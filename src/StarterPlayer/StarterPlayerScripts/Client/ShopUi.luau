--!strict
-- Drives LobbyUi.Shop: the tabbed shop window for cosmetics, pets, toys, chests, passes and packs.
-- The server checks every buy, equip and chest; this only shows the state and sends requests.
-- Shells buys and chest openings take a second click within CONFIRM_SECONDS; reward items open the Rewards
-- panel; chest-only items jump to CHESTS; a Shells item you cannot afford offers GET SHELLS (the STORE tab).
--
-- Tabs are authored in Studio under Panel.Tabs. The current set is TABS; when a place still has only the
-- older five (Skins, Titles, Splashes, Trails, Passes) the shop falls back to OLD_TABS so it keeps working.

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
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

-- Tab name -> what it lists: cosmetic slots, or a special page.
local TABS = { "Hot", "Pets", "Skins", "Effects", "Style", "Toys", "Chests", "Store" }
local TAB_SLOTS: { [string]: { string } } = {
	Pets = { "Pet" },
	Skins = { "Skin" },
	Effects = { "Trail", "Aura", "Splash" },
	Style = { "Title", "NameTag", "CardTheme" },
	Toys = { "Toy" },
	-- The older authored tabs.
	Titles = { "Title" },
	Splashes = { "Splash" },
	Trails = { "Trail" },
}
local OLD_TABS = { "Skins", "Titles", "Splashes", "Trails", "Passes" }
local STORE_TABS: { [string]: boolean } = { Store = true, Passes = true }

local BLUR_SIZE = 12
local GOLD = Color3.fromRGB(255, 194, 75)
local MUTED = Color3.fromRGB(122, 140, 160)
local GREEN = Color3.fromRGB(120, 235, 140)
local CARD_SHADOW_REST = UDim2.fromOffset(0, 6)
local CARD_SHADOW_HOVER = UDim2.fromOffset(0, 12)
local CONFIRM_SECONDS = 3 -- a Shells buy or chest needs a second click within this long
local SOON = "COMING SOON" -- Robux entries whose id is still the 0 placeholder
local LONG_PRICE = 18 -- longer price lines (the pass perks) shrink to fit their label
local LONG_ACTION = 8

-- The emoji drawn in a card's Preview.Emoji label (when the template has one), by slot or item.
local SLOT_EMOJI: { [string]: string } = {
	Aura = "✨",
	CardTheme = "🃏",
	NameTag = "🏷️",
	Toy = "🍅",
	Pet = "🐟",
}
local ITEM_EMOJI: { [string]: string } = {
	pet_clownfish = "🐠",
	pet_crab = "🦀",
	pet_turtle = "🐢",
	pet_jelly = "🎐",
	pet_puffer = "🐡",
	pet_octopus = "🐙",
	pet_seahorse = "🐎",
	pet_axolotl = "🦎",
	pet_narwhal = "🦄",
	pet_shark = "🦈",
	pet_whale = "🐋",
	pet_krill = "🦐",
	toy_tomato = "🍅",
	toy_snowball = "❄️",
	toy_pie = "🥧",
	toy_balloon = "🎈",
	toy_fish = "🐟",
	toy_confetti = "🎉",
	aura_frost = "❄️",
	aura_flame = "🔥",
	aura_electric = "⚡",
	aura_halo = "😇",
	aura_bubbles = "🫧",
	aura_void = "🌑",
	aura_rainbow = "🌈",
}
local PASS_EMOJI: { [string]: string } = { Vip = "👑", DoubleCash = "💰", SecondChance = "❤️", BoostPlus = "⚡" }

type Entry = {
	kind: string, -- a cosmetic slot, "Shop" (passes and products), "Chest" or "Odds"
	name: string,
	price: string,
	currency: string?, -- "Cash" (Shells) shows the coin mark; nil shows the price text alone
	priceColor: Color3?,
	badge: string?, -- "EQUIPPED" | "OWNED" | "FREE" | "NEW" | "HOT" | "n OWNED" | nil
	action: string,
	enabled: boolean,
	color: Color3,
	rarity: string?, -- colours the card border
	emoji: string?,
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
local tabs: { string } = TABS

local current = "Hot"
local profile: Profile.Profile = Profile.new()
local passes: { [string]: boolean } = {}
local chestsAllowed = false
local playing = false
local pendingBuy: { id: string, at: number }? = nil -- the Shells buy or chest waiting for its CONFIRM? click

local ShopUi = {}

local render: () -> ()
local setOpen: (boolean) -> ()

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

local function goTo(tab: string)
	if tabButtons[tab] == nil then
		-- The older authored tabs have no CHESTS or STORE; PASSES is the store there.
		tab = if STORE_TABS[tab] then "Passes" else current
	end
	current = tab
	render()
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
			if panel.Visible then
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
		price = "",
		currency = nil,
		priceColor = nil,
		badge = nil,
		action = "",
		enabled = true,
		color = color,
		rarity = nil,
		emoji = nil,
		stripe = nil,
		onClick = function() end,
	}
end

local function cosmeticEntry(item: Cosmetics.Item): Entry
	local owned = Shop.owns(profile, item, passes)
	local equipped = (profile.equipped :: any)[item.slot] == item.id
	local entry = emptyEntry(item.slot, string.upper(item.name), colorOf(item))
	entry.rarity = item.rarity
	entry.emoji = ITEM_EMOJI[item.id] or SLOT_EMOJI[item.slot]
	entry.stripe = if item.trail ~= nil then trailColors(item) else nil
	entry.badge = item.label
	local bonus = if item.shellBonus ~= nil then "+" .. math.floor(item.shellBonus * 100 + 0.5) .. "% " .. Currency.Upper else nil
	if owned then
		if equipped then
			entry.badge = "EQUIPPED"
			entry.price = bonus or "In use"
			entry.action = "UNEQUIP"
			entry.onClick = function()
				Net.event("ShopEquip"):FireServer(item.slot, "")
			end
		else
			entry.badge = "OWNED"
			entry.price = bonus or "Ready to equip"
			entry.action = "EQUIP"
			entry.onClick = function()
				Net.event("ShopEquip"):FireServer(item.slot, item.id)
			end
		end
		if bonus ~= nil then
			entry.priceColor = GREEN
		end
		return entry
	end
	local source = Cosmetics.source(item)
	if source == "reward" then
		-- Never sold: RewardService grants it, so GET opens the panel that says how.
		entry.badge = "FREE"
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
			goTo("Store")
		end
	elseif source == "chest" then
		local chest = chestFor(item.id)
		entry.price = if chest ~= nil then "In the " .. chest.name else "In a chest"
		entry.action = "CHESTS"
		entry.enabled = chestsAllowed
		entry.onClick = function()
			goTo("Chests")
		end
	elseif source == "robux" then
		entry.price = "R$ " .. tostring(item.robux or 0)
		entry.priceColor = GOLD
		entry.enabled = item.robuxProductId ~= 0
		entry.action = if entry.enabled then "BUY" else SOON
		entry.onClick = function()
			promptProduct(item.robuxProductId :: number)
		end
	else
		entry.price = Currency.digits(item.price) .. (if bonus ~= nil then "  |  " .. bonus else "")
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
				goTo("Store")
			end
		end
	end
	return entry
end

local function passPerks(key: string): string
	if key == "Vip" then
		local bonus = math.floor(GameConfig.Cash.VipBonus * 100 + 0.5)
		return "+" .. bonus .. "% " .. Currency.Upper .. "  |  AURORA PILLAR  |  GOLD WAKE  |  VIP TITLE AND TAG"
	elseif key == "DoubleCash" then
		return "Double every " .. Currency.Upper .. " you earn"
	elseif key == "SecondChance" then
		return "One free revive every match"
	elseif key == "BoostPlus" then
		return GameConfig.Boosts.PerMatchPlus .. " hints and " .. GameConfig.Boosts.PerMatchPlus .. " +time per match"
	end
	return "Game pass"
end

local PASS_NAMES: { [string]: string } = {
	Vip = "VIP",
	DoubleCash = "2X " .. Currency.Upper,
	SecondChance = "SECOND CHANCE",
	BoostPlus = "BOOST PLUS",
}

local function passEntry(key: string): Entry
	local passId = (Products.Passes :: any)[key] :: number
	local robux = (Products.PassPrices :: any)[key] :: number?
	local owned = passes[key] == true
	local entry = emptyEntry("Shop", PASS_NAMES[key] or string.upper(key), GOLD)
	entry.rarity = "Legendary"
	entry.emoji = PASS_EMOJI[key]
	entry.price = passPerks(key)
	entry.priceColor = MUTED
	entry.enabled = passId ~= 0 and not owned
	entry.action = if robux ~= nil then "R$ " .. robux else "BUY"
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
	entry.badge = "ONCE"
	-- Short enough to read on the card: the Shells and what kinds of items come with them.
	local kinds = {}
	for _, id in pack.items do
		local item = Cosmetics.ById[id]
		if item ~= nil then
			table.insert(kinds, string.upper(item.slot))
		end
	end
	entry.price = Currency.digits(pack.cash) .. " " .. Theme.Icon.Shell .. " + " .. table.concat(kinds, " + ")
	entry.priceColor = GOLD
	entry.action = if pack.productId ~= 0 then "R$ " .. pack.robux else SOON
	return entry
end

local function packEntries(entries: { Entry })
	for index, pack in Products.CashPacks do
		local entry = productEntry(Currency.format(pack.cash), pack.robux, pack.productId, Theme.Icon.Shell)
		entry.rarity = Cosmetics.Rarities[math.min(index, #Cosmetics.Rarities)]
		if index == #Products.CashPacks then
			entry.badge = "BEST VALUE"
		end
		table.insert(entries, entry)
	end
end

-- What a boost costs when used from its in-match button; there is nothing to buy here.
local function boostShellsEntry(name: string, shells: number, emoji: string): Entry
	local entry = emptyEntry("Shop", name, GOLD)
	entry.emoji = emoji
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
	if profile.hints > 0 then
		hint.badge = profile.hints .. " OWNED"
	end
	table.insert(entries, hint)
	table.insert(entries, boostShellsEntry(timeName, GameConfig.Boosts.ExtraTimeShells, Theme.Icon.Time))
	local extra = productEntry(timeName .. " x1", Products.Boosts.ExtraTime.robux, Products.Boosts.ExtraTime.productId, Theme.Icon.Time)
	if profile.extraTimes > 0 then
		extra.badge = profile.extraTimes .. " OWNED"
	end
	table.insert(entries, extra)
	for _, pack in Products.BoostPacks do
		local name = (if pack.kind == "Hint" then hintName else timeName) .. " x" .. pack.count
		local emoji = if pack.kind == "Hint" then Theme.Icon.Hint else Theme.Icon.Time
		local entry = productEntry(name, pack.robux, pack.productId, emoji)
		entry.badge = "SAVE"
		table.insert(entries, entry)
	end
end

local function storeEntries(entries: { Entry })
	local starter = starterEntry()
	if starter ~= nil then
		table.insert(entries, starter)
	end
	for _, key in Products.PassOrder do
		table.insert(entries, passEntry(key))
	end
	local revive = productEntry("REVIVE", Products.Revive.robux, Products.Revive.productId, "❤️")
	if profile.revives > 0 then
		revive.badge = profile.revives .. " OWNED"
	end
	table.insert(entries, revive)
	boostEntries(entries)
	packEntries(entries)
end

local function chestEntries(entries: { Entry })
	if not chestsAllowed then
		local blocked = emptyEntry("Shop", "CHESTS", MUTED)
		blocked.emoji = Theme.Icon.Chest
		blocked.price = "Not available where you live"
		blocked.priceColor = MUTED
		blocked.action = "LOCKED"
		blocked.enabled = false
		table.insert(entries, blocked)
		return
	end
	for _, chest in Chests.List do
		local entry = emptyEntry("Chest", string.upper(chest.name), rgb(chest.color, GOLD))
		entry.emoji = Theme.Icon.Chest
		entry.rarity = if chest.price >= 1000 then "Epic" else "Rare"
		entry.price = Currency.digits(chest.price)
		entry.currency = "Cash"
		if profile.cash >= chest.price then
			entry.action = if isConfirming(chest.id) then "CONFIRM?" else "OPEN"
			entry.onClick = function()
				confirmThen(chest.id, function()
					Net.event("ChestOpen"):FireServer(chest.id)
				end)
			end
		else
			entry.action = "GET " .. Theme.Icon.Shell
			entry.onClick = function()
				goTo("Store")
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
				entry.emoji = ITEM_EMOJI[item.id] or SLOT_EMOJI[item.slot]
				entry.price = chest.name .. "  |  " .. Chests.percent(drop.chance)
				entry.priceColor = Theme.Rarity[item.rarity] or MUTED
				entry.action = string.upper(item.rarity)
				entry.enabled = false
				if Shop.owns(profile, item, passes) then
					entry.badge = "OWNED"
				end
				table.insert(entries, entry)
			end
		end
	end
end

local function hotEntries(entries: { Entry })
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
	local best = Products.CashPacks[#Products.CashPacks]
	local pack = productEntry(Currency.format(best.cash), best.robux, best.productId, Theme.Icon.Shell)
	pack.rarity = "Legendary"
	pack.badge = "BEST VALUE"
	table.insert(entries, pack)
	if passes.DoubleCash ~= true then
		table.insert(entries, passEntry("DoubleCash"))
	end
end

local function entriesFor(tab: string): { Entry }
	local entries: { Entry } = {}
	local slots = TAB_SLOTS[tab]
	if slots ~= nil then
		for _, slot in slots do
			for _, item in Cosmetics.inSlot(slot) do
				table.insert(entries, cosmeticEntry(item))
			end
		end
	elseif tab == "Hot" then
		hotEntries(entries)
	elseif tab == "Chests" then
		chestEntries(entries)
	elseif STORE_TABS[tab] then
		storeEntries(entries)
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
		local border = card:FindFirstChild("Border")
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
			priceLabel.TextColor3 = entry.priceColor or MUTED
		end
		-- Rarity colours the card's border; cards with no rarity keep the authored one.
		if border ~= nil and border:IsA("UIStroke") then
			local rarityColor = if entry.rarity ~= nil then Theme.Rarity[entry.rarity] else nil
			if rarityColor ~= nil then
				border.Color = rarityColor
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
		-- A pass bought on the website while playing shows up without a rejoin.
		Net.event("PassCheck"):FireServer()
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

-- Uses the current tab set when the place has every one of its buttons, else the older five. Buttons of
-- the set not in use are hidden so the authored row lays out only the live tabs.
local function bindTabs(row: Instance)
	local useNew = true
	for _, name in TABS do
		local button = row:FindFirstChild(name)
		if button == nil or not button:IsA("TextButton") then
			useNew = false
		end
	end
	tabs = if useNew then TABS else OLD_TABS
	local live: { [string]: boolean } = {}
	for _, name in tabs do
		live[name] = true
	end
	for _, child in row:GetChildren() do
		if child:IsA("TextButton") then
			child.Visible = live[child.Name] == true
		end
	end
	-- The live tabs share the row evenly (the authored widths are for the older five).
	local layout = row:FindFirstChildOfClass("UIListLayout")
	local gap = if layout ~= nil then layout.Padding.Offset else 8
	for _, name in tabs do
		local button = row:WaitForChild(name) :: TextButton
		if useNew then
			button.Size = UDim2.new(1 / #tabs, -math.ceil(gap * (#tabs - 1) / #tabs), 1, 0)
		end
		tabButtons[name] = button
		Ui.pressable(button)
		button.MouseButton1Click:Connect(function()
			current = name
			Sfx.play("Pop", 0.4)
			render()
		end)
	end
	current = tabs[1]
end

function ShopUi.init(playerGui: PlayerGui)
	gui = Ui.screen(playerGui, "Shop") :: Frame
	panel = gui:WaitForChild("Panel") :: Frame
	scrim = gui:WaitForChild("Scrim") :: Frame
	blur = Lighting:FindFirstChild("ShopBlur") :: BlurEffect?
	cashText = panel:WaitForChild("CashText") :: TextLabel
	grid = panel:WaitForChild("Grid") :: ScrollingFrame
	template = grid:WaitForChild("ItemTemplate") :: Frame
	bindTabs(panel:WaitForChild("Tabs"))
	local close = panel:WaitForChild("CloseButton") :: TextButton
	Ui.pressable(close)
	close.MouseButton1Click:Connect(function()
		Sfx.play("Close", 0.5)
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
			Sfx.play("Open", 0.5)
			setOpen(true)
		end)
	end
end

-- Opens the shop on one tab ("Store", "Chests"...), e.g. from a Starter Pack nudge.
function ShopUi.openTab(tab: string)
	if playing then
		return
	end
	setOpen(true)
	goTo(tab)
end

function ShopUi.onProfile(payload)
	profile = Profile.fromStored(payload)
	passes = payload.passes or {}
	chestsAllowed = payload.chestsAllowed == true
	if panel.Visible then
		render()
	end
end

function ShopUi.onState(payload)
	playing = payload.playing == true
	refreshButton()
end

return ShopUi
