extends RefCounted
## The flat language of dice and patterns: die palettes, face-on silhouettes, the little
## face controls a requirement is drawn with, and the pictograph row for a trigger.
##
## `DeepPatterns.describe()` says what a trigger needs; this turns that into a mark, a
## label and, where it helps, a strip of example faces. Nothing here evaluates a hand.

const GemIcons = preload("res://view/gems/gem_icons.gd")

const NEED_TONE := Color("e6e9f0")
const MATCH_TONE := Color("ffcf7a")
const OTHER_TONE := Color("76b6ff")
const RUN_TONE := Color("6fe3b0")
const PLAIN_TONE := Color("d8dce6")
const LEAD_TONE := Color("8f9fb5")

## Every die's body and edge color, keyed the way the content keys them. The 3D view
## reads it too, so a solid and its icon never disagree.
const DIE_PALETTE := {
	"D2": ["e0bc70", "77603b"], "D3": ["91d0de", "38566f"],
	"D4": ["d9a05b", "6d4a20"], "D6": ["e6e2d4", "7c7565"], "D8": ["5fc7bd", "235e5a"],
	"D10": ["6fa8ff", "27467f"], "D12": ["b98bff", "4a2f7a"], "D20": ["ff8672", "7a2b26"],
	"D16": ["db8bc4", "70355f"], "D24": ["efb471", "86542e"], "D30": ["82d39b", "326544"],
	"D40": ["78cce4", "305e78"], "D50": ["a4b8ef", "47577b"], "D60": ["d8a5ed", "6d437f"], "D100": ["f4d98c", "89703c"],
	"PAIRED_D6": ["ff9cc4", "7d2f52"], "ODD_D6": ["8fd8ff", "2b5b7a"], "EVEN_D6": ["b7e06a", "4d6b22"],
	"SEVENS_D8": ["ffd166", "806018"], "SPLIT_D12": ["ff86e0", "7a2668"], "WILD_D6": ["f3e7ff", "6d4a9a"],
	"EXPLODING_D6": ["ff9d5c", "8a3a12"], "LOCKED_D8": ["9aa7b8", "3c4656"], "MIRROR_D6": ["dfe9f5", "5a6b80"],
	"HOLLOW_D10": ["8c98a8", "2e3644"], "GEM_D8": ["ffe08a", "8a6a10"]}

## What a special face is tinted toward on the solid, and the mark drawn on it.
const FACE_KINDS := {
	"wild": {"tint": "ffffff", "text": "★"}, "gem": {"tint": "ffe08a", "text": "◆"}, "exploding": {"tint": "ff7a3c", "text": "!"},
	"locked": {"tint": "6f7c92", "text": "⌂"}, "mirror": {"tint": "ffffff", "text": "≡"}, "blank": {"tint": "3a4150", "text": ""}}

## The face-on silhouette of each solid, in unit space, with where its numeral sits.
const SILHOUETTES := {
	"D3": {"points": [Vector2(0.50, 0.02), Vector2(0.83, 0.24), Vector2(0.83, 0.76), Vector2(0.50, 0.98), Vector2(0.17, 0.76), Vector2(0.17, 0.24)], "font": 0.50, "middle": 0.50},
	"D4": {"points": [Vector2(0.50, 0.04), Vector2(0.97, 0.92), Vector2(0.03, 0.92)], "font": 0.40, "middle": 0.64},
	"D6": {"points": [Vector2(0.07, 0.07), Vector2(0.93, 0.07), Vector2(0.93, 0.93), Vector2(0.07, 0.93)], "font": 0.58, "middle": 0.50},
	"D8": {"points": [Vector2(0.50, 0.02), Vector2(0.97, 0.50), Vector2(0.50, 0.98), Vector2(0.03, 0.50)], "font": 0.46, "middle": 0.52},
	"D10": {"points": [Vector2(0.50, 0.02), Vector2(0.96, 0.36), Vector2(0.50, 0.98), Vector2(0.04, 0.36)], "font": 0.44, "middle": 0.48},
	"D12": {"points": [Vector2(0.50, 0.02), Vector2(0.97, 0.36), Vector2(0.79, 0.95), Vector2(0.21, 0.95), Vector2(0.03, 0.36)], "font": 0.48, "middle": 0.56},
	"D16": {"points": [Vector2(0.50, 0.02), Vector2(0.98, 0.43), Vector2(0.50, 0.98), Vector2(0.02, 0.43)], "font": 0.44, "middle": 0.50},
	"D24": {"points": [Vector2(0.50, 0.02), Vector2(0.96, 0.32), Vector2(0.83, 0.88), Vector2(0.25, 0.97), Vector2(0.04, 0.40)], "font": 0.48, "middle": 0.53},
	"D30": {"points": [Vector2(0.50, 0.02), Vector2(0.97, 0.50), Vector2(0.50, 0.98), Vector2(0.03, 0.50)], "font": 0.46, "middle": 0.52},
	"D20": {"points": [Vector2(0.50, 0.02), Vector2(0.95, 0.27), Vector2(0.95, 0.73), Vector2(0.50, 0.98), Vector2(0.05, 0.73), Vector2(0.05, 0.27)], "font": 0.50, "middle": 0.52}}

static func palette(key: String) -> Dictionary:
	var entry: Array = DIE_PALETTE.get(key.to_upper(), [])
	if entry.is_empty():
		return {"body": Color("d8dce6"), "edge": Color("545c6b")}
	return {"body": Color(str(entry[0])), "edge": Color(str(entry[1]))}

static func face_kind_tint(kind: String) -> Color:
	return Color(str(FACE_KINDS.get(kind, {}).get("tint", "ffffff")))

static func face_text(value: int, kind: String = "plain") -> String:
	## What a face shows: its number, or the mark of what it does instead.
	match kind:
		"plain", "locked", "exploding", "gem":
			var mark: String = str(FACE_KINDS.get(kind, {}).get("text", ""))
			return str(value) + (mark if kind != "plain" else "")
		"blank":
			return ""
	return str(FACE_KINDS.get(kind, {}).get("text", str(value)))

static func silhouette(shape: String) -> Dictionary:
	var key := shape.to_upper()
	if key in ["D2", "D40", "D50", "D60", "D100"]:
		var points: Array = []
		var corners := 24 if key == "D2" else 10
		for i in corners:
			var angle := TAU * float(i) / corners - PI * 0.5
			points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.47)
		return {"shape": key, "points": points, "font": 0.50, "middle": 0.50}
	var outline: Dictionary = SILHOUETTES.get(key, SILHOUETTES["D6"])
	return {"shape": key if SILHOUETTES.has(key) else "D6", "points": outline.points, "font": outline.font, "middle": outline.middle}

static func face(edge: float, value: int, tone: Color, shape := "D6", filled := false, text: String = "") -> Face:
	return Face.new(edge, value, tone, silhouette(shape), filled, text)

class Face extends Control:
	## One die face drawn flat: the solid's own silhouette with its value on it.
	var value := 1
	var tone := Color("d8dce6")
	var shape := "D6"
	var text := ""
	var _points: Array = []
	var _font_scale := 0.58
	var _middle := 0.5
	var _fill := Color("d8dce6")
	var _edge := Color("d8dce6")
	var _ink := Color("d8dce6")

	func _init(edge: float, face_value: int, face_tone: Color, outline: Dictionary, filled := false, label: String = "") -> void:
		value = face_value
		tone = face_tone
		text = label if not label.is_empty() else str(face_value)
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
		if text.is_empty():
			return
		var font := ThemeDB.fallback_font
		var scale: float = _font_scale * minf(1.0, 1.4 / maxf(1.0, text.length()))
		var font_size := maxi(7, int(size.y * scale))
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := size.y * _middle + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2((size.x - measured.x) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _ink)

# --- triggers as pictographs ------------------------------------------------------------

static func glyph_for(described: Dictionary) -> String:
	## The mark a described trigger is drawn with, from the glyphs `gem_icons.gd` knows.
	match str(described.get("mark", described.get("kind", ""))):
		"read_high": return "high"
		"read_low": return "low"
		"pair": return "pair"
		"two_pair": return "two_pairs"
		"triple": return "triple"
		"quad", "quint": return "quad"
		"full_house": return "full_house"
		"straight": return "straight%d" % clampi(int(described.get("need", 3)), 3, 5)
		"odd": return "odd"
		"even": return "even"
		"distinct": return "distinct"
		"value": return "face"
		"at_most": return "low"
		"at_least", "high_pct_at_least": return "peak"
		"total_pct_at_least": return "total_high"
		"total_pct_at_most": return "total_low"
		"held": return "lock"
		"rerolled": return "reroll"
		"resonance": return "resonance"
		"low_count": return "low"
		"crowns", "crowns_at_most": return "peak"
		"skip_straight": return "even"
		"distinct_dominant": return "distinct"
	return "carat"

static func build(parent: Node, described: Dictionary, edge: float, tint: Color = NEED_TONE, tooltip: String = "") -> HBoxContainer:
	## The mark and its label as one hoverable row.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", maxi(2, int(edge * 0.2)))
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tooltip if not tooltip.is_empty() else str(described.get("words", ""))
	parent.add_child(row)
	var glyph := GemIcons.glyph(row, glyph_for(described), edge, tint, row.tooltip_text)
	glyph.mouse_filter = Control.MOUSE_FILTER_PASS
	var label := str(described.get("label", ""))
	if not label.is_empty():
		var words := Label.new()
		words.text = label
		words.add_theme_font_size_override("font_size", maxi(9, int(edge * 0.62)))
		words.add_theme_color_override("font_color", tint)
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(words)
	return row

# --- a Birthstone whose tiers count more of one die -------------------------------------

## Tier kinds that only ask for more of one kind of die, and the die each is drawn with:
## matching dice for a set, a die on its top face for a crown.
const LADDER_DICE := {"pair": "die", "triple": "die", "quad": "die", "quint": "die", "crowns": "crown_die"}

static func ladder_die(tiers: Array) -> String:
	## The die a Birthstone's tiers climb with, or "" when they do not: two or more tiers
	## must count the same die, so they read as one row of five dice instead of marks that
	## run out of shapes. Any other tier (High Roller's Bust) keeps its own mark beside it.
	var die: String = ""
	var rungs: int = 0
	for tier in tiers:
		var mark: String = str(LADDER_DICE.get(str(tier.get("trigger", {}).get("kind", "")), ""))
		if mark.is_empty():
			continue
		if not die.is_empty() and mark != die:
			return ""
		die = mark
		rungs += 1
	return die if rungs >= 2 else ""

static func ladder_rung(tier: Dictionary, die: String) -> int:
	## How many of `die` this tier needs, or 0 when it is not a rung of that ladder.
	var trigger: Dictionary = tier.get("trigger", {})
	var kind: String = str(trigger.get("kind", ""))
	if die.is_empty() or str(LADDER_DICE.get(kind, "")) != die:
		return 0
	if DeepPatterns.SET_SIZES.has(kind):
		return int(DeepPatterns.SET_SIZES[kind])
	return clampi(int(DeepPatterns.describe(trigger, 0).get("need", 0)), 1, 5)

static func build_ladder(parent: Node, tiers: Array, die: String, lit: int, edge: float, on: Color, off: Color, notes: Array = []) -> HBoxContainer:
	## Five dice, the first `lit` of them solid: the dice the hand has that count, or the
	## number a tier needs. Each die names, on hover, the smallest tier that reaches it.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	for count in range(1, 6):
		var reached: int = -1
		for index in range(tiers.size()):
			var needs: int = ladder_rung(tiers[index], die)
			if needs >= count and (reached < 0 or needs < ladder_rung(tiers[reached], die)):
				reached = index
		var tooltip: String = ""
		if reached >= 0:
			tooltip = "%s: %s" % [str(tiers[reached].get("name", "")), str(tiers[reached].get("text", ""))]
			var note: String = str(notes[reached]) if reached < notes.size() else ""
			if not note.is_empty():
				tooltip += "\n" + note
		GemIcons.glyph(row, die + "_solid" if count <= lit else die, edge, on if count <= lit else off, tooltip)
	return row

static func strip(described: Dictionary) -> Dictionary:
	## Example faces that would satisfy the trigger: [value, tone] pairs, with a lead symbol.
	var kind := str(described.get("kind", "always"))
	var need := int(described.get("need", 0))
	match kind:
		"pair": return _spec(_same(2, maxi(need, 4)), "", described.words)
		"two_pair": return _spec(_same(2, maxi(need, 2)) + _same(2, maxi(need + 3, 5), OTHER_TONE), "", described.words)
		"triple": return _spec(_same(3, maxi(need, 5)), "", described.words)
		"quad": return _spec(_same(4, maxi(need, 5)), "", described.words)
		"quint": return _spec(_same(5, maxi(need, 5)), "", described.words)
		"full_house": return _spec(_same(3, maxi(need, 5)) + _same(2, 2, OTHER_TONE), "", described.words)
		"straight": return _spec(_run(clampi(need, 1, 5)), "", described.words)
		"odd":
			var faces: Array = []
			for index in range(clampi(need, 1, 5)):
				faces.append([1 + index * 2, RUN_TONE])
			return _spec(faces, "", described.words)
		"even":
			var faces: Array = []
			for index in range(clampi(need, 1, 5)):
				faces.append([2 + index * 2, RUN_TONE])
			return _spec(faces, "", described.words)
		"distinct":
			var faces: Array = []
			for index in range(clampi(need, 1, 5)):
				faces.append([[3, 1, 6, 2, 5][index], PLAIN_TONE])
			return _spec(faces, "≠", described.words)
		"value":
			return _spec([[int(str(described.get("label", "7")).get_slice("/", 0).get_slice(" ", 0)), MATCH_TONE]], "", described.words)
		"at_most": return _spec([[need, MATCH_TONE]], "≤", described.words)
		"at_least": return _spec([[need, MATCH_TONE]], "≥", described.words)
		"total_pct_at_least": return _spec([], "Σ ≥ %d%%" % need, described.words)
		"total_pct_at_most": return _spec([], "Σ ≤ %d%%" % need, described.words)
		"high_pct_at_least": return _spec([], "▲ ≥ %d%%" % need, described.words)
		"held": return _spec([], "held ×%d" % need, described.words)
		"rerolled": return _spec([], "rerolled ×%d" % need, described.words)
		"low_count":
			var faces: Array = []
			for index in range(clampi(need, 1, 5)):
				faces.append([[1, 2, 1, 3, 2][index], MATCH_TONE])
			return _spec(faces, "▼", described.words)
		"crowns":
			var faces: Array = []
			for index in range(clampi(need, 1, 5)):
				faces.append([6, MATCH_TONE])
			return _spec(faces, "▲", described.words)
		"crowns_at_most": return _spec([], "no ▲", described.words)
		"skip_straight":
			var faces: Array = []
			for index in range(clampi(need, 1, 5)):
				faces.append([2 + index * 2, RUN_TONE])
			return _spec(faces, "≠", described.words)
		"distinct_dominant":
			var faces: Array = []
			for index in range(clampi(need, 1, 5) - 1):
				faces.append([index + 1, PLAIN_TONE])
			faces.append([20, MATCH_TONE])
			return _spec(faces, "≠", described.words)
		"resonance": return _spec([], "resonance %d" % need, described.words)
	return _spec([], "EVERY HAND", described.words)

static func build_strip(parent: Node, spec: Dictionary, edge: float, tooltip: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", maxi(2, int(edge * 0.16)))
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tooltip if not tooltip.is_empty() else str(spec.get("note", ""))
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
