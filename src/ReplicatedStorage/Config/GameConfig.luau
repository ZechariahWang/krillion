--!strict
-- Every gameplay tunable lives here. Numbers only, no Roblox types, so Lune tests can require it.

local GameConfig = {
	Round = {
		MinPlayers = 2, -- 1 turns on solo practice matches on empty servers
		IntermissionSeconds = 15,
		PromptSeconds = 20,
		PromptSecondsStep = 1.5, -- subtracted per round after the first
		PromptSecondsMin = 10,
		RevealSeconds = 5,
		SurgeSeconds = 3,
		ResultsSeconds = 10,
		MaxRounds = 0, -- 0 means no cap: last player standing
		SuddenDeathAlive = 2, -- banner only, no rule change
		DangerSeconds = 5, -- timer turns red and pulses below this
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
		Radius = 4,
		Spacing = 16,
		Columns = 4,
		RiseStageFraction = 0.65,
		RiseStageSeconds = 0.6,
		RiseHoldSeconds = 0.4,
		RiseSnapSeconds = 0.5,
	},
	Answer = {
		MaxLength = 40,
		FuzzyMinLength = 5,
		FuzzyMaxDistance = 1,
	},
	Lobby = {
		HeightAboveArena = 120,
		QuizSeconds = 20,
		CoinsPerPoint = 0.5,
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
table.freeze(GameConfig.Server)
return table.freeze(GameConfig)
