--!strict
-- Drives GameUi.Revive: the short card shown after sinking when a revive is on offer (Economy.reviveOffer).
-- kind "free" is the Second Chance pass's free revive, "stock" uses one you own, "buy" is Revive Now for
-- Robux (the server revives on the receipt). The card says which in its Count line and button.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Lobby = require(script.Parent.Lobby)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local WAIT_SECONDS = 10

local gui: Frame
local card: Frame
local count: TextLabel
local fill: Frame
local use: TextButton
local useText = "USE" -- the authored button text, for a stocked revive
local token = 0
local offer: Net.RevivePromptPayload? = nil
local ready = false
local missing: string? = nil

local RevivePrompt = {}

-- WaitForChild with a timeout. Once one child is missing the rest are skipped, so init gives up quickly.
local function waitChild(parent: Instance?, name: string): Instance?
	if parent == nil or missing ~= nil then
		return nil
	end
	local found = parent:WaitForChild(name, WAIT_SECONDS)
	if found == nil then
		missing = name
	end
	return found
end

local function hide(revived: boolean)
	if not gui.Visible then
		return
	end
	gui.Visible = false
	offer = nil
	Lobby.setReviveOpen(false, revived)
end

function RevivePrompt.init(playerGui: PlayerGui)
	local screen = Ui.screen(playerGui, "Revive", WAIT_SECONDS)
	if screen == nil then
		warn("[RevivePrompt] GameUi.Revive is missing; no revive card")
		return
	end
	local cardFound = waitChild(screen, "Card")
	local countFound = waitChild(cardFound, "Count")
	local trackFound = waitChild(cardFound, "TimerTrack")
	local fillFound = waitChild(trackFound, "TimerFill")
	local useFound = waitChild(cardFound, "UseButton")
	if missing ~= nil then
		warn("[RevivePrompt] GameUi.Revive has no " .. missing .. "; no revive card")
		return
	end
	gui = screen
	card = cardFound :: Frame
	count = countFound :: TextLabel
	fill = fillFound :: Frame
	use = useFound :: TextButton
	useText = use.Text
	ready = true
	Ui.pressable(use)
	use.MouseButton1Click:Connect(function()
		local current = offer
		if not gui.Visible or current == nil then
			return
		end
		if current.kind == "buy" then
			-- The card stays up until the receipt revives you (or the window runs out).
			local productId = current.productId or 0
			if productId ~= 0 then
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
			end
			return
		end
		token += 1
		hide(true)
		Sfx.play("Fanfare", 0.5)
		Net.event("ReviveUse"):FireServer()
	end)
	-- A finished Revive Now purchase: the server puts you back, so the card can go.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local current = offer
		if userId ~= Players.LocalPlayer.UserId or not purchased or current == nil or current.kind ~= "buy" then
			return
		end
		if productId == current.productId then
			token += 1
			hide(true)
			Sfx.play("Fanfare", 0.5)
		end
	end)
end

function RevivePrompt.onPrompt(payload: Net.RevivePromptPayload)
	if not ready then
		return
	end
	token += 1
	local mine = token
	offer = payload
	local kind = payload.kind or "stock"
	if kind == "free" then
		count.Text = "SECOND CHANCE"
		use.Text = "FREE REVIVE"
	elseif kind == "buy" then
		count.Text = "JUMP BACK IN"
		use.Text = "REVIVE  R$ " .. tostring(payload.robux or 0)
	else
		count.Text = payload.revives .. " LEFT"
		use.Text = useText
	end
	fill.Size = UDim2.fromScale(1, 1)
	gui.Visible = true
	Lobby.setReviveOpen(true)
	Ui.pop(card, 0.6)
	Sfx.play("Tick", 0.5, 1.3)
	TweenService:Create(fill, TweenInfo.new(payload.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	task.delay(payload.seconds, function()
		if token == mine then
			hide(false)
		end
	end)
end

return RevivePrompt
