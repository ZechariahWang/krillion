--!strict
-- Icons are ImageLabels authored in ReplicatedStorage.Templates.Icons, one per name ("Shell", "Trophy"...).
-- Most icons are placed in Studio and never touched. A controller asks here only when the icon depends on
-- data: a toast's kind, a quest's kind, a shop item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WAIT_SECONDS = 10

local Icons = {}

local folder: Instance? = nil
local looked = false

local function library(): Instance?
	if looked then
		return folder
	end
	looked = true
	local templates = ReplicatedStorage:WaitForChild("Templates", WAIT_SECONDS)
	if templates ~= nil then
		folder = templates:WaitForChild("Icons", WAIT_SECONDS)
	end
	if folder == nil then
		warn("Icons: ReplicatedStorage.Templates.Icons is missing; data-driven icons stay blank")
	end
	return folder
end

-- The image of the authored icon with this name, or "" when there is none.
function Icons.image(name: string): string
	local found = library()
	if found == nil then
		return ""
	end
	local icon = found:FindFirstChild(name)
	if icon ~= nil and icon:IsA("ImageLabel") then
		return icon.Image
	end
	return ""
end

local reserved: { [UIPadding]: UDim } = setmetatable({}, { __mode = "k" }) :: any

-- Shows or hides the authored "Icon" that sits in a label's left padding. While hidden, the left padding
-- matches the right one, so the text is centred again.
function Icons.show(label: GuiObject, shown: boolean)
	local icon = label:FindFirstChild("Icon")
	local padding = label:FindFirstChildOfClass("UIPadding")
	if icon == nil or not icon:IsA("GuiObject") or padding == nil then
		return
	end
	if reserved[padding] == nil then
		reserved[padding] = padding.PaddingLeft
	end
	icon.Visible = shown
	if shown then
		padding.PaddingLeft = reserved[padding]
	else
		padding.PaddingLeft = padding.PaddingRight
	end
end

return Icons
