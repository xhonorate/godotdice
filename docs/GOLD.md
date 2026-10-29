# Gold at home

This is the plan for giving gold uses outside a run and new ways to earn it. When a part ships, its marker turns green, its row in §6 gets a "Built" date, and the README is updated. §11 lists what the build settled that this plan had left open.

**Key:** 🟢 built · 🟡 partly built · 🔵 planned, in the build order · ⚪ idea for later, not scheduled · ⛔ considered and left out

## At a glance

|     | Feature                                                                                  | Section    | Phase                                                       |
| --- | ---------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------- |
| 🟢  | Geodes: today's and the week's, cracked in three blows                                   | §3.3       | 4, built October 10, 2026; reworked October 12, 2026        |
| 🟢  | Contracts (trade-ups), once a day                                                        | §3.4       | 5, built October 10, 2026; once a day from October 12, 2026 |
| 🟢  | The Market: the case of cut stones, the bench, restocking                                | §3.6       | built October 12, 2026                                      |
| 🟢  | The daily dig, reworked after the review                                                 | §4.2       | 6, built October 10, 2026, reworked the same day            |
| 🟢  | Mine fares                                                                               | §3.1       | 3, built October 7, 2026                                    |
| 🟢  | Salvage insurance                                                                        | §3.2       | 3, built October 7, 2026                                    |
| 🟢  | Socket unlocks, and temporary stones below the Quarry                                    | §3.5, §3.1 | 3, built October 7, 2026                                    |
| 🟢  | Commissions, and the "New skill" choice                                                  | §4.1       | 2, built October 7, 2026                                    |
| ⛔  | The assay at the lift                                                                    | §4.3       | 1, built October 7, 2026; removed October 14, 2026          |
| 🟢  | First-conquest purse                                                                     | §4.4       | 1, built October 7, 2026                                    |
| 🟢  | Groundwork: economy code, save upgrade, daily turnover, Gold page in the balance browser | §5, §6     | 0, built October 7, 2026                                    |
| 🟢  | The no-profit test: all four checks                                                      | §7         | grew with 4 and 5                                           |
| ⚪  | Birthstone upgrades                                                                      | §8.1       | not scheduled                                               |
| 🟢  | The Wheel and the Oven, once a day each                                                  | §3.6, §8.2 | built October 12, 2026                                      |
| ⛔  | Everything in §9                                                                         | §9         | —                                                           |

## 1. Where gold stood before this plan

|                   |                                                                                                                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Earned by**     | Selling stones on the Appraise tab (full worth if appraised, the size-class price if not), and the stone sold when a new one of its skill replaces it in the vault (`DeepProfile.keep`). |
| **Spent on**      | The workshop appraisal fee (`DeepProfile.appraisal_fee`: twice the rough price, at least 12).                                                                                            |
| **Not converted** | Pyrite. Whatever a player carries when the run ends is lost.                                                                                                                             |

Once most skills are in the vault, the only spend is the appraisal fee, so gold piles up. Deeper mines pile it up faster, because stones there are worth several times more. (This is the problem the plan answers; the 🟢 sections below have since changed it.)

## 2. Rules every part follows

1. **Gold never makes a kept stone better.** The design rule "Nothing anywhere makes a kept stone truer for the asking" stands. Gold buys new chances at stones (Geodes), new stones made from old ones (Contracts), access (fares) and protection (insurance), never a recut or re-fire of a vault stone. The one candidate exception is a home reroll of Cut or Clarity (§8.2), which would be a gamble (drawn again, better or worse) and never an upgrade.
2. **No profitable loops.** Nothing bought with gold may be resold, alone or after a chain of steps, for more than it cost on average. One headless test checks every chain (§7).
3. **Prices scale by mine.** Every price is a field on the mine in `content/deep_cut.json`, never a single constant.
4. **Gold belongs to each player.** Pyrite is pooled by the party, but gold is per profile. In co-op, every player pays their own costs from their own purse.
5. **Every gamble shows its odds** before the player pays.
6. **Gold is never sold for money,** and stones are never traded between players. That keeps Geodes outside loot-box rules.
7. **One page per screen** (CLAUDE.md). Every new view below fits without scrolling. Long lists page.
8. **"Daily" means the UTC calendar day.** Everything that refreshes daily turns over at 00:00 UTC.

## 3. Spending gold

### 🟢 3.1 Mine fares

Starting a run in any mine below the Quarry costs a **fare** in gold. The Quarry stays free.

- **What a deeper start gives.** Today a run that starts below the Quarry fills every socket from the vault (`loadout_sockets` 6) as well as handing each player a purse (`start_pyrite`, 120 in the Seeps up to 550 in the Rift). **That changes (decided October 6, 2026):** every mine fills only the sockets the lapidary has unlocked (§3.5), the same as the Quarry. The empty sockets get **temporary stones** instead (below). The purse stays. The fare pays for the purse, the temporary stones and the floors skipped.
- **No mid-mine starts.** A run always starts at the top of a mine.
- **Pushing on is free.** A party that beats a mine's final boss and walks into the mine below pays nothing.
- **Co-op:** every player pays their own fare when the party departs. The Descend button stays disabled until everyone can pay, and the panel names who is short. Nobody is charged if the departure is cancelled.
- **Starting fares:** half the mine's `start_pyrite`, which values the purse at 2 pyrite to 1 gold.

| Mine        | Seeps | Glass Veins | Warrens | Furnace | Geode | Rift |
| ----------- | ----- | ----------- | ------- | ------- | ----- | ---- |
| `fare_gold` | 60    | 100         | 140     | 180     | 225   | 275  |

**Temporary stones for the empty sockets.** At the shaft head of a run that starts below the Quarry, every socket with no stone of its own (one the lapidary has not unlocked, or one unlocked and left empty, so that buying a socket never makes a deep run weaker) is offered a **pick of three temporary stones**:

- **Color:** each pick matches its socket's color. An Any socket offers three different colors.
- **One screen:** all the picks sit on one screen, a row of three cards per empty socket (two or three rows), before the Grubstake. The existing "Pick of Three" stake already draws this kind of row.
- **Quality:** appraised, never Void. Rolled at the bottom of the mine's luck (`temporary_depth` 20) with `temporary_luck` (4) on top, and drawn again, a little kinder each time, until it is at least `temporary_min_tier` (Precious) or a dozen draws have been made. Buffed October 8, 2026: at depth 4 they came out Rough four times in five, which made bringing the vault's own stones the only sensible choice.
- **Temporary means fragile:** the stone carries the same `fragile` flag as the "A Fragile Find" stake, shown with the Fragile mark. It cannot be sold, kept, turned in or thrown down a well, and it shatters when the run ends, however it ends.
- **Replaceable:** a stone found during the run can take its socket. The temporary stone moves to the bag and still shatters at the end.
- **Dice offered for the deep (October 9, 2026, replacing the dice worked for the deep of October 8):** after the temporary stones, each die in a player's bowl is offered three dice to swap it for, one die at a time, or kept as it is. The left one is its size or smaller, the middle one its size and the right one its size or bigger; every one differs from it, the middle one always in its pattern, an etching or its material. A mine's `start_dice_offer` tunes it: `steps` are the chances, in percent, of a side die being at least one, two and three sizes off (Seeps 30/1/0 up to the Geode 99/30/1), and `variation` the chance of each extra pattern, etching or material (Seeps 15% up to the Geode 50%). Like all work on a die down the mine, a swap stays there.
- **Not when pushing on:** a party walking into the next mine already has its rail. The Quarry gets none, and the daily dig fills the rail by its own rule instead.
- **Why unlock sockets, then:** temporary stones are good (Precious, at the mine's usual carat) but random: three to choose from, of skills the rock picked, and gone when the run ends. An unlocked socket carries the stone the player chose from the vault, built around. That difference is what socket unlocks sell.

**Closing two existing loopholes (needed before this ships, and worth fixing now):**

- **The well:** the wishing well accepts fragile stones (`DeepDescent.can_wish` checks only Birthstones and Knots), so a temporary stone can be turned into a permanent reward. It should refuse them.
- **The Crucible:** fusing a fragile stone with a permanent one keeps whichever survives the 50% draw. If the permanent one survives, it absorbs the fragile one's carats and comes home. A fused stone should be fragile if either input was.

Both loopholes already exist with "A Fragile Find", the Grubstake's depth-20 fragile stone (from the bottom of a mine that ends sooner, since October 9, 2026).

### 🟢 3.2 Salvage insurance

An optional purchase on the Map's trip panel: a **checkbox the profile remembers**, so a player sets it once and it applies to every run until turned off. The Descend button shows the total (fare plus insurance), and the gold is taken at departure.

- **What it does:** if the run falls or is abandoned, every salvage die rolls twice and keeps the better result.
- **Price:** `insurance_gold` per mine, starting at 15 in the Quarry and a quarter of the fare below it (15, 25, 35, 45, 55, 70). It pays for itself only on a bad run.

### 🟢 3.3 Geodes (phase 4, reworked October 12, 2026)

Geodes are sold on the Market (§3.6), down its left side. Until October 12 they were a Shop tab of their own with three a day.

**The shelf.** Two Geodes, each bought at most once, all from mines the player has unlocked:

| Geode                                            | What it can hold                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Today's Geode** (one a day, UTC)               | Either a **mine's Geode** (the skill pool of one open mine, weighted the way the mine weights it) or a **color's Geode** (one color, from the deepest open mine's rock), whichever the day draws. A restock (§3.6) draws it again.                                                                                                                                                                                                                                                                                                              |
| **The week's Geode** (one a week, kept all week) | A hand-written set of 7–10 skills (content: `geodes.featured`, eight sets) from the deepest open mine's rock. The sets take turns a week each, the same for everyone. When fewer than three of the set are in reach of the mines open, the deepest mine's own Geode takes its place. It is better and dearer than today's: its carat floor is one higher (`geode_week_carat`), it is never cut worse than Keen (`geode_week_min_cut` 3), and its price is a fifth higher (`geode_week_price_mult` 1.2). It stays on the shelf through restocks. |

Each card shows the Geode's art (a mine's Geode in its mine's rock, a color's with crystals of its color breaking through, the week's strapped in brass), its carat range, whether it can hold a favorite (§3.6), and the Crack it button. **Right-clicking** the card opens its close look, the way a stone's or a die's opens (October 14, 2026; it replaced an Odds button): the Geode in 3D, turned by dragging, beside its odds in full. The first page has the share of each rarity and of each grade tier (sampled from 400 rolls, not written by hand), with the count of skills in each rarity, its carats, what its stone is worth on average, the opal chance, and how many of its skills the player has never found or has starred; then a page to a rarity lists every skill it can hold with its own share, likeliest first. "Crack it" pays and opens it in one click.

**What is inside.** A Geode stone is better than a mine stone:

- **Carat:** from the mine's usual top (its band's `soft`) up to **its cap + 2** (`geode_carat_over_cap`), each carat past the top half as likely as the one before (`geode_carat_keep` 50). A Quarry Geode can hold an 8 or 9, where the Quarry itself never gives more than 7.
- **Cut and Clarity:** rolled at the bottom of the mine's luck (depth 20) with `geode_luck` (4) on top.
- **No Void.** A fragile stone would shatter at home. A roll that comes up Void is rolled again, and anything fragile left inside is taken out.
- **Opals:** a 1% chance (`geode_opal_pct`) of a Mythic Opal in any Geode.
- **Rolled in advance.** The stone is rolled when the day's shelf is rolled and saved with it, so reloading cannot change it. Cracking it only shows what was already there, and the stone is on the tray, read, before the drum turns: quitting half-way loses nothing.

**The crack (October 12, 2026).** The drum and its lever are gone. The Geode is opened in three blows, the way this section first planned:

1. The Geode sits alone in the middle of a darkened screen under its name: "Strike it. Three blows open it." It rocks a little while it waits.
2. The first blow (a click on it, or Space) puts a hairline in it with a puff of dust.
3. The second opens the cracks, and light gets out of them. The light tells the grade: brighter and more colored for a finer stone.
4. The third splits it. The halves fall away, the hollow is lit in the grade's color, rays and a burst go up, and the stone rises out of it turning. Its name and grade are called in the grade's color (a jackpot for an Exquisite, a Peerless or an opal), and it slides aside for its card to be read out line by line.
5. The choices are the tray's, made on the spot: Into the vault (with the "New skill" fanfare for a first stone), Keep it, replace yours, Sell it, Turn it in for a commission, or Decide later, which leaves it in the vault's Unappraised view.

Escape jumps to the end, and at the end takes the gentlest way out.

**The Geode in 3D (October 13, 2026).** The drawn Geode is replaced by a real one, cut by `view/gems/geode_mesh.gd` and shown by `view/gems/geode_view.gd` in its own SubViewport, the way the stones are. Its knobbly rind is its mine's rock: pale limestone, wet moss, crystal spurs, fungus caps, basalt with lit seams, banded agate, or void black with violet seams and pinpoints of light. A color's Geode has points of its color pushing out of its seam, and the week's is bound in brass. It is made as two halves that meet along a jagged seam. The blows crack it along that seam with light in the cracks, and the third swings the halves open like a book so both faces turn to the viewer: the rind in section, a pale line and a band of agate, and a hollow cut in broad crystal facets with a few large crystal points in it, lit by the grade's light. The hollow is kept to large forms on purpose: an earlier version lined it with hundreds of small points, and a field of small bumps and the dark gaps between them is unpleasant to look at (trypophobia). The shelf shows a bought Geode as its two open halves. A Geode is cut on a worker thread the first time it is shown and kept for the session.

**The drum (October 10 to 12, 2026).** Before the rework the Geode was opened on a reel, a slot machine in the spirit of a CS case drawn in the workshop's brass and iron. It worked like this:

1. The Geode sits in front of an iron drum case with a plaque, a ring of lamps, a loupe's hairline over its window and a lever at its side. The lever breathes, says PULL and shows which way it goes.
2. Pulling it (a click anywhere, or Space) cracks the Geode along its glowing seam; the halves fall away and the drum spins behind them.
3. The strip on the drum is 64 tiles, each a skill's mark on a tile washed in its **rarity's color** (Common to Legendary, opals in a rainbow), so the colors read at speed the way a case's do. Every tile but the winner is drawn at the Geode's own odds, so what goes by is what could have come out. The drum slows tooth by tooth, a tick for every tile past the pawl, and stops anywhere across the winning tile, not always dead centre.
4. The lamps chase while it spins and blink the winner's rarity when it stops; a Rare stone adds a gleam and a shake, a Legendary or an opal the jackpot.
5. The machine steps back and the stone is set on the lamp and read out line by line by the appraisal's own sheet (carat, Cut, Clarity, inclusions, grade, worth). Its grade's color takes over the frame.
6. The choices are the tray's: Into the vault (with the "A new skill!" fanfare for a first stone), sell, Turn it in for a commission, or, for a skill already kept, Weigh it against yours at the loupe table; or back to the shop, the stone waiting on the tray.

**Price:** `geode_price_mult` (1.75) times the average sale value of the Geode's stone, rounded up to ten, and never under the mine's own floor (`geode_gold`), so cracking Geodes to sell what is inside always loses gold (§7 checks it).

| Mine                 | Quarry | Seeps | Glass Veins | Warrens | Furnace | Hollow | Rift |
| -------------------- | ------ | ----- | ----------- | ------- | ------- | ------ | ---- |
| `geode_gold` (floor) | 150    | 200   | 240         | 270     | 330     | 370    | 370  |
| A mine's Geode costs | 160    | 210   | 250         | 280     | 340     | 380    | 370  |

**Geodes from the mine (October 15, 2026).** A Geode can also be brought up from a run, and these cannot be bought with gold or cracked down there. They are the same rock as a shelf Geode: a recipe (`kind` mine or color, `theme`, `mine`, `id`) and one stone inside, rolled by `roll_geode_stone` the moment the Geode is made. In the haul and on the tray a Geode is a stone dictionary, still `appraised: false`, with the recipe under `geode` (`DeepStone.is_geode`), so everything that carries stones carries it; `DeepEconomy.roll_run_geode` makes one. Two things in a run put one in the bag:

- **The third Warden's hoard** (the mine's boss; in the Rift, every third Warden) swaps its last non-opal pedestal for a Geode of the mine the party is in (`hoard_geode_pct`, 100). It stands on the pedestal as the 3D rock, with "Geode" cut into the plinth.
- **The Geode oddity** now shows a Geode of the current mine on the plinth, turning, and sells it: `geode_buy`, for pyrite, `geode_run_price_mult` (1.0) times the Geode's gold price on the shelf (`run_geode_price`), or leave it. The old "crack it" and "sell it" choices are gone.

Down the mine a Geode can be carried, traded at a landing and nothing else: `DeepOddities.find_stone` never finds one, so no oddity, lens, well, merchant or smith can touch it, and an unappraised stone cannot be set. A wipe's salvage dice roll it like any raw stone. The bag (the bench, and the dock's drawer) is split in tabs: **Appraised**, **Raw** and **Geodes** (`DeepUi.HAUL_TABS`, `DeepStone.haul_tab`), each with a count.

At home it comes up on the tray (and the vault's Unappraised view) sealed. Where a raw stone is **read**, a Geode is **cracked**: the same fee as reading a stone of its size (`appraisal_fee`, on `geode_rough`), the three-blow ceremony, and then the stone is an ordinary one, decided like the rest. "Read the rest" leaves Geodes alone, so each is cracked on its own. **Sold unopened** it fetches `geode_rough_share` (0.3) of what a stone of that kind of Geode is worth on average, whatever is in this one. Cracking counts in `records.geodes`.

### 🟢 3.4 Contracts, trade-ups (phase 5)

Five stones of one grade tier go in, and one stone of the next tier comes out. It works like a CS trade-up contract.

| Rule                     | Detail                                                                                                                                                                                                                                                                                                                                            |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inputs                   | **5 appraised stones of the same grade tier**: Rough, Fine, Precious or Exquisite. They can come from the tray or the vault. No Birthstones, fragile stones, Opals or Transcendents.                                                                                                                                                              |
| Output tier              | Always the next tier up. There is no fail state. The risk is giving up five known stones for one unknown.                                                                                                                                                                                                                                         |
| Output color             | Weighted by the inputs: 3 Red and 2 Blue gives 60% Red and 40% Blue. A color with no skill in the rock that could reach the next tier at that carat is struck out, and the others share its weight.                                                                                                                                               |
| Output mine              | The deepest mine among the inputs. The skill comes from that mine's pool, filtered to the drawn color.                                                                                                                                                                                                                                            |
| Output carat             | The inputs' average carat, rounded, capped at that mine's cap at the deepest floor its stones came from. This is the lever players control, like float in CS. Carat is 45 of the 100 grade points, so a big, badly cut stone becomes worth keeping for a contract.                                                                                |
| Cut, Clarity, inclusions | Rolled at the bottom of that mine's luck, with more luck each try, up to 48 tries, until the grade lands in the target tier. If luck alone never gets there the stone is worked up a step at a time (Cut first, then Clarity toward Intricate with the rarest sound inclusions the rock holds), which the feasibility check promises is possible. |
| Impossible contracts     | If the average carat is too low for the next tier even with a perfect Cut and Clarity, the contract cannot be signed, and the screen says why.                                                                                                                                                                                                    |
| Fee                      | 20 / 60 / 150 / 400 gold for Rough / Fine / Precious / Exquisite inputs.                                                                                                                                                                                                                                                                          |
| How often                | **Once a day** (from October 12, 2026), like the Wheel and the Oven.                                                                                                                                                                                                                                                                              |

**Vault stones as inputs.** A vault stone can go in, with a warning that the skill becomes unowned (still seen). This is how a player uses a stone they are about to replace: put the old one into a contract, then keep the new one.

**The screen.** The bench on the left: the promise (five of this grade, one of the next), five places (a click takes a stone back off), and lines running down from each place to a ring where the new stone will come out, lit a fifth at a time as the bench fills and breathing once the contract can be signed. Under it the forecast: the grade, carat and rock, the color odds, and every skill it could become with the exact odds of each (`DeepEconomy.contract_odds`). The picker on the right pages the tray's and the vault's eligible stones (All, Tray, Vault), and once the first is on, only stones of its grade can follow. Signing puts the five in a circle that turns in to its middle until they meet in a flash, then the new stone is read out the way a Geode's is, with the same choices. **Fill from cheapest** puts the five lowest-worth stones of a grade on the bench (tray stones before vault ones at the same worth), the grade being the first stone's on the bench, or with the bench empty the lowest grade that has five. The contract is a page of the Market reached from its bench (§3.6).

**Why we keep one stone per skill.** Contracts do not need duplicates. They need five stones of one _tier_, which can be any skills. The tray already keeps stones between runs and pages them, so it is the natural place for contract material to wait. Lifting the one-per-skill rule would mean:

- loadouts pointing at individual stones instead of skills (`DeepProfile.set_rail` stores a skill key today);
- a vault grid that can show several stones per skill;
- losing the keep-one-or-the-other decision, which is the core of the home loop and its main source of gold.

That is a large change with no gain for Contracts. Revisit it only if the tray becomes a long-term storage problem; a tray cap would be the first answer.

### 🟢 3.5 Socket unlocks

A lapidary's rail is filled from the vault only as far as that lapidary's **unlocked sockets** reach, in every mine. Everyone starts with the first three. The rest are bought with gold, **permanently and per lapidary**, so gold also says which lapidaries a player has invested in.

| Socket                                 | 4th | 5th  | 6th (the one lapidary with six) |
| -------------------------------------- | --- | ---- | ------------------------------- |
| `socket_unlock_gold` (starting values) | 300 | 1200 | 4800                            |

- **Prices climb steeply** (×4 a socket), so the last socket is a long-term goal.
- **Only the pre-run fill changes.** A locked socket still takes stones found during a run, as Quarry sockets 4–6 do today.
- **Where:** the Lapidaries tab already draws locked sockets with a lock. A locked socket shows its price and an Unlock button, and once unlocked it accepts a stone from the vault like the first three.
- **Replaces** the per-mine `loadout_sockets`: deeper mines fill 3 plus whatever is unlocked, like the Quarry. The rule "the loadout lets a stone past the third socket once any deeper mine is open" goes away.
- **Balance watch:** deeper starts lean on temporary stones (§3.1) for the sockets a player has not bought. If they feel too weak, raise their luck before touching the purse or creature health.
- **The daily dig is unaffected:** it fills the rail by its own rail rule (§4.2).
- **Travelling heavy (October 29, 2026):** a bought socket is the right to bring a fourth, fifth or sixth stone, and every stone over three takes 2 luck off every stone the mine gives that player (every socket left empty adds 2). The loadout page and the map say so, with a dark star per stone over three and a gold one per empty socket. See REIMAGINING.md §5.1.
- **Fusing a twin costs 100 pyrite** (`fuse_ore_cost`) when it is fused into the one held (§5.1 there); the Crucible room stays free. Pyrite, never gold, so rule 1 holds.
- **Co-op:** each player's unlocks are their own. A guest's rail arrives filled as far as their own lapidary allows.

### 🟢 3.6 The Market (October 12, 2026)

The Market is the home tab where gold is spent, on one page with no scrolling:

- **Down the left:** today's Geode and the week's (§3.3).
- **In the middle: the case.** Three stones a day, cut and read, each a different skill, from the open mines (a random depth in the lower half of the mine, with `case_luck` 2 on top). Never an opal, a Transcendent or anything fragile. Each sits under a lamp with its trigger, card text, carat line and inclusions, and beside it how it compares to the one of its skill already kept ("Yours: Fine · 38", and how many grade points apart), or "New!". Holding Shift over one compares it in full. **Price:** 2.5 times what it sells for (`case_price_mult`), rounded up to ten, never under 30 (`case_gold_min`), so buying and selling always loses gold. **Buy** puts it straight into the vault (marked new) in place of the stone of its skill already kept.
- **Under the case: the bench**, three tiles in a row: the Wheel, the Oven and the trade-up contract (§3.4), each a page of its own and **once a day each**, marked "Used today" once done. Each tile carries a short line; the whole of what it does shows on hover. (Until October 13, 2026 the bench sat under the commissions, and the case's lamps were taller.)
- **Down the right: the commissions** (§4.1), the whole column, the three sharing its height. Each is read down its middle: the skill's emblem large, its name and what it asks under it, what it pays on the left and the swap with its price in gold on the right. A Turn in button shows when a tray stone or a kept stone meets it, with that stone on it (right-click for the close look) and what it pays in gold; a kept stone asks twice, since its skill is then no longer kept.
- **Restock.** Once a day, for 100 gold (`restock_gold`): a new Geode of the day and a new case. The week's Geode and the commissions stay as they are. The header says how long until the day turns over.

**The Wheel and the Oven.** A stone from the vault (not the tray: those are decided first) goes on the Wheel to have its Cut cut again, or into the Oven to have its Clarity, and what is frozen inside it, fired again. The result is always a different rung (`DeepForge.cut_weights` and `clarity_weights` with the current rung struck off), drawn at the luck of the mine and depth the stone was found at, so a Quarry stone stays a Quarry stone, and the Oven never leaves anything fragile inside. **1 in 25 stones break** (`rework_break_pct` 4): the stone is gone from the vault and every loadout, and it flies apart on the page with a sound of its own. **Price:** half the stone's worth, rounded up to five, never under 25 (`rework_price_mult`, `rework_gold_min`). The page shows the stone on a ladder of rungs with a bar of what it could come out as and the break chance; the ladder flickers like a reel for about a second and lands, with a gleam and a rising chime for a better rung and a low note for a worse one. A reworked stone counts its reworks in its provenance. The same ladder now shows down the mine wherever an oddity recuts or refires a stone, and a stone broken there flies apart the same way.

**Why once a day is enough of a guard (§8.2).** The plan worried that rerolls would let a player polish every vault stone to its mine's best Cut. With one turn of the Wheel and one firing a day, a result that always changes (better or worse), a price that follows the stone's worth and a 1 in 25 chance of losing it, polishing a stone is slow and costly, and a good stone is risked every time.

**Favorites** (named Wanted until October 14, 2026). The star in the top-right corner of the vault's lamp makes a skill a favorite: an outline until clicked, filled while it is one. A favorite's tile wears the star, and every Geode, case stone and commission that could be one says so. An old save's wanted list becomes its favorites.

## 4. Earning gold

### 🟢 4.1 Commissions

**What a commission asks for.** Every commission names **one skill**. Some also add **one requirement from the four C's**:

| Requirement | Example                                                                    |
| ----------- | -------------------------------------------------------------------------- |
| Carat       | "8 carats or more" (always within the band of a mine the player can reach) |
| Cut         | "Good cut or better"                                                       |
| Clarity     | "Pristine or better", or "with at least one inclusion"                     |

- Only stones count. There are no depth or fight goals.
- The commission card shows the skill's emblem and name, and a tooltip saying **where it is found**: its batch mine and every mine below it (`DeepForge.batch_tiers`).
- Skills are drawn from the pools of the mines the player has unlocked, **including skills the player has never seen**: the card names the skill and where it is found, which doubles as a hint. Being named on a commission does not count as seen in the vault; the player still has to find one. Mythic Opals are excluded.

**Slots and refresh.**

- There are three slots. At 00:00 UTC every unfilled commission is replaced and every filled slot gets a new one.
- One free reroll a day. After that a reroll costs gold, starting at 10 and rising by 10 each time, which is a small extra gold sink.

**Payout:** 2.5× the sale value of the weakest stone that would meet every requirement, rounded to 5. Turning a stone in must always beat selling it.

**Turning in.** The Appraise tab gains a **Turn in** button beside Keep and Sell whenever a tray stone meets a commission. Turning in pays the gold and removes the stone. Its skill stays seen. (Since October 12, 2026 the commissions live on the Market, where a kept stone that meets one can be turned in too; §3.6.)

**The first stone of a skill.** The automatic keep (`DeepProfile.auto_keep`, called on homecoming and from the home screen) is removed. Instead:

- Every first stone of a skill opens a **"New skill" popup** with fanfare: its own sound, a stronger beam than the ordinary grade reveal, and the vault slot for that skill lighting up from grey to color.
- The buttons are **Keep**, plus **Turn in** when a commission wants it. **Sell is never offered**, so the rule "the first stone of a skill is never sold" still holds.
- A raw first stone is appraised first, as now. Stones read in the mine get the popup on homecoming, one after another.
- A player may also leave a first stone on the tray, for example to put it into a contract.

**Optional extra:** when a stone is appraised down the mine and it meets a commission, mark it with a small commission icon.

### 🟢 4.2 The daily dig (phase 6, reworked October 10, 2026)

One seeded run per UTC day, the same for every player on the same build, in the spirit of Slay the Spire's daily climb. The first version (two hazards and a blessing, a lent rail in a seeded mine, gold per floor) was replaced the same day after a review of format options and 82 candidate modifiers (§10, decision 7).

**The run.** It starts at the top of the Quarry and goes on through every mine into the Rift. There is no bottom: the party rides up when it chooses, or falls.

**What the seed decides** (`DeepEconomy.daily_plan`):

- one lapidary for the whole party;
- four cards (`daily_deal`): a rail rule, a hazard, a blessing and a twist. Cards share a `group` when they would cancel out or stack too hard (Iron Bowl and Overcast both set the dice's material; Tight Winch and Greased Winch both set the lift's cost), and two cards of one group are never dealt on the same day;
- what some cards need: Drought's color, Strangers' Dice's bowl, the Borrowed Birthstone's owner and One Trick's skill.

The seed is `hash("deep-cut-daily:<UTC date>:<pack version>:<DAILY_RULES>")`. `DAILY_RULES` is 2 since the rework, so the two versions never claim the same day.

**Score and pay.**

- **Score:** the worth of every stone a player brings up, plus the pyrite they carry. Lent and fragile stones never count. After a fall, only the stones the salvage dice save count, and pyrite counts nothing.
- **Nothing is kept.** The stones, dice and pyrite stay behind.
- **Gold:** `daily_score_rate` (0.5) of the score up to `daily_score_knee` (1000), and half that rate above it. A score of 1000 pays 500 gold; 3000 pays 1000.
- **Attempts:** as many as a player likes. A later dig the same day pays only the gold its score adds to the day's best, so a lower score pays nothing.
- **Who is paid:** lapidaries who have beaten the Quarry's final boss. Anyone who has not, host or guest, can still dig it and see their score, unpaid (a solo player is a host; since October 26, 2026).
- **The Ledger** keeps the best score of each day (the last 30 days), the best of all, and each daily run's score in the run history.
- **Not a mine's run:** it opens no mine, brings no lapidary into the workshop, pays no first-conquest or Warden purse and writes no mine's records.

**Co-op.** The host picks the day's seam for the party. It costs no fare and needs no insurance. Each player is scored and paid on their own stones and pyrite. A host who has not beaten the Quarry digs it unpaid, as such a guest does (until October 26, 2026 the host had to have beaten it).

**Rail rules** (one a day, `kind: "rail"`, weighted by `weight`):

| Rule             | What it does                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------- |
| **Lent Rail**    | Every socket starts with a lent stone of its color.                                         |
| **Draft**        | Every socket starts empty and offers three stones of its color. Pick one for each.          |
| **Sealed Tray**  | Your rail starts empty and your bag holds a dozen read stones. Set the ones you want.       |
| **The Big Haul** | Your rail starts empty and your bag is full of raw stones. Read them and set what you find. |
| **Bare Hands**   | Only the Birthstone is set. Every other socket starts empty.                                |
| **One Trick**    | Every socket that can take it holds the same skill. The others start empty.                 |

**Hazards:**

| Card               | What it does                                                                          |
| ------------------ | ------------------------------------------------------------------------------------- |
| **Short Wick**     | The lantern only lights the next floor.                                               |
| **Hard Rock**      | Creatures have a quarter more health.                                                 |
| **Bad Air**        | Everyone starts with a quarter less health.                                           |
| **Tight Winch**    | The lift costs twice as much.                                                         |
| **Blank Faces**    | Every die's highest face is blank.                                                    |
| **Closed Stalls**  | There are no merchants.                                                               |
| **Glass Bowl**     | Every die is glass. Glass dice can break when thrown.                                 |
| **Brittle Picks**  | Swinging at the rock costs twice the health.                                          |
| **Small Bones**    | Every die is one size smaller.                                                        |
| **Void Season**    | Void inclusions are much more common.                                                 |
| **Drought**        | One color does not come out of the rock.                                              |
| **Sharp Claws**    | Creatures deal a quarter more damage.                                                 |
| **Warden's Wrath** | Wardens and bosses have half again their health. Their hoards have one more pedestal. |
| **Overcast**       | Every die is cloud: it rolls twice and keeps the lower result.                        |
| **Shaky Hands**    | One fewer reroll every turn.                                                          |
| **Short-Handed**   | Your smallest die sits out every turn.                                                |
| **One Road**       | Each floor has one chamber, so there is no choice of path.                            |
| **No Bench**       | You cannot rest at landings.                                                          |
| **Last Lift**      | The lift only runs from Warden landings and boss halls.                               |
| **Toll Gates**     | Each landing takes a quarter of the pyrite you carry.                                 |
| **Bleeding**       | Every floor you go down costs 2 health.                                               |
| **Cursed Run**     | Beating a Warden locks a face on one of your dice.                                    |

**Blessings:**

| Card                | What it does                                                       |
| ------------------- | ------------------------------------------------------------------ |
| **Rich Seams**      | Stones from the rock are rolled with more luck.                    |
| **Golden Faces**    | Every die's lowest face is golden.                                 |
| **Deep Pockets**    | Everyone starts with 100 pyrite.                                   |
| **Generous Hoards** | Warden hoards have one more pedestal.                              |
| **Steady Hands**    | One more reroll every turn until the first landing.                |
| **Bright Well**     | Wells count everything thrown in as worth half again as much.      |
| **Heirloom**        | One socket holds an Exquisite stone.                               |
| **A Borrowed Opal** | One of your Any sockets holds an opal.                             |
| **Big Bones**       | Every die is one size bigger.                                      |
| **Motherlode**      | Veins open into motherlodes much more often.                       |
| **Lamplight**       | Stones come out of the rock already read.                          |
| **Torpor**          | Every creature is stunned on its first turn.                       |
| **Fireworks**       | Every die's highest face explodes.                                 |
| **Iron Bowl**       | Every die is iron: it rolls twice and keeps the higher result.     |
| **Wild Card**       | Your biggest die has a wild face.                                  |
| **Ringing Bowl**    | Every die is crystal: each throw adds Resonance.                   |
| **An Extra Die**    | A plain d6 joins your bowl.                                        |
| **Greased Winch**   | The lift is free.                                                  |
| **Altar Lights**    | Every stretch has an altar.                                        |
| **Market Day**      | Merchants sell at half price.                                      |
| **Collector's Day** | Merchants pay full worth for stones.                               |
| **Hardy**           | Everyone has a quarter more max health.                            |
| **Second Wind**     | The first time you go down, you get back up with half your health. |

**Twists:**

| Card                    | What it does                                                                                    |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| **Strangers' Dice**     | Your dice are drawn from every lapidary's starting dice.                                        |
| **Borrowed Birthstone** | You carry another lapidary's Birthstone instead of your own.                                    |
| **Clear Water**         | Stones have no inclusions. Every one is Clear or better.                                        |
| **Flawed**              | Every stone has at least one inclusion.                                                         |
| **Heavy Rock**          | Stones are two carats heavier, and swinging at the rock costs more health.                      |
| **Restless Rock**       | At every landing, the stones on your rail may change to another skill of their color.           |
| **Big Game**            | Elites are twice as common, and the stones they drop come out read.                             |
| **Swarms**              | Every fight has one more creature, and each has less health.                                    |
| **Lone Beasts**         | Every fight is one creature with the health of the whole group.                                 |
| **Plated**              | You start every fight with 6 Block, but lose 1 max health after each fight.                     |
| **Gambler's Bowl**      | Every die that can take the Gambler's pattern has it: 6s and 8s count as 7s.                    |
| **Blood Dice**          | Every die is blood: rerolling it costs 2 health, and its face goes up each time something dies. |
| **Tally Marks**         | Every die's lowest face goes up by 1 each time it shows.                                        |
| **Night Terrors**       | Resting heals you to full, but lowers your max health a little.                                 |
| **Strange Day**         | Oddities are three times as common, and fights are rarer.                                       |
| **Midas**               | Fights and veins pay twice the pyrite, but there are no Smithies, Carvers or Vats.              |
| **Glass Lungs**         | Your max health is halved, but every landing heals you to full.                                 |
| **Colorblind**          | Any stone fits any socket.                                                                      |

Cut in the review: Matching Aprons, Sleeping Birthstone, In the Dark, Hoarder, Magpie Day, Rope and Grapple, Long Wick, Halfway Down, No Bottom (the seam has none anyway), Looking-Glass, Echoes, Restless Rail, Shifting Seam and One Rope.

### ⛔ 4.3 The assay at the lift (removed October 14, 2026)

Built October 7, 2026, and taken out on October 14, 2026: pyrite can be dug without end, so weighing it into gold at the lift made gold too easy to come by. The pyrite a player carries when a run ends is lost again, as it was before this plan; it still counts toward the daily dig's score (§4.2), which a later dig the same day only tops up.

Gone with it: `assay_rate`, `DeepEconomy.assay`, the `stats.earned` tally and `DeepEconomy.earned`, and the assayer's strip on the end-of-run card.

What it was: when a run ended by extraction or conquest, each player's remaining pyrite was converted at 5 pyrite to 1 gold, never more than the pyrite earned that run, so the starting purse of a deeper mine could not be cashed.

### 🟢 4.4 First-conquest purse

The first time a player beats a mine's final boss, they receive a one-off purse: `first_conquest_gold` per mine. It is paid when the mine record's `boss` flag first turns true. The Rift has no bottom and no purse.

| Mine | Quarry | Seeps | Glass Veins | Warrens | Furnace | Geode |
| ---- | ------ | ----- | ----------- | ------- | ------- | ----- |
| Gold | 150    | 250   | 400         | 600     | 900     | 1300  |

**Warden purses (October 26, 2026).** The first time each Warden falls it pays a purse of its own: a third of the mine's `first_conquest_gold` for the first Warden and half for the second, rounded to 5 (`DeepEconomy.WARDEN_PURSE_SHARES`, `warden_purse`): 50 and 75 in the Quarry. Like the conquest purse it is paid at home, once on any Hazard tier, whether the party rode up or fell, and never on the day's seam. The Descend track shows each crown's purse until it is paid. Wardens beaten before then count as paid.

| Mine           | Quarry | Seeps | Glass Veins | Warrens | Furnace | Geode |
| -------------- | ------ | ----- | ----------- | ------- | ------- | ----- |
| First Warden   | 50     | 85    | 135         | 200     | 300     | 435   |
| Second Warden  | 75     | 125   | 200         | 300     | 450     | 650   |

## 🟢 5. Content and save data

**New fields on each mine** (`mines.*`):

- 🟢 `fare_gold`, `insurance_gold`, `first_conquest_gold`. `loadout_sockets` is removed; every mine uses `starting_rail_cap` (3) plus the lapidary's unlocks.
- 🟢 `geode_gold`: the floor under a mine's Geode price (§3.3).

**New constants:**

- 🟢 `socket_unlock_gold` ([300, 1200, 4800]), `temporary_depth` (20), `temporary_luck` (4), `temporary_min_tier` (PRECIOUS), `commission_slots` (3), `commission_payout_mult` (2.5), `commission_reroll_gold` (10) and `commission_reroll_step` (10), `commission_requirement_pct` (50).
- 🟢 `geode_luck` (4), `geode_carat_over_cap` (2), `geode_carat_keep` (50), `geode_opal_pct` (1), `geode_price_mult` (1.75); `contract_inputs` (5), `contract_fee` (20 / 60 / 150 / 400 by tier); `daily_deal` (a rail rule, a hazard, a blessing and a twist), `daily_score_rate` (0.5), `daily_score_knee` (1000). The first daily's `daily_mines`, `daily_hazards`, `daily_blessings`, `daily_gold_per_depth` and `daily_clear_gold` are gone.

**New sections:** 🟢 `geodes` (`featured`: eight weekly sets, each a name, a line and its skills), `daily_modifiers` (six rail rules, 22 hazards, 23 blessings and 18 twists, each a name, kind, mark and line, some with a `group` or a `weight`). The pack's validation checks both.

**Profile:** 🟢 schema 3, with an upgrade (`DeepProfile.upgrade`) that leaves every old field alone.

- 🟢 `daily`: `{date, commissions: [3], rerolls, seq, shelf: [3 Geodes with their stones, prices and whether bought]}`, rebuilt whenever `date` is not today (UTC).
- 🟢 `dig`: `{date, best_score, best_gold, runs, run_id}`, the day's attempts and its best.
- 🟢 `records.daily_bests` (the last 30 days' bests) and `records.best_daily`.
- 🟢 `records.geodes`, `records.contracts`, `records.dailies`.
- 🟢 `outfit`: `{insure: bool}`.
- 🟢 `characters.<key>.sockets`: how many sockets that lapidary has unlocked (3 to start).
- 🟢 `conquest_paid`: the mines whose first-conquest purse has been paid.
- 🟢 `warden_paid`: the Wardens whose purse has been paid, as `"<mine>:<index>"` (`"QUARRY:0"` is The Foreman).
- 🟢 `charged_run`: the last run this profile paid its fare for, so no run is billed twice.

All date logic takes the date as an argument, so tests can set any day.

## 6. Build order

Each phase ships on its own and leaves the game playable.

| Phase                                                               | What                                                                                                                                                                                                                                                                                                                                                        | Where                                                                                                                                                                                                                                                                                                                            | Tests                                                                                                                                                                                                                                                                                       |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢 **0. Groundwork** (built October 7, 2026)                        | The UTC date helper, profile schema 3 and its migration, content fields and constants. A new `sim/economy.gd` holds every price and every daily roll, pure and headless. A data-browser page shows the expected value of a stone, Geode and contract by mine.                                                                                               | `sim/economy.gd`, `sim/profile.gd`, `content/deep_cut.json`, `tools/data-browser/`                                                                                                                                                                                                                                               | Migration; date turnover; content validation of the new fields                                                                                                                                                                                                                              |
| 🟢 **1. Assay and first-conquest purse** (built October 7, 2026)    | The conversion on homecoming, with its animation before the tray (removed October 14, 2026, §4.3). The one-off purse.                                                                                                                                                                                                                                       | `sim/profile.gd` (homecoming), `view/home/home_screen.gd`                                                                                                                                                                                                                                                                        | Earned-pyrite cap; fall pays nothing; purse paid once                                                                                                                                                                                                                                       |
| 🟢 **2. Commissions** (built October 7, 2026)                       | The three slots on the Ledger, the Turn in button, the "New skill" popup in place of `auto_keep`, rerolls.                                                                                                                                                                                                                                                  | `sim/economy.gd`, `sim/profile.gd`, `view/home/home_screen.gd`, `view/gems/appraisal.gd`, `view/audio/sound_bank.gd`                                                                                                                                                                                                             | Requirement matching; first stone never sellable; payout always beats sale                                                                                                                                                                                                                  |
| 🟢 **3. Fares, insurance and sockets** (built October 7, 2026)      | Fares, the insurance checkbox, the Descend total, salvage keeping the better of two rolls, co-op payment and refund. Socket unlocks on the Lapidaries tab, every mine filling only unlocked sockets, and the temporary-stone picks at the shaft head. These ship together, so deeper starts never lose their full rail before players can buy sockets back. | `view/home/home_screen.gd` (trip panel, the "every socket filled" line, the loadout), `sim/descent.gd` (`new_run`, `loadout_sockets`, salvage, `can_wish`), `sim/oddities.gd` (fuse), `sim/boons.gd` (the pick row), `sim/profile.gd` (`starting_rail_cap`, `widest_rail_cap`), `content/deep_cut.json`, `docs/MINES.md`, `net/` | Fare charged once per player; push-on free; insured salvage; rail filled to exactly the unlocked count in every mine; unlocks are per lapidary and permanent; one temporary pick per empty socket, in its color; temporary stones shatter, cannot be wished, and make a fused stone fragile |
| 🟢 **4. Shop: Geodes** (built October 10, 2026)                     | The Shop tab, the daily shelf with its printed odds, the raised carat band, the drum.                                                                                                                                                                                                                                                                       | `sim/forge.gd` (`skill_table`), `sim/economy.gd`, new `view/gems/geode.gd`, `view/home/home_screen.gd`, `view/audio/sound_bank.gd`, `content/deep_cut.json`                                                                                                                                                                      | No Void; carat within the raised band; shelf stable across reloads; odds add up; price over worth                                                                                                                                                                                           |
| 🟢 **5. Contracts** (built October 10, 2026)                        | The Contracts view, input rules, output roll, feasibility check, the sealing.                                                                                                                                                                                                                                                                               | `sim/economy.gd`, `view/home/home_screen.gd`, `view/gems/geode.gd`                                                                                                                                                                                                                                                               | Color weighting; carat average and cap; tier always next; impossible contracts refused; vault stones leave loadouts; odds add up                                                                                                                                                            |
| 🟢 **6. Daily dig** (built October 10, 2026, reworked the same day) | Global seed, the four-card deal, rail rules, scoring and pay, co-op rules, the Map's Daily view, the run's daily marks and the Ledger's daily bests.                                                                                                                                                                                                        | `sim/economy.gd`, `sim/descent.gd`, `sim/forge.gd`, `sim/battle.gd`, `sim/oddities.gd`, `sim/boons.gd`, `sim/profile.gd`, `view/home/home_screen.gd`, `view/run/`, `view/app.gd`, `net/session.gd`                                                                                                                               | Same date and build gives the same run; one card of each kind and never two of a group; every rail rule and every card does what it says; a score counts only what came up; later digs pay only the improvement; nothing found is kept                                                      |

## 🟢 7. The no-profit test

`tests/test_economy.gd` simulates thousands of rolls per mine and fails if any of these makes money on average:

- 🟢 buying a Geode and selling what is inside (300 Geodes in each of five mines);
- 🟢 buying Geodes, appraising nothing further, and putting their stones into contracts five at a time, then selling the output;
- ⛔ the fare against cashing out the starting purse through the assay (moot since the assay was removed on October 14, 2026);
- 🟢 turning in against selling (this one must always favour turning in; it is the only intended profit);
- 🟢 the case: every stone in it costs at least twice what it sells for.

The test reads prices from content, so retuning a number can never quietly open a loop.

## ⚪ 8. Later: ideas for a future pass

None of this is in the build order.

### ⚪ 8.1 Birthstone upgrades

Like socket unlocks (§3.5), these grow one lapidary permanently. Rule 1 still holds: none of this touches a vault stone.

- **Raise it:** spend gold to improve a lapidary's Birthstone along one axis, for example its multiplier per tier, or an easier first tier. A few steps, each dearer than the last.
- **Swap it:** each lapidary gets one or two **alternative Birthstones**, bought once with gold, and the player picks which one to bring before a run. An alternative reads a different hand or pays out differently, so it changes how the lapidary plays rather than only making them stronger. Example shape: Ardor's Rally reads sets (pair, triple, four and five of a kind); an alternative could read straights or a high total instead, so Ardor stops chasing matches.
- Each alternative needs its own tiers, Birthstone face and tests in `tests/test_battle.gd`, like the current six (`docs/CHARACTERS.md`). That is the main cost; the gold side is small.

**Open for that pass:** whether upgrades are bought on the Lapidaries tab (likely, next to the dossier and the socket unlocks), and how a guest's Birthstone choice shows to the rest of the party.

### 🟢 8.2 Shop services: the Wheel and the Oven

**Built October 12, 2026, as described in §3.6:** vault stones only, once a day each, a result that always changes, a price that follows the stone's worth and 1 in 25 stones broken. The plan as it stood before follows.

A third Shop view where a player pays gold to **reroll one stone's Cut (the Wheel) or its Clarity (the Oven)**, from the tray or the vault.

**How a reroll works.** It is the mine's own gamble, run at home:

- It uses `DeepForge.reroll_cut` / `reroll_clarity`: a fresh draw, better or worse, with the current rung struck off the table, so the result always changes.
- It draws at the luck of the **stone's own mine and depth** (its provenance), so a Quarry stone stays a Quarry stone.
- An Oven reroll draws the inclusions again with the new Clarity, but **never Void**: a Void stone would shatter on the bench.
- There is no undo. The player keeps whatever comes off the wheel.

**Price: high, and climbing fast within a day.**

- One counter per player, shared by the Wheel and the Oven, reset at 00:00 UTC.
- Price = base × 2^(uses today): ×1, ×2, ×4, ×8, …
- The base is the larger of a per-mine floor (`reroll_gold`) and half the stone's sale value, so rerolling a cheap stone and selling it can never pay. That check joins the no-profit test (§7).

**A daily version** (lighter, and could ship first). The shelf offers **one discounted reroll a day**, alternating between the Wheel and the Oven, beside the day's Geodes. After that the full climbing price applies, or the service is simply not offered.

**The risk to weigh before building it.** The comment on `reroll_cut` says what to fear: "Nothing anywhere may raise a Cut on purpose — that is what would make a stone farmable." A reroll is a gamble, but a player can keep rerolling until a good result and then stop. Given enough days, every vault stone could reach its mine's best Cut, and the daily reset brings the cheap first rolls back every day. Ways to keep it from becoming a farm:

- **Once per stone, ever:** a reworked stone carries a "Reworked" mark in its provenance and cannot go back on the home wheel. The mine's Wheel still takes it.
- **A climbing price per stone,** not per day, that never resets.
- **Tray stones only:** a stone can be reworked only before it is first kept. This makes it part of the keep-or-sell decision, not a way to polish the vault.

Pick one of these if the service is built. "Once per stone" is the simplest to explain.

## ⛔ 9. Considered and left out

| Idea                                     | Why not, for now                                                                                                                                                                                             |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A fee for every run, or a free run a day | Blocks co-op parties, traps broke players, punishes regular players.                                                                                                                                         |
| Starting a run past a beaten Warden      | A run always starts at the top of a mine; the fare covers deeper starts.                                                                                                                                     |
| Dice in the shop                         | Each lapidary's dice are their own, and the range of bowls makes a fair shop hard.                                                                                                                           |
| Grubstake add-ons                        | Too dull for the gold they would cost.                                                                                                                                                                       |
| Bench upgrades                           | Shared upgrades are hard to balance. Replaced by per-lapidary socket unlocks (§3.5) and, later, Birthstone upgrades (§8.1).                                                                                  |
| Paying for a fourth stone on each run    | Annoying to buy every time. Replaced by permanent socket unlocks per lapidary (§3.5).                                                                                                                        |
| A second vault slot per skill            | Loadouts and the vault are built around one stone per skill (§3.4).                                                                                                                                          |
| A three-blow crack for Geodes            | Planned first (thumbnails of stones read badly at speed), then replaced on October 10, 2026 by the drum (§3.3): tiles washed in rarity colors carry the moment, and the stone itself is read out afterwards. |
| A guaranteed recut or re-fire for gold   | Breaks rule 1. A reroll gamble with a climbing price is a candidate (§8.2).                                                                                                                                  |
| Depth or fight goals as commissions      | Commissions are stones only, so they stay tied to the appraisal.                                                                                                                                             |

## 10. Decisions

Settled October 6, 2026:

1. **The daily dig lends its rail**, rolled from the seed. The player's own loadout is not used.
2. **Commissions may name skills the player has never seen.**
3. **Geodes have a 1% chance of a Mythic Opal.**
4. **Deeper mines stop filling every socket.** Every mine fills the first three plus the lapidary's unlocked sockets, bought with gold (§3.5).
5. **Deeper starts fill the remaining sockets with temporary stones,** one pick of three per empty socket, which shatter when the run ends (§3.1).

Settled October 10, 2026:

6. **Geodes open on a reel after all:** a slot machine with a CS case's feel (§3.3), in place of the three-blow crack.
7. **The daily dig is reworked** (from the review page of format options and modifiers): the same lapidary for the whole party; a rail rule, a hazard, a blessing and a twist each day; it starts at the Quarry and goes on into the Rift; the score is the worth of the stones brought up plus the pyrite carried, nothing is kept, and gold is paid for the score; a later dig pays only what it adds to the day's best; a fall scores what the salvage dice save; the Ledger keeps daily bests. 68 of the 82 modifiers were kept (§4.2).

No questions are open for phases 0–6. The later ideas in §8 carry their own open questions.

## 🟢 11. What the build settled

### Pyrite and kept stones, October 14, 2026

- **No gold for a stone replaced in the vault.** Keeping a stone of a skill already kept lets the old one go for nothing (`DeepProfile.keep` pays nothing). The only stone sold is the one not kept: Sell it pays the new stone's worth and leaves the vault alone. The tray's choice reads Keep it, replace yours ("Yours is let go for no gold"), and a stone bought from the case replaces the one kept the same way. Since Oct 26 2026 keeping stands last on the row, in one place on every stone (and the row waits 0.35 s after the tray moves on); whichever choice would cost the better of the two stones (higher grade, then worth) is drawn in outline and asks for a second click that says in red what it costs.
- **No gold for pyrite.** The assay at the lift is gone (§4.3). Gold now comes from selling stones, commissions, first-conquest purses and the daily dig.
- **Gold on buttons.** Every button that costs or pays gold shows it the same way: the coin, then the number, in a small dark tag at the button's right end (`DeepUi.priced`, `DeepUi.price_chip`), and never the word "gold". A button carrying the coin is never filled with the accent yellow, which the coin would melt into: Descend is green, Crack it, Read it and the Wheel and Oven blue, and selling a lavender of its own (`DeepUi.TRADE`). Sentences and tooltips still say "gold".
- **The daily dig's map** shows how far today's digs have gone (`DeepEconomy.daily_reach`, kept in `profile.dig.mines` and topped up by each attempt): the strata reached are lit with their depth tracks, the Quarry always as the start, and the rest of the route is dark and marked Ahead with a dashed shaft. Its bottoms carry plain crowns, without the Birthstones of the delvers they let out, since the seam lets nobody out.

### Phases 0–3, October 7, 2026

- **Turning in always beats selling.** A commission pays its price, or a quarter more than the stone handed in would sell for if that is more (`DeepEconomy.payout`). Its card says "N gold or more"; the Turn it in button says exactly what this stone fetches.
- **A first stone of its skill** gets the "A new skill!" fanfare at the end of its appraisal, a star on its tray tile and a "New skill" heading on the loupe table. Its choices are Into the vault, Turn it in (when a commission wants it) and Decide later. It is never offered for sale, and `decide_tray` still keeps it if asked to sell. "Appraise all" opens the table on the first new skill it found.
- **Where things live.** Commissions have their own workshop tab, whose badge counts the requests a tray stone could fill. The Ledger opens directly to records and run history. Sockets are bought on the Lapidaries tab's sockets page: only the next socket is for sale. The fare is on the Descend button ("Descend · 75 gold", "I'm ready · 75 gold" for a guest); insurance is a toggle in the same card that stays on until turned off. The trip card's carat line also says the starting purse; its tooltip explains the fare and the temporary stones.
- **Co-op.** Each lobby member tells the host their gold, insurance and open sockets; Descend waits until everyone can pay and names who cannot. Each machine bills its own profile once per run (`profile.charged_run`), when the run first reaches it at the shaft head, so a run resumed from a checkpoint or joined late is never billed twice. The session version is now 0.3.0.
- **Temporary stones** are rolled from a stream of their own (`temps`), so they never shift the rest of a seed. Same-color sockets are offered three different skills where the mine holds them. With no shaft head (`boons: false`) the first of each three is set. At the end of the run they leave quietly: they are not counted among the shattered losses.
- **Loopholes closed:** the landing's well and the wishing-well oddity refuse fragile stones; a stone fused in the Crucible with a fragile one comes out fragile (and temporary, if either was). The Echo Chamber was checked and needs nothing: it copies only a skill into a fresh roll, never a stone's carats or quality.
- **The no-profit test** covers phases 0–3: turning in beats selling over 800 rolled stones across four mines, and no purse cashed whole at the assayer is worth its fare.

### The workshop rework, October 12, 2026

From a review page of mockups and options, marked over three rounds:

- **Where things live.** The workshop has four tabs, opened with 1 to 4: **Descend** (the mines as a cross-section, with Expedition or Daily dig as a switch beside it, who goes down, and the Descend button that names the delver and the fare), **Delvers** (each delver's dossier and sockets; editing a delver's sockets also picks them to go down), **Vault** (the one page that scrolls; grid or list, one row of sorts, filters and a search; Cut pips, Clarity marks and the carat on every tile; new stones glow until looked at) and **Market** (§3.6). The player's chip opens a profile page: the five best stones as a showcase the party can see, the records, each mine's progress and the runs. Lapidaries are called delvers, and the sixth mine is **The Hollow**.
- **Coming home.** With stones on the tray the workshop waits behind a bench of its own: the tray down the left, the stone being looked at in the middle, read there under the loupe when paid for, the kept one of its skill on the right once it is known. Nothing opens until every stone is kept, sold or turned in; a player who cannot pay to read a stone sells it rough. Stones left on the tray later (Decide later) wait in the vault's Unappraised view.
- **Pips.** A tab carries a count of what is waiting there (tray stones, commissions ready, new stones) or a dot for something new since it was looked at.
- **The party.** Choosing another mine no longer takes a guest's ready mark away; a guest who cannot pay that mine's fare stays ready but shows a coin, and Descend waits until the host picks a mine everyone can pay for.
- **The run's tally (October 23, 2026).** A run ends on three tabs over the room before the haul is appraised. *Your run* is the tally the sim keeps on each player through every fight (`DeepBattle.fresh_stats`, carried by the fighter and taken back when a fight settles): six totals with what each one cost (damage dealt and overkill, block gained and damage blocked, healed and overhealed, pyrite dug and spent, enemies slain with Wardens apart, debuffs applied by kind), the highlights (biggest hit by one gem's firing with the gem, the creature and the depth; best turn; best hand; taken, falls and revives; buffs given), the Crown Jewel (the stone on the rail at the end with the most points: damage, block and healing as they are, a debuff stack three, a pyrite two) and the way down. *Party*, in a party of two or more, is every delver side by side with a crown on each stat they led, the MVP by points (plus fifty a revive and ten a kill) crowned on their portrait, the party's totals, and one chart, a row a stat and a bar a player, each row its own scale; hovering a delver picks out their bars; a delver who left is greyed with the depth they left at. *Haul* is the lift card as it was. Numbers count up the first time a tab is seen and the music plays once. Poison and Burn ticks, and the kills they make, belong to whoever put the last stacks on (`stacked_by` on the creature). The tally comes home in the run's history entry (`stats`, and `party` for everyone). Nothing is logged blow by blow.
- **The lift.** Setting out, the screen becomes the shaft for a moment and the cage drops past the strata to the mine; coming home it rises to the workshop.

### Phases 4–6, October 10, 2026

- **Prices.** A Geode's odds (its skills and their shares, its grades from 400 sampled stones, its average worth) are worked out once a session per recipe (`DeepEconomy.geode_odds`), and its price comes from that worth. The floors sit just under the 1.75× rule, so the rule sets the prices; only the Rift, whose stones are a little lighter than the Geode's, sits on its floor.
- **The drum** is `view/gems/geode.gd`: a CanvasLayer over everything, opaque so the shelf behind (which already shows the Geode open and its stone named) gives nothing away. It has its own sounds in `sound_bank.gd`: the lever, a tick a tooth, the stop, the crack, the jackpot and the contract's seal. The rock is drawn low-poly like the stones, and the shelf shows a bought Geode as its two halves face up, a faceted bowl of crystal in each.
- **Contracts.** The new stone is rolled in a stream seeded by the profile, the new id and the five refs, so the same five always make the same stone. A vault stone on the bench is named under it in red, and the Sign button asks twice before it gives a kept skill up; every loadout that set it lets it go. The ledger counts contracts and cracked Geodes.
- **The daily dig.** The Map's side column has three views: Expedition, Daily and Party. For the host, Expedition and Daily are the choice of what the party goes down; a guest's column follows the host. The Daily view shows the day's four cards, how it is scored and paid, the player's best today and the time left, and what it lends the party (lapidary, rail, Birthstone). Starting a dig says in a toast whether it is the first today or what score to beat. Down the mine the strip carries the day's cards as marks and the Grubstake page a banner of them. The end of the run shows the score (stones' worth plus pyrite), the gold it is worth, and what this run pays after the day's best, counted out.
- **Where the cards live** (reworked version):
  - `mine_of` changes the rock and the chart's room weights (luck, carat band, a held-back color, clarity and inclusion rules, Void's weight, stones read as found, motherlodes, elites, oddities, the rooms Midas closes); `DeepForge.roll_stone` reads `clarity_rule`, `inclusion_bias` and `read_on_find` from the mine it is handed.
  - `_dress_for_the_day` sets health, pyrite, dice (size, pattern, etched faces, material, the extra die, the wild face), Birthstone, socket colors and the run's flags (`run_mods`: Steady Hands, Shaky Hands, Short-Handed, Second Wind).
  - `_chart` builds One Road's single path and places Altar Lights' altars.
  - `_start_fight` and `_dress_the_fight` scale creatures (Hard Rock, Sharp Claws, Warden's Wrath), add or merge them (Swarms, Lone Beasts), stun them (Torpor) and plate the party (Plated); `_settle_fight` doubles Midas' pyrite, reads Big Game's elite drops, spends Second Wind, trims Plated's max health and locks Cursed Run's faces.
  - `_dress_the_landing` takes Toll Gates' cut, heals Glass Lungs and turns Restless Rock's rail; `_respite` refuses rest on No Bench and runs Night Terrors' rest; `_choose_at_landing` keeps Last Lift's rule; `lift_cost`, the stall prices and the sale price read the winch and stall cards; `_enter` takes Bleeding's toll.
  - `DeepBattle._begin_turn` reads `short_handed` and `reroll_shift`, and `_lifeline` marks a rescue so Second Wind is spent once.
- **A first-pass call to revisit:** the score's rate and knee (0.5 and 1000) are a first guess; Quarry lent stones are weaker than the first version's, which rolled in deeper mines.
- **Two holes closed on the way.** A stall or Collector sale of a lent stone does not count as pyrite earned down there, so the assayer never buys it; and an extra-rerolls boon adds to rerolls already granted instead of replacing them.
- **A party of four on the run's strip.** With three or four players the strip's names are cut short (each says itself in full on hover) and its bars and gaps narrow; four long names used to push it past the screen's edge.
- **Balance browser.** The Gold page has the Geode columns (a mine's Geode's stone and its price, sampled the way the game rolls them) and the contract fee ladder.
