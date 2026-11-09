--!strict
-- Player profiles: Shells (stored as `cash`), Wins, Best, Revives, cosmetics, boosts, quests, rewards.
-- Each server keeps a session of changes and merges it into the saved profile with UpdateAsync
-- (see Profile.merge), so no session locking is needed.
-- Also owns leaderstats, the Wins OrderedDataStore behind the lobby board, and the TutorialDone remote.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PROFILE_STORE = "Profile_v1"
local LEGACY_STORE = "PlayerData_v1"
local WINS_STORE = "Wins_v1"
local AUTOSAVE_SECONDS = 120
local DAY_SECONDS = 86400
local LEAVE_SAVE_TRIES = 3 -- waits 1 s, then 2 s, between tries
local SHUTDOWN_WAIT_SECONDS = 28 -- Roblox allows BindToClose 30 s

-- An unpublished place (a local test copy) has no DataStore access and GetDataStore throws. Players then
-- get a fresh profile that never saves, instead of the error stopping every server script.
local storeWarned = false
local function openStore<T>(open: () -> T): T?
	local ok, result = pcall(open)
	if ok then
		return result
	end
	if not storeWarned then
		storeWarned = true
		warn("DataService: no DataStore access, nothing will save: " .. tostring(result))
	end
	return nil
end

-- Used inside the callers' pcalls, so a missing store takes their normal failed-load/failed-save path.
local function need<T>(store: T?): T
	if store == nil then
		error("no DataStore access", 0)
	end
	return store
end

local profileStore = openStore(function()
	return DataStoreService:GetDataStore(PROFILE_STORE)
end)
local legacyStore = openStore(function()
	return DataStoreService:GetDataStore(LEGACY_STORE)
end)
local winsStore = openStore(function()
	return DataStoreService:GetOrderedDataStore(WINS_STORE)
end)

type LoadInfo = {
	ok: boolean, -- the stored profile was read (a failed read must never look like a new player)
	existed: boolean, -- a profile or a legacy coins save was found
}

local stored: { [Player]: Profile.Profile } = {}
local sessions: { [Player]: Profile.Session } = {}
local inFlight: { [Player]: Profile.Session } = {} -- changes being written right now
local loadInfo: { [Player]: LoadInfo } = {}
local extraPayloads: { (Player) -> { [string]: any } } = {}
local unloading: { [Player]: boolean } = {}
local pendingUnloads = 0

local DataService = {}

-- The profile store's name, for tools (DebugService) that edit a profile directly; key with DataService.keyFor.
DataService.PROFILE_STORE = PROFILE_STORE

-- (player: Player) once the player's profile is loaded and the first ProfileChanged has gone out.
DataService.ProfileLoaded = Signal.new("ProfileLoaded")

function DataService.keyFor(userId: number): string
	return "profile_" .. userId
end

local function profileKey(player: Player): string
	return DataService.keyFor(player.UserId)
end

local function legacyKey(player: Player): string
	return "coins_" .. player.UserId
end

-- The UTC day number, the same one Quests.day uses.
local function today(): number
	return math.floor(os.time() / DAY_SECONDS)
end

-- The player's profile as it stands right now: last saved values plus this session's changes.
function DataService.get(player: Player): Profile.Profile?
	local base = stored[player]
	local session = sessions[player]
	if base == nil or session == nil then
		return nil
	end
	local saving = inFlight[player]
	if saving ~= nil then
		base = Profile.merge(base, saving)
	end
	return Profile.merge(base, session)
end

function DataService.isLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- True only for a first visit: the profile read succeeded and found nothing, not even a legacy save.
function DataService.isNew(player: Player): boolean
	local info = loadInfo[player]
	return info ~= nil and info.ok and not info.existed
end

-- Other services add fields to the ProfileChanged payload (passes, and so on). Every provider is merged.
function DataService.addExtraPayload(fn: (Player) -> { [string]: any })
	table.insert(extraPayloads, fn)
end

local function updateLeaderstats(player: Player, profile: Profile.Profile)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		return
	end
	local wins = stats:FindFirstChild("Wins") :: IntValue?
	-- "Shells" is the player-list name; "Cash" is the old Studio template's, kept as a fallback.
	local shells = (stats:FindFirstChild("Shells") or stats:FindFirstChild("Cash")) :: IntValue?
	local best = stats:FindFirstChild("Best") :: IntValue?
	if wins ~= nil then
		wins.Value = profile.wins
	end
	if shells ~= nil then
		shells.Value = profile.cash
	end
	if best ~= nil then
		best.Value = profile.best
	end
end

function DataService.changed(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	updateLeaderstats(player, profile)
	local payload: { [string]: any } = {}
	for _, provider in extraPayloads do
		local ok, extra = pcall(provider, player)
		if ok and typeof(extra) == "table" then
			for key, value in extra do
				payload[key] = value
			end
		end
	end
	payload.cash = profile.cash
	payload.wins = profile.wins
	payload.best = profile.best
	payload.revives = profile.revives
	payload.owned = profile.owned
	payload.equipped = profile.equipped
	payload.hints = profile.hints
	payload.extraTimes = profile.extraTimes
	payload.tutorialDone = profile.tutorialDone
	payload.claimed = profile.claimed
	payload.referrals = profile.referrals
	payload.quests = profile.quests
	payload.lobbyEarnedToday = Profile.lobbyEarned(profile, today())
	payload.krillions = profile.krillions
	payload.games = profile.games
	payload.musicOff = profile.musicOff
	payload.musicVolume = profile.musicVolume
	Net.event("ProfileChanged"):FireClient(player, payload)
end

local function readStored(player: Player): (Profile.Profile, LoadInfo)
	local ok, value = pcall(function()
		return need(profileStore):GetAsync(profileKey(player))
	end)
	if not ok then
		warn("DataService: load failed for " .. player.Name .. ": " .. tostring(value))
		return Profile.new(), { ok = false, existed = false }
	end
	if value ~= nil then
		return Profile.fromStored(value), { ok = true, existed = true }
	end
	-- First visit since profiles: carry over the old coins-only save. That key is left in place as a backup.
	local legacyOk, legacy = pcall(function()
		return need(legacyStore):GetAsync(legacyKey(player))
	end)
	if legacyOk then
		return Profile.fromStored(legacy), { ok = true, existed = legacy ~= nil }
	end
	return Profile.new(), { ok = false, existed = false }
end

local function load(player: Player)
	local stats = (ReplicatedStorage:WaitForChild("Templates"):WaitForChild("leaderstats") :: Folder):Clone()
	stats.Parent = player
	local profile, info = readStored(player)
	if player.Parent == nil then
		return
	end
	stored[player] = profile
	sessions[player] = Profile.newSession()
	loadInfo[player] = info
	DataService.changed(player)
	DataService.ProfileLoaded.fire(player)
end

-- Writes this session's changes and starts a fresh session on top of the result. Returns whether it saved.
function DataService.save(player: Player): boolean
	local session = sessions[player]
	local base = stored[player]
	if session == nil or base == nil or inFlight[player] ~= nil then
		return false
	end
	sessions[player] = Profile.newSession()
	inFlight[player] = session
	local saved: Profile.Profile? = nil
	local ok, err = pcall(function()
		need(profileStore):UpdateAsync(profileKey(player), function(old)
			local current = base
			if old ~= nil then
				current = Profile.fromStored(old)
			end
			saved = Profile.merge(current, session)
			return saved
		end)
	end)
	inFlight[player] = nil
	if not ok or saved == nil then
		warn("DataService: save failed for " .. player.Name .. ": " .. tostring(err))
		-- Put the changes back, ahead of anything that happened during the save, so the next save retries them.
		local pending = sessions[player]
		if pending ~= nil then
			sessions[player] = Profile.combine(session, pending)
		end
		return false
	end
	local result = saved :: Profile.Profile
	stored[player] = result
	if session.wins > 0 then
		pcall(function()
			need(winsStore):SetAsync(tostring(player.UserId), result.wins)
		end)
	end
	return true
end

local function session(player: Player): Profile.Session?
	return sessions[player]
end

function DataService.addCash(player: Player, amount: number)
	local current = session(player)
	if current == nil then
		return
	end
	current.cash += amount
	DataService.changed(player)
end

-- Spends cash if the player has enough. Returns whether it was spent.
-- Prefer StoreService.spendShells, which also tells the client's wallet.
function DataService.spendCash(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	local current = session(player)
	if profile == nil or current == nil or profile.cash < amount then
		return false
	end
	current.cash -= amount
	DataService.changed(player)
	return true
end

function DataService.addWin(player: Player)
	local current = session(player)
	if current == nil then
		return
	end
	current.wins += 1
	DataService.changed(player)
end

function DataService.recordHeight(player: Player, height: number)
	local current = session(player)
	local profile = DataService.get(player)
	if current == nil or profile == nil then
		return
	end
	local whole = math.floor(height)
	if whole <= profile.best then
		return
	end
	current.best = whole
	DataService.changed(player)
end

function DataService.addRevives(player: Player, count: number)
	local current = session(player)
	if current == nil then
		return
	end
	current.revives += count
	DataService.changed(player)
end

-- kind: "Hint" | "ExtraTime". Adds to the boost inventory (Robux products, debug grants).
function DataService.addBoosts(player: Player, kind: string, count: number)
	local current = session(player)
	if current == nil then
		return
	end
	if kind == "Hint" then
		current.hints += count
	elseif kind == "ExtraTime" then
		current.extraTimes += count
	else
		return
	end
	DataService.changed(player)
end

-- Uses one boost from the inventory. Returns whether there was one.
function DataService.spendBoost(player: Player, kind: string): boolean
	local profile = DataService.get(player)
	local current = session(player)
	if profile == nil or current == nil then
		return false
	end
	if kind == "Hint" and profile.hints > 0 then
		current.hints -= 1
	elseif kind == "ExtraTime" and profile.extraTimes > 0 then
		current.extraTimes -= 1
	else
		return false
	end
	DataService.changed(player)
	return true
end

-- Lifetime counters. key: "krillions" | "games".
function DataService.addCounter(player: Player, key: string, count: number)
	local current = session(player)
	if current == nil then
		return
	end
	if key == "krillions" then
		current.krillions += count
	elseif key == "games" then
		current.games += count
	else
		return
	end
	DataService.changed(player)
end

-- Marks a one-time grant as taken. Returns true only the first time, so the caller grants exactly then.
-- Per server and best effort: two servers loading the same player before either saves could both say true.
function DataService.claim(player: Player, id: string): boolean
	local profile = DataService.get(player)
	local current = session(player)
	if profile == nil or current == nil or profile.claimed[id] == true then
		return false
	end
	current.claimed[id] = true
	DataService.changed(player)
	return true
end

-- Hands back a claim made this session whose grant failed, so a later try can claim it again. A claim an
-- autosave already wrote stays taken.
function DataService.unclaim(player: Player, id: string)
	local current = session(player)
	if current == nil or current.claimed[id] == nil then
		return
	end
	current.claimed[id] = nil
	DataService.changed(player)
end

function DataService.isClaimed(player: Player, id: string): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.claimed[id] == true
end

function DataService.setTutorialDone(player: Player)
	local current = session(player)
	if current == nil or current.tutorialDone then
		return
	end
	current.tutorialDone = true
	DataService.changed(player)
end

-- The player's background music choice from Settings; saved with the profile.
function DataService.setMusicOff(player: Player, off: boolean)
	local current = session(player)
	if current == nil then
		return
	end
	current.musicOff = off
	DataService.changed(player)
end

-- The Settings volume bar (0..1); saved with the profile.
function DataService.setMusicVolume(player: Player, volume: number)
	local current = session(player)
	if current == nil then
		return
	end
	current.musicVolume = math.clamp(volume, 0, 1)
	DataService.changed(player)
end

-- Sets one daily quest's absolute progress for `day` (Quests.day). An older day than the session's is ignored.
function DataService.setQuest(player: Player, day: number, id: string, progress: number, done: boolean)
	local current = session(player)
	if current == nil then
		return
	end
	local quests = current.quests
	if day < quests.day then
		return
	end
	if day > quests.day then
		-- A new day starts from what was saved for it, if anything (usually nothing).
		local profile = DataService.get(player)
		quests = { day = day, progress = {}, done = {} }
		if profile ~= nil and profile.quests.day == day then
			for questId, amount in profile.quests.progress do
				quests.progress[questId] = amount
			end
			for questId in profile.quests.done do
				quests.done[questId] = true
			end
		end
		current.quests = quests
	end
	quests.progress[id] = progress
	if done then
		quests.done[id] = true
	end
	DataService.changed(player)
end

-- Warm-up Shells already paid on `day`, for the daily cap.
function DataService.lobbyEarnedToday(player: Player, day: number): number
	local profile = DataService.get(player)
	if profile == nil then
		return 0
	end
	return Profile.lobbyEarned(profile, day)
end

function DataService.addLobbyEarned(player: Player, day: number, amount: number)
	local current = session(player)
	if current == nil then
		return
	end
	local lobby = current.lobby
	if day > lobby.day then
		current.lobby = { day = day, earned = amount }
	elseif day == lobby.day then
		lobby.earned += amount
	else
		return
	end
	DataService.changed(player)
end

-- Records the friend whose invite brought this player. Returns false if one is already recorded.
function DataService.setReferredBy(player: Player, userId: number): boolean
	local profile = DataService.get(player)
	local current = session(player)
	if profile == nil or current == nil or profile.referredBy ~= 0 or userId <= 0 then
		return false
	end
	current.referredBy = userId
	DataService.changed(player)
	return true
end

-- Changes another user's profile, whether or not they are in this server: `apply` edits a session of
-- deltas, which goes into the live session here or is merged into their saved profile with UpdateAsync.
-- Yields (DataStore). Returns whether the change was recorded. Users without a saved profile are skipped.
function DataService.creditUser(userId: number, apply: (Profile.Session) -> ()): boolean
	local online = Players:GetPlayerByUserId(userId)
	if online ~= nil then
		local current = sessions[online]
		if current ~= nil then
			apply(current)
			DataService.changed(online)
			return true
		end
	end
	local delta = Profile.newSession()
	apply(delta)
	local wrote = false
	local ok, err = pcall(function()
		need(profileStore):UpdateAsync(DataService.keyFor(userId), function(old)
			if old == nil then
				return nil
			end
			wrote = true
			return Profile.merge(Profile.fromStored(old), delta)
		end)
	end)
	if not ok then
		warn("DataService: credit failed for " .. userId .. ": " .. tostring(err))
		return false
	end
	return wrote
end

function DataService.grantItem(player: Player, id: string)
	local current = session(player)
	if current == nil then
		return
	end
	current.owned[id] = true
	DataService.changed(player)
end

function DataService.equip(player: Player, slot: string, id: string)
	local current = session(player)
	if current == nil then
		return
	end
	(current.equipped :: any)[slot] = id
	DataService.changed(player)
end

function DataService.hasReceipt(player: Player, receipt: string): boolean
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	return Profile.hasReceipt(profile, receipt)
end

function DataService.addReceipt(player: Player, receipt: string)
	local current = session(player)
	if current ~= nil then
		table.insert(current.receipts, receipt)
	end
end

-- Top players by wins, best first, as { userId, wins }.
function DataService.topWins(count: number): { { userId: number, wins: number } }
	local result = {}
	local ok, err = pcall(function()
		local pages = need(winsStore):GetSortedAsync(false, count)
		for _, entry in pages:GetCurrentPage() do
			table.insert(result, { userId = tonumber(entry.key) or 0, wins = entry.value })
		end
	end)
	if not ok then
		warn("DataService: leaderboard read failed: " .. tostring(err))
	end
	return result
end

-- The leave-save retries, and the profile stays in memory until it lands or the last try fails.
local function unload(player: Player)
	if unloading[player] then
		return
	end
	unloading[player] = true
	pendingUnloads += 1
	if sessions[player] ~= nil then
		for attempt = 1, LEAVE_SAVE_TRIES do
			while inFlight[player] ~= nil do
				task.wait(0.1)
			end
			if DataService.save(player) then
				break
			end
			if attempt < LEAVE_SAVE_TRIES then
				task.wait(attempt)
			end
		end
	end
	stored[player] = nil
	sessions[player] = nil
	loadInfo[player] = nil
	unloading[player] = nil
	pendingUnloads -= 1
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(unload)
	-- The client asks once its listeners are connected: the first ProfileChanged often goes out before that.
	-- A profile still loading pushes itself when it lands.
	Net.event("ProfileRequest").OnServerEvent:Connect(function(player)
		if DataService.isLoaded(player) then
			DataService.changed(player)
		end
	end)
	-- The client fires this when the first-time tutorial is finished (or skipped).
	Net.event("TutorialDone").OnServerEvent:Connect(function(player)
		DataService.setTutorialDone(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(unload, player)
		end
		local waited = 0
		while pendingUnloads > 0 and waited < SHUTDOWN_WAIT_SECONDS do
			waited += task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.save, player)
			end
		end
	end)
end

return DataService
