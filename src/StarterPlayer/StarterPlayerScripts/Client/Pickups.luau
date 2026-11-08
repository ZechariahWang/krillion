--!strict
-- Floats and spins the Visual scallop of every shell in workspace.ShellPickups, on this client. The server
-- never moves them, so a shell that streams back in starts from its resting pivot again.

local RunService = game:GetService("RunService")

local HOVER = 0.9 -- studs above the resting pivot, at the middle of the bob
local BOB = 0.3 -- studs up and down
local BOB_RATE = 2.2 -- radians per second
local SPIN_RATE = 1.4 -- radians per second

-- Resting pivots, keyed by the Visual model. Not a weak table: Roblox may drop an Instance's Lua handle while
-- the Instance lives, and a dropped entry would re-read the lifted pivot and drift the shell upward.
local rest: { [Model]: CFrame } = {}

local Pickups = {}

local function step()
	local folder = workspace:FindFirstChild("ShellPickups")
	if folder == nil then
		return
	end
	local now = os.clock()
	for index, shell in folder:GetChildren() do
		local visual = shell:FindFirstChild("Visual")
		if not shell:IsA("Model") or visual == nil or not visual:IsA("Model") then
			continue
		end
		local base = rest[visual]
		if base == nil then
			base = visual:GetPivot()
			rest[visual] = base
		end
		local phase = index * 0.7
		local lift = HOVER + math.sin(now * BOB_RATE + phase) * BOB
		visual:PivotTo(base * CFrame.new(0, lift, 0) * CFrame.Angles(0, now * SPIN_RATE + phase, 0))
	end
end

local function forget(shell: Instance)
	local visual = shell:FindFirstChild("Visual")
	if visual ~= nil and visual:IsA("Model") then
		rest[visual] = nil
	end
end

function Pickups.init()
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		local folder = workspace:WaitForChild("ShellPickups", 60)
		if folder ~= nil then
			folder.ChildRemoved:Connect(forget)
		end
	end)
end

return Pickups
