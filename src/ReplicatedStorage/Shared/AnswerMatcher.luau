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

-- Accented letters (both cases) and the ASCII they fold to, so "Jalapeño" types the same as
-- "jalapeno". Curly apostrophes fold to nothing, like the straight one the punctuation pass drops.
local ACCENT_GROUPS = {
	{ "a", "àáâãäåāăąÀÁÂÃÄÅĀĂĄ" },
	{ "c", "çćčÇĆČ" },
	{ "d", "ďđðĎĐÐ" },
	{ "e", "èéêëēėęěÈÉÊËĒĖĘĚ" },
	{ "g", "ğĞ" },
	{ "i", "ìíîïīįıÌÍÎÏĪĮİ" },
	{ "l", "łľŁĽ" },
	{ "n", "ñńňÑŃŇ" },
	{ "o", "òóôõöøōőÒÓÔÕÖØŌŐ" },
	{ "r", "řŘ" },
	{ "s", "śšşșŚŠŞȘ" },
	{ "t", "ťţțŤŢȚ" },
	{ "u", "ùúûüūůűųÙÚÛÜŪŮŰŲ" },
	{ "y", "ýÿÝŸ" },
	{ "z", "źżžŹŻŽ" },
	{ "ae", "æÆ" },
	{ "oe", "œŒ" },
	{ "ss", "ß" },
	{ "th", "þÞ" },
	{ "", "’‘´" },
}

local accentMap: { [number]: string } = {}
for _, group in ACCENT_GROUPS do
	for _, codepoint in utf8.codes(group[2]) do
		accentMap[codepoint] = group[1]
	end
end

-- Folds text to ASCII. Any other non-ASCII character (an emoji, say) becomes a space.
local function foldAccents(text: string): string
	if utf8.len(text) == nil then
		-- Not valid UTF-8, so there are no characters to fold: drop every non-ASCII byte.
		return (string.gsub(text, "[\128-\255]", " "))
	end
	local parts = table.create(#text)
	for _, codepoint in utf8.codes(text) do
		local replacement = accentMap[codepoint]
		if replacement ~= nil then
			table.insert(parts, replacement)
		elseif codepoint < 128 then
			table.insert(parts, string.char(codepoint))
		else
			table.insert(parts, " ")
		end
	end
	return table.concat(parts)
end

-- Order matters: accents fold first, then "&" becomes "and" before the punctuation strip
-- would delete it.
function AnswerMatcher.normalize(text: string): string
	local result = string.lower(foldAccents(text))
	result = string.gsub(result, "&", " and ")
	result = string.gsub(result, "%+", " plus ")
	result = string.gsub(result, "#", " sharp ")
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

local ARTICLES = { "the ", "a ", "an " }

local function stripArticle(answer: string): string
	for _, article in ARTICLES do
		if #answer > #article and string.sub(answer, 1, #article) == article then
			return string.sub(answer, #article + 1)
		end
	end
	return answer
end

-- Plural spellings must leave a stem of at least this many letters, so "gas" stays "gas".
local MIN_STEM = 3

-- The answer and its singular guesses, most likely first. "s" is tried before "es" so "panes"
-- prefers "pane" over "pan"; "boxes" still reaches "box".
function AnswerMatcher.variants(answer: string): { string }
	local forms = { answer }
	local function add(form: string)
		if #form >= MIN_STEM and table.find(forms, form) == nil then
			table.insert(forms, form)
		end
	end
	local length = #answer
	if string.sub(answer, -3) == "ies" then
		add(string.sub(answer, 1, length - 3) .. "y")
	end
	if string.sub(answer, -1) == "s" and string.sub(answer, -2) ~= "ss" then
		add(string.sub(answer, 1, length - 1))
	end
	if string.sub(answer, -2) == "es" then
		add(string.sub(answer, 1, length - 2))
	end
	return forms
end

-- Fallback lookups after exact and alias, loosest last. Each turns an answer into the forms it
-- may be compared by; the bank side gets the same treatment, so "the moon" and "moon" meet
-- either way round, and so do "cherry" and "cherries".
local FOLDS: { (string) -> { string } } = {
	function(answer)
		return { stripArticle(answer) }
	end,
	function(answer)
		return AnswerMatcher.variants(stripArticle(answer))
	end,
	function(answer)
		local spaceless = string.gsub(stripArticle(answer), " ", "")
		return AnswerMatcher.variants(spaceless)
	end,
}

local function tierIndex(name: string): number
	for index, tier in Tiers.List do
		if tier.name == name then
			return index
		end
	end
	return math.huge
end

type Entry = { key: string, tier: string, spelling: string }
type Candidate = { forms: { string }, tier: string, spelling: string }

-- Every bank answer and alias, with the tier and bank spelling it stands for.
local function entries(prompt: Prompt): { Entry }
	local list: { Entry } = {}
	for _, tier in Tiers.List do
		local accepted = prompt.answers[tier.name]
		if accepted ~= nil then
			for _, candidate in accepted do
				table.insert(list, { tier = tier.name, spelling = candidate, key = candidate })
			end
		end
	end
	local aliasKeys: { string } = {}
	for alias in prompt.aliases do
		table.insert(aliasKeys, alias)
	end
	table.sort(aliasKeys)
	for _, alias in aliasKeys do
		local canonical = prompt.aliases[alias]
		local tier = findExact(prompt, canonical)
		if tier ~= nil then
			table.insert(list, { tier = tier, spelling = canonical, key = alias })
		end
	end
	return list
end

-- The first input form that any candidate shares wins; among candidates sharing it, the lowest tier.
local function findFolded(prompt: Prompt, answer: string): (string?, string?)
	local pool = entries(prompt)
	for _, fold in FOLDS do
		local folded: { Candidate } = {}
		for _, entry in pool do
			table.insert(folded, { forms = fold(entry.key), tier = entry.tier, spelling = entry.spelling })
		end
		for _, form in fold(answer) do
			local best: Candidate? = nil
			for _, candidate in folded do
				if table.find(candidate.forms, form) ~= nil then
					if best == nil or tierIndex(candidate.tier) < tierIndex(best.tier) then
						best = candidate
					end
				end
			end
			if best ~= nil then
				return best.tier, best.spelling
			end
		end
	end
	return nil, nil
end

-- Returns the tier and the bank spelling for an accepted answer, or nil when it is refused.
-- The bank spelling is what autocorrect shows back to the player.
-- Lookups run strictest first: exact, alias, then the article, plural and space-less fallbacks,
-- then typos. The existing pre-normalized bank entries therefore still match first.
function AnswerMatcher.resolve(text: string, prompt: Prompt): (string?, string?)
	local answer = AnswerMatcher.normalize(text)
	if #answer == 0 or #answer > GameConfig.Answer.MaxLength then
		return nil, nil
	end
	local exact = findExact(prompt, answer)
	if exact ~= nil then
		return exact, answer
	end
	local canonical = prompt.aliases[answer]
	if canonical ~= nil then
		local aliased = findExact(prompt, canonical)
		if aliased ~= nil then
			return aliased, canonical
		end
		answer = canonical
	end
	local tier, spelling = findFolded(prompt, answer)
	if tier ~= nil then
		return tier, spelling
	end
	return findClosest(prompt, answer)
end

function AnswerMatcher.match(text: string, prompt: Prompt): string?
	local tier = AnswerMatcher.resolve(text, prompt)
	return tier
end

return AnswerMatcher
