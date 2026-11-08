--!strict
-- Shows ReplicatedFirst.LoadingScreen (authored in Studio) instead of Roblox's default screen: the bar follows
-- asset preloading, bubbles drift up, and it fades straight into the lobby when done.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local MIN_SECONDS = 1.5 -- never flash past
local SKIP_AFTER_SECONDS = 10 -- in case preloading stalls

local startedAt = os.clock()
ReplicatedFirst:RemoveDefaultLoadingScreen()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gui = (script.Parent:WaitForChild("LoadingScreen") :: ScreenGui):Clone()
gui.Parent = playerGui

local root = gui:WaitForChild("Root") :: CanvasGroup
local fill = root:WaitForChild("Center"):WaitForChild("Track"):WaitForChild("Fill") :: Frame
local skip = root:WaitForChild("Skip") :: TextButton
local bubbles = root:WaitForChild("Bubbles") :: Frame
local logoScale = root:WaitForChild("Center"):WaitForChild("Logo"):WaitForChild("UIScale") :: UIScale
local status = root:WaitForChild("Center"):FindFirstChild("Status") :: TextLabel?

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

logoScale.Scale = 0.9
TweenService:Create(logoScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

local function finish()
	if finished then
		return
	end
	finished = true
	setProgress(1)
	task.wait(0.25)
	local fade = TweenService:Create(root, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 1,
	})
	fade:Play()
	fade.Completed:Wait()
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

setProgress(0.08)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.3)

local assets: { Instance } = {}
for _, child in StarterGui:GetChildren() do
	table.insert(assets, child)
end
local sounds = SoundService:FindFirstChild("Krillion")
if sounds ~= nil then
	table.insert(assets, sounds)
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
