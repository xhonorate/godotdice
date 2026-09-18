# Networking, recovery, and desktop exports

RogueDice uses one host authority for offline, LAN, and Steam sessions. Steam lobbies provide membership and invitations; gameplay uses reliable Steam Networking Messages on channel 0. The LAN development adapter uses reliable ENet packets. A session selects one transport.

## Pinned integration

- Godot **4.7.2 stable**, official build `ed1daf0bf`, Forward+ renderer (Vulkan 1.0 or D3D12 required).
- GodotSteam **GDExtension 4.22.1**, Steamworks **1.65**, upstream Godot compatibility minimum 4.4.
- Included native libraries: Windows x64; Linux x64 and ARM64; macOS universal. Debug/release libraries and their Steam API dependencies are included.
- Source, upstream ZIP SHA-256, and per-library SHA-256 values: [`addons/godotsteam/PINNED_BUILD.json`](../addons/godotsteam/PINNED_BUILD.json). Upstream license: [`addons/godotsteam/license.md`](../addons/godotsteam/license.md).

The GDExtension loads automatically; there is no editor plugin to enable. Steam initializes at game startup (not in the editor), before the renderer creates its device, which is what lets the Steam overlay hook the D3D12/Vulkan swapchain. Initializing later leaves `isOverlayEnabled()` false for the whole process; this was measured on Windows with both D3D12 and Vulkan. `GameSession` pumps Steam callbacks from startup, so invitations accepted in Steam reach the shop during offline or LAN play too. If Steam was not running at launch, opening a Steam lobby initializes it then; lobbies work but the overlay does not until the game restarts. The singleton and required native methods were loaded successfully on the installed macOS engine. A real `steamInitEx(480, false)` attempt returned “Could not determine Steam client install directory”; The Steam client was unavailable to that process. The game reports this and keeps offline/LAN play available. Live Steam lobbies, overlay invitations, relay transport across accounts, and Steam exports still require the platform tests below.

## Play locally or over LAN

Choose Host LAN on one machine. Other players choose Join LAN and supply its LAN address. The default UDP port is **24567**; a loopback test uses `127.0.0.1`. Each player chooses a hero and readies. The host's Start button becomes available when all one to four seats are ready. Duplicate heroes are supported. Lobby host identity is explicit and independent of seat order.

For multiple client processes sharing this computer, assign separate persistent LAN identities:

```sh
"$GODOT_BIN" --path . -- --instance=guest2
"$GODOT_BIN" --path . -- --instance=guest3
```

The identity token is stored in `user://lan_identity_<instance>.json` so a restarted client can reclaim its reserved hero. ENet is a development/LAN transport; its reconnect token is a bearer credential and traffic is not encrypted. Use Steam for the intended Internet transport.

Automated transport tests:

```sh
"$GODOT_BIN" --headless --path . --script tests/test_services.gd
"$GODOT_BIN" --headless --path . --script tests/test_network_run.gd
```

The services suite creates four real ENet peers and separately launches four Godot processes. It checks handshakes, duplicate hero selection, readiness, authenticated sender ownership, concurrent commands, snapshot checksums, old-session rejection, disconnect grace, explicit fallback, same-seat reconnect, host loss, bounded JSON, and atomic checkpoint backup recovery. The authority integration test drives a real four-hero run through route voting, rerolls, ready, and combat snapshots without presentation.

## Steam setup and invitations

1. Install and run Steam, signed into an account entitled to the configured application. For development this project uses Valve's test application **480** (Spacewar).
2. The current GodotSteam setting is `steam/initialization/app_data/app_id`. Replace `480` with your real App ID for distribution. Keep `steam/initialization/processes/initialize_on_startup=true`; without it the overlay (and its invite dialog) never appears. `SteamMessagesTransport` reuses that startup initialization.
3. Choose Host Steam to create a friends-only four-seat lobby. The game displays its lobby ID. Friends may join by that ID, through the overlay invitation dialog, or by accepting Steam's join request. With the test App ID 480, the invited friend must already have RogueDice open when they accept; otherwise Steam launches Spacewar instead. If the overlay is unavailable, right-click a friend in the Steam friends list and choose Invite to Lobby. Cold starts honor Steam's `+connect_lobby <id>` launch argument. An invitation during an active run presents a leave-and-join choice before changing sessions.
4. Before a seat is assigned, both builds must match protocol/build/content versions. The verified Steam sender ID determines ownership. IDs are serialized as decimal strings, never JSON floating-point numbers.
5. After a run begins, the authority accepts only the existing party identities. Lobby membership alone cannot add or replace a hero. Steam may change lobby ownership after host loss; RogueDice does not promote that peer to simulation authority.

For an exported application started outside Steam during testing, an adjacent `steam_appid.txt` containing `480` can help Steam resolve the test application. Do not distribute a test App ID file in a production depot. Production builds should launch through their configured Steam application and depots.

## Recovery and saves

Commands include protocol/run/session/host-epoch identity, a unique command ID, sequence, phase, and base revision. The authenticated transport sender supplies the player ID. The authority validates ownership, current phase, and resources, serializes accepted transactions, checkpoints before acknowledgment, and publishes the full snapshot. Snapshots over 64 KiB use 32 KiB byte chunks, bounded to 8 MiB per snapshot and two simultaneous assemblies; each transfer verifies identity, epoch, indices, byte count, and SHA-256, and expires after 15 seconds. This keeps every Steam packet below its native 512 KiB message limit. Command receipts omit state/events already carried by the snapshot. Repeated commands return cached results; accepted sequence counters protect against older retries after the bounded cache rolls over. Pings are bounded, rate-limited presentation messages and never mutate run state.

A disconnected hero retains its inventory and reward entitlement. Planning pauses for **60 seconds**. The host then chooses explicitly whether to continue with deterministic fallback: retain the hand, avoid purchases, use the first living target and the prescribed free reward/draft choices. Reconnection replaces the fallback controller and loads a fresh snapshot. Clients stop at host loss and keep their last snapshot for the recovery screen; only the original host can reopen the canonical checkpoint.

Host checkpoints live in `user://saves/active_run.json`; the previous valid file is `.bak`. Writes flush a temporary file before atomic replacement. Invalid schema/content IDs, malformed nested records, invalid resources/loadouts, and duplicate ownership are rejected. Exact RNG states and command history persist. Settings and completed-run history have independent files. LAN credentials never appear in snapshots or host saves.

## Export builds

Install only the pinned desktop templates, using Python's standard library:

```sh
python3 tools/install_export_templates.py
GODOT_BIN=/path/to/godot tools/export_desktop.sh all
```

The installer requests explicit HTTP ranges from the official Godot template bundle and verifies extracted size and ZIP CRC for every selected member. It avoids downloading unrelated Android/iOS/Web templates. The exporter accepts `all`, `windows`, `linux`, or `macos` and refuses a different Godot version. Output goes into `build/windows`, `build/linux`, and `build/macos`. Export presets include the GDExtension and each matching Steam API library.

All three export presets were built successfully. The macOS universal app was extracted and run with `--headless --quit-after 20` (exit 0, no script/native-load errors); its archive includes both native dylibs and license notices. Windows PE x64 and Linux ELF x64 binaries were inspected together with their matching Steam/GodotSteam libraries; those platforms were not executed on this macOS machine.

macOS export signing/notarization and Windows code signing are disabled for this development build. Configure your own identities for distribution. Real App IDs, Steam depot configuration, platform entitlements, signing identities, and separate test accounts are release inputs that are not present in this repository.

Before release, launch exported builds through Steam on Windows, Steam Deck/Linux, and macOS; use two or more accounts on separate networks to complete and resume a run. Exercise invitations, incompatible builds, client loss during a purchase acknowledgment, the full 60-second recovery window, and host loss immediately after a reward commit. Verify every client converges after fast/skipped playback. A successful local ENet test does not establish these Steam-platform results.

## Service API

`GameSession` (`scripts/services/session.gd`) is a Node. Important methods:

- `host_enet(name, port=24567)`, `join_enet(address, name, port=24567)`, `host_steam(name)`, `join_steam(lobby_id, name)` return `{ok, error}`.
- `start_offline(name, hero_id)`, `choose_hero(hero_id)`, `set_lobby_ready(bool)`, `can_start()`, `start_run()` (authenticated party records).
- `send_command(envelope)`, `broadcast_snapshot(state)` (host only), `reply_command(player_id, result)`, `request_snapshot()`.
- `restore_party(state)`, `resume_disconnected(player_id)`, `reconnect()`, `invite_friends()`, `send_ping(subject_id, label)`, `leave()`.
- Signals: `command_received(player_id, envelope)`, `command_result(result)`, `snapshot_received(state)` (clients), `lobby_changed(lobby)`, `connection_changed(status)`, `error_received(message)`, `controller_connection_changed(player_id, connected)`, `recovery_required(snapshot)`, `invite_received(lobby_id)`, `party_ping(player_id, subject_id, label)`.

`SaveStore` (`scripts/services/save_store.gd`) is a RefCounted service: `save_checkpoint(state, command_history)`, `load_checkpoint()`, `clear_checkpoint()`, `load_settings()`, `save_settings(settings)`, `load_history()`, and `record_summary(summary)`. Set its `content_validator` to the authority validator. Errors are returned in dictionaries rather than replacing a valid run with an empty state.
