--!strict
-- Local water visuals: shows where the water will reach this round.
-- Cosmetic and per-client; the server never moves the NextLevel line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local LINE_TRANSPARENCY = 0.15

local nextLevel: Model? = nil
local lines: { BasePart } = {}

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

function WaterFx.init()
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena")
		collect(arena)
	end)
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
		return
	end
	local color = Theme.Color.Gold
	if payload.special == "TidalWave" then
		color = Theme.Color.Red
	end
	local target = payload.waterY + payload.surge
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position.X, target, pivot.Position.Z))
	for _, line in lines do
		line.Color = color
		Tween.play(line, Theme.Tween.Enter, { Transparency = LINE_TRANSPARENCY })
	end
end

return WaterFx
