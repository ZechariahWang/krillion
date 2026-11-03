--!strict
-- Drives StarterGui.Hud during a match: answer box with instant feedback, Cash, water meter, sudden-death card.
-- The prompt, timer and alive count live in StarterGui.Status (see Status.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local METER_RANGE = 30 -- studs of margin that fills the whole meter
local METER_WATER = 0.2 -- fraction of the meter the water fill occupies
local FEEDBACK_SECONDS = 1.5

local gui: ScreenGui
local coinChip: Frame
local coinText: TextLabel
local meter: Frame
local marker: Frame
local target: Frame
local answerBar: Frame
local answerBox: TextBox
local submitButton: TextButton
local lockedCard: Frame
local lockedText: TextLabel
local feedback: Frame
local banner: Frame

local locked = false
local lastSentAt = 0
local feedbackToken = 0
local lastRound = 0
local lastPhase = ""
local lastWaterY = 0

local Hud = {}

-- Deferred so it runs after the TextBox has finished losing focus from the Enter press.
local function keepFocus()
	task.defer(function()
		if answerBox.Visible and answerBar.Visible then
			answerBox:CaptureFocus()
		end
	end)
end

local function showLocked()
	answerBox:ReleaseFocus()
	answerBox.Visible = false
	submitButton.Visible = false
	Ui.appear(lockedCard)
end

local function showEntry()
	answerBox.Text = ""
	answerBox.Visible = true
	submitButton.Visible = true
	lockedCard.Visible = false
	feedback.Visible = false
end

local function submit()
	if locked then
		return
	end
	local text = answerBox.Text
	if #text == 0 then
		return
	end
	local now = os.clock()
	if now - lastSentAt < GameConfig.Answer.RetryCooldown then
		return
	end
	lastSentAt = now
	Net.event("SubmitAnswer"):FireServer(text)
	keepFocus()
end

local function showFeedback()
	feedbackToken += 1
	local token = feedbackToken
	Ui.appear(feedback)
	Ui.nudge(answerBar)
	task.delay(FEEDBACK_SECONDS, function()
		if token == feedbackToken then
			feedback.Visible = false
		end
	end)
end

function Hud.onAnswerResult(payload)
	if payload.accepted then
		locked = true
		-- Autocorrect: show the answer in the bank's spelling, whatever was typed.
		local corrected = payload.corrected or answerBox.Text
		answerBox.Text = string.upper(corrected)
		lockedText.Text = "LOCKED IN  |  " .. string.upper(corrected)
		showLocked()
		Sfx.play("LockIn", 0.7)
		Fx.flash(Theme.Color.Green)
		return
	end
	answerBox.Text = ""
	showFeedback()
	Sfx.play("Wrong", 0.5)
	keepFocus()
end

-- Where a height sits on the meter, measured from the current water line.
local function meterY(height: number, waterY: number): number
	local margin = math.clamp((height - waterY) / METER_RANGE, 0, 1)
	return 1 - METER_WATER - margin * (1 - METER_WATER)
end

-- The marker is you; the target line is where the water will reach this round.
-- The marker turns red while you are still below that line.
local function updateMeter(payload)
	local markerY = meterY(payload.height, payload.waterY)
	Tween.play(marker, Theme.Tween.Enter, { Position = UDim2.fromScale(0.5, markerY) })
	local showTarget = payload.phase == "Prompt" or payload.phase == "Reveal"
	target.Visible = showTarget
	if showTarget then
		local targetY = meterY(payload.waterY + payload.surge, payload.waterY)
		Tween.play(target, Theme.Tween.Enter, { Position = UDim2.fromScale(0.5, targetY) })
	end
	local willSink = payload.height < payload.waterY + payload.surge
	if showTarget and willSink then
		marker.BackgroundColor3 = Theme.Color.Red
	else
		marker.BackgroundColor3 = Theme.Color.Cream
	end
end

local function onSurge(payload)
	if payload.waterY == lastWaterY then
		-- First Surge broadcast: the water is about to move. A faint rumble, then a firmer one on the jump.
		Fx.shake(GameConfig.Water.CreepSeconds, 0.06)
		task.delay(GameConfig.Water.CreepSeconds, function()
			Fx.shake(GameConfig.Water.JumpSeconds + 0.2, 0.3)
			Sfx.play("Splash", 0.6)
		end)
		return
	end
	-- Second Surge broadcast: the water has settled.
	if payload.playing then
		local margin = payload.height - payload.waterY
		if margin < GameConfig.Round.CloseCallStuds then
			Fx.callout("CLOSE CALL", Theme.Color.Yellow)
			Sfx.play("Pop", 0.8)
		end
	end
end

function Hud.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Hud") :: ScreenGui
	coinChip = gui:WaitForChild("CoinChip") :: Frame
	coinText = coinChip:WaitForChild("CoinText") :: TextLabel
	meter = gui:WaitForChild("WaterMeter") :: Frame
	marker = meter:WaitForChild("Marker") :: Frame
	target = meter:WaitForChild("Target") :: Frame
	answerBar = gui:WaitForChild("AnswerBar") :: Frame
	answerBox = answerBar:WaitForChild("AnswerBox") :: TextBox
	submitButton = answerBar:WaitForChild("SubmitButton") :: TextButton
	lockedCard = answerBar:WaitForChild("LockedText") :: Frame
	lockedText = lockedCard:WaitForChild("Text") :: TextLabel
	feedback = answerBar:WaitForChild("Feedback") :: Frame
	banner = gui:WaitForChild("Banner") :: Frame

	Ui.pressable(submitButton)
	submitButton.Activated:Connect(submit)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

function Hud.setCash(cash: number)
	coinText.Text = cash .. " CASH"
	Ui.bump(coinChip, 1.03)
end

function Hud.onState(payload)
	local phase = payload.phase
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	gui.Enabled = inMatch
	if not inMatch then
		lastPhase = phase
		lastWaterY = 0
		return
	end

	meter.Visible = payload.playing
	if payload.playing then
		updateMeter(payload)
	end

	-- Prompt phase only, so it never sits on top of the reveal card.
	local suddenDeath = phase == "Prompt" and payload.playing and payload.alive == GameConfig.Round.SuddenDeathAlive
	if suddenDeath and not banner.Visible then
		Ui.appear(banner)
	end
	banner.Visible = suddenDeath

	local newPrompt = phase == "Prompt" and (lastPhase ~= "Prompt" or payload.round ~= lastRound)
	if newPrompt then
		locked = false
		showEntry()
		if payload.playing then
			answerBar.Visible = true
			keepFocus()
		end
	end

	if phase == "Prompt" then
		answerBar.Visible = payload.playing
	else
		answerBar.Visible = false
		answerBox:ReleaseFocus()
	end

	if phase == "Surge" then
		onSurge(payload)
	end

	lastPhase = phase
	lastRound = payload.round
	lastWaterY = payload.waterY
end

return Hud
