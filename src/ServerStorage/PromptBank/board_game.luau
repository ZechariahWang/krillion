--!strict
return {
	id = "board_game",
	prompt = "Name a board or card game",
	answers = {
		Plankton = {
			"monopoly", "chess", "scrabble", "checkers", "uno",
		},
		TooClever = {
			"go",
		},
		Schooler = {
			"go fish", "solitaire", "jenga", "yahtzee", "old maid", "war", "crazy eights", "spoons", "slapjack",
			"exploding kittens", "apples to apples", "twister", "hearts", "spades", "rummy", "speed", "skipbo", "phase 10",
			"memory", "dominoes", "pokemon cards", "clue", "risk", "battleship", "backgammon", "sorry", "connect four",
			"candy land", "trouble", "operation", "life", "chutes and ladders", "guess who", "mouse trap", "trivial pursuit",
			"pictionary", "catan",
		},
		Rare = {
			"egyptian ratscrew", "spit", "nertz", "euchre", "gin rummy", "cribbage", "bridge", "canasta", "pinochle",
			"kings in the corner", "president", "cheat", "mao", "pig", "garbage", "golf", "pit", "ratatat cat",
			"sleeping queens", "monopoly deal", "sushi go", "love letter", "coup", "the resistance", "avalon", "werewolf",
			"mafia", "telestrations", "boggle", "scattergories", "taboo", "headbanz", "bananagrams", "rummikub", "qwirkle",
			"magic the gathering", "yugioh", "spot it", "five crowns", "set", "dutch blitz", "ticket to ride", "pandemic",
			"mancala", "othello", "parcheesi", "ludo", "hungry hungry hippos", "cranium", "mastermind", "sequence",
			"chinese checkers", "hi ho cherryo", "kerplunk", "payday", "careers", "blokus", "stratego", "carcassonne",
			"azul", "codenames", "splendor", "dixit", "king of tokyo", "forbidden island", "shogi", "xiangqi",
		},
		DeepCut = {
			"whist", "skat", "durak", "briscola", "scopa", "sheepshead", "hanabi", "the mind", "the crew", "6 nimmt",
			"skull", "wizard", "rook", "concentration", "dominion", "7 wonders", "sagrada", "patchwork",
			"betrayal at house on the hill", "small world", "scythe", "root", "everdell", "risk legacy", "arkham horror",
			"mysterium", "takenoko", "hive", "santorini", "quoridor", "abalone", "kingdomino", "halma", "nine mens morris",
			"hnefatafl", "senet", "royal game of ur", "game of the goose", "diplomacy", "axis and allies",
			"forbidden desert", "pandemic legacy", "fox and geese",
		},
		OneInAKrillion = {
			"tichu", "cuttle", "hanafuda", "big two", "tien len", "belote", "terraforming mars", "twilight imperium",
			"gloomhaven", "wingspan", "agricola", "brass birmingham", "spirit island", "through the ages",
			"twilight struggle", "dune imperium", "ark nova", "great western trail", "puerto rico", "power grid", "caverna",
			"concordia", "food chain magnate", "advanced squad leader", "tigris and euphrates", "mage knight",
			"war of the ring", "star wars rebellion", "1830",
		},
	},
	aliases = {
		["skip bo"] = "skipbo", ["yu gi oh"] = "yugioh", ["rat a tat cat"] = "ratatat cat", ["dobble"] = "spot it",
		["magic"] = "magic the gathering", ["mtg"] = "magic the gathering", ["pokemon tcg"] = "pokemon cards",
		["pokemon trading card game"] = "pokemon cards", ["egyptian rat screw"] = "egyptian ratscrew",
		["slap jack"] = "slapjack", ["crazy 8s"] = "crazy eights", ["kings corner"] = "kings in the corner",
		["i doubt it"] = "cheat", ["phase ten"] = "phase 10", ["klondike"] = "solitaire", ["domino"] = "dominoes",
		["six nimmt"] = "6 nimmt", ["cluedo"] = "clue", ["draughts"] = "checkers", ["settlers of catan"] = "catan",
		["connect 4"] = "connect four", ["four in a row"] = "connect four", ["game of life"] = "life",
		["snakes and ladders"] = "chutes and ladders", ["reversi"] = "othello", ["pachisi"] = "parcheesi",
		["mousetrap"] = "mouse trap", ["hi ho cherry o"] = "hi ho cherryo", ["seven wonders"] = "7 wonders",
		["tafl"] = "hnefatafl", ["chinese chess"] = "xiangqi", ["pay day"] = "payday",
	},
}
