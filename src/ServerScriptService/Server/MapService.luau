--!strict
-- Puts the Studio-built Arena and Lobby into Workspace and spawns per-player platforms.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local arena: Model
local lobby: Model
local platformFolder: Folder
local platforms: { Part } = {}

local MapService = {}

function MapService.start()
	local maps = ServerStorage:WaitForChild("Maps")
	arena = (maps:WaitForChild("Arena") :: Model):Clone()
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

local function platformPosition(index: number, count: number, topY: number): Vector3
	local columns = GameConfig.Platform.Columns
	local rows = math.ceil(count / columns)
	local column = (index - 1) % columns
	local row = math.floor((index - 1) / columns)
	local x = (column - (columns - 1) / 2) * GameConfig.Platform.Spacing
	local z = (row - (rows - 1) / 2) * GameConfig.Platform.Spacing
	return Vector3.new(x, topY - 0.5, z)
end

-- Builds `count` platforms whose top sits at `topY`. Platforms are unanchored and held by constraints so
-- physics carries standing characters when the server moves the AlignPosition target.
function MapService.spawnPlatforms(count: number, topY: number): { Part }
	MapService.clearPlatforms()
	local template = arena:WaitForChild("PlatformTemplate") :: Part
	for index = 1, count do
		local platform = template:Clone()
		platform.Name = "Platform" .. index
		local position = platformPosition(index, count, topY)
		platform.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		platform.Anchored = false
		local rim = platform:FindFirstChild("Rim") :: Part?
		if rim ~= nil then
			rim.Anchored = false
			rim.Massless = true
			rim.CFrame = platform.CFrame * CFrame.new(-0.2, 0, 0)
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
		alignOrientation.CFrame = platform.CFrame.Rotation
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

-- Moves the platform's resting target so its top is at `topY`.
function MapService.setPlatformTop(platform: Part, topY: number)
	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	local current = lift.Position
	lift.Position = Vector3.new(current.X, topY - 0.5, current.Z)
end

function MapService.platformStandCFrame(platform: Part): CFrame
	local lift = platform:FindFirstChild("Lift") :: AlignPosition
	return CFrame.new(lift.Position + Vector3.new(0, 4, 0))
end

return MapService
