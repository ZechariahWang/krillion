local Weekly = require("../src/ReplicatedStorage/Shared/Weekly")

local MONDAY = 1794787200 -- 2026-11-16 00:00:00 UTC, a Monday
local HOUR = 3600
local DAY = 86400

return function(test)
	test("a week starts on Monday 00:00 UTC", function()
		local week = Weekly.week(MONDAY)
		assert(Weekly.week(MONDAY - 1) == week - 1)
		assert(Weekly.week(MONDAY + 7 * DAY - 1) == week)
		assert(Weekly.week(MONDAY + 7 * DAY) == week + 1)
	end)

	test("the time left runs out at the next Monday", function()
		assert(Weekly.secondsLeft(MONDAY) == 7 * DAY)
		assert(Weekly.secondsLeft(MONDAY + 7 * DAY - 1) == 1)
		assert(Weekly.secondsLeft(MONDAY + 2 * DAY + 3 * HOUR) == 4 * DAY + 21 * HOUR)
	end)

	test("each week has its own store, and Studio never shares the live one", function()
		local week = Weekly.week(MONDAY)
		assert(Weekly.storeName(week, false) ~= Weekly.storeName(week + 1, false))
		assert(Weekly.storeName(week, true) ~= Weekly.storeName(week, false))
	end)

	test("the reset line shows days and hours, then hours and minutes, then minutes", function()
		local long = Weekly.resetText(2 * DAY + 5 * HOUR + 59)
		assert(string.find(long, "2D", 1, true) ~= nil and string.find(long, "5H", 1, true) ~= nil, long)
		local mid = Weekly.resetText(5 * HOUR + 12 * 60)
		assert(string.find(mid, "5H", 1, true) ~= nil and string.find(mid, "12M", 1, true) ~= nil, mid)
		local short = Weekly.resetText(30)
		assert(string.find(short, "1M", 1, true) ~= nil, short)
	end)

	test("your rank comes from the top list, and none when you are not in it", function()
		local top = { { userId = 5, wins = 9 }, { userId = 7, wins = 4 } }
		assert(Weekly.rankOf(top, 7) == 2)
		assert(Weekly.rankOf(top, 99) == nil)
	end)
end
