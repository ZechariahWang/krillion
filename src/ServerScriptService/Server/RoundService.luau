--!strict
-- The match state machine: Waiting -> Intermission -> (Prompt -> Reveal -> Surge)* -> Results -> ...

local MatchmakingService = game:GetService("MatchmakingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
local AnswerService = require(script.Parent.AnswerService)
local LobbyQuizService = require(script.Parent.LobbyQuizService)
local MapService = require(script.Parent.MapService)
local PlayerService = require(script.Parent.PlayerService)
local WaterService = require(script.Parent.WaterService)

local phase = "Waiting"
local round = 0
local secondsLeft = 0
local currentPrompt: AnswerService.Prompt? = nil
local match: MatchState.State? = nil
local platforms: { [Player]: Part } = {}
local usedPromptIds: { [string]: boolean } = {}
local participantCount = 0

local RoundService = {}

local function setServerAttributes()
	pcall(function()
		MatchmakingService:SetServerAttribute("Phase", phase)
		MatchmakingService:SetServerAttribute("AliveCount", RoundService.aliveCount())
	end)
end

local function alivePlayers(): { Player }
	local result = {}
	if match == nil then
		return result
	end
	for _, player in Players:GetPlayers() do
		if match.alive[player] then
			table.insert(result, player)
		end
	end
	return result
end

-- A solo match (empty server) runs until the lone player sinks instead of ending at once.
local function matchOver(): boolean
	local alive = RoundService.aliveCount()
	if participantCount > 1 then
		return alive <= 1
	end
	return alive == 0
end

function RoundService.aliveCount(): number
	if match == nil then
		return 0
	end
	return MatchState.aliveCount(match)
end

local lastWinnerName = ""

local function updateScoreboard()
	local alive = RoundService.aliveCount()
	if phase == "Waiting" then
		MapService.setScoreboard("WAITING FOR PLAYERS", #Players:GetPlayers() .. " / " .. GameConfig.Round.MinPlayers)
	elseif phase == "Intermission" then
		MapService.setScoreboard("NEXT DIVE IN", tostring(secondsLeft))
	elseif phase == "Prompt" and currentPrompt ~= nil then
		MapService.setScoreboard("ROUND " .. round .. "  |  " .. alive .. " ALIVE  |  " .. secondsLeft, currentPrompt.prompt)
	elseif phase == "Reveal" then
		MapService.setScoreboard("ROUND " .. round .. "  |  " .. alive .. " ALIVE", "THE PILLARS RISE!")
	elseif phase == "Surge" then
		MapService.setScoreboard("ROUND " .. round .. "  |  " .. alive .. " ALIVE", "THE WATER IS RISING!")
	elseif phase == "Results" then
		MapService.setScoreboard("WINNER", lastWinnerName)
	end
end

local function broadcastState()
	updateScoreboard()
	local aliveUserIds = {}
	for _, player in alivePlayers() do
		table.insert(aliveUserIds, player.UserId)
	end
	local promptText = nil
	local promptId = nil
	if currentPrompt ~= nil then
		promptText = currentPrompt.prompt
		promptId = currentPrompt.id
	end
	local waterY = 0
	if match ~= nil then
		waterY = match.waterY
	end
	for _, player in Players:GetPlayers() do
		local height = 0
		if match ~= nil and match.heights[player] ~= nil then
			height = match.heights[player]
		end
		Net.event("RoundState"):FireClient(player, {
			phase = phase,
			round = round,
			secondsLeft = secondsLeft,
			alive = #aliveUserIds,
			aliveUserIds = aliveUserIds,
			prompt = promptText,
			promptId = promptId,
			playing = match ~= nil and match.alive[player] == true,
			height = height,
			waterY = waterY,
			playerCount = #Players:GetPlayers(),
			starting = participantCount,
			minPlayers = GameConfig.Round.MinPlayers,
		})
	end
end

local function setPhase(newPhase: string)
	phase = newPhase
	broadcastState()
	setServerAttributes()
end

-- Counts down one second at a time, broadcasting each tick. Stops early when `shouldStop` says so.
local function countdown(seconds: number, shouldStop: (() -> boolean)?)
	secondsLeft = seconds
	broadcastState()
	while secondsLeft > 0 do
		task.wait(1)
		secondsLeft -= 1
		if shouldStop ~= nil and shouldStop() then
			return
		end
		broadcastState()
	end
end

local function sinkPlayer(player: Player)
	platforms[player] = nil
	PlayerService.sendToLobby(player)
	Net.event("Eliminated"):FireClient(player, { round = round })
	setServerAttributes()
end

-- Used by the water poll: a player fell in or lost their character mid-round.
local function eliminate(player: Player)
	if match == nil or not match.alive[player] then
		return
	end
	MatchState.eliminate(match, player)
	sinkPlayer(player)
end

local function readyPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if PlayerService.hasCharacter(player) then
			table.insert(result, player)
		end
	end
	return result
end

local function waitForPlayers()
	setPhase("Waiting")
	while #readyPlayers() < GameConfig.Round.MinPlayers do
		task.wait(1)
		broadcastState()
	end
end

local function startMatch()
	local participants = readyPlayers()
	participantCount = #participants
	local state = MatchState.new(GameConfig.Water.StartHeight)
	match = state
	round = 0
	usedPromptIds = {}
	platforms = {}
	WaterService.reset()
	local parts = MapService.spawnPlatforms(#participants, GameConfig.Water.StartHeight)
	for index, player in participants do
		MatchState.addPlayer(state, player)
		platforms[player] = parts[index]
		MapService.setPlatformName(parts[index], player.DisplayName)
		PlayerService.sendToPlatform(player, parts[index])
	end
end

-- Stage one lifts most of the way, a hold, then a snap with a small overshoot that settles.
local function risePlatform(player: Player, fromTop: number, toTop: number, points: number)
	local platform = platforms[player]
	if platform == nil or platform.Parent == nil then
		return
	end
	local stageTop = fromTop + (toTop - fromTop) * GameConfig.Platform.RiseStageFraction
	MapService.setPlatformTop(platform, stageTop)
	task.wait(GameConfig.Platform.RiseStageSeconds + GameConfig.Platform.RiseHoldSeconds)
	if platform.Parent == nil then
		return
	end
	MapService.setPlatformTop(platform, toTop + 0.6)
	if points >= GameConfig.Platform.ConfettiMinPoints then
		MapService.celebrate(platform, points)
	end
	task.wait(GameConfig.Platform.RiseSnapSeconds * 0.6)
	if platform.Parent == nil then
		return
	end
	MapService.setPlatformTop(platform, toTop)
end

local function runPrompt()
	round += 1
	local prompt = AnswerService.randomPrompt(usedPromptIds)
	usedPromptIds[prompt.id] = true
	currentPrompt = prompt
	LobbyQuizService.setLivePromptId(prompt.id)
	AnswerService.openRound(prompt, alivePlayers())
	local seconds = WaterCurve.promptSeconds(round)
	-- Set before the phase change so clients start their timer from the right number, not the last countdown's 0.
	secondsLeft = seconds
	setPhase("Prompt")
	countdown(seconds, matchOver)
	return AnswerService.closeRound()
end

local function runReveal(submissions: { [Player]: AnswerService.Submission })
	local state = match :: MatchState.State
	local rows = {}
	for _, player in alivePlayers() do
		local submission = submissions[player]
		local points = 0
		local tier = nil
		local shownAnswer = nil
		if submission ~= nil then
			points = submission.points
			tier = submission.tier
			-- Accepted answers are shown in the bank's spelling, which is our own text, so it needs no chat filter.
			shownAnswer = submission.corrected
		end
		local lift = WaterCurve.lift(points)
		local fromTop = state.heights[player]
		MatchState.applyLift(state, player, points, lift)
		table.insert(rows, {
			userId = player.UserId,
			name = player.DisplayName,
			answer = shownAnswer,
			tier = tier,
			points = points,
			lift = lift,
			height = state.heights[player],
		})
		if lift > 0 then
			task.spawn(risePlatform, player, fromTop, state.heights[player], points)
		end
	end
	currentPrompt = nil
	LobbyQuizService.setLivePromptId(nil)
	setPhase("Reveal")
	Net.event("Reveal"):FireAllClients({ round = round, rows = rows })
	task.wait(GameConfig.Round.RevealSeconds)
end

local function runSurge()
	local state = match :: MatchState.State
	setPhase("Surge")
	MatchState.surge(state, WaterCurve.surge(round))
	WaterService.surgeTo(state.waterY)
	local culled = MatchState.cull(state)
	for _, player in culled do
		sinkPlayer(player)
	end
	broadcastState()
end

local function podium(state: MatchState.State, winner: Player?): { { name: string, points: number } }
	local players = {}
	for _, player in Players:GetPlayers() do
		if state.points[player] ~= nil and player ~= winner then
			table.insert(players, player)
		end
	end
	table.sort(players, function(a, b)
		return state.points[a] > state.points[b]
	end)
	if winner ~= nil then
		table.insert(players, 1, winner)
	end
	local top = {}
	for index = 1, math.min(3, #players) do
		local player = players[index]
		table.insert(top, { name = player.DisplayName, points = state.points[player] or 0 })
	end
	return top
end

local function endMatch()
	local state = match :: MatchState.State
	local winner: Player? = nil
	local found = MatchState.winner(state)
	if found ~= nil and typeof(found) == "Instance" then
		winner = found :: Player
	end
	local winnerName = "Nobody"
	if winner ~= nil then
		winnerName = winner.DisplayName
	end
	local top = podium(state, winner)
	lastWinnerName = winnerName
	for _, player in alivePlayers() do
		MatchState.eliminate(state, player)
		PlayerService.sendToLobby(player)
	end
	MapService.clearPlatforms()
	platforms = {}
	match = nil
	secondsLeft = GameConfig.Round.ResultsSeconds
	setPhase("Results")
	Net.event("MatchEnded"):FireAllClients({
		solo = participantCount == 1,
		rounds = round,
		winnerName = winnerName,
		podium = top,
		seconds = GameConfig.Round.ResultsSeconds,
	})
	countdown(GameConfig.Round.ResultsSeconds)
end

local function runMatch()
	startMatch()
	while true do
		local submissions = runPrompt()
		if matchOver() then
			break
		end
		runReveal(submissions)
		runSurge()
		if matchOver() then
			break
		end
		if GameConfig.Round.MaxRounds > 0 and round >= GameConfig.Round.MaxRounds then
			break
		end
	end
	endMatch()
end

local function mainLoop()
	while true do
		waitForPlayers()
		secondsLeft = GameConfig.Round.IntermissionSeconds
		setPhase("Intermission")
		countdown(GameConfig.Round.IntermissionSeconds, function()
			return #readyPlayers() < GameConfig.Round.MinPlayers
		end)
		if #readyPlayers() >= GameConfig.Round.MinPlayers then
			runMatch()
		end
	end
end

function RoundService.start()
	Players.PlayerRemoving:Connect(function(player)
		if match ~= nil then
			MatchState.removePlayer(match, player)
			platforms[player] = nil
		end
	end)
	WaterService.startCullLoop(function()
		if phase == "Prompt" or phase == "Reveal" or phase == "Surge" then
			return alivePlayers()
		end
		return {}
	end, eliminate)
	task.spawn(mainLoop)
end

return RoundService
