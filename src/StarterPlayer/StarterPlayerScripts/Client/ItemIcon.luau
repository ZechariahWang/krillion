--!strict
-- The icon (a name in ReplicatedStorage.Templates.Icons) that stands for a cosmetic in the shop's card
-- previews and the chest reveal: the item's own, else its slot's. Skins, trails, titles and splashes show as
-- colour discs in the shop, so theirs are only used where there is no disc (the chest reveal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)

local SLOT: { [string]: string } = {
	Aura = "Sparkle",
	CardTheme = "Cards",
	NameTag = "Tag",
	Toy = "Tomato",
	Pet = "Fish",
}

local DISC_SLOT: { [string]: string } = {
	Skin = "Palette",
	Trail = "Sparkle",
	Title = "Quest",
	Splash = "Sparkle",
}

local ITEM: { [string]: string } = {
	pet_clownfish = "Fish",
	pet_crab = "Crab",
	pet_turtle = "Turtle",
	pet_jelly = "Jelly",
	pet_puffer = "Puffer",
	pet_octopus = "Octopus",
	pet_seahorse = "Seahorse",
	pet_axolotl = "Axolotl",
	pet_narwhal = "Narwhal",
	pet_shark = "Shark",
	pet_whale = "Whale",
	pet_krill = "Shrimp",
	toy_tomato = "Tomato",
	toy_snowball = "Snowflake",
	toy_pie = "Pie",
	toy_balloon = "Balloon",
	toy_fish = "Fish",
	toy_confetti = "Confetti",
	aura_frost = "Snowflake",
	aura_flame = "Flame",
	aura_electric = "Bolt",
	aura_halo = "Halo",
	aura_bubbles = "Bubbles",
	aura_void = "Void",
	aura_rainbow = "Rainbow",
}

local ItemIcon = {}

-- The shop preview icon, or nil for slots the shop draws as a colour disc.
function ItemIcon.of(item: Cosmetics.Item): string?
	return ITEM[item.id] or SLOT[item.slot]
end

-- Always an icon, for places with no colour disc.
function ItemIcon.any(item: Cosmetics.Item): string
	return ItemIcon.of(item) or DISC_SLOT[item.slot] or "Gift"
end

return ItemIcon
