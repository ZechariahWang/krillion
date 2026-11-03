--!strict
local GameConfig = require("../Config/GameConfig")

local WaterCurve = {}

function WaterCurve.promptSeconds(round: number): number
	local seconds = GameConfig.Round.PromptSeconds - GameConfig.Round.PromptSecondsStep * (round - 1)
	return math.max(GameConfig.Round.PromptSecondsMin, math.floor(seconds))
end

function WaterCurve.surge(round: number): number
	return GameConfig.Water.SurgeBase + GameConfig.Water.SurgeStep * round
end

function WaterCurve.lift(points: number): number
	return points * GameConfig.Water.LiftPerPoint
end

return WaterCurve
