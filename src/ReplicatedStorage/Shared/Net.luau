--!strict
-- All remotes live in ReplicatedStorage.Remotes. The server creates them once; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local NAMES = {
	-- client -> server
	"SubmitAnswer",
	"LobbyQuizAnswer",
	"LobbyQuizSkip",
	-- server -> client
	"RoundState",
	"Reveal",
	"Eliminated",
	"MatchEnded",
	"AnswerResult",
	"LobbyQuizPrompt",
	"LobbyQuizResult",
	"CoinsChanged",
}

export type RoundStatePayload = {
	phase: string, -- "Waiting" | "Intermission" | "Prompt" | "Reveal" | "Surge" | "Results"
	round: number,
	secondsLeft: number,
	alive: number,
	prompt: string?,
	promptId: string?,
	playing: boolean, -- is the receiving player on a platform this match
	height: number,
	waterY: number,
}

export type RevealRow = {
	userId: number,
	name: string,
	answer: string?, -- filtered, nil when no accepted answer or the filter failed
	tier: string?, -- nil when no accepted answer
	points: number,
	lift: number,
	height: number,
}

export type RevealPayload = {
	round: number,
	rows: { RevealRow },
}

local Net = {}

function Net.init()
	if not RunService:IsServer() then
		error("Net.init is server only")
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Net.event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
