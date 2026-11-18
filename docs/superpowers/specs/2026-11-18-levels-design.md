# Levels

## Why

Players need a reason to play one more match and to come back: a number that only goes up, shown to
everyone. Part of a retention push (weekly boards, the answer
collection and the Prompt of the Day follow, each designed on its own).

## What the player sees

- Their level in their head label's name row: `[12] dogLover234`. Bots show a believable level too.
- A level bar under the Shells chip (bottom-right; on a phone under the chip in the top-right):
  `LV 12` and a fill for progress to the next level. It shows and hides with the chip. The chip and the
  boosts docked on it move up by the bar's height.
- On a level up: the bar fills, flashes and starts over, a toast reads `LEVEL 13!`, and 50 Shells pop in
  the wallet as usual.

## Rules (all numbers in `GameConfig.Levels`)

- XP per graded match answer = the tier's points (Plankton 10 .. Mythic 100). +20 per round survived,
  +100 for a match that counts as a Win. The warm-up quiz gives none.
- Level 1 to 2 costs 100 XP; each next level costs 25 more. No cap.
- 50 Shells per level gained, unmultiplied (`grantShells`).
- Existing players with no saved `xp` start at 150 XP per finished game plus 100 per Win.

## Approaches

Shop items locked by level (by rarity, Shells items only) were built and then dropped by the user
(2026-11-18): levels are status plus Shells only.

## Build

- `Shared/Levels` (pure, tested): level from XP with progress, the level an item needs, the name-row text.
- `Profile.xp`: a delta like `wins`; a stored profile without it is given the starting XP in `fromStored`.
- `Server/LevelService`: listens to `MatchEvents` (AnswerGraded, RoundSurvived, MatchFinished), adds XP,
  pays Shells and toasts on a level up, refreshes the name tag.
- `BotBrain.level(roll)` gives each bot a level, weighted towards low.
- The level bar is authored in Studio (`SharedUi.Wallet.Chip.LevelBar`); `Client/Wallet` fills it.
- XP goes to the client in the ProfileChanged payload.

## Left to the builder

The exact look of the bar within the stud style; the bot level spread.
