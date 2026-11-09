--!strict
-- The cosmetic catalogue. Priced in Shells (the `cash` field), or Robux-only when `robuxProductId` is set
-- (0 = placeholder until the developer product exists).
--
-- Slots:
--   Skin      recolours your pillar (`color`, `top`, `material`)
--   Title     floats over your head (`color`)
--   Splash    plays where you sink (Templates.Splashes.<splash>)
--   Trail     follows you around (Templates.Trails.<trail>)
--   Pet       swims beside you and adds `shellBonus` to earned Shells (Templates.Pets.<pet>)
--   Aura      a particle glow on your character (Templates.Auras.<aura>)
--   CardTheme colours your dive card and answer tag (`card`)
--   NameTag   colours your pillar name tag (`tag`, one colour or a gradient)
--   Toy       a throwable for the lobby (Templates.Toys.<toy>)
--
-- `pass` items come with a game pass; `reward` items are never sold and only RewardService grants them;
-- `chestOnly` items only come out of a chest (Config/Chests). Item ids are saved in profiles: never rename
-- one. `rarity` sets the card frame colour (Theme.Rarity); `label` is an optional NEW / HOT / LIMITED badge.

export type Rgb = { number }

export type CardColors = {
	header: Rgb, -- the YOUR DIVE header bar
	frame: Rgb, -- the card face around the water window
	tag: Rgb, -- the answer tag sinking through the water
}

export type Item = {
	id: string,
	slot: string,
	name: string,
	rarity: string, -- "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"
	price: number, -- Shells; ignored for Robux, pass, reward and chest-only items
	sort: number?, -- lower comes first within a rarity; defaults to the price
	label: string?, -- "NEW" | "HOT" | "LIMITED"
	robuxProductId: number?,
	robux: number?, -- shown price for Robux items
	pass: string?, -- owned automatically by holders of this game pass (key in Products.Passes)
	reward: string?, -- unlocked by this free reward (key in RewardHow): Group, Referral1, Referral3
	chestOnly: boolean?,
	color: Rgb?, -- the skin, the title text, and every item's shop preview colour
	top: Rgb?, -- RGB for the pillar cap; skins without one get a lightened `color`
	material: string?, -- Enum.Material name, for skins
	splash: string?,
	trail: string?,
	pet: string?,
	shellBonus: number?, -- pets: added to the earned-Shells multiplier (0.05 = +5%)
	aura: string?,
	card: CardColors?,
	tag: { Rgb }?, -- name tag text colours: one colour, or two or more for a gradient
	toy: string?,
}

local list: { Item } = {
	-- Skins -------------------------------------------------------------------------------------------------
	{ id = "skin_coral", slot = "Skin", name = "Coral", rarity = "Common", price = 300, color = { 255, 120, 110 }, material = "SmoothPlastic" },
	{ id = "skin_kelp", slot = "Skin", name = "Kelp", rarity = "Common", price = 300, color = { 70, 150, 90 }, material = "SmoothPlastic" },
	{ id = "skin_bubblegum", slot = "Skin", name = "Bubblegum", rarity = "Common", price = 350, label = "NEW", color = { 255, 140, 200 }, top = { 255, 210, 235 }, material = "SmoothPlastic" },
	{ id = "skin_mint", slot = "Skin", name = "Mint Chip", rarity = "Common", price = 400, label = "NEW", color = { 150, 235, 190 }, top = { 90, 60, 50 }, material = "SmoothPlastic" },
	{ id = "skin_lagoon", slot = "Skin", name = "Lagoon", rarity = "Rare", price = 450, color = { 38, 198, 196 }, top = { 190, 250, 245 }, material = "SmoothPlastic" },
	{ id = "skin_sunset", slot = "Skin", name = "Sunset", rarity = "Rare", price = 750, label = "NEW", color = { 255, 120, 70 }, top = { 255, 205, 90 }, material = "SmoothPlastic" },
	{ id = "skin_glass", slot = "Skin", name = "Sea Glass", rarity = "Rare", price = 900, color = { 150, 225, 220 }, material = "Glass" },
	{ id = "skin_pearl", slot = "Skin", name = "Pearl", rarity = "Rare", price = 1050, color = { 240, 240, 248 }, top = { 255, 255, 255 }, material = "Marble" },
	{ id = "skin_neon", slot = "Skin", name = "Neon Reef", rarity = "Epic", price = 1200, label = "HOT", color = { 60, 255, 170 }, top = { 255, 80, 220 }, material = "Neon" },
	{ id = "skin_abyss", slot = "Skin", name = "Abyss", rarity = "Epic", price = 1500, color = { 14, 28, 60 }, top = { 80, 170, 255 }, material = "Slate" },
	{ id = "skin_glacier", slot = "Skin", name = "Glacier", rarity = "Epic", price = 1800, color = { 170, 220, 255 }, top = { 235, 248, 255 }, material = "Ice" },
	{ id = "skin_volcano", slot = "Skin", name = "Volcano", rarity = "Legendary", price = 2400, color = { 45, 40, 44 }, top = { 255, 110, 40 }, material = "Basalt" },
	{ id = "skin_lava", slot = "Skin", name = "Molten", rarity = "Epic", price = 0, robuxProductId = 3729794371, robux = 99, label = "HOT", color = { 255, 90, 30 }, top = { 255, 200, 60 }, material = "CrackedLava" },
	{ id = "skin_gold", slot = "Skin", name = "Gold", rarity = "Legendary", price = 0, robuxProductId = 3729794381, robux = 99, color = { 255, 200, 70 }, material = "Foil" },
	{ id = "skin_galaxy", slot = "Skin", name = "Galaxy", rarity = "Legendary", price = 0, robuxProductId = 3729794393, robux = 149, label = "NEW", color = { 60, 30, 120 }, top = { 200, 120, 255 }, material = "Glass" },
	{ id = "skin_aurora", slot = "Skin", name = "Aurora", rarity = "Legendary", price = 0, pass = "Vip", color = { 120, 90, 255 }, top = { 120, 255, 220 }, material = "Glass" },
	{ id = "skin_kraken", slot = "Skin", name = "Kraken Ink", rarity = "Legendary", price = 0, chestOnly = true, color = { 30, 10, 45 }, top = { 170, 60, 255 }, material = "Neon" },
	{ id = "skin_prism", slot = "Skin", name = "Prism", rarity = "Mythic", price = 0, chestOnly = true, color = { 255, 255, 255 }, top = { 140, 255, 255 }, material = "Glass" },
	{ id = "skin_buddy", slot = "Skin", name = "Buddy System", rarity = "Rare", price = 0, reward = "Referral1", color = { 255, 150, 40 }, top = { 255, 220, 150 }, material = "Plastic" },

	-- Titles ------------------------------------------------------------------------------------------------
	{ id = "title_rookie", slot = "Title", name = "Rookie Diver", rarity = "Common", price = 150, color = { 200, 230, 255 } },
	{ id = "title_diver", slot = "Title", name = "Deep Diver", rarity = "Common", price = 250, color = { 120, 200, 255 } },
	{ id = "title_shark", slot = "Title", name = "Shark", rarity = "Rare", price = 600, color = { 170, 185, 200 } },
	{ id = "title_knowitall", slot = "Title", name = "Know-It-All", rarity = "Rare", price = 700, label = "NEW", color = { 255, 230, 120 } },
	{ id = "title_tide", slot = "Title", name = "Tidecaller", rarity = "Rare", price = 900, color = { 90, 220, 255 } },
	{ id = "title_krill", slot = "Title", name = "Krill Lord", rarity = "Epic", price = 1500, color = { 255, 140, 90 } },
	{ id = "title_niche", slot = "Title", name = "Niche Lord", rarity = "Epic", price = 1800, label = "HOT", color = { 200, 120, 255 } },
	{ id = "title_abyssal", slot = "Title", name = "Abyssal", rarity = "Epic", price = 2000, color = { 120, 140, 255 } },
	{ id = "title_krillionaire", slot = "Title", name = "Krillionaire", rarity = "Legendary", price = 5000, color = { 255, 200, 60 } },
	{ id = "title_kraken", slot = "Title", name = "The Kraken", rarity = "Mythic", price = 0, chestOnly = true, color = { 190, 80, 255 } },
	{ id = "title_vip", slot = "Title", name = "VIP", rarity = "Legendary", price = 0, pass = "Vip", color = { 255, 210, 80 } },
	{ id = "title_crew", slot = "Title", name = "Reef Crew", rarity = "Rare", price = 0, reward = "Group", color = { 38, 198, 196 } },

	-- Splashes ----------------------------------------------------------------------------------------------
	{ id = "splash_bubbles", slot = "Splash", name = "Bubble Burst", rarity = "Rare", price = 400, splash = "Bubbles", color = { 170, 225, 255 } },
	{ id = "splash_ink", slot = "Splash", name = "Ink Cloud", rarity = "Epic", price = 800, splash = "Ink", color = { 150, 110, 210 } },
	{ id = "splash_stars", slot = "Splash", name = "Starfall", rarity = "Legendary", price = 0, robuxProductId = 3729794407, robux = 79, splash = "Stars", color = { 255, 215, 110 } },

	-- Trails (the template's Trail.Color is what shows in game; `color` is the shop preview) ------------------
	{ id = "trail_bubbles", slot = "Trail", name = "Bubbles", rarity = "Common", price = 300, trail = "Bubbles", color = { 160, 220, 255 } },
	{ id = "trail_seafoam", slot = "Trail", name = "Seafoam", rarity = "Common", price = 600, trail = "Seafoam", color = { 38, 198, 196 } },
	{ id = "trail_neon", slot = "Trail", name = "Neon Streak", rarity = "Rare", price = 800, label = "NEW", trail = "Neon", color = { 60, 255, 170 } },
	{ id = "trail_sunset", slot = "Trail", name = "Sunset Reef", rarity = "Rare", price = 900, trail = "Sunset", color = { 255, 120, 120 } },
	{ id = "trail_abyssal", slot = "Trail", name = "Abyssal", rarity = "Epic", price = 1350, trail = "Abyssal", color = { 181, 80, 235 } },
	{ id = "trail_fire", slot = "Trail", name = "Fire Wake", rarity = "Epic", price = 1800, label = "HOT", trail = "Fire", color = { 255, 110, 40 } },
	{ id = "trail_rainbow", slot = "Trail", name = "Rainbow Fish", rarity = "Legendary", price = 2700, trail = "Rainbow", color = { 255, 120, 200 } },
	{ id = "trail_galaxy", slot = "Trail", name = "Galaxy Wake", rarity = "Mythic", price = 0, chestOnly = true, trail = "Galaxy", color = { 150, 90, 255 } },
	{ id = "trail_goldwake", slot = "Trail", name = "Gold Wake", rarity = "Legendary", price = 0, pass = "Vip", trail = "GoldWake", color = { 255, 200, 61 } },
	{ id = "trail_pod", slot = "Trail", name = "Pod Wake", rarity = "Rare", price = 0, reward = "Referral3", trail = "Pod", color = { 255, 150, 40 } },

	-- Pets: one at a time, so their Shells bonuses never stack ---------------------------------------------
	{ id = "pet_clownfish", slot = "Pet", name = "Clownfish", rarity = "Common", price = 500, pet = "Clownfish", shellBonus = 0.05, color = { 255, 140, 40 } },
	{ id = "pet_crab", slot = "Pet", name = "Crab", rarity = "Common", price = 600, pet = "Crab", shellBonus = 0.05, color = { 235, 70, 60 } },
	{ id = "pet_turtle", slot = "Pet", name = "Sea Turtle", rarity = "Rare", price = 1200, pet = "Turtle", shellBonus = 0.08, color = { 90, 170, 90 } },
	{ id = "pet_jelly", slot = "Pet", name = "Jellyfish", rarity = "Rare", price = 1400, label = "NEW", pet = "Jelly", shellBonus = 0.08, color = { 255, 150, 230 } },
	{ id = "pet_puffer", slot = "Pet", name = "Pufferfish", rarity = "Rare", price = 0, chestOnly = true, pet = "Puffer", shellBonus = 0.1, color = { 240, 210, 90 } },
	{ id = "pet_octopus", slot = "Pet", name = "Octopus", rarity = "Epic", price = 3000, label = "HOT", pet = "Octopus", shellBonus = 0.12, color = { 190, 80, 200 } },
	{ id = "pet_seahorse", slot = "Pet", name = "Seahorse", rarity = "Epic", price = 0, chestOnly = true, pet = "Seahorse", shellBonus = 0.12, color = { 255, 190, 70 } },
	{ id = "pet_axolotl", slot = "Pet", name = "Axolotl", rarity = "Epic", price = 0, robuxProductId = 3729794417, robux = 149, pet = "Axolotl", shellBonus = 0.15, color = { 255, 170, 200 } },
	{ id = "pet_narwhal", slot = "Pet", name = "Narwhal", rarity = "Legendary", price = 9000, pet = "Narwhal", shellBonus = 0.18, color = { 170, 210, 240 } },
	{ id = "pet_shark", slot = "Pet", name = "Great White", rarity = "Legendary", price = 0, chestOnly = true, pet = "Shark", shellBonus = 0.18, color = { 140, 160, 180 } },
	{ id = "pet_whale", slot = "Pet", name = "Blue Whale", rarity = "Legendary", price = 0, robuxProductId = 3729794543, robux = 299, pet = "Whale", shellBonus = 0.2, color = { 60, 110, 220 } },
	{ id = "pet_krill", slot = "Pet", name = "Golden Krill", rarity = "Mythic", price = 0, chestOnly = true, pet = "GoldenKrill", shellBonus = 0.25, color = { 255, 210, 60 } },

	-- Auras -------------------------------------------------------------------------------------------------
	{ id = "aura_sparkle", slot = "Aura", name = "Sparkle", rarity = "Common", price = 400, aura = "Sparkle", color = { 255, 255, 200 } },
	{ id = "aura_bubbles", slot = "Aura", name = "Bubble Cloud", rarity = "Rare", price = 800, aura = "Bubbles", color = { 160, 220, 255 } },
	{ id = "aura_frost", slot = "Aura", name = "Frost", rarity = "Rare", price = 900, aura = "Frost", color = { 190, 240, 255 } },
	{ id = "aura_flame", slot = "Aura", name = "Flame", rarity = "Epic", price = 1600, label = "HOT", aura = "Flame", color = { 255, 120, 40 } },
	{ id = "aura_electric", slot = "Aura", name = "Electric", rarity = "Epic", price = 2000, aura = "Electric", color = { 120, 200, 255 } },
	{ id = "aura_halo", slot = "Aura", name = "Halo", rarity = "Legendary", price = 0, robuxProductId = 3729794556, robux = 99, aura = "Halo", color = { 255, 230, 140 } },
	{ id = "aura_void", slot = "Aura", name = "Void", rarity = "Legendary", price = 0, chestOnly = true, aura = "Void", color = { 90, 40, 160 } },
	{ id = "aura_rainbow", slot = "Aura", name = "Rainbow", rarity = "Mythic", price = 0, chestOnly = true, aura = "Rainbow", color = { 255, 120, 200 } },

	-- Dive card themes --------------------------------------------------------------------------------------
	{ id = "card_sunset", slot = "CardTheme", name = "Sunset Card", rarity = "Common", price = 400, color = { 255, 140, 80 }, card = { header = { 255, 120, 70 }, frame = { 120, 40, 60 }, tag = { 255, 230, 200 } } },
	{ id = "card_coral", slot = "CardTheme", name = "Coral Card", rarity = "Rare", price = 900, color = { 255, 120, 140 }, card = { header = { 255, 110, 140 }, frame = { 110, 30, 70 }, tag = { 255, 220, 230 } } },
	{ id = "card_neon", slot = "CardTheme", name = "Neon Card", rarity = "Rare", price = 900, label = "NEW", color = { 60, 255, 170 }, card = { header = { 40, 220, 150 }, frame = { 10, 30, 40 }, tag = { 200, 255, 230 } } },
	{ id = "card_midnight", slot = "CardTheme", name = "Midnight Card", rarity = "Epic", price = 1500, color = { 60, 70, 160 }, card = { header = { 70, 80, 200 }, frame = { 12, 14, 40 }, tag = { 210, 220, 255 } } },
	{ id = "card_candy", slot = "CardTheme", name = "Candy Card", rarity = "Epic", price = 1500, color = { 255, 150, 220 }, card = { header = { 255, 120, 210 }, frame = { 120, 60, 180 }, tag = { 255, 240, 250 } } },
	{ id = "card_gold", slot = "CardTheme", name = "Gold Card", rarity = "Legendary", price = 0, robuxProductId = 3729794569, robux = 79, color = { 255, 200, 60 }, card = { header = { 255, 190, 40 }, frame = { 110, 70, 10 }, tag = { 255, 245, 200 } } },
	{ id = "card_galaxy", slot = "CardTheme", name = "Galaxy Card", rarity = "Legendary", price = 0, chestOnly = true, color = { 150, 90, 255 }, card = { header = { 130, 70, 240 }, frame = { 20, 10, 45 }, tag = { 230, 210, 255 } } },
	{ id = "card_kraken", slot = "CardTheme", name = "Kraken Card", rarity = "Mythic", price = 0, chestOnly = true, color = { 190, 80, 255 }, card = { header = { 170, 40, 220 }, frame = { 30, 5, 40 }, tag = { 255, 200, 255 } } },

	-- Name tags ---------------------------------------------------------------------------------------------
	{ id = "tag_sky", slot = "NameTag", name = "Sky Tag", rarity = "Common", price = 300, color = { 120, 200, 255 }, tag = { { 120, 200, 255 } } },
	{ id = "tag_mint", slot = "NameTag", name = "Mint Tag", rarity = "Common", price = 300, color = { 120, 240, 180 }, tag = { { 120, 240, 180 } } },
	{ id = "tag_pink", slot = "NameTag", name = "Pink Tag", rarity = "Rare", price = 600, color = { 255, 130, 200 }, tag = { { 255, 130, 200 } } },
	{ id = "tag_gold", slot = "NameTag", name = "Gold Tag", rarity = "Epic", price = 1200, color = { 255, 210, 70 }, tag = { { 255, 230, 120 }, { 255, 170, 30 } } },
	{ id = "tag_fire", slot = "NameTag", name = "Fire Tag", rarity = "Epic", price = 1500, label = "HOT", color = { 255, 110, 40 }, tag = { { 255, 220, 80 }, { 255, 70, 40 } } },
	{ id = "tag_ice", slot = "NameTag", name = "Ice Tag", rarity = "Legendary", price = 0, chestOnly = true, color = { 180, 240, 255 }, tag = { { 255, 255, 255 }, { 120, 210, 255 } } },
	{ id = "tag_rainbow", slot = "NameTag", name = "Rainbow Tag", rarity = "Legendary", price = 0, robuxProductId = 3729794585, robux = 49, color = { 255, 120, 200 }, tag = { { 255, 90, 90 }, { 255, 220, 80 }, { 90, 220, 120 }, { 90, 160, 255 }, { 200, 110, 255 } } },
	{ id = "tag_vip", slot = "NameTag", name = "VIP Tag", rarity = "Legendary", price = 0, pass = "Vip", color = { 255, 210, 80 }, tag = { { 255, 240, 150 }, { 255, 180, 40 } } },

	-- Toys: lobby throwables, owned forever ---------------------------------------------------------------
	{ id = "toy_tomato", slot = "Toy", name = "Tomato", rarity = "Common", price = 250, label = "HOT", toy = "Tomato", color = { 230, 50, 40 } },
	{ id = "toy_snowball", slot = "Toy", name = "Snowball", rarity = "Rare", price = 600, toy = "Snowball", color = { 240, 248, 255 } },
	{ id = "toy_pie", slot = "Toy", name = "Cream Pie", rarity = "Rare", price = 600, toy = "Pie", color = { 255, 235, 200 } },
	{ id = "toy_balloon", slot = "Toy", name = "Water Balloon", rarity = "Epic", price = 1200, toy = "Balloon", color = { 80, 170, 255 } },
	{ id = "toy_fish", slot = "Toy", name = "Fish Slap", rarity = "Epic", price = 1500, label = "NEW", toy = "Fish", color = { 150, 190, 210 } },
	{ id = "toy_confetti", slot = "Toy", name = "Confetti Bomb", rarity = "Legendary", price = 0, robuxProductId = 3729794609, robux = 49, toy = "Confetti", color = { 255, 120, 200 } },
}

local byId: { [string]: Item } = {}
for _, item in list do
	byId[item.id] = item
end

-- What unlocks each reward item, as the shop card says it.
local rewardHow: { [string]: string } = { Group = "JOIN GROUP", Referral1 = "INVITE 1 FRIEND", Referral3 = "INVITE 3 FRIENDS" }

-- Every slot, in shop order. Equipped is keyed by these names.
local slotOrder = { "Skin", "Pet", "Aura", "Trail", "Title", "NameTag", "CardTheme", "Splash", "Toy" }
local slots: { [string]: boolean } = {}
for _, slot in slotOrder do
	slots[slot] = true
end

local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
local rarityRank: { [string]: number } = {}
for index, rarity in rarities do
	rarityRank[rarity] = index
end

local Cosmetics = {
	List = list,
	ById = byId,
	Slots = slots,
	SlotOrder = slotOrder,
	Rarities = rarities,
	RarityRank = rarityRank,
	Labels = { NEW = true, HOT = true, LIMITED = true },
	RewardHow = rewardHow,
}

-- Every item a free reward unlocks (RewardService grants these into profile.owned).
function Cosmetics.forReward(reward: string): { Item }
	local items = {}
	for _, item in list do
		if item.reward == reward then
			table.insert(items, item)
		end
	end
	return items
end

-- A slot's items in shop order: rarity, then `sort` (default: price), then name.
function Cosmetics.inSlot(slot: string): { Item }
	local items = {}
	for _, item in list do
		if item.slot == slot then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		local ra, rb = rarityRank[a.rarity] or 0, rarityRank[b.rarity] or 0
		if ra ~= rb then
			return ra < rb
		end
		local sa, sb = a.sort or a.price, b.sort or b.price
		if sa ~= sb then
			return sa < sb
		end
		return a.name < b.name
	end)
	return items
end

-- How an item is unlocked: "shells" | "robux" | "pass" | "reward" | "chest".
function Cosmetics.source(item: Item): string
	if item.reward ~= nil then
		return "reward"
	elseif item.pass ~= nil then
		return "pass"
	elseif item.chestOnly == true then
		return "chest"
	elseif item.robuxProductId ~= nil then
		return "robux"
	end
	return "shells"
end

table.freeze(Cosmetics.Slots)
table.freeze(Cosmetics.SlotOrder)
table.freeze(Cosmetics.Rarities)
table.freeze(Cosmetics.RarityRank)
table.freeze(Cosmetics.Labels)
table.freeze(Cosmetics.RewardHow)
return table.freeze(Cosmetics)
