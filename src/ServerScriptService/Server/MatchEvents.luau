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
	-- when a question opens: per-question resets (boost uses), stats prefetch. `seconds` is 0: the fuse is hidden.
	PromptOpened = Signal.new("PromptOpened"),
	-- (player: Player, tier: string?, points: number, promptId: string, answer: string?) each time a
	-- player's answer is accepted and the crab moves on.
	AnswerGraded = Signal.new("AnswerGraded"),
	-- (player: Player, round: number) for each player still in after a pinch.
	RoundSurvived = Signal.new("RoundSurvived"),
	-- (player: Player, round: number) when a player is out: no hearts left, or they fell in.
	PlayerSank = Signal.new("PlayerSank"),
	-- (participants: { Player }, winner: Player?, countsAsWin: boolean, rounds: number) at the end of a
	-- match, before MatchEnded goes to clients. Participants still in the server only.
	MatchFinished = Signal.new("MatchFinished"),
	-- (player: Player, tier: string, points: number, promptId: string, corrected: string) for an accepted
	-- warm-up answer in the lobby.
	LobbyAnswered = Signal.new("LobbyAnswered"),
}

return MatchEvents
