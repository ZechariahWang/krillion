--!strict
-- Drives StarterGui.Results: winner, podium, countdown to the next dive.

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
				nameLabel.Text = entry.name
				pointsLabel.Text = tostring(entry.points)
			end
		end
	end
	nextText.Text = "Next dive in " .. payload.seconds
	gui.Enabled = true
	Ui.pop(panel)
	Sfx.play("Fanfare", 0.6)
end

function Results.onState(payload)
	if payload.phase == "Results" then
		nextText.Text = "Next dive in " .. payload.secondsLeft
	else
		gui.Enabled = false
	end
end

return Results
