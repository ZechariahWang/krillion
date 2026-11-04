# Studio changes

Some of the game lives only in the Roblox place, not in git: `Workspace.Lobby`, `ServerStorage.Maps.Arena`, the Studio-built ScreenGuis and so on. Rojo leaves those alone. When a change has to be made there, the Edit-mode script that makes it is kept in this folder, so the change is written down, can be reviewed in a PR and can be run again.

Files here are **not** synced by Rojo and never run in the game. You paste them into Studio by hand.

## 2026-11-04-stud-theme.luau

Gives the lobby deck and the arena reef a Roblox stud look. Nothing moves: positions, sizes and names stay the same, so the layout, the lobby spawn and every pillar position are unchanged.

| Where | Parts | Change |
|---|---|---|
| `Workspace.Lobby` | Plank x25, SubFloor, Trim x4, RailPost x32, RailTop x3, RailMid x3, RailCap, Brace x9, Crate x4 | Plastic, studs on the face that points up. Planks alternate two tans inside a dark-blue trim ring; rails white, posts navy, crates in toy colours. |
| `Workspace.Lobby` | Stilt x12 | Cylinder to square post (same size), navy. |
| `Workspace.Lobby` | Barrel x2 | Plastic, red. Stays round because its bands are props. |
| `Maps.Arena.Reef.OuterRim` | Rock x56 | Plastic, brighter stone, studs on whichever face points most upward (most rocks are tilted). |
| `Maps.Arena.Reef.Ledges` | Stone x91 | Ball to cube (same size, tilt removed, yaw kept), brighter stone. |
| `Maps.Arena.Reef.Coral` | Kelp x90, SeaFan x26 | Plastic, studs on both broad faces, brighter greens and coral colours. |
| `Maps.Arena.Reef.Coral` | BrainCoral x30, Pebble x10, Tip x92 | Ball to cube (same size, so they still sit on the floor). |
| `Maps.Arena.Reef.Coral` | Branch x92 | Cylinder to square stick (same size and angle). |
| `Maps.Arena.Reef.Coral` | FanStem x26 | Plastic. |
| `Maps.Arena` | RimSegment x40 | Plastic, studs, the same two tans as the deck. |
| `Maps.Arena.PlatformTemplate` | Cap | Plastic with studs, so every pillar top is studded. Colour still comes from MapService. |

Colours come from `src/ReplicatedStorage/Config/Theme.luau` where a token fits (Ink, Red, Yellow, Water, Green, Tier.Rare and the pillar colours).

It never touches `Arena.Water`, `WaterSurface`, `NextLevel`, `Floor`, `GlassWall`, `FarSea`, the pillar's `Lift`, `Upright`, `Anchor`, `Top` and `NameTag`, or the lobby's `LobbySpawn`, `GlassRail`, `RailBlocker` and `Leaderboard`. Palms, mountains and lobby props (benches, tables, shack, flags, lamps) are left as they are.

### How to run it

1. Open the place in Studio in **Edit mode** (not Play). If you use `rojo serve`, sync from merged `main`.
2. Open **View > Command Bar**.
3. Open `docs/studio-changes/2026-11-04-stud-theme.luau` in an editor, copy the whole file, paste it into the command bar and press Enter.
4. Read the summary in the Output window. Each line shows how many parts were found and styled. A `<-- expected N` note means the place no longer has the part count the script was written for: look before saving.
5. Look around the lobby, and drag a copy of `ServerStorage.Maps.Arena` into Workspace if you want to see the reef (delete the copy afterwards, the game clones it at runtime).
6. Save the place. Publish only from a session synced to merged `main`, and only with Kevin's or Zechariah's go-ahead.

Options at the top of the script:

- `KEEP_COLOURS = true` changes material, shape and studs only and keeps today's colours.
- `VERSION` bumps let a later edit of the script re-style parts an older run already did. With the same `VERSION`, styled parts are skipped, so running it twice is safe.

### How to undo

Pick one, from quickest to most complete:

1. **Right after running it:** press Ctrl+Z in Studio. The script records one undo step.
2. **Any time later, before or after saving:** set `local MODE: string = "undo"` at the top of the script and run it the same way. Every styled part has its original material, colour, shape, surfaces and (for the balls turned into cubes) its rotation stored as `StudOrig*` attributes, and undo puts them back and removes the `StudTheme` tag and attributes.
3. **After publishing:** restore the previous place version. On the Creator Dashboard open the experience, then **Places > (this place) > Version History**, and click **Restore** on the version before the stud theme. Then re-open the place in Studio. This brings back the whole place as it was, so anything else changed since that version is lost too.

### Known limits

- Studs only render on Plastic parts with Block faces. Pillar skins with another material (Sea Glass, Gold, and any Glass, Foil, Marble, Ice, Basalt or Slate skins) show no studs on the cap. That is expected.
- `CosmeticService.applySkin` keeps the cap Plastic for plastic-look skins (no material, Coral, Kelp), so those pillars keep their studs too.
- Turning a Ball into a Block keeps the same Size, so a cube is bulkier than the ball it replaces. The bottom stays where it was, so nothing floats.
