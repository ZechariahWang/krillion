local Shop = require("../src/ReplicatedStorage/Shared/Shop")
local Cosmetics = require("../src/ReplicatedStorage/Config/Cosmetics")
local Profile = require("../src/ReplicatedStorage/Shared/Profile")

local function firstItem(wantRobux: boolean)
	for _, item in Cosmetics.List do
		local isRobux = item.robuxProductId ~= nil
		if isRobux == wantRobux then
			return item
		end
	end
	error("catalogue needs both a Cash item and a Robux item")
end

return function(test)
	test("every catalogue item has a known slot and a unique id", function()
		local seen = {}
		for _, item in Cosmetics.List do
			assert(Cosmetics.Slots[item.slot] ~= nil, item.id .. " has slot " .. tostring(item.slot))
			assert(seen[item.id] == nil, "duplicate id " .. item.id)
			seen[item.id] = true
		end
	end)

	test("a Cash item can be bought with enough cash and not without", function()
		local item = firstItem(false)
		local profile = Profile.fromStored(nil)
		profile.cash = item.price - 1
		assert(Shop.canBuyWithCash(profile, item) ~= true)
		profile.cash = item.price
		assert(Shop.canBuyWithCash(profile, item) == true)
	end)

	test("an owned item cannot be bought again", function()
		local item = firstItem(false)
		local profile = Profile.fromStored(nil)
		profile.cash = item.price * 10
		profile.owned[item.id] = true
		assert(Shop.canBuyWithCash(profile, item) ~= true)
	end)

	test("a Robux item cannot be bought with Cash", function()
		local item = firstItem(true)
		local profile = Profile.fromStored(nil)
		profile.cash = 1e9
		assert(Shop.canBuyWithCash(profile, item) ~= true)
	end)

	test("only owned items can be equipped", function()
		local item = firstItem(false)
		local profile = Profile.fromStored(nil)
		assert(not Shop.canEquip(profile, item, {}))
		profile.owned[item.id] = true
		assert(Shop.canEquip(profile, item, {}))
	end)

	test("a pass-granted item can be equipped by a pass holder", function()
		local granted = nil
		for _, item in Cosmetics.List do
			if item.pass ~= nil then
				granted = item
			end
		end
		assert(granted ~= nil, "catalogue needs the VIP title")
		local profile = Profile.fromStored(nil)
		assert(not Shop.canEquip(profile, granted, {}))
		assert(Shop.canEquip(profile, granted, { [granted.pass] = true }))
	end)

	test("reward items are not buyable with Shells", function()
		local profile = Profile.fromStored(nil)
		profile.cash = 1e9
		local found = 0
		for _, item in Cosmetics.List do
			if item.reward ~= nil then
				found += 1
				assert(Shop.canBuyWithCash(profile, item) ~= true, item.id .. " is buyable")
				assert(not Shop.owns(profile, item, { Vip = true, DoubleCash = true }), item.id .. " owned without a grant")
			end
		end
		assert(found > 0, "catalogue needs reward items")
	end)

	test("a granted reward item can be equipped", function()
		local item = Cosmetics.ById["title_crew"]
		assert(item ~= nil and item.reward ~= nil)
		local profile = Profile.fromStored(nil)
		assert(not Shop.canEquip(profile, item, {}))
		profile.owned[item.id] = true
		assert(Shop.canEquip(profile, item, {}))
	end)

	test("a Trail-slot item can be equipped when owned", function()
		local item = Cosmetics.ById["trail_bubbles"]
		assert(item ~= nil and item.slot == "Trail")
		local profile = Profile.fromStored(nil)
		profile.cash = item.price
		assert(Shop.canBuyWithCash(profile, item))
		assert(not Shop.canEquip(profile, item, {}))
		profile.owned[item.id] = true
		assert(Shop.canEquip(profile, item, {}))
		assert(not Shop.canBuyWithCash(profile, item))
	end)

	test("VIP pass items count as owned with passes.Vip", function()
		local profile = Profile.fromStored(nil)
		for _, id in { "title_vip", "skin_aurora", "trail_goldwake" } do
			local item = Cosmetics.ById[id]
			assert(item ~= nil and item.pass == "Vip", id)
			assert(not Shop.owns(profile, item, {}), id)
			assert(Shop.owns(profile, item, { Vip = true }), id)
			assert(not Shop.canBuyWithCash(profile, item), id)
		end
	end)
end
