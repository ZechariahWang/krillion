--!strict
-- One-shot generator. Run once in Studio (via MCP execute_luau or the command bar) to build
-- ServerStorage.Maps.Arena, the Lobby, the terrain (island, beach, sea) and lighting, then save the place.
-- Not run at runtime. Rebuilding replaces the existing models and terrain.
-- LightingStyle is not scriptable: set it to Realistic by hand in the Lighting properties.

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)

local TANK_HALF = 40 -- interior half width; a multiple of 4 so terrain voxels line up with the glass
local GLASS = 1
local FLOOR_Y = -20
local WALL_TOP = 70
local SEA_LEVEL = -4
-- Terrain sea is only this wide (a multiple of 8). Past it a flat "far sea" ring takes over, and the
-- atmosphere haze hides the seam, so the sea looks endless while staying cheap to render.
local SEA_SIZE = 400
local FAR_SEA_COLOR = Color3.fromHex("2FA9DC")
local DECK_Y = GameConfig.Lobby.DeckHeight
local DECK_NEAR = TANK_HALF + 6 -- deck edge closest to the tank
local DECK_FAR = DECK_NEAR + 50
local DECK_HALF_X = 40

local WOOD_LIGHT = Color3.fromHex("C69469")
local WOOD = Theme.Color.Wood
local WOOD_DARK = Theme.Color.WoodDark
local WOOD_DEEP = Color3.fromHex("5E3B25")

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

local function cylinder(name: string, length: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	-- Roblox cylinders run along X; callers pass the CFrame of an upright cylinder.
	local p = part(name, Vector3.new(length, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function decor(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

-- Terrain ----------------------------------------------------------------------------------------

-- Sea floor, open sea, the island the tank sits in, and a gentle beach running under the dock.
local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	local seaSize = SEA_SIZE
	terrain:FillBlock(CFrame.new(0, -30, 0), Vector3.new(seaSize, 4, seaSize), Enum.Material.Sand)
	task.wait()
	terrain:FillBlock(CFrame.new(0, (SEA_LEVEL - 28) / 2, 0), Vector3.new(seaSize, SEA_LEVEL + 28, seaSize), Enum.Material.Water)
	task.wait()
	-- Island: x -96..96, z -96..56, top at y -2.
	terrain:FillBlock(CFrame.new(0, -15, -20), Vector3.new(192, 26, 152), Enum.Material.Sand)
	task.wait()
	-- Beach: a gentle slope from the island edge (z 56, y -2) down under the sea (z 156, y -10), so the
	-- shoreline runs under the back of the dock and the sea laps the sand beside it.
	-- The wedge's high edge faces -Z after the half turn, so it meets the island.
	terrain:FillWedge(CFrame.new(0, -6, 106) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(192, 8, 100), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -19, 106), Vector3.new(192, 18, 100), Enum.Material.Sand)
	task.wait()
	-- The tank column stays clear: the game fills it with water itself (see WaterService).
	terrain:FillBlock(CFrame.new(0, 20, 0), Vector3.new(TANK_HALF * 2, 120, TANK_HALF * 2), Enum.Material.Air)

	terrain.WaterColor = Color3.fromHex("1A9BD0")
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 10
	terrain.WaterReflectance = 0.35
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromHex("EBD29A"))
end

-- Arena ------------------------------------------------------------------------------------------

local function signText(parent: Instance, name: string, text: string, color: Color3)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.FontFace = Theme.Font.Body
	label.TextColor3 = color
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent
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
	signText(tag, "NameText", "Player", Theme.Color.White)
end

local function buildArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "Arena"

	-- Far sea: a flat ring at the water line around the terrain sea, fading into the haze.
	-- It overlaps the terrain edge a little and sits just above the still water, so the terrain's
	-- edge is hidden and only wave crests poke through, which reads as a distant swell.
	local reach = 2048
	local overlap = 8
	local half = SEA_SIZE / 2 - overlap
	local band = reach / 2 - half
	local ring = {
		{ Vector3.new(reach, 1, band), CFrame.new(0, SEA_LEVEL - 0.4, half + band / 2) },
		{ Vector3.new(reach, 1, band), CFrame.new(0, SEA_LEVEL - 0.4, -half - band / 2) },
		{ Vector3.new(band, 1, half * 2), CFrame.new(half + band / 2, SEA_LEVEL - 0.4, 0) },
		{ Vector3.new(band, 1, half * 2), CFrame.new(-half - band / 2, SEA_LEVEL - 0.4, 0) },
	}
	for _, spec in ring do
		local far = part("FarSea", spec[1], spec[2], FAR_SEA_COLOR, Enum.Material.SmoothPlastic, arena)
		decor(far)
		far.CastShadow = false
	end

	-- Dark slate floor, so the clear water above it reads as deep rather than shallow.
	local floor = part("Floor", Vector3.new(TANK_HALF * 2, 20, TANK_HALF * 2), CFrame.new(0, FLOOR_Y - 10, 0), Color3.fromHex("1F3A52"), Enum.Material.Slate, arena)
	floor.CanCollide = false

	-- Tank walls with painted corner posts and a wooden rim.
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
		-- See-through plastic, not Glass: Roblox does not draw transparent things (the water) behind Glass.
		local glass = part("Glass" .. index, spec[1], spec[2], Color3.fromHex("CDEBFF"), Enum.Material.SmoothPlastic, arena)
		glass.Transparency = 0.85
		glass.Reflectance = 0.1
		glass.CastShadow = false
		local rimSize = spec[1] + Vector3.new(4, 0, 4)
		part("Rim" .. index, Vector3.new(rimSize.X, 2, rimSize.Z), CFrame.new(spec[2].Position.X, WALL_TOP + 1, spec[2].Position.Z), WOOD, Enum.Material.WoodPlanks, arena)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part("Post", Vector3.new(4, wallHeight + 4, 4), CFrame.new(x * (edge + 1), wallY + 2, z * (edge + 1)), Theme.Color.Blue, Enum.Material.SmoothPlastic, arena)
		end
	end

	-- The tank water itself is terrain (WaterService fills it). This invisible box just marks the
	-- water volume: WaterService reads its FloorY and sizes it to the water so its bubbles stay underwater.
	local water = part("Water", Vector3.new(TANK_HALF * 2, -FLOOR_Y, TANK_HALF * 2), CFrame.new(0, FLOOR_Y / 2, 0), Theme.Color.Water, Enum.Material.SmoothPlastic, arena)
	water.Transparency = 1
	decor(water)
	water.CastShadow = false
	water:SetAttribute("FloorY", FLOOR_Y)

	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Shape = Enum.ParticleEmitterShape.Box
	bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Rate = 14
	bubbles.Lifetime = NumberRange.new(2, 4)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.SpreadAngle = Vector2.new(10, 10)
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.35) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Color = ColorSequence.new(Color3.fromRGB(230, 248, 255))
	bubbles.LightEmission = 0.3
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Parent = water

	-- Where the water will reach at the end of this round: a thin line around the inside of the glass.
	-- Hidden here; each client shows and moves it locally.
	local nextLevel = Instance.new("Model")
	nextLevel.Name = "NextLevel"
	local inset = TANK_HALF - 0.3
	local lines = {
		{ Vector3.new(TANK_HALF * 2, 0.4, 0.4), Vector3.new(0, 0, inset) },
		{ Vector3.new(TANK_HALF * 2, 0.4, 0.4), Vector3.new(0, 0, -inset) },
		{ Vector3.new(0.4, 0.4, TANK_HALF * 2), Vector3.new(inset, 0, 0) },
		{ Vector3.new(0.4, 0.4, TANK_HALF * 2), Vector3.new(-inset, 0, 0) },
	}
	for index, spec in lines do
		local line = part("Line" .. index, spec[1], CFrame.new(spec[2]), Theme.Color.Gold, Enum.Material.SmoothPlastic, nextLevel)
		line.Transparency = 1
		decor(line)
		line.CastShadow = false
	end
	nextLevel.Parent = arena

	-- Blocky palm trees around the island.
	for _, spot in { Vector3.new(-80, -2, -80), Vector3.new(80, -2, -70), Vector3.new(-84, -2, 30), Vector3.new(86, -2, 20) } do
		for step = 0, 5 do
			part("Trunk", Vector3.new(2.5, 3, 2.5), CFrame.new(spot + Vector3.new(step * 0.6, 1.5 + step * 3, 0)), WOOD_DARK, Enum.Material.Wood, arena)
		end
		local crown = spot + Vector3.new(3.6, 19.5, 0)
		part("Leaves", Vector3.new(14, 1.5, 4), CFrame.new(crown), Theme.Color.Leaf, Enum.Material.SmoothPlastic, arena)
		part("Leaves", Vector3.new(4, 1.5, 14), CFrame.new(crown), Theme.Color.Leaf, Enum.Material.SmoothPlastic, arena)
		part("Leaves", Vector3.new(9, 1.2, 9), CFrame.new(crown + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromHex("5FCF6A"), Enum.Material.SmoothPlastic, arena)
	end

	buildPlatformTemplate(arena)
	return arena
end

-- Lobby: a boardwalk over the beach ---------------------------------------------------------------

local function buildDeck(lobby: Model)
	local depth = DECK_FAR - DECK_NEAR
	local centerZ = (DECK_NEAR + DECK_FAR) / 2

	-- A dark sub-floor under the planks, so the small gaps between planks read as shadow.
	part("SubFloor", Vector3.new(DECK_HALF_X * 2, 1, depth), CFrame.new(0, DECK_Y - 1.4, centerZ), WOOD_DEEP, Enum.Material.Wood, lobby)
	-- Planks in three shades, with a small gap between each.
	local shades = { WOOD, WOOD_LIGHT, WOOD, Color3.fromHex("A8774F") }
	local plankDepth = 2
	local count = math.floor(depth / plankDepth)
	for index = 0, count - 1 do
		local z = DECK_NEAR + plankDepth / 2 + index * plankDepth
		local shade = shades[(index % #shades) + 1]
		part("Plank", Vector3.new(DECK_HALF_X * 2, 0.6, plankDepth - 0.15), CFrame.new(0, DECK_Y - 0.6, z), shade, Enum.Material.Wood, lobby)
	end
	-- Trim beams around the edge.
	part("Trim", Vector3.new(DECK_HALF_X * 2 + 1, 1.2, 1), CFrame.new(0, DECK_Y - 1, DECK_NEAR), WOOD_DEEP, Enum.Material.Wood, lobby)
	part("Trim", Vector3.new(DECK_HALF_X * 2 + 1, 1.2, 1), CFrame.new(0, DECK_Y - 1, DECK_FAR), WOOD_DEEP, Enum.Material.Wood, lobby)
	part("Trim", Vector3.new(1, 1.2, depth), CFrame.new(-DECK_HALF_X, DECK_Y - 1, centerZ), WOOD_DEEP, Enum.Material.Wood, lobby)
	part("Trim", Vector3.new(1, 1.2, depth), CFrame.new(DECK_HALF_X, DECK_Y - 1, centerZ), WOOD_DEEP, Enum.Material.Wood, lobby)

	-- Round stilts down into the sand, with cross braces between them.
	local stiltXs = { -DECK_HALF_X + 2, -DECK_HALF_X / 3, DECK_HALF_X / 3, DECK_HALF_X - 2 }
	local stiltZs = { DECK_NEAR + 2, centerZ, DECK_FAR - 2 }
	local stiltBottom = -16
	local stiltLength = DECK_Y - 1.5 - stiltBottom
	for _, x in stiltXs do
		for _, z in stiltZs do
			cylinder("Stilt", stiltLength, 2.4, CFrame.new(x, stiltBottom + stiltLength / 2, z), WOOD_DARK, Enum.Material.Wood, lobby)
		end
	end
	for _, z in stiltZs do
		for index = 1, #stiltXs - 1 do
			local a = Vector3.new(stiltXs[index], DECK_Y - 4, z)
			local b = Vector3.new(stiltXs[index + 1], DECK_Y - 9, z)
			local brace = part("Brace", Vector3.new(0.6, 0.8, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), WOOD_DEEP, Enum.Material.Wood, lobby)
			decor(brace)
		end
	end
end

local function buildRails(lobby: Model)
	local railY = DECK_Y
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
		local facing = CFrame.lookAt(middle, to)
		if from.Z == DECK_NEAR and to.Z == DECK_NEAR then
			-- The tank-side rail is a clear panel with a wooden cap, so spectators can see into the water.
			local panel = part("GlassRail", Vector3.new(0.3, 3.4, length), facing + Vector3.new(0, 1.7, 0), Color3.fromHex("CDEBFF"), Enum.Material.SmoothPlastic, lobby)
			panel.Transparency = 0.85
			panel.CastShadow = false
			part("RailCap", Vector3.new(0.8, 0.4, length + 1), facing + Vector3.new(0, 3.6, 0), WOOD, Enum.Material.Wood, lobby)
		else
			part("RailTop", Vector3.new(0.8, 0.5, length + 1), facing + Vector3.new(0, 3.6, 0), WOOD, Enum.Material.Wood, lobby)
			part("RailMid", Vector3.new(0.5, 0.4, length), facing + Vector3.new(0, 1.9, 0), WOOD_DARK, Enum.Material.Wood, lobby)
			local posts = math.floor(length / 6)
			for step = 0, posts do
				local point = from + (to - from) * (step / posts)
				part("RailPost", Vector3.new(1, 4, 1), CFrame.new(point + Vector3.new(0, 1.8, 0)), WOOD_DARK, Enum.Material.Wood, lobby)
			end
		end
		-- Invisible wall so nobody hops the rail into the sea.
		local wall = part("RailBlocker", Vector3.new(1, 12, length), facing + Vector3.new(0, 6, 0), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
		wall.Transparency = 1
	end

	-- Life rings hanging on the side rails.
	for _, x in { -DECK_HALF_X - 0.6, DECK_HALF_X + 0.6 } do
		local ring = cylinder("LifeRing", 0.6, 3.6, CFrame.new(x, DECK_Y + 2.2, DECK_NEAR + 20) * CFrame.Angles(0, 0, math.rad(90)), Theme.Color.Orange, Enum.Material.SmoothPlastic, lobby)
		decor(ring)
		local hole = cylinder("LifeRingHole", 0.7, 1.8, ring.CFrame * CFrame.Angles(0, 0, math.rad(-90)), WOOD_DARK, Enum.Material.Wood, lobby)
		decor(hole)
	end
end

local function lamp(lobby: Model, position: Vector3)
	part("LampPost", Vector3.new(0.6, 9, 0.6), CFrame.new(position + Vector3.new(0, 4.5, 0)), Theme.Color.Ink, Enum.Material.Metal, lobby)
	part("LampArm", Vector3.new(0.4, 0.4, 2), CFrame.new(position + Vector3.new(0, 9, 0.8)), Theme.Color.Ink, Enum.Material.Metal, lobby)
	local housing = part("Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(position + Vector3.new(0, 8.1, 1.6)), Theme.Color.Ink, Enum.Material.Metal, lobby)
	local glow = part("LanternGlass", Vector3.new(1, 1.2, 1), housing.CFrame, Color3.fromHex("FFE7B0"), Enum.Material.SmoothPlastic, lobby)
	glow.Transparency = 0.2
	decor(glow)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFD9A0")
	light.Range = 14
	light.Brightness = 1
	light.Parent = glow
end

local function bench(lobby: Model, position: Vector3, facing: number)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0)
	part("BenchSeat", Vector3.new(8, 0.5, 2), base * CFrame.new(0, 1.6, 0), WOOD_LIGHT, Enum.Material.Wood, lobby)
	part("BenchBack", Vector3.new(8, 2, 0.4), base * CFrame.new(0, 2.8, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), WOOD_LIGHT, Enum.Material.Wood, lobby)
	for _, x in { -3.4, 3.4 } do
		part("BenchLeg", Vector3.new(0.5, 1.4, 1.8), base * CFrame.new(x, 0.7, 0), Theme.Color.Ink, Enum.Material.Metal, lobby)
	end
end

local function lounger(lobby: Model, position: Vector3, towel: Color3)
	local base = CFrame.new(position)
	part("LoungerFrame", Vector3.new(2.4, 0.4, 6), base * CFrame.new(0, 1, 0), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
	part("LoungerBack", Vector3.new(2.4, 0.4, 2.4), base * CFrame.new(0, 1.8, -2.6) * CFrame.Angles(math.rad(35), 0, 0), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
	local cloth = part("Towel", Vector3.new(2, 0.1, 4.4), base * CFrame.new(0, 1.25, 0.4), towel, Enum.Material.Fabric, lobby)
	decor(cloth)
	for _, x in { -1, 1 } do
		for _, z in { -2.6, 2.6 } do
			part("LoungerLeg", Vector3.new(0.3, 0.8, 0.3), base * CFrame.new(x, 0.4, z), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
		end
	end
end

local function umbrellaTable(lobby: Model, position: Vector3, canopyColor: Color3)
	local base = CFrame.new(position)
	cylinder("TableTop", 0.4, 5, base * CFrame.new(0, 2.8, 0), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
	cylinder("TableLeg", 2.6, 0.5, base * CFrame.new(0, 1.4, 0), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
	cylinder("Pole", 10, 0.35, base * CFrame.new(0, 5, 0), Theme.Color.White, Enum.Material.SmoothPlastic, lobby)
	-- Canopy: a wide disc with a smaller tilted ring of stripes.
	cylinder("Canopy", 0.5, 11, base * CFrame.new(0, 9.6, 0), canopyColor, Enum.Material.Fabric, lobby)
	cylinder("CanopyTop", 0.6, 4, base * CFrame.new(0, 10.1, 0), Theme.Color.White, Enum.Material.Fabric, lobby)
	for _, angle in { 0, 90, 180, 270 } do
		local seat = base * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, 4)
		part("Chair", Vector3.new(1.8, 0.4, 1.8), seat * CFrame.new(0, 1.6, 0), WOOD_LIGHT, Enum.Material.Wood, lobby)
		part("ChairBack", Vector3.new(1.8, 1.8, 0.3), seat * CFrame.new(0, 2.6, 0.8), WOOD_LIGHT, Enum.Material.Wood, lobby)
		part("ChairLeg", Vector3.new(1.4, 1.4, 1.4), seat * CFrame.new(0, 0.7, 0), Theme.Color.Ink, Enum.Material.Metal, lobby)
	end
end

local function pottedPalm(lobby: Model, position: Vector3)
	cylinder("Pot", 2.4, 3, CFrame.new(position + Vector3.new(0, 1.2, 0)), Color3.fromHex("C2694A"), Enum.Material.Slate, lobby)
	cylinder("Soil", 0.2, 2.6, CFrame.new(position + Vector3.new(0, 2.4, 0)), WOOD_DEEP, Enum.Material.Ground, lobby)
	part("Trunk", Vector3.new(0.8, 4, 0.8), CFrame.new(position + Vector3.new(0, 4.4, 0)), WOOD_DARK, Enum.Material.Wood, lobby)
	local crown = position + Vector3.new(0, 6.6, 0)
	part("Leaves", Vector3.new(6, 0.5, 1.6), CFrame.new(crown), Theme.Color.Leaf, Enum.Material.SmoothPlastic, lobby)
	part("Leaves", Vector3.new(1.6, 0.5, 6), CFrame.new(crown), Theme.Color.Leaf, Enum.Material.SmoothPlastic, lobby)
	part("Leaves", Vector3.new(4, 0.5, 4), CFrame.new(crown + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromHex("5FCF6A"), Enum.Material.SmoothPlastic, lobby)
end

-- A small striped-roof beach shack at the back of the deck, with a serving counter.
local function shack(lobby: Model)
	local center = Vector3.new(0, DECK_Y, DECK_FAR - 6)
	local width, height, depth = 16, 8, 8
	part("ShackBack", Vector3.new(width, height, 0.6), CFrame.new(center + Vector3.new(0, height / 2, depth / 2)), WOOD_LIGHT, Enum.Material.WoodPlanks, lobby)
	for _, x in { -width / 2, width / 2 } do
		part("ShackSide", Vector3.new(0.6, height, depth), CFrame.new(center + Vector3.new(x, height / 2, 0)), WOOD_LIGHT, Enum.Material.WoodPlanks, lobby)
	end
	part("ShackFrontLow", Vector3.new(width, 3.4, 0.6), CFrame.new(center + Vector3.new(0, 1.7, -depth / 2)), WOOD, Enum.Material.WoodPlanks, lobby)
	part("Counter", Vector3.new(width + 1, 0.4, 2), CFrame.new(center + Vector3.new(0, 3.6, -depth / 2 - 0.4)), WOOD_DARK, Enum.Material.Wood, lobby)
	for _, x in { -width / 2, width / 2 } do
		part("ShackPost", Vector3.new(0.8, height, 0.8), CFrame.new(center + Vector3.new(x, height / 2, -depth / 2)), WOOD_DARK, Enum.Material.Wood, lobby)
	end
	-- Striped awning roof, sloping toward the deck.
	local stripes = 8
	local stripeWidth = (width + 2) / stripes
	for index = 0, stripes - 1 do
		local x = -(width + 2) / 2 + stripeWidth / 2 + index * stripeWidth
		local color = Theme.Color.Red
		if index % 2 == 1 then
			color = Theme.Color.White
		end
		part("Awning", Vector3.new(stripeWidth, 0.4, depth + 3), CFrame.new(center + Vector3.new(x, height + 0.6, -1)) * CFrame.Angles(math.rad(12), 0, 0), color, Enum.Material.Fabric, lobby)
	end
	-- Things on the counter.
	for index, x in { -5, -2.5, 3, 5.5 } do
		local colors = { Theme.Color.Yellow, Theme.Color.Sky, Theme.Color.Red, Theme.Color.Green }
		local cup = cylinder("Cup", 0.9, 0.6, CFrame.new(center + Vector3.new(x, 4.25, -depth / 2 - 0.4)), colors[index], Enum.Material.SmoothPlastic, lobby)
		decor(cup)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFD9A0")
	light.Range = 12
	light.Brightness = 0.8
	local glow = part("ShackLight", Vector3.new(0.6, 0.6, 0.6), CFrame.new(center + Vector3.new(0, height - 1, 0)), Color3.fromHex("FFE7B0"), Enum.Material.SmoothPlastic, lobby)
	decor(glow)
	light.Parent = glow
end

-- Little triangle flags strung between two points.
local function bunting(lobby: Model, from: Vector3, to: Vector3)
	local colors = { Theme.Color.Red, Theme.Color.Yellow, Theme.Color.Sky, Theme.Color.Green, Theme.Color.White }
	local length = (to - from).Magnitude
	local count = math.floor(length / 2.5)
	for index = 0, count do
		local alpha = index / count
		local sag = math.sin(alpha * math.pi) * 1.5
		local point = from:Lerp(to, alpha) - Vector3.new(0, sag, 0)
		local flag = Instance.new("WedgePart")
		flag.Name = "Flag"
		flag.Size = Vector3.new(0.1, 1.2, 1.2)
		flag.CFrame = CFrame.lookAt(point, point + (to - from).Unit) * CFrame.Angles(0, math.rad(90), math.rad(180))
		flag.Color = colors[(index % #colors) + 1]
		flag.Material = Enum.Material.Fabric
		flag.Anchored = true
		decor(flag)
		flag.Parent = lobby
	end
end

local function buildProps(lobby: Model)
	local centerZ = (DECK_NEAR + DECK_FAR) / 2
	-- Lamps at the corners and halfway along the sides.
	for _, x in { -DECK_HALF_X + 2.5, DECK_HALF_X - 2.5 } do
		for _, z in { DECK_NEAR + 2.5, centerZ, DECK_FAR - 2.5 } do
			lamp(lobby, Vector3.new(x, DECK_Y, z))
		end
	end
	-- Benches facing the tank, right behind the clear rail.
	for _, x in { -22, 0, 22 } do
		bench(lobby, Vector3.new(x, DECK_Y, DECK_NEAR + 5), 0)
	end
	umbrellaTable(lobby, Vector3.new(-24, DECK_Y, centerZ + 6), Theme.Color.Red)
	umbrellaTable(lobby, Vector3.new(24, DECK_Y, centerZ + 6), Theme.Color.Sky)
	lounger(lobby, Vector3.new(-33, DECK_Y, centerZ - 6), Theme.Color.Yellow)
	lounger(lobby, Vector3.new(33, DECK_Y, centerZ - 6), Theme.Color.Red)
	shack(lobby)
	pottedPalm(lobby, Vector3.new(-12, DECK_Y, DECK_FAR - 3))
	pottedPalm(lobby, Vector3.new(12, DECK_Y, DECK_FAR - 3))
	-- Crates and barrels stacked in the back corners.
	for _, corner in { -1, 1 } do
		local x = corner * (DECK_HALF_X - 5)
		part("Crate", Vector3.new(3, 3, 3), CFrame.new(x, DECK_Y + 1.5, DECK_FAR - 4), WOOD_LIGHT, Enum.Material.WoodPlanks, lobby)
		part("Crate", Vector3.new(2.4, 2.4, 2.4), CFrame.new(x, DECK_Y + 4.2, DECK_FAR - 4) * CFrame.Angles(0, math.rad(20), 0), WOOD, Enum.Material.WoodPlanks, lobby)
		cylinder("Barrel", 3.2, 2.6, CFrame.new(x - corner * 3.4, DECK_Y + 1.6, DECK_FAR - 3.5), WOOD_DARK, Enum.Material.Wood, lobby)
		cylinder("BarrelBand", 0.3, 2.75, CFrame.new(x - corner * 3.4, DECK_Y + 2.6, DECK_FAR - 3.5), Theme.Color.Ink, Enum.Material.Metal, lobby)
		cylinder("RopeCoil", 0.8, 2.4, CFrame.new(x - corner * 1.5, DECK_Y + 0.4, DECK_FAR - 8), Color3.fromHex("D8C08A"), Enum.Material.Fabric, lobby)
	end
	-- Bunting along the back and the sides.
	local flagY = DECK_Y + 8.6
	bunting(lobby, Vector3.new(-DECK_HALF_X + 2.5, flagY, DECK_FAR - 2.5), Vector3.new(DECK_HALF_X - 2.5, flagY, DECK_FAR - 2.5))
	bunting(lobby, Vector3.new(-DECK_HALF_X + 2.5, flagY, DECK_NEAR + 2.5), Vector3.new(-DECK_HALF_X + 2.5, flagY, centerZ))
	bunting(lobby, Vector3.new(DECK_HALF_X - 2.5, flagY, DECK_NEAR + 2.5), Vector3.new(DECK_HALF_X - 2.5, flagY, centerZ))
end

local function buildLobby(): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	buildDeck(lobby)
	buildRails(lobby)
	buildProps(lobby)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, DECK_Y + 0.5, DECK_NEAR + 18)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby
	return lobby
end

-- Lighting ---------------------------------------------------------------------------------------

-- Late-afternoon sun: warm key light, long soft shadows, a little bloom and sun rays off the water.
local function applyLighting()
	Lighting.Ambient = Color3.fromRGB(110, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 35
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.FogEnd = 100000
	Lighting.FogColor = Color3.fromRGB(190, 225, 255)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	-- Sea haze: thick enough to swallow the edge of the terrain sea, tinted to match the far water.
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.3
	atmosphere.Color = Color3.fromRGB(196, 222, 240)
	atmosphere.Decay = Color3.fromRGB(120, 172, 215)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.8
	atmosphere.Parent = Lighting

	local correction = Lighting:FindFirstChild("KrillionColor") or Instance.new("ColorCorrectionEffect")
	correction.Name = "KrillionColor"
	correction.TintColor = Color3.fromRGB(255, 248, 238)
	correction.Brightness = 0.02
	correction.Saturation = 0.15
	correction.Contrast = 0.12
	correction.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.8
	rays.Parent = Lighting

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
end

-- Build ------------------------------------------------------------------------------------------

local maps = ServerStorage:FindFirstChild("Maps")
if maps == nil then
	maps = Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = ServerStorage
end
assert(maps ~= nil)

-- A lobby already placed in Workspace is replaced in Workspace, so it stays where it was being edited.
local lobbyParent: Instance = maps
local placedLobby = workspace:FindFirstChild("Lobby")
if placedLobby ~= nil then
	lobbyParent = workspace
	placedLobby:Destroy()
end
for _, name in { "Arena", "Lobby" } do
	local old = maps:FindFirstChild(name)
	if old ~= nil then
		old:Destroy()
	end
end

buildTerrain()
buildArena().Parent = maps
buildLobby().Parent = lobbyParent
applyLighting()

print("BuildMap: terrain, Arena and Lobby built")
