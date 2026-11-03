--!strict
-- Drives StarterGui.Reveal: your tier slams in with a count-up, then everyone's answers roll in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local ROW_STAGGER = 0.15

local gui: ScreenGui
local badge: Frame
local accent: Frame
local tierText: TextLabel
local yourAnswer: TextLabel
local pointsText: TextLabel
local list: Frame
local rowTemplate: Frame

local streak = 0

local Reveal = {}

function Reveal.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Reveal") :: ScreenGui
	badge = gui:WaitForChild("Badge") :: Frame
	accent = badge:WaitForChild("Accent") :: Frame
	tierText = badge:WaitForChild("TierText") :: TextLabel
	yourAnswer = badge:WaitForChild("YourAnswer") :: TextLabel
	pointsText = badge:WaitForChild("PointsText") :: TextLabel
	list = gui:WaitForChild("List") :: Frame
	rowTemplate = list:WaitForChild("RowTemplate") :: Frame
end

local function tierLabel(tier: string?): string
	if tier == nil then
		return "NO ANSWER"
	end
	local info = Tiers.ByName[tier]
	if info == nil then
		return tier
	end
	return string.upper(info.label)
end

local function countUp(points: number)
	pointsText.Text = "+0"
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(current)
		pointsText.Text = "+" .. math.floor(current + 0.5)
	end)
	local tween = TweenService:Create(value, Theme.Tween.Count, { Value = points })
	tween.Completed:Once(function()
		pointsText.Text = "+" .. points
		value:Destroy()
	end)
	tween:Play()
end

local function showBadge(row)
	if row.answer ~= nil then
		yourAnswer.Text = string.upper(row.answer)
	elseif row.tier ~= nil then
		yourAnswer.Text = "ACCEPTED"
	else
		yourAnswer.Text = "NO VALID ANSWER"
	end
	tierText.Text = tierLabel(row.tier)
	tierText.TextColor3 = Ui.tierColor(row.tier)
	accent.BackgroundColor3 = Ui.tierColor(row.tier)
	if row.points > 0 then
		pointsText.TextColor3 = Theme.Color.Cream
	else
		pointsText.TextColor3 = Theme.Color.Red
	end
	Ui.appear(badge)
	countUp(row.points)
end

local function showRows(rows)
	Ui.clearClones(list, rowTemplate.Name, "Row")
	for index, row in rows do
		local clone = rowTemplate:Clone()
		clone.Name = "Row" .. index
		clone.LayoutOrder = index
		local nameLabel = clone:FindFirstChild("Name") :: TextLabel
		local answerLabel = clone:FindFirstChild("Answer") :: TextLabel
		local tierLabelObject = clone:FindFirstChild("Tier") :: TextLabel
		nameLabel.Text = string.upper(row.name)
		if row.answer ~= nil then
			answerLabel.Text = string.upper(row.answer)
		elseif row.tier ~= nil then
			answerLabel.Text = "accepted"
		else
			answerLabel.Text = "-"
		end
		tierLabelObject.Text = "+" .. row.points
		tierLabelObject.TextColor3 = Ui.tierColor(row.tier)
		clone.Visible = false
		clone.Parent = list
		task.delay(ROW_STAGGER * index, function()
			if clone.Parent ~= nil then
				Ui.appear(clone)
			end
		end)
	end
end

local function celebrate(row)
	local points = row.points
	if points >= Tiers.ByName.OneInAKrillion.points then
		Fx.flash(Theme.Tier.OneInAKrillion)
		Sfx.play("Fanfare", 0.8)
	elseif points >= Tiers.ByName.Rare.points then
		Fx.flash(Ui.tierColor(row.tier))
		Sfx.play("Fanfare", 0.6)
	elseif points > 0 then
		Sfx.play("Rise", 0.5)
	end

	if points >= GameConfig.Round.StreakMinPoints then
		streak += 1
	else
		streak = 0
	end
	if streak >= 2 then
		task.delay(0.9, function()
			Fx.callout("STREAK x" .. streak, Theme.Color.Orange)
		end)
	end
end

function Reveal.onReveal(payload)
	local rows = payload.rows
	table.sort(rows, function(a, b)
		return a.points > b.points
	end)
	if payload.round == 1 then
		streak = 0
	end
	gui.Enabled = true

	local me = Players.LocalPlayer.UserId
	local myRow = nil
	for _, row in rows do
		if row.userId == me then
			myRow = row
		end
	end

	badge.Visible = myRow ~= nil
	if myRow ~= nil then
		showBadge(myRow)
		celebrate(myRow)
	else
		Sfx.play("Rise", 0.4)
	end
	showRows(rows)
end

function Reveal.onState(payload)
	if payload.phase ~= "Reveal" and payload.phase ~= "Surge" then
		gui.Enabled = false
	end
end

return Reveal
