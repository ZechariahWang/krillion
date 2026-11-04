# Krillion pass 3: porting the best of Sink or Niche

## Intent

Kevin's older game, Sink or Niche, is the same idea as Krillion (give the rarest answer, rise above the water) with a few years of extra features on it. This pass brings the parts that make it feel good into Krillion without losing what Krillion does better: the clean screen where you can always see how high everyone else's pillar is, the Studio-authored UI, and the Rojo + strict Luau + Lune setup.

What comes over, in one line each:

- **The dive card.** At the reveal your answer sinks through the tier depth zones to "390 m" and a tilted tier stamp lands, with "About 1 in N players" underneath. Other players' rarest answers get small cards beside it. The cards collapse before the surge so the water rise stays in view.
- **Shells.** The currency is called Shells on screen. Every payout pops up next to the coin chip with its reason ("+20 ANSWER", "+25 SURVIVED"), and answers now pay a little by tier.
- **Enter twice to lock in.** The first Enter checks the answer and shows the bank spelling; the second Enter locks it. Typos stop costing rounds.
- **Hint and +10s boosts.** Bought with earned Shells or Robux, one of each per round and three per match.
- **Late join.** A player who arrives during round 1 (or early in round 2) gets a JUMP IN button instead of waiting a whole match.
- **Social rewards.** Joining the group and inviting friends unlock a title, a skin, a trail and some Shells.
- **Daily quests**, a **first-time tutorial**, a **standings peek** (collapsed by default), **answer tags over pillars**, a **floating prompt screen** above the ring, **trails** and more skins in the shop, **bots** to fill small matches, and a **Studio-only debug hook**.
- **Smaller ports:** the round ends 1.5 s after everyone has locked in, better tide feedback (what tier you need, close calls, who sank), a daily cap and a no-repeat memory on the lobby warm-up, and the old matcher's accent, "&" and plural handling.

Standing rules still apply: code only finds, clones and drives authored instances; tunables live in `GameConfig`; pure logic goes in `Shared` with Lune tests.

## How the new instances are authored (changed: model.json in git)

Studio is not open while this is built, so **new** instances are written as Rojo JSON model files instead of being authored by hand in the place. They are still authored instances: code only finds and drives them, nothing is generated at runtime.

- **New ScreenGuis:** `src/StarterGui/<Name>.model.json` (Rail is the first; Wallet, Toasts, Rewards, Quests, Tutorial and Standings follow).
- **New templates:** `src/ReplicatedStorage/Templates/<Name>.model.json`.
- **New remotes:** `src/ReplicatedStorage/Remotes/<Name>.model.json`, each just `{"className": "RemoteEvent"}`.
- **New sounds:** `src/ReplicatedStorage/Sounds.model.json`, using built-in `rbxasset://sounds/...` files. `Sfx.play` looks in `SoundService.Krillion` first, then there.

`Remotes/` and `Templates/` each have an `init.meta.json` with `ignoreUnknownInstances: true`, so the 15 existing remotes and the existing templates (`Title`, `Splashes`) authored in Studio are left alone. The upside: a new remote or GUI always ships in the same sync as the code that waits for it, so a checkout can never hang on a missing `WaitForChild`.

The **existing** ScreenGuis (Hud, Reveal, Lobby, LobbyQuiz, Results, Fx, Status, Shop, Revive) stay Studio-only. Code may restyle them through `Theme` tokens and add cloned templates into them at runtime, but nothing restructures them. Where a workstream needs new elements on screen, it puts them in its own new ScreenGui.

One existing template moves into git on purpose: `Templates/leaderstats.model.json` (Wins, **Shells**, Best). The player-list rename has to land at the same moment as the code that writes `Shells`, and this is the only way to guarantee that. `DataService` still falls back to a `Cash` value if it finds one.

## Shared contract (built first, in pass 0)

Everything later work plugs into exists now as working code or as a stub with its final API, so later work fills files in without changing callers. Stubs are safe no-ops: a match plays exactly as before.

**Currency.** `Shared/Currency` (`Name`, `Upper`, `format(1250) = "1,250 SHELLS"`, `short(1250) = "1.3K"`). The data key stays `cash` and code names stay (`GameConfig.Cash`, `Products.CashPacks`, `DoubleCash`), so there is no DataStore migration. Every player-facing string goes through `Currency`.

**Remotes added** (all RemoteEvents):

| Direction | Remote | Payload |
|---|---|---|
| client to server | `CheckAnswer` | `text` |
| client to server | `UseBoost` | `"Hint"` or `"ExtraTime"` |
| client to server | `JoinMatch` | none |
| client to server | `TutorialDone` | none |
| client to server | `RewardClaim` | `"Group"` |
| client to server | `LobbyQuizCheck` | `text` |
| server to client | `BoostResult` | `{kind, status, hint?, secondsLeft?, uses}` |
| server to client | `JoinResult` | `{status, message}` |
| server to client | `Notify` | `{text, kind}` (info, good, bad, krillion, hint) |
| server to client | `ShellsEarned` | `{amount, reason}` (negative amount for a spend) |

Payload types for these and the extended ones live in `Shared/Net.luau`. `RoundState` gains `yourSecondsLeft`, `overtime`, `lockedUserIds`, `heights` and `lateJoinOpen`. Reveal rows gain `depth`, `oneIn` and `schooled`. `MatchEnded` gains `rarest` and `earned`. `AnswerResult` gains `stage` ("check" or "submit") and `status`.

**Server signals.** `Server/MatchEvents` holds `MatchStarted`, `PromptOpened`, `PlayerJoinedMatch`, `AnswerGraded`, `RoundSurvived`, `PlayerSank`, `MatchFinished` and `LobbyAnswered`, built on a tiny pure `Shared/Signal`. RoundService fires them at their natural spots; payouts, quests, rewards and stats only listen. Handlers run on the match loop, so anything that touches a DataStore spawns its own thread.

**Services added.** `NotifyService` (toasts, done), plus stubs for `PayoutService`, `BoostService`, `QuestService`, `RewardService`, `AnswerStatsService`, `BotService` and `DebugService`, all started from `Main.server.luau` before `RoundService`. `StoreService` stays the only `ProcessReceipt` owner: other services sell products through `StoreService.registerProduct`. It also gains `grantShells` (no multiplier), `spendShells` and `earnedTotal`, and every payout or spend now tells the client's wallet.

**Profile fields added** (each with a merge rule, so two servers never overwrite each other): `hints` and `extraTimes` (boost inventory, summed, never below 0), `tutorialDone` (once true stays true), `claimed` (one-time grants, union), `referrals` (summed), `referredBy` (the first friend recorded keeps it), `quests` (today's progress; a newer day replaces, the same day keeps the most progress), `lobby` (warm-up Shells today, for the daily cap), `krillions` and `games` (lifetime counters), and `equipped.Trail`. Saves from before this pass load with defaults.

**Client.** New controllers are wired in `Main.client.luau`: Toasts, Wallet, Tide (the surge shake and close-call code moved out of Hud unchanged), Rail, Quests, Rewards, Tutorial, Standings, Sonar, and `DiveCard` for Reveal and LobbyQuiz. A new controller waits at most 10 s for its GUI and then does nothing, so one missing GUI never stops the rest.

**Config.** New `GameConfig` sections: `Boosts`, `LateJoin`, `Schooling`, `Quests`, `Rewards`, `Reveal`, `Depth`, `Sonar` and `Bots`, plus new keys in `Round`, `Answer`, `Lobby` and `Cash`. Tiers gain a depth band and a one-line blurb. `Theme` gains font, outline, panel, header-bar, depth, confetti and emoji-icon tokens; the existing tokens are unchanged. `Products.Boosts` holds the two boost products.

## Decisions for Zechariah

These change his game, so they are listed for a yes or no. Each is one config value or one file to roll back.

1. **The look.** The pass-2 spec says Roboto, no outlines, RefLobby style. Kevin wants the Sink or Niche look: FredokaOne display text with dark outlines, coloured header bars, emoji icons, lipped buttons. New GUIs use it; restyling the existing ones keeps every size and position, so it can be rolled back by re-publishing the old place version.
2. **Boosts are on** (`Boosts.Enabled = 1`). This is past "pay-to-win beyond the one revive". Mitigations: both are buyable with earned Shells, capped at one of each per round and three per match, and a hint shows a masked Rare or Deep Cut answer, never the best one.
3. **Bots are on** (`Bots.FillTo = 4`): small matches are topped up to 4 like Sink or Niche. A win only counts with 2 or more human players, so bots never farm Wins, and they never earn Shells or fire match events.
4. **Schooling is off** (`Schooling.Enabled = 0`): two players with the same answer each getting half the points is a real scoring change, so it waits for agreement.
5. **Economy.** Answers now pay 5 to 50 Shells by tier, new players get 100, and quests and rewards pay more. Shop prices may want a look alongside. VIP stays +10% (`Cash.VipBonus = 0.1`); Sink or Niche used +25%.
6. **Reveal pacing.** `Round.RevealSeconds` goes from 5 to 7 so the dive card lands before the pillar starts rising (`Reveal.RaiseDelaySeconds = 4`). Seeing the pillar rise first spoils the card.
7. **"About 1 in N players".** Real counts need enough answers per prompt (`Reveal.StatsMinTotal = 40`), which a new game will not have for weeks. `Reveal.EstimatedOneIn = 1` shows a clearly labelled estimate from the depth until then; 0 shows the tier blurb instead.

## Roblox rules that shaped this

- **No reward for likes or favorites.** There is no API to detect a like, and rewarding likes or favorites is against Roblox's rules. The game shows an unrewarded FAVORITE button and a nudge after a couple of matches. Rewards go to joining the group (checked on the server) and to friend invites (Roblox's own `ReferredByPlayerId` join data, credited only after the friend finishes a match).
- **Studio testing writes live data.** There is no separate test universe, so a Studio session with API access writes the real DataStores: profiles, answer stats, referral credits and debug grants are permanent.
- **Publishing.** The group place ships whatever scripts are synced into the session. Publish only from a session synced to merged `main`, and only with Kevin's or Zechariah's go-ahead.

## Studio follow-ups (cannot be done in files)

- Create the boost developer products (Hint 15 R$, +10s 10 R$) and the real pass and pack ids under group 36001322, then fill in `Products.luau`.
- Allow open joining on group 36001322, or the join prompt only sends requests.
- Preview the new sounds in `ReplicatedStorage.Sounds` (Thud, Ping, Heartbeat, Uhh, Whoosh, Coin, Deny) and swap any that sound wrong.
- After the first sync, check that the player list shows Wins, Shells and Best, and that the Rail sits under the SHOP button without overlapping it.
- World-space work that has to be done in the place: the stud restyle of the deck and reef, the answer tag on `PlatformTemplate.NameTag`, the Sonar screen model, the trail templates, the bot rig and the two lobby boards. Each is recorded as an Edit-mode script or a saved `.rbxmx` with before and after screenshots in its PR.

## Build order

Pass 0 (this contract, stubs and wiring) first, alone. Then the UI style, Shells wallet and toasts, the answer flow and boosts, the dive card, and match rules (late join, slate sunk pillars) in that order, with the rest (shop, rewards, quests, tutorial, tide, standings, sonar, warm-up, stats, matcher, bots, debug) after, each its own commit. RoundService has one owner at a time.

## Calls made by Claude (not yet confirmed)

- **Round end.** The prompt ends 1.5 s after every eligible player has locked in (`Round.AllLockedGrace`). A lock-in pushes a state update within 0.25 s so lock dots and the count react right away.
- **Overtime.** A +10s boost keeps the prompt open only for that player. Everyone else sees OVERTIME in the timer pill until they finish.
- **Warm-up cap.** 600 Shells per UTC day from the lobby quiz, after pass multipliers. Matches are never capped.
- **Sounds.** Ping and Coin use different built-in files so they never sound like the timer Tick.
- **Leaderstats in git.** Done so the Shells rename and the code that writes it can never be out of step.
- **Lifetime stats.** `krillions` and `games` are counted from now on (no backfill), for quests and boards later.

## Left to the builder

Exact art, colours, sound picks, card timings within `Reveal.CardBudgetSeconds`, quest list and rewards, cosmetic names and prices, and board placement, within the constraints above.
