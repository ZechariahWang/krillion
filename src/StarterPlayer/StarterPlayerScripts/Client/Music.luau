--!strict
-- Background music: the tracks authored under SoundService.RareOrSink.Music play one after another, from a
-- random first track, for the whole session. Settings turns it on and off (saved as profile.musicOff); it
-- waits for the profile before the first note so a player who turned music off never hears a burst.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Toasts = require(script.Parent.Toasts)

local WAIT_SECONDS = 10
local PROFILE_WAIT_SECONDS = 6 -- start anyway (music on) if the profile is slow to arrive
local FADE_SECONDS = 0.8
local LOAD_SECONDS = 8 -- a track not loaded by then is skipped

local tracks: { Sound } = {}
local volumes: { [Sound]: number } = {}
local current: Sound? = nil
local index = 0
local enabled = true
local volume = 1 -- the Settings volume bar, applied on top of each track's authored volume
local decided = false -- the profile (or the wait) has said whether music is on
local profileApplied = false -- later profile pushes echo our own SetSetting and would undo a fresh change
local fadeTween: Tween? = nil
local playToken = 0
local failedInARow = 0 -- stops skipping once every track has failed, instead of spinning through them

local Music = {}

-- Credits the track as it starts: the Title and Artist attributes authored on each Sound (DistroKid music
-- on the Creator Store names its artist; the attribute carries it into the game).
local function announce(sound: Sound)
	local title = sound:GetAttribute("Title")
	local artist = sound:GetAttribute("Artist")
	if typeof(title) ~= "string" or typeof(artist) ~= "string" then
		return
	end
	Toasts.show(string.upper(title) .. "  |  " .. string.upper(artist), "info")
end

local function cancelFade()
	local tween = fadeTween
	if tween ~= nil then
		fadeTween = nil
		tween:Cancel()
	end
end

local function fade(sound: Sound, target: number): Tween
	cancelFade()
	local tween = TweenService:Create(sound, TweenInfo.new(FADE_SECONDS), { Volume = target })
	fadeTween = tween
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
	playToken += 1
	local token = playToken
	-- The playlist moves on only when a track ends, so a looped track would play forever.
	sound.Looped = false
	sound.Volume = volumes[sound] * volume
	sound.TimePosition = 0
	sound:Play()
	announce(sound)
	task.spawn(function()
		local waitedFrom = os.clock()
		while not sound.IsLoaded and os.clock() - waitedFrom < LOAD_SECONDS do
			task.wait(0.25)
		end
		if token ~= playToken then
			return
		end
		if sound.IsLoaded then
			failedInARow = 0
			return
		end
		failedInARow += 1
		warn("Music: " .. sound.Name .. " did not load; skipping it")
		sound:Stop()
		if failedInARow < #tracks then
			playNext()
		end
	end)
end

local function start()
	if not enabled or #tracks == 0 then
		return
	end
	local sound = current
	if sound ~= nil and sound.IsPaused then
		sound.Volume = 0
		sound:Resume()
		fade(sound, volumes[sound] * volume)
		return
	end
	-- Turned back on while the fade out still runs: fade back up from where it got to.
	if sound ~= nil and sound.IsPlaying then
		fade(sound, volumes[sound] * volume)
		return
	end
	playNext()
end

local function stop()
	local sound = current
	if sound == nil or not sound.IsPlaying then
		return
	end
	fade(sound, 0).Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and not enabled then
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

-- 0..1 from the Settings volume bar; the playing track follows at once.
function Music.setVolume(level: number)
	volume = math.clamp(level, 0, 1)
	local sound = current
	if sound ~= nil and enabled then
		cancelFade()
		sound.Volume = volumes[sound] * volume
	end
end

function Music.getVolume(): number
	return volume
end

-- ProfileChanged payload: the saved music choice, taken from the first profile only.
function Music.onProfile(profile)
	if typeof(profile) ~= "table" or profileApplied then
		return
	end
	profileApplied = true
	if typeof(profile.musicVolume) == "number" then
		Music.setVolume(profile.musicVolume)
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
		local folder = SoundService:WaitForChild("RareOrSink"):WaitForChild("Music", WAIT_SECONDS)
		if folder == nil then
			warn("Music: SoundService.RareOrSink.Music is missing; no background music")
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
