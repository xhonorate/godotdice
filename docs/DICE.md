# Dice: patterns, etchings and materials

Decided September 29, 2026. This replaces the hard-coded variant dice (`EVEN_D6`,
`SPLIT_D12`, `WILD_D6`, …) and the engraving system with three orthogonal axes that
apply to any die of any size.

**This reverses a previous decision.** `README.md` and `docs/REIMAGINING.md:255` say
"Dice are never bought or swapped in the mine, only worked. [Decided September 22,
2026]". Dice are now sold at merchants and swapped, size for size. Both lines must be
rewritten; this document is the authority.

## 1. A die is four things

```
{ id, shape, pattern, faces: [{value, kind}], material, top? }
```

| Axis | What it changes | Count on one die |
| --- | --- | --- |
| **Shape** | how many faces (d2 … d100) | always exactly one |
| **Pattern** | which numbers sit on those faces | at most one |
| **Etching** | one face's special behaviour | any number, one per face |
| **Material** | the whole die, every face, every roll | at most one |

A die's pattern is baked into its face list when it is made; it is recorded as `pattern`
for display and pricing, but nothing reads it at roll time. Etchings are the face `kind`.
Material is a die-level string. Colour comes from material only (§7).

**Engravings are deleted.** `always_held` becomes the **Sticky** etching, `twin` becomes
the **Twin** etching, `steady` becomes the **Iron** material, and `keen` is dropped — a
pattern does the same job better. The `engravings` content section,
`DeepDice.ENGRAVINGS` and every `roll.engraving` read go away.

## 2. Patterns

Patterns only move numbers. They never add an etching or a material. Legality is by
shape; a pattern is never offered for a die that cannot take it.

| Pattern | Rule | Legal on | Rarity |
| --- | --- | --- | --- |
| **Even** | for `i` in 1…n/2: the value `2i`, twice | d4+ (even-sided) | UNCOMMON |
| **Odd** | for `i` in 1…n/2: the value `2i-1`, twice | d4+ (even-sided) | UNCOMMON |
| **Split** | drop the `2t` middlemost values, add `t` more copies of 1 and of `n` | d6+ | UNCOMMON |
| **Gambler's** | every face showing 6 or 8 becomes 7 | d6–d12 only | UNCOMMON |
| **Paired** | pick `n/2` distinct values from 1…n at random; each appears twice | d6+ | UNCOMMON |
| **Stretched** | face `i` shows `2i`, so the die tops out at `2n` | d4+ (a d100 reads 200) | RARE |
| **Shallow** | face `i` shows `ceil(i/2)`; `top` stays `n` | d6+ | UNCOMMON |

**Split's `t`:** 1 for d6–d16, 2 for d20–d30, 3 for d40+. The face count is unchanged,
because `2t` values leave and `2t` copies arrive.

- d6, t=1 → `1,1,2,5,6,6`
- d12, t=1 → `1,1,2,3,4,5,8,9,10,11,12,12` (identical to today's `SPLIT_D12`)
- d20, t=2 → three 1s, three 20s, and 9–12 gone
- d40, t=3 → four 1s, four 40s, and 18–23 gone

**Gambler's** only touches literal 6s and 8s, which is why it stops at d12: on a d20 it
would change two faces out of twenty and mean nothing.

**Shallow** is the Phial generalised: a d6 becomes `1,1,2,2,3,3` and keeps `top: 6`, so
every face it can show reads as a low die. Rue's Phial becomes a Shallow d6, which
raises its average from 1.67 to 2.0 — a deliberate simplification, tunable by authoring
her die's faces directly if the 0.33 matters.

**Considered and not included:** Crowned (lowest face becomes a second copy of the top).

## 3. Etchings

An etching marks one face. A die may carry several, on different faces. The face `kind`
stays the storage. **`gem` and `mirror` are removed.**

| Etching | Effect | Rarity |
| --- | --- | --- |
| **Wild** | counts as any value for patterns, and as the die's top for totals | RARE |
| **Exploding** | rolls again and adds, up to 3 chains | RARE |
| **Shiny** | +1 Resonance for every gem it helps activate; stacks with itself | RARE |
| **Golden** | +2 pyrite whenever it is rolled or rerolled | UNCOMMON |
| **Tally** | +1 to this face, permanently, every time it is landed on | RARE |
| **Sticky** | the face carries into the next turn instead of being rerolled | UNCOMMON |
| **Twin** | counts as two dice in every set (pair, triple, …) | RARE |
| **Doubled** | the face's value counts double in every calculation | RARE |
| **Locked** | once shown, the die cannot be rerolled for the rest of the fight | detrimental |
| **Blank** | no value, no pattern, nothing | detrimental |

**Sticky, precisely:** a Sticky face that is showing at the end of a turn is *not*
rerolled by the new turn's opening roll — the die keeps that face while the other four
are thrown fresh. The player may still spend a reroll on it deliberately. Because it was
never rerolled it also satisfies `held` triggers for free, which is what the old
`always_held` engraving did.

**Tally has no cap**, and neither does any face (October 8, 2026). It raises the stored face value, so it
also raises the die's `top` (§4) — a Tally d6 sitting at 14 makes its own 1–5 faces count
as low dice. That is a real trade, not a bug: it feeds totals and crowns while quietly
feeding Rue's low-dice triggers too. It ticks up as the face is landed on, with its own
little animation.

**Doubled** doubles the face's *effective* value, so a Doubled 6 on a d6 reads as 12,
tops the die at 12, and pairs with other 12s rather than with other 6s. Good for totals,
`at_least` and crowns; bad for sets and straights.

*Name alternatives for Tally, if it reads wrong: Waxing, Notch, Hunger.*

## 4. Value and `top`

**Stored mutations** change the face itself and last the run: Tally, Blood's kills, a
carver raising a face, an enemy grinding a face down.

**Roll-time modifiers** are computed each throw and never written back: Doubled's ×2,
Iron's and Cloud's second throw, Exploding's chain, Blank's zero.

`top` is the highest **effective** value any face of the die can show — printed value
plus stored mutations, then Doubled, with no ceiling. A pattern may override it
(Shallow keeps the shape's own `n`, which is the whole point of the Phial). Everything
that reads a die against itself reads `top`: crowns, `low_dice`, `high_pct`, `max_total`.

## 5. The material strength bonus

A material's coloured bonus is **not** carat. It is a separate multiplier on the gem's
magnitude, applied on top of carat and clarity, and **it stacks multiplicatively**:

```
boost = 1.5 ^ (matching dice among the dice that fired this gem)
```

One Ruby on a red gem is ×1.5, two ×2.25, three ×3.38, four ×5.06, five ×7.59. The top of
that curve is enormous on purpose — five matching materials on one colour is a whole run
spent building it, and it should read like one. Watch it in play before touching it (§15).

The boost multiplies `eff.magnitude` inside `DeepStone.evaluate` *after* the trigger has
named its dice, and it feeds `DeepRules.carat_procs` too, so whole-number effects
(rerolls, stuns, phantom dice) get more goes rather than a fraction of one. It is
reported on the evaluation as `die_boost`, so the battle log and the forecast can show
it.

## 6. Materials

Rare by design: a material is the biggest single thing that can happen to a die.

| Material | Effect | Rarity |
| --- | --- | --- |
| **Ruby / Sapphire / Emerald / Amethyst / Citrine / Diamond** | +50% strength to gems of RED / BLUE / GREEN / VIOLET / GOLD / WHITE it helps activate | UNCOMMON |
| **Opal** | +50% strength to *any* gem it helps activate | LEGENDARY |
| **Glass** | +50% to any gem it helps activate; **10% per roll to shatter and be destroyed** | RARE |
| **Crystal** | +1 Resonance on every roll and every reroll, no limit | RARE |
| **Iron** | thrown twice, keeps the higher face (a tie keeps the first) | UNCOMMON |
| **Cloud** | thrown twice, keeps the lower face (a tie keeps the first) | UNCOMMON |
| **Fool's Gold** | +2 pyrite on every roll and every reroll | UNCOMMON |
| **Granite** | immune to every enemy die effect: etch, lock, destroy, grind, downgrade | COMMON |
| **Blood** | −2 HP whenever it is **rerolled** (never on the opening roll); the showing face gains +1 permanently whenever an enemy unit dies | RARE |

Notes:

- **Citrine** covers the GOLD colour, which the first draft missed. The game has six
  colours plus OPAL: RED, BLUE, GREEN, VIOLET, GOLD, WHITE.
- **Fool's Gold** is the pyrite material, named apart from the GOLD *colour* so "gold"
  never means two things. It is thematically the currency itself.
- **Glass** rolls its 10% on the opening roll as well as on rerolls, so a Glass die is
  expected to survive about three turns. That is the price of a colourless +50%.
- **Granite** is the answer to the enemy abilities in §11; it is common on purpose.
- **Blood** damage never takes a player below 1 HP, matching `hp_cost`.
- "Ghost" is deliberately not used as a name: `phantom_high` already owns that word.
- Materials are the only thing that colours a die (§7).

## 7. Colour

- Material sets the die's body and edge colour.
- No material → the die keeps its **shape** palette (d4 amber, d6 bone, d8 teal, …).
- Patterns and etchings never change the body colour. An etched face is marked on the
  face itself, as today.

`DIE_PALETTE` in `view/dice/dice_icons.gd` stops being keyed by variant key: the shape
keys stay, every variant key goes, and a material table is added.

## 8. Which die gets used

For anything that cares *which* die activated a gem — Shiny, every coloured material,
Glass, Opal — the hand must prefer the die that matters. One shared comparator, used
everywhere a trigger names dice (`groups`, `ids_by_value`, `DeepHand.read`,
`DeepHand.matching`, and `DeepPatterns.evaluate`'s set and straight paths):

1. a material matching **this gem's** colour (Opal and Glass match every colour)
2. a beneficial etching on the showing face (Shiny, Golden, Tally, Doubled)
3. any material at all
4. everything else

Ties keep the bench order, so the sort is stable and a hand reads the same way twice.

This needs the gem's colours inside the trigger context. `DeepPatterns.evaluate` has no
idea what stone is asking; `DeepStone.evaluate` does. Pass `colors` down through the same
context dictionary that already carries `resonance` and `pyrite`.

## 9. Destruction and replacement

**A destroyed die** — Glass shattering, or an enemy breaking one — is gone for the rest
of the turn. **At the start of the next turn it returns as that character's starting die
for that slot**, plain: base numbers, no etchings, no material. A player never rolls
fewer than five dice for longer than one turn.

**A destroyed gem** follows the same shape: it is replaced by the initial gem that hero
had in that socket, **one turn later**. The socket is empty for that turn.

## 10. Where dice come from

### Merchants

Every merchant offers **one die per player, privately**. The whole stall is now
per-player — stones included — so two players at the same merchant see different stock.
`state.chamber.stock` becomes a map keyed by unit id.

A merchant die's **size is drawn from the sizes that player currently has equipped**, so
Vesper is only ever offered a d4 or a d20 until she works one.

A merchant die always carries **one or two** of the three axes — never none, never all
three:

- 60% one axis, 40% two.
- Axis weights: pattern 45, etching 35, material 20.

**Price** is the shape's base price times a multiplier per variation, rounded:

| Variation | Multiplier |
| --- | --- |
| Pattern | ×1.25 (Stretched ×1.4) |
| Beneficial etching | ×1.5 |
| Detrimental etching (blank, locked) | ×0.6 |
| Material | ×2.0 (Glass ×1.75, Opal ×3.0) |

Examples: Ruby d20 = 22 × 2.0 = **44**. Split d6 = 10 × 1.25 = **13**. Shiny Even d8 =
12 × 1.25 × 1.5 = **23**. Blank Paired d10 = 14 × 1.25 × 0.6 = **11**.

**Buying swaps.** A bought die replaces one of the player's own dice **of the same number
of faces**. The die it replaces is discarded for the rest of the run.

### Rooms

No new chamber kinds beyond one. The map is already thin at weight 5.

| Room | Cards |
| --- | --- |
| **Smithy** (existing) | hammer a die bigger / file it smaller, **plus** **stamp**: the anvil is set for one pattern a night, and it is cut across every face of the die you choose |
| **Carver** (existing) | raise a face / lower a face, **plus** **etch**: the needles are set for one etching a night — choose a die and a face; it bites 60%, cracks the die's best face 10%, or nothing |
| **The Vat** (new, weight 4) | **dip** a die in what is in the vat tonight, **dip it blind** for a material rolled after you choose, or **melt it down** — standard numbers, every etching cleared, the material kept |

A card holds at most four choices, which is why melting lives in the Vat rather than the
smithy: it is the room where a die is remade, and the heat leaving the material alone is
the rule that makes it worth doing.

"Random, rolled after you choose" is the gamble in all three rooms: the player commits,
then the RNG speaks.

## 11. Enemy abilities

Rare, and mostly elites and wardens. Everything here is **run-scoped** — dice reset to
the character's own five at the start of the next run — and everything here is blocked by
**Granite**.

| Ability | Detail | Who |
| --- | --- | --- |
| `mar_die` | put a **blank** or **locked** etching on `amount` random faces | elite |
| `grind_die` | −1 to `amount` face values, permanently, floor 1 | elite |
| `lock_die` | one die cannot be rerolled for the rest of this fight | elite |
| `break_die` | destroy a die; it returns next turn per §9, and never the last one | elite and warden |
| `downgrade_die` | one size smaller, never below **d4** | warden |
| `break_gem` | destroy a gem; it returns next turn per §9, and never the last one | warden |

They are ordinary effect kinds, written in a creature's moves like any other, and they
are all debuffs, so a Ward stops them exactly as it stops poison.

## 12. Persistence

Unchanged and deliberate: **every variation lasts the run only.** `DeepProfile.loadout`
rebuilds each character's five dice from their content defaults, so a bought Ruby d8 does
not come home. The key check at `sim/profile.gd:257` must change from comparing `key` to
comparing `shape`, because variant keys no longer exist.

## 13. Content changes

- **Delete** the `engravings` section.
- **Delete** every variant die entry: `PAIRED_D6`, `ODD_D6`, `EVEN_D6`, `SEVENS_D8`,
  `SPLIT_D12`, `WILD_D6`, `EXPLODING_D6`, `LOCKED_D8`, `MIRROR_D6`, `HOLLOW_D10`,
  `GEM_D8`, `PHIAL`, `GAMBLERS_D6`. Keep `D2`…`D100` as the base shapes.
- **Add** `patterns`, `etchings` and `materials` sections, each entry carrying `name`,
  `key`, `rarity`, `text`, and for patterns its legal size range.
- **Characters' `dice` become objects**, not keys:
  - Florin: five × `{"shape": "D6", "pattern": "gamblers"}`
  - Rue: `{"shape": "D6", "pattern": "shallow", "top": 6}` in place of `PHIAL`
  - everyone else: `{"shape": "D6"}` and friends
- A mine's `dice` pool becomes a **size** pool plus variation weights.

## 14. Code map

| File | Work |
| --- | --- |
| `sim/dice.gd` | new face kinds; delete `gem`, `mirror`, `_resolve_mirrors`, `resolve_mirrors`, `ENGRAVINGS`; material effects in `roll_one`; Sticky carry-over in `roll_hand`; `top` from effective values |
| `sim/patterns.gd` | pattern-generation functions; delete the `gem_face` short-circuit; die preference in the set and straight paths; colours in the context |
| `sim/hand.gd` | delete `gem_face`; `twin` reads the etching, not the engraving; preference-ordered `ids_by_value` and `groups` |
| `sim/stone.gd` | `die_boost` from the dice that fired, applied to magnitude and procs |
| `sim/battle.gd` | `_pay_dues` after every throw; `break_die` / `break_gem` and `_regrow` at the turn's start; `_blood_feeds` where a creature dies; `_spoil` for the elite abilities; the `resolve_mirrors` calls are gone |
| `sim/forge.gd` | `roll_die` builds shape + 1–2 variations instead of picking a content key; pricing |
| `sim/descent.gd` | per-player stalls; the die offer; the Vat chamber and its weight |
| `sim/oddities.gd` | pattern, reset, etch and material actions; `resize` keeps material and etchings |
| `sim/content.gd` | validate the three new sections; drop engraving validation |
| `sim/profile.gd` | loadout matches on `shape` |
| `view/dice/dice_icons.gd` | palette by shape + material; marks for the new etchings |
| `view/gems/gem_mesh.gd` and the 3D die view | material body colour and finish |
| `tools/data-browser/js/sim/*.js` | the JS mirror of `hand`, `patterns`, `forge` and `rules` needs every one of these changes |
| `README.md`, `docs/REIMAGINING.md`, `Buffs.md` | rewrite the "never bought or swapped" line and the engraving table |

## 15. What the screen is told

Every payout is reported so the view can play it where it happened, and nothing is left
for the interface to work out for itself:

- `turn_begin` carries each hand's `dues` (`resonance`, `pyrite`, `hp`, `climbed`,
  `shattered`) and whatever `regrown` came back with it.
- `reroll` carries the same `dues` for the dice actually thrown.
- `gem_fire` carries `die_boost` and the `materials` that earned it.

The battle screen plays them on their own beats — Crystal rings the Resonance count,
Fool's Gold and a Golden face send coins arcing into the purse, Blood takes its price off
the health bar, a Tally face climbs with a mark, and Glass breaks — and the 3D die wears
its material: glass goes see-through, crystal lights from inside, iron reads as metal,
granite as stone.

## 16. Numbers to tune first

1. Glass's 10% per roll — expected life about three turns.
2. The +50% strength step, and whether multiplicative stacking wants a ceiling — five
   matching dice on one gem is ×7.59.
3. Crystal's +1 per roll: up to 3 Resonance a turn from one die, about a gem's worth.
4. Material weight in the merchant axis roll (20 of 100) and the ×2.0 price.
5. Fool's Gold at +2 pyrite, against 10.5 pyrite per depth per player for the lift.
