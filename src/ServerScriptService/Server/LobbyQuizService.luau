--!strict
-- A personal prompt stream for anyone in the lobby. Accepted answers pay coins by tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local AnswerService = require(script.Parent.AnswerService)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local MIN_SECONDS_BETWEEN_ANSWERS = 1

local current: { [Player]: AnswerService.Prompt? } = {}
local lastAnswerAt: { [Player]: number } = {}
local livePromptId: string? = nil

local LobbyQuizService = {}

local function serve(player: Player)
	local exclude: { [string]: boolean } = {}
	if livePromptId ~= nil then
		exclude[livePromptId] = true
	end
	local previous = current[player]
	if previous ~= nil then
		exclude[previous.id] = true
	end
	local prompt = AnswerService.randomPrompt(exclude)
	current[player] = prompt
	Net.event("LobbyQuizPrompt"):FireClient(player, {
		promptId = prompt.id,
		prompt = prompt.prompt,
		seconds = GameConfig.Lobby.QuizSeconds,
	})
end

local function stop(player: Player)
	current[player] = nil
	Net.event("LobbyQuizPrompt"):FireClient(player, nil)
end

local function onAnswer(player: Player, text: any)
	local prompt = current[player]
	if prompt == nil or PlayerService.isPlaying(player) then
		return
	end
	local now = os.clock()
	if now - (lastAnswerAt[player] or 0) < MIN_SECONDS_BETWEEN_ANSWERS then
		return
	end
	lastAnswerAt[player] = now
	if not AnswerService.isValidText(text) then
		return
	end
	local graded = AnswerService.grade(text, prompt)
	local coins = WaterCurve.lobbyCoins(graded.points)
	if coins > 0 then
		DataService.addCoins(player, coins)
	end
	Net.event("LobbyQuizResult"):FireClient(player, { tier = graded.tier, coins = coins })
	serve(player)
end

local function onSkip(player: Player)
	if current[player] == nil or PlayerService.isPlaying(player) then
		return
	end
	serve(player)
end

function LobbyQuizService.setLivePromptId(id: string?)
	livePromptId = id
end

function LobbyQuizService.start()
	Net.event("LobbyQuizAnswer").OnServerEvent:Connect(onAnswer)
	Net.event("LobbyQuizSkip").OnServerEvent:Connect(onSkip)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("Playing"):Connect(function()
			if PlayerService.isPlaying(player) then
				stop(player)
			else
				serve(player)
			end
		end)
		if not PlayerService.isPlaying(player) then
			serve(player)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
		lastAnswerAt[player] = nil
	end)
end

return LobbyQuizService
