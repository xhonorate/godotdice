# RogueDice

A cooperative dice-and-gem roguelike for one to four heroes, rebuilt in **Godot 4.7.2 stable** with typed GDScript and the Compatibility renderer. Every equipped gem evaluates the same five-die hand. Keeping a pair, completing a straight, or chasing a high roll changes several skills at once.

Open [project.godot](project.godot) in Godot 4.7.2 and press **F6 on `scenes/main.tscn` or F5**. No art downloads, Firebase service, Node installation, or asset setup are required.

```sh
godot --path .
python3 tools/run_checks.py --godot /path/to/godot
```

## Playing

Choose one to four local heroes for solo or shared-screen play. Duplicate heroes are allowed. Pick a seed to reproduce a run, or leave it empty. The nine-room Quarry uses the starter content pool; the eighteen-room Expedition unlocks the full content pool across three acts.

Select dice to **reroll**; unselected dice stay. You get one normal reroll each turn. Max also has one Second Thought reroll per battle. Inspect enemy intents, choose hostile and friendly targets, then lock in. All equipped gems execute in their displayed order, using the same hand. You can unready until the final participating hero locks in.

Between rooms, open Inventory to equip up to six unique gems, reorder them, swap active and reserve dice, and equip up to three relics. Strike must remain equipped. Rewards enter reserves so receiving an item never silently replaces your build. The journal explains every rule and content definition.

| Input | Default |
| --- | --- |
| Select dice | Mouse or 1–5 |
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
- Eight relics; six standard dice and six alternative face distributions; active/reserve equipment and engraving.
- Eight ordinary/elite enemies and three scripted bosses: Slime King, Mirror Regent, and Rift Sovereign.
- Both `short_9` and `expedition_18`, authored encounters, weighted route offers, votes, camps, elite rewards, boss rewards, victory, and defeat.
- Personal shops, die purchases/sales/swaps, Workshop, Lapidary, four events, two mine veins, automatic mining, pooled gold, and rotating drafts.
- Integer effects, stable skill targets, persistent combat block, stun timing, Poison ticks, boss Resolve, Enrage, gold caps, Lifeline charges, and postbattle rally.
- Host authority, versioned commands, bounded idempotency history, separate saved RNG streams, revisioned snapshots, atomic checkpoint and backup saves, run history, and connection recovery.

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
| `scripts/core/combat.gd` | Pure triggers, previews, intent programs, effects and turn resolution |
| `scripts/core/run_engine.gd` | Validated transactions, campaigns, rooms, inventory, economy and saves |
| `scripts/services/` | ENet/Steam sessions, bounded packet codec, atomic saves and settings |
| `scripts/ui/`, `scenes/main.tscn` | Snapshot presentation, procedural illustrations, desktop input |
| `tests/` | Combat, campaign, save, networking and interface scenarios |

Placeholder illustrations are generated by `scripts/ui/rune_art.gd`. Replace those drawing paths or substitute TextureRects/Sprites without changing the simulation. Die face values are physical data independent of their appearance; repeated values retain separate face IDs. Outcomes never depend on animation, physics, sound, or frame rate.

Host checkpoints are written under Godot's `user://saves/` in the `RogueDice` application-data directory. The previous valid checkpoint is retained as `.bak`. Settings and completed-run history are separate. RNG states and Steam IDs are decimal strings to preserve all 64 bits through JSON. Deterministic replay is supported within the pinned engine/rules/content build; accepted command records are saved for diagnosis.

## Validation and exports

`tools/run_checks.py` runs the real Godot headless scenario scripts and fails on script errors even if the engine exits with status zero. The campaign tests verify complete one-to-four-hero transitions using explicit strong fixtures; those tests do not establish game balance. Ordinary-seed balance runs remain playtesting data, not a guarantee of equal win rates.

Desktop presets are supplied in [export_presets.cfg](export_presets.cfg), and development builds are available under `build/windows`, `build/linux`, and `build/macos`. The macOS ZIP contains a universal application. Regenerate them with `python3 tools/install_export_templates.py` followed by `tools/export_desktop.sh all`. Release builds need the real Steam App ID, application configuration, and platform-specific signing where applicable. See [implementation and verification](docs/IMPLEMENTATION_STATUS.md) for the tested scope and external platform checks. Steam achievements, Cloud, Workshop integration, host migration, cosmetics, and permanent stat progression are intentionally outside the requested ruleset.
