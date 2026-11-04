local BotBrain = require("../src/ReplicatedStorage/Shared/BotBrain")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

local BANK = {
	Plankton = { "cod", "tuna", "salmon" },
	Schooler = { "eel" },
	Rare = { "sunfish", "oarfish" },
}

-- A roll that never takes the no-answer branch.
local ANSWERS = 0.999

local function meanTier(skill: number): number
	local total = 0
	local count = 0
	for step = -20, 20 do
		local tier = BotBrain.chooseTier(skill, ANSWERS, step / 10)
		assert(tier ~= nil)
		total += tier
		count += 1
	end
	return total / count
end

return function(test)
	test("bots: twelve distinct names, and fill tops up to FillTo", function()
		assert(#BotBrain.Names == 12)
		local seen = {}
		for _, name in BotBrain.Names do
			assert(not seen[name], name .. " twice")
			seen[name] = true
		end
		assert(BotBrain.fillCount(1, 4, 12) == 3)
		assert(BotBrain.fillCount(4, 4, 12) == 0)
		assert(BotBrain.fillCount(6, 4, 12) == 0)
		assert(BotBrain.fillCount(1, 0, 12) == 0, "FillTo 0 turns bots off")
		assert(BotBrain.fillCount(1, 4, 2) == 1, "never more pillars than the arena holds")
	end)

	test("bots: pickName skips taken names and numbers them once all are used", function()
		assert(BotBrain.pickName(1, {}) == BotBrain.Names[1])
		assert(BotBrain.pickName(1, { [BotBrain.Names[1]] = true }) == BotBrain.Names[2])
		assert(BotBrain.pickName(13, {}) == BotBrain.Names[1], "start wraps round the list")
		local all = {}
		for _, name in BotBrain.Names do
			all[name] = true
		end
		assert(BotBrain.pickName(3, all) == BotBrain.Names[3] .. " 2")
		all[BotBrain.Names[3] .. " 2"] = true
		assert(BotBrain.pickName(3, all) == BotBrain.Names[3] .. " 3")
	end)

	test("bots: skill stays within MinSkill and MaxSkill", function()
		assert(BotBrain.skill(0) == GameConfig.Bots.MinSkill)
		assert(math.abs(BotBrain.skill(1) - GameConfig.Bots.MaxSkill) < 1e-9)
		for _, roll in { -1, 0.25, 0.5, 0.99, 2 } do
			local skill = BotBrain.skill(roll)
			assert(skill >= GameConfig.Bots.MinSkill and skill <= GameConfig.Bots.MaxSkill, "skill " .. skill)
		end
	end)

	test("bots: a low no-answer roll misses the prompt, more often for weak bots", function()
		assert(BotBrain.chooseTier(0.5, 0, 0) == nil)
		local cfg = GameConfig.Bots
		local weakMiss = cfg.NoAnswerBase + cfg.NoAnswerSkill * (1 - 0.15)
		local strongMiss = cfg.NoAnswerBase + cfg.NoAnswerSkill * (1 - 0.85)
		local between = (weakMiss + strongMiss) / 2
		assert(BotBrain.chooseTier(0.15, between, 0) == nil, "weak bot misses")
		assert(BotBrain.chooseTier(0.85, between, 0) ~= nil, "strong bot answers")
	end)

	test("bots: higher skill aims at a deeper tier on average, always within the tier list", function()
		assert(meanTier(0.85) > meanTier(0.15) + 1)
		for _, z in { -10, 10 } do
			local tier = BotBrain.chooseTier(0.5, ANSWERS, z) :: number
			assert(tier >= 1 and tier <= #Tiers.List, "tier " .. tier)
		end
		assert(BotBrain.chooseTier(0, ANSWERS, 0) == 1)
		assert(BotBrain.chooseTier(1, ANSWERS, 0) == 5)
	end)

	test("bots: gaussian is centred and finite even for a zero roll", function()
		assert(math.abs(BotBrain.gaussian(math.exp(-0.5), 0) - 1) < 1e-9)
		local z = BotBrain.gaussian(0, 0.5)
		assert(z == z and z > -math.huge and z < math.huge)
	end)

	test("bots: chooseAnswer avoids taken answers and returns nil for an empty tier", function()
		for _, roll in { 0, 0.5, 0.99 } do
			local answer = BotBrain.chooseAnswer(BANK, 1, { cod = true, tuna = true }, roll)
			assert(answer == "salmon", tostring(answer))
		end
		assert(BotBrain.chooseAnswer(BANK, 3, { eel = true }, 0.5) == "eel", "all taken: share rather than skip")
		assert(BotBrain.chooseAnswer(BANK, 2, {}, 0.5) == nil, "TooClever has no answers")
		assert(BotBrain.chooseAnswer(BANK, 6, {}, 0.5) == nil)
		assert(BotBrain.chooseAnswer(BANK, 99, {}, 0.5) == nil)
	end)

	test("bots: nearestTier finds the closest tier with answers", function()
		assert(BotBrain.nearestTier(BANK, 1) == 1)
		assert(BotBrain.nearestTier(BANK, 2) == 1, "a tie goes to the shallower tier")
		assert(BotBrain.nearestTier(BANK, 6) == 4)
		assert(BotBrain.nearestTier(BANK, 5) == 4)
		assert(BotBrain.nearestTier({}, 3) == nil)
	end)

	test("bots: delay lands between DelayMin and DelayMin + DelayRange of the prompt", function()
		local cfg = GameConfig.Bots
		assert(math.abs(BotBrain.delay(20, 0) - 20 * cfg.DelayMin) < 1e-9)
		assert(math.abs(BotBrain.delay(20, 1) - 20 * (cfg.DelayMin + cfg.DelayRange)) < 1e-9)
		for _, roll in { -1, 0.3, 0.7, 2 } do
			local delay = BotBrain.delay(20, roll)
			assert(delay >= 20 * cfg.DelayMin - 1e-9 and delay <= 20 * (cfg.DelayMin + cfg.DelayRange) + 1e-9)
		end
		assert(BotBrain.delay(20, 1) < 20, "a bot always answers before the prompt ends")
	end)
end
