--!strict
-- Cash payouts, pass multipliers and the revive rule. No Roblox APIs, so Lune tests can require it.
local GameConfig = require("../Config/GameConfig")

local Economy = {}

function Economy.multiplier(hasVip: boolean, hasDouble: boolean): number
	local total = 1
	if hasVip then
		total += GameConfig.Cash.VipBonus
	end
	if hasDouble then
		total += GameConfig.Cash.DoubleBonus
	end
	return total
end

function Economy.apply(cash: number, multiplier: number): number
	return math.floor(cash * multiplier)
end

function Economy.lobbyCash(points: number): number
	return math.floor(points * GameConfig.Lobby.CashPerPoint)
end

-- One warm-up answer's Shells: pass multiplier applied once, then cut to what is left of today's cap.
-- Pay the result unmultiplied (StoreService.grantShells). Returns the amount and whether the cap cut it
-- or is now reached.
function Economy.lobbyPayout(points: number, multiplier: number, earnedToday: number, cap: number): (number, boolean)
	local full = Economy.apply(Economy.lobbyCash(points), multiplier)
	local left = math.max(0, cap - math.max(0, earnedToday))
	local paid = math.max(0, math.min(full, left))
	return paid, paid < full or earnedToday + paid >= cap
end

-- Shells for one graded match answer (before pass bonuses); 0 with no accepted answer.
function Economy.answerShells(tier: string?): number
	if tier == nil then
		return 0
	end
	local byTier: { [string]: number } = GameConfig.Cash.AnswerByTier :: any
	return byTier[tier] or 0
end

function Economy.matchCash(roundsSurvived: number, won: boolean): number
	local cash = roundsSurvived * GameConfig.Cash.PerRoundSurvived
	if won then
		cash += GameConfig.Cash.WinBonus
	end
	return cash
end

function Economy.countsAsWin(participants: number): boolean
	return participants >= 2
end

function Economy.canOfferRevive(revivesOwned: number, usedThisMatch: boolean, othersAlive: number): boolean
	if revivesOwned <= 0 then
		return false
	end
	if usedThisMatch then
		return false
	end
	return othersAlive >= GameConfig.Revive.MinOthersAlive
end

return Economy
