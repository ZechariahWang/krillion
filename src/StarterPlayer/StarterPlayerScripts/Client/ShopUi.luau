--!strict
-- Drives StarterGui.Shop: the lobby SHOP button and the tabbed window for cosmetics, passes and packs.
-- The server checks every buy and equip; this only shows the state and sends requests.
-- Shells buys take a second click within CONFIRM_SECONDS; reward items open the Rewards panel instead.

local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Rail = require(script.Parent.Rail)
local Rewards = require(script.Parent.Rewards)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local TABS = { "Skins", "Titles", "Splashes", "Trails", "Passes" }
local TAB_SLOT = { Skins = "Skin", Titles = "Title", Splashes = "Splash", Trails = "Trail" }
local BLUR_SIZE = 12
local GOLD = Color3.fromRGB(255, 194, 75)
local MUTED = Color3.fromRGB(122, 140, 160)
local CARD_SHADOW_REST = UDim2.fromOffset(0, 6)
local CARD_SHADOW_HOVER = UDim2.fromOffset(0, 12)
local CONFIRM_SECONDS = 3 -- a Shells buy needs a second click within this long
local SOON = "COMING SOON" -- Robux entries whose id is still the 0 placeholder
local LONG_PRICE = 18 -- longer price lines (the VIP perks) shrink to fit their label
local LONG_ACTION = 8

type Entry = {
	kind: string, -- "Skin" | "Title" | "Splash" | "Trail" | "Shop" (passes and products)
	name: string,
	price: string,
	currency: string?, -- "Cash" (Shells) shows the coin mark; nil shows the price text alone
	badge: string?, -- "EQUIPPED" | "OWNED" | "FREE" | "n OWNED" | nil
	action: string,
	enabled: boolean,
	color: Color3,
	stripe: ColorSequence?, -- trails: the colours along the trail, for the preview stripe
	onClick: () -> (),
}

local player = Players.LocalPlayer
local gui: Frame
local panel: Frame
local scrim: Frame
local blur: BlurEffect?
local cashText: TextLabel
local grid: ScrollingFrame
local template: Frame
local tabButtons: { [string]: TextButton } = {}

local current = "Skins"
local profile: Profile.Profile = Profile.new()
local passes: { [string]: boolean } = {}
local playing = false
local pendingBuy: { id: string, at: number }? = nil -- the Shells item waiting for its CONFIRM? click

local ShopUi = {}

local render: () -> ()
local setOpen: (boolean) -> ()

local function colorOf(item: Cosmetics.Item): Color3
	local rgb = item.color
	if rgb ~= nil then
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	return Color3.fromRGB(60, 200, 255)
end

local function promptProduct(productId: number)
	if productId == 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- The trail's own colours from its template, so the shop stripe always matches what plays in game.
local function trailColors(item: Cosmetics.Item): ColorSequence
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local folder = if templates ~= nil then templates:FindFirstChild("Trails") else nil
	local name = item.trail
	local trailFolder = if folder ~= nil and name ~= nil then folder:FindFirstChild(name) else nil
	local trail = if trailFolder ~= nil then trailFolder:FindFirstChild("KrillionTrail") else nil
	if trail ~= nil and trail:IsA("Trail") then
		return trail.Color
	end
	return ColorSequence.new(colorOf(item))
end

local function isConfirming(id: string): boolean
	local pending = pendingBuy
	return pending ~= nil and pending.id == id and os.clock() - pending.at < CONFIRM_SECONDS
end

-- The first click arms the buy and shows CONFIRM?; a second click inside the window sends it.
local function buyWithShells(item: Cosmetics.Item)
	if isConfirming(item.id) then
		pendingBuy = nil
		Net.event("ShopBuy"):FireServer(item.id)
		render()
		return
	end
	local mine = { id = item.id, at = os.clock() }
	pendingBuy = mine
	render()
	task.delay(CONFIRM_SECONDS, function()
		if pendingBuy == mine then
			pendingBuy = nil
			if panel.Visible then
				render()
			end
		end
	end)
end

local function cosmeticEntry(item: Cosmetics.Item): Entry
	local owned = Shop.owns(profile, item, passes)
	local equipped = (profile.equipped :: any)[item.slot] == item.id
	local entry: Entry = {
		kind = item.slot,
		name = string.upper(item.name),
		price = "",
		currency = nil,
		badge = nil,
		action = "",
		enabled = true,
		color = colorOf(item),
		stripe = if item.trail ~= nil then trailColors(item) else nil,
		onClick = function() end,
	}
	if owned then
		if equipped then
			entry.badge = "EQUIPPED"
			entry.price = "In use"
			entry.action = "UNEQUIP"
			entry.onClick = function()
				Net.event("ShopEquip"):FireServer(item.slot, "")
			end
		else
			entry.badge = "OWNED"
			entry.price = "Ready to equip"
			entry.action = "EQUIP"
			entry.onClick = function()
				Net.event("ShopEquip"):FireServer(item.slot, item.id)
			end
		end
	elseif item.reward ~= nil then
		-- Never sold: RewardService grants it, so GET opens the panel that says how.
		entry.badge = "FREE"
		entry.price = Cosmetics.RewardHow[item.reward] or "Free reward"
		entry.action = "GET"
		entry.onClick = function()
			setOpen(false)
			Rewards.open()
		end
	elseif item.pass ~= nil then
		entry.price = "With the " .. string.upper(item.pass) .. " pass"
		entry.action = "VIEW"
		entry.onClick = function()
			current = "Passes"
			render()
		end
	elseif item.robuxProductId ~= nil then
		entry.price = "R$ " .. tostring(item.robux or 0)
		entry.enabled = item.robuxProductId ~= 0
		entry.action = if entry.enabled then "BUY" else SOON
		entry.onClick = function()
			promptProduct(item.robuxProductId :: number)
		end
	else
		entry.price = Currency.digits(item.price)
		entry.currency = "Cash"
		entry.action = if isConfirming(item.id) then "CONFIRM?" else "BUY"
		entry.enabled = Shop.canBuyWithCash(profile, item)
		entry.onClick = function()
			buyWithShells(item)
		end
	end
	return entry
end

local function passEntry(name: string, key: string): Entry
	local passId = (Products.Passes :: any)[key] :: number
	local owned = passes[key] == true
	local entry: Entry = {
		kind = "Shop",
		name = name,
		price = "Game pass",
		currency = nil,
		badge = nil,
		action = "BUY",
		enabled = passId ~= 0 and not owned,
		color = GOLD,
		onClick = function()
			if passId ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, passId)
			end
		end,
	}
	if owned then
		entry.badge = "OWNED"
		entry.action = "OWNED"
	elseif passId == 0 then
		entry.action = SOON
	end
	return entry
end

local function productEntry(name: string, robux: number, productId: number): Entry
	return {
		kind = "Shop",
		name = name,
		price = "R$ " .. robux,
		currency = nil,
		badge = nil,
		action = if productId ~= 0 then "BUY" else SOON,
		enabled = productId ~= 0,
		color = GOLD,
		onClick = function()
			promptProduct(productId)
		end,
	}
end

-- What a boost costs when used from its in-match button; there is nothing to buy here.
local function boostShellsEntry(name: string, shells: number): Entry
	return {
		kind = "Shop",
		name = name,
		price = Currency.digits(shells) .. " each",
		currency = "Cash",
		badge = nil,
		action = "IN MATCH",
		enabled = false,
		color = GOLD,
		onClick = function() end,
	}
end

local function vipPerks(): string
	local bonus = math.floor(GameConfig.Cash.VipBonus * 100 + 0.5)
	return "+" .. bonus .. "% " .. Currency.Upper .. "  |  AURORA PILLAR  |  GOLD WAKE TRAIL  |  VIP TITLE"
end

local function boostEntries(entries: { Entry })
	if GameConfig.Boosts.Enabled ~= 1 then
		return
	end
	-- In a match the boost buttons use held boosts first, then Shells; Robux only stocks up.
	local hintName = Theme.Icon.Hint .. " HINT"
	local timeName = Theme.Icon.Time .. " +" .. GameConfig.Boosts.ExtraTimeSeconds .. "s"
	table.insert(entries, boostShellsEntry(hintName, GameConfig.Boosts.HintShells))
	local hint = productEntry(hintName .. " x1", Products.Boosts.Hint.robux, Products.Boosts.Hint.productId)
	if profile.hints > 0 then
		hint.badge = profile.hints .. " OWNED"
	end
	table.insert(entries, hint)
	table.insert(entries, boostShellsEntry(timeName, GameConfig.Boosts.ExtraTimeShells))
	local extra = productEntry(timeName .. " x1", Products.Boosts.ExtraTime.robux, Products.Boosts.ExtraTime.productId)
	if profile.extraTimes > 0 then
		extra.badge = profile.extraTimes .. " OWNED"
	end
	table.insert(entries, extra)
end

local function entriesFor(tab: string): { Entry }
	local entries = {}
	local slot = TAB_SLOT[tab]
	if slot ~= nil then
		for _, item in Cosmetics.List do
			if item.slot == slot then
				table.insert(entries, cosmeticEntry(item))
			end
		end
		return entries
	end
	local vip = passEntry("VIP", "Vip")
	vip.price = vipPerks()
	table.insert(entries, vip)
	table.insert(entries, passEntry("2X " .. Currency.Upper, "DoubleCash"))
	local revive = productEntry("REVIVE", Products.Revive.robux, Products.Revive.productId)
	if profile.revives > 0 then
		revive.badge = profile.revives .. " OWNED"
	end
	table.insert(entries, revive)
	boostEntries(entries)
	for _, pack in Products.CashPacks do
		table.insert(entries, productEntry(Currency.format(pack.cash), pack.robux, pack.productId))
	end
	return entries
end

-- Shows the preview that fits the item: a shaded disc for skins and shop items, the title as it would
-- float over a head, a burst for splashes, or the trail's colours as a stripe (an authored Stripe frame
-- if the template has one, else the disc).
local function fillPreview(preview: Frame, entry: Entry)
	local disc = preview:FindFirstChild("Disc") :: Frame
	local pill = preview:FindFirstChild("TitlePill") :: TextLabel
	local burst = preview:FindFirstChild("Burst") :: Frame
	local stripe = preview:FindFirstChild("Stripe") :: Frame?
	local isTrail = entry.kind == "Trail"
	disc.Visible = entry.kind == "Skin" or entry.kind == "Shop" or (isTrail and stripe == nil)
	pill.Visible = entry.kind == "Title"
	burst.Visible = entry.kind == "Splash"
	if stripe ~= nil then
		stripe.Visible = isTrail
	end
	disc.BackgroundColor3 = entry.color
	pill.Text = entry.name
	pill.TextColor3 = entry.color
	for _, part in burst:GetChildren() do
		if part:IsA("Frame") then
			part.BackgroundColor3 = entry.color
		end
	end
	local colors = entry.stripe
	if isTrail and colors ~= nil then
		local target: Frame = stripe or disc
		target.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = target:FindFirstChildOfClass("UIGradient")
		if gradient ~= nil then
			gradient.Color = colors
			gradient.Rotation = 0
		end
	end
end

-- Lifts the object a little and deepens its shadow while the mouse is over it.
local function addHover(object: GuiObject, lift: number, restShadow: UDim2, hoverShadow: UDim2)
	local scale = object:FindFirstChildOfClass("UIScale")
	local shadow = object:FindFirstChildOfClass("UIShadow") :: any
	object.MouseEnter:Connect(function()
		if scale ~= nil then
			Tween.play(scale, Theme.Tween.Hover, { Scale = lift })
		end
		if shadow ~= nil then
			shadow.Offset = hoverShadow
		end
	end)
	object.MouseLeave:Connect(function()
		if scale ~= nil then
			Tween.play(scale, Theme.Tween.Hover, { Scale = 1 })
		end
		if shadow ~= nil then
			shadow.Offset = restShadow
		end
	end)
end

-- The selected tab shows its authored Lime key face; the others are a faint glass key.
local function renderTabs()
	for name, button in tabButtons do
		local selected = name == current
		local face = button:FindFirstChild("Lip")
		if face ~= nil and face:IsA("UIGradient") then
			face.Enabled = selected
		end
		button.BackgroundTransparency = if selected then 0 else 0.75
	end
end

function render()
	cashText.Text = Currency.format(profile.cash)
	renderTabs()
	Ui.clearClones(grid, template.Name, "Item")
	for index, entry in entriesFor(current) do
		local card = template:Clone()
		card.Name = "Item" .. index
		card.LayoutOrder = index
		local nameLabel = card:FindFirstChild("ItemName") :: TextLabel
		local priceLabel = card:FindFirstChild("Price") :: TextLabel
		local coin = card:FindFirstChild("CoinIcon") :: Frame
		local badge = card:FindFirstChild("Badge") :: TextLabel
		local action = card:FindFirstChild("Action") :: TextButton
		fillPreview(card:FindFirstChild("Preview") :: Frame, entry)
		nameLabel.Text = entry.name
		priceLabel.Text = entry.price
		priceLabel.TextScaled = #entry.price > LONG_PRICE
		coin.Visible = entry.currency == "Cash"
		if entry.currency == "Cash" then
			priceLabel.Position = UDim2.fromOffset(84, 40)
			priceLabel.TextColor3 = GOLD
		else
			priceLabel.Position = UDim2.fromOffset(68, 40)
			if string.sub(entry.price, 1, 2) == "R$" then
				priceLabel.TextColor3 = GOLD
			else
				priceLabel.TextColor3 = MUTED
			end
		end
		badge.Visible = entry.badge ~= nil
		if entry.badge ~= nil then
			badge.Text = entry.badge
		end
		action.Text = entry.action
		action.TextScaled = #entry.action > LONG_ACTION
		action.Active = entry.enabled
		if entry.enabled then
			action.BackgroundTransparency = 0
		else
			action.BackgroundTransparency = 0.65
		end
		action.MouseButton1Click:Connect(function()
			if not entry.enabled then
				return
			end
			Sfx.play("LockIn", 0.5)
			entry.onClick()
		end)
		Ui.pressable(action)
		addHover(card, 1.03, CARD_SHADOW_REST, CARD_SHADOW_HOVER)
		card.Visible = true
		card.Parent = grid
	end
end

local function setBackdrop(shown: boolean)
	scrim.Visible = shown
	local effect = blur
	if effect == nil then
		return
	end
	if shown then
		Tween.play(effect, Theme.Tween.Enter, { Size = BLUR_SIZE })
	else
		Tween.play(effect, Theme.Tween.Exit, { Size = 0 })
	end
end

function setOpen(open: boolean)
	if open then
		render()
		setBackdrop(true)
		Ui.pop(panel)
	else
		pendingBuy = nil
		panel.Visible = false
		setBackdrop(false)
	end
end

local function refreshButton()
	if playing and panel.Visible then
		setOpen(false)
	end
end

function ShopUi.init(playerGui: PlayerGui)
	gui = Ui.screen(playerGui, "Shop") :: Frame
	panel = gui:WaitForChild("Panel") :: Frame
	scrim = gui:WaitForChild("Scrim") :: Frame
	blur = Lighting:FindFirstChild("ShopBlur") :: BlurEffect?
	cashText = panel:WaitForChild("CashText") :: TextLabel
	grid = panel:WaitForChild("Grid") :: ScrollingFrame
	template = grid:WaitForChild("ItemTemplate") :: Frame
	local tabs = panel:WaitForChild("Tabs")
	for _, name in TABS do
		local button = tabs:WaitForChild(name) :: TextButton
		tabButtons[name] = button
		Ui.pressable(button)
		button.MouseButton1Click:Connect(function()
			current = name
			Sfx.play("Pop", 0.4)
			render()
		end)
	end
	local close = panel:WaitForChild("CloseButton") :: TextButton
	Ui.pressable(close)
	close.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	scrim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setOpen(false)
		end
	end)
	-- The SHOP key lives on the lobby rail (Rail hides it in a match and while this window is open).
	local railButton = Rail.button("ShopButton")
	if railButton ~= nil then
		railButton.Activated:Connect(function()
			Sfx.play("Pop", 0.5)
			setOpen(true)
		end)
	end
end

function ShopUi.onProfile(payload)
	profile = Profile.fromStored(payload)
	passes = payload.passes or {}
	if panel.Visible then
		render()
	end
end

function ShopUi.onState(payload)
	playing = payload.playing == true
	refreshButton()
end

return ShopUi
