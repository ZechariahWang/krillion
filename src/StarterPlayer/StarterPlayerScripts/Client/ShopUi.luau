--!strict
-- Drives StarterGui.Shop: the lobby SHOP button and the tabbed window for cosmetics, passes and packs.
-- The server checks every buy and equip; this only shows the state and sends requests.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Products = require(ReplicatedStorage.Config.Products)
local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local TABS = { "Skins", "Titles", "Splashes", "Passes" }
local TAB_SLOT = { Skins = "Skin", Titles = "Title", Splashes = "Splash" }

type Entry = {
	name: string,
	price: string,
	action: string,
	enabled: boolean,
	color: Color3?,
	onClick: () -> (),
}

local player = Players.LocalPlayer
local openButton: TextButton
local panel: Frame
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
		name = string.upper(item.name),
		price = "",
		action = "",
		enabled = true,
		color = colorOf(item),
		onClick = function() end,
	}
	if owned then
		entry.price = "OWNED"
		if equipped then
			entry.action = "UNEQUIP"
			entry.onClick = function()
				Net.event("ShopEquip"):FireServer(item.slot, "")
			end
		else
			entry.action = "EQUIP"
			entry.onClick = function()
				Net.event("ShopEquip"):FireServer(item.slot, item.id)
			end
		end
	elseif item.pass ~= nil then
		entry.price = "WITH " .. string.upper(item.pass) .. " PASS"
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
		entry.price = item.price .. " CASH"
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
		name = name,
		price = "GAME PASS",
		action = "BUY",
		enabled = passId ~= 0 and not owned,
		color = Color3.fromRGB(255, 194, 75),
		onClick = function()
			if passId ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, passId)
			end
		end,
	}
	if owned then
		entry.action = "OWNED"
	end
	return entry
end

local function productEntry(name: string, robux: number, productId: number): Entry
	return {
		name = name,
		price = "R$ " .. robux,
		action = "BUY",
		enabled = productId ~= 0,
		color = Color3.fromRGB(255, 194, 75),
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
	table.insert(entries, productEntry("REVIVE  (" .. profile.revives .. " OWNED)", Products.Revive.robux, Products.Revive.productId))
	for _, pack in Products.CashPacks do
		table.insert(entries, productEntry(pack.cash .. " CASH", pack.robux, pack.productId))
	end
	return entries
end

local function render()
	cashText.Text = profile.cash .. " CASH"
	for name, button in tabButtons do
		local selected = name == current
		if selected then
			button.BackgroundColor3 = Color3.fromRGB(60, 200, 255)
			button.TextColor3 = Color3.fromRGB(10, 20, 32)
		else
			button.BackgroundColor3 = Color3.fromRGB(5, 11, 18)
			button.TextColor3 = Color3.fromRGB(255, 245, 220)
		end
	end
	Ui.clearClones(grid, template.Name, "Item")
	for index, entry in entriesFor(current) do
		local card = template:Clone()
		card.Name = "Item" .. index
		card.LayoutOrder = index
		local nameLabel = card:FindFirstChild("ItemName") :: TextLabel
		local priceLabel = card:FindFirstChild("Price") :: TextLabel
		local swatch = card:FindFirstChild("Swatch") :: Frame
		local action = card:FindFirstChild("Action") :: TextButton
		nameLabel.Text = entry.name
		priceLabel.Text = entry.price
		if entry.color ~= nil then
			swatch.BackgroundColor3 = entry.color
		end
		action.Text = entry.action
		action.Active = entry.enabled
		if entry.enabled then
			action.BackgroundTransparency = 0
		else
			action.BackgroundTransparency = 0.6
		end
		action.MouseButton1Click:Connect(function()
			if not entry.enabled then
				return
			end
			Sfx.play("LockIn", 0.5)
			entry.onClick()
		end)
		Ui.pressable(action)
		card.Visible = true
		card.Parent = grid
	end
end

local function setOpen(open: boolean)
	if open then
		render()
		Ui.pop(panel)
	else
		panel.Visible = false
	end
end

local function refreshButton()
	openButton.Visible = not playing
	if playing then
		setOpen(false)
	end
end

function ShopUi.init(playerGui: PlayerGui)
	local gui = playerGui:WaitForChild("Shop")
	openButton = gui:WaitForChild("OpenButton") :: TextButton
	panel = gui:WaitForChild("Panel") :: Frame
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
	Ui.pressable(openButton)
	openButton.MouseButton1Click:Connect(function()
		Sfx.play("Pop", 0.5)
		setOpen(not panel.Visible)
	end)
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
