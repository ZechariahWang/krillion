local Quests = require("../src/ReplicatedStorage/Shared/Quests")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local function ids(list): string
	local out = {}
	for _, quest in list do
		table.insert(out, quest.id)
	end
	return table.concat(out, ",")
end

return function(test)
	test("day() changes exactly at UTC midnight", function()
		assert(Quests.day(0) == 0)
		assert(Quests.day(86399) == 0)
		assert(Quests.day(86400) == 1)
		assert(Quests.day(86400 * 20000 + 5) == 20000)
	end)

	test("secondsLeft counts down to the next UTC day", function()
		assert(Quests.secondsLeft(0) == 86400)
		assert(Quests.secondsLeft(86399) == 1)
		assert(Quests.secondsLeft(86400 + 3600) == 82800)
	end)

	test("draw is the same for the same player and day", function()
		local a = ids(Quests.draw(12345, 20400))
		local b = ids(Quests.draw(12345, 20400))
		assert(a == b, a .. " vs " .. b)
	end)

	test("draw gives PerDay distinct quests of distinct kinds", function()
		for userId = -3, 40 do
			local list = Quests.draw(userId * 7919, 20400)
			assert(#list == GameConfig.Quests.PerDay, "got " .. #list)
			local seenIds, seenKinds = {}, {}
			for _, quest in list do
				assert(not seenIds[quest.id], "repeated id " .. quest.id)
				assert(not seenKinds[quest.kind], "repeated kind " .. quest.kind)
				seenIds[quest.id] = true
				seenKinds[quest.kind] = true
			end
		end
	end)

	test("draw changes from one day to the next", function()
		local changed = 0
		for userId = 1, 20 do
			for day = 20400, 20409 do
				if ids(Quests.draw(userId, day)) ~= ids(Quests.draw(userId, day + 1)) then
					changed += 1
				end
			end
		end
		-- 200 day pairs: nearly all should differ, not just a lucky few.
		assert(changed >= 180, "only " .. changed .. " of 200 next-day draws differed")
	end)

	test("draw never offers the warm-up quest while the lobby quiz is off", function()
		if GameConfig.Lobby.QuizEnabled == 1 then
			return
		end
		for userId = 1, 200 do
			for _, quest in Quests.draw(userId, 20400) do
				assert(quest.kind ~= "practice_answer", "warm-up quest drawn for " .. userId)
			end
		end
	end)

	test("draw reaches every drawable quest across players", function()
		local seen = {}
		for userId = 1, 200 do
			for _, quest in Quests.draw(userId, 20400) do
				seen[quest.id] = true
			end
		end
		for _, quest in Quests.Drawable do
			assert(seen[quest.id], quest.id .. " never drawn")
		end
	end)

	test("draw handles big and negative user ids", function()
		assert(#Quests.draw(9876543210, 20400) == GameConfig.Quests.PerDay)
		assert(#Quests.draw(-1, 20400) == GameConfig.Quests.PerDay)
		assert(ids(Quests.draw(9876543210, 20400)) == ids(Quests.draw(9876543210, 20400)))
	end)

	test("draw can ask for fewer, and never more than the pool", function()
		assert(#Quests.draw(5, 20400, 1) == 1)
		assert(#Quests.draw(5, 20400, 99) == #Quests.Drawable)
	end)

	test("advance adds, clamps at the goal and reports justDone once", function()
		local quest = Quests.ById.survive_5
		local progress, done = Quests.advance(0, quest, 2)
		assert(progress == 2 and done == false)
		progress, done = Quests.advance(progress, quest, 10)
		assert(progress == 5 and done == true, tostring(progress))
		progress, done = Quests.advance(progress, quest, 1)
		assert(progress == 5 and done == false)
	end)

	test("advance ignores zero, negative and NaN amounts", function()
		local quest = Quests.ById.rare_2
		assert(select(1, Quests.advance(1, quest, 0)) == 1)
		assert(select(1, Quests.advance(1, quest, -3)) == 1)
		local progress, done = Quests.advance(1, quest, 0 / 0)
		assert(progress == 1 and done == false)
	end)

	test("Rare counts as rare, Deep Cut and up count as rare and deep", function()
		assert(#Quests.kindsForTier(0) == 0)
		assert(#Quests.kindsForTier(3) == 0)
		local rare = Quests.kindsForTier(4)
		assert(#rare == 1 and rare[1] == "rare_answer")
		local deep = Quests.kindsForTier(5)
		assert(#deep == 2 and table.find(deep, "rare_answer") and table.find(deep, "deep_answer"))
		assert(#Quests.kindsForTier(6) == 2)
	end)

	test("progress and reset texts", function()
		assert(Quests.progressText(Quests.ById.play_3, 2) == "2/3")
		assert(Quests.progressText(Quests.ById.play_3, 9) == "3/3")
		assert(Quests.progressText(Quests.ById.minutes_10, 270) == "4/10 MIN")
		assert(Quests.resetText(5 * 3600 + 12 * 60) == "5H 12M")
		assert(Quests.resetText(5 * 3600 + 11 * 60 + 1) == "5H 12M")
		assert(Quests.resetText(30) == "1M")
		assert(Quests.resetText(59 * 60) == "59M")
	end)
end
