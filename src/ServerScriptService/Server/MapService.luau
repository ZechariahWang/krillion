--!strict
-- Finds the Studio-built map placed in Workspace (Arena, Lobby, Mountains) and spawns per-player pillars from
-- ServerStorage.PhysicalAssets.PlatformTemplate (the starting ring; a pillar turns slate and sinks when its player is out).

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local Theme = require(ReplicatedStorage.Config.Theme)

local CAP_HEIGHT = 1

local arena: Model
local lobby: Model
local template: Part
local platformFolder: Folder
local platforms: { Part } = {}
local glideTokens: { [Part]: number } = {}

local MapService = {}

function MapService.start()
	local assets = ServerStorage:WaitForChild("PhysicalAssets")
	template = assets:WaitForChild("PlatformTemplate") :: Part
	arena = workspace:WaitForChild("Arena") :: Model
	lobby = workspace:WaitForChild("Lobby") :: Model
	platformFolder = workspace:WaitForChild("Platforms") :: Folder
end

function MapService.getWater(): Part
	return arena:WaitForChild("Water") :: Part
end

function MapService.getWaterSurface(): Part
	return arena:WaitForChild("WaterSurface") :: Part
end

function MapService.getLobbySpawnCFrame(): CFrame
	local spawn = lobby:WaitForChild("LobbySpawn") :: SpawnLocation
	return spawn.CFrame + Vector3.new(0, 3, 0)
end

-- The pillar's center, given the height of its standing surface (top of the cap).
local function centerY(topY: number): number
	return topY - CAP_HEIGHT - GameConfig.Platform.Height / 2
end

-- Builds one pillar whose standing surface sits at `topY`, centred on (x, z). Pillars are unanchored and
-- held by the template's Lift (AlignPosition) and Upright (AlignOrientation), so physics carries standing
-- characters when the server moves the Lift target. The default colours are kept as attributes so a sunk
-- pillar can be restored after a revive.
local function makePlatform(index: number, x: number, z: number, topY: number): Part
	local platform = template:Clone()
	platform.Name = "Platform" .. index
	local position = Vector3.new(x, centerY(topY), z)
	-- Welds do not carry child parts (cap, walls) while the clone is outside Workspace, so each keeps its
	-- authored offset from the pillar by hand.
	local offsets: { [BasePart]: CFrame } = {}
	for _, child in platform:GetChildren() do
		if child:IsA("BasePart") then
			offsets[child] = platform.CFrame:ToObjectSpace(child.CFrame)
		end
	end
	platform.CFrame = CFrame.new(position)
	platform.Anchored = false
	for child, offset in offsets do
		child.CFrame = platform.CFrame * offset
		child.Anchored = false
	end
	local color = Theme.Pillars[((index - 1) % #Theme.Pillars) + 1]
	platform.Color = color
	platform:SetAttribute("BaseColor", color)
	platform:SetAttribute("BaseMaterial", platform.Material.Name)
	local cap = platform:FindFirstChild("Cap") :: Part?
	if cap ~= nil then
		-- Lighter tint of the pillar colour, so you can tell your pillar apart from above.
		cap.Color = color:Lerp(Theme.Color.White, 0.35)
		cap.Massless = true
		platform:SetAttribute("CapColor", cap.Color)
		platform:SetAttribute("CapMaterial", cap.Material.Name)
	end

	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	lift.Position = position

	platform.Parent = platformFolder
	platform:SetNetworkOwner(nil)
	table.insert(platforms, platform)
	return platform
end

-- Builds `count` pillars on the starting ring (ArenaLayout) with their standing surface at `topY`.
function MapService.spawnPlatforms(count: number, topY: number): { Part }
	MapService.clearPlatforms()
	for index = 1, count do
		local x, z = ArenaLayout.position(index, count)
		makePlatform(index, x, z, topY)
	end
	return table.clone(platforms)
end

-- A sunk pillar turns slate, so the ring shows at a glance who is still in.
function MapService.markSunk(platform: Part)
	platform.Color = Theme.Color.Slate
	local cap = platform:FindFirstChild("Cap") :: BasePart?
	if cap ~= nil then
		cap.Color = Theme.Color.Slate
	end
end

-- Puts back the pillar's own colours after a revive. Skins go on again after this
-- (CosmeticService.applySkin does nothing for a player without a skin, so the defaults must come first).
function MapService.unmarkSunk(platform: Part)
	local color = platform:GetAttribute("BaseColor")
	if typeof(color) == "Color3" then
		platform.Color = color
	end
	local material = platform:GetAttribute("BaseMaterial")
	if type(material) == "string" then
		platform.Material = (Enum.Material :: any)[material]
	end
	local cap = platform:FindFirstChild("Cap") :: BasePart?
	if cap ~= nil then
		local capColor = platform:GetAttribute("CapColor")
		if typeof(capColor) == "Color3" then
			cap.Color = capColor
		end
		local capMaterial = platform:GetAttribute("CapMaterial")
		if type(capMaterial) == "string" then
			cap.Material = (Enum.Material :: any)[capMaterial]
		end
	end
end

-- Marks the pillar sunk and slides it under the water. Does not wait for the slide.
function MapService.sinkPlatform(platform: Part)
	MapService.markSunk(platform)
	task.spawn(MapService.glidePlatformTop, platform, -GameConfig.Crab.SunkDepth, GameConfig.Crab.SinkSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

function MapService.clearPlatforms()
	for _, platform in platforms do
		platform:Destroy()
	end
	platforms = {}
	glideTokens = {}
end

-- Confetti burst from the top of the pillar, bigger for rarer answers.
function MapService.celebrate(platform: Part, points: number)
	local top = platform:FindFirstChild("Top")
	if top == nil then
		return
	end
	local confetti = top:FindFirstChild("Confetti") :: ParticleEmitter?
	if confetti ~= nil then
		confetti:Emit(math.floor(points * 0.8))
	end
end

-- A quick bubble puff from the top of the pillar as it starts to rise.
function MapService.riseBurst(platform: Part)
	local top = platform:FindFirstChild("Top")
	if top == nil then
		return
	end
	local bubbles = top:FindFirstChild("Bubbles") :: ParticleEmitter?
	if bubbles ~= nil then
		bubbles:Emit(24)
	end
end

-- Moves the pillar's target to `topY` along an eased curve, one step per frame, so the pillar glides
-- instead of snapping. A newer glide on the same pillar takes over. Blocks until done.
function MapService.glidePlatformTop(platform: Part, topY: number, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection)
	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	local token = (glideTokens[platform] or 0) + 1
	glideTokens[platform] = token
	local startCenter = lift.Position.Y
	local endCenter = centerY(topY)
	local elapsed = 0
	while elapsed < seconds do
		elapsed += RunService.Heartbeat:Wait()
		if platform.Parent == nil or glideTokens[platform] ~= token then
			return
		end
		local alpha = math.min(1, elapsed / seconds)
		local eased = TweenService:GetValue(alpha, style, direction)
		local current = lift.Position
		lift.Position = Vector3.new(current.X, startCenter + (endCenter - startCenter) * eased, current.Z)
	end
	glideTokens[platform] = nil
end

function MapService.platformStandCFrame(platform: Part): CFrame
	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	local topY = lift.Position.Y + GameConfig.Platform.Height / 2 + CAP_HEIGHT
	local spot = Vector3.new(lift.Position.X, topY + 3, lift.Position.Z)
	local middle = Vector3.new(0, spot.Y, 0)
	-- Facing the middle of the ring, where the crab is.
	if (middle - spot).Magnitude < 0.01 then
		return CFrame.new(spot)
	end
	return CFrame.lookAt(spot, middle)
end

return MapService
