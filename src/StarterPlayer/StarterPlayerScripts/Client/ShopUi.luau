--!strict
-- Drives StarterGui.Shop: the lobby SHOP button and the tabbed window for cosmetics, passes and packs.
-- The server checks every buy and equip; this only shows the state and sends requests.

local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Products = require(ReplicatedStorage.Config.Products)
local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local TABS = { "Skins", "Titles", "Splashes", "Passes" }
local TAB_SLOT = { Skins = "Skin", Titles = "Title", Splashes = "Splash" }
local BLUR_SIZE = 12
local GOLD = Color3.fromRGB(255, 194, 75)
local CREAM = Color3.fromRGB(255, 245, 220)
local MUTED = Color3.fromRGB(122, 140, 160)
local CARD_SHADOW_REST = UDim2.fromOffset(0, 6)
local CARD_SHADOW_HOVER = UDim2.fromOffset(0, 12)
local SHINE_EVERY = 4 -- seconds between light sweeps across the SHOP button
local SHINE_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

type Entry = {
	kind: string, -- "Skin" | "Title" | "Splash" | "Shop" (passes and products)
	name: string,
	price: string,
	currency: string?, -- "Cash" shows the coin mark; nil shows the price text alone
	badge: string?, -- "EQUIPPED" | "OWNED" | nil
	action: string,
	enabled: boolean,
	color: Color3,
	onClick: () -> (),
}

local player = Players.LocalPlayer
local gui: ScreenGui
local openButton: TextButton
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

local ShopUi = {}

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
	elseif item.pass ~= nil then
		entry.price = "With the " .. string.upper(item.pass) .. " pass"
		entry.action = "LOCKED"
		entry.enabled = false
	elseif item.robuxProductId ~= nil then
		entry.price = "R$ " .. tostring(item.robux or 0)
		entry.action = "BUY"
		entry.enabled = item.robuxProductId ~= 0
		entry.onClick = function()
			promptProduct(item.robuxProductId :: number)
		end
	else
		entry.price = tostring(item.price)
		entry.currency = "Cash"
		entry.action = "BUY"
		entry.enabled = Shop.canBuyWithCash(profile, item)
		entry.onClick = function()
			Net.event("ShopBuy"):FireServer(item.id)
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
		action = "BUY",
		enabled = productId ~= 0,
		color = GOLD,
		onClick = function()
			promptProduct(productId)
		end,
	}
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
	table.insert(entries, passEntry("VIP", "Vip"))
	table.insert(entries, passEntry("2X CASH", "DoubleCash"))
	local revive = productEntry("REVIVE", Products.Revive.robux, Products.Revive.productId)
	if profile.revives > 0 then
		revive.badge = profile.revives .. " OWNED"
	end
	table.insert(entries, revive)
	for _, pack in Products.CashPacks do
		table.insert(entries, productEntry(pack.cash .. " CASH", pack.robux, pack.productId))
	end
	return entries
end

-- Shows the preview that fits the item: a shaded disc for skins and shop items, the title as it would
-- float over a head, or a burst for splashes.
local function fillPreview(preview: Frame, entry: Entry)
	local disc = preview:FindFirstChild("Disc") :: Frame
	local pill = preview:FindFirstChild("TitlePill") :: TextLabel
	local burst = preview:FindFirstChild("Burst") :: Frame
	disc.Visible = entry.kind == "Skin" or entry.kind == "Shop"
	pill.Visible = entry.kind == "Title"
	burst.Visible = entry.kind == "Splash"
	disc.BackgroundColor3 = entry.color
	pill.Text = entry.name
	pill.TextColor3 = entry.color
	for _, part in burst:GetChildren() do
		if part:IsA("Frame") then
			part.BackgroundColor3 = entry.color
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

-- A soft light band sweeps across the SHOP button every few seconds while it is showing.
local function startShine()
	local shine = openButton:FindFirstChild("Shine")
	local gradient = nil
	if shine ~= nil then
		gradient = shine:FindFirstChildOfClass("UIGradient")
	end
	if gradient == nil then
		return
	end
	task.spawn(function()
		while true do
			task.wait(SHINE_EVERY)
			if openButton.Visible then
				gradient.Offset = Vector2.new(-1, 0)
				TweenService:Create(gradient, SHINE_INFO, { Offset = Vector2.new(1, 0) }):Play()
			end
		end
	end)
end

local function renderTabs()
	for name, button in tabButtons do
		local selected = name == current
		local underline = button:FindFirstChild("Underline") :: Frame?
		if underline ~= nil then
			underline.Visible = selected
		end
		if selected then
			button.TextColor3 = CREAM
			button.BackgroundTransparency = 0.3
		else
			button.TextColor3 = MUTED
			button.BackgroundTransparency = 0.55
		end
	end
end

local function render()
	cashText.Text = profile.cash .. " CASH"
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

local function setOpen(open: boolean)
	if open then
		render()
		setBackdrop(true)
		Ui.pop(panel)
	else
		panel.Visible = false
		setBackdrop(false)
	end
	-- The button hides while the window is open, and only shows in the lobby.
	openButton.Visible = not open and not playing
end

local function refreshButton()
	if playing and panel.Visible then
		setOpen(false)
	end
	openButton.Visible = not playing and not panel.Visible
end

function ShopUi.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Shop") :: ScreenGui
	openButton = gui:WaitForChild("OpenButton") :: TextButton
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
	Ui.pressable(openButton)
	addHover(openButton, 1.04, UDim2.fromOffset(0, 6), UDim2.fromOffset(0, 10))
	openButton.MouseButton1Click:Connect(function()
		Sfx.play("Pop", 0.5)
		setOpen(true)
	end)
	startShine()
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
