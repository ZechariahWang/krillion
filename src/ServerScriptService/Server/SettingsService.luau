--!strict
-- Applies the Settings window's toggles and volume bar (SetSetting remote). Music on/off and volume are saved
-- with the profile. AFK lasts for this session only: it sets the player's Afk attribute, which keeps them out
-- of matches (RoundService) and shows the AFK row on their head label (Client/HeadTags).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local function onSetSetting(player: Player, key: any, value: any)
	if key == "MusicVolume" then
		if typeof(value) == "number" and value == value then
			DataService.setMusicVolume(player, value)
		end
		return
	end
	if typeof(value) ~= "boolean" then
		return
	end
	if key == "MusicOn" then
		DataService.setMusicOff(player, not value)
	elseif key == "Afk" then
		player:SetAttribute("Afk", value)
	end
end

function SettingsService.start()
	Net.event("SetSetting").OnServerEvent:Connect(onSetSetting)
end

return SettingsService
