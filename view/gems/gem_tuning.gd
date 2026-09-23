extends RefCounted
## Every number that decides how a stone is surfaced and lit, in one adjustable table.
##
## `gem_mesh.gd` and `gem_view.gd` ask this for their material and environment values
## instead of holding literals, so the gem lab can move any of them with a slider and watch
## the stone answer. Untouched, every call returns exactly the number those two files used
## to hard-code, so the game and the test suites still see the shipped look.
##
## Two of these are baked into the mesh rather than read off a material — the facet tones
## are vertex colors, decided when the solid is cut — so moving a knob means re-cutting the
## stone, not just re-skinning it. A knob marked `"view": true` is applied by `gem_view.gd`
## to the scene rather than to a material, so it cannot be seen in a material at all.
## `GemView.restyle()` covers all three, and is what the lab calls.
##
## When a setting looks right, `source_lines()` writes the changed knobs back out as the
## table entries to paste in below. That is how a tuning session becomes the shipped look:
## nothing here persists on its own, and the lab is not part of the game.

## Each knob: where it lives, what it does, and the range worth sweeping. `step` of 1.0 with
## a 0..1 range marks a switch; the lab draws those as a toggle instead of a slider.
const KNOBS := [
	# --- the near half of the stone, which is what you look through ---------------
	{"key": "near_alpha_dull", "group": "STONE", "label": "Front alpha · Fractured",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.85,
		"hint": "How solid the front of a Clarity 1 stone is. 1.0 is paint."},
	{"key": "near_alpha_clear", "group": "STONE", "label": "Front alpha · Flawless",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.25,
		"hint": "The same for a Clarity 5 stone. This and the back alpha multiply, so 0.5 over 0.8 still hides four fifths of the background."},
	{"key": "refraction", "group": "STONE", "label": "Refraction",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.00,
		"hint": "How far the front of the stone bends what is behind it. Godot's refraction writes the fragment fully opaque, so on a view with no ground it overrides both front alpha knobs and hides whatever is behind the viewport. On a grounded view — the lab always is — the background is inside the scene, so refraction bends it and the alpha still counts."},
	{"key": "grey_pull", "group": "STONE", "label": "Cloudiness",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.32,
		"hint": "How far a Fractured stone's hue is pulled towards grey. Re-cuts the stone."},
	{"key": "facet_swing", "group": "STONE", "label": "Facet variation",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 1.00,
		"hint": "How much neighbouring facets differ in tone. Zero is a moulded blob. Re-cuts the stone."},

	# --- the far half, drawn first and seen through the near one ------------------
	{"key": "far_alpha_dull", "group": "DEPTH", "label": "Back alpha · Fractured",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.44,
		"hint": "How much of a cloudy stone's own pavilion shows through its crown."},
	{"key": "far_alpha_clear", "group": "DEPTH", "label": "Back alpha · Flawless",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.90,
		"hint": "The same for a clean stone. Drop this and the front alpha together to see the background through the gem."},
	{"key": "far_darken", "group": "DEPTH", "label": "Back shade",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.47,
		"hint": "How much darker the far facets are, which is what gives the stone depth rather than layers."},
	{"key": "far_pass", "group": "DEPTH", "label": "Draw the back half",
		"low": 0.0, "high": 1.0, "step": 1.0, "value": 1.0, "view": true,
		"hint": "Off leaves only the front of the stone, which is the clearest way to see what the front alpha alone is doing."},
	{"key": "far_emission", "group": "DEPTH", "label": "Back inner light",
		"low": 0.0, "high": 2.0, "step": 0.02, "value": 0.46,
		"hint": "The share of the inner glow the far half carries."},

	# --- how the surface answers light --------------------------------------------
	{"key": "roughness_dull", "group": "SURFACE", "label": "Roughness · Fractured",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.06,
		"hint": "An unpolished stone scatters instead of reflecting."},
	{"key": "roughness_clear", "group": "SURFACE", "label": "Roughness · Flawless",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.02,
		"hint": "Near zero is a mirror polish."},
	{"key": "metallic_dull", "group": "SURFACE", "label": "Metallic · Fractured",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.06,
		"hint": "A touch strengthens the sky reflection. Too much and the gem reads as painted steel."},
	{"key": "metallic_clear", "group": "SURFACE", "label": "Metallic · Flawless",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.22,
		"hint": "The same at the top of the range."},
	{"key": "rim_dull", "group": "SURFACE", "label": "Rim · Fractured",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.22,
		"hint": "Light catching the edges where the stone turns away from you."},
	{"key": "rim_clear", "group": "SURFACE", "label": "Rim · Flawless",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 1.00,
		"hint": "The same at the top of the range."},
	{"key": "clearcoat", "group": "SURFACE", "label": "Lacquer",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 1.00,
		"hint": "A second glossy layer over the body, which is most of the wet look."},
	{"key": "emission_clear", "group": "SURFACE", "label": "Inner light · Flawless",
		"low": 0.0, "high": 2.0, "step": 0.02, "value": 0.42,
		"hint": "How much a clean stone glows from inside. Past the glow threshold this blooms."},

	# --- what is frozen inside the stone ------------------------------------------
	{"key": "flaw_size", "group": "INSIDE", "label": "Inclusion size",
		"low": 0.1, "high": 3.0, "step": 0.02, "value": 1.00,
		"hint": "How large each thing frozen in the stone is cut. Re-cuts the stone."},
	{"key": "flaw_alpha", "group": "INSIDE", "label": "Inclusion strength",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 1.00,
		"hint": "How solidly an inclusion reads through the crystal over it. Zero empties the stone. Re-cuts the stone."},
	{"key": "flaw_facet", "group": "INSIDE", "label": "Surface smudge",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.34,
		"hint": "How far a facet darkens where a flaw reaches it. This was once the whole of what an inclusion looked like. Re-cuts the stone."},
	{"key": "rind_alpha", "group": "INSIDE", "label": "Second color",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.88,
		"hint": "How solidly the second half of a two-colored stone reads through the crystal over it. Zero leaves the stone one color. Re-cuts the stone."},
	{"key": "seam_width", "group": "INSIDE", "label": "Seam width",
		"low": 0.01, "high": 0.6, "step": 0.005, "value": 0.115,
		"hint": "How broad each vein of an opal Seam is cut. Re-cuts the stone."},
	{"key": "seam_fire", "group": "INSIDE", "label": "Seam fire bias",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.72,
		"hint": "How far a Seam pulls the opal play-of-color towards the color it replays. Zero is the white-light spectrum an ordinary opal returns, and washes all six Seams to one pastel."},
	{"key": "seam_room", "group": "INSIDE", "label": "Seam room",
		"low": 0.1, "high": 1.0, "step": 0.01, "value": 0.45,
		"hint": "How much of an ordinary opal's play-of-color a Seam keeps. One drowns the vein under the additive pass; low leaves the stone room to show what runs through it."},
	{"key": "seam_alpha", "group": "INSIDE", "label": "Seam strength",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 1.00,
		"hint": "How strongly a Seam's color shows through the milky body it runs in. Re-cuts the stone."},

	# --- fire: the rainbow a cut stone throws out of white light ------------------
	{"key": "fire", "group": "FIRE", "label": "Fire",
		"low": 0.0, "high": 3.0, "step": 0.02, "value": 0.86,
		"hint": "How strongly facets throw spectral color. Scaled by Clarity, so a Fractured stone throws none."},
	{"key": "fire_bands", "group": "FIRE", "label": "color cycles",
		"low": 0.2, "high": 12.0, "step": 0.1, "value": 1.10,
		"hint": "How many times the spectrum repeats across the stone. Low is two or three broad washes, high is a fine rainbow scatter."},
	{"key": "fire_spread", "group": "FIRE", "label": "Spread",
		"low": 0.2, "high": 4.0, "step": 0.02, "value": 1.56,
		"hint": "How fast the color changes from one facet to the next, and so how far it sweeps when the stone turns."},
	{"key": "fire_reach", "group": "FIRE", "label": "Reach",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.02,
		"hint": "Zero keeps the fire at the rim, where facets are steepest. One spreads it across the whole face."},
	{"key": "fire_sharpness", "group": "FIRE", "label": "Falloff",
		"low": 0.2, "high": 8.0, "step": 0.05, "value": 6.60,
		"hint": "How abruptly the fire fades from the steep facets to the flat ones."},
	{"key": "fire_tint", "group": "FIRE", "label": "Body tint",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.21,
		"hint": "Zero throws a pure white-light spectrum, like a diamond. One pulls it right back into the gem's own color."},
	{"key": "facet_hue", "group": "FIRE", "label": "Facet hue spread",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.60,
		"hint": "Splits the body color slightly differently on each facet, baked into the solid. This is the half of the prism that stays put when the stone does. Re-cuts the stone."},

	# --- the emblem cut into the table --------------------------------------------
	{"key": "etch_inset", "group": "ETCH", "label": "Etch inset",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.85,
		"hint": "How far into the crown the emblem is set. Zero puts it back on the table surface, where parts of it float clear of a face that has sloped away. One drops it to the girdle, deepest inside the stone — and hardest to read through a cloudy one."},
	{"key": "etch_depth", "group": "ETCH", "label": "Etch relief",
		"low": 0.0, "high": 3.0, "step": 0.05, "value": 3.00,
		"hint": "How steeply the walls of the emblem fall away from the plate it is cut into."},
	{"key": "etch_darken", "group": "ETCH", "label": "Etch shade",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.00,
		"hint": "How much darker the floor of the groove starts. It lights back up, so it has to start dark to read as a recess."},
	{"key": "etch_alpha", "group": "ETCH", "label": "Etch strength",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.86,
		"hint": "How firmly the emblem sits on the table. Lower lets more stone through it."},
	{"key": "etch_murk", "group": "ETCH", "label": "Etch through murk",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.62,
		"hint": "Extra shade and opacity the emblem takes on as Clarity falls. A cloudy stone is nearly solid, so only a fraction of what is set inside it comes through; without this the emblem disappears exactly where the player still has to read it. Zero switches the compensation off and leaves the emblem the same at every Clarity."},
	{"key": "etch_roughness", "group": "ETCH", "label": "Etch roughness",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 1.00,
		"hint": "A groove is not polished. Low values turn it into a bright inlay sitting on top."},

	# --- the turn a gem has when nothing is happening to it -----------------------
	{"key": "drift_turn", "group": "MOTION", "label": "Idle sway",
		"low": 0.0, "high": 30.0, "step": 0.5, "value": 6.0, "view": true,
		"hint": "Degrees the stone swings either side of where it rests, the way the dice breathe on the table. Zero holds it still — and puts every gem back to a single rendered frame instead of a live camera."},
	{"key": "drift_rate", "group": "MOTION", "label": "Sway speed",
		"low": 0.0, "high": 3.0, "step": 0.01, "value": 0.55, "view": true,
		"hint": "How fast that swing runs, in radians per second of its own clock. Slow enough that it reads as weight rather than as animation."},

	# --- the room the stone is standing in ----------------------------------------
	{"key": "exposure", "group": "LIGHT", "label": "Exposure",
		"low": 0.2, "high": 2.0, "step": 0.01, "value": 0.76,
		"hint": "Under ACES this runs hot fast: past 1.0 the body color bleaches out."},
	{"key": "ambient", "group": "LIGHT", "label": "Ambient",
		"low": 0.0, "high": 1.0, "step": 0.01, "value": 0.16,
		"hint": "Sky light filling the facets that face away. Too much flattens the cut."},
	{"key": "sky_energy", "group": "LIGHT", "label": "Sky strength",
		"low": 0.0, "high": 3.0, "step": 0.02, "value": 1.70,
		"hint": "How bright the sky the facets mirror is. Reflection, not illumination."},
	{"key": "light_energy", "group": "LIGHT", "label": "Key lights",
		"low": 0.0, "high": 3.0, "step": 0.02, "value": 1.76,
		"hint": "All four directional lights at once, keeping their balance."},
	{"key": "glow_intensity", "group": "LIGHT", "label": "Glow",
		"low": 0.0, "high": 2.0, "step": 0.02, "value": 0.58,
		"hint": "How far blown highlights bloom."},
	{"key": "glow_threshold", "group": "LIGHT", "label": "Glow threshold",
		"low": 0.0, "high": 3.0, "step": 0.02, "value": 1.08,
		"hint": "How bright a highlight has to be before it blooms. Below 1.0 the whole stone starts glowing and swallows the emblem."},
	{"key": "ssr", "group": "LIGHT", "label": "Facet reflections",
		"low": 0.0, "high": 1.0, "step": 1.0, "value": 1.0, "view": true,
		"hint": "Screen-space reflections, so facets mirror facets and the ground. Only works when the stone is standing on a ground: Godot switches SSR off in a viewport with a transparent background."},
	{"key": "ssao", "group": "LIGHT", "label": "Contact shade",
		"low": 0.0, "high": 4.0, "step": 0.05, "value": 1.40,
		"hint": "Darkening where facets meet, so the cut reads as cut. Zero switches it off."},
	{"key": "halo", "group": "LIGHT", "label": "Halo",
		"low": 0.0, "high": 3.0, "step": 0.02, "value": 1.00,
		"hint": "The 2D light the stone throws onto the panel behind it."}]

## Only what has been moved. Empty means the shipped look.
static var _moved: Dictionary = {}
static var _index: Dictionary = {}
## Bumped on every change, so a caller can tell whether its cached material is stale.
static var _revision: int = 0

static func _table() -> Dictionary:
	if _index.is_empty():
		for knob: Dictionary in KNOBS:
			_index[str(knob.key)] = knob
	return _index

static func definition(key: String) -> Dictionary:
	return _table().get(key, {})

static func default_of(key: String) -> float:
	return float(definition(key).get("value", 0.0))

static func value(key: String) -> float:
	## The one call the rest of the code makes. Unknown keys return zero rather than
	## throwing, because a knob being renamed should dim a gem, not crash a battle.
	if _moved.has(key):
		return float(_moved[key])
	return default_of(key)

static func flag(key: String) -> bool:
	return value(key) > 0.5

static func set_value(key: String, amount: float) -> void:
	var knob: Dictionary = definition(key)
	if knob.is_empty():
		return
	var held := clampf(amount, float(knob.low), float(knob.high))
	if is_equal_approx(held, default_of(key)):
		_moved.erase(key)
	else:
		_moved[key] = held
	_revision += 1

static func reset() -> void:
	_moved.clear()
	_revision += 1

static func revision() -> int:
	return _revision

static func moved() -> Array:
	## Which knobs are off their default, in table order so the report reads top to bottom.
	var found: Array = []
	for knob: Dictionary in KNOBS:
		if _moved.has(str(knob.key)):
			found.append(str(knob.key))
	return found

static func groups() -> Array:
	var seen: Array = []
	for knob: Dictionary in KNOBS:
		if not seen.has(str(knob.group)):
			seen.append(str(knob.group))
	return seen

static func in_group(group: String) -> Array:
	var found: Array = []
	for knob: Dictionary in KNOBS:
		if str(knob.group) == group:
			found.append(knob)
	return found

static func source_lines() -> String:
	## The changed knobs as the `"value":` entries to paste back into KNOBS above. Printing
	## the whole table would bury the two numbers that actually moved.
	var changed: Array = moved()
	if changed.is_empty():
		return "# gem tuning: everything at its default."
	var lines: PackedStringArray = ["# gem tuning: %d changed. Paste each into its KNOBS entry." % changed.size()]
	for key: String in changed:
		lines.append("\t\"%s\": \"value\": %.3f,   # was %.3f" % [key, value(key), default_of(key)])
	return "\n".join(lines)
