local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

return function(test)
	test("cash multiplier is 1 with no passes", function()
		assert(Economy.multiplier(false, false) == 1)
	end)

	test("VIP and 2x Cash stack additively", function()
		local both = Economy.multiplier(true, true)
		local expected = 1 + GameConfig.Cash.VipBonus + GameConfig.Cash.DoubleBonus
		assert(math.abs(both - expected) < 1e-9, "got " .. both)
		assert(Economy.multiplier(true, false) > 1)
		assert(Economy.multiplier(false, true) > Economy.multiplier(true, false))
	end)

	test("applying a multiplier gives whole cash", function()
		local cash = Economy.apply(25, Economy.multiplier(true, false))
		assert(cash == math.floor(cash))
	end)

	test("surviving a round pays more than the best lobby quiz answer", function()
		local bestLobby = Economy.lobbyCash(Tiers.MaxPoints)
		assert(GameConfig.Cash.PerRoundSurvived > bestLobby)
	end)

	test("a win pays the bonus on top of rounds survived", function()
		assert(Economy.matchCash(3, true) == 3 * GameConfig.Cash.PerRoundSurvived + GameConfig.Cash.WinBonus)
		assert(Economy.matchCash(3, false) == 3 * GameConfig.Cash.PerRoundSurvived)
	end)

	test("every tier pays its configured answer Shells, and no answer pays nothing", function()
		for _, tier in Tiers.List do
			local pay = Economy.answerShells(tier.name)
			assert(pay == GameConfig.Cash.AnswerByTier[tier.name], tier.name .. " pays " .. pay)
			assert(pay > 0, tier.name .. " pays nothing")
		end
		assert(Economy.answerShells(nil) == 0)
		assert(Economy.answerShells("NotATier") == 0)
	end)

	test("a rarer tier never pays fewer answer Shells", function()
		local previous = 0
		for _, tier in Tiers.List do
			local pay = Economy.answerShells(tier.name)
			assert(pay >= previous, tier.name .. " pays less than the tier below it")
			previous = pay
		end
	end)

	test("pass bonuses apply to answer Shells", function()
		local base = Economy.answerShells("Rare")
		local vip = Economy.apply(base, Economy.multiplier(true, false))
		assert(vip == math.floor(base * (1 + GameConfig.Cash.VipBonus)), "got " .. vip)
		assert(vip >= base)
		local both = Economy.apply(base, Economy.multiplier(true, true))
		assert(both == math.floor(base * (1 + GameConfig.Cash.VipBonus + GameConfig.Cash.DoubleBonus)), "got " .. both)
	end)

	test("a match counts toward wins only when it started with two or more players", function()
		assert(not Economy.countsAsWin(1))
		assert(Economy.countsAsWin(2))
	end)

	test("a warm-up payout applies the multiplier once and never passes the daily cap", function()
		local cap = GameConfig.Lobby.DailyShellCap
		local base = Economy.lobbyCash(Tiers.MaxPoints)
		local both = Economy.multiplier(true, true)
		local paid, capped = Economy.lobbyPayout(Tiers.MaxPoints, both, 0, cap)
		assert(paid == Economy.apply(base, both), "got " .. paid)
		assert(not capped)
		-- Close to the cap: only what is left is paid, and it reports capped.
		paid, capped = Economy.lobbyPayout(Tiers.MaxPoints, both, cap - 3, cap)
		assert(paid == 3, "got " .. paid)
		assert(capped)
		-- At or past the cap: graded but pays nothing.
		paid, capped = Economy.lobbyPayout(Tiers.MaxPoints, both, cap, cap)
		assert(paid == 0 and capped)
		paid, capped = Economy.lobbyPayout(Tiers.MaxPoints, 1, cap + 50, cap)
		assert(paid == 0 and capped)
		-- Landing exactly on the cap counts as reaching it.
		local exact = Economy.apply(base, 1)
		paid, capped = Economy.lobbyPayout(Tiers.MaxPoints, 1, cap - exact, cap)
		assert(paid == exact and capped)
	end)

	test("revive is offered only with one in stock, unused this match, and enough rivals alive", function()
		local need = GameConfig.Revive.MinOthersAlive
		assert(Economy.canOfferRevive(1, false, need))
		assert(not Economy.canOfferRevive(0, false, need))
		assert(not Economy.canOfferRevive(1, true, need))
		assert(not Economy.canOfferRevive(1, false, need - 1))
	end)
end
