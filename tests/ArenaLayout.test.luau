local ArenaLayout = require("../src/ReplicatedStorage/Shared/ArenaLayout")
local GameConfig = require("../src/ReplicatedStorage/Config/GameConfig")

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

return function(test)
	test("a single platform sits in the centre", function()
		local x, z = ArenaLayout.position(1, 1)
		assert(x == 0 and z == 0)
	end)

	test("platforms never sit closer than the minimum spacing", function()
		for count = 2, GameConfig.Server.MaxPlayers do
			local points = {}
			for index = 1, count do
				local x, z = ArenaLayout.position(index, count)
				table.insert(points, { x, z })
			end
			for a = 1, count do
				for b = a + 1, count do
					local gap = distance(points[a][1], points[a][2], points[b][1], points[b][2])
					assert(gap >= GameConfig.Platform.Spacing - 1e-6, count .. " players: gap " .. gap)
				end
			end
		end
	end)

	test("every platform fits inside the arena", function()
		local count = GameConfig.Server.MaxPlayers
		for index = 1, count do
			local x, z = ArenaLayout.position(index, count)
			assert(distance(x, z, 0, 0) <= GameConfig.Platform.RingMaxRadius + 1e-6)
		end
	end)

	test("a small match stays tight instead of using the full ring", function()
		local x, z = ArenaLayout.position(1, 3)
		local bigX, bigZ = ArenaLayout.position(1, GameConfig.Server.MaxPlayers)
		assert(distance(x, z, 0, 0) < distance(bigX, bigZ, 0, 0))
	end)
end
