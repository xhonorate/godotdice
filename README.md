# RogueDice

A cooperative dice-and-gem roguelike for one to four heroes, rebuilt in **Godot 4.7.2 stable** with typed GDScript and the Forward+ renderer. Every equipped gem evaluates the same five-die hand. Keeping a pair, completing a straight, or chasing a high roll changes several skills at once.

Open [project.godot](project.godot) in Godot 4.7.2 and press **F6 on `scenes/main.tscn` or F5**. No art downloads, Firebase service, Node installation, or asset setup are required.

```sh
godot --path .
python3 tools/run_checks.py --godot /path/to/godot
```

## Playing

Your profile keeps a gem collection, each hero's loadout of up to six gems, gold, and the mines you have opened. Pick a hero and an unlocked mine, then set out. A mine is a seam of chambers dug one layer at a time with no bottom: your lantern shows the rooms two layers ahead, anything further is a silhouette, and lift beacons show however deep they are. Every step, every combat turn and every noisy room fills the **tremor meter**, faster the deeper you are; when it fills, the mine's boss breaks into the next chamber you enter. An expedition ends when the party rides a lift home, falls, or kills the boss — which also unlocks the mines beyond it.

Stones come out of the rock **unappraised**: you see their colour, size, cut and clarity but not what they do, and they cannot be equipped until a loupe or a Lapidary appraises them. Ore is the mine's own currency and stays behind. At the surface every stone is appraised on the table and kept (replacing any copy you own) or sold for gold. If the whole party falls, each carried stone is rolled on a die by rarity, d6 to d20, and only the top face brings it home; loadout gems are never at risk. See the [expedition loop design](docs/EXPEDITION_LOOP_DESIGN.md) for the whole plan, including the shop hub still to come.

Battles are fought on a JRPG-style field: your party holds the left flank, the enemy the right, both on a receding diagonal. Click a combatant to target it and right-click anyone to read their sheet. When the turn resolves, each attacker crosses the field, lands its blow and returns to its mark, with the authority's numbers floating over whoever was hit. Rolling spins each die and settles it with the rolled physical face turned toward you.

Select dice to **reroll**; unselected dice stay. You get one normal reroll each turn. Max also has one Second Thought reroll per battle. Inspect enemy intents, choose hostile and friendly targets, then lock in. All equipped gems execute in their displayed order, using the same hand. You can unready until the final participating hero locks in.

Between rooms, open Inventory to equip up to six unique gems, reorder them, swap active and reserve dice, and equip up to three relics. Strike must remain equipped. Rewards enter reserves so receiving an item never silently replaces your build. The journal explains every rule and content definition.

| Input | Default |
| --- | --- |
| Select dice | Mouse or 1–5 |
| Vote for a tunnel | Click a ringed chamber on the seam, or 1–9 |
| Reroll selected dice | R / gamepad X |
| Ready or unready | Space / gamepad Y |
| Cycle hostile target | Tab / right shoulder |
| Inventory / inspect | I / gamepad Back |
| Close panel | Escape / gamepad B |
| Skip playback | F / gamepad Start |

Controls can be rebound in Settings. Keyboard/gamepad focus offers alternatives to mouse interaction. Settings include text scale, reduced motion, fullscreen, and playback speed. Skipping playback never changes rewards or combat outcomes.

## Included content

- Three heroes with their specified HP, starting dice, three starting gems, and distinct encounter traits.
- Nineteen skill gems, including all eleven corrected originals, support, Poison, revival, parity, and distinct-value skills.
- The four C's on every gem: **Color** is the effect category (Red damage, Blue block, Green healing, Violet control, Gold fortune, White mastery — rerolls, the dice themselves, and the gems themselves), and each colour is cut to its own shape: a trilliant, a princess, a heart, a pear, a half Dutch rose and a round brilliant; **Carat** 1–24 is the overall strength multiplier `M(C) = (C+7)/8`; **Cut** 1–5 (Poor to Perfect) scales what the dice contributed, so it matters most on attacks; **Clarity** 1–5 (Fractured to Flawless) adds the flat term `F(L) = 2L`, eases triggers, and unlocks bonuses at the top ranks. Color comes from the skill; the other three are rolled. Cut and Clarity are then bought at the Lapidary, and Carat — the multiplier over the whole gem — is raised only at the Crucible. In play a gem is named by its ranks — "Good Flawless 12 Multistrike" — each rank marked with its own icon, and its rule is drawn as a chain of marked terms rather than an equation, with hover text on every mark.
- Gems are **real 3D stones cut at runtime from their own four properties**, so two gems alike but for one rank look different: Color sets the cut outline and hue, Carat the size, Cut the faceting, Clarity how see-through and how polished it is, down to the inclusions frozen inside. The stones are translucent and drawn in two passes, so you look through a gem's crown at its own pavilion. The skill's emblem is etched into the table. Inspect a gem to turn it in your hand.
- A **gem lab** for tuning the stones: `godot --path . scenes/gem_lab.tscn` gives a live 3D gem with the skill and all three ranks on dials, plus the rule chain the game would show. Arrow keys change the skill and Carat, `[` `]` the Cut, `;` `'` the Clarity, `R` randomises, `S` spins.
- Eight relics; six standard dice and six alternative face distributions; active/reserve equipment and engraving.
- Eight ordinary/elite enemies and three scripted bosses: Slime King, Mirror Regent, and Rift Sovereign.
- Three mines — the Quarry, Mirror Grotto and Rift Hollow — each with its own boss, depth bands, room weights, gem pool, colour leaning, tremor and lift rates, linked on an unlock web.
- A generated seam per expedition: planar tunnels between layers, a lantern that hides rooms past its reach, lift beacons, a tremor meter that summons the boss, depth-scaled enemies and loot, boss chests, and salvage rolls for a fallen party.
- A persistent profile: one gem per skill in the collection, per-hero loadouts, a daily gem shop with a climbing refresh price, commissions and special missions, and an appraisal table that keeps or sells every stone brought home.
- Personal merchants, loupes, die purchases/sales/swaps, Workshop, Lapidary appraisal and upgrades, Wager Hall, Crucible, treasure caches, five events, two rock veins, automatic mining, pooled ore, and rotating drafts of unappraised stones.
- Two of the eleven rooms are played rather than read. **The Wager Hall** stakes gold on five matched house dice — the house deals its own so a party that upgraded its dice is not quietly taxed for it — and allows the same single reroll a combat turn does before paying the pattern you show, on a paytable that names the very patterns the gems read. Only a four-die straight or better pays, so the reroll is the whole game: never rerolling returns about 0.39 per gold staked, keeping the largest group about 0.74, and also chasing a straight about 0.99. A stake left on the table is paid out when you leave, never forfeited. **The Crucible** is the only place Carat moves: temper a gem and pay in HP that rises with the gem, or fuse a reserve gem into it and pay in Carat instead, one offering per hero per visit.
- Integer effects, stable skill targets, persistent combat block, stun timing, Poison ticks, boss Resolve, Enrage, gold caps, Lifeline charges, and postbattle rally.
- Host authority, versioned commands, bounded idempotency history, separate saved RNG streams, revisioned snapshots, atomic checkpoint and backup saves, run history, and connection recovery.

- **Gem rules can be written as data.** A gem may carry a `rule` — a trigger and a list of effects whose amounts are arithmetic over the hand — interpreted by `scripts/core/gem_rules.gd` from a small fixed vocabulary with no way to reach past the hand it is given. Block, Strike, Venom, Arc Burst and Multistrike are all expressible in it, so a new gem can be invented, balanced and shipped without touching GDScript; the studio builds one with dropdowns and runs it on a hand as you write. Anything the language cannot say — Bulwark's block table, Lifeline's revival — stays a compiled rule for an authored gem to borrow.
- A **content studio** for authoring all of it: `python tools/content_studio/server.py` opens a web panel over `data/full_content.json` with a visual editor and a live preview for every hero, gem, die, relic, enemy, event, run profile and status. The gem preview cuts the same stone the game does, a hero shows what its five dice actually roll, and the engine's validator runs as you type. Saving rewrites the pack and the `.tres` the game loads. New content is data: a gem, enemy or hero the rules build has never heard of runs by naming the registered rule it borrows — an evaluator, an intent routine, a trait — while keeping its own name, stats, colour and art. [Studio guide](tools/content_studio/README.md).

The original documents remain the design references: [rebuild specification](docs/GODOT_REBUILD_SPEC.md) and [content catalog](docs/CONTENT_CATALOG.md). The journal and preview calculations use the installed rules, including corrections to Heal, Shield Bash, Heavy Strike, straights, Stun, and Bulwark.

## Multiplayer

Use **Host LAN / direct** on one machine, then join its IP address from other clients. ENet uses UDP port **24567**; same-machine clients use `127.0.0.1`. For independent local development identities, launch guests with `-- --instance=guest2` (and `guest3`, `guest4`). The host begins after all participants mark ready.

Steam uses the vendored **GodotSteam GDExtension 4.22.1 / Steamworks 1.65** with Steam Networking Messages. Development App ID **480** is configured. The native extension is included for macOS universal, Windows x64, and Linux x64/arm64. See [Steam setup and validation](docs/STEAM_SETUP.md) for identity, packaging, and release configuration.

On disconnect, a seat and its inventory stay reserved. Progress pauses for a 60-second reconnect grace period. The host can explicitly enable deterministic fallback afterward. The absent hero keeps its hand, makes no purchases, and receives deterministic loot choices. Host loss stops authority; reconnect to the original host's reopened checkpoint. Automatic host migration is outside this specification.

Live Steam acceptance requires a running Steam client and separate accounts on separate networks. The development environment loads the native extension but cannot initialize its Steam client, so real Steam matchmaking, invitations, relay traffic, and release-account validation are not claimed as tested.

## Code and assets

| Location | Responsibility |
| --- | --- |
| `scripts/core/catalog.gd`, `content/` | Versioned definitions, factories, validated content pack |
| `scripts/core/gem_rules.gd` | The data-written gem rule: its vocabulary, its validator and its interpreter |
| `scripts/core/combat.gd` | Pure triggers, previews, intent programs, effects and turn resolution |
| `scripts/core/run_engine.gd` | Validated transactions, expeditions, rooms, inventory, economy and saves |
| `scripts/core/seam.gd` | The generated mine: layers, tunnels, lifts, sight and tremor steps |
| `scripts/core/profile.gd`, `scripts/services/profile_store.gd` | The persistent profile's rules and its transactional save |
| `scripts/services/` | ENet/Steam sessions, bounded packet codec, atomic saves and settings |
| `scripts/ui/`, `scenes/main.tscn` | Snapshot presentation, generated sprites, polyhedral dice, battlefield, desktop input |
| `tests/` | Combat, campaign, save, networking, presentation, authored-content and interface scenarios |
| `tools/content_studio/` | The web panel that authors `data/full_content.json` and the pack the game loads |

The art in `assets/sprites/` is ordinary PNGs and is what the game loads. Edit one in place to change it. Those files were generated once by `scripts/ui/sprite_forge.gd` and baked with `tools/bake_sprites.gd`, so they are an editable starting point, not a runtime effect; the painter remains only as the fallback for a key whose file is missing. A file at `user://sprites/<category>/<key>.png` overrides the shipped one at runtime with no reimport. [The sprite guide](assets/sprites/README.md) lists every category, key and size, and how to regenerate without overwriting hand-painted art. Animation needs no extra frames — `scripts/ui/sprite_actor.gd` breathes, sways, lunges, flashes on damage and drains the colour of a downed unit by deforming and recolouring the still image.

Dice are real geometry, not pictures. `scripts/ui/dice_geometry.gd` recovers the faces of a tetrahedron, cube, octahedron, pentagonal trapezohedron, dodecahedron and icosahedron from their vertices by convex-hull plane grouping, and `scripts/ui/dice_view.gd` renders each die in its own 3D SubViewport with a numeral on every face. Face colours and values come from the die's actual face data, so engraved and alternative-distribution dice look like what they are.

Die face values are physical data independent of their appearance; repeated values retain separate face IDs. Outcomes never depend on animation, physics, sound, or frame rate.

Host checkpoints are written under Godot's `user://saves/` in the `RogueDice` application-data directory. The previous valid checkpoint is retained as `.bak`. Settings and completed-run history are separate. RNG states and Steam IDs are decimal strings to preserve all 64 bits through JSON. Deterministic replay is supported within the pinned engine/rules/content build; accepted command records are saved for diagnosis.

## Validation and exports

`tools/run_checks.py` runs the real Godot headless scenario scripts and fails on script errors even if the engine exits with status zero. `tests/test_authored_content.gd` covers the other direction: a pack carrying a hero, gem, die and enemy that no GDScript mentions loads, plays through its borrowed rules, and is still rejected when it borrows a rule the build does not have. The campaign tests verify complete one-to-four-hero transitions using explicit strong fixtures; those tests do not establish game balance. Ordinary-seed balance runs remain playtesting data, not a guarantee of equal win rates.

Desktop presets are supplied in [export_presets.cfg](export_presets.cfg), and development builds are available under `build/windows`, `build/linux`, and `build/macos`. The macOS ZIP contains a universal application. Regenerate them with `python3 tools/install_export_templates.py` followed by `tools/export_desktop.sh all`. Release builds need the real Steam App ID, application configuration, and platform-specific signing where applicable. See [implementation and verification](docs/IMPLEMENTATION_STATUS.md) for the tested scope and external platform checks. Steam achievements, Cloud, Workshop integration, host migration, cosmetics, and permanent stat progression are intentionally outside the requested ruleset.
