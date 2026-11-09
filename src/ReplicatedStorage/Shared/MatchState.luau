--!strict
-- Pure match model: who is alive, how high each platform is, where the water is.
-- Ids are any value (UserId in game, numbers in tests). No Roblox APIs here.

export type State = {
	startHeight: number,
	waterY: number,
	alive: { [any]: boolean },
	heights: { [any]: number },
	points: { [any]: number },
	lastCulled: { any }, -- everyone the current surge has taken, however it took them
	sunkOrder: { any }, -- everyone out of the match, first to sink first
}

local MatchState = {}

function MatchState.new(startHeight: number): State
	return {
		startHeight = startHeight,
		waterY = 0,
		alive = {},
		heights = {},
		points = {},
		lastCulled = {},
		sunkOrder = {},
	}
end

function MatchState.addPlayer(state: State, id: any)
	state.alive[id] = true
	state.heights[id] = state.startHeight
	state.points[id] = 0
end

-- A late joiner: alive on a pillar at `height` (not the start height), with no points yet.
function MatchState.addPlayerAt(state: State, id: any, height: number)
	state.alive[id] = true
	state.heights[id] = height
	state.points[id] = 0
end

-- The lowest pillar still in the match, or nil when nobody is alive.
function MatchState.lowestAlive(state: State): number?
	local lowest: number? = nil
	for id in state.alive do
		local height = state.heights[id]
		if height ~= nil and (lowest == nil or height < lowest) then
			lowest = height
		end
	end
	return lowest
end

local function removeFrom(list: { any }, id: any)
	local index = table.find(list, id)
	if index ~= nil then
		table.remove(list, index)
	end
end

function MatchState.removePlayer(state: State, id: any)
	state.alive[id] = nil
	state.heights[id] = nil
	state.points[id] = nil
	removeFrom(state.lastCulled, id)
	removeFrom(state.sunkOrder, id)
end

-- Out of the match by any route: the water poll, a reset, or the state cull.
function MatchState.eliminate(state: State, id: any)
	if state.alive[id] == nil then
		return
	end
	state.alive[id] = nil
	table.insert(state.lastCulled, id)
	table.insert(state.sunkOrder, id)
end

function MatchState.applyLift(state: State, id: any, points: number, lift: number)
	if state.heights[id] == nil then
		return
	end
	state.heights[id] += lift
	state.points[id] += points
end

-- A new surge: whoever it takes, by the poll or the cull below, is this surge's last cull.
function MatchState.surge(state: State, amount: number)
	state.waterY += amount
	state.lastCulled = {}
end

-- A new prompt: a player who sinks now (a reset) is judged on their own, not with the last surge's victims.
function MatchState.forgetCull(state: State)
	state.lastCulled = {}
end

function MatchState.cull(state: State): { any }
	local culled = {}
	for id in state.alive do
		if state.heights[id] < state.waterY then
			table.insert(culled, id)
		end
	end
	for _, id in culled do
		MatchState.eliminate(state, id)
	end
	return culled
end

-- Brings an eliminated player back `above` studs over the current water, keeping their points.
function MatchState.revive(state: State, id: any, above: number)
	if state.heights[id] == nil then
		return
	end
	state.alive[id] = true
	state.heights[id] = state.waterY + above
	removeFrom(state.lastCulled, id)
	removeFrom(state.sunkOrder, id)
end

function MatchState.aliveCount(state: State): number
	local count = 0
	for _ in state.alive do
		count += 1
	end
	return count
end

function MatchState.aliveIds(state: State): { any }
	local ids = {}
	for id in state.alive do
		table.insert(ids, id)
	end
	return ids
end

function MatchState.isOver(state: State): boolean
	return MatchState.aliveCount(state) <= 1
end

local function better(state: State, a: any, b: any): boolean
	if state.heights[a] ~= state.heights[b] then
		return state.heights[a] > state.heights[b]
	end
	if state.points[a] ~= state.points[b] then
		return state.points[a] > state.points[b]
	end
	return tostring(a) < tostring(b)
end

-- Everyone in the match, best first: the afloat by height and points, then the sunk, last to sink first.
function MatchState.ranking(state: State): { any }
	local ranked = MatchState.aliveIds(state)
	table.sort(ranked, function(a, b)
		return better(state, a, b)
	end)
	for index = #state.sunkOrder, 1, -1 do
		table.insert(ranked, state.sunkOrder[index])
	end
	return ranked
end

-- The single survivor, or the best of the players sunk in the final cull.
function MatchState.winner(state: State): any
	local candidates = MatchState.aliveIds(state)
	if #candidates == 0 then
		candidates = state.lastCulled
	end
	local best = nil
	for _, id in candidates do
		if state.heights[id] ~= nil then
			if best == nil or better(state, id, best) then
				best = id
			end
		end
	end
	return best
end

return MatchState
