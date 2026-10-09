# Gold at home

This is the plan for giving gold uses outside a run and new ways to earn it. When a part ships, its marker turns green, its row in §6 gets a "Built" date, and the README is updated. §11 lists what the build settled that this plan had left open.

**Key:** 🟢 built · 🟡 partly built · 🔵 planned, in the build order · ⚪ idea for later, not scheduled · ⛔ considered and left out

## At a glance

| | Feature | Section | Phase |
| --- | --- | --- | --- |
| 🟢 | Mine fares | §3.1 | 3, built October 7, 2026 |
| 🟢 | Salvage insurance | §3.2 | 3, built October 7, 2026 |
| 🟢 | Socket unlocks, and temporary stones below the Quarry | §3.5, §3.1 | 3, built October 7, 2026 |
| 🟢 | Commissions, and the "New skill" choice | §4.1 | 2, built October 7, 2026 |
| 🟢 | The assay at the lift | §4.3 | 1, built October 7, 2026 |
| 🟢 | First-conquest purse | §4.4 | 1, built October 7, 2026 |
| 🟢 | Groundwork: economy code, save upgrade, daily turnover, Gold page in the balance browser | §5, §6 | 0, built October 7, 2026 |
| 🟡 | The no-profit test: two of its four checks exist; the Geode and contract checks wait for those features | §7 | grows with 4 and 5 |
| 🔵 | The shop: Geodes | §3.3 | 4, next |
| 🔵 | Contracts (trade-ups) | §3.4 | 5 |
| 🔵 | The daily dig | §4.2 | 6 |
| ⚪ | Birthstone upgrades | §8.1 | not scheduled |
| ⚪ | Shop services: the Wheel and the Oven | §8.2 | not scheduled |
| ⛔ | Everything in §9 | §9 | — |

## 1. Where gold stood before this plan

| | |
| --- | --- |
| **Earned by** | Selling stones on the Appraise tab (full worth if appraised, the size-class price if not), and the stone sold when a new one of its skill replaces it in the vault (`DeepProfile.keep`). |
| **Spent on** | The workshop appraisal fee (`DeepProfile.appraisal_fee`: twice the rough price, at least 12). |
| **Not converted** | Pyrite. Whatever a player carries when the run ends is lost. |

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

| Mine | Seeps | Glass Veins | Warrens | Furnace | Geode | Rift |
| --- | --- | --- | --- | --- | --- | --- |
| `fare_gold` | 60 | 100 | 140 | 180 | 225 | 275 |

**Temporary stones for the empty sockets.** At the shaft head of a run that starts below the Quarry, every socket with no stone of its own (one the lapidary has not unlocked, or one unlocked and left empty, so that buying a socket never makes a deep run weaker) is offered a **pick of three temporary stones**:

- **Color:** each pick matches its socket's color. An Any socket offers three different colors.
- **One screen:** all the picks sit on one screen, a row of three cards per empty socket (two or three rows), before the Grubstake. The existing "Pick of Three" stake already draws this kind of row.
- **Quality:** appraised, never Void. Rolled at the bottom of the mine's luck (`temporary_depth` 20) with `temporary_luck` (4) on top, and drawn again, a little kinder each time, until it is at least `temporary_min_tier` (Precious) or a dozen draws have been made. Buffed October 8, 2026: at depth 4 they came out Rough four times in five, which made bringing the vault's own stones the only sensible choice.
- **Temporary means fragile:** the stone carries the same `fragile` flag as the "A Fragile Find" stake, shown with the Fragile mark. It cannot be sold, kept, turned in or thrown down a well, and it shatters when the run ends, however it ends.
- **Replaceable:** a stone found during the run can take its socket. The temporary stone moves to the bag and still shatters at the end.
- **Dice offered for the deep (October 9, 2026, replacing the dice worked for the deep of October 8):** after the temporary stones, each die in a player's bowl is offered three dice to swap it for, one die at a time, or kept as it is. The left one is its size or smaller, the middle one its size and the right one its size or bigger; every one differs from it, the middle one always in its pattern, an etching or its material. A mine's `start_dice_offer` tunes it: `steps` are the chances, in percent, of a side die being at least one, two and three sizes off (Seeps 30/1/0 up to the Geode 99/30/1), and `variation` the chance of each extra pattern, etching or material (Seeps 15% up to the Geode 50%). Like all work on a die down the mine, a swap stays there.
- **Not when pushing on:** a party walking into the next mine already has its rail. The Quarry gets none, and the daily dig lends a full rail instead.
- **Why unlock sockets, then:** temporary stones are good (Precious, at the mine's usual carat) but random: three to choose from, of skills the rock picked, and gone when the run ends. An unlocked socket carries the stone the player chose from the vault, built around. That difference is what socket unlocks sell.

**Closing two existing loopholes (needed before this ships, and worth fixing now):**
- **The well:** the wishing well accepts fragile stones (`DeepDescent.can_wish` checks only Birthstones and Knots), so a temporary stone can be turned into a permanent reward. It should refuse them.
- **The Crucible:** fusing a fragile stone with a permanent one keeps whichever survives the 50% draw. If the permanent one survives, it absorbs the fragile one's carats and comes home. A fused stone should be fragile if either input was.

Both loopholes already exist with "A Fragile Find", the Grubstake's depth-20 fragile stone (from the bottom of a mine that ends sooner, since October 9, 2026).

### 🟢 3.2 Salvage insurance

An optional purchase on the Map's trip panel: a **checkbox the profile remembers**, so a player sets it once and it applies to every run until turned off. The Descend button shows the total (fare plus insurance), and the gold is taken at departure.

- **What it does:** if the run falls or is abandoned, every salvage die rolls twice and keeps the better result.
- **Price:** `insurance_gold` per mine, starting at 15 in the Quarry and a quarter of the fare below it (15, 25, 35, 45, 55, 70). It pays for itself only on a bad run.

### 🔵 3.3 The shop: Geodes (phase 4)

The Shop is a new home tab with two views: **Geodes** (this section) and **Contracts** (§3.4).

**The shelf.** Three Geodes a day, each bought at most once, all from mines the player has unlocked:

| Theme | What it can hold |
| --- | --- |
| **Mine Geode** | That mine's skill pool, weighted the way the mine weights it. |
| **Color Geode** | One color, from the deepest mine the player has unlocked. |
| **Featured Geode** | A hand-written set of 6–8 skills that changes every week (content: `geodes.featured`). |

Each Geode lists its possible skills with their odds, and its odds by grade tier (measured by simulation, not written by hand).

**What is inside.** A Geode stone is better than a mine stone:

- **Carat:** rolled in a raised band, from the mine's usual top up to **its cap + 2**. A Quarry Geode can hold an 8 or 9, where the Quarry itself never gives more than 7.
- **Cut and Clarity:** rolled at the mine's luck plus `geode_luck` (a new bonus, passed through the existing `bonus` argument of `DeepForge.roll_stone`).
- **No Void.** A fragile stone would shatter at home. A roll that comes up Void is rolled again.
- **Opals:** a 1% chance (`geode_opal_pct`) of a Mythic Opal in any Geode.
- **Rolled in advance.** The stone is rolled when the day's shelf is rolled and saved with it, so reloading cannot change it. Cracking it only shows what was already there.

**The crack, not a reel.** A CS-style reel works because skins are instantly recognisable thumbnails. Stone thumbnails are not. Use the strike from veins instead:

1. The Geode sits on the bench. The player strikes it, three blows, with the vein pick.
2. Each blow opens a crack, and **light leaks out in the color of the stone's grade tier** (Rough, Fine, Precious, Exquisite, Peerless), brighter with each blow. This is the "rarity flash" moment from CS, without a reel.
3. The last blow splits the Geode into two halves lined with crystal in the stone's color, and the stone rises out.
4. The normal appraisal ceremony (`view/gems/appraisal.gd`) reads it out, and it goes to the tray for the usual keep, sell or turn-in.

A click or Space skips to the end, as the appraisal already allows.

**Price:** `geode_gold` per mine, set so the price is at least 1.5× the average sale value of what the Geode holds (§7 checks it). Starting point: about three times what a typical stone from that mine sells for.

### 🔵 3.4 Contracts, trade-ups (phase 5)

Five stones of one grade tier go in, and one stone of the next tier comes out. It works like a CS trade-up contract.

| Rule | Detail |
| --- | --- |
| Inputs | **5 appraised stones of the same grade tier**: Rough, Fine, Precious or Exquisite. They can come from the tray or the vault. No Birthstones, fragile stones or Opals. |
| Output tier | Always the next tier up. There is no fail state. The risk is giving up five known stones for one unknown. |
| Output color | Weighted by the inputs: 3 Red and 2 Blue gives 60% Red and 40% Blue. |
| Output mine | The deepest mine among the inputs. The skill comes from that mine's pool, filtered to the drawn color. |
| Output carat | The inputs' average carat, rounded, capped at that mine's cap. This is the lever players control, like float in CS. Carat is 45 of the 100 grade points, so a big, badly cut stone becomes worth keeping for a contract. |
| Cut, Clarity, inclusions | Rolled at that mine's luck, rolled again until the grade lands in the target tier, as `DeepBoons._raw_pick` already does for `min_tier`. |
| Impossible contracts | If the average carat is too low for the next tier even with a perfect Cut and Clarity, the contract cannot be signed, and the screen says why. |
| Fee | 20 / 60 / 150 / 400 gold for Rough / Fine / Precious / Exquisite inputs. |

**Vault stones as inputs.** A vault stone can go in, with a warning that the skill becomes unowned (still seen). This is how a player uses a stone they are about to replace: put the old one into a contract, then keep the new one.

**The screen.** Five slots, a paged picker of eligible stones filtered to the tier of the first stone placed, and a panel with the color odds, the expected carat, the output mine, the fee and the Sign button. Signing plays a short fusing animation, then the normal appraisal ceremony for the new stone.

**Why we keep one stone per skill.** Contracts do not need duplicates. They need five stones of one *tier*, which can be any skills. The tray already keeps stones between runs and pages them, so it is the natural place for contract material to wait. Lifting the one-per-skill rule would mean:

- loadouts pointing at individual stones instead of skills (`DeepProfile.set_rail` stores a skill key today);
- a vault grid that can show several stones per skill;
- losing the keep-one-or-the-other decision, which is the core of the home loop and its main source of gold.

That is a large change with no gain for Contracts. Revisit it only if the tray becomes a long-term storage problem; a tray cap would be the first answer.

### 🟢 3.5 Socket unlocks

A lapidary's rail is filled from the vault only as far as that lapidary's **unlocked sockets** reach, in every mine. Everyone starts with the first three. The rest are bought with gold, **permanently and per lapidary**, so gold also says which lapidaries a player has invested in.

| Socket | 4th | 5th | 6th (the one lapidary with six) |
| --- | --- | --- | --- |
| `socket_unlock_gold` (starting values) | 300 | 1200 | 4800 |

- **Prices climb steeply** (×4 a socket), so the last socket is a long-term goal.
- **Only the pre-run fill changes.** A locked socket still takes stones found during a run, as Quarry sockets 4–6 do today.
- **Where:** the Lapidaries tab already draws locked sockets with a lock. A locked socket shows its price and an Unlock button, and once unlocked it accepts a stone from the vault like the first three.
- **Replaces** the per-mine `loadout_sockets`: deeper mines fill 3 plus whatever is unlocked, like the Quarry. The rule "the loadout lets a stone past the third socket once any deeper mine is open" goes away.
- **Balance watch:** deeper starts lean on temporary stones (§3.1) for the sockets a player has not bought. If they feel too weak, raise their luck before touching the purse or creature health.
- **The daily dig is unaffected:** it lends a full rail (§4.2).
- **Co-op:** each player's unlocks are their own. A guest's rail arrives filled as far as their own lapidary allows.

## 4. Earning gold

### 🟢 4.1 Commissions

**What a commission asks for.** Every commission names **one skill**. Some also add **one requirement from the four C's**:

| Requirement | Example |
| --- | --- |
| Carat | "8 carats or more" (always within the band of a mine the player can reach) |
| Cut | "Good cut or better" |
| Clarity | "Pristine or better", or "with at least one inclusion" |

- Only stones count. There are no depth or fight goals.
- The commission card shows the skill's emblem and name, and a tooltip saying **where it is found**: its batch mine and every mine below it (`DeepForge.batch_tiers`).
- Skills are drawn from the pools of the mines the player has unlocked, **including skills the player has never seen**: the card names the skill and where it is found, which doubles as a hint. Being named on a commission does not count as seen in the vault; the player still has to find one. Mythic Opals are excluded.

**Slots and refresh.**
- There are three slots. At 00:00 UTC every unfilled commission is replaced and every filled slot gets a new one.
- One free reroll a day. After that a reroll costs gold, starting at 10 and rising by 10 each time, which is a small extra gold sink.

**Payout:** 2.5× the sale value of the weakest stone that would meet every requirement, rounded to 5. Turning a stone in must always beat selling it.

**Turning in.** The Appraise tab gains a **Turn in** button beside Keep and Sell whenever a tray stone meets a commission. Turning in pays the gold and removes the stone. Its skill stays seen.

**The first stone of a skill.** The automatic keep (`DeepProfile.auto_keep`, called on homecoming and from the home screen) is removed. Instead:

- Every first stone of a skill opens a **"New skill" popup** with fanfare: its own sound, a stronger beam than the ordinary grade reveal, and the vault slot for that skill lighting up from grey to color.
- The buttons are **Keep**, plus **Turn in** when a commission wants it. **Sell is never offered**, so the rule "the first stone of a skill is never sold" still holds.
- A raw first stone is appraised first, as now. Stones read in the mine get the popup on homecoming, one after another.
- A player may also leave a first stone on the tray, for example to put it into a contract.

**Optional extra:** when a stone is appraised down the mine and it meets a commission, mark it with a small commission icon.

### 🔵 4.2 The daily dig (phase 6)

One global seeded run per UTC day, harder than a normal run, in the spirit of Slay the Spire's daily climb.

- **Global seed:** `hash("deep-cut-daily", UTC date, content version)`. Every player on the same build gets the same run with no server. The content version is included so two builds never claim the same daily with different rules. The same-build seed also makes a Steam leaderboard possible later.
- **What the seed decides:**
  - the mine, drawn from the Quarry to the Warrens (`daily_mines`);
  - the lapidary;
  - a **lent rail**: all six sockets filled with stones rolled for that mine, which go back when the run ends. The player's own loadout is never used, so everyone faces the same run and a new player is not behind;
  - the stake offers;
  - **two hazards and one blessing** from the list below.
- **Who can play:** anyone who has beaten the Quarry once.
- **One rewarded attempt a day.** The first start counts, and an abandoned attempt counts. Replays are allowed for fun, with no gold and no haul.
- **Rewards (first attempt only):**
  - gold for depth reached: `daily_gold_per_depth` × depth × the mine's tier, starting at 10;
  - a clear bonus for beating the final boss: 200 × tier;
  - the haul comes home as usual.
- **Co-op:** the party plays the same seed. Each player is rewarded only if it is their first attempt of the day. A player who has already played can join for no reward.

**Daily modifiers** (content: `daily_modifiers`). The list starts with these. Most reuse existing mechanics:

| Hazards | Blessings |
| --- | --- |
| **Short Wick:** the lantern shows one depth ahead instead of two | **Rich Seams:** +1 luck on every stone |
| **Hard Rock:** creatures have +25% health | **Golden Faces:** every die has one golden face |
| **Bad Air:** start at 75% health | **Deep Pockets:** start with double pyrite |
| **Tight Winch:** the winch charges double | **Generous Hoards:** Warden hoards offer four pedestals |
| **Blank Faces:** every die has one blank face | **Steady Hands:** +1 reroll every turn until the first landing |
| **Closed Stalls:** no merchants | **Bright Well:** wishing wells weigh offerings half again as much |
| **Glass Bowl:** every die is Glass (breaks one throw in ten) | |
| **Brittle Picks:** vein strikes cost health twice as soon | |

### 🟢 4.3 The assay at the lift

When a run ends by extraction or conquest, each player's remaining pyrite is converted to gold. A fall or an abandoned run converts nothing.

- **Rate:** 5 pyrite to 1 gold (`assay_rate`). This is deliberately worse than the 2-to-1 the fare pays for the starting purse.
- **Only earned pyrite counts.** The amount converted is the lesser of what the player is carrying and the pyrite they earned this run, so the starting purse of a deeper mine can never be cashed out. Built as a tally of its own, `stats.earned` (`DeepEconomy.earned`), written at every gain but the starting purse: fights (which already fold in golden and Fool's Gold faces and every pyrite gem), veins, stall sales, the Collector, oddities that pay pyrite, the well and stakes. `stats.ore` stays what the summary calls "Pyrite dug".
- **Animation:** on arriving at the workshop and **before the tray and appraisal**, the player's pyrite pours into the assayer's scales and a gold counter ticks up. Each player sees only their own. It is skippable.

### 🟢 4.4 First-conquest purse

The first time a player beats a mine's final boss, they receive a one-off purse: `first_conquest_gold` per mine. It is paid when the mine record's `boss` flag first turns true. The Rift has no bottom and no purse.

| Mine | Quarry | Seeps | Glass Veins | Warrens | Furnace | Geode |
| --- | --- | --- | --- | --- | --- | --- |
| Gold | 150 | 250 | 400 | 600 | 900 | 1300 |

## 🟡 5. Content and save data

**New fields on each mine** (`mines.*`):
- 🟢 `fare_gold`, `insurance_gold`, `first_conquest_gold`. `loadout_sockets` is removed; every mine uses `starting_rail_cap` (3) plus the lapidary's unlocks.
- 🔵 `geode_gold` (phase 4).

**New constants:**
- 🟢 `assay_rate` (5), `socket_unlock_gold` ([300, 1200, 4800]), `temporary_depth` (20), `temporary_luck` (4), `temporary_min_tier` (PRECIOUS), `commission_slots` (3), `commission_payout_mult` (2.5), `commission_reroll_gold` (10) and `commission_reroll_step` (10), `commission_requirement_pct` (50).
- 🔵 `geode_luck`, `geode_carat_over_cap` (2), `geode_opal_pct` (phase 4); `contract_inputs` (5), `contract_fee` (by tier) (phase 5); `daily_mines`, `daily_gold_per_depth`, `daily_clear_gold` (phase 6).

**New sections:** 🔵 `geodes` (featured sets by week, phase 4), `daily_modifiers` (phase 6).

**Profile:** 🟢 schema 3, with an upgrade (`DeepProfile.upgrade`) that leaves every old field alone.
- 🟡 `daily`: `{date, commissions: [3], rerolls, seq}` is built; `shelf: [3 Geodes with their stones]` (phase 4) and `dig: {played, depth, cleared}` (phase 6) are not. It is rebuilt whenever `date` is not today (UTC).
- 🟢 `outfit`: `{insure: bool}`.
- 🟢 `characters.<key>.sockets`: how many sockets that lapidary has unlocked (3 to start).
- 🟢 `conquest_paid`: the mines whose first-conquest purse has been paid.
- 🟢 `charged_run`: the last run this profile paid its fare for, so no run is billed twice.

All date logic takes the date as an argument, so tests can set any day.

## 6. Build order

Each phase ships on its own and leaves the game playable.

| Phase | What | Where | Tests |
| --- | --- | --- | --- |
| 🟢 **0. Groundwork** (built October 7, 2026) | The UTC date helper, profile schema 3 and its migration, content fields and constants. A new `sim/economy.gd` holds every price and every daily roll, pure and headless. A data-browser page shows the expected value of a stone, Geode and contract by mine. | `sim/economy.gd`, `sim/profile.gd`, `content/deep_cut.json`, `tools/data-browser/` | Migration; date turnover; content validation of the new fields |
| 🟢 **1. Assay and first-conquest purse** (built October 7, 2026) | The conversion on homecoming, with its animation before the tray. The one-off purse. | `sim/profile.gd` (homecoming), `view/home/home_screen.gd` | Earned-pyrite cap; fall pays nothing; purse paid once |
| 🟢 **2. Commissions** (built October 7, 2026) | The three slots on the Ledger, the Turn in button, the "New skill" popup in place of `auto_keep`, rerolls. | `sim/economy.gd`, `sim/profile.gd`, `view/home/home_screen.gd`, `view/gems/appraisal.gd`, `view/audio/sound_bank.gd` | Requirement matching; first stone never sellable; payout always beats sale |
| 🟢 **3. Fares, insurance and sockets** (built October 7, 2026) | Fares, the insurance checkbox, the Descend total, salvage keeping the better of two rolls, co-op payment and refund. Socket unlocks on the Lapidaries tab, every mine filling only unlocked sockets, and the temporary-stone picks at the shaft head. These ship together, so deeper starts never lose their full rail before players can buy sockets back. | `view/home/home_screen.gd` (trip panel, the "every socket filled" line, the loadout), `sim/descent.gd` (`new_run`, `loadout_sockets`, salvage, `can_wish`), `sim/oddities.gd` (fuse), `sim/boons.gd` (the pick row), `sim/profile.gd` (`starting_rail_cap`, `widest_rail_cap`), `content/deep_cut.json`, `docs/MINES.md`, `net/` | Fare charged once per player; push-on free; insured salvage; rail filled to exactly the unlocked count in every mine; unlocks are per lapidary and permanent; one temporary pick per empty socket, in its color; temporary stones shatter, cannot be wished, and make a fused stone fragile |
| 🔵 **4. Shop: Geodes** (next) | The Shop tab, the daily shelf, the raised carat band, the crack ceremony. | `sim/forge.gd` (band override), `sim/economy.gd`, new `view/gems/geode.gd` | No Void; carat within the raised band; shelf stable across reloads |
| 🔵 **5. Contracts** | The Contracts view, input rules, output roll, feasibility check, fusing animation. | `sim/economy.gd`, `view/home/home_screen.gd` | Color weighting; carat average and cap; tier always next; impossible contracts refused |
| 🔵 **6. Daily dig** | Global seed, modifiers, lent rail, eligibility, rewards, co-op rules. | `sim/economy.gd`, `sim/descent.gd`, `view/home/home_screen.gd`, `net/` | Same date and build gives the same run; one rewarded attempt; lent rail never reaches the vault |

## 🟡 7. The no-profit test

`tests/test_economy.gd` simulates thousands of rolls per mine and fails if any of these makes money on average:

- 🔵 buying a Geode and selling what is inside (phase 4);
- 🔵 buying a Geode, appraising nothing further, and putting its stone into a contract with four others bought the same way, then selling the output (phase 5);
- 🟢 the fare against cashing out the starting purse through the assay (blocked by the earned-pyrite cap; the test proves it);
- 🟢 turning in against selling (this one must always favour turning in; it is the only intended profit).

The test reads prices from content, so retuning a number can never quietly open a loop.

## ⚪ 8. Later: ideas for a future pass

None of this is in the build order.

### ⚪ 8.1 Birthstone upgrades

Like socket unlocks (§3.5), these grow one lapidary permanently. Rule 1 still holds: none of this touches a vault stone.

- **Raise it:** spend gold to improve a lapidary's Birthstone along one axis, for example its multiplier per tier, or an easier first tier. A few steps, each dearer than the last.
- **Swap it:** each lapidary gets one or two **alternative Birthstones**, bought once with gold, and the player picks which one to bring before a run. An alternative reads a different hand or pays out differently, so it changes how the lapidary plays rather than only making them stronger. Example shape: Ardor's Rally reads sets (pair, triple, four and five of a kind); an alternative could read straights or a high total instead, so Ardor stops chasing matches.
- Each alternative needs its own tiers, Birthstone face and tests in `tests/test_battle.gd`, like the current six (`docs/CHARACTERS.md`). That is the main cost; the gold side is small.

**Open for that pass:** whether upgrades are bought on the Lapidaries tab (likely, next to the dossier and the socket unlocks), and how a guest's Birthstone choice shows to the rest of the party.

### ⚪ 8.2 Shop services: the Wheel and the Oven

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

| Idea | Why not, for now |
| --- | --- |
| A fee for every run, or a free run a day | Blocks co-op parties, traps broke players, punishes regular players. |
| Starting a run past a beaten Warden | A run always starts at the top of a mine; the fare covers deeper starts. |
| Dice in the shop | Each lapidary's dice are their own, and the range of bowls makes a fair shop hard. |
| Grubstake add-ons | Too dull for the gold they would cost. |
| Bench upgrades | Shared upgrades are hard to balance. Replaced by per-lapidary socket unlocks (§3.5) and, later, Birthstone upgrades (§8.1). |
| Paying for a fourth stone on each run | Annoying to buy every time. Replaced by permanent socket unlocks per lapidary (§3.5). |
| A second vault slot per skill | Loadouts and the vault are built around one stone per skill (§3.4). |
| A CS-style reel for Geodes | Stone thumbnails are not readable enough at reel speed; the crack shows the same moment better. |
| A guaranteed recut or re-fire for gold | Breaks rule 1. A reroll gamble with a climbing price is a candidate (§8.2). |
| Depth or fight goals as commissions | Commissions are stones only, so they stay tied to the appraisal. |

## 10. Decisions

Settled October 6, 2026:

1. **The daily dig lends its rail**, rolled from the seed. The player's own loadout is not used.
2. **Commissions may name skills the player has never seen.**
3. **Geodes have a 1% chance of a Mythic Opal.**
4. **Deeper mines stop filling every socket.** Every mine fills the first three plus the lapidary's unlocked sockets, bought with gold (§3.5).
5. **Deeper starts fill the remaining sockets with temporary stones,** one pick of three per empty socket, which shatter when the run ends (§3.1).

No questions are open for phases 0–6. The later ideas in §8 carry their own open questions.

## 🟢 11. What the build settled (phases 0–3, October 7, 2026)

- **Turning in always beats selling.** A commission pays its price, or a quarter more than the stone handed in would sell for if that is more (`DeepEconomy.payout`). Its card says "N gold or more"; the Turn it in button says exactly what this stone fetches.
- **A first stone of its skill** gets the "A new skill!" fanfare at the end of its appraisal, a star on its tray tile and a "New skill" heading on the loupe table. Its choices are Into the vault, Turn it in (when a commission wants it) and Decide later. It is never offered for sale, and `decide_tray` still keeps it if asked to sell. "Appraise all" opens the table on the first new skill it found.
- **Where things live.** Commissions have their own workshop tab, whose badge counts the requests a tray stone could fill. The Ledger opens directly to records and run history. Sockets are bought on the Lapidaries tab's sockets page: only the next socket is for sale. The fare is on the Descend button ("Descend · 75 gold", "I'm ready · 75 gold" for a guest); insurance is a toggle in the same card that stays on until turned off. The trip card's carat line also says the starting purse; its tooltip explains the fare and the temporary stones.
- **Co-op.** Each lobby member tells the host their gold, insurance and open sockets; Descend waits until everyone can pay and names who cannot. Each machine bills its own profile once per run (`profile.charged_run`), when the run first reaches it at the shaft head, so a run resumed from a checkpoint or joined late is never billed twice. The session version is now 0.3.0.
- **Temporary stones** are rolled from a stream of their own (`temps`), so they never shift the rest of a seed. Same-color sockets are offered three different skills where the mine holds them. With no shaft head (`boons: false`) the first of each three is set. At the end of the run they leave quietly: they are not counted among the shattered losses.
- **Loopholes closed:** the landing's well and the wishing-well oddity refuse fragile stones; a stone fused in the Crucible with a fragile one comes out fragile (and temporary, if either was). The Echo Chamber was checked and needs nothing: it copies only a skill into a fresh roll, never a stone's carats or quality.
- **The no-profit test** covers phases 0–3: turning in beats selling over 800 rolled stones across four mines, and no purse cashed whole at the assayer is worth its fare. The Geode and contract chains join it with phases 4 and 5, as do the Gold page's Geode and Contract columns in the balance browser (`tools/data-browser`, The workshop → Gold).
