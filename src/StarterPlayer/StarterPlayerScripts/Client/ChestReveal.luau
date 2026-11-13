--!strict
-- Drives SharedUi.ChestReveal (authored in Studio): the moment a chest opens. OPEN in the shop calls
-- ChestReveal.open, which shows the chest at once, shaking harder while the server rolls, then bursts it in
-- the prize's rarity colour and pops the prize card (NEW / DUPLICATE, AGAIN and NICE! buttons).
-- The server's ChestResult decides everything; a refusal hides the reveal (Market shows why).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Chests = require(ReplicatedStorage.Config.Chests)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local Theme = require(ReplicatedStorage.Config.Theme)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Fx)
local Icons = require(script.Parent.Icons)
local ItemIcon = require(script.Parent.ItemIcon)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local Ui = require(script.Parent.Ui)

local WIND_UP = 1.1 -- the chest always shakes at least this long, so even an instant reply builds up
local TIMEOUT = 6 -- no reply by then: give up and close
local TICK_EVERY = 0.13
local RAY_SPIN = 14 -- degrees per second
local CARD_MARGIN = 16 -- pixels the prize card keeps clear of the screen edges
local CONFETTI: { [string]: number } = { Common = 0, Rare = 30, Epic = 60, Legendary = 100, Mythic = 150 }

local screen: Frame? = nil
local cash = 0
local busy = false
local token = 0
local spin: RBXScriptConnection? = nil

local ChestReveal = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function scaleOf(object: Instance): UIScale?
	return object:FindFirstChildOfClass("UIScale")
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local playing = TweenService:Create(object, info, goal)
	playing:Play()
	return playing
end

local function tint(color: Color3)
	local root = screen :: Frame
	local rays = root:FindFirstChild("Rays")
	if rays ~= nil then
		for _, ray in rays:GetChildren() do
			if ray:IsA("Frame") then
				ray.BackgroundColor3 = color
			end
		end
	end
	local glow = root:FindFirstChild("Glow")
	if glow ~= nil and glow:IsA("Frame") then
		glow.BackgroundColor3 = color
	end
end

local function hide()
	token += 1
	busy = false
	if spin ~= nil then
		spin:Disconnect()
		spin = nil
	end
	if screen ~= nil then
		screen.Visible = false
	end
end

local function setButton(button: TextButton, text: string, enabled: boolean)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.65
end

-- The prize card's scale: full size, or smaller on a screen too short or narrow for it (a phone).
local function cardFit(root: Frame, card: Frame, scale: UIScale): number
	local shown = math.max(scale.Scale, 0.01)
	local width = math.max(card.AbsoluteSize.X / shown, 1)
	local height = math.max(card.AbsoluteSize.Y / shown, 1)
	local wide = (root.AbsoluteSize.X - CARD_MARGIN * 2) / width
	local tall = (root.AbsoluteSize.Y - CARD_MARGIN * 2) / height
	return math.clamp(math.min(wide, tall), 0.1, 1)
end

-- Shows the prize. `chest` is the one that was opened, for the AGAIN price.
local function reveal(chest: Chests.Chest, payload: Net.ChestResultPayload)
	local root = screen :: Frame
	local item = if payload.item ~= nil then Cosmetics.ById[payload.item] else nil
	if item == nil then
		hide()
		return
	end
	local rarity = item.rarity
	local color = Theme.Rarity[rarity] or Theme.Color.Yellow
	local rank = Cosmetics.RarityRank[rarity] or 1

	-- Burst: the chest blows up and vanishes in the prize's colour.
	tint(color)
	local chestLabel = root:FindFirstChild("Chest") :: ImageLabel
	local chestScale = scaleOf(chestLabel)
	chestLabel.Rotation = 0
	if chestScale ~= nil then
		tween(chestScale, 0.18, { Scale = 1.7 })
	end
	tween(chestLabel, 0.18, { ImageTransparency = 1 })
	local glow = root:FindFirstChild("Glow") :: Frame
	local glowScale = scaleOf(glow)
	if glowScale ~= nil then
		glowScale.Scale = 0.6
		tween(glowScale, 0.5, { Scale = 1.2 + 0.12 * rank }, Enum.EasingStyle.Back)
	end
	glow.BackgroundTransparency = 0.25
	tween(glow, 0.9, { BackgroundTransparency = 0.8 })
	local rays = root:FindFirstChild("Rays")
	local raysScale = if rays ~= nil then scaleOf(rays) else nil
	if raysScale ~= nil then
		raysScale.Scale = 0.4
		tween(raysScale, 0.6, { Scale = 1 + 0.15 * rank }, Enum.EasingStyle.Back)
	end
	Fx.flash(color)
	Fx.shake(0.25 + 0.08 * rank, 0.25 + 0.15 * rank)
	local confetti = CONFETTI[rarity] or 0
	if confetti > 0 then
		Fx.confetti(confetti, { color, Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.5) })
	end
	Sfx.play("Pop", 0.8, 0.9)
	if rank >= (Cosmetics.RarityRank.Legendary or 4) then
		Sfx.play("Fanfare", 0.8, 1)
	else
		Sfx.play("Ping", 0.8, 0.8 + 0.12 * rank)
	end

	-- The prize card.
	local card = root:FindFirstChild("Card") :: Frame
	local function text(name: string): TextLabel
		return card:FindFirstChild(name) :: TextLabel
	end
	text("Rarity").Text = string.upper(rarity)
	text("Rarity").TextColor3 = color
	local itemIcon = card:FindFirstChild("Icon") :: ImageLabel
	itemIcon.Image = Icons.image(ItemIcon.any(item))
	text("ItemName").Text = string.upper(item.name)
	if payload.duplicate then
		text("Note").Text = "DUPLICATE  |  +" .. Currency.format(payload.refund or 0) .. " BACK"
	else
		text("Note").Text = "NEW!  EQUIPPED"
	end
	local border = card:FindFirstChild("Border")
	if border ~= nil and border:IsA("UIStroke") then
		border.Color = color
	end
	local again = card:FindFirstChild("Again") :: TextButton
	local affordable = cash >= chest.price
	setButton(again, "AGAIN  " .. Currency.format(chest.price), affordable)
	again:SetAttribute("Chest", chest.id)
	card.Visible = true
	local cardScale = scaleOf(card)
	if cardScale ~= nil then
		local full = cardFit(root, card, cardScale)
		cardScale.Scale = 0.3 * full
		tween(cardScale, 0.45, { Scale = full }, Enum.EasingStyle.Back)
	end
	local iconScale = scaleOf(itemIcon)
	if iconScale ~= nil then
		iconScale.Scale = 0.2
		tween(iconScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end
	busy = false
end

-- Shows the chest and asks the server to open it. Does nothing while another chest is still opening.
function ChestReveal.open(chestId: string)
	local root = screen
	local chest = Chests.ById[chestId]
	if root == nil or chest == nil or busy then
		return
	end
	busy = true
	token += 1
	local mine = token
	local started = os.clock()
	local result: Net.ChestResultPayload? = nil

	local color = rgb(chest.color)
	tint(color)
	root.Visible = true
	local card = root:FindFirstChild("Card") :: Frame
	card.Visible = false
	local chestLabel = root:FindFirstChild("Chest") :: ImageLabel
	chestLabel.ImageTransparency = 0
	chestLabel.Rotation = 0
	local chestScale = scaleOf(chestLabel)
	if chestScale ~= nil then
		chestScale.Scale = 0
		tween(chestScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local glow = root:FindFirstChild("Glow") :: Frame
	glow.BackgroundTransparency = 0.7
	local glowScale = scaleOf(glow)
	if glowScale ~= nil then
		glowScale.Scale = 0.8
	end
	local rays = root:FindFirstChild("Rays") :: Frame
	local raysScale = scaleOf(rays)
	if raysScale ~= nil then
		raysScale.Scale = 0.6
	end
	Sfx.play("Pop", 0.6, 0.8)

	if spin ~= nil then
		spin:Disconnect()
	end
	local nextTick = 0
	spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation = (rays.Rotation + RAY_SPIN * dt) % 360
		if result ~= nil and os.clock() - started >= WIND_UP then
			return
		end
		-- Winding up: the chest rocks harder and the ticks climb in pitch until the prize is in.
		local t = math.min((os.clock() - started) / WIND_UP, 1)
		chestLabel.Rotation = math.sin(os.clock() * (18 + 22 * t)) * (4 + 14 * t)
		if glowScale ~= nil then
			glowScale.Scale = 0.8 + 0.35 * t + math.sin(os.clock() * 20) * 0.03
		end
		if os.clock() >= nextTick then
			nextTick = os.clock() + TICK_EVERY * (1 - 0.45 * t)
			Sfx.play("Tick", 0.5, 0.8 + 0.7 * t)
		end
	end)

	local reply: RBXScriptConnection
	reply = Net.event("ChestResult").OnClientEvent:Connect(function(payload)
		if payload.chest ~= chestId then
			return
		end
		reply:Disconnect()
		result = payload
	end)
	Net.event("ChestOpen"):FireServer(chestId)

	task.spawn(function()
		while result == nil and os.clock() - started < TIMEOUT and token == mine do
			task.wait()
		end
		if token ~= mine then
			reply:Disconnect()
			return
		end
		local got = result
		if got == nil then
			-- The server may still open it after we stop waiting, so point the player at their items.
			reply:Disconnect()
			hide()
			Toasts.show("CHEST DELAYED  |  CHECK YOUR ITEMS IN A MOMENT", "info")
			return
		end
		if got.status ~= "ok" then
			-- Market toasts the reason (not enough Shells, cooldown...).
			reply:Disconnect()
			hide()
			return
		end
		local wait = WIND_UP - (os.clock() - started)
		if wait > 0 then
			task.wait(wait)
		end
		if token == mine then
			reveal(chest, got)
		end
	end)
end

function ChestReveal.init(playerGui: PlayerGui)
	task.spawn(function()
		local found = Ui.screen(playerGui, "ChestReveal", 10)
		if found == nil then
			warn("[ChestReveal] SharedUi.ChestReveal is missing; chests open without a reveal")
			return
		end
		screen = found
		found.Visible = false
		local card = found:FindFirstChild("Card") :: Frame
		local again = card:FindFirstChild("Again") :: TextButton
		local done = card:FindFirstChild("Done") :: TextButton
		Ui.pressable(again)
		Ui.pressable(done)
		again.MouseButton1Click:Connect(function()
			local chestId = again:GetAttribute("Chest")
			if not again.Active or busy or type(chestId) ~= "string" then
				return
			end
			ChestReveal.open(chestId)
		end)
		done.MouseButton1Click:Connect(function()
			if busy then
				return
			end
			Sfx.play("Close", 0.5)
			hide()
		end)
	end)
	Net.event("ProfileChanged").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.cash) == "number" then
			cash = payload.cash
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(payload)
		-- A match starting takes over the screen.
		if payload.playing == true and screen ~= nil and screen.Visible then
			hide()
		end
	end)
end

return ChestReveal
