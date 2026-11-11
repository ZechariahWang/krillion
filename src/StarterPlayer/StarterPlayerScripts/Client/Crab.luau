--!strict
-- Shows the crab during a match: one clone of ReplicatedStorage.Templates.CrazeCrab on this client, sitting
-- on the pillar of whoever holds it, hopping across when it is passed and shaking harder as its mood
-- sours. The server only says who holds it and its mood; the fuse itself never reaches a client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Status = require(script.Parent.Status)

local WAIT_SECONDS = 10
local CAP_HEIGHT = 1 -- the cap part on top of a pillar
local INWARD_STUDS = 2.6 -- the crab sits this far from the pillar's centre, towards the middle of the ring
local HOP_SECONDS = 0.45
local HOP_HEIGHT = 5
local PINCH_SECONDS = 0.5
local PINCH_HEIGHT = 3
local FLASH_SECONDS = 2.5

type Mood = {
	shake: number, -- radians the crab rocks either way
	speed: number, -- rocks per second
	glow: number, -- the Anger highlight's fill transparency
}

local MOODS: { [string]: Mood } = {
	Calm = { shake = 0.04, speed = 1.5, glow = 1 },
	Restless = { shake = 0.14, speed = 5, glow = 0.7 },
	Furious = { shake = 0.3, speed = 11, glow = 0.35 },
}

local crab: Model? = nil
local anger: Highlight? = nil
local halfHeight = 1.5
local shown = false
local holderUserId: number? = nil
local mood = "Calm"
local names: { [number]: string } = {}
local lastSpot: Vector3? = nil -- where the crab last sat, so a hop starts from there
local hopFrom: Vector3? = nil
local hopStart = 0
local pinchStart = -math.huge

local Crab = {}

-- The pillar is looked up each time: with streaming on, a pillar that streams back in is a new instance.
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

-- Where the crab sits on a pillar: on its top, on the side facing the middle of the ring.
local function spotOn(platform: BasePart): Vector3
	local top = platform.Position.Y + platform.Size.Y / 2 + CAP_HEIGHT + halfHeight
	local centre = Vector3.new(platform.Position.X, 0, platform.Position.Z)
	local inward = Vector3.zero
	if centre.Magnitude > 0.01 then
		inward = -centre.Unit * INWARD_STUDS
	end
	return Vector3.new(platform.Position.X + inward.X, top, platform.Position.Z + inward.Z)
end

local function hide()
	local model = crab
	if model ~= nil and shown then
		shown = false
		model.Parent = nil
	end
end

local function step()
	local model = crab
	local holder = holderUserId
	if model == nil or holder == nil then
		hide()
		return
	end
	local platform = platformFor(holder)
	if platform == nil then
		hide()
		return
	end
	local now = os.clock()
	local spot = spotOn(platform)
	local position = spot
	local from = hopFrom
	if from ~= nil then
		local alpha = (now - hopStart) / HOP_SECONDS
		if alpha >= 1 then
			hopFrom = nil
		else
			position = from:Lerp(spot, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * HOP_HEIGHT, 0)
		end
	end
	local sincePinch = now - pinchStart
	if sincePinch < PINCH_SECONDS then
		position += Vector3.new(0, math.sin(sincePinch / PINCH_SECONDS * math.pi) * PINCH_HEIGHT, 0)
	end
	lastSpot = spot
	local look = MOODS[mood] or MOODS.Calm
	local rock = math.sin(now * look.speed * math.pi * 2) * look.shake
	-- It faces the player standing on the pillar.
	local facing = Vector3.new(platform.Position.X, position.Y, platform.Position.Z)
	local frame = CFrame.new(position)
	if (facing - position).Magnitude > 0.01 then
		frame = CFrame.lookAt(position, facing)
	end
	model:PivotTo(frame * CFrame.Angles(0, 0, rock))
	local glow = anger
	if glow ~= nil then
		glow.FillTransparency += (look.glow - glow.FillTransparency) * 0.2
	end
	if not shown then
		shown = true
		model.Parent = workspace
	end
end

function Crab.onState(payload: Net.RoundStatePayload)
	if crab == nil then
		return
	end
	for _, row in payload.ring or {} do
		names[row.userId] = row.name
	end
	local inMatch = payload.phase == "Prompt" or payload.phase == "Reveal"
	local holder = if inMatch then payload.holderUserId else nil
	if holder ~= holderUserId and holder ~= nil and holderUserId ~= nil and lastSpot ~= nil then
		hopFrom = lastSpot
		hopStart = os.clock()
	end
	if holder == nil then
		lastSpot = nil
		hopFrom = nil
	end
	holderUserId = holder
	mood = payload.mood or "Calm"
end

-- CrabPassed: the hop itself follows the next state; this is the moment for the passer's reward.
function Crab.onPassed(payload: Net.CrabPassedPayload)
	if crab == nil then
		return
	end
	Sfx.play("Pop", 0.4)
	if payload.gainedHeart and payload.fromUserId == Players.LocalPlayer.UserId then
		Fx.callout("EXTRA HEART!", Theme.Color.Green)
		Sfx.play("Fanfare", 0.6)
	end
end

-- CrabPinched: the crab jumps, and everyone reads who it got.
function Crab.onPinched(payload: Net.CrabPinchedPayload)
	if crab == nil then
		return
	end
	pinchStart = os.clock()
	local me = payload.userId == Players.LocalPlayer.UserId
	local who = if me then "YOU" else string.upper(names[payload.userId] or "SOMEONE")
	local text = who .. (if payload.eliminated then " SANK!" else " GOT PINCHED!")
	Status.flashTide(text, Theme.Color.Red, FLASH_SECONDS)
	Sfx.play("Wrong", 0.7)
	if me then
		Fx.flash(Theme.Color.Red)
		Fx.shake(0.4, 0.5)
	end
end

function Crab.init()
	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
		local template = if templates ~= nil then templates:WaitForChild("CrazeCrab", WAIT_SECONDS) else nil
		if template == nil or not template:IsA("Model") then
			warn("Crab: ReplicatedStorage.Templates.CrazeCrab is missing; the crab is not shown")
			return
		end
		local model = template:Clone()
		local _, size = model:GetBoundingBox()
		halfHeight = size.Y / 2
		local glow = model:FindFirstChild("Anger")
		anger = if glow ~= nil and glow:IsA("Highlight") then glow else nil
		crab = model
		RunService.RenderStepped:Connect(step)
	end)
end

return Crab
