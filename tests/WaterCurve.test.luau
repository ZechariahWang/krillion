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

	test("surge animation starts at the old level and ends exactly at the new one", function()
		assert(WaterCurve.surgeY(2, 6, 0) == 2)
		assert(WaterCurve.surgeY(2, 6, WaterCurve.surgeSeconds()) == 6)
		assert(WaterCurve.surgeY(2, 6, WaterCurve.surgeSeconds() + 5) == 6)
	end)

	test("surge animation creeps most of the way first, then finishes quickly", function()
		local creepEnd = GameConfig.Water.CreepSeconds
		local creepY = 2 + 4 * GameConfig.Water.CreepFraction
		assert(math.abs(WaterCurve.surgeY(2, 6, creepEnd) - creepY) < 1e-6)
		assert(WaterCurve.surgeSeconds() == GameConfig.Water.CreepSeconds + GameConfig.Water.JumpSeconds)
	end)

	test("terrain water stops at the last whole voxel at or below the surface", function()
		local voxel = GameConfig.Water.Voxel
		assert(WaterCurve.terrainTop(0) == 0)
		assert(WaterCurve.terrainTop(voxel * 2 - 0.1) == voxel)
		assert(WaterCurve.terrainTop(voxel * 2) == voxel * 2)
		assert(WaterCurve.terrainTop(-1) == -voxel)
	end)

	test("the surface slab always reaches down past the terrain top, so no gap shows", function()
		local level = -3.5
		while level < 40 do
			local slabBottom = level - GameConfig.Water.SurfaceDepth
			assert(slabBottom <= WaterCurve.terrainTop(level), "gap at level " .. level)
			level += 0.37
		end
	end)

	test("surge animation never moves the water down", function()
		local previous = WaterCurve.surgeY(0, 10, 0)
		local t = 0
		while t <= WaterCurve.surgeSeconds() do
			local y = WaterCurve.surgeY(0, 10, t)
			assert(y >= previous - 1e-9, "dropped at t=" .. t)
			previous = y
			t += 1 / 60
		end
	end)
end
