--!strict
-- Drives StarterGui.Status: the top status line (the question, on a plate), the bar under it (whose turn it
-- is, or a countdown, beside the alive count), the chip under that with what the holder is typing, and
-- the chip under that, which lists the answers the question has used up. Shown in every phase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Icons = require(script.Parent.Icons)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10 -- most seconds to wait for the authored screen and its children before giving up
local ready = false
local missing: string? = nil

local statusGui: Frame
local statusFrame: Frame
local statusText: TextLabel
local secondaryText: TextLabel
local aliveText: TextLabel
local tide: Frame
local tideAccent: Frame
local tideText: TextLabel
local typing: Frame
local typingText: TextLabel
local typingFrom: number? = nil -- whose live typing the chip shows; nil while it shows an accepted answer

local lastStatus = ""
local lastPrompt = ""
local lastUsed = 0 -- how many used answers the chip last showed, so it only bumps when one is added
local lastPayload: any = nil
local flashToken = 0
local flashUntil = 0
local flashText = ""
local flashColor = Theme.Color.Green

local TIDE_WIDTH = 0.26 -- wider than authored so a long list of used answers stays readable
local PLATE_PAD_X = 28 -- pixels of plate either side of the status text
-- The plate is centred on the status line and a little shorter than its box (the box includes the font's
-- empty ascender and descender room), so the letters sit in the middle and its border clears the timer row.
local PLATE_HEIGHT = 0.9 -- of the status line's height
local PLATE_BORDER_PER_PIXEL = 1 / 200 -- border thickness per pixel of screen height, up to the chunky border

local Status = {}

function Status.formatTime(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	local minutes = math.floor(whole / 60)
	local rest = whole % 60
	return string.format("%d:%02d", minutes, rest)
end

local function setStatus(text: string)
	if text == lastStatus then
		return
	end
	lastStatus = text
	statusText.Text = text
	Ui.appear(statusFrame)
end

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

function Status.init(playerGui: PlayerGui)
	local gui = Ui.screen(playerGui, "Status", WAIT_SECONDS)
	local frameFound = waitChild(gui, "StatusFrame")
	local statusFound = waitChild(frameFound, "Status")
	local secondary = waitChild(gui, "SecondaryStatus")
	local secondaryFound = waitChild(secondary, "Secondary")
	local aliveFound = waitChild(secondary, "Alive")
	local tideFound = waitChild(gui, "Tide")
	local accentFound = waitChild(tideFound, "Accent")
	local tideTextFound = waitChild(tideFound, "Text")
	local typingFound = waitChild(gui, "Typing")
	local typingTextFound = waitChild(typingFound, "Text")
	local plateFound = waitChild(frameFound, "Plate")
	if gui == nil or missing ~= nil then
		warn("Status: SharedUi.Status is missing " .. (missing or "entirely") .. "; no status chips")
		return
	end
	statusGui = gui :: Frame
	-- The chips hide under an open window (its header carries what matters), except one that keeps them.
	Windows.Changed.connect(function()
		statusGui.Visible = not Windows.hidesStatus()
	end)
	statusFrame = frameFound :: Frame
	statusText = statusFound :: TextLabel
	secondaryText = secondaryFound :: TextLabel
	aliveText = aliveFound :: TextLabel
	-- The authored clock icon shows beside a countdown only, not beside LOBBY or REVEAL.
	local function showClock()
		Icons.show(secondaryText, string.match(secondaryText.Text, "^%d+:%d%d$") ~= nil)
	end
	secondaryText:GetPropertyChangedSignal("Text"):Connect(showClock)
	showClock()
	tide = tideFound :: Frame
	tideAccent = accentFound :: Frame
	tideText = tideTextFound :: TextLabel
	typing = typingFound :: Frame
	typingText = typingTextFound :: TextLabel
	typing.Visible = false
	-- A flash is coloured inline, so the chip takes rich text.
	tideText.RichText = true
	tide.Size = UDim2.new(math.max(tide.Size.X.Scale, TIDE_WIDTH), tide.Size.X.Offset, tide.Size.Y.Scale, tide.Size.Y.Offset)

	-- The prompt sits on a solid chunky plate so it reads over the busy arena (name tags, signs) behind it.
	-- The authored Plate hugs the text.
	local line = statusText.Size.Y
	local plate = plateFound :: Frame
	local border = plate:FindFirstChildOfClass("UIStroke")
	local screen = statusFrame:FindFirstAncestorWhichIsA("LayerCollector") :: LayerCollector?
	local function fitPlate()
		plate.Size = UDim2.new(0, statusText.TextBounds.X + PLATE_PAD_X * 2, line.Scale * PLATE_HEIGHT, line.Offset * PLATE_HEIGHT)
		plate.Visible = statusText.Text ~= ""
		-- A phone's short screen leaves only a few pixels to the timer row, so the border thins there.
		if border ~= nil and screen ~= nil and screen.AbsoluteSize.Y > 0 then
			border.Thickness = math.clamp(screen.AbsoluteSize.Y * PLATE_BORDER_PER_PIXEL, 2, Theme.Chunky.Border)
		end
	end
	statusText:GetPropertyChangedSignal("TextBounds"):Connect(fitPlate)
	if screen ~= nil then
		screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPlate)
	end
	fitPlate()
	ready = true
end

local function tinted(text: string, color: Color3): string
	return '<font color="#' .. color:ToHex() .. '">' .. text .. "</font>"
end

-- The chip under the status row: the answers this question has used up, newest last. A flash (a pinch,
-- an extra heart) shows over it for a moment.
local function updateChip(payload)
	if os.clock() < flashUntil then
		tide.Visible = true
		tideAccent.BackgroundColor3 = flashColor
		tideText.Text = tinted(flashText, flashColor)
		return
	end
	local used: { string } = payload.used or {}
	local shown = payload.phase == "Prompt" and #used > 0
	tide.Visible = shown
	if not shown then
		lastUsed = 0
		return
	end
	tideAccent.BackgroundColor3 = Theme.Color.Water
	tideText.Text = "USED  |  " .. string.upper(table.concat(used, ", "))
	if #used ~= lastUsed then
		lastUsed = #used
		Ui.bump(tide, 1.06)
	end
end

-- Shows `text` on the chip for `seconds` (over the used answers or a hidden chip), then puts it back.
function Status.flashTide(text: string, color: Color3, seconds: number)
	if not ready then
		return
	end
	flashToken += 1
	local token = flashToken
	flashUntil = os.clock() + seconds
	flashText = text
	flashColor = color
	updateChip(lastPayload or { phase = "Reveal" })
	Ui.bump(tide, 1.08)
	task.delay(seconds, function()
		if token ~= flashToken then
			return
		end
		flashUntil = 0
		if lastPayload ~= nil then
			updateChip(lastPayload)
		else
			tide.Visible = false
		end
	end)
end

local function showTyping(text: string, color: Color3)
	typingText.Text = string.upper(text)
	typingText.TextColor3 = color
	typing.Visible = text ~= ""
end

-- Typing: what another player holding the crab has typed so far.
function Status.onTyping(payload: Net.TypingPayload)
	if not ready or lastPayload == nil or payload.userId ~= lastPayload.holderUserId then
		return
	end
	typingFrom = payload.userId
	showTyping(payload.text, Theme.Color.Cream)
end

-- CrabPassed: the accepted answer stays on the typing chip, in its tier's colour, until the next
-- holder types.
function Status.onPassed(payload: Net.CrabPassedPayload)
	if not ready or payload.fromUserId == Players.LocalPlayer.UserId then
		return
	end
	typingFrom = nil
	showTyping(payload.answer, Ui.tierColor(payload.tier))
end

-- The name of whoever holds the crab, from the ring rows.
local function holderName(payload): string?
	for _, row in payload.ring or {} do
		if row.userId == payload.holderUserId then
			return row.name
		end
	end
	return nil
end

function Status.onState(payload)
	if not ready then
		return
	end
	local phase = payload.phase
	lastPayload = payload
	secondaryText.TextColor3 = Theme.Color.Cream
	updateChip(payload)
	-- The typing chip clears when the question ends, on your own turn, and when its typist has moved on.
	local holder = payload.holderUserId
	if phase ~= "Prompt" or holder == Players.LocalPlayer.UserId or (typingFrom ~= nil and typingFrom ~= holder) then
		typingFrom = nil
		typing.Visible = false
	end

	if phase == "Waiting" then
		setStatus("WAITING FOR PLAYERS")
		secondaryText.Text = "LOBBY"
		-- Ready players (a live character, not AFK) are the ones a match can start with.
		local ready = if typeof(payload.readyCount) == "number" then payload.readyCount else payload.playerCount
		aliveText.Text = "PLAYERS " .. ready .. "/" .. payload.minPlayers
	elseif phase == "Intermission" then
		setStatus("CRAB CRAZE STARTS SOON")
		secondaryText.Text = Status.formatTime(payload.secondsLeft)
		aliveText.Text = "PLAYERS " .. payload.playerCount
	elseif phase == "Starting" then
		setStatus("GET READY")
		secondaryText.Text = Status.formatTime(payload.secondsLeft)
		aliveText.Text = "PLAYERS " .. payload.alive
	elseif phase == "Prompt" then
		if payload.prompt ~= nil then
			lastPrompt = string.upper(payload.prompt)
		end
		setStatus(lastPrompt)
		-- Whose turn it is, where the countdown used to be: the fuse has no clock to show.
		if payload.holderUserId == Players.LocalPlayer.UserId then
			secondaryText.Text = "YOUR TURN"
			secondaryText.TextColor3 = Theme.Color.Green
		else
			secondaryText.Text = string.upper(holderName(payload) or "...")
		end
		aliveText.Text = "ALIVE " .. payload.alive .. "/" .. payload.starting
	elseif phase == "Reveal" then
		setStatus("PINCHED!")
		secondaryText.Text = "ROUND " .. payload.round
		aliveText.Text = "ALIVE " .. payload.alive .. "/" .. payload.starting
	elseif phase == "Results" then
		setStatus("MATCH OVER")
		secondaryText.Text = Status.formatTime(payload.secondsLeft)
		aliveText.Text = "NEXT MATCH"
	end
	-- Phones, on a pillar: only the question and whose turn it is. The alive count and the chip stay off.
	if Ui.isPhone() and payload.playing == true then
		aliveText.Visible = false
		tide.Visible = false
		secondaryText.Size = UDim2.new(1, 0, 1, 0)
	else
		aliveText.Visible = true
		secondaryText.Size = UDim2.new(0.5, 0, 1, 0)
	end
end

return Status
