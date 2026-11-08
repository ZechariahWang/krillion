# Creator Hub checklist: passes and products

**Status (2026-11-08):** all 25 below were created through Open Cloud under the krillion universe (10774453756), with
the icons in `assets/store-icons/`, and their ids are in the config. They were created **off sale**. To sell them, open
the Creator Hub, then krillion, then Monetization, and switch each pass and product on sale. Until then Roblox's
purchase window says the item is not for sale.

| Item | Id | Item | Id |
|---|---|---|---|
| VIP (pass) | 2074210408 | Hint | 3729794185 |
| 2x Shells (pass) | 2074618471 | +10 SEC | 3729794199 |
| Second Chance (pass) | 2075800451 | Hint x3 | 3729794218 |
| Boost Plus (pass) | 2074618472 | +10 SEC x3 | 3729794235 |
| 500 Shells | 3729793872 | Molten Pillar | 3729794371 |
| 1,500 Shells | 3729793985 | Gold Pillar | 3729794381 |
| 5,000 Shells | 3729793992 | Galaxy Pillar | 3729794393 |
| 12,000 Shells | 3729794005 | Starfall Splash | 3729794407 |
| Starter Pack | 3729794015 | Axolotl Pet | 3729794417 |
| Revive | 3729794156 | Blue Whale Pet | 3729794543 |
| Revive Now | 3729794171 | Halo Aura | 3729794556 |
| Gold Card Theme | 3729794569 | Rainbow Tag | 3729794585 |
| Confetti Bomb Toy | 3729794609 | | |

Everything paid with Shells works without any of this.

## How to add one

1. Go to [create.roblox.com](https://create.roblox.com). Open **TwoTen Studio** (group 36001322), then **krillion**, then **Monetization**.
2. Create the pass or product with the name, price and description below.
3. Copy its id (the number in its URL) into `src/ReplicatedStorage/Config/Products.luau`, or into `src/ReplicatedStorage/Config/Cosmetics.luau` for items. Each line below says which.
4. Keep the price on Roblox the same as the `robux` number in the config. The shop shows the config number, but Roblox charges what you set on the website.

Studio test purchases are free, so once an id is in, you can try every purchase in Play mode.

## Game passes (Monetization, then Passes)

| Name | Price | Description | Goes in |
|---|---|---|---|
| VIP | 199 | +10% Shells forever, the Aurora pillar, the Gold Wake trail, a VIP title and a gold VIP name tag. | `Products.Passes.Vip` |
| 2x Shells | 299 | Double every Shell you earn from answers, surviving and winning. | `Products.Passes.DoubleCash` |
| Second Chance | 249 | One free revive in every match (not in a 1v1). | `Products.Passes.SecondChance` |
| Boost Plus | 149 | Use up to 5 hints and 5 +10 SEC boosts per match instead of 3. | `Products.Passes.BoostPlus` |

## Developer products (Monetization, then Developer Products)

| Name | Price | Description | Goes in |
|---|---|---|---|
| 500 Shells | 25 | A small bag of Shells. | `Products.CashPacks[1].productId` |
| 1,500 Shells | 65 | A big bag of Shells. | `Products.CashPacks[2].productId` |
| 5,000 Shells | 199 | A chest of Shells. | `Products.CashPacks[3].productId` |
| 12,000 Shells | 449 | Best value: a treasure hoard of Shells. | `Products.CashPacks[4].productId` |
| Starter Pack | 49 | One time only: 1,000 Shells, a Sea Turtle pet and the Sunset pillar. | `Products.StarterPack.productId` |
| Revive | 25 | A revive to use the next time you sink. | `Products.Revive.productId` |
| Revive Now | 35 | Jump straight back in when you sink. | `Products.ReviveNow.productId` |
| Hint | 15 | One hint boost. | `Products.Boosts.Hint.productId` |
| +10 SEC | 10 | One +10 seconds boost. | `Products.Boosts.ExtraTime.productId` |
| Hint x3 | 35 | Three hint boosts. | `Products.BoostPacks[1].productId` |
| +10 SEC x3 | 25 | Three +10 seconds boosts. | `Products.BoostPacks[2].productId` |

## Robux items (each is a developer product)

| Name | Price | Goes in (`Cosmetics.luau`, the item's `robuxProductId`) |
|---|---|---|
| Molten pillar | 99 | `skin_lava` |
| Gold pillar | 99 | `skin_gold` |
| Galaxy pillar | 149 | `skin_galaxy` |
| Starfall splash | 79 | `splash_stars` |
| Axolotl pet | 149 | `pet_axolotl` |
| Blue Whale pet | 299 | `pet_whale` |
| Halo aura | 99 | `aura_halo` |
| Gold Card theme | 79 | `card_gold` |
| Rainbow Tag | 49 | `tag_rainbow` |
| Confetti Bomb toy | 49 | `toy_confetti` |

## Good to know

- **Chests** cost Shells, not Robux, so they need nothing here. The shop lists every chance next to each chest, as Roblox requires for paid random items. Players in countries where paid random items aren't allowed don't see chests.
- **Robux items bought twice:** a player who somehow buys a Robux item they already own gets its price back as Shells (20 per Robux).
- **Revive Now that arrives too late:** if the purchase lands after the revive window has closed, the player keeps it as a revive for their next match.
- **Paid perks:** Second Chance, Boost Plus, Revive Now and the pet Shells bonuses go past the old "no pay-to-win beyond the one revive" rule. Kevin chose this on 2026-11-07. Revives still never happen in a 1v1.
