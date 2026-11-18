--!strict
-- This week's wins board (Lobby.WeeklyBoard, authored in Studio): counts each Win in that week's
-- OrderedDataStore (rules in Shared/Weekly), fills the top 10 and the reset countdown, and tells each player
-- their own place (WeeklyRank) for the board's YOU row, which Client/WeeklyBoard fills.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Weekly = require(ReplicatedStorage.Shared.Weekly)
local MatchEvents = require(script.Parent.MatchEvents)
local LeaderboardService = require(script.Parent.LeaderboardService)

local RULES = GameConfig.Leaderboard

local top: { Weekly.Entry } = {}
local topWeek = -1

local WeeklyService = {}

local function storeFor(week: number): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Weekly.storeName(week, RunService:IsStudio()))
	end)
	if not ok then
		warn("WeeklyService: no weekly store: " .. tostring(store))
		return nil
	end
	return store
end

local function addWin(player: Player)
	local store = storeFor(Weekly.week(os.time()))
	if store == nil then
		return
	end
	local ok, err = pcall(function()
		store:IncrementAsync(tostring(player.UserId), 1)
	end)
	if not ok then
		warn("WeeklyService: could not count a win: " .. tostring(err))
	end
end

local function readTop(week: number): { Weekly.Entry }?
	local store = storeFor(week)
	if store == nil then
		return nil
	end
	local result: { Weekly.Entry } = {}
	local ok, err = pcall(function()
		local pages = store:GetSortedAsync(false, RULES.WeeklyTopRead)
		for _, entry in pages:GetCurrentPage() do
			table.insert(result, { userId = tonumber(entry.key) or 0, wins = entry.value })
		end
	end)
	if not ok then
		warn("WeeklyService: board read failed: " .. tostring(err))
		return nil
	end
	return result
end

local function findBoard(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby == nil then
		return nil
	end
	return lobby:FindFirstChild("WeeklyBoard")
end

local function fillBoard()
	local board = findBoard()
	if board == nil then
		return
	end
	local resets = board:FindFirstChild("Resets", true)
	if resets ~= nil and resets:IsA("TextLabel") then
		resets.Text = Weekly.resetText(Weekly.secondsLeft(os.time()))
	end
	local list = board:FindFirstChild("List", true)
	if list == nil then
		return
	end
	for index = 1, RULES.Size do
		local row = list:FindFirstChild("Row" .. index)
		local nameLabel = if row ~= nil then row:FindFirstChild("Name") else nil
		local winsLabel = if row ~= nil then row:FindFirstChild("Wins") else nil
		if nameLabel ~= nil and nameLabel:IsA("TextLabel") and winsLabel ~= nil and winsLabel:IsA("TextLabel") then
			local entry = top[index]
			if entry ~= nil then
				nameLabel.Text = LeaderboardService.nameOf(entry.userId)
				winsLabel.Text = tostring(entry.wins)
			else
				nameLabel.Text = "-"
				winsLabel.Text = ""
			end
		end
	end
end

-- Wins this week for someone outside the top list: one read of their own entry.
local function winsOf(userId: number): number
	local store = storeFor(topWeek)
	if store == nil then
		return 0
	end
	local ok, value = pcall(function()
		return store:GetAsync(tostring(userId))
	end)
	if ok and typeof(value) == "number" then
		return value
	end
	return 0
end

local function tellRank(player: Player)
	local rank = Weekly.rankOf(top, player.UserId)
	local wins = if rank ~= nil then top[rank].wins else winsOf(player.UserId)
	if player.Parent ~= nil then
		Net.event("WeeklyRank"):FireClient(player, { rank = rank, wins = wins })
	end
end

local function refresh()
	local week = Weekly.week(os.time())
	local read = readTop(week)
	if read ~= nil then
		top = read
		topWeek = week
	elseif week ~= topWeek then
		-- A new week whose store could not be read yet starts empty, never with last week's names.
		top = {}
		topWeek = week
	end
	fillBoard()
	for _, player in Players:GetPlayers() do
		task.spawn(tellRank, player)
	end
end

function WeeklyService.start()
	MatchEvents.MatchFinished.connect(function(_participants: { Player }, winner: Player?, countsAsWin: boolean)
		if winner ~= nil and countsAsWin then
			task.spawn(function()
				addWin(winner)
				refresh()
			end)
		end
	end)
	-- A client asks once when its board controller starts, so the YOU row fills before the next refresh.
	local asked: { [Player]: boolean } = {}
	Net.event("WeeklyRank").OnServerEvent:Connect(function(player)
		if asked[player] then
			return
		end
		asked[player] = true
		tellRank(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		asked[player] = nil
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(RULES.RefreshSeconds)
		end
	end)
end

return WeeklyService
