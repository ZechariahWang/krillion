--!strict
-- Drives GameUi.Spectate for anyone not on a platform: spectating and the late-join card. The small eye
-- button in the top-left (Rail.WatchButton) is always there in the lobby; it starts spectating when a match
-- has anyone left in it, players and bots alike, and says so when there is nobody to watch. A player who
-- sinks just lands in the lobby, with no card in the way. JoinCard is a Studio template
-- (ReplicatedStorage.Templates) cloned in here, unless the place authors its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Fx)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)
local Windows = require(script.Parent.Windows)

local WAIT_SECONDS = 10
local JOIN_TIMEOUT = 4 -- seconds before a JUMP IN press with no answer can be pressed again
local BAR_GAP = 12 -- pixels between the join card and the bar under it
local BOTTOM_GAP = 20 -- pixels from the screen bottom when nothing is under the join card

local gui: Frame
local spectateBar: Frame
local watchingText: TextLabel
local nextButton: TextButton
local backButton: TextButton
local joinCard: Frame? = nil
local joinSub: TextLabel? = nil
local joinButton: TextButton? = nil
local joinButtonText = "JUMP IN"
local watchBound = false -- the top-left spectate button has its click connected

local aliveUserIds: { number } = {}
local spectating = false
local spectateIndex = 0
local watchedId = 0 -- the UserId the spectate camera is on
local inMatch = false
local playing = false
local joinOpen = false
local joinRound = 0
local joinPendingSince: number? = nil
local ready = false
local missing: string? = nil

local Lobby = {}

local function ownHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

-- The join card sits above the spectate bar when that is showing.
local function placeJoinCard(card: Frame)
	local lift = BOTTOM_GAP
	local bottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
	if spectateBar.Visible then
		lift = math.max(lift, bottom - spectateBar.AbsolutePosition.Y + BAR_GAP)
	end
	card.Position = UDim2.new(card.Position.X.Scale, card.Position.X.Offset, 1, -math.floor(lift + 0.5))
end

local function setJoinPending(pending: boolean)
	joinPendingSince = if pending then os.clock() else nil
	local button = joinButton
	if button ~= nil then
		button.Text = if pending then "..." else joinButtonText
	end
end

local startSpectating: () -> ()

-- The small eye button in the top-left (authored as Rail.WatchButton; Rail places it on the top bar line).
-- Rail starts after this controller, so the button is looked up when it is needed.
local function watchButton(): TextButton?
	local button = Rail.button("WatchButton")
	if button ~= nil and not watchBound then
		watchBound = true
		button.Activated:Connect(function()
			if inMatch and not playing and #aliveUserIds > 0 then
				startSpectating()
			else
				Ui.nudge(button)
				Toasts.show("NOBODY TO WATCH RIGHT NOW", "info")
			end
		end)
	end
	return button
end

-- Shows the card while the server says this player may jump in. The spectate button is up whenever you are
-- in the lobby with no window open; it only steps aside for the spectate bar.
local function refreshExtras()
	local button = watchButton()
	if button ~= nil then
		button.Visible = not playing and not spectating and not Windows.anyOpen()
	end
	local card = joinCard
	if card == nil then
		return
	end
	local since = joinPendingSince
	if since ~= nil and os.clock() - since > JOIN_TIMEOUT then
		setJoinPending(false)
	end
	local show = joinOpen and not playing
	if show then
		local sub = joinSub
		if sub ~= nil then
			sub.Text = "ROUND " .. joinRound .. "  |  JUMP IN NOW"
		end
		placeJoinCard(card)
		if not card.Visible then
			Ui.appear(card)
		end
	else
		card.Visible = false
		setJoinPending(false)
	end
end

local function stopSpectating()
	spectating = false
	spectateBar.Visible = false
	local camera = workspace.CurrentCamera
	local humanoid = ownHumanoid()
	if camera ~= nil and humanoid ~= nil then
		camera.CameraSubject = humanoid
	end
	refreshExtras()
end

-- What the camera follows for this id, and the name to show: a player's humanoid, or a bot's rig on its
-- pillar (RoundService names the pillar's owner in its OwnerName attribute). An id is a player's when a
-- Player has it, never by its sign: players in a Studio test server have negative ids, as bots do.
local function targetOf(userId: number): (Instance?, string)
	local target = Players:GetPlayerByUserId(userId)
	if target ~= nil then
		local character = target.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		return humanoid, target.DisplayName
	end
	local folder = workspace:FindFirstChild("Platforms")
	if folder == nil then
		return nil, "BOT"
	end
	for _, platform in folder:GetChildren() do
		if platform:GetAttribute("OwnerUserId") == userId then
			local rig = platform:FindFirstChild("BotRig")
			local head = if rig ~= nil then rig:FindFirstChild("Head") else nil
			local name = platform:GetAttribute("OwnerName")
			return head, if typeof(name) == "string" then name else "BOT"
		end
	end
	return nil, "BOT"
end

local function watch(index: number)
	if #aliveUserIds == 0 then
		stopSpectating()
		return
	end
	spectateIndex = ((index - 1) % #aliveUserIds) + 1
	watchedId = aliveUserIds[spectateIndex]
	local subject, name = targetOf(watchedId)
	local camera = workspace.CurrentCamera
	if camera ~= nil and subject ~= nil and (subject:IsA("Humanoid") or subject:IsA("BasePart")) then
		camera.CameraSubject = subject
		watchingText.Text = "WATCHING " .. string.upper(name)
	else
		-- Not streamed in yet: the bar says so, and the next state update tries again.
		watchingText.Text = "FINDING " .. string.upper(name) .. "..."
	end
end

function startSpectating()
	spectating = true
	spectateBar.Visible = true
	watch(1)
	refreshExtras()
end

local function requestJoin()
	if joinPendingSince ~= nil or not joinOpen then
		return
	end
	setJoinPending(true)
	Sfx.play("Pop", 0.6)
	Net.event("JoinMatch"):FireServer()
end

-- An element authored under StarterGui.Lobby wins; otherwise the git template is cloned in.
-- Waits for the template, so call it off the init thread.
local function adopt(name: string, className: string): GuiObject?
	local existing = gui:FindFirstChild(name)
	if existing ~= nil and existing:IsA(className) then
		return existing :: GuiObject
	end
	local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
	local template = if templates ~= nil then templates:WaitForChild(name, WAIT_SECONDS) else nil
	if template == nil or not template:IsA(className) then
		warn("Lobby: no " .. name .. " template; that part of the lobby is off")
		return nil
	end
	local clone = template:Clone() :: GuiObject
	clone.Visible = false
	clone.Parent = gui
	return clone
end

local function bindExtras()
	local card = adopt("JoinCard", "Frame")
	if card ~= nil then
		local sub = card:FindFirstChild("Sub")
		if sub ~= nil and sub:IsA("TextLabel") then
			joinSub = sub
		end
		local button = card:FindFirstChild("JoinButton")
		if button ~= nil and button:IsA("TextButton") then
			joinButton = button
			joinButtonText = button.Text
			Ui.pressable(button)
			button.Activated:Connect(requestJoin)
		end
		joinCard = card :: Frame
	end
	refreshExtras()
end

-- WaitForChild with a timeout. Once one child is missing the rest are skipped, so init gives up quickly.
local function waitChild(parent: Instance?, name: string): Instance?
	if parent == nil or missing ~= nil then
		return nil
	end
	local found = parent:WaitForChild(name, WAIT_SECONDS)
	if found == nil then
		missing = name
	end
	return found
end

function Lobby.init(playerGui: PlayerGui)
	local screen = Ui.screen(playerGui, "Spectate", WAIT_SECONDS)
	if screen == nil then
		warn("[Lobby] GameUi.Spectate is missing; no spectating")
		return
	end
	local barFound = waitChild(screen, "SpectateBar")
	local watchingFound = waitChild(barFound, "Watching")
	local nextFound = waitChild(barFound, "NextButton")
	local backFound = waitChild(barFound, "BackButton")
	if missing ~= nil then
		warn("[Lobby] GameUi.Spectate has no " .. missing .. "; no spectating")
		return
	end
	gui = screen
	spectateBar = barFound :: Frame
	watchingText = watchingFound :: TextLabel
	nextButton = nextFound :: TextButton
	backButton = backFound :: TextButton
	ready = true

	Ui.pressable(nextButton)
	Ui.pressable(backButton)
	nextButton.Activated:Connect(function()
		watch(spectateIndex + 1)
	end)
	local prevButton = spectateBar:FindFirstChild("PrevButton")
	if prevButton ~= nil and prevButton:IsA("TextButton") then
		Ui.pressable(prevButton)
		prevButton.Activated:Connect(function()
			watch(spectateIndex - 1)
		end)
	end
	backButton.Activated:Connect(stopSpectating)
	Windows.Changed.connect(refreshExtras)
	task.spawn(bindExtras)
end

-- Whether the spectate camera is following someone in the match.
function Lobby.isSpectating(): boolean
	return spectating
end

-- You sank: a flash and a splash, you are in the lobby, and a toast says how far you got and that the eye
-- button lets you watch the rest.
function Lobby.onEliminated(payload)
	if not ready then
		return
	end
	playing = false
	Fx.flash(Theme.Color.Water)
	Sfx.play("Splash", 0.8)
	local reached = if type(payload) == "table" and type(payload.round) == "number" then payload.round else nil
	local text = if reached ~= nil then "YOU'RE OUT IN ROUND " .. reached else "YOU'RE OUT"
	Toasts.show(text .. "  |  TAP THE EYE TO WATCH", "info")
	refreshExtras()
end

-- JoinResult {status, message} from the server after a JUMP IN press.
function Lobby.onJoinResult(payload)
	if not ready then
		return
	end
	setJoinPending(false)
	if type(payload) ~= "table" or type(payload.message) ~= "string" then
		return
	end
	local status = payload.status
	local kind = "bad"
	if status == "joined" then
		kind = "good"
		joinOpen = false
	elseif status == "not_ready" then
		kind = "info"
	end
	Toasts.show(payload.message, kind)
	refreshExtras()
end

function Lobby.onState(payload)
	if not ready then
		return
	end
	local phase = payload.phase
	inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	playing = payload.playing == true
	joinOpen = payload.lateJoinOpen == true
	joinRound = if type(payload.round) == "number" then payload.round else 0
	gui.Visible = inMatch and not playing
	if payload.playing then
		if spectating then
			stopSpectating()
		else
			refreshExtras()
		end
		return
	end

	-- Everyone still in can be watched, bots included; never yourself.
	aliveUserIds = {}
	for _, id in payload.aliveUserIds or {} do
		if id ~= Players.LocalPlayer.UserId then
			table.insert(aliveUserIds, id)
		end
	end

	if not inMatch then
		if spectating then
			stopSpectating()
		end
		refreshExtras()
		return
	end

	if spectating then
		-- Stay on the same one while they are in (pointing the camera again, in case their character was
		-- not streamed in before); move on when they are out.
		local index = table.find(aliveUserIds, watchedId)
		watch(index or spectateIndex)
	end
	refreshExtras()
end

return Lobby
