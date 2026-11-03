--!strict
-- Plays the sound effects authored in Studio under SoundService.Krillion. Swap SoundIds there to retheme.

local SoundService = game:GetService("SoundService")

local folder = SoundService:WaitForChild("Krillion")

local Sfx = {}

function Sfx.play(name: string, volume: number?)
	local sound = folder:FindFirstChild(name) :: Sound?
	if sound == nil then
		return
	end
	sound.Volume = volume or 0.5
	sound:Play()
end

return Sfx
