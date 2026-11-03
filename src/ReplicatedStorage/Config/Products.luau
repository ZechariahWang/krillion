--!strict
-- Game pass and developer product ids. 0 is a placeholder until the real ones exist in the Creator Hub.

local Products = {
	Passes = {
		Vip = 0,
		DoubleCash = 0,
	},
	-- Developer products: what each one grants when bought.
	CashPacks = {
		{ productId = 0, cash = 500, robux = 25 },
		{ productId = 0, cash = 1500, robux = 65 },
		{ productId = 0, cash = 5000, robux = 199 },
	},
	Revive = { productId = 0, robux = 25 },
}

table.freeze(Products.Passes)
return table.freeze(Products)
