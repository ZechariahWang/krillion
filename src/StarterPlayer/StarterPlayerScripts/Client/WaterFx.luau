--!strict
-- Local water visuals: scrolls the water textures and shows where the water will reach this round.
-- All of this is cosmetic and per-client; the server never moves the NextLevel line.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local LINE_TRANSPARENCY = 0.15

local textures: { Texture } = {}
local nextLevel: Model? = nil
local lines: { BasePart } = {}

local WaterFx = {}

local function collect(arena: Instance)
	for _, d in arena:GetDescendants() do
		if d:IsA("Texture") and d:GetAttribute("ScrollU") ~= nil then
			table.insert(textures, d)
		end
	end
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
	RunService.Heartbeat:Connect(function(dt)
		for _, texture in textures do
			local u = texture:GetAttribute("ScrollU") :: number
			local v = texture:GetAttribute("ScrollV") :: number
			texture.OffsetStudsU = (texture.OffsetStudsU + u * dt) % texture.StudsPerTileU
			texture.OffsetStudsV = (texture.OffsetStudsV + v * dt) % texture.StudsPerTileV
		end
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
