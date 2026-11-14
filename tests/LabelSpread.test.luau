local LabelSpread = require("../src/ReplicatedStorage/Shared/LabelSpread")

local GAP = 4

local function box(x: number, y: number, width: number, height: number, depth: number)
	return { x = x, y = y, width = width, height = height, depth = depth }
end

-- Whether two boxes overlap once each is lifted (moved up the screen) by its own amount.
local function overlap(a, liftA: number, b, liftB: number): boolean
	local aTop = a.y - liftA
	local bTop = b.y - liftB
	if a.x + a.width <= b.x or b.x + b.width <= a.x then
		return false
	end
	if aTop + a.height <= bTop or bTop + b.height <= aTop then
		return false
	end
	return true
end

local function anyOverlap(boxes, lifts): boolean
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			if overlap(boxes[i], lifts[i], boxes[j], lifts[j]) then
				return true
			end
		end
	end
	return false
end

return function(test)
	test("LabelSpread: boxes that do not overlap are left alone", function()
		local boxes = { box(0, 0, 100, 40, 10), box(200, 0, 100, 40, 20), box(0, 100, 100, 40, 30) }
		local lifts = LabelSpread.lifts(boxes, GAP)
		assert(lifts[1] == 0 and lifts[2] == 0 and lifts[3] == 0)
	end)

	test("LabelSpread: of two overlapping boxes the nearer stays and the farther is lifted clear", function()
		local boxes = { box(0, 100, 100, 40, 50), box(50, 110, 100, 40, 10) }
		local lifts = LabelSpread.lifts(boxes, GAP)
		assert(lifts[2] == 0, "the nearer box moved")
		assert(lifts[1] > 0, "the farther box did not move")
		assert(not anyOverlap(boxes, lifts))
		-- Lifted just clear of the nearer box, with the gap between them.
		assert(boxes[1].y - lifts[1] + boxes[1].height == boxes[2].y - GAP)
	end)

	test("LabelSpread: a chain of three ends with none overlapping", function()
		local boxes = { box(0, 100, 100, 40, 10), box(40, 95, 100, 40, 20), box(80, 90, 100, 40, 30) }
		local lifts = LabelSpread.lifts(boxes, GAP)
		assert(lifts[1] == 0)
		assert(not anyOverlap(boxes, lifts))
	end)

	test("LabelSpread: a lifted box that lands on a third is lifted again", function()
		-- The far box is pushed off the near one straight into the middle one sitting above it.
		local boxes = { box(0, 100, 100, 40, 10), box(0, 50, 100, 40, 20), box(0, 110, 100, 40, 30) }
		local lifts = LabelSpread.lifts(boxes, GAP)
		assert(not anyOverlap(boxes, lifts))
	end)

	test("LabelSpread: the same boxes give the same lifts, and equal depths do not swap", function()
		local boxes = { box(0, 100, 100, 40, 10), box(50, 100, 100, 40, 10) }
		local first = LabelSpread.lifts(boxes, GAP)
		local second = LabelSpread.lifts(boxes, GAP)
		assert(first[1] == second[1] and first[2] == second[2])
		assert(first[1] == 0, "with equal depths the earlier box stays put")
	end)
end
