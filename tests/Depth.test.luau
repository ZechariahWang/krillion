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
		assert(Depth.ease(0) == 0 and Depth.ease(1) == 1)
		assert(Depth.ease(0.5) > 0.5, "ease-out runs ahead of linear")
	end)
end
