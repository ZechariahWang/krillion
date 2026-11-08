--!strict
-- Treasure chests: pay Shells, get one random cosmetic. Every chance is shown on the chest (Roblox rule for
-- paid random items), and ChestService hides chests from players whose PolicyService info says paid random
-- items are restricted where they live. A duplicate pays back DuplicateRefund of the chest price in Shells.
-- Pure, so Lune tests can check the odds add up and every chest-only item can come out of a chest.

export type Drop = { item: string, chance: number }

export type Chest = {
	id: string,
	name: string,
	price: number, -- Shells
	color: { number },
	drops: { Drop }, -- in display order; chances add up to 1
}

local list: { Chest } = {
	{
		id = "chest_reef",
		name = "Reef Chest",
		price = 500,
		color = { 60, 200, 190 },
		drops = {
			{ item = "pet_clownfish", chance = 0.2 },
			{ item = "pet_crab", chance = 0.18 },
			{ item = "aura_sparkle", chance = 0.15 },
			{ item = "tag_sky", chance = 0.12 },
			{ item = "toy_snowball", chance = 0.1 },
			{ item = "pet_puffer", chance = 0.1 },
			{ item = "pet_turtle", chance = 0.08 },
			{ item = "trail_neon", chance = 0.05 },
			{ item = "pet_octopus", chance = 0.015 },
			{ item = "skin_kraken", chance = 0.005 },
		},
	},
	{
		id = "chest_abyss",
		name = "Abyss Chest",
		price = 1500,
		color = { 130, 70, 240 },
		drops = {
			{ item = "pet_octopus", chance = 0.2 },
			{ item = "pet_seahorse", chance = 0.2 },
			{ item = "aura_flame", chance = 0.14 },
			{ item = "card_galaxy", chance = 0.1 },
			{ item = "tag_ice", chance = 0.1 },
			{ item = "pet_shark", chance = 0.1 },
			{ item = "aura_void", chance = 0.07 },
			{ item = "trail_galaxy", chance = 0.04 },
			{ item = "skin_kraken", chance = 0.02 },
			{ item = "pet_krill", chance = 0.01 },
			{ item = "skin_prism", chance = 0.005 },
			{ item = "title_kraken", chance = 0.005 },
			{ item = "aura_rainbow", chance = 0.005 },
			{ item = "card_kraken", chance = 0.005 },
		},
	},
}

local byId: { [string]: Chest } = {}
for _, chest in list do
	byId[chest.id] = chest
end

local Chests = {
	List = list,
	ById = byId,
	DuplicateRefund = 0.4,
}

-- The item a roll in [0, 1) lands on. Walks the drops in order, so the same roll always gives the same item.
function Chests.roll(chest: Chest, roll: number): string
	local total = 0
	for _, drop in chest.drops do
		total += drop.chance
		if roll < total then
			return drop.item
		end
	end
	return chest.drops[#chest.drops].item
end

-- Shells paid back when the rolled item is already owned.
function Chests.refund(chest: Chest): number
	return math.floor(chest.price * Chests.DuplicateRefund)
end

-- "20%", "1.5%", "0.5%": the odds line on the chest.
function Chests.percent(chance: number): string
	local value = chance * 100
	if math.abs(value - math.round(value)) < 1e-6 then
		return string.format("%d%%", math.round(value))
	end
	return (string.gsub(string.format("%.2f", value), "0+$", "")) .. "%"
end

return table.freeze(Chests)
