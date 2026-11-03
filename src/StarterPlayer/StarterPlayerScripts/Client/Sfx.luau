--!strict
-- Built-in Roblox sounds so nothing external needs uploading. Swap ids here to retheme.

local SoundService = game:GetService("SoundService")

local SOUNDS = {
	Tick = "rbxasset://sounds/electronicpingshort.wav",
	LockIn = "rbxasset://sounds/button.wav",
	Rise = "rbxasset://sounds/swoosh.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Fanfare = "rbxasset://sounds/victory.wav",
	Pop = "rbxasset://sounds/snap.wav",
}

local cache: { [string]: Sound } = {}

local Sfx = {}

function Sfx.play(name: string, volume: number?)
	local id = SOUNDS[name]
	if id == nil then
		return
	end
	local sound = cache[name]
	if sound == nil then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Parent = SoundService
		cache[name] = sound
	end
	sound.Volume = volume or 0.5
	sound:Play()
end

return Sfx
