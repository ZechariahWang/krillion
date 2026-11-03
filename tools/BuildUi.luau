--!strict
-- One-shot generator. Run once in Studio (via MCP execute_luau or the command bar) to build the
-- five ScreenGuis into StarterGui from Theme tokens, then hand-edit in Studio and save the place.
-- Never run at runtime. Rebuilding replaces the existing ScreenGuis.

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = Theme.Stroke.Thickness
	s.Transparency = Theme.Stroke.Transparency
	s.Color = color or Theme.Color.Text
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

local function frame(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = Theme.Color.Navy
	f.BackgroundTransparency = Theme.Panel.Transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, Theme.Radius.Large)
	stroke(f)
	return f
end

local function label(name: string, parent: Instance, text: string, font: Font, size: UDim2, position: UDim2, maxText: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.FontFace = font
	l.TextColor3 = Theme.Color.Text
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 14
	constraint.MaxTextSize = maxText
	constraint.Parent = l
	return l
end

local function button(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, anchor: Vector2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.FontFace = Theme.Font.Bold
	b.TextColor3 = Theme.Color.Text
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Size = size
	b.Position = position
	b.AnchorPoint = anchor
	b.TextScaled = true
	b.AutoButtonColor = false
	b.Parent = parent
	corner(b, Theme.Radius.Small)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 14
	constraint.MaxTextSize = 22
	constraint.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	return b
end

local function textBox(name: string, parent: Instance, placeholder: string, size: UDim2, position: UDim2, anchor: Vector2): TextBox
	local t = Instance.new("TextBox")
	t.Name = name
	t.Text = ""
	t.PlaceholderText = placeholder
	t.PlaceholderColor3 = Theme.Color.TextDim
	t.FontFace = Theme.Font.Medium
	t.TextColor3 = Theme.Color.Text
	t.BackgroundColor3 = Theme.Color.Surface
	t.BorderSizePixel = 0
	t.Size = size
	t.Position = position
	t.AnchorPoint = anchor
	t.ClearTextOnFocus = false
	t.MultiLine = false
	t.TextScaled = true
	t.Parent = parent
	corner(t, Theme.Radius.Small)
	stroke(t, Theme.Color.Accent)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 16
	constraint.MaxTextSize = 24
	constraint.Parent = t
	return t
end

local function screen(name: string): ScreenGui
	local old = StarterGui:FindFirstChild(name)
	if old ~= nil then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Enabled = false
	gui.Parent = StarterGui
	return gui
end

local function buildHud()
	local gui = screen("Hud")

	local promptCard = frame("PromptCard", gui, UDim2.new(0.6, 0, 0, 96), UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
	local promptSize = Instance.new("UISizeConstraint")
	promptSize.MinSize = Vector2.new(320, 96)
	promptSize.MaxSize = Vector2.new(720, 96)
	promptSize.Parent = promptCard
	padding(promptCard, 12)
	label("RoundLabel", promptCard, "ROUND 1", Theme.Font.Medium, UDim2.new(1, 0, 0, 18), UDim2.fromScale(0, 0), 16).TextColor3 = Theme.Color.TextDim
	label("PromptText", promptCard, "Name a bird", Theme.Font.Bold, UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 22), 28)
	local timerTrack = Instance.new("Frame")
	timerTrack.Name = "TimerTrack"
	timerTrack.Size = UDim2.new(1, 0, 0, 6)
	timerTrack.Position = UDim2.new(0, 0, 1, -6)
	timerTrack.BackgroundColor3 = Theme.Color.Surface
	timerTrack.BorderSizePixel = 0
	timerTrack.Parent = promptCard
	corner(timerTrack, Theme.Radius.Pill)
	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Theme.Color.Accent
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerTrack
	corner(timerFill, Theme.Radius.Pill)

	local timerChip = frame("TimerChip", gui, UDim2.fromOffset(72, 72), UDim2.new(0.5, 0, 0, 124), Vector2.new(0.5, 0))
	timerChip.BackgroundColor3 = Theme.Color.Surface
	timerChip.BackgroundTransparency = 0
	local chipCorner = timerChip:FindFirstChildOfClass("UICorner")
	if chipCorner ~= nil then
		chipCorner.CornerRadius = Theme.Radius.Pill
	end
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timerChip
	label("TimerText", timerChip, "20", Theme.Font.Black, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 36)

	local aliveChip = frame("AliveChip", gui, UDim2.fromOffset(140, 36), UDim2.new(1, -16, 0, 16), Vector2.new(1, 0))
	label("AliveText", aliveChip, "6 ALIVE", Theme.Font.Bold, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 18)

	local coinChip = frame("CoinChip", gui, UDim2.fromOffset(140, 36), UDim2.new(1, -16, 0, 60), Vector2.new(1, 0))
	label("CoinText", coinChip, "0 COINS", Theme.Font.Bold, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 18).TextColor3 = Theme.Color.Gold

	-- Vertical water meter: your platform marker versus the water line.
	local meter = frame("WaterMeter", gui, UDim2.new(0, 28, 0.5, 0), UDim2.new(0, 16, 0.5, 0), Vector2.new(0, 0.5))
	meter.BackgroundColor3 = Theme.Color.Surface
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
	marker.Size = UDim2.fromOffset(36, 6)
	marker.BackgroundColor3 = Theme.Color.Text
	marker.BorderSizePixel = 0
	marker.Parent = meter
	corner(marker, Theme.Radius.Pill)

	local answerBar = frame("AnswerBar", gui, UDim2.new(0.5, 0, 0, 56), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))
	local answerSize = Instance.new("UISizeConstraint")
	answerSize.MinSize = Vector2.new(320, 56)
	answerSize.MaxSize = Vector2.new(640, 56)
	answerSize.Parent = answerBar
	answerBar.BackgroundTransparency = 1
	local answerStroke = answerBar:FindFirstChildOfClass("UIStroke")
	if answerStroke ~= nil then
		answerStroke:Destroy()
	end
	textBox("AnswerBox", answerBar, "Type your answer and press Enter", UDim2.new(1, -112, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0))
	button("SubmitButton", answerBar, "LOCK IN", UDim2.new(0, 104, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), Theme.Color.Accent)
	label("LockedText", answerBar, "LOCKED IN", Theme.Font.Bold, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 22).Visible = false

	local banner = frame("Banner", gui, UDim2.new(0, 360, 0, 48), UDim2.new(0.5, 0, 0.5, -40), Vector2.new(0.5, 0.5))
	banner.BackgroundColor3 = Theme.Color.Danger
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	label("BannerText", banner, "SUDDEN DEATH", Theme.Font.Black, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 26)
end

local function buildReveal()
	local gui = screen("Reveal")

	local badge = frame("Badge", gui, UDim2.new(0, 340, 0, 120), UDim2.new(0.5, 0, 0.42, 0), Vector2.new(0.5, 0.5))
	badge.BackgroundColor3 = Theme.Color.Surface
	badge.BackgroundTransparency = 0
	local badgeScale = Instance.new("UIScale")
	badgeScale.Parent = badge
	label("YourAnswer", badge, "ANDORRA", Theme.Font.Medium, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 10), 18).TextColor3 = Theme.Color.TextDim
	label("TierText", badge, "RARE", Theme.Font.Black, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 34), 36)
	label("PointsText", badge, "+60", Theme.Font.Bold, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 80), 24).TextColor3 = Theme.Color.Accent

	local list = frame("List", gui, UDim2.new(0, 340, 0, 0), UDim2.new(0.5, 0, 0.42, 80), Vector2.new(0.5, 0))
	list.AutomaticSize = Enum.AutomaticSize.Y
	padding(list, 8)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local row = Instance.new("Frame")
	row.Name = "RowTemplate"
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundColor3 = Theme.Color.Surface
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.Visible = false
	row.Parent = list
	corner(row, Theme.Radius.Small)
	padding(row, 6)
	local name = label("Name", row, "Player", Theme.Font.Medium, UDim2.new(0.4, 0, 1, 0), UDim2.fromScale(0, 0), 16)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local answer = label("Answer", row, "andorra", Theme.Font.Regular, UDim2.new(0.38, 0, 1, 0), UDim2.fromScale(0.4, 0), 16)
	answer.TextColor3 = Theme.Color.TextDim
	answer.TextXAlignment = Enum.TextXAlignment.Left
	local tier = label("Tier", row, "+60", Theme.Font.Bold, UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0.78, 0), 16)
	tier.TextXAlignment = Enum.TextXAlignment.Right
end

local function buildLobby()
	local gui = screen("Lobby")

	local banner = frame("Banner", gui, UDim2.new(0, 360, 0, 64), UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
	label("BannerTitle", banner, "DIVING IN", Theme.Font.Medium, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 8), 16).TextColor3 = Theme.Color.TextDim
	label("BannerText", banner, "15", Theme.Font.Black, UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 26), 30)

	local card = frame("EliminatedCard", gui, UDim2.new(0, 360, 0, 150), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	card.Visible = false
	label("Title", card, "YOU SANK", Theme.Font.Black, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 16), 32)
	label("Subtitle", card, "Round 4", Theme.Font.Medium, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 58), 18).TextColor3 = Theme.Color.TextDim
	button("SpectateButton", card, "SPECTATE", UDim2.new(0, 160, 0, 40), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1), Theme.Color.Accent)

	local spectateBar = frame("SpectateBar", gui, UDim2.new(0, 320, 0, 44), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))
	spectateBar.Visible = false
	label("Watching", spectateBar, "WATCHING PLAYER", Theme.Font.Medium, UDim2.new(1, -200, 1, 0), UDim2.new(0, 8, 0, 0), 16)
	button("NextButton", spectateBar, "NEXT", UDim2.new(0, 80, 0, 32), UDim2.new(1, -96, 0.5, 0), Vector2.new(1, 0.5), Theme.Color.Surface)
	button("BackButton", spectateBar, "BACK", UDim2.new(0, 80, 0, 32), UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5), Theme.Color.SurfaceLight)
end

local function buildLobbyQuiz()
	local gui = screen("LobbyQuiz")

	local panel = frame("Panel", gui, UDim2.new(0, 300, 0, 200), UDim2.new(0, 16, 1, -24), Vector2.new(0, 1))
	padding(panel, 12)
	label("Header", panel, "WARM-UP  ·  EARN COINS", Theme.Font.Medium, UDim2.new(1, 0, 0, 18), UDim2.fromScale(0, 0), 14).TextColor3 = Theme.Color.TextDim
	label("PromptText", panel, "Name a bird", Theme.Font.Bold, UDim2.new(1, 0, 0, 48), UDim2.new(0, 0, 0, 24), 22)
	local timerTrack = Instance.new("Frame")
	timerTrack.Name = "TimerTrack"
	timerTrack.Size = UDim2.new(1, 0, 0, 4)
	timerTrack.Position = UDim2.new(0, 0, 0, 78)
	timerTrack.BackgroundColor3 = Theme.Color.Surface
	timerTrack.BorderSizePixel = 0
	timerTrack.Parent = panel
	corner(timerTrack, Theme.Radius.Pill)
	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Theme.Color.Accent
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerTrack
	corner(timerFill, Theme.Radius.Pill)
	textBox("AnswerBox", panel, "Your answer", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 92), Vector2.new(0, 0))
	button("SubmitButton", panel, "ANSWER", UDim2.new(0.5, -4, 0, 32), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), Theme.Color.Accent)
	button("SkipButton", panel, "SKIP", UDim2.new(0.5, -4, 0, 32), UDim2.new(1, 0, 1, 0), Vector2.new(1, 1), Theme.Color.Surface)

	local result = frame("Result", gui, UDim2.new(0, 300, 0, 56), UDim2.new(0, 16, 1, -236), Vector2.new(0, 1))
	result.BackgroundColor3 = Theme.Color.Surface
	result.BackgroundTransparency = 0
	result.Visible = false
	local resultScale = Instance.new("UIScale")
	resultScale.Parent = result
	label("TierText", result, "RARE", Theme.Font.Black, UDim2.new(0.6, 0, 1, 0), UDim2.fromScale(0, 0), 22)
	label("CoinsText", result, "+30 COINS", Theme.Font.Bold, UDim2.new(0.4, 0, 1, 0), UDim2.fromScale(0.6, 0), 18).TextColor3 = Theme.Color.Gold
end

local function buildResults()
	local gui = screen("Results")

	local panel = frame("Panel", gui, UDim2.new(0, 380, 0, 260), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	padding(panel, 16)
	label("Title", panel, "LAST ONE FLOATING", Theme.Font.Medium, UDim2.new(1, 0, 0, 20), UDim2.fromScale(0, 0), 16).TextColor3 = Theme.Color.TextDim
	label("WinnerText", panel, "Player", Theme.Font.Black, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 24), 36).TextColor3 = Theme.Color.Gold

	local podium = Instance.new("Frame")
	podium.Name = "Podium"
	podium.Size = UDim2.new(1, 0, 0, 120)
	podium.Position = UDim2.new(0, 0, 0, 80)
	podium.BackgroundTransparency = 1
	podium.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = podium
	for place = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "Place" .. place
		row.LayoutOrder = place
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = Theme.Color.Surface
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Parent = podium
		corner(row, Theme.Radius.Small)
		padding(row, 8)
		local rank = label("Rank", row, "#" .. place, Theme.Font.Bold, UDim2.new(0.12, 0, 1, 0), UDim2.fromScale(0, 0), 18)
		rank.TextXAlignment = Enum.TextXAlignment.Left
		local name = label("Name", row, "-", Theme.Font.Medium, UDim2.new(0.58, 0, 1, 0), UDim2.fromScale(0.12, 0), 18)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local points = label("Points", row, "0", Theme.Font.Bold, UDim2.new(0.3, 0, 1, 0), UDim2.fromScale(0.7, 0), 18)
		points.TextXAlignment = Enum.TextXAlignment.Right
		points.TextColor3 = Theme.Color.Accent
	end

	label("NextText", panel, "Next dive in 10", Theme.Font.Medium, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 1, -20), 16).TextColor3 = Theme.Color.TextDim
end

buildHud()
buildReveal()
buildLobby()
buildLobbyQuiz()
buildResults()

print("BuildUi: Hud, Reveal, Lobby, LobbyQuiz, Results built into StarterGui")
