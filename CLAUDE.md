# Krillion

Roblox party game. Code is synced with Rojo (`default.project.json`); everything visual lives in the Studio place.

## Commands

- Tests: `lune run tests/run.luau` (pure modules under `src/ReplicatedStorage/Shared`).
- Build check: `rojo build default.project.json -o <scratch>.rbxl`.

## Studio is the source of truth for instances

- UI, map, lighting, sounds and templates are authored in Studio, never created by code. Code finds and drives them.
- Do not author an instance in Studio while a `model.json` still owns it: Rojo reverts it on a later sync. Delete the
  `model.json` first, with Rojo disconnected. Remaining ones: `ReplicatedStorage/Remotes/*`, `Templates/{BotRig,Confetti,DiveCard,HowRareBoard,HowToBoard,Trails,leaderstats}`, `Sounds`.
- `ServerStorage.UIArchive` keeps the UI as it was before the style bake (2026-11-05). Reference only.
  `ServerStorage.Sonar` keeps the retired floating prompt screen model; no code uses it.
- Beach: the island top (y 0, x -96..96, z -96..80) slopes as a smoothstep from 16 studs inside its edge to the
  sea floor (y -28) 64 studs out, on every side; partial-occupancy sand keeps it smooth under water. The pre-slope
  terrain is `ServerStorage.Maps.TerrainBackup` (a TerrainRegion; `Terrain:PasteRegion` restores it).
- Declaring a new node in `default.project.json` while Rojo is connected makes Rojo create an empty placeholder
  next to an instance you already moved there. Check for duplicates and delete the empty one.
- After Studio edits, remind the user to save the place.

## UI layout

Three ScreenGuis in StarterGui, each holding full-screen screen Frames (one per former ScreenGui):

| Root | DisplayOrder | Studio default | Screens |
|------|--------------|----------------|---------|
| `GameUi` | 1 | Enabled off (code turns it on) | Hud, Reveal, Results, Revive, Spectate, Vignette |
| `LobbyUi` | 2 | on | Rail, Shop, LobbyQuiz, Quests, Rewards, Tutorial |
| `SharedUi` | 3 | on | Status, Toasts, Fx, Standings, Wallet, DiveCards |

- Controllers get a screen with `Ui.screen(playerGui, "Hud")` (or `Ui.findScreen`) and show it with `Visible`.
  The name-to-root map is `ROOT_OF` in `Client/Ui.luau`; update it when a screen moves.
- Layering inside a root is the screen Frame's `ZIndex`; across roots it is the root's `DisplayOrder`.
- Roots use `IgnoreGuiInset = true`. A screen with attribute `BelowTopbar = true` is moved below the Roblox top
  bar at runtime (Studio has no top bar, so it is authored flush with the top).
- Lobby rail (left edge, `LobbyUi.Rail.RailFrame`): QUESTS, REWARDS, SHOP, HELP keys. Each controller connects
  its key with `Rail.button(name)`; the rail hides in a match and while the shop is open.
- Screen corners: the Roblox player list owns the top-right, so keep it clear. The bottom-right column, from the
  bottom: the one Shells chip (`SharedUi.Wallet.Chip`, always on), the Standings tab docked on it (its list opens
  to the tab's left), the Hint and +10 SEC boosts (`Hud.BoostBar`, match only) docked on the tab, and the Wallet
  pop-ups above whatever is highest.
- Spacing: 16 px from screen edges, 8 px between stacked pieces, text at least 12 px from a button or pill's
  sides.
- The look (outlines, gradients, corners, `LiftedText` captions) is authored. `Ui.bindAll` only binds live
  behaviour: outlines tracking text, captions mirroring their label, pop-up fit (`GROWS`) and icon prefixes (`ICONS`).
