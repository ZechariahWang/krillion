# Rare or Sink

Roblox party game. Code is synced with Rojo (`default.project.json`); everything visual lives in the Studio place.

## Commands

- Tests: `lune run tests/run.luau` (pure modules under `src/ReplicatedStorage/Shared`, plus the prompt bank).
- Build check: `rojo build default.project.json -o <scratch>.rbxl`.
- Syntax check of every script, including Roblox-side ones the tests cannot run: `lune run tests/syntax.luau src`
  (compiles with `@lune/luau`; there is no luau-analyze). Run it after editing client or server code.

## Studio is the source of truth for instances

- UI, map, lighting, sounds and templates are authored in Studio, never created by code. Code finds and drives them.
- Do not author an instance in Studio while a `model.json` still owns it: Rojo reverts it on a later sync. Delete the
  `model.json` first, with Rojo disconnected. Remaining ones: `ReplicatedStorage/Remotes/*`, `Templates/{BotRig,Confetti,DiveCard,HowRareBoard,HowToBoard,Trails,leaderstats}`, `Sounds`.
- `ServerStorage.UIArchive` keeps the UI as it was before the style bake (2026-11-05). Reference only.
- Modes: the rising-water mode is live. Crab Craze (tried 2026-11-10 to 13) is kept at git tag
  `mode/crab-craze`, with Studio copies of its authored pieces in `ServerStorage.CrabCrazeInstances`
  (reference only). Keep Studio-only archives as direct children of ServerStorage: Rojo deletes Studio-only
  children of any folder it syncs from disk below that (it deleted `ModeArchive.RisingWater.Instances` on a
  branch switch; `ServerStorage.TowerInstancesBackup` is the recovered copy).
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
- Every `default.project.json` node carries `$ignoreUnknownInstances`, so Studio-only children are kept on
  sync; only renaming or removing a declared node still deletes.
- Renaming or removing a `default.project.json` node while Rojo is connected makes Rojo delete the old instance
  with everything in it. Move the contents out first (or undo the "Rojo: Patch" waypoint).
- Declaring a new node in `default.project.json` while Rojo is connected makes Rojo create an empty placeholder
  next to an instance you already moved there. Check for duplicates and delete the empty one.
- Prompt bank: one module per prompt in `src/ServerStorage/PromptBank/`, listed in its `init.luau`;
  `tests/PromptBank.test.luau` guards it (normalized answers, no duplicates, aliases point at answers).
- Templates cloned by code that are authored in Studio: `Templates.AnswerTag`, `Templates.NameTag`, the head
  label (CosmeticService puts it on every Head, named `RareOrSinkName`; Roblox's own name display is off). Its
  `Main` is a bottom-anchored vertical list, so hidden rows collapse: `Afk`, `TitleText`, `NameText`. The
  server fills the name and title; `Client/HeadTags` shows the `Afk` row from the player's `Afk` attribute
  and lifts labels that would overlap on screen (`Shared/LabelSpread`), so no two cover each other.
  `Templates.ShellPickup` (PickupService drops them on the sand and deck between rounds). `Templates.Title` is
  unused.
- Sea dressing: `Arena.Reef.Coral.Extra` and `Arena.Beach.GrassExtra` hold the extra kelp, coral and tufts;
  `Arena.Beach.Shallows` the seagrass, kelp, coral and shells on the
  underwater slope (kept under the surface), `Arena.Beach.Clutter` the towels, buckets, driftwood and net,
  `Arena.Beach.LifeguardChair` the chair; `Arena.Beach.Palm` models are built from parts (trunk segments, fronds, coconuts).
  `Arena.SeaLife` also holds six `Sailboat` models (part-built yachts floating at the water level, y -4:
  tapered hull, cabin, rails, mast, main and jib hung along the boom so their faces show from the island),
  `Seagull` and `Buoy` models (Persistent, `Speed` attribute) that SeaLife moves round the island.
- Phones play landscape only (`StarterGui.ScreenOrientation`). In a match a phone shows only the strip at the
  top (prompt, timer, `Hud.AnswerBar` at 17% of the height, boosts beside it), above where the on-screen
  keyboard reaches; `PromptEcho` stays hidden. Walking is off on a pillar (`Hud` disables the touch controls).
- World labels: each BillboardGui's main child is centred (the head label's is bottom-anchored, so it shrinks
  towards the head) and holds a UIScale named `DistanceScale`; `Client/BillboardScale` keeps it at authored
  size within 45 studs and shrinks it beyond. Give new labels one.
- Loading screen: `ReplicatedFirst.LoadingScreen` (authored), with `ScreenInsets = None` and
  `ClipToDeviceSafeArea` off so it covers the phone notch area.
- StreamingEnabled is on. Client code must not cache streamed parts: a part that streams back in is a new instance
  (the next-level ring once showed only an arc). Read children when you use them, or watch `ChildAdded`.
  `Arena.SeaLife` swimmers are `Atomic`; `Arena.NextLevel` is `Persistent` (always on every client).
- Day and night: Lighting's properties and linear fog are the day look; its `NightAmbient` / `NightOutdoorAmbient`
  attributes and the `Lighting.Atmosphere` haze are the night look. `Client/DayNight` blends them at dusk and dawn
  (fog out, then haze in) and lights parts tagged `NightLight` (lobby and beach torches, `Arena.TankLights`)
  only at night.
- `Arena.Reef` (OuterRim rocks, Ledges, Coral) stays clear of the tank glass (radius 41.0..41.6): rocks outside,
  ledges inside.
- Lobby (`Workspace.Lobby`) is grouped into models (Deck, Railing, Bunting, SnackShack, Lamps, PatioSets, ...).
  `LobbySpawn`, `HowToBoard`, `HowRareBoard`, `QuizZone` and `QuizArc` stay direct children: code looks them up
  by name. `QuizZone` carries `ArcCenter`, `Outward` and `Radius` attributes describing the glowing semicircle
  (`QuizArc`) in front of the shack: LobbyQuizService serves warm-up prompts to whoever stands on it (`LobbyUi.LobbyQuiz`, a centred window with
  an X; a match closes it). `Lobby.WestStairs`
  and `EastStairs` lead off the side rails to the beach. The How to Play / How Rare boards and the Top 10 stand
  along the back of the deck, facing the front. Players roam the whole island: invisible `Arena.BeachBorder` walls
  stand just short of the waterline (and behind the deck) so nobody swims out.
- `PhysicalAssets.TerrainBeforeDunes` is the terrain before the beach dunes were added.
- Audio: UI sounds and the `Music` playlist folder live in `SoundService.RareOrSink` (Sfx looks there first, then
  `ReplicatedStorage.Sounds`). Music tracks play in name order from a random start. Every track is DistroKid
  music from the Creator Store (Roblox-only licence) and carries `Title`, `Artist` and `Source` attributes that
  `Client/Music` shows as a toast when it starts; `docs/music-credits.md` lists them.
- After Studio edits, remind the user to save the place.

## Match flow

- Phases: Waiting, Intermission, Starting, Prompt, Reveal, Surge, Results. Before Starting, `MatchIntro` fades the
  starters' screens to black and the server teleports them; Starting is the 3-2-1 on the pillars
  (`Client/Transition`, `SharedUi.Transition`). Lengths are `GameConfig.Round.IntroFadeSeconds` and
  `StartCountdownSeconds`.
- Every teleport goes through `PlayerService.sendToPlatform` / `sendToLobby`: they anchor the root, move it, and
  release it once the spot has streamed in, so nobody falls through a pillar their client does not have yet.
- Dying or respawning while alive in a match eliminates the player (RoundService), like sinking.
- Settings: music on/off and volume are saved in the profile (`musicOff`, `musicVolume`); AFK is session only.
- Profiles: a load that fails after retries leaves the player read-only (`DataService.isReadOnly`): no spends,
  payouts or saves, `loadFailed` in the payload, retried every 60 s. Studio is exempt and gets a throwaway
  writable profile, so local tests never go read-only. A stored `activeSession` marker makes a second server
  wait up to 10 s for the first one's leave-save.

## UI layout

Three ScreenGuis in StarterGui, each holding full-screen screen Frames (one per former ScreenGui):

| Root | DisplayOrder | Studio default | Screens |
|------|--------------|----------------|---------|
| `GameUi` | 1 | Enabled off (code turns it on) | Hud, Reveal, Results, Revive, Spectate, Vignette |
| `LobbyUi` | 2 | on | Rail, Shop, Inventory, Store, LobbyQuiz, Quests, Rewards, Tutorial |
| `SharedUi` | 3 | on | Status, Toasts, Fx, Wallet, DiveCards, Settings, Transition, ChestReveal |

- Controllers get a screen with `Ui.screen(playerGui, "Hud")` (or `Ui.findScreen`) and show it with `Visible`.
  The name-to-root map is `ROOT_OF` in `Client/Ui.luau`; update it when a screen moves.
- Controllers wait at most 10 s (`WAIT_SECONDS`) for their screen and children, then warn and set a `ready`
  flag false so their handlers do nothing. Never wait without a timeout in `init`: Main's init chain is
  synchronous and one missing child would stall every controller after it.
- Layering inside a root is the screen Frame's `ZIndex`; across roots it is the root's `DisplayOrder`.
- Roots use `IgnoreGuiInset = true`. A screen with attribute `BelowTopbar = true` is moved below the Roblox top
  bar at runtime (Studio has no top bar, so it is authored flush with the top).
- Lobby rail (left edge, `LobbyUi.Rail.RailFrame`): QUESTS, REWARDS, SHOP, STORE, ITEMS keys. Each controller connects
  its key with `Rail.button(name)`; the rail hides in a match and while any window is open. On short screens it
  wraps into two columns and sizes itself to its visible keys. `Rail.HelpButton` is the top-bar circle right of
  the Settings gear (`Ui.placeTopButton`); `Rail.ToyButton` is the small THROW key above the Shells chip.
- Pop-up windows (Quests, Rewards, Help, Shop, Settings) and the match countdown sit dead centre: anchor
  (0.5, 0.5) at Position (0.5, 0.5). One window at a time: each reports to `Client/Windows`, and while any is
  open the rail, the top buttons, the status chips and the Shells chip hide (the warm-up quiz opens with
  `keepStatus`, so the phase and countdown chips stay). Window titles carry no emoji.
- Shop (`LobbyUi.Shop.Holder.Panel`) and Inventory (`LobbyUi.Inventory`, the same tree with only the cosmetic
  sections): the section keys under `Sections` carry `Kind` (Featured | Slots | Chests | Shells | Passes |
  Specials) and, for Slots, a comma list in `Slots`; `Tools` holds the search box and filter keys. `ShopUi`
  drives both; the rail SHOP and ITEMS keys open them. Robux items (passes, Shell packs, specials) have their
  own STORE window (`LobbyUi.Store`).
- Screen corners: the Roblox player list owns the top-right, so keep it clear. The top-left holds the Settings
  gear, matching Roblox's own buttons: a 44 px circle, RGB(18, 18, 21) at 0.08 transparency, 8 px after
  `GuiService.TopbarInset.Min.X` and 2 px above its bottom. Toasts stack in the bottom-left
  (past the match water meter, above the touch thumbstick). The bottom-right column, from the
  bottom: the one Shells chip (`SharedUi.Wallet.Chip`, always on), the Hint and +10 SEC boosts (`Hud.BoostBar`,
  match only) docked on it, and the Wallet pop-ups above whatever is highest.
- Icons are ImageLabels authored in Studio; text never carries an emoji. The artwork lives once in
  `ReplicatedStorage.Templates.Icons` (one ImageLabel per name: `Shell`, `Trophy`, `Fish`...). An icon beside
  text is a child named `Icon` sitting in that label's UIPadding. Code only picks an image by name when it
  depends on data (`Client/Icons.image`: toast kind, quest kind, shop and chest items via `Client/ItemIcon`)
  or shows and hides an authored one (`Icons.show`: the status clock, the boost price shell). The X, + and
  arrow marks are authored bars and labels inside their buttons.
- Icon images: `assets/ui-icons/<Name>.png` are the uploaded files (group-owned; ids in `ids.json`), made by
  `normalize.py` from Codex's Style A originals so every icon is trimmed, centred and the same size. A new icon
  goes through `normalize.py`, gets uploaded, and its id goes in `ids.json` and `Templates.Icons`. An `Icon`
  beside text sits 8 px from it (4 to 6 px on small labels) and at least 12 px from a button's edge.
- Spacing: 16 px from screen edges, 8 px between stacked pieces, text at least 12 px from a button or pill's
  sides.
- The look (outlines, gradients, corners, `LiftedText` captions) is authored. `Ui.bindAll` only binds live
  behaviour: outlines tracking text, captions mirroring their label and pop-up fit (`GROWS`).

## Studio MCP tips

- `require` inside `execute_luau` returns a fresh copy of a game module, not the running one. Test through
  remotes (`FireServer`/`FireClient`) or by reading instances.
- Plugin-level `execute_luau` can read `CoreGui.TopBarApp`, so Roblox's own top bar can be measured to match it.
- A Creator Store decal id does not load in an ImageLabel; `InsertService:LoadAsset(decalId)` gives the Decal
  whose `Texture` is the image id.
- `user_keyboard_input` with an `instance_path` clicks that instance first; to type into a focused box, omit it.
- `get_console_output` returns only Edit-context lines. In play, run `game:GetService("LogService"):GetLogHistory()`
  on the Client or Server datamodel to read the game's output.
- `ServerStorage.RareOrSinkDebug:Invoke("state")` (Server datamodel, DebugService) returns the match snapshot:
  phase, round, alive ids, heights, water level, prompt.
- Screenshots come back at 1596x1080 but the viewport is 1152x779; `user_mouse_input` takes viewport pixels.
- With `MinPlayers = 1` a solo match starts 15 s after joining. To test the lobby, turn AFK on in Settings first.
