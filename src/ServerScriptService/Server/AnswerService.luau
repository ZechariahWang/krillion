--!strict
-- Receives match answers, validates them and grades them against the live question, with autocorrect.
-- Only the player holding the crab may answer. One Enter sends SubmitAnswer: a wrong or already used answer
-- is refused and they may try again; an accepted one fires Answered, and RoundService passes the crab on.

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

local currentPrompt: AnswerMatcher.Prompt? = nil
local used: { [string]: boolean } = {} -- the question's used answers; RoundService's match owns the table
local holder: Player? = nil
local gate: AnswerGate.Gate? = nil -- the holder's guess rate for this turn

local AnswerService = {}

-- (player: Player, submission: Submission) when the holder's answer is accepted.
AnswerService.Answered = Signal.new("TurnAnswered")
-- (player: Player, seconds: number) when the holder buys extra time for the fuse.
AnswerService.Extended = Signal.new("TurnExtended")

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

function AnswerService.randomPrompt(exclude: { [string]: boolean }): AnswerMatcher.Prompt
	return PromptBank.random(exclude)
end

-- Opens a question. `usedAnswers` is the match's own table of answers this question has used up; it is read
-- here, never written.
function AnswerService.openQuestion(prompt: AnswerMatcher.Prompt, usedAnswers: { [string]: boolean })
	currentPrompt = prompt
	used = usedAnswers
	holder = nil
	gate = nil
end

function AnswerService.closeQuestion()
	currentPrompt = nil
	used = {}
	holder = nil
	gate = nil
end

-- Who may answer now: the player holding the crab, or nil while a bot holds it.
function AnswerService.setHolder(player: Player?)
	holder = player
	gate = if player ~= nil then AnswerGate.new(math.huge) else nil
end

-- The live question's accepted answers by tier name (already normalized), or nil between questions.
function AnswerService.currentAnswersByTier(): { [string]: { string } }?
	local prompt = currentPrompt
	if prompt == nil then
		return nil
	end
	return prompt.answers
end

-- The answers the live question has used up, so a hint never offers one of them.
function AnswerService.usedAnswers(): { [string]: boolean }
	return table.clone(used)
end

-- Grades text against the live question. Nil when it is not in the bank; a used answer comes back with
-- `isUsed` true. Nothing the client sent before is trusted.
local function gradeText(text: any): (Submission?, boolean)
	local prompt = currentPrompt
	if prompt == nil or not AnswerService.isValidText(text) then
		return nil, false
	end
	local graded = AnswerService.grade(text, prompt)
	if graded.tier == nil or graded.corrected == nil then
		return nil, false
	end
	return graded, used[graded.corrected] == true
end

-- Grades a bot's answer against the live question. Nil when it is wrong or already used.
function AnswerService.gradeForBot(text: string): Submission?
	local graded, isUsed = gradeText(text)
	if graded == nil or isUsed then
		return nil
	end
	return graded
end

-- Whether this player could use a boost right now: "ok" | "closed" | "not_playing".
function AnswerService.boostStatus(player: Player): string
	if currentPrompt == nil then
		return "closed"
	end
	if holder ~= player then
		return "not_playing"
	end
	return "ok"
end

-- Adds `seconds` to the fuse while this player holds the crab. Returns the seconds added, or nil if they
-- do not hold it.
function AnswerService.extend(player: Player, seconds: number): number?
	if AnswerService.boostStatus(player) ~= "ok" then
		return nil
	end
	AnswerService.Extended.fire(player, seconds)
	return seconds
end

-- Enter: grade it and, if it is a new answer in the bank, accept it. The reply says accepted or why not
-- ("closed" | "cooldown" | "limit" | "invalid" | "used").
local function onSubmit(player: Player, text: any)
	local result = Net.event("AnswerResult")
	local turn = gate
	if currentPrompt == nil or holder ~= player or turn == nil then
		result:FireClient(player, { stage = "submit", accepted = false, status = "closed" })
		return
	end
	local now = os.clock()
	local status = AnswerGate.check(turn, now)
	if status ~= "ok" then
		result:FireClient(player, { stage = "submit", accepted = false, status = status })
		return
	end
	local graded, isUsed = gradeText(text)
	if graded == nil then
		AnswerGate.noteCheck(turn, now, false)
		result:FireClient(player, { stage = "submit", accepted = false, status = "invalid" })
		return
	end
	if isUsed then
		AnswerGate.noteCheck(turn, now, false)
		result:FireClient(player, { stage = "submit", accepted = false, status = "used", corrected = graded.corrected })
		return
	end
	-- The turn is over: a second Enter in flight is refused as "closed".
	holder = nil
	gate = nil
	result:FireClient(player, { stage = "submit", accepted = true, corrected = graded.corrected })
	AnswerService.Answered.fire(player, graded)
end

function AnswerService.start()
	Net.event("SubmitAnswer").OnServerEvent:Connect(onSubmit)
	Players.PlayerRemoving:Connect(function(player)
		if holder == player then
			holder = nil
			gate = nil
		end
	end)
end

return AnswerService
