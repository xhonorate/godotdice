# Hazard tiers

Reaching the Rift is the end of the game as first written. The Hazard ladder is what comes after it, like Ascension in Slay the Spire: twenty tiers, each carrying every hazard below it and one more. Designed with the owner on October 14, 2026 in the "Deep Cut Hazard Ladder" review page; the order and the numbers below are the approved ones.

Everything is data in `content/deep_cut.json` under `hazard_tiers` (in order: tier N carries the first N) and five `hazard_*` constants. A hazard's numbers are its `params`.

## Unlocking and progress

- Reaching the Rift (opening it by beating the Hollow's final boss) unlocks **Hazard 1**. Reaching the Rift on your highest tier unlocks the next one, up to 20 (`DeepProfile._raise_hazard`). A profile that reached the Rift before the ladder existed is given Hazard 1 on load (`DeepProfile.upgrade`).
- **Every tier keeps its own map** (`profile.hazard.tiers[N].mines`, `DeepProfile.mine_records`). On Hazard 1 and up only the Quarry is open at first; beating a mine's boss on a tier opens the next mine on that tier, with its own deepest floor and crowns. **Hazard 0** is the ordinary map: start in any mine you have opened.
- Lapidaries and first-conquest purses belong to the ordinary map; a tier opens only mines and the next tier.
- The daily dig never counts toward any of this.

## The party

The host picks the tier on the map. The party can only pick a tier **every member has unlocked** (`DeepSession.hazard_cap`); a guest with a lower highest tier pulls the party's tier down when they join. On Hazard 1 and up, every member must also have the party's mine open on that tier (`hazard_blocked`), or the way down stays shut and the Descend panel says who is missing it. Members tell the lobby their `hazard_top` and the mines open on it (`hazard_open`).

## The ladder

A rule that both the day's seam and the tier carry counts twice where it can add up (`DeepDescent.mod_count`): two Cursed Runs lock two faces. Health bonuses add rather than multiply: Hard Rock and Thick Hides together are +45%.

| Tier | Hazard | What it does | Where |
|---|---|---|---|
| 1 | Old Blood | Creatures are bred 10 floors deeper: more health and damage, bigger groups and the next creature band from the first floor. Worst at the top of each mine. | `_start_fight` threat |
| 2 | Cold Start | One fewer reroll on the first turn of every fight. | `run_mods.first_turn_rerolls`, `_begin_turn` |
| 3 | Short Rest | Resting heals 25% instead of 35%. | `rest_amount` |
| 4 | Prowlers | Elites half again as common, and from depth 2 instead of 3. | `mine_of`, `_chart` |
| 5 | Champions | The strongest creature in an elite fight gets a trait: Steadfast, Sturdy, Splits, Spiked (3), Regenerating (4% a turn) or Warded (2). | `_harden_the_fight` |
| 6 | Worn | Everyone starts the run at 85% health. | `_dress_for_the_hazard` |
| 7 | Warden's Pride | Wardens and bosses +20% health and one more Ward. | `_start_fight`, `_harden_the_fight` |
| 8 | Thin Hoards | Hoards have one pedestal fewer, and half as often an opal. | `_offer_hoard` |
| 9 | Early Enrage | Enrage on turn 6, +3 a turn (was 7, +2). | `DeepBattle.enrage_turn` |
| 10 | Bigger Teeth | Every creature's dice one size bigger, for the whole fight. | `dice_upgrade` |
| 11 | Dark Mouths | Up to 2 hidden chambers a floor at 35% each, never a whole floor. | `_chart` |
| 12 | Thick Hides | Creatures +20% health. | `_start_fight` |
| 13 | Lean Seams | Fights drop a stone 45% of the time (was 55%) and pay 15 pyrite (was 20). | fight rewards |
| 14 | Escorts | Every Warden and boss brings a creature from its mine's deepest band, room permitting. | `_deep_creature` |
| 15 | Pressure Cooker | Creature health climbs 7% a floor (was 5%), damage a point every 3 floors (was 4). | `scale.depth_hp`, `scale.damage_every` |
| 16 | Festering Air | All healing received 20% lower, rests included. | `run_mods.heal_cut`, `_heal` |
| 17 | Gauntlet | The floor before every landing is all elites. | `_chart` |
| 18 | Dull Vault | Stones brought from the vault are judged one Cut step lower; finds are not, nor anything the daily dig lends. | gem context `dulled` |
| 19 | Cursed Run | Beating a Warden locks a face on one of your dice (the daily hazard). | fight settle |
| 20 | Crown's Court | The Hollow Crown fights beside one of the Rift's Remembered bosses. | `_start_fight` `court` |

Ideas left on the bench in review: Hard Bargains (merchants a quarter dearer, no promised merchant), Cunning, Short Wick, Narrow Shaft, Hungry Void, Drought.

## Heavier stones

The reward is stones, never gold (gold buys sockets, so a gold bonus would make tiers farmable). Every stone found on a tier records it (`provenance.hazard`), shown in the vault.

- **Luck**: +0.25 a tier (`hazard_luck`).
- **Carat band**: the usual top and the cap both rise by up to `hazard_carats` (7) at Hazard 20, scaled by the mine's tier: all of it in the Hollow and the Rift, a sixth of it in the Quarry (`DeepForge.hazard_carats`). The Rift's cap never passes 24.
- **Pressure**: a stone that reaches the usual top keeps growing a carat at a time toward the cap, each step at 3.25% a tier (`hazard_pressure_pct`), 65% at Hazard 20. Without it nothing reaches the cap, because the band holds the average under the usual top.

Simulated odds in the Hollow's deepest stretch (a copy of `roll_carat`, not the game):

| Tier | Band | Ordinary find | Elite ≥ 20 ct | Elite 24 ct |
|---|---|---|---|---|
| 0 | 12 / 17 | 9.8 | — | — |
| 8 | 15 / 20 | 12.8 | < 0.1% | — |
| 16 | 18 / 23 | 15.9 | 5.1% | — |
| 20 | 19 / 24 | 17.1 | 12.8% | 2.3% |

Caps on Hazard 20: Quarry 8, Seeps 11, Glass Veins 15, Warrens 18, Furnace 21, Hollow 24, Rift 24. The map's carat chips and the expedition's "up to N ct" read the selected tier.

## The daily dig

The daily dig can be played on any unlocked tier. Its gold is multiplied by `1 + tier × hazard_daily_gold` (×2 at Hazard 20; `DeepEconomy.daily_gold`). The day's best is kept as gold paid, so a later dig on a higher tier pays only the difference, the same rule as a deeper one. The carat bounty does not apply on the day's seam: the tier pays in gold there instead.

## The map

The sky over the workshop carries the gauge once Hazard 1 is unlocked (`mine_map.gd` `_draw_hazard_gauge`): a pip for tier 0 and one for every tier, a bigger one every fifth, lit up to the party's tier and locked past the highest. Hovering a pip names what it adds; hovering the label lists everything the tier carries. The strata show that tier's own map and the deep reddens as the tier rises. The Descend button names the tier. Down the mine the run strip shows it, with every hazard on hover. `tools/screenshot.gd -- map_hazard` shoots it.

## Balance changes made with it

- Resting heals 35% (was 30%), so Short Rest takes it to 25%.
- Fights pay 20 pyrite plus the depth (was 6), so Lean Seams takes it to 15. This roughly doubles fight income against the lift fare (`lift_ore_per_depth`, tuned on October 7 to the old income).

## Not done yet

- A balance pass with the bot on each tier, and on the vault: a vault of Rift stones walks through the Quarry on most tiers, so the ladder bites mostly in the deep mines.
- A Rift score to multiply by the tier: the game has no Rift score yet.
- Hazards on summoned creatures: Bigger Teeth, Champions and Warden's Pride touch only what stands at the start of a fight.
