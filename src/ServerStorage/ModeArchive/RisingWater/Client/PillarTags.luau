--!strict
-- Tags every other pillar with its answer once the pillars rise (ReplicatedStorage.Templates.AnswerTag,
-- or a Studio-authored NameTag.AnswerText if the template ever gains one), and hides your own pillar's name
-- tag locally so it never blocks your view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Ui = require(script.Parent.Ui)

local TAG_GAP = 4 -- pixels between a pillar's name tag and its answer tag
local TAG_STUDS = 2.5 -- fallback lift when the name tag is sized in studs
local MATCH_PHASES: { [string]: boolean } = { Prompt = true, Reveal = true, Surge = true }

type Tag = {
	label: TextLabel,
	billboard: BillboardGui?, -- our clone; nil when the label is a Studio-authored NameTag.AnswerText
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

local function nameTagOf(platform: Instance): BillboardGui?
	local tag = platform:FindFirstChild("NameTag")
	if tag ~= nil and tag:IsA("BillboardGui") then
		return tag
	end
	return nil
end

-- Puts our tag just above the pillar's name tag, wherever the template places that.
local function placeAbove(tag: BillboardGui, nameTag: BillboardGui?)
	if nameTag == nil then
		tag.StudsOffsetWorldSpace = Vector3.new(0, GameConfig.Platform.Height / 2 + 8, 0)
		return
	end
	tag.Adornee = nameTag.Adornee
	tag.StudsOffset = nameTag.StudsOffset
	tag.StudsOffsetWorldSpace = nameTag.StudsOffsetWorldSpace
	tag.ExtentsOffset = nameTag.ExtentsOffset
	tag.ExtentsOffsetWorldSpace = nameTag.ExtentsOffsetWorldSpace
	tag.MaxDistance = nameTag.MaxDistance
	tag.AlwaysOnTop = nameTag.AlwaysOnTop
	local nameSize = nameTag.Size
	local tagSize = tag.Size
	if nameSize.Y.Scale == 0 and tagSize.Y.Scale == 0 and tagSize.Y.Offset > 0 then
		-- Both sized in pixels: SizeOffset stacks ours on top at any distance.
		local nameHeight = nameSize.Y.Offset
		local tagHeight = tagSize.Y.Offset
		local lift = nameTag.SizeOffset.Y * nameHeight + (nameHeight + tagHeight) / 2 + TAG_GAP
		local shiftX = nameTag.SizeOffset.X * nameSize.X.Offset / math.max(tagSize.X.Offset, 1)
		tag.SizeOffset = Vector2.new(shiftX, lift / tagHeight)
	else
		tag.StudsOffset = nameTag.StudsOffset + Vector3.new(0, TAG_STUDS, 0)
	end
end

local function tagFor(platform: BasePart): Tag?
	local existing = tags[platform]
	if existing ~= nil then
		return existing
	end
	local nameTag = nameTagOf(platform)
	local authored = if nameTag ~= nil then nameTag:FindFirstChild("AnswerText") else nil
	if authored ~= nil and authored:IsA("TextLabel") then
		local tag: Tag = { label = authored, billboard = nil, border = nil }
		tags[platform] = tag
		return tag
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
	placeAbove(clone, nameTag)
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

local function setTagShown(tag: Tag, shown: boolean)
	local billboard = tag.billboard
	if billboard ~= nil then
		billboard.Enabled = shown
	else
		tag.label.Visible = shown
	end
end

local function hideTags()
	revealToken += 1
	for platform, tag in tags do
		if platform.Parent == nil then
			tags[platform] = nil
		else
			setTagShown(tag, false)
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
			setTagShown(tag, true)
		end
	end
end

-- Your own name tag sits right over your head from the default camera, so it is hidden for you only.
local function hideOwnNameTag()
	local platform = platformFor(Players.LocalPlayer.UserId)
	local nameTag = if platform ~= nil then nameTagOf(platform) else nil
	if nameTag ~= nil and nameTag.Enabled then
		nameTag.Enabled = false
	end
end

-- RoundState payload: only the phase matters here.
function PillarTags.onState(payload)
	local previous = phase
	phase = payload.phase
	if MATCH_PHASES[phase] then
		hideOwnNameTag()
	end
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
