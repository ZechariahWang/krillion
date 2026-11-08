--!strict
return {
	id = "spice",
	prompt = "Name a spice or herb",
	answers = {
		Plankton = {
			"salt", "pepper", "cinnamon", "basil",
		},
		TooClever = {
			"vanilla", "cayenne",
		},
		Schooler = {
			"oregano", "paprika", "ginger", "garlic", "parsley", "cumin", "mint", "thyme", "rosemary", "nutmeg", "turmeric",
			"chili", "cloves", "chili powder", "curry powder", "sage", "dill", "cilantro", "peppermint", "garlic powder",
			"bay leaf", "chives", "allspice",
		},
		Rare = {
			"cardamom", "saffron", "coriander", "fennel", "anise", "star anise", "tarragon", "marjoram", "lemongrass",
			"mustard", "garam masala", "caraway", "spearmint", "lavender", "chamomile", "catnip", "horseradish", "wasabi",
			"white pepper", "red pepper flakes", "poppy seed", "mustard seed", "celery seed", "juniper berries",
			"curry leaf", "five spice", "zaatar", "herbes de provence", "chipotle", "onion powder", "lemon balm",
		},
		DeepCut = {
			"fenugreek", "sumac", "mace", "galangal", "tamarind", "savory", "chervil", "sorrel", "lemon verbena",
			"kaffir lime leaf", "annatto", "szechuan pepper", "pink peppercorn", "long pepper", "cassia", "nigella",
			"black cardamom", "ras el hanout", "baharat", "berbere", "dukkah", "togarashi", "shiso", "holy basil",
			"thai basil", "borage", "hyssop", "licorice root", "mugwort", "dill seed", "fennel seed", "cumin seed",
		},
		OneInAKrillion = {
			"asafoetida", "lovage", "cubeb", "grains of paradise", "epazote", "culantro", "angelica", "mitsuba",
			"vietnamese coriander", "tonka bean", "mahlab", "ajwain", "amchur", "kokum", "urfa biber", "aleppo pepper",
		},
	},
	aliases = {
		["chilli"] = "chili", ["black pepper"] = "pepper", ["peppercorn"] = "pepper",
		["sichuan pepper"] = "szechuan pepper", ["hing"] = "asafoetida", ["achiote"] = "annatto", ["perilla"] = "shiso",
		["tulsi"] = "holy basil", ["crushed red pepper"] = "red pepper flakes", ["zatar"] = "zaatar",
		["chinese five spice"] = "five spice", ["liquorice root"] = "licorice root",
		["makrut lime leaf"] = "kaffir lime leaf", ["bay"] = "bay leaf", ["curry"] = "curry powder",
		["ground ginger"] = "ginger", ["smoked paprika"] = "paprika",
	},
}
