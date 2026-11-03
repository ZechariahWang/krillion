--!strict
-- Receives match answers, validates them, grades them against the live prompt, and filters text for display.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local AnswerMatcher = require(ReplicatedStorage.Shared.AnswerMatcher)
local Net = require(ReplicatedStorage.Shared.Net)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local PromptBank = require(ServerStorage.PromptBank)

export type Prompt = AnswerMatcher.Prompt

export type Submission = {
	text: string,
	tier: string?,
	points: number,
}

local RAW_LIMIT = GameConfig.Answer.MaxLength * 2

local accepting = false
local currentPrompt: AnswerMatcher.Prompt? = nil
local eligible: { [Player]: boolean } = {}
local submissions: { [Player]: Submission } = {}

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
	local tier = AnswerMatcher.match(text, prompt)
	local points = 0
	if tier ~= nil then
		points = Tiers.points(tier)
	end
	return { text = text, tier = tier, points = points }
end

-- Returns the text safe to show to everyone, or nil when filtering failed.
function AnswerService.filterForBroadcast(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return result
	end
	warn("AnswerService: filter failed for " .. player.Name .. ": " .. tostring(result))
	return nil
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

function AnswerService.start()
	Net.event("SubmitAnswer").OnServerEvent:Connect(function(player, text)
		if not accepting or currentPrompt == nil then
			return
		end
		if not eligible[player] or submissions[player] ~= nil then
			return
		end
		if not AnswerService.isValidText(text) then
			return
		end
		submissions[player] = AnswerService.grade(text, currentPrompt)
	end)
	Players.PlayerRemoving:Connect(function(player)
		eligible[player] = nil
		submissions[player] = nil
	end)
end

return AnswerService
