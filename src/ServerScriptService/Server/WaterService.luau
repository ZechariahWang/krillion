--!strict
-- Owns the water surface: the two-stage surge animation and the "who is under water" poll.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local MapService = require(script.Parent.MapService)

local WATER_DEPTH = 40

local surfaceY = 0

local WaterService = {}

local function placeSurface(y: number)
	local water = MapService.getWater()
	local foam = MapService.getFoam()
	water.Position = Vector3.new(0, y - WATER_DEPTH / 2, 0)
	foam.Position = Vector3.new(0, y + 0.1, 0)
end

function WaterService.reset()
	surfaceY = 0
	placeSurface(0)
end

function WaterService.getSurfaceY(): number
	local water = MapService.getWater()
	return water.Position.Y + WATER_DEPTH / 2
end

-- Creeps most of the way, then jumps the rest. Blocks until the water has settled.
function WaterService.surgeTo(targetY: number)
	local water = MapService.getWater()
	local foam = MapService.getFoam()
	local creepY = surfaceY + (targetY - surfaceY) * GameConfig.Water.CreepFraction

	local creepInfo = TweenInfo.new(GameConfig.Water.CreepSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local jumpInfo = TweenInfo.new(GameConfig.Water.JumpSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local creepWater = TweenService:Create(water, creepInfo, { Position = Vector3.new(0, creepY - WATER_DEPTH / 2, 0) })
	local creepFoam = TweenService:Create(foam, creepInfo, { Position = Vector3.new(0, creepY + 0.1, 0) })
	creepWater:Play()
	creepFoam:Play()
	creepWater.Completed:Wait()

	local jumpWater = TweenService:Create(water, jumpInfo, { Position = Vector3.new(0, targetY - WATER_DEPTH / 2, 0) })
	local jumpFoam = TweenService:Create(foam, jumpInfo, { Position = Vector3.new(0, targetY + 0.1, 0) })
	jumpWater:Play()
	jumpFoam:Play()
	jumpWater.Completed:Wait()

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
