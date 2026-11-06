--!strict
-- Surge feedback: the rumble, splash and "THE WATER RISES" callout as the water starts to move, then once it
-- settles a close-call heartbeat (or a quiet SAFE flash on the tide chip) and a toast naming who sank.
-- The need hint on the tide chip during the prompt lives in Status.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local TideRules = require(ReplicatedStorage.Shared.Tide)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Status = require(script.Parent.Status)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local GUI_WAIT = 10
local SUNK_NAMES = 4 -- names listed in the sunk toast before "AND N MORE"
local SAFE_FLASH_SECONDS = 1.5
local BEAT_SECONDS = 0.6 -- one lub-dub every this long
local DUB_DELAY = 0.22
local VIGNETTE_PEAK = 0.6 -- band transparency at the lub; the dub is a touch softer
local VIGNETTE_FADE = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local WOBBLE_STUDS = 0.22
local WOBBLE_SECONDS = 0.5

local lastWaterY = 0
local aliveBefore: { number }? = nil -- alive ids when this surge started
local wasPlaying = false
local names: { [number]: string } = {} -- userId -> name from the last reveal, bots included

local edges: Frame? = nil
local bands: { Frame } = {}
local heartbeatToken = 0
local wobbleToken = 0
local random = Random.new()

local Tide = {}

local function pulse(peak: number)
	for _, band in bands do
		band.BackgroundTransparency = peak
		Tween.play(band, VIGNETTE_FADE, { BackgroundTransparency = 1 })
	end
end

-- Two lub-dubs with the red edge bands throbbing in time.
local function heartbeat()
	heartbeatToken += 1
	local token = heartbeatToken
	local frame = edges
	if frame ~= nil then
		frame.Visible = true
	end
	task.spawn(function()
		for _ = 1, 2 do
			if token ~= heartbeatToken then
				return
			end
			pulse(VIGNETTE_PEAK)
			Sfx.play("Heartbeat", 0.9, 0.9)
			task.wait(DUB_DELAY)
			pulse(VIGNETTE_PEAK + 0.15)
			Sfx.play("Heartbeat", 1, 0.6)
			task.wait(BEAT_SECONDS - DUB_DELAY)
		end
		task.wait(VIGNETTE_FADE.Time)
		if token == heartbeatToken and frame ~= nil then
			frame.Visible = false
		end
	end)
end

-- A small fading wobble through Humanoid.CameraOffset, so the camera scripts never drift.
local function wobble()
	local character = Players.LocalPlayer.Character
	local found = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if found == nil then
		return
	end
	local humanoid: Humanoid = found
	wobbleToken += 1
	local token = wobbleToken
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if token ~= wobbleToken or t >= WOBBLE_SECONDS or humanoid.Parent == nil then
			connection:Disconnect()
			if token == wobbleToken then
				humanoid.CameraOffset = Vector3.zero
			end
			return
		end
		local size = WOBBLE_STUDS * (1 - t / WOBBLE_SECONDS)
		humanoid.CameraOffset = Vector3.new(random:NextNumber(-size, size), random:NextNumber(-size, size), 0)
	end)
end

local function oneDecimal(value: number): string
	return string.format("%.1f", math.max(0, value))
end

local function closeCall(margin: number)
	local spare = oneDecimal(margin)
	local text = if spare == "0.0" then "CLOSE CALL!  |  NOTHING TO SPARE" else "CLOSE CALL!  |  ONLY " .. spare .. " TO SPARE"
	Fx.callout(text, Theme.Color.Yellow)
	heartbeat()
	wobble()
end

-- Who went under in this surge. Players who left the server are not "sunk"; bots (negative ids) stay in.
local function announceSunk(after: { number })
	local before = aliveBefore
	if before == nil then
		return
	end
	local me = Players.LocalPlayer.UserId
	local sunkNames: { string } = {}
	local sunkCount = 0
	local iSank = false
	for _, id in TideRules.sunk(before, after) do
		local player = if id > 0 then Players:GetPlayerByUserId(id) else nil
		if id > 0 and player == nil then
			continue
		end
		sunkCount += 1
		if id == me then
			iSank = true
			continue
		end
		local name = names[id] or (if player ~= nil then player.DisplayName else nil)
		if name ~= nil then
			table.insert(sunkNames, name)
		end
	end
	if iSank then
		Toasts.show("THE TIDE GOT YOU!", "bad")
	end
	local text = TideRules.sunkText(sunkNames, SUNK_NAMES)
	if text ~= nil then
		Toasts.show(text, "info")
	elseif sunkCount == 0 and #after >= 2 then
		Toasts.show("EVERYONE STAYED AFLOAT!", "good")
	end
end

local function onSurge(payload)
	if payload.waterY == lastWaterY then
		-- First Surge broadcast: the water is about to move. A faint rumble, then a firmer one on the jump.
		aliveBefore = payload.aliveUserIds
		wasPlaying = payload.playing == true
		if wasPlaying then
			Fx.callout("THE WATER RISES +" .. oneDecimal(payload.surge), Theme.Color.Water)
		end
		Fx.shake(GameConfig.Water.CreepSeconds, 0.06)
		task.delay(GameConfig.Water.CreepSeconds, function()
			Fx.shake(GameConfig.Water.JumpSeconds + 0.2, 0.3)
			Sfx.play("Splash", 0.6)
		end)
		return
	end
	-- Second Surge broadcast: the water has settled. A sinking player hears it from Lobby and the toast below.
	if payload.playing and wasPlaying then
		local margin = TideRules.margin(payload.height, payload.waterY)
		if margin < GameConfig.Round.CloseCallStuds then
			closeCall(margin)
		else
			Status.flashTide("SAFE  |  +" .. oneDecimal(margin), Theme.Color.Green, SAFE_FLASH_SECONDS)
			Sfx.play("Ping", 0.5)
		end
	end
	announceSunk(payload.aliveUserIds or {})
	aliveBefore = nil
	wasPlaying = false
end

-- Binds StarterGui.Vignette without blocking the other controllers; with it missing the heartbeat is sound only.
function Tide.init(playerGui: PlayerGui)
	task.spawn(function()
		local gui = Ui.screen(playerGui, "Vignette", GUI_WAIT)
		local found = if gui ~= nil then gui:WaitForChild("Edges", GUI_WAIT) else nil
		if found == nil or not found:IsA("Frame") then
			warn("[Tide] StarterGui.Vignette.Edges is missing; the close-call heartbeat has no red edges")
			return
		end
		local frame = found :: Frame
		frame.Visible = false
		for _, child in frame:GetChildren() do
			if child:IsA("Frame") then
				local band = child :: Frame
				band.BackgroundColor3 = Theme.Header.Danger
				band.BackgroundTransparency = 1
				table.insert(bands, band)
			end
		end
		edges = frame
	end)
end

function Tide.onState(payload)
	local phase = payload.phase
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	if not inMatch then
		lastWaterY = 0
		aliveBefore = nil
		wasPlaying = false
		table.clear(names)
		return
	end
	if phase == "Surge" then
		onSurge(payload)
	end
	lastWaterY = payload.waterY
end

-- Remembers the reveal rows' names for the "SUNK: ..." toast.
function Tide.onReveal(payload)
	if type(payload) ~= "table" or type(payload.rows) ~= "table" then
		return
	end
	for _, row in payload.rows do
		if type(row) == "table" and type(row.userId) == "number" and type(row.name) == "string" then
			names[row.userId] = row.name
		end
	end
end

return Tide
