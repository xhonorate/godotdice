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
const ScreenFx = preload("res://view/battle/screen_fx.gd")
const CameraRig = preload("res://view/battle/camera_rig.gd")
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
## What Sleight does, on its button. See `DeepBattle.shift_face`.
const SHIFT_TIP: String = "Sleight, once a turn  [F]: turn one chosen die over onto a face of the other parity, its mirror face (a 2 on a d6 to its 5) or the nearest one of the other parity it has. A die whose faces are all even or all odd can't be shifted."
const BASE_FOV: float = 58.0

signal command(cmd: Dictionary)

const DIE_EDGE: float = 82.0
const SOCKET_EDGE: float = 60.0
## A Void gem riding a socket, as a chip under the socket's name, and how many of them show
## before a count stands for the rest.
const RIDER_EDGE: float = 20.0
const RIDERS_SHOWN: int = 3
## A phantom die beside the hand, and how many are drawn before the rest are counted.
const PHANTOM_EDGE: float = 56.0
const PHANTOMS_SHOWN: int = 3
const PHANTOM_TINT := Color(0.72, 0.84, 1.0, 0.62)
## A set gem the hand in the tray would leave dark: still readable, plainly stepped back.
const QUIET_GEM := Color(0.62, 0.62, 0.68, 0.72)
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
## How much of the left edge something else lies over (the run's chart, when it is open):
## the creature's table stands clear of it.
var left_inset: float = 0.0:
	set(value):
		left_inset = value
		_position_enemy_panel()

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
## The die a creature is rolling, turning over its head; and whose head.
var _enemy_roll: RollBadge = null
var _enemy_roll_id: String = ""
var _enemy_panel: PanelContainer
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
## One control per entry of the fighter's flat rail: a socket's card, or a rider's chip.
var _socket_cards: Array = []
var _rail_shape: String = ""
var _resonance_value: Label
var _resonance_box: HBoxContainer
var _tray_box: HBoxContainer
var _dice_views: Dictionary = {}
## Phantom dice (a Refract's copies of the highest die), drawn small and ghostly after the
## five; and what they were last drawn from.
var _phantom_box: HBoxContainer
var _phantom_key: String = ""
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
var _forecast_key: String = ""
## The block the status row was last drawn with: it is only rebuilt when that changes.
var _status_block: int = -1
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
## What the dice owed on the throw this turn opened with, and what grew back with them.
var _pending_dues: Dictionary = {}
var _pending_regrown: Dictionary = {}
var _battery_tween: Tween

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
	var built: bool = stage.show_room({"key": key, "mine": mine, "depth": depth, "kind": kind, "exits": int(context.get("exits", 2)), "phase": int(context.get("phase", -1))})
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
	## The bottom of a mine is its final boss's, not a Warden's: the hall is built the same.
	var boss: bool = bool(context.get("boss", false))
	_depth_label.text = str(biome.name).replace("Warden's Hall", "The Final Hall") if boss else str(biome.name)
	_biome_label.text = "Depth %d%s" % [depth, ("  ·  The bottom of the mine" if boss else "  ·  Warden's gate") if bool(biome.warden) else ("  ·  Elite" if bool(biome.elite) else "")]
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
				if bool(foe.get("fled", false)):
					_flee(_creatures[id], int(foe.get("stolen_gold", 0)))
				else:
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
			var creature: CrystalCreature = CrystalCreature.make(str(foe.key), bool(foe.get("warden", false)), str(foe.get("echo_of", "")))
			creature.position = target
			creature.rest_position = target
			if _chamber != null:
				creature.ground = _chamber.ground
			_world.add_child(creature)
			_creatures[id] = creature
			var after: float = stage.seal_remaining() if stage.has_method("seal_remaining") else 0.0
			creature.spawn(after + 0.25 + 0.18 * float(fresh) if _intro_pending else after)
			_fx.puff(target + Vector3(0, 0.3, 0), Color(0.5, 0.45, 0.4), 10, 0.9, 1.4, 0.6)
			## Something called into the fight arrives with more of a flourish than a rockfall.
			if bool(foe.get("summoned", false)) and not _intro_pending:
				_fx.ring_wave(Vector3(target.x, 0.0, target.z), creature.tint, 2.2, 0.5)
				_fx.sparks(target + Vector3(0, 0.6, 0), creature.tint, 30, 4.0, 0.7, 0.06)
				_fx.flash(target + Vector3(0, 0.8, 0), creature.tint, 4.0, 5.0, 0.4, 1.0)
			fresh += 1
		else:
			var creature: CrystalCreature = _creatures[id]
			if not creature.rest_position.is_equal_approx(target):
				var tween := create_tween()
				tween.tween_property(creature, "rest_position", target, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		(_creatures[id] as CrystalCreature).set_targeted(str(me().get("target", "")) == id)
		_dress(_creatures[id], foe)

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
	## Allies: cards stacked up the right edge from the top of the dock.
	_ally_box = DeepUi.vbox(_hud, 8)
	_ally_box.custom_minimum_size = Vector2(230, 0)
	_ally_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	_ally_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ally_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ally_box.alignment = BoxContainer.ALIGNMENT_END
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
	_dock.resized.connect(_seat_allies)
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
	_hp_bar.warn = true
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
	_resonance_box.tooltip_text = "Resonance: each gem that fires adds one, a neighbour of the same color adds two, and a gem that doesn't fire costs nothing. Your Birthstone reads it last."
	DeepUi.icon(_resonance_box, "resonance", 18, DeepUi.RESONANCE).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.heading(_resonance_box, "Resonance", 13, DeepUi.RESONANCE).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resonance_value = DeepUi.title(_resonance_box, "0", 20, DeepUi.RESONANCE)
	_resonance_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rail_box = DeepUi.hbox(left, 6)
	_rail_box.custom_minimum_size.y = SOCKET_EDGE + 60
	DeepUi.rule(columns, Color(DeepUi.LINE, 0.8)).custom_minimum_size = Vector2(1, 0)
	## Middle: the dice.
	var middle := DeepUi.vbox(columns, 6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tray_head := DeepUi.hbox(middle, 8)
	DeepUi.icon(tray_head, "die", 16, DeepUi.ACCENT)
	DeepUi.heading(tray_head, "Your hand", 13)
	DeepUi.spacer(tray_head)
	_hint = DeepUi.label(tray_head, "", 13, DeepUi.MUTED)
	## The five, and after them any phantom dice a Refract has added for the rest of the turn.
	var hand_row := DeepUi.hbox(middle, 10)
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray_box = DeepUi.hbox(hand_row, 8)
	_tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_phantom_box = DeepUi.hbox(hand_row, 6)
	_phantom_box.visible = false
	var buttons := DeepUi.hbox(middle, 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_reroll_button = DeepUi.icon_button(buttons, "reroll", "Reroll", _reroll, 15, DeepUi.INFO)
	_reroll_button.tooltip_text = "Reroll the selected dice  [R]"
	_flip_button = DeepUi.icon_button(buttons, "eye", "Shift", _flip, 15, DeepUi.ACCENT)
	_flip_button.tooltip_text = SHIFT_TIP
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

func _seat_allies() -> void:
	## The allies stand on the dock: their bottom edge is its top edge, wherever it grows to.
	if _ally_box == null or _dock == null:
		return
	_ally_box.offset_bottom = - (_dock.size.y + 14.0 + 10.0)

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

func leave() -> void:
	## The party is somewhere with no fight in it: whatever creatures are still standing in
	## the room go, and nothing of the last fight is kept to be recognised again. Without
	## this the creatures a party fell to stood in every room of the next run until its
	## first fight, because they live in the stage's world rather than under this screen.
	if _creatures.is_empty() and _plates.is_empty() and state.is_empty():
		return
	for id in _creatures.keys():
		if is_instance_valid(_creatures[id]):
			_creatures[id].queue_free()
	_creatures.clear()
	_awaited.clear()
	for id in _plates.keys():
		if is_instance_valid(_plates[id]):
			_plates[id].queue_free()
	_plates.clear()
	if _enemy_panel != null:
		_enemy_panel.reset()
	_hide_enemy_roll()
	_hovered_creature = ""
	_layout_wait = null
	_battle_signature = ""
	_stage_key = ""
	state = {}

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
			var settling_hand: String = rolled
			get_tree().create_timer(DiceView.SPIN_SECONDS + 0.09).timeout.connect(func() -> void:
				if is_instance_valid(self) and not state.is_empty() and _rolled_hand == settling_hand:
					_dice_settle_at = 0
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
		foe_label.text = ("Final boss · " if bool(context.get("boss", false)) else "Warden · ") + foe_label.text
	elif bool(state.get("elite", false)):
		foe_label.text = "Elite · " + foe_label.text
	if not unit.is_empty():
		var ratio: float = float(unit.hp) / float(maxi(1, int(unit.max_hp)))
		_hp_bar.set_values(ratio, "%d / %d" % [int(unit.hp), int(unit.max_hp)], float(unit.block) / float(maxi(1, int(unit.max_hp))))
		if _screen_fx != null:
			_screen_fx.danger = clampf((0.3 - ratio) / 0.3, 0.0, 1.0) if not bool(unit.get("downed", false)) else 0.0
		if int(unit.block) != _status_block:
			_status_block = int(unit.block)
			DeepUi.clear(_status_row)
			if int(unit.block) > 0:
				DeepUi.pill(_status_row, "shield", str(int(unit.block)), DeepUi.BLOCK, 14, "Block: soaks hit damage. Retain preserves some at the next turn; the rest falls away.")
		var effects: Array = EffectChips.for_player(unit, state).filter(func(e: Dictionary) -> bool: return str(e.key) != "block")
		var passive: Dictionary = unit.get("passive", {})
		if not str(passive.get("text", "")).is_empty():
			effects.append(EffectChips.entry("passive", "spark", "", true, str(passive.get("name", DeepContent.character_title(str(unit.get("character", ""))))), str(passive.text), DeepUi.ACCENT))
		_effects.show_effects(effects)
		## While a turn resolves the rail's own events count the Resonance up, sparks and all.
		if planning and (_battery_tween == null or not _battery_tween.is_running()):
			_show_resonance(int(forecast.get("totals", {}).get("resonance", 0)))
		elif not planning and (_headless or str(state.get("phase", "")) != "resolving"):
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
	## A Roller in the room threw the hand this turn and took the rerolls with it: the button
	## wears the Roller's own mark and name in its colour, and says why on a hover.
	var roller: Dictionary = _roller(state) if planning else {}
	var roller_chip: Array = EffectChips.GIMMICKS.get("roll_for_you", ["die", "Roller", ""])
	var tone: Color = DeepUi.BAD if not roller.is_empty() else DeepUi.INFO
	_reroll_button.icon = GemIcons.texture(str(roller_chip[0]) if not roller.is_empty() else "reroll", GemIcons.baked_size(30.0))
	_reroll_button.add_theme_color_override("icon_normal_color", tone)
	_reroll_button.add_theme_color_override("icon_disabled_color", Color(tone, 0.8))
	if not roller.is_empty():
		_reroll_button.text = str(roller_chip[1])
		_reroll_button.add_theme_color_override("font_disabled_color", tone.lightened(0.2))
		_reroll_button.tooltip_text = "%s: %s" % [str(roller.get("name", "A creature")), str(roller_chip[2])]
	else:
		_reroll_button.remove_theme_color_override("font_disabled_color")
		_reroll_button.tooltip_text = "Reroll the selected dice  [R]"
	var flips: int = int(unit.get("flips", 0))
	## Unlocking is only offered while there is something left to do with the hand.
	var spent: bool = rerolls <= 0 and flips <= 0
	_lock_button.disabled = not planning or downed or (locked and spent)
	_lock_button.text = "Unlock" if locked else "Lock in"
	_lock_button.tooltip_text = "Locked in: no rerolls or shifts left to spend." if locked and spent else "Lock in your hand  [Space]"
	_flip_button.visible = str(unit.get("passive", {}).get("kind", "")) == "free_flip"
	var shift_refusal: String = _shift_refusal()
	_flip_button.disabled = not planning or locked or downed or flips <= 0 or selected.size() != 1 or not shift_refusal.is_empty()
	_flip_button.text = "Shift" if flips > 0 or not planning else "Shifted"
	_flip_button.tooltip_text = (shift_refusal.substr(0, 1).to_upper() + shift_refusal.substr(1) + ".") if not shift_refusal.is_empty() else SHIFT_TIP
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
		if flips > 0 and not shift_refusal.is_empty():
			_hint.text = "That die has no face of the other parity to shift to"
		elif rerolls <= 0 and flips > 0:
			_hint.text = "Pick one die to shift parity  [F], or lock in  [Space]"
		elif rerolls <= 0 and not roller.is_empty():
			_hint.text = "%s rolled for you: no rerolls this turn. Lock in  [Space]" % str(roller.get("name", "A creature"))
		elif rerolls <= 0:
			_hint.text = "No rerolls left. Lock in  [Space]"
		else:
			_hint.text = "Click dice to reroll  [1-5]" if selected.is_empty() else "%d selected" % selected.size()

func _roller(state: Dictionary) -> Dictionary:
	## The creature that threw this turn's hand for the party, if one did: a Roller in the
	## room on an odd turn (see the turn's opening in DeepBattle).
	if int(state.get("turn", 0)) % 2 != 1:
		return {}
	for foe in DeepBattle.living(state.get("enemies", [])):
		if DeepCreatures.has_trait(foe, "roll_for_you"):
			return foe
	return {}

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

func _charge_resonance(amount: int) -> void:
	## The battery empties into the counter at turn start; never one particle per stack.
	if _battery_tween != null and _battery_tween.is_valid():
		_battery_tween.kill()
	if _headless:
		_show_resonance(amount)
		return
	_show_resonance(0)
	var token: int = _resonance_token
	DeepAudio.from(_resonance_box, "resonance", {"volume": 0.8, "pitch": 0.9})
	_float_at(_resonance_box, "+%d Charged" % amount, DeepUi.ACCENT_HI, 20)
	DeepUi.burst(self, _center_of(_resonance_box), DeepUi.ACCENT_HI, 20, 100.0, 0.55)
	_battery_tween = create_tween()
	_battery_tween.tween_method(func(value: float) -> void:
		if token == _resonance_token:
			_resonance_value.text = str(int(round(value)))
			_resonance_value.add_theme_color_override("font_color", _resonance_color(int(round(value)))), 0.0, float(amount), 0.6)
	_battery_tween.tween_callback(func() -> void:
		if token == _resonance_token:
			_show_resonance(amount)
			DeepUi.pulse(_resonance_box, 1.2, 0.25))

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
	##
	## The rail is laid flat for the fight (see `DeepStone.flatten_rail`); the cards fold it
	## back onto the sockets: a socket's own gem large, and the Void gems riding it in a
	## line of chips under its name, each firing in turn after it. `_socket_cards` is by flat
	## index, so every event's socket lands on the thing to light, a card or a chip.
	var showing: bool = (planning or str(state.get("phase", "")) == "resolving") and Time.get_ticks_msec() >= _dice_settle_at
	var rail: Array = unit.get("rail", [])
	var birth_key: String = str(unit.get("character", ""))
	var shape: String = "%d|%s" % [rail.size(), str(unit.get("places", []))]
	if _rail_shape != shape or _birthstone_key != birth_key or (_birthstone_card != null and not is_instance_valid(_birthstone_card)):
		DeepUi.clear(_rail_box)
		_socket_cards.clear()
		_birthstone_card = null
		_birthstone_key = birth_key
		_rail_shape = shape
		var hosts: Array = []
		for _socket in range(maxi(DeepStone.socket_count(unit), 1 if rail.is_empty() else 0)):
			var host := VBoxContainer.new()
			host.add_theme_constant_override("separation", 3)
			host.mouse_filter = Control.MOUSE_FILTER_PASS
			_rail_box.add_child(host)
			var card := VBoxContainer.new()
			card.name = "Main"
			card.add_theme_constant_override("separation", 2)
			card.alignment = BoxContainer.ALIGNMENT_CENTER
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			host.add_child(card)
			hosts.append(host)
		for index in range(rail.size()):
			var place: Dictionary = DeepStone.place_of(unit, index)
			var host: VBoxContainer = hosts[clampi(int(place.socket), 0, hosts.size() - 1)]
			if int(place.rider) < 0:
				_socket_cards.append(host.get_node("Main"))
				continue
			var row: HBoxContainer = host.get_node_or_null("Riders")
			if row == null:
				row = HBoxContainer.new()
				row.name = "Riders"
				row.alignment = BoxContainer.ALIGNMENT_CENTER
				row.add_theme_constant_override("separation", 3)
				row.mouse_filter = Control.MOUSE_FILTER_PASS
				host.add_child(row)
			if int(place.rider) < RIDERS_SHOWN:
				var chip := Control.new()
				chip.custom_minimum_size = Vector2(RIDER_EDGE, RIDER_EDGE)
				chip.mouse_filter = Control.MOUSE_FILTER_PASS
				row.add_child(chip)
				_socket_cards.append(chip)
			else:
				## Past three, a count stands for the rest; what they do lights it.
				var badge: Label = row.get_node_or_null("More")
				if badge == null:
					badge = DeepUi.label(row, "", 10, DeepUi.INFO)
					badge.name = "More"
					badge.set_meta("badge", true)
					badge.mouse_filter = Control.MOUSE_FILTER_PASS
				badge.text = "+%d" % (int(place.rider) - RIDERS_SHOWN + 1)
				_socket_cards.append(badge)
				var socket_at: int = int(place.socket)
				var riding: Array = []
				for other in range(rail.size()):
					var spot: Dictionary = DeepStone.place_of(unit, other)
					if int(spot.socket) == socket_at and int(spot.rider) >= 0 and rail[other] is Dictionary:
						riding.append(rail[other])
				badge.tooltip_text = "\n".join(riding.slice(RIDERS_SHOWN).map(func(s: Dictionary) -> String: return "%s: %s" % [DeepUi.skill_name(s), DeepStone.text(s)])) + "\nClick to see every Void gem on this socket."
				badge.set_meta("riding", riding)
				if not bool(badge.get_meta("wired", false)):
					badge.set_meta("wired", true)
					badge.mouse_filter = Control.MOUSE_FILTER_STOP
					badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					badge.gui_input.connect(func(event: InputEvent) -> void:
						if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
							Inspector.gathering("Void gems on socket %d" % (socket_at + 1), "They ride the socket instead of sitting in it, and fire after its own gem, in this order.", "gem", badge.get_meta("riding", []))
							badge.accept_event())
		if not unit.get("birthstone", {}).is_empty():
			_birthstone_card = _build_birthstone_card(unit)
			_rail_box.add_child(_birthstone_card)
	var sockets: Array = unit.get("sockets", [])
	for socket in range(rail.size()):
		var card: Control = _socket_cards[socket]
		if bool(card.get_meta("badge", false)):
			continue
		var stone: Variant = rail[socket]
		var place: Dictionary = DeepStone.place_of(unit, socket)
		var rider: bool = int(place.rider) >= 0
		var socket_color: String = str(sockets[socket]) if socket < sockets.size() else "ANY"
		var tag: String = "%s|%s" % [DeepUi.stone_marks(stone) if stone is Dictionary else "", socket_color]
		if str(card.get_meta("tag", "")) != tag:
			card.set_meta("tag", tag)
			DeepUi.clear(card)
			var slot := Control.new()
			slot.name = "Slot"
			slot.mouse_filter = Control.MOUSE_FILTER_PASS
			if rider:
				slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			else:
				slot.custom_minimum_size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
			card.add_child(slot)
			var ring := SocketRing.new("VOID" if rider else socket_color, stone == null)
			ring.name = "Ring"
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(ring)
			if rider and stone is Dictionary:
				var picture := Thumbs.GemThumb.new(stone, RIDER_EDGE - 4)
				picture.name = "Gem"
				picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
				var fate: String = "Made by an Echo: it lasts as long as the fight does." if bool(stone.get("temporary", false)) \
					else "Fragile: shatters at the end of the run."
				picture.tooltip_text = "%s\n%s\nVoid · rides socket %d and fires right after its gem. %s" % [DeepStone.name(stone), DeepStone.text(stone), int(place.socket) + 1, fate]
				slot.add_child(picture)
			elif stone is Dictionary:
				var picture := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 12)
				picture.name = "Gem"
				picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
				picture.tooltip_text = DeepStone.name(stone) + "\n" + DeepStone.text(stone)
				slot.add_child(picture)
				## Stacked down the socket's top-right corner, so three of them fit without
				## crowding the stone or widening the rail.
				var marks := VBoxContainer.new()
				marks.name = "Raised"
				marks.alignment = BoxContainer.ALIGNMENT_BEGIN
				marks.add_theme_constant_override("separation", 1)
				marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, -4)
				marks.mouse_filter = Control.MOUSE_FILTER_PASS
				marks.z_index = 1
				slot.add_child(marks)
				var trigger_row := HBoxContainer.new()
				trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
				trigger_row.name = "Trigger"
				trigger_row.mouse_filter = Control.MOUSE_FILTER_PASS
				card.add_child(trigger_row)
				var name_label := DeepUi.fit_label(card, str(DeepStone.skill_of(stone).get("name", stone.skill)), 11, DeepUi.MUTED, SOCKET_EDGE + 8)
				name_label.name = "SkillName"
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
			var picture: Control = card.get_node_or_null("Slot/Gem")
			if picture != null:
				picture.set("context", DeepBattle.rail_context(state, unit, socket))
			## Pointing at a gem lights the dice in the tray its trigger reads: the plainest way
			## to learn what "a pair of 4+" asks for is to watch which dice answer it.
			card.set_meta("flat", socket)
			if not bool(card.get_meta("dice_link_wired", false)):
				card.set_meta("dice_link_wired", true)
				var linked: Control = card
				card.mouse_entered.connect(func() -> void: _light_dice_for(int(linked.get_meta("flat", -1))))
				card.mouse_exited.connect(func() -> void: _light_dice_for(-1))
			_sync_raised(unit, card, stone)
			var blocked: bool = DeepPatch.holds(unit.get("buried", []), socket) or DeepPatch.holds(unit.get("clouded", []), socket)
			## A gem this hand leaves dark steps back, so the ones it fires stand out at a glance
			## and "fires 2, fizzles 1" can be read off the rail itself. Its trigger, in the row
			## under it, still says what it is waiting for.
			var quiet: bool = showing and not entry.is_empty() and not active
			card.modulate = Color(0.55, 0.55, 0.6, 0.6) if blocked else (QUIET_GEM if quiet else Color.WHITE)
			card.tooltip_text = ("Buried in rubble: this gem cannot fire this turn." if DeepPatch.holds(unit.get("buried", []), socket) else "Clouded: hit the Clouder to clear it.") if blocked else ""
	_sync_birthstone(unit, planning, showing)

func _light_dice_for(socket: int) -> void:
	## The dice a gem's trigger counted in the hand as it stands, lit while that gem is pointed
	## at; -1 (or a gem this hand leaves dark) lights none.
	var reads: Array = []
	if socket >= 0 and str(state.get("phase", "")) == "planning" and Time.get_ticks_msec() >= _dice_settle_at:
		for entry in forecast.get("sockets", []):
			if int(entry.get("socket", -1)) == socket and bool(entry.get("active", false)):
				reads = entry.get("dice", []).map(func(d: Variant) -> String: return str(d))
	for id in _dice_views:
		var view: Variant = _dice_views[id]
		if view != null and is_instance_valid(view):
			view.set_highlight(reads.has(str(id)))

static func raised_ranks(unit: Dictionary, stone: Dictionary) -> Array:
	## What a Fire Opal, or any gem that raises another's ranks, has put on this gem for the
	## rest of the fight: [rank, amount] a rank, highest ranks first. The whole rail's buff and
	## this gem's own are one number to the player, so they are added together here.
	var own: Dictionary = unit.get("gem_buffs", {}).get(str(stone.get("id", "")), {})
	var rail: Dictionary = unit.get("rank_buff", {})
	var out: Array = []
	for rank in ["carat", "cut", "clarity"]:
		var amount: int = int(own.get(rank, 0)) + int(rail.get(rank, 0))
		if amount > 0:
			out.append([rank, amount])
	return out

func _sync_raised(unit: Dictionary, card: Control, stone: Dictionary) -> void:
	## An upgrade won mid-fight is said on the gem it was won for, not by a chip over the hud
	## that has to be hovered to be read: the stone grows to the carat it now counts as, and
	## each raised rank gets its own mark and number stacked in the corner of the socket.
	var slot: Control = card.get_node_or_null("Slot")
	var picture: Control = slot.get_node_or_null("Gem") if slot != null else null
	var marks: VBoxContainer = slot.get_node_or_null("Raised") if slot != null else null
	if picture == null or marks == null:
		return
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(card.get_meta("gem_inspection_wired", false)):
		card.set_meta("gem_inspection_wired", true)
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				var target: Control = card.get_node_or_null("Slot/Gem")
				if target != null:
					Inspector.stone(target.get("stone"), {"context": target.get("context")})
					card.accept_event())
	var raised: Array = raised_ranks(unit, stone)
	var key: String = str(raised)
	if str(marks.get_meta("key", "")) != key:
		marks.set_meta("key", key)
		DeepUi.clear(marks)
		for entry in raised:
			## Its own dark plate: a grown gem reaches out under these, and a bare mark on a
			## bright facet is unreadable.
			var plate := PanelContainer.new()
			plate.add_theme_stylebox_override("panel", DeepUi.flat(Color(0.03, 0.04, 0.06, 0.82), Color(DeepUi.GOOD, 0.45), 5, 2))
			plate.size_flags_horizontal = Control.SIZE_SHRINK_END
			plate.mouse_filter = Control.MOUSE_FILTER_PASS
			plate.tooltip_text = "+%d %s for the rest of this fight%s" % [int(entry[1]), str(entry[0]).capitalize(), _raised_by(unit, str(entry[0]))]
			marks.add_child(plate)
			var chip := DeepUi.hbox(plate, 2)
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			DeepUi.label(chip, "+%d" % int(entry[1]), 10, DeepUi.GOOD)
			DeepUi.icon(chip, str(entry[0]), 12, DeepUi.GOOD)
		if not raised.is_empty() and not _headless:
			DeepUi.pulse(picture, 1.14, 0.3)
	## Weight is the one rank the eye can see, so the stone is drawn at what it now weighs.
	var carat: int = 0
	for entry in raised:
		if str(entry[0]) == "carat":
			carat = int(entry[1])
	if carat <= 0:
		picture.call("configure", stone)
		return
	var grown: Dictionary = stone.duplicate(true)
	grown.carat = int(stone.get("carat", 1)) + carat
	picture.call("configure", grown)

static func _raised_by(unit: Dictionary, rank: String) -> String:
	var named: Array = unit.get("buff_sources", {}).get(rank, [])
	var words: Array = []
	for key in named:
		words.append(str(DeepContent.skill(str(key)).get("name", key)) if str(key) != "BIRTHSTONE" else "your Birthstone")
	return "" if words.is_empty() else ", from %s" % " and ".join(words)

func _build_birthstone_card(unit: Dictionary) -> VBoxContainer:
	## The character's Birthstone at the end of the rail: the stone in its own bezel, its
	## name, and its tiers as marks that light when the hand in the tray would fire them.
	var stone: Dictionary = DeepStone.birthstone(str(unit.get("character", "")))
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	## Top-aligned like a socket's own card, which sits at the top of its column: centred
	## in a rail made taller by riders or a trigger row, the bezel hung lower than the rest.
	card.alignment = BoxContainer.ALIGNMENT_BEGIN
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
	## A Bust has no mark of its own: it is the dice that did not come, so it turns them red.
	var bust: int = DiceIcons.ladder_penalty(defs, die)
	var busted: bool = bust >= 0 and bust < previewed.size() and bool(previewed[bust].get("active", false)) and showing
	key += "|%d|%s" % [lit, "bust" if busted else ""]
	if str(tiers_row.get_meta("key", "")) == key:
		return
	tiers_row.set_meta("key", key)
	DeepUi.clear(tiers_row)
	var notes: Array = []
	for index in range(defs.size()):
		var reason: String = str(previewed[index].get("reason", "")) if index < previewed.size() else ""
		notes.append(reason if key[index] == "0" and showing else "")
	if not die.is_empty():
		var dark: Color = DeepUi.BAD if busted else DeepUi.DIM
		var tip: String = ""
		if bust >= 0:
			tip = "%s: %s" % [str(defs[bust].get("name", "")), str(defs[bust].get("text", ""))]
		DiceIcons.build_ladder(tiers_row, defs, die, lit, 14, DeepUi.GOOD, dark, notes, tip)
	for index in range(defs.size()):
		var tier: Dictionary = defs[index]
		if DiceIcons.ladder_rung(tier, die) > 0 or index == bust:
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
		if color == "VOID":
			tone = DeepUi.INFO
			for arc in range(6):
				var angle: float = TAU * float(arc) / 6.0
				draw_arc(centre, radius, angle, angle + TAU / 9.0, 12, Color(tone, 0.5 + _ready_glow * 0.5), 2.0, true)
			draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - size * 0.5, size), false, Color(tone, 0.12 + _flash * 0.6))
			return
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

func _sync_phantoms(unit: Dictionary) -> void:
	## A Refract's phantoms: copies of the highest die that count for every gem after it this
	## turn. They are not the player's to reroll, so they stand apart from the five, smaller and
	## pale, ringed in the Void blue a rider wears; past three the rest are a count.
	if _phantom_box == null:
		return
	var ghosts: Array = unit.get("hand", []).filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false)))
	var key: String = ",".join(ghosts.map(func(r: Dictionary) -> String: return "%s=%d" % [str(r.get("die_id", "")), int(r.get("value", 0))]))
	if key == _phantom_key:
		return
	_phantom_key = key
	DeepUi.clear(_phantom_box)
	_phantom_box.visible = not ghosts.is_empty()
	if ghosts.is_empty():
		return
	var by_id: Dictionary = {}
	for die in unit.get("dice", []):
		by_id[str(die.id)] = die
	for index in range(mini(ghosts.size(), PHANTOMS_SHOWN)):
		var ghost: Dictionary = ghosts[index]
		var source_id: String = str(ghost.get("source_id", str(ghost.get("die_id", "")).split("_ph")[0]))
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", DeepUi.flat(Color(DeepUi.INFO, 0.08), Color(DeepUi.INFO, 0.55), 12, 3, 2))
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.tooltip_text = "Phantom %d: a copy of your highest die, made by a Refract. It counts for every gem after it this turn, then fades." % int(ghost.get("value", 0))
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_phantom_box.add_child(holder)
		var column := DeepUi.vbox(holder, 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var view := DiceView.new()
		view.custom_minimum_size = Vector2(PHANTOM_EDGE, PHANTOM_EDGE)
		view.size = Vector2(PHANTOM_EDGE, PHANTOM_EDGE)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.modulate = PHANTOM_TINT
		column.add_child(view)
		view.configure(by_id.get(source_id, {"shape": ghost.get("shape", "D6"), "material": str(ghost.get("material", "")), "faces": []}), ghost, false, false, DeepUi.INFO)
		DeepUi.label(column, "phantom %d" % int(ghost.get("value", 0)), 11, DeepUi.INFO, HORIZONTAL_ALIGNMENT_CENTER)
		if not _headless:
			DeepUi.pop_in(holder, 0.05 * float(index))
	if ghosts.size() > PHANTOMS_SHOWN:
		var more := DeepUi.label(_phantom_box, "+%d" % (ghosts.size() - PHANTOMS_SHOWN), 14, DeepUi.INFO)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		## What is behind the count: each phantom said on a hover, every one of them on a click.
		var said: Array = []
		var drawn: Array = []
		var captions: Array = []
		for ghost in ghosts:
			var source_id: String = str(ghost.get("source_id", str(ghost.get("die_id", "")).split("_ph")[0]))
			var source: Dictionary = by_id.get(source_id, {"shape": ghost.get("shape", "D6"), "material": str(ghost.get("material", "")), "faces": []})
			said.append("Phantom %d, a copy of your %s" % [int(ghost.get("value", 0)), DeepDice.describe(source)])
			drawn.append([source, int(ghost.get("face", -1))])
			captions.append("phantom %d" % int(ghost.get("value", 0)))
		more.tooltip_text = "\n".join(said.slice(PHANTOMS_SHOWN)) + "\nClick to see every phantom die."
		more.mouse_filter = Control.MOUSE_FILTER_STOP
		more.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		more.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Inspector.gathering("Phantom dice", "Copies of your highest die, made by a Refract. Each counts for every gem after the one that made it this turn, then fades.", "die", [], drawn, captions)
				more.accept_event())

func _sync_tray(unit: Dictionary, planning: bool) -> void:
	_sync_phantoms(unit)
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
			## An exploding face is added up as the die lands on each throw, not all at once.
			view.chain_stepped.connect(func(total: int) -> void:
				if is_instance_valid(value):
					value.text = DiceIcons.face_text(total, "exploding").strip_edges()
					if not _headless:
						DeepUi.pulse(value, 1.25, 0.2))
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
		view.configure(by_id.get(id, {"shape": roll.shape, "material": str(roll.get("material", "")), "faces": []}), tagged, chosen, false, DeepUi.ACCENT)
		var lift: float = -10.0 if chosen else 0.0
		if not is_equal_approx(view.position.y, lift) and not _headless:
			var tween := view.create_tween()
			tween.tween_property(view, "position:y", lift, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var value: Label = view.get_parent().get_node("Value")
		## The die itself shows its number; only what the number cannot say goes under it.
		var words: String = ""
		if str(roll.get("kind", "plain")) != "plain":
			var added_up: int = view.running_total()
			words = DiceIcons.face_text(added_up if added_up >= 0 else int(roll.value), str(roll.get("kind", "plain"))).strip_edges()
		if bool(roll.get("locked", false)):
			words += "  ⌂"
		if bool(roll.get("flipped", false)):
			words += "  ⇅"
		if bool(roll.get("loaded", false)):
			words += "  ↻"
		value.text = words.strip_edges()
		value.add_theme_color_override("font_color", DeepUi.ACCENT if chosen else DeepUi.MUTED)

func _sync_forecast() -> void:
	## Held still through a whole resolving turn, so it is rebuilt only when it changes.
	var totals: Dictionary = forecast.get("totals", {})
	var key: String = "%s#%d" % [str(totals), DeepRules.pyrite(me())]
	if key == _forecast_key and _forecast_box.get_child_count() > 0:
		return
	_forecast_key = key
	DeepUi.clear(_forecast_box)
	if totals.is_empty():
		DeepUi.label(_forecast_box, "—", 14, DeepUi.DIM)
		return
	## Pyrite is not one of these: it can go either way, and is said below as what the hand would
	## win or spend, never as the bank it would leave.
	var rows: Array = [["sword", "damage", DeepUi.BAD, "Damage"], ["shield", "block", DeepUi.BLOCK, "Block"], ["heart", "heal", DeepUi.GOOD, "Healing"],
		["drop", "poison", DeepUi.POISON, "Poison"]]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forecast_box.add_child(grid)
	var any: bool = false
	for row in rows:
		var amount: int = int(totals.get(row[1], 0))
		if amount == 0:
			continue
		any = true
		var cell := DeepUi.hbox(grid, 5)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = str(row[3])
		DeepUi.icon(cell, str(row[0]), 20, row[2], str(row[3]))
		DeepUi.title(cell, str(amount), 22, row[2])
	var pyrite: int = int(totals.get("gold", 0))
	if not any and pyrite == 0:
		DeepUi.label(_forecast_box, "Nothing fires on this hand.", 13, DeepUi.DIM)
	var summary := DeepUi.hbox(_forecast_box, 10)
	var fires: int = int(totals.get("fires", 0))
	var fizzles: int = int(totals.get("fizzles", 0))
	DeepUi.stat(summary, "check", str(fires), DeepUi.GOOD, 13, "Gems that would fire")
	DeepUi.stat(summary, "cross_out", str(fizzles), DeepUi.DIM if fizzles == 0 else DeepUi.BAD, 13, "Gems that would fizzle")
	DeepUi.stat(summary, "ore", ("+%d" % pyrite) if pyrite > 0 else ("−%d" % -pyrite if pyrite < 0 else "±0"),
		DeepUi.ORE if pyrite > 0 else (DeepUi.BAD if pyrite < 0 else DeepUi.DIM), 13,
		"Pyrite this hand would win (or spend), on top of the %d you have" % DeepRules.pyrite(me()))
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
	var _unit: Dictionary = {}
	func _init() -> void:
		add_theme_stylebox_override("panel", DeepUi.raised(Color(0.06, 0.075, 0.105, 0.88), DeepUi.LINE, 12, 10, 0.4))
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Click to see their rail, their bag and their dice."
		var box := DeepUi.vbox(self, 5)
		var head := DeepUi.hbox(box, 6)
		DeepUi.icon(head, "person", 16, DeepUi.INFO)
		_name = DeepUi.label(head, "", 14, DeepUi.PAPER)
		DeepUi.spacer(head)
		_note = DeepUi.label(head, "", 11, DeepUi.MUTED)
		## Tall enough to carry its number, and tinted as it runs low: an ally in trouble shows.
		_bar = DeepUi.bar(box, 14.0)
		_bar.warn = true
		_hand = DeepUi.hbox(box, 3)
		_effects = EffectChips.Row.new(13)
		box.add_child(_effects)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _unit.is_empty():
			load("res://view/inspect/inspector.gd").member(_unit)
			accept_event()
	func update(unit: Dictionary, planning: bool) -> void:
		_unit = unit
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
					_hand.add_child(DiceIcons.face(20, int(roll.value), DiceIcons.die_palette(roll).body, str(roll.get("shape", "D6")), true, DiceIcons.face_text(int(roll.value), str(roll.get("kind", "plain")))))
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
			plate.inspect.connect(func(move: String) -> void: _inspect_creature(id, move))
			plate.mouse_entered.connect(func() -> void: _hover_creature(id))
			plate.mouse_exited.connect(func() -> void: _hover_creature(""))
			_plates_layer.add_child(plate)
			_plates[id] = plate
			DeepUi.pop_in(plate, 0.4)
		plate.update(foe, state, local_id, target_id == id, preview if target_id == id else 0)
		_dress(_creature(id), foe)
	for id in _plates.keys():
		if not present.has(id):
			if is_instance_valid(_plates[id]):
				_plates[id].queue_free()
			_plates.erase(id)

class Plate extends PanelContainer:
	## A creature's nameplate: health with a ghost of what this hand would take off it,
	## its buffs, ordered dice and compact ability icons.
	## Its moveset opens in the table when it is targeted or hovered; right-click for the inspector.
	signal inspect(move: String)
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
		## What it has rolled so far this action rides on the plate with its dice, so the
		## numbers read over its head and not only in its table.
		var hand: Array = foe.get("hand", []) if bool(foe.get("acting", false)) or str(foe.get("beat", "")) == "done" else []
		var moves_key: String = str(dice) + str(moves) + str(foe.get("stolen_dice", 0)) + str(foe.get("suppressed", 0)) + str(hand.map(func(r: Dictionary) -> int: return int(r.get("value", 0))))
		if moves_key == _moves_key:
			return
		_moves_key = moves_key
		DeepUi.clear(_dice)
		var suppressed: int = int(foe.get("suppressed", 0)) if bool(foe.get("acting", false)) else int(foe.get("stolen_dice", 0))
		for index in range(dice.size()):
			var gone: bool = index >= dice.size() - suppressed
			var rolled: bool = index < hand.size()
			var mark: String = "×" if gone else (str(int(hand[index].get("value", 0))) if rolled else "?")
			_dice.add_child(DiceIcons.face(16, int(hand[index].get("value", 0)) if rolled else 0, DeepUi.DIM if gone else DiceIcons.die_palette(dice[index]).body, str(dice[index].shape), rolled, mark))
			DeepUi.label(_dice, str(dice[index].shape).to_lower() + ("×" if gone else ""), 11, DeepUi.DIM if gone else DeepUi.MUTED)
		DeepUi.clear(_abilities)
		for move in moves:
			var tip: String = str(move.name) + " · " + DeepCreatures.trigger_words(move)
			for effect in move.get("effects", []):
				tip += "\n" + DeepCreatures.effect_words(effect)
			var mark: String = EnemyPanel.move_glyph(move)
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

func _sync_enemy_panel() -> void:
	## The table is always open on someone: the creature acting, else the one under the
	## pointer, else the player's target.
	if _enemy_panel == null:
		return
	var id: String = _hovered_creature if not _hovered_creature.is_empty() else str(me().get("target", ""))
	for foe in state.get("enemies", []):
		if bool(foe.get("acting", false)) and int(foe.hp) > 0:
			id = str(foe.id)
			break
	var foe: Dictionary = DeepBattle.enemy(state, id)
	if foe.is_empty() or int(foe.get("hp", 0)) <= 0:
		## A target that has just fallen hands the table to whoever is still standing.
		var living: Array = DeepBattle.living(state.get("enemies", []))
		if living.is_empty():
			_enemy_panel.reset()
			return
		foe = living[0]
	_enemy_panel.show_enemy(foe, int(state.get("turn", 0)))
	_position_enemy_panel()

func _position_enemy_panel() -> void:
	## The table keeps to the left of the room (right of the chart, when it is open), and
	## crosses to the right (left of the party cards) only when it would stand in front of a
	## creature there and the right is clearer.
	if _enemy_panel == null or not _enemy_panel.visible:
		return
	var right: float = size.x - 20.0
	if not _ally_cards.is_empty():
		right -= _ally_box.size.x + 20.0
	var panel_size: Vector2 = _enemy_panel.size
	var at_right := Rect2(Vector2(maxf(20.0, right - panel_size.x), 82.0), panel_size)
	var at_left := Rect2(Vector2(minf(20.0 + left_inset, at_right.position.x), 82.0), panel_size)
	var bodies: Array = _creature_rects()
	## A little slack on the way back keeps a bobbing creature from flicking it side to side.
	var on_right: bool = is_equal_approx(_enemy_panel.position.x, at_right.position.x) and at_left.position.x != at_right.position.x
	var left_cover: float = _cover(at_left.grow(12.0 if on_right else 0.0), bodies)
	if left_cover > 0.0 and _cover(at_right, bodies) < left_cover:
		_enemy_panel.position = at_right.position
	else:
		_enemy_panel.position = at_left.position

func _creature_rects() -> Array:
	## Where each living creature and its nameplate stand on the screen.
	var rects: Array = []
	for foe in DeepBattle.living(state.get("enemies", [])):
		var id: String = str(foe.id)
		var plate: Variant = _plates.get(id, null)
		if plate != null and is_instance_valid(plate) and plate.visible:
			rects.append(Rect2(plate.global_position - global_position, plate.size))
		var creature: CrystalCreature = _creature(id)
		if creature == null or _camera == null or _headless:
			continue
		var feet: Vector2 = _to_screen(creature.rest_position)
		var head: Vector2 = _to_screen(creature.rest_position + Vector3(0, creature.anchor.y, 0))
		var tall: float = maxf(40.0, feet.y - head.y)
		rects.append(Rect2(Vector2(feet.x - tall * 0.35, head.y), Vector2(tall * 0.7, tall)))
	return rects

static func _cover(area: Rect2, rects: Array) -> float:
	var total: float = 0.0
	for rect in rects:
		var overlap: Rect2 = area.intersection(rect)
		total += overlap.get_area()
	return total
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
	var dock_top: float = _dock.position.y if _dock != null else size.y - 200.0
	_effects_box.size.x = maxf(240.0, size.x - 300.0)
	_effects_box.position = Vector2(22.0, dock_top - _effects_box.size.y - 8.0)
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
	_place_enemy_roll(delta)
	_frame_camera(highest, ceiling, delta)

# --- the die over a creature's head -------------------------------------------------------------
##
## A creature's roll used to turn inside its moves table, which made the table a different
## size while it acted and put a big die over the room. It turns over the creature's own
## head instead, riding just above its plate, or beside the plate when the plate is already
## against the top of the screen; the table only reads the number once it has landed.

func _show_enemy_roll(event: Dictionary) -> void:
	if _headless or stage.walking():
		return
	if _enemy_roll == null or not is_instance_valid(_enemy_roll):
		_enemy_roll = RollBadge.new()
		_plates_layer.add_child(_enemy_roll)
	_enemy_roll_id = str(event.get("unit", ""))
	_enemy_roll.roll(event)

func _hide_enemy_roll() -> void:
	_enemy_roll_id = ""
	if _enemy_roll != null and is_instance_valid(_enemy_roll):
		_enemy_roll.put_away()

func _place_enemy_roll(delta: float) -> void:
	if _enemy_roll == null or not is_instance_valid(_enemy_roll) or not _enemy_roll.visible:
		return
	var plate: Variant = _plates.get(_enemy_roll_id, null)
	if plate == null or not is_instance_valid(plate) or not (plate as Control).visible or _creature(_enemy_roll_id) == null:
		_hide_enemy_roll()
		return
	var over: Control = plate
	var goal := Vector2(over.position.x + (over.size.x - _enemy_roll.size.x) * 0.5, over.position.y - _enemy_roll.size.y - 6.0)
	if goal.y < 8.0:
		## The plate is already against the top of the screen: the die stands beside it,
		## on whichever side has the room.
		var right_side: bool = over.position.x + over.size.x + _enemy_roll.size.x + 20.0 < size.x
		goal = Vector2(over.position.x + over.size.x + 10.0 if right_side else over.position.x - _enemy_roll.size.x - 10.0, over.position.y)
	goal.x = clampf(goal.x, 8.0, size.x - _enemy_roll.size.x - 8.0)
	goal.y = maxf(goal.y, 8.0)
	_enemy_roll.position = _enemy_roll.position.lerp(goal, clampf(delta * 14.0, 0.0, 1.0)) if _enemy_roll.position != Vector2.ZERO else goal

class RollBadge extends Control:
	## One die turning in the air over a creature. The solid itself says what it landed on, so
	## nothing is written under it and it keeps no room for words that are not there.
	const EDGE: float = 84.0
	var _die: DiceView
	var _tween: Tween
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(EDGE, EDGE)
		size = custom_minimum_size
		_die = DiceView.new()
		_die.position = Vector2.ZERO
		_die.size = Vector2(EDGE, EDGE)
		_die.custom_minimum_size = _die.size
		_die.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_die)
		visible = false
	func roll(event: Dictionary) -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		visible = true
		modulate.a = 1.0
		var suspense: bool = bool(event.get("suspense", false))
		_die.spin_seconds = maxf(0.3, float(event.get("duration", 1.1)) - 0.28)
		_die.suspense = suspense
		_die.suspense_scale = CameraRig.comfort
		_die.configure(event.die, event.roll, false, true, DeepUi.BAD)
		_tween = create_tween()
		if suspense:
			## Rising clacks on scaled time, so the fight's speed cannot pull them apart.
			for index in range(5):
				var pitch: float = 0.8 + float(index) * 0.14
				_tween.tween_callback(func() -> void: DeepAudio.from(_die, "die_tumble", {"pitch": pitch, "volume": 0.3 + pitch * 0.15, "gap": 0.0}))
				_tween.tween_interval(_die.spin_seconds / 5.0)
		else:
			_tween.tween_interval(_die.spin_seconds)
		var value: int = int(event.get("roll", {}).get("value", 0))
		_tween.tween_callback(func() -> void:
			DeepUi.pulse(_die, 1.08 if ScreenFx.calm else 1.22, 0.23)
			if not ScreenFx.calm:
				DeepUi.burst(self, _die.size * 0.5, DeepUi.BAD, 13, 95.0, 0.25)
			DeepAudio.from(_die, "hit_crit", {"volume": 0.45, "pitch": 0.9 + float(value) * 0.018}))
	func put_away() -> void:
		if not visible:
			return
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, 0.25)
		_tween.tween_callback(func() -> void:
			visible = false
			position = Vector2.ZERO)

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

func _shift_refusal() -> String:
	## Why the one die picked out cannot be shifted, or "" (also "" with no single die picked).
	if selected.size() != 1:
		return ""
	var unit: Dictionary = me()
	for roll in unit.get("hand", []):
		if str(roll.get("die_id", "")) == str(selected[0]) and not bool(roll.get("phantom", false)):
			return DeepBattle.shift_refusal(unit, roll)
	return ""

func _flip() -> void:
	## Sleight: the one chosen die turns over onto a face of the other parity.
	if selected.size() != 1 or int(me().get("flips", 0)) <= 0 or bool(me().get("locked", false)):
		return
	if not _shift_refusal().is_empty():
		DeepAudio.play("ui_back", {"volume": 0.6})
		return
	var id: String = str(selected[0])
	command.emit({"kind": "flip", "die": id})
	DeepAudio.play("die_pick", {"volume": 0.9})
	if not _headless and _dice_views.has(id):
		var view: Control = _dice_views[id]
		DeepUi.burst(self, view.global_position - global_position + view.size * 0.5, DeepUi.ACCENT_HI, 16, 150.0, 0.5)
	selected.clear()

func _lock_if_spent() -> void:
	if _headless or not is_instance_valid(self) or not is_inside_tree() or state.is_empty():
		return
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or bool(unit.get("locked", false)) or bool(unit.get("downed", false)):
		return
	if int(unit.get("rerolls", 0)) <= 0 and int(unit.get("flips", 0)) <= 0:
		_toggle_lock()

func _toggle_lock() -> void:
	var locking: bool = not bool(me().get("locked", false))
	## Locked in with nothing left to spend: there is nothing to unlock for.
	if not locking and int(me().get("rerolls", 0)) <= 0 and int(me().get("flips", 0)) <= 0:
		return
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
	## The hand's keys only mean something while it is being planned. Pressed while a turn
	## plays out they used to reach the rules anyway and come back as a red refusal.
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or unit.is_empty() or bool(unit.get("downed", false)):
		return
	match event.keycode:
		KEY_R:
			_reroll()
		KEY_F:
			## F is also the fast-fight key: it is a Sleight only for a hand that has one to
			## spend, and otherwise goes on to the speed toggle.
			if int(unit.get("flips", 0)) <= 0 or bool(unit.get("locked", false)):
				return
			_flip()
		KEY_SPACE:
			_toggle_lock()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var index: int = event.keycode - KEY_1
			var ids: Array = _dice_views.keys()
			if index < ids.size():
				_toggle_die(str(ids[index]))
		_:
			return
	get_viewport().set_input_as_handled()

# --- events --------------------------------------------------------------------------------

func perform(event: Dictionary) -> void:
	## Animate one battle event against the state already shown.
	var kind: String = str(event.get("kind", ""))
	if kind == "turn_begin":
		selected.clear()
		for entry in event.get("hands", []):
			if str(entry.get("unit", "")) == local_id:
				_pending_dues = entry.get("dues", {})
				_pending_regrown = entry.get("regrown", {})
		for battery in event.get("charged", []):
			if str(battery.unit) == local_id:
				_charge_resonance(int(battery.amount))
			elif _ally_cards.has(str(battery.unit)):
				_float_at(_ally_cards[str(battery.unit)], "+%d Charged" % int(battery.amount), DeepUi.ACCENT_HI, 16)
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
	match kind:
		"enemy_roll": _show_enemy_roll(event)
		"enemy_end", "skip", "battle_over", "turn_begin": _hide_enemy_roll()
	if _headless or stage.walking():
		return
	match kind:
		"turn_begin":
			DeepAudio.play("turn_begin", {"volume": 0.7})
			_announce("Turn %d" % int(event.get("turn", 1)), DeepUi.PAPER, "Roll, reroll, lock in", 0.9)
			## What the creatures' presence did to the party as the turn opened.
			var said: int = 0
			for hurt in event.get("afflicted", []):
				if str(hurt.get("unit", "")) != local_id:
					continue
				var words: String = str(hurt.get("kind", "")).capitalize()
				if str(hurt.get("kind", "")) == "die_lock":
					words = "Straight shattered · die locked"
				_later_do(0.7 + 0.25 * float(said), func() -> void: _float_at(_hp_bar, words, DeepUi.BAD, 16))
				said += 1
			for entry in event.get("hands", []):
				if str(entry.get("unit", "")) != local_id:
					continue
				if not entry.get("locked", []).is_empty():
					_later_do(1.1, func() -> void: _float_at(_tray_box, "%s locked" % DeepUi.plural(entry.locked.size(), "die", "dice"), DeepUi.BAD, 16))
			_camera.nudge(Vector3(0, 0.08, -0.15), 0.6)
			## The dice have already been thrown for this turn: what they paid is played over
			## the tray a beat later, once the solids have settled where they landed.
			var owed: Dictionary = _pending_dues
			var back: Dictionary = _pending_regrown
			_pending_dues = {}
			_pending_regrown = {}
			_later_do(0.55, func() -> void:
				_dice_regrown(back)
				_dice_dues(owed, _dice_views.keys()))
		"resolution_begin":
			DeepAudio.play("resolve", {"volume": 0.75})
			_announce("Resolve", DeepUi.ACCENT, "", 0.5)
			_camera.punch(-3.0, 0.8)
			_screen_fx.blink(DeepUi.ACCENT, 0.06)
		"rail_begin":
			if str(event.get("unit", "")) == local_id:
				_show_resonance(int(event.get("resonance", 0)))
		"gem_fire":
			_gem_fire(event)
			if str(event.get("unit", "")) == local_id:
				if int(event.get("backlash", 0)) > 0:
					DeepAudio.play("enemy_strike", {"volume": 0.5})
					_screen_fx.wound(0.4)
					_float_at(_hp_bar, "−%d Backlash" % int(event.backlash), Color("ff8ad8"), 18)
				if bool(event.get("damped", false)):
					_float_at(_resonance_box, "Dampened", Color("c8b8ff"), 14)
			## A Refractor drinking in a colour it had not seen: a point of Strength more.
			for fed in event.get("fed", []):
				var drinker: CrystalCreature = _creature(str(fed.get("unit", "")))
				if drinker != null:
					var hue := Color("#" + str(DeepContent.color(str(fed.get("color", ""))).get("hue", "c8a8ff")))
					drinker.flash(1.4)
					_fx.rise(drinker.centre(), hue, 14, 0.5)
					_float_world(drinker.centre() + Vector3(0, 0.7, 0), "+1 Strength", hue, 15)
		"gem_fizzle":
			_gem_fizzle(event)
		"birthstone":
			_birthstone_fire(event)
		"reroll":
			if str(event.get("unit", "")) == local_id:
				_later_do(0.4, func() -> void: _dice_dues(event.get("dues", {}), event.get("dice", [])))
				## The last reroll spent, there is nothing left to decide: the hand locks itself
				## once its dice have been seen to land. Unlock takes it back.
				_later_do(1.3, _lock_if_spent)
		"flip":
			if str(event.get("unit", "")) == local_id:
				DeepAudio.play("die_settle", {"volume": 0.8})
				_float_at(_tray_box, "Shifted to %d" % int(event.get("value", 0)), DeepUi.ACCENT_HI, 16)
		"enemy_begin":
			var who: String = str(event.get("unit", ""))
			var up: CrystalCreature = _creature(who)
			if up != null:
				if bool(event.get("emerged", false)):
					DeepAudio.play_at(global_position + _to_screen(up.centre()), "rock_break", {"volume": 0.8})
					_fx.puff(Vector3(up.global_position.x, 0.3, up.global_position.z), Color(0.5, 0.42, 0.35), 24, 1.2, 1.4, 1.0)
					_fx.shards(Vector3(up.global_position.x, 0.2, up.global_position.z), Color(0.55, 0.5, 0.45), 12, 4.0, 0.14, 1.0)
					_camera.add_trauma(0.35)
					_float_world(up.global_position + Vector3(0, up.anchor.y, 0), "Erupts!", Color("ffd06a"), 20)
				var charge: Dictionary = event.get("charge", {})
				if bool(charge.get("broken", false)):
					_fx.shards(up.centre(), Color("ffe27a"), 16, 4.0, 0.12, 1.0)
					_float_world(up.centre() + Vector3(0, 0.6, 0), "Charge broken", DeepUi.GOOD, 22)
				elif int(charge.get("turns", 0)) > 0:
					_fx.rise(up.centre(), Color("ffe27a"), 30, 0.8)
					_float_world(up.centre() + Vector3(0, 0.6, 0), "Charging · %d" % int(charge.turns), Color("ffe27a"), 18)
				if int(event.get("flee_in", -1)) == 1:
					_float_world(up.global_position + Vector3(0, up.anchor.y, 0), "Its last turn here", DeepUi.ORE, 16)
				for grown in event.get("regrown", []):
					var back: CrystalCreature = _creature(str(grown))
					if back != null:
						back.spawn(0.1)
						_fx.rise(back.global_position, DeepUi.GOOD, 20, 0.8)
						_float_world(back.centre(), "Grows back", DeepUi.GOOD, 18)
		"enemy_end":
			var who: String = str(event.get("unit", ""))
			var down: CrystalCreature = _creature(who)
			if down != null and bool(event.get("burrowed", false)):
				DeepAudio.play_at(global_position + _to_screen(down.centre()), "rock_break", {"volume": 0.6})
				_fx.puff(Vector3(down.global_position.x, 0.3, down.global_position.z), Color(0.5, 0.42, 0.35), 20, 1.1, 1.2, 0.6)
				_float_world(down.global_position + Vector3(0, down.anchor.y, 0), "Burrows", Color("c8b8a0"), 18)
				down.burrow(true)
		"rail_end":
			var resonance: int = int(event.get("resonance", 0))
			## Second Wind is paid as the rail closes, on the Resonance it built.
			if int(event.get("healed", 0)) > 0:
				if str(event.get("unit", "")) == local_id:
					DeepAudio.play("heal", {"volume": 0.6})
					_float_at(_hp_bar, "+%d Second Wind" % int(event.healed), DeepUi.GOOD, 20)
				elif _ally_cards.has(str(event.get("unit", ""))):
					_float_at(_ally_cards[str(event.unit)], "+%d" % int(event.healed), DeepUi.GOOD, 16)
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
				if bool(event.get("combo_breaker", false)):
					_float_world(creature.centre(), "Combo Breaker", DeepUi.INFO, 22)
					_fx.shield(creature.centre(), Vector3.FORWARD, DeepUi.INFO, 1.0, 0.5)
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
	if tick.has("lifeline"):
		_show_lifeline(str(tick.get("unit", "")), int(tick.lifeline))
	## One round of poison (or regrowth) on one unit, and whoever drank from it.
	var target_id: String = str(tick.get("unit", ""))
	var color: Color = DeepUi.POISON if str(tick.get("kind", "")) == "poison" else (Color("ff7a2a") if str(tick.get("kind", "")) == "burn" else DeepUi.GOOD)
	## Burning is a wound like poison; block soaking it shows as block lost.
	var hurt: bool = str(tick.get("kind", "")) in ["poison", "burn"]
	if str(tick.get("kind", "")) == "burn" and int(tick.get("soaked", 0)) > 0 and target_id == local_id:
		_float_at(_hp_bar, "%d burn blocked" % int(tick.soaked), DeepUi.BLOCK, 14)
	if _creatures.has(target_id) and is_instance_valid(_creatures[target_id]):
		var creature: CrystalCreature = _creatures[target_id]
		DeepAudio.play_at(global_position + _to_screen(creature.centre()), "poison" if hurt else "heal", {"volume": 0.5})
		_fx.puff(creature.centre(), color, 10, 0.6, 1.0, 0.5, true)
		_float_world(creature.centre(), ("−%d" if hurt else "+%d") % int(tick.get("amount", 0)), color, 22)
		if hurt:
			creature.hit(0.3)
		if bool(tick.get("escorts", false)):
			_float_world(creature.centre() + Vector3(0, 0.5, 0), "fed by its tendrils", DeepUi.GOOD, 13)
		_thresholds(tick, creature)
		if bool(tick.get("killed", false)):
			_deathburst(tick, creature)
			_kill(creature)
	elif target_id == local_id:
		DeepAudio.play("poison" if hurt else "heal", {"volume": 0.6})
		_float_at(_hp_bar, ("−%d" if hurt else "+%d") % int(tick.get("amount", 0)), color, 22)
		_screen_fx.blink(color, 0.1)
	elif _ally_cards.has(target_id):
		_float_at(_ally_cards[target_id], ("−%d" if hurt else "+%d") % int(tick.get("amount", 0)), color, 16)
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
			_float_at(anchor, "fizzle", DeepUi.DIM, 13)
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
	var card_anchor: Control = _socket_cards[socket] if mine and socket >= 0 and socket < _socket_cards.size() else null
	if mine:
		_die_boost(card_anchor if card_anchor != null else _tray_box, event, color)
	_animate_effects(event.get("effects", []), origin, color, mine, card_anchor, magnitude)

func _die_anchor(die_id: String) -> Control:
	## The die in the tray, or the tray itself when that die is not on screen.
	if _dice_views.has(die_id) and is_instance_valid(_dice_views[die_id]):
		return _dice_views[die_id]
	return _tray_box

func _purse() -> Vector3:
	## Where pyrite ends up: the near corner of the room, under the reader's own hand.
	return _camera.global_position + (-_camera.global_transform.basis.z) * 1.4 + Vector3(0.8, -0.7, 0)

func _die_world(die_id: String) -> Vector3:
	## A point in the room over the tray, roughly under the die: the pile a coin flies from.
	var spread: float = 0.0
	var ids: Array = _dice_views.keys()
	if ids.has(die_id) and ids.size() > 1:
		spread = (float(ids.find(die_id)) / float(ids.size() - 1) - 0.5) * 2.4
	return _camera.global_position + (-_camera.global_transform.basis.z) * 2.4 + Vector3(spread, -1.1, 0)

func _dice_dues(dues: Dictionary, die_ids: Array = []) -> void:
	## What the dice themselves paid out this throw, played where it happened. A Crystal die
	## rings the Resonance count up, a Golden face and a Fool's Gold die send pyrite into the
	## purse, Blood takes its price out of the health bar, a Tally face climbs, and Glass
	## breaks. Nothing here decides anything: the fight already paid it.
	if dues.is_empty() or _headless:
		return
	var anchor: Control = _die_anchor(str(die_ids[0]) if not die_ids.is_empty() else "")
	var resonance: int = int(dues.get("resonance", 0))
	if resonance > 0:
		var tone: Color = DiceIcons.material_palette("crystal").get("body", DeepUi.RESONANCE)
		## The count itself is the state's to say (a forecast is standing in it while the turn
		## is planned); this is only the ring of the die that paid it.
		DeepAudio.from(_resonance_box, "resonance", {"volume": 0.55, "pitch": 1.15})
		_float_at(_resonance_box, "+%d" % resonance, tone, 18)
		DeepUi.burst(self, _center_of(_resonance_box), tone, 10 + resonance * 4, 110.0, 0.5)
		for id in die_ids:
			var lit: Control = _die_anchor(str(id))
			if lit != _tray_box:
				DeepUi.burst(self, _center_of(lit), tone, 8, 70.0, 0.45)
	var pyrite: int = int(dues.get("pyrite", 0))
	if pyrite > 0:
		_later_do(0.14, func() -> void:
			DeepAudio.play("ore", {"volume": 0.6})
			_fx.coins(_die_world(str(die_ids[0]) if not die_ids.is_empty() else ""), _purse(), 4 + mini(10, pyrite))
			_float_at(anchor, "+%d pyrite" % pyrite, DeepUi.ORE, 18))
	var blood: int = int(dues.get("hp", 0))
	if blood > 0:
		var gore: Color = DiceIcons.material_palette("blood").get("body", DeepUi.BAD)
		_later_do(0.28, func() -> void:
			DeepAudio.play("hit_light", {"volume": 0.5})
			_float_at(_hp_bar, "-%d" % blood, gore, 20)
			DeepUi.burst(self, _center_of(anchor), gore, 14, 90.0, 0.5))
	var beat: float = 0.42
	for climb in dues.get("climbed", []):
		var grown: Control = _die_anchor(str(climb.get("die", "")))
		var shown: int = int(climb.get("value", 0))
		_later_do(beat, func() -> void:
			DeepAudio.from(grown, "tally", {"volume": 0.6})
			_float_at(grown, "↑ %d" % shown, DiceIcons.face_kind_tint("tally"), 20)
			DeepUi.pulse(grown, 1.22, 0.35)
			DeepUi.burst(self, _center_of(grown), DiceIcons.face_kind_tint("tally"), 12, 80.0, 0.5))
		beat += 0.16
	for broken in dues.get("shattered", []):
		var lost: Control = _die_anchor(str(broken))
		var shards: Color = DiceIcons.material_palette("glass").get("body", DeepUi.PAPER)
		_later_do(beat, func() -> void:
			DeepAudio.play("die_break", {"volume": 0.85})
			_float_at(lost, "Shattered", shards, 20)
			DeepUi.burst(self, _center_of(lost), shards, 26, 190.0, 0.7)
			_screen_fx.blink(DeepUi.PAPER, 0.05))
		beat += 0.18

func _dice_regrown(regrown: Dictionary) -> void:
	## A die or a gem that was broken is back, the way its hero came down with it.
	if regrown.is_empty() or _headless:
		return
	for die in regrown.get("dice", []):
		var back: Control = _die_anchor(str(die.get("id", "")))
		DeepAudio.play("die_settle", {"volume": 0.7})
		_float_at(back, "%s, remade" % DeepDice.describe(die), DeepUi.INFO, 16)
	for socket in regrown.get("sockets", []):
		var at: int = int(socket)
		if at >= 0 and at < _socket_cards.size():
			DeepUi.pulse(_socket_cards[at], 1.2, 0.45)
			_float_at(_socket_cards[at], "Recut", DeepUi.INFO, 16)

func _die_boost(anchor: Control, event: Dictionary, color: Color) -> void:
	## What the dice themselves were worth to this gem: the materials that answered its
	## colour, said on the gem that felt them.
	var boost: float = float(event.get("die_boost", 1.0))
	if boost <= 1.001 or anchor == null or not is_instance_valid(anchor):
		return
	var materials: Array = event.get("materials", [])
	var tone: Color = DiceIcons.material_palette(str(materials[0])).get("body", color) if not materials.is_empty() else color
	var named: Array = []
	for material in materials:
		var word: String = DeepDice.material_name(str(material))
		if not named.has(word):
			named.append(word)
	_float_at(anchor, "×%.2f %s" % [boost, ", ".join(named)], tone, 20)
	DeepUi.pulse(anchor, 1.26, 0.45)
	DeepUi.burst(self, _center_of(anchor), tone, 18 + int(round(boost * 6.0)), 200.0, 0.65)
	DeepAudio.from(anchor, "gleam", {"volume": 0.6, "pitch": 1.1})

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
	## Blows close up as they pile on, so a gem that lands twenty times over still plays inside
	## the step the rules reserved for it. `DeepBattle` owns the beat; this only follows it.
	var pace: float = DeepBattle.hit_pace(effects)
	for effect in effects:
		var kind: String = str(effect.get("kind", ""))
		var target_id: String = str(effect.get("target", ""))
		if effect.has("drunk_by"):
			## A Kaleidoscope drinking this gem's colour: what the gem gives goes to it instead.
			var drinker: CrystalCreature = _creature(str(effect.drunk_by))
			if drinker != null:
				var gift: String = "+%d %s" % [int(effect.get("amount", 0)), kind.replace("_", " ")]
				_later_do(at, func() -> void:
					if is_instance_valid(drinker):
						_fx.projectile(origin, drinker.centre(), color, 0.25, 0.1, Callable(), 0.8)
						_float_world(drinker.centre() + Vector3(0, 0.8, 0), "Drinks it · " + gift, color, 16))
				at += 0.2
			continue
		match kind:
			"damage":
				var hits: Array = [effect] + effect.get("splash", [])
				## A blow that lands several times over throws one bolt for each, in quick
				## succession, rather than one fat bolt carrying the whole number.
				var over: int = maxi(1, int(effect.get("repeat", 1)))
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
						var when: float = at + DeepBattle.BOLT_GAP * pace * float(again)
						_later_do(when , func() -> void:
							if is_instance_valid(creature):
								_fx.projectile(origin, creature.centre(), color, 0.2, fat, _impact.bind(who, landing, color, mine), 0.6 + randf() * 0.5))
					at += DeepBattle.BOLT_GAP * pace * float(over)
				at += DeepBattle.HIT_BREATH * pace
				if not effect.get("poison_spread", []).is_empty():
					_animate_effects(effect.poison_spread, origin, DeepUi.POISON, mine, anchor)
				if mine and effect.has("spent"):
					_float_at(_forecast_box, "−%d Pyrite%s" % [int(effect.spent), " / +%d refund" % int(effect.refund) if effect.has("refund") else ""], DeepUi.ORE, 16)
			"appraise":
				if mine:
					_float_at(_forecast_box, "%d appraised · %d Pyrite value" % [effect.get("appraised", []).size(), int(effect.get("value", 0))], DeepUi.ORE, 16)
				_animate_effects(effect.get("hits", []), origin, DeepUi.ORE, mine, anchor, magnitude)
			"gem_rank":
				if mine:
					for socket in effect.get("sockets", []):
						if int(socket) < _socket_cards.size():
							_float_at(_socket_cards[int(socket)], "+%d %s" % [int(effect.amount), str(effect.rank).capitalize()], Color.WHITE, 15)
			"void_copy":
				## An Echo's copies join the rail as it resolves, so the cards under them
				## may not have been rebuilt yet; whatever is there already is what floats.
				if mine:
					for socket in effect.get("sockets", []):
						if int(socket) < _socket_cards.size():
							_float_at(_socket_cards[int(socket)], "Void copy", DeepUi.ACCENT_HI, 15)
			"stake":
				if mine and effect.has("spent"):
					_float_at(_forecast_box, "−%d Pyrite · next gem +%d%%" % [int(effect.spent), int(effect.amount)], DeepUi.ORE, 16)
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
					_float_at(_forecast_box, "+%d pyrite" % int(effect.amount), DeepUi.ORE, 20)
			"poison", "stun", "curse", "remove_block", "dice_dread", "die_steal", "cleanse", "clouded", "marked", "dulled", "ward", "retain", "charged", "regeneration", "spikes", "lifeline", "max_hp", "max_hp_loss":
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
				elif target_id == local_id:
					_float_at(_effects, "Ward blocked" if bool(effect.get("warded", false)) else "%s +%d" % [kind.capitalize(), int(effect.amount)], color, 16)
				elif _ally_cards.has(target_id):
					_float_at(_ally_cards[target_id], "Ward blocked" if bool(effect.get("warded", false)) else "%s +%d" % [kind.capitalize(), int(effect.amount)], color, 15)
			"raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high", "upgrade_faces":
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
	if hit.has("lifeline"):
		_show_lifeline(who, int(hit.lifeline))
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
		## A beat of stillness as it lands, longer the harder it was: the blow is felt rather
		## than only seen. The kill itself holds the clock for longer; see `_kill`.
		if not bool(hit.get("killed", false)):
			ScreenFx.hold(0.03 + 0.05 * minf(ratio, 1.0))
	var text: String = "−%d" % amount
	var size: int = 24 + mini(28, amount)
	if hit.has("mirrored"):
		text = "Mirrored"
		size = 22
	var number: Label = _float_world(at + Vector3(0, 0.6, 0), text, color.lightened(0.35) if mine else DeepUi.PAPER, size)
	## A heavy blow's number lands with a jolt of its own.
	if number != null and (ratio >= 0.25 or bool(hit.get("killed", false))):
		DeepUi.shake(number, 9.0 + 9.0 * minf(ratio, 1.0), 0.32)
	if int(hit.get("absorbed", 0)) > 0:
		_float_world(at + Vector3(0.5, 0.2, 0), "%d blocked" % int(hit.absorbed), DeepUi.BLOCK, 14)
	if hit.has("drunk"):
		## A colour it is drinking: the blow sinks into it and does nothing.
		var hue := Color("#" + str(DeepContent.color(str(hit.drunk)).get("hue", "c8a8ff")))
		_float_world(at + Vector3(-0.5, 0.9, 0), "Drunk", hue, 16)
		_fx.glow_burst(at, hue, 1.6, 0.4)
	if bool(hit.get("guarded", false)):
		_float_world(at + Vector3(-0.5, 1.2, 0), "Gathering · half", Color("ffe27a"), 14)
	if hit.has("mirrored"):
		## The colour it mirrors throws the blow straight back at whoever threw it.
		_fx.beam(at, _camera.global_position + Vector3(0, -0.4, -1.0) if who != "" and str(hit.mirrored.get("target", "")) == local_id else at + Vector3(0, 2.0, 2.0), color, 0.35, 0.16)
		_enemy_effect(hit.mirrored, creature)
	if int(hit.get("capped", 0)) > 0:
		_float_world(at + Vector3(0.6, 1.0, 0), "Sturdy", Color("c8b8a0"), 16)
		_fx.shield(at + Vector3(0, -0.2, 0.4), Vector3.UP, Color("c8b8a0"), 1.0, 0.4)
	if bool(hit.get("shielded", false)):
		_float_world(at + Vector3(-0.6, 1.0, 0), "Shielded", Color("c8a8ff"), 14)
	if bool(hit.get("piercing", false)):
		_float_world(at + Vector3(0.4, 0.2, 0), "pierces", DeepUi.BAD, 13)
	for returned in hit.get("returned_gems", []):
		if str(returned.get("unit", "")) == local_id and int(returned.get("socket", -1)) < _socket_cards.size() and int(returned.get("socket", -1)) >= 0:
			_float_at(_socket_cards[int(returned.socket)], "Returned", DeepUi.ACCENT_HI, 15)
	if bool(hit.get("raw_drop", false)):
		_float_world(at + Vector3(0, 1.3, 0), "A stone!", DeepUi.ACCENT_HI, 18)
	_deathburst(hit, creature)
	for reflection in hit.get("reflections", []):
		_enemy_effect(reflection, creature)
		_screen_fx.wound(0.3)
	if hit.has("spikes"):
		_enemy_effect(hit.spikes, creature)
	if not str(hit.get("split", "")).is_empty():
		_float_world(at + Vector3(0, 1.0, 0), "It splits!", Color("9fd8c8"), 18)
	_thresholds(hit, creature)
	if bool(hit.get("killed", false)):
		_kill(creature)

func _thresholds(hit: Dictionary, creature: CrystalCreature) -> void:
	## What a creature does the moment its health falls far enough (the Hollow Crown calling
	## its magpies, the Spore Mother shedding everything), played as it falls.
	for crossed in hit.get("thresholds", []):
		var at: Vector3 = creature.centre() if creature != null and is_instance_valid(creature) else Vector3(0, 1.2, ARC_Z)
		_later_do(0.25, func() -> void:
			_fx.ring_wave(Vector3(at.x, 0.0, at.z), Color("ffb0a0"), 3.0, 0.6)
			_float_world(at + Vector3(0, 1.2, 0), str(crossed.get("move", "")) + "!", Color("ffb0a0"), 22)
			for effect in crossed.get("effects", []):
				_enemy_effect(effect, creature))

func _deathburst(hit: Dictionary, creature: CrystalCreature) -> void:
	## What a dying creature leaves behind: a Puffball's spores, a Spore Slime's burst,
	## played from where it stood a beat after the killing blow.
	for burst in hit.get("deathburst", []):
		var at: Vector3 = creature.centre() if creature != null and is_instance_valid(creature) else Vector3(0, 1.0, ARC_Z)
		_later_do(0.3, func() -> void:
			_fx.ring_wave(Vector3(at.x, 0.0, at.z), DeepUi.POISON, 3.5, 0.6)
			_fx.puff(at, DeepUi.POISON, 40, 1.4, 1.6, 0.9, true)
			_fx.glow_burst(at, DeepUi.POISON, 2.4, 0.4)
			_float_world(at + Vector3(0, 1.0, 0), str(burst.get("move", "Burst")) + "!", DeepUi.POISON, 22)
			for effect in burst.get("effects", []):
				_enemy_effect(effect, creature))

func _afflict(who: String, effect: Dictionary, tone: Color) -> void:
	var creature: CrystalCreature = _creature(who)
	if creature == null or not is_instance_valid(creature):
		return
	var kind: String = str(effect.get("kind", ""))
	var at: Vector3 = creature.centre()
	if bool(effect.get("warded", false)) or bool(effect.get("immune", false)) or bool(effect.get("resisted", false)):
		_fx.shield(at, Vector3.FORWARD, DeepUi.INFO, 0.8, 0.4)
		_float_world(at, "Ward blocked" if bool(effect.get("warded", false)) else "Immune", DeepUi.INFO, 18)
		return
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

func _dress(creature: CrystalCreature, foe: Dictionary) -> void:
	## What the rules say the creature is doing right now, worn on the model: under the floor,
	## turning a colour away, winding up a blow.
	if creature == null or not is_instance_valid(creature):
		return
	creature.burrow(bool(foe.get("burrowed", false)))
	## A halo for what guards it: the colour it drinks, a refraction, a mirror held up.
	var drinking: Array = foe.get("absorb", [])
	if not drinking.is_empty():
		creature.set_halo(Color("#" + str(DeepContent.color(str(drinking[0])).get("hue", "c8a8ff"))))
	elif int(foe.get("reflect", 0)) > 0 or int(foe.get("mirror", 0)) > 0:
		creature.set_halo(Color("e8e0ff"))
	else:
		creature.clear_halo()
	creature.set_charging(DeepCreatures.charge_turns(foe) > 0)

func _flee(creature: CrystalCreature, stolen: int = 0) -> void:
	## Off into the dark with what it took: no shards, no spoils, only a shower of the
	## pyrite it is carrying away.
	if creature == null or not is_instance_valid(creature) or bool(creature.get_meta("killed", false)):
		return
	creature.set_meta("killed", true)
	creature.set_meta("dying", true)
	if _headless:
		creature.queue_free()
		return
	var at: Vector3 = creature.centre()
	DeepAudio.play_at(global_position + _to_screen(at), "ui_deny", {"gap": 0.0, "volume": 0.6})
	_fx.puff(at, creature.tint, 14, 0.9, 1.2, 0.8)
	_fx.sparks(at, DeepUi.ORE, 20 + mini(30, stolen), 3.0, 0.8, 0.06)
	_float_world(at + Vector3(0, 0.8, 0), "Flees" + (" with %d pyrite" % stolen if stolen > 0 else ""), DeepUi.ORE, 20)
	creature.flee()

func _kill(creature: CrystalCreature) -> void:
	if creature == null or not is_instance_valid(creature) or bool(creature.get_meta("killed", false)):
		return
	creature.set_meta("killed", true)
	creature.set_meta("dying", true)
	if _headless:
		creature.queue_free()
		return
	var at: Vector3 = creature.centre()
	## The blow that ends the fight plays in slow motion; any other kill holds the clock for a
	## beat. Nobody who asked for fewer flashes is made to sit through the slow motion.
	var last: bool = true
	for id in _creatures:
		var other: CrystalCreature = _creature(str(id))
		if other != null and other != creature and not bool(other.get_meta("killed", false)) and not bool(other.get_meta("dying", false)):
			last = false
	if last and not ScreenFx.calm:
		ScreenFx.hold(0.07, 0.04)
		ScreenFx.hold(0.75 if creature.warden else 0.5, 0.3)
		_camera.punch(-7.0 if creature.warden else -5.0, 0.9)
	else:
		ScreenFx.hold(0.08 if not creature.warden else 0.14, 0.05)
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

func _show_lifeline(who: String, hp: int) -> void:
	var text: String = "Lifeline · %d HP" % hp
	if who == local_id:
		_screen_fx.blink(DeepUi.GOOD, 0.25)
		_float_at(_hp_bar, text, DeepUi.GOOD, 24)
	elif _ally_cards.has(who):
		_float_at(_ally_cards[who], text, DeepUi.GOOD, 18)
	elif _creature(who) != null:
		_float_world(_creature(who).centre(), text, DeepUi.GOOD, 18)

func _enemy_effect(effect: Dictionary, creature: CrystalCreature) -> void:
	var kind: String = str(effect.get("kind", ""))
	var target_id: String = str(effect.get("target", ""))
	var source: Vector3 = creature.centre() if creature != null and is_instance_valid(creature) else Vector3(0, 1.2, ARC_Z)
	if bool(effect.get("warded", false)) or bool(effect.get("resisted", false)) or bool(effect.get("immune", false)):
		var label: String = "Ward blocked" if bool(effect.get("warded", false)) else "Immune"
		if target_id == local_id:
			_float_at(_hp_bar, label, DeepUi.INFO, 18)
		elif _ally_cards.has(target_id):
			_float_at(_ally_cards[target_id], label, DeepUi.INFO, 16)
		return
	if effect.has("lifeline"):
		_show_lifeline(target_id, int(effect.lifeline))
	if effect.has("spikes"):
		var retaliation: Dictionary = effect.spikes
		_impact(str(retaliation.target), retaliation, DeepUi.INFO, true)
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
		"ward", "retain", "charged", "regeneration", "spikes", "lifeline", "max_hp", "max_hp_loss":
			var receiver: CrystalCreature = _creature(target_id)
			if receiver != null:
				_afflict(target_id, effect, DeepUi.GOOD)
		"poison", "stun", "die_steal", "remove_block", "curse", "clouded", "marked", "dulled", "festering", "scorched", "burn", "dice_dread":
			if target_id == local_id:
				DeepAudio.play({"poison": "poison", "stun": "stun", "curse": "curse", "remove_block": "block_break", "festering": "poison", "scorched": "block_break", "burn": "block_break"}.get(kind, "ui_deny"), {"volume": 0.7})
				var tone: Color = {"poison": DeepUi.POISON, "stun": Color("ffe27a"), "remove_block": DeepUi.BLOCK, "curse": Color("c58bff"), "festering": DeepUi.POISON, "scorched": Color("ff8a3a"), "burn": Color("ff7a2a")}.get(kind, DeepUi.INFO)
				_screen_fx.blink(tone, 0.12)
				var said: String = kind.replace("_", " ").capitalize() + (" %d" % int(effect.get("amount", 0)) if int(effect.get("amount", 0)) > 0 and not kind in ["stun"] else "")
				if kind == "remove_block":
					said = "−%d block" % int(effect.get("removed", 0))
				elif kind == "dice_dread":
					said = "Dread · smaller dice next turn"
				_float_at(_hp_bar, said, tone, 18)
				if kind == "die_steal" and not _dice_views.is_empty():
					var view: Control = _dice_views.values().back()
					DeepUi.shake(view, 12.0, 0.4)
					DeepUi.burst(self, _center_of(view), DeepUi.BAD, 12, 120.0, 0.5)
				if kind == "stun":
					DeepUi.shake(_dock, 4.0, 0.4)
			elif target_id != "" and _creature(target_id) != null and kind == "stun":
				## A creature that stunned itself (a Croupier Crab on a 1).
				_afflict(target_id, effect, Color("ffe27a"))
		"die_lock":
			if target_id == local_id:
				DeepAudio.play("ui_deny", {"volume": 0.7})
				for id in effect.get("dice", []):
					if _dice_views.has(str(id)):
						var view: Control = _dice_views[str(id)]
						DeepUi.shake(view, 10.0, 0.4)
						DeepUi.burst(self, _center_of(view), DeepUi.INFO, 10, 100.0, 0.5)
						_float_at(view, "Locked", DeepUi.INFO, 15)
		"steal_gold", "gold":
			if target_id == local_id:
				var amount: int = int(effect.get("stolen", effect.get("amount", 0)))
				if amount <= 0:
					return
				DeepAudio.play("ore", {"volume": 0.6})
				if kind == "steal_gold" and creature != null and is_instance_valid(creature):
					_fx.coins(_camera.global_position + (-_camera.global_transform.basis.z) * 1.2 + Vector3(0, -0.4, 0), creature.centre(), mini(10, 3 + amount / 5))
					_float_at(_forecast_box, "−%d pyrite taken" % amount, DeepUi.ORE, 16)
				else:
					_float_at(_forecast_box, "+%d pyrite" % amount, DeepUi.ORE, 16)
			elif _ally_cards.has(target_id) and int(effect.get("stolen", effect.get("amount", 0))) > 0:
				_float_at(_ally_cards[target_id], ("−%d" if kind == "steal_gold" else "+%d") % int(effect.get("stolen", effect.get("amount", 0))), DeepUi.ORE, 14)
			## The Assayer's tax: the pyrite it took, then a blow for as much.
			if effect.has("hurt"):
				_enemy_effect(effect.hurt, creature)
		"hold_gem":
			var held: Dictionary = effect.get("held", {})
			if not held.is_empty() and str(held.get("unit", "")) == local_id:
				var socket: int = int(held.get("socket", -1))
				if socket >= 0 and socket < _socket_cards.size():
					var card: Control = _socket_cards[socket]
					DeepAudio.from(card, "gem_fizzle", {"volume": 0.8})
					DeepUi.shake(card, 12.0, 0.4)
					_float_at(card, "Taken!", DeepUi.BAD, 18)
					if creature != null and is_instance_valid(creature):
						_fx.projectile(_origin_for(local_id, socket), creature.centre(), DeepUi.ACCENT, 0.5, 0.18, Callable(), 1.2)
			elif bool(effect.get("nothing", false)) and creature != null and is_instance_valid(creature):
				_float_world(creature.centre(), str(effect.get("reason", "Nothing to take")), DeepUi.DIM, 14)
		"bury_socket":
			if target_id == local_id and effect.has("socket") and int(effect.socket) < _socket_cards.size():
				var card: Control = _socket_cards[int(effect.socket)]
				DeepAudio.from(card, "rock_break", {"volume": 0.7})
				DeepUi.shake(card, 8.0, 0.4)
				_float_at(card, "Buried", Color("c8b8a0"), 16)
		"summon":
			if creature != null and is_instance_valid(creature):
				if effect.get("summoned", []).is_empty():
					_float_world(creature.centre() + Vector3(0, 0.6, 0), str(effect.get("reason", "No room")), DeepUi.DIM, 14)
				else:
					DeepAudio.play_at(global_position + _to_screen(creature.centre()), "rock_break", {"volume": 0.7})
					_fx.ring_wave(Vector3(creature.global_position.x, 0.0, creature.global_position.z), creature.tint, 3.0, 0.6)
					_float_world(creature.centre() + Vector3(0, 0.6, 0), "Calls for help", creature.tint.lightened(0.3), 18)
		"burrow":
			if creature != null and is_instance_valid(creature):
				_float_world(creature.global_position + Vector3(0, creature.anchor.y, 0), "Digs in", Color("c8b8a0"), 16)
		"absorb_color", "reflect", "mirror":
			if creature != null and is_instance_valid(creature):
				if bool(effect.get("nothing", false)):
					_float_world(creature.centre(), str(effect.get("reason", "")), DeepUi.DIM, 13)
				else:
					var hue := Color("e8e0ff")
					var said: String = "Refracts" if kind == "reflect" else "Holds up a mirror"
					if kind == "absorb_color":
						hue = Color("#" + str(DeepContent.color(str(effect.get("color", ""))).get("hue", "c8a8ff")))
						said = "Drinks %s" % str(DeepContent.color(str(effect.get("color", ""))).get("name", str(effect.get("color", "")).capitalize()))
					_fx.ring_wave(Vector3(creature.global_position.x, 0.0, creature.global_position.z), hue, 2.4, 0.6)
					_fx.glow_burst(creature.centre(), hue, 2.0, 0.4)
					creature.set_halo(hue)
					_float_world(creature.centre() + Vector3(0, 0.6, 0), said, hue, 18)
		"strength":
			## Stronger for the fight: every creature it reached flares.
			var lifted: CrystalCreature = _creature(target_id)
			if lifted != null:
				lifted.flash(2.0)
				_fx.rise(lifted.centre(), DeepUi.BAD, 18, 0.6)
				_float_world(lifted.centre() + Vector3(0, 0.6, 0), "+%d Strength" % int(effect.get("amount", 0)), DeepUi.BAD, 16)
		"roll_again":
			if creature != null and is_instance_valid(creature) and not bool(effect.get("nothing", false)):
				_fx.sparks(creature.centre(), DeepUi.ACCENT, 20, 3.0, 0.5, 0.06)
				_float_world(creature.centre() + Vector3(0, 0.9, 0), "Again!", DeepUi.ACCENT, 18)
		"end_action":
			if creature != null and is_instance_valid(creature):
				_fx.stars(creature.global_position + Vector3(0, creature.anchor.y * 0.85, 0))
				_float_world(creature.centre() + Vector3(0, 0.6, 0), "Stumbles", Color("ffe27a"), 18)
		"purge":
			if creature != null and is_instance_valid(creature) and int(effect.get("purged", 0)) > 0:
				_fx.puff(creature.centre(), DeepUi.POISON, 20, 0.8, 1.2, 0.9, true)
				_float_world(creature.centre() + Vector3(0, 0.6, 0), "Sheds %d poison" % int(effect.purged), DeepUi.POISON, 16)
		"empower_next":
			if creature != null and is_instance_valid(creature):
				_fx.rise(creature.centre(), DeepUi.BAD, 24, 0.7)
				creature.flash(2.5)
				_float_world(creature.centre() + Vector3(0, 0.6, 0), "Empowered +%d%%" % int(effect.get("amount", 0)), DeepUi.BAD, 18)
		"rally":
			for id in effect.get("rallied", []):
				var ally: CrystalCreature = _creature(str(id))
				if ally != null:
					ally.flash(1.6)
					_fx.rise(ally.centre(), DeepUi.BAD, 12, 0.5)
					_float_world(ally.centre() + Vector3(0, 0.6, 0), "+%d" % int(effect.get("amount", 0)), DeepUi.BAD, 15)
		"grow_die":
			if creature != null and is_instance_valid(creature):
				_fx.sparks(creature.centre(), creature.tint, 24, 3.0, 0.6, 0.06)
				_float_world(creature.centre() + Vector3(0, 0.6, 0), "Another head" if not bool(effect.get("nothing", false)) else "No more heads", creature.tint.lightened(0.3), 18)
		"swell":
			if creature != null and is_instance_valid(creature):
				creature.hit(0.2)
				_fx.puff(creature.centre(), DeepUi.POISON, 8, 0.5, 0.9, 0.5, true)
				_float_world(creature.centre() + Vector3(0, 0.6, 0), "Swells · %d" % int(effect.get("swell_after", 0)), DeepUi.POISON, 15)
		"charge":
			if creature != null and is_instance_valid(creature):
				if not bool(effect.get("nothing", false)):
					creature.set_charging(true)
					_fx.rise(creature.centre(), Color("ffe27a"), 36, 1.0)
					_float_world(creature.centre() + Vector3(0, 0.6, 0), "Gathers light · %d" % int(effect.get("turns", 0)), Color("ffe27a"), 18)
		"downgrade_die", "grind_die", "break_gem", "lock_die", "mar_die", "break_die", "blank_face":
			if target_id == local_id:
				DeepAudio.play("block_break", {"volume": 0.7})
				_screen_fx.blink(DeepUi.BAD, 0.1)
				var said: String = {"downgrade_die": "A die shrinks", "grind_die": "A face ground down", "break_gem": "A gem melts!", "lock_die": "A die locked", "mar_die": "A face marred",
					"break_die": "A die breaks!", "blank_face": "A face burns blank"}.get(kind, kind)
				if kind == "downgrade_die" and effect.get("dice", []).size() > 1:
					said = "Every die shrinks"
				elif kind == "grind_die" and effect.get("dice", []).size() > 1:
					said = "Every face showing loses a point, for good"
				elif kind == "grind_die" and bool(effect.get("permanent", false)):
					said = "A face cut down, for good"
				elif kind in ["break_gem", "break_die"] and bool(effect.get("permanent", false)):
					said = ("A gem" if kind == "break_gem" else "A die") + " is gone for the fight!"
				_float_at(_tray_box if kind != "break_gem" else _hp_bar, said, DeepUi.BAD, 18)
				for die in effect.get("dice", []):
					if _dice_views.has(str(die.get("id", ""))):
						DeepUi.shake(_dice_views[str(die.id)], 12.0, 0.5)
				for socket in effect.get("sockets", []):
					if int(socket) < _socket_cards.size():
						DeepUi.shake(_socket_cards[int(socket)], 12.0, 0.5)
						DeepUi.burst(self, _center_of(_socket_cards[int(socket)]), DeepUi.BAD, 16, 140.0, 0.6)

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

func _float_world(point: Vector3, text: String, color: Color, size: int = 20) -> Label:
	if _headless or _camera == null or _camera.is_position_behind(point):
		return null
	return DeepUi.float_text(self, _to_screen(point), text, color, size, 70.0, 1.1)

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
