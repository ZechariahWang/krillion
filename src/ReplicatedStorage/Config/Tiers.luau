--!strict
-- Rarity tiers, lowest to highest. Colours live in Theme so this module stays Lune-safe.

export type Tier = {
	name: string,
	label: string,
	points: number,
}

local list: { Tier } = {
	{ name = "Plankton", label = "Plankton", points = 10 },
	{ name = "TooClever", label = "Too Clever", points = 15 },
	{ name = "Schooler", label = "Schooler", points = 30 },
	{ name = "Rare", label = "Rare", points = 60 },
	{ name = "DeepCut", label = "Deep Cut", points = 85 },
	{ name = "OneInAKrillion", label = "One in a Krillion", points = 100 },
}

local byName: { [string]: Tier } = {}
for _, tier in list do
	byName[tier.name] = tier
end

local Tiers = {
	List = list,
	ByName = byName,
	MaxPoints = 100,
}

function Tiers.points(name: string): number
	local tier = byName[name]
	if tier == nil then
		return 0
	end
	return tier.points
end

return table.freeze(Tiers)
