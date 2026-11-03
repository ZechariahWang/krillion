--!strict
-- Local water visuals: shows where the water will reach this round.
-- Cosmetic and per-client; the server never moves the NextLevel line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local LINE_TRANSPARENCY = 0.15
local GLIDE_RATE = 6 -- higher catches up faster; the line eases toward its target every frame

local nextLevel: Model? = nil
local lines: { BasePart } = {}
local currentY: number? = nil
local targetY = 0

local WaterFx = {}

local function collect(arena: Instance)
	local model = arena:FindFirstChild("NextLevel")
	if model ~= nil and model:IsA("Model") then
		nextLevel = model
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(lines, child)
			end
		end
	end
end

-- Eases the line toward targetY with frame-rate independent smoothing, so it glides instead of jumping.
local function step(dt: number)
	local model = nextLevel
	if model == nil or currentY == nil then
		return
	end
	local y = currentY :: number
	if math.abs(targetY - y) < 0.01 then
		return
	end
	y += (targetY - y) * (1 - math.exp(-GLIDE_RATE * dt))
	currentY = y
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position.X, y, pivot.Position.Z))
end

function WaterFx.init()
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena")
		collect(arena)
	end)
	RunService.RenderStepped:Connect(step)
end

function WaterFx.onState(payload)
	local model = nextLevel
	if model == nil then
		return
	end
	local showing = payload.phase == "Prompt" or payload.phase == "Reveal"
	if not showing then
		for _, line in lines do
			Tween.play(line, Theme.Tween.Exit, { Transparency = 1 })
		end
		currentY = nil
		return
	end
	local color = Theme.Color.Gold
	if payload.special == "TidalWave" then
		color = Theme.Color.Red
	end
	targetY = payload.waterY + payload.surge
	if currentY == nil then
		-- First showing: start at the water so the line rises into place.
		currentY = payload.waterY
		local pivot = model:GetPivot()
		model:PivotTo(CFrame.new(pivot.Position.X, payload.waterY, pivot.Position.Z))
	end
	for _, line in lines do
		line.Color = color
		Tween.play(line, Theme.Tween.Enter, { Transparency = LINE_TRANSPARENCY })
	end
end

return WaterFx
