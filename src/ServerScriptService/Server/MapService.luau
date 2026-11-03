--!strict
-- Puts the Studio-built Arena and Lobby into Workspace, spawns per-player pillars, drives the lobby scoreboard.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)

local CAP_HEIGHT = 1

local arena: Model
local lobby: Model
local template: Part
local platformFolder: Folder
local platforms: { Part } = {}

local MapService = {}

function MapService.start()
	local maps = ServerStorage:WaitForChild("Maps")
	arena = (maps:WaitForChild("Arena") :: Model):Clone()
	template = arena:WaitForChild("PlatformTemplate") :: Part
	template.Parent = nil
	arena.Parent = workspace
	lobby = (maps:WaitForChild("Lobby") :: Model):Clone()
	lobby.Parent = workspace
	platformFolder = Instance.new("Folder")
	platformFolder.Name = "Platforms"
	platformFolder.Parent = workspace
end

function MapService.getWater(): Part
	return arena:WaitForChild("Water") :: Part
end

function MapService.getFoam(): Part
	return arena:WaitForChild("Foam") :: Part
end

function MapService.getLobbySpawnCFrame(): CFrame
	local spawn = lobby:WaitForChild("LobbySpawn") :: SpawnLocation
	return spawn.CFrame + Vector3.new(0, 3, 0)
end

function MapService.setScoreboard(title: string, body: string)
	local board = lobby:FindFirstChild("Scoreboard")
	if board == nil then
		return
	end
	local content = board:FindFirstChild("Content", true)
	if content == nil then
		return
	end
	local titleLabel = content:FindFirstChild("Title") :: TextLabel?
	local bodyLabel = content:FindFirstChild("Body") :: TextLabel?
	if titleLabel ~= nil then
		titleLabel.Text = title
	end
	if bodyLabel ~= nil then
		bodyLabel.Text = body
	end
end

-- The pillar's center, given the height of its standing surface (top of the cap).
local function centerY(topY: number): number
	return topY - CAP_HEIGHT - GameConfig.Platform.Height / 2
end

local function platformPosition(index: number, count: number, topY: number): Vector3
	local columns = GameConfig.Platform.Columns
	local rows = math.ceil(count / columns)
	local column = (index - 1) % columns
	local row = math.floor((index - 1) / columns)
	local x = (column - (columns - 1) / 2) * GameConfig.Platform.Spacing
	local z = (row - (rows - 1) / 2) * GameConfig.Platform.Spacing
	return Vector3.new(x, centerY(topY), z)
end

-- Builds `count` pillars whose standing surface sits at `topY`. Pillars are unanchored and held by constraints
-- so physics carries standing characters when the server moves the AlignPosition target.
function MapService.spawnPlatforms(count: number, topY: number): { Part }
	MapService.clearPlatforms()
	for index = 1, count do
		local platform = template:Clone()
		platform.Name = "Platform" .. index
		local position = platformPosition(index, count, topY)
		platform.CFrame = CFrame.new(position)
		platform.Anchored = false
		platform.Color = Theme.Pillars[((index - 1) % #Theme.Pillars) + 1]
		local cap = platform:FindFirstChild("Cap") :: Part?
		if cap ~= nil then
			cap.Anchored = false
			cap.Massless = true
			cap.CFrame = platform.CFrame * CFrame.new(0, GameConfig.Platform.Height / 2 + CAP_HEIGHT / 2, 0)
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "Anchor"
		attachment.Parent = platform

		local alignPosition = Instance.new("AlignPosition")
		alignPosition.Name = "Lift"
		alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPosition.Attachment0 = attachment
		alignPosition.Position = position
		alignPosition.MaxForce = math.huge
		alignPosition.MaxVelocity = math.huge
		alignPosition.Responsiveness = 40
		alignPosition.Parent = platform

		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = attachment
		alignOrientation.CFrame = CFrame.identity
		alignOrientation.RigidityEnabled = true
		alignOrientation.Parent = platform

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

-- Moves the pillar's resting target so its standing surface is at `topY`.
function MapService.setPlatformTop(platform: Part, topY: number)
	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	local current = lift.Position
	lift.Position = Vector3.new(current.X, centerY(topY), current.Z)
end

function MapService.platformStandCFrame(platform: Part): CFrame
	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	local topY = lift.Position.Y + GameConfig.Platform.Height / 2 + CAP_HEIGHT
	return CFrame.new(lift.Position.X, topY + 3, lift.Position.Z)
end

return MapService
