--!strict
local GameConfig = require("../Config/GameConfig")

local WaterCurve = {}

function WaterCurve.promptSeconds(round: number): number
	local seconds = GameConfig.Round.PromptSeconds - GameConfig.Round.PromptSecondsStep * (round - 1)
	return math.max(GameConfig.Round.PromptSecondsMin, math.floor(seconds))
end

function WaterCurve.surge(round: number): number
	local water = GameConfig.Water
	local growth = water.SurgeGrowth * (round - 1) ^ water.SurgePower
	return water.SurgeBase + growth
end

function WaterCurve.lift(points: number): number
	return points * GameConfig.Water.LiftPerPoint
end

function WaterCurve.surgeSeconds(): number
	return GameConfig.Water.CreepSeconds + GameConfig.Water.JumpSeconds
end

-- Water height `t` seconds into a surge from `fromY` to `toY`: a slow sine creep most of the way,
-- then a quick accelerating finish. Shared by the server (eliminations) and clients (visuals).
function WaterCurve.surgeY(fromY: number, toY: number, t: number): number
	local creepSeconds = GameConfig.Water.CreepSeconds
	local creepY = fromY + (toY - fromY) * GameConfig.Water.CreepFraction
	if t <= 0 then
		return fromY
	end
	if t < creepSeconds then
		local alpha = t / creepSeconds
		local eased = -(math.cos(math.pi * alpha) - 1) / 2
		return fromY + (creepY - fromY) * eased
	end
	local jumpT = t - creepSeconds
	if jumpT >= GameConfig.Water.JumpSeconds then
		return toY
	end
	local alpha = jumpT / GameConfig.Water.JumpSeconds
	local eased = alpha * alpha
	return creepY + (toY - creepY) * eased
end

return WaterCurve
