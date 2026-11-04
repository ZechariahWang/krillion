--!strict
-- The cosmetic catalogue. Priced in Shells (the `cash` field), or Robux-only when `robuxProductId` is set
-- (0 = placeholder). Skins recolour your pillar, titles float over your head, splashes play where you sink
-- (templates under ReplicatedStorage.Templates.Splashes, named by `splash`), trails follow you around
-- (templates under ReplicatedStorage.Templates.Trails, named by `trail`).
-- `pass` items come with a game pass; `reward` items are never sold and only RewardService grants them.

export type Item = {
	id: string,
	slot: string, -- "Skin" | "Title" | "Splash" | "Trail"
	name: string,
	price: number, -- Shells; ignored for Robux, pass and reward items
	robuxProductId: number?,
	robux: number?, -- shown price for Robux items
	pass: string?, -- owned automatically by holders of this game pass (key in Products.Passes)
	reward: string?, -- unlocked by this free reward (key in RewardHow): Group, Referral1, Referral3
	color: { number }?, -- RGB: the skin, the title text, the splash's or trail's shop preview
	top: { number }?, -- RGB for the pillar cap; skins without one get a lightened `color`
	material: string?, -- Enum.Material name, for skins
	splash: string?,
	trail: string?,
}

local list: { Item } = {
	{ id = "skin_coral", slot = "Skin", name = "Coral", price = 300, color = { 255, 120, 110 }, material = "SmoothPlastic" },
	{ id = "skin_kelp", slot = "Skin", name = "Kelp", price = 300, color = { 70, 150, 90 }, material = "SmoothPlastic" },
	{ id = "skin_lagoon", slot = "Skin", name = "Lagoon", price = 450, color = { 38, 198, 196 }, top = { 190, 250, 245 }, material = "SmoothPlastic" },
	{ id = "skin_glass", slot = "Skin", name = "Sea Glass", price = 900, color = { 150, 225, 220 }, material = "Glass" },
	{ id = "skin_pearl", slot = "Skin", name = "Pearl", price = 1050, color = { 240, 240, 248 }, top = { 255, 255, 255 }, material = "Marble" },
	{ id = "skin_abyss", slot = "Skin", name = "Abyss", price = 1500, color = { 14, 28, 60 }, top = { 80, 170, 255 }, material = "Slate" },
	{ id = "skin_glacier", slot = "Skin", name = "Glacier", price = 1800, color = { 170, 220, 255 }, top = { 235, 248, 255 }, material = "Ice" },
	{ id = "skin_volcano", slot = "Skin", name = "Volcano", price = 2400, color = { 45, 40, 44 }, top = { 255, 110, 40 }, material = "Basalt" },
	{ id = "skin_gold", slot = "Skin", name = "Gold", price = 0, robuxProductId = 0, robux = 99, color = { 255, 200, 70 }, material = "Foil" },
	{ id = "skin_aurora", slot = "Skin", name = "Aurora", price = 0, pass = "Vip", color = { 120, 90, 255 }, top = { 120, 255, 220 }, material = "Glass" },
	{ id = "skin_buddy", slot = "Skin", name = "Buddy System", price = 0, reward = "Referral1", color = { 255, 150, 40 }, top = { 255, 220, 150 }, material = "Plastic" },

	{ id = "title_diver", slot = "Title", name = "Deep Diver", price = 250, color = { 120, 200, 255 } },
	{ id = "title_shark", slot = "Title", name = "Shark", price = 600, color = { 170, 185, 200 } },
	{ id = "title_krill", slot = "Title", name = "Krill Lord", price = 1500, color = { 255, 140, 90 } },
	{ id = "title_vip", slot = "Title", name = "VIP", price = 0, pass = "Vip", color = { 255, 210, 80 } },
	{ id = "title_crew", slot = "Title", name = "Reef Crew", price = 0, reward = "Group", color = { 38, 198, 196 } },

	{ id = "splash_bubbles", slot = "Splash", name = "Bubble Burst", price = 400, splash = "Bubbles", color = { 170, 225, 255 } },
	{ id = "splash_ink", slot = "Splash", name = "Ink Cloud", price = 800, splash = "Ink", color = { 150, 110, 210 } },
	{ id = "splash_stars", slot = "Splash", name = "Starfall", price = 0, robuxProductId = 0, robux = 79, splash = "Stars", color = { 255, 215, 110 } },

	-- Trail colours are the Sink or Niche ones; the template's Trail.Color is what shows in game.
	{ id = "trail_bubbles", slot = "Trail", name = "Bubbles", price = 300, trail = "Bubbles", color = { 160, 220, 255 } },
	{ id = "trail_seafoam", slot = "Trail", name = "Seafoam", price = 600, trail = "Seafoam", color = { 38, 198, 196 } },
	{ id = "trail_sunset", slot = "Trail", name = "Sunset Reef", price = 900, trail = "Sunset", color = { 255, 120, 120 } },
	{ id = "trail_abyssal", slot = "Trail", name = "Abyssal", price = 1350, trail = "Abyssal", color = { 181, 80, 235 } },
	{ id = "trail_rainbow", slot = "Trail", name = "Rainbow Fish", price = 2700, trail = "Rainbow", color = { 255, 120, 200 } },
	{ id = "trail_goldwake", slot = "Trail", name = "Gold Wake", price = 0, pass = "Vip", trail = "GoldWake", color = { 255, 200, 61 } },
	{ id = "trail_pod", slot = "Trail", name = "Pod Wake", price = 0, reward = "Referral3", trail = "Pod", color = { 255, 150, 40 } },
}

local byId: { [string]: Item } = {}
for _, item in list do
	byId[item.id] = item
end

-- What unlocks each reward item, as the shop card says it.
local rewardHow: { [string]: string } = { Group = "JOIN GROUP", Referral1 = "INVITE 1 FRIEND", Referral3 = "INVITE 3 FRIENDS" }

local Cosmetics = {
	List = list,
	ById = byId,
	Slots = { Skin = true, Title = true, Splash = true, Trail = true },
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

table.freeze(Cosmetics.Slots)
table.freeze(Cosmetics.RewardHow)
return table.freeze(Cosmetics)
