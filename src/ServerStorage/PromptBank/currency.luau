--!strict
return {
	id = "currency",
	prompt = "Name a currency",
	answers = {
		Plankton = {
			"dollar", "euro", "pound",
		},
		TooClever = {
			"bitcoin", "robux", "vbucks",
		},
		Schooler = {
			"yen", "peso", "rupee", "yuan", "franc",
		},
		Rare = {
			"won", "ruble", "lira", "krona", "rand", "real", "krone", "dinar", "riyal", "rial", "rupiah", "dong",
			"canadian dollar", "australian dollar", "shilling", "drachma", "ducat", "florin", "ethereum", "dogecoin",
			"guilder", "deutsche mark", "peseta",
		},
		DeepCut = {
			"zloty", "forint", "baht", "dirham", "shekel", "ringgit", "afghani", "lek", "dram", "manat", "lari", "som",
			"tenge", "hryvnia", "leu", "lev", "koruna", "denar", "naira", "cedi", "birr", "kip", "riel", "taka", "kyat",
			"leone", "metical", "pula", "kwanza", "guarani", "boliviano", "sol", "bolivar", "colon", "balboa", "kuna",
			"denarius", "doubloon", "thaler", "farthing", "new zealand dollar", "hong kong dollar", "singapore dollar",
			"schilling", "escudo",
		},
		OneInAKrillion = {
			"ngultrum", "kwacha", "lempira", "tugrik", "quetzal", "nakfa", "ouguiya", "vatu", "paanga", "tala", "rufiyaa",
			"dalasi", "loti", "ariary", "kina", "somoni", "dobra", "sestertius", "solidus", "obol", "aureus", "groat",
			"cordoba", "gourde", "pataca",
		},
	},
	aliases = {
		["rupees"] = "rupee", ["rouble"] = "ruble", ["renminbi"] = "yuan", ["usd"] = "dollar", ["greenback"] = "dollar",
		["pound sterling"] = "pound", ["sterling"] = "pound", ["loonie"] = "canadian dollar", ["v bucks"] = "vbucks",
		["togrog"] = "tugrik", ["mark"] = "deutsche mark",
	},
}
