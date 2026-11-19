--!strict
-- Prompt of the Day (rules in Shared/DailyPrompt): one prompt a UTC day for everyone, answered once from the
-- lobby window (Client/DailyPrompt). Grading works like a match: an answer the bank has as typed locks in, one
-- that needed a typo fixed comes back to be confirmed. It pays Shells and XP, keeps a day streak whose every
-- seventh day opens a free chest, and counts every answer in a per-day DataStore so the window can show what
-- share of players gave yours, today so far and yesterday in full.
-- Each server buffers its answers and adds them to the day's entry once a FlushSeconds, and on close.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local AnswerStats = require(ReplicatedStorage.Shared.AnswerStats)
local Collection = require(ReplicatedStorage.Shared.Collection)
local DailyPrompt = require(ReplicatedStorage.Shared.DailyPrompt)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local PromptBank = require(ServerStorage.PromptBank)
local AnswerService = require(script.Parent.AnswerService)
local ChestService = require(script.Parent.ChestService)
local DataService = require(script.Parent.DataService)
local LevelService = require(script.Parent.LevelService)
local MatchEvents = require(script.Parent.MatchEvents)
local StoreService = require(script.Parent.StoreService)

local RULES = GameConfig.DailyPrompt
local DAY_SECONDS = 86400
local STORE_NAME = "DailyPrompt_v1"
local ANSWER_COOLDOWN = 0.4 -- seconds between answer attempts from one player
local STATE_COOLDOWN = 2 -- seconds between state requests from one player

local liveIds: { string } = {}
local store: DataStore? = nil
local saved: { [number]: AnswerStats.Counts } = {} -- the day's entry as last read or written
local buffer: { [number]: AnswerStats.Counts } = {} -- this server's answers not yet added to the store
local lastAnswer: { [Player]: number } = {}
local lastState: { [Player]: number } = {}

local DailyPromptService = {}

local function today(): number
	return math.floor(os.time() / DAY_SECONDS)
end

local function promptFor(day: number): AnswerService.Prompt?
	if #liveIds == 0 then
		return nil
	end
	return PromptBank.ById[DailyPrompt.pick(day, liveIds)]
end

local function countsFor(day: number): AnswerStats.Counts
	return AnswerStats.mergeCounts(saved[day], buffer[day])
end

local function read(day: number)
	local target = store
	if target == nil then
		return
	end
	local ok, value = pcall(function()
		return target:GetAsync(tostring(day))
	end)
	if ok then
		saved[day] = AnswerStats.sanitize(value)
	else
		warn("DailyPromptService: could not read day " .. day .. ": " .. tostring(value))
	end
end

-- Adds every buffered day to the store. A failed write keeps its answers for the next try.
local function flush()
	local target = store
	if target == nil then
		return
	end
	for day, delta in buffer do
		buffer[day] = nil
		if delta.total > 0 then
			local ok, result = pcall(function()
				return target:UpdateAsync(tostring(day), function(old)
					return AnswerStats.mergeCounts(old, delta)
				end)
			end)
			if ok then
				saved[day] = AnswerStats.sanitize(result)
			else
				buffer[day] = AnswerStats.mergeCounts(buffer[day], delta)
				warn("DailyPromptService: could not save day " .. day .. ": " .. tostring(result))
			end
		end
	end
end

local function shareOf(day: number, answer: string): number?
	return DailyPrompt.share(countsFor(day), answer)
end

-- What the window shows for one player: today's prompt and their answer, the streak, and yesterday's result.
local function stateFor(player: Player): Net.DailyPromptStatePayload?
	local profile = DataService.get(player)
	local day = today()
	local prompt = promptFor(day)
	if profile == nil or prompt == nil then
		return nil
	end
	local mine = profile.dailyPrompt
	local streak = if mine.day >= day - 1 then mine.streak else 0
	local payload: Net.DailyPromptStatePayload = {
		day = day,
		prompt = prompt.prompt,
		secondsLeft = (day + 1) * DAY_SECONDS - os.time(),
		streak = streak,
		chestIn = DailyPrompt.daysToChest(streak),
	}
	if mine.day == day then
		payload.answered = { answer = mine.answer, tier = mine.tier, share = shareOf(day, mine.answer) }
	end
	local before = promptFor(day - 1)
	if before ~= nil then
		local answer: string? = nil
		local tier: string? = nil
		if mine.day == day - 1 then
			answer = mine.answer
			tier = mine.tier
		elseif mine.prevDay == day - 1 then
			answer = mine.prevAnswer
			tier = mine.prevTier
		end
		local counts = countsFor(day - 1)
		local top = {}
		for _, row in DailyPrompt.top(counts, RULES.TopCount) do
			table.insert(top, { answer = row.answer, share = DailyPrompt.share(counts, row.answer) })
		end
		payload.yesterday = {
			prompt = before.prompt,
			answer = answer,
			tier = tier,
			share = if answer ~= nil then DailyPrompt.share(counts, answer) else nil,
			top = top,
		}
	end
	return payload
end

local function sendState(player: Player)
	local payload = stateFor(player)
	if payload ~= nil and player.Parent ~= nil then
		Net.event("DailyPromptState"):FireClient(player, payload)
	end
end

local function reply(player: Player, payload: Net.DailyPromptResultPayload)
	Net.event("DailyPromptResult"):FireClient(player, payload)
end

-- Locks the answer in as today's, pays it and records it.
local function settle(player: Player, old: Profile.DailyPromptState, day: number, tier: string, answer: string)
	local streak = DailyPrompt.nextStreak(old.day, old.streak, day)
	DataService.setDailyPrompt(player, {
		day = day,
		answer = answer,
		tier = tier,
		streak = streak,
		prevDay = old.day,
		prevAnswer = old.answer,
		prevTier = old.tier,
	})
	local counts = buffer[day] or AnswerStats.empty()
	AnswerStats.record(counts, answer)
	buffer[day] = counts
	local shells = StoreService.payEarned(player, Economy.answerShells(tier) * RULES.ShellsMultiplier, "daily")
	LevelService.give(player, Levels.answerXp(tier))
	local chest = DailyPrompt.chestDue(streak)
	if chest then
		ChestService.openFree(player, RULES.StreakChest)
	end
	reply(player, { status = "ok", answer = answer, tier = tier, shells = shells, streak = streak, chest = chest })
	sendState(player)
end

-- text: what the player typed. confirm: true when they pressed Enter again on a DID YOU MEAN.
local function onAnswer(player: Player, text: any, confirm: any)
	local now = os.clock()
	local last = lastAnswer[player]
	if last ~= nil and now - last < ANSWER_COOLDOWN then
		return reply(player, { status = "cooldown" })
	end
	lastAnswer[player] = now
	local profile = DataService.get(player)
	local day = today()
	local prompt = promptFor(day)
	if profile == nil or prompt == nil or DataService.isReadOnly(player) or player:GetAttribute("Playing") == true then
		return reply(player, { status = "closed" })
	end
	if profile.dailyPrompt.day == day then
		return reply(player, { status = "done" })
	end
	if not AnswerService.isValidText(text) then
		return reply(player, { status = "invalid" })
	end
	local graded = AnswerService.grade(text, prompt)
	local tier = graded.tier
	local answer = graded.corrected
	if tier == nil or answer == nil then
		MatchEvents.AnswerRefused.fire(player, prompt.id, text)
		return reply(player, { status = "invalid" })
	end
	if not graded.sure and confirm ~= true then
		return reply(player, { status = "confirm", answer = answer })
	end
	settle(player, profile.dailyPrompt, day, tier, answer)
end

local function onStateRequest(player: Player)
	local now = os.clock()
	local last = lastState[player]
	if last ~= nil and now - last < STATE_COOLDOWN then
		return
	end
	lastState[player] = now
	sendState(player)
end

function DailyPromptService.start()
	for _, prompt in PromptBank.List do
		if not PromptBank.Retired[prompt.id] and Collection.topTier(prompt.answers) ~= nil then
			table.insert(liveIds, prompt.id)
		end
	end
	local name = if RunService:IsStudio() then STORE_NAME .. "_Studio" else STORE_NAME
	local ok, opened = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok then
		store = opened
	else
		warn("DailyPromptService: no store, shares stay hidden: " .. tostring(opened))
	end
	Net.event("DailyPromptAnswer").OnServerEvent:Connect(onAnswer)
	Net.event("DailyPromptState").OnServerEvent:Connect(onStateRequest)
	DataService.ProfileLoaded.connect(sendState)
	Players.PlayerRemoving:Connect(function(player)
		lastAnswer[player] = nil
		lastState[player] = nil
	end)
	-- Yesterday is final: one read. Today is read again every flush so other servers' answers show up.
	task.spawn(function()
		local readYesterdayFor = -1
		while true do
			local day = today()
			if readYesterdayFor ~= day then
				read(day - 1)
				readYesterdayFor = day
			end
			flush()
			read(day)
			task.wait(RULES.FlushSeconds)
		end
	end)
	game:BindToClose(flush)
end

return DailyPromptService
