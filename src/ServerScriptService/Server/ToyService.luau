--!strict
-- Lobby throwables (Cosmetics slot Toy). ToyThrow(targetUserId) from a player holding an owned toy throws it
-- at another player in the lobby; every client hears ToyHit and animates the flight, and the target's screen
-- gets a splat. Never on a pillar: neither the thrower nor the target may be in a match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local CosmeticService = require(script.Parent.CosmeticService)
local PlayerService = require(script.Parent.PlayerService)

local lastThrow: { [Player]: number } = {}

local ToyService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onThrow(player: Player, targetUserId: any)
	if typeof(targetUserId) ~= "number" or targetUserId == player.UserId then
		return
	end
	local now = os.clock()
	if now - (lastThrow[player] or -math.huge) < GameConfig.Toys.Cooldown then
		return
	end
	local toy = CosmeticService.equipped(player, "Toy")
	if toy == nil or toy.toy == nil then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil or PlayerService.isPlaying(player) or PlayerService.isPlaying(target) then
		return
	end
	local from = rootOf(player)
	local to = rootOf(target)
	if from == nil or to == nil or (from.Position - to.Position).Magnitude > GameConfig.Toys.Range then
		return
	end
	lastThrow[player] = now
	Net.event("ToyHit"):FireAllClients({ from = player.UserId, to = target.UserId, toy = toy.toy })
end

function ToyService.start()
	Net.event("ToyThrow").OnServerEvent:Connect(onThrow)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return ToyService
