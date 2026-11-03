--!strict
-- Drives StarterGui.Status: the top status line (with accent underline), the time | alive bar under it,
-- and the tide chip that says how far the water rises this round. Shown in every phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

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

function Status.init(playerGui: PlayerGui)
	local gui = playerGui:WaitForChild("Status")
	statusFrame = gui:WaitForChild("StatusFrame") :: Frame
	statusText = statusFrame:WaitForChild("Status") :: TextLabel
	local secondary = gui:WaitForChild("SecondaryStatus")
	secondaryText = secondary:WaitForChild("Secondary") :: TextLabel
	aliveText = secondary:WaitForChild("Alive") :: TextLabel
	tide = gui:WaitForChild("Tide") :: Frame
	tideAccent = tide:WaitForChild("Accent") :: Frame
	tideText = tide:WaitForChild("Text") :: TextLabel
end

local function updateTide(payload)
	local inRound = payload.phase == "Prompt" or payload.phase == "Reveal"
	tide.Visible = inRound
	if not inRound then
		return
	end
	local rise = "WATER +" .. string.format("%.1f", payload.surge)
	local special = payload.special
	if special == "TidalWave" then
		tideAccent.BackgroundColor3 = Theme.Color.Red
		tideText.Text = "TIDAL WAVE  |  " .. rise
	elseif special == "DoubleLift" then
		tideAccent.BackgroundColor3 = Theme.Color.Green
		tideText.Text = "DOUBLE LIFT  |  " .. rise
	else
		tideAccent.BackgroundColor3 = Theme.Color.Water
		tideText.Text = rise
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
	local phase = payload.phase
	secondaryText.TextColor3 = Theme.Color.Cream
	updateTide(payload)
	announceSpecial(payload)
	if phase == "Results" or phase == "Waiting" then
		lastRound = 0
	end

	if phase == "Waiting" then
		setStatus("WAITING FOR PLAYERS")
		secondaryText.Text = "LOBBY"
		aliveText.Text = "PLAYERS " .. payload.playerCount .. "/" .. payload.minPlayers
	elseif phase == "Intermission" then
		setStatus("DIVING IN")
		secondaryText.Text = Status.formatTime(payload.secondsLeft)
		aliveText.Text = "PLAYERS " .. payload.playerCount
	elseif phase == "Prompt" then
		if payload.prompt ~= nil then
			lastPrompt = string.upper(payload.prompt)
		end
		setStatus(lastPrompt)
		secondaryText.Text = Status.formatTime(payload.secondsLeft)
		aliveText.Text = "ALIVE " .. payload.alive .. "/" .. payload.starting
		if payload.secondsLeft <= GameConfig.Round.DangerSeconds then
			secondaryText.TextColor3 = Theme.Color.Red
			Ui.bump(secondaryText, 1.08)
			Sfx.play("Tick", 0.5)
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
end

return Status
