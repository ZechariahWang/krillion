--!strict
-- Drives StarterGui.Results: winner, podium and the countdown to the next dive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Config.Theme)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WIN_CONFETTI = 110
local WAIT_SECONDS = 10

local gui: Frame
local panel: Frame
local titleText: TextLabel
local winnerText: TextLabel
local podium: Frame
local nextText: TextLabel

local reachedRound = 0 -- the last round this player was on a pillar for, this match
local ready = false
local missing: string? = nil

local Results = {}

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

function Results.init(playerGui: PlayerGui)
	local screen = Ui.screen(playerGui, "Results", WAIT_SECONDS)
	if screen == nil then
		warn("[Results] GameUi.Results is missing; no results card")
		return
	end
	local panelFound = waitChild(screen, "Panel")
	local titleFound = waitChild(panelFound, "Title")
	local winnerFound = waitChild(panelFound, "WinnerText")
	local podiumFound = waitChild(panelFound, "Podium")
	local nextFound = waitChild(panelFound, "NextText")
	if missing ~= nil then
		warn("[Results] GameUi.Results has no " .. missing .. "; no results card")
		return
	end
	gui = screen
	panel = panelFound :: Frame
	titleText = titleFound :: TextLabel
	winnerText = winnerFound :: TextLabel
	podium = podiumFound :: Frame
	nextText = nextFound :: TextLabel
	ready = true
end

function Results.onMatchEnded(payload: Net.MatchEndedPayload)
	if not ready then
		return
	end
	local won = false
	if payload.solo then
		won = false
	elseif payload.winnerUserId ~= nil then
		won = payload.winnerUserId == Players.LocalPlayer.UserId
	else
		won = payload.winnerName == Players.LocalPlayer.DisplayName
	end
	-- A solo dive has no winner to name: show how far the player got instead.
	if payload.solo then
		titleText.Text = "SOLO RUN"
		winnerText.Text = "SURVIVED " .. math.max(0, payload.rounds - 1) .. " ROUNDS"
	elseif won then
		titleText.Text = "VICTORY!"
		winnerText.Text = string.upper(payload.winnerName)
	else
		titleText.Text = "LAST ONE FLOATING"
		winnerText.Text = string.upper(payload.winnerName)
	end
	-- The authored trophies either side of the title show for a win only.
	for _, name in { "TrophyLeft", "TrophyRight" } do
		local trophy = titleText:FindFirstChild(name)
		if trophy ~= nil and trophy:IsA("GuiObject") then
			trophy.Visible = won
		end
	end
	for place = 1, 3 do
		local row = podium:FindFirstChild("Place" .. place) :: Frame?
		if row ~= nil then
			local entry = payload.podium[place]
			row.Visible = entry ~= nil
			if entry ~= nil then
				local nameLabel = row:FindFirstChild("Name") :: TextLabel
				local pointsLabel = row:FindFirstChild("Points") :: TextLabel
				nameLabel.Text = string.upper(entry.name)
				pointsLabel.Text = entry.points .. " PTS"
			end
		end
	end
	nextText.Text = "NEXT MATCH IN " .. payload.seconds
	gui.Visible = true
	-- A win lands with the big bounce; any other ending still pops, the panel is the moment.
	if won then
		Ui.bounce(panel)
	else
		Ui.pop(panel, 0.7)
	end
	if won then
		Sfx.play("Fanfare", 0.8)
		Fx.flash(Theme.Color.Gold)
		Fx.confetti(WIN_CONFETTI)
	elseif payload.solo or reachedRound > 0 then
		-- You went under this match: a splash, not a fanfare.
		Sfx.play("Splash", 0.6)
	else
		Sfx.play("Fanfare", 0.5)
	end
	reachedRound = 0
end

function Results.onState(payload: Net.RoundStatePayload)
	if not ready then
		return
	end
	if payload.playing and (payload.phase == "Prompt" or payload.phase == "Reveal") then
		reachedRound = math.max(reachedRound, payload.round)
	end
	if payload.phase == "Results" then
		nextText.Text = "NEXT MATCH IN " .. payload.secondsLeft
	else
		gui.Visible = false
	end
end

return Results
