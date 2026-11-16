local AnswerMisses = require("../src/ReplicatedStorage/Shared/AnswerMisses")

return function(test)
	test("a refused answer is kept under its normalized text", function()
		assert(AnswerMisses.key("  Spork! ") == "spork")
		assert(AnswerMisses.key("Crème Brûlée") == "creme brulee")
		assert(AnswerMisses.key("boeing 747") == "boeing 747")
		assert(AnswerMisses.key("7up") == "7up")
	end)

	test("text that is not an answer is not kept", function()
		assert(AnswerMisses.key("") == nil)
		assert(AnswerMisses.key("a") == nil)
		assert(AnswerMisses.key("!!!") == nil)
		assert(AnswerMisses.key("123") == nil, "no letters")
		assert(AnswerMisses.key("call me on 5551234567") == nil, "a run of digits")
		assert(AnswerMisses.key("call 555 123 4567") == nil, "digits spread out")
		assert(AnswerMisses.key("bob@gmail.com") == nil, "an email")
		assert(AnswerMisses.key("discord.gg/abcd") == nil and AnswerMisses.key("www.site.net") == nil, "a link")
		assert(AnswerMisses.key("Dr. Pepper") == "dr pepper" and AnswerMisses.key("st.louis") == "stlouis", "a dot is not a link")
		assert(AnswerMisses.key("coca.cola") == "cocacola", "nor is .co inside a word")
		assert(AnswerMisses.key("aaaaaaaa") == nil, "keyboard mashing")
		assert(AnswerMisses.key("hahahahaha lol") == "hahahahaha lol", "not the same letter four times")
		assert(AnswerMisses.key("i do not know this one") == nil, "a sentence")
		assert(AnswerMisses.key("supercalifragilisticexpialidocious") == nil, "too long")
	end)

	test("record counts kept text and says when it dropped some", function()
		local counts = AnswerMisses.empty()
		assert(AnswerMisses.record(counts, "Spork") == true)
		assert(AnswerMisses.record(counts, "spork ") == true)
		assert(AnswerMisses.record(counts, "exuberant") == true)
		assert(AnswerMisses.record(counts, "zzzzzz") == false)
		assert(counts.total == 3 and counts.counts.spork == 2 and counts.counts.exuberant == 1)
	end)

	local function size(counts): number
		local n = 0
		for _ in counts.counts do
			n += 1
		end
		return n
	end

	test("merge sums and changes neither input", function()
		local stored = { total = 10, counts = { spork = 5, straw = 3, bib = 2 } }
		local delta = { total = 4, counts = { ladle = 3, bib = 1 } }
		local merged = AnswerMisses.merge(stored, delta, 10)
		assert(merged.total == 14)
		assert(merged.counts.spork == 5 and merged.counts.bib == 3 and merged.counts.ladle == 3 and merged.counts.straw == 3)
		assert(stored.counts.bib == 2 and stored.counts.ladle == nil and stored.total == 10 and delta.counts.bib == 1)
	end)

	test("over the cap every count drops by one, so one-offs go and the table has room again", function()
		local stored = { total = 20, counts = { spork = 9, straw = 4, bib = 1, cup = 1 } }
		local merged = AnswerMisses.merge(stored, { total = 1, counts = { yuzu = 1 } }, 4)
		assert(merged.total == 21, "the total counts every miss, kept or not")
		assert(merged.counts.spork == 8 and merged.counts.straw == 3, "the common ones stay, one lower")
		assert(merged.counts.bib == nil and merged.counts.cup == nil and merged.counts.yuzu == nil)
		-- The next newcomer fits, whatever letter it starts with, and one that keeps coming climbs.
		local nextOne = AnswerMisses.merge(merged, { total = 1, counts = { zucchini = 1 } }, 4)
		assert(nextOne.counts.zucchini == 1 and size(nextOne) == 3)
		local again = AnswerMisses.merge(nextOne, { total = 2, counts = { zucchini = 2 } }, 4)
		assert(again.counts.zucchini == 3)
	end)

	test("merge never ends over the cap, even when every answer was refused often", function()
		local counts = {}
		for index = 1, 50 do
			counts["answer" .. string.char(96 + (index - 1) % 26 + 1) .. string.char(96 + (index - 1) // 26 + 1)] = 2 + index % 3
		end
		local merged = AnswerMisses.merge({ total = 500, counts = counts }, nil, 10)
		assert(size(merged) <= 10 and merged.total == 500, tostring(size(merged)))
		assert(size(AnswerMisses.merge({ total = 3, counts = { a1 = 1, b1 = 1, c1 = 1 } }, nil, 2)) == 0)
	end)

	test("without removes one answer however it is typed", function()
		local stored = { total = 9, counts = { ["rude word"] = 4, spork = 5 } }
		local cleaned = AnswerMisses.without(stored, " Rude  Word! ")
		assert(cleaned.counts["rude word"] == nil and cleaned.counts.spork == 5)
		assert(cleaned.total == 9 and stored.counts["rude word"] == 4)
		assert(AnswerMisses.without(nil, "x").total == 0)
	end)

	test("merge treats a missing or broken stored value as empty", function()
		local delta = { total = 1, counts = { spork = 1 } }
		assert(AnswerMisses.merge(nil, delta, 5).counts.spork == 1)
		assert(AnswerMisses.merge("oops", delta, 5).total == 1)
		assert(AnswerMisses.merge({ total = 2, counts = { a = "x" } }, nil, 5).total == 2)
	end)

	test("top lists the most refused that pass the filter", function()
		local counts = { total = 20, counts = { spork = 9, exuberant = 6, fork = 4, zz = 1 } }
		local rows = AnswerMisses.top(counts, 5, 2, function(answer)
			return answer ~= "fork" -- the bank has it now
		end)
		assert(#rows == 2 and rows[1].answer == "spork" and rows[2].answer == "exuberant")
		assert(#AnswerMisses.top(counts, 1, 1) == 1)
		assert(#AnswerMisses.top(counts, 10, 1) == 4)
		assert(AnswerMisses.describe(20, rows) == "20 refused: spork 9, exuberant 6")
		assert(AnswerMisses.describe(0, {}) == "0 refused")
	end)
end
