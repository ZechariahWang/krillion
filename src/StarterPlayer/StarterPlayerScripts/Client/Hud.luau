--!strict
-- Drives StarterGui.Hud during a match: prompt, timer, answer box with instant feedback, alive chip, water meter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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
local promptCard: Frame
local roundLabel: TextLabel
local promptText: TextLabel
local timerFill: Frame
local timerChip: Frame
local timerText: TextLabel
local aliveText: TextLabel
local coinChip: Frame
local coinText: TextLabel
local meter: Frame
local marker: Frame
local answerBar: Frame
local answerBox: TextBox
local submitButton: TextButton
local lockedCard: Frame
local feedback: TextLabel
local banner: Frame

local locked = false
local lastSentAt = 0
local feedbackToken = 0
local lastRound = 0
local lastPhase = ""
local lastWaterY = 0
local promptTotal = 1

local Hud = {}

local function showLocked()
	answerBox:ReleaseFocus()
	answerBox.Visible = false
	submitButton.Visible = false
	Ui.pop(lockedCard)
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
end

local function showFeedback()
	feedbackToken += 1
	local token = feedbackToken
	Ui.pop(feedback)
	Ui.shake(answerBar, 0.3)
	task.delay(FEEDBACK_SECONDS, function()
		if token == feedbackToken then
			feedback.Visible = false
		end
	end)
end

function Hud.onAnswerResult(payload)
	if payload.accepted then
		locked = true
		showLocked()
		Sfx.play("LockIn", 0.7)
		Fx.flash(Theme.Color.Green)
		return
	end
	answerBox.Text = ""
	showFeedback()
	Sfx.play("Wrong", 0.5)
	if not UserInputService.TouchEnabled then
		answerBox:CaptureFocus()
	end
end

local function startTimer(seconds: number)
	promptTotal = math.max(seconds, 1)
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Theme.Color.Green
	Tween.play(timerFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
end

local function updateTimer(secondsLeft: number)
	local fraction = secondsLeft / promptTotal
	local color = Ui.timerColor(fraction)
	timerChip.BackgroundColor3 = color
	timerFill.BackgroundColor3 = color
	timerText.Text = tostring(secondsLeft)
	if secondsLeft <= GameConfig.Round.DangerSeconds then
		Ui.bump(timerChip, 1.35)
		Ui.shake(timerChip, 0.25)
		Sfx.play("Tick", 0.5)
	else
		Ui.bump(timerChip, 1.12)
	end
end

local function updateMeter(height: number, waterY: number)
	local margin = math.clamp((height - waterY) / METER_RANGE, 0, 1)
	local y = 1 - METER_WATER - margin * (1 - METER_WATER)
	Tween.play(marker, Theme.Tween.Enter, { Position = UDim2.fromScale(0.5, y) })
	if margin < 0.15 then
		marker.BackgroundColor3 = Theme.Color.Red
	else
		marker.BackgroundColor3 = Theme.Color.Yellow
	end
end

local function onSurge(payload)
	if payload.waterY == lastWaterY then
		-- First Surge broadcast: the water is about to move. Rumble, then a hard jolt on the jump.
		Fx.shake(GameConfig.Water.CreepSeconds, 0.15)
		task.delay(GameConfig.Water.CreepSeconds, function()
			Fx.shake(GameConfig.Water.JumpSeconds + 0.3, 0.7)
			Sfx.play("Splash", 0.6)
		end)
		return
	end
	-- Second Surge broadcast: the water has settled.
	if payload.playing then
		local margin = payload.height - payload.waterY
		if margin < GameConfig.Round.CloseCallStuds then
			Fx.callout("CLOSE CALL!", Theme.Color.Yellow)
			Sfx.play("Pop", 0.8)
		end
	end
end

function Hud.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Hud") :: ScreenGui
	promptCard = gui:WaitForChild("PromptCard") :: Frame
	roundLabel = promptCard:WaitForChild("Header"):WaitForChild("RoundLabel") :: TextLabel
	promptText = promptCard:WaitForChild("PromptText") :: TextLabel
	timerFill = promptCard:WaitForChild("TimerTrack"):WaitForChild("TimerFill") :: Frame
	timerChip = gui:WaitForChild("TimerChip") :: Frame
	timerText = timerChip:WaitForChild("TimerText") :: TextLabel
	aliveText = gui:WaitForChild("AliveChip"):WaitForChild("AliveText") :: TextLabel
	coinChip = gui:WaitForChild("CoinChip") :: Frame
	coinText = coinChip:WaitForChild("CoinText") :: TextLabel
	meter = gui:WaitForChild("WaterMeter") :: Frame
	marker = meter:WaitForChild("Marker") :: Frame
	answerBar = gui:WaitForChild("AnswerBar") :: Frame
	answerBox = answerBar:WaitForChild("AnswerBox") :: TextBox
	submitButton = answerBar:WaitForChild("SubmitButton") :: TextButton
	lockedCard = answerBar:WaitForChild("LockedText") :: Frame
	feedback = answerBar:WaitForChild("Feedback") :: TextLabel
	banner = gui:WaitForChild("Banner") :: Frame

	Ui.pressable(submitButton)
	submitButton.Activated:Connect(submit)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

function Hud.setCoins(coins: number)
	coinText.Text = coins .. " COINS"
	Ui.bump(coinChip, 1.15)
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

	roundLabel.Text = "ROUND " .. payload.round
	if payload.prompt ~= nil then
		promptText.Text = payload.prompt
	end
	aliveText.Text = payload.alive .. " ALIVE"
	meter.Visible = payload.playing
	if payload.playing then
		updateMeter(payload.height, payload.waterY)
	end

	local suddenDeath = payload.playing and payload.alive == GameConfig.Round.SuddenDeathAlive
	if suddenDeath and not banner.Visible then
		Ui.slam(banner)
	end
	banner.Visible = suddenDeath

	local newPrompt = phase == "Prompt" and (lastPhase ~= "Prompt" or payload.round ~= lastRound)
	if newPrompt then
		locked = false
		showEntry()
		startTimer(payload.secondsLeft)
		Ui.pop(promptCard)
		Sfx.play("Pop", 0.5)
		if payload.playing and not UserInputService.TouchEnabled then
			answerBox:CaptureFocus()
		end
	end

	if phase == "Prompt" then
		timerChip.Visible = true
		updateTimer(payload.secondsLeft)
		answerBar.Visible = payload.playing
	else
		timerChip.Visible = false
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
