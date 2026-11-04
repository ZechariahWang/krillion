--!strict
-- Applies equipped cosmetics: the title over a player's head, their pillar skin, their elimination splash
-- and the trail behind them. Titles, splashes and trails are clones of templates under ReplicatedStorage.Templates.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Shop = require(ReplicatedStorage.Shared.Shop)
local DataService = require(script.Parent.DataService)

local TITLE_NAME = "KrillionTitle"
local TRAIL_PREFIX = "KrillionTrail" -- every trail clone in the root part is named with this, for removal
local TRAIL_NAME = "KrillionTrail"

local passLookup: (Player) -> { [string]: boolean } = function()
	return {}
end

local CosmeticService = {}

function CosmeticService.setPassLookup(fn: (Player) -> { [string]: boolean })
	passLookup = fn
end

local function templates(): Folder
	return ReplicatedStorage:WaitForChild("Templates") :: Folder
end

-- The equipped item in `slot`, only if the player still owns it.
function CosmeticService.equipped(player: Player, slot: string): Cosmetics.Item?
	local profile = DataService.get(player)
	if profile == nil then
		return nil
	end
	local id = (profile.equipped :: any)[slot]
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local item = Cosmetics.ById[id]
	if item == nil or not Shop.owns(profile, item, passLookup(player)) then
		return nil
	end
	return item
end

local function colorOf(item: Cosmetics.Item): Color3?
	local rgb = item.color
	if rgb == nil then
		return nil
	end
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function applyTitle(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	if head == nil then
		return
	end
	local old = head:FindFirstChild(TITLE_NAME)
	if old ~= nil then
		old:Destroy()
	end
	local item = CosmeticService.equipped(player, "Title")
	if item == nil then
		return
	end
	local title = (templates():WaitForChild("Title") :: BillboardGui):Clone()
	title.Name = TITLE_NAME
	local label = title:FindFirstChild("Text") :: TextLabel?
	if label ~= nil then
		label.Text = string.upper(item.name)
		local color = colorOf(item)
		if color ~= nil then
			label.TextColor3 = color
		end
	end
	title.Parent = head
end

-- Swaps the trail in the HumanoidRootPart for the equipped one: Templates.Trails.<trail> holds two
-- attachments and a Trail; clones lose the Trail's links to them, so it is re-pointed here.
local function applyTrail(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	for _, child in root:GetChildren() do
		if string.sub(child.Name, 1, #TRAIL_PREFIX) == TRAIL_PREFIX then
			child:Destroy()
		end
	end
	local item = CosmeticService.equipped(player, "Trail")
	local trailName = if item ~= nil then item.trail else nil
	if trailName == nil then
		return
	end
	local folder = templates():FindFirstChild("Trails")
	local template = if folder ~= nil then folder:FindFirstChild(trailName) else nil
	if template == nil then
		warn("CosmeticService: no trail template " .. trailName)
		return
	end
	local top = template:FindFirstChild("TrailTop")
	local bottom = template:FindFirstChild("TrailBottom")
	local trailTemplate = template:FindFirstChild(TRAIL_NAME)
	if top == nil or bottom == nil or trailTemplate == nil or not trailTemplate:IsA("Trail") then
		return
	end
	local topClone = top:Clone() :: Attachment
	topClone.Name = TRAIL_PREFIX .. "Top"
	topClone.Parent = root
	local bottomClone = bottom:Clone() :: Attachment
	bottomClone.Name = TRAIL_PREFIX .. "Bottom"
	bottomClone.Parent = root
	local trail = trailTemplate:Clone()
	trail.Name = TRAIL_NAME
	trail.Attachment0 = topClone
	trail.Attachment1 = bottomClone
	trail.Parent = root
end

function CosmeticService.refresh(player: Player)
	applyTitle(player)
	applyTrail(player)
end

-- Recolours a freshly spawned pillar (and its cap) with the player's skin, if they have one equipped.
-- Skins with a `top` colour give the cap that colour; others get a lightened body colour.
function CosmeticService.applySkin(player: Player, platform: Part)
	local item = CosmeticService.equipped(player, "Skin")
	if item == nil then
		return
	end
	local color = colorOf(item)
	local material = Enum.Material.SmoothPlastic
	if item.material ~= nil then
		material = (Enum.Material :: any)[item.material]
	end
	local cap = platform:FindFirstChild("Cap") :: BasePart?
	if color ~= nil then
		platform.Color = color
		if cap ~= nil then
			local top = item.top
			cap.Color = if top ~= nil then Color3.fromRGB(top[1], top[2], top[3]) else color:Lerp(Color3.new(1, 1, 1), 0.35)
		end
	end
	platform.Material = material
	if cap ~= nil then
		-- Studs only render on Plastic, so plastic-look skins keep the cap's studded top.
		if material == Enum.Material.Plastic or material == Enum.Material.SmoothPlastic then
			cap.Material = Enum.Material.Plastic
		else
			cap.Material = material
		end
	end
end

-- Plays the player's equipped splash where they sank. Players without one keep the default splash.
function CosmeticService.splash(player: Player, position: Vector3)
	local item = CosmeticService.equipped(player, "Splash")
	if item == nil or item.splash == nil then
		return
	end
	local folder = templates():FindFirstChild("Splashes")
	local template = nil
	if folder ~= nil then
		template = folder:FindFirstChild(item.splash) :: BasePart?
	end
	if template == nil then
		return
	end
	local effect = template:Clone()
	effect.Anchored = true
	effect.CanCollide = false
	effect.Transparency = 1
	effect.Position = position
	effect.Parent = workspace
	for _, child in effect:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child:Emit(child:GetAttribute("Burst") or 40)
		end
	end
	Debris:AddItem(effect, 4)
end

function CosmeticService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			applyTitle(player)
			character:WaitForChild("HumanoidRootPart", 5)
			applyTrail(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CosmeticService
