--!strict
-- Pure maths behind the "About 1 in N players" footer: per-prompt answer counts, merged and read safely.
-- AnswerStatsService stores one Counts per prompt id in a DataStore; everything here is Lune-safe.

local AnswerMatcher = require("./AnswerMatcher")

export type Counts = {
	total: number, -- accepted answers recorded for the prompt
	counts: { [string]: number }, -- normalized answer -> how many gave it
}

local AnswerStats = {}

function AnswerStats.empty(): Counts
	return { total = 0, counts = {} }
end

-- The counts key for an answer, so "The Beatles!" and "the beatles" land on the same entry.
function AnswerStats.key(answer: string): string
	return AnswerMatcher.normalize(answer)
end

-- A whole, non-negative count from anything a DataStore hands back (nil, NaN, strings become 0).
local function whole(value: any): number
	if typeof(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- A clean copy of a stored value. Unknown shapes become empty rather than erroring in a transform.
function AnswerStats.sanitize(value: any): Counts
	local result = AnswerStats.empty()
	if typeof(value) ~= "table" then
		return result
	end
	local sum = 0
	if typeof(value.counts) == "table" then
		for answer, count in value.counts do
			local n = whole(count)
			if typeof(answer) == "string" and answer ~= "" and n > 0 then
				result.counts[answer] = n
				sum += n
			end
		end
	end
	-- The total can never be smaller than the answers it covers.
	result.total = math.max(whole(value.total), sum)
	return result
end

-- stored + delta as a new table; neither input is changed, so it is safe inside an UpdateAsync transform
-- that Roblox may call more than once.
function AnswerStats.mergeCounts(stored: any, delta: any): Counts
	local result = AnswerStats.sanitize(stored)
	local add = AnswerStats.sanitize(delta)
	result.total += add.total
	for answer, n in add.counts do
		result.counts[answer] = (result.counts[answer] or 0) + n
	end
	return result
end

-- Adds one answer to a buffer in place.
function AnswerStats.record(counts: Counts, answer: string)
	local key = AnswerStats.key(answer)
	if key == "" then
		return
	end
	counts.total += 1
	counts.counts[key] = (counts.counts[key] or 0) + 1
end

function AnswerStats.countFor(counts: Counts, answer: string): number
	return counts.counts[AnswerStats.key(answer)] or 0
end

-- About how many players give an answer: nil below minTotal recorded answers (too little data to be honest).
-- (total + 1) / (count + 1) counts the player being shown as one more giver, so an answer nobody had
-- given yet reads as 1 in total + 1. Never below 2: "1 in 1" would mean everyone said it.
function AnswerStats.oneIn(total: number, count: number, minTotal: number): number?
	if total < minTotal or total <= 0 then
		return nil
	end
	local given = math.clamp(count, 0, total)
	return math.max(2, math.floor((total + 1) / (given + 1)))
end

function AnswerStats.oneInFor(counts: Counts, answer: string, minTotal: number): number?
	return AnswerStats.oneIn(counts.total, AnswerStats.countFor(counts, answer), minTotal)
end

-- One line for the debug "stats" command: "412 answers: beatles 120, queen 80 (+9 more)".
function AnswerStats.describe(counts: Counts, limit: number): string
	local rows: { { answer: string, n: number } } = {}
	for answer, n in counts.counts do
		table.insert(rows, { answer = answer, n = n })
	end
	table.sort(rows, function(a, b)
		if a.n ~= b.n then
			return a.n > b.n
		end
		return a.answer < b.answer
	end)
	local parts = {}
	for i = 1, math.min(limit, #rows) do
		table.insert(parts, rows[i].answer .. " " .. rows[i].n)
	end
	local text = string.format("%d answers", counts.total)
	if #parts > 0 then
		text ..= ": " .. table.concat(parts, ", ")
	end
	if #rows > limit then
		text ..= string.format(" (+%d more)", #rows - limit)
	end
	return text
end

return table.freeze(AnswerStats)
