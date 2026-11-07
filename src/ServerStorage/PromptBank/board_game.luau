--!strict
return {
	id = "board_game",
	prompt = "Name a board game",
	answers = {
		Plankton = {
			"monopoly", "chess", "scrabble",
		},
		TooClever = {
			"go",
		},
		Schooler = {
			"checkers", "clue", "risk", "battleship", "backgammon", "sorry",
		},
		Rare = {
			"catan", "ticket to ride", "pandemic", "trouble", "candy land", "operation",
		},
		DeepCut = {
			"carcassonne", "azul", "codenames", "dominion", "stratego",
		},
		OneInAKrillion = {
			"terraforming mars", "twilight imperium", "gloomhaven", "wingspan", "agricola",
		},
	},
	aliases = {
		["cluedo"] = "clue", ["draughts"] = "checkers", ["settlers of catan"] = "catan",
	},
}
