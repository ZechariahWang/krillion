--!strict
-- Drives StarterGui.Reveal: your tier badge with a count-up, and the ranked list of everyone's answers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local ROW_STAGGER = 0.12

local gui: ScreenGui
local badge: Frame
local yourAnswer: TextLabel
local tierText: TextLabel
local pointsText: TextLabel
local list: Frame
local rowTemplate: Frame

local Reveal = {}

function Reveal.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Reveal") :: ScreenGui
	badge = gui:WaitForChild("Badge") :: Frame
	yourAnswer = badge:WaitForChild("YourAnswer") :: TextLabel
	tierText = badge:WaitForChild("TierText") :: TextLabel
	pointsText = badge:WaitForChild("PointsText") :: TextLabel
	list = gui:WaitForChild("List") :: Frame
	rowTemplate = list:WaitForChild("RowTemplate") :: Frame
end

local function tierLabel(tier: string?): string
	if tier == nil then
		return "REFUSED"
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
	elseif row.answered then
		yourAnswer.Text = "NOT IN THE BANK"
	else
		yourAnswer.Text = "NO ANSWER"
	end
	tierText.Text = tierLabel(row.tier)
	tierText.TextColor3 = Ui.tierColor(row.tier)
	Ui.pop(badge)
	countUp(row.points)
end

local function showRows(rows)
	Ui.clearClones(list, rowTemplate.Name)
	for index, row in rows do
		local clone = rowTemplate:Clone()
		clone.Name = "Row" .. index
		clone.LayoutOrder = index
		local nameLabel = clone:FindFirstChild("Name") :: TextLabel
		local answerLabel = clone:FindFirstChild("Answer") :: TextLabel
		local tierLabelObject = clone:FindFirstChild("Tier") :: TextLabel
		nameLabel.Text = row.name
		if row.answer ~= nil then
			answerLabel.Text = row.answer
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
				clone.Visible = true
			end
		end)
	end
end

function Reveal.onReveal(payload)
	local rows = payload.rows
	table.sort(rows, function(a, b)
		return a.points > b.points
	end)
	gui.Enabled = true

	local me = Players.LocalPlayer.UserId
	local myRow = nil
	local bestTier = 0
	for _, row in rows do
		if row.userId == me then
			myRow = row
		end
		if row.tier ~= nil then
			bestTier = math.max(bestTier, Tiers.points(row.tier))
		end
	end

	badge.Visible = myRow ~= nil
	if myRow ~= nil then
		showBadge(myRow)
	end
	showRows(rows)

	if bestTier >= Tiers.ByName.DeepCut.points then
		Sfx.play("Fanfare", 0.6)
	elseif bestTier > 0 then
		Sfx.play("Rise", 0.4)
	end
end

function Reveal.onState(payload)
	if payload.phase ~= "Reveal" and payload.phase ~= "Surge" then
		gui.Enabled = false
	end
end

return Reveal
