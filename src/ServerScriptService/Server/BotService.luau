--!strict
-- Bots that top small matches up to GameConfig.Bots.FillTo. Bot ids are negative numbers (-1001, -1002, ...)
-- kept apart from Players, so the water cull never sees them; bots fire no MatchEvents and earn nothing,
-- and a match only counts as a Win with 2+ human participants (RoundService).
-- Each bot stands on its pillar as a Templates.BotRig clone, welded to the pillar so it rides every rise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BotBrain = require(ReplicatedStorage.Shared.BotBrain)
local MapService = require(script.Parent.MapService)

local FIRST_ID = -1001 -- well clear of local test servers' player ids (-1, -2, ...)
local SHIRT_TINT = 0.2 -- the rig's torso is its pillar's colour, a little lighter
local SINK_DEPTH = 6 -- studs the rig drops while it fades out
local SINK_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type Bot = {
	name: string,
	skill: number,
	rig: Model?,
}

local bots: { [number]: Bot } = {}
local random = Random.new()
local warnedMissing = false

local BotService = {}

function BotService.isBot(id: any): boolean
	return typeof(id) == "number" and id < 0
end

-- Creates `count` bots with names nobody in `usedNames` has. Returns their ids.
function BotService.fill(count: number, usedNames: { [string]: boolean }): { number }
	BotService.clear()
	local used = table.clone(usedNames)
	local ids = {}
	local start = random:NextInteger(1, #BotBrain.Names)
	for index = 1, math.max(0, count) do
		local name = BotBrain.pickName(start + index - 1, used)
		used[name] = true
		local id = FIRST_ID - (index - 1)
		bots[id] = { name = name, skill = BotBrain.skill(random:NextNumber()) }
		table.insert(ids, id)
	end
	return ids
end

function BotService.nameOf(id: number): string
	local bot = bots[id]
	if bot == nil then
		return "Bot"
	end
	return bot.name
end

function BotService.skillOf(id: number): number
	local bot = bots[id]
	if bot == nil then
		return BotBrain.skill(0.5)
	end
	return bot.skill
end

local function rigTemplate(): Model?
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local rig = if templates ~= nil then templates:FindFirstChild("BotRig") else nil
	if rig ~= nil and rig:IsA("Model") then
		return rig
	end
	if not warnedMissing then
		warnedMissing = true
		warn("BotService: ReplicatedStorage.Templates.BotRig is missing; bots play without a rig")
	end
	return nil
end

-- Puts the bot's rig on its pillar, facing the middle of the ring. The rig's parts are welded to the
-- pillar and massless, so the pillar's Lift carries it like a standing player, and clearing the pillars
-- clears it too.
function BotService.attach(id: number, platform: Part)
	local bot = bots[id]
	local template = rigTemplate()
	if bot == nil or template == nil then
		return
	end
	local rig = template:Clone()
	rig.Name = "BotRig"
	local box, size = rig:GetBoundingBox()
	local feet = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	local topY = MapService.platformStandCFrame(platform).Position.Y - 3
	local spot = Vector3.new(platform.Position.X, topY, platform.Position.Z)
	local facing = CFrame.lookAt(spot, Vector3.new(0, topY, 0))
	if (spot - Vector3.new(0, topY, 0)).Magnitude < 0.01 then
		facing = CFrame.new(spot)
	end
	rig:PivotTo(facing * feet:Inverse() * rig:GetPivot())
	local shirt = platform.Color:Lerp(Color3.new(1, 1, 1), SHIRT_TINT)
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			if part:GetAttribute("Shirt") == true then
				part.Color = shirt
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = platform
			weld.Part1 = part
			weld.Parent = part
		end
	end
	rig.Parent = platform
	bot.rig = rig
end

-- The water took this bot: the rig lets go of the pillar, drops and fades, then is removed.
function BotService.sink(id: number)
	local bot = bots[id]
	local rig = if bot ~= nil then bot.rig else nil
	if bot == nil or rig == nil then
		return
	end
	bot.rig = nil
	for _, item in rig:GetDescendants() do
		if item:IsA("WeldConstraint") then
			item:Destroy()
		end
	end
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			TweenService:Create(part, SINK_TWEEN, {
				CFrame = part.CFrame - Vector3.new(0, SINK_DEPTH, 0),
				Transparency = 1,
			}):Play()
		elseif part:IsA("Decal") then
			TweenService:Create(part, SINK_TWEEN, { Transparency = 1 }):Play()
		elseif part:IsA("LayerCollector") then
			part.Enabled = false
		end
	end
	task.delay(SINK_TWEEN.Time, function()
		rig:Destroy()
	end)
end

-- Removes every bot (and any rig still standing) at the end of a match.
function BotService.clear()
	for _, bot in bots do
		local rig = bot.rig
		if rig ~= nil then
			rig:Destroy()
		end
	end
	bots = {}
end

function BotService.start() end

return BotService
