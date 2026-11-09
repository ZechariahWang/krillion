--!strict
-- Runs the day and night cycle on this client: Lighting.ClockTime follows DayCycle from the shared server clock,
-- so every player sees the same sky. Lighting as authored in Studio is the day look (bright ambient, the old
-- linear fog); the night look is Lighting's NightAmbient / NightOutdoorAmbient attributes plus the authored
-- Lighting.Atmosphere haze. Parts and models tagged "NightLight" (the lobby torches) burn only at night.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayCycle = require(ReplicatedStorage.Shared.DayCycle)

local UPDATE_SECONDS = 0.1
local TORCHES_ON_AT = 0.5 -- night factor above which the torches burn
local NO_FOG_DISTANCE = 20000 -- fog pushed this far out is invisible
local NIGHT_TAG = "NightLight"
local UNLIT_COLOR = Color3.fromRGB(40, 36, 34)

-- A tagged part also dims its own colour; a tagged model only switches the lights inside it.
type Torch = { root: Instance, part: BasePart?, color: Color3, material: Enum.Material }

local dayAmbient = Lighting.Ambient
local dayOutdoor = Lighting.OutdoorAmbient
local nightAmbient = dayAmbient
local nightOutdoor = dayOutdoor
local dayFogStart = Lighting.FogStart
local dayFogEnd = Lighting.FogEnd
local atmosphere: Atmosphere? = nil
local nightDensity = 0
local nightHaze = 0
local torches: { [Instance]: Torch } = {}
local torchesLit: boolean? = nil

local DayNight = {}

local function colorAttribute(name: string, fallback: Color3): Color3
	local value = Lighting:GetAttribute(name)
	if typeof(value) == "Color3" then
		return value
	end
	return fallback
end

local function addTorch(instance: Instance)
	if torches[instance] ~= nil then
		return
	end
	if instance:IsA("BasePart") then
		torches[instance] = { root = instance, part = instance, color = instance.Color, material = instance.Material }
		torchesLit = nil
	elseif instance:IsA("Model") then
		torches[instance] = { root = instance, part = nil, color = UNLIT_COLOR, material = Enum.Material.Slate }
		torchesLit = nil
	end
end

local function setTorch(torch: Torch, lit: boolean)
	for _, child in torch.root:GetDescendants() do
		if child:IsA("Light") or child:IsA("Fire") or child:IsA("ParticleEmitter") then
			child.Enabled = lit
		end
	end
	local part = torch.part
	if part ~= nil then
		part.Color = if lit then torch.color else UNLIT_COLOR
		part.Material = if lit then torch.material else Enum.Material.Slate
	end
end

local function setTorches(lit: boolean)
	if lit == torchesLit then
		return
	end
	torchesLit = lit
	for root, torch in torches do
		if root:IsDescendantOf(workspace) then
			setTorch(torch, lit)
		else
			torches[root] = nil
		end
	end
end

-- Fog and Atmosphere cannot show together (any Atmosphere switches the fog off), so the first half of a
-- dusk fades the day fog out and the second half fades the night haze in; dawn runs it backwards.
local function applyLighting(night: number)
	Lighting.Ambient = dayAmbient:Lerp(nightAmbient, night)
	Lighting.OutdoorAmbient = dayOutdoor:Lerp(nightOutdoor, night)
	local fogWeight = math.clamp(1 - night * 2, 0, 1)
	Lighting.FogStart = dayFogStart + (NO_FOG_DISTANCE - dayFogStart) * (1 - fogWeight)
	Lighting.FogEnd = dayFogEnd + (NO_FOG_DISTANCE - dayFogEnd) * (1 - fogWeight)
	local haze = atmosphere
	if haze ~= nil then
		local hazeWeight = math.clamp(night * 2 - 1, 0, 1)
		if hazeWeight > 0 then
			haze.Density = nightDensity * hazeWeight
			haze.Haze = nightHaze * hazeWeight
			haze.Parent = Lighting
		else
			haze.Parent = nil
		end
	end
	setTorches(night > TORCHES_ON_AT)
end

function DayNight.init()
	nightAmbient = colorAttribute("NightAmbient", dayAmbient)
	nightOutdoor = colorAttribute("NightOutdoorAmbient", dayOutdoor)
	local found = Lighting:FindFirstChildOfClass("Atmosphere")
	if found ~= nil then
		atmosphere = found
		nightDensity = found.Density
		nightHaze = found.Haze
	end
	for _, instance in CollectionService:GetTagged(NIGHT_TAG) do
		addTorch(instance)
	end
	CollectionService:GetInstanceAddedSignal(NIGHT_TAG):Connect(addTorch)

	local sinceUpdate = UPDATE_SECONDS
	RunService.Heartbeat:Connect(function(dt)
		sinceUpdate += dt
		if sinceUpdate < UPDATE_SECONDS then
			return
		end
		sinceUpdate = 0
		local clock = DayCycle.clockAt(workspace:GetServerTimeNow())
		Lighting.ClockTime = clock
		applyLighting(DayCycle.nightFactor(clock))
	end)
end

return DayNight
