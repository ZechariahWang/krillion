--!strict
-- The client side of the paid extras that live outside the shop window:
--   Pets   every player's equipped pet (RareOrSinkPet attribute) swims beside them, drawn locally from
--          ReplicatedStorage.Templates.Pets.<name> (a Model authored in Studio)
--   Toys   the lobby THROW key (LobbyUi.Rail.RailFrame.ToyButton) and key T: pick a player, the server
--          checks it, then every client flies Templates.Toys.<toy> to them and the target gets a splat
--          (SharedUi.Fx.Splat when authored, a coloured flash otherwise)
--   Chests what a ChestOpen gave, as a toast (confetti for Legendary and up)
--   Shop   why the server refused a Shells buy (ShopResult), as a toast
--   Themes your equipped dive card theme, handed to DiveCard
--   Nudges a one-time Starter Pack reminder and a "2x Shells would have paid" line after a match, once
--          per visit each, and only while those products can actually be bought.
-- Missing templates or UI just switch their part off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Shop = require(ReplicatedStorage.Shared.Shop)
local DiveCard = require(script.Parent.DiveCard)
local Fx = require(script.Parent.Fx)
local Rail = require(script.Parent.Rail)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local PET_ATTRIBUTE = "RareOrSinkPet"
local PET_OFFSET = CFrame.new(2.6, 1.2, 2.2) -- beside and a little behind the owner's root part
-- Pet models are built nose along +X; this turns them to swim the way their owner faces (-Z).
local PET_FACING = CFrame.Angles(0, math.pi / 2, 0)
local PET_FOLLOW = 8 -- how quickly a pet catches up (higher is snappier)
local PET_BOB = 0.35 -- studs up and down
local AIM_SECONDS = 6 -- how long the THROW key waits for you to pick a player
local PICK_RADIUS = 160 -- screen pixels around the cursor that key T looks for a target in
local SPLAT_FADE = 0.6
local NUDGE_DELAY = 4 -- seconds after the results screen before a nudge, so it never covers the scores

local player = Players.LocalPlayer
local petFolder: Folder
local pets: { [Player]: { model: Model, name: string } } = {}
local profile: Profile.Profile = Profile.new()
local passes: { [string]: boolean } = {}
local playing = false
local toyButton: TextButton? = nil
local splat: Frame? = nil
local aimingUntil = 0
local nudgedStarter = false
local nudgedDouble = false
-- Shells paid for answers, survival and the win since the last match ended, for the 2x Shells nudge.
local MATCH_REASONS = { answer = true, survive = true, win = true }
local matchEarned = 0

local Market = {}

local function templateFolder(name: string): Instance?
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	return if templates ~= nil then templates:FindFirstChild(name) else nil
end

local function rootOf(target: Player): BasePart?
	local character = target.Character
	return if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Pets ------------------------------------------------------------------------------------------------------

local function removePet(owner: Player)
	local pet = pets[owner]
	if pet ~= nil then
		pet.model:Destroy()
		pets[owner] = nil
	end
end

local function updatePet(owner: Player)
	local name = owner:GetAttribute(PET_ATTRIBUTE)
	local current = pets[owner]
	if typeof(name) ~= "string" or name == "" then
		removePet(owner)
		return
	end
	if current ~= nil and current.name == name then
		return
	end
	removePet(owner)
	local folder = templateFolder("Pets")
	local template = if folder ~= nil then folder:FindFirstChild(name) else nil
	if template == nil or not template:IsA("Model") then
		return
	end
	local model = template:Clone()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	local root = rootOf(owner)
	if root ~= nil then
		model:PivotTo(root.CFrame * PET_OFFSET * PET_FACING)
	end
	model.Parent = petFolder
	pets[owner] = { model = model, name = name }
end

local function watchPlayer(owner: Player)
	owner:GetAttributeChangedSignal(PET_ATTRIBUTE):Connect(function()
		updatePet(owner)
	end)
	updatePet(owner)
end

local function stepPets(dt: number)
	local now = os.clock()
	local alpha = 1 - math.exp(-PET_FOLLOW * dt)
	for owner, pet in pets do
		local root = rootOf(owner)
		if root == nil or owner.Parent == nil then
			continue
		end
		local bob = math.sin(now * 2 + owner.UserId % 7) * PET_BOB
		local goal = root.CFrame * PET_OFFSET * CFrame.new(0, bob, 0) * PET_FACING
		local here = pet.model:GetPivot()
		-- Too far behind (a teleport to a pillar or the lobby): jump straight there.
		if (here.Position - goal.Position).Magnitude > 40 then
			pet.model:PivotTo(goal)
		else
			pet.model:PivotTo(here:Lerp(goal, alpha))
		end
	end
end

-- Toys ------------------------------------------------------------------------------------------------------

local function equippedToy(): Cosmetics.Item?
	local id = profile.equipped.Toy
	local item = if id ~= nil and id ~= "" then Cosmetics.ById[id] else nil
	if item == nil or item.slot ~= "Toy" or not Shop.owns(profile, item, passes) then
		return nil
	end
	return item
end

local function refreshToyButton()
	local button = toyButton
	if button ~= nil then
		button.Visible = equippedToy() ~= nil and not playing
	end
end

local function throwAt(target: Player)
	if target == player or playing then
		return
	end
	aimingUntil = 0
	Net.event("ToyThrow"):FireServer(target.UserId)
end

-- The player whose character is under the screen point, if any.
local function playerAt(screen: Vector2): Player?
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { petFolder }
	if player.Character ~= nil then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if result == nil then
		return nil
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	while model ~= nil do
		local owner = Players:GetPlayerFromCharacter(model)
		if owner ~= nil then
			return owner
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- The other player drawn closest to the screen point, within PICK_RADIUS pixels.
local function playerNear(screen: Vector2): Player?
	local camera = workspace.CurrentCamera
	local best: Player? = nil
	local bestDistance = PICK_RADIUS
	for _, other in Players:GetPlayers() do
		local root = if other ~= player then rootOf(other) else nil
		if root ~= nil then
			local point, visible = camera:WorldToViewportPoint(root.Position)
			if visible then
				local distance = (Vector2.new(point.X, point.Y) - screen).Magnitude
				if distance < bestDistance then
					best = other
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function startAiming()
	if equippedToy() == nil or playing then
		return
	end
	aimingUntil = os.clock() + AIM_SECONDS
	Toasts.show("CLICK A PLAYER TO THROW", "info")
end

local function showSplat(color: Color3)
	local frame = splat
	if frame == nil then
		Fx.flash(color)
		return
	end
	frame.Visible = true
	for _, blob in frame:GetDescendants() do
		if blob:IsA("Frame") then
			blob.BackgroundColor3 = color
			blob.BackgroundTransparency = 0.1
			TweenService:Create(blob, TweenInfo.new(SPLAT_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, GameConfig.Toys.SplatSeconds), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end
	task.delay(GameConfig.Toys.SplatSeconds + SPLAT_FADE, function()
		frame.Visible = false
	end)
end

local function toyColor(toy: string): Color3
	for _, item in Cosmetics.List do
		if item.toy == toy and item.color ~= nil then
			return Color3.fromRGB(item.color[1], item.color[2], item.color[3])
		end
	end
	return Color3.fromRGB(230, 50, 40)
end

-- Every client flies the toy from thrower to target along a short arc, then bursts it.
local function onToyHit(payload: Net.ToyHitPayload)
	local from = Players:GetPlayerByUserId(payload.from)
	local to = Players:GetPlayerByUserId(payload.to)
	local start = if from ~= nil then rootOf(from) else nil
	local finish = if to ~= nil then rootOf(to) else nil
	if start == nil or finish == nil then
		return
	end
	local folder = templateFolder("Toys")
	local template = if folder ~= nil then folder:FindFirstChild(payload.toy) else nil
	local color = toyColor(payload.toy)
	local projectile: PVInstance
	if template ~= nil and (template:IsA("BasePart") or template:IsA("Model")) then
		projectile = template:Clone() :: PVInstance
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1.2, 1.2, 1.2)
		ball.Color = color
		ball.Material = Enum.Material.SmoothPlastic
		projectile = ball
	end
	for _, part in projectile:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanQuery = false
	end
	projectile.Parent = workspace
	local flight = GameConfig.Toys.FlightSeconds
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - started) / flight)
		local a = start.Position + Vector3.new(0, 1.5, 0)
		local b = finish.Position + Vector3.new(0, 1, 0)
		local height = math.min(12, (b - a).Magnitude * 0.25)
		local position = a:Lerp(b, t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		projectile:PivotTo(CFrame.new(position) * CFrame.Angles(t * 8, t * 5, 0))
		if t >= 1 then
			connection:Disconnect()
			projectile:Destroy()
			Sfx.play("Splash", 0.5, 1.4)
			if to == player then
				showSplat(color)
			end
		end
	end)
	if from == player then
		Sfx.play("Pop", 0.5)
	end
end

local function onInput(input: InputObject, processed: boolean)
	if processed or playing then
		return
	end
	if input.KeyCode == Enum.KeyCode.T then
		if equippedToy() == nil then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local target = playerNear(mouse)
		if target ~= nil then
			throwAt(target)
		else
			startAiming()
		end
		return
	end
	local isClick = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	if isClick and os.clock() < aimingUntil then
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local target = playerAt(point) or playerNear(point)
		if target ~= nil then
			throwAt(target)
		end
	end
end

-- Chests ----------------------------------------------------------------------------------------------------

local CHEST_MESSAGES: { [string]: string } = {
	no_shells = "NOT ENOUGH " .. Currency.Upper .. " FOR THAT CHEST",
	limit = "THAT'S A LOT OF CHESTS  |  TAKE A BREAK",
	restricted = "CHESTS AREN'T AVAILABLE WHERE YOU LIVE",
	cooldown = "ONE CHEST AT A TIME",
	unknown = "CHESTS AREN'T READY YET  |  TRY AGAIN SHORTLY",
	refunded = "THAT CHEST JAMMED  |  " .. Currency.Upper .. " REFUNDED",
}

-- ChestReveal shows a prize; this only explains a refusal.
local function onChestResult(payload: Net.ChestResultPayload)
	local message = CHEST_MESSAGES[payload.status]
	if message ~= nil then
		Toasts.show(message, "bad")
	end
end

local SHOP_MESSAGES: { [string]: string } = {
	cash = "NOT ENOUGH " .. Currency.Upper .. " FOR THAT",
	owned = "YOU ALREADY OWN THAT",
	unknown = "THAT CAN'T BE BOUGHT RIGHT NOW",
}

-- A Shells buy the server refused after CONFIRM.
local function onShopResult(payload)
	if type(payload) ~= "table" then
		return
	end
	local message = SHOP_MESSAGES[payload.status]
	if message ~= nil then
		Toasts.show(message, "bad")
	end
end

-- Nudges ----------------------------------------------------------------------------------------------------

local function onShellsEarned(payload)
	if type(payload) == "table" and MATCH_REASONS[payload.reason] and type(payload.amount) == "number" then
		matchEarned += payload.amount
	end
end

local function onMatchEnded()
	local earned = matchEarned
	matchEarned = 0
	task.delay(NUDGE_DELAY, function()
		if not nudgedStarter and profile.claimed.StarterPack ~= true and Products.StarterPack.productId ~= 0 then
			nudgedStarter = true
			Toasts.show(
				"STARTER PACK  |  "
					.. Currency.format(Products.StarterPack.cash)
					.. " + PET + SKIN FOR R$ "
					.. Products.StarterPack.robux
					.. " IN THE SHOP",
				"info"
			)
			return
		end
		if nudgedDouble or passes.DoubleCash == true or Products.Passes.DoubleCash == 0 then
			return
		end
		if earned <= 0 then
			return
		end
		-- What the same match pays with 2x Shells on top of everything you already have.
		local now = Economy.multiplier(passes.Vip == true, false, Shop.petBonus(profile, passes))
		local with = Economy.multiplier(passes.Vip == true, true, Shop.petBonus(profile, passes))
		local extra = math.floor(earned * with / now) - earned
		if extra <= 0 then
			return
		end
		nudgedDouble = true
		Toasts.show("2X " .. Currency.Upper .. " WOULD HAVE PAID +" .. Currency.digits(extra) .. " MORE THIS MATCH", "info")
	end)
end

-- Profile and state -----------------------------------------------------------------------------------------

local function onProfile(payload)
	profile = Profile.fromStored(payload)
	passes = payload.passes or {}
	local id = profile.equipped.CardTheme
	local item = if id ~= nil and id ~= "" then Cosmetics.ById[id] else nil
	if item ~= nil and item.card ~= nil and Shop.owns(profile, item, passes) then
		DiveCard.setTheme(item.card)
	else
		DiveCard.setTheme(nil)
	end
	refreshToyButton()
end

local function onState(payload)
	playing = payload.playing == true
	if playing then
		aimingUntil = 0
	end
	refreshToyButton()
end

function Market.init(playerGui: PlayerGui)
	petFolder = Instance.new("Folder")
	petFolder.Name = "RareOrSinkPets"
	petFolder.Parent = workspace
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(removePet)
	RunService.RenderStepped:Connect(stepPets)

	task.spawn(function()
		local button = Rail.button("ToyButton")
		if button ~= nil then
			toyButton = button
			button.Activated:Connect(function()
				Sfx.play("Pop", 0.5)
				startAiming()
			end)
			refreshToyButton()
		end
		local fx = Ui.screen(playerGui, "Fx", 10)
		local found = if fx ~= nil then fx:FindFirstChild("Splat") else nil
		if found ~= nil and found:IsA("Frame") then
			found.Visible = false
			splat = found
		end
	end)
	UserInputService.InputBegan:Connect(onInput)

	Net.event("ChestResult").OnClientEvent:Connect(onChestResult)
	Net.event("ShopResult").OnClientEvent:Connect(onShopResult)
	Net.event("ToyHit").OnClientEvent:Connect(onToyHit)
	Net.event("ProfileChanged").OnClientEvent:Connect(onProfile)
	Net.event("RoundState").OnClientEvent:Connect(onState)
	Net.event("MatchEnded").OnClientEvent:Connect(onMatchEnded)
	Net.event("ShellsEarned").OnClientEvent:Connect(onShellsEarned)
end

return Market
