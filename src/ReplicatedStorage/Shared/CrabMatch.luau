--!strict
-- Pure match model for Crab Craze: who is in, their hearts and meters, who holds the crab, which answers the
-- current question has used up, and the fuse. Ids are any value (UserId in game, strings in tests). Random
-- rolls (0 to 1) are passed in so every rule is testable. No Roblox APIs here.

local GameConfig = require("../Config/GameConfig")

local RULES = GameConfig.Crab

export type Match = {
	order: { any }, -- everyone who started and has not left, clockwise round the ring
	started: number, -- how many started, leavers included
	alive: { [any]: boolean },
	hearts: { [any]: number },
	meter: { [any]: number }, -- answer points towards the next extra heart
	holder: any?,
	used: { [string]: boolean }, -- answers the current question has used up
	usedList: { string }, -- the same answers, in the order they were given
	fuse: number, -- seconds until the crab pinches; the server never sends this to clients
	pinches: number, -- questions finished so far
	out: { any }, -- everyone out of the match, first out first
}

export type PassResult = {
	to: any,
	gainedHeart: boolean,
}

export type PinchResult = {
	id: any,
	hearts: number,
	eliminated: boolean,
}

local CrabMatch = {}

local putOut: (match: Match, id: any) -> ()

function CrabMatch.rollFuse(roll: number): number
	return RULES.FuseMinSeconds + (RULES.FuseMaxSeconds - RULES.FuseMinSeconds) * roll
end

function CrabMatch.new(order: { any }, holderRoll: number, fuseRoll: number): Match
	local match: Match = {
		order = table.clone(order),
		started = #order,
		alive = {},
		hearts = {},
		meter = {},
		holder = nil,
		used = {},
		usedList = {},
		fuse = CrabMatch.rollFuse(fuseRoll),
		pinches = 0,
		out = {},
	}
	for _, id in order do
		match.alive[id] = true
		match.hearts[id] = RULES.StartHearts
		match.meter[id] = 0
	end
	local index = math.floor(holderRoll * #order) + 1
	if index > #order then
		index = #order
	end
	match.holder = order[index]
	return match
end

function CrabMatch.aliveCount(match: Match): number
	local count = 0
	for _, id in match.order do
		if match.alive[id] then
			count += 1
		end
	end
	return count
end

-- The next player still in, clockwise from `from`. With nobody else in, it is `from` itself (if still in).
function CrabMatch.nextHolder(match: Match, from: any): any?
	local start = table.find(match.order, from)
	if start == nil then
		return nil
	end
	local count = #match.order
	for step = 1, count do
		local id = match.order[(start - 1 + step) % count + 1]
		if match.alive[id] then
			return id
		end
	end
	return nil
end

function CrabMatch.isUsed(match: Match, answer: string): boolean
	return match.used[answer] == true
end

-- Takes a player out of the match. If they held the crab, the next player still in holds it.
function putOut(match: Match, id: any)
	match.alive[id] = false
	match.hearts[id] = 0
	table.insert(match.out, id)
	if match.holder == id then
		match.holder = CrabMatch.nextHolder(match, id)
	end
end

-- A player fell in or died mid-match: out at once, whatever hearts they had.
function CrabMatch.eliminate(match: Match, id: any)
	if match.alive[id] ~= true then
		return
	end
	putOut(match, id)
end

-- A player left the server: gone from the ring and the ranking.
function CrabMatch.remove(match: Match, id: any)
	local index = table.find(match.order, id)
	if index == nil then
		return
	end
	if match.holder == id then
		local nextId = CrabMatch.nextHolder(match, id)
		match.holder = if nextId ~= id then nextId else nil
	end
	table.remove(match.order, index)
	match.alive[id] = nil
	match.hearts[id] = nil
	match.meter[id] = nil
	local outIndex = table.find(match.out, id)
	if outIndex ~= nil then
		table.remove(match.out, outIndex)
	end
end

-- The holder gave an accepted answer worth `points`: it is used up, their meter fills, the fuse is topped
-- up and the crab moves on.
function CrabMatch.pass(match: Match, answer: string, points: number): PassResult
	local holder = match.holder
	match.used[answer] = true
	table.insert(match.usedList, answer)
	local gainedHeart = false
	local meter = match.meter[holder] + points
	if meter >= RULES.MeterTarget then
		if match.hearts[holder] < RULES.MaxHearts then
			match.hearts[holder] += 1
			meter -= RULES.MeterTarget
			gainedHeart = true
		else
			meter = RULES.MeterTarget
		end
	end
	match.meter[holder] = meter
	if match.fuse < RULES.MinTurnSeconds then
		match.fuse = RULES.MinTurnSeconds
	end
	local nextId = CrabMatch.nextHolder(match, holder)
	match.holder = nextId
	return { to = nextId, gainedHeart = gainedHeart }
end

-- Burns `seconds` off the fuse. True once it has run out.
function CrabMatch.tick(match: Match, seconds: number): boolean
	match.fuse -= seconds
	return match.fuse <= 0
end

function CrabMatch.addTime(match: Match, seconds: number)
	match.fuse += seconds
end

-- The fuse ran out on the holder: they lose a heart, the question's used answers are cleared and a new fuse
-- starts. They hold the crab again unless that was their last heart.
function CrabMatch.pinch(match: Match, fuseRoll: number): PinchResult
	local holder = match.holder
	local hearts = match.hearts[holder] - 1
	match.hearts[holder] = hearts
	local eliminated = hearts <= 0
	if eliminated then
		putOut(match, holder)
	end
	match.used = {}
	match.usedList = {}
	match.fuse = CrabMatch.rollFuse(fuseRoll)
	match.pinches += 1
	return { id = holder, hearts = hearts, eliminated = eliminated }
end

function CrabMatch.mood(match: Match): string
	if match.fuse <= RULES.FuriousSeconds then
		return "Furious"
	end
	if match.fuse <= RULES.RestlessSeconds then
		return "Restless"
	end
	return "Calm"
end

-- Puts a player who is out back in with the revive hearts. False if they are still in.
function CrabMatch.revive(match: Match, id: any): boolean
	if match.alive[id] ~= false then
		return false
	end
	match.alive[id] = true
	match.hearts[id] = RULES.ReviveHearts
	local index = table.find(match.out, id)
	if index ~= nil then
		table.remove(match.out, index)
	end
	if match.holder == nil then
		match.holder = id
	end
	return true
end

-- Two or more started: over when one is left. One started alone: over when they are out.
function CrabMatch.over(match: Match): boolean
	local alive = CrabMatch.aliveCount(match)
	if match.started <= 1 then
		return alive == 0
	end
	return alive <= 1
end

-- The last one standing, once a match of two or more is over.
function CrabMatch.winner(match: Match): any?
	if match.started <= 1 or CrabMatch.aliveCount(match) ~= 1 then
		return nil
	end
	for _, id in match.order do
		if match.alive[id] then
			return id
		end
	end
	return nil
end

-- Everyone, best first: those still in (ring order), then those out, last out first.
function CrabMatch.ranking(match: Match): { any }
	local ranking = {}
	for _, id in match.order do
		if match.alive[id] then
			table.insert(ranking, id)
		end
	end
	for index = #match.out, 1, -1 do
		table.insert(ranking, match.out[index])
	end
	return ranking
end

return CrabMatch
