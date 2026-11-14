--!strict
-- Throwables (Cosmetics slot Toy). ToyThrow(targetId) from a player in the lobby holding an owned toy throws
-- it at another lobby player nearby, or at whoever they are spectating on a pillar (a player or a bot, at any
-- distance). Every client hears ToyHit and draws the flight and a splat in the world; nothing is ever put
-- on the target's screen. A player in a match cannot throw.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local BotService = require(script.Parent.BotService)
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
	local from = rootOf(player)
	if from == nil or PlayerService.isPlaying(player) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target ~= nil then
		local to = rootOf(target)
		if to == nil then
			return
		end
		-- Two lobby players must be near each other; a player on a pillar is thrown at by whoever watches them.
		if not PlayerService.isPlaying(target) and (from.Position - to.Position).Magnitude > GameConfig.Toys.Range then
			return
		end
	elseif not BotService.isBot(targetUserId) then
		return
	end
	lastThrow[player] = now
	Net.event("ToyHit"):FireAllClients({ from = player.UserId, to = targetUserId, toy = toy.toy })
end

function ToyService.start()
	Net.event("ToyThrow").OnServerEvent:Connect(onThrow)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return ToyService
