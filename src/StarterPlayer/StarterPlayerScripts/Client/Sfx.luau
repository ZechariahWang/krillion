--!strict
-- Plays the sound effects authored in Studio under SoundService.RareOrSink. Swap SoundIds there to retheme.
-- Sounds added for the Sink or Niche port live in git under ReplicatedStorage.Sounds and are found there
-- when SoundService.RareOrSink has no sound of that name.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local warned: { [string]: boolean } = {}

local Sfx = {}

-- Looked up on every play rather than waited for at require, so a missing folder never stalls the client.
local function find(name: string): Sound?
	local folder = SoundService:FindFirstChild("RareOrSink")
	local extra = ReplicatedStorage:FindFirstChild("Sounds")
	local template: Instance? = nil
	if folder ~= nil then
		template = folder:FindFirstChild(name)
	end
	if template == nil and extra ~= nil then
		template = extra:FindFirstChild(name)
	end
	if template ~= nil and template:IsA("Sound") then
		return template
	end
	return nil
end

-- Each play is a clone of the authored sound, so quick repeats at different pitches overlap cleanly.
-- `pitch` multiplies the authored PlaybackSpeed, so a sound authored at 0.7 keeps its character.
function Sfx.play(name: string, volume: number?, pitch: number?)
	local template = find(name)
	if template == nil then
		if not warned[name] then
			warned[name] = true
			warn("[Sfx] no sound named " .. name .. " in SoundService.RareOrSink or ReplicatedStorage.Sounds")
		end
		return
	end
	local sound = template:Clone()
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = (pitch or 1) * template.PlaybackSpeed
	sound.Parent = SoundService:FindFirstChild("RareOrSink") or SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sfx
