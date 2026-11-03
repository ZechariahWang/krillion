--!strict
-- The match state machine: Waiting -> Intermission -> (Prompt -> Reveal -> Surge)* -> Results -> ...

local MatchmakingService = game:GetService("MatchmakingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local SpecialRound = require(ReplicatedStorage.Shared.SpecialRound)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
local Economy = require(ReplicatedStorage.Shared.Economy)
local AnswerService = require(script.Parent.AnswerService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local LobbyQuizService = require(script.Parent.LobbyQuizService)
local MapService = require(script.Parent.MapService)
local PlayerService = require(script.Parent.PlayerService)
local StoreService = require(script.Parent.StoreService)
local WaterService = require(script.Parent.WaterService)

local phase = "Waiting"
local round = 0
local secondsLeft = 0
local currentPrompt: AnswerService.Prompt? = nil
local match: MatchState.State? = nil
local platforms: { [Player]: Part } = {}
local usedPromptIds: { [string]: boolean } = {}
local special: string? = nil -- this round's special, if any
local roundSurge = 0 -- how far the water will rise at the end of this round
local participantCount = 0
local matchId = 0
local sunkPlatforms: { [Player]: Part } = {} -- kept so a revive can put the player back on their own pillar
local reviveUsed: { [Player]: boolean } = {}
local reviveOffers: { [Player]: { matchId: number, expires: number } } = {}

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

local function broadcastState()
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
			surge = roundSurge,
			special = special,
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

local function sinkPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return nil
	end
	return root.Position
end

local function offerRevive(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not Economy.canOfferRevive(profile.revives, reviveUsed[player] == true, RoundService.aliveCount()) then
		return
	end
	reviveOffers[player] = { matchId = matchId, expires = os.clock() + GameConfig.Revive.WindowSeconds }
	Net.event("RevivePrompt"):FireClient(player, { seconds = GameConfig.Revive.WindowSeconds, revives = profile.revives })
end

local function sinkPlayer(player: Player)
	local position = sinkPosition(player)
	if position ~= nil then
		CosmeticService.splash(player, position)
	end
	sunkPlatforms[player] = platforms[player]
	platforms[player] = nil
	PlayerService.sendToLobby(player)
	Net.event("Eliminated"):FireClient(player, { round = round })
	setServerAttributes()
	offerRevive(player)
end

local function onReviveUse(player: Player)
	local offer = reviveOffers[player]
	reviveOffers[player] = nil
	local state = match
	if offer == nil or state == nil or offer.matchId ~= matchId or os.clock() > offer.expires then
		return
	end
	local platform = sunkPlatforms[player]
	if platform == nil or platform.Parent == nil or not PlayerService.hasCharacter(player) then
		return
	end
	local profile = DataService.get(player)
	if profile == nil or profile.revives <= 0 or reviveUsed[player] then
		return
	end
	reviveUsed[player] = true
	DataService.addRevives(player, -1)
	local top = state.waterY + GameConfig.Revive.HeightAboveWater
	-- The pillar glides out of the water before the player is put back on it.
	MapService.glidePlatformTop(platform, top, 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	if match ~= state or platform.Parent == nil then
		return
	end
	PlayerService.sendToPlatform(player, platform)
	MatchState.revive(state, player, GameConfig.Revive.HeightAboveWater)
	platforms[player] = platform
	sunkPlatforms[player] = nil
	AnswerService.allow(player)
	MapService.riseBurst(platform)
	broadcastState()
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
	special = nil
	roundSurge = 0
	platforms = {}
	sunkPlatforms = {}
	reviveUsed = {}
	reviveOffers = {}
	matchId += 1
	WaterService.reset()
	local parts = MapService.spawnPlatforms(#participants, GameConfig.Water.StartHeight)
	for index, player in participants do
		MatchState.addPlayer(state, player)
		platforms[player] = parts[index]
		MapService.setPlatformName(parts[index], player.DisplayName)
		CosmeticService.applySkin(player, parts[index])
		PlayerService.sendToPlatform(player, parts[index])
	end
end

-- One eased glide up with a soft overshoot; confetti fires as it nears the top.
local function risePlatform(player: Player, toTop: number, points: number)
	local platform = platforms[player]
	if platform == nil or platform.Parent == nil then
		return
	end
	MapService.riseBurst(platform)
	if points >= GameConfig.Platform.ConfettiMinPoints then
		task.delay(GameConfig.Platform.RiseSeconds * 0.5, function()
			if platform.Parent ~= nil then
				MapService.celebrate(platform, points)
			end
		end)
	end
	MapService.glidePlatformTop(platform, toTop, GameConfig.Platform.RiseSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function runPrompt()
	round += 1
	special = SpecialRound.pick(round, special, math.random(), math.random())
	roundSurge = SpecialRound.surge(round, special)
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
		local lift = SpecialRound.lift(points, special)
		MatchState.applyLift(state, player, points, lift)
		DataService.recordHeight(player, state.heights[player])
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
			task.spawn(risePlatform, player, state.heights[player], points)
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
	MatchState.surge(state, roundSurge)
	WaterService.surgeTo(state.waterY)
	local culled = MatchState.cull(state)
	for _, player in culled do
		sinkPlayer(player)
	end
	for _, player in alivePlayers() do
		StoreService.payEarned(player, Economy.matchCash(1, false))
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
		if Economy.countsAsWin(participantCount) then
			DataService.addWin(winner)
			StoreService.payEarned(winner, Economy.matchCash(0, true))
		end
	end
	local top = podium(state, winner)
	for _, player in alivePlayers() do
		MatchState.eliminate(state, player)
		PlayerService.sendToLobby(player)
	end
	MapService.clearPlatforms()
	platforms = {}
	sunkPlatforms = {}
	reviveOffers = {}
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
	Net.event("ReviveUse").OnServerEvent:Connect(onReviveUse)
	Players.PlayerRemoving:Connect(function(player)
		if match ~= nil then
			MatchState.removePlayer(match, player)
			platforms[player] = nil
			sunkPlatforms[player] = nil
			reviveOffers[player] = nil
		end
	end)
	WaterService.startCullLoop(function()
		if phase == "Prompt" or phase == "Reveal" or phase == "Surge" then
			return alivePlayers()
		end
		return {}
	end, eliminate)
	-- Fill the tank now, so spectators in the lobby see water before the first match.
	WaterService.reset()
	task.spawn(mainLoop)
end

return RoundService
