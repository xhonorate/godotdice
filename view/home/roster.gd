extends RefCounted
## The delvers as people: a portrait frame and the roster tile built around it.
##
## Each delver has a face for each of eight moods (idle, rolling, wince, bloodied, critical,
## birthstone, downed, victory), drawn at 512 square under
## `view/home/delvers/<delver>/<mood>.png`. The plate is lit in their Birthstone's tint behind
## the face. A delver with no faces drawn is shown by their Birthstone instead.

const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

const MOODS: Array = ["idle", "rolling", "wince", "bloodied", "critical", "birthstone", "downed", "victory"]
const ORDINALS: Array = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"]

static func face(key: String, mood: String = "idle") -> Texture2D:
	## A delver's face in a mood, or null when that delver has none drawn.
	return Portrait.face(key, mood)

static func resting_mood(unit: Dictionary) -> String:
	## The face a delver wears with nothing happening to them: what their health says.
	if bool(unit.get("downed", false)) or int(unit.get("hp", 1)) <= 0:
		return "downed"
	var ratio: float = float(unit.get("hp", 0)) / float(maxi(1, int(unit.get("max_hp", 1))))
	if ratio < 0.25:
		return "critical"
	if ratio < 0.5:
		return "bloodied"
	return "idle"

static func unlock_hint(key: String) -> String:
	## What earns a locked delver: the final boss of the mine above the one they belong to.
	var mine: String = DeepProfile.lapidary_boss_mine(key)
	if mine.is_empty():
		return ""
	return "Joins when the boss of %s falls" % DeepContent.mine_name(mine)

static func wardens_beaten(profile: Dictionary) -> int:
	var count: int = 0
	for key in profile.get("mines", {}):
		count += profile.mines[key].get("wardens", []).size()
	return count

class Portrait extends Control:
	## A character's plate: their face in the mood given, over a glow of their Birthstone's
	## tint. Small plates close in on the face, so it still reads at the size of a word; large
	## ones show the whole bust standing on the plate's bottom edge. Locked plates go dark and
	## wear a lock; the one going down wears a crown. Key and mood can change after it is built,
	## so a panel that follows a player keeps one plate and only swaps the face.
	## A locked delver's face (or stone) multiplied by this: a flat shadow, nearly black.
	const SILHOUETTE := Color(0.02, 0.022, 0.032, 1.0)
	## The plate behind a locked delver: lit, so their shadow reads against it.
	const BACKLIT := Color(0.13, 0.15, 0.21, 0.96)
	var key: String = "":
		set(value):
			if value == key:
				return
			key = value
			_dress()
	var locked: bool = false
	var selected: bool = false
	var chosen: bool = false
	var mood: String = "idle":
		set(value):
			if value == mood:
				return
			mood = value
			_turn_to(_face_for(mood))
	## Drawn as a disc rather than a cut plate: the dock's vitals ring stands round it.
	var round: bool = false:
		set(value):
			round = value
			queue_redraw()
	## A frame color of its own, over the Birthstone's (a seat's, in a party); clear for none.
	var ring: Color = Color(0, 0, 0, 0):
		set(value):
			ring = value
			queue_redraw()
	var tint: Color = Color("e2b23a")
	var _texture: Texture2D = null
	## The face being turned from, faded out under the new one.
	var _from: Texture2D = null
	var _fade: float = 1.0
	var _fading: Tween = null
	## The Birthstone, standing in for a delver with no faces drawn.
	var _thumb: Control = null
	## Every face read so far, by path (null for one not drawn), so a mood swaps in at once.
	static var _faces: Dictionary = {}

	static func face(character_key: String, which: String = "idle") -> Texture2D:
		var path: String = "res://view/home/delvers/%s/%s.png" % [character_key.to_lower(), which]
		if not _faces.has(path):
			_faces[path] = load(path) if ResourceLoader.exists(path) else null
		return _faces[path]

	func _init(character_key: String, edge: Vector2, is_locked: bool = false, is_selected: bool = false, is_chosen: bool = false) -> void:
		locked = is_locked
		selected = is_selected
		chosen = is_chosen
		custom_minimum_size = edge
		size = edge
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_PASS
		## Drawn well under the 512 it was painted at: read from its mipmaps, or it shimmers.
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		key = character_key
		if locked:
			var lock := DeepUi.icon(self, "lock", edge.x * 0.22, DeepUi.PAPER, "Locked")
			lock.position = Vector2(edge.x * 0.39, edge.y * 0.36)
		elif chosen:
			var crown := DeepUi.icon(self, "crown", edge.x * 0.16, DeepUi.ACCENT, "Going down as this delver")
			crown.position = Vector2(edge.x - edge.x * 0.16 - 8.0, 8.0)

	func _face_for(which: String) -> Texture2D:
		if key.is_empty():
			return null
		var found: Texture2D = face(key, which)
		return found if found != null else face(key, "idle")

	func _dress() -> void:
		## A new delver on the plate: their tint, and their face or, failing one, their stone.
		var stone: Dictionary = DeepStone.birthstone(key) if not key.is_empty() else {}
		tint = GemMesh.tint(stone) if not stone.is_empty() else Color("e2b23a")
		_texture = _face_for(mood)
		_from = null
		_fade = 1.0
		if _thumb != null:
			_thumb.queue_free()
			_thumb = null
		if _texture == null and not stone.is_empty():
			var edge: Vector2 = custom_minimum_size
			var reach: float = minf(edge.x, edge.y) * 0.7
			_thumb = Thumbs.GemThumb.new(stone, reach)
			_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_thumb.position = Vector2((edge.x - reach) * 0.5, (edge.y - reach) * 0.46)
			if locked:
				_thumb.modulate = SILHOUETTE
			add_child(_thumb)
			move_child(_thumb, 0)
		queue_redraw()

	func _turn_to(next: Texture2D) -> void:
		## A change of face: the new one fades up over the old in a blink, quick enough that a
		## flinch still reads as one.
		if next == _texture:
			return
		if _fading != null and _fading.is_valid():
			_fading.kill()
		_from = _texture
		_texture = next
		_fade = 1.0
		if _from != null and not DeepUi.headless() and is_visible_in_tree():
			_fade = 0.0
			_fading = create_tween()
			_fading.tween_method(func(t: float) -> void:
				_fade = t
				queue_redraw(), 0.0, 1.0, 0.12)
		queue_redraw()

	func _corner() -> int:
		## The kit's cut corner, kept in proportion: a plate the size of a word gets a nick, not
		## a corner that eats its face.
		return clampi(int(minf(size.x, size.y) * 0.14), 3, 14)

	func _draw() -> void:
		if round:
			_draw_round()
			return
		var w: float = size.x
		var h: float = size.y
		var whole := Rect2(Vector2.ZERO, size)
		var border: Color = ring if ring.a > 0.0 else (DeepUi.ACCENT if selected else (Color(tint, 0.55) if not locked else DeepUi.LINE))
		var corner: int = _corner()
		## A locked delver stands as a shadow against a lit plate, so the plate is lighter.
		var plate := DeepUi.raised(Color(0.05, 0.055, 0.08, 0.96) if not locked else BACKLIT, border, corner, 0, 0.35)
		var heavy: bool = selected or ring.a > 0.0
		if heavy:
			plate.set_border_width_all(2)
		if minf(w, h) < 40.0:
			plate.shadow_size = 0
		draw_style_box(plate, whole)
		var light: Color = tint if not locked else DeepUi.DIM
		var reach: float = w * 1.5
		draw_texture_rect(DeepUi.glow_texture(), Rect2(Vector2(w * 0.5 - reach * 0.5, h * 0.42 - reach * 0.5), Vector2(reach, reach)), false, Color(light, 0.24 if not locked else 0.6))
		if _texture == null:
			## No face: a ring of the plate's light under the stone standing in for one.
			var stand: float = minf(w, h) * 0.7
			draw_arc(Vector2(w * 0.5, (h - stand) * 0.46 + stand * 0.5), stand * 0.55, 0, TAU, 48, Color(light, 0.35 if not locked else 0.12), 2.0, true)
			return
		var inside := Rect2(Vector2(1, 1), size - Vector2(2, 3)) if not heavy else whole.grow(-2.0)
		## Locked: the face as a flat silhouette, its colors multiplied down to the plate's dark.
		var shade: Color = SILHOUETTE if locked else Color.WHITE
		if _from != null and _fade < 1.0:
			_draw_face(_from, inside, corner - 1, shade)
		_draw_face(_texture, inside, corner - 1, Color(shade, shade.a * _fade))
		## The frame again over the face's edge, so the cut corners stay crisp.
		var edge := plate.duplicate() as StyleBoxFlat
		edge.draw_center = false
		edge.shadow_size = 0
		draw_style_box(edge, whole)

	func _draw_round() -> void:
		## The face in a disc: the plate, the Birthstone's light under it, the face cut to a
		## circle and the frame over its edge.
		var radius: float = minf(size.x, size.y) * 0.5
		var centre: Vector2 = size * 0.5
		var light: Color = tint if not locked else DeepUi.DIM
		draw_circle(centre, radius, Color(0.05, 0.055, 0.08, 1.0))
		var reach: float = radius * 2.6
		draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(light, 0.22))
		var border: Color = ring if ring.a > 0.0 else Color(tint, 0.55)
		if _texture == null:
			draw_arc(centre, radius * 0.55, 0, TAU, 48, Color(light, 0.35), 2.0, true)
			draw_arc(centre, radius - 1.0, 0, TAU, 64, border, 2.0, true)
			return
		var shade: Color = SILHOUETTE if locked else Color.WHITE
		if _from != null and _fade < 1.0:
			_draw_disc(_from, centre, radius - 2.0, shade)
		_draw_disc(_texture, centre, radius - 2.0, Color(shade, shade.a * _fade))
		draw_arc(centre, radius - 1.0, 0, TAU, 64, border, 2.0, true)

	func _draw_disc(picture: Texture2D, centre: Vector2, radius: float, shade: Color) -> void:
		## The face close in on the eyes, cut to a circle: a polygon of many sides with the
		## picture mapped onto it.
		var zoom: float = 1.0 if locked else 1.3
		var side: float = 1.0 / zoom
		var top: float = clampf(0.44 - side * 0.5, 0.0, 1.0 - side)
		var source := Rect2(Vector2(0.5 - side * 0.5, top), Vector2(side, side))
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in range(48):
			var angle: float = TAU * float(i) / 48.0
			var at: Vector2 = centre + Vector2.from_angle(angle) * radius
			points.append(at)
			uvs.append(source.position + (at - (centre - Vector2(radius, radius))) / (radius * 2.0) * source.size)
		draw_colored_polygon(points, shade, uvs, picture)

	func _draw_face(picture: Texture2D, into: Rect2, corner: int, shade: Color) -> void:
		## The face cut to the plate's shape. The smaller the plate, the closer it comes in on
		## the face (from the whole bust at 120 and over, to the face alone at about 36).
		## A silhouette is known by its outline, so a locked delver always shows the whole bust.
		var zoom: float = 1.0 if locked else clampf(remap(minf(into.size.x, into.size.y), 120.0, 36.0, 1.0, 1.65), 1.0, 1.65)
		var closeness: float = (zoom - 1.0) / 0.65
		var side: float = 1.0 / zoom
		var span := Vector2(side, side)
		if into.size.x < into.size.y:
			span.x = side * into.size.x / into.size.y
		else:
			span.y = side * into.size.y / into.size.x
		## The bust stands on the plate's bottom edge; a close-up centres on the eyes.
		var top: float = clampf(lerpf(1.0 - span.y, 0.44 - span.y * 0.5, closeness), 0.0, 1.0 - span.y)
		var source := Rect2(Vector2(0.5 - span.x * 0.5, top), span)
		var c: float = float(maxi(0, corner))
		var p: Vector2 = into.position
		var s: Vector2 = into.size
		var points := PackedVector2Array([p + Vector2(c, 0), p + Vector2(s.x - c, 0), p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
			p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0, s.y - c), p + Vector2(0, c)])
		var uvs := PackedVector2Array()
		for point in points:
			uvs.append(source.position + (point - p) / s * source.size)
		draw_colored_polygon(points, shade, uvs, picture)

static func tile(parent: Node, key: String, selected: bool, chosen: bool, unlocked: bool, fresh: bool) -> PanelContainer:
	## One delver in the roster strip: portrait, name, title, and their standing.
	var character: Dictionary = DeepContent.character(key)
	var stone: Dictionary = DeepStone.birthstone(key)
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var box := PanelContainer.new()
	var style := DeepUi.raised(Color(0.06, 0.07, 0.1, 0.9) if unlocked else Color(0.04, 0.045, 0.06, 0.8), DeepUi.ACCENT if selected else (Color(tint, 0.35) if unlocked else DeepUi.LINE), 12, 10, 0.35)
	if selected:
		style.set_border_width_all(2)
		style.shadow_color = Color(DeepUi.ACCENT, 0.3)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(140, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.tooltip_text = str(character.get("text", "")) if unlocked else "Locked. " + unlock_hint(key) + "."
	parent.add_child(box)
	var column := DeepUi.vbox(box, 5)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	var frame := DeepUi.center(column)
	frame.add_child(Portrait.new(key, Vector2(112, 128), not unlocked, selected, chosen))
	DeepUi.title(column, str(character.get("name", key)), 15, DeepUi.ACCENT_HI if selected else (DeepUi.PAPER if unlocked else DeepUi.DIM), HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.label(column, str(character.get("title", "")), 11, DeepUi.MUTED if unlocked else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var foot := DeepUi.hbox(column, 4)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if not unlocked:
		DeepUi.stat(foot, "lock", "Locked", DeepUi.DIM, 10)
	elif chosen:
		DeepUi.pill(foot, "check", "Going down", DeepUi.GOOD, 10)
	elif fresh:
		DeepUi.pill(foot, "star", "New", DeepUi.ACCENT, 10)
	else:
		DeepUi.stat(foot, "heart", "%d" % int(character.get("hp", 0)), DeepUi.HP, 10)
	DeepUi.juice(box, 1.04)
	return box
