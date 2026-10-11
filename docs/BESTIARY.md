# The Bestiary: creatures for every mine, and the mechanics they fight with

October 2, 2026, revised October 5. Built from the owner's bestiary page (the claude.ai artifact
"Deep Cut Bestiary": 53 creature cards and 16 mechanic cards). The page saves a verdict and a
note on every card in its database (collection `verdicts`); the first build read the cards but
not those, so it was the page as first proposed. This revision applies all 69 verdicts: 28
approved (one, the Mycel Wraith, with new dice), 36 changed as the notes asked, and 5 turned
down and taken out. §7 lists
every one. Where a note left a rule open, §5 says what was chosen and why; each of those is a
question for the owner.

Everything here is data in `content/deep_cut.json` and rules in `sim/`. The browser at
`tools/data-browser` mirrors it (`node tools/data-browser/server.mjs`), and
`tests/test_bestiary.gd` exercises every mechanic through real battle steps.

## 1. What a creature is now

A creature entry gained five things:

- **`traits`**: a dictionary of what it is, as opposed to what it rolls for. The old single
  `gimmick` string is read as one of these, so the Quarry's creatures are unchanged. A phase
  may carry its own `traits`, which override the base ones while that phase holds (a value of
  `0` or `false` takes a trait away: the Drill stops rolling your dice for you once it is hurt).
  `DeepCreatures.traits_for(enemy)` is the one place that merges them. The full list is
  `DeepContent.TRAITS`.
- **`escorts`**: creatures that walk in beside it (the Prismarch's three Prisms, the Heartrot's
  three Tendrils). They are ordinary creatures with `summon_only: true`, never found in a band.
  A creature that summons one of its own escorts (the Heartrot growing a Tendril) adds it to
  them.
- **`echo`**: `{mines: [...]}`. The creature is a copy of a random ordinary creature from those
  mines' bands: health, dice, moves, phases and traits are the original's, scaled for the
  mine it is met in; only its name says what it is (the Void Echo).
- **`gems`**: skills it walks in holding as gems of its own (the Collector's Strike and Bulwark).
  They sit with any gems it takes, and nobody gets them back when it dies.
- Moves may carry **`once: true`** (it fires once a fight and is then shown SPENT) and a trigger
  may name **`die: n`**, the one die an ordinary move reads.

A creature may also start with **no dice** if a move that opens its action grows its first
one (the Infinite Void).

### Triggers read from the action

Six trigger kinds read the fight rather than a die, and each fires at most once an action:

| Kind | Fires |
| --- | --- |
| `each_turn` | on the first die of every action |
| `every_nth_turn` (amount n) | on the first die of the n-th, 2n-th… action; the table and the chips show "in N actions" |
| `emerge` | on the first die of the action after it burrowed |
| `action_begin` | as its action opens, before any die is thrown (shown "As each action opens") |
| `on_death` | never during an action: when the creature dies, with the creature as the source (shown ON DEATH) |
| `hp_below` (amount n) | never during an action: once, the moment its health first falls to n% of its most, from a blow or from poison or burning (shown ON DEATH-style as latent, then SPENT) |

Creature moves on a die read that die alone, so `crowns`, `value`, `at_least`, `odd`, `even`
and `high_pct_at_least` (51 is "a high roll: over half its die") fire on every die that
qualifies. Combinations (`pair`, `triple`…) read the whole hand and fire once an action.

### Effects

New creature-only effect kinds (`DeepRules.CREATURE_KINDS`; a stone may not use them):
`summon`, `purge`, `burrow`, `festering`, `scorched`, `burn`, `strength`, `die_lock`,
`steal_gold`, `empower_next`, `rally`, `grow_die`, `swell`, `hold_gem`, `bury_socket`,
`exhibit`, `charge`, `reflect`, `mirror`, `absorb_color`, `blank_face`, `roll_again` and
`end_action`. Damage may carry `piercing` (ignores block), `split_party` (divided across the
living party, rounded up) or, from a creature, `flat` (its own number and its Strength,
without the mine's multiplier or the depth bonus); a creature's `spread` deals its hits round
the party one at a time. New targets pick one player: `hero_least_block`, `hero_most_hp`,
`hero_most_gold`, `hero_top_damage` (whoever hurt it most this turn), `hero_top_dealt`
(whoever dealt the most last turn), `hero_marked` (every Marked player), and `allies_other`
(every other creature). New terms: `party_richest` (the richest player's pyrite) and
`strength` (its own Strength).

The elites' dice spoils gained picks and a lifetime. `downgrade_die` may take `pick: "all"`;
`grind_die` may take `pick: "showing"` (the face every die lies on); `break_die` and
`break_gem` may be `permanent` (gone for the rest of the fight rather than until next turn);
`grind_die` that is `permanent` is for good. **Everything a creature does to a die for the
fight is undone when the fight is**: `DeepBattle.dice_after_fight` gives the bowl back as it
came in, and the descent settles a fight with it. Before this a shrunk or ground die stayed
that way for the run, whatever the card said.

`steal_gold` gained `hurt` (each player is hit for what was taken from them), `hold_gem`
gained `pick: "usable"`, `dice_upgrade` gained `cap` (a die shape it stops at), and `cleanse`
now clears Burn, Festering, Scorched and bound dice too.

A creature's hostile effect is still turned on the whole party, unless it names one player or
itself (a Croupier Crab stuns itself on a 1). A creature's own Ward never turns away what it
does to itself.

## 2. The mechanics, as built

| Mechanic | Built as | Where |
| --- | --- | --- |
| Festering | status on players: healing received is halved; counts down 1 at the tick (a fresh enemy application survives the tick that follows it) | `_heal` |
| Scorched | status: block gained is halved, rounded up; counts down 1 a turn | `_apply_one` "block" |
| Burn | status: at the tick, after poison, it hurts for its stacks like poison, but block soaks it first; then it loses one stack | `_burn_tick` |
| Strength | status on a creature: a point more on every blow it deals, for the fight. A split twin does not inherit it | `resolved_move`, `display_moves` |
| Piercing | `piercing: true` on a damage effect: block is not touched | `_damage` |
| Steadfast | trait: Stun, Bound (die_steal), Clouded and Dread applications are halved (rounded up, at least 1); after an action lost to Stun the next Stun is resisted until it has acted | `_apply_one`, `enemy_begin` |
| Purge | effect: sheds that percent of its own poison (100 for most, 50 for a boss) | `_apply_one` |
| Summon | effect: that many of the named creature join beside it, bred to the same depth, acting from the next turn; `max_creatures` (4) standing at most | `DeepBattle.summon` |
| Burrow | effect: it ends its action and cannot be targeted until its next action; gems aimed at it hit another creature, gems that hit every creature miss it; it emerges as it next acts | `_targets`, `enemy_roll`, `enemy_begin` |
| Sturdy (was Bedrock) | trait: no single hit's HP loss exceeds that percent of its max HP (`capped` on the hit) | `_damage` |
| Backlash | trait: while it lives, every gem that fires costs its owner 1 HP, wherever it sits on the rail, never the last | `resolve_gem` |
| Flee | trait: after that many actions it leaves (`fled`, HP 0); what it stole goes with it. A countdown chip on its plate says how many actions it has left | `enemy_roll` |
| Echo | `echo` on the creature, see §1 | `DeepCreatures.make` |
| On death | `on_death` moves, see §1 | `_on_enemy_death` |
| Refract | effect `reflect`: until its next action, that percent of every blow it takes goes back at every living player (Prism Golem, 50) | `_damage` |
| Mirror | effect `mirror`: the next blow on it goes back whole at whoever threw it, and it takes nothing; it waits until a blow comes (Echo Sprite) | `_damage` |
| Drinking a colour | effect `absorb_color`: until its next action, gems of that colour do it no damage, and the block, healing, Retain, Regeneration, Ward, Spikes or most health they would give their owner goes to it instead (the Kaleidoscope; a pair drinks a second colour, `add`) | `_damage`, `_apply` |
| Splits | the Silt Slime's trait, now also a Remembered trait; a split never takes the room past four creatures | `_damage` |
| Carat cap | trait `carat_cap`: while it stands no gem counts for more than that many carats (the Assayer, 5) | `rail_context`, `DeepStone.effective` |
| Dampened Resonance | trait `resonance_damp`: gems ring for that percent less; the remainder carries, so two gems at half still make one (the Null Shade, 50) | `resolve_gem` |
| Feeds on colour | trait `colour_strength`: it gains 1 Strength the first time it sees each colour of gem fire (the Refractor) | `resolve_gem` |
| Charge | effect: a blow wound up over actions and let go. `guard_pct` takes that much less meanwhile; `store` lets go exactly what it was dealt; `cancel_pct` breaks it when that share of its health is lost (no creature uses that now) | `_tick_charge`, `_damage` |
| Exhibit | effect: every gem it holds fires as its own move, read against its dice at the gem's Cut and one carat, through the mine's multiplier like any blow; what a gem does to "the enemy" lands on the party, what it does for its owner the creature keeps. Gems that only work the hand, rail or purse do nothing for it | `DeepCreatures.gem_effects` |
| Grow and throw again | `dice_upgrade` with `cap` grows its dice a size; `roll_again` throws the die once more this action (three more at most); `end_action` stops its action | `enemy_roll`, `_apply_one` |
| Fight-only dice | see §1 | `_spoil`, `dice_after_fight` |

**Taken out, as the owner asked:** Adapt (and the Remembered's adapting aura), Corroded,
Invert and Unmake. Their effect kinds, statuses, chips and words are gone from the rules, the
view and the browser.

## 3. The mines

Every mine has its own two Wardens and its own final boss; the Foreman, the Mirror Regent and
the Drill are the Quarry's. A variant never appears within one mine of the creature it is based
on, or of another variant of it (`tests/test_bestiary.gd` checks this against the bands).

| Mine | New creatures | Wardens | Boss |
| --- | --- | --- | --- |
| Quarry | Rail Rat, Pit Mole | the Foreman, the Mirror Regent | the Drill, rebuilt |
| Seeps | Seep Eel, Drowned Miner, Lamprey Knot, Cave Crayfish | the Lock-Keeper, the Drowned Choir | the Undertow |
| Glass Veins | Prism Golem, Shard Wyrm, Glint Magpie, Will-o’-Wisp, Echo Sprite, Refractor | the Glazier, the Kaleidoscope | the Prismarch (with three Prisms) |
| Warrens | Spore Slime, Mycel Wraith, Cap Shambler, Mycel Weaver, Puffball, Root Horror | the Gardener, the Spore Mother | the Heartrot (with three Tendrils) |
| Furnace | Fire Tick, Cinder Moth, Salamander, Slag Hound, Forge Imp, Ember Crawler | the Smelter, the Anvil Knight | the Kiln Wyrm |
| Geode | Gilded Magpie, Geode Golem, Amethyst Wyrm, Hoard Mimic, Croupier Crab, Crystal Hydra | the Assayer, the Collector | the Hollow Crown |
| Rift | Void Echo, Null Shade, Riftling Swarm, Entropy Eye | the Remembered (see below) | none: it does not end |

The Lens Beetle's places in the bands went to the mine's own creatures: the Refractor and Echo
Sprite in the Glass Veins, the Echo Sprite and Mycel Weaver in the Warrens, the Forge Imp in the
Furnace.

**The Rift's Wardens.** Every eighth floor a boss from above comes back as *the Remembered*:
the Drill, the Undertow, the Prismarch, the Heartrot, then the Kiln Wyrm, and round again, each
with one trait more picked by the seed: Steadfast, Sturdy 25%, or Splits. Every fifth Rift
Warden (floors 40, 80, 120…) is the Infinite Void instead (its content key is still
`THE_UNMADE`). The Hollow Crown is left out because the Geode is next to the Rift.
`mines.RIFT.wardens` is the cycle, `unmade` and `unmade_every` the exception;
`DeepDescent.warden_key` does the counting.

## 4. Presentation

- **Chips.** Every status and creature state has a chip with its sentence: Festering,
  Scorched, Burn, Dread and locked dice on a player; Burrowed, Drinking (the colours),
  Refracting, Mirror, Strength, Charging (with what it has stored), Empowered, Swollen, Holding
  gems (its own and those it took), Leaving (the Flee countdown), Echo, Escort, Remembered, and
  a countdown chip for every move that fires every so many actions. Every trait is a chip too
  (`EffectChips.TRAITS`); a Flee shows as its countdown only.
- **The moves table** names every kind, marks ON DEATH and SPENT rows, says "in N actions"
  beside a periodic move, and reads the creature's traits out as a row of pills with their
  sentences on hover. A table with more than four moves, or more than six effects between
  them, is read densely so it still leaves the battle and the dock in view.
- **In the room**: a burrowing creature sinks under the floor and erupts back with rubble; a
  creature drinking a colour wears a halo in that colour, and one refracting or holding a
  mirror wears a pale one; a mirrored blow is beamed back at its thrower; a drunk blow says so;
  a charging creature pulses brighter; a summoned creature arrives in a flash and a ring; a
  fleeing one flies off in a shower of the pyrite it took; a dying Puffball bursts; held gems
  are torn off the rail and fly to the creature; a creature's health falling past a mark plays
  what it does there; Sturdy, piercing, Backlash, Burn (and what block soaked of it), a Strength
  gained, a die thrown again and a stumble all say so where they land. A Void Echo is drawn as
  the creature it copies, violet and half there.
- **Models.** Variants reuse their base scene in their own colours (`CrystalCreature.VARIANTS`),
  and may name a core colour and a size: the Geode Golem is now a grey shell split open on an
  amethyst heart, a size bigger than the violet Prism Golem; the Will-o’-Wisp is pink, not the
  Lantern Moth's blue. Every new creature has a scene baked by `tools/creature_bake.gd` from a
  data recipe in `tools/creature_recipes/<mine>.gd`. The Glazier (a glass spider with a diamond
  saw for a mouth), the Gardener (a great beetle with a garden on its back) and the Assayer (a
  faceless, horned shadow holding its scale) were redesigned as the owner asked, none of them
  human-shaped. `tools/creature_sheet.gd` photographs any set of them to one contact sheet. See
  `docs/CREATURE_SCENES.md`.

## 5. Readings where a note left a rule open

1. **Burn's decay.** "Similar to poison, but can be blocked by armour": it loses a stack a tick
   like poison, so Burn 12 left alone deals 12, 11, 10…; block soaks each round before health.
2. **Strength per blow.** "+damage on each attack" is read per damage effect, so a creature with
   several dice adds it on every die that hits. The Slag Hound's Howl gives every creature 1
   (the card's rally was 2 for one turn; 2 for the whole fight seemed too much); the Anvil
   Knight's Quench gives its odd roll, as written, which grows fast.
3. **Refract** sends back half of the health each blow took, at every player, until it acts
   again. **Mirror** sends a blow back at whoever threw it and waits for that blow, however
   long. The Echo Sprite's mirror throws back the whole blow at its thrower, not the party.
4. **The Kaleidoscope's drink** keeps the original rule that the colour does it no damage, and
   adds that what a gem of that colour gives its owner (block, healing, Retain, Regeneration,
   Ward, Spikes, most health) goes to it. Its Turn adds the party's most-used colour it is not
   already drinking, until its next action.
5. **The Prismarch's charge** takes one action and comes every other action, so the party has a
   turn to hit it in full between charges. While it charges it takes half, and it throws back
   everything it was dealt (before the halving), through block. Its Lancet hits every player.
6. **The Gardener's Prune and the Glazier's Cut are for good** (the run): the notes say
   "permanently" and "PERMANENT". Everything else done to dice is for the fight: the Smelter's
   Melt, the Forge Imp's Heat Treat, the Entropy Eye's Unmake and the Infinite Void's dread.
7. **The Assayer's carat cap** caps the carat a gem counts as, inclusions and fight buffs
   included; its Tax hits each player for exactly what it took from them; Eat the Rich heals
   by the richest player's pyrite and grows its most health by as much.
8. **The Collector** takes one gem from the party per pair, the finest it can use (one whose
   effects hit the party or help it), or the finest of all if none can be used; never a rail's
   last gem. Its gems fire at one carat through the mine's multiplier, against its own dice:
   a stolen 20-carat gem would otherwise one-shot the party.
9. **The Hollow Crown.** "Stuns self (ends its turn and deals no damage)" is built as exactly
   that: a 1 ends its action, and it does not lose the next. A high roll is over half its die
   (4–6 on a d6); it grows the die a size, up to a d20, and throws again, three times more at
   most. Its magpies come the moment it falls to half, from any blow.
10. **The Infinite Void** keeps the Unmade's Sturdy 10% and Backlash; its Rising went with the
    old moveset, since a d20 more every action is its escalation. It grows five d20s at most and
    hits for each roll (Consume), which it needs to be a threat at all.
11. **The Null Shade's** gem-snuffing keeps the trigger its Adapt had (an even roll) and melts a
    gem for the fight. Its halved Resonance is gem-fire Resonance only (not Charged or Crystal
    dice).
12. **The Refractor's Split Light** is its roll in hits of 1 plus its Strength, spread round the
    party one hit at a time; Prism Wall is ten block for each point of Strength, so nothing at
    Strength 0.
13. **Will-o’-Wisp and Cinder Moth** were asked to read their roll and do "possibly some other
    effect": the Wisp's 6 locks one of your dice (Lure), the Cinder Moth's 6 burns the party for
    3 (Embers). Their reroll prices are unchanged.
14. **All Magpie variants flee**: the Glint and Gilded Magpies, after their fourth turn. The
    Quarry's Magpie is the original, not a variant, and does not.
15. **Summons** were already capped at four creatures standing; splitting now respects the same
    cap (it used to allow six entries).

## 6. Logical additions beyond the cards

- The Spore Mother and the Heartrot had no ordinary attack, which would leave a die with nothing
  to do: Writhe (the roll) and Rot (4) were added. The Entropy Eye's Gaze now hits for its roll,
  as the note asked.
- The Infinite Void's Consume (the roll), see §5.10.
- The Kiln Wyrm's basic attack is called Claw, so its crown move can be the Scorch the note asked
  for.
- The Spore Mother's Shed and the Hollow Crown's magpies fire at the moment health falls past
  half (a new trigger), rather than at the start of a phase.
- The Drill keeps its Spikes 3 and its escalation into its last phase.
- The Undertow's Bite and Drag Under stay on its moveset through every phase.
- `max_creatures` (4) and `punished_straight` (4) are constants in the pack; `backlash_after` is
  gone.

## 7. The owner's verdicts, card by card

Approved as written: Rail Rat, Pit Mole, the Drill, Seep Eel, Drowned Miner, Cave Crayfish, the
Drowned Choir, the Undertow, Shard Wyrm, Glint Magpie (but see the Gilded Magpie), Cap Shambler,
Fire Tick, Amethyst Wyrm, Hoard Mimic, Croupier Crab, Crystal Hydra, Void Echo, and the Burrow,
On death, Echo, Festering, Piercing, Purge, Scorched, Steadfast, Summon and Flee mechanics.

Turned down and taken out: **Lens Beetle**, **Adapt**, **Corroded**, **Invert**, **Unmake**.

Changed as the notes asked:

| Card | Now |
| --- | --- |
| Lantern Moth (from the Cinder Moth's note) | Flutter hits for its roll. |
| Lamprey Knot | Latch bites for each die's roll; Drink heals 4 on every 4 rolled, and takes no pyrite. |
| The Lock-Keeper | Open the Sluice removes all block first, then hits. |
| Prism Golem | Refract (even roll): until its next action, half of every blow on it goes back at every player. |
| Will-o’-Wisp | Pink, not blue. Flicker hits for its roll; Lure (a 6) locks one of your dice. |
| Echo Sprite | Twinkle hits for its roll; Mirror (5 or 6) sends the next blow on it back at its thrower. |
| Refractor | Gains 1 Strength per new colour it sees fire; Split Light is its roll in hits of 1 + Strength; Prism Wall is 10 block × Strength. |
| The Glazier | A glass spider, not a person. Cut is for good; Anneal is 10 block. |
| The Kaleidoscope | Absorb (each action): drinks a colour: no damage from it, and its gems' gifts go to it. Turn (a pair) drinks another. |
| The Prismarch | Every attack hits every player. Near death it charges for one action, every other action, takes half meanwhile, and throws all it was dealt back at every player. |
| Spore Slime | Ooze poisons for 1 as well. |
| Mycel Wraith | 2d6. |
| Mycel Weaver | 2d4; Bite hits and poisons for its roll. |
| Puffball | 30 health, a d6; it swells by its roll; a 6 gives it Regeneration 6. |
| Root Horror | 3d4; Grow (a pair): a quarter more health and most health, and Strength equal to the pair. |
| The Gardener | A beetle with a garden on its back. One d20: Tend heals every creature, itself included, by the roll; an even roll plants a Puffball, an odd one a Root Horror; Prune (a 20) hits for 20 and takes a point off every face your dice show, for good. |
| The Spore Mother | 3d6; Brood on every 1; Choke on a 6; Shed (once, at half health) sheds every affliction. |
| The Heartrot | 3d10; no Slough, no regrowth by phase; every 10 grows a Tendril back. |
| Cinder Moth | Flutter hits for its roll; Embers (a 6) burns the party for 3. |
| Salamander | A d12. Scratch (odd): the roll; Ember (even): Burn equal to the roll. **Burn** is new: poison that block soaks. |
| Slag Hound | Howl gives every creature 1 Strength for the fight. |
| Forge Imp | Cackle burns for the roll. |
| Ember Crawler | Bite burns for 4 as well; Spit removes block equal to the roll. |
| The Smelter | 2d8. Pour hits and burns for the roll; Melt (an 8) burns a showing face blank for the fight; Slag Armour (even) is block equal to the roll and Spikes 4. |
| The Anvil Knight | Bulwark is 20 block and Spikes 4; Quench is Ward 1 and Strength equal to the roll. |
| The Kiln Wyrm | No Corroded aura. Claw hits for each roll; Firebreath burns for the pair; Lavafall is 20 damage and 20 Burn; Ember is now Scorch. |
| Gilded Magpie | Every Magpie variant flees, and its plate counts the actions down. |
| Geode Golem | A grey shell split open on amethyst, bigger than the Prism Golem. Harden is block and Retain equal to the roll. |
| The Assayer | A faceless horned shadow. 2d10. No gem counts for more than 5 carats while it stands; Weigh (even): the roll and 1 Strength; Balance (odd): block equal to the roll and 1 Spikes; Tax (a pair): a tenth of each purse and a blow for as much; Eat the Rich (a 10): heals and grows by the richest player's pyrite. |
| The Collector | 3d6. Comes holding a Strike and a Bulwark. Acquire (a pair) takes a gem it can use; Exhibit (a 6) fires every gem it holds. |
| The Hollow Crown | One d6, Sturdy 15% all fight. A 1 stuns it; any other roll hits and shields for the roll; a high roll grows its die and throws again; a crown heals it by the roll and doubles its next attack; at half health two Gilded Magpies come at once. |
| Null Shade | Your Resonance is halved while it lives; Drain hits and heals for the roll; Snuff (even) melts a gem for the fight. |
| Riftling Swarm | 3d4; Nibble hits for each roll; a 4 adds a riftling (a d4); Backlash on every gem. |
| Entropy Eye | Gaze hits for its roll; Unmake (a 1) destroys one of your dice for the fight. |
| The Remembered | The third trait is Splits, not Adapt. |
| The Unmade | Now the Infinite Void: no dice, a d20 more as every action opens (five at most), and Existential Dread (a 20) shrinks every die you carry for the fight. |
| Backlash | 1 health for every gem that fires, wherever it sits. |
| Bedrock | Called Sturdy. |

## 8. Open questions for the owner

- The readings in §5 are calls made where a note was open; the ones that most change how a
  fight feels are Burn's slow decay (§5.1), Strength per die (§5.2), the Prismarch charging
  every other action (§5.5) and the Collector firing gems at one carat (§5.8).
- The Anvil Knight's Quench grows Strength by its roll on every odd die, for the fight; two
  odd rolls can add 15 to every blow after. Is that the intended pace?
- Should the Collector take one gem from *each* player in co-op, or one from the party as built?
- The paired units plan (the "Deep Cut Mine Progression Plan" doc) was not read in this pass;
  if it carries other verdicts on these creatures they are not reflected here.

The Glazier's and the Anvil Knight's Temper and the Drowned Choir's Crescendo were renamed Anneal, Quench and Requiem in October 2026, when those names went to the new Temper and Crescendo gems.
