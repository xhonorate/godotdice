extends Control
## The fight, seen from the party's own eyes.
##
## The chamber is one World3D: creatures stand in an arc facing the camera, and every plate
## above a creature is a 2D control pinned to a 3D anchor. The player's dice and rail sit at
## the bottom of their own screen; allies are compact panels at the side. Nothing here
## decides anything: the screen shows the state it is given and animates the events it is
## handed, and every click becomes a command.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const CrystalCreature = preload("res://view/creatures/crystal_creature.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")

signal command(cmd: Dictionary)

const DIE_EDGE: float = 86.0
const SOCKET_EDGE: float = 68.0
const CAMERA_POSITION := Vector3(0.0, 2.1, 5.2)
const CAMERA_LOOK := Vector3(0.0, 1.2, -3.5)
const ARC_Z: float = -4.2

var local_id: String = ""
var state: Dictionary = {}
var depth: int = 1
var forecast: Dictionary = {}
var selected: Array = []

var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D
var _creatures: Dictionary = {}
var _plates: Dictionary = {}
var _plates_layer: Control
var _hud: VBoxContainer
var _top_left: Label
var _top_right: Label
var _banner: Label
var _rail_box: HBoxContainer
var _socket_cards: Array = []
var _resonance_label: Label
var _tray_box: HBoxContainer
var _dice_views: Dictionary = {}
var _reroll_button: Button
var _lock_button: Button
var _hint: Label
var _hp_bar: DeepUi.Bar
var _hp_text: Label
var _status_row: HBoxContainer
var _forecast_box: VBoxContainer
var _ally_box: VBoxContainer
var _shake: float = 0.0
var _vignette: ColorRect
var _headless: bool = false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stage()
	_build_hud()

# --- the chamber ---------------------------------------------------------------------------

func _build_stage() -> void:
	if _headless:
		var dark := ColorRect.new()
		dark.color = DeepUi.INK
		dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dark)
		return
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	frame.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.position = CAMERA_POSITION
	_camera.look_at_from_position(CAMERA_POSITION, CAMERA_LOOK, Vector3.UP)
	_camera.fov = 58.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07090d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("2a3140")
	environment.ambient_light_energy = 1.3
	environment.fog_enabled = true
	environment.fog_light_color = Color("0c1018")
	environment.fog_density = 0.035
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.05
	_camera.environment = environment
	_viewport.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.light_color = Color("f4e6c8")
	key.light_energy = 0.9
	key.rotation_degrees = Vector3(-52, 28, 0)
	key.shadow_enabled = true
	_world.add_child(key)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color("ffb877")
	lantern.light_energy = 2.6
	lantern.omni_range = 14.0
	lantern.position = Vector3(0.6, 2.6, 3.4)
	_world.add_child(lantern)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("1a1e27")
	stone.roughness = 0.95
	floor.material_override = stone
	_world.add_child(floor)
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(1.5, 9.0, 30.0)
		wall.mesh = slab
		wall.position = Vector3(side * 9.5, 4.0, -6.0)
		wall.rotation_degrees = Vector3(0, side * 14.0, 0)
		var rock := StandardMaterial3D.new()
		rock.albedo_color = Color("11151d")
		rock.roughness = 1.0
		wall.material_override = rock
		_world.add_child(wall)
	var back := MeshInstance3D.new()
	var back_slab := BoxMesh.new()
	back_slab.size = Vector3(30, 10, 1.5)
	back.mesh = back_slab
	back.position = Vector3(0, 4.5, -13.0)
	back.material_override = floor.material_override
	_world.add_child(back)

func _place_creatures() -> void:
	var enemies: Array = state.get("enemies", [])
	var living: Array = enemies.filter(func(e: Dictionary) -> bool: return int(e.hp) > 0)
	var present: Dictionary = {}
	var index: int = 0
	for foe in enemies:
		var id: String = str(foe.id)
		present[id] = true
		if int(foe.hp) <= 0:
			if _creatures.has(id) and is_instance_valid(_creatures[id]) and not bool(_creatures[id].get_meta("dying", false)):
				_creatures[id].set_meta("dying", true)
				_creatures[id].die()
			continue
		var slot: int = living.find(foe)
		var spread: float = minf(3.4, 1.4 * float(living.size()))
		var x: float = 0.0 if living.size() == 1 else lerpf(-spread, spread, float(slot) / float(living.size() - 1))
		var target := Vector3(x, 0.0, ARC_Z - absf(x) * 0.25)
		if not _creatures.has(id) or not is_instance_valid(_creatures[id]):
			if _headless:
				continue
			var creature: CrystalCreature = CrystalCreature.make(str(foe.key), bool(foe.get("warden", false)))
			creature.position = target
			creature.rest_position = target
			_world.add_child(creature)
			_creatures[id] = creature
		else:
			var creature: CrystalCreature = _creatures[id]
			if not creature.rest_position.is_equal_approx(target):
				creature.rest_position = target
				var tween := create_tween()
				tween.tween_property(creature, "position", target, 0.5).set_ease(Tween.EASE_IN_OUT)
		index += 1
	for id in _creatures.keys():
		if not present.has(id) and is_instance_valid(_creatures[id]):
			_creatures[id].queue_free()
			_creatures.erase(id)

# --- the HUD -------------------------------------------------------------------------------

func _build_hud() -> void:
	_plates_layer = Control.new()
	_plates_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plates_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plates_layer)
	_vignette = ColorRect.new()
	_vignette.color = Color(DeepUi.BAD, 0.0)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_hud = VBoxContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var top := DeepUi.hbox(_hud, 12)
	_top_left = DeepUi.label(top, "", 14, DeepUi.MUTED)
	DeepUi.spacer(top)
	_banner = DeepUi.label(top, "", 22, DeepUi.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.modulate.a = 0.0
	DeepUi.spacer(top)
	_top_right = DeepUi.label(top, "", 14, DeepUi.MUTED)
	DeepUi.spacer(_hud, false)
	var dock := DeepUi.panel(_hud, Color(DeepUi.SLATE, 0.92), DeepUi.LINE, 12, 12)
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var columns := DeepUi.hbox(dock, 18)
	## Left: you and your rail.
	var left := DeepUi.vbox(columns, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	var me := DeepUi.hbox(left, 10)
	_hp_text = DeepUi.label(me, "", 13, DeepUi.PAPER)
	_hp_bar = DeepUi.bar(me, 14.0)
	_status_row = DeepUi.hbox(me, 4)
	var rail_head := DeepUi.hbox(left, 8)
	DeepUi.heading(rail_head, "Rail")
	DeepUi.spacer(rail_head)
	_resonance_label = DeepUi.label(rail_head, "", 12, DeepUi.ACCENT)
	_rail_box = DeepUi.hbox(left, 8)
	## Middle: the dice.
	var middle := DeepUi.vbox(columns, 8)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_stretch_ratio = 1.4
	var tray_head := DeepUi.hbox(middle, 8)
	DeepUi.heading(tray_head, "Your hand")
	DeepUi.spacer(tray_head)
	_hint = DeepUi.label(tray_head, "", 12, DeepUi.MUTED)
	_tray_box = DeepUi.hbox(middle, 10)
	_tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons := DeepUi.hbox(middle, 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_reroll_button = DeepUi.button(buttons, "Reroll selected", _reroll)
	_lock_button = DeepUi.button(buttons, "Lock in", _toggle_lock)
	## Right: what the hand would do, and the rest of the party.
	var right := DeepUi.vbox(columns, 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.heading(right, "This hand would")
	_forecast_box = DeepUi.vbox(right, 2)
	_ally_box = DeepUi.vbox(right, 6)

func bind(player_id: String) -> void:
	local_id = player_id

func show_state(battle: Dictionary, at_depth: int, new_forecast: Dictionary = {}) -> void:
	state = battle
	depth = at_depth
	forecast = new_forecast
	_place_creatures()
	_sync()

func me() -> Dictionary:
	return DeepBattle.player(state, local_id)

func _sync() -> void:
	if state.is_empty():
		return
	var unit: Dictionary = me()
	var planning: bool = str(state.get("phase", "")) == "planning"
	_top_left.text = "Depth %d   ·   Turn %d" % [depth, int(state.get("turn", 1))]
	var living_foes: int = DeepBattle.living(state.get("enemies", [])).size()
	_top_right.text = "%d creature%s" % [living_foes, "" if living_foes == 1 else "s"]
	if not unit.is_empty():
		_hp_text.text = "%s  %d / %d" % [str(unit.name), int(unit.hp), int(unit.max_hp)]
		_hp_bar.set_values(float(unit.hp) / float(maxi(1, int(unit.max_hp))), "", float(unit.block) / float(maxi(1, int(unit.max_hp))))
		DeepUi.clear(_status_row)
		if int(unit.block) > 0:
			DeepUi.chip(_status_row, "%d block" % int(unit.block), DeepUi.BLOCK, 11)
		for status in unit.get("statuses", {}):
			if int(unit.statuses[status]) > 0:
				DeepUi.chip(_status_row, "%s %d" % [str(status), int(unit.statuses[status])], DeepUi.POISON if status == "poison" else DeepUi.BAD, 11)
		_resonance_label.text = "Resonance %d" % int(unit.get("resonance", 0)) if not planning else ""
	_sync_rail(unit, planning)
	_sync_tray(unit, planning)
	_sync_forecast()
	_sync_allies()
	_sync_plates()
	var locked: bool = bool(unit.get("locked", false))
	var downed: bool = bool(unit.get("downed", false))
	_reroll_button.disabled = not planning or locked or downed or int(unit.get("rerolls", 0)) <= 0 or selected.is_empty()
	_reroll_button.text = "Reroll selected  (%d left)" % int(unit.get("rerolls", 0)) if planning else "Resolving…"
	_lock_button.disabled = not planning or downed
	_lock_button.text = "Unlock" if locked else "Lock in"
	if downed:
		_hint.text = "You are down. The party fights on."
	elif not planning:
		_hint.text = "Resolving"
	elif locked:
		var waiting: Array = state.get("players", []).filter(func(p: Dictionary) -> bool: return not bool(p.get("locked", false)) and not bool(p.get("downed", false)))
		_hint.text = "Waiting for %s" % ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))) if not waiting.is_empty() else "Everyone is in."
	else:
		_hint.text = "Click dice to reroll them" if selected.is_empty() else "%d selected" % selected.size()

func _sync_rail(unit: Dictionary, planning: bool) -> void:
	var rail: Array = unit.get("rail", [])
	if _socket_cards.size() != rail.size():
		DeepUi.clear(_rail_box)
		_socket_cards.clear()
		for socket in range(rail.size()):
			var card := VBoxContainer.new()
			card.add_theme_constant_override("separation", 3)
			card.alignment = BoxContainer.ALIGNMENT_CENTER
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			_rail_box.add_child(card)
			_socket_cards.append(card)
	var sockets: Array = unit.get("sockets", [])
	for socket in range(rail.size()):
		var card: VBoxContainer = _socket_cards[socket]
		var stone: Variant = rail[socket]
		var socket_colour: String = str(sockets[socket]) if socket < sockets.size() else "ANY"
		var tag: String = "%s|%s" % [str(stone.get("id", "")) if stone is Dictionary else "", socket_colour]
		if str(card.get_meta("tag", "")) != tag:
			card.set_meta("tag", tag)
			DeepUi.clear(card)
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
			slot.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_child(slot)
			var ring := _SocketRing.new(socket_colour, stone == null)
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(ring)
			if stone is Dictionary:
				var picture := GemView.new()
				picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
				picture.set_drift(false)
				picture.configure(stone)
				picture.tooltip_text = DeepStone.name(stone)
				slot.add_child(picture)
				var skill: Dictionary = DeepStone.skill_of(stone)
				var trigger_row := HBoxContainer.new()
				trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
				card.add_child(trigger_row)
				var name_label := DeepUi.label(card, str(skill.get("name", stone.skill)), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
				name_label.name = "SkillName"
				trigger_row.name = "Trigger"
			else:
				DeepUi.label(card, socket_colour.capitalize() if socket_colour != "ANY" else "Any", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if stone is Dictionary:
			var entry: Dictionary = {}
			for candidate in forecast.get("sockets", []):
				if int(candidate.get("socket", -1)) == socket:
					entry = candidate
			var trigger_row: Node = card.get_node_or_null("Trigger")
			if trigger_row != null:
				var described: Dictionary = entry.get("trigger", DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(stone.get("cut", 0))))
				var active: bool = bool(entry.get("active", false))
				var tone: Color = DeepUi.GOOD if active and planning else (DeepUi.PAPER if entry.is_empty() else DeepUi.DIM)
				var key: String = "%s|%s|%s" % [str(described.get("mark", "")), str(described.get("label", "")), str(tone)]
				if str(trigger_row.get_meta("key", "")) != key:
					trigger_row.set_meta("key", key)
					DeepUi.clear(trigger_row)
					DiceIcons.build(trigger_row, described, 16, tone, str(described.get("words", "")) + ("" if active or entry.is_empty() else "\n" + str(entry.get("reason", ""))))
			var blocked: bool = unit.get("buried", []).has(socket) or unit.get("clouded", []).has(socket)
			card.modulate = Color(1, 1, 1, 0.35) if blocked else Color.WHITE

class _SocketRing extends Control:
	var colour: String = "ANY"
	var empty: bool = false
	func _init(socket_colour: String, is_empty: bool) -> void:
		colour = socket_colour
		empty = is_empty
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var tone: Color = DeepUi.ACCENT if colour == "CAPSTONE" else (DeepUi.colour(colour) if colour != "ANY" else DeepUi.MUTED)
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.47
		draw_arc(centre, radius, 0, TAU, 40, Color(tone, 0.9 if empty else 0.55), 2.0 if colour != "CAPSTONE" else 3.0, true)
		if empty:
			draw_circle(centre, radius * 0.86, Color(tone, 0.08))

func _sync_tray(unit: Dictionary, planning: bool) -> void:
	var hand: Array = unit.get("hand", [])
	var by_id: Dictionary = {}
	for die in unit.get("dice", []):
		by_id[str(die.id)] = die
	var wanted: Array = []
	for roll in hand:
		if bool(roll.get("phantom", false)):
			continue
		wanted.append(str(roll.die_id))
	if _dice_views.keys() != wanted:
		DeepUi.clear(_tray_box)
		_dice_views.clear()
		for id in wanted:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE + 18)
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
			_tray_box.add_child(holder)
			var view := DiceView.new()
			view.position = Vector2.ZERO
			view.size = Vector2(DIE_EDGE, DIE_EDGE)
			view.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE)
			holder.add_child(view)
			var value := DeepUi.label(holder, "", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			value.position = Vector2(0, DIE_EDGE)
			value.size = Vector2(DIE_EDGE, 18)
			value.name = "Value"
			var hit := Button.new()
			hit.flat = true
			hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
			hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
			hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			hit.pressed.connect(_toggle_die.bind(id))
			holder.add_child(hit)
			_dice_views[id] = view
	for roll in hand:
		var id: String = str(roll.die_id)
		if not _dice_views.has(id):
			continue
		var view: DiceView = _dice_views[id]
		var tagged: Dictionary = roll.duplicate(true)
		tagged.turn_tag = str(state.get("turn", 0))
		var can_select: bool = planning and not bool(unit.get("locked", false)) and not bool(roll.get("locked", false))
		view.configure(by_id.get(id, {"key": roll.key, "shape": roll.shape, "faces": []}), tagged, selected.has(id) and can_select, false, DeepUi.ACCENT)
		var value: Label = view.get_parent().get_node("Value")
		var words: String = DiceIcons.face_text(int(roll.value), str(roll.get("kind", "plain")))
		if bool(roll.get("locked", false)):
			words += "  locked"
		elif bool(roll.get("held", false)) and int(roll.get("rerolls", 0)) == 0 and planning:
			words += ""
		value.text = words
		value.add_theme_color_override("font_color", DeepUi.ACCENT if selected.has(id) and can_select else DeepUi.MUTED)

func _sync_forecast() -> void:
	DeepUi.clear(_forecast_box)
	var totals: Dictionary = forecast.get("totals", {})
	if totals.is_empty():
		DeepUi.label(_forecast_box, "—", 13, DeepUi.DIM)
		return
	var rows: Array = [["Damage", "damage", DeepUi.BAD], ["Block", "block", DeepUi.BLOCK], ["Heal", "heal", DeepUi.GOOD], ["Ore", "gold", DeepUi.ACCENT], ["Poison", "poison", DeepUi.POISON]]
	for row in rows:
		var amount: int = int(totals.get(row[1], 0))
		if amount <= 0:
			continue
		var line := DeepUi.hbox(_forecast_box, 6)
		DeepUi.label(line, str(row[0]), 13, DeepUi.MUTED)
		DeepUi.spacer(line)
		DeepUi.label(line, str(amount), 15, row[2])
	var fires: int = int(totals.get("fires", 0))
	var fizzles: int = int(totals.get("fizzles", 0))
	var summary := DeepUi.hbox(_forecast_box, 6)
	DeepUi.label(summary, "%d fire, %d fizzle" % [fires, fizzles], 12, DeepUi.MUTED)
	DeepUi.spacer(summary)
	DeepUi.label(summary, "Resonance %d" % int(totals.get("resonance", 0)), 12, DeepUi.ACCENT)

func _sync_allies() -> void:
	DeepUi.clear(_ally_box)
	for unit in state.get("players", []):
		if str(unit.id) == local_id:
			continue
		var card := DeepUi.panel(_ally_box, DeepUi.SLATE_LOW, DeepUi.LINE, 8, 8)
		var box := DeepUi.vbox(card, 3)
		var head := DeepUi.hbox(box, 6)
		DeepUi.label(head, str(unit.name), 13, DeepUi.PAPER)
		DeepUi.spacer(head)
		var note: String = "down" if bool(unit.get("downed", false)) else ("locked" if bool(unit.get("locked", false)) else "planning")
		if not bool(unit.get("connected", true)):
			note = "away"
		DeepUi.label(head, note, 11, DeepUi.MUTED)
		var bar := DeepUi.bar(box, 8.0)
		bar.set_values(float(unit.hp) / float(maxi(1, int(unit.max_hp))), "", float(unit.block) / float(maxi(1, int(unit.max_hp))))
		var hand_text: Array = []
		for roll in unit.get("hand", []):
			if not bool(roll.get("phantom", false)):
				hand_text.append(DiceIcons.face_text(int(roll.value), str(roll.get("kind", "plain"))))
		DeepUi.label(box, "  ".join(hand_text) + ("   ·   Resonance %d" % int(unit.get("resonance", 0)) if str(state.get("phase", "")) != "planning" else ""), 11, DeepUi.MUTED)

func _sync_plates() -> void:
	var present: Dictionary = {}
	for foe in state.get("enemies", []):
		var id: String = str(foe.id)
		present[id] = true
		if int(foe.hp) <= 0:
			if _plates.has(id):
				_plates[id].visible = false
			continue
		var plate: PanelContainer
		if not _plates.has(id) or not is_instance_valid(_plates[id]):
			plate = PanelContainer.new()
			plate.add_theme_stylebox_override("panel", DeepUi.flat(Color(DeepUi.SLATE, 0.86), DeepUi.LINE, 8, 8))
			plate.mouse_filter = Control.MOUSE_FILTER_STOP
			plate.gui_input.connect(_plate_input.bind(id))
			_plates_layer.add_child(plate)
			_plates[id] = plate
		plate = _plates[id]
		plate.visible = true
		var targeted: bool = str(me().get("target", "")) == id
		plate.add_theme_stylebox_override("panel", DeepUi.flat(Color(DeepUi.SLATE, 0.86), DeepUi.ACCENT if targeted else DeepUi.LINE, 8, 8, 2 if targeted else 1))
		DeepUi.clear(plate)
		var box := DeepUi.vbox(plate, 3)
		var head := DeepUi.hbox(box, 6)
		DeepUi.label(head, str(foe.name), 13, DeepUi.PAPER)
		if targeted:
			DeepUi.label(head, "target", 10, DeepUi.ACCENT)
		var bar := DeepUi.bar(box, 9.0, DeepUi.BAD, DeepUi.HP_LOST)
		bar.custom_minimum_size = Vector2(120, 9)
		bar.set_values(float(foe.hp) / float(maxi(1, int(foe.max_hp))), "%d" % int(foe.hp))
		var chips := DeepUi.hbox(box, 4)
		if int(foe.block) > 0:
			DeepUi.chip(chips, "%d block" % int(foe.block), DeepUi.BLOCK, 10)
		for status in foe.get("statuses", {}):
			if int(foe.statuses[status]) > 0:
				DeepUi.chip(chips, "%s %d" % [str(status), int(foe.statuses[status])], DeepUi.POISON if status == "poison" else DeepUi.INFO, 10)
		for intent in foe.get("intents", []):
			var line := DeepUi.hbox(box, 5)
			GemIcons.glyph(line, GemIcons.emblem(str(intent.move).to_upper()), 14, DeepUi.MUTED, str(intent.move))
			var amounts: Array = []
			for effect in intent.get("effects", []):
				var kind: String = str(effect.kind)
				var amount: int = int(effect.amount) * maxi(1, int(effect.get("repeat", 1)))
				match kind:
					"damage": amounts.append("%d dmg" % amount)
					"block": amounts.append("+%d block" % amount)
					"poison": amounts.append("%d poison" % amount)
					"stun": amounts.append("stun")
					"remove_block": amounts.append("−%d block" % amount)
					"die_steal": amounts.append("steals a die")
					_: amounts.append(kind)
			var target_name: String = str(DeepBattle.player(state, str(intent.get("target", ""))).get("name", ""))
			var words: String = "%s: %s" % [str(intent.move), ", ".join(amounts)]
			if not target_name.is_empty() and intent.get("effects", []).any(func(e: Dictionary) -> bool: return str(e.target) == "hero"):
				words += " → " + target_name
			DeepUi.label(line, words, 11, DeepUi.PAPER if str(intent.get("target", "")) == local_id else DeepUi.MUTED)
		if str(foe.get("text", "")) != "":
			plate.tooltip_text = str(foe.text)
	for id in _plates.keys():
		if not present.has(id):
			_plates[id].queue_free()
			_plates.erase(id)

func _plate_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		command.emit({"kind": "target", "enemy": id})

func _process(delta: float) -> void:
	if _headless or _camera == null:
		return
	for id in _creatures:
		var creature: CrystalCreature = _creatures[id]
		if not is_instance_valid(creature) or not _plates.has(id) or not is_instance_valid(_plates[id]):
			continue
		var plate: Control = _plates[id]
		if not plate.visible:
			continue
		var world_point: Vector3 = creature.global_position + creature.anchor
		if _camera.is_position_behind(world_point):
			plate.visible = false
			continue
		var screen: Vector2 = _camera.unproject_position(world_point)
		var scale_factor: float = _plates_layer.size.x / maxf(1.0, float(_viewport.size.x))
		plate.position = screen * scale_factor - Vector2(plate.size.x * 0.5, plate.size.y + 6)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		_hud.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 6.0
	else:
		_hud.position = Vector2.ZERO

# --- input ---------------------------------------------------------------------------------

func _toggle_die(id: String) -> void:
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or bool(unit.get("locked", false)):
		return
	if selected.has(id):
		selected.erase(id)
	else:
		selected.append(id)
	_sync()

func _reroll() -> void:
	if selected.is_empty():
		return
	command.emit({"kind": "reroll", "dice": selected.duplicate()})
	selected.clear()

func _toggle_lock() -> void:
	command.emit({"kind": "unlock" if bool(me().get("locked", false)) else "lock"})

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R: _reroll()
		KEY_SPACE: _toggle_lock()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var index: int = event.keycode - KEY_1
			var ids: Array = _dice_views.keys()
			if index < ids.size():
				_toggle_die(str(ids[index]))

# --- events --------------------------------------------------------------------------------

func perform(event: Dictionary) -> void:
	## Animate one battle event against the state already shown.
	var kind: String = str(event.get("kind", ""))
	match kind:
		"turn_begin":
			selected.clear()
			_say("Turn %d" % int(event.get("turn", 1)), DeepUi.MUTED)
		"resolution_begin":
			_say("Resolving", DeepUi.ACCENT)
		"gem_fire":
			_socket_pulse(event, true)
			for effect in event.get("effects", []):
				_show_effect(effect, str(event.get("unit", "")))
			if str(event.get("unit", "")) == local_id and int(event.get("gain", 0)) > 0:
				_float_at(_resonance_label, "+%d%s" % [int(event.gain), " harmony" if bool(event.get("harmony", false)) else ""], DeepUi.ACCENT, 14)
		"gem_fizzle":
			_socket_pulse(event, false)
		"enemy_move":
			var creature: CrystalCreature = _creatures.get(str(event.get("unit", "")), null)
			if creature != null and is_instance_valid(creature):
				creature.lunge(CAMERA_POSITION, 0.5)
			for effect in event.get("effects", []):
				_show_enemy_effect(effect)
		"tick":
			for tick in event.get("ticks", []):
				var target_id: String = str(tick.get("unit", ""))
				if _plates.has(target_id):
					_float_at(_plates[target_id], "−%d poison" % int(tick.get("amount", 0)), DeepUi.POISON)
				elif target_id == local_id:
					_float_at(_hp_bar, "−%d poison" % int(tick.get("amount", 0)), DeepUi.POISON)
		"skip":
			var who: String = str(event.get("unit", ""))
			if _plates.has(who):
				_float_at(_plates[who], "stunned", DeepUi.INFO)
			elif who == local_id:
				_say("You are stunned", DeepUi.INFO)
		"battle_over":
			var won: bool = str(event.get("outcome", "")) == "victory"
			_say("Victory" if won else "The party falls", DeepUi.GOOD if won else DeepUi.BAD, 2.0)

func _show_effect(effect: Dictionary, source_id: String) -> void:
	var kind: String = str(effect.get("kind", ""))
	var target_id: String = str(effect.get("target", ""))
	match kind:
		"damage":
			var hits: Array = [effect] + effect.get("splash", [])
			for hit in hits:
				var who: String = str(hit.get("target", target_id))
				var creature: CrystalCreature = _creatures.get(who, null)
				if creature != null and is_instance_valid(creature):
					creature.flash()
				if _plates.has(who):
					var text: String = "−%d" % (int(hit.get("hp_loss", 0)) + int(hit.get("absorbed", 0)))
					if int(hit.get("absorbed", 0)) > 0:
						text += " (%d blocked)" % int(hit.absorbed)
					_float_at(_plates[who], text, DeepUi.BAD if source_id == local_id else DeepUi.PAPER, 20)
				if bool(hit.get("killed", false)) and creature != null and is_instance_valid(creature) and not bool(creature.get_meta("dying", false)):
					creature.set_meta("dying", true)
					creature.die()
		"block":
			if target_id == local_id:
				_float_at(_hp_bar, "+%d block" % int(effect.amount), DeepUi.BLOCK)
		"heal", "revive":
			if target_id == local_id:
				_float_at(_hp_bar, "+%d" % int(effect.get("healed", effect.amount)), DeepUi.GOOD)
		"gold":
			if source_id == local_id:
				_float_at(_forecast_box, "+%d ore" % int(effect.amount), DeepUi.ACCENT)
		"poison", "stun", "curse", "remove_block", "die_steal", "intent_downgrade":
			if _plates.has(target_id):
				_float_at(_plates[target_id], kind.replace("_", " ") + (" %d" % int(effect.amount) if int(effect.get("amount", 0)) > 0 and kind != "stun" else ""), DeepUi.INFO)
		"raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high":
			if source_id == local_id:
				_float_at(_tray_box, kind.replace("_", " "), DeepUi.PAPER, 14)

func _show_enemy_effect(effect: Dictionary) -> void:
	var kind: String = str(effect.get("kind", ""))
	var target_id: String = str(effect.get("target", ""))
	if kind == "damage":
		if target_id == local_id:
			_shake = 1.0
			_vignette.color = Color(DeepUi.BAD, 0.22)
			var tween := create_tween()
			tween.tween_property(_vignette, "color:a", 0.0, 0.5)
			var text: String = "−%d" % int(effect.get("hp_loss", 0))
			if int(effect.get("absorbed", 0)) > 0:
				text += " (%d blocked)" % int(effect.absorbed)
			_float_at(_hp_bar, text, DeepUi.BAD, 22)
		else:
			for card in _ally_box.get_children():
				pass
	elif kind == "block" and _plates.has(target_id):
		_float_at(_plates[target_id], "+%d block" % int(effect.amount), DeepUi.BLOCK)
	elif target_id == local_id and kind in ["poison", "stun", "die_steal", "remove_block"]:
		_float_at(_hp_bar, kind.replace("_", " "), DeepUi.INFO)

func _socket_pulse(event: Dictionary, fired: bool) -> void:
	if str(event.get("unit", "")) != local_id:
		return
	var socket: int = int(event.get("socket", -1))
	if socket < 0 or socket >= _socket_cards.size():
		return
	var card: Control = _socket_cards[socket]
	var tween := create_tween()
	if fired:
		card.modulate = Color(1.6, 1.5, 1.2, 1.0)
		tween.tween_property(card, "modulate", Color.WHITE, 0.6)
	else:
		card.modulate = Color(0.5, 0.5, 0.6, 1.0)
		tween.tween_property(card, "modulate", Color.WHITE, 0.6)
		_float_at(card, "fizzle", DeepUi.DIM, 12)

func _float_at(anchor: Control, text: String, color: Color, size: int = 18) -> void:
	if anchor == null or not is_instance_valid(anchor) or _headless:
		return
	var at: Vector2 = anchor.global_position + Vector2(anchor.size.x * 0.5, 0)
	DeepUi.float_text(self, at - global_position, text, color, size)

func _say(text: String, color: Color, hold: float = 1.1) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5).set_delay(hold)
