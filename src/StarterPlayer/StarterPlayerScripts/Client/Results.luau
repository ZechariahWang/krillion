--!strict
-- Drives StarterGui.Results: winner, podium, countdown to the next dive, plus a strip under the panel
-- (cloned from ReplicatedStorage.Templates.ResultsExtras) with the rarest dive and the Shells you earned
-- this match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local TEMPLATE_WAIT = 10
local EARNED_COUNT_SECONDS = 1.1
local WIN_CONFETTI = 110

local gui: Frame
local panel: Frame
local titleText: TextLabel
local winnerText: TextLabel
local podium: Frame
local nextText: TextLabel
local rarestText: TextLabel? = nil
local earnedText: TextLabel? = nil

local reachedRound = 0 -- the last round this player was on a pillar for, this match
local earnedToken = 0

local Results = {}

function Results.init(playerGui: PlayerGui)
	gui = Ui.screen(playerGui, "Results") :: Frame
	panel = gui:WaitForChild("Panel") :: Frame
	titleText = panel:WaitForChild("Title") :: TextLabel
	winnerText = panel:WaitForChild("WinnerText") :: TextLabel
	podium = panel:WaitForChild("Podium") :: Frame
	nextText = panel:WaitForChild("NextText") :: TextLabel

	-- The panel is full, so the extras hang just below it and move with it.
	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("Templates", TEMPLATE_WAIT)
		local template = if templates ~= nil then templates:WaitForChild("ResultsExtras", TEMPLATE_WAIT) else nil
		if template == nil or not template:IsA("Frame") then
			warn("[Results] ReplicatedStorage.Templates.ResultsExtras is missing; no rarest dive or Shells line")
			return
		end
		local extras = (template :: Frame):Clone()
		extras.Name = "Extras"
		extras.Parent = panel
		local function text(name: string): TextLabel?
			local found = extras:FindFirstChild(name)
			return if found ~= nil and found:IsA("TextLabel") then found else nil
		end
		rarestText = text("Rarest")
		earnedText = text("Earned")
	end)
end

local function earnedLine(amount: number): string
	return Theme.Icon.Shell .. " +" .. Currency.digits(amount) .. " " .. Currency.Upper .. " THIS MATCH"
end

local function countEarned(label: TextLabel, amount: number)
	earnedToken += 1
	local token = earnedToken
	label.Text = earnedLine(0)
	task.spawn(function()
		local elapsed = 0
		while elapsed < EARNED_COUNT_SECONDS and token == earnedToken do
			elapsed += RunService.RenderStepped:Wait()
			local alpha = math.min(1, elapsed / EARNED_COUNT_SECONDS)
			label.Text = earnedLine(math.floor(amount * (1 - (1 - alpha) ^ 3) + 0.5))
		end
		if token == earnedToken then
			label.Text = earnedLine(amount)
			if amount > 0 then
				Ui.bump(label, 1.12)
				Sfx.play("Coin", 0.5)
			end
		end
	end)
end

local function showExtras(payload: Net.MatchEndedPayload)
	local rarestLabel = rarestText
	if rarestLabel ~= nil then
		local rarest = payload.rarest
		if rarest ~= nil then
			local info = Tiers.ByName[rarest.tier]
			local tierName = if info ~= nil then info.label else rarest.tier
			rarestLabel.Text = string.format(
				"RAREST DIVE  |  %s  |  %s  by %s",
				string.upper(rarest.answer),
				string.upper(tierName),
				string.upper(rarest.name)
			)
			rarestLabel.TextColor3 = Ui.tierColor(rarest.tier)
		else
			rarestLabel.Text = "Nothing rare this time"
			rarestLabel.TextColor3 = Theme.Color.Grey
		end
	end
	local earnedLabel = earnedText
	if earnedLabel ~= nil then
		local earned = payload.earned
		local amount = if earned ~= nil then earned[tostring(Players.LocalPlayer.UserId)] else nil
		earnedLabel.Visible = amount ~= nil
		if amount ~= nil then
			countEarned(earnedLabel, amount)
		end
	end
end

function Results.onMatchEnded(payload: Net.MatchEndedPayload)
	local won = not payload.solo and payload.winnerName == Players.LocalPlayer.DisplayName
	-- A solo dive has no winner to name: show how far the player got instead.
	if payload.solo then
		titleText.Text = "SOLO DIVE"
		winnerText.Text = "SURVIVED " .. math.max(0, payload.rounds - 1) .. " ROUNDS"
	elseif won then
		titleText.Text = Theme.Icon.Trophy .. " VICTORY! " .. Theme.Icon.Trophy
		winnerText.Text = string.upper(payload.winnerName)
	else
		titleText.Text = "LAST ONE FLOATING"
		winnerText.Text = string.upper(payload.winnerName)
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
	nextText.Text = "NEXT DIVE IN " .. payload.seconds
	showExtras(payload)
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
	if payload.playing and (payload.phase == "Prompt" or payload.phase == "Reveal" or payload.phase == "Surge") then
		reachedRound = math.max(reachedRound, payload.round)
	end
	if payload.phase == "Results" then
		nextText.Text = "NEXT DIVE IN " .. payload.secondsLeft
	else
		gui.Visible = false
	end
end

return Results
