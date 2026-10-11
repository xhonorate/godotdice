# The Altar and the Transcendent gems

A rare chamber where a player gives up five gems for one better one, and the only place a **Transcendent** gem can come from. Designed and approved on the review page https://claude.ai/artifact/RUrLPLRdFtSK3u5KHBb4Tv (two rounds), built October 10, 2026.

Nothing in the game explains the recipes. The circle lights for a set it knows and stays cold for anything else.

## The room

| | |
| --- | --- |
| **Where** | Chamber kind `altar`, map weight 2 in every mine (about one stretch in eight). Never in a mine's first stretch, never two in one stretch (`DeepDescent._chart`). Its mouth glints "strange". |
| **What goes on it** | Appraised gems from the bag or the rail. Never a raw stone, a Birthstone, a temporary stone, a gem that can't leave its socket, or a Transcendent (`DeepAltar.refusal`). |
| **Vault copies** | A gem the rail brought from the Vault can be offered, and the Vault loses that stone for good. The run records it in `vault_spent`, and `DeepProfile.apply_result` removes it. |
| **Flow** | The five sockets are the screen's own until the crystal is pressed (`descent_screen._altar_slots`). The `altar` command takes five stone ids; `altar_leave` walks on. Each player makes one thing at most. The room closes only when everyone has walked on, so the ritual is never cut short. |
| **Party** | Everyone has their own circle. Everyone sees the circle take the five, and a Transcendent's reveal is shown to the whole party. |

## What the circle makes

Tried in order; the first rule that fits wins (`DeepAltar.recipe_for`).

1. **A Transcendent's own recipe**: five different skills from its `altar.from` list.
2. **Five gems of one of the six colors**, repeats allowed: that color's Seam.
3. **Five gems of five different colors**, Opal counting as one: a random ordinary opal. Never a Transcendent.

A gem's color here is its skill's own; a Zoning inclusion doesn't change it.

| Transcendent | Made from | Cut | What it does |
| --- | --- | --- | --- |
| Rainbow Seam | any five different Seams | cabochon | Every gem that has already fired this turn fires again. |
| Procession | Barrage, Aegis, Renewal, Dread, Gilded Armor, Lodestone, Crescendo (any five) | kite | By the top of the straight: damage, Block, healing, Poison and Pyrite, each a share of it. Flawless: all to every enemy and ally. |
| Black Opal | Pinfire, Doublet, Matrix, Echo, Prelude (Pinfire took Fire Opal's place in October 2026) | cabochon | At the start of each fight absorbs a random read gem from the bag (destroyed); when it fires, every absorbed skill fires too, if the dice suit it. Reset when the run ends. Flawless absorbs two. |
| Quintessence | Crush, Sap, Bastion, Shatter, Jackpot | pentagon | On five of a kind: 5 damage, 5 Block, 5 healing, 5 Pyrite, then +5 carats to itself for the fight. Flawless: +5 to every other gem too. |
| Gemini | Cleave, Guard, Venom, Tithe, Cascade | hourglass | For each pair in the hand (four or five alike and a full house are two; phantom dice count), the gems either side fire. Never an opal. Flawless: once more. |
| Certainty | Strike, Riposte, Siphon, Miasma, Prism | keystone | Every gem after it fires this turn whatever the dice show (opals still need Resonance). Flawless: twice. |

To make the recipes span five colors, two pairs of existing gems traded triggers: Bastion ↔ Lifeline (three of a kind / full house) and Mortar ↔ Miasma (even dice / any hand). Miasma now counts the even dice among the 1–5 highest it reads, by Cut, so its Cut still matters; at Perfect it plays exactly as before.

## The new gem

Carat, Cut and Clarity are each the average of the five, raised by a random 20–30% (`altar_raise_pct`) and nudged: Carat by up to 1 (`altar_carat_nudge`), Cut and Clarity a grade either way 17% of the time (`altar_nudge_pct`). Cut and Clarity are averaged as grades counted from one. Inclusion slots are filled from what the five carried first, skipping a Zoning of a color the new gem already is, then from the rock.

## Keeping Transcendents secret

Rarity `TRANSCENDENT`, roll weight 0, value 16. No pool holds one (`DeepForge.skill_pool`, `opal_pool`), so no vein, hoard, well, merchant, commission or random opal can produce one. The Vault doesn't list or count a Transcendent until the player has made one (`DeepProfile.knows`, `profile.transcended`); then it gets a Transcendent filter and sits after every color.

## Calls made while building, worth revisiting

- **Exact counts.** Gemini's fires, Certainty's forcing, Black Opal's absorbed skills and Quintessence's +5 carats don't scale with carat, as specified. The test that every effect answers to weight exempts these four (`tests/test_stones.gd`). Carat still scales everything else the gems do.
- **Certainty's Cut does nothing**, by design ("any hand", "every gem after it"). The test that every Cut step differs exempts it.
- **Black Opal's absorbed skills** need their own trigger met, reading the hand at the Black Opal's own carat, cut and clarity.
- **The two unspecified Flawless lines** (Black Opal: absorbs two; Quintessence: +5 carats to every other gem) were chosen during the build.

## Where it lives

`sim/altar.gd` (recipes and rolls), `sim/descent.gd` (the room, Black Opal's absorbing), `sim/battle.gd` (the new effects), `view/battle/altar.gd` (the 3D altar and the ritual), `view/run/descent_screen.gd` (`_show_altar`), `view/gems/motes.gd` (the ring every Transcendent carries), `tests/test_altar.gd`. The balance browser's JS sim mirrors the battle side (`tools/data-browser/js/sim`).
