--!strict
-- Drives StarterGui.Results: winner, podium, countdown to the next dive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local gui: ScreenGui
local panel: Frame
local winnerText: TextLabel
local podium: Frame
local nextText: TextLabel

local Results = {}

function Results.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Results") :: ScreenGui
	panel = gui:WaitForChild("Panel") :: Frame
	winnerText = panel:WaitForChild("WinnerText") :: TextLabel
	podium = panel:WaitForChild("Podium") :: Frame
	nextText = panel:WaitForChild("NextText") :: TextLabel
end

function Results.onMatchEnded(payload)
	winnerText.Text = string.upper(payload.winnerName)
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
	nextText.Text = "NEXT DIVE IN " .. payload.seconds
	gui.Enabled = true
	Ui.appear(panel)
	Sfx.play("Fanfare", 0.8)
	if payload.winnerName == Players.LocalPlayer.DisplayName then
		Fx.flash(Theme.Color.Gold)
		Fx.callout("YOU WIN", Theme.Color.Gold)
	end
end

function Results.onState(payload)
	if payload.phase == "Results" then
		nextText.Text = "NEXT DIVE IN " .. payload.secondsLeft
	else
		gui.Enabled = false
	end
end

return Results
