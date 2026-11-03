--!strict
-- All remotes are authored in Studio under ReplicatedStorage.Remotes; code only looks them up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

export type RoundStatePayload = {
	phase: string, -- "Waiting" | "Intermission" | "Prompt" | "Reveal" | "Surge" | "Results"
	round: number,
	secondsLeft: number,
	alive: number,
	prompt: string?,
	promptId: string?,
	playing: boolean, -- is the receiving player on a platform this match
	playerCount: number,
	minPlayers: number,
	starting: number, -- players who started the current match
	height: number,
	waterY: number,
	surge: number, -- how far the water rises at the end of this round
	special: string?, -- "TidalWave" | "DoubleLift" | nil
}

export type RevealRow = {
	userId: number,
	name: string,
	answer: string?, -- the bank spelling of the accepted answer, nil when there was none
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

function Net.event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
