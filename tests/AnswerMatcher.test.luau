local AnswerMatcher = require("../src/ReplicatedStorage/Shared/AnswerMatcher")

local prompt = {
	id = "test_country_a",
	prompt = "Name a country whose name starts with A",
	answers = {
		Plankton = { "argentina", "australia" },
		Rare = { "andorra" },
		Mythic = { "antigua and barbuda" },
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
		assert(AnswerMatcher.match("antigua", prompt) == "Mythic")
	end)

	test("one character typo is accepted for answers of 5+ characters", function()
		assert(AnswerMatcher.match("andora", prompt) == "Rare")
		assert(AnswerMatcher.match("argxyzina", prompt) == nil, "three edits is too far")
	end)

	test("autocorrect returns the bank spelling for a typo", function()
		local tier, corrected = AnswerMatcher.resolve("Andora", prompt)
		assert(tier == "Rare")
		assert(corrected == "andorra", tostring(corrected))
	end)

	test("swapped neighbouring letters count as one typo", function()
		local tier, corrected = AnswerMatcher.resolve("argentian", prompt)
		assert(tier == "Plankton")
		assert(corrected == "argentina")
	end)

	test("long answers forgive two typos", function()
		local tier, corrected = AnswerMatcher.resolve("antiqua and barbada", prompt)
		assert(tier == "Mythic")
		assert(corrected == "antigua and barbuda")
	end)

	test("typo allowance grows with length: none under 5 letters, 1 from 5, 2 from 10, never 3", function()
		local animals = { id = "a", prompt = "x", answers = { Plankton = { "duck", "penguin", "velociraptor" } }, aliases = {} }
		assert(AnswerMatcher.match("dukc", animals) == nil, "4 letters must be exact")
		assert(AnswerMatcher.match("pengiun", animals) == "Plankton", "7 letters, one swap")
		assert(AnswerMatcher.match("pengwen", animals) == nil, "7 letters, two typos is too far")
		assert(AnswerMatcher.match("volosiraptor", animals) == "Plankton", "12 letters, two typos")
		assert(AnswerMatcher.match("volosirapter", animals) == nil, "12 letters, three typos is too far")
	end)

	test("a typo never changes the first letter", function()
		assert(AnswerMatcher.match("bndorra", prompt) == nil)
		assert(AnswerMatcher.match("andorrq", prompt) == "Rare")
	end)

	test("autocorrect picks the closest bank answer, not the first one in tier order", function()
		local berries = { id = "b", prompt = "x", answers = { Plankton = { "blackberries" }, Rare = { "blackberried" } }, aliases = {} }
		local tier, corrected = AnswerMatcher.resolve("blackberrid", berries)
		assert(tier == "Rare", tostring(tier))
		assert(corrected == "blackberried")
	end)

	test("an alias autocorrects to its canonical answer", function()
		local tier, corrected = AnswerMatcher.resolve("antigua", prompt)
		assert(tier == "Mythic")
		assert(corrected == "antigua and barbuda")
	end)

	test("short answers must match exactly", function()
		local short = { id = "s", prompt = "x", answers = { Plankton = { "red" } }, aliases = {} }
		assert(AnswerMatcher.match("red", short) == "Plankton")
		assert(AnswerMatcher.match("rad", short) == nil)
	end)

	local food = {
		id = "test_food",
		prompt = "Name a food",
		answers = {
			Plankton = { "ice cream", "hot dog", "cherry", "mac and cheese" },
			Schooler = { "box", "gas", "eiffel tower", "the moon" },
			Rare = { "jalapeno", "pane", "pan", "hotdog bun" },
			DeepCut = { "creme brulee" },
		},
		aliases = {
			["macaroni and cheese"] = "mac and cheese",
		},
	}

	test("normalize spells out + and # so C++ and C# keep their names", function()
		assert(AnswerMatcher.normalize("C++") == "c plus plus")
		assert(AnswerMatcher.normalize("c#") == "c sharp")
		assert(AnswerMatcher.normalize("C Sharp") == "c sharp")
	end)

	test("normalize folds accents and turns & into and before stripping punctuation", function()
		assert(AnswerMatcher.normalize("Jalapeño") == "jalapeno")
		assert(AnswerMatcher.normalize("CRÈME BRÛLÉE") == "creme brulee")
		assert(AnswerMatcher.normalize("mac&cheese") == "mac and cheese")
		assert(AnswerMatcher.normalize("shepherd’s pie") == "shepherds pie")
		assert(AnswerMatcher.normalize("pizza 🍕") == "pizza")
		assert(AnswerMatcher.normalize("bad\255byte") == "bad byte", "invalid UTF-8 still normalizes")
	end)

	test("accented answers match the plain bank spelling", function()
		local tier, corrected = AnswerMatcher.resolve("Jalapeño", food)
		assert(tier == "Rare")
		assert(corrected == "jalapeno")
		assert(AnswerMatcher.match("crème brûlée", food) == "DeepCut")
	end)

	test("& matches an alias spelled with and", function()
		local tier, corrected = AnswerMatcher.resolve("macaroni & cheese", food)
		assert(tier == "Plankton")
		assert(corrected == "mac and cheese")
		assert(AnswerMatcher.match("mac & cheese", food) == "Plankton")
	end)

	test("a leading article is ignored on either side", function()
		local tier, corrected = AnswerMatcher.resolve("the eiffel tower", food)
		assert(tier == "Schooler")
		assert(corrected == "eiffel tower")
		local _, moon = AnswerMatcher.resolve("moon", food)
		assert(moon == "the moon", tostring(moon))
		assert(AnswerMatcher.match("an eiffel tower", food) == "Schooler")
	end)

	test("plurals fall back to the singular bank answer", function()
		local tier, corrected = AnswerMatcher.resolve("cherries", food)
		assert(tier == "Plankton")
		assert(corrected == "cherry")
		local _, box = AnswerMatcher.resolve("boxes", food)
		assert(box == "box", tostring(box))
		local _, pane = AnswerMatcher.resolve("panes", food)
		assert(pane == "pane", "s is tried before es: " .. tostring(pane))
		assert(AnswerMatcher.match("the hot dogs", food) == "Plankton")
	end)

	test("a singular answer matches a plural bank answer", function()
		local berries = { id = "b", prompt = "x", answers = { Rare = { "cherries" } }, aliases = {} }
		local tier, corrected = AnswerMatcher.resolve("cherry", berries)
		assert(tier == "Rare")
		assert(corrected == "cherries")
	end)

	test("plural stripping keeps a stem of at least 3 letters", function()
		assert(AnswerMatcher.variants("gas")[2] == nil)
		assert(AnswerMatcher.variants("glass")[2] == nil, "ss is not a plural")
		local short = { id = "s", prompt = "x", answers = { Plankton = { "ga" } }, aliases = {} }
		assert(AnswerMatcher.match("gas", short) == nil)
		local _, gas = AnswerMatcher.resolve("gas", food)
		assert(gas == "gas")
	end)

	test("spaces do not matter when nothing closer matches", function()
		local tier, corrected = AnswerMatcher.resolve("icecream", food)
		assert(tier == "Plankton")
		assert(corrected == "ice cream")
		local _, dog = AnswerMatcher.resolve("hotdog", food)
		assert(dog == "hot dog", tostring(dog))
		local _, bun = AnswerMatcher.resolve("hot dog bun", food)
		assert(bun == "hotdog bun", tostring(bun))
		assert(AnswerMatcher.match("ice creams", food) == "Plankton")
	end)

	test("fallback ties resolve to the lowest tier", function()
		local tied = { id = "t", prompt = "x", answers = { Plankton = { "the cat" }, Rare = { "a cat" } }, aliases = {} }
		local tier, corrected = AnswerMatcher.resolve("cat", tied)
		assert(tier == "Plankton")
		assert(corrected == "the cat")
	end)

	test("empty, too long and unknown answers are rejected", function()
		assert(AnswerMatcher.match("", prompt) == nil)
		assert(AnswerMatcher.match("   ", prompt) == nil)
		assert(AnswerMatcher.match(string.rep("a", 41), prompt) == nil)
		assert(AnswerMatcher.match("france", prompt) == nil)
	end)

	local drinks = {
		id = "test_drinks",
		prompt = "Name a soft drink",
		answers = {
			Plankton = { "pepsi", "dr pepper" },
			Schooler = { "diet dr pepper", "pepsi zero", "mt dew" },
			Rare = { "dr pepper cherry", "a and w" },
		},
		aliases = {},
	}

	test("whole words with a short spelling match either way", function()
		local tier, spelling = AnswerMatcher.resolve("Diet Doctor Pepper", drinks)
		assert(tier == "Schooler" and spelling == "diet dr pepper", tostring(spelling))
		assert(AnswerMatcher.match("mount dew", drinks) == "Schooler")
	end)

	test("word order does not matter for answers of two or more words", function()
		local tier, spelling = AnswerMatcher.resolve("cherry dr pepper", drinks)
		assert(tier == "Rare" and spelling == "dr pepper cherry", tostring(spelling))
	end)

	test("qualifier words at the ends are dropped when the answer is refused as typed", function()
		local tier, spelling = AnswerMatcher.resolve("pepsi zero sugar", drinks)
		assert(tier == "Schooler" and spelling == "pepsi zero", tostring(spelling))
		tier, spelling = AnswerMatcher.resolve("vanilla pepsi", drinks)
		assert(tier == "Plankton" and spelling == "pepsi", tostring(spelling))
		tier, spelling = AnswerMatcher.resolve("diet doctor pepper zero sugar", drinks)
		assert(tier == "Schooler" and spelling == "diet dr pepper", tostring(spelling))
	end)

	test("an answer that is listed as typed keeps its own tier over a shorter one", function()
		assert(AnswerMatcher.match("diet dr pepper", drinks) == "Schooler")
		assert(AnswerMatcher.match("a & w", drinks) == "Rare")
	end)

	test("qualifiers alone, negations and words in the middle are not dropped", function()
		assert(AnswerMatcher.match("diet zero", drinks) == nil)
		assert(AnswerMatcher.match("not pepsi", drinks) == nil)
		assert(AnswerMatcher.match("no sugar pepsi", drinks) == nil)
		assert(AnswerMatcher.match("pepsi with sprite", drinks) == nil)
		assert(AnswerMatcher.match("diet doctor pespi", drinks) == nil, "pepsi and dr pepper are different drinks")
	end)

	test("a qualifier word that is an answer itself is not dropped", function()
		local fruit = {
			id = "test_fruit",
			prompt = "Name a fruit",
			answers = { Plankton = { "lemon", "lime", "apple" } },
			aliases = {},
		}
		assert(AnswerMatcher.match("lemon lime", fruit) == nil)
		assert(AnswerMatcher.match("fresh apple", fruit) == "Plankton")
	end)
end
