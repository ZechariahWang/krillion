--!strict
return {
	id = "coffee_drink",
	prompt = "Name a coffee drink",
	answers = {
		Plankton = {
			"latte", "espresso", "cappuccino",
		},
		TooClever = {
			"frappuccino",
		},
		Schooler = {
			"americano", "mocha", "macchiato", "iced coffee", "cold brew",
		},
		Rare = {
			"flat white", "cortado", "affogato", "irish coffee",
		},
		DeepCut = {
			"ristretto", "lungo", "red eye", "cafe au lait", "doppio",
		},
		OneInAKrillion = {
			"cafe bombon", "turkish coffee", "einspanner", "marocchino", "carajillo",
		},
	},
	aliases = {
		["flatwhite"] = "flat white", ["frappe"] = "frappuccino",
	},
}
