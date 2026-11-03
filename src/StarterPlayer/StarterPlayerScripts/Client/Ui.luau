--!strict
-- Micro-interactions shared by the controllers. Everything about the UI layout is set in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local Ui = {}

-- Every animated element has a UIScale authored in Studio; without one, scale animations are skipped.
local function scaleOf(object: GuiObject): UIScale?
	return object:FindFirstChildOfClass("UIScale")
end

local basePositions: { [GuiObject]: UDim2 } = {}

-- Hover brightens the panel slightly; press dips the scale a hair.
function Ui.pressable(button: GuiButton)
	local scale = scaleOf(button)
	if scale == nil then
		return
	end
	local restTransparency = button.BackgroundTransparency
	local hoverTransparency = math.max(0, restTransparency - 0.15)
	button.MouseEnter:Connect(function()
		Tween.play(button, Theme.Tween.Hover, { BackgroundTransparency = hoverTransparency })
	end)
	button.MouseLeave:Connect(function()
		Tween.play(button, Theme.Tween.Hover, { BackgroundTransparency = restTransparency })
		Tween.play(scale, Theme.Tween.Hover, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Tween.play(scale, Theme.Tween.Press, { Scale = 0.98 })
	end)
	button.MouseButton1Up:Connect(function()
		Tween.play(scale, Theme.Tween.Hover, { Scale = 1 })
	end)
end

-- Shows an element with a short settle from 96% scale. No overshoot.
function Ui.appear(object: GuiObject)
	object.Visible = true
	local scale = scaleOf(object)
	if scale == nil then
		return
	end
	scale.Scale = 0.96
	Tween.play(scale, Theme.Tween.Enter, { Scale = 1 })
end

-- A small tick, used on timer seconds and counters.
function Ui.bump(object: GuiObject, size: number)
	local scale = scaleOf(object)
	if scale == nil then
		return
	end
	scale.Scale = size
	Tween.play(scale, Theme.Tween.Tick, { Scale = 1 })
end

-- A short horizontal nudge, the "no" gesture for a rejected answer.
function Ui.nudge(object: GuiObject)
	local base = basePositions[object]
	if base == nil then
		base = object.Position
		basePositions[object] = base
	end
	task.spawn(function()
		local offsets = { 6, -6, 3, 0 }
		for _, offset in offsets do
			local goal = UDim2.new(base.X.Scale, base.X.Offset + offset, base.Y.Scale, base.Y.Offset)
			Tween.play(object, Theme.Tween.Nudge, { Position = goal })
			task.wait(0.06)
		end
		object.Position = base
	end)
end

-- Removes rows cloned from a template, leaving the template and any other children (titles) alone.
function Ui.clearClones(parent: Instance, templateName: string, clonePrefix: string)
	for _, child in parent:GetChildren() do
		local isClone = string.sub(child.Name, 1, #clonePrefix) == clonePrefix
		if isClone and child.Name ~= templateName then
			child:Destroy()
		end
	end
end

function Ui.tierColor(tier: string?): Color3
	if tier == nil then
		return Theme.Color.Grey
	end
	local color = Theme.Tier[tier]
	if color == nil then
		return Theme.Color.Ink
	end
	return color
end

-- Green while there is plenty of time, then yellow, then red.
function Ui.timerColor(fraction: number): Color3
	if fraction > 0.5 then
		return Theme.Color.Green
	end
	if fraction > 0.25 then
		return Theme.Color.Yellow
	end
	return Theme.Color.Red
end

return Ui
