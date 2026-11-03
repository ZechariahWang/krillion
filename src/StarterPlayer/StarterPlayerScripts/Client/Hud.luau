--!strict
-- Drives StarterGui.Hud during a match: prompt, timer, answer box, alive chip, water meter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local METER_RANGE = 30 -- studs of margin that fills the whole meter
local METER_WATER = 0.2 -- fraction of the meter the water fill occupies

local gui: ScreenGui
local roundLabel: TextLabel
local promptText: TextLabel
local timerFill: Frame
local timerChip: Frame
local timerText: TextLabel
local aliveText: TextLabel
local coinText: TextLabel
local meter: Frame
local marker: Frame
local answerBar: Frame
local answerBox: TextBox
local submitButton: TextButton
local lockedText: TextLabel
local banner: Frame

local locked = false
local lastRound = 0
local lastPhase = ""

local Hud = {}

local function lockIn()
	if locked then
		return
	end
	local text = answerBox.Text
	if #text == 0 then
		return
	end
	locked = true
	Net.event("SubmitAnswer"):FireServer(text)
	answerBox:ReleaseFocus()
	answerBox.Visible = false
	submitButton.Visible = false
	lockedText.Visible = true
	Ui.pop(lockedText)
	Sfx.play("LockIn")
end

local function unlock()
	locked = false
	answerBox.Text = ""
	answerBox.Visible = true
	submitButton.Visible = true
	lockedText.Visible = false
end

local function startTimer(seconds: number)
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Theme.Color.Accent
	Tween.play(timerFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
end

local function updateMeter(height: number, waterY: number)
	local margin = math.clamp((height - waterY) / METER_RANGE, 0, 1)
	local y = 1 - METER_WATER - margin * (1 - METER_WATER)
	Tween.play(marker, Theme.Tween.Enter, { Position = UDim2.fromScale(0.5, y) })
	if margin < 0.15 then
		marker.BackgroundColor3 = Theme.Color.Danger
	else
		marker.BackgroundColor3 = Theme.Color.Text
	end
end

function Hud.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Hud") :: ScreenGui
	local promptCard = gui:WaitForChild("PromptCard")
	roundLabel = promptCard:WaitForChild("RoundLabel") :: TextLabel
	promptText = promptCard:WaitForChild("PromptText") :: TextLabel
	timerFill = promptCard:WaitForChild("TimerTrack"):WaitForChild("TimerFill") :: Frame
	timerChip = gui:WaitForChild("TimerChip") :: Frame
	timerText = timerChip:WaitForChild("TimerText") :: TextLabel
	aliveText = gui:WaitForChild("AliveChip"):WaitForChild("AliveText") :: TextLabel
	coinText = gui:WaitForChild("CoinChip"):WaitForChild("CoinText") :: TextLabel
	meter = gui:WaitForChild("WaterMeter") :: Frame
	marker = meter:WaitForChild("Marker") :: Frame
	answerBar = gui:WaitForChild("AnswerBar") :: Frame
	answerBox = answerBar:WaitForChild("AnswerBox") :: TextBox
	submitButton = answerBar:WaitForChild("SubmitButton") :: TextButton
	lockedText = answerBar:WaitForChild("LockedText") :: TextLabel
	banner = gui:WaitForChild("Banner") :: Frame

	Ui.pressable(submitButton)
	submitButton.Activated:Connect(lockIn)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			lockIn()
		end
	end)
end

function Hud.setCoins(coins: number)
	coinText.Text = coins .. " COINS"
end

function Hud.onState(payload)
	local phase = payload.phase
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	gui.Enabled = inMatch
	if not inMatch then
		lastPhase = phase
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
		Ui.pop(banner)
	end
	banner.Visible = suddenDeath

	local newPrompt = phase == "Prompt" and (lastPhase ~= "Prompt" or payload.round ~= lastRound)
	if newPrompt then
		unlock()
		startTimer(payload.secondsLeft)
		Ui.pop(promptText)
		if payload.playing and not UserInputService.TouchEnabled then
			answerBox:CaptureFocus()
		end
	end

	if phase == "Prompt" then
		timerChip.Visible = true
		timerText.Text = tostring(payload.secondsLeft)
		local danger = payload.secondsLeft <= GameConfig.Round.DangerSeconds
		if danger then
			timerText.TextColor3 = Theme.Color.Danger
			timerFill.BackgroundColor3 = Theme.Color.Danger
			Ui.pulse(timerChip, true)
			Sfx.play("Tick", 0.3)
		else
			timerText.TextColor3 = Theme.Color.Text
			Ui.pulse(timerChip, false)
		end
		answerBar.Visible = payload.playing
	else
		timerChip.Visible = false
		Ui.pulse(timerChip, false)
		answerBar.Visible = false
		answerBox:ReleaseFocus()
	end

	lastPhase = phase
	lastRound = payload.round
end

return Hud
