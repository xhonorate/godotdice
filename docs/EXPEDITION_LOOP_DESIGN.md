# RogueDice: the expedition loop

Design revision: September 14, 2026. This replaces the fixed-length run profiles (`short_9`, `expedition_18`), the room-offer route screen, and the start menu. Combat rules, gems, dice, enemies, the host-authoritative command boundary, and saves stay as they are.

Items marked **⚑ default** were not specified by the design brief. They are proposals to confirm or change.

## 1. The loop in one paragraph

The player owns a jewelry shop. From the shop they pick an unlocked mine on a map, set out alone or with up to three friends, and dig down through a lantern-lit cross-section of the mine. The deeper they go, the harder the enemies and the richer the rocks. A tremor meter fills as they dig, faster when deeper. When it is full, the mine's boss breaks through wherever the party is. The run ends when the party rides a lift to the surface, is wiped out, or kills the boss. Back at the shop, every gem they found is laid out on a table, appraised, and kept or sold for gold. Gold buys gems at the shop. Killing a mine's boss unlocks the neighbouring mines on the map.

## 2. Two kinds of state

| | Lives in | Survives a run? |
|---|---|---|
| **Profile** | Each player's own machine, `user://profile.json` | Yes |
| **Expedition** | The host's `RunEngine` state and checkpoint | No. New seed and fresh mine every time |

Only gems and gold cross from an expedition into a profile, and only through the return screen.

| Thing | Scope |
|---|---|
| Gold | Profile. Earned by selling gems at the return and from commissions |
| Ore | Expedition. Found in rocks and battles, spent on in-mine services, discarded at the end |
| Collection gems | Profile. At most one gem per skill key |
| Loadout gems | Profile. Up to 6 gems from the collection per hero, Strike required. Never at risk |
| Found gems (the haul) | Expedition until the return screen, where they are kept or sold |
| Relics, die changes, HP | Expedition only **⚑ default** |
| Unlocked heroes, mines, seen gems, commissions | Profile |

In multiplayer, each player brings their own profile's loadout into the host's run and receives their own haul back. Co-op play trusts each client's profile; there is no anti-cheat **⚑ default**.

## 3. Profile

```
schema_version, profile_id, gold
collection:    {SKILL_KEY: {key, carat, cut, clarity}}
seen_gems:     [SKILL_KEY]              # identity revealed at least once
heroes:        {HERO_KEY: {unlocked, loadout: [SKILL_KEY, ...]}}
mines:         {MINE_ID: {unlocked, boss_defeated, deepest, expeditions}}
encountered:   {enemies: [KEY], bosses: [KEY]}
shop:          {date, stock: [{id, gem, price, sold}], refreshes_today}
commissions:   {board: [...], special: [...], claimed: [...]}
lifetime:      {runs, extractions, deaths, bosses, gold_earned, ...}
```

- **Starting profile:** 0 gold, all three current heroes unlocked **⚑ default**, the Quarry unlocked. The collection holds every hero's starting gems at their best starting ranks: Strike C2, Block, Precision, Sunder, Arc Burst. Each hero's loadout is its catalog starting set.
- **Gem states in the collection grid:** *unseen* (black silhouette, no name), *seen* (greyed, named, not owned), *owned* (the saved version with its ranks). A gem becomes seen when it is appraised: mid-run, at the return, or through a commission reward.
- **One copy per skill:** keeping a found gem you already own sells the old version automatically. The appraisal view shows both side by side first.
- **Writes** use the same temp-file, atomic-replace, and `.bak` pattern as `SaveStore`. Every profile change is one transaction.

## 4. The shop (hub)

The main menu is an illustrated shop interior. Every menu entry is an object you click. It highlights on hover and has a keyboard/controller focus order.

| Object | Opens |
|---|---|
| Overflowing jewel bag | Collection grid: sort by colour, rarity, name, owned; filter by state |
| Shopkeeper at the counter | Daily gem shop |
| Commission board (pinned notes) | Commissions and special missions |
| Armor stand | Heroes: pick the hero, edit that hero's loadout |
| Framed wall map | Mine atlas: preview mines; the host picks the destination |
| Mine cart at the cellar hatch | **Set out** (solo or host once everyone is ready) / **Ready** (guests) |
| "Open" sign on the door | Party: host, invite (Steam), join (LAN/Steam), member list |
| Ledger on the counter | Journal |
| Wall clock | Settings **⚑ default** |

### 4.1 Daily shop

- Stock: 6 gems **⚑ default**, drawn only from seen skill keys, never a key the player already owns at equal or better value **⚑ default**. Ranks roll from the difficulty of the deepest mine the player has unlocked.
- Stock is generated from `hash(profile_id, local date)`. It refreshes at local midnight, determined by the system clock.
- Refresh now: `1000 × (refreshes_today + 1)` gold. The counter resets with the daily stock.
- Buy price `30 × gem_value`. Sell value at the return `10 × gem_value` **⚑ default**. `gem_value` is the existing `rarity × (C + 2(K−1) + 2(L−1))`, so gems sell for 10–1,600 g and buy for 30–4,800 g. These are tuning constants, not balance claims.

### 4.2 Commissions

- Three standing notes. A claimed note is replaced by a new one from the templates **⚑ default**:
  - Return with a *Colour* gem of Carat ≥ N.
  - Return with a *Rarity*-or-better gem.
  - Return with a Cut or Clarity 5 gem.
  - Reach depth N in *Mine*.
  - Defeat *Boss*.
- A delivery note is satisfied by the haul at the return; the gem is **not** consumed **⚑ default**. The reward is claimed at the board: gold, a specific appraised gem, or a special mission.
- **Special missions** appear at random (about one every two days, lasting 24 hours **⚑ default**). Each names a mine variant (a modifier such as "double tremor rate", "no camps", or "elites everywhere"), a goal (defeat the boss / recover a named artifact gem), and a larger reward. Its mine appears on the atlas as a marked node while it is active.

### 4.3 Heroes and loadouts

The armor stand shows the selected hero's sprite, HP, dice, and trait, with six gem sockets. Clicking a socket opens the collection grid filtered to owned gems. Strike cannot be removed. Two heroes may use the same collection gem, because one player only controls one hero per expedition. Locked heroes appear as silhouettes on the stand's hero picker; commissions can unlock future heroes.

## 5. Mine atlas

A web of mines. The Quarry sits in the centre; lines connect each mine to its neighbours.

| Mine | Boss | Difficulty | Unlocks | Enemy pool | Character |
|---|---|---:|---|---|---|
| The Quarry | Slime King | 1 | Mirror Grotto, Rift Hollow | Slime, Stone Crab, Gem Cultist · elite Iron Warden, Red Slime | Plenty of camps and lifts |
| Mirror Grotto | Mirror Regent | 2 | (future) | Mirror Wisp, Dartling, Gem Cultist · elite Iron Warden | More events and Lapidaries, White/Blue-leaning gems |
| Rift Hollow | Rift Sovereign | 3 | (future) | Rift Hound, Mirror Wisp, Dartling · elite Iron Warden ×2 | Sparse lifts, fast tremors, Red/Violet-leaning gems |

- States: unlocked (lit, selectable), revealed but locked (silhouette, name hidden), and hidden. A mine is revealed when a neighbour is unlocked, and unlocked when a neighbour's boss is defeated by any member of that party.
- The preview panel shows the boss portrait, difficulty pips, room tendencies, and the gem pool as icons. Bosses and gems the player has not encountered or seen are greyed silhouettes.
- In a lobby, the host's selection shows on every member's atlas and beside the cart. A guest who has not unlocked that mine can still go; clearing it unlocks it for them too **⚑ default**.
- Mines are content: a new `mines` section in the content pack and the content studio, replacing `profiles`.

```
MINE: id, name, atlas_position, links: [MINE_ID], difficulty, boss_id,
      palette, quality_bonus, tremor_rate, lift_rate,
      room_weights: {kind: weight}, enemy_pools: [{from_depth, normal: [...], elite: [...]}],
      skill_ids: [...], color_weights: {COLOR: weight}
```

## 6. The expedition

### 6.1 The seam

- A side-view cross-section. **Depth** is the layer number, starting at 1. There is no bottom.
- Each layer has 3–5 nodes across 7 columns. Each node links to 1–3 nodes on the next layer within one column of it, so tunnels branch and merge. The party is always on exactly one node and moves only downward.
- Layers are generated from `hash(run seed, mine_id, depth)`, so any layer is identical regardless of when it is generated. The engine keeps generated layers up to `depth + 8` and saves them in the checkpoint.
- **Lantern:** nodes 1–2 layers ahead show their exact room. Nodes 3–8 ahead show only a silhouette class: *hostile* (glowing eyes), *service* (lit window), *treasure* (glint), *unknown* (dark). **Lift beacons are visible across the whole generated window.** Miner's Lantern adds one layer of exact sight.
- The party votes on the next node with the existing vote rule (host breaks ties).

### 6.2 Rooms

| Node | What happens | Change from today |
|---|---|---|
| Battle | Encounter from the mine pool at this depth. Ore, chance of an unappraised gem | Gem choice replaced by drops |
| Elite | Tougher encounter. More ore, a relic choice, 1–2 unappraised gems at +1 quality | Relic kept |
| Rock vein | The existing automatic mining. Rocks yield ore and unappraised gems. Gem-rich rock odds rise with depth | Gold → ore; the shared draft stays, now picking unappraised stones by eye |
| Camp | Heal a third. Free equipment changes | Unchanged |
| Lift | Vote: ride up (end the run, extracted) or keep digging | New |
| Treasure | An appraised gem or a relic, usable immediately | New |
| Merchant | Buy appraised gems, dice, relics, and Loupes with ore | Gold → ore |
| Lapidary | Cut/Clarity upgrade **or** appraise gems, paid in ore | Appraisal added |
| Crucible, Workshop, Wager Hall | As today, paid in ore | Gold → ore |
| Event (?) | One of the events, or a disguised room of another kind | Rewards in ore |

- In-mine upgrades to a **loadout** gem last only for this expedition. Upgrades to a **found** gem stay on it when it comes home **⚑ default**. This keeps ore from buying permanent power for gems that were never at risk.
- **Depth scaling** replaces act tiers: enemy HP × `1 + 0.06·(depth−1)`, attack damage + `floor(depth/4)`, block and heals × `1 + 0.03·(depth−1)`. Gem quality is `mine.quality_bonus + depth/2` plus a source bonus (merchant +2, treasure +3, elite +4, boss chest +10). All of these are constants to tune.
- **Known tuning problem:** a layer holds three to five chambers, so a party can usually find a tunnel that avoids a fight. The smoke bot reached depth 9 of Mirror Grotto without one. Candidates: guard deep service rooms with a fight, raise battle weights further, or make some tunnels hostile.

### 6.3 Unappraised gems

- A found gem arrives with `appraised: false` and goes into the hero's **haul**, not their gem list. It cannot be equipped.
- The haul shows the real 3D stone: its cut outline and hue (Color), size (Carat), faceting (Cut), and transparency and inclusions (Clarity). The **skill emblem, name, and exact ranks are hidden**, so a player can guess from how the stone looks **⚑ default**.
- Ways to appraise mid-run: Lapidary service, a Loupe consumable (treasure, merchant, events), and some events. An appraised found gem can be equipped immediately. Treasure gems arrive appraised.
- The host knows every value, and UI hides them on every client. Snapshot redaction for guests can come later.

### 6.4 The tremor meter

- 0–100. Each move adds `base + depth × rate` using the mine's `tremor_rate`. Elites add a little extra; some events calm it.
- Warnings at 50, 75, and 90. When it reaches 100, the next node the party enters becomes the boss lair, whatever it was going to be.
- The boss scales with depth on the same curve as other enemies, capped at `+60%` HP **⚑ default**.

### 6.5 Endings

| Ending | Happens when | Result |
|---|---|---|
| **Extracted** | The party rides a lift | Everyone's haul comes home |
| **Fallen** | Every hero is down | Salvage roll per haul gem, then home |
| **Conquered** | The boss dies | Boss chest (choose one of three appraised gems from the boss pool at high quality **⚑ default**), mine unlocks, then home |

**Salvage:** each gem in a fallen hero's haul is rolled on a die by its rarity: Common d6, Uncommon d8, Rare d12, Legendary d20. Only the maximum face keeps the gem; otherwise it shatters. The engine rolls from the loot stream when the salvage phase starts. The player clicks each die to reveal the result, which is presentation only. Found gems equipped mid-run count as haul. Loadout gems are never rolled.

If some heroes are down when the party extracts or wins, those heroes keep their haul. Only a party wipe triggers salvage.

### 6.6 Statistics

Statistics are tracked per hero in addition to party totals: damage dealt, block gained, healing, final blows, rooms visited, deepest layer, ore earned, gems found, and haul value in gold. The statistics screen shows each player in a column and highlights the leader of every row.

## 7. The return

1. **Table:** a 3D wooden table with each player's gems scattered in their own area. Stones use the existing gem mesh and show their emblem once appraised. Every gem is revealed here.
2. **Appraisal:** clicking a gem moves it toward the camera and turns it slowly. The right panel shows its name, rule chain, ranks, rarity, and sell value. If the player owns that skill, the owned version appears beside it with each better or worse rank marked.
3. **Keep or sell** for each gem. Keeping a duplicate sells the older version for its value. Unresolved gems are sold at the end **⚑ default**.
4. **Statistics** for the whole party.
5. **Back to the shop.** In a lobby, everyone returns to the same lobby with ready flags cleared.

Keep/sell decisions are profile transactions on each player's own machine. Guests see other players' tables read-only.

## 8. Lobby and networking

- The hub is the lobby. `Session.lobby` gains `mine_id` (host-set) and per-member `hero_id`, `loadout` (gem instances from the profile), `unlocked_mine_ids`, and `ready`.
- Every member can use the bag, shop, board, and armor stand while in the lobby. Changing hero or loadout clears that member's ready flag.
- The cart shows each member's ready state. Only the host's cart can start the expedition, and only when everyone is ready.
- `RunEngine.new_run` receives `mine_id` and seats that carry loadouts. At the end, the host sends each client a result record containing the ending, that player's haul (post-salvage), boss unlocks, encountered enemies, and statistics. Each client applies it to its own profile, with the record ID recorded so a resend never pays out twice.

## 9. What is removed

- `short_9`, `expedition_18`, acts, the room counter and fixed milestones, `_route_offers`, the route card screen, profile and seed pickers on the start menu, and the gold-per-battle reward table.
- Content studio `profiles` becomes `mines`.
- Tests built around the nine- and eighteen-room campaigns are rewritten against expeditions.

A seed field stays available behind a developer toggle for reproducing runs.

## 10. Art

All art is generated as editable starting points. Hub art is authored as SVG so it scales to any resolution and can be hand-edited or replaced by PNGs with the same keys.

| Set | Pieces |
|---|---|
| Hub | Background room, counter, shopkeeper, jewel bag, commission board, armor stand, wall map frame, mine cart and hatch, door sign, ledger, clock. Hover outline shader |
| Atlas | Parchment map, mine node icons for 3 mines, lit/locked/silhouette states, connecting paths |
| Seam | Rock strata background per mine palette, tunnel strokes, silhouette-class icons, lift beacon, party marker, tremor meter |
| Rooms | New `lift`, `treasure` icons; `mine` repurposed as rock vein |
| Return | Table surface material, appraisal backdrop, salvage dice (existing polyhedra), shatter effect |
| Items | Loupe, ore icon |

## 11. Build order

Each phase ends with passing checks and something playable. Status as of September 14, 2026: phases 1 and 2 are done, and phase 3 is partly done (seam map, tremor meter, lift, salvage and unappraised stones are in; an interim appraisal list stands in for the phase 4 table).

| Phase | Deliverable | Rough size |
|---|---|---|
| 1 | Profile rules and store, mines in the content pack and validator, studio `mines` editor | ~1 day |
| 2 | Expedition engine: seam generation, lantern, lifts, tremor, depth scaling, ore, haul, appraisal, treasure, salvage, boss chest, per-hero stats, result records. Old profiles removed; run tests rewritten | ~3 days |
| 3 | Expedition UI: seam map, tremor meter, haul bag with unappraised stones, salvage screen | ~2 days |
| 4 | Return: 3D table, appraisal view with comparison, keep/sell, statistics screen | ~2 days |
| 5 | Hub: scene art and hotspots, collection grid, armor stand, daily shop, commission board, mine atlas | ~3 days |
| 6 | Lobby in the hub: host mine choice, ready states, loadouts into the run, results back to each profile | ~1–2 days |

Phases 1–4 can be played from a temporary plain menu before the hub exists.
