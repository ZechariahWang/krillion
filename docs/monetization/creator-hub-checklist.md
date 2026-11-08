# Creator Hub checklist: passes and products

Until these exist on Roblox, every Robux button in the game says COMING SOON. Everything paid with Shells already works.

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
