--!strict
-- The YOU row of this week's wins board (Lobby.WeeklyBoard): each player sees their own place there. The
-- server sends it (WeeklyRank); the row is filled again every few seconds because the board can stream out
-- and back in as a new instance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local REFILL_SECONDS = 5

local last: Net.WeeklyRankPayload? = nil

local WeeklyBoard = {}

local function setText(row: Instance, name: string, text: string)
	local label = row:FindFirstChild(name)
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function fill()
	local payload = last
	local lobby = workspace:FindFirstChild("Lobby")
	local board = if lobby ~= nil then lobby:FindFirstChild("WeeklyBoard") else nil
	local row = if board ~= nil then board:FindFirstChild("YouRow", true) else nil
	if payload == nil or row == nil then
		return
	end
	local rankText = "-"
	if payload.rank ~= nil then
		rankText = tostring(payload.rank)
	elseif payload.wins > 0 then
		rankText = "100+"
	end
	setText(row, "Rank", rankText)
	setText(row, "Name", "YOU")
	setText(row, "Wins", tostring(payload.wins))
end

function WeeklyBoard.onRank(payload: Net.WeeklyRankPayload)
	if type(payload) ~= "table" or type(payload.wins) ~= "number" then
		return
	end
	last = payload
	fill()
end

function WeeklyBoard.init()
	Net.event("WeeklyRank").OnClientEvent:Connect(WeeklyBoard.onRank)
	Net.event("WeeklyRank"):FireServer()
	task.spawn(function()
		while true do
			task.wait(REFILL_SECONDS)
			fill()
		end
	end)
end

return WeeklyBoard
