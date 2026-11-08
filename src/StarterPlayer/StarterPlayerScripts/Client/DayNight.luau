--!strict
-- Runs the day and night cycle on this client: Lighting.ClockTime follows DayCycle from the shared server clock,
-- so every player sees the same sky. The rest of the look (ambient, fog, sky) stays as authored in Studio.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayCycle = require(ReplicatedStorage.Shared.DayCycle)

local UPDATE_SECONDS = 0.1

local DayNight = {}

function DayNight.init()
	local sinceUpdate = UPDATE_SECONDS
	RunService.Heartbeat:Connect(function(dt)
		sinceUpdate += dt
		if sinceUpdate < UPDATE_SECONDS then
			return
		end
		sinceUpdate = 0
		Lighting.ClockTime = DayCycle.clockAt(workspace:GetServerTimeNow())
	end)
end

return DayNight
