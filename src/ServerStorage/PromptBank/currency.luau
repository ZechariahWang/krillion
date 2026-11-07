--!strict
return {
	id = "currency",
	prompt = "Name a currency",
	answers = {
		Plankton = {
			"dollar", "euro", "pound",
		},
		TooClever = {
			"bitcoin", "robux",
		},
		Schooler = {
			"yen", "peso", "rupee", "yuan", "franc",
		},
		Rare = {
			"won", "ruble", "lira", "krona", "rand", "real",
		},
		DeepCut = {
			"zloty", "forint", "baht", "dirham", "shekel", "ringgit",
		},
		OneInAKrillion = {
			"ngultrum", "kwacha", "lempira", "tugrik", "quetzal",
		},
	},
	aliases = {
		["dollars"] = "dollar", ["euros"] = "euro", ["pounds"] = "pound", ["rupees"] = "rupee",
	},
}
