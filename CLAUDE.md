# CLAUDE.md

## UI layout

- Every UI screen must fit on a single page with no scroll bar. Never add a ScrollContainer (or let content overflow) to make things fit - the only exceptions are the "Vault" and the Bestiary's creature list (one list down every mine, banded like the map).
- If a screen has too much content, split it into separate pages/views (tabs, steps, or sub-screens) instead of scrolling.

## Skill icons

- No two skills may share an icon (emblem), and no Birthstone may share one with a skill or another Birthstone. A new skill gets a new drawing in `view/gems/gem_icons.gd` (`SKILL_EMBLEMS` and `_emblem_shapes`); a Birthstone's is its `emblem` in `content/deep_cut.json`. `tests/test_view.gd` checks this.
- Several emblem drawings double as interface icons (`loupe`, `gem`, `reroll`, `copy`, `spark`, `flame`, ...). A redrawn skill emblem gets a new glyph name instead of editing a shared drawing, so the interface icon does not change with it.

## New skill gems: approve before implementing

- Before implementing any new skill gem (or Birthstone), put the whole proposal in an artifact for review and wait for every part to be approved. Do not write code or content until then.
- Icon: offer 3 different emblem options, drawn as `gem_icons.gd` shapes and shown the way the game renders them (flat mark at full and small sizes, and on the cut stone where possible). The user picks one or flags all of them for regeneration, with or without a comment.
- Everything else gets approve / reject / comment controls of its own: name, color, rarity, card text, activation requirement (trigger and Cut ladder), effects and numbers, and the Flawless line.
- Revise whatever was rejected or commented on, show the new version in the same artifact, and repeat until everything is approved. Then implement.
- Redrawing an existing emblem follows the same loop: 2-3 options per flagged emblem, pick one or flag again.

## Sockets, opals and twins (October 29, 2026)

- A socket is one color (`"RED"`), a two-tone pair (`"GREEN/VIOLET"`) or `"RAINBOW"` (`DeepContent.SOCKET_RAINBOW`; an old save's `ANY` reads as one). Down the mine any gem sits in any socket; a socket that *shows* the gem's color (`DeepStone.shows`) is lit and adds a point of Resonance when the gem fires. Only a Rainbow shows an opal. The loadout at home sets a gem only where a socket shows it (`DeepStone.fits`). Riders fire in `SOCKET_NONE` and never light. Never add a color gate to in-run placement.
- Opals interact. Never reintroduce a blanket opal exclusion: what stops loops is that a replay (`replay_color`, `replay_fizzled`) only reaches sockets earlier than the gem replaying, and that an Echo never copies an Echo (`DeepBattle.is_echo`). A Doublet wears any non-Doublet behind it. Mirror every change in `tools/data-browser/js/sim/fight.js`.
- Nobody carries two of one gem: a read twin in the bag sets `unit.twin` and the `twin` command (swap, toss, fuse) is the only one allowed until it is settled (`DeepDescent.check_twins`). Fusing costs `fuse_ore_cost` pyrite everywhere; the carat gain is `DeepOddities.fuse_gain`.
- Loadout luck: `DeepDescent.loadout_luck` (±2 a stone from three) rides on every stone the mine gives a player; apply it wherever a per-player stone is rolled.

## Carat scaling: three modes

A stone's weight (carat) reaches an effect in one of three ways. Pick by what the number is; `DeepRules.resolve_effect` (sim/rules.gd) and its mirror in `tools/data-browser/js/sim/rules.js` implement all three.

- **`"scale": "carat"` (the default for damage, block, heal, gold, poison, remove_block, retain, regeneration, spikes, lifeline, wager, detonate):** the amount is multiplied by the whole carat curve (`DeepStone.carat_multiplier`: 1x at 1 carat, 5.5x at 19, 10x at 24). Use it for plain output numbers a heavy stone should simply do more of.
- **`"scale": "steps"`:** the amount is multiplied by `1 + carat_steps`, where `carat_steps = (carat_multiplier - 1) / 3` (0 at 1 carat, 1 at 13, 3 at 24, so x1 to x4). Use it for numbers that multiply *other* numbers (Bloodletting/Stake amplification, Hemlock's share of Poison, Ferment's growth, Pinfire's Resonance). The whole curve would compound with the effects they feed and run away. Put the same `"scale": "steps"` on the matching entry in the skill's `numbers` so the card text shows the stone's real number.
- **No `scale` (procs):** a whole-number effect that cannot be a fraction (a reroll, a phantom die, a stun) happens more often instead: `carat_steps` read as extra goes, at most `MAX_PROCS` (10), the fraction as a chance of one more. Write `"scale": "none"` to keep an effect exactly flat (a cost the gem makes its owner pay, a fixed price).

A priced effect (`cost`) never procs, so it must be `carat` or `steps`. Any change to these rules is mirrored in the browser sim and checked by `tests/test_limits.gd`, `tests/test_stones.gd` and `tools/data-browser/parity.mjs`.
