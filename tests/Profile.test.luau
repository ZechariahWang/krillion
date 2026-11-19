local Profile = require("../src/ReplicatedStorage/Shared/Profile")

return function(test)
	test("a missing save loads as an empty profile", function()
		local profile = Profile.fromStored(nil)
		assert(profile.cash == 0 and profile.wins == 0 and profile.best == 0 and profile.revives == 0)
	end)

	test("a legacy coin number becomes the profile's cash", function()
		local profile = Profile.fromStored(120)
		assert(profile.cash == 120, "got " .. profile.cash)
	end)

	test("merge adds cash, wins and revives as deltas on top of what another server saved", function()
		local stored = Profile.fromStored(nil)
		stored.cash = 100
		stored.wins = 3
		stored.revives = 1
		local session = Profile.newSession()
		session.cash = 40
		session.wins = 1
		session.revives = -1
		local merged = Profile.merge(stored, session)
		assert(merged.cash == 140 and merged.wins == 4 and merged.revives == 0)
	end)

	test("merge keeps the higher best height", function()
		local stored = Profile.fromStored(nil)
		stored.best = 50
		local session = Profile.newSession()
		session.best = 30
		assert(Profile.merge(stored, session).best == 50)
		session.best = 70
		assert(Profile.merge(stored, session).best == 70)
	end)

	test("merge unions owned items and applies equipped choices", function()
		local stored = Profile.fromStored(nil)
		stored.owned.skin_coral = true
		local session = Profile.newSession()
		session.owned.title_diver = true
		session.equipped.Title = "title_diver"
		local merged = Profile.merge(stored, session)
		assert(merged.owned.skin_coral and merged.owned.title_diver)
		assert(merged.equipped.Title == "title_diver")
	end)

	test("merge never lets cash or revives go below zero", function()
		local stored = Profile.fromStored(nil)
		local session = Profile.newSession()
		session.cash = -10
		session.revives = -1
		local merged = Profile.merge(stored, session)
		assert(merged.cash == 0 and merged.revives == 0)
	end)

	test("a receipt id is remembered so a retried purchase is not granted twice", function()
		local stored = Profile.fromStored(nil)
		local session = Profile.newSession()
		table.insert(session.receipts, "r1")
		local merged = Profile.merge(stored, session)
		assert(Profile.hasReceipt(merged, "r1"))
		assert(not Profile.hasReceipt(merged, "r2"))
	end)

	test("combining two sessions keeps every change, later equips winning", function()
		local first = Profile.newSession()
		first.cash = 10
		first.best = 40
		first.owned.a = true
		first.equipped.Skin = "a"
		table.insert(first.receipts, "r1")
		local second = Profile.newSession()
		second.cash = 5
		second.best = 20
		second.owned.b = true
		second.equipped.Skin = "b"
		second.equipped.Title = "t"
		local combined = Profile.combine(first, second)
		assert(combined.cash == 15 and combined.best == 40)
		assert(combined.owned.a and combined.owned.b)
		assert(combined.equipped.Skin == "b" and combined.equipped.Title == "t")
		assert(combined.receipts[1] == "r1")
	end)

	test("only the most recent receipts are kept", function()
		local profile = Profile.fromStored(nil)
		for index = 1, Profile.MAX_RECEIPTS + 10 do
			local session = Profile.newSession()
			table.insert(session.receipts, "r" .. index)
			profile = Profile.merge(profile, session)
		end
		assert(#profile.receipts == Profile.MAX_RECEIPTS)
		assert(Profile.hasReceipt(profile, "r" .. (Profile.MAX_RECEIPTS + 10)))
		assert(not Profile.hasReceipt(profile, "r1"))
	end)

	test("a save from before the port loads every new field with its default", function()
		local profile = Profile.fromStored({ cash = 50, wins = 1, owned = {}, equipped = { Skin = "skin_coral" } })
		assert(profile.cash == 50 and profile.equipped.Skin == "skin_coral")
		assert(profile.hints == 0 and profile.extraTimes == 0 and profile.tutorialDone == false)
		assert(next(profile.claimed) == nil and profile.referrals == 0 and profile.referredBy == 0)
		assert(profile.quests.day == 0 and next(profile.quests.progress) == nil)
		assert(profile.lobby.day == 0 and profile.lobby.earned == 0)
		assert(profile.krillions == 0 and profile.games == 0)
		assert(profile.equipped.Trail == nil)
	end)

	test("boost inventory adds as deltas and never goes below zero", function()
		local stored = Profile.fromStored({ hints = 1, extraTimes = 0 })
		local session = Profile.newSession()
		session.hints = -3
		session.extraTimes = 2
		local merged = Profile.merge(stored, session)
		assert(merged.hints == 0 and merged.extraTimes == 2)
		local first = Profile.newSession()
		first.hints = 1
		local second = Profile.newSession()
		second.hints = 2
		assert(Profile.combine(first, second).hints == 3)
	end)

	test("the tutorial stays done once any server marks it", function()
		local stored = Profile.fromStored({ tutorialDone = true })
		assert(Profile.merge(stored, Profile.newSession()).tutorialDone)
		local session = Profile.newSession()
		session.tutorialDone = true
		assert(Profile.merge(Profile.fromStored(nil), session).tutorialDone)
	end)

	test("music is on by default and a saved choice survives a round trip", function()
		assert(Profile.new().musicOff == false)
		assert(Profile.fromStored(nil).musicOff == false)
		assert(Profile.fromStored({ musicOff = true }).musicOff == true)
	end)

	test("a music choice made this session replaces the saved one; no choice keeps it", function()
		local stored = Profile.fromStored({ musicOff = true })
		assert(Profile.merge(stored, Profile.newSession()).musicOff == true)
		local session = Profile.newSession()
		session.musicOff = false
		assert(Profile.merge(stored, session).musicOff == false)
	end)

	test("combined sessions keep the latest music choice", function()
		local first = Profile.newSession()
		first.musicOff = true
		local second = Profile.newSession()
		assert(Profile.combine(first, second).musicOff == true)
		second.musicOff = false
		assert(Profile.combine(first, second).musicOff == false)
	end)

	test("music volume defaults to full, survives a round trip and stays between 0 and 1", function()
		assert(Profile.new().musicVolume == 1)
		assert(Profile.fromStored({ musicVolume = 0.4 }).musicVolume == 0.4)
		assert(Profile.fromStored({ musicVolume = 3 }).musicVolume == 1)
		assert(Profile.fromStored({ musicVolume = -1 }).musicVolume == 0)
		assert(Profile.fromStored({ musicVolume = "loud" }).musicVolume == 1)
	end)

	test("a volume set this session replaces the saved one; none keeps it", function()
		local stored = Profile.fromStored({ musicVolume = 0.3 })
		assert(Profile.merge(stored, Profile.newSession()).musicVolume == 0.3)
		local session = Profile.newSession()
		session.musicVolume = 0.8
		assert(Profile.merge(stored, session).musicVolume == 0.8)
		local later = Profile.newSession()
		later.musicVolume = 0.5
		assert(Profile.combine(session, later).musicVolume == 0.5)
		assert(Profile.combine(session, Profile.newSession()).musicVolume == 0.8)
	end)

	test("claimed rewards are a union and survive a round trip", function()
		local stored = Profile.fromStored({ claimed = { Starter = true } })
		local session = Profile.newSession()
		session.claimed.Group = true
		local merged = Profile.merge(stored, session)
		assert(merged.claimed.Starter and merged.claimed.Group)
		local again = Profile.fromStored(merged)
		assert(again.claimed.Starter and again.claimed.Group)
	end)

	test("referrals add up and the first friend to refer keeps the credit", function()
		local stored = Profile.fromStored({ referrals = 2, referredBy = 111 })
		local session = Profile.newSession()
		session.referrals = 1
		session.referredBy = 222
		local merged = Profile.merge(stored, session)
		assert(merged.referrals == 3 and merged.referredBy == 111)
		local fresh = Profile.merge(Profile.fromStored(nil), session)
		assert(fresh.referredBy == 222)
		local first = Profile.newSession()
		first.referredBy = 333
		assert(Profile.combine(first, session).referredBy == 333)
		assert(Profile.combine(Profile.newSession(), session).referredBy == 222)
	end)

	test("quests: a newer day replaces, the same day keeps the most progress, an older day is ignored", function()
		local stored = Profile.fromStored({ quests = { day = 10, progress = { play_3 = 2, rare_2 = 1 }, done = { deep_1 = true } } })
		local same = Profile.newSession()
		same.quests = { day = 10, progress = { play_3 = 1, rare_2 = 2 }, done = { rare_2 = true } }
		local merged = Profile.merge(stored, same)
		assert(merged.quests.progress.play_3 == 2 and merged.quests.progress.rare_2 == 2)
		assert(merged.quests.done.deep_1 and merged.quests.done.rare_2)

		local newer = Profile.newSession()
		newer.quests = { day = 11, progress = { win_1 = 1 }, done = {} }
		merged = Profile.merge(stored, newer)
		assert(merged.quests.day == 11 and merged.quests.progress.win_1 == 1 and merged.quests.progress.play_3 == nil)

		local older = Profile.newSession()
		older.quests = { day = 9, progress = { play_3 = 3 }, done = { play_3 = true } }
		merged = Profile.merge(stored, older)
		assert(merged.quests.day == 10 and merged.quests.progress.play_3 == 2 and not merged.quests.done.play_3)

		assert(Profile.merge(stored, Profile.newSession()).quests.progress.play_3 == 2)
	end)

	test("warm-up earnings add up within a day and start over on a new day", function()
		local stored = Profile.fromStored({ lobby = { day = 10, earned = 300 } })
		local same = Profile.newSession()
		same.lobby = { day = 10, earned = 50 }
		assert(Profile.merge(stored, same).lobby.earned == 350)
		assert(Profile.lobbyEarned(Profile.merge(stored, same), 10) == 350)
		assert(Profile.lobbyEarned(stored, 11) == 0)

		local newer = Profile.newSession()
		newer.lobby = { day = 11, earned = 20 }
		local merged = Profile.merge(stored, newer)
		assert(merged.lobby.day == 11 and merged.lobby.earned == 20)

		local older = Profile.newSession()
		older.lobby = { day = 9, earned = 999 }
		merged = Profile.merge(stored, older)
		assert(merged.lobby.day == 10 and merged.lobby.earned == 300)

		local first = Profile.newSession()
		first.lobby = { day = 10, earned = 5 }
		assert(Profile.combine(first, same).lobby.earned == 55)
		assert(Profile.combine(first, newer).lobby.day == 11)
		assert(Profile.combine(first, Profile.newSession()).lobby.earned == 5)
	end)

	test("the equipped trail round-trips and later equips win", function()
		local session = Profile.newSession()
		session.equipped.Trail = "trail_bubbles"
		local merged = Profile.merge(Profile.fromStored(nil), session)
		assert(Profile.fromStored(merged).equipped.Trail == "trail_bubbles")
		local later = Profile.newSession()
		later.equipped.Trail = "trail_seafoam"
		assert(Profile.combine(session, later).equipped.Trail == "trail_seafoam")
		local unequip = Profile.newSession()
		unequip.equipped.Trail = ""
		assert(Profile.merge(merged, unequip).equipped.Trail == "")
	end)

	test("lifetime krillions and games add up", function()
		local stored = Profile.fromStored({ krillions = 2, games = 10 })
		local session = Profile.newSession()
		session.krillions = 1
		session.games = 1
		local merged = Profile.merge(stored, session)
		assert(merged.krillions == 3 and merged.games == 11)
		assert(Profile.combine(session, session).games == 2)
	end)

	test("the deepest dive keeps the deeper one with its answer", function()
		local stored = Profile.fromStored({ deepest = 300, deepestAnswer = "kiwi" })
		assert(stored.deepest == 300 and stored.deepestAnswer == "kiwi")
		assert(Profile.fromStored({}).deepestAnswer == "")
		local shallower = Profile.newSession()
		shallower.deepest = 120
		shallower.deepestAnswer = "apple"
		local kept = Profile.merge(stored, shallower)
		assert(kept.deepest == 300 and kept.deepestAnswer == "kiwi")
		local deeper = Profile.newSession()
		deeper.deepest = 512
		deeper.deepestAnswer = "jabuticaba"
		local replaced = Profile.merge(stored, deeper)
		assert(replaced.deepest == 512 and replaced.deepestAnswer == "jabuticaba")
		local combined = Profile.combine(deeper, shallower)
		assert(combined.deepest == 512 and combined.deepestAnswer == "jabuticaba")
	end)

	test("fromStored keeps the server that holds the profile", function()
		local profile = Profile.fromStored({ activeSession = { jobId = "job-a", time = 1000 } })
		local active = profile.activeSession
		assert(active ~= nil and active.jobId == "job-a" and active.time == 1000)
		assert(Profile.fromStored({ activeSession = "junk" }).activeSession == nil)
	end)

	test("merge keeps the stored session marker unless the session sets one", function()
		local stored = Profile.fromStored({ activeSession = { jobId = "job-a", time = 1000 } })
		local untouched = Profile.merge(stored, Profile.newSession())
		local kept = untouched.activeSession
		assert(kept ~= nil and kept.jobId == "job-a")
		local session = Profile.newSession()
		session.activeSession = { jobId = "job-b", time = 2000 }
		local replaced = Profile.merge(stored, session).activeSession
		assert(replaced ~= nil and replaced.jobId == "job-b" and replaced.time == 2000)
		local combined = Profile.combine(session, Profile.newSession()).activeSession
		assert(combined ~= nil and combined.jobId == "job-b")
	end)

	test("a new player starts with no XP", function()
		assert(Profile.fromStored(nil).xp == 0)
	end)

	test("a saved profile from before levels starts with XP for its games and wins", function()
		local profile = Profile.fromStored({ cash = 10, games = 4, wins = 2 })
		assert(profile.xp == Profile.startingXp(4, 2), "got " .. profile.xp)
		assert(profile.xp > 0)
		assert(Profile.startingXp(4, 3) > Profile.startingXp(4, 2))
		assert(Profile.startingXp(5, 2) > Profile.startingXp(4, 2))
	end)

	test("saved XP is kept as it is, never given the starting XP again", function()
		local profile = Profile.fromStored({ games = 40, wins = 10, xp = 7 })
		assert(profile.xp == 7)
	end)

	test("XP from a session adds on top of what another server saved", function()
		local stored = Profile.fromStored({ xp = 500 })
		local first = Profile.newSession()
		first.xp = 30
		local second = Profile.newSession()
		second.xp = 20
		local merged = Profile.merge(stored, Profile.combine(first, second))
		assert(merged.xp == 550, "got " .. merged.xp)
		assert(Profile.fromStored(merged).xp == 550)
	end)

	test("a saved collection card loads, and a broken one is dropped", function()
		local profile = Profile.fromStored({ collection = { author = { tier = "Rare", answer = "aesop" }, bad = { tier = 5 } } })
		assert(profile.collection.author ~= nil and profile.collection.author.answer == "aesop")
		assert(profile.collection.bad == nil)
	end)

	test("collection cards merge to the rarer tier from either server", function()
		local stored = Profile.fromStored({ collection = {
			author = { tier = "DeepCut", answer = "aesop" },
			wild_cat = { tier = "Rare", answer = "ocelot" },
		} })
		local session = Profile.newSession()
		session.collection.author = { tier = "Rare", answer = "poe" }
		session.collection.wild_cat = { tier = "Mythic", answer = "margay" }
		session.collection.vegetable = { tier = "Schooler", answer = "leek" }
		local merged = Profile.merge(stored, session)
		assert(merged.collection.author.answer == "aesop")
		assert(merged.collection.wild_cat.answer == "margay")
		assert(merged.collection.vegetable.tier == "Schooler")
		local first = Profile.newSession()
		first.collection.author = { tier = "Mythic", answer = "aesop" }
		local second = Profile.newSession()
		second.collection.author = { tier = "Rare", answer = "poe" }
		assert(Profile.combine(first, second).collection.author.tier == "Mythic")
	end)

	test("a saved Prompt of the Day answer loads, and a new player has none", function()
		assert(Profile.fromStored(nil).dailyPrompt.day == 0)
		local profile = Profile.fromStored({ dailyPrompt = { day = 20410, answer = "aesop", tier = "Mythic", streak = 3, prevDay = 20409, prevAnswer = "lynx", prevTier = "Rare" } })
		local state = profile.dailyPrompt
		assert(state.day == 20410 and state.answer == "aesop" and state.tier == "Mythic" and state.streak == 3)
		assert(state.prevDay == 20409 and state.prevAnswer == "lynx" and state.prevTier == "Rare")
	end)

	test("the later Prompt of the Day answer wins a merge, an older server never rolls it back", function()
		local stored = Profile.fromStored({ dailyPrompt = { day = 20410, answer = "aesop", tier = "Mythic", streak = 3 } })
		local stale = Profile.newSession()
		stale.dailyPrompt = { day = 20409, answer = "poe", tier = "Rare", streak = 2, prevDay = 0, prevAnswer = "", prevTier = "" }
		assert(Profile.merge(stored, stale).dailyPrompt.answer == "aesop")
		local newer = Profile.newSession()
		newer.dailyPrompt = { day = 20411, answer = "lynx", tier = "Rare", streak = 4, prevDay = 20410, prevAnswer = "aesop", prevTier = "Mythic" }
		assert(Profile.merge(stored, newer).dailyPrompt.answer == "lynx")
		assert(Profile.combine(newer, stale).dailyPrompt.day == 20411)
	end)
end
