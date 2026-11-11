--!strict
-- Short toast messages to one player or everyone, shown by the client's Toasts controller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local KINDS = { info = true, good = true, bad = true, mythic = true, hint = true }

local NotifyService = {}

local function kindOf(kind: string?): string
	if kind ~= nil and KINDS[kind] then
		return kind
	end
	return "info"
end

-- kind: "info" | "good" | "bad" | "mythic" | "hint". Text is our own copy; never pass raw chat text here.
function NotifyService.send(player: Player, text: string, kind: string?)
	if player.Parent == nil then
		return
	end
	Net.event("Notify"):FireClient(player, { text = text, kind = kindOf(kind) })
end

function NotifyService.sendAll(text: string, kind: string?)
	Net.event("Notify"):FireAllClients({ text = text, kind = kindOf(kind) })
end

function NotifyService.start()
	-- Looked up now so a missing remote shows up at boot, not on the first toast.
	Net.event("Notify")
end

return NotifyService
