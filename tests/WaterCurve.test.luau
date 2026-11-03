local WaterCurve = require("../src/ReplicatedStorage/Shared/WaterCurve")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

return function(test)
	test("prompt timer shrinks each round and never goes below the floor", function()
		local first = WaterCurve.promptSeconds(1)
		local second = WaterCurve.promptSeconds(2)
		assert(first == GameConfig.Round.PromptSeconds, "round 1 uses the base timer")
		assert(second < first, "round 2 is shorter than round 1")
		assert(WaterCurve.promptSeconds(100) == GameConfig.Round.PromptSecondsMin, "floor holds")
	end)

	test("prompt timer is always whole seconds", function()
		for round = 1, 20 do
			local seconds = WaterCurve.promptSeconds(round)
			assert(seconds == math.floor(seconds), "round " .. round .. " gave " .. seconds)
		end
	end)

	test("surge grows every round", function()
		assert(WaterCurve.surge(2) > WaterCurve.surge(1))
		assert(WaterCurve.surge(1) > 0)
	end)

	test("lift is proportional to points", function()
		assert(WaterCurve.lift(0) == 0)
		assert(WaterCurve.lift(100) == 100 * GameConfig.Water.LiftPerPoint)
	end)

	test("lobby coins are whole numbers proportional to points", function()
		local coins = WaterCurve.lobbyCoins(15)
		assert(coins == math.floor(coins))
		assert(WaterCurve.lobbyCoins(100) > WaterCurve.lobbyCoins(10))
	end)

	test("surge eventually exceeds the best possible lift so matches end", function()
		local bestLift = WaterCurve.lift(Tiers.MaxPoints)
		local found = false
		for round = 1, 200 do
			if WaterCurve.surge(round) > bestLift then
				found = true
				break
			end
		end
		assert(found, "surge never outgrows the top tier lift")
	end)
end
