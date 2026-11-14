local Schooling = require("../src/ReplicatedStorage/Shared/Schooling")

local ON = { Enabled = 1, Factor = 0.5 }
local OFF = { Enabled = 0, Factor = 0.5 }

return function(test)
	test("schooling: sizes counts how many gave each answer, ignoring case", function()
		local sizes = Schooling.sizes({ [1] = "Shark", [2] = "shark", [3] = "Krill", [4] = "SHARK" })
		assert(sizes[1] == 3 and sizes[2] == 3 and sizes[4] == 3)
		assert(sizes[3] == 1)
		assert(next(Schooling.sizes({})) == nil)
	end)

	test("schooling: a shared answer is worth Factor of its points, rounded down", function()
		assert(Schooling.apply(60, 2, ON) == 30)
		assert(Schooling.apply(45, 3, ON) == 22)
		assert(Schooling.apply(60, 1, ON) == 60)
		assert(Schooling.apply(60, nil, ON) == 60)
		assert(Schooling.applies(2, ON))
		assert(not Schooling.applies(1, ON))
	end)

	test("schooling: disabled leaves points unchanged", function()
		assert(Schooling.apply(60, 4, OFF) == 60)
		assert(not Schooling.applies(4, OFF))
	end)
end
