--!strict
-- Draws the tank water at a level: the Arena.WaterSurface cylinder, stretched from the tank floor up to
-- the level. A part instead of terrain water, because terrain water only moves in whole 4-stud cells.
-- Used by the server (authoritative, replicated) and by clients (local animation during a surge).

local LYING = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder part's axis is X; this stands it upright
local MIN_DEPTH = 0.2

local WaterSurface = {}

function WaterSurface.place(water: BasePart, floorY: number, level: number)
	local depth = math.max(MIN_DEPTH, level - floorY)
	water.Size = Vector3.new(depth, water.Size.Y, water.Size.Z)
	water.CFrame = CFrame.new(0, floorY + depth / 2, 0) * LYING
end

return WaterSurface
