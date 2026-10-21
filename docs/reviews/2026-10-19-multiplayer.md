# Multiplayer playtest — 19 October 2026

**Owner decision:** All suggestions in this report are rejected. Do not implement them; retain this report as audit evidence.

This is the multiplayer/session part of the broader game review. The game was driven through real localhost ENet connections, with a separate Godot process for the host and for each guest. These are automated playthroughs through the same session commands used by the UI; they do not replace the rendered menu and visual review.

## Setup and reproducibility

- Godot: `4.7.2.stable.official.ed1daf0bf` on macOS.
- Every process creates a fresh in-memory profile. `DeepSaveStore.override_directory` points at a generated scratch directory; no real profile, settings, or checkpoint is read or written.
- Ordinary-play parties use Ardor, Vesper, and Rue with their initial loadouts. The Seeps runs exercise the normal deeper-start temporary stones and dice offers. A fixture purse permits selecting the deeper mine; battle health, damage, rewards, and enemy stats are not modified in these batches. Additional explicitly boosted traversal fixtures are reported separately.
- Bots reroll low dice, lock in, select routes, mine within a health budget, leave merchants and room cards, trade stones collected during the run, take respites, vote to extract/descend, acknowledge salvage, and return to the workshop session.
- Host battle animation waits are accelerated. This is a correctness and progression check, not a rendering or latency benchmark.
- Each guest's normalized full-state SHA-256 hash is compared with the host at every received revision. Files retain coverage, commands, refusals, engine output, results, and progress diagnostics.

```sh
# A fresh checkout needs Godot's global-class cache first.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import

# Eight seeds each with two, three, and four players: 24 Quarry runs.
python3 tools/playtest_enet.py --output build/playtest-enet-final

# Deeper starts and extraction: six Seeps runs.
python3 tools/playtest_enet.py --players 2,3,4 --seeds 4242,4244 \
  --mine SEEPS --output build/playtest-enet-final-deep

# Disconnect and rejoin the same profile during a battle: two runs.
python3 tools/playtest_enet.py --players 2,4 --seeds 4243 \
  --mode rejoin --output build/playtest-enet-final-rejoin

# Explicitly boosted loadouts: validate late progression, not balance.
python3 tools/playtest_enet.py --players 2,4 --seeds 4243 \
  --mode traversal --output build/playtest-enet-final-traversal

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_net.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_descent.gd
```

`--godot /path/to/Godot` or `GODOT_BIN` overrides executable discovery. Host ports are derived from the coordinator PID, so independent sweeps can run together. Generated evidence is under `build/`; summaries are `summary.json` in each output directory.

## Fixes made

### Trade offers could desynchronize after a stone was equipped

Reproduction: two players offer stones; one accepts, then equips their offered stone from the bench; the other accepts. Previously the offered stone remained on the table after leaving the bag. Completing the trade removed/restored the other stone, changed the acceptance list, and cleared the table, but returned a refusal. Refusals send no state patch, so the guest and host silently disagreed despite retaining the same revision.

Equipping an offered stone now withdraws it and clears both acceptances as part of the published rail change. Accepting a stale offer validates both bags before changing either one. Regression coverage exercises the real linked session/patch path, including an older checkpoint containing a stale offer.

### A rejected appraisal could silently withdraw a trade offer

Reproduction: offer an already-appraised stone, then attempt to appraise it at the landing. The appraisal was correctly rejected, but its early trade withdrawal mutated the host without a patch. Trade withdrawal now happens only after a respite succeeds. The regression verifies that a refusal leaves the entire run unchanged on both sides.

### A disconnected trader could occupy the booth for the rest of the landing

The landing table has two places. A player who disconnected after offering a stone retained their place and any consent; the remaining players could be unable to complete any trade. Losing the connection now withdraws that player's offer and clears consent in the same presence update. Their stone stays in their bag for reconnection.

The new networking regression initially failed four assertions for the first two problems; the disconnect assertion also failed before its fix. All **98 networking assertions pass** after these changes.

## Results

The final ordinary-play sweep completed **32 runs in 96 separate host/guest processes**, issuing **3,859 player commands** and comparing **26,234 guest-state revisions**. There were **zero state mismatches, unexpected refusals, engine script errors/warnings, or worker failures**. Every process returned to the workshop session. Three correctly rejected, obsolete mining actions occurred after the room advanced; the UX consequence is described below.

| Batch | Runs / party sizes | Seeds | Results | Depths | Guest revisions compared |
| --- | --- | --- | --- | --- | --- |
| Quarry, initial loadouts | 24 / 2, 3, 4 players | 4242–4249 | 1 extraction, 23 falls | 3–9 | 20,712 |
| Seeps, deeper-start offers | 6 / 2, 3, 4 players | 4242, 4244 | 5 extractions, 1 fall | 4–5 | 3,567 |
| Quarry, disconnect/rejoin during planning | 2 / 2 and 4 players | 4243 | Both rejoined and completed to a fall | 6 | 1,955 |

The host streams included 1,437 rerolls, 756 locks, 261 mining strikes, 507 tunnel votes, 109 landing choices, 102 respites, and **22 completed stone trades**. Both disconnect cases published absence and restored presence. Covered rooms included fights, elites, Wardens, veins, merchants, oddities, smithies, carvers, vats, and wells. The combined machine-readable record is `build/playtest-enet-final-audit.json`; it also verifies every process's return marker.

Earlier development attempts are kept in separate output directories and are excluded from these counts. An early bot assumed process launch order equaled assigned network seat order; that harness error caused invalid trade requests in some three/four-player attempts. The corrected bot uses the host-assigned player ID and waits for command acknowledgement. The ordinary-play results above do not include boosted progression fixtures.

Two additional **boosted traversal fixtures**, with two and four players at seed 4243, each conquered the Quarry at depth 16 and returned to the workshop. These deliberately fill every character socket with 150-carat gems to make late progression reachable quickly; they provide no balance evidence. They exercised Warden/boss resolution, hoard choices, further descent, and the final conquest lift through real ENet. Both completed with zero mismatches, refusals, engine errors, or failed returns: **391 commands and 1,951 additional guest-state comparisons**. Including these fixtures gives **34 runs, 102 processes, 4,250 commands, and 28,185 comparisons**. The complete record is `build/playtest-enet-complete-audit.json`.

## Review suggestions

These are proposals for review, not implemented redesigns:

1. **Explain why an offer disappeared.** Equipping or spending a tabled stone and a partner disconnecting now cancel the offer correctly. A small message such as “Offer withdrawn: stone equipped” or “Offer withdrawn: partner disconnected” would make the reset easier to understand. Changing an offer already clears both acceptances; present that explicitly beside the Accept action.
2. **Teach the landing commitment early.** The lift needs pooled pyrite, and using a respite commits that player to continuing. A newcomer can reach a landing with stones but too little pyrite to leave. The game describes these rules, but a compact “Party purse / lift cost” comparison and an explicit consequence on the respite action would make the decision easier to assess. Review a visual mock-up before changing this layout.
3. **Keep acknowledgement visible on cooperative actions.** Multiplayer commands travel to the host before the result appears. Mining already tracks a pending strike. Apply the same visible pending state to ready/accept/vote actions if real high-latency testing shows repeated clicks or uncertainty. Localhost success cannot establish WAN responsiveness.
4. **Soften stale-action feedback after a room advances.** The live sweep captured guests putting their pick down just after a teammate emptied the last rock. The host correctly rejected the already-obsolete action with “there is no rock to walk away from”; both mirrors stayed equal and play continued. The app currently displays every refusal as a red toast. A neutral “The party has moved on” acknowledgement, or no toast once the new room is already visible, would read more naturally. Keep genuine invalid-action errors visible.

## Limits and remaining validation

- Steam was not running. Startup printed `SteamAPI_Init()`/“did not locate a running instance of Steam” messages. ENet stayed functional; these are environment startup messages, not a gameplay script failure. Existing networking tests exercise a mocked Steam backend, including lobby membership and transport restrictions; real Steam invitations, overlay, relay behavior, and NAT traversal remain untested.
- No packet-loss or artificial high-latency simulation was applied to the real ENet sweep. Existing linked-session tests exercise missing-step resynchronization, version rejection, late joins, departure, held rewards, reconnects, and reopening checkpoints.
- These bots provide reproducible progression and network evidence. Their wins/losses do not estimate human win rates, and the accelerated headless run is not a frame-rate or animation-quality measurement.
- Workshop **session return** is checked. Banking results into a real profile and rendered home-screen interaction belong to the separate save/economy and UI review.
