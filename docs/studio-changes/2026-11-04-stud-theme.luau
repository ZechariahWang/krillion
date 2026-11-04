--!strict
-- Stud theme for the lobby deck and the arena reef (W2). Edit-mode Studio script: paste the whole file into
-- the command bar (View > Command Bar) with the place open in Edit mode, never in Play.
--
-- What it does, in place, without moving anything:
-- - Workspace.Lobby deck: planks, sub-floor, trim, rails, stilts, braces, crates and barrels become Plastic
--   bricks with studs on whichever face points up. Planks alternate two tones inside a dark-blue trim ring.
-- - ServerStorage.Maps.Arena: reef rocks, ledge stones, kelp, sea fans, corals and pebbles, the rim and the
--   pillar cap become Plastic with studs. Ball and Cylinder decor becomes Block with the same Size, so the
--   bounding box and height stay the same (balls keep only their yaw so the new cubes sit level).
-- - Brighter, toy-like colours taken from Config/Theme (KEEP_COLOURS = true keeps the current ones).
--
-- Re-runnable: every styled part gets the StudTheme attribute and tag and is skipped next time. The part's
-- original material, colour, shape, surfaces (and the CFrame of levelled balls) are stored as StudOrig* attributes, so MODE = "undo"
-- puts everything back. Positions and Sizes are never written. See docs/studio-changes/README.md.

local MODE: string = "apply" -- "apply" or "undo"
local KEEP_COLOURS = false -- true: change material, shape and studs only
local VERSION = 1 -- bump to re-style parts an older version already touched

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local TAG = "StudTheme"

assert(not RunService:IsRunning(), "stud theme: run this in Edit mode, not during a playtest")

-- Palette. Hex values are Theme tokens where one fits (Theme.Color, Theme.Tier, Theme.Pillars).
local rgb = Color3.fromRGB
local hex = Color3.fromHex
local PLANK_A = rgb(236, 184, 116) -- warm toy tan
local PLANK_B = rgb(214, 150, 90)
local TRIM = rgb(38, 76, 128) -- dark-blue edge ring, as on the old Sink or Niche deck
local INK = hex("1B2A49") -- Theme.Color.Ink: posts, stilts, braces, sub-floor
local RAIL = rgb(240, 246, 250) -- white rails
local TOYS = { hex("FF5A5A"), hex("FFD23F"), hex("2E9BFF"), hex("50E07A") } -- Red, Yellow, Water, Green
local ROCK = { rgb(150, 146, 140), rgb(178, 170, 154), rgb(204, 192, 168) } -- dark to light
local KELP = { rgb(36, 160, 84), hex("3DDC6A"), hex("50E07A"), rgb(140, 220, 70) } -- dark to light
local PEBBLE = { rgb(96, 108, 124), rgb(122, 134, 150), hex("7A8CA0") } -- dark to light, Theme.Color.Grey
-- Coral: each original hue goes to the nearest anchor's new colour.
local CORAL = {
	{ from = hex("BE6EDC"), to = hex("A97BFF") }, -- purple -> Tier.Rare
	{ from = hex("FF786E"), to = hex("FF4D5E") }, -- coral -> Pillars red
	{ from = hex("FFC878"), to = hex("FFD23F") }, -- peach -> Theme yellow
	{ from = hex("6ED2C8"), to = hex("00C2A8") }, -- teal -> Pillars teal
	{ from = hex("FFA05A"), to = hex("FF8C42") }, -- orange -> Pillars orange
}

-- Never styled, whatever their name: gameplay parts WaterFx, WaterService and MapService look up by name,
-- and lobby props. A part is skipped when it or any ancestor below the root has one of these names.
local PROTECTED = {
	Water = true,
	WaterSurface = true,
	NextLevel = true,
	Floor = true,
	GlassWall = true,
	FarSea = true,
	Lift = true,
	Upright = true,
	Anchor = true,
	Top = true,
	NameTag = true,
	Leaderboard = true,
	LobbySpawn = true,
	GlassRail = true,
	RailBlocker = true,
}

type Colour = {
	kind: string, -- "keep" | "solid" | "alternate" | "ramp" | "coral"
	palette: { Color3 }?,
	sortBy: string?, -- alternate: "x" | "z" | "angle"
	tint: number?, -- coral: lerp toward white (Tips are lighter tints of their branch)
}

type Group = {
	root: string, -- "Lobby" | "Arena"
	path: { string }?, -- Model path under the root the parts must sit in; nil = anywhere in the root
	name: string,
	expect: number, -- count in the live place on 2026-11-03 (gap.json inventory)
	studs: string, -- "up" = the most upward face | "broad" = both large faces | "none"
	blockify: boolean?, -- Ball/Cylinder -> Block, same Size
	colour: Colour,
}

local KEEP: Colour = { kind = "keep" }

local GROUPS: { Group } = {
	-- Lobby deck (Workspace.Lobby). Benches, tables, shack, flags, lamps, palms and the Leaderboard stay as they are.
	{ root = "Lobby", name = "Plank", expect = 25, studs = "up", colour = { kind = "alternate", palette = { PLANK_A, PLANK_B }, sortBy = "z" } },
	{ root = "Lobby", name = "SubFloor", expect = 1, studs = "up", colour = { kind = "solid", palette = { INK } } },
	{ root = "Lobby", name = "Trim", expect = 4, studs = "up", colour = { kind = "solid", palette = { TRIM } } },
	{ root = "Lobby", name = "RailPost", expect = 32, studs = "up", colour = { kind = "solid", palette = { INK } } },
	{ root = "Lobby", name = "RailTop", expect = 3, studs = "up", colour = { kind = "solid", palette = { RAIL } } },
	{ root = "Lobby", name = "RailMid", expect = 3, studs = "up", colour = { kind = "solid", palette = { RAIL } } },
	{ root = "Lobby", name = "RailCap", expect = 1, studs = "up", colour = { kind = "solid", palette = { RAIL } } },
	{ root = "Lobby", name = "Brace", expect = 9, studs = "up", colour = { kind = "solid", palette = { INK } } },
	{ root = "Lobby", name = "Crate", expect = 4, studs = "up", colour = { kind = "alternate", palette = TOYS, sortBy = "x" } },
	{ root = "Lobby", name = "Stilt", expect = 12, studs = "up", blockify = true, colour = { kind = "solid", palette = { INK } } },
	-- Barrels keep their round shape: their BarrelBand rings are props and stay round.
	{ root = "Lobby", name = "Barrel", expect = 2, studs = "none", colour = { kind = "solid", palette = { TOYS[1] } } },

	-- Arena (ServerStorage.Maps.Arena). Palms and Mountains are out of scope.
	{ root = "Arena", path = { "Reef", "OuterRim" }, name = "Rock", expect = 56, studs = "up", colour = { kind = "ramp", palette = ROCK } },
	{ root = "Arena", path = { "Reef", "Ledges" }, name = "Stone", expect = 91, studs = "up", blockify = true, colour = { kind = "ramp", palette = ROCK } },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "Kelp", expect = 90, studs = "broad", colour = { kind = "ramp", palette = KELP } },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "SeaFan", expect = 26, studs = "broad", colour = { kind = "coral" } },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "FanStem", expect = 26, studs = "up", colour = KEEP },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "BrainCoral", expect = 30, studs = "up", blockify = true, colour = { kind = "coral" } },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "Branch", expect = 92, studs = "up", blockify = true, colour = { kind = "coral" } },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "Tip", expect = 92, studs = "up", blockify = true, colour = { kind = "coral", tint = 0.35 } },
	{ root = "Arena", path = { "Reef", "Coral" }, name = "Pebble", expect = 10, studs = "up", blockify = true, colour = { kind = "ramp", palette = PEBBLE } },
	{ root = "Arena", name = "RimSegment", expect = 40, studs = "up", colour = { kind = "alternate", palette = { PLANK_A, PLANK_B }, sortBy = "angle" } },
	-- MapService recolours the cap per player and CosmeticService sets skin materials, so only studs here.
	{ root = "Arena", path = { "PlatformTemplate" }, name = "Cap", expect = 1, studs = "up", colour = KEEP },
}

----------------------------------------------------------------------------------------------------
-- Faces

local FACES = {
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Front,
	Enum.NormalId.Back,
}

local OPPOSITE: { [string]: Enum.NormalId } = {
	Top = Enum.NormalId.Bottom,
	Bottom = Enum.NormalId.Top,
	Left = Enum.NormalId.Right,
	Right = Enum.NormalId.Left,
	Front = Enum.NormalId.Back,
	Back = Enum.NormalId.Front,
}

local function getSurface(part: BasePart, face: Enum.NormalId): Enum.SurfaceType
	if face == Enum.NormalId.Top then
		return part.TopSurface
	elseif face == Enum.NormalId.Bottom then
		return part.BottomSurface
	elseif face == Enum.NormalId.Left then
		return part.LeftSurface
	elseif face == Enum.NormalId.Right then
		return part.RightSurface
	elseif face == Enum.NormalId.Front then
		return part.FrontSurface
	end
	return part.BackSurface
end

local function setSurface(part: BasePart, face: Enum.NormalId, surface: Enum.SurfaceType)
	if face == Enum.NormalId.Top then
		part.TopSurface = surface
	elseif face == Enum.NormalId.Bottom then
		part.BottomSurface = surface
	elseif face == Enum.NormalId.Left then
		part.LeftSurface = surface
	elseif face == Enum.NormalId.Right then
		part.RightSurface = surface
	elseif face == Enum.NormalId.Front then
		part.FrontSurface = surface
	else
		part.BackSurface = surface
	end
end

-- Many reef rocks and kelp are tilted, so "top" is whichever face points most upward in world space.
local function upFace(part: BasePart): Enum.NormalId
	local best, bestY = Enum.NormalId.Top, -math.huge
	for _, face in FACES do
		local y = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)).Y
		if y > bestY then
			best, bestY = face, y
		end
	end
	return best
end

-- The two large faces of a thin slab (sea fans and kelp blades stand on edge).
local function broadFace(part: BasePart): Enum.NormalId
	local size = part.Size
	if size.X <= size.Y and size.X <= size.Z then
		return Enum.NormalId.Left
	elseif size.Z <= size.Y then
		return Enum.NormalId.Front
	end
	return Enum.NormalId.Top
end

local function applyStuds(part: BasePart, mode: string)
	for _, face in FACES do
		setSurface(part, face, Enum.SurfaceType.Smooth)
	end
	if mode == "up" then
		local face = upFace(part)
		setSurface(part, face, Enum.SurfaceType.Studs)
		setSurface(part, OPPOSITE[face.Name], Enum.SurfaceType.Inlet)
	elseif mode == "broad" then
		local face = broadFace(part)
		setSurface(part, face, Enum.SurfaceType.Studs)
		setSurface(part, OPPOSITE[face.Name], Enum.SurfaceType.Studs)
	end
end

----------------------------------------------------------------------------------------------------
-- Colours

local function luma(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function hueDistance(a: number, b: number): number
	local d = math.abs(a - b)
	return math.min(d, 1 - d)
end

local function originalColour(part: BasePart): Color3
	local stored = part:GetAttribute("StudOrigColor")
	if typeof(stored) == "Color3" then
		return stored
	end
	return part.Color
end

local function coralColour(original: Color3, tint: number?): Color3
	local h, s = original:ToHSV()
	if s < 0.12 then
		return original -- a grey or white piece: leave it
	end
	local best, bestD = CORAL[1].to, math.huge
	for _, anchor in CORAL do
		local ah = anchor.from:ToHSV()
		local d = hueDistance(h, ah)
		if d < bestD then
			best, bestD = anchor.to, d
		end
	end
	if tint ~= nil then
		return best:Lerp(Color3.new(1, 1, 1), tint)
	end
	return best
end

local function sortKey(part: BasePart, sortBy: string?): number
	local p = part.CFrame.Position
	if sortBy == "x" then
		return p.X
	elseif sortBy == "angle" then
		return math.atan2(p.Z, p.X)
	end
	return p.Z
end

-- Returns the new colour for every part of a group, or nil where the colour stays.
local function planColours(parts: { BasePart }, colour: Colour): { [BasePart]: Color3 }
	local out: { [BasePart]: Color3 } = {}
	local palette = colour.palette
	if KEEP_COLOURS or colour.kind == "keep" then
		return out
	elseif colour.kind == "solid" and palette then
		for _, part in parts do
			out[part] = palette[1]
		end
	elseif colour.kind == "alternate" and palette then
		local sorted = table.clone(parts)
		table.sort(sorted, function(a, b)
			return sortKey(a, colour.sortBy) < sortKey(b, colour.sortBy)
		end)
		for i, part in sorted do
			out[part] = palette[(i - 1) % #palette + 1]
		end
	elseif colour.kind == "ramp" and palette then
		-- Keep each part's light/dark rank from its original colour, on the brighter ramp.
		local lo, hi = math.huge, -math.huge
		for _, part in parts do
			local l = luma(originalColour(part))
			lo, hi = math.min(lo, l), math.max(hi, l)
		end
		for _, part in parts do
			local t = if hi > lo then (luma(originalColour(part)) - lo) / (hi - lo) else 0.5
			out[part] = palette[math.clamp(math.floor(t * #palette) + 1, 1, #palette)]
		end
	elseif colour.kind == "coral" then
		for _, part in parts do
			out[part] = coralColour(originalColour(part), colour.tint)
		end
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- Finding parts

local function isProtected(part: Instance, root: Instance): boolean
	local node: Instance? = part
	while node ~= nil and node ~= root do
		if PROTECTED[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

local function resolve(root: Instance, path: { string }?): Instance?
	local node: Instance? = root
	for _, name in path or {} do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function collect(root: Instance, group: Group): { BasePart }
	local container = resolve(root, group.path)
	local found: { BasePart } = {}
	if container == nil then
		return found
	end
	for _, inst in container:GetDescendants() do
		if inst.Name == group.name and inst:IsA("BasePart") and not isProtected(inst, root) then
			table.insert(found, inst)
		end
	end
	return found
end

----------------------------------------------------------------------------------------------------
-- Apply and undo

local function surfacesString(part: BasePart): string
	local names = {}
	for _, face in FACES do
		table.insert(names, getSurface(part, face).Name)
	end
	return table.concat(names, ",")
end

-- First run only: later runs (VERSION bumps) must not overwrite the true originals with styled values.
local function rememberOriginal(part: BasePart)
	if part:GetAttribute("StudOrigMaterial") ~= nil then
		return
	end
	part:SetAttribute("StudOrigMaterial", part.Material.Name)
	part:SetAttribute("StudOrigColor", part.Color)
	part:SetAttribute("StudOrigSurfaces", surfacesString(part))
	if part:IsA("Part") then
		part:SetAttribute("StudOrigShape", part.Shape.Name)
	end
end

local function styleGroup(part: BasePart, group: Group, colour: Color3?)
	rememberOriginal(part)
	if group.blockify and part:IsA("Part") and part.Shape ~= Enum.PartType.Block then
		local wasBall = part.Shape == Enum.PartType.Ball
		local size = part.Size
		part.Shape = Enum.PartType.Block
		part.Size = size -- same bounding box and height
		if wasBall then
			-- A ball's tilt was invisible; as a cube it would show, so keep only the yaw. Position is unchanged.
			if part:GetAttribute("StudOrigCFrame") == nil then
				part:SetAttribute("StudOrigCFrame", part.CFrame)
			end
			local _, yaw, _ = part.CFrame:ToEulerAnglesYXZ()
			part.CFrame = CFrame.new(part.CFrame.Position) * CFrame.Angles(0, yaw, 0)
		end
	end
	part.Material = Enum.Material.Plastic -- studs only render on Plastic
	if colour ~= nil then
		part.Color = colour
	end
	applyStuds(part, group.studs)
	part:SetAttribute(TAG, VERSION)
	CollectionService:AddTag(part, TAG)
end

local function restore(part: BasePart): boolean
	local material = part:GetAttribute("StudOrigMaterial")
	if typeof(material) ~= "string" then
		return false
	end
	local shape = part:GetAttribute("StudOrigShape")
	if typeof(shape) == "string" and part:IsA("Part") then
		local size = part.Size
		part.Shape = (Enum.PartType :: any)[shape]
		part.Size = size
	end
	local cf = part:GetAttribute("StudOrigCFrame")
	if typeof(cf) == "CFrame" then
		part.CFrame = cf
	end
	part.Material = (Enum.Material :: any)[material]
	local color = part:GetAttribute("StudOrigColor")
	if typeof(color) == "Color3" then
		part.Color = color
	end
	local surfaces = part:GetAttribute("StudOrigSurfaces")
	if typeof(surfaces) == "string" then
		for i, name in string.split(surfaces, ",") do
			local face = FACES[i]
			if face ~= nil then
				setSurface(part, face, (Enum.SurfaceType :: any)[name])
			end
		end
	end
	for _, key in { "StudOrigMaterial", "StudOrigColor", "StudOrigSurfaces", "StudOrigCFrame", "StudOrigShape", TAG } do
		part:SetAttribute(key, nil)
	end
	CollectionService:RemoveTag(part, TAG)
	return true
end

----------------------------------------------------------------------------------------------------
-- Run

local maps = ServerStorage:FindFirstChild("Maps")
local roots: { [string]: Instance? } = {
	Lobby = workspace:FindFirstChild("Lobby"),
	Arena = maps and maps:FindFirstChild("Arena"),
}
assert(roots.Lobby, "stud theme: Workspace.Lobby is missing")
assert(roots.Arena, "stud theme: ServerStorage.Maps.Arena is missing")
if workspace:FindFirstChild("Arena") then
	warn("stud theme: there is a Workspace.Arena (left over from a playtest?). Only ServerStorage.Maps.Arena is styled.")
end

-- Gameplay parts the client and server find by name; checked before and after.
local arenaRoot = roots.Arena :: Instance
local REQUIRED = { "Water", "WaterSurface", "NextLevel", "PlatformTemplate" }
for _, name in REQUIRED do
	assert(arenaRoot:FindFirstChild(name), "stud theme: Arena." .. name .. " is missing; stopping before any change")
end

local recording: string? = nil
do
	local ok, id = pcall(function()
		return ChangeHistoryService:TryBeginRecording("StudTheme", "Stud theme " .. MODE)
	end)
	if ok then
		recording = id
	end
end

local lines: { string } = {}
local styled, skipped, restored = 0, 0, 0

if MODE == "undo" then
	for rootName, root in roots do
		local count = 0
		for _, inst in (root :: Instance):GetDescendants() do
			if inst:IsA("BasePart") and inst:GetAttribute(TAG) ~= nil and restore(inst) then
				count += 1
			end
		end
		restored += count
		table.insert(lines, string.format("  %-6s restored %d parts", rootName, count))
		task.wait()
	end
else
	for _, group in GROUPS do
		local root = roots[group.root] :: Instance
		local parts = collect(root, group)
		local todo: { BasePart } = {}
		for _, part in parts do
			if part:GetAttribute(TAG) == VERSION then
				skipped += 1
			else
				table.insert(todo, part)
			end
		end
		local colours = planColours(todo, group.colour)
		for _, part in todo do
			styleGroup(part, group, colours[part])
		end
		styled += #todo
		local where = group.root .. (if group.path then "." .. table.concat(group.path, ".") else "")
		local note = if #parts ~= group.expect then string.format("  <-- expected %d", group.expect) else ""
		table.insert(
			lines,
			string.format("  %-28s %-10s found %3d, styled %3d, already done %3d%s", where, group.name, #parts, #todo, #parts - #todo, note)
		)
		if #parts ~= group.expect then
			warn(string.format("stud theme: %s.%s found %d, expected %d", where, group.name, #parts, group.expect))
		end
		task.wait() -- let Studio breathe between groups
	end
end

for _, name in REQUIRED do
	if not arenaRoot:FindFirstChild(name) then
		warn("stud theme: Arena." .. name .. " is missing after the run")
	end
end

if recording ~= nil then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

local header = if MODE == "undo"
	then string.format("Stud theme v%d undo: %d parts restored", VERSION, restored)
	else string.format(
		"Stud theme v%d: %d parts styled, %d already done%s",
		VERSION,
		styled,
		skipped,
		if KEEP_COLOURS then " (colours kept)" else ""
	)
print(header .. "\n" .. table.concat(lines, "\n"))
print("Not saved yet: look it over in Edit mode, then save. Publish only from merged main, with Kevin's or Zechariah's go-ahead.")
