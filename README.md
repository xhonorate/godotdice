# Deep Cut

A cooperative dice-and-stone roguelike for one to four players, built in **Godot 4.7.2** with typed GDScript and the Forward+ renderer. You are a lapidary with a bottomless mine under your workshop. Go down with a setting full of stones and a bowl of dice, fight what lives in the rock, pull raw stones out of the walls, and decide at every landing whether to ride the lift home or dig deeper where the stones are bigger. Back at the bench, every stone goes under the loupe.

The design of record is [docs/REIMAGINING.md](docs/REIMAGINING.md). This is a ground-up rebuild of the earlier RogueDice prototype: the procedural 3D stones, the poker-hand dice and the expedition loop survived; everything else was redone.

```sh
/path/to/Godot --path .                      # play
python3 tools/run_checks.py                  # every headless suite (needs Godot 4.7.2)
/path/to/Godot --path . --script tools/screenshot.gd -- battle build/shot.png   # a picture of a screen
/path/to/Godot --path . --script tools/biome_gallery.gd -- build/biomes          # every battle biome, one picture each
/path/to/Godot --path . --script tools/sound_gallery.gd -- gem                   # hear the sound bank (a filter plays one group)
```

## How it plays

- **Stones** have four C's. Colour is what kind of thing it does (Red damage, Blue guard, Green sustain, Violet control, Gold fortune, White the hand itself) and sets the cut shape. Carat is how much: one multiplier over everything. Cut is how often: every skill has a five-rung trigger ladder and a better cut stands on a looser rung. Clarity is how pure: Flawless and Pristine stones hit harder and are judged a Cut step better; Included, Veined and Riddled stones carry one, two or three **inclusions**, the affixes that make one stone unlike another.
- **Dice** are items too: shapes, face sets, special faces (wild, gem, exploding, locked, mirror, blank) and engravings.
- **A turn**: everyone rolls five dice, rerolls twice, locks in. Each player's rail of stones then fires gem by gem against their final hand, one step at a time on every screen. Each stone that fires adds **Resonance**; a fizzle resets it; two neighbours of one colour resonate harder; the Capstone socket cashes it in as carats.
- **The Descent**: a shaft charted one stretch at a time. Between landings the way down is a lattice of chambers whose tunnels split and rejoin; the lantern shows two depths ahead, past that only glints, and a loupe (or ore) lights the whole stretch. A landing every fourth depth with a lift, a lapidary, a merchant and a bench, and a Warden at 8, 16 and 24. Below 24 the mine is Endless.
- **Co-op** is the baseline. The host runs the rules and streams every step as an event plus a state patch; guests mirror and animate. Solo play is the host talking to nobody.

## Layout

| Where | What |
|---|---|
| `sim/` | The rules, pure and headless: dice, hands, patterns, the rule language, stones, the forge, the battle step machine, creatures, the descent, oddities, the profile, the state patch |
| `content/deep_cut.json` | Every skill, inclusion, die, setting, creature, mine and oddity, as data |
| `net/` | The host/guest session and the ENet and Steam transports |
| `profile/` | Atomic saves for profile, settings and run checkpoints |
| `view/` | The screens: app shell and UI kit, workshop tabs and the mine map, the run pages and shaft map, the first-person battle, stone cards, procedural stones, dice and creatures |
| `view/battle/` | The battle chamber: biomes by mine and depth, the low-poly room builder, effects, the camera rig, lens flares and the screen pass |
| `view/audio/` | The sound: a synthesiser, the bank of recipes every sound is written from, and the mixer the screens call |
| `view/gems/thumbs.gd` | The thumbnail service: stones and dice are rendered once and shown as textures; only the stone a page is about is live 3D |
| `tests/` | Headless suites run by `tools/run_checks.py` |

## Status

The look (September 19, 2026): every screen was redone around icons and pictures rather than text. Fights happen in one of seven procedural low-poly biomes (galleries, seeps, crystal veins, mycelium, magma seam, geode heart, the Rift) chosen by depth, with Warden and elite variants, volumetric fog and ground mist, flickering and surging lights, lens flares, drifting particles, and a camera that breathes, shakes, punches and leans. Every gem that fires throws a bolt of its colour at its target; blows land with sparks, shockwaves, shards and numbers. The run has a shaft map, the workshop a cross-section map of the mines. Stones and dice in lists are cached thumbnails, which took the vault from a three-second stall to about 40 ms to open. The battle drops its most expensive effects on its own if the frame rate stays under 40.

The lantern map (September 19, 2026): each stretch between landings is charted as a branching lattice, two mouths wide at the top and a mouth wider each depth, every chamber leading to the two nearest below it. The map panel draws it with the way taken, the ways on (clickable, hover to trace where they lead), and fog past the lantern's reach with glints for what is hidden: eyes for something hostile, a sparkle for something glittering, a question for something strange. Tunnel cards show what each way leads to next. Esc or the gear in the corner opens the menu: resume (a solo dig pauses), settings (fullscreen, vsync, graphics quality, screen shake, fewer flashes, fight speed), controls, abandon the expedition (the host only; it counts as a fall), leave the party, quit.

The sound (September 21, 2026): there is not one audio file in the project. Every sound is written sample by sample by `view/audio/synth.gd` — struck bells, filtered noise, swept tones, plucked strings — and the 69 recipes in `sound_bank.gd` are baked into streams on a worker thread while the workshop is on screen. The palette is underground: the interface is wood and small stones, each stone colour rings as its own kind of crystal, rock is noise, metal is the lift and the lock, and creatures shatter. The mixer pools voices on its own bus, pans anything with a place on screen, will not start the same sound twice inside a few milliseconds, and wobbles the pitch of anything physical. The appraisal is the slot machine it was designed as: light, then a chord per grade, and a Star has a sound of its own. Master and effects volume are on the settings page.

Right-click any stone, die, creature or creature intent for the close look: a large live model and everything about it (a stone's trigger ladder and four C's, a die's faces, a creature's moves and trick). Every buff and debuff (poison, stun, curse, block, buried or clouded sockets, stolen dice, extra rerolls, Sparkle, a Shrine's blessing, a creature's trick, enrage) is a chip with its own mark and explanation. A chamber's results stay on screen until the player moves on: the rock with every find in it after a vein, the spoils after a fight, the outcome of an oddity.


Phases 0 and 1 of the plan are complete and Phase 2 through 4 have a first playable pass: a full loop from the workshop through fights, veins, oddities, landings, Wardens, salvage and back to appraisal, solo or over LAN. The look is a first pass: procedural crystal creatures and a flat UI frame. See the status section of the design doc for what is next.
