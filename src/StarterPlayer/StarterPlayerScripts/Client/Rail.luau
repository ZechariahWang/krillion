--!strict
-- Drives LobbyUi.Rail: the column of chunky square keys at the left edge (QUESTS, REWARDS, SHOP, HELP), each
-- with an icon, a label and a "!" badge. It shows only in the lobby, off a pillar, and hides while the shop
-- window is open. On short screens (landscape phones) the keys wrap into two columns and RailFrame.Fit
-- shrinks them to fit.
-- Each button belongs to its own controller: Quests, Rewards, ShopUi and Tutorial call Rail.button(name) to connect
-- it and Rail.setBadge(name, text) to mark it, so this module never needs to know them.

local Ui = require(script.Parent.Ui)

local BUTTONS = { "QuestsButton", "RewardsButton", "ShopButton", "HelpButton" }
local WAIT_SECONDS = 10
local HEIGHT_SHARE = 0.62 -- the most of the screen height the rail may take
local MIN_FIT = 0.45
local TWO_COLUMNS_BELOW = 0.7 -- a single column shrunk below this wraps into two columns instead

local gui: Frame? = nil
local shopPanel: GuiObject? = nil
local railFrame: GuiObject? = nil
local layout: UIListLayout? = nil
local fit: UIScale? = nil
local edgeWidth = 0 -- authored frame width beyond one key (room for the badge)
local buttons: { [string]: TextButton } = {}
local playing = false
local openPanel: (() -> ())? = nil -- closes the rail panel that is open now

local Rail = {}

local function visibleKeys(frame: GuiObject): (number, number)
	local count = 0
	local keySize = 0
	for _, child in frame:GetChildren() do
		if child:IsA("TextButton") and child.Visible then
			count += 1
			keySize = math.max(keySize, child.Size.Y.Offset)
		end
	end
	return count, keySize
end

-- Height of `rows` keys stacked with the layout's gap between them.
local function stackHeight(rows: number, keySize: number, gap: number): number
	return rows * keySize + math.max(rows - 1, 0) * gap
end

-- Sizes the rail to its visible keys in one column, or two on short screens (landscape phones), then
-- shrinks it to fit the screen height. The list layout wraps the keys into the second column.
local function fitToScreen()
	local screen = gui
	local frame = railFrame
	local list = layout
	local scale = fit
	if screen == nil or frame == nil or list == nil or scale == nil then
		return
	end
	local available = screen.AbsoluteSize.Y * HEIGHT_SHARE
	local count, keySize = visibleKeys(frame)
	if available <= 0 or count == 0 then
		return
	end
	local gap = list.Padding.Offset
	local columns = 1
	local rows = count
	local height = stackHeight(rows, keySize, gap)
	if available / height < TWO_COLUMNS_BELOW and count > 1 then
		columns = 2
		rows = math.ceil(count / 2)
		height = stackHeight(rows, keySize, gap)
	end
	local width = stackHeight(columns, keySize, gap) + edgeWidth
	list.Wraps = columns > 1
	frame.Size = UDim2.fromOffset(width, height)
	scale.Scale = math.clamp(available / height, MIN_FIT, 1)
end

local function refresh()
	local screen = gui
	if screen == nil then
		return
	end
	local shopOpen = shopPanel ~= nil and (shopPanel :: GuiObject).Visible
	screen.Visible = not playing and not shopOpen
	if screen.Visible then
		fitToScreen()
	end
end

function Rail.init(playerGui: PlayerGui)
	local found = Ui.screen(playerGui, "Rail", WAIT_SECONDS)
	if found == nil or not found:IsA("Frame") then
		warn("Rail: StarterGui.Rail is missing; the side rail stays hidden")
		return
	end
	gui = found
	local frame = found:WaitForChild("RailFrame", WAIT_SECONDS)
	if frame ~= nil and frame:IsA("GuiObject") then
		railFrame = frame
		local scale = frame:FindFirstChild("Fit")
		fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
		local list = frame:FindFirstChildOfClass("UIListLayout")
		layout = list
		local _, keySize = visibleKeys(frame)
		edgeWidth = math.max(frame.Size.X.Offset - keySize, 0)
		found:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
		for _, child in frame:GetChildren() do
			if child:IsA("TextButton") then
				child:GetPropertyChangedSignal("Visible"):Connect(fitToScreen)
			end
		end
		fitToScreen()
		for _, name in BUTTONS do
			local button = frame:FindFirstChild(name)
			if button ~= nil and button:IsA("TextButton") then
				buttons[name] = button
				Ui.pressable(button)
			end
		end
	end
	-- The shop is bound by ShopUi; this only watches whether its window is open.
	task.spawn(function()
		local shop = Ui.screen(playerGui, "Shop", WAIT_SECONDS)
		local panel = if shop ~= nil then shop:WaitForChild("Panel", WAIT_SECONDS) else nil
		if panel ~= nil and panel:IsA("GuiObject") then
			shopPanel = panel
			panel:GetPropertyChangedSignal("Visible"):Connect(refresh)
		end
		refresh()
	end)
	refresh()
end

-- The rail button with this name ("QuestsButton" | "RewardsButton" | "HelpButton"), or nil if not authored.
function Rail.button(name: string): TextButton?
	return buttons[name]
end

-- Shows the red badge on a key ("!" or "1/3"); nil hides it.
function Rail.setBadge(name: string, text: string?)
	local button = buttons[name]
	if button == nil then
		return
	end
	local badge = button:FindFirstChild("Badge")
	if badge == nil or not badge:IsA("TextLabel") then
		return
	end
	if text == nil then
		badge.Visible = false
		return
	end
	badge.Text = text
	if not badge.Visible then
		Ui.pop(badge)
	end
end

-- One rail panel open at a time: a controller opening its panel passes its close function, and the
-- panel that was open before is closed. Rail.panelClosed(close) forgets it again.
function Rail.panelOpened(close: () -> ())
	local previous = openPanel
	openPanel = close
	if previous ~= nil and previous ~= close then
		previous()
	end
end

function Rail.panelClosed(close: () -> ())
	if openPanel == close then
		openPanel = nil
	end
end

function Rail.onState(payload)
	playing = payload.playing == true
	refresh()
end

return Rail
