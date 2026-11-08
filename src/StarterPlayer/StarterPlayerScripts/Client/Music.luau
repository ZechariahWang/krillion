--!strict
-- Background music: the tracks authored under SoundService.Krillion.Music play one after another, from a
-- random first track, for the whole session. Settings turns it on and off (saved as profile.musicOff); it
-- waits for the profile before the first note so a player who turned music off never hears a burst.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local WAIT_SECONDS = 10
local PROFILE_WAIT_SECONDS = 6 -- start anyway (music on) if the profile is slow to arrive
local FADE_SECONDS = 0.8

local tracks: { Sound } = {}
local volumes: { [Sound]: number } = {}
local current: Sound? = nil
local index = 0
local enabled = true
local decided = false -- the profile (or the wait) has said whether music is on

local Music = {}

local function fade(sound: Sound, volume: number)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE_SECONDS), { Volume = volume })
	tween:Play()
	return tween
end

local function playNext()
	if #tracks == 0 or not enabled then
		return
	end
	index = (index % #tracks) + 1
	local sound = tracks[index]
	current = sound
	sound.Volume = volumes[sound]
	sound.TimePosition = 0
	sound:Play()
end

local function start()
	if not enabled or #tracks == 0 then
		return
	end
	local sound = current
	if sound ~= nil and sound.IsPaused then
		sound.Volume = 0
		sound:Resume()
		fade(sound, volumes[sound])
		return
	end
	if sound == nil or not sound.IsPlaying then
		playNext()
	end
end

local function stop()
	local sound = current
	if sound == nil or not sound.IsPlaying then
		return
	end
	fade(sound, 0).Completed:Once(function()
		if not enabled then
			sound:Pause()
		end
	end)
end

-- True plays the music (fading back in); false fades it out and pauses it.
function Music.setEnabled(on: boolean)
	enabled = on
	if not decided then
		return
	end
	if on then
		start()
	else
		stop()
	end
end

function Music.isEnabled(): boolean
	return enabled
end

-- ProfileChanged payload: the saved music choice.
function Music.onProfile(profile)
	if typeof(profile) ~= "table" then
		return
	end
	local on = profile.musicOff ~= true
	if not decided then
		decided = true
		enabled = on
		start()
		return
	end
	if on ~= enabled then
		Music.setEnabled(on)
	end
end

function Music.init()
	task.spawn(function()
		local folder = SoundService:WaitForChild("Krillion"):WaitForChild("Music", WAIT_SECONDS)
		if folder == nil then
			warn("Music: SoundService.Krillion.Music is missing; no background music")
			return
		end
		for _, child in folder:GetChildren() do
			if child:IsA("Sound") then
				table.insert(tracks, child)
				volumes[child] = child.Volume
				child.Ended:Connect(function()
					if child == current then
						playNext()
					end
				end)
			end
		end
		table.sort(tracks, function(a, b)
			return a.Name < b.Name
		end)
		if #tracks > 0 then
			index = math.random(1, #tracks) - 1
		end
		task.delay(PROFILE_WAIT_SECONDS, function()
			if not decided then
				decided = true
				start()
			end
		end)
		if decided then
			start()
		end
	end)
end

return Music
