--!strict
-- Time of day from the shared server clock, so every client shows the same sky without any network traffic.
-- Day (dawn to dusk) fills most of the cycle and night only GameConfig.DayCycle.NightShare of it.

local GameConfig = require("../Config/GameConfig")

local DayCycle = {}

-- Lighting.ClockTime (0..24) at `serverSeconds` (workspace:GetServerTimeNow()).
function DayCycle.clockAt(serverSeconds: number): number
	local rules = GameConfig.DayCycle
	local phase = (serverSeconds % rules.CycleSeconds) / rules.CycleSeconds
	local dayShare = 1 - rules.NightShare
	local dayHours = rules.DuskClock - rules.DawnClock
	local nightHours = 24 - dayHours
	local clock = 0
	if phase < dayShare then
		clock = rules.DawnClock + (phase / dayShare) * dayHours
	else
		clock = rules.DuskClock + ((phase - dayShare) / rules.NightShare) * nightHours
	end
	return clock % 24
end

-- How much it is night at `clock`: 0 by day, 1 from dusk to dawn, blending over the hour before dusk and
-- the hour after dawn. Drives the night lighting and the torches.
function DayCycle.nightFactor(clock: number): number
	local rules = GameConfig.DayCycle
	local eveningStart = rules.DuskClock - 1
	local morningEnd = rules.DawnClock + 1
	if clock >= rules.DuskClock or clock <= rules.DawnClock then
		return 1
	end
	if clock > eveningStart then
		return clock - eveningStart
	end
	if clock < morningEnd then
		return morningEnd - clock
	end
	return 0
end

return DayCycle
