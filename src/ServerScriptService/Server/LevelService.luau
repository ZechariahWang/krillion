--!strict
-- Gives level XP for match answers, rounds survived and Wins (rules in Shared/Levels), and on a level up
-- pays the Shells and refreshes the head label's level. The client's level bar celebrates it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Levels = require(ReplicatedStorage.Shared.Levels)
local MatchEvents = require(script.Parent.MatchEvents)
local DataService = require(script.Parent.DataService)
local StoreService = require(script.Parent.StoreService)
local CosmeticService = require(script.Parent.CosmeticService)

local RULES = GameConfig.Levels

local LevelService = {}

function LevelService.give(player: Player, amount: number)
	local profile = DataService.get(player)
	if profile == nil or amount <= 0 or DataService.isReadOnly(player) then
		return
	end
	local before = profile.xp
	DataService.addXp(player, amount)
	local gained = Levels.gained(before, before + amount)
	if gained <= 0 then
		return
	end
	StoreService.grantShells(player, gained * RULES.ShellsPerLevel, "level")
	CosmeticService.refresh(player)
end

function LevelService.start()
	-- Answer XP lands with the answer's Shells, once the dive cards are down.
	MatchEvents.AnswerGraded.connect(function(player: Player, tier: string?)
		local xp = Levels.answerXp(tier)
		if xp <= 0 then
			return
		end
		task.delay(GameConfig.Reveal.PayoutDelaySeconds, function()
			if player.Parent ~= nil then
				LevelService.give(player, xp)
			end
		end)
	end)
	MatchEvents.RoundSurvived.connect(function(player: Player)
		LevelService.give(player, RULES.RoundSurvivedXp)
	end)
	MatchEvents.MatchFinished.connect(function(_participants: { Player }, winner: Player?, countsAsWin: boolean)
		if winner ~= nil and countsAsWin then
			LevelService.give(winner, RULES.WinXp)
		end
	end)
	-- A character can spawn before the profile loads; this puts the real level on its label.
	DataService.ProfileLoaded.connect(function(player: Player)
		CosmeticService.refresh(player)
	end)
end

return LevelService
