--!strict
-- Tags a pillar with its player's answer when they pass the crab (ReplicatedStorage.Templates.AnswerTag,
-- or a Studio-authored NameTag.AnswerText if the template ever gains one), keeps the authored heart pips
-- over every name in step with the match, and hides your own pillar's name tag locally so it never
-- blocks your view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Ui)

local TAG_GAP = 4 -- pixels between a pillar's name tag and its answer tag
local TAG_STUDS = 2.5 -- fallback lift when the name tag is sized in studs
local MATCH_PHASES: { [string]: boolean } = { Prompt = true, Reveal = true }
local EMPTY_HEART = 0.75 -- transparency of a heart slot the player does not have

type Tag = {
	label: TextLabel,
	billboard: BillboardGui?, -- our clone; nil when the label is a Studio-authored NameTag.AnswerText
	border: UIStroke?,
}

local phase = "Waiting"
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
	for platform, tag in tags do
		if platform.Parent == nil then
			tags[platform] = nil
		else
			setTagShown(tag, false)
		end
	end
end

-- The heart pips authored on a pillar's name tag: as many bright as the player has hearts.
local function showHearts(platform: BasePart, hearts: number, maxHearts: number)
	local nameTag = nameTagOf(platform)
	local nameText = if nameTag ~= nil then nameTag:FindFirstChild("NameText") else nil
	local row = if nameText ~= nil then nameText:FindFirstChild("Hearts") else nil
	if row == nil or not row:IsA("GuiObject") then
		return
	end
	row.Visible = hearts > 0
	for _, slot in row:GetChildren() do
		if slot:IsA("ImageLabel") then
			local index = tonumber(string.match(slot.Name, "%d+")) or 0
			slot.Visible = index <= maxHearts
			slot.ImageTransparency = if index <= hearts then 0 else EMPTY_HEART
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

-- RoundState payload: the phase, and everyone's hearts.
function PillarTags.onState(payload: Net.RoundStatePayload)
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
	for _, row in payload.ring or {} do
		local platform = platformFor(row.userId)
		if platform ~= nil then
			showHearts(platform, row.hearts, payload.maxHearts or 5)
		end
	end
end

-- CrabPassed payload: the passer's answer goes up over their pillar, in its tier's colour, until the next
-- question. Your own is not tagged: your name tag is hidden for you.
function PillarTags.onPassed(payload: Net.CrabPassedPayload)
	if payload.fromUserId == Players.LocalPlayer.UserId then
		return
	end
	local platform = platformFor(payload.fromUserId)
	local tag = if platform ~= nil then tagFor(platform) else nil
	if tag == nil then
		return
	end
	local color = Ui.tierColor(payload.tier)
	tag.label.Text = string.upper(payload.answer)
	tag.label.TextColor3 = color
	local border = tag.border
	if border ~= nil then
		border.Color = color
	end
	setTagShown(tag, true)
end

return PillarTags
