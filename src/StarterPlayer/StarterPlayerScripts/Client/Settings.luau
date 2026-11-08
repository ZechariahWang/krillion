--!strict
-- Drives SharedUi.Settings: the gear in the Roblox top bar (placed right of Roblox's own buttons through
-- GuiService.TopbarInset) and the window it opens: a MUSIC toggle, a VOLUME bar and an AFK toggle. Music and
-- volume are saved with the profile (SetSetting "MusicOn" / "MusicVolume"); AFK lasts for the session and the
-- server's Afk attribute is the truth.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Music = require(script.Parent.Music)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local TOPBAR_GAP = 8 -- pixels between Roblox's last top bar button and the gear (Roblox's own spacing)
local TOPBAR_BOTTOM = 2 -- Roblox's buttons end this far above the bottom of GuiService.TopbarInset
local MARGIN = 16
local MIN_FIT = 0.5

local player = Players.LocalPlayer

local screen: Frame? = nil
local gear: GuiButton? = nil
local holder: GuiObject? = nil
local panel: GuiObject? = nil
local fit: UIScale? = nil
local scrim: GuiObject? = nil
local musicToggle: GuiButton? = nil
local afkToggle: GuiButton? = nil
local slider: GuiObject? = nil
local sliderFill: GuiObject? = nil
local sliderKnob: GuiObject? = nil
local sliderText: TextLabel? = nil
local dragging = false
local isOpen = false

local Settings = {}

-- Recolours a chunky button's face (its "Lip" gradient), keeping the authored lip band height.
local function paint(button: GuiButton, swatch: { Top: Color3, Bottom: Color3, Lip: Color3 })
	local lip = button:FindFirstChild("Lip")
	if lip == nil or not lip:IsA("UIGradient") then
		return
	end
	local band = 0.88
	local points = lip.Color.Keypoints
	for _, point in points do
		if point.Time > 0 and point.Time < 1 and point.Value ~= points[1].Value then
			band = point.Time
			break
		end
	end
	lip.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, swatch.Top),
		ColorSequenceKeypoint.new(band, swatch.Bottom),
		ColorSequenceKeypoint.new(math.min(band + 0.01, 1), swatch.Lip),
		ColorSequenceKeypoint.new(1, swatch.Lip),
	})
end

local function showToggle(button: GuiButton?, on: boolean)
	if button == nil then
		return
	end
	local colors = Theme.Chunky.Color
	paint(button, if on then colors.Lime else colors.Red)
	local label = button:FindFirstChild("Label")
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = if on then "ON" else "OFF"
	end
end

local function showVolume(level: number)
	if sliderFill ~= nil then
		sliderFill.Size = UDim2.fromScale(level, 1)
	end
	if sliderKnob ~= nil then
		sliderKnob.Position = UDim2.fromScale(level, 0.5)
	end
	if sliderText ~= nil then
		sliderText.Text = math.floor(level * 100 + 0.5) .. "%"
	end
end

local function refresh()
	showToggle(musicToggle, Music.isEnabled())
	showToggle(afkToggle, player:GetAttribute("Afk") == true)
	if not dragging then
		showVolume(Music.getVolume())
	end
end

-- The bar under the pointer's x position sets the volume at once; it is saved when the drag ends.
local function volumeAt(x: number)
	local bar = slider
	if bar == nil or bar.AbsoluteSize.X <= 0 then
		return
	end
	local level = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
	Music.setVolume(level)
	showVolume(level)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function bindSlider(bar: GuiObject)
	slider = bar
	local fill = bar:FindFirstChild("Fill")
	sliderFill = if fill ~= nil and fill:IsA("GuiObject") then fill else nil
	local knob = bar:FindFirstChild("Knob")
	sliderKnob = if knob ~= nil and knob:IsA("GuiObject") then knob else nil
	local count = bar:FindFirstChild("Count")
	sliderText = if count ~= nil and count:IsA("TextLabel") then count else nil
	local function begin(input: InputObject)
		if isPress(input) then
			dragging = true
			volumeAt(input.Position.X)
		end
	end
	bar.InputBegan:Connect(begin)
	if sliderKnob ~= nil then
		sliderKnob.InputBegan:Connect(begin)
	end
	UserInputService.InputChanged:Connect(function(input)
		local moving = input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		if dragging and moving then
			volumeAt(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and isPress(input) then
			dragging = false
			Net.event("SetSetting"):FireServer("MusicVolume", Music.getVolume())
			Sfx.play("Tick", 0.5)
		end
	end)
end

-- Puts the gear just right of Roblox's own top bar buttons, on the same line as them.
local function placeGear()
	local button = gear
	if button == nil then
		return
	end
	local inset = GuiService.TopbarInset
	local size = button.AbsoluteSize
	local x = inset.Min.X + TOPBAR_GAP
	local y = inset.Max.Y - TOPBAR_BOTTOM - size.Y
	button.AnchorPoint = Vector2.zero
	button.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function fitToScreen()
	local frame = screen
	local window = panel
	local scale = fit
	if frame == nil or window == nil or scale == nil then
		return
	end
	Ui.fitPanel(frame.AbsoluteSize, window, scale, nil, MARGIN, MIN_FIT, 0)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	if holder ~= nil then
		holder.Visible = false
	end
	if scrim ~= nil then
		scrim.Visible = false
	end
	Rail.panelClosed(close)
end

function Settings.open()
	if isOpen or holder == nil then
		return
	end
	isOpen = true
	refresh()
	fitToScreen()
	if scrim ~= nil then
		scrim.Visible = true
	end
	holder.Visible = true
	Sfx.play("Open", 0.5)
	if panel ~= nil then
		Ui.pop(panel, 0.7)
	end
	Rail.panelOpened(close)
end

local function toggleWindow()
	if isOpen then
		Sfx.play("Close", 0.5)
		close()
	else
		Settings.open()
	end
end

local function buttonIn(parent: Instance?, rowName: string): GuiButton?
	local row = if parent ~= nil then parent:FindFirstChild(rowName) else nil
	local button = if row ~= nil then row:FindFirstChild("Toggle") else nil
	if button ~= nil and button:IsA("GuiButton") then
		return button
	end
	return nil
end

local function bind(found: Frame)
	screen = found
	local top = found:FindFirstChild("TopButton")
	local box = found:FindFirstChild("Holder")
	local window = if box ~= nil then box:FindFirstChild("Panel") else nil
	if top == nil or not top:IsA("GuiButton") or box == nil or not box:IsA("GuiObject") or window == nil then
		warn("Settings: SharedUi.Settings needs TopButton and Holder.Panel")
		return
	end
	gear = top
	holder = box
	panel = if window:IsA("GuiObject") then window else nil
	local scale = box:FindFirstChild("Fit")
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	local back = found:FindFirstChild("Scrim")
	scrim = if back ~= nil and back:IsA("GuiObject") then back else nil
	box.Visible = false
	if scrim ~= nil then
		scrim.Visible = false
	end

	Ui.pressable(top)
	top.Activated:Connect(toggleWindow)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeGear)
	top:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeGear)
	placeGear()

	local closeButton = window:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("GuiButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			close()
		end)
	end
	if scrim ~= nil and scrim:IsA("GuiButton") then
		scrim.Activated:Connect(close)
	end

	local volumeRow = window:FindFirstChild("VolumeRow")
	local bar = if volumeRow ~= nil then volumeRow:FindFirstChild("Slider") else nil
	if bar ~= nil and bar:IsA("GuiObject") then
		bindSlider(bar)
	end
	musicToggle = buttonIn(window, "MusicRow")
	afkToggle = buttonIn(window, "AfkRow")
	local music = musicToggle
	if music ~= nil then
		Ui.pressable(music)
		music.Activated:Connect(function()
			local on = not Music.isEnabled()
			Music.setEnabled(on)
			Net.event("SetSetting"):FireServer("MusicOn", on)
			Sfx.play("Tick", 0.5)
			refresh()
		end)
	end
	local afk = afkToggle
	if afk ~= nil then
		Ui.pressable(afk)
		afk.Activated:Connect(function()
			local on = player:GetAttribute("Afk") ~= true
			Net.event("SetSetting"):FireServer("Afk", on)
			Sfx.play("Tick", 0.5)
			showToggle(afk, on)
		end)
	end
	player:GetAttributeChangedSignal("Afk"):Connect(refresh)
	found:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	refresh()
end

-- ProfileChanged payload: keeps the MUSIC toggle in step with the saved choice.
function Settings.onProfile(profile)
	Music.onProfile(profile)
	refresh()
end

function Settings.init(playerGui: PlayerGui)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Settings", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Settings: SharedUi.Settings is missing; there is no settings button")
			return
		end
		bind(found)
	end)
end

return Settings
