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

-- A Robux item bought again (it can only happen through a stale shop) pays this many Shells per Robux.
local SHELLS_PER_ROBUX = 20
local PASS_CHECK_COOLDOWN = 15 -- seconds between pass re-checks a player's shop can ask for

local PASS_MESSAGES: { [string]: string } = {
	Vip = "VIP UNLOCKED!  |  +"
		.. math.floor(GameConfig.Cash.VipBonus * 100 + 0.5)
		.. "% "
		.. Currency.Upper
		.. ", AURORA PILLAR, GOLD WAKE TRAIL, VIP TITLE AND TAG",
	DoubleCash = "2X " .. Currency.Upper .. " UNLOCKED!",
	SecondChance = "SECOND CHANCE UNLOCKED!  |  ONE FREE REVIVE EVERY MATCH",
	BoostPlus = "BOOST PLUS UNLOCKED!  |  " .. GameConfig.Boosts.PerMatchPlus .. " +TIME PER MATCH",
}

local lastPassCheck: { [Player]: number } = {}

local passes: { [Player]: { [string]: boolean } } = {}
local productHandlers: { [number]: (Player) -> () } = {}

local StoreService = {}

function StoreService.passesOf(player: Player): { [string]: boolean }
	return passes[player] or {}
end

function StoreService.ownsPass(player: Player, key: string): boolean
	return StoreService.passesOf(player)[key] == true
end

-- VIP + 2x Shells + the equipped pet's bonus. Earned Shells only (payEarned); never packs or rewards.
function StoreService.cashMultiplier(player: Player): number
	local owned = StoreService.passesOf(player)
	local profile = DataService.get(player)
	local petBonus = if profile ~= nil then Shop.petBonus(profile, owned) else 0
	return Economy.multiplier(owned.Vip == true, owned.DoubleCash == true, petBonus)
end

local function tellWallet(player: Player, amount: number, reason: string?)
	if amount ~= 0 and player.Parent ~= nil then
		Net.event("ShellsEarned"):FireClient(player, { amount = amount, reason = reason })
	end
end

-- Pays earned Shells (never purchased ones) with the player's pass bonuses applied. Returns the amount paid.
-- reason: "answer" | "survive" | "win" | "warmup" | ... (shown under the wallet popup).
function StoreService.payEarned(player: Player, cash: number, reason: string?): number
	if DataService.isReadOnly(player) then
		return 0
	end
	local amount = Economy.apply(cash, StoreService.cashMultiplier(player))
	if amount > 0 then
		DataService.addCash(player, amount)
		tellWallet(player, amount, reason)
	end
	return amount
end

-- Gives Shells exactly as stated, with no pass multiplier (packs, quests, rewards, debug).
function StoreService.grantShells(player: Player, amount: number, reason: string?)
	if amount <= 0 or DataService.isReadOnly(player) then
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

-- Asks Roblox which passes the player holds. A pass already known stays owned if a lookup fails.
local function lookupPasses(player: Player): { [string]: boolean }
	local previous = passes[player] or {}
	local owned = {}
	for key, passId in Products.Passes do
		if passId ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			owned[key] = (ok and has == true) or (not ok and previous[key] == true)
		end
	end
	return owned
end

local function loadPasses(player: Player)
	passes[player] = lookupPasses(player)
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
	-- The purchase event alone is not proof; a failed check leaves the pass to the next PassCheck.
	local ok, confirmed = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok or confirmed ~= true then
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
			local message = PASS_MESSAGES[key]
			if message ~= nil then
				NotifyService.send(player, message, "good")
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
				local profile = DataService.get(player)
				if profile ~= nil and profile.owned[item.id] == true then
					-- Already owned: the Robux is not wasted, it comes back as Shells.
					StoreService.grantShells(player, (item.robux or 0) * SHELLS_PER_ROBUX, "purchase")
					return
				end
				DataService.grantItem(player, item.id)
				DataService.equip(player, item.slot, item.id)
				CosmeticService.refresh(player)
			end)
		end
	end
	-- One per player: a second purchase (a stale shop) gets only the Shells.
	local starter = Products.StarterPack
	StoreService.registerProduct(starter.productId, function(player)
		StoreService.grantShells(player, starter.cash, "purchase")
		if not DataService.claim(player, "StarterPack") then
			return
		end
		for _, id in starter.items do
			DataService.grantItem(player, id)
		end
		NotifyService.send(player, "STARTER PACK UNLOCKED!  |  CHECK YOUR SHOP", "good")
	end)
end

-- Grants once per receipt: the receipt id is stored with the grant and checked before granting.
local function processReceipt(info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil or not DataService.isLoaded(player) or DataService.isReadOnly(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipt = tostring(info.PurchaseId)
	if DataService.hasReceipt(player, receipt) then
		-- Granted already. It is only acknowledged once that grant is saved: a receipt recorded in this
		-- session but lost to a failed save must stay open, or a crash would lose the purchase.
		if DataService.receiptSaved(player, receipt) or DataService.save(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local handler = productHandlers[info.ProductId]
	if handler == nil then
		warn("StoreService: no handler for product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- A handler that errors grants nothing and records nothing, so Roblox retries the receipt later.
	local ok, err = pcall(handler, player)
	if not ok then
		warn("StoreService: product " .. tostring(info.ProductId) .. " handler failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.addReceipt(player, receipt)
	if DataService.save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- The grant and receipt stay in the session; the retry acknowledges it once a save has gone through.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- status: "ok" | "cash" | "owned" | "unknown"
local function shopReply(player: Player, status: string)
	Net.event("ShopResult"):FireClient(player, { status = status })
end

local function onBuy(player: Player, itemId: any)
	if typeof(itemId) ~= "string" then
		return
	end
	local item = Cosmetics.ById[itemId]
	local profile = DataService.get(player)
	if item == nil or profile == nil or DataService.isReadOnly(player) then
		return shopReply(player, "unknown")
	end
	if profile.owned[item.id] == true then
		return shopReply(player, "owned")
	end
	if not Shop.canBuyWithCash(profile, item) then
		if profile.cash < item.price then
			return shopReply(player, "cash")
		end
		return shopReply(player, "unknown")
	end
	if not StoreService.spendShells(player, item.price, "spend") then
		return shopReply(player, "cash")
	end
	DataService.grantItem(player, item.id)
	DataService.equip(player, item.slot, item.id)
	CosmeticService.refresh(player)
	shopReply(player, "ok")
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
	-- The shop asks when it opens, so a pass bought on the website mid-session is picked up.
	Net.event("PassCheck").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastPassCheck[player] or -math.huge) < PASS_CHECK_COOLDOWN then
			return
		end
		lastPassCheck[player] = now
		local before = StoreService.passesOf(player)
		local after = lookupPasses(player)
		passes[player] = after
		for key, has in after do
			if has and before[key] ~= true then
				local message = PASS_MESSAGES[key]
				if message ~= nil then
					NotifyService.send(player, message, "good")
				end
			end
		end
		DataService.changed(player)
		CosmeticService.refresh(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerAdded:Connect(loadPasses)
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
		lastPassCheck[player] = nil
	end)
end

return StoreService
