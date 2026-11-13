--!strict
-- Daily quests: the pool, each player's seeded draw for a UTC day, and progress rules. The server and
-- the client draw the same list from (userId, day), so only progress is saved. Pure, so Lune tests can
-- require it (no Random: a hand-rolled generator keeps the draw identical everywhere).
local GameConfig = require("../Config/GameConfig")

export type Quest = {
	id: string,
	kind: string, -- the event that advances it (QuestService.advance)
	text: string,
	goal: number,
	reward: number, -- Shells, paid as stated (no pass multiplier)
}

local DAY_SECONDS = 86400
local RARE_INDEX = 4 -- Tiers.List index of Rare
local DEEP_INDEX = 5 -- DeepCut
-- Park-Miller "minimal standard" generator: state * 16807 stays far below 2^53, so it is exact in doubles.
local MODULUS = 2147483647
local MULTIPLIER = 16807
local WARMUP = 4 -- neighbouring seeds (tomorrow's) start almost equal; a few steps pull them apart

local pool: { Quest } = {
	{ id = "play_match", kind = "match_played", text = "PLAY 1 MATCH", goal = 1, reward = 75 },
	{ id = "play_3", kind = "match_played", text = "PLAY 3 MATCHES", goal = 3, reward = 175 },
	{ id = "survive_5", kind = "round_survived", text = "SURVIVE 5 ROUNDS", goal = 5, reward = 125 },
	{ id = "rare_2", kind = "rare_answer", text = "GIVE 2 RARE+ ANSWERS", goal = 2, reward = 125 },
	{ id = "deep_1", kind = "deep_answer", text = "GIVE A DEEP CUT+ ANSWER", goal = 1, reward = 150 },
	{ id = "warmup_5", kind = "practice_answer", text = "ANSWER 5 WARM-UPS", goal = 5, reward = 100 },
	{ id = "minutes_10", kind = "play_seconds", text = "PLAY FOR 10 MINUTES", goal = 600, reward = 100 },
	{ id = "win_1", kind = "match_won", text = "WIN A MATCH", goal = 1, reward = 250 },
}

local byId: { [string]: Quest } = {}
for _, quest in pool do
	table.freeze(quest)
	byId[quest.id] = quest
end

-- What draw picks from: the warm-up quest only while the lobby quiz is on, or it could never be finished.
-- ById keeps every quest so saved progress on a dropped one still resolves.
local drawable: { Quest } = {}
for _, quest in pool do
	if quest.kind ~= "practice_answer" or GameConfig.Lobby.QuizEnabled == 1 then
		table.insert(drawable, quest)
	end
end

local Quests = {
	Pool = table.freeze(pool),
	Drawable = table.freeze(drawable),
	ById = table.freeze(byId),
}

-- The UTC day number for a Unix time. Quests reset when it changes.
function Quests.day(now: number): number
	return math.floor(now / DAY_SECONDS)
end

-- Whole seconds until the next UTC day starts.
function Quests.secondsLeft(now: number): number
	return math.max(0, (Quests.day(now) + 1) * DAY_SECONDS - math.floor(now))
end

local function newGenerator(seed: number): () -> number
	local state = seed % MODULUS
	if state == 0 then
		state = 1
	end
	local function nextValue(): number
		state = (state * MULTIPLIER) % MODULUS
		return state
	end
	for _ = 1, WARMUP do
		nextValue()
	end
	return nextValue
end

-- The player's quests for `day`, always the same for the same (userId, day). Different kinds first, so
-- one match never finishes two quests at once while another kind is available.
function Quests.draw(userId: number, day: number, count: number?): { Quest }
	local wanted = math.min(count or GameConfig.Quests.PerDay, #drawable)
	local nextValue = newGenerator(userId * 31 + day)
	local shuffled = table.clone(drawable)
	for i = #shuffled, 2, -1 do
		local j = nextValue() % i + 1
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local picked: { Quest } = {}
	local usedKinds: { [string]: boolean } = {}
	local usedIds: { [string]: boolean } = {}
	for _, quest in shuffled do
		if #picked >= wanted then
			break
		end
		if not usedKinds[quest.kind] then
			usedKinds[quest.kind] = true
			usedIds[quest.id] = true
			table.insert(picked, quest)
		end
	end
	for _, quest in shuffled do
		if #picked >= wanted then
			break
		end
		if not usedIds[quest.id] then
			usedIds[quest.id] = true
			table.insert(picked, quest)
		end
	end
	return picked
end

-- New progress after `amount` more of the quest's kind, clamped at the goal. justDone is true only on the
-- step that reaches the goal, so a finished quest never pays twice.
function Quests.advance(progress: number, quest: Quest, amount: number): (number, boolean)
	if progress >= quest.goal then
		return quest.goal, false
	end
	if amount ~= amount or amount <= 0 then
		return progress, false
	end
	local nextProgress = math.min(quest.goal, progress + amount)
	return nextProgress, nextProgress >= quest.goal
end

-- Quest kinds an answer of this tier counts toward (Tiers.index: 4 Rare, 5 Deep Cut, 6 Mythic).
function Quests.kindsForTier(tierIndex: number): { string }
	local kinds = {}
	if tierIndex >= RARE_INDEX then
		table.insert(kinds, "rare_answer")
	end
	if tierIndex >= DEEP_INDEX then
		table.insert(kinds, "deep_answer")
	end
	return kinds
end

-- "2/5", or "4/10 MIN" for play-time quests.
function Quests.progressText(quest: Quest, progress: number): string
	local shown = math.clamp(progress, 0, quest.goal)
	if quest.kind == "play_seconds" then
		return string.format("%d/%d MIN", math.floor(shown / 60), math.floor(quest.goal / 60))
	end
	return string.format("%d/%d", math.floor(shown), quest.goal)
end

-- "5H 12M", "12M", or "1M" for the last minute.
function Quests.resetText(seconds: number): string
	local minutes = math.max(1, math.ceil(seconds / 60))
	local hours = math.floor(minutes / 60)
	minutes -= hours * 60
	if hours > 0 then
		return string.format("%dH %dM", hours, minutes)
	end
	return string.format("%dM", minutes)
end

return table.freeze(Quests)
