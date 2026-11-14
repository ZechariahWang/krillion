--!strict
-- The "YOUR DIVE" card: answer tags sink through the tier depth zones as a pack, each stopping at its own
-- depth, and yours lands a tier stamp. With other players' answers on the card (options.peers) every tag
-- (a picture in a circle, then the answer) takes a lane; the view follows yours down, then glides to the
-- round's deepest answer, which is crowned, and when that answer is Rare or better the others drift away.
-- Clones ReplicatedStorage.Templates.DiveCard (authored in git as a model.json) and only drives it; used by
-- Reveal (full-screen, match) and LobbyQuiz (warm-up card). The pack's lanes and motion are Shared/DivePack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Depth = require(ReplicatedStorage.Shared.Depth)
local DivePack = require(ReplicatedStorage.Shared.DivePack)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

export type Options = {
	title: string, -- "YOUR DIVE"
	isYou: boolean, -- blue header for you, pink for someone else
	userId: number?, -- whose picture your tag carries; the local player's when isYou and this is nil
	answer: string?, -- bank spelling; nil with no tier shows NO ANSWER bobbing at the surface
	tier: string?,
	depth: number, -- metres (Depth.metres)
	oneIn: number?, -- real "1 in N players", when known
	schooled: number?, -- players who gave the same answer, when 2 or more
	shells: number?, -- Shells the answer pays; a chip pops under the stamp when this is above 0
	quick: boolean?, -- half-length dive
	scale: number?, -- card height as a fraction of the parent's height (default 1)
	fill: boolean?, -- full-screen: the card takes its parent's shape (within FILL_ASPECT), not the portrait one
	budget: number?, -- every tag has landed within this many seconds of play(); deep dives play a little faster
	peers: { Peer }?, -- everyone else's answers this round: they sink in the pack with yours
}

-- Another player's answer on your card.
export type Peer = {
	userId: number?, -- above 0 for a real player (their picture); a bot shows its initial
	name: string,
	answer: string?, -- bank spelling; nil for no answer
	tier: string?,
	depth: number, -- metres
}

export type Handle = {
	frame: Frame?, -- the clone, parented to `parent`; nil when the template is missing
	finished: () -> (), -- yields until your stamp has landed and the round's deepest answer is crowned
	destroy: () -> (),
}

type FadePart = { instance: Instance, property: string, base: number }

-- One answer tag in the pack. divers[1] is yours.
type Diver = {
	frame: Frame,
	scale: UIScale?,
	stroke: UIStroke?,
	crown: GuiObject?,
	nameLabel: TextLabel?,
	name: string,
	own: boolean,
	hasAnswer: boolean,
	depth: number, -- metres of the answer
	color: Color3, -- its tier's colour
	tierIndex: number,
	rest: number, -- the tag's resting UIScale: smaller when many lanes share the window
	x: number, -- its lane's centre, as a fraction of the window width
	slot: DivePack.Slot,
	pos: number, -- metres now, without the bob a landed tag is drawn with
	landed: boolean,
	landedAt: number,
	washAt: number?, -- when the tag started to drift away
	fade: { FadePart }?, -- its parts, while it drifts away
	gone: boolean,
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SKY_LOW = Color3.fromRGB(214, 240, 255) -- just above the surface line
local NO_ANSWER_GREY = Color3.fromRGB(200, 208, 222)
local SKY = GameConfig.Depth.SkyMetres
local BOTTOM = GameConfig.Depth.MaxMetres
local VIEW = GameConfig.Depth.ViewMetres
local RANGE = SKY + BOTTOM
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local TAG_Y = 0.46 -- window height fraction the view keeps its focus tag at
local START_SKY = SKY + 20 -- metres above the surface the pack starts at, out of sight
local ENTER_TIME = 0.45 -- the card slides up and grows into place
local ENTER_RISE = 0.07 -- card heights it slides up by
local ENTER_SCALE = 0.86
local DIVE_DELAY = 0.2 -- the tags drop in once the card is all but in place
local LAYOUT_WAIT = 0.3 -- a window that still has no size by then gets the authored proportions
local DROP_TIME = 0.32
local SETTLE_TIME = 0.32 -- your stamp landing to `finished`, at the least
local CAMERA_RATE = 9 -- how tightly the view follows its focus, per second
local FOCUS_DELAY = 0.3 -- your stamp gets this long before the view moves on to the deepest answer
local FOCUS_TIME = 0.6 -- the glide from your tag to the deepest answer
local CROWN_TIME = 0.4 -- the crown's pop, before `finished`
local SPOT_SCALE = 1.5 -- the crowned tag grows this much and slides to the middle when it is alone on screen
local SPOT_TIME = 0.4
local SPOT_CLEAR = 0.75 -- views another tag must be away, up or down, for the crowned one to count as alone
local OVERRUN = 3 -- `finished` fires this long after the pack stops whatever happens
local MAX_LANES = 4
local MIN_LANE_SCALE = 0.72 -- tags shrink this far to fit one more lane; below it the pack takes fewer lanes
local CROWD = 6 -- with more tags than this they may shrink further, so fewer are pushed down a crowded lane
local CROWD_LANE_SCALE = 0.6
local LANE_GAP = 0.012 -- window width kept clear between two lanes
local OWN_SCALE = 1.1 -- your tag is a little larger than the others
local ROW_GAP = 0.25 -- tag heights kept clear between two tags in a lane: room for the crown
local GUTTER_LEFT = 0.2 -- window width the zone labels take, when they cannot be measured
local GUTTER_RIGHT = 0.07 -- and the ruler's numbers
local GUTTER_PAD = 0.012
local SOFT_SHARE = 0.18 -- a tag slows over this share of the deepest depth...
local SOFT_MIN = 10 -- ...but at least this many metres
local SOFT_MAX = 36 -- ...and at most this many
local BOB_METRES = 1.2 -- a landed tag keeps a slow bob; the view does not follow it
local BOB_RATE = 2
local BOB_EASE = 0.4 -- seconds the bob takes to grow from nothing, so landing has no kick
local IDLE_BOB_METRES = 4 -- NO ANSWER bobs at the surface
local IDLE_BOB_RATE = 3
local WASH_LEAD = 0.35 -- the tags that stopped short start to drift away this long before the view leaves them
local WASH_BEAT = 0.15 -- one that stops later stays this long first
local WASH_TIME = 0.55 -- then drifts up, shrinks and fades over this long (no tilt: a rotated tag is not clipped)
local WASH_RISE = 22 -- metres
local WASH_SHRINK = 0.3
local WASH_STAGGER = 0.07 -- seconds between two tags starting to drift away
local IN_VIEW = NumberRange.new(-0.07, 1.07) -- window heights a tag's centre is (partly) on screen within
local TIE_METRES = 0.5 -- answers this close to the deepest share its crown
local GLIDE_SHARE = 0.76 -- of FOCUS_TIME gone when the view has all but arrived (the crown pops then)
local PEER_SOUND_GAP = 0.09 -- other tags' landing and leaving sounds are at least this far apart
local BUBBLE_COUNT = 9
local BASE_HEIGHT = 380 -- card height the authored stroke thicknesses and corner radii are tuned for
local MAX_STYLE_SCALE = 2.2 -- a full-screen card's outlines stop thickening here
local FILL_ASPECT = NumberRange.new(0.6, 2.1) -- width / height of a full-screen card, tall phone to landscape phone
local STAMP_Y = 0.665 -- the stamp's centre as a fraction of card height; confetti bursts from here
local STAMP_GAP = 0.02 -- card-height fraction kept clear between a low answer tag and the stamp
local LIP_SHADE = 0.45 -- how much darker a lip is than the face above it
local SHELLS_DELAY = 0.15 -- the Shells chip pops in just after the stamp
local TICK_METRES = 35 -- the depth counter clicks once for every this many metres your tag falls
local TICK_GAP = 0.05 -- seconds between clicks at the fastest
local ZONE_FLASH = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DiveCard = {}

local warned = false
local cardTheme: Cosmetics.CardColors? = nil -- the local player's equipped CardTheme, set by Market

local function fromRgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- Your own cards (isYou) use these colours from now on; nil puts the default look back.
function DiveCard.setTheme(colors: Cosmetics.CardColors?)
	cardTheme = colors
end

local function findTemplate(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("Templates")
	return if folder ~= nil then folder:FindFirstChild(name) else nil
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, amount)
end

local function worldY(metres: number): number
	return (metres + SKY) / RANGE
end

-- The water darkens from the surface to the abyss, tinted a little by each tier's colour.
local function zoneColor(index: number): Color3
	local tier = Tiers.List[index]
	local base = Theme.Depth.Surface:Lerp(Theme.Depth.Abyss, (index - 1) / #Tiers.List)
	return base:Lerp(Ui.tierColor(tier.name), 0.22)
end

local function oceanColors(): ColorSequence
	local surface = worldY(0)
	local points = {
		ColorSequenceKeypoint.new(0, Theme.Depth.Sky),
		ColorSequenceKeypoint.new(surface - 0.002, SKY_LOW),
		ColorSequenceKeypoint.new(surface, Theme.Depth.Surface),
	}
	for index = 2, #Tiers.List do
		table.insert(points, ColorSequenceKeypoint.new(worldY(Tiers.List[index].depthMin), zoneColor(index)))
	end
	table.insert(points, ColorSequenceKeypoint.new(1, Theme.Depth.Abyss))
	return ColorSequence.new(points)
end

-- The first letter of a name, for a tag with no picture.
local function initialOf(name: string): string
	if #name == 0 then
		return "?"
	end
	local second = utf8.offset(name, 2)
	return string.upper(string.sub(name, 1, (second or #name + 1) - 1))
end

-- A tag's Avatar circle: a real player's headshot, or a bot's initial on a colour picked by its name. A real
-- player shows their initial too until the picture has loaded, so the circle is never empty: the picture and
-- the initial to hide then are returned while it is still loading (IsLoaded has no change signal to wait on).
local function fillAvatar(tag: Frame, userId: number?, name: string): (ImageLabel?, TextLabel?)
	local avatar = tag:FindFirstChild("Avatar")
	if avatar == nil or not avatar:IsA("GuiObject") then
		return nil, nil
	end
	local real = userId ~= nil and userId > 0
	local image = avatar:FindFirstChild("Image")
	local picture = if image ~= nil and image:IsA("ImageLabel") then image else nil
	if picture ~= nil then
		picture.Visible = real
		if real then
			picture.Image = string.format(HEADSHOT, userId :: number)
		end
	end
	local initial = avatar:FindFirstChild("Initial")
	local letter = if initial ~= nil and initial:IsA("TextLabel") then initial else nil
	local loading = real and picture ~= nil and not picture.IsLoaded
	if letter ~= nil then
		letter.Text = initialOf(name)
		letter.Visible = not real or loading
	end
	if not real then
		local sum = 0
		for index = 1, #name do
			sum += string.byte(name, index)
		end
		avatar.BackgroundColor3 = Theme.Confetti[sum % #Theme.Confetti + 1]:Lerp(BLACK, 0.2)
	end
	if loading then
		return picture, letter
	end
	return nil, nil
end

-- Everything in a tag that can be faded, with the transparency it has at rest.
local function fadeParts(root: Instance): { FadePart }
	local parts: { FadePart } = {}
	local function add(instance: Instance)
		if instance:IsA("GuiObject") then
			table.insert(parts, { instance = instance, property = "BackgroundTransparency", base = instance.BackgroundTransparency })
			if instance:IsA("TextLabel") then
				table.insert(parts, { instance = instance, property = "TextTransparency", base = instance.TextTransparency })
			elseif instance:IsA("ImageLabel") then
				table.insert(parts, { instance = instance, property = "ImageTransparency", base = instance.ImageTransparency })
			end
		elseif instance:IsA("UIStroke") then
			table.insert(parts, { instance = instance, property = "Transparency", base = instance.Transparency })
		end
	end
	add(root)
	for _, descendant in root:GetDescendants() do
		add(descendant)
	end
	return parts
end

local function setFade(parts: { FadePart }, amount: number)
	for _, part in parts do
		(part.instance :: any)[part.property] = part.base + (1 - part.base) * amount
	end
end

local function emptyHandle(): Handle
	return {
		frame = nil,
		finished = function() end,
		destroy = function() end,
	}
end

function DiveCard.play(parent: GuiObject, options: Options): Handle
	local template = findTemplate("DiveCard")
	if template == nil or not template:IsA("Frame") then
		if not warned then
			warned = true
			warn("[DiveCard] ReplicatedStorage.Templates.DiveCard is missing; dive cards are off")
		end
		return emptyHandle()
	end

	local quick = options.quick == true
	local speed = if quick then 0.5 else 1
	local volume = if quick then 0.45 else 1
	local tierName = options.tier
	local tierInfo = if tierName ~= nil then Tiers.ByName[tierName] else nil
	local hasAnswer = tierInfo ~= nil
	local tierIndex = Tiers.index(tierName)
	local isMythic = tierName == "Mythic"
	local tierColor = Ui.tierColor(tierName)
	-- 0 for the commonest tier up to 1 for Mythic: drives how hard your landing hits.
	local intensity = if hasAnswer then math.clamp((tierIndex - 1) / math.max(#Tiers.List - 1, 1), 0, 1) else 0
	local shells = if hasAnswer then options.shells or 0 else 0
	local random = Random.new()

	local connections: { RBXScriptConnection } = {}
	local tweens: { Tween } = {}
	local strokes: { { stroke: UIStroke, base: number } } = {}
	local corners: { { corner: UICorner, base: number } } = {}
	local destroyed = false

	local function play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
		local tween = TweenService:Create(instance, info, goal)
		table.insert(tweens, tween)
		tween:Play()
		return tween
	end

	local function sound(name: string, gain: number, pitch: number)
		if volume > 0 then
			Sfx.play(name, gain * volume, pitch)
		end
	end

	-- Card shell -----------------------------------------------------------------------------------------
	local frame = (template :: Frame):Clone()
	frame.Size = UDim2.fromScale(1, options.scale or 1)
	local cardScale = frame:FindFirstChildOfClass("UIScale") :: UIScale
	local body = frame:FindFirstChild("Card") :: Frame -- the visible card; its Shadow sibling sits under it
	local shadow = frame:FindFirstChild("Shadow")
	local cardStroke = body:FindFirstChild("Border") :: UIStroke
	local header = body:FindFirstChild("Header") :: Frame
	local headerLip = body:FindFirstChild("HeaderLip") :: Frame
	local titleLabel = header:FindFirstChild("Title") :: TextLabel
	local window = body:FindFirstChild("WaterWindow") :: Frame
	local content = window:FindFirstChild("Content") :: Frame
	local gradient = content:FindFirstChild("Gradient") :: UIGradient
	local ruler = content:FindFirstChild("Ruler") :: Frame
	local tickTemplate = ruler:FindFirstChild("Tick") :: TextLabel
	local bubbleTemplate = window:FindFirstChild("Bubble") :: Frame
	local rope = window:FindFirstChild("Rope") :: Frame
	local soloTag = window:FindFirstChild("AnswerTag") :: Frame
	local peerTemplate = window:FindFirstChild("PeerTag")
	local counter = body:FindFirstChild("DepthText") :: TextLabel
	local footer = body:FindFirstChild("Footer") :: TextLabel
	local schooledChip = body:FindFirstChild("SchooledChip") :: Frame
	-- Stamp and ShellsChip are a transparent holder (scale, tilt) around a dark Lip and a gradient Face.
	local stamp = body:FindFirstChild("Stamp") :: Frame
	local stampScale = stamp:FindFirstChildOfClass("UIScale") :: UIScale
	local stampFace = stamp:FindFirstChild("Face") :: Frame
	local stampLip = stamp:FindFirstChild("Lip") :: Frame
	local stampLabel = stampFace:FindFirstChild("Label") :: TextLabel
	local shellsChip = body:FindFirstChild("ShellsChip") :: Frame
	local shellsScale = shellsChip:FindFirstChildOfClass("UIScale") :: UIScale
	local shellsFace = shellsChip:FindFirstChild("Face") :: Frame
	local shellsLip = shellsChip:FindFirstChild("Lip") :: Frame
	local shellsText = shellsFace:FindFirstChild("Text") :: TextLabel
	local confettiLayer = body:FindFirstChild("ConfettiLayer") :: Frame

	local headerColor = if options.isYou then Theme.Header.You else Theme.Header.Other
	-- Your equipped card theme (DiveCard.setTheme) recolours the header, the card face and the answer tag.
	local themed = if options.isYou then cardTheme else nil
	if themed ~= nil then
		headerColor = fromRgb(themed.header)
		local face = body:FindFirstChild("Fill")
		if face ~= nil and face:IsA("UIGradient") then
			local frameColor = fromRgb(themed.frame)
			face.Color = ColorSequence.new(lighten(frameColor, 0.18), frameColor)
		end
	end
	header.BackgroundColor3 = headerColor
	headerLip.BackgroundColor3 = headerColor:Lerp(BLACK, LIP_SHADE)
	titleLabel.Text = string.upper(options.title)
	gradient.Color = oceanColors()
	-- Past the bottom of the scale the window's own colour carries the abyss on.
	window.BackgroundColor3 = Theme.Depth.Abyss

	-- Zone lines follow Tiers, so a retuned band moves its line too. Each keeps its colours, to flash from.
	local zones: { [number]: { label: TextLabel?, line: Frame?, labelColor: Color3, lineColor: Color3 } } = {}
	for index, tier in Tiers.List do
		local zoneLine = content:FindFirstChild("ZoneLine" .. index)
		if zoneLine ~= nil and zoneLine:IsA("Frame") then
			zoneLine.Position = UDim2.fromScale(0, worldY(tier.depthMin))
			local lineColor = lighten(Ui.tierColor(tier.name), 0.25)
			local labelColor = lighten(Ui.tierColor(tier.name), 0.35)
			local line = zoneLine:FindFirstChild("Line")
			if line ~= nil and line:IsA("Frame") then
				line.BackgroundColor3 = lineColor
			end
			local zoneLabel = zoneLine:FindFirstChild("Label")
			if zoneLabel ~= nil and zoneLabel:IsA("TextLabel") then
				zoneLabel.Text = string.format("%s  %d m", string.upper(tier.label), tier.depthMin)
				zoneLabel.TextColor3 = labelColor
			end
			zones[index] = {
				label = if zoneLabel ~= nil and zoneLabel:IsA("TextLabel") then zoneLabel else nil,
				line = if line ~= nil and line:IsA("Frame") then line else nil,
				labelColor = labelColor,
				lineColor = lineColor,
			}
		end
	end

	for metres = 100, BOTTOM - 20, 100 do
		local mark = tickTemplate:Clone()
		mark.Name = "Tick" .. metres
		mark.Text = tostring(metres)
		mark.Position = UDim2.fromScale(tickTemplate.Position.X.Scale, worldY(metres))
		mark.Visible = true
		mark.Parent = ruler
	end

	-- One fish drifting inside each zone.
	for index, tier in Tiers.List do
		local fish = content:FindFirstChild("Fish" .. index)
		if fish ~= nil and fish:IsA("GuiObject") then
			local top = tier.depthMin
			local bottom = if index < #Tiers.List then Tiers.List[index + 1].depthMin else BOTTOM - 20
			local metres = top + (bottom - top) * random:NextNumber(0.3, 0.85)
			local startX = random:NextNumber(0.08, 0.8)
			local endX = if startX > 0.45 then random:NextNumber(0.05, 0.3) else random:NextNumber(0.6, 0.85)
			fish.Position = UDim2.fromScale(startX, worldY(metres))
			play(
				fish,
				TweenInfo.new(random:NextNumber(5, 9), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = UDim2.fromScale(endX, worldY(metres + random:NextNumber(-6, 6))) }
			)
		end
	end

	-- Bubbles live in window space and stream past faster while the view dives.
	local bubbles: { { frame: Frame, x: number, y: number, speed: number, phase: number } } = {}
	for index = 1, BUBBLE_COUNT do
		local bubble = bubbleTemplate:Clone()
		bubble.Name = "BubbleLive"
		local size = random:NextNumber(0.018, 0.04)
		bubble.Size = UDim2.fromScale(size, size)
		bubble.Visible = true
		bubble.Parent = window
		bubbles[index] = {
			frame = bubble,
			x = random:NextNumber(0.05, 0.95),
			y = random:NextNumber(0, 1.1),
			speed = random:NextNumber(0.06, 0.14),
			phase = random:NextNumber(0, math.pi * 2),
		}
	end

	-- The pack ---------------------------------------------------------------------------------------------
	-- With other answers on the card every tag, yours too, is a PeerTag in a lane. Alone, yours is the big
	-- AnswerTag in the middle.
	local packed = options.peers ~= nil and #options.peers > 0 and peerTemplate ~= nil and peerTemplate:IsA("Frame")
	local divers: { Diver } = {}
	local loading: { { picture: ImageLabel, letter: TextLabel } } = {} -- pictures still on their way

	local function addDiver(tag: Frame, own: boolean, userId: number?, name: string, shown: string, answer: string?, tier: string?, metres: number)
		local info = if tier ~= nil then Tiers.ByName[tier] else nil
		local answerLabel = tag:FindFirstChild("Text")
		if answerLabel ~= nil and answerLabel:IsA("TextLabel") then
			answerLabel.Text = if info ~= nil then string.upper(answer or "ACCEPTED") else "NO ANSWER"
		end
		local nameLabel = tag:FindFirstChild("Name")
		if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
			nameLabel.Text = string.upper(shown)
		end
		if info == nil then
			tag.BackgroundColor3 = NO_ANSWER_GREY
		end
		local picture, letter = fillAvatar(tag, userId, name)
		if picture ~= nil and letter ~= nil then
			table.insert(loading, { picture = picture, letter = letter })
		end
		local stroke = tag:FindFirstChild("Border")
		local crownIcon = tag:FindFirstChild("Crown")
		table.insert(divers, {
			frame = tag,
			scale = tag:FindFirstChildOfClass("UIScale"),
			stroke = if stroke ~= nil and stroke:IsA("UIStroke") then stroke else nil,
			crown = if crownIcon ~= nil and crownIcon:IsA("GuiObject") then crownIcon else nil,
			nameLabel = if nameLabel ~= nil and nameLabel:IsA("TextLabel") then nameLabel else nil,
			name = shown,
			own = own,
			hasAnswer = info ~= nil,
			depth = if info ~= nil then math.clamp(metres, info.depthMin, BOTTOM) else 0,
			color = Ui.tierColor(tier),
			tierIndex = Tiers.index(tier),
			rest = 1,
			x = 0.5,
			slot = { lane = 1, row = 0, final = 0 },
			pos = -START_SKY,
			landed = false,
			landedAt = 0,
			washAt = nil,
			fade = nil,
			gone = false,
		})
	end

	local ownUserId = options.userId
	if ownUserId == nil and options.isYou then
		ownUserId = Players.LocalPlayer.UserId
	end
	local ownTag = soloTag
	if packed then
		soloTag.Visible = false
		ownTag = (peerTemplate :: Frame):Clone()
		ownTag.Name = "OwnTagLive"
		-- Above the rope and the other tags.
		ownTag.ZIndex += 2
		for _, descendant in ownTag:GetDescendants() do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex += 2
			end
		end
		local ownStroke = ownTag:FindFirstChild("Border")
		if ownStroke ~= nil and ownStroke:IsA("UIStroke") then
			ownStroke.Color = headerColor:Lerp(BLACK, 0.25)
			ownStroke.Thickness *= 1.5
		end
		local ownLabel = ownTag:FindFirstChild("Name")
		if ownLabel ~= nil and ownLabel:IsA("TextLabel") then
			ownLabel.TextColor3 = headerColor:Lerp(BLACK, 0.3)
		end
		ownTag.Visible = true
		ownTag.Parent = window
	end
	if themed ~= nil then
		ownTag.BackgroundColor3 = fromRgb(themed.tag)
	end
	local ownName = Players.LocalPlayer.DisplayName
	addDiver(ownTag, true, ownUserId, ownName, if packed then "YOU" else ownName, options.answer, tierName, options.depth or 0)
	if packed then
		for _, peer in options.peers :: { Peer } do
			-- Only answers dive. A player with none is in the answers list that follows the card.
			if peer.tier ~= nil and Tiers.ByName[peer.tier] ~= nil then
				local clone = (peerTemplate :: Frame):Clone()
				clone.Name = "PeerTagLive"
				clone.Visible = true
				clone.Parent = window
				addDiver(clone, false, peer.userId, peer.name, peer.name, peer.answer, peer.tier, peer.depth)
			end
		end
	end
	local own = divers[1]
	local depth = own.depth
	for _, diver in divers do
		diver.frame.Position = UDim2.fromScale(0.5, -0.3)
	end

	counter.Text = "0 m"
	footer.Text = ""
	schooledChip.Visible = false
	stamp.Visible = false
	local stampColor = if hasAnswer then tierColor else Theme.Color.Grey
	stampFace.BackgroundColor3 = stampColor
	stampLip.BackgroundColor3 = stampColor:Lerp(BLACK, LIP_SHADE)
	shellsChip.Visible = false
	shellsLip.BackgroundColor3 = shellsFace.BackgroundColor3:Lerp(BLACK, LIP_SHADE)
	if shells > 0 then
		shellsText.Text = "+" .. Currency.format(shells)
	else
		-- No chip: the footer line drops into the space it would have used.
		footer.Position = footer.Position:Lerp(shellsChip.Position, 0.5)
	end
	stampLabel.Text = if tierInfo ~= nil
		then string.upper(tierInfo.label) .. (if isMythic then "!" else "")
		else "NO ANSWER"

	-- Authored strokes and corners are tuned for a 380 px card; scale them with the card so a small card
	-- stays crisp and a full-screen one keeps its chunky outlines.
	for _, descendant in frame:GetDescendants() do
		if descendant:IsA("UIStroke") then
			table.insert(strokes, { stroke = descendant, base = descendant.Thickness })
		elseif descendant:IsA("UICorner") and descendant.CornerRadius.Scale == 0 then
			table.insert(corners, { corner = descendant, base = descendant.CornerRadius.Offset })
		end
	end
	local function restyle()
		local height = frame.AbsoluteSize.Y
		if height < 2 then
			return
		end
		local factor = math.clamp(height / BASE_HEIGHT, 0.45, MAX_STYLE_SCALE)
		for _, entry in strokes do
			entry.stroke.Thickness = math.max(1, entry.base * factor)
		end
		for _, entry in corners do
			entry.corner.CornerRadius = UDim.new(0, math.floor(entry.base * factor + 0.5))
		end
	end
	table.insert(connections, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(restyle))

	-- Full-screen: as wide as the parent allows, from a tall phone card to a wide desktop one.
	local aspect = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	if options.fill == true and aspect ~= nil then
		local constraint: UIAspectRatioConstraint = aspect
		local function fit()
			local size = parent.AbsoluteSize
			if size.Y >= 2 then
				constraint.AspectRatio = math.clamp(size.X / size.Y, FILL_ASPECT.Min, FILL_ASPECT.Max)
			end
		end
		table.insert(connections, parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		fit()
	end

	-- The card slides up and grows into place.
	local enter = TweenInfo.new(ENTER_TIME * speed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	for _, part in { body, shadow } do
		if part ~= nil and part:IsA("GuiObject") then
			local rest = part.Position
			part.Position = rest + UDim2.fromScale(0, ENTER_RISE)
			play(part, enter, { Position = rest })
		end
	end
	frame.Parent = parent
	restyle()
	cardScale.Scale = ENTER_SCALE
	play(cardScale, enter, { Scale = 1 })

	-- Handle -----------------------------------------------------------------------------------------------
	local landedFired = false
	local waiting: { thread } = {}
	local function fire()
		if landedFired then
			return
		end
		landedFired = true
		for _, thread in waiting do
			task.spawn(thread)
		end
		table.clear(waiting)
	end

	local handle: Handle = {
		frame = frame,
		finished = function()
			if not landedFired then
				table.insert(waiting, coroutine.running())
				coroutine.yield()
			end
		end,
		destroy = function() end,
	}

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, tween in tweens do
			tween:Cancel()
		end
		fire()
		frame:Destroy()
	end
	handle.destroy = destroy
	table.insert(connections, frame.Destroying:Connect(destroy))

	-- Your landing ---------------------------------------------------------------------------------------
	local stampY = STAMP_Y -- where the stamp lands; placeStamp moves it above a low tag

	local function burst(count: number)
		local piece = findTemplate("Confetti")
		if piece == nil or not piece:IsA("Frame") then
			return
		end
		for _ = 1, count do
			local bit = (piece :: Frame):Clone()
			bit.Name = "ConfettiLive"
			bit.Position = UDim2.fromScale(0.5, stampY)
			bit.Size = UDim2.fromScale(random:NextNumber(0.025, 0.045), random:NextNumber(0.015, 0.03))
			bit.Rotation = random:NextNumber(0, 360)
			bit.BackgroundColor3 = Theme.Confetti[random:NextInteger(1, #Theme.Confetti)]
			bit.Parent = confettiLayer
			local angle = random:NextNumber(0, math.pi * 2)
			local reach = random:NextNumber(0.25, 0.6)
			local goal = UDim2.fromScale(0.5 + math.cos(angle) * reach, stampY + math.sin(angle) * reach * 0.8 + 0.15)
			local seconds = random:NextNumber(0.7, 1.2) * (if quick then 0.7 else 1)
			play(bit, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = goal,
				Rotation = bit.Rotation + random:NextNumber(-360, 360),
				BackgroundTransparency = 1,
			})
		end
	end

	local function footerText(): string
		if tierInfo == nil then
			return "No answer locked in this round."
		end
		local oneIn = options.oneIn
		if oneIn ~= nil then
			return "About 1 in " .. Currency.digits(oneIn) .. " players"
		end
		-- Labelled with "~" so a guess from the depth curve never reads as a real count.
		if GameConfig.Reveal.EstimatedOneIn == 1 then
			return "About 1 in ~" .. Currency.digits(Depth.oneInEstimate(depth)) .. " players"
		end
		return tierInfo.blurb
	end

	-- A very deep dive can leave your tag low in the water window, right where the stamp lands; the stamp
	-- then lands just above the tag instead, so your answer is never covered.
	local function placeStamp()
		local cardTop = body.AbsolutePosition.Y
		local cardHeight = body.AbsoluteSize.Y
		if cardHeight < 2 then
			return
		end
		local half = stamp.AbsoluteSize.Y / math.max(stampScale.Scale, 0.01) / 2 / cardHeight
		local tagTop = (ownTag.AbsolutePosition.Y - cardTop) / cardHeight
		local tagBottom = (ownTag.AbsolutePosition.Y + ownTag.AbsoluteSize.Y - cardTop) / cardHeight
		if tagBottom + STAMP_GAP > STAMP_Y - half then
			stampY = math.max(tagTop - STAMP_GAP - half, half)
			stamp.Position = UDim2.new(stamp.Position.X.Scale, stamp.Position.X.Offset, stampY, 0)
		end
	end

	-- A tag pops as it comes to rest and takes its tier's colour on its outline.
	local function touchDown(diver: Diver, pop: number)
		local stroke = diver.stroke
		if stroke ~= nil and diver.hasAnswer then
			stroke.Color = diver.color:Lerp(BLACK, 0.35)
		end
		local tagScale = diver.scale
		if tagScale ~= nil then
			tagScale.Scale = diver.rest * pop
			play(tagScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = diver.rest })
		end
		local nameLabel = diver.nameLabel
		if nameLabel ~= nil and diver.hasAnswer then
			nameLabel.Text = string.upper(diver.name) .. "  |  " .. Currency.digits(math.floor(diver.depth + 0.5)) .. " M"
		end
	end

	local function land()
		if destroyed then
			return
		end
		placeStamp()
		touchDown(own, 1.12)
		stamp.Visible = true
		stampScale.Scale = 2.2
		play(stampScale, TweenInfo.new(0.28 * speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		footer.Text = footerText()
		local counterScale = counter:FindFirstChildOfClass("UIScale")
		if counterScale ~= nil then
			counterScale.Scale = 1.25
			play(counterScale, TweenInfo.new(0.3 * speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end
		if not hasAnswer then
			counter.TextColor3 = Theme.Color.Grey
			sound("Uhh", 0.8, 1)
			return
		end
		counter.TextColor3 = lighten(tierColor, 0.3)
		footer.TextColor3 = WHITE
		sound("Thud", 0.7 + 0.3 * intensity, 1.1 - 0.25 * intensity)
		sound("Ping", 1, 0.8 + 0.12 * tierIndex)
		if not isMythic then
			-- The slam: every answer thuds, rarer ones hit harder and flash their colour.
			Fx.shakeOffset(frame, (3 + 9 * intensity) * (if quick then 0.5 else 1), 0.35 + 0.2 * intensity)
		end
		if options.isYou and not quick and tierIndex >= Tiers.index("Rare") then
			Fx.flash(tierColor)
		end
		if shells > 0 then
			task.delay(SHELLS_DELAY * speed, function()
				if destroyed then
					return
				end
				shellsChip.Visible = true
				shellsScale.Scale = 0.2
				play(shellsScale, TweenInfo.new(0.3 * speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				sound("Pop", 0.5, 1.2)
			end)
		end
		local schooled = options.schooled
		if schooled ~= nil and schooled >= 2 then
			local factor = GameConfig.Schooling.Factor
			local lift = if factor == 0.5 then "HALF LIFT" else math.floor(factor * 100 + 0.5) .. "% LIFT"
			local chipText = schooledChip:FindFirstChild("Text")
			if chipText ~= nil and chipText:IsA("TextLabel") then
				chipText.Text = "SCHOOLED x" .. schooled .. "  |  " .. lift
			end
			schooledChip.Visible = true
		end
		if tierIndex >= Tiers.index("Rare") then
			play(cardStroke, TweenInfo.new(0.3), { Color = tierColor })
		end
		if tierName == "Rare" then
			burst(if quick then 3 else 6)
		end
		if tierName == "DeepCut" then
			burst(if quick then 6 else 12)
		end
		-- A good answer's stamp keeps a slow pulse while the card holds, so the result has a moment.
		if not isMythic and tierIndex >= Tiers.index("Rare") then
			task.delay(0.3 * speed, function()
				if not destroyed then
					play(
						stampScale,
						TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Scale = 1.05 }
					)
				end
			end)
		end
		if isMythic then
			sound("Fanfare", 0.8, 1)
			Fx.shakeOffset(frame, if quick then 5 else 12, 0.5)
			burst(if quick then 14 else 30)
			play(
				cardStroke,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true),
				{ Thickness = cardStroke.Thickness * 2.2 }
			)
			-- The stamp keeps breathing after it lands; Back easing has to finish first.
			task.delay(0.3 * speed, function()
				if not destroyed then
					play(
						stampScale,
						TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Scale = 1.08 }
					)
				end
			end)
		end
	end

	-- Your tag crossing into a deeper zone: the zone's own label and line flash, and the counter takes its
	-- colour. Nothing is drawn over the tags.
	local function flashZone(index: number)
		local tier = Tiers.List[index]
		sound("Tick", 0.5, 0.9 + 0.18 * index)
		counter.TextColor3 = lighten(Ui.tierColor(tier.name), 0.3)
		local zone = zones[index]
		if zone == nil then
			return
		end
		local label = zone.label
		if label ~= nil then
			label.TextColor3 = WHITE
			play(label, ZONE_FLASH, { TextColor3 = zone.labelColor })
		end
		local line = zone.line
		if line ~= nil then
			local resting = line.BackgroundTransparency
			line.BackgroundColor3 = WHITE
			line.BackgroundTransparency = 0
			play(line, ZONE_FLASH, { BackgroundColor3 = zone.lineColor, BackgroundTransparency = resting })
		end
	end

	-- The pack's lanes and timing ------------------------------------------------------------------------
	local created = os.clock()
	local diveDelay = DIVE_DELAY * speed
	local dropTime = DROP_TIME * speed
	local sinkTime = 1
	local settleTime = SETTLE_TIME * speed
	local focusDelay = FOCUS_DELAY * speed
	local focusTime = FOCUS_TIME * speed
	local glideDelay = focusDelay -- your landing to the view leaving your tag; longer when tags drift away first
	local ready = false
	local started = 0
	local spacing = VIEW
	local soft = SOFT_MIN
	local reach = SOFT_MIN
	local leader: Diver? = nil -- the round's deepest answer, when other answers share the card
	local leaderDeep = false -- it is Rare or better: the tags that stopped short drift away

	-- Window width the zone labels (left) and the ruler's numbers (right) take, so no tag sits on them.
	local function gutters(size: Vector2): (number, number)
		local origin = window.AbsolutePosition.X
		local left = 0
		for _, zone in zones do
			local label = zone.label
			if label ~= nil then
				left = math.max(left, label.AbsolutePosition.X - origin + label.TextBounds.X)
			end
		end
		local right = 0
		for _, mark in ruler:GetChildren() do
			if mark:IsA("TextLabel") and mark.Visible then
				right = math.max(right, origin + size.X - (mark.AbsolutePosition.X + mark.AbsoluteSize.X) + mark.TextBounds.X)
			end
		end
		local leftShare = if left > 1 then left / size.X + GUTTER_PAD else GUTTER_LEFT
		local rightShare = if right > 1 then right / size.X + GUTTER_PAD else GUTTER_RIGHT
		return math.min(leftShare, 0.3), math.min(rightShare, 0.15)
	end

	-- Gives every tag its lane, row and resting place, sizes the tags to their lanes and sets the pack's
	-- timing. Waits for the window to have a size to measure by, unless `force`.
	local function prepare(force: boolean)
		local size = window.AbsoluteSize
		local sized = size.X >= 2 and size.Y >= 2
		if not sized and not force then
			return
		end
		local lanes = 1
		local left = 0
		local area = 1
		if packed then
			local right = GUTTER_RIGHT
			left = GUTTER_LEFT
			local tagWidth = 0.19 -- of the window: the authored PeerTag, until measured
			local tagHeight = 0.14
			if sized then
				left, right = gutters(size)
				local tagSize = own.frame.AbsoluteSize
				if tagSize.X >= 2 and tagSize.Y >= 2 then
					tagWidth = tagSize.X / size.X
					tagHeight = tagSize.Y / size.Y
				end
			end
			area = math.max(1 - left - right, 0.3)
			-- As many lanes as tags, up to MAX_LANES, while the tags stay a readable size.
			local laneScale = 1
			local smallest = if #divers > CROWD then CROWD_LANE_SCALE else MIN_LANE_SCALE
			for count = math.min(#divers, MAX_LANES), 1, -1 do
				local fit = (area / count - LANE_GAP) / (tagWidth * OWN_SCALE)
				if fit >= smallest or count == 1 then
					lanes = count
					laneScale = math.clamp(fit, 0.5, 1)
					break
				end
			end
			for _, diver in divers do
				diver.rest = laneScale * (if diver.own then OWN_SCALE else 1)
				local tagScale = diver.scale
				if tagScale ~= nil then
					tagScale.Scale = diver.rest
				end
			end
			spacing = tagHeight * laneScale * OWN_SCALE * (1 + ROW_GAP) * VIEW
		end

		local depths: { number } = {}
		for index, diver in divers do
			depths[index] = diver.depth
		end
		local slots = DivePack.layout(depths, lanes, spacing, 1)
		local deepestRest = 0
		local deepest = 0
		for index, diver in divers do
			diver.slot = slots[index]
			diver.x = if packed then left + (slots[index].lane - 0.5) * area / lanes else 0.5
			deepestRest = math.max(deepestRest, slots[index].final)
			deepest = math.max(deepest, diver.depth)
		end
		soft = math.clamp(SOFT_SHARE * deepestRest, SOFT_MIN, SOFT_MAX)
		reach = DivePack.reach(slots, soft)
		-- Timed by the deepest answer itself, not by where a crowded lane rests it.
		sinkTime = Depth.diveSeconds(deepest, quick)

		if packed then
			for _, diver in divers do
				if diver.hasAnswer and (leader == nil or diver.depth > leader.depth) then
					leader = diver
				end
			end
			leaderDeep = leader ~= nil and leader.tierIndex >= Tiers.index("Rare")
			if leaderDeep then
				glideDelay += WASH_LEAD * speed
			end
		end

		-- `budget` squeezes the whole dive when its last tag would land too late, or when the view would
		-- reach another player's deepest answer too late (it leaves your tag glideDelay after you land).
		local budget = options.budget
		if budget ~= nil and budget > diveDelay then
			local limit = budget - diveDelay
			local last = 0
			for _, diver in divers do
				last = math.max(last, DivePack.landSeconds(diver.slot, spacing, soft, dropTime, sinkTime, reach))
			end
			local pace = math.min(1, limit / last)
			if leader ~= nil and leader ~= own then
				local glide = glideDelay + GLIDE_SHARE * focusTime
				local ownLands = DivePack.landSeconds(own.slot, spacing, soft, dropTime, sinkTime, reach)
				if limit > glide then
					pace = math.min(pace, (limit - glide) / ownLands)
				end
			end
			if pace < 1 then
				dropTime *= pace
				sinkTime *= pace
				settleTime *= pace
			end
		end
		started = os.clock()
		ready = true
	end

	-- The round's deepest answer gets its crown.
	local function crown(diver: Diver)
		local icon = diver.crown
		if icon ~= nil then
			icon.Visible = true
		end
		local tagScale = diver.scale
		if tagScale ~= nil then
			tagScale.Scale = diver.rest * 1.15
			play(tagScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = diver.rest })
		end
		sound("Ping", 0.7, 1.5)
	end

	-- Once the tags around the crowned one have drifted away and no other is on screen with it, it takes the
	-- middle of the window and grows: the card ends on that one answer.
	local spotFrom = 0.5 -- the crowned tag's lane, while it slides to the middle
	local spotAt: number? = nil
	local function spotlight(diver: Diver, now: number)
		for _, other in divers do
			if other ~= diver and not other.gone and math.abs(other.pos - diver.pos) < SPOT_CLEAR * VIEW then
				-- Still on screen with it: only one that has all but faded is out of the way.
				local washAt = other.washAt
				if washAt == nil or now - washAt < WASH_TIME * 0.6 then
					return
				end
			end
		end
		spotFrom = diver.x
		spotAt = now
		diver.rest *= SPOT_SCALE
		local tagScale = diver.scale
		if tagScale ~= nil then
			play(tagScale, TweenInfo.new(SPOT_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = diver.rest })
		end
	end

	-- A few bubbles leave a tag as it starts to drift away.
	local function puff(diver: Diver, y: number)
		for _ = 1, 4 do
			local bubble = bubbleTemplate:Clone()
			bubble.Name = "PuffLive"
			local size = random:NextNumber(0.02, 0.035)
			bubble.Size = UDim2.fromScale(size, size)
			local x = diver.x + random:NextNumber(-0.07, 0.07)
			bubble.Position = UDim2.fromScale(x, y)
			bubble.Visible = true
			bubble.Parent = window
			local tween = play(bubble, TweenInfo.new(random:NextNumber(0.5, 0.8), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(x + random:NextNumber(-0.02, 0.02), y - random:NextNumber(0.18, 0.3)),
				BackgroundTransparency = 1,
			})
			tween.Completed:Once(function()
				bubble:Destroy()
			end)
		end
	end

	-- Per-frame dive -------------------------------------------------------------------------------------
	local viewTop = -SKY -- metres at the top of the window
	local ownLandedAt: number? = nil
	local crownedAt: number? = nil
	local shownMetres = -1
	local splashed = false
	local nextZone = 2
	local tickedAt = 0 -- depth of the last counter click
	local tickedTime = 0
	local peerSoundAt = 0
	local lastWashAt = 0

	local function peerSound(name: string, gain: number, pitch: number, now: number)
		if now - peerSoundAt >= PEER_SOUND_GAP then
			peerSoundAt = now
			sound(name, gain, pitch)
		end
	end

	local function step(dt: number)
		local now = os.clock()
		if not ready and now - created >= diveDelay then
			prepare(now - created >= diveDelay + LAYOUT_WAIT)
		end
		for index = #loading, 1, -1 do
			if loading[index].picture.IsLoaded then
				loading[index].letter.Visible = false
				table.remove(loading, index)
			end
		end
		local previousTop = viewTop

		if ready then
			local elapsed = now - started
			local front = DivePack.front(elapsed, dropTime, sinkTime, reach, START_SKY)
			for _, diver in divers do
				local at = DivePack.position(front, diver.slot, spacing, soft)
				if not diver.landed and DivePack.landed(front, diver.slot, spacing, soft) then
					diver.landed = true
					diver.landedAt = now
					if diver.own then
						ownLandedAt = now
						task.spawn(land)
					else
						-- The deepest answer lands out of sight or under your stamp: its crown is its pop.
						touchDown(diver, if diver == leader then 1 else 1.08)
						if diver.hasAnswer then
							peerSound("Tick", 0.25, 0.8 + 0.12 * diver.tierIndex, now)
						end
					end
				end
				diver.pos = at
			end

			-- Your tag meets the water.
			if not splashed and own.pos >= -2 then
				splashed = true
				sound("Splash", 0.6, 1.1)
				local tagScale = own.scale
				if tagScale ~= nil then
					tagScale.Scale = own.rest * 0.8
					play(tagScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = own.rest })
				end
			end

			-- The fall is heard as well as seen: the counter clicks faster and higher the deeper it goes.
			if hasAnswer and not quick and not own.landed and own.pos - tickedAt >= TICK_METRES and now - tickedTime >= TICK_GAP then
				tickedAt = own.pos
				tickedTime = now
				sound("Tick", 0.22, 0.75 + 0.9 * math.clamp(own.pos / BOTTOM, 0, 1))
			end

			while
				hasAnswer
				and nextZone <= #Tiers.List
				and Tiers.List[nextZone].depthMin <= depth
				and own.pos >= Tiers.List[nextZone].depthMin
			do
				flashZone(nextZone)
				nextZone += 1
			end
		end

		-- The view follows your tag; once your stamp has had its moment it glides to the round's deepest.
		local focus = own.pos
		local shift = 0
		local lead = leader
		local landedAt = ownLandedAt
		if lead ~= nil and lead ~= own and landedAt ~= nil then
			local u = math.clamp((now - landedAt - glideDelay) / focusTime, 0, 1)
			shift = u * u * (3 - 2 * u)
			focus += (lead.pos - own.pos) * shift
		end
		local target = math.clamp(focus - TAG_Y * VIEW, -SKY, BOTTOM - TAG_Y * VIEW)
		viewTop += (target - viewTop) * (1 - math.exp(-CAMERA_RATE * dt))

		if lead ~= nil and crownedAt == nil and lead.landed and (lead == own or shift >= 0.85) then
			crownedAt = now
			crown(lead)
			-- The same answer from two players is the same depth: they share the crown.
			for _, diver in divers do
				if diver ~= lead and diver.hasAnswer and diver.depth >= lead.depth - TIE_METRES then
					local icon = diver.crown
					if icon ~= nil then
						icon.Visible = true
					end
				end
			end
		end
		if lead ~= nil and leaderDeep and crownedAt ~= nil and spotAt == nil and now >= crownedAt + 0.15 then
			spotlight(lead, now)
		end
		if not landedFired and landedAt ~= nil then
			local done = landedAt + settleTime
			if lead ~= nil then
				done = if crownedAt ~= nil then math.max(done, crownedAt + CROWN_TIME) else math.huge
			end
			if now >= done or now - started >= dropTime + sinkTime + OVERRUN then
				fire()
			end
		end

		content.Position = UDim2.fromScale(0, -(viewTop + SKY) / VIEW)
		for _, diver in divers do
			if not diver.gone then
				local at = diver.pos
				if diver.landed then
					-- The bob is only drawn: the view follows `pos`, so the water stays still under a resting tag.
					local since = now - diver.landedAt
					local swing = if diver.hasAnswer
						then math.sin(since * BOB_RATE) * BOB_METRES
						else math.sin(since * IDLE_BOB_RATE) * IDLE_BOB_METRES
					at += swing * math.min(since / BOB_EASE, 1)
				end
				local y = (at - viewTop) / VIEW
				-- With a deep answer on the card, the tags that stopped short of it drift away once your stamp
				-- has had its moment, just before the view leaves for the deepest; one that stops later goes a
				-- beat after it lands. A tag nobody can see just goes.
				if leaderDeep and lead ~= nil and not diver.own and diver.landed and diver.depth < lead.depth - TIE_METRES then
					local washAt = diver.washAt
					if
						washAt == nil
						and landedAt ~= nil
						and now >= math.max(diver.landedAt + WASH_BEAT, landedAt + focusDelay, lastWashAt + WASH_STAGGER)
					then
						if y < IN_VIEW.Min or y > IN_VIEW.Max then
							diver.gone = true
							diver.frame.Visible = false
						else
							washAt = now
							lastWashAt = now
							diver.washAt = now
							diver.fade = fadeParts(diver.frame)
							puff(diver, y)
							peerSound("Pop", 0.2, 1.5, now)
						end
					end
					local parts = diver.fade
					if washAt ~= nil and parts ~= nil then
						local u = math.min((now - washAt) / WASH_TIME, 1)
						local eased = u * u
						y -= WASH_RISE * eased / VIEW
						setFade(parts, eased)
						local tagScale = diver.scale
						if tagScale ~= nil then
							tagScale.Scale = diver.rest * (1 - WASH_SHRINK * eased)
						end
						if u >= 1 then
							diver.gone = true
							diver.frame.Visible = false
						end
					end
				end
				local x = diver.x
				local slideAt = spotAt
				if diver == lead and slideAt ~= nil then
					local u = math.min((now - slideAt) / SPOT_TIME, 1)
					x = spotFrom + (0.5 - spotFrom) * u * u * (3 - 2 * u)
				end
				diver.frame.Position = UDim2.fromScale(x, y)
			end
		end

		local tagY = own.frame.Position.Y.Scale
		local ropeTop = math.max((0 - viewTop) / VIEW, 0)
		if tagY > ropeTop + 0.01 then
			rope.Visible = true
			rope.Position = UDim2.fromScale(own.frame.Position.X.Scale, ropeTop)
			rope.Size = UDim2.new(0, 2, tagY - ropeTop, 0)
		else
			rope.Visible = false
		end

		-- The counter is your depth: it never reads past it, and holds it once your tag has landed (the tag
		-- keeps bobbing, and may rest lower in a crowded lane).
		local metres = 0
		if hasAnswer then
			metres = if own.landed then math.floor(depth + 0.5) else math.floor(math.clamp(own.pos, 0, depth) + 0.5)
		end
		if metres ~= shownMetres then
			shownMetres = metres
			counter.Text = Currency.digits(metres) .. " m"
		end

		local rise = if dt > 0 then math.max(0, (viewTop - previousTop) / dt) / VIEW else 0
		for _, bubble in bubbles do
			bubble.y -= (bubble.speed + rise) * dt
			if bubble.y < -0.05 then
				bubble.y = 1.05
				bubble.x = random:NextNumber(0.05, 0.95)
			end
			bubble.frame.Position = UDim2.fromScale(bubble.x + math.sin(now * 2 + bubble.phase) * 0.015, bubble.y)
		end
	end

	local render: RBXScriptConnection
	render = RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			-- Stop animating but keep the card (and let waiters continue) instead of erroring every frame.
			warn("[DiveCard] " .. tostring(err))
			render:Disconnect()
			fire()
		end
	end)
	table.insert(connections, render)

	return handle
end

return DiveCard
