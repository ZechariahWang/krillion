--!strict
-- Shop rules shared by the server (which enforces them) and the client (which greys out buttons).
local Cosmetics = require("../Config/Cosmetics")
local Profile = require("./Profile")

local Shop = {}

function Shop.owns(profile: Profile.Profile, item: Cosmetics.Item, passes: { [string]: boolean }): boolean
	if profile.owned[item.id] == true then
		return true
	end
	if item.pass ~= nil and passes[item.pass] == true then
		return true
	end
	return false
end

function Shop.canBuyWithCash(profile: Profile.Profile, item: Cosmetics.Item): boolean
	if item.robuxProductId ~= nil or item.pass ~= nil then
		return false
	end
	if profile.owned[item.id] == true then
		return false
	end
	return profile.cash >= item.price
end

function Shop.canEquip(profile: Profile.Profile, item: Cosmetics.Item, passes: { [string]: boolean }): boolean
	return Shop.owns(profile, item, passes)
end

return Shop
