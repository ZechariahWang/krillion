--!strict
-- Shows the crab during a match: one clone of ReplicatedStorage.Templates.CrazeCrab on this client, hovering
-- in the middle of the ring. It faces whoever holds it and blows its authored Bubbles their way, shaking
-- harder and blowing more as its mood sours. The server only says who holds it and its mood; the fuse
-- itself never reaches a client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Status = require(script.Parent.Status)

local WAIT_SECONDS = 10
local FLOAT_ABOVE_TOP = 11 -- the crab hovers this far over the pillar tops, clear of your own character
local AIM_ABOVE_TOP = 3 -- it looks at a point this far over the holder's pillar top: the player
local BOB_HEIGHT = 0.4
local BOB_SPEED = 2
local TURN_SPEED = 8 -- how fast it swings round to a new holder
local CAMERA_BACK = 14 -- the match opens with the camera this far behind you, looking at the middle
local CAMERA_UP = 9
local CAMERA_AIM_ABOVE_TOP = 2
local PINCH_SECONDS = 0.5
local PINCH_HEIGHT = 3
local FLASH_SECONDS = 2.5

type Mood = {
	shake: number, -- radians the crab rocks either way
	speed: number, -- rocks per second
	glow: number, -- the Anger highlight's fill transparency
	bubbles: number, -- bubbles per second
}

local MOODS: { [string]: Mood } = {
	Calm = { shake = 0.04, speed = 1.5, glow = 1, bubbles = 5 },
	Restless = { shake = 0.14, speed = 5, glow = 0.7, bubbles = 12 },
	Furious = { shake = 0.3, speed = 11, glow = 0.35, bubbles = 24 },
}

local crab: Model? = nil
local anger: Highlight? = nil
local bubbles: ParticleEmitter? = nil
local heading: CFrame? = nil -- the way it faces now, turning towards the holder
local shown = false
local lastPhase = ""
local holderUserId: number? = nil
local mood = "Calm"
local names: { [number]: string } = {}
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

local function hide()
	local model = crab
	if model ~= nil and shown then
		shown = false
		heading = nil
		model.Parent = nil
	end
end

local function step(dt: number)
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
	local top = platform.Position.Y + platform.Size.Y / 2
	local position = Vector3.new(0, top + FLOAT_ABOVE_TOP + math.sin(now * BOB_SPEED) * BOB_HEIGHT, 0)
	local sincePinch = now - pinchStart
	if sincePinch < PINCH_SECONDS then
		position += Vector3.new(0, math.sin(sincePinch / PINCH_SECONDS * math.pi) * PINCH_HEIGHT, 0)
	end
	-- It turns to face whoever holds it, aiming up at the player on the pillar.
	local target = Vector3.new(platform.Position.X, top + AIM_ABOVE_TOP, platform.Position.Z)
	local wanted = CFrame.lookAt(position, target).Rotation
	local facing = heading or wanted
	facing = facing:Lerp(wanted, math.min(1, dt * TURN_SPEED))
	heading = facing
	local look = MOODS[mood] or MOODS.Calm
	local rock = math.sin(now * look.speed * math.pi * 2) * look.shake
	model:PivotTo(CFrame.new(position) * facing * CFrame.Angles(0, 0, rock))
	local glow = anger
	if glow ~= nil then
		glow.FillTransparency += (look.glow - glow.FillTransparency) * 0.2
	end
	local stream = bubbles
	if stream ~= nil then
		stream.Rate = look.bubbles
	end
	if not shown then
		shown = true
		model.Parent = workspace
	end
end

-- Turns your camera to the middle of the ring from behind your pillar, once it has streamed in. The
-- camera stays yours to move.
local function faceMiddle()
	local deadline = os.clock() + WAIT_SECONDS
	local platform = platformFor(Players.LocalPlayer.UserId)
	while platform == nil and os.clock() < deadline do
		task.wait(0.1)
		platform = platformFor(Players.LocalPlayer.UserId)
	end
	local camera = workspace.CurrentCamera
	if platform == nil or camera == nil then
		return
	end
	local top = platform.Position.Y + platform.Size.Y / 2
	local flat = Vector3.new(platform.Position.X, 0, platform.Position.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local eye = flat + flat.Unit * CAMERA_BACK + Vector3.new(0, top + CAMERA_UP, 0)
	-- Aimed under the crab, so it shows over your head and not behind it.
	camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, top + CAMERA_AIM_ABOVE_TOP, 0))
end

function Crab.onState(payload: Net.RoundStatePayload)
	if crab == nil then
		return
	end
	if payload.phase == "Starting" and lastPhase ~= "Starting" and payload.playing == true then
		task.spawn(faceMiddle)
	end
	lastPhase = payload.phase
	for _, row in payload.ring or {} do
		names[row.userId] = row.name
	end
	local inMatch = payload.phase == "Prompt" or payload.phase == "Reveal"
	holderUserId = if inMatch then payload.holderUserId else nil
	mood = payload.mood or "Calm"
end

-- CrabPassed: the crab turns with the next state; this is the moment for the passer's reward.
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
		local glow = model:FindFirstChild("Anger")
		anger = if glow ~= nil and glow:IsA("Highlight") then glow else nil
		local stream = model:FindFirstChild("Bubbles", true)
		bubbles = if stream ~= nil and stream:IsA("ParticleEmitter") then stream else nil
		crab = model
		RunService.RenderStepped:Connect(step)
	end)
end

return Crab
