local WaterCurve = require("../src/ReplicatedStorage/Shared/WaterCurve")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")
local MatchState = require("../src/ReplicatedStorage/Shared/MatchState")

-- The round a player sinks in when they score `tierName` every round (nil tier means no answer),
-- following RoundService's order: answer lift, then surge, then cull.
local function sinkRound(tierName: string?, missRound: number?): number
	local state = MatchState.new(GameConfig.Water.StartHeight)
	MatchState.addPlayer(state, "p")
	for round = 1, 100 do
		local points = 0
		if tierName ~= nil and round ~= missRound then
			points = Tiers.points(tierName)
		end
		MatchState.applyLift(state, "p", points, WaterCurve.lift(points))
		MatchState.surge(state, WaterCurve.surge(round))
		local culled = MatchState.cull(state)
		if #culled > 0 then
			return round
		end
	end
	return 101
end

local function assertSinksBetween(label: string, round: number, low: number, high: number)
	assert(round >= low and round <= high, label .. " sank in round " .. round .. ", want " .. low .. "-" .. high)
end

return function(test)
	test("round 1 surge is gentle", function()
		assert(WaterCurve.surge(1) <= 0.6, "round 1 surge is " .. WaterCurve.surge(1))
	end)

	test("each round's surge grows by more than the last", function()
		for round = 2, 20 do
			local before = WaterCurve.surge(round) - WaterCurve.surge(round - 1)
			local after = WaterCurve.surge(round + 1) - WaterCurve.surge(round)
			assert(after > before, "growth stalls at round " .. round)
		end
	end)

	test("survival targets by answer tier", function()
		assertSinksBetween("Plankton every round", sinkRound("Plankton"), 4, 6)
		assertSinksBetween("Plankton missing round 2", sinkRound("Plankton", 2), 4, 100)
		assertSinksBetween("Schooler every round", sinkRound("Schooler"), 8, 10)
		assertSinksBetween("Rare every round", sinkRound("Rare"), 12, 15)
		assertSinksBetween("One in a Krillion every round", sinkRound("OneInAKrillion"), 1, 17)
	end)

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
