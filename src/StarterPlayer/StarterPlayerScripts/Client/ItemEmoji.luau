--!strict
-- The emoji that stands for a cosmetic in the shop's card previews and the chest reveal: the item's own, else
-- its slot's. Skins, trails, titles and splashes show as colour discs in the shop, so theirs are only used
-- where there is no disc (the chest reveal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)

local SLOT: { [string]: string } = {
	Aura = "✨",
	CardTheme = "🃏",
	NameTag = "🏷️",
	Toy = "🍅",
	Pet = "🐟",
}

local DISC_SLOT: { [string]: string } = {
	Skin = "🎨",
	Trail = "💫",
	Title = "📜",
	Splash = "💦",
}

local ITEM: { [string]: string } = {
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

local ItemEmoji = {}

-- The shop preview emoji, or nil for slots the shop draws as a colour disc.
function ItemEmoji.of(item: Cosmetics.Item): string?
	return ITEM[item.id] or SLOT[item.slot]
end

-- Always an emoji, for places with no colour disc.
function ItemEmoji.any(item: Cosmetics.Item): string
	return ItemEmoji.of(item) or DISC_SLOT[item.slot] or "🎁"
end

return ItemEmoji
