--!strict
-- How the currency is named and written on screen. The data key stays `cash` (no DataStore migration);
-- every player-facing string goes through here so a rename touches one file. Lune-safe.

local Currency = {
	Name = "Shells",
	Upper = "SHELLS",
}

-- 1250 -> "1,250"
function Currency.digits(amount: number): string
	local whole = math.floor(math.abs(amount))
	local text = tostring(whole)
	local grouped = ""
	while #text > 3 do
		grouped = "," .. string.sub(text, -3) .. grouped
		text = string.sub(text, 1, -4)
	end
	grouped = text .. grouped
	if amount < 0 and whole > 0 then
		grouped = "-" .. grouped
	end
	return grouped
end

-- 1250 -> "1,250 SHELLS"
function Currency.format(amount: number): string
	return Currency.digits(amount) .. " " .. Currency.Upper
end

-- Compact form for tight chips: 950 -> "950", 1250 -> "1.3K", 3400000 -> "3.4M".
function Currency.short(amount: number): string
	local value = math.abs(amount)
	local sign = if amount < 0 then "-" else ""
	local function oneDecimal(x: number): string
		-- Round half up by hand: string.format("%.1f", 1.25) gives "1.2".
		local rounded = math.floor(x * 10 + 0.5) / 10
		if rounded == math.floor(rounded) then
			return tostring(math.floor(rounded))
		end
		return string.format("%.1f", rounded)
	end
	-- 999,999 would round to "1000K", so it already counts as millions.
	if value >= 999950 then
		return sign .. oneDecimal(value / 1e6) .. "M"
	end
	if value >= 1e3 then
		return sign .. oneDecimal(value / 1e3) .. "K"
	end
	return sign .. tostring(math.floor(value))
end

return table.freeze(Currency)
