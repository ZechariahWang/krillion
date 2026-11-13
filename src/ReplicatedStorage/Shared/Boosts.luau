--!strict
-- Rules for the in-match boosts: the hint text, which bank answer a hint gives away, and the
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

-- "A DEEP CUT  |  MANDOLINE": the tier, then the whole answer.
function Boosts.hintText(tierLabel: string, display: string): string
	return "A " .. string.upper(tierLabel) .. "  |  " .. string.upper(display)
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

-- Picks the answer a hint gives away: one from the highest tier (Mythic first) that still has an answer
-- not in `excluded` (answers locked in this round), dropping a tier at a time. `roll` in [0, 1) picks
-- within the tier, so the same roll gives the same answer.
-- Returns the display spelling, the tier name and the bank answer, or nil when nothing qualifies.
function Boosts.pickHint(
	answersByTier: { [string]: { string } },
	excluded: { [string]: boolean },
	roll: number
): (string?, string?, string?)
	for index = #Tiers.List, 1, -1 do
		local tier = Tiers.List[index]
		local pool: { string } = {}
		for _, answer in answersByTier[tier.name] or {} do
			if not excluded[answer] then
				table.insert(pool, answer)
			end
		end
		if #pool > 0 then
			local pick = pool[math.clamp(math.floor(roll * #pool) + 1, 1, #pool)]
			return Boosts.titleCase(pick), tier.name, pick
		end
	end
	return nil, nil, nil
end

return table.freeze(Boosts)
