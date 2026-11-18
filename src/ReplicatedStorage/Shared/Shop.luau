--!strict
-- Shop rules shared by the server (which enforces them) and the client (which greys out buttons).
local Cosmetics = require("../Config/Cosmetics")
local Profile = require("./Profile")

local FEATURED_COUNT = 4

local Shop = {}

-- Reward items count only once RewardService has put them in profile.owned; chest items once ChestService
-- has; there is no other way in.
function Shop.owns(profile: Profile.Profile, item: Cosmetics.Item, passes: { [string]: boolean }): boolean
	if profile.owned[item.id] == true then
		return true
	end
	if item.pass ~= nil and passes[item.pass] == true then
		return true
	end
	return false
end

-- Only plain Shells items: never Robux, pass, reward or chest-only ones.
function Shop.canBuyWithCash(profile: Profile.Profile, item: Cosmetics.Item): boolean
	if Cosmetics.source(item) ~= "shells" then
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

-- The Shells bonus of the equipped pet (0 with none, or one the player no longer owns).
function Shop.petBonus(profile: Profile.Profile, passes: { [string]: boolean }): number
	local id = profile.equipped.Pet
	local item = if id ~= nil then Cosmetics.ById[id] else nil
	if item == nil or item.slot ~= "Pet" or not Shop.owns(profile, item, passes) then
		return 0
	end
	return item.shellBonus or 0
end

export type Filterable = {
	name: string,
	currency: string?, -- "Cash" | "Robux" | "Free" | nil (passes, chest-only items, info rows)
	rarity: string?,
	owned: boolean,
}

export type Filter = {
	query: string,
	price: string, -- "All" | "Shells" | "Robux" | "Free"
	rarity: string, -- "All" | a Cosmetics rarity
	hideOwned: boolean,
}

local PRICE_CURRENCY: { [string]: string } = { Shells = "Cash", Robux = "Robux", Free = "Free" }

-- Whether a shop card passes the toolbar's search and filters.
function Shop.matches(entry: Filterable, filter: Filter): boolean
	local query = string.lower((string.gsub(filter.query, "^%s+", "")):gsub("%s+$", ""))
	if query ~= "" and string.find(string.lower(entry.name), query, 1, true) == nil then
		return false
	end
	local wanted = PRICE_CURRENCY[filter.price]
	if wanted ~= nil and entry.currency ~= wanted then
		return false
	end
	if filter.rarity ~= "All" and entry.rarity ~= filter.rarity then
		return false
	end
	if filter.hideOwned and entry.owned then
		return false
	end
	return true
end

-- Today's featured items: FEATURED_COUNT Shells or Robux items picked from the UTC day number, so every
-- player and server shows the same four, and they change at midnight UTC.
function Shop.featured(day: number, count: number?): { Cosmetics.Item }
	local pool: { Cosmetics.Item } = {}
	for _, item in Cosmetics.List do
		local source = Cosmetics.source(item)
		if source == "shells" or source == "robux" then
			table.insert(pool, item)
		end
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	local wanted = math.min(count or FEATURED_COUNT, #pool)
	local picked: { Cosmetics.Item } = {}
	-- MINSTD seeded by the day: every product stays below 2^53, so it is exact and the same in Lune and Roblox.
	local state = (math.floor(day) % 2147483646) + 1
	while #picked < wanted do
		state = (state * 48271) % 2147483647
		local index = (state % #pool) + 1
		local item = table.remove(pool, index) :: Cosmetics.Item
		table.insert(picked, item)
	end
	return picked
end

return Shop
