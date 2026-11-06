--!strict
-- Drives StarterGui.Toasts: a short stack of big chunky banners at the bottom centre (server Notify and local
-- ones). Kinds: "info" | "good" | "bad" | "krillion" | "hint", plus "shells" and "reward" (a "good" toast about
-- Shells or an unlock gets those looks on its own). "HEADLINE  |  details" splits into a big line and a sub line.
-- The stack lifts above whatever bottom-centre bar is showing (the answer bar during a prompt, the spectate bar,
-- the join card) so a toast never covers input. Toasts pop in with an overshoot and slide out quickly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)

local WAIT_SECONDS = 10
local MAX_TOASTS = 3
local MAX_TOASTS_SHORT = 2 -- on a short screen (landscape phone) fewer banners fit above the bars
local SHORT_HEIGHT = 560
local DESIGN_HEIGHT = 820 -- screen height the banners are drawn for; shorter screens scale the stack down
local MIN_FIT = 0.62
local MAX_QUEUED = 6 -- a burst longer than this drops its oldest waiting toasts
local SPACING_SECONDS = 0.4 -- a burst of toasts arrives one at a time, this far apart
local BASE_GAP = 110 -- pixels from the bottom edge to the bottom of the stack
local PROMPT_GAP = 170 -- while answering: clears the answer bar and the hint row above it
local CLEARANCE = 10 -- pixels kept above a bar the stack lifts over
local MAX_LIFT = 0.45 -- never lift the stack past this fraction of the screen height
local PLACE_INTERVAL = 0.25
local EXIT_SECONDS = 0.22
local EXIT_SLIDE = 90 -- pixels a banner slides right as it leaves
local MAX_CHARS = 160
local SPLIT = "  |  "
local POP_IN = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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

type Style = {
	swatch: string, -- Theme.Chunky.Color the banner is painted with
	icon: string,
	life: number, -- seconds on screen
	sound: string?,
	kicker: string?, -- small line above the text
	text: Color3?, -- headline colour when it is not white
}

local STYLES: { [string]: Style } = {
	info = { swatch = "Sky", icon = Theme.Icon.Wave, life = 3.4 },
	good = { swatch = "Lime", icon = Theme.Icon.Check, life = 3.4, sound = "Ping" },
	shells = { swatch = "Gold", icon = Theme.Icon.Shell, life = 3.6, sound = "Ping" },
	reward = { swatch = "Pink", icon = Theme.Icon.Gift, life = 4, sound = "Ping" },
	bad = { swatch = "Red", icon = "❌", life = 3.6, sound = "Deny" },
	krillion = {
		swatch = "Purple",
		icon = Theme.Icon.Sparkle,
		life = 5,
		sound = "Fanfare",
		text = Color3.fromRGB(255, 217, 94),
	},
	hint = { swatch = "Sea", icon = Theme.Icon.Hint, life = 9, sound = "Pop", kicker = "HINT" },
}
local SWATCHES: { [string]: Swatch } = Theme.Chunky.Color :: any

-- A "good" toast about an unlock or a gift reads as a reward, one about Shells as a payout.
local REWARD_WORDS = { "UNLOCKED", "REWARD", "WELCOME", "THANKS" }

-- Bottom-centre elements (ScreenGui, child path) the stack floats above while they show.
local AVOID: { { string } } = {
	{ "Hud", "AnswerBar" },
	{ "Lobby", "SpectateBar" },
	{ "Lobby", "JoinCard" },
	{ "Lobby", "WatchButton" },
}

local root: PlayerGui? = nil
local stack: Frame? = nil
local fit: UIScale? = nil
local template: Frame? = nil
local live: { Frame } = {}
local queue: { { text: string, kind: string } } = {}
local pumping = false
local order = 0
local prompting = false -- the local player is answering a prompt right now
local goShown = false

local Toasts = {}

local function clip(text: string): string
	local length = utf8.len(text)
	if length == nil then
		return string.sub(text, 1, MAX_CHARS)
	end
	if length <= MAX_CHARS then
		return text
	end
	local stop = utf8.offset(text, MAX_CHARS - 2)
	if stop == nil then
		return text
	end
	return string.sub(text, 1, stop - 1) .. "..."
end

-- The look for a toast: server kinds are fixed, so a "good" one is sorted by what it says.
local function styleKey(text: string, kind: string): string
	if kind ~= "good" then
		return kind
	end
	local upper = string.upper(text)
	for _, word in REWARD_WORDS do
		if string.find(upper, word, 1, true) ~= nil then
			return "reward"
		end
	end
	if string.find(text, Theme.Icon.Shell, 1, true) ~= nil or string.find(upper, "SHELLS", 1, true) ~= nil then
		return "shells"
	end
	return "good"
end

-- "QUEST COMPLETE  |  PLAY 1 MATCH  +75" -> headline "QUEST COMPLETE", sub "PLAY 1 MATCH  +75".
local function split(text: string): (string, string?)
	local at = string.find(text, SPLIT, 1, true)
	if at == nil or at <= 1 then
		return text, nil
	end
	local rest = string.sub(text, at + #SPLIT)
	if rest == "" then
		return string.sub(text, 1, at - 1), nil
	end
	return string.sub(text, 1, at - 1), rest
end

local function limit(): number
	local box = stack
	local screen = if box ~= nil then box:FindFirstAncestorWhichIsA("LayerCollector") else nil
	if screen ~= nil and screen:IsA("LayerCollector") then
		local height = screen.AbsoluteSize.Y
		if height > 0 and height < SHORT_HEIGHT then
			return MAX_TOASTS_SHORT
		end
	end
	return MAX_TOASTS
end

local function textOf(parent: Instance?, name: string): TextLabel?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("TextLabel") then found else nil
end

-- Slides the banner's card out to the right and fades it, then frees its slot.
local function dismiss(toast: Frame)
	local index = table.find(live, toast)
	if index == nil then
		return
	end
	table.remove(live, index)
	local info = TweenInfo.new(EXIT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local card = toast:FindFirstChild("Card")
	for _, object in toast:GetDescendants() do
		if object:IsA("TextLabel") then
			Tween.play(object, info, { TextTransparency = 1 })
		elseif object:IsA("UIStroke") then
			Tween.play(object, info, { Transparency = 1 })
		elseif object:IsA("Frame") and object ~= card and object.BackgroundTransparency < 1 then
			Tween.play(object, info, { BackgroundTransparency = 1 })
		end
	end
	if card ~= nil and card:IsA("GuiObject") then
		-- One tween slides and fades the card, since Tween keeps one per instance.
		local goal = card.Position + UDim2.fromOffset(EXIT_SLIDE, 0)
		Tween.play(card, info, { Position = goal, BackgroundTransparency = 1 })
	end
	task.delay(EXIT_SECONDS + 0.02, function()
		for _, object in toast:GetDescendants() do
			Tween.cancel(object)
		end
		Tween.cancel(toast)
		toast:Destroy()
	end)
end

local function display(text: string, kind: string)
	local box = stack
	local source = template
	if box == nil or source == nil then
		return
	end
	local key = styleKey(text, kind)
	local style = STYLES[key] or STYLES.info
	order += 1
	local toast = source:Clone() :: Frame
	toast.Name = "ToastLive"
	toast.LayoutOrder = order
	local card = toast:FindFirstChild("Card")
	if card ~= nil and card:IsA("GuiObject") then
		local face = card:FindFirstChild("Lip")
		local swatch = SWATCHES[style.swatch]
		if face ~= nil and face:IsA("UIGradient") and swatch ~= nil then
			paint(face, swatch)
		end
		local icon = textOf(card:FindFirstChild("Accent"), "Icon")
		if icon ~= nil then
			icon.Text = style.icon
		end
		local content = card:FindFirstChild("Content")
		local headline, rest = split(text)
		local kicker = textOf(content, "Kicker")
		if kicker ~= nil then
			kicker.Visible = style.kicker ~= nil
			kicker.Text = style.kicker or ""
		end
		local body = textOf(content, "Text")
		if body ~= nil then
			body.Text = headline
			if style.text ~= nil then
				body.TextColor3 = style.text
			end
			-- A krillion find is a headline, not a note.
			if key == "krillion" then
				body.TextSize += 4
			end
		end
		local sub = textOf(content, "Sub")
		if sub ~= nil then
			sub.Text = rest or ""
			sub.Visible = rest ~= nil
		end
	end
	toast.Visible = true
	toast.Parent = box
	table.insert(live, toast)
	-- A bouncy pop-in: the card grows from small, overshooting a little before it settles.
	local scale = if card ~= nil then card:FindFirstChildOfClass("UIScale") else nil
	if scale ~= nil then
		scale.Scale = if key == "krillion" then 0.4 else 0.55
		Tween.play(scale, POP_IN, { Scale = 1 })
	end
	while #live > limit() do
		dismiss(live[1])
	end
	local sound = style.sound
	if sound ~= nil then
		Sfx.play(sound, if key == "krillion" then 0.8 else 0.6)
	end
	task.delay(style.life, dismiss, toast)
end

local function pump()
	if pumping or stack == nil then
		return
	end
	pumping = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			if item ~= nil then
				display(item.text, item.kind)
			end
			task.wait(SPACING_SECONDS)
		end
		pumping = false
	end)
end

local function isShowing(object: GuiObject): boolean
	local current: Instance? = object
	while current ~= nil do
		if current:IsA("LayerCollector") then
			return current.Enabled
		end
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return false
end

-- Top edge of an element and of its visible children (a hint row or confirm chip above the bar).
local function topOf(object: GuiObject): number
	local top = object.AbsolutePosition.Y
	for _, child in object:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			top = math.min(top, child.AbsolutePosition.Y)
		end
	end
	return top
end

-- Pixels from the bottom edge the stack should sit at: clear of the answer bar while answering and of any
-- bottom-centre bar it overlaps, but never past MAX_LIFT of the screen.
local function wantedGap(): number
	local gap = if prompting then PROMPT_GAP else BASE_GAP
	local playerGui = root
	local box = stack
	if playerGui == nil or box == nil then
		return gap
	end
	local screen = box:FindFirstAncestorWhichIsA("LayerCollector")
	if screen == nil or not screen:IsA("LayerCollector") then
		return gap
	end
	local height = screen.AbsoluteSize.Y
	if height <= 0 then
		return gap
	end
	local left = box.AbsolutePosition.X
	local right = left + box.AbsoluteSize.X
	for _, entry in AVOID do
		local holder = playerGui:FindFirstChild(entry[1])
		local object = if holder ~= nil then holder:FindFirstChild(entry[2]) else nil
		if object ~= nil and object:IsA("GuiObject") and isShowing(object) then
			local x = object.AbsolutePosition.X
			local overlaps = x < right and x + object.AbsoluteSize.X > left
			local owner = object:FindFirstAncestorWhichIsA("LayerCollector")
			if overlaps and owner ~= nil and owner:IsA("LayerCollector") then
				-- Measured from each ScreenGui's own bottom edge, so a different top inset does not matter.
				local bottom = owner.AbsolutePosition.Y + owner.AbsoluteSize.Y
				local lift = bottom - topOf(object) + CLEARANCE
				if lift <= height * MAX_LIFT then
					gap = math.max(gap, lift)
				end
			end
		end
	end
	return math.min(gap, height * MAX_LIFT)
end

-- Short screens draw the banners smaller, so they still fit between the bars and the status line.
local function fitStack(box: Frame)
	local scale = fit
	local screen = box:FindFirstAncestorWhichIsA("LayerCollector")
	if scale == nil or screen == nil or not screen:IsA("LayerCollector") then
		return
	end
	local height = screen.AbsoluteSize.Y
	if height > 0 then
		scale.Scale = math.clamp(height / DESIGN_HEIGHT, MIN_FIT, 1)
	end
end

local function followBars(box: Frame)
	local current = -1
	while box.Parent ~= nil do
		fitStack(box)
		local gap = math.floor(wantedGap() + 0.5)
		if gap ~= current then
			local goal = UDim2.new(box.Position.X.Scale, box.Position.X.Offset, 1, -gap)
			if current < 0 then
				box.Position = goal
			else
				Tween.play(box, Theme.Tween.Enter, { Position = goal })
			end
			current = gap
		end
		task.wait(PLACE_INTERVAL)
	end
end

local function onState(payload)
	if type(payload) ~= "table" then
		return
	end
	prompting = payload.phase == "Prompt" and payload.playing == true
	-- The match's first prompt, once, for players on a pillar.
	local go = prompting and payload.round == 1
	if go and not goShown then
		Toasts.show("ROUND 1  |  GO NICHE!", "info")
	end
	goShown = go
end

function Toasts.init(playerGui: PlayerGui)
	root = playerGui
	task.spawn(function()
		Net.event("RoundState").OnClientEvent:Connect(onState)
	end)
	task.spawn(function()
		local found = playerGui:WaitForChild("Toasts", WAIT_SECONDS)
		if found == nil or not found:IsA("ScreenGui") then
			warn("Toasts: StarterGui.Toasts is missing; toasts are not shown")
			return
		end
		local box = found:WaitForChild("Stack", WAIT_SECONDS)
		local source = if box ~= nil then box:WaitForChild("ToastTemplate", WAIT_SECONDS) else nil
		if box == nil or not box:IsA("Frame") or source == nil or not source:IsA("Frame") then
			warn("Toasts: StarterGui.Toasts needs Stack.ToastTemplate")
			return
		end
		source.Visible = false
		stack = box
		template = source
		local scale = box:FindFirstChild("Fit")
		fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
		task.spawn(followBars, box)
		pump()
	end)
end

-- Notify payload {text, kind} from the server.
function Toasts.onNotify(payload)
	if type(payload) ~= "table" or type(payload.text) ~= "string" then
		return
	end
	Toasts.show(payload.text, if type(payload.kind) == "string" then payload.kind else nil)
end

-- Shows a local toast. Other controllers call this (late-join results, hints, sunk names).
-- Toasts that arrive together are shown SPACING_SECONDS apart; until the GUI is bound they wait.
function Toasts.show(text: string, kind: string?)
	if type(text) ~= "string" then
		return
	end
	local message = clip(string.match(text, "^%s*(.-)%s*$") or "")
	if message == "" then
		return
	end
	local style = if kind ~= nil and STYLES[kind] ~= nil then kind else "info"
	table.insert(queue, { text = message, kind = style })
	while #queue > MAX_QUEUED do
		table.remove(queue, 1)
	end
	pump()
end

return Toasts
