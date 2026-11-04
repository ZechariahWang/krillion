--!strict
-- The floating prompt screen above the ring: four outward-facing screens showing the prompt and timer
-- during Prompt and Reveal. It hovers above the water and the average alive pillar, so it never blocks the
-- sideways view of other pillars, spins slowly, and fades out for the rest of the match and in the lobby.
-- Each client clones ReplicatedStorage.Templates.Sonar locally (or drives Arena.Sonar if one is placed in
-- Studio), so all motion is local and smooth; the server never moves it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local SCREENS = 4
local FOLLOW_RATE = 4 -- higher catches up faster; the screen eases toward its target height every frame
local SPIN_SPEED = 0.15 -- radians per second
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Fadeable = { instance: Instance, property: string, shown: number }

local model: Model? = nil
local guis: { SurfaceGui } = {}
local fadeables: { Fadeable } = {}
local labels: { [string]: { TextLabel } } = { Round = {}, Prompt = {}, Timer = {} }
local accentFrames: { GuiObject } = {} -- the header bar and the border take the round's colour
local accentStrokes: { UIStroke } = {}
local centre = Vector3.zero
local currentY: number? = nil
local targetY = 0
local angle = 0
local shown = false
local moving = false -- still visible or fading, so the frame step keeps it moving
local fadeToken = 0
local lastPrompt = ""
local pending: Net.RoundStatePayload? = nil

local Sonar = {}

local function eachLabel(name: string, apply: (TextLabel) -> ())
	for _, label in labels[name] do
		apply(label)
	end
end

local function setText(name: string, text: string)
	eachLabel(name, function(label)
		if label.Text ~= text then
			label.Text = text
		end
	end)
end

local function setColor(name: string, color: Color3)
	eachLabel(name, function(label)
		label.TextColor3 = color
	end)
end

-- Fades every part, panel, border and text together. The SurfaceGuis are switched off once hidden,
-- because a SurfaceGui keeps drawing on a fully transparent part.
local function fade(visible: boolean)
	if visible == shown then
		return
	end
	shown = visible
	fadeToken += 1
	local token = fadeToken
	if visible then
		moving = true
		for _, gui in guis do
			gui.Enabled = true
		end
	end
	for _, entry in fadeables do
		Tween.play(entry.instance, FADE, { [entry.property] = if visible then entry.shown else 1 })
	end
	if not visible then
		task.delay(FADE.Time, function()
			if token ~= fadeToken then
				return
			end
			moving = false
			for _, gui in guis do
				gui.Enabled = false
			end
		end)
	end
end

local function collect(sonar: Model)
	for _, object in sonar:GetDescendants() do
		if object:IsA("BasePart") then
			table.insert(fadeables, { instance = object, property = "Transparency", shown = object.Transparency })
			object.Transparency = 1
		elseif object:IsA("SurfaceGui") and object.Name == "Gui" then
			object.Enabled = false
			table.insert(guis, object)
		elseif object:IsA("TextLabel") then
			table.insert(fadeables, { instance = object, property = "TextTransparency", shown = object.TextTransparency })
			object.TextTransparency = 1
			local list = labels[object.Name]
			if list ~= nil then
				table.insert(list, object)
			end
			-- The authored outline follows TextTransparency, so it fades with its text.
			Ui.outline(object, Theme.Stroke.Label)
		elseif object:IsA("Frame") then
			table.insert(fadeables, { instance = object, property = "BackgroundTransparency", shown = object.BackgroundTransparency })
			object.BackgroundTransparency = 1
			if object.Name == "Header" then
				table.insert(accentFrames, object)
			end
		elseif object:IsA("UIStroke") and object.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			table.insert(fadeables, { instance = object, property = "Transparency", shown = object.Transparency })
			object.Transparency = 1
			table.insert(accentStrokes, object)
		end
	end
	if #guis < SCREENS then
		warn(`Sonar: found {#guis} of {SCREENS} screen Guis`)
	end
end

-- Eases the height toward targetY with frame-rate independent smoothing and turns it a little.
local function step(dt: number)
	local sonar = model
	if sonar == nil or not moving or currentY == nil then
		return
	end
	local y = currentY :: number
	y += (targetY - y) * (1 - math.exp(-FOLLOW_RATE * dt))
	currentY = y
	angle = (angle + SPIN_SPEED * dt) % (2 * math.pi)
	sonar:PivotTo(CFrame.new(centre.X, y, centre.Z) * CFrame.Angles(0, angle, 0))
end

-- Above the water and above the average alive pillar, whichever is higher.
local function hoverY(payload: Net.RoundStatePayload): number
	local y = payload.waterY + GameConfig.Sonar.AboveWater
	local total, count = 0, 0
	for _, height in payload.heights or {} do
		total += height
		count += 1
	end
	if count > 0 then
		y = math.max(y, total / count + GameConfig.Sonar.AbovePlayers)
	end
	return y
end

local function headerText(payload: Net.RoundStatePayload): (string, Color3)
	if payload.special == "TidalWave" then
		return `{Theme.Icon.Wave} TIDAL WAVE`, Theme.Header.Danger
	end
	if payload.special == "DoubleLift" then
		return "DOUBLE LIFT", Theme.Header.Good
	end
	return `ROUND {payload.round}`, Theme.Header.Quest
end

function Sonar.onState(payload: Net.RoundStatePayload)
	if model == nil then
		pending = payload
		return
	end
	local phase = payload.phase
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	if not inMatch then
		-- Back in the lobby: the next match's screen rises out of the water again.
		currentY = nil
		lastPrompt = ""
	end
	local visible = phase == "Prompt" or phase == "Reveal"
	if not visible then
		fade(false)
		return
	end

	-- The prompt is cleared on the server once the reveal starts, so the reveal keeps the last one.
	if payload.prompt ~= nil and payload.prompt ~= "" then
		lastPrompt = string.upper(payload.prompt)
	end
	setText("Prompt", if lastPrompt ~= "" then lastPrompt else "…")
	local header, accent = headerText(payload)
	setText("Round", header)
	for _, frame in accentFrames do
		frame.BackgroundColor3 = accent
	end
	for _, stroke in accentStrokes do
		stroke.Color = accent
	end
	if phase == "Prompt" then
		local seconds = math.max(0, math.ceil(payload.yourSecondsLeft or payload.secondsLeft))
		setText("Timer", `{Theme.Icon.Time} {seconds}`)
		setColor("Timer", if seconds <= GameConfig.Round.DangerSeconds then Theme.Color.Red else Theme.Color.Gold)
	else
		setText("Timer", "")
	end

	targetY = hoverY(payload)
	if currentY == nil then
		-- First showing this match: start at the water so it rises into place.
		currentY = payload.waterY
	end
	fade(true)
end

local function bind()
	local arena = workspace:WaitForChild("Arena", WAIT_SECONDS)
	local placed = if arena ~= nil then arena:FindFirstChild("Sonar") else nil
	local sonar: Model
	if placed ~= nil and placed:IsA("Model") then
		sonar = placed
	else
		local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
		local template = if templates ~= nil then templates:WaitForChild("Sonar", WAIT_SECONDS) else nil
		if template == nil or not template:IsA("Model") then
			warn("Sonar: ReplicatedStorage.Templates.Sonar is missing; the floating prompt screen stays hidden")
			return
		end
		sonar = template:Clone()
		sonar.Parent = workspace
	end
	if sonar.PrimaryPart == nil then
		sonar.PrimaryPart = sonar:FindFirstChild("Core") :: BasePart?
	end
	-- Hovers over wherever it was authored; the ring (and the template) are centred on the origin.
	centre = sonar:GetPivot().Position
	collect(sonar)
	model = sonar
	local latest = pending
	if latest ~= nil then
		pending = nil
		Sonar.onState(latest)
	end
end

function Sonar.init(playerGui: PlayerGui)
	task.spawn(bind)
	RunService.RenderStepped:Connect(step)
end

return Sonar
