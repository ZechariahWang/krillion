--!strict
-- Swims the authored fish and schools in Arena.SeaLife round the island, on this client only. Each child
-- model's Speed attribute is studs per second along its circle round the island centre (sign = direction);
-- a school turns as one model, so its formation holds.

local RunService = game:GetService("RunService")

local WAIT_SECONDS = 30
local BOB_STUDS = 0.6
local BOB_RATE = 1.5 -- radians per second

type Swimmer = {
	model: Model,
	start: CFrame,
	turnRate: number, -- radians per second round the island centre
	phase: number,
}

local swimmers: { Swimmer } = {}
local known: { [Instance]: boolean } = {}

local SeaLife = {}

local function add(child: Instance)
	local speed = child:GetAttribute("Speed")
	if known[child] or not child:IsA("Model") or typeof(speed) ~= "number" then
		return
	end
	local start = child:GetPivot()
	local radius = Vector2.new(start.Position.X, start.Position.Z).Magnitude
	if radius <= 1 then
		return
	end
	known[child] = true
	-- CFrame.Angles turns clockwise seen from above, the opposite way to the authored facing.
	local turnRate = -speed / radius
	table.insert(swimmers, { model = child, start = start, turnRate = turnRate, phase = #swimmers })
end

-- The map is in the place from the start, so fish can still be arriving when this runs.
local function collect(sea: Instance)
	for _, child in sea:GetChildren() do
		add(child)
	end
	sea.ChildAdded:Connect(add)
end

local function step()
	local t = os.clock()
	for _, swimmer in swimmers do
		if swimmer.model.Parent ~= nil then
			local turn = CFrame.Angles(0, swimmer.turnRate * t, 0)
			local bob = Vector3.new(0, math.sin(t * BOB_RATE + swimmer.phase) * BOB_STUDS, 0)
			swimmer.model:PivotTo((turn * swimmer.start) + bob)
		end
	end
end

function SeaLife.init()
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena", WAIT_SECONDS)
		local sea = if arena ~= nil then arena:WaitForChild("SeaLife", WAIT_SECONDS) else nil
		if sea == nil then
			return
		end
		collect(sea)
		RunService.RenderStepped:Connect(step)
	end)
end

return SeaLife
