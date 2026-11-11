--!strict
-- Occasional special rounds. Rolls are passed in (0 to 1) so the rules stay testable.
--   TidalWave:  the water rises extra far this round.
--   DoubleLift: every pillar rises extra far this round.

local GameConfig = require("../Config/GameConfig")
local WaterCurve = require("./WaterCurve")

local RULES = GameConfig.Special

local SpecialRound = {}

function SpecialRound.pick(round: number, previous: string?, chanceRoll: number, kindRoll: number): string?
	if round < RULES.MinRound then
		return nil
	end
	if previous ~= nil then
		return nil
	end
	if chanceRoll >= RULES.Chance then
		return nil
	end
	if kindRoll < 0.5 then
		return "TidalWave"
	end
	return "DoubleLift"
end

function SpecialRound.surge(round: number, special: string?): number
	local surge = WaterCurve.surge(round)
	if special == "TidalWave" then
		return surge * RULES.TidalWaveMultiplier
	end
	return surge
end

function SpecialRound.lift(points: number, special: string?): number
	local lift = WaterCurve.lift(points)
	if special == "DoubleLift" then
		return lift * RULES.DoubleLiftMultiplier
	end
	return lift
end

return SpecialRound
