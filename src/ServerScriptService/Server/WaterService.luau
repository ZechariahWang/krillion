--!strict
-- Owns the tank water: terrain water filled up from the tank floor, the two-stage surge, and the
-- "who is under water" poll. Terrain water gives real waves, reflections and underwater depth.
-- The invisible Arena.Water box marks the tank's footprint and floor, and holds the bubble emitter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local MapService = require(script.Parent.MapService)

local VOXEL = 4 -- terrain resolution; refill one voxel below the old level so the top layer is rewritten
local CLEAR_HEIGHT = 120 -- how far above the floor the tank column is cleared on reset

local level = 0 -- the water surface the game uses for eliminations

local WaterService = {}

local function footprint(): (Vector3, number)
	local water = MapService.getWater()
	local floorY = water:GetAttribute("FloorY") :: number
	return Vector3.new(water.Size.X, 0, water.Size.Z), floorY
end

-- Fills the tank with water from `fromY` up to `toY`. FillBlock gives the top voxel a partial
-- fill, so the surface can sit between voxel boundaries.
local function fillBetween(fromY: number, toY: number)
	local size, floorY = footprint()
	local bottom = math.max(floorY, fromY - VOXEL)
	if toY <= bottom then
		return
	end
	local height = toY - bottom
	workspace.Terrain:FillBlock(CFrame.new(0, bottom + height / 2, 0), Vector3.new(size.X, height, size.Z), Enum.Material.Water)
end

-- Keeps the invisible marker box (and so its bubbles) the same size as the water.
local function fitMarker(y: number)
	local water = MapService.getWater()
	local floorY = water:GetAttribute("FloorY") :: number
	local height = math.max(0.2, y - floorY)
	water.Size = Vector3.new(water.Size.X, height, water.Size.Z)
	water.Position = Vector3.new(water.Position.X, floorY + height / 2, water.Position.Z)
end

function WaterService.reset()
	local size, floorY = footprint()
	workspace.Terrain:FillBlock(CFrame.new(0, floorY + CLEAR_HEIGHT / 2, 0), Vector3.new(size.X, CLEAR_HEIGHT, size.Z), Enum.Material.Air)
	level = 0
	fillBetween(floorY, 0)
	fitMarker(0)
end

function WaterService.getSurfaceY(): number
	return level
end

-- Raises the water from the current level to `targetY` over `seconds`, eased, one fill per frame.
local function riseTo(targetY: number, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection)
	local startY = level
	local elapsed = 0
	while elapsed < seconds do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(1, elapsed / seconds)
		local eased = TweenService:GetValue(alpha, style, direction)
		local y = startY + (targetY - startY) * eased
		fillBetween(level, y)
		level = y
	end
	fillBetween(level, targetY)
	level = targetY
end

-- Creeps most of the way, then jumps the rest. Blocks until the water has settled.
function WaterService.surgeTo(targetY: number)
	local creepY = level + (targetY - level) * GameConfig.Water.CreepFraction
	riseTo(creepY, GameConfig.Water.CreepSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	riseTo(targetY, GameConfig.Water.JumpSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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
