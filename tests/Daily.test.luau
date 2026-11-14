local Daily = require("../src/ReplicatedStorage/Shared/Daily")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")
local Profile = require("../src/ReplicatedStorage/Shared/Profile")
local Chests = require("../src/ReplicatedStorage/Config/Chests")

local DAYS = #GameConfig.Daily.Days
local TODAY = 20000

return function(test)
	test("Daily: a new player can claim day 1", function()
		local state = Daily.new()
		assert(Daily.canClaim(state, TODAY))
		assert(Daily.nextIndex(state, TODAY) == 1)
		local claimed, index = Daily.claim(state, TODAY)
		assert(claimed ~= nil and index == 1)
		assert(claimed.day == TODAY and claimed.streak == 1)
	end)

	test("Daily: one claim a day", function()
		local claimed = Daily.claim(Daily.new(), TODAY)
		assert(claimed ~= nil)
		assert(not Daily.canClaim(claimed, TODAY))
		local again = Daily.claim(claimed, TODAY)
		assert(again == nil)
	end)

	test("Daily: the next day continues the streak", function()
		local state = { day = TODAY - 1, streak = 3 }
		assert(Daily.canClaim(state, TODAY))
		assert(Daily.nextIndex(state, TODAY) == 4)
		local claimed, index = Daily.claim(state, TODAY)
		assert(claimed ~= nil and index == 4 and claimed.streak == 4)
	end)

	test("Daily: a missed day starts again at day 1", function()
		local state = { day = TODAY - 2, streak = 5 }
		assert(Daily.nextIndex(state, TODAY) == 1)
		local claimed, index = Daily.claim(state, TODAY)
		assert(claimed ~= nil and index == 1 and claimed.streak == 1)
	end)

	test("Daily: after the last day the cycle starts over", function()
		local state = { day = TODAY - 1, streak = DAYS }
		local claimed, index = Daily.claim(state, TODAY)
		assert(claimed ~= nil and index == 1)
	end)

	test("Daily: a clock that went backwards claims nothing", function()
		local state = { day = TODAY + 1, streak = 2 }
		assert(not Daily.canClaim(state, TODAY))
		assert(Daily.claim(state, TODAY) == nil)
	end)

	test("Daily: shown is the day already claimed today, or the one waiting", function()
		assert(Daily.shownIndex({ day = TODAY, streak = 4 }, TODAY) == 4)
		assert(Daily.shownIndex({ day = TODAY - 1, streak = 4 }, TODAY) == 5)
		assert(Daily.shownIndex({ day = TODAY - 3, streak = 4 }, TODAY) == 1)
	end)

	test("Daily: every day pays Shells and any chest it names exists", function()
		assert(DAYS == 7)
		for index, day in GameConfig.Daily.Days do
			assert(day.shells > 0, "day " .. index .. " pays nothing")
			if day.chest ~= nil then
				assert(Chests.ById[day.chest] ~= nil, "day " .. index .. " names an unknown chest")
			end
		end
	end)

	test("Daily: the claim is saved, and the later day wins a merge", function()
		local stored = Profile.new()
		local session = Profile.newSession()
		session.daily = { day = TODAY, streak = 2 }
		local merged = Profile.merge(stored, session)
		assert(merged.daily.day == TODAY and merged.daily.streak == 2)
		-- An untouched session leaves the saved claim alone.
		local kept = Profile.merge(merged, Profile.newSession())
		assert(kept.daily.day == TODAY and kept.daily.streak == 2)
		-- A session from an older day never rolls it back.
		local older = Profile.newSession()
		older.daily = { day = TODAY - 1, streak = 1 }
		local still = Profile.merge(merged, older)
		assert(still.daily.day == TODAY and still.daily.streak == 2)
		-- It survives the round trip through the store.
		local loaded = Profile.fromStored(merged)
		assert(loaded.daily.day == TODAY and loaded.daily.streak == 2)
		-- Two sessions combined keep the later claim.
		local first = Profile.newSession()
		first.daily = { day = TODAY, streak = 2 }
		local combined = Profile.combine(first, Profile.newSession())
		assert(combined.daily.day == TODAY and combined.daily.streak == 2)
	end)
end
