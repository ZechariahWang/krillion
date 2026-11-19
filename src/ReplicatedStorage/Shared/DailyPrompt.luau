--!strict
-- Prompt of the Day: which prompt a UTC day gets (the same everywhere, never yesterday's), the answer streak,
-- and the worldwide share of an answer. Pure, so Lune tests can require it. Numbers are GameConfig.DailyPrompt.
local GameConfig = require("../Config/GameConfig")
local AnswerStats = require("./AnswerStats")

local RULES = GameConfig.DailyPrompt
local MODULUS = 2147483647
local MULTIPLIER = 48271
local WARMUP = 3 -- neighbouring days start almost equal; a few steps pull them apart

export type TopAnswer = { answer: string, count: number }

local DailyPrompt = {}

-- MINSTD seeded by the day: exact in doubles, so Lune and Roblox pick the same prompt.
local function rawPick(day: number, sorted: { string }): string
	local state = (math.floor(day) % (MODULUS - 1)) + 1
	for _ = 1, WARMUP do
		state = (state * MULTIPLIER) % MODULUS
	end
	return sorted[(state % #sorted) + 1]
end

-- The prompt id for `day` out of `ids` (any order). Never the one the day before had.
function DailyPrompt.pick(day: number, ids: { string }): string
	local sorted = table.clone(ids)
	table.sort(sorted)
	local chosen = rawPick(day, sorted)
	if #sorted < 2 then
		return chosen
	end
	if chosen == rawPick(day - 1, sorted) then
		local index = table.find(sorted, chosen) :: number
		chosen = sorted[(index % #sorted) + 1]
	end
	return chosen
end

-- The streak after answering on `day`, given the last day answered and the streak then.
function DailyPrompt.nextStreak(lastDay: number, streak: number, day: number): number
	if lastDay == day then
		return streak
	end
	if lastDay == day - 1 then
		return streak + 1
	end
	return 1
end

function DailyPrompt.chestDue(streak: number): boolean
	return streak > 0 and streak % RULES.ChestEvery == 0
end

-- Days of answering still needed for the next chest (a full cycle right after one).
function DailyPrompt.daysToChest(streak: number): number
	return RULES.ChestEvery - (streak % RULES.ChestEvery)
end

-- Percent of all answers that were `answer`, or nil below MinTotal answers.
function DailyPrompt.share(counts: AnswerStats.Counts, answer: string): number?
	if counts.total < RULES.MinTotal or counts.total <= 0 then
		return nil
	end
	return 100 * AnswerStats.countFor(counts, answer) / counts.total
end

function DailyPrompt.shareText(percent: number): string
	if percent > 0 and percent < 1 then
		return "<1%"
	end
	return tostring(math.floor(percent + 0.5)) .. "%"
end

-- The `n` most given answers, most first, ties in name order.
function DailyPrompt.top(counts: AnswerStats.Counts, n: number): { TopAnswer }
	local rows: { TopAnswer } = {}
	for answer, count in counts.counts do
		table.insert(rows, { answer = answer, count = count })
	end
	table.sort(rows, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.answer < b.answer
	end)
	local result: { TopAnswer } = {}
	for index = 1, math.min(n, #rows) do
		table.insert(result, rows[index])
	end
	return result
end

return DailyPrompt
