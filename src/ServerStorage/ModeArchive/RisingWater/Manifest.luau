--!strict
-- The rising-water mode (pillars rise by answer rarity, the water surges, the last one standing wins), as it
-- stood at git tag mode/rising-water. Nothing here runs: every module's require paths point at its old home.
--
-- To bring the mode back, either check out the tag, or:
--   1. Copy each module below over the file at its original path (two are renamed: see MainServer, MainClient).
--   2. Put the tests in tests/archive/rising-water back in tests/ and list them in tests/run.luau.
--   3. In Studio, put the copies under Instances (authored in the place, not in git) back where their
--      names say: GameUi, SharedUi.Status, SharedUi.Transition and LobbyUi.Tutorial under StarterGui,
--      Templates under ReplicatedStorage.Templates, Arena.NextLevel under Workspace.Arena and
--      PlatformTemplate under ServerStorage.PhysicalAssets. Turn GameUi's Enabled back off.
--   4. Run the tests, the syntax check and a play test.

return {
	Tag = "mode/rising-water",
	-- Archived module (under this folder) to the path it came from.
	Files = {
		["Server/RoundService"] = "src/ServerScriptService/Server/RoundService.luau",
		["Server/WaterService"] = "src/ServerScriptService/Server/WaterService.luau",
		["Server/MapService"] = "src/ServerScriptService/Server/MapService.luau",
		["Server/BotService"] = "src/ServerScriptService/Server/BotService.luau",
		["Server/AnswerService"] = "src/ServerScriptService/Server/AnswerService.luau",
		["Server/BoostService"] = "src/ServerScriptService/Server/BoostService.luau",
		["Server/DebugService"] = "src/ServerScriptService/Server/DebugService.luau",
		["Server/PlayerService"] = "src/ServerScriptService/Server/PlayerService.luau",
		["Server/MainServer"] = "src/ServerScriptService/Main.server.luau",
		["Shared/MatchState"] = "src/ReplicatedStorage/Shared/MatchState.luau",
		["Shared/WaterCurve"] = "src/ReplicatedStorage/Shared/WaterCurve.luau",
		["Shared/WaterSurface"] = "src/ReplicatedStorage/Shared/WaterSurface.luau",
		["Shared/Tide"] = "src/ReplicatedStorage/Shared/Tide.luau",
		["Shared/SpecialRound"] = "src/ReplicatedStorage/Shared/SpecialRound.luau",
		["Shared/LateJoin"] = "src/ReplicatedStorage/Shared/LateJoin.luau",
		["Shared/Schooling"] = "src/ReplicatedStorage/Shared/Schooling.luau",
		["Shared/BotBrain"] = "src/ReplicatedStorage/Shared/BotBrain.luau",
		["Shared/Economy"] = "src/ReplicatedStorage/Shared/Economy.luau",
		["Shared/Net"] = "src/ReplicatedStorage/Shared/Net.luau",
		["Shared/Boosts"] = "src/ReplicatedStorage/Shared/Boosts.luau",
		["Config/GameConfig"] = "src/ReplicatedStorage/Config/GameConfig.luau",
		["Client/Hud"] = "src/StarterPlayer/StarterPlayerScripts/Client/Hud.luau",
		["Client/Status"] = "src/StarterPlayer/StarterPlayerScripts/Client/Status.luau",
		["Client/Tide"] = "src/StarterPlayer/StarterPlayerScripts/Client/Tide.luau",
		["Client/WaterFx"] = "src/StarterPlayer/StarterPlayerScripts/Client/WaterFx.luau",
		["Client/PillarTags"] = "src/StarterPlayer/StarterPlayerScripts/Client/PillarTags.luau",
		["Client/Reveal"] = "src/StarterPlayer/StarterPlayerScripts/Client/Reveal.luau",
		["Client/Lobby"] = "src/StarterPlayer/StarterPlayerScripts/Client/Lobby.luau",
		["Client/Results"] = "src/StarterPlayer/StarterPlayerScripts/Client/Results.luau",
		["Client/RevivePrompt"] = "src/StarterPlayer/StarterPlayerScripts/Client/RevivePrompt.luau",
		["Client/Transition"] = "src/StarterPlayer/StarterPlayerScripts/Client/Transition.luau",
		["Client/Tutorial"] = "src/StarterPlayer/StarterPlayerScripts/Client/Tutorial.luau",
		["Client/MainClient"] = "src/StarterPlayer/StarterPlayerScripts/Main.client.luau",
	},
}
