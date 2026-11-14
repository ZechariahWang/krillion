--!strict
-- Every remote is a RemoteEvent under ReplicatedStorage.Remotes; code only looks them up.
-- The original remotes are authored in Studio. Remotes added for the Sink or Niche port are in git as
-- src/ReplicatedStorage/Remotes/<Name>.model.json (the folder keeps unknown Studio children), so Rojo
-- ships them with the code that uses them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

export type RoundStatePayload = {
	phase: string, -- "Waiting" | "Intermission" | "Starting" | "Prompt" | "Reveal" | "Surge" | "Results"
	round: number,
	secondsLeft: number,
	yourSecondsLeft: number?, -- this player's own time when it differs from secondsLeft (a +10s boost, overtime)
	overtime: boolean, -- the prompt is running past its base time because someone bought extra time
	alive: number,
	aliveUserIds: { number },
	lockedUserIds: { number }, -- who has locked in an answer this prompt
	prompt: string?,
	promptId: string?,
	playing: boolean, -- is the receiving player on a platform this match
	lateJoinOpen: boolean, -- the receiving player may jump into the running match now
	playerCount: number,
	readyCount: number, -- players with a living character who are not AFK: what the match actually waits on
	minPlayers: number,
	starting: number, -- players who started the current match
	height: number,
	waterY: number,
	surge: number, -- how far the water rises at the end of this round
	surging: boolean, -- the Surge broadcast sent before the water rises; false on the settled one and on mid-surge updates
	settled: boolean, -- the Surge broadcast sent once the water has stopped; false on mid-surge updates
	special: string?, -- "TidalWave" | "DoubleLift" | nil
}

export type RevealRow = {
	userId: number, -- negative for bots
	name: string,
	answer: string?, -- the bank spelling of the accepted answer, nil when there was none
	tier: string?, -- nil when no accepted answer
	points: number,
	lift: number,
	height: number,
	depth: number, -- metres on the dive card (Depth.metres); 0 with no answer
	oneIn: number?, -- real "1 in N players" from recorded answers, nil until there is enough data
	schooled: number?, -- how many players gave this same answer, when 2 or more
	newBest: boolean?, -- true when this dive is the player's deepest ever
}

export type RevealPayload = {
	round: number,
	rows: { RevealRow },
}

-- AnswerResult: stage "check" answers an Enter-to-check, stage "submit" answers a lock-in.
export type AnswerResultPayload = {
	stage: string, -- "check" | "submit"
	status: string?, -- "valid" | "invalid" | "cooldown" | "limit" | "closed"
	accepted: boolean?, -- submit only
	corrected: string?, -- the bank spelling; never the tier
}

export type LobbyQuizPromptPayload = {
	promptId: string,
	prompt: string,
	seconds: number,
	earnedToday: number, -- warm-up Shells paid today, before this prompt
	cap: number, -- GameConfig.Lobby.DailyShellCap
	capped: boolean, -- still playable, but pays nothing until tomorrow
}

export type LobbyQuizResultPayload = {
	stage: string?, -- "check" | "submit"
	status: string?, -- check: "valid" | "invalid" | "cooldown" | "limit" | "closed"; submit: the same, "valid" on success
	tier: string?,
	cash: number,
	corrected: string?,
	capped: boolean?, -- today's warm-up cap is reached; graded but paid 0
	depth: number?,
	earnedToday: number?, -- warm-up Shells paid today, including this answer
	cap: number?,
}

export type DeepestDive = {
	userId: number, -- negative for bots
	name: string,
	answer: string,
	tier: string,
	metres: number,
	round: number,
}

export type MatchEndedPayload = {
	solo: boolean,
	rounds: number,
	winnerName: string,
	winnerUserId: number?, -- nil when nobody won or the winner has left
	podium: { { name: string, points: number } },
	deepest: DeepestDive?, -- the match's deepest dive; nil when nobody had an accepted answer
	seconds: number,
}

export type BoostUses = { Hint: number, ExtraTime: number }

export type BoostResultPayload = {
	kind: string, -- "Hint" | "ExtraTime"
	status: string, -- "ok" | "no_shells" | "no_hints" | "limit" | "closed" | "not_playing" | "locked" | "none" | "disabled" | "pending" | "stocked" (a Robux boost that landed too late to use: it is in the inventory)
	hint: string?, -- e.g. "A MYTHIC  |  JABUTICABA"
	secondsLeft: number?,
	uses: BoostUses, -- used this round
}

export type JoinResultPayload = {
	status: string, -- "joined" | "closed" | "full" | "already" | "not_ready"
	message: string,
}

export type NotifyPayload = {
	text: string,
	kind: string, -- "info" | "good" | "bad" | "mythic" | "hint"
}

export type ShellsEarnedPayload = {
	amount: number, -- negative for a spend
	reason: string?, -- "answer" | "survive" | "win" | "warmup" | "quest" | "reward" | "purchase" | "spend"
}

-- ProfileChanged. Pass and other service fields are merged in from DataService.addExtraPayload providers.
export type ProfilePayload = {
	cash: number,
	wins: number,
	best: number,
	deepest: number, -- metres of your deepest match dive ever
	deepestAnswer: string,
	revives: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	hints: number,
	extraTimes: number,
	tutorialDone: boolean,
	claimed: { [string]: boolean },
	referrals: number,
	quests: { day: number, progress: { [string]: number }, done: { [string]: boolean } },
	lobbyEarnedToday: number,
	krillions: number,
	games: number,
	passes: { [string]: boolean }?,
	chestsAllowed: boolean?, -- false where paid random items are restricted (ChestService)
}

-- ChestResult: what a ChestOpen gave. status "ok" carries the item; others say why nothing opened.
export type ChestResultPayload = {
	chest: string,
	status: string, -- "ok" | "no_shells" | "cooldown" | "limit" | "restricted" | "unknown" (policy not answered yet) | "refunded"
	item: string?,
	duplicate: boolean?,
	refund: number?, -- Shells paid back for a duplicate
}

-- DailyResult: what a DailyClaim did.
export type DailyResultPayload = {
	status: string, -- "ok" | "claimed" (today's is already claimed) | "closed" (off, or the profile is not ready)
	index: number?, -- which day of the week was claimed
	shells: number?,
	chest: string?, -- the chest opened for free, if that day has one (its ChestResult follows)
}

-- ShopResult: why a Shells buy did or did not go through.
export type ShopResultPayload = {
	status: string, -- "ok" | "cash" | "owned" | "unknown"
}

-- ToyHit (to every client): a lobby throw. `to` is the target's UserId; the toy lands after FlightSeconds.
export type ToyHitPayload = {
	from: number,
	to: number,
	toy: string, -- Templates.Toys child name
}

-- RevivePrompt: kind "free" (Second Chance), "stock" (a revive you own) or "buy" (Revive Now, Robux).
export type RevivePromptPayload = {
	seconds: number,
	revives: number,
	kind: string?,
	robux: number?, -- Revive Now's price, for kind "buy"
	productId: number?, -- Revive Now's product, for kind "buy"
}

local Net = {}

function Net.event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
