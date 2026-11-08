--!strict
-- Drives SharedUi.Wallet: the chunky gold Shells chip in the bottom-right corner, always on screen (lobby and
-- match), that counts up, and the "+25 🐚 ANSWER" pills that bounce in above the corner column for every
-- payout or spend (ShellsEarned).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local MAX_POPS = 4
local POP_SLOT = 64 -- pixels between stacked pills; the newest sits closest to the chip
local POP_GAP = 12 -- pixels between the chip and the first pill
local POP_HOLD = 1.4
local POP_FADE = 0.3
local POP_DRIFT = 18 -- pixels a pill rises (away from the chip) while it fades
local DESIGN_HEIGHT = 820 -- screen height the pills are drawn for; shorter screens scale them down
local MIN_FIT = 0.65
local POP_IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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
	spend = "SPENT",
}

local gui: Frame? = nil
local chip: Frame? = nil
local amountLabel: TextLabel? = nil
local pops: Frame? = nil
local popsFit: UIScale? = nil
local popTemplate: Frame? = nil
local playerGuiRef: PlayerGui? = nil

-- Tweened for the count-up; the label follows it.
local counter = Instance.new("NumberValue")
local shown: number? = nil -- the balance the chip is heading for; nil until the first profile
local live: { Frame } = {}
local fading: { [Frame]: boolean } = {} -- pills mid-fade; a re-slot must keep their fade going

local Wallet = {}

local function setAmount(value: number)
	local label = amountLabel
	if label ~= nil then
		-- Just the number: the shell icon beside it already says what it counts.
		label.Text = Currency.digits(math.floor(value + 0.5))
	end
end

-- What else stacks in the bottom-right column above the chip while it is on screen: in a match, the Hint and
-- +10 SEC boosts docked on the chip.
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
	return parts
end

-- Puts the popup column just above the chip's right edge, above everything else in the column, so a pill
-- never covers it. Pills stack upward from the column's bottom.
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
	for _, part in columnParts() do
		if part.AbsoluteSize.Y > 0 then
			top = math.min(top, part.AbsolutePosition.Y - origin.Y)
		end
	end
	layer.AnchorPoint = Vector2.new(1, 1)
	layer.Position = UDim2.fromOffset(right, top - POP_GAP)
	local scale = popsFit
	if scale ~= nil and screen.AbsoluteSize.Y > 0 then
		scale.Scale = math.clamp(screen.AbsoluteSize.Y / DESIGN_HEIGHT, MIN_FIT, 1)
	end
end

local function refresh()
	local own = chip
	if own == nil then
		return
	end
	own.Visible = not Windows.anyOpen()
	placePops()
end

local function slot(index: number): UDim2
	return UDim2.new(1, 0, 1, -(index - 1) * POP_SLOT)
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
	Tween.play(pop, info, { Position = pop.Position + UDim2.fromOffset(0, -POP_DRIFT), BackgroundTransparency = 1 })
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
				Position = slot(index) + UDim2.fromOffset(0, -POP_DRIFT),
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
		pops = layer
		local fit = layer:FindFirstChild("Fit")
		popsFit = if fit ~= nil and fit:IsA("UIScale") then fit else nil
		found:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePops)
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

-- ProfileChanged payload (Net.ProfilePayload). The first one sets the chip; later ones count up to it.
function Wallet.onProfile(profile)
	if type(profile) ~= "table" or type(profile.cash) ~= "number" then
		return
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
		spawnPop("+" .. Currency.digits(amount) .. " " .. Theme.Icon.Shell, caption, "Gold")
		-- Bigger payouts ring a little higher.
		Sfx.play("Coin", 0.6, 1 + math.clamp(amount / 100, 0, 0.3))
		if reason == "win" then
			Sfx.play("Ping", 0.7)
		end
		if target ~= nil then
			Ui.bump(target, if amount >= 100 then 1.22 else 1.14)
		end
	else
		spawnPop("-" .. Currency.digits(-amount) .. " " .. Theme.Icon.Shell, caption or CAPTIONS.spend, "Red")
		Sfx.play("Coin", 0.5, 0.7)
	end
end

function Wallet.onState(_payload)
	refresh()
end

return Wallet
