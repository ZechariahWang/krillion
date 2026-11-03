--!strict
-- One-shot generator. Run once in Studio (via MCP execute_luau or the command bar) to build
-- ServerStorage.Maps.Arena and ServerStorage.Maps.Lobby plus lighting, then save the place.
-- Not run at runtime. Rebuilding replaces the existing models.
-- The sea is one flat part rather than terrain water, which is far cheaper to render. Terrain is cleared.
-- LightingStyle is not scriptable: set it to Realistic by hand in the Lighting properties.

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)

local TANK_HALF = 40 -- interior half width
local GLASS = 1
local FLOOR_Y = -20
local WALL_TOP = 70
local DECK_Y = GameConfig.Lobby.DeckHeight
local DECK_NEAR = TANK_HALF + 6 -- deck edge closest to the tank
local DECK_FAR = DECK_NEAR + 50
local DECK_HALF_X = 40

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function signText(parent: Instance, name: string, text: string, font: Font, color: Color3, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.FontFace = font
	label.TextColor3 = color
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- A board on two wooden posts with a SurfaceGui on the face that points at `face`.
local function board(parent: Instance, name: string, size: Vector3, cframe: CFrame, face: Enum.NormalId, postDown: number): (Part, Frame)
	local panel = part(name, size, cframe, Theme.Color.Ink, Enum.Material.SmoothPlastic, parent)
	if postDown > 0 then
		-- Posts run from below the board up to its top edge, one at each side.
		local postHeight = size.Y + postDown
		for _, side in { -1, 1 } do
			local sideOffset = cframe.RightVector * (side * (size.X / 2 + 0.6))
			local postCenter = cframe.Position + sideOffset - Vector3.new(0, postDown / 2, 0)
			part(name .. "Post", Vector3.new(1.2, postHeight, 1.2), CFrame.new(postCenter), Theme.Color.WoodDark, Enum.Material.Wood, parent)
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = panel
	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Color.Ink
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Sky
	stroke.Thickness = 12
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 24)
	padding.PaddingBottom = UDim.new(0, 24)
	padding.PaddingLeft = UDim.new(0, 30)
	padding.PaddingRight = UDim.new(0, 30)
	padding.Parent = frame
	return panel, frame
end

local function buildPlatformTemplate(arena: Model)
	local width = GameConfig.Platform.Width
	local height = GameConfig.Platform.Height
	local pillar = part("PlatformTemplate", Vector3.new(width, height, width), CFrame.new(0, -400, 0), Theme.Color.Red, Enum.Material.SmoothPlastic, arena)

	local cap = part("Cap", Vector3.new(width + 1, 1, width + 1), pillar.CFrame * CFrame.new(0, height / 2 + 0.5, 0), Theme.Color.White, Enum.Material.SmoothPlastic, pillar)
	cap.CanCollide = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = pillar
	weld.Part1 = cap
	weld.Parent = cap

	local top = Instance.new("Attachment")
	top.Name = "Top"
	top.Position = Vector3.new(0, height / 2 + 1, 0)
	top.Parent = pillar

	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Confetti"
	confetti.Enabled = false
	confetti.Rate = 0
	confetti.Lifetime = NumberRange.new(1.5, 2.5)
	confetti.Speed = NumberRange.new(25, 40)
	confetti.SpreadAngle = Vector2.new(45, 45)
	confetti.Acceleration = Vector3.new(0, -35, 0)
	confetti.Drag = 1
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.RotSpeed = NumberRange.new(-300, 300)
	confetti.Size = NumberSequence.new(0.5)
	confetti.LightInfluence = 0
	confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Color.Yellow),
		ColorSequenceKeypoint.new(0.33, Theme.Color.Red),
		ColorSequenceKeypoint.new(0.66, Theme.Color.Sky),
		ColorSequenceKeypoint.new(1, Theme.Color.Green),
	})
	confetti.Parent = top

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(220, 40)
	tag.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 9, 0)
	tag.MaxDistance = 200
	tag.Parent = pillar
	signText(tag, "NameText", "Player", Theme.Font.Body, Theme.Color.White, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
end

local function buildArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "Arena"

	local ocean = part("Ocean", Vector3.new(2048, 1, 2048), CFrame.new(0, -4.5, 0), Color3.fromHex("1E90E0"), Enum.Material.SmoothPlastic, arena)
	ocean.CanCollide = false
	ocean.CanQuery = false
	ocean.CanTouch = false
	ocean.CastShadow = false

	-- Sandy island the tank sits on. Pillars pass through it, so it does not collide.
	local island = part("Island", Vector3.new(190, 4, 190), CFrame.new(0, -4, 0), Theme.Color.Sand, Enum.Material.Sand, arena)
	island.CanCollide = false

	local floor = part("Floor", Vector3.new(TANK_HALF * 2, 20, TANK_HALF * 2), CFrame.new(0, FLOOR_Y - 10, 0), Theme.Color.Sand, Enum.Material.Sand, arena)
	floor.CanCollide = false

	-- Glass tank walls with painted corner posts and a wooden rim.
	local wallHeight = WALL_TOP - FLOOR_Y
	local wallY = FLOOR_Y + wallHeight / 2
	local edge = TANK_HALF + GLASS / 2
	local walls = {
		{ Vector3.new(TANK_HALF * 2, wallHeight, GLASS), CFrame.new(0, wallY, edge) },
		{ Vector3.new(TANK_HALF * 2, wallHeight, GLASS), CFrame.new(0, wallY, -edge) },
		{ Vector3.new(GLASS, wallHeight, TANK_HALF * 2), CFrame.new(edge, wallY, 0) },
		{ Vector3.new(GLASS, wallHeight, TANK_HALF * 2), CFrame.new(-edge, wallY, 0) },
	}
	for index, spec in walls do
		local glass = part("Glass" .. index, spec[1], spec[2], Color3.fromHex("CDEBFF"), Enum.Material.Glass, arena)
		glass.Transparency = 0.75
		glass.CastShadow = false
		local rimSize = spec[1] + Vector3.new(4, 0, 4)
		part("Rim" .. index, Vector3.new(rimSize.X, 2, rimSize.Z), CFrame.new(spec[2].Position.X, WALL_TOP + 1, spec[2].Position.Z), Theme.Color.Wood, Enum.Material.WoodPlanks, arena)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part("Post", Vector3.new(4, wallHeight + 4, 4), CFrame.new(x * (edge + 1), wallY + 2, z * (edge + 1)), Theme.Color.Blue, Enum.Material.SmoothPlastic, arena)
		end
	end

	local water = part("Water", Vector3.new(TANK_HALF * 2, -FLOOR_Y, TANK_HALF * 2), CFrame.new(0, FLOOR_Y / 2, 0), Theme.Color.Water, Enum.Material.SmoothPlastic, arena)
	water.Transparency = 0.12
	water.Reflectance = 0.1
	water.CanCollide = false
	water.CanQuery = false
	water.CastShadow = false
	water:SetAttribute("FloorY", FLOOR_Y)

	local foam = part("Foam", Vector3.new(TANK_HALF * 2, 0.3, TANK_HALF * 2), CFrame.new(0, 0.15, 0), Theme.Color.Sky, Enum.Material.SmoothPlastic, arena)
	foam.Transparency = 0.7
	foam.CanCollide = false
	foam.CanQuery = false
	foam.CastShadow = false

	-- Two blocky palm trees on the island corners.
	for _, spot in { Vector3.new(-80, -2, -80), Vector3.new(80, -2, -70) } do
		for step = 0, 5 do
			part("Trunk", Vector3.new(2.5, 3, 2.5), CFrame.new(spot + Vector3.new(step * 0.6, 1.5 + step * 3, 0)), Theme.Color.WoodDark, Enum.Material.Wood, arena)
		end
		local crown = spot + Vector3.new(3.6, 19.5, 0)
		part("Leaves", Vector3.new(14, 1.5, 4), CFrame.new(crown), Theme.Color.Leaf, Enum.Material.SmoothPlastic, arena)
		part("Leaves", Vector3.new(4, 1.5, 14), CFrame.new(crown), Theme.Color.Leaf, Enum.Material.SmoothPlastic, arena)
	end

	buildPlatformTemplate(arena)
	return arena
end

local function buildHowToPlay(lobby: Model)
	local cframe = CFrame.new(-DECK_HALF_X + 2, DECK_Y + 9, DECK_NEAR + 26) * CFrame.Angles(0, math.rad(90), 0)
	local _, frame = board(lobby, "HowToPlay", Vector3.new(22, 14, 0.6), cframe, Enum.NormalId.Back, 3)
	signText(frame, "Title", "HOW TO PLAY", Theme.Font.Title, Theme.Color.Yellow, UDim2.new(1, 0, 0.2, 0), UDim2.fromScale(0, 0))
	local steps = {
		"1. A prompt pops up. Type an answer!",
		"2. Rarer answers lift your pillar higher.",
		"3. Wrong answers? Try again fast!",
		"4. The water rises every round.",
		"5. Last one above water wins!",
	}
	for index, step in steps do
		local y = 0.22 + (index - 1) * 0.155
		local line = signText(frame, "Step" .. index, step, Theme.Font.Body, Theme.Color.White, UDim2.new(1, 0, 0.13, 0), UDim2.fromScale(0, y))
		line.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function buildTierChart(lobby: Model)
	local cframe = CFrame.new(DECK_HALF_X - 2, DECK_Y + 9, DECK_NEAR + 26) * CFrame.Angles(0, math.rad(-90), 0)
	local _, frame = board(lobby, "TierChart", Vector3.new(22, 14, 0.6), cframe, Enum.NormalId.Back, 3)
	signText(frame, "Title", "HOW RARE?", Theme.Font.Title, Theme.Color.Yellow, UDim2.new(1, 0, 0.2, 0), UDim2.fromScale(0, 0))
	for index, tier in Tiers.List do
		local y = 0.22 + (index - 1) * 0.13
		local name = signText(frame, tier.name, tier.label, Theme.Font.Title, Theme.Tier[tier.name], UDim2.new(0.7, 0, 0.11, 0), UDim2.fromScale(0, y))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local points = signText(frame, tier.name .. "Points", "+" .. tier.points, Theme.Font.Title, Theme.Color.White, UDim2.new(0.3, 0, 0.11, 0), UDim2.fromScale(0.7, y))
		points.TextXAlignment = Enum.TextXAlignment.Right
	end
end

local function buildScoreboard(lobby: Model)
	-- Hangs high over the tank-side rail so spectators can see under it into the tank.
	local cframe = CFrame.new(0, DECK_Y + 20, DECK_NEAR + 1)
	local _, titleFrame = board(lobby, "TitleSign", Vector3.new(34, 7, 0.6), cframe + Vector3.new(0, 9, 0), Enum.NormalId.Back, 0)
	signText(titleFrame, "Logo", "KRILLION", Theme.Font.Title, Theme.Color.Yellow, UDim2.new(1, 0, 0.62, 0), UDim2.fromScale(0, 0))
	signText(titleFrame, "Tagline", "Rare answers lift you up. Common ones get you wet!", Theme.Font.Body, Theme.Color.White, UDim2.new(1, 0, 0.32, 0), UDim2.fromScale(0, 0.66))

	local _, frame = board(lobby, "Scoreboard", Vector3.new(30, 10, 0.6), cframe, Enum.NormalId.Back, 0)
	signText(frame, "Title", "WAITING FOR PLAYERS", Theme.Font.Title, Theme.Color.Sky, UDim2.new(1, 0, 0.35, 0), UDim2.fromScale(0, 0))
	signText(frame, "Body", "0 / 2", Theme.Font.Body, Theme.Color.White, UDim2.new(1, 0, 0.55, 0), UDim2.fromScale(0, 0.42))
	for _, x in { -14, 14 } do
		part("ScoreboardPole", Vector3.new(1.5, 30, 1.5), CFrame.new(x, DECK_Y + 15, DECK_NEAR + 1), Theme.Color.WoodDark, Enum.Material.Wood, lobby)
	end
end

local function buildDeck(lobby: Model)
	local depth = DECK_FAR - DECK_NEAR
	local centerZ = (DECK_NEAR + DECK_FAR) / 2
	part("Deck", Vector3.new(DECK_HALF_X * 2, 2, depth), CFrame.new(0, DECK_Y - 1, centerZ), Theme.Color.Wood, Enum.Material.WoodPlanks, lobby)

	-- Stilts down into the sea.
	for _, x in { -DECK_HALF_X + 2, 0, DECK_HALF_X - 2 } do
		for _, z in { DECK_NEAR + 2, DECK_FAR - 2 } do
			part("Stilt", Vector3.new(3, DECK_Y + 30, 3), CFrame.new(x, DECK_Y / 2 - 15, z), Theme.Color.WoodDark, Enum.Material.Wood, lobby)
		end
	end

	-- Rails: posts every 8 studs plus a top bar.
	local railY = DECK_Y + 2
	local sides = {
		{ Vector3.new(-DECK_HALF_X, railY, DECK_NEAR), Vector3.new(DECK_HALF_X, railY, DECK_NEAR) },
		{ Vector3.new(-DECK_HALF_X, railY, DECK_FAR), Vector3.new(DECK_HALF_X, railY, DECK_FAR) },
		{ Vector3.new(-DECK_HALF_X, railY, DECK_NEAR), Vector3.new(-DECK_HALF_X, railY, DECK_FAR) },
		{ Vector3.new(DECK_HALF_X, railY, DECK_NEAR), Vector3.new(DECK_HALF_X, railY, DECK_FAR) },
	}
	for _, side in sides do
		local from = side[1]
		local to = side[2]
		local length = (to - from).Magnitude
		local middle = (from + to) / 2
		local bar = part("RailBar", Vector3.new(1, 0.8, length), CFrame.lookAt(middle + Vector3.new(0, 1.6, 0), to + Vector3.new(0, 1.6, 0)), Theme.Color.Wood, Enum.Material.Wood, lobby)
		bar.Size = Vector3.new(1, 0.8, length + 1)
		if from.Z == DECK_NEAR and to.Z == DECK_NEAR then
			-- The tank-side rail is a clear glass panel so spectators can see down into the water.
			bar.Name = "GlassRail"
			bar.Size = Vector3.new(0.4, 4, length)
			bar.CFrame = CFrame.lookAt(middle + Vector3.new(0, 0, 0), to)
			bar.Material = Enum.Material.Glass
			bar.Color = Color3.fromHex("CDEBFF")
			bar.Transparency = 0.8
			continue
		end
		local count = math.floor(length / 8)
		for step = 0, count do
			local point = from + (to - from) * (step / count)
			part("RailPost", Vector3.new(1.2, 4, 1.2), CFrame.new(point), Theme.Color.WoodDark, Enum.Material.Wood, lobby)
		end
	end
	-- Invisible wall so nobody hops the rail into the sea.
	for _, side in sides do
		local from = side[1]
		local to = side[2]
		local length = (to - from).Magnitude
		local middle = (from + to) / 2
		local wall = part("RailBlocker", Vector3.new(1, 12, length), CFrame.lookAt(middle + Vector3.new(0, 5, 0), to + Vector3.new(0, 5, 0)), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
		wall.Transparency = 1
	end

	-- Lamp posts at the corners.
	for _, x in { -DECK_HALF_X + 3, DECK_HALF_X - 3 } do
		for _, z in { DECK_NEAR + 3, DECK_FAR - 3 } do
			part("LampPost", Vector3.new(0.8, 9, 0.8), CFrame.new(x, DECK_Y + 4.5, z), Theme.Color.Ink, Enum.Material.SmoothPlastic, lobby)
			local bulb = part("LampBulb", Vector3.new(1.8, 1.8, 1.8), CFrame.new(x, DECK_Y + 9.5, z), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
			bulb.Shape = Enum.PartType.Ball
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex("FFF1C9")
			light.Range = 16
			light.Brightness = 1.2
			light.Parent = bulb
		end
	end

	-- Beach tables with umbrellas.
	local umbrellas = {
		{ Vector3.new(-24, 0, DECK_FAR - 12), Theme.Color.Red },
		{ Vector3.new(24, 0, DECK_FAR - 12), Theme.Color.Yellow },
	}
	for _, spec in umbrellas do
		local base = Vector3.new(spec[1].X, DECK_Y, spec[1].Z)
		local tabletop = part("Table", Vector3.new(1, 5, 5), CFrame.new(base + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
		tabletop.Shape = Enum.PartType.Cylinder
		part("Pole", Vector3.new(0.5, 10, 0.5), CFrame.new(base + Vector3.new(0, 5, 0)), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
		local canopy = part("Umbrella", Vector3.new(1, 10, 10), CFrame.new(base + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)), spec[2], Enum.Material.SmoothPlastic, lobby)
		canopy.Shape = Enum.PartType.Cylinder
	end

	-- Barrels and a life ring for flavour.
	for _, x in { -34, -31 } do
		local barrel = part("Barrel", Vector3.new(4, 3, 3), CFrame.new(x, DECK_Y + 1.5, DECK_FAR - 4) * CFrame.Angles(0, 0, math.rad(90)), Theme.Color.WoodDark, Enum.Material.Wood, lobby)
		barrel.Shape = Enum.PartType.Cylinder
	end
end

local function buildLobby(): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	buildDeck(lobby)
	buildHowToPlay(lobby)
	buildTierChart(lobby)
	buildScoreboard(lobby)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, DECK_Y + 0.5, DECK_NEAR + 22)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby
	return lobby
end

local function applyLighting()
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 175)
	Lighting.Brightness = 3
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 30
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000
	Lighting.FogColor = Color3.fromRGB(190, 225, 255)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 230, 255)
	atmosphere.Decay = Color3.fromRGB(120, 180, 240)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting

	local correction = Lighting:FindFirstChild("KrillionColor") or Instance.new("ColorCorrectionEffect")
	correction.Name = "KrillionColor"
	correction.TintColor = Color3.fromRGB(255, 255, 255)
	correction.Brightness = 0.05
	correction.Saturation = 0.2
	correction.Contrast = 0.05
	correction.Parent = Lighting

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
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

workspace.Terrain:Clear()
buildArena().Parent = maps
buildLobby().Parent = maps
applyLighting()

print("BuildMap: Arena and Lobby built into ServerStorage.Maps")
