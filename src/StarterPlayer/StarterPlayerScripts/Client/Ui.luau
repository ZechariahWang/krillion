--!strict
-- Micro-interactions shared by the controllers, plus the live parts of the Studio-authored UI. Every
-- outline, gradient, corner and caption is authored in Studio; this module only animates and tracks them.
-- The big pop-ups (eliminated, revive, results, callouts) show bigger through their UIScale only, fitted to
-- the screen, so the HUD between pop-ups stays as small as authored.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local Ui = {}

type TextObject = TextLabel | TextButton

-- A phone or tablet: touch with no keyboard. A touchscreen laptop keeps the desktop layout.
function Ui.isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local DARK_TEXT = 0.3 -- text darker than this needs no dark outline (it would only blur it)
local WAIT_SECONDS = 10 -- how long binding waits for a root ScreenGui before warning
local PATH_WAIT = 5
local LIP_PRESS = 3 -- pixels the lip shrinks while a button is held

-- Every animated element has a UIScale authored in Studio; without one, scale animations are skipped.
local function scaleOf(object: GuiObject): UIScale?
	return object:FindFirstChildOfClass("UIScale")
end

-- The scale an element settles at: 1, or the "Rest" attribute Ui.grow puts on a pop-up shown bigger than
-- authored. Every animation below starts and ends relative to it.
local function restOf(scale: UIScale): number
	local rest = scale:GetAttribute("Rest")
	return if type(rest) == "number" then rest else 1
end

local basePositions: { [GuiObject]: UDim2 } = {}

local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

-- The resting scale of an element (see restOf), for controllers that run their own scale tweens.
function Ui.rest(object: GuiObject): number
	local scale = scaleOf(object)
	return if scale ~= nil then restOf(scale) else 1
end

-- Hover brightens the panel slightly (chunky buttons lift instead, since they are opaque); press dips the
-- scale a hair and squashes the lip. Parts are looked up per event, so a later restyle still animates.
function Ui.pressable(button: GuiButton)
	local restTransparency = button.BackgroundTransparency
	local hoverTransparency = math.max(0, restTransparency - 0.15)
	local function lipOf(): UIGradient?
		local lipObject = button:FindFirstChild("Lip")
		return if lipObject ~= nil and lipObject:IsA("UIGradient") then lipObject else nil
	end
	local function chunky(): boolean
		return button:GetAttribute("Chunky") == true
	end
	local function release(hovered: boolean)
		local scale = scaleOf(button)
		if scale == nil then
			return
		end
		local rest = restOf(scale)
		Tween.play(scale, Theme.Tween.Hover, { Scale = if hovered and chunky() then rest * 1.05 else rest })
		local lip = lipOf()
		if lip ~= nil then
			Tween.play(lip, Theme.Tween.Hover, { Offset = Vector2.zero })
		end
	end
	button.MouseEnter:Connect(function()
		if scaleOf(button) == nil then
			return
		end
		if chunky() then
			release(true)
		else
			Tween.play(button, Theme.Tween.Hover, { BackgroundTransparency = hoverTransparency })
		end
	end)
	button.MouseLeave:Connect(function()
		if scaleOf(button) == nil then
			return
		end
		if not chunky() then
			Tween.play(button, Theme.Tween.Hover, { BackgroundTransparency = restTransparency })
		end
		release(false)
	end)
	button.MouseButton1Down:Connect(function()
		local scale = scaleOf(button)
		if scale == nil then
			return
		end
		Tween.play(scale, Theme.Tween.Press, { Scale = restOf(scale) * 0.98 })
		-- The press moves the lip line, not the button, so list and grid layouts are never fought.
		local lip = lipOf()
		if lip ~= nil then
			local height = math.max(button.AbsoluteSize.Y, 1)
			Tween.play(lip, Theme.Tween.Press, { Offset = Vector2.new(0, math.min(LIP_PRESS / height, 0.12)) })
		end
	end)
	button.MouseButton1Up:Connect(function()
		release(chunky())
	end)
end

-- Shows an element with a short settle from 96% scale. No overshoot.
function Ui.appear(object: GuiObject)
	object.Visible = true
	local scale = scaleOf(object)
	if scale == nil then
		return
	end
	local rest = restOf(scale)
	scale.Scale = rest * 0.96
	Tween.play(scale, Theme.Tween.Enter, { Scale = rest })
end

-- A springy entrance that overshoots slightly and settles, for reward moments.
function Ui.pop(object: GuiObject, from: number?)
	object.Visible = true
	local scale = scaleOf(object)
	if scale == nil then
		return
	end
	local rest = restOf(scale)
	scale.Scale = rest * (from or 0.85)
	Tween.play(scale, Theme.Tween.Pop, { Scale = rest })
end

-- The big party-game entrance from 60%. Keep it for the reveal and rare moments (Rare+, Mythic, wins).
function Ui.bounce(object: GuiObject)
	object.Visible = true
	local scale = scaleOf(object)
	if scale == nil then
		return
	end
	local rest = restOf(scale)
	scale.Scale = rest * 0.6
	Tween.play(scale, Theme.Tween.Bounce, { Scale = rest })
end

-- A small tick, used on timer seconds and counters.
function Ui.bump(object: GuiObject, size: number)
	local scale = scaleOf(object)
	if scale == nil then
		return
	end
	local rest = restOf(scale)
	scale.Scale = rest * size
	Tween.play(scale, Theme.Tween.Tick, { Scale = rest })
end

-- A short horizontal nudge, the "no" gesture for a rejected answer.
function Ui.nudge(object: GuiObject)
	local base = basePositions[object]
	if base == nil then
		base = object.Position
		basePositions[object] = base
	end
	task.spawn(function()
		local offsets = { 6, -6, 3, 0 }
		for _, offset in offsets do
			local goal = UDim2.new(base.X.Scale, base.X.Offset + offset, base.Y.Scale, base.Y.Offset)
			Tween.play(object, Theme.Tween.Nudge, { Position = goal })
			task.wait(0.06)
		end
		object.Position = base
	end)
end

-- Removes rows cloned from a template, leaving the template and any other children (titles) alone.
function Ui.clearClones(parent: Instance, templateName: string, clonePrefix: string)
	for _, child in parent:GetChildren() do
		local isClone = string.sub(child.Name, 1, #clonePrefix) == clonePrefix
		if isClone and child.Name ~= templateName then
			child:Destroy()
		end
	end
end

function Ui.tierColor(tier: string?): Color3
	if tier == nil then
		return Theme.Color.Grey
	end
	local color = Theme.Tier[tier]
	if color == nil then
		return Theme.Color.Ink
	end
	return color
end

-- Green while there is plenty of time, then yellow, then red.
function Ui.timerColor(fraction: number): Color3
	if fraction > 0.5 then
		return Theme.Color.Green
	end
	if fraction > 0.25 then
		return Theme.Color.Yellow
	end
	return Theme.Color.Red
end

-- Live text ------------------------------------------------------------------------------------------------

-- A UIGradient tints everything its object draws, text included, so a text object with a face gradient
-- draws its text through an authored child "LiftedText" label, and its own glyphs are hidden with
-- MaxVisibleGraphemes = 0. Code keeps setting Text, TextColor3 and the rest on the object; every change
-- is mirrored onto the caption.
local MIRRORED = {
	"Text",
	"TextColor3",
	"TextTransparency",
	"FontFace",
	"TextSize",
	"TextScaled",
	"TextWrapped",
	"RichText",
	"TextXAlignment",
	"TextYAlignment",
	"LineHeight",
	"TextTruncate",
	"TextStrokeColor3",
	"TextStrokeTransparency",
}
local mirrored: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function mirrorCaption(source: TextObject, caption: TextLabel)
	if mirrored[caption] then
		return
	end
	mirrored[caption] = true
	for _, property in MIRRORED do
		(caption :: any)[property] = (source :: any)[property]
		source:GetPropertyChangedSignal(property :: any):Connect(function()
			(caption :: any)[property] = (source :: any)[property]
		end)
	end
end

local boundStrokes: { [UIStroke]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Outline width follows the rendered text height, so small row text never drowns in its stroke.
local function outlineWidth(label: TextObject, cap: number): number
	local height = label.TextSize
	if label.TextScaled then
		height = label.AbsoluteSize.Y
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if limit ~= nil then
			height = math.min(height, limit.MaxTextSize)
		end
	end
	if height <= 0 then
		return cap
	end
	return math.clamp(height / 12, 1, cap)
end

-- Makes an authored "Outline" stroke track its label: it fades with TextTransparency, switches off on
-- dark text and thins on small text. The stroke's "Cap" attribute is its full thickness.
local function bindOutline(label: TextObject, stroke: UIStroke)
	if boundStrokes[stroke] then
		return
	end
	boundStrokes[stroke] = true
	local cap = stroke:GetAttribute("Cap")
	if type(cap) ~= "number" then
		cap = stroke.Thickness
		stroke:SetAttribute("Cap", cap)
	end
	local base = stroke:GetAttribute("BaseTransparency")
	if type(base) ~= "number" then
		base = stroke.Transparency
		stroke:SetAttribute("BaseTransparency", base)
	end
	local baseTransparency = base :: number
	local function refresh()
		stroke.Enabled = luminance(label.TextColor3) >= DARK_TEXT
		stroke.Transparency = math.max(baseTransparency, label.TextTransparency)
	end
	local function resize()
		local current = stroke:GetAttribute("Cap")
		stroke.Thickness = outlineWidth(label, if type(current) == "number" then current else stroke.Thickness)
	end
	label:GetPropertyChangedSignal("TextColor3"):Connect(refresh)
	label:GetPropertyChangedSignal("TextTransparency"):Connect(refresh)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	stroke:GetAttributeChangedSignal("Cap"):Connect(resize)
	refresh()
	resize()
end

local function isText(object: Instance?): boolean
	return object ~= nil and (object:IsA("TextLabel") or object:IsA("TextButton"))
end

local function bindOne(object: Instance)
	if object:IsA("UIStroke") and object.Name == "Outline" and isText(object.Parent) then
		bindOutline(object.Parent :: TextObject, object)
	elseif object:IsA("TextLabel") and object.Name == "LiftedText" and isText(object.Parent) then
		mirrorCaption(object.Parent :: TextObject, object)
	end
end

-- Pop-up sizing ------------------------------------------------------------------------------------------

-- Pixels a grown pop-up keeps from every screen edge, and the least it may shrink to fit a small phone.
local FIT_MARGIN = 8
local MIN_FIT = 0.6

-- The authored on-screen size of an object inside a parent of `parentSize` pixels, before any UIScale.
local function naturalSize(object: GuiObject, parentSize: Vector2): Vector2
	local size = object.Size
	local x = size.X.Scale * parentSize.X + size.X.Offset
	local y = size.Y.Scale * parentSize.Y + size.Y.Offset
	local limit = object:FindFirstChildOfClass("UISizeConstraint")
	if limit ~= nil then
		x = math.clamp(x, limit.MinSize.X, math.max(limit.MinSize.X, limit.MaxSize.X))
		y = math.clamp(y, limit.MinSize.Y, math.max(limit.MinSize.Y, limit.MaxSize.Y))
	end
	local aspect = object:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect ~= nil and aspect.AspectRatio > 0 and y > 0 then
		if x / y > aspect.AspectRatio then
			x = y * aspect.AspectRatio
		else
			y = x / aspect.AspectRatio
		end
	end
	return Vector2.new(x, y)
end

-- The box an object and its direct children cover, from its own top-left, unscaled. Children that hang
-- outside it (the results extras strip under the panel) count, so the whole pop-up stays on screen.
local function extent(object: GuiObject, size: Vector2): (Vector2, Vector2)
	local lowX, lowY, highX, highY = 0, 0, size.X, size.Y
	if object:FindFirstChildWhichIsA("UIGridStyleLayout") == nil then
		for _, child in object:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				local childSize = naturalSize(child, size)
				local position = child.Position
				local left = position.X.Scale * size.X + position.X.Offset - child.AnchorPoint.X * childSize.X
				local top = position.Y.Scale * size.Y + position.Y.Offset - child.AnchorPoint.Y * childSize.Y
				lowX = math.min(lowX, left)
				lowY = math.min(lowY, top)
				highX = math.max(highX, left + childSize.X)
				highY = math.max(highY, top + childSize.Y)
			end
		end
	end
	return Vector2.new(lowX, lowY), Vector2.new(highX, highY)
end

-- The biggest scale up to `desired` that keeps the object inside its ScreenGui. A UIScale grows an object
-- around its anchor point, so each side is checked against the room between the anchor and that edge.
local function fitScale(object: GuiObject, desired: number): number
	local parentObject = object.Parent
	local rootObject = object:FindFirstAncestorWhichIsA("LayerCollector")
	if parentObject == nil or not parentObject:IsA("GuiBase2d") or rootObject == nil then
		return desired
	end
	local parent = parentObject :: GuiBase2d
	local root = rootObject :: LayerCollector
	local screenPosition = root.AbsolutePosition
	local screenSize = root.AbsoluteSize
	if screenSize.X <= 0 or screenSize.Y <= 0 then
		return desired
	end
	local parentPosition = parent.AbsolutePosition
	local parentSize = parent.AbsoluteSize
	local size = naturalSize(object, parentSize)
	local position = object.Position
	local pivotX = parentPosition.X + position.X.Scale * parentSize.X + position.X.Offset
	local pivotY = parentPosition.Y + position.Y.Scale * parentSize.Y + position.Y.Offset
	local anchorX = object.AnchorPoint.X * size.X
	local anchorY = object.AnchorPoint.Y * size.Y
	local low, high = extent(object, size)
	local scale = desired
	local function limit(reach: number, room: number)
		if reach > 0 then
			scale = math.min(scale, room / reach)
		end
	end
	limit(anchorX - low.X, pivotX - screenPosition.X - FIT_MARGIN)
	limit(high.X - anchorX, screenPosition.X + screenSize.X - FIT_MARGIN - pivotX)
	limit(anchorY - low.Y, pivotY - screenPosition.Y - FIT_MARGIN)
	limit(high.Y - anchorY, screenPosition.Y + screenSize.Y - FIT_MARGIN - pivotY)
	return math.max(scale, MIN_FIT)
end

local grown: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Shows a pop-up up to `desired` times its authored size through its UIScale ("Rest" attribute, which
-- every Ui animation settles at), shrunk to fit the screen. Refits when the screen turns or children are
-- added. Sizes and positions are never written, so the Studio layout stays as authored.
function Ui.grow(object: GuiObject, desired: number)
	local found = scaleOf(object)
	if found == nil then
		return
	end
	local scale = found :: UIScale
	local function refit()
		local rest = fitScale(object, desired)
		if scale:GetAttribute("Rest") ~= nil and math.abs(rest - restOf(scale)) < 0.005 then
			return
		end
		scale:SetAttribute("Rest", rest)
		if object.Visible then
			Tween.play(scale, Theme.Tween.Hover, { Scale = rest })
		else
			scale.Scale = rest
		end
	end
	refit()
	if grown[object] then
		return
	end
	grown[object] = true
	local root = object:FindFirstAncestorWhichIsA("LayerCollector") :: LayerCollector?
	if root ~= nil then
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	end
	object.ChildAdded:Connect(function()
		task.defer(refit)
	end)
end

-- Phone portrait layouts ----------------------------------------------------------------------------------

-- Property overrides keyed by a path under a panel ("" is the panel itself, "Rows/GroupRow/Button" a child).
export type Overrides = { [string]: { [string]: any } }

export type PhoneLayout = {
	authored: UDim2, -- the panel's authored (landscape) size
	portrait: UDim2, -- its size in the portrait layout
	apply: (portrait: boolean) -> (),
}

-- A second, taller and narrower layout for a fixed-size panel authored for landscape, so a portrait phone
-- shows it at a readable scale instead of shrinking the wide one to under half size. The authored values are
-- read once here, so turning the phone back restores them exactly.
function Ui.phoneLayout(panel: GuiObject, portraitSize: UDim2, overrides: Overrides): PhoneLayout
	local authored: { [Instance]: { [string]: any } } = {}
	local swapped: { [Instance]: { [string]: any } } = {}
	local all: Overrides = table.clone(overrides)
	all[""] = { Size = portraitSize }
	for path, properties in all do
		local object: Instance? = panel
		if path ~= "" then
			for _, part in string.split(path, "/") do
				object = if object ~= nil then object:FindFirstChild(part) else nil
			end
		end
		if object ~= nil then
			local saved: { [string]: any } = authored[object] or {}
			local goal: { [string]: any } = swapped[object] or {}
			for key, value in properties do
				saved[key] = (object :: any)[key]
				goal[key] = value
			end
			authored[object] = saved
			swapped[object] = goal
		end
	end
	local current: boolean? = nil
	return {
		authored = panel.Size,
		portrait = portraitSize,
		apply = function(portrait: boolean)
			if current == portrait then
				return
			end
			current = portrait
			for object, properties in if portrait then swapped else authored do
				for key, value in properties do
					(object :: any)[key] = value
				end
			end
		end,
	}
end

-- Fits a fixed-size panel inside the screen through its holder's UIScale, `margin` pixels clear of every
-- edge. With a phone layout it takes the portrait one only when the authored one would show too small
-- (under `portraitBelow`) and the portrait one shows bigger.
function Ui.fitPanel(
	screenSize: Vector2,
	panel: GuiObject,
	fit: UIScale,
	layout: PhoneLayout?,
	margin: number,
	minScale: number,
	portraitBelow: number
)
	if screenSize.X <= 0 or screenSize.Y <= 0 then
		return
	end
	local function scaleFor(size: UDim2): number
		local width = math.max(size.X.Offset, 1)
		local height = math.max(size.Y.Offset, 1)
		return math.min((screenSize.X - margin * 2) / width, (screenSize.Y - margin * 2) / height)
	end
	if layout ~= nil then
		local wide = scaleFor(layout.authored)
		layout.apply(wide < portraitBelow and scaleFor(layout.portrait) > wide)
	end
	fit.Scale = math.clamp(scaleFor(panel.Size), minScale, 1)
end

-- Top bar --------------------------------------------------------------------------------------------------

local TOPBAR_GAP = 8 -- pixels between Roblox's last top bar button and ours (Roblox's own spacing)
local TOPBAR_BOTTOM = 2 -- Roblox's buttons end this far above the bottom of GuiService.TopbarInset

-- Puts a 44 px circle button on the line of Roblox's own top bar buttons, `slot` places right of them
-- (0 is next to them). Call again when GuiService.TopbarInset or the button's size changes.
function Ui.placeTopButton(button: GuiObject, slot: number)
	local inset = GuiService.TopbarInset
	local size = button.AbsoluteSize
	local x = inset.Min.X + TOPBAR_GAP + slot * (size.X + TOPBAR_GAP)
	local y = inset.Max.Y - TOPBAR_BOTTOM - size.Y
	button.AnchorPoint = Vector2.zero
	button.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

-- Screens --------------------------------------------------------------------------------------------------

-- Each screen is a full-screen Frame under one of three ScreenGuis authored in Studio: LobbyUi (only in the
-- lobby), GameUi (only in a match) and SharedUi (both). Controllers show a screen with Visible.
local ROOT_OF: { [string]: string } = {
	Rail = "LobbyUi",
	Shop = "LobbyUi",
	Inventory = "LobbyUi",
	Store = "LobbyUi",
	LobbyQuiz = "LobbyUi",
	Quests = "LobbyUi",
	Rewards = "LobbyUi",
	Tutorial = "LobbyUi",
	Hud = "GameUi",
	Reveal = "GameUi",
	Results = "GameUi",
	Revive = "GameUi",
	Spectate = "GameUi",
	Vignette = "GameUi",
	Status = "SharedUi",
	Toasts = "SharedUi",
	Fx = "SharedUi",
	Wallet = "SharedUi",
	Settings = "SharedUi",
	Transition = "SharedUi",
	DiveCards = "SharedUi",
	ChestReveal = "SharedUi",
}
local ROOTS = { "LobbyUi", "GameUi", "SharedUi" }

-- The screen frame by name, waiting up to `timeout` seconds (forever without one), or nil.
function Ui.screen(playerGui: PlayerGui, name: string, timeout: number?): Frame?
	local rootName = ROOT_OF[name]
	if rootName == nil then
		return nil
	end
	local root: Instance?
	local found: Instance?
	if timeout == nil then
		root = playerGui:WaitForChild(rootName)
		found = (root :: Instance):WaitForChild(name)
	else
		root = playerGui:WaitForChild(rootName, timeout)
		found = if root ~= nil then root:WaitForChild(name, timeout) else nil
	end
	if found ~= nil and found:IsA("Frame") then
		return found
	end
	return nil
end

-- The screen frame by name if it is already there, without waiting.
function Ui.findScreen(playerGui: PlayerGui, name: string): Frame?
	local rootName = ROOT_OF[name]
	local root = if rootName ~= nil then playerGui:FindFirstChild(rootName) else nil
	local found = if root ~= nil then root:FindFirstChild(name) else nil
	if found ~= nil and found:IsA("Frame") then
		return found
	end
	return nil
end

-- Screens with the "BelowTopbar" attribute keep clear of the Roblox top bar. Studio has no top bar, so they
-- are authored flush with the top and moved down here by the real inset, again whenever the top bar changes
-- (it is still 0 while the top bar loads).
local function placeBelowTopbar(root: Instance)
	local function apply()
		local inset = GuiService:GetGuiInset()
		for _, child in root:GetChildren() do
			if child:IsA("GuiObject") and child:GetAttribute("BelowTopbar") == true then
				child.Position = UDim2.new(0, 0, 0, inset.Y)
				child.Size = UDim2.new(1, 0, 1, -inset.Y)
			end
		end
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(apply)
	apply()
end

-- Live binding -------------------------------------------------------------------------------------------

-- Pop-ups shown bigger than authored (through their UIScale), by root and dotted path.
local GROWS: { [string]: { [string]: number } } = {
	GameUi = {
		["Revive.Card"] = Theme.Chunky.Grow.Card,
		["Results.Panel"] = Theme.Chunky.Grow.Results,
	},
}

local function find(root: Instance, path: string): Instance?
	local current: Instance? = root
	for name in string.gmatch(path, "[^%.]+") do
		if current == nil then
			return nil
		end
		current = (current :: Instance):WaitForChild(name, PATH_WAIT)
	end
	return current
end

local boundRoots: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Wires up the live parts of a ScreenGui, BillboardGui or SurfaceGui authored in Studio, and of everything
-- later cloned into it: outlines track their text, lifted captions mirror it and pop-ups fit the screen.
-- Nothing is created or restyled. Safe to call twice.
function Ui.bindGui(root: LayerCollector)
	if boundRoots[root] then
		return
	end
	boundRoots[root] = true
	for _, object in root:GetDescendants() do
		bindOne(object)
	end
	root.DescendantAdded:Connect(function(object)
		task.defer(bindOne, object)
	end)
	local grows = GROWS[root.Name]
	if grows == nil then
		return
	end
	task.spawn(function()
		for path, desired in grows do
			local found = find(root, path)
			if found ~= nil and found:IsA("GuiObject") then
				Ui.grow(found, desired)
			end
		end
	end)
end

-- World text players see all the time: head labels and the lobby leaderboard.
local function isWorldText(object: Instance): boolean
	if object:IsA("BillboardGui") then
		return object.Name == "RareOrSinkName"
	end
	if object:IsA("SurfaceGui") then
		return object:FindFirstAncestor("Leaderboard") ~= nil
	end
	return false
end

-- Binds the three roots and the world text. Call once from Main.client with the PlayerGui; it never yields.
function Ui.bindAll(playerGui: PlayerGui)
	for _, name in ROOTS do
		task.spawn(function()
			local gui = playerGui:WaitForChild(name, WAIT_SECONDS)
			if gui == nil or not gui:IsA("ScreenGui") then
				warn(`Ui: StarterGui.{name} is missing`)
				return
			end
			placeBelowTopbar(gui)
			-- GameUi is off in Studio so the lobby is what opens; its screens show through Visible.
			gui.Enabled = true
			Ui.bindGui(gui)
		end)
	end
	task.spawn(function()
		for _, object in workspace:GetDescendants() do
			if isWorldText(object) then
				Ui.bindGui(object :: LayerCollector)
			end
		end
		workspace.DescendantAdded:Connect(function(object)
			if isWorldText(object) then
				task.defer(Ui.bindGui, object :: LayerCollector)
			end
		end)
	end)
end

return Ui
