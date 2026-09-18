# Deep Cut

A cooperative dice-and-stone roguelike for one to four players, built in **Godot 4.7.2** with typed GDScript and the Forward+ renderer. You are a lapidary with a bottomless mine under your workshop. Go down with a setting full of stones and a bowl of dice, fight what lives in the rock, pull raw stones out of the walls, and decide at every landing whether to ride the lift home or dig deeper where the stones are bigger. Back at the bench, every stone goes under the loupe.

The design of record is [docs/REIMAGINING.md](docs/REIMAGINING.md). This is a ground-up rebuild of the earlier RogueDice prototype: the procedural 3D stones, the poker-hand dice and the expedition loop survived; everything else was redone.

```sh
/path/to/Godot --path .                      # play
python3 tools/run_checks.py                  # every headless suite (needs Godot 4.7.2)
/path/to/Godot --path . --script tools/screenshot.gd -- battle build/shot.png   # a picture of a screen
```

## How it plays

- **Stones** have four C's. Colour is what kind of thing it does (Red damage, Blue guard, Green sustain, Violet control, Gold fortune, White the hand itself) and sets the cut shape. Carat is how much: one multiplier over everything. Cut is how often: every skill has a five-rung trigger ladder and a better cut stands on a looser rung. Clarity is how pure: Flawless and Pristine stones hit harder and are judged a Cut step better; Included, Veined and Riddled stones carry one, two or three **inclusions**, the affixes that make one stone unlike another.
- **Dice** are items too: shapes, face sets, special faces (wild, gem, exploding, locked, mirror, blank) and engravings.
- **A turn**: everyone rolls five dice, rerolls twice, locks in. Each player's rail of stones then fires gem by gem against their final hand, one step at a time on every screen. Each stone that fires adds **Resonance**; a fizzle resets it; two neighbours of one colour resonate harder; the Capstone socket cashes it in as carats.
- **The Descent**: a straight shaft. Two or three tunnel mouths per depth, a landing every fourth depth with a lift, a lapidary, a merchant and a bench, and a Warden at 8, 16 and 24. Below 24 the mine is Endless.
- **Co-op** is the baseline. The host runs the rules and streams every step as an event plus a state patch; guests mirror and animate. Solo play is the host talking to nobody.

## Layout

| Where | What |
|---|---|
| `sim/` | The rules, pure and headless: dice, hands, patterns, the rule language, stones, the forge, the battle step machine, creatures, the descent, oddities, the profile, the state patch |
| `content/deep_cut.json` | Every skill, inclusion, die, setting, creature, mine and oddity, as data |
| `net/` | The host/guest session and the ENet and Steam transports |
| `profile/` | Atomic saves for profile, settings and run checkpoints |
| `view/` | The screens: app shell, workshop tabs, the run, the first-person battle, stone cards, procedural stones, dice and creatures |
| `tests/` | Headless suites run by `tools/run_checks.py` |

## Status

Phases 0 and 1 of the plan are complete and Phase 2 through 4 have a first playable pass: a full loop from the workshop through fights, veins, oddities, landings, Wardens, salvage and back to appraisal, solo or over LAN. The look is a first pass: procedural crystal creatures, a flat UI frame, no audio yet. See the status section of the design doc for what is next.
