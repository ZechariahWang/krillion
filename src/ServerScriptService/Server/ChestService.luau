--!strict
-- Treasure chests (Config/Chests): ChestOpen(chestId) spends the chest's Shells price, rolls one item with the
-- shown odds and grants it, or pays DuplicateRefund of the price back when it is already owned. ChestResult
-- tells the client what came out. Players whose PolicyService info says paid random items are restricted
-- where they live never see chests (the `chestsAllowed` payload flag) and the server refuses to open them.
-- While the lookup has not answered, `chestsAllowed` is nil and opens are refused with "unknown".

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

local POLICY_WAITS = { 10, 20 } -- seconds before the second and third policy lookup

local allowed: { [Player]: boolean } = {} -- nil until the policy lookup answers; false blocks chests
local lookingUp: { [Player]: boolean } = {}
local lastOpen: { [Player]: number } = {}
local opened: { [Player]: number } = {}
local random = Random.new()

local ChestService = {}

local function lookupPolicy(player: Player): boolean?
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		return info.ArePaidRandomItemsRestricted == false
	end
	warn("ChestService: policy lookup failed for " .. player.Name .. ": " .. tostring(info))
	return nil
end

-- Paid random items are refused until Roblox says they are fine for this player. Failed lookups retry;
-- if every try fails the answer stays unknown until the player tries a chest again. Studio, where the
-- lookup can fail, allows chests so testing works.
local function loadPolicy(player: Player)
	if lookingUp[player] then
		return
	end
	lookingUp[player] = true
	local answer = lookupPolicy(player)
	for _, seconds in POLICY_WAITS do
		if answer ~= nil or player.Parent == nil then
			break
		end
		task.wait(seconds)
		answer = lookupPolicy(player)
	end
	lookingUp[player] = nil
	if player.Parent == nil then
		return
	end
	if answer == nil and RunService:IsStudio() then
		answer = true
	end
	if answer ~= nil then
		allowed[player] = answer
	end
	DataService.changed(player)
end

function ChestService.allowed(player: Player): boolean
	return allowed[player] == true
end

local function reply(player: Player, payload: { [string]: any })
	Net.event("ChestResult"):FireClient(player, payload)
end

-- Rolls one item from the chest and grants it, or pays the duplicate refund when it is already owned. The
-- caller has taken any payment.
local function rollAndGrant(player: Player, chest: Chests.Chest)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local itemId = Chests.roll(chest, random:NextNumber())
	local item = Cosmetics.ById[itemId]
	if item == nil then
		warn("ChestService: " .. chest.id .. " rolled unknown item " .. tostring(itemId) .. "; refunding")
		StoreService.grantShells(player, chest.price, "refund")
		return reply(player, { chest = chest.id, status = "refunded", refund = chest.price })
	end
	local duplicate = profile.owned[itemId] == true
	local refund = 0
	if duplicate then
		refund = Chests.refund(chest)
		StoreService.grantShells(player, refund, "refund")
	else
		DataService.grantItem(player, itemId)
		DataService.equip(player, item.slot, itemId)
		CosmeticService.refresh(player)
	end
	reply(player, { chest = chest.id, status = "ok", item = itemId, duplicate = duplicate, refund = refund })
end

local function open(player: Player, chestId: any)
	if typeof(chestId) ~= "string" then
		return
	end
	local chest = Chests.ById[chestId]
	if chest == nil then
		return
	end
	if allowed[player] == nil then
		task.spawn(loadPolicy, player)
		return reply(player, { chest = chestId, status = "unknown" })
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
	rollAndGrant(player, chest)
end

-- Opens a chest that was given, not bought (the daily reward): no price, no cooldown, and no policy check,
-- because nothing is paid for it. The client hears ChestResult as for any chest.
function ChestService.openFree(player: Player, chestId: string)
	local chest = Chests.ById[chestId]
	if chest ~= nil and DataService.get(player) ~= nil then
		rollAndGrant(player, chest)
	end
end

function ChestService.start()
	DataService.addExtraPayload(function(player)
		return { chestsAllowed = allowed[player] }
	end)
	Net.event("ChestOpen").OnServerEvent:Connect(open)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPolicy, player)
	end
	Players.PlayerAdded:Connect(loadPolicy)
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
		lookingUp[player] = nil
		lastOpen[player] = nil
		opened[player] = nil
	end)
end

return ChestService
