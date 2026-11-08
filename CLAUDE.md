# Krillion

Roblox party game. Code is synced with Rojo (`default.project.json`); everything visual lives in the Studio place.

## Commands

- Tests: `lune run tests/run.luau` (pure modules under `src/ReplicatedStorage/Shared`, plus the prompt bank).
- Build check: `rojo build default.project.json -o <scratch>.rbxl`.

## Studio is the source of truth for instances

- UI, map, lighting, sounds and templates are authored in Studio, never created by code. Code finds and drives them.
- Do not author an instance in Studio while a `model.json` still owns it: Rojo reverts it on a later sync. Delete the
  `model.json` first, with Rojo disconnected. Remaining ones: `ReplicatedStorage/Remotes/*`, `Templates/{BotRig,Confetti,DiveCard,HowRareBoard,HowToBoard,Trails,leaderstats}`, `Sounds`.
- `ServerStorage.UIArchive` keeps the UI as it was before the style bake (2026-11-05). Reference only.
  `ServerStorage.Sonar` keeps the retired floating prompt screen model; no code uses it.
- Map: Arena, Lobby and Mountains sit in Workspace as authored; MapService finds them and builds nothing.
  `ServerStorage.PhysicalAssets` holds `PlatformTemplate` (cloned per pillar, walls authored on it) and
  `TerrainBackup`. The tank hole (radius 40, from y -20 up) is carved into the terrain.
  `Arena.Beach` holds the beach decor; `Arena.SeaLife` holds fish and schools that `Client/SeaLife` swims round
  the island (each child model's `Speed` attribute is studs per second, sign = direction).
- Beach: the island top (y 0, x -96..96, z -96..80) slopes as a smoothstep from 16 studs inside its edge to the
  sea floor (y -28) 64 studs out, on every side; partial-occupancy sand keeps it smooth under water. Terrain sea
  (sand y -32..-28, water to y -4) reaches 1024 studs out; eight `Arena.FarSea` planes carry it to 3072. The
  pre-slope, pre-carve terrain is `PhysicalAssets.TerrainBackup` (a TerrainRegion; `Terrain:PasteRegion` restores it).
- Renaming or removing a `default.project.json` node while Rojo is connected makes Rojo delete the old instance
  with everything in it. Move the contents out first (or undo the "Rojo: Patch" waypoint).
- Declaring a new node in `default.project.json` while Rojo is connected makes Rojo create an empty placeholder
  next to an instance you already moved there. Check for duplicates and delete the empty one.
- Prompt bank: one module per prompt in `src/ServerStorage/PromptBank/`, listed in its `init.luau`;
  `tests/PromptBank.test.luau` guards it (normalized answers, no duplicates, aliases point at answers).
- Templates cloned by code that are authored in Studio: `ReplicatedStorage.Templates.AfkTag` (SettingsService puts
  it on an AFK player's Head), `Templates.AnswerTag`, `Templates.Title`.
- World labels: each BillboardGui's main child is centred and holds a UIScale named `DistanceScale`;
  `Client/BillboardScale` keeps it at authored size within 45 studs and shrinks it beyond. Give new labels one.
- Loading screen: `ReplicatedFirst.LoadingScreen` (authored), with `ScreenInsets = None` and
  `ClipToDeviceSafeArea` off so it covers the phone notch area.
- StreamingEnabled is on: models a client animates far away (`Arena.SeaLife`) use `ModelStreamingMode = Atomic`
  and are picked up with `ChildAdded` as they stream in.
- Audio: UI sounds and the `Music` playlist folder live in `SoundService.Krillion` (Sfx looks there first, then
  `ReplicatedStorage.Sounds`). Music tracks play in name order from a random start.
- After Studio edits, remind the user to save the place.

## UI layout

Three ScreenGuis in StarterGui, each holding full-screen screen Frames (one per former ScreenGui):

| Root | DisplayOrder | Studio default | Screens |
|------|--------------|----------------|---------|
| `GameUi` | 1 | Enabled off (code turns it on) | Hud, Reveal, Results, Revive, Spectate, Vignette |
| `LobbyUi` | 2 | on | Rail, Shop, LobbyQuiz, Quests, Rewards, Tutorial |
| `SharedUi` | 3 | on | Status, Toasts, Fx, Wallet, DiveCards, Settings |

- Controllers get a screen with `Ui.screen(playerGui, "Hud")` (or `Ui.findScreen`) and show it with `Visible`.
  The name-to-root map is `ROOT_OF` in `Client/Ui.luau`; update it when a screen moves.
- Layering inside a root is the screen Frame's `ZIndex`; across roots it is the root's `DisplayOrder`.
- Roots use `IgnoreGuiInset = true`. A screen with attribute `BelowTopbar = true` is moved below the Roblox top
  bar at runtime (Studio has no top bar, so it is authored flush with the top).
- Lobby rail (left edge, `LobbyUi.Rail.RailFrame`): QUESTS, REWARDS, SHOP, HELP keys. Each controller connects
  its key with `Rail.button(name)`; the rail hides in a match and while the shop is open. On short screens it
  wraps into two columns and sizes itself to its visible keys.
- Pop-up windows (Quests, Rewards, Help, Shop, Settings) share the Quests panel's top edge: centre-anchored at
  `Position.Y = (0.5 + heightScale / 2, -248 + heightOffset / 2)`.
- Screen corners: the Roblox player list owns the top-right, so keep it clear. The top-left holds the Settings
  gear, matching Roblox's own buttons: a 44 px circle, RGB(18, 18, 21) at 0.08 transparency, 8 px after
  `GuiService.TopbarInset.Min.X` and 2 px above its bottom. Toasts stack in the bottom-left
  (past the match water meter, above the touch thumbstick). The bottom-right column, from the
  bottom: the one Shells chip (`SharedUi.Wallet.Chip`, always on), the Hint and +10 SEC boosts (`Hud.BoostBar`,
  match only) docked on it, and the Wallet pop-ups above whatever is highest.
- Spacing: 16 px from screen edges, 8 px between stacked pieces, text at least 12 px from a button or pill's
  sides.
- The look (outlines, gradients, corners, `LiftedText` captions) is authored. `Ui.bindAll` only binds live
  behaviour: outlines tracking text, captions mirroring their label, pop-up fit (`GROWS`) and icon prefixes (`ICONS`).

## Studio MCP tips

- `require` inside `execute_luau` returns a fresh copy of a game module, not the running one. Test through
  remotes (`FireServer`/`FireClient`) or by reading instances.
- Plugin-level `execute_luau` can read `CoreGui.TopBarApp`, so Roblox's own top bar can be measured to match it.
- A Creator Store decal id does not load in an ImageLabel; `InsertService:LoadAsset(decalId)` gives the Decal
  whose `Texture` is the image id.
- `user_keyboard_input` with an `instance_path` clicks that instance first; to type into a focused box, omit it.
