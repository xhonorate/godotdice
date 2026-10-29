# Creature action dice

October 2026. Every creature throws **action dice**: a die with one of its moves on every face,
no numbers. The owner settled the design over eleven review rounds of the plates rethink
(artifact NMAGkwooypHHUKxsB4tR71, db `plates1`..`plates11`) and four rounds of the creature
rework (artifact WzmfgyGoPjqjYdw7TjTUaz, db `rework1`..`rework4`). The approved cards are the
source of `content/deep_cut.json`'s creatures; `build/rework/gen_content.py` (gitignored) wrote
them from the review data and is kept only as a record.

## Rules of thumb (the owner's)

1. Die size says threat: d4 small, d6 average, d8 tougher, d12 be scared. No d10 is written and
   nothing above d12 (the Hollow Crown's die grows through d10 on its way to d12).
2. Almost every creature has a plain attack face.
3. Passives become faces wherever a face can do it; what stays a trait is visible on the
   creature (splitting, Waterlogged, Sturdy, Steadfast, Acid Armour, the carat cap).
4. A face does one thing.
5. No "below X health" switches.
6. Glance clarity: one icon, one meaning, per creature, and no face on two of a creature's dice.
7. Every ability hits the whole party unless it names someone; the words never say "every player".
8. No "next turn" rider: what lands, lands now, and wears off after your next turn.

## Content

```json
"MAGPIE": {
  "name": "Magpie", "hp": 14, "block": 0, "threat": 2, "text": "...", "tip": "...",
  "dice": [{"shape": "D6", "faces": ["Peck", "Snatch", "Peck", "Snatch", "Peck", "Snatch"]}],
  "moves": [
    {"name": "Peck", "kind": "attack", "mark": "f_sword", "anim": "peck", "text": "{0} damage",
     "trigger": {"kind": "face"}, "effects": [{"kind": "damage", "target": "heroes", "amount": 2}]},
    {"name": "Snatch", "kind": "meddle", "mark": "f_coin_taken__m_spark", ...},
    {"name": "Flee", "kind": "ready", "mark": "flee", ...}
  ]
}
```

- `dice`: one to four dice, each a shape and the move on every face in order (a `label` names
  the die on the panel: "lamp", "pick", "jaws", "tail"). Dice written twice are identical (the
  Choir's three heads, the Collapsar's two).
- A move: `name` (unique on the creature), `kind` (attack red d72d47, guard blue 2c6ae8, meddle
  violet 7f4dd1, mend green 3fb57a, ready gold f1bb25, dud slate 4d5363), `mark` (a face mark,
  `base` or `base__modifier`, drawn by `view/dice/face_marks.gd`), `anim` (what the view plays:
  bite, claw, peck, lash, breath, spit, slam, drill, cast, mirror, pull, sing, guard, mend,
  rally, falter, erupt, burst, drink, gather, spores), `text` (its words; `{0}`, `{1}` stand for
  its effects' amounts and are written in as this creature deals them here,
  `DeepCreatures.move_text`), `trigger` and `effects`.
- `trigger` `{"kind": "face"}`: it fires when its face lands. A move on no face waits to be
  etched (a Magpie's Flee, the Foreman's Blast, the Assayer's Heavy Tax, the Crown's Topple and
  Summon).
- `trigger` `{"kind": "match", "faces": [...], "count": n}`: faces landing together in one action
  (`count` of the first named face, or every named face once): the Choir's Requiem Chorus, the
  Collapsar's Singularity, the Kaleidoscope's Deep Drink, the Spore Mother's Bloom. Once an action.
- Called moves keep their triggers: `emerge` (the Pit Mole's Erupt, the Undertow's Surface) and
  `on_death` (the Puffball's Burst).

## The sim

- `DeepCreatures.face_die` makes a die from its content entry; every face carries `move`, `mark`
  and `move_kind` (a face's `kind` is its etching, as on any die). `is_face_die`, `face_share`
  (each die's moves with their face counts, for the pips), `move_in`, `dress_face`.
- `enemy_roll` writes the landed face's `move`, `mark` and `move_kind` on the roll, and
  `DeepCreatures.activation` fires the move whose face it is.
- `effective_dice` keeps an action die's moves when Dread or an upgrade resizes it.
- New effect kinds (creature-only, `DeepRules.CREATURE_KINDS`):
  - `etch` `{from, to, count (0 = all), die}`: faces re-etched for the fight; `from: "self_face"`
    is the face just thrown. Result `etched: [{die, face, from, to, mark, kind}]`.
  - `grow_faces` `{faces, cap}`: the thrown die grows a size with new faces (the Crown's Rise).
    Result `{die, shape, added}`.
  - `grow_die` with `template`: another action die like a written one (heads, riftlings, voices,
    the Void's Expand); a die grown mid-action first throws next action. Result `die`.
  - `pin_trait` `{trait, value}`: a trait held until its next action opens (the lanterns'
    `gift_rerolls`, the Paradox Moth's `reroll_all`, Static's `backlash`, Hush and Dampen's
    `resonance_damp`, the Drill's `roll_for_you`, the Collapsar's `taunt`). Result `pinned`; the
    `enemy_begin` event lists `unpinned`.
  - `fog`: a socket clouded until someone hits the creature (or it dies); `player.fog`.
  - `flee`: it leaves with what it stole. Result `fled`, `stolen`, `returned`.
  - `morph`: a Void Echo becomes another creature at full health (`DeepCreatures.become_echo`).
    Result `became`, `name`, `hp_after`, `max_hp`, `was`. Its action ends there.
  - `cling`: the finest gem's hostile effects land on its owner until they hit the leech;
    `player.clung`. Result `socket`, `stone_id`.
  - `blank_next`: a die the player rerolled this turn lands blank (and locked) next turn.
- New effect options: `per_reroll` (amount times the target's rerolls this turn; result
  `rerolls`), `poison_through` (Poison for what got past block; result `envenomed`), `until:
  "next_action"` (a status on itself taken off as its next action opens: thorns), `back:
  "thrower"` on `reflect` (half of a blow back at whoever threw it, not the party), `for_fight`
  on `bury_socket` (rubble every turn: `player.rubble`), `cap` on `summon` (no more than so many
  of that creature standing).
- New target `escort_leader` (a Tendril knitting its Heartrot), new terms `taken_since` (what it
  took since its last action: the Regent's Reflection) and `party_high_die` (Mirror Image).
- New trait `acid_armour` (a player hitting it takes that much Poison). The lanterns' old blood
  and scorch price (`reroll_drain`, `reroll_scorch`) is only paid where written; no creature
  writes it now.
- `tests/test_creature_dice.gd` lands every face of every creature and checks it does what it
  says, and holds each mechanic above.

## The view

- `view/dice/face_marks.gd` draws every mark and composes `base__modifier` at run time with an
  even gap; `DiceView` dresses a die whose faces carry marks in the approved matte faces with
  engraved marks.
- Outside the fight, `view/inspect/creature_ledger.gd` reads a creature's dice as the battle's
  ledger does (a rule and the mark in the kind's ink, name and number, words with keywords on
  hover, pips) and pages them so nothing scrolls: a page a die (like dice as one), then what lands
  on no face (matches, moves waiting for a face or called by the fight, traits). The close look
  (`inspector.gd`) puts each page's die on its stage, turnable and centred beside its rows (the
  creature itself on a page with no die); the Bestiary's sheet stands the die beside its rows.
  A row under the pointer turns the die to its face.
- The data browser's creature page (`tools/data-browser/js/views/enemies.js`) lists each die's
  faces the same way, with the sampled fire rate a move; `creatureTurn` (js/sim/simulate.js)
  throws action dice. Its face marks and creature dice are pictures `tools/browser_assets.gd`
  bakes (sets `marks`, `creature_dice`).
- The battle reads them as the owner settled in the plates rethink (docs/UI_REDO.md, "Creature tags and the ledger"): an inset tag at each creature's feet with its dice standing in it and a grey pill a face move (`view/battle/creature_tag.gd`), the ledger at the side of the room with a row and pips a face move (`view/battle/enemy_panel.gd`), the throw played on the tag, and the right-click die window (`view/battle/creature_die_window.gd`); `view/battle/creature_look.gd` holds what they share (kind colours, a move's number and words, the keywords explained on hover).
