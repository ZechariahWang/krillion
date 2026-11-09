--!strict
-- Local water visuals: the NextLevel line showing where the water will reach, and the surge itself,
-- animated on this client every frame. The server sets the final level once at the end of the surge,
-- which matches what this already shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
local WaterSurface = require(ReplicatedStorage.Shared.WaterSurface)

local LINE_TRANSPARENCY = 0.15
local GLIDE_RATE = 6 -- higher catches up faster; the line eases toward its target every frame

local nextLevel: Model? = nil
local currentY: number? = nil
local targetY = 0
local waterMarker: BasePart? = nil
local waterSurface: BasePart? = nil
local lastPhase = ""
local surgeToken = 0
local serverSendsSurging = false -- set once any RoundState carries `surging`; until then the phase change decides

local WaterFx = {}

local function collect(arena: Instance)
	waterMarker = arena:WaitForChild("Water") :: BasePart
	waterSurface = arena:WaitForChild("WaterSurface") :: BasePart
	local model = arena:WaitForChild("NextLevel")
	if model:IsA("Model") then
		nextLevel = model
	end
end

-- The ring's segments as they are on this client right now. Not cached: a segment that streams in late or
-- streams back in arrives as a new part, and a cached list would leave it hidden (the ring showed an arc).
local function linesOf(model: Model): { BasePart }
	local lines = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(lines, child)
		end
	end
	return lines
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

-- Raises the water part along the shared surge curve, one step per frame.
local function animateSurge(fromY: number, toY: number)
	local marker = waterMarker
	local water = waterSurface
	if marker == nil or water == nil then
		return
	end
	local floorY = marker:GetAttribute("FloorY") :: number
	surgeToken += 1
	local token = surgeToken
	task.spawn(function()
		local elapsed = 0
		local total = WaterCurve.surgeSeconds()
		while elapsed < total and token == surgeToken do
			elapsed += RunService.RenderStepped:Wait()
			WaterSurface.place(water, floorY, WaterCurve.surgeY(fromY, toY, elapsed))
		end
		if token == surgeToken then
			WaterSurface.place(water, floorY, toY)
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

-- Whether this broadcast is the one sent before the water rises. A client whose first state is mid-surge
-- (a late join) has no rise to show.
local function isRiseBroadcast(payload): boolean
	if payload.surging ~= nil then
		serverSendsSurging = true
	end
	if serverSendsSurging then
		return payload.surging == true
	end
	return payload.phase == "Surge" and lastPhase ~= "Surge" and lastPhase ~= ""
end

function WaterFx.onState(payload)
	local enteringSurge = isRiseBroadcast(payload)
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
		for _, line in linesOf(model) do
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
	for _, line in linesOf(model) do
		line.Color = color
		Tween.play(line, Theme.Tween.Enter, { Transparency = LINE_TRANSPARENCY })
	end
end

return WaterFx
