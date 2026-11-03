--!strict
local GameConfig = require("../Config/GameConfig")
local Tiers = require("../Config/Tiers")

export type Prompt = {
	id: string,
	prompt: string,
	answers: { [string]: { string } }, -- tier name -> accepted answers (already normalized)
	aliases: { [string]: string }, -- alias -> canonical answer
}

local AnswerMatcher = {}

function AnswerMatcher.normalize(text: string): string
	local result = string.lower(text)
	result = string.gsub(result, "[%p]", "")
	result = string.gsub(result, "%s+", " ")
	result = string.match(result, "^%s*(.-)%s*$") :: string
	return result
end

-- Edit distance where inserting, deleting or changing a letter costs 1, and so does swapping two
-- neighbouring letters (the most common typo).
function AnswerMatcher.distance(a: string, b: string): number
	local rows: { { number } } = {}
	for i = 0, #a do
		local row = {}
		for j = 0, #b do
			row[j] = 0
		end
		row[0] = i
		rows[i] = row
	end
	for j = 0, #b do
		rows[0][j] = j
	end
	for i = 1, #a do
		for j = 1, #b do
			local cost = 1
			if string.sub(a, i, i) == string.sub(b, j, j) then
				cost = 0
			end
			local deletion = rows[i - 1][j] + 1
			local insertion = rows[i][j - 1] + 1
			local substitution = rows[i - 1][j - 1] + cost
			local best = math.min(deletion, insertion, substitution)
			local swapped = i > 1
				and j > 1
				and string.sub(a, i, i) == string.sub(b, j - 1, j - 1)
				and string.sub(a, i - 1, i - 1) == string.sub(b, j, j)
			if swapped then
				best = math.min(best, rows[i - 2][j - 2] + 1)
			end
			rows[i][j] = best
		end
	end
	return rows[#a][#b]
end

-- How many typos an answer of this length may have and still count.
local function allowedTypos(answer: string): number
	if #answer < GameConfig.Answer.FuzzyMinLength then
		return 0
	end
	if #answer < GameConfig.Answer.FuzzyLongLength then
		return 1
	end
	return 2
end

local function findExact(prompt: Prompt, answer: string): string?
	for _, tier in Tiers.List do
		local accepted = prompt.answers[tier.name]
		if accepted ~= nil then
			for _, candidate in accepted do
				if candidate == answer then
					return tier.name
				end
			end
		end
	end
	return nil
end

-- The bank answer with the fewest typos, if any is within the allowance.
local function findClosest(prompt: Prompt, answer: string): (string?, string?)
	local bestTier = nil
	local bestAnswer = nil
	local bestDistance = allowedTypos(answer) + 1
	for _, tier in Tiers.List do
		local accepted = prompt.answers[tier.name]
		if accepted ~= nil then
			for _, candidate in accepted do
				local distance = AnswerMatcher.distance(candidate, answer)
				if distance < bestDistance then
					bestDistance = distance
					bestTier = tier.name
					bestAnswer = candidate
				end
			end
		end
	end
	return bestTier, bestAnswer
end

-- Returns the tier and the bank spelling for an accepted answer, or nil when it is refused.
-- The bank spelling is what autocorrect shows back to the player.
function AnswerMatcher.resolve(text: string, prompt: Prompt): (string?, string?)
	local answer = AnswerMatcher.normalize(text)
	if #answer == 0 or #answer > GameConfig.Answer.MaxLength then
		return nil, nil
	end
	local canonical = prompt.aliases[answer]
	if canonical ~= nil then
		answer = canonical
	end
	local exact = findExact(prompt, answer)
	if exact ~= nil then
		return exact, answer
	end
	return findClosest(prompt, answer)
end

function AnswerMatcher.match(text: string, prompt: Prompt): string?
	local tier = AnswerMatcher.resolve(text, prompt)
	return tier
end

return AnswerMatcher
