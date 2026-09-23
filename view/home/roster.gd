extends RefCounted
## The lapidaries as people: a portrait frame and the roster tile built around it.
##
## No headshots are drawn yet, so the portrait is a placeholder that already behaves like
## the real thing will: a plate lit in the character's Birthstone tint and a bust in
## silhouette. The Birthstone itself sits at the end of their sockets, not on the portrait.
## When the busts arrive they replace the silhouette and take the same `mood` the plate
## carries (idle, rolling, wince, bloodied, critical, birthstone, downed, victory).

const GemMesh = preload("res://view/gems/gem_mesh.gd")

const MOODS: Array = ["idle", "rolling", "wince", "bloodied", "critical", "birthstone", "downed", "victory"]
const ORDINALS: Array = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"]

static func unlock_hint(key: String) -> String:
	## What earns a locked lapidary: Wardens, in the pack's order.
	var order: int = int(DeepContent.character(key).get("unlock_order", 0))
	if order <= 0:
		return ""
	return "Beat your %s Warden" % (ORDINALS[order - 1] if order - 1 < ORDINALS.size() else str(order) + "th")

static func wardens_beaten(profile: Dictionary) -> int:
	var count: int = 0
	for key in profile.get("mines", {}):
		count += profile.mines[key].get("wardens", []).size()
	return count

class Portrait extends Control:
	## A character's plate: tint and silhouette. Locked plates go grey and wear a lock;
	## the one going down wears a crown.
	var key: String = ""
	var locked: bool = false
	var selected: bool = false
	var chosen: bool = false
	var mood: String = "idle"
	var tint: Color = Color("e2b23a")

	func _init(character_key: String, edge: Vector2, is_locked: bool = false, is_selected: bool = false, is_chosen: bool = false) -> void:
		key = character_key
		locked = is_locked
		selected = is_selected
		chosen = is_chosen
		custom_minimum_size = edge
		size = edge
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_PASS
		var stone: Dictionary = DeepStone.birthstone(key)
		if not stone.is_empty():
			tint = GemMesh.tint(stone)
		if locked:
			var lock := DeepUi.icon(self, "lock", edge.x * 0.22, DeepUi.DIM, "Locked")
			lock.position = Vector2(edge.x * 0.39, edge.y * 0.30)
		elif chosen:
			var crown := DeepUi.icon(self, "crown", edge.x * 0.16, DeepUi.ACCENT, "Going down as this lapidary")
			crown.position = Vector2(edge.x - edge.x * 0.16 - 8.0, 8.0)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var border: Color = DeepUi.ACCENT if selected else (Color(tint, 0.55) if not locked else DeepUi.LINE)
		var plate := DeepUi.raised(Color(0.05, 0.055, 0.08, 0.96), border, 14, 0, 0.35)
		if selected:
			plate.set_border_width_all(2)
		draw_style_box(plate, Rect2(Vector2.ZERO, size))
		var light: Color = tint if not locked else DeepUi.DIM
		var reach: float = w * 1.5
		draw_texture_rect(DeepUi.glow_texture(), Rect2(Vector2(w * 0.5 - reach * 0.5, h * 0.42 - reach * 0.5), Vector2(reach, reach)), false, Color(light, 0.24 if not locked else 0.08))
		## The bust: shoulders, neck, head. A silhouette until the busts are drawn.
		var body: Color = DeepUi.SLATE_HI if not locked else DeepUi.SLATE
		var rim: Color = light.lightened(0.15)
		## The shoulders are the top half of an ellipse standing on the plate's foot, so the
		## polygon is convex and closes along the bottom edge on its own.
		var shoulders := PackedVector2Array()
		for index in range(25):
			var angle: float = PI + PI * float(index) / 24.0
			shoulders.append(Vector2(w * 0.5 + cos(angle) * w * 0.47, h + sin(angle) * h * 0.36))
		draw_colored_polygon(shoulders, body)
		draw_polyline(shoulders, Color(rim, 0.7), 2.0, true)
		draw_rect(Rect2(w * 0.44, h * 0.50, w * 0.12, h * 0.17), body)
		var head := Vector2(w * 0.5, h * 0.40)
		draw_circle(head, w * 0.17, body)
		draw_arc(head, w * 0.17, 0, TAU, 40, Color(rim, 0.75), 2.0, true)
		if mood in ["bloodied", "critical"] and not locked:
			draw_arc(head, w * 0.17, PI * 1.1, PI * 1.9, 20, Color(DeepUi.BAD, 0.8), 3.0, true)

static func tile(parent: Node, key: String, selected: bool, chosen: bool, unlocked: bool, fresh: bool) -> PanelContainer:
	## One lapidary in the roster strip: portrait, name, title, and their standing.
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
