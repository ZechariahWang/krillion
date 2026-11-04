local Tide = require("../src/ReplicatedStorage/Shared/Tide")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")
local SpecialRound = require("../src/ReplicatedStorage/Shared/SpecialRound")

return function(test)
	test("a pillar already above this round's surge is safe", function()
		assert(Tide.needTier(20, 10, 2.6, nil) == "safe")
		assert(Tide.needTier(12.6, 10, 2.6, nil) == "safe", "level with the settled water still survives")
	end)

	test("a deficit of 5.5 needs Rare", function()
		assert(SpecialRound.lift(Tiers.ByName.Schooler.points, nil) < 5.5)
		assert(Tide.needTier(10, 13, 2.5, nil) == "Rare")
	end)

	test("double lift halves what you need: Schooler covers 5.5", function()
		assert(Tide.needTier(10, 13, 2.5, "DoubleLift") == "Schooler")
	end)

	test("a tidal wave is already counted in the surge it is given", function()
		assert(Tide.needTier(10, 10, 1, "TidalWave") == "Plankton")
	end)

	test("a deficit of 11 is out of reach", function()
		assert(Tide.needTier(10, 18, 3, nil) == "none")
	end)

	test("the need never skips past a tier that is enough", function()
		for _, tier in Tiers.List do
			local lift = SpecialRound.lift(tier.points, nil)
			assert(Tide.needTier(0, 0, lift, nil) == tier.name, tier.name)
		end
	end)

	test("margin is the room between the pillar top and the water", function()
		assert(Tide.margin(12.5, 11) == 1.5)
		assert(Tide.margin(9, 11) == -2)
	end)

	test("sunk lists the ids that are no longer alive, in order", function()
		local gone = Tide.sunk({ 1, 2, 3, -1 }, { 2 })
		assert(#gone == 3 and gone[1] == 1 and gone[2] == 3 and gone[3] == -1)
		assert(#Tide.sunk({ 1, 2 }, { 1, 2 }) == 0)
	end)

	test("sunk text names up to the cap and counts the rest", function()
		assert(Tide.sunkText({}, 4) == nil)
		assert(Tide.sunkText({ "Ana" }, 4) == "SUNK: Ana")
		assert(Tide.sunkText({ "Ana", "Bo" }, 4) == "SUNK: Ana AND Bo")
		assert(Tide.sunkText({ "Ana", "Bo", "Cy" }, 4) == "SUNK: Ana, Bo AND Cy")
		local many = Tide.sunkText({ "A", "B", "C", "D", "E", "F" }, 4)
		assert(many == "SUNK: A, B, C, D AND 2 MORE", many)
	end)
end
