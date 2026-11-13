--!strict
-- Drives LobbyUi.Rail: the column of chunky square keys at the left edge (QUESTS, REWARDS, SHOP, STORE, ITEMS), each
-- with an icon, a label and a "!" badge, the HELP circle on the top bar next to the Settings gear, and the
-- small THROW key at the right edge. It
-- shows only in the lobby, off a pillar, and hides while any window is open. On short screens (landscape
-- phones) the keys wrap into two columns and RailFrame.Fit shrinks them to fit.
-- Each button belongs to its own controller: Quests, Rewards, ShopUi and Tutorial call Rail.button(name) to connect
-- it and Rail.setBadge(name, text) to mark it, so this module never needs to know them.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local BUTTONS = { "QuestsButton", "RewardsButton", "ShopButton", "StoreButton", "InventoryButton" }
local HELP_SLOT = 1 -- top bar place right of the Settings gear
local WATCH_SLOT = 2 -- the spectate eye, right of Help
local WAIT_SECONDS = 10
local HEIGHT_SHARE = 0.62 -- the most of the screen height the rail may take
local MIN_FIT = 0.45
-- One column shrunk below TWO_COLUMNS_BELOW wraps into two; two columns go back to one only above
-- ONE_COLUMN_ABOVE, so a screen near the threshold never flips back and forth.
local TWO_COLUMNS_BELOW = 0.62
local ONE_COLUMN_ABOVE = 0.85
local JITTER = 4 -- pixels of screen height change that do not count as a resize
local TOUCH_FIT = 0.58 -- phones: the keys at this scale, always two columns, laid out once

local gui: Frame? = nil
local railFrame: GuiObject? = nil
local layout: UIListLayout? = nil
local fit: UIScale? = nil
local edgeWidth = 0 -- authored frame width beyond one key (room for the badge)
local buttons: { [string]: TextButton } = {}
local playing = false
local phase = ""
local columns = 1
local lastHeight = 0
local lastCount = 0

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
	local screenHeight = screen.AbsoluteSize.Y
	local count, keySize = visibleKeys(frame)
	if screenHeight <= 0 or count == 0 then
		return
	end
	local gap = list.Padding.Offset
	if UserInputService.TouchEnabled then
		-- Phones: the list layout is off and every key gets a fixed slot in two columns, so nothing can
		-- re-wrap. Laid out again only when the set of visible keys changes.
		if count == lastCount then
			return
		end
		lastCount = count
		columns = 2
		list.Parent = nil -- a UIListLayout has no off switch; out of the frame it lays out nothing
		local index = 0
		for _, child in frame:GetChildren() do
			if child:IsA("TextButton") and child.Visible then
				local column = index % 2
				local row = math.floor(index / 2)
				child.Position = UDim2.fromOffset(column * (keySize + gap), row * (keySize + gap))
				index += 1
			end
		end
		local rows = math.ceil(count / 2)
		frame.Size = UDim2.fromOffset(stackHeight(2, keySize, gap) + edgeWidth, stackHeight(rows, keySize, gap))
		scale.Scale = TOUCH_FIT
		return
	end
	list.Parent = frame
	if math.abs(screenHeight - lastHeight) < JITTER and count == lastCount then
		return
	end
	lastHeight = screenHeight
	lastCount = count
	local available = screenHeight * HEIGHT_SHARE
	local oneColumn = available / stackHeight(count, keySize, gap)
	if count < 2 then
		columns = 1
	elseif columns == 1 and oneColumn < TWO_COLUMNS_BELOW then
		columns = 2
	elseif columns == 2 and oneColumn > ONE_COLUMN_ABOVE then
		columns = 1
	end
	local rows = math.ceil(count / columns)
	local height = stackHeight(rows, keySize, gap)
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
	screen.Visible = not playing and phase ~= "Results" and not Windows.anyOpen()
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
	-- The THROW key (Market shows it with a toy equipped) sits at the right edge, above the Shells chip.
	local toy = found:FindFirstChild("ToyButton")
	if toy ~= nil and toy:IsA("TextButton") then
		buttons.ToyButton = toy
		Ui.pressable(toy)
	end
	-- The HELP circle sits on the top bar line, right of the Settings gear.
	local help = found:FindFirstChild("HelpButton")
	if help ~= nil and help:IsA("TextButton") then
		buttons.HelpButton = help
		Ui.pressable(help)
		local function placeHelp()
			Ui.placeTopButton(help, HELP_SLOT)
		end
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeHelp)
		help:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHelp)
		placeHelp()
	end
	-- The spectate eye sits next to it. Client/Lobby shows it while a match is running and connects it.
	local watch = found:FindFirstChild("WatchButton")
	if watch ~= nil and watch:IsA("TextButton") then
		buttons.WatchButton = watch
		watch.Visible = false
		Ui.pressable(watch)
		local function placeWatch()
			Ui.placeTopButton(watch, WATCH_SLOT)
		end
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeWatch)
		watch:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeWatch)
		placeWatch()
	end
	Windows.Changed.connect(refresh)
	refresh()
end

-- The button with this name ("QuestsButton", "InventoryButton", "HelpButton", ...), or nil if not authored.
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

function Rail.onState(payload)
	playing = payload.playing == true
	phase = payload.phase
	refresh()
end

function Rail.onEliminated()
	playing = false
	refresh()
end

return Rail
