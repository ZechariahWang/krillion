--!strict
-- Drives the reveal: your own dive card slides up to fill the screen (StarterGui.DiveCards) with everyone's
-- answers sinking on it, yours lands, the view moves to the round's deepest answer, it holds a moment and
-- shrinks away before the pillars rise (GameConfig.Reveal.RaiseDelaySeconds), so you watch your pillar and
-- the water. StarterGui.Reveal's compact answer list rolls in on the right at the Surge, or straight away
-- for anyone without a card (sunk players, spectators, the lobby).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Economy = require(ReplicatedStorage.Shared.Economy)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local DiveCard = require(script.Parent.DiveCard)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

type RevealRow = Net.RevealRow

local ROW_STAGGER = 0.15
local ROW_SPREAD = 1.4 -- every row is in within this, however many players there are
local COUNT_SECONDS = 0.45
local SCHOOLED_PAUSE = 0.3
local WAIT_SECONDS = 10
local CARD_ENTER = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- the dim fades in as the card slides up
local CARD_EXIT = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local EXIT_MARGIN = 0.1 -- the card is fully gone this long before the rise starts
local MYTHIC_GLOW = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local gui: Frame
local badge: Frame
local list: Frame
local rowTemplate: Frame
local cardsGui: Frame? = nil
local stage: Frame? = nil
local backdrop: Frame? = nil
local backdropTransparency = 0.35 -- replaced by the authored Backdrop's value

local card: DiveCard.Handle? = nil
local lobbyCard = false -- the card up now is the lobby warm-up's, not this round's: state ticks leave it alone
local pendingRows: { RevealRow }? = nil -- shown in the list when the Surge starts
local lastPhase = ""
local revealToken = 0
local streak = 0
local passes: { [string]: boolean } = {} -- from ProfileChanged, for the Shells chip
local ready = false
local missing: string? = nil

local Reveal = {}

-- WaitForChild with a timeout. Once one child is missing the rest are skipped, so init gives up quickly.
local function waitChild(parent: Instance?, name: string): Instance?
	if parent == nil or missing ~= nil then
		return nil
	end
	local found = parent:WaitForChild(name, WAIT_SECONDS)
	if found == nil then
		missing = name
	end
	return found
end

function Reveal.init(playerGui: PlayerGui)
	task.spawn(function()
		local found = Ui.screen(playerGui, "DiveCards", WAIT_SECONDS)
		local area = if found ~= nil then found:WaitForChild("Stage", WAIT_SECONDS) else nil
		if found == nil or not found:IsA("Frame") or area == nil or not area:IsA("Frame") then
			warn("[Reveal] StarterGui.DiveCards.Stage is missing; the reveal shows the answer list only")
			return
		end
		local dim = found:FindFirstChild("Backdrop")
		if dim ~= nil and dim:IsA("Frame") then
			backdrop = dim
			backdropTransparency = dim.BackgroundTransparency
		end
		cardsGui = found
		stage = area
	end)

	task.spawn(function()
		Net.event("ProfileChanged").OnClientEvent:Connect(function(profile: Net.ProfilePayload)
			passes = profile.passes or {}
		end)
	end)

	local screen = Ui.screen(playerGui, "Reveal", WAIT_SECONDS)
	if screen == nil then
		warn("[Reveal] GameUi.Reveal is missing; no answer list")
		return
	end
	-- The dive card replaces the old badge; the instance stays so nothing waiting on it hangs.
	local badgeFound = waitChild(screen, "Badge")
	local listFound = waitChild(screen, "List")
	local rowFound = waitChild(listFound, "RowTemplate")
	if missing ~= nil then
		warn("[Reveal] GameUi.Reveal has no " .. missing .. "; no answer list")
		return
	end
	gui = screen
	badge = badgeFound :: Frame
	badge.Visible = false
	list = listFound :: Frame
	rowTemplate = rowFound :: Frame
	ready = true
end

-- Mirrors StoreService.payEarned's pass bonuses, so the chip matches the wallet popup at the rise.
local function shellsFor(tier: string?): number
	local multiplier = Economy.multiplier(passes.Vip == true, passes.DoubleCash == true)
	return Economy.apply(Economy.answerShells(tier), multiplier)
end

local function fadeBackdrop(goal: number, info: TweenInfo?)
	local dim = backdrop
	if dim == nil then
		return
	end
	if info == nil then
		dim.BackgroundTransparency = goal
	else
		TweenService:Create(dim, info, { BackgroundTransparency = goal }):Play()
	end
end

-- Takes your card away: a quick shrink with the dim fading out, or at once (`instant`) between rounds.
local function hideCard(instant: boolean)
	local leaving = card
	card = nil
	local holder = cardsGui
	local function closeHolder()
		if card == nil and holder ~= nil then
			holder.Visible = false
		end
	end
	if leaving == nil then
		fadeBackdrop(1)
		closeHolder()
		return
	end
	local frame = leaving.frame
	local scale = if frame ~= nil then frame:FindFirstChildOfClass("UIScale") else nil
	if not instant and scale ~= nil then
		TweenService:Create(scale, CARD_EXIT, { Scale = 0 }):Play()
		fadeBackdrop(1, CARD_EXIT)
		task.delay(CARD_EXIT.Time + 0.05, function()
			leaving.destroy()
			closeHolder()
		end)
		return
	end
	leaving.destroy()
	fadeBackdrop(1)
	closeHolder()
end

-- A full-screen card over the dimmed backdrop; nil when DiveCards or the template is missing.
local function showCardWith(options: DiveCard.Options): DiveCard.Handle?
	hideCard(true)
	local holder = cardsGui
	local area = stage
	if holder == nil or area == nil then
		return nil
	end
	holder.Visible = true
	fadeBackdrop(1)
	fadeBackdrop(backdropTransparency, CARD_ENTER)
	options.fill = true
	options.budget = options.budget or GameConfig.Reveal.CardBudgetSeconds
	local handle = DiveCard.play(area, options)
	if handle.frame == nil then
		holder.Visible = false
		return nil
	end
	card = handle
	return handle
end

-- Your round's card, with everyone else's answers sinking in the pack with yours.
local function showCard(row: RevealRow, rows: { RevealRow }): DiveCard.Handle?
	lobbyCard = false
	local peers: { DiveCard.Peer } = {}
	for _, other in rows do
		if other ~= row then
			table.insert(peers, {
				userId = other.userId,
				name = other.name,
				answer = other.answer,
				tier = other.tier,
				depth = other.depth or 0,
			})
		end
	end
	return showCardWith({
		peers = peers,
		title = "YOUR DIVE",
		isYou = true,
		userId = row.userId,
		answer = row.answer,
		tier = row.tier,
		depth = row.depth or 0,
		oneIn = row.oneIn,
		schooled = row.schooled,
		shells = shellsFor(row.tier),
	})
end

-- The lobby warm-up borrows the same full-screen stage for its answers; nothing else is on it in the lobby.
function Reveal.showOwnCard(options: DiveCard.Options): DiveCard.Handle?
	revealToken += 1
	local handle = showCardWith(options)
	lobbyCard = handle ~= nil
	return handle
end

function Reveal.hideOwnCard(instant: boolean)
	lobbyCard = false
	hideCard(instant)
end

-- The card holds briefly once its stamp settles, then leaves; it is gone before the rise whatever happens.
local function scheduleExit(mine: DiveCard.Handle, token: number)
	local started = os.clock()
	local deadline = GameConfig.Reveal.RaiseDelaySeconds - CARD_EXIT.Time - EXIT_MARGIN
	local function leave()
		if token == revealToken and card == mine then
			hideCard(false)
		end
	end
	task.delay(deadline, leave)
	task.spawn(function()
		mine.finished()
		local hold = math.min(GameConfig.Reveal.CardHoldSeconds, deadline - (os.clock() - started))
		if hold > 0 then
			task.wait(hold)
		end
		leave()
	end)
end

local function setPoints(label: TextLabel, value: number)
	label.Text = "+" .. math.floor(value + 0.5)
end

-- Counts a row's points up; a schooled answer counts up to the tier's full points, then back down to the
-- share it actually got.
local function countRow(label: TextLabel, answerLabel: TextLabel, row: RevealRow)
	local full = row.points
	local schooled = row.schooled
	local isSchooled = schooled ~= nil and schooled >= 2 and row.tier ~= nil and Tiers.points(row.tier) > row.points
	if isSchooled and row.tier ~= nil then
		full = Tiers.points(row.tier)
	end
	task.spawn(function()
		local function run(from: number, to: number)
			local elapsed = 0
			while elapsed < COUNT_SECONDS and label.Parent ~= nil do
				elapsed += RunService.RenderStepped:Wait()
				local alpha = math.min(1, elapsed / COUNT_SECONDS)
				setPoints(label, from + (to - from) * (1 - (1 - alpha) ^ 3))
			end
			setPoints(label, to)
		end
		run(0, full)
		if not isSchooled or label.Parent == nil then
			return
		end
		task.wait(SCHOOLED_PAUSE)
		answerLabel.Text ..= "  SCHOOLED x" .. tostring(schooled)
		answerLabel.TextColor3 = Theme.Color.Orange
		Ui.nudge(label)
		run(full, row.points)
	end)
end

-- Pulses the row's authored gold "Glow" outline on a Mythic row.
local function glow(row: Frame)
	local outline = row:FindFirstChild("Glow")
	if outline == nil or not outline:IsA("UIStroke") then
		return
	end
	outline.Enabled = true
	TweenService:Create(outline, MYTHIC_GLOW, { Thickness = 3.5 }):Play()
end

-- Best answer on top; rows arrive from the lowest up so the best one lands last.
local function showRows(rows: { RevealRow })
	Ui.clearClones(list, rowTemplate.Name, "Row")
	local ordered = table.clone(rows)
	table.sort(ordered, function(a, b)
		return a.points > b.points
	end)
	local me = Players.LocalPlayer.UserId
	local stagger = math.min(ROW_STAGGER, ROW_SPREAD / math.max(#ordered, 1))
	for index, row in ordered do
		local clone = rowTemplate:Clone()
		clone.Name = "Row" .. index
		clone.LayoutOrder = index
		local nameLabel = clone:FindFirstChild("Name") :: TextLabel
		local answerLabel = clone:FindFirstChild("Answer") :: TextLabel
		local pointsLabel = clone:FindFirstChild("Tier") :: TextLabel
		nameLabel.Text = string.upper(row.name)
		if row.userId == me then
			nameLabel.TextColor3 = Theme.Header.You
		end
		if row.answer ~= nil then
			answerLabel.Text = string.upper(row.answer)
		elseif row.tier ~= nil then
			answerLabel.Text = "accepted"
		else
			answerLabel.Text = "-"
		end
		setPoints(pointsLabel, 0)
		pointsLabel.TextColor3 = Ui.tierColor(row.tier)
		if row.tier == "Mythic" then
			glow(clone)
		end
		clone.Visible = false
		clone.Parent = list
		task.delay(stagger * (#ordered - index), function()
			if clone.Parent == nil then
				return
			end
			Ui.appear(clone)
			countRow(pointsLabel, answerLabel, row)
			if row.userId == me and row.points > 0 then
				Sfx.play("Pop", 0.3, 0.9 + 0.6 * (row.points / Tiers.MaxPoints))
			end
		end)
	end
	Ui.appear(list)
end

-- Streak callout after your card lands; tier sounds and the stamp belong to the card itself.
local function celebrate(row: RevealRow, mine: DiveCard.Handle?, token: number)
	local points = row.points
	if points >= GameConfig.Round.StreakMinPoints then
		streak += 1
	else
		streak = 0
	end
	local level = streak
	task.spawn(function()
		if mine ~= nil then
			mine.finished()
		end
		if token ~= revealToken then
			return
		end
		if mine == nil then
			-- No card to carry the moment (template missing): the old flash and fanfare.
			if row.tier == "Mythic" then
				Fx.flash(Theme.Tier.Mythic)
				Fx.shake(0.35, 0.5)
				Sfx.play("Fanfare", 0.8)
			elseif points >= Tiers.points("Rare") then
				Fx.flash(Ui.tierColor(row.tier))
				Sfx.play("Fanfare", 0.5)
			end
		elseif row.tier == "Mythic" then
			Fx.confetti(90)
			Fx.flash(Theme.Tier.Mythic)
		end
		if row.newBest == true then
			Toasts.show("NEW PERSONAL BEST  |  " .. math.floor(row.depth + 0.5) .. " M DIVE", "good")
		end
		if level >= 2 then
			-- The callout is drawn mid-screen, where the card's stamp is: it waits for the card to leave.
			if mine ~= nil then
				while card == mine and token == revealToken do
					task.wait(0.1)
				end
				task.wait(CARD_EXIT.Time)
			else
				task.wait(0.4)
			end
			if token ~= revealToken then
				return
			end
			Fx.callout("STREAK x" .. level, Theme.Color.Orange)
			Sfx.play("Tick", 0.5, 1 + 0.12 * math.min(level, 6))
		end
	end)
end

function Reveal.onReveal(payload: Net.RevealPayload)
	if not ready then
		return
	end
	revealToken += 1
	local token = revealToken
	local rows = payload.rows
	gui.Visible = true
	badge.Visible = false

	local me = Players.LocalPlayer.UserId
	local myRow: RevealRow? = nil
	for _, row in rows do
		if row.userId == me then
			myRow = row
		end
	end

	-- Only you get a card, with everyone else's answers diving on it; the list follows once it leaves.
	local mine = if myRow ~= nil then showCard(myRow, rows) else nil
	if mine ~= nil then
		list.Visible = false
		pendingRows = rows
		scheduleExit(mine, token)
	else
		pendingRows = nil
		showRows(rows)
	end
	if myRow ~= nil then
		celebrate(myRow, mine, token)
	end
	-- Pillars start rising RaiseDelaySeconds after the reveal, once your card is out of the way.
	if myRow == nil or myRow.lift > 0 then
		task.delay(GameConfig.Reveal.RaiseDelaySeconds, function()
			if token == revealToken and gui.Visible then
				Sfx.play("Rise", if myRow ~= nil then 0.45 else 0.4)
			end
		end)
	end
end

-- You sank or reset: your card and the answers list go at once, whatever the round is doing.
function Reveal.onEliminated()
	if not ready then
		return
	end
	revealToken += 1
	pendingRows = nil
	hideCard(true)
	gui.Visible = false
end

function Reveal.onState(payload: Net.RoundStatePayload)
	if not ready then
		return
	end
	local phase = payload.phase
	if phase == "Surge" and lastPhase ~= "Surge" then
		-- The card is normally long gone by now; this catches a short reveal.
		if not lobbyCard then
			hideCard(false)
		end
		local rows = pendingRows
		pendingRows = nil
		if rows ~= nil and gui.Visible then
			showRows(rows)
		end
	end
	if phase ~= "Prompt" and phase ~= "Reveal" and phase ~= "Surge" then
		streak = 0
	end
	if phase ~= "Reveal" and phase ~= "Surge" then
		gui.Visible = false
		pendingRows = nil
		if not lobbyCard then
			hideCard(true)
		end
	end
	lastPhase = phase
end

return Reveal
