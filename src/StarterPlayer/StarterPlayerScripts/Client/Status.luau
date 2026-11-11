--!strict
-- Drives StarterGui.Status: the top status line (with accent underline), the time | alive bar under it,
-- and the tide chip that says how far the water rises this round and, while you play, what tier keeps you
-- afloat. Tide.luau flashes SAFE on the chip after a surge. Shown in every phase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local TideRules = require(ReplicatedStorage.Shared.Tide)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
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

local lastStatus = ""
local lastPrompt = ""
local lastRound = 0
local lastTick = "" -- round and second of the last danger tick, so extra broadcasts never double-tick
local lastNeed = "" -- the need hint last shown, so the chip only bumps when it changes
local lastPayload: any = nil
local flashToken = 0
local flashUntil = 0
local flashText = ""
local flashColor = Theme.Color.Green

local TIDE_WIDTH = 0.26 -- wider than authored so the need hint fits beside a special-round prefix
local PLATE_PAD_X = 28 -- pixels of plate either side of the status text
-- The plate is centred on the status line and a little shorter than its box (the box includes the font's
-- empty ascender and descender room), so the letters sit in the middle and its border clears the timer row.
local PLATE_HEIGHT = 0.9 -- of the status line's height
local PLATE_BORDER_PER_PIXEL = 1 / 200 -- border thickness per pixel of screen height, up to the chunky border

local SPECIAL_NAMES = {
	TidalWave = "TIDAL WAVE",
	DoubleLift = "DOUBLE LIFT",
}

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
	tide = tideFound :: Frame
	tideAccent = accentFound :: Frame
	tideText = tideTextFound :: TextLabel
	-- The need hint is coloured inline so the accent keeps the special round's colour.
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

-- "RARE+ TO SURVIVE" in the tier colour, "SAFE THIS ROUND" in green, "GO FOR A MYTHIC" when nothing is enough.
local function needHint(payload): string
	local need = TideRules.needTier(payload.height, payload.waterY, payload.surge, payload.special)
	if need == "safe" then
		return tinted("SAFE THIS ROUND", Theme.Color.Green)
	elseif need == "none" then
		return tinted("GO FOR A MYTHIC", Theme.Color.Red)
	elseif Tiers.index(need) == 1 then
		return tinted("ANY ANSWER SURVIVES", Theme.Tier.Plankton)
	end
	local tierColors: { [string]: Color3 } = Theme.Tier :: any
	return tinted(string.upper(Tiers.ByName[need].label) .. "+ TO SURVIVE", tierColors[need] or Theme.Color.Cream)
end

local function updateTide(payload)
	if os.clock() < flashUntil then
		tide.Visible = true
		tideAccent.BackgroundColor3 = flashColor
		tideText.Text = tinted(flashText, flashColor)
		return
	end
	local inRound = payload.phase == "Prompt" or payload.phase == "Reveal"
	tide.Visible = inRound
	if not inRound then
		lastNeed = ""
		return
	end
	local text = "WATER +" .. string.format("%.1f", payload.surge)
	local special = payload.special
	if special == "TidalWave" then
		tideAccent.BackgroundColor3 = Theme.Color.Red
		text = "TIDAL WAVE  |  " .. text
	elseif special == "DoubleLift" then
		tideAccent.BackgroundColor3 = Theme.Color.Green
		text = "DOUBLE LIFT  |  " .. text
	else
		tideAccent.BackgroundColor3 = Theme.Color.Water
	end
	-- Answers are graded by the reveal, so the hint only helps while the prompt is open.
	if payload.phase == "Prompt" and payload.playing then
		local need = needHint(payload)
		text ..= "  |  " .. need
		if need ~= lastNeed then
			lastNeed = need
			Ui.bump(tide, 1.06)
		end
	else
		lastNeed = ""
	end
	tideText.Text = text
end

-- Shows `text` on the tide chip for `seconds` (over the need hint or a hidden chip), then puts it back.
function Status.flashTide(text: string, color: Color3, seconds: number)
	if not ready then
		return
	end
	flashToken += 1
	local token = flashToken
	flashUntil = os.clock() + seconds
	flashText = text
	flashColor = color
	lastNeed = ""
	if tide == nil then
		return
	end
	updateTide(lastPayload or { phase = "Surge" })
	Ui.bump(tide, 1.08)
	task.delay(seconds, function()
		if token ~= flashToken then
			return
		end
		flashUntil = 0
		if lastPayload ~= nil then
			updateTide(lastPayload)
		else
			tide.Visible = false
		end
	end)
end

local function isLocked(payload): boolean
	local me = Players.LocalPlayer.UserId
	for _, id in payload.lockedUserIds or {} do
		if id == me then
			return true
		end
	end
	return false
end

-- The pill's left half during a prompt: your own time (a +10s boost) or the shared countdown, and
-- OVERTIME while the prompt only stays open for someone else's extra time.
local function promptTimer(payload)
	local mine = payload.yourSecondsLeft
	local outOfTime = mine == nil or mine <= 0 or not payload.playing or isLocked(payload)
	if payload.overtime and outOfTime then
		secondaryText.Text = "OVERTIME"
		return
	end
	local shown = if mine ~= nil then mine else payload.secondsLeft
	secondaryText.Text = Status.formatTime(shown)
	if shown <= GameConfig.Round.DangerSeconds then
		secondaryText.TextColor3 = Theme.Color.Red
		-- Only the players on the pillars hear the countdown tick; the lobby just sees it go red.
		local key = payload.round .. ":" .. shown
		if payload.playing == true and key ~= lastTick then
			lastTick = key
			Ui.bump(secondaryText, 1.08)
			Sfx.play("Tick", 0.5)
		end
	end
end

-- Announces a special round once, when its prompt starts.
local function announceSpecial(payload)
	if payload.phase ~= "Prompt" or payload.round == lastRound then
		return
	end
	lastRound = payload.round
	local special = payload.special
	if special == nil then
		return
	end
	local color = Theme.Color.Green
	if special == "TidalWave" then
		color = Theme.Color.Red
	end
	Fx.callout(SPECIAL_NAMES[special] or special, color)
	Sfx.play("Fanfare", 0.5)
end

function Status.onState(payload)
	if not ready then
		return
	end
	local phase = payload.phase
	lastPayload = payload
	secondaryText.TextColor3 = Theme.Color.Cream
	updateTide(payload)
	announceSpecial(payload)
	if phase == "Results" or phase == "Waiting" then
		lastRound = 0
	end

	if phase == "Waiting" then
		setStatus("WAITING FOR PLAYERS")
		secondaryText.Text = "LOBBY"
		-- Ready players (a live character, not AFK) are the ones a match can start with.
		local ready = if typeof(payload.readyCount) == "number" then payload.readyCount else payload.playerCount
		aliveText.Text = "PLAYERS " .. ready .. "/" .. payload.minPlayers
	elseif phase == "Intermission" then
		setStatus("DIVING IN")
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
		promptTimer(payload)
		aliveText.Text = "ALIVE " .. payload.alive .. "/" .. payload.starting
		-- How many have locked in, once anyone has: the compact stand-in for the old lock counter.
		local locked = #(payload.lockedUserIds or {})
		if locked > 0 then
			aliveText.Text ..= "  " .. Theme.Icon.Lock .. locked
		end
	elseif phase == "Reveal" then
		setStatus("ROUND " .. payload.round .. " RESULTS")
		secondaryText.Text = "REVEAL"
		aliveText.Text = "ALIVE " .. payload.alive .. "/" .. payload.starting
	elseif phase == "Surge" then
		setStatus("THE WATER IS RISING")
		secondaryText.Text = "ROUND " .. payload.round
		aliveText.Text = "ALIVE " .. payload.alive .. "/" .. payload.starting
	elseif phase == "Results" then
		setStatus("MATCH OVER")
		secondaryText.Text = Status.formatTime(payload.secondsLeft)
		aliveText.Text = "NEXT DIVE"
	end
	-- Phones, on a pillar: only the prompt and the timer. The alive count and the tide chip stay off.
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
