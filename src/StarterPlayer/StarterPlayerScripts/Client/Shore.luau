--!strict
-- Washes the shoreline foam (Arena.Beach.Foam) up the sand and back, on this client. Each authored disc
-- carries Inward (unit Vector3 toward the island), Reach (studs it runs up the beach) and Phase; it slides
-- along Inward on a slow sine, rides up the slope as it goes, and thins out as it pulls back.

local RunService = game:GetService("RunService")

local WAVE_RATE = 0.55 -- radians per second
local SLOPE = 0.4 -- studs the sand rises per stud inward at the waterline (CLAUDE.md beach slope)
local LIFT = 0.06 -- keeps the disc just over the sand
local FADE = 0.35 -- extra transparency when the wave is fully drawn back

-- Resting CFrame and authored transparency, keyed by disc. A plain table: Roblox can drop an Instance's Lua
-- handle while the Instance lives, and a weak entry would re-read a moved disc.
local rest: { [BasePart]: { cframe: CFrame, transparency: number } } = {}

local Shore = {}

local function step()
	local arena = workspace:FindFirstChild("Arena")
	local beach = if arena ~= nil then arena:FindFirstChild("Beach") else nil
	local foam = if beach ~= nil then beach:FindFirstChild("Foam") else nil
	if foam == nil then
		return
	end
	local now = os.clock()
	for _, disc in foam:GetChildren() do
		if not disc:IsA("BasePart") then
			continue
		end
		local inward = disc:GetAttribute("Inward")
		local reach = disc:GetAttribute("Reach")
		local phase = disc:GetAttribute("Phase")
		if typeof(inward) ~= "Vector3" or typeof(reach) ~= "number" or typeof(phase) ~= "number" then
			continue
		end
		local base = rest[disc]
		if base == nil then
			base = { cframe = disc.CFrame, transparency = disc.Transparency }
			rest[disc] = base
		end
		-- 0 at the waterline, 1 at the top of the wash
		local wash = 0.5 + 0.5 * math.sin(now * WAVE_RATE + phase)
		local run = wash * reach
		disc.CFrame = base.cframe + inward * run + Vector3.new(0, run * SLOPE + LIFT * wash, 0)
		disc.Transparency = base.transparency + (1 - wash) * FADE
	end
end

local function forget(disc: Instance)
	if disc:IsA("BasePart") then
		rest[disc] = nil
	end
end

function Shore.init()
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena", 60)
		local beach = if arena ~= nil then arena:WaitForChild("Beach", 60) else nil
		local foam = if beach ~= nil then beach:WaitForChild("Foam", 60) else nil
		if foam ~= nil then
			foam.ChildRemoved:Connect(forget)
		end
	end)
end

return Shore
