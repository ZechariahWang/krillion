--!strict
-- Drives LobbyUi.LobbyQuiz: the warm-up prompt window that opens when you step into the semicircle in front of
-- the snack shack and pays Shells while you wait, up to a daily cap. It is a window (Client/Windows): the X or
-- stepping out closes it, and a match closes it from the server side.
-- Enter checks the answer, Enter again locks it in (like a match). A wrong answer is rejected right away and
-- the same prompt stays up for another try. A locked answer plays a mini dive card, then NEXT counts down.
-- ConfirmChip and LobbyQuizExtras (ResultCard, CollapseButton) are Studio templates cloned in, unless
-- the place already has them authored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local DiveCard = require(script.Parent.DiveCard)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local RESULT_SECONDS = 1.6
local RETRY_SECONDS = 0.08 -- a check that raced the server's cooldown is retried once, this much later
local TEMPLATE_WAIT = 10
local CAP_PROMPT_TEXT = "THAT'S TODAY'S WARM-UP LIMIT: MATCHES STILL PAY!"
local CAP_RESULT_TEXT = "WARM-UP SHELLS MAXED TODAY: MATCHES STILL PAY!"

local gui: Frame
local panel: Frame
local headerBar: Frame
local header: TextLabel
local promptText: TextLabel
local timerFill: Frame
local answerBox: TextBox
local submitButton: TextButton
local skipButton: TextButton
local result: Frame
local resultTier: TextLabel
local resultCoins: TextLabel
local confirmChip: Frame? = nil
local confirmText: TextLabel? = nil
local cardHolder: Frame? = nil

local submitText = ""
local skipText = ""
local basePosition: UDim2

local earnedToday = 0
local dailyCap = GameConfig.Lobby.DailyShellCap
local capNoticeShown = false -- the cap message shows once a session

local promptToken = 0
local resultToken = 0
local promptEndsAt = 0 -- os.clock() when the current prompt's timer runs out
local confirmed: string? = nil -- the trimmed text the server found in the bank; Enter again locks it in
local checking: string? = nil
local submitting = false
local retried = false
local locked = false -- the current prompt is answered; NEXT is counting down
local lastCheckAt = -math.huge
local lastWrongAt = -math.huge
local card: DiveCard.Handle? = nil

local LobbyQuiz = {}

local closeQuiz: () -> ()

-- Takes the window down without telling the server (it already stopped, or is about to).
local function hideQuiz()
	if not gui.Visible then
		return
	end
	gui.Visible = false
	result.Visible = false
	Windows.closed(closeQuiz)
end

-- The X, or another window opening over this one: the server stops the stream until you step out and back.
function closeQuiz()
	hideQuiz()
	Net.event("LobbyQuizStop"):FireServer()
end

local function trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

-- Phones and tablets have no Enter key to press twice.
local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- One frame later: a focus grab in the same frame as the Enter press that released the box is dropped.
local function keepFocus()
	task.delay(0, function()
		if gui.Visible and not locked then
			answerBox:CaptureFocus()
		end
	end)
end

local function updateHeader()
	header.Text = "WARM-UP  |  "
		.. Currency.digits(math.min(earnedToday, dailyCap))
		.. "/"
		.. Currency.digits(dailyCap)
		.. " "
		.. Theme.Icon.Shell
		.. " TODAY"
end

local function setProgress(payload: { [string]: any })
	if typeof(payload.earnedToday) == "number" then
		earnedToday = payload.earnedToday
	end
	if typeof(payload.cap) == "number" then
		dailyCap = payload.cap
	end
	updateHeader()
end

local function showCapNotice(text: string)
	if capNoticeShown then
		return
	end
	capNoticeShown = true
	Toasts.show(text, "info")
end

local function showMessage(title: string, subtitle: string, color: Color3)
	resultToken += 1
	local token = resultToken
	resultTier.Text = title
	resultTier.TextColor3 = color
	resultCoins.Text = subtitle
	Ui.appear(result)
	task.delay(RESULT_SECONDS, function()
		if token == resultToken then
			result.Visible = false
		end
	end)
end

local function hideConfirm()
	confirmed = nil
	if confirmChip ~= nil then
		confirmChip.Visible = false
	end
	submitButton.Text = submitText
end

local function showConfirm(text: string, corrected: string)
	confirmed = text
	resultToken += 1
	result.Visible = false
	local action = if isTouch() then "TAP LOCK IN" else "PRESS ENTER AGAIN"
	if confirmText ~= nil then
		confirmText.Text = Theme.Icon.Lock .. " LOCK IN  " .. string.upper(corrected) .. "?  " .. action
	end
	if confirmChip ~= nil then
		Ui.pop(confirmChip)
	end
	submitButton.Text = "LOCK IN"
	Sfx.play("Ping", 0.3)
end

local function clearCard()
	if card ~= nil then
		card.destroy()
		card = nil
	end
	if cardHolder ~= nil then
		cardHolder.Visible = false
	end
end

local function skip()
	answerBox.Text = ""
	Net.event("LobbyQuizSkip"):FireServer()
end

-- Answering -----------------------------------------------------------------------------------------------

local function sendCheck(text: string)
	local now = os.clock()
	if now - lastCheckAt < GameConfig.Answer.CheckMinInterval or now - lastWrongAt < GameConfig.Answer.RetryCooldown then
		return
	end
	lastCheckAt = now
	checking = text
	retried = false
	Net.event("LobbyQuizCheck"):FireServer(text)
end

-- Enter (or ANSWER): the first press checks the answer; a second press with the same text locks it in.
local function submit()
	if locked or submitting then
		return
	end
	local text = trim(answerBox.Text)
	if #text == 0 then
		return
	end
	if confirmed ~= nil and text == confirmed then
		submitting = true
		retried = false
		Net.event("LobbyQuizAnswer"):FireServer(text)
		return
	end
	sendCheck(text)
	keepFocus()
end

local function wrongAnswer()
	lastWrongAt = os.clock()
	answerBox.Text = ""
	hideConfirm()
	showMessage("NOT IN THE BANK", "TRY AGAIN", Theme.Color.Red)
	Ui.nudge(panel)
	Sfx.play("Wrong", 0.5)
	keepFocus()
end

local function deny(title: string, subtitle: string)
	hideConfirm()
	showMessage(title, subtitle, Theme.Color.Red)
	Sfx.play("Wrong", 0.4)
end

local function onCheckResult(payload)
	local text = checking
	checking = nil
	if locked or text == nil then
		return
	end
	local status = payload.status
	if status == "cooldown" then
		if not retried and text == trim(answerBox.Text) then
			retried = true
			checking = text
			task.delay(RETRY_SECONDS, function()
				if not locked and checking == text then
					Net.event("LobbyQuizCheck"):FireServer(text)
				end
			end)
		end
		return
	end
	retried = false
	if status == "valid" then
		-- Typing on while the check was in flight means the player moved on from that answer.
		if text == trim(answerBox.Text) then
			showConfirm(text, payload.corrected or text)
		end
	elseif status == "invalid" then
		wrongAnswer()
	elseif status == "limit" then
		deny("THAT'S A LOT OF CHECKS", "LOCK ONE IN OR SKIP")
	elseif status == "closed" then
		deny("TIME'S UP", "NEXT ONE COMING")
	end
end

-- NEXT counts down on the skip button and moves on by itself; pressing it moves on at once.
local function startNextCountdown(token: number)
	task.spawn(function()
		for left = GameConfig.Lobby.AutoNextSeconds, 1, -1 do
			if token ~= promptToken or not locked then
				return
			end
			skipButton.Text = "NEXT ▶ " .. left
			task.wait(1)
		end
		if token == promptToken and locked and gui.Visible then
			skip()
		end
	end)
end

local function playCard(payload, token: number)
	clearCard()
	local holder = cardHolder
	if holder == nil then
		-- No holder: fall back to the text result.
		local info = Tiers.ByName[payload.tier]
		local label = if info ~= nil then string.upper(info.label) else ""
		showMessage(label .. "  |  " .. string.upper(payload.corrected or ""), "+" .. Currency.format(payload.cash), Ui.tierColor(payload.tier))
		return
	end
	local anchor: Frame = holder
	anchor.Visible = true
	local handle = DiveCard.play(anchor, {
		title = "YOUR DIVE",
		isYou = true,
		answer = payload.corrected,
		tier = payload.tier,
		depth = if typeof(payload.depth) == "number" then payload.depth else 0,
		quick = false,
		scale = 1,
	})
	card = handle
	task.spawn(function()
		handle.finished()
		if token ~= promptToken or card ~= handle then
			return
		end
		local from: GuiObject = handle.frame or anchor
		if payload.cash > 0 then
			Fx.coinPop("+" .. Currency.digits(payload.cash) .. " " .. Theme.Icon.Shell, from)
		end
	end)
end

local function onSubmitResult(payload)
	submitting = false
	if payload.status == "valid" and payload.tier ~= nil then
		locked = true
		hideConfirm()
		resultToken += 1
		result.Visible = false
		setProgress(payload)
		-- Autocorrect: show the answer in the bank's spelling, whatever was typed.
		answerBox:ReleaseFocus()
		answerBox.Text = string.upper(payload.corrected or answerBox.Text)
		answerBox.TextEditable = false
		submitButton.Visible = false
		Tween.cancel(timerFill)
		Sfx.play("LockIn", 0.6)
		local token = promptToken
		playCard(payload, token)
		if payload.capped then
			showCapNotice(CAP_RESULT_TEXT)
		end
		startNextCountdown(token)
		return
	end
	local status = payload.status
	if status == "cooldown" and not retried and confirmed ~= nil then
		retried = true
		submitting = true
		local text = confirmed
		task.delay(RETRY_SECONDS, function()
			if not locked then
				Net.event("LobbyQuizAnswer"):FireServer(text)
			end
		end)
		return
	end
	retried = false
	hideConfirm()
	if status == "closed" then
		deny("TIME'S UP", "NEXT ONE COMING")
	elseif status == "limit" then
		deny("THAT'S A LOT OF CHECKS", "LOCK ONE IN OR SKIP")
	elseif status == "cooldown" then
		keepFocus()
	else
		wrongAnswer()
	end
end

-- Collapse ------------------------------------------------------------------------------------------------

-- Collapsed, the panel slides down until only its header bar shows above the bottom edge.
-- Setup ---------------------------------------------------------------------------------------------------

local function findTemplate(name: string): Instance?
	local templates = ReplicatedStorage:WaitForChild("Templates", TEMPLATE_WAIT)
	return if templates ~= nil then templates:WaitForChild(name, TEMPLATE_WAIT) else nil
end

-- An element authored in the place wins; otherwise the git template is cloned in. Waits for the template,
-- so call it off the init thread.
local function adopt(parent: Instance, name: string, source: Instance?): Instance?
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		return existing
	end
	if source == nil then
		warn("LobbyQuiz: no " .. name .. " template; that part of the warm-up is off")
		return nil
	end
	local clone = source:Clone()
	clone.Parent = parent
	return clone
end

local function bindExtras()
	-- The confirm chip and the result card sit above the panel's top edge.
	panel.ClipsDescendants = false
	local chip = adopt(panel, "ConfirmChip", findTemplate("ConfirmChip"))
	if chip ~= nil and chip:IsA("Frame") then
		chip.Visible = false
		confirmChip = chip
		local label = chip:FindFirstChild("Text")
		if label ~= nil and label:IsA("TextLabel") then
			confirmText = label
		end
	end
	local extras = findTemplate("LobbyQuizExtras")
	local holder = adopt(panel, "ResultCard", if extras ~= nil then extras:FindFirstChild("ResultCard") else nil)
	if holder ~= nil and holder:IsA("Frame") then
		holder.Visible = false
		cardHolder = holder
	end
	-- The window pops up whole; the old tuck-away CollapseButton is not adopted.
	local tucked = headerBar:FindFirstChild("CollapseButton")
	if tucked ~= nil then
		tucked:Destroy()
	end
end

function LobbyQuiz.init(playerGui: PlayerGui)
	gui = Ui.screen(playerGui, "LobbyQuiz") :: Frame
	panel = gui:WaitForChild("Panel") :: Frame
	headerBar = panel:WaitForChild("HeaderBar") :: Frame
	header = headerBar:WaitForChild("Header") :: TextLabel
	promptText = panel:WaitForChild("PromptText") :: TextLabel
	timerFill = panel:WaitForChild("TimerTrack"):WaitForChild("TimerFill") :: Frame
	answerBox = panel:WaitForChild("AnswerBox") :: TextBox
	submitButton = panel:WaitForChild("SubmitButton") :: TextButton
	skipButton = panel:WaitForChild("SkipButton") :: TextButton
	result = gui:WaitForChild("Result") :: Frame
	resultTier = result:WaitForChild("TierText") :: TextLabel
	resultCoins = result:WaitForChild("CoinsText") :: TextLabel
	submitText = submitButton.Text
	skipText = skipButton.Text
	basePosition = panel.Position
	local close = panel:FindFirstChild("CloseButton")
	if close ~= nil and close:IsA("GuiButton") then
		Ui.pressable(close)
		close.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			closeQuiz()
		end)
	end

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
	-- Any edit cancels a pending lock-in, so only the answer that was checked can be locked.
	answerBox:GetPropertyChangedSignal("Text"):Connect(function()
		if confirmed ~= nil and trim(answerBox.Text) ~= confirmed then
			hideConfirm()
		end
	end)
	updateHeader()
	task.spawn(bindExtras)
end

-- The wallet chip shows the balance; the header shows today's warm-up progress instead, which arrives
-- with each prompt and result.
function LobbyQuiz.setCash(_value: number) end

function LobbyQuiz.onPrompt(payload)
	promptToken += 1
	local token = promptToken
	locked = false
	submitting = false
	checking = nil
	retried = false
	hideConfirm()
	clearCard()
	if payload == nil then
		hideQuiz()
		return
	end
	if not gui.Visible then
		gui.Visible = true
		Sfx.play("Open", 0.5)
		Ui.pop(panel, 0.8)
		Windows.opened(closeQuiz)
	end
	setProgress(payload)
	if payload.capped then
		showCapNotice(CAP_PROMPT_TEXT)
	end
	answerBox.Text = ""
	answerBox.TextEditable = true
	submitButton.Visible = true
	skipButton.Text = skipText
	promptText.Text = string.upper(payload.prompt)
	Ui.appear(promptText)
	promptEndsAt = os.clock() + payload.seconds
	timerFill.Size = UDim2.fromScale(1, 1)
	Tween.play(timerFill, TweenInfo.new(payload.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
	task.delay(payload.seconds, function()
		-- Tucked away, the prompt waits; opening the panel asks for a fresh one.
		if token == promptToken and gui.Visible and not locked then
			skip()
		end
	end)
	keepFocus()
end

function LobbyQuiz.onResult(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.stage == "check" then
		onCheckResult(payload)
	else
		onSubmitResult(payload)
	end
end

return LobbyQuiz
