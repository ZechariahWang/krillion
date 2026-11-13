--!strict
-- What the coming surge means for one pillar: the lowest tier that keeps it afloat, how much room it
-- has left once the water settles, and who sank. Pure, so the client copy and the tests agree.

local Tiers = require("../Config/Tiers")
local SpecialRound = require("./SpecialRound")

local Tide = {}

-- "safe" when the pillar already clears this round's surge, otherwise the lowest tier whose lift is enough,
-- or "none" when even a Mythic falls short. Sums are done the way the server does them
-- (height + lift against waterY + surge) so float rounding lands on the same side.
function Tide.needTier(height: number, waterY: number, surge: number, special: string?): string
	local target = waterY + surge
	if height >= target then
		return "safe"
	end
	for _, tier in Tiers.List do
		if height + SpecialRound.lift(tier.points, special) >= target then
			return tier.name
		end
	end
	return "none"
end

-- Studs between the pillar top and the water; below zero means sunk.
function Tide.margin(height: number, waterY: number): number
	return height - waterY
end

-- Ids in `before` that are missing from `after`, in their original order.
function Tide.sunk(before: { number }, after: { number }): { number }
	local still: { [number]: boolean } = {}
	for _, id in after do
		still[id] = true
	end
	local gone = {}
	for _, id in before do
		if not still[id] then
			table.insert(gone, id)
		end
	end
	return gone
end

-- "SUNK: A", "SUNK: A AND B", "SUNK: A, B, C, D AND 3 MORE". nil for nobody.
function Tide.sunkText(names: { string }, maxNames: number): string?
	local count = #names
	if count == 0 then
		return nil
	end
	local shown = math.min(count, math.max(1, maxNames))
	local listed: { string } = {}
	for index = 1, shown do
		table.insert(listed, names[index])
	end
	local rest = count - shown
	if rest > 0 then
		return "SUNK: " .. table.concat(listed, ", ") .. " AND " .. rest .. " MORE"
	end
	if shown == 1 then
		return "SUNK: " .. listed[1]
	end
	local last = table.remove(listed) :: string
	return "SUNK: " .. table.concat(listed, ", ") .. " AND " .. last
end

return Tide
