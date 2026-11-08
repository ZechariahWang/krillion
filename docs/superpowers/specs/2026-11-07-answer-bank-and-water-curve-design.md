# Answer bank and water curve

## Why

Players get eliminated by the game, not by each other. Two causes:

1. The answer bank is thin: 40 prompts, about 20-30 answers each. Real, valid answers get rejected, a rejected
   answer lifts 0, and two or three misses sink you by round 3 or 4.
2. The water outpaces the lift even when an answer is accepted. A Plankton answer lifts 1 stud
   (10 points x `LiftPerPoint` 0.1); round 1 already surges 2 studs and every round adds 0.6.

Goal: a valid answer is almost never rejected, and elimination comes from giving common answers while others dig
deeper. Rounds 1-4 feel safe for everyone, the middle separates players by knowledge, the end gets tense fast.

Non-goals: dynamic rarity from player data (rankings stay curated), new prompts, changes to tiers or their points,
changes to special rounds (Tidal Wave, Double Lift) beyond keeping them working on the new curve.

## Part 1: larger, fully ranked answer bank

- Every existing prompt gets a long list of valid answers: hundreds where the category supports it (bird, fruit,
  country), as many as really exist where it is small (moons of the solar system).
- Every answer is ranked into one of the six existing tiers. The user asked for the long lists to be ranked too,
  not dumped into Plankton.
- Ranking rule: how likely a typical Roblox player (young, English-speaking) is to think of it. Plankton holds only
  the handful of first-thought answers; most of the long tail lands in Schooler, Rare and Deep Cut;
  One in a Krillion stays scarce and must still be a real, checkable answer.
- Too Clever keeps the meaning the bank already gives it (my call): an answer that feels like a smart pick but that
  lots of players reach for (flamingo, dragon fruit, Titan). It sits between Plankton and Schooler.
- Existing tier assignments may be moved when the bigger picture makes them clearly wrong.
- Aliases cover plurals, "the X" forms, common alternate spellings and well-known short names, normalized the way
  the bank already requires (lowercase, no punctuation, single spaces).
- No answer that would be inappropriate for Roblox, even if technically valid.
- The user skims the drafted lists and corrects them. Drafting is the builder's job; correctness review is theirs.
  Drafts land in batches of about 10 prompts, one commit each, so each batch can be skimmed on its own (my call).
- Layout: `src/ServerStorage/PromptBank/init.luau` keeps the type, `List`, `ById` and `random`; each prompt moves to
  its own module beside it (`PromptBank/bird.luau`, and so on), returning one `Prompt`. `init.luau` requires them
  through an explicit list so load order and membership are obvious. Consumers (`AnswerService`, bots) keep the same
  `PromptBank` API.
- A Lune test checks bank integrity across all prompts: no answer in two tiers of the same prompt, every alias
  points at a real answer, every answer and alias is already normalized, no alias equals an answer, and every prompt has
  at least one answer in Plankton, Schooler and Rare. Too Clever, Deep Cut and One in a Krillion are optional, so
  small categories are never padded with made-up answers (my call; bots already fall back to the nearest tier).
  The bank lives in ServerStorage, so the test requires the modules by path the same way other tests do.

## Part 2: water curve

Shape (user approved): the water barely moves at first, about half a stud in round 1, and each round's rise grows
faster than the last.

- `WaterCurve.surge(round)` becomes `SurgeBase + SurgeGrowth * (round - 1) ^ SurgePower`. `SurgeStep` is replaced by
  `SurgeGrowth` and `SurgePower` in `GameConfig.Water`. `StartHeight` and `LiftPerPoint` may be retuned too.
- Survival targets, with a player giving the same tier every round from `StartHeight`:

  | Player | Eliminated in round |
  |--------|---------------------|
  | Plankton every round | 4-6 |
  | Plankton, but misses round 2 | not before round 4 |
  | Schooler every round | 8-10 |
  | Rare every round | 12-15 |
  | One in a Krillion every round | by round 17 |

- A deterministic simulation test in `tests/WaterCurve.test.luau` asserts the table, so retuning is a config change
  plus a test run. It follows the real round order in `RoundService` (answer lift, then surge, then the elimination
  check) and covers normal rounds only; Tidal Wave and Double Lift are deliberate swings and stay out of the targets
  (my call). Existing tests (surge grows every round, eventually exceeds max lift) stay; any test or fixture that
  references `SurgeStep` is updated.
- A quick offline sweep confirmed these targets are reachable with this shape (for example base 0.2, growth 0.8,
  power 1.2); the builder picks final numbers, preferring a round 1 surge near 0.5.
- If playtests say good players coast and the end is too abrupt, the fix is a lower `SurgePower`. Left to the user.

## Left to the builder

- Final curve numbers within the targets.
- Exact answer counts per prompt and tier boundaries for borderline answers.
- Whether the integrity test also guards list sizes.
