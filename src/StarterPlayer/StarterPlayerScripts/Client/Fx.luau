--!strict
-- Drives StarterGui.Fx and the camera: screen flash, big callouts, floating coin text, camera shake.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local CALLOUT_SECONDS = 1.4

local flash: Frame
local callout: TextLabel
local coinPop: TextLabel

local calloutToken = 0
local calloutBase: UDim2? = nil
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

-- A faint tint that fades out, never a full white-out.
function Fx.flash(color: Color3)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.8
	Tween.play(flash, Theme.Tween.Flash, { BackgroundTransparency = 1 })
end

-- Fades in while sliding up a few pixels, holds, then fades out.
function Fx.callout(text: string, color: Color3)
	calloutToken += 1
	local token = calloutToken
	if calloutBase == nil then
		calloutBase = callout.Position
	end
	local base = calloutBase :: UDim2
	callout.Text = text
	callout.TextColor3 = color
	callout.TextTransparency = 1
	callout.Position = base + UDim2.fromOffset(0, 12)
	callout.Visible = true
	Tween.play(callout, Theme.Tween.Enter, { TextTransparency = 0, Position = base })
	local scale = callout:FindFirstChildOfClass("UIScale")
	if scale ~= nil then
		scale.Scale = 0.85
		Tween.play(scale, Theme.Tween.Pop, { Scale = 1 })
	end
	task.delay(CALLOUT_SECONDS, function()
		if token ~= calloutToken then
			return
		end
		Tween.play(callout, Theme.Tween.Exit, { TextTransparency = 1 })
		task.delay(0.2, function()
			if token == calloutToken then
				callout.Visible = false
			end
		end)
	end)
end

-- "+50" that drifts up from a point on screen and fades.
function Fx.coinPop(text: string, from: GuiObject)
	local pop = coinPop:Clone()
	pop.Name = "CoinPopLive"
	pop.Text = text
	local center = from.AbsolutePosition + from.AbsoluteSize / 2
	pop.Position = UDim2.fromOffset(center.X, center.Y)
	pop.Visible = true
	pop.Parent = coinPop.Parent
	local goal = { Position = UDim2.fromOffset(center.X, center.Y - 50), TextTransparency = 1 }
	Tween.play(pop, Theme.Tween.Float, goal)
	task.delay(1, function()
		pop:Destroy()
	end)
end

function Fx.shake(seconds: number, power: number)
	shakeUntil = os.clock() + seconds
	shakePower = power
end

return Fx
