--!strict
return {
	id = "material",
	prompt = "Name a material that things are made from",
	answers = {
		Plankton = {
			"wood", "plastic", "metal", "glass", "paper", "rubber",
		},
		TooClever = {
			"steel", "concrete", "leather", "cotton", "brick", "cardboard",
		},
		Schooler = {
			"iron", "gold", "silver", "aluminum", "copper", "wool", "stone", "clay", "plaster", "foam", "ceramic", "porcelain",
			"silk", "nylon", "polyester", "denim", "cement", "sand", "ice", "bamboo", "cork", "wax", "fiberglass", "carbon fiber",
			"vinyl", "latex", "styrofoam", "tin", "brass", "bronze", "marble", "granite", "diamond", "linen", "velvet", "fur",
			"bone", "straw", "canvas", "asphalt", "drywall", "plywood", "felt", "cloth", "fabric", "mud", "lead", "platinum",
			"stainless steel", "cast iron", "fleece", "titanium",
		},
		Rare = {
			"pewter", "tungsten", "kevlar", "spandex", "acrylic", "rayon", "neoprene", "silicone", "resin", "bakelite",
			"linoleum", "formica", "laminate", "particle board", "balsa", "pvc", "polyethylene", "polystyrene", "teflon",
			"graphene", "mica", "slate", "limestone", "sandstone", "quartz", "jade", "amber", "pearl", "mother of pearl", "shell",
			"horn", "tortoiseshell", "rattan", "jute", "sisal", "burlap", "papier mache", "parchment", "papyrus", "adobe",
			"thatch", "tar", "mortar", "stucco", "terracotta", "earthenware", "stoneware", "bone china", "crystal",
			"stained glass", "tempered glass", "zinc", "nickel", "chrome", "wrought iron", "sheet metal", "ivory", "cashmere",
			"satin", "chiffon", "tweed", "corduroy", "suede", "mesh", "tulle", "lace", "microfiber", "cardstock", "wicker",
		},
		DeepCut = {
			"vellum", "bitumen", "cob", "celluloid", "shellac",
			"baleen", "sinew", "catgut", "polypropylene", "polycarbonate", "polyurethane",
			"epoxy",
			"basalt", "pumice", "gypsum", "terrazzo", "travertine", "alabaster", "soapstone",
			"gabardine",
			"damask", "brocade", "organza", "taffeta", "muslin", "calico", "twill", "chambray",
			"seersucker",
			"masonite",
		},
		Mythic = {
			"ormolu", "shagreen", "vulcanite", "lignum vitae", "tabby", "pise", "oakum", "bast", "nankeen", "buckram",
			"crinoline", "grosgrain", "moleskin", "sharkskin", "chamois",
		},
	},
	aliases = {
		["woods"] = "wood", ["lumber"] = "wood", ["timber"] = "wood", ["plastics"] = "plastic", ["metals"] = "metal",
		["papers"] = "paper", ["rubbers"] = "rubber", ["steels"] = "steel", ["leathers"] = "leather", ["bricks"] = "brick",
		["card board"] = "cardboard", ["aluminium"] = "aluminum", ["alumium"] = "aluminum", ["alluminum"] = "aluminum",
		["woolen"] = "wool", ["stones"] = "stone", ["clays"] = "clay", ["ceramics"] = "ceramic", ["silks"] = "silk",
		["polyestre"] = "polyester", ["styro foam"] = "styrofoam", ["fibre glass"] = "fiberglass",
		["carbon fibre"] = "carbon fiber", ["marbles"] = "marble", ["diamonds"] = "diamond", ["bones"] = "bone",
		["lycra"] = "spandex", ["elastane"] = "spandex", ["pearls"] = "pearl", ["shells"] = "shell",
		["terra cotta"] = "terracotta", ["velour"] = "velvet", ["dry wall"] = "drywall", ["ply wood"] = "plywood",
		["paper mache"] = "papier mache", ["fibreglass"] = "fiberglass", ["glass fiber"] = "fiberglass",
		["plexiglass"] = "acrylic", ["lucite"] = "acrylic", ["xylonite"] = "celluloid",
	},
}
