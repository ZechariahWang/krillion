--!strict
-- Fills the lobby's top-wins board (Lobby.Leaderboard, authored in Studio) from the Wins OrderedDataStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local DataService = require(script.Parent.DataService)

local names: { [number]: string } = {}

local LeaderboardService = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached ~= nil then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		names[userId] = name
		return name
	end
	return "Player"
end

local function findList(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby == nil then
		return nil
	end
	local board = lobby:FindFirstChild("Leaderboard", true)
	if board == nil then
		return nil
	end
	return board:FindFirstChild("List", true)
end

local function refresh()
	local list = findList()
	if list == nil then
		return
	end
	local top = DataService.topWins(GameConfig.Leaderboard.Size)
	for index = 1, GameConfig.Leaderboard.Size do
		local row = list:FindFirstChild("Row" .. index)
		if row ~= nil then
			local nameLabel = row:FindFirstChild("Name") :: TextLabel?
			local winsLabel = row:FindFirstChild("Wins") :: TextLabel?
			local entry = top[index]
			if nameLabel ~= nil and winsLabel ~= nil then
				if entry ~= nil then
					nameLabel.Text = nameOf(entry.userId)
					winsLabel.Text = tostring(entry.wins)
				else
					nameLabel.Text = "-"
					winsLabel.Text = ""
				end
			end
		end
	end
end

function LeaderboardService.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(GameConfig.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
