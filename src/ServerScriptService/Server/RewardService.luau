--!strict
-- One-time and social rewards: Starter Shells for new profiles, joining group 36001322 (verified on the
-- server), and friend referrals through Roblox's invite join data (credited once the friend finishes a
-- match). Favoriting and liking are never rewarded (Roblox rules); the client only nudges.
-- Grants are claim-backed (DataService.claim), so each happens once per profile, best effort across servers.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local NotifyService = require(script.Parent.NotifyService)
local StoreService = require(script.Parent.StoreService)

local GROUP_ID = GameConfig.Rewards.GroupId
local JOIN_DATA_POLL = 0.5
-- Waits between group re-checks after a claim: membership can read as cached for a while right after
-- PromptJoinAsync says Joined, so keep looking for about 30 seconds.
local RECHECK_WAITS = { 0, 2, 4, 6, 8, 10 }

local handled: { [Player]: boolean } = {} -- the on-load pass has run (ProfileLoaded fires once per load)
local lastRecheck: { [Player]: number } = {}
local checking: { [Player]: boolean } = {}
local crediting: { [Player]: boolean } = {}

local RewardService = {}

local function itemNames(reward: string): string
	local names = {}
	for _, id in Rewards.itemsFor(reward) do
		local item = Cosmetics.ById[id]
		if item ~= nil then
			table.insert(names, string.upper(item.name))
		end
	end
	return table.concat(names, " + ")
end

-- fresh: read the member list (GetGroupsAsync) instead of IsInGroupAsync, whose answer may be cached.
local function inGroup(player: Player, fresh: boolean): boolean
	if GROUP_ID == 0 then
		return false
	end
	local function viaList(): boolean?
		local ok, groups = pcall(function()
			return GroupService:GetGroupsAsync(player.UserId)
		end)
		if not ok or typeof(groups) ~= "table" then
			return nil
		end
		for _, group in groups do
			if typeof(group) == "table" and group.Id == GROUP_ID then
				return true
			end
		end
		return false
	end
	local function viaPlayer(): boolean?
		local ok, member = pcall(function()
			return player:IsInGroupAsync(GROUP_ID)
		end)
		if not ok then
			return nil
		end
		return member == true
	end
	local first = if fresh then viaList() else viaPlayer()
	if first ~= nil then
		return first
	end
	-- One way failed (throttle, outage): ask the other before giving up.
	local second = if fresh then viaPlayer() else viaList()
	return second == true
end

local function grantGroup(player: Player)
	if not DataService.claim(player, Rewards.Group) then
		return
	end
	local grant = Rewards.groupGrant()
	for _, id in grant.items do
		DataService.grantItem(player, id)
	end
	StoreService.grantShells(player, grant.shells, "reward")
	NotifyService.send(
		player,
		"WELCOME TO THE REEF CREW!  |  " .. itemNames(Rewards.Group) .. " TITLE + " .. Currency.format(grant.shells),
		"good"
	)
end

-- Re-checks the player's unlocks (referral tiers, group) and grants anything newly earned.
function RewardService.refresh(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	-- Owned items follow the unlocks, so an item added to a reward later reaches everyone who earned it.
	for _, id in Rewards.missingItems(profile.claimed, profile.referrals, profile.owned) do
		DataService.grantItem(player, id)
	end
	for _, reward in Rewards.unlocksFor(profile.referrals) do
		if DataService.claim(player, reward) then
			NotifyService.send(player, "INVITE REWARD UNLOCKED!  |  " .. itemNames(reward), "good")
		end
	end
end

-- Roblox fills ReferredByPlayerId when the player came from a friend's PromptGameInvite. It can arrive a
-- few seconds after the player, so poll briefly.
local function referrerOf(player: Player): number
	local deadline = os.clock() + GameConfig.Rewards.JoinDataWaitSeconds
	while player.Parent ~= nil do
		local ok, data = pcall(function()
			return player:GetJoinData()
		end)
		if ok and typeof(data) == "table" then
			local id = tonumber(data.ReferredByPlayerId)
			if id ~= nil and id > 0 then
				return id
			end
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(JOIN_DATA_POLL)
	end
	return 0
end

local function welcomeReferred(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local refId = referrerOf(player)
	if not Rewards.referralEligible(refId, player.UserId, profile.referredBy, DataService.isNew(player)) then
		return
	end
	if DataService.setReferredBy(player, refId) and DataService.claim(player, Rewards.Welcome) then
		StoreService.grantShells(player, GameConfig.Rewards.WelcomeShells, "reward")
		NotifyService.send(
			player,
			"WELCOME! A FRIEND INVITED YOU  |  +" .. Currency.format(GameConfig.Rewards.WelcomeShells),
			"good"
		)
	end
end

local function onLoaded(player: Player)
	if handled[player] then
		return
	end
	handled[player] = true
	if DataService.isNew(player) and DataService.claim(player, Rewards.Starter) then
		StoreService.grantShells(player, GameConfig.Cash.StartingShells, "reward")
	end
	if DataService.isNew(player) then
		welcomeReferred(player)
	end
	if player.Parent == nil then
		return
	end
	if not DataService.isClaimed(player, Rewards.Group) and inGroup(player, false) then
		grantGroup(player)
	end
	RewardService.refresh(player)
end

-- The client asks after PromptJoinAsync says Joined (or AlreadyMember). Rate limited; re-checks for ~30 s.
local function onClaim(player: Player, id: any)
	if id ~= Rewards.Group then
		return
	end
	if DataService.isClaimed(player, Rewards.Group) then
		RewardService.refresh(player)
		return
	end
	local now = os.clock()
	if checking[player] or not Rewards.canRecheck(lastRecheck[player], now) then
		return
	end
	lastRecheck[player] = now
	checking[player] = true
	task.spawn(function()
		for _, seconds in RECHECK_WAITS do
			if seconds > 0 then
				task.wait(seconds)
			end
			if player.Parent == nil then
				break
			end
			if inGroup(player, true) then
				grantGroup(player)
				checking[player] = nil
				return
			end
		end
		checking[player] = nil
		if player.Parent ~= nil then
			NotifyService.send(player, "WE CAN'T SEE YOU IN THE GROUP YET. TRY CLAIM AGAIN IN A MINUTE.", "bad")
		end
	end)
end

-- The referrer is credited only once the invited friend has finished a match, so a quick alt join is not enough.
local function creditReferrer(player: Player)
	local profile = DataService.get(player)
	if profile == nil or profile.referredBy == 0 or crediting[player] then
		return
	end
	if DataService.isClaimed(player, Rewards.ReferralCredited) then
		return
	end
	-- Claimed before the write, so an invitee who leaves while it is in flight still saves the claim and can
	-- never credit twice. A failed write hands the claim back so the next match retries; if a save already
	-- took it, the referrer is under-credited, never over-credited.
	if not DataService.claim(player, Rewards.ReferralCredited) then
		return
	end
	crediting[player] = true
	local referrerId = profile.referredBy
	local ok = DataService.creditUser(referrerId, function(session)
		session.referrals += 1
	end)
	crediting[player] = nil
	if not ok then
		DataService.unclaim(player, Rewards.ReferralCredited)
		return
	end
	local referrer = Players:GetPlayerByUserId(referrerId)
	if referrer ~= nil then
		NotifyService.send(referrer, string.upper(player.DisplayName) .. " JOINED FROM YOUR INVITE!", "good")
		RewardService.refresh(referrer)
	end
end

local function onMatchFinished(participants: { Player })
	for _, player in participants do
		-- creditUser can yield on UpdateAsync; never hold up the match loop that fired this.
		task.spawn(function()
			creditReferrer(player)
			if player.Parent ~= nil then
				RewardService.refresh(player)
			end
		end)
	end
end

function RewardService.start()
	DataService.ProfileLoaded.connect(function(player: Player)
		task.spawn(onLoaded, player)
	end)
	-- Profiles that finished loading before this service started.
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) and not DataService.isReadOnly(player) then
			task.spawn(onLoaded, player)
		end
	end
	MatchEvents.MatchFinished.connect(onMatchFinished)
	Net.event("RewardClaim").OnServerEvent:Connect(onClaim)
	Players.PlayerRemoving:Connect(function(player)
		handled[player] = nil
		lastRecheck[player] = nil
		checking[player] = nil
		crediting[player] = nil
	end)
end

return RewardService
