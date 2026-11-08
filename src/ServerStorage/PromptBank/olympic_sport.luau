--!strict
return {
	id = "olympic_sport",
	prompt = "Name a Summer Olympic sport",
	answers = {
		Plankton = {
			"swimming", "gymnastics", "athletics", "running",
		},
		TooClever = {
			"breaking",
		},
		Schooler = {
			"basketball", "soccer", "tennis", "volleyball", "cycling", "boxing", "diving", "golf", "table tennis",
			"rugby sevens", "water polo", "beach volleyball", "baseball", "softball", "handball", "hockey", "skateboarding",
		},
		Rare = {
			"rowing", "fencing", "archery", "judo", "wrestling", "weightlifting", "sailing", "surfing", "sport climbing",
			"taekwondo", "canoeing", "triathlon", "equestrian", "shooting", "badminton", "artistic gymnastics",
			"rhythmic gymnastics", "karate", "mountain biking", "bmx", "cricket", "lacrosse", "squash", "flag football",
		},
		DeepCut = {
			"trampoline", "artistic swimming", "marathon swimming", "canoe slalom", "canoe sprint", "dressage",
			"show jumping", "3x3 basketball", "road cycling", "track cycling", "modern pentathlon", "tug of war", "polo",
			"croquet",
		},
		OneInAKrillion = {
			"eventing", "jeu de paume", "motorboating", "roque",
		},
	},
	aliases = {
		["breakdancing"] = "breaking", ["break dancing"] = "breaking", ["breakdance"] = "breaking",
		["climbing"] = "sport climbing", ["track and field"] = "athletics", ["track"] = "athletics",
		["football"] = "soccer", ["ping pong"] = "table tennis", ["field hockey"] = "hockey", ["kayaking"] = "canoeing",
		["kayak"] = "canoeing", ["synchronized swimming"] = "artistic swimming",
		["open water swimming"] = "marathon swimming", ["pentathlon"] = "modern pentathlon",
		["trampolining"] = "trampoline", ["horse riding"] = "equestrian", ["rugby"] = "rugby sevens",
		["bmx racing"] = "bmx", ["bmx freestyle"] = "bmx", ["tug war"] = "tug of war", ["3x3"] = "3x3 basketball",
	},
}
