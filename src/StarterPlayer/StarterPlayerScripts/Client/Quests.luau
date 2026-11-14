--!strict
-- Draws the Quests page of the REWARDS window (LobbyUi.Rewards; Client/Rewards owns the window and its tabs):
-- today's three daily quests as chunky cards (icon, chunky progress bar, gold reward chip, a check when done),
-- plus the tab badge "x/3" while any quest is unfinished. The list is drawn here from Shared/Quests with the
-- same (userId, UTC day) seed the server uses; the profile only carries progress, so a new day needs no message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local QuestRules = require(ReplicatedStorage.Shared.Quests)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Icons = require(script.Parent.Icons)
local Rewards = require(script.Parent.Rewards)
local Ui = require(script.Parent.Ui)

local PAGE = "Quests" -- this controller's tab and page in the REWARDS window
local ROWS = 3
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

local footer: TextLabel? = nil
local empty: TextLabel? = nil
local rows: { [number]: Row } = {}

local saved: QuestDay? = nil -- profile.quests from the last ProfileChanged; nil until the first one
local shownDay = -1
local lastDone: { [string]: boolean } = {}

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

-- Redraws the rows and the tab badge. `animate` slides the bars and pops new checks (page showing).
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
	-- The badge waits for the profile, so it never flashes "0/3" for someone who is already done. It goes
	-- once every quest is done: a plain open of the window lands on this tab only while it carries a badge.
	if saved ~= nil then
		local total = math.min(#list, ROWS)
		Rewards.setTabBadge(PAGE, if doneCount < total then `{doneCount}/{total}` else nil)
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

local function bind(page: GuiObject)
	footer = textChild(page, "Footer")
	empty = textChild(page, "Empty")
	for index = 1, ROWS do
		local row = page:FindFirstChild("Row" .. index)
		if row ~= nil and row:IsA("GuiObject") then
			rows[index] = bindRow(row)
		end
	end
	render(false)
end

function Quests.init()
	Rewards.onShow(PAGE, function()
		render(false)
	end)
	task.spawn(function()
		local page = Rewards.page(PAGE)
		if page == nil then
			warn("Quests: LobbyUi.Rewards has no Quests page; the quests are not shown")
			return
		end
		bind(page)
	end)
	-- The countdown ticks while the page is showing, and the list redraws itself at UTC midnight.
	task.spawn(function()
		while true do
			task.wait(1)
			if QuestRules.day(now()) ~= shownDay then
				render(Rewards.isOpen(PAGE))
			elseif Rewards.isOpen(PAGE) then
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
	render(Rewards.isOpen(PAGE))
end

return Quests
