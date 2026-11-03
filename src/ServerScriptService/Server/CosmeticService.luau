--!strict
-- Applies equipped cosmetics: the title over a player's head, their pillar skin, their elimination splash.
-- Titles and splashes are clones of templates authored under ReplicatedStorage.Templates.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Shop = require(ReplicatedStorage.Shared.Shop)
local DataService = require(script.Parent.DataService)

local TITLE_NAME = "KrillionTitle"

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

function CosmeticService.refresh(player: Player)
	applyTitle(player)
end

-- Recolours a freshly spawned pillar (and its cap) with the player's skin, if they have one equipped.
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
			cap.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
		end
	end
	platform.Material = material
	if cap ~= nil then
		cap.Material = material
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
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CosmeticService
