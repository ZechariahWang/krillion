# Prompt of the Day

## Why

A reason to come back every day: one prompt for everyone, answered once, with a result worth checking the
next day (what share of players said your answer) and a streak that pays a chest.

## What the player sees

- A TODAY key at the top of the lobby rail, with a `!` badge until today's answer is in, opens
  LobbyUi.DailyPrompt: the prompt, a countdown to the next one, an answer box and GO.
- Answering works like a match: an answer the bank has as typed locks in; one that needed a typo fixed
  shows DID YOU MEAN X? and GO again confirms it; a refused answer can be retried. No timer.
- After answering: the answer and its tier, and "SO FAR x% OF PLAYERS SAID THAT" (or not enough answers yet).
- The streak line, and yesterday's prompt with your answer's share and the top 5 answers worldwide.

## Rules (GameConfig.DailyPrompt)

- The day is the UTC day; the prompt is picked from the live bank by the day number, never yesterday's.
- Pay: twice a match answer's Shells for the tier (pass bonuses apply), plus the answer's level XP.
- Streak: answering on back-to-back days; every 7th day opens a free `chest_reef`; a missed day starts over.
- Shares need 40 answers worldwide.

## Approaches

- **Chosen: a rail window.** Anyone in the lobby can answer at any time.
- First match round: no new UI, but bots answer it and it is tied to matchmaking.
- A lobby pad: one more place to walk to; the warm-up quiz already uses that pattern.

## Build

- `Shared/DailyPrompt` (pure, tested): pick, nextStreak, chestDue, daysToChest, share, shareText, top.
- `Profile.dailyPrompt` `{ day, answer, tier, streak, prevDay, prevAnswer, prevTier }`; the later day wins
  a merge.
- `Server/DailyPromptService`: grades with `AnswerService.grade`, pays, records the answer in this server's
  buffer, which is added to the `DailyPrompt_v1` DataStore entry for the day (`_Studio` in Studio) every
  minute and on close; reads today again each minute and yesterday once. Remotes `DailyPromptState`,
  `DailyPromptAnswer`, `DailyPromptResult`, each rate-limited per player.
- `Client/DailyPrompt` draws the window.
