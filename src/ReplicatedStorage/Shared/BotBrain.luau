--!strict
-- What a bot is like and how it answers: its name, skill, which tier it aims for, which answer it picks
-- and when it locks in. Every random choice is a roll passed in, so Lune tests can pin the outcome.
-- Pure (no Roblox APIs), so Lune tests can require it.

local GameConfig = require("../Config/GameConfig")
local Tiers = require("../Config/Tiers")

local TIER_SPREAD = 1.2 -- standard deviation, in tiers, around a bot's aim

-- A bot's name is FIRST + SECOND + a number, the way players name themselves ("dogLover234").
local FIRST = {
	"dog", "cat", "pizza", "taco", "ninja", "panda", "cookie", "shadow", "turbo", "mango",
	"pixel", "frog", "bacon", "robo", "star", "lava", "frost", "sushi", "melon", "waffle",
	"dino", "bunny", "pickle", "noodle", "comet", "tiger", "banana", "storm", "lemon", "otter",
}
local SECOND = {
	"Lover", "King", "Queen", "Master", "Gamer", "Fan", "Boss", "Hero", "Pro", "Wizard",
	"Legend", "Girl", "Boy", "Dude", "Rider", "Plays", "Squad", "Champ", "Kid", "Star",
}
local NUMBER_MIN = 10
local NUMBER_MAX = 999
local NAME_TRIES = 20 -- rolls for a free name before a taken one gets an extra digit

local BotBrain = {}

-- How many bots top a match of `humans` up to `fillTo` (0 turns bots off), within `maxSlots` pillars.
function BotBrain.fillCount(humans: number, fillTo: number, maxSlots: number): number
	return math.max(0, math.min(fillTo, maxSlots) - humans)
end

local function pick(list: { string }, roll: number): string
	local index = math.clamp(math.floor(roll * #list) + 1, 1, #list)
	return list[index]
end

-- Each roll is in [0, 1): the first word, the second word, the number.
function BotBrain.username(rollFirst: number, rollSecond: number, rollNumber: number): string
	local span = NUMBER_MAX - NUMBER_MIN + 1
	local number = NUMBER_MIN + math.clamp(math.floor(rollNumber * span), 0, span - 1)
	return pick(FIRST, rollFirst) .. pick(SECOND, rollSecond) .. number
end

-- A username nobody in `used` has. `nextRoll` gives a fresh roll in [0, 1) each call.
function BotBrain.pickName(nextRoll: () -> number, used: { [string]: boolean }): string
	local name = ""
	for _ = 1, NAME_TRIES do
		name = BotBrain.username(nextRoll(), nextRoll(), nextRoll())
		if not used[name] then
			return name
		end
	end
	local digit = 0
	while used[name .. digit] do
		digit += 1
	end
	return name .. digit
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

-- The Tiers.List index a bot aims for: a bot answers every prompt. Skilled bots aim deeper: the aim is
-- 1 + 4 * skill, spread by TIER_SPREAD times `z` (a standard normal deviate).
function BotBrain.chooseTier(skill: number, z: number): number
	local s = math.clamp(skill, 0, 1)
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
