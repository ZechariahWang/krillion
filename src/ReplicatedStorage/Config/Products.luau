--!strict
-- Game pass and developer product ids. 0 is a placeholder until the real ones exist in the Creator Hub
-- (create them under group 36001322, which owns the place; docs/monetization/creator-hub-checklist.md lists
-- every one with its name, price and description). Robux prices here are what the shop shows; the Creator
-- Hub price is what Roblox charges, so keep the two the same.

local Products = {
	-- Game pass ids. Perks: Vip (+10% earned Shells, Aurora skin, Gold Wake trail, VIP title and tag),
	-- DoubleCash ("2X SHELLS", +100% earned Shells), SecondChance (one free revive every match, never in a
	-- 1v1), BoostPlus (hint and +10s limit per match raised from GameConfig.Boosts.PerMatch to PerMatchPlus).
	Passes = {
		Vip = 0,
		DoubleCash = 0,
		SecondChance = 0,
		BoostPlus = 0,
	},
	PassPrices = {
		Vip = 199,
		DoubleCash = 299,
		SecondChance = 249,
		BoostPlus = 149,
	},
	PassOrder = { "Vip", "DoubleCash", "SecondChance", "BoostPlus" },
	-- Developer products: what each one grants when bought.
	CashPacks = {
		{ productId = 0, cash = 500, robux = 25 },
		{ productId = 0, cash = 1500, robux = 65 },
		{ productId = 0, cash = 5000, robux = 199 },
		{ productId = 0, cash = 12000, robux = 449 },
	},
	-- Adds one revive to the stock you can use when you sink.
	Revive = { productId = 0, robux = 25 },
	-- Bought on the revive card at the moment you sink, by someone with no revive in stock: revives at once.
	ReviveNow = { productId = 0, robux = 35 },
	-- Each adds `count` to the boost inventory; the in-match buttons spend inventory before Shells.
	Boosts = {
		Hint = { productId = 0, robux = 15 },
		ExtraTime = { productId = 0, robux = 10 },
	},
	BoostPacks = {
		{ productId = 0, kind = "Hint", count = 3, robux = 35 },
		{ productId = 0, kind = "ExtraTime", count = 3, robux = 25 },
	},
	-- One time per player (profile.claimed.StarterPack): Shells plus a pet and a skin.
	StarterPack = { productId = 0, robux = 49, cash = 1000, items = { "pet_turtle", "skin_sunset" } },
}

table.freeze(Products.Passes)
table.freeze(Products.PassPrices)
table.freeze(Products.PassOrder)
table.freeze(Products.Boosts)
table.freeze(Products.BoostPacks)
table.freeze(Products.StarterPack.items)
table.freeze(Products.StarterPack)
return table.freeze(Products)
