local Signal = require("../src/ReplicatedStorage/Shared/Signal")

-- Handler errors are expected in some cases here, so keep the output quiet while each case runs.
local function quietly(fn: () -> ())
	local report = Signal.report
	Signal.report = function() end
	local ok, err = pcall(fn)
	Signal.report = report
	if not ok then
		error(err, 0)
	end
end

return function(test)
	test("fire passes every argument to every handler, in connect order", function()
		local signal = Signal.new()
		local seen = {}
		signal.connect(function(a, b)
			table.insert(seen, "first " .. a .. " " .. b)
		end)
		signal.connect(function(a, b)
			table.insert(seen, "second " .. a .. " " .. b)
		end)
		signal.fire("x", 2)
		assert(seen[1] == "first x 2" and seen[2] == "second x 2", "got " .. table.concat(seen, ", "))
	end)

	test("a disconnected handler is not called again, and disconnecting twice is harmless", function()
		local signal = Signal.new()
		local calls = 0
		local disconnect = signal.connect(function()
			calls += 1
		end)
		signal.fire()
		disconnect()
		disconnect()
		signal.fire()
		assert(calls == 1, "got " .. calls)
		assert(signal.count() == 0)
	end)

	test("an error in one handler does not stop the others and is returned", function()
		quietly(function()
			local signal = Signal.new("Test")
			local reached = false
			signal.connect(function()
				error("boom")
			end)
			signal.connect(function()
				reached = true
			end)
			local errors = signal.fire()
			assert(reached)
			assert(#errors == 1 and string.find(errors[1], "boom") ~= nil)
		end)
	end)

	test("a handler that disconnects itself during a fire does not skip the next one", function()
		local signal = Signal.new()
		local order = {}
		local disconnect
		disconnect = signal.connect(function()
			table.insert(order, 1)
			disconnect()
		end)
		signal.connect(function()
			table.insert(order, 2)
		end)
		signal.fire()
		signal.fire()
		assert(#order == 3 and order[1] == 1 and order[2] == 2 and order[3] == 2)
	end)
end
