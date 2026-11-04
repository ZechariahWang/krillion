--!strict
-- Where each player is: lobby or on a platform. The "Playing" attribute is read by clients and LobbyQuizService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local MapService = require(script.Parent.MapService)

local PlayerService = {}

local function pivotCharacter(player: Player, cframe: CFrame)
	local character = player.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cframe)
end

function PlayerService.start()
	local function onCharacter(player: Player, character: Model)
		-- Respawns always land in the lobby; RoundService eliminates anyone who was mid-match.
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root ~= nil then
			character:PivotTo(MapService.getLobbySpawnCFrame())
		end
	end
	local function onPlayer(player: Player)
		player:SetAttribute("Playing", false)
		if player.Character ~= nil then
			onCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

function PlayerService.isPlaying(player: Player): boolean
	return player:GetAttribute("Playing") == true
end

function PlayerService.hasCharacter(player: Player): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	return character:FindFirstChild("HumanoidRootPart") ~= nil
end

-- On a pillar you can stroll around its top (invisible walls from MapService hold you on) but not jump,
-- so nobody falls off by accident or hops onto a neighbour's pillar.
local function setMovement(player: Player, onPillar: boolean)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	if onPillar then
		humanoid.WalkSpeed = GameConfig.Platform.WalkSpeed
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
	end
end

function PlayerService.sendToPlatform(player: Player, platform: Part)
	player:SetAttribute("Playing", true)
	setMovement(player, true)
	pivotCharacter(player, MapService.platformStandCFrame(platform))
end

function PlayerService.sendToLobby(player: Player)
	player:SetAttribute("Playing", false)
	setMovement(player, false)
	pivotCharacter(player, MapService.getLobbySpawnCFrame())
end

return PlayerService
