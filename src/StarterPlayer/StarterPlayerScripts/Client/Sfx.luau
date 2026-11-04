--!strict
-- Plays the sound effects authored in Studio under SoundService.Krillion. Swap SoundIds there to retheme.
-- Sounds added for the Sink or Niche port live in git under ReplicatedStorage.Sounds and are found there
-- when SoundService.Krillion has no sound of that name.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local folder = SoundService:WaitForChild("Krillion")
local extra = ReplicatedStorage:FindFirstChild("Sounds")

local Sfx = {}

local function find(name: string): Sound?
	local template = folder:FindFirstChild(name)
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
		return
	end
	local sound = template:Clone()
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = (pitch or 1) * template.PlaybackSpeed
	sound.Parent = folder
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sfx
