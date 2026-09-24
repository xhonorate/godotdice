# Skill gem catalogue and future work

Updated September 24, 2026 from [content/deep_cut.json](content/deep_cut.json). The current pack contains **66 skill gems: 56 standard gems and 10 Mythic Opals**. The six character Birthstones are separate. All requested gem revisions and the ten additions below are implemented.

| Color | Role | Skills |
| --- | --- | ---: |
| Red | Damage | 11 |
| Blue | Guard | 9 |
| Green | Sustain | 8 |
| Violet | Control | 9 |
| Gold | Fortune | 10 |
| White | The hand | 9 |
| Opal | Every color | 10 |

Each slash-separated ladder runs **Poor / Fair / Good / Fine / Perfect**. Pair and triple thresholds refer to matched face value. “Allies” includes the caster; “weakest ally” means the living ally with the lowest HP percentage. Adjacent enemies are the nearest living neighbors in the displayed row, with the right neighbor preferred for a single adjacent hit.

Formulas are base values before ordinary carat/inclusion scaling. **Flawless also multiplies magnitude by 1.5 and base Resonance gain by 3.** Whole-number status applications normally use proc scaling. Explicit percentages of actual results, prices/refunds, temporary rank upgrades, Glimmer face upgrades, and Thrive’s +1 max HP remain exact. Keyword definitions live in hover tooltips and [Buffs.md](Buffs.md).

## Red — 11 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Strike | Common | Always; reads lowest 1 → lowest 2 → highest 2 → highest 3 → highest 4 dice | Damage equal to the dice it reads. | Also hits an adjacent enemy. |
| Cleave | Common | Pair valued ≥5/4/3/2/1 | Damage twice the pair's value. Deals half damage to adjacent enemies. | Adjacent enemies take the full damage. |
| Crush | Uncommon | Triple valued ≥5/4/3/2/1 | Damage three times the matched value. | The target is stunned. |
| Barrage | Uncommon | Straight of ≥5/4/4/3/3 dice | Deal 4/4/5/5/6 damage for every die in the straight. | Add 1 hit. |
| Overkill | Rare | Total ≥90/85/80/75/70% of hand maximum | Damage equal to your total dice roll. | On a kill, repeat against another enemy. |
| Spall | Common | ≥5/4/3/2/1 distinct values | Damage twice the sum of your two lowest dice. | Three times instead. |
| Ember | Uncommon | At least one die ≤1/1/2/2/3 | 2/3/3/4/4 damage for every low die. | Each low die also leaves a poison. |
| Fury | Rare | ≥5/4/3/2/1 rerolled dice | 4 damage for every die you rerolled this turn. | Increase damage by your missing HP percentage. |
| Crosscut | Uncommon | ≥5/4/3/2/1 odd dice | Deal 3 damage per odd die. | Gain 1 Block per odd die. |
| Detonate | Rare | Pair valued ≥5/4/3/2/1 | Consume all target Poison. Deal 4 damage per stack consumed. | Apply half the consumed Poison to adjacent enemies. |
| Apex | Rare | Individual die ≥20/19/18/17/16 | Deal damage equal to your highest qualifying roll. | Double damage if that roll is exactly 20. |

## Blue — 9 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Guard | Common | Pair valued ≥5/4/3/2/1 | Block equal to the pair's value. | Half as much again to every ally. |
| Bulwark | Uncommon | Total ≤40/45/50/55/60% of hand maximum | Gain Block equal to your total dice roll. | Also gain Retain equal to half that value. |
| Aegis | Uncommon | Straight of ≥5/4/4/3/3 dice | Block to every ally worth 100/100/150/150/200% of the top of the straight. | Give each ally 1 Ward. |
| Bastion | Rare | Full house; triple valued ≥5/4/3/2/1 | Block to every ally equal to both values of the house. | Give each ally 4 Retain. |
| Tempo | Common | ≥5/4/3/2/1 even dice | 2 block for every even die. | 3 for every even die. |
| Anchor | Common | ≥5/4/3/2/1 held dice | 2 block for every die you did not reroll. | Gain 2 Spikes. |
| Riposte | Rare | Always | Damage worth 60/80/100/125/150% of the block you lost since your last turn. | Gain Block equal to 25% of the damage dealt. |
| Shelter | Common | Pair valued ≥5/4/3/2/1 | Give the weakest ally Block equal to twice the pair's value. | Also Cleanse 1 stack. |
| Mortar | Rare | Always | Gain Retain equal to 10/15/20/25/30% of your current Block. | Retain 10 percentage points more. |

## Green — 8 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Mend | Common | Lowest die ≤3/4/5/6/7 | Heal equal to your lowest die roll. | Gain 2 Regeneration. |
| Graft | Uncommon | Two pairs, both valued ≥5/4/3/2/1 | Heal equal to both pair values. | Every ally is healed. |
| Bloom | Common | ≥5/4/3/2/1 odd dice | Heal every ally 1 for each odd die. | Give each ally 1 Charged per odd die. |
| Renewal | Uncommon | Straight of ≥5/4/4/3/3 dice | Heal the top of the straight and Cleanse 1/1/2/2/3 stacks. | Gain 1 Ward. |
| Lifeline | Legendary | Triple valued ≥6/5/4/3/2 | Give each ally Lifeline equal to the matched value. | Lifeline also restores that much Block. |
| Thrive | Rare | Highest die ≥12/11/10/9/8 | Heal 25/35/50/65/80% of your current block. | Permanently gain 1 max HP. |
| Sap | Rare | Three of a kind | Damage worth 60/80/100/125/150% of the healing you did this turn. | And the party is healed half of it. |
| Siphon | Rare | Always | Heal the weakest ally for 20/30/40/50/60% of all enemy Poison. | Heal every ally. |

## Violet — 9 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Hex | Uncommon | At least one die ≥95/90/85/80/70% of its own maximum | Apply 1 Bound. | Also apply 1 Clouded. |
| Venom | Common | Pair valued ≥5/4/3/2/1 | Poison equal to the pair's value. | And half the value in damage. |
| Miasma | Uncommon | ≥5/4/3/2/1 even dice | Apply 2 Poison per even die to every enemy. | Apply 3 Poison per even die. |
| Curse | Rare | At least one 1 | Apply 1 Curse per rolled 1. Reduce enemy max HP by 0/1/2/3/4 per rolled 1. | Deal damage equal to the target's Curse stacks. |
| Shatter | Uncommon | Triple valued ≥5/4/3/2/1 | Remove Block equal to three times the matched value. Deal damage equal to the Block removed. | Remove all Block. |
| Bind | Rare | Two pairs, both valued ≥5/4/3/2/1 | Apply 1 Bound. | Apply 2 Bound. |
| Dread | Legendary | Straight of ≥5/4/4/3/3 dice | Apply 1/1/2/2/3 Dread stacks. | Apply to all enemies. |
| Mist | Uncommon | Pair valued ≥5/4/3/2/1 | Apply 1 Clouded. | Apply to all enemies. |
| Etch | Rare | Pair valued ≥5/4/3/2/1 | Apply 2 Marked. | Apply 1 more Marked. |

## Gold — 10 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Tithe | Common | Pair valued ≥5/4/3/2/1 | Pyrite equal to the pair's value. | Deal damage equal to the Pyrite gained. |
| Jackpot | Rare | Triple valued ≥5/4/3/2/1 | Gain Pyrite equal to the matched value × matched dice count. | Five of a kind pays 5×. |
| Lucky Seven | Uncommon | At least one 7 | Deal 7 damage and gain 1/2/3/4/5 Pyrite per rolled 7. | With at least three 7s, receive the reward 7 times. |
| Wager | Rare | ≥50/45/40/35/30 Pyrite | Spend 50/45/40/35/30 Pyrite to deal your highest roll as damage. On a kill, gain twice the Pyrite spent. | On a kill, gain three times the Pyrite spent. |
| Windfall | Uncommon | Straight of ≥5/4/4/3/3 dice | Add 10/10/15/15/20 loot-quality points for this fight; improves drop chance and generation luck. | Ten points better again. |
| Double Down | Legendary | Pair of 1s | Flip a coin: 35/42/50/58/65% the next gem is doubled, else it does nothing. | Tripled. |
| Prospect | Uncommon | ≥5/4/3/2/1 distinct values | Gain 1 Sparkle. | Two Sparkles. |
| Stake | Rare | ≥25/20/15/10/5 Pyrite | Spend 25/20/15/10/5 Pyrite. Amplify the next gem by 50%. | Amplify by 75% instead. |
| Appraise | Rare | Pair valued ≥5/4/3/2/1 | Appraise 1 raw stone in your bag. Deal damage equal to its value. | Appraise up to 2 stones and deal their combined value. |
| Gilded Armor | Uncommon | Always | Gain Block equal to 10/15/20/25/30% of your Pyrite. | Gain 1 Ward. |

## White — 9 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Glimmer | Common | At least one die <7/6/5/4/3 | Permanently raise each matched die face by 1. | Raise all faces of each matched die. |
| Refract | Uncommon | At least one die ≥95/90/85/80/70% of its own maximum | Add 1 phantom die copying your highest roll. | Two phantoms. |
| Polish | Uncommon | ≥4/3/2/1/0 dice at or below half their own maximum | Adjacent gems gain 1 Clarity this fight. | Apply to all gems. |
| Mirror | Uncommon | ≥5/4/3/2/1 distinct values | Change one die to join your strongest matching set. | Match two dice. |
| Cascade | Rare | Pair valued ≥5/4/3/2/1 | An extra reroll next turn. | Two extra rerolls. |
| Facet | Rare | At least one die ≥90/75/60/40/0% of its own maximum | Adjacent gems gain 1 Cut this fight. | Apply to all gems. |
| Echo | Rare | Pair valued ≥5/4/3/2/1 | Repeat the previous gem at half strength. | At full strength. |
| Prism | Legendary | Always | Adds 1/2/3/4/5 Resonance when it fires. | Gain 2 Charged. |
| Enrich | Rare | ≥5/4/3/2/1 distinct values | All other gems gain 1 Carat this fight. | Gain 2 Carats instead. |

## Opal — 10 skills

| Gem | Rarity | Trigger / Cut ladder | Base effect | Flawless card line |
| --- | --- | --- | --- | --- |
| Red Seam | Mythic | Resonance ≥5/4/3/2/1 | A seam of Red through the stone: every Red gem that has already fired this turn fires again. | Each of them plays a second time. |
| Blue Seam | Mythic | Resonance ≥5/4/3/2/1 | A seam of Blue through the stone: every Blue gem that has already fired this turn fires again. | Each of them plays a second time. |
| Green Seam | Mythic | Resonance ≥5/4/3/2/1 | A seam of Green through the stone: every Green gem that has already fired this turn fires again. | Each of them plays a second time. |
| Violet Seam | Mythic | Resonance ≥5/4/3/2/1 | A seam of Violet through the stone: every Violet gem that has already fired this turn fires again. | Each of them plays a second time. |
| Gold Seam | Mythic | Resonance ≥5/4/3/2/1 | A seam of Gold through the stone: every Gold gem that has already fired this turn fires again. | Each of them plays a second time. |
| White Seam | Mythic | Resonance ≥5/4/3/2/1 | A seam of White through the stone: every White gem that has already fired this turn fires again. | Each of them plays a second time. |
| Fire Opal | Mythic | Pair valued ≥5/4/3/2/1 | Every gem in the rail gains 1/1/1/2/2 carats for the rest of the fight. | And a Cut step with it. |
| Doublet | Mythic | Uses the copied skill’s trigger; search reach 1/2/3/4/5 sockets. Always fires if no skill is found. | Copy the nearest later non-Opal skill within reach, using Doublet’s own carat, cut, clarity and inclusions. With no eligible gem, add 1 Resonance. | It reads the other gem's Flawless line as well. |
| Matrix | Mythic | Always | The first 1/2/3/4/5 gems that stayed dark this turn fire anyway. Last in the rail it hears them all. | However many of them there are. |
| Prelude | Mythic | ≥5/4/3/2/1 distinct values | The next gem fires 1/1/1/1/2 extra times. Last in the rail, that is the Birthstone. | And once more after that. |

## Character Birthstones — separate from the 66 skill gems

These are fixed character abilities at the end of the rail, not collectible skill entries. Resonance powers their effects; qualifying tiers can combine unless a tier is marked exclusive.

| Character | Birthstone | Main pattern and payoff |
| --- | --- | --- |
| Ardor, the Knight | Rally | Pair: Resonance block. Triple: 3× Resonance damage. Quad: cleanse and stun. Five of a kind: five hits of 5× Resonance. |
| Vesper, the Rogue | Thousand Cuts | Five distinct values with the highest exceeding all the others combined: one Resonance-damage hit per point on the highest die. |
| Cadence, the Wizard | Encore | Four-die straight: 4× Resonance damage to every creature. Five-die straight: replay the fired rail, including Overture. |
| Rue, the Apothecary | Bitter Draught | Four low dice: Resonance poison. Five low dice: tick every creature’s poison. Five ones: tick every poison Resonance times. |
| Puck, the Harlequin | Motley | Five odd dice: 3× Resonance damage. Five even: 3× Resonance block. Five distinct values of one parity: exclusive 6× damage and block, plus stun. |
| Florin, the Gambler | High Roller | Crowns grant Resonance damage and pyrite each; three add loot quality; five award a stone. No crowns loses Resonance pyrite. A crown is a die on its top face. |

## Implementation notes

- **Lifeline:** stacks on each living ally. The next lethal direct hit, Poison tick, or retaliation consumes every stack and restores that much HP (up to maximum). Flawless applications also store that amount of revival Block. It does not revive an already downed ally and has no once-per-fight activation limit.
- **Permanent means this run:** Glimmer changes physical die faces and Thrive raises max HP by exactly 1 per Flawless firing. Both survive later fights without altering the stored collection. Glimmer also updates the current roll; phantom dice cannot gain permanent faces.
- **Fight-only gem growth:** Polish grants adjacent Clarity, Facet adjacent Cut, and Enrich all other gems Carats. Flawless Polish/Facet affect every gem, including themselves. Bonuses stack and follow the gem within the fight; Cut/Clarity stop at their normal highest tier. Temporary Clarity enables its Resonance, magnitude and Flawless bonuses while preserving existing inclusions. Stored gems are unchanged.
- **Pyrite:** Wager/Stake may spend bag Pyrite plus combat earnings. Each activation and replay pays separately; insufficient funds fizzle even with Star/forced activation. Wager refunds 2× the price only on a kill (3× when Flawless). Stake always gives +50% (+75% Flawless). Prices/refunds are never multiplied by carats or elite/warden rewards. On defeat, unbanked earnings/refund profit are lost; net spending still reduces the bag balance, to a minimum of zero.
- **Result-based riders:** Riposte reads actual HP damage, Shatter actual Block removed, Tithe actual Pyrite gained, and Bulwark actual Block gained. These riders do not receive a second magnitude multiplier. Mortar grants its percentage of current Block as flat Retain at activation; Retain still caps at 20.
- **Curse:** one base stack per rolled 1; 0/1/2/3/4 max HP removed per rolled 1. Curse and max HP loss are separate Ward-blockable applications. Max HP cannot fall below 1. Flawless then attacks for current Curse stacks, subject to ordinary target damage modifiers. The status remains 10% per stack, capped at 10.
- **Jackpot / Lucky Seven:** Jackpot’s 5× bonus requires Flawless and at least five matched dice. Lucky Seven with Flawless and at least three 7s resolves seven hits plus seven payouts in total, even with four or more 7s. Ordinary magnitude scaling still applies to each reward.
- **Apex:** uses the highest qualifying individual die once, with thresholds 20/19/18/17/16. Its Flawless doubling requires that selected value to be exactly 20; a higher value does not double.
- **Appraise:** identifies the first raw bag stone (up to two when Flawless), reveals its inclusions and deals its current Pyrite sale value as one hit. Already appraised stones cannot pay again. Appraisal persists to the run; forecasts do not mutate real inventory.
- **Chosen defaults:** Bloom’s Charged bonus is party-wide. Flawless Renewal and Gilded Armor grant 1 Ward. Gilded Armor grants Block worth 10/15/20/25/30% of available Pyrite; Appraise requires a pair; Enrich requires distinct values and grants +1 Carat (+2 Flawless). Refract adds one phantom per normal proc (+1 Flawless), independent of remaining rail length.

## Completed updates

- [x] Revise existing gem requirements, effects, rarities, and Flawless lines as listed above.
- [x] Add Crosscut, Detonate, Shelter, Mortar, Siphon (formerly Mycelium), and Stake.
- [x] Add Apex, Enrich, Appraise, and Gilded Armor.
- [x] Shorten status text and add keyword hover definitions to effect and Flawless lines.
- [x] Show Lifeline stacks, temporary gem upgrades, Pyrite costs/refunds, appraisal, and Poison spread in combat feedback.
- [x] Preserve Curse at 10% per stack / maximum 10 and Sparkle at maximum 100 / all consumed on next find.
- [x] Cover new mechanics, forecasts and run persistence in [gem scenarios](tests/test_gem_updates.gd).

## Future work — not implemented

- [ ] **Tailings — Gold / Uncommon:** reward earlier fizzles, once per socket per turn. Proposed 1/2/3/4/5 Pyrite per fizzle; Flawless +1 per paid fizzle. Requires tracking so replays cannot pay twice.
- [ ] **Windfall:** revise the remaining card/tooltip percentage-quality wording to describe its actual drop chance and generation luck effects.
- [ ] **Balance playtesting:** compare paid Gold builds, poison conversion, Lifeline stacking, and repeating fight/run upgrades with Echo, Seams, Prelude and Encore.

**Not selected:** Poultice, Undertow, Silence, Level and Invert are excluded from the content pack and active implementation plan. Siphon is the selected name for Mycelium. Additional status ideas remain in [Buffs.md](Buffs.md).

Sources: [content pack](content/deep_cut.json), [trigger rules](sim/patterns.gd), [effect rules](sim/rules.gd), [stone scaling](sim/stone.gd), [battle resolution](sim/battle.gd), [run settlement](sim/descent.gd).
