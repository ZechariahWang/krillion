--!strict
-- Drives StarterGui.Standings (authored in Studio): a small STANDINGS tab that is always on
-- screen, docked right under whichever Shells chip shows (the Hud one in a match, the Wallet one in the
-- lobby). Click or tap it to open the list (rank, name, pillar height, lock dot), or hold Q to peek. Between
-- matches the list keeps the last match until the next one starts. The list closes itself when a prompt
-- starts unless it is pinned, and stays shut while the Reveal list is up; that list is pushed below the tab
-- if the two would meet, since both use the right-hand column.
-- It also tags every other pillar with its answer once the pillars rise (ReplicatedStorage.Templates.AnswerTag,
-- or a Studio-authored NameTag.AnswerText if the template ever gains one), and hides your own pillar's name
-- tag locally so it never blocks your view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local PEEK_KEY = Enum.KeyCode.Q -- not Tab: Tab also toggles Roblox's own player list
local MEDALS = {
	Color3.fromRGB(255, 200, 61),
	Color3.fromRGB(200, 214, 230),
	Color3.fromRGB(222, 140, 80),
}
local PLAIN_BADGE = Theme.Panel.Top
local ROW_FILL = Color3.fromRGB(8, 16, 36)
local SUNK_TEXT = Color3.fromRGB(255, 126, 182)
local REFERENCE_HEIGHT = 760 -- screens shorter than this shrink the panel so a full list still fits
local MIN_SCALE = 0.55
local TAG_GAP = 4 -- pixels between a pillar's name tag and its answer tag
local TAG_STUDS = 2.5 -- fallback lift when the name tag is sized in studs
local MATCH_PHASES: { [string]: boolean } = { Prompt = true, Reveal = true, Surge = true }
local DOCK_GAP = 6 -- pixels between the Shells chip and the tab, and between the tab and the Reveal list

type Entry = {
	userId: number,
	alive: boolean,
	height: number,
	locked: boolean,
	tier: string?,
	revealed: boolean, -- has been through at least one reveal (so the tier bar means something)
	sunkAt: number, -- order of sinking; later sinkers rank higher
}

type Row = {
	frame: Frame,
	border: UIStroke?,
	badge: Frame?,
	rank: TextLabel?,
	tierBar: Frame?,
	name: TextLabel?,
	lock: Frame?,
	height: TextLabel?,
	value: NumberValue,
	shown: number?,
	wasLocked: boolean,
}

type Tag = {
	label: TextLabel,
	billboard: BillboardGui?, -- our clone; nil when the label is a Studio-authored NameTag.AnswerText
	border: UIStroke?,
}

local gui: Frame? = nil
local rootScale: UIScale? = nil
local tab: TextButton? = nil
local arrow: TextLabel? = nil
local place: TextLabel? = nil
local list: Frame? = nil
local pinButton: TextButton? = nil
local rowTemplate: Frame? = nil
local revealGui: Frame? = nil
local revealList: GuiObject? = nil
local revealListPosition: UDim2? = nil -- as authored, so a nudge below the tab is never compounded
local rootFrame: GuiObject? = nil
local emptyLabel: TextLabel? = nil
local hudGui: Frame? = nil
local hudChip: GuiObject? = nil
local walletGui: Frame? = nil
local walletChip: GuiObject? = nil
local shopPanel: GuiObject? = nil

local phase = "Waiting"
local stale = false -- the entries are from a finished match; the next match clears them
local expanded = false -- opened by a click or tap
local peeking = false -- Q held
local pinned = false
local sinkCount = 0
local revealToken = 0

local entries: { [number]: Entry } = {}
local rows: { [number]: Row } = {}
local names: { [number]: string } = {} -- from Reveal rows (bots have no Player)
local tags: { [Instance]: Tag } = {}

local Standings = {}

local function escape(text: string): string
	return (string.gsub(text, "[&<>\"']", {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		['"'] = "&quot;",
		["'"] = "&apos;",
	}))
end

local function platformFor(userId: number): BasePart?
	local folder = workspace:FindFirstChild("Platforms")
	if folder == nil then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("OwnerUserId") == userId then
			return child
		end
	end
	return nil
end

local function nameTagOf(platform: Instance): BillboardGui?
	local tag = platform:FindFirstChild("NameTag")
	if tag ~= nil and tag:IsA("BillboardGui") then
		return tag
	end
	return nil
end

local function nameFor(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		return player.DisplayName
	end
	local known = names[userId]
	if known ~= nil then
		return known
	end
	-- Bots: the server writes their name on the pillar tag before the first reveal.
	local platform = platformFor(userId)
	local nameTag = if platform ~= nil then nameTagOf(platform) else nil
	local text = if nameTag ~= nil then nameTag:FindFirstChild("NameText") else nil
	if text ~= nil and text:IsA("TextLabel") and text.Text ~= "" then
		return text.Text
	end
	return if userId < 0 then "BOT" else "PLAYER"
end

-- Alive players by height, then the sunk ones, most recently sunk first.
local function sorted(): { Entry }
	local result = {}
	for _, entry in entries do
		table.insert(result, entry)
	end
	table.sort(result, function(a, b)
		if a.alive ~= b.alive then
			return a.alive
		end
		if a.alive then
			if a.height ~= b.height then
				return a.height > b.height
			end
			return a.userId < b.userId
		end
		if a.sunkAt ~= b.sunkAt then
			return a.sunkAt > b.sunkAt
		end
		return a.userId < b.userId
	end)
	return result
end

-- Visibility -------------------------------------------------------------------------------------------

local function revealShowing(): boolean
	local reveal = revealGui
	if reveal == nil or not reveal.Visible then
		return false
	end
	local revealRows = revealList
	return revealRows == nil or revealRows.Visible
end

-- The Shells chip the player can see right now: the Hud one in a match, otherwise the Wallet one.
local function visibleChip(): GuiObject?
	local hud = hudGui
	local coin = hudChip
	if hud ~= nil and coin ~= nil and hud.Visible and coin.Visible then
		return coin
	end
	local wallet = walletGui
	local own = walletChip
	if wallet ~= nil and own ~= nil and wallet.Visible and own.Visible then
		return own
	end
	return nil
end

-- The bottom edge of an object without the bump its UIScale may be playing, in screen pixels.
local function restingBottom(object: GuiObject): number
	local scale = object:FindFirstChildOfClass("UIScale")
	local factor = if scale ~= nil and scale.Scale > 0 then scale.Scale / Ui.rest(object) else 1
	return object.AbsolutePosition.Y + object.AbsoluteSize.Y / factor
end

-- Docks the tab right under the visible Shells chip, right edges lined up, and pushes the Reveal list down
-- when it would start above the tab's bottom. Positions are offsets from each screen frame's own origin.
local function dock()
	local screen = gui
	local root = rootFrame
	local chip = visibleChip()
	if screen == nil or root == nil or chip == nil or chip.AbsoluteSize.Y <= 0 then
		return
	end
	local origin = screen.AbsolutePosition
	local right = chip.AbsolutePosition.X + chip.AbsoluteSize.X - origin.X
	local top = restingBottom(chip) - origin.Y + DOCK_GAP
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.fromOffset(math.floor(right + 0.5), math.floor(top + 0.5))

	local reveal = revealGui
	local revealRows = revealList
	local authored = revealListPosition
	local button = tab
	if reveal == nil or revealRows == nil or authored == nil or button == nil then
		return
	end
	local revealOrigin = reveal.AbsolutePosition
	local revealHeight = reveal.AbsoluteSize.Y
	local naturalTop = authored.Y.Scale * revealHeight + authored.Y.Offset
	-- The tab's bottom, from where it is docked now (its UIScale shrinks it on short screens).
	local tabScale = rootScale
	local tabHeight = button.AbsoluteSize.Y
	if tabHeight <= 0 then
		tabHeight = button.Size.Y.Offset * (if tabScale ~= nil then tabScale.Scale else 1)
	end
	local tabBottom = origin.Y + top + tabHeight - revealOrigin.Y
	local wanted = math.max(naturalTop, tabBottom + DOCK_GAP)
	revealRows.Position = UDim2.new(authored.X.Scale, authored.X.Offset, 0, math.floor(wanted + 0.5))
end

local function refreshVisibility()
	local screen = gui
	if screen == nil then
		return
	end
	-- Always up, except behind the open shop window, which it would poke into.
	local shop = shopPanel
	screen.Visible = not (shop ~= nil and shop.Visible)
	local empty = emptyLabel
	if empty ~= nil then
		empty.Visible = next(entries) == nil
	end
	-- The open list would sit over the Reveal list, so it waits until the reveal is done.
	local open = (expanded or peeking) and not revealShowing()
	local panel = list
	if panel ~= nil and panel.Visible ~= open then
		if open then
			Ui.appear(panel)
		else
			panel.Visible = false
		end
	end
	local arrowLabel = arrow
	if arrowLabel ~= nil then
		arrowLabel.Text = if open then "▾" else "▸"
	end
	local pin = pinButton
	if pin ~= nil then
		pin.BackgroundColor3 = if pinned then Theme.Color.Yellow else Theme.Color.White
		pin.BackgroundTransparency = if pinned then 0 else 0.8
		pin.TextColor3 = if pinned then Theme.Outline else Theme.Color.White
	end
end

local function fitScreen()
	local scale = rootScale
	local camera = workspace.CurrentCamera
	if scale == nil or camera == nil then
		return
	end
	scale.Scale = math.clamp(camera.ViewportSize.Y / REFERENCE_HEIGHT, MIN_SCALE, 1)
end

-- Rows -------------------------------------------------------------------------------------------------

local function childOf(parent: Instance, name: string, className: string): any
	local child = parent:FindFirstChild(name)
	if child ~= nil and child:IsA(className) then
		return child
	end
	return nil
end

local function makeRow(userId: number): Row?
	local template = rowTemplate
	local panel = list
	if template == nil or panel == nil then
		return nil
	end
	local frame = template:Clone()
	frame.Name = "Row" .. userId
	local badge: Frame? = childOf(frame, "Rank", "Frame")
	local heightLabel: TextLabel? = childOf(frame, "Height", "TextLabel")
	local value = Instance.new("NumberValue")
	value.Name = "ShownHeight"
	value.Parent = frame
	value.Changed:Connect(function(current)
		if heightLabel ~= nil and entries[userId] ~= nil and entries[userId].alive then
			heightLabel.Text = string.format("%.1f", current)
		end
	end)
	local row: Row = {
		frame = frame,
		border = childOf(frame, "Border", "UIStroke"),
		badge = badge,
		rank = if badge ~= nil then childOf(badge, "Text", "TextLabel") else nil,
		tierBar = childOf(frame, "Tier", "Frame"),
		name = childOf(frame, "Name", "TextLabel"),
		lock = childOf(frame, "Lock", "Frame"),
		height = heightLabel,
		value = value,
		shown = nil,
		wasLocked = false,
	}
	frame.Parent = panel
	return row
end

local function paintRow(row: Row, entry: Entry, index: number, isNew: boolean)
	local me = entry.userId == Players.LocalPlayer.UserId
	row.frame.LayoutOrder = index
	row.frame.BackgroundColor3 = if me then Theme.Header.You:Lerp(ROW_FILL, 0.55) else ROW_FILL
	local border = row.border
	if border ~= nil then
		border.Color = if me then Theme.Header.You else Theme.Outline
		border.Transparency = if me then 0 else 0.4
	end

	local medal = if entry.alive then MEDALS[index] else nil
	local badge = row.badge
	if badge ~= nil then
		badge.BackgroundColor3 = medal or PLAIN_BADGE
	end
	local rank = row.rank
	if rank ~= nil then
		rank.Text = tostring(index)
		rank.TextColor3 = if medal ~= nil then Theme.Outline else Theme.Color.White
	end
	local tierBar = row.tierBar
	if tierBar ~= nil then
		tierBar.BackgroundColor3 = if entry.revealed then Ui.tierColor(entry.tier) else PLAIN_BADGE
	end

	local name = row.name
	if name ~= nil then
		local text = escape(string.upper(nameFor(entry.userId)))
		if entry.userId < 0 then
			text ..= ' <font size="11" color="#9AA5B1">BOT</font>'
		end
		name.Text = if entry.alive then text else "<s>" .. text .. "</s>"
		name.TextColor3 = if entry.alive then Theme.Color.White else Theme.Color.Grey
		name.TextTransparency = if entry.alive then 0 else 0.25
	end

	local lock = row.lock
	if lock ~= nil then
		local showDot = entry.alive and phase == "Prompt"
		lock.Visible = showDot
		lock.BackgroundColor3 = if entry.locked then Theme.Color.Green else PLAIN_BADGE
		if showDot and entry.locked and not row.wasLocked then
			Ui.pop(lock, 1.8)
		end
		row.wasLocked = entry.locked and showDot
	end

	local height = row.height
	if height ~= nil then
		if entry.alive then
			height.TextColor3 = Theme.Color.White
			if row.shown == nil then
				row.value.Value = entry.height
				height.Text = string.format("%.1f", entry.height)
			elseif row.shown ~= entry.height then
				Tween.play(row.value, Theme.Tween.Count, { Value = entry.height })
			end
			row.shown = entry.height
		else
			Tween.cancel(row.value)
			height.TextColor3 = SUNK_TEXT
			height.Text = "SUNK"
			row.shown = nil
		end
	end

	if isNew then
		-- Late joiners (and the first fill of a match) slot in with a small settle.
		Ui.appear(row.frame)
	else
		row.frame.Visible = true
	end
end

local function render()
	if list == nil then
		return
	end
	local order = sorted()
	local myPlace: number? = nil
	for index, entry in order do
		local row: Row? = rows[entry.userId]
		local isNew = false
		if row == nil then
			row = makeRow(entry.userId)
			if row == nil then
				return
			end
			rows[entry.userId] = row
			isNew = true
		end
		paintRow(row :: Row, entry, index, isNew)
		if entry.userId == Players.LocalPlayer.UserId and entry.alive then
			myPlace = index
		end
	end
	for userId, row in rows do
		if entries[userId] == nil then
			row.frame:Destroy()
			rows[userId] = nil
		end
	end
	local label = place
	if label ~= nil then
		label.Visible = myPlace ~= nil
		if myPlace ~= nil then
			label.Text = "#" .. myPlace
		end
	end
end

local function clearMatch()
	for _, row in rows do
		row.frame:Destroy()
	end
	rows = {}
	entries = {}
	names = {}
	sinkCount = 0
end

-- Pillar tags -------------------------------------------------------------------------------------------

-- Puts our tag just above the pillar's name tag, wherever the template places that.
local function placeAbove(tag: BillboardGui, nameTag: BillboardGui?)
	if nameTag == nil then
		tag.StudsOffsetWorldSpace = Vector3.new(0, GameConfig.Platform.Height / 2 + 8, 0)
		return
	end
	tag.Adornee = nameTag.Adornee
	tag.StudsOffset = nameTag.StudsOffset
	tag.StudsOffsetWorldSpace = nameTag.StudsOffsetWorldSpace
	tag.ExtentsOffset = nameTag.ExtentsOffset
	tag.ExtentsOffsetWorldSpace = nameTag.ExtentsOffsetWorldSpace
	tag.MaxDistance = nameTag.MaxDistance
	tag.AlwaysOnTop = nameTag.AlwaysOnTop
	local nameSize = nameTag.Size
	local tagSize = tag.Size
	if nameSize.Y.Scale == 0 and tagSize.Y.Scale == 0 and tagSize.Y.Offset > 0 then
		-- Both sized in pixels: SizeOffset stacks ours on top at any distance.
		local nameHeight = nameSize.Y.Offset
		local tagHeight = tagSize.Y.Offset
		local lift = nameTag.SizeOffset.Y * nameHeight + (nameHeight + tagHeight) / 2 + TAG_GAP
		local shiftX = nameTag.SizeOffset.X * nameSize.X.Offset / math.max(tagSize.X.Offset, 1)
		tag.SizeOffset = Vector2.new(shiftX, lift / tagHeight)
	else
		tag.StudsOffset = nameTag.StudsOffset + Vector3.new(0, TAG_STUDS, 0)
	end
end

local function tagFor(platform: BasePart): Tag?
	local existing = tags[platform]
	if existing ~= nil then
		return existing
	end
	local nameTag = nameTagOf(platform)
	local authored = if nameTag ~= nil then nameTag:FindFirstChild("AnswerText") else nil
	if authored ~= nil and authored:IsA("TextLabel") then
		local tag: Tag = { label = authored, billboard = nil, border = nil }
		tags[platform] = tag
		return tag
	end
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local template = if templates ~= nil then templates:FindFirstChild("AnswerTag") else nil
	if template == nil or not template:IsA("BillboardGui") then
		return nil
	end
	local clone = template:Clone()
	local pill = clone:FindFirstChild("Pill")
	local label = if pill ~= nil then pill:FindFirstChild("AnswerText") else nil
	if label == nil or not label:IsA("TextLabel") then
		clone:Destroy()
		return nil
	end
	clone.Enabled = false
	placeAbove(clone, nameTag)
	clone.Parent = platform
	Ui.bindGui(clone)
	local stroke = if pill ~= nil then pill:FindFirstChild("Border") else nil
	local tag: Tag = {
		label = label,
		billboard = clone,
		border = if stroke ~= nil and stroke:IsA("UIStroke") then stroke else nil,
	}
	tags[platform] = tag
	return tag
end

local function setTagShown(tag: Tag, shown: boolean)
	local billboard = tag.billboard
	if billboard ~= nil then
		billboard.Enabled = shown
	else
		tag.label.Visible = shown
	end
end

local function hideTags()
	revealToken += 1
	for platform, tag in tags do
		if platform.Parent == nil then
			tags[platform] = nil
		else
			setTagShown(tag, false)
		end
	end
end

local function showTags(revealRows)
	local me = Players.LocalPlayer.UserId
	for _, row in revealRows do
		local platform = if row.userId ~= me then platformFor(row.userId) else nil
		local tag = if platform ~= nil then tagFor(platform) else nil
		if tag ~= nil then
			local color = Ui.tierColor(row.tier)
			tag.label.Text = if row.answer ~= nil then string.upper(row.answer) else "NO ANSWER"
			tag.label.TextColor3 = if row.answer ~= nil then color else Theme.Color.Grey
			local border = tag.border
			if border ~= nil then
				border.Color = color
			end
			setTagShown(tag, true)
		end
	end
end

-- Your own name tag sits right over your head from the default camera, so it is hidden for you only.
local function hideOwnNameTag()
	local platform = platformFor(Players.LocalPlayer.UserId)
	local nameTag = if platform ~= nil then nameTagOf(platform) else nil
	if nameTag ~= nil and nameTag.Enabled then
		nameTag.Enabled = false
	end
end

-- Binding -----------------------------------------------------------------------------------------------

local function bindReveal(playerGui: PlayerGui)
	local found = Ui.screen(playerGui, "Reveal", WAIT_SECONDS)
	if found == nil or not found:IsA("Frame") then
		return
	end
	revealGui = found
	found:GetPropertyChangedSignal("Visible"):Connect(refreshVisibility)
	local revealRows = found:FindFirstChild("List")
	if revealRows ~= nil and revealRows:IsA("GuiObject") then
		revealList = revealRows
		revealListPosition = revealRows.Position
		revealRows:GetPropertyChangedSignal("Visible"):Connect(refreshVisibility)
	end
	refreshVisibility()
	dock()
end

-- Finds both Shells chips and re-docks whenever either one shows, hides or the screen changes size.
local function bindDock(playerGui: PlayerGui)
	local function later()
		task.defer(dock)
	end
	local hud = Ui.screen(playerGui, "Hud", WAIT_SECONDS)
	local coin = if hud ~= nil then hud:WaitForChild("CoinChip", WAIT_SECONDS) else nil
	if hud ~= nil and hud:IsA("Frame") and coin ~= nil and coin:IsA("GuiObject") then
		hudGui = hud
		hudChip = coin
		hud:GetPropertyChangedSignal("Visible"):Connect(later)
		coin:GetPropertyChangedSignal("Visible"):Connect(later)
		hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(later)
	end
	local wallet = Ui.screen(playerGui, "Wallet", WAIT_SECONDS)
	local own = if wallet ~= nil then wallet:WaitForChild("Chip", WAIT_SECONDS) else nil
	if wallet ~= nil and wallet:IsA("Frame") and own ~= nil and own:IsA("GuiObject") then
		walletGui = wallet
		walletChip = own
		wallet:GetPropertyChangedSignal("Visible"):Connect(later)
		own:GetPropertyChangedSignal("Visible"):Connect(later)
		own:GetPropertyChangedSignal("Position"):Connect(later)
	end
	later()
	-- The shop is bound by ShopUi; this only watches whether its window is open.
	local shop = Ui.screen(playerGui, "Shop", WAIT_SECONDS)
	local panel = if shop ~= nil then shop:WaitForChild("Panel", WAIT_SECONDS) else nil
	if panel ~= nil and panel:IsA("GuiObject") then
		shopPanel = panel
		panel:GetPropertyChangedSignal("Visible"):Connect(refreshVisibility)
		refreshVisibility()
	end
end

local function bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		-- processed is true while typing in the answer box, so a Q in an answer never opens the list.
		if processed or input.KeyCode ~= PEEK_KEY then
			return
		end
		peeking = true
		refreshVisibility()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode ~= PEEK_KEY or not peeking then
			return
		end
		peeking = false
		refreshVisibility()
	end)
end

function Standings.init(playerGui: PlayerGui)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Standings", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Standings: StarterGui.Standings is missing; the standings tab stays hidden")
			return
		end
		local root = found:WaitForChild("Root", WAIT_SECONDS)
		if root == nil then
			warn("Standings: Standings.Root is missing; the standings tab stays hidden")
			return
		end
		rootScale = root:FindFirstChildOfClass("UIScale")
		local tabButton: TextButton? = childOf(root, "Tab", "TextButton")
		local panel: Frame? = childOf(root, "List", "Frame")
		if tabButton == nil or panel == nil then
			warn("Standings: Standings.Root needs a Tab button and a List frame")
			return
		end
		gui = found
		tab = tabButton
		list = panel
		if root:IsA("GuiObject") then
			rootFrame = root
		end
		emptyLabel = childOf(panel, "Empty", "TextLabel")
		arrow = childOf(tabButton, "Arrow", "TextLabel")
		place = childOf(tabButton, "Place", "TextLabel")
		rowTemplate = childOf(panel, "RowTemplate", "Frame")
		local header = panel:FindFirstChild("Header")
		pinButton = if header ~= nil then childOf(header, "Pin", "TextButton") else nil

		local keyHint: TextLabel? = childOf(tabButton, "KeyHint", "TextLabel")
		if keyHint ~= nil then
			keyHint.Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
		end

		Ui.pressable(tabButton)
		tabButton.Activated:Connect(function()
			expanded = not (expanded or peeking)
			if not expanded then
				pinned = false
			end
			peeking = false
			Sfx.play("Tick", 0.3)
			refreshVisibility()
		end)
		local pin = pinButton
		if pin ~= nil then
			Ui.pressable(pin)
			pin.Activated:Connect(function()
				pinned = not pinned
				expanded = true
				Sfx.play("Tick", 0.3, if pinned then 1.2 else 0.9)
				refreshVisibility()
			end)
		end

		local camera = workspace.CurrentCamera
		if camera ~= nil then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				fitScreen()
				task.defer(dock)
			end)
		end
		fitScreen()
		bindInput()
		task.spawn(bindReveal, playerGui)
		task.spawn(bindDock, playerGui)
		render()
		refreshVisibility()
	end)
end

-- RoundState payload: heights, aliveUserIds, lockedUserIds.
function Standings.onState(payload)
	local previous = phase
	phase = payload.phase

	if phase == "Waiting" or phase == "Intermission" then
		-- The tab stays up in the lobby with the last match's standings; the next match clears them.
		if next(entries) ~= nil then
			stale = true
		end
		hideTags()
		render()
		refreshVisibility()
		dock()
		return
	end

	if MATCH_PHASES[phase] then
		if stale then
			stale = false
			clearMatch()
		end
		local alive: { [number]: boolean } = {}
		for _, userId in payload.aliveUserIds or {} do
			alive[userId] = true
		end
		local locked: { [number]: boolean } = {}
		for _, userId in payload.lockedUserIds or {} do
			locked[userId] = true
		end
		local heights = payload.heights or {}
		for userId in alive do
			local entry: Entry? = entries[userId]
			if entry == nil then
				entry = {
					userId = userId,
					alive = true,
					height = 0,
					locked = false,
					tier = nil,
					revealed = false,
					sunkAt = 0,
				}
				entries[userId] = entry
			end
			local current = entry :: Entry
			current.alive = true
			current.height = heights[tostring(userId)] or current.height
			current.locked = locked[userId] == true
		end
		for userId, entry in entries do
			if entry.alive and not alive[userId] then
				entry.alive = false
				entry.locked = false
				sinkCount += 1
				entry.sunkAt = sinkCount
			end
		end
		hideOwnNameTag()
	end

	if phase == "Prompt" and previous ~= "Prompt" then
		-- A new question: clear the screen centre and the pillar tags.
		if not pinned then
			expanded = false
		end
		hideTags()
	elseif not MATCH_PHASES[phase] then
		hideTags()
	end

	render()
	refreshVisibility()
	dock()
end

-- Reveal payload: names and answers for the pillar tags.
function Standings.onReveal(payload)
	local revealRows = payload.rows or {}
	for _, row in revealRows do
		names[row.userId] = row.name
		local entry = entries[row.userId]
		if entry ~= nil then
			entry.tier = row.tier
			entry.revealed = true
			if row.height ~= nil then
				entry.height = row.height
			end
		end
	end
	render()
	-- The answer tags appear as the pillars start to rise, after the dive cards have landed.
	revealToken += 1
	local token = revealToken
	task.delay(GameConfig.Reveal.RaiseDelaySeconds, function()
		if token ~= revealToken or (phase ~= "Reveal" and phase ~= "Surge") then
			return
		end
		showTags(revealRows)
	end)
end

return Standings
