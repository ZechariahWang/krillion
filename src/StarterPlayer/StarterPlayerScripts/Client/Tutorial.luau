--!strict
-- Drives StarterGui.Tutorial: the big 4-step HOW TO PLAY modal shown once to new players (off a pillar), and
-- again from the rail's HELP key. Finishing or closing it fires TutorialDone, which DataService records.
-- Also puts the HowToBoard and HowRareBoard lobby boards (ReplicatedStorage.Templates) in the world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Net = require(ReplicatedStorage.Shared.Net)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local FIRST_SHOW_DELAY = 1.5 -- let the lobby settle before the first-time popup
local STEPS = 4
local MARGIN = 16 -- pixels kept clear around the modal when it is scaled down for a small screen
local MIN_FIT = 0.4
local PORTRAIT_BELOW = 0.7 -- the wide layout shows smaller than this: use the tall phone one if it shows bigger
local PORTRAIT_SIZE = UDim2.fromOffset(560, 628)
local DOT_IDLE = Color3.fromRGB(68, 35, 163)
local DOT_ACTIVE = Color3.fromRGB(255, 217, 94)
local DOT_SIZE = UDim2.fromOffset(20, 20)
local DOT_ACTIVE_SIZE = UDim2.fromOffset(44, 20)
local BOARDS = { "HowToBoard", "HowRareBoard" }
-- After leaving a pillar mid-match (sunk), wait for the match to end so the modal never covers the
-- revive offer or the eliminated card.
local CALM_PHASES: { [string]: boolean } = { Waiting = true, Intermission = true }

local player = Players.LocalPlayer

local gui: Frame? = nil
local fit: UIScale? = nil
local modal: Frame? = nil
local layout: Ui.PhoneLayout? = nil
local stepText: TextLabel? = nil
local backButton: TextButton? = nil
local nextButton: TextButton? = nil
local doneButton: TextButton? = nil
local pages: { [number]: GuiObject } = {} -- by step, so a missing page never shifts the others
local dots: { [number]: Frame } = {}

local step = 1
local isOpen = false
local decided = false -- the first ProfileChanged has been seen
local pending = false -- this player has not finished the tutorial: show it once they are off a pillar
local profileDone = false -- the server has recorded TutorialDone
local waiting = false -- a first-time show is scheduled
local phase = "Waiting"
local wasPlaying = false
local leftMidMatch = false

local Tutorial = {}

local function schoolingOn(): boolean
	return GameConfig.Schooling.Enabled == 1
end

local function isPlaying(): boolean
	return player:GetAttribute("Playing") == true
end

local function calm(): boolean
	if isPlaying() then
		return false
	end
	return not leftMidMatch or CALM_PHASES[phase] == true
end

-- Shrinks the whole modal on small screens instead of letting it run off the edge; a portrait phone gets the
-- tall layout so the page text stays readable.
local function fitToScreen()
	local screen = gui
	local panel = modal
	local scale = fit
	if screen == nil or panel == nil or scale == nil then
		return
	end
	Ui.fitPanel(screen.AbsoluteSize, panel, scale, layout, MARGIN, MIN_FIT, PORTRAIT_BELOW)
end

-- Portrait phone layout: a narrower, taller modal with bigger body text; page 2's sample input, page 3's
-- tier chips (two rows of three) and its low/high labels (stacked) are rearranged to fit the width.
local function portraitOverrides(): Ui.Overrides
	local overrides: Ui.Overrides = {
		Pages = { Size = UDim2.new(1, -60, 0, 376) },
		["Pages/Page2/Stage/SampleBox"] = { Size = UDim2.fromOffset(320, 55) },
		["Pages/Page2/Stage/SampleLock"] = { Position = UDim2.new(0.5, 88, 0, 22) },
		["Pages/Page2/Stage/Confirm"] = { TextScaled = true },
		["Pages/Page3/Stage"] = { Size = UDim2.new(1, 0, 0, 196) },
		["Pages/Page3/Stage/TierChips"] = { Size = UDim2.new(1, 0, 0, 68), Position = UDim2.fromOffset(0, 10) },
		["Pages/Page3/Stage/TierChips/UIListLayout"] = { Wraps = true },
		["Pages/Page3/Stage/Scale"] = { Position = UDim2.new(0.5, 0, 0, 88) },
		["Pages/Page3/Stage/Low"] = {
			Position = UDim2.fromOffset(36, 104),
			Size = UDim2.new(1, -72, 0, 28),
			TextSize = 24,
		},
		["Pages/Page3/Stage/High"] = {
			Position = UDim2.fromOffset(36, 132),
			Size = UDim2.new(1, -72, 0, 28),
			TextSize = 24,
		},
		["Pages/Page3/Stage/Water"] = { Position = UDim2.fromOffset(0, 164), TextSize = 23 },
		["Pages/Page3/Heading"] = { Position = UDim2.fromOffset(0, 202) },
		["Pages/Page3/Body"] = {
			Position = UDim2.fromOffset(12, 248),
			Size = UDim2.new(1, -24, 0, 126),
			TextSize = 26,
		},
		["Pages/Page4/Body"] = { Size = UDim2.new(1, -24, 0, 58), TextWrapped = true, TextSize = 24 },
		["Pages/Page4/SchoolingNote"] = {
			Position = UDim2.fromOffset(12, 314),
			Size = UDim2.new(1, -24, 0, 54),
			TextWrapped = true,
			TextSize = 23,
		},
	}
	for page = 1, 2 do
		overrides["Pages/Page" .. page .. "/Body"] = { Size = UDim2.new(1, -24, 0, 126), TextSize = 26 }
	end
	for _, chip in { "Plankton", "TooClever", "Schooler", "Rare", "DeepCut", "OneInAKrillion" } do
		local path = "Pages/Page3/Stage/TierChips/" .. chip
		overrides[path] = { Size = UDim2.fromOffset(140, 31) }
		overrides[path .. "/Text"] = { TextSize = 22 }
	end
	return overrides
end

local function showStep(index: number, animate: boolean)
	step = math.clamp(index, 1, STEPS)
	if stepText ~= nil then
		stepText.Text = string.format("STEP %d OF %d", step, STEPS)
	end
	for i, dot in dots do
		local active = i == step
		dot.BackgroundColor3 = if active then DOT_ACTIVE else DOT_IDLE
		dot.Size = if active then DOT_ACTIVE_SIZE else DOT_SIZE
	end
	for i, page in pages do
		if i == step then
			if animate then
				Ui.appear(page)
			else
				page.Visible = true
			end
		else
			page.Visible = false
		end
	end
	local last = step == STEPS
	if backButton ~= nil then
		backButton.Visible = step > 1
	end
	if nextButton ~= nil then
		nextButton.Visible = not last
	end
	if doneButton ~= nil then
		doneButton.Visible = last
	end
end

-- `finished` is GOT IT or the close button (a skip counts as done); false when a match pulls the player away,
-- which keeps the tutorial pending so it comes back after the match.
local function close(finished: boolean)
	local screen = gui
	if screen == nil or not isOpen then
		return
	end
	isOpen = false
	screen.Visible = false
	if finished then
		pending = false
		Rail.setBadge("HelpButton", nil)
		if not profileDone then
			profileDone = true
			Net.event("TutorialDone"):FireServer()
		end
	end
end

-- Another rail panel opening (one at a time) counts as skipping, like the close button.
local function closeForRail()
	close(true)
end

local function tryShow()
	if not pending or isOpen or waiting or gui == nil then
		return
	end
	waiting = true
	task.delay(FIRST_SHOW_DELAY, function()
		waiting = false
		if pending and not isOpen and calm() then
			Tutorial.open()
		end
	end)
end

-- Page 4 lists every tier from Config/Tiers, so a points or depth change shows up here on its own.
local function fillTiers(page: Instance)
	local list = page:FindFirstChild("TierList")
	local template = if list ~= nil then list:FindFirstChild("TierRow") else nil
	if list == nil or template == nil or not template:IsA("Frame") then
		return
	end
	Ui.clearClones(list, "TierRow", "TierRow")
	for index, tier in Tiers.List do
		local row = template:Clone()
		row.Name = "TierRow" .. tier.name
		row.LayoutOrder = index
		row.Visible = true
		local color = Ui.tierColor(tier.name)
		local chip = row:FindFirstChild("Chip")
		if chip ~= nil and chip:IsA("Frame") then
			chip.BackgroundColor3 = color
		end
		local name = row:FindFirstChild("Name")
		if name ~= nil and name:IsA("TextLabel") then
			name.Text = tier.label
			name.TextColor3 = color
		end
		local points = row:FindFirstChild("Points")
		if points ~= nil and points:IsA("TextLabel") then
			points.Text = string.format("%d pts", tier.points)
		end
		local depth = row:FindFirstChild("Depth")
		if depth ~= nil and depth:IsA("TextLabel") then
			depth.Text = string.format("%d-%d m", tier.depthMin, tier.depthMax)
		end
		row.Parent = list
	end
end

local function showSchoolingNote(root: Instance)
	local note = root:FindFirstChild("SchoolingNote", true)
	if note ~= nil and note:IsA("GuiObject") then
		note.Visible = schoolingOn()
	end
end

local function bindButton(button: TextButton?, onClick: () -> ())
	if button == nil then
		return
	end
	Ui.pressable(button)
	button.Activated:Connect(onClick)
end

local function bind(screen: Frame)
	local holder = screen:WaitForChild("Holder", WAIT_SECONDS)
	local panel = if holder ~= nil then holder:WaitForChild("Modal", WAIT_SECONDS) else nil
	if holder == nil or panel == nil or not panel:IsA("Frame") then
		warn("Tutorial: StarterGui.Tutorial.Holder.Modal is missing; the tutorial stays closed")
		return
	end
	local scale = holder:FindFirstChild("Fit")
	fit = if scale ~= nil and scale:IsA("UIScale") then scale else nil
	modal = panel
	local label = panel:FindFirstChild("StepText")
	stepText = if label ~= nil and label:IsA("TextLabel") then label else nil
	local function buttonNamed(name: string): TextButton?
		local found = panel:FindFirstChild(name)
		return if found ~= nil and found:IsA("TextButton") then found else nil
	end
	backButton = buttonNamed("BackButton")
	nextButton = buttonNamed("NextButton")
	doneButton = buttonNamed("DoneButton")
	local pagesFolder = panel:WaitForChild("Pages", WAIT_SECONDS)
	local dotsFolder = panel:FindFirstChild("Dots")
	for i = 1, STEPS do
		local page = if pagesFolder ~= nil then pagesFolder:FindFirstChild("Page" .. i) else nil
		if page ~= nil and page:IsA("GuiObject") then
			pages[i] = page
		end
		local dot = if dotsFolder ~= nil then dotsFolder:FindFirstChild("Dot" .. i) else nil
		if dot ~= nil and dot:IsA("Frame") then
			dots[i] = dot
		end
	end
	local tierPage = pages[STEPS]
	if tierPage ~= nil then
		fillTiers(tierPage)
		showSchoolingNote(tierPage)
	end
	layout = Ui.phoneLayout(panel, PORTRAIT_SIZE, portraitOverrides())

	bindButton(backButton, function()
		Sfx.play("Tick", 0.4)
		showStep(step - 1, true)
	end)
	bindButton(nextButton, function()
		Sfx.play("Pop", 0.4)
		showStep(step + 1, true)
	end)
	bindButton(doneButton, function()
		Sfx.play("LockIn", 0.6)
		close(true)
	end)
	bindButton(buttonNamed("CloseButton"), function()
		Sfx.play("Tick", 0.4)
		close(true)
	end)
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)

	local help = Rail.button("HelpButton")
	if help ~= nil then
		help.Activated:Connect(Tutorial.open)
	end
	gui = screen
	tryShow()
end

-- Clones the lobby boards into the world unless Studio already placed its own in Workspace.Lobby.
-- They are local display props, the same for every client.
local function placeBoards()
	local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
	local lobby = workspace:WaitForChild("Lobby", WAIT_SECONDS)
	for _, name in BOARDS do
		local board = if lobby ~= nil then lobby:FindFirstChild(name) else nil
		if board == nil then
			board = workspace:FindFirstChild(name)
		end
		if board == nil and templates ~= nil then
			local template = templates:FindFirstChild(name)
			if template ~= nil then
				local copy = template:Clone()
				copy.Parent = workspace
				board = copy
			else
				warn("Tutorial: ReplicatedStorage.Templates." .. name .. " is missing; that lobby board is not shown")
			end
		end
		if board ~= nil then
			showSchoolingNote(board)
		end
	end
end

function Tutorial.init(playerGui: PlayerGui)
	player:GetAttributeChangedSignal("Playing"):Connect(function()
		if isPlaying() then
			close(false)
			wasPlaying = true
			leftMidMatch = false
		else
			-- Only a real trip off a pillar counts; the false set on joining is not one.
			leftMidMatch = wasPlaying and not CALM_PHASES[phase]
			wasPlaying = false
			tryShow()
		end
	end)
	-- RoundState also fans out from Main.client; this controller only needs the phase.
	Net.event("RoundState").OnClientEvent:Connect(function(payload)
		phase = payload.phase
		if CALM_PHASES[phase] then
			leftMidMatch = false
		end
		tryShow()
	end)
	task.spawn(placeBoards)
	task.spawn(function()
		local found = Ui.screen(playerGui, "Tutorial", WAIT_SECONDS)
		if found == nil or not found:IsA("Frame") then
			warn("Tutorial: StarterGui.Tutorial is missing; the tutorial stays closed")
			return
		end
		bind(found)
	end)
end

-- ProfileChanged payload: opens the modal the first time tutorialDone is false while not playing.
function Tutorial.onProfile(profile)
	if profile.tutorialDone == true then
		profileDone = true
		pending = false
	end
	if decided then
		return
	end
	decided = true
	if not profileDone then
		pending = true
		-- The HELP key wears a "!" until the new player has been through it once.
		Rail.setBadge("HelpButton", "!")
		tryShow()
	end
end

-- Opens the modal at step 1. Never over a pillar: the match comes first.
function Tutorial.open()
	local screen = gui
	local panel = modal
	if screen == nil or panel == nil or isPlaying() then
		return
	end
	showStep(1, false)
	fitToScreen()
	screen.Visible = true
	if not isOpen then
		isOpen = true
		Sfx.play("Pop", 0.5)
		Ui.pop(panel, 0.7)
	end
	Rail.panelOpened(closeForRail)
end

return Tutorial
