extends RefCounted
## The delvers as people: a portrait frame and the roster tile built around it.
##
## No headshots are drawn yet, so each delver is shown by their Birthstone: the plate is lit
## in its tint and the stone itself sits in the middle of it. When the busts arrive they
## replace the stone and take the same `mood` the plate carries (idle, rolling, wince,
## bloodied, critical, birthstone, downed, victory).

const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

const MOODS: Array = ["idle", "rolling", "wince", "bloodied", "critical", "birthstone", "downed", "victory"]
const ORDINALS: Array = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"]

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
			## The Birthstone stands in for the face until the busts are drawn.
			var reach: float = minf(edge.x, edge.y) * 0.7
			var thumb := Thumbs.GemThumb.new(stone, reach)
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumb.position = Vector2((edge.x - reach) * 0.5, (edge.y - reach) * 0.46)
			if locked:
				thumb.modulate = Color(0.32, 0.33, 0.4, 0.9)
			add_child(thumb)
		if locked:
			var lock := DeepUi.icon(self, "lock", edge.x * 0.22, DeepUi.DIM, "Locked")
			lock.position = Vector2(edge.x * 0.39, edge.y * 0.30)
		elif chosen:
			var crown := DeepUi.icon(self, "crown", edge.x * 0.16, DeepUi.ACCENT, "Going down as this delver")
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
		## A ring of the plate's light under the stone, red at its rim when they are hurt.
		var face: float = minf(w, h) * 0.7
		var heart := Vector2(w * 0.5, (h - face) * 0.46 + face * 0.5)
		var ring: float = face * 0.55
		draw_arc(heart, ring, 0, TAU, 48, Color(light, 0.35 if not locked else 0.12), 2.0, true)
		if mood in ["bloodied", "critical"] and not locked:
			draw_arc(heart, ring, PI * 1.1, PI * 1.9, 20, Color(DeepUi.BAD, 0.8), 3.0, true)

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
