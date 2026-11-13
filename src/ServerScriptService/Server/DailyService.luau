--!strict
-- The daily reward (Shared/Daily): DailyClaim pays today's Shells, opens the day's free chest if it has
-- one, and saves the claim in the profile (profile.daily, so it lives in the DataStore). DailyResult tells
-- the client what it got. One claim per UTC day; consecutive days climb the week, a missed day starts over.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Net = require(ReplicatedStorage.Shared.Net)
local ChestService = require(script.Parent.ChestService)
local DataService = require(script.Parent.DataService)
local StoreService = require(script.Parent.StoreService)

local COOLDOWN = 1 -- seconds between claim requests from one player

local lastRequest: { [Player]: number } = {}

local DailyService = {}

-- status: "ok" | "claimed" (already claimed today) | "closed" (off, or the profile is not ready)
local function reply(player: Player, payload: Net.DailyResultPayload)
	Net.event("DailyResult"):FireClient(player, payload)
end

local function onClaim(player: Player)
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < COOLDOWN then
		return
	end
	lastRequest[player] = now
	if GameConfig.Daily.Enabled ~= 1 or not DataService.isLoaded(player) or DataService.isReadOnly(player) then
		reply(player, { status = "closed" })
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		reply(player, { status = "closed" })
		return
	end
	local claimed, index = Daily.claim(profile.daily, Daily.today(os.time()))
	if claimed == nil or index == nil then
		reply(player, { status = "claimed" })
		return
	end
	-- The claim is recorded before anything is paid, so a second request can never pay twice.
	DataService.setDaily(player, claimed)
	local reward = Daily.reward(index)
	StoreService.grantShells(player, reward.shells, "daily")
	if reward.chest ~= nil then
		ChestService.openFree(player, reward.chest)
	end
	reply(player, { status = "ok", index = index, shells = reward.shells, chest = reward.chest })
end

function DailyService.start()
	Net.event("DailyClaim").OnServerEvent:Connect(onClaim)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return DailyService
