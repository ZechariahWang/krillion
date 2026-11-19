--!strict
-- How hard the bots play, and what happens when only bots are left afloat. Pure (no Roblox APIs), so Lune
-- tests can require it.
--   Paid: once anyone in the match has used a paid boost (a hint, a revive, Robux +10 SEC), the bots play
--   worse for the rest of the match. Nothing on screen says so.
--   Bots-only: when every player has sunk, the match does not end at once (the last one can still revive,
--   and someone arriving can still jump in). Those rounds run quicker: bots play worse, the water rises
--   faster and the prompt is shorter, so the match wraps up soon. With a player back afloat the round is
--   normal again (or paid-easy).

local GameConfig = require("../Config/GameConfig")

local BotsOnly = {}

export type KeepGoing = {
	humansInServer: number, -- players in the server who are not AFK
	aliveBots: number,
	soloRounds: number, -- bots-only rounds already played this match
	revivePending: boolean, -- someone who sank may still revive
}

-- Whether a match with no player afloat carries on with its bots. It never runs for an empty or all-AFK
-- server, nor once fewer than two bots are left (the match is decided). A pending revive keeps it going
-- even past the round cap, so that player is not cut off.
function BotsOnly.keepGoing(state: KeepGoing): boolean
	if state.humansInServer <= 0 or state.aliveBots < 2 then
		return false
	end
	if state.revivePending then
		return true
	end
	return state.soloRounds < GameConfig.Bots.SoloRoundsMax
end

-- A bot's skill for this round. `paid`: someone in the match used a paid boost; `solo`: no player afloat.
function BotsOnly.skill(skill: number, paid: boolean, solo: boolean): number
	local cfg = GameConfig.Bots
	local scale = 1
	if paid then
		scale *= cfg.PaidSkillScale
	end
	if solo then
		scale *= cfg.SoloSkillScale
	end
	return skill * scale
end

-- The chance a bot gives no answer this round (it gets no lift).
function BotsOnly.missChance(paid: boolean, solo: boolean): number
	local cfg = GameConfig.Bots
	local stay = 1
	if paid then
		stay *= 1 - cfg.PaidMissChance
	end
	if solo then
		stay *= 1 - cfg.SoloMissChance
	end
	return 1 - stay
end

-- This round's surge when no player is afloat.
function BotsOnly.surge(surge: number, solo: boolean): number
	if solo then
		return surge * GameConfig.Water.SoloSurgeMultiplier
	end
	return surge
end

-- This round's prompt time when no player is afloat.
function BotsOnly.promptSeconds(seconds: number, solo: boolean): number
	if solo then
		return math.min(seconds, GameConfig.Round.SoloPromptSeconds)
	end
	return seconds
end

return BotsOnly
