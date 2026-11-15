local Metrics = require("../src/ReplicatedStorage/Shared/Metrics")

return function(test)
	test("onboarding steps count up from 1 in funnel order, and an unknown step has no number", function()
		for index, name in Metrics.ONBOARDING do
			assert(Metrics.onboardingStep(name) == index)
		end
		assert(Metrics.onboardingStep("Joined") == 1)
		assert(Metrics.onboardingStep("NotAStep") == nil)
	end)

	test("match funnel: the start is step 1 and surviving round N is step N + 1", function()
		assert(Metrics.matchStep(0) == 1)
		assert(Metrics.matchStep(1) == 2)
		assert(Metrics.matchStep(7) == 8)
	end)

	test("match funnel never passes the step limit, however long a match runs", function()
		local step = Metrics.matchStep(5000)
		assert(step <= Metrics.FUNNEL_STEP_LIMIT)
		assert(step == Metrics.matchStep(Metrics.MAX_ROUND))
	end)

	test("economy: gained Shells are a source and spent Shells a sink, with a positive amount", function()
		local earned = Metrics.economy(40, "answer", nil)
		assert(earned.flow == "Source" and earned.amount == 40 and earned.transaction == "Gameplay")
		local spent = Metrics.economy(-75, "spend", "boost_ExtraTime")
		assert(spent.flow == "Sink" and spent.amount == 75 and spent.transaction == "Shop")
		assert(spent.sku == "boost_ExtraTime")
	end)

	test("economy: bought Shells are IAP, the daily is a timed reward, the sku falls back to the reason", function()
		assert(Metrics.economy(500, "purchase", nil).transaction == "IAP")
		local daily = Metrics.economy(50, "daily", nil)
		assert(daily.transaction == "TimedReward" and daily.sku == "daily")
		assert(Metrics.economy(10, nil, nil).sku == "unknown")
	end)

	test("a field reads as its dimension and value, and a missing value still gives a string", function()
		assert(Metrics.field("Tier", "Mythic") == "Tier - Mythic")
		assert(Metrics.field("Tier", nil) == "Tier - None")
	end)
end
