--!strict
-- Tags every other pillar with its answer once the pillars rise (a clone of
-- ReplicatedStorage.Templates.AnswerTag floating over the pillar top). Pillars carry no name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Ui = require(script.Parent.Ui)

local TAG_ABOVE_TOP = 9 -- studs the answer tag floats over the pillar top
local MATCH_PHASES: { [string]: boolean } = { Prompt = true, Reveal = true, Surge = true }

type Tag = {
	label: TextLabel,
	billboard: BillboardGui,
	border: UIStroke?,
}

local phase = "Waiting"
local revealToken = 0
local tags: { [Instance]: Tag } = {}

local PillarTags = {}

local function platformFor(userId: number): BasePart?
	local folder = workspace:FindFirstChild("Platforms")
	if folder == nil then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("OwnerUserId") == userId then
			return child
		end
	end
	return nil
end

local function tagFor(platform: BasePart): Tag?
	local existing = tags[platform]
	if existing ~= nil then
		return existing
	end
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local template = if templates ~= nil then templates:FindFirstChild("AnswerTag") else nil
	if template == nil or not template:IsA("BillboardGui") then
		return nil
	end
	local clone = template:Clone()
	local pill = clone:FindFirstChild("Pill")
	local label = if pill ~= nil then pill:FindFirstChild("AnswerText") else nil
	if label == nil or not label:IsA("TextLabel") then
		clone:Destroy()
		return nil
	end
	clone.Enabled = false
	clone.StudsOffsetWorldSpace = Vector3.new(0, GameConfig.Platform.Height / 2 + TAG_ABOVE_TOP, 0)
	clone.Parent = platform
	Ui.bindGui(clone)
	local stroke = if pill ~= nil then pill:FindFirstChild("Border") else nil
	local tag: Tag = {
		label = label,
		billboard = clone,
		border = if stroke ~= nil and stroke:IsA("UIStroke") then stroke else nil,
	}
	tags[platform] = tag
	return tag
end

local function hideTags()
	revealToken += 1
	for platform, tag in tags do
		if platform.Parent == nil then
			tags[platform] = nil
		else
			tag.billboard.Enabled = false
		end
	end
end

local function showTags(revealRows)
	local me = Players.LocalPlayer.UserId
	for _, row in revealRows do
		local platform = if row.userId ~= me then platformFor(row.userId) else nil
		local tag = if platform ~= nil then tagFor(platform) else nil
		if tag ~= nil then
			local color = Ui.tierColor(row.tier)
			tag.label.Text = if row.answer ~= nil then string.upper(row.answer) else "NO ANSWER"
			tag.label.TextColor3 = if row.answer ~= nil then color else Theme.Color.Grey
			local border = tag.border
			if border ~= nil then
				border.Color = color
			end
			tag.billboard.Enabled = true
		end
	end
end

-- RoundState payload: only the phase matters here.
function PillarTags.onState(payload)
	local previous = phase
	phase = payload.phase
	-- A new question clears the pillar tags; so does leaving the match.
	if phase == "Prompt" and previous ~= "Prompt" then
		hideTags()
	elseif not MATCH_PHASES[phase] then
		hideTags()
	end
end

-- Reveal payload: the answers for the pillar tags.
function PillarTags.onReveal(payload)
	local revealRows = payload.rows or {}
	-- The answer tags appear as the pillars start to rise, after the dive cards have landed.
	revealToken += 1
	local token = revealToken
	task.delay(GameConfig.Reveal.RaiseDelaySeconds, function()
		if token ~= revealToken or (phase ~= "Reveal" and phase ~= "Surge") then
			return
		end
		showTags(revealRows)
	end)
end

return PillarTags
