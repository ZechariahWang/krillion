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
end
