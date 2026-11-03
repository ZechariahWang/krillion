--!strict
-- The server teleports you between the lobby and your pillar. If you were walking, the Animate script
-- is never told your speed changed and keeps looping the walk while you stand still. Bumping the
-- humanoid through Landed makes it re-fire Running with the real speed, so Animate picks idle or walk.

local Players = game:GetService("Players")

local SETTLE_SECONDS = 0.15 -- let the teleport land before re-checking

local AnimationReset = {}

local function reset()
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Landed)
end

function AnimationReset.init()
	Players.LocalPlayer:GetAttributeChangedSignal("Playing"):Connect(function()
		task.delay(SETTLE_SECONDS, reset)
	end)
end

return AnimationReset
