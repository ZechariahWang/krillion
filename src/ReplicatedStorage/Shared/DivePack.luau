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

local SINK_POWER = 1.7 -- the pack starts slowly and gathers speed
local LAND_SHARE = 0.6 -- a tag counts as landed once the pack is this share of `soft` past its resting place
local OWN_LANE_ROOM = 2 -- spacings of push another tag takes on before it joins your lane

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

-- Metres of the pack's front `elapsed` seconds in: it drifts down from `sky` metres above the surface over
-- `dropSeconds`, coming to rest on the water, then sinks to `reach` over `sinkSeconds`, gathering speed.
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
	local u = math.min((elapsed - dropSeconds) / sinkSeconds, 1)
	return reach * u ^ SINK_POWER
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
	return dropSeconds + sinkSeconds * math.min(needed / reach, 1) ^ (1 / SINK_POWER)
end

return table.freeze(DivePack)
