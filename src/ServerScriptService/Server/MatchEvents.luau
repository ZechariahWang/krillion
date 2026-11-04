--!strict
-- Match moments other services react to (payouts, quests, rewards, stats) without RoundService knowing them.
-- RoundService and LobbyQuizService fire these; everyone else only connects. Handlers run synchronously
-- on the match loop (see Signal): anything that yields (DataStores, waits) must task.spawn itself.
-- Bots never fire these: every `player` argument is a real Player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local MatchEvents = {
	-- (participants: { Player }) after pillars are spawned and everyone is placed.
	MatchStarted = Signal.new("MatchStarted"),
	-- (prompt: { id: string, prompt: string }, round: number, players: { Player }, seconds: number)
	-- right after AnswerService.openRound: per-round resets (boost uses), stats prefetch.
	PromptOpened = Signal.new("PromptOpened"),
	-- (player: Player) a late joiner got a pillar in the running match.
	PlayerJoinedMatch = Signal.new("PlayerJoinedMatch"),
	-- (player: Player, tier: string?, points: number, promptId: string, answer: string?) once per alive
	-- player at each reveal; tier and answer are nil when they gave no accepted answer.
	AnswerGraded = Signal.new("AnswerGraded"),
	-- (player: Player, round: number) for each player still afloat after a surge.
	RoundSurvived = Signal.new("RoundSurvived"),
	-- (player: Player, round: number) when the water takes a player (or they fall off).
	PlayerSank = Signal.new("PlayerSank"),
	-- (participants: { Player }, winner: Player?, countsAsWin: boolean, rounds: number) at the end of a
	-- match, before MatchEnded goes to clients. Participants still in the server only.
	MatchFinished = Signal.new("MatchFinished"),
	-- (player: Player, tier: string, points: number, promptId: string, corrected: string) for an accepted
	-- warm-up answer in the lobby.
	LobbyAnswered = Signal.new("LobbyAnswered"),
}

return MatchEvents
