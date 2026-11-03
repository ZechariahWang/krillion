local AnswerMatcher = require("../src/ReplicatedStorage/Shared/AnswerMatcher")

local prompt = {
	id = "test_country_a",
	prompt = "Name a country whose name starts with A",
	answers = {
		Plankton = { "argentina", "australia" },
		Rare = { "andorra" },
		OneInAKrillion = { "antigua and barbuda" },
	},
	aliases = {
		["antigua"] = "antigua and barbuda",
	},
}

return function(test)
	test("normalize lowercases, strips punctuation and collapses spaces", function()
		assert(AnswerMatcher.normalize("  Antigua,  and   Barbuda! ") == "antigua and barbuda")
	end)

	test("exact answer returns its tier", function()
		assert(AnswerMatcher.match("Argentina", prompt) == "Plankton")
		assert(AnswerMatcher.match("ANDORRA", prompt) == "Rare")
	end)

	test("alias resolves to the canonical answer tier", function()
		assert(AnswerMatcher.match("antigua", prompt) == "OneInAKrillion")
	end)

	test("one character typo is accepted for answers of 5+ characters", function()
		assert(AnswerMatcher.match("andora", prompt) == "Rare")
		assert(AnswerMatcher.match("argentian", prompt) == nil, "two edits is too far")
	end)

	test("short answers must match exactly", function()
		local short = { id = "s", prompt = "x", answers = { Plankton = { "red" } }, aliases = {} }
		assert(AnswerMatcher.match("red", short) == "Plankton")
		assert(AnswerMatcher.match("rad", short) == nil)
	end)

	test("empty, too long and unknown answers are rejected", function()
		assert(AnswerMatcher.match("", prompt) == nil)
		assert(AnswerMatcher.match("   ", prompt) == nil)
		assert(AnswerMatcher.match(string.rep("a", 41), prompt) == nil)
		assert(AnswerMatcher.match("france", prompt) == nil)
	end)
end
