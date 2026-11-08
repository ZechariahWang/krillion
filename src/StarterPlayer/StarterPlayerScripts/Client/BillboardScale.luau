--!strict
-- Shrinks world labels with distance, on this client. Every UIScale named "DistanceScale" inside a BillboardGui
-- (pillar name tags, answer tags, titles, the AFK tag; authored in Studio) is full size up to NEAR_STUDS away
-- and shrinks in proportion beyond that, so a far label stays in scale with its pillar instead of covering it.

local RunService = game:GetService("RunService")

local NEAR_STUDS = 45 -- labels closer than this show at their authored (largest) size
local MIN_SCALE = 0.3 -- never shrink past this, so far labels stay readable
local UPDATE_SECONDS = 0.1

type Entry = { scale: UIScale, billboard: BillboardGui }

local entries: { [UIScale]: Entry } = {}

local BillboardScale = {}

local function add(object: Instance)
	if not object:IsA("UIScale") or object.Name ~= "DistanceScale" then
		return
	end
	local billboard = object:FindFirstAncestorWhichIsA("BillboardGui")
	if billboard == nil then
		return
	end
	entries[object] = { scale = object, billboard = billboard }
end

-- Where the label hangs: its adornee, else the part it is parented under.
local function anchorOf(billboard: BillboardGui): Vector3?
	local target = billboard.Adornee or billboard.Parent
	if target == nil then
		return nil
	end
	local position: Vector3? = nil
	if target:IsA("BasePart") then
		position = target.Position
	elseif target:IsA("Model") then
		position = target:GetPivot().Position
	elseif target:IsA("Attachment") then
		position = target.WorldPosition
	end
	if position == nil then
		return nil
	end
	return position + billboard.StudsOffsetWorldSpace + billboard.StudsOffset
end

local function step()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	for scale, entry in entries do
		if scale.Parent == nil then
			entries[scale] = nil
		else
			local anchor = anchorOf(entry.billboard)
			if anchor ~= nil then
				local distance = (anchor - eye).Magnitude
				local wanted = 1
				if distance > NEAR_STUDS then
					wanted = math.max(NEAR_STUDS / distance, MIN_SCALE)
				end
				scale.Scale = wanted
			end
		end
	end
end

function BillboardScale.init()
	for _, object in workspace:GetDescendants() do
		add(object)
	end
	workspace.DescendantAdded:Connect(add)
	local sinceUpdate = UPDATE_SECONDS
	RunService.Heartbeat:Connect(function(dt)
		sinceUpdate += dt
		if sinceUpdate < UPDATE_SECONDS then
			return
		end
		sinceUpdate = 0
		step()
	end)
end

return BillboardScale
