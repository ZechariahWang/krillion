--!strict
-- Micro-interactions shared by the controllers. Everything about the UI layout is set in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Config.Theme)
local Tween = require(ReplicatedStorage.Shared.Tween)

local Ui = {}

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Parent = object
	end
	return scale :: UIScale
end

function Ui.pressable(button: GuiButton)
	local scale = scaleOf(button)
	button.MouseEnter:Connect(function()
		Tween.play(scale, Theme.Tween.Press, { Scale = 1.06 })
	end)
	button.MouseButton1Down:Connect(function()
		Tween.play(scale, Theme.Tween.Press, { Scale = 0.92 })
	end)
	local function release()
		Tween.play(scale, Theme.Tween.Pop, { Scale = 1 })
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- Grows in from small with a bounce.
function Ui.pop(object: GuiObject)
	local scale = scaleOf(object)
	scale.Scale = 0.6
	object.Visible = true
	Tween.play(scale, Theme.Tween.Pop, { Scale = 1 })
end

-- Drops in from big, like a stamp hitting the screen.
function Ui.slam(object: GuiObject)
	local scale = scaleOf(object)
	scale.Scale = 2
	object.Visible = true
	Tween.play(scale, Theme.Tween.Slam, { Scale = 1 })
end

-- A quick bump, used on every timer tick.
function Ui.bump(object: GuiObject, size: number)
	local scale = scaleOf(object)
	scale.Scale = size
	Tween.play(scale, Theme.Tween.Tick, { Scale = 1 })
end

-- Wiggles side to side for `seconds`.
function Ui.shake(object: GuiObject, seconds: number)
	task.spawn(function()
		local steps = math.floor(seconds / 0.04)
		for step = 1, steps do
			local direction = 1
			if step % 2 == 0 then
				direction = -1
			end
			object.Rotation = direction * 7
			task.wait(0.04)
		end
		object.Rotation = 0
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
