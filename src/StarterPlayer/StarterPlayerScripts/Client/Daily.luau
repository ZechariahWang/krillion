--!strict
-- Drives LobbyUi.Daily: the daily reward window (authored in Studio). Seven day cards show the week: the
-- days already claimed carry a check, today's is lit, the rest wait. CLAIM asks the server (DailyClaim);
-- the claim lives in the profile (profile.daily), so the window only draws what the server last said.
-- Opened from the rail's DAILY key, which carries a "!" badge while a reward is waiting, and once by
-- itself on the first lobby visit of a session when there is something to claim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Rules = require(ReplicatedStorage.Shared.Daily)
local Net = require(ReplicatedStorage.Shared.Net)
local ChestReveal = require(script.Parent.ChestReveal)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local MARGIN = 16 -- pixels kept clear around the panel when it is scaled down for a small screen
local MIN_FIT = 0.4
local BADGE = "DailyButton"
local AUTO_OPEN_SECONDS = 2 -- how long after the lobby settles the window opens by itself
local CLAIM_TIMEOUT = 6 -- a claim with no answer by then can be pressed again
local WAITING_TRANSPARENCY = 0.45 -- a day not reached yet is dimmed this much

type Card = {
	frame: GuiObject,
	amount: TextLabel?,
	bonus: GuiObject?,
	check: GuiObject?,
	today: GuiObject?,
	dim: GuiObject?,
}

local player = Players.LocalPlayer

local gui: Frame? = nil
local panel: GuiObject? = nil
local fit: UIScale? = nil
local claimButton: TextButton? = nil
local claimLabel: TextLabel? = nil -- the button's authored caption
local footer: TextLabel? = nil
local cards: { [number]: Card } = {}

local saved: Rules.State? = nil -- profile.daily from the last ProfileChanged; nil until the first one
local tutorialDone = false
local isOpen = false
local playing = false
local autoShown = false
local pendingSince: number? = nil -- a claim is with the server

local Daily = {}

-- UTC seconds from the server's clock, so the day matches the server's even on a skewed PC.
local function now(): number
	return workspace:GetServerTimeNow()
end

local function claimable(): boolean
	local state = saved
	if state == nil or GameConfig.Daily.Enabled ~= 1 then
		return false
	end
	return Rules.canClaim(state, Rules.today(now()))
end

local function clock(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local rest = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, rest)
end

local function updateFooter()
	local label = footer
	if label == nil then
		return
	end
	if claimable() then
		label.Text = "TODAY'S REWARD IS READY"
	else
		label.Text = "NEXT REWARD IN " .. clock(Rules.secondsLeft(now()))
	end
end

-- Draws the week from the saved claim: checks on the days of this streak already claimed, today's lit.
local function render()
	local state = saved
	if state == nil then
		return
	end
	local today = Rules.today(now())
	local shown = Rules.shownIndex(state, today)
	local claimedToday = state.day == today
	-- The streak only counts while it is unbroken: after a missed day nothing is checked.
	local kept = state.day >= today - 1
	for index, card in cards do
		local reward = Rules.reward(index)
		local done = kept and index <= state.streak and (claimedToday or index < shown)
		if card.amount ~= nil then
			card.amount.Text = "+" .. reward.shells
		end
		if card.bonus ~= nil then
			card.bonus.Visible = reward.chest ~= nil
		end
		if card.check ~= nil then
			card.check.Visible = done
		end
		if card.today ~= nil then
			card.today.Visible = index == shown
		end
		if card.dim ~= nil then
			card.dim.Visible = not done and index ~= shown
			card.dim.BackgroundTransparency = WAITING_TRANSPARENCY
		end
	end
	local button = claimButton
	if button ~= nil then
		local ready = claimable() and pendingSince == nil
		local label = claimLabel
		if label ~= nil then
			label.Text = if claimable() then "CLAIM DAY " .. shown else "CLAIMED"
		end
		button.Active = ready
		button.AutoButtonColor = ready
		button.BackgroundTransparency = if ready then 0 else 0.6
	end
	updateFooter()
	Rail.setBadge(BADGE, if claimable() then "!" else nil)
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

local function close()
	local screen = gui
	if screen == nil or not isOpen then
		return
	end
	isOpen = false
	screen.Visible = false
	Windows.closed(close)
end

-- Opens the window. Never over a pillar: the match comes first.
function Daily.open()
	local screen = gui
	if screen == nil or playing or player:GetAttribute("Playing") == true then
		return
	end
	render()
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
		Daily.open()
	end
end

local function claim()
	local state = saved
	if state == nil or not claimable() then
		return
	end
	local since = pendingSince
	if since ~= nil and os.clock() - since < CLAIM_TIMEOUT then
		return
	end
	pendingSince = os.clock()
	render()
	local reward = Rules.reward(Rules.nextIndex(state, Rules.today(now())))
	if reward.chest ~= nil then
		-- The chest opens with the full reveal; the claim itself is what makes the server roll it.
		close()
		ChestReveal.open(reward.chest, function()
			Net.event("DailyClaim"):FireServer()
		end)
	else
		Net.event("DailyClaim"):FireServer()
	end
end

-- DailyResult: the Shells arrive with the profile; this is the sound and the window closing on a claim.
function Daily.onResult(payload: Net.DailyResultPayload)
	pendingSince = nil
	if type(payload) == "table" and payload.status == "ok" then
		Sfx.play("Fanfare", 0.6)
		close()
	end
	render()
end

local function tryAutoOpen()
	if autoShown or gui == nil or playing or not tutorialDone or not claimable() or Windows.anyOpen() then
		return
	end
	autoShown = true
	Daily.open()
end

local function child(parent: Instance?, name: string): GuiObject?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("GuiObject") then found else nil
end

local function textChild(parent: Instance?, name: string): TextLabel?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("TextLabel") then found else nil
end

local function bind(screen: Frame)
	local holder = screen:FindFirstChild("Holder")
	local frame = child(holder, "Panel")
	local scale = if holder ~= nil then holder:FindFirstChild("Fit") else nil
	local days = child(frame, "Days")
	local button = if frame ~= nil then frame:FindFirstChild("ClaimButton") else nil
	if frame == nil or days == nil or button == nil or not button:IsA("TextButton") then
		warn("Daily: LobbyUi.Daily is missing Holder.Panel, Days or ClaimButton; no daily reward window")
		return
	end
	panel = frame
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	claimButton = button
	claimLabel = textChild(button, "Label")
	footer = textChild(frame, "Footer")
	for index = 1, #GameConfig.Daily.Days do
		local card = child(days, "Day" .. index)
		if card ~= nil then
			cards[index] = {
				frame = card,
				amount = textChild(card, "Amount"),
				bonus = child(card, "Bonus"),
				check = child(card, "Check"),
				today = child(card, "Today"),
				dim = child(card, "Dim"),
			}
		end
	end
	Ui.pressable(button)
	button.Activated:Connect(claim)
	local closeButton = frame:FindFirstChild("CloseButton")
	if closeButton ~= nil and closeButton:IsA("GuiButton") then
		Ui.pressable(closeButton)
		closeButton.Activated:Connect(function()
			Sfx.play("Close", 0.5)
			close()
		end)
	end
	local scrim = screen:FindFirstChild("Scrim")
	if scrim ~= nil and scrim:IsA("GuiButton") then
		scrim.Activated:Connect(close)
	end
	local railButton = Rail.button(BADGE)
	if railButton ~= nil then
		railButton.Activated:Connect(toggle)
	else
		warn("Daily: the rail has no DailyButton; the daily window only opens by itself")
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
	screen.Visible = false
	gui = screen
	render()
end

function Daily.init(playerGui: PlayerGui)
	player:GetAttributeChangedSignal("Playing"):Connect(function()
		if player:GetAttribute("Playing") == true then
			close()
		end
	end)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Daily", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Daily: LobbyUi.Daily is missing; no daily reward window")
			return
		end
		bind(found)
	end)
	-- The countdown ticks while the window is open; the week redraws itself at UTC midnight.
	task.spawn(function()
		local shownDay = -1
		while true do
			task.wait(1)
			local today = Rules.today(now())
			if today ~= shownDay then
				shownDay = today
				render()
			elseif isOpen then
				updateFooter()
			end
		end
	end)
end

-- ProfileChanged payload: profile.daily {day, streak}.
function Daily.onProfile(profile)
	if type(profile) ~= "table" then
		return
	end
	tutorialDone = profile.tutorialDone == true
	local daily = profile.daily
	if type(daily) ~= "table" or type(daily.day) ~= "number" or type(daily.streak) ~= "number" then
		return
	end
	-- A profile that failed to load cannot be claimed against: the window stays quiet until the real one.
	if profile.loadFailed == true then
		saved = nil
		Rail.setBadge(BADGE, nil)
		return
	end
	local first = saved == nil
	saved = { day = daily.day, streak = daily.streak }
	render()
	if first then
		task.delay(AUTO_OPEN_SECONDS, tryAutoOpen)
	end
end

function Daily.onState(payload)
	local wasPlaying = playing
	playing = type(payload) == "table" and payload.playing == true
	if playing then
		close()
	elseif wasPlaying then
		-- Back in the lobby after a match: a reward still waiting gets its one automatic showing.
		task.delay(AUTO_OPEN_SECONDS, tryAutoOpen)
	end
end

return Daily
