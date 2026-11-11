--!strict
-- Drives StarterGui.Lobby for anyone not on a platform: eliminated card, spectating, the late-join card
-- and the spectate button for players who are off a pillar mid-match. JoinCard and WatchButton are
-- Studio templates (ReplicatedStorage.Templates) cloned in here, unless the place authors its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10
local JOIN_TIMEOUT = 4 -- seconds before a JUMP IN press with no answer can be pressed again
local BAR_GAP = 12 -- pixels between the join card and the bar under it
local BOTTOM_GAP = 20 -- pixels from the screen bottom when nothing is under the join card

local gui: Frame
local eliminatedCard: Frame
local eliminatedSubtitle: TextLabel
local spectateButton: TextButton
local spectateBar: Frame
local watchingText: TextLabel
local nextButton: TextButton
local backButton: TextButton
local joinCard: Frame? = nil
local joinSub: TextLabel? = nil
local joinButton: TextButton? = nil
local joinButtonText = "JUMP IN"
local watchButton: TextButton? = nil

local aliveUserIds: { number } = {}
local spectating = false
local spectateIndex = 0
local watchedId = 0 -- the UserId the spectate camera is on
local inMatch = false
local playing = false
local joinOpen = false
local joinRound = 0
local joinPendingSince: number? = nil
local reviveOpen = false -- the revive card is up, so the eliminated card waits behind it
local eliminatedWaiting = false
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

-- The join card sits above whichever bottom-centre bar is showing (the spectate bar or watch button).
local function placeJoinCard(card: Frame)
	local lift = BOTTOM_GAP
	local bottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
	local bars: { GuiObject } = { spectateBar }
	if watchButton ~= nil then
		table.insert(bars, watchButton)
	end
	for _, bar in bars do
		if bar.Visible then
			lift = math.max(lift, bottom - bar.AbsolutePosition.Y + BAR_GAP)
		end
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

-- Shows the card while the server says this player may jump in, and the spectate button for anyone off
-- a pillar mid-match who is not already spectating or looking at the eliminated card.
local function refreshExtras()
	local button = watchButton
	if button ~= nil then
		button.Visible = inMatch
			and not playing
			and not spectating
			and not eliminatedCard.Visible
			and not reviveOpen
			and not eliminatedWaiting
			and #aliveUserIds > 0
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
	if camera ~= nil then
		camera.CameraSubject = ownHumanoid()
	end
	refreshExtras()
end

local function watch(index: number)
	if #aliveUserIds == 0 then
		stopSpectating()
		return
	end
	spectateIndex = ((index - 1) % #aliveUserIds) + 1
	watchedId = aliveUserIds[spectateIndex]
	local target = Players:GetPlayerByUserId(watchedId)
	if target == nil or target.Character == nil then
		return
	end
	local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if humanoid ~= nil and camera ~= nil then
		camera.CameraSubject = humanoid
	end
	watchingText.Text = "WATCHING " .. string.upper(target.DisplayName)
end

local function startSpectating()
	spectating = true
	eliminatedWaiting = false
	eliminatedCard.Visible = false
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
	local watchObject = adopt("WatchButton", "TextButton")
	if watchObject ~= nil then
		local button = watchObject :: TextButton
		Ui.pressable(button)
		button.Activated:Connect(startSpectating)
		watchButton = button
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
		warn("[Lobby] GameUi.Spectate is missing; no eliminated card or spectating")
		return
	end
	local cardFound = waitChild(screen, "EliminatedCard")
	local subtitleFound = waitChild(cardFound, "Subtitle")
	local spectateFound = waitChild(cardFound, "SpectateButton")
	local barFound = waitChild(screen, "SpectateBar")
	local watchingFound = waitChild(barFound, "Watching")
	local nextFound = waitChild(barFound, "NextButton")
	local backFound = waitChild(barFound, "BackButton")
	if missing ~= nil then
		warn("[Lobby] GameUi.Spectate has no " .. missing .. "; no eliminated card or spectating")
		return
	end
	gui = screen
	eliminatedCard = cardFound :: Frame
	eliminatedSubtitle = subtitleFound :: TextLabel
	spectateButton = spectateFound :: TextButton
	spectateBar = barFound :: Frame
	watchingText = watchingFound :: TextLabel
	nextButton = nextFound :: TextButton
	backButton = backFound :: TextButton
	ready = true

	Ui.pressable(spectateButton)
	Ui.pressable(nextButton)
	Ui.pressable(backButton)
	spectateButton.Activated:Connect(startSpectating)
	nextButton.Activated:Connect(function()
		watch(spectateIndex + 1)
	end)
	backButton.Activated:Connect(stopSpectating)
	task.spawn(bindExtras)
end

-- Whether the spectate camera is following someone in the match.
function Lobby.isSpectating(): boolean
	return spectating
end

function Lobby.onEliminated(payload)
	if not ready then
		return
	end
	local text = "YOU MADE IT TO ROUND " .. payload.round
	-- The second line only fits a label that scales or wraps its text.
	if eliminatedSubtitle.TextScaled or eliminatedSubtitle.TextWrapped then
		text ..= if GameConfig.Lobby.QuizEnabled == 1
			then "\nSPECTATE, OR WARM UP FOR " .. Currency.Upper
			else "\nSPECTATE UNTIL THE NEXT MATCH"
	end
	eliminatedSubtitle.Text = text
	-- Both cards are big now, so they never share the screen: the revive choice comes first.
	if reviveOpen then
		eliminatedWaiting = true
	else
		Ui.pop(eliminatedCard, 0.7)
	end
	Fx.flash(Theme.Color.Water)
	Sfx.play("Splash", 0.8)
	refreshExtras()
end

-- RevivePrompt calls this while its card is up. The eliminated card steps aside and comes back when the
-- revive card goes, unless the revive was used (the player is going back onto a pillar).
function Lobby.setReviveOpen(open: boolean, revived: boolean?)
	if not ready then
		return
	end
	reviveOpen = open
	if open then
		if eliminatedCard.Visible then
			eliminatedCard.Visible = false
			eliminatedWaiting = true
		end
	elseif eliminatedWaiting then
		eliminatedWaiting = false
		if revived ~= true and inMatch and not playing and not spectating then
			Ui.pop(eliminatedCard, 0.7)
		end
	end
	refreshExtras()
end

function Lobby.onState(payload)
	if not ready then
		return
	end
	local phase = payload.phase
	inMatch = phase == "Prompt" or phase == "Reveal"
	playing = payload.playing == true
	joinOpen = payload.lateJoinOpen == true
	joinRound = if type(payload.round) == "number" then payload.round else 0
	gui.Visible = inMatch and not playing
	if payload.playing then
		eliminatedWaiting = false
		stopSpectating()
		return
	end

	-- Only real players can be watched: bots (negative ids) have no Player to follow.
	aliveUserIds = {}
	for _, id in payload.aliveUserIds or {} do
		if id > 0 then
			table.insert(aliveUserIds, id)
		end
	end

	if not inMatch then
		eliminatedCard.Visible = false
		eliminatedWaiting = false
		if spectating then
			stopSpectating()
		end
		refreshExtras()
		return
	end

	if spectating then
		local index = table.find(aliveUserIds, watchedId)
		if index ~= nil then
			spectateIndex = index
		else
			watch(spectateIndex)
		end
	end
	refreshExtras()
end

return Lobby
