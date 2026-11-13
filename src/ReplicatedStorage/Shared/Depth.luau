--!strict
-- How deep an answer "dives" on the dive card, in metres. Each tier owns a depth band (Tiers depthMin..depthMax)
-- and an answer always lands at the same spot inside its band. No Roblox APIs, so Lune tests can require it.
local GameConfig = require("../Config/GameConfig")
local Tiers = require("../Config/Tiers")

local HASH_MOD = 4294967296 -- 2^32: djb2 is reduced every step so it stays exact in a double

local Depth = {}

-- djb2 over the lower-cased answer, so "Mandoline" and "mandoline" dive to the same depth.
local function hash(text: string): number
	local value = 5381
	local lowered = string.lower(text)
	for index = 1, #lowered do
		value = (value * 33 + string.byte(lowered, index)) % HASH_MOD
	end
	return value
end

-- Metres for an answer in a tier; 0 when there is no tier (no answer). An accepted answer without its
-- text sits in the middle of the band.
function Depth.metres(tier: string?, answer: string?): number
	if tier == nil then
		return 0
	end
	local info = Tiers.ByName[tier]
	if info == nil then
		return 0
	end
	local width = info.depthMax - info.depthMin
	if answer == nil or answer == "" or width <= 0 then
		return math.floor((info.depthMin + info.depthMax) / 2)
	end
	return info.depthMin + hash(answer) % width
end

-- A rough "1 in N players" for a depth, used only when real answer counts are missing and
-- GameConfig.Reveal.EstimatedOneIn is on. Same curve as the old dive card: 390 m gives 327.
function Depth.oneInEstimate(metres: number): number
	return math.max(2, math.floor(10 ^ ((metres + 50) / 175) + 0.5))
end

-- 1..#Tiers.List for the band a depth falls in (0 above the first band).
function Depth.zoneIndex(metres: number): number
	local zone = 0
	for index, tier in Tiers.List do
		if metres >= tier.depthMin then
			zone = index
		end
	end
	return zone
end

-- How long the dive animation takes to reach `metres`; halved for the quick (mini card) version.
function Depth.diveSeconds(metres: number, quick: boolean): number
	if metres <= 0 then
		return 0.9
	end
	local fraction = math.clamp(metres / 500, 0, 1)
	local seconds = 1.7 + 3.1 * fraction ^ 0.85
	if quick then
		seconds /= 2
	end
	return seconds
end

-- The shape of a dive for an answer of `intensity` (0 for the commonest tier, 1 for Mythic):
-- `hold` is when the slow wind-up ends and the burst starts, `impact` is when the tag first reaches its depth
-- (the stamp lands here), and `creep` and `overshoot` are fractions of the depth. Better answers wind up
-- longer, burst faster and overshoot further before springing back.
export type DiveShape = { hold: number, impact: number, creep: number, overshoot: number }

function Depth.diveShape(intensity: number): DiveShape
	local k = math.clamp(intensity, 0, 1)
	return {
		hold = 0.3 + 0.15 * k,
		impact = 0.86 - 0.04 * k,
		creep = 0.05 + 0.03 * k,
		overshoot = 0.015 + 0.055 * k,
	}
end

-- Fraction of the depth reached at time `t` (0..1 of the dive): a slow creep that gathers speed, a burst
-- that is still accelerating when it overshoots the depth, then a damped spring back onto it.
function Depth.dive(t: number, intensity: number): number
	local shape = Depth.diveShape(intensity)
	local u = math.clamp(t, 0, 1)
	if u < shape.hold then
		return shape.creep * (u / shape.hold) ^ 1.6
	end
	if u < shape.impact then
		local burst = (u - shape.hold) / (shape.impact - shape.hold)
		return shape.creep + (1 + shape.overshoot - shape.creep) * burst ^ 2.6
	end
	local settle = (u - shape.impact) / (1 - shape.impact)
	return 1 + shape.overshoot * (1 - settle) ^ 2 * math.cos(settle * 2.5 * math.pi)
end

-- The full scale the dive window scrolls over.
function Depth.range(): (number, number)
	return -GameConfig.Depth.SkyMetres, GameConfig.Depth.MaxMetres
end

return table.freeze(Depth)
