--!strict
-- Drives SharedUi.Wallet: the chunky gold Shells chip in the bottom-right corner, always on screen (lobby and
-- match), that counts up, and the "+25 ANSWER" pills (the shell icon is authored on the pill) that bounce in above the corner column for every
-- payout or spend (ShellsEarned). On a phone the chip hangs in the top-right corner, right under the top bar
-- buttons, with the THROW key under it and the pills dropping in below both. The level bar (Chip.LevelBar)
-- hangs under the chip and shows the player's level and progress to the next one.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Fx = require(script.Parent.Fx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local MAX_POPS = 4
local POP_SLOT = 70 -- pixels between stacked pills; the newest sits closest to the chip
local POP_GAP = 24 -- pixels between the chip and the first pill
local POP_HOLD = 1.4
local POP_FADE = 0.3
local POP_DRIFT = 18 -- pixels a pill moves away from the chip while it fades
local POP_CLEAR = 10 -- pixels of a slot left clear between two pills
local PHONE_SIDE = 8 -- phones: pixels from the right end of the top bar to the chip, as the top bar buttons keep
local PHONE_TOP = 10 -- phones: pixels from the bottom of the top bar to the chip under its buttons
local PHONE_STACK_GAP = 16 -- phones: pixels between the chip and the THROW key under it
local PHONE_CHIP_SCALE = 0.8 -- phones: the chip's size, so its shell bubble stays clear of the THROW key
local DESIGN_HEIGHT = 820 -- screen height the pills are drawn for; shorter screens scale them down
local MIN_FIT = 0.65
local POP_IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FILL_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local GAIN_RISE = 34 -- pixels a "+15 XP" pop floats up beside the level bar while it fades
local GAIN_SECONDS = 1.1
local LEVEL_CONFETTI = 60
local SKY = Color3.fromHex("00FDFF")

type Swatch = { Top: Color3, Bottom: Color3, Lip: Color3 }

-- Repaints a chunky face (white, coloured by its gradient) with a Theme.Chunky swatch, keeping the height
-- of the lip band authored in Studio.
local function paint(gradient: UIGradient, swatch: Swatch)
	local points = gradient.Color.Keypoints
	local edge = if #points >= 4 then points[3].Time else 0.9
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, swatch.Top),
		ColorSequenceKeypoint.new(math.max(edge - 0.01, 0), swatch.Bottom),
		ColorSequenceKeypoint.new(edge, swatch.Lip),
		ColorSequenceKeypoint.new(1, swatch.Lip),
	})
end

local SWATCHES: { [string]: Swatch } = Theme.Chunky.Color :: any

-- ShellsEarned reasons, as the line under the amount.
local CAPTIONS: { [string]: string } = {
	answer = "ANSWER",
	survive = "SURVIVED",
	win = "WINNER!",
	warmup = "WARM-UP",
	quest = "QUEST",
	reward = "REWARD",
	purchase = "PURCHASE",
	pickup = "FOUND",
	spend = "SPENT",
	level = "LEVEL UP!",
}

local gui: Frame? = nil
local chip: Frame? = nil
local amountLabel: TextLabel? = nil
local pops: Frame? = nil
local popsFit: UIScale? = nil
local popTemplate: Frame? = nil
local playerGuiRef: PlayerGui? = nil
local levelBar: Frame? = nil
local levelFill: Frame? = nil
local levelLabel: TextLabel? = nil
local shownLevel: number? = nil -- nil until the first profile
local shownXp: number? = nil
local gainTemplate: TextLabel? = nil
local rimStroke: UIStroke? = nil
local rimColor: Color3? = nil
local phase = ""
local playing = false -- the local player is on a pillar in the running match

-- Tweened for the count-up; the label follows it.
local counter = Instance.new("NumberValue")
local shown: number? = nil -- the balance the chip is heading for; nil until the first profile
local live: { Frame } = {}
local fading: { [Frame]: boolean } = {} -- pills mid-fade; a re-slot must keep their fade going

local Wallet = {}

-- How far the level bar reaches below the chip's bottom edge (0 without one), so the column makes room.
local function barExtent(): number
	local own = chip
	local bar = levelBar
	if own == nil or bar == nil or not bar.Visible or bar.AbsoluteSize.Y <= 0 then
		return 0
	end
	local chipBottom = own.AbsolutePosition.Y + own.AbsoluteSize.Y
	local barBottom = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y
	return math.max(0, barBottom - chipBottom)
end

local function setAmount(value: number)
	local label = amountLabel
	if label ~= nil then
		-- Just the number: the shell icon beside it already says what it counts.
		label.Text = Currency.digits(math.floor(value + 0.5))
	end
end

-- What else stacks in the bottom-right column above the chip while it is on screen: in a match, the Hint and
-- +10 SEC boosts docked on the chip; in the lobby, the THROW key when a toy is equipped.
local function columnParts(): { GuiObject }
	local parts: { GuiObject } = {}
	local root = playerGuiRef
	if root == nil then
		return parts
	end
	local hud = Ui.findScreen(root, "Hud")
	local boosts = if hud ~= nil then hud:FindFirstChild("BoostBar") else nil
	if hud ~= nil and hud.Visible and boosts ~= nil and boosts:IsA("GuiObject") and boosts.Visible then
		table.insert(parts, boosts)
	end
	local rail = Ui.findScreen(root, "Rail")
	local toy = if rail ~= nil then rail:FindFirstChild("ToyButton") else nil
	if rail ~= nil and rail.Visible and toy ~= nil and toy:IsA("GuiObject") and toy.Visible then
		table.insert(parts, toy)
	end
	return parts
end

-- The lobby's THROW key (Rail.ToyButton), while it is on screen.
local function shownToy(): GuiObject?
	local root = playerGuiRef
	local rail = if root ~= nil then Ui.findScreen(root, "Rail") else nil
	local toy = if rail ~= nil then rail:FindFirstChild("ToyButton") else nil
	if rail ~= nil and rail.Visible and toy ~= nil and toy:IsA("GuiObject") and toy.Visible then
		return toy
	end
	return nil
end

-- Puts the popup column just above the chip's right edge, above everything else in the column, so a pill
-- never covers it. Pills stack upward from the column's bottom. On a phone the chip hangs under the top
-- bar, so the column hangs under the chip (and the THROW key, when it shows) and its pills stack downward.
local function placePops()
	local layer = pops
	local screen = gui
	local target = chip
	if layer == nil or screen == nil or target == nil or target.AbsoluteSize.X <= 0 then
		return
	end
	local origin = screen.AbsolutePosition
	local right = target.AbsolutePosition.X + target.AbsoluteSize.X - origin.X
	local top = target.AbsolutePosition.Y - origin.Y
	if Ui.isPhone() then
		local bottom = top + target.AbsoluteSize.Y + barExtent()
		local toy = shownToy()
		if toy ~= nil and toy.AbsoluteSize.Y > 0 then
			bottom = math.max(bottom, toy.AbsolutePosition.Y + toy.AbsoluteSize.Y - origin.Y)
		end
		layer.AnchorPoint = Vector2.new(1, 0)
		layer.Position = UDim2.fromOffset(right, bottom + POP_GAP)
	else
		for _, part in columnParts() do
			if part.AbsoluteSize.Y > 0 then
				top = math.min(top, part.AbsolutePosition.Y - origin.Y)
			end
		end
		layer.AnchorPoint = Vector2.new(1, 1)
		layer.Position = UDim2.fromOffset(right, top - POP_GAP)
	end
	local scale = popsFit
	if scale ~= nil and screen.AbsoluteSize.Y > 0 then
		scale.Scale = math.clamp(screen.AbsoluteSize.Y / DESIGN_HEIGHT, MIN_FIT, 1)
	end
end

local JUMP_GAP = 16 -- pixels between Roblox's touch jump button and the chip above it
local chipRest: UDim2? = nil
local toyRest: UDim2? = nil

-- Roblox's own jump button, once the touch controls exist.
local function jumpButton(): GuiObject?
	local root = playerGuiRef
	local touch = if root ~= nil then root:FindFirstChild("TouchGui") else nil
	local frame = if touch ~= nil then touch:FindFirstChild("TouchControlFrame") else nil
	local button = if frame ~= nil then frame:FindFirstChild("JumpButton") else nil
	return if button ~= nil and button:IsA("GuiObject") then button else nil
end

-- Phones: the jump button owns the bottom-right corner, so the chip (and the THROW key on it) sit just above
-- it. Without one, both stay where they were authored.
local function dodgeJumpButton()
	local own = chip
	local screen = gui
	if own == nil or screen == nil then
		return
	end
	if chipRest == nil then
		chipRest = own.Position
	end
	local root = playerGuiRef
	local rail = if root ~= nil then Ui.findScreen(root, "Rail") else nil
	local toy = if rail ~= nil then rail:FindFirstChild("ToyButton") else nil
	if toy ~= nil and toy:IsA("GuiObject") and toyRest == nil then
		toyRest = toy.Position
	end
	local lift = UDim2.fromOffset(0, barExtent())
	local jump = jumpButton()
	if jump == nil or not jump.Visible then
		own.Position = chipRest - lift
		if toy ~= nil and toy:IsA("GuiObject") and toyRest ~= nil then
			toy.Position = toyRest - lift
		end
		return
	end
	local bottom = jump.AbsolutePosition.Y - screen.AbsolutePosition.Y - JUMP_GAP - lift.Y.Offset
	own.Position = UDim2.new(1, chipRest.X.Offset, 0, bottom)
	if toy ~= nil and toy:IsA("GuiObject") then
		toy.Position = UDim2.new(1, -16, 0, bottom - own.AbsoluteSize.Y - JUMP_GAP)
	end
end

-- Phones: the chip hangs in the top-right corner, close under the top bar buttons and in line with their
-- right edge, where no thumb covers it; the THROW key hangs right under the chip.
local function placeOnPhone()
	local own = chip
	local screen = gui
	if own == nil or screen == nil then
		return
	end
	local inset = GuiService.TopbarInset
	local right = inset.Max.X - PHONE_SIDE
	local top = inset.Max.Y + PHONE_TOP
	-- TopbarInset is measured from the screen's top-left corner; an AbsolutePosition is measured from the
	-- corner below Roblox's top bar, so it is the GUI inset short of that.
	local guiInset = GuiService:GetGuiInset()
	local origin = screen.AbsolutePosition + guiInset
	own.AnchorPoint = Vector2.new(1, 0)
	own.Position = UDim2.fromOffset(right - origin.X, top - origin.Y)
	local root = playerGuiRef
	local rail = if root ~= nil then Ui.findScreen(root, "Rail") else nil
	local toy = if rail ~= nil then rail:FindFirstChild("ToyButton") else nil
	if rail ~= nil and toy ~= nil and toy:IsA("GuiObject") then
		-- The key is a child of the rail screen, which has an origin of its own.
		local railOrigin = rail.AbsolutePosition + guiInset
		local under = top + own.AbsoluteSize.Y + barExtent() + PHONE_STACK_GAP
		toy.AnchorPoint = Vector2.new(1, 0)
		toy.Position = UDim2.fromOffset(right - railOrigin.X, under - railOrigin.Y)
	end
end

local function placeChip()
	if Ui.isPhone() then
		placeOnPhone()
	else
		dodgeJumpButton()
	end
end

local function refresh()
	local own = chip
	if own == nil then
		return
	end
	-- A phone's match strip (prompt, answer bar, boosts) needs the top of the screen to itself.
	local inMatchOnPhone = playing and Ui.isPhone()
	local root = playerGuiRef
	local answersInCorner = root ~= nil and Ui.answersListCoversCorner(root)
	own.Visible = phase ~= "Results"
		and not inMatchOnPhone
		and not answersInCorner
		and not Windows.anyOpen()
		and not Windows.covered()
		and not UserInputService.OnScreenKeyboardVisible
	placeChip()
	placePops()
end

-- Where the pill `index` places from the chip sits in the column: up from its bottom, or on a phone down
-- from its top.
local function slot(index: number): UDim2
	if Ui.isPhone() then
		return UDim2.new(1, 0, 0, index * POP_SLOT - POP_CLEAR)
	end
	return UDim2.new(1, 0, 1, -(index - 1) * POP_SLOT)
end

-- The move a fading pill makes away from the chip.
local function drift(): UDim2
	return UDim2.fromOffset(0, if Ui.isPhone() then POP_DRIFT else -POP_DRIFT)
end

local function destroyPop(pop: Frame)
	local index = table.find(live, pop)
	if index ~= nil then
		table.remove(live, index)
	end
	fading[pop] = nil
	for _, object in pop:GetDescendants() do
		Tween.cancel(object)
	end
	Tween.cancel(pop)
	pop:Destroy()
end

local function fadePop(pop: Frame)
	if pop.Parent == nil then
		return
	end
	local info = TweenInfo.new(POP_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	fading[pop] = true
	for _, object in pop:GetDescendants() do
		if object:IsA("TextLabel") then
			local goal: { [string]: any } = { TextTransparency = 1 }
			if object.BackgroundTransparency < 1 then
				goal.BackgroundTransparency = 1
			end
			Tween.play(object, info, goal)
		elseif object:IsA("UIStroke") then
			Tween.play(object, info, { Transparency = 1 })
		end
	end
	Tween.play(pop, info, { Position = pop.Position + drift(), BackgroundTransparency = 1 })
	task.delay(POP_FADE + 0.02, function()
		if pop.Parent ~= nil then
			destroyPop(pop)
		end
	end)
end

local function spawnPop(text: string, caption: string?, swatchName: string)
	local layer = pops
	local template = popTemplate
	if layer == nil or template == nil then
		return
	end
	placePops()
	local pop = template:Clone() :: Frame
	pop.Name = "PopLive"
	local face = pop:FindFirstChild("Lip")
	local swatch = SWATCHES[swatchName]
	if face ~= nil and face:IsA("UIGradient") and swatch ~= nil then
		paint(face, swatch)
	end
	local amount = pop:FindFirstChild("Amount")
	if amount ~= nil and amount:IsA("TextLabel") then
		amount.Text = text
	end
	local sub = pop:FindFirstChild("Caption")
	if sub ~= nil and sub:IsA("TextLabel") then
		sub.Text = caption or ""
		sub.Visible = caption ~= nil
	end
	pop.Position = slot(1)
	pop.Parent = layer
	table.insert(live, 1, pop)
	-- Older popups slide one slot further from the chip. Tween keeps one tween per instance, so a pill that
	-- is already fading carries its fade into the slide or its face would stay opaque.
	for index = 2, #live do
		local older = live[index]
		if fading[older] then
			Tween.play(older, TweenInfo.new(POP_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = slot(index) + drift(),
				BackgroundTransparency = 1,
			})
		else
			Tween.play(older, Theme.Tween.Enter, { Position = slot(index) })
		end
	end
	while #live > MAX_POPS do
		destroyPop(live[#live])
	end
	-- A chunky bounce: in from small, overshooting before it settles.
	pop.Visible = true
	local scale = pop:FindFirstChildOfClass("UIScale")
	if scale ~= nil then
		scale.Scale = 0.3
		Tween.play(scale, POP_IN, { Scale = 1 })
	end
	task.delay(POP_HOLD, fadePop, pop)
end

function Wallet.init(playerGui: PlayerGui)
	playerGuiRef = playerGui
	Windows.Changed.connect(refresh)
	Ui.watchAnswersList(playerGui, refresh)
	UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(refresh)
	counter:GetPropertyChangedSignal("Value"):Connect(function()
		setAmount(counter.Value)
	end)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Wallet", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Wallet: StarterGui.Wallet is missing; no lobby Shells chip or popups")
			return
		end
		local ownChip = found:WaitForChild("Chip", WAIT_SECONDS)
		local layer = found:WaitForChild("Pops", WAIT_SECONDS)
		local template = if layer ~= nil then layer:WaitForChild("PopTemplate", WAIT_SECONDS) else nil
		if ownChip == nil or not ownChip:IsA("Frame") or layer == nil or not layer:IsA("Frame") then
			warn("Wallet: StarterGui.Wallet needs Chip and Pops frames")
			return
		end
		gui = found
		chip = ownChip
		local chipScale = ownChip:FindFirstChildOfClass("UIScale")
		if Ui.isPhone() and chipScale ~= nil then
			-- Ui.bump settles at "Rest", so the count-up bounce keeps the smaller size.
			chipScale:SetAttribute("Rest", PHONE_CHIP_SCALE)
			chipScale.Scale = PHONE_CHIP_SCALE
		end
		-- The touch controls appear with the character and move with the screen: follow them.
		if UserInputService.TouchEnabled then
			task.spawn(function()
				while true do
					placeChip()
					placePops()
					task.wait(0.5)
				end
			end)
		end
		pops = layer
		local fit = layer:FindFirstChild("Fit")
		popsFit = if fit ~= nil and fit:IsA("UIScale") then fit else nil
		found:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			placeChip()
			placePops()
		end)
		local bar = ownChip:FindFirstChild("LevelBar")
		if bar ~= nil and bar:IsA("Frame") then
			levelBar = bar
			local fill = bar:FindFirstChild("Fill")
			levelFill = if fill ~= nil and fill:IsA("Frame") then fill else nil
			local label = bar:FindFirstChild("Label")
			levelLabel = if label ~= nil and label:IsA("TextLabel") then label else nil
			local gain = bar:FindFirstChild("Gain")
			if gain ~= nil and gain:IsA("TextLabel") then
				gain.Visible = false
				gainTemplate = gain
			end
			local highlight = bar:FindFirstChild("Highlight")
			local stroke = if highlight ~= nil then highlight:FindFirstChildOfClass("UIStroke") else nil
			if stroke ~= nil then
				rimStroke = stroke
				rimColor = stroke.Color
			end
		else
			warn("Wallet: Chip.LevelBar is missing; no level bar")
		end
		local amount = ownChip:FindFirstChild("Amount")
		if amount ~= nil and amount:IsA("TextLabel") then
			amountLabel = amount
		end
		if template ~= nil and template:IsA("Frame") then
			template.Visible = false
			popTemplate = template
		end
		-- Always on screen; it reads 0 until the first profile arrives.
		setAmount(counter.Value)
		refresh()
	end)
end

-- A "+15 XP" beside the level bar that floats up and fades. Each gain gets its own.
local function popGain(amount: number)
	local template = gainTemplate
	if template == nil then
		return
	end
	local pop = template:Clone()
	pop.Name = "GainLive"
	pop.Text = "+" .. amount .. " XP"
	pop.TextTransparency = 1
	pop.Visible = true
	pop.Parent = template.Parent
	local rest = pop.Position
	pop.Position = rest + UDim2.fromOffset(12, 0)
	local outline = pop:FindFirstChildOfClass("UIStroke")
	Tween.play(pop, Theme.Tween.Pop, { Position = rest, TextTransparency = 0 })
	task.delay(Theme.Tween.Pop.Time, function()
		local rise = TweenInfo.new(GAIN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween.play(pop, rise, { Position = rest - UDim2.fromOffset(0, GAIN_RISE), TextTransparency = 1 })
		if outline ~= nil then
			Tween.play(outline, rise, { Transparency = 1 })
		end
		task.delay(GAIN_SECONDS, function()
			pop:Destroy()
		end)
	end)
end

-- The bar's rim lights up in `color`, then settles back to its authored colour.
local function flashRim(color: Color3)
	local stroke = rimStroke
	local rest = rimColor
	if stroke == nil or rest == nil then
		return
	end
	stroke.Color = color
	Tween.play(stroke, Theme.Tween.Flash, { Color = rest })
end

local function popLabel()
	local label = levelLabel
	if label ~= nil then
		Ui.bump(label, 1.35)
	end
end

-- Level up: the bar fills to the end and flashes gold, a LEVEL callout lands with confetti and a fanfare,
-- then the bar starts over from the new level's progress.
local function celebrateLevel(level: number, target: UDim2)
	local fill = levelFill
	if fill == nil then
		return
	end
	Tween.play(fill, FILL_TWEEN, { Size = UDim2.fromScale(1, 1) })
	task.delay(FILL_TWEEN.Time, function()
		if shownLevel ~= level then
			return
		end
		flashRim(Theme.Color.Gold)
		local label = levelLabel
		if label ~= nil then
			label.Text = "LV " .. level
		end
		popLabel()
		Fx.callout("LEVEL " .. level .. "!", Theme.Color.Gold)
		Fx.confetti(LEVEL_CONFETTI)
		Sfx.play("Fanfare", 0.7)
		fill.Size = UDim2.fromScale(0, 1)
		Tween.play(fill, FILL_TWEEN, { Size = target })
	end)
end

-- Shows the level and fills the bar. A gain pops "+N XP" beside it, sweeps the fill and flashes the rim.
local function showLevel(xp: number)
	local label = levelLabel
	local fill = levelFill
	if label == nil or fill == nil then
		return
	end
	local info = Levels.progress(xp)
	local share = if info.need > 0 then info.into / info.need else 0
	local target = UDim2.fromScale(share, 1)
	local previousLevel = shownLevel
	local previousXp = shownXp
	shownLevel = info.level
	shownXp = xp
	if previousLevel == nil or previousXp == nil then
		label.Text = "LV " .. info.level
		Tween.cancel(fill)
		fill.Size = target
		return
	end
	local gained = math.floor(xp - previousXp + 0.5)
	if gained <= 0 then
		label.Text = "LV " .. info.level
		fill.Size = target
		return
	end
	popGain(gained)
	if info.level > previousLevel then
		celebrateLevel(info.level, target)
		return
	end
	flashRim(SKY)
	popLabel()
	Sfx.play("Tick", 0.4, 1.4)
	Tween.play(fill, FILL_TWEEN, { Size = target })
end

-- ProfileChanged payload (Net.ProfilePayload). The first one sets the chip; later ones count up to it.
function Wallet.onProfile(profile)
	if type(profile) ~= "table" or type(profile.cash) ~= "number" then
		return
	end
	if type(profile.xp) == "number" then
		showLevel(profile.xp)
	end
	local cash = math.floor(profile.cash)
	local previous = shown
	shown = cash
	if previous == nil then
		Tween.cancel(counter)
		counter.Value = cash
		setAmount(cash)
		refresh()
		return
	end
	if cash == previous then
		return
	end
	local seconds = math.clamp(math.abs(cash - previous) / 60, 0.35, 1.1)
	Tween.play(counter, TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = cash })
end

-- ShellsEarned payload {amount, reason}: amount is negative for a spend.
function Wallet.onShells(payload)
	if type(payload) ~= "table" or type(payload.amount) ~= "number" then
		return
	end
	local amount = math.floor(payload.amount + 0.5)
	if amount == 0 then
		return
	end
	local reason = if type(payload.reason) == "string" then payload.reason else nil
	local caption = if reason ~= nil then CAPTIONS[reason] else nil
	local target = chip
	if amount > 0 then
		spawnPop("+" .. Currency.digits(amount), caption, "Gold")
		-- Bigger payouts ring a little higher.
		Sfx.play("Coin", 0.6, 1 + math.clamp(amount / 100, 0, 0.3))
		if reason == "win" then
			Sfx.play("Ping", 0.7)
		end
		if target ~= nil then
			Ui.bump(target, if amount >= 100 then 1.22 else 1.14)
		end
	else
		spawnPop("-" .. Currency.digits(-amount), caption or CAPTIONS.spend, "Red")
		Sfx.play("Coin", 0.5, 0.7)
	end
end

function Wallet.onState(payload)
	phase = payload.phase
	playing = payload.playing == true
	refresh()
end

return Wallet
