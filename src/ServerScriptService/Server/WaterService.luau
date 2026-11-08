--!strict
-- Owns the tank water: the level, the two-stage surge, and the "who is under water" poll.
-- The water is the Arena.WaterSurface part (see Shared/WaterSurface); the sea outside stays terrain.
-- The invisible Arena.Water box holds the bubble emitter; its FloorY attribute gives the tank's floor.
-- The tank hole is carved into the authored terrain, so nothing here edits terrain.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
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

-- Follows WaterCurve.surgeY frame by frame for eliminations, but draws the water once at the end:
-- server edits reach clients in batches and would look like jumps, so each client animates the rise
-- locally (WaterFx) and this final write lands on what they already show. Blocks until done.
function WaterService.surgeTo(targetY: number)
	local startY = level
	local elapsed = 0
	local total = WaterCurve.surgeSeconds()
	while elapsed < total do
		elapsed += RunService.Heartbeat:Wait()
		level = WaterCurve.surgeY(startY, targetY, elapsed)
	end
	local floorY = MapService.getWater():GetAttribute("FloorY") :: number
	WaterSurface.place(MapService.getWaterSurface(), floorY, targetY)
	level = targetY
	fitMarker(targetY)
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
