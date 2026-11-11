--!strict
-- Every remote is a RemoteEvent under ReplicatedStorage.Remotes; code only looks them up.
-- The original remotes are authored in Studio. Remotes added for the Sink or Niche port are in git as
-- src/ReplicatedStorage/Remotes/<Name>.model.json (the folder keeps unknown Studio children), so Rojo
-- ships them with the code that uses them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

export type RingRow = {
	userId: number, -- negative for bots
	name: string,
	hearts: number, -- 0 once they are out
}

export type RoundStatePayload = {
	phase: string, -- "Waiting" | "Intermission" | "Starting" | "Prompt" | "Reveal" | "Results"
	round: number, -- the question number
	secondsLeft: number, -- the countdown outside a question; the fuse is never sent
	alive: number,
	aliveUserIds: { number },
	prompt: string?,
	promptId: string?,
	playing: boolean, -- is the receiving player still in this match
	holderUserId: number?, -- who holds the crab
	mood: string, -- "Calm" | "Restless" | "Furious": all a client learns about the fuse
	ring: { RingRow }, -- everyone in the match, clockwise
	used: { string }, -- answers the current question has used up, in order
	meter: number, -- the receiving player's points towards an extra heart
	meterTarget: number,
	maxHearts: number,
	playerCount: number,
	readyCount: number, -- players with a living character who are not AFK: what the match actually waits on
	minPlayers: number,
	starting: number, -- players who started the current match
}

-- CrabPassed: the holder's answer was accepted and the crab moved on.
export type CrabPassedPayload = {
	fromUserId: number,
	toUserId: number?,
	answer: string, -- the bank spelling
	tier: string?,
	points: number,
	gainedHeart: boolean,
}

-- CrabPinched: the fuse ran out on the holder.
export type CrabPinchedPayload = {
	userId: number,
	hearts: number, -- what they have left
	eliminated: boolean,
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
}

export type RevealPayload = {
	round: number,
	rows: { RevealRow },
}

-- AnswerResult: the reply to SubmitAnswer.
export type AnswerResultPayload = {
	stage: string, -- "submit"
	status: string?, -- when refused: "invalid" | "used" | "cooldown" | "limit" | "closed"
	accepted: boolean?,
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

export type MatchEndedPayload = {
	solo: boolean,
	rounds: number,
	winnerName: string,
	winnerUserId: number?, -- nil when nobody won or the winner has left
	podium: { { name: string, points: number } },
	seconds: number,
}

export type BoostUses = { Hint: number, ExtraTime: number }

export type BoostResultPayload = {
	kind: string, -- "Hint" | "ExtraTime"
	status: string, -- "ok" | "no_shells" | "limit" | "closed" | "not_playing" | "locked" | "none" | "disabled" | "pending"
	hint: string?, -- e.g. "A DEEP CUT  |  M _ _ _ _ _ _ _ E (9 letters)"
	secondsLeft: number?,
	uses: BoostUses, -- used this round
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
