local DayCycle = require("../src/ReplicatedStorage/Shared/DayCycle")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local function isNight(clock: number): boolean
	local rules = GameConfig.DayCycle
	return clock >= rules.DuskClock or clock < rules.DawnClock
end

return function(test)
	test("the clock stays within a day", function()
		for t = 0, 3000, 7 do
			local clock = DayCycle.clockAt(t)
			assert(clock >= 0 and clock < 24, "t=" .. t .. " gave " .. clock)
		end
	end)

	test("one full cycle brings the clock back to the same time", function()
		local length = GameConfig.DayCycle.CycleSeconds
		for _, t in { 0, 100, 333, 700 } do
			assert(math.abs(DayCycle.clockAt(t) - DayCycle.clockAt(t + length)) < 1e-6)
		end
	end)

	test("night takes only its share of the cycle", function()
		local rules = GameConfig.DayCycle
		local nightSamples = 0
		local samples = 0
		for t = 0, rules.CycleSeconds - 1 do
			samples += 1
			if isNight(DayCycle.clockAt(t)) then
				nightSamples += 1
			end
		end
		local share = nightSamples / samples
		assert(math.abs(share - rules.NightShare) < 0.01, "night share was " .. share)
	end)

	test("night factor is 0 by day, 1 by night, and blends in the hour before dusk and after dawn", function()
		local rules = GameConfig.DayCycle
		assert(DayCycle.nightFactor(12) == 0, "noon")
		assert(DayCycle.nightFactor(0) == 1, "midnight")
		assert(DayCycle.nightFactor(rules.DuskClock) == 1, "dusk is fully night")
		assert(DayCycle.nightFactor(rules.DawnClock) == 1, "dawn starts fully night")
		local evening = DayCycle.nightFactor(rules.DuskClock - 0.5)
		local morning = DayCycle.nightFactor(rules.DawnClock + 0.5)
		assert(evening > 0 and evening < 1, "evening blends, got " .. evening)
		assert(morning > 0 and morning < 1, "morning blends, got " .. morning)
		assert(DayCycle.nightFactor(rules.DuskClock - 1) == 0, "an hour before dusk is still day")
		assert(DayCycle.nightFactor(rules.DawnClock + 1) == 0, "an hour after dawn is day")
	end)

	test("time only moves forward, apart from wrapping past midnight", function()
		local previous = DayCycle.clockAt(0)
		for t = 1, GameConfig.DayCycle.CycleSeconds * 2 do
			local clock = DayCycle.clockAt(t)
			local step = clock - previous
			if step < 0 then
				step += 24
			end
			assert(step >= 0 and step < 1, "jumped at t=" .. t)
			previous = clock
		end
	end)
end
