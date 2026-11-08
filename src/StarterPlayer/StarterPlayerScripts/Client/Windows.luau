--!strict
-- One pop-up window at a time (Shop, Inventory, Quests, Rewards, Help, Settings). A controller opening its
-- window passes its close function; the window open before is closed. While any window is open the rail, the
-- top buttons, the status chips and the Shells chip hide, so nothing stacks: they watch Windows.Changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Windows = {}

Windows.Changed = Signal.new("Windows")

local openClose: (() -> ())? = nil

function Windows.anyOpen(): boolean
	return openClose ~= nil
end

function Windows.opened(close: () -> ())
	local previous = openClose
	openClose = close
	if previous ~= nil and previous ~= close then
		previous()
	end
	if previous ~= close then
		Windows.Changed.fire()
	end
end

function Windows.closed(close: () -> ())
	if openClose == close then
		openClose = nil
		Windows.Changed.fire()
	end
end

return Windows
