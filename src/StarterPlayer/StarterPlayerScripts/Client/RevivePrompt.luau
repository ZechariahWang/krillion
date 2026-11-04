--!strict
-- Drives StarterGui.Revive: the short "use a revive?" card shown after sinking, only to players holding one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Lobby = require(script.Parent.Lobby)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local gui: ScreenGui
local card: Frame
local count: TextLabel
local fill: Frame
local token = 0

local RevivePrompt = {}

local function hide(revived: boolean)
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	Lobby.setReviveOpen(false, revived)
end

function RevivePrompt.init(playerGui: PlayerGui)
	gui = playerGui:WaitForChild("Revive") :: ScreenGui
	card = gui:WaitForChild("Card") :: Frame
	count = card:WaitForChild("Count") :: TextLabel
	fill = card:WaitForChild("TimerTrack"):WaitForChild("TimerFill") :: Frame
	local use = card:WaitForChild("UseButton") :: TextButton
	Ui.pressable(use)
	use.MouseButton1Click:Connect(function()
		if not gui.Enabled then
			return
		end
		token += 1
		hide(true)
		Sfx.play("Fanfare", 0.5)
		Net.event("ReviveUse"):FireServer()
	end)
end

function RevivePrompt.onPrompt(payload)
	token += 1
	local mine = token
	count.Text = payload.revives .. " LEFT"
	fill.Size = UDim2.fromScale(1, 1)
	gui.Enabled = true
	Lobby.setReviveOpen(true)
	Ui.pop(card, 0.6)
	Sfx.play("Tick", 0.5, 1.3)
	TweenService:Create(fill, TweenInfo.new(payload.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	task.delay(payload.seconds, function()
		if token == mine then
			hide(false)
		end
	end)
end

return RevivePrompt
