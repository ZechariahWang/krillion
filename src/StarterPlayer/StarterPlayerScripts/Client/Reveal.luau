--!strict
-- Drives the reveal: your own dive card fills the screen (StarterGui.DiveCards), lands, holds a moment and
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
local Ui = require(script.Parent.Ui)

type RevealRow = Net.RevealRow

local ROW_STAGGER = 0.15
local ROW_SPREAD = 1.4 -- every row is in within this, however many players there are
local COUNT_SECONDS = 0.45
local SCHOOLED_PAUSE = 0.3
local CARDS_WAIT = 10
local CARD_ENTER = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CARD_EXIT = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local EXIT_MARGIN = 0.1 -- the card is fully gone this long before the rise starts
local KRILLION_GLOW = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local gui: ScreenGui
local badge: Frame
local list: Frame
local rowTemplate: Frame
local cardsGui: ScreenGui? = nil
local stage: Frame? = nil
local backdrop: Frame? = nil
local backdropTransparency = 0.35 -- replaced by the authored Backdrop's value

local card: DiveCard.Handle? = nil
local pendingRows: { RevealRow }? = nil -- shown in the list when the Surge starts
local lastPhase = ""
local revealToken = 0
local streak = 0
local passes: { [string]: boolean } = {} -- from ProfileChanged, for the Shells chip

local Reveal = {}

function Reveal.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Reveal") :: ScreenGui
	-- The dive card replaces the old badge; the instance stays so nothing waiting on it hangs.
	badge = gui:WaitForChild("Badge") :: Frame
	badge.Visible = false
	list = gui:WaitForChild("List") :: Frame
	rowTemplate = list:WaitForChild("RowTemplate") :: Frame

	task.spawn(function()
		local found = playerGui:WaitForChild("DiveCards", CARDS_WAIT)
		local area = if found ~= nil then found:WaitForChild("Stage", CARDS_WAIT) else nil
		if found == nil or not found:IsA("ScreenGui") or area == nil or not area:IsA("Frame") then
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
			holder.Enabled = false
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

-- Your full-screen card over a dimmed backdrop; nil when DiveCards or the template is missing.
local function showCard(row: RevealRow): DiveCard.Handle?
	hideCard(true)
	local holder = cardsGui
	local area = stage
	if holder == nil or area == nil then
		return nil
	end
	holder.Enabled = true
	fadeBackdrop(1)
	fadeBackdrop(backdropTransparency, CARD_ENTER)
	local handle = DiveCard.play(area, {
		title = "YOUR DIVE",
		isYou = true,
		answer = row.answer,
		tier = row.tier,
		depth = row.depth or 0,
		oneIn = row.oneIn,
		schooled = row.schooled,
		shells = shellsFor(row.tier),
		fill = true,
		budget = GameConfig.Reveal.CardBudgetSeconds,
	})
	if handle.frame == nil then
		holder.Enabled = false
		return nil
	end
	card = handle
	return handle
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

-- A pulsing gold outline on a One in a Krillion row.
local function glow(row: Frame)
	local stroke = row:FindFirstChildOfClass("UIStroke")
	if stroke == nil then
		local created = Instance.new("UIStroke")
		created.Name = "Glow"
		created.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		created.Parent = row
		stroke = created
	end
	local outline = stroke :: UIStroke
	outline.Color = Theme.Tier.OneInAKrillion
	outline.Thickness = 1.5
	TweenService:Create(outline, KRILLION_GLOW, { Thickness = 3.5 }):Play()
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
		if row.tier == "OneInAKrillion" then
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
			if row.tier == "OneInAKrillion" then
				Fx.flash(Theme.Tier.OneInAKrillion)
				Fx.shake(0.35, 0.5)
				Sfx.play("Fanfare", 0.8)
			elseif points >= Tiers.points("Rare") then
				Fx.flash(Ui.tierColor(row.tier))
				Sfx.play("Fanfare", 0.5)
			end
		elseif row.tier == "OneInAKrillion" then
			Fx.confetti(90)
			Fx.flash(Theme.Tier.OneInAKrillion)
		end
		if level >= 2 then
			task.wait(0.4)
			Fx.callout("STREAK x" .. level, Theme.Color.Orange)
			Sfx.play("Tick", 0.5, 1 + 0.12 * math.min(level, 6))
		end
	end)
end

function Reveal.onReveal(payload: Net.RevealPayload)
	revealToken += 1
	local token = revealToken
	local rows = payload.rows
	if payload.round == 1 then
		streak = 0
	end
	gui.Enabled = true
	badge.Visible = false

	local me = Players.LocalPlayer.UserId
	local myRow: RevealRow? = nil
	for _, row in rows do
		if row.userId == me then
			myRow = row
		end
	end

	-- Only you get a card; everyone else's answers are in the list.
	local mine = if myRow ~= nil then showCard(myRow) else nil
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
			if token == revealToken and gui.Enabled then
				Sfx.play("Rise", if myRow ~= nil then 0.45 else 0.4)
			end
		end)
	end
end

function Reveal.onState(payload: Net.RoundStatePayload)
	local phase = payload.phase
	if phase == "Surge" and lastPhase ~= "Surge" then
		-- The card is normally long gone by now; this catches a short reveal.
		hideCard(false)
		local rows = pendingRows
		pendingRows = nil
		if rows ~= nil and gui.Enabled then
			showRows(rows)
		end
	end
	if phase ~= "Reveal" and phase ~= "Surge" then
		gui.Enabled = false
		pendingRows = nil
		hideCard(true)
	end
	lastPhase = phase
end

return Reveal
