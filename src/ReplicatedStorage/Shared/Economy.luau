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
