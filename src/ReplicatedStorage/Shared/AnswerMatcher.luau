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

function AnswerMatcher.distance(a: string, b: string): number
	local previous = {}
	for j = 0, #b do
		previous[j] = j
	end
	for i = 1, #a do
		local current = { [0] = i }
		for j = 1, #b do
			local cost = 1
			if string.sub(a, i, i) == string.sub(b, j, j) then
				cost = 0
			end
			local deletion = previous[j] + 1
			local insertion = current[j - 1] + 1
			local substitution = previous[j - 1] + cost
			current[j] = math.min(deletion, insertion, substitution)
		end
		previous = current
	end
	return previous[#b]
end

local function findTier(prompt: Prompt, answer: string): string?
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

local function findFuzzyTier(prompt: Prompt, answer: string): string?
	for _, tier in Tiers.List do
		local accepted = prompt.answers[tier.name]
		if accepted ~= nil then
			for _, candidate in accepted do
				if AnswerMatcher.distance(candidate, answer) <= GameConfig.Answer.FuzzyMaxDistance then
					return tier.name
				end
			end
		end
	end
	return nil
end

-- Returns the tier name for an accepted answer, or nil when it is refused.
function AnswerMatcher.match(text: string, prompt: Prompt): string?
	local answer = AnswerMatcher.normalize(text)
	if #answer == 0 or #answer > GameConfig.Answer.MaxLength then
		return nil
	end
	local canonical = prompt.aliases[answer]
	if canonical ~= nil then
		answer = canonical
	end
	local exact = findTier(prompt, answer)
	if exact ~= nil then
		return exact
	end
	if #answer < GameConfig.Answer.FuzzyMinLength then
		return nil
	end
	return findFuzzyTier(prompt, answer)
end

return AnswerMatcher
