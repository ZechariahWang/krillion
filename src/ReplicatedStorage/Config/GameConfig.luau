--!strict
-- Every gameplay tunable lives here. Numbers only, no Roblox types, so Lune tests can require it.

local GameConfig = {
	Round = {
		MinPlayers = 1, -- one player plays solo until they sink; two or more play last-player-standing
		IntermissionSeconds = 15,
		PromptSeconds = 20,
		PromptSecondsStep = 1.5, -- subtracted per round after the first, then floored to whole seconds
		PromptSecondsMin = 10,
		RevealSeconds = 5,
		SurgeSeconds = 3,
		ResultsSeconds = 10,
		MaxRounds = 0, -- 0 means no cap: last player standing
		SuddenDeathAlive = 2, -- banner only, no rule change
		DangerSeconds = 5, -- timer turns red and shakes below this
		CloseCallStuds = 1.5, -- "CLOSE CALL!" when you end a surge this close to the water
		StreakMinPoints = 60, -- answers worth at least this much build a streak
	},
	Water = {
		StartHeight = 6, -- platform top above the starting water line
		SurgeBase = 2,
		SurgeStep = 0.6, -- added per round
		LiftPerPoint = 0.1,
		CullHz = 10,
		CreepFraction = 0.7, -- slow part of the surge
		CreepSeconds = 2,
		JumpSeconds = 0.4,
	},
	Platform = {
		Width = 8,
		Height = 140, -- tall enough to reach the tank floor at any height
		Spacing = 16,
		Columns = 4,
		WalkSpeed = 10, -- slower on the pillar so a stray key press is not instant death
		RiseStageFraction = 0.65,
		RiseStageSeconds = 0.6,
		RiseHoldSeconds = 0.4,
		RiseSnapSeconds = 0.5,
		ConfettiMinPoints = 60,
	},
	Answer = {
		MaxLength = 40,
		FuzzyMinLength = 5, -- shorter answers must be spelled exactly
		FuzzyLongLength = 10, -- answers this long or longer forgive two typos instead of one
		RetryCooldown = 1, -- seconds between guesses, so a wrong answer can be retried but not spammed
	},
	Lobby = {
		DeckHeight = 6, -- boardwalk height above the starting water; low enough to look into the tank
		QuizSeconds = 20,
		CoinsPerPoint = 0.5,
	},
	Special = {
		MinRound = 3, -- no special rounds before this
		Chance = 0.25, -- per eligible round; never two in a row
		TidalWaveMultiplier = 2, -- water rises this many times further
		DoubleLiftMultiplier = 2, -- pillars rise this many times further
	},
	Server = {
		MaxPlayers = 12,
	},
}

table.freeze(GameConfig.Round)
table.freeze(GameConfig.Water)
table.freeze(GameConfig.Platform)
table.freeze(GameConfig.Answer)
table.freeze(GameConfig.Lobby)
table.freeze(GameConfig.Special)
table.freeze(GameConfig.Server)
return table.freeze(GameConfig)
