local Depth = require("../src/ReplicatedStorage/Shared/Depth")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

return function(test)
	test("tier depth bands run deeper with rarity and do not overlap", function()
		local previous = 0
		for _, tier in Tiers.List do
			assert(tier.depthMin >= previous and tier.depthMax > tier.depthMin, tier.name)
			assert(#tier.blurb > 0, tier.name)
			previous = tier.depthMax
		end
	end)

	test("metres stays inside the tier's band, and the same answer always gives the same depth", function()
		for _, tier in Tiers.List do
			local metres = Depth.metres(tier.name, "mandoline")
			assert(metres >= tier.depthMin and metres <= tier.depthMax, tier.name .. " " .. metres)
			assert(Depth.metres(tier.name, "mandoline") == metres)
		end
	end)

	test("different answers usually land at different depths, and case does not matter", function()
		local seen: { [number]: boolean } = {}
		local distinct = 0
		for _, answer in { "mandoline", "whisk", "spatula", "ladle", "zester", "colander", "tongs", "sieve" } do
			local metres = Depth.metres("DeepCut", answer)
			if not seen[metres] then
				seen[metres] = true
				distinct += 1
			end
		end
		assert(distinct >= 6, "only " .. distinct .. " distinct depths")
		assert(Depth.metres("Rare", "Mandoline") == Depth.metres("Rare", "mandoline"))
	end)

	test("no answer has no depth, and an unknown tier is treated the same", function()
		assert(Depth.metres(nil, nil) == 0)
		assert(Depth.metres(nil, "whisk") == 0)
		assert(Depth.metres("NotATier", "whisk") == 0)
	end)

	test("zoneIndex names the band a depth falls in", function()
		assert(Depth.zoneIndex(0) == 0)
		for index, tier in Tiers.List do
			assert(Depth.zoneIndex(Depth.metres(tier.name, "kelp")) == index, tier.name)
		end
	end)

	test("the 1-in-N estimate matches the old dive card", function()
		assert(Depth.oneInEstimate(390) == 327, tostring(Depth.oneInEstimate(390)))
		assert(Depth.oneInEstimate(10) == 2)
	end)

	test("deeper dives take longer and the quick version is half as long", function()
		assert(Depth.diveSeconds(400, false) > Depth.diveSeconds(100, false))
		assert(math.abs(Depth.diveSeconds(300, true) * 2 - Depth.diveSeconds(300, false)) < 1e-9)
		assert(Depth.diveSeconds(0, false) == 0.9)
		local previous = 0
		for metres = 10, 560, 10 do
			local seconds = Depth.diveSeconds(metres, false)
			assert(seconds >= previous, "not monotonic at " .. metres)
			previous = seconds
		end
	end)

	test("a dive creeps, bursts past its depth, then settles exactly on it", function()
		for _, intensity in { 0, 0.4, 1 } do
			local shape = Depth.diveShape(intensity)
			assert(Depth.dive(0, intensity) == 0)
			assert(math.abs(Depth.dive(1, intensity) - 1) < 1e-9, "ends on the depth")
			assert(Depth.dive(shape.hold, intensity) <= 0.1, "the wind-up stays shallow")
			assert(Depth.dive(shape.hold / 2, intensity) < shape.creep / 2, "the wind-up starts slow")
			local previous = -1
			for step = 0, 100 do
				local t = shape.impact * step / 100
				local value = Depth.dive(t, intensity)
				assert(value >= previous, "sinks without stopping until impact")
				previous = value
			end
			assert(Depth.dive(shape.impact, intensity) > 1, "overshoots at impact")
		end
		local small = Depth.diveShape(0)
		local big = Depth.diveShape(1)
		assert(big.hold > small.hold, "better answers wind up longer")
		assert(big.impact - big.hold < small.impact - small.hold, "and burst faster")
		assert(big.overshoot > small.overshoot, "and overshoot further")
	end)
end
