--!strict
-- Every gameplay tunable lives here. Numbers only, no Roblox types, so Lune tests can require it.
-- Flags are 1 (on) or 0 (off) so the whole table stays numeric.

local GameConfig = {
	Round = {
		MinPlayers = 1, -- one player plays solo until they sink; two or more play last-player-standing
		IntermissionSeconds = 15,
		IntroFadeSeconds = 0.35, -- screens fade to black this long before the teleport onto the pillars
		StartCountdownSeconds = 3, -- the 3-2-1 on the pillars before round 1
		PromptSeconds = 20,
		PromptSecondsStep = 1.5, -- subtracted per round after the first, then floored to whole seconds
		PromptSecondsMin = 10,
		RevealSeconds = 7.5, -- long enough for the dive card to land (Reveal.RaiseDelaySeconds) and the pillar to rise
		SettleSeconds = 1.5, -- after the water settles, before the next prompt or the results: room for the callouts
		ResultsSeconds = 10,
		MaxRounds = 0, -- 0 means no cap: last player standing
		SuddenDeathAlive = 2, -- banner only, no rule change
		DangerSeconds = 5, -- timer turns red and shakes below this
		CloseCallStuds = 1.5, -- "CLOSE CALL!" when you end a surge this close to the water
		StreakMinPoints = 60, -- answers worth at least this much build a streak
		AllLockedGrace = 1.5, -- the prompt ends this long after every eligible player has locked in
		LockBroadcastSeconds = 0.25, -- a lock-in pushes a state update this soon (at most 4 a second)
	},
	Water = {
		StartHeight = 6, -- platform top above the starting water line
		-- Round r surges SurgeBase + SurgeGrowth * (r - 1) ^ SurgePower; tests/WaterCurve pins the survival targets.
		SurgeBase = 0.5,
		SurgeGrowth = 0.4,
		SurgePower = 1.5,
		LiftPerPoint = 0.1,
		CullHz = 10,
		CreepFraction = 0.7, -- slow part of the surge
		CreepSeconds = 2,
		JumpSeconds = 0.4,
	},
	Platform = {
		Height = 140, -- tall enough to reach the tank floor at any height
		Spacing = 16, -- preferred distance between pillar centres
		MinSpacing = 13, -- a full ring (16 players) squeezes down to this to stay inside RingMaxRadius
		RingMaxRadius = 34, -- outermost pillar centre; the reef rim sits outside this
		RiseSeconds = 1.1, -- one eased glide with a soft overshoot at the top
		ConfettiMinPoints = 60,
		WalkSpeed = 10, -- players stroll around their pillar top during a match; jumping stays off
	},
	Answer = {
		MaxLength = 40,
		FuzzyMinLength = 5, -- shorter answers must be spelled exactly
		FuzzyLongLength = 10, -- answers this long or longer forgive two typos instead of one (never more)
		RetryCooldown = 1, -- seconds between guesses, so a wrong answer can be retried but not spammed
		CheckMinInterval = 0.35, -- seconds between Enter-to-check presses after a valid check
		MaxChecksPerRound = 40, -- per player per prompt (and per lobby prompt)
		DeadlineGrace = 0.5, -- network slack after a player's deadline before answers are refused
	},
	DayCycle = {
		CycleSeconds = 720, -- one full day and night
		NightShare = 0.25, -- of the cycle spent between dusk and dawn
		DawnClock = 5.5, -- Lighting.ClockTime where night ends
		DuskClock = 18.5, -- Lighting.ClockTime where night begins
	},
	Lobby = {
		QuizEnabled = 1, -- 1 serves warm-up prompts inside Lobby.QuizZone (in front of the shack); 0 turns the quiz off
		QuizSeconds = 20,
		CashPerPoint = 0.2, -- lobby quiz pays clearly less than surviving a match round
		DailyShellCap = 600, -- warm-up Shells per UTC day, after pass multipliers; matches are not capped
		RecentMemory = 12, -- a player's last N warm-up prompts are not served again
		AutoNextSeconds = 4, -- the result card moves on to the next prompt by itself after this
		NextDelaySeconds = 2.5, -- minimum gap between a result and the next prompt
		ExpiryGrace = 0.5, -- a warm-up answer this late after the prompt's timer is still accepted
	},
	Cash = {
		PerRoundSurvived = 25,
		WinBonus = 100,
		VipBonus = 0.1, -- multiplier bonuses add: VIP + 2x Shells = 2.1x (0.25 is proposed, not agreed)
		DoubleBonus = 1,
		MaxPetBonus = 0.25, -- the best pet's bonus; a bad config can never pay more than this
		ChestSessionLimit = 50, -- chest openings per player per server visit, a guard against runaway spending
		ChestCooldown = 1.2, -- seconds between chest openings (the open animation's length)
		StartingShells = 100, -- one-time gift to a brand-new profile
		-- Paid per graded match answer, after the dive card lands (Reveal.PayoutDelaySeconds).
		AnswerByTier = {
			Plankton = 5,
			TooClever = 5,
			Schooler = 10,
			Rare = 20,
			DeepCut = 30,
			Mythic = 50,
		},
	},
	Boosts = {
		Enabled = 1, -- 0 hides both in-match boosts and refuses UseBoost
		ExtraTimeShells = 75, -- a hint has no Shell price: it is only ever paid for with Robux
		ExtraTimeSeconds = 10,
		PerRound = 1, -- +time uses per round; a hint has no limit
		PerMatch = 3, -- +time uses per match
		PerMatchPlus = 5, -- +time uses per match for holders of the Boost Plus game pass
		Cooldown = 0.5, -- seconds between UseBoost requests
		PurchaseWaitSeconds = 5, -- how long a Robux-bought boost waits for its receipt before giving up
	},
	LateJoin = {
		Enabled = 1,
		MaxRound = 2, -- joining is open up to and including this round
		MinSecondsLeft = 8, -- in MaxRound, only while this many prompt seconds remain
		ReserveSlots = 4, -- late joiners a match may take on top of its starters; their pillars go in free gaps
	},
	Schooling = {
		Enabled = 0, -- off until Zechariah agrees: two players with the same answer each get Factor of the points
		Factor = 0.5,
	},
	Quests = {
		PerDay = 3,
		PlaySecondsTick = 30, -- play-time quests advance this often
	},
	Rewards = {
		GroupId = 36001322,
		WelcomeShells = 200, -- for a new player who arrived from a friend's invite
		GroupShells = 250,
		ReferralTier1 = 1, -- friends who finished a match: unlocks the first referral reward
		ReferralTier2 = 3,
		FavoriteNudgeAfterMatches = 2, -- one unrewarded "favorite the game" toast after this many matches
		GroupRecheckSeconds = 10, -- minimum gap between group claim re-checks
		JoinDataWaitSeconds = 5, -- join data can arrive a few seconds after the player
	},
	Reveal = {
		-- Your full-screen dive card: stamp lands by CardBudgetSeconds (deep dives play a little faster), the
		-- card holds CardHoldSeconds after the stamp settles (~0.3 s), then shrinks away (0.25 s). That is
		-- at most ~4.3 s, so it is gone before the rise at RaiseDelaySeconds. The dive winds up slowly, then
		-- bursts (Depth.dive), so it needs a little longer than a plain ease.
		CardBudgetSeconds = 3.3,
		CardHoldSeconds = 0.45,
		RaiseDelaySeconds = 4.5, -- pillars start rising this long after the reveal, once your card is out of the way
		PayoutDelaySeconds = 4.5, -- answer Shells and Mythic announcements land with the rise
		StatsMinTotal = 40, -- real "1 in N" needs at least this many recorded answers for the prompt
		EstimatedOneIn = 1, -- 1: show a labelled estimate until real data exists; 0: show the tier blurb
	},
	Depth = {
		SkyMetres = 40, -- sky shown above the surface at the top of a dive
		MaxMetres = 620, -- bottom of the depth scale
		ViewMetres = 230, -- how much of the scale the dive window shows at once
	},
	Bots = {
		FillTo = 4, -- matches with fewer humans are topped up with bots to this size; 0 turns bots off
		MinSkill = 0.15,
		MaxSkill = 0.85,
		NoAnswerBase = 0.06, -- chance a bot misses the prompt, plus NoAnswerSkill * (1 - skill)
		NoAnswerSkill = 0.12,
		DelayMin = 0.25, -- bots answer between DelayMin and DelayMin + DelayRange of the prompt time
		DelayRange = 0.6,
	},
	Revive = {
		WindowSeconds = 8, -- long enough for a child to read the card and tap it
		BuyWindowSeconds = 12, -- Revive Now: long enough to get through the Robux purchase dialog
		MinOthersAlive = 2, -- fewer than this and the match is already decided
		HeightAboveWater = 4,
	},
	-- Shells lying on the island between rounds (PickupService). SessionCap is per visit.
	Pickups = {
		Enabled = 1,
		Max = 10, -- on the island at once
		SpawnSeconds = 8,
		Shells = 1, -- per shell picked up
		SessionCap = 100,
	},
	-- Lobby throwables (Cosmetics slot Toy): owned forever, never usable on a pillar.
	Toys = {
		Cooldown = 2.5, -- seconds between throws
		Range = 90, -- studs; a target further away is refused
		FlightSeconds = 0.45, -- how long the toy is in the air (the hit lands when it arrives)
		SplatSeconds = 2.2, -- how long the splat covers the hit player's screen
	},
	Leaderboard = {
		RefreshSeconds = 60,
		Size = 10,
	},
	Special = {
		MinRound = 3, -- no special rounds before this
		Chance = 0.25, -- per eligible round; never two in a row
		TidalWaveMultiplier = 2, -- water rises this many times further
		DoubleLiftMultiplier = 2, -- pillars rise this many times further
	},
	Server = {
		MaxPlayers = 16, -- also set Server Size to 16 in the Creator Hub (Places > Configure)
	},
}

table.freeze(GameConfig.Round)
table.freeze(GameConfig.Water)
table.freeze(GameConfig.Platform)
table.freeze(GameConfig.Answer)
table.freeze(GameConfig.Lobby)
table.freeze(GameConfig.Special)
table.freeze(GameConfig.Cash.AnswerByTier)
table.freeze(GameConfig.Cash)
table.freeze(GameConfig.Boosts)
table.freeze(GameConfig.LateJoin)
table.freeze(GameConfig.Schooling)
table.freeze(GameConfig.Quests)
table.freeze(GameConfig.Rewards)
table.freeze(GameConfig.Reveal)
table.freeze(GameConfig.Depth)
table.freeze(GameConfig.Bots)
table.freeze(GameConfig.Revive)
table.freeze(GameConfig.Toys)
table.freeze(GameConfig.Leaderboard)
table.freeze(GameConfig.Server)
return table.freeze(GameConfig)
