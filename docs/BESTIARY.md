# The Bestiary: creatures for every mine, and the mechanics they fight with

October 2, 2026. Implemented from the owner's bestiary page (the claude.ai artifact "Deep Cut
Bestiary": 53 creature cards and 16 mechanic cards). The units plan it was paired with was
behind a sign-in wall and could not be read, so this is the bestiary built as written, plus
the small additions listed in §6. Where the page left a rule open, §5 says what was chosen and
why; each of those is a question for the owner.

Everything here is data in `content/deep_cut.json` and rules in `sim/`. The browser at
`tools/data-browser` mirrors it (`node tools/data-browser/server.mjs`), and
`tests/test_bestiary.gd` exercises every mechanic through real battle steps.

## 1. What a creature is now

A creature entry gained four things:

- **`traits`**: a dictionary of what it is, as opposed to what it rolls for. The old single
  `gimmick` string is read as one of these, so the Quarry's creatures are unchanged. A phase
  may carry its own `traits`, which override the base ones while that phase holds (a value of
  `0` or `false` takes a trait away: the Drill stops rolling your dice for you once it is hurt,
  the Hollow Crown loses its Bedrock once cracked). `DeepCreatures.traits_for(enemy)` is the
  one place that merges them. The full list is `DeepContent.TRAITS`.
- **`escorts`**: creatures that walk in beside it (the Prismarch's three Prisms, the Heartrot's
  three Tendrils). They are ordinary creatures with `summon_only: true`, never found in a band.
- **`echo`**: `{mines: [...]}`. The creature is a copy of a random ordinary creature from those
  mines' bands: health, dice, moves, phases and traits are the original's, scaled for the
  mine it is met in; only its name says what it is (the Void Echo).
- Moves may carry **`once: true`** (it fires once a fight and is then shown SPENT) and a trigger
  may name **`die: n`**, the one die an ordinary move reads (the Hollow Crown's d20 rules).

### Triggers read from the action

Four trigger kinds read the fight rather than a die, and each fires at most once an action:

| Kind | Fires |
| --- | --- |
| `each_turn` | on the first die of every action |
| `every_nth_turn` (amount n) | on the first die of the n-th, 2n-th… action; the table and the chips show "in N actions" |
| `emerge` | on the first die of the action after it burrowed |
| `on_death` | never during an action: when the creature dies, with the creature as the source (shown ON DEATH) |

### Effects

New creature-only effect kinds (`DeepRules.CREATURE_KINDS`; a stone may not use them):
`summon`, `purge`, `burrow`, `adapt`, `festering`, `corroded`, `scorched`, `die_lock`,
`invert_dice`, `steal_gold`, `empower_next`, `drain_resonance`, `rally`, `grow_die`, `swell`,
`hold_gem`, `bury_socket`, `charge`. Damage may carry `piercing` (ignores block) or
`split_party` (divided across the living party, rounded up). New targets pick one player:
`hero_least_block`, `hero_most_hp`, `hero_most_gold`, `hero_top_damage` (whoever hurt it most
this turn), `hero_top_dealt` (whoever dealt the most last turn), `hero_marked` (every Marked
player), and `allies_other` (every other creature). The elite spoils gained `pick` (`high`
for the biggest die) and `break_gem` gained `permanent`.

A creature's hostile effect is still turned on the whole party, unless it names one player or
itself (a Croupier Crab stuns itself on a 1). A creature's own Ward never turns away what it
does to itself.

## 2. The sixteen mechanics, as built

| Card | Built as | Where |
| --- | --- | --- |
| Festering | status on players: healing received is halved; counts down 1 at the tick (a fresh enemy application survives the tick that follows it) | `_heal` |
| Corroded | status: as the turn opens, after Retain has kept what it keeps, half of that block is lost | `_begin_turn` |
| Scorched | status: block gained is halved, rounded up; counts down 1 a turn | `_apply_one` "block" |
| Piercing | `piercing: true` on a damage effect: block is not touched | `_damage` |
| Steadfast | trait: Stun, Bound (die_steal), Clouded and Dread applications are halved (rounded up, at least 1); after an action lost to Stun the next Stun is resisted until it has acted | `_apply_one`, `enemy_begin` |
| Purge | effect: sheds that percent of its own poison (100 for most, 50 for a boss) | `_apply_one` |
| Summon | effect: that many of the named creature join beside it, bred to the same depth, acting from the next turn; `max_creatures` (4) standing at most | `DeepBattle.summon` |
| Burrow | effect: it ends its action and cannot be targeted until its next action; gems aimed at it hit another creature, gems that hit every creature miss it; it emerges as it next acts (`emerged` on the `enemy_begin` event) | `_targets`, `enemy_roll`, `enemy_begin` |
| Adapt | effect: until its next action it takes that percent less from one colour: the colour that hurt it most this turn (`most_damage`), the colour the party sets most (`most_used`), one at random, or one named; with `reflect` it mirrors instead (the gem's whole blow lands on its owner, none on it) | `_adapt`, `_damage` |
| Bedrock | trait: no single hit's HP loss exceeds that percent of its max HP (`capped` on the hit) | `_damage` |
| Backlash | trait: while it lives, every gem past `backlash_after` (6) to fire in one turn costs its owner 1 HP, never the last | `resolve_gem` |
| Flee | trait: after that many actions it leaves (`fled`, HP 0, the `enemy_end` event says so); what it stole goes with it; the view plays a flight, no shards and no spoils | `enemy_roll` |
| Invert | effect: next turn, after the roll, that many highest dice shift to the other parity (Sleight's rule) | `_begin_turn` |
| Echo | `echo` on the creature, see §1 | `DeepCreatures.make` |
| On death | `on_death` moves, see §1 | `_on_enemy_death` |
| Unmake | effect: Resonance goes to 0 at once, any Charged is lost, and the status `unmade` holds the next rail at 0: gems fire, but the chain counts for nothing until that rail closes | `_apply_one`, `rail_begin`, `resolve_gem`, `rail_end` |

Also built because the cards needed them: `die_lock` (the die comes up next turn showing what it
shows now and cannot be rerolled), `steal_gold` (a flat amount or a percent of each purse, held
by the creature, recovered on its death), `empower_next` (its next attack deals that percent
more; spent on the first attack it makes), `rally` (every creature deals that much more this
turn), `grow_die` (another die up to a cap), `swell` (a counter its burst reads), `hold_gem` (a
gem comes off a rail into its keeping until it dies: the gem that hit it hardest, or the finest on
any rail; never a rail's last gem), `bury_socket` (the socket under the heaviest gem),
`charge` (a blow wound up over turns and let go, cancelled by taking a share of its health),
`dice_dread` on a player (the bowl rolls a size smaller next turn), and traits for the auras
(`aura`), the Heartrot (`regen_with_escorts`, `regrow_escorts`), the Prismarch
(`shielded_by_escorts`, `punish_straight`), the Drill (`spikes`, `escalate`), the Unmade
(`rising`) and the Hoard Mimic (`drops_stone`: a raw stone for its killer, settled with the fight).

## 3. The mines

Every mine has its own two Wardens and its own final boss now; the Foreman, the Mirror Regent and
the Drill are the Quarry's. Bands were rebuilt from the page's bleed lists. A variant never
appears within one mine of the creature it is based on, or of another variant of it
(`tests/test_bestiary.gd` checks this against the bands).

| Mine | New creatures | Wardens | Boss |
| --- | --- | --- | --- |
| Quarry | Rail Rat, Pit Mole | the Foreman, the Mirror Regent | the Drill, rebuilt |
| Seeps | Seep Eel, Drowned Miner, Lamprey Knot, Cave Crayfish | the Lock-Keeper, the Drowned Choir | the Undertow |
| Glass Veins | Prism Golem, Shard Wyrm, Glint Magpie, Will-o’-Wisp, Echo Sprite, Lens Beetle, Refractor | the Glazier, the Kaleidoscope | the Prismarch (with three Prisms) |
| Warrens | Spore Slime, Mycel Wraith, Cap Shambler, Mycel Weaver, Puffball, Root Horror | the Gardener, the Spore Mother | the Heartrot (with three Tendrils) |
| Furnace | Fire Tick, Cinder Moth, Salamander, Slag Hound, Forge Imp, Ember Crawler | the Smelter, the Anvil Knight | the Kiln Wyrm |
| Geode | Gilded Magpie, Geode Golem, Amethyst Wyrm, Hoard Mimic, Croupier Crab, Crystal Hydra | the Assayer, the Collector | the Hollow Crown |
| Rift | Void Echo, Null Shade, Riftling Swarm, Entropy Eye | the Remembered (see below) | none: it does not end |

**The Rift's Wardens.** Every eighth floor a boss from above comes back as *the Remembered*:
the Drill, the Undertow, the Prismarch, the Heartrot, then the Kiln Wyrm, and round again, each
with one trait more picked by the seed (Steadfast, Bedrock 25% or a remembered Adapt that turns
half of the colour that hurt it most away every turn). Every fifth Rift Warden (floors 40, 80,
120…) is the Unmade instead. The Hollow Crown is left out because the Geode is next to the Rift.
`mines.RIFT.wardens` is the cycle, `unmade` and `unmade_every` the exception;
`DeepDescent.warden_key` does the counting.

## 4. Presentation

- **Chips.** Every new status and creature state has a chip with its sentence: Festering,
  Corroded, Scorched, Unmade, Dread and locked or inverted dice on a player; Burrowed, Adapted
  (in the colour), Mirroring, Charging (with the count), Empowered, Rallied, Swollen, Holding
  gems, Leaving (a Flee countdown), Echo, Escort, Remembered, and a countdown chip for every
  move that fires every so many actions. Every trait is a chip too (`EffectChips.TRAITS`).
- **The moves table** names the new kinds, marks ON DEATH and SPENT rows, says "in N actions"
  beside a periodic move, and reads the creature's traits out as a row of pills with their
  sentences on hover. The close look reads moves four to a page, so a six-move boss phase
  never runs off the bottom, and lists what the creature is and what each phase changes.
- **In the room**: a burrowing creature sinks under the floor and erupts back with rubble; an
  adapted creature wears a halo in the colour it turned away and a mirrored blow is beamed
  back at the player; a charging creature pulses brighter; a summoned creature arrives in a
  flash and a ring; a fleeing one flies off in a shower of the pyrite it took; a dying Puffball
  bursts; held gems are torn off the rail and fly to the creature; Bedrock, piercing, Backlash
  and Unmake all say so where they land. A Void Echo is drawn as the creature it copies, violet
  and half there.
- **Models.** Variants reuse their base scene in their own colours (`CrystalCreature.VARIANTS`).
  Every new creature has a scene baked by `tools/creature_bake.gd` from a data recipe in
  `tools/creature_recipes/<mine>.gd`; `tools/creature_sheet.gd` photographs any set of them to
  one contact sheet. Scenes gained an optional accent material for their brightest parts. See
  `docs/CREATURE_SCENES.md`.

## 5. Interpretations the page left open

1. **Unmake.** "Sets a player's Resonance to 0" would do nothing at the moment a creature acts,
   since Resonance is spent by then. It was built as: Resonance to 0 now, any Charged lost, and
   the *next rail held at 0* until it closes. That is a real anti-combo tool (the Rift's stated
   purpose) and the chip explains it. If the owner meant only "lose your Charged Battery", drop
   the `unmade` hold in `resolve_gem`.
2. **Locked dice.** "Locks your highest die for your next turn" was built as: the die comes up
   next turn showing exactly what it shows now and cannot be rerolled. It can help as well as
   hurt (a locked 20 is a gift), which is why it reads as a fair shock rather than a theft.
3. **Dread on a player** (the Drowned Miner's Pull Under) had no rule: the whole bowl rolls a
   size smaller next turn, the dice themselves untouched.
4. **Corroded** takes half the block *kept* at turn start. Since ordinary block already falls
   off at turn start, it bites only Retain builds, which is what the Ember Crawler's test line
   ("keeping block from one turn to the next") says it is for.
5. **Hold a gem** (Mimic, Collector): one gem per firing, never a rail's last gem; the
   Collector's "highest-grade" is the gem of highest sale value on any rail.
6. **The Heartrot's regrowth**: a dead tendril grows back when the heart next acts two or more
   turns after it died, unless all three died within two turns of each other, in which case they
   stay dead for the fight.
7. **The Prismarch's charge** re-arms after every release (the card does not say once).
8. **"A straight"** for the Prismarch's lock is a run of four, Cadence's small straight
   (`punished_straight`).
9. **Summons act from the next turn**, not the turn they arrive.
10. **Steadfast** also halves Dread, as the kin of the three controls it names.

## 6. Logical additions beyond the cards

- The Spore Mother, the Entropy Eye and the Heartrot had no ordinary attack, which would leave a
  die with nothing to do (and would fail the coverage rule that every face activates something):
  Writhe (the roll), Gaze (3 flat) and Rot (4 flat) were added. The Gardener keeps only Prune, as
  written, since its Puffballs are its damage.
- The Unmade had no attack either: Unmaking (the roll) was added beside Unmake, Rising and Adapt.
- The Drill keeps its Spikes 3 and its escalation into its last phase (the card lists them only
  for 60–30%); a boss should not soften as it dies.
- The Undertow's Bite and Drag Under stay on its moveset through every phase, and its dive turn
  still bites with the die that dives.
- Variants: Fire Tick's Ignite needs 6 or more on a d8, as the card says; Glint and Gilded Magpies
  steal through the shared `steal_gold` trait (×1 and ×3).
- Mines got new one-line descriptions naming their Wardens and bosses.
- `max_creatures` (4), `backlash_after` (6) and `punished_straight` (4) are constants in the pack.

## 7. Open questions for the owner

- The paired units plan could not be read (it needs a sign-in). If it carried verdicts on the
  cards or changes to them, those are not reflected here.
- Are the three added attacks (§6) wanted, or should those bosses truly rely on summons and
  statuses alone?
- Unmake's reading (§5.1) is the strongest call made here; is holding a whole rail at 0 too much
  for an ordinary Rift creature on a 10+ (25% of its actions)?
- Should the Collector's Acquire take one gem from *each* player in co-op, or one from the party
  as built?
- The Remembered's adapt trait is "half of the colour that hurt it most, every turn"; the card
  says only "Adapt". Steadfast and Bedrock 25% are as the card lists.
