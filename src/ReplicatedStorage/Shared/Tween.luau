--!strict
-- Thin TweenService helper: one live tween per instance, so a new tween always cancels the old one.

local TweenService = game:GetService("TweenService")

local live: { [Instance]: Tween } = {}

local Tween = {}

function Tween.play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local previous = live[instance]
	if previous ~= nil then
		previous:Cancel()
	end
	local tween = TweenService:Create(instance, info, goal)
	live[instance] = tween
	tween.Completed:Once(function()
		if live[instance] == tween then
			live[instance] = nil
		end
	end)
	tween:Play()
	return tween
end

function Tween.cancel(instance: Instance)
	local previous = live[instance]
	if previous ~= nil then
		previous:Cancel()
		live[instance] = nil
	end
end

return Tween
