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

To add a type, duplicate the closest scene, edit it, set its root `Key`, and add its
path to `CrystalCreature.SCENE_PATHS`. Define its combat stats and moves separately
in `content/deep_cut.json`. An unregistered key uses `crystal_cluster.tscn` with a
stable color based on the key.

Run `python3 tools/run_checks.py` to check scene loading, independent instance
materials, authored transforms, Warden variants and the animation lifecycle alongside
the existing game suites.
