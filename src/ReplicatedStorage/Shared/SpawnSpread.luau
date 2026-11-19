--!strict
-- Where a player lands in the lobby, so a crowd that respawns together does not stand in one spot: a spot on a
-- ring round the lobby spawn, clear of everyone already standing there. Pure (no Roblox APIs): positions are
-- { x, z } pairs and every random choice is a roll passed in, so Lune tests can pin the outcome.

local SpawnSpread = {}

SpawnSpread.MIN_RADIUS = 1.5 -- studs from the spawn's centre a spot may be: close by, on the deck round it
SpawnSpread.MAX_RADIUS = 5
SpawnSpread.CLEAR = 2.5 -- studs a spot keeps from every player already near it: not on top of anyone
SpawnSpread.TRIES = 24

export type Spot = { number } -- { x, z }

local function nearest(x: number, z: number, taken: { Spot }): number
	local best = math.huge
	for _, other in taken do
		local dx, dz = other[1] - x, other[2] - z
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- Candidate spots round (cx, cz), best first: every one clear of `taken` (CLEAR studs) in the order rolled,
-- then the rest by how far they keep from the nearest player. `roll` gives numbers in [0, 1).
function SpawnSpread.candidates(cx: number, cz: number, taken: { Spot }, roll: () -> number): { Spot }
	local clear: { Spot } = {}
	local crowded: { { spot: Spot, room: number } } = {}
	for _ = 1, SpawnSpread.TRIES do
		local angle = roll() * 2 * math.pi
		local radius = SpawnSpread.MIN_RADIUS + (SpawnSpread.MAX_RADIUS - SpawnSpread.MIN_RADIUS) * roll()
		local x, z = cx + math.cos(angle) * radius, cz + math.sin(angle) * radius
		local room = nearest(x, z, taken)
		if room >= SpawnSpread.CLEAR then
			table.insert(clear, { x, z })
		else
			table.insert(crowded, { spot = { x, z }, room = room })
		end
	end
	table.sort(crowded, function(a, b)
		return a.room > b.room
	end)
	for _, entry in crowded do
		table.insert(clear, entry.spot)
	end
	return clear
end

return SpawnSpread
