--!strict
-- Treasure chests (Config/Chests): ChestOpen(chestId) spends the chest's Shells price, rolls one item with the
-- shown odds and grants it, or pays DuplicateRefund of the price back when it is already owned. ChestResult
-- tells the client what came out. Players whose PolicyService info says paid random items are restricted
-- where they live never see chests (the `chestsAllowed` payload flag) and the server refuses to open them.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Chests = require(ReplicatedStorage.Config.Chests)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local StoreService = require(script.Parent.StoreService)

local allowed: { [Player]: boolean } = {} -- nil until the policy lookup answers; false blocks chests
local lastOpen: { [Player]: number } = {}
local opened: { [Player]: number } = {}
local random = Random.new()

local ChestService = {}

-- Paid random items are refused until Roblox says they are fine for this player, and on a failed lookup
-- (except in Studio, where the lookup can fail and testing needs chests).
local function loadPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		allowed[player] = info.ArePaidRandomItemsRestricted == false
	else
		allowed[player] = RunService:IsStudio()
	end
	DataService.changed(player)
end

function ChestService.allowed(player: Player): boolean
	return allowed[player] == true
end

local function reply(player: Player, payload: { [string]: any })
	Net.event("ChestResult"):FireClient(player, payload)
end

local function open(player: Player, chestId: any)
	if typeof(chestId) ~= "string" then
		return
	end
	local chest = Chests.ById[chestId]
	if chest == nil then
		return
	end
	if not ChestService.allowed(player) then
		return reply(player, { chest = chestId, status = "restricted" })
	end
	local now = os.clock()
	if now - (lastOpen[player] or -math.huge) < GameConfig.Cash.ChestCooldown then
		return reply(player, { chest = chestId, status = "cooldown" })
	end
	if (opened[player] or 0) >= GameConfig.Cash.ChestSessionLimit then
		return reply(player, { chest = chestId, status = "limit" })
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not StoreService.spendShells(player, chest.price, "spend") then
		return reply(player, { chest = chestId, status = "no_shells" })
	end
	lastOpen[player] = now
	opened[player] = (opened[player] or 0) + 1

	local itemId = Chests.roll(chest, random:NextNumber())
	local item = Cosmetics.ById[itemId]
	local duplicate = profile.owned[itemId] == true
	local refund = 0
	if duplicate then
		refund = Chests.refund(chest)
		StoreService.grantShells(player, refund, "refund")
	elseif item ~= nil then
		DataService.grantItem(player, itemId)
		DataService.equip(player, item.slot, itemId)
		CosmeticService.refresh(player)
	end
	reply(player, { chest = chestId, status = "ok", item = itemId, duplicate = duplicate, refund = refund })
end

function ChestService.start()
	DataService.addExtraPayload(function(player)
		return { chestsAllowed = ChestService.allowed(player) }
	end)
	Net.event("ChestOpen").OnServerEvent:Connect(open)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPolicy, player)
	end
	Players.PlayerAdded:Connect(loadPolicy)
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
		lastOpen[player] = nil
		opened[player] = nil
	end)
end

return ChestService
