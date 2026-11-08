--!strict
return {
	id = "sport_ball",
	prompt = "Name a sport played with a ball",
	answers = {
		Plankton = {
			"soccer", "football", "basketball", "tennis", "baseball",
		},
		TooClever = {
			"quidditch", "sepak takraw",
		},
		Schooler = {
			"volleyball", "golf", "rugby", "cricket", "hockey", "table tennis", "bowling", "dodgeball", "american football",
			"pool", "billiards", "snooker", "kickball", "handball", "softball", "beach volleyball", "field hockey",
			"mini golf", "croquet", "foosball", "lacrosse", "squash",
		},
		Rare = {
			"water polo", "netball", "racquetball", "polo", "bocce", "petanque", "rounders", "futsal", "gaelic football",
			"australian rules football", "rugby league", "rugby union", "canadian football", "tetherball", "four square",
			"padel", "pickleball", "paddleball", "real tennis", "hurling", "camogie", "shinty", "bandy", "floorball",
			"korfball", "footvolley", "teqball", "kin ball", "tchoukball", "goalball", "lawn bowls", "skittles",
			"ten pin bowling", "tee ball", "wiffle ball", "stoolball", "pesapallo", "cycle ball", "beach tennis",
			"soft tennis", "beach soccer", "street hockey", "pelota", "platform tennis", "touch rugby", "flag football",
		},
		DeepCut = {
			"rackets", "eton fives", "rugby fives", "fives", "jai alai", "canoe polo", "bicycle polo", "horseball",
			"polocrosse", "bossaball", "futnet", "boccia", "nine pin bowling", "candlepin bowling", "duckpin bowling",
			"gaelic handball", "wallyball", "sitting volleyball", "ball hockey", "underwater rugby", "rink bandy",
			"woodball", "footgolf", "pitch and putt", "pallapugno", "calcio storico", "jeu de paume", "longue paume",
			"pilota", "tamburello", "bowls", "crown green bowls", "carpet bowls",
		},
		OneInAKrillion = {
			"ulama", "pitz", "kemari", "cuju", "harpastum", "episkyros", "lelo burti", "ringette", "cestoball", "kronum",
			"pushball", "ballon au poing", "kaatsen", "fistball", "faustball", "brannboll", "vigoro", "danish longball",
			"eton wall game", "calcio fiorentino", "la soule", "knattleikr",
		},
	},
	aliases = {
		["basket"] = "basketball", ["footie"] = "football", ["ping pong"] = "table tennis", ["pingpong"] = "table tennis",
		["bball"] = "basketball", ["gridiron"] = "american football", ["aussie rules"] = "australian rules football",
		["afl"] = "australian rules football", ["minigolf"] = "mini golf", ["putt putt"] = "mini golf",
		["tenpin bowling"] = "ten pin bowling", ["tenpin"] = "ten pin bowling", ["ten pin"] = "ten pin bowling",
		["dodge ball"] = "dodgeball", ["tether ball"] = "tetherball", ["foursquare"] = "four square",
		["table football"] = "foosball", ["basque pelota"] = "pelota", ["pickle ball"] = "pickleball",
		["t ball"] = "tee ball", ["tball"] = "tee ball", ["association football"] = "soccer", ["futbol"] = "soccer",
		["takraw"] = "sepak takraw", ["boules"] = "petanque", ["soft ball"] = "softball",
	},
}
