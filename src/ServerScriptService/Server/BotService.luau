--!strict
-- Bots that top small matches up to GameConfig.Bots.FillTo. Bot ids are negative numbers (-1001, -1002, ...)
-- kept apart from Players, so the water cull never sees them; bots fire no MatchEvents and earn nothing.
-- A player who outlasts them has won the match (RoundService).
-- Each bot stands on its pillar as a clone of one of the Templates.BotLooks characters (authored: R6, posed,
-- anchored, joints kept), its root welded to the pillar so it rides every rise, with the head label players
-- have and the idle animation players stand in. Templates.BotRig is the stand-in when BotLooks is missing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local BotBrain = require(ReplicatedStorage.Shared.BotBrain)
local CosmeticService = require(script.Parent.CosmeticService)
local MapService = require(script.Parent.MapService)

local FIRST_ID = -1001 -- well clear of local test servers' player ids (-1, -2, ...)
local SHIRT_TINT = 0.2 -- the rig's torso is its pillar's colour, a little lighter
local SINK_DEPTH = 6 -- studs the rig drops while it fades out
local SINK_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local IDLE_SPEED_MIN = 0.85 -- each bot idles at its own speed, so they do not sway in step
local IDLE_SPEED_MAX = 1.15

type Bot = {
	name: string,
	skill: number,
	look: string?, -- the Templates.BotLooks model it wears
	rig: Model?,
}

local bots: { [number]: Bot } = {}
local random = Random.new()
local warnedMissing = false

local BotService = {}

function BotService.isBot(id: any): boolean
	return typeof(id) == "number" and id < 0
end

-- Whether this id is a bot that is on a pillar now: in the current match and not sunk.
function BotService.standing(id: any): boolean
	local bot = if typeof(id) == "number" then bots[id] else nil
	return bot ~= nil and bot.rig ~= nil
end

-- The names of the authored looks, shuffled, so the bots of one match all look different.
local function shuffledLooks(): { string }
	local names: { string } = {}
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local folder = if templates ~= nil then templates:FindFirstChild("BotLooks") else nil
	if folder ~= nil then
		for _, look in folder:GetChildren() do
			if look:IsA("Model") then
				table.insert(names, look.Name)
			end
		end
	end
	random:Shuffle(names)
	return names
end

-- Creates `count` bots with names nobody in `usedNames` has. Returns their ids.
function BotService.fill(count: number, usedNames: { [string]: boolean }): { number }
	BotService.clear()
	local used = table.clone(usedNames)
	local looks = shuffledLooks()
	local ids = {}
	local function nextRoll(): number
		return random:NextNumber()
	end
	for index = 1, math.max(0, count) do
		local name = BotBrain.pickName(nextRoll, used)
		used[name] = true
		local id = FIRST_ID - (index - 1)
		local look = if #looks > 0 then looks[(index - 1) % #looks + 1] else nil
		bots[id] = { name = name, skill = BotBrain.skill(random:NextNumber()), look = look }
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

-- The look this bot wears: clients draw it on the dive card. Nil for an unknown bot or with no looks authored.
function BotService.lookOf(id: number): string?
	local bot = bots[id]
	if bot == nil then
		return nil
	end
	return bot.look
end

local function rigTemplate(bot: Bot): Model?
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local looks = if templates ~= nil then templates:FindFirstChild("BotLooks") else nil
	local look = if looks ~= nil and bot.look ~= nil then looks:FindFirstChild(bot.look) else nil
	if look ~= nil and look:IsA("Model") then
		return look
	end
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

-- The idle animation players stand in (the game's Animate script), so a bot moves the way they do.
local function idleAnimation(): Animation?
	local scripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	local animate = if scripts ~= nil then scripts:FindFirstChild("Animate") else nil
	local idle = if animate ~= nil then animate:FindFirstChild("idle") else nil
	if idle == nil then
		return nil
	end
	return idle:FindFirstChildOfClass("Animation")
end

-- Starts the idle on a rig that has a Humanoid with an Animator; the stand-in rig has neither.
local function playIdle(rig: Model)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	local animation = idleAnimation()
	if animator == nil or animation == nil then
		return
	end
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play(0.1, 1, random:NextNumber(IDLE_SPEED_MIN, IDLE_SPEED_MAX))
end

-- Puts the bot's rig on its pillar, facing the middle of the ring. The rig is massless and welded to the
-- pillar (a character by its root, so its joints stay free to animate; the stand-in rig by every part), so
-- the pillar's Lift carries it like a standing player, and clearing the pillars clears it too.
function BotService.attach(id: number, platform: Part)
	local bot = bots[id]
	if bot == nil then
		return
	end
	local template = rigTemplate(bot)
	if template == nil then
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
	local root = rig:FindFirstChild("HumanoidRootPart")
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
			if root == nil or part == root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = platform
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	rig.Parent = platform
	bot.rig = rig
	local head = rig:FindFirstChild("Head")
	if head ~= nil and bot.look ~= nil then
		CosmeticService.tagHead(head, bot.name)
	end
	playIdle(rig)
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

-- A player took this bot's pillar: its rig goes at once. The bot keeps its name for anything already shown.
function BotService.leave(id: number)
	local bot = bots[id]
	local rig = if bot ~= nil then bot.rig else nil
	if bot == nil or rig == nil then
		return
	end
	bot.rig = nil
	rig:Destroy()
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
