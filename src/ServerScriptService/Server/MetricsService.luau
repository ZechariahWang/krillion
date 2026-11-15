--!strict
-- Sends gameplay metrics to Roblox's AnalyticsService: they show in the Creator Hub's Analytics pages
-- (Funnels, Economy, Custom), which only the experience's developers can open.
--   Onboarding funnel  a new player's first session (Metrics.ONBOARDING)
--   "Match" funnel     match started, then each round survived
--   Economy            every Shells gain and spend, by reason and item
--   Custom events      AnswerGraded, Sank, Won, BoostUsed, ReviveOffered, ReviveUsed
-- Roblox records nothing from Studio, so there each event is printed instead.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Metrics = require(ReplicatedStorage.Shared.Metrics)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)

local PROFILE_WAIT_SECONDS = 30
local MATCH_FUNNEL = "Match"
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
}

local isStudio = RunService:IsStudio()
-- New players only: the onboarding steps each has logged this session.
local onboarding: { [Player]: { [string]: boolean } } = {}
-- The funnel session of the match each player is in.
local matchSession: { [Player]: string } = {}

local MetricsService = {}

local function send(label: string, call: () -> ())
	if isStudio then
		print("[Metrics] " .. label)
		return
	end
	local ok, err = pcall(call)
	if not ok then
		warn("[Metrics] " .. label .. " failed: " .. tostring(err))
	end
end

local function fieldsOf(field1: string?, field2: string?): { [string]: string }
	local fields: { [string]: string } = {}
	if field1 ~= nil then
		fields[FIELD_KEYS[1]] = field1
	end
	if field2 ~= nil then
		fields[FIELD_KEYS[2]] = field2
	end
	return fields
end

-- A custom event. Fields are breakdowns, written with Metrics.field.
function MetricsService.event(player: Player, name: string, value: number?, field1: string?, field2: string?)
	if player.Parent == nil then
		return
	end
	local amount = value or 1
	local label = name .. " " .. amount .. " " .. (field1 or "") .. " " .. (field2 or "")
	send(label, function()
		AnalyticsService:LogCustomEvent(player, name, amount, fieldsOf(field1, field2))
	end)
end

-- Shells gained (delta above 0) or spent (below 0), after the profile changed. sku says what a spend bought.
function MetricsService.shells(player: Player, delta: number, reason: string?, sku: string?)
	local profile = DataService.get(player)
	if delta == 0 or profile == nil or player.Parent == nil then
		return
	end
	local entry = Metrics.economy(delta, reason, sku)
	local label = "Shells " .. entry.flow .. " " .. entry.amount .. " " .. entry.transaction .. " " .. entry.sku
	local balance = profile.cash
	send(label, function()
		local flow = if entry.flow == "Sink"
			then Enum.AnalyticsEconomyFlowType.Sink
			else Enum.AnalyticsEconomyFlowType.Source
		AnalyticsService:LogEconomyEvent(player, flow, "Shells", entry.amount, balance, entry.transaction, entry.sku)
	end)
end

-- One onboarding step, once per new player. Players who have been here before log nothing.
local function onboard(player: Player, name: string)
	local logged = onboarding[player]
	local step = Metrics.onboardingStep(name)
	if logged == nil or step == nil or logged[name] == true then
		return
	end
	logged[name] = true
	send("Onboarding " .. step .. " " .. name, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

local function matchFunnel(player: Player, round: number)
	local session = matchSession[player]
	if session == nil then
		return
	end
	local step, name = Metrics.matchStep(round)
	send("Match funnel " .. step .. " " .. name, function()
		AnalyticsService:LogFunnelStepEvent(player, MATCH_FUNNEL, session, step, name)
	end)
end

local function enterMatch(player: Player)
	matchSession[player] = HttpService:GenerateGUID(false)
	matchFunnel(player, 0)
	onboard(player, "MatchStarted")
end

-- Only a first visit joins the onboarding funnel, and that is known once the profile has loaded.
local function onPlayerAdded(player: Player)
	local waited = 0
	while not DataService.isLoaded(player) and player.Parent ~= nil and waited < PROFILE_WAIT_SECONDS do
		waited += task.wait(0.5)
	end
	if player.Parent == nil or not DataService.isNew(player) then
		return
	end
	onboarding[player] = {}
	onboard(player, "Joined")
end

function MetricsService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		onboarding[player] = nil
		matchSession[player] = nil
	end)
	Net.event("TutorialDone").OnServerEvent:Connect(function(player)
		onboard(player, "TutorialDone")
	end)

	MatchEvents.MatchStarted.connect(function(participants: { Player })
		for _, player in participants do
			enterMatch(player)
		end
	end)
	MatchEvents.PlayerJoinedMatch.connect(enterMatch)
	MatchEvents.AnswerGraded.connect(function(player: Player, tier: string?)
		MetricsService.event(player, "AnswerGraded", 1, Metrics.field("Tier", tier))
		if tier ~= nil then
			onboard(player, "AnswerAccepted")
		end
	end)
	MatchEvents.RoundSurvived.connect(function(player: Player, round: number)
		matchFunnel(player, round)
		onboard(player, "RoundSurvived")
	end)
	MatchEvents.PlayerSank.connect(function(player: Player, round: number)
		MetricsService.event(player, "Sank", round)
	end)
	MatchEvents.MatchFinished.connect(
		function(participants: { Player }, winner: Player?, countsAsWin: boolean, rounds: number)
			for _, player in participants do
				onboard(player, "MatchFinished")
				matchSession[player] = nil
			end
			if winner ~= nil and countsAsWin then
				MetricsService.event(winner, "Won", rounds)
			end
		end
	)
end

return MetricsService
