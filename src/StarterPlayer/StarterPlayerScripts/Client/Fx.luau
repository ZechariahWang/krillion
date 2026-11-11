--!strict
-- Drives StarterGui.Fx and the camera: screen flash, big callouts, floating coin text, camera shake, and the
-- full-screen confetti rain (pieces cloned from ReplicatedStorage.Templates.Confetti).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Ui = require(script.Parent.Ui)

local CALLOUT_SECONDS = 1.4
local CALLOUT_TILT = 4 -- degrees a callout lands tilted, alternating sides, like a stamped sticker
local COIN_RISE = 70 -- pixels a coin pop drifts up
local COIN_FADE_AT = 0.5 -- seconds before a coin pop starts to fade
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local MAX_CONFETTI = 120 -- pieces alive at once, across every burst
local WAIT_SECONDS = 10

type Piece = {
	frame: Frame,
	x: number,
	sway: number,
	swaySpeed: number,
	phase: number,
	spin: number,
	rotation: number,
	born: number,
	life: number,
}

local gui: Instance
local flash: Frame
local callout: TextLabel
local coinPop: TextLabel

local calloutFill: UIGradient
local calloutToken = 0
local calloutSide = 1
local calloutBase: UDim2? = nil
local shakeUntil = 0
local shakePower = 0

local confettiTemplate: Frame? = nil
local pieces: { Piece } = {}
local confettiConnection: RBXScriptConnection? = nil
local shaking: { [GuiObject]: boolean } = {}
local random = Random.new()

local Fx = {}

local ready = false -- the Fx screen and its children were found; the screen effects are off until then
local missing: string? = nil

-- WaitForChild with a timeout. Once one child is missing the rest are skipped, so init gives up quickly.
local function waitChild(parent: Instance?, name: string): Instance?
	if parent == nil or missing ~= nil then
		return nil
	end
	local found = parent:WaitForChild(name, WAIT_SECONDS)
	if found == nil then
		missing = name
	end
	return found
end

function Fx.init(playerGui: PlayerGui)
	RunService:BindToRenderStep("RareOrSinkShake", Enum.RenderPriority.Camera.Value + 1, function()
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

	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
		local found = if templates ~= nil then templates:WaitForChild("Confetti", WAIT_SECONDS) else nil
		if found ~= nil and found:IsA("Frame") then
			confettiTemplate = found :: Frame
		else
			warn("[Fx] ReplicatedStorage.Templates.Confetti is missing; confetti is off")
		end
	end)

	local screen = Ui.screen(playerGui, "Fx", WAIT_SECONDS)
	if screen == nil then
		warn("[Fx] SharedUi.Fx is missing; flashes, callouts and coin pops are off")
		return
	end
	local flashFound = waitChild(screen, "Flash")
	local calloutFound = waitChild(screen, "Callout")
	local coinFound = waitChild(screen, "CoinPop")
	local fillFound = waitChild(calloutFound, "Fill")
	if missing ~= nil then
		warn("[Fx] SharedUi.Fx has no " .. missing .. "; flashes, callouts and coin pops are off")
		return
	end
	gui = screen
	flash = flashFound :: Frame
	callout = calloutFound :: TextLabel
	coinPop = coinFound :: TextLabel
	-- The callout is a big sticker authored in Studio (outline, "Fill" gradient tinted per callout), shown up
	-- to Theme.Chunky.Grow.Callout times its authored size (fitted to the screen).
	calloutFill = fillFound :: UIGradient
	Ui.grow(callout, Theme.Chunky.Grow.Callout)
	ready = true
end

-- A faint tint that fades out, never a full white-out.
function Fx.flash(color: Color3)
	if not ready then
		return
	end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.8
	Tween.play(flash, Theme.Tween.Flash, { BackgroundTransparency = 1 })
end

-- Lands big and tilted from 40%, sliding up a few pixels, holds, then shrinks a little as it fades. The
-- text is white under a gradient in `color` (lighter on top, darker at the bottom) with a thick outline.
function Fx.callout(text: string, color: Color3)
	if not ready then
		return
	end
	calloutToken += 1
	local token = calloutToken
	if calloutBase == nil then
		calloutBase = callout.Position
	end
	local base = calloutBase :: UDim2
	calloutSide = -calloutSide
	local tilt = CALLOUT_TILT * calloutSide
	callout.Text = text
	callout.TextColor3 = WHITE
	calloutFill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.55)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, color:Lerp(BLACK, 0.22)),
	})
	callout.TextTransparency = 1
	callout.Position = base + UDim2.fromOffset(0, 12)
	callout.Rotation = tilt * 3
	callout.Visible = true
	Tween.play(callout, Theme.Tween.Enter, { TextTransparency = 0, Position = base, Rotation = tilt })
	local scale = callout:FindFirstChildOfClass("UIScale")
	local rest = Ui.rest(callout)
	if scale ~= nil then
		scale.Scale = rest * 0.4
		Tween.play(scale, Theme.Tween.Hop, { Scale = rest })
	end
	task.delay(CALLOUT_SECONDS, function()
		if token ~= calloutToken then
			return
		end
		Tween.play(callout, Theme.Tween.Exit, { TextTransparency = 1 })
		if scale ~= nil then
			Tween.play(scale, Theme.Tween.Exit, { Scale = rest * 0.8 })
		end
		task.delay(0.2, function()
			if token == calloutToken then
				callout.Visible = false
			end
		end)
	end)
end

-- A big "+50" that springs out of a point on screen with a wobble, drifts up and fades. `color` overrides
-- the authored gold.
function Fx.coinPop(text: string, from: GuiObject, color: Color3?)
	if not ready then
		return
	end
	local pop = coinPop:Clone()
	pop.Name = "CoinPopLive"
	pop.Text = text
	if color ~= nil then
		pop.TextColor3 = color
	end
	local center = from.AbsolutePosition + from.AbsoluteSize / 2
	pop.Position = UDim2.fromOffset(center.X, center.Y)
	pop.Rotation = random:NextNumber(-10, 10)
	pop.Visible = true
	pop.Parent = coinPop.Parent
	local scale = pop:FindFirstChildOfClass("UIScale")
	if scale ~= nil then
		local rest = Ui.rest(pop)
		scale.Scale = rest * 0.3
		Tween.play(scale, Theme.Tween.Boing, { Scale = rest })
	end
	Tween.play(pop, Theme.Tween.Float, { Position = UDim2.fromOffset(center.X, center.Y - COIN_RISE), Rotation = 0 })
	task.delay(COIN_FADE_AT, function()
		if pop.Parent ~= nil then
			TweenService:Create(pop, Theme.Tween.Flash, { TextTransparency = 1 }):Play()
		end
	end)
	task.delay(1, function()
		pop:Destroy()
	end)
end

function Fx.shake(seconds: number, power: number)
	shakeUntil = os.clock() + seconds
	shakePower = power
end

-- Jitters a GUI element by up to `pixels`, fading out over `seconds`. An element inside a list or grid layout
-- ignores Position, so its children are jittered together instead (the dive card in the reveal row).
function Fx.shakeOffset(target: GuiObject, pixels: number, seconds: number)
	if shaking[target] then
		return
	end
	local parent = target.Parent
	local movers: { GuiObject } = {}
	if parent ~= nil and parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil then
		for _, child in target:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(movers, child)
			end
		end
	else
		table.insert(movers, target)
	end
	local bases: { UDim2 } = {}
	for index, mover in movers do
		bases[index] = mover.Position
	end
	shaking[target] = true
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= seconds or target.Parent == nil then
			connection:Disconnect()
			shaking[target] = nil
			for index, mover in movers do
				if mover.Parent ~= nil then
					mover.Position = bases[index]
				end
			end
			return
		end
		local power = pixels * (1 - elapsed / seconds)
		local offset = UDim2.fromOffset(random:NextNumber(-power, power), random:NextNumber(-power, power))
		for index, mover in movers do
			mover.Position = bases[index] + offset
		end
	end)
end

-- One loop moves every live piece: a fall with a little gravity, a side-to-side sway and a spin.
local function stepConfetti()
	local now = os.clock()
	for index = #pieces, 1, -1 do
		local piece = pieces[index]
		local alpha = (now - piece.born) / piece.life
		if alpha >= 1 then
			piece.frame:Destroy()
			table.remove(pieces, index)
		elseif alpha >= 0 then
			local y = -0.05 + 1.12 * (0.6 * alpha + 0.4 * alpha * alpha)
			local x = piece.x + math.sin(now * piece.swaySpeed + piece.phase) * piece.sway
			piece.frame.Position = UDim2.fromScale(x, y)
			piece.frame.Rotation = piece.rotation + piece.spin * (now - piece.born)
			piece.frame.Visible = true
		end
	end
	if #pieces == 0 and confettiConnection ~= nil then
		confettiConnection:Disconnect()
		confettiConnection = nil
	end
end

-- Confetti rains down the whole screen. Kept for wins and Mythics; capped so bursts never pile up.
function Fx.confetti(count: number, colors: { Color3 }?)
	local template = confettiTemplate
	if template == nil or not ready then
		return
	end
	local palette = colors or Theme.Confetti
	local now = os.clock()
	local amount = math.min(count, MAX_CONFETTI - #pieces)
	for _ = 1, amount do
		local frame = template:Clone()
		frame.Name = "ConfettiLive"
		frame.BackgroundColor3 = palette[random:NextInteger(1, #palette)]
		frame.Size = UDim2.fromOffset(random:NextInteger(8, 12), random:NextInteger(12, 18))
		frame.Position = UDim2.fromScale(0, -0.1)
		frame.Visible = false
		frame.Parent = gui
		table.insert(pieces, {
			frame = frame,
			x = random:NextNumber(0.02, 0.98),
			sway = random:NextNumber(0.01, 0.035),
			swaySpeed = random:NextNumber(2, 4),
			phase = random:NextNumber(0, math.pi * 2),
			spin = random:NextNumber(-360, 360),
			rotation = random:NextNumber(0, 360),
			-- Staggered starts so it reads as a rain, not a sheet.
			born = now + random:NextNumber(0, 0.45),
			life = random:NextNumber(1.6, 2.4),
		})
	end
	if confettiConnection == nil and #pieces > 0 then
		confettiConnection = RunService.RenderStepped:Connect(stepConfetti)
	end
end

return Fx
