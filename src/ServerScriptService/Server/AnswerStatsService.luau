--!strict
-- Real "1 in N players" numbers: counts how often each answer is given per prompt in a DataStore.
-- Answers are buffered per prompt (match reveals and lobby warm-ups, real players only, once per player
-- per prompt per server) and merged in with one UpdateAsync per prompt every FLUSH_SECONDS and on close.
-- Reads are cached per prompt and prefetched when a prompt opens. oneIn() never yields: it returns nil
-- until the counts are cached and GameConfig.Reveal.StatsMinTotal answers exist, and the dive card then
-- falls back to the estimate or the tier blurb. Repeated DataStore failures switch the whole thing off.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnswerStats = require(ReplicatedStorage.Shared.AnswerStats)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local MatchEvents = require(script.Parent.MatchEvents)

-- Studio with API access shares the live universe's DataStores, so test answers go to their own store.
local STORE_NAME = if RunService:IsStudio() then "AnswerStats_v1_Studio" else "AnswerStats_v1"
local FLUSH_SECONDS = 60
local CACHE_SECONDS = 300
local RETRY_SECONDS = 30 -- after a failed read, before that prompt is fetched again
local MAX_FAILURES = 3 -- consecutive DataStore failures before stats switch off for this server
local BUDGET_RESERVE = 20 -- requests left for profile saves before stats wait for the next flush
local MAX_KEY_LENGTH = 50 -- DataStore key limit
local CLOSE_WAIT_SECONDS = 20

type CacheEntry = {
	data: AnswerStats.Counts,
	fetchedAt: number,
}

local store: DataStore? = nil
local disabled = false
local failures = 0
local flushing = false

local pending: { [string]: AnswerStats.Counts } = {} -- promptId -> answers not yet written
local cache: { [string]: CacheEntry } = {}
local fetching: { [string]: boolean } = {}
local retryAt: { [string]: number } = {}
local seen: { [Player]: { [string]: boolean } } = {} -- promptIds each player already counted for

local AnswerStatsService = {}

local function fail(what: string, err: any)
	failures += 1
	warn(string.format("[AnswerStats] %s failed (%d/%d): %s", what, failures, MAX_FAILURES, tostring(err)))
	if failures >= MAX_FAILURES and not disabled then
		disabled = true
		pending = {}
		warn("[AnswerStats] switched off for this server; dive cards fall back to the tier blurb")
	end
end

local function validId(promptId: any): boolean
	return typeof(promptId) == "string" and promptId ~= "" and #promptId <= MAX_KEY_LENGTH
end

local function hasBudget(requestType: Enum.DataStoreRequestType, reserve: number): boolean
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(requestType)
	end)
	return ok and budget > reserve
end

local function fetch(promptId: string)
	local dataStore = store
	if dataStore == nil or disabled or fetching[promptId] then
		return
	end
	if os.clock() < (retryAt[promptId] or 0) then
		return
	end
	if not hasBudget(Enum.DataStoreRequestType.GetAsync, BUDGET_RESERVE) then
		retryAt[promptId] = os.clock() + RETRY_SECONDS
		return
	end
	fetching[promptId] = true
	task.spawn(function()
		local ok, value = pcall(function()
			return dataStore:GetAsync(promptId)
		end)
		fetching[promptId] = nil
		if ok then
			failures = 0
			cache[promptId] = { data = AnswerStats.sanitize(value), fetchedAt = os.clock() }
		else
			retryAt[promptId] = os.clock() + RETRY_SECONDS
			fail("GetAsync " .. promptId, value)
		end
	end)
end

-- Starts a read when the prompt is not cached or the cache is stale. Never yields.
local function refresh(promptId: string)
	local entry = cache[promptId]
	if entry == nil or os.clock() - entry.fetchedAt > CACHE_SECONDS then
		fetch(promptId)
	end
end

local function record(player: any, promptId: any, answer: any)
	if disabled or store == nil then
		return
	end
	-- Humans only: bots never fire MatchEvents, but a stray table must not be counted either.
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if not validId(promptId) or typeof(answer) ~= "string" then
		return
	end
	local id = promptId :: string
	-- One answer per player per prompt, so replaying a prompt in the lobby cannot skew its numbers.
	local mine = seen[player]
	if mine == nil then
		mine = {}
		seen[player] = mine
	end
	if mine[id] then
		return
	end
	mine[id] = true
	local buffer = pending[id]
	if buffer == nil then
		buffer = AnswerStats.empty()
		pending[id] = buffer
	end
	AnswerStats.record(buffer, answer :: string)
end

-- Writes the pending counts, one UpdateAsync per prompt. `closing` ignores the reserve (the server is going).
local function flush(closing: boolean)
	local dataStore = store
	if dataStore == nil or disabled or flushing then
		return
	end
	flushing = true
	local ids = {}
	for id in pending do
		table.insert(ids, id)
	end
	for _, id in ids do
		if disabled then
			break
		end
		if not hasBudget(Enum.DataStoreRequestType.UpdateAsync, if closing then 0 else BUDGET_RESERVE) then
			break -- the rest wait for the next flush
		end
		local delta = pending[id]
		if delta == nil then
			continue
		end
		pending[id] = nil
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(id, function(old: any)
				return AnswerStats.mergeCounts(old, delta)
			end)
		end)
		if ok then
			failures = 0
			cache[id] = { data = AnswerStats.sanitize(result), fetchedAt = os.clock() }
		else
			-- Put the answers back so the next flush tries again (anything recorded meanwhile is kept too).
			if not disabled then
				pending[id] = AnswerStats.mergeCounts(pending[id], delta)
			end
			fail("UpdateAsync " .. id, result)
		end
	end
	flushing = false
end

-- About how many players give `answer` for this prompt, from recorded counts plus this server's unsaved
-- ones. nil until there is enough data (or while the prompt's counts are still loading).
function AnswerStatsService.oneIn(promptId: string, answer: string?): number?
	if disabled or store == nil or answer == nil or not validId(promptId) then
		return nil
	end
	refresh(promptId)
	local entry = cache[promptId]
	if entry == nil then
		return nil
	end
	local counts = AnswerStats.mergeCounts(entry.data, pending[promptId])
	return AnswerStats.oneInFor(counts, answer, GameConfig.Reveal.StatsMinTotal)
end

-- Debug hook ("stats <promptId>"): a one-line summary of a prompt's recorded counts.
function AnswerStatsService.describe(promptId: string): string
	if store == nil then
		return "answer stats are off (no DataStore access)"
	end
	if disabled then
		return "answer stats switched off after repeated DataStore failures"
	end
	if not validId(promptId) then
		return "not a valid prompt id: " .. tostring(promptId)
	end
	refresh(promptId)
	local unsaved = pending[promptId]
	local suffix = if unsaved ~= nil then string.format(" (%d not saved yet)", unsaved.total) else ""
	local entry = cache[promptId]
	if entry == nil then
		return promptId .. ": loading" .. suffix
	end
	local counts = AnswerStats.mergeCounts(entry.data, unsaved)
	local age = math.floor(os.clock() - entry.fetchedAt)
	return string.format("%s: %s%s [read %ds ago]", promptId, AnswerStats.describe(counts, 5), suffix, age)
end

-- Debug hook: writes pending counts now instead of waiting for the next flush. Yields.
function AnswerStatsService.flush()
	flush(false)
end

function AnswerStatsService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warn("[AnswerStats] no DataStore access, stats are off: " .. tostring(result))
		return
	end
	store = result

	MatchEvents.PromptOpened.connect(function(prompt: { id: string, prompt: string })
		if typeof(prompt) == "table" and validId(prompt.id) then
			refresh(prompt.id)
		end
	end)
	MatchEvents.AnswerGraded.connect(
		function(player: Player, tier: string?, _points: number, promptId: string, answer: string?)
			if tier ~= nil and answer ~= nil then
				record(player, promptId, answer)
			end
		end
	)
	MatchEvents.LobbyAnswered.connect(
		function(player: Player, _tier: string, _points: number, promptId: string, corrected: string)
			record(player, promptId, corrected)
		end
	)
	Players.PlayerRemoving:Connect(function(player)
		seen[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			flush(false)
		end
	end)
	game:BindToClose(function()
		-- A timed flush may be mid-write; let it finish, then write whatever is left.
		local deadline = os.clock() + CLOSE_WAIT_SECONDS
		while flushing and os.clock() < deadline do
			task.wait(0.2)
		end
		flush(true)
	end)
end

return AnswerStatsService
