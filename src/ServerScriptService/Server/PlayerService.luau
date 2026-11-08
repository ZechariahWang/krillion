--!strict
-- Where each player is: lobby or on a platform. The "Playing" attribute is read by clients and LobbyQuizService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local MapService = require(script.Parent.MapService)

local PlayerService = {}

local HOLD_TIMEOUT = 3 -- most seconds to wait for the destination to stream in before letting go anyway
local SETTLE_SECONDS = 0.25 -- extra beat after streaming, so the client has the pillar under its feet

local holdTokens: { [Player]: number } = {}

-- Moves the character with its root anchored, then lets go once the destination has streamed in to the
-- player. A freshly spawned pillar can otherwise be missing on the client (which simulates its own
-- character), so the character fell through it or slid off at its old speed.
local function placeAndHold(player: Player, cframe: CFrame)
	local character = player.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local token = (holdTokens[player] or 0) + 1
	holdTokens[player] = token
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = cframe
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position, HOLD_TIMEOUT)
		end)
		task.wait(SETTLE_SECONDS)
		if holdTokens[player] ~= token or root.Parent == nil then
			return
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end)
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
	Players.PlayerRemoving:Connect(function(player)
		holdTokens[player] = nil
	end)
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
	placeAndHold(player, MapService.platformStandCFrame(platform))
end

function PlayerService.sendToLobby(player: Player)
	player:SetAttribute("Playing", false)
	setMovement(player, false)
	placeAndHold(player, MapService.getLobbySpawnCFrame())
end

return PlayerService
