local Cosmetics = require("../src/ReplicatedStorage/Config/Cosmetics")
local Products = require("../src/ReplicatedStorage/Config/Products")

-- Templates authored in src/ReplicatedStorage/Templates/Trails.model.json.
local TRAIL_TEMPLATES = { Bubbles = true, Seafoam = true, Sunset = true, Abyssal = true, Rainbow = true, GoldWake = true, Pod = true }

return function(test)
	test("cosmetic ids are unique and ById finds each one", function()
		local seen = {}
		for _, item in Cosmetics.List do
			assert(seen[item.id] == nil, "duplicate id " .. item.id)
			seen[item.id] = true
			assert(Cosmetics.ById[item.id] == item, item.id .. " missing from ById")
		end
	end)

	test("every item's slot is in Slots", function()
		for _, item in Cosmetics.List do
			assert(Cosmetics.Slots[item.slot] == true, item.id .. " has slot " .. tostring(item.slot))
		end
	end)

	test("every Trail item names a trail template, and only trails do", function()
		local trails = 0
		for _, item in Cosmetics.List do
			if item.slot == "Trail" then
				trails += 1
				assert(item.trail ~= nil and TRAIL_TEMPLATES[item.trail], item.id .. " has trail " .. tostring(item.trail))
			else
				assert(item.trail == nil, item.id .. " is not a trail but sets one")
			end
		end
		assert(trails >= 7, "expected the seven trails, found " .. trails)
	end)

	test("reward items have no price path and a known unlock", function()
		for _, item in Cosmetics.List do
			if item.reward ~= nil then
				assert(item.price == 0, item.id .. " has a Shells price")
				assert(item.robuxProductId == nil, item.id .. " has a Robux product")
				assert(item.pass == nil, item.id .. " also comes with a pass")
				assert(Cosmetics.RewardHow[item.reward] ~= nil, item.id .. " has unknown reward " .. item.reward)
			end
		end
	end)

	test("forReward lists the items each reward unlocks", function()
		for reward in Cosmetics.RewardHow do
			local items = Cosmetics.forReward(reward)
			assert(#items > 0, reward .. " unlocks nothing")
			for _, item in items do
				assert(item.reward == reward)
			end
		end
		assert(#Cosmetics.forReward("Nope") == 0)
	end)

	test("every pass key exists in Products.Passes", function()
		local vipItems = 0
		for _, item in Cosmetics.List do
			if item.pass ~= nil then
				assert((Products.Passes :: any)[item.pass] ~= nil, item.id .. " has unknown pass " .. item.pass)
				if item.pass == "Vip" then
					vipItems += 1
				end
			end
		end
		assert(vipItems >= 3, "VIP should bring its title, the Aurora pillar and the Gold Wake trail")
	end)

	test("skins have a valid colour and material name", function()
		for _, item in Cosmetics.List do
			if item.slot == "Skin" then
				assert(item.color ~= nil and #item.color == 3, item.id .. " needs a colour")
				assert(item.material ~= nil, item.id .. " needs a material")
				if item.top ~= nil then
					assert(#item.top == 3, item.id .. " top needs three channels")
				end
			end
		end
	end)
end
