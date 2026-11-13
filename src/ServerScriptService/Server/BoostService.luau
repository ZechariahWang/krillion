--!strict
-- In-match boosts: Hint (the best answer nobody has locked in, Mythic whenever one is left, locked in for
-- you at once) and ExtraTime (+10 s for you only).
-- Paid from the boost inventory first; ExtraTime then falls back to Shells, a Hint never does (hints are
-- only bought with Robux). Robux products only add inventory. A Robux buy made mid-prompt is applied when
-- its receipt lands (the client asks with pay "inventory" and the server remembers the request), so a slow
-- receipt never falls through to spending Shells.

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

local function inventoryOf(player: Player, kind: string): number
	local profile = DataService.get(player)
	if profile == nil then
		return 0
	end
	return if kind == "Hint" then profile.hints else profile.extraTimes
end

-- How many more +time boosts this player may use this match.
local function timeLeftThisMatch(player: Player): number
	local limits = Boosts.limitsFor(StoreService.ownsPass(player, "BoostPlus"))
	return math.max(0, limits.PerMatch - usageOf(player).match.ExtraTime)
end

local function reply(player: Player, kind: string, status: string, extra: { [string]: any }?): string
	local payload: { [string]: any } = {
		kind = kind,
		status = status,
		uses = BoostService.usesFor(player),
		timeLeftThisMatch = timeLeftThisMatch(player),
	}
	if extra ~= nil then
		for key, value in extra do
			payload[key] = value
		end
	end
	Net.event("BoostResult"):FireClient(player, payload)
	return status
end

-- The hint a player would get now, without using it: display spelling, tier name, bank answer.
local function findHint(): (string?, string?, string?)
	local answers = AnswerService.currentAnswersByTier()
	if answers == nil then
		return nil, nil, nil
	end
	return Boosts.pickHint(answers, AnswerService.lockedCorrected(), math.random())
end

-- Uses one boost for the player. pay: "auto" (inventory, then Shells for ExtraTime) | "inventory" (a Robux
-- purchase that just landed; never falls back to Shells). Returns the BoostResult status it sent.
-- Everything is checked before anything is paid, so no path needs a refund.
function BoostService.apply(player: Player, kind: string, pay: string?): string
	if GameConfig.Boosts.Enabled == 0 then
		return reply(player, kind, "disabled")
	end
	local open = AnswerService.boostStatus(player)
	if open ~= "ok" then
		return reply(player, kind, open)
	end
	local allowed = Boosts.canUse(usageOf(player), kind, Boosts.limitsFor(StoreService.ownsPass(player, "BoostPlus")))
	if allowed ~= "ok" then
		return reply(player, kind, allowed)
	end
	local display: string?, tier: string?, answer: string? = nil, nil, nil
	if kind == "Hint" then
		display, tier, answer = findHint()
		if display == nil or tier == nil or answer == nil then
			return reply(player, kind, "none")
		end
	end

	local owned = inventoryOf(player, kind) > 0
	if not owned and pay == "inventory" then
		-- The receipt has not landed yet; the product handler finishes this request when it does.
		pending[player] = { kind = kind, expires = os.clock() + GameConfig.Boosts.PurchaseWaitSeconds }
		return reply(player, kind, "pending")
	end
	if kind == "Hint" then
		if not owned then
			return reply(player, kind, "no_hints")
		end
		-- The answer is locked in first, so a hint that cannot be used is never paid for.
		if not AnswerService.lockIn(player, answer :: string) then
			return reply(player, kind, "closed")
		end
		DataService.spendBoost(player, kind)
		Boosts.noteUse(usageOf(player), kind)
		local label = Tiers.ByName[tier :: string].label
		return reply(player, kind, "ok", { hint = Boosts.hintText(label, display :: string) })
	end

	if owned then
		DataService.spendBoost(player, kind)
	elseif not StoreService.spendShells(player, GameConfig.Boosts.ExtraTimeShells, "spend") then
		return reply(player, kind, "no_shells")
	end
	Boosts.noteUse(usageOf(player), kind)
	local secondsLeft = AnswerService.extend(player, GameConfig.Boosts.ExtraTimeSeconds)
	return reply(player, kind, "ok", { secondsLeft = secondsLeft })
end

-- A Robux boost adds `count` (1, or 3 for a pack) to the inventory; if the buyer is waiting on it this
-- prompt, one is used at once.
local function onBoostBought(player: Player, kind: string, count: number?)
	DataService.addBoosts(player, kind, count or 1)
	local waiting = pending[player]
	if waiting == nil or waiting.kind ~= kind then
		return
	end
	pending[player] = nil
	if os.clock() > waiting.expires then
		-- Too late to use it for them: it is in their stock, and they are told so.
		reply(player, kind, "stocked")
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
	for _, pack in Products.BoostPacks do
		StoreService.registerProduct(pack.productId, function(player)
			onBoostBought(player, pack.kind, pack.count)
		end)
	end

	-- The +time round count and any waiting purchase reset on every prompt.
	MatchEvents.PromptOpened.connect(function()
		for _, uses in usage do
			uses.round = Boosts.newUses()
		end
		pending = {}
	end)
	MatchEvents.MatchStarted.connect(function()
		usage = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		usage[player] = nil
		lastRequest[player] = nil
		pending[player] = nil
	end)
end

return BoostService
