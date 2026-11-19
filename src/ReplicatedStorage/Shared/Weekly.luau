--!strict
-- The weekly wins board: which week it is (weeks start Monday 00:00 UTC), how long until it resets, the
-- store that holds each week, and a player's rank in the top list. Pure, so Lune tests can require it.

local DAY = 86400
local WEEK = 7 * DAY
local MONDAY_OFFSET = 4 * DAY -- 1970-01-01 was a Thursday; the first Monday was 4 days later
local STORE_PREFIX = "WeeklyWins_v1_"

export type Entry = { userId: number, wins: number }

local Weekly = {}

function Weekly.week(now: number): number
	return math.floor((now - MONDAY_OFFSET) / WEEK)
end

function Weekly.secondsLeft(now: number): number
	local nextStart = (Weekly.week(now) + 1) * WEEK + MONDAY_OFFSET
	return nextStart - now
end

-- Studio writes its own store, so test wins never reach the live board.
function Weekly.storeName(week: number, studio: boolean): string
	local name = STORE_PREFIX .. week
	if studio then
		name = name .. "_Studio"
	end
	return name
end

function Weekly.resetText(seconds: number): string
	local minutes = math.max(1, math.floor(seconds / 60))
	local hours = math.floor(minutes / 60)
	local days = math.floor(hours / 24)
	if days >= 1 then
		return "RESETS IN " .. days .. "D " .. (hours % 24) .. "H"
	end
	if hours >= 1 then
		return "RESETS IN " .. hours .. "H " .. (minutes % 60) .. "M"
	end
	return "RESETS IN " .. minutes .. "M"
end

-- 1-based place of `userId` in `top` (best first), or nil when they are not in it.
function Weekly.rankOf(top: { Entry }, userId: number): number?
	for index, entry in top do
		if entry.userId == userId then
			return index
		end
	end
	return nil
end

return Weekly
