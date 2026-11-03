# Krillion pass 2: polish, stats, reef arena, cosmetics, shop, loading screen

## Intent

The core loop works. This pass makes it feel good and gives players reasons to come back and to spend: a punchier reveal, persistent stats and a global board, a reef arena instead of a square tank, cosmetics, a shop with paid options, and a clean loading screen. A few quick fixes come first.

Standing rules still apply: every instance (UI, parts, sounds, particles, remotes) is authored in the Studio place; code only finds, clones and drives it. New UI matches StarterGui.RefLobby / RefGame (dark translucent panels, Roboto, bold italic titles, UIShadow, no text outlines). Tunables go in `GameConfig`.

## Anti-goals

- Anything loud, cartoony or cluttered. "Clean and modern" governs every effect.
- Pay-to-win beyond the one revive the user explicitly chose.
- Runtime-generated UI or map instances.

## 1. Quick fixes

1. **Flat lobby ground.** The ground under/around the boardwalk lobby is uneven. Flatten it in Studio (terrain and/or parts, whichever it is) so players walk on a level surface.
2. **No movement on a platform.** While `Playing` is true, the character cannot walk or jump: `WalkSpeed = 0` as well as the existing jump = 0, in `PlayerService.setMovement`. `GameConfig.Platform.WalkSpeed` becomes 0 (or is removed). Lobby movement restores to StarterPlayer defaults as today.
3. **No shift lock.** `StarterPlayer.EnableMouseLockOption = false`, set in Studio.

## 2. Reveal rewards

All feedback stays at the reveal (nothing on submit). The existing pieces in `Reveal.luau`, `Fx.luau`, `Sfx.luau` stay; they get more snap:

- **Badge pop:** the tier badge scales in with a small overshoot (about 0.9 -> 1.05 -> 1.0, via a UIScale) instead of a plain appear.
- **Count-up ticks:** a soft tick sound plays during the points count-up, pitch rising as it climbs, ending on a "ding" whose weight scales with tier.
- **Tier escalation:** Plankton gets a light ding; Rare and above add a short particle ring from your platform and a brief camera kick (`Fx.shake`); One in a Krillion gets the full stack (flash, fanfare, particles, a slightly longer badge hold).
- **Platform rise:** a quick bubble burst and whoosh at your platform when it starts rising, so the rise connects to the number.
- **Streak:** the streak callout gets the same pop, and a chime whose pitch rises with each streak level.

Sounds go in `SoundService.Krillion`; particle emitters are authored on the platform template (or an Fx template) and toggled/`Emit`ted by code.

## 3. Stats

**Leaderstats** (standard Roblox player list, top right), three values:

- **Wins:** matches won. A solo match (one participant) does not count as a win.
- **Cash:** the existing lobby-quiz coins, renamed Cash everywhere user-visible (HUD, quiz result text). Same currency, not a new one. Matches also pay Cash (per round survived plus a winner bonus) and pay noticeably more than the lobby quiz; amounts live in `GameConfig`.
- **Best:** highest platform height ever reached, in studs above the starting water line, rounded down to a whole number. Updated whenever a player's `MatchState` height exceeds their record.

All persist. `DataService` grows from a bare coin number into a small profile (Cash, Wins, Best, owned cosmetics, equipped cosmetics). Cross-server safety still comes from `UpdateAsync` merging session changes into the stored value: sum deltas for Cash and Wins, `max` for Best, union for owned items, last-write for equipped. Existing `coins_<UserId>` values migrate into the new profile on first load.

**Top-10 board:** a board on one side of the boardwalk lobby (authored in Studio, SurfaceGui with 10 row slots) showing the global top 10 by Wins, from an OrderedDataStore, refreshed about every 60 seconds.

## 4. Round reef arena

Replace the square tank with a round reef:

- Platforms laid out in a ring or loose circle (replaces the grid in `MapService.platformPosition`; `Columns` / `Spacing` config replaced by ring radius settings that still fit 12 players).
- A curved rock/reef rim replaces the tank walls.
- Coral clusters, sea fans, kelp and rocks, all authored in Studio. Some sit below the waterline so they disappear as water rises. Decor stays below platform-top height so it never blocks the view of other players.
- Water, caustics and surge behaviour stay as they are; terrain water fill must follow the round shape.

## 5. Cosmetics

Three slots, one equipped item per slot:

- **Platform skins:** change the look of your pillar/cap (e.g. coral, gold, glass). Applied when platforms spawn, replacing the per-index `Theme.Pillars` colour for that player.
- **Titles:** a tag above your head (e.g. "Deep Diver"), BillboardGui template authored in Studio.
- **Elimination splashes:** the effect when you sink (e.g. ink cloud, bubble burst).

Most are bought with Cash; a few premium ones are Robux-only. A small starter catalogue (about 3-5 per slot) is enough for this pass; the catalogue lives in a config module.

## 6. Paid options

- **VIP game pass:** VIP title plus +10% Cash.
- **2x Cash game pass.**
- **Cash packs:** Robux developer products.
- **Revive developer product:** buying it adds one Revive to the player's saved inventory (a count in the profile). Use is limited to once per match per player. The in-match revive prompt appears only for players who hold at least one Revive, so nobody else ever sees it. When such a player sinks, a short prompt (about 5 s) offers to use one. Using it spends one, puts them back on a platform a few studs above the current water, and keeps their score.

Purchases go through `MarketplaceService.ProcessReceipt` with idempotent granting (receipt id recorded so retries never double-grant).

## 7. Shop GUI

One shop window, opened from a lobby button, with tabs: Skins, Titles, Splashes, Passes. Shows price (Cash or Robux), owned/equipped state, and buy/equip buttons; the Passes tab also sells Cash packs and Revives and shows how many Revives you hold. Authored in Studio in the RefLobby style.

All game pass and developer product IDs are placeholders in a config module; the user creates the real ones in the Creator Hub later.

## 8. Loading screen

A custom loading screen in ReplicatedFirst replacing the default: dark backdrop, Krillion logo, thin progress bar filling as content loads, soft bubbles drifting up behind. Minimum display about 1.5 s so it never flashes; a skip appears after about 10 s in case loading stalls. When done it fades out quickly and the player is straight in the lobby (no Play button).

## Build order

Quick fixes, then reveal rewards, stats + board, loading screen, reef arena, cosmetics, paid options + shop. Each is its own commit.

## Calls made by Claude (not yet confirmed by the user)

- **Revive window:** the prompt is offered only if at least 2 other players are still alive, so a revive never undoes a decided match; the match does not wait on an unanswered prompt beyond its ~5 s.
- **Match Cash amounts:** starting values 25 Cash per round survived and 100 for a win. The lobby quiz drops from points x 0.5 to points x 0.2 (at most 20 per answer) so it pays clearly less than a match.

- **Wins:** the winner is `MatchState.winner` at match end; a match counts if it started with 2+ participants, even if others left mid-match.
- **Best:** read from `MatchState.heights` (platform standing surface), per match; a revive does not reset it.
- **Cash multipliers:** VIP +10% and 2x stack additively (2.1x), apply to earned Cash only, never to Cash packs.
- **VIP title:** a normal Titles-slot item whose ownership the VIP pass grants.
- **Robux-only cosmetics:** one developer product per item, granting permanent ownership through ProcessReceipt.
- **Migration:** legacy `coins_<UserId>` is read once into the new profile and left in place as a backup. The Wins OrderedDataStore is written whenever a player's Wins change; no backfill.
- **Loading:** waits on `game:IsLoaded()` then `ContentProvider:PreloadAsync` over the authored UI/sound assets; progress bar tracks that list; the skip is a small button.
- **Ring layout:** adapts to the match's player count (spacing stays comfortable for 2 to 12); camera and water fill follow the round arena.

## Left to the builder

Exact art, colours, sound picks, particle tuning, cosmetic names and prices, board placement, ring radius, and the profile key/schema details, within the constraints above.
