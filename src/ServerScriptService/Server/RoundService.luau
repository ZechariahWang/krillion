--!strict
-- The match state machine for Crab Craze: Waiting -> Intermission -> Starting -> (Prompt -> Reveal)* ->
-- Results -> ... Prompt is one question with the crab going round the ring; Reveal is the beat after the
-- crab pinches. Other services hear about match moments through MatchEvents rather than being called here.

local MatchmakingService = game:GetService("MatchmakingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local BotBrain = require(ReplicatedStorage.Shared.BotBrain)
local CrabMatch = require(ReplicatedStorage.Shared.CrabMatch)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local AnswerService = require(script.Parent.AnswerService)
local BotService = require(script.Parent.BotService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local LobbyQuizService = require(script.Parent.LobbyQuizService)
local MapService = require(script.Parent.MapService)
local MatchEvents = require(script.Parent.MatchEvents)
local NotifyService = require(script.Parent.NotifyService)
local PlayerService = require(script.Parent.PlayerService)
local StoreService = require(script.Parent.StoreService)
local WaterService = require(script.Parent.WaterService)

local RULES = GameConfig.Crab
local FUSE_POLL_SECONDS = 0.1 -- how often the fuse burns down and the crab's mood is checked

local phase = "Waiting"
local round = 0 -- the question number
local secondsLeft = 0
local currentPrompt: AnswerService.Prompt? = nil
local match: CrabMatch.Match? = nil
local shownMood = "Calm" -- the crab's mood in the last broadcast
local platforms: { [Player]: Part } = {}
local sunkPlatforms: { [Player]: Part } = {} -- kept so a revive can put the player back on their own pillar
local usedPromptIds: { [string]: boolean } = {}
local points: { [any]: number } = {} -- answer points this match, for the podium
local participantCount = 0
local participantsList: { Player } = {}
local matchId = 0
local reviveUsed: { [Player]: boolean } = {}
local reviveOffers: { [Player]: { matchId: number, expires: number, kind: string } } = {}
-- Bots (negative number ids, see BotService) are in the match like players but never in `platforms` or
-- alivePlayers(), so payouts and MatchEvents only ever see real players.
local bots: { number } = {}
local botPlatforms: { [number]: Part } = {}
local turnToken = 0 -- bumped whenever the crab changes hands, so a bot answer planned for an old turn is dropped

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

-- A contestant is a Player or a bot id.
local function nameOf(id: any): string
	if typeof(id) == "Instance" then
		return (id :: Player).DisplayName
	end
	return BotService.nameOf(id :: number)
end

local function userIdOf(id: any): number
	if typeof(id) == "Instance" then
		return (id :: Player).UserId
	end
	return id :: number
end

function RoundService.aliveCount(): number
	if match == nil then
		return 0
	end
	return CrabMatch.aliveCount(match)
end

-- Bots never play on alone: the match ends once no player is left in.
local function matchOver(): boolean
	if match == nil then
		return true
	end
	if #bots > 0 and #alivePlayers() == 0 then
		return true
	end
	return CrabMatch.over(match)
end

-- Players with a character who are not AFK (Settings): an AFK player is never put on a pillar.
local function readyPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		local afk = player:GetAttribute("Afk") == true
		if PlayerService.hasCharacter(player) and not afk then
			table.insert(result, player)
		end
	end
	return result
end

local function broadcastState()
	local state = match
	local ring: { Net.RingRow } = {}
	local aliveUserIds: { number } = {}
	local holderUserId: number? = nil
	local used: { string } = {}
	local mood = "Calm"
	if state ~= nil then
		for _, id in state.order do
			table.insert(ring, { userId = userIdOf(id), name = nameOf(id), hearts = state.hearts[id] })
			if state.alive[id] then
				table.insert(aliveUserIds, userIdOf(id))
			end
		end
		if state.holder ~= nil then
			holderUserId = userIdOf(state.holder)
		end
		used = state.usedList
		if phase == "Prompt" then
			mood = CrabMatch.mood(state)
		end
	end
	shownMood = mood
	local promptText = nil
	local promptId = nil
	if currentPrompt ~= nil then
		promptText = currentPrompt.prompt
		promptId = currentPrompt.id
	end
	for _, player in Players:GetPlayers() do
		local playing = state ~= nil and state.alive[player] == true
		local meter = 0
		if state ~= nil and state.meter[player] ~= nil then
			meter = state.meter[player]
		end
		Net.event("RoundState"):FireClient(player, {
			phase = phase,
			round = round,
			secondsLeft = secondsLeft,
			alive = #aliveUserIds,
			aliveUserIds = aliveUserIds,
			prompt = promptText,
			promptId = promptId,
			playing = playing,
			holderUserId = holderUserId,
			mood = mood,
			ring = ring,
			used = used,
			meter = meter,
			meterTarget = RULES.MeterTarget,
			maxHearts = RULES.MaxHearts,
			playerCount = #Players:GetPlayers(),
			readyCount = #readyPlayers(),
			starting = participantCount + #bots,
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

local botAnswer: (token: number, id: number) -> ()

local function scheduleBot(id: number)
	local delay = RULES.BotDelayMin + (RULES.BotDelayMax - RULES.BotDelayMin) * math.random()
	task.delay(delay, botAnswer, turnToken, id)
end

-- Hands the turn to whoever holds the crab: a player may answer, a bot plans its answer.
local function startTurn()
	turnToken += 1
	local state = match
	local holder = if state ~= nil then state.holder else nil
	if holder ~= nil and typeof(holder) == "Instance" then
		AnswerService.setHolder(holder :: Player)
		return
	end
	AnswerService.setHolder(nil)
	if holder ~= nil then
		scheduleBot(holder :: number)
	end
end

-- The holder's answer was accepted: the crab moves on.
local function onAnswer(id: any, submission: AnswerService.Submission)
	local state = match
	local prompt = currentPrompt
	local answer = submission.corrected
	if state == nil or prompt == nil or phase ~= "Prompt" or state.holder ~= id or answer == nil then
		return
	end
	local result = CrabMatch.pass(state, answer, submission.points)
	points[id] = (points[id] or 0) + submission.points
	Net.event("CrabPassed"):FireAllClients({
		fromUserId = userIdOf(id),
		toUserId = if result.to ~= nil then userIdOf(result.to) else nil,
		answer = answer,
		tier = submission.tier,
		points = submission.points,
		gainedHeart = result.gainedHeart,
	})
	if typeof(id) == "Instance" then
		MatchEvents.AnswerGraded.fire(id :: Player, submission.tier, submission.points, prompt.id, answer)
	end
	startTurn()
	broadcastState()
end

-- A bot's turn: it picks a tier by skill and an answer nobody has used. A bot that draws a blank thinks
-- again, so it is only pinched when the fuse was short.
function botAnswer(token: number, id: number)
	local state = match
	local prompt = currentPrompt
	if token ~= turnToken or state == nil or prompt == nil or phase ~= "Prompt" or state.holder ~= id then
		return
	end
	local aim = BotBrain.chooseTier(BotService.skillOf(id), math.random(), BotBrain.gaussian(math.random(), math.random()))
	local index = if aim ~= nil then BotBrain.nearestTier(prompt.answers, aim) else nil
	local answer = if index ~= nil then BotBrain.chooseAnswer(prompt.answers, index, state.used, math.random()) else nil
	local graded = if answer ~= nil then AnswerService.gradeForBot(answer) else nil
	if graded == nil then
		scheduleBot(id)
		return
	end
	onAnswer(id, graded)
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

-- One revive per player per match, whatever pays for it (Economy.reviveOffer): the Second Chance pass's
-- free one, a revive from stock, or Revive Now bought on the spot. Never in a 1v1.
local function offerRevive(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	-- A player who died (a reset) respawns in the lobby after the window would close: no offer to waste.
	if not PlayerService.hasCharacter(player) then
		return
	end
	local kind = Economy.reviveOffer({
		revivesOwned = profile.revives,
		usedThisMatch = reviveUsed[player] == true,
		othersAlive = RoundService.aliveCount(),
		secondChance = StoreService.ownsPass(player, "SecondChance"),
		secondChanceUsed = false, -- the one-per-match rule already covers it
		canBuy = Products.ReviveNow.productId ~= 0,
	})
	if kind == nil then
		return
	end
	-- With no player left in the match ends now, however many bots are still up.
	if #bots > 0 and #alivePlayers() == 0 then
		return
	end
	-- A purchase takes longer than a tap, so Revive Now gets the longer window.
	local seconds = if kind == "buy" then GameConfig.Revive.BuyWindowSeconds else GameConfig.Revive.WindowSeconds
	reviveOffers[player] = { matchId = matchId, expires = os.clock() + seconds, kind = kind }
	Net.event("RevivePrompt"):FireClient(player, {
		seconds = seconds,
		revives = profile.revives,
		kind = kind,
		robux = Products.ReviveNow.robux,
		productId = Products.ReviveNow.productId,
	})
end

-- A player is out (the match state already says so): their pillar sinks and they go back to the lobby.
local function sinkPlayer(player: Player)
	local position = sinkPosition(player)
	if position ~= nil then
		CosmeticService.splash(player, position)
	end
	local platform = platforms[player]
	sunkPlatforms[player] = platform
	platforms[player] = nil
	if platform ~= nil and platform.Parent ~= nil then
		MapService.sinkPlatform(platform)
	end
	PlayerService.sendToLobby(player)
	Net.event("Eliminated"):FireClient(player, { round = round })
	setServerAttributes()
	MatchEvents.PlayerSank.fire(player, round)
	offerRevive(player)
end

-- A bot is out: its pillar sinks and its rig goes under. Bots get no revive offer.
local function sinkBot(id: number)
	local platform = botPlatforms[id]
	botPlatforms[id] = nil
	if platform ~= nil and platform.Parent ~= nil then
		MapService.sinkPlatform(platform)
	end
	BotService.sink(id)
	setServerAttributes()
end

-- Whether the player's revive offer is still good: this match, in time, their pillar still there.
local function liveOffer(player: Player): boolean
	local offer = reviveOffers[player]
	local platform = sunkPlatforms[player]
	return offer ~= nil
		and match ~= nil
		and offer.matchId == matchId
		and os.clock() <= offer.expires
		and not reviveUsed[player]
		and platform ~= nil
		and platform.Parent ~= nil
		and PlayerService.hasCharacter(player)
end

-- A revive the pillar could not finish rising for (the match ended under it) goes back where it came from.
local function refundRevive(player: Player, kind: string)
	reviveUsed[player] = nil
	if kind == "stock" or kind == "buy" then
		DataService.addRevives(player, 1)
		NotifyService.send(player, "REVIVE SAVED FOR YOUR NEXT MATCH", "info")
	end
end

-- Puts a player who is out back on their own pillar with the revive hearts. The caller has checked
-- liveOffer and taken payment; `kind` is the offer's kind, so the payment can go back if this fails.
local function restore(player: Player, kind: string)
	reviveOffers[player] = nil
	reviveUsed[player] = true
	local state = match :: CrabMatch.Match
	local platform = sunkPlatforms[player] :: Part
	-- Back to its own colours, skin and name, then the pillar rises out of the water before the player is
	-- put back on it.
	MapService.unmarkSunk(platform)
	CosmeticService.applySkin(player, platform)
	MapService.setPlatformName(platform, player.DisplayName)
	MapService.glidePlatformTop(platform, GameConfig.Water.StartHeight, 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	if match ~= state or platform.Parent == nil then
		refundRevive(player, kind)
		return
	end
	PlayerService.sendToPlatform(player, platform)
	local hadHolder = state.holder ~= nil
	CrabMatch.revive(state, player)
	platforms[player] = platform
	sunkPlatforms[player] = nil
	MapService.riseBurst(platform)
	if not hadHolder and phase == "Prompt" then
		startTurn()
	end
	broadcastState()
	setServerAttributes()
end

-- ReviveUse: a free (Second Chance) or stocked revive. Revive Now goes through its receipt instead.
local function onReviveUse(player: Player)
	local offer = reviveOffers[player]
	if offer == nil or not liveOffer(player) then
		reviveOffers[player] = nil
		return
	end
	if offer.kind == "stock" then
		local profile = DataService.get(player)
		if profile == nil or profile.revives <= 0 then
			return
		end
		DataService.addRevives(player, -1)
	elseif offer.kind == "free" then
		NotifyService.send(player, "SECOND CHANCE!", "good")
	else
		return
	end
	restore(player, offer.kind)
end

-- Revive Now's receipt: revives at once while the offer is live; a late receipt is never lost, it becomes
-- a revive in stock for a later match.
local function onReviveBought(player: Player)
	local offer = reviveOffers[player]
	if offer ~= nil and offer.kind == "buy" and liveOffer(player) then
		task.spawn(restore, player, "buy")
		return
	end
	DataService.addRevives(player, 1)
	NotifyService.send(player, "REVIVE SAVED FOR YOUR NEXT MATCH", "info")
end

-- A player fell in or lost their character mid-match: out at once, and the crab moves on if they held it.
local function eliminate(player: Player)
	local state = match
	if state == nil or not state.alive[player] then
		return
	end
	local heldCrab = state.holder == player
	CrabMatch.eliminate(state, player)
	sinkPlayer(player)
	if heldCrab and phase == "Prompt" then
		startTurn()
	end
	broadcastState()
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
	participantsList = table.clone(participants)
	round = 0
	usedPromptIds = {}
	points = {}
	platforms = {}
	sunkPlatforms = {}
	reviveUsed = {}
	reviveOffers = {}
	matchId += 1
	local usedNames: { [string]: boolean } = {}
	for _, player in participants do
		usedNames[player.DisplayName] = true
	end
	local botCount = BotBrain.fillCount(#participants, GameConfig.Bots.FillTo, GameConfig.Server.MaxPlayers)
	bots = BotService.fill(botCount, usedNames)
	botPlatforms = {}
	-- Ring order is pillar order: players first, then bots.
	local order: { any } = table.clone(participants)
	for _, id in bots do
		table.insert(order, id)
	end
	match = CrabMatch.new(order, math.random(), math.random())
	local parts = MapService.spawnPlatforms(#order, GameConfig.Water.StartHeight)
	for index, player in participants do
		platforms[player] = parts[index]
		-- Lets clients find a player's pillar (the crab, answer tags, hearts) without a lookup remote.
		parts[index]:SetAttribute("OwnerUserId", player.UserId)
		MapService.setPlatformName(parts[index], player.DisplayName)
		CosmeticService.applySkin(player, parts[index])
		PlayerService.sendToPlatform(player, parts[index])
	end
	for index, id in bots do
		local part = parts[#participants + index]
		botPlatforms[id] = part
		part:SetAttribute("OwnerUserId", id)
		MapService.setPlatformName(part, BotService.nameOf(id))
		BotService.attach(id, part)
	end
	MatchEvents.MatchStarted.fire(table.clone(participantsList))
end

-- One question: the crab goes round until its fuse runs out. Returns false if the match ended first.
local function runQuestion(): boolean
	local state = match :: CrabMatch.Match
	round += 1
	local exclude = table.clone(usedPromptIds)
	for id in LobbyQuizService.recentPromptIds(alivePlayers()) do
		exclude[id] = true
	end
	local prompt = AnswerService.randomPrompt(exclude)
	usedPromptIds[prompt.id] = true
	currentPrompt = prompt
	LobbyQuizService.setLivePromptId(prompt.id)
	AnswerService.openQuestion(prompt, state.used)
	MatchEvents.PromptOpened.fire({ id = prompt.id, prompt = prompt.prompt }, round, alivePlayers(), 0)
	startTurn()
	secondsLeft = 0
	setPhase("Prompt")
	local last = os.clock()
	while true do
		task.wait(FUSE_POLL_SECONDS)
		if matchOver() then
			return false
		end
		local now = os.clock()
		local burned = now - last
		last = now
		if CrabMatch.tick(state, burned) then
			return true
		end
		if CrabMatch.mood(state) ~= shownMood then
			broadcastState()
		end
	end
end

-- The fuse ran out: the crab pinches the holder, and everyone still in is paid for getting through it.
local function runPinch()
	local state = match :: CrabMatch.Match
	turnToken += 1
	currentPrompt = nil
	LobbyQuizService.setLivePromptId(nil)
	AnswerService.closeQuestion()
	if state.holder == nil then
		return
	end
	local result = CrabMatch.pinch(state, math.random())
	Net.event("CrabPinched"):FireAllClients({
		userId = userIdOf(result.id),
		hearts = result.hearts,
		eliminated = result.eliminated,
	})
	if result.eliminated then
		if typeof(result.id) == "Instance" then
			sinkPlayer(result.id :: Player)
		else
			sinkBot(result.id :: number)
		end
	end
	setPhase("Reveal")
	for _, player in alivePlayers() do
		StoreService.payEarned(player, Economy.matchCash(1, false), "survive")
		MatchEvents.RoundSurvived.fire(player, round)
	end
	task.wait(RULES.PinchSeconds)
end

-- The top three by CrabMatch.ranking. Players who left are already out of the match (PlayerRemoving), so
-- everyone listed can be named.
local function podium(state: CrabMatch.Match): { { name: string, points: number } }
	local ids = CrabMatch.ranking(state)
	local top = {}
	for index = 1, math.min(3, #ids) do
		local id = ids[index]
		table.insert(top, { name = nameOf(id), points = points[id] or 0 })
	end
	return top
end

local function endMatch()
	local state = match :: CrabMatch.Match
	local ranking = CrabMatch.ranking(state)
	-- The last one standing; when bots outlast every player, the first bot still in is named.
	local found = CrabMatch.winner(state)
	if found == nil and state.started > 1 then
		found = ranking[1]
	end
	local winner: Player? = nil
	if found ~= nil and typeof(found) == "Instance" then
		winner = found :: Player
	end
	local winnerName = "Nobody"
	if found ~= nil then
		winnerName = nameOf(found)
	end
	-- Only players count toward a Win, so a lone player outlasting bots is not one.
	local countsAsWin = Economy.countsAsWin(participantCount)
	if winner ~= nil and countsAsWin then
		DataService.addWin(winner)
		StoreService.payEarned(winner, Economy.matchCash(0, true), "win")
	end
	local top = podium(state)
	for _, player in alivePlayers() do
		PlayerService.sendToLobby(player)
	end
	local contestants = state.started
	turnToken += 1
	-- A match that ends inside a question never reaches runPinch, which otherwise clears these.
	currentPrompt = nil
	LobbyQuizService.setLivePromptId(nil)
	AnswerService.closeQuestion()
	BotService.clear()
	bots = {}
	botPlatforms = {}
	MapService.clearPlatforms()
	platforms = {}
	sunkPlatforms = {}
	reviveOffers = {}
	match = nil
	local present = {}
	for _, player in participantsList do
		if player.Parent ~= nil then
			table.insert(present, player)
		end
	end
	local winnerHere = winner
	if winnerHere ~= nil and winnerHere.Parent == nil then
		winnerHere = nil
	end
	MatchEvents.MatchFinished.fire(present, winnerHere, countsAsWin and winnerHere ~= nil, round)
	secondsLeft = GameConfig.Round.ResultsSeconds
	setPhase("Results")
	Net.event("MatchEnded"):FireAllClients({
		solo = contestants == 1,
		rounds = round,
		winnerName = winnerName,
		winnerUserId = if winnerHere ~= nil then winnerHere.UserId else nil,
		podium = top,
		seconds = GameConfig.Round.ResultsSeconds,
	})
	participantsList = {}
	countdown(GameConfig.Round.ResultsSeconds)
end

-- Fades the starters' screens to black, so the teleport onto the pillars happens out of sight.
local function introFade()
	local seconds = GameConfig.Round.IntroFadeSeconds
	for _, player in readyPlayers() do
		LobbyQuizService.stopFor(player)
		Net.event("MatchIntro"):FireClient(player, { fadeSeconds = seconds })
	end
	task.wait(seconds)
end

local function runMatch()
	introFade()
	-- Everyone can leave or go AFK during the fade: no match of bots for nobody.
	if #readyPlayers() < GameConfig.Round.MinPlayers then
		return
	end
	startMatch()
	-- Everyone stands on their pillar for a 3-2-1 before the first question.
	secondsLeft = GameConfig.Round.StartCountdownSeconds
	setPhase("Starting")
	countdown(GameConfig.Round.StartCountdownSeconds)
	while not matchOver() do
		if not runQuestion() then
			break
		end
		runPinch()
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

-- A plain-data picture of the match for the Studio debug hook. The fuse is in here and nowhere else.
function RoundService.snapshot(): { [string]: any }
	local state = match
	local alive = {}
	local hearts: { [string]: number } = {}
	local botNames: { [string]: string } = {}
	for _, id in bots do
		botNames[tostring(id)] = BotService.nameOf(id)
	end
	local participants = {}
	for _, player in participantsList do
		table.insert(participants, player.UserId)
	end
	local promptText: string? = nil
	if currentPrompt ~= nil then
		promptText = currentPrompt.prompt
	end
	local snapshot: { [string]: any } = {
		phase = phase,
		round = round,
		secondsLeft = secondsLeft,
		matchId = matchId,
		participantCount = participantCount,
		participants = participants,
		bots = botNames,
		alive = alive,
		hearts = hearts,
		prompt = promptText,
	}
	if state ~= nil then
		for _, id in state.order do
			hearts[tostring(userIdOf(id))] = state.hearts[id]
			if state.alive[id] then
				table.insert(alive, userIdOf(id))
			end
		end
		snapshot.holder = if state.holder ~= nil then userIdOf(state.holder) else nil
		snapshot.fuse = state.fuse
		snapshot.mood = CrabMatch.mood(state)
		snapshot.used = state.usedList
	end
	return snapshot
end

function RoundService.start()
	Net.event("ReviveUse").OnServerEvent:Connect(onReviveUse)
	StoreService.registerProduct(Products.ReviveNow.productId, onReviveBought)
	AnswerService.Answered.connect(function(player: Player, submission: AnswerService.Submission)
		onAnswer(player, submission)
	end)
	AnswerService.Extended.connect(function(_player: Player, seconds: number)
		if match ~= nil and phase == "Prompt" then
			CrabMatch.addTime(match, seconds)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local state = match
		if state == nil then
			return
		end
		local heldCrab = state.holder == player
		CrabMatch.remove(state, player)
		local platform = platforms[player]
		if platform ~= nil and platform.Parent ~= nil then
			MapService.sinkPlatform(platform)
		end
		platforms[player] = nil
		sunkPlatforms[player] = nil
		reviveOffers[player] = nil
		if heldCrab and phase == "Prompt" then
			startTurn()
		end
	end)
	-- Resetting (or any death) on a pillar puts the player out: the respawn lands in the lobby, above the
	-- water, so the water poll alone would never catch it.
	local function watchCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid ~= nil and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				eliminate(player)
			end)
		end
	end
	local function watchPlayer(player: Player)
		if player.Character ~= nil then
			task.spawn(watchCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			eliminate(player)
			watchCharacter(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	WaterService.startCullLoop(function()
		if phase == "Prompt" or phase == "Reveal" then
			return alivePlayers()
		end
		return {}
	end, eliminate)
	-- Fill the tank now, so the lobby sees water before the first match.
	WaterService.reset()
	task.spawn(mainLoop)
end

return RoundService
