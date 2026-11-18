--!strict
-- Drives StarterGui.Hud during a match: the answer box (Enter locks the answer in; a fixed typo asks first),
-- the Hint (locks the best unused answer in for you) and +10s boost chips, Shells, water meter,
-- sudden-death card.
-- The prompt, timer and alive count live in StarterGui.Status (see Status.luau); surge feedback in Tide.luau.
-- ConfirmChip and BoostBar are Studio templates (ReplicatedStorage.Templates) cloned into
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
local Icons = require(script.Parent.Icons)
local Sfx = require(script.Parent.Sfx)
local Status = require(script.Parent.Status)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local METER_RANGE = 30 -- studs of margin that fills the whole meter
local METER_WATER = 0.2 -- fraction of the meter the water fill occupies
local LABEL_ROOM = 0.1 -- fraction of the meter, from its top, that a label above a line needs
local FEEDBACK_SECONDS = 1.5
local RETRY_SECONDS = 0.08 -- a check that raced the server's cooldown is retried once, this much later
local WAIT_SECONDS = 10
local DISABLED_FACE = Color3.fromRGB(88, 100, 124)
local BOOST_GAP = 8 -- pixels between the boost buttons and what they stand on
local BOOST_MIN_SCALE = 0.6 -- the smallest the boost buttons shrink to on a short screen
local BOOST_DESIGN_HEIGHT = 820 -- screen height the boost buttons are drawn for
local BOOST_DESKTOP_SCALE = 1.4 -- desktop shows the boost buttons this much larger than authored
local PRICE_SHELLS = Color3.fromRGB(255, 217, 94) -- shell gold
local PRICE_SHORT = Color3.fromRGB(255, 130, 112) -- not enough Shells
local PRICE_ROBUX = Color3.fromRGB(120, 235, 140)
local PRICE_OWNED = Color3.fromRGB(255, 255, 255)

local INVALID_TEXT = "WE DON'T KNOW THAT ONE  |  TRY ANOTHER"
local SAVE_TEXT = "YOUR SAVE IS STILL LOADING  |  TRY AGAIN SOON"
local MIN_BUY_SECONDS = 6 -- with less time than this left, a purchase could not finish in time to be used
local AUTO_LOCK_SECONDS = 1 -- a checked answer still in the box this close to the end is locked in for you
local BOOST_MESSAGES: { [string]: string } = {
	no_shells = "NOT ENOUGH " .. Currency.Upper,
	no_hints = "HINTS COST ROBUX",
	none = "NO HINT LEFT  |  EVERY ANSWER IS TAKEN",
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
-- Optional labels on the meter (authored): YOU beside your line, what the yellow line is beside it, and how
-- far you still have to rise above the meter.
local markerLabel: TextLabel? = nil
local targetLabel: TextLabel? = nil
local needLabel: TextLabel? = nil
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
local confirmed: string? = nil -- the trimmed text the server matched after a typo fix; Enter again locks it in
local submitting = false
local retried = false
local feedbackToken = 0
local lastRound = 0
local lastPhase = ""
local heldHeight: number? = nil -- your height before this round's answer, kept on the meter through the reveal
local holdMeter = false -- true from the reveal until your pillar rises
local meterPayload: Net.RoundStatePayload? = nil -- the latest state, for releasing the meter
local inventory = { Hint = 0, ExtraTime = 0 }
local timeLeftThisMatch: number? = nil -- +time uses left this match, once the server has said; nil is unknown
local secondsLeft = 0 -- your own time left on the open prompt
local saveFailed = false -- the profile did not load: nothing can be bought until it does
local cash = 0
local uses: Net.BoostUses = { Hint = 0, ExtraTime = 0 }
local ready = false -- GameUi.Hud and its children were found; every handler is a no-op until then
local missing: string? = nil

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

-- Only +time has a per-round limit: a hint is bought each time and can be used every round.
local function roundLimitHit(kind: string): boolean
	return kind ~= "Hint" and usesOf(kind) >= GameConfig.Boosts.PerRound
end

-- The boost's price in Shells, or nil for a hint: hints are only bought with Robux.
local function shellCostOf(kind: string): number?
	if kind == "Hint" then
		return nil
	end
	return GameConfig.Boosts.ExtraTimeShells
end

local function productOf(kind: string): { productId: number, robux: number }
	return if kind == "Hint" then Products.Boosts.Hint else Products.Boosts.ExtraTime
end

-- Phones and tablets have no Enter key to press twice.
local function isTouch(): boolean
	return Ui.isPhone()
end

-- Phones: the answer bar sits in the strip at the top, under the prompt and timer, where the keyboard never
-- reaches; the authored PromptEcho stays hidden. Desktop keeps the authored bottom position.
local barRest: UDim2? = nil
local promptText = ""

local refreshBoosts: () -> ()
local TOUCH_BAR_TOP = 0.17 -- phones: the answer bar's top, as a fraction of the screen height (under the chips)
local TOUCH_BAR_WIDTH = 0.6

-- Phones: the answer bar sits high on the screen, under the prompt and timer, where the keyboard (which
-- covers the bottom half) never reaches it. Desktop keeps the authored bottom position.
local function placeAnswerBar()
	if barRest == nil then
		barRest = answerBar.Position
	end
	local echo = answerBar:FindFirstChild("PromptEcho")
	if echo ~= nil and echo:IsA("GuiObject") then
		echo.Visible = false
	end
	if isTouch() then
		answerBar.AnchorPoint = Vector2.new(0.5, 0)
		answerBar.Position = UDim2.new(0.5, 0, TOUCH_BAR_TOP, 0)
		answerBar.Size = UDim2.new(TOUCH_BAR_WIDTH, 0, answerBar.Size.Y.Scale, answerBar.Size.Y.Offset)
	else
		answerBar.Position = barRest
	end
	refreshBoosts()
end

local function placeForKeyboard()
	placeAnswerBar()
end

-- Phones: no walking in a match. The pillar top is small, the thumbstick would sit under the keyboard, and
-- a stray drag must never walk a player off the edge.
local function setTouchControls(enabled: boolean)
	if not isTouch() then
		return
	end
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	local ok, controls = pcall(function()
		return (require(module) :: any):GetControls()
	end)
	if not ok or controls == nil then
		return
	end
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end
end

local touchControlsOn = true

local function applyTouchControls(enabled: boolean)
	if enabled == touchControlsOn then
		return
	end
	touchControlsOn = enabled
	setTouchControls(enabled)
end

-- One frame later: a focus grab in the same frame as the Enter press that released the box is dropped.
local function keepFocus()
	task.delay(0, function()
		if gui.Visible and answerBox.Visible and answerBar.Visible then
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
		confirmText.Text = "DID YOU MEAN  " .. string.upper(corrected) .. "?  " .. action
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
end

-- Boosts --------------------------------------------------------------------------------------------------

local function boostsShown(): boolean
	return GameConfig.Boosts.Enabled == 1 and phase == "Prompt" and playing and not locked and not outOfTime
end

-- Top edge (screen pixels) of what the desktop boost buttons stand on: the answer bar, or the confirm chip
-- or feedback line over it while one shows, so the buttons never cover them.
local function boostFloor(): number
	local top = answerBar.AbsolutePosition.Y
	for _, line in { confirmChip, feedback } do
		if line ~= nil and line.Visible and line.AbsoluteSize.Y > 0 then
			top = math.min(top, line.AbsolutePosition.Y)
		end
	end
	return top
end

-- The boost buttons stand just above the answer box (not the GO button), centred on it, where the player is
-- already looking, and shrink with the screen height.
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
	local height = gui.AbsoluteSize.Y
	if isTouch() then
		-- Phones: beside the answer bar at the top, clear of the keyboard.
		bar.AnchorPoint = Vector2.new(0, 0)
		local barRight = answerBar.AbsolutePosition.X + answerBar.AbsoluteSize.X - origin.X
		bar.Position = UDim2.fromOffset(math.floor(barRight + BOOST_GAP + 0.5), math.floor(answerBar.AbsolutePosition.Y - origin.Y + 0.5))
		scale.Scale = BOOST_MIN_SCALE
		return
	end
	local centre = answerBox.AbsolutePosition.X + answerBox.AbsoluteSize.X / 2 - origin.X
	local bottom = boostFloor() - origin.Y - BOOST_GAP
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromOffset(math.floor(centre + 0.5), math.floor(bottom + 0.5))
	if height > 0 then
		local fit = math.clamp(height / BOOST_DESIGN_HEIGHT, BOOST_MIN_SCALE, 1)
		scale.Scale = fit * BOOST_DESKTOP_SCALE
	end
end

-- Each chip shows what pressing it would spend: the inventory, Shells, Robux, or greyed when none applies.
function refreshBoosts()
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
		local usedUp = roundLimitHit(kind)
		local cost = shellCostOf(kind)
		local product = productOf(kind)
		-- The price pill says what pressing spends: one you own, Shells (with the authored shell icon; never
		-- for a hint) or Robux.
		local shellPrice = if cost ~= nil then tostring(cost) else ""
		local payable = true
		local priceColor = PRICE_SHELLS
		if inventoryOf(kind) > 0 then
			chip.price.Text = "OWNED x" .. inventoryOf(kind)
			priceColor = PRICE_OWNED
		elseif cost ~= nil and cash >= cost then
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
		Icons.show(chip.price, cost ~= nil and chip.price.Text == shellPrice)
		local usable = payable and not usedUp
		chip.button.BackgroundColor3 = if usable then chip.face else chip.face:Lerp(DISABLED_FACE, 0.75)
		-- The count is the +time uses left this round; a hint has no limit, so it shows none.
		local counted = kind ~= "Hint" and not usedUp
		chip.uses.Text = if counted then tostring(GameConfig.Boosts.PerRound - usesOf(kind)) else ""
		local check = chip.uses:FindFirstChild("Check")
		if check ~= nil and check:IsA("GuiObject") then
			check.Visible = usedUp
		end
	end
end

local function limitMessage(kind: string): string
	if roundLimitHit(kind) then
		return "ONLY ONE +10 SEC PER ROUND"
	end
	return "NO +10 SEC LEFT THIS MATCH"
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
	-- Refused before anything is paid for: the round limit, and the match limit once the server has said.
	if roundLimitHit(kind) or (kind == "ExtraTime" and timeLeftThisMatch == 0) then
		deny(limitMessage(kind))
		return
	end
	local chip = boostChips[kind]
	if chip ~= nil then
		Ui.bump(chip.button, 1.06)
	end
	local cost = shellCostOf(kind)
	if inventoryOf(kind) > 0 or (cost ~= nil and cash >= cost) then
		Net.event("UseBoost"):FireServer(kind)
		return
	end
	local product = productOf(kind)
	if product.productId == 0 then
		deny(if cost ~= nil then BOOST_MESSAGES.no_shells else BOOST_MESSAGES.no_hints)
		return
	end
	-- From here pressing costs Robux, so nothing opens by accident or when it could not be used.
	if saveFailed then
		deny(SAVE_TEXT)
		return
	end
	if secondsLeft < MIN_BUY_SECONDS then
		deny("NOT ENOUGH TIME LEFT TO BUY ONE")
		return
	end
	-- One tap opens Roblox's purchase dialog, which asks the player to confirm.
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.productId)
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

-- False when the press came too soon after the last one and nothing was sent.
local function sendCheck(text: string): boolean
	local now = os.clock()
	if now - lastCheckAt < GameConfig.Answer.CheckMinInterval or now - lastWrongAt < GameConfig.Answer.RetryCooldown then
		Ui.nudge(answerBox)
		return false
	end
	lastCheckAt = now
	checking = text
	retried = false
	Net.event("CheckAnswer"):FireServer(text)
	return true
end

-- Enter (or GO) sends the answer: the server locks it in at once when the bank has it as typed. When it had
-- to fix a typo it asks first, and a second press with the same text locks that in.
local function onEnter()
	if locked or submitting or outOfTime then
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
	-- A phone leaves its keyboard down once the answer is on its way: most answers lock in on this press,
	-- and raising it only to drop it again makes it bounce. A wrong answer brings it back (wrongAnswer).
	local sent = sendCheck(text)
	if not (sent and isTouch()) then
		keepFocus()
	end
end

-- The text stays in the box, selected, so a typo is fixed and not retyped.
local function wrongAnswer()
	lastWrongAt = os.clock()
	showFeedback(INVALID_TEXT)
	Sfx.play("Wrong", 0.5)
	keepFocus()
	task.delay(0, function()
		if answerBox:IsFocused() then
			answerBox.SelectionStart = 1
			answerBox.CursorPosition = #answerBox.Text + 1
		end
	end)
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
		deny("OUT OF TRIES THIS ROUND")
	elseif status == "closed" then
		deny("TIME'S UP")
	end
end

local function onSubmitResult(payload)
	submitting = false
	if payload.accepted then
		locked = true
		checking = nil
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
		deny("OUT OF TRIES THIS ROUND")
	elseif status == "cooldown" then
		keepFocus()
	else
		wrongAnswer()
	end
end

function Hud.onAnswerResult(payload)
	if not ready then
		return
	end
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

-- A line's label sits beside it, above the line (`up`) or below it.
local function placeLabel(label: TextLabel?, up: boolean)
	if label ~= nil then
		label.AnchorPoint = Vector2.new(0, if up then 1 else 0)
		label.Position = UDim2.new(label.Position.X.Scale, label.Position.X.Offset, 0.5, if up then -1 else 1)
	end
end

-- The marker is you; the target line is where the water will reach this round.
-- The marker turns red while you are still below that line, and the label above the meter says how far
-- you have to rise to clear it, or by how much you are safe.
local function updateMeter(payload)
	-- The server sends your new height as the reveal starts; showing it then would spoil your tier, so the
	-- meter keeps the old one until your pillar rises.
	local height = payload.height
	if holdMeter and payload.phase == "Reveal" and heldHeight ~= nil then
		height = heldHeight
	else
		heldHeight = height
	end
	local markerY = meterY(height, payload.waterY)
	Tween.play(marker, Theme.Tween.Enter, { Position = UDim2.fromScale(0.5, markerY) })
	local showTarget = payload.phase == "Prompt" or payload.phase == "Reveal"
	target.Visible = showTarget
	if showTarget then
		local targetY = meterY(payload.waterY + payload.surge, payload.waterY)
		Tween.play(target, Theme.Tween.Enter, { Position = UDim2.fromScale(0.5, targetY) })
	end
	local gap = payload.waterY + payload.surge - height
	local willSink = gap > 0
	local danger = showTarget and willSink
	marker.BackgroundColor3 = if danger then Theme.Color.Red else Theme.Color.Cream
	-- Each label goes on the far side of its line from the other line, so the two never overlap.
	-- Near the top of the meter YOU drops below its line, clear of the label above the meter.
	placeLabel(markerLabel, not danger and markerY > LABEL_ROOM)
	placeLabel(targetLabel, danger)
	local you = markerLabel
	if you ~= nil then
		you.TextColor3 = if danger then Theme.Color.Red else Theme.Color.Cream
	end
	local need = needLabel
	if need ~= nil then
		need.Visible = showTarget
		if willSink then
			need.Text = string.format("RISE +%.1f", gap)
			need.TextColor3 = Theme.Color.Red
		else
			need.Text = string.format("SAFE +%.1f", -gap)
			need.TextColor3 = Theme.Color.Green
		end
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
	local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
	local template = if templates ~= nil then templates:WaitForChild(name, WAIT_SECONDS) else nil
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
	local bar = adopt("BoostBar")
	if bar ~= nil then
		-- Out of the answer bar (which clips) and onto the Hud, centred above the bar.
		bar.Parent = gui
		boostBar = bar
		bindChip(bar, "Hint", "HintButton")
		bindChip(bar, "ExtraTime", "TimeButton")
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoostBar)
		answerBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitBoostBar)
		answerBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoostBar)
		for _, line in { confirmChip, feedback } do
			if line ~= nil then
				line:GetPropertyChangedSignal("Visible"):Connect(fitBoostBar)
			end
		end
		refreshBoosts()
	end
end

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

function Hud.init(newPlayerGui: PlayerGui)
	playerGui = newPlayerGui
	local screen = Ui.screen(playerGui, "Hud", WAIT_SECONDS)
	if screen == nil then
		warn("Hud: GameUi.Hud is missing; no answer bar or water meter")
		return
	end
	local meterFound = waitChild(screen, "WaterMeter")
	local markerFound = waitChild(meterFound, "Marker")
	local targetFound = waitChild(meterFound, "Target")
	local barFound = waitChild(screen, "AnswerBar")
	local boxFound = waitChild(barFound, "AnswerBox")
	local submitFound = waitChild(barFound, "SubmitButton")
	local lockedFound = waitChild(barFound, "LockedText")
	local lockedTextFound = waitChild(lockedFound, "Text")
	local feedbackFound = waitChild(barFound, "Feedback")
	local bannerFound = waitChild(screen, "Banner")
	if missing ~= nil then
		warn("Hud: GameUi.Hud has no " .. missing .. "; no answer bar or water meter")
		return
	end
	gui = screen
	meter = meterFound :: Frame
	marker = markerFound :: Frame
	target = targetFound :: Frame
	local function optionalLabel(parent: Instance, name: string): TextLabel?
		local found = parent:FindFirstChild(name)
		return if found ~= nil and found:IsA("TextLabel") then found else nil
	end
	markerLabel = optionalLabel(marker, "Label")
	targetLabel = optionalLabel(target, "Label")
	needLabel = optionalLabel(meter, "Need")
	answerBar = barFound :: Frame
	answerBox = boxFound :: TextBox
	submitButton = submitFound :: TextButton
	lockedCard = lockedFound :: Frame
	lockedText = lockedTextFound :: TextLabel
	feedback = feedbackFound :: Frame
	local label = feedback:FindFirstChild("Text")
	if label ~= nil and label:IsA("TextLabel") then
		feedbackText = label
	end
	banner = bannerFound :: Frame
	buttonText = submitButton.Text
	ready = true

	UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(placeForKeyboard)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAnswerBar)
	placeAnswerBar()
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
	if not ready then
		return
	end
	if typeof(profile.hints) == "number" then
		inventory.Hint = profile.hints
	end
	if typeof(profile.extraTimes) == "number" then
		inventory.ExtraTime = profile.extraTimes
	end
	saveFailed = profile.loadFailed == true
	if typeof(profile.cash) == "number" then
		cash = profile.cash
	end
	refreshBoosts()
end

-- Shows the result of a Hint or +10s request: the hint text, the extra time, or why it was refused.
function Hud.onBoostResult(payload)
	if not ready then
		return
	end
	local kind = payload.kind
	if typeof(payload.uses) == "table" then
		uses = { Hint = payload.uses.Hint or 0, ExtraTime = payload.uses.ExtraTime or 0 }
	end
	if typeof(payload.timeLeftThisMatch) == "number" then
		timeLeftThisMatch = payload.timeLeftThisMatch
	end
	local status = payload.status
	if status == "ok" then
		if kind == "Hint" and typeof(payload.hint) == "string" then
			-- The server has locked the hinted answer in (an accepted AnswerResult fills the box with it).
			Toasts.show(payload.hint, "hint")
			Sfx.play("Ping", 0.5)
		elseif kind == "ExtraTime" then
			showExtraTime()
		end
	elseif status == "limit" then
		deny(limitMessage(kind))
	elseif status == "pending" then
		showFeedback(BOOST_MESSAGES.pending)
	elseif status == "stocked" then
		-- The purchase landed too late to use for you: it is yours, one tap away.
		local name = if kind == "Hint" then "HINT" else "+" .. GameConfig.Boosts.ExtraTimeSeconds .. " SEC"
		showFeedback(name .. " SAVED  |  TAP IT TO USE IT")
	elseif BOOST_MESSAGES[status] ~= nil then
		deny(BOOST_MESSAGES[status])
	end
	refreshBoosts()
end

-- You sank or reset: your meter and answer bar go now, not on the next state tick.
function Hud.onEliminated()
	if not ready then
		return
	end
	playing = false
	applyTouchControls(true)
	meter.Visible = false
	answerBar.Visible = false
	answerBox:ReleaseFocus()
	banner.Visible = false
	refreshBoosts()
end

function Hud.onState(payload)
	if not ready then
		return
	end
	phase = payload.phase
	if type(payload.prompt) == "string" then
		promptText = string.upper(payload.prompt)
	end
	playing = payload.playing == true
	applyTouchControls(not playing)
	local mine = payload.yourSecondsLeft
	local wasOutOfTime = outOfTime
	outOfTime = phase == "Prompt" and mine ~= nil and mine <= 0
	answerBox.TextEditable = not outOfTime
	secondsLeft = if typeof(mine) == "number" then mine else (payload.secondsLeft or 0)
	-- The box stopping is said out loud, once.
	if outOfTime and not wasOutOfTime and playing and not locked then
		deny("TIME'S UP")
	end
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	gui.Visible = inMatch
	if not inMatch then
		answerBox:ReleaseFocus()
		lastPhase = phase
		refreshBoosts()
		return
	end

	meter.Visible = payload.playing and not isTouch()
	meterPayload = payload
	if phase == "Reveal" and lastPhase ~= "Reveal" then
		holdMeter = true
		task.delay(GameConfig.Reveal.RaiseDelaySeconds, function()
			holdMeter = false
			local latest = meterPayload
			if latest ~= nil and latest.phase == "Reveal" and latest.playing then
				updateMeter(latest)
			end
		end)
	end
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
		-- A new match starts the +time count again.
		if payload.round < lastRound or payload.round <= 1 then
			timeLeftThisMatch = nil
		end
		showEntry()
		if payload.playing then
			answerBar.Visible = true
			keepFocus()
		end
	end

	-- An answer you checked but never locked in would count as no answer: with the time about gone it is
	-- locked in for you, as long as it is still what is in the box.
	if phase == "Prompt" and playing and secondsLeft <= AUTO_LOCK_SECONDS and not locked and not submitting then
		local text = trim(answerBox.Text)
		if confirmed ~= nil and text == confirmed then
			submitting = true
			retried = false
			Net.event("SubmitAnswer"):FireServer(text)
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
