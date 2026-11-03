--!strict
-- One-shot generator. Run once in Studio (via MCP execute_luau or the command bar) to build
-- ServerStorage.Maps.Arena and ServerStorage.Maps.Lobby, then save the place. Not run at runtime.
-- Rebuilding replaces the existing models.

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)

local ARENA_SIZE = 140
local WALL_HEIGHT = 110
local WALL_THICKNESS = 6
local FLOOR_Y = -20
local LOBBY_Y = GameConfig.Lobby.HeightAboveArena
local LOBBY_OUTER = 40
local LOBBY_INNER = 24

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function buildArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "Arena"

	local floor = part("Floor", Vector3.new(ARENA_SIZE, 4, ARENA_SIZE), CFrame.new(0, FLOOR_Y, 0), Theme.Color.Navy, Enum.Material.Slate)
	floor.Parent = arena

	local half = ARENA_SIZE / 2 + WALL_THICKNESS / 2
	local wallY = FLOOR_Y + WALL_HEIGHT / 2
	local walls = {
		{ Vector3.new(ARENA_SIZE + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS), CFrame.new(0, wallY, half) },
		{ Vector3.new(ARENA_SIZE + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS), CFrame.new(0, wallY, -half) },
		{ Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE), CFrame.new(half, wallY, 0) },
		{ Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE), CFrame.new(-half, wallY, 0) },
	}
	for index, spec in walls do
		local wall = part("Wall" .. index, spec[1], spec[2], Theme.Color.Navy, Enum.Material.Slate)
		wall.Parent = arena
	end

	-- Accent strips along the top of each wall so the basin reads as designed, not raw.
	for index, spec in walls do
		local size = spec[1]
		local strip = part("Trim" .. index, Vector3.new(size.X, 0.5, size.Z), spec[2] + Vector3.new(0, WALL_HEIGHT / 2, 0), Theme.Color.Accent, Enum.Material.Neon)
		strip.Parent = arena
	end

	local water = part("Water", Vector3.new(ARENA_SIZE, 40, ARENA_SIZE), CFrame.new(0, -20, 0), Theme.Color.Water, Enum.Material.Glass)
	water.Transparency = 0.45
	water.CanCollide = false
	water.CanQuery = false
	water.CastShadow = false
	water.Parent = arena

	local foam = part("Foam", Vector3.new(ARENA_SIZE, 0.2, ARENA_SIZE), CFrame.new(0, 0.1, 0), Theme.Color.Accent, Enum.Material.Neon)
	foam.Transparency = 0.6
	foam.CanCollide = false
	foam.CanQuery = false
	foam.CastShadow = false
	foam.Parent = arena

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Theme.Color.Water
	glow.Brightness = 2
	glow.Range = 60
	glow.Parent = water

	local platformTemplate = Instance.new("Part")
	platformTemplate.Name = "PlatformTemplate"
	platformTemplate.Shape = Enum.PartType.Cylinder
	platformTemplate.Size = Vector3.new(1, GameConfig.Platform.Radius * 2, GameConfig.Platform.Radius * 2)
	platformTemplate.CFrame = CFrame.new(0, -100, 0) * CFrame.Angles(0, 0, math.rad(90))
	platformTemplate.Color = Theme.Color.Text
	platformTemplate.Material = Enum.Material.SmoothPlastic
	platformTemplate.Anchored = true
	platformTemplate.TopSurface = Enum.SurfaceType.Smooth
	platformTemplate.BottomSurface = Enum.SurfaceType.Smooth

	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.3, GameConfig.Platform.Radius * 2 + 0.6, GameConfig.Platform.Radius * 2 + 0.6)
	rim.CFrame = platformTemplate.CFrame * CFrame.new(-0.2, 0, 0)
	rim.Color = Theme.Color.Accent
	rim.Material = Enum.Material.Neon
	rim.Anchored = true
	rim.CanCollide = false
	rim.Parent = platformTemplate

	local rimWeld = Instance.new("WeldConstraint")
	rimWeld.Part0 = platformTemplate
	rimWeld.Part1 = rim
	rimWeld.Parent = rim

	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Right
	light.Color = Theme.Color.Accent
	light.Brightness = 1
	light.Range = 12
	light.Parent = platformTemplate

	platformTemplate.Parent = arena

	return arena
end

local function buildLobby(): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	local deckThickness = 2
	local outer = part("Deck", Vector3.new(LOBBY_OUTER * 2, deckThickness, LOBBY_OUTER * 2), CFrame.new(0, LOBBY_Y, 0), Theme.Color.Text, Enum.Material.SmoothPlastic)
	outer.Parent = lobby

	local glass = part("GlassFloor", Vector3.new(LOBBY_INNER * 2, deckThickness, LOBBY_INNER * 2), CFrame.new(0, LOBBY_Y + 0.05, 0), Theme.Color.Accent, Enum.Material.Glass)
	glass.Transparency = 0.7
	glass.Parent = lobby

	-- Four light pillars at the corners of the glass floor.
	local pillarOffsets = {
		Vector3.new(LOBBY_INNER + 4, 0, LOBBY_INNER + 4),
		Vector3.new(-LOBBY_INNER - 4, 0, LOBBY_INNER + 4),
		Vector3.new(LOBBY_INNER + 4, 0, -LOBBY_INNER - 4),
		Vector3.new(-LOBBY_INNER - 4, 0, -LOBBY_INNER - 4),
	}
	for index, offset in pillarOffsets do
		local pillar = part("Pillar" .. index, Vector3.new(1.5, 14, 1.5), CFrame.new(offset + Vector3.new(0, LOBBY_Y + 8, 0)), Theme.Color.Accent, Enum.Material.Neon)
		pillar.Parent = lobby
	end

	-- Low rail so people can lean over to watch.
	local railHeight = 3
	local railY = LOBBY_Y + railHeight / 2 + deckThickness / 2
	local rails = {
		{ Vector3.new(LOBBY_OUTER * 2, railHeight, 0.5), CFrame.new(0, railY, LOBBY_OUTER) },
		{ Vector3.new(LOBBY_OUTER * 2, railHeight, 0.5), CFrame.new(0, railY, -LOBBY_OUTER) },
		{ Vector3.new(0.5, railHeight, LOBBY_OUTER * 2), CFrame.new(LOBBY_OUTER, railY, 0) },
		{ Vector3.new(0.5, railHeight, LOBBY_OUTER * 2), CFrame.new(-LOBBY_OUTER, railY, 0) },
	}
	for index, spec in rails do
		local rail = part("Rail" .. index, spec[1], spec[2], Theme.Color.Surface, Enum.Material.Glass)
		rail.Transparency = 0.4
		rail.Parent = lobby
	end

	local sign = part("Sign", Vector3.new(24, 6, 0.5), CFrame.new(0, LOBBY_Y + 12, -LOBBY_OUTER + 1), Theme.Color.Surface, Enum.Material.SmoothPlastic)
	sign.Parent = lobby
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Text = "KRILLION"
	signText.TextColor3 = Theme.Color.Text
	signText.FontFace = Theme.Font.Black
	signText.TextScaled = true
	signText.Parent = signGui

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, LOBBY_Y + 1.5, LOBBY_INNER + 8)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby

	return lobby
end

-- Lighting.Technology cannot be set from a script: pick Future by hand in the Lighting properties.
local function applyLighting()
	Lighting.Ambient = Color3.fromRGB(12, 20, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 35, 70)
	Lighting.Brightness = 1.5
	Lighting.ClockTime = 20
	Lighting.FogColor = Theme.Color.Navy
	Lighting.FogStart = 60
	Lighting.FogEnd = 400

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.35
	atmosphere.Color = Theme.Color.Navy
	atmosphere.Decay = Theme.Color.Surface
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	local correction = Lighting:FindFirstChild("KrillionColor") or Instance.new("ColorCorrectionEffect")
	correction.Name = "KrillionColor"
	correction.TintColor = Color3.fromRGB(220, 235, 255)
	correction.Saturation = -0.05
	correction.Contrast = 0.1
	correction.Parent = Lighting
end

local maps = ServerStorage:FindFirstChild("Maps")
if maps == nil then
	maps = Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = ServerStorage
end
assert(maps ~= nil)

for _, name in { "Arena", "Lobby" } do
	local old = maps:FindFirstChild(name)
	if old ~= nil then
		old:Destroy()
	end
end

buildArena().Parent = maps
buildLobby().Parent = maps
applyLighting()

local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate ~= nil then
	baseplate:Destroy()
end
local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
if defaultSpawn ~= nil then
	defaultSpawn:Destroy()
end

print("BuildMap: Arena and Lobby built into ServerStorage.Maps")
