--!strict
return {
	id = "room_in_house",
	prompt = "Name a room in a house",
	answers = {
		Plankton = {
			"kitchen", "bedroom", "bathroom", "living room", "garage", "basement",
		},
		TooClever = {
			"attic", "dining room", "laundry room", "playroom",
		},
		Schooler = {
			"hallway", "closet", "office", "study", "nursery", "pantry", "porch", "balcony",
			"den", "family room", "guest room", "master bedroom", "game room", "man cave",
			"mudroom", "foyer", "entryway", "toilet", "restroom", "sunroom", "library", "cellar",
			"bonus room", "home theater", "gym", "walk in closet",
			"spare room", "utility room", "kids room", "storage room", "wine cellar", "drawing room",
			"lounge", "sitting room", "front room", "parlor", "powder room", "half bath", "ensuite",
			"loft", "workshop", "laundry",
		},
		Rare = {
			"conservatory", "scullery", "larder", "boot room", "vestibule", "landing", "box room",
			"breakfast nook", "great room", "rec room", "craft room",
			"music room", "billiard room", "smoking room", "morning room", "salon", "solarium",
			"panic room", "safe room", "root cellar", "crawl space", "garret", "mezzanine",
			"cloakroom", "butlers pantry", "ballroom",
			"dressing room", "boudoir", "nook", "alcove", "annex", "granny flat", "in law suite",
			"studio", "darkroom",
			"tv room", "media room", "theater room", "wet room", "sauna",
			"steam room", "kitchenette",
		},
		DeepCut = {
			"buttery", "still room", "gunroom",
			"antechamber", "anteroom", "withdrawing room", "tack room", "orangery", "lumber room",
			"strongroom",
			"turret room",
			"inglenook", "hearth room", "keeping room",
			
			
		},
		Mythic = {
			"scriptorium", "solar", "garderobe", "minstrels gallery",
			"oriel", "tablinum", "triclinium", "atrium", "peristyle",
		},
	},
	aliases = {
		["mud room"] = "mudroom",
		["bed room"] = "bedroom", ["bath room"] = "bathroom", ["livingroom"] = "living room",
		["lounge room"] = "living room", ["kitchens"] = "kitchen", ["bedrooms"] = "bedroom",
		["bathrooms"] = "bathroom", ["bath"] = "bathroom", ["washroom"] = "bathroom", ["loo"] = "toilet",
		["garages"] = "garage", ["basements"] = "basement", ["dining"] = "dining room",
		["washing room"] = "laundry room", ["play room"] = "playroom",
		["hall"] = "hallway", ["hall way"] = "hallway", ["closets"] = "closet", ["home office"] = "office",
		["nurserys"] = "nursery", ["baby room"] = "nursery", ["kids bedroom"] = "kids room",
		["childrens room"] = "kids room", ["guestroom"] = "guest room", ["master bed room"] = "master bedroom",
		["main bedroom"] = "master bedroom", ["gameroom"] = "game room",
		["sun room"] = "sunroom", ["wc"] = "toilet", ["lavatory"] = "toilet",
		["rumpus room"] = "rec room", ["recreation room"] = "rec room", ["theatre room"] = "theater room",
		["home cinema"] = "home theater", ["cinema room"] = "home theater", ["movie room"] = "home theater",
		["conservatories"] = "conservatory", ["attic room"] = "attic", ["loft room"] = "loft",
		["bonusroom"] = "bonus room", ["walk in wardrobe"] = "walk in closet", ["wardrobe"] = "closet",
		["scull"] = "scullery", ["butler pantry"] = "butlers pantry", ["sunparlor"] = "sunroom",
		["cinema"] = "home theater",
	},
}
