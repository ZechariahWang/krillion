--!strict
-- Drives StarterGui.Fx and the camera: screen flash, big callouts, floating coin text, camera shake.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Ui = require(script.Parent.Ui)

local CALLOUT_SECONDS = 1.4

local flash: Frame
local callout: TextLabel
local coinPop: TextLabel

local calloutToken = 0
local shakeUntil = 0
local shakePower = 0

local Fx = {}

function Fx.init(playerGui: PlayerGui)
	local gui = playerGui:WaitForChild("Fx")
	flash = gui:WaitForChild("Flash") :: Frame
	callout = gui:WaitForChild("Callout") :: TextLabel
	coinPop = gui:WaitForChild("CoinPop") :: TextLabel

	RunService:BindToRenderStep("KrillionShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() >= shakeUntil then
			return
		end
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local x = (math.random() - 0.5) * shakePower
		local y = (math.random() - 0.5) * shakePower
		camera.CFrame = camera.CFrame * CFrame.new(x, y, 0)
	end)
end

function Fx.flash(color: Color3)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.35
	Tween.play(flash, Theme.Tween.Flash, { BackgroundTransparency = 1 })
end

function Fx.callout(text: string, color: Color3)
	calloutToken += 1
	local token = calloutToken
	callout.Text = text
	callout.TextColor3 = color
	callout.Rotation = math.random(-6, 6)
	Ui.slam(callout)
	task.delay(CALLOUT_SECONDS, function()
		if token == calloutToken then
			callout.Visible = false
		end
	end)
end

-- "+50" that floats up from a point on screen and fades.
function Fx.coinPop(text: string, from: GuiObject)
	local pop = coinPop:Clone()
	pop.Name = "CoinPopLive"
	pop.Text = text
	local center = from.AbsolutePosition + from.AbsoluteSize / 2
	pop.Position = UDim2.fromOffset(center.X, center.Y)
	pop.Visible = true
	pop.Parent = coinPop.Parent
	Ui.pop(pop)
	local goal = { Position = UDim2.fromOffset(center.X, center.Y - 90), TextTransparency = 1 }
	Tween.play(pop, Theme.Tween.Float, goal)
	local stroke = pop:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then
		Tween.play(stroke, Theme.Tween.Float, { Transparency = 1 })
	end
	task.delay(1, function()
		pop:Destroy()
	end)
end

function Fx.shake(seconds: number, power: number)
	shakeUntil = os.clock() + seconds
	shakePower = power
end

return Fx
