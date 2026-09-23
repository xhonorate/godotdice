extends Control
## The fight, seen from the party's own eyes.
##
## The room is the mine stage's: during a run it is the room the party walked into, and a
## screen shown on its own (a gallery shot) makes a stage of its own. Creatures stand in an
## arc facing the camera; the plate above each is a 2D control pinned to a 3D anchor. The
## player's rail, dice and forecast sit in a dock at the bottom; allies are compact cards at
## the side.
##
## Every event is played as something physical: a gem that fires throws a bolt of its own
## color from its socket to what it hits; a blow lands with sparks, light, a shockwave, a
## camera kick and a number; a creature rears before it strikes and the view flinches when
## it lands. Nothing here decides anything: the screen shows the state it is given, animates
## the events it is handed, and turns every click into a command.

const EnemyPanel = preload("res://view/battle/enemy_panel.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const MineStage = preload("res://view/run/mine_stage.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
## The field of view the camera prefers; it widens on its own when a tall creature and its
## plate would not fit under the top of the screen, and narrows back when they would.
const BASE_FOV: float = 58.0

signal command(cmd: Dictionary)

const DIE_EDGE: float = 82.0
const SOCKET_EDGE: float = 60.0
const ARC_Z: float = -4.4
const MOVE_WORDS: Dictionary = {"damage": "sword", "block": "shield", "poison": "drop", "stun": "stun", "remove_block": "split_shield",
	"die_steal": "die", "heal": "heart", "curse": "eye", "bury_socket": "rampart", "cloud_socket": "cloud"}

var local_id: String = ""
var state: Dictionary = {}
var depth: int = 1
var forecast: Dictionary = {}
var context: Dictionary = {}
var selected: Array = []

## The stage the fight is drawn on. Given by the run before the screen is added; a screen
## shown on its own makes its own.
var stage: Control = null
## Creatures leave ore and roughs on the floor as they die, for the run to settle later.
var spoils: bool = false

var _headless: bool = false
var _world: Node3D
var _camera: Camera3D
var _fx: Node3D
var _chamber: Node3D:
	get:
		return stage.room if stage != null and stage.has_room() else null
var _stage_key: String = ""
var _battle_signature: String = ""
var _intro_pending: bool = false
var _creatures: Dictionary = {}
var _hovered_creature: String = ""

var _screen_fx: ColorRect
var _flare: Control
var _picker: Control
var _plates_layer: Control
var _plates: Dictionary = {}
var _enemy_panel: PanelContainer
var _pinned_enemy: String = ""
var _hud: Control
var _depth_label: Label
var _biome_label: Label
var _turn_pill: PanelContainer
var _foes_pill: PanelContainer
var _banner: Label
var _banner_sub: Label
var _banner_box: VBoxContainer
var _dock: PanelContainer
var _rail_box: HBoxContainer
var _socket_cards: Array = []
var _resonance_value: Label
var _resonance_box: HBoxContainer
var _tray_box: HBoxContainer
var _dice_views: Dictionary = {}
## A rearrangement of the room put off until a death or a split has finished animating, and
## the creatures whose arrival has already been waited for.
var _layout_wait: SceneTreeTimer = null
var _awaited: Dictionary = {}
## The hand as it was last seen, and when the dice it rolled will have finished tumbling.
var _rolled_hand: String = ""
var _dice_settle_at: int = 0
var _reroll_button: Button
var _flip_button: Button
var _lock_button: Button
var _birthstone_card: VBoxContainer = null
var _birthstone_key: String = ""
var _hint: Label
var _hp_bar: DeepUi.Bar
var _status_row: HBoxContainer
var _effects: EffectChips.Row
var _fight_effects: EffectChips.Row
var _effects_box: VBoxContainer
var _forecast_box: VBoxContainer
var _ally_box: VBoxContainer
var _ally_cards: Dictionary = {}
var _lock_pulse: Tween = null
## The forecast as the hand stood when it was locked in, and what the local rail has actually
## done since: socket -> fired, and the Birthstone's own event.
var _held_forecast: Dictionary = {}
var _outcomes: Dictionary = {}
var _birth_outcome: Dictionary = {}
## Bumped by every change to the Resonance number, so sparks still in flight never write an
## old value over a newer one.
var _resonance_token: int = 0

var _shows: int = 0

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stage == null:
		stage = MineStage.new()
		add_child(stage)
	_world = stage.world
	_camera = stage.camera
	_fx = stage.fx
	_screen_fx = stage.screen_fx
	_flare = stage.flare
	_build_hud()
	_enemy_panel = EnemyPanel.new()
	add_child(_enemy_panel)
	_enemy_panel.pinned.connect(_pin_enemy)

# --- the chamber ---------------------------------------------------------------------------

func warm_up() -> void:
	stage.warm_up()

func _rebuild_chamber() -> void:
	## The room is the stage's. During a run the party has already walked into it and this
	## only reads it; shown on its own, the stage builds it here and the camera sweeps in.
	if _headless:
		return
	var mine: String = str(context.get("mine", DeepContent.starter_mine()))
	var kind: String = str(context.get("kind", "warden" if bool(state.get("warden", false)) else ("elite" if bool(state.get("elite", false)) else "fight")))
	var key: String = "%s|%d|%s" % [mine, depth, kind]
	var built: bool = stage.show_room({"key": key, "mine": mine, "depth": depth, "kind": kind, "exits": int(context.get("exits", 2))})
	if key == _stage_key and not built:
		return
	_stage_key = key
	if _chamber == null:
		return
	var biome: Dictionary = _chamber.biome
	_camera.calm(1.7 if bool(biome.warden) else 1.0)
	if not stage.arrived_by_walk:
		_camera.reset()
		_camera.intro(1.5, bool(biome.warden))
	_screen_fx.desaturate = 0.0
	_depth_label.text = str(biome.name)
	_biome_label.text = "Depth %d%s" % [depth, "  ·  Warden's gate" if bool(biome.warden) else ("  ·  Elite" if bool(biome.elite) else "")]
	_intro_pending = true

func _creature(id: String) -> CrystalCreature:
	## A creature still standing in the room, or null. Checked before it is typed, because a
	## freed one cannot even be assigned to a typed variable.
	var node: Variant = _creatures.get(id, null)
	if node == null or not is_instance_valid(node):
		return null
	return node as CrystalCreature

## How long the room waits before it rearranges itself: long enough for a creature to
## finish breaking apart, or for the blow that split one in two to land.
const SETTLE_SECONDS: float = 0.62

func _hold_layout(seconds: float = SETTLE_SECONDS) -> void:
	## Puts the rearrangement off until what caused it has played out.
	if _layout_wait != null or _headless or not is_inside_tree():
		return
	_layout_wait = get_tree().create_timer(maxf(0.1, seconds))
	_layout_wait.timeout.connect(func() -> void:
		_layout_wait = null
		if is_instance_valid(self) and not state.is_empty():
			_place_creatures()
			_sync())

func _place_creatures() -> void:
	var enemies: Array = state.get("enemies", [])
	var living: Array = enemies.filter(func(e: Dictionary) -> bool: return int(e.hp) > 0)
	var present: Dictionary = {}
	var fresh: int = 0
	## Nothing slides along the arc while a creature is still coming apart, and a half that
	## has just split off waits with it: a layout that moved the instant the rules did would
	## pull the room out from under a blow that has not finished landing.
	var settling: bool = false
	for foe in enemies:
		var id: String = str(foe.id)
		if int(foe.hp) <= 0:
			if _creatures.has(id) and is_instance_valid(_creatures[id]) and not bool(_creatures[id].get_meta("dying", false)):
				_kill(_creatures[id])
				settling = true
			continue
		if not _intro_pending and not _headless and not _awaited.has(id) and (not _creatures.has(id) or not is_instance_valid(_creatures[id])):
			_awaited[id] = true
			settling = true
	## Nothing moves while the turn is still playing out either: a creature sliding along the
	## arc between one blow and the next reads as the room second-guessing the fight.
	if not settling and str(state.get("phase", "")) == "resolving":
		for foe in enemies:
			var id: String = str(foe.id)
			if int(foe.hp) > 0 and _creatures.has(id) and is_instance_valid(_creatures[id]):
				var slot: int = living.find(foe)
				var spread: float = minf(3.6, 1.5 * float(living.size()))
				var x: float = 0.0 if living.size() == 1 else lerpf(-spread, spread, float(slot) / float(living.size() - 1))
				if not (_creatures[id] as CrystalCreature).rest_position.is_equal_approx(Vector3(x, 0.0, ARC_Z - absf(x) * 0.28)):
					settling = true
	if settling:
		for foe in enemies:
			present[str(foe.id)] = true
		_forget_gone(present)
		_hold_layout()
		return
	for foe in enemies:
		var id: String = str(foe.id)
		present[id] = true
		if int(foe.hp) <= 0:
			continue
		var slot: int = living.find(foe)
		var spread: float = minf(3.6, 1.5 * float(living.size()))
		var x: float = 0.0 if living.size() == 1 else lerpf(-spread, spread, float(slot) / float(living.size() - 1))
		var target := Vector3(x, 0.0, ARC_Z - absf(x) * 0.28)
		if not _creatures.has(id) or not is_instance_valid(_creatures[id]):
			if _headless:
				continue
			var creature: CrystalCreature = CrystalCreature.make(str(foe.key), bool(foe.get("warden", false)))
			creature.position = target
			creature.rest_position = target
			_world.add_child(creature)
			_creatures[id] = creature
			var after: float = stage.seal_remaining() if stage.has_method("seal_remaining") else 0.0
			creature.spawn(after + 0.25 + 0.18 * float(fresh) if _intro_pending else after)
			_fx.puff(target + Vector3(0, 0.3, 0), Color(0.5, 0.45, 0.4), 10, 0.9, 1.4, 0.6)
			fresh += 1
		else:
			var creature: CrystalCreature = _creatures[id]
			if not creature.rest_position.is_equal_approx(target):
				var tween := create_tween()
				tween.tween_property(creature, "rest_position", target, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		(_creatures[id] as CrystalCreature).set_targeted(str(me().get("target", "")) == id)
	if _intro_pending and fresh > 0 and _camera != null:
		## Frame the room for its tallest creature before the camera sweeps in, so a Warden
		## is not first seen with its head cut off.
		var tallest: float = 0.0
		for id in _creatures:
			var creature: CrystalCreature = _creature(str(id))
			if creature != null:
				tallest = maxf(tallest, creature.anchor.y)
		## Eased into, not snapped to: the party has just walked in and the view is still
		## settling from the tunnel.
		var wide: float = clampf(BASE_FOV + maxf(0.0, tallest - 2.8) * 4.8, BASE_FOV, 80.0)
		var eye := Vector3(_camera.home_look.x, 1.2 + (wide - BASE_FOV) * 0.05, _camera.home_look.z)
		if _headless:
			_camera.home_fov = wide
			_camera.home_look = eye
		else:
			var settle := _camera.create_tween().set_parallel(true)
			settle.tween_property(_camera, "home_fov", wide, 0.6).set_trans(Tween.TRANS_SINE)
			settle.tween_property(_camera, "home_look", eye, 0.6).set_trans(Tween.TRANS_SINE)
	_intro_pending = false
	_forget_gone(present)

func _forget_gone(present: Dictionary) -> void:
	## Anything the fight no longer has, and anything already freed, leaves the book.
	for id in _creatures.keys():
		if not is_instance_valid(_creatures[id]):
			_creatures.erase(id)
		elif not present.has(id):
			_creatures[id].queue_free()
			_creatures.erase(id)
	for id in _awaited.keys():
		if not present.has(id):
			_awaited.erase(id)

# --- the HUD -------------------------------------------------------------------------------

func _build_hud() -> void:
	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_PASS
	_picker.gui_input.connect(_pick_input)
	add_child(_picker)
	_plates_layer = Control.new()
	_plates_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plates_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plates_layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	## Top left: where the fight is.
	var place := DeepUi.vbox(_hud, 2)
	place.position = Vector2(22, 16)
	var depth_row := DeepUi.hbox(place, 10)
	DeepUi.icon(depth_row, "pick", 24, DeepUi.ACCENT, "Where the fight is")
	_depth_label = DeepUi.title(depth_row, "", 24, DeepUi.PAPER)
	_turn_pill = DeepUi.pill(depth_row, "hourglass", "Turn 1", DeepUi.MUTED, 13, "Turn")
	_turn_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_biome_label = DeepUi.label(place, "", 14, DeepUi.MUTED)
	_biome_label.add_theme_font_override("font", DeepUi.display_font())
	## Top right: what the party faces.
	var foes := DeepUi.hbox(_hud, 8)
	foes.alignment = BoxContainer.ALIGNMENT_END
	foes.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	foes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fight_effects = EffectChips.Row.new(18)
	foes.add_child(_fight_effects)
	_foes_pill = DeepUi.pill(foes, "skull", "", DeepUi.BAD, 14, "Creatures still standing. Right-click one for everything about it.")
	## The banner in the middle of the room.
	_banner_box = DeepUi.vbox(_hud, 0)
	_banner_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_box.position.y = 96
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner = DeepUi.title(_banner_box, "", 46, DeepUi.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner_sub = DeepUi.label(_banner_box, "", 16, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_sub.add_theme_constant_override("outline_size", 5)
	_banner_box.modulate.a = 0.0
	## Allies: cards down the right edge.
	_ally_box = DeepUi.vbox(_hud, 8)
	_ally_box.custom_minimum_size = Vector2(230, 0)
	_ally_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	_ally_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ally_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ally_box.offset_top -= 130
	_ally_box.offset_bottom -= 130
	## Your buffs and troubles, in a row along the top edge of the dock.
	_effects_box = DeepUi.vbox(_hud, 2)
	_effects_box.position = Vector2(22, 600)
	_effects = EffectChips.Row.new(20)
	_effects_box.add_child(_effects)
	## The dock.
	_dock = PanelContainer.new()
	var dock_style := DeepUi.raised(Color(0.06, 0.075, 0.105, 0.9), Color(DeepUi.LINE_HI, 0.8), 16, 14, 0.55)
	_dock.add_theme_stylebox_override("panel", dock_style)
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 16
	_dock.offset_right = -16
	_dock.offset_bottom = -14
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_dock)
	var columns := DeepUi.hbox(_dock, 20)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	## Left: you, and your rail.
	var left := DeepUi.vbox(columns, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## As tall as the block pill from the start, and everything in it centred, so gaining
	## block never stretches the bar or moves the dock.
	var me_row := DeepUi.hbox(left, 8)
	me_row.custom_minimum_size.y = 30
	DeepUi.icon(me_row, "heart", 22, DeepUi.HP, "Your health").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar = DeepUi.bar(me_row, 20.0)
	_hp_bar.custom_minimum_size = Vector2(250, 20)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## The count rides inside the bar rather than beside it: one thing to read, and nothing
	## to line up against it.
	_status_row = DeepUi.hbox(me_row, 4)
	_status_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Resonance rides on the same line as the health bar: the stones below it say plainly
	## enough what they are, so the rail needs no word over it.
	DeepUi.spacer(me_row)
	_resonance_box = DeepUi.hbox(me_row, 5)
	_resonance_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_resonance_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resonance_box.tooltip_text = "Resonance: each gem that fires adds one, a neighbour of the same color adds two, a fizzle resets it. Your Birthstone reads it last."
	DeepUi.icon(_resonance_box, "resonance", 18, DeepUi.RESONANCE).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.heading(_resonance_box, "Resonance", 13, DeepUi.RESONANCE).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resonance_value = DeepUi.title(_resonance_box, "0", 20, DeepUi.RESONANCE)
	_resonance_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rail_box = DeepUi.hbox(left, 6)
	DeepUi.rule(columns, Color(DeepUi.LINE, 0.8)).custom_minimum_size = Vector2(1, 0)
	## Middle: the dice.
	var middle := DeepUi.vbox(columns, 6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tray_head := DeepUi.hbox(middle, 8)
	DeepUi.icon(tray_head, "die", 16, DeepUi.ACCENT)
	DeepUi.heading(tray_head, "Your hand", 13)
	DeepUi.spacer(tray_head)
	_hint = DeepUi.label(tray_head, "", 13, DeepUi.MUTED)
	_tray_box = DeepUi.hbox(middle, 8)
	_tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons := DeepUi.hbox(middle, 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_reroll_button = DeepUi.icon_button(buttons, "reroll", "Reroll", _reroll, 15, DeepUi.INFO)
	_reroll_button.tooltip_text = "Reroll the selected dice  [R]"
	_flip_button = DeepUi.icon_button(buttons, "eye", "Flip", _flip, 15, DeepUi.ACCENT)
	_flip_button.tooltip_text = "Sleight: turn one chosen die to the other side of its range, free, once a turn  [F]"
	_flip_button.visible = false
	_lock_button = DeepUi.primary(buttons, "check", "Lock in", _toggle_lock, 16)
	_lock_button.tooltip_text = "Lock in this hand  [Space]"
	DeepUi.rule(columns, Color(DeepUi.LINE, 0.8)).custom_minimum_size = Vector2(1, 0)
	## Right: what the hand would do.
	var right := DeepUi.vbox(columns, 6)
	right.custom_minimum_size = Vector2(250, 0)
	var forecast_head := DeepUi.hbox(right, 8)
	DeepUi.icon(forecast_head, "eye", 16, DeepUi.ACCENT)
	DeepUi.heading(forecast_head, "This hand would", 13)
	_forecast_box = DeepUi.vbox(right, 4)

func bind(player_id: String) -> void:
	local_id = player_id

func show_state(battle: Dictionary, at_depth: int, new_forecast: Dictionary = {}, new_context: Dictionary = {}) -> void:
	_shows += 1
	modulate.a = 1.0
	state = battle
	depth = at_depth
	## Once the hand is locked in, the forecast it was locked in with stays up: the rail keeps
	## showing what would fire, and each gem corrects it as it actually fires or fizzles.
	if str(battle.get("phase", "")) == "planning" or _held_forecast.is_empty():
		_held_forecast = new_forecast
	forecast = _held_forecast
	if not new_context.is_empty():
		context = new_context
	## Enemy ids start again at e0 in every fight, so a new fight is recognised by who is in
	## it and where, and everything pinned to the old one is let go.
	var signature: String = "%d|%s" % [depth, ",".join(state.get("enemies", []).map(func(e: Dictionary) -> String: return str(e.get("key", ""))))]
	if signature != _battle_signature:
		_battle_signature = signature
		_forget_fight()
	_rebuild_chamber()
	_place_creatures()
	_sync()

func _forget_fight() -> void:
	selected.clear()
	_pinned_enemy = ""
	if _enemy_panel != null:
		_enemy_panel.reset()
	_outcomes.clear()
	_birth_outcome = {}
	for id in _plates.keys():
		if is_instance_valid(_plates[id]):
			_plates[id].queue_free()
	_plates.clear()
	for id in _creatures.keys():
		if is_instance_valid(_creatures[id]):
			_creatures[id].queue_free()
	_creatures.clear()
	_intro_pending = true
	_awaited.clear()
	_layout_wait = null
	DeepAudio.play("battle_begin", {"volume": 0.9})
	if _screen_fx != null:
		_screen_fx.desaturate = 0.0
	if _camera != null and not stage.arrived_by_walk:
		_camera.reset()
		_camera.intro(1.2, bool(state.get("warden", false)))

func me() -> Dictionary:
	return DeepBattle.player(state, local_id)

func _sync() -> void:
	if state.is_empty():
		return
	var unit: Dictionary = me()
	var planning: bool = str(state.get("phase", "")) == "planning"
	## While the dice are still tumbling nothing on the rail is lit: the forecast is known the
	## instant the roll is, and a gem that came on a beat before its dice landed gave the
	## answer away. The rail is told again the moment they settle.
	var rolled: String = ",".join(unit.get("hand", []).map(func(r: Dictionary) -> String: return "%s:%d:%s" % [str(r.get("die_id", "")), int(r.get("value", 0)), str(r.get("rerolls", 0))]))
	if rolled != _rolled_hand:
		_rolled_hand = rolled
		if not _headless and is_inside_tree() and planning:
			_dice_settle_at = Time.get_ticks_msec() + int(DiceView.SPIN_SECONDS * 1000.0) + 60
			get_tree().create_timer(DiceView.SPIN_SECONDS + 0.09).timeout.connect(func() -> void:
				if is_instance_valid(self) and not state.is_empty():
					_sync())
	## A pick outlives its reroll; a die that came back locked drops out of it, and the whole
	## pick is let go once there are no rerolls left to spend on it.
	var movable: Array = DeepDice.rerollable(unit.get("hand", [])) if int(unit.get("rerolls", 0)) > 0 or int(unit.get("flips", 0)) > 0 else []
	selected = selected.filter(func(id: Variant) -> bool: return movable.has(str(id)))
	if _headless:
		_depth_label.text = "Depth %d" % depth
	(_turn_pill.get_child(0).get_node("Value") as Label).text = "Turn %d" % int(state.get("turn", 1))
	var living_foes: int = DeepBattle.living(state.get("enemies", [])).size()
	var foe_label: Label = _foes_pill.get_child(0).get_node("Value")
	foe_label.text = "%d %s" % [living_foes, "creature" if living_foes == 1 else "creatures"]
	if bool(state.get("warden", false)):
		foe_label.text = "Warden · " + foe_label.text
	elif bool(state.get("elite", false)):
		foe_label.text = "Elite · " + foe_label.text
	if not unit.is_empty():
		var ratio: float = float(unit.hp) / float(maxi(1, int(unit.max_hp)))
		_hp_bar.set_values(ratio, "%d / %d" % [int(unit.hp), int(unit.max_hp)], float(unit.block) / float(maxi(1, int(unit.max_hp))))
		if _screen_fx != null:
			_screen_fx.danger = clampf((0.3 - ratio) / 0.3, 0.0, 1.0) if not bool(unit.get("downed", false)) else 0.0
		DeepUi.clear(_status_row)
		if int(unit.block) > 0:
			DeepUi.pill(_status_row, "shield", str(int(unit.block)), DeepUi.BLOCK, 14, "Block: soaks damage before your health. Whatever is left falls away at the end of the turn.")
		var effects: Array = EffectChips.for_player(unit, state).filter(func(e: Dictionary) -> bool: return str(e.key) != "block")
		var passive: Dictionary = unit.get("passive", {})
		if not str(passive.get("text", "")).is_empty():
			effects.append(EffectChips.entry("passive", "spark", "", true, str(passive.get("name", DeepContent.character_title(str(unit.get("character", ""))))), str(passive.text), DeepUi.ACCENT))
		_effects.show_effects(effects)
		## While a turn resolves the rail's own events count the Resonance up, sparks and all.
		if planning:
			_show_resonance(int(forecast.get("totals", {}).get("resonance", 0)))
		elif _headless or str(state.get("phase", "")) != "resolving":
			_show_resonance(int(unit.get("resonance", 0)))
	_fight_effects.show_effects(EffectChips.for_battle(state))
	_sync_rail(unit, planning)
	_sync_tray(unit, planning)
	_sync_forecast()
	_sync_allies()
	_sync_plates()
	_sync_enemy_panel()
	var locked: bool = bool(unit.get("locked", false))
	var downed: bool = bool(unit.get("downed", false))
	var rerolls: int = int(unit.get("rerolls", 0))
	_reroll_button.disabled = not planning or locked or downed or rerolls <= 0 or selected.is_empty()
	_reroll_button.text = ("Reroll  %d left" % rerolls) if planning else "Resolving"
	_lock_button.disabled = not planning or downed
	_lock_button.text = "Unlock" if locked else "Lock in"
	var flips: int = int(unit.get("flips", 0))
	_flip_button.visible = str(unit.get("passive", {}).get("kind", "")) == "free_flip"
	_flip_button.disabled = not planning or locked or downed or flips <= 0 or selected.size() != 1
	_flip_button.text = "Flip" if flips > 0 or not planning else "Flipped"
	## When there is nothing left to decide, the lock button asks to be pressed.
	var waiting_on_me: bool = planning and not locked and not downed and ((rerolls <= 0 and flips <= 0) or selected.is_empty())
	if waiting_on_me and _lock_pulse == null:
		_lock_pulse = DeepUi.breathe(_lock_button, 0.7, 1.4)
	elif not waiting_on_me and _lock_pulse != null:
		_lock_pulse.kill()
		_lock_pulse = null
		_lock_button.modulate.a = 1.0
	if downed:
		_hint.text = "You are down. The party fights on."
	elif not planning:
		_hint.text = "Resolving…"
	elif locked:
		var waiting: Array = state.get("players", []).filter(func(p: Dictionary) -> bool: return not bool(p.get("locked", false)) and not bool(p.get("downed", false)))
		_hint.text = "Waiting for %s" % ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))) if not waiting.is_empty() else "Everyone is in."
	else:
		if rerolls <= 0 and flips > 0:
			_hint.text = "Pick one die to flip  [F], or lock in  [Space]"
		elif rerolls <= 0:
			_hint.text = "No rerolls left. Lock in  [Space]"
		else:
			_hint.text = "Click dice to reroll  [1-5]" if selected.is_empty() else "%d selected" % selected.size()

func _status_glyph(status: String) -> String:
	match status:
		"poison": return "drop"
		"stun": return "stun"
		"curse": return "eye"
		"resolve": return "shield"
	return "spark"

func _status_color(status: String) -> Color:
	match status:
		"poison": return DeepUi.POISON
		"stun": return Color("ffe27a")
		"curse": return Color("c58bff")
	return DeepUi.INFO

func _resonance_color(value: int) -> Color:
	if value <= 0:
		return DeepUi.DIM
	return DeepUi.ACCENT.lerp(Color("ff6a3a"), clampf(float(value - 1) / 6.0, 0.0, 1.0))

func _show_resonance(value: int) -> void:
	_resonance_token += 1
	_resonance_value.text = str(value)
	_resonance_value.add_theme_color_override("font_color", _resonance_color(value))

func _resonance_flight(card: Control, value: int, gain: int, color: Color, harmony: bool) -> void:
	## A gem that fires throws sparks of its own color up to the Resonance count, and the
	## number only ticks over when they land, so the chain is seen building gem by gem.
	var token: int = _resonance_token + 1
	_resonance_token = token
	var from: Vector2 = _center_of(card)
	var to: Vector2 = _center_of(_resonance_box)
	var count: int = clampi(4 + 3 * gain, 6, 16)
	var flight: float = 0.42
	for index in range(count):
		var spark := DeepUi.icon(self, "spark", randf_range(12.0, 19.0), color.lightened(randf_range(0.15, 0.55)))
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 40
		spark.pivot_offset = spark.custom_minimum_size * 0.5
		var start: Vector2 = from + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		## Each spark bows out to one side and up before it homes in, so they fan and gather.
		var bend: Vector2 = (start + to) * 0.5 + Vector2(randf_range(-90.0, 90.0), randf_range(-110.0, -40.0))
		var half: Vector2 = spark.custom_minimum_size * 0.5
		spark.position = start - half
		var delay: float = 0.03 * float(index)
		var tween := spark.create_tween()
		tween.tween_interval(delay)
		tween.tween_method(func(t: float) -> void:
			var eased: float = t * t * (3.0 - 2.0 * t)
			spark.position = start.lerp(bend, eased).lerp(bend.lerp(to, eased), eased) - half
			spark.rotation = t * 4.0
			spark.scale = Vector2.ONE * lerpf(1.1, 0.5, t), 0.0, 1.0, flight)
		tween.tween_callback(spark.queue_free)
	var land := create_tween()
	land.tween_interval(flight + 0.03 * float(count - 1) * 0.5)
	land.tween_callback(func() -> void:
		if token != _resonance_token:
			return
		_show_resonance(value)
		DeepUi.pulse(_resonance_box, 1.3, 0.3)
		DeepUi.burst(self, to, _resonance_color(value), 10 + 2 * gain, 110.0, 0.4, 4.0)
		if harmony:
			DeepAudio.from(_resonance_box, "harmony", {"volume": 0.7})
			_float_at(_resonance_box, "+%d harmony" % gain, DeepUi.ACCENT_HI, 15))

func _sync_rail(unit: Dictionary, planning: bool) -> void:
	## Lit while the hand is chosen and on through the resolution it was locked in for, and
	## never while the dice that decide it are still in the air.
	var showing: bool = (planning or str(state.get("phase", "")) == "resolving") and Time.get_ticks_msec() >= _dice_settle_at
	var rail: Array = unit.get("rail", [])
	var birth_key: String = str(unit.get("character", ""))
	if _socket_cards.size() != rail.size() or _birthstone_key != birth_key or (_birthstone_card != null and not is_instance_valid(_birthstone_card)):
		DeepUi.clear(_rail_box)
		_socket_cards.clear()
		_birthstone_card = null
		_birthstone_key = birth_key
		for socket in range(rail.size()):
			var card := VBoxContainer.new()
			card.add_theme_constant_override("separation", 2)
			card.alignment = BoxContainer.ALIGNMENT_CENTER
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			_rail_box.add_child(card)
			_socket_cards.append(card)
		if not unit.get("birthstone", {}).is_empty():
			_birthstone_card = _build_birthstone_card(unit)
			_rail_box.add_child(_birthstone_card)
	var sockets: Array = unit.get("sockets", [])
	for socket in range(rail.size()):
		var card: VBoxContainer = _socket_cards[socket]
		var stone: Variant = rail[socket]
		var socket_color: String = str(sockets[socket]) if socket < sockets.size() else "ANY"
		var tag: String = "%s|%s" % [DeepUi.stone_marks(stone) if stone is Dictionary else "", socket_color]
		if str(card.get_meta("tag", "")) != tag:
			card.set_meta("tag", tag)
			DeepUi.clear(card)
			var slot := Control.new()
			slot.name = "Slot"
			slot.custom_minimum_size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
			slot.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_child(slot)
			var ring := SocketRing.new(socket_color, stone == null)
			ring.name = "Ring"
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(ring)
			if stone is Dictionary:
				var picture := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 12)
				picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
				picture.tooltip_text = DeepStone.name(stone) + "\n" + DeepStone.text(stone)
				slot.add_child(picture)
				var trigger_row := HBoxContainer.new()
				trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
				trigger_row.name = "Trigger"
				trigger_row.mouse_filter = Control.MOUSE_FILTER_PASS
				card.add_child(trigger_row)
				var name_label := DeepUi.label(card, str(DeepStone.skill_of(stone).get("name", stone.skill)), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
				name_label.name = "SkillName"
				name_label.custom_minimum_size.x = SOCKET_EDGE + 8
				name_label.clip_text = true
			else:
				## The same rows a filled socket has, the trigger one empty: the cards are
				## centred against one another, and one row short would hang the empty
				## socket lower than every stone beside it.
				var blank := HBoxContainer.new()
				blank.custom_minimum_size.y = 15
				blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(blank)
				DeepUi.label(card, socket_color.capitalize() if socket_color != "ANY" else "Any", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if stone is Dictionary:
			var entry: Dictionary = {}
			for candidate in forecast.get("sockets", []):
				if int(candidate.get("socket", -1)) == socket:
					entry = candidate
			var trigger_row: Node = card.get_node_or_null("Trigger")
			var ring: SocketRing = card.get_node_or_null("Slot/Ring")
			var active: bool = bool(entry.get("active", false))
			## Once the gem has resolved, what it really did outranks what was forecast.
			if not planning and _outcomes.has(socket):
				active = bool(_outcomes[socket])
			if ring != null:
				ring.set_ready(active and showing)
			if trigger_row != null:
				var described: Dictionary = entry.get("trigger", DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(stone.get("cut", 0))))
				var tone: Color = DeepUi.GOOD if active and showing else (DeepUi.PAPER if entry.is_empty() else DeepUi.DIM)
				var key: String = "%s|%s|%s" % [str(described.get("mark", "")), str(described.get("label", "")), str(tone)]
				if str(trigger_row.get_meta("key", "")) != key:
					trigger_row.set_meta("key", key)
					DeepUi.clear(trigger_row)
					DiceIcons.build(trigger_row, described, 15, tone, str(described.get("words", "")) + ("" if active or entry.is_empty() else "\n" + str(entry.get("reason", ""))))
			var blocked: bool = unit.get("buried", []).has(socket) or unit.get("clouded", []).has(socket)
			card.modulate = Color(0.55, 0.55, 0.6, 0.6) if blocked else Color.WHITE
			card.tooltip_text = ("Buried in rubble: this gem cannot fire this turn." if unit.get("buried", []).has(socket) else "Clouded: hit the Clouder to clear it.") if blocked else ""
	_sync_birthstone(unit, planning, showing)

func _build_birthstone_card(unit: Dictionary) -> VBoxContainer:
	## The character's Birthstone at the end of the rail: the stone in its own bezel, its
	## name, and its tiers as marks that light when the hand in the tray would fire them.
	var stone: Dictionary = DeepStone.birthstone(str(unit.get("character", "")))
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var slot := Control.new()
	slot.name = "Slot"
	slot.custom_minimum_size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(slot)
	var ring := SocketRing.new("BIRTHSTONE", false)
	ring.name = "Ring"
	ring.birth_tint = tint
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if not stone.is_empty():
		var picture := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 12)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		picture.tooltip_text = "%s, your Birthstone\n%s" % [str(stone.get("name", "")), str(stone.get("text", ""))]
		slot.add_child(picture)
	## One row at the sockets' trigger size, so the tiers sit level with every other
	## requirement on the rail and the name lines up with theirs.
	var tiers := HBoxContainer.new()
	tiers.name = "Tiers"
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers.add_theme_constant_override("separation", 3)
	tiers.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(tiers)
	var name_label := DeepUi.label(card, str(stone.get("name", "Birthstone")), 11, tint.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.name = "Name"
	name_label.custom_minimum_size.x = SOCKET_EDGE + 8
	name_label.clip_text = true
	return card

func _sync_birthstone(unit: Dictionary, planning: bool, showing: bool) -> void:
	if _birthstone_card == null or not is_instance_valid(_birthstone_card):
		return
	## The forecast until the Birthstone has actually resolved this turn, then what it did.
	var preview: Dictionary = _birth_outcome if not planning and not _birth_outcome.is_empty() else forecast.get("birthstone", {})
	var defs: Array = unit.get("birthstone", {}).get("tiers", [])
	var previewed: Array = preview.get("tiers", [])
	## The bezel wakes for a tier worth firing; a penalty on its own (a Bust) leaves it dark.
	var rewarded: bool = false
	for index in range(mini(defs.size(), previewed.size())):
		if bool(previewed[index].get("active", false)) and not bool(defs[index].get("penalty", false)):
			rewarded = true
	var ring: SocketRing = _birthstone_card.get_node_or_null("Slot/Ring")
	if ring != null:
		ring.set_ready(rewarded and showing)
	var tiers_row: Node = _birthstone_card.get_node_or_null("Tiers")
	if tiers_row == null:
		return
	## Tiers that count more of one die are five dice, lit for every die a firing tier
	## counted (the whole set, every crown), never fewer than that tier needs.
	var die: String = DiceIcons.ladder_die(defs)
	var lit: int = 0
	var key: String = ""
	for index in range(defs.size()):
		var active: bool = index < previewed.size() and bool(previewed[index].get("active", false)) and showing
		key += "1" if active else "0"
		var rung: int = DiceIcons.ladder_rung(defs[index], die)
		if active and rung > 0:
			lit = mini(5, maxi(lit, maxi(rung, previewed[index].get("dice", []).size())))
	key += "|%d" % lit
	if str(tiers_row.get_meta("key", "")) == key:
		return
	tiers_row.set_meta("key", key)
	DeepUi.clear(tiers_row)
	var notes: Array = []
	for index in range(defs.size()):
		var reason: String = str(previewed[index].get("reason", "")) if index < previewed.size() else ""
		notes.append(reason if key[index] == "0" and showing else "")
	if not die.is_empty():
		DiceIcons.build_ladder(tiers_row, defs, die, lit, 14, DeepUi.GOOD, DeepUi.DIM, notes)
	for index in range(defs.size()):
		var tier: Dictionary = defs[index]
		if DiceIcons.ladder_rung(tier, die) > 0:
			continue
		var words: String = "%s: %s" % [str(tier.get("name", "")), str(tier.get("text", ""))]
		if not str(notes[index]).is_empty():
			words += "\n" + str(notes[index])
		var lit_tone: Color = DeepUi.BAD if bool(tier.get("penalty", false)) else DeepUi.GOOD
		DiceIcons.build(tiers_row, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 15, lit_tone if key[index] == "1" else DeepUi.DIM, words)

class SocketRing extends Control:
	## A character's socket: a bezel in the socket's color, a crown for the Birthstone, and a
	## glow that wakes when the hand in the tray would fire the stone set in it.
	var color: String = "ANY"
	var empty: bool = false
	var birth_tint: Color = DeepUi.ACCENT
	var _ready_glow: float = 0.0
	var _goal: float = 0.0
	var _clock: float = 0.0
	var _flash: float = 0.0
	func _init(socket_color: String, is_empty: bool) -> void:
		color = socket_color
		empty = is_empty
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_ready(on: bool) -> void:
		_goal = 1.0 if on else 0.0
		set_process(true)
	func fire() -> void:
		_flash = 1.0
		set_process(true)
	func _process(delta: float) -> void:
		_clock += delta
		_ready_glow = move_toward(_ready_glow, _goal, delta * 4.0)
		_flash = maxf(0.0, _flash - delta * 2.2)
		queue_redraw()
		if _flash <= 0.0 and is_equal_approx(_ready_glow, _goal) and _goal <= 0.0:
			set_process(false)
	func _draw() -> void:
		var tone: Color = birth_tint.lightened(0.15) if color == "BIRTHSTONE" else (DeepUi.color(color) if color != "ANY" else DeepUi.MUTED)
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.47
		if _ready_glow > 0.01 or _flash > 0.0:
			var pulse: float = 0.75 + 0.25 * sin(_clock * 5.0)
			var reach: float = radius * (2.4 + _flash * 1.2)
			draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(tone.lerp(Color.WHITE, _flash * 0.5), 0.35 * _ready_glow * pulse + 0.8 * _flash))
		draw_circle(centre, radius, Color(0, 0, 0, 0.45))
		draw_circle(centre, radius * 0.9, Color(tone, 0.08 if empty else 0.12))
		draw_arc(centre, radius, 0, TAU, 48, Color(tone, 0.95 if empty else 0.75), 3.0 if color == "BIRTHSTONE" else 2.0, true)
		draw_arc(centre, radius * 0.82, 0, TAU, 40, Color(tone, 0.25), 1.0, true)
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0 + PI * 0.25
			draw_circle(centre + Vector2.from_angle(angle) * radius * 0.92, 2.2, Color(tone.lightened(0.3), 0.9))
		if color == "BIRTHSTONE":
			var crown := PackedVector2Array([centre + Vector2(-9, -radius - 1), centre + Vector2(-5, -radius - 8), centre + Vector2(0, -radius - 3),
				centre + Vector2(5, -radius - 8), centre + Vector2(9, -radius - 1)])
			draw_colored_polygon(crown, tone.lightened(0.2))

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
		var index: int = 0
		for id in wanted:
			index += 1
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE + 16)
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
			_tray_box.add_child(holder)
			var view := DiceView.new()
			view.position = Vector2.ZERO
			view.size = Vector2(DIE_EDGE, DIE_EDGE)
			view.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE)
			holder.add_child(view)
			var value := DeepUi.label(holder, "", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			value.position = Vector2(0, DIE_EDGE + 2)
			value.size = Vector2(DIE_EDGE, 18)
			value.name = "Value"
			var key_hint := DeepUi.label(holder, str(index), 10, DeepUi.DIM)
			key_hint.position = Vector2(4, 2)
			var hit := Button.new()
			hit.flat = true
			hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				hit.add_theme_stylebox_override(style, StyleBoxEmpty.new())
			hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			hit.pressed.connect(_toggle_die.bind(id))
			hit.mouse_entered.connect(func() -> void: view.set_highlight(true))
			hit.mouse_exited.connect(func() -> void: view.set_highlight(false))
			hit.tooltip_text = "Left-click to choose it for a reroll. Right-click for everything about it."
			hit.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					_inspect_die(id)
					hit.accept_event())
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
		var chosen: bool = selected.has(id) and can_select
		view.configure(by_id.get(id, {"key": roll.key, "shape": roll.shape, "faces": []}), tagged, chosen, false, DeepUi.ACCENT)
		var lift: float = -10.0 if chosen else 0.0
		if not is_equal_approx(view.position.y, lift) and not _headless:
			var tween := view.create_tween()
			tween.tween_property(view, "position:y", lift, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var value: Label = view.get_parent().get_node("Value")
		## The die itself shows its number; only what the number cannot say goes under it.
		var words: String = ""
		if str(roll.get("kind", "plain")) != "plain":
			words = DiceIcons.face_text(int(roll.value), str(roll.get("kind", "plain"))).strip_edges()
		if bool(roll.get("locked", false)):
			words += "  ⌂"
		if bool(roll.get("flipped", false)):
			words += "  ⇅"
		if bool(roll.get("loaded", false)):
			words += "  ↻"
		value.text = words.strip_edges()
		value.add_theme_color_override("font_color", DeepUi.ACCENT if chosen else DeepUi.MUTED)

func _sync_forecast() -> void:
	DeepUi.clear(_forecast_box)
	var totals: Dictionary = forecast.get("totals", {})
	if totals.is_empty():
		DeepUi.label(_forecast_box, "—", 14, DeepUi.DIM)
		return
	var rows: Array = [["sword", "damage", DeepUi.BAD, "Damage"], ["shield", "block", DeepUi.BLOCK, "Block"], ["heart", "heal", DeepUi.GOOD, "Healing"],
		["ore", "gold", DeepUi.ORE, "Ore"], ["drop", "poison", DeepUi.POISON, "Poison"]]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forecast_box.add_child(grid)
	var any: bool = false
	for row in rows:
		var amount: int = int(totals.get(row[1], 0))
		if amount <= 0:
			continue
		any = true
		var cell := DeepUi.hbox(grid, 5)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = str(row[3])
		DeepUi.icon(cell, str(row[0]), 20, row[2], str(row[3]))
		DeepUi.title(cell, str(amount), 22, row[2])
	if not any:
		DeepUi.label(_forecast_box, "Nothing fires on this hand.", 13, DeepUi.DIM)
	var summary := DeepUi.hbox(_forecast_box, 10)
	var fires: int = int(totals.get("fires", 0))
	var fizzles: int = int(totals.get("fizzles", 0))
	DeepUi.stat(summary, "check", str(fires), DeepUi.GOOD, 13, "Gems that would fire")
	DeepUi.stat(summary, "cross_out", str(fizzles), DeepUi.DIM if fizzles == 0 else DeepUi.BAD, 13, "Gems that would fizzle")
	DeepUi.spacer(summary)
	DeepUi.stat(summary, "spark", str(int(totals.get("resonance", 0))), _resonance_color(int(totals.get("resonance", 0))), 13, "Resonance this hand would build")

func _sync_allies() -> void:
	var present: Dictionary = {}
	for unit in state.get("players", []):
		var id: String = str(unit.id)
		if id == local_id:
			continue
		present[id] = true
		var card: AllyCard = _ally_cards.get(id, null)
		if card == null or not is_instance_valid(card):
			card = AllyCard.new()
			_ally_box.add_child(card)
			_ally_cards[id] = card
			DeepUi.pop_in(card)
		card.update(unit, str(state.get("phase", "")) == "planning")
	for id in _ally_cards.keys():
		if not present.has(id):
			if is_instance_valid(_ally_cards[id]):
				_ally_cards[id].queue_free()
			_ally_cards.erase(id)

class AllyCard extends PanelContainer:
	## Another player, compact: health, what they are doing, and the hand they rolled.
	var _name: Label
	var _note: Label
	var _bar: DeepUi.Bar
	var _hand: HBoxContainer
	var _effects: EffectChips.Row
	var _key: String = ""
	func _init() -> void:
		add_theme_stylebox_override("panel", DeepUi.raised(Color(0.06, 0.075, 0.105, 0.88), DeepUi.LINE, 12, 10, 0.4))
		mouse_filter = Control.MOUSE_FILTER_PASS
		var box := DeepUi.vbox(self, 5)
		var head := DeepUi.hbox(box, 6)
		DeepUi.icon(head, "person", 16, DeepUi.INFO)
		_name = DeepUi.label(head, "", 14, DeepUi.PAPER)
		DeepUi.spacer(head)
		_note = DeepUi.label(head, "", 11, DeepUi.MUTED)
		_bar = DeepUi.bar(box, 10.0)
		_hand = DeepUi.hbox(box, 3)
		_effects = EffectChips.Row.new(13)
		box.add_child(_effects)
	func update(unit: Dictionary, planning: bool) -> void:
		_effects.show_effects(EffectChips.for_player(unit))
		var who: String = str(DeepContent.character(str(unit.get("character", ""))).get("name", ""))
		_name.text = str(unit.name) + ("" if who.is_empty() else " · " + who)
		var note: String = "down" if bool(unit.get("downed", false)) else ("locked in" if bool(unit.get("locked", false)) else "choosing")
		if not bool(unit.get("connected", true)):
			note = "away"
		if not planning and not bool(unit.get("downed", false)):
			note = "resonance %d" % int(unit.get("resonance", 0))
		_note.text = note
		_note.add_theme_color_override("font_color", DeepUi.GOOD if note == "locked in" else (DeepUi.BAD if note == "down" else DeepUi.MUTED))
		_bar.set_values(float(unit.hp) / float(maxi(1, int(unit.max_hp))), "%d" % int(unit.hp), float(unit.block) / float(maxi(1, int(unit.max_hp))))
		var faces: Array = []
		for roll in unit.get("hand", []):
			if not bool(roll.get("phantom", false)):
				faces.append("%d:%s" % [int(roll.value), str(roll.get("shape", "D6"))])
		var key: String = ",".join(faces)
		if key != _key:
			_key = key
			DeepUi.clear(_hand)
			for roll in unit.get("hand", []):
				if not bool(roll.get("phantom", false)):
					_hand.add_child(DiceIcons.face(20, int(roll.value), DiceIcons.palette(str(roll.get("key", "D6"))).body, str(roll.get("shape", "D6")), true, DiceIcons.face_text(int(roll.value), str(roll.get("kind", "plain")))))
		modulate = Color(1, 1, 1, 0.55) if bool(unit.get("downed", false)) else Color.WHITE
	func hurt() -> void:
		DeepUi.shake(self, 8.0, 0.35)
		var tween := create_tween()
		self_modulate = Color(1.6, 0.6, 0.6)
		tween.tween_property(self, "self_modulate", Color.WHITE, 0.4)

func _sync_plates() -> void:
	var present: Dictionary = {}
	var target_id: String = str(me().get("target", ""))
	var preview: int = int(forecast.get("totals", {}).get("damage", 0)) if str(state.get("phase", "")) == "planning" else 0
	for foe in state.get("enemies", []):
		var id: String = str(foe.id)
		present[id] = true
		var plate: Plate = _plates.get(id, null)
		if int(foe.hp) <= 0:
			if plate != null and is_instance_valid(plate) and not plate.fading:
				plate.fade()
			continue
		if plate == null or not is_instance_valid(plate) or plate.fading:
			if plate != null and is_instance_valid(plate):
				plate.queue_free()
			plate = Plate.new()
			plate.gui_input.connect(_plate_input.bind(id))
			plate.expand.connect(func() -> void: _pin_enemy(id))
			plate.inspect.connect(func(move: String) -> void: _inspect_creature(id, move))
			plate.mouse_entered.connect(func() -> void: _hover_creature(id))
			plate.mouse_exited.connect(func() -> void: _hover_creature(""))
			_plates_layer.add_child(plate)
			_plates[id] = plate
			DeepUi.pop_in(plate, 0.4)
		plate.update(foe, state, local_id, target_id == id, preview if target_id == id else 0)
	for id in _plates.keys():
		if not present.has(id):
			if is_instance_valid(_plates[id]):
				_plates[id].queue_free()
			_plates.erase(id)

class Plate extends PanelContainer:
	## A creature's nameplate: health with a ghost of what this hand would take off it,
	## its buffs, ordered dice and compact ability icons.
	## Hover for the moveset, pin it with Moves, or right-click for the inspector.
	signal inspect(move: String)
	signal expand()
	var fading: bool = false
	var _name: Label
	var _target: TextureRect
	var _bar: DeepUi.Bar
	var _effects: EffectChips.Row
	var _dice: HBoxContainer
	var _abilities: HBoxContainer
	var _moves_key: String = ""
	var _chip_key: String = ""
	var _targeted: bool = false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style(false)
		var box := DeepUi.vbox(self, 4)
		var head := DeepUi.hbox(box, 6)
		_target = DeepUi.icon(head, "crosshair", 15, DeepUi.ACCENT, "Your target")
		_name = DeepUi.label(head, "", 14, DeepUi.PAPER)
		_name.add_theme_font_override("font", DeepUi.display_font())
		DeepUi.spacer(head)
		_dice = DeepUi.hbox(head, 2)
		_bar = DeepUi.bar(box, 15.0, DeepUi.BAD, DeepUi.HP_LOST)
		_bar.custom_minimum_size = Vector2(170, 15)
		_effects = EffectChips.Row.new(14)
		box.add_child(_effects)
		var footer := DeepUi.hbox(box, 6)
		_abilities = DeepUi.hbox(footer, 6)
		DeepUi.spacer(footer)
		DeepUi.button(footer, "Moves", func() -> void: expand.emit(), 11)
		gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				inspect.emit("")
				accept_event())
	func _style(targeted: bool) -> void:
		var style := DeepUi.raised(Color(0.05, 0.06, 0.09, 0.86), DeepUi.ACCENT if targeted else Color(DeepUi.LINE_HI, 0.7), 10, 9, 0.5)
		if targeted:
			style.set_border_width_all(2)
			style.shadow_color = Color(DeepUi.ACCENT, 0.35)
			style.shadow_size = 14
		add_theme_stylebox_override("panel", style)
	func update(foe: Dictionary, battle: Dictionary, local_id: String, targeted: bool, preview: int) -> void:
		if targeted != _targeted:
			_targeted = targeted
			_style(targeted)
			if targeted:
				DeepUi.pulse(self, 1.06, 0.3)
		_target.visible = targeted
		_name.text = str(foe.name)
		_name.add_theme_color_override("font_color", Color("ffb0a0") if bool(foe.get("warden", false)) else DeepUi.PAPER)
		var max_hp: int = maxi(1, int(foe.max_hp))
		_bar.set_values(float(foe.hp) / float(max_hp), "%d / %d" % [int(foe.hp), max_hp])
		_bar.preview = clampf(float(maxi(0, preview - int(foe.block))) / float(max_hp), 0.0, 1.0)
		tooltip_text = str(foe.get("text", "")) + "\nLeft-click to target it. Right-click for everything about it."
		_effects.show_effects(EffectChips.for_enemy(foe, battle))
		var dice: Array = DeepCreatures.effective_dice(foe)
		var moves: Array = DeepCreatures.display_moves(foe, foe.get("moves", DeepCreatures.moves_for(foe)))
		var moves_key: String = str(dice) + str(moves) + str(foe.get("stolen_dice", 0)) + str(foe.get("suppressed", 0))
		if moves_key == _moves_key:
			return
		_moves_key = moves_key
		DeepUi.clear(_dice)
		var suppressed: int = int(foe.get("suppressed", 0)) if bool(foe.get("acting", false)) else int(foe.get("stolen_dice", 0))
		for index in range(dice.size()):
			_dice.add_child(DiceIcons.face(16, 0, DeepUi.DIM if index >= dice.size() - suppressed else DiceIcons.palette(str(dice[index].key)).body, str(dice[index].shape), false, "×" if index >= dice.size() - suppressed else "?"))
			DeepUi.label(_dice, str(dice[index].shape).to_lower() + ("×" if index >= dice.size() - suppressed else ""), 11, DeepUi.DIM if index >= dice.size() - suppressed else DeepUi.MUTED)
		DeepUi.clear(_abilities)
		for move in moves:
			var tip: String = str(move.name) + " · " + DeepCreatures.trigger_words(move)
			for effect in move.get("effects", []):
				tip += "\n" + DeepCreatures.effect_words(effect)
			var mark: String = GemIcons.emblem(str(move.name).to_upper())
			DeepUi.icon(_abilities, mark, 17, DeepUi.BAD, tip)
	func fade() -> void:
		fading = true
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void: visible = false)

func _plate_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_target(id)

func _pin_enemy(id: String) -> void:
	_pinned_enemy = "" if _pinned_enemy == id else id
	_sync_enemy_panel()

func _sync_enemy_panel() -> void:
	if _enemy_panel == null:
		return
	var id: String = _pinned_enemy if not _pinned_enemy.is_empty() else _hovered_creature
	for foe in state.get("enemies", []):
		if bool(foe.get("acting", false)) and int(foe.hp) > 0:
			id = str(foe.id)
			break
	var foe: Dictionary = DeepBattle.enemy(state, id)
	if foe.is_empty() or int(foe.get("hp", 0)) <= 0:
		_enemy_panel.reset()
		return
	_enemy_panel.show_enemy(foe, int(state.get("turn", 0)), id == _pinned_enemy)
	_position_enemy_panel()

func _position_enemy_panel() -> void:
	if _enemy_panel == null or not _enemy_panel.visible:
		return
	var living: Array = DeepBattle.living(state.get("enemies", []))
	var index: int = 0
	for i in range(living.size()):
		if str(living[i].id) == _enemy_panel.enemy_id:
			index = i
	# Put the table opposite the acting creature; reserve the party cards on the right.
	var right: float = size.x - 20.0
	if not _ally_cards.is_empty():
		right -= _ally_box.size.x + 20.0
	var left: bool = index >= living.size() / 2
	_enemy_panel.position = Vector2(20.0 if left else maxf(20.0, right - _enemy_panel.size.x), 82.0)

func _inspect_creature(id: String, move: String) -> void:
	var foe: Dictionary = DeepBattle.enemy(state, id)
	if not foe.is_empty():
		Inspector.creature(foe, state, {"move": move})

func _inspect_die(id: String) -> void:
	var unit: Dictionary = me()
	for die in unit.get("dice", []):
		if str(die.id) == id:
			var roll: Dictionary = {}
			for candidate in unit.get("hand", []):
				if str(candidate.get("die_id", "")) == id:
					roll = candidate
			Inspector.die(die, {"roll": roll})
			return

func _target(id: String) -> void:
	if str(me().get("target", "")) != id:
		command.emit({"kind": "target", "enemy": id})
		if _creatures.has(id) and is_instance_valid(_creatures[id]) and not _headless:
			var creature: CrystalCreature = _creatures[id]
			_fx.ring_wave(creature.global_position, DeepUi.ACCENT, 1.6, 0.4, 0.12)

func _hover_creature(id: String) -> void:
	if id == _hovered_creature:
		return
	if _creatures.has(_hovered_creature) and is_instance_valid(_creatures[_hovered_creature]):
		_creatures[_hovered_creature].set_hovered(false)
	_hovered_creature = id
	_sync_enemy_panel()
	if _creatures.has(id) and is_instance_valid(_creatures[id]):
		_creatures[id].set_hovered(true)

func _creature_at(local: Vector2) -> String:
	## The creature under a point on the screen: nearest to the line from its feet to its head.
	var best: String = ""
	var best_distance: float = 70.0
	for id in _creatures:
		var creature: CrystalCreature = _creature(str(id))
		if creature == null or bool(creature.get_meta("dying", false)):
			continue
		## Read off where the creature stands rather than where it is breathing: a hovering
		## wraith would otherwise slide out from under the pointer as it drifted.
		var stood: Vector3 = creature.rest_position
		var feet: Vector2 = _to_screen(stood)
		var head: Vector2 = _to_screen(stood + Vector3(0, creature.anchor.y * 0.9, 0))
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(local, feet, head)
		var distance: float = local.distance_to(closest)
		if distance < best_distance:
			best_distance = distance
			best = str(id)
	return best

func _pick_input(event: InputEvent) -> void:
	if _headless or _camera == null:
		return
	if event is InputEventMouseMotion:
		var id := _creature_at(event.position)
		_hover_creature(id)
		_picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not id.is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _creature_at(event.position)
		if not id.is_empty():
			_target(id)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var id := _creature_at(event.position)
		if not id.is_empty():
			_inspect_creature(id, "")

# --- space ---------------------------------------------------------------------------------

func _to_screen(point: Vector3) -> Vector2:
	return stage.to_screen(point) + (stage.global_position - global_position)

func _from_screen(local: Vector2, distance: float) -> Vector3:
	return stage.from_screen(local - (stage.global_position - global_position), distance)

func _control_world(control: Control, distance: float = 1.8) -> Vector3:
	## A point in the room just in front of the camera, behind a control on the HUD.
	var local: Vector2 = control.global_position + control.size * 0.5 - global_position
	return _from_screen(local, distance)

func _process(delta: float) -> void:
	_position_enemy_panel()
	if _headless or _camera == null or not is_visible_in_tree():
		return
	## The plates ride above the creatures' heads. `highest` is how far the worst of them
	## sits below the top of the screen, which is what the camera frames by.
	var ceiling: float = 72.0
	var highest: float = INF
	for id in _plates:
		var node: Variant = _plates[id]
		if node == null or not is_instance_valid(node):
			continue
		var plate: Plate = node
		if not plate.visible:
			continue
		var creature: CrystalCreature = _creature(id)
		if creature == null:
			continue
		## Its mark on the floor, not its body: a creature that breathes, rears or reels must
		## not drag its own plate about while somebody is trying to read it.
		var stood: Vector3 = creature.rest_position
		var world_point: Vector3 = stood + Vector3(0, creature.anchor.y + 0.15, 0)
		if _camera.is_position_behind(world_point):
			continue
		var screen: Vector2 = _to_screen(world_point)
		var goal: Vector2 = screen - Vector2(plate.size.x * 0.5, plate.size.y + 12)
		if not plate.fading and not bool(creature.get_meta("dying", false)):
			highest = minf(highest, goal.y)
		if goal.y < ceiling:
			## No room over its head: the plate stands beside it instead of across its face.
			var body: Vector2 = _to_screen(stood + Vector3(0, creature.anchor.y * 0.55, 0))
			var reach: float = absf(_to_screen(stood + Vector3(1.2 * creature.scale.x, 0, 0)).x - _to_screen(stood).x)
			var right_side: bool = body.x < size.x * 0.6
			goal = Vector2(body.x + reach + 16.0 if right_side else body.x - reach - 16.0 - plate.size.x, body.y - plate.size.y * 0.5)
		goal.x = clampf(goal.x, 8.0, size.x - plate.size.x - 8.0)
		goal.y = clampf(goal.y, ceiling, size.y - plate.size.y - 260.0)
		plate.position = plate.position.lerp(goal, clampf(delta * 14.0, 0.0, 1.0)) if plate.position != Vector2.ZERO else goal
	_frame_camera(highest, ceiling, delta)
	var dock_top: float = _dock.position.y if _dock != null else size.y - 200.0
	_effects_box.position = Vector2(22.0, dock_top - _effects_box.size.y - 8.0)

func _frame_camera(highest: float, ceiling: float, delta: float) -> void:
	## A tall Warden and its plate must fit under the top of the screen: the view widens and
	## lifts a little until they do, and settles back when a smaller creature is left.
	if not _camera.has_method("settled") or not _camera.settled() or is_inf(highest):
		return
	var fov: float = _camera.home_fov
	if highest < ceiling + 6.0:
		fov = minf(84.0, fov + delta * clampf((ceiling + 6.0 - highest) * 0.35, 4.0, 30.0))
	elif highest > ceiling + 90.0 and fov > BASE_FOV:
		fov = maxf(BASE_FOV, fov - delta * 6.0)
	_camera.home_fov = fov
	_camera.home_look.y = 1.2 + (fov - BASE_FOV) * 0.05

func apply_quality() -> void:
	## The settings menu changed the graphics setting: the stage takes it up, even mid-fight.
	stage.apply_quality()

func apply_look() -> void:
	## Likewise the outline setting.
	stage.apply_look()

# --- input ---------------------------------------------------------------------------------

func _toggle_die(id: String) -> void:
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or bool(unit.get("locked", false)) or (int(unit.get("rerolls", 0)) <= 0 and int(unit.get("flips", 0)) <= 0):
		return
	if selected.has(id):
		selected.erase(id)
		DeepAudio.play("die_drop", {"gap": 0.0})
	else:
		selected.append(id)
		DeepAudio.play("die_pick", {"gap": 0.0})
	_sync()

func _reroll() -> void:
	if selected.is_empty():
		return
	command.emit({"kind": "reroll", "dice": selected.duplicate()})
	DeepAudio.play("dice_reroll", {"volume": 0.8})
	if not _headless:
		for id in selected:
			if _dice_views.has(id):
				var view: Control = _dice_views[id]
				DeepUi.burst(self, view.global_position - global_position + view.size * 0.5, DeepUi.INFO, 14, 140.0, 0.5)
	## The picked dice stay picked, so pressing Reroll again throws the same ones.

func _flip() -> void:
	## Sleight: the one chosen die turns over.
	if selected.size() != 1 or int(me().get("flips", 0)) <= 0 or bool(me().get("locked", false)):
		return
	var id: String = str(selected[0])
	command.emit({"kind": "flip", "die": id})
	DeepAudio.play("die_pick", {"volume": 0.9})
	if not _headless and _dice_views.has(id):
		var view: Control = _dice_views[id]
		DeepUi.burst(self, view.global_position - global_position + view.size * 0.5, DeepUi.ACCENT_HI, 16, 150.0, 0.5)
	selected.clear()

func _toggle_lock() -> void:
	var locking: bool = not bool(me().get("locked", false))
	command.emit({"kind": "lock" if locking else "unlock"})
	DeepAudio.play("dice_lock" if locking else "ui_back", {"volume": 0.8})
	if locking and not _headless:
		DeepUi.pulse(_lock_button, 1.12, 0.3)
		for id in _dice_views:
			var view: Control = _dice_views[id]
			DeepUi.burst(self, view.global_position - global_position + view.size * 0.5, DeepUi.ACCENT, 8, 90.0, 0.4, 4.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R: _reroll()
		KEY_F: _flip()
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
	if kind == "turn_begin":
		selected.clear()
	## What the local rail really did this turn, kept so its highlights follow the dice.
	if kind in ["turn_begin", "resolution_begin"]:
		_outcomes.clear()
		_birth_outcome = {}
	elif str(event.get("unit", "")) == local_id:
		match kind:
			"gem_fire": _outcomes[int(event.get("socket", -1))] = true
			"gem_fizzle": _outcomes[int(event.get("socket", -1))] = false
			"birthstone": _birth_outcome = event
	if _enemy_panel != null:
		match kind:
			"enemy_roll": _enemy_panel.roll_die(event)
			"enemy_ability": _enemy_panel.power(event)
			"enemy_move": _enemy_panel.impact(event)
	if _headless or stage.walking():
		return
	match kind:
		"turn_begin":
			DeepAudio.play("turn_begin", {"volume": 0.7})
			_announce("Turn %d" % int(event.get("turn", 1)), DeepUi.PAPER, "Roll, reroll, lock in", 0.9)
			_camera.nudge(Vector3(0, 0.08, -0.15), 0.6)
		"resolution_begin":
			DeepAudio.play("resolve", {"volume": 0.75})
			_announce("Resolve", DeepUi.ACCENT, "", 0.5)
			_camera.punch(-3.0, 0.8)
			_screen_fx.blink(DeepUi.ACCENT, 0.06)
		"rail_begin":
			if str(event.get("unit", "")) == local_id:
				_show_resonance(0)
				if int(event.get("healed", 0)) > 0:
					DeepAudio.play("heal", {"volume": 0.6})
					_float_at(_hp_bar, "+%d Second Wind" % int(event.healed), DeepUi.GOOD, 20)
			elif int(event.get("healed", 0)) > 0 and _ally_cards.has(str(event.get("unit", ""))):
				_float_at(_ally_cards[str(event.unit)], "+%d" % int(event.healed), DeepUi.GOOD, 16)
		"gem_fire":
			_gem_fire(event)
		"gem_fizzle":
			_gem_fizzle(event)
		"birthstone":
			_birthstone_fire(event)
		"flip":
			if str(event.get("unit", "")) == local_id:
				DeepAudio.play("die_settle", {"volume": 0.8})
				_float_at(_tray_box, "Flipped to %d" % int(event.get("value", 0)), DeepUi.ACCENT_HI, 16)
		"rail_end":
			var resonance: int = int(event.get("resonance", 0))
			if str(event.get("unit", "")) == local_id and resonance >= 3:
				## The chain pays off a step higher for every stone in it.
				DeepAudio.from(_resonance_box, "resonance", {"pitch": 1.0 + 0.09 * float(mini(resonance, 8)), "volume": 0.8})
				_float_at(_resonance_box, "Resonance ×%d" % resonance, _resonance_color(resonance), 20)
				DeepUi.burst(self, _center_of(_resonance_box), _resonance_color(resonance), 20 + resonance * 4, 180.0, 0.7)
		"enemy_ability":
			_enemy_windup(event)
		"enemy_move":
			_enemy_move(event)
		"tick":
			for tick in event.get("ticks", []):
				_animate_tick(tick)
		"skip":
			DeepAudio.play("stun", {"volume": 0.7})
			var who: String = str(event.get("unit", ""))
			if _creatures.has(who) and is_instance_valid(_creatures[who]):
				var creature: CrystalCreature = _creatures[who]
				_fx.stars(creature.global_position + Vector3(0, creature.anchor.y * 0.85, 0))
				_float_world(creature.global_position + Vector3(0, creature.anchor.y, 0), "Bound" if str(event.get("why", "")) == "bound" else "Stunned", Color("ffe27a"), 18)
			elif who == local_id:
				_announce("Stunned", Color("ffe27a"), "Your rail sits this turn out", 0.9)
		"battle_over":
			var won: bool = str(event.get("outcome", "")) == "victory"
			if won:
				DeepAudio.play("victory")
				_announce("Victory", DeepUi.ACCENT_HI, "The chamber is yours", 2.2)
				_camera.victory()
				_screen_fx.blink(DeepUi.ACCENT, 0.25)
				for i in range(4):
					var color: Color = [DeepUi.ACCENT, DeepUi.GOOD, DeepUi.INFO, Color("c58bff")][i]
					_fx.sparks(Vector3(randf_range(-3, 3), 1.5, ARC_Z), color, 50, 6.0, 1.4, 0.07)
				_fx.flash(Vector3(0, 3, ARC_Z), DeepUi.ACCENT, 8.0, 14.0, 1.2, 2.0)
			else:
				DeepAudio.play("defeat")
				_announce("The party falls", DeepUi.BAD, "Everything loose will be salvaged", 2.4)
				_camera.defeat()
				var tween := create_tween()
				tween.tween_property(_screen_fx, "desaturate", 0.85, 1.4)
				_screen_fx.wound(1.0)

func _animate_tick(tick: Dictionary) -> void:
	## One round of poison (or regrowth) on one unit, and whoever drank from it.
	var target_id: String = str(tick.get("unit", ""))
	var color: Color = DeepUi.POISON if str(tick.get("kind", "")) == "poison" else DeepUi.GOOD
	if _creatures.has(target_id) and is_instance_valid(_creatures[target_id]):
		var creature: CrystalCreature = _creatures[target_id]
		DeepAudio.play_at(global_position + _to_screen(creature.centre()), "poison" if str(tick.kind) == "poison" else "heal", {"volume": 0.5})
		_fx.puff(creature.centre(), color, 10, 0.6, 1.0, 0.5, true)
		_float_world(creature.centre(), ("−%d" if str(tick.kind) == "poison" else "+%d") % int(tick.get("amount", 0)), color, 22)
		if str(tick.kind) == "poison":
			creature.hit(0.3)
		if bool(tick.get("killed", false)):
			_kill(creature)
	elif target_id == local_id:
		DeepAudio.play("poison" if str(tick.kind) == "poison" else "heal", {"volume": 0.6})
		_float_at(_hp_bar, "−%d" % int(tick.get("amount", 0)), color, 22)
		_screen_fx.blink(color, 0.1)
	for leech in tick.get("leech", []):
		var drinker: String = str(leech.get("unit", ""))
		if drinker == local_id:
			DeepAudio.play("heal", {"volume": 0.55})
			_float_at(_hp_bar, "+%d Leech" % int(leech.get("amount", 0)), DeepUi.GOOD, 18)
		elif _ally_cards.has(drinker) and is_instance_valid(_ally_cards[drinker]):
			_float_at(_ally_cards[drinker], "+%d" % int(leech.get("amount", 0)), DeepUi.GOOD, 15)

func _birthstone_fire(event: Dictionary) -> void:
	## The Birthstone at the end of a rail lights every tier the hand earned, then its effects
	## leave from its bezel the way a gem's do.
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var stone: Dictionary = DeepStone.birthstone(str(unit.get("character", "")))
	var color: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var anchor: Control = null
	if mine and _birthstone_card != null and is_instance_valid(_birthstone_card):
		anchor = _birthstone_card
	elif _ally_cards.has(unit_id) and is_instance_valid(_ally_cards[unit_id]):
		anchor = _ally_cards[unit_id]
	var origin: Vector3 = _control_world(anchor, 1.6) if anchor != null else _origin_for(unit_id, -1)
	if not bool(event.get("fired", false)):
		if anchor != null and mine:
			_float_at(anchor, "dark", DeepUi.DIM, 13)
			anchor.modulate = Color(0.6, 0.6, 0.7, 1.0)
			var tween := create_tween()
			tween.tween_property(anchor, "modulate", Color.WHITE, 0.6)
		return
	var lit: Array = event.get("tiers", []).filter(func(x: Dictionary) -> bool: return bool(x.get("active", false)))
	## A penalty tier (a Bust) is a loss, so it lights red, and alone it bursts red too.
	var penalties: Array = stone.get("tiers", []).filter(func(x: Dictionary) -> bool: return bool(x.get("penalty", false))).map(func(x: Dictionary) -> String: return str(x.get("name", "")))
	var busted: bool = lit.all(func(x: Dictionary) -> bool: return penalties.has(str(x.get("name", ""))))
	if anchor != null:
		DeepAudio.from(anchor, "resonance", {"pitch": 1.1 + 0.08 * float(mini(lit.size(), 4)), "volume": 0.9, "gap": 0.02})
		var ring: SocketRing = anchor.get_node_or_null("Slot/Ring")
		if ring != null:
			ring.fire()
		DeepUi.pulse(anchor, 1.2, 0.45)
		DeepUi.burst(self, _center_of(anchor), DeepUi.BAD if busted else color, 24 + 8 * lit.size(), 190.0, 0.6)
		var lift: int = 0
		for entry in lit:
			var loss: bool = penalties.has(str(entry.get("name", "")))
			_float_at(anchor, str(entry.get("name", "")), DeepUi.BAD if loss else color.lightened(0.35), 17 - mini(lift, 3))
			lift += 1
		if bool(event.get("replay", false)):
			_float_at(anchor, "Encore!", DeepUi.ACCENT_HI, 18)
	else:
		DeepAudio.play("resonance", {"volume": 0.7})
	for entry in lit:
		_animate_effects(entry.get("effects", []), origin, color, mine, anchor, 1.0)

func _stone_color(unit_id: String, socket: int, skill_key: String) -> Color:
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var rail: Array = unit.get("rail", [])
	if socket >= 0 and socket < rail.size() and rail[socket] is Dictionary:
		return DeepUi.color(DeepStone.color(rail[socket]))
	return DeepUi.color(str(DeepContent.skill(skill_key).get("color", "WHITE")))

func _color_key(unit_id: String, socket: int, skill_key: String) -> String:
	## What a stone rings as. Its color is what kind of thing it does, so it is also its voice.
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var rail: Array = unit.get("rail", [])
	if socket >= 0 and socket < rail.size() and rail[socket] is Dictionary:
		return DeepStone.color(rail[socket])
	return str(DeepContent.skill(skill_key).get("color", "WHITE"))

func _origin_for(unit_id: String, socket: int) -> Vector3:
	## Where a gem's light leaves from: its socket on your dock, or an ally's card.
	if unit_id == local_id and socket >= 0 and socket < _socket_cards.size():
		return _control_world(_socket_cards[socket], 1.6)
	if _ally_cards.has(unit_id) and is_instance_valid(_ally_cards[unit_id]):
		return _control_world(_ally_cards[unit_id], 1.8)
	return _camera.global_position + (-_camera.global_transform.basis.z) * 1.5 + Vector3(0, -0.6, 0)

func _gem_fire(event: Dictionary) -> void:
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	var socket: int = int(event.get("socket", -1))
	var color: Color = _stone_color(unit_id, socket, str(event.get("skill", "")))
	var origin: Vector3 = _origin_for(unit_id, socket)
	var magnitude: float = clampf(float(event.get("magnitude", 1.0)), 0.5, 4.0)
	var voice: String = DeepSoundBank.gem_sound(_color_key(unit_id, socket, str(event.get("skill", ""))))
	var carry: float = clampf(0.5 + magnitude * 0.14, 0.45, 1.0) * (1.0 if mine else 0.55)
	if mine and socket >= 0 and socket < _socket_cards.size():
		var card: Control = _socket_cards[socket]
		DeepAudio.from(card, voice, {"volume": carry, "gap": 0.02})
		var ring: SocketRing = card.get_node_or_null("Slot/Ring")
		if ring != null:
			ring.fire()
		DeepUi.pulse(card, 1.18, 0.4)
		DeepUi.burst(self, _center_of(card), color, 18, 170.0, 0.55)
		var resonance: int = int(event.get("resonance", 0))
		if resonance > int(_resonance_value.text) or int(event.get("gain", 0)) > 0:
			_resonance_flight(card, resonance, maxi(1, int(event.get("gain", 0))), color, bool(event.get("harmony", false)))
		elif resonance != int(_resonance_value.text):
			_show_resonance(resonance)
		if bool(event.get("retrigger", false)):
			_float_at(card, "Again!", DeepUi.ACCENT_HI, 15)
	elif _ally_cards.has(unit_id) and is_instance_valid(_ally_cards[unit_id]):
		DeepAudio.from(_ally_cards[unit_id], voice, {"volume": carry, "gap": 0.02})
		DeepUi.pulse(_ally_cards[unit_id], 1.05, 0.3)
	else:
		DeepAudio.play(voice, {"volume": carry, "gap": 0.02})
	_animate_effects(event.get("effects", []), origin, color, mine, _socket_cards[socket] if mine and socket >= 0 and socket < _socket_cards.size() else null, magnitude)

func _later_do(seconds: float, work: Callable) -> void:
	## One beat of an effect's playback. Nothing here outlives the screen.
	if seconds <= 0.001 or _headless or not is_inside_tree():
		work.call()
		return
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			work.call())

func _animate_effects(effects: Array, origin: Vector3, color: Color, mine: bool, anchor: Control, magnitude: float = 1.0) -> void:
	## What a gem or a Birthstone did, animated effect by effect from where its light left —
	## one after another, not all at once. A skill that files a die and then throws five
	## bolts should read as exactly that: the file, a breath, then five bolts in a row.
	var at: float = 0.0
	for effect in effects:
		var kind: String = str(effect.get("kind", ""))
		var target_id: String = str(effect.get("target", ""))
		match kind:
			"damage":
				var hits: Array = [effect] + effect.get("splash", [])
				## A blow that lands several times over throws one bolt for each, in quick
				## succession, rather than one fat bolt carrying the whole number.
				var over: int = clampi(int(effect.get("repeat", 1)), 1, 10)
				for hit in hits:
					var who: String = str(hit.get("target", target_id))
					var creature: CrystalCreature = _creature(who)
					if creature == null or not is_instance_valid(creature):
						continue
					var landing: Dictionary = hit.duplicate()
					if bool(hit.get("killed", false)):
						creature.set_meta("dying", true)
					## Bigger numbers throw bigger, faster bolts.
					var weight: float = clampf(float(int(hit.get("hp_loss", 0)) + int(hit.get("absorbed", 0))) / 14.0, 0.0, 1.6)
					var fat: float = 0.09 + 0.035 * magnitude + 0.05 * weight
					for again in range(over):
						var when: float = at + 0.085 * float(again)
						_later_do(when, func() -> void:
							if is_instance_valid(creature):
								_fx.projectile(origin, creature.centre(), color, 0.2, fat, _impact.bind(who, landing, color, mine), 0.6 + randf() * 0.5))
					at += 0.085 * float(over)
				at += 0.16
			"block":
				var gained: int = int(effect.amount)
				var swell: float = clampf(float(gained) / 18.0, 0.0, 1.0)
				_later_do(at, func() -> void:
					DeepAudio.play("block", {"volume": (0.5 + 0.35 * swell) if target_id == local_id else 0.45})
					if target_id == local_id:
						var ahead: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 2.2 + Vector3(0, -0.35, 0)
						_fx.shield(ahead, _camera.global_position - ahead, DeepUi.BLOCK, 0.7 + swell * 0.9, 0.5 + swell * 0.4)
						_screen_fx.blink(DeepUi.BLOCK, 0.06 + swell * 0.22)
						_ward(DeepUi.BLOCK, "shield", swell, 5 + int(round(swell * 9.0)))
						_float_at(_hp_bar, "+%d block" % gained, DeepUi.BLOCK, 18 + int(round(swell * 14.0)))
					elif _ally_cards.has(target_id):
						_float_at(_ally_cards[target_id], "+%d block" % gained, DeepUi.BLOCK, 16))
				at += 0.2
			"heal", "revive":
				var healed: int = int(effect.get("healed", effect.amount))
				var pour: float = clampf(float(healed) / 20.0, 0.0, 1.0)
				_later_do(at, func() -> void:
					DeepAudio.play("heal", {"volume": 0.55 + 0.35 * pour})
					if target_id == local_id:
						var below: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 2.6 + Vector3(0, -1.4, 0)
						_fx.rise(below, DeepUi.GOOD, 16 + int(round(pour * 54.0)), 1.1 + pour * 1.0)
						_screen_fx.blink(DeepUi.GOOD, 0.06 + pour * 0.2)
						_ward(DeepUi.GOOD, "cross", pour, 5 + int(round(pour * 11.0)))
						_float_at(_hp_bar, "+%d" % healed, DeepUi.GOOD, 18 + int(round(pour * 16.0)))
					elif _ally_cards.has(target_id):
						_float_at(_ally_cards[target_id], "+%d" % healed, DeepUi.GOOD, 16))
				at += 0.2
			"gold":
				if mine:
					DeepAudio.play("ore", {"volume": 0.7})
					var pile: Vector3 = Vector3(randf_range(-1.5, 1.5), 1.2, ARC_Z + 0.5)
					var home: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.4 + Vector3(0.8, -0.7, 0)
					_fx.coins(pile, home, 8 + mini(12, int(effect.amount)))
					_float_at(_forecast_box, "+%d ore" % int(effect.amount), DeepUi.ORE, 20)
			"poison", "stun", "curse", "remove_block", "dice_dread", "die_steal", "cleanse":
				var creature: CrystalCreature = _creature(target_id)
				if creature != null and is_instance_valid(creature):
					var tone: Color = {"poison": DeepUi.POISON, "stun": Color("ffe27a"), "curse": Color("c58bff"), "remove_block": DeepUi.BLOCK}.get(kind, color)
					var landing: Dictionary = effect.duplicate()
					_later_do(at, func() -> void:
						if is_instance_valid(creature):
							_fx.projectile(origin, creature.centre(), tone, 0.3, 0.1, _afflict.bind(target_id, landing, tone), 1.0))
					at += 0.16
				elif target_id == local_id and kind == "cleanse":
					_fx.rise(_camera.global_position + (-_camera.global_transform.basis.z) * 2.6 + Vector3(0, -1.4, 0), Color.WHITE, 20, 1.2)
			"raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high":
				if mine:
					_float_at(_tray_box, kind.replace("_", " ").capitalize(), Color.WHITE, 15)
					for id in _dice_views:
						var view: Control = _dice_views[id]
						DeepUi.burst(self, _center_of(view), color, 6, 80.0, 0.4, 4.0)
			"tick_poison":
				for tick in effect.get("ticks", []):
					_animate_tick(tick)
			"replay_rail":
				if not bool(effect.get("nothing", false)):
					DeepAudio.play("harmony", {"volume": 0.9})
					_announce("Encore", DeepUi.ACCENT_HI, "The rail plays again", 0.9)
			"stone_drop":
				DeepAudio.play("ore", {"volume": 0.9})
				_announce("Royal Flush", DeepUi.ORE, "A stone falls from the rock", 1.1)
				if anchor != null:
					DeepUi.burst(self, _center_of(anchor), DeepUi.ORE, 40, 220.0, 0.9)
			_:
				if mine and anchor != null:
					_float_at(anchor, kind.replace("_", " ").capitalize(), color.lightened(0.3), 13)

func _ward(tone: Color, glyph: String, strength: float, count: int) -> void:
	## What a heal or a guard looks like from inside the helmet: a wash of its colour round
	## the edge of the view and a scatter of its own mark drifting up through it, both of
	## them as big as the number was. A three-point heal is a flicker; a twenty-point one
	## fills the screen.
	if _headless or not is_inside_tree():
		return
	for i in range(maxi(1, count)):
		var mark := GemIcons.glyph(self, glyph, 16.0 + strength * 22.0, Color(tone, 0.0))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var from := Vector2(size.x * 0.5 + side * randf_range(size.x * 0.18, size.x * 0.46), size.y * randf_range(0.62, 0.92))
		mark.position = from
		var rise: float = randf_range(90.0, 200.0) * (0.6 + strength)
		var tween := mark.create_tween()
		tween.tween_interval(randf() * 0.22)
		tween.tween_property(mark, "modulate:a", 0.85, 0.16)
		tween.parallel().tween_property(mark, "position", from + Vector2(randf_range(-40.0, 40.0), -rise), 0.9 + strength * 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mark, "modulate:a", 0.0, 0.3)
		tween.tween_callback(mark.queue_free)

func _impact(who: String, hit: Dictionary, color: Color, mine: bool) -> void:
	var creature: CrystalCreature = _creature(who)
	if creature == null or not is_instance_valid(creature):
		return
	var foe: Dictionary = DeepBattle.enemy(state, who)
	var max_hp: float = float(maxi(1, int(foe.get("max_hp", 1)))) if not foe.is_empty() else 20.0
	var amount: int = int(hit.get("hp_loss", 0)) + int(hit.get("absorbed", 0))
	var ratio: float = clampf(float(amount) / max_hp, 0.0, 1.0)
	var at: Vector3 = creature.centre()
	var heft: String = "hit_light"
	if bool(hit.get("killed", false)) or ratio >= 0.4:
		heft = "hit_crit"
	elif ratio >= 0.15:
		heft = "hit_heavy"
	DeepAudio.play_at(global_position + _to_screen(at), heft, {"gap": 0.02, "volume": clampf(0.5 + ratio, 0.5, 1.0),
		"pitch": clampf(1.2 - ratio * 0.4, 0.82, 1.25)})
	if int(hit.get("absorbed", 0)) > 0:
		DeepAudio.play_at(global_position + _to_screen(at), "block", {"volume": 0.5, "gap": 0.02})
	creature.hit(clampf(ratio * 3.0, 0.3, 1.5))
	_fx.sparks(at, color, 18 + mini(40, amount * 2), 4.0 + ratio * 6.0, 0.6, 0.06)
	_fx.glow_burst(at, color, 1.2 + ratio * 3.0, 0.3)
	_fx.flash(at, color, 4.0 + ratio * 10.0, 7.0, 0.3, 0.8 + ratio)
	if int(hit.get("absorbed", 0)) > 0:
		_fx.shield(at + Vector3(0, 0, 0.6), _camera.global_position - at, DeepUi.BLOCK, 0.7, 0.4)
	_camera.add_trauma(0.1 + ratio * 0.55)
	if ratio >= 0.25 or bool(hit.get("killed", false)):
		_camera.punch(-4.0 - ratio * 4.0, 0.4)
		_camera.focus(at, 0.2, 0.6)
		_screen_fx.kick(0.5 + ratio)
		_fx.ring_wave(Vector3(at.x, 0.0, at.z), color, 2.5 + ratio * 3.0, 0.5)
	var text: String = "−%d" % amount
	var size: int = 24 + mini(28, amount)
	_float_world(at + Vector3(0, 0.6, 0), text, color.lightened(0.35) if mine else DeepUi.PAPER, size)
	if int(hit.get("absorbed", 0)) > 0:
		_float_world(at + Vector3(0.5, 0.2, 0), "%d blocked" % int(hit.absorbed), DeepUi.BLOCK, 14)
	for reflection in hit.get("reflections", []):
		_enemy_effect(reflection, creature)
		_screen_fx.wound(0.3)
	if not str(hit.get("split", "")).is_empty():
		_float_world(at + Vector3(0, 1.0, 0), "It splits!", Color("9fd8c8"), 18)
	if bool(hit.get("killed", false)):
		_kill(creature)

func _afflict(who: String, effect: Dictionary, tone: Color) -> void:
	var creature: CrystalCreature = _creature(who)
	if creature == null or not is_instance_valid(creature):
		return
	var kind: String = str(effect.get("kind", ""))
	var at: Vector3 = creature.centre()
	var spoken: String = {"poison": "poison", "stun": "stun", "curse": "curse", "dice_dread": "curse",
		"remove_block": "block_break", "die_steal": "ui_deny", "cleanse": "heal"}.get(kind, "")
	if not spoken.is_empty() and not bool(effect.get("immune", false)):
		DeepAudio.play_at(global_position + _to_screen(at), spoken, {"volume": 0.65, "gap": 0.02})
	creature.flash(1.8)
	match kind:
		"poison":
			_fx.puff(at, DeepUi.POISON, 16, 0.8, 1.4, 0.4, true)
		"stun":
			_fx.stars(creature.global_position + Vector3(0, creature.anchor.y * 0.85, 0))
			_fx.flash(at, tone, 5.0, 5.0, 0.3)
		"curse", "dice_dread":
			_fx.sigil(Vector3(at.x, 0.0, at.z), tone, 1.3)
		"remove_block":
			_fx.shards(at, DeepUi.BLOCK, 10, 3.0, 0.1, 0.8)
		_:
			_fx.glow_burst(at, tone, 1.2)
	var amount: int = int(effect.get("amount", 0))
	var words: String = kind.replace("_", " ").capitalize()
	if effect.get("immune", false):
		words = "Immune"
	elif effect.get("resisted", false):
		words = "Resisted"
	elif amount > 0 and kind != "stun":
		words += " %d" % amount
	_float_world(at + Vector3(0, 0.8, 0), words, tone, 18)

func _kill(creature: CrystalCreature) -> void:
	if creature == null or not is_instance_valid(creature) or bool(creature.get_meta("killed", false)):
		return
	creature.set_meta("killed", true)
	creature.set_meta("dying", true)
	if _headless:
		creature.queue_free()
		return
	var at: Vector3 = creature.centre()
	DeepAudio.play_at(global_position + _to_screen(at), "warden_die" if creature.warden else "creature_die", {"gap": 0.0})
	_fx.shards(at, creature.tint, 18, 4.5, 0.16, 1.2)
	_fx.sparks(at, creature.tint, 60, 7.0, 0.9, 0.08)
	_fx.flash(at, creature.tint.lightened(0.3), 10.0, 10.0, 0.5, 1.8)
	_fx.ring_wave(Vector3(at.x, 0.0, at.z), creature.tint, 4.0, 0.6)
	_fx.puff(Vector3(at.x, 0.4, at.z), Color(0.35, 0.32, 0.3), 12, 1.0, 1.6, 0.5)
	_camera.add_trauma(0.35 if not creature.warden else 0.8)
	_screen_fx.kick(0.9 if not creature.warden else 1.6)
	if _chamber != null and is_instance_valid(_chamber):
		_chamber.surge(creature.tint, 0.8)
	if creature.warden:
		_fx.dust_fall(90)
		_screen_fx.blink(Color.WHITE, 0.35)
	if spoils:
		stage.shed(at, creature.tint)
	creature.die()

func _gem_fizzle(event: Dictionary) -> void:
	if str(event.get("unit", "")) != local_id:
		return
	var socket: int = int(event.get("socket", -1))
	if socket < 0 or socket >= _socket_cards.size():
		return
	var card: Control = _socket_cards[socket]
	DeepAudio.from(card, "gem_fizzle", {"volume": 0.6, "gap": 0.02})
	card.modulate = Color(0.4, 0.4, 0.5, 1.0)
	var tween := create_tween()
	tween.tween_property(card, "modulate", Color.WHITE, 0.6)
	DeepUi.shake(card, 10.0, 0.3)
	DeepUi.burst(self, _center_of(card), Color(0.5, 0.5, 0.55), 10, 60.0, 0.6, 6.0)
	_float_at(card, "fizzle", DeepUi.DIM, 14)
	if int(event.get("healed", 0)) > 0:
		_float_at(_hp_bar, "+%d" % int(event.healed), DeepUi.GOOD, 18)
	_show_resonance(int(event.get("resonance", 0)))
	DeepUi.shake(_resonance_box, 8.0, 0.25)

func _enemy_windup(event: Dictionary) -> void:
	var who: String = str(event.get("unit", ""))
	var delay: float = maxf(0.0, float(event.get("duration", 0.7)) - 0.3)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		var creature: CrystalCreature = _creature(who)
		if creature == null:
			return
		DeepAudio.play_at(global_position + _to_screen(creature.centre()), "enemy_windup", {"volume": 0.7})
		var hostile: bool = event.get("effects", []).any(func(e: Dictionary) -> bool: return str(e.kind) in DeepRules.HOSTILE)
		if hostile:
			creature.lunge(_camera.global_position, 0.62)
		else:
			creature.channel(0.6)
			_fx.rise(creature.centre(), DeepUi.BLOCK, 18, 0.5)
		_fx.flash(creature.centre(), creature.tint, 2.0, 3.0, 0.3, 0.5)
		_float_world(creature.global_position + Vector3(0, creature.anchor.y + 0.3, 0), str(event.get("move", "")), creature.tint.lightened(0.4), 20))

func _enemy_move(event: Dictionary) -> void:
	# The simulation applies damage at this event, after the power-up and lunge windup.
	for effect in event.get("effects", []):
		_enemy_effect(effect, _creature(str(event.get("unit", ""))))

func _enemy_effect(effect: Dictionary, creature: CrystalCreature) -> void:
	var kind: String = str(effect.get("kind", ""))
	var target_id: String = str(effect.get("target", ""))
	var source: Vector3 = creature.centre() if creature != null and is_instance_valid(creature) else Vector3(0, 1.2, ARC_Z)
	match kind:
		"damage":
			var loss: int = int(effect.get("hp_loss", 0))
			var absorbed: int = int(effect.get("absorbed", 0))
			if target_id == local_id:
				var unit: Dictionary = me()
				var ratio: float = clampf(float(loss) / float(maxi(1, int(unit.get("max_hp", 60)))), 0.0, 1.0)
				DeepAudio.play("enemy_strike" if loss > 0 else "block", {"volume": clampf(0.6 + ratio * 1.2, 0.6, 1.0), "gap": 0.02})
				_camera.add_trauma(0.3 + ratio * 1.4)
				_camera.nudge(Vector3(randf_range(-0.25, 0.25), -0.12, 0.3 + ratio), 0.45)
				if loss > 0:
					_screen_fx.wound(0.45 + ratio * 2.0)
					_screen_fx.kick(0.4 + ratio * 2.0)
					_screen_fx.blink(Color(1.0, 0.2, 0.15), 0.12 + ratio * 0.3)
					_slash(creature.tint if creature != null and is_instance_valid(creature) else DeepUi.BAD)
				if absorbed > 0:
					var ahead: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.8
					_fx.shield(ahead, _camera.global_position - ahead, DeepUi.BLOCK, 0.9, 0.5)
				var text: String = "−%d" % loss if loss > 0 else "Blocked"
				_float_at(_hp_bar, text, DeepUi.BAD if loss > 0 else DeepUi.BLOCK, 26 + mini(20, loss))
				if absorbed > 0 and loss > 0:
					_float_at(_hp_bar, "%d blocked" % absorbed, DeepUi.BLOCK, 14)
				if bool(effect.get("downed", false)):
					_announce("You are down", DeepUi.BAD, "The party fights on", 1.6)
				if ratio > 0.2 and _chamber != null:
					_fx.dust_fall(40)
			elif _ally_cards.has(target_id) and is_instance_valid(_ally_cards[target_id]):
				DeepAudio.from(_ally_cards[target_id], "enemy_strike", {"volume": 0.5, "gap": 0.02})
				_ally_cards[target_id].hurt()
				_float_at(_ally_cards[target_id], "−%d" % loss, DeepUi.BAD, 18)
				_camera.add_trauma(0.12)
		"block":
			if creature != null and is_instance_valid(creature):
				DeepAudio.play_at(global_position + _to_screen(creature.centre()), "block", {"volume": 0.5})
				_fx.shield(creature.centre() + Vector3(0, 0, 0.8), _camera.global_position - creature.centre(), DeepUi.BLOCK, 1.0 * creature.scale.x, 0.6)
				_float_world(creature.global_position + Vector3(0, creature.anchor.y * 0.7, 0), "+%d block" % int(effect.get("amount", 0)), DeepUi.BLOCK, 18)
		"dice_upgrade":
			if creature != null:
				_fx.rise(creature.centre(), DeepUi.ACCENT, 28, 0.7)
				_float_world(creature.centre(), "Dice tier up", DeepUi.ACCENT, 20)
		"heal":
			DeepAudio.play("heal", {"volume": 0.5})
			var healed: Node3D = _creature(target_id) if _creature(target_id) != null else creature
			if healed != null and is_instance_valid(healed):
				_fx.rise(healed.global_position + Vector3(0, 0.3, 0), DeepUi.GOOD, 24, 0.8)
		"poison", "stun", "die_steal", "remove_block", "curse":
			if target_id == local_id:
				DeepAudio.play({"poison": "poison", "stun": "stun", "curse": "curse", "remove_block": "block_break"}.get(kind, "ui_deny"), {"volume": 0.7})
				var tone: Color = {"poison": DeepUi.POISON, "stun": Color("ffe27a"), "remove_block": DeepUi.BLOCK, "curse": Color("c58bff")}.get(kind, DeepUi.INFO)
				_screen_fx.blink(tone, 0.12)
				_float_at(_hp_bar, kind.replace("_", " ").capitalize() + (" %d" % int(effect.get("amount", 0)) if int(effect.get("amount", 0)) > 0 and kind != "stun" else ""), tone, 18)
				if kind == "die_steal" and not _dice_views.is_empty():
					var view: Control = _dice_views.values().back()
					DeepUi.shake(view, 12.0, 0.4)
					DeepUi.burst(self, _center_of(view), DeepUi.BAD, 12, 120.0, 0.5)
				if kind == "stun":
					DeepUi.shake(_dock, 4.0, 0.4)

func _slash(color: Color) -> void:
	## Claw marks across the view: three bright strokes that rip in and fade.
	var marks := Slash.new()
	marks.color = color.lightened(0.4)
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(marks)
	move_child(marks, _hud.get_index())

class Slash extends Control:
	var color: Color = Color.WHITE
	var _t: float = 0.0
	var _angle: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_angle = randf_range(-0.5, 0.5)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
	func _process(delta: float) -> void:
		_t += delta / 0.45
		if _t >= 1.0:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5 + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var reach: float = size.y * 0.42 * minf(1.0, _t * 4.0)
		var alpha: float = 1.0 - _t
		var direction := Vector2(cos(_angle + 0.9), sin(_angle + 0.9))
		var across := direction.orthogonal()
		for i in range(3):
			var offset: Vector2 = across * (float(i) - 1.0) * size.y * 0.09
			var a: Vector2 = centre + offset - direction * reach
			var b: Vector2 = centre + offset + direction * reach
			draw_line(a, b, Color(color, 0.35 * alpha), 22.0, true)
			draw_line(a, b, Color(color, 0.9 * alpha), 6.0, true)
			draw_line(a, b, Color(1, 1, 1, alpha), 2.0, true)

# --- flourishes ----------------------------------------------------------------------------

func _center_of(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5 - global_position

func _float_at(anchor: Control, text: String, color: Color, size: int = 18) -> void:
	if anchor == null or not is_instance_valid(anchor) or _headless:
		return
	var at: Vector2 = anchor.global_position + Vector2(anchor.size.x * 0.5, 0) - global_position
	DeepUi.float_text(self, at, text, color, size)

func _float_world(point: Vector3, text: String, color: Color, size: int = 20) -> void:
	if _headless or _camera == null or _camera.is_position_behind(point):
		return
	DeepUi.float_text(self, _to_screen(point), text, color, size, 70.0, 1.1)

func _announce(text: String, color: Color, sub: String = "", hold: float = 1.1) -> void:
	## A title across the room: it lands large and settles, holds, and fades.
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner_sub.visible = not sub.is_empty()
	_banner_box.modulate.a = 0.0
	_banner_box.pivot_offset = _banner_box.size * 0.5
	_banner_box.scale = Vector2.ONE * 1.35
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_banner_box, "modulate:a", 1.0, 0.18)
	tween.tween_property(_banner_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_banner_box, "modulate:a", 0.0, 0.5).set_delay(hold)
