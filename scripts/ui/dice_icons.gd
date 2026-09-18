extends RefCounted
## Draws what a hand has to show — a gem's trigger, a hero's passive or signature — as the
## pictograph of that requirement, with the number it needs beside it.
##
## Every requirement kind in `requirements.gd` has a mark of its own: a pair is two matching
## dice, a straight a stair of dice as long as the run, a total the sum sign over an arrow.
## An always-firing gem is drawn as the thing it grows with, so Strike reads "highest die".
## The sentence stays on the tooltip; the mark only makes it readable at a glance.
##
## `strip()` is the older drawing of the same triggers as literal die faces. The content
## studio still draws that one, and its cross-check reads it from here.

const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const GemRules = preload("res://scripts/core/gem_rules.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const Requirements = preload("res://scripts/core/requirements.gd")

const NEED_TONE := Color("e6e9f0")

const MATCH_TONE := Color("ffcf7a")
const OTHER_TONE := Color("76b6ff")
const RUN_TONE := Color("6fe3b0")
const PLAIN_TONE := Color("d8dce6")
const LEAD_TONE := Color("8f9fb5")

## Every die's body and edge colour, keyed the way the content keys them. This is the
## single source: the 3D view reads it too, so a solid and its icon never disagree.
const DIE_PALETTE := {
	"D4": ["d9a05b", "6d4a20"], "D6": ["e6e2d4", "7c7565"], "D8": ["5fc7bd", "235e5a"],
	"D10": ["6fa8ff", "27467f"], "D12": ["b98bff", "4a2f7a"], "D20": ["ff8672", "7a2b26"],
	"PAIRED_D6": ["ff9cc4", "7d2f52"], "ODD_D6": ["8fd8ff", "2b5b7a"],
	"EVEN_D6": ["b7e06a", "4d6b22"], "SEVEN_D8": ["ffd166", "806018"],
	"SPLIT_D12": ["ff86e0", "7a2668"], "SPLIT_D20": ["8f7bff", "2b1f6b"]}

## The face-on silhouette of each solid, in unit space, with where its numeral sits.
## A d4 reads as a triangle, a d6 a square, a d8 a diamond, a d10 a kite, a d12 a
## pentagon and a d20 a hexagon — the shapes players already read on a table.
const SILHOUETTES := {
	"D4": {"points": [Vector2(0.50, 0.04), Vector2(0.97, 0.92), Vector2(0.03, 0.92)],
		"font": 0.40, "middle": 0.64},
	"D6": {"points": [Vector2(0.07, 0.07), Vector2(0.93, 0.07), Vector2(0.93, 0.93), Vector2(0.07, 0.93)],
		"font": 0.58, "middle": 0.50},
	"D8": {"points": [Vector2(0.50, 0.02), Vector2(0.97, 0.50), Vector2(0.50, 0.98), Vector2(0.03, 0.50)],
		"font": 0.46, "middle": 0.52},
	"D10": {"points": [Vector2(0.50, 0.02), Vector2(0.96, 0.36), Vector2(0.50, 0.98), Vector2(0.04, 0.36)],
		"font": 0.44, "middle": 0.48},
	"D12": {"points": [Vector2(0.50, 0.02), Vector2(0.97, 0.36), Vector2(0.79, 0.95), Vector2(0.21, 0.95), Vector2(0.03, 0.36)],
		"font": 0.48, "middle": 0.56},
	"D20": {"points": [Vector2(0.50, 0.02), Vector2(0.95, 0.27), Vector2(0.95, 0.73), Vector2(0.50, 0.98), Vector2(0.05, 0.73), Vector2(0.05, 0.27)],
		"font": 0.50, "middle": 0.52}}

static func palette(key: String) -> Dictionary:
	var entry: Array = DIE_PALETTE.get(key.to_upper(), [])
	if entry.is_empty():
		return {"body": Color("d8dce6"), "edge": Color("545c6b")}
	return {"body": Color(str(entry[0])), "edge": Color(str(entry[1]))}

static func silhouette(shape: String) -> Dictionary:
	## Falls back to the cube, which is the shape every reader recognises.
	var key := shape.to_upper()
	var outline: Dictionary = SILHOUETTES.get(key, SILHOUETTES["D6"])
	return {"shape": key if SILHOUETTES.has(key) else "D6", "points": outline.points,
		"font": outline.font, "middle": outline.middle}

static func face(edge: float, value: int, tone: Color, shape := "D6", filled := false) -> Face:
	## The only way to build a face: it resolves the silhouette the inner class needs.
	return Face.new(edge, value, tone, silhouette(shape), filled)

class Face extends Control:
	## One die face drawn flat: the solid's own silhouette with its value on it.
	## `solid` paints it as a real die body; otherwise it is the light outline the
	## gem requirements use.
	var value := 1
	var tone := Color("d8dce6")
	var shape := "D6"

	var _points: Array = []
	var _font_scale := 0.58
	var _middle := 0.5
	var _fill := Color("d8dce6")
	var _edge := Color("d8dce6")
	var _ink := Color("d8dce6")

	func _init(edge: float, face_value: int, face_tone: Color, outline: Dictionary, filled := false) -> void:
		value = face_value
		tone = face_tone
		shape = str(outline.get("shape", "D6"))
		_points = outline.points
		_font_scale = float(outline.font)
		_middle = float(outline.middle)
		if filled:
			_fill = tone
			_edge = tone.darkened(0.45)
			_ink = Color("15181f") if tone.get_luminance() > 0.45 else Color("f4f7fb")
		else:
			_fill = Color(tone, 0.18)
			_edge = Color(tone, 0.9)
			_ink = tone
		custom_minimum_size = Vector2(edge, edge)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var outline := PackedVector2Array()
		for point in _points:
			outline.append(Vector2(point) * size)
		draw_colored_polygon(outline, _fill)
		var loop := outline.duplicate()
		loop.append(outline[0])
		draw_polyline(loop, _edge, maxf(1.0, size.x * 0.055), true)
		var font := ThemeDB.fallback_font
		var text := str(value)
		# Two digits have to sit inside the same silhouette, so they shrink to fit.
		var scale: float = _font_scale * (0.70 if text.length() > 1 else 1.0)
		var font_size := maxi(7, int(size.y * scale))
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := size.y * _middle + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2((size.x - measured.x) * 0.5, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _ink)

static func requirement(key: String, clarity: int = 1, cut: int = 1, carat: int = 1) -> Dictionary:
	## What would switch this skill on, at the ranks it resolves with.
	return Requirements.skill(key, clarity, cut, carat)

static func glyph_for(requirement: Dictionary) -> String:
	## The pictograph a requirement is drawn with. Each kind has its own; an always-firing
	## effect borrows the mark of the term it grows with.
	match str(requirement.get("kind", "")):
		"scale":
			var scale := str(requirement.get("scale", "carat"))
			return scale if GemIcons.known(scale) else "carat"
		"straight": return "straight%d" % clampi(int(requirement.get("amount", 3)), 3, 5)
		"value": return "face"
		"total_at_least": return "total_high"
		"total_at_most": return "total_low"
		"high_at_least": return "peak"
		"pair", "two_pairs", "triple", "quad", "full_house", "odd", "even", "distinct", "climb", "once":
			return str(requirement.kind)
	return "carat"

static func build(parent: Node, requirement: Dictionary, edge: float, tooltip: String = "", tint: Color = NEED_TONE) -> HBoxContainer:
	## The mark and its label as one hoverable row. PASS keeps the card's own clicks working.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", maxi(2, int(edge * 0.2)))
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tooltip if not tooltip.is_empty() else str(requirement.get("words", ""))
	parent.add_child(row)
	var glyph := GemIcons.glyph(row, glyph_for(requirement), edge, tint, row.tooltip_text)
	glyph.mouse_filter = Control.MOUSE_FILTER_PASS
	var label := str(requirement.get("label", ""))
	if not label.is_empty():
		var words := Label.new()
		words.text = label
		words.add_theme_font_size_override("font_size", maxi(9, int(edge * 0.62)))
		words.add_theme_color_override("font_color", tint)
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(words)
	return row

static func detail(key: String, clarity: int = 1, cut: int = 1, carat: int = 1) -> String:
	## The tooltip text for a gem's requirement.
	return str(Requirements.skill(key, clarity, cut, carat).get("words", ""))

static func strip(key: String, clarity: int = 1, cut: int = 1, carat: int = 1) -> Dictionary:
	## The dice that would switch this skill on, given its effective Clarity.
	## `faces` are [value, tone]; `lead` is the comparison drawn ahead of them.
	var l: int = clampi(clarity, 1, 5)
	var run: int = 5 - (l - 1) / 2
	var definition: Dictionary = Catalog.definitions("skills").get(Catalog.canonical_key(key), {})
	if GemRules.has_rule(definition):
		return _from_trigger(definition.rule.get("trigger", {}), l, cut, carat)
	## A gem that borrows a rule shows the rule's requirement, not its own name's.
	match Combat.rule_of(key):
		"BLOCK", "INTERPOSE", "TITHE":
			return _spec(_same(2, 4), "", "Any two dice sharing a value.")
		"HEAVYSTRIKE", "ENERVATE":
			return _spec(_same(3, 5), "", "Any three dice sharing a value.")
		"SHIELDBASH":
			return _spec(_same(3, 5) + _same(2, 2, OTHER_TONE), "",
				"Three dice of one value and two of another.")
		"SUNDER", "GRAFT":
			return _spec(_same(2, 2) + _same(2, 5, OTHER_TONE), "",
				"Two pairs of different values.")
		"MULTISTRIKE", "LIFELINE":
			return _spec(_run(run), "", "A run of %d consecutive values, in any order." % run)
		"BLESSING", "ARC_BURST":
			return _spec(_run(3), "", "A run of three consecutive values, in any order.")
		"LUCKYSTRIKE":
			return _spec([[7, MATCH_TONE]], "", "At least one die showing 7.")
		"MEND", "HEXBOLT":
			return _spec([[1, RUN_TONE], [3, RUN_TONE], [5, RUN_TONE]], "",
				"At least three odd results.")
		"EVEN_TEMPO", "PURGE", "MIASMA":
			return _spec([[2, RUN_TONE], [4, RUN_TONE], [6, RUN_TONE]], "",
				"At least three even results.")
		"PRECISION":
			return _spec([[3, PLAIN_TONE], [1, PLAIN_TONE], [6, PLAIN_TONE], [2, PLAIN_TONE], [5, PLAIN_TONE]],
				"≠", "All five dice showing different values.")
		"ECHO":
			return _spec(_same(2, 4), "", "Any two dice sharing a value.")
		"QUARTET":
			var alike: int = 3 if l == 5 else 4
			return _spec(_same(alike, 4), "", "Any %d dice sharing a value." % alike)
		"FACET", "MINT":
			## The same easing a straight gets, counted in distinct values rather than a run.
			return _spec([[3, PLAIN_TONE], [1, PLAIN_TONE], [6, PLAIN_TONE], [2, PLAIN_TONE], [5, PLAIN_TONE]].slice(0, run),
				"≠", "At least %d dice with no two of them alike." % run)
		"STUN":
			return _spec([[21 - l, MATCH_TONE]], "≥", "The highest die is at least %d." % (21 - l))
		"VENOM":
			return _spec([[13 - l, MATCH_TONE]], "≥", "The highest die is at least %d." % (13 - l))
		"BULWARK", "BASTION", "WAGER":
			return _spec([], "Σ ≤ %d" % (18 + 2 * l), "The whole hand totals %d or less." % (18 + 2 * l))
		"DRAINSTRIKE":
			return _spec([], "Σ ≥ %d" % (45 - 5 * l), "The whole hand totals %d or more." % (45 - 5 * l))
	return _spec([], "ANY HAND", "No condition: this skill fires on every hand.")

static func build_strip(parent: Node, spec: Dictionary, edge: float, tooltip: String) -> Control:
	## Lays a face strip out as a hoverable row.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", maxi(2, int(edge * 0.16)))
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tooltip
	parent.add_child(row)
	var lead := str(spec.get("lead", ""))
	if not lead.is_empty():
		var label := Label.new()
		label.text = lead
		label.add_theme_font_size_override("font_size", maxi(9, int(edge * 0.55)))
		label.add_theme_color_override("font_color", LEAD_TONE)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
	for entry in spec.get("faces", []):
		row.add_child(face(edge, int(entry[0]), Color(entry[1])))
	return row

static func _from_trigger(trigger: Dictionary, l: int, cut: int, carat: int) -> Dictionary:
	## The same strip for a rule written as data, read off its trigger.
	var count: Callable = func(expression: Variant, fallback: int) -> int:
		return GemRules.threshold(expression, carat, cut, l) if expression is Dictionary else fallback
	match str(trigger.get("kind", "always")):
		"pair":
			return _spec(_same(2, 4), "", "Any two dice sharing a value.")
		"two_pairs":
			return _spec(_same(2, 2) + _same(2, 5, OTHER_TONE), "", "Two pairs of different values.")
		"triple":
			return _spec(_same(3, 5), "", "Any three dice sharing a value.")
		"full_house":
			return _spec(_same(3, 5) + _same(2, 2, OTHER_TONE), "", "Three dice of one value and two of another.")
		"straight":
			var length: int = l if false else (5 - (l - 1) / 2 if trigger.get("length", null) is String else count.call(trigger.get("length", null), 3))
			length = clampi(length, 1, 5)
			return _spec(_run(length), "", "A run of %d consecutive values, in any order." % length)
		"parity":
			var odd: bool = str(trigger.get("parity", "even")) == "odd"
			var wanted: int = clampi(count.call(trigger.get("at_least", null), 3), 1, 5)
			var faces: Array = []
			for index in range(wanted):
				faces.append([(1 if odd else 2) + index * 2, RUN_TONE])
			return _spec(faces, "", "At least %d %s results." % [wanted, "odd" if odd else "even"])
		"distinct":
			var wanted_distinct: int = clampi(count.call(trigger.get("at_least", null), 5), 1, 5)
			var distinct_faces: Array = []
			for index in range(wanted_distinct):
				distinct_faces.append([[3, 1, 6, 2, 5][index % 5], PLAIN_TONE])
			return _spec(distinct_faces, "≠", "At least %d dice showing different values." % wanted_distinct)
		"value":
			var wanted_value: int = int(trigger.get("value", 7))
			return _spec([[wanted_value, MATCH_TONE]], "", "At least one die showing %d." % wanted_value)
		"total_at_least":
			var floor_total: int = count.call(trigger.get("amount", null), 0)
			return _spec([], "Σ ≥ %d" % floor_total, "The whole hand totals %d or more." % floor_total)
		"total_at_most":
			var ceiling: int = count.call(trigger.get("amount", null), 0)
			return _spec([], "Σ ≤ %d" % ceiling, "The whole hand totals %d or less." % ceiling)
		"high_at_least":
			var least: int = count.call(trigger.get("amount", null), 0)
			return _spec([[least, MATCH_TONE]], "≥", "The highest die is at least %d." % least)
	return _spec([], "ANY HAND", "No condition: this skill fires on every hand.")

static func _spec(faces: Array, lead: String, note: String) -> Dictionary:
	return {"faces": faces, "lead": lead, "note": note}

static func _same(count: int, value: int, tone: Color = MATCH_TONE) -> Array:
	var faces: Array = []
	for _i in range(count):
		faces.append([value, tone])
	return faces

static func _run(length: int) -> Array:
	var faces: Array = []
	for i in range(length):
		faces.append([i + 1, RUN_TONE])
	return faces
