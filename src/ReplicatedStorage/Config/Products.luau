--!strict
-- Game pass and developer product ids, created 2026-11-08 under the Rare or Sink universe (10774453756), owned by
-- group 36001322. They were created off sale: switch each on sale in the Creator Hub (Monetization) to sell it.
-- docs/monetization/creator-hub-checklist.md lists every one with its name, price and description. Robux
-- prices here are what the shop shows; the Creator Hub price is what Roblox charges, so keep the two the same.
-- 0 would mean "not created yet": the button then says COMING SOON.

local Products = {
	-- Game pass ids. Perks: Vip (+10% earned Shells, Aurora skin, Gold Wake trail, VIP title and tag),
	-- DoubleCash ("2X SHELLS", +100% earned Shells), SecondChance (one free revive every match, never in a
	-- 1v1), BoostPlus (+10s limit per match raised from GameConfig.Boosts.PerMatch to PerMatchPlus).
	Passes = {
		Vip = 2074210408,
		DoubleCash = 2074618471,
		SecondChance = 2075800451,
		BoostPlus = 2074618472,
	},
	PassPrices = {
		Vip = 199,
		DoubleCash = 299,
		SecondChance = 249,
		BoostPlus = 149,
	},
	PassOrder = { "Vip", "DoubleCash", "SecondChance", "BoostPlus" },
	-- Sales badges on the shop cards. Picked by hand: there are no sales numbers behind them yet.
	PassBadges = { DoubleCash = "MOST POPULAR" },
	-- Developer products: what each one grants when bought.
	CashPacks = {
		{ productId = 3729793872, cash = 500, robux = 25 },
		{ productId = 3729793985, cash = 1500, robux = 65, badge = "MOST POPULAR" },
		{ productId = 3729793992, cash = 5000, robux = 199 },
		{ productId = 3729794005, cash = 12000, robux = 449, badge = "BEST VALUE" },
	},
	-- Adds one revive to the stock you can use when you sink.
	Revive = { productId = 3729794156, robux = 25 },
	-- Bought on the revive card at the moment you sink, by someone with no revive in stock: revives at once.
	ReviveNow = { productId = 3729794171, robux = 35 },
	-- Each adds `count` to the boost inventory, which the in-match buttons spend first. A hint has no other
	-- price; +time falls back to Shells.
	Boosts = {
		Hint = { productId = 3729794185, robux = 15 },
		ExtraTime = { productId = 3729794199, robux = 10 },
	},
	-- `retired` packs are not sold any more (a hint is 15 Robux each, every time); their receipts are still
	-- honoured.
	BoostPacks = {
		{ productId = 3729794218, kind = "Hint", count = 3, robux = 35, retired = true },
		{ productId = 3729794235, kind = "ExtraTime", count = 3, robux = 25 },
	},
	-- One time per player (profile.claimed.StarterPack): Shells plus a pet and a skin.
	StarterPack = { productId = 3729794015, robux = 49, cash = 1000, items = { "pet_turtle", "skin_sunset" }, badge = "ONCE" },
}

table.freeze(Products.Passes)
table.freeze(Products.PassPrices)
table.freeze(Products.PassBadges)
table.freeze(Products.PassOrder)
table.freeze(Products.Boosts)
table.freeze(Products.BoostPacks)
table.freeze(Products.StarterPack.items)
table.freeze(Products.StarterPack)
return table.freeze(Products)
