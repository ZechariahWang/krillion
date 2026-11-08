--!strict
return {
	id = "constellation",
	prompt = "Name a constellation",
	answers = {
		Plankton = {
			"orion", "ursa major", "ursa minor", "cassiopeia", "scorpius", "leo",
		},
		TooClever = {
			"ophiuchus", "draco", "crux",
		},
		Schooler = {
			"aries", "taurus", "gemini", "cancer", "virgo", "libra", "sagittarius", "capricornus", "aquarius", "pisces",
			"andromeda", "pegasus", "perseus", "cygnus", "lyra", "aquila", "hercules", "canis major", "canis minor",
			"hydra", "centaurus", "cepheus", "bootes", "auriga", "phoenix", "lynx", "lepus", "corona borealis",
			"delphinus", "monoceros",
		},
		Rare = {
			"ara", "camelopardalis", "canes venatici", "carina", "columba", "coma berenices", "corona australis",
			"corvus", "crater", "dorado", "equuleus", "eridanus", "grus", "hydrus", "lacerta", "leo minor", "lupus",
			"musca", "pavo", "piscis austrinus", "puppis", "sagitta", "scutum", "serpens", "triangulum",
			"triangulum australe", "tucana", "vela", "vulpecula", "cetus",
		},
		DeepCut = {
			"antlia", "caelum", "circinus", "horologium", "mensa", "microscopium", "norma", "octans", "pictor", "pyxis",
			"reticulum", "sculptor", "sextans", "telescopium", "volans", "fornax", "apus", "chamaeleon", "indus",
		},
		OneInAKrillion = {
			"argo navis", "quadrans muralis", "antinous", "felis", "noctua", "rangifer", "solarium",
			"machina electrica", "globus aerostaticus", "officina typographica", "psalterium georgii",
			"taurus poniatovii", "cerberus", "gallus", "jordanus", "tigris", "telescopium herschelii",
			"sceptrum brandenburgicum", "custos messium", "lochium funis", "musca borealis", "turdus solitarius",
			"honores friderici", "robur carolinum", "triangulum minus", "vespa", "apis", "mons maenalus",
			"cancer minor", "gladii electorales saxonici", "sceptrum et manus iustitiae",
		},
	},
	aliases = {
		["big dipper"] = "ursa major", ["the big dipper"] = "ursa major", ["plough"] = "ursa major",
		["the plough"] = "ursa major", ["great bear"] = "ursa major", ["the great bear"] = "ursa major",
		["little dipper"] = "ursa minor", ["little bear"] = "ursa minor", ["southern cross"] = "crux",
		["scorpio"] = "scorpius", ["capricorn"] = "capricornus", ["orions belt"] = "orion",
		["northern cross"] = "cygnus", ["teapot"] = "sagittarius", ["sea goat"] = "capricornus",
		["water bearer"] = "aquarius", ["great dog"] = "canis major", ["little dog"] = "canis minor",
		["winged horse"] = "pegasus", ["southern fish"] = "piscis austrinus", ["northern crown"] = "corona borealis",
		["southern crown"] = "corona australis", ["hunting dogs"] = "canes venatici",
		["berenices hair"] = "coma berenices", ["serpent bearer"] = "ophiuchus",
		["southern triangle"] = "triangulum australe", ["ship argo"] = "argo navis", ["argo"] = "argo navis",
		["cassiopia"] = "cassiopeia", ["casiopeia"] = "cassiopeia", ["orion constellation"] = "orion",
		["ophiucus"] = "ophiuchus", ["aquarious"] = "aquarius", ["sagitarius"] = "sagittarius",
		["saggitarius"] = "sagittarius", ["andromida"] = "andromeda",
	},
}
