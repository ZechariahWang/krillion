--!strict
-- Drives StarterGui.Quests: a big centred panel with today's three daily quests as chunky cards (icon, chunky
-- progress bar, gold reward chip, a check when done), opened from the rail's QUESTS key (lobby only), plus the
-- rail badge "x/3". The list is drawn here from Shared/Quests with the same (userId, UTC day) seed the server
-- uses; the profile only carries progress, so a new day needs no message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local QuestRules = require(ReplicatedStorage.Shared.Quests)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Icons = require(script.Parent.Icons)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local ROWS = 3
local MARGIN = 16 -- pixels kept clear around the panel when it is scaled down for a small screen
local MIN_FIT = 0.4
local PORTRAIT_BELOW = 0.7 -- the wide layout shows smaller than this: use the tall phone one if it shows bigger
local PORTRAIT_SIZE = UDim2.fromOffset(460, 656)
local PORTRAIT_ROW = 152 -- a portrait card puts its reward chip under the progress bar
local PORTRAIT_ROW_GAP = 12
local ROWS_TOP = 104
local BADGE = "QuestsButton"
local BAR_COLOR = Color3.fromRGB(164, 123, 255)
local DONE_COLOR = Color3.fromRGB(122, 220, 72)
local DEFAULT_ICON = "Quest"
-- Each quest's card icon (a name in Templates.Icons), by the event that advances it.
local KIND_ICONS: { [string]: string } = {
	match_played = "Controller",
	round_survived = "Wave",
	rare_answer = "Gem",
	deep_answer = "Octopus",
	practice_answer = "Pencil",
	play_seconds = "Time",
	match_won = "Trophy",
}

type QuestDay = { day: number, progress: { [string]: number }, done: { [string]: boolean } }

type Row = {
	frame: GuiObject,
	icon: ImageLabel?,
	text: TextLabel?,
	reward: TextLabel?,
	fill: Frame?,
	count: TextLabel?,
	check: ImageLabel?,
}

local player = Players.LocalPlayer

local gui: Frame? = nil
local panel: GuiObject? = nil
local fit: UIScale? = nil
local layout: Ui.PhoneLayout? = nil
local footer: TextLabel? = nil
local empty: TextLabel? = nil
local rows: { [number]: Row } = {}

local saved: QuestDay? = nil -- profile.quests from the last ProfileChanged; nil until the first one
local shownDay = -1
local lastDone: { [string]: boolean } = {}
local isOpen = false
local playing = false

local Quests = {}

-- UTC seconds from the server's clock, so the day and countdown match the server's even on a skewed PC.
local function now(): number
	return workspace:GetServerTimeNow()
end

local function progressOf(day: number, id: string): (number, boolean)
	local quests = saved
	if quests == nil or quests.day ~= day then
		return 0, false
	end
	return quests.progress[id] or 0, quests.done[id] == true
end

local function updateFooter()
	local label = footer
	if label ~= nil then
		label.Text = "NEW QUESTS IN " .. QuestRules.resetText(QuestRules.secondsLeft(now()))
	end
end

local function fillRow(row: Row, quest: QuestRules.Quest, day: number, animate: boolean): boolean
	local progress, done = progressOf(day, quest.id)
	if done then
		progress = quest.goal
	end
	local text = row.text
	if text ~= nil then
		text.Text = quest.text
	end
	local icon = row.icon
	if icon ~= nil then
		icon.Image = Icons.image(KIND_ICONS[quest.kind] or DEFAULT_ICON)
	end
	local reward = row.reward
	if reward ~= nil then
		reward.Text = `+{quest.reward}`
	end
	local count = row.count
	if count ~= nil then
		count.Text = QuestRules.progressText(quest, progress)
		count.Visible = not done
	end
	local fill = row.fill
	if fill ~= nil then
		local goal = UDim2.fromScale(math.clamp(progress / quest.goal, 0, 1), 1)
		fill.BackgroundColor3 = if done then DONE_COLOR else BAR_COLOR
		if animate then
			Tween.play(fill, Theme.Tween.Count, { Size = goal })
		else
			Tween.cancel(fill)
			fill.Size = goal
		end
	end
	local check = row.check
	if check ~= nil then
		if done and animate and not lastDone[quest.id] then
			Ui.pop(check, 0.6)
		else
			check.Visible = done
		end
	end
	return done
end

-- Redraws the rows and the rail badge. `animate` slides the bars and pops new checks (panel open).
local function render(animate: boolean)
	local day = QuestRules.day(now())
	shownDay = day
	local list = QuestRules.draw(player.UserId, day)
	local doneCount = 0
	local nowDone: { [string]: boolean } = {}
	for index = 1, ROWS do
		local row = rows[index]
		local quest = list[index]
		if row ~= nil then
			row.frame.Visible = quest ~= nil
		end
		if quest ~= nil then
			local done: boolean
			if row ~= nil then
				done = fillRow(row, quest, day, animate)
			else
				local _, savedDone = progressOf(day, quest.id)
				done = savedDone
			end
			if done then
				doneCount += 1
				nowDone[quest.id] = true
			end
		end
	end
	lastDone = nowDone
	if empty ~= nil then
		empty.Visible = #list == 0
	end
	updateFooter()
	-- The badge waits for the profile, so it never flashes "0/3" for someone who is already done.
	if saved ~= nil then
		Rail.setBadge(BADGE, if #list > 0 then `{doneCount}/{math.min(#list, ROWS)}` else nil)
	end
end

-- Shrinks the panel on small screens instead of letting it run off the edge; a portrait phone gets the tall
-- layout so the counts and rewards stay readable.
local function fitToScreen()
	local screen = gui
	local frame = panel
	local scale = fit
	if screen == nil or frame == nil or scale == nil then
		return
	end
	Ui.fitPanel(screen.AbsoluteSize, frame, scale, layout, MARGIN, MIN_FIT, PORTRAIT_BELOW)
end

-- Portrait phone layout: narrow and tall cards, the reward chip and check under the progress bar.
local function portraitOverrides(): Ui.Overrides
	local overrides: Ui.Overrides = {
		Empty = { Size = UDim2.new(1, -60, 0, ROWS * PORTRAIT_ROW + (ROWS - 1) * PORTRAIT_ROW_GAP) },
		Footer = {
			Position = UDim2.new(0.5, 0, 0, ROWS_TOP + ROWS * PORTRAIT_ROW + (ROWS - 1) * PORTRAIT_ROW_GAP + 14),
		},
	}
	for index = 1, ROWS do
		local path = "Row" .. index
		overrides[path] = {
			Size = UDim2.new(1, -48, 0, PORTRAIT_ROW),
			Position = UDim2.fromOffset(24, ROWS_TOP + (index - 1) * (PORTRAIT_ROW + PORTRAIT_ROW_GAP)),
		}
		overrides[path .. "/IconBack"] = { Size = UDim2.fromOffset(76, 76) }
		overrides[path .. "/Text"] = { Position = UDim2.fromOffset(108, 12), Size = UDim2.new(1, -124, 0, 36) }
		overrides[path .. "/Track"] = { Position = UDim2.fromOffset(108, 56), Size = UDim2.new(1, -124, 0, 32) }
		overrides[path .. "/RewardChip"] = { Position = UDim2.fromOffset(108, 98), AnchorPoint = Vector2.zero }
		overrides[path .. "/Check"] = { Position = UDim2.fromOffset(278, 121) }
	end
	return overrides
end

local function close()
	local screen = gui
	if screen == nil or not isOpen then
		return
	end
	isOpen = false
	screen.Visible = false
	Windows.closed(close)
end

-- Opens the panel. Never over a pillar: the match comes first.
function Quests.open()
	local screen = gui
	if screen == nil or playing or player:GetAttribute("Playing") == true then
		return
	end
	render(false)
	fitToScreen()
	screen.Visible = true
	if not isOpen then
		isOpen = true
		Sfx.play("Open", 0.5)
		local frame = panel
		if frame ~= nil then
			Ui.pop(frame, 0.7)
		end
	end
	Windows.opened(close)
end

local function toggle()
	if isOpen then
		Sfx.play("Close", 0.5)
		close()
	else
		Quests.open()
	end
end

local function textChild(parent: Instance?, name: string): TextLabel?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("TextLabel") then found else nil
end

local function imageChild(parent: Instance?, name: string): ImageLabel?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("ImageLabel") then found else nil
end

-- Row children: IconBack.Icon, Text, RewardChip.Reward, Track.Fill, Track.Count, Check.
local function bindRow(frame: GuiObject): Row
	local track = frame:FindFirstChild("Track")
	local fill = if track ~= nil then track:FindFirstChild("Fill") else nil
	return {
		frame = frame,
		icon = imageChild(frame:FindFirstChild("IconBack"), "Icon"),
		text = textChild(frame, "Text"),
		reward = textChild(frame:FindFirstChild("RewardChip"), "Reward") or textChild(frame, "Reward"),
		fill = if fill ~= nil and fill:IsA("Frame") then fill else nil,
		count = textChild(track, "Count") or textChild(frame, "Count"),
		check = imageChild(frame, "Check"),
	}
end

local function bind(screen: Frame, playerGui: PlayerGui)
	local holder = screen:WaitForChild("Holder", WAIT_SECONDS)
	local frame = if holder ~= nil then holder:WaitForChild("Panel", WAIT_SECONDS) else nil
	if holder == nil or frame == nil or not frame:IsA("GuiObject") then
		warn("Quests: StarterGui.Quests.Holder.Panel is missing; the quests panel stays closed")
		return
	end
	panel = frame
	local scale = holder:FindFirstChild("Fit")
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	footer = textChild(frame, "Footer")
	empty = textChild(frame, "Empty")
	layout = Ui.phoneLayout(frame, PORTRAIT_SIZE, portraitOverrides())
	for index = 1, ROWS do
		local row = frame:FindFirstChild("Row" .. index)
		if row ~= nil and row:IsA("GuiObject") then
			rows[index] = bindRow(row)
		end
	end
	local closeButton = frame:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("TextButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			close()
		end)
	end
	local railButton = Rail.button(BADGE)
	if railButton ~= nil then
		railButton.Activated:Connect(toggle)
	else
		warn("Quests: the rail has no QuestsButton; the quests panel cannot be opened")
	end
	-- Tapping outside the panel closes it.
	local scrim = screen:FindFirstChild("Scrim")
	if scrim ~= nil and scrim:IsA("GuiButton") then
		scrim.Activated:Connect(close)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	gui = screen
	render(false)
end

function Quests.init(playerGui: PlayerGui)
	player:GetAttributeChangedSignal("Playing"):Connect(function()
		if player:GetAttribute("Playing") == true then
			close()
		end
	end)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Quests", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Quests: StarterGui.Quests is missing; the quests panel stays closed")
			return
		end
		bind(found, playerGui)
	end)
	-- The countdown ticks while the panel is open, and the list redraws itself at UTC midnight.
	task.spawn(function()
		while true do
			task.wait(1)
			if QuestRules.day(now()) ~= shownDay then
				render(isOpen)
			elseif isOpen then
				updateFooter()
			end
		end
	end)
end

-- ProfileChanged payload: profile.quests {day, progress, done}.
function Quests.onProfile(profile)
	local quests = if type(profile) == "table" then profile.quests else nil
	if type(quests) ~= "table" or type(quests.day) ~= "number" then
		return
	end
	local progress: { [string]: number } = {}
	if type(quests.progress) == "table" then
		for id, amount in quests.progress do
			if type(id) == "string" and type(amount) == "number" then
				progress[id] = amount
			end
		end
	end
	local done: { [string]: boolean } = {}
	if type(quests.done) == "table" then
		for id, flag in quests.done do
			if type(id) == "string" and flag == true then
				done[id] = true
			end
		end
	end
	saved = { day = quests.day, progress = progress, done = done }
	render(isOpen)
end

function Quests.onState(payload)
	playing = type(payload) == "table" and payload.playing == true
	if playing then
		close()
	end
end

return Quests
