--!strict
-- Player profiles: Cash, Wins, Best, Revives, cosmetics. Each server keeps a session of changes and merges
-- it into the saved profile with UpdateAsync (see Profile.merge), so no session locking is needed.
-- Also owns leaderstats and the Wins OrderedDataStore behind the lobby board.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)

local PROFILE_STORE = "Profile_v1"
local LEGACY_STORE = "PlayerData_v1"
local WINS_STORE = "Wins_v1"
local AUTOSAVE_SECONDS = 120

local profileStore = DataStoreService:GetDataStore(PROFILE_STORE)
local legacyStore = DataStoreService:GetDataStore(LEGACY_STORE)
local winsStore = DataStoreService:GetOrderedDataStore(WINS_STORE)

local stored: { [Player]: Profile.Profile } = {}
local sessions: { [Player]: Profile.Session } = {}
local inFlight: { [Player]: Profile.Session } = {} -- changes being written right now
local extraPayload: (Player) -> { [string]: any } = function()
	return {}
end

local DataService = {}

local function profileKey(player: Player): string
	return "profile_" .. player.UserId
end

local function legacyKey(player: Player): string
	return "coins_" .. player.UserId
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

-- Other services add fields to the ProfileChanged payload (for example which passes the player holds).
function DataService.setExtraPayload(fn: (Player) -> { [string]: any })
	extraPayload = fn
end

local function updateLeaderstats(player: Player, profile: Profile.Profile)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		return
	end
	local wins = stats:FindFirstChild("Wins") :: IntValue?
	local cash = stats:FindFirstChild("Cash") :: IntValue?
	local best = stats:FindFirstChild("Best") :: IntValue?
	if wins ~= nil then
		wins.Value = profile.wins
	end
	if cash ~= nil then
		cash.Value = profile.cash
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
	local payload = extraPayload(player)
	payload.cash = profile.cash
	payload.wins = profile.wins
	payload.best = profile.best
	payload.revives = profile.revives
	payload.owned = profile.owned
	payload.equipped = profile.equipped
	Net.event("ProfileChanged"):FireClient(player, payload)
end

local function readStored(player: Player): Profile.Profile
	local ok, value = pcall(function()
		return profileStore:GetAsync(profileKey(player))
	end)
	if not ok then
		warn("DataService: load failed for " .. player.Name .. ": " .. tostring(value))
		return Profile.new()
	end
	if value ~= nil then
		return Profile.fromStored(value)
	end
	-- First visit since profiles: carry over the old coins-only save. That key is left in place as a backup.
	local legacyOk, legacy = pcall(function()
		return legacyStore:GetAsync(legacyKey(player))
	end)
	if legacyOk then
		return Profile.fromStored(legacy)
	end
	return Profile.new()
end

local function load(player: Player)
	local stats = (ReplicatedStorage:WaitForChild("Templates"):WaitForChild("leaderstats") :: Folder):Clone()
	stats.Parent = player
	local profile = readStored(player)
	if player.Parent == nil then
		return
	end
	stored[player] = profile
	sessions[player] = Profile.newSession()
	DataService.changed(player)
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
		profileStore:UpdateAsync(profileKey(player), function(old)
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
			winsStore:SetAsync(tostring(player.UserId), result.wins)
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
		local pages = winsStore:GetSortedAsync(false, count)
		for _, entry in pages:GetCurrentPage() do
			table.insert(result, { userId = tonumber(entry.key) or 0, wins = entry.value })
		end
	end)
	if not ok then
		warn("DataService: leaderboard read failed: " .. tostring(err))
	end
	return result
end

local function unload(player: Player)
	while inFlight[player] ~= nil do
		task.wait(0.1)
	end
	DataService.save(player)
	stored[player] = nil
	sessions[player] = nil
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(unload)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(unload, player)
		end
		task.wait(3)
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
