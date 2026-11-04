--!strict
-- Micro-interactions shared by the controllers, plus the party-game style pass. Everything about the UI
-- layout is set in Studio (or in a model.json); the style pass only adds fonts, outlines, corners, gradients
-- and header colour to what is already there, and never moves or resizes a panel, button or label. The big
-- pop-ups (eliminated, revive, results, callouts) get the chunky toy look and show bigger through their
-- UIScale only, fitted to the screen, so the HUD between pop-ups stays as small as authored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local Ui = {}

type TextObject = TextLabel | TextButton

local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = 0.3 -- text darker than this needs no dark outline (it would only blur it)
local WAIT_SECONDS = 10 -- how long the style pass waits for a ScreenGui before giving up quietly
local PATH_WAIT = 5
local HEADER_PAD = 6 -- pixels of header bar under a panel's title
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

-- Multiplied over a button's face: a soft top-to-bottom shade, then a hard band 40% darker along the
-- bottom edge, so a flat button reads as a chunky key sitting on its lip. Model.json buttons can author
-- the same thing as a UIGradient named "Lip" (Rotation 90) to get the press animation.
local LIP_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, WHITE),
	ColorSequenceKeypoint.new(0.84, Color3.fromRGB(222, 222, 222)),
	ColorSequenceKeypoint.new(0.86, Color3.fromRGB(153, 153, 153)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 153, 153)),
})
-- A light gloss for coloured header bars and bright panels.
local GLOSS_COLORS = ColorSequence.new(WHITE, Color3.fromRGB(205, 205, 205))
local PANEL_COLORS = ColorSequence.new(Theme.Panel.Top, Theme.Panel.Bottom)

-- The resting scale of an element (see restOf), for controllers that run their own scale tweens.
function Ui.rest(object: GuiObject): number
	local scale = scaleOf(object)
	return if scale ~= nil then restOf(scale) else 1
end

-- The element's UIScale, added if Studio did not author one, so pop-ups restyled in code still animate.
function Ui.ensureScale(object: GuiObject): UIScale
	local scale = scaleOf(object)
	if scale ~= nil then
		return scale
	end
	local created = Instance.new("UIScale")
	created.Parent = object
	return created
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

-- The big party-game entrance from 60%. Keep it for the reveal and rare moments (Rare+, Krillion, wins).
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

-- Style pass ---------------------------------------------------------------------------------------------

-- Theme.Icon glyph for a name ("Shell", "Trophy"...), or the text itself if it is not a known icon.
function Ui.icon(name: string): string
	local icons: { [string]: string } = Theme.Icon :: any
	return icons[name] or name
end

-- Keeps an emoji in front of whatever text code sets on the label ("🐚 1,250 SHELLS"), so icons sit
-- beside existing text without a new element. `when` can limit it to some texts (timers only, say).
function Ui.prefixIcon(label: TextObject, name: string, when: ((string) -> boolean)?)
	local prefix = Ui.icon(name) .. " "
	local function apply()
		local text = label.Text
		if text == "" or string.sub(text, 1, #prefix) == prefix then
			return
		end
		if when ~= nil and not when(text) then
			return
		end
		label.Text = prefix .. text
	end
	label:GetPropertyChangedSignal("Text"):Connect(apply)
	apply()
end

local function isFamily(font: Font, family: string): boolean
	return string.find(font.Family, family, 1, true) ~= nil
end

-- Labels whose job is reading rather than shouting use the body face and no outline.
local BODY_NAMES: { [string]: boolean } = {
	Subtitle = true,
	YourAnswer = true,
	Answer = true,
	Name = true,
	Watching = true,
	NextText = true,
}
-- Big display text gets the thickest outline.
local TITLE_NAMES: { [string]: boolean } = {
	Title = true,
	Status = true,
	Callout = true,
	BannerText = true,
	WinnerText = true,
	PointsText = true,
}

-- A UIGradient tints everything its object draws, text included, so white text on a gradient face came out
-- in the face colour (and a white "!" on a red badge vanished). A text object with a face gradient draws its
-- text through a child "LiftedText" label instead, since a gradient never reaches children; the object's own
-- glyphs are hidden with MaxVisibleGraphemes. Code keeps setting Text, TextColor3 and the rest on the
-- object as before, and every change is mirrored onto the caption.
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
-- Gradients that colour a face. Others (the gold text gradient on callouts) are meant to colour the text.
local FACE_GRADIENTS: { [string]: boolean } = { Lip = true, Fill = true, Gloss = true, Face = true }
local captions: { [Instance]: TextLabel } = setmetatable({}, { __mode = "k" }) :: any

-- The label that actually draws this object's text: its caption once lifted, otherwise itself.
local function textOf(label: TextObject): TextObject
	return captions[label] or label
end

local function liftText(object: Instance)
	if captions[object] ~= nil or object.Name == "LiftedText" then
		return
	end
	if not (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return
	end
	local source = object :: TextObject
	-- A clone of an already lifted template brings its caption (and the moved outline) along, but not the
	-- mirroring, so that caption is adopted and wired up instead of drawing a second one over it.
	local cloned = source:FindFirstChild("LiftedText")
	local caption: TextLabel
	if cloned ~= nil and cloned:IsA("TextLabel") then
		caption = cloned
	else
		caption = Instance.new("TextLabel")
		caption.Name = "LiftedText"
		caption.BackgroundTransparency = 1
		caption.BorderSizePixel = 0
		caption.Size = UDim2.fromScale(1, 1)
	end
	caption.ZIndex = source.ZIndex
	for _, property in MIRRORED do
		(caption :: any)[property] = (source :: any)[property]
		source:GetPropertyChangedSignal(property :: any):Connect(function()
			(caption :: any)[property] = (source :: any)[property]
		end)
	end
	for _, child in source:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			child.Parent = caption
		elseif child:IsA("UITextSizeConstraint") then
			child:Clone().Parent = caption
		end
	end
	source.MaxVisibleGraphemes = 0
	captions[object] = caption
	caption.Parent = source
end

local function hasFaceGradient(object: Instance): boolean
	for _, child in object:GetChildren() do
		if child:IsA("UIGradient") and FACE_GRADIENTS[child.Name] then
			return true
		end
	end
	return false
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

-- Makes an outline stroke track its label: it fades with TextTransparency, switches off on dark text and
-- thins on small text. Clones of a styled template carry the stroke but not these connections, which is
-- why the style pass rebinds anything added later.
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
	-- The cap is read each time, so Ui.setOutline can thicken an outline that is already bound.
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

-- Adds (or adopts) the dark Contextual outline on a label or button text. Model.json UIs that author
-- their own UIStroke named "Outline" get the same tracking from Ui.restyleGui.
function Ui.outline(target: TextObject, thickness: number?)
	local label = textOf(target)
	local existing = label:FindFirstChild("Outline")
	if existing ~= nil and existing:IsA("UIStroke") then
		bindOutline(label, existing)
		return
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Theme.Outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = thickness or Theme.Stroke.Label
	stroke.Parent = label
	bindOutline(label, stroke)
end

-- The thick pop-up outline in the chunky colour. Adopts whatever stroke the label already has, so it
-- never ends up with two.
function Ui.setOutline(target: TextObject, cap: number)
	local label = textOf(target)
	local named = label:FindFirstChild("Outline")
	local stroke: UIStroke? = if named ~= nil and named:IsA("UIStroke") then named else label:FindFirstChildOfClass("UIStroke")
	if stroke == nil then
		local created = Instance.new("UIStroke")
		created.Parent = label
		stroke = created
	end
	local outline = stroke :: UIStroke
	outline.Name = "Outline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Theme.Chunky.Outline
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline:SetAttribute("Cap", cap)
	outline.Thickness = cap
	bindOutline(label, outline)
end

-- Chunky display text with an outline, or the body face for reading text. Fonts that are already
-- Fredoka or Builder Sans were chosen on purpose and are left alone; only the old Roboto look changes.
function Ui.styleText(object: TextObject)
	local font = object.FontFace
	local styled = isFamily(font, "FredokaOne") or isFamily(font, "BuilderSans")
	if not styled then
		object.FontFace = if BODY_NAMES[object.Name] then Theme.Font.Body else Theme.Font.Display
	end
	if hasFaceGradient(object) then
		liftText(object)
	end
	if object.Name == "Icon" or object.TextStrokeTransparency < 1 then
		return
	end
	-- The outline goes on whatever draws the text; the caption sits inside the object's own Border stroke.
	local label = textOf(object)
	local own = label:FindFirstChild("Outline")
	if own ~= nil and own:IsA("UIStroke") then
		bindOutline(label, own)
		return
	end
	-- One stroke per object: a Border stroke someone authored (badges, chips) stays the only one.
	if label:FindFirstChildOfClass("UIStroke") ~= nil then
		return
	end
	if not isFamily(label.FontFace, "FredokaOne") then
		return
	end
	local cap = if TITLE_NAMES[object.Name] then Theme.Stroke.Title else Theme.Stroke.Label
	if object:IsA("TextButton") then
		cap = Theme.Stroke.Button
	end
	Ui.outline(label, cap)
end

local function setCorner(object: GuiObject, radius: number)
	local corner = object:FindFirstChildOfClass("UICorner")
	if corner == nil then
		corner = Instance.new("UICorner")
		corner.Parent = object
	elseif corner.CornerRadius.Scale > 0 then
		return -- pills and circles keep their shape
	end
	(corner :: UICorner).CornerRadius = UDim.new(0, radius)
end

local function addGradient(object: GuiObject, name: string, colors: ColorSequence)
	if object:FindFirstChildOfClass("UIGradient") ~= nil then
		return
	end
	liftText(object)
	local gradient = Instance.new("UIGradient")
	gradient.Name = name
	gradient.Rotation = 90
	gradient.Color = colors
	gradient.Parent = object
end

local function addBorder(object: GuiObject, thickness: number)
	if object:FindFirstChildOfClass("UIStroke") ~= nil then
		return
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = thickness
	stroke.Parent = object
end

-- Chunky style --------------------------------------------------------------------------------------------

type Swatch = { Top: Color3, Bottom: Color3, Lip: Color3 }

local SWATCHES: { [string]: Swatch } = Theme.Chunky.Color :: any
-- The navy chip fill (timer pill, coin chip, tide chip) with a thin darker lip, so the HUD chips match the
-- pop-ups without growing.
local NAVY: Swatch = { Top = Theme.Panel.Top, Bottom = Theme.Panel.Bottom, Lip = Theme.Panel.Lip }
local CHIP_LIP = 3

-- Top-to-bottom shade, then a hard band `lip` pixels tall along the bottom edge: a slab sitting on its lip.
local function lipColors(swatch: Swatch, height: number, lip: number): ColorSequence
	local edge = math.clamp(1 - lip / math.max(height, 1), 0.5, 0.97)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, swatch.Top),
		ColorSequenceKeypoint.new(edge - 0.01, swatch.Bottom),
		ColorSequenceKeypoint.new(edge, swatch.Lip),
		ColorSequenceKeypoint.new(1, swatch.Lip),
	})
end

type Shade = { swatch: Swatch, lip: number }
local shades: { [UIGradient]: Shade } = setmetatable({}, { __mode = "k" }) :: any

-- Paints a white face with the swatch through a UIGradient (adopting one the object already has), keeping
-- the lip band the same height in pixels as the object resizes.
local function shade(object: GuiObject, name: string, swatch: Swatch, lip: number)
	liftText(object)
	local existing = object:FindFirstChildOfClass("UIGradient")
	local gradient: UIGradient
	if existing ~= nil then
		gradient = existing
	else
		gradient = Instance.new("UIGradient")
		gradient.Parent = object
	end
	gradient.Name = name
	gradient.Rotation = 90
	gradient.Offset = Vector2.zero
	gradient.Transparency = NumberSequence.new(0)
	object.BackgroundColor3 = WHITE
	local bound = shades[gradient] ~= nil
	shades[gradient] = { swatch = swatch, lip = lip }
	local function refresh()
		local current = shades[gradient]
		if current ~= nil then
			gradient.Color = lipColors(current.swatch, object.AbsoluteSize.Y, current.lip)
		end
	end
	refresh()
	if not bound then
		object:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	end
end

-- A dark border in the chunky colour, adopting an existing stroke on a frame (frames have no text).
local function chunkyBorder(object: GuiObject, thickness: number)
	local existing = object:FindFirstChildOfClass("UIStroke")
	local border: UIStroke
	if existing ~= nil then
		border = existing
	else
		border = Instance.new("UIStroke")
		border.Parent = object
	end
	border.Name = "Border"
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Theme.Chunky.Outline
	border.LineJoinMode = Enum.LineJoinMode.Round
	border.Thickness = thickness
end

-- A saturated toy key: the swatch shaded top to bottom over a darker lip, big corners, white display text
-- with a thick dark outline. A button shows one stroke, so the outlined text wins over a border; the lip
-- carries the shape. Hover lifts it (Ui.pressable checks the Chunky attribute).
function Ui.chunkyButton(button: TextButton, swatchName: string)
	local swatch = SWATCHES[swatchName]
	if swatch == nil or button:GetAttribute("NoRestyle") == true then
		return
	end
	button:SetAttribute("Chunky", true)
	Ui.ensureScale(button)
	button.AutoButtonColor = false
	button.BackgroundTransparency = 0
	shade(button, "Lip", swatch, Theme.Chunky.ButtonLip)
	setCorner(button, Theme.Chunky.ButtonCorner)
	button.FontFace = Theme.Font.Display
	button.TextColor3 = WHITE
	Ui.setOutline(button, Theme.Chunky.TextStroke)
end

-- A chunky backing plate for a frame: the swatch face over its lip, big corners and the thick dark border.
function Ui.plate(object: GuiObject, swatchName: string)
	local swatch = SWATCHES[swatchName]
	if swatch == nil then
		return
	end
	object.BackgroundTransparency = 0
	object.BorderSizePixel = 0
	shade(object, "Fill", swatch, Theme.Chunky.Lip)
	setCorner(object, Theme.Chunky.Corner)
	chunkyBorder(object, Theme.Chunky.Border)
end

-- A lipped key: rounded corners, the darker lip band, and one stroke. Light text gets the text outline
-- (from Ui.styleText); dark text on a bright face gets a border instead, since an object shows one stroke.
-- Translucent buttons (tabs, ghost buttons) only get their text styled.
function Ui.styleButton(button: TextButton)
	local parent = button.Parent
	if button.BackgroundTransparency > 0.2 or (parent ~= nil and parent.Name == "Tabs") then
		return
	end
	-- A coloured stripe child has square ends; a bigger corner would make them poke out.
	if button:FindFirstChild("Accent") == nil then
		setCorner(button, 12)
	end
	addGradient(button, "Lip", LIP_COLORS)
	if luminance(button.TextColor3) < DARK_TEXT or button.Text == "" then
		addBorder(button, Theme.Stroke.Button)
	end
end

local function styleBox(box: TextBox)
	if not (isFamily(box.FontFace, "FredokaOne") or isFamily(box.FontFace, "BuilderSans")) then
		box.FontFace = Theme.Font.Body
	end
	addBorder(box, 2)
end

local function skipped(object: Instance, root: Instance): boolean
	local current: Instance? = object
	while current ~= nil and current ~= root do
		if current:GetAttribute("NoRestyle") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function styleOne(object: Instance, root: Instance)
	if object.Parent == nil or skipped(object, root) then
		return
	end
	if object:IsA("TextButton") then
		Ui.styleButton(object)
		Ui.styleText(object)
	elseif object:IsA("TextLabel") then
		Ui.styleText(object)
	elseif object:IsA("TextBox") then
		styleBox(object)
	end
end

-- Sends a decoration behind its siblings so the labels it sits under stay on top.
local function sendToBack(object: GuiObject)
	local parent = object.Parent
	if parent == nil then
		return
	end
	local lowest = math.huge
	for _, sibling in parent:GetChildren() do
		if sibling ~= object and sibling:IsA("GuiObject") then
			lowest = math.min(lowest, sibling.ZIndex)
		end
	end
	if lowest ~= math.huge and object.ZIndex >= lowest then
		object.ZIndex = lowest - 1
	end
end

-- The height a header needs to sit behind the title, or nil if the title is not along the top edge.
local function headerHeight(title: GuiObject): UDim?
	local y = title.Position.Y
	local size = title.Size.Y
	local anchor = title.AnchorPoint.Y
	local topScale = y.Scale - size.Scale * anchor
	local topOffset = y.Offset - size.Offset * anchor
	if topScale > 0.12 or topOffset > 24 then
		return nil
	end
	local bottomScale = topScale + size.Scale
	if bottomScale > 0.3 then
		return nil
	end
	return UDim.new(bottomScale, topOffset + size.Offset + HEADER_PAD)
end

local function isTopBar(accent: GuiObject): boolean
	local size = accent.Size
	local position = accent.Position
	return size.X.Scale >= 0.9
		and size.Y.Scale == 0
		and size.Y.Offset <= 6
		and position.Y.Scale == 0
		and position.Y.Offset <= 4
		and accent.AnchorPoint.Y == 0
end

-- White title text on its header, unless the authored colour already stands out from the bar.
local function contrastTitle(title: Instance, bar: Color3)
	if not (title:IsA("TextLabel") or title:IsA("TextButton")) then
		return
	end
	local color = title.TextColor3
	local distance = math.abs(color.R - bar.R) + math.abs(color.G - bar.G) + math.abs(color.B - bar.B)
	if distance < 0.9 then
		title.TextColor3 = WHITE
	end
end

-- Turns a panel's thin top Accent bar into a coloured header bar behind its Title. Code that tints the
-- Accent (tier, status) now tints the whole header. Only for panels without a list layout, where the
-- Accent can sit under the Title by ZIndex; side stripes stay stripes.
local function makeHeader(panel: GuiObject, accent: GuiObject, radius: number): boolean
	local title = panel:FindFirstChild("Title")
	if title == nil or not title:IsA("GuiObject") or not isTopBar(accent) then
		return false
	end
	if panel:FindFirstChildOfClass("UIListLayout") ~= nil or panel:FindFirstChildOfClass("UIGridLayout") ~= nil then
		return false
	end
	local height = headerHeight(title)
	if height == nil then
		return false
	end
	accent.Position = UDim2.new(accent.Position.X.Scale, accent.Position.X.Offset, 0, 0)
	accent.Size = UDim2.new(accent.Size.X.Scale, accent.Size.X.Offset, height.Scale, height.Offset)
	accent.BackgroundTransparency = 0
	setCorner(accent, radius)
	addGradient(accent, "Gloss", GLOSS_COLORS)
	sendToBack(accent)
	contrastTitle(title, accent.BackgroundColor3)
	return true
end

-- Panel kinds: "panel" (big card: header bar, 14 px corners, 3 px outline), "chip" (small pill or toast:
-- 2.5 px outline), "frame" (outline only, e.g. the water meter). Dark fills become the navy gradient;
-- bright fills get a gloss. Sizes and positions are never touched.
function Ui.stylePanel(panel: GuiObject, kind: string?)
	local style = kind or "panel"
	if panel.BackgroundTransparency >= 1 then
		return
	end
	local accentObject = panel:FindFirstChild("Accent")
	local accent = if accentObject ~= nil and accentObject:IsA("GuiObject") then accentObject else nil
	local radius = if style == "panel" then 14 else 10
	local header = false
	if style == "panel" and accent ~= nil then
		header = makeHeader(panel, accent, radius)
	end
	if accent == nil or header then
		setCorner(panel, radius)
	end
	addBorder(panel, if style == "panel" then Theme.Stroke.Title elseif style == "chip" then 2.5 else 2)
	if style == "frame" then
		return
	end
	if luminance(panel.BackgroundColor3) < 0.25 and panel:FindFirstChildOfClass("UIGradient") == nil then
		if style == "chip" then
			shade(panel, "Fill", NAVY, CHIP_LIP)
		else
			panel.BackgroundColor3 = WHITE
			addGradient(panel, "Fill", PANEL_COLORS)
		end
	else
		addGradient(panel, "Gloss", GLOSS_COLORS)
	end
end

-- A frame that holds a panel's title (LobbyQuiz's HeaderBar) becomes a solid coloured bar.
local function styleHeaderBar(bar: GuiObject)
	local panel = bar.Parent
	local accent = if panel ~= nil then panel:FindFirstChild("Accent") else nil
	local color = if accent ~= nil and accent:IsA("GuiObject") then accent.BackgroundColor3 else Theme.Header.Quest
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 0
	setCorner(bar, 8)
	addGradient(bar, "Gloss", GLOSS_COLORS)
	for _, child in bar:GetChildren() do
		contrastTitle(child, color)
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
	local scale = Ui.ensureScale(object)
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

-- Pop-up restyle -----------------------------------------------------------------------------------------

type Popup = {
	fill: string, -- Theme.Chunky.Color swatch for the panel face
	header: string, -- swatch for the header bar made from the panel's top Accent
	button: string, -- swatch for every button in the panel
	buttons: { [string]: string }?, -- per-button overrides by name
	grow: number?, -- Theme.Chunky.Grow factor, or nil to keep the authored size
}

-- Turns a Studio panel into a chunky toy pop-up: opaque swatch face over a lip band, a thick dark border,
-- big corners, a saturated header bar behind a white outlined title, and chunky buttons. Nothing moves;
-- `grow` makes it bigger through its UIScale only.
function Ui.stylePopup(panel: GuiObject, spec: Popup)
	local fill = SWATCHES[spec.fill]
	if fill == nil or panel:GetAttribute("NoRestyle") == true then
		return
	end
	local radius = Theme.Chunky.Corner
	local accentObject = panel:FindFirstChild("Accent")
	if accentObject ~= nil and accentObject:IsA("GuiObject") then
		if makeHeader(panel, accentObject, radius) then
			local header = SWATCHES[spec.header]
			if header ~= nil then
				shade(accentObject, "Gloss", header, 4)
			end
		else
			-- A thin stripe that cannot become a header would poke out of the big corners; the face and
			-- border carry the colour now.
			accentObject.Visible = false
		end
	end
	panel.BackgroundTransparency = 0
	shade(panel, "Fill", fill, Theme.Chunky.Lip)
	setCorner(panel, radius)
	chunkyBorder(panel, Theme.Chunky.Border)
	local title = panel:FindFirstChild("Title")
	if title ~= nil and (title:IsA("TextLabel") or title:IsA("TextButton")) then
		title.FontFace = Theme.Font.Display
		title.TextColor3 = WHITE
		Ui.setOutline(title, Theme.Chunky.TextStroke)
	end
	local overrides = spec.buttons or {}
	for _, object in panel:GetDescendants() do
		if object:IsA("TextButton") and not skipped(object, panel) then
			Ui.chunkyButton(object, overrides[object.Name] or spec.button)
		end
	end
	if spec.grow ~= nil then
		Ui.grow(panel, spec.grow)
	end
end

-- Studio pop-ups that get the chunky look, by ScreenGui and dotted path. Everything in the match HUD stays
-- small (see PANELS); only these grow, and only while they show.
local POPUPS: { [string]: { [string]: Popup } } = {
	Lobby = {
		EliminatedCard = { fill = "Sea", header = "Red", button = "Lime", grow = Theme.Chunky.Grow.Card },
		SpectateBar = { fill = "Sea", header = "Sky", button = "Sky", buttons = { BackButton = "Pink" } },
	},
	Revive = { Card = { fill = "Berry", header = "Lime", button = "Lime", grow = Theme.Chunky.Grow.Card } },
	Results = { Panel = { fill = "Grape", header = "Gold", button = "Lime", grow = Theme.Chunky.Grow.Results } },
}

-- Studio-authored panels to restyle, by ScreenGui and dotted path. "header" is a title bar frame.
local PANELS: { [string]: { [string]: string } } = {
	Status = { SecondaryStatus = "chip", Tide = "chip" },
	Hud = {
		CoinChip = "chip",
		["AnswerBar.LockedText"] = "chip",
		["AnswerBar.Feedback"] = "chip",
		Banner = "chip",
		WaterMeter = "frame",
	},
	LobbyQuiz = { Panel = "panel", ["Panel.HeaderBar"] = "header", Result = "chip" },
	Shop = { Panel = "panel" },
	Reveal = { Badge = "panel", List = "panel" },
}

local function isClock(text: string): boolean
	return string.match(text, "^%d+:%d%d$") ~= nil
end

-- Emoji beside existing labels: the coin chip and shop counter, the tide chip, the timer, the results title.
local ICONS: { [string]: { { path: string, icon: string, when: ((string) -> boolean)? } } } = {
	Hud = { { path = "CoinChip.CoinText", icon = "Shell" } },
	Shop = { { path = "Panel.CashText", icon = "Shell" } },
	Results = { { path = "Panel.Title", icon = "Trophy" } },
	Status = {
		{ path = "Tide.Text", icon = "Wave" },
		{ path = "SecondaryStatus.Secondary", icon = "Time", when = isClock },
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

local styledRoots: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Restyles one ScreenGui, BillboardGui or SurfaceGui and everything later added to it (cloned rows keep
-- their outlines tracking). Safe to call twice. Model.json UIs authored in the style just get their
-- "Outline" strokes bound; put attribute NoRestyle=true on anything that must keep its look.
function Ui.restyleGui(root: LayerCollector)
	if styledRoots[root] then
		return
	end
	styledRoots[root] = true
	for _, object in root:GetDescendants() do
		styleOne(object, root)
	end
	root.DescendantAdded:Connect(function(object)
		task.defer(styleOne, object, root)
	end)
	local panels = PANELS[root.Name]
	local popups = POPUPS[root.Name]
	local icons = ICONS[root.Name]
	if panels == nil and popups == nil and icons == nil then
		return
	end
	task.spawn(function()
		if popups ~= nil then
			for path, spec in popups do
				local found = find(root, path)
				if found ~= nil and found:IsA("GuiObject") then
					Ui.stylePopup(found, spec)
				end
			end
		end
		if panels ~= nil then
			for path, kind in panels do
				local found = find(root, path)
				if found ~= nil and found:IsA("GuiObject") then
					if kind == "header" then
						styleHeaderBar(found)
					else
						Ui.stylePanel(found, kind)
					end
				end
			end
		end
		if icons ~= nil then
			for _, entry in icons do
				local found = find(root, entry.path)
				if found ~= nil and (found:IsA("TextLabel") or found:IsA("TextButton")) then
					Ui.prefixIcon(found, entry.icon, entry.when)
				end
			end
		end
	end)
end

-- Every ScreenGui in the game, old (Studio) and new (model.json). Missing ones are skipped quietly.
local SCREEN_GUIS = {
	"Status",
	"Hud",
	"Lobby",
	"LobbyQuiz",
	"Results",
	"Shop",
	"Revive",
	"Fx",
	"Reveal",
	"Rail",
	"Wallet",
	"Toasts",
	"Rewards",
	"Quests",
	"Tutorial",
	"Standings",
}

-- World text players see all the time: pillar name tags, head titles and the lobby leaderboard.
local function isWorldText(object: Instance): boolean
	if object:IsA("BillboardGui") then
		return object.Name == "NameTag" or object.Name == "KrillionTitle"
	end
	if object:IsA("SurfaceGui") then
		return object:FindFirstAncestor("Leaderboard") ~= nil
	end
	return false
end

-- The style pass for the whole client. Call once from Main.client with the PlayerGui; it never yields.
function Ui.restyle(playerGui: PlayerGui)
	for _, name in SCREEN_GUIS do
		task.spawn(function()
			local gui = playerGui:WaitForChild(name, WAIT_SECONDS)
			if gui ~= nil and gui:IsA("LayerCollector") then
				Ui.restyleGui(gui)
			end
		end)
	end
	task.spawn(function()
		for _, object in workspace:GetDescendants() do
			if isWorldText(object) then
				Ui.restyleGui(object :: LayerCollector)
			end
		end
		workspace.DescendantAdded:Connect(function(object)
			if isWorldText(object) then
				task.defer(Ui.restyleGui, object :: LayerCollector)
			end
		end)
	end)
end

return Ui
