local Levels = require("../src/ReplicatedStorage/Shared/Levels")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local RULES = GameConfig.Levels

return function(test)
	test("a level costs the first level's XP plus one step per level after it", function()
		assert(Levels.costOf(1) == RULES.FirstLevelXp)
		assert(Levels.costOf(2) == RULES.FirstLevelXp + RULES.StepXp)
		assert(Levels.costOf(5) == RULES.FirstLevelXp + 4 * RULES.StepXp)
	end)

	test("the level goes up exactly when its cost is reached", function()
		local first = RULES.FirstLevelXp
		assert(Levels.levelOf(0) == 1)
		assert(Levels.levelOf(first - 1) == 1)
		assert(Levels.levelOf(first) == 2)
		local secondEnd = first + Levels.costOf(2)
		assert(Levels.levelOf(secondEnd - 1) == 2)
		assert(Levels.levelOf(secondEnd) == 3)
	end)

	test("progress gives the XP into the level and the XP the level needs", function()
		local first = RULES.FirstLevelXp
		local info = Levels.progress(first + 10)
		assert(info.level == 2, "level " .. info.level)
		assert(info.into == 10, "into " .. info.into)
		assert(info.need == Levels.costOf(2), "need " .. info.need)
	end)

	test("negative or broken XP counts as level 1", function()
		assert(Levels.levelOf(-50) == 1)
		assert(Levels.levelOf(0 / 0) == 1)
	end)

	test("levels gained counts every level crossed", function()
		local first = RULES.FirstLevelXp
		assert(Levels.gained(0, first - 1) == 0)
		assert(Levels.gained(first - 1, first) == 1)
		assert(Levels.gained(0, first + Levels.costOf(2) + Levels.costOf(3)) == 3)
	end)

	test("answer XP follows the tier and a missing answer gives none", function()
		assert(Levels.answerXp(nil) == 0)
		assert(Levels.answerXp("Mythic") > Levels.answerXp("Plankton"))
		assert(Levels.answerXp("Plankton") > 0)
	end)

	test("the name row shows the level before the name", function()
		local text = Levels.tagName(12, "dogLover234")
		assert(string.find(text, "12", 1, true) ~= nil)
		assert(string.find(text, "dogLover234", 1, true) ~= nil)
		assert(string.find(text, "12", 1, true) < string.find(text, "dogLover234", 1, true))
	end)
end
