--!strict
return {
	id = "chess_piece",
	prompt = "Name a chess piece",
	answers = {
		Plankton = {
			"king", "queen", "pawn", "knight",
		},
		Schooler = {
			"rook", "bishop",
		},
		Rare = {
			"chancellor", "archbishop", "amazon", "cannon",
		},
		DeepCut = {
			"wazir", "nightrider", "grasshopper", "camel", "zebra", "giraffe", "centaur", "unicorn", "dragon",
			"commoner", "advisor", "general", "soldier", "hawk", "ferz", "alfil",
		},
		Mythic = {
			"dabbaba", "threeleaper", "berolina pawn", "mann", "champion", "wizard", "squirrel", "rose", "kirin",
			"phoenix", "lion", "bison", "buffalo", "gnu", "antelope", "vao", "pao", "mao", "moa", "leo",
		},
	},
	aliases = {
		["castle"] = "rook", ["horse"] = "knight", ["cardinal"] = "archbishop", ["fers"] = "ferz", ["elephant"] = "alfil",
		["peon"] = "pawn", ["pawns"] = "pawn", ["kings"] = "king", ["queens"] = "queen", ["rooks"] = "rook",
		["knights"] = "knight", ["bishops"] = "bishop", ["tower"] = "rook", ["rock"] = "rook", ["castle piece"] = "rook",
		["horsey"] = "knight", ["horse piece"] = "knight", ["knite"] = "knight", ["nite"] = "knight", ["knigt"] = "knight",
		["knight piece"] = "knight", ["bishup"] = "bishop", ["bisop"] = "bishop", ["bishop piece"] = "bishop",
		["queen piece"] = "queen", ["quen"] = "queen", ["kinng"] = "king", ["king piece"] = "king", ["pawn piece"] = "pawn",
		["guard"] = "advisor", ["mandarin"] = "advisor", ["elephant xiangqi"] = "alfil", ["nightrider piece"] = "nightrider",
		["night rider"] = "nightrider", ["knightrider"] = "nightrider", ["knight rider"] = "nightrider",
		["grasshopper piece"] = "grasshopper", ["camel piece"] = "camel", ["zebra piece"] = "zebra",
		["giraffe piece"] = "giraffe", ["amazon piece"] = "amazon", ["super queen"] = "amazon", ["superqueen"] = "amazon",
		["chancellor piece"] = "chancellor", ["archbishop piece"] = "archbishop", ["cardinal piece"] = "archbishop",
		["princess piece"] = "archbishop", ["empress piece"] = "chancellor", ["wazir piece"] = "wazir",
		["ferz piece"] = "ferz", ["fers piece"] = "ferz", ["firzan"] = "ferz", ["alfil piece"] = "alfil", ["alfin"] = "alfil",
		["centaur piece"] = "centaur", ["dabbaba piece"] = "dabbaba", ["threeleaper piece"] = "threeleaper",
		["three leaper"] = "threeleaper", ["berolina"] = "berolina pawn", ["berolina pawns"] = "berolina pawn",
		["pown"] = "pawn", ["peasant"] = "pawn", ["rok"] = "rook", ["rooke"] = "rook", ["roook"] = "rook",
		["biship"] = "bishop", ["bishap"] = "bishop", ["queeen"] = "queen", ["qeen"] = "queen", ["kight"] = "knight",
		["knigth"] = "knight", ["nighth"] = "knight", ["horsie"] = "knight", ["pony"] = "knight", ["horses"] = "knight",
		["pwan"] = "pawn", ["pawnn"] = "pawn", ["kng"] = "king", ["kingg"] = "king", ["marshall"] = "chancellor",
		["rook piece"] = "rook", ["castle rook"] = "rook", ["chess king"] = "king", ["chess queen"] = "queen",
		["chess knight"] = "knight", ["chess rook"] = "rook", ["chess bishop"] = "bishop", ["chess pawn"] = "pawn",
		["the king"] = "king", ["the queen"] = "queen", ["the rook"] = "rook", ["the knight"] = "knight",
		["the bishop"] = "bishop", ["the pawn"] = "pawn", ["marshal"] = "chancellor", ["empress"] = "chancellor",
		["princess"] = "archbishop", ["chariot"] = "rook",
	},
}
