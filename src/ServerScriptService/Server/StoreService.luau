--!strict
-- Game passes, developer product receipts, the shop's buy/equip requests, and every Shells payout or spend
-- the player should see (each one fires ShellsEarned for the client's wallet popups).
-- This is the only ProcessReceipt owner: other services sell products through registerProduct.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Config.Products)
local Shop = require(ReplicatedStorage.Shared.Shop)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)

-- Only these count toward "Shells earned this match" on the results screen.
local MATCH_REASONS = { answer = true, survive = true, win = true }

local passes: { [Player]: { [string]: boolean } } = {}
local productHandlers: { [number]: (Player) -> () } = {}
local earned: { [Player]: number } = {}

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

local function tellWallet(player: Player, amount: number, reason: string?)
	if amount ~= 0 and player.Parent ~= nil then
		Net.event("ShellsEarned"):FireClient(player, { amount = amount, reason = reason })
	end
end

-- Pays earned Shells (never purchased ones) with the player's pass bonuses applied. Returns the amount paid.
-- reason: "answer" | "survive" | "win" | "warmup" | ... (shown under the wallet popup).
function StoreService.payEarned(player: Player, cash: number, reason: string?): number
	local amount = Economy.apply(cash, StoreService.cashMultiplier(player))
	if amount > 0 then
		DataService.addCash(player, amount)
		if reason ~= nil and MATCH_REASONS[reason] then
			earned[player] = (earned[player] or 0) + amount
		end
		tellWallet(player, amount, reason)
	end
	return amount
end

-- Gives Shells exactly as stated, with no pass multiplier (packs, quests, rewards, debug).
function StoreService.grantShells(player: Player, amount: number, reason: string?)
	if amount <= 0 then
		return
	end
	DataService.addCash(player, amount)
	tellWallet(player, amount, reason)
end

-- Spends Shells if the player has enough, and shows the spend in the wallet. Returns whether it was spent.
function StoreService.spendShells(player: Player, amount: number, reason: string?): boolean
	if not DataService.spendCash(player, amount) then
		return false
	end
	tellWallet(player, -amount, reason or "spend")
	return true
end

-- Running total of match Shells (answers, survival, wins) paid to the player while in this server.
-- RoundService diffs it across a match for the results screen.
function StoreService.earnedTotal(player: Player): number
	return earned[player] or 0
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
			if key == "Vip" then
				local bonus = math.floor(GameConfig.Cash.VipBonus * 100 + 0.5)
				NotifyService.send(player, "VIP UNLOCKED!  |  +" .. bonus .. "% " .. Currency.Upper .. ", AURORA PILLAR, GOLD WAKE TRAIL AND VIP TITLE", "good")
			elseif key == "DoubleCash" then
				NotifyService.send(player, "2X " .. Currency.Upper .. " UNLOCKED!", "good")
			end
		end
	end
	DataService.changed(player)
	CosmeticService.refresh(player)
end

-- Sells a developer product: `handler` grants it when a receipt arrives. Product 0 (a placeholder) is ignored.
-- The receipt is recorded with the grant, so a handler runs once per purchase.
function StoreService.registerProduct(productId: number, handler: (Player) -> ())
	if productId ~= 0 then
		productHandlers[productId] = handler
	end
end

local function buildProducts()
	for _, pack in Products.CashPacks do
		StoreService.registerProduct(pack.productId, function(player)
			StoreService.grantShells(player, pack.cash, "purchase")
		end)
	end
	StoreService.registerProduct(Products.Revive.productId, function(player)
		DataService.addRevives(player, 1)
	end)
	for _, item in Cosmetics.List do
		if item.robuxProductId ~= nil then
			StoreService.registerProduct(item.robuxProductId, function(player)
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
	if StoreService.spendShells(player, item.price, "spend") then
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
	DataService.addExtraPayload(function(player)
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
		earned[player] = nil
	end)
end

return StoreService
