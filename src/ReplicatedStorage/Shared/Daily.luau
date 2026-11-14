--!strict
-- The daily reward: one claim per UTC day. Claiming on consecutive days walks through GameConfig.Daily.Days
-- and starts over after the last; missing a day starts again at day 1. Pure, so Lune tests can require it.
local GameConfig = require("../Config/GameConfig")

-- What is saved in the profile: the UTC day number of the last claim (0 for never) and which day of the
-- cycle that claim was.
export type State = {
	day: number,
	streak: number,
}

export type Reward = {
	shells: number,
	chest: string?, -- a Config/Chests id opened for free
}

local DAY_SECONDS = 86400

local Daily = {}

function Daily.new(): State
	return { day = 0, streak = 0 }
end

-- The UTC day number for a time in seconds (os.time()); the same day Quests.day gives.
function Daily.today(now: number): number
	return math.floor(now / DAY_SECONDS)
end

-- Whole seconds until the next UTC day starts.
function Daily.secondsLeft(now: number): number
	return DAY_SECONDS - (math.floor(now) % DAY_SECONDS)
end

function Daily.canClaim(state: State, today: number): boolean
	return state.day < today
end

-- Which day of the cycle a claim made today would be: the one after yesterday's, or day 1 when yesterday
-- was missed (or nothing was ever claimed).
function Daily.nextIndex(state: State, today: number): number
	local days = #GameConfig.Daily.Days
	if state.day == today - 1 and state.streak >= 1 then
		return (state.streak % days) + 1
	end
	return 1
end

-- The day of the cycle to show as "today": the one already claimed today, else the one waiting.
function Daily.shownIndex(state: State, today: number): number
	if state.day == today and state.streak >= 1 then
		return state.streak
	end
	return Daily.nextIndex(state, today)
end

function Daily.reward(index: number): Reward
	return GameConfig.Daily.Days[index]
end

-- Claims today's reward. Returns the new state and which day of the cycle it was, or nil when today's is
-- already claimed.
function Daily.claim(state: State, today: number): (State?, number?)
	if not Daily.canClaim(state, today) then
		return nil, nil
	end
	local index = Daily.nextIndex(state, today)
	return { day = today, streak = index }, index
end

return table.freeze(Daily)
