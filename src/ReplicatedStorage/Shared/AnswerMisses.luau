--!strict
-- Refused answers, counted per prompt, so the bank can be given what players really type. Pure and
-- Lune-safe; AnswerMissService stores one Counts per prompt id in a DataStore.
-- Only short answer-like text is kept, as counts with no player attached. Long text, sentences, numbers of
-- five digits or more, addresses (an @ or a web ending) and keyboard mashing are dropped, which keeps out
-- most chat and contact details. What is left is whatever a player typed as an answer, rude words included:
-- it is only ever shown to the owner by the debug command, which can also remove an entry.

local AnswerMatcher = require("./AnswerMatcher")
local AnswerStats = require("./AnswerStats")

export type Counts = AnswerStats.Counts
export type Row = { answer: string, n: number }

local MIN_LENGTH = 2
local MAX_LENGTH = 30 -- characters, after normalizing; bank answers run to 40 but a miss that long is a sentence
local MAX_WORDS = 4
local MAX_DIGITS = 4 -- in the whole text: more is a phone number or an id, never an answer
local MASH = "(.)%1%1%1" -- the same character four times running
-- Raw text holding one of these is an email, a link or a handle, not an answer.
local ADDRESS_MARKS = { "@", "http", "www%.", "%.com", "%.net", "%.org", "%.gg", "%.io", "%.me", "%.tv", "%.co%f[%A]" }

local AnswerMisses = {}

function AnswerMisses.empty(): Counts
	return AnswerStats.empty()
end

-- The counts key for refused text, or nil when it is not worth keeping.
function AnswerMisses.key(text: string): string?
	local raw = string.lower(text)
	for _, mark in ADDRESS_MARKS do
		if string.find(raw, mark) ~= nil then
			return nil
		end
	end
	local key = AnswerMatcher.normalize(text)
	if #key < MIN_LENGTH or #key > MAX_LENGTH then
		return nil
	end
	local _, digits = string.gsub(key, "%d", "")
	if digits > MAX_DIGITS or string.find(key, MASH) ~= nil then
		return nil
	end
	if not string.find(key, "%a") then
		return nil
	end
	local words = 0
	for _ in string.gmatch(key, "%S+") do
		words += 1
	end
	if words > MAX_WORDS then
		return nil
	end
	return key
end

-- Adds one refused answer to a buffer in place. False when the text is not kept.
function AnswerMisses.record(counts: Counts, text: string): boolean
	local key = AnswerMisses.key(text)
	if key == nil then
		return false
	end
	counts.total += 1
	counts.counts[key] = (counts.counts[key] or 0) + 1
	return true
end

-- Most refused first; ties in alphabetical order so the result never depends on table order.
local function sorted(counts: Counts): { Row }
	local rows: { Row } = {}
	for answer, n in counts.counts do
		table.insert(rows, { answer = answer, n = n })
	end
	table.sort(rows, function(a, b)
		if a.n ~= b.n then
			return a.n > b.n
		end
		return a.answer < b.answer
	end)
	return rows
end

-- stored + delta as a new table holding at most `cap` different answers, so one prompt's entry stays small
-- however long the game runs. Over the cap every count drops by one and the answers that reach zero go:
-- one-off junk washes out, a full table always has room for a newcomer, and an answer many players type
-- keeps climbing. Counts are therefore "at least this many"; the total keeps counting every miss.
-- Neither input is changed, so it is safe inside an UpdateAsync transform that may run more than once.
function AnswerMisses.merge(stored: any, delta: any, cap: number): Counts
	local merged = AnswerStats.mergeCounts(stored, delta)
	local size = 0
	for _ in merged.counts do
		size += 1
	end
	while size > cap do
		local kept: { [string]: number } = {}
		size = 0
		for answer, n in merged.counts do
			if n > 1 then
				kept[answer] = n - 1
				size += 1
			end
		end
		merged.counts = kept
	end
	return merged
end

-- A copy of the stored value without `answer` (as typed or as stored). The total is left alone.
function AnswerMisses.without(stored: any, answer: string): Counts
	local result = AnswerStats.sanitize(stored)
	result.counts[AnswerMatcher.normalize(answer)] = nil
	return result
end

-- The most refused answers, at most `limit`, each refused at least `minCount` times and passing `keep`
-- (the service passes "the bank still refuses it", so answers added since drop out of the list).
function AnswerMisses.top(counts: Counts, limit: number, minCount: number, keep: ((string) -> boolean)?): { Row }
	local rows: { Row } = {}
	for _, row in sorted(counts) do
		if #rows >= limit or row.n < minCount then
			break
		end
		if keep == nil or keep(row.answer) then
			table.insert(rows, row)
		end
	end
	return rows
end

-- One line for the debug "misses" command: "412 refused: spork 31, exuberant 12".
function AnswerMisses.describe(total: number, rows: { Row }): string
	local parts = {}
	for _, row in rows do
		table.insert(parts, row.answer .. " " .. row.n)
	end
	local text = string.format("%d refused", total)
	if #parts > 0 then
		text ..= ": " .. table.concat(parts, ", ")
	end
	return text
end

return table.freeze(AnswerMisses)
