local AnswerStats = require("../src/ReplicatedStorage/Shared/AnswerStats")

return function(test)
	test("oneIn stays nil until enough answers are recorded", function()
		assert(AnswerStats.oneIn(39, 1, 40) == nil)
		assert(AnswerStats.oneIn(0, 0, 0) == nil)
		assert(AnswerStats.oneIn(40, 1, 40) ~= nil)
	end)

	test("oneIn counts the shown player as one more giver", function()
		assert(AnswerStats.oneIn(400, 1, 40) == 200, tostring(AnswerStats.oneIn(400, 1, 40)))
		assert(AnswerStats.oneIn(400, 0, 40) == 401, tostring(AnswerStats.oneIn(400, 0, 40)))
		assert(AnswerStats.oneIn(1000, 9, 40) == 100, tostring(AnswerStats.oneIn(1000, 9, 40)))
	end)

	test("oneIn never says 1 in 1 and ignores impossible counts", function()
		assert(AnswerStats.oneIn(400, 400, 40) == 2)
		assert(AnswerStats.oneIn(400, 900, 40) == 2)
		assert(AnswerStats.oneIn(400, -5, 40) == 401)
	end)

	test("mergeCounts sums totals and per-answer counts without changing its inputs", function()
		local stored = { total = 10, counts = { beatles = 6, queen = 4 } }
		local delta = { total = 3, counts = { beatles = 1, abba = 2 } }
		local merged = AnswerStats.mergeCounts(stored, delta)
		assert(merged.total == 13)
		assert(merged.counts.beatles == 7 and merged.counts.queen == 4 and merged.counts.abba == 2)
		assert(stored.total == 10 and stored.counts.beatles == 6 and stored.counts.abba == nil)
		assert(delta.total == 3 and delta.counts.beatles == 1)
	end)

	test("mergeCounts treats missing or broken stored values as empty", function()
		local delta = { total = 2, counts = { beatles = 2 } }
		local fromNil = AnswerStats.mergeCounts(nil, delta)
		assert(fromNil.total == 2 and fromNil.counts.beatles == 2)
		local fromJunk = AnswerStats.mergeCounts("oops", delta)
		assert(fromJunk.total == 2)
		local messy = AnswerStats.mergeCounts({ total = 0 / 0, counts = { a = -3, b = "x", c = 2.7, [""] = 4 } }, nil)
		assert(messy.counts.a == nil and messy.counts.b == nil and messy.counts[""] == nil)
		assert(messy.counts.c == 2 and messy.total == 2, tostring(messy.total))
	end)

	test("record groups answers by their normalized spelling", function()
		local buffer = AnswerStats.empty()
		AnswerStats.record(buffer, "The Beatles!")
		AnswerStats.record(buffer, "the  beatles")
		AnswerStats.record(buffer, "Queen")
		AnswerStats.record(buffer, "  ")
		assert(buffer.total == 3, tostring(buffer.total))
		assert(AnswerStats.countFor(buffer, "THE BEATLES") == 2)
		assert(AnswerStats.countFor(buffer, "queen") == 1)
		assert(AnswerStats.countFor(buffer, "abba") == 0)
	end)

	test("oneInFor reads an answer's count from a Counts table", function()
		local counts = { total = 400, counts = { ["the beatles"] = 1 } }
		assert(AnswerStats.oneInFor(counts, "The Beatles", 40) == 200)
		assert(AnswerStats.oneInFor(counts, "Abba", 40) == 401)
		assert(AnswerStats.oneInFor(AnswerStats.empty(), "Abba", 40) == nil)
	end)

	test("describe lists the most common answers first", function()
		local counts = { total = 12, counts = { queen = 3, beatles = 7, abba = 2 } }
		local text = AnswerStats.describe(counts, 2)
		assert(text == "12 answers: beatles 7, queen 3 (+1 more)", text)
		assert(AnswerStats.describe(AnswerStats.empty(), 5) == "0 answers")
	end)
end
