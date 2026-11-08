--!strict
return {
	id = "capital_europe",
	prompt = "Name a capital city in Europe",
	answers = {
		Plankton = {
			"london", "paris", "berlin", "rome", "madrid", "moscow",
		},
		TooClever = {
			"vaduz", "valletta",
		},
		Schooler = {
			"vienna", "amsterdam", "lisbon", "athens", "dublin", "prague", "brussels", "oslo", "stockholm", "copenhagen",
			"helsinki", "warsaw", "budapest", "edinburgh",
		},
		Rare = {
			"kyiv", "bern", "reykjavik", "belgrade", "zagreb", "bucharest", "sofia", "minsk", "luxembourg", "monaco",
			"cardiff", "belfast", "vatican city", "san marino", "nicosia",
		},
		DeepCut = {
			"ljubljana", "bratislava", "vilnius", "tallinn", "riga", "sarajevo", "pristina", "torshavn", "douglas",
			"st helier", "st peter port", "mariehamn",
		},
		OneInAKrillion = {
			"chisinau", "podgorica", "tirana", "skopje", "andorra la vella",
		},
	},
	aliases = {
		["kiev"] = "kyiv", ["berne"] = "bern", ["luxembourg city"] = "luxembourg", ["vatican"] = "vatican city",
		["saint helier"] = "st helier", ["saint peter port"] = "st peter port", ["prishtina"] = "pristina",
		["wien"] = "vienna", ["praha"] = "prague", ["roma"] = "rome", ["moskva"] = "moscow", ["warszawa"] = "warsaw",
		["lisboa"] = "lisbon", ["bruxelles"] = "brussels", ["kobenhavn"] = "copenhagen", ["athina"] = "athens",
		["andorra"] = "andorra la vella", ["kishinev"] = "chisinau",
	},
}
