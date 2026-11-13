--!strict
-- Keeps head labels from overlapping on screen. Given each label's screen box and how far it is from the
-- camera, it says how many pixels to lift each one: the nearest label stays put and each farther one is
-- raised until it clears every label already placed. No Roblox APIs here.

export type Box = {
	x: number, -- left edge, pixels
	y: number, -- top edge, pixels (down the screen)
	width: number,
	height: number,
	depth: number, -- distance from the camera
}

local LabelSpread = {}

local function overlaps(a: Box, aTop: number, b: Box, bTop: number): boolean
	if a.x + a.width <= b.x or b.x + b.width <= a.x then
		return false
	end
	if aTop + a.height <= bTop or bTop + b.height <= aTop then
		return false
	end
	return true
end

-- The lift for each box, in the order given. `gap` is the space left between two boxes that were touching.
function LabelSpread.lifts(boxes: { Box }, gap: number): { number }
	local order: { number } = {}
	for index = 1, #boxes do
		table.insert(order, index)
	end
	table.sort(order, function(a: number, b: number): boolean
		if boxes[a].depth ~= boxes[b].depth then
			return boxes[a].depth < boxes[b].depth
		end
		return a < b
	end)

	local lifts: { number } = table.create(#boxes, 0)
	local placed: { number } = {}
	for _, index in order do
		local box = boxes[index]
		local top = box.y
		-- Each pass moves the box up past one placed box, so it ends after at most one pass per placed box.
		local moved = true
		while moved do
			moved = false
			for _, other in placed do
				local otherBox = boxes[other]
				local otherTop = otherBox.y - lifts[other]
				if overlaps(box, top, otherBox, otherTop) then
					top = otherTop - gap - box.height
					moved = true
				end
			end
		end
		lifts[index] = box.y - top
		table.insert(placed, index)
	end
	return lifts
end

return LabelSpread
