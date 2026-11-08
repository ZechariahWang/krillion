--!strict
return {
	id = "board_game",
	prompt = "Name a board game",
	answers = {
		Plankton = {
			"monopoly", "chess", "scrabble", "checkers",
		},
		TooClever = {
			"go",
		},
		Schooler = {
			"clue", "risk", "battleship", "backgammon", "sorry", "connect four", "candy land", "trouble", "operation",
			"life", "chutes and ladders", "guess who", "mouse trap", "trivial pursuit", "pictionary", "catan",
		},
		Rare = {
			"dutch blitz", "ticket to ride", "pandemic", "mancala", "othello", "parcheesi", "ludo", "hungry hungry hippos",
			"cranium", "mastermind", "sequence", "chinese checkers", "hi ho cherryo", "kerplunk", "payday", "careers",
			"blokus", "stratego", "carcassonne", "azul", "codenames", "splendor", "dixit", "king of tokyo",
			"forbidden island", "shogi", "xiangqi",
		},
		DeepCut = {
			"dominion", "7 wonders", "sagrada", "patchwork", "betrayal at house on the hill", "small world", "scythe",
			"root", "everdell", "risk legacy", "arkham horror", "mysterium", "takenoko", "hive", "santorini", "quoridor",
			"abalone", "kingdomino", "halma", "nine mens morris", "hnefatafl", "senet", "royal game of ur",
			"game of the goose", "diplomacy", "axis and allies", "forbidden desert", "pandemic legacy", "fox and geese",
		},
		OneInAKrillion = {
			"terraforming mars", "twilight imperium", "gloomhaven", "wingspan", "agricola", "brass birmingham",
			"spirit island", "through the ages", "twilight struggle", "dune imperium", "ark nova", "great western trail",
			"puerto rico", "power grid", "caverna", "concordia", "food chain magnate", "advanced squad leader",
			"tigris and euphrates", "mage knight", "war of the ring", "star wars rebellion", "1830",
		},
	},
	aliases = {
		["cluedo"] = "clue", ["draughts"] = "checkers", ["settlers of catan"] = "catan", ["connect 4"] = "connect four",
		["four in a row"] = "connect four", ["game of life"] = "life", ["snakes and ladders"] = "chutes and ladders",
		["reversi"] = "othello", ["pachisi"] = "parcheesi", ["mousetrap"] = "mouse trap",
		["hi ho cherry o"] = "hi ho cherryo", ["seven wonders"] = "7 wonders", ["tafl"] = "hnefatafl",
		["chinese chess"] = "xiangqi", ["pay day"] = "payday",
	},
}
