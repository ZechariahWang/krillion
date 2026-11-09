--!strict
-- One pop-up window at a time (Shop, Inventory, Quests, Rewards, Help, Settings). A controller opening its
-- window passes its close function; the window open before is closed. While any window is open the rail, the
-- top buttons, the status chips and the Shells chip hide, so nothing stacks: they watch Windows.Changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Windows = {}

Windows.Changed = Signal.new("Windows")

export type Options = {
	keepStatus: boolean?, -- the status chips stay up under this window (the warm-up quiz keeps the countdown)
}

local openClose: (() -> ())? = nil
local openKeepsStatus = false

function Windows.anyOpen(): boolean
	return openClose ~= nil
end

function Windows.hidesStatus(): boolean
	return openClose ~= nil and not openKeepsStatus
end

function Windows.opened(close: () -> (), options: Options?)
	local previous = openClose
	openClose = close
	openKeepsStatus = options ~= nil and options.keepStatus == true
	if previous ~= nil and previous ~= close then
		previous()
	end
	if previous ~= close then
		Windows.Changed.fire()
	end
end

-- Closes whatever is open (a death, a match starting).
function Windows.closeAll()
	local close = openClose
	if close ~= nil then
		close()
		Windows.closed(close)
	end
end

function Windows.closed(close: () -> ())
	if openClose == close then
		openClose = nil
		openKeepsStatus = false
		Windows.Changed.fire()
	end
end

return Windows
