--!strict
-- What a bot is like and how it answers: its name, skill, which tier it aims for, which answer it picks
-- and when it locks in. Every random choice is a roll passed in, so Lune tests can pin the outcome.
-- Pure (no Roblox APIs), so Lune tests can require it.

local GameConfig = require("../Config/GameConfig")
local Tiers = require("../Config/Tiers")

local TIER_SPREAD = 1.2 -- standard deviation, in tiers, around a bot's aim

local NAMES = {
	"Captain Kelp",
	"Barnacle Bea",
	"Sandy Bottom",
	"Admiral Anchovy",
	"Coral Ray",
	"Finn Fathom",
	"Shelly Tide",
	"Doc Drift",
	"Gill Grouper",
	"Pearl Diver",
	"Inky Squidd",
	"Murky Mo",
}

local BotBrain = {}

BotBrain.Names = table.freeze(NAMES)

-- How many bots top a match of `humans` up to `fillTo` (0 turns bots off), within `maxSlots` pillars.
function BotBrain.fillCount(humans: number, fillTo: number, maxSlots: number): number
	return math.max(0, math.min(fillTo, maxSlots) - humans)
end

-- The first name from `start` (wrapping round the list) that nobody in `used` has; when all are taken,
-- that name with the lowest free number after it ("Captain Kelp 2").
function BotBrain.pickName(start: number, used: { [string]: boolean }): string
	local count = #NAMES
	local first = ((math.floor(start) - 1) % count) + 1
	for offset = 0, count - 1 do
		local name = NAMES[((first - 1 + offset) % count) + 1]
		if not used[name] then
			return name
		end
	end
	local base = NAMES[first]
	local suffix = 2
	while used[base .. " " .. suffix] do
		suffix += 1
	end
	return base .. " " .. suffix
end

-- `roll` in [0, 1) gives a skill in [MinSkill, MaxSkill].
function BotBrain.skill(roll: number): number
	local cfg = GameConfig.Bots
	return cfg.MinSkill + (cfg.MaxSkill - cfg.MinSkill) * math.clamp(roll, 0, 1)
end

-- A standard normal deviate from two uniform rolls in [0, 1) (Box-Muller).
function BotBrain.gaussian(u1: number, u2: number): number
	local safe = math.max(u1, 1e-9)
	return math.sqrt(-2 * math.log(safe)) * math.cos(2 * math.pi * u2)
end

-- The Tiers.List index a bot aims for, or nil when it misses the prompt. Skilled bots miss less and aim
-- deeper: the aim is 1 + 4 * skill, spread by TIER_SPREAD times `z` (a standard normal deviate).
function BotBrain.chooseTier(skill: number, rollNoAnswer: number, z: number): number?
	local cfg = GameConfig.Bots
	local s = math.clamp(skill, 0, 1)
	if rollNoAnswer < cfg.NoAnswerBase + cfg.NoAnswerSkill * (1 - s) then
		return nil
	end
	local aim = 1 + 4 * s + TIER_SPREAD * z
	return math.clamp(math.floor(aim + 0.5), 1, #Tiers.List)
end

local function tierAnswers(answersByTier: { [string]: { string } }, index: number): { string }?
	local tier = Tiers.List[index]
	if tier == nil then
		return nil
	end
	local list = answersByTier[tier.name]
	if list == nil or #list == 0 then
		return nil
	end
	return list
end

-- The tier closest to `index` that has answers in this prompt (the shallower one first on a tie), or nil
-- when the prompt has none at all.
function BotBrain.nearestTier(answersByTier: { [string]: { string } }, index: number): number?
	for distance = 0, #Tiers.List do
		for _, candidate in { index - distance, index + distance } do
			if tierAnswers(answersByTier, candidate) ~= nil then
				return candidate
			end
		end
	end
	return nil
end

-- One answer from the tier at `index`, skipping answers in `taken` (another bot has it). If every answer
-- in the tier is taken it reuses one, since sharing beats staying silent. Nil when the tier is empty.
function BotBrain.chooseAnswer(answersByTier: { [string]: { string } }, index: number, taken: { [string]: boolean }, roll: number): string?
	local list = tierAnswers(answersByTier, index)
	if list == nil then
		return nil
	end
	local free = {}
	for _, answer in list do
		if not taken[answer] then
			table.insert(free, answer)
		end
	end
	local pool = if #free > 0 then free else list
	local pick = math.clamp(math.floor(roll * #pool) + 1, 1, #pool)
	return pool[pick]
end

-- Seconds after the prompt opens that a bot locks in: between DelayMin and DelayMin + DelayRange of it.
function BotBrain.delay(promptSeconds: number, roll: number): number
	local cfg = GameConfig.Bots
	return math.max(0, promptSeconds) * (cfg.DelayMin + cfg.DelayRange * math.clamp(roll, 0, 1))
end

return BotBrain
