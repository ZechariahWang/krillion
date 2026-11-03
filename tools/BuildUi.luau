--!strict
-- One-shot generator. Run once in Studio (via MCP execute_luau or the command bar) to build the
-- ScreenGuis into StarterGui from Theme tokens, then hand-edit in Studio and save the place.
-- Never run at runtime. Rebuilding replaces the existing ScreenGuis (only the ones named here).
-- Style: dark translucent navy panels, cream heavy text, 6px corners, thin aqua accent bars.

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)

local C = Theme.Color

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = Theme.Radius.Small
	c.Parent = parent
end

local function scale(parent: Instance)
	local s = Instance.new("UIScale")
	s.Parent = parent
end

local function padding(parent: Instance, x: number, y: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.Parent = parent
end

local function limit(parent: Instance, minSize: Vector2, maxSize: Vector2)
	local c = Instance.new("UISizeConstraint")
	c.MinSize = minSize
	c.MaxSize = maxSize
	c.Parent = parent
end

local function panel(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundColor3 = C.Panel
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f)
	scale(f)
	return f
end

local function blank(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundTransparency = 1
	f.Parent = parent
	scale(f)
	return f
end

-- Thin vertical bar on the left edge, the reference's signature detail.
-- Panels carry it inside the edge; buttons carry it just outside so it never touches the text.
local function sideAccent(parent: Instance, color: Color3, outside: boolean?)
	local a = Instance.new("Frame")
	a.Name = "Accent"
	a.Size = UDim2.new(0, 4, 0.6, 0)
	if outside then
		a.Position = UDim2.new(0, -8, 0.5, 0)
	else
		a.Position = UDim2.new(0, 6, 0.5, 0)
	end
	a.AnchorPoint = Vector2.new(0, 0.5)
	a.BackgroundColor3 = color
	a.BorderSizePixel = 0
	a.Parent = parent
end

-- Full-width bar along the top edge.
local function topAccent(parent: Instance, color: Color3)
	local a = Instance.new("Frame")
	a.Name = "Accent"
	a.Size = UDim2.new(1, 0, 0, 3)
	a.BackgroundColor3 = color
	a.BorderSizePixel = 0
	a.Parent = parent
end

-- Short underline that fades out at both ends.
local function underline(parent: Instance, color: Color3)
	local a = Instance.new("Frame")
	a.Name = "Accent"
	a.Size = UDim2.new(0.6, 0, 0, 2)
	a.Position = UDim2.new(0.5, 0, 1, 2)
	a.AnchorPoint = Vector2.new(0.5, 0)
	a.BackgroundColor3 = color
	a.BorderSizePixel = 0
	a.Parent = parent
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = a
end

local function label(name: string, parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2, maxText: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.FontFace = Theme.Font.Title
	l.TextColor3 = color
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 10
	c.MaxTextSize = maxText
	c.Parent = l
	return l
end

-- Text that floats over the 3D world gets a faint dark outline so it reads on bright sky.
local function worldText(l: TextLabel)
	local s = Instance.new("UIStroke")
	s.Color = C.Panel
	s.Thickness = 1.5
	s.Transparency = 0.3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
end

-- Secondary button: dark panel with a coloured side accent.
local function button(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, anchor: Vector2, accent: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.FontFace = Theme.Font.Title
	b.TextColor3 = C.Cream
	b.BackgroundColor3 = C.Panel
	b.BackgroundTransparency = Theme.Panel.Transparency
	b.BorderSizePixel = 0
	b.Size = size
	b.Position = position
	b.AnchorPoint = anchor
	b.TextScaled = true
	b.AutoButtonColor = false
	b.Parent = parent
	corner(b)
	padding(b, 14, 8)
	scale(b)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 10
	c.MaxTextSize = 22
	c.Parent = b
	sideAccent(b, accent, true)
	return b
end

-- Primary button: solid accent fill with dark text.
local function primaryButton(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, anchor: Vector2): TextButton
	local b = button(name, parent, text, size, position, anchor, C.Accent)
	b.BackgroundColor3 = C.Accent
	b.BackgroundTransparency = 0
	b.TextColor3 = C.Panel
	local accent = b:FindFirstChild("Accent")
	if accent ~= nil then
		accent:Destroy()
	end
	return b
end

local function textBox(name: string, parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local t = Instance.new("TextBox")
	t.Name = name
	t.Text = ""
	t.PlaceholderText = placeholder
	t.PlaceholderColor3 = C.Muted
	t.FontFace = Theme.Font.Title
	t.TextColor3 = C.Cream
	t.BackgroundColor3 = C.Field
	t.BackgroundTransparency = 0.1
	t.BorderSizePixel = 0
	t.Size = size
	t.Position = position
	t.ClearTextOnFocus = false
	t.MultiLine = false
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	corner(t)
	padding(t, 14, 10)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 12
	c.MaxTextSize = 24
	c.Parent = t
	return t
end

local function progress(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local track = Instance.new("Frame")
	track.Name = name
	track.Size = size
	track.Position = position
	track.AnchorPoint = anchor
	track.BackgroundColor3 = C.Field
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "TimerFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	return track
end

local function screen(name: string, insets: Enum.ScreenInsets, enabled: boolean, order: number): ScreenGui
	for _, old in StarterGui:GetChildren() do
		-- Only replace our own screens; the pasted reference GUIs are renamed RefLobby/RefGame.
		if old.Name == name and old:IsA("ScreenGui") then
			old:Destroy()
		end
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

	-- Prompt: big status text at the top with a fading underline, no box.
	local promptCard = blank("PromptCard", gui, UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.5, 0.025), Vector2.new(0.5, 0))
	limit(promptCard, Vector2.new(320, 64), Vector2.new(900, 110))
	local roundLabel = label("RoundLabel", promptCard, "ROUND 1", C.Accent, UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), 20)
	worldText(roundLabel)
	local promptText = label("PromptText", promptCard, "NAME A BIRD", C.Cream, UDim2.fromScale(1, 0.68), UDim2.fromScale(0, 0.32), 46)
	worldText(promptText)
	underline(promptCard, C.Accent)

	-- Timer | alive, split by a divider, with a thin progress line along the bottom.
	local status = panel("StatusBar", gui, UDim2.fromScale(0.22, 0.05), UDim2.fromScale(0.5, 0.14), Vector2.new(0.5, 0), Theme.Panel.Transparency)
	limit(status, Vector2.new(220, 38), Vector2.new(380, 56))
	local timerText = label("TimerText", status, "20", C.Cream, UDim2.fromScale(0.5, 1), UDim2.fromScale(0, 0), 30)
	padding(timerText, 0, 6)
	scale(timerText)
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0, 1, 0.6, 0)
	divider.Position = UDim2.fromScale(0.5, 0.5)
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.BackgroundColor3 = C.Cream
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.Parent = status
	local aliveText = label("AliveText", status, "ALIVE 6", C.Cream, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.5, 0), 22)
	padding(aliveText, 0, 8)
	progress("TimerTrack", status, UDim2.new(1, 0, 0, 3), UDim2.fromScale(0, 1), Vector2.new(0, 1))

	local coinChip = panel("CoinChip", gui, UDim2.fromScale(0.12, 0.05), UDim2.new(1, -12, 0.025, 0), Vector2.new(1, 0), Theme.Panel.Transparency)
	limit(coinChip, Vector2.new(130, 36), Vector2.new(220, 52))
	sideAccent(coinChip, C.Gold)
	local coinText = label("CoinText", coinChip, "0 COINS", C.Gold, UDim2.new(1, -24, 1, -12), UDim2.fromOffset(18, 6), 22)
	coinText.TextXAlignment = Enum.TextXAlignment.Left

	-- Vertical water meter: your pillar marker versus the water line.
	local meter = panel("WaterMeter", gui, UDim2.new(0, 22, 0.4, 0), UDim2.new(0, 16, 0.55, 0), Vector2.new(0, 0.5), Theme.Panel.Transparency)
	local waterFill = Instance.new("Frame")
	waterFill.Name = "WaterFill"
	waterFill.AnchorPoint = Vector2.new(0, 1)
	waterFill.Position = UDim2.fromScale(0, 1)
	waterFill.Size = UDim2.fromScale(1, 0.2)
	waterFill.BackgroundColor3 = C.Water
	waterFill.BorderSizePixel = 0
	waterFill.Parent = meter
	corner(waterFill)
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.6)
	marker.Size = UDim2.new(1, 10, 0, 4)
	marker.BackgroundColor3 = C.Cream
	marker.BorderSizePixel = 0
	marker.Parent = meter
	local meterLabel = label("MeterLabel", meter, "YOU", C.Cream, UDim2.fromOffset(40, 16), UDim2.new(0.5, 0, 0, -20), 14)
	meterLabel.AnchorPoint = Vector2.new(0.5, 0)
	worldText(meterLabel)

	-- Answer entry at the bottom.
	local answerBar = blank("AnswerBar", gui, UDim2.fromScale(0.42, 0.075), UDim2.new(0.5, 0, 1, -20), Vector2.new(0.5, 1))
	limit(answerBar, Vector2.new(320, 48), Vector2.new(680, 64))
	textBox("AnswerBox", answerBar, "TYPE A RARE ANSWER", UDim2.new(0.78, -8, 1, 0), UDim2.fromScale(0, 0))
	primaryButton("SubmitButton", answerBar, "GO", UDim2.fromScale(0.22, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0))
	local locked = panel("LockedText", answerBar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), Theme.Panel.Transparency)
	locked.Visible = false
	sideAccent(locked, C.Green)
	label("Text", locked, "LOCKED IN  |  WAIT FOR THE REVEAL", C.Cream, UDim2.new(1, -40, 1, -16), UDim2.fromOffset(24, 8), 22)
	local feedback = panel("Feedback", answerBar, UDim2.new(0.6, 0, 0, 32), UDim2.new(0.5, 0, 0, -8), Vector2.new(0.5, 1), Theme.Panel.ModalTransparency)
	feedback.Visible = false
	sideAccent(feedback, C.Red)
	label("Text", feedback, "NOT IN THE BANK  |  TRY AGAIN", C.Red, UDim2.new(1, -36, 1, -10), UDim2.fromOffset(22, 5), 18)

	-- Like the reference's stage-change card: solid box, small title, big coloured line.
	local banner = panel("Banner", gui, UDim2.fromScale(0.22, 0.09), UDim2.fromScale(0.5, 0.22), Vector2.new(0.5, 0), Theme.Panel.ModalTransparency)
	limit(banner, Vector2.new(240, 60), Vector2.new(380, 90))
	banner.Visible = false
	label("Title", banner, "LAST TWO", C.Cream, UDim2.fromScale(0.8, 0.35), UDim2.fromScale(0.1, 0.08), 18)
	label("BannerText", banner, "SUDDEN DEATH", C.Red, UDim2.fromScale(0.85, 0.45), UDim2.fromScale(0.075, 0.45), 30)
end

local function buildReveal()
	local gui = screen("Reveal", Enum.ScreenInsets.CoreUISafeInsets, false, 2)

	-- Your result, under the prompt so your pillar stays visible.
	local badge = panel("Badge", gui, UDim2.fromScale(0.26, 0.2), UDim2.fromScale(0.5, 0.215), Vector2.new(0.5, 0), Theme.Panel.ModalTransparency)
	limit(badge, Vector2.new(260, 120), Vector2.new(420, 170))
	topAccent(badge, C.Accent)
	label("YourAnswer", badge, "ANDORRA", C.Muted, UDim2.fromScale(0.86, 0.2), UDim2.fromScale(0.07, 0.1), 20)
	label("TierText", badge, "RARE", Theme.Tier.Rare, UDim2.fromScale(0.86, 0.38), UDim2.fromScale(0.07, 0.3), 44)
	label("PointsText", badge, "+60", C.Cream, UDim2.fromScale(0.86, 0.24), UDim2.fromScale(0.07, 0.7), 28)

	-- Everyone's answers, like the reference scoreboard.
	local list = panel("List", gui, UDim2.fromScale(0.24, 0), UDim2.new(1, -12, 0.14, 0), Vector2.new(1, 0), Theme.Panel.ModalTransparency)
	limit(list, Vector2.new(240, 0), Vector2.new(380, 600))
	list.AutomaticSize = Enum.AutomaticSize.Y
	padding(list, 10, 10)
	topAccent(list, C.Accent)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local title = label("Title", list, "ANSWERS", C.Cream, UDim2.new(1, 0, 0, 22), UDim2.fromScale(0, 0), 20)
	title.LayoutOrder = -1
	title.TextXAlignment = Enum.TextXAlignment.Left

	local row = Instance.new("Frame")
	row.Name = "RowTemplate"
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = C.Row
	row.BackgroundTransparency = Theme.Panel.RowTransparency
	row.BorderSizePixel = 0
	row.Visible = false
	row.Parent = list
	padding(row, 8, 5)
	scale(row)
	local name = label("Name", row, "PLAYER", C.Cream, UDim2.fromScale(0.38, 1), UDim2.fromScale(0, 0), 18)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local answer = label("Answer", row, "andorra", C.Muted, UDim2.fromScale(0.4, 1), UDim2.fromScale(0.38, 0), 18)
	answer.TextXAlignment = Enum.TextXAlignment.Left
	local tier = label("Tier", row, "+60", C.Accent, UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 18)
	tier.TextXAlignment = Enum.TextXAlignment.Right
end

local function buildLobby()
	local gui = screen("Lobby", Enum.ScreenInsets.CoreUISafeInsets, false, 1)

	local banner = blank("Banner", gui, UDim2.fromScale(0.35, 0.09), UDim2.fromScale(0.5, 0.025), Vector2.new(0.5, 0))
	limit(banner, Vector2.new(280, 56), Vector2.new(600, 90))
	local title = label("BannerTitle", banner, "DIVING IN", C.Accent, UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 20)
	worldText(title)
	local text = label("BannerText", banner, "15", C.Cream, UDim2.fromScale(1, 0.65), UDim2.fromScale(0, 0.35), 40)
	worldText(text)
	underline(banner, C.Accent)

	local eliminated = panel("EliminatedCard", gui, UDim2.fromScale(0.3, 0.24), UDim2.fromScale(0.5, 0.42), Vector2.new(0.5, 0.5), Theme.Panel.ModalTransparency)
	limit(eliminated, Vector2.new(280, 150), Vector2.new(440, 210))
	eliminated.Visible = false
	topAccent(eliminated, C.Red)
	label("Title", eliminated, "YOU SANK", C.Red, UDim2.fromScale(0.86, 0.3), UDim2.fromScale(0.07, 0.1), 40)
	label("Subtitle", eliminated, "YOU MADE IT TO ROUND 4", C.Cream, UDim2.fromScale(0.86, 0.15), UDim2.fromScale(0.07, 0.42), 20)
	button("SpectateButton", eliminated, "SPECTATE", UDim2.fromScale(0.6, 0.24), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1), C.Purple)

	-- Like the reference spectate bar: target in the middle, next on the right, back to lobby below.
	local spectateBar = blank("SpectateBar", gui, UDim2.fromScale(0.3, 0.13), UDim2.new(0.5, 0, 1, -20), Vector2.new(0.5, 1))
	limit(spectateBar, Vector2.new(300, 90), Vector2.new(480, 120))
	spectateBar.Visible = false
	local watching = label("Watching", spectateBar, "WATCHING PLAYER", C.Cream, UDim2.fromScale(0.74, 0.46), UDim2.fromScale(0, 0), 20)
	watching.BackgroundColor3 = C.Panel
	watching.BackgroundTransparency = Theme.Panel.Transparency
	corner(watching)
	padding(watching, 10, 6)
	button("NextButton", spectateBar, ">", UDim2.fromScale(0.24, 0.46), UDim2.fromScale(1, 0), Vector2.new(1, 0), C.Accent)
	button("BackButton", spectateBar, "BACK TO LOBBY", UDim2.fromScale(0.6, 0.44), UDim2.fromScale(0.5, 1), Vector2.new(0.5, 1), C.Muted)
end

local function buildLobbyQuiz()
	local gui = screen("LobbyQuiz", Enum.ScreenInsets.CoreUISafeInsets, false, 1)

	local panelFrame = panel("Panel", gui, UDim2.fromScale(0.24, 0.3), UDim2.new(0, 16, 1, -20), Vector2.new(0, 1), Theme.Panel.Transparency)
	limit(panelFrame, Vector2.new(260, 200), Vector2.new(360, 260))
	sideAccent(panelFrame, C.Purple)
	local header = blank("HeaderBar", panelFrame, UDim2.new(1, -36, 0.12, 0), UDim2.new(0, 22, 0.05, 0), Vector2.new(0, 0))
	local headerText = label("Header", header, "WARM-UP  |  0 COINS", C.Muted, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 16)
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	local prompt = label("PromptText", panelFrame, "NAME A BIRD", C.Cream, UDim2.new(1, -36, 0.24, 0), UDim2.new(0, 22, 0.19, 0), 26)
	prompt.TextXAlignment = Enum.TextXAlignment.Left
	progress("TimerTrack", panelFrame, UDim2.new(1, -36, 0, 3), UDim2.new(0, 22, 0.45, 0), Vector2.new(0, 0))
	textBox("AnswerBox", panelFrame, "YOUR ANSWER", UDim2.new(1, -36, 0.2, 0), UDim2.new(0, 22, 0.51, 0))
	primaryButton("SubmitButton", panelFrame, "ANSWER", UDim2.new(0.5, -22, 0.18, 0), UDim2.new(0, 22, 0.94, 0), Vector2.new(0, 1))
	local skip = button("SkipButton", panelFrame, "SKIP", UDim2.new(0.5, -22, 0.18, 0), UDim2.new(1, -14, 0.94, 0), Vector2.new(1, 1), C.Muted)
	-- Sits right beside the Answer button, where an outside accent would float in the gap.
	local skipAccent = skip:FindFirstChild("Accent")
	if skipAccent ~= nil then
		skipAccent:Destroy()
	end

	local result = panel("Result", gui, UDim2.fromScale(0.24, 0.07), UDim2.new(0, 16, 0.7, -32), Vector2.new(0, 1), Theme.Panel.ModalTransparency)
	limit(result, Vector2.new(260, 44), Vector2.new(360, 56))
	result.Visible = false
	sideAccent(result, C.Accent)
	local tierText = label("TierText", result, "RARE", Theme.Tier.Rare, UDim2.new(0.6, -22, 1, -14), UDim2.fromOffset(22, 7), 24)
	tierText.TextXAlignment = Enum.TextXAlignment.Left
	local coins = label("CoinsText", result, "+30 COINS", C.Gold, UDim2.new(0.4, -12, 1, -14), UDim2.new(0.6, 0, 0, 7), 20)
	coins.TextXAlignment = Enum.TextXAlignment.Right
end

local function buildResults()
	local gui = screen("Results", Enum.ScreenInsets.CoreUISafeInsets, false, 3)

	local panelFrame = panel("Panel", gui, UDim2.fromScale(0.32, 0.46), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), Theme.Panel.ModalTransparency)
	limit(panelFrame, Vector2.new(300, 260), Vector2.new(480, 360))
	topAccent(panelFrame, C.Gold)
	label("Title", panelFrame, "LAST ONE FLOATING", C.Muted, UDim2.fromScale(0.9, 0.08), UDim2.fromScale(0.05, 0.06), 18)
	label("WinnerText", panelFrame, "PLAYER", C.Gold, UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.15), 44)

	local podium = Instance.new("Frame")
	podium.Name = "Podium"
	podium.Size = UDim2.fromScale(0.9, 0.48)
	podium.Position = UDim2.fromScale(0.05, 0.36)
	podium.BackgroundTransparency = 1
	podium.Parent = panelFrame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = podium
	local medals = { C.Gold, C.Silver, C.Bronze }
	for place = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "Place" .. place
		row.LayoutOrder = place
		row.Size = UDim2.fromScale(1, 0.3)
		row.BackgroundColor3 = C.Row
		row.BackgroundTransparency = Theme.Panel.RowTransparency
		row.BorderSizePixel = 0
		row.Parent = podium
		sideAccent(row, medals[place])
		local rank = label("Rank", row, tostring(place), medals[place], UDim2.fromScale(0.1, 0.7), UDim2.fromScale(0.05, 0.15), 22)
		rank.TextXAlignment = Enum.TextXAlignment.Left
		local name = label("Name", row, "-", C.Cream, UDim2.fromScale(0.55, 0.7), UDim2.fromScale(0.15, 0.15), 22)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local points = label("Points", row, "0", C.Accent, UDim2.fromScale(0.28, 0.7), UDim2.fromScale(0.69, 0.15), 22)
		points.TextXAlignment = Enum.TextXAlignment.Right
	end

	label("NextText", panelFrame, "NEXT DIVE IN 10", C.Muted, UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.05, 0.88), 16)
end

-- Full-screen effects layer: flash, big callouts, floating coin text. Always enabled.
local function buildFx()
	local gui = screen("Fx", Enum.ScreenInsets.None, true, 10)
	gui.IgnoreGuiInset = true

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = C.Cream
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local callout = label("Callout", gui, "CLOSE CALL", C.Yellow, UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.5, 0.62), 72)
	callout.AnchorPoint = Vector2.new(0.5, 0.5)
	callout.Visible = false
	worldText(callout)
	scale(callout)

	local coinPop = label("CoinPop", gui, "+50", C.Gold, UDim2.fromOffset(200, 44), UDim2.fromScale(0.5, 0.5), 36)
	coinPop.AnchorPoint = Vector2.new(0.5, 0.5)
	coinPop.Visible = false
	worldText(coinPop)
end

buildHud()
buildReveal()
buildLobby()
buildLobbyQuiz()
buildResults()
buildFx()

print("BuildUi: Hud, Reveal, Lobby, LobbyQuiz, Results, Fx built into StarterGui")
