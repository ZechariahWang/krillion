--!strict
-- Micro-interactions shared by the controllers. Everything else about the UI is set in Studio.

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
	button.MouseButton1Down:Connect(function()
		Tween.play(scale, Theme.Tween.Press, { Scale = 0.96 })
	end)
	local function release()
		Tween.play(scale, Theme.Tween.Press, { Scale = 1 })
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

function Ui.pop(object: GuiObject)
	local scale = scaleOf(object)
	scale.Scale = 0.7
	object.Visible = true
	Tween.play(scale, Theme.Tween.Pop, { Scale = 1 })
end

function Ui.pulse(object: GuiObject, on: boolean)
	local scale = scaleOf(object)
	if on then
		Tween.play(scale, Theme.Tween.Pulse, { Scale = 1.12 })
	else
		Tween.cancel(scale)
		scale.Scale = 1
	end
end

function Ui.clearClones(parent: Instance, templateName: string)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= templateName then
			child:Destroy()
		end
	end
end

function Ui.tierColor(tier: string?): Color3
	if tier == nil then
		return Theme.Color.TextDim
	end
	local color = Theme.Tier[tier]
	if color == nil then
		return Theme.Color.Text
	end
	return color
end

return Ui
