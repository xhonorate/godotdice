extends Control
## The fight, seen from the party's own eyes.
##
## The chamber is one World3D, built for the mine and the depth: a biome of low-poly rock,
## props, fog, lights and drifting particles. Creatures stand in an arc facing the camera;
## the plate above each is a 2D control pinned to a 3D anchor. The player's rail, dice and
## forecast sit in a dock at the bottom; allies are compact cards at the side.
##
## Every event is played as something physical: a gem that fires throws a bolt of its own
## colour from its socket to what it hits; a blow lands with sparks, light, a shockwave, a
## camera kick and a number; a creature rears before it strikes and the view flinches when
## it lands. Nothing here decides anything: the screen shows the state it is given, animates
## the events it is handed, and turns every click into a command.

const DiceView = preload("res://view/dice/dice_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const Chamber = preload("res://view/battle/chamber.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")
const CameraRig = preload("res://view/battle/camera_rig.gd")
const LensFlare = preload("res://view/battle/lens_flare.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
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

var _headless: bool = false
var _frame: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _chamber: Node3D
var _fx: Node3D
var _env: Environment
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
var _reroll_button: Button
var _lock_button: Button
var _hint: Label
var _hp_bar: DeepUi.Bar
var _hp_text: Label
var _status_row: HBoxContainer
var _effects: EffectChips.Row
var _fight_effects: EffectChips.Row
var _effects_box: VBoxContainer
var _forecast_box: VBoxContainer
var _ally_box: VBoxContainer
var _ally_cards: Dictionary = {}
var _lock_pulse: Tween = null

var _quality: int = 3
## The graphics setting: 0 lets the governor decide, 1-3 fixes low, medium or high.
static var quality_pref: int = 0
var _warmed: bool = false
var _shows: int = 0
var _slow: float = 0.0
var _ambient_clock: float = 0.0
var _next_rumble: float = 7.0

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stage()
	_build_hud()
	visibility_changed.connect(_on_visibility)

func _on_visibility() -> void:
	## A hidden fight costs nothing: its world stops rendering and stops moving.
	if _viewport == null:
		return
	var shown := is_visible_in_tree()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	_world.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED

# --- the chamber ---------------------------------------------------------------------------

func _build_stage() -> void:
	if _headless:
		var dark := ColorRect.new()
		dark.color = DeepUi.INK
		dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dark)
		return
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.positional_shadow_atlas_size = 2048
	_frame.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_camera = CameraRig.new()
	_viewport.add_child(_camera)
	_fx = BattleFx.new()
	_world.add_child(_fx)

func warm_up() -> void:
	## The first fight used to stall for half a second while the GPU compiled everything a
	## room uses: rock, fog, glow, every kind of spark. This builds a throwaway room with one
	## of each effect, lets the hidden viewport draw it a few times, and throws it away, so
	## the cost is paid when a run starts rather than when the first creature rises.
	if _headless or _warmed or _viewport == null:
		return
	_warmed = true
	var room := Chamber.new()
	room.quality = _quality
	_world.add_child(room)
	room.build(Biomes.for_depth(DeepContent.starter_mine(), 1, "warden"), 7)
	var previous_env: Environment = _camera.environment
	_camera.environment = room.environment()
	var creature: CrystalCreature = CrystalCreature.make("CAVE_TICK", true)
	creature.position = Vector3(0, 0, ARC_Z)
	_world.add_child(creature)
	var at := Vector3(0, 1.2, ARC_Z)
	_fx.sparks(at, DeepUi.ACCENT, 8)
	_fx.glow_burst(at, DeepUi.ACCENT)
	_fx.puff(at, DeepUi.POISON, 4)
	_fx.rise(at, DeepUi.GOOD, 4)
	_fx.ring_wave(at, DeepUi.ACCENT)
	_fx.flash(at, DeepUi.ACCENT)
	_fx.shards(at, DeepUi.ACCENT, 3)
	_fx.projectile(Vector3(0, 1.5, 2.0), at, DeepUi.ACCENT, 0.1)
	_fx.shield(at, Vector3(0, 0, 1), DeepUi.BLOCK)
	_fx.coins(at, Vector3(0, 1, 2), 2)
	_fx.stars(at)
	_fx.sigil(at, DeepUi.INFO)
	_fx.dust_fall(4)
	var was: SubViewport.UpdateMode = _viewport.render_target_update_mode
	var processing: Node.ProcessMode = _world.process_mode
	## A hidden container does not size its viewport, and buffers allocated at the wrong size
	## would only be thrown away and made again when the fight is shown.
	var span: Vector2 = size if size.x > 64.0 else get_viewport_rect().size
	_viewport.size = Vector2i(maxi(64, int(span.x)), maxi(64, int(span.y)))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	## Drawn behind the page for a moment: a viewport nobody draws is never rendered, so the
	## fight is shown, fully transparent, under everything else.
	var hidden: bool = not visible
	var shade: float = modulate.a
	var shows: int = _shows
	if hidden:
		modulate.a = 0.0
		visible = true
	for _i in range(4):
		await get_tree().process_frame
	if hidden:
		modulate.a = shade
		## A fight that began while the room was warming stays on screen.
		if _shows == shows:
			visible = false
	room.queue_free()
	creature.queue_free()
	for child in _fx.get_children():
		child.queue_free()
	_fx.flares.clear()
	if not is_visible_in_tree():
		_camera.environment = previous_env
		_viewport.render_target_update_mode = was
		_world.process_mode = processing

func _rebuild_chamber() -> void:
	if _headless:
		return
	var mine: String = str(context.get("mine", DeepContent.starter_mine()))
	var kind: String = str(context.get("kind", "warden" if bool(state.get("warden", false)) else ("elite" if bool(state.get("elite", false)) else "fight")))
	var key: String = "%s|%d|%s" % [mine, depth, kind]
	if key == _stage_key:
		return
	_stage_key = key
	if _chamber != null and is_instance_valid(_chamber):
		_chamber.queue_free()
	var biome: Dictionary = Biomes.for_depth(mine, depth, kind)
	_chamber = Chamber.new()
	_chamber.quality = _quality
	_world.add_child(_chamber)
	_chamber.build(biome, ("%s|%d" % [mine, depth]).hash())
	_env = _chamber.environment()
	_camera.environment = _env
	_camera.calm(1.7 if bool(biome.warden) else 1.0)
	_camera.reset()
	_camera.intro(1.5, bool(biome.warden))
	_screen_fx.vignette = 0.42 + 0.12 * float(biome.intensity)
	_screen_fx.vignette_colour = Color(biome.background).darkened(0.5)
	_screen_fx.desaturate = 0.0
	_flare.sources = _chamber.flares
	_depth_label.text = str(biome.name)
	_biome_label.text = "Depth %d%s" % [depth, "  ·  Warden's gate" if bool(biome.warden) else ("  ·  Elite" if bool(biome.elite) else "")]
	_intro_pending = true
	_next_rumble = 5.0

func _creature(id: String) -> CrystalCreature:
	## A creature still standing in the room, or null. Checked before it is typed, because a
	## freed one cannot even be assigned to a typed variable.
	var node: Variant = _creatures.get(id, null)
	if node == null or not is_instance_valid(node):
		return null
	return node as CrystalCreature

func _place_creatures() -> void:
	var enemies: Array = state.get("enemies", [])
	var living: Array = enemies.filter(func(e: Dictionary) -> bool: return int(e.hp) > 0)
	var present: Dictionary = {}
	var fresh: int = 0
	for foe in enemies:
		var id: String = str(foe.id)
		present[id] = true
		if int(foe.hp) <= 0:
			if _creatures.has(id) and is_instance_valid(_creatures[id]) and not bool(_creatures[id].get_meta("dying", false)):
				_kill(_creatures[id])
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
			creature.spawn(0.25 + 0.18 * float(fresh) if _intro_pending else 0.0)
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
		_camera.home_fov = clampf(BASE_FOV + maxf(0.0, tallest - 2.8) * 4.8, BASE_FOV, 80.0)
		_camera.home_look.y = 1.2 + (_camera.home_fov - BASE_FOV) * 0.05
	_intro_pending = false
	for id in _creatures.keys():
		if not present.has(id) and is_instance_valid(_creatures[id]):
			_creatures[id].queue_free()
			_creatures.erase(id)

# --- the HUD -------------------------------------------------------------------------------

func _build_hud() -> void:
	if not _headless:
		_screen_fx = ScreenFx.new()
		add_child(_screen_fx)
		_flare = LensFlare.new()
		_flare.camera = _camera
		_flare.viewport = _viewport
		_flare.transient = _fx.flares
		add_child(_flare)
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
	var me_row := DeepUi.hbox(left, 8)
	DeepUi.icon(me_row, "heart", 22, DeepUi.HP, "Your health")
	_hp_bar = DeepUi.bar(me_row, 18.0)
	_hp_bar.custom_minimum_size = Vector2(230, 18)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hp_text = DeepUi.label(me_row, "", 15, DeepUi.PAPER)
	_hp_text.add_theme_font_override("font", DeepUi.display_font())
	_status_row = DeepUi.hbox(me_row, 4)
	var rail_head := DeepUi.hbox(left, 8)
	DeepUi.icon(rail_head, "gem", 16, DeepUi.ACCENT)
	DeepUi.heading(rail_head, "Rail", 13)
	DeepUi.spacer(rail_head)
	_resonance_box = DeepUi.hbox(rail_head, 5)
	_resonance_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_resonance_box.tooltip_text = "Resonance: each gem that fires adds one, a neighbour of the same colour adds two, a fizzle resets it. The Capstone turns it into carats."
	DeepUi.icon(_resonance_box, "spark", 18, DeepUi.ACCENT)
	_resonance_value = DeepUi.title(_resonance_box, "0", 20, DeepUi.ACCENT)
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
	forecast = new_forecast
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
	for id in _plates.keys():
		if is_instance_valid(_plates[id]):
			_plates[id].queue_free()
	_plates.clear()
	for id in _creatures.keys():
		if is_instance_valid(_creatures[id]):
			_creatures[id].queue_free()
	_creatures.clear()
	_intro_pending = true
	DeepAudio.play("battle_begin", {"volume": 0.9})
	if _screen_fx != null:
		_screen_fx.desaturate = 0.0
	if _camera != null:
		_camera.reset()
		_camera.intro(1.2, bool(state.get("warden", false)))

func me() -> Dictionary:
	return DeepBattle.player(state, local_id)

func _sync() -> void:
	if state.is_empty():
		return
	var unit: Dictionary = me()
	var planning: bool = str(state.get("phase", "")) == "planning"
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
		_hp_text.text = "%d / %d" % [int(unit.hp), int(unit.max_hp)]
		_hp_bar.set_values(ratio, "", float(unit.block) / float(maxi(1, int(unit.max_hp))))
		if _screen_fx != null:
			_screen_fx.danger = clampf((0.3 - ratio) / 0.3, 0.0, 1.0) if not bool(unit.get("downed", false)) else 0.0
		DeepUi.clear(_status_row)
		if int(unit.block) > 0:
			DeepUi.pill(_status_row, "shield", str(int(unit.block)), DeepUi.BLOCK, 14, "Block: soaks damage before your health. It lasts the whole fight.")
		var effects: Array = EffectChips.for_player(unit, state).filter(func(e: Dictionary) -> bool: return str(e.key) != "block")
		var passive: Dictionary = unit.get("passive", {})
		if not str(passive.get("text", "")).is_empty():
			effects.append(EffectChips.entry("passive", "gem", "", true, str(DeepContent.setting(str(unit.get("setting", ""))).get("name", "Your setting")), str(passive.text), DeepUi.ACCENT))
		_effects.show_effects(effects)
		_resonance_value.text = str(int(unit.get("resonance", 0))) if not planning else str(int(forecast.get("totals", {}).get("resonance", 0)))
		_resonance_value.add_theme_color_override("font_color", _resonance_colour(int(_resonance_value.text)))
	_fight_effects.show_effects(EffectChips.for_battle(state))
	_sync_rail(unit, planning)
	_sync_tray(unit, planning)
	_sync_forecast()
	_sync_allies()
	_sync_plates()
	var locked: bool = bool(unit.get("locked", false))
	var downed: bool = bool(unit.get("downed", false))
	var rerolls: int = int(unit.get("rerolls", 0))
	_reroll_button.disabled = not planning or locked or downed or rerolls <= 0 or selected.is_empty()
	_reroll_button.text = ("Reroll  %d left" % rerolls) if planning else "Resolving"
	_lock_button.disabled = not planning or downed
	_lock_button.text = "Unlock" if locked else "Lock in"
	## When there is nothing left to decide, the lock button asks to be pressed.
	var waiting_on_me: bool = planning and not locked and not downed and (rerolls <= 0 or selected.is_empty())
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
		_hint.text = "Click dice to reroll  [1-5]" if selected.is_empty() else "%d selected" % selected.size()

func _status_glyph(status: String) -> String:
	match status:
		"poison": return "drop"
		"stun": return "stun"
		"curse": return "eye"
		"resolve": return "shield"
	return "spark"

func _status_colour(status: String) -> Color:
	match status:
		"poison": return DeepUi.POISON
		"stun": return Color("ffe27a")
		"curse": return Color("c58bff")
	return DeepUi.INFO

func _resonance_colour(value: int) -> Color:
	if value <= 0:
		return DeepUi.DIM
	return DeepUi.ACCENT.lerp(Color("ff6a3a"), clampf(float(value - 1) / 6.0, 0.0, 1.0))

func _sync_rail(unit: Dictionary, planning: bool) -> void:
	var rail: Array = unit.get("rail", [])
	if _socket_cards.size() != rail.size():
		DeepUi.clear(_rail_box)
		_socket_cards.clear()
		for socket in range(rail.size()):
			var card := VBoxContainer.new()
			card.add_theme_constant_override("separation", 2)
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
			slot.name = "Slot"
			slot.custom_minimum_size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
			slot.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_child(slot)
			var ring := SocketRing.new(socket_colour, stone == null)
			ring.name = "Ring"
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(ring)
			if stone is Dictionary:
				var picture := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 12)
				picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
				picture.tooltip_text = DeepStone.name(stone) + "\n" + str(DeepStone.skill_of(stone).get("text", ""))
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
				DeepUi.label(card, "Capstone" if socket_colour == "CAPSTONE" else (socket_colour.capitalize() if socket_colour != "ANY" else "Any"), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if stone is Dictionary:
			var entry: Dictionary = {}
			for candidate in forecast.get("sockets", []):
				if int(candidate.get("socket", -1)) == socket:
					entry = candidate
			var trigger_row: Node = card.get_node_or_null("Trigger")
			var ring: SocketRing = card.get_node_or_null("Slot/Ring")
			var active: bool = bool(entry.get("active", false))
			if ring != null:
				ring.set_ready(active and planning)
			if trigger_row != null:
				var described: Dictionary = entry.get("trigger", DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(stone.get("cut", 0))))
				var tone: Color = DeepUi.GOOD if active and planning else (DeepUi.PAPER if entry.is_empty() else DeepUi.DIM)
				var key: String = "%s|%s|%s" % [str(described.get("mark", "")), str(described.get("label", "")), str(tone)]
				if str(trigger_row.get_meta("key", "")) != key:
					trigger_row.set_meta("key", key)
					DeepUi.clear(trigger_row)
					DiceIcons.build(trigger_row, described, 15, tone, str(described.get("words", "")) + ("" if active or entry.is_empty() else "\n" + str(entry.get("reason", ""))))
			var blocked: bool = unit.get("buried", []).has(socket) or unit.get("clouded", []).has(socket)
			card.modulate = Color(0.55, 0.55, 0.6, 0.6) if blocked else Color.WHITE
			card.tooltip_text = ("Buried in rubble: this gem cannot fire this turn." if unit.get("buried", []).has(socket) else "Clouded: hit the Clouder to clear it.") if blocked else ""

class SocketRing extends Control:
	## A setting's socket: a bezel in the socket's colour, a crown for the Capstone, and a
	## glow that wakes when the hand in the tray would fire the stone set in it.
	var colour: String = "ANY"
	var empty: bool = false
	var _ready_glow: float = 0.0
	var _goal: float = 0.0
	var _clock: float = 0.0
	var _flash: float = 0.0
	func _init(socket_colour: String, is_empty: bool) -> void:
		colour = socket_colour
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
		var tone: Color = DeepUi.ACCENT if colour == "CAPSTONE" else (DeepUi.colour(colour) if colour != "ANY" else DeepUi.MUTED)
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.47
		if _ready_glow > 0.01 or _flash > 0.0:
			var pulse: float = 0.75 + 0.25 * sin(_clock * 5.0)
			var reach: float = radius * (2.4 + _flash * 1.2)
			draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(tone.lerp(Color.WHITE, _flash * 0.5), 0.35 * _ready_glow * pulse + 0.8 * _flash))
		draw_circle(centre, radius, Color(0, 0, 0, 0.45))
		draw_circle(centre, radius * 0.9, Color(tone, 0.08 if empty else 0.12))
		draw_arc(centre, radius, 0, TAU, 48, Color(tone, 0.95 if empty else 0.75), 3.0 if colour == "CAPSTONE" else 2.0, true)
		draw_arc(centre, radius * 0.82, 0, TAU, 40, Color(tone, 0.25), 1.0, true)
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0 + PI * 0.25
			draw_circle(centre + Vector2.from_angle(angle) * radius * 0.92, 2.2, Color(tone.lightened(0.3), 0.9))
		if colour == "CAPSTONE":
			var crown := PackedVector2Array([centre + Vector2(-9, -radius - 1), centre + Vector2(-5, -radius - 8), centre + Vector2(0, -radius - 3),
				centre + Vector2(5, -radius - 8), centre + Vector2(9, -radius - 1)])
			draw_colored_polygon(crown, DeepUi.ACCENT)

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
			holder.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE + 22)
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
		var words: String = DiceIcons.face_text(int(roll.value), str(roll.get("kind", "plain")))
		if bool(roll.get("locked", false)):
			words += "  ⌂"
		value.text = words
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
	DeepUi.stat(summary, "spark", str(int(totals.get("resonance", 0))), _resonance_colour(int(totals.get("resonance", 0))), 13, "Resonance this hand would build")

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
		_name.text = str(unit.name)
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
	## its buffs and troubles, the dice it rolled and what it means to do with them.
	## Right-click it, or one of its intents, for everything about it.
	signal inspect(move: String)
	var fading: bool = false
	var _name: Label
	var _target: TextureRect
	var _bar: DeepUi.Bar
	var _effects: EffectChips.Row
	var _dice: HBoxContainer
	var _intents: VBoxContainer
	var _intent_key: String = ""
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
		_intents = DeepUi.vbox(box, 3)
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
		var intent_key: String = str(foe.get("intents", [])) + str(foe.get("hand", []).map(func(r: Dictionary) -> int: return int(r.value)))
		if intent_key == _intent_key:
			return
		_intent_key = intent_key
		DeepUi.clear(_dice)
		for roll in foe.get("hand", []):
			_dice.add_child(DiceIcons.face(19, int(roll.value), DiceIcons.palette(str(roll.get("key", "D6"))).body, str(roll.get("shape", "D6")), true))
		DeepUi.clear(_intents)
		for intent in foe.get("intents", []):
			var line := DeepUi.hbox(_intents, 6)
			line.mouse_filter = Control.MOUSE_FILTER_STOP
			line.tooltip_text = "%s. Right-click to see all its moves." % str(intent.move)
			var move_name: String = str(intent.move)
			line.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					inspect.emit(move_name)
					line.accept_event())
			var at_me: bool = str(intent.get("target", "")) == local_id
			GemIcons.glyph(line, GemIcons.emblem(str(intent.move).to_upper()), 16, DeepUi.BAD if at_me else DeepUi.MUTED, str(intent.move))
			DeepUi.label(line, str(intent.move), 12, DeepUi.PAPER if at_me else DeepUi.MUTED)
			for effect in intent.get("effects", []):
				var kind: String = str(effect.kind)
				var amount: int = int(effect.amount) * maxi(1, int(effect.get("repeat", 1)))
				var glyph: String = str(MOVE_WORDS.get(kind, "spark"))
				var tone: Color = DeepUi.BAD if kind == "damage" else (DeepUi.BLOCK if kind == "block" else (DeepUi.POISON if kind == "poison" else DeepUi.INFO))
				var shown: String = str(amount) if kind in ["damage", "block", "poison", "remove_block", "heal"] else ""
				DeepUi.stat(line, glyph, shown, tone, 12, kind.replace("_", " ").capitalize())
			var victim: Dictionary = DeepBattle.player(battle, str(intent.get("target", "")))
			if not victim.is_empty() and intent.get("effects", []).any(func(e: Dictionary) -> bool: return str(e.target) in ["hero", "heroes"]):
				var who := DeepUi.stat(line, "person", "you" if at_me else str(victim.name), DeepUi.BAD if at_me else DeepUi.MUTED, 11, "Who it is aimed at")
				who.modulate.a = 1.0
	func fade() -> void:
		fading = true
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void: visible = false)

func _plate_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_target(id)

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
		var feet: Vector2 = _to_screen(creature.global_position)
		var head: Vector2 = _to_screen(creature.global_position + Vector3(0, creature.anchor.y * 0.9, 0))
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

func _laid_out() -> bool:
	## The viewport is only sized once the fight has been on screen; until then there is no
	## projection to speak of.
	return _camera != null and _viewport != null and _frame.size.x >= 1.0 and _frame.size.y >= 1.0 and _viewport.size.x >= 1 and _viewport.size.y >= 1

func _to_screen(point: Vector3) -> Vector2:
	if not _laid_out():
		return size * 0.5
	var at: Vector2 = _camera.unproject_position(point)
	return at * (_frame.size / Vector2(_viewport.size)) + _frame.position

func _from_screen(local: Vector2, distance: float) -> Vector3:
	if not _laid_out():
		return Vector3(0.0, 1.3, 5.2 - distance) if _camera == null or not _camera.is_inside_tree() else _camera.global_position + (-_camera.global_transform.basis.z) * distance
	var at: Vector2 = (local - _frame.position) * (Vector2(_viewport.size) / _frame.size)
	var point: Vector3 = _camera.project_position(at, distance)
	return point if point.is_finite() else _camera.global_position + (-_camera.global_transform.basis.z) * distance

func _control_world(control: Control, distance: float = 1.8) -> Vector3:
	## A point in the room just in front of the camera, behind a control on the HUD.
	var local: Vector2 = control.global_position + control.size * 0.5 - global_position
	return _from_screen(local, distance)

func _process(delta: float) -> void:
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
		var world_point: Vector3 = creature.global_position + Vector3(0, creature.anchor.y + 0.15, 0)
		if _camera.is_position_behind(world_point):
			continue
		var screen: Vector2 = _to_screen(world_point)
		var goal: Vector2 = screen - Vector2(plate.size.x * 0.5, plate.size.y + 12)
		if not plate.fading and not bool(creature.get_meta("dying", false)):
			highest = minf(highest, goal.y)
		if goal.y < ceiling:
			## No room over its head: the plate stands beside it instead of across its face.
			var body: Vector2 = _to_screen(creature.global_position + Vector3(0, creature.anchor.y * 0.55, 0))
			var reach: float = absf(_to_screen(creature.global_position + Vector3(1.2 * creature.scale.x, 0, 0)).x - _to_screen(creature.global_position).x)
			var right_side: bool = body.x < size.x * 0.6
			goal = Vector2(body.x + reach + 16.0 if right_side else body.x - reach - 16.0 - plate.size.x, body.y - plate.size.y * 0.5)
		goal.x = clampf(goal.x, 8.0, size.x - plate.size.x - 8.0)
		goal.y = clampf(goal.y, ceiling, size.y - plate.size.y - 260.0)
		plate.position = plate.position.lerp(goal, clampf(delta * 14.0, 0.0, 1.0)) if plate.position != Vector2.ZERO else goal
	_frame_camera(highest, ceiling, delta)
	var dock_top: float = _dock.position.y if _dock != null else size.y - 200.0
	_effects_box.position = Vector2(22.0, dock_top - _effects_box.size.y - 8.0)
	_govern(delta)
	_ambience(delta)

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

func _govern(delta: float) -> void:
	## Keeps the room smooth: after a few seconds under 40 frames a second, the chamber
	## gives up its most expensive effects one step at a time.
	if _quality <= 1 or quality_pref > 0:
		return
	if Engine.get_frames_per_second() < 40:
		_slow += delta
	else:
		_slow = maxf(0.0, _slow - delta * 2.0)
	if _slow > 3.0:
		_slow = 0.0
		_set_quality(_quality - 1)

func apply_quality() -> void:
	## The settings menu changed the graphics setting: take it up now, even mid-fight.
	_slow = 0.0
	_set_quality(3 if quality_pref <= 0 else clampi(quality_pref, 1, 3))

func _set_quality(level: int) -> void:
	_quality = level
	if _fx != null:
		_fx.quality = _quality
	if _chamber != null and is_instance_valid(_chamber) and _env != null:
		_chamber.set_quality(_quality, _env)
	if _viewport != null:
		_viewport.msaa_3d = Viewport.MSAA_4X if _quality >= 3 else (Viewport.MSAA_2X if _quality == 2 else Viewport.MSAA_DISABLED)
		_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if _quality <= 1 else Viewport.SCREEN_SPACE_AA_DISABLED

func _ambience(delta: float) -> void:
	## The room keeps moving on its own: a Warden's hall shakes and sheds dust, the magma
	## seam heaves, the Rift flickers.
	_ambient_clock += delta
	if _chamber == null or not is_instance_valid(_chamber):
		return
	var biome: Dictionary = _chamber.biome
	if _ambient_clock < _next_rumble:
		return
	_ambient_clock = 0.0
	_next_rumble = randf_range(6.0, 11.0)
	## Rock settling somewhere above, on the same clock the dust falls on.
	DeepAudio.play("cave_rumble", {"volume": 0.4 if bool(biome.get("warden", false)) else 0.22, "vary": 0.12})
	if bool(biome.get("warden", false)):
		_camera.add_trauma(0.22)
		_fx.dust_fall(50)
		_chamber.surge(Color(biome.accent), 0.5)
	elif str(biome.get("id", "")) == "magma":
		_camera.add_trauma(0.12)
		_fx.sparks(Vector3(randf_range(-7, 7), 0.2, randf_range(-14, -6)), Color("ff7a2a"), 30, 4.0, 1.2, 0.08)
	elif str(biome.get("id", "")) == "rift":
		_chamber.surge(Color(biome.accent), 0.8)
		_screen_fx.blink(Color(biome.accent), 0.08)
	elif str(biome.get("id", "")) == "galleries" and randf() < 0.5:
		_fx.dust_fall(24, 4.0)

# --- input ---------------------------------------------------------------------------------

func _toggle_die(id: String) -> void:
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or bool(unit.get("locked", false)):
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
	if _headless:
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
				_resonance_value.text = "0"
		"gem_fire":
			_gem_fire(event)
		"gem_fizzle":
			_gem_fizzle(event)
		"rail_end":
			var resonance: int = int(event.get("resonance", 0))
			if str(event.get("unit", "")) == local_id and resonance >= 3:
				## The chain pays off a step higher for every stone in it.
				DeepAudio.from(_resonance_box, "resonance", {"pitch": 1.0 + 0.09 * float(mini(resonance, 8)), "volume": 0.8})
				_float_at(_resonance_box, "Resonance ×%d" % resonance, _resonance_colour(resonance), 20)
				DeepUi.burst(self, _center_of(_resonance_box), _resonance_colour(resonance), 20 + resonance * 4, 180.0, 0.7)
		"enemy_move":
			_enemy_move(event)
		"tick":
			for tick in event.get("ticks", []):
				var target_id: String = str(tick.get("unit", ""))
				var colour: Color = DeepUi.POISON if str(tick.get("kind", "")) == "poison" else DeepUi.GOOD
				if _creatures.has(target_id) and is_instance_valid(_creatures[target_id]):
					var creature: CrystalCreature = _creatures[target_id]
					DeepAudio.play_at(global_position + _to_screen(creature.centre()), "poison" if str(tick.kind) == "poison" else "heal", {"volume": 0.5})
					_fx.puff(creature.centre(), colour, 10, 0.6, 1.0, 0.5, true)
					_float_world(creature.centre(), ("−%d" if str(tick.kind) == "poison" else "+%d") % int(tick.get("amount", 0)), colour, 22)
					if str(tick.kind) == "poison":
						creature.hit(0.3)
					if bool(tick.get("killed", false)):
						_kill(creature)
				elif target_id == local_id:
					DeepAudio.play("poison" if str(tick.kind) == "poison" else "heal", {"volume": 0.6})
					_float_at(_hp_bar, "−%d" % int(tick.get("amount", 0)), colour, 22)
					_screen_fx.blink(colour, 0.1)
		"skip":
			DeepAudio.play("stun", {"volume": 0.7})
			var who: String = str(event.get("unit", ""))
			if _creatures.has(who) and is_instance_valid(_creatures[who]):
				var creature: CrystalCreature = _creatures[who]
				_fx.stars(creature.global_position + Vector3(0, creature.anchor.y * 0.85, 0))
				_float_world(creature.global_position + Vector3(0, creature.anchor.y, 0), "Stunned", Color("ffe27a"), 18)
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
					var colour: Color = [DeepUi.ACCENT, DeepUi.GOOD, DeepUi.INFO, Color("c58bff")][i]
					_fx.sparks(Vector3(randf_range(-3, 3), 1.5, ARC_Z), colour, 50, 6.0, 1.4, 0.07)
				_fx.flash(Vector3(0, 3, ARC_Z), DeepUi.ACCENT, 8.0, 14.0, 1.2, 2.0)
			else:
				DeepAudio.play("defeat")
				_announce("The party falls", DeepUi.BAD, "Everything loose will be salvaged", 2.4)
				_camera.defeat()
				var tween := create_tween()
				tween.tween_property(_screen_fx, "desaturate", 0.85, 1.4)
				_screen_fx.wound(1.0)

func _stone_colour(unit_id: String, socket: int, skill_key: String) -> Color:
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var rail: Array = unit.get("rail", [])
	if socket >= 0 and socket < rail.size() and rail[socket] is Dictionary:
		return DeepUi.colour(DeepStone.colour(rail[socket]))
	return DeepUi.colour(str(DeepContent.skill(skill_key).get("colour", "WHITE")))

func _colour_key(unit_id: String, socket: int, skill_key: String) -> String:
	## What a stone rings as. Its colour is what kind of thing it does, so it is also its voice.
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var rail: Array = unit.get("rail", [])
	if socket >= 0 and socket < rail.size() and rail[socket] is Dictionary:
		return DeepStone.colour(rail[socket])
	return str(DeepContent.skill(skill_key).get("colour", "WHITE"))

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
	var colour: Color = _stone_colour(unit_id, socket, str(event.get("skill", "")))
	var origin: Vector3 = _origin_for(unit_id, socket)
	var magnitude: float = clampf(float(event.get("magnitude", 1.0)), 0.5, 4.0)
	var voice: String = DeepSoundBank.gem_sound(_colour_key(unit_id, socket, str(event.get("skill", ""))))
	var carry: float = clampf(0.5 + magnitude * 0.14, 0.45, 1.0) * (1.0 if mine else 0.55)
	if mine and socket >= 0 and socket < _socket_cards.size():
		var card: Control = _socket_cards[socket]
		DeepAudio.from(card, voice, {"volume": carry, "gap": 0.02})
		var ring: SocketRing = card.get_node_or_null("Slot/Ring")
		if ring != null:
			ring.fire()
		DeepUi.pulse(card, 1.18, 0.4)
		DeepUi.burst(self, _center_of(card), colour, 18, 170.0, 0.55)
		if int(event.get("gain", 0)) > 0:
			_resonance_value.text = str(int(event.get("resonance", 0)))
			_resonance_value.add_theme_color_override("font_color", _resonance_colour(int(event.get("resonance", 0))))
			DeepUi.pulse(_resonance_box, 1.25, 0.35)
			if bool(event.get("harmony", false)):
				DeepAudio.from(_resonance_box, "harmony", {"volume": 0.7})
				_float_at(_resonance_box, "+%d harmony" % int(event.gain), DeepUi.ACCENT_HI, 15)
		if bool(event.get("retrigger", false)):
			_float_at(card, "Again!", DeepUi.ACCENT_HI, 15)
	elif _ally_cards.has(unit_id) and is_instance_valid(_ally_cards[unit_id]):
		DeepAudio.from(_ally_cards[unit_id], voice, {"volume": carry, "gap": 0.02})
		DeepUi.pulse(_ally_cards[unit_id], 1.05, 0.3)
	else:
		DeepAudio.play(voice, {"volume": carry, "gap": 0.02})
	var shot: int = 0
	for effect in event.get("effects", []):
		var kind: String = str(effect.get("kind", ""))
		var target_id: String = str(effect.get("target", ""))
		match kind:
			"damage":
				var hits: Array = [effect] + effect.get("splash", [])
				for hit in hits:
					var who: String = str(hit.get("target", target_id))
					var creature: CrystalCreature = _creature(who)
					if creature == null or not is_instance_valid(creature):
						continue
					var landing: Dictionary = hit.duplicate()
					var travel: float = 0.22 + 0.05 * float(shot)
					if bool(hit.get("killed", false)):
						creature.set_meta("dying", true)
					_fx.projectile(origin, creature.centre(), colour, travel, 0.11 + 0.04 * magnitude, _impact.bind(who, landing, colour, mine), 0.6 + randf() * 0.5)
					shot += 1
			"block":
				DeepAudio.play("block", {"volume": 0.6 if target_id == local_id else 0.45})
				if target_id == local_id:
					var ahead: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 2.2 + Vector3(0, -0.35, 0)
					_fx.shield(ahead, _camera.global_position - ahead, DeepUi.BLOCK, 0.8)
					_screen_fx.blink(DeepUi.BLOCK, 0.08)
					_float_at(_hp_bar, "+%d block" % int(effect.amount), DeepUi.BLOCK, 20)
				elif _ally_cards.has(target_id):
					_float_at(_ally_cards[target_id], "+%d block" % int(effect.amount), DeepUi.BLOCK, 16)
			"heal", "revive":
				DeepAudio.play("heal", {"volume": 0.7})
				var healed: int = int(effect.get("healed", effect.amount))
				if target_id == local_id:
					var below: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 2.6 + Vector3(0, -1.4, 0)
					_fx.rise(below, DeepUi.GOOD, 34, 1.4)
					_screen_fx.blink(DeepUi.GOOD, 0.1)
					_float_at(_hp_bar, "+%d" % healed, DeepUi.GOOD, 24)
				elif _ally_cards.has(target_id):
					_float_at(_ally_cards[target_id], "+%d" % healed, DeepUi.GOOD, 16)
			"gold":
				if mine:
					DeepAudio.play("ore", {"volume": 0.7})
					var pile: Vector3 = Vector3(randf_range(-1.5, 1.5), 1.2, ARC_Z + 0.5)
					var home: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.4 + Vector3(0.8, -0.7, 0)
					_fx.coins(pile, home, 8 + mini(12, int(effect.amount)))
					_float_at(_forecast_box, "+%d ore" % int(effect.amount), DeepUi.ORE, 20)
			"poison", "stun", "curse", "remove_block", "intent_downgrade", "die_steal", "cleanse":
				var creature: CrystalCreature = _creature(target_id)
				if creature != null and is_instance_valid(creature):
					var tone: Color = {"poison": DeepUi.POISON, "stun": Color("ffe27a"), "curse": Color("c58bff"), "remove_block": DeepUi.BLOCK}.get(kind, colour)
					var landing: Dictionary = effect.duplicate()
					_fx.projectile(origin, creature.centre(), tone, 0.3 + 0.05 * float(shot), 0.1, _afflict.bind(target_id, landing, tone), 1.0)
					shot += 1
				elif target_id == local_id and kind == "cleanse":
					_fx.rise(_camera.global_position + (-_camera.global_transform.basis.z) * 2.6 + Vector3(0, -1.4, 0), Color.WHITE, 20, 1.2)
			"raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high":
				if mine:
					_float_at(_tray_box, kind.replace("_", " ").capitalize(), Color.WHITE, 15)
					for id in _dice_views:
						var view: Control = _dice_views[id]
						DeepUi.burst(self, _center_of(view), colour, 6, 80.0, 0.4, 4.0)
			_:
				if mine and socket >= 0 and socket < _socket_cards.size():
					_float_at(_socket_cards[socket], kind.replace("_", " ").capitalize(), colour.lightened(0.3), 13)

func _impact(who: String, hit: Dictionary, colour: Color, mine: bool) -> void:
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
	_fx.sparks(at, colour, 18 + mini(40, amount * 2), 4.0 + ratio * 6.0, 0.6, 0.06)
	_fx.glow_burst(at, colour, 1.2 + ratio * 3.0, 0.3)
	_fx.flash(at, colour, 4.0 + ratio * 10.0, 7.0, 0.3, 0.8 + ratio)
	if int(hit.get("absorbed", 0)) > 0:
		_fx.shield(at + Vector3(0, 0, 0.6), _camera.global_position - at, DeepUi.BLOCK, 0.7, 0.4)
	_camera.add_trauma(0.1 + ratio * 0.55)
	if ratio >= 0.25 or bool(hit.get("killed", false)):
		_camera.punch(-4.0 - ratio * 4.0, 0.4)
		_camera.focus(at, 0.2, 0.6)
		_screen_fx.kick(0.5 + ratio)
		_fx.ring_wave(Vector3(at.x, 0.0, at.z), colour, 2.5 + ratio * 3.0, 0.5)
	var text: String = "−%d" % amount
	var size: int = 24 + mini(28, amount)
	_float_world(at + Vector3(0, 0.6, 0), text, colour.lightened(0.35) if mine else DeepUi.PAPER, size)
	if int(hit.get("absorbed", 0)) > 0:
		_float_world(at + Vector3(0.5, 0.2, 0), "%d blocked" % int(hit.absorbed), DeepUi.BLOCK, 14)
	if int(hit.get("reflected", 0)) > 0:
		_float_at(_hp_bar, "−%d reflected" % int(hit.reflected), DeepUi.BAD, 16)
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
	var spoken: String = {"poison": "poison", "stun": "stun", "curse": "curse", "intent_downgrade": "curse",
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
		"curse", "intent_downgrade":
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
	_resonance_value.text = str(int(event.get("resonance", 0)))
	_resonance_value.add_theme_color_override("font_color", _resonance_colour(int(event.get("resonance", 0))))
	DeepUi.shake(_resonance_box, 8.0, 0.25)

func _enemy_move(event: Dictionary) -> void:
	var creature: CrystalCreature = _creature(str(event.get("unit", "")))
	var windup: float = 0.26
	if creature != null and is_instance_valid(creature):
		DeepAudio.play_at(global_position + _to_screen(creature.centre()), "enemy_windup", {"volume": 0.7})
		creature.lunge(_camera.global_position, 0.62)
		_fx.flash(creature.centre(), creature.tint, 3.0, 5.0, 0.4, 0.8)
		_float_world(creature.global_position + Vector3(0, creature.anchor.y + 0.3, 0), str(event.get("move", "")), creature.tint.lightened(0.4), 20)
	var effects: Array = event.get("effects", [])
	var who: String = str(event.get("unit", ""))
	var tween := create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		for effect in effects:
			_enemy_effect(effect, _creature(who)))

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

func _slash(colour: Color) -> void:
	## Claw marks across the view: three bright strokes that rip in and fade.
	var marks := Slash.new()
	marks.colour = colour.lightened(0.4)
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(marks)
	move_child(marks, _hud.get_index())

class Slash extends Control:
	var colour: Color = Color.WHITE
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
			draw_line(a, b, Color(colour, 0.35 * alpha), 22.0, true)
			draw_line(a, b, Color(colour, 0.9 * alpha), 6.0, true)
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
