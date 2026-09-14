# Sprites

These PNGs are the game's art. They ship with the build and are what you see in play —
nothing is drawn procedurally at runtime as long as a file is present.

They were *generated* by [`scripts/ui/sprite_forge.gd`](../../scripts/ui/sprite_forge.gd) and
baked here once, so they are an editable starting point rather than a runtime effect. Open
any of them, repaint it, and the game uses your version. The painter stays in the code only
as a fallback for a key whose file is missing.

## Editing

Just edit the PNG in place and let Godot reimport it. Nothing else to do.

To try a change without touching the repository, drop a file at
`user://sprites/<category>/<key>.png` instead — that path wins over this one and is loaded at
runtime with no reimport. On Windows it resolves to
`%APPDATA%\Godot\app_userdata\RogueDice\sprites\`.

## Regenerating

Only needed if you change the painter in `sprite_forge.gd`. **This overwrites hand-painted
art**, so pass `--keep` to skip files that already exist.

```sh
godot --headless --path . --script tools/bake_sprites.gd          # rewrite every sprite
godot --headless --path . --script tools/bake_sprites.gd -- --keep # only fill in missing ones
godot --headless --path . --import                                # regenerate .import files
```

## Contents

`<key>` is the lowercase content key from [`scripts/core/catalog.gd`](../../scripts/core/catalog.gd).

| Category | Keys | Size |
| --- | --- | --- |
| `heroes` | `ardor`, `kait`, `max` | 128 × 128, feet at ~93% height |
| `enemies` | `slime`, `red_slime`, `stone_crab`, `gem_cultist`, `dartling`, `iron_warden`, `mirror_wisp`, `rift_hound`, `slime_king`, `mirror_regent`, `rift_sovereign` | 128 × 128 |
| `gems` | one per skill: `strike`, `block`, `heal`, `multistrike`, … | 72 × 72 |
| `relics` | `matchbox`, `steady_hand`, `field_dressing`, `miners_lantern`, `focusing_prism`, `merchant_seal`, `tinkers_belt`, `lasting_aegis` | 72 × 72 |
| `rooms` | `battle`, `elite`, `boss`, `shop`, `rest`, `event`, `mine`, `workshop`, `lapidary`, `wager`, `crucible` | 72 × 72 |
| `props` | `sigil`, `gold`, `heart`, `shield`, `skull` | 72 × 72 |

Transparent background. Any size works — sprites are drawn with
`STRETCH_KEEP_ASPECT_CENTERED`, so the aspect ratio is preserved and the art is scaled to fit
its slot. Characters are drawn facing the viewer; the battlefield flips their lunge direction
by side, so no mirrored copies are needed.

## Animation

No extra frames are required. [`scripts/ui/sprite_actor.gd`](../../scripts/ui/sprite_actor.gd)
breathes, sways, lunges at a target, flashes on damage and drains the colour of a downed unit
by deforming and recolouring the still image.

## Dice are not sprites

They are real polyhedra built by
[`scripts/ui/dice_geometry.gd`](../../scripts/ui/dice_geometry.gd) and rendered per die in a 3D
SubViewport, so face values and colours follow each die's actual face data. There is nothing to
paint here for them.
