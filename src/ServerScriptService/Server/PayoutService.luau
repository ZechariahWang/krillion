--!strict
-- Pays Shells for match answers and announces Mythic finds, driven by MatchEvents.
-- Survival ("survive") and win ("win") pay stays in RoundService; warm-up pay in LobbyQuizService.
-- Also keeps the lifetime krillions and games counters on the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Economy = require(ReplicatedStorage.Shared.Economy)
local MatchEvents = require(script.Parent.MatchEvents)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local StoreService = require(script.Parent.StoreService)

local MYTHIC = "Mythic"

local PayoutService = {}

-- The finder reads "YOU FOUND...", everyone else gets the name. The answer is the bank's spelling
-- (our own text, never raw chat), so it is safe to broadcast.
local function announceMythic(finder: Player, answer: string?)
	local found = if answer ~= nil and answer ~= "" then ": " .. string.upper(answer) .. "!" else "!"
	local name = string.upper(finder.DisplayName)
	for _, player in Players:GetPlayers() do
		local who = if player == finder then "YOU" else name
		NotifyService.send(player, who .. " FOUND A MYTHIC" .. found, "mythic")
	end
end

-- Waits until the dive cards have landed, so the "+N" popup and the toast arrive with the pillar rise
-- instead of on top of the reveal.
local function onGraded(player: Player, tier: string?, _points: number, _promptId: string, answer: string?)
	if tier == nil then
		return
	end
	if tier == MYTHIC then
		DataService.addCounter(player, "krillions", 1)
	end
	local shells = Economy.answerShells(tier)
	task.delay(GameConfig.Reveal.PayoutDelaySeconds, function()
		if player.Parent == nil then
			return
		end
		if shells > 0 then
			StoreService.payEarned(player, shells, "answer")
		end
		if tier == MYTHIC then
			announceMythic(player, answer)
		end
	end)
end

function PayoutService.start()
	MatchEvents.AnswerGraded.connect(onGraded)
	MatchEvents.MatchFinished.connect(function(participants: { Player })
		for _, player in participants do
			DataService.addCounter(player, "games", 1)
		end
	end)
end

return PayoutService
