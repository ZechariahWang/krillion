--!strict
-- Draws the tank water at a level: terrain water in whole voxels up to WaterCurve.terrainTop, plus the
-- Arena.WaterSurface slab whose top sits exactly at the level, so the surface can move smoothly.
-- Used by the server (authoritative, replicated) and by clients (local animation during a surge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)

local LYING = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder part's axis is X; this stands it upright

local WaterSurface = {}

-- Fills terrain water from just below `fromLevel` up to the last whole voxel under `toLevel`.
function WaterSurface.fillTerrain(marker: BasePart, fromLevel: number, toLevel: number)
	local radius = marker:GetAttribute("Radius") :: number
	local floorY = marker:GetAttribute("FloorY") :: number
	local top = WaterCurve.terrainTop(toLevel)
	local bottom = math.max(floorY, WaterCurve.terrainTop(fromLevel) - GameConfig.Water.Voxel)
	if top <= bottom then
		return
	end
	-- Stop a hair short of the voxel boundary so the voxel above is not touched.
	local height = top - bottom - 0.01
	workspace.Terrain:FillCylinder(CFrame.new(0, bottom + height / 2, 0), height, radius, Enum.Material.Water)
end

function WaterSurface.place(surface: BasePart, level: number)
	local depth = surface.Size.X
	surface.CFrame = CFrame.new(0, level - depth / 2, 0) * LYING
end

return WaterSurface
