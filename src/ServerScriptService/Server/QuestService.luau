--!strict
-- Daily quests: three per player per UTC day (Shared/Quests), advanced by MatchEvents and play time,
-- paid with StoreService.grantShells(reward, "quest") and a "QUEST COMPLETE" toast.
-- The list itself is never saved: server and client both draw it from (userId, day); the profile keeps
-- only that day's progress and done flags (DataService.setQuest), so a new day starts fresh by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Quests = require(ReplicatedStorage.Shared.Quests)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local NotifyService = require(script.Parent.NotifyService)
local StoreService = require(script.Parent.StoreService)

-- When the last play-time credit was counted, so a player who joins mid-tick only gets the time they played.
local lastPlayTick: { [Player]: number } = {}

local QuestService = {}

local function complete(player: Player, quest: Quests.Quest)
	StoreService.grantShells(player, quest.reward, "quest")
	NotifyService.send(player, `QUEST COMPLETE  |  {quest.text}  +{quest.reward} SHELLS`, "good")
end

-- Today's saved progress for one quest. A profile still on an older day counts as nothing done yet.
local function savedProgress(player: Player, day: number, id: string): (number, boolean)
	local profile = DataService.get(player)
	if profile == nil or profile.quests.day ~= day then
		return 0, false
	end
	return profile.quests.progress[id] or 0, profile.quests.done[id] == true
end

-- Advances every quest of `kind` the player has today ("match_played", "round_survived", "rare_answer",
-- "deep_answer", "practice_answer", "play_seconds", "match_won").
function QuestService.advance(player: Player, kind: string, amount: number)
	if amount ~= amount or amount <= 0 or not DataService.isLoaded(player) or DataService.isReadOnly(player) then
		return
	end
	-- The day is read on every event, so the first event after UTC midnight starts the new day's quests.
	local day = Quests.day(os.time())
	for _, quest in Quests.draw(player.UserId, day) do
		if quest.kind == kind then
			local progress, done = savedProgress(player, day, quest.id)
			if not done then
				local nextProgress, justDone = Quests.advance(progress, quest, amount)
				if nextProgress ~= progress or justDone then
					DataService.setQuest(player, day, quest.id, nextProgress, justDone)
					if justDone then
						complete(player, quest)
					end
				end
			end
		end
	end
end

-- Debug hook: sets one of today's quests to an absolute progress. Returns a short result for the console.
function QuestService.debugSet(player: Player, questId: string, progress: number): string
	if not DataService.isLoaded(player) then
		return "profile not loaded"
	end
	local day = Quests.day(os.time())
	local todays = Quests.draw(player.UserId, day)
	local quest: Quests.Quest? = nil
	local listed = {}
	for _, candidate in todays do
		table.insert(listed, candidate.id)
		if candidate.id == questId then
			quest = candidate
		end
	end
	if quest == nil then
		return `{questId} is not one of today's quests ({table.concat(listed, ", ")})`
	end
	local found = quest :: Quests.Quest
	local current, done = savedProgress(player, day, found.id)
	local target = math.clamp(math.floor(progress), 0, found.goal)
	-- Progress merges as a per-day maximum, so it can only go up; done quests stay done.
	if done or target <= current then
		return `{found.id} stays at {current}/{found.goal}{if done then " (done)" else ""}`
	end
	local justDone = target >= found.goal
	DataService.setQuest(player, day, found.id, target, justDone)
	if justDone then
		complete(player, found)
	end
	return `{found.id} set to {target}/{found.goal}`
end

local function advanceForTier(player: Player, tier: string?)
	for _, kind in Quests.kindsForTier(Tiers.index(tier)) do
		QuestService.advance(player, kind, 1)
	end
end

local function creditPlayTime(player: Player, now: number)
	local last = lastPlayTick[player]
	lastPlayTick[player] = now
	if last == nil then
		return
	end
	-- AFK time still moves the tick forward, so going back to play does not credit the idle stretch.
	if player:GetAttribute("Afk") == true then
		return
	end
	local seconds = math.floor(now - last + 0.5)
	if seconds > 0 then
		QuestService.advance(player, "play_seconds", seconds)
	end
end

function QuestService.start()
	MatchEvents.AnswerGraded.connect(
		function(player: Player, tier: string?, _points: number, _promptId: string, _answer: string?)
			if tier == nil then
				return
			end
			-- After the dive cards land, like the answer payout, so a "QUEST COMPLETE" toast never spoils a tier.
			task.delay(GameConfig.Reveal.PayoutDelaySeconds, function()
				if player.Parent ~= nil then
					advanceForTier(player, tier)
				end
			end)
		end
	)
	MatchEvents.RoundSurvived.connect(function(player: Player, _round: number)
		QuestService.advance(player, "round_survived", 1)
	end)
	MatchEvents.MatchFinished.connect(
		function(participants: { Player }, winner: Player?, countsAsWin: boolean, _rounds: number)
			for _, player in participants do
				QuestService.advance(player, "match_played", 1)
			end
			if winner ~= nil and countsAsWin then
				QuestService.advance(winner, "match_won", 1)
			end
		end
	)
	-- Warm-ups count for the warm-up quest and, as in Sink or Niche, for the Rare+ and Deep Cut+ quests too.
	MatchEvents.LobbyAnswered.connect(
		function(player: Player, tier: string, _points: number, _promptId: string, _corrected: string)
			QuestService.advance(player, "practice_answer", 1)
			advanceForTier(player, tier)
		end
	)

	DataService.ProfileLoaded.connect(function(player: Player)
		lastPlayTick[player] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPlayTick[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(GameConfig.Quests.PlaySecondsTick)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if DataService.isLoaded(player) then
					local ok, err = pcall(creditPlayTime, player, now)
					if not ok then
						warn("QuestService: play time failed for " .. player.Name .. ": " .. tostring(err))
					end
				end
			end
		end
	end)
end

return QuestService
