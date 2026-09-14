# Content Studio

A local web panel for authoring every piece of content in the game — heroes, gems, dice,
relics, enemies, events, mines and statuses — with a live preview of each one and
the engine's own validator running as you type.

```
python tools/content_studio/server.py
```

It opens `http://127.0.0.1:8777/` and edits `data/full_content.json`. Saving writes that
file **and** regenerates `content/full_content.tres`, which is the pack the game loads at
startup, so an edit reaches the next launch with no export step.

`--port N` moves it, `--godot <path>` points the *Validate in engine* button at a Godot
binary (it also reads `GODOT_BIN` and `.vscode/settings.json`), and `--no-browser` stops it
opening a tab.

## What the panel gives you

- **Every section, one list.** Search, create, duplicate, rename and delete. A rename
  repoints every reference — a hero's dice, a mine's gem pool, boss or depth bands, another
  entry that borrows this one's rule — so nothing is left pointing at a name that is gone.
- **Live previews built from the game's own code.** The gem preview is a port of
  `scripts/ui/gem_mesh.gd`: the same outline per Colour, the same miscut per Cut, the same
  body colour per Clarity, the same facet hash. Sliding Carat from 1 to 24 shows the stone
  the game will cut, on the palette it will sit on.
- **The gem sheet the game draws.** A gem's preview is the panel from the battlefield:
  its name in its Colour, the rank line a player says out loud, the dice that switch it on,
  and its rule as a chain of marked terms — each mark the very pictograph the game draws,
  baked out by `bake_glyphs.gd` and tinted by CSS, with the same sentence on hover. Nothing
  that contributes nothing is shown: Carat 1 multiplies by one and disappears, a Cut that
  adds nothing is absent, and Bulwark's fixed table is stated rather than multiplied.
- **Numbers that mean something.** A die shows its face distribution, average and spread.
  A hero shows what its five dice actually roll: the chance of a pair, a straight, three
  evens, five distinct — the triggers gems are written against, sampled 12,000 hands deep.
  A gem shows its Carat multiplier, Clarity bonus, sale value, and the chance each hero can
  fire it. An enemy shows its health and block at every act and party size.
- **Validation as you type.** `app/validate.js` mirrors `scripts/core/content_pack.gd`
  check for check, with each error attached to the field that caused it. *Validate in
  engine* then has Godot load the pack for real and report what it says.
- **A saved copy every time.** The previous JSON is kept under `backups/`; the last 30 are
  retained and any of them can be restored from the Pack page.

## Authoring content the build has never heard of

The rules live in GDScript and the pack is data. A new entry bridges the two by naming the
registered behaviour it borrows, and the panel offers only behaviours the server found by
reading `catalog.gd` and `combat.gd` themselves:

| Section | How a new entry runs | Field |
| --- | --- | --- |
| Dice | Pure data — no rule needed | — |
| Gems | **Writes its own rule**, or borrows a registered formula | `rule`, or `evaluator_id` |
| Enemies | Picks intents with a registered routine | `ai` |
| Heroes | Carries a registered trait | `trait` |
| Relics, events, statuses | Behaviour only — the build has to register the ID first | — |

A gem that borrows Strike keeps its own name, colour, cut, rarity, tags, trigger text and
drop pool, and resolves Strike's formula. An enemy that borrows Stone Crab keeps its own
health, block, dice and art, and alternates Shell Up and Claw. To make an authored enemy
actually appear, name it in a mine's **depth bands**: each band is a depth it starts at and
weights for the ordinary and elite enemies that fill a fight from there down.

`tests/test_authored_content.gd` is the proof: it writes a pack carrying a hero, a gem, a
die and an enemy that no GDScript mentions, loads it the way the game does, and checks the
borrowed rules fire — and that a pack borrowing a rule the build lacks is still rejected.

## Writing a gem's rule

A gem can carry a `rule` of its own instead of borrowing one. It is a trigger and a list of
effects whose amounts are arithmetic over the hand — a small fixed language, interpreted by
`scripts/core/gem_rules.gd`, with no way to reach anything beyond the hand it was handed:

```json
"rule": {
  "trigger": {"kind": "pair"},
  "effects": [{"kind": "block", "target": "self",
    "amount": {"op": "+", "args": [
      {"op": "*", "args": [{"term": "pair_value"}, {"rank": "cut"}]},
      {"rank": "clarity_bonus"}]}}]
}
```

That is Block, exactly as the compiled rule resolves it. The **Rule** field on any gem
builds this with dropdowns — pick a trigger, add effects, assemble each amount out of
terms, ranks, numbers and operations — and the preview pane runs it on a hand you can type
into or roll from any hero's real dice, showing which dice it read and what each effect
comes to at the Carat, Cut and Clarity on the sliders.

| Piece | What it offers |
| --- | --- |
| Triggers | always · pair · two pairs · triple · full house · straight (fixed or shortened by Clarity) · even/odd count · distinct values · a particular number · total at least/at most · highest die at least |
| Terms | the highest or lowest die, the highest or lowest N added, the total, a pair or triple's value, the run's highest value, the lowest odd die, even/odd/distinct counts, how many of a value, the caster's block |
| Ranks | Carat, Cut, Clarity, and the flat Clarity bonus F(L) |
| Operations | add, subtract, multiply, divide rounding down, smaller of, larger of, × the Cut multiplier |
| Effects | damage, block, heal, gold, poison, stun, strip block — to the caster, one enemy, several enemies, every hero, or the caster's allies — with an optional repeat and target limit |

Carat multiplies the whole amount last and floors once, which is the contract every shipped
rule keeps. Sixteen shipped rules are offered as starting points, so authoring usually means
picking *Strike* or *Venom* and changing two things. The rule also writes its own wording:
"Write this into the gem's rules text" fills in the trigger and formula the player reads,
and the in-game gem panel draws an authored rule as the same chain of marked parts a
compiled one gets.

A rule that does not hold together is refused by the pack validator, so a malformed one
cannot reach a run. What the language cannot express stays in code: Bulwark's block table,
Lifeline's revive charges, and Lucky Strike's jackpot are still compiled rules to borrow.

### Keeping the two interpreters honest

The panel needs the rule to run in the browser, so the interpreter exists twice — once in
GDScript for the game and once in `app/rules.js` for the studio. They are cross-checked
rather than trusted:

```
node tools/content_studio/rule_probe.mjs > js.txt
godot --headless --path . --script tools/content_studio/rule_probe.gd > gd.txt
diff js.txt gd.txt
```

Every shipped template, over twelve hands and five rank spreads: 1008 lines that have to
match exactly, down to the generated sentence.

The gem sheet is checked the same way, since `app/gemtext.js` is a port of
`scripts/ui/gem_text.gd` and the requirement strip from `scripts/ui/dice_icons.gd`:

```
node tools/content_studio/panel_probe.mjs > js.txt
godot --headless --path . --script tools/content_studio/panel_probe.gd > gd.txt
diff js.txt gd.txt
```

Every gem in the pack at five rank spreads — 620 lines of chains, chips, marks, multipliers
and requirement strips that have to come out identical.

The pictographs themselves are not redrawn either. They are exported from the game's own
`gem_icons.gd` as alpha masks:

```
godot --headless --path . --script tools/content_studio/bake_glyphs.gd
```

Re-run it after changing a glyph; the PNGs and their hover text live in `app/glyphs/`.

## Testing the panel itself

```
node tools/content_studio/smoke.mjs     # with the server running
```

Drives the studio headlessly against a stub DOM: opens every section, selects every entry,
touches a control of each kind, creates and deletes an entry in each section, then builds a
gem rule through the panel — every trigger, every effect kind and target, every node kind,
every operator, every term, repeats, target limits and the bench. Any throw fails the run.

## Layout

| File | Responsibility |
| --- | --- |
| `server.py` | Static host, pack read/write, `.tres` generation, backups, engine validation |
| `validate_pack.gd` | The engine-side check the Validate button runs |
| `app/schema.js` | What each section is made of: fields, controls, bounds, defaults |
| `app/rules.js` | The gem rule language, mirroring `scripts/core/gem_rules.gd` |
| `app/rulebuilder.js` | The rule editor and the bench that runs a rule on a hand |
| `app/validate.js` | A mirror of the engine validator, per field |
| `app/gem.js` | The cut solid, ported from `gem_mesh.gd` |
| `app/dice.js` | Die icons, face statistics, and what five dice roll into |
| `app/app.js` | The panel: list, editor, previews, undo, save |
| `app/gemtext.js` | What a gem says: the chain, the rank line, the requirement strip |
| `app/gemcard.js` | The gem sheet, laid out as `gem_panel.gd` lays it out |
| `app/glyphs/` | The game's own pictographs, baked as masks, with their hover text |
| `app/dom.js` | The helpers every panel is built from |
| `smoke.mjs` | Headless drive-through of the whole panel |
| `rule_probe.mjs`, `rule_probe.gd` | The two halves of the interpreter cross-check |
| `panel_probe.mjs`, `panel_probe.gd` | The same, for the gem sheet |
| `bake_glyphs.gd` | Exports the game's pictographs for the panel |
