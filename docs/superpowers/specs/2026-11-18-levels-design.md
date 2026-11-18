# Levels

## Why

Players need a reason to play one more match and to come back: a number that only goes up, shown to
everyone, that opens better shop items as it grows. Part of a retention push (weekly boards, the answer
collection and the Prompt of the Day follow, each designed on its own).

## What the player sees

- Their level in their head label's name row: `[12] dogLover234`. Bots show a believable level too.
- A level bar under the Shells chip (bottom-right; on a phone under the chip in the top-right):
  `LV 12` and a fill for progress to the next level. It shows and hides with the chip. The chip and the
  boosts docked on it move up by the bar's height.
- On a level up: the bar fills, flashes and starts over, a toast reads `LEVEL 13!`, and 50 Shells pop in
  the wallet as usual.
- Shop: a Shells item above the player's level shows its buy key greyed with `LV 10` (and a lock icon if
  one is authored). A tap explains the level needed. The server refuses the buy.

## Rules (all numbers in `GameConfig.Levels`)

- XP per graded match answer = the tier's points (Plankton 10 .. Mythic 100). +20 per round survived,
  +100 for a match that counts as a Win. The warm-up quiz gives none.
- Level 1 to 2 costs 100 XP; each next level costs 25 more. No cap.
- 50 Shells per level gained, unmultiplied (`grantShells`).
- Shells items need a level by rarity: Common 1, Rare 5, Epic 10, Legendary 20, Mythic 30. Robux, pass,
  reward and chest-only items never lock. Owned items stay owned. Chests can still drop locked items.
- Existing players with no saved `xp` start at 150 XP per finished game plus 100 per Win.

## Approaches

- **Chosen: a rarity rule.** One config table covers every item, including future ones.
- Per-item levels: more control, but 86 items to set by hand and every new one after. Rejected by the user.
- Locking Robux items too: stronger pull but blocks buyers. Rejected by the user.

## Build

- `Shared/Levels` (pure, tested): level from XP with progress, the level an item needs, the name-row text.
- `Profile.xp`: a delta like `wins`; a stored profile without it is given the starting XP in `fromStored`.
- `Server/LevelService`: listens to `MatchEvents` (AnswerGraded, RoundSurvived, MatchFinished), adds XP,
  pays Shells and toasts on a level up, refreshes the name tag.
- `Shop.canBuyWithCash` checks the level, so the server and the shop UI agree.
- `BotBrain.level(roll)` gives each bot a level, weighted towards low.
- The level bar and the lock badge are authored in Studio; `Client/Wallet` and `ShopUi` fill them.
- XP goes to the client in the ProfileChanged payload.

## Left to the builder

The exact look of the bar and lock badge within the stud style; the bot level spread.
