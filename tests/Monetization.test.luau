local Boosts = require("../src/ReplicatedStorage/Shared/Boosts")
local Chests = require("../src/ReplicatedStorage/Config/Chests")
local Cosmetics = require("../src/ReplicatedStorage/Config/Cosmetics")
local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Products = require("../src/ReplicatedStorage/Config/Products")
local Profile = require("../src/ReplicatedStorage/Shared/Profile")
local Shop = require("../src/ReplicatedStorage/Shared/Shop")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

local function reviveState(overrides)
	local state = {
		revivesOwned = 0,
		usedThisMatch = false,
		othersAlive = 3,
		secondChance = false,
		secondChanceUsed = false,
		canBuy = true,
	}
	for key, value in overrides do
		state[key] = value
	end
	return state
end

return function(test)
	-- Catalogue ------------------------------------------------------------------------------------------
	test("every item has a known rarity, a valid label and a preview colour", function()
		for _, item in Cosmetics.List do
			assert(Cosmetics.RarityRank[item.rarity] ~= nil, item.id .. " has rarity " .. tostring(item.rarity))
			assert(item.label == nil or Cosmetics.Labels[item.label], item.id .. " has label " .. tostring(item.label))
			assert(item.color ~= nil and #item.color == 3, item.id .. " needs a preview colour")
		end
	end)

	test("each item has exactly one way in, and Shells items have a price", function()
		for _, item in Cosmetics.List do
			local ways = 0
			for _, flag in { item.reward ~= nil, item.pass ~= nil, item.chestOnly == true, item.robuxProductId ~= nil } do
				if flag then
					ways += 1
				end
			end
			assert(ways <= 1, item.id .. " has more than one unlock path")
			if Cosmetics.source(item) == "shells" then
				assert(item.price > 0, item.id .. " is a Shells item with no price")
			else
				assert(item.price == 0, item.id .. " is not sold for Shells but has a price")
			end
			if item.robuxProductId ~= nil then
				assert(type(item.robux) == "number" and item.robux > 0, item.id .. " needs a shown Robux price")
			end
		end
	end)

	test("slot fields match their slot", function()
		local need = { Splash = "splash", Trail = "trail", Pet = "pet", Aura = "aura", CardTheme = "card", NameTag = "tag", Toy = "toy" }
		for _, item in Cosmetics.List do
			for slot, field in need do
				local value = (item :: any)[field]
				if item.slot == slot then
					assert(value ~= nil, item.id .. " needs " .. field)
				else
					assert(value == nil, item.id .. " is not a " .. slot .. " but sets " .. field)
				end
			end
		end
	end)

	test("pets give a bonus in range and rarer pets never give less", function()
		local bestByRank = {}
		for _, item in Cosmetics.List do
			if item.slot == "Pet" then
				local bonus = item.shellBonus or 0
				assert(bonus > 0 and bonus <= GameConfig.Cash.MaxPetBonus, item.id .. " bonus " .. tostring(bonus))
				local rank = Cosmetics.RarityRank[item.rarity]
				bestByRank[rank] = math.max(bestByRank[rank] or 0, bonus)
			end
		end
		for _, item in Cosmetics.List do
			if item.slot == "Pet" then
				local rank = Cosmetics.RarityRank[item.rarity]
				if rank > 1 and bestByRank[rank - 1] ~= nil then
					assert((item.shellBonus or 0) >= bestByRank[rank - 1] - 0.03, item.id .. " pays far less than a commoner pet")
				end
			end
		end
	end)

	test("name tags have at least one colour and card themes all three", function()
		for _, item in Cosmetics.List do
			if item.slot == "NameTag" then
				assert(item.tag ~= nil and #item.tag >= 1, item.id)
				for _, rgb in item.tag :: { { number } } do
					assert(#rgb == 3, item.id .. " tag colour needs three channels")
				end
			elseif item.slot == "CardTheme" then
				local card = item.card :: any
				assert(#card.header == 3 and #card.frame == 3 and #card.tag == 3, item.id)
			end
		end
	end)

	test("every slot has items and inSlot keeps rarity order", function()
		for _, slot in Cosmetics.SlotOrder do
			local items = Cosmetics.inSlot(slot)
			assert(#items > 0, slot .. " is empty")
			for index = 2, #items do
				assert(Cosmetics.RarityRank[items[index - 1].rarity] <= Cosmetics.RarityRank[items[index].rarity], slot .. " is out of rarity order")
			end
		end
	end)

	-- Chests ---------------------------------------------------------------------------------------------
	test("chest odds add up to 1 and every drop is a real item", function()
		for _, chest in Chests.List do
			local total = 0
			for _, drop in chest.drops do
				assert(Cosmetics.ById[drop.item] ~= nil, chest.id .. " drops unknown " .. drop.item)
				assert(drop.chance > 0, chest.id .. " has a zero-chance drop")
				total += drop.chance
			end
			assert(near(total, 1), chest.id .. " odds add up to " .. total)
			assert(chest.price > 0)
		end
	end)

	test("every chest-only item can come out of some chest", function()
		local dropped = {}
		for _, chest in Chests.List do
			for _, drop in chest.drops do
				dropped[drop.item] = true
			end
		end
		for _, item in Cosmetics.List do
			if item.chestOnly then
				assert(dropped[item.id], item.id .. " is chest-only but no chest drops it")
			end
		end
	end)

	test("a chest roll walks the odds in order", function()
		local chest = Chests.List[1]
		assert(Chests.roll(chest, 0) == chest.drops[1].item)
		assert(Chests.roll(chest, chest.drops[1].chance - 1e-9) == chest.drops[1].item)
		assert(Chests.roll(chest, chest.drops[1].chance + 1e-9) == chest.drops[2].item)
		assert(Chests.roll(chest, 0.999999999) == chest.drops[#chest.drops].item)
		assert(Chests.refund(chest) == math.floor(chest.price * Chests.DuplicateRefund))
	end)

	test("odds print as plain percentages", function()
		assert(Chests.percent(0.2) == "20%")
		assert(Chests.percent(0.015) == "1.5%")
		assert(Chests.percent(0.005) == "0.5%")
	end)

	-- Products -------------------------------------------------------------------------------------------
	test("every pass has a price and a place in the shop order", function()
		local ordered = {}
		for _, key in Products.PassOrder do
			ordered[key] = true
			assert(Products.Passes[key] ~= nil, key .. " is ordered but not a pass")
		end
		for key in Products.Passes do
			assert(ordered[key], key .. " is missing from PassOrder")
			assert(type(Products.PassPrices[key]) == "number", key .. " has no shown price")
		end
	end)

	test("non-zero product ids are unique across packs, boosts, revives and items", function()
		local seen = {}
		local function add(id: number, what: string)
			if id ~= 0 then
				assert(seen[id] == nil, what .. " reuses product id " .. id .. " from " .. tostring(seen[id]))
				seen[id] = what
			end
		end
		for index, pack in Products.CashPacks do
			add(pack.productId, "CashPacks " .. index)
		end
		add(Products.Revive.productId, "Revive")
		add(Products.ReviveNow.productId, "ReviveNow")
		add(Products.Boosts.Hint.productId, "Hint")
		add(Products.Boosts.ExtraTime.productId, "ExtraTime")
		for index, pack in Products.BoostPacks do
			add(pack.productId, "BoostPacks " .. index)
		end
		add(Products.StarterPack.productId, "StarterPack")
		for _, item in Cosmetics.List do
			if item.robuxProductId ~= nil then
				add(item.robuxProductId, item.id)
			end
		end
	end)

	test("the starter pack grants real Shells-shop items", function()
		for _, id in Products.StarterPack.items do
			assert(Cosmetics.ById[id] ~= nil, "starter pack item " .. id)
		end
		assert(Products.StarterPack.cash > 0)
	end)

	-- Shop -----------------------------------------------------------------------------------------------
	test("chest-only, Robux, pass and reward items can never be bought with Shells", function()
		local profile = Profile.new()
		profile.cash = 1e9
		for _, item in Cosmetics.List do
			local expected = Cosmetics.source(item) == "shells"
			assert(Shop.canBuyWithCash(profile, item) == expected, item.id)
		end
	end)

	test("only an owned, equipped pet pays its bonus", function()
		local profile = Profile.new()
		assert(Shop.petBonus(profile, {}) == 0)
		profile.equipped.Pet = "pet_turtle"
		assert(Shop.petBonus(profile, {}) == 0, "an unowned pet pays nothing")
		profile.owned.pet_turtle = true
		assert(near(Shop.petBonus(profile, {}), 0.08))
		profile.equipped.Pet = "skin_coral"
		profile.owned.skin_coral = true
		assert(Shop.petBonus(profile, {}) == 0, "a non-pet in the pet slot pays nothing")
	end)

	test("featured items are four distinct sellable items, stable for a day", function()
		local a = Shop.featured(20400)
		local b = Shop.featured(20400)
		assert(#a == 4)
		local seen = {}
		for index, item in a do
			assert(item == b[index], "same day, same picks")
			assert(not seen[item.id], "featured twice: " .. item.id)
			seen[item.id] = true
			local source = Cosmetics.source(item)
			assert(source == "shells" or source == "robux", item.id .. " cannot be bought")
		end
		local changed = false
		for day = 20401, 20410 do
			if Shop.featured(day)[1] ~= a[1] then
				changed = true
			end
		end
		assert(changed, "the featured row should rotate across days")
	end)

	-- Economy and boosts ---------------------------------------------------------------------------------
	test("the pet bonus adds to the pass multiplier and is capped", function()
		assert(near(Economy.multiplier(false, false, 0.1), 1.1))
		assert(near(Economy.multiplier(true, true, 0.25), 1 + GameConfig.Cash.VipBonus + GameConfig.Cash.DoubleBonus + 0.25))
		assert(near(Economy.multiplier(false, false, 5), 1 + GameConfig.Cash.MaxPetBonus), "a bad bonus is capped")
		assert(near(Economy.multiplier(false, false), 1), "no pet, no bonus")
	end)

	test("revive offers: free beats stock beats buy", function()
		assert(Economy.reviveOffer(reviveState({ secondChance = true, revivesOwned = 2 })) == "free")
		assert(Economy.reviveOffer(reviveState({ secondChance = true, secondChanceUsed = true, revivesOwned = 1 })) == "stock")
		assert(Economy.reviveOffer(reviveState({})) == "buy")
		assert(Economy.reviveOffer(reviveState({ canBuy = false })) == nil)
	end)

	test("never a revive in a 1v1 or after one this match", function()
		local fewest = GameConfig.Revive.MinOthersAlive
		assert(fewest >= 2, "a 1v1 leaves one other alive; the rule must block it")
		for _, overrides in {
			{ othersAlive = 1, secondChance = true },
			{ othersAlive = 1, revivesOwned = 3 },
			{ othersAlive = 1 },
			{ othersAlive = fewest - 1, secondChance = true },
			{ usedThisMatch = true, secondChance = true, revivesOwned = 1 },
		} do
			assert(Economy.reviveOffer(reviveState(overrides)) == nil)
		end
	end)

	test("Boost Plus raises only the per-match limit", function()
		local plain = Boosts.limitsFor(false)
		local plus = Boosts.limitsFor(true)
		assert(plain.PerMatch == GameConfig.Boosts.PerMatch)
		assert(plus.PerMatch == GameConfig.Boosts.PerMatchPlus)
		assert(plus.PerMatch > plain.PerMatch)
		assert(plus.PerRound == plain.PerRound)
		local usage = { round = Boosts.newUses(), match = Boosts.newUses() }
		usage.match.Hint = plain.PerMatch
		assert(Boosts.canUse(usage, "Hint", plain) == "limit")
		assert(Boosts.canUse(usage, "Hint", plus) == "ok")
	end)

	-- Profile --------------------------------------------------------------------------------------------
	test("the new equip slots save, combine and merge like the old ones", function()
		local stored = Profile.new()
		stored.equipped.Skin = "skin_coral"
		local first = Profile.newSession()
		first.equipped.Pet = "pet_crab"
		first.equipped.Aura = "aura_sparkle"
		local second = Profile.newSession()
		second.equipped.Pet = "pet_turtle"
		second.equipped.Toy = "toy_tomato"
		second.equipped.Aura = ""
		local merged = Profile.merge(stored, Profile.combine(first, second))
		assert(merged.equipped.Skin == "skin_coral")
		assert(merged.equipped.Pet == "pet_turtle", "the later session wins")
		assert(merged.equipped.Toy == "toy_tomato")
		assert(merged.equipped.Aura == "", "an unequip is kept")
		local reloaded = Profile.fromStored(merged)
		for _, slot in Profile.EQUIP_SLOTS do
			assert((reloaded.equipped :: any)[slot] == (merged.equipped :: any)[slot], slot .. " lost on reload")
		end
	end)

	test("Profile knows every cosmetic slot", function()
		local known = {}
		for _, slot in Profile.EQUIP_SLOTS do
			known[slot] = true
		end
		for slot in Cosmetics.Slots do
			assert(known[slot], slot .. " is a cosmetic slot that Profile would not save")
		end
	end)

	test("every sales badge names a real product", function()
		for key in Products.PassBadges do
			assert(Products.Passes[key] ~= nil, "PassBadges." .. key .. " is not a pass")
		end
		local valueBadges = 0
		for _, pack in Products.CashPacks do
			if pack.badge ~= nil then
				valueBadges += 1
			end
		end
		assert(valueBadges >= 1, "no cash pack carries a badge")
		assert(type(Products.StarterPack.badge) == "string")
	end)
end
