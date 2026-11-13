local CrabMatch = require("../src/ReplicatedStorage/Shared/CrabMatch")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local RULES = GameConfig.Crab

-- Three players in ring order, the first one holding, with a fuse in the middle of its range.
local function threePlayers()
	return CrabMatch.new({ "a", "b", "c" }, 0, 0.5)
end

return function(test)
	test("a fuse roll spans the configured range", function()
		assert(CrabMatch.rollFuse(0) == RULES.FuseMinSeconds)
		assert(CrabMatch.rollFuse(1) == RULES.FuseMaxSeconds)
		local middle = CrabMatch.rollFuse(0.5)
		assert(middle == (RULES.FuseMinSeconds + RULES.FuseMaxSeconds) / 2)
	end)

	test("a new match gives everyone the starting hearts and an empty meter", function()
		local match = threePlayers()
		for _, id in { "a", "b", "c" } do
			assert(match.hearts[id] == RULES.StartHearts)
			assert(match.meter[id] == 0)
			assert(match.alive[id] == true)
		end
		assert(CrabMatch.aliveCount(match) == 3)
		assert(match.fuse == CrabMatch.rollFuse(0.5))
	end)

	test("the holder roll picks who starts with the crab", function()
		assert(CrabMatch.new({ "a", "b", "c" }, 0, 0).holder == "a")
		assert(CrabMatch.new({ "a", "b", "c" }, 0.5, 0).holder == "b")
		assert(CrabMatch.new({ "a", "b", "c" }, 0.999, 0).holder == "c")
	end)

	test("a pass sends the crab clockwise and wraps round the ring", function()
		local match = threePlayers()
		assert(CrabMatch.pass(match, "apple", 10).to == "b")
		assert(match.holder == "b")
		assert(CrabMatch.pass(match, "pear", 10).to == "c")
		assert(CrabMatch.pass(match, "plum", 10).to == "a")
	end)

	test("a passed answer cannot be used again for the same question", function()
		local match = threePlayers()
		assert(not CrabMatch.isUsed(match, "apple"))
		CrabMatch.pass(match, "apple", 10)
		assert(CrabMatch.isUsed(match, "apple"))
		assert(not CrabMatch.isUsed(match, "pear"))
		assert(#match.usedList == 1 and match.usedList[1] == "apple")
	end)

	test("a pass with little fuse left tops it up to the minimum turn", function()
		local match = threePlayers()
		match.fuse = 2
		CrabMatch.pass(match, "apple", 10)
		assert(match.fuse == RULES.MinTurnSeconds)
	end)

	test("a pass with plenty of fuse left leaves it alone", function()
		local match = threePlayers()
		match.fuse = RULES.MinTurnSeconds + 5
		CrabMatch.pass(match, "apple", 10)
		assert(match.fuse == RULES.MinTurnSeconds + 5)
	end)

	test("answer points fill the passer's meter", function()
		local match = threePlayers()
		CrabMatch.pass(match, "apple", 60)
		assert(match.meter.a == 60)
		assert(match.meter.b == 0)
	end)

	test("a full meter becomes an extra heart and keeps what is left over", function()
		local match = threePlayers()
		match.meter.a = RULES.MeterTarget - 10
		local result = CrabMatch.pass(match, "apple", 60)
		assert(result.gainedHeart == true)
		assert(match.hearts.a == RULES.StartHearts + 1)
		assert(match.meter.a == 50)
	end)

	test("hearts never go past the maximum; the meter waits full instead", function()
		local match = threePlayers()
		match.hearts.a = RULES.MaxHearts
		match.meter.a = RULES.MeterTarget - 10
		local result = CrabMatch.pass(match, "apple", 60)
		assert(result.gainedHeart == false)
		assert(match.hearts.a == RULES.MaxHearts)
		assert(match.meter.a == RULES.MeterTarget)
	end)

	test("the fuse runs out only once its time has passed", function()
		local match = threePlayers()
		match.fuse = 5
		assert(CrabMatch.tick(match, 4) == false)
		assert(CrabMatch.tick(match, 1) == true)
	end)

	test("a pinch costs the holder a heart and they hold the crab again", function()
		local match = threePlayers()
		local result = CrabMatch.pinch(match, 0)
		assert(result.id == "a")
		assert(result.hearts == RULES.StartHearts - 1)
		assert(result.eliminated == false)
		assert(match.holder == "a")
	end)

	test("a pinch starts a new fuse and clears the used answers", function()
		local match = threePlayers()
		CrabMatch.pass(match, "apple", 10)
		match.fuse = 0
		CrabMatch.pinch(match, 1)
		assert(match.fuse == RULES.FuseMaxSeconds)
		assert(not CrabMatch.isUsed(match, "apple"))
		assert(#match.usedList == 0)
		assert(match.pinches == 1)
	end)

	test("a pinch on the last heart puts the holder out and the next player holds", function()
		local match = threePlayers()
		match.hearts.a = 1
		local result = CrabMatch.pinch(match, 0)
		assert(result.eliminated == true)
		assert(match.alive.a == false)
		assert(match.holder == "b")
		assert(CrabMatch.aliveCount(match) == 2)
	end)

	test("the crab skips players who are out", function()
		local match = threePlayers()
		match.hearts.b = 1
		match.holder = "b"
		CrabMatch.pinch(match, 0)
		assert(match.holder == "c")
		CrabMatch.pass(match, "apple", 10)
		assert(match.holder == "a")
		assert(CrabMatch.pass(match, "pear", 10).to == "c")
	end)

	test("the crab's mood follows the fuse", function()
		local match = threePlayers()
		match.fuse = RULES.RestlessSeconds + 1
		assert(CrabMatch.mood(match) == "Calm")
		match.fuse = RULES.RestlessSeconds
		assert(CrabMatch.mood(match) == "Restless")
		match.fuse = RULES.FuriousSeconds
		assert(CrabMatch.mood(match) == "Furious")
	end)

	test("the match is over when one player is left, and they win", function()
		local match = threePlayers()
		assert(not CrabMatch.over(match))
		assert(CrabMatch.winner(match) == nil)
		match.hearts.a = 1
		CrabMatch.pinch(match, 0)
		assert(not CrabMatch.over(match))
		match.hearts.b = 1
		CrabMatch.pinch(match, 0)
		assert(CrabMatch.over(match))
		assert(CrabMatch.winner(match) == "c")
	end)

	test("ranking puts the winner first, then the last out, then the first out", function()
		local match = threePlayers()
		match.hearts.a = 1
		CrabMatch.pinch(match, 0)
		match.hearts.b = 1
		CrabMatch.pinch(match, 0)
		local ranking = CrabMatch.ranking(match)
		assert(ranking[1] == "c" and ranking[2] == "b" and ranking[3] == "a")
	end)

	test("a player alone plays until they are out, with no winner", function()
		local match = CrabMatch.new({ "a" }, 0, 0)
		assert(not CrabMatch.over(match))
		CrabMatch.pass(match, "apple", 10)
		assert(match.holder == "a")
		match.hearts.a = 1
		CrabMatch.pinch(match, 0)
		assert(CrabMatch.over(match))
		assert(CrabMatch.winner(match) == nil)
	end)

	test("a revive puts a player back with the revive hearts", function()
		local match = threePlayers()
		match.hearts.a = 1
		CrabMatch.pinch(match, 0)
		assert(CrabMatch.revive(match, "a") == true)
		assert(match.alive.a == true)
		assert(match.hearts.a == RULES.ReviveHearts)
		assert(CrabMatch.aliveCount(match) == 3)
		assert(#CrabMatch.ranking(match) == 3)
	end)

	test("a revive does nothing for someone still in", function()
		local match = threePlayers()
		assert(CrabMatch.revive(match, "a") == false)
		assert(match.hearts.a == RULES.StartHearts)
	end)

	test("a holder who falls in is out and the crab moves on", function()
		local match = threePlayers()
		CrabMatch.eliminate(match, "a")
		assert(match.alive.a == false)
		assert(match.hearts.a == 0)
		assert(match.holder == "b")
		assert(CrabMatch.ranking(match)[3] == "a")
	end)

	test("someone else falling in leaves the crab where it is", function()
		local match = threePlayers()
		CrabMatch.eliminate(match, "c")
		assert(match.holder == "a")
		assert(CrabMatch.pass(match, "apple", 10).to == "b")
		assert(CrabMatch.pass(match, "pear", 10).to == "a")
	end)

	test("eliminating someone already out changes nothing", function()
		local match = threePlayers()
		CrabMatch.eliminate(match, "c")
		CrabMatch.eliminate(match, "c")
		assert(#match.out == 1)
	end)

	test("a player who leaves is gone from the ring and the ranking", function()
		local match = threePlayers()
		CrabMatch.remove(match, "a")
		assert(match.holder == "b")
		assert(CrabMatch.aliveCount(match) == 2)
		assert(#CrabMatch.ranking(match) == 2)
		assert(CrabMatch.pass(match, "apple", 10).to == "c")
		assert(CrabMatch.pass(match, "pear", 10).to == "b")
	end)

	test("when one of two leaves, the other wins", function()
		local match = CrabMatch.new({ "a", "b" }, 0, 0)
		CrabMatch.remove(match, "a")
		assert(CrabMatch.over(match))
		assert(CrabMatch.winner(match) == "b")
	end)

	test("extra time is added to the fuse", function()
		local match = threePlayers()
		match.fuse = 4
		CrabMatch.addTime(match, 10)
		assert(match.fuse == 14)
	end)
end
