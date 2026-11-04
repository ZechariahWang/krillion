local Rewards = require("../src/ReplicatedStorage/Shared/Rewards")
local Cosmetics = require("../src/ReplicatedStorage/Config/Cosmetics")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local function same(got: { string }, want: { string }): boolean
	if #got ~= #want then
		return false
	end
	for i, value in want do
		if got[i] ~= value then
			return false
		end
	end
	return true
end

return function(test)
	test("a referral counts for a new profile invited by someone else", function()
		assert(Rewards.referralEligible(42, 7, 0, true) == true)
	end)

	test("a referral never counts for yourself, nobody, an existing referrer or an old profile", function()
		assert(Rewards.referralEligible(7, 7, 0, true) == false, "self")
		assert(Rewards.referralEligible(0, 7, 0, true) == false, "zero")
		assert(Rewards.referralEligible(nil, 7, 0, true) == false, "nil")
		assert(Rewards.referralEligible(-3, 7, 0, true) == false, "negative")
		assert(Rewards.referralEligible(42, 7, 99, true) == false, "already referred")
		assert(Rewards.referralEligible(42, 7, 0, false) == false, "not new")
	end)

	test("unlocksFor follows the referral tiers", function()
		assert(GameConfig.Rewards.ReferralTier1 == 1 and GameConfig.Rewards.ReferralTier2 == 3)
		assert(same(Rewards.unlocksFor(0), {}))
		assert(same(Rewards.unlocksFor(1), { "Referral1" }))
		assert(same(Rewards.unlocksFor(2), { "Referral1" }))
		assert(same(Rewards.unlocksFor(3), { "Referral1", "Referral3" }))
		assert(same(Rewards.unlocksFor(10), { "Referral1", "Referral3" }))
	end)

	test("nextGoal walks the tiers and stops after the last", function()
		assert(Rewards.nextGoal(0) == 1)
		assert(Rewards.nextGoal(1) == 3)
		assert(Rewards.nextGoal(2) == 3)
		assert(Rewards.nextGoal(3) == nil)
	end)

	test("groupGrant is the Reef Crew title plus the group Shells", function()
		local grant = Rewards.groupGrant()
		assert(grant.shells == GameConfig.Rewards.GroupShells and grant.shells == 250, tostring(grant.shells))
		assert(same(grant.items, { "title_crew" }), table.concat(grant.items, ","))
	end)

	test("each reward tier unlocks a real, unsold catalogue item", function()
		for _, reward in { "Group", "Referral1", "Referral3" } do
			local ids = Rewards.itemsFor(reward)
			assert(#ids >= 1, reward .. " unlocks nothing")
			for _, id in ids do
				local item = Cosmetics.ById[id]
				assert(item ~= nil and item.reward == reward, id)
			end
		end
		assert(same(Rewards.itemsFor("Referral1"), { "skin_buddy" }))
		assert(same(Rewards.itemsFor("Referral3"), { "trail_pod" }))
	end)

	test("missingItems lists unlocked items not yet owned", function()
		assert(same(Rewards.missingItems({}, 0, {}), {}))
		assert(same(Rewards.missingItems({ Group = true }, 0, {}), { "title_crew" }))
		assert(same(Rewards.missingItems({ Group = true }, 3, { title_crew = true }), { "skin_buddy", "trail_pod" }))
		assert(same(Rewards.missingItems({}, 1, { skin_buddy = true }), {}))
	end)

	test("group re-checks are rate limited", function()
		local gap = GameConfig.Rewards.GroupRecheckSeconds
		assert(Rewards.canRecheck(nil, 0) == true)
		assert(Rewards.canRecheck(100, 100 + gap - 1) == false)
		assert(Rewards.canRecheck(100, 100 + gap) == true)
	end)

	test("the favorite nudge is due once, after enough matches", function()
		local after = GameConfig.Rewards.FavoriteNudgeAfterMatches
		assert(Rewards.favoriteNudgeDue(after - 1, false) == false)
		assert(Rewards.favoriteNudgeDue(after, false) == true)
		assert(Rewards.favoriteNudgeDue(after + 3, true) == false)
	end)
end
