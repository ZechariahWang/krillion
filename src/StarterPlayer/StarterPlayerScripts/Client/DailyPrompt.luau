--!strict
-- Drives LobbyUi.DailyPrompt, the Prompt of the Day window opened from the rail's TodayButton: today's prompt
-- with an answer box until you answer, then your answer, its tier and the share of players who said it so far;
-- the day streak; and yesterday's prompt with your answer's share and the top answers worldwide.
-- The server (DailyPromptService) grades, pays and sends the state (DailyPromptState). Like a match, an answer
-- that needed a typo fixed comes back as DID YOU MEAN and GO again confirms it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tiers = require(ReplicatedStorage.Config.Tiers)
local DailyPromptRules = require(ReplicatedStorage.Shared.DailyPrompt)
local Net = require(ReplicatedStorage.Shared.Net)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local MARGIN = 16
local MIN_FIT = 0.4
local RAIL_KEY = "TodayButton"
local TOP_ROWS = 5

local player = Players.LocalPlayer

local gui: Frame? = nil
local panel: Frame? = nil
local fit: UIScale? = nil
local box: TextBox? = nil
local opened = false
local state: Net.DailyPromptStatePayload? = nil
local stateAt = 0 -- os.clock() when the state arrived, for the countdown
local confirming: string? = nil -- the box text a DID YOU MEAN was shown for

local DailyPrompt = {}

local function find(name: string): GuiObject?
	local frame = panel
	if frame == nil then
		return nil
	end
	return frame:FindFirstChild(name) :: GuiObject?
end

local function setText(name: string, text: string)
	local label = find(name)
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setVisible(name: string, visible: boolean)
	local object = find(name)
	if object ~= nil then
		object.Visible = visible
	end
end

local function tierLabel(tier: string?): string
	local info = if tier ~= nil then Tiers.ByName[tier] else nil
	if info == nil then
		return ""
	end
	return string.upper(info.label)
end

local function countdownText(seconds: number): string
	local minutes = math.max(1, math.floor(seconds / 60))
	local hours = math.floor(minutes / 60)
	if hours >= 1 then
		return "NEW PROMPT IN " .. hours .. "H " .. (minutes % 60) .. "M"
	end
	return "NEW PROMPT IN " .. minutes .. "M"
end

local function secondsLeft(): number
	local current = state
	if current == nil then
		return 0
	end
	return current.secondsLeft - (os.clock() - stateAt)
end

local function renderYesterday(current: Net.DailyPromptStatePayload)
	local yesterday = current.yesterday
	local show = yesterday ~= nil
	setVisible("Rule", show)
	setVisible("YesterdayTitle", show)
	setVisible("YesterdayYou", show)
	for index = 1, TOP_ROWS do
		setVisible("Top" .. index, false)
	end
	if yesterday == nil then
		return
	end
	setText("YesterdayTitle", "YESTERDAY: " .. string.upper(yesterday.prompt))
	if yesterday.answer ~= nil then
		local line = "YOU: " .. string.upper(yesterday.answer) .. "  |  " .. tierLabel(yesterday.tier)
		if yesterday.share ~= nil then
			line ..= "  |  " .. DailyPromptRules.shareText(yesterday.share)
		end
		setText("YesterdayYou", line)
	else
		setText("YesterdayYou", "YOU DID NOT ANSWER")
	end
	if #yesterday.top == 0 then
		setText("Top1", "NO ANSWERS YET")
		setVisible("Top1", true)
		return
	end
	for index, row in yesterday.top do
		if index > TOP_ROWS then
			break
		end
		local line = index .. "   " .. string.upper(row.answer)
		if row.share ~= nil then
			line ..= "   " .. DailyPromptRules.shareText(row.share)
		end
		setText("Top" .. index, line)
		setVisible("Top" .. index, true)
	end
end

local function render()
	local current = state
	if current == nil or panel == nil then
		return
	end
	setText("PromptText", string.upper(current.prompt))
	setText("Countdown", countdownText(secondsLeft()))
	local answered = current.answered
	setVisible("AnswerBox", answered == nil)
	setVisible("GoButton", answered == nil)
	setVisible("Feedback", answered == nil)
	setVisible("ResultAnswer", answered ~= nil)
	setVisible("ResultShare", answered ~= nil)
	if answered ~= nil then
		setText("ResultAnswer", string.upper(answered.answer) .. "  |  " .. tierLabel(answered.tier))
		local result = find("ResultAnswer")
		if result ~= nil and result:IsA("TextLabel") then
			result.TextColor3 = Ui.tierColor(answered.tier)
		end
		if answered.share ~= nil then
			setText("ResultShare", "SO FAR " .. DailyPromptRules.shareText(answered.share) .. " OF PLAYERS SAID THAT")
		else
			setText("ResultShare", "NOT ENOUGH ANSWERS YET TO SHOW HOW RARE")
		end
	end
	if current.streak > 0 then
		local tail = if answered ~= nil then "CHEST IN " .. current.chestIn else "ANSWER TODAY TO KEEP IT"
		setText("Streak", "STREAK " .. current.streak .. (if current.streak == 1 then " DAY" else " DAYS") .. "  |  " .. tail)
	else
		setText("Streak", "ANSWER EVERY DAY: A CHEST EVERY " .. current.chestIn .. " DAYS")
	end
	renderYesterday(current)
end

local function updateBadge()
	local current = state
	Rail.setBadge(RAIL_KEY, if current ~= nil and current.answered == nil then "!" else nil)
end

local function fitToScreen()
	local screen = gui
	local frame = panel
	local scale = fit
	if screen == nil or frame == nil or scale == nil then
		return
	end
	Ui.fitPanel(screen.AbsoluteSize, frame, scale, nil, MARGIN, MIN_FIT, 0)
end

function DailyPrompt.close()
	local screen = gui
	if screen == nil or not opened then
		return
	end
	opened = false
	screen.Visible = false
	Windows.closed(DailyPrompt.close)
end

-- Never over a pillar: the match comes first.
function DailyPrompt.open()
	local screen = gui
	local frame = panel
	if screen == nil or frame == nil or player:GetAttribute("Playing") == true then
		return
	end
	Net.event("DailyPromptState"):FireServer()
	fitToScreen()
	render()
	screen.Visible = true
	if not opened then
		opened = true
		Sfx.play("Open", 0.5)
		Ui.pop(frame, 0.7)
	end
	Windows.opened(DailyPrompt.close)
end

local function toggle()
	if opened then
		Sfx.play("Close", 0.5)
		DailyPrompt.close()
	else
		DailyPrompt.open()
	end
end

local function submit()
	local input = box
	if input == nil then
		return
	end
	local text = input.Text
	if text == "" then
		return
	end
	Net.event("DailyPromptAnswer"):FireServer(text, confirming == text)
end

local function onState(payload: Net.DailyPromptStatePayload)
	if type(payload) ~= "table" or type(payload.prompt) ~= "string" then
		return
	end
	state = payload
	stateAt = os.clock()
	updateBadge()
	render()
end

local function onResult(payload: Net.DailyPromptResultPayload)
	if type(payload) ~= "table" then
		return
	end
	local status = payload.status
	if status == "confirm" and payload.answer ~= nil then
		confirming = if box ~= nil then box.Text else nil
		setText("Feedback", "DID YOU MEAN " .. string.upper(payload.answer) .. "?  PRESS GO AGAIN")
		Sfx.play("Tick", 0.5)
	elseif status == "invalid" then
		confirming = nil
		setText("Feedback", "NOT ON THE LIST, TRY ANOTHER")
		local input = box
		if input ~= nil then
			Ui.nudge(input)
		end
	elseif status == "ok" then
		confirming = nil
		setText("Feedback", "")
		Sfx.play("LockIn", 0.7)
	elseif status == "closed" then
		setText("Feedback", "NOT RIGHT NOW, TRY AGAIN IN THE LOBBY")
	end
end

local function bind(screen: Frame)
	local holder = screen:FindFirstChild("Holder")
	local found = if holder ~= nil then holder:FindFirstChild("Panel") else nil
	if found == nil or not found:IsA("Frame") then
		warn("DailyPrompt: LobbyUi.DailyPrompt needs Holder.Panel; the window stays closed")
		return
	end
	panel = found
	local scale = if holder ~= nil then holder:FindFirstChild("Fit") else nil
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	local input = found:FindFirstChild("AnswerBox")
	if input ~= nil and input:IsA("TextBox") then
		box = input
		input.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				submit()
			end
		end)
		input:GetPropertyChangedSignal("Text"):Connect(function()
			if confirming ~= nil and input.Text ~= confirming then
				confirming = nil
				setText("Feedback", "")
			end
		end)
	end
	local go = found:FindFirstChild("GoButton")
	if go ~= nil and go:IsA("TextButton") then
		Ui.pressable(go)
		go.Activated:Connect(submit)
	end
	local closeButton = found:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("TextButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			DailyPrompt.close()
		end)
	end
	setText("Feedback", "")
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	screen.Visible = false
	gui = screen
	render()
end

function DailyPrompt.init(playerGui: PlayerGui)
	local railButton = Rail.button(RAIL_KEY)
	if railButton ~= nil then
		railButton.Activated:Connect(toggle)
	else
		warn("DailyPrompt: the rail has no TodayButton")
	end
	player:GetAttributeChangedSignal("Playing"):Connect(function()
		if player:GetAttribute("Playing") == true then
			DailyPrompt.close()
		end
	end)
	Net.event("DailyPromptState").OnClientEvent:Connect(onState)
	Net.event("DailyPromptResult").OnClientEvent:Connect(onResult)
	Net.event("DailyPromptState"):FireServer()
	-- The countdown ticks while the window is open; at midnight UTC it asks for the new day's prompt.
	task.spawn(function()
		while true do
			task.wait(1)
			if opened then
				if state ~= nil and secondsLeft() <= 0 then
					Net.event("DailyPromptState"):FireServer()
				end
				setText("Countdown", countdownText(secondsLeft()))
			end
		end
	end)
	task.spawn(function()
		local found = Ui.screen(playerGui, "DailyPrompt", WAIT_SECONDS)
		if found ~= nil then
			bind(found)
		else
			warn("DailyPrompt: LobbyUi.DailyPrompt is missing; the window stays closed")
		end
	end)
end

return DailyPrompt
