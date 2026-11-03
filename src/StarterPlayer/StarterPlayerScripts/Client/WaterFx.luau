--!strict
-- Local water visuals: the NextLevel line showing where the water will reach, and the surge itself,
-- animated on this client every frame (surface slab plus local terrain). The server draws the final
-- level once at the end of the surge, which matches what this already shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
local WaterSurface = require(ReplicatedStorage.Shared.WaterSurface)

local LINE_TRANSPARENCY = 0.15
local GLIDE_RATE = 6 -- higher catches up faster; the line eases toward its target every frame

local nextLevel: Model? = nil
local lines: { BasePart } = {}
local currentY: number? = nil
local targetY = 0
local waterMarker: BasePart? = nil
local waterSurface: BasePart? = nil
local lastPhase = ""
local surgeToken = 0

local WaterFx = {}

local function collect(arena: Instance)
	waterMarker = arena:WaitForChild("Water") :: BasePart
	waterSurface = arena:WaitForChild("WaterSurface") :: BasePart
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

-- Slides the surface slab along the shared surge curve every frame; local terrain fills a voxel at a
-- time underneath, staying below the slab.
local function animateSurge(fromY: number, toY: number)
	local marker = waterMarker
	local surface = waterSurface
	if marker == nil or surface == nil then
		return
	end
	surgeToken += 1
	local token = surgeToken
	task.spawn(function()
		local filledTo = fromY
		local elapsed = 0
		local total = WaterCurve.surgeSeconds()
		while elapsed < total and token == surgeToken do
			elapsed += RunService.RenderStepped:Wait()
			local y = WaterCurve.surgeY(fromY, toY, elapsed)
			WaterSurface.place(surface, y)
			if WaterCurve.terrainTop(y) > WaterCurve.terrainTop(filledTo) then
				WaterSurface.fillTerrain(marker, filledTo, y)
				filledTo = y
			end
		end
		if token == surgeToken then
			WaterSurface.place(surface, toY)
			WaterSurface.fillTerrain(marker, filledTo, toY)
		end
	end)
end

function WaterFx.init()
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena")
		collect(arena)
	end)
	RunService.RenderStepped:Connect(step)
end

function WaterFx.onState(payload)
	local enteringSurge = payload.phase == "Surge" and lastPhase ~= "Surge"
	lastPhase = payload.phase
	-- The Surge broadcast carries the level before the rise and how far it will go.
	if enteringSurge and payload.surge > 0 then
		animateSurge(payload.waterY, payload.waterY + payload.surge)
	end
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
