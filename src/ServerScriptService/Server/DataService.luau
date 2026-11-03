--!strict
-- Coins only, for now. Increment-only writes (UpdateAsync with a session delta) are safe across
-- servers without session locking. Swap for ProfileStore when XP and quests need a full profile.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local STORE_NAME = "PlayerData_v1"

local store = DataStoreService:GetDataStore(STORE_NAME)
local balance: { [Player]: number } = {}
local delta: { [Player]: number } = {}

local DataService = {}

local function key(player: Player): string
	return "coins_" .. player.UserId
end

local function load(player: Player)
	delta[player] = 0
	local ok, value = pcall(function()
		return store:GetAsync(key(player))
	end)
	local coins = 0
	if ok and typeof(value) == "number" then
		coins = value
	elseif not ok then
		warn("DataService: load failed for " .. player.Name .. ": " .. tostring(value))
	end
	balance[player] = coins + (delta[player] or 0)
	Net.event("CoinsChanged"):FireClient(player, balance[player])
end

local function flush(player: Player)
	local amount = delta[player]
	balance[player] = nil
	delta[player] = nil
	if amount == nil or amount == 0 then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			local current = 0
			if typeof(old) == "number" then
				current = old
			end
			return current + amount
		end)
	end)
	if not ok then
		warn("DataService: flush failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.getCoins(player: Player): number
	return balance[player] or 0
end

function DataService.addCoins(player: Player, amount: number)
	if delta[player] == nil then
		return
	end
	delta[player] += amount
	balance[player] = (balance[player] or 0) + amount
	Net.event("CoinsChanged"):FireClient(player, balance[player])
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	Players.PlayerRemoving:Connect(flush)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			flush(player)
		end
	end)
end

return DataService
