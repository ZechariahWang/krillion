--!strict
-- Schooling: players who lock in the same answer in a round each get only Factor of its points, so
-- copying the obvious pick costs you. Pure (no Roblox APIs), so Lune tests can require it.

export type Config = {
	Enabled: number,
	Factor: number,
}

local Schooling = {}

-- How many players gave each player's answer (case-insensitive), keyed like `answers`.
function Schooling.sizes(answers: { [any]: string }): { [any]: number }
	local counts: { [string]: number } = {}
	for _, answer in answers do
		local key = string.lower(answer)
		counts[key] = (counts[key] or 0) + 1
	end
	local sizes = {}
	for id, answer in answers do
		sizes[id] = counts[string.lower(answer)]
	end
	return sizes
end

function Schooling.applies(size: number?, cfg: Config): boolean
	return cfg.Enabled == 1 and size ~= nil and size >= 2
end

function Schooling.apply(points: number, size: number?, cfg: Config): number
	if Schooling.applies(size, cfg) then
		return math.floor(points * cfg.Factor)
	end
	return points
end

return Schooling
