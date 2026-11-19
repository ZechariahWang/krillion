# Answer collection

## Why

Retention: an album to fill gives every match a long-term goal beyond the round, built on the game's core
(rare answers).

## What the player sees

- An ALBUM key on the lobby rail opens LobbyUi.Collection: one card per live prompt (the prompt, your best
  match answer and its tier in the tier colour), a gold check on mastered cards, dimmed `???` cards for
  prompts not found yet. Found cards sort first, rarest first. A search box filters by prompt text.
- The header line: `37/211 MASTERED | 112 FOUND`, and the next milestone.
- When a match answer improves a card: a toast `COLLECTION: NAME A FAMOUS AUTHOR | DEEP CUT`.
- Milestones pay themselves with a toast.

## Rules (GameConfig.Collection)

- A card keeps the prompt's best match answer; only a strictly rarer tier replaces it. Warm-ups never count.
- A prompt is mastered when its card reaches the rarest tier the prompt's bank has.
- The album is every live prompt (retired ones and empty ones left out).
- Milestones by mastered count: 10, 25, 50 (+ COLLECTOR title), 100, 200 pay Shells (100, 250, 500, 1000,
  2000); mastering every prompt unlocks the COMPLETIONIST title. A milestone above the album size is skipped.

## Approaches

- **Chosen: best per prompt.** A finite album with a clear goal.
- Every rare answer: endless counter, no goal. Mythics only: prompts without Mythics never count.

## Build

- `Shared/Collection` (pure, tested): better, topTier, isMastered, counts, reached, nextMilestone.
- `Profile.collection` `{ [promptId]: { tier, answer } }`; merge keeps the rarer tier from either side.
- `Server/AnswerCollectionService`: records cards from AnswerGraded (with the payout delay), toasts, pays
  milestones (claim ids `Collect10`.. `CollectAll`, Shells and reward titles), sends the album over
  `CollectionCatalog`. Named apart from Roblox's own CollectionService.
- `Client/Collection` draws the window; ShopUi's GET on a collection title opens it.
