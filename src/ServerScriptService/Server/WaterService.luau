--!strict
-- Owns the tank water: it rests at one level, and a poll finds players who fell in.
-- The water is the Arena.WaterSurface part (see Shared/WaterSurface); the sea outside stays terrain.
-- The invisible Arena.Water box holds the bubble emitter; its FloorY attribute gives the tank's floor.
-- The tank hole is carved into the authored terrain, so nothing here edits terrain.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WaterSurface = require(ReplicatedStorage.Shared.WaterSurface)
local MapService = require(script.Parent.MapService)

local level = 0 -- the water surface the game uses for eliminations

local WaterService = {}

-- Keeps the invisible marker box (and so its bubbles) the same size as the water.
local function fitMarker(y: number)
	local water = MapService.getWater()
	local floorY = water:GetAttribute("FloorY") :: number
	local height = math.max(0.2, y - floorY)
	water.Size = Vector3.new(water.Size.X, height, water.Size.Z)
	water.Position = Vector3.new(water.Position.X, floorY + height / 2, water.Position.Z)
end

function WaterService.reset()
	local floorY = MapService.getWater():GetAttribute("FloorY") :: number
	level = 0
	WaterSurface.place(MapService.getWaterSurface(), floorY, 0)
	fitMarker(0)
end

function WaterService.getSurfaceY(): number
	return level
end

-- Calls `onSunk` for any player in `players()` whose character is missing or under the surface.
function WaterService.startCullLoop(players: () -> { Player }, onSunk: (Player) -> ())
	task.spawn(function()
		while true do
			task.wait(1 / GameConfig.Water.CullHz)
			local surface = WaterService.getSurfaceY()
			for _, player in players() do
				local character = player.Character
				local root = nil
				if character ~= nil then
					root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				end
				if root == nil or root.Position.Y < surface then
					onSunk(player)
				end
			end
		end
	end)
end

return WaterService
