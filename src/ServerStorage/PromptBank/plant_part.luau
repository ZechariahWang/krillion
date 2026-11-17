--!strict
return {
	id = "plant_part",
	prompt = "Name a part of a plant",
	answers = {
		Plankton = {
			"leaf", "root", "stem", "flower", "petal", "seed", "branch", "trunk",
		},
		TooClever = {
			"bark", "thorn", "fruit", "bud",
		},
		Schooler = {
			"twig", "pollen", "nectar", "sap", "bulb", "pistil", "stamen", "sepal", "needle", "cone", "vine", "tendril",
			"canopy", "crown", "shoot", "sprout", "seedling", "tuber", "rhizome", "spine", "pod", "husk", "shell", "peel", "pit",
			"kernel", "node", "cotyledon", "chloroplast", "xylem", "phloem", "anther", "stigma", "ovary", "style", "filament",
			"ovule", "taproot", "root hair", "tree ring", "heartwood", "sapwood", "cambium", "foliage", "frond", "stipe",
		},
		Rare = {
			"calyx", "corolla", "carpel", "receptacle", "peduncle", "pedicel", "petiole", "leaf blade", "leaf vein", "midrib",
			"stomata", "cuticle", "epidermis", "cortex", "pith", "vascular bundle", "lenticel", "bract", "spathe", "spadix",
			"catkin", "inflorescence", "floret", "rosette", "tepal", "perianth", "gynoecium", "androecium", "endosperm",
			"embryo", "radicle", "plumule", "hilum", "seed coat", "aril", "bulbil", "corm", "stolon", "offshoot", "sucker",
			"scape", "awn", "glume", "bole", "burl", "stump", "lateral root", "aerial root", "prop root", "buttress root",
			"root cap", "root tip", "nodule", "mycorrhiza", "internode", "axil", "bud scale", "leaflet", "stipule",
		},
		DeepCut = {
			"lamina", "rachis", "pinna", "pinnule", "sorus", "sporangium", "spore", "prothallus", "gametophyte", "sporophyte",
			"guard cell", "mesophyll", "palisade layer", "spongy layer", "trichome", "glandular hair", "pneumatophore",
			"haustorium", "rhizoid", "thallus", "gemma", "sclerenchyma", "collenchyma", "parenchyma", "periderm", "phelloderm",
			"cork cambium", "pericycle", "endodermis", "casparian strip",
		},
		Mythic = {
			"exine", "intine", "tapetum", "nucellus", "micropyle", "funiculus", "chalaza", "synergid", "antipodal", "pappus",
			"samara", "achene", "silique", "caryopsis", "drupelet", "hypanthium", "staminode", "petaloid", "apical meristem",
			"intercalary meristem", "root meristem", "quiescent center",
		},
	},
	aliases = {
		["leaves"] = "leaf", ["roots"] = "root", ["stems"] = "stem", ["flowers"] = "flower", ["petals"] = "petal",
		["seeds"] = "seed", ["branches"] = "branch", ["trunks"] = "trunk", ["barks"] = "bark", ["thorns"] = "thorn",
		["fruits"] = "fruit", ["buds"] = "bud", ["stalks"] = "stem", ["twigs"] = "twig", ["bulbs"] = "bulb",
		["pistils"] = "pistil", ["stamens"] = "stamen", ["sepals"] = "sepal", ["needles"] = "needle", ["cones"] = "cone",
		["vines"] = "vine", ["pine cone"] = "cone", ["pinecone"] = "cone", ["pine needle"] = "needle", ["shoots"] = "shoot",
		["sprouts"] = "sprout", ["blooms"] = "flower", ["blossoms"] = "flower", ["tubers"] = "tuber",
		["rhizomes"] = "rhizome", ["spines"] = "spine", ["pods"] = "pod", ["pits"] = "pit", ["stones"] = "pit",
		["seed pod"] = "pod", ["nodes"] = "node", ["anthers"] = "anther", ["stigmas"] = "stigma", ["styles"] = "style",
		["tree trunk"] = "trunk", ["tree bark"] = "bark", ["tree rings"] = "tree ring", ["growth ring"] = "tree ring",
		["fronds"] = "frond", ["leaflets"] = "leaflet", ["stipules"] = "stipule", ["xylem tissue"] = "xylem",
		["sap wood"] = "sapwood", ["heart wood"] = "heartwood", ["tap root"] = "taproot", ["tendrils"] = "tendril",
		["husks"] = "husk", ["limbs"] = "branch", ["veins"] = "leaf vein", ["vein"] = "leaf vein", ["stoma"] = "stomata",
		["stomas"] = "stomata", ["calyces"] = "calyx", ["catkins"] = "catkin", ["bracts"] = "bract", ["florets"] = "floret",
		["corms"] = "corm", ["stolons"] = "stolon", ["runners"] = "stolon", ["suckers"] = "sucker", ["burls"] = "burl",
		["stumps"] = "stump", ["peduncles"] = "peduncle", ["petioles"] = "petiole", ["pedicels"] = "pedicel",
		["receptacles"] = "receptacle", ["carpels"] = "carpel", ["spores"] = "spore", ["trichomes"] = "trichome",
		["samaras"] = "samara", ["achenes"] = "achene", ["stone"] = "pit", ["bloom"] = "flower", ["blossom"] = "flower",
		["limb"] = "branch", ["stalk"] = "stem", ["blade"] = "leaf blade", ["runner"] = "stolon", ["testa"] = "seed coat",
		["vascular cambium"] = "cambium",
	},
}
