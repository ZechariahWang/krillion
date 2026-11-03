--!strict
-- Drives StarterGui.LobbyQuiz: the warm-up prompt stream that pays coins while you wait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local RESULT_SECONDS = 1.6

local gui: ScreenGui
local header: TextLabel
local promptText: TextLabel
local timerFill: Frame
local answerBox: TextBox
local submitButton: TextButton
local skipButton: TextButton
local result: Frame
local resultTier: TextLabel
local resultCoins: TextLabel

local coins = 0
local promptToken = 0
local resultToken = 0

local LobbyQuiz = {}

local function submit()
	local text = answerBox.Text
	if #text == 0 then
		return
	end
	answerBox.Text = ""
	Net.event("LobbyQuizAnswer"):FireServer(text)
end

local function skip()
	answerBox.Text = ""
	Net.event("LobbyQuizSkip"):FireServer()
end

local function updateHeader()
	header.Text = "WARM-UP  ·  " .. coins .. " COINS"
end

function LobbyQuiz.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("LobbyQuiz") :: ScreenGui
	local panel = gui:WaitForChild("Panel")
	header = panel:WaitForChild("Header") :: TextLabel
	promptText = panel:WaitForChild("PromptText") :: TextLabel
	timerFill = panel:WaitForChild("TimerTrack"):WaitForChild("TimerFill") :: Frame
	answerBox = panel:WaitForChild("AnswerBox") :: TextBox
	submitButton = panel:WaitForChild("SubmitButton") :: TextButton
	skipButton = panel:WaitForChild("SkipButton") :: TextButton
	result = gui:WaitForChild("Result") :: Frame
	resultTier = result:WaitForChild("TierText") :: TextLabel
	resultCoins = result:WaitForChild("CoinsText") :: TextLabel

	Ui.pressable(submitButton)
	Ui.pressable(skipButton)
	submitButton.Activated:Connect(submit)
	skipButton.Activated:Connect(skip)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	updateHeader()
end

function LobbyQuiz.setCoins(value: number)
	coins = value
	updateHeader()
end

function LobbyQuiz.onPrompt(payload)
	promptToken += 1
	local token = promptToken
	if payload == nil then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	promptText.Text = payload.prompt
	Ui.pop(promptText)
	timerFill.Size = UDim2.fromScale(1, 1)
	Tween.play(timerFill, TweenInfo.new(payload.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
	task.delay(payload.seconds, function()
		if token == promptToken and gui.Enabled then
			skip()
		end
	end)
end

function LobbyQuiz.onResult(payload)
	resultToken += 1
	local token = resultToken
	if payload.tier ~= nil then
		local info = Tiers.ByName[payload.tier]
		resultTier.Text = string.upper(info.label)
		resultCoins.Text = "+" .. payload.coins .. " COINS"
		Sfx.play("Pop", 0.5)
	else
		resultTier.Text = "REFUSED"
		resultCoins.Text = ""
	end
	resultTier.TextColor3 = Ui.tierColor(payload.tier)
	if payload.tier == nil then
		resultTier.TextColor3 = Theme.Color.Danger
	end
	Ui.pop(result)
	task.delay(RESULT_SECONDS, function()
		if token == resultToken then
			result.Visible = false
		end
	end)
end

return LobbyQuiz
