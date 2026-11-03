--!strict
-- Drives StarterGui.Status: the top status line (with accent underline) and the time | alive bar under it.
-- Shown in every phase, in the lobby and in the match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local statusFrame: Frame
local statusText: TextLabel
local secondaryText: TextLabel
local aliveText: TextLabel

local lastStatus = ""
local lastPrompt = ""

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
end

function Status.onState(payload)
	local phase = payload.phase
	secondaryText.TextColor3 = Theme.Color.Cream

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
