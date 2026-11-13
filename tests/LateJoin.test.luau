local LateJoin = require("../src/ReplicatedStorage/Shared/LateJoin")
local ArenaLayout = require("../src/ReplicatedStorage/Shared/ArenaLayout")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local CFG = { Enabled = 1, MaxRound = 2, MinSecondsLeft = 8, ReserveSlots = 4 }
local OFF = { Enabled = 0, MaxRound = 2, MinSecondsLeft = 8, ReserveSlots = 4 }

local function ctx(overrides: { [string]: boolean }?): LateJoin.Context
	local base: LateJoin.Context = {
		enabled = true,
		matchRunning = true,
		played = false,
		windowOpen = true,
		hasRoom = true,
		ready = true,
	}
	for key, value in overrides or {} do
		(base :: any)[key] = value
	end
	return base
end

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- The starting ring for `count` players, exactly as MapService lays it out.
local function startingRing(count: number): { { number } }
	local taken = {}
	for index = 1, count do
		local x, z = ArenaLayout.position(index, count)
		table.insert(taken, { x, z })
	end
	return taken
end

return function(test)
	test("late join: slotCount adds the reserve, clamps to the server size, and is off when disabled", function()
		assert(LateJoin.slotCount(2, CFG, 12) == 6)
		assert(LateJoin.slotCount(10, CFG, 12) == 12)
		assert(LateJoin.slotCount(12, CFG, 12) == 12)
		assert(LateJoin.slotCount(3, OFF, 12) == 3)
	end)

	test("late join: round 1 is open in every match phase", function()
		assert(LateJoin.windowOpen("Prompt", 1, 20, CFG))
		assert(LateJoin.windowOpen("Prompt", 1, 1, CFG))
		assert(LateJoin.windowOpen("Reveal", 1, 0, CFG))
		assert(LateJoin.windowOpen("Surge", 1, 0, CFG))
		assert(not LateJoin.windowOpen("Intermission", 0, 10, CFG))
		assert(not LateJoin.windowOpen("Results", 1, 10, CFG))
	end)

	test("late join: the last round is open only in its prompt with enough time left", function()
		assert(LateJoin.windowOpen("Prompt", 2, 9, CFG))
		assert(LateJoin.windowOpen("Prompt", 2, 8, CFG))
		assert(not LateJoin.windowOpen("Prompt", 2, 7, CFG))
		assert(not LateJoin.windowOpen("Reveal", 2, 9, CFG))
		assert(not LateJoin.windowOpen("Prompt", 3, 20, CFG))
		assert(not LateJoin.windowOpen("Prompt", 1, 20, OFF))
	end)

	test("late join: joinHeight is StartHeight over the water or the lowest alive pillar", function()
		assert(LateJoin.joinHeight(2, 6, nil) == 8)
		assert(LateJoin.joinHeight(2, 6, 5) == 8)
		assert(LateJoin.joinHeight(2, 6, 14) == 14)
	end)

	test("late join: canJoin gives each status in order", function()
		assert(LateJoin.canJoin(ctx()) == "joined")
		assert(LateJoin.canJoin(ctx({ enabled = false })) == "closed")
		assert(LateJoin.canJoin(ctx({ matchRunning = false, played = true })) == "closed")
		assert(LateJoin.canJoin(ctx({ played = true, windowOpen = false })) == "already")
		assert(LateJoin.canJoin(ctx({ windowOpen = false, hasRoom = false })) == "closed")
		assert(LateJoin.canJoin(ctx({ hasRoom = false, ready = false })) == "full")
		assert(LateJoin.canJoin(ctx({ ready = false })) == "not_ready")
		for status in LateJoin.Messages do
			assert(type(LateJoin.Messages[status]) == "string")
		end
	end)

	test("late join: a solo player keeps the centre and joiners ring it at the minimum spacing", function()
		local taken = startingRing(1)
		assert(taken[1][1] == 0 and taken[1][2] == 0)
		local x, z = LateJoin.spot(taken, GameConfig.Platform.Spacing, GameConfig.Platform.RingMaxRadius)
		assert(x ~= nil and z ~= nil)
		assert(math.abs(distance(x, z, 0, 0) - GameConfig.Platform.Spacing) < 1e-6)
		table.insert(taken, { x, z })
		-- The next joiner goes opposite the first, not next to it.
		local x2, z2 = LateJoin.spot(taken, GameConfig.Platform.Spacing, GameConfig.Platform.RingMaxRadius)
		assert(x2 ~= nil and z2 ~= nil)
		assert(distance(x2, z2, x, z) > 2 * GameConfig.Platform.Spacing - 1e-6)
	end)

	test("late join: spots never crowd a pillar or leave the arena, and small matches fit every reserved joiner", function()
		local spacing = GameConfig.Platform.Spacing
		local maxRadius = GameConfig.Platform.RingMaxRadius
		for starting = 1, GameConfig.Server.MaxPlayers - 1 do
			local taken = startingRing(starting)
			local wanted = LateJoin.slotCount(starting, GameConfig.LateJoin, GameConfig.Server.MaxPlayers) - starting
			local placed = 0
			for _ = 1, wanted do
				local x, z = LateJoin.spot(taken, spacing, maxRadius)
				if x == nil or z == nil then
					break
				end
				assert(distance(x, z, 0, 0) <= maxRadius + 1e-6, "outside the arena")
				for _, point in taken do
					assert(distance(x, z, point[1], point[2]) >= spacing - 1e-6, starting .. " starters: crowded")
				end
				table.insert(taken, { x, z })
				placed += 1
			end
			if starting <= 4 then
				assert(placed == wanted, starting .. " starters: only " .. placed .. " of " .. wanted .. " joiners fit")
			end
		end
	end)

	test("late join: a full arena has no spot", function()
		local x, z = LateJoin.spot({ { 0, 0 } }, 16, 10)
		assert(x == nil and z == nil)
	end)
end
