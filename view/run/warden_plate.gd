extends RefCounted
## A Warden's or a final boss's name, face and two signature moves (review card W2, November
## 2026), shown from the first floor of the stretch that ends at its hall: over the hall on the
## chart, and on the plate of the mouth that leads to it at a landing. The run used to call it
## "the Warden" until the party walked into its hall.

const FaceMarks = preload("res://view/dice/face_marks.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

## Where the bestiary keeps every creature's baked picture.
const PORTRAITS: String = "res://view/creatures/portraits/"

static func signature(key: String) -> Array:
	## Its two signature moves: its trick (the move that is neither a blow nor a guard it shows
	## most faces of, a meddling one first), and its biggest blow (the most damage in one move,
	## the face its dice can be turned to counted too; with no damage written, the blow it shows
	## most). Fewer for a creature with fewer.
	var def: Dictionary = DeepContent.creature(key)
	var moves: Array = def.get("moves", [])
	var faces: Dictionary = {}
	for die in def.get("dice", []):
		for face in die.get("faces", []):
			faces[str(face)] = int(faces.get(str(face), 0)) + 1
	var trick: Dictionary = {}
	for wanted in [["meddle"], ["ready", "mend", "curse", "summon"], ["guard"]]:
		var best: int = -1
		for move in moves:
			var count: int = int(faces.get(str(move.get("name", "")), 0))
			if str(move.get("kind", "")) in wanted and count > best and count > 0:
				best = count
				trick = move
		if not trick.is_empty():
			break
	var blow: Dictionary = {}
	var most: float = 0.0
	for move in moves:
		if str(move.get("kind", "")) != "attack":
			continue
		var total: float = _damage(move)
		if total > most:
			most = total
			blow = move
	if blow.is_empty():
		var shown: int = 0
		for move in moves:
			var count: int = int(faces.get(str(move.get("name", "")), 0))
			if str(move.get("kind", "")) == "attack" and count > shown:
				shown = count
				blow = move
	var out: Array = []
	for move in [trick, blow]:
		if not move.is_empty() and not out.has(move):
			out.append(move)
	return out

static func _damage(move: Dictionary) -> float:
	var total: float = 0.0
	for effect in move.get("effects", []):
		if str(effect.get("kind", "")) == "damage" and (effect.get("amount", 0) is int or effect.get("amount", 0) is float):
			total += float(effect.amount) * float(maxi(1, int(effect.get("repeat", 1))))
	return total

static func move_words(move: Dictionary, mine: Dictionary, depth: int) -> String:
	## What the move does, its numbers weighed as the mine weighs them.
	var scale: Dictionary = DeepDescent.creature_scale(mine, depth)
	return DeepCreatures.move_text({"statuses": {}, "damage_mult": float(scale.get("damage", 1.0)), "hp_scale": float(scale.get("hp", 1.0))}, move)

static func role_words(state: Dictionary, depth: int) -> String:
	## "Warden of the Quarry · the second landing" or "The Quarry's final boss · depth 24".
	var mine_name: String = DeepContent.mine_name(str(state.get("mine", "")))
	if DeepDescent.run_is_boss(state, depth):
		return "%s's final boss · depth %d" % [mine_name, depth]
	return "Warden of %s · depth %d" % [mine_name, depth]

static func fill(box: Control, key: String, state: Dictionary, depth: int, width: float) -> void:
	## Into `box`: its face beside its name and what it guards, then its two moves, each with
	## the mark its dice show for it and what it does.
	var phone: bool = DeepUi.phone
	var def: Dictionary = DeepContent.creature(key)
	var tone: Color = DeepUi.CHAMBER_colorS.get("warden", DeepUi.BAD)
	var head := DeepUi.hbox(box, int(DeepUi.pt(5)) if phone else 10)
	head.name = "WardenHead"
	var face := Face.new(key, DeepUi.pt(26) if phone else 52.0, tone)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(face)
	var named := DeepUi.vbox(head, 0)
	named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	named.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(named, str(def.get("name", key.capitalize())), 15 if phone else 20, tone.lightened(0.3))
	DeepUi.label(named, role_words(state, depth), 11 if phone else 12, DeepUi.MUTED)
	var mine: Dictionary = DeepDescent.mine_of(state)
	for move in signature(key):
		var line := DeepUi.hbox(box, int(DeepUi.pt(4)) if phone else 8)
		line.name = "Move"
		var mark_edge: float = DeepUi.glyph_px(13) if phone else 22.0
		var mark := TextureRect.new()
		mark.custom_minimum_size = Vector2(mark_edge, mark_edge)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var mark_name: String = str(move.get("mark", ""))
		if not mark_name.is_empty() and FaceMarks.known(mark_name):
			mark.texture = FaceMarks.texture(mark_name)
		mark.modulate = DeepUi.BAD.lightened(0.25) if str(move.get("kind", "")) == "attack" else DeepUi.ACCENT
		line.add_child(mark)
		var said := DeepUi.vbox(line, 0)
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(said, str(move.get("name", "")), 12 if phone else 14, DeepUi.PAPER).add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.wrap(said, move_words(move, mine, depth), 11 if phone else 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, width - mark_edge - (DeepUi.pt(4) if phone else 8.0))

static func short_line(key: String) -> String:
	## "The Foreman · Bury · Blast", for a line of text.
	var parts: Array = [str(DeepContent.creature(key).get("name", key.capitalize()))]
	for move in signature(key):
		parts.append(str(move.get("name", "")))
	return " · ".join(parts)

static func portrait(key: String) -> Texture2D:
	var path: String = PORTRAITS + key.to_lower() + ".png"
	return load(path) if ResourceLoader.exists(path) else null

class Face extends Control:
	## The creature's baked picture in a ring, the way a delver's face sits in theirs.
	var texture: Texture2D = null
	var tone: Color
	func _init(key: String, edge: float, ring: Color) -> void:
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tone = ring
		if DisplayServer.get_name() != "headless":
			texture = load("res://view/run/warden_plate.gd").portrait(key)
	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 1.5
		draw_circle(centre, radius, Color(0.05, 0.05, 0.07))
		if texture != null:
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for index in range(40):
				var angle: float = TAU * float(index) / 40.0
				var unit := Vector2(cos(angle), sin(angle))
				points.append(centre + unit * radius)
				uvs.append(Vector2(0.5, 0.5) + unit * 0.5)
			draw_colored_polygon(points, Color.WHITE, uvs, texture)
		else:
			var icons: Script = load("res://view/gems/gem_icons.gd")
			var crown: Texture2D = icons.texture("crown", icons.baked_size(radius * 1.6))
			draw_texture_rect(crown, Rect2(centre - Vector2.ONE * radius * 0.6, Vector2.ONE * radius * 1.2), false, tone)
		draw_arc(centre, radius, 0, TAU, 40, tone, 2.0, true)
