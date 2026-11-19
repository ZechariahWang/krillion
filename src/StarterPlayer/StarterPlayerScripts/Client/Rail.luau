--!strict
-- Drives LobbyUi.Rail: the grid of chunky square keys at the left edge (TODAY, REWARDS, SHOP, STORE, ITEMS,
-- ALBUM), each with an icon, a label and a "!" badge, the HELP circle on the top bar next to the Settings
-- gear, and the small THROW key at the right edge. It shows only in the lobby, off a pillar, and hides while
-- any window is open. The grid's size and layout are authored in Studio (RailFrame scales with the screen
-- height): one column on desktop, and on a phone the layout in RailFrame's Phone* attributes (two columns).
-- Each button belongs to its own controller: Rewards, ShopUi and Tutorial call Rail.button(name) to connect
-- it and Rail.setBadge(name, text) to mark it, so this module never needs to know them.

local GuiService = game:GetService("GuiService")

local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local BUTTONS = { "RewardsButton", "ShopButton", "StoreButton", "InventoryButton", "CollectionButton", "TodayButton" }
local HELP_SLOT = 1 -- top bar place right of the Settings gear
local WATCH_SLOT = 2 -- the spectate eye, right of Help
local WAIT_SECONDS = 10

local gui: Frame? = nil
local buttons: { [string]: TextButton } = {}
local playing = false
local phase = ""

local Rail = {}

-- Phones: swaps the authored desktop column for the authored phone grid (RailFrame's Phone* attributes).
local function usePhoneLayout(frame: GuiObject)
	local grid = frame:FindFirstChildOfClass("UIGridLayout")
	local aspect = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	local limit = frame:FindFirstChildOfClass("UISizeConstraint")
	local columns = frame:GetAttribute("PhoneColumns")
	local height = frame:GetAttribute("PhoneHeight")
	local ratio = frame:GetAttribute("PhoneAspect")
	local cell = frame:GetAttribute("PhoneCellSize")
	local padding = frame:GetAttribute("PhoneCellPadding")
	local minSize = frame:GetAttribute("PhoneMinSize")
	local maxSize = frame:GetAttribute("PhoneMaxSize")
	if grid == nil or aspect == nil or typeof(columns) ~= "number" or typeof(height) ~= "number"
		or typeof(ratio) ~= "number" or typeof(cell) ~= "UDim2" or typeof(padding) ~= "UDim2" then
		warn("Rail: RailFrame has no complete Phone* layout; phones keep the desktop column")
		return
	end
	frame.Size = UDim2.fromScale(0, height)
	grid.FillDirectionMaxCells = columns
	grid.CellSize = cell
	grid.CellPadding = padding
	aspect.AspectRatio = ratio
	if limit ~= nil and typeof(minSize) == "Vector2" then
		limit.MinSize = minSize
	end
	if limit ~= nil and typeof(maxSize) == "Vector2" then
		limit.MaxSize = maxSize
	end
end

local function refresh()
	local screen = gui
	if screen == nil then
		return
	end
	screen.Visible = not playing and phase ~= "Results" and not Windows.anyOpen()
end

-- The top tiles stack under the gear when their row would reach the status bar (Ui.placeTopButton), so they
-- are placed again once the status bar has its size: it may have none yet when the rail starts.
local function onStatusResized(playerGui: PlayerGui, place: () -> ())
	task.spawn(function()
		local status = Ui.screen(playerGui, "Status", WAIT_SECONDS)
		local frame = if status ~= nil then status:WaitForChild("StatusFrame", WAIT_SECONDS) else nil
		if frame ~= nil and frame:IsA("GuiObject") then
			frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			place()
		end
	end)
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
		if Ui.isPhone() then
			usePhoneLayout(frame)
		end
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
		found:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHelp)
		onStatusResized(playerGui, placeHelp)
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
		found:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeWatch)
		onStatusResized(playerGui, placeWatch)
		placeWatch()
	end
	Windows.Changed.connect(refresh)
	refresh()
end

-- The button with this name ("RewardsButton", "InventoryButton", "HelpButton", ...), or nil if not authored.
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
