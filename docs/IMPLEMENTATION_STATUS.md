# Implementation and verification

Built from the rebuild specification and expanded catalog on September 8, 2026, against Godot 4.7.2 stable. The project starts at `scenes/main.tscn` and requires no supplied artwork. Illustrations, branding, dice presentation, and sound effects are replaceable generated placeholders.

## Implemented scope

The game includes the complete nine-room starter campaign and eighteen-room full campaign, three heroes and traits, nineteen corrected gems, eight relics, six alternative dice, eight ordinary/elite enemies, three bosses, all service rooms, four events, and both mining veins. Rewards, build management, downed-player participation, rally, revival, Poison, Resolve, Enrage, combat gold caps, persistent block, and deterministic targeting follow the specified contracts.

All gameplay goes through the same validated authority offline and online. Saves preserve RNG streams, pending offers, room claims, controller state, command results, and accepted requests. Scene playback and inspection do not execute rules. The frontend provides mouse, keyboard, and focus-based controller interaction, remapping, text scaling, reduced motion, playback speed, and skips.

The Steam adapter and matching native libraries are included, alongside a working ENet development transport. Lobby identity, readiness, version handshake, reliable commands, snapshots, bounded snapshot chunks, authenticated pings, reconnect grace, explicit fallback, and original-host checkpoint recovery are implemented. Native dependencies and version provenance are recorded in `addons/godotsteam/PINNED_BUILD.json`.

## Reproducible checks

Run `python3 tools/run_checks.py` with Godot 4.7.2 on PATH, or supply `--godot /path/to/godot`. The runner treats Godot script errors as failures even when an engine invocation returns exit status zero.

The final combined run passed **1,251 checks** across the five assertion suites, plus **12 campaign simulations and 1,266 public commands**, with no failures or script errors.

| Suite | What it verifies |
| --- | --- |
| `test_combat.gd` | All gem/property boundaries, status and relic hooks, hero traits, stable targets, boss phases, independent previews, loot and content validation |
| `test_run.gd` | Commands, duplicate/rejected transactions, economy, all room families, schedules, save/resume, disconnect recovery, determinism, and both campaigns with 1–4 heroes |
| `test_services.gd` | Atomic backup recovery, packet validation, four ENet peers, four separate processes, reconnect/host loss, and large snapshot reassembly |
| `test_network_run.gd` | Actual four-hero authority through network route votes, rerolls, lock-in and resolved combat, snapshot convergence, and pings |
| `test_ui.gd` | Scene startup, real input-to-authority flow, all screens, inspection, provisional build planning, and recovery presentation |
| `balance_smoke.gd` | Twelve unmodified solo campaign samples, 1,266 public commands, victory/defeat completion, and a real autosave die-swap/resize/reload regression |

Campaign transition fixtures deliberately use strong heroes to verify every milestone independent of balance. The separate ordinary-loadout simulations use the actual starting stats and legal transactions. Their small sample is a functionality check; it does not establish balanced win rates or campaign duration.

Real OpenGL window captures were inspected for menu, combat, inventory, settings, and room presentation. The default combat layout displays all three starting gems with the hand and enemy intentions visible.

## Desktop builds and remaining external validation

Windows x64, Linux x64, and universal macOS exports are generated under `build/`, with their matching Steam native dependencies and license notices. The macOS exported application was launched headlessly with a clean exit. Windows and Linux binaries were inspected for correct executable architecture and native-library packaging; they have not been run on those operating systems here.

The native Steam singleton and required Networking Messages methods load on macOS. Steam initialization in this environment returns “Could not determine Steam client install directory.” Live Steam lobbies, accepted invitations, relayed traffic, separate-account runs, and recovery across real networks therefore need validation on machines with Steam available. Development uses App ID 480; a release App ID, depot configuration, accounts, and signing identities remain external release inputs.

No automatic host migration, Steam Cloud, achievements, Steam Workshop integration, persistent stat progression, or synchronized physics have been added. Those features are explicitly outside this rebuild's initial scope.
