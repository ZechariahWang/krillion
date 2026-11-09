--!strict
-- Drives SharedUi.Transition around the start of a match: MatchIntro fades the screen to black, the server
-- teleports you onto your pillar out of sight, the black fades away once the "Starting" phase arrives, and a
-- big 3-2-1 counts down to a GO! as round 1 opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local HOLD_SECONDS = 0.3 -- black stays a moment after the pillars appear, while the teleport settles
local FADE_OUT_SECONDS = 0.45
local FAILSAFE_SECONDS = 4 -- never leave the screen black if the Starting phase does not arrive
local GO_SECONDS = 0.9

local fade: Frame? = nil
local countdown: TextLabel? = nil
local black = false
local fadeToken = 0
local lastPhase = ""
local lastShown = -1

local Transition = {}

local function fadeOut()
	local frame = fade
	if frame == nil or not black then
		return
	end
	black = false
	fadeToken += 1
	local token = fadeToken
	Tween.play(frame, TweenInfo.new(FADE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	task.delay(FADE_OUT_SECONDS, function()
		if token == fadeToken then
			frame.Visible = false
		end
	end)
end

local function showText(text: string)
	local label = countdown
	if label == nil then
		return
	end
	label.Text = text
	Ui.pop(label, 0.5)
end

local function hideText()
	local label = countdown
	if label ~= nil then
		label.Visible = false
	end
	lastShown = -1
end

-- MatchIntro payload {fadeSeconds}: this player is about to be teleported onto a pillar.
function Transition.onIntro(payload)
	local frame = fade
	if frame == nil then
		return
	end
	local seconds = if type(payload) == "table" and type(payload.fadeSeconds) == "number" then payload.fadeSeconds else 0.35
	black = true
	fadeToken += 1
	local token = fadeToken
	frame.BackgroundTransparency = 1
	frame.Visible = true
	Tween.play(frame, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
	task.delay(FAILSAFE_SECONDS, function()
		if token == fadeToken then
			fadeOut()
		end
	end)
end

-- RoundState payload.
function Transition.onState(payload)
	local phase = payload.phase
	if phase == "Starting" then
		if black and lastPhase ~= "Starting" then
			task.delay(HOLD_SECONDS, fadeOut)
		end
		local seconds = payload.secondsLeft
		if not payload.playing then
			hideText()
		elseif seconds > 0 and seconds ~= lastShown then
			lastShown = seconds
			showText(tostring(seconds))
			Sfx.play("Tick", 0.6, 1 + 0.1 * (3 - seconds))
		end
	elseif phase == "Prompt" and lastPhase == "Starting" then
		fadeOut()
		if payload.playing then
			showText("GO!")
			Sfx.play("LockIn", 0.8)
			task.delay(GO_SECONDS, hideText)
		else
			hideText()
		end
	elseif phase ~= "Prompt" then
		hideText()
		if phase ~= "Intermission" then
			fadeOut()
		end
	end
	lastPhase = phase
end

function Transition.init(playerGui: PlayerGui)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Transition", WAIT_SECONDS)
		if found == nil then
			warn("Transition: SharedUi.Transition is missing; no fade or countdown")
			return
		end
		local frame = found:FindFirstChild("Fade")
		local label = found:FindFirstChild("Countdown")
		if frame ~= nil and frame:IsA("Frame") then
			fade = frame
		end
		if label ~= nil and label:IsA("TextLabel") then
			countdown = label
			label.Visible = false
		end
	end)
end

return Transition
