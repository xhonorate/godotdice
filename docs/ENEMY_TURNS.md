# Enemy turns: sequential dice and revealed abilities

September 23, 2026. Design decisions from the owner, extending the fights in
[The Descent in 3D](DESCENT_3D.md). **Status: implemented September 23, 2026.**
This changes combat rules, content, presentation and multiplayer events. It replaces
the published-intent design described in `REIMAGINING.md` and the former implementation.
The defaults below were adopted during implementation; enemy damage and debuffs both affect the whole party.

## 1. Planning information

During player planning, enemies show their complete current moveset and the dice they
will roll, in a fixed, visible order. They reveal neither future results nor which
abilities will activate. Dice changes from control effects and buffs are visible.

An ability row uses the same visual language as Birthstones such as Rally: ability
icon/name, activation requirement and effect. Use **Rolled value** for an amount read
from the current die. A formula remains a formula until that die lands; previous
results must never silently become the amount for a later die.

Most enemies have one die and a short, simple moveset. Ordinarily, every possible roll
activates at least one ability, through an unconditional ability or conditions that
cover the whole range. Suppression, stun and death can prevent an enemy from acting.
Combinations are uncommon bonuses, especially for stronger enemies.

## 2. Rules for one enemy turn

1. Begin the enemy's action phase after the players' actions. Check whether it can act.
2. Roll its first available die and reveal the result.
3. Evaluate ordinary conditions against that die and combination conditions against
   the results revealed so far in this enemy turn.
4. Resolve **every qualifying ability, in displayed order**, completing the effects
   of one ability before proceeding to the next.
5. Roll the next available die only after those abilities finish. Repeat until done.

Ordinary abilities can fire again for every die. For an enemy with 2d6 and an
unconditional damage ability, rolls of 5 then 2 produce an attack for 5, followed by
an attack for 2. The second attack does not read the first die's higher value.
Remove the existing `best`/`cycle` selection and implicit fallback to move zero;
coverage must be expressed by the visible conditions themselves.

Each combination ability fires **once per enemy turn, when first completed**. With
results 3, 3, 3, a pair row fires after die two and a triple row after die three.
The pair row does not fire again. If several rows qualify on the same die, their
displayed order still determines resolution. Combination history resets for each
enemy turn and never includes another enemy's dice.

Sequences accept consecutive values in any rolling order: 4, 2, 3 completes a
three-value sequence. All-odd and all-even conditions wait for the final available
die, because an unrevealed die could still break them. Suppressed dice contribute
no result. A combination ability must state its minimum dice requirement, avoiding
an accidental one-die combination when Bind removes other dice.

Combination effects explicitly state the value they read: matched value, sequence
total, a fixed number, or another declared formula. They do not inherit an ambiguous
"high roll" amount from ordinary abilities.

## 3. Damage and cooperation

**Enemy damage applies to every living player.** Each player absorbs that damage
with their own block and takes their own remaining HP loss. Damage is not divided
between the party, and attacks do not select one player as their victim.

For example, an attack for 6 against players with 4 and 0 block causes 2 and 6 HP
loss respectively. Skills that grant another player block and effects that control
the enemy retain their cooperative value. Player attacks retain their enemy targeting.

**Enemy debuffs also apply to every living player**, including die theft, poison,
stun, vulnerability and block removal. Passive fog/burial and reflected damage follow
the same party-wide rule. The moth's reroll drain reaches the whole party while
retaining its existing nonlethal HP cost.

## 4. Bind, Dread and enemy upgrades

**Agreed:** Bind suppresses a die, including an enemy's last die. It is a lighter
form of stun against enemies with multiple dice. A bound one-die enemy has no roll
and no roll-triggered abilities during the affected action phase.

**Agreed:** Dread temporarily lowers enemy dice tiers: d6 becomes d4, d12 becomes
d10. Dice return to their appropriate tier when the effect ends. It replaces the
current mechanic that downgrades a selected move.

**Implemented:** the Foreman can buff its dice upward for the rest of the fight,
with an explicit ability row explaining the upgrade.

**Implemented defaults:**

- Tier ladder: **d2 → d3 → d4 → d6 → d8 → d10 → d12 → d16 → d20 → d24 → d30 → d40 → d50 → d60 → d100**. Clamp at d2 and d100;
  Dread lowers d4 to the crystal d3, and d3 to a coin. It never removes dice.
  Unusual sizes come through tier changes; starting encounter dice are unchanged.
- Bind suppresses the last available dice in the displayed order for the next enemy
  action phase. Mark those slots visibly. Its existing enhanced version suppresses two.
- Dread lowers all the target's dice by one tier for a stated number of enemy action
  phases, beginning with the next one. Convert its current 1/1/2/2/3 move-count ladder
  into 1/1/2/2/3 phases of duration. Reapplication refreshes to at least the new
  duration, without accumulating tier penalties. Its existing enhanced version
  affects every enemy. Carat scales the duration directly, so a heavier Dread
  remains useful while repeated applications still refresh rather than stack tiers.
- Expire these durations after an affected enemy action phase, including one skipped
  through stun or complete suppression, so timing is predictable.
- A permanent enemy upgrade lasts **for the rest of the fight**. Show the tier change
  as the buff resolves; it affects dice that have not rolled yet and future turns.
- Compute effective tiers from the base dice, fight-long upgrades and temporary
  penalties. Remove only the expired penalty. Expiring Dread must not erase an
  upgrade gained while it was active, and neither effect changes a revealed result.

Absolute conditions remain absolute: "roll a 6" cannot activate on a d4. A
"maximum face" condition instead follows the effective die's top. The ability's
wording must distinguish these. An upgrade or downgrade must not create a gap in
the ordinary moveset's coverage unless that exception is intentional and visible.

## 5. Compact and expanded presentation

The compact enemy plate retains health, statuses, ordered dice types and ability
icons. Hover reveals the full list; a dedicated toggle pins it open without changing
the selected attack target. The acting enemy's full panel opens automatically and
remains visible throughout its dice and abilities.

Keep the panel in a stable, readable position. It must fit without scrolling, and
leave the acting creature and player defenses visible. Most tables stay small
enough to make this practical. A future unusually large table needs a deliberate
layout rather than an overflowing list.

Rows distinguish these states with marks/text as well as color:

| State | Meaning |
| --- | --- |
| Unrevealed | Planning; no roll is known |
| Pending | A combination can still be completed by remaining dice |
| Activated | Queued for this roll |
| Resolving | This ability is currently being enacted |
| Resolved | Completed; an ordinary row can activate again on the next die |
| Missed | Did not qualify for this roll, or the combination is now impossible |
| Used | A once-per-turn combination has already fired |

Keep revealed results visible beside the unrevealed dice. To explain a completed
sequence, animate the contributing results into sorted order beside the ability
before it resolves. This is a presentation arrangement: preserve die identities
and the fixed order of any remaining rolls. The main row can keep its original
positions while visual copies assemble the combination at the ability.

## 6. Rolling, powering and resolving

For each die:

1. Emphasize its slot and bring up a large 3D die beside the full moveset.
2. Roll, settle on the actual face, and punctuate the value with a short impact
   pulse/effect and sound.
3. Light activated rows, fade misses and update pending combinations.
4. In list order, send energy from the contributing dice into the active row,
   using the resonance-flight treatment as a reference. Animate each positive
   effect amount from 1 to its final value, drawing on the appraisal count-ups.
5. Emphasize the row while the enemy performs the corresponding animation.
   Damage, block, healing and statuses visually land at the appropriate impact.
6. Mark the row resolved, retain the die result, and advance to the next ability
   or die.

Count-ups use a short, bounded duration rather than a delay per integer. A value
of 1 receives a pulse; a zero amount must not briefly claim a positive effect.
Combat speed settings govern the entire sequence, including suspense and count-ups.

### Suspense for major combinations

For explicitly significant abilities, a real near-completion can prolong the last
die's roll like the last reel of a slot machine. Example: a 3d4 enemy with a major
triple ability has revealed two 3s, and its last d4 could complete the triple.

Build audio tension and gently increase the rolling die's scale. A small camera
movement is optional; die scaling is the default so the table remains readable.
Respect motion and sound settings. The beat ends in a clear payoff or release.

Choose suspense from **already revealed results, remaining dice and the ability's
importance**, before consulting the upcoming result. Play it for both wins and
misses under the same conditions. Never delay because a hidden winning result is
already known, and never use the beat for an impossible combination. Keep it rare
and bounded so normal turns remain quick.

## 7. Baseline content and balance

Cave Tick has one d6:

| Ability | Activation | Effect |
| --- | --- | --- |
| Bite | Always | Deal Rolled value damage to every player |
| Latch | Roll a 6 | Suppress one die for every player’s next turn |

A six causes Bite, then Latch. Latch does not inherit the old move's extra damage.

Use a single larger die for a wide damage range; use multiple smaller dice for
more consistent total damage and repeated activations. Mixed dice such as d6 then
d20 visibly build toward a more dangerous roll. Reserve pair/triple/sequence bonuses
for enemies whose identity benefits from them.

Retune enemies for their complete turn, not just one activation. Flat damage bonuses,
depth scaling, enrage, poison and other per-hit effects can multiply with die count.
Party-wide damage also changes multiplayer balance. Audit abilities that formerly
paid for hitting every player; that target scope is now the baseline. Avoid making
ordinary unseen rolls routinely lethal from healthy starting states.

## 8. Implementation and acceptance

- `sim/creatures.gd`: replace whole-hand published intents with visible movesets,
  ordered effective dice, individual rolls and per-turn combination tracking.
- `sim/battle.gd`: step through roll and ability events; apply controls before rolls;
  send enemy damage through each player's existing defense pipeline. Keep one
  authoritative result stream for local play, multiplayer and replay.
- `sim/patterns.gd` / `sim/rules.gd`: give enemy conditions explicit current-die or
  revealed-history scope and amounts; add temporary tier changes and fight upgrades
  without changing player gem semantics.
- `content/deep_cut.json`: migrate every enemy and phase to the new conditions,
  dice and effect rules; revise Bind/Dread text and balance.
- `view/battle/battle_screen.gd`, dice views, effects, audio and inspector: replace
  published intentions with the expandable table and synchronized roll sequence.
- `net/session.gd` and state patches: carry ordered roll/ability events and enough
  current progress for reconnects. Planning data contains no future enemy result.

Rules resolve in the simulation; animation displays those results. Hurrying or
skipping presentation must not change RNG use, activation order, damage or durations.
Do not generate future dice early merely to animate them. An enemy that dies before
its action makes no rolls; stop remaining work when combat ends.

Verification should cover repeated ordinary activations, overlapping rows, pair then
triple, unordered sequences, final-die all-odd/even, suppressed last dice, tier
restoration with intervening buffs, independent player block, and deterministic
multiplayer order. Validate ordinary coverage across all reachable die tiers and
enemy phases. Visually check hover/pinning, multiple enemies, table fit, combination
arrangement, suspense on both success and failure, and effect timing at normal and
accelerated combat speed.

## 9. Implementation notes and verification

All eleven creature definitions and their boss phases use the new rules. Most have
one die; Magpie uses 3d4, Glass Wyrm uses d4 → d6 → d8, the Foreman uses d6 → d12,
and the Drill uses d6 → d20. The Foreman's upgrades change unrolled dice immediately
and last for the fight. Revealed dice retain the shapes and values they actually rolled.

The host emits `enemy_begin`, `enemy_roll`, `enemy_ability`, `enemy_move` (impact),
and `enemy_end` events. Damage is applied at impact, after the preceding event has
allowed the panel to power up and the creature to wind up. Network version 0.2.0
requires matching clients. A restored view displays the existing result without
replaying a roll. Standard combat speed scales the events and their animations together.

`view/battle/enemy_panel.gd` owns hover/pinning, row states, the large die, combination
assembly and amount count-ups. The table stands opposite the selected creature and
reserves space for ally cards. Its visible damage formulas include depth, mirror and
enrage bonuses. Boss phases have separate inspector tabs to keep every page readable.

Validation: `test_enemy_turns.gd` exercises sequential resolution, control effects,
combination timing, party-wide effects, patch equivalence and ordinary activation
coverage at every die tier. `test_enemy_ui.gd` exercises reveal timing, count-ups,
impact, cancellation and restoration at accelerated time. `test_fit.gd` checks every
enemy panel and phase alongside the existing screens. The full suite's assertions
pass; its runner still reports the existing two-shader RID leak from `test_view.gd`,
reproduced on the unchanged repository baseline.

`tools/enemy_gallery.gd` provides planning, roll, reveal, power, impact, suspense,
combo and miss screenshot fixtures. GPU captures on the implementation machine
returned graphics-driver memory errors, so rendered appearance remains unverified.
