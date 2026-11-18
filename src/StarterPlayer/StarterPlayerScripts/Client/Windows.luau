--!strict
-- One pop-up window at a time (Shop, Inventory, Rewards, Help, Settings). A controller opening its
-- window passes its close function; the window open before is closed. While any window is open the rail, the
-- top buttons, the status chips and the Shells chip hide, so nothing stacks: they watch Windows.Changed.
-- The full-screen dive card is not a window, but while it covers the screen (Windows.cover) the status chips and
-- the Shells chip hide too, so the card has the whole screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Windows = {}

Windows.Changed = Signal.new("Windows")

export type Options = {
	keepStatus: boolean?, -- the status chips stay up under this window (the warm-up quiz keeps the countdown)
}

local openClose: (() -> ())? = nil
local openKeepsStatus = false
local isCovered = false

-- The dive card covers the screen (true) or has left it (false).
function Windows.cover(on: boolean)
	if isCovered ~= on then
		isCovered = on
		Windows.Changed.fire()
	end
end

function Windows.covered(): boolean
	return isCovered
end

function Windows.anyOpen(): boolean
	return openClose ~= nil
end

function Windows.hidesStatus(): boolean
	return isCovered or (openClose ~= nil and not openKeepsStatus)
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
