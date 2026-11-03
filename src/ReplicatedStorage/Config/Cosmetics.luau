--!strict
-- The cosmetic catalogue. Priced in Cash, or Robux-only when `robuxProductId` is set (0 = placeholder).
-- Skins recolour your pillar, titles float over your head, splashes play where you sink
-- (templates under ReplicatedStorage.Templates.Splashes, named by `splash`).

export type Item = {
	id: string,
	slot: string, -- "Skin" | "Title" | "Splash"
	name: string,
	price: number, -- Cash; ignored for Robux items
	robuxProductId: number?,
	robux: number?, -- shown price for Robux items
	pass: string?, -- owned automatically by holders of this game pass (key in Products.Passes)
	color: { number }?, -- RGB: the skin, the title text, or the splash's shop preview
	material: string?, -- Enum.Material name, for skins
	splash: string?,
}

local list: { Item } = {
	{ id = "skin_coral", slot = "Skin", name = "Coral", price = 300, color = { 255, 120, 110 }, material = "SmoothPlastic" },
	{ id = "skin_kelp", slot = "Skin", name = "Kelp", price = 300, color = { 70, 150, 90 }, material = "SmoothPlastic" },
	{ id = "skin_glass", slot = "Skin", name = "Sea Glass", price = 900, color = { 150, 225, 220 }, material = "Glass" },
	{ id = "skin_gold", slot = "Skin", name = "Gold", price = 0, robuxProductId = 0, robux = 99, color = { 255, 200, 70 }, material = "Foil" },

	{ id = "title_diver", slot = "Title", name = "Deep Diver", price = 250, color = { 120, 200, 255 } },
	{ id = "title_shark", slot = "Title", name = "Shark", price = 600, color = { 170, 185, 200 } },
	{ id = "title_krill", slot = "Title", name = "Krill Lord", price = 1500, color = { 255, 140, 90 } },
	{ id = "title_vip", slot = "Title", name = "VIP", price = 0, pass = "Vip", color = { 255, 210, 80 } },

	{ id = "splash_bubbles", slot = "Splash", name = "Bubble Burst", price = 400, splash = "Bubbles", color = { 170, 225, 255 } },
	{ id = "splash_ink", slot = "Splash", name = "Ink Cloud", price = 800, splash = "Ink", color = { 150, 110, 210 } },
	{ id = "splash_stars", slot = "Splash", name = "Starfall", price = 0, robuxProductId = 0, robux = 79, splash = "Stars", color = { 255, 215, 110 } },
}

local byId: { [string]: Item } = {}
for _, item in list do
	byId[item.id] = item
end

local Cosmetics = {
	List = list,
	ById = byId,
	Slots = { Skin = true, Title = true, Splash = true },
}

return table.freeze(Cosmetics)
