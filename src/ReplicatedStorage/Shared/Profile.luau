--!strict
-- The saved player profile and how one server's session changes merge into it.
-- Cash, wins and revives are deltas so two servers never overwrite each other; best keeps the max.
-- Every field has a merge rule (see merge) so no session locking is needed. Add a new field to Profile,
-- Session, new, newSession, fromStored, combine and merge, or it is silently dropped on save.
-- No Roblox APIs here, so Lune tests can require it.

export type Equipped = {
	Skin: string?,
	Title: string?,
	Splash: string?,
	Trail: string?,
}

-- Daily quests: absolute values for one UTC day (Quests.day). day 0 means untouched.
export type QuestDay = {
	day: number,
	progress: { [string]: number },
	done: { [string]: boolean },
}

-- Warm-up Shells earned on one UTC day, for the daily cap. In a session `earned` is a delta.
export type LobbyDay = {
	day: number,
	earned: number,
}

export type Profile = {
	cash: number,
	wins: number,
	best: number,
	revives: number,
	owned: { [string]: boolean },
	equipped: Equipped,
	receipts: { string },
	hints: number, -- boost inventory
	extraTimes: number,
	tutorialDone: boolean,
	claimed: { [string]: boolean }, -- one-time grants: Starter, Welcome, Group, ReferralCredited, Referral1, Referral3
	referrals: number, -- friends who joined from this player's invite and finished a match
	referredBy: number, -- UserId of the friend whose invite brought this player; 0 for none
	quests: QuestDay,
	lobby: LobbyDay,
	krillions: number, -- One in a Krillion answers ever given in matches
	games: number, -- matches played to the end
}

export type Session = {
	cash: number,
	wins: number,
	best: number,
	revives: number,
	owned: { [string]: boolean },
	equipped: Equipped, -- only the slots changed this session; "" means unequipped
	receipts: { string },
	hints: number, -- delta
	extraTimes: number, -- delta
	tutorialDone: boolean, -- true once finished in this session
	claimed: { [string]: boolean },
	referrals: number, -- delta
	referredBy: number, -- 0 unless set this session
	quests: QuestDay,
	lobby: LobbyDay,
	krillions: number, -- delta
	games: number, -- delta
}

local Profile = {}

Profile.MAX_RECEIPTS = 50

local function newQuests(): QuestDay
	return { day = 0, progress = {}, done = {} }
end

local function newLobby(): LobbyDay
	return { day = 0, earned = 0 }
end

function Profile.new(): Profile
	return {
		cash = 0,
		wins = 0,
		best = 0,
		revives = 0,
		owned = {},
		equipped = {},
		receipts = {},
		hints = 0,
		extraTimes = 0,
		tutorialDone = false,
		claimed = {},
		referrals = 0,
		referredBy = 0,
		quests = newQuests(),
		lobby = newLobby(),
		krillions = 0,
		games = 0,
	}
end

local function numberOr(value: any, fallback: number): number
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function copyQuests(value: any): QuestDay -- any: stored table or a QuestDay
	local quests = newQuests()
	if typeof(value) ~= "table" then
		return quests
	end
	quests.day = numberOr(value.day, 0)
	if typeof(value.progress) == "table" then
		for id, amount in value.progress do
			if typeof(id) == "string" and typeof(amount) == "number" then
				quests.progress[id] = amount
			end
		end
	end
	if typeof(value.done) == "table" then
		for id, done in value.done do
			if typeof(id) == "string" and done == true then
				quests.done[id] = true
			end
		end
	end
	return quests
end

local function copyLobby(value: any): LobbyDay -- any: stored table or a LobbyDay
	local lobby = newLobby()
	if typeof(value) == "table" then
		lobby.day = numberOr(value.day, 0)
		lobby.earned = numberOr(value.earned, 0)
	end
	return lobby
end

-- Same-day quest progress from two sources: the higher progress per quest, and done if either is done.
local function joinQuests(a: QuestDay, b: QuestDay): QuestDay
	if b.day > a.day then
		return copyQuests(b)
	end
	if b.day < a.day then
		return copyQuests(a)
	end
	local joined = copyQuests(a)
	for id, amount in b.progress do
		joined.progress[id] = math.max(joined.progress[id] or 0, amount)
	end
	for id in b.done do
		joined.done[id] = true
	end
	return joined
end

-- Accepts nothing (new player), a bare number (the old coins-only save) or a saved profile table.
function Profile.fromStored(value: any): Profile -- any: raw DataStore value
	local profile = Profile.new()
	if typeof(value) == "number" then
		profile.cash = value
		return profile
	end
	if typeof(value) ~= "table" then
		return profile
	end
	local stored = value :: { [string]: any }
	profile.cash = numberOr(stored.cash, 0)
	profile.wins = numberOr(stored.wins, 0)
	profile.best = numberOr(stored.best, 0)
	profile.revives = numberOr(stored.revives, 0)
	if typeof(stored.owned) == "table" then
		for id, owned in stored.owned do
			if owned == true then
				profile.owned[id] = true
			end
		end
	end
	if typeof(stored.equipped) == "table" then
		profile.equipped.Skin = stored.equipped.Skin
		profile.equipped.Title = stored.equipped.Title
		profile.equipped.Splash = stored.equipped.Splash
		profile.equipped.Trail = stored.equipped.Trail
	end
	if typeof(stored.receipts) == "table" then
		for _, receipt in stored.receipts do
			table.insert(profile.receipts, receipt)
		end
	end
	profile.hints = numberOr(stored.hints, 0)
	profile.extraTimes = numberOr(stored.extraTimes, 0)
	profile.tutorialDone = stored.tutorialDone == true
	if typeof(stored.claimed) == "table" then
		for id, claimed in stored.claimed do
			if claimed == true then
				profile.claimed[id] = true
			end
		end
	end
	profile.referrals = numberOr(stored.referrals, 0)
	profile.referredBy = numberOr(stored.referredBy, 0)
	profile.quests = copyQuests(stored.quests)
	profile.lobby = copyLobby(stored.lobby)
	profile.krillions = numberOr(stored.krillions, 0)
	profile.games = numberOr(stored.games, 0)
	return profile
end

function Profile.newSession(): Session
	return {
		cash = 0,
		wins = 0,
		best = 0,
		revives = 0,
		owned = {},
		equipped = {},
		receipts = {},
		hints = 0,
		extraTimes = 0,
		tutorialDone = false,
		claimed = {},
		referrals = 0,
		referredBy = 0,
		quests = newQuests(),
		lobby = newLobby(),
		krillions = 0,
		games = 0,
	}
end

-- One session holding the changes of `first` followed by `second`, e.g. to retry a failed save.
function Profile.combine(first: Session, second: Session): Session
	local combined = Profile.newSession()
	combined.cash = first.cash + second.cash
	combined.wins = first.wins + second.wins
	combined.best = math.max(first.best, second.best)
	combined.revives = first.revives + second.revives
	for id in first.owned do
		combined.owned[id] = true
	end
	for id in second.owned do
		combined.owned[id] = true
	end
	combined.equipped.Skin = second.equipped.Skin or first.equipped.Skin
	combined.equipped.Title = second.equipped.Title or first.equipped.Title
	combined.equipped.Splash = second.equipped.Splash or first.equipped.Splash
	combined.equipped.Trail = second.equipped.Trail or first.equipped.Trail
	for _, receipt in first.receipts do
		table.insert(combined.receipts, receipt)
	end
	for _, receipt in second.receipts do
		table.insert(combined.receipts, receipt)
	end
	combined.hints = first.hints + second.hints
	combined.extraTimes = first.extraTimes + second.extraTimes
	combined.tutorialDone = first.tutorialDone or second.tutorialDone
	for id in first.claimed do
		combined.claimed[id] = true
	end
	for id in second.claimed do
		combined.claimed[id] = true
	end
	combined.referrals = first.referrals + second.referrals
	if first.referredBy ~= 0 then
		combined.referredBy = first.referredBy
	else
		combined.referredBy = second.referredBy
	end
	combined.quests = joinQuests(first.quests, second.quests)
	-- Warm-up earnings are deltas for a day: the same day adds up, a later day starts over.
	if second.lobby.day > first.lobby.day then
		combined.lobby = copyLobby(second.lobby)
	elseif second.lobby.day < first.lobby.day then
		combined.lobby = copyLobby(first.lobby)
	else
		combined.lobby = { day = first.lobby.day, earned = first.lobby.earned + second.lobby.earned }
	end
	combined.krillions = first.krillions + second.krillions
	combined.games = first.games + second.games
	return combined
end

function Profile.hasReceipt(profile: Profile, receipt: string): boolean
	for _, seen in profile.receipts do
		if seen == receipt then
			return true
		end
	end
	return false
end

function Profile.merge(stored: Profile, session: Session): Profile
	local merged = Profile.fromStored(stored)
	merged.cash = math.max(0, merged.cash + session.cash)
	merged.wins = merged.wins + session.wins
	merged.best = math.max(merged.best, session.best)
	merged.revives = math.max(0, merged.revives + session.revives)
	for id in session.owned do
		merged.owned[id] = true
	end
	if session.equipped.Skin ~= nil then
		merged.equipped.Skin = session.equipped.Skin
	end
	if session.equipped.Title ~= nil then
		merged.equipped.Title = session.equipped.Title
	end
	if session.equipped.Splash ~= nil then
		merged.equipped.Splash = session.equipped.Splash
	end
	if session.equipped.Trail ~= nil then
		merged.equipped.Trail = session.equipped.Trail
	end
	for _, receipt in session.receipts do
		table.insert(merged.receipts, receipt)
	end
	while #merged.receipts > Profile.MAX_RECEIPTS do
		table.remove(merged.receipts, 1)
	end
	merged.hints = math.max(0, merged.hints + session.hints)
	merged.extraTimes = math.max(0, merged.extraTimes + session.extraTimes)
	merged.tutorialDone = merged.tutorialDone or session.tutorialDone
	for id in session.claimed do
		merged.claimed[id] = true
	end
	merged.referrals = math.max(0, merged.referrals + session.referrals)
	-- The first friend to be recorded keeps the credit.
	if merged.referredBy == 0 then
		merged.referredBy = session.referredBy
	end
	-- An older day's quests from a long-running server never overwrite today's.
	merged.quests = joinQuests(merged.quests, session.quests)
	if session.lobby.day > merged.lobby.day then
		merged.lobby = copyLobby(session.lobby)
	elseif session.lobby.day == merged.lobby.day then
		merged.lobby.earned += session.lobby.earned
	end
	merged.krillions = merged.krillions + session.krillions
	merged.games = merged.games + session.games
	return merged
end

-- Warm-up Shells already earned on `day` (0 if the stored day is another one).
function Profile.lobbyEarned(profile: Profile, day: number): number
	if profile.lobby.day == day then
		return profile.lobby.earned
	end
	return 0
end

return Profile
