--!strict
-- Draws the Daily page of the REWARDS window (LobbyUi.Rewards; Client/Rewards owns the window and its tabs):
-- the daily reward. Seven day cards show the week: the days already claimed carry a check, today's is lit,
-- the rest wait. CLAIM asks the server (DailyClaim); the claim lives in the profile (profile.daily), so the
-- page only draws what the server last said. Its tab carries a "!" badge while a reward is waiting, and the
-- window opens on it by itself once, on the first lobby visit of a session with something to claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Rules = require(ReplicatedStorage.Shared.Daily)
local Net = require(ReplicatedStorage.Shared.Net)
local ChestReveal = require(script.Parent.ChestReveal)
local Rewards = require(script.Parent.Rewards)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local PAGE = "Daily" -- this controller's tab and page in the REWARDS window
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

local bound = false -- the page was found and its pieces are connected
local claimButton: TextButton? = nil
local claimLabel: TextLabel? = nil -- the button's authored caption
local footer: TextLabel? = nil
local cards: { [number]: Card } = {}

local saved: Rules.State? = nil -- profile.daily from the last ProfileChanged; nil until the first one
local tutorialDone = false
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
	-- Without the page there is nothing to claim on, so the tab and the rail key stay unmarked.
	Rewards.setTabBadge(PAGE, if bound and claimable() then "!" else nil)
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
		Rewards.close()
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
		-- Only when the claim is still what the player is looking at: they may have moved to another tab.
		if Rewards.isOpen(PAGE) then
			Rewards.close()
		end
	end
	render()
end

local function tryAutoOpen()
	if autoShown or not bound or playing or not tutorialDone or not claimable() or Windows.anyOpen() then
		return
	end
	autoShown = true
	Rewards.open(PAGE)
end

local function child(parent: Instance?, name: string): GuiObject?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("GuiObject") then found else nil
end

local function textChild(parent: Instance?, name: string): TextLabel?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("TextLabel") then found else nil
end

local function bind(page: GuiObject)
	local days = child(page, "Days")
	local button = page:FindFirstChild("ClaimButton")
	if days == nil or button == nil or not button:IsA("TextButton") then
		warn("Daily: the Daily page of LobbyUi.Rewards is missing Days or ClaimButton; no daily reward")
		return
	end
	claimButton = button
	claimLabel = textChild(button, "Label")
	footer = textChild(page, "Footer")
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
	bound = true
	render()
end

function Daily.init()
	Rewards.onShow(PAGE, render)
	task.spawn(function()
		local page = Rewards.page(PAGE)
		if page == nil then
			warn("Daily: LobbyUi.Rewards has no Daily page; no daily reward")
			return
		end
		bind(page)
	end)
	-- The countdown ticks while the page is showing; the week redraws itself at UTC midnight.
	task.spawn(function()
		local shownDay = -1
		while true do
			task.wait(1)
			local today = Rules.today(now())
			if today ~= shownDay then
				shownDay = today
				render()
			elseif Rewards.isOpen(PAGE) then
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
	-- A profile that failed to load cannot be claimed against: the page stays quiet until the real one.
	if profile.loadFailed == true then
		saved = nil
		Rewards.setTabBadge(PAGE, nil)
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
	if wasPlaying and not playing then
		-- Back in the lobby after a match: a reward still waiting gets its one automatic showing.
		task.delay(AUTO_OPEN_SECONDS, tryAutoOpen)
	end
end

return Daily
