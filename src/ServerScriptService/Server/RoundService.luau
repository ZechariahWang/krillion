--!strict
-- The match state machine: Waiting -> Intermission -> (Prompt -> Reveal -> Surge)* -> Results -> ...
-- Other services hear about match moments through MatchEvents rather than being called from here.

local MatchmakingService = game:GetService("MatchmakingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local BotBrain = require(ReplicatedStorage.Shared.BotBrain)
local Depth = require(ReplicatedStorage.Shared.Depth)
local LateJoin = require(ReplicatedStorage.Shared.LateJoin)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Schooling = require(ReplicatedStorage.Shared.Schooling)
local SpecialRound = require(ReplicatedStorage.Shared.SpecialRound)
local WaterCurve = require(ReplicatedStorage.Shared.WaterCurve)
local Economy = require(ReplicatedStorage.Shared.Economy)
local AnswerService = require(script.Parent.AnswerService)
local AnswerStatsService = require(script.Parent.AnswerStatsService)
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

local PROMPT_POLL_SECONDS = 0.1 -- how often the prompt clock looks for everyone having locked in

local phase = "Waiting"
local round = 0
local secondsLeft = 0
local overtime = false -- the prompt is running past its base time for someone's extra time
local currentPrompt: AnswerService.Prompt? = nil
local match: MatchState.State? = nil
local platforms: { [Player]: Part } = {}
local usedPromptIds: { [string]: boolean } = {}
local special: string? = nil -- this round's special, if any
local roundSurge = 0 -- how far the water will rise at the end of this round
local participantCount = 0
local participantsList: { Player } = {}
local slotCount = 0 -- how many players this match may hold, late joiners included
local playedUserIds: { [number]: boolean } = {} -- everyone who had a pillar this match, even if they left
local lateUnproven: { [Player]: boolean } = {} -- late joiners who have not had an answer graded yet
local matchId = 0
local sunkPlatforms: { [Player]: Part } = {} -- kept so a revive can put the player back on their own pillar
local reviveUsed: { [Player]: boolean } = {}
local reviveOffers: { [Player]: { matchId: number, expires: number } } = {}
local broadcastQueued = false
-- Bots (negative number ids, see BotService) live in the match state but never in `platforms` or
-- alivePlayers(), so the water cull, payouts and MatchEvents only ever see real players.
local bots: { number } = {}
local botPlatforms: { [number]: Part } = {}
local botAnswers: { [number]: AnswerService.Submission } = {} -- bots locked in on the open prompt
local botPending: { [number]: string } = {} -- answers bots will lock in later this prompt
local promptToken = 0 -- bumped per prompt, so a bot answer scheduled for an old prompt is dropped

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

local function aliveBots(): { number }
	local result = {}
	if match == nil then
		return result
	end
	for _, id in bots do
		if match.alive[id] then
			table.insert(result, id)
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

local function platformOf(id: any): Part?
	if typeof(id) == "Instance" then
		return platforms[id :: Player]
	end
	return botPlatforms[id :: number]
end

-- A solo match (empty server) runs until the lone player sinks instead of ending at once. Bots never
-- play on alone: the match ends once no player is left afloat.
local function matchOver(): boolean
	local alive = RoundService.aliveCount()
	if #bots > 0 and #alivePlayers() == 0 then
		return true
	end
	if participantCount + #bots > 1 then
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

local function inMatchPhase(): boolean
	return phase == "Prompt" or phase == "Reveal" or phase == "Surge"
end

local function lateJoinWindow(): boolean
	-- Overtime is past the base time, so it counts as no time left.
	return LateJoin.windowOpen(phase, round, if overtime then 0 else secondsLeft, GameConfig.LateJoin)
end

local function lateJoinRoom(): boolean
	return participantCount < slotCount and MapService.hasFreeSpot()
end

-- Whether this player may jump into the running match right now (drives the JUMP IN card).
local function lateJoinOpenFor(player: Player): boolean
	if player:GetAttribute("Afk") == true then
		return false
	end
	return match ~= nil and lateJoinWindow() and not playedUserIds[player.UserId] and lateJoinRoom()
end

-- Starters plus late joiners who have answered at least once: a joiner who never answers (or an alt that
-- joins and leaves) cannot turn a solo run into a Win.
local function provenParticipants(): number
	local unproven = 0
	for _ in lateUnproven do
		unproven += 1
	end
	return participantCount - unproven
end

local function broadcastState()
	local aliveUserIds = {}
	local contestants: { any } = table.clone(alivePlayers())
	for _, id in aliveBots() do
		table.insert(contestants, id)
	end
	for _, id in contestants do
		table.insert(aliveUserIds, userIdOf(id))
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
	local lockedUserIds: { number } = {}
	if phase == "Prompt" then
		lockedUserIds = AnswerService.lockedUserIds()
		for id in botAnswers do
			table.insert(lockedUserIds, id)
		end
	end
	for _, player in Players:GetPlayers() do
		local height = 0
		if match ~= nil and match.heights[player] ~= nil then
			height = match.heights[player]
		end
		local playing = match ~= nil and match.alive[player] == true
		local yourSecondsLeft: number? = nil
		if phase == "Prompt" then
			yourSecondsLeft = AnswerService.secondsLeftFor(player)
			-- In overtime everyone without extra time of their own is already out of time.
			if overtime and yourSecondsLeft == nil then
				yourSecondsLeft = 0
			end
		end
		Net.event("RoundState"):FireClient(player, {
			phase = phase,
			round = round,
			secondsLeft = secondsLeft,
			yourSecondsLeft = yourSecondsLeft,
			overtime = overtime,
			alive = #aliveUserIds,
			aliveUserIds = aliveUserIds,
			lockedUserIds = lockedUserIds,
			prompt = promptText,
			promptId = promptId,
			playing = playing,
			lateJoinOpen = not playing and lateJoinOpenFor(player),
			height = height,
			waterY = waterY,
			surge = roundSurge,
			special = special,
			playerCount = #Players:GetPlayers(),
			starting = participantCount + #bots,
			minPlayers = GameConfig.Round.MinPlayers,
		})
	end
end

-- A lock-in pushes an extra update soon after, at most a few per second, so lock dots react quickly.
local function queueBroadcast()
	if broadcastQueued then
		return
	end
	broadcastQueued = true
	task.delay(GameConfig.Round.LockBroadcastSeconds, function()
		broadcastQueued = false
		if phase == "Prompt" then
			broadcastState()
		end
	end)
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
	-- With no player left afloat the match ends now, however many bots are still up.
	if #bots > 0 and #alivePlayers() == 0 then
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
	local platform = platforms[player]
	AnswerService.disallow(player)
	sunkPlatforms[player] = platform
	platforms[player] = nil
	if platform ~= nil and platform.Parent ~= nil then
		MapService.markSunk(platform)
	end
	PlayerService.sendToLobby(player)
	Net.event("Eliminated"):FireClient(player, { round = round })
	setServerAttributes()
	MatchEvents.PlayerSank.fire(player, round)
	offerRevive(player)
end

-- A bot under the water: its pillar goes slate and its rig sinks. Bots get no revive offer.
local function sinkBot(id: number)
	local platform = botPlatforms[id]
	botPlatforms[id] = nil
	if platform ~= nil and platform.Parent ~= nil then
		MapService.markSunk(platform)
	end
	BotService.sink(id)
	setServerAttributes()
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
	-- Back to its own colours, skin and name, then the pillar glides out of the water before the player
	-- is put back on it.
	MapService.unmarkSunk(platform)
	CosmeticService.applySkin(player, platform)
	MapService.setPlatformName(platform, player.DisplayName)
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
	slotCount = LateJoin.slotCount(#participants, GameConfig.LateJoin, GameConfig.Server.MaxPlayers)
	playedUserIds = {}
	lateUnproven = {}
	for _, player in participants do
		playedUserIds[player.UserId] = true
	end
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
	overtime = false
	matchId += 1
	WaterService.reset()
	local usedNames: { [string]: boolean } = {}
	for _, player in participants do
		usedNames[player.DisplayName] = true
	end
	local botCount = BotBrain.fillCount(#participants, GameConfig.Bots.FillTo, GameConfig.Server.MaxPlayers)
	bots = BotService.fill(botCount, usedNames)
	botPlatforms = {}
	botAnswers = {}
	botPending = {}
	local parts = MapService.spawnPlatforms(#participants + #bots, GameConfig.Water.StartHeight)
	for index, player in participants do
		MatchState.addPlayer(state, player)
		platforms[player] = parts[index]
		-- Lets clients find a player's pillar (answer tags) without a lookup remote.
		parts[index]:SetAttribute("OwnerUserId", player.UserId)
		MapService.setPlatformName(parts[index], player.DisplayName)
		CosmeticService.applySkin(player, parts[index])
		PlayerService.sendToPlatform(player, parts[index])
	end
	for index, id in bots do
		local part = parts[#participants + index]
		MatchState.addPlayer(state, id)
		botPlatforms[id] = part
		part:SetAttribute("OwnerUserId", id)
		MapService.setPlatformName(part, BotService.nameOf(id))
		BotService.attach(id, part)
	end
	MatchEvents.MatchStarted.fire(table.clone(participantsList))
end

-- One eased glide up with a soft overshoot; confetti fires as it nears the top.
local function risePlatform(platform: Part?, toTop: number, points: number)
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

-- Locks in a bot's planned answer, unless its prompt is over or the water already took it.
local function lockBot(token: number, id: number)
	local answer = botPending[id]
	if token ~= promptToken or answer == nil or match == nil or not match.alive[id] then
		return
	end
	botPending[id] = nil
	local submission = AnswerService.submitFor(id, answer)
	if submission ~= nil then
		botAnswers[id] = submission
		queueBroadcast()
	end
end

-- Each alive bot picks a tier by skill, an answer no other bot has, and a time to lock it in.
local function scheduleBots(prompt: AnswerService.Prompt, seconds: number)
	promptToken += 1
	botAnswers = {}
	botPending = {}
	local token = promptToken
	local taken: { [string]: boolean } = {}
	for _, id in aliveBots() do
		local aim = BotBrain.chooseTier(BotService.skillOf(id), math.random(), BotBrain.gaussian(math.random(), math.random()))
		local index = if aim ~= nil then BotBrain.nearestTier(prompt.answers, aim) else nil
		local answer = if index ~= nil then BotBrain.chooseAnswer(prompt.answers, index, taken, math.random()) else nil
		if answer ~= nil then
			taken[answer] = true
			botPending[id] = answer
			task.delay(BotBrain.delay(seconds, math.random()), lockBot, token, id)
		end
	end
end

-- Every player has locked in: bots still thinking answer now, spread over part of the grace, so the
-- prompt does not wait on them.
local function hurryBots()
	local token = promptToken
	for id in botPending do
		task.delay(math.random() * GameConfig.Round.AllLockedGrace * 0.6, lockBot, token, id)
	end
end

-- The prompt's base countdown, broadcast once a second like countdown(). It also ends early when the
-- match is decided, or Round.AllLockedGrace after every eligible player has locked in (a late joiner or a
-- revive makes that false again, so the round carries on for them).
local function promptCountdown(seconds: number)
	secondsLeft = seconds
	broadcastState()
	local nextTick = os.clock() + 1
	local allLockedAt: number? = nil
	while secondsLeft > 0 do
		task.wait(PROMPT_POLL_SECONDS)
		if matchOver() then
			return
		end
		local now = os.clock()
		if AnswerService.allLocked() then
			if allLockedAt == nil then
				hurryBots()
			end
			local since = allLockedAt or now
			allLockedAt = since
			if now - since >= GameConfig.Round.AllLockedGrace then
				return
			end
		else
			allLockedAt = nil
		end
		if now >= nextTick then
			nextTick += 1
			secondsLeft -= 1
			broadcastState()
		end
	end
end

-- After the base time runs out, keeps the prompt open while someone with bought extra time is still
-- answering. Everyone else sees OVERTIME.
local function runOvertime()
	while not matchOver() do
		local remaining = AnswerService.overtimeRemaining()
		if remaining <= 0 then
			break
		end
		overtime = true
		secondsLeft = math.ceil(remaining)
		broadcastState()
		task.wait(math.min(1, remaining))
	end
	overtime = false
end

local function runPrompt()
	round += 1
	special = SpecialRound.pick(round, special, math.random(), math.random())
	roundSurge = SpecialRound.surge(round, special)
	local prompt = AnswerService.randomPrompt(usedPromptIds)
	usedPromptIds[prompt.id] = true
	currentPrompt = prompt
	LobbyQuizService.setLivePromptId(prompt.id)
	local seconds = WaterCurve.promptSeconds(round)
	local players = alivePlayers()
	AnswerService.openRound(prompt, players, seconds)
	MatchEvents.PromptOpened.fire({ id = prompt.id, prompt = prompt.prompt }, round, players, seconds)
	scheduleBots(prompt, seconds)
	-- Set before the phase change so clients start their timer from the right number, not the last countdown's 0.
	secondsLeft = seconds
	setPhase("Prompt")
	promptCountdown(seconds)
	runOvertime()
	-- Bots that have not answered by now never will this prompt.
	promptToken += 1
	botPending = {}
	return AnswerService.closeRound()
end

local function runReveal(submissions: { [Player]: AnswerService.Submission })
	local state = match :: MatchState.State
	local prompt = currentPrompt
	local promptId = ""
	if prompt ~= nil then
		promptId = prompt.id
	end
	local rows = {}
	local graded: { { player: Player, tier: string?, points: number, answer: string? } } = {}
	-- Players, then bots; only players are graded for MatchEvents, saved heights and late-join proof.
	local alive: { any } = table.clone(alivePlayers())
	local all: { [any]: AnswerService.Submission } = {}
	for player, submission in submissions do
		all[player] = submission
	end
	for _, id in aliveBots() do
		table.insert(alive, id)
		all[id] = botAnswers[id]
	end
	-- Schooling: everyone who locked in the same answer gets a cut of its points (off unless enabled).
	local answers: { [any]: string } = {}
	for _, id in alive do
		local submission = all[id]
		if submission ~= nil and submission.corrected ~= nil then
			answers[id] = submission.corrected
		end
	end
	local schoolSizes = Schooling.sizes(answers)
	for _, id in alive do
		local player: Player? = if typeof(id) == "Instance" then id :: Player else nil
		local submission = all[id]
		local points = 0
		local tier = nil
		local shownAnswer = nil
		local schooled: number? = nil
		if submission ~= nil then
			local size = schoolSizes[id]
			points = Schooling.apply(submission.points, size, GameConfig.Schooling)
			if Schooling.applies(size, GameConfig.Schooling) then
				schooled = size
			end
			tier = submission.tier
			-- Accepted answers are shown in the bank's spelling, which is our own text, so it needs no chat filter.
			shownAnswer = submission.corrected
			if player ~= nil then
				lateUnproven[player] = nil
			end
		end
		local lift = SpecialRound.lift(points, special)
		MatchState.applyLift(state, id, points, lift)
		if player ~= nil then
			DataService.recordHeight(player, state.heights[player])
		end
		local depth = Depth.metres(tier, shownAnswer)
		local oneIn: number? = nil
		if shownAnswer ~= nil then
			oneIn = AnswerStatsService.oneIn(promptId, shownAnswer)
		end
		table.insert(rows, {
			userId = userIdOf(id),
			name = nameOf(id),
			answer = shownAnswer,
			tier = tier,
			points = points,
			lift = lift,
			height = state.heights[id],
			depth = depth,
			oneIn = oneIn,
			schooled = schooled,
		})
		if player ~= nil then
			table.insert(graded, { player = player, tier = tier, points = points, answer = shownAnswer })
		end
		if lift > 0 then
			-- The dive card lands first; seeing the pillar rise before it would spoil the tier.
			task.delay(GameConfig.Reveal.RaiseDelaySeconds, risePlatform, platformOf(id), state.heights[id], points)
		end
	end
	currentPrompt = nil
	LobbyQuizService.setLivePromptId(nil)
	setPhase("Reveal")
	Net.event("Reveal"):FireAllClients({ round = round, rows = rows })
	for _, entry in graded do
		MatchEvents.AnswerGraded.fire(entry.player, entry.tier, entry.points, promptId, entry.answer)
	end
	task.wait(GameConfig.Round.RevealSeconds)
end

local function runSurge()
	local state = match :: MatchState.State
	setPhase("Surge")
	MatchState.surge(state, roundSurge)
	WaterService.surgeTo(state.waterY)
	local culled = MatchState.cull(state)
	for _, id in culled do
		if typeof(id) == "Instance" then
			sinkPlayer(id :: Player)
		else
			sinkBot(id :: number)
		end
	end
	for _, player in alivePlayers() do
		StoreService.payEarned(player, Economy.matchCash(1, false), "survive")
		MatchEvents.RoundSurvived.fire(player, round)
	end
	broadcastState()
end

-- The winner, then the best by points, players and bots alike. Players who left are already out of the
-- state (PlayerRemoving), so everyone listed can be named.
local function podium(state: MatchState.State, winner: any): { { name: string, points: number } }
	local ids: { any } = {}
	for id in state.points do
		if id ~= winner then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return state.points[a] > state.points[b]
	end)
	if winner ~= nil then
		table.insert(ids, 1, winner)
	end
	local top = {}
	for index = 1, math.min(3, #ids) do
		local id = ids[index]
		table.insert(top, { name = nameOf(id), points = state.points[id] or 0 })
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
	-- Only players count toward a Win (provenParticipants), so a lone player outlasting bots is not one.
	local countsAsWin = Economy.countsAsWin(provenParticipants())
	if found ~= nil then
		winnerName = nameOf(found)
	end
	if winner ~= nil and countsAsWin then
		DataService.addWin(winner)
		StoreService.payEarned(winner, Economy.matchCash(0, true), "win")
	end
	local top = podium(state, found)
	for _, player in alivePlayers() do
		MatchState.eliminate(state, player)
		PlayerService.sendToLobby(player)
	end
	local contestants = participantCount + #bots
	for _, id in aliveBots() do
		MatchState.eliminate(state, id)
	end
	promptToken += 1
	BotService.clear()
	bots = {}
	botPlatforms = {}
	botAnswers = {}
	botPending = {}
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
		podium = top,
		seconds = GameConfig.Round.ResultsSeconds,
	})
	participantsList = {}
	playedUserIds = {}
	lateUnproven = {}
	slotCount = 0
	countdown(GameConfig.Round.ResultsSeconds)
end

-- Fades the starters' screens to black, so the teleport onto the pillars happens out of sight.
local function introFade()
	local seconds = GameConfig.Round.IntroFadeSeconds
	for _, player in readyPlayers() do
		Net.event("MatchIntro"):FireClient(player, { fadeSeconds = seconds })
	end
	task.wait(seconds)
end

local function runMatch()
	introFade()
	startMatch()
	-- Everyone stands on their pillar for a 3-2-1 before the first prompt.
	secondsLeft = GameConfig.Round.StartCountdownSeconds
	setPhase("Starting")
	countdown(GameConfig.Round.StartCountdownSeconds)
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

-- Puts a late joiner into the running match. Returns the JoinResult status
-- ("joined" | "closed" | "full" | "already" | "not_ready") and the message shown to the player.
-- The debug hook calls this too, so it does all its own checks. Nothing here yields.
function RoundService.tryJoin(player: Player): (string, string)
	if player:GetAttribute("Afk") == true then
		return "closed", LateJoin.Messages.closed
	end
	local state = match
	local status = LateJoin.canJoin({
		enabled = GameConfig.LateJoin.Enabled == 1,
		matchRunning = state ~= nil and inMatchPhase(),
		played = playedUserIds[player.UserId] == true or (state ~= nil and state.points[player] ~= nil),
		windowOpen = lateJoinWindow(),
		hasRoom = lateJoinRoom(),
		ready = player.Parent ~= nil and PlayerService.hasCharacter(player),
	})
	if status ~= "joined" then
		return status, LateJoin.Messages[status]
	end
	if state == nil then
		return "closed", LateJoin.Messages.closed
	end
	local height = LateJoin.joinHeight(state.waterY, GameConfig.Water.StartHeight, MatchState.lowestAlive(state))
	local platform = MapService.addPlatform(height)
	if platform == nil then
		return "full", LateJoin.Messages.full
	end
	playedUserIds[player.UserId] = true
	participantCount += 1
	table.insert(participantsList, player)
	lateUnproven[player] = true
	platform:SetAttribute("OwnerUserId", player.UserId)
	MapService.setPlatformName(platform, player.DisplayName)
	CosmeticService.applySkin(player, platform)
	PlayerService.sendToPlatform(player, platform)
	-- Added after the teleport, so the water poll never sees them still standing in the lobby.
	MatchState.addPlayerAt(state, player, height)
	platforms[player] = platform
	-- Mid-prompt they answer this prompt (with at least LateJoin.MinSecondsLeft); otherwise the next one.
	if phase == "Prompt" then
		AnswerService.allow(player)
	end
	MatchEvents.PlayerJoinedMatch.fire(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			NotifyService.send(other, string.upper(player.DisplayName) .. " JUMPED IN!", "info")
		end
	end
	broadcastState()
	setServerAttributes()
	return "joined", LateJoin.Messages.joined
end

-- A plain-data picture of the match for the Studio debug hook.
function RoundService.snapshot(): { [string]: any }
	local alive = {}
	local heights: { [string]: number } = {}
	local contestants: { any } = table.clone(alivePlayers())
	for _, id in aliveBots() do
		table.insert(contestants, id)
	end
	for _, id in contestants do
		table.insert(alive, userIdOf(id))
		if match ~= nil then
			heights[tostring(userIdOf(id))] = match.heights[id]
		end
	end
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
	return {
		phase = phase,
		round = round,
		secondsLeft = secondsLeft,
		overtime = overtime,
		matchId = matchId,
		participantCount = participantCount,
		slotCount = slotCount,
		lateJoinOpen = match ~= nil and lateJoinWindow() and lateJoinRoom(),
		participants = participants,
		bots = botNames,
		alive = alive,
		heights = heights,
		locked = AnswerService.lockedUserIds(),
		waterY = if match ~= nil then match.waterY else 0,
		surge = roundSurge,
		special = special,
		prompt = promptText,
	}
end

function RoundService.start()
	Net.event("ReviveUse").OnServerEvent:Connect(onReviveUse)
	Net.event("JoinMatch").OnServerEvent:Connect(function(player)
		local status, message = RoundService.tryJoin(player)
		Net.event("JoinResult"):FireClient(player, { status = status, message = message })
	end)
	AnswerService.Locked.connect(queueBroadcast)
	Players.PlayerRemoving:Connect(function(player)
		if match ~= nil then
			MatchState.removePlayer(match, player)
			platforms[player] = nil
			sunkPlatforms[player] = nil
			reviveOffers[player] = nil
			-- A late joiner who leaves before answering never counted, so a solo run stays solo.
			if lateUnproven[player] then
				lateUnproven[player] = nil
				participantCount -= 1
				local index = table.find(participantsList, player)
				if index ~= nil then
					table.remove(participantsList, index)
				end
			end
		end
	end)
	-- Resetting (or any death) on a pillar is a sink: the respawn lands in the lobby, above the water, so the
	-- water poll alone would never catch it.
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
