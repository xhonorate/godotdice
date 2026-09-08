# Content authoring

`full_content.tres` is the bundled `RogueContentPack` Resource. Godot's Inspector can edit its named dictionaries. `data/full_content.json` is the equivalent data-only interchange format. Both contain all heroes, skills, dice, relics, enemies, events, status metadata, and profile references.

The authority calls `Catalog.validate_content()` before creating a run. It loads the bundled Resource, checks its schema/content version, registered IDs and evaluators, target policies, trigger tags, loadouts, face counts/values, and referenced content. Factories deep-copy the pack's data; modifying a hero's face or gem never changes shared definitions.

To load a JSON pack in an authoring tool, call `Catalog.load_content_pack(path)`. It returns validation errors and leaves the current pack untouched on failure. To write the selected pack, use `Catalog.export_content_pack(path)` with a `.tres` or `.json` extension. JSON imports never execute expressions. Changed rules or balance require a new content version in the game build and pack for multiplayer compatibility.

Skills reference registered `evaluator_id` values. Their effect formulas, timing, and boss intent programs live in `scripts/core/combat.gd`; their tooltip formulas and trigger tags are in the pack. New behaviors require a registered evaluator and tests. New sprites and sound assets can replace the generated presentation without touching these rules. Template health, starting dice/gems, faces, rarity, display metadata, and prices are editable data.

To regenerate the two bundled files from the immutable baseline catalog (overwriting authoring edits):

```sh
godot --headless --path . --script data/export_content.gd
```

The baseline values follow both specification documents. `short_9` selects the starter pool; `expedition_18` selects the full pool. The pack version is `1.0.0`.
