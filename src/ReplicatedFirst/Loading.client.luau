--!strict
-- Shows ReplicatedFirst.LoadingScreen (authored in Studio) instead of Roblox's default screen: the bar follows
-- asset preloading, bubbles drift up, the title and the sea life bob, the kelp sways, and when done a white
-- flash snaps on and the screen zooms out of the way into the lobby. The centre block (title, bar, how-to-play pills) is drawn for DESIGN_SIZE and shrinks to fit.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local MIN_SECONDS = 1.5 -- never flash past
local SKIP_AFTER_SECONDS = 10 -- in case preloading stalls
local GIVE_UP_SECONDS = 20 -- the screen goes by itself even if preloading never returns
local DESIGN_SIZE = Vector2.new(980, 600) -- screen size the centre block is authored for
local MIN_FIT = 0.4
local TITLE_BOB = 8 -- pixels the title sinks and rises
local BOB_SECONDS = 1.8 -- one way; each creature takes a little longer than the one before
local SWAY_SECONDS = 2.6 -- one way; each kelp stalk takes a little longer than the one before
-- The hand-over: the shell pops at the end of the bar, the art pulls in a touch, a white flash snaps on with a
-- ping, holds a beat, then fades while the art zooms past the camera into the lobby.
local SHELL_POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHELL_POP_SCALE = 1.5
local PULL_IN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local PULL_IN_SCALE = 0.96
local FLASH_IN = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_HOLD = 0.12 -- seconds the screen stays fully white
local FLASH_OUT = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local ZOOM_OUT = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local ZOOM_SCALE = 1.35

local startedAt = os.clock()
ReplicatedFirst:RemoveDefaultLoadingScreen()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gui = (script.Parent:WaitForChild("LoadingScreen") :: ScreenGui):Clone()
gui.Parent = playerGui

local root = gui:WaitForChild("Root") :: CanvasGroup
local center = root:WaitForChild("Center") :: Frame
local fill = center:WaitForChild("Track"):WaitForChild("Fill") :: Frame
local skip = root:WaitForChild("Skip") :: TextButton
local bubbles = root:WaitForChild("Bubbles") :: Frame
local title = center:WaitForChild("Title") :: Frame
local titleScale = title:WaitForChild("UIScale") :: UIScale
local status = center:FindFirstChild("Status") :: TextLabel?
local centerFit = center:FindFirstChild("Fit") :: UIScale?
local creatures = root:FindFirstChild("Creatures")
local backdrop = root:FindFirstChild("Backdrop")
local kelp = if backdrop ~= nil then backdrop:FindFirstChild("Kelp") else nil
local zoom = root:FindFirstChild("Zoom") :: UIScale?
local flash = gui:FindFirstChild("Flash") :: Frame?

local finished = false

local function setProgress(fraction: number)
	local clamped = math.clamp(fraction, 0, 1)
	local goal = { Size = UDim2.fromScale(clamped, 1) }
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	if status ~= nil then
		status.Text = "LOADING  " .. math.floor(clamped * 100) .. "%"
	end
end

-- Each bubble rises from below the screen to above it, then starts again.
local function driftBubble(bubble: Frame)
	task.spawn(function()
		local x = bubble.Position.X.Scale
		local y = bubble.Position.Y.Scale
		while not finished do
			local seconds = 6 + (1.2 - y) * 6
			local tween = TweenService:Create(bubble, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
				Position = UDim2.fromScale(x, -0.1),
			})
			tween:Play()
			tween.Completed:Wait()
			y = 1.1
			bubble.Position = UDim2.fromScale(x, y)
		end
	end)
end

for _, child in bubbles:GetChildren() do
	if child:IsA("Frame") then
		driftBubble(child)
	end
end

-- Rises and falls by `pixels` for as long as the screen lives (the tween dies with the instance).
local function bob(object: GuiObject, pixels: number, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(object, info, { Position = object.Position + UDim2.fromOffset(0, pixels) }):Play()
end

local function fitCenter()
	local scale = centerFit
	local size = gui.AbsoluteSize
	if scale == nil or size.X <= 0 or size.Y <= 0 then
		return
	end
	scale.Scale = math.clamp(math.min(size.X / DESIGN_SIZE.X, size.Y / DESIGN_SIZE.Y), MIN_FIT, 1)
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCenter)
fitCenter()

titleScale.Scale = 0.9
TweenService:Create(titleScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
-- bob(title, TITLE_BOB, BOB_SECONDS)

-- Each creature's Bob attribute is the pixels it rises and falls.
if creatures ~= nil then
	local count = 0
	for _, child in creatures:GetChildren() do
		local pixels = child:GetAttribute("Bob")
		if child:IsA("GuiObject") and typeof(pixels) == "number" then
			count += 1
			bob(child, -pixels, BOB_SECONDS + count * 0.35)
		end
	end
end

-- Each stalk's Sway attribute is the degrees it leans each way.
if kelp ~= nil then
	local count = 0
	for _, child in kelp:GetChildren() do
		local degrees = child:GetAttribute("Sway")
		if child:IsA("GuiObject") and typeof(degrees) == "number" then
			count += 1
			child.Rotation = -degrees
			local info = TweenInfo.new(SWAY_SECONDS + count * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(child, info, { Rotation = degrees }):Play()
		end
	end
end

-- The hand-over: a white flash snaps on, then fades while the loading art zooms past the camera and goes.
local function playSound(name: string, volume: number)
	local folder = SoundService:FindFirstChild("RareOrSink")
	local sound = if folder ~= nil then folder:FindFirstChild(name) else nil
	if sound ~= nil and sound:IsA("Sound") then
		local copy = sound:Clone()
		copy.Volume = volume
		copy.Parent = SoundService
		copy:Play()
		copy.Ended:Connect(function()
			copy:Destroy()
		end)
	end
end

local function finish()
	if finished then
		return
	end
	finished = true
	setProgress(1)
	task.wait(0.25)
	local shell = fill:FindFirstChild("Shell")
	local pop = if shell ~= nil then shell:FindFirstChildOfClass("UIScale") else nil
	if pop ~= nil then
		pop.Scale = SHELL_POP_SCALE
		TweenService:Create(pop, SHELL_POP, { Scale = 1 }):Play()
	end
	if zoom ~= nil then
		TweenService:Create(zoom, PULL_IN, { Scale = PULL_IN_SCALE }):Play()
	end
	task.wait(PULL_IN.Time)
	playSound("Ping", 0.6)
	if flash ~= nil then
		TweenService:Create(flash, FLASH_IN, { BackgroundTransparency = 0 }):Play()
		task.wait(FLASH_IN.Time + FLASH_HOLD)
		TweenService:Create(flash, FLASH_OUT, { BackgroundTransparency = 1 }):Play()
	end
	if zoom ~= nil then
		TweenService:Create(zoom, ZOOM_OUT, { Scale = ZOOM_SCALE }):Play()
	end
	TweenService:Create(root, ZOOM_OUT, { GroupTransparency = 1 }):Play()
	task.wait(FLASH_OUT.Time)
	gui:Destroy()
end

skip.MouseButton1Click:Connect(function()
	task.spawn(finish)
end)

task.delay(SKIP_AFTER_SECONDS, function()
	if not finished then
		skip.Visible = true
	end
end)

task.delay(GIVE_UP_SECONDS, finish)

setProgress(0.08)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.3)

local assets: { Instance } = {}
for _, child in StarterGui:GetChildren() do
	table.insert(assets, child)
end
-- The Music tracks are full songs: they stream in once the lobby shows instead of holding up the screen.
local sounds = SoundService:FindFirstChild("RareOrSink")
if sounds ~= nil then
	for _, child in sounds:GetChildren() do
		if child.Name ~= "Music" then
			table.insert(assets, child)
		end
	end
end

for index, asset in assets do
	if finished then
		break
	end
	ContentProvider:PreloadAsync({ asset })
	setProgress(0.3 + 0.7 * index / #assets)
end

local elapsed = os.clock() - startedAt
if elapsed < MIN_SECONDS then
	task.wait(MIN_SECONDS - elapsed)
end
finish()
