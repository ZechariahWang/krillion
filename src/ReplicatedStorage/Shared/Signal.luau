--!strict
-- A tiny synchronous signal for server-side match events. No Roblox APIs, so Lune tests can require it.
-- fire() calls every handler in order inside pcall, so one broken handler never stops the others.
-- Handlers run on the firing thread: a handler that yields (DataStores, waits) must task.spawn itself,
-- or it holds up the match loop that fired it.

export type Signal = {
	connect: (fn: (...any) -> ()) -> () -> (), -- returns a disconnect function
	fire: (...any) -> { string }, -- returns the errors raised by handlers (also reported)
	count: () -> number,
}

local Signal = {}

-- Where handler errors go. Lune and Roblox both have warn; tests may swap this for a quiet one.
Signal.report = function(message: string)
	warn(message)
end

function Signal.new(name: string?): Signal
	local label = name or "Signal"
	local handlers: { (...any) -> () } = {}

	local function connect(fn: (...any) -> ()): () -> ()
		table.insert(handlers, fn)
		local connected = true
		return function()
			if not connected then
				return
			end
			connected = false
			local index = table.find(handlers, fn)
			if index ~= nil then
				table.remove(handlers, index)
			end
		end
	end

	local function fire(...: any): { string }
		local errors = {}
		-- A snapshot, so handlers that connect or disconnect during the fire do not skip anyone.
		local snapshot = table.clone(handlers)
		for _, handler in snapshot do
			local ok, err = pcall(handler, ...)
			if not ok then
				local message = label .. " handler failed: " .. tostring(err)
				table.insert(errors, message)
				Signal.report(message)
			end
		end
		return errors
	end

	local function count(): number
		return #handlers
	end

	return {
		connect = connect,
		fire = fire,
		count = count,
	}
end

return Signal
