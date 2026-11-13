--!strict
-- Rules for the in-match boosts: the masked hint text, which bank answer a hint gives away, and the
-- per-round and per-match limits. Pure, so Lune tests can require it.
local GameConfig = require("../Config/GameConfig")
local Tiers = require("../Config/Tiers")

export type Uses = { Hint: number, ExtraTime: number }

export type Usage = {
	round: Uses,
	match: Uses,
}

export type Limits = {
	Enabled: number,
	PerRound: number,
	PerMatch: number,
}

local SHORT_WORD = 3 -- words this short only show their first letter
local WIDEN_TRIES = 2 -- a hint widens its tier range by one on each side at most this many times

local Boosts = {}

function Boosts.newUses(): Uses
	return { Hint = 0, ExtraTime = 0 }
end

-- "antigua and barbuda" -> "Antigua And Barbuda". Bank answers are stored normalized (lowercase).
function Boosts.titleCase(normalized: string): string
	return (string.gsub(normalized, "(%S)(%S*)", function(first: string, rest: string)
		return string.upper(first) .. rest
	end))
end

-- Characters of a word, UTF-8 aware; an invalid string falls back to its ASCII bytes.
local function charsOf(text: string): { string }
	local chars = {}
	if utf8.len(text) ~= nil then
		for _, code in utf8.codes(text) do
			table.insert(chars, utf8.char(code))
		end
		return chars
	end
	for index = 1, #text do
		local ch = string.sub(text, index, index)
		if string.byte(ch) < 128 then
			table.insert(chars, ch)
		end
	end
	return chars
end

-- Letters and digits are hidden and counted; anything else ("-", "'") stays visible as a clue.
local function isLetter(ch: string): boolean
	return #ch > 1 or string.match(ch, "^%w$") ~= nil
end

-- "mandoline" -> "M _ _ _ _ _ _ _ E (9 letters)". Each word shows its first and last letter (only the
-- first for words of 3 letters or fewer); characters are spaced, words are three spaces apart.
function Boosts.mask(display: string): string
	local words: { string } = {}
	local total = 0
	for word in string.gmatch(display, "%S+") do
		local chars = charsOf(word)
		local letters = 0
		local first: number? = nil
		local last: number? = nil
		for index, ch in chars do
			if isLetter(ch) then
				letters += 1
				first = first or index
				last = index
			end
		end
		total += letters
		if letters <= SHORT_WORD then
			last = first
		end
		local shown = {}
		for index, ch in chars do
			if index == first or index == last then
				table.insert(shown, string.upper(ch))
			elseif isLetter(ch) then
				table.insert(shown, "_")
			else
				table.insert(shown, ch)
			end
		end
		table.insert(words, table.concat(shown, " "))
	end
	if total == 0 then
		return display
	end
	local unit = if total == 1 then "letter" else "letters"
	return string.format("%s (%d %s)", table.concat(words, "   "), total, unit)
end

-- "A DEEP CUT  |  M _ _ _ _ _ _ _ E (9 letters)"
function Boosts.hintText(tierLabel: string, display: string): string
	return "A " .. string.upper(tierLabel) .. "  |  " .. Boosts.mask(display)
end

-- The limits for one player: Boost Plus holders get PerMatchPlus uses of each boost per match.
function Boosts.limitsFor(hasBoostPlus: boolean): Limits
	local base = GameConfig.Boosts
	return {
		Enabled = base.Enabled,
		PerRound = base.PerRound,
		PerMatch = if hasBoostPlus then base.PerMatchPlus else base.PerMatch,
	}
end

-- "ok" | "disabled" | "limit" for one more boost of `kind`.
function Boosts.canUse(usage: Usage, kind: string, cfg: Limits?): string
	local limits: Limits = cfg or GameConfig.Boosts
	if limits.Enabled == 0 then
		return "disabled"
	end
	local round = if kind == "Hint" then usage.round.Hint else usage.round.ExtraTime
	local match = if kind == "Hint" then usage.match.Hint else usage.match.ExtraTime
	if round >= limits.PerRound or match >= limits.PerMatch then
		return "limit"
	end
	return "ok"
end

-- Records one use of `kind` in both the round and the match counts.
function Boosts.noteUse(usage: Usage, kind: string)
	if kind == "Hint" then
		usage.round.Hint += 1
		usage.match.Hint += 1
	else
		usage.round.ExtraTime += 1
		usage.match.ExtraTime += 1
	end
end

-- Picks the answer a hint gives away: one from tiers minTier..maxTier (Tiers.List indices) that is not
-- in `excluded` (answers locked in this round, answers already hinted to this player). With none left it
-- widens by a tier on each side, but never up to the top tier, so a hint never hands over the best
-- answer. `roll` in [0, 1) picks within the pool, so the same roll gives the same answer.
-- Returns the display spelling, the tier name and the bank answer, or nil when nothing qualifies.
function Boosts.pickHint(
	answersByTier: { [string]: { string } },
	minTier: number,
	maxTier: number,
	excluded: { [string]: boolean },
	roll: number
): (string?, string?, string?)
	local ceiling = #Tiers.List - 1
	for widen = 0, WIDEN_TRIES do
		local low = math.max(1, minTier - widen)
		local high = math.min(ceiling, maxTier + widen)
		local pool: { { answer: string, tier: string } } = {}
		for index = low, high do
			local tier = Tiers.List[index]
			for _, answer in answersByTier[tier.name] or {} do
				if not excluded[answer] then
					table.insert(pool, { answer = answer, tier = tier.name })
				end
			end
		end
		if #pool > 0 then
			local pick = pool[math.clamp(math.floor(roll * #pool) + 1, 1, #pool)]
			return Boosts.titleCase(pick.answer), pick.tier, pick.answer
		end
	end
	return nil, nil, nil
end

return table.freeze(Boosts)
