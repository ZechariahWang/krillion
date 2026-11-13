--!strict
-- Drives every player's head label (the server's clone of ReplicatedStorage.Templates.NameTag on their Head):
-- it shows the AFK row from the player's Afk attribute, and lifts labels that would overlap on screen, so
-- no two ever cover each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LabelSpread = require(ReplicatedStorage.Shared.LabelSpread)

local TAG_NAME = "RareOrSinkName" -- what CosmeticService calls the clone
local SPREAD_GAP = 6 -- pixels left between two labels that were overlapping
local LIFT_SPEED = 12 -- how fast a label slides to its lifted spot
local TEXT_PAD = 16 -- pixels of room counted round a text row's letters

local HeadTags = {}

-- A streamed part that comes back is a new instance, so the label is looked up every time it is used.
local function labelOf(player: Player): BillboardGui?
	local character = player.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	local label = if head ~= nil then head:FindFirstChild(TAG_NAME) else nil
	if label ~= nil and label:IsA("BillboardGui") then
		return label
	end
	return nil
end

-- The AFK row follows the player's Afk attribute, which the server sets (SettingsService).
local function showAfk(player: Player, label: BillboardGui)
	local main = label:FindFirstChild("Main")
	local row = if main ~= nil then main:FindFirstChild("Afk") else nil
	if row ~= nil and row:IsA("GuiObject") then
		row.Visible = player:GetAttribute("Afk") == true
	end
end

local function rowWidth(row: GuiObject): number
	if row:IsA("TextLabel") then
		return math.min(row.AbsoluteSize.X, row.TextBounds.X + TEXT_PAD)
	end
	return row.AbsoluteSize.X
end

-- The label's box on screen before any lift: its visible rows, standing on the point over the head.
local function boxOf(label: BillboardGui, camera: Camera): LabelSpread.Box?
	local head = label.Parent
	local main = label:FindFirstChild("Main")
	if head == nil or not head:IsA("BasePart") or main == nil or not label.Enabled then
		return nil
	end
	local world = head.Position + Vector3.new(0, label.StudsOffset.Y, 0)
	local point = camera:WorldToViewportPoint(world)
	if point.Z <= 0 or (label.MaxDistance > 0 and point.Z > label.MaxDistance) then
		return nil
	end
	local width = 0
	local height = 0
	for _, row in main:GetChildren() do
		if row:IsA("GuiObject") and row.Visible then
			width = math.max(width, rowWidth(row))
			height += row.AbsoluteSize.Y
		end
	end
	if width <= 0 or height <= 0 then
		return nil
	end
	return { x = point.X - width / 2, y = point.Y - height, width = width, height = height, depth = point.Z }
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local boxed: { BillboardGui } = {}
	local boxes: { LabelSpread.Box } = {}
	for _, player in Players:GetPlayers() do
		local label = labelOf(player)
		if label ~= nil then
			showAfk(player, label)
			local box = boxOf(label, camera)
			if box ~= nil then
				table.insert(boxed, label)
				table.insert(boxes, box)
			else
				label.StudsOffsetWorldSpace = Vector3.zero
			end
		end
	end
	local lifts = LabelSpread.lifts(boxes, SPREAD_GAP)
	local studsPerDepth = 2 * math.tan(math.rad(camera.FieldOfView) / 2) / camera.ViewportSize.Y
	local blend = math.min(1, dt * LIFT_SPEED)
	for index, label in boxed do
		local wanted = lifts[index] * boxes[index].depth * studsPerDepth
		local now = label.StudsOffsetWorldSpace.Y
		label.StudsOffsetWorldSpace = Vector3.new(0, now + (wanted - now) * blend, 0)
	end
end

function HeadTags.init()
	-- Every frame: a label is cloned afresh when its character respawns or changes cosmetics.
	RunService.RenderStepped:Connect(step)
end

return HeadTags
