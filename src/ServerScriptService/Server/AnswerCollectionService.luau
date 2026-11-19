--!strict
-- The answer collection (rules in Shared/Collection): keeps each prompt's best match answer as a card, toasts
-- an improved card, pays the mastered-count milestones (Shells and reward titles), and sends clients the
-- album (every live prompt and its rarest tier), since the prompt bank stays on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Cosmetics = require(ReplicatedStorage.Config.Cosmetics)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Tiers = require(ReplicatedStorage.Config.Tiers)
local Collection = require(ReplicatedStorage.Shared.Collection)
local Currency = require(ReplicatedStorage.Shared.Currency)
local Net = require(ReplicatedStorage.Shared.Net)
local PromptBank = require(ServerStorage.PromptBank)
local MatchEvents = require(script.Parent.MatchEvents)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local StoreService = require(script.Parent.StoreService)

local CATALOGUE_COOLDOWN = 5 -- seconds between album sends to one player

local catalogue: { Collection.Entry } = {}
local promptText: { [string]: string } = {}

local AnswerCollectionService = {}

local function buildCatalogue()
	for _, prompt in PromptBank.List do
		local top = Collection.topTier(prompt.answers)
		if not PromptBank.Retired[prompt.id] and top ~= nil then
			table.insert(catalogue, { id = prompt.id, prompt = prompt.prompt, top = top })
			promptText[prompt.id] = prompt.prompt
		end
	end
end

local function titleNames(reward: string): string
	local names = {}
	for _, item in Cosmetics.forReward(reward) do
		table.insert(names, string.upper(item.name))
	end
	return table.concat(names, ", ")
end

local function grantTitle(player: Player, reward: string)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	for _, item in Cosmetics.forReward(reward) do
		if profile.owned[item.id] ~= true then
			DataService.grantItem(player, item.id)
		end
	end
end

-- Pays every milestone reached and not yet claimed, and re-grants a claimed milestone's title if it is missing.
local function checkMilestones(player: Player)
	local profile = DataService.get(player)
	if profile == nil or DataService.isReadOnly(player) then
		return
	end
	local _, mastered = Collection.counts(profile.collection, catalogue)
	for _, milestone in Collection.reached(mastered, #catalogue) do
		local title = milestone.title
		if DataService.claim(player, milestone.id) then
			if milestone.shells > 0 then
				StoreService.grantShells(player, milestone.shells, "collection")
			end
			local reward = "COLLECTION: " .. Collection.needFor(milestone, #catalogue) .. " MASTERED!"
			if milestone.shells > 0 then
				reward ..= "  |  +" .. Currency.format(milestone.shells)
			end
			if title ~= nil then
				reward ..= "  |  " .. titleNames(title) .. " TITLE"
			end
			NotifyService.send(player, reward, "mythic")
		end
		if title ~= nil then
			grantTitle(player, title)
		end
	end
end

local function onGraded(player: Player, tier: string?, _points: number, promptId: string, answer: string?)
	if tier == nil or answer == nil or promptText[promptId] == nil then
		return
	end
	-- The card lands with the answer's Shells, once the dive cards are down.
	task.delay(GameConfig.Reveal.PayoutDelaySeconds, function()
		if player.Parent == nil then
			return
		end
		if not DataService.recordCard(player, promptId, tier, answer) then
			return
		end
		local info = Tiers.ByName[tier]
		local label = if info ~= nil then string.upper(info.label) else tier
		NotifyService.send(player, "COLLECTION: " .. string.upper(promptText[promptId]) .. "  |  " .. label, "good")
		checkMilestones(player)
	end)
end

function AnswerCollectionService.start()
	buildCatalogue()
	MatchEvents.AnswerGraded.connect(onGraded)
	DataService.ProfileLoaded.connect(checkMilestones)
	-- The album is the same for everyone; a cooldown keeps a spamming client from making the server resend it.
	local lastSent: { [Player]: number } = {}
	Net.event("CollectionCatalog").OnServerEvent:Connect(function(player)
		local now = os.clock()
		local last = lastSent[player]
		if last ~= nil and now - last < CATALOGUE_COOLDOWN then
			return
		end
		lastSent[player] = now
		Net.event("CollectionCatalog"):FireClient(player, catalogue)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
end

return AnswerCollectionService
