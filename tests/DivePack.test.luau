local DivePack = require("../src/ReplicatedStorage/Shared/DivePack")

-- A small repeatable random stream, so a failing pack can be reproduced.
local function stream(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function randomDepths(random: () -> number, count: number): { number }
	local depths = {}
	for index = 1, count do
		-- A third have no answer (the surface); the rest fall anywhere down to the bottom.
		depths[index] = if random() < 0.33 then 0 else math.floor(10 + random() * 550)
	end
	return depths
end

return function(test)
	test("softMin follows the lower value and rounds the corner without ever passing either", function()
		assert(DivePack.softMin(10, 100, 20) == 10)
		assert(DivePack.softMin(200, 100, 20) == 100)
		assert(DivePack.softMin(120, 100, 20) == 100, "it has come to rest once the pack is `k` past")
		assert(DivePack.softMin(5, 9, 0) == 5)
		local previous = -math.huge
		for a = 60, 140 do
			local value = DivePack.softMin(a, 100, 20)
			assert(value <= math.min(a, 100) + 1e-9, "above the minimum at " .. a)
			assert(value >= previous - 1e-9, "it went back up at " .. a)
			previous = value
		end
	end)

	test("with a lane each, every tag rests at its own depth and yours takes the middle", function()
		local slots = DivePack.layout({ 120, 30, 480, 30 }, 4, 40, 1)
		local used = {}
		for index, slot in slots do
			assert(slot.row == 0)
			assert(slot.final == ({ 120, 30, 480, 30 })[index])
			assert(used[slot.lane] == nil, "two tags share lane " .. slot.lane)
			used[slot.lane] = true
		end
		assert(slots[1].lane == 2, "your lane is " .. slots[1].lane)
	end)

	test("a crowded lane pushes its deeper tags down, never up, and rows count up from the deepest", function()
		local random = stream(7)
		for _ = 1, 200 do
			local count = 1 + math.floor(random() * 16)
			local lanes = 1 + math.floor(random() * 4)
			local spacing = 20 + random() * 30
			local depths = randomDepths(random, count)
			local own = 1 + math.floor(random() * count)
			local slots = DivePack.layout(depths, lanes, spacing, own)
			assert(#slots == count)
			local byLane: { [number]: { { depth: number, slot: DivePack.Slot } } } = {}
			for index, slot in slots do
				assert(slot.lane >= 1 and slot.lane <= lanes)
				assert(slot.final >= depths[index] - 1e-9, "a tag rests above its depth")
				byLane[slot.lane] = byLane[slot.lane] or {}
				table.insert(byLane[slot.lane], { depth = depths[index], slot = slot })
			end
			for _, members in byLane do
				table.sort(members, function(a, b)
					return a.slot.row < b.slot.row
				end)
				for position, member in members do
					assert(member.slot.row == position - 1, "rows are not 0, 1, 2...")
					local behind = members[position + 1]
					if behind ~= nil then
						assert(member.slot.final >= behind.slot.final + spacing - 1e-6, "two tags rest too close")
						assert(member.depth >= behind.depth, "a shallower answer is in front")
					end
				end
			end
		end
	end)

	test("tags spread over the lanes before any lane takes a second one", function()
		local slots = DivePack.layout({ 20, 22, 24, 26, 28, 30 }, 3, 40, nil)
		local sizes = { 0, 0, 0 }
		for _, slot in slots do
			sizes[slot.lane] += 1
		end
		assert(sizes[1] == 2 and sizes[2] == 2 and sizes[3] == 2)
	end)

	test("the front drifts onto the water, then sinks to its reach without ever going back", function()
		assert(DivePack.front(0, 0.3, 4, 500, 60) == -60)
		assert(math.abs(DivePack.front(0.3, 0.3, 4, 500, 60)) < 1e-9)
		assert(DivePack.front(4.3, 0.3, 4, 500, 60) == 500)
		assert(DivePack.front(9, 0.3, 4, 500, 60) == 500)
		local previous = -math.huge
		for step = 0, 430 do
			local value = DivePack.front(step / 100, 0.3, 4, 500, 60)
			assert(value >= previous - 1e-9, "the front went back up")
			previous = value
		end
		-- No jolt where the drop meets the sink: it is all but still either side of the surface.
		assert(math.abs(DivePack.front(0.31, 0.3, 4, 500, 60) - DivePack.front(0.29, 0.3, 4, 500, 60)) < 1)
	end)

	test("no two tags in a lane ever come closer than the spacing, and every tag ends on its resting place", function()
		local random = stream(11)
		for _ = 1, 120 do
			local count = 1 + math.floor(random() * 16)
			local lanes = 1 + math.floor(random() * 4)
			local spacing = 20 + random() * 30
			local soft = 8 + random() * 30
			local depths = randomDepths(random, count)
			local slots = DivePack.layout(depths, lanes, spacing, 1)
			local reach = DivePack.reach(slots, soft)
			local drop, sink, sky = 0.3, 1 + random() * 4, 60
			local last: { number } = {}
			local previousFront = -sky
			-- The front never covers more than this in one step: its top speed, in the drop or at the end of the sink.
			local stride = math.max(2 * sky / drop, 1.7 * reach / sink) * (drop + sink) / 200 + 1e-6
			for step = 0, 200 do
				local elapsed = (drop + sink) * step / 200
				local front = DivePack.front(elapsed, drop, sink, reach, sky)
				assert(front - previousFront <= stride, "the front jumped " .. (front - previousFront))
				for index, slot in slots do
					local position = DivePack.position(front, slot, spacing, soft)
					assert(position <= slot.final + 1e-6, "a tag sank past its resting place")
					assert(last[index] == nil or position >= last[index] - 1e-6, "a tag moved back up")
					assert(last[index] == nil or position - last[index] <= front - previousFront + 1e-6, "a tag jumped ahead of the pack")
					last[index] = position
					for other = 1, index - 1 do
						if slots[other].lane == slot.lane then
							local gap = math.abs(position - DivePack.position(front, slots[other], spacing, soft))
							assert(gap >= spacing - 1e-6, "tags overlap: gap " .. gap .. " of " .. spacing)
						end
					end
				end
				previousFront = front
			end
			local front = DivePack.front(drop + sink, drop, sink, reach, sky)
			for _, slot in slots do
				assert(math.abs(DivePack.position(front, slot, spacing, soft) - slot.final) < 1e-6, "a tag stopped short")
				assert(DivePack.landed(front, slot, spacing, soft))
			end
		end
	end)

	test("other tags keep out of your lane while another lane costs them little", function()
		-- Six shallow answers and yours on three lanes: the others pair up at the sides and yours rests alone.
		local slots = DivePack.layout({ 60, 20, 22, 24, 26, 28, 30 }, 3, 40, 1)
		assert(slots[1].lane == 2 and slots[1].row == 0 and slots[1].final == 60)
		for index = 2, #slots do
			assert(slots[index].lane ~= 2, "tag " .. index .. " joined your lane")
		end
		-- With two lanes there is no lane to spare, so they share.
		local shared = DivePack.layout({ 60, 20, 22, 24 }, 2, 40, 1)
		local inYours = 0
		for index = 2, #shared do
			if shared[index].lane == shared[1].lane then
				inYours += 1
			end
		end
		assert(inYours >= 1)
	end)

	test("squeezing the drop and the sink by one pace makes the last tag land on the budget", function()
		local depths = { 559, 560, 40, 300 }
		local spacing, soft, drop, sink = 38, 36, 0.32, 4.8
		local slots = DivePack.layout(depths, 4, spacing, 1)
		local reach = DivePack.reach(slots, soft)
		local last = 0
		for _, slot in slots do
			last = math.max(last, DivePack.landSeconds(slot, spacing, soft, drop, sink, reach))
		end
		local budget, delay = 5, 0.2
		assert(delay + last > budget, "this pack needs no squeeze")
		local pace = (budget - delay) / last
		local squeezed = 0
		for _, slot in slots do
			squeezed = math.max(squeezed, DivePack.landSeconds(slot, spacing, soft, drop * pace, sink * pace, reach))
		end
		assert(math.abs(delay + squeezed - budget) < 1e-6, "lands at " .. (delay + squeezed))
	end)

	test("landSeconds is the moment landed turns true, and the deepest tag lands before the pack stops", function()
		local depths = { 12, 140, 300, 512, 0, 141 }
		local spacing, soft, drop, sink, sky = 38, 30, 0.3, 4.5, 60
		local slots = DivePack.layout(depths, 3, spacing, 1)
		local reach = DivePack.reach(slots, soft)
		for _, slot in slots do
			local at = DivePack.landSeconds(slot, spacing, soft, drop, sink, reach)
			assert(at <= drop + sink + 1e-9)
			assert(DivePack.landed(DivePack.front(at + 0.01, drop, sink, reach, sky), slot, spacing, soft))
			if at > drop + 0.02 then
				assert(not DivePack.landed(DivePack.front(at - 0.01, drop, sink, reach, sky), slot, spacing, soft))
			end
		end
	end)
end
