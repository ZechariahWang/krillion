local SpecialRound = require("../src/ReplicatedStorage/Shared/SpecialRound")
local WaterCurve = require("../src/ReplicatedStorage/Shared/WaterCurve")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local RULES = GameConfig.Special

return function(test)
	test("no special rounds before the minimum round", function()
		assert(SpecialRound.pick(RULES.MinRound - 1, nil, 0, 0) == nil)
	end)

	test("a low roll from the minimum round on picks a special", function()
		local special = SpecialRound.pick(RULES.MinRound, nil, 0, 0)
		assert(special ~= nil)
	end)

	test("a roll at or above the chance gives a normal round", function()
		assert(SpecialRound.pick(RULES.MinRound, nil, RULES.Chance, 0) == nil)
	end)

	test("special rounds never come back to back", function()
		assert(SpecialRound.pick(RULES.MinRound + 1, "TidalWave", 0, 0) == nil)
	end)

	test("the second roll chooses between tidal wave and double lift", function()
		assert(SpecialRound.pick(RULES.MinRound, nil, 0, 0.1) == "TidalWave")
		assert(SpecialRound.pick(RULES.MinRound, nil, 0, 0.9) == "DoubleLift")
	end)

	test("a tidal wave multiplies this round's surge", function()
		local normal = SpecialRound.surge(5, nil)
		assert(normal == WaterCurve.surge(5))
		assert(SpecialRound.surge(5, "TidalWave") == normal * RULES.TidalWaveMultiplier)
		assert(SpecialRound.surge(5, "DoubleLift") == normal)
	end)

	test("double lift multiplies how far pillars rise", function()
		local normal = SpecialRound.lift(60, nil)
		assert(normal == WaterCurve.lift(60))
		assert(SpecialRound.lift(60, "DoubleLift") == normal * RULES.DoubleLiftMultiplier)
		assert(SpecialRound.lift(60, "TidalWave") == normal)
	end)
end
