--!strict
-- Drives LobbyUi.Shop (the shop window for cosmetics, pets, toys, chests, passes and packs) and
-- LobbyUi.Inventory (the same kind of window, authored with the cosmetic sections only, listing what you own
-- first and the rest dimmed behind a lock, with how much of the collection you have in the title).
-- The server checks every buy, equip and chest; this only shows the state and sends requests.
-- Shells buys take a second click within CONFIRM_SECONDS; a chest opens on one click into ChestReveal; reward items open the Rewards
-- panel; chest-only items jump to CHESTS; a Shells item you cannot afford offers GET SHELLS (the SHELLS section).
--
-- The sections are the TextButtons authored under Holder.Panel.Sections, in LayoutOrder. Each carries a `Kind`
-- attribute (Featured | Slots | Chests | Shells | Passes | Specials) and, for Slots, a comma list of cosmetic slots
-- in `Slots`. The toolbar (Panel.Tools) holds the search box and the Price, Rarity and Hide-owned filters.

local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chests = require(ReplicatedStorage.Config.Chests)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Rail = require(script.Parent.Rail)
local Rewards = require(script.Parent.Rewards)
local ChestReveal = require(script.Parent.ChestReveal)
local ItemEmoji = require(script.Parent.ItemEmoji)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local BLUR_SIZE = 12
local GOLD = Color3.fromRGB(255, 194, 75)
local MUTED = Color3.fromRGB(185, 211, 240)
local GREEN = Color3.fromRGB(120, 235, 140)
local NAVY = Color3.fromRGB(10, 20, 32)
local WHITE = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(255, 92, 92)
local PURPLE = Color3.fromRGB(180, 107, 255)
local CARD_SHADOW_REST = UDim2.fromOffset(0, 6)
local CARD_SHADOW_HOVER = UDim2.fromOffset(0, 12)
local CONFIRM_SECONDS = 3 -- a Shells buy or chest needs a second click within this long
local SOON = "COMING SOON" -- Robux entries whose id is still the 0 placeholder
local LONG_ACTION = 8
local MARGIN = 16 -- pixels kept clear around the window when it is scaled down for a small screen
local MIN_FIT = 0.4
local PORTRAIT_BELOW = 0.7 -- the wide layout shows smaller than this: use the tall phone one if it shows bigger
local PORTRAIT_SIZE = UDim2.fromOffset(520, 880)
local PRICE_X_WITH_COIN = 142
local PRICE_X_PLAIN = 120
local LOCKED = "🔒"
local DIM = 0.45 -- text and preview transparency of an item you do not own, in the inventory

local PRICES = { "All", "Shells", "Robux", "Free" }
local RARITIES = { "All", table.unpack(Cosmetics.Rarities) }

-- Badge face colour and whether its text is light.
local BADGE_LOOK: { [string]: { color: Color3, light: boolean } } = {
	["BEST VALUE"] = { color = GOLD, light = false },
	["MOST POPULAR"] = { color = GOLD, light = false },
	ONCE = { color = PURPLE, light = true },
	TODAY = { color = RED, light = true },
	NEW = { color = RED, light = true },
	HOT = { color = RED, light = true },
	LIMITED = { color = RED, light = true },
}

local PASS_EMOJI: { [string]: string } = { Vip = "👑", DoubleCash = "💰", SecondChance = "❤️", BoostPlus = "⚡" }
local PASS_NAMES: { [string]: string } = {
	Vip = "VIP",
	DoubleCash = "2X " .. Currency.Upper,
	SecondChance = "SECOND CHANCE",
	BoostPlus = "BOOST PLUS",
}
local SLOT_NAMES: { [string]: string } = {
	Skin = "pillar skin",
	Title = "title",
	Splash = "splash",
	Trail = "trail",
	Pet = "pet",
	Aura = "aura",
	CardTheme = "dive card theme",
	NameTag = "name tag",
	Toy = "toy",
}

type Entry = {
	kind: string, -- a cosmetic slot, "Shop" (passes and products), "Chest" or "Odds"
	name: string,
	sub: string, -- the small line under the name: rarity and kind, a perk, a pack's rate
	price: string,
	currency: string?, -- "Cash" (shows the coin), "Robux", "Free", or nil (passes, chest-only, info rows)
	priceColor: Color3?,
	badge: string?,
	action: string,
	enabled: boolean,
	owned: boolean,
	color: Color3,
	rarity: string?, -- colours the card border
	emoji: string?,
	stripe: ColorSequence?, -- trails: the colours along the trail, for the preview stripe
	onClick: () -> (),
}

type Section = { name: string, kind: string, slots: { string }, button: TextButton }


-- One window record per authored screen: LobbyUi.Shop (Shells items), LobbyUi.Store (everything bought with
-- Robux: specials, passes, Shells packs) and LobbyUi.Inventory share every card and section mechanic; the
-- inventory one lists the whole collection, owned first, the rest behind a lock.
type Window = {
	name: string,
	inventory: boolean,
	gui: Frame,
	panel: Frame,
	scrim: Frame,
	fit: UIScale,
	layout: Ui.PhoneLayout?,
	cashText: TextLabel,
	titleLabel: TextLabel?,
	title: string,
	grid: ScrollingFrame,
	template: Frame,
	emptyLabel: TextLabel?,
	sections: { Section },
	sectionByName: { [string]: Section },
	filterKeys: { [string]: TextButton },
	current: Section?,
	filter: Shop.Filter,
	scrollToken: number, -- bumped by scrollToTop, so a re-render's deferred scroll restore stands down
	close: () -> (),
}

local player = Players.LocalPlayer
local blur: BlurEffect?
local windows: { Window } = {}
local shopWindow: Window? = nil
local active: Window? = nil -- the window being rendered or shown; card callbacks act on it
local profile: Profile.Profile = Profile.new()
local passes: { [string]: boolean } = {}
local chestsAllowed = false
local playing = false
local pendingBuy: { id: string, at: number }? = nil -- the Shells buy or chest waiting for its CONFIRM? click

local ShopUi = {}

local renderWindow: (Window) -> ()
local openWindow: (Window, boolean) -> ()

local function render()
	if active ~= nil then
		renderWindow(active)
	end
end

local function setOpen(open: boolean)
	if active ~= nil then
		openWindow(active, open)
	end
end

local function rgb(values: { number }?, fallback: Color3): Color3
	if values == nil then
		return fallback
	end
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function colorOf(item: Cosmetics.Item): Color3
	return rgb(item.color, Color3.fromRGB(60, 200, 255))
end

local function promptProduct(productId: number)
	if productId == 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function scrollToTop(w: Window)
	w.scrollToken += 1
	w.grid.CanvasPosition = Vector2.zero
end

local function goToIn(w: Window, name: string): boolean
	local section = w.sectionByName[name]
	if section == nil then
		return false
	end
	w.current = section
	renderWindow(w)
	scrollToTop(w)
	return true
end

local function goToKindIn(w: Window, kind: string): boolean
	for _, section in w.sections do
		if section.kind == kind then
			return goToIn(w, section.name)
		end
	end
	return false
end

-- The first non-inventory window with a section of this kind: SHELLS and PASSES live in the store, CHESTS
-- in the shop.
local function windowWithKind(kind: string): Window?
	for _, w in windows do
		if not w.inventory then
			for _, section in w.sections do
				if section.kind == kind then
					return w
				end
			end
		end
	end
	return nil
end

-- A card's jump ("GET SHELLS", "VIEW", "CHESTS"): this window if it has the section, else the window that does.
local function goToKind(kind: string)
	local w = active
	if w == nil or goToKindIn(w, kind) then
		return
	end
	local target = windowWithKind(kind)
	if target ~= nil and target ~= w then
		openWindow(w, false)
		openWindow(target, true)
		goToKindIn(target, kind)
	end
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

-- The first click arms a Shells spend and shows CONFIRM?; a second click inside the window sends it.
local function confirmThen(id: string, send: () -> ())
	if isConfirming(id) then
		pendingBuy = nil
		send()
		render()
		return
	end
	local mine = { id = id, at = os.clock() }
	pendingBuy = mine
	render()
	task.delay(CONFIRM_SECONDS, function()
		if pendingBuy == mine then
			pendingBuy = nil
			if active ~= nil and active.panel.Visible then
				render()
			end
		end
	end)
end

-- Which chest drops an item (the first that does), for a chest-only card's price line.
local function chestFor(itemId: string): Chests.Chest?
	for _, chest in Chests.List do
		for _, drop in chest.drops do
			if drop.item == itemId then
				return chest
			end
		end
	end
	return nil
end

local function emptyEntry(kind: string, name: string, color: Color3): Entry
	return {
		kind = kind,
		name = name,
		sub = "",
		price = "",
		currency = nil,
		priceColor = nil,
		badge = nil,
		action = "",
		enabled = true,
		owned = false,
		color = color,
		rarity = nil,
		emoji = nil,
		stripe = nil,
		onClick = function() end,
	}
end

local function bonusText(item: Cosmetics.Item): string?
	if item.shellBonus == nil then
		return nil
	end
	return "+" .. math.floor(item.shellBonus * 100 + 0.5) .. "% " .. Currency.Upper
end

local function cosmeticEntry(item: Cosmetics.Item): Entry
	local owned = Shop.owns(profile, item, passes)
	local equipped = (profile.equipped :: any)[item.slot] == item.id
	local entry = emptyEntry(item.slot, string.upper(item.name), colorOf(item))
	entry.rarity = item.rarity
	entry.emoji = ItemEmoji.of(item)
	entry.stripe = if item.trail ~= nil then trailColors(item) else nil
	entry.badge = item.label
	entry.owned = owned
	local bonus = bonusText(item)
	entry.sub = item.rarity .. " " .. (SLOT_NAMES[item.slot] or string.lower(item.slot))
	if bonus ~= nil then
		entry.sub ..= ", " .. bonus
	end
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
		entry.priceColor = GREEN
		return entry
	end
	local source = Cosmetics.source(item)
	if source == "reward" then
		-- Never sold: RewardService grants it, so GET opens the panel that says how.
		entry.badge = "FREE"
		entry.currency = "Free"
		entry.price = Cosmetics.RewardHow[item.reward :: string] or "Free reward"
		entry.action = "GET"
		entry.onClick = function()
			setOpen(false)
			Rewards.open()
		end
	elseif source == "pass" then
		entry.price = "With the " .. string.upper(item.pass :: string) .. " pass"
		entry.action = "VIEW"
		entry.onClick = function()
			goToKind("Passes")
		end
	elseif source == "chest" then
		local chest = chestFor(item.id)
		entry.price = if chest ~= nil then "In the " .. chest.name else "In a chest"
		entry.action = "CHESTS"
		entry.enabled = chestsAllowed
		entry.onClick = function()
			goToKind("Chests")
		end
	elseif source == "robux" then
		entry.currency = "Robux"
		entry.price = "R$ " .. tostring(item.robux or 0)
		entry.priceColor = GOLD
		entry.enabled = item.robuxProductId ~= 0
		entry.action = if entry.enabled then "BUY" else SOON
		entry.onClick = function()
			promptProduct(item.robuxProductId :: number)
		end
	else
		entry.price = Currency.digits(item.price)
		entry.currency = "Cash"
		if Shop.canBuyWithCash(profile, item) then
			entry.action = if isConfirming(item.id) then "CONFIRM?" else "BUY"
			entry.onClick = function()
				confirmThen(item.id, function()
					Net.event("ShopBuy"):FireServer(item.id)
				end)
			end
		else
			-- Short of Shells: the button sells Shells instead of greying out.
			entry.action = "GET " .. Theme.Icon.Shell
			entry.onClick = function()
				goToKind("Shells")
			end
		end
	end
	return entry
end

local function passPerks(key: string): string
	if key == "Vip" then
		local bonus = math.floor(GameConfig.Cash.VipBonus * 100 + 0.5)
		return "+" .. bonus .. "% " .. Currency.Upper .. ", Aurora pillar, Gold Wake, VIP title and tag"
	elseif key == "DoubleCash" then
		return "Double every " .. Currency.Upper .. " you earn, forever"
	elseif key == "SecondChance" then
		return "One free revive every match"
	elseif key == "BoostPlus" then
		return GameConfig.Boosts.PerMatchPlus .. " hints and " .. GameConfig.Boosts.PerMatchPlus .. " +time per match"
	end
	return "Game pass"
end

local function passEntry(key: string): Entry
	local passId = (Products.Passes :: any)[key] :: number
	local robux = (Products.PassPrices :: any)[key] :: number?
	local owned = passes[key] == true
	local entry = emptyEntry("Shop", PASS_NAMES[key] or string.upper(key), GOLD)
	entry.rarity = "Legendary"
	entry.emoji = PASS_EMOJI[key]
	entry.sub = passPerks(key)
	entry.currency = "Robux"
	entry.price = if robux ~= nil then "R$ " .. robux else "Game pass"
	entry.priceColor = GOLD
	entry.badge = (Products.PassBadges :: any)[key]
	entry.enabled = passId ~= 0 and not owned
	entry.owned = owned
	entry.action = "BUY"
	entry.onClick = function()
		if passId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end
	end
	if owned then
		entry.badge = "OWNED"
		entry.action = "OWNED"
	elseif passId == 0 then
		entry.action = SOON
	end
	return entry
end

local function productEntry(name: string, robux: number, productId: number, emoji: string?): Entry
	local entry = emptyEntry("Shop", name, GOLD)
	entry.emoji = emoji
	entry.currency = "Robux"
	entry.price = "R$ " .. robux
	entry.priceColor = GOLD
	entry.action = if productId ~= 0 then "BUY" else SOON
	entry.enabled = productId ~= 0
	entry.onClick = function()
		promptProduct(productId)
	end
	return entry
end

local function starterEntry(): Entry?
	if profile.claimed.StarterPack == true then
		return nil
	end
	local pack = Products.StarterPack
	local entry = productEntry("STARTER PACK", pack.robux, pack.productId, Theme.Icon.Gift)
	entry.rarity = "Epic"
	entry.badge = pack.badge
	-- Short enough to read on the card: the Shells and what kinds of items come with them.
	local kinds = {}
	for _, id in pack.items do
		local item = Cosmetics.ById[id]
		if item ~= nil then
			table.insert(kinds, string.lower(item.slot))
		end
	end
	entry.sub = Currency.digits(pack.cash) .. " " .. Theme.Icon.Shell .. " + " .. table.concat(kinds, " + ") .. ", one time only"
	return entry
end

local function packEntry(pack: { productId: number, cash: number, robux: number, badge: string? }, rarity: string): Entry
	local entry = productEntry(Currency.format(pack.cash), pack.robux, pack.productId, Theme.Icon.Shell)
	entry.rarity = rarity
	entry.badge = pack.badge
	entry.sub = math.floor(pack.cash / pack.robux + 0.5) .. " " .. Currency.Upper .. " per R$"
	return entry
end

local function packEntries(entries: { Entry })
	for index, pack in Products.CashPacks do
		table.insert(entries, packEntry(pack, Cosmetics.Rarities[math.min(index, #Cosmetics.Rarities)]))
	end
end

-- What a boost costs when used from its in-match button; there is nothing to buy here.
local function boostShellsEntry(name: string, shells: number, emoji: string): Entry
	local entry = emptyEntry("Shop", name, GOLD)
	entry.emoji = emoji
	entry.sub = "Buy it from the match button when you need it"
	entry.price = Currency.digits(shells) .. " each"
	entry.currency = "Cash"
	entry.action = "IN MATCH"
	entry.enabled = false
	return entry
end

local function boostEntries(entries: { Entry })
	if GameConfig.Boosts.Enabled ~= 1 then
		return
	end
	-- In a match the boost buttons use held boosts first, then Shells; Robux only stocks up.
	local hintName = "HINT"
	local timeName = "+" .. GameConfig.Boosts.ExtraTimeSeconds .. " SEC"
	table.insert(entries, boostShellsEntry(hintName, GameConfig.Boosts.HintShells, Theme.Icon.Hint))
	local hint = productEntry(hintName .. " x1", Products.Boosts.Hint.robux, Products.Boosts.Hint.productId, Theme.Icon.Hint)
	hint.sub = "One hint in your stock"
	if profile.hints > 0 then
		hint.badge = profile.hints .. " OWNED"
	end
	table.insert(entries, hint)
	table.insert(entries, boostShellsEntry(timeName, GameConfig.Boosts.ExtraTimeShells, Theme.Icon.Time))
	local extra = productEntry(timeName .. " x1", Products.Boosts.ExtraTime.robux, Products.Boosts.ExtraTime.productId, Theme.Icon.Time)
	extra.sub = "One +time in your stock"
	if profile.extraTimes > 0 then
		extra.badge = profile.extraTimes .. " OWNED"
	end
	table.insert(entries, extra)
	for _, pack in Products.BoostPacks do
		local name = (if pack.kind == "Hint" then hintName else timeName) .. " x" .. pack.count
		local emoji = if pack.kind == "Hint" then Theme.Icon.Hint else Theme.Icon.Time
		local entry = productEntry(name, pack.robux, pack.productId, emoji)
		entry.sub = pack.count .. " in your stock, cheaper than one at a time"
		entry.badge = "SAVE"
		table.insert(entries, entry)
	end
end

local function specialEntries(entries: { Entry })
	local starter = starterEntry()
	if starter ~= nil then
		table.insert(entries, starter)
	end
	local revive = productEntry("REVIVE", Products.Revive.robux, Products.Revive.productId, "❤️")
	revive.sub = "Jump back in the next time you sink"
	if profile.revives > 0 then
		revive.badge = profile.revives .. " OWNED"
	end
	table.insert(entries, revive)
	boostEntries(entries)
end

local function passEntries(entries: { Entry })
	for _, key in Products.PassOrder do
		table.insert(entries, passEntry(key))
	end
end

local function chestEntries(entries: { Entry })
	if not chestsAllowed then
		local blocked = emptyEntry("Shop", "CHESTS", MUTED)
		blocked.emoji = Theme.Icon.Chest
		blocked.sub = "Not available where you live"
		blocked.action = "LOCKED"
		blocked.enabled = false
		table.insert(entries, blocked)
		return
	end
	for _, chest in Chests.List do
		local entry = emptyEntry("Chest", string.upper(chest.name), rgb(chest.color, GOLD))
		entry.emoji = Theme.Icon.Chest
		entry.rarity = if chest.price >= 1000 then "Epic" else "Rare"
		entry.sub = "One random prize, odds below"
		entry.price = Currency.digits(chest.price)
		entry.currency = "Cash"
		if profile.cash >= chest.price then
			entry.action = "OPEN"
			entry.onClick = function()
				ChestReveal.open(chest.id)
			end
		else
			entry.action = "GET " .. Theme.Icon.Shell
			entry.onClick = function()
				goToKind("Shells")
			end
		end
		table.insert(entries, entry)
	end
	-- Every chance, before anyone pays: what can come out of each chest and how likely it is.
	for _, chest in Chests.List do
		for _, drop in chest.drops do
			local item = Cosmetics.ById[drop.item]
			if item ~= nil then
				local entry = emptyEntry("Odds", string.upper(item.name), colorOf(item))
				entry.rarity = item.rarity
				entry.emoji = ItemEmoji.of(item)
				entry.sub = "In the " .. chest.name
				entry.price = Chests.percent(drop.chance) .. " chance"
				entry.priceColor = Theme.Rarity[item.rarity] or MUTED
				entry.action = string.upper(item.rarity)
				entry.enabled = false
				entry.owned = Shop.owns(profile, item, passes)
				if entry.owned then
					entry.badge = "OWNED"
				end
				table.insert(entries, entry)
			end
		end
	end
end

local function featuredEntries(entries: { Entry })
	local starter = starterEntry()
	if starter ~= nil then
		table.insert(entries, starter)
	end
	for _, item in Shop.featured(Quests.day(os.time())) do
		local entry = cosmeticEntry(item)
		if entry.badge == nil then
			entry.badge = "TODAY"
		end
		table.insert(entries, entry)
	end
	-- The best cash pack and the 2x pass are Robux, so they live in the STORE window only.
	if windowWithKind("Shells") ~= nil then
		return
	end
	local best = #Products.CashPacks
	table.insert(entries, packEntry(Products.CashPacks[best], "Legendary"))
	if passes.DoubleCash ~= true then
		table.insert(entries, passEntry("DoubleCash"))
	end
end

local function entriesFor(section: Section): { Entry }
	local entries: { Entry } = {}
	if section.kind == "Slots" then
		for _, slot in section.slots do
			for _, item in Cosmetics.inSlot(slot) do
				table.insert(entries, cosmeticEntry(item))
			end
		end
	elseif section.kind == "Featured" then
		featuredEntries(entries)
	elseif section.kind == "Chests" then
		chestEntries(entries)
	elseif section.kind == "Shells" then
		packEntries(entries)
	elseif section.kind == "Passes" then
		passEntries(entries)
	elseif section.kind == "Specials" then
		specialEntries(entries)
	end
	return entries
end

-- Shows the preview that fits the item: a shaded disc (with an emoji when the template has a
-- Preview.Emoji label), the title or name tag as a pill, a burst for splashes, or the trail's colours as a
-- stripe (an authored Stripe frame if the template has one, else the disc).
local function fillPreview(preview: Frame, entry: Entry)
	local disc = preview:FindFirstChild("Disc") :: Frame
	local pill = preview:FindFirstChild("TitlePill") :: TextLabel
	local burst = preview:FindFirstChild("Burst") :: Frame
	local stripe = preview:FindFirstChild("Stripe") :: Frame?
	local emoji = preview:FindFirstChild("Emoji") :: TextLabel?
	local isTrail = entry.kind == "Trail"
	local isPill = entry.kind == "Title" or entry.kind == "NameTag"
	disc.Visible = not isPill and entry.kind ~= "Splash" and not (isTrail and stripe ~= nil)
	pill.Visible = isPill
	burst.Visible = entry.kind == "Splash"
	if stripe ~= nil then
		stripe.Visible = isTrail
	end
	if emoji ~= nil then
		emoji.Visible = entry.emoji ~= nil and disc.Visible
		emoji.Text = entry.emoji or ""
	end
	disc.BackgroundColor3 = entry.color
	pill.Text = if entry.kind == "NameTag" then "NAME" else entry.name
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

local function fillBadge(badge: TextLabel, text: string?)
	badge.Visible = text ~= nil
	if text == nil then
		return
	end
	badge.Text = text
	local look = BADGE_LOOK[text]
	badge.BackgroundColor3 = if look ~= nil then look.color else WHITE
	badge.TextColor3 = if look ~= nil and look.light then WHITE else NAVY
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

-- A lime key shows its authored Lime face when selected (or its filter is on); otherwise a faint glass key.
local function setKeyLit(button: TextButton, lit: boolean)
	local face = button:FindFirstChild("Lip")
	if face ~= nil and face:IsA("UIGradient") then
		face.Enabled = lit
	end
	button.BackgroundTransparency = if lit then 0 else 0.75
end

local function renderSections(w: Window)
	for _, section in w.sections do
		setKeyLit(section.button, section == w.current)
	end
end

local function renderFilters(w: Window)
	local filter = w.filter
	local price = w.filterKeys.PriceFilter
	if price ~= nil then
		price.Text = "PRICE: " .. string.upper(filter.price)
		setKeyLit(price, filter.price ~= "All")
	end
	local rarity = w.filterKeys.RarityFilter
	if rarity ~= nil then
		rarity.Text = "RARITY: " .. string.upper(filter.rarity)
		setKeyLit(rarity, filter.rarity ~= "All")
	end
	local owned = w.filterKeys.OwnedFilter
	if owned ~= nil then
		setKeyLit(owned, filter.hideOwned)
	end
end

local function fillCard(w: Window, card: Frame, entry: Entry)
	local nameLabel = card:FindFirstChild("ItemName") :: TextLabel
	local subLabel = card:FindFirstChild("Sub") :: TextLabel?
	local priceLabel = card:FindFirstChild("Price") :: TextLabel
	local coin = card:FindFirstChild("CoinIcon") :: Frame
	local badge = card:FindFirstChild("Badge") :: TextLabel
	local action = card:FindFirstChild("Action") :: TextButton
	local border = card:FindFirstChild("Border")
	fillPreview(card:FindFirstChild("Preview") :: Frame, entry)
	nameLabel.Text = entry.name
	if subLabel ~= nil then
		subLabel.Text = entry.sub
	end
	priceLabel.Text = entry.price
	local showCoin = entry.currency == "Cash"
	coin.Visible = showCoin
	priceLabel.Position = UDim2.fromOffset(if showCoin then PRICE_X_WITH_COIN else PRICE_X_PLAIN, priceLabel.Position.Y.Offset)
	priceLabel.TextColor3 = if showCoin then GOLD else (entry.priceColor or MUTED)
	-- Rarity colours the card's border; cards with no rarity keep the authored one.
	if border ~= nil and border:IsA("UIStroke") then
		local rarityColor = if entry.rarity ~= nil then Theme.Rarity[entry.rarity] else nil
		if rarityColor ~= nil then
			border.Color = rarityColor
		end
	end
	local locked = w.inventory and not entry.owned
	fillBadge(badge, if locked and entry.badge == nil then LOCKED else entry.badge)
	local dim = if locked then DIM else 0
	nameLabel.TextTransparency = dim
	if subLabel ~= nil then
		subLabel.TextTransparency = dim
	end
	priceLabel.TextTransparency = dim
	if locked then
		local preview = card:FindFirstChild("Preview")
		if preview ~= nil then
			for _, part in preview:GetChildren() do
				if part:IsA("TextLabel") then
					part.TextTransparency = DIM
				elseif part:IsA("GuiObject") then
					part.BackgroundTransparency = math.max(part.BackgroundTransparency, DIM)
				end
			end
		end
	end
	action.Text = entry.action
	action.TextScaled = #entry.action > LONG_ACTION
	action.Active = entry.enabled
	action.BackgroundTransparency = if entry.enabled then 0 else 0.65
	action.MouseButton1Click:Connect(function()
		if not entry.enabled then
			return
		end
		Sfx.play("LockIn", 0.5)
		active = w
		entry.onClick()
	end)
	Ui.pressable(action)
	addHover(card, 1.03, CARD_SHADOW_REST, CARD_SHADOW_HOVER)
end

-- How much of the whole catalogue is owned, for the inventory title.
local function collectionText(): string
	local owned = 0
	for _, item in Cosmetics.List do
		if Shop.owns(profile, item, passes) then
			owned += 1
		end
	end
	return owned .. "/" .. #Cosmetics.List
end

-- Re-rendering (a buy, an equip, a profile update) keeps the grid where it was scrolled to; only a new
-- section, a filter change or opening the window goes back to the top (scrollToTop).
function renderWindow(w: Window)
	active = w
	local scroll = w.grid.CanvasPosition
	local token = w.scrollToken
	w.cashText.Text = Currency.format(profile.cash)
	if w.titleLabel ~= nil then
		w.titleLabel.Text = if w.inventory then w.title .. "  " .. collectionText() else w.title
	end
	renderSections(w)
	renderFilters(w)
	Ui.clearClones(w.grid, w.template.Name, "Item")
	local section = w.current
	if section == nil then
		return
	end
	local entries = entriesFor(section)
	if w.inventory then
		-- What you own comes first; the rest follows in catalogue order.
		local owned: { Entry } = {}
		local rest: { Entry } = {}
		for _, entry in entries do
			table.insert(if entry.owned then owned else rest, entry)
		end
		table.move(rest, 1, #rest, #owned + 1, owned)
		entries = owned
	end
	local shown = 0
	for _, entry in entries do
		if not Shop.matches(entry, w.filter) then
			continue
		end
		shown += 1
		local card = w.template:Clone()
		card.Name = "Item" .. shown
		card.LayoutOrder = shown
		fillCard(w, card, entry)
		card.Visible = true
		card.Parent = w.grid
	end
	if w.emptyLabel ~= nil then
		w.emptyLabel.Visible = shown == 0
	end
	w.grid.CanvasPosition = scroll
	-- The canvas regrows a frame later (AutomaticCanvasSize), which can clamp the position: set it again.
	task.defer(function()
		if w.grid.CanvasPosition ~= scroll and w.scrollToken == token then
			w.grid.CanvasPosition = scroll
		end
	end)
end


local function setBackdrop(w: Window, shown: boolean)
	w.scrim.Visible = shown
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

function openWindow(w: Window, open: boolean)
	if open then
		-- A pass bought on the website while playing shows up without a rejoin.
		Net.event("PassCheck"):FireServer()
		active = w
		renderWindow(w)
		scrollToTop(w)
		setBackdrop(w, true)
		Ui.pop(w.panel)
		Windows.opened(w.close)
	else
		w.close()
	end
end

local function fitToScreen(w: Window)
	Ui.fitPanel(w.gui.AbsoluteSize, w.panel, w.fit, w.layout, MARGIN, MIN_FIT, PORTRAIT_BELOW)
end

-- Portrait phone layout: the section keys wrap into rows above the toolbar, and the grid takes the rest.
local function portraitOverrides(w: Window): Ui.Overrides
	local overrides: Ui.Overrides = {
		Sections = { Position = UDim2.fromOffset(24, 104), Size = UDim2.new(1, -48, 0, 92) },
		["Sections/UIListLayout"] = { FillDirection = Enum.FillDirection.Horizontal, Wraps = true },
		["Sections/GetMore"] = { Visible = false },
		Tools = { Position = UDim2.fromOffset(24, 204), Size = UDim2.new(1, -48, 0, 40) },
		["Tools/Search"] = { Size = UDim2.new(1, -3 * 96 - 24, 1, 0) },
		["Tools/PriceFilter"] = { Size = UDim2.fromOffset(96, 40) },
		["Tools/RarityFilter"] = { Size = UDim2.fromOffset(96, 40) },
		["Tools/OwnedFilter"] = { Size = UDim2.fromOffset(96, 40) },
		Grid = { Position = UDim2.fromOffset(24, 256), Size = UDim2.new(1, -48, 1, -280) },
	}
	for _, section in w.sections do
		overrides["Sections/" .. section.name] = { Size = UDim2.fromOffset(110, 34) }
	end
	return overrides
end

local function bindSections(w: Window, frame: Instance)
	local buttons: { TextButton } = {}
	for _, child in frame:GetChildren() do
		if child:IsA("TextButton") then
			table.insert(buttons, child)
		end
	end
	table.sort(buttons, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for _, button in buttons do
		local kind = button:GetAttribute("Kind")
		if typeof(kind) ~= "string" then
			continue
		end
		local slotList = button:GetAttribute("Slots")
		local slots = if typeof(slotList) == "string" then string.split(slotList, ",") else {}
		local section: Section = { name = button.Name, kind = kind, slots = slots, button = button }
		table.insert(w.sections, section)
		w.sectionByName[button.Name] = section
		Ui.pressable(button)
		button.MouseButton1Click:Connect(function()
			Sfx.play("Pop", 0.4)
			goToIn(w, button.Name)
		end)
	end
	w.current = w.sections[1]
end

local function cycle(list: { string }, value: string): string
	local index = table.find(list, value) or 1
	return list[index % #list + 1]
end

local function bindTools(w: Window, frame: Instance)
	for _, name in { "PriceFilter", "RarityFilter", "OwnedFilter" } do
		local button = frame:FindFirstChild(name)
		if button ~= nil and button:IsA("TextButton") then
			w.filterKeys[name] = button
			Ui.pressable(button)
		end
	end
	local price = w.filterKeys.PriceFilter
	if price ~= nil then
		price.MouseButton1Click:Connect(function()
			w.filter.price = cycle(PRICES, w.filter.price)
			Sfx.play("Pop", 0.4)
			renderWindow(w)
			scrollToTop(w)
		end)
	end
	local rarity = w.filterKeys.RarityFilter
	if rarity ~= nil then
		rarity.MouseButton1Click:Connect(function()
			w.filter.rarity = cycle(RARITIES, w.filter.rarity)
			Sfx.play("Pop", 0.4)
			renderWindow(w)
			scrollToTop(w)
		end)
	end
	local owned = w.filterKeys.OwnedFilter
	if owned ~= nil then
		owned.MouseButton1Click:Connect(function()
			w.filter.hideOwned = not w.filter.hideOwned
			Sfx.play("Pop", 0.4)
			renderWindow(w)
			scrollToTop(w)
		end)
	end
	local search = frame:FindFirstChild("Search")
	if search ~= nil and search:IsA("TextBox") then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			w.filter.query = search.Text
			renderWindow(w)
			scrollToTop(w)
		end)
	end
end

-- Binds one authored screen (Scrim, Holder.Fit, Holder.Panel with Sections, Tools, Grid, CashText, Title,
-- CloseButton, an optional GetShells key) to a window record.
local function bindWindow(playerGui: PlayerGui, name: string, inventory: boolean): Window?
	local gui = Ui.screen(playerGui, name, 10)
	if gui == nil then
		warn("ShopUi: LobbyUi." .. name .. " is missing; that window stays closed")
		return nil
	end
	local holder = gui:WaitForChild("Holder") :: Frame
	local panel = holder:WaitForChild("Panel") :: Frame
	local grid = panel:WaitForChild("Grid") :: ScrollingFrame
	local title = panel:FindFirstChild("Title")
	local titleLabel = if title ~= nil and title:IsA("TextLabel") then title else nil
	local empty = grid:FindFirstChild("Empty")
	local w: Window = {
		name = name,
		inventory = inventory,
		gui = gui,
		panel = panel,
		scrim = gui:WaitForChild("Scrim") :: Frame,
		fit = holder:WaitForChild("Fit") :: UIScale,
		layout = nil,
		cashText = panel:WaitForChild("CashText") :: TextLabel,
		titleLabel = titleLabel,
		title = if titleLabel ~= nil then titleLabel.Text else "",
		grid = grid,
		template = grid:WaitForChild("ItemTemplate") :: Frame,
		emptyLabel = if empty ~= nil and empty:IsA("TextLabel") then empty else nil,
		sections = {},
		sectionByName = {},
		filterKeys = {},
		current = nil,
		filter = { query = "", price = "All", rarity = "All", hideOwned = false },
		scrollToken = 0,
		close = function() end,
	}
	w.close = function()
		pendingBuy = nil
		panel.Visible = false
		setBackdrop(w, false)
		Windows.closed(w.close)
	end
	bindSections(w, panel:WaitForChild("Sections"))
	bindTools(w, panel:WaitForChild("Tools"))
	w.layout = Ui.phoneLayout(panel, PORTRAIT_SIZE, portraitOverrides(w))
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitToScreen(w)
	end)
	fitToScreen(w)
	local plus = panel:FindFirstChild("GetShells")
	if plus ~= nil and plus:IsA("TextButton") then
		Ui.pressable(plus)
		plus.MouseButton1Click:Connect(function()
			Sfx.play("Pop", 0.4)
			active = w
			goToKind("Shells")
		end)
	end
	local close = panel:WaitForChild("CloseButton") :: TextButton
	Ui.pressable(close)
	close.MouseButton1Click:Connect(function()
		Sfx.play("Close", 0.5)
		openWindow(w, false)
	end)
	-- The Scrim sees every press, including those over the panel on top of it; only a press outside closes.
	w.scrim.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local corner = panel.AbsolutePosition
		local size = panel.AbsoluteSize
		local x, y = input.Position.X, input.Position.Y
		if x >= corner.X and x <= corner.X + size.X and y >= corner.Y and y <= corner.Y + size.Y then
			return
		end
		openWindow(w, false)
	end)
	table.insert(windows, w)
	return w
end

local function bindRailKey(keyName: string, w: Window?)
	local button = Rail.button(keyName)
	if button == nil or w == nil then
		return
	end
	button.Activated:Connect(function()
		if playing then
			return
		end
		Sfx.play("Open", 0.5)
		openWindow(w, true)
	end)
end

-- Binds LobbyUi.Shop (rail SHOP key), LobbyUi.Store (rail STORE key) and LobbyUi.Inventory (rail ITEMS key).
function ShopUi.init(playerGui: PlayerGui)
	blur = Lighting:FindFirstChild("ShopBlur") :: BlurEffect?
	shopWindow = bindWindow(playerGui, "Shop", false)
	bindRailKey("ShopButton", shopWindow)
	bindRailKey("StoreButton", bindWindow(playerGui, "Store", false))
	bindRailKey("InventoryButton", bindWindow(playerGui, "Inventory", true))
end

-- Opens the shop or store on one section by name ("Shells", "Chests"...), e.g. from a Starter Pack nudge.
function ShopUi.openTab(name: string)
	if playing then
		return
	end
	for _, w in windows do
		if not w.inventory and w.sectionByName[name] ~= nil then
			openWindow(w, true)
			goToIn(w, name)
			return
		end
	end
end

function ShopUi.onProfile(payload)
	profile = Profile.fromStored(payload)
	passes = payload.passes or {}
	chestsAllowed = payload.chestsAllowed == true
	for _, w in windows do
		if w.panel.Visible then
			renderWindow(w)
		end
	end
end

function ShopUi.onState(payload)
	playing = payload.playing == true
	if playing then
		for _, w in windows do
			if w.panel.Visible then
				openWindow(w, false)
			end
		end
	end
end

return ShopUi
