--!strict
-- Game pass and developer product ids. 0 is a placeholder until the real ones exist in the Creator Hub
-- (create them under group 36001322, which owns the place).

local Products = {
	Passes = {
		Vip = 0,
		DoubleCash = 0, -- shown as "2X SHELLS"
	},
	-- Developer products: what each one grants when bought.
	CashPacks = {
		{ productId = 0, cash = 500, robux = 25 },
		{ productId = 0, cash = 1500, robux = 65 },
		{ productId = 0, cash = 5000, robux = 199 },
	},
	Revive = { productId = 0, robux = 25 },
	-- Each adds one to the boost inventory; the in-match buttons spend inventory before Shells.
	Boosts = {
		Hint = { productId = 0, robux = 15 },
		ExtraTime = { productId = 0, robux = 10 },
	},
}

table.freeze(Products.Passes)
table.freeze(Products.Boosts)
return table.freeze(Products)
