--!strict
-- The "YOUR DIVE" card: an answer tag sinks through tier depth zones to its depth, then a tier stamp lands.
-- Clones ReplicatedStorage.Templates.DiveCard (authored in git as a model.json) and only drives it; used by
-- Reveal (full-screen, match) and LobbyQuiz (warm-up card). Ported from Sink or Niche's code-built DiveCard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Depth = require(ReplicatedStorage.Shared.Depth)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

export type Options = {
	title: string, -- "YOUR DIVE"
	isYou: boolean, -- blue header for you, pink for someone else
	answer: string?, -- bank spelling; nil with no tier shows NO ANSWER bobbing at the surface
	tier: string?,
	depth: number, -- metres (Depth.metres)
	oneIn: number?, -- real "1 in N players", when known
	schooled: number?, -- players who gave the same answer, when 2 or more
	shells: number?, -- Shells the answer pays; a chip pops under the stamp when this is above 0
	quick: boolean?, -- half-length dive
	scale: number?, -- card height as a fraction of the parent's height (default 1)
	fill: boolean?, -- full-screen: the card takes its parent's shape (within FILL_ASPECT), not the portrait one
	budget: number?, -- the stamp lands within this many seconds of play(); deep dives play a little faster
}

export type Handle = {
	frame: Frame?, -- the clone, parented to `parent`; nil when the template is missing
	finished: () -> (), -- yields until the stamp has landed
	destroy: () -> (),
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SKY_LOW = Color3.fromRGB(214, 240, 255) -- just above the surface line
local SKY = GameConfig.Depth.SkyMetres
local BOTTOM = GameConfig.Depth.MaxMetres
local VIEW = GameConfig.Depth.ViewMetres
local RANGE = SKY + BOTTOM
local TAG_Y = 0.46 -- window height fraction the tag holds once the view starts following it
local DROP_TIME = 0.32
local SETTLE_TIME = 0.32 -- stamp landing to `finished`
local BUBBLE_COUNT = 9
local BASE_HEIGHT = 380 -- card height the authored stroke thicknesses and corner radii are tuned for
local MAX_STYLE_SCALE = 2.2 -- a full-screen card's outlines stop thickening here
local FILL_ASPECT = NumberRange.new(0.6, 2.1) -- width / height of a full-screen card, tall phone to landscape phone
local STAMP_Y = 0.665 -- the stamp's centre as a fraction of card height; confetti bursts from here
local STAMP_GAP = 0.02 -- card-height fraction kept clear between a low answer tag and the stamp
local LIP_SHADE = 0.45 -- how much darker a lip is than the face above it
local SHELLS_DELAY = 0.15 -- the Shells chip pops in just after the stamp

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
	local depth = 0
	if tierInfo ~= nil then
		depth = math.clamp(options.depth or 0, tierInfo.depthMin, BOTTOM)
	end
	local tierIndex = Tiers.index(tierName)
	local isKrillion = tierName == "OneInAKrillion"
	local tierColor = Ui.tierColor(tierName)
	-- 0 for the commonest tier up to 1 for One in a Krillion: drives how hard the dive winds up and hits.
	local intensity = if hasAnswer then math.clamp((tierIndex - 1) / math.max(#Tiers.List - 1, 1), 0, 1) else 0
	local shape = Depth.diveShape(intensity)
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
	local tag = window:FindFirstChild("AnswerTag") :: Frame
	local tagStroke = tag:FindFirstChild("Border") :: UIStroke
	local tagText = tag:FindFirstChild("Text") :: TextLabel
	local zoneFlash = window:FindFirstChild("ZoneFlash") :: TextLabel
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

	-- Zone lines follow Tiers, so a retuned band moves its line too.
	for index, tier in Tiers.List do
		local zoneLine = content:FindFirstChild("ZoneLine" .. index)
		if zoneLine ~= nil and zoneLine:IsA("Frame") then
			zoneLine.Position = UDim2.fromScale(0, worldY(tier.depthMin))
			local line = zoneLine:FindFirstChild("Line")
			if line ~= nil and line:IsA("Frame") then
				line.BackgroundColor3 = lighten(Ui.tierColor(tier.name), 0.25)
			end
			local zoneLabel = zoneLine:FindFirstChild("Label")
			if zoneLabel ~= nil and zoneLabel:IsA("TextLabel") then
				zoneLabel.Text = string.format("%s  %d m", string.upper(tier.label), tier.depthMin)
				zoneLabel.TextColor3 = lighten(Ui.tierColor(tier.name), 0.35)
			end
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

	-- Bubbles live in window space and stream past faster while the tag dives.
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

	if hasAnswer then
		tagText.Text = string.upper(options.answer or "ACCEPTED")
		if themed ~= nil then
			tag.BackgroundColor3 = fromRgb(themed.tag)
		end
	else
		tag.BackgroundColor3 = Color3.fromRGB(200, 208, 222)
		tagText.Text = "NO ANSWER"
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
		shellsText.Text = "+" .. Currency.digits(shells) .. " " .. Theme.Icon.Shell .. " " .. Currency.Upper
	else
		-- No chip: the footer line drops into the space it would have used.
		footer.Position = footer.Position:Lerp(shellsChip.Position, 0.5)
	end
	stampLabel.Text = if tierInfo ~= nil
		then string.upper(tierInfo.label) .. (if isKrillion then "!" else "")
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

	frame.Parent = parent
	restyle()
	cardScale.Scale = 0.75
	play(cardScale, TweenInfo.new(0.3 * speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })

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

	-- Landing --------------------------------------------------------------------------------------------
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

	-- A very deep dive leaves the tag low in the water window, right where the stamp lands; the stamp then
	-- lands just above the tag instead, so your answer is never covered.
	local function placeStamp()
		local cardTop = body.AbsolutePosition.Y
		local cardHeight = body.AbsoluteSize.Y
		if cardHeight < 2 then
			return
		end
		local half = stamp.AbsoluteSize.Y / math.max(stampScale.Scale, 0.01) / 2 / cardHeight
		local tagTop = (tag.AbsolutePosition.Y - cardTop) / cardHeight
		local tagBottom = (tag.AbsolutePosition.Y + tag.AbsoluteSize.Y - cardTop) / cardHeight
		if tagBottom + STAMP_GAP > STAMP_Y - half then
			stampY = math.max(tagTop - STAMP_GAP - half, half)
			stamp.Position = UDim2.new(stamp.Position.X.Scale, stamp.Position.X.Offset, stampY, 0)
		end
	end

	local function land()
		if destroyed then
			return
		end
		placeStamp()
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
		tagStroke.Color = tierColor:Lerp(BLACK, 0.35)
		sound("Thud", 0.7 + 0.3 * intensity, 1.1 - 0.25 * intensity)
		sound("Ping", 1, 0.8 + 0.12 * tierIndex)
		if not isKrillion then
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
		if tierName == "DeepCut" then
			burst(if quick then 6 else 12)
		end
		if isKrillion then
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

	local function flashZone(index: number)
		local tier = Tiers.List[index]
		local color = lighten(Ui.tierColor(tier.name), 0.3)
		sound("Tick", 0.5, 0.9 + 0.18 * index)
		zoneFlash.Text = string.upper(tier.label)
		zoneFlash.TextColor3 = color
		zoneFlash.TextTransparency = 0
		local flashScale = zoneFlash:FindFirstChildOfClass("UIScale")
		if flashScale ~= nil then
			flashScale.Scale = 1.4
			play(flashScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end
		play(zoneFlash, TweenInfo.new(0.55 * speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
		counter.TextColor3 = color
	end

	-- Per-frame dive -------------------------------------------------------------------------------------
	-- `pace` squeezes the whole dive when it would land after the caller's budget.
	local diveTime = Depth.diveSeconds(depth, quick)
	local natural = DROP_TIME * speed + diveTime * shape.impact
	local budget = options.budget
	local pace = if budget ~= nil and budget > 0 and natural > budget then budget / natural else 1
	local dropTime = DROP_TIME * speed * pace
	diveTime *= pace
	local settleTime = SETTLE_TIME * speed * pace
	local started = os.clock()
	local current = -SKY - 20
	local shownMetres = -1
	local splashed = false
	local landed = false
	local nextZone = 2
	local bursting = false
	local rumble = 0 -- sideways jitter of the tag during the wind-up, in window widths

	local function step(dt: number)
		local now = os.clock()
		local elapsed = now - started
		local previous = current
		if elapsed < dropTime then
			local u = elapsed / dropTime
			current = (-SKY - 20) * (1 - u * u)
		elseif hasAnswer and elapsed < dropTime + diveTime then
			local t = (elapsed - dropTime) / diveTime
			current = depth * Depth.dive(t, intensity)
			if t < shape.hold then
				-- Winding up: the tag shivers harder the longer it holds.
				local strength = (t / shape.hold) ^ 2 * (0.004 + 0.012 * intensity)
				rumble = math.sin(now * 70) * strength
			else
				rumble = 0
				if not bursting then
					bursting = true
					sound("Splash", 0.5 + 0.4 * intensity, 0.75 - 0.2 * intensity)
					Fx.shakeOffset(frame, (2 + 6 * intensity) * (if quick then 0.5 else 1), 0.25)
					local tagScale = tag:FindFirstChildOfClass("UIScale")
					if tagScale ~= nil then
						tagScale.Scale = 1.15 + 0.2 * intensity
						play(tagScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
					end
				end
			end
		elseif hasAnswer then
			rumble = 0
			current = depth
		else
			-- No answer: the tag bobs at the surface.
			current = math.sin(elapsed * 3) * 4
		end

		if not splashed and elapsed >= dropTime then
			splashed = true
			sound("Splash", 0.6, 1.1)
			local tagScale = tag:FindFirstChildOfClass("UIScale")
			if tagScale ~= nil then
				tagScale.Scale = 0.8
				play(tagScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			end
		end

		while
			hasAnswer
			and nextZone <= #Tiers.List
			and Tiers.List[nextZone].depthMin <= depth
			and current >= Tiers.List[nextZone].depthMin
		do
			flashZone(nextZone)
			nextZone += 1
		end

		if not landed and elapsed >= dropTime + diveTime * (if hasAnswer then shape.impact else 1) then
			landed = true
			task.spawn(land)
			task.delay(settleTime, fire)
		end

		local top = math.clamp(current - TAG_Y * VIEW, -SKY, BOTTOM - VIEW)
		content.Position = UDim2.fromScale(0, -(top + SKY) / VIEW)
		local tagY = (current - top) / VIEW
		tag.Position = UDim2.fromScale(0.5 + rumble, tagY)
		local ropeTop = math.max((0 - top) / VIEW, 0)
		if tagY > ropeTop + 0.01 then
			rope.Visible = true
			rope.Position = UDim2.fromScale(0.5, ropeTop)
			rope.Size = UDim2.new(0, 2, tagY - ropeTop, 0)
		else
			rope.Visible = false
		end

		-- The counter never reads past the real depth while the tag overshoots and springs back.
		local metres = math.max(0, math.floor(math.min(current, if hasAnswer then depth else current) + 0.5))
		if metres ~= shownMetres then
			shownMetres = metres
			counter.Text = Currency.digits(metres) .. " m"
		end

		local rise = if dt > 0 then math.max(0, (current - previous) / dt) / VIEW else 0
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
