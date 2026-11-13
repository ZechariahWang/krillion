--!strict
-- Receives match answers, validates them and grades them against the live prompt, with autocorrect.
-- Answering is two steps: CheckAnswer (Enter once) says whether the text is in the bank and shows its
-- spelling; SubmitAnswer (Enter again) re-grades and locks it in. Each player has their own deadline,
-- which a +10s boost or a late join can push past the prompt's base time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AnswerGate = require(ReplicatedStorage.Shared.AnswerGate)
local AnswerMatcher = require(ReplicatedStorage.Shared.AnswerMatcher)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local PromptBank = require(ServerStorage.PromptBank)

export type Prompt = AnswerMatcher.Prompt

export type Submission = {
	text: string,
	tier: string?,
	corrected: string?, -- the bank spelling, shown back to players instead of what they typed
	points: number,
}

local RAW_LIMIT = GameConfig.Answer.MaxLength * 2

local accepting = false
local currentPrompt: AnswerMatcher.Prompt? = nil
local eligible: { [Player]: boolean } = {}
local submissions: { [Player]: Submission } = {}
local gates: { [Player]: AnswerGate.Gate } = {} -- per-player checks and deadline for the open prompt
local baseDeadline = 0 -- os.clock() when the prompt's normal time runs out
local DEADLINE_EPSILON = 0.01 -- a deadline this close to the base one counts as "no extra time"

local AnswerService = {}

-- (player: Player) when a player's answer locks in. RoundService pushes a state update on it so lock dots
-- and the all-locked early finish react within a fraction of a second.
AnswerService.Locked = Signal.new("AnswerLocked")

function AnswerService.isValidText(text: any): boolean
	if typeof(text) ~= "string" then
		return false
	end
	if #text == 0 or #text > RAW_LIMIT then
		return false
	end
	return true
end

function AnswerService.grade(text: string, prompt: AnswerMatcher.Prompt): Submission
	local tier, corrected = AnswerMatcher.resolve(text, prompt)
	local points = 0
	if tier ~= nil then
		points = Tiers.points(tier)
	end
	return { text = text, tier = tier, corrected = corrected, points = points }
end

-- `seconds` is the prompt's normal answer time; per-player deadlines (extra time) build on it.
function AnswerService.openRound(prompt: AnswerMatcher.Prompt, players: { Player }, seconds: number?)
	currentPrompt = prompt
	submissions = {}
	eligible = {}
	gates = {}
	baseDeadline = os.clock() + (seconds or GameConfig.Round.PromptSeconds)
	for _, player in players do
		eligible[player] = true
		gates[player] = AnswerGate.new(baseDeadline)
	end
	accepting = true
end

-- Lets a player who rejoined mid-round (a revive, a late joiner) answer the open prompt, with at least
-- LateJoin.MinSecondsLeft to do it: past the base time the prompt runs on in overtime for them.
function AnswerService.allow(player: Player)
	eligible[player] = true
	if not accepting then
		return
	end
	local floor = math.max(baseDeadline, os.clock() + GameConfig.LateJoin.MinSecondsLeft)
	local gate = gates[player]
	if gate == nil then
		gates[player] = AnswerGate.new(floor)
	else
		gate.deadline = math.max(gate.deadline, floor)
	end
end

-- A player who sinks mid-prompt (a fall, a reset) stops counting: no boosts, no overtime held open for
-- them, and the all-locked early finish no longer waits on them. A locked answer stays, so a revive in
-- the same prompt (AnswerService.allow) keeps it.
function AnswerService.disallow(player: Player)
	eligible[player] = nil
	gates[player] = nil
end

function AnswerService.closeRound(): { [Player]: Submission }
	accepting = false
	currentPrompt = nil
	return submissions
end

function AnswerService.randomPrompt(exclude: { [string]: boolean }): AnswerMatcher.Prompt
	return PromptBank.random(exclude)
end

-- UserIds of everyone who has locked in an answer this prompt.
function AnswerService.lockedUserIds(): { number }
	local ids = {}
	for player in submissions do
		table.insert(ids, player.UserId)
	end
	return ids
end

-- True when every eligible player still in the server has locked in (and there is at least one).
function AnswerService.allLocked(): boolean
	if not accepting then
		return false
	end
	local any = false
	for player in eligible do
		if player.Parent ~= nil then
			any = true
			if submissions[player] == nil then
				return false
			end
		end
	end
	return any
end

-- The bank spellings locked in this prompt, so a hint never gives away an answer someone already has.
function AnswerService.lockedCorrected(): { [string]: boolean }
	local result = {}
	for _, submission in submissions do
		if submission.corrected ~= nil then
			result[submission.corrected] = true
		end
	end
	return result
end

-- The live prompt's accepted answers by tier name (already normalized), or nil between prompts.
function AnswerService.currentAnswersByTier(): { [string]: { string } }?
	local prompt = currentPrompt
	if prompt == nil then
		return nil
	end
	return prompt.answers
end

-- Seconds the prompt must run past now because an unlocked player still has extra time (a +10s boost,
-- a late join). Only deadlines past the base time count; 0 means it can end.
function AnswerService.overtimeRemaining(): number
	if not accepting then
		return 0
	end
	local now = os.clock()
	local remaining = 0
	for player, gate in gates do
		local waiting = eligible[player] and player.Parent ~= nil and submissions[player] == nil
		if waiting and gate.deadline > baseDeadline + DEADLINE_EPSILON then
			remaining = math.max(remaining, gate.deadline - now)
		end
	end
	return remaining
end

-- This player's own seconds left when it differs from the shared countdown (they bought extra time or
-- joined late), else nil.
function AnswerService.secondsLeftFor(player: Player): number?
	local gate = gates[player]
	if not accepting or gate == nil or submissions[player] ~= nil then
		return nil
	end
	if math.abs(gate.deadline - baseDeadline) <= DEADLINE_EPSILON then
		return nil
	end
	return math.max(0, math.ceil(gate.deadline - os.clock()))
end

-- Whether this player could use a boost on the open prompt right now:
-- "ok" | "closed" | "not_playing" | "locked". Boosts get no network grace past the deadline.
function AnswerService.boostStatus(player: Player): string
	if not accepting or currentPrompt == nil then
		return "closed"
	end
	local gate = gates[player]
	if not eligible[player] or gate == nil then
		return "not_playing"
	end
	if submissions[player] ~= nil or gate.locked then
		return "locked"
	end
	if os.clock() >= gate.deadline then
		return "closed"
	end
	return "ok"
end

-- Adds `seconds` to one player's deadline. Returns their new seconds left, or nil if they cannot answer now.
function AnswerService.extend(player: Player, seconds: number): number?
	if AnswerService.boostStatus(player) ~= "ok" then
		return nil
	end
	local gate = gates[player] :: AnswerGate.Gate
	gate.deadline += seconds
	return math.ceil(gate.deadline - os.clock())
end

-- When the prompt's base time ends, as an os.clock() time.
function AnswerService.baseDeadline(): number
	return baseDeadline
end

-- The gate statuses a client can act on; a locked or ineligible player just hears "closed".
local function clientStatus(status: string): string
	if status == "cooldown" or status == "limit" or status == "closed" then
		return status
	end
	return "closed"
end

-- Grades without trusting anything the client sent before. Nil when the text is not a usable string.
local function gradeText(text: any): Submission?
	local prompt = currentPrompt
	if prompt == nil or not AnswerService.isValidText(text) then
		return nil
	end
	local graded = AnswerService.grade(text, prompt)
	if graded.tier == nil then
		return nil
	end
	return graded
end

-- Grades a bot's answer (a negative number id) against the open prompt, before its base deadline. Bots are
-- not eligible players, so this stores nothing: RoundService keeps the result. Nil when refused.
function AnswerService.submitFor(id: number, text: string): Submission?
	if id >= 0 or not accepting or os.clock() > baseDeadline then
		return nil
	end
	return gradeText(text)
end

-- Enter once: is it in the bank, and how is it spelled? Never says the tier, and never locks anything.
local function onCheck(player: Player, text: any)
	local result = Net.event("AnswerResult")
	local gate = gates[player]
	if not accepting or currentPrompt == nil or not eligible[player] or gate == nil or submissions[player] ~= nil then
		result:FireClient(player, { stage = "check", status = "closed" })
		return
	end
	local now = os.clock()
	local status = AnswerGate.check(gate, now)
	if status ~= "ok" then
		result:FireClient(player, { stage = "check", status = clientStatus(status) })
		return
	end
	local graded = gradeText(text)
	AnswerGate.noteCheck(gate, now, graded ~= nil)
	if graded == nil then
		result:FireClient(player, { stage = "check", status = "invalid" })
		return
	end
	result:FireClient(player, { stage = "check", status = "valid", corrected = graded.corrected })
end

-- Enter again: re-grades and locks in. Wrong answers are rejected on the spot so the player can try
-- again. The tier stays secret until the reveal: the client only learns accepted or not.
local function onSubmit(player: Player, text: any)
	local result = Net.event("AnswerResult")
	local gate = gates[player]
	if submissions[player] ~= nil then
		return
	end
	if not accepting or currentPrompt == nil or not eligible[player] or gate == nil then
		result:FireClient(player, { stage = "submit", accepted = false, status = "closed" })
		return
	end
	local now = os.clock()
	local status = AnswerGate.canSubmit(gate, now)
	if status ~= "ok" then
		result:FireClient(player, { stage = "submit", accepted = false, status = clientStatus(status) })
		return
	end
	local graded = gradeText(text)
	if graded == nil then
		AnswerGate.noteCheck(gate, now, false)
		result:FireClient(player, { stage = "submit", accepted = false, status = "invalid" })
		return
	end
	AnswerGate.lock(gate)
	submissions[player] = graded
	result:FireClient(player, { stage = "submit", accepted = true, corrected = graded.corrected })
	AnswerService.Locked.fire(player)
end

function AnswerService.start()
	Net.event("CheckAnswer").OnServerEvent:Connect(onCheck)
	Net.event("SubmitAnswer").OnServerEvent:Connect(onSubmit)
	Players.PlayerRemoving:Connect(function(player)
		eligible[player] = nil
		submissions[player] = nil
		gates[player] = nil
	end)
end

return AnswerService
