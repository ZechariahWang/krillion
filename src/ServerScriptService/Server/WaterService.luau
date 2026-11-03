--!strict
-- Owns the water surface: the two-stage surge animation and the "who is under water" poll.
-- The water part's bottom stays on the tank floor; only its height grows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local MapService = require(script.Parent.MapService)

local surfaceY = 0

local WaterService = {}

local function waterGoal(water: Part, y: number): { [string]: any }
	local floorY = water:GetAttribute("FloorY") :: number
	local height = y - floorY
	return {
		Size = Vector3.new(water.Size.X, height, water.Size.Z),
		Position = Vector3.new(water.Position.X, floorY + height / 2, water.Position.Z),
	}
end

local function foamGoal(foam: Part, y: number): { [string]: any }
	return { Position = Vector3.new(foam.Position.X, y + 0.15, foam.Position.Z) }
end

local function placeSurface(y: number)
	local water = MapService.getWater()
	local foam = MapService.getFoam()
	local goal = waterGoal(water, y)
	water.Size = goal.Size
	water.Position = goal.Position
	foam.Position = foamGoal(foam, y).Position
end

function WaterService.reset()
	surfaceY = 0
	placeSurface(0)
end

function WaterService.getSurfaceY(): number
	local water = MapService.getWater()
	return water.Position.Y + water.Size.Y / 2
end

local function tweenSurface(y: number, info: TweenInfo)
	local water = MapService.getWater()
	local foam = MapService.getFoam()
	local waterTween = TweenService:Create(water, info, waterGoal(water, y))
	local foamTween = TweenService:Create(foam, info, foamGoal(foam, y))
	waterTween:Play()
	foamTween:Play()
	waterTween.Completed:Wait()
end

-- Creeps most of the way, then jumps the rest. Blocks until the water has settled.
function WaterService.surgeTo(targetY: number)
	local creepY = surfaceY + (targetY - surfaceY) * GameConfig.Water.CreepFraction
	local creepInfo = TweenInfo.new(GameConfig.Water.CreepSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local jumpInfo = TweenInfo.new(GameConfig.Water.JumpSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tweenSurface(creepY, creepInfo)
	tweenSurface(targetY, jumpInfo)
	surfaceY = targetY
	placeSurface(targetY)
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
