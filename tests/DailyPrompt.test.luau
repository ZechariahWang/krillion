local DailyPrompt = require("../src/ReplicatedStorage/Shared/DailyPrompt")
local AnswerStats = require("../src/ReplicatedStorage/Shared/AnswerStats")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local IDS = { "author", "bird", "cheese", "dog_breed", "elf", "fruit", "gem" }

local function countsOf(list: { string }, extraTotal: number?)
	local counts = AnswerStats.empty()
	for _, answer in list do
		AnswerStats.record(counts, answer)
	end
	counts.total += extraTotal or 0
	return counts
end

return function(test)
	test("everyone gets the same prompt for a day, and the order of the id list does not matter", function()
		local a = DailyPrompt.pick(20410, IDS)
		local shuffled = { "gem", "author", "fruit", "bird", "elf", "cheese", "dog_breed" }
		assert(a == DailyPrompt.pick(20410, shuffled))
		assert(table.find(IDS, a) ~= nil)
	end)

	test("a day never repeats the day before's prompt", function()
		for day = 20000, 20200 do
			assert(DailyPrompt.pick(day, IDS) ~= DailyPrompt.pick(day - 1, IDS), "day " .. day)
		end
	end)

	test("the prompt changes from day to day across the bank", function()
		local seen = {}
		for day = 20000, 20060 do
			seen[DailyPrompt.pick(day, IDS)] = true
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		assert(kinds >= 5, "only " .. kinds .. " prompts in 60 days")
	end)

	test("the streak grows on back-to-back days, holds on the same day, and starts over after a gap", function()
		assert(DailyPrompt.nextStreak(0, 0, 100) == 1)
		assert(DailyPrompt.nextStreak(99, 3, 100) == 4)
		assert(DailyPrompt.nextStreak(100, 4, 100) == 4)
		assert(DailyPrompt.nextStreak(97, 6, 100) == 1)
	end)

	test("every seventh day of a streak opens a chest", function()
		local every = GameConfig.DailyPrompt.ChestEvery
		assert(DailyPrompt.chestDue(every))
		assert(DailyPrompt.chestDue(every * 2))
		assert(not DailyPrompt.chestDue(every - 1))
		assert(not DailyPrompt.chestDue(0))
		assert(DailyPrompt.daysToChest(every - 1) == 1)
		assert(DailyPrompt.daysToChest(every) == every)
	end)

	test("an answer's share needs enough answers in total", function()
		local min = GameConfig.DailyPrompt.MinTotal
		local few = countsOf({ "lion", "lion", "tiger" })
		assert(DailyPrompt.share(few, "lion") == nil)
		local many = countsOf({ "lion", "lion", "tiger" }, min)
		local share = DailyPrompt.share(many, "Lion")
		assert(share ~= nil and share > 0 and share < 100)
	end)

	test("the top answers come most-given first, ties in name order, at most n", function()
		local counts = countsOf({ "tiger", "lion", "lion", "puma", "lynx", "lynx", "ocelot" })
		local top = DailyPrompt.top(counts, 3)
		assert(#top == 3)
		assert(top[1].answer == "lion" or top[1].answer == "lynx")
		assert(top[1].count == 2 and top[2].count == 2 and top[3].count == 1)
		assert(top[1].answer < top[2].answer)
	end)

	test("a tiny share reads as under one percent, never zero", function()
		assert(string.find(DailyPrompt.shareText(0.3), "1", 1, true) ~= nil)
		assert(DailyPrompt.shareText(0.3) ~= DailyPrompt.shareText(0))
		assert(string.find(DailyPrompt.shareText(31.6), "32", 1, true) ~= nil)
	end)
end
