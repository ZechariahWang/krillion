--!strict
-- Counts the answers the bank refuses, per prompt, in a DataStore, so the bank can be given what players
-- really type. Only counts are kept, with no player attached, and only short answer-like text
-- (Shared/AnswerMisses.key drops sentences, long numbers, addresses and mashing). A player adds at most
-- GameConfig.Answer.MissesPerPrompt different misses to one prompt per visit, which slows flooding; someone
-- who rejoins over and over can still add junk, and the cap (GameConfig.Answer.MissCap answers per prompt)
-- washes one-off junk out again.
-- Misses are buffered and merged in with one UpdateAsync per prompt every FLUSH_SECONDS and on close.
-- Repeated DataStore failures switch it off.
-- Read them in Studio with the debug command "misses" (DebugService): it lists what the bank still refuses,
-- and "misses forget" removes an entry nobody should have typed.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AnswerMatcher = require(ReplicatedStorage.Shared.AnswerMatcher)
local AnswerMisses = require(ReplicatedStorage.Shared.AnswerMisses)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local MatchEvents = require(script.Parent.MatchEvents)
local PromptBank = require(ServerStorage.PromptBank)

-- Studio with API access shares the live universe's DataStores, so test misses go to their own store.
local LIVE_STORE = "AnswerMisses_v1"
local STUDIO_STORE = "AnswerMisses_v1_Studio"
local STORE_NAME = if RunService:IsStudio() then STUDIO_STORE else LIVE_STORE
local FLUSH_SECONDS = 120
local MAX_FAILURES = 3 -- consecutive DataStore failures before recording switches off for this server
local BUDGET_RESERVE = 20 -- requests left for profile saves before misses wait for the next flush
local MAX_KEY_LENGTH = 50 -- DataStore key limit
local CLOSE_WAIT_SECONDS = 20
local READ_LIMIT = 200 -- stored answers the "misses" command grades against the bank at most

type Mine = { count: number, seen: { [string]: boolean } }

local store: DataStore? = nil
local disabled = false
local failures = 0
local flushing = false

local pending: { [string]: AnswerMisses.Counts } = {} -- promptId -> misses not yet written
local given: { [Player]: { [string]: Mine } } = {} -- what each player already added, by prompt id

local AnswerMissService = {}

local function fail(what: string, err: any)
	failures += 1
	warn(string.format("[AnswerMisses] %s failed (%d/%d): %s", what, failures, MAX_FAILURES, tostring(err)))
	if failures >= MAX_FAILURES and not disabled then
		disabled = true
		pending = {}
		warn("[AnswerMisses] switched off for this server")
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

local function record(player: any, promptId: any, text: any)
	if disabled or store == nil or GameConfig.Answer.RecordMisses ~= 1 then
		return
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if not validId(promptId) or typeof(text) ~= "string" then
		return
	end
	local id = promptId :: string
	local key = AnswerMisses.key(text :: string)
	if key == nil then
		return
	end
	local prompts = given[player]
	if prompts == nil then
		prompts = {}
		given[player] = prompts
	end
	local mine = prompts[id]
	if mine == nil then
		mine = { count = 0, seen = {} }
		prompts[id] = mine
	end
	-- The same miss twice, or a string of guesses, counts once and stops at the limit.
	if mine.seen[key] or mine.count >= GameConfig.Answer.MissesPerPrompt then
		return
	end
	mine.seen[key] = true
	mine.count += 1
	local buffer = pending[id]
	if buffer == nil then
		buffer = AnswerMisses.empty()
		pending[id] = buffer
	end
	AnswerMisses.record(buffer, key)
end

-- Writes the pending misses, one UpdateAsync per prompt. `closing` ignores the reserve (the server is going).
local function flush(closing: boolean)
	local dataStore = store
	if dataStore == nil or disabled or flushing then
		return
	end
	flushing = true
	local cap = GameConfig.Answer.MissCap
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
				return AnswerMisses.merge(old, delta, cap)
			end)
		end)
		if ok then
			failures = 0
		else
			-- Put the misses back so the next flush tries again (anything recorded meanwhile is kept too).
			if not disabled then
				pending[id] = AnswerMisses.merge(pending[id], delta, math.huge)
			end
			fail("UpdateAsync " .. id, result)
		end
	end
	flushing = false
end

-- Debug hook: writes pending misses now instead of waiting for the next flush. Yields.
function AnswerMissService.flush()
	flush(false)
end

-- Debug hook ("misses <promptId> [n] [studio]"): the n most refused answers the bank still refuses, from
-- the live store, or from this Studio's own test store (with what is not saved yet) when `studio`. Yields.
function AnswerMissService.describe(promptId: string, limit: number, studio: boolean): string
	if not validId(promptId) then
		return "not a valid prompt id: " .. tostring(promptId)
	end
	local prompt = PromptBank.ById[promptId]
	if prompt == nil then
		return "no prompt called " .. promptId
	end
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore(if studio then STUDIO_STORE else LIVE_STORE):GetAsync(promptId)
	end)
	if not ok then
		return "misses could not be read: " .. tostring(value)
	end
	local counts = AnswerMisses.merge(value, if studio then pending[promptId] else nil, math.huge)
	-- Grading is the slow part, so only the most refused are graded: plenty to fill the list.
	local graded = 0
	local rows = AnswerMisses.top(counts, limit, 1, function(answer: string): boolean
		graded += 1
		if graded > READ_LIMIT then
			return false
		end
		if graded % 20 == 0 then
			task.wait()
		end
		return AnswerMatcher.match(answer, prompt) == nil
	end)
	return promptId .. (if studio then " (studio)" else "") .. ": " .. AnswerMisses.describe(counts.total, rows)
end

-- Debug hook ("misses forget <promptId> <answer> [studio]"): removes one stored answer, for text that
-- should not be kept. This is the one command that changes the live store. Yields.
function AnswerMissService.forget(promptId: string, answer: string, studio: boolean): string
	if not validId(promptId) then
		return "not a valid prompt id: " .. tostring(promptId)
	end
	local key = AnswerMatcher.normalize(answer)
	local had = false
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(if studio then STUDIO_STORE else LIVE_STORE):UpdateAsync(promptId, function(old: any)
			if old == nil then
				return nil
			end
			had = AnswerMisses.merge(old, nil, math.huge).counts[key] ~= nil
			return AnswerMisses.without(old, key)
		end)
	end)
	if not ok then
		return "forget failed: " .. tostring(err)
	end
	local unsaved = pending[promptId]
	if studio and unsaved ~= nil and unsaved.counts[key] ~= nil then
		unsaved.counts[key] = nil
		had = true
	end
	local where = promptId .. (if studio then " (studio)" else "")
	return if had then string.format("%s: forgot %q", where, key) else string.format("%s: has no %q", where, key)
end

-- Debug hook ("misses"): the prompt ids that have misses recorded in the live store (or the Studio one).
function AnswerMissService.prompts(studio: boolean): string
	local ids = {}
	local ok, err = pcall(function()
		local dataStore = DataStoreService:GetDataStore(if studio then STUDIO_STORE else LIVE_STORE)
		local pages = dataStore:ListKeysAsync(nil, 100)
		while true do
			for _, key in pages:GetCurrentPage() do
				table.insert(ids, key.KeyName)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		return "misses could not be listed: " .. tostring(err)
	end
	table.sort(ids)
	if #ids == 0 then
		return "no misses recorded yet"
	end
	return #ids .. " prompts with misses: " .. table.concat(ids, ", ")
end

function AnswerMissService.start()
	if GameConfig.Answer.RecordMisses ~= 1 then
		return
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warn("[AnswerMisses] no DataStore access, refused answers are not recorded: " .. tostring(result))
		return
	end
	store = result

	MatchEvents.AnswerRefused.connect(record)
	Players.PlayerRemoving:Connect(function(player)
		given[player] = nil
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

return AnswerMissService
