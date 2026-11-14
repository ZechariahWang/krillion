--!strict
-- Studio-only test hook: ServerStorage.RareOrSinkDebug (a BindableFunction) runs one text command and
-- returns a one-line result. Call it from the server, e.g. ServerStorage.RareOrSinkDebug:Invoke("state").
--   state                                   RoundService.snapshot() as JSON
--   players                                 who is in the server, with user ids
--   shells <user> <n>                       grant n Shells (a negative n spends them)
--   boost <user> <Hint|ExtraTime> <n>       add n boosts to the inventory
--   quest <user> [questId n]                list today's quests, or set one's progress
--   tutorial <user> reset                   clear tutorialDone so the first-visit tutorial shows again
--   stats <promptId>                        recorded answer counts for a prompt
--   flush                                   write pending answer counts now
--   join <user>                             the JoinMatch path (late join), as if the player pressed JOIN
--   erase <userId>                          delete everything saved for a user id (a right-to-erasure request)
--   daily <user> <n>                        set the daily reward as if day n was claimed yesterday (0 clears it)
-- <user> is a user id (negative in local test servers) or a player's name.
-- Inert in live servers: the BindableFunction is only created when RunService:IsStudio().
-- Studio with API access writes the LIVE Profile_v1 DataStore, so shells/boost/quest/tutorial changes persist.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local AnswerStatsService = require(script.Parent.AnswerStatsService)
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)
local RoundService = require(script.Parent.RoundService)
local StoreService = require(script.Parent.StoreService)

local HOOK_NAME = "RareOrSinkDebug"
local MAX_AMOUNT = 1000000 -- keeps a typo from granting a silly number
local PERSIST_NOTE = " (saved to the live profile)"

local BOOST_KINDS: { [string]: string } = {
	hint = "Hint",
	extratime = "ExtraTime",
	time = "ExtraTime",
}

type Command = (args: { string }) -> string

local DebugService = {}

-- A user id (online players only) or a player's Name/DisplayName, case-insensitive.
local function findPlayer(arg: string?): Player?
	if arg == nil then
		return nil
	end
	local id = tonumber(arg)
	if id ~= nil then
		return Players:GetPlayerByUserId(id)
	end
	local lowered = string.lower(arg)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == lowered or string.lower(player.DisplayName) == lowered then
			return player
		end
	end
	return nil
end

local function wholeNumber(arg: string?): number?
	local value = tonumber(arg)
	if value == nil or value ~= math.floor(value) or math.abs(value) > MAX_AMOUNT then
		return nil
	end
	return value
end

local function noPlayer(arg: string?): string
	return `no player "{arg or ""}" in this server (try "players")`
end

-- Looks up the player in args[1] with a loaded profile, or returns why not.
local function loadedPlayer(args: { string }): (Player?, string)
	local player = findPlayer(args[1])
	if player == nil then
		return nil, noPlayer(args[1])
	end
	if not DataService.isLoaded(player) then
		return nil, player.Name .. ": profile not loaded yet"
	end
	return player, ""
end

local commands: { [string]: Command } = {}

commands.state = function()
	local ok, result = pcall(function()
		return HttpService:JSONEncode(RoundService.snapshot())
	end)
	if not ok then
		return "state failed: " .. tostring(result)
	end
	return result
end

commands.players = function()
	local lines = {}
	for _, player in Players:GetPlayers() do
		local loaded = if DataService.isLoaded(player) then "" else " (loading)"
		table.insert(lines, `{player.Name} {player.UserId}{loaded}`)
	end
	if #lines == 0 then
		return "no players"
	end
	return table.concat(lines, ", ")
end

commands.shells = function(args)
	local player, why = loadedPlayer(args)
	if player == nil then
		return why
	end
	local amount = wholeNumber(args[2])
	if amount == nil or amount == 0 then
		return "usage: shells <user> <n>"
	end
	if amount > 0 then
		StoreService.grantShells(player, amount, "reward")
	elseif not StoreService.spendShells(player, -amount, "spend") then
		local profile = DataService.get(player)
		return `{player.Name} has only {if profile ~= nil then profile.cash else 0} Shells`
	end
	local profile = DataService.get(player)
	local now = if profile ~= nil then tostring(profile.cash) else "?"
	local sign = if amount > 0 then "+" else ""
	return `{player.Name}: {sign}{amount} Shells, now {now}{PERSIST_NOTE}`
end

commands.boost = function(args)
	local player, why = loadedPlayer(args)
	if player == nil then
		return why
	end
	local kind = BOOST_KINDS[string.lower(args[2] or "")]
	local count = wholeNumber(args[3])
	if kind == nil or count == nil or count == 0 then
		return "usage: boost <user> <Hint|ExtraTime> <n>"
	end
	local profile = DataService.get(player)
	if profile == nil then
		return player.Name .. ": profile not loaded yet"
	end
	local have = if kind == "Hint" then profile.hints else profile.extraTimes
	-- Never take the inventory below zero.
	count = math.max(count, -have)
	if count == 0 then
		return `{player.Name} has no {kind} boosts to remove`
	end
	DataService.addBoosts(player, kind, count)
	return `{player.Name}: {kind} {have} -> {have + count}{PERSIST_NOTE}`
end

commands.quest = function(args)
	local player, why = loadedPlayer(args)
	if player == nil then
		return why
	end
	local questId = args[2]
	if questId == nil then
		local listed = {}
		for _, quest in Quests.draw(player.UserId, Quests.day(os.time())) do
			table.insert(listed, `{quest.id} (goal {quest.goal})`)
		end
		return `{player.Name}'s quests today: {table.concat(listed, ", ")}`
	end
	local progress = wholeNumber(args[3])
	if progress == nil then
		return "usage: quest <user> <questId> <n>"
	end
	return QuestService.debugSet(player, questId, progress) .. PERSIST_NOTE
end

-- tutorialDone merges as OR, so it is cleared in the saved profile directly. An online player's session
-- flag is cleared too, so their next save does not set it again. The first-visit modal only decides once
-- per join, so they rejoin to see it (the rail's help button opens it any time).
commands.tutorial = function(args)
	if string.lower(args[2] or "") ~= "reset" then
		return "usage: tutorial <user> reset"
	end
	local player = findPlayer(args[1])
	local userId = if player ~= nil then player.UserId else tonumber(args[1])
	if userId == nil then
		return noPlayer(args[1])
	end
	if player ~= nil then
		DataService.creditUser(userId, function(session)
			session.tutorialDone = false
		end)
	end
	local found = false
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(DataService.PROFILE_STORE):UpdateAsync(DataService.keyFor(userId), function(old)
			if typeof(old) ~= "table" then
				return nil
			end
			found = true
			old.tutorialDone = false
			return old
		end)
	end)
	if not ok then
		return "tutorial reset failed: " .. tostring(err)
	end
	if not found then
		return `{userId} has no saved profile, so the tutorial already shows for them`
	end
	return `{userId}: tutorialDone cleared{PERSIST_NOTE}; rejoin to see the first-visit tutorial`
end

commands.stats = function(args)
	local promptId = args[1]
	if promptId == nil then
		return "usage: stats <promptId>"
	end
	return AnswerStatsService.describe(promptId)
end

commands.flush = function()
	AnswerStatsService.flush()
	return "answer counts flushed"
end

-- Puts the daily reward where a test needs it: day n claimed yesterday, so today's claim is day n + 1.
commands.daily = function(args)
	local player, why = loadedPlayer(args)
	if player == nil then
		return why
	end
	local streak = wholeNumber(args[2])
	if streak == nil or streak < 0 then
		return "usage: daily <user> <n>"
	end
	local yesterday = math.floor(os.time() / 86400) - 1
	DataService.setDaily(player, { day = if streak == 0 then 0 else yesterday, streak = streak })
	return `{player.Name}: daily reward set to day {streak} claimed yesterday{PERSIST_NOTE}`
end

-- Takes a number only, never a name: an erasure request names a user id, and this cannot be undone.
commands.erase = function(args)
	local userId = wholeNumber(args[1])
	if userId == nil then
		return "usage: erase <userId>"
	end
	local _, line = DataService.erase(userId)
	return line
end

-- Same as the JoinMatch remote: RoundService.tryJoin does every check, and the client gets its JoinResult.
commands.join = function(args)
	local player = findPlayer(args[1])
	if player == nil then
		return noPlayer(args[1])
	end
	local status, message = RoundService.tryJoin(player)
	Net.event("JoinResult"):FireClient(player, { status = status, message = message })
	return `{player.Name}: {status} ({message})`
end

local HELP = "commands: state, players, shells <user> <n>, boost <user> <Hint|ExtraTime> <n>, "
	.. "quest <user> [questId n], tutorial <user> reset, stats <promptId>, flush, join <user>"

-- Accepts one command line or separate arguments: Invoke("shells -1 500") or Invoke("shells", -1, 500).
local function run(...: any): string
	local words = {}
	for _, part in { ... } do
		for word in string.gmatch(tostring(part), "%S+") do
			table.insert(words, word)
		end
	end
	local name = string.lower(table.remove(words, 1) or "")
	local command = commands[name]
	if command == nil then
		return HELP
	end
	local ok, result = pcall(command, words)
	if not ok then
		return `{name} failed: {result}`
	end
	return result
end

function DebugService.start()
	if not RunService:IsStudio() then
		return
	end
	-- Made at run time rather than in git or the place file, so a live server never has it.
	local existing = ServerStorage:FindFirstChild(HOOK_NAME)
	local hook: BindableFunction
	if existing == nil then
		hook = Instance.new("BindableFunction")
		hook.Name = HOOK_NAME
		hook.Parent = ServerStorage
	elseif existing:IsA("BindableFunction") then
		hook = existing :: BindableFunction
	else
		warn(`DebugService: ServerStorage.{HOOK_NAME} is a {existing.ClassName}, not a BindableFunction`)
		return
	end
	hook.OnInvoke = run
end

return DebugService
