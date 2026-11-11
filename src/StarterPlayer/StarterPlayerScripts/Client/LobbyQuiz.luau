--!strict
-- Drives LobbyUi.LobbyQuiz: the warm-up prompt window that opens when you step into the semicircle in front of
-- the snack shack and pays Shells while you wait, up to a daily cap. It is a window (Client/Windows): the X or
-- stepping out closes it, and a match closes it from the server side.
-- Enter checks the answer, Enter again locks it in (like a match). A wrong answer is rejected right away and
-- the same prompt stays up for another try. A locked answer plays your dive full screen (the match's own
-- DiveCards stage, through Reveal), then NEXT counts down. ConfirmChip is a Studio template cloned in, unless
-- the place already has it authored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local DiveCard = require(script.Parent.DiveCard)
local Fx = require(script.Parent.Fx)
local Reveal = require(script.Parent.Reveal)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local RESULT_SECONDS = 1.6
local RETRY_SECONDS = 0.08 -- a check that raced the server's cooldown is retried once, this much later
local TEMPLATE_WAIT = 10
local WAIT_SECONDS = 10 -- most seconds to wait for the authored screen and its children before giving up
local ready = false
local missing: string? = nil
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
local engaged = false -- the player clicked the box or pressed Enter this visit; new prompts may take focus
local held = false -- a prompt arrived while another window was open; ask for a fresh one once it closes

local LobbyQuiz = {}

local closeQuiz: () -> ()

-- Takes the window down without telling the server (it already stopped, or is about to).
local function hideQuiz()
	if not gui.Visible then
		return
	end
	gui.Visible = false
	result.Visible = false
	engaged = false
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
	return Ui.isPhone()
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
		.. Currency.Upper
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
		confirmText.Text = "LOCK IN  " .. string.upper(corrected) .. "?  " .. action
	end
	if confirmChip ~= nil then
		Ui.pop(confirmChip)
	end
	submitButton.Text = "LOCK IN"
	Sfx.play("Ping", 0.3)
end

local function clearCard()
	if card ~= nil then
		card = nil
		Reveal.hideOwnCard(true)
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
	local handle = Reveal.showOwnCard({
		title = "YOUR DIVE",
		isYou = true,
		answer = payload.corrected,
		tier = payload.tier,
		depth = if typeof(payload.depth) == "number" then payload.depth else 0,
		shells = payload.cash,
	})
	if handle == nil then
		-- No stage: fall back to the text result.
		local info = Tiers.ByName[payload.tier]
		local label = if info ~= nil then string.upper(info.label) else ""
		showMessage(label .. "  |  " .. string.upper(payload.corrected or ""), "+" .. Currency.format(payload.cash), Ui.tierColor(payload.tier))
		return
	end
	card = handle
	task.spawn(function()
		handle.finished()
		if token ~= promptToken or card ~= handle then
			return
		end
		if payload.cash > 0 and handle.frame ~= nil then
			Fx.coinPop("+" .. Currency.format(payload.cash), handle.frame)
		end
		-- Held like a match card, then it shrinks away and the panel is back for NEXT.
		task.wait(GameConfig.Reveal.CardHoldSeconds)
		if token == promptToken and card == handle then
			card = nil
			Reveal.hideOwnCard(false)
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
	-- The window pops up whole and the dive plays full screen: the old in-panel ResultCard and tuck-away
	-- CollapseButton are not adopted.
	for _, old in { panel:FindFirstChild("ResultCard"), headerBar:FindFirstChild("CollapseButton") } do
		if old ~= nil then
			old:Destroy()
		end
	end
end

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

function LobbyQuiz.init(playerGui: PlayerGui)
	local guiFound = Ui.screen(playerGui, "LobbyQuiz", WAIT_SECONDS)
	local panelFound = waitChild(guiFound, "Panel")
	local headerBarFound = waitChild(panelFound, "HeaderBar")
	local headerFound = waitChild(headerBarFound, "Header")
	local promptFound = waitChild(panelFound, "PromptText")
	local timerFillFound = waitChild(waitChild(panelFound, "TimerTrack"), "TimerFill")
	local answerBoxFound = waitChild(panelFound, "AnswerBox")
	local submitFound = waitChild(panelFound, "SubmitButton")
	local skipFound = waitChild(panelFound, "SkipButton")
	local resultFound = waitChild(guiFound, "Result")
	local tierFound = waitChild(resultFound, "TierText")
	local coinsFound = waitChild(resultFound, "CoinsText")
	if guiFound == nil or missing ~= nil then
		warn("LobbyQuiz: LobbyUi.LobbyQuiz is missing " .. (missing or "entirely") .. "; no warm-up quiz")
		return
	end
	gui = guiFound :: Frame
	panel = panelFound :: Frame
	headerBar = headerBarFound :: Frame
	header = headerFound :: TextLabel
	promptText = promptFound :: TextLabel
	timerFill = timerFillFound :: Frame
	answerBox = answerBoxFound :: TextBox
	submitButton = submitFound :: TextButton
	skipButton = skipFound :: TextButton
	result = resultFound :: Frame
	resultTier = tierFound :: TextLabel
	resultCoins = coinsFound :: TextLabel
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
	answerBox.Focused:Connect(function()
		engaged = true
	end)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			engaged = true
			submit()
		end
	end)
	-- Any edit cancels a pending lock-in, so only the answer that was checked can be locked.
	answerBox:GetPropertyChangedSignal("Text"):Connect(function()
		if confirmed ~= nil and trim(answerBox.Text) ~= confirmed then
			hideConfirm()
		end
	end)
	Windows.Changed.connect(function()
		if held and not Windows.anyOpen() then
			held = false
			skip()
		end
	end)
	updateHeader()
	task.spawn(bindExtras)
	ready = true
end

-- The wallet chip shows the balance; the header shows today's warm-up progress instead, which arrives
-- with each prompt and result.
function LobbyQuiz.setCash(_value: number) end

function LobbyQuiz.onPrompt(payload)
	if not ready then
		return
	end
	held = false
	-- Stepping on to the arc never replaces a window that is already up (the tutorial, the shop): wait for it.
	if payload ~= nil and not gui.Visible and Windows.anyOpen() then
		held = true
		return
	end
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
		Windows.opened(closeQuiz, { keepStatus = true })
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
		if token == promptToken and gui.Visible and not locked then
			skip()
		end
	end)
	-- Walking onto the arc must not take the keyboard from movement, and a touch keyboard never pops by itself.
	if engaged and not Ui.isPhone() then
		keepFocus()
	end
end

function LobbyQuiz.onResult(payload)
	if not ready then
		return
	end
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
