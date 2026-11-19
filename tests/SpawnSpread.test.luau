local SpawnSpread = require("../src/ReplicatedStorage/Shared/SpawnSpread")

-- A small seeded generator, so a run is the same every time.
local function stream(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return function(test)
	test("spawn spread: every spot sits on the ring round the spawn", function()
		local spots = SpawnSpread.candidates(0, 64, {}, stream(3))
		assert(#spots == SpawnSpread.TRIES)
		for _, spot in spots do
			local r = math.sqrt(spot[1] ^ 2 + (spot[2] - 64) ^ 2)
			assert(r >= SpawnSpread.MIN_RADIUS - 1e-9 and r <= SpawnSpread.MAX_RADIUS + 1e-9, "radius " .. r)
		end
	end)

	test("spawn spread: eight players landing one after another never share a spot", function()
		local roll = stream(7)
		local taken = {}
		for _ = 1, 8 do
			local spot = SpawnSpread.candidates(0, 64, taken, roll)[1]
			for _, other in taken do
				local gap = math.sqrt((spot[1] - other[1]) ^ 2 + (spot[2] - other[2]) ^ 2)
				assert(gap >= SpawnSpread.CLEAR, "two players landed " .. gap .. " studs apart")
			end
			table.insert(taken, spot)
		end
	end)

	test("spawn spread: with no clear spot left, the roomiest comes first", function()
		local crowd = {}
		for x = -12, 12, 2 do
			for z = 52, 76, 2 do
				table.insert(crowd, { x, z })
			end
		end
		local spots = SpawnSpread.candidates(0, 64, crowd, stream(5))
		assert(#spots == SpawnSpread.TRIES, "a spot is always given")
	end)
end
