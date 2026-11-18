# Balance runs

November 17, 2026. How the balance is tested: whole runs played through the game's own rules by a bot, every Birthstone of every delver down every mine, and what those runs say about the stones, the gems and the creatures.

The older sweeps (`tools/data-browser/balance.mjs`, the Balance page) still stand. They play a rail against training dummies in a port of the fight, which is fast and is the right tool for one question: what is the strongest rail there is (the hunt and its gate). They cannot say what a Birthstone is worth over a run, what a creature costs, or which Warden ends runs. The balance runs answer those.

## Running it

```sh
node tools/balance/delve.mjs calibrate                 # once, and after a big change: find the kit each mine is played with (6 min)
node tools/balance/delve.mjs run                       # every Birthstone, every mine, 40 seeds each: 5,040 runs (25 to 30 min)
node tools/balance/delve.mjs gems                      # a finer reading of the gems, added to that run: 5,040 more (30 min)
node tools/balance/delve.mjs run --gem-seeds 120       # both at once (an hour)
node tools/balance/delve.mjs run quick --seeds 12      # the same, coarser (8 min), kept under another name
node tools/balance/delve.mjs run rue --delvers RUE --mines SEEPS,WARRENS --seeds 80   # one delver, two mines, finer
node tools/balance/delve.mjs run hemlock --plant HEMLOCK --seeds 20                   # one gem on every rail
node tools/balance/delve.mjs run tried --pack build/tried.json                        # a changed copy of the pack
node tools/balance/delve.mjs report [name]             # read a run again without playing it
node tools/balance/delve.mjs run look --mines QUARRY --seeds 4 --trace               # a few runs that keep every fight turn by turn
node tools/balance/delve.mjs fights look --foe THE_REGENT --lost                     # read those fights: why a creature does what the report says
node tools/balance/delve.mjs diff before after         # what moved between two runs
node tools/balance/delve.mjs list
```

It needs Godot 4.7.2 (found the way `parity.mjs` finds it: `GODOT_BIN`, the path, or a build on the desktop) and plays on every core but two. A run is kept in `build/balance/delve/<name>/`:

| File | What |
| --- | --- |
| `runs.jsonl` | one run a line: the kit, every fight, every gem's tally, what ended it |
| `summary.json` | everything the report shows, as numbers |
| `report.md` | the report as text (what `run` prints) |
| `report.html` | the report as a page: open it from disk |
| `report.page.html` | the same page without its wrapper, to publish as an artifact |

Running a name again keeps the run before it as `<name>.prev`, and the report marks what moved.

**The gems' own pass.** A gem is read by the runs it was planted in (see Gems below), and a delver's three stones are planted the same stone on the same seed, so 40 seeds read a rare gem off a dozen kits: too few to say much. `gems [name]` adds a pass to a run already played, with its kits: the first stones only, 120 seeds of their own, every run a different kit. `--gem-seeds N` on `run` plays both together. Those runs count for the gems and for nothing else on the report.

## What a run is

One delver, one Birthstone, one mine, one seed. The run starts at the mine's shaft head with a rail from the vault and ends when the mine's boss is dead and its hoard taken (in the Rift: two Wardens), or when the delver falls. Nothing is ported or approximated: the bot (`tools/balance/bot.gd`) sends `DeepDescent.command` what a player's clicks would send, and the fights are stepped by `DeepDescent.step`. Every room, stake, spoils card, stall and hoard is the game's.

**The kit.** A delver brings as many stones as they would have sockets open by that mine (three in the Quarry, one more a mine). They are chosen from a small vault drawn for the job: twice as many skills as open sockets and two more, each one the mines above could have given, and now and then an opal. The vault is drawn from the seed and the delver, never the Birthstone, so a delver's three stones choose from the same vault and go down the same shaft. One stone of the vault is set whatever it is worth (the **plant**, see Gems below); the bot fills the other sockets one at a time with the stone the rail gains most by, as the loadout at home allows (a socket takes only a stone it shows).

**How well stocked the vault is** is a rung of a ladder (`KITS` in `delve.mjs`): the carats, Cut and Clarity of every stone in it, read off the mine's own carat band. `standard` is the mine's soft cap, cut Keen, Clear. `rich` is the mine's cap, cut Perfect. Above that the stones grow two carats a rung and turn Pristine, then Flawless; `peak` is 24 carats, Perfect, Flawless. `calibrate` plays every mine at every rung with the first stones only and keeps, for each mine, the lowest rung at which the bot beats the boss 40% of the time. That is the rung `run` plays the mine at (`--kit auto`), so every mine is read where it is neither a walk nor a wall. A mine the bot does not beat at any rung is played at `peak`.

The rung a mine needs is a finding in itself. On November 17 the Quarry was played at `standard`, the Seeps needed `rich+4` (13 carats, Pristine), the Furnace `rich+8`, the Glass Veins and the Warrens `peak`, and the Hollow and the Rift were beaten 3% of the time at `peak`. Part of that is the bot (see What it cannot tell you); the order of the mines is not.

## The bot

It has no opinions about gems. Whatever it weighs, it weighs by playing it.

- **A hand.** `play_rail` plays the party's half of a turn for real on a copy of the fight: every gem, every replay and repeat, the Birthstone, and whatever a creature sends straight back (a mirror, a Refraction, Spikes). `turn_worth` reads what that left: the health taken off the creatures, what those still standing are expected to do in answer (every face of their dice, each as likely as the next, and what a Reflection would throw back) against the block now up, the bot's own health, and what it set standing. A hand that leaves the bot dead is worth nothing at all.
- **A reroll.** The ways of keeping dice that the rail's triggers and the Birthstone's tiers would chase are each thrown twice and played out. The best is taken if it beats standing. A hand that ends the fight is not thrown again.
- **Dying.** Every face of every creature's dice is read for whether it would be the end of the bot, with what the hand dealt thrown back on the faces that throw it back (a Regent's Reflection). A hand that leaves a fair chance of that is one to get out of: the whole bowl is thrown too, to see whether a weaker hand is the safer one.
- **Aim.** Never a mirror while anything else stands; an escort before the leader it shields; the biggest creature the hand would fell; else the one nearest falling. If the hand would kill the bot aimed there, it tries the others.
- **The rail.** A stone is worth what the whole rail gains by it: the rail played out on sample hands against creatures of the mine it is in, half as that room would have it (overkill wasted, what survives throws back) and half as the next Warden would (only what lands counts). So a gem that completes what is set is seen to, and the bot does not take a combination apart.
- **The mine.** Fights when healthy, elites when very healthy, the rock while swings are cheap, the stall to read raw stones and buy what the rail gains by, rest when hurt, the opal from a hoard. It takes a die's work from the spoils only when the rail plays better for it.

## Reading the report

Every number is read against its neighbours. The same bot plays every stone, gem and creature, so what one does beside another is the game's doing. How far the bot gets at all is partly the bot's.

**What stands out** is the short list: whatever sits two standard errors from its peers by a difference worth acting on (six points of progress for a delver, a stone or a gem). The numbered list on top is the one that stands furthest of each kind. Start there, then look at the table the line came from.

**Mines.** *Clear*: the share of runs that beat the boss. *Progress*: the share of the mine's floors a run left behind, the boss counted. Where runs fell (a fight, an elite, a Warden, the boss) and what ended most of them.

**Wardens and bosses.** How many runs reached each, how many of those beat it, in how many turns, and what the fight cost as a share of a full health bar (it can pass 100%: healing counts). *Thrown back* is the part of that the creature sent back for blows it was dealt. The grid is each delver's share of wins. *A wall* is beaten by 55% or fewer of the runs that reach it, or is a Warden on the way down that ends a fifth of all its mine's runs (a boss ends many by the way the kit is chosen, so it is not held to that); *a walkover* is beaten by 97% or more, for under a quarter of a health bar.

**Delvers and Birthstones.** *Edge*: progress over the middle stone in the same mines, in points (the middle, not the average: one weak delver would lift all the others). A delver's line is all three of their stones. *Against its siblings*: the stone beside its delver's other two on the same seeds, a paired difference, so it reads finer than the edge and says which of a delver's three is out of line. *Fires*: how often any tier lit, a turn. *Damage*: the stone's share of everything the delver dealt. The grid is clear, mine by mine; the line under each stone is how often each tier lit.

**Gems.** Four readings, the first the cleanest.

- *Planted.* Every run sets one stone of its vault on the rail whatever the bot thinks of it. Those runs are set against the other runs of the same delver, stone and mine, and the difference is the gem's. It is the only reading that does not depend on the bot liking the gem. *Kits* is how many different kits that is (a delver's three stones on one seed are one kit, and count once). It needs kits: about 60 to read a gem to within four points, which is what the gems' own pass is for.
- *Light kits* and *heavy kits* split that by the carats of the kit (under 16, and 16 up). A gem that only stands out one side of the line scales too well with carats, or not at all.
- *Chosen*: how often the bot set it when it lay in the vault unplanted. *Taken*: how often it took it when the mine offered it. Both say what the gem adds to a rail as the bot plays it, a turn ahead.
- *Did a turn*: what it did for each turn it sat on a rail, from the game's own tally (damage, 0.7 a point of block, 0.8 of healing, 1.5 a debuff). *Against peers*: that at one carat, beside the middle gem of its rarity that does anything a tally shows. *Outsized* is four times that or more. A gem that works through something else (a reroll, a raised face, an amplifier) shows little here and is read by its planted runs.
- *Rarely fires*: lit on under 15% of the turns it sat. *Never chosen*: the bot set it on under 8% of the rails it could have.

**Creatures.** *Hurt*: the health one of them took off the bot in a fight, as a share of the bot's health, and that against the middle creature of its mine. *Stood*: turns it lasted. *Ended*: the runs it finished.

**Whose doing a point of health is.** Every point the bot loses is put down to something, and the test suite holds the books to adding up:

- a creature's own action: that creature;
- a tick of Poison or Burn: whoever laid the stacks, shared by how much each laid (so a Mycel Weaver's Fangs are the Weaver's, not "poison");
- a blow that comes back while the bot's own rail fires (a mirror, a Refraction, Spikes, a Jagged or acid hide, a Swarm's Backlash) or a toll a creature takes for a throw (a Hall of Mirrors, a lantern): the creature that asks it. This is the *thrown back* column;
- a tier of the Birthstone that costs its owner (Florin's Bust): the stone. The Birthstones table says what that comes to, as a share of a health bar a fight;
- anything else the rail costs its owner with nothing standing that answers blows: the bot's own.

## What it cannot tell you

- The bot looks one turn ahead. It does not plan a fight, save anything for a Warden or build toward a combination it has not been dealt. Rails that win by an engine (the hunt's Hemlock and Rainbow Seam rails) are stronger in a player's hands than in the bot's, and the deep mines are tuned for them. That is most of why the bot needs heavy kits there.
- It leaves the smithy, the carver, the vat, the altar, the well and the gambling cards alone, so every delver throws the dice they were made with. No Transcendent gem is made, so none is tested (plant one with `--plant` to see it).
- The bot hoards pyrite. It buys a stone only when the rail gains by it and never spends a purse down: on November 17 it ended a Quarry run holding about 400 and a Warrens run about 1,300. Whatever reads the purse sees a fuller one than a player would bring: the Assayer's Tax (a tenth of it, as damage) and Eat the Rich (1% healed and grown for every 10 held) make that Warden a wall for the bot and may not for a player who spends before the fight; Gilded Armor's block is read off the same purse.
- Florin's rail is gold, and gold gems feed on pyrite. The bot has no plan for a purse (when to hold, when to spend), so Florin is played short of what a player would get from him.
- A creature the bot handles badly looks worse than it is. It reads mirrors, Refraction, Spikes, a Reflection, a gathered charge and escorts; it does not read a countdown, a summons to come or a face about to be re-etched. Read a flagged creature's row, then its text, then a fight: `run look --mines QUARRY --seeds 4 --trace` keeps every turn of every fight (the hand, what each gem did, what each creature threw), and `fights look --foe KEY --lost` prints them.
- The home loadout sets a gem only where a socket shows it, so a kit is the colors of its delver's sockets. Florin's is all Gold.
- A number with few runs behind it is noise. The report marks nothing that is under two standard errors; the tables show everything, with the runs beside it.

## Changing a number

1. Run it as it is: `node tools/balance/delve.mjs run base --seeds 40`.
2. Change `content/deep_cut.json` (or a copy, with `--pack`).
3. Run it again under the same name. The report marks what moved, and `base.prev` holds the run before.

The seeds, the vaults and the shafts are the same both times, so what moves is the change and the dice the change set rolling. For one gem or one stone, narrow the run (`--delvers`, `--mines`, `--stones`, `--plant`) and raise `--seeds`.

**Trying a change before making it.** Write a changed copy of the pack, play it under a name of its own with `--pack` on a slice of the jobs, and set it against the kept run job by job: a job's id is its delver, stone, mine and seed, so the two runs pair up, and 240 to 700 paired runs read to about a point of progress. `--plant X` set against the kept run is X against the average plant. A rules change cannot be tried this way: play the nearest content change and say so. The scratch tools that pair runs are in `build/balance/tuning/whatif/` (`cmp.mjs` two runs by stone, mine or delver; `foe.mjs` a creature in two runs; `gem.mjs` a planted gem). Never play two runs of one name at once.

A planted gem's points, to read them by: a gem that does nothing reads 5 under the average plant, Strike 6 over, Strike doubled 8 over; block is worth less than it looks (Anchor +4, doubled +6). A full run's reading of a gem set in 30 kits is often 4 to 6 points off. Plant it in a run of its own before calling it.

## The first tuning round (November 17, 2026)

The first full run was read into 25 calls, each with a size and one or more fixes, most of them played first as a what-if (68 runs, 22,660 jobs). The owner marked them on the review page (https://claude.ai/artifact/XatLhfzHmBf1socNM5DiYU, db `tune1`): 20 changes approved and built, 3 calls marked leave it (Strike, Apex and Temper, the Assayer) and 2 rejected (the Mirror and Refract, the Collapsar). What changed is in docs/CHARACTERS.md (the stones) and docs/BESTIARY.md section 15 (the creatures); the six gems that read a share of another number went from the whole carat curve to its steps (CLAUDE.md, Carat scaling).

The full run was then played again on the same seeds and kits (8,400 jobs, paired; the run before is kept as `nov17_before`):

| What | Before | After |
| --- | --- | --- |
| Every run | 67.9% of the way, 34% clear | 71.3% (+3.4, give or take 0.2), 38% clear |
| The Quarry | 55% clear | 76% |
| The Mirror Regent (Reflection throws back half) | beaten 74%, ended 260 runs | beaten 95%, ended 54 |
| The Kaleidoscope (Glare 11) | 11% of a health bar | 18%; beaten 98% as before |
| Salamander (Ember 4) | ended 233 runs | 151 |
| Slag Hound (two Mauls, two Bites) | ended 154 runs, 13% of a bar a fight | 84 runs, 9% |
| Mycel Weaver (Fangs 2 of 1) | ended 216 runs | 155; a fight with one costs the same 5% |
| Florin (payouts ×5, 80 health) | 4% clear | 17% (+15 points); still 26 points under the middle stone |
| Bloodroot (head start 175%) | 56% clear | 49% (3 points less far); still 7 over Rue's other stones |
| Nocturne (lines 18, 14, 11; Dead of Night) | 31% clear | 32% (+2.6 points, give or take 1.6); Dead of Night lit one turn in a hundred |
| Mithridate (the coat grows with Resonance) | 33% clear | 36% (+2 points, give or take 1.5) |
| Encore (Overture ×6) | 27% clear | 28%: nothing, as its what-if said |
| The thieves and the lanterns | harmless | harmless: nothing that shows for the bot |

The gems, as output a turn carat for carat against the middle gem of their rarity: Thirst 5.7× → 3.1×, Gilded Armor 18.5× → 7.2×, Detonate 5.5× → 3.5×, Bash 3.9× → 2.3×, Hardening 2.0× → 1.0×, Hone 2.3× → 1.7×; Lodestone fires on 63% of turns, was 29%. Siphon (3.1 billion Poison a turn → 600 million) and Fortify (2.3 million block → 23,000) still run away on steps: each feeds on what it made, which only a flat share stops.

Still standing out after the round: Florin, Siphon and Fortify, Encore, the Assayer, the Rift's Drill, the Collapsar, and the Glass Veins' mirrors (Echo Sprite, Prism Golem).

## The lit-socket rule (November 18, 2026)

The owner's rule: a gem rings Resonance only from a socket that shows its color (1, and 1 more for Harmony). In any other socket it fires but rings nothing, takes no Harmony and gives none to the gem after it; the lit socket's own extra point is gone. A Void rider sits in no socket and rings as before.

Played on the same 5,040 jobs (40 seeds, the calibrated kits; `build/balance/delve/res_*`, compared job by job with `build/balance/resonance/res_cmp.mjs`):

| | Today | The rule alone | The rule and the Birthstone buffs |
| --- | --- | --- | --- |
| Progress | 68.3 | 66.6 (-1.7 ±0.3) | 68.3 (±0.0 ±0.2) |
| Boss beaten | 25% | 20% | 25% |
| Resonance a turn | 34.9 | 28.0 | 27.0 |
| The Quarry, boss beaten | 60% | 44% | 51% |

Almost all of the loss is the lit socket's +1: muting unlit gems while keeping it cost only 0.4 points, because the bot nearly always sets a gem in a socket of its own color (about a tenth of its fires were unlit). Every Birthstone reads Resonance linearly, so the buffs are whole multipliers (no flat additions, on the owner's word): plain Resonance to twice Resonance on Rank, Parapet, Thornwork, Thousand Cuts and Clean Kill, Reckoning and Snake Eyes, the Fan and Flourish knives, Transfusion, Comedy, Tragedy and Scraps; File 4×, Legion 7×, the Faces 4× (Full Motley 8×), Lucky 7×, High Roller's Jackpot 10×, the Bandit's prizes 8×/16×/32× and its Jackpot pyrite 10×, Stand 7×; Mithridate's Coat one Envenomed for every 3 Resonance. The owner kept Overture at 6×, Tincture, Take Root and Mithridate's stabs at 1×, and made Twenty-One 7× Resonance 21 times (it was 35× three times; played on 840 Blackjack jobs it is level with 21× three times, -0.1 ±0.6, and with the game before the rule, +1.1 ±1.2); these were marked after the runs above, so that table is a little ahead of what was built. The review page is https://claude.ai/artifact/RGzsCWXZRTLEPbAMdRbyUn (db `res1`).

Still open: the Quarry stays harder (its three-gem rails lose about 40% of their Resonance, deeper rails 15 to 20%); gems that read Resonance (Pinfire, the Seams, Crescendo, Hydrophane, Prelude) were not looked at; Ardor's Second Wind heals by Resonance and was left as it is.

## Checks

`tests/test_delve.gd` holds the bot to finishing a run, to one job always playing the same run, to one vault for a delver's three stones, to every point of health lost being put down to something, and to a played-out hand leaving its fight untouched. `tools/run_checks.py` runs it with the other suites.

## The pieces

| File | What |
| --- | --- |
| `tools/balance/bot.gd` | the player: the kit, the mine, a fight, and what it writes down about each |
| `tools/balance/delve.gd` | a worker: plays the jobs in a file, one line a run |
| `tools/balance/delve.mjs` | deals the jobs to every core, keeps the runs, calibrates the kits |
| `tools/balance/analyze.mjs` | the runs into a summary, what stands out, the report as text |
| `tools/balance/page.mjs` | the report as a page |
