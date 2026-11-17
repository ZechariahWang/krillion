--!strict
-- The pack of answer tags that sinks together on a dive card (Client/DiveCard): which lane and row each tag
-- takes, where the front of the pack is at a moment, and where one tag is then. Tags in a lane sink in a line,
-- the deepest answer in front and each next one `spacing` behind it, and each stops at its own depth. So two
-- tags in a lane are never closer than `spacing`, at any moment, and the motion has no jumps.
-- No Roblox APIs here, so Lune tests can require it.

export type Slot = {
	lane: number, -- 1..lanes
	row: number, -- 0 for the deepest tag in its lane, then 1, 2... for the ones behind (above) it
	final: number, -- metres where the tag comes to rest: its depth, or lower when its lane is crowded there
}

-- The sink is a wind-up, then a burst. For HOLD_SHARE of it the pack only creeps CREEP_METRES under the surface;
-- then it launches, at full speed within the first sixth of the burst (LAUNCH_POWER), and eases off towards
-- the deepest answer (GLIDE_POWER) while keeping CARRY of its speed, so even the last tag lands with a thud.
local HOLD_SHARE = 0.3
local CREEP_METRES = 5
local LAUNCH_POWER = 1.35
local GLIDE_POWER = 4
local CARRY = 0.35
local LAND_STEPS = 40 -- halvings when a landing time is searched for
local LAND_SHARE = 0.6 -- a tag counts as landed once the pack is this share of `soft` past its resting place
local OWN_LANE_ROOM = 2 -- spacings of push another tag takes on before it joins your lane
local DIP_SECONDS = 0.7 -- your tag's plunge past its resting place and back
local REBOUND_SECONDS = 0.45 -- then it springs up a little past its place
local REBOUND_SHARE = 0.2 -- of the plunge

local DivePack = {}

-- A minimum of `a` and `b` with the corner rounded over `k` either side: `a` while it is well below `b`,
-- `b` once it is well above, and a smooth slow-down in between. Never above either.
function DivePack.softMin(a: number, b: number, k: number): number
	if k <= 0 then
		return math.min(a, b)
	end
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end

-- A lane, a row and a resting depth for every tag. Each tag takes the lane where it rests nearest its own
-- depth; among equals, `own` (your tag's index) takes the middle lane and the others take the emptiest lane,
-- sides first. With three lanes or more the others keep out of your lane unless it saves them a push of more
-- than OWN_LANE_ROOM spacings, so your tag is rarely queued behind another. Tags in one lane rest at least
-- `spacing` apart, so a crowded lane pushes its deeper tags down.
function DivePack.layout(depths: { number }, lanes: number, spacing: number, own: number?): { Slot }
	local count = math.max(1, math.floor(lanes))
	local middle = math.ceil(count / 2)
	local order: { number } = {}
	for index = 1, #depths do
		order[index] = index
	end
	table.sort(order, function(a: number, b: number): boolean
		if depths[a] ~= depths[b] then
			return depths[a] < depths[b]
		end
		return a < b
	end)

	local deepest: { number } = table.create(count, -math.huge) -- the lowest resting place in each lane so far
	local sizes: { number } = table.create(count, 0)
	local slots: { Slot } = table.create(#depths)
	for _, index in order do
		local bestLane = 1
		local bestPush = math.huge
		local bestCost = math.huge
		local bestRank = math.huge
		for lane = 1, count do
			local push = math.max(depths[index], deepest[lane] + spacing) - depths[index]
			local cost = push
			if own ~= nil and index ~= own and lane == middle and count >= 3 then
				cost += OWN_LANE_ROOM * spacing
			end
			local rank: number
			if index == own then
				rank = math.abs(lane - middle)
			else
				-- Emptiest lane first, then away from the middle (yours), then the outer lanes.
				rank = sizes[lane] * count * 2
				if own ~= nil and lane == middle then
					rank += count
				end
				rank += count - math.abs(lane - middle)
			end
			if cost < bestCost - 1e-6 or (cost <= bestCost + 1e-6 and rank < bestRank) then
				bestLane = lane
				bestPush = push
				bestCost = cost
				bestRank = rank
			end
		end
		local final = depths[index] + bestPush
		slots[index] = { lane = bestLane, row = 0, final = final }
		deepest[bestLane] = final
		sizes[bestLane] += 1
	end

	-- Rows count up from the deepest tag in each lane.
	local seen: { number } = table.create(count, 0)
	for position = #order, 1, -1 do
		local slot = slots[order[position]]
		slot.row = seen[slot.lane]
		seen[slot.lane] += 1
	end
	return slots
end

-- How far the front of the pack must travel so that every tag has come to rest: `soft` past the deepest one.
function DivePack.reach(slots: { Slot }, soft: number): number
	local deepest = 0
	for _, slot in slots do
		deepest = math.max(deepest, slot.final)
	end
	return deepest + soft
end

-- How much of `sinkSeconds` is the wind-up before the burst.
function DivePack.holdSeconds(sinkSeconds: number): number
	return HOLD_SHARE * sinkSeconds
end

-- Metres of the pack's front `elapsed` seconds in: it drifts down from `sky` metres above the surface over
-- `dropSeconds`, coming to rest on the water; winds up, creeping just under the surface; then bursts down to
-- `reach`. The wind-up and the burst together take `sinkSeconds`. It never goes back up and never jumps: it
-- is still for an instant where the drop, the wind-up and the burst meet.
function DivePack.front(elapsed: number, dropSeconds: number, sinkSeconds: number, reach: number, sky: number): number
	if elapsed <= 0 then
		return -sky
	end
	if elapsed < dropSeconds then
		local left = 1 - elapsed / dropSeconds
		return -sky * left * left
	end
	if sinkSeconds <= 0 then
		return reach
	end
	local creep = math.min(CREEP_METRES, 0.4 * reach)
	local hold = HOLD_SHARE * sinkSeconds
	local since = elapsed - dropSeconds
	if since < hold then
		local left = 1 - since / hold
		return creep * (1 - left * left)
	end
	local u = math.min((since - hold) / (sinkSeconds - hold), 1)
	local launched = u ^ LAUNCH_POWER
	return creep + (reach - creep) * ((1 - CARRY) * (1 - (1 - launched) ^ GLIDE_POWER) + CARRY * launched)
end

-- Metres of one tag when the pack's front is at `front`: its place in the line, slowing over `soft` metres
-- into its resting place.
function DivePack.position(front: number, slot: Slot, spacing: number, soft: number): number
	return DivePack.softMin(front - slot.row * spacing, slot.final, soft)
end

-- Whether the tag has (all but) come to rest.
function DivePack.landed(front: number, slot: Slot, spacing: number, soft: number): boolean
	return front - slot.row * spacing >= slot.final + LAND_SHARE * soft
end

-- Seconds your tag's plunge and rebound take, from its landing.
function DivePack.overshootSeconds(): number
	return DIP_SECONDS + REBOUND_SECONDS
end

-- How far up the rebound goes, as a share of the plunge.
function DivePack.reboundShare(): number
	return REBOUND_SHARE
end

-- Metres your tag is drawn below its resting place `since` seconds after it lands: it keeps going down by
-- `amplitude`, comes back up a little past its place, and settles there.
function DivePack.overshoot(since: number, amplitude: number): number
	if since <= 0 or since >= DivePack.overshootSeconds() then
		return 0
	end
	if since < DIP_SECONDS then
		return amplitude * math.sin(math.pi * since / DIP_SECONDS)
	end
	local after = since - DIP_SECONDS
	return -REBOUND_SHARE * amplitude * math.sin(math.pi * after / REBOUND_SECONDS)
end

-- The largest plunge your tag (slots[own]) can take without coming within `spacing` of another tag in its
-- lane: the one resting below it, or (on the rebound) the one behind it. math.huge when it is alone.
function DivePack.overshootRoom(slots: { Slot }, own: number, spacing: number): number
	local mine = slots[own]
	local room = math.huge
	for index, slot in slots do
		if index ~= own and slot.lane == mine.lane then
			if slot.final > mine.final then
				room = math.min(room, slot.final - mine.final - spacing)
			else
				room = math.min(room, (mine.final - slot.final - spacing) / REBOUND_SHARE)
			end
		end
	end
	return math.max(room, 0)
end

-- Seconds until `landed` turns true for the tag, with the same numbers as `front`.
function DivePack.landSeconds(
	slot: Slot,
	spacing: number,
	soft: number,
	dropSeconds: number,
	sinkSeconds: number,
	reach: number
): number
	local needed = slot.final + LAND_SHARE * soft + slot.row * spacing
	if needed <= 0 or reach <= 0 then
		return dropSeconds
	end
	-- The front only ever sinks, so the moment it passes `needed` can be closed in on.
	local low = dropSeconds
	local high = dropSeconds + sinkSeconds
	for _ = 1, LAND_STEPS do
		local middle = (low + high) / 2
		if DivePack.front(middle, dropSeconds, sinkSeconds, reach, 0) >= needed then
			high = middle
		else
			low = middle
		end
	end
	return high
end

return table.freeze(DivePack)
