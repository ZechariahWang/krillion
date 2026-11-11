--!strict
-- Rarity tiers, lowest to highest. Colours live in Theme so this module stays Lune-safe.
-- depthMin/depthMax are the band (in metres) the dive card sinks into for that tier.

export type Tier = {
	name: string,
	label: string,
	points: number,
	depthMin: number,
	depthMax: number,
	blurb: string, -- the dive card footer when there is no real "1 in N" number yet
}

local list: { Tier } = {
	{ name = "Plankton", label = "Plankton", points = 10, depthMin = 10, depthMax = 90, blurb = "Lots of people said that one." },
	{ name = "TooClever", label = "Too Clever", points = 15, depthMin = 90, depthMax = 150, blurb = "Clever, but plenty of others thought so too." },
	{ name = "Schooler", label = "Schooler", points = 30, depthMin = 150, depthMax = 250, blurb = "A pretty common pick." },
	{ name = "Rare", label = "Rare", points = 60, depthMin = 250, depthMax = 350, blurb = "Not many people said that!" },
	{ name = "DeepCut", label = "Deep Cut", points = 85, depthMin = 350, depthMax = 450, blurb = "Hardly anyone thinks of that!" },
	{ name = "Mythic", label = "Mythic", points = 100, depthMin = 450, depthMax = 560, blurb = "Almost nobody says that. Legendary!" },
}

local byName: { [string]: Tier } = {}
local indexOf: { [string]: number } = {}
for index, tier in list do
	byName[tier.name] = tier
	indexOf[tier.name] = index
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

-- 1 for Plankton up to 6 for Mythic; 0 for no tier.
function Tiers.index(name: string?): number
	if name == nil then
		return 0
	end
	return indexOf[name] or 0
end

return table.freeze(Tiers)
