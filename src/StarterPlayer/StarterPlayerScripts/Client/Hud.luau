--!strict
-- Drives GameUi.Hud during a match: your hearts and the meter towards the next one (Hud.Vitals), and, while
-- you hold the crab, the answer box (one Enter sends the answer) with the Hint and +10s boost chips.
-- The question, whose turn it is and the used answers live in SharedUi.Status (see Status.luau).
-- HintRow and BoostBar are Studio templates (ReplicatedStorage.Templates) cloned into Hud.AnswerBar, unless
-- the place already has them authored there.

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
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local FEEDBACK_SECONDS = 1.5
local RETRY_SECONDS = 0.08 -- an answer that raced the server's cooldown is sent once more, this much later
local TYPING_SECONDS = 0.15 -- what you type is sent on at most this often
local WAIT_SECONDS = 10
local DISABLED_FACE = Color3.fromRGB(88, 100, 124)
local BOOST_GAP = 8 -- pixels between the Shells chip and the boost buttons above it
local BOOST_EDGE = 16 -- pixels from the screen edges when there is no Shells chip to stand on
local BOOST_MIN_SCALE = 0.6 -- the smallest the boost buttons shrink to on a short screen
local BOOST_DESIGN_HEIGHT = 820 -- screen height the boost buttons are drawn for
local PRICE_SHELLS = Color3.fromRGB(255, 217, 94) -- shell gold
local PRICE_SHORT = Color3.fromRGB(255, 130, 112) -- not enough Shells
local PRICE_ROBUX = Color3.fromRGB(120, 235, 140)
local PRICE_OWNED = Color3.fromRGB(255, 255, 255)

local INVALID_TEXT = "NOT IN THE BANK  |  TRY AGAIN"
local USED_TEXT = "ALREADY USED  |  TRY ANOTHER"
local BOOST_MESSAGES: { [string]: string } = {
	no_shells = "NOT ENOUGH " .. Currency.Upper,
	none = "NO HINT FOR THIS ONE",
	closed = "NOT YOUR TURN",
	not_playing = "NOT YOUR TURN",
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
local vitals: Frame
local hearts: Frame
local meterFill: Frame
local meterText: TextLabel
local answerBar: Frame
local answerBox: TextBox
local submitButton: TextButton
local feedback: Frame
local feedbackText: TextLabel?
local hintRow: Frame? = nil
local hintText: TextLabel? = nil
local boostBar: Frame? = nil
local boostChips: { [string]: BoostChip } = {}

local playing = false
local phase = ""
local myTurn = false -- you hold the crab: the answer box is yours
local lastWrongAt = -math.huge
local lastBoostAt = -math.huge
local sent: string? = nil -- the trimmed text of the answer in flight
local retried = false
local feedbackToken = 0
local lastRound = 0
local inventory = { Hint = 0, ExtraTime = 0 }
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

local function costOf(kind: string): number
	return if kind == "Hint" then GameConfig.Boosts.HintShells else GameConfig.Boosts.ExtraTimeShells
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
	Ui.appear(feedback)
	Ui.nudge(answerBar)
	task.delay(FEEDBACK_SECONDS, function()
		if token == feedbackToken then
			feedback.Visible = false
		end
	end)
end

local function showEntry()
	answerBox.Text = ""
	answerBox.Visible = true
	submitButton.Visible = true
	feedback.Visible = false
	if hintRow ~= nil then
		hintRow.Visible = false
	end
end

-- Boosts --------------------------------------------------------------------------------------------------

local function boostsShown(): boolean
	return GameConfig.Boosts.Enabled == 1 and phase == "Prompt" and playing and myTurn
end

-- The Shells chip in the bottom-right corner (SharedUi.Wallet.Chip), while it shows.
local function shellsChip(): GuiObject?
	local screen = Ui.findScreen(playerGui, "Wallet")
	local chip = if screen ~= nil then screen:FindFirstChild("Chip") else nil
	if screen ~= nil and screen.Visible and chip ~= nil and chip:IsA("GuiObject") and chip.Visible and chip.AbsoluteSize.X > 0 then
		return chip
	end
	return nil
end

-- The chip's top edge without the bump its UIScale may be playing, so the boosts never jiggle with it.
-- The chip is anchored at its bottom, so a bump only moves its top.
local function restingTop(object: GuiObject): number
	local scale = object:FindFirstChildOfClass("UIScale")
	local factor = if scale ~= nil and scale.Scale > 0 then scale.Scale / Ui.rest(object) else 1
	local bottom = object.AbsolutePosition.Y + object.AbsoluteSize.Y
	return bottom - object.AbsoluteSize.Y / factor
end

-- The boost buttons stand in the bottom-right column, right above the Shells chip, right edges lined up,
-- and shrink with the screen height like the rest of the column.
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
	local right = gui.AbsoluteSize.X - BOOST_EDGE
	local bottom = gui.AbsoluteSize.Y - BOOST_EDGE
	local chip = shellsChip()
	if chip ~= nil then
		right = chip.AbsolutePosition.X + chip.AbsoluteSize.X - origin.X
		bottom = restingTop(chip) - origin.Y - BOOST_GAP
	end
	bar.AnchorPoint = Vector2.new(1, 1)
	bar.Position = UDim2.fromOffset(math.floor(right + 0.5), math.floor(bottom + 0.5))
	if height > 0 then
		scale.Scale = math.clamp(height / BOOST_DESIGN_HEIGHT, BOOST_MIN_SCALE, 1)
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
		local usedUp = usesOf(kind) >= GameConfig.Boosts.PerRound
		local cost = costOf(kind)
		local product = productOf(kind)
		-- The price pill says what pressing spends: Shells (with the authored shell icon), Robux, or one you own.
		local shellPrice = tostring(cost)
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
		Icons.show(chip.price, chip.price.Text == shellPrice)
		local usable = payable and not usedUp
		chip.button.BackgroundColor3 = if usable then chip.face else chip.face:Lerp(DISABLED_FACE, 0.75)
		chip.uses.Text = if usedUp then "" else tostring(GameConfig.Boosts.PerRound - usesOf(kind))
		local check = chip.uses:FindFirstChild("Check")
		if check ~= nil and check:IsA("GuiObject") then
			check.Visible = usedUp
		end
	end
end

local function limitMessage(kind: string): string
	if usesOf(kind) >= GameConfig.Boosts.PerRound then
		return "ONE OF EACH PER QUESTION"
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

-- The +10s pops under the Status turn label, where the player is already looking.
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

-- Enter (or GO) sends the answer. A wrong or used one is refused and the box is yours again.
local function onEnter()
	if not myTurn or sent ~= nil then
		return
	end
	local text = trim(answerBox.Text)
	if #text == 0 then
		return
	end
	if os.clock() - lastWrongAt < GameConfig.Answer.RetryCooldown then
		Ui.nudge(answerBox)
		keepFocus()
		return
	end
	sent = text
	retried = false
	Net.event("SubmitAnswer"):FireServer(text)
	keepFocus()
end

local function refused(text: string)
	lastWrongAt = os.clock()
	answerBox.Text = ""
	showFeedback(text)
	Sfx.play("Wrong", 0.5)
	keepFocus()
end

function Hud.onAnswerResult(payload)
	if not ready then
		return
	end
	local text = sent
	sent = nil
	if payload.accepted then
		-- The crab is on its way: the box goes until it comes back round.
		myTurn = false
		answerBox.Text = ""
		answerBox:ReleaseFocus()
		answerBar.Visible = false
		refreshBoosts()
		Sfx.play("LockIn", 0.7)
		Fx.flash(Theme.Color.Green)
		return
	end
	local status = payload.status
	if status == "cooldown" then
		if not retried and text ~= nil and myTurn then
			retried = true
			sent = text
			task.delay(RETRY_SECONDS, function()
				if sent == text then
					Net.event("SubmitAnswer"):FireServer(text)
				end
			end)
		end
		return
	end
	retried = false
	if status == "invalid" then
		refused(INVALID_TEXT)
	elseif status == "used" then
		refused(USED_TEXT)
	elseif status == "limit" then
		deny("THAT'S A LOT OF GUESSES  |  SLOW DOWN")
	end
end

-- Vitals --------------------------------------------------------------------------------------------------

-- Your hearts, one icon each, and the meter towards the next one.
local function updateVitals(payload)
	local mine = 0
	for _, row in payload.ring or {} do
		if row.userId == Players.LocalPlayer.UserId then
			mine = row.hearts
		end
	end
	for _, slot in hearts:GetChildren() do
		if slot:IsA("ImageLabel") then
			local index = tonumber(string.match(slot.Name, "%d+")) or 0
			slot.Visible = index <= mine
		end
	end
	local goal = payload.meterTarget or 1
	local have = payload.meter or 0
	Tween.play(meterFill, Theme.Tween.Enter, { Size = UDim2.fromScale(math.clamp(have / goal, 0, 1), 1) })
	meterText.Text = "NEXT HEART " .. have .. "/" .. goal
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
		-- Out of the answer bar and into the bottom-right column above the Shells chip.
		bar.Parent = gui
		boostBar = bar
		bindChip(bar, "Hint", "HintButton")
		bindChip(bar, "ExtraTime", "TimeButton")
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoostBar)
		local wallet = Ui.screen(playerGui, "Wallet", WAIT_SECONDS)
		local chip = if wallet ~= nil then wallet:WaitForChild("Chip", WAIT_SECONDS) else nil
		if chip ~= nil and chip:IsA("GuiObject") then
			chip:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitBoostBar)
			chip:GetPropertyChangedSignal("Visible"):Connect(fitBoostBar)
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
		warn("Hud: GameUi.Hud is missing; no answer bar or hearts")
		return
	end
	local vitalsFound = waitChild(screen, "Vitals")
	local heartsFound = waitChild(vitalsFound, "Hearts")
	local meterFound = waitChild(vitalsFound, "Meter")
	local fillFound = waitChild(meterFound, "Fill")
	local meterTextFound = waitChild(meterFound, "Text")
	local barFound = waitChild(screen, "AnswerBar")
	local boxFound = waitChild(barFound, "AnswerBox")
	local submitFound = waitChild(barFound, "SubmitButton")
	local feedbackFound = waitChild(barFound, "Feedback")
	if missing ~= nil then
		warn("Hud: GameUi.Hud has no " .. missing .. "; no answer bar or hearts")
		return
	end
	gui = screen
	vitals = vitalsFound :: Frame
	hearts = heartsFound :: Frame
	meterFill = fillFound :: Frame
	meterText = meterTextFound :: TextLabel
	answerBar = barFound :: Frame
	answerBox = boxFound :: TextBox
	submitButton = submitFound :: TextButton
	feedback = feedbackFound :: Frame
	local label = feedback:FindFirstChild("Text")
	if label ~= nil and label:IsA("TextLabel") then
		feedbackText = label
	end
	-- The old lock-in card under the bar has no use in a turn: one Enter passes the crab.
	local lockedCard = answerBar:FindFirstChild("LockedText")
	if lockedCard ~= nil and lockedCard:IsA("GuiObject") then
		lockedCard.Visible = false
	end
	ready = true

	UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(placeForKeyboard)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAnswerBar)
	placeAnswerBar()
	Ui.pressable(submitButton)
	submitButton.Activated:Connect(onEnter)
	-- Everyone else watches the holder type: the box's text goes up a few times a second.
	local typingQueued = false
	answerBox:GetPropertyChangedSignal("Text"):Connect(function()
		if not myTurn or typingQueued then
			return
		end
		typingQueued = true
		task.delay(TYPING_SECONDS, function()
			typingQueued = false
			if myTurn then
				Net.event("Typing"):FireServer(answerBox.Text)
			end
		end)
	end)
	answerBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			onEnter()
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

-- You are out: your hearts and answer bar go now, not on the next state tick.
function Hud.onEliminated()
	if not ready then
		return
	end
	playing = false
	myTurn = false
	sent = nil
	applyTouchControls(true)
	vitals.Visible = false
	answerBar.Visible = false
	answerBox:ReleaseFocus()
end

function Hud.onState(payload)
	if not ready then
		return
	end
	phase = payload.phase
	playing = payload.playing == true
	applyTouchControls(not playing)
	local inMatch = phase == "Prompt" or phase == "Reveal"
	gui.Visible = inMatch
	local holding = phase == "Prompt" and playing and payload.holderUserId == Players.LocalPlayer.UserId
	if not inMatch then
		myTurn = false
		sent = nil
		answerBox:ReleaseFocus()
		refreshBoosts()
		return
	end

	vitals.Visible = playing
	if playing then
		updateVitals(payload)
	end
	-- One of each boost per question.
	if payload.round ~= lastRound then
		lastRound = payload.round
		uses = { Hint = 0, ExtraTime = 0 }
	end
	if holding and not myTurn then
		-- The crab just reached you.
		myTurn = true
		sent = nil
		retried = false
		lastWrongAt = -math.huge
		showEntry()
		answerBar.Visible = true
		keepFocus()
		Sfx.play("Ping", 0.6)
	elseif not holding and myTurn then
		myTurn = false
		sent = nil
		answerBox:ReleaseFocus()
	end
	answerBar.Visible = myTurn
	refreshBoosts()
end

return Hud
