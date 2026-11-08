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
			"chancellor", "archbishop", "amazon", "ferz", "alfil",
		},
		DeepCut = {
			"wazir", "nightrider", "grasshopper", "camel", "zebra", "giraffe", "centaur",
		},
		OneInAKrillion = {
			"dabbaba", "threeleaper", "berolina pawn",
		},
	},
	aliases = {
		["castle"] = "rook", ["horse"] = "knight", ["marshal"] = "chancellor", ["cardinal"] = "archbishop",
		["fers"] = "ferz", ["elephant"] = "alfil",
	},
}
