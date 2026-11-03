--!strict
-- Receives match answers, validates them and grades them against the live prompt, with autocorrect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AnswerMatcher = require(ReplicatedStorage.Shared.AnswerMatcher)
local Net = require(ReplicatedStorage.Shared.Net)
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
local lastTry: { [Player]: number } = {}

local AnswerService = {}

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

function AnswerService.openRound(prompt: AnswerMatcher.Prompt, players: { Player })
	currentPrompt = prompt
	submissions = {}
	eligible = {}
	for _, player in players do
		eligible[player] = true
	end
	accepting = true
end

function AnswerService.closeRound(): { [Player]: Submission }
	accepting = false
	currentPrompt = nil
	return submissions
end

function AnswerService.randomPrompt(exclude: { [string]: boolean }): AnswerMatcher.Prompt
	return PromptBank.random(exclude)
end

-- Wrong answers are rejected on the spot so the player can try again; only an accepted answer locks in.
-- The tier stays secret until the reveal: the client only learns accepted or not.
local function onSubmit(player: Player, text: any)
	if not accepting or currentPrompt == nil then
		return
	end
	if not eligible[player] or submissions[player] ~= nil then
		return
	end
	local now = os.clock()
	if now - (lastTry[player] or 0) < GameConfig.Answer.RetryCooldown then
		return
	end
	lastTry[player] = now
	local result = Net.event("AnswerResult")
	if not AnswerService.isValidText(text) then
		result:FireClient(player, { accepted = false })
		return
	end
	local graded = AnswerService.grade(text, currentPrompt)
	if graded.tier == nil then
		result:FireClient(player, { accepted = false })
		return
	end
	submissions[player] = graded
	result:FireClient(player, { accepted = true, corrected = graded.corrected })
end

function AnswerService.start()
	Net.event("SubmitAnswer").OnServerEvent:Connect(onSubmit)
	Players.PlayerRemoving:Connect(function(player)
		eligible[player] = nil
		submissions[player] = nil
		lastTry[player] = nil
	end)
end

return AnswerService
