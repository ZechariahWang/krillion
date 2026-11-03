--!strict
-- Where each pillar stands in the round reef: one ring, just wide enough for the match's player count.
local GameConfig = require("../Config/GameConfig")

local ArenaLayout = {}

function ArenaLayout.radius(count: number): number
	if count <= 1 then
		return 0
	end
	-- Neighbours on a ring of n points sit 2 * r * sin(pi / n) apart.
	local radius = GameConfig.Platform.Spacing / (2 * math.sin(math.pi / count))
	return math.min(radius, GameConfig.Platform.RingMaxRadius)
end

-- Returns the x and z of pillar `index` out of `count`, centred on the origin.
function ArenaLayout.position(index: number, count: number): (number, number)
	local radius = ArenaLayout.radius(count)
	if radius == 0 then
		return 0, 0
	end
	local angle = (index - 1) / count * 2 * math.pi
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	return x, z
end

return ArenaLayout
