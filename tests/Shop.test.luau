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
end
