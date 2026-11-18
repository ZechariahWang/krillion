local BotBrain = require("../src/ReplicatedStorage/Shared/BotBrain")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Tiers = require("../src/ReplicatedStorage/Config/Tiers")

local BANK = {
	Plankton = { "cod", "tuna", "salmon" },
	Schooler = { "eel" },
	Rare = { "sunfish", "oarfish" },
}

local function meanTier(skill: number): number
	local total = 0
	local count = 0
	for step = -20, 20 do
		local tier = BotBrain.chooseTier(skill, step / 10)
		assert(tier ~= nil)
		total += tier
		count += 1
	end
	return total / count
end

return function(test)
	test("bots: fill tops up to FillTo", function()
		assert(BotBrain.fillCount(1, 4, 12) == 3)
		assert(BotBrain.fillCount(4, 4, 12) == 0)
		assert(BotBrain.fillCount(6, 4, 12) == 0)
		assert(BotBrain.fillCount(1, 0, 12) == 0, "FillTo 0 turns bots off")
		assert(BotBrain.fillCount(1, 4, 2) == 1, "never more pillars than the arena holds")
		assert(BotBrain.fillCount(1, GameConfig.Bots.FillTo, GameConfig.Server.MaxPlayers) == 5, "a lone player gets five bots")
	end)

	test("bots: a username reads like a player's: a word, a capitalised word, a number", function()
		local name = BotBrain.username(0, 0, 0)
		assert(string.match(name, "^%l+%u%l+%d+$") ~= nil, name)
		assert(BotBrain.username(0, 0, 0) == name, "the same rolls give the same name")
		assert(BotBrain.username(0.99, 0.99, 0.99) ~= name)
		assert(string.match(BotBrain.username(0.99, 0.99, 0.99), "^%l+%u%l+%d+$") ~= nil)
	end)

	test("bots: pickName rolls again past a taken name, and still finds a free one when the rolls repeat", function()
		local taken = BotBrain.username(0, 0, 0)
		local rolls = { 0, 0, 0, 0.5, 0.5, 0.5 }
		local at = 0
		local function nextRoll(): number
			at += 1
			return rolls[at]
		end
		assert(BotBrain.pickName(nextRoll, { [taken] = true }) == BotBrain.username(0.5, 0.5, 0.5))
		local stuck = BotBrain.pickName(function()
			return 0
		end, { [taken] = true })
		assert(stuck ~= taken and string.sub(stuck, 1, #taken) == taken)
	end)

	test("bots: skill stays within MinSkill and MaxSkill", function()
		assert(BotBrain.skill(0) == GameConfig.Bots.MinSkill)
		assert(math.abs(BotBrain.skill(1) - GameConfig.Bots.MaxSkill) < 1e-9)
		for _, roll in { -1, 0.25, 0.5, 0.99, 2 } do
			local skill = BotBrain.skill(roll)
			assert(skill >= GameConfig.Bots.MinSkill and skill <= GameConfig.Bots.MaxSkill, "skill " .. skill)
		end
	end)

	test("bots: every bot aims at a tier every prompt, the weakest too", function()
		for _, skill in { 0, GameConfig.Bots.MinSkill, 0.5, GameConfig.Bots.MaxSkill, 1 } do
			for _, z in { -3, 0, 3 } do
				local tier = BotBrain.chooseTier(skill, z)
				assert(type(tier) == "number", "skill " .. skill .. " missed the prompt")
			end
		end
	end)

	test("bots: higher skill aims at a deeper tier on average, always within the tier list", function()
		assert(meanTier(0.85) > meanTier(0.15) + 1)
		for _, z in { -10, 10 } do
			local tier = BotBrain.chooseTier(0.5, z)
			assert(tier >= 1 and tier <= #Tiers.List, "tier " .. tier)
		end
		assert(BotBrain.chooseTier(0, 0) == 1)
		assert(BotBrain.chooseTier(1, 0) == 5)
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

	test("bots: a typical bot reaches Rare far less often than players do (about 27%)", function()
		-- Every skill roll and a spread of tier rolls, weighted like a normal curve.
		local rare = Tiers.index("Rare")
		local hits = 0
		local weight = 0
		for skillStep = 0, 20 do
			local skill = BotBrain.skill(skillStep / 20)
			for zStep = -30, 30 do
				local z = zStep / 10
				local w = math.exp(-z * z / 2)
				weight += w
				if BotBrain.chooseTier(skill, z) >= rare then
					hits += w
				end
			end
		end
		local share = hits / weight
		assert(share < 0.2, "bots reach Rare or better " .. math.floor(share * 100 + 0.5) .. "% of the time")
	end)
end
