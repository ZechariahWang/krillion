--!strict
-- Drives StarterGui.Hud during a match: the answer box (Enter checks the answer, Enter again locks it in),
-- the Hint and +10s boost chips, Shells, water meter, sudden-death card.
-- The prompt, timer and alive count live in StarterGui.Status (see Status.luau); surge feedback in Tide.luau.
-- ConfirmChip, HintRow and BoostBar are Studio templates (ReplicatedStorage.Templates) cloned into
-- Hud.AnswerBar, unless the place already has them authored there.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local METER_RANGE = 30 -- studs of margin that fills the whole meter
local METER_WATER = 0.2 -- fraction of the meter the water fill occupies
local FEEDBACK_SECONDS = 1.5
local RETRY_SECONDS = 0.08 -- a check that raced the server's cooldown is retried once, this much later
local TEMPLATE_WAIT = 10
local DISABLED_FACE = Color3.fromRGB(88, 100, 124)
local BOOST_GAP = 8 -- pixels between the Standings tab and the boost buttons above it
local BOOST_EDGE = 16 -- pixels from the screen edges when there is no Standings tab to stand on
local BOOST_MIN_SCALE = 0.6 -- the smallest the boost buttons shrink to on a short screen
local BOOST_DESIGN_HEIGHT = 820 -- screen height the boost buttons are drawn for
local PRICE_SHELLS = Color3.fromRGB(255, 217, 94) -- shell gold
local PRICE_SHORT = Color3.fromRGB(255, 130, 112) -- not enough Shells
local PRICE_ROBUX = Color3.fromRGB(120, 235, 140)
local PRICE_OWNED = Color3.fromRGB(255, 255, 255)

local INVALID_TEXT = "NOT IN THE BANK  |  TRY AGAIN"
local BOOST_MESSAGES: { [string]: string } = {
	no_shells = "NOT ENOUGH " .. Currency.Upper,
	none = "NO HINT FOR THIS ONE",
	closed = "TIME'S UP",
	locked = "ALREADY LOCKED IN",
	pending = "FINISHING YOUR PURCHASE...",
}

type BoostChip = {
	button: TextButton,
	price: TextLabel,
	uses: TextLabel,
	face: Color3,
}

local playerGui: PlayerGui
local gui: Frame
local meter: Frame
local marker: Frame
local target: Frame
local answerBar: Frame
local answerBox: TextBox
local submitButton: TextButton
local lockedCard: Frame
local lockedText: TextLabel
local feedback: Frame
local feedbackText: TextLabel?
local banner: Frame
local confirmChip: Frame? = nil
local confirmText: TextLabel? = nil
local hintRow: Frame? = nil
local hintText: TextLabel? = nil
local boostBar: Frame? = nil
local boostChips: { [string]: BoostChip } = {}

local locked = false
local playing = false
local phase = ""
local outOfTime = false -- overtime that is not yours: the prompt is open only for someone else
local buttonText = "GO"
local lastCheckAt = -math.huge
local lastWrongAt = -math.huge
local lastBoostAt = -math.huge
local checking: string? = nil -- the trimmed text of the check in flight
local confirmed: string? = nil -- the trimmed text the server found in the bank; Enter again locks it in
local submitting = false
local retried = false
local feedbackToken = 0
local lastRound = 0
local lastPhase = ""
local inventory = { Hint = 0, ExtraTime = 0 }
local cash = 0
local uses: Net.BoostUses = { Hint = 0, ExtraTime = 0 }

local Hud = {}

local function trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") :: string
end

local function usesOf(kind: string): number
	return if kind == "Hint" then uses.Hint else uses.ExtraTime
end

local function inventoryOf(kind: string): number
	return if kind == "Hint" then inventory.Hint else inventory.ExtraTime
end

local function costOf(kind: string): number
	return if kind == "Hint" then GameConfig.Boosts.HintShells else GameConfig.Boosts.ExtraTimeShells
end

local function productOf(kind: string): { productId: number, robux: number }
	return if kind == "Hint" then Products.Boosts.Hint else Products.Boosts.ExtraTime
end

-- Phones and tablets have no Enter key to press twice.
local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Deferred so it runs after the TextBox has finished losing focus from the Enter press.
local function keepFocus()
	task.defer(function()
		if answerBox.Visible and answerBar.Visible then
			answerBox:CaptureFocus()
		end
	end)
end

local function showFeedback(text: string)
	feedbackToken += 1
	local token = feedbackToken
	if feedbackText ~= nil then
		feedbackText.Text = text
	end
	if confirmChip ~= nil then
		confirmChip.Visible = false
	end
	Ui.appear(feedback)
	Ui.nudge(answerBar)
	task.delay(FEEDBACK_SECONDS, function()
		if token == feedbackToken then
			feedback.Visible = false
		end
	end)
end

local function hideConfirm()
	confirmed = nil
	if confirmChip ~= nil then
		confirmChip.Visible = false
	end
	submitButton.Text = buttonText
end

local function showConfirm(text: string, corrected: string)
	confirmed = text
	feedbackToken += 1
	feedback.Visible = false
	local action = if isTouch() then "TAP LOCK IN" else "PRESS ENTER AGAIN"
	if confirmText ~= nil then
		confirmText.Text = Theme.Icon.Lock .. " LOCK IN  " .. string.upper(corrected) .. "?  " .. action
	end
	if confirmChip ~= nil then
		Ui.pop(confirmChip)
	end
	submitButton.Text = "LOCK IN"
	Sfx.play("Ping", 0.35)
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
	hideConfirm()
	if hintRow ~= nil then
		hintRow.Visible = false
	end
end

-- Boosts --------------------------------------------------------------------------------------------------

local function boostsShown(): boolean
	return GameConfig.Boosts.Enabled == 1 and phase == "Prompt" and playing and not locked and not outOfTime
end

-- The Standings tab docked above the Shells chip in the bottom-right corner, while it shows.
local function standingsTab(): GuiObject?
	local screen = Ui.findScreen(playerGui, "Standings")
	local root = if screen ~= nil then screen:FindFirstChild("Root") else nil
	local tab = if root ~= nil then root:FindFirstChild("Tab") else nil
	if screen ~= nil and screen.Visible and tab ~= nil and tab:IsA("GuiObject") and tab.AbsoluteSize.X > 0 then
		return tab
	end
	return nil
end

-- The boost buttons stand in the bottom-right column, right above the Standings tab (which sits on the
-- Shells chip), right edges lined up, and shrink with the screen height like the rest of the column.
local function fitBoostBar()
	local bar = boostBar
	if bar == nil then
		return
	end
	local scale = bar:FindFirstChild("Fit")
	if scale == nil or not scale:IsA("UIScale") then
		return
	end
	local origin = gui.AbsolutePosition
	local right = gui.AbsoluteSize.X - BOOST_EDGE
	local bottom = gui.AbsoluteSize.Y - BOOST_EDGE
	local tab = standingsTab()
	if tab ~= nil then
		right = tab.AbsolutePosition.X + tab.AbsoluteSize.X - origin.X
		bottom = tab.AbsolutePosition.Y - origin.Y - BOOST_GAP
	end
	bar.AnchorPoint = Vector2.new(1, 1)
	bar.Position = UDim2.fromOffset(math.floor(right + 0.5), math.floor(bottom + 0.5))
	local height = gui.AbsoluteSize.Y
	if height > 0 then
		scale.Scale = math.clamp(height / BOOST_DESIGN_HEIGHT, BOOST_MIN_SCALE, 1)
	end
end

-- Each chip shows what pressing it would spend: the inventory, Shells, Robux, or greyed when none applies.
local function refreshBoosts()
	local bar = boostBar
	if bar == nil then
		return
	end
	local shown = boostsShown()
	bar.Visible = shown
	if not shown then
		return
	end
	fitBoostBar()
	for kind, chip in boostChips do
		local usedUp = usesOf(kind) >= GameConfig.Boosts.PerRound
		local cost = costOf(kind)
		local product = productOf(kind)
		-- The price pill says what pressing spends: Shells (with the shell icon), Robux, or one you own.
		local shellPrice = Theme.Icon.Shell .. " " .. cost
		local payable = true
		local priceColor = PRICE_SHELLS
		if inventoryOf(kind) > 0 then
			chip.price.Text = "OWNED x" .. inventoryOf(kind)
			priceColor = PRICE_OWNED
		elseif cash >= cost then
			chip.price.Text = shellPrice
		elseif product.productId ~= 0 then
			chip.price.Text = "R$ " .. product.robux
			priceColor = PRICE_ROBUX
		else
			chip.price.Text = shellPrice
			priceColor = PRICE_SHORT
			payable = false
		end
		chip.price.TextColor3 = priceColor
		local usable = payable and not usedUp
		chip.button.BackgroundColor3 = if usable then chip.face else chip.face:Lerp(DISABLED_FACE, 0.75)
		chip.uses.Text = if usedUp then Theme.Icon.Check else tostring(GameConfig.Boosts.PerRound - usesOf(kind))
	end
end

local function limitMessage(kind: string): string
	if usesOf(kind) >= GameConfig.Boosts.PerRound then
		return "ONE OF EACH PER ROUND"
	end
	return GameConfig.Boosts.PerMatch .. " OF EACH PER MATCH"
end

local function deny(text: string)
	showFeedback(text)
	Sfx.play("Deny", 0.5)
end

local function useBoost(kind: string)
	if not boostsShown() then
		return
	end
	local now = os.clock()
	if now - lastBoostAt < GameConfig.Boosts.Cooldown then
		return
	end
	lastBoostAt = now
	keepFocus()
	if usesOf(kind) >= GameConfig.Boosts.PerRound then
		deny(limitMessage(kind))
		return
	end
	local chip = boostChips[kind]
	if chip ~= nil then
		Ui.bump(chip.button, 1.06)
	end
	if inventoryOf(kind) > 0 or cash >= costOf(kind) then
		Net.event("UseBoost"):FireServer(kind)
		return
	end
	local product = productOf(kind)
	if product.productId ~= 0 then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.productId)
		return
	end
	deny(BOOST_MESSAGES.no_shells)
end

-- The +10s pops under the Status timer, where the player is already looking.
local function showExtraTime()
	local from: GuiObject? = nil
	local status = Ui.findScreen(playerGui, "Status")
	local secondary = if status ~= nil then status:FindFirstChild("SecondaryStatus") else nil
	local timer = if secondary ~= nil then secondary:FindFirstChild("Secondary") else nil
	if timer ~= nil and timer:IsA("GuiObject") then
		from = timer
		Ui.bump(timer, 1.12)
	else
		local chip = boostChips.ExtraTime
		from = if chip ~= nil then chip.button else nil
	end
	if from ~= nil then
		-- Fx.coinPop takes an optional colour; cast so this still works against the two-argument version.
		(Fx :: any).coinPop("+" .. GameConfig.Boosts.ExtraTimeSeconds .. "s", from, Theme.Header.Good)
	end
	Sfx.play("Coin", 0.6)
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
	Net.event("CheckAnswer"):FireServer(text)
end

-- Enter (or GO): the first press checks the answer; a second press with the same text locks it in.
local function onEnter()
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
		Net.event("SubmitAnswer"):FireServer(text)
		return
	end
	sendCheck(text)
	keepFocus()
end

local function wrongAnswer()
	lastWrongAt = os.clock()
	answerBox.Text = ""
	showFeedback(INVALID_TEXT)
	Sfx.play("Wrong", 0.5)
	keepFocus()
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
					Net.event("CheckAnswer"):FireServer(text)
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
		deny("THAT'S A LOT OF CHECKS  |  LOCK ONE IN")
	elseif status == "closed" then
		deny("TIME'S UP")
	end
end

local function onSubmitResult(payload)
	submitting = false
	if payload.accepted then
		locked = true
		hideConfirm()
		-- Autocorrect: show the answer in the bank's spelling, whatever was typed.
		local corrected = payload.corrected or answerBox.Text
		answerBox.Text = string.upper(corrected)
		lockedText.Text = "LOCKED IN  |  " .. string.upper(corrected)
		showLocked()
		refreshBoosts()
		Sfx.play("LockIn", 0.7)
		Fx.flash(Theme.Color.Green)
		return
	end
	local status = payload.status
	if status == "cooldown" and not retried and confirmed ~= nil then
		retried = true
		submitting = true
		local text = confirmed
		task.delay(RETRY_SECONDS, function()
			if not locked then
				Net.event("SubmitAnswer"):FireServer(text)
			end
		end)
		return
	end
	retried = false
	hideConfirm()
	if status == "closed" then
		deny("TIME'S UP")
	elseif status == "limit" then
		deny("THAT'S A LOT OF CHECKS  |  LOCK ONE IN")
	elseif status == "cooldown" then
		keepFocus()
	else
		wrongAnswer()
	end
end

function Hud.onAnswerResult(payload)
	if payload.stage == "check" then
		onCheckResult(payload)
	else
		onSubmitResult(payload)
	end
end

-- Meter ---------------------------------------------------------------------------------------------------

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

-- Setup ---------------------------------------------------------------------------------------------------

-- An element authored under AnswerBar wins; otherwise the ReplicatedStorage.Templates one is cloned in.
-- Waits for the template, so call it off the init thread.
local function adopt(name: string): Frame?
	local existing = answerBar:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Frame") then
		return existing
	end
	local templates = ReplicatedStorage:WaitForChild("Templates", TEMPLATE_WAIT)
	local template = if templates ~= nil then templates:WaitForChild(name, TEMPLATE_WAIT) else nil
	if template == nil or not template:IsA("Frame") then
		warn("Hud: no " .. name .. " template; that part of the answer bar is off")
		return nil
	end
	local clone = template:Clone()
	clone.Visible = false
	clone.Parent = answerBar
	return clone
end

local function bindChip(bar: Frame, kind: string, name: string)
	local button = bar:FindFirstChild(name)
	if button == nil or not button:IsA("TextButton") then
		return
	end
	local price = button:FindFirstChild("Price")
	local usesLabel = button:FindFirstChild("Uses")
	if price == nil or not price:IsA("TextLabel") or usesLabel == nil or not usesLabel:IsA("TextLabel") then
		return
	end
	-- The name under the icon says what the boost does; the +time one follows the configured seconds.
	local nameLabel = button:FindFirstChild("Label")
	if kind == "ExtraTime" and nameLabel ~= nil and nameLabel:IsA("TextLabel") then
		nameLabel.Text = "+" .. GameConfig.Boosts.ExtraTimeSeconds .. " SEC"
	end
	boostChips[kind] = { button = button, price = price, uses = usesLabel, face = button.BackgroundColor3 }
	Ui.pressable(button)
	button.Activated:Connect(function()
		useBoost(kind)
	end)
end

local function bindExtras()
	-- The boost chips sit outside the bar's left edge.
	answerBar.ClipsDescendants = false
	local chip = adopt("ConfirmChip")
	if chip ~= nil then
		confirmChip = chip
		local label = chip:FindFirstChild("Text")
		if label ~= nil and label:IsA("TextLabel") then
			confirmText = label
		end
	end
	local row = adopt("HintRow")
	if row ~= nil then
		hintRow = row
		local label = row:FindFirstChild("Text")
		if label ~= nil and label:IsA("TextLabel") then
			hintText = label
		end
	end
	local bar = adopt("BoostBar")
	if bar ~= nil then
		-- Out of the answer bar and into the bottom-right column above the Standings tab.
		bar.Parent = gui
		boostBar = bar
		bindChip(bar, "Hint", "HintButton")
		bindChip(bar, "ExtraTime", "TimeButton")
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoostBar)
		local standings = Ui.screen(playerGui, "Standings", TEMPLATE_WAIT)
		local root = if standings ~= nil then standings:WaitForChild("Root", TEMPLATE_WAIT) else nil
		if root ~= nil and root:IsA("GuiObject") then
			root:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitBoostBar)
			root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoostBar)
		end
		refreshBoosts()
	end
end

function Hud.init(newPlayerGui: PlayerGui)
	playerGui = newPlayerGui
	gui = Ui.screen(playerGui, "Hud") :: Frame
	meter = gui:WaitForChild("WaterMeter") :: Frame
	marker = meter:WaitForChild("Marker") :: Frame
	target = meter:WaitForChild("Target") :: Frame
	answerBar = gui:WaitForChild("AnswerBar") :: Frame
	answerBox = answerBar:WaitForChild("AnswerBox") :: TextBox
	submitButton = answerBar:WaitForChild("SubmitButton") :: TextButton
	lockedCard = answerBar:WaitForChild("LockedText") :: Frame
	lockedText = lockedCard:WaitForChild("Text") :: TextLabel
	feedback = answerBar:WaitForChild("Feedback") :: Frame
	local label = feedback:FindFirstChild("Text")
	if label ~= nil and label:IsA("TextLabel") then
		feedbackText = label
	end
	banner = gui:WaitForChild("Banner") :: Frame
	buttonText = submitButton.Text

	Ui.pressable(submitButton)
	submitButton.Activated:Connect(onEnter)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			onEnter()
		end
	end)
	-- Any edit cancels a pending lock-in, so only the answer that was checked can be locked.
	answerBox:GetPropertyChangedSignal("Text"):Connect(function()
		if confirmed ~= nil and trim(answerBox.Text) ~= confirmed then
			hideConfirm()
		end
	end)
	-- A Robux boost is used as soon as it is bought; the server waits for the receipt if it is slow.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if userId ~= Players.LocalPlayer.UserId or not purchased or productId == 0 then
			return
		end
		for _, kind in { "Hint", "ExtraTime" } do
			if productOf(kind).productId == productId then
				Net.event("UseBoost"):FireServer(kind, "inventory")
			end
		end
	end)
	task.spawn(bindExtras)
end

-- Keeps the boost inventory and Shells, so each chip shows what pressing it would spend.
function Hud.onProfile(profile)
	if typeof(profile.hints) == "number" then
		inventory.Hint = profile.hints
	end
	if typeof(profile.extraTimes) == "number" then
		inventory.ExtraTime = profile.extraTimes
	end
	if typeof(profile.cash) == "number" then
		cash = profile.cash
	end
	refreshBoosts()
end

-- Shows the result of a Hint or +10s request: the hint text, the extra time, or why it was refused.
function Hud.onBoostResult(payload)
	local kind = payload.kind
	if typeof(payload.uses) == "table" then
		uses = { Hint = payload.uses.Hint or 0, ExtraTime = payload.uses.ExtraTime or 0 }
	end
	local status = payload.status
	if status == "ok" then
		if kind == "Hint" and typeof(payload.hint) == "string" then
			if hintText ~= nil then
				hintText.Text = payload.hint
			end
			if hintRow ~= nil then
				Ui.pop(hintRow)
			end
			Toasts.show(payload.hint, "hint")
			Sfx.play("Ping", 0.5)
		elseif kind == "ExtraTime" then
			showExtraTime()
		end
	elseif status == "limit" then
		deny(limitMessage(kind))
	elseif status == "pending" then
		showFeedback(BOOST_MESSAGES.pending)
	elseif BOOST_MESSAGES[status] ~= nil then
		deny(BOOST_MESSAGES[status])
	end
	refreshBoosts()
end

function Hud.onState(payload)
	phase = payload.phase
	playing = payload.playing == true
	local mine = payload.yourSecondsLeft
	outOfTime = phase == "Prompt" and mine ~= nil and mine <= 0
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	gui.Visible = inMatch
	if not inMatch then
		lastPhase = phase
		refreshBoosts()
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
		submitting = false
		retried = false
		checking = nil
		lastWrongAt = -math.huge
		uses = { Hint = 0, ExtraTime = 0 }
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
	refreshBoosts()

	lastPhase = phase
	lastRound = payload.round
end

return Hud
