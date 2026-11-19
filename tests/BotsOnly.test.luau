local BotsOnly = require("../src/ReplicatedStorage/Shared/BotsOnly")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local function state(over: { [string]: any }): BotsOnly.KeepGoing
	local base = { humansInServer = 1, aliveBots = 4, soloRounds = 0, revivePending = false }
	for key, value in over do
		base[key] = value
	end
	return base :: any
end

return function(test)
	test("bots-only: the match runs on while someone can still play", function()
		assert(BotsOnly.keepGoing(state({})))
		assert(not BotsOnly.keepGoing(state({ humansInServer = 0 })), "an empty or all-AFK server ends at once")
		assert(not BotsOnly.keepGoing(state({ aliveBots = 1 })), "one bot left: the match is decided")
	end)

	test("bots-only: it stops after SoloRoundsMax rounds unless a revive is pending", function()
		local cap = GameConfig.Bots.SoloRoundsMax
		assert(BotsOnly.keepGoing(state({ soloRounds = cap - 1 })))
		assert(not BotsOnly.keepGoing(state({ soloRounds = cap })))
		assert(BotsOnly.keepGoing(state({ soloRounds = cap, revivePending = true })), "a pending revive is not cut off")
		assert(not BotsOnly.keepGoing(state({ revivePending = true, humansInServer = 0 })))
	end)

	test("bots play worse after a paid boost and in bots-only rounds, and worst with both", function()
		local skill = 0.4
		local normal = BotsOnly.skill(skill, false, false)
		local paid = BotsOnly.skill(skill, true, false)
		local solo = BotsOnly.skill(skill, false, true)
		local both = BotsOnly.skill(skill, true, true)
		assert(normal == skill)
		assert(paid < normal and solo < normal and both < paid and both < solo)
		assert(BotsOnly.missChance(false, false) == 0)
		assert(BotsOnly.missChance(true, false) > 0 and BotsOnly.missChance(false, true) > 0)
		assert(BotsOnly.missChance(true, true) > BotsOnly.missChance(true, false))
		assert(BotsOnly.missChance(true, true) < 1)
	end)

	test("bots-only rounds rise faster and are shorter; normal rounds are untouched", function()
		assert(BotsOnly.surge(3, false) == 3)
		assert(BotsOnly.surge(3, true) > 3)
		assert(BotsOnly.promptSeconds(20, false) == 20)
		assert(BotsOnly.promptSeconds(20, true) == GameConfig.Round.SoloPromptSeconds)
		assert(BotsOnly.promptSeconds(5, true) == 5, "never longer than the normal time")
	end)
end
