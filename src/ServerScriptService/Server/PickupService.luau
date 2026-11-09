--!strict
-- Shells lying around the island to pick up between rounds: clones of ReplicatedStorage.Templates.ShellPickup
-- (a Model: the Hitbox the server watches, and the Visual scallop that Client/Pickups floats and spins) dropped
-- on the sand and the deck (never in the tank), one every GameConfig.Pickups.SpawnSeconds up to Max. Walking
-- into one takes it and pays Pickups.Shells, up to Pickups.SessionCap per visit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local StoreService = require(script.Parent.StoreService)

local FOLDER_NAME = "ShellPickups"
local DROP_HEIGHT = 40 -- the ray down onto the island starts this high
local LIFT = 0 -- the template's Visual sits above its own origin
local ISLAND_X = 92 -- half-width of the island top (CLAUDE.md: x -96..96, z -96..80)
local ISLAND_Z_MIN = -92
local ISLAND_Z_MAX = 76
local TANK_CLEAR = 52 -- no shells within this radius of the tank centre (glass and rim rocks)
local LOWEST = -1 -- below this the ray hit the slope under water
local HIGHEST = 25
local FLAT_NORMAL_Y = 0.7 -- a part's surface counts as floor when its normal points at least this far up
local LIFETIME_SECONDS = 120 -- an untaken shell goes after this, so the island restocks somewhere else

local folder: Folder
local taken: { [Player]: number } = {} -- Shells picked up this visit
local rng = Random.new()

local PickupService = {}

local function template(): Model?
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local found = if templates ~= nil then templates:FindFirstChild("ShellPickup") else nil
	return if found ~= nil and found:IsA("Model") then found else nil
end

-- Sand, or the flat top of a solid lobby part (the deck, the stairs), not a lamp, a sign or bunting.
local function isWalkable(hit: RaycastResult): boolean
	if hit.Instance == workspace.Terrain then
		return true
	end
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby == nil or not hit.Instance:IsDescendantOf(lobby) then
		return false
	end
	local part = hit.Instance
	if not part:IsA("BasePart") or not part.CanCollide then
		return false
	end
	return hit.Normal.Y > FLAT_NORMAL_Y
end

-- A random standing spot on the island: sand or the lobby deck, out of the water and clear of the tank.
local function findSpot(): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Bunting and other walk-through decor let the ray fall on to what is under it.
	params.RespectCanCollide = true
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, 20 do
		local x = rng:NextNumber(-ISLAND_X, ISLAND_X)
		local z = rng:NextNumber(ISLAND_Z_MIN, ISLAND_Z_MAX)
		if Vector2.new(x, z).Magnitude < TANK_CLEAR then
			continue
		end
		local hit = workspace:Raycast(Vector3.new(x, DROP_HEIGHT, z), Vector3.new(0, -(DROP_HEIGHT + 10), 0), params)
		if hit == nil then
			continue
		end
		if isWalkable(hit) and hit.Material ~= Enum.Material.Water and hit.Position.Y > LOWEST and hit.Position.Y < HIGHEST then
			return hit.Position + Vector3.new(0, LIFT, 0)
		end
	end
	return nil
end

local function collect(shell: Model, player: Player)
	if shell.Parent == nil then
		return
	end
	-- A player at the cap leaves the shell for someone else.
	local config = GameConfig.Pickups
	local soFar = taken[player] or 0
	if soFar >= config.SessionCap then
		return
	end
	shell:Destroy()
	taken[player] = soFar + config.Shells
	StoreService.grantShells(player, config.Shells, "pickup")
end

local function spawnOne()
	local proto = template()
	local spot = findSpot()
	if proto == nil or spot == nil then
		return
	end
	local shell = proto:Clone()
	shell:PivotTo(CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local hitbox = shell:FindFirstChild("Hitbox")
	if hitbox == nil or not hitbox:IsA("BasePart") then
		return
	end
	hitbox.Touched:Connect(function(other)
		local character = other:FindFirstAncestorOfClass("Model")
		local player = if character ~= nil then Players:GetPlayerFromCharacter(character) else nil
		if player ~= nil then
			collect(shell, player)
		end
	end)
	shell.Parent = folder
	task.delay(LIFETIME_SECONDS, function()
		if shell.Parent ~= nil then
			shell:Destroy()
		end
	end)
end

function PickupService.start()
	if GameConfig.Pickups.Enabled ~= 1 then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		taken[player] = nil
	end)
	task.spawn(function()
		-- Wait for the map, then keep the island stocked.
		workspace:WaitForChild("Lobby", 30)
		while true do
			if #folder:GetChildren() < GameConfig.Pickups.Max then
				spawnOne()
			end
			task.wait(GameConfig.Pickups.SpawnSeconds)
		end
	end)
end

return PickupService
