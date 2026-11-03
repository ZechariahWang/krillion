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

	test("a match counts toward wins only when it started with two or more players", function()
		assert(not Economy.countsAsWin(1))
		assert(Economy.countsAsWin(2))
	end)

	test("revive is offered only with one in stock, unused this match, and enough rivals alive", function()
		local need = GameConfig.Revive.MinOthersAlive
		assert(Economy.canOfferRevive(1, false, need))
		assert(not Economy.canOfferRevive(0, false, need))
		assert(not Economy.canOfferRevive(1, true, need))
		assert(not Economy.canOfferRevive(1, false, need - 1))
	end)
end
