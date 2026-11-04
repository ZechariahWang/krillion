--!strict
-- Rules for the free social rewards: who counts as a referred new player, which referral tiers a count
-- unlocks, what the group reward grants, and the client's one favorite nudge. Pure, so Lune tests can
-- require it. Liking and favoriting are never rewarded (Roblox rules); only the group and invites are.
local Cosmetics = require("../Config/Cosmetics")
local GameConfig = require("../Config/GameConfig")

export type Grant = {
	items: { string }, -- cosmetic ids put in profile.owned
	shells: number,
}

local Rewards = {
	-- profile.claimed ids. Reward ids (Group, Referral1, Referral3) match Cosmetics item `reward` fields.
	Starter = "Starter",
	Welcome = "Welcome",
	Group = "Group",
	ReferralCredited = "ReferralCredited",
	Referral1 = "Referral1",
	Referral3 = "Referral3",
}

-- A friend's invite counts only for a brand-new profile that has no referrer yet, and never for yourself.
-- refId is Player:GetJoinData().ReferredByPlayerId (Roblox verifies it; launch data can be forged).
function Rewards.referralEligible(refId: number?, selfId: number, referredBy: number, isNew: boolean): boolean
	if refId == nil or refId <= 0 or refId == selfId then
		return false
	end
	return referredBy == 0 and isNew
end

-- The referral rewards `referrals` finished-a-match friends have unlocked, lowest tier first.
function Rewards.unlocksFor(referrals: number): { string }
	local unlocked = {}
	if referrals >= GameConfig.Rewards.ReferralTier1 then
		table.insert(unlocked, Rewards.Referral1)
	end
	if referrals >= GameConfig.Rewards.ReferralTier2 then
		table.insert(unlocked, Rewards.Referral3)
	end
	return unlocked
end

-- The next referral goal above `referrals`, or nil once every tier is unlocked.
function Rewards.nextGoal(referrals: number): number?
	if referrals < GameConfig.Rewards.ReferralTier1 then
		return GameConfig.Rewards.ReferralTier1
	end
	if referrals < GameConfig.Rewards.ReferralTier2 then
		return GameConfig.Rewards.ReferralTier2
	end
	return nil
end

-- Cosmetic ids a reward unlocks, from the catalogue's `reward` fields.
function Rewards.itemsFor(reward: string): { string }
	local ids = {}
	for _, item in Cosmetics.forReward(reward) do
		table.insert(ids, item.id)
	end
	return ids
end

-- Joining the group: the Reef Crew title plus some Shells.
function Rewards.groupGrant(): Grant
	return { items = Rewards.itemsFor(Rewards.Group), shells = GameConfig.Rewards.GroupShells }
end

-- Every reward the profile has earned, whose items it should own: the group once claimed, plus the
-- referral tiers its count has reached.
function Rewards.unlockedRewards(claimed: { [string]: boolean }, referrals: number): { string }
	local unlocked = {}
	if claimed[Rewards.Group] == true then
		table.insert(unlocked, Rewards.Group)
	end
	for _, id in Rewards.unlocksFor(referrals) do
		table.insert(unlocked, id)
	end
	return unlocked
end

-- Items from unlocked rewards the profile does not own yet, in reward order.
function Rewards.missingItems(claimed: { [string]: boolean }, referrals: number, owned: { [string]: boolean }): { string }
	local missing = {}
	for _, reward in Rewards.unlockedRewards(claimed, referrals) do
		for _, id in Rewards.itemsFor(reward) do
			if owned[id] ~= true then
				table.insert(missing, id)
			end
		end
	end
	return missing
end

-- A client may ask for a group re-check at most once per GroupRecheckSeconds. lastAt is nil before the first.
function Rewards.canRecheck(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= GameConfig.Rewards.GroupRecheckSeconds
end

-- The one unrewarded favorite toast is due after this many matches finished this session.
function Rewards.favoriteNudgeDue(matchesThisSession: number, alreadyShown: boolean): boolean
	return not alreadyShown and matchesThisSession >= GameConfig.Rewards.FavoriteNudgeAfterMatches
end

return table.freeze(Rewards)
