# The mines

Seven mines lie one under another below the workshop, and each is harder, deeper and richer than the one above it. The Quarry is open from the start; every other mine is sealed until the party beats the final boss at the bottom of the mine above it. Below the Geode is the Rift, which has no bottom.

Everything here is data in `content/deep_cut.json` under `mines`, read by `sim/forge.gd` (stones), `sim/descent.gd` (the shaft, the bosses, pushing on), `sim/profile.gd` (unlocks) and `view/battle/biomes.gd` (how each stretch looks).

## The ladder

| # | Mine | Depth | Wardens | Final boss | Usual carats | Cap | Luck | Creature health / damage | Lapidary met here |
|---|---|---|---|---|---|---|---|---|---|
| I | The Quarry | 16 | 8, 12 | 16 | ≤ 5 | 7 | −1 | ×1 / ×1 | (Ardor is the starter) |
| II | The Seeps | 20 | 8, 16 | 20 | ≤ 6 | 9 | 0 | ×1.8 / ×1.3 | Vesper |
| III | The Glass Veins | 24 | 8, 16 | 24 | ≤ 8 | 11 | +1 | ×3.2 / ×1.7 | Cadence |
| IV | The Warrens | 24 | 8, 16 | 24 | ≤ 9 | 13 | +2 | ×5.8 / ×2.2 | Rue |
| V | The Furnace | 28 | 12, 20 | 28 | ≤ 11 | 15 | +3 | ×10.5 / ×2.85 | Puck |
| VI | The Geode | 32 | 12, 24 | 32 | ≤ 12 | 17 | +4 | ×19 / ×3.7 | Florin |
| ∞ | The Rift | endless | every 8 | — | ≤ 13, +1 a Warden | 17, +1 a Warden, to 24 | +5 | ×34, doubling every 8 floors / ×4.8, +15% every 8 | — |

Landings still come every fourth floor and still wander a floor either way, Wardens with them; the bottom floor never moves. Every mine has its own two Wardens and its own final boss (see [the Bestiary](BESTIARY.md)); the Rift's are the bosses above it, remembered, with the Infinite Void every fifth.

## Creatures: who lives where

| Mine | Its own creatures | Bled in from above | Wardens | Final boss |
|---|---|---|---|---|
| Quarry | Cave Tick, Silt Slime, Magpie, Lantern Moth, Rail Rat, Quartz Golem, Clouder, Pit Mole, Vein Wraith, Glass Wyrm | — | the Foreman, the Mirror Regent | the Drill |
| Seeps | Seep Eel, Drowned Miner, Lamprey Knot, Cave Crayfish | Cave Tick, Silt Slime, Clouder, Vein Wraith | the Lock-Keeper, the Drowned Choir | the Undertow |
| Glass Veins | Echo Sprite, Glint Magpie, Will-o’-Wisp, Prism Golem, Refractor, Shard Wyrm | Cave Tick, Seep Eel, Drowned Miner, Clouder | the Glazier, the Kaleidoscope | the Prismarch and its Prisms |
| Warrens | Spore Slime, Mycel Weaver, Puffball, Cap Shambler, Mycel Wraith, Root Horror | Clouder, Drowned Miner, Echo Sprite | the Gardener, the Spore Mother | the Heartrot and its Tendrils |
| Furnace | Forge Imp, Salamander, Slag Hound, Fire Tick, Ember Crawler, Cinder Moth | Mycel Weaver, Clouder, Root Horror | the Smelter, the Anvil Knight | the Kiln Wyrm |
| Geode | Croupier Crab, Gilded Magpie, Geode Golem, Hoard Mimic, Amethyst Wyrm, Crystal Hydra | Salamander, Slag Hound, Forge Imp, Clouder | the Assayer, the Collector | the Hollow Crown |
| Rift | Void Echo (anything from the first four mines), Null Shade, Riftling Swarm, Entropy Eye | through the Void Echo | the Remembered: the Drill, the Undertow, the Prismarch, the Heartrot, the Kiln Wyrm, round again; every fifth the Infinite Void | — |

A variant (a Fire Tick for the Cave Tick) never stands within one mine of the creature it is based on, or of another variant of it; `tests/test_bestiary.gd` holds the bands to that.

## Stones: the carat band

Every mine writes a band, `carat: {soft, cap}`. Luck still raises the average carat (mine, depth, elites, Sparkle, hoards, wells), but the average levels off just under `soft` however much luck is piled on; past `soft` each further carat holds only 35% of the time, and nothing comes out over `cap` (`DeepForge.carat_band`, `roll_carat`). In the Quarry an ordinary find near the bottom is over five carats about one time in a hundred, an elite drop on a full stack of Sparkle about one in twenty, and nothing ever weighs eight. The Rift's band climbs a carat with each Warden (`carat_per_warden`), up to 24.

Only the Crucible, the Prospector and the Grubstake move carat past a band, because each of them pays for it with something else.

Luck sources were trimmed alongside: an elite's stone is +3 luck (was +4, `elite_stone_luck`), a Sparkle stack is 0.08 a point (was 0.1), a Warden's hoard +5 (was +6).

## Skills: one batch per mine

Each mine's `batch` is the skills first found in its rock. A mine's pool is its own batch plus every batch above it, and its own batch comes up twice as often (`DeepForge.skill_pool`, `HOME_BATCH_WEIGHT`). A skill in no batch is in every pool, so a new skill is never unfindable while it waits to be placed; `tests/test_descent.gd` fails until every skill outside the opals has a home.

| Mine | Style | Batch |
|---|---|---|
| Quarry (22) | the basics of every lapidary's style, all six colours | Strike, Cleave, Crush, Spall, Ember, Crosscut · Guard, Shelter, Anchor, Tempo, Bulwark · Mend, Graft, Bloom · Venom, Hex, Mist · Tithe, Prospect · Glimmer, Mirror, Refract |
| Seeps | one big die, hits, marks (Vesper) | Apex, Riposte, Etch, Shatter, Wager, Facet |
| Glass Veins | straights and rerolls (Cadence) | Barrage, Fury, Aegis, Renewal, Dread, Cascade, Gilded Armor |
| Warrens | low dice and poison (Rue) | Detonate, Siphon, Sap, Miasma, Curse, Polish |
| Furnace | odd, even and two pair (Puck) | Bind, Mortar, Thrive, Bastion, Enrich, Lifeline |
| Geode | pyrite and big totals (Florin) | Jackpot, Lucky Seven, Double Down, Stake, Appraise, Overkill, Prism |

New skills go into the later mines' batches first; they have room.

## Lapidaries

A lapidary is met at the first Warden of their mine (`lapidary`), and unlocking them brings their five dice into the bowl, as before. The first Warden counts whether or not the party gets out alive. Ardor is the starter and the Quarry has no lapidary of its own.

## Pushing on, or starting deeper

The final boss's hall is the one hall with a cage in it. After its hoard the party either rides up (the run ends conquered) or pushes on into the top of the next mine with everything it carries (`DeepDescent._push_on`):

- the rail, the haul, the purse and the wounds all come along, and nothing is banked: a fall loses both mines' finds;
- the new mine's depth starts again at 1, but its creatures are bred `chain_heat` (2) floors deeper for every mine pushed through (`heat`, read as the battle's `threat`);
- the winch counts every floor since the workshop (`carried`), so the lift home from the second mine costs the first mine's floors too;
- the run writes a record for every mine it went through (`results.mines`), and each one's boss and first Warden unlock as usual.

A party that starts in a deeper mine instead gets what the way down would have given it: every socket filled from the vault (`loadout_sockets`, 3 in the Quarry, all of them below) and a purse (`start_pyrite`). The loadout screen lets a stone into a socket past the third once any deeper mine is open; a Quarry run leaves those sockets empty.

## Harder, mine by mine

Each mine multiplies its creatures' health and damage (`hp_mult`, `damage_mult`) on top of the old per-depth scaling, and fights and elites take up more of every stretch (`chambers`): from 48 fights and 12 elites in the Quarry to 62 and 22 in the Geode, 65 and 25 in the Rift. The Rift keeps compounding (`growth`): health doubles and damage rises 15% for every eight floors.

The numbers are a first guess at "a party that just beat one mine dies at the first or second Warden of the next until it gears up". They need a balance pass with the bot over real loadouts.

## How each mine looks

Each mine lists three biomes in `biomes`, one per stretch: the base biome to its first Warden, then a deeper variant past each Warden (`view/battle/biomes.gd` `VARIANTS`, a base biome with only its differences written). Every room builds by its `family`, the base biome it deepens.

| Mine | First stretch | Past the first Warden | Past the second |
|---|---|---|---|
| Quarry | The Upper Galleries | The Lower Workings | The Quartz Cut |
| Seeps | The Seeps | The Flooded Drifts | The Black Sump |
| Glass Veins | The Crystal Veins | The Prism Halls | The Black Glass |
| Warrens | The Mycelium | The Bloom | The Rot |
| Furnace | The Magma Seam | The Ember Crystals | The Lavafalls |
| Geode | The Geode Heart | The Gilded Vault | The Amethyst Throat |
| Rift | The Rift, The Shattered Deep and The Echoing Deep, turning over every eight floors |

`tools/biome_gallery.gd` shoots every stretch of every mine.

## The map

The workshop's map is a cross-section of the earth with one stratum per mine, shallowest first. One shaft runs down through every stratum the player has opened and stops at rubble and a lock. An open stratum shows its depth track (a crown at each Warden and at the boss, gold once beaten), its carats and its lapidary; the expedition panel beside it adds the skills first found there and, for a deeper mine, what a run started there brings down.

## Not done yet

- A balance pass with the bot on the health and damage multipliers, the start purses, `chain_heat`, and the new creatures' health and threat (the Bestiary's numbers are the page's, untested against real loadouts).
- Opals by mine: every hoard still draws from all of them.
