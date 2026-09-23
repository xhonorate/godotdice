# The Descent in 3D: proposal

September 21, 2026. The owner asked (Todo.md) whether the run could stay in the first-person 3D scene the whole way down instead of showing a 2D map beside 2D pages between fights: walk from room to room, choose a way at a crossroads of real tunnels, be sealed into a fight by a rockfall that crumbles when it is won, watch spoils fall from the creatures and fly into the bag, mine a vein in 3D, and use the fight HUD's rail and tray as the bench and the shop counter.

**Combat follow-up (September 23, 2026):** [Enemy turns: sequential dice and revealed abilities](ENEMY_TURNS.md) records the new moveset display, one-die-at-a-time resolution, party-wide enemy damage, control effects and animation design. The enemy-turn implementation is complete; the completed stages below describe the original descent work.

**Dice follow-up (September 23, 2026):** [Additional dice shapes](DICE_SHAPES.md) extends smithy and enemy tier changes from a d2 coin through d100, with d16 between d12 and d20. It records the solids, playable faces, mesh costs and validation limits.

**Verdict: yes, and it is view work.** Nothing here needs a rule to change. The run state machine in `sim/descent.gd` already knows everything the 3D scene needs (which chamber the party stands in, the ways on from it, who has voted, what a fight paid) and the events the host streams are enough to drive every animation. The one place a rule _could_ change (which creature dropped which stone) is better faked in the view, see §6. The owner's answers to the questions it raised are in §14.

## 0. Two measurements

Both from a throwaway headless script on this machine (Godot 4.7.2, CPU only: mesh arrays, nodes, lights; the GPU upload and shader compile happen at first render and are already paid by `warm_up`).

| Room                     | CPU build time, three trials | Nodes    | Triangles    |
| ------------------------ | ---------------------------- | -------- | ------------ |
| Fight rooms, every band  | 17 to 24 ms                  | 25 to 46 | 6.6k to 8.0k |
| Warden halls, every band | 21 to 32 ms                  | 53 to 72 | 7.0k to 8.3k |

So a room is one to two frames of work if built in one go. A walk of three seconds is 180 frames, so the next room is built in slices during the walk (or before it, during the crumble) and never stalls (§2.5).

| The lattice, 2,400 charted stretches       |                                   |
| ------------------------------------------ | --------------------------------- |
| Ways on from a chamber inside a stretch    | always **2** (55.6% of nodes)     |
| Ways on from the last row before a landing | always **1**, the landing (44.4%) |
| Ways down from a landing                   | always **2**                      |

With `landing_every` 4 and rows two, three and four wide, a crossroads is always a fork of two, and the approach to a landing is one tunnel. If `landing_every` ever became 5 a three-way fork would appear once a stretch, so the far wall should be built to carry one to three mouths, but the art can be designed around the fork.

## 1. What the run looks like today, and what moves

Today `view/run/descent_screen.gd` is a strip (mine, depth, party, ore, bag, bench, gear) over a body that holds a 2D faceted cave (`backdrop.gd`), the lantern map down the left (`shaft_map.gd`), a page holder for tunnels, vein, oddity, merchant, landing, hoard, salvage and the run's end, and a black curtain that lifts between them. The battle screen is shown only during a fight and owns the whole 3D stage: its own `SubViewport` and `World3D`, the camera rig, the effects node and the chamber. The rules move on the instant a chamber is done; the screen _holds_ the page that shows what came of it until the player clicks Onward.

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

Biome bands change every four depths, which is exactly the landing cadence (galleries 1 to 4, seeps 5 to 8, crystal 9 to 12, and so on), so almost every tunnel joins two rooms of the same band and only the tunnels _out of a landing_ cross a band. Inside a band, depth already darkens and thickens the room. The blend is done four ways, and none of them needs a new asset:

| What   | How it blends along the tunnel                                                                                                                                                                                                                                                                                                                     |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rock   | vertex colors lerp from A's rock, rock_dark and floor to B's along the tunnel's length (`Lowpoly.tri` already writes a color per triangle)                                                                                                                                                                                                         |
| Props  | A's set for the first half, B's for the second, sparse                                                                                                                                                                                                                                                                                             |
| Lights | A's lantern colors near the start, B's near the end; the rim lights of A dim as the camera passes the midpoint and B's rise                                                                                                                                                                                                                        |
| Air    | the camera's `Environment` is tweened over the walk: background, fog color, ambient color and energy, volumetric density and albedo, glow, saturation and contrast (`Biomes.for_depth` already resolves both ends). A's particles stop emitting when the walk begins and B's start at the midpoint. Ground mist is a room thing; tunnels have none |

The party's lantern (the shadowing key light) becomes a child of the camera rig, so it walks with the party and swings a little; on arrival it settles onto the room's mark, where it already sits today.

### 2.5 Coordinates, build cost and memory

- **Rebase, not floating coordinates.** Room B is built 40 metres further along and lower; the camera walks to it; on arrival room A is freed and B, the tunnel stub and the camera are translated in the same frame so B sits at the origin. Nobody sees the teleport, and every coordinate in `battle_screen.gd`, `chamber.gd` and `battle_fx.gd` stays exactly as it is. Ambient `GPUParticles3D` are set to local coordinates so they move with their room instead of streaking.
- **Build in slices.** Floor one frame, shell the next, props over the next few, lights last; the measured 17 to 32 ms spreads over a dozen frames. B is started as soon as the way is known (the crumble and the spoils' flight cover it) and is always finished before the camera is in the tunnel. A worker thread for the `SurfaceTool` arrays is the fallback if slices are not enough; nodes stay on the main thread.
- **Two rooms and one tunnel alive at most.** A's optional lights switch off once the camera is in the tunnel, so the light count never doubles for long. The quality governor keeps working as it does now.

## 3. The crossroads

### 3.1 Where the fork is

Two placements were considered:

|                                                     | Shape                                                                                                   | For                                                                                                                                                  | Against                                                                              |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **A. The far wall is the crossroads** (recommended) | the room's exits are its mouths; when the room's business is done they light up and the party picks one | one walk per depth; the rockfall seals the very mouths the party will leave by, so the crumble _is_ the reveal of the way on; nothing extra to build | the choice is made from the middle of the room, twenty metres from the mouths        |
| B. A fork cavern after every room                   | one exit, a short walk to a small cave with two mouths                                                  | the walk into the cave sells "further in"; the decision has its own place                                                                            | a second room to build every depth, and two walks; two to three minutes more per run |

A is proposed. The camera leans toward a hovered mouth (the rig's `focus`) so the choice still feels looked at.

### 3.2 What a mouth shows

| Mouth                                                           | Look                                                                                                                                                                                                                |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Revealed chamber (inside the lantern's two-depth reach, or lit) | light of the chamber's color spilling out of the tunnel (`DeepUi.CHAMBER_colorS`), motes drifting out, the chamber's glyph carved on a plaque above the arch and lit from below (the same pictograph the cards use) |
| A dark mouth (`hidden`)                                         | no light; two small glints blinking out of step deep inside, as the 2D mouth draws today                                                                                                                            |
| The landing                                                     | warm lamp light and the sound of the cable; the plaque is the lift                                                                                                                                                  |
| A Warden's landing                                              | the same with a red rim on the arch and heavier dust                                                                                                                                                                |

Hovering a mouth shows a HUD chip row above it with what the lantern knows of the way beyond ("then: Depth 7, a vein · past the lantern, something hostile"), which is the "then" line the tunnel cards show now. Clicking a mouth is the vote. In solo that is the walk; in a party the mouth shows every voter as a small lantern in their seat color hung inside the arch (the colors `shaft_map.gd` uses), with the party's names on the chip row. When the vote resolves, every screen walks.

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
4. **The crumble**, on victory after the banner: the boulders tumble apart, shrink and sink through the floor in a cloud, the mouths' lights come back in the colors of what waits, the way is open. A Warden's gate uses the same fall with pillars either side (the hall already has pillars and braziers).
5. On defeat there is no crumble; the camera drops and rolls as it does now.

## 6. Spoils in 3D

**What the rules pay.** A fight settles per player when `battle_over` arrives: ore (six, plus the depth, plus any gold the rail made; doubled for an elite, tripled for a Warden), a raw stone 55% of the time from a fight and always from an elite, a die 35% of the time from an elite, and a Birthstone's own drops. Nothing is tied to a particular creature, and nothing is known until the settle.

**Proposal, view only.** As each creature dies it sheds three or four **spoil chunks**, ore nuggets in the ore color and one glinting rough that could be a stone, which arc to the floor (a tween with a bounce, the `coins` effect already does the arc) and lie there catching the lantern. When the settle arrives the pile resolves: the nuggets count up into the ore won; if a stone was won the rough cracks open into the real raw stone, a `GemMesh` of the actual find, so its color and size are read off the rock before the plaque names it; a die lands as a real die mesh. Then everything flies to the strip: ore to the ore pill, stones and dice to the bag pill, which swell and count as they do today (`_celebrate`). A single HUD line under the strip says it in words ("+14 ore · a raw Red stone") for the record. The 2D spoils page and its Onward button go; the mouths light up when the last spoil lands. Right-click to look at a stone stays on the bag and the bench.

Each player sees their own spoils fly to their own HUD, since rewards are already per player.

**The alternative**, deciding drops per creature in the rules so that a Magpie really carries the stone, was considered and set aside: it touches `sim/descent.gd`, the tests and the patch traffic for a difference nobody can tell from the fake. Question 4.

## 7. Veins in 3D

The vein's six spots become six nodules on a rock face at the far wall, three by two, each with its own sparkle: nine bright sparks for a bright spot, five for a glint, two dull ones, as the 2D face draws them. Clicking one strikes it: a punch on the camera, `sparks` and `shards` at the spot, the pick's sound, the nodule splits and what it held pops out, a raw stone as a `GemMesh`, ore as nuggets, a die as a die mesh, and flies to the bag. A struck spot is a hole with its finder's seat color lit inside it. Strikes left and the legend live in a HUD strip under the top bar; the vug variant shakes the room and reddens the vignette on every blow. Picking uses the same screen-space nearest-point test the creatures use, applied to the six nodule centres.

## 8. The dock as the bench, and every other room

**The dock outside fights.** The rail and tray stay on screen in every room. When `DeepDescent.bench_open` is true the dock _is_ the bench: a **bag drawer** slides up above it holding the haul and the bag dice as tiles; drag a haul stone onto a socket to set it, a set stone into the drawer to take it out, a die onto a slot to swap. `bench_panel.gd` already has this drag and drop (`_wire`, refusals from `socket_refusal`, rings lighting the sockets a dragged stone fits); it moves onto the dock's socket cards and the drawer. During a fight the drawer closes and the sockets refuse drops, as the panel does now. Give (hand a stone to an ally) is a drop on the ally's card.

| Room          | In 3D                                                                                                                                                                                                                                                                                                                                                                          | What stays a HUD card                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| **Merchant**  | a timber counter with a lantern at the far wall; the three stones and two dice on its shelf as real meshes with price plaques; a pair of scales and a lens. Drag a shelf item to the bag or straight onto a socket to buy; drag a haul stone onto the scales to sell; drop a raw stone under the lens to appraise (the price rises each time, as now). Clicking a mouth leaves | the receipt line                                                |
| **Landing**   | the lift hall: a cage in its shaft with the cable running up into a warm light, rails and timber (both props exist), and two mouths down. The cage is the Up target; the mouths are Down. The lift ride is the run's closing shot                                                                                                                                              | the three respite cards; the haul's worth and the party's votes |
| **Oddity**    | the oddity's object on a plinth in the room; one generic shrine to start, a prop per oddity later (a wheel, a bath, an idol); found stones fly to the bag                                                                                                                                                                                                                      | the choice card with its odds and pickers                       |
| **Hoard**     | three pedestals, the real stones turning on them under beams of their grade; click to take, it flies to the bag                                                                                                                                                                                                                                                                | the stones' lines                                               |
| **Salvage**   | one real die per raw stone tumbles onto the floor; the top face keeps the stone, anything else shatters it                                                                                                                                                                                                                                                                     | the verdicts                                                    |
| **Grubstake** | the shaft head is the lift hall at depth 0 with the workshop's daylight above                                                                                                                                                                                                                                                                                                  | the stakes, which are words by nature                           |
| **The end**   | the cage rises into the light (extracted, conquered) or the room goes dark (fallen)                                                                                                                                                                                                                                                                                            | the summary                                                     |

## 9. Retired and kept

| Retired                                                                          | Kept                                                         |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `backdrop.gd`, the 2D cave                                                       | `shaft_map.gd`, as a fold-out chart (question 2)             |
| the tunnels, spoils, vein, merchant and oddity-result pages and their 2D classes | the strip, toasts, the inspector, the menu                   |
| the black curtain between rooms                                                  | the hold mechanism, as the stage's "done" beat               |
| `TunnelMouth`'s faceted rock                                                     | `DeepUi.CHAMBER_GLYPHS` and colors, on plaques and in mouths |

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

| Phase                           | Deliverable                                                                                                                                               | Rough size  |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 1. The stage                    | `mine_stage.gd` owns viewport, world, camera and effects; the battle screen draws on it; no visible change                                                | 1 day       |
| 2. Portals, tunnels, the walk   | exits in the far wall, the tunnel sweep, the environment tween, rebasing, sliced building, votes on mouths, the depth title; the old tunnels page retired | 2 to 3 days |
| 3. Rockfall, crumble, spoils    | the fall and the crumble, spoil chunks off dying creatures, the resolve and the flight to the strip; the spoils page retired                              | 1 to 2 days |
| 4. The vein                     | six nodules, strikes, finds flying; the vein page retired                                                                                                 | 1 day       |
| 5. The dock as bench, the stall | the bag drawer with the panel's drag and drop; the merchant's counter, scales and lens                                                                    | 2 days      |
| 6. The other rooms              | the lift hall and the ride, hoard pedestals, salvage dice, the oddity plinth, the shaft head                                                              | 2 to 3 days |
| 7. Finish                       | footsteps and rock sounds, comfort settings, the chart fold-out, the tunnel gallery, screenshot targets                                                   | 1 to 2 days |

Phases 2 and 3 are what the owner asked for first and are worth a look on their own before the rest.

**Status (September 21, 2026): all seven phases are built**, with the suites passing.

| Piece              | Where                         | Notes                                                                                                                                                                                                                                                                                                                            |
| ------------------ | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The stage          | `view/run/mine_stage.gd`      | one World3D for the run: rooms, the walk, the crossroads, the rockfall, the spoils, the governor and the ambience. `BattleScreen` draws on it; shown on its own (the biome gallery) it makes its own                                                                                                                             |
| Portals and stubs  | `view/battle/chamber.gd`      | far wall at z = −24, triangulated round one to three mouths; trails carved level to each; every mouth holds a 12-metre stub, capped round its bend                                                                                                                                                                               |
| Tunnels            | `view/battle/tunnel.gd`       | the arch every portal is cut to, swept along a curve that leaves square to the wall, bends 4 to 5 metres aside, drops 2.5 metres (a stretch runs level about one depth in six, and a landing to its Warden's hall always does) and enters the next room square; rock and props turn from one biome to the next                   |
| Mouths             | `view/battle/mouth.gd`        | light, haze and motes in the color of what waits; a plaque with its mark; two glints in a dark mouth; a lantern per vote. A room about to be sealed shows its mouths lit and plain as the party arrives                                                                                                                          |
| Rockfall           | `view/battle/rockfall.gd`     | 30 boulders land lowest first with a thump, dust and a flash each; the crumble takes them top first                                                                                                                                                                                                                              |
| The walk           | stage                         | about 3.2 seconds from the crossroads to the next room's mark, with a stride; the carried lantern lights the tunnel; the air turns in the tunnel; the room ahead is built two slices a frame; on arrival the world is moved back so the new room is at the origin. A click, Space or Enter arrives at once                       |
| Spoils             | stage and `descent_screen.gd` | nuggets and a rough shed by each creature as it dies; on the settle the rough cracks into the real stone (a `GemMesh`), turns in the light and flies to the bag, the nuggets fly to the ore pill, and each count ticks over as its first piece lands; a line of words sums it up                                                 |
| The descent screen | `view/run/descent_screen.gd`  | the room is worked out from the state (`_place_of`); a new room is walked to through the mouth that was chosen, or built at once when there was no walk (a run begun, a party joined). The tunnels page, the 2D backdrop and the black curtain are gone; the chart folds out from the strip (Chart, or M); 1 to 3 choose a mouth |

| Things to point at | stage | anything a room's business is done with is registered with the stage by node and size; the stage reports pointing and clicking, starts drags from it and takes drops on it, and lights whatever would take what is being dragged. Clicking one pins its chip (with its buttons) until something else is clicked |
| The vein (4) | `view/battle/vein_face.gd` | an outcrop at the arena with six spots, three by two: bright spots sparkle hard with gold crystal breaking through, glints show a little blue, dull rock almost nothing. A strike swings the party's pick in from the edge of the view; the spot bursts into a hole lit in the finder's color and the find flies to the strip (an ally's flies off into the dark). The vug shakes the room and reddens the view on every blow. When the rock is spent it sinks into the floor as the way on opens |
| The dock and the bag (5) | `view/run/run_dock.gd` | outside a fight the rail, the five dice and health stand along the bottom where the fight's dock does; the bag is a drawer above them (the Bag button or B). Drag to set, take out, swap, and to give to an ally; right-click or click for the close look. Pages stop short of it. The full bench is still on the strip |
| The stall (5) | `view/battle/stall.gd` | a counter at the arena with a sign and a lantern; the goods are real stones and dice turning on stands with their prices; scales at one end, a lens at the other. Drag goods onto a socket, a die slot or the bag to buy (and set); drop a raw stone on the lens to appraise it, an appraised one on the scales to sell it; click any of them for a chip with Buy, Sell or Appraise buttons. The bag opens as the party walks up and closes as it leaves |
| The lift hall (6) | `view/battle/lift_hall.gd` | at a landing: the cage in its shaft under a warm light, a campfire (rest), a workbench with a lamp and a lens (appraise) and a grinding wheel (polish), each glowing and named when pointed at. Click the fire to rest; click the bench or the wheel for a list, or drop a stone on them. Then the cage is Up (click, then Ride up) and the mouths are Down, clickable from where the party stands; the mouth clicked gets the party's vote when the ways are offered. The shaft head has the cage under daylight; a Warden's hall has a cage for after its hoard |
| The hoard (6) | `view/battle/hoard.gd` | three pedestals, a real stone turning over each under a beam of its grade; click one for its lines and Take it; the stone flies to the bag and the other beams go out. The pedestals sink away when the landing's choice comes back |
| The oddity (6) | stage | a plinth with the oddity's mark burning over it; the choices are cards along the bottom, the name and words at the top |
| Salvage (6) | stage | a real die for every raw stone is thrown on the floor in front of the fallen party; a top face lights green and the stone rises to the bag, anything else lights red and the stone shatters. The verdicts are read down the right |
| The end (6) | stage | extracted or conquered, the party walks into the cage and rides up the shaft into the light; fallen, the room's lights go out and its color drains. Then the summary |
| Sounds (7) | `view/audio/sound_bank.gd` | footsteps on every footfall of a walk, a rockfall and a crumble, all synthesised like the rest of the bank |
| Tunnel gallery (7) | `tools/tunnel_gallery.gd` | walks out of every band-ending landing into the depth below and pictures the room, four moments down the tunnel and the room it reaches |

Screenshot targets for the new beats: `crossroads`, `crossroads_hover`, `walk`, `walk_in`, `rockfall`, `spoils`, `crumble`, `vein_hover`, `vein_strike`, `hoard`, `lift_ride`; a fourth argument sets the moment to shoot (seconds). `landing`, `lift`, `merchant`, `oddity`, `vein` and `over` now show the rooms in 3D.

## 14. Decisions (September 21, 2026)

The owner answered the ten questions; these override the sections above where they differ.

| #   | Question                | Decision                                                                                                                                           |
| --- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | The crossroads          | **A**: exits in the far wall of each room                                                                                                          |
| 2   | The chart               | **Keep** `shaft_map.gd` as a fold-out with Light the way on it                                                                                     |
| 3   | Walk length             | **About three seconds**, and a click (or Space) **jumps straight to the next room**, not double speed                                              |
| 4   | Spoils                  | **The view-side fake**                                                                                                                             |
| 5   | The rockfall            | **Ahead only**: no fall behind the camera                                                                                                          |
| 6   | The dock outside fights | **Always on screen**                                                                                                                               |
| 7   | Landings                | The choices are **objects in the lift hall**, glowing on hover: a campfire to rest, a workbench or anvil to appraise, a wheel to polish. Not cards |
| 8   | Fewer flashes           | **No cross-fade, ever.** Walks are always a dolly with a head bob; the bob still follows the shake slider                                          |
| 9   | Tunnels slope down      | **Yes**, the descent should be felt; some stretches may plateau (a landing to its Warden's hall does)                                              |
| 10  | Order of work           | **As planned** in §13                                                                                                                              |

Three things found while building phase 2 changed the layout slightly:

- **The room is shorter.** With the far wall at z = −30 the mouths sat 35 metres from the camera, deep in the depth fog, and a rockfall there could not be seen. The far wall now stands at z = −24, and the floor rises toward it in rubble with a trail carved to each mouth.
- **The crossroads is a beat of its own.** When a room's business is done the party walks up to about z = −8, where the mouths are large and clear, and the choice is made from there. The walk proper starts from that spot.
- **Every mouth has a stub.** A mouth is never a hole into nothing: each exit is built with the first nine metres of the tunnel it will become, bent out of sight, so the lit mouth shows real rock and the walk later extends the same tunnel without a pop.
