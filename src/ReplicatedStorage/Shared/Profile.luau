--!strict
-- The saved player profile and how one server's session changes merge into it.
-- Cash, wins and revives are deltas so two servers never overwrite each other; best keeps the max.
-- No Roblox APIs here, so Lune tests can require it.

export type Equipped = {
	Skin: string?,
	Title: string?,
	Splash: string?,
}

export type Profile = {
	cash: number,
	wins: number,
	best: number,
	revives: number,
	owned: { [string]: boolean },
	equipped: Equipped,
	receipts: { string },
}

export type Session = {
	cash: number,
	wins: number,
	best: number,
	revives: number,
	owned: { [string]: boolean },
	equipped: Equipped, -- only the slots changed this session; "" means unequipped
	receipts: { string },
}

local Profile = {}

Profile.MAX_RECEIPTS = 50

function Profile.new(): Profile
	return {
		cash = 0,
		wins = 0,
		best = 0,
		revives = 0,
		owned = {},
		equipped = {},
		receipts = {},
	}
end

local function numberOr(value: any, fallback: number): number
	if typeof(value) == "number" then
		return value
	end
	return fallback
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
	end
	if typeof(stored.receipts) == "table" then
		for _, receipt in stored.receipts do
			table.insert(profile.receipts, receipt)
		end
	end
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
	for _, receipt in first.receipts do
		table.insert(combined.receipts, receipt)
	end
	for _, receipt in second.receipts do
		table.insert(combined.receipts, receipt)
	end
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
	for _, receipt in session.receipts do
		table.insert(merged.receipts, receipt)
	end
	while #merged.receipts > Profile.MAX_RECEIPTS do
		table.remove(merged.receipts, 1)
	end
	return merged
end

return Profile
