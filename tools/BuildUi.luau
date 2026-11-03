--!strict
-- One-shot generator. Run once in Studio (via MCP execute_luau or the command bar) to build the
-- ScreenGuis into StarterGui from Theme tokens, then hand-edit in Studio and save the place.
-- Never run at runtime. Rebuilding replaces the existing ScreenGuis.
-- Style: chunky Roblox look. White cards with thick ink outlines, bright buttons, outlined text.

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)

local INK = Theme.Color.Ink

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function border(parent: Instance, thickness: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
end

local function textOutline(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
end

local function shine(parent: Instance)
	-- Light top, slightly darker bottom: the classic glossy Roblox button.
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205))
	g.Parent = parent
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

local function scale(parent: Instance)
	local s = Instance.new("UIScale")
	s.Parent = parent
end

local function card(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = color or Theme.Color.White
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, Theme.Radius.Large)
	border(f, Theme.Stroke.Card)
	scale(f)
	return f
end

-- Light text gets an ink outline; dark text does not need one.
local function label(name: string, parent: Instance, text: string, font: Font, color: Color3, size: UDim2, position: UDim2, maxText: number, outline: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.FontFace = font
	l.TextColor3 = color
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 12
	c.MaxTextSize = maxText
	c.Parent = l
	if outline > 0 then
		textOutline(l, outline)
	end
	return l
end

local function button(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, anchor: Vector2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.FontFace = Theme.Font.Title
	b.TextColor3 = Theme.Color.White
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Size = size
	b.Position = position
	b.AnchorPoint = anchor
	b.TextScaled = true
	b.AutoButtonColor = false
	b.Parent = parent
	corner(b, Theme.Radius.Small)
	border(b, Theme.Stroke.Card)
	shine(b)
	padding(b, 6)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 12
	c.MaxTextSize = 26
	c.Parent = b
	textOutline(b, Theme.Stroke.TextSmall)
	scale(b)
	return b
end

local function textBox(name: string, parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local t = Instance.new("TextBox")
	t.Name = name
	t.Text = ""
	t.PlaceholderText = placeholder
	t.PlaceholderColor3 = Theme.Color.Grey
	t.FontFace = Theme.Font.Body
	t.TextColor3 = INK
	t.BackgroundColor3 = Theme.Color.White
	t.BorderSizePixel = 0
	t.Size = size
	t.Position = position
	t.ClearTextOnFocus = false
	t.MultiLine = false
	t.TextScaled = true
	t.Parent = parent
	corner(t, Theme.Radius.Small)
	border(t, Theme.Stroke.Card)
	padding(t, 8)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 14
	c.MaxTextSize = 26
	c.Parent = t
	return t
end

local function strip(name: string, parent: Instance, color: Color3, height: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(1, -16, 0, height)
	f.Position = UDim2.new(0.5, 0, 0, 8)
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, Theme.Radius.Small)
	border(f, 3)
	return f
end

local function bar(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local track = Instance.new("Frame")
	track.Name = name
	track.Size = size
	track.Position = position
	track.AnchorPoint = anchor
	track.BackgroundColor3 = Theme.Color.RowLight
	track.BorderSizePixel = 0
	track.Parent = parent
	corner(track, Theme.Radius.Pill)
	border(track, 3)
	local fill = Instance.new("Frame")
	fill.Name = "TimerFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.Color.Green
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, Theme.Radius.Pill)
	return track
end

local function limit(parent: Instance, minSize: Vector2, maxSize: Vector2)
	local c = Instance.new("UISizeConstraint")
	c.MinSize = minSize
	c.MaxSize = maxSize
	c.Parent = parent
end

local function screen(name: string, insets: Enum.ScreenInsets, enabled: boolean, order: number): ScreenGui
	local old = StarterGui:FindFirstChild(name)
	if old ~= nil then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = insets
	gui.DisplayOrder = order
	gui.Enabled = enabled
	gui.Parent = StarterGui
	return gui
end

local function buildHud()
	local gui = screen("Hud", Enum.ScreenInsets.CoreUISafeInsets, false, 1)

	local promptCard = card("PromptCard", gui, UDim2.new(0.55, 0, 0, 126), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	limit(promptCard, Vector2.new(340, 126), Vector2.new(760, 126))
	local header = strip("Header", promptCard, Theme.Color.Blue, 34)
	label("RoundLabel", header, "ROUND 1", Theme.Font.Title, Theme.Color.White, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 24, Theme.Stroke.TextSmall)
	label("PromptText", promptCard, "Name a bird", Theme.Font.Body, INK, UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 46), 34, 0)
	bar("TimerTrack", promptCard, UDim2.new(1, -24, 0, 14), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1))

	local timerChip = card("TimerChip", gui, UDim2.fromOffset(96, 96), UDim2.new(0.5, 0, 0, 146), Vector2.new(0.5, 0), Theme.Color.Green)
	local chipCorner = timerChip:FindFirstChildOfClass("UICorner")
	if chipCorner ~= nil then
		chipCorner.CornerRadius = Theme.Radius.Pill
	end
	shine(timerChip)
	label("TimerText", timerChip, "20", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 10), 56, Theme.Stroke.Text)

	local aliveChip = card("AliveChip", gui, UDim2.fromOffset(150, 46), UDim2.new(1, -12, 0, 10), Vector2.new(1, 0))
	label("AliveText", aliveChip, "6 ALIVE", Theme.Font.Title, INK, UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 7), 24, 0)

	local coinChip = card("CoinChip", gui, UDim2.fromOffset(150, 46), UDim2.new(1, -12, 0, 64), Vector2.new(1, 0), Theme.Color.Gold)
	shine(coinChip)
	label("CoinText", coinChip, "0 COINS", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 7), 24, Theme.Stroke.TextSmall)

	-- Vertical water meter: your pillar marker versus the water line.
	local meter = card("WaterMeter", gui, UDim2.new(0, 34, 0.45, 0), UDim2.new(0, 14, 0.55, 0), Vector2.new(0, 0.5))
	local meterCorner = meter:FindFirstChildOfClass("UICorner")
	if meterCorner ~= nil then
		meterCorner.CornerRadius = Theme.Radius.Pill
	end
	local waterFill = Instance.new("Frame")
	waterFill.Name = "WaterFill"
	waterFill.AnchorPoint = Vector2.new(0, 1)
	waterFill.Position = UDim2.fromScale(0, 1)
	waterFill.Size = UDim2.fromScale(1, 0.2)
	waterFill.BackgroundColor3 = Theme.Color.Water
	waterFill.BorderSizePixel = 0
	waterFill.Parent = meter
	corner(waterFill, Theme.Radius.Pill)
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.6)
	marker.Size = UDim2.fromOffset(46, 12)
	marker.BackgroundColor3 = Theme.Color.Yellow
	marker.BorderSizePixel = 0
	marker.Parent = meter
	corner(marker, Theme.Radius.Pill)
	border(marker, 3)
	label("MeterLabel", meter, "YOU", Theme.Font.Title, Theme.Color.White, UDim2.fromOffset(60, 20), UDim2.new(0.5, 0, 0, -26), 18, Theme.Stroke.TextSmall).AnchorPoint = Vector2.new(0.5, 0)

	local answerBar = Instance.new("Frame")
	answerBar.Name = "AnswerBar"
	answerBar.Size = UDim2.new(0.5, 0, 0, 66)
	answerBar.Position = UDim2.new(0.5, 0, 1, -18)
	answerBar.AnchorPoint = Vector2.new(0.5, 1)
	answerBar.BackgroundTransparency = 1
	answerBar.Parent = gui
	limit(answerBar, Vector2.new(340, 66), Vector2.new(680, 66))
	scale(answerBar)
	textBox("AnswerBox", answerBar, "Type a rare answer!", UDim2.new(1, -134, 1, 0), UDim2.fromScale(0, 0))
	button("SubmitButton", answerBar, "GO!", UDim2.new(0, 122, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), Theme.Color.Green)
	local locked = card("LockedText", answerBar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), Theme.Color.Green)
	locked.Visible = false
	shine(locked)
	label("Text", locked, "LOCKED IN! WAIT FOR THE REVEAL", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -20, 1, -16), UDim2.fromOffset(10, 8), 28, Theme.Stroke.TextSmall)
	local feedback = label("Feedback", answerBar, "NOT IN THE BANK, TRY AGAIN!", Theme.Font.Title, Theme.Color.Red, UDim2.new(1, 0, 0, 30), UDim2.new(0.5, 0, 0, -8), 28, Theme.Stroke.TextSmall)
	feedback.AnchorPoint = Vector2.new(0.5, 1)
	feedback.Visible = false
	local feedbackStroke = feedback:FindFirstChildOfClass("UIStroke")
	if feedbackStroke ~= nil then
		feedbackStroke.Color = Theme.Color.White
	end
	scale(feedback)

	local banner = card("Banner", gui, UDim2.fromOffset(340, 52), UDim2.new(0.5, 0, 0, 252), Vector2.new(0.5, 0), Theme.Color.Red)
	banner.Visible = false
	shine(banner)
	label("BannerText", banner, "SUDDEN DEATH!", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 8), 32, Theme.Stroke.Text)
end

local function buildReveal()
	local gui = screen("Reveal", Enum.ScreenInsets.CoreUISafeInsets, false, 2)

	-- Sits under the prompt card so your character and pillar stay visible while it rises.
	local badge = card("Badge", gui, UDim2.fromOffset(380, 168), UDim2.new(0.5, 0, 0, 148), Vector2.new(0.5, 0))
	local tierBanner = strip("TierBanner", badge, Theme.Tier.Rare, 62)
	shine(tierBanner)
	label("TierText", tierBanner, "RARE!", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 7), 44, Theme.Stroke.Text)
	label("YourAnswer", badge, "ANDORRA", Theme.Font.Body, Theme.Color.Muted, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 78), 24, 0)
	label("PointsText", badge, "+60", Theme.Font.Title, Theme.Color.Green, UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 110), 44, Theme.Stroke.Text)

	local list = card("List", gui, UDim2.fromOffset(320, 0), UDim2.new(1, -12, 0, 120), Vector2.new(1, 0))
	list.AutomaticSize = Enum.AutomaticSize.Y
	padding(list, 10)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local row = Instance.new("Frame")
	row.Name = "RowTemplate"
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = Theme.Color.RowLight
	row.BorderSizePixel = 0
	row.Visible = false
	row.Parent = list
	corner(row, Theme.Radius.Small)
	padding(row, 6)
	local name = label("Name", row, "Player", Theme.Font.Body, INK, UDim2.new(0.38, 0, 1, 0), UDim2.fromScale(0, 0), 20, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local answer = label("Answer", row, "andorra", Theme.Font.Body, Theme.Color.Muted, UDim2.new(0.4, 0, 1, 0), UDim2.fromScale(0.38, 0), 20, 0)
	answer.TextXAlignment = Enum.TextXAlignment.Left
	local tier = label("Tier", row, "+60", Theme.Font.Title, Theme.Color.Green, UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0.78, 0), 22, Theme.Stroke.TextSmall)
	tier.TextXAlignment = Enum.TextXAlignment.Right
end

local function buildLobby()
	local gui = screen("Lobby", Enum.ScreenInsets.CoreUISafeInsets, false, 1)

	local banner = card("Banner", gui, UDim2.fromOffset(360, 90), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	local header = strip("Header", banner, Theme.Color.Blue, 30)
	label("BannerTitle", header, "DIVING IN", Theme.Font.Title, Theme.Color.White, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 22, Theme.Stroke.TextSmall)
	label("BannerText", banner, "15", Theme.Font.Title, INK, UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 44), 38, 0)

	local eliminated = card("EliminatedCard", gui, UDim2.fromOffset(380, 210), UDim2.new(0.5, 0, 0.45, 0), Vector2.new(0.5, 0.5))
	eliminated.Visible = false
	local sankHeader = strip("Header", eliminated, Theme.Color.Red, 64)
	shine(sankHeader)
	label("Title", sankHeader, "SPLASH! YOU SANK", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 8), 40, Theme.Stroke.Text)
	label("Subtitle", eliminated, "You made it to round 4", Theme.Font.Body, INK, UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 86), 24, 0)
	button("SpectateButton", eliminated, "SPECTATE", UDim2.fromOffset(200, 56), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1), Theme.Color.Blue)

	local spectateBar = card("SpectateBar", gui, UDim2.fromOffset(420, 64), UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
	spectateBar.Visible = false
	local watching = label("Watching", spectateBar, "WATCHING PLAYER", Theme.Font.Title, INK, UDim2.new(1, -230, 1, -20), UDim2.fromOffset(14, 10), 22, 0)
	watching.TextXAlignment = Enum.TextXAlignment.Left
	button("NextButton", spectateBar, "NEXT", UDim2.fromOffset(100, 46), UDim2.new(1, -116, 0.5, 0), Vector2.new(1, 0.5), Theme.Color.Blue)
	button("BackButton", spectateBar, "BACK", UDim2.fromOffset(100, 46), UDim2.new(1, -10, 0.5, 0), Vector2.new(1, 0.5), Theme.Color.Grey)
end

local function buildLobbyQuiz()
	local gui = screen("LobbyQuiz", Enum.ScreenInsets.CoreUISafeInsets, false, 1)

	local panel = card("Panel", gui, UDim2.fromOffset(330, 262), UDim2.new(0, 14, 1, -18), Vector2.new(0, 1))
	local header = strip("HeaderBar", panel, Theme.Color.Purple, 32)
	label("Header", header, "WARM-UP: 0 COINS", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -12, 1, -6), UDim2.fromOffset(6, 3), 22, Theme.Stroke.TextSmall)
	label("PromptText", panel, "Name a bird", Theme.Font.Body, INK, UDim2.new(1, -24, 0, 54), UDim2.new(0, 12, 0, 46), 28, 0)
	bar("TimerTrack", panel, UDim2.new(1, -24, 0, 12), UDim2.new(0.5, 0, 0, 106), Vector2.new(0.5, 0))
	textBox("AnswerBox", panel, "Your answer", UDim2.new(1, -24, 0, 48), UDim2.new(0, 12, 0, 130))
	button("SubmitButton", panel, "ANSWER", UDim2.new(0.5, -18, 0, 52), UDim2.new(0, 12, 1, -12), Vector2.new(0, 1), Theme.Color.Green)
	button("SkipButton", panel, "SKIP", UDim2.new(0.5, -18, 0, 52), UDim2.new(1, -12, 1, -12), Vector2.new(1, 1), Theme.Color.Grey)

	local result = card("Result", gui, UDim2.fromOffset(330, 64), UDim2.new(0, 14, 1, -292), Vector2.new(0, 1))
	result.Visible = false
	local tierText = label("TierText", result, "RARE!", Theme.Font.Title, Theme.Tier.Rare, UDim2.new(0.58, -12, 1, -16), UDim2.fromOffset(12, 8), 30, Theme.Stroke.TextSmall)
	tierText.TextXAlignment = Enum.TextXAlignment.Left
	local coins = label("CoinsText", result, "+30 COINS", Theme.Font.Title, Theme.Color.Gold, UDim2.new(0.42, -12, 1, -16), UDim2.new(0.58, 0, 0, 8), 26, Theme.Stroke.TextSmall)
	coins.TextXAlignment = Enum.TextXAlignment.Right
end

local function buildResults()
	local gui = screen("Results", Enum.ScreenInsets.CoreUISafeInsets, false, 3)

	local panel = card("Panel", gui, UDim2.fromOffset(420, 330), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	local header = strip("Header", panel, Theme.Color.Gold, 44)
	shine(header)
	label("Title", header, "LAST ONE FLOATING!", Theme.Font.Title, Theme.Color.White, UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 5), 30, Theme.Stroke.Text)
	label("WinnerText", panel, "Player", Theme.Font.Title, INK, UDim2.new(1, -24, 0, 50), UDim2.new(0, 12, 0, 60), 46, 0)

	local podium = Instance.new("Frame")
	podium.Name = "Podium"
	podium.Size = UDim2.new(1, -24, 0, 138)
	podium.Position = UDim2.new(0, 12, 0, 118)
	podium.BackgroundTransparency = 1
	podium.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = podium
	local medals = { Theme.Color.Gold, Theme.Color.Silver, Theme.Color.Bronze }
	for place = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "Place" .. place
		row.LayoutOrder = place
		row.Size = UDim2.new(1, 0, 0, 42)
		row.BackgroundColor3 = Theme.Color.RowLight
		row.BorderSizePixel = 0
		row.Parent = podium
		corner(row, Theme.Radius.Small)
		local medal = Instance.new("Frame")
		medal.Name = "Medal"
		medal.Size = UDim2.fromOffset(34, 34)
		medal.Position = UDim2.new(0, 4, 0.5, 0)
		medal.AnchorPoint = Vector2.new(0, 0.5)
		medal.BackgroundColor3 = medals[place]
		medal.BorderSizePixel = 0
		medal.Parent = row
		corner(medal, Theme.Radius.Pill)
		border(medal, 3)
		label("Rank", medal, tostring(place), Theme.Font.Title, Theme.Color.White, UDim2.new(1, -6, 1, -6), UDim2.fromOffset(3, 4), 22, Theme.Stroke.TextSmall)
		local name = label("Name", row, "-", Theme.Font.Body, INK, UDim2.new(0.6, -46, 1, -10), UDim2.new(0, 46, 0, 5), 22, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local points = label("Points", row, "0", Theme.Font.Title, Theme.Color.Blue, UDim2.new(0.4, -12, 1, -10), UDim2.new(0.6, 0, 0, 5), 24, 0)
		points.TextXAlignment = Enum.TextXAlignment.Right
	end

	label("NextText", panel, "Next dive in 10", Theme.Font.Body, Theme.Color.Muted, UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 1, -40), 22, 0)
end

-- Full-screen effects layer: flash, big callouts, floating coin text. Always enabled.
local function buildFx()
	local gui = screen("Fx", Enum.ScreenInsets.None, true, 10)
	gui.IgnoreGuiInset = true

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Theme.Color.White
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local callout = label("Callout", gui, "CLOSE CALL!", Theme.Font.Title, Theme.Color.Yellow, UDim2.fromOffset(640, 96), UDim2.fromScale(0.5, 0.62), 84, 5)
	callout.AnchorPoint = Vector2.new(0.5, 0.5)
	callout.Visible = false
	scale(callout)

	local coinPop = label("CoinPop", gui, "+50", Theme.Font.Title, Theme.Color.Gold, UDim2.fromOffset(200, 50), UDim2.fromScale(0.5, 0.5), 44, Theme.Stroke.Text)
	coinPop.AnchorPoint = Vector2.new(0.5, 0.5)
	coinPop.Visible = false
end

buildHud()
buildReveal()
buildLobby()
buildLobbyQuiz()
buildResults()
buildFx()

print("BuildUi: Hud, Reveal, Lobby, LobbyQuiz, Results, Fx built into StarterGui")
