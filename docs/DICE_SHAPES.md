# Additional dice shapes

Implemented September 23, 2026. The shared tier ladder is:

**d2 → d3 → d4 → d6 → d8 → d10 → d12 → d16 → d20 → d24 → d30 → d40 → d50 → d60 → d100**

Smithies, Hammered stakes, enemy upgrades and Dread all follow this ladder. A d12
upgrades to d16, and a d20 downgrades to d16. Filing a d4 gives a d3, then a d2.
Player resizing refuses to go past either end; enemy tier changes clamp there.
Resizing still preserves the die's identity and engraving and replaces its faces
with plain numbers. Starting character bowls, starting encounters, and salvage
dice are unchanged, so the unusual sizes require deliberate tier changes.

| Die | Solid | Numbered faces | Body triangles |
| --- | --- | --- | --- |
| d2 | Bevelled coin | Two disks; the rim and bevels are unnumbered | 252 |
| d3 | Triangular prism with a pyramid at each end | Three rectangular sides; the six tip triangles are unnumbered | 12 |
| d16 | Octagonal trapezohedron, constructed like the d10 | 16 kite faces | 32 |
| d24 | Pentagonal icositetrahedron (dual of a snub cube) | 24 congruent pentagons | 72 |
| d30 | Rhombic triacontahedron (dual of an icosidodecahedron) | 30 rhombi | 60 |
| d40 | Faceted sphere | 40 flat polygonal faces | 148 |
| d50 | Faceted sphere | 50 flat polygonal faces | 188 |
| d60 | Pentakis dodecahedron (dual of a truncated icosahedron) | 60 congruent triangles | 60 |
| d100 | Faceted sphere | 100 flat polygonal faces | 388 |

The faceted spheres are intersections of tangent planes sampled in opposite pairs
around a sphere. Their faces vary slightly in area. Rolling remains uniform over
the die's face data: the deterministic simulation chooses the result, and the view
spins to that numbered face. There is no rigid-body settling or physical fairness
assumption, and the coin rim and crystal tips cannot be rolled as results.

Small solids retain the existing hull builder. Larger ones use incremental plane
clipping, avoiding an expensive hull search over hundreds of vertices. Each solid's
geometry and face frames are cached. The d100 took approximately **19 ms** to build
cold in Godot 4.7.2 headless on this machine; subsequent solid requests use the cache.
The body and outline together use 776 triangles, plus numeral quads. Geometry does
not require a d30 or d40 limit. GPU time, numeral readability and draw-call cost
still need a graphical run: both Metal and OpenGL initialization failed in the
implementation session, before the gallery could render.

The numerical ceiling is now 100, including mirrors, hand mutations and content
validation. Explosions retain their three-extra-roll limit and cap their result at
100. Per-point effects such as Thousand Cuts can repeat up to 100 times. Large die
inspectors show faces in pages of 30, with statistics on an About page, so every
number remains clickable without overflowing the screen.

`tests/test_dice_shapes.gd` checks face counts, planar and convex surfaces, outward
winding, closed meshes, equal face areas on the named solids, rhombic d30 faces,
roll-to-numeral alignment, every upgrade/downgrade, Dread, and high-value rolls.
The battle suite checks a 100-hit Thousand Cuts, and the layout suite checks every
inspector page. All scenario assertions passed. The aggregate runner still flags
two shader RID leaks in `test_view.gd`; the same leaks reproduced in a separate
baseline copy with the pre-existing gem changes and without these dice changes.

For visual review and a warmed-up rolling benchmark on a graphical display:

```sh
/path/to/Godot --path . --script tools/dice_gallery.gd -- build/dice.png
/path/to/Godot --path . --script tools/dice_gallery.gd -- build/d100-bowl.png D100 D100 D100 D100 D100
```
