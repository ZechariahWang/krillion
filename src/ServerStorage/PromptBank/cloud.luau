--!strict
return {
	id = "cloud",
	prompt = "Name a type of cloud",
	answers = {
		Plankton = {
			"cumulus", "cirrus", "stratus",
		},
		TooClever = {
			"mushroom cloud", "storm cloud", "rain cloud",
		},
		Schooler = {
			"cumulonimbus", "nimbus", "nimbostratus", "funnel cloud", "contrail",
		},
		Rare = {
			"altostratus", "altocumulus", "cirrostratus", "stratocumulus", "cirrocumulus", "wall cloud", "shelf cloud",
			"roll cloud", "anvil cloud", "mares tails", "mackerel sky", "fair weather cumulus", "pyrocumulus", "lenticular",
			"mammatus",
		},
		DeepCut = {
			"castellanus", "floccus", "fractus", "humilis", "mediocris", "congestus", "undulatus", "radiatus", "virga",
			"pileus", "pannus", "velum", "nacreous", "noctilucent", "asperitas", "kelvin helmholtz", "fibratus", "uncinus",
			"spissatus", "calvus", "capillatus",
		},
		OneInAKrillion = {
			"cavum", "flumen", "cauda", "volutus", "homogenitus", "flammagenitus", "cataractagenitus", "silvagenitus",
			"praecipitatio", "opacus", "translucidus", "perlucidus", "intortus", "vertebratus", "duplicatus", "lacunosus",
			"arcus",
		},
	},
	aliases = {
		["thundercloud"] = "storm cloud", ["thunder cloud"] = "storm cloud", ["thunderhead"] = "cumulonimbus",
		["cumulus cloud"] = "cumulus", ["cirrus cloud"] = "cirrus", ["stratus cloud"] = "stratus",
		["incus"] = "anvil cloud", ["mamma"] = "mammatus", ["lenticularis"] = "lenticular", ["tuba"] = "funnel cloud",
		["murus"] = "wall cloud", ["cap cloud"] = "pileus", ["polar stratospheric cloud"] = "nacreous",
		["mother of pearl cloud"] = "nacreous", ["noctilucent cloud"] = "noctilucent",
		["kelvinhelmholtz"] = "kelvin helmholtz", ["fluctus"] = "kelvin helmholtz", ["condensation trail"] = "contrail",
		["vapor trail"] = "contrail", ["vapour trail"] = "contrail",
	},
}
