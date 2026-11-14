# Crab Craze: the new main gamemode

> **Reverted 2026-11-13.** Crab Craze was built, tried for three days and taken out again. The rising-water
> mode is the live game. Crab Craze is kept at git tag `mode/crab-craze` (its Studio pieces are in
> `ServerStorage.CrabCrazeInstances`). This document is history: nothing in it describes the current game,
> and the `ModeArchive` it mentions has been deleted.

Date: 2026-11-10. Branch: `feat/puffer-party`. Status: plan with decisions made (section 7), nothing built yet.

Goal: replace the rising-water mode with a hot-potato mode modelled on Krillion's Puffer Party, with a crab in
place of the puffer. The rising-water mode is archived so it can come back later.

## 1. How the real Puffer Party works

Sources: the how-to-play panel and room defaults on krillion.io/party, and the FAQ on krillion.io/faq, read on
2026-11-10.

Verified:

- One category question. The player holding the puffer must type a valid answer to pass it on.
- "No reusing answers for the current question."
- The fuse is hidden and shared by the room. It is random, 10 to 30 seconds. It keeps counting down as the
  puffer is passed. If less than 8 seconds are left when it is passed, it goes back up to 8.
- When the fuse runs out the puffer explodes on whoever holds it. Then a new random fuse starts.
- Players have hearts: 2 to start, 5 at most.
- "Rarer answers get you closer to an extra heart." The meter target is 600 points.
- "Last one floating wins."
- Rooms: 1v1, 3 players, 4 to 6, 8 to 10. The default room size is 6. A hosted room can list up to 16.
- The creator says it is modelled on hot potato and on JKLM's BombParty.

Not stated anywhere I could read, so these are my assumptions:

- An explosion costs the holder one heart, and a player with no hearts is out.
- The question changes after an explosion (the "current question" wording implies it lasts several turns).
- The meter uses the normal tier points (10 to 100 per answer).
- Who holds the puffer after an explosion, and the passing order.

## 2. Crab Craze rules

The mode keeps the game's name honest: rare answers still keep you in, and you still sink when you lose.

- **Ring.** Players stand on their pillars in the arena ring, as today. Every pillar stays at the same height
  for the whole match and the water stays at one level.
- **The crab.** One crab sits on the holder's pillar. A valid answer sends it scuttling to the next player
  still in, clockwise.
- **Your turn.** Only the holder can answer. Everyone sees the question and the answers already used, so they
  can think ahead. A wrong or used answer is refused and the holder can try again while the fuse burns.
  Enter submits at once; a near-miss spelling is corrected and accepted (no second "lock in" press).
- **Fuse.** Random 10 to 30 seconds, shared, topped up to 8 seconds on a pass. Same numbers as the original.
  There is no countdown on screen, but the crab gets angrier as the fuse runs down: calm, then restless,
  then furious in the last seconds.
- **Pinch.** When the fuse ends the crab pinches the holder. They lose a heart, a new fuse is rolled and a new
  question starts with an empty used list. The pinched player holds the crab again; if that pinch put them
  out, it goes to the next player.
- **Hearts.** Start with 2, at most 5, shown as pips on the pillar's name tag and on the Hud. At zero hearts
  the player is out and their pillar sinks (the existing sink and Splash cosmetic). That is the only time a
  pillar moves.
- **Rarity meter.** Each accepted answer adds its tier points (Plankton 10 up to Mythic 100) to the player's
  meter. At 600 the meter empties and the player gains a heart, unless they already have 5.
- **Win.** Last player standing. Podium order is the order players went out.

### Numbers (all in a new `GameConfig.Crab` section)

| Knob | Value | From |
|------|-------|------|
| `StartHearts` | 2 | original |
| `MaxHearts` | 5 | original |
| `MeterTarget` | 600 | original |
| `FuseMinSeconds` / `FuseMaxSeconds` | 10 / 30 | original |
| `MinTurnSeconds` | 8 | original |
| `PinchSeconds` | 3 | new: the beat that shows the pinch before the next fuse |
| `RestlessSeconds` | 6 | new: the crab turns restless with this much fuse left |
| `FuriousSeconds` | 3 | new: the crab turns furious with this much fuse left |

## 3. What changes around the mode

- **Phases.** The names the shared screens already switch on are kept: Waiting, Intermission, Starting,
  Prompt (the crab is live), Reveal (the pinch beat), Results. Surge goes. Keeping the names means Rail,
  Wallet, Rewards, Tutorial and Transition need no change.
- **Bots.** Kept, so one player alone still gets a match. `BotBrain.chooseAnswer` already takes a "taken"
  set, which fits the no-reuse rule. A bot answers after a random delay and sometimes freezes up.
- **Late join.** Off in the first version. Matches are short, and joining a hearts game late is easy to abuse.
- **Revive.** Kept: at zero hearts the existing revive prompt can put the player back with 1 heart, once per
  match. The saved `revives` field and the products stay as they are.
- **Boosts.** Hint works on your turn (it already skips used answers). +10 SEC adds time to the hidden fuse
  while you hold the crab. The per-round limit becomes per question.
- **Shells.** Each accepted answer pays by tier through the existing `AnswerGraded` event. The per-round
  survival pay is paid to everyone still in after each pinch. The win bonus is unchanged.
- **Quests.** `RoundSurvived` fires per pinch survived, so "SURVIVE 5 SURGES" only needs new wording.
- **Tutorial, How to Play board, status text, game description.** Rewritten for the new rules.

## 4. Code plan

New, pure and tested first (Lune):

- `Shared/CrabMatch.luau`: the whole match state and its rules. Players in ring order, hearts, meters, the
  holder, the used answers, the fuse. Functions: start, pass (answer accepted), pinch (fuse ended), next
  holder, top up the fuse, winner, ranking. Random rolls are passed in, as `SpecialRound` does, so every rule
  is testable.

Rewritten:

- `Server/RoundService.luau`: the shell (wait for players, intermission, intro fade, results, match events,
  matchmaking attributes) is carried over; the pillar-and-water engine is replaced by the crab loop.
- `Server/AnswerService.luau`: gains a turn: only the holder may submit, a refused answer can be retried,
  used answers are refused. `grade`, `isValidText` and `randomPrompt` are untouched (the lobby quiz uses them).
- `Server/MapService.luau`: pillars are placed once and only sink; the rise and lift code leaves.
- `Server/BotService.luau`, `Server/BoostService.luau`, `Server/DebugService.luau`: follow the new loop.
- Client: `Hud` (hearts, meter, used answers, "YOUR TURN"), `Status`, `PillarTags`, `Lobby` (spectate),
  `Results`, `Tutorial`, plus a new `Client/Crab.luau` that moves the crab and plays the pinch.

Remotes: `RoundState` carries the holder, everyone's hearts, your meter, the used answers and the crab's mood
in place of the water fields. The fuse's exact time is never sent to clients. Two new events, `CrabPassed` and `CrabPinched`, drive the animations.

Authored in Studio (not by code): the crab model (`Templates.CrazeCrab`) with its calm, restless and furious
looks, heart pips on the pillar name tag,
the Hud hearts row, meter and used-answer strip, and the two remotes.

Leaves the live game (archived, see below): `WaterService`, `Shared/MatchState`, `WaterCurve`, `Tide`,
`SpecialRound`, `LateJoin`, `Schooling`, `Client/Tide`, `Client/WaterFx`, `Client/Reveal`, and the
`GameConfig` sections `Water`, `Special`, `LateJoin`, `Schooling`.

Stays as is: the prompt bank, `AnswerMatcher`, `AnswerGate`, `Tiers`, `ArenaLayout`, `PlayerService`
teleports, profiles, shop, quests, rewards, the lobby quiz, the dive card (lobby quiz only).

## 5. Archiving the rising-water mode

Three layers, so nothing is lost and the restore path is real:

1. **Git tag `mode/rising-water`** on the last commit that runs the old mode. This is the true restore point:
   it has the code, the tests and the config in a state that works together.
2. **`ServerStorage.ModeArchive.RisingWater`** (from `src/ServerStorage/ModeArchive/RisingWater/`, synced by
   the existing ServerStorage path, no new project node):
   - `Server/`, `Shared/`, `Client/`, `Config/`: a copy of every file the old mode owns or that the new mode
     rewrites, as it stands at the tag.
   - `Manifest.luau`: each archived module's original path, and the steps to bring the mode back.
   - `Instances/` (Studio only): copies of the mode's authored pieces: `Hud.WaterMeter`, `Status.Tide`, the
     Reveal screen, `Vignette`, and `Arena.NextLevel`.
3. **`tests/archive/rising-water/`**: the old mode's test files, out of `tests/run.luau`.

What the archive is not: the modules in ServerStorage do not run where they sit. Their `require` paths point
at their old homes, so bringing the mode back means moving them back by the manifest (or checking out the tag).

The case against, for the record: an archive folder slowly goes stale, because nothing compiles it against
the shared code as that changes. The alternative is to keep both modes live behind a `GameConfig.Mode`
switch, which keeps the old mode tested but means every shared change must work for two modes. I recommend
the archive, as asked: one live mode is simpler, and the tag makes the old one recoverable exactly.

## 6. Build order

One commit per step; tests, syntax check and `rojo build` green at each.

1. Tag, then copy the archive (nothing removed; the old mode still runs).
2. `CrabMatch` with its tests, and `GameConfig.Crab`.
3. Server: the new `RoundService` loop, the `AnswerService` turn, pillar notches, bots. Old mode modules
   leave the live tree; their tests move to the archive.
4. Studio: the crab, the heart pips, the Hud pieces, the remotes.
5. Client: `Hud`, `Status`, `Crab`, `PillarTags`, spectate, `Results`.
6. Boosts, revive, shells and quest wording, the debug hook.
7. Tutorial, boards, `CLAUDE.md`, the game description.
8. Play test: solo with bots, a pass chain, the crab's moods, a pinch, an extra heart, a sink, a revive, a
   win, phone layout.

## 7. Decisions (made 2026-11-10)

1. **Server size: 8.** `GameConfig.Server.MaxPlayers` becomes 8, and Server Size is set to 8 in the Creator
   Hub. One ring, one crab.
2. **After a pinch the pinched player holds the crab again.**
3. **The crab gets visibly angrier** as the fuse runs down. No countdown is shown.
4. **All pillars stay the same height.** Hearts are pips, not height. With no heights, the Best stat is left
   frozen: no save migration.
5. **The mode is called Crab Craze** on screen. The game stays Rare or Sink.

One reading of mine to confirm: a pillar still sinks when its player runs out of hearts.
