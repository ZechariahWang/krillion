--!strict
-- A personal prompt stream for anyone in the lobby. Answering is two steps like a match: LobbyQuizCheck
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

function LobbyQuizService.start()
	if GameConfig.Lobby.QuizEnabled ~= 1 then
		return
	end
	Net.event("LobbyQuizCheck").OnServerEvent:Connect(onCheck)
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
		recent[player] = nil
		serveTokens[player] = nil
	end)
end

return LobbyQuizService
