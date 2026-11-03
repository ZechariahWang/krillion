--!strict
-- Game passes, developer product receipts, and the shop's buy/equip requests.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Config.Products)
local Shop = require(ReplicatedStorage.Shared.Shop)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)

local passes: { [Player]: { [string]: boolean } } = {}
local productHandlers: { [number]: (Player) -> () } = {}

local StoreService = {}

function StoreService.passesOf(player: Player): { [string]: boolean }
	return passes[player] or {}
end

function StoreService.ownsPass(player: Player, key: string): boolean
	return StoreService.passesOf(player)[key] == true
end

function StoreService.cashMultiplier(player: Player): number
	return Economy.multiplier(StoreService.ownsPass(player, "Vip"), StoreService.ownsPass(player, "DoubleCash"))
end

-- Pays earned cash (never purchased cash) with the player's pass bonuses applied. Returns the amount paid.
function StoreService.payEarned(player: Player, cash: number): number
	local amount = Economy.apply(cash, StoreService.cashMultiplier(player))
	if amount > 0 then
		DataService.addCash(player, amount)
	end
	return amount
end

local function loadPasses(player: Player)
	local owned = {}
	for key, passId in Products.Passes do
		if passId ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			owned[key] = ok and has == true
		end
	end
	passes[player] = owned
	-- Titles need the profile too, so wait for it before the first refresh.
	local waited = 0
	while not DataService.isLoaded(player) and player.Parent ~= nil and waited < 30 do
		waited += task.wait(0.5)
	end
	DataService.changed(player)
	CosmeticService.refresh(player)
end

local function onPassBought(player: Player, passId: number, bought: boolean)
	if not bought then
		return
	end
	local owned = passes[player]
	if owned == nil then
		owned = {}
		passes[player] = owned
	end
	for key, id in Products.Passes do
		if id == passId and id ~= 0 then
			owned[key] = true
		end
	end
	DataService.changed(player)
	CosmeticService.refresh(player)
end

local function addProduct(productId: number, handler: (Player) -> ())
	-- 0 is the placeholder id; nothing is sold under it.
	if productId ~= 0 then
		productHandlers[productId] = handler
	end
end

local function buildProducts()
	for _, pack in Products.CashPacks do
		addProduct(pack.productId, function(player)
			DataService.addCash(player, pack.cash)
		end)
	end
	addProduct(Products.Revive.productId, function(player)
		DataService.addRevives(player, 1)
	end)
	for _, item in Cosmetics.List do
		if item.robuxProductId ~= nil then
			addProduct(item.robuxProductId, function(player)
				DataService.grantItem(player, item.id)
			end)
		end
	end
end

-- Grants once per receipt: the receipt id is stored with the grant and checked before granting.
local function processReceipt(info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil or not DataService.isLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipt = tostring(info.PurchaseId)
	if DataService.hasReceipt(player, receipt) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local handler = productHandlers[info.ProductId]
	if handler == nil then
		warn("StoreService: no handler for product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	handler(player)
	DataService.addReceipt(player, receipt)
	if DataService.save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- The grant and receipt stay in the session and are saved later; a retry sees the receipt.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onBuy(player: Player, itemId: any)
	if typeof(itemId) ~= "string" then
		return
	end
	local item = Cosmetics.ById[itemId]
	local profile = DataService.get(player)
	if item == nil or profile == nil then
		return
	end
	if not Shop.canBuyWithCash(profile, item) then
		return
	end
	if DataService.spendCash(player, item.price) then
		DataService.grantItem(player, item.id)
		DataService.equip(player, item.slot, item.id)
		CosmeticService.refresh(player)
	end
end

local function onEquip(player: Player, slot: any, itemId: any)
	if typeof(slot) ~= "string" or Cosmetics.Slots[slot] == nil or typeof(itemId) ~= "string" then
		return
	end
	if itemId == "" then
		DataService.equip(player, slot, "")
		CosmeticService.refresh(player)
		return
	end
	local item = Cosmetics.ById[itemId]
	local profile = DataService.get(player)
	if item == nil or profile == nil or item.slot ~= slot then
		return
	end
	if not Shop.canEquip(profile, item, StoreService.passesOf(player)) then
		return
	end
	DataService.equip(player, slot, item.id)
	CosmeticService.refresh(player)
end

function StoreService.start()
	buildProducts()
	DataService.setExtraPayload(function(player)
		return { passes = StoreService.passesOf(player) }
	end)
	CosmeticService.setPassLookup(StoreService.passesOf)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassBought)
	Net.event("ShopBuy").OnServerEvent:Connect(onBuy)
	Net.event("ShopEquip").OnServerEvent:Connect(onEquip)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerAdded:Connect(loadPasses)
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
	end)
end

return StoreService
