--!strict
-- The answer collection: each prompt's best match answer and its tier, when a prompt counts as mastered,
-- and the milestones (GameConfig.Collection) that mastering pays. Pure, so Lune tests can require it.
local GameConfig = require("../Config/GameConfig")
local Tiers = require("../Config/Tiers")

export type Card = {
	tier: string,
	answer: string,
}

-- One album entry, as the server sends it: the prompt and the rarest tier its bank has.
export type Entry = {
	id: string,
	prompt: string,
	top: string,
}

export type Milestone = {
	id: string,
	count: number?,
	all: boolean?,
	shells: number,
	title: string?,
}

local Collection = {}

-- Whether an answer in `tier` should replace `card`: only a strictly rarer tier does.
function Collection.better(card: Card?, tier: string?): boolean
	local index = Tiers.index(tier)
	if index == 0 then
		return false
	end
	if card == nil then
		return true
	end
	return index > Tiers.index(card.tier)
end

-- The rarest tier with at least one answer, or nil for an empty bank entry.
function Collection.topTier(answers: { [string]: { string } }): string?
	local best: string? = nil
	for _, tier in Tiers.List do
		local list = answers[tier.name]
		if list ~= nil and #list > 0 then
			best = tier.name
		end
	end
	return best
end

function Collection.isMastered(card: Card?, top: string): boolean
	if card == nil then
		return false
	end
	return Tiers.index(card.tier) >= Tiers.index(top)
end

-- How many album prompts have a card, and how many of those are mastered.
function Collection.counts(cards: { [string]: Card }, catalogue: { Entry }): (number, number)
	local found = 0
	local mastered = 0
	for _, entry in catalogue do
		local card = cards[entry.id]
		if card ~= nil then
			found += 1
			if Collection.isMastered(card, entry.top) then
				mastered += 1
			end
		end
	end
	return found, mastered
end

-- The claim id of a milestone, kept in profile.claimed once paid.
function Collection.idOf(raw: { [string]: any }): string
	if raw.all == true then
		return "CollectAll"
	end
	return "Collect" .. tostring(raw.count)
end

local function milestones(): { Milestone }
	local result: { Milestone } = {}
	for _, raw in GameConfig.Collection.Milestones :: { any } do
		table.insert(result, {
			id = Collection.idOf(raw),
			count = raw.count,
			all = raw.all,
			shells = raw.shells,
			title = raw.title,
		})
	end
	return result
end

-- The mastered count a milestone needs, or nil when the album is too small to ever reach it.
local function needs(milestone: Milestone, total: number): number?
	if milestone.all == true then
		return total
	end
	local count = milestone.count or 0
	if count > total then
		return nil
	end
	return count
end

-- Every milestone `mastered` out of `total` has reached.
function Collection.reached(mastered: number, total: number): { Milestone }
	local result: { Milestone } = {}
	for _, milestone in milestones() do
		local need = needs(milestone, total)
		if need ~= nil and total > 0 and mastered >= need then
			table.insert(result, milestone)
		end
	end
	return result
end

-- The first milestone not yet reached, or nil when every reachable one is.
function Collection.nextMilestone(mastered: number, total: number): Milestone?
	for _, milestone in milestones() do
		local need = needs(milestone, total)
		if need ~= nil and mastered < need then
			return milestone
		end
	end
	return nil
end

-- The mastered count `milestone` needs in an album of `total`.
function Collection.needFor(milestone: Milestone, total: number): number
	return needs(milestone, total) or total
end

return Collection
