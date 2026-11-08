--!strict
-- Applies the Settings window's toggles and volume bar (SetSetting remote). Music on/off and volume are saved
-- with the profile. AFK lasts for this session only: it sets the player's Afk attribute, which keeps them out
-- of matches and late joins (RoundService), and floats a clone of ReplicatedStorage.Templates.AfkTag over
-- their head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local TAG_NAME = "AfkTag"

local SettingsService = {}

local function removeTag(character: Model?)
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	local tag = if head ~= nil then head:FindFirstChild(TAG_NAME) else nil
	if tag ~= nil then
		tag:Destroy()
	end
end

local function addTag(character: Model?)
	if character == nil then
		return
	end
	local head = character:WaitForChild("Head", 10)
	if head == nil or head:FindFirstChild(TAG_NAME) ~= nil then
		return
	end
	local templates = ReplicatedStorage:FindFirstChild("Templates")
	local template = if templates ~= nil then templates:FindFirstChild(TAG_NAME) else nil
	if template == nil or not template:IsA("BillboardGui") then
		warn("SettingsService: ReplicatedStorage.Templates.AfkTag is missing; AFK players get no tag")
		return
	end
	local tag = template:Clone()
	tag.Adornee = head :: BasePart
	tag.Parent = head
end

local function setAfk(player: Player, afk: boolean)
	player:SetAttribute("Afk", afk)
	if afk then
		addTag(player.Character)
	else
		removeTag(player.Character)
	end
end

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
		setAfk(player, value)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		if player:GetAttribute("Afk") == true then
			addTag(character)
		end
	end)
end

function SettingsService.start()
	Net.event("SetSetting").OnServerEvent:Connect(onSetSetting)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return SettingsService
