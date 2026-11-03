--!strict
-- Plays the sound effects authored in Studio under SoundService.Krillion. Swap SoundIds there to retheme.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local folder = SoundService:WaitForChild("Krillion")

local Sfx = {}

-- Each play is a clone of the authored sound, so quick repeats at different pitches overlap cleanly.
function Sfx.play(name: string, volume: number?, pitch: number?)
	local template = folder:FindFirstChild(name) :: Sound?
	if template == nil then
		return
	end
	local sound = template:Clone()
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = folder
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sfx
