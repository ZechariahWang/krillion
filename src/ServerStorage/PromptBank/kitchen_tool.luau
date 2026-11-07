--!strict
return {
	id = "kitchen_tool",
	prompt = "Name a kitchen tool or utensil",
	answers = {
		Plankton = {
			"knife", "spoon", "fork", "spatula",
		},
		TooClever = {
			"air fryer",
		},
		Schooler = {
			"whisk", "ladle", "grater", "peeler", "tongs", "rolling pin", "blender",
		},
		Rare = {
			"colander", "sieve", "mandoline", "mortar and pestle", "zester",
		},
		DeepCut = {
			"garlic press", "pastry brush", "bench scraper", "melon baller", "skimmer",
		},
		OneInAKrillion = {
			"spurtle", "chinois", "tamis", "spider strainer", "cherry pitter",
		},
	},
	aliases = {
		["pestle"] = "mortar and pestle", ["strainer"] = "colander",
	},
}
