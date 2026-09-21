# The Descent in 3D: proposal

September 21, 2026. The owner asked (Todo.md) whether the run could stay in the first-person 3D scene the whole way down instead of showing a 2D map beside 2D pages between fights: walk from room to room, choose a way at a crossroads of real tunnels, be sealed into a fight by a rockfall that crumbles when it is won, watch spoils fall from the creatures and fly into the bag, mine a vein in 3D, and use the fight HUD's rail and tray as the bench and the shop counter.

**Verdict: yes, and it is view work.** Nothing here needs a rule to change. The run state machine in `sim/descent.gd` already knows everything the 3D scene needs (which chamber the party stands in, the ways on from it, who has voted, what a fight paid) and the events the host streams are enough to drive every animation. The one place a rule *could* change (which creature dropped which stone) is better faked in the view, see §6. Questions for the owner are numbered in §14.

## 0. Two measurements

Both from a throwaway headless script on this machine (Godot 4.7.2, CPU only: mesh arrays, nodes, lights; the GPU upload and shader compile happen at first render and are already paid by `warm_up`).

| Room | CPU build time, three trials | Nodes | Triangles |
|---|---|---|---|
| Fight rooms, every band | 17 to 24 ms | 25 to 46 | 6.6k to 8.0k |
| Warden halls, every band | 21 to 32 ms | 53 to 72 | 7.0k to 8.3k |

So a room is one to two frames of work if built in one go. A walk of three seconds is 180 frames, so the next room is built in slices during the walk (or before it, during the crumble) and never stalls (§2.5).

| The lattice, 2,400 charted stretches | |
|---|---|
| Ways on from a chamber inside a stretch | always **2** (55.6% of nodes) |
| Ways on from the last row before a landing | always **1**, the landing (44.4%) |
| Ways down from a landing | always **2** |

With `landing_every` 4 and rows two, three and four wide, a crossroads is always a fork of two, and the approach to a landing is one tunnel. If `landing_every` ever became 5 a three-way fork would appear once a stretch, so the far wall should be built to carry one to three mouths, but the art can be designed around the fork.

## 1. What the run looks like today, and what moves

Today `view/run/descent_screen.gd` is a strip (mine, depth, party, ore, bag, bench, gear) over a body that holds a 2D faceted cave (`backdrop.gd`), the lantern map down the left (`shaft_map.gd`), a page holder for tunnels, vein, oddity, merchant, landing, hoard, salvage and the run's end, and a black curtain that lifts between them. The battle screen is shown only during a fight and owns the whole 3D stage: its own `SubViewport` and `World3D`, the camera rig, the effects node and the chamber. The rules move on the instant a chamber is done; the screen *holds* the page that shows what came of it until the player clicks Onward.

Proposed layering:

```
DescentScreen
  MineStage            the one World3D for the whole run: viewport, camera rig, BattleFx,
                       the Environment, the room the party is in, the tunnel it is walking,
                       the room it is walking to; beats: arrive → business → done → crossroads → walk
  BattleScreen         the fight HUD and choreographer only: dock (rail, tray, forecast),
                       plates, ally cards, banners, target pick; it animates events on the stage
  Room overlays        HUD cards over the room for what is text by nature: respite, oddity
                       choices, stakes, the hoard's lines, salvage, the summary
  Strip, toasts, inspector, menu, chart fold-out (optional, §3.4)
```

The stage is hoisted out of `battle_screen.gd` into `view/run/mine_stage.gd` and is on screen for the whole run. The 2D backdrop and the full-screen pages for tunnels, spoils, vein, merchant and oddity results are retired; their 2D classes (`TunnelCard`, `TunnelMouth`, `VeinSpot`, `VeinFace`, `RewardSlot`) go with them. The hold mechanism stays as the stage's "done" beat: the room keeps showing what came of it until the party walks on.

## 2. Rooms, portals and tunnels

### 2.1 The room today

`chamber.gd` builds a half-tube vault from z = 9 to z = −30 (12.5 wide, 8 high, bulging around the arena), closed by a far wall, over a 44 × 38 floor; props keep out of the arena and the line of sight; the party's lantern is a shadowing spotlight fixed at (1.2, 4.6, 6.0); rim lights stand behind the arc. The camera lives at (0, 2.1, 5.2) looking down −z. Everything in `battle_screen.gd` assumes these coordinates.

### 2.2 Portals

Every room gains **portals**: an entrance behind the camera, cut into the near end of the vault at z ≈ 9, and one to three exits cut into the far wall at z ≈ −30, spaced across it (one centred; two at ±3.5; three at 0 and ±4.5). A portal is a fixed profile, a ring of 14 vertices about 2.8 wide and 3.4 high with a round head, welded into the shell's own ring so the rock flows into it without a seam. Because every portal in the mine has the same profile, any tunnel fits any room.

The number of exits is known when the room is built: `map.nodes[at].next.size()` for a chamber, 2 for a landing, 1 for the last row (the landing's tunnel). Mouths are dark holes until they are lit by what waits (§3).

### 2.3 Tunnels

A tunnel is one swept low-poly tube along a spline from room A's exit portal to room B's entrance portal: 30 to 40 metres, an S-bend of a few metres sideways and a drop of two to three metres, so B's interior is never in view from A and A's is gone a few steps in. **Visible depth is one room**: from anywhere in a room or a tunnel at most one room's interior is in view. Rings along the spline are displaced by the same noise the shell uses; the floor is rubble with the party's footing kept flat; a few props from the biomes' own sets lean in (timber in the galleries, drips in the seeps).

### 2.4 Seamless style changes

Biome bands change every four depths, which is exactly the landing cadence (galleries 1 to 4, seeps 5 to 8, crystal 9 to 12, and so on), so almost every tunnel joins two rooms of the same band and only the tunnels *out of a landing* cross a band. Inside a band, depth already darkens and thickens the room. The blend is done four ways, and none of them needs a new asset:

| What | How it blends along the tunnel |
|---|---|
| Rock | vertex colours lerp from A's rock, rock_dark and floor to B's along the tunnel's length (`Lowpoly.tri` already writes a colour per triangle) |
| Props | A's set for the first half, B's for the second, sparse |
| Lights | A's lantern colours near the start, B's near the end; the rim lights of A dim as the camera passes the midpoint and B's rise |
| Air | the camera's `Environment` is tweened over the walk: background, fog colour, ambient colour and energy, volumetric density and albedo, glow, saturation and contrast (`Biomes.for_depth` already resolves both ends). A's particles stop emitting when the walk begins and B's start at the midpoint. Ground mist is a room thing; tunnels have none |

The party's lantern (the shadowing key light) becomes a child of the camera rig, so it walks with the party and swings a little; on arrival it settles onto the room's mark, where it already sits today.

### 2.5 Coordinates, build cost and memory

- **Rebase, not floating coordinates.** Room B is built 40 metres further along and lower; the camera walks to it; on arrival room A is freed and B, the tunnel stub and the camera are translated in the same frame so B sits at the origin. Nobody sees the teleport, and every coordinate in `battle_screen.gd`, `chamber.gd` and `battle_fx.gd` stays exactly as it is. Ambient `GPUParticles3D` are set to local coordinates so they move with their room instead of streaking.
- **Build in slices.** Floor one frame, shell the next, props over the next few, lights last; the measured 17 to 32 ms spreads over a dozen frames. B is started as soon as the way is known (the crumble and the spoils' flight cover it) and is always finished before the camera is in the tunnel. A worker thread for the `SurfaceTool` arrays is the fallback if slices are not enough; nodes stay on the main thread.
- **Two rooms and one tunnel alive at most.** A's optional lights switch off once the camera is in the tunnel, so the light count never doubles for long. The quality governor keeps working as it does now.

## 3. The crossroads

### 3.1 Where the fork is

Two placements were considered:

| | Shape | For | Against |
|---|---|---|---|
| **A. The far wall is the crossroads** (recommended) | the room's exits are its mouths; when the room's business is done they light up and the party picks one | one walk per depth; the rockfall seals the very mouths the party will leave by, so the crumble *is* the reveal of the way on; nothing extra to build | the choice is made from the middle of the room, twenty metres from the mouths |
| B. A fork cavern after every room | one exit, a short walk to a small cave with two mouths | the walk into the cave sells "further in"; the decision has its own place | a second room to build every depth, and two walks; two to three minutes more per run |

A is proposed. The camera leans toward a hovered mouth (the rig's `focus`) so the choice still feels looked at.

### 3.2 What a mouth shows

| Mouth | Look |
|---|---|
| Revealed chamber (inside the lantern's two-depth reach, or lit) | light of the chamber's colour spilling out of the tunnel (`DeepUi.CHAMBER_COLOURS`), motes drifting out, the chamber's glyph carved on a plaque above the arch and lit from below (the same pictograph the cards use) |
| A dark mouth (`hidden`) | no light; two small glints blinking out of step deep inside, as the 2D mouth draws today |
| The landing | warm lamp light and the sound of the cable; the plaque is the lift |
| A Warden's landing | the same with a red rim on the arch and heavier dust |

Hovering a mouth shows a HUD chip row above it with what the lantern knows of the way beyond ("then: Depth 7, a vein · past the lantern, something hostile"), which is the "then" line the tunnel cards show now. Clicking a mouth is the vote. In solo that is the walk; in a party the mouth shows every voter as a small lantern in their seat colour hung inside the arch (the colours `shaft_map.gd` uses), with the party's names on the chip row. When the vote resolves, every screen walks.

### 3.3 The merchant's exit and the vein's last strike

The rules ask for `leave` before a stall's tunnels open and settle a vein on the last strike. Neither needs a change: clicking a mouth at a stall sends `leave` and remembers the mouth to vote for when the offers arrive; after a vein's last strike the stage holds the room until the finds have flown, then lights the mouths.

### 3.4 The lantern chart and lighting the way

The 2D map is what is being removed, but two of its jobs need a home: seeing the charted stretch, and paying ore to light it. Proposed: `shaft_map.gd` survives as a **fold-out chart** (a key, and a small compass pill in the strip), drawn over the room when asked and otherwise hidden, with the Light the way button on it; a lit stretch turns every dark mouth's plaque on. The alternative is to drop the chart entirely and rely on plaques and hover chips, which loses the view of the whole stretch and the trail behind. Question 2.

## 4. Walking

- The camera rig gains `travel(path, seconds)`: a dolly along the tunnel spline at eye height with a small head bob (two to three centimetres, scaled by the existing shake slider), the lantern swinging on the rig, footsteps in the sound bank (there is none yet; "tunnel", "depth_card" and "rock_break" exist), dust in the beam. About three seconds a walk; a click or Space hurries it to double speed.
- **Fewer flashes** (the reduced-motion setting) turns a walk into a cross-fade: the room darkens, the next one fades in at the camera's home. No dolly, no bob.
- The depth card ("Depth 7 · A vein · The Seeps") stays, drawn as a HUD title over the last third of the walk instead of a black card.
- The walk is local. It starts on the `vote` event that carries `entered` (or the `landing` event); the state has already moved and the stage holds the old room until the walk ends, exactly as the held pages do now. Fights only resolve once everyone has locked, so a slow walker delays nobody's turn; a fast ally may lock before I arrive, as today.
- Headless, the walk is skipped like every other effect, so `test_screens.gd` keeps driving the run through the same code.

Time added to a run: about three seconds a depth for the walk, four for a rockfall and its crumble, two for the spoils' flight; over twenty-four depths with about eleven fights that is two to three minutes, less with hurrying. Question 3.

## 5. Fights: the rockfall and the crumble

On arrival at a fight, elite or Warden room, in order:

1. The camera settles. A rumble: trauma on the rig, `Chamber.surge`, `BattleFx.dust_fall`.
2. **The rockfall.** A `Rockfall` node fills each exit portal with twenty to forty `Lowpoly.rock` boulders tweened down from the vault into a pile, with dust puffs and shards at each landing; the mouths' lights go out. It stands at z ≈ −28 to −30, behind the arc, so it is seen over and around the creatures. A second, unseen fall behind the camera is sound and dust only (question 5).
3. The creatures rise (the existing `spawn`), the Turn 1 banner, and the fight as it is now.
4. **The crumble**, on victory after the banner: the boulders tumble apart, shrink and sink through the floor in a cloud, the mouths' lights come back in the colours of what waits, the way is open. A Warden's gate uses the same fall with pillars either side (the hall already has pillars and braziers).
5. On defeat there is no crumble; the camera drops and rolls as it does now.

## 6. Spoils in 3D

**What the rules pay.** A fight settles per player when `battle_over` arrives: ore (six, plus the depth, plus any gold the rail made; doubled for an elite, tripled for a Warden), a raw stone 55% of the time from a fight and always from an elite, a die 35% of the time from an elite, and a Birthstone's own drops. Nothing is tied to a particular creature, and nothing is known until the settle.

**Proposal, view only.** As each creature dies it sheds three or four **spoil chunks**, ore nuggets in the ore colour and one glinting rough that could be a stone, which arc to the floor (a tween with a bounce, the `coins` effect already does the arc) and lie there catching the lantern. When the settle arrives the pile resolves: the nuggets count up into the ore won; if a stone was won the rough cracks open into the real raw stone, a `GemMesh` of the actual find, so its colour and size are read off the rock before the plaque names it; a die lands as a real die mesh. Then everything flies to the strip: ore to the ore pill, stones and dice to the bag pill, which swell and count as they do today (`_celebrate`). A single HUD line under the strip says it in words ("+14 ore · a raw Red stone") for the record. The 2D spoils page and its Onward button go; the mouths light up when the last spoil lands. Right-click to look at a stone stays on the bag and the bench.

Each player sees their own spoils fly to their own HUD, since rewards are already per player.

**The alternative**, deciding drops per creature in the rules so that a Magpie really carries the stone, was considered and set aside: it touches `sim/descent.gd`, the tests and the patch traffic for a difference nobody can tell from the fake. Question 4.

## 7. Veins in 3D

The vein's six spots become six nodules on a rock face at the far wall, three by two, each with its own sparkle: nine bright sparks for a bright spot, five for a glint, two dull ones, as the 2D face draws them. Clicking one strikes it: a punch on the camera, `sparks` and `shards` at the spot, the pick's sound, the nodule splits and what it held pops out, a raw stone as a `GemMesh`, ore as nuggets, a die as a die mesh, and flies to the bag. A struck spot is a hole with its finder's seat colour lit inside it. Strikes left and the legend live in a HUD strip under the top bar; the vug variant shakes the room and reddens the vignette on every blow. Picking uses the same screen-space nearest-point test the creatures use, applied to the six nodule centres.

## 8. The dock as the bench, and every other room

**The dock outside fights.** The rail and tray stay on screen in every room. When `DeepDescent.bench_open` is true the dock *is* the bench: a **bag drawer** slides up above it holding the haul and the bag dice as tiles; drag a haul stone onto a socket to set it, a set stone into the drawer to take it out, a die onto a slot to swap. `bench_panel.gd` already has this drag and drop (`_wire`, refusals from `socket_refusal`, rings lighting the sockets a dragged stone fits); it moves onto the dock's socket cards and the drawer. During a fight the drawer closes and the sockets refuse drops, as the panel does now. Give (hand a stone to an ally) is a drop on the ally's card.

| Room | In 3D | What stays a HUD card |
|---|---|---|
| **Merchant** | a timber counter with a lantern at the far wall; the three stones and two dice on its shelf as real meshes with price plaques; a pair of scales and a lens. Drag a shelf item to the bag or straight onto a socket to buy; drag a haul stone onto the scales to sell; drop a raw stone under the lens to appraise (the price rises each time, as now). Clicking a mouth leaves | the receipt line |
| **Landing** | the lift hall: a cage in its shaft with the cable running up into a warm light, rails and timber (both props exist), and two mouths down. The cage is the Up target; the mouths are Down. The lift ride is the run's closing shot | the three respite cards; the haul's worth and the party's votes |
| **Oddity** | the oddity's object on a plinth in the room; one generic shrine to start, a prop per oddity later (a wheel, a bath, an idol); found stones fly to the bag | the choice card with its odds and pickers |
| **Hoard** | three pedestals, the real stones turning on them under beams of their grade; click to take, it flies to the bag | the stones' lines |
| **Salvage** | one real die per raw stone tumbles onto the floor; the top face keeps the stone, anything else shatters it | the verdicts |
| **Grubstake** | the shaft head is the lift hall at depth 0 with the workshop's daylight above | the stakes, which are words by nature |
| **The end** | the cage rises into the light (extracted, conquered) or the room goes dark (fallen) | the summary |

## 9. Retired and kept

| Retired | Kept |
|---|---|
| `backdrop.gd`, the 2D cave | `shaft_map.gd`, as a fold-out chart (question 2) |
| the tunnels, spoils, vein, merchant and oddity-result pages and their 2D classes | the strip, toasts, the inspector, the menu |
| the black curtain between rooms | the hold mechanism, as the stage's "done" beat |
| `TunnelMouth`'s faceted rock | `DeepUi.CHAMBER_GLYPHS` and colours, on plaques and in mouths |

## 10. Performance and comfort

- One `World3D` renders for the whole run instead of only during fights. Between fights the room costs what it costs during one, and the governor that drops effects under 40 frames a second keeps working.
- During a walk two rooms and a tunnel are alive; A's optional lights go off once the camera is in the tunnel, and A is freed on arrival.
- Head bob obeys the shake slider; Fewer flashes replaces walks with cross-fades; the field of view never changes during a walk; hurrying is always one click.
- HUD cards over a lit room need a scrim: the dock's raised panel style, already dark, is the model.

## 11. Co-op

Walks, rockfalls, crumbles, spoils and strikes are all local presentations of events the host already streams; nothing new goes on the wire. Votes are shown on the mouths. A guest joining mid-run, or the host reopening a checkpoint, builds the current room directly at the camera's home with no walk.

## 12. Tests and tools

- `test_screens.gd` drives a whole run through the real screens headless; the stage skips its 3D work headless exactly as the battle screen does, so the suite keeps running. New checks: the dock accepts and refuses drops outside and inside a fight; one mouth target per offer; the spoils line matches the settle.
- `tools/screenshot.gd` gains targets for the crossroads, the rockfall, the crumble, the spoils' flight, the 3D vein and the stall, with walks hurried.
- A `tools/tunnel_gallery.gd`, like `biome_gallery.gd`, renders room A, tunnel, room B for every band boundary (4→5, 8→9, 12→13, and so on) so the seams can be looked at side by side.

## 13. Build plan

Each phase ends playable with the suites passing. Sizes assume one person with an AI pair.

| Phase | Deliverable | Rough size |
|---|---|---|
| 1. The stage | `mine_stage.gd` owns viewport, world, camera and effects; the battle screen draws on it; no visible change | 1 day |
| 2. Portals, tunnels, the walk | exits in the far wall, the tunnel sweep, the environment tween, rebasing, sliced building, votes on mouths, the depth title; the old tunnels page retired | 2 to 3 days |
| 3. Rockfall, crumble, spoils | the fall and the crumble, spoil chunks off dying creatures, the resolve and the flight to the strip; the spoils page retired | 1 to 2 days |
| 4. The vein | six nodules, strikes, finds flying; the vein page retired | 1 day |
| 5. The dock as bench, the stall | the bag drawer with the panel's drag and drop; the merchant's counter, scales and lens | 2 days |
| 6. The other rooms | the lift hall and the ride, hoard pedestals, salvage dice, the oddity plinth, the shaft head | 2 to 3 days |
| 7. Finish | footsteps and rock sounds, comfort settings, the chart fold-out, the tunnel gallery, screenshot targets | 1 to 2 days |

Phases 2 and 3 are what the owner asked for first and are worth a look on their own before the rest.

## 14. Questions for the owner

1. **The crossroads:** exits in the far wall of each room (A, recommended) or a fork cavern after every room (B)? §3.1.
2. **The chart:** keep `shaft_map.gd` as a fold-out with the Light the way button on it, or drop it and rely on plaques and hover chips? §3.4.
3. **Walk length:** about three seconds with click-to-hurry, or shorter? Is two to three minutes more per run acceptable? §4.
4. **Spoils:** the view-side fake (recommended) or real per-creature drops in the rules? §6.
5. **The rockfall:** seal the exits ahead only, or also a fall behind the camera as sound and dust? "In front of the player" is read here as the way onward. §5.
6. **The dock outside fights:** always on screen with a bag drawer above it, or slid away until the bench is asked for? §8.
7. **Landings:** the cage as the Up target and the mouths as Down, respites as cards over the hall. Agreed? §8.
8. **Fewer flashes** turns walks into cross-fades. Agreed? §4.
9. **Tunnels slope down** two to three metres a depth so the descent is felt. Agreed? §2.3.
10. **Order of work:** the plan in §13 puts the walk, the crossroads, the rockfall and the spoils first, then the vein, then the stall and bench, then the other rooms. Agreed?
