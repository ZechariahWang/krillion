--!strict
-- Drives StarterGui.LobbyQuiz: the warm-up prompt stream that pays Cash while you wait.
-- A wrong answer is rejected right away and the same prompt stays up for another try.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local RESULT_SECONDS = 1.6

local gui: ScreenGui
local panel: Frame
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
local lastSentAt = 0

local LobbyQuiz = {}

-- Deferred so it runs after the TextBox has finished losing focus from the Enter press.
local function keepFocus()
	task.defer(function()
		if gui.Enabled then
			answerBox:CaptureFocus()
		end
	end)
end

local function submit()
	local text = answerBox.Text
	if #text == 0 then
		return
	end
	local now = os.clock()
	if now - lastSentAt < GameConfig.Answer.RetryCooldown then
		return
	end
	lastSentAt = now
	answerBox.Text = ""
	Net.event("LobbyQuizAnswer"):FireServer(text)
	keepFocus()
end

local function skip()
	answerBox.Text = ""
	Net.event("LobbyQuizSkip"):FireServer()
end

local function updateHeader()
	header.Text = "WARM-UP  |  " .. coins .. " CASH"
end

function LobbyQuiz.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("LobbyQuiz") :: ScreenGui
	panel = gui:WaitForChild("Panel") :: Frame
	header = panel:WaitForChild("HeaderBar"):WaitForChild("Header") :: TextLabel
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
	skipButton.Activated:Connect(function()
		skip()
		keepFocus()
	end)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	updateHeader()
end

function LobbyQuiz.setCash(value: number)
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
	promptText.Text = string.upper(payload.prompt)
	Ui.appear(promptText)
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
		-- Autocorrect: name the answer in the bank's spelling next to its tier.
		local corrected = payload.corrected or ""
		resultTier.Text = string.upper(info.label) .. "  |  " .. string.upper(corrected)
		resultTier.TextColor3 = Ui.tierColor(payload.tier)
		resultCoins.Text = "+" .. payload.cash .. " CASH"
		Ui.appear(result)
		Fx.coinPop("+" .. payload.cash, panel)
		Sfx.play("LockIn", 0.6)
	else
		resultTier.Text = "NOT IN THE BANK"
		resultTier.TextColor3 = Theme.Color.Red
		resultCoins.Text = "TRY AGAIN"
		Ui.appear(result)
		Ui.nudge(panel)
		Sfx.play("Wrong", 0.5)
	end
	task.delay(RESULT_SECONDS, function()
		if token == resultToken then
			result.Visible = false
		end
	end)
end

return LobbyQuiz
