--!strict
-- Late join into a running match: when the window is open, whether a player may jump in, how high
-- their pillar starts and where it stands. Pure (no Roblox APIs), so Lune tests can require it.

export type Config = {
	Enabled: number,
	MaxRound: number,
	MinSecondsLeft: number,
	ReserveSlots: number,
}

export type Context = {
	enabled: boolean, -- LateJoin.Enabled
	matchRunning: boolean,
	played: boolean, -- already in this match (alive, sunk, or left and came back)
	windowOpen: boolean,
	hasRoom: boolean, -- under the match's slot count and a free spot exists in the arena
	ready: boolean, -- has a character to put on the pillar
}

local RADIUS_STEP = 1 -- studs between the rings searched for a free spot
local ANGLE_STEPS = 72 -- spots searched on each ring (every 5 degrees)
local EPSILON = 1e-6

local LateJoin = {}

-- What the player is told for each canJoin status.
local MESSAGES: { [string]: string } = {
	joined = "YOU'RE IN! RARER ANSWERS LIFT YOU HIGHER",
	closed = "TOO LATE: NEXT MATCH SOON",
	full = "MATCH IS FULL",
	already = "YOU ALREADY PLAYED THIS MATCH",
	not_ready = "HANG ON, STILL LOADING",
}
LateJoin.Messages = table.freeze(MESSAGES)

-- How many players a match that starts with `starting` may hold, late joiners included.
function LateJoin.slotCount(starting: number, cfg: Config, maxPlayers: number): number
	if cfg.Enabled ~= 1 then
		return starting
	end
	return math.max(starting, math.min(starting + cfg.ReserveSlots, maxPlayers))
end

-- Rounds before MaxRound are open in every match phase, so the card does not blink off at the reveal.
-- MaxRound itself is open only while its prompt still has MinSecondsLeft (pass 0 in overtime).
-- MaxRound 0 means no last round: every round is open in every match phase.
function LateJoin.windowOpen(phase: string, round: number, secondsLeft: number, cfg: Config): boolean
	if cfg.Enabled ~= 1 or round < 1 then
		return false
	end
	local noLimit = cfg.MaxRound == 0
	if not noLimit and round > cfg.MaxRound then
		return false
	end
	if noLimit or round < cfg.MaxRound then
		return phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	end
	return phase == "Prompt" and secondsLeft >= cfg.MinSecondsLeft
end

-- "joined" | "closed" | "full" | "already" | "not_ready", checked in that order of precedence.
function LateJoin.canJoin(ctx: Context): string
	if not ctx.enabled or not ctx.matchRunning then
		return "closed"
	end
	if ctx.played then
		return "already"
	end
	if not ctx.windowOpen then
		return "closed"
	end
	if not ctx.hasRoom then
		return "full"
	end
	if not ctx.ready then
		return "not_ready"
	end
	return "joined"
end

-- What to do with someone arriving mid-match: "wait" for their profile, leave them in the lobby for the
-- "tutorial" (finishing it joins them), or "join". A read-only placeholder never shows the tutorial.
function LateJoin.arrivalAction(loaded: boolean, readOnly: boolean, tutorialDone: boolean): string
	if not loaded then
		return "wait"
	end
	if readOnly or tutorialDone then
		return "join"
	end
	return "tutorial"
end

-- A late joiner starts StartHeight over the water, or level with the lowest pillar still in the match if
-- that is higher, so they are never ahead of anyone who has been answering.
function LateJoin.joinHeight(waterY: number, startHeight: number, minAliveHeight: number?): number
	local height = waterY + startHeight
	if minAliveHeight ~= nil then
		height = math.max(height, minAliveHeight)
	end
	return height
end

-- In a match filled with bots a late joiner takes a standing bot's pillar, so the ring keeps its shape:
-- the lowest one (the first listed on a tie), so the joiner starts level with the back of the field.
-- Nil when no bot is left standing.
function LateJoin.pickBot(standing: { { id: number, height: number } }): number?
	local lowest: { id: number, height: number }? = nil
	for _, bot in standing do
		if lowest == nil or bot.height < lowest.height then
			lowest = bot
		end
	end
	if lowest == nil then
		return nil
	end
	return lowest.id
end

-- Distance to the nearest taken spot, and the sum of distances to all of them (the tie-break).
local function distances(x: number, z: number, taken: { { number } }): (number, number)
	local nearest = math.huge
	local total = 0
	for _, point in taken do
		local distance = math.sqrt((x - point[1]) ^ 2 + (z - point[2]) ^ 2)
		nearest = math.min(nearest, distance)
		total += distance
	end
	return nearest, total
end

-- A free spot for a late joiner's pillar, leaving every pillar already standing where it is: the spot
-- closest to the centre that keeps `spacing` from all of `taken` (x, z pairs) and fits in `maxRadius`;
-- on that ring, the one furthest from its nearest neighbour, then from all of them (so a second joiner
-- goes opposite the first). Nil when the arena has no room left.
function LateJoin.spot(taken: { { number } }, spacing: number, maxRadius: number): (number?, number?)
	local rings = math.floor(maxRadius / RADIUS_STEP)
	for ring = 0, rings do
		local radius = ring * RADIUS_STEP
		local steps = if radius == 0 then 1 else ANGLE_STEPS
		local bestX: number? = nil
		local bestZ: number? = nil
		local bestGap = -1
		local bestTotal = -1
		for step = 0, steps - 1 do
			local angle = step / steps * 2 * math.pi
			local x = math.cos(angle) * radius
			local z = math.sin(angle) * radius
			local gap, total = distances(x, z, taken)
			if gap >= spacing - EPSILON then
				local better = gap > bestGap + EPSILON or (gap > bestGap - EPSILON and total > bestTotal + EPSILON)
				if better then
					bestX, bestZ, bestGap, bestTotal = x, z, gap, total
				end
			end
		end
		if bestX ~= nil then
			return bestX, bestZ
		end
	end
	return nil, nil
end

return LateJoin
