--!strict
-- Drives SharedUi.Settings: the gear in the Roblox top bar (placed right of Roblox's own buttons through
-- GuiService.TopbarInset) and the window it opens, with a MUSIC and an AFK toggle. Music is saved with the
-- profile (SetSetting "MusicOn"); AFK lasts for the session and the server's Afk attribute is the truth.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Music = require(script.Parent.Music)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local TOPBAR_GAP = 12 -- pixels between Roblox's last top bar button and the gear
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

local function refresh()
	showToggle(musicToggle, Music.isEnabled())
	showToggle(afkToggle, player:GetAttribute("Afk") == true)
end

-- Puts the gear just right of Roblox's own top bar buttons, centred in the bar's height.
local function placeGear()
	local button = gear
	if button == nil then
		return
	end
	local inset = GuiService.TopbarInset
	local size = button.AbsoluteSize
	local x = inset.Min.X + TOPBAR_GAP
	local y = inset.Min.Y + math.max((inset.Height - size.Y) / 2, 0)
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
