--!strict
-- Drives StarterGui.Lobby for anyone not on a platform: status banner, eliminated card, spectating.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local gui: ScreenGui
local banner: Frame
local bannerTitle: TextLabel
local bannerText: TextLabel
local eliminatedCard: Frame
local eliminatedSubtitle: TextLabel
local spectateButton: TextButton
local spectateBar: Frame
local watchingText: TextLabel
local nextButton: TextButton
local backButton: TextButton

local aliveUserIds: { number } = {}
local spectating = false
local spectateIndex = 0

local Lobby = {}

local function ownHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function stopSpectating()
	spectating = false
	spectateBar.Visible = false
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraSubject = ownHumanoid()
	end
end

local function watch(index: number)
	if #aliveUserIds == 0 then
		stopSpectating()
		return
	end
	spectateIndex = ((index - 1) % #aliveUserIds) + 1
	local target = Players:GetPlayerByUserId(aliveUserIds[spectateIndex])
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
	eliminatedCard.Visible = false
	spectateBar.Visible = true
	watch(1)
end

function Lobby.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Lobby") :: ScreenGui
	banner = gui:WaitForChild("Banner") :: Frame
	bannerTitle = banner:WaitForChild("Header"):WaitForChild("BannerTitle") :: TextLabel
	bannerText = banner:WaitForChild("BannerText") :: TextLabel
	eliminatedCard = gui:WaitForChild("EliminatedCard") :: Frame
	eliminatedSubtitle = eliminatedCard:WaitForChild("Subtitle") :: TextLabel
	spectateButton = eliminatedCard:WaitForChild("SpectateButton") :: TextButton
	spectateBar = gui:WaitForChild("SpectateBar") :: Frame
	watchingText = spectateBar:WaitForChild("Watching") :: TextLabel
	nextButton = spectateBar:WaitForChild("NextButton") :: TextButton
	backButton = spectateBar:WaitForChild("BackButton") :: TextButton

	Ui.pressable(spectateButton)
	Ui.pressable(nextButton)
	Ui.pressable(backButton)
	spectateButton.Activated:Connect(startSpectating)
	nextButton.Activated:Connect(function()
		watch(spectateIndex + 1)
	end)
	backButton.Activated:Connect(stopSpectating)
end

function Lobby.onEliminated(payload)
	eliminatedSubtitle.Text = "You made it to round " .. payload.round
	Ui.slam(eliminatedCard)
	Fx.flash(Theme.Color.Water)
	Fx.shake(0.5, 0.6)
	Sfx.play("Splash", 0.8)
end

function Lobby.onState(payload)
	local phase = payload.phase
	local inMatch = phase == "Prompt" or phase == "Reveal" or phase == "Surge"
	gui.Enabled = not payload.playing
	if payload.playing then
		stopSpectating()
		return
	end

	aliveUserIds = payload.aliveUserIds or {}
	-- During a match the Hud prompt card takes the top of the screen instead.
	banner.Visible = not inMatch
	if phase == "Waiting" then
		bannerTitle.Text = "WAITING FOR PLAYERS"
		bannerText.Text = payload.playerCount .. " / " .. payload.minPlayers
	elseif phase == "Intermission" then
		bannerTitle.Text = "DIVING IN"
		bannerText.Text = tostring(payload.secondsLeft)
	elseif inMatch then
		bannerTitle.Text = "ROUND " .. payload.round
		bannerText.Text = payload.alive .. " ALIVE"
	else
		bannerTitle.Text = "NEXT DIVE IN"
		bannerText.Text = tostring(payload.secondsLeft)
	end

	if not inMatch then
		eliminatedCard.Visible = false
		if spectating then
			stopSpectating()
		end
		return
	end

	if spectating then
		local stillAlive = false
		for _, id in aliveUserIds do
			if id == aliveUserIds[spectateIndex] then
				stillAlive = true
			end
		end
		if not stillAlive then
			watch(spectateIndex)
		end
	end
end

return Lobby
