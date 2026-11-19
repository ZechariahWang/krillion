local Collection = require("../src/ReplicatedStorage/Shared/Collection")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local CATALOGUE = {
	{ id = "author", prompt = "Name a famous author", top = "Mythic" },
	{ id = "us_president", prompt = "Name a US president", top = "DeepCut" },
	{ id = "wild_cat", prompt = "Name a wild cat", top = "Mythic" },
}

return function(test)
	test("a rarer tier replaces the card and a tie or commoner tier does not", function()
		assert(Collection.better(nil, "Plankton"))
		assert(Collection.better({ tier = "Rare", answer = "x" }, "Mythic"))
		assert(not Collection.better({ tier = "Rare", answer = "x" }, "Rare"))
		assert(not Collection.better({ tier = "Rare", answer = "x" }, "Schooler"))
		assert(not Collection.better(nil, nil))
	end)

	test("a prompt's top tier is the rarest tier it has answers in", function()
		assert(Collection.topTier({ Plankton = { "a" }, Rare = { "b" }, Mythic = {} }) == "Rare")
		assert(Collection.topTier({ Plankton = { "a" }, Mythic = { "z" } }) == "Mythic")
		assert(Collection.topTier({}) == nil)
	end)

	test("a card is mastered at its prompt's top tier", function()
		assert(Collection.isMastered({ tier = "DeepCut", answer = "x" }, "DeepCut"))
		assert(not Collection.isMastered({ tier = "Rare", answer = "x" }, "DeepCut"))
		assert(not Collection.isMastered(nil, "Mythic"))
	end)

	test("counts only prompts still in the catalogue", function()
		local cards = {
			author = { tier = "Mythic", answer = "aesop" },
			us_president = { tier = "Rare", answer = "polk" },
			retired_prompt = { tier = "Mythic", answer = "gone" },
		}
		local found, mastered = Collection.counts(cards, CATALOGUE)
		assert(found == 2, "found " .. found)
		assert(mastered == 1, "mastered " .. mastered)
	end)

	test("milestones are reached by mastered count, the last one by mastering everything", function()
		local milestones = GameConfig.Collection.Milestones
		local first = milestones[1]
		assert(#Collection.reached(first.count - 1, 300) == 0)
		local reached = Collection.reached(first.count, 300)
		assert(#reached == 1 and reached[1].id == Collection.idOf(first))
		local all = Collection.reached(300, 300)
		assert(#all == #milestones)
		local beforeAll = Collection.reached(299, 300)
		assert(#beforeAll == #milestones - 1)
	end)

	test("the next milestone is the first not yet reached", function()
		local milestones = GameConfig.Collection.Milestones
		local nextOne = Collection.nextMilestone(0, 300)
		assert(nextOne ~= nil and nextOne.id == Collection.idOf(milestones[1]))
		assert(Collection.nextMilestone(300, 300) == nil)
	end)

	test("a milestone that needs more than the whole album is skipped, so a small bank can still finish", function()
		local reached = Collection.reached(3, 3)
		local hasAll = false
		for _, milestone in reached do
			if milestone.all then
				hasAll = true
			end
		end
		assert(hasAll)
		assert(Collection.nextMilestone(3, 3) == nil)
	end)
end
