# RogueDice: expanded gameplay and content catalog

Design revision: September 8, 2026. All content in this document is **proposed**, not recovered from the React source. Numeric values are implementation-ready starting points for playtesting, not claims of proven balance.

Read this alongside the [Godot rebuild specification](GODOT_REBUILD_SPEC.md). That document defines the common combat, networking, and persistence rules and preserves the original game's mechanics as a historical reference. This catalog defines additional content and named run profiles. A profile selects its content pool, encounters, and rewards; it never silently changes fundamental combat rules.

## 1. Design goals and scope

The expansion should create more reasons to keep, reroll, or reshape dice. Each addition must support a recognizable decision: preserve a pair, break it for a straight, chase a threshold, protect an ally, or invest in future consistency.

The complete proposed catalog contains the original eleven corrected skills plus eight new skills, eight relics, six alternative dice, six new ordinary/elite enemies, and three boss definitions. Build a small starter set first; the final section gives the rollout order.

| Build direction | Desired hand | Core tools | Main tradeoff |
|---|---|---|---|
| Matching sets | Pairs, two pairs, triples, full houses | Block, Heavy Strike, Shield Bash, Interpose, Sunder | Smaller repeated values improve consistency but reduce large attacks |
| Straights | Distinct consecutive values | Multistrike, Blessing, Arc Burst, Lifeline | Rerolling to complete a sequence can sacrifice defense |
| High rolls | One large value or a large total | Strike, Stun, Drain Strike, Venom | A high-variance die can leave the rest of the hand weak |
| Low totals | Small controlled rolls | Bulwark, Heal, supporting gems | Low totals weaken basic offense; persistent block needs a payoff |
| Parity | Mostly odd or mostly even values | Mend, Even Tempo, odd/even dice | Face specialization reduces access to other patterns |
| Distinct values | Five different results | Precision, Arc Burst, Focusing Prism | Conflicts with pair-based defenses |
| Sevens | One or more 7s | Lucky Strike, Seven D8 | Chasing a jackpot can weaken reliable damage and block |

Every hero can use every direction. Starting traits give a preference, not a class restriction. Keep gold as the only spendable run currency in this version; avoid adding separate ore, dust, essence, and upgrade tokens.

## 2. Hero identities

Keep the original maximum HP and five-die loadouts for the first comparison. Add one trait and a third starting gem to each hero. All third gems start at Carat 1, Cut 1, Clarity 1.

| Hero | Retained loadout | Trait | Third starting gem |
|---|---|---|---|
| Ardor | 100 HP; D6/D6/D6/D8/D8; Strike C1, Block C2 | **Stand Firm:** at the beginning of a non-skipped actor turn, gain 2 block if the final hand contains a pair | `INTERPOSE` |
| Kait | 70 HP; D4/D4/D4/D4/D20; Strike C2, Block C1 | **Calculated Risk:** at the beginning of a non-skipped actor turn, gain 3 block if any die's final value is at least 4 higher than that die's initial value this turn | `SUNDER` |
| Max | 80 HP; D4/D6/D6/D8/D12; Strike C1, Block C1 | **Second Thought:** once per encounter, reroll exactly one active die without spending the normal reroll opportunity | `ARC_BURST` |

Ardor's trait activates once, not once per pair or per gem. Kait compares the initial and final authoritative results by die-instance ID; intermediate rerolls do not accumulate improvements. A hand cannot gain trait block again by toggling ready. These traits run after the actor's stun check, before their ordered gems.

Max can use Second Thought before or after a normal reroll while planning and not ready. It is a distinct command with one encounter charge; it does not refill or increase the normal reroll budget. It generates an actual new face and records it like any other reroll. A failed/stale request spends neither the charge nor RNG. Revival does not refresh the charge.

The roles are deliberately modest. Kait already has the strongest starting Strike expectation, so her new identity adds conditional defense rather than more damage. Max gains control over a crucial die; Ardor gets a dependable matching-set benefit plus a way to help a teammate.

## 3. Additional skill gems

### 3.1 Shared notation and targeting

Use the four C's from section 9.2 of the main specification: `C` = Carat with the multiplier
`M(C) = (C+7)/8`, `K` = Cut, `L` = Clarity with the flat term `F(L) = 2L`, and Color as the skill's
effect category. Carat multiplies the finished base; Cut scales only what the dice contributed;
Clarity is flat and also eases triggers. Floor each completed damage, block, or heal amount once,
inside `M(C)`, before mitigation or caps. `H` is the highest die value, `p` the highest pair value,
and `T` the total. All skills use the same five-die hand without consuming dice.

The gems below are the additions to the main catalog. Each one names a Color so a player can read a
build's shape without opening every gem: Red damage, Blue block, Green healing and revival, Violet
control, Gold fortune. Color is authored on the skill and never rolled, upgraded, or sold.

Players choose a preferred hostile target only. Friendly effects have no chosen recipient: ordinary support skills reach every living hero. Lifeline revives the first downed hero, and otherwise heals every living hero. The simulation freezes a skill's targets at skill start, and subsequent hostile effects against a killed target fizzle.

“Two pairs” means two distinct values each appearing at least twice. A full house qualifies; four of a kind plus a singleton does not. For a straight, duplicate values are ignored and the highest qualifying run of the required length is used.

### 3.2 Skill definitions

| ID / name | Color | Rarity | Activation | Ordered effects | Design purpose |
|---|---|---:|---|---|---|
| `INTERPOSE` / Interpose | Blue | 1 | Any pair | Give every living hero `floor((p + K - 1 + F(L)) × M(C))` block | Turns a personal pair into cooperative protection; works on self in solo. Its base is a fixed pair, so Cut is the weakest of the three rolls here and Clarity the strongest |
| `MEND` / Mend | Green | 1 | At least three odd results | Heal every living hero `floor((lowest odd value + 2(K-1) + F(L)) × M(C))` | Makes odd faces and support builds useful without requiring a dedicated healer |
| `SUNDER` / Sunder | Red | 2 | Two pairs | Remove up to `floor((2K + F(L)) × M(C))` target block; then deal `floor((p + F(L)) × M(C))` damage | Rewards sets against defensive enemies; removal itself causes no HP damage |
| `ARC_BURST` / Arc Burst | Red | 2 | Straight of length 3 | Deal `floor((highest value in the chosen straight + F(L)) × M(C))` damage to up to `K + 1` distinct living enemies | Gives straight builds an explicit group attack. Cut buys targets rather than damage, the one place it does not scale the roll |
| `VENOM` / Venom | Violet | 2 | `H ≥ 13 - L`, i.e. 12/11/10/9/8 | Deal `floor((floor(H/2) + F(L)) × M(C))` damage, then apply `K + ceil(C/4)` Poison | Gives high rolls a slower answer to heavy block. Clarity does double duty: a flat damage term and a lower threshold |
| `EVEN_TEMPO` / Even Tempo | Blue | 2 | At least three even results | Gain `floor((even result count × K + F(L)) × M(C))` self block, then deal `floor((K + F(L)) × M(C))` damage | A defensive parity build with a small offensive payoff |
| `PRECISION` / Precision | Red | 3 | All five results are distinct | Deal `floor((sum of the lowest two results + 2K + F(L)) × M(C))` damage | Rewards keeping diversity instead of a pair |
| `LIFELINE` / Lifeline | Green | 4 | Straight length 5 at L1–2, 4 at L3–4, 3 at L5 | If a downed ally is available and the gem's revive charge remains, revive them with `min(maxHP, floor((3K + F(L)) × M(C)))` HP; otherwise heal every living hero `floor((K + F(L)) × M(C))` | Allows a difficult pattern to recover a teammate during a fight |

Arc Burst targets the preferred enemy first, then remaining living enemies in stable encounter order until the target limit is reached. It does not hit one enemy repeatedly when fewer targets exist. The target list is fixed for that skill. Cut can therefore be situational against a single boss; the upgrade preview must say so.

Lifeline prioritizes a preferred downed ally, then the first downed ally in stable party order. Each equipped Lifeline instance has one revival charge per encounter. If that charge is exhausted, downed targets cannot be revived; the skill may still heal a living ally. Living-target healing does not consume the revival charge. Swapping, reconnecting, or reviving the caster does not refresh encounter charges. The revived hero starts with zero block, no encounter statuses, and cannot act until the next combat turn. Exclude Lifeline from default solo loot offers, where its main function cannot be used.

All eight definitions are generic gems. Their use is not restricted to their associated starting hero. The original gems retain their corrected definitions from the main specification.

### 3.3 Poison, Resolve, and effect timing

Add only one general damage status initially: **Poison**.

- Poison stores an integer stack count from 0 to 12. New applications add stacks up to that cap.
- At the end of the affected unit's scheduled actor slot, deal damage equal to current stacks directly to HP, then remove one stack.
- Poison ticks even when stun skips the slot. It does not tick an extra time because the unit uses several gems or performs a multi-hit skill.
- An application before a unit's slot can tick at that slot's end. An application after its slot waits until the next turn.
- Poison is not an attack hit: it does not trigger attack-hit relics or receive Enrage bonuses. Block cannot absorb it.
- A downed unit loses Poison; a dead actor does not create extra ticks. Encounter end clears it.
- After a Poison tick, run the same defeat/victory check used after a complete skill. If a boss dies from its end-slot tick, settle the encounter before scheduling another turn.

Boss **Resolve** follows the main specification: one stun-skipped slot followed by two slots immune to new external stun. Poison still ticks during those slots. An effect can successfully damage or poison a boss even when its stun component is rejected; show each result separately.

The new `remove_block` effect simply subtracts `min(current_block, requested_amount)`. It does not bypass into HP, generate a damage event, or activate a damage-triggered effect. Report the actual removed amount in its own event.

### 3.4 Example combinations

For `[2,2,3,3,3]`, Block, Interpose, Heavy Strike, Sunder, and Shield Bash can all activate if equipped. A player can order Block before Shield Bash, while Interpose protects another hero. Sunder creates an opening by removing enemy block. Six slots and the required Strike prevent equipping every matching-set payoff indefinitely.

For `[1,2,2,3,4]`, Arc Burst uses the highest three-value run `[2,3,4]`. At C1/K1/L1 it deals `floor((4 + 2) × 1.000) = 6` to each of up to two enemies. Multistrike at L3 can use the four-value run `[1,2,3,4]` from the same hand. The duplicate 2 can also activate Block.

For `[1,3,3,5,12]`, Mend activates and a base-Clarity Venom activates from the 12. A C2/K2/L1 Mend heals `floor((1 + 2 + 2) × 1.125) = 5`; C2/K2/L1 Venom deals `floor((6 + 2) × 1.125) = 9` and applies 3 Poison. If the target had no Poison, its next end-slot tick deals 3 and leaves 2 stacks.

Raising that Mend to C12 alone takes it to `floor(5 × 2.375) = 11`, while raising it to L5 alone takes it to `floor((1 + 2 + 10) × 1.125) = 14`. That is the intended read on the two upgrade paths: Clarity is the bigger single step on a small-base support gem, and Carat overtakes it on anything whose base already scales with the roll.

These examples demonstrate overlap without inventing consumable dice, manual skill selection, or combo meters.

## 4. Dice as build components

Keep exactly five active dice. Add up to five reserve dice per hero, swappable between rooms. Purchases require a vacant reserve slot; only reserve dice may be sold, and a swap exchanges one active die with one reserve die. If reserves are full, sell a reserve die before purchasing. Validate capacity on the host; never remove an active die and leave a four-die hand.

These six alternatives preserve the mean value of a standard die with the same number of faces. They change distribution, so matching the mean is not a claim that they are equally powerful.

| ID / name | Shape | Ordered face values | Mean | Purchase price | Useful tradeoff |
|---|---|---|---:|---:|---|
| `PAIRED_D6` / Paired Die | D6 | 1, 1, 2, 5, 6, 6 | 3.5 | 8 | More 1s and 6s; fewer distinct values and missing 3/4 |
| `ODD_D6` / Odd Die | D6 | 1, 1, 3, 5, 5, 6 | 3.5 | 8 | Odd result on 5/6 faces; missing 2/4 |
| `EVEN_D6` / Even Die | D6 | 1, 2, 4, 4, 4, 6 | 3.5 | 8 | Even result on 5/6 faces; concentrated on 4 |
| `SEVEN_D8` / Seven Die | D8 | 1, 2, 3, 4, 5, 7, 7, 7 | 4.5 | 14 | A 37.5% chance of 7; cannot produce 6 or 8 |
| `SPLIT_D12` / Split Die | D12 | 1, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 12 | 6.5 | 16 | More extremes; missing 6/7 |
| `SPLIT_D20` / Rift Die | D20 | 1, 2, 3, 4, 5, 5, 6, 6, 7, 7, 14, 14, 15, 15, 16, 16, 17, 18, 19, 20 | 10.5 | 22 | Low or high clusters; no 8–13; natural 20 remains 5% |

Mean values and face counts were checked arithmetically. Odd and Even Dice have the same mean but very different pattern probabilities. Repeated 7 faces still produce only one rolled 7 from that die; Lucky Strike's jackpot requires three different dice to show 7.

Expanded shops add one featured die beside the three gem offers. Choose uniformly from eligible alternatives: the three D6 variants in Act 1; those plus Seven D8 and Split D12 in Act 2; all six in Act 3. The nine-room starter profile can include Seven D8 after its elite encounter to demonstrate a jackpot build. Generate stock once per visit. Die sale price is half the listed purchase price rounded down; ordinary standard dice use values 4/6/8/10/12/16 for D4/D6/D8/D10/D12/D20 before halving.

Workshop engraving still changes one face to a value from 1 through that die's side count. A shape replacement resets the full face list. No individual face has a hidden weight: probability always comes from face count. Save physical face IDs independently of displayed numbers.

## 5. Relics with bounded triggers

Heroes start without relics. Allow three equipped relics and an unlimited reserve, with no duplicate relic ID equipped. Equip changes occur between encounters; acquiring, swapping, or reconnecting must not manufacture extra trigger charges. Relics are run-only sidegrades competing for slots, not account-wide power.

| ID / name | Effect | Trigger boundary |
|---|---|---|
| `MATCHBOX` / Matchbox | A successful Block gem grants 2 additional block to its recipient | Once per actor turn; does not apply to every block-granting effect |
| `STEADY_HAND` / Steady Hand | Strike deals 2 additional raw damage if none of the hero's dice was rerolled this turn | Once for that hero's Strike; Max's extra reroll also breaks the condition |
| `FIELD_DRESSING` / Field Dressing | Add 2 to the first positive ordinary healing effect the owner casts each actor turn | Add before recipient HP cap; no bonus to revival, rally, or Rest |
| `MINERS_LANTERN` / Miner's Lantern | Owner receives 2 extra mining energy | Once when entering a Mine; downed owners still receive zero energy |
| `FOCUSING_PRISM` / Focusing Prism | Treat Clarity as one rank higher, capped at 5, for skills with the `straight` trigger tag | An effective stat modifier; no change to stored gem value or sell price |
| `MERCHANT_SEAL` / Merchant's Seal | Add 3 gold to the owner's normal/elite battle-room reward | Once per settled room; not skill gold, boss rewards, or item sales |
| `TINKERS_BELT` / Tinker's Belt | One Workshop service per act costs zero while the relic is equipped | Applies to the first service while its act charge is available; consumes the visit allowance and act charge |
| `LASTING_AEGIS` / Lasting Aegis | After a victorious battle, store up to 6 of the owner's remaining block; grant that amount on entry to their next battle | Capture before block cleanup; consume the stored amount once; downed owners store zero |

For Focusing Prism, `straight` tags apply to Multistrike, Blessing, Arc Burst, and Lifeline. Each uses its normal formula at effective Clarity, so the relic can raise `F(L)`, ease the trigger, or both. If a particular rank changes neither, the preview shows no change. Cut/Clarity upgrade costs always use the stored rank.

Relics do not recursively react to their own bonus events. Each bonus records its source relic and originating action. Equipment is frozen during an encounter. Lasting Aegis's stored block belongs to its owner's relic instance; transferring or selling relics is not supported in the first content set, and equipping it later cannot capture block from an already settled fight. Unequipping it discards stored block. Tinker's Belt tracks its act charge even while unequipped.

Field Dressing is eligible only when the base healing amount is positive and the recipient is missing HP at resolution. Healing a full-health recipient does not consume its turn use; healing a recipient missing only 1 HP does consume it, even though most of the bonus is capped away.

Award personal relic choices after elite battles and nonfinal bosses. Offer two unowned relic IDs after an elite and three after a boss; the player chooses one or declines. If the eligible pool is smaller, show the available choices; if empty, award 5 gold. Never silently replace an equipped relic. The owner can move their new relic into a slot during the subsequent build window.

## 6. Enemy roles and encounter composition

### 6.1 Intents and targeting

An enemy definition supplies a die deck and an intent script. Unless explicitly stated otherwise, roll once at turn start, choose one script branch from that snapshot, and publish its targets and values before players plan. Do not secretly switch a heal to an attack because the players changed HP during resolution.

Single-target attacks select one random living hero at turn start using the host's encounter RNG. A stated priority rule overrides this choice, with ties broken by stable seat order. If that target is downed before execution, retarget once at skill start to the first living hero and report the change. A multi-effect skill keeps its resulting target for the whole skill.

Enemy-friendly heals and block grants default to self if the advertised friendly target dies before execution. Empty groups produce no effects. Damage receives Enrage; healing, Poison ticks, and block do not. Each named intent below is one skill action whose ordered effects complete before a victory check, with status ticks at the end of the actor slot.

### 6.2 Six new enemy definitions

These are Act 1 base values. Use the scaling and composition rules below for other acts and party sizes.

| ID / enemy | HP / initial block | Dice | Intent script | What it teaches |
|---|---|---|---|---|
| `STONE_CRAB` / Stone Crab | 26 / 6 | D6, D6 | Alternate **Shell Up** (gain `min(roll)+3` block) and **Claw** (damage `H+3`); start with Shell Up | Preparing Sunder or a straight while the enemy defends |
| `GEM_CULTIST` / Gem Cultist | 22 / 0 | D8, D8 | At turn start, if any living ally has at least 5 missing HP, **Restore** the ally with most missing HP for `min(roll)+2`; otherwise **Shard** for `H+1` damage | Focus fire and disrupting support |
| `DARTLING` / Dartling | 16 / 0 | D4, D4, D4 | **Barbed Dart:** damage `H+1`; if its roll contains a pair, then apply 2 Poison to that same target | Threatening low-HP enemies and damage that block cannot absorb |
| `IRON_WARDEN` / Iron Warden | 48 / 12 | D6, D8, D10 | Alternate **Fortify** (gain `min(roll)+4` self block, give 4 block to each other living enemy) and **Hammer** (damage `H+5`); start with Fortify | Group protection and the value of control or block removal |
| `MIRROR_WISP` / Mirror Wisp | 18 / 0 | D6, D6 | **Reflection:** publish one random face value 1–6 and a hero target; deal `H+1`, plus 4 if that hero's final hand contains the marked value | Choosing whether to break a useful pattern to avoid extra damage |
| `RIFT_HOUND` / Rift Hound | 28 / 0 | D4, D8, D12 | Alternate **Track** (`H+1` damage) and **Pounce** (`H+4` damage); target the living hero with least block at turn start; start with Track | Anticipating a vulnerable teammate and using Interpose |

Mirror Wisp marks once per turn. The bonus is a published conditional rule, not a second random draw after lock-in. Its UI shows base and conditional damage and updates the preview as the target's hand changes. Any retargeting uses the replacement hero's hand and is logged.

The original Slime and Red Slime remain useful introductory definitions. Iron Warden is elite content; avoid making every ordinary enemy a status-heavy special case.

### 6.3 Encounter budget

Use one threat point for Slime, Stone Crab, Gem Cultist, Dartling, Mirror Wisp, or Rift Hound; use two for Red Slime or Iron Warden. These are authoring weights, not a mathematically proven equivalence.

- Ordinary battle budget is the party size P; elite budget is 2P.
- Fill the budget from the act's authored encounter template, not unrestricted random enemies.
- At most P support enemies and at least one attacker per encounter; at most one Gem Cultist in Act 1.
- Cap the initial enemy count at four. If a template exceeds four, replace two one-point enemies with one two-point enemy from the same act's pool rather than stacking unreadable rows.
- Lock party size at room entry using the run's original seats. Downed/disconnected heroes do not reduce the budget.

Example templates by P:

| Template | P1 | P2 | P3 | P4 |
|---|---|---|---|---|
| Intro Slimes | Slime | 2 Slimes | 3 Slimes | 4 Slimes |
| Quarry Patrol | Stone Crab | Stone Crab + Dartling | Stone Crab + Dartling + Cultist | 2 Stone Crabs + Dartling + Cultist |
| Warden Elite | Iron Warden | Iron Warden + Red Slime | 2 Iron Wardens + Red Slime | 2 Iron Wardens + 2 Red Slimes |
| Mirror Patrol | Mirror Wisp | Mirror Wisp + Rift Hound | 2 Mirror Wisps + Rift Hound | 2 Mirror Wisps + 2 Rift Hounds |

For ordinary/elite enemies, multiply base HP by 1.0/1.35/1.75 in Acts 1/2/3 and round up. Add 0/2/4 to each attack's raw damage and multiply initial block, generated block, and healing by 1.0/1.2/1.4, flooring each result. Keep Poison application amounts unchanged. Apply the turn-based Enrage bonus afterward. Bosses use their own act-specific values and are not scaled a second time.

The short profile starts with Intro Slimes, introduces Quarry Patrol, and uses Warden Elite as its required elite. In the starter content set, substitute a Slime for each Dartling in Quarry Patrol; its Poison content ships with the full set. Introduce Mirror and Poison enemies only once their rules are available and explained.

## 7. Bosses that ask different questions

Bosses use scripted intents rather than dice unless a future definition explicitly gives them a die-based intent. Their values below already account for their act; multiply only the marked quantities by original party size P. All use visible Resolve and the common Enrage rule. Group attacks hit each living hero once.

Check HP-based phase changes only at the next turn start, before publishing intentions. Crossing a threshold during player actions never replaces an already announced attack. A new phase starts at its first listed intent. Summons, interrupt windows, and additional boss health bars are unnecessary for these first three designs.

### 7.1 Slime King — Act 1

`SLIME_KING`: 60P HP, zero starting block. Cycle these three intents, starting with Slam:

1. **Slam:** deal 10 damage to every living hero.
2. **Fortify:** gain 8P block.
3. **Absorb:** heal 6P HP, capped at maximum.

The question is whether the party can exploit quiet turns while preparing for group damage. Interpose, Sunder, persistent block, and precise use of stun each have a purpose. This deliberately simple boss is also the end of `short_9`.

### 7.2 Mirror Regent — Act 2

`MIRROR_REGENT`: 75P HP, 8P starting block. Above half HP, cycle:

1. **Refraction:** publish a uniformly chosen number from 1–6; deal 8 damage to every living hero, plus 6 to each whose final hand contains that number.
2. **Shatter:** remove up to 5 block from every living hero, then deal 6 damage to each. All block removals precede all damage, within the same action.
3. **Mending Glass:** heal 5P HP, then gain 5P block.

At 50% HP or lower, the next turn starts **Fractured** phase: alternate Refraction and Shatter, beginning with Refraction. Mending Glass no longer occurs. The selected number and conditional damage rule are published before planning.

This encounter makes keeping a particular face a calculated cost. It pressures both matching-set and pure block builds without making either unusable. Single-target gems remain useful because there is one target; group-attack specialists may swap their reserves before entry.

### 7.3 Rift Sovereign — Act 3

`RIFT_SOVEREIGN`: 100P HP, zero starting block. Above 40% HP, cycle:

1. **High Tide:** deal 10 damage to every living hero, plus 6 if that hero's final total is at least 24.
2. **Low Tide:** deal 10 damage to every living hero, plus 6 if that hero's final total is at most 18.
3. **Eclipse:** remove up to 3 block from every living hero, deal 6 damage to each, then gain 6P block.

At 40% HP or lower, enter **Convergence** next turn: each boss slot performs High Tide followed by Low Tide as two actions. This phase continues until victory or defeat. Check outcomes between the two actions, while Poison ticks only once at the end of the boss slot. Enrage applies separately to each damage action.

The safe total band during Convergence is 19–23: heroes there still take the base damage from both attacks, but avoid the conditional bonuses. The intent UI shows total incoming damage per hero, not merely the first action. High-roll builds can accept the extra damage to finish faster; low-total builds can rely on prepared block; reroll-control builds can aim for the middle band.

## 8. Run profiles and reward pacing

### 8.1 Two explicit profiles

| Profile | Purpose | Structure | Initial target duration |
|---|---|---|---|
| `short_9` | First complete experience, tutorials, short sessions | The main specification's nine rooms, ending with Slime King | 20–35 minutes solo; 30–45 cooperative |
| `expedition_18` | Full campaign after the short loop is validated | Three acts of six rooms, each ending in its own boss | 45–70 minutes solo; 60–90 cooperative |

Durations are design targets, not measured results. Use fast playback and inspect time-per-turn before adding rooms to achieve length.

Each six-room act in `expedition_18` has the following structure:

| Local room | Contents |
|---:|---|
| 1 | Required ordinary battle, introducing the act's enemy pool |
| 2 | Three-offer route choice |
| 3 | Required elite encounter |
| 4 | Three-offer route choice |
| 5 | Camp: the normal Rest recovery plus free inventory/equipment management |
| 6 | Boss |

Act 1 is the Quarry: Slimes, Stone Crabs, Cultists, and the Warden. Act 2 introduces Mirror Wisps, Dartlings, and the Mirror Regent. Act 3 mixes Rift Hounds with earlier roles before Rift Sovereign. Avoid adding new status rules during the final boss explanation.

In the full profile, variable offers include normal Battle, Shop, Workshop, Lapidary, Mine, Rest, and Event. Reuse the main offer weights, add Event at weight 1, and exclude optional Elite because each act already has a required elite. The first offer is a normal Battle; the other two are sampled without replacement from eligible noncombat types. If the party has not seen a Shop in the act, force Shop into local room 4's offer set. Consecutive noncombat repeats remain excluded, except a guaranteed Camp.

These guarantees prevent a run from depending on whether a healing or upgrade room happened to appear. They still leave the party free to spend its two optional visits on combat, equipment, or recovery.

### 8.2 Rewards after combat

| Encounter | Gold per hero, Acts 1/2/3 | Additional reward |
|---|---|---|
| Normal | 10 / 15 / 20 | Personal choice of one of three gems, or decline for 3 gold |
| Elite | 20 / 30 / 40 | Personal choice of one of three improved gems, plus one relic choice from two offers |
| Nonfinal boss | 30 / 40 / — | Personal relic choice from three offers |
| Final boss | Profile's boss gold, if configured | Victory summary; grant its reward once before ending the run |

For `short_9`, use Act 1 gold values and the original corrected depth-luck property generation. Its normal battles also grant the new personal gem choice; its elite grants improved gems and a relic. Its final Slime King awards 30 gold once for the run summary. `expedition_18` uses the tiered generation below and a final-boss award of 50 gold per hero.

Rally downed heroes to `ceil(10% maxHP)` after a victorious battle; preserve surviving heroes' actual HP. Do not heal the whole party to full between acts. Camp heals the ordinary one-third amount. A party wipe remains immediate defeat, including solo; it cannot be repaired by rally.

Rewards are settled by room-instance ID and claim ID. Players may inspect offers and discuss them before selecting; no fast-click competition exists. In the event of a disconnected controller, select the first offered gem into their reserve after the host's declared fallback period, and log the choice. Each player's reward is personal, so receiving it does not remove another player's options.

### 8.3 Tiered loot for the full profile

`expedition_18` replaces raw room-number luck with these explicit tables. `short_9` retains the original corrected luck formula for comparison. Save the profile ID so a resumed run never changes generator.

| Act | Skill-rarity weights, ranks 1/2/3/4 | Carat, uniform inclusive | Independent Cut and Clarity rank weights, ranks 1/2/3/4/5 |
|---:|---|---|---|
| 1 | 55 / 35 / 10 / 0 | 1–4 | 75 / 25 / 0 / 0 / 0 |
| 2 | 35 / 40 / 20 / 5 | 4–8 | 35 / 45 / 20 / 0 / 0 |
| 3 | 20 / 40 / 30 / 10 | 7–12 | 10 / 25 / 45 / 20 / 0 |

For each offer, choose rarity from nonempty eligible buckets after renormalization, select a skill ID uniformly within that bucket, then roll its three rolled properties. Color is not rolled: it arrives with the skill ID. Avoid duplicate skill IDs within a player's offer set, allow improved copies of owned skills, and respect contextual exclusions such as solo Lifeline. An elite gem gains +1 to either Cut or Clarity, chosen with equal probability and capped at 5. Ordinary shop stock uses the ordinary act table.

This keeps early gems understandable and gives upgrades room to matter. Carat still has a technical maximum of 24, but normal full-profile drops top out at 12; reserve the upper range for later challenge content instead of flooding a short run with near-maximal items. Because Carat is the pure multiplier, that cap is a hard balance lever: an act-3 drop reaches `M(12) = 2.375`, while the unreachable `M(24) = 3.875` is roughly a 63% further increase on top of it.

Retain the common gem buy-value formula and half-value shop sales. Workshop and Lapidary costs remain as specified in the main document. All equipment choices show their actual trigger, effective properties, price, and before/after output. No paid refresh is needed initially: repeated stock rerolls obscure whether the base offer distribution is good.

### 8.4 Account progression and difficulty

Give new players access to all three heroes and the starter content set. Introduce additional catalog content through the tutorial/journal as it is encountered; do not require hours of grinding to make a friend's build available. The permanent rewards can be discovered descriptions, run history, cosmetic dice skins, and achievements.

If challenge ranks are added after balance testing, make them selected, visible run modifiers—such as +10% enemy HP or an earlier Enrage turn—not permanent player stat upgrades. Store the chosen modifiers in the seed/run record. Avoid changing enemy dice distributions invisibly.

## 9. Events, mining decisions, and cooperative flow

### 9.1 Four event definitions

The party votes to enter an Event room, but each hero makes their own transaction. One player cannot spend another player's gold or HP. Generate any random offers once on room entry, and show the complete transaction before committing it. Every event also has a free Leave choice.

| ID / event | Option A | Option B |
|---|---|---|
| `ABANDONED_CACHE` / Abandoned Cache | Take 6 gold | Lose 8 HP and take one pre-generated current-tier gem with +2 Carat, capped at 24; requires current HP greater than 8 |
| `FIELD_MEDIC` / Field Medic | Take 4 gold from the abandoned supplies | Pay 8 gold to heal `ceil(0.2 × maxHP)`, capped at maximum |
| `ECHO_SHRINE` / Echo Shrine | Take 5 gold | Replace the faces of one owned D6 with Paired, Odd, or Even D6 at no cost; preview lost engraving |
| `JEWEL_BROKER` / Jewel Broker | Take 4 gold | Exchange one reserve gem for one of three pre-generated current-tier offers; all offers visible before commitment |

Cache HP loss is a noncombat cost, not damage: block cannot absorb it and damage-triggered effects do not respond. It cannot down the purchaser. Medic healing is not a cast heal and does not trigger Field Dressing. Broker must not consume the last owned Strike or an equipped gem. All events are limited to one option per hero per visit, and the ordinary all-done room barrier follows.

These events reuse HP, gold, dice, and gems. They create a choice without requiring a new minigame, quest system, or resource economy.

### 9.2 Make Mine a decision before its animation

Once the base mine simulation works, let the party choose one of two veins before generating its rocks. Use the same vote/readiness policy as a route choice; preview the distribution and each hero's energy, then commit once.

| Vein | Small / Medium / Large / Gold / Shiny rock weights | Why choose it |
|---|---|---|
| Coin Vein | 4 / 4 / 2 / 2 / 0 | More short rocks and direct currency |
| Crystal Vein | 1 / 3 / 4 / 0 / 2 | More work per rock, with a better chance of gem-bearing rocks |

These weights select rock types directly, replacing rarity-based rock selection for the expanded mine. Hit requirements and contents use the original rock definitions. Generate `6 × P` rocks after the vein is chosen; each living hero receives ten energy plus applicable relic bonuses. Retain automatic round-robin hits, pooled gold, and the gem draft. The choice changes reward shape; there is no click-speed test.

In `short_9`, use the main specification's mining luck for rock contents and the original +5 luck for Shiny-rock gems. In `expedition_18`, generate gems from the current act table; Shiny gems receive the same one-rank Cut-or-Clarity bonus as elite gems. Rock gold and gem-count distributions stay unchanged. Record both the generated rocks and final outcomes so reconnecting cannot regenerate the mine.

An empty result is still a completed visit with a visible result screen and Done action. Animation skip changes only playback. Present expected tendencies before vein selection, then reveal the actual generated rock sequence; avoid displaying a made-up guaranteed yield.

### 9.3 Communication and avoiding downtime

- Show each hero's intended enemy target, likely skill activations, and readiness. Let players ping a gem, enemy, or room option; pings carry no simulation authority.
- Keep party seat order visible. Support can happen before or after a teammate's turn, so order must be predictable. Reordering gems is sufficient for the initial version; do not add a whole-party initiative negotiation every turn.
- When downed, a player may inspect the fight, ping, and prepare a provisional next-room loadout. Commit that loadout only in the normal between-room window. They cannot execute combat commands.
- Rally returns the player to participation after the battle. Lifeline offers an earlier return during longer fights. Neither restores spent encounter charges.
- Once a room's transactions are complete, show a single clear Continue/Ready state. Do not require clicking through a separate modal for each coin, gem, and relic.
- Give the host a visible reconnect timer and explicit fallback choice. Treat slow planning as a social coordination issue, not grounds for silently choosing a risky reroll.

Pings, inspection, and provisional inventory edits must not consume RNG or alter a committed hand. Steam voice or in-game text chat can be added separately; they are not needed to implement cooperative rules.

## 10. Content contracts and Godot data examples

### 10.1 Additional definition fields

Keep content as typed Resources with an export/import format for bulk authoring. The examples below are illustrative JSON records for that format, not code claiming that a current Godot importer exists.

| Definition | Additional fields |
|---|---|
| Hero | `trait_id`, starting third gem, per-encounter trait charge count |
| Skill | Trigger kind/parameters, target policy, tags, ordered effects, optional revive charge limit |
| Relic | Hook ID, applicability filter, modifier, trigger scope/limit, optional stored-value cap |
| Status | Stack cap, tick/expiry hook, mitigation behavior, applicable sides, immunity interaction |
| Enemy | Base stats, dice IDs, threat weight, act tags, intent program |
| Boss | Party-scaled stats, ordered phases, turn-start transition predicates, Resolve policy |
| Encounter | Per-party-size unit lists, encounter category, reward-table ID |
| Run profile | Room schedule, act definitions, eligible content IDs, generator IDs, rewards, gold cap |
| Event | Options with typed costs, requirements, rewards, and per-visit limits |

Store the following runtime counters explicitly: normal rerolls, hero-trait charge, initial/final rolls by die ID, per-turn relic activation flags, Lifeline revive charge, a revived hero's `action_eligible_from_turn`, Poison stacks, Resolve slots remaining, generated combat gold, Lasting Aegis stored block, Tinker's Belt act usage, reward claims, and selected mine vein. Every counter has a declared reset boundary.

### 10.2 Example skill definition

```json
{
  "id": "INTERPOSE",
  "schema_version": 1,
  "name_key": "skill.interpose.name",
  "rarity": 1,
  "tags": ["pair", "support", "block"],
  "trigger": {"kind": "matching_group", "minimum_count": 2},
  "target_policy": "preferred_living_ally_or_self",
  "effects": [
    {
      "kind": "gain_block",
      "amount_rule": "interpose_block_v1",
      "rounding": "floor"
    }
  ]
}
```

`interpose_block_v1` is a registered evaluator implementing the published formula. It must be shared by the resolver, previews, and tooltip parameters. Do not evaluate arbitrary expression strings from downloaded content. An imported gem instance references `INTERPOSE` and stores its own Carat/Cut/Clarity and owner ID; its Color comes from the referenced skill definition, and a pack declaring an unknown Color is rejected at validation.

### 10.3 Example die definition

```json
{
  "id": "SEVEN_D8",
  "schema_version": 1,
  "shape": "D8",
  "purchase_price": 14,
  "faces": [
    {"id": "f0", "value": 1},
    {"id": "f1", "value": 2},
    {"id": "f2", "value": 3},
    {"id": "f3", "value": 4},
    {"id": "f4", "value": 5},
    {"id": "f5", "value": 7},
    {"id": "f6", "value": 7},
    {"id": "f7", "value": 7}
  ]
}
```

The three 7s are different physical faces. The authoritative roll records which was selected, even though several animations may show the same number.

### 10.4 Rule order and bounded hooks

At battle entry, establish the encounter instance, apply one-time entry grants such as stored block, and initialize charge counters. At turn start, roll and publish enemy intents, roll heroes, and save initial results. Accept legal planning commands until ready commitment.

For each actor slot: check death and action-turn eligibility; check stun/Resolve if eligible; if acting, apply the hero's start-slot trait and resolve ordered skills; then run one end-slot Poison tick if the actor is still alive; finish any slot-bound expiry counters. Check the outcome after complete skills and status ticks. A stun-skipped slot still reaches the end-slot status hook. A newly revived hero waiting for their eligible turn skips traits/gems without spending stun duration, but still has an end-slot status hook. A downed actor's slot creates no attack or status events. Decrement Resolve only if it existed at slot entry: gaining it after a stun skip does not immediately consume one of its two future protected slots.

Modifiers such as effective Clarity are read before evaluating the trigger or effect. Calculate the skill's base integer effect, apply eligible flat bonuses, then mitigate against block or HP caps. Report each source in the event. Damage bonuses never apply to block removal or Poison unless explicitly defined to do so. Keep resource-award provenance (`combat_skill`, `combat_relic`, `room_reward`, `sale`, `event`) so the combat gold cap cannot affect the wrong awards.

After victory, capture permitted carryover block, commit rewards, perform rally, clear block/statuses, and enter the reward/build window. Capture and cleanup are one authoritative transaction; animations cannot run them twice. Boss/act advancement waits for mandatory reward choices or the declared disconnected-player fallback.

Bound each hook: one per action, actor turn, encounter, act, or room as its definition declares. A relic bonus is a resolved modifier, not another skill cast. This avoids chains that recursively trigger themselves or depend on animation event order.

### 10.5 Additional commands

Extend the existing protocol with typed commands for hero-trait use, friendly target selection, die purchase/sale/swap, relic equip, reward choice/decline, event option, and mine-vein vote. Each identifies current phase and relevant instance IDs. Validate ownership, capacity, charge limits, nonlethal HP costs, and offer/claim availability on the host.

Generate content only when the command that commits entry/choice is accepted. Repeated previews cannot roll new shop stock, event gems, marked boss values, or mining contents. A room's persisted pending choices are part of its snapshot, so a reconnect resumes the same decision.

## 11. Verification and content rollout

### 11.1 Additional acceptance scenarios

| Case | Required outcome |
|---|---|
| Ardor with two pairs and three matching-set gems | Exactly 2 trait block; the trait is not multiplied by gem count |
| Kait's die changes 2→8→5 across two legal rerolls | No trait block: final improvement is 3, not 6 |
| Max retries the same Second Thought command | One new face and one spent charge; duplicate returns the earlier result |
| Max uses Second Thought without a normal reroll | Steady Hand is inactive because a die was rerolled |
| Arc Burst has one living enemy and K3 | One damage event, not four hits on that enemy |
| Sunder requests removal of 7 against 3 block | Remove 3, then independently apply its damage; no 4-point overflow from removal |
| Poison 3 on a stunned unit | End-slot damage 3, remaining stacks 2; exactly one tick |
| Two Venoms would exceed 12 stacks | Cap at 12; record applied versus requested stacks |
| Boss skips a stun slot, then receives stun during Resolve | Damage portions work; new stun is rejected for two slots; boss acts in both |
| Lifeline revives a later-seat hero | They remain unable to act until next turn despite their seat not yet occurring |
| Lifeline heals a living hero | Revival charge remains available |
| Party victory with one downed Ardor | Ardor rallies to 10 HP; no block/statuses; all eligible room rewards granted once |
| All heroes reach zero HP | Defeat; no rally or reward transaction |
| Capped combat-gold effect at allowance 1 requests 6 | Grant 1 skill gold; its damage still resolves; full room gold is separate |
| Lasting Aegis owner ends alive with 20 block | Store 6, clear combat block, grant 6 once on next battle entry |
| Tinker's Belt is unequipped and reequipped in the same act | Consumed free-service charge stays consumed |
| Final die values are all 7s | Five rolled sevens, irrespective of how many 7 faces each physical die has |
| Mirror Regent crosses 50% during player actions | Current announced intent remains; phase changes next turn |
| Rift Sovereign in Convergence | Two named actions, one Poison tick, distinct outcome checks between actions |
| Cache selected at exactly 8 HP | Risky option rejected; no RNG, inventory, or HP change |
| Mine vein selection retried after reconnect | Same rocks and rewards; no second energy grant |

Validate all table IDs, formula evaluator IDs, target policies, tags, content references, die face counts, property bounds, and positive eligible loot weights when importing the pack. A missing rule ID should fail content validation before a run begins.

### 11.2 Rollout order

| Stage | Include | Question to answer |
|---|---|---|
| Core comparison | Original eleven corrected skills, original heroes and enemies | Does the shared-hand combat work clearly and deterministically? |
| Starter content set | Three hero traits and third gems; Interpose, Mend, Sunder, Arc Burst; Matchbox, Steady Hand, Field Dressing, Miner's Lantern; Paired/Odd/Even D6 and Seven D8; Stone Crab, Gem Cultist, Iron Warden; Slime King; complete `short_9` | Do hero identity, build choices, and support make a short run worth replaying? |
| Full content set | Venom, Even Tempo, Precision, Lifeline; remaining relics/dice/enemies; two new bosses; event rooms and vein choice; `expedition_18` | Does progression sustain distinct builds across three acts without excessive planning time? |
| Later optional work | Challenge ranks, cosmetics, more encounters using existing rules | Which additions improve replayability without adding another rules subsystem? |

Enable content by explicit pack/profile IDs, not by scattered feature flags in skill functions. In the starter set, odd/even dice can already affect Mend and matching-set odds; Even Tempo completes the parity pair later. Until Dartling/Venom ship, omit Poison from tutorial screens and encounter offers.

Prioritize measuring the effect of a new mechanic over adding more definitions. The design succeeds if a player can explain why they kept a particular pair, rerolled a particular die, or chose a particular room—and if their teammate can see and support that decision.
