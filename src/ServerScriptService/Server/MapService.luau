--!strict
-- Puts the Studio-built Arena and Lobby into Workspace and spawns per-player pillars.

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
	local maps = ServerStorage:WaitForChild("Maps")
	arena = (maps:WaitForChild("Arena") :: Model):Clone()
	template = arena:WaitForChild("PlatformTemplate") :: Part
	template.Parent = nil
	arena.Parent = workspace
	-- A lobby already placed in Workspace (being edited in Studio) is used as-is; otherwise clone the stored one.
	local placed = workspace:FindFirstChild("Lobby")
	if placed ~= nil and placed:IsA("Model") then
		lobby = placed
	else
		lobby = (maps:WaitForChild("Lobby") :: Model):Clone()
		lobby.Parent = workspace
	end
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

local function platformPosition(index: number, count: number, topY: number): Vector3
	local x, z = ArenaLayout.position(index, count)
	return Vector3.new(x, centerY(topY), z)
end

-- Builds `count` pillars whose standing surface sits at `topY`. Pillars are unanchored and held by the
-- template's Lift (AlignPosition) and Upright (AlignOrientation), so physics carries standing characters
-- when the server moves the Lift target.
function MapService.spawnPlatforms(count: number, topY: number): { Part }
	MapService.clearPlatforms()
	for index = 1, count do
		local platform = template:Clone()
		platform.Name = "Platform" .. index
		local position = platformPosition(index, count, topY)
		platform.CFrame = CFrame.new(position)
		platform.Anchored = false
		local color = Theme.Pillars[((index - 1) % #Theme.Pillars) + 1]
		platform.Color = color
		local cap = platform:FindFirstChild("Cap") :: Part?
		if cap ~= nil then
			-- Lighter tint of the pillar colour, so you can tell your pillar apart from above.
			cap.Color = color:Lerp(Theme.Color.White, 0.35)
			cap.Anchored = false
			cap.Massless = true
			cap.CFrame = platform.CFrame * CFrame.new(0, GameConfig.Platform.Height / 2 + CAP_HEIGHT / 2, 0)
		end

		local lift = platform:FindFirstChild("Lift") :: AlignPosition
		lift.Position = position

		platform.Parent = platformFolder
		platform:SetNetworkOwner(nil)
		table.insert(platforms, platform)
	end
	return platforms
end

function MapService.clearPlatforms()
	for _, platform in platforms do
		platform:Destroy()
	end
	platforms = {}
	glideTokens = {}
end

function MapService.setPlatformName(platform: Part, name: string)
	local tag = platform:FindFirstChild("NameTag")
	if tag == nil then
		return
	end
	local text = tag:FindFirstChild("NameText") :: TextLabel?
	if text ~= nil then
		text.Text = name
	end
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
	return CFrame.new(lift.Position.X, topY + 3, lift.Position.Z)
end

return MapService
