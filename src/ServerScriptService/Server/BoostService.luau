--!strict
-- In-match boosts: Hint (a masked Rare/Deep Cut answer) and ExtraTime (+10 s for you only).
-- Paid from the boost inventory first, then Shells; Robux products only add inventory. A Robux buy made
-- mid-prompt is applied when its receipt lands (the client asks with pay "inventory" and the server
-- remembers the request), so a slow receipt never falls through to spending Shells.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Boosts = require(ReplicatedStorage.Shared.Boosts)
local Net = require(ReplicatedStorage.Shared.Net)
local AnswerService = require(script.Parent.AnswerService)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local StoreService = require(script.Parent.StoreService)

local KINDS = { Hint = true, ExtraTime = true }

local usage: { [Player]: Boosts.Usage } = {}
local hinted: { [Player]: { [string]: boolean } } = {} -- answers already hinted to this player this prompt
local lastRequest: { [Player]: number } = {}
-- A boost bought with Robux that is waiting for its receipt: applied by the product handler if it lands
-- before `expires`, otherwise the bought boost just stays in the inventory.
local pending: { [Player]: { kind: string, expires: number } } = {}

local BoostService = {}

local function usageOf(player: Player): Boosts.Usage
	local found = usage[player]
	if found == nil then
		found = { round = Boosts.newUses(), match = Boosts.newUses() }
		usage[player] = found
	end
	return found
end

-- Boosts this player used in the current round, by kind.
function BoostService.usesFor(player: Player): Net.BoostUses
	local round = usageOf(player).round
	return { Hint = round.Hint, ExtraTime = round.ExtraTime }
end

local function costOf(kind: string): number
	if kind == "Hint" then
		return GameConfig.Boosts.HintShells
	end
	return GameConfig.Boosts.ExtraTimeShells
end

local function inventoryOf(player: Player, kind: string): number
	local profile = DataService.get(player)
	if profile == nil then
		return 0
	end
	return if kind == "Hint" then profile.hints else profile.extraTimes
end

local function reply(player: Player, kind: string, status: string, extra: { [string]: any }?): string
	local payload: { [string]: any } = { kind = kind, status = status, uses = BoostService.usesFor(player) }
	if extra ~= nil then
		for key, value in extra do
			payload[key] = value
		end
	end
	Net.event("BoostResult"):FireClient(player, payload)
	return status
end

-- The hint this player would get now, without using it: display spelling, tier name, bank answer.
local function findHint(player: Player): (string?, string?, string?)
	local answers = AnswerService.currentAnswersByTier()
	if answers == nil then
		return nil, nil, nil
	end
	local excluded = AnswerService.lockedCorrected()
	for answer in hinted[player] or {} do
		excluded[answer] = true
	end
	return Boosts.pickHint(answers, GameConfig.Boosts.HintMinTier, GameConfig.Boosts.HintMaxTier, excluded, math.random())
end

-- Uses one boost for the player. pay: "auto" (inventory, then Shells) | "inventory" (a Robux purchase
-- that just landed; never falls back to Shells). Returns the BoostResult status it sent.
-- Everything is checked before anything is paid, so no path needs a refund.
function BoostService.apply(player: Player, kind: string, pay: string?): string
	if GameConfig.Boosts.Enabled == 0 then
		return reply(player, kind, "disabled")
	end
	local open = AnswerService.boostStatus(player)
	if open ~= "ok" then
		return reply(player, kind, open)
	end
	local allowed = Boosts.canUse(usageOf(player), kind)
	if allowed ~= "ok" then
		return reply(player, kind, allowed)
	end
	local display: string?, tier: string?, answer: string? = nil, nil, nil
	if kind == "Hint" then
		display, tier, answer = findHint(player)
		if display == nil or tier == nil or answer == nil then
			return reply(player, kind, "none")
		end
	end

	if inventoryOf(player, kind) > 0 then
		DataService.spendBoost(player, kind)
	elseif pay == "inventory" then
		-- The receipt has not landed yet; the product handler finishes this request when it does.
		pending[player] = { kind = kind, expires = os.clock() + GameConfig.Boosts.PurchaseWaitSeconds }
		return reply(player, kind, "pending")
	elseif not StoreService.spendShells(player, costOf(kind), "spend") then
		return reply(player, kind, "no_shells")
	end

	Boosts.noteUse(usageOf(player), kind)
	if kind == "Hint" then
		local seen = hinted[player] or {}
		hinted[player] = seen
		seen[answer :: string] = true
		local label = Tiers.ByName[tier :: string].label
		return reply(player, kind, "ok", { hint = Boosts.hintText(label, display :: string) })
	end
	local secondsLeft = AnswerService.extend(player, GameConfig.Boosts.ExtraTimeSeconds)
	return reply(player, kind, "ok", { secondsLeft = secondsLeft })
end

-- A Robux boost adds one to the inventory; if the buyer is waiting on it this prompt, it is used at once.
local function onBoostBought(player: Player, kind: string)
	DataService.addBoosts(player, kind, 1)
	local waiting = pending[player]
	if waiting == nil or waiting.kind ~= kind then
		return
	end
	pending[player] = nil
	if os.clock() > waiting.expires then
		return
	end
	-- Deferred so the receipt handler finishes (and saves) before the boost is spent.
	task.defer(BoostService.apply, player, kind, "inventory")
end

function BoostService.start()
	Net.event("UseBoost").OnServerEvent:Connect(function(player, kind, pay)
		if typeof(kind) ~= "string" or not KINDS[kind] then
			return
		end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < GameConfig.Boosts.Cooldown then
			return
		end
		lastRequest[player] = now
		BoostService.apply(player, kind :: string, if pay == "inventory" then "inventory" else "auto")
	end)

	StoreService.registerProduct(Products.Boosts.Hint.productId, function(player)
		onBoostBought(player, "Hint")
	end)
	StoreService.registerProduct(Products.Boosts.ExtraTime.productId, function(player)
		onBoostBought(player, "ExtraTime")
	end)

	-- One of each per round: the round count, hints given and any waiting purchase reset on every prompt.
	MatchEvents.PromptOpened.connect(function()
		for _, uses in usage do
			uses.round = Boosts.newUses()
		end
		hinted = {}
		pending = {}
	end)
	MatchEvents.MatchStarted.connect(function()
		usage = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		usage[player] = nil
		hinted[player] = nil
		lastRequest[player] = nil
		pending[player] = nil
	end)
end

return BoostService
