# Networking, Steam and desktop exports

Deep Cut has one host authority for solo, LAN and Steam play (see `net/session.gd`). The host runs the rules and streams `{event, patch, revision}` to its guests; a guest that sees a gap in revisions asks for the whole state. A session uses exactly one transport, and both speak the same small interface (`send(peer_id, bytes)` plus `packet_received`, `peer_connected`, `peer_disconnected`, `connected`, `failed`):

| Transport | File | Use |
|---|---|---|
| ENet | `net/enet_transport.gd` | LAN and direct IP, UDP port 24567. Development only: not encrypted, no NAT traversal. |
| Steam | `net/steam_transport.gd` | Release. A friends-only Steam lobby is the party; Steam Networking Messages carry the packets over Valve's relays. |

## Pinned integration

- Godot **4.7.2 stable**, official build `ed1daf0bf`, Forward+ renderer (Vulkan 1.0 or D3D12 required).
- GodotSteam **GDExtension 4.22.1**, Steamworks **1.65**, upstream Godot compatibility minimum 4.4.
- Included native libraries: Windows x64; Linux x64 and ARM64; macOS universal. Debug/release libraries and their Steam API dependencies are included.
- Source, upstream ZIP SHA-256, and per-library SHA-256 values: [`addons/godotsteam/PINNED_BUILD.json`](../addons/godotsteam/PINNED_BUILD.json). Upstream license: [`addons/godotsteam/license.md`](../addons/godotsteam/license.md).

The GDExtension loads automatically; there is no editor plugin to enable. Steam initializes at game startup (`steam/initialization/processes/initialize_on_startup=true`), before the renderer creates its device, which is what lets the Steam overlay hook the D3D12/Vulkan swapchain. Initializing later leaves `isOverlayEnabled()` false for the whole process. `DeepSession` pumps Steam callbacks every frame, so an invitation accepted in Steam reaches the workshop during solo or LAN play too. If Steam was not running at launch, the first Host on Steam or Join initializes it then; lobbies work but the overlay does not until the game restarts. Headless test runs initialize Steam too when the client is running; the suites never touch it (they use a stand-in).

## How the Steam transport works

- **Hosting.** Host on Steam creates a friends-only lobby of four. The lobby ID shows under Play together with Invite friends (the overlay's invite list) and Copy ID.
- **Joining.** Three ways in: the overlay invite, Join Game on the host in the Steam friends list, or pasting the lobby ID into the Steam lobby ID field and pressing Join. A friend who accepts while the game is closed is launched with `+connect_lobby <id>` and joins on startup. An invitation accepted in the middle of an expedition asks before leaving it.
- **Who is who.** The lobby owner, as it was when a guest joined, is the host. Steam IDs travel as decimal strings. Only lobby members are heard: a session request from anyone else is never accepted and their messages are dropped. A guest takes packets from the host alone.
- **Packets.** Reliable and in order on channel 0, with auto-restart for broken sessions. Every message starts with one tag byte (whole / part / last part); anything over 256 KiB is cut into parts, because Steam refuses a message over 512 KiB, and reassembly is capped at the codec's 1 MiB packet limit.
- **Presence.** Lobby membership decides who is here. A member leaving the lobby (or crashing, which Steam notices) is a disconnect: the host marks that seat away; a guest whose host leaves goes to `lost`. A failed networking session with someone still in the lobby is not a disconnect: the next send restarts it and the revision gap check recovers the state.
- **Offline.** If the build has no GodotSteam, Steam will not start, or the client is in offline mode, Host and Join say so in a toast and the workshop is left as it was.

The suite `tests/test_net.gd` drives three sessions through a stand-in for the GodotSteam singleton: hosting, bad and vanished lobby IDs, seating, a guest ignoring another guest, a stranger ignored by the host, a guest leaving, a whole run start, a 700 KiB packet in parts, invitations, the overlay, launch arguments and host loss.

## Testing with real Steam

A single account cannot join its own lobby, so a real test needs two Steam accounts on two machines (or one machine plus a Steam Deck).

1. Both machines: Steam running and **online** (`loggedOn()` false means offline mode; lobbies fail with result 3).
2. Both: launch the same build of the game. With the test App ID 480 the game shows as Spacewar in Steam, and both must already be running before an invite is accepted; otherwise Steam launches Spacewar itself.
3. Host: Map tab, Play together, **Host on Steam**. The lobby ID appears.
4. Host: **Invite friends** (exported build, overlay on) or **Copy ID** and send the number.
5. Guest: accept the invite, or paste the ID and press **Join**. The party card shows both lapidaries.
6. Guest: **I'm ready**. Host: **Descend**, then play a fight to the end on both.

The overlay may not appear when the game runs from the editor; an exported build launched with Steam running is the real test. Also worth checking before release: a guest closing the game mid-fight (the host should mark them away and the fight resolve), the host closing the game (the guest shows Disconnected), and an invite accepted mid-expedition (the menu asks first).

## Play locally or over LAN

Choose Host on LAN on one machine. Other players type its LAN address and press Join (a loopback test uses `127.0.0.1`). Each player readies; the host's Descend opens when everyone connected is ready. The party is one to four.

## Release checklist

- Replace `steam/initialization/app_data/app_id=480` in `project.godot` with the real App ID.
- Keep `initialize_on_startup=true`; without it the overlay and its invite dialog never appear.
- Do not ship a `steam_appid.txt` in a production depot; an adjacent one containing `480` only helps a test build started outside Steam.
- Consider `restartAppIfNecessary(app_id)` at startup so a copy started outside Steam relaunches through it.
- Rejoining mid-run keeps a seat only if the hello carries that seat's ID; tying seats to Steam IDs would let a crashed guest reclaim theirs.

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
