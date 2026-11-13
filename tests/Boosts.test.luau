local Boosts = require("../src/ReplicatedStorage/Shared/Boosts")

local LIMITS = { Enabled = 1, PerRound = 1, PerMatch = 3 }

local function usage(roundHints: number, matchHints: number)
	return {
		round = { Hint = roundHints, ExtraTime = 0 },
		match = { Hint = matchHints, ExtraTime = 0 },
	}
end

local BANK = {
	Plankton = { "apple", "banana" },
	TooClever = { "kiwi" },
	Schooler = { "mango", "cherry" },
	Rare = { "lychee", "quince" },
	DeepCut = { "mandoline" },
	Mythic = { "jabuticaba" },
}

return function(test)
	test("hint text leads with the tier and gives the whole answer", function()
		local got = Boosts.hintText("Deep Cut", "Mandoline")
		assert(got == "A DEEP CUT  |  MANDOLINE", got)
		got = Boosts.hintText("Rare", "Antigua And Barbuda")
		assert(got == "A RARE  |  ANTIGUA AND BARBUDA", got)
	end)

	test("titleCase capitalises each word", function()
		assert(Boosts.titleCase("antigua and barbuda") == "Antigua And Barbuda")
		assert(Boosts.titleCase("7up") == "7up")
	end)

	test("canUse allows the first boost and stops at the round limit", function()
		assert(Boosts.canUse(usage(0, 0), "Hint", LIMITS) == "ok")
		assert(Boosts.canUse(usage(1, 1), "Hint", LIMITS) == "limit")
		-- The other kind has its own count.
		assert(Boosts.canUse(usage(1, 1), "ExtraTime", LIMITS) == "ok")
	end)

	test("canUse stops at the match limit", function()
		assert(Boosts.canUse(usage(0, 2), "Hint", LIMITS) == "ok")
		assert(Boosts.canUse(usage(0, 3), "Hint", LIMITS) == "limit")
	end)

	test("canUse is disabled by the kill switch", function()
		assert(Boosts.canUse(usage(0, 0), "Hint", { Enabled = 0, PerRound = 1, PerMatch = 3 }) == "disabled")
	end)

	test("noteUse counts the round and the match", function()
		local uses = usage(0, 0)
		Boosts.noteUse(uses, "Hint")
		assert(uses.round.Hint == 1 and uses.match.Hint == 1 and uses.round.ExtraTime == 0)
		Boosts.noteUse(uses, "ExtraTime")
		assert(uses.round.ExtraTime == 1 and uses.match.ExtraTime == 1)
	end)

	test("pickHint gives a Mythic answer and is deterministic for a roll", function()
		local display, tier, answer = Boosts.pickHint(BANK, {}, 0)
		assert(display == "Jabuticaba" and tier == "Mythic" and answer == "jabuticaba", tostring(display))
		local again = Boosts.pickHint(BANK, {}, 0)
		assert(again == display)
	end)

	test("pickHint skips answers already locked in", function()
		local two = { Rare = { "lychee" }, Mythic = { "jabuticaba", "salak" } }
		local display, tier = Boosts.pickHint(two, { jabuticaba = true }, 0)
		assert(display == "Salak" and tier == "Mythic", tostring(display))
	end)

	test("pickHint drops a tier at a time when the higher ones are used up", function()
		local excluded = { jabuticaba = true }
		local display, tier = Boosts.pickHint(BANK, excluded, 0)
		assert(tier == "DeepCut" and display == "Mandoline", tostring(display))
		excluded.mandoline = true
		display, tier = Boosts.pickHint(BANK, excluded, 0.99)
		assert(tier == "Rare" and display == "Quince", tostring(display))
		excluded.lychee = true
		excluded.quince = true
		display, tier = Boosts.pickHint(BANK, excluded, 0)
		assert(tier == "Schooler" and display == "Mango", tostring(display))
	end)

	test("pickHint gives the highest tier a question has, and nil when nothing is left", function()
		local small = { Plankton = { "apple" }, Rare = { "lychee" } }
		local display, tier = Boosts.pickHint(small, {}, 0)
		assert(tier == "Rare" and display == "Lychee", tostring(display))
		display = Boosts.pickHint(small, { apple = true, lychee = true }, 0)
		assert(display == nil, tostring(display))
	end)
end
