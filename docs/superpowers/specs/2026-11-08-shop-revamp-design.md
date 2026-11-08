# Shop revamp

## Intent

The shop should make a player want to buy. Today it is a 3-across grid of small cards under five stale tabs, the
section list lives in `ShopUi.luau`, Robux items are one long STORE tab, and the Shells counter at the bottom of
the screen does not reliably follow a purchase.

## Goals

- Bigger cards, two across, with room for a preview, a name, a sub-line, a price and a full-width button.
- Sections authored in Studio, not in code; Shells sections first, Robux panels after.
- Search and filters (price kind, rarity, hide owned).
- Sales cues: BEST VALUE, MOST POPULAR, ONCE, TODAY badges.
- The window fits inside the screen on every device, centred; only the grid scrolls.
- The Shells counters (shop header and the bottom-right chip) follow every spend and purchase.

## Non-goals

- No new products, prices or passes. No server changes beyond what the Shells bug needs.
- No sales analytics behind MOST POPULAR: it is a config pick for now.
- No hero card spanning both columns (UIGridLayout cannot span); the Starter Pack is the first card of
  FEATURED and SPECIALS with the ONCE badge.

## Anti-goals

- Losing the second-click confirm on Shells spends, or the chest odds list (a Roblox rule).
- A window that overflows the screen or opens off-centre.

## Window

`LobbyUi.Shop` follows the Quests pattern: `Scrim`, then `Holder` (full screen, `Fit` UIScale) holding `Panel`,
960 x 640 px, anchored and positioned at (0.5, 0.5). `Ui.fitPanel` (margin 16, min scale 0.4) scales it to fit,
and a `Ui.phoneLayout` portrait variant (520 x 880) moves the section list to a wrapping row above the grid.
Grid cells stay two across in both.

Header (the authored gold `Accent` band): `Title` "SHOP", `CashText` Shells pill with a `GetShells` "+" key
docked on its right that jumps to the SHELLS section, `CloseButton`.

## Sections (authored under `Panel.Sections`)

A vertical list of lime-key TextButtons, read in LayoutOrder. Each carries attributes:

- `Kind`: `Featured` | `Slots` | `Chests` | `Shells` | `Passes` | `Specials`
- `Slots`: comma list of cosmetic slots, for `Slots` only (for example `Trail,Aura,Splash`)

Order: FEATURED, PETS, SKINS, EFFECTS, STYLE, TOYS, CHESTS, a "GET MORE" divider label, SHELLS (cash packs),
PASSES, SPECIALS (Starter Pack, Revive, Hint and +10 SEC singles and packs). The first section opens by default.
`ShopUi.openTab(name)` keeps working for the nudges (`Store` maps to SHELLS, `Chests` to CHESTS).

What each kind lists:

- Featured: Starter Pack (until claimed), today's four picks (`Shop.featured`) tagged TODAY, the BEST VALUE cash
  pack, the 2x Shells pass (until owned).
- Slots: `Cosmetics.inSlot` for each listed slot, in catalogue order.
- Chests: the chests, then every drop with its odds (unchanged).
- Shells, Passes, Specials: the matching part of today's STORE tab.

## Toolbar (authored under `Panel.Tools`)

`Search` (TextBox, placeholder "Search"), `PriceFilter` (cycles ALL, SHELLS, ROBUX, FREE), `RarityFilter`
(cycles ALL then the five rarities), `OwnedFilter` (toggle HIDE OWNED). Filters apply to whatever section is open;
an entry carries `currency`, `rarity` and `owned` so the pure `Shop.matches(entry, filter)` decides. Changing a
section keeps the filters. The grid shows an authored `Empty` label when nothing matches.

## Cards (`Grid.ItemTemplate`)

Cell (0.5, -12) x (0, 168) with 24 px padding both ways. Left: 96 px `Preview` (Disc, Emoji, TitlePill, Burst,
Stripe as today). Right: `ItemName` (display font, 22 px), `Sub` (body font, muted: "Rare pillar skin", "Epic
pet, +5% Shells", a pass's perk, a pack's Shells per Robux), `Price` with `CoinIcon` for Shells. Bottom: full-width
`Action`. `Badge` sits on the top-right corner, outside the card edge. Border colour is the rarity, as today.

Badge colours: gold for BEST VALUE and MOST POPULAR, purple for ONCE, red for TODAY, NEW, HOT and LIMITED, white
for OWNED, EQUIPPED, FREE and n OWNED.

Badges come from config: `Products.CashPacks[n].badge`, `Products.PassBadges`, `Products.StarterPack.badge`.
Picks: 12,000 pack BEST VALUE, 1,500 pack MOST POPULAR, 2x Shells MOST POPULAR, Starter Pack ONCE.

## Shells counter bug

Reproduce in Play mode first (buy a Shells item, watch the header pill and the bottom-right chip), then fix the
cause found. Both counters must read the profile's cash after every `ProfileChanged`.

## Code

- `ShopUi.luau` loses `TABS`, `TAB_SLOTS`, `OLD_TABS`, `STORE_TABS` and the old-tab fallback; sections come from
  the authored buttons.
- `Shared/Shop.luau` gains `Shop.matches` (pure; Lune test in `tests/Shop.test.luau`).
- `Products.luau` gains the badge fields; `tests/Monetization.test.luau` checks each badge names a real product.

## Studio

Authored through the Studio MCP in the place: the old five tab buttons and the hidden eight go; the new
`Holder/Panel/Sections/Tools/Grid` tree is built by cloning the existing authored pieces (lime keys, pills, the
card template) so the look stays the game's. Save the place after.

## Left to the builder

Exact pixel positions inside the card, filter key widths, the portrait row's wrap, search debounce.
