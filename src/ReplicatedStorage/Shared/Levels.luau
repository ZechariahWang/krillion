--!strict
-- Player levels: XP to level, progress through a level, and the level a shop item needs.
-- Pure, so Lune tests can require it. Numbers are GameConfig.Levels.
local GameConfig = require("../Config/GameConfig")
local Cosmetics = require("../Config/Cosmetics")
local Tiers = require("../Config/Tiers")

local RULES = GameConfig.Levels

export type Progress = {
	level: number,
	into: number, -- XP gained inside this level
	need: number, -- XP this level costs in all
}

local Levels = {}

-- XP from `level` to the next one.
function Levels.costOf(level: number): number
	return RULES.FirstLevelXp + RULES.StepXp * (level - 1)
end

function Levels.progress(xp: number): Progress
	local left = xp
	if left ~= left or left < 0 then
		left = 0
	end
	local level = 1
	while left >= Levels.costOf(level) do
		left -= Levels.costOf(level)
		level += 1
	end
	return { level = level, into = left, need = Levels.costOf(level) }
end

function Levels.levelOf(xp: number): number
	return Levels.progress(xp).level
end

-- How many levels going from `before` to `after` XP crosses.
function Levels.gained(before: number, after: number): number
	return Levels.levelOf(after) - Levels.levelOf(before)
end

function Levels.requiredLevel(item: Cosmetics.Item): number
	if Cosmetics.source(item) ~= "shells" then
		return 1
	end
	local byRarity: { [string]: number } = RULES.RarityLevel :: any
	return byRarity[item.rarity] or 1
end

function Levels.answerXp(tier: string?): number
	if tier == nil then
		return 0
	end
	return Tiers.points(tier)
end

-- The head label's name row.
function Levels.tagName(level: number, name: string): string
	return "[" .. level .. "] " .. name
end

return Levels
