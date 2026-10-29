# Creature scenes

Every creature type has an editable scene in `view/creatures/scenes/`. These scenes
contain the existing low-poly meshes, materials, part transforms, light, shadow and
target ring. They are the source of the creature's appearance; geometry is no longer
built when a creature spawns.

Open a scene such as `cave_tick.tscn` in Godot to edit it. The same scene is used in
battles and the creature inspector. Multiple cave ticks are instances of that one
scene, with separate animation state and materials.

## Editing a creature

- **Body** holds the model. Its named pivots (`Core01`, `Crystal01`, `Wing01`, etc.)
  can be moved, rotated and scaled. Their `Mesh` children hold the actual geometry
  and can be replaced with another mesh or an imported model.
- **Creature parts** use `creature_part.gd`. The exported `Motion`, `Phase` and
  `Wing Side` properties control their idle movement. Choose `static` for a part
  that should stay still. Idle movement uses the saved transform as the rest pose.
  Additional pivots with this script are discovered automatically beneath `Body`.
- **Root properties** select the shared idle style and breathing speed (`Sway`).
  `Body Material` and `Core Material` reference the materials used by the meshes;
  edit those resources to change the surface appearance. Keep `Local to Scene`
  enabled on these materials and the target-ring material so animation stays local
  to each instance. Assign these same materials to new meshes that should flash on hits.
- **Anchor** is a marker above the model. Move it when changing the creature's height:
  the battle uses it for labels and hit placement, and the inspector uses it to frame
  the model. Its position is local; root scale is accounted for automatically.
- **Glow**, **Shadow** and **TargetRing** control the light and floor effects.

Keep those five top-level node names and the root `crystal_creature.gd` script.
The meshes are saved resources, so they appear in the editor without running the game.
Existing idle movement and spawn, hit, lunge, channel and death effects remain scripted.

## Spawning and adding types

`CrystalCreature.make(key, is_warden)` loads and caches the matching `PackedScene`,
then calls `instantiate()`. The battle adds that instance to its 3D world; the
inspector adds it to its preview pivot. Directly placing a creature scene in another
scene also works, including its saved position and Warden appearance.

The three Warden scenes already contain their larger scale, warmer materials and
stronger light. Passing the opposite Warden flag to the factory switches the variant
without making another scene. `Normal Tint` supplies the palette for that conversion;
update it too if you change the creature's color and use both variants.

To add a type, either duplicate the closest scene, edit it, set its root `Key`, and add
its key to `CrystalCreature.SCENE_KEYS` (the path is `scenes/<key_lower>.tscn`), or write a
recipe and bake it (below). Define its combat stats and moves separately in
`content/deep_cut.json`. An unregistered key uses `crystal_cluster.tscn` with a stable
color based on the key.

## Baking a scene from a recipe

The deeper mines' creatures (October 2, 2026) are baked from data. A recipe in
`tools/creature_recipes/<mine>.gd` lists the shapes a creature is made of (the low-poly
rocks, crystals, spikes, columns, caps and slabs of `view/battle/lowpoly.gd`, and Godot's
spheres, cylinders, cones, boxes, tori and capsules), where each sits, which material it
wears and how it idles. `tools/creature_bake.gd` turns every recipe into a scene with the
five top-level nodes above:

```sh
/path/to/Godot --headless --path . --script tools/creature_bake.gd                 # every recipe
/path/to/Godot --headless --path . --script tools/creature_bake.gd -- RAIL_RAT     # one
/path/to/Godot --path . --script tools/creature_sheet.gd -- build/sheet.png RAIL_RAT PIT_MOLE   # look at them
```

The bake tool's header documents the recipe format. A baked scene is an ordinary scene
afterwards: edit it in Godot like any other, or edit the recipe and bake again.

Since the October 2026 model review every creature but the Quartz Golem and the Lantern Moth
is baked from a recipe. A recipe moved in from a review batch names that batch's key as its
`seed` (`"seed": "CAVE_TICK_A"`), so its rocks and crystals are cut exactly as they were picked.
Parts an animation will move carry a `name` (the pivot becomes `Jaw01`, `ClawL01`, `Tail01`,
...), and parts that move together share a `joint`; build/options/PART_ROLES.md (local, not in
git) lists every creature's roles, hinges and directions.

## Variants and the accent material

A variant (a Fire Tick for the Cave Tick) is its base creature's scene in other colors:
`CrystalCreature.VARIANTS` names the base and the tint, and `make()` recolors the instance.
Scenes may carry a third **Accent Material** for their brightest parts (a lamp, a fire, an
eye); it is animated with the body and core and recolored for variants. A Void Echo spawns
the scene of the creature it copies and is drawn as a ghost (`ghost()`).

Parts gained idle motions beyond the first five: `orbit`, `spin`, `bob`, `swing`, `tread`
and `flicker`. The presentation API gained `burrow(down)`, `flee()`, `set_halo(color)`,
`clear_halo()` and `set_charging(on)`. A variant may also name a `core` color and a `scale`.
(The Geode Golem was once the Quartz Golem's scene recolored this way; it has its own scene now.)

## The bestiary's portraits

The Bestiary tab lists creatures as pictures, not live 3D: one PNG per creature in
`view/creatures/portraits/<key>.png`, baked from the scene on the turntable, off its plinth,
cropped square. Bake again after changing a creature's scene or colors, and bake one for
every new creature (`tests/test_creatures.gd` fails until it has one):

```sh
/path/to/Godot --path . --script tools/creature_portraits.gd                    # every creature
/path/to/Godot --path . --script tools/creature_portraits.gd -- RAIL_RAT        # one
/path/to/Godot --headless --path . --import                                     # then import
```

A new picture's `.import` should have `mipmaps/generate=true` like the others: the grid draws
it at well under half the size it is baked at.

Run `python3 tools/run_checks.py` to check scene loading, independent instance
materials, authored transforms, Warden variants and the animation lifecycle alongside
the existing game suites.
