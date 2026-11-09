--!strict
-- A personal prompt stream for anyone standing on the semicircle in front of the snack shack (Lobby.QuizZone's
-- ArcCenter, Outward and Radius attributes describe it).
-- Stepping in starts it, stepping out or the X (LobbyQuizStop) ends it, and a match pulls the player out of it
-- whatever they were doing. Answering is two steps like a match: LobbyQuizCheck
-- (Enter once) says whether the text is in the bank, LobbyQuizAnswer (Enter again) locks it in and pays
-- Shells by tier, up to a daily warm-up cap. Wrong answers can be retried until the prompt's time is up.
-- After a result the client asks for the next prompt (LobbyQuizSkip), no sooner than NextDelaySeconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnswerGate = require(ReplicatedStorage.Shared.AnswerGate)
local Depth = require(ReplicatedStorage.Shared.Depth)
local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local AnswerService = require(script.Parent.AnswerService)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local PlayerService = require(script.Parent.PlayerService)
local StoreService = require(script.Parent.StoreService)

local DAY_SECONDS = 86400
local ZONE_POLL = 0.25 -- seconds between checks of who stands in the zone

-- Match answer pacing, but the lobby's own slack after the prompt's timer.
local GATE_CONFIG: AnswerGate.Config = table.freeze({
	CheckMinInterval = GameConfig.Answer.CheckMinInterval,
	RetryCooldown = GameConfig.Answer.RetryCooldown,
	MaxChecksPerRound = GameConfig.Answer.MaxChecksPerRound,
	DeadlineGrace = GameConfig.Lobby.ExpiryGrace,
})

type Quiz = {
	prompt: AnswerService.Prompt,
	gate: AnswerGate.Gate,
	servedAt: number, -- os.clock()
	resultAt: number?, -- set once the answer is graded; the prompt is done
}

local current: { [Player]: Quiz } = {}
local recent: { [Player]: { string } } = {} -- last RecentMemory prompt ids, oldest first
local serveTokens: { [Player]: number } = {}
local livePromptId: string? = nil
local inZone: { [Player]: boolean } = {}
local dismissed: { [Player]: boolean } = {} -- closed with the X; stays quiet until they leave and come back

local LobbyQuizService = {}

-- The UTC day number, the same one DataService and the quests use.
local function today(): number
	return math.floor(os.time() / DAY_SECONDS)
end

local function earnedToday(player: Player): number
	return DataService.lobbyEarnedToday(player, today())
end

local function remember(player: Player, promptId: string)
	local list = recent[player]
	if list == nil then
		list = {}
		recent[player] = list
	end
	table.insert(list, promptId)
	while #list > GameConfig.Lobby.RecentMemory do
		table.remove(list, 1)
	end
end

local function nextToken(player: Player): number
	local token = (serveTokens[player] or 0) + 1
	serveTokens[player] = token
	return token
end

local function serve(player: Player)
	nextToken(player)
	local exclude: { [string]: boolean } = {}
	if livePromptId ~= nil then
		exclude[livePromptId] = true
	end
	for _, id in recent[player] or {} do
		exclude[id] = true
	end
	local prompt = AnswerService.randomPrompt(exclude)
	local seconds = GameConfig.Lobby.QuizSeconds
	current[player] = {
		prompt = prompt,
		gate = AnswerGate.new(os.clock() + seconds),
		servedAt = os.clock(),
		resultAt = nil,
	}
	remember(player, prompt.id)
	local earned = earnedToday(player)
	local cap = GameConfig.Lobby.DailyShellCap
	Net.event("LobbyQuizPrompt"):FireClient(player, {
		promptId = prompt.id,
		prompt = prompt.prompt,
		seconds = seconds,
		earnedToday = earned,
		cap = cap,
		capped = earned >= cap, -- still playable, but pays nothing until tomorrow
	})
end

local function stop(player: Player)
	nextToken(player)
	current[player] = nil
	Net.event("LobbyQuizPrompt"):FireClient(player, nil)
end

-- The open prompt a player may answer right now, if any.
local function openQuiz(player: Player): Quiz?
	local quiz = current[player]
	if quiz == nil or quiz.resultAt ~= nil or PlayerService.isPlaying(player) then
		return nil
	end
	return quiz
end

-- The gate statuses a client can act on; anything else just hears "closed".
local function clientStatus(status: string): string
	if status == "cooldown" or status == "limit" or status == "closed" then
		return status
	end
	return "closed"
end

-- Enter once: is it in the bank, and how is it spelled? Never says the tier, and never pays.
local function onCheck(player: Player, text: any)
	local result = Net.event("LobbyQuizResult")
	local quiz = openQuiz(player)
	if quiz == nil then
		result:FireClient(player, { stage = "check", status = "closed", cash = 0 })
		return
	end
	local now = os.clock()
	local status = AnswerGate.check(quiz.gate, now, GATE_CONFIG)
	if status ~= "ok" then
		result:FireClient(player, { stage = "check", status = clientStatus(status), cash = 0 })
		return
	end
	local graded = if AnswerService.isValidText(text) then AnswerService.grade(text, quiz.prompt) else nil
	local valid = graded ~= nil and graded.tier ~= nil
	AnswerGate.noteCheck(quiz.gate, now, valid)
	if graded == nil or graded.tier == nil then
		result:FireClient(player, { stage = "check", status = "invalid", cash = 0 })
		return
	end
	result:FireClient(player, { stage = "check", status = "valid", corrected = graded.corrected, cash = 0 })
end

-- Enter again: re-grades, locks in and pays. Wrong answers are refused and the same prompt stays up.
local function onAnswer(player: Player, text: any)
	local result = Net.event("LobbyQuizResult")
	local quiz = openQuiz(player)
	if quiz == nil then
		result:FireClient(player, { stage = "submit", status = "closed", cash = 0 })
		return
	end
	local now = os.clock()
	local status = AnswerGate.canSubmit(quiz.gate, now, GATE_CONFIG)
	if status ~= "ok" then
		result:FireClient(player, { stage = "submit", status = clientStatus(status), cash = 0 })
		return
	end
	local graded = if AnswerService.isValidText(text) then AnswerService.grade(text, quiz.prompt) else nil
	if graded == nil or graded.tier == nil then
		AnswerGate.noteCheck(quiz.gate, now, false)
		result:FireClient(player, { stage = "submit", status = "invalid", cash = 0 })
		return
	end
	AnswerGate.lock(quiz.gate)
	quiz.resultAt = now

	-- Multiplier once, capped once, paid unmultiplied: VIP + 2x can never push past the daily cap.
	local day = today()
	local cap = GameConfig.Lobby.DailyShellCap
	local earned = DataService.lobbyEarnedToday(player, day)
	local cash, capped = 0, earned >= cap
	if DataService.isLoaded(player) then
		cash, capped = Economy.lobbyPayout(graded.points, StoreService.cashMultiplier(player), earned, cap)
		if cash > 0 then
			StoreService.grantShells(player, cash, "warmup")
			DataService.addLobbyEarned(player, day, cash)
		end
	end
	result:FireClient(player, {
		stage = "submit",
		status = "valid",
		tier = graded.tier,
		cash = cash,
		corrected = graded.corrected,
		capped = capped,
		depth = Depth.metres(graded.tier, graded.corrected),
		earnedToday = earned + cash,
		cap = cap,
	})
	MatchEvents.LobbyAnswered.fire(player, graded.tier, graded.points, quiz.prompt.id, graded.corrected)
end

-- SKIP on an open prompt, or NEXT after a result. Prompts cannot be cycled faster than the gaps below;
-- an early request is honoured when the gap is up, so the button never feels dead.
local function onSkip(player: Player)
	local quiz = current[player]
	if quiz == nil or PlayerService.isPlaying(player) then
		return
	end
	local readyAt = if quiz.resultAt ~= nil
		then quiz.resultAt + GameConfig.Lobby.NextDelaySeconds
		else quiz.servedAt + GameConfig.Answer.RetryCooldown
	local wait = readyAt - os.clock()
	if wait <= 0 then
		serve(player)
		return
	end
	local token = nextToken(player)
	task.delay(wait, function()
		if serveTokens[player] == token and current[player] == quiz and not PlayerService.isPlaying(player) then
			serve(player)
		end
	end)
end

-- The match's prompt must not double as anyone's warm-up: its answers would show up in the reveal.
-- Prompt ids any of these players warmed up on recently, so a match never asks what they just practised.
function LobbyQuizService.recentPromptIds(players: { Player }): { [string]: boolean }
	local ids: { [string]: boolean } = {}
	for _, player in players do
		for _, id in recent[player] or {} do
			ids[id] = true
		end
	end
	return ids
end

-- The match is taking this player: their open prompt closes now, before the screen goes black.
function LobbyQuizService.stopFor(player: Player)
	if current[player] ~= nil then
		stop(player)
	end
end

function LobbyQuizService.setLivePromptId(id: string?)
	livePromptId = id
	if id == nil then
		return
	end
	for player, quiz in current do
		if quiz.prompt.id == id and quiz.resultAt == nil and not PlayerService.isPlaying(player) then
			serve(player)
		end
	end
end

-- The players whose character stands on the semicircle: within `Radius` of the zone's `ArcCenter`, on its
-- `Outward` side (the flat edge runs along the shack front), and not far above or below the deck.
local ZONE_HEIGHT = 6

local function playersInZone(zone: BasePart): { [Player]: boolean }
	local inside: { [Player]: boolean } = {}
	local center = zone:GetAttribute("ArcCenter")
	local outward = zone:GetAttribute("Outward")
	local radius = zone:GetAttribute("Radius")
	if typeof(center) ~= "Vector3" or typeof(outward) ~= "Vector3" or typeof(radius) ~= "number" then
		return inside
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local offset = root.Position - center
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if math.abs(offset.Y) <= ZONE_HEIGHT and flat.Magnitude <= radius and flat:Dot(outward) >= 0 then
			inside[player] = true
		end
	end
	return inside
end

local function pollZone(zone: BasePart)
	local inside = playersInZone(zone)
	for _, player in Players:GetPlayers() do
		local was = inZone[player] == true
		local now = inside[player] == true and not PlayerService.isPlaying(player)
		if now and not was then
			inZone[player] = true
			if not dismissed[player] then
				serve(player)
			end
		elseif was and not now then
			inZone[player] = nil
			dismissed[player] = nil
			if current[player] ~= nil then
				stop(player)
			end
		end
	end
end

-- The X on the quiz: quiet until they step out and back in.
local function onStop(player: Player)
	if current[player] ~= nil then
		stop(player)
	end
	if inZone[player] then
		dismissed[player] = true
	end
end

function LobbyQuizService.start()
	if GameConfig.Lobby.QuizEnabled ~= 1 then
		return
	end
	Net.event("LobbyQuizCheck").OnServerEvent:Connect(onCheck)
	Net.event("LobbyQuizAnswer").OnServerEvent:Connect(onAnswer)
	Net.event("LobbyQuizSkip").OnServerEvent:Connect(onSkip)
	Net.event("LobbyQuizStop").OnServerEvent:Connect(onStop)

	-- A match takes over: the quiz stops the moment the player is put on a pillar.
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Playing"):Connect(function()
			if PlayerService.isPlaying(player) and current[player] ~= nil then
				stop(player)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
		recent[player] = nil
		serveTokens[player] = nil
		inZone[player] = nil
		dismissed[player] = nil
	end)
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 60)
		local zone = if lobby ~= nil then lobby:WaitForChild("QuizZone", 60) else nil
		if zone == nil or not zone:IsA("BasePart") then
			warn("LobbyQuizService: Workspace.Lobby.QuizZone is missing; the warm-up quiz is off")
			return
		end
		while true do
			pollZone(zone)
			task.wait(ZONE_POLL)
		end
	end)
end

return LobbyQuizService
