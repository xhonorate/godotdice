extends Control
## The fight, seen from the party's own eyes.
##
## The room is the mine stage's: during a run it is the room the party walked into, and a
## screen shown on its own (a gallery shot) makes a stage of its own. Creatures stand in an
## arc facing the camera; the plate above each is a 2D control pinned to a 3D anchor. A
## player's rail, dice and forecast sit in a dock at the bottom, one page a player; in a party
## a tab a player rides on top of the dock (the reader's first) with their buffs over it, and
## the dock follows the turn from rail to rail as each one fires.
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
const StreakFx = preload("res://view/battle/streak_fx.gd")
const MotleyFx = preload("res://view/battle/motley_fx.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Tally = preload("res://view/battle/tally.gd")
const ResonanceCount = preload("res://view/battle/resonance_count.gd")
const ShaftMap = preload("res://view/run/shaft_map.gd")
const Roster = preload("res://view/home/roster.gd")
const VitalsRing = preload("res://view/battle/vitals_ring.gd")
const ResonanceMeter = preload("res://view/battle/resonance_meter.gd")
const Fan = preload("res://view/battle/fan.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")
## The field of view the camera prefers; it widens on its own when a tall creature and its
## plate would not fit under the top of the screen, and narrows back when they would.
## What Sleight does, on its button. See `DeepBattle.shift_face`.
const SHIFT_TIP: String = "Sleight, once a turn: turn one die over. The face underneath is the other parity (its mirror face, a 2 on a d6 to its 5, or the nearest face of the other parity it has). Right-click a die to turn it, hold it, or pick it and press F. A die whose faces are all even or all odd can't turn."
const BASE_FOV: float = 58.0

signal command(cmd: Dictionary)

## The dock (docs/UI_REDO.md): a die and a socket ring stand this large, and the player's
## face in its ring of health this large, so the dock stands one height for the whole fight.
const DIE_EDGE: float = 100.0
const SOCKET_EDGE: float = 94.0
const VITALS_EDGE: float = 156.0
## The rows of the dock that both docks share (docs/UI_REDO.md): the short line over the
## dice, the words under a die, the buttons under the dice and the Resonance meter under the
## rail. The run's dock lays empty rows of the same heights, so a gem or a die stands exactly
## where it stood as a fight begins and ends.
const OVER_ROW: float = 14.0
const DIE_WORDS: float = 14.0
const BUTTONS_ROW: float = 38.0
const METER_ROW: float = 24.0
## A Void rider's gem, or a phantom's die, drawn faint behind the ring it fans out from.
const VOID_GHOST := Color(0.78, 0.84, 1.0, 0.55)
## How many Void gems riding a socket are drawn fanned behind it before a count stands for
## the rest (docs/UI_REDO.md).
const RIDERS_SHOWN: int = 3
## A set gem the hand in the tray would leave dark: still readable, plainly stepped back.
const QUIET_GEM := Color(0.62, 0.62, 0.68, 0.72)
const ARC_Z: float = -4.4
const MOVE_WORDS: Dictionary = {"damage": "sword", "block": "shield", "poison": "drop", "stun": "stun", "remove_block": "split_shield",
	"die_steal": "die", "heal": "heart", "curse": "eye", "bury_socket": "rampart", "cloud_socket": "cloud"}

var local_id: String = ""
var state: Dictionary = {}
var depth: int = 1
## What the hand on the page being drawn would do (the reader's own, outside a page's sync).
var forecast: Dictionary:
	get: return _page.forecast
	set(value): _page.forecast = value
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
		## The fight's name steps aside for the chart too, rather than showing through it.
		if _place_box != null:
			_place_box.position.x = 22.0 + left_inset

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
var _place_box: VBoxContainer
var _biome_label: Label
var _turn_pill: PanelContainer
var _foes_pill: PanelContainer
var _banner: Label
var _banner_sub: Label
var _banner_box: VBoxContainer
var _dock: PanelContainer
## The dock's border as it was last drawn: gold under the reader's own page in a party, the
## seat color of whoever else's page is up.
var _dock_tone: Color = Color(0, 0, 0, 0)
var _dock_style: StyleBoxFlat = null
var _dock_tween: Tween = null
## The light run along the dock's top edge as a page comes up, built once.
var _edge_texture: GradientTexture2D = null
## A page a player (see `Page`): the reader's own, built with the screen, and one for everyone
## else in the fight, built the first time they are seen. `_page` is the one the drawing
## functions below draw on: the reader's own, except while another player's page is being
## brought up to date, and it is put straight back after.
var _local_page: Page = Page.new()
var _page: Page = null
var _pages: Dictionary = {}
## Whose page is in the dock; "" for the reader's own.
var _shown_id: String = ""
## The party along the top of the dock: a tab a player, the reader's own first, each with
## that player's buffs and troubles over it.
var _tab_bar: HBoxContainer
var _my_tab: SeatTab
var _tabs: Dictionary = {}
## The rail firing now, every player whose rail has had its go this turn, and the last rail
## that began (the turn passes from its tab to the next one's).
var _firing_id: String = ""
var _fired: Dictionary = {}
var _last_rail_id: String = ""
## The turn the reader was last told everyone else is waiting on them.
var _called_turn: int = -1
## Each player's rerolls and lock as last seen, and when they last spent a reroll: their tab
## says so for a moment after.
var _seen_rerolls: Dictionary = {}
var _seen_locked: Dictionary = {}
var _rerolled_at: Dictionary = {}
const REROLL_SHOWN_MS: int = 1200
## A face each player wears for a moment (a flinch, eyes on the dice, a Birthstone going
## off), by id: [mood, until msec]. Past it they wear what their health says.
var _passing: Dictionary = {}
## The fight is won: everyone still standing wears it.
var _won: bool = false
## A figure growing while one gem's blows land (a Riposte's guard), by player id:
## {"plate", "token", "total", "timer"}. A new gem from them closes it and starts again.
var _swells: Dictionary = {}
## Which gem or Birthstone each player's blows belong to right now, bumped as each fires; and
## which round of poison is biting, with how many times each Leech has drunk from it.
var _blow_token: Dictionary = {}
var _leech_token: int = 0
var _leech_beat: Dictionary = {}
## A turn has opened and its passives are still to be shown, once the walk in is over.
var _opening_due: bool = false
## What the Gambler's pot and purse read while coins are still on their way, by player id:
## the truth once they land.
var _pot_held: Dictionary = {}
var _bank_held: Dictionary = {}
## Told when the purse should be read again (the strip over the fight shows it).
signal bank_changed(delta: int)
## The purse on the strip, for coins to fly to and from: () -> Control.
var bank_anchor: Callable = Callable()
## House Money has been seen going onto the table this fight (until it has, the pot reads
## empty and the purse whole: see `_house_due`); Study's reroll is still being counted onto
## the button (how many the button holds back, until when).
var _house_shown: bool = false
var _study_lag: int = 0
var _study_until: int = 0
## How tall the reader's buttons stand, so a page without them keeps the dock the same height.
var _buttons_height: float = 0.0
var _rail_box: HBoxContainer:
	get: return _page.rail_box
	set(value): _page.rail_box = value
## One control per entry of the fighter's flat rail: a socket's card, or a rider's chip.
var _socket_cards: Array:
	get: return _page.socket_cards
	set(value): _page.socket_cards = value
var _rail_shape: String:
	get: return _page.rail_shape
	set(value): _page.rail_shape = value
var _resonance_value: Label:
	get: return _page.resonance_value
	set(value): _page.resonance_value = value
var _resonance_box: HBoxContainer:
	get: return _page.resonance_box
	set(value): _page.resonance_box = value
var _tray_box: HBoxContainer:
	get: return _page.tray_box
	set(value): _page.tray_box = value
var _dice_views: Dictionary:
	get: return _page.dice_views
	set(value): _page.dice_views = value
## Phantom dice (a Refract's copies of the highest die), drawn small and ghostly after the
## five; and what they were last drawn from.
var _phantom_box: HBoxContainer:
	get: return _page.phantom_box
	set(value): _page.phantom_box = value
var _phantom_key: String:
	get: return _page.phantom_key
	set(value): _page.phantom_key = value
## A rearrangement of the room put off until a death or a split has finished animating, and
## the creatures whose arrival has already been waited for.
var _layout_wait: SceneTreeTimer = null
var _layout_generation: int = 0
var _banner_tween: Tween = null
var _awaited: Dictionary = {}
## The hand as it was last seen, and when the dice it rolled will have finished tumbling.
var _rolled_hand: String:
	get: return _page.rolled_hand
	set(value): _page.rolled_hand = value
var _dice_settle_at: int:
	get: return _page.dice_settle_at
	set(value): _page.dice_settle_at = value
var _reroll_button: Button
var _flip_button: Button
var _lock_button: Button
var _birthstone_card: VBoxContainer:
	get: return _page.birthstone_card
	set(value): _page.birthstone_card = value
var _birthstone_key: String:
	get: return _page.birthstone_key
	set(value): _page.birthstone_key = value
var _hint: Label:
	get: return _page.hint
	set(value): _page.hint = value
var _hp_bar: VitalsRing:
	get: return _page.hp_bar
	set(value): _page.hp_bar = value
var _status_row: Control:
	get: return _page.status_row
	set(value): _page.status_row = value
## The reader's own buffs and troubles, over their tab.
var _effects: EffectChips.Row
var _fight_effects: EffectChips.Row
## The block the status row was last drawn with: it is only rebuilt when that changes.
var _status_block: int:
	get: return _page.status_block
	set(value): _page.status_block = value
var _lock_pulse: Tween = null
## The forecast as the hand stood when it was locked in, and what the rail has actually done
## since: socket -> fired, and the Birthstone's own event.
var _held_forecast: Dictionary:
	get: return _page.held_forecast
	set(value): _page.held_forecast = value
var _outcomes: Dictionary:
	get: return _page.outcomes
	set(value): _page.outcomes = value
var _birth_outcome: Dictionary:
	get: return _page.birth_outcome
	set(value): _page.birth_outcome = value
## Bumped by every change to the Resonance number, so sparks still in flight never write an
## old value over a newer one.
var _resonance_token: int:
	get: return _page.resonance_token
	set(value): _page.resonance_token = value
## What the dice owed on the throw this turn opened with, and what grew back with them.
var _pending_dues: Dictionary = {}
## All or Nothing: the crowns the turn's opening throw brought up, rung once it is seen.
var _pending_crowns: Array = []
## Florin's hot streak, worn by the reader's own tray (see streak_fx.gd).
var _streak_fx: Control = null
## Puck's motley, over the reader's own tray, for as long as the faces keep changing.
var _motley_fx: Control = null
## A die held down long enough turns over (Sleight): the click that follows is not a pick.
var _pressing: String = ""
var _press_token: int = 0
var _long_pressed: String = ""
var _pending_regrown: Dictionary = {}
var _battery_tween: Tween:
	get: return _page.battery_tween
	set(value): _page.battery_tween = value
## The rail firing now, as pitch: each gem's count starts a step further up the music's scale.
var _chain: Tally.Chain = Tally.Chain.new()
## The phantom dice beside the hand, by die id, for a count to point at.
var _phantom_views: Dictionary:
	get: return _page.phantom_views
	set(value): _page.phantom_views = value
## What a count has not landed yet, held on the bars at what it was before: a creature's
## health and block by its id, and each player's under theirs. Each is {"hp", "block",
## "landings", "until"}: it lets go when its last blow (or guard, or heal) lands, and lapses
## by itself if one never does, so nothing is held for good.
var _held: Dictionary = {}
const HELD_MS: int = 6000
## What the rail has dealt this turn, counted up beside the forecast as its blows land.
var _turn_dealt: int:
	get: return _page.turn_dealt
	set(value): _page.turn_dealt = value
var _dealt_box: HBoxContainer:
	get: return _page.dealt_box
	set(value): _page.dealt_box = value
var _dealt_label: Label:
	get: return _page.dealt_label
	set(value): _page.dealt_label = value
## The plate a hovered gem shows while the hand is still being chosen.
var _preview: Control = null
## Whether the creature move being played now is one whose blows block may be counted against.
var _soaking: bool = false
var _soak_pace: float = 1.0

var _shows: int = 0

func _init() -> void:
	_local_page.mine = true
	_page = _local_page

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
	## The depth is on the strip already: only what kind of room it is is said here.
	var kind_words: String = ("The bottom of the mine" if boss else "Warden's gate") if bool(biome.warden) else ("Elite" if bool(biome.elite) else "")
	_biome_label.text = kind_words
	_biome_label.visible = not kind_words.is_empty()
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
	## A wait started in a fight that has since been let go lays nothing out in the next one.
	var generation: int = _layout_generation
	_layout_wait = get_tree().create_timer(maxf(0.1, seconds))
	_layout_wait.timeout.connect(func() -> void:
		if not is_instance_valid(self) or generation != _layout_generation:
			return
		_layout_wait = null
		if not state.is_empty():
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
	place.position = Vector2(22.0 + left_inset, 16)
	_place_box = place
	var depth_row := DeepUi.hbox(place, 10)
	DeepUi.icon(depth_row, "pick", 24, DeepUi.ACCENT, "Where the fight is")
	_depth_label = DeepUi.title(depth_row, "", 24, DeepUi.PAPER)
	_turn_pill = DeepUi.pill(depth_row, "hourglass", "Turn 1", DeepUi.MUTED, 13, "Turn")
	_turn_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_biome_label = DeepUi.label(place, "", 14, DeepUi.MUTED)
	_biome_label.add_theme_font_override("font", DeepUi.caps_font())
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
	## The dock: one page a player, the one being looked at shown.
	_dock = PanelContainer.new()
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 16
	_dock.offset_right = -16
	_dock.offset_bottom = -14
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_dock)
	_dock.gui_input.connect(_hurry_input)
	_dress_dock(DeepUi.LEDGER_LINE, false)
	_build_page(_local_page)
	## The party, along the top of the dock: drawn after it, so the tab that is up lies over
	## the dock's edge and the two read as one piece. Alone, only the buffs over the tab show.
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 6)
	_tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tab_bar)
	_my_tab = SeatTab.new(true)
	_my_tab.picked.connect(_pick_tab.bind(""))
	_tab_bar.add_child(_my_tab)
	_effects = _my_tab.chips
	## A hot streak's embers and flames, over the reader's own tray.
	_streak_fx = StreakFx.new()
	_streak_fx.follow = _local_page.tray_box
	_streak_fx.shimmer_host = _hud
	_streak_fx.dice_rects = func() -> Array:
		var rects: Array = []
		for view in _local_page.dice_views.values():
			if is_instance_valid(view) and (view as Control).is_visible_in_tree():
				rects.append((view as Control).get_global_rect())
		return rects
	_hud.add_child(_streak_fx)
	## The Changing Face's motley, over the same tray.
	_motley_fx = MotleyFx.new()
	_motley_fx.follow = _local_page.tray_box
	_hud.add_child(_motley_fx)

func _build_page(page: Page) -> void:
	## A player's page of the dock, built once (docs/UI_REDO.md, layout 1a): their face in the
	## ring of their health, their rail with the thread of Resonance under it, their dice and
	## their buttons. The reader's own has the buttons; anyone else's says what they are doing
	## in their place, so the dock stands the same height for both. Nothing on it is a heading
	## or a hint: the things themselves say what they are, and their plates say the rest.
	var was: Page = _page
	_page = page
	var columns := DeepUi.hbox(_dock, 16)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.set_meta("page", page)
	columns.visible = page.mine
	page.root = columns
	## Far left: the player themself, their face in the ring their health runs round, their
	## block an arc outside it, and the numbers once in the capsule under it.
	_hp_bar = VitalsRing.new(VITALS_EDGE, "")
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(_hp_bar)
	page.face = _hp_bar.portrait
	_status_row = _hp_bar.shield_badge
	var whose: Page = page
	Tips.attach(_hp_bar, func() -> Control: return _vitals_plate(whose))
	## The rail, the Resonance it comes to at its end, and the thread under it.
	## The rail stands level with the dice (the same room over it as the line over them), and
	## the meter takes what is left under the names and centres itself in it.
	var left := DeepUi.vbox(columns, 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	DeepUi.gap(left, OVER_ROW + 4.0)
	var rail_row := DeepUi.hbox(left, 12)
	rail_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_rail_box = DeepUi.hbox(rail_row, 6)
	_rail_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_rail_box.custom_minimum_size.y = SOCKET_EDGE + 20
	## While the turn plays out: what the rail has really dealt, counted up blow by blow.
	_dealt_box = DeepUi.hbox(rail_row, 4)
	_dealt_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_dealt_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dealt_box.tooltip_text = "Damage your rail has dealt this turn" if page.mine else "Damage their rail has dealt this turn"
	DeepUi.icon(_dealt_box, "impacts", 16, DeepUi.BAD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dealt_label = DeepUi.title(_dealt_box, "0", 18, DeepUi.BAD)
	_dealt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dealt_box.visible = false
	## Resonance, centred under the sockets: the word and the number, and the waves that
	## reach out along the rail as it grows (docs/UI_REDO.md).
	page.meter = ResonanceMeter.new()
	page.meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(page.meter)
	_resonance_box = page.meter.box
	_resonance_value = page.meter.number
	Tips.attach(page.meter, func() -> Control: return Plates.words("Resonance", "Each gem that fires adds one, a neighbour of the same color adds two, and a gem that stays dark costs nothing. Your Birthstone reads it last. The waves reach along the rail as it grows, one for each color that rang.", "the rail ringing", DeepUi.RESONANCE))
	var divider := DeepUi.rule(columns, DeepUi.LEDGER_LINE)
	divider.custom_minimum_size = Vector2(3, 0)
	## Right: the dice, and under them the buttons, centred.
	var middle := DeepUi.vbox(columns, 6)
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	## One short line over the dice, kept whether or not it has anything to say: Puck's
	## Motley reads here, and the one word of state the dock still needs (Resolving, Waiting).
	var over := DeepUi.hbox(middle, 8)
	over.alignment = BoxContainer.ALIGNMENT_CENTER
	over.custom_minimum_size.y = OVER_ROW
	page.hand_title = DeepUi.heading(over, "", 11)
	page.hand_title.visible = false
	if page.mine:
		page.face_chip = DeepUi.label(over, "", 12, DeepUi.MUTED)
		page.face_chip.visible = false
		page.face_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		page.face_chip.mouse_filter = Control.MOUSE_FILTER_PASS
		page.face_chip.tooltip_text = "Motley reads the whole hand: all odd is the Cruel Face, all even the Kind Face, and all one parity and all different is Full Motley."
	_hint = DeepUi.label(over, "", 12, DeepUi.MUTED)
	var hand_row := DeepUi.hbox(middle, 8)
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray_box = DeepUi.hbox(hand_row, 8)
	_tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	## The phantoms fan out behind the die they copy (see `_sync_phantoms`); this row is kept
	## empty for the counts that still look for it.
	_phantom_box = DeepUi.hbox(hand_row, 6)
	_phantom_box.visible = false
	var buttons := DeepUi.hbox(middle, 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	if page.mine:
		_reroll_button = DeepUi.icon_button(buttons, "reroll", "Reroll", _reroll, 15, DeepUi.INFO)
		DeepUi.ledger_button(_reroll_button, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
		_reroll_button.custom_minimum_size = Vector2(150, BUTTONS_ROW)
		_reroll_button.tooltip_text = "Reroll the selected dice  [R]"
		## The rerolls left, as pips at the button's right end.
		var pips := Control.new()
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		pips.offset_left = -46
		pips.offset_right = -12
		pips.offset_top = -5
		pips.offset_bottom = 5
		pips.draw.connect(func() -> void:
			var left_now: int = int(pips.get_meta("left", 0))
			var total: int = int(pips.get_meta("total", 2))
			for i in range(mini(total, 4)):
				var at := Vector2(5.0 + float(i) * 10.0, pips.size.y * 0.5)
				if i < left_now:
					pips.draw_circle(at, 3.5, DeepUi.INFO)
				else:
					pips.draw_arc(at, 3.5, 0.0, TAU, 16, Color(DeepUi.INFO, 0.4), 1.5, true))
		_reroll_button.add_child(pips)
		page.reroll_pips = pips
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var box: StyleBox = _reroll_button.get_theme_stylebox(style_name)
			if box != null:
				box.content_margin_right = box.content_margin_right + 36.0
		_flip_button = DeepUi.icon_button(buttons, "eye", "Turn over", _flip, 15, DeepUi.ACCENT)
		DeepUi.ledger_button(_flip_button, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
		_flip_button.custom_minimum_size = Vector2(0, BUTTONS_ROW)
		_flip_button.tooltip_text = SHIFT_TIP
		_flip_button.visible = false
		_lock_button = DeepUi.primary(buttons, "check", "Lock in", _toggle_lock, 16)
		DeepUi.ledger_primary(_lock_button)
		_lock_button.custom_minimum_size = Vector2(170, BUTTONS_ROW)
		_lock_button.tooltip_text = "Lock in this hand  [Space]"
		_buttons_height = buttons.get_combined_minimum_size().y
	else:
		## Where the reader's buttons are: whether they are still choosing or locked in, and
		## the rerolls they have left.
		page.mate_state = buttons
		buttons.custom_minimum_size.y = maxf(_buttons_height, BUTTONS_ROW)
	_page = was

func _vitals_plate(page: Page) -> Control:
	## The ring's plate: the numbers, and what the ring and the arc outside it are.
	var unit: Dictionary = DeepBattle.player(state, local_id if page.mine else page.id)
	if unit.is_empty():
		return null
	var shown: Dictionary = _shown(unit)
	var words: String = "The ring is health, %s of %s. " % [DeepUi.number(int(shown.hp)), DeepUi.number(int(shown.max_hp))]
	if int(shown.get("block", 0)) > 0:
		words += "Block is the number at the top: %s soaks that much hit damage, and falls away at the next turn unless Retain keeps it. Its arc grows both ways round the ring, a whole ring at block to match full health, and past that it thickens and armours the face. " % DeepUi.number(int(shown.block))
	else:
		words += "Block, when there is any, is a number at the top and an arc round the ring. "
	words += "A blow being counted hatches in red what it will take."
	var passive: String = passive_words(unit)
	if not passive.is_empty():
		words += "
" + passive
	return Plates.words(str(unit.get("name", "")), words, DeepContent.character_title(str(unit.get("character", ""))), DeepUi.HP)

func _sync_pips(left: int, total: int) -> void:
	var pips: Control = _page.reroll_pips
	if pips == null or not is_instance_valid(pips):
		return
	pips.set_meta("left", left)
	pips.set_meta("total", maxi(total, left))
	pips.queue_redraw()

func _dress_dock(tone: Color, _theirs: bool) -> void:
	## The dock's frame: a Ledger plate (opaque, a heavy outline, a hard shadow) whose outline
	## is the kit's own under the reader's page alone, gold under it in a party, and the seat
	## color of whoever else's page is up. One frame for the whole fight, its color eased
	## from one player's to the next.
	if tone == _dock_tone:
		return
	_dock_tone = tone
	var first: bool = _dock_style == null
	if first:
		_dock_style = DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, 12, 3, 5)
		_dock.add_theme_stylebox_override("panel", _dock_style)
	if _dock_tween != null and _dock_tween.is_valid():
		_dock_tween.kill()
	if first or _headless or not is_inside_tree():
		_dock_style.border_color = tone
		return
	_dock_tween = create_tween()
	_dock_tween.tween_property(_dock_style, "border_color", tone, 0.28).set_trans(Tween.TRANS_SINE)

func dock_height() -> float:
	## How tall the dock stands with the reader's page in it: the run's own dock, outside a
	## fight, stands exactly as tall, so the bottom of the screen never jumps.
	return _dock.get_combined_minimum_size().y if _dock != null else 0.0

func bind(player_id: String) -> void:
	local_id = player_id

func show_state(battle: Dictionary, at_depth: int, new_forecast: Dictionary = {}, new_context: Dictionary = {}) -> void:
	_shows += 1
	modulate.a = 1.0
	state = battle
	depth = at_depth
	## Once the hand is locked in, the forecast it was locked in with stays up: the rail keeps
	## showing what would fire, and each gem corrects it as it actually fires or fizzles.
	if wants_forecast(battle):
		_held_forecast = new_forecast
	forecast = _held_forecast
	if not new_context.is_empty():
		context = new_context
	## Enemy ids start again at e0 in every fight, so a new fight is recognised by the run's
	## fight count, where it is, and who it opened with, and everything pinned to the old one
	## is let go. Something summoned or split off mid-fight is not a new fight.
	var founders: Array = state.get("enemies", []).filter(func(e: Dictionary) -> bool:
		return str(e.get("summoned_by", "")).is_empty() and not str(e.get("id", "")).contains("_split"))
	var signature: String = "%d|%d|%s" % [int(context.get("fight", 0)), depth, ",".join(founders.map(func(e: Dictionary) -> String: return "%s:%s" % [str(e.get("id", "")), str(e.get("key", ""))]))]
	if signature != _battle_signature:
		_battle_signature = signature
		_forget_fight()
	_rebuild_chamber()
	_place_creatures()
	_sync()

func wants_forecast(battle: Dictionary) -> bool:
	## Whether show_state would take a new forecast for this state: while planning, or with
	## none held. Asked first, so a forecast nobody will look at is never worked out.
	return str(battle.get("phase", "")) == "planning" or _held_forecast.is_empty()

func _forget_fight() -> void:
	selected.clear()
	_held.clear()
	if _enemy_panel != null:
		_enemy_panel.reset()
	for page in _all_pages():
		page.outcomes.clear()
		page.birth_outcome = {}
	## A new fight opens on the reader's own page.
	_shown_id = ""
	_firing_id = ""
	_fired.clear()
	_seen_rerolls.clear()
	_seen_locked.clear()
	_rerolled_at.clear()
	_passing.clear()
	_won = false
	for id in _swells.keys():
		_close_swell(str(id))
	_blow_token.clear()
	_pot_held.clear()
	if not _bank_held.is_empty():
		_bank_held.clear()
		bank_changed.emit(0)
	_study_lag = 0
	_leech_beat.clear()
	_infinity_seen = false
	## A fight opens on its first turn with no turn_begin of its own: its passives are due.
	_opening_due = true
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
	_layout_generation += 1
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
	## The next fight's House Money has not been seen yet.
	_house_shown = false
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
	_layout_generation += 1
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
	_fight_effects.show_effects(EffectChips.for_battle(state))
	_sync_pages(planning)
	_sync_tabs()
	_sync_plates()
	_sync_enemy_panel()
	var locked: bool = bool(unit.get("locked", false))
	var downed: bool = bool(unit.get("downed", false))
	var rerolls: int = int(unit.get("rerolls", 0))
	## All or Nothing: nothing to pick, the button throws the whole bowl.
	var whole_bowl: bool = DeepBattle.all_or_nothing(unit)
	_reroll_button.disabled = not planning or locked or downed or rerolls <= 0 or (selected.is_empty() and not whole_bowl)
	## Study's reroll is shown arriving: the button holds it back until it has been counted on.
	var lag: int = _study_lag if Time.get_ticks_msec() < _study_until else 0
	_reroll_button.text = "Reroll" if planning else "Resolving"
	_sync_pips(maxi(0, rerolls - lag) if planning else 0, maxi(2, int(unit.get("rerolls_max", 0))))
	## A Roller in the room threw the hand this turn and took the rerolls with it: the button
	## wears the Roller's own mark and name in its color, and says why on a hover.
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
		_reroll_button.tooltip_text = "All or Nothing: reroll every die  [R]" if whole_bowl else "Reroll the selected dice  [R]"
	var flips: int = int(unit.get("flips", 0))
	## Unlocking is only offered while there is something left to do with the hand.
	var spent: bool = rerolls <= 0 and flips <= 0
	_lock_button.disabled = not planning or downed or (locked and spent)
	_lock_button.text = "Unlock" if locked else "Lock in"
	_lock_button.tooltip_text = "Locked in: no rerolls or turns left to spend." if locked and spent else "Lock in your hand  [Space]"
	_flip_button.visible = str(unit.get("passive", {}).get("kind", "")) == "free_flip"
	var shift_refusal: String = _shift_refusal()
	_flip_button.disabled = not planning or locked or downed or flips <= 0 or selected.size() != 1 or not shift_refusal.is_empty()
	_flip_button.text = "Turn over" if flips > 0 or not planning else "Turned"
	_flip_button.tooltip_text = (shift_refusal.substr(0, 1).to_upper() + shift_refusal.substr(1) + ".") if not shift_refusal.is_empty() else SHIFT_TIP
	## When there is nothing left to decide, the lock button asks to be pressed.
	var waiting_on_me: bool = planning and not locked and not downed and ((rerolls <= 0 and flips <= 0) or (selected.is_empty() and not whole_bowl))
	if waiting_on_me and _lock_pulse == null:
		_lock_pulse = DeepUi.breathe(_lock_button, 0.7, 1.4)
	elif not waiting_on_me and _lock_pulse != null:
		_lock_pulse.kill()
		_lock_pulse = null
		_lock_button.modulate.a = 1.0
	if downed:
		_hint.text = "You are down. The party fights on."
	elif not planning:
		_hint.text = "Resolving…  click to hurry"
	elif locked:
		var waiting: Array = state.get("players", []).filter(func(p: Dictionary) -> bool: return not bool(p.get("locked", false)) and not bool(p.get("downed", false)))
		_hint.text = "Waiting for %s" % ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))) if not waiting.is_empty() else "Everyone is in."
	else:
		## Only what the dock cannot say otherwise: no instructions, no key hints.
		if flips > 0 and not shift_refusal.is_empty():
			_hint.text = "That die has no face of the other parity to turn to"
		elif rerolls <= 0 and flips > 0:
			_hint.text = "A turn over left: right-click a die"
		elif rerolls <= 0 and not roller.is_empty():
			_hint.text = "%s rolled for you: no rerolls this turn" % str(roller.get("name", "A creature"))
		elif whole_bowl and rerolls > 0:
			_hint.text = "All or Nothing: Reroll throws every die"
		else:
			_hint.text = ""

# --- the party: a page each, and a tab each -----------------------------------------------------

class Page extends RefCounted:
	## One player's page of the dock: their health and Resonance, their rail, their tray and
	## what their hand would do. Every player in the fight has one, built once and kept up to
	## date whether it is shown or not, so turning to it is only a matter of showing it.
	var id: String = ""
	var mine: bool = false
	var root: Control = null
	## Their face (a Roster.Portrait), in whatever mood the fight has put them in.
	var face: Control = null
	var hp_bar: VitalsRing
	var status_row: Control
	## The Resonance meter under their rail (ResonanceMeter), and the rerolls left as pips
	## on the Reroll button (the reader's own page only).
	var meter: ResonanceMeter = null
	var reroll_pips: Control = null
	var status_block: int = -1
	var resonance_box: HBoxContainer
	var resonance_value: Label
	## What resonance_value shows, as a number: its words may be Infinite.
	var resonance_shown: int = 0
	var resonance_token: int = 0
	var battery_tween: Tween
	var rail_box: HBoxContainer
	var socket_cards: Array = []
	var rail_shape: String = ""
	var birthstone_card: VBoxContainer = null
	var birthstone_key: String = ""
	var hand_title: Label
	var hint: Label
	## Puck only: which face the hand wears, under the tray's title.
	var face_chip: Label = null
	var tray_box: HBoxContainer
	var dice_views: Dictionary = {}
	var phantom_box: HBoxContainer
	var phantom_key: String = ""
	var phantom_views: Dictionary = {}
	var rolled_hand: String = ""
	var dice_settle_at: int = 0
	## Another player's page only: what they are doing, where the reader's buttons are.
	var mate_state: HBoxContainer
	var mate_key: String = ""
	var dealt_box: HBoxContainer
	var dealt_label: Label
	var turn_dealt: int = 0
	## The rail's last gem that fired this turn, for the bow drawn when the next one rings
	## with it; -1 after a fizzle or as a rail begins.
	var last_fired: int = -1
	var forecast: Dictionary = {}
	var held_forecast: Dictionary = {}
	## What another player's forecast was worked out from: "turn|hand", or "turn|held".
	var forecast_for: String = ""
	var outcomes: Dictionary = {}
	var birth_outcome: Dictionary = {}

func _all_pages() -> Array:
	return [_local_page] + _pages.values()

func _page_for(id: String) -> Page:
	return _local_page if id == local_id else _pages.get(id, null)

func _shown_owner() -> String:
	return local_id if _shown_id.is_empty() else _shown_id

func _is_shown(id: String) -> bool:
	return id == _shown_owner()

func _is_player(id: String) -> bool:
	return not id.is_empty() and not DeepBattle.player(state, id).is_empty()

func _party() -> bool:
	return state.get("players", []).size() > 1

func _seat_color(id: String) -> Color:
	## A player's color wherever the party is drawn: the map's dots, the vein's picks, their tab.
	var players: Array = state.get("players", [])
	for index in range(players.size()):
		if str(players[index].get("id", "")) == id:
			return ShaftMap.SEATS[int(players[index].get("seat", index)) % ShaftMap.SEATS.size()]
	return DeepUi.INFO

func _on_page(page: Page, work: Callable) -> void:
	## Does something on another player's page: what reads `_page` reads theirs meanwhile.
	var was: Page = _page
	_page = page
	work.call()
	_page = was

func _sync_pages(planning: bool) -> void:
	## Every player's page is kept up to date, shown or not: a tray out of sight still turns its
	## dice over as they are rerolled (silently, and drawing nothing), so the next page turned
	## to is already right. Pages of players who have left go with them.
	var present: Dictionary = {}
	for unit in state.get("players", []):
		var id: String = str(unit.get("id", ""))
		var page: Page = _page_for(id)
		if page == null:
			page = Page.new()
			page.id = id
			_build_page(page)
			_pages[id] = page
		page.id = id
		present[id] = true
		_sync_page(page, unit, planning)
	for id in _pages.keys():
		if not present.has(id):
			var gone: Page = _pages[id]
			if gone.root != null and is_instance_valid(gone.root):
				gone.root.queue_free()
			_pages.erase(id)
	if not present.has(_shown_owner()):
		_shown_id = ""
	_apply_shown()

func _sync_page(page: Page, unit: Dictionary, planning: bool) -> void:
	var was: Page = _page
	_page = page
	## While the dice are still tumbling nothing on the rail is lit: the forecast is known the
	## instant the roll is, and a gem that came on a beat before its dice landed gave the
	## answer away. The rail is told again the moment they settle.
	var rolled: String = ",".join(unit.get("hand", []).map(func(r: Dictionary) -> String: return "%s:%d:%s" % [str(r.get("die_id", "")), int(r.get("value", 0)), str(r.get("rerolls", 0))]))
	page.face.key = str(unit.get("character", ""))
	page.face.tooltip_text = "%s · %s" % [str(unit.get("name", "")), DeepContent.character_title(page.face.key)] if not page.mine else "You, as %s" % DeepContent.character_title(page.face.key)
	if rolled != _rolled_hand:
		_rolled_hand = rolled
		if not _headless and is_inside_tree() and planning:
			## Their eyes go down to the dice for as long as they tumble.
			_react(page.id, "rolling", DiceView.SPIN_SECONDS + 0.4)
			_dice_settle_at = Time.get_ticks_msec() + int(DiceView.SPIN_SECONDS * 1000.0) + 60
			var settling_hand: String = rolled
			var settling: Page = page
			get_tree().create_timer(DiceView.SPIN_SECONDS + 0.09).timeout.connect(func() -> void:
				if is_instance_valid(self) and not state.is_empty() and settling.rolled_hand == settling_hand:
					settling.dice_settle_at = 0
					_sync())
	if not page.mine:
		_mate_forecast(page, unit, planning, rolled)
	_sync_vitals(unit)
	## While a turn resolves the rail's own events count the Resonance up, sparks and all.
	if planning and (_battery_tween == null or not _battery_tween.is_running()):
		_show_resonance(int(forecast.get("totals", {}).get("resonance", 0)))
	elif not planning and (_headless or str(state.get("phase", "")) != "resolving"):
		_show_resonance(int(unit.get("resonance", 0)))
	_sync_rail(unit, planning)
	_sync_tray(unit, planning)
	_sync_streak(page, unit)
	_sync_face(page, unit)
	if not page.mine:
		_sync_mate_state(page, unit, planning)
	_show_mood(page.id)
	_page = was

func _mate_forecast(page: Page, unit: Dictionary, planning: bool, rolled: String) -> void:
	## Another player's "this hand would", read here off the fight as it stands, the same way
	## their own screen reads it for them: again only when their hand changes, and held still
	## through a resolving turn as the reader's own is.
	var turn: String = str(int(state.get("turn", 0)))
	if planning:
		var key: String = "%s|%s|%d" % [turn, rolled, unit.get("rail", []).size()]
		if page.forecast_for != key:
			page.forecast_for = key
			page.forecast = DeepBattle.forecast(state, page.id)
			page.held_forecast = page.forecast
	elif not page.forecast_for.begins_with(turn + "|"):
		page.forecast_for = turn + "|held"
		page.forecast = DeepBattle.forecast(state, page.id)
		page.held_forecast = page.forecast

func _sync_mate_state(page: Page, unit: Dictionary, planning: bool) -> void:
	## Another player's page has no buttons: in their place, whether they are still choosing or
	## locked in, and how many rerolls they have left to spend.
	var who: String = str(unit.get("name", ""))
	page.hand_title.text = "%s's hand" % who
	page.hint.text = "" if planning else "Resolving…"
	var downed: bool = bool(unit.get("downed", false))
	var locked: bool = bool(unit.get("locked", false))
	var away: bool = not bool(unit.get("connected", true))
	var rerolls: int = int(unit.get("rerolls", 0))
	var key: String = "%s|%s|%s|%s|%d" % [planning, downed, locked, away, rerolls]
	if key == page.mate_key:
		return
	page.mate_key = key
	DeepUi.clear(page.mate_state)
	if downed:
		_mate_block(page.mate_state, "skull", "Down", DeepUi.BAD, 170, "%s is down. The party fights on." % who)
		return
	if planning:
		_mate_block(page.mate_state, "reroll", "%s left" % DeepUi.plural(rerolls, "reroll", "rerolls"), DeepUi.INFO if rerolls > 0 else DeepUi.DIM, 150,
			"%s has %s left this turn." % [who, DeepUi.plural(rerolls, "reroll", "rerolls")])
	if away:
		_mate_block(page.mate_state, "wifi", "Away", DeepUi.MUTED, 170, "%s has lost the connection." % who)
	elif locked or not planning:
		_mate_block(page.mate_state, "check", "Locked in", DeepUi.GOOD, 170, "%s has locked this hand in." % who)
	else:
		_mate_block(page.mate_state, "hourglass", "Choosing", DeepUi.ACCENT, 170, "%s is still choosing what to reroll." % who)

func _mate_block(parent: Node, glyph: String, words: String, tone: Color, width: float, tip: String) -> void:
	## A plate the size of the reader's own button in the same place, saying instead of doing.
	var block := PanelContainer.new()
	var style := DeepUi.ledger(Color(tone.darkened(0.7), 1.0), Color(tone, 0.7), 8, 6, 2, 3)
	block.add_theme_stylebox_override("panel", style)
	block.custom_minimum_size = Vector2(width, BUTTONS_ROW)
	block.mouse_filter = Control.MOUSE_FILTER_PASS
	block.tooltip_text = tip
	parent.add_child(block)
	var row := DeepUi.hbox(block, 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(row, glyph, 16, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var said := DeepUi.label(row, words, 15, tone.lightened(0.2))
	said.add_theme_font_override("font", DeepUi.bold_font())

func _apply_shown() -> void:
	## Only the page being looked at is shown, and the dock wears whose it is.
	var shown: Page = _page_for(_shown_owner())
	if shown == null:
		shown = _local_page
	for page in _all_pages():
		if page.root != null and is_instance_valid(page.root):
			page.root.visible = page == shown
	if not _party():
		_dress_dock(DeepUi.LEDGER_LINE, false)
	elif shown == _local_page:
		_dress_dock(DeepUi.ACCENT, false)
	else:
		_dress_dock(_seat_color(shown.id), true)

func _show_page(id: String) -> void:
	## Puts a player's page in the dock. The turn does this by itself (whoever's rail is
	## firing, then the reader again for the creatures and the next turn); a tab does it in
	## between, for as long as the turn leaves it.
	if id.is_empty():
		id = local_id
	if id == _shown_owner() or (id != local_id and not _pages.has(id)):
		return
	_shown_id = "" if id == local_id else id
	_preview_count(-1)
	_apply_shown()
	if not state.is_empty():
		_sync_tabs()
	_reveal_page(_page_for(id))
	_edge_light(_seat_tone(id), _tab_anchor(id))

func _seat_tone(id: String) -> Color:
	## A player's color in the party's own effects: gold for the reader, their seat for anyone else.
	return DeepUi.ACCENT if id == local_id else _seat_color(id)

func _reveal_page(page: Page) -> void:
	## A page coming up: it fades in over a breath, and its stones and then its dice give a
	## small jolt one after another, left to right, so the eye goes to whose rail is up now.
	if _headless or page == null or page.root == null or not is_instance_valid(page.root) or not is_inside_tree():
		return
	var root: Control = page.root
	root.modulate.a = 0.3
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	var things: Array = []
	for card in page.socket_cards:
		if card is Control and is_instance_valid(card) and not bool((card as Control).get_meta("badge", false)):
			things.append(card)
	if page.birthstone_card != null and is_instance_valid(page.birthstone_card):
		things.append(page.birthstone_card)
	for id in page.dice_views:
		var view: Variant = page.dice_views[id]
		if view is Control and is_instance_valid(view):
			things.append(view)
	var at: float = 0.0
	for thing in things:
		_later_do(at, _jolt.bind(weakref(thing)))
		at += 0.028

func _jolt(held: WeakRef) -> void:
	var control: Control = held.get_ref() as Control
	if control != null and control.is_visible_in_tree():
		DeepUi.spring(control, 0.1, 3.0, 0.35)

func _edge_light(tone: Color, from: Control) -> void:
	## The dock's top edge lights up in the color of whoever's page has just come up, running
	## out both ways from their tab and fading as it goes.
	if _headless or ScreenFx.calm or _dock == null or not is_inside_tree():
		return
	if _edge_texture == null:
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_edge_texture = GradientTexture2D.new()
		_edge_texture.gradient = ramp
		_edge_texture.width = 256
		_edge_texture.height = 1
	var dock: Rect2 = _dock.get_global_rect()
	var centre: float = (from.get_global_rect().get_center().x if from != null else dock.get_center().x) - _hud.global_position.x
	var y: float = dock.position.y - _hud.global_position.y
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var strokes: Array = []
	for thick in [5.0, 26.0]:
		var stroke := TextureRect.new()
		stroke.texture = _edge_texture
		stroke.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stroke.stretch_mode = TextureRect.STRETCH_SCALE
		stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stroke.material = add
		stroke.modulate = Color(tone.lightened(0.35), 0.0)
		_hud.add_child(stroke)
		strokes.append(stroke)
	var line: TextureRect = strokes[0]
	var bloom: TextureRect = strokes[1]
	var reach: float = dock.size.x * 0.95
	var tween := line.create_tween()
	tween.tween_method(func(t: float) -> void:
		var half: float = lerpf(40.0, reach, 1.0 - pow(1.0 - t, 3.0))
		var alpha: float = (1.0 - t) * minf(1.0, t * 6.0)
		line.position = Vector2(centre - half, y - 2.5)
		line.size = Vector2(half * 2.0, 5.0)
		line.modulate.a = alpha * 0.95
		bloom.position = Vector2(centre - half * 0.8, y - 13.0)
		bloom.size = Vector2(half * 1.6, 26.0)
		bloom.modulate.a = alpha * 0.3, 0.0, 1.0, 0.5)
	tween.tween_callback(bloom.queue_free)
	tween.tween_callback(line.queue_free)

func _baton(from: Control, to: Control, tone: Color) -> void:
	## The turn passing from one rail to the next: a mote of light from the tab that has just
	## fired arcs to the one firing now, and that tab jumps as it lands.
	if _headless or to == null or not is_inside_tree():
		return
	var held: WeakRef = weakref(to)
	var land := func() -> void:
		var tab: Control = held.get_ref() as Control
		if tab == null:
			return
		DeepUi.spring(tab, 0.16, 4.0, 0.45)
		if not ScreenFx.calm:
			DeepUi.burst(self, _center_of(tab), tone, 16, 130.0, 0.5)
	if from == null or from == to or ScreenFx.calm:
		land.call()
		return
	var a: Vector2 = _center_of(from)
	var b: Vector2 = _center_of(to)
	var top: Vector2 = (a + b) * 0.5 + Vector2(0, -36.0 - absf(b.x - a.x) * 0.12)
	var mote := TextureRect.new()
	mote.texture = DeepUi.glow_texture()
	mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mote.size = Vector2(34, 34)
	mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mote.modulate = tone.lightened(0.4)
	mote.z_index = 46
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mote.material = add
	add_child(mote)
	mote.position = a - mote.size * 0.5
	mote.pivot_offset = mote.size * 0.5
	var tween := mote.create_tween()
	tween.tween_method(func(t: float) -> void:
		var eased: float = t * t * (3.0 - 2.0 * t)
		mote.position = a.lerp(top, eased).lerp(top.lerp(b, eased), eased) - mote.size * 0.5
		mote.scale = Vector2.ONE * lerpf(0.7, 1.15, sin(PI * t)), 0.0, 1.0, 0.3)
	tween.tween_callback(land)
	tween.tween_callback(mote.queue_free)

func _tab_flash(id: String, tone: Color) -> void:
	var tab: SeatTab = _tab_of(id)
	if tab != null:
		tab.flash(tone)

func _pick_tab(id: String) -> void:
	if (local_id if id.is_empty() else id) == _shown_owner():
		return
	DeepAudio.play("ui_tab", {"volume": 0.6})
	_show_page(id)

func _player_effects(unit: Dictionary) -> Array:
	## A player's buffs and troubles over their tab. Block rides the health bars instead.
	## A player's passive is not a chip: it is said on their face's plate and their tab's.
	return EffectChips.for_player(unit, state).filter(func(e: Dictionary) -> bool: return str(e.key) != "block")

static func passive_words(unit: Dictionary) -> String:
	## "Second Wind: heal Resonance for each unused reroll...", or "" for none.
	var passive: Dictionary = unit.get("passive", {})
	if str(passive.get("text", "")).is_empty():
		return ""
	return "%s: %s" % [str(passive.get("name", DeepContent.character_title(str(unit.get("character", ""))))), str(passive.text)]

func _seat_status(unit: Dictionary) -> Array:
	## What a player is doing, as the one mark on their tab: [glyph, tone, words].
	var id: String = str(unit.get("id", ""))
	## Down is said by the whole tab going grey, not by a mark on it.
	if bool(unit.get("downed", false)):
		return ["", DeepUi.DIM, "Down"]
	if not bool(unit.get("connected", true)):
		return ["wifi", DeepUi.DIM, "Away"]
	match str(state.get("phase", "")):
		"planning":
			if bool(unit.get("locked", false)):
				return ["check", DeepUi.GOOD, "Locked in"]
			if Time.get_ticks_msec() < int(_rerolled_at.get(id, -REROLL_SHOWN_MS)) + REROLL_SHOWN_MS:
				return ["reroll", DeepUi.INFO, "Rerolling"]
			var left: int = int(unit.get("rerolls", 0))
			return ["hourglass", DeepUi.MUTED, "Choosing · %s left" % DeepUi.plural(left, "reroll", "rerolls")]
		"resolving":
			if id == _firing_id:
				return ["bolt", DeepUi.ACCENT_HI, "Firing"]
			if _fired.has(id):
				return ["check", DeepUi.MUTED, "Fired this turn"]
			return ["hourglass", DeepUi.DIM, "Waiting to fire"]
	return ["", DeepUi.MUTED, ""]

func _sync_tabs() -> void:
	## A tab a player, the reader's first and the rest in the order their rails fire, each with
	## that player's buffs over it. A player alone has no one to turn to: their tab is put
	## away and only the buffs stay, along the top of the dock.
	if _tab_bar == null:
		return
	var players: Array = state.get("players", [])
	var party: bool = players.size() > 1
	var resolving: bool = str(state.get("phase", "")) == "resolving"
	var turn: int = int(state.get("turn", 0))
	var present: Dictionary = {}
	var at: int = 1
	for index in range(players.size()):
		var unit: Dictionary = _shown(players[index])
		var id: String = str(unit.get("id", ""))
		var tab: SeatTab = _tab_of(id)
		if tab == null:
			tab = SeatTab.new(false)
			tab.picked.connect(_pick_tab.bind(id))
			tab.inspected.connect(func() -> void:
				var member: Dictionary = DeepBattle.player(state, id)
				if not member.is_empty():
					Inspector.member(member))
			_tab_bar.add_child(tab)
			_tabs[id] = tab
			if not _headless:
				DeepUi.pop_in(tab)
		present[id] = true
		if id != local_id:
			_tab_bar.move_child(tab, at)
			at += 1
		## A reroll spent, or a hand locked in, is seen landing on the tab.
		var rerolls: int = int(unit.get("rerolls", 0))
		var before: String = str(_seen_rerolls.get(id, ""))
		if before.begins_with("%d|" % turn) and int(before.get_slice("|", 1)) > rerolls and str(state.get("phase", "")) == "planning":
			_rerolled_at[id] = Time.get_ticks_msec()
			tab.ping()
			if not _headless and is_inside_tree():
				get_tree().create_timer(float(REROLL_SHOWN_MS) / 1000.0 + 0.05).timeout.connect(func() -> void:
					if is_instance_valid(self) and not state.is_empty():
						_sync_tabs())
		_seen_rerolls[id] = "%d|%d" % [turn, rerolls]
		var locked: bool = bool(unit.get("locked", false))
		if locked and not bool(_seen_locked.get(id, true)):
			tab.ping()
		_seen_locked[id] = locked
		var character: String = DeepContent.character_title(str(unit.get("character", "")))
		tab.update(unit, character, _seat_color(id), party and _is_shown(id), _seat_status(unit), index + 1 if resolving and party else 0, _player_effects(unit), party)
		tab.portrait.mood = _mood_of(id)
	_tab_bar.move_child(_my_tab, 0)
	for id in _tabs.keys():
		if not present.has(id):
			if is_instance_valid(_tabs[id]):
				_tabs[id].queue_free()
			_tabs.erase(id)
	## Everyone else is in and the reader is not: their tab calls them back, and says so once.
	var reader: Dictionary = me()
	var calling: bool = party and str(state.get("phase", "")) == "planning" and not reader.is_empty() \
		and not bool(reader.get("locked", false)) and not bool(reader.get("downed", false)) \
		and players.all(func(p: Dictionary) -> bool: return str(p.get("id", "")) == local_id or bool(p.get("locked", false)) or bool(p.get("downed", false)) or not bool(p.get("connected", true)))
	_my_tab.face.calling = calling
	if calling and _called_turn != turn:
		_called_turn = turn
		_float_at(_my_tab.face, "The party is waiting on you", DeepUi.ACCENT_HI, 15)
	## Alone or not, the reader's chips run over their tab the same way.
	_my_tab.chips.custom_minimum_size.x = 0.0 if party else maxf(240.0, size.x - 300.0 - left_inset)

func _tab_of(id: String) -> SeatTab:
	if id == local_id:
		return _my_tab
	var tab: Variant = _tabs.get(id, null)
	return tab as SeatTab if tab != null and is_instance_valid(tab) else null

func _tab_anchor(id: String) -> Control:
	## A player's tab, for what is said about them while their page is not the one up; null
	## when there is none on screen (a player alone).
	var tab: SeatTab = _tab_of(id)
	return tab.face if tab != null and tab.face.is_visible_in_tree() else null

func _vital_anchor(id: String) -> Control:
	## Where what happens to a player's health is said: their health bar while their page is
	## up, their tab while it is not.
	var page: Page = _page_for(id)
	if page != null and _is_shown(id) and page.hp_bar != null:
		return page.hp_bar
	return _tab_anchor(id)

func _shown_anchor(control: Control) -> Control:
	## A control on a page that is not up stands for nothing on the screen: what would be said
	## over it is said over its player's tab instead.
	if control == null or not is_instance_valid(control) or control.is_visible_in_tree() or not is_visible_in_tree():
		return control
	var at: Node = control
	while at != null and at != _dock:
		if at.has_meta("page"):
			var page: Page = at.get_meta("page")
			var tab: Control = _tab_anchor(local_id if page.mine else page.id)
			return tab if tab != null else control
		at = at.get_parent()
	return control

class SeatTab extends VBoxContainer:
	## One player over the dock: their buffs and troubles, and under them the tab that puts
	## their page in the dock. The reader's own is first, edged in gold and marked as theirs;
	## everyone else's wears their seat color.
	signal picked
	signal inspected
	const BG := Color(0.045, 0.056, 0.082, 0.9)
	const BG_UP := Color(0.06, 0.075, 0.105, 1.0)
	var mine: bool = false
	var chips: EffectChips.Row
	var face: TabFace
	## Their face, ringed in their seat's color, in the same mood as on their page.
	var portrait: Roster.Portrait
	var _order: Label
	var _name: Label
	var _bar: DeepUi.Bar
	var _status: TextureRect
	var _status_key: String = ""
	var _style_key: String = ""
	var _was_up: bool = false
	## The reroll mark turns for as long as the player is rerolling.
	var _spin: Tween = null
	func _init(is_mine: bool) -> void:
		mine = is_mine
		add_theme_constant_override("separation", 5)
		alignment = BoxContainer.ALIGNMENT_END
		size_flags_vertical = Control.SIZE_SHRINK_END
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips = EffectChips.Row.new(18)
		add_child(chips)
		face = TabFace.new()
		face.custom_minimum_size = Vector2(150, 0)
		face.gui_input.connect(_face_input)
		add_child(face)
		var row := DeepUi.hbox(face, 7)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_order = DeepUi.label(row, "", 12, DeepUi.MUTED)
		_order.visible = false
		portrait = Roster.Portrait.new("", Vector2(30, 30))
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		if mine:
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", DeepUi.capsule(badge, DeepUi.ACCENT, DeepUi.ACCENT, 1, 7, 0))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(badge)
			var you := DeepUi.label(badge, "YOU", 10, DeepUi.INK)
			you.add_theme_font_override("font", DeepUi.caps_font())
		var words := DeepUi.vbox(row, 4)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name = DeepUi.label(words, "", 14, DeepUi.PAPER)
		_name.clip_text = true
		_name.custom_minimum_size.x = 48
		_bar = DeepUi.bar(words, 5.0)
		_bar.warn = true
		_bar.custom_minimum_size = Vector2(64, 5)
		_status = DeepUi.icon(row, "hourglass", 18, DeepUi.MUTED)
		_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _face_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()
			face.accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not mine:
			inspected.emit()
			face.accept_event()
	func update(unit: Dictionary, character: String, seat: Color, up: bool, status: Array, order: int, effects: Array, party: bool) -> void:
		chips.show_effects(effects)
		## Alone, the tab is kept but unseen, so the chips over it stand where they stand in
		## a party and nothing moves when someone joins.
		face.visible = true
		face.modulate.a = 1.0 if party else 0.0
		face.mouse_filter = Control.MOUSE_FILTER_STOP if party else Control.MOUSE_FILTER_IGNORE
		if not party:
			return
		var who: String = str(unit.get("name", ""))
		_name.text = who
		portrait.key = str(unit.get("character", ""))
		var max_hp: int = maxi(1, int(unit.get("max_hp", 1)))
		_bar.set_values(float(unit.get("hp", 0)) / float(max_hp), "", float(unit.get("block", 0)) / float(max_hp))
		## As the turn starts resolving, the firing order is counted out along the tabs.
		if order > 0 and not _order.visible and not DeepUi.headless():
			var count := _order.create_tween()
			count.tween_interval(0.08 * float(order))
			count.tween_callback(func() -> void: DeepUi.pulse(_order, 1.8, 0.3))
		_order.visible = order > 0
		_order.text = str(order)
		_order.add_theme_color_override("font_color", seat)
		var key: String = "%s|%s" % [up, seat.to_html()]
		if key != _style_key:
			var rising: bool = up and not _was_up and not _style_key.is_empty()
			_style_key = key
			face.add_theme_stylebox_override("panel", _style(up, seat))
			portrait.ring = seat
			face.stripe = DeepUi.ACCENT if mine else seat
			face.up = up
			face.queue_redraw()
			if rising:
				DeepUi.pulse(face, 1.05, 0.28)
		_was_up = up
		var glyph: String = str(status[0])
		var status_key: String = "%s|%s" % [glyph, (status[1] as Color).to_html()]
		if status_key != _status_key:
			var changed: bool = not _status_key.is_empty()
			_status_key = status_key
			_status.visible = not glyph.is_empty()
			if not glyph.is_empty():
				_status.texture = GemIcons.texture(glyph, GemIcons.baked_size(27.0))
				_status.modulate = status[1]
				if changed:
					_status_changed(glyph, status[1])
			_spin_status(glyph == "reroll")
		face.firing = glyph == "bolt"
		var lines: Array = [who if character.is_empty() else "%s · %s" % [who, character]]
		if not str(status[2]).is_empty():
			lines.append(str(status[2]))
		var passive: Dictionary = unit.get("passive", {})
		if not str(passive.get("text", "")).is_empty():
			lines.append("%s: %s" % [str(passive.get("name", character)), str(passive.text)])
		lines.append("Your rail and dice." if mine else "Click to see their rail and dice. Right-click for their bag.")
		face.tooltip_text = "\n".join(lines)
		## A player who is down is greyed out, tab, face and all: that is the whole mark.
		var down: bool = bool(unit.get("downed", false))
		face.modulate = Color(0.55, 0.57, 0.62, 0.85) if down else Color.WHITE
		chips.modulate = Color(0.55, 0.57, 0.62, 0.85) if down else Color.WHITE
	func _style(up: bool, seat: Color) -> StyleBoxFlat:
		## The tab that is up is the dock's own color and lies over its edge, so the two read
		## as one piece; the rest sit behind it, darker.
		var edge: Color = DeepUi.ACCENT if mine else seat
		var style := DeepUi.ledger(DeepUi.LEDGER_FILL if up else BG, edge if up else Color(edge, 0.55), 12, 8, 3 if up else 2, 0)
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.border_width_bottom = 0
		style.content_margin_left = 9
		style.content_margin_right = 10
		style.content_margin_top = 10 if up else 6
		style.content_margin_bottom = 7
		if up:
			style.expand_margin_bottom = 3
		return style
	func _status_changed(glyph: String, tone: Color) -> void:
		## A new mark on the tab pops as it lands; locking in, starting to fire and going down
		## each throw a few sparks of their own color, so a glance along the tabs catches them.
		if DeepUi.headless() or not face.is_visible_in_tree():
			return
		DeepUi.pulse(_status, 1.55, 0.36)
		if glyph in ["check", "bolt", "skull"] and tone != DeepUi.MUTED and not ScreenFx.calm:
			DeepUi.burst(face, _status.get_global_rect().get_center() - face.global_position, tone, 12, 110.0, 0.45, 4.0)
	func _spin_status(on: bool) -> void:
		if on == (_spin != null):
			return
		if _spin != null:
			_spin.kill()
			_spin = null
			_status.rotation = 0.0
		if on and not DeepUi.headless():
			_status.pivot_offset = _status.custom_minimum_size * 0.5
			_spin = _status.create_tween().set_loops()
			_spin.tween_property(_status, "rotation", TAU, 0.7).from(0.0)
	func brace(share: float) -> void:
		## What a creature's blow being counted would take off them, pulsing on their health line.
		_bar.preview = share
	func ping() -> void:
		## A reroll spent or a hand locked in: the player's mark jumps.
		if not DeepUi.headless():
			DeepUi.pulse(portrait, 1.3, 0.35)
	func flash(tone: Color) -> void:
		## Guarded or healed while their page is not up: the tab washes over in that color and
		## its health line swells.
		if DeepUi.headless() or not face.visible:
			return
		face.self_modulate = Color.WHITE.lerp(Color(tone.r * 1.9, tone.g * 1.9, tone.b * 1.9), 0.55)
		face.create_tween().tween_property(face, "self_modulate", Color.WHITE, 0.45)
		DeepUi.pulse(_bar, 1.2, 0.3)
	func hurt() -> void:
		if DeepUi.headless() or not face.visible:
			return
		DeepUi.shake(face, 8.0, 0.35)
		var tween := face.create_tween()
		face.self_modulate = Color(1.6, 0.6, 0.6)
		tween.tween_property(face, "self_modulate", Color.WHITE, 0.4)

class TabFace extends PanelContainer:
	## A tab itself: a stripe of its player's color along the top, a lift under the pointer,
	## and a glow round it that breathes while their rail is firing, or, slower and gold, on
	## the reader's own tab while the rest of the party waits on them. Both are held steady
	## for anyone who asked for fewer flashes.
	var stripe: Color = DeepUi.ACCENT
	var up: bool = false:
		set(value):
			up = value
			queue_redraw()
	var firing: bool = false:
		set(value):
			if value == firing:
				return
			firing = value
			_clock = 0.0
			_awake()
	var calling: bool = false:
		set(value):
			if value == calling:
				return
			calling = value
			_awake()
	var _hovered: bool = false
	var _clock: float = 0.0
	var _halo: StyleBoxFlat
	var _lift: StyleBoxFlat
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		## The glow is the tab's own outline drawn again a little outside it, cut the same way.
		_halo = DeepUi.flat(Color(0, 0, 0, 0), Color.WHITE, 13, 0, 2)
		_halo.draw_center = false
		_halo.border_width_bottom = 0
		_halo.corner_radius_bottom_left = 0
		_halo.corner_radius_bottom_right = 0
		_halo.set_expand_margin_all(3)
		_halo.expand_margin_bottom = 0
		_halo.shadow_size = 8
		_lift = DeepUi.flat(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 12, 0)
		_lift.corner_radius_bottom_left = 0
		_lift.corner_radius_bottom_right = 0
		mouse_entered.connect(func() -> void:
			_hovered = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hovered = false
			queue_redraw())
		_awake()
	func _awake() -> void:
		set_process(firing or calling)
		queue_redraw()
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var lit: bool = _hovered and not up
		if lit and _lift != null:
			draw_style_box(_lift, Rect2(Vector2.ZERO, size))
		if (firing or calling) and _halo != null:
			var glow: float
			var tone: Color = stripe
			if firing:
				glow = 0.75 if ScreenFx.calm else 0.5 + 0.4 * sin(_clock * 5.0)
			else:
				tone = DeepUi.ACCENT_HI
				glow = 0.6 if ScreenFx.calm else 0.25 + 0.5 * (0.5 + 0.5 * sin(_clock * 2.6))
			_halo.border_color = Color(tone, glow)
			_halo.shadow_color = Color(tone, glow * 0.35)
			draw_style_box(_halo, Rect2(Vector2.ZERO, size))

func _sync_vitals(unit: Dictionary) -> void:
	## The health bar and the block beside it, as they should read: a guard or a heal still
	## being counted out has not arrived yet.
	var shown: Dictionary = _shown(unit)
	var ratio: float = float(shown.hp) / float(maxi(1, int(shown.max_hp)))
	_hp_bar.set_values(ratio, "%s / %s" % [DeepUi.number(int(shown.hp)), DeepUi.number(int(shown.max_hp))], float(shown.block) / float(maxi(1, int(shown.max_hp))),
		DeepUi.number(int(shown.block)) if int(shown.block) > 0 else "")
	if _screen_fx != null and str(unit.get("id", "")) == local_id:
		_screen_fx.danger = clampf((0.3 - ratio) / 0.3, 0.0, 1.0) if not bool(shown.get("downed", false)) else 0.0
	## Block gained jumps the badge and flares along the arc (the ring does both).
	_status_block = int(shown.block)

func _shown(unit: Dictionary) -> Dictionary:
	## A unit as its bars should read: the truth, unless a count is still on its way to it.
	var id: String = str(unit.get("id", ""))
	## The Gambler's pot reads what the coins have carried onto the table so far.
	if _pot_held.has(id) or _house_due(unit, state):
		unit = unit.duplicate()
		unit.pot = int(_pot_held.get(id, 0))
	if not _held.has(id):
		return unit
	var held: Dictionary = _held[id]
	if Time.get_ticks_msec() > int(held.until) or str(state.get("phase", "")) == "planning":
		_held.erase(id)
		return unit
	var copy: Dictionary = unit.duplicate()
	copy.hp = clampi(int(held.hp), 0, maxi(int(unit.get("max_hp", held.hp)), int(unit.hp)))
	copy.block = maxi(0, int(held.block))
	return copy

func _hold_vitals(effects: Array, by: String = "") -> void:
	## Before a count: what these effects took off a creature, or gave the player, goes back
	## on the bars until the blow, the guard or the heal is seen to land. A unit an earlier
	## count is still holding already reads as it was before both, and only waits longer.
	## `by` is whose rail it was: a Riposte's guard from these blows is held too, and comes in
	## all at once as its swell is flown to the bar.
	var moved: Dictionary = {}
	_vital_moves(effects, moved)
	var parried: int = _parried(effects) if not by.is_empty() else 0
	if parried > 0:
		_vital_move(moved, by, 0, -parried)
	_hold_moves(moved)

func _hold_parry(effects: Array, by: String) -> void:
	## Only a Riposte's guard, for blows that are not counted first.
	var parried: int = _parried(effects)
	if parried > 0:
		var moved: Dictionary = {}
		_vital_move(moved, by, 0, -parried)
		_hold_moves(moved)

func _hold_moves(moved: Dictionary) -> void:
	for id in moved:
		var unit: Dictionary = DeepBattle.player(state, str(id)) if _is_player(str(id)) else DeepBattle.enemy(state, str(id))
		if unit.is_empty():
			continue
		var change: Array = moved[id]
		if _held.has(id):
			_held[id].landings = int(_held[id].landings) + int(change[2])
			_held[id].until = Time.get_ticks_msec() + HELD_MS
			continue
		_held[id] = {"hp": int(unit.hp) + int(change[0]), "block": int(unit.get("block", 0)) + int(change[1]),
			"landings": int(change[2]), "until": Time.get_ticks_msec() + HELD_MS}

func _vital_moves(effects: Array, into: Dictionary) -> void:
	## What each landing will move: [health back, block back, landings], by who it lands on.
	for effect in effects:
		if not effect is Dictionary:
			continue
		match str(effect.get("kind", "")):
			"damage":
				for hit in [effect] + effect.get("splash", []):
					var who: String = str(hit.get("target", effect.get("target", ""))) if hit is Dictionary else ""
					if _creature(who) != null:
						_vital_move(into, who, int(hit.get("hp_loss", 0)), int(hit.get("absorbed", 0)))
			"appraise", "invert_previous":
				_vital_moves(effect.get("hits", []), into)
			"block":
				if _is_player(str(effect.get("target", ""))):
					_vital_move(into, str(effect.target), 0, -int(effect.get("amount", 0)))
			"heal", "revive":
				if _is_player(str(effect.get("target", ""))):
					_vital_move(into, str(effect.target), -int(effect.get("healed", effect.get("amount", 0))), 0)
		_vital_moves(effect.get("poison_spread", []), into)

static func _parried(effects: Array) -> int:
	## The guard a Riposte raised off these blows, every hit of them.
	var total: int = 0
	for effect in effects:
		if effect is Dictionary and str(effect.get("kind", "")) == "damage":
			for hit in [effect] + effect.get("splash", []):
				if hit is Dictionary:
					total += maxi(0, int(hit.get("riposte", 0)))
	return total

static func _vital_move(into: Dictionary, id: String, hp: int, block: int) -> void:
	var change: Array = into.get(id, [0, 0, 0])
	into[id] = [int(change[0]) + hp, int(change[1]) + block, int(change[2]) + 1]

func _land_vitals(id: String, hp: int, block: int) -> void:
	## A blow, a guard or a heal has landed: the bar it was held on moves by that much, and
	## lets go of it once the last one it was waiting for is in.
	if not _held.has(id):
		return
	var held: Dictionary = _held[id]
	held.hp = int(held.hp) - hp
	held.block = int(held.block) - block
	held.landings = int(held.landings) - 1
	if int(held.landings) <= 0:
		_held.erase(id)
	if _is_player(id):
		## That player's bars: on their page, and on their tab; and their face, which the
		## blow may have taken down a step.
		var unit: Dictionary = DeepBattle.player(state, id)
		var page: Page = _page_for(id)
		if page != null:
			_on_page(page, _sync_vitals.bind(unit))
		_sync_tabs()
		_show_mood(id)
	else:
		## Only the plate it landed on: the others have not moved.
		_sync_plates(id)

func _mood_of(id: String) -> String:
	## The face a player wears right now: down once the blow that downed them has landed, the
	## fight's end when it is won, a passing face while one lasts, and otherwise what their
	## health says, as the bars read it.
	var unit: Dictionary = DeepBattle.player(state, id)
	if unit.is_empty():
		return "idle"
	var shown: Dictionary = _shown(unit)
	var hp: int = int(shown.get("hp", 0))
	if bool(unit.get("downed", false)) and hp <= 0:
		return "downed"
	if _won:
		return "victory"
	var passing: Array = _passing.get(id, [])
	if not passing.is_empty() and Time.get_ticks_msec() < int(passing[1]):
		return str(passing[0])
	## On Fire: the face of a man on a run of luck, for as long as it lasts.
	if int(unit.get("streak", 0)) >= 3:
		return "victory"
	return Roster.resting_mood({"hp": maxi(1, hp), "max_hp": int(shown.get("max_hp", 1))})

func _show_mood(id: String) -> void:
	## A player's face, the same on their page and on their tab.
	var mood: String = _mood_of(id)
	var page: Page = _page_for(id)
	if page != null and page.face != null:
		page.face.mood = mood
	var tab: SeatTab = _tab_of(id)
	if tab != null:
		tab.portrait.mood = mood

func _react(id: String, mood: String, seconds: float) -> void:
	## A passing face: a flinch, eyes on the dice, a Birthstone going off. It holds for its
	## moment and then gives way to whatever their health says by then.
	if not _is_player(id):
		return
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	_passing[id] = [mood, until]
	_show_mood(id)
	if _headless or not is_inside_tree():
		return
	## On their page the plate moves with the face: it rocks with a flinch, and jumps as their
	## Birthstone goes off.
	var page: Page = _page_for(id)
	if page != null and page.face != null and page.face.is_visible_in_tree() and _mood_of(id) == mood:
		page.face.pivot_offset = page.face.size * 0.5
		if mood == "wince":
			DeepUi.shake(page.face, 7.0, 0.32)
		elif mood == "birthstone":
			DeepUi.spring(page.face, 0.08, 3.0, 0.5)
	get_tree().create_timer(seconds + 0.03).timeout.connect(func() -> void:
		if is_instance_valid(self) and not state.is_empty() and int(_passing.get(id, [mood, 0])[1]) == until:
			_passing.erase(id)
			_show_mood(id))

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

func _show_resonance(value: int, page: Page = null) -> void:
	## A page's Resonance count: the one being drawn on, unless one is named.
	var on: Page = page if page != null else _page
	on.resonance_token += 1
	on.resonance_shown = value
	if on.meter != null and is_instance_valid(on.meter):
		on.meter.set_value(value)
	else:
		on.resonance_value.text = DeepUi.number(value)

func _charge_resonance(amount: int) -> void:
	## The battery empties into the counter at turn start; never one particle per stack. Only
	## the reader's own battery is played out like this.
	var page: Page = _local_page
	if page.battery_tween != null and page.battery_tween.is_valid():
		page.battery_tween.kill()
	if _headless:
		_show_resonance(amount, page)
		return
	_show_resonance(0, page)
	var token: int = page.resonance_token
	DeepAudio.from(page.resonance_box, "resonance", {"volume": 0.8, "pitch": 0.9})
	_float_at(page.resonance_box, "+%s Charged" % DeepUi.number(amount), DeepUi.ACCENT_HI, 20)
	DeepUi.burst(self, _center_of(page.resonance_box), DeepUi.ACCENT_HI, 20, 100.0, 0.55)
	page.battery_tween = create_tween()
	page.battery_tween.tween_method(func(value: float) -> void:
		if token == page.resonance_token and page.meter != null and is_instance_valid(page.meter):
			page.meter.set_value(int(round(value)), false), 0.0, float(amount), 0.6)
	page.battery_tween.tween_callback(func() -> void:
		if token == page.resonance_token:
			_show_resonance(amount, page)
			DeepUi.pulse(page.resonance_box, 1.2, 0.25))

func _resonance_flight(page: Page, card: Control, value: int, gain: int, color: Color, harmony: bool) -> void:
	## A gem that fires throws sparks of its own color up to its rail's Resonance count, and
	## the number only ticks over when they land, so the chain is seen building gem by gem.
	var token: int = page.resonance_token + 1
	page.resonance_token = token
	var from: Vector2 = _center_of(card)
	var to: Vector2 = _center_of(page.resonance_box)
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
		if token != page.resonance_token:
			return
		_show_resonance(value, page)
		DeepUi.spring(page.resonance_box, 0.3, 6.0, 0.45)
		DeepUi.burst(self, _center_of(page.resonance_box), _resonance_color(value), 10 + 2 * mini(gain, 30), 110.0, 0.4, 4.0)
		if harmony:
			DeepAudio.from(page.resonance_box, "harmony", {"volume": 0.7 if page.mine else 0.5})
			_float_at(page.resonance_box, "+%d harmony" % gain, DeepUi.ACCENT_HI, 15))

func _sync_rail(unit: Dictionary, planning: bool) -> void:
	## Lit while the hand is chosen and on through the resolution it was locked in for, and
	## never while the dice that decide it are still in the air.
	##
	## The rail is laid flat for the fight (see `DeepStone.flatten_rail`); the cards fold it
	## back onto the sockets: a socket's own gem in its ring with its name under it, and the
	## Void gems riding it fanned out behind the ring (docs/UI_REDO.md), each firing in turn
	## after it, with a count of them at the ring's corner. `_socket_cards` is by flat index,
	## so every event's socket lands on the thing to light: a card, a rider's ring, or the
	## count that stands for the riders past the third.
	var showing: bool = (planning or str(state.get("phase", "")) == "resolving") and Time.get_ticks_msec() >= _dice_settle_at
	var rail: Array = unit.get("rail", [])
	var birth_key: String = str(unit.get("character", ""))
	var shape: String = "%d|%s" % [rail.size(), str(unit.get("places", []))]
	var unit_id: String = str(unit.get("id", ""))
	var on: Page = _page
	if _rail_shape != shape or _birthstone_key != birth_key or (_birthstone_card != null and not is_instance_valid(_birthstone_card)):
		DeepUi.clear(_rail_box)
		_socket_cards.clear()
		_birthstone_card = null
		_birthstone_key = birth_key
		_rail_shape = shape
		var hosts: Array = []
		for _socket in range(maxi(DeepStone.socket_count(unit), 1 if rail.is_empty() else 0)):
			var host := VBoxContainer.new()
			host.add_theme_constant_override("separation", 0)
			host.mouse_filter = Control.MOUSE_FILTER_PASS
			_rail_box.add_child(host)
			## The riders fan out behind the card: a row of no height before it, so their rings
			## are drawn under the card and take no room in the rail.
			var riders := Control.new()
			riders.name = "Riders"
			riders.custom_minimum_size = Vector2(SOCKET_EDGE + 8, 0)
			riders.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(riders)
			var card := VBoxContainer.new()
			card.name = "Main"
			card.add_theme_constant_override("separation", 2)
			card.alignment = BoxContainer.ALIGNMENT_BEGIN
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			host.add_child(card)
			hosts.append(host)
		var counts: Dictionary = {}
		for index in range(rail.size()):
			var place: Dictionary = DeepStone.place_of(unit, index)
			var socket_at: int = clampi(int(place.socket), 0, hosts.size() - 1)
			var host: VBoxContainer = hosts[socket_at]
			if int(place.rider) < 0:
				_socket_cards.append(host.get_node("Main"))
				continue
			var riders: Control = host.get_node("Riders")
			counts[socket_at] = int(counts.get(socket_at, 0)) + 1
			var at: int = int(place.rider)
			var riding: Array = []
			for other in range(rail.size()):
				var spot: Dictionary = DeepStone.place_of(unit, other)
				if int(spot.socket) == socket_at and int(spot.rider) >= 0 and rail[other] is Dictionary:
					riding.append(rail[other])
			## The count at the ring's top-left corner says how many ride here (the figure a lit
			## gem would land has the top-right), and stands for the ones past the third; a
			## click lays every one of them out.
			var badge: PanelContainer = riders.get_node_or_null("Count")
			if badge == null:
				badge = PanelContainer.new()
				badge.name = "Count"
				badge.add_theme_stylebox_override("panel", DeepUi.capsule(badge, DeepUi.INFO.darkened(0.6), DeepUi.INFO, 2, 9, 0))
				badge.z_index = 3
				badge.mouse_filter = Control.MOUSE_FILTER_STOP
				badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				badge.set_meta("badge", true)
				riders.add_child(badge)
				var count_label := DeepUi.label(badge, "", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
				count_label.name = "Value"
				count_label.add_theme_font_override("font", DeepUi.bold_font())
				count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var placed_badge: PanelContainer = badge
				badge.resized.connect(func() -> void: placed_badge.position = Vector2(-4.0, Fan.STEP.y * float(RIDERS_SHOWN) - 2.0).round())
				var here: int = socket_at
				badge.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						Inspector.gathering("Void gems on socket %d" % (here + 1), "They ride the socket instead of sitting in it, and fire after its own gem, in this order.", "gem", badge.get_meta("riding", []))
						badge.accept_event())
			(badge.get_node("Value") as Label).text = "×%d" % int(counts[socket_at])
			badge.reset_size()
			badge.set_meta("riding", riding)
			var listed: Array = riding
			Tips.attach(badge, func() -> Control: return _riders_plate(listed, socket_at))
			if at < RIDERS_SHOWN:
				var chip := Control.new()
				chip.name = "Rider%d" % at
				chip.custom_minimum_size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
				chip.size = Vector2(SOCKET_EDGE, SOCKET_EDGE)
				chip.position = Vector2(4.0, 0.0) + Fan.STEP * float(at + 1)
				chip.mouse_filter = Control.MOUSE_FILTER_PASS
				riders.add_child(chip)
				riders.move_child(chip, 0)
				_socket_cards.append(chip)
			else:
				_socket_cards.append(badge)
		if not unit.get("birthstone", {}).is_empty():
			_birthstone_card = _build_birthstone_card(unit)
			_rail_box.add_child(_birthstone_card)
	var sockets: Array = unit.get("sockets", [])
	## Gems the settled dice have just woken, in rail order: each jolts and ticks a step up
	## the scale from the one before, so a roll that lands well is heard to click into place.
	var woken: int = 0
	var waking: Tally.Chain = null
	var links: Array = []
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
				## A faint copy of the rider inside its ring, in the Void's blue.
				var ghost := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 22)
				ghost.name = "Gem"
				ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
				ghost.live_on_hover = false
				ghost.modulate = VOID_GHOST
				slot.add_child(ghost)
			if stone is Dictionary and not rider:
				var picture := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 22)
				picture.name = "Gem"
				picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
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
				## The figure the hand would land, big and bold at the top-right corner, outlined
				## so it reads over the stone; it waits for a hand that fires it.
				var fire := DeepUi.label(slot, "", 23, Color.WHITE)
				fire.name = "Fire"
				fire.add_theme_font_override("font", DeepUi.bold_font())
				fire.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.05, 0.95))
				fire.add_theme_constant_override("outline_size", 8)
				fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fire.z_index = 2
				fire.visible = false
				fire.resized.connect(func() -> void: fire.position = Vector2(SOCKET_EDGE - fire.size.x + 8.0, -10.0))
				var name_label := DeepUi.fit_label(card, DeepUi.skill_name(stone), 12, DeepUi.PAPER, SOCKET_EDGE + 8)
				name_label.name = "SkillName"
			elif not rider:
				DeepUi.label(card, socket_color.capitalize() if socket_color != "ANY" else "Any", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER).custom_minimum_size.x = SOCKET_EDGE + 8
			if stone is Dictionary:
				var flat: int = socket
				var hue: Color = DeepUi.color(DeepStone.color(stone))
				card.focus_mode = Control.FOCUS_ALL
				Tips.attach(card, func() -> Control: return _gem_plate(on, unit_id, flat), {"tone": hue, "keep": true})
		if stone is Dictionary:
			var entry: Dictionary = {}
			for candidate in forecast.get("sockets", []):
				if int(candidate.get("socket", -1)) == socket:
					entry = candidate
			var ring: SocketRing = card.get_node_or_null("Slot/Ring")
			var active: bool = bool(entry.get("active", false))
			## Once the gem has resolved, what it really did outranks what was forecast.
			if not planning and _outcomes.has(socket):
				active = bool(_outcomes[socket])
			var lit: bool = active and showing
			if ring != null:
				ring.set_ready(lit)
				## Only the reader's own rail ticks as it wakes: it answers what they rolled.
				if lit and planning and not bool(card.get_meta("lit", false)) and not _headless and _page.mine:
					if waking == null:
						waking = Tally.Chain.new()
						waking.reset()
					_wake(card, waking.pitch(woken), 0.05 * float(woken), DeepSoundBank.tick_sound(_color_key(local_id, socket, "")))
					woken += 1
				card.set_meta("lit", lit)
			## The figure: what the hand would land, read off the rail itself.
			var fire: Label = card.get_node_or_null("Slot/Fire")
			if fire != null:
				var said: Array = Plates.badge(entry) if lit and planning else ["", DeepUi.PAPER]
				fire.visible = not str(said[0]).is_empty()
				if fire.visible:
					fire.text = str(said[0])
					fire.add_theme_color_override("font_color", Color(said[1]).lightened(0.25))
					fire.reset_size()
			var picture: Control = card.get_node_or_null("Slot/Gem")
			if picture != null:
				picture.set("context", DeepBattle.rail_context(state, unit, socket))
			## Pointing at a gem lights the dice in the tray its trigger reads: the plainest way
			## to learn what "a pair of 4+" asks for is to watch which dice answer it.
			card.set_meta("flat", socket)
			if not bool(card.get_meta("dice_link_wired", false)):
				card.set_meta("dice_link_wired", true)
				var linked: Control = card
				card.mouse_entered.connect(func() -> void: _on_page(on, _light_dice_for.bind(int(linked.get_meta("flat", -1)))))
				card.mouse_exited.connect(func() -> void: _on_page(on, _light_dice_for.bind(-1)))
			if not rider:
				_sync_raised(unit, card, stone)
			var blocked: bool = DeepPatch.holds(unit.get("buried", []), socket) or DeepPatch.holds(unit.get("clouded", []), socket)
			if ring != null:
				ring.blocked = blocked
			## A gem this hand leaves dark steps back, so the ones it fires stand out at a glance
			## and "fires 2, fizzles 1" can be read off the rail itself.
			var quiet: bool = showing and not entry.is_empty() and not active
			## The stone steps back; its name only greys, so it stays readable (4.5:1 or better).
			card.modulate = Color.WHITE
			var slot_node: Control = card.get_node_or_null("Slot")
			if slot_node != null:
				slot_node.modulate = Color(0.55, 0.55, 0.6, 0.6) if blocked else (QUIET_GEM if quiet else Color.WHITE)
			var named: Label = card.get_node_or_null("SkillName")
			if named != null:
				named.add_theme_color_override("font_color", DeepUi.MUTED if blocked or quiet else DeepUi.PAPER)
			if lit and not entry.is_empty():
				links.append([DeepStone.color(stone), int(entry.get("resonance", 0))])
	_sync_birthstone(unit, planning, showing)
	## What each color rang, for the meter's waves: each firing gem's share is the count after
	## it less the count before it.
	if _page.meter != null and is_instance_valid(_page.meter):
		var rang: Dictionary = {}
		var before: int = int(unit.get("initial_resonance", 0))
		for link in links:
			var gain: int = maxi(0, int(link[1]) - before)
			before = maxi(before, int(link[1]))
			rang[str(link[0])] = int(rang.get(str(link[0]), 0)) + maxi(gain, 1)
		_page.meter.set_contributions(rang)

func _socket_riders(unit: Dictionary, socket: int) -> Array:
	## The Void gems riding one socket of a flattened rail, in the order they fire.
	var out: Array = []
	var rail: Array = unit.get("rail", [])
	for index in range(rail.size()):
		var place: Dictionary = DeepStone.place_of(unit, index)
		if int(place.socket) == socket and int(place.rider) >= 0 and rail[index] is Dictionary:
			out.append(rail[index])
	return out

func _socket_gem(unit: Dictionary, socket: int) -> Dictionary:
	## The gem set in a socket of a flattened rail ({} when the socket is empty).
	var rail: Array = unit.get("rail", [])
	for index in range(rail.size()):
		var place: Dictionary = DeepStone.place_of(unit, index)
		if int(place.socket) == socket and int(place.rider) < 0 and rail[index] is Dictionary:
			return rail[index]
	return {}

func _gem_plate(page: Page, unit_id: String, flat: int) -> Control:
	## The plate over a gem on the rail: built from the fight as it stands when the pointer
	## arrives (docs/UI_REDO.md).
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var rail: Array = unit.get("rail", [])
	if unit.is_empty() or flat < 0 or flat >= rail.size() or not rail[flat] is Dictionary:
		return null
	var stone: Dictionary = rail[flat]
	var entry: Dictionary = {}
	var planning: bool = str(state.get("phase", "")) == "planning"
	if planning and Time.get_ticks_msec() >= page.dice_settle_at:
		for candidate in page.forecast.get("sockets", []):
			if int(candidate.get("socket", -1)) == flat:
				entry = candidate
	var place: Dictionary = DeepStone.place_of(unit, flat)
	var socket: int = int(place.socket)
	var opts: Dictionary = {"socket": socket}
	var riders: Array = _socket_riders(unit, socket)
	if int(place.rider) >= 0:
		opts.rider_of = true
		var own: Dictionary = _socket_gem(unit, socket)
		opts.riders = ([own] if not own.is_empty() else []) + riders
	elif not riders.is_empty():
		opts.riders = riders
	if DeepPatch.holds(unit.get("buried", []), flat):
		opts.note = "Buried in rubble: it cannot fire this turn."
	elif DeepPatch.holds(unit.get("clouded", []), flat):
		opts.note = "Clouded: hit the creature that fogged it to clear it."
	return Plates.gem(stone, DeepBattle.rail_context(state, unit, flat), unit.get("hand", []), entry, unit.get("dice", []), opts)

func _riders_plate(riders: Array, socket: int) -> Control:
	## The count at a socket's corner: every Void gem riding it, in firing order.
	var box: VBoxContainer = Plates.plate(300.0)
	Plates.head(box, "%s riding socket %d" % [DeepUi.plural(riders.size(), "Void gem"), socket + 1], "fire after its gem, in this order", DeepUi.INFO)
	for rider in riders:
		var row := DeepUi.hbox(box, 8)
		var thumb := Thumbs.GemThumb.new(rider, 24)
		thumb.live_on_hover = false
		row.add_child(thumb)
		var words := DeepUi.vbox(row, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(words, DeepUi.skill_name(rider), 13, DeepUi.PAPER)
		DeepUi.effect_text(words, DeepStone.text(rider), 11, DeepUi.MUTED)
	Plates.footer(box, "Click · lay them all out")
	return box

func _wake(card: Control, pitch: float, delay: float, voice: String) -> void:
	## A gem the hand would now fire, said as it lights: a small jolt and a tick in its voice.
	var held: WeakRef = weakref(card)
	_later_do(delay, func() -> void:
		var still: Control = held.get_ref() as Control
		if still == null or not still.is_inside_tree():
			return
		DeepUi.spring(still, 0.12, 4.0, 0.35)
		DeepAudio.from(still, voice, {"pitch": pitch, "volume": 0.32, "vary": 0.0, "gap": 0.0}))

func _preview_count(socket: int) -> void:
	## While the hand is chosen, a gem pointed at shows its count already worked out, over
	## its socket: the dice, what multiplies them, and what it would come to.
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	if socket < 0 or _headless or str(state.get("phase", "")) != "planning" or Time.get_ticks_msec() < _dice_settle_at:
		return
	var entry: Dictionary = {}
	for candidate in forecast.get("sockets", []):
		if int(candidate.get("socket", -1)) == socket:
			entry = candidate
	var tally: Dictionary = entry.get("tally", {})
	if not bool(entry.get("active", false)) or not tally.has("amount"):
		return
	var whose: String = local_id if _page.mine else _page.id
	var plate := Tally.new()
	plate.color = _stone_color(whose, socket, str(entry.get("skill", "")))
	var said: String = str(DeepContent.skill(str(entry.get("skill", ""))).get("name", ""))
	if int(entry.get("fires", 1)) > 1:
		said += " · fires %d times" % int(entry.fires)
	plate.caption = said
	plate.gem_anchor = _gem_card.bind(whose, socket)
	plate.ceiling = _dock_top
	add_child(plate)
	plate.show_sum(tally)
	_preview = plate

func _light_dice_for(socket: int) -> void:
	## The dice a gem's trigger counted in the hand as it stands, lit while that gem is pointed
	## at; -1 (or a gem this hand leaves dark) lights none. Its count is on its plate.
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
			plate.add_theme_stylebox_override("panel", DeepUi.facet_ends(plate, DeepUi.flat(Color(0.03, 0.04, 0.06, 0.82), Color(DeepUi.GOOD, 0.45), 5, 2)))
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
	## The character's Birthstone at the end of the rail: the stone in its own bezel and its
	## name, built like a socket's card. Its tiers, and which the hand would fire, read on
	## its plate.
	var stone: Dictionary = DeepStone.birthstone_for(unit)
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
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
		var picture := Thumbs.GemThumb.new(stone, SOCKET_EDGE - 22)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
		slot.add_child(picture)
	## Stepped down to fit rather than cut off: a Birthstone's name is often the longest on the rail.
	var name_label := DeepUi.fit_label(card, str(stone.get("name", "Birthstone")), 12, tint.lightened(0.35), SOCKET_EDGE + 8)
	name_label.name = "Name"
	var on: Page = _page
	var unit_id: String = str(unit.get("id", ""))
	Tips.attach(card, func() -> Control: return _birth_plate(on, unit_id), {"tone": tint})
	return card

func _birth_plate(page: Page, unit_id: String) -> Control:
	## The Birthstone's plate: each tier, its pictograph and its words, the ones this hand
	## would fire lit.
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	if unit.is_empty() or unit.get("birthstone", {}).is_empty():
		return null
	var stone: Dictionary = DeepStone.birthstone_for(unit)
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var box: VBoxContainer = Plates.plate()
	Plates.head(box, str(stone.get("name", "Birthstone")), "your Birthstone", tint.lightened(0.3))
	if not str(stone.get("text", "")).is_empty():
		DeepUi.effect_text(box, str(stone.get("text", "")), 12, DeepUi.MUTED)
	var planning: bool = str(state.get("phase", "")) == "planning"
	var preview: Dictionary = page.birth_outcome if not planning and not page.birth_outcome.is_empty() else page.forecast.get("birthstone", {})
	var previewed: Array = preview.get("tiers", []) if Time.get_ticks_msec() >= page.dice_settle_at else []
	var defs: Array = unit.get("birthstone", {}).get("tiers", [])
	Plates.section(box, "Its tiers")
	for index in range(defs.size()):
		var tier: Dictionary = defs[index]
		var active: bool = index < previewed.size() and bool(previewed[index].get("active", false))
		var penalty: bool = bool(tier.get("penalty", false))
		var row := DeepUi.hbox(box, 8)
		var tone: Color = (DeepUi.BAD if penalty else DeepUi.GOOD) if active else DeepUi.MUTED
		DiceIcons.build(row, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 16, tone)
		var said := DeepUi.vbox(row, 0)
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_row := DeepUi.hbox(said, 6)
		DeepUi.label(title_row, str(tier.get("name", "")), 12, tone)
		if active:
			DeepUi.label(title_row, "FIRES", 9, Color("ffc247")).add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.effect_text(said, str(tier.get("text", "")), 11, DeepUi.PAPER if active else DeepUi.MUTED)
		var reason: String = str(previewed[index].get("reason", "")) if index < previewed.size() and not active else ""
		if not reason.is_empty():
			DeepUi.label(said, reason, 10, DeepUi.DIM)
	Plates.footer(box)
	return box

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
	## Buried or clouded: hatched across, so a socket that cannot fire reads as one.
	var blocked: bool = false:
		set(value):
			if value != blocked:
				blocked = value
				queue_redraw()
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
			draw_arc(centre, radius - 5.0, 0, TAU, 48, Color(tone, 0.6), 2.0, true)
			var crown := PackedVector2Array([centre + Vector2(-9, -radius - 1), centre + Vector2(-5, -radius - 8), centre + Vector2(0, -radius - 3),
				centre + Vector2(5, -radius - 8), centre + Vector2(9, -radius - 1)])
			draw_colored_polygon(crown, tone.lightened(0.2))
		if blocked:
			var step: float = 7.0
			var x: float = -radius
			while x < radius * 2.0:
				var a: Vector2 = centre + Vector2(x - radius, radius)
				var b: Vector2 = centre + Vector2(x, -radius)
				draw_line(a, b, Color(0.9, 0.9, 1.0, 0.22), 2.0, true)
				x += step

class PhantomRing extends Control:
	## One phantom die behind the die it copies: a dashed ring in the Void blue, a faint copy of
	## the die inside it showing the face it carries, and the value where the ring peeks out
	## from behind the die.
	var value: int = 0
	var _ghost: Control = null
	func _init(carried: int, die: Dictionary = {}, face: int = -1) -> void:
		value = carried
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not die.is_empty():
			_ghost = Thumbs.DieThumb.new(die, 60.0, face)
			_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ghost.modulate = VOID_GHOST
			add_child(_ghost)
			resized.connect(func() -> void: _ghost.position = ((size - Vector2(60.0, 60.0)) * 0.5).round())
	func _draw() -> void:
		var centre := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.46
		draw_circle(centre, radius, Color(DeepUi.INFO, 0.1))
		for arc in range(8):
			var angle: float = TAU * float(arc) / 8.0
			draw_arc(centre, radius, angle, angle + TAU / 12.0, 10, Color(DeepUi.INFO, 0.85), 2.0, true)
		var font: Font = DeepUi.bold_font()
		var font_size: int = maxi(10, int(radius * 0.42))
		var text: String = str(value)
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at: Vector2 = centre + Vector2.from_angle(-PI * 0.75) * radius * 0.62 - Vector2(measured.x * 0.5, -measured.y * 0.3)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.8))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DeepUi.INFO.lightened(0.3))

func _sync_phantoms(unit: Dictionary) -> void:
	## A Refract's phantoms: copies of a die that count for every gem after it this turn. They
	## are not the player's to reroll, so they fan out behind the die they copy, in the Void
	## blue a rider wears, with a count of them at its corner (docs/UI_REDO.md); the die's
	## plate names each one.
	var ghosts: Array = unit.get("hand", []).filter(func(r: Dictionary) -> bool: return bool(r.get("phantom", false)))
	var key: String = ",".join(ghosts.map(func(r: Dictionary) -> String: return "%s=%d=%s" % [str(r.get("die_id", "")), int(r.get("value", 0)), str(r.get("source_id", ""))]))
	if key == _phantom_key:
		return
	_phantom_key = key
	for id in _dice_views:
		var view: Variant = _dice_views[id]
		if view is Control and is_instance_valid(view):
			var fan: Node = (view as Control).get_parent().get_node_or_null("Fan")
			if fan != null:
				fan.get_parent().remove_child(fan)
				fan.queue_free()
	_phantom_views.clear()
	if _phantom_box != null:
		_phantom_box.visible = false
	if ghosts.is_empty():
		return
	var grouped: Dictionary = {}
	for ghost in ghosts:
		var source_id: String = str(ghost.get("source_id", str(ghost.get("die_id", "")).split("_ph")[0]))
		if not grouped.has(source_id):
			grouped[source_id] = []
		grouped[source_id].append(ghost)
	var index: int = 0
	for source_id in grouped:
		var view: Variant = _dice_views.get(source_id, null)
		if not (view is Control and is_instance_valid(view)):
			continue
		var holder: Control = (view as Control).get_parent()
		var fan := Fan.new(DeepUi.INFO)
		fan.name = "Fan"
		holder.add_child(fan)
		holder.move_child(fan, 0)
		fan.offset_bottom = -DIE_WORDS
		var list: Array = grouped[source_id]
		var source_die: Dictionary = {}
		for die in unit.get("dice", []):
			if str(die.get("id", "")) == source_id:
				source_die = die
		for k in range(list.size()):
			var ring := PhantomRing.new(int(list[k].get("value", 0)), source_die, int(list[k].get("face", -1)))
			fan.lay(ring, k)
			_phantom_views[str(list[k].get("die_id", ""))] = ring
		fan.set_count(list.size())
		if not _headless:
			DeepUi.pop_in(fan, 0.05 * float(index), 0.7)
		index += 1

func _die_plate(page: Page, owner_id: String, die_id: String, mine: bool) -> Control:
	## The plate over a die in the tray: what it is, its faces with the one it shows lit, what
	## is cut into it, the phantoms behind it, and what this turn has done to it.
	var unit: Dictionary = DeepBattle.player(state, owner_id)
	var die: Dictionary = {}
	for candidate in unit.get("dice", []):
		if str(candidate.get("id", "")) == die_id:
			die = candidate
	if die.is_empty():
		return null
	var roll: Dictionary = {}
	var ghosts: Array = []
	for candidate in unit.get("hand", []):
		if str(candidate.get("die_id", "")) == die_id:
			roll = candidate
		elif bool(candidate.get("phantom", false)) and str(candidate.get("source_id", str(candidate.get("die_id", "")).split("_ph")[0])) == die_id:
			ghosts.append(candidate)
	var opts: Dictionary = {}
	if not ghosts.is_empty():
		opts.phantoms = ghosts
	if bool(roll.get("locked", false)):
		opts.note = "Locked: it came up as it did last turn and cannot be rerolled."
		opts.note_glyph = "lock"
		opts.note_tone = DeepUi.BAD
	elif bool(roll.get("lock_next", false)):
		opts.note = "It will come up next turn exactly as it shows now."
		opts.note_glyph = "lock"
		opts.note_tone = DeepUi.BAD
	elif bool(roll.get("bonus", false)):
		opts.note = "A Hot Streak's die, lent for this turn."
		opts.note_glyph = "flame"
		opts.note_tone = DeepUi.ORE
	elif bool(roll.get("flipped", false)):
		opts.note = "Turned over by Sleight this turn."
		opts.note_glyph = "flip"
	if mine:
		var sleight: bool = str(unit.get("passive", {}).get("kind", "")) == "free_flip"
		if DeepBattle.all_or_nothing(unit):
			opts.footer = "Reroll throws every die · Right-click · everything"
		elif sleight:
			opts.footer = "Click · pick it · Right-click or hold · turn it over · Shift+right-click · everything"
		else:
			opts.footer = "Click · pick it for a reroll · Right-click · everything"
	else:
		opts.footer = Plates.FOOTER
	return Plates.die(die, roll, opts)

func _sync_tray(unit: Dictionary, planning: bool) -> void:
	## The reader's own dice are theirs to pick; anyone else's are only to look at.
	var mine: bool = _page.mine
	var owner_id: String = str(unit.get("id", ""))
	var on: Page = _page
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
		## The fans behind the old dice went with them.
		_phantom_key = ""
		_phantom_views.clear()
		var index: int = 0
		for id in wanted:
			index += 1
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE + DIE_WORDS)
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
			_tray_box.add_child(holder)
			var view := DiceView.new()
			view.tilt = true
			view.position = Vector2.ZERO
			view.size = Vector2(DIE_EDGE, DIE_EDGE)
			view.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE)
			view.hush = 1.0 if mine else 0.6
			holder.add_child(view)
			var value := DeepUi.label(holder, "", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			value.position = Vector2(0, DIE_EDGE)
			value.size = Vector2(DIE_EDGE, DIE_WORDS)
			value.name = "Value"
			## An exploding face is added up as the die lands on each throw, not all at once.
			view.chain_stepped.connect(func(total: int) -> void:
				if is_instance_valid(value):
					value.text = DiceIcons.face_text(total, "exploding").strip_edges()
					if not _headless:
						DeepUi.pulse(value, 1.25, 0.2))
			var hit := Button.new()
			hit.flat = true
			hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				hit.add_theme_stylebox_override(style, StyleBoxEmpty.new())
			if mine:
				hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hit.pressed.connect(_toggle_die.bind(id))
			## Under the pointer a die lifts 2 px over 80 ms, and settles back as it leaves; a
			## chosen die is already up on its spring and stays there.
			hit.mouse_entered.connect(func() -> void:
				view.set_highlight(true)
				_show_ghost(id, true)
				if mine and not bool(view.get_meta("chosen", false)) and not _headless:
					view.create_tween().tween_property(view, "position:y", -2.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT))
			hit.mouse_exited.connect(func() -> void:
				view.set_highlight(false)
				_show_ghost(id, false)
				if mine and not bool(view.get_meta("chosen", false)) and not _headless:
					view.create_tween().tween_property(view, "position:y", 0.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT))
			Tips.attach(hit, func() -> Control: return _die_plate(on, owner_id, id, mine), {"tone": DiceIcons.die_palette(by_id.get(id, {})).body})
			## A right-click turns a die over while Puck has a Sleight to spend; with Shift held, or
			## for anyone else, it opens the die.
			hit.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					if mine and not event.shift_pressed and _can_turn(id):
						_turn_die(id)
					else:
						_inspect_die(id, owner_id)
					hit.accept_event())
			if mine:
				hit.button_down.connect(_press_start.bind(id))
				hit.button_up.connect(_press_end.bind(id))
			holder.add_child(hit)
			_dice_views[id] = view
	## The phantoms stand behind the dice they copy, so they are laid once the dice are.
	_sync_phantoms(unit)
	for roll in hand:
		var id: String = str(roll.die_id)
		if not _dice_views.has(id):
			continue
		var view: DiceView = _dice_views[id]
		var tagged: Dictionary = roll.duplicate(true)
		tagged.turn_tag = str(state.get("turn", 0))
		var can_select: bool = mine and planning and not bool(unit.get("locked", false)) and not bool(roll.get("locked", false))
		var chosen: bool = selected.has(id) and can_select
		view.configure(by_id.get(id, {"shape": roll.shape, "material": str(roll.get("material", "")), "faces": []}), tagged, chosen, false, DeepUi.ACCENT)
		## Chosen, a die lifts 5 px on a spring (docs/UI_REDO.md, R1); at rest it sits flat.
		view.set_meta("chosen", chosen)
		var lift: float = -5.0 if chosen else 0.0
		if not is_equal_approx(view.position.y, lift) and not _headless:
			var tween := view.create_tween()
			tween.tween_property(view, "position:y", lift, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif _headless:
			view.position.y = lift
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
		var lent: bool = bool(roll.get("bonus", false))
		if lent:
			words = "bonus  " + words
		value.text = words.strip_edges()
		value.add_theme_color_override("font_color", DeepUi.ACCENT if chosen else (DeepUi.ORE if lent else DeepUi.MUTED))
		_bonus_rim(view.get_parent(), lent)
		_parity_rim(view.get_parent(), roll, unit)
	## A hand locked in while the rest of the party still chooses settles back a shade: these
	## dice are final. They come up bright again for the turn to count them.
	var settled: Color = Color(0.74, 0.76, 0.86) if planning and bool(unit.get("locked", false)) else Color.WHITE
	if not _tray_box.has_meta("tone") or Color(_tray_box.get_meta("tone")) != settled:
		var was_set: bool = _tray_box.has_meta("tone")
		_tray_box.set_meta("tone", settled)
		if _headless or not was_set or not _tray_box.is_inside_tree():
			_tray_box.modulate = settled
		else:
			_tray_box.create_tween().tween_property(_tray_box, "modulate", settled, 0.25).set_trans(Tween.TRANS_SINE)

func _sync_plates(only: String = "") -> void:
	## Every creature's plate, or with `only` just that one creature's (a blow landing on it).
	var present: Dictionary = {}
	var target_id: String = str(me().get("target", ""))
	var preview: int = int(forecast.get("totals", {}).get("damage", 0)) if str(state.get("phase", "")) == "planning" else 0
	## The creature acting now, if one is: its plate is lit and the rest step back.
	var acting: String = ""
	if str(state.get("phase", "")) == "resolving":
		for foe in state.get("enemies", []):
			if bool(foe.get("acting", false)) and int(foe.get("hp", 0)) > 0:
				acting = str(foe.id)
				break
	for truth in state.get("enemies", []):
		if not only.is_empty() and str(truth.get("id", "")) != only:
			continue
		## As its plate should read: health a count has not landed yet is still on it.
		var foe: Dictionary = _shown(truth)
		var id: String = str(foe.id)
		present[id] = true
		var plate: Plate = _plates.get(id, null)
		if int(foe.hp) <= 0:
			if plate != null and is_instance_valid(plate) and not plate.fading:
				var dead: Plate = plate
				plate.fade(func() -> void:
					if _plates.get(id, null) == dead:
						_plates.erase(id))
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
		plate.set_open(id == _hovered_creature or (_hovered_creature.is_empty() and id == target_id))
		plate.set_spot(acting == id, not acting.is_empty() and acting != id)
		_dress(_creature(id), foe)
	if not only.is_empty():
		return
	for id in _plates.keys():
		if not present.has(id):
			if is_instance_valid(_plates[id]):
				_plates[id].queue_free()
			_plates.erase(id)

func _soak(hit: Dictionary, creature: CrystalCreature, ratio: float) -> void:
	## A blow block took part of, counted at the health bar: what came in, the block flying
	## off the shield to meet it, and what was left to bleed, each landing on its own bar.
	var absorbed: int = int(hit.get("absorbed", 0))
	var loss: int = int(hit.get("hp_loss", 0))
	var plate := Tally.new()
	plate.gem_anchor = func() -> Control: return _vital_anchor(local_id)
	plate.ceiling = _dock_top
	plate.rumbles = true
	plate.shield = func() -> Control: return _shown_anchor(_status_row if _status_row.get_child_count() > 0 else _hp_bar)
	plate.on_soaked = func(block: int) -> void:
		_land_vitals(local_id, 0, block)
		DeepAudio.play("block", {"volume": 0.7, "gap": 0.0})
		DeepUi.burst(self, _center_of(_hp_bar), DeepUi.BLOCK, 14, 120.0, 0.45)
	var tint: Color = creature.tint if creature != null and is_instance_valid(creature) else DeepUi.BAD
	plate.on_bled = func(hp: int) -> void:
		_land_vitals(local_id, hp, 0)
		if hp <= 0:
			_float_at(_hp_bar, "Blocked", DeepUi.BLOCK, 24)
			return
		DeepAudio.rumble(0.3 + ratio, 0.4 + ratio * 1.5, 0.12 + ratio * 0.2)
		_screen_fx.wound(0.45 + ratio * 2.0)
		_screen_fx.kick(0.4 + ratio * 2.0)
		_screen_fx.blink(Color(1.0, 0.2, 0.15), 0.12 + ratio * 0.3)
		_slash(tint)
		_float_at(_hp_bar, "−" + DeepUi.number(hp), DeepUi.BAD, 26 + mini(20, hp))
	add_child(plate)
	plate.soak(absorbed + loss, absorbed, loss, _soak_pace)

class Plate extends VBoxContainer:
	## A creature's nameplate (docs/UI_REDO.md, M1): everything about it, over its head. Its
	## name and its dice in order (the next to roll lit); its health, with its block capped past
	## the end of it and what this hand would take hatched in red; its traits (violet tiles) and
	## its moves as tiles with their numbers, the one it is winding up in red; and under the
	## plate, what is on it, the same chips the party wears. The targeted or hovered creature's
	## plate opens into a line a move: the trigger as a pictograph and the effect in the gem
	## sheet's keyword colors. The plate itself never moves for it: the lines and the chips hang
	## below it (`base_height`). Right-click for the inspector.
	signal inspect(move: String)
	const WIDTH: float = 330.0
	var fading: bool = false
	## Open: its moves spelled out under the tiles.
	var expanded: bool = false
	var panel: PanelContainer
	var _name: Label
	var _target: TextureRect
	var _bar: DeepUi.Bar
	var _effects: EffectChips.Row
	var _dice: HBoxContainer
	var _moves: HBoxContainer
	var _lines: VBoxContainer
	var _tiles: Array = []
	var _trait_tiles: Array = []
	var _moves_key: String = ""
	var _lines_key: String = ""
	var _states_key: String = ""
	var _targeted: bool = false
	## While a creature acts its plate is lit in the color of a blow and the others step back.
	var _acting: bool = false
	var _dimmed: bool = false
	var _breath: Tween = null
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_constant_override("separation", 4)
		panel = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.custom_minimum_size.x = WIDTH
		add_child(panel)
		_style(false)
		var box := DeepUi.vbox(panel, 5)
		var head := DeepUi.hbox(box, 6)
		_target = DeepUi.icon(head, "crosshair", 14, DeepUi.ACCENT, "Your target")
		_name = DeepUi.label(head, "", 14, DeepUi.PAPER)
		_name.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.spacer(head)
		_dice = DeepUi.hbox(head, 3)
		_dice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bar = DeepUi.bar(box, 16.0, DeepUi.BAD, DeepUi.HP_LOST)
		_bar.cap = true
		_bar.custom_minimum_size = Vector2(WIDTH - 24.0, 16)
		_moves = DeepUi.hbox(box, 5)
		_moves.mouse_filter = Control.MOUSE_FILTER_PASS
		_lines = DeepUi.vbox(box, 4)
		_lines.visible = false
		## What is on it, under the plate, the way the party's chips ride over the dock.
		_effects = EffectChips.Row.new(14)
		_effects.alignment = FlowContainer.ALIGNMENT_CENTER
		add_child(_effects)
		gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				inspect.emit("")
				accept_event())
	func _style(targeted: bool) -> void:
		var style := DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT if targeted else DeepUi.LEDGER_LINE, 10, 9, 3 if targeted else 2, 4)
		if _acting:
			## Acting outranks targeted: the edge goes the color of a blow and glows, breathing
			## until its action ends (held steady for anyone who asked for fewer flashes).
			style.border_color = DeepUi.BAD
			style.set_border_width_all(3)
			style.shadow_color = Color(DeepUi.BAD, 0.3)
			style.shadow_size = 10
			style.shadow_offset = Vector2.ZERO
		if _breath != null and _breath.is_valid():
			_breath.kill()
		_breath = null
		if _acting and not DeepUi.headless() and not ScreenFx.calm:
			_breath = create_tween().set_loops()
			_breath.tween_property(style, "shadow_color:a", 0.1, 0.6).set_trans(Tween.TRANS_SINE)
			_breath.tween_property(style, "shadow_color:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
		panel.add_theme_stylebox_override("panel", style)
	func base_height() -> float:
		## The plate without what hangs under it (its open lines and its chips): what it is
		## placed by, so opening it or a new status never moves it.
		var whole: float = panel.get_combined_minimum_size().y
		if _lines.visible:
			whole -= _lines.get_combined_minimum_size().y + 5.0
		return whole
	func set_spot(acting: bool, dimmed: bool) -> void:
		## Whether this creature is the one acting, or another one is.
		if fading:
			return
		if dimmed != _dimmed:
			_dimmed = dimmed
			var alpha: float = 0.68 if dimmed else 1.0
			if DeepUi.headless():
				modulate.a = alpha
			else:
				create_tween().tween_property(self, "modulate:a", alpha, 0.2).set_trans(Tween.TRANS_SINE)
		if acting == _acting:
			return
		_acting = acting
		_style(_targeted)
		if acting:
			DeepUi.pulse(self, 1.04, 0.3)
	func set_open(open: bool) -> void:
		## The lines under the tiles, for the creature being looked at.
		if open == expanded:
			return
		expanded = open
		_lines.visible = open
		if not open:
			_lines_key = ""
	func die_mark(index: int) -> Control:
		## The mark of its die at this place on the plate.
		return _dice.get_child(index) as Control if index >= 0 and index < _dice.get_child_count() else null

	func update(foe: Dictionary, battle: Dictionary, local_id: String, targeted: bool, preview: int) -> void:
		if targeted != _targeted:
			_targeted = targeted
			_style(targeted)
			if targeted:
				DeepUi.pulse(self, 1.06, 0.3)
		_target.visible = targeted
		_name.text = str(foe.name).to_upper()
		_name.add_theme_color_override("font_color", Color("ffb0a0") if bool(foe.get("warden", false)) else DeepUi.PAPER)
		var max_hp: int = maxi(1, int(foe.max_hp))
		_bar.set_values(float(foe.hp) / float(max_hp), "%s / %s" % [DeepUi.number(int(foe.hp)), DeepUi.number(max_hp)], float(foe.get("block", 0)) / float(max_hp))
		_bar.preview = clampf(float(maxi(0, preview - int(foe.block))) / float(max_hp), 0.0, 1.0)
		tooltip_text = str(foe.get("text", "")) + "\nLeft-click to target it. Right-click for everything about it."
		## What is on it, under the plate; what it is (its traits) stands beside its moves.
		var chips: Array = EffectChips.for_enemy(foe, battle)
		_effects.show_effects(chips.filter(func(c: Dictionary) -> bool: return str(c.get("span", "")) != "trait"))
		var dice: Array = DeepCreatures.effective_dice(foe)
		var moves: Array = DeepCreatures.display_moves(foe, foe.get("moves", DeepCreatures.moves_for(foe)))
		var acting: bool = bool(foe.get("acting", false))
		## What it has rolled so far this action rides on the plate with its dice, so the
		## numbers read over its head.
		var hand: Array = foe.get("hand", []) if acting or str(foe.get("beat", "")) == "done" else []
		var states: Array = foe.get("move_states", [])
		var moves_key: String = str(dice) + str(moves) + str(foe.get("stolen_dice", 0)) + str(foe.get("suppressed", 0)) + str(hand.map(func(r: Dictionary) -> int: return int(r.get("value", 0)))) + str(acting) + str(int(foe.get("next_die", 0)))
		if moves_key != _moves_key:
			_moves_key = moves_key
			DeepUi.clear(_dice)
			var suppressed: int = int(foe.get("suppressed", 0)) if acting else int(foe.get("stolen_dice", 0))
			for index in range(dice.size()):
				var gone: bool = index >= dice.size() - suppressed
				var rolled: bool = index < hand.size()
				## The next die to be thrown is the lit one.
				var next: bool = acting and not rolled and not gone and index == hand.size()
				## Unrolled, a die says its size in a quiet grey; rolled, its number in its own color.
				var shape_name: String = str(dice[index].shape).to_lower()
				var mark: String = "×" if gone else (str(int(hand[index].get("value", 0))) if rolled else shape_name)
				var tone: Color = DeepUi.DIM if gone else (DeepUi.ACCENT_HI if next else (DiceIcons.die_palette(dice[index]).body if rolled else DeepUi.MUTED))
				var face: Control = DiceIcons.face(22, int(hand[index].get("value", 0)) if rolled else 0, tone, str(dice[index].shape), rolled or next, mark)
				face.mouse_filter = Control.MOUSE_FILTER_PASS
				face.tooltip_text = "%s · %s" % [str(dice[index].shape).to_lower(), "taken away" if gone else ("next to roll" if next else "roll %d" % (index + 1))]
				_dice.add_child(face)
			_build_tiles(foe, moves)
		var states_key: String = str(states) + str(foe.get("clouded_move", -1)) + str(DeepCreatures.charge_turns(foe))
		if states_key != _states_key:
			_states_key = states_key
			_state_tiles(foe, states)
		if expanded:
			var lines_key: String = moves_key + str(DeepCreatures.traits_for(foe) if foe.has("key") else {})
			if lines_key != _lines_key:
				_lines_key = lines_key
				_build_lines(foe, moves)
	func _build_tiles(foe: Dictionary, moves: Array) -> void:
		## A tile a trait (violet), then a tile a move: its mark, its name and its number, in the
		## keyword color of what it does.
		DeepUi.clear(_moves)
		_tiles.clear()
		_trait_tiles.clear()
		var traits: Dictionary = DeepCreatures.traits_for(foe) if foe.has("key") else {}
		var keys: Array = traits.keys()
		keys.sort()
		for key in keys:
			if str(key) == "gift_rerolls" and (traits.has("reroll_drain") or traits.has("reroll_scorch")):
				continue
			var words: Dictionary = EffectChips.trait_entry(str(key), traits[key])
			var tile := PanelContainer.new()
			tile.mouse_filter = Control.MOUSE_FILTER_PASS
			var style := DeepUi.ledger(Color("251b3c"), Color("b58cff"), 6, 3, 2, 0)
			style.content_margin_left = 7
			style.content_margin_right = 8
			tile.add_theme_stylebox_override("panel", style)
			tile.tooltip_text = "%s\n%s" % [str(words.title), str(words.text)]
			_moves.add_child(tile)
			var row := DeepUi.hbox(tile, 4)
			DeepUi.icon(row, str(words.glyph), 13, Color("c8a8ff")).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var named := DeepUi.label(row, str(words.title), 12, Color("e3d2ff"))
			named.add_theme_font_override("font", DeepUi.bold_font())
			_trait_tiles.append(tile)
		if not _trait_tiles.is_empty() and not moves.is_empty():
			var gap := DeepUi.rule(_moves, DeepUi.LEDGER_LINE)
			gap.custom_minimum_size = Vector2(2, 0)
			gap.size_flags_vertical = Control.SIZE_FILL
		for index in range(moves.size()):
			var move: Dictionary = moves[index]
			var tile := PanelContainer.new()
			tile.mouse_filter = Control.MOUSE_FILTER_PASS
			tile.add_theme_stylebox_override("panel", _tile_style(false))
			tile.tooltip_text = str(move.name) + " · " + DeepCreatures.trigger_words(move) + "\n" + "\n".join(move.get("effects", []).map(func(e: Dictionary) -> String: return DeepCreatures.effect_words(e)))
			_moves.add_child(tile)
			var row := DeepUi.hbox(tile, 4)
			var glyph := DeepUi.icon(row, EnemyPanel.move_glyph(move), 13, DeepUi.BAD)
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var named := DeepUi.label(row, str(move.name), 12, DeepUi.PAPER)
			named.add_theme_font_override("font", DeepUi.bold_font())
			var figure: Array = _tile_figure(move)
			if not str(figure[0]).is_empty():
				var number := DeepUi.label(row, str(figure[0]), 12, figure[1])
				number.add_theme_font_override("font", DeepUi.bold_font())
			_tiles.append(tile)
	static func _tile_style(hot: bool) -> StyleBoxFlat:
		var style := DeepUi.ledger(Color("3d1612") if hot else Color("1c2232"), DeepUi.BAD if hot else DeepUi.LEDGER_LINE, 6, 3, 2, 0)
		style.content_margin_left = 7
		style.content_margin_right = 8
		return style
	static func _tile_figure(move: Dictionary) -> Array:
		## The one number a move's tile wears: its first effect's, when it has a plain one.
		for effect in move.get("effects", []):
			if not effect is Dictionary:
				continue
			var kind: String = str(effect.get("kind", ""))
			var parts: Dictionary = DeepCreatures.amount_parts(effect.get("amount", 0))
			var words: String = str(parts.base) if not parts.is_empty() else DeepCreatures.amount_words(effect.get("amount", 0))
			if not words.is_valid_int():
				continue
			var tone: Color = DeepUi.EFFECT_KEYWORDS.get(kind, {}).get("color", DeepUi.INFO)
			if kind == "heal":
				words = "+" + words
			return [words, tone]
		return ["", DeepUi.PAPER]
	func _state_tiles(foe: Dictionary, states: Array) -> void:
		## The move it is winding up, or acting out, burns red; one it has used, missed or had
		## clouded steps back.
		for index in range(_tiles.size()):
			var status: String = str(states[index]) if index < states.size() else "unrevealed"
			if DeepCreatures.move_clouded(foe, index):
				status = "clouded"
			var tile: PanelContainer = _tiles[index]
			var hot: bool = status in ["activated", "resolving"]
			if bool(tile.get_meta("hot", false)) != hot or not tile.has_meta("hot"):
				tile.set_meta("hot", hot)
				tile.add_theme_stylebox_override("panel", _tile_style(hot))
			tile.modulate.a = 0.4 if status in ["missed", "clouded", "spent"] else (0.65 if status in ["used", "resolved"] else 1.0)
	static func _short_effect(effect: Dictionary) -> String:
		## The inspector's words for an effect, with what goes without saying on a plate left
		## off: that a blow lands on every player, the rounding, the asides.
		var words: String = DeepCreatures.effect_words(effect)
		for cut in [" · all players", " (rounded up)", " · nothing more"]:
			words = words.replace(cut, "")
		return words
	func _build_lines(foe: Dictionary, moves: Array) -> void:
		## The plate opened: a line a move, and one a trait. The trigger is a pictograph with a
		## few words, the effect the words the inspector uses, their keywords colored.
		DeepUi.clear(_lines)
		DeepUi.rule(_lines, DeepUi.LEDGER_LINE).custom_minimum_size = Vector2(0, 2)
		for move in moves:
			var line := DeepUi.hbox(_lines, 8)
			var named := DeepUi.label(line, str(move.name), 12, Color.WHITE)
			named.add_theme_font_override("font", DeepUi.bold_font())
			named.custom_minimum_size.x = 70
			named.clip_text = true
			var described: Dictionary = DeepPatterns.describe(move.get("trigger", {"kind": "always"}), 0)
			described.label = ""
			if str(described.kind) in ["all_odd", "all_even"]:
				described.mark = "odd" if str(described.kind) == "all_odd" else "even"
			var when := DeepUi.hbox(line, 3)
			when.custom_minimum_size.x = 78
			when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			DiceIcons.build(when, described, 12, DeepUi.MUTED, DeepCreatures.trigger_words(move))
			var short: String = _short_trigger(move)
			if not short.is_empty():
				var trig := DeepUi.label(when, short, 10, DeepUi.MUTED)
				trig.clip_text = true
				trig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var said := DeepUi.vbox(line, 0)
			said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var words: Array = move.get("effects", []).map(func(e: Dictionary) -> String: return _short_effect(e))
			var text := DeepUi.effect_text(said, " · ".join(words), 11, DeepUi.PAPER)
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var traits: Dictionary = DeepCreatures.traits_for(foe) if foe.has("key") else {}
		var keys: Array = traits.keys()
		keys.sort()
		for key in keys:
			if str(key) == "gift_rerolls" and (traits.has("reroll_drain") or traits.has("reroll_scorch")):
				continue
			var trait_words: Dictionary = EffectChips.trait_entry(str(key), traits[key])
			var line := DeepUi.hbox(_lines, 8)
			var named := DeepUi.label(line, str(trait_words.title), 12, Color("d7b8ff"))
			named.add_theme_font_override("font", DeepUi.bold_font())
			named.custom_minimum_size.x = 64
			named.clip_text = true
			var when := DeepUi.hbox(line, 3)
			when.custom_minimum_size.x = 78
			when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			DeepUi.icon(when, str(trait_words.glyph), 12, Color("b58cff"))
			DeepUi.label(when, "always", 10, Color("c9b3f0"))
			var said := DeepUi.vbox(line, 0)
			said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var text := DeepUi.effect_text(said, str(trait_words.text), 11, Color("c9b3f0"))
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static func _short_trigger(move: Dictionary) -> String:
		## The trigger in two or three words beside its pictograph.
		var t: Dictionary = move.get("trigger", {"kind": "always"})
		var n: int = DeepPatterns.rung(t, 0)
		match str(t.get("kind", "always")):
			"always": return "every roll"
			"odd": return "odd roll"
			"even": return "even roll"
			"at_least": return "%d+" % n
			"at_most": return "≤%d" % n
			"value": return "/".join(t.get("values", []).map(func(v: Variant) -> String: return str(int(v))))
			"crowns": return "top face"
			"high_pct_at_least": return "high roll"
			"each_turn": return "each action"
			"every_nth_turn": return "every %s" % DeepPatterns._ordinal(n)
			"emerge": return "coming up"
			"on_death": return "on death"
			"hp_below": return "at %d%% hp" % n
			"action_begin": return "action opens"
			"pair", "triple", "quad", "quint": return ("%d+ " % n if n > 1 else "") + "once/turn"
			"straight": return "run of %d" % n
			"all_odd": return "all odd"
			"all_even": return "all even"
		return ""
	func power(index: int) -> void:
		## A move being acted out: its tile jumps.
		if index >= 0 and index < _tiles.size():
			DeepUi.pulse(_tiles[index], 1.15, 0.3)
	func impact(index: int) -> void:
		if index >= 0 and index < _tiles.size():
			DeepUi.pulse(_tiles[index], 1.06, 0.25)
		else:
			DeepUi.pulse(self, 1.03, 0.3)
	func fade(gone: Callable = Callable()) -> void:
		## Out, and then freed: `gone` is told first, so the screen can drop it from its book.
		fading = true
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void:
			visible = false
			if gone.is_valid():
				gone.call()
			queue_free())

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
	## crosses to the right only when it would stand in front of a creature there and the
	## right is clearer.
	if _enemy_panel == null or not _enemy_panel.visible:
		return
	var right: float = size.x - 20.0
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

func _inspect_die(id: String, owner_id: String = "") -> void:
	var unit: Dictionary = DeepBattle.player(state, local_id if owner_id.is_empty() else owner_id)
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
	if not state.is_empty():
		_sync_plates()
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
		if str(state.get("phase", "")) == "resolving":
			_hurry()
			return
		var id := _creature_at(event.position)
		if not id.is_empty():
			_target(id)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var id := _creature_at(event.position)
		if not id.is_empty():
			_inspect_creature(id, "")

# --- space ---------------------------------------------------------------------------------

func _hurry_input(event: InputEvent) -> void:
	## A click on the dock while a turn plays out hurries it, like one in the room.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and str(state.get("phase", "")) == "resolving":
		_hurry()

func _hurry() -> void:
	## Asks the clock to hurry the turn along, and says it was heard: the hint over the tray
	## jumps and a pair of chevrons runs off it, no more often than the eye can follow.
	command.emit({"kind": "hurry"})
	var now: int = Time.get_ticks_msec()
	if _headless or now - _hurried_at < 260:
		return
	_hurried_at = now
	var page: Page = _page_for(_shown_owner())
	var hint: Label = page.hint if page != null else null
	if hint != null and is_instance_valid(hint) and hint.is_visible_in_tree():
		DeepUi.pulse(hint, 1.12, 0.25)
		_float_at(hint, "»", DeepUi.ACCENT_HI, 24)
	DeepAudio.play("ui_tap", {"volume": 0.35, "gap": 0.05})

var _hurried_at: int = 0
## How often the creature's table is checked against the room, and when it is next due.
const PANEL_EVERY: float = 0.1
var _panel_clock: float = 0.0
var _panel_placed_size: Vector2 = Vector2.ZERO

func _to_screen(point: Vector3) -> Vector2:
	return stage.to_screen(point) + (stage.global_position - global_position)

func _from_screen(local: Vector2, distance: float) -> Vector3:
	return stage.from_screen(local - (stage.global_position - global_position), distance)

func _control_world(control: Control, distance: float = 1.8) -> Vector3:
	## A point in the room just in front of the camera, behind a control on the HUD.
	var local: Vector2 = control.global_position + control.size * 0.5 - global_position
	return _from_screen(local, distance)

func _process(delta: float) -> void:
	## The table is weighed against the creatures a few times a second rather than every
	## frame, and at once whenever it has changed size.
	_panel_clock -= delta
	if _enemy_panel != null and is_visible_in_tree() and (_panel_clock <= 0.0 or _enemy_panel.size != _panel_placed_size):
		_panel_clock = PANEL_EVERY
		_panel_placed_size = _enemy_panel.size
		_position_enemy_panel()
	## The party's tabs stand on the dock, from its left edge (clear of the chart, when it is
	## open): their bottom edge is its top edge, wherever it grows to.
	if _tab_bar != null and _dock != null:
		_tab_bar.reset_size()
		_tab_bar.position = Vector2(_dock.position.x + 18.0 + left_inset, _dock.position.y - _tab_bar.size.y)
	if _opening_due and not _headless and is_visible_in_tree() and stage != null and not stage.walking() and not state.is_empty():
		_opening_due = false
		_later_do(0.5, _turn_opening)
	if _headless or _camera == null or not is_visible_in_tree():
		return
	## The plates ride above the creatures' heads. `highest` is how far the worst of them
	## sits below the top of the screen, which is what the camera frames by.
	var ceiling: float = 72.0
	var highest: float = INF
	var placed: Array = []
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
		var footing: float = plate.base_height()
		var goal: Vector2 = screen - Vector2(plate.size.x * 0.5, footing + 12)
		if not plate.fading and not bool(creature.get_meta("dying", false)):
			highest = minf(highest, goal.y)
		if goal.y < ceiling:
			## No room over its head: the plate stands beside it instead of across its face.
			var body: Vector2 = _to_screen(stood + Vector3(0, creature.anchor.y * 0.55, 0))
			var reach: float = absf(_to_screen(stood + Vector3(1.2 * creature.scale.x, 0, 0)).x - _to_screen(stood).x)
			var right_side: bool = body.x < size.x * 0.6
			goal = Vector2(body.x + reach + 16.0 if right_side else body.x - reach - 16.0 - plate.size.x, body.y - footing * 0.5)
		goal.x = clampf(goal.x, 8.0, size.x - plate.size.x - 8.0)
		goal.y = clampf(goal.y, ceiling, size.y - footing - 260.0)
		placed.append([plate, goal])
	## Creatures that stand close (a slime split three ways) put their plates over each other,
	## hiding the health of all but the last. Left to right, a plate that would cover the one
	## before it steps up above it, or down below it where there is no room above.
	placed.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector2).x < (b[1] as Vector2).x)
	var taken: Array = []
	for entry in placed:
		var plate: Plate = entry[0]
		var goal: Vector2 = entry[1]
		for _try in range(3):
			var rect := Rect2(goal, Vector2(plate.size.x, plate.base_height())).grow(3.0)
			var hit: Rect2 = Rect2()
			for other in taken:
				if rect.intersects(other):
					hit = other
					break
			if hit.size == Vector2.ZERO:
				break
			var above: float = hit.position.y - plate.base_height() - 6.0
			goal.y = above if above >= ceiling else hit.end.y + 6.0
		taken.append(Rect2(goal, Vector2(plate.size.x, plate.base_height())))
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
	## The click that let go of a long press already turned the die over: it is not a pick.
	if _long_pressed == id:
		_long_pressed = ""
		return
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or bool(unit.get("locked", false)) or (int(unit.get("rerolls", 0)) <= 0 and int(unit.get("flips", 0)) <= 0):
		return
	## All or Nothing: no die is picked out; the whole bowl goes again or none of it.
	if DeepBattle.all_or_nothing(unit):
		if not _headless:
			_float_at(_tray_box, "All or Nothing: Reroll throws every die", DeepUi.INFO, 14)
		return
	if selected.has(id):
		selected.erase(id)
		DeepAudio.play("die_drop", {"gap": 0.0})
	else:
		selected.append(id)
		DeepAudio.play("die_pick", {"gap": 0.0})
	_sync()

func _reroll() -> void:
	var whole_bowl: bool = DeepBattle.all_or_nothing(me())
	if selected.is_empty() and not whole_bowl:
		return
	## Rerolling before Study's reroll has been counted on: it is simply there.
	_study_lag = 0
	var thrown: Array = DeepDice.rerollable(me().get("hand", [])) if whole_bowl else selected.duplicate()
	command.emit({"kind": "reroll", "dice": thrown})
	DeepAudio.play("dice_reroll", {"volume": 0.8})
	if not _headless:
		for id in thrown:
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
	## Sleight, from its button or F: the one chosen die turns over.
	if selected.size() != 1 or int(me().get("flips", 0)) <= 0 or bool(me().get("locked", false)):
		return
	if not _shift_refusal().is_empty():
		DeepAudio.play("ui_back", {"volume": 0.6})
		return
	_turn_die(str(selected[0]))
	selected.clear()

func _turn_roll(id: String) -> Dictionary:
	## The reader's own roll on that die, or {} (a phantom is not a die that turns).
	for roll in me().get("hand", []):
		if str(roll.get("die_id", "")) == id and not bool(roll.get("phantom", false)):
			return roll
	return {}

func _can_turn(id: String) -> bool:
	## Whether Sleight can turn that die over right now: Puck's, while planning, unlocked, with a
	## turn left, and a die with a face of the other parity to land on.
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or bool(unit.get("locked", false)) or bool(unit.get("downed", false)):
		return false
	if int(unit.get("flips", 0)) <= 0 or str(unit.get("passive", {}).get("kind", "")) != "free_flip":
		return false
	var roll: Dictionary = _turn_roll(id)
	return not roll.is_empty() and DeepBattle.shift_refusal(unit, roll).is_empty()

func _turn_value(id: String) -> int:
	## The number the die would show turned over, or -1 when it cannot turn.
	if not _can_turn(id):
		return -1
	var unit: Dictionary = me()
	var roll: Dictionary = _turn_roll(id)
	var face: int = DeepBattle.shift_face(unit, roll)
	for die in unit.get("dice", []):
		if str(die.get("id", "")) == id and face >= 0 and face < die.get("faces", []).size():
			return DeepDice.face_value(die.faces[face])
	return -1

func _turn_die(id: String) -> void:
	## Sleight: the die turns over onto the face underneath, by right-click, a long press, its
	## button or F.
	if not _can_turn(id):
		return
	command.emit({"kind": "flip", "die": id})
	DeepAudio.play("die_pick", {"volume": 0.9})
	if not _headless and _dice_views.has(id):
		var view: Control = _dice_views[id]
		DeepUi.burst(self, view.global_position - global_position + view.size * 0.5, DeepUi.ACCENT_HI, 16, 150.0, 0.5)
	selected.erase(id)
	_show_ghost(id, false)

func _press_start(id: String) -> void:
	## A die held down for a moment turns over, without the pick-then-button dance.
	_long_pressed = ""
	if _headless or not _can_turn(id):
		return
	_pressing = id
	_press_token += 1
	var token: int = _press_token
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(self) and not state.is_empty() and _pressing == id and _press_token == token:
			_pressing = ""
			_long_pressed = id
			_turn_die(id))

func _press_end(id: String) -> void:
	if _pressing == id:
		_pressing = ""

func _show_ghost(id: String, on: bool) -> void:
	## Hovering a die Sleight can turn shows the face it would land on, as a ghost on the die.
	if _headless or not _dice_views.has(id) or not is_instance_valid(_dice_views[id]):
		return
	var holder: Node = (_dice_views[id] as Control).get_parent()
	var ghost: Label = holder.get_node_or_null("Ghost")
	var value: int = _turn_value(id) if on else -1
	if ghost == null:
		if value < 0:
			return
		ghost = DeepUi.label(holder, "", 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		ghost.name = "Ghost"
		ghost.position = Vector2(DIE_EDGE - 38, -8)
		ghost.size = Vector2(40, 18)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 2
		ghost.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
		ghost.add_theme_constant_override("outline_size", 5)
	ghost.visible = value >= 0
	if value >= 0:
		ghost.text = "⇅ %d" % value
		ghost.add_theme_color_override("font_color", MotleyFx.CRUEL if value % 2 == 1 else MotleyFx.KIND)

func _parity_rim(holder: Node, roll: Dictionary, unit: Dictionary) -> void:
	## Puck's dice wear their parity: a pink rim light for odd, green for even, the two halves of
	## her tourmaline, so the face the hand wears can be read straight off the tray.
	if holder == null or not holder is Control:
		return
	var rim: Panel = holder.get_node_or_null("ParityRim")
	var value: int = int(roll.get("value", 0))
	var wanted: bool = str(unit.get("passive", {}).get("kind", "")) == "free_flip" and value > 0 and str(roll.get("kind", "plain")) != "blank"
	if rim == null and wanted:
		rim = Panel.new()
		rim.name = "ParityRim"
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.position = Vector2(-2, -2)
		rim.size = Vector2(DIE_EDGE + 4, DIE_EDGE + 4)
		holder.add_child(rim)
		holder.move_child(rim, 0)
	if rim == null:
		return
	rim.visible = wanted
	if wanted:
		var tone: Color = MotleyFx.CRUEL if value % 2 == 1 else MotleyFx.KIND
		if not rim.has_meta("tone") or Color(rim.get_meta("tone")) != tone:
			rim.set_meta("tone", tone)
			rim.add_theme_stylebox_override("panel", DeepUi.flat(Color(tone, 0.07), Color(tone, 0.8), 10, 0, 2))

func _sync_face(page: Page, unit: Dictionary) -> void:
	## Puck's tray says which face the hand wears and how far it is from a full one, and the
	## Changing Face what the other face from last turn's would pay: ×2, ×3 as the run goes on.
	var harlequin: bool = str(unit.get("passive", {}).get("kind", "")) == "free_flip"
	var downed: bool = bool(unit.get("downed", false))
	var pays: int = DeepBattle.next_face_pays(unit) if harlequin and not downed else 1
	var last: String = str(unit.get("last_face", ""))
	var other: String = "the Kind Face" if last == "odd" else "the Cruel Face"
	if page.face_chip != null:
		page.face_chip.visible = harlequin and not downed and not unit.get("hand", []).is_empty()
		if page.face_chip.visible:
			var odd: int = 0
			var even: int = 0
			var seen: Dictionary = {}
			for roll in unit.get("hand", []):
				var value: int = int(roll.get("value", 0))
				if value <= 0:
					continue
				if value % 2 == 1:
					odd += 1
				else:
					even += 1
				seen[value] = true
			var cruel: bool = odd >= even
			var away: int = mini(odd, even)
			var full: String = "the Cruel Face" if cruel else "the Kind Face"
			var words: String = "%d cruel · %d kind" % [odd, even]
			if away == 0 and odd + even > 0:
				words += " · Full Motley" if seen.size() == odd + even else " · " + full
			elif away > 0:
				words += " · %s from %s" % ["one" if away == 1 else str(away), full]
			page.face_chip.text = words
			page.face_chip.add_theme_color_override("font_color", MotleyFx.CRUEL if cruel else MotleyFx.KIND)
	## The run, written beside the count the way On Fire's ×2 is.
	var mark: Label = page.resonance_box.get_node_or_null("Change") if page.resonance_box != null else null
	if mark == null and pays > 1 and page.resonance_box != null:
		mark = DeepUi.title(page.resonance_box, "", 18, MotleyFx.CRUEL)
		mark.name = "Change"
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
	if mark != null:
		mark.visible = pays > 1
		if pays > 1:
			mark.text = "×%d" % pays
			mark.add_theme_color_override("font_color", MotleyFx.KIND if last == "odd" else MotleyFx.CRUEL)
			mark.tooltip_text = "The Changing Face: show %s this turn and Motley pays ×%d. The same face again starts over." % [other, pays]
	if page.mine and _motley_fx != null:
		_motley_fx.set_level(pays, last)

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
	## Space while a turn plays out hurries it, which only the clock hears.
	if str(state.get("phase", "")) == "resolving" and event.keycode == KEY_SPACE:
		_hurry()
		get_viewport().set_input_as_handled()
		return
	## Tab turns the dock to the next player's page (Shift+Tab, the one before).
	if event.keycode == KEY_TAB and _party():
		var order: Array = [local_id]
		for member in state.get("players", []):
			if str(member.get("id", "")) != local_id:
				order.append(str(member.get("id", "")))
		var at: int = order.find(_shown_owner())
		_pick_tab(order[posmod(at + (-1 if event.shift_pressed else 1), order.size())])
		get_viewport().set_input_as_handled()
		return
	## The hand's keys only mean something while it is being planned. Pressed while a turn
	## plays out they used to reach the rules anyway and come back as a red refusal.
	var unit: Dictionary = me()
	if str(state.get("phase", "")) != "planning" or unit.is_empty() or bool(unit.get("downed", false)):
		return
	## They are the reader's own hand's keys: pressed while someone else's page is up, they
	## turn the dock back to the reader's first.
	if event.keycode in [KEY_R, KEY_SPACE, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5] and not _is_shown(local_id):
		_show_page(local_id)
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
				_pending_crowns = entry.get("crowned", [])
		for battery in event.get("charged", []):
			if str(battery.unit) == local_id:
				_charge_resonance(int(battery.amount))
			else:
				_float_at(_tab_anchor(str(battery.unit)), "+%s Charged" % DeepUi.number(int(battery.amount)), DeepUi.ACCENT_HI, 16)
	var unit_id: String = str(event.get("unit", ""))
	## Every rail climbs from the bottom of the scale again, in whatever key is playing.
	if kind in ["turn_begin", "resolution_begin", "rail_begin"]:
		_chain.reset()
	if kind == "rail_begin" and _page_for(unit_id) != null:
		_page_for(unit_id).last_fired = -1
	if kind in ["turn_begin", "resolution_begin"]:
		for page in _all_pages():
			page.last_fired = -1
			page.turn_dealt = 0
			if page.dealt_box != null:
				page.dealt_box.visible = false
				page.dealt_label.text = "0"
	if kind == "turn_begin":
		_preview_count(-1)
	## What each rail really did this turn, kept so its highlights follow the dice.
	if kind in ["turn_begin", "resolution_begin"]:
		for page in _all_pages():
			page.outcomes.clear()
			page.birth_outcome = {}
	elif _page_for(unit_id) != null:
		var page: Page = _page_for(unit_id)
		match kind:
			"gem_fire": page.outcomes[int(event.get("socket", -1))] = true
			"gem_fizzle": page.outcomes[int(event.get("socket", -1))] = false
			"birthstone": page.birth_outcome = event
	## The dock follows the turn: whoever's rail is firing has their page up, and the reader's
	## own comes back for the creatures and for the next turn. A tab turns to anyone in between.
	match kind:
		"turn_begin", "resolution_begin":
			_firing_id = ""
			_fired.clear()
			_last_rail_id = ""
			if kind == "turn_begin":
				_show_page(local_id)
			_sync_tabs()
		"rail_begin":
			## The turn passes from the tab whose rail just closed to this one's.
			var handed: Control = _tab_anchor(_last_rail_id) if not _last_rail_id.is_empty() else null
			_firing_id = unit_id
			_last_rail_id = unit_id
			_show_page(unit_id)
			_sync_tabs()
			_baton(handed, _tab_anchor(unit_id), _seat_tone(unit_id))
		"rail_end", "skip":
			if _is_player(unit_id):
				_fired[unit_id] = true
				if _firing_id == unit_id:
					_firing_id = ""
				_sync_tabs()
		"enemy_begin", "tick":
			if not _firing_id.is_empty() or not _is_shown(local_id):
				_firing_id = ""
				_show_page(local_id)
				_sync_tabs()
	## A creature's move being acted out, or landing, is said on its plate.
	var acting_plate: Variant = _plates.get(unit_id, null)
	if acting_plate is Plate and is_instance_valid(acting_plate):
		match kind:
			"enemy_ability": (acting_plate as Plate).power(int(event.get("index", -1)))
			"enemy_move": (acting_plate as Plate).impact(int(event.get("index", -1)))
	match kind:
		"enemy_roll": _show_enemy_roll(event)
		"enemy_end", "skip", "battle_over", "turn_begin":
			_hide_enemy_roll()
			_brace({})
	## A turn's passives are shown once the room is up: straight away, or once the walk in ends.
	if kind == "turn_begin":
		_opening_due = true
	if _headless or stage.walking():
		return
	if kind != "gem_fire":
		_watch_infinity(event)
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
			var crowns: Array = _pending_crowns
			_pending_dues = {}
			_pending_regrown = {}
			_pending_crowns = []
			_later_do(0.55, func() -> void:
				_dice_regrown(back)
				_dice_dues(owed, _dice_views.keys())
				_crowns_ring(crowns))
		"resolution_begin":
			DeepAudio.play("resolve", {"volume": 0.75})
			_announce("Resolve", DeepUi.ACCENT, "", 0.5)
			_camera.punch(-3.0, 0.8)
			_screen_fx.blink(DeepUi.ACCENT, 0.06)
		"rail_begin":
			if _page_for(unit_id) != null:
				_show_resonance(int(event.get("resonance", 0)), _page_for(unit_id))
		"gem_fire":
			_gem_fire(event)
			if str(event.get("unit", "")) == local_id:
				_crowns_ring(event.get("crowned", []))
				if int(event.get("backlash", 0)) > 0:
					DeepAudio.play("enemy_strike", {"volume": 0.5})
					_screen_fx.wound(0.4)
					_float_at(_hp_bar, "−%d Backlash" % int(event.backlash), Color("ff8ad8"), 18)
				if bool(event.get("damped", false)):
					_float_at(_resonance_box, "Dampened", Color("c8b8ff"), 14)
			## A Refractor drinking in a color it had not seen: a point of Strength more.
			for fed in event.get("fed", []):
				var drinker: CrystalCreature = _creature(str(fed.get("unit", "")))
				if drinker != null:
					var hue := Color("#" + str(DeepContent.color(str(fed.get("color", ""))).get("hue", "c8a8ff")))
					drinker.flash(1.4)
					_fx.rise(drinker.centre(), hue, 14, 0.5)
					_float_world(drinker.centre() + Vector3(0, 0.7, 0), "+1 Strength", hue, 15)
		"rail_spent":
			_rail_spent(event)
		"gem_fizzle":
			_gem_fizzle(event)
		"birthstone":
			_birthstone_fire(event)
		"reroll":
			if str(event.get("unit", "")) == local_id:
				_later_do(0.4, func() -> void:
					_dice_dues(event.get("dues", {}), event.get("dice", []))
					_crowns_ring(event.get("crowned", [])))
				## The last reroll spent, there is nothing left to decide: the hand locks itself
				## once its dice have been seen to land. Unlock takes it back.
				_later_do(1.3, _lock_if_spent)
		"flip":
			if str(event.get("unit", "")) == local_id:
				DeepAudio.play("die_settle", {"volume": 0.8})
				_float_at(_tray_box, "Turned over to %d" % int(event.get("value", 0)), DeepUi.ACCENT_HI, 16)
		"enemy_begin":
			var who: String = str(event.get("unit", ""))
			var up: CrystalCreature = _creature(who)
			if up != null:
				## Its turn: it lights up where it stands and a ring goes out under it.
				up.flash(0.8)
				_fx.ring_wave(Vector3(up.global_position.x, 0.0, up.global_position.z), Color(DeepUi.BAD, 0.7), 1.2, 0.4, 0.08)
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
				## Its guard comes down as it acts again: the barrier breaks.
				if bool(event.get("guard_ended", false)) and up.has_barrier():
					_fx.shards(up.barrier_point(), Color("dcd4ff"), 12, 3.0, 0.1, 0.9)
					up.set_barrier("")
				if int(event.get("heads_grown", 0)) > 0:
					DeepAudio.play_at(global_position + _to_screen(up.centre()), "rock_break", {"volume": 0.7})
					_fx.sparks(up.centre() + Vector3(0, 0.5, 0), Color("c070ff"), 40, 3.5, 0.8, 0.06)
					_fx.glow_burst(up.centre(), Color("c070ff"), 2.4, 0.5)
					up.flash(3.0)
					_float_world(up.centre() + Vector3(0, 1.1, 0), "Grows %d heads back · %d now" % [int(event.heads_grown), int(event.get("heads", 0))], Color("d8a6ef"), 20)
				if bool(event.get("held_back", false)):
					_fx.puff(up.centre(), Color("b8c84a"), 12, 0.7, 1.0, 0.5)
					_float_world(up.centre() + Vector3(0, 1.1, 0), "Held back: the count starts again", DeepUi.GOOD, 18)
				## What it has been counting toward comes now.
				for name in event.get("due", []):
					_fx.ring_wave(Vector3(up.global_position.x, 0.0, up.global_position.z), Color("ffb05a"), 3.5, 0.6)
					_float_world(up.global_position + Vector3(0, up.anchor.y + 0.6, 0), str(name) + "!", Color("ffb05a"), 22)
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
			## Second Wind is paid as the rail closes, on the Resonance it built: counted out.
			if not event.get("count", {}).is_empty():
				_second_wind(event)
			## The rail that closed says what it came to, on its own page if that page is up.
			var closing: Page = _page_for(unit_id)
			if closing != null and _is_shown(unit_id):
				if closing.turn_dealt > 0:
					_dealt_flourish(closing)
				if resonance >= 3:
					## The chain pays off a step higher for every stone in it.
					DeepAudio.from(closing.resonance_box, "resonance", {"pitch": 1.0 + 0.09 * float(mini(resonance, 8)), "volume": 0.8 if closing.mine else 0.6})
					_float_at(closing.resonance_box, "Resonance ×%s" % DeepUi.number(resonance), _resonance_color(resonance), 20)
					DeepUi.burst(self, _center_of(closing.resonance_box), _resonance_color(resonance), 20 + mini(resonance, 30) * 4, 180.0, 0.7)
		"enemy_ability":
			_enemy_windup(event)
			_count_creature(event)
			_brace(event.get("tally", {}))
		"enemy_move":
			_brace({})
			_enemy_move(event)
		"tick":
			_leech_token += 1
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
			elif _is_player(who):
				_float_at(_tab_anchor(who), "Stunned", Color("ffe27a"), 16)
		"battle_over":
			var won: bool = str(event.get("outcome", "")) == "victory"
			_won = won
			if won:
				_cash_out()
			_house_shown = false
			for player in state.get("players", []):
				_show_mood(str(player.get("id", "")))
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
	if hurt and int(tick.get("amount", 0)) > 0:
		_react(target_id, "wince", 0.7)
	if str(tick.get("kind", "")) == "burn" and int(tick.get("soaked", 0)) > 0 and target_id == local_id:
		_float_at(_hp_bar, "%d burn blocked" % int(tick.soaked), DeepUi.BLOCK, 14)
	if hurt and int(tick.get("amount", 0)) + int(tick.get("soaked", 0)) > 0 and not _headless:
		var burning: bool = str(tick.get("kind", "")) == "burn"
		var where: Vector3 = Vector3.INF
		if target_id == local_id:
			where = _before_me(3.0, -0.5)
		elif _creatures.has(target_id) and is_instance_valid(_creatures[target_id]):
			where = (_creatures[target_id] as CrystalCreature).centre()
		if where != Vector3.INF:
			if burning:
				_fx.flames(where, 0.45, 0.6)
				_sound_at(where, "flame", 0.35)
			else:
				_fx.bubbles(where, DeepUi.POISON, 12, 0.5, 0.9)
	if (bool(tick.get("risen", false)) or tick.has("released") or tick.has("heads_cut")) and _creatures.has(target_id) and is_instance_valid(_creatures[target_id]):
		_hit_extras(tick, _creatures[target_id], (_creatures[target_id] as CrystalCreature).centre())
	if _creatures.has(target_id) and is_instance_valid(_creatures[target_id]):
		var creature: CrystalCreature = _creatures[target_id]
		DeepAudio.play_at(global_position + _to_screen(creature.centre()), "poison" if hurt else "heal", {"volume": 0.5})
		_fx.puff(creature.centre(), color, 10, 0.6, 1.0, 0.5, true)
		_float_world(creature.centre(), ("−" if hurt else "+") + DeepUi.number(int(tick.get("amount", 0))), color, 22)
		if hurt:
			creature.hit(0.3)
		if bool(tick.get("escorts", false)):
			_float_world(creature.centre() + Vector3(0, 0.5, 0), "fed by its tendrils", DeepUi.GOOD, 13)
		_thresholds(tick, creature)
		if bool(tick.get("killed", false)):
			_deathburst(tick, creature)
			_kill(creature)
	elif target_id == local_id and not hurt and int(tick.get("amount", 0)) <= 0:
		## Regrowth on a lapidary already whole.
		_float_at(_hp_bar, "Full", DeepUi.MUTED, 15)
	elif target_id == local_id:
		DeepAudio.play("poison" if hurt else "heal", {"volume": 0.6})
		_float_at(_hp_bar, ("−" if hurt else "+") + DeepUi.number(int(tick.get("amount", 0))), color, 22)
		_screen_fx.blink(color, 0.1)
	elif _is_player(target_id):
		_float_at(_vital_anchor(target_id), ("−" if hurt else "+") + DeepUi.number(int(tick.get("amount", 0))), color, 16)
		_tab_flash(target_id, color)
	## Leech: every poison that bites pays the Apothecary her Resonance, counted up over her
	## bar for as long as this round of poison keeps biting.
	for leech in tick.get("leech", []):
		var drinker: String = str(leech.get("unit", ""))
		if not _is_player(drinker):
			continue
		var token: int = _leech_token
		var beat: int = int(_leech_beat.get(drinker, [0, 0])[1]) + 1 if int(_leech_beat.get(drinker, [-1, 0])[0]) == token else 0
		_leech_beat[drinker] = [token, beat]
		var name: String = str(DeepBattle.player(state, drinker).get("passive", {}).get("name", "Leech"))
		var amount: int = int(leech.get("amount", 0))
		_later_do(0.14 * float(beat), func() -> void:
			if drinker == local_id:
				DeepAudio.play("heal", {"volume": 0.45})
			elif _tab_anchor(drinker) != null:
				_tab_flash(drinker, DeepUi.GOOD)
			_swell(drinker, name, "heal", amount, -token))

func _birthstone_fire(event: Dictionary) -> void:
	## The Birthstone at the end of a rail lights, then every tier the hand earned is called
	## out by name and counted on its own (the number Resonance multiplies, Resonance itself
	## streaming out of the rail's counter, the figure), and lands, before the next is called:
	## a Rally's Rank guards, then its File strikes.
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	var unit: Dictionary = DeepBattle.player(state, unit_id)
	var stone: Dictionary = DeepStone.birthstone_for(unit)
	var color: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	## Its own bezel when its player's page is up, their tab when it is not.
	var page: Page = _page_for(unit_id)
	var shown: bool = page != null and _is_shown(unit_id) and page.birthstone_card != null and is_instance_valid(page.birthstone_card)
	var anchor: Control = page.birthstone_card if shown else _tab_anchor(unit_id)
	if not bool(event.get("fired", false)):
		if anchor != null and shown:
			_float_at(anchor, "fizzle", DeepUi.DIM, 13)
			anchor.modulate = Color(0.6, 0.6, 0.7, 1.0)
			var tween := create_tween()
			tween.tween_property(anchor, "modulate", Color.WHITE, 0.6)
		return
	var lit: Array = event.get("tiers", []).filter(func(x: Dictionary) -> bool: return bool(x.get("active", false)))
	## A penalty tier (a Bust) is a loss, so it lights red, and alone it bursts red too.
	var penalties: Array = stone.get("tiers", []).filter(func(x: Dictionary) -> bool: return bool(x.get("penalty", false))).map(func(x: Dictionary) -> String: return str(x.get("name", "")))
	var busted: bool = lit.all(func(x: Dictionary) -> bool: return penalties.has(str(x.get("name", ""))))
	## Their face goes with it: their own Birthstone face, or a flinch for a Bust.
	_react(unit_id, "wince" if busted else "birthstone", 1.8)
	## High Roller's moments: a Bust snuffs the streak out at once; the Jackpot's slot machine
	## pays when its own tier is reached, below.
	if mine and not _headless:
		if busted and penalties.size() > 0 and _streak_fx != null:
			_streak_fx.snuff()
			_screen_fx.blink(Color(0.55, 0.65, 0.85), 0.25)
			_later_do(0.3, func() -> void: _fx.coins(_purse(), _purse() + Vector3(0, -1.6, 0.4), 8))
	if bool(event.get("doubled", false)) and anchor != null and not _headless:
		_float_at(_resonance_anchor(unit_id), "On Fire ×2", StreakFx.HOT, 18)
	## The Changing Face: the other face from last turn's, paying double and more. Her motley
	## bursts off the tray and the room is told how much.
	if int(event.get("change", 0)) > 0 and not _headless:
		var pays: int = int(event.change) + 1
		var face_tone: Color = MotleyFx.CRUEL if str(event.get("face", "")) == "odd" else MotleyFx.KIND
		if anchor != null:
			_float_at(_resonance_anchor(unit_id), "Changing Face ×%d" % pays, face_tone, 18)
		if mine:
			if _motley_fx != null:
				_motley_fx.change(str(event.get("face", "")), pays)
			_announce("CHANGING FACE", face_tone, "×%d" % pays, 1.1)
	if anchor != null:
		DeepAudio.from(anchor, "resonance", {"pitch": 1.1 + 0.08 * float(mini(lit.size(), 4)), "volume": 0.9, "gap": 0.02})
		var ring: SocketRing = anchor.get_node_or_null("Slot/Ring")
		if ring != null:
			ring.fire()
		DeepUi.spring(anchor, 0.24, 8.0, 0.55)
		if mine:
			DeepAudio.rumble(0.3, 0.3, 0.08)
		DeepUi.burst(self, _center_of(anchor), DeepUi.BAD if busted else color, 24 + 8 * lit.size(), 190.0, 0.6)
		if bool(event.get("replay", false)):
			_float_at(anchor, "Encore!", DeepUi.ACCENT_HI, 18)
	else:
		DeepAudio.play("resonance", {"volume": 0.7})
	## Everything the tiers will land is held on the bars until each lands, and a creature a
	## later tier kills is left standing for the blow.
	var landing: Array = []
	for entry in lit:
		landing.append_array(entry.get("effects", []))
	_mark_dying(landing)
	_hold_vitals(landing, unit_id)
	var at: float = DeepBattle.BIRTH_LEAD
	var step: int = mini(_chain.fired, Tally.TOP_START)
	for entry in lit:
		_later_do(at, _birth_tier.bind(unit_id, entry, color, step, penalties.has(str(entry.get("name", "")))))
		if mine and not _headless and str(entry.get("trigger", {}).get("kind", "")) == "crowns" and int(entry.get("trigger", {}).get("need", 0)) >= 5:
			_later_do(at, _jackpot.bind(entry))
		at += DeepBattle.tier_span(entry)
		step = mini(step + 2, Tally.TOP_START + 2)
	_birth_purse(event, at + 0.3)

func _birth_tier(unit_id: String, entry: Dictionary, color: Color, step: int, loss: bool) -> void:
	## One lit tier: its count over the Birthstone (or, small, over its player's tab), then
	## what it does, leaving from the stone as the figure flies.
	if state.is_empty():
		return
	var mine: bool = unit_id == local_id
	var count: Dictionary = entry.get("count", {})
	var effects: Array = entry.get("effects", [])
	## Each tier's blows are their own, for a Riposte growing off them.
	_blow_token[unit_id] = int(_blow_token.get(unit_id, 0)) + 1
	_close_swell(unit_id)
	var page: Page = _page_for(unit_id)
	var shown: bool = page != null and _is_shown(unit_id) and page.birthstone_card != null and is_instance_valid(page.birthstone_card)
	var span: float = DeepBattle.birth_span(count)
	var tone: Color = DeepUi.BAD if loss else color
	if not count.is_empty() and not _headless and is_inside_tree():
		var plate: ResonanceCount = _resonance_plate(unit_id, tone, step, shown)
		plate.gem_anchor = _birth_anchor.bind(unit_id)
		plate.destination = _figure_destination.bind(str(count.get("kind", "")), effects)
		plate.blaze = _kills(effects)
		plate.on_fuse = _count_fused
		add_child(plate)
		plate.play_tier(count)
	var go := func() -> void:
		var anchor: Control = _birth_anchor(unit_id)
		var origin: Vector3 = _control_world(anchor, 1.6) if anchor != null else _origin_for(unit_id, -1)
		if anchor != null and _is_shown(unit_id):
			DeepUi.spring(anchor, 0.18, 6.0, 0.4)
		_animate_effects(effects, origin, tone, mine, anchor, 1.0, unit_id)
	if span <= 0.0:
		go.call()
	else:
		_later_do(span, go)

func _birth_anchor(unit_id: String) -> Control:
	## A Birthstone's bezel while its player's page is up, else their tab.
	var page: Page = _page_for(unit_id)
	if page != null and _is_shown(unit_id) and page.birthstone_card != null and is_instance_valid(page.birthstone_card):
		return page.birthstone_card
	return _tab_anchor(unit_id)

func _resonance_plate(unit_id: String, tone: Color, step: int, shown: bool) -> ResonanceCount:
	## A count paid on a player's Resonance, wired to where its pieces come from: their rail's
	## Resonance count, their dice, their rerolls, their pot and purse.
	var mine: bool = unit_id == local_id
	var plate := ResonanceCount.new()
	plate.chain = _chain
	plate.start_step = step
	plate.color = tone
	plate.compact = not shown
	plate.volume = 1.0 if mine else (0.8 if shown else 0.45)
	plate.rumbles = mine
	plate.placement = "above"
	plate.ceiling = _dock_top
	plate.tick = DeepSoundBank.tick_sound("WHITE")
	plate.die_anchor = _counted_die.bind(unit_id) if shown else Callable()
	plate.flow_from = _resonance_anchor.bind(unit_id)
	plate.coef_anchor = func() -> Control: return _reroll_button if mine and _is_shown(unit_id) else null
	plate.pot_anchor = _pot_anchor.bind(unit_id)
	plate.bank_anchor = func() -> Control: return _bank_control() if mine else null
	plate.on_bank = _bank_moved.bind(unit_id)
	plate.on_pot = _pot_shows.bind(unit_id)
	return plate

func _resonance_anchor(unit_id: String) -> Control:
	## A player's Resonance count while their page is up, else their tab.
	var page: Page = _page_for(unit_id)
	if page != null and _is_shown(unit_id) and page.resonance_box != null and is_instance_valid(page.resonance_box):
		return page.resonance_box
	return _tab_anchor(unit_id)

func _figure_destination(kind: String, effects: Array) -> Vector2:
	## Where a counted figure flies as what it does leaves: the creature it lands on, the
	## health bar (or the tab) of the player a guard or a heal goes to, or the pyrite purse.
	if kind == "gold":
		var purse: Control = _purse_spot()
		return purse.get_global_rect().get_center() if purse != null else Vector2.INF
	for effect in effects:
		if str(effect.get("kind", "")) != kind:
			continue
		var target: String = str(effect.get("target", ""))
		var creature: CrystalCreature = _creature(target)
		if creature != null and not _camera.is_position_behind(creature.centre()):
			return global_position + _to_screen(creature.centre())
		var bar: Control = _vital_anchor(target) if _is_player(target) else null
		if bar != null:
			return bar.get_global_rect().get_center()
	return Vector2.INF

func _second_wind(event: Dictionary) -> void:
	## Second Wind, counted out as the rail closes: the rerolls left unspent, times the
	## Resonance the rail built, and the heal it comes to flown into the health bar.
	var unit_id: String = str(event.get("unit", ""))
	var count: Dictionary = event.get("count", {})
	var healed: int = int(event.get("healed", 0))
	var heal: Array = [ {"kind": "heal", "target": unit_id, "amount": int(count.get("amount", healed)), "healed": healed}]
	_hold_vitals(heal)
	var page: Page = _page_for(unit_id)
	var shown: bool = page != null and _is_shown(unit_id)
	var plate: ResonanceCount = _resonance_plate(unit_id, DeepUi.GOOD, mini(_chain.fired, Tally.TOP_START), shown)
	plate.gem_anchor = func() -> Control:
		var on: Page = _page_for(unit_id)
		return on.face if on != null and _is_shown(unit_id) and on.face != null else _tab_anchor(unit_id)
	plate.destination = _figure_destination.bind("heal", heal)
	add_child(plate)
	plate.play_tier(count)
	_later_do(DeepBattle.birth_span(count), func() -> void:
		_animate_effects(heal, Vector3.ZERO, DeepUi.GOOD, unit_id == local_id, null, 1.0, unit_id))

# --- passives that pay as blows land ---------------------------------------------------------

func _swell(id: String, title: String, kind: String, amount: int, token: int) -> void:
	## A figure over a player's bar that grows with every blow one gem of theirs lands (a
	## Riposte's guard) or every poison that pays them (a Leech): a step up the scale each
	## time, and flown into the bar once nothing more has landed for a moment. A new gem's
	## blows close the last one's and start again.
	var held: Dictionary = _swells.get(id, {})
	if not held.is_empty() and int(held.token) != token:
		_close_swell(id)
		held = {}
	if held.is_empty():
		var page: Page = _page_for(id)
		var shown: bool = page != null and _is_shown(id)
		var plate: ResonanceCount = null
		if not _headless and is_inside_tree():
			plate = ResonanceCount.new()
			plate.chain = Tally.Chain.new()
			plate.chain.reset()
			plate.start_step = 0
			plate.compact = not shown
			plate.color = DeepUi.BLOCK if kind == "block" else DeepUi.GOOD
			plate.volume = 0.9 if id == local_id else 0.5
			plate.rumbles = id == local_id
			plate.placement = "above"
			plate.ceiling = _dock_top
			plate.tick = DeepSoundBank.tick_sound("BLUE" if kind == "block" else "GREEN")
			plate.gem_anchor = func() -> Control:
				var on: Page = _page_for(id)
				return on.face if on != null and _is_shown(id) and on.face != null else _tab_anchor(id)
			plate.destination = func() -> Vector2:
				var bar: Control = _vital_anchor(id)
				return bar.get_global_rect().get_center() if bar != null else Vector2.INF
			add_child(plate)
			plate.open_swell(title, kind)
		held = {"plate": plate, "token": token, "total": 0, "kind": kind, "timer": 0}
		_swells[id] = held
	held.total = int(held.total) + amount
	held.timer = int(held.timer) + 1
	if held.plate != null and is_instance_valid(held.plate):
		(held.plate as ResonanceCount).swell(amount)
	var mark: int = int(held.timer)
	_later_do(0.7, func() -> void:
		var still: Dictionary = _swells.get(id, {})
		if not still.is_empty() and int(still.token) == token and int(still.timer) == mark:
			_close_swell(id))

func _close_swell(id: String) -> void:
	## The swell flies into the bar, and the guard it carried lands there with it.
	var held: Dictionary = _swells.get(id, {})
	_swells.erase(id)
	if held.is_empty():
		return
	if held.plate != null and is_instance_valid(held.plate):
		(held.plate as ResonanceCount).close_swell()
	if str(held.kind) == "block":
		var total: int = int(held.total)
		_later_do(0.2, func() -> void:
			_land_vitals(id, 0, -total)
			if id == local_id:
				DeepAudio.play("block", {"volume": 0.6})
				_float_at(_hp_bar, "+%s block" % DeepUi.number(total), DeepUi.BLOCK, 18))

# --- the Gambler's pot and purse -------------------------------------------------------------

func bank_shown(id: String, live: int, battle: Dictionary = {}) -> int:
	## What a player's purse should read in the strip over the fight: `live` (what the bank
	## holds now), unless coins are still on their way out of it or into it, or House Money
	## has yet to be seen leaving it. `battle` is the fight as the strip reads it, which may
	## be newer than the one this screen has been shown.
	if _bank_held.has(id):
		return int(_bank_held[id])
	var unit: Dictionary = DeepBattle.player(battle, id)
	return live + int(unit.get("pot", 0)) if _house_due(unit, battle) else live

func _house_due(unit: Dictionary, battle: Dictionary) -> bool:
	## The reader is the Gambler, his first turn is still being chosen and House Money has not
	## been seen going onto the table: the pot reads empty and the purse whole until it is.
	return not _house_shown and not _headless and str(unit.get("id", "")) == local_id and str(unit.get("passive", {}).get("kind", "")) == "pot_share" and int(unit.get("pot", 0)) > 0 and int(battle.get("turn", 0)) == 1 and str(battle.get("phase", "")) == "planning"

func _bank_live(id: String) -> int:
	## What the bank holds this moment of the fight: what they came down with, and whatever
	## the fight has taken out or put in since (a stake, a Wager, a Golden face).
	var unit: Dictionary = DeepBattle.player(state, id)
	return maxi(0, int(unit.get("ore", 0)) + int(unit.get("pyrite_delta", 0)))

func _bank_control() -> Control:
	var found: Variant = bank_anchor.call() if bank_anchor.is_valid() else null
	return found as Control if found is Control and is_instance_valid(found) and (found as Control).is_inside_tree() else null

func _bank_moved(delta: int, unit_id: String) -> void:
	## Coins have left the purse (or come back to it): it reads that much less (or more).
	if _bank_held.has(unit_id):
		_bank_held[unit_id] = int(_bank_held[unit_id]) + delta
	if unit_id == local_id:
		bank_changed.emit(delta)

func _purse_spot() -> Control:
	## Where pyrite the reader wins or spends is said: over the purse on the strip, or failing
	## that over their Resonance line in the dock.
	var purse: Control = _bank_control()
	return purse if purse != null else _local_page.resonance_box

func _pot_shows(value: int, unit_id: String) -> void:
	## The pot reads a new figure: the coins staked have landed on it, or the table took it.
	_pot_held[unit_id] = value
	_sync_tabs()

func _pot_anchor(unit_id: String) -> Control:
	## The pot among a player's buffs, or the buffs themselves while it is empty.
	var tab: SeatTab = _tab_of(unit_id) if unit_id != local_id else _my_tab
	if tab == null or not is_instance_valid(tab):
		return null
	var chip: Control = tab.chips.chip_for("pot")
	return chip if chip != null else (tab.chips if tab.chips.is_visible_in_tree() else _tab_anchor(unit_id))

func _hold_purse(unit_id: String, pot: int, bank: int) -> void:
	## The pot and the purse read `pot` and `bank` until the coins of what follows have moved;
	## the truth again `seconds` later, whatever happened.
	_pot_held[unit_id] = pot
	if unit_id == local_id:
		_bank_held[unit_id] = bank
		bank_changed.emit(0)
	_sync_tabs()

func _free_purse(unit_id: String) -> void:
	_pot_held.erase(unit_id)
	_sync_tabs()
	if _bank_held.has(unit_id):
		_bank_held.erase(unit_id)
		bank_changed.emit(0)

func _birth_purse(event: Dictionary, span: float) -> void:
	## A Birthstone moving pyrite (an Ante's stake, a Raise, All In, a Bust) has already moved
	## it by the time it is shown: the pot and the purse go back to how they stood, and each
	## tier's count moves them as its coins fly.
	var unit_id: String = str(event.get("unit", ""))
	var was: int = -1
	var moved: int = 0
	for entry in event.get("tiers", []):
		var pot: Dictionary = entry.get("count", {}).get("pot", {})
		if not bool(entry.get("active", false)) or pot.is_empty():
			continue
		if was < 0:
			was = int(pot.get("was", 0))
		moved += int(pot.get("moved", 0))
	if was < 0:
		return
	_hold_purse(unit_id, was, _bank_live(unit_id) + moved)
	_later_do(span, _free_purse.bind(unit_id))

func _house_money() -> void:
	## House Money, as the Gambler's first turn opens: a tenth of his purse carried onto the
	## table, coin by coin, under its name.
	if _house_shown or _headless or not is_inside_tree():
		return
	var unit: Dictionary = me()
	var pot: int = int(unit.get("pot", 0))
	if str(unit.get("passive", {}).get("kind", "")) != "pot_share" or pot <= 0 or int(state.get("turn", 0)) != 1:
		return
	if str(state.get("phase", "")) != "planning":
		## Locked in before it could be shown: the purse already reads it gone.
		_house_shown = true
		return
	_hold_purse(local_id, 0, _bank_live(local_id) + pot)
	_house_shown = true
	var plate := ResonanceCount.new()
	plate.color = DeepUi.ORE
	plate.placement = "above"
	plate.ceiling = _dock_top
	plate.gem_anchor = func() -> Control: return _my_tab.chips if _my_tab != null and _my_tab.chips.is_visible_in_tree() else null
	add_child(plate)
	plate.call_only(str(unit.passive.get("name", "House Money")), "%d%% of your pyrite on the table" % int(unit.passive.get("amount", 10)))
	_later_do(0.45, func() -> void:
		var from: Control = _bank_control()
		var to: Control = _pot_anchor(local_id)
		_bank_moved(-pot, local_id)
		var landed := func() -> void:
			_free_purse(local_id)
			var chip: Control = _pot_anchor(local_id)
			if chip != null:
				DeepUi.spring(chip, 0.4, 8.0, 0.45)
				_float_at(chip, "+%d on the table" % pot, DeepUi.ORE, 16)
		if from == null or to == null:
			landed.call()
			return
		ResonanceCount.coins(self, from.get_global_rect().get_center(), to.get_global_rect().get_center(), pot, 0.6, landed))

func _cash_out() -> void:
	## The fight is won: everything the Gambler had on the table comes back to his purse.
	var unit: Dictionary = me()
	var pot: int = int(_shown(unit).get("pot", 0))
	if pot <= 0 or _headless or not is_inside_tree():
		return
	var said: Control = _pot_anchor(local_id)
	_float_at(said if said != null else _hp_bar, "Pot · +%d" % pot, DeepUi.ORE, 20)
	var landed := func() -> void:
		_pot_shows(0, local_id)
		bank_changed.emit(pot)
	## Looked up as the coins leave: the buffs may have been laid out again by then.
	_later_do(0.5, func() -> void:
		var from: Control = _pot_anchor(local_id)
		var to: Control = _bank_control()
		if from == null or to == null:
			landed.call()
			return
		ResonanceCount.coins(self, from.get_global_rect().get_center(), to.get_global_rect().get_center(), pot, 0.7, landed))

# --- passives as a turn opens ------------------------------------------------------------------

func _turn_opening() -> void:
	## What a passive does as the reader's turn opens, said without holding them up: Study's
	## reroll counted onto the button, House Money going onto the table.
	_house_money()
	var unit: Dictionary = me()
	var passive: Dictionary = unit.get("passive", {})
	if str(passive.get("kind", "")) == "extra_reroll" and int(unit.get("rerolls", 0)) > 0 and str(state.get("phase", "")) == "planning":
		_study(int(passive.get("amount", 1)), str(passive.get("name", "Study")))

func _study(amount: int, title: String) -> void:
	## The reroll Study gives, thrown from the reader's face onto the reroll button, which
	## ticks up and shakes as it lands. The button works all the while: a reroll pressed
	## before it lands simply has it.
	if _headless or not is_inside_tree() or _reroll_button == null or not _reroll_button.is_visible_in_tree():
		return
	_study_lag = amount
	_study_until = Time.get_ticks_msec() + 900
	_sync()
	_later_do(0.3, func() -> void:
		var face: Control = _local_page.face if _local_page != null and _local_page.face != null and _local_page.face.is_visible_in_tree() else _resonance_box
		var plate := ResonanceCount.new()
		plate.chain = Tally.Chain.new()
		plate.chain.reset()
		add_child(plate)
		var landed := func() -> void:
			if _study_lag <= 0:
				return
			_study_lag = 0
			_sync()
			DeepUi.spring(_reroll_button, 0.28, 7.0, 0.45)
			DeepUi.burst(self, _center_of(_reroll_button), DeepUi.INFO, 16, 150.0, 0.45)
			DeepAudio.from(_reroll_button, "tally_mult", {"volume": 0.55, "pitch": 1.2, "vary": 0.0, "gap": 0.0})
		plate.toss(face.get_global_rect().get_center(), _reroll_button.get_global_rect().get_center(), "+%d" % amount, title, DeepUi.INFO, 0.3, landed, "reroll"))

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
	## Where a gem's light leaves from: its socket on the dock while its player's page is up,
	## else their tab.
	var card: Control = _gem_card(unit_id, socket)
	if card != null:
		return _control_world(card, 1.6)
	var tab: Control = _tab_anchor(unit_id)
	if tab != null:
		return _control_world(tab, 1.8)
	return _camera.global_position + (-_camera.global_transform.basis.z) * 1.5 + Vector3(0, -0.6, 0)

func _gem_fire(event: Dictionary) -> void:
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	## Played in full on its own socket while its player's page is up (the dock follows each
	## rail as it fires); on their tab, small, while it is not.
	var page: Page = _page_for(unit_id)
	var shown: bool = page != null and _is_shown(unit_id)
	var socket: int = int(event.get("socket", -1))
	var color: Color = _stone_color(unit_id, socket, str(event.get("skill", "")))
	var origin: Vector3 = _origin_for(unit_id, socket)
	var magnitude: float = clampf(float(event.get("magnitude", 1.0)), 0.5, 4.0)
	var voice: String = DeepSoundBank.gem_sound(_color_key(unit_id, socket, str(event.get("skill", ""))))
	var carry: float = clampf(0.5 + magnitude * 0.14, 0.45, 1.0) * (1.0 if mine else (0.8 if shown else 0.55))
	var tally: Dictionary = event.get("tally", {})
	## Each gem the rail fires starts its count a step further up the music's scale, and rings
	## a little higher itself, so a rail that keeps firing is heard to climb.
	var step: int = mini(_chain.fired, Tally.TOP_START)
	_chain.fired += 1
	var lift: float = 1.0 + 0.04 * float(step)
	var tab: Control = _tab_anchor(unit_id)
	if shown and socket >= 0 and socket < page.socket_cards.size():
		var card: Control = page.socket_cards[socket]
		DeepAudio.from(card, voice, {"volume": carry, "gap": 0.02, "pitch": lift})
		if mine:
			DeepAudio.rumble(0.3, 0.12, 0.05)
		var ring: SocketRing = card.get_node_or_null("Slot/Ring")
		if ring != null:
			ring.fire()
		DeepUi.spring(card, 0.22, 8.0, 0.5)
		DeepUi.burst(self, _center_of(card), color, 18, 170.0, 0.55)
		var resonance: int = int(event.get("resonance", 0))
		if resonance > page.resonance_shown or int(event.get("gain", 0)) > 0:
			_resonance_flight(page, card, resonance, maxi(1, int(event.get("gain", 0))), color, bool(event.get("harmony", false)))
		elif resonance != page.resonance_shown:
			_show_resonance(resonance, page)
		## A count says it on its own plate.
		if bool(event.get("retrigger", false)) and not tally.has("amount"):
			_float_at(card, "Again!", DeepUi.ACCENT_HI, 15)
		## Two of one color fired back to back ring together: a bow of their light between them.
		if bool(event.get("harmony", false)) and page.last_fired >= 0 and page.last_fired != socket:
			_harmony_bow(_gem_card(unit_id, page.last_fired), card, color)
	elif tab != null:
		DeepAudio.from(tab, voice, {"volume": carry, "gap": 0.02, "pitch": lift})
		DeepUi.spring(tab, 0.06, 2.0, 0.35)
	else:
		DeepAudio.play(voice, {"volume": carry, "gap": 0.02, "pitch": lift})
	if page != null:
		page.last_fired = socket
	var card_anchor: Control = _gem_card(unit_id, socket)
	if shown and not tally.has("amount"):
		## A count with a figure in it lays what the dice were worth on its own plate.
		_die_boost(card_anchor if card_anchor != null else page.tray_box, event, color)
	## A blow that kills is marked now, while its bolt waits for the count: the room must not
	## clear the creature away before it has been hit.
	_mark_dying(event.get("effects", []))
	## Its blows are its own: a Riposte growing off the last gem's is flown as this one fires.
	_blow_token[unit_id] = int(_blow_token.get(unit_id, 0)) + 1
	_close_swell(unit_id)
	var wait: float = _count_out(event, shown, color, step)
	## A count past counting is celebrated as its blows land.
	_watch_infinity(event, wait + 0.1)
	var effects: Array = event.get("effects", [])
	if wait > 0.0:
		_hold_vitals(effects, unit_id)
	else:
		_hold_parry(effects, unit_id)
	if wait <= 0.0:
		_animate_effects(effects, origin, color, mine, card_anchor, magnitude, unit_id)
		return
	_later_do(wait, func() -> void:
		_animate_effects(effects, origin, color, mine, _gem_card(unit_id, socket), magnitude, unit_id))

func _count_out(event: Dictionary, shown: bool, color: Color, step: int) -> float:
	## A gem's arithmetic, counted out over its socket (or, small, over its player's tab while
	## their page is not the one up) before what it does leaves it: the dice it read, what
	## multiplied them and the figure they came to. Returns how long the count takes, which is
	## how long the bolts wait: exactly the beat the rules reserved for it in the step (see
	## `DeepBattle.tally_span`).
	var tally: Dictionary = event.get("tally", {})
	var span: float = DeepBattle.tally_span(tally)
	if span <= 0.0:
		return 0.0
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	var socket: int = int(event.get("socket", -1))
	var anchor: Control = _gem_card(unit_id, socket) if shown else _tab_anchor(unit_id)
	if anchor == null:
		## Nowhere to count it, but the bolts still keep the step's time.
		return span
	var plate := Tally.new()
	plate.chain = _chain
	plate.start_step = step
	plate.color = color
	plate.compact = not shown
	plate.volume = 1.0 if mine else (0.8 if shown else 0.45)
	plate.skill = str(DeepContent.skill(str(event.get("skill", ""))).get("name", ""))
	var words: Array = [] if mine else [str(DeepBattle.player(state, unit_id).get("name", ""))]
	words.append(plate.skill)
	if bool(event.get("retrigger", false)):
		words.append("Again!")
	plate.caption = " · ".join(words.filter(func(w: Variant) -> bool: return not str(w).is_empty()))
	plate.gem_anchor = _gem_card.bind(unit_id, socket) if shown else _tab_anchor.bind(unit_id)
	plate.die_anchor = _counted_die.bind(unit_id) if shown else Callable()
	plate.destination = _tally_destination.bind(event)
	plate.ceiling = _dock_top
	plate.placement = "above"
	plate.rumbles = mine
	plate.tick = DeepSoundBank.tick_sound(_color_key(unit_id, socket, str(event.get("skill", ""))))
	plate.blaze = _kills(event.get("effects", []))
	plate.on_fuse = _count_fused
	add_child(plate)
	plate.play(tally)
	return span

func _kills(effects: Array) -> bool:
	## Whether any blow among these finishes what it hits.
	for effect in effects:
		if not effect is Dictionary:
			continue
		if str(effect.get("kind", "")) == "damage":
			for hit in [effect] + effect.get("splash", []):
				if hit is Dictionary and bool(hit.get("killed", false)):
					return true
		elif str(effect.get("kind", "")) in ["appraise", "invert_previous"] and _kills(effect.get("hits", [])):
			return true
	return false

func _count_fused(_total: int, blazing: bool) -> void:
	## A figure that will finish what it hits shakes the room as it is fused.
	if not blazing or _camera == null:
		return
	_camera.punch(-2.5, 0.3)
	_camera.add_trauma(0.18)
	_screen_fx.kick(0.35)

func _count_creature(event: Dictionary) -> void:
	## A creature's blow counted beside its nameplate before it lands: the dice it rolled for
	## it, the mine's weight, what every blow of its carries on top. An octave under the rail's
	## counts, and on fire when it would put the reader down.
	var tally: Dictionary = event.get("tally", {})
	var id: String = str(event.get("unit", ""))
	var plate_node: Variant = _plates.get(id, null)
	if tally.is_empty() or plate_node == null or not is_instance_valid(plate_node) or stage.walking():
		return
	var foe: Dictionary = DeepBattle.enemy(state, id)
	var creature: CrystalCreature = _creature(id)
	var plate := Tally.new()
	plate.chain = Tally.Chain.new()
	plate.chain.reset()
	plate.register = 0.5
	plate.volume = 0.7
	plate.rumbles = false
	plate.compact = false
	plate.placement = "right"
	plate.mult_glyph = "depth"
	plate.color = creature.tint if creature != null else DeepUi.BAD
	plate.caption = str(event.get("move", ""))
	plate.skill = str(event.get("move", ""))
	plate.gem_anchor = _creature_plate.bind(id)
	plate.die_anchor = _creature_die.bind(id)
	plate.destination = func() -> Vector2:
		var bar: Control = _vital_anchor(local_id)
		return bar.get_global_rect().get_center() if bar != null and not bool(me().get("downed", false)) else Vector2.INF
	var mine: Dictionary = _shown(me())
	plate.blaze = not mine.is_empty() and not bool(mine.get("downed", false)) and int(tally.get("amount", 0)) * maxi(1, int(tally.get("repeat", 1))) >= int(mine.get("hp", 0)) + int(mine.get("block", 0))
	add_child(plate)
	plate.play(tally)

func _brace(tally: Dictionary) -> void:
	## While a creature's blow is counted, the share of each player's health it would take
	## pulses at the end of their bars, on the dock and on the tabs, until it lands. An empty
	## tally lets go of all of them.
	for unit in state.get("players", []):
		var id: String = str(unit.get("id", ""))
		var share: float = 0.0
		var target: String = str(tally.get("target", ""))
		if str(tally.get("kind", "")) == "damage" and not bool(unit.get("downed", false)) and (target == "heroes" or target == id):
			var shown: Dictionary = _shown(unit)
			var blows: int = int(tally.get("amount", 0)) * maxi(1, int(tally.get("repeat", 1)))
			var loss: int = clampi(blows - int(shown.get("block", 0)), 0, int(shown.get("hp", 0)))
			share = float(loss) / float(maxi(1, int(shown.get("max_hp", 1))))
		var page: Page = _page_for(id)
		if page != null and page.hp_bar != null:
			page.hp_bar.preview = share
		var tab: SeatTab = _tab_of(id)
		if tab != null:
			tab.brace(share)

func _creature_plate(id: String) -> Control:
	var plate_node: Variant = _plates.get(id, null)
	return plate_node as Control if plate_node != null and is_instance_valid(plate_node) else null

func _creature_die(id: String, die_id: String) -> Control:
	## The mark of one of a creature's dice on its nameplate, for a count to point at.
	var plate_node: Variant = _plates.get(id, null)
	if plate_node == null or not is_instance_valid(plate_node):
		return null
	var dice: Array = DeepCreatures.effective_dice(DeepBattle.enemy(state, id))
	for index in range(dice.size()):
		if str(dice[index].get("id", "")) == die_id:
			return (plate_node as Plate).die_mark(index)
	return null

func _harmony_bow(from: Control, to: Control, tone: Color) -> void:
	## Two gems of one color fired back to back ring together: a bow of their light from the
	## one before to this one, sparks running along it, and the one before answers with a jolt.
	if from == null or to == null or _headless:
		return
	var a: Vector2 = _center_of(from) + Vector2(0, -from.size.y * 0.3)
	var b: Vector2 = _center_of(to) + Vector2(0, -to.size.y * 0.3)
	var top: Vector2 = (a + b) * 0.5 + Vector2(0, -26.0 - absf(b.x - a.x) * 0.18)
	var points := PackedVector2Array()
	for i in range(17):
		var t: float = float(i) / 16.0
		points.append(a.lerp(top, t).lerp(top.lerp(b, t), t))
	var bow := Line2D.new()
	bow.points = points
	bow.width = 0.0
	bow.default_color = Color(tone.lightened(0.4), 0.95)
	bow.joint_mode = Line2D.LINE_JOINT_ROUND
	bow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bow.end_cap_mode = Line2D.LINE_CAP_ROUND
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bow.material = additive
	bow.z_index = 44
	add_child(bow)
	var tween := bow.create_tween()
	tween.tween_property(bow, "width", 6.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bow, "width", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(bow, "modulate:a", 0.0, 0.45)
	tween.tween_callback(bow.queue_free)
	for k in range(4):
		var spark := TextureRect.new()
		spark.texture = DeepUi.glow_texture()
		spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spark.size = Vector2(22, 22)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.modulate = Color(tone.lightened(0.6), 0.0)
		spark.material = additive
		spark.z_index = 45
		bow.add_child(spark)
		var run := spark.create_tween()
		run.tween_interval(0.04 * float(k))
		run.tween_method(func(t: float) -> void:
			spark.position = a.lerp(top, t).lerp(top.lerp(b, t), t) - spark.size * 0.5
			spark.modulate.a = sin(PI * t), 0.0, 1.0, 0.26)
	DeepUi.spring(from, 0.14, 5.0, 0.4)
	_later_do(0.27, func() -> void:
		DeepUi.burst(self, b, tone, 14, 120.0, 0.4))

func _gem_card(unit_id: String, socket: int) -> Control:
	## A rail's card (or rider chip) for a socket, while its player's page is the one up.
	var page: Page = _page_for(unit_id)
	if page == null or not _is_shown(unit_id) or socket < 0 or socket >= page.socket_cards.size():
		return null
	var card: Variant = page.socket_cards[socket]
	return card if card is Control and is_instance_valid(card) else null

func _counted_die(die_id: String, unit_id: String = "") -> Control:
	## The die a count points at: in its player's tray, or among their phantoms; null if it is
	## not on screen.
	var whose: String = local_id if unit_id.is_empty() else unit_id
	var page: Page = _page_for(whose)
	if page == null or not _is_shown(whose):
		return null
	for views in [page.dice_views, page.phantom_views]:
		var view: Variant = views.get(die_id, null)
		if view is Control and is_instance_valid(view):
			return view
	return null

func _dock_top() -> float:
	## How low a count's plate may sit: above the dock and the party's tabs along it, never
	## over them.
	if _dock == null:
		return INF
	var top: float = _dock.get_global_rect().position.y - 6.0
	if _my_tab != null and _my_tab.face.is_visible_in_tree():
		top = minf(top, _my_tab.face.get_global_rect().position.y - 6.0)
	## Nor over anyone's buffs and troubles, which ride over their tab (or, alone, along the
	## top of the dock): a count laid over them hid them while it played.
	for tab in [_my_tab] + _tabs.values():
		if tab is SeatTab and is_instance_valid(tab) and (tab as SeatTab).chips.is_visible_in_tree() and (tab as SeatTab).chips.get_child_count() > 0:
			top = minf(top, (tab as SeatTab).chips.get_global_rect().position.y - 6.0)
	return top

func _tally_destination(event: Dictionary) -> Vector2:
	## Where a gem's counted figure flies as its bolt leaves (see `_figure_destination`).
	return _figure_destination(str(event.get("tally", {}).get("kind", "")), event.get("effects", []))

func _mark_dying(effects: Array) -> void:
	## Every creature these effects killed, marked as dying before its blow is drawn, so the
	## room leaves it standing for a bolt still on its way (see `_place_creatures`).
	for effect in effects:
		if not effect is Dictionary:
			continue
		match str(effect.get("kind", "")):
			"damage":
				for hit in [effect] + effect.get("splash", []):
					if hit is Dictionary and bool(hit.get("killed", false)):
						var struck: CrystalCreature = _creature(str(hit.get("target", effect.get("target", ""))))
						if struck != null:
							struck.set_meta("dying", true)
			"appraise", "invert_previous":
				_mark_dying(effect.get("hits", []))
			"tick_poison":
				for tick in effect.get("ticks", []):
					if tick is Dictionary and bool(tick.get("killed", false)):
						var ticked: CrystalCreature = _creature(str(tick.get("unit", "")))
						if ticked != null:
							ticked.set_meta("dying", true)
		_mark_dying(effect.get("poison_spread", []))

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
		_float_at(_resonance_box, "+" + DeepUi.number(resonance), tone, 18)
		DeepUi.burst(self, _center_of(_resonance_box), tone, 10 + mini(resonance, 30) * 4, 110.0, 0.5)
		for id in die_ids:
			var lit: Control = _die_anchor(str(id))
			if lit != _tray_box:
				DeepUi.burst(self, _center_of(lit), tone, 8, 70.0, 0.45)
	var pyrite: int = int(dues.get("pyrite", 0))
	if pyrite > 0:
		_later_do(0.14, func() -> void:
			DeepAudio.play("ore", {"volume": 0.6})
			_fx.coins(_die_world(str(die_ids[0]) if not die_ids.is_empty() else ""), _purse(), 4 + mini(10, pyrite))
			_float_at(anchor, "+%s pyrite" % DeepUi.number(pyrite), DeepUi.ORE, 18))
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

func _crowns_ring(ids: Array) -> void:
	## All or Nothing: every crown that came up rings the rail once. Each glints gold where it
	## landed, and the count goes up by as many.
	if ids.is_empty() or _headless or not is_inside_tree():
		return
	var box: Control = _local_page.resonance_box
	DeepAudio.from(box, "resonance", {"volume": 0.6, "pitch": 1.25})
	_float_at(box, "+%d" % ids.size(), StreakFx.BULB, 18)
	DeepUi.burst(self, _center_of(box), StreakFx.BULB, 8 + 4 * ids.size(), 110.0, 0.5)
	for id in ids:
		var lit: Control = _die_anchor(str(id))
		if lit != null and lit != _tray_box:
			DeepUi.burst(self, _center_of(lit), StreakFx.BULB, 10, 80.0, 0.45)
			DeepUi.pulse(lit, 1.15, 0.25)

func _bonus_rim(holder: Node, lent: bool) -> void:
	## A Hot Streak's bonus die wears a gold rim for the turn it was lent, and drops in burning.
	if holder == null or not holder is Control:
		return
	var rim: Panel = holder.get_node_or_null("BonusRim")
	if rim == null and lent:
		rim = Panel.new()
		rim.name = "BonusRim"
		var edge := DeepUi.flat(Color(0, 0, 0, 0), DeepUi.ORE, 2, 9)
		rim.add_theme_stylebox_override("panel", edge)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.position = Vector2(-3, -3)
		rim.size = Vector2(DIE_EDGE + 6, DIE_EDGE + 6)
		holder.add_child(rim)
		if not _headless and holder.is_inside_tree():
			DeepUi.burst(self, _center_of(holder as Control), StreakFx.EMBER, 26, 150.0, 0.6)
	if rim != null:
		rim.visible = lent

func _sync_streak(page: Page, unit: Dictionary) -> void:
	## The hot streak this turn rides on (DeepBattle's `streak`): the reader's own tray wears it,
	## and On Fire's doubled Resonance is written beside the count.
	var downed: bool = bool(unit.get("downed", false))
	var doubled: bool = bool(unit.get("resonance_doubled", false)) and not downed
	var mark: Label = page.resonance_box.get_node_or_null("Doubled") if page.resonance_box != null else null
	if mark == null and doubled and page.resonance_box != null:
		mark = DeepUi.title(page.resonance_box, "×2", 18, StreakFx.HOT)
		mark.name = "Doubled"
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		mark.tooltip_text = "On Fire: High Roller reads double Resonance this turn."
	if mark != null:
		mark.visible = doubled
	if page.mine and _streak_fx != null:
		_streak_fx.set_level(0 if downed else int(unit.get("streak", 0)))

func _jackpot(entry: Dictionary) -> void:
	## Five crowns, as the Jackpot's own tier is reached: the slot machine pays. Time slows, bulbs
	## chase round the tray, each of the seven blows lands with a ring as the count lets them go,
	## and coins pour into the purse.
	if state.is_empty() or not is_inside_tree():
		return
	ScreenFx.hold(0.9, 0.35)
	if _streak_fx != null:
		_streak_fx.jackpot()
	_announce("JACKPOT", StreakFx.BULB, "Seven times seven", 1.6)
	DeepAudio.rumble(0.6, 0.6, 0.3)
	var hit_at: Vector3 = _purse() + Vector3(0, 1.0, -1.0)
	for effect in entry.get("effects", []):
		var struck: CrystalCreature = _creature(str(effect.get("target", ""))) if str(effect.get("kind", "")) == "damage" else null
		if struck != null and is_instance_valid(struck):
			hit_at = struck.centre()
	var land: float = DeepBattle.birth_span(entry.get("count", {}))
	for index in range(7):
		_later_do(land + 0.13 * float(index), func() -> void: _fx.ring_wave(Vector3(hit_at.x, 0.0, hit_at.z), StreakFx.BULB, 1.8, 0.4, 0.1))
	_later_do(land + 1.0, func() -> void: _fx.coins(hit_at, _purse(), 26))

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
	## color, said on the gem that felt them.
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
	DeepUi.burst(self, _center_of(anchor), tone, 18 + int(round(minf(boost, 20.0) * 6.0)), 200.0, 0.65)
	DeepAudio.from(anchor, "gleam", {"volume": 0.6, "pitch": 1.1})

func _later_do(seconds: float, work: Callable) -> void:
	## One beat of an effect's playback. Nothing here outlives the screen.
	if seconds <= 0.001 or _headless or not is_inside_tree():
		work.call()
		return
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			work.call())

func _animate_effects(effects: Array, origin: Vector3, color: Color, mine: bool, anchor: Control, magnitude: float = 1.0, by: String = "") -> void:
	## What a gem or a Birthstone did, animated effect by effect from where its light left —
	## one after another, not all at once. A skill that files a die and then throws five
	## bolts should read as exactly that: the file, a breath, then five bolts in a row. `by`
	## is the player whose rail it was: their page counts up what it dealt.
	var at: float = 0.0
	## Blows close up as they pile on, so a gem that lands twenty times over still plays inside
	## the step the rules reserved for it. `DeepBattle` owns the beat; this only follows it.
	var pace: float = DeepBattle.hit_pace(effects)
	for effect in effects:
		var kind: String = str(effect.get("kind", ""))
		var target_id: String = str(effect.get("target", ""))
		if effect.has("drunk_by"):
			## A Kaleidoscope drinking this gem's color: what the gem gives goes to it instead.
			var drinker: CrystalCreature = _creature(str(effect.drunk_by))
			if drinker != null:
				var gift: String = "+%d %s" % [int(effect.get("amount", 0)), kind.replace("_", " ")]
				## Held by a weak reference: a lambda that captures a creature freed before it
				## runs (a slime split, a kill) errors on the call even if it checks first.
				var drinker_ref: WeakRef = weakref(drinker)
				_later_do(at, func() -> void:
					var still: CrystalCreature = drinker_ref.get_ref() as CrystalCreature
					if still != null:
						_fx.projectile(origin, still.centre(), color, 0.25, 0.1, Callable(), 0.8)
						_float_world(still.centre() + Vector3(0, 0.8, 0), "Drinks it · " + gift, color, 16))
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
					## Which gem's blows these are, for a Riposte growing off them.
					landing.blow = int(_blow_token.get(by, 0))
					if bool(hit.get("killed", false)):
						creature.set_meta("dying", true)
					## Bigger numbers throw bigger, faster bolts.
					var weight: float = clampf(float(int(hit.get("hp_loss", 0)) + int(hit.get("absorbed", 0))) / 14.0, 0.0, 1.6)
					var fat: float = 0.09 + 0.035 * magnitude + 0.05 * weight
					var creature_ref: WeakRef = weakref(creature)
					for again in range(over):
						var when: float = at + DeepBattle.BOLT_GAP * pace * float(again)
						_later_do(when , func() -> void:
							var still: CrystalCreature = creature_ref.get_ref() as CrystalCreature
							if still != null:
								_fx.projectile(origin, still.centre(), color, 0.2, fat, _impact.bind(who, landing, color, mine, by), 0.6 + randf() * 0.5))
					at += DeepBattle.BOLT_GAP * pace * float(over)
				at += DeepBattle.HIT_BREATH * pace
				if not effect.get("poison_spread", []).is_empty():
					_animate_effects(effect.poison_spread, origin, DeepUi.POISON, mine, anchor, 1.0, by)
				if mine and effect.has("spent"):
					_float_at(_purse_spot(), "−%d Pyrite%s" % [int(effect.spent), " / +%d refund" % int(effect.refund) if effect.has("refund") else ""], DeepUi.ORE, 16)
			"appraise":
				if mine:
					_float_at(_purse_spot(), "%d appraised · %d Pyrite value" % [effect.get("appraised", []).size(), int(effect.get("value", 0))], DeepUi.ORE, 16)
				_animate_effects(effect.get("hits", []), origin, DeepUi.ORE, mine, anchor, magnitude, by)
			"invert_previous":
				## An Invert: said over its card, then what it turned around lands like any other gem's.
				if mine and anchor != null:
					_float_at(anchor, "Nothing to turn around" if bool(effect.get("nothing", false)) else "Inverted", color.lightened(0.3), 15)
				_animate_effects(effect.get("hits", []), origin, color, mine, anchor, magnitude, by)
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
					_float_at(_purse_spot(), "−%d Pyrite · next gem +%d%%" % [int(effect.spent), int(effect.amount)], DeepUi.ORE, 16)
			"block":
				var gained: int = int(effect.amount)
				var swell: float = clampf(float(gained) / 18.0, 0.0, 1.0)
				_later_do(at, func() -> void:
					if _is_player(target_id):
						_land_vitals(target_id, 0, -gained)
					DeepAudio.play("block", {"volume": (0.5 + 0.35 * swell) if target_id == local_id else 0.45})
					if target_id == local_id:
						var ahead: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 2.2 + Vector3(0, -0.35, 0)
						_fx.shield(ahead, _camera.global_position - ahead, DeepUi.BLOCK, 0.7 + swell * 0.9, 0.5 + swell * 0.4)
						_screen_fx.blink(DeepUi.BLOCK, 0.06 + swell * 0.22)
						_ward(DeepUi.BLOCK, "shield", swell, 5 + int(round(swell * 9.0)))
						_float_at(_hp_bar, "+%s block" % DeepUi.number(gained), DeepUi.BLOCK, 18 + int(round(swell * 14.0)))
					elif _is_player(target_id):
						_float_at(_vital_anchor(target_id), "+%s block" % DeepUi.number(gained), DeepUi.BLOCK, 16)
						_tab_flash(target_id, DeepUi.BLOCK))
				at += 0.2
			"heal", "revive":
				var healed: int = int(effect.get("healed", effect.amount))
				var pour: float = clampf(float(healed) / 20.0, 0.0, 1.0)
				var whole: bool = healed <= 0 and kind == "heal"
				_later_do(at, func() -> void:
					if _is_player(target_id):
						_land_vitals(target_id, -healed, 0)
					if whole:
						## Healing someone already whole: said quietly, not cheered as "+0".
						if target_id == local_id:
							_float_at(_hp_bar, "Full", DeepUi.MUTED, 15)
						elif _is_player(target_id):
							_float_at(_vital_anchor(target_id), "Full", DeepUi.MUTED, 13)
						return
					DeepAudio.play("heal", {"volume": 0.55 + 0.35 * pour})
					if target_id == local_id:
						var below: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 2.6 + Vector3(0, -1.4, 0)
						_fx.rise(below, DeepUi.GOOD, 16 + int(round(pour * 54.0)), 1.1 + pour * 1.0)
						_screen_fx.blink(DeepUi.GOOD, 0.06 + pour * 0.2)
						_ward(DeepUi.GOOD, "cross", pour, 5 + int(round(pour * 11.0)))
						_float_at(_hp_bar, "+" + DeepUi.number(healed), DeepUi.GOOD, 18 + int(round(pour * 16.0)))
					elif _is_player(target_id):
						_float_at(_vital_anchor(target_id), "+" + DeepUi.number(healed), DeepUi.GOOD, 16)
						_tab_flash(target_id, DeepUi.GOOD))
				at += 0.2
			"gold":
				if mine:
					DeepAudio.play("ore", {"volume": 0.7})
					var pile: Vector3 = Vector3(randf_range(-1.5, 1.5), 1.2, ARC_Z + 0.5)
					var home: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.4 + Vector3(0.8, -0.7, 0)
					_fx.coins(pile, home, 8 + mini(12, int(effect.amount)))
					_float_at(_purse_spot(), "+%s pyrite" % DeepUi.number(int(effect.amount)), DeepUi.ORE, 20)
			"poison", "stun", "curse", "remove_block", "dice_dread", "die_steal", "cleanse", "clouded", "marked", "dulled", "ward", "retain", "charged", "regeneration", "spikes", "lifeline", "max_hp", "max_hp_loss":
				var creature: CrystalCreature = _creature(target_id)
				if creature != null and is_instance_valid(creature):
					var tone: Color = {"poison": DeepUi.POISON, "stun": Color("ffe27a"), "curse": Color("c58bff"), "remove_block": DeepUi.BLOCK}.get(kind, color)
					var landing: Dictionary = effect.duplicate()
					var creature_ref: WeakRef = weakref(creature)
					_later_do(at, func() -> void:
						var still: CrystalCreature = creature_ref.get_ref() as CrystalCreature
						if still != null:
							_fx.projectile(origin, still.centre(), tone, 0.3, 0.1, _afflict.bind(target_id, landing, tone), 1.0))
					at += 0.16
				elif target_id == local_id and kind == "cleanse":
					_fx.rise(_camera.global_position + (-_camera.global_transform.basis.z) * 2.6 + Vector3(0, -1.4, 0), Color.WHITE, 20, 1.2)
				elif target_id == local_id:
					_float_at(_effects, "Ward blocked" if bool(effect.get("warded", false)) else "%s +%s" % [kind.capitalize(), DeepUi.number(int(effect.amount))], color, 16)
				elif _is_player(target_id):
					_float_at(_tab_anchor(target_id), "Ward blocked" if bool(effect.get("warded", false)) else "%s +%s" % [kind.capitalize(), DeepUi.number(int(effect.amount))], color, 15)
			"raise_low", "raise_high", "set_match", "flip_low", "flip_high", "phantom_high", "phantom_low", "phantom_roll", "rethrow", "gild", "upgrade_faces":
				if mine:
					_float_at(_tray_box, kind.replace("_", " ").capitalize(), Color.WHITE, 15)
					for id in _dice_views:
						var view: Control = _dice_views[id]
						DeepUi.burst(self, _center_of(view), color, 6, 80.0, 0.4, 4.0)
			"tick_poison":
				_leech_token += 1
				for tick in effect.get("ticks", []):
					_animate_tick(tick)
			"replay_rail":
				## Its name has been called out over the Birthstone; the rail going round again
				## is what is said here.
				if not bool(effect.get("nothing", false)):
					DeepAudio.play("harmony", {"volume": 0.9})
					if anchor != null:
						_float_at(anchor, "The rail plays again", DeepUi.ACCENT_HI, 18)
			"pot":
				## The pot is counted out over the Birthstone, coins and all.
				pass
			"stone_drop":
				DeepAudio.play("ore", {"volume": 0.9})
				_announce("Royal Flush", DeepUi.ORE, "A stone falls from the rock", 1.1)
				if anchor != null:
					DeepUi.burst(self, _center_of(anchor), DeepUi.ORE, 40, 220.0, 0.9)
			_:
				if mine and anchor != null:
					_float_at(anchor, kind.replace("_", " ").capitalize(), color.lightened(0.3), 13)

func _ward(tone: Color, glyph: String, strength: float, count: int) -> void:
	## What a heal or a guard looks like from inside the helmet: a wash of its color round
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

func _impact(who: String, hit: Dictionary, color: Color, mine: bool, by: String = "") -> void:
	_land_vitals(who, int(hit.get("hp_loss", 0)), int(hit.get("absorbed", 0)))
	if not by.is_empty() and str(state.get("phase", "")) == "resolving":
		_count_dealt(int(hit.get("hp_loss", 0)) + int(hit.get("absorbed", 0)), by)
	## Riposte: every blow that lands raises the Rogue's guard by her Resonance, counted up
	## blow by blow over her bar for as long as this gem keeps landing them.
	if int(hit.get("riposte", 0)) > 0 and _is_player(by):
		var passive: Dictionary = DeepBattle.player(state, by).get("passive", {})
		_swell(by, str(passive.get("name", "Riposte")), "block", int(hit.riposte), int(hit.get("blow", 0)))
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
	if mine:
		DeepAudio.rumble(0.2 + ratio * 0.6, ratio * 1.2, 0.05 + ratio * 0.12)
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
	var text: String = "−" + DeepUi.number(amount)
	var size: int = 24 + mini(28, amount)
	## A blow past counting is said as Infinite, the mark itself, whatever health it found to take.
	var boundless: bool = (DeepRules.infinite(amount) or DeepRules.infinite(int(hit.get("raw", 0)))) and not hit.has("mirrored")
	if hit.has("mirrored"):
		text = "Mirrored"
		size = 22
	## In the gem's own color for the rail on the dock (the reader's, or the one being followed).
	var watched: bool = mine or (not by.is_empty() and _is_shown(by))
	var number: Label = null
	if boundless:
		_infinity_float(at + Vector3(0, 0.6, 0))
	else:
		number = _float_world(at + Vector3(0, 0.6, 0), text, color.lightened(0.35) if watched else DeepUi.PAPER, size)
	## A heavy blow's number lands with a jolt of its own.
	if number != null and (ratio >= 0.25 or bool(hit.get("killed", false))):
		DeepUi.shake(number, 9.0 + 9.0 * minf(ratio, 1.0), 0.32)
	if int(hit.get("absorbed", 0)) > 0:
		_float_world(at + Vector3(0.5, 0.2, 0), "%s blocked" % DeepUi.number(int(hit.absorbed)), DeepUi.BLOCK, 14)
	if hit.has("drunk"):
		## A color it is drinking: the blow sinks into it and does nothing.
		var hue := Color("#" + str(DeepContent.color(str(hit.drunk)).get("hue", "c8a8ff")))
		_float_world(at + Vector3(-0.5, 0.9, 0), "Drunk", hue, 16)
		_fx.glow_burst(at, hue, 1.6, 0.4)
	if bool(hit.get("guarded", false)):
		_float_world(at + Vector3(-0.5, 1.2, 0), "Gathering · half", Color("ffe27a"), 14)
	if hit.has("mirrored"):
		## The color it mirrors throws the blow straight back at whoever threw it.
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
	## A mirror that took the blow breaks as it throws it back.
	if hit.has("mirrored") and creature != null and is_instance_valid(creature):
		_fx.shards(creature.barrier_point(), Color("eef2ff"), 14, 3.5, 0.1, 0.9)
		_sound_at(creature.barrier_point(), "gem_shatter", 0.5)
		creature.set_barrier("")
	_hit_extras(hit, creature, at)
	_thresholds(hit, creature)
	if bool(hit.get("killed", false)):
		_kill(creature)

func _count_dealt(amount: int, by: String) -> void:
	## A blow of a rail's has landed: the turn's count beside its player's forecast rolls up to
	## it, whether their page is up or not.
	var page: Page = _page_for(by)
	if amount <= 0 or page == null or page.dealt_box == null or _headless:
		return
	var from: int = page.turn_dealt
	page.turn_dealt = DeepRules.sat_add(page.turn_dealt, amount)
	page.dealt_box.visible = true
	var shown: Label = page.dealt_label
	var to: int = page.turn_dealt
	var roll := shown.create_tween()
	roll.tween_method(func(v: float) -> void: shown.text = DeepUi.number(int(round(v))), float(from), float(to), 0.25)
	DeepUi.spring(page.dealt_box, 0.22, 5.0, 0.4)

func _dealt_flourish(page: Page) -> void:
	## The rail has closed: what it dealt is said once more and louder, gold if it came to
	## everything the hand promised.
	var promised: int = int(page.held_forecast.get("totals", {}).get("damage", 0))
	var whole: bool = promised > 0 and page.turn_dealt >= promised
	var tone: Color = DeepUi.ACCENT_HI if whole else DeepUi.BAD
	var label: Label = page.dealt_label
	label.add_theme_color_override("font_color", tone)
	DeepUi.spring(page.dealt_box, 0.45, 8.0, 0.6)
	DeepUi.burst(self, _center_of(page.dealt_box), tone, 18 + mini(30, page.turn_dealt / 4), 160.0, 0.6)
	DeepAudio.from(page.dealt_box, "tally_fuse", {"volume": 0.6 if page.mine else 0.45, "pitch": 1.5 if whole else 1.0, "vary": 0.0, "gap": 0.0})
	_float_at(page.dealt_box, "dealt " + DeepUi.number(page.turn_dealt), tone, 16)
	var held: WeakRef = weakref(label)
	_later_do(1.2, func() -> void:
		var still: Label = held.get_ref() as Label
		if still != null:
			still.add_theme_color_override("font_color", DeepUi.BAD))

func _thresholds(hit: Dictionary, creature: CrystalCreature) -> void:
	## What a creature does the moment its health falls far enough (the Hollow Crown calling
	## its magpies, the Spore Mother shedding everything), played as it falls.
	var creature_ref: WeakRef = weakref(creature) if creature != null and is_instance_valid(creature) else null
	for crossed in hit.get("thresholds", []):
		var at: Vector3 = creature.centre() if creature != null and is_instance_valid(creature) else Vector3(0, 1.2, ARC_Z)
		_later_do(0.25, func() -> void:
			_fx.ring_wave(Vector3(at.x, 0.0, at.z), Color("ffb0a0"), 3.0, 0.6)
			_float_world(at + Vector3(0, 1.2, 0), str(crossed.get("move", "")) + "!", Color("ffb0a0"), 22)
			for effect in crossed.get("effects", []):
				_enemy_effect(effect, creature_ref.get_ref() as CrystalCreature if creature_ref != null else null))

func _deathburst(hit: Dictionary, creature: CrystalCreature) -> void:
	## What a dying creature leaves behind: a Puffball's spores, a Spore Slime's burst,
	## played from where it stood a beat after the killing blow.
	var creature_ref: WeakRef = weakref(creature) if creature != null and is_instance_valid(creature) else null
	for burst in hit.get("deathburst", []):
		var at: Vector3 = creature.centre() if creature != null and is_instance_valid(creature) else Vector3(0, 1.0, ARC_Z)
		_later_do(0.3, func() -> void:
			_fx.ring_wave(Vector3(at.x, 0.0, at.z), DeepUi.POISON, 3.5, 0.6)
			_fx.puff(at, DeepUi.POISON, 40, 1.4, 1.6, 0.9, true)
			_fx.glow_burst(at, DeepUi.POISON, 2.4, 0.4)
			_float_world(at + Vector3(0, 1.0, 0), str(burst.get("move", "Burst")) + "!", DeepUi.POISON, 22)
			for effect in burst.get("effects", []):
				_enemy_effect(effect, creature_ref.get_ref() as CrystalCreature if creature_ref != null else null))

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
	## turning a color away, winding up a blow.
	if creature == null or not is_instance_valid(creature):
		return
	creature.burrow(bool(foe.get("burrowed", false)))
	## A halo for what guards it, and a barrier between it and the party: the color it drinks,
	## a refraction, a mirror held up.
	var drinking: Array = foe.get("absorb", [])
	if not drinking.is_empty():
		var hue := Color("#" + str(DeepContent.color(str(drinking[0])).get("hue", "c8a8ff")))
		creature.set_halo(hue)
		creature.set_barrier("drink", hue)
	elif int(foe.get("mirror", 0)) > 0:
		creature.set_halo(Color("e8e0ff"))
		creature.set_barrier("mirror", Color("eef2ff"))
	elif int(foe.get("reflect", 0)) > 0:
		creature.set_halo(Color("e8e0ff"))
		creature.set_barrier("refract", Color("c8b8ff"))
	else:
		creature.clear_halo()
		creature.set_barrier("")
	creature.set_charging(DeepCreatures.charge_turns(foe) > 0)
	## A ring of warning over its head when what it counts down to comes on its next action.
	creature.set_omen(int(foe.get("hp", 0)) > 0 and _due_next(foe))
	## A Collapsar's pull, and the dice a Cave Crayfish holds in its claw.
	creature.set_well(int(foe.get("hp", 0)) > 0 and DeepCreatures.has_trait(foe, "taunt"))
	var holding: int = 0
	for unit in state.get("players", []):
		var held: Variant = unit.get("gripped", {})
		if held is Dictionary:
			for die_id in held:
				if str(held[die_id]) == str(foe.get("id", "")):
					holding += 1
	creature.set_gripping(holding)

func _due_next(foe: Dictionary) -> bool:
	## Whether something it has been counting toward lands on its next action: a countdown at
	## one, an every-so-often move whose turn is next, a charge about to be let go.
	if DeepCreatures.charge_turns(foe) == 1:
		return true
	for move in DeepCreatures.moves_for(foe):
		match str(move.get("trigger", {}).get("kind", "")):
			"countdown":
				if DeepCreatures.countdown_in(foe, move) <= 1:
					return true
			"every_nth_turn":
				if DeepCreatures.next_nth_in(foe, move) <= 1:
					return true
	return false

func _before_me(distance: float = 1.8, drop: float = -0.35) -> Vector3:
	## A point just in front of the reader's eyes, where what lands on them is shown.
	return _camera.global_position + (-_camera.global_transform.basis.z) * distance + Vector3(0, drop, 0)

func _creature_fx(effect: Dictionary, creature: CrystalCreature, source: Vector3) -> void:
	## What a creature's move looks like in the room, on top of its numbers: fire for Burn,
	## bubbles for Poison, spores for Festering, crosshairs for Marked, a lance for a blow that
	## goes through block, and the tricks of the creatures reworked in October 2026.
	if _headless or _fx == null or bool(effect.get("warded", false)) or bool(effect.get("immune", false)) or bool(effect.get("resisted", false)):
		return
	var kind: String = str(effect.get("kind", ""))
	var target_id: String = str(effect.get("target", ""))
	var mine: bool = target_id == local_id
	## Far enough out to be seen whole over the dock, rather than a blur against the lens.
	var ahead: Vector3 = _before_me(3.0, -0.15)
	var struck: CrystalCreature = _creature(target_id)
	var reached: bool = mine or struck != null
	var at: Vector3 = ahead if mine else (struck.centre() if struck != null else Vector3.ZERO)
	var base: Vector3 = ahead + Vector3(0, -0.35, 0) if mine else (Vector3(struck.global_position.x, struck.global_position.y + 0.25, struck.global_position.z) if struck != null else Vector3.ZERO)
	var from_creature: bool = creature != null and is_instance_valid(creature)
	match kind:
		"burn":
			if reached and int(effect.get("amount", 0)) > 0:
				if mine and from_creature:
					_fx.projectile(source, ahead, Color("ff8a30"), 0.28, 0.16, Callable(), 0.5)
				_fx.flames(base, 0.8 if mine else 1.3 * (struck.scale.x if struck != null else 1.0), 1.1)
				_sound_at(base, "flame", 0.6)
		"poison":
			if reached and int(effect.get("amount", 0)) > 0:
				_fx.bubbles(base, DeepUi.POISON, 30, 0.7, 1.3)
		"poison_tick":
			if mine:
				_fx.bubbles(base, DeepUi.POISON, 22, 0.8, 0.9)
				_fx.puff(base, Color("7a8a3a"), 8, 0.5, 0.9, 0.3)
		"festering":
			if reached:
				_fx.puff(base, Color("8a9a4a"), 14, 0.55, 1.6, 0.4)
				_fx.bubbles(base, Color("b8c84a"), 12, 0.6)
		"scorched":
			if reached:
				_fx.sparks(at + Vector3(0, 0.6, 0), Color("ff8a3a"), 30, 1.5, 1.2, 0.04)
				_fx.puff(at, Color("3a3230"), 10, 0.6, 1.4, 0.5)
		"marked":
			if reached:
				_fx.reticle(at, _camera.global_position - at, Color("ff5a5a"), 0.35 if mine else 0.8)
		"curse":
			if mine:
				_fx.sigil(ahead + Vector3(0, -0.9, 0), Color("c58bff"), 0.8)
		"remove_block":
			if mine and int(effect.get("removed", 0)) > 0:
				_fx.shards(ahead, DeepUi.BLOCK, 8, 2.0, 0.06, 0.7)
			## A sluice opening: the water comes through everything.
			if bool(effect.get("remove_all", false)) and from_creature:
				_fx.splash(Vector3(source.x, 0.3, source.z), Color("8fd0e8"), 60, 5.0, 1.2)
				_sound_at(source, "splash", 0.8)
				_fx.ring_wave(Vector3(source.x, 0.0, source.z), Color("6ab8e0"), 6.0, 0.9, 0.6)
				if mine:
					_fx.splash(base, Color("8fd0e8"), 40, 3.0, 0.9)
		"damage":
			if bool(effect.get("piercing", false)) and from_creature and (mine or _is_player(target_id)):
				_fx.beam(source, ahead + Vector3(0, -0.15, 0), Color("ff6a5a"), 0.35, 0.1)
		"reflect":
			if from_creature:
				creature.set_barrier("refract", Color("c8b8ff"))
				_sound_at(creature.barrier_point(), "mirror", 0.45)
		"mirror":
			if from_creature:
				creature.set_barrier("mirror", Color("eef2ff"))
				_fx.flash(creature.barrier_point(), Color("eef2ff"), 4.0, 4.0, 0.4, 1.2)
				_sound_at(creature.barrier_point(), "mirror", 0.6)
		"absorb_color":
			if from_creature and not bool(effect.get("nothing", false)):
				creature.set_barrier("drink", Color("#" + str(DeepContent.color(str(effect.get("color", ""))).get("hue", "c8a8ff"))))
		"strength":
			if struck != null:
				_fx.ring_wave(Vector3(struck.global_position.x, 0.0, struck.global_position.z), DeepUi.BAD, 2.0, 0.5, 0.2)
				_fx.sparks(struck.centre(), Color("ff7a5a"), 18, 2.0, 0.7, 0.05)
		"copy_hand":
			if from_creature and not bool(effect.get("nothing", false)):
				var copied: String = str(effect.get("copied", ""))
				var faces: Array = effect.get("faces", [])
				var origin: Vector3 = _before_me(1.6, -0.7) if copied == local_id else Vector3(0, 1.5, 4.0)
				for index in range(faces.size()):
					_fx.projectile(origin + Vector3(0.35 * (float(index) - float(faces.size() - 1) * 0.5), 0, 0), creature.centre(), Color("eef2ff"), 0.4 + 0.08 * float(index), 0.12, Callable(), 0.6)
				_fx.spiral_in(creature.centre(), Color("eef2ff"), 1.6, 36, 0.9)
				_fx.flash(creature.centre(), Color("eef2ff"), 5.0, 6.0, 0.5, 1.4)
				var whose: String = "your" if copied == local_id else "%s's" % str(DeepBattle.player(state, copied).get("name", "their"))
				_float_world(creature.centre() + Vector3(0, 1.0, 0), "Copies %s dice: %s" % [whose, " · ".join(faces.map(func(v: Variant) -> String: return str(int(v))))], Color("eef2ff"), 18)
		"grip_die":
			if bool(effect.get("nothing", false)):
				return
			if mine:
				_fx.claw(base, _camera.global_position - base, Color("8fd0e8"))
				_sound_at(base, "claw", 0.8)
				var die_id: String = str(effect.get("gripped", ""))
				if _dice_views.has(die_id):
					var view: Control = _dice_views[die_id]
					DeepUi.shake(view, 12.0, 0.4)
					_float_at(view, "Gripped", Color("8fd0e8"), 15)
				DeepAudio.play("block_break", {"volume": 0.6})
			elif _is_player(target_id):
				_float_at(_vital_anchor(target_id), "A die gripped", Color("8fd0e8"), 14)
		"lose_die":
			if from_creature and not bool(effect.get("nothing", false)):
				_fx.puff(creature.centre() + Vector3(0, 0.6, 0), Color("2a3a48"), 18, 0.9, 1.4, 0.4)
				_fx.ring_wave(Vector3(creature.global_position.x, 0.0, creature.global_position.z), Color("6ab8e0"), 3.0, 0.7)
				_float_world(creature.centre() + Vector3(0, 1.1, 0), "A head falls silent · %d left" % int(effect.get("heads", 0)), Color("8fd0e8"), 18)
		"hasten":
			if from_creature and not bool(effect.get("nothing", false)):
				_fx.sigil(Vector3(creature.global_position.x, 0.0, creature.global_position.z), Color("ffb05a"), 1.6, 1.0)
				for sped in effect.get("hastened", []):
					_float_world(creature.centre() + Vector3(0, 1.1, 0), "%s in %s" % [str(sped.get("move", "")), DeepUi.plural(int(sped.get("in", 1)), "action")], Color("ffb05a"), 18)
		"swap_gems":
			if bool(effect.get("nothing", false)):
				return
			var pair: Array = effect.get("swapped", [])
			if mine and pair.size() == 2:
				_fx.spiral_in(base, Color("b58cff"), 0.9, 24, 0.7)
				for socket in pair:
					if int(socket) < _socket_cards.size():
						var card: Control = _socket_cards[int(socket)]
						DeepUi.shake(card, 10.0, 0.45)
						DeepUi.burst(self, _center_of(card), Color("b58cff"), 14, 120.0, 0.5)
				if int(pair[0]) < _socket_cards.size():
					_float_at(_socket_cards[int(pair[0])], "Swapped", Color("b58cff"), 16)
				DeepAudio.play("ui_deny", {"volume": 0.6})
			elif _is_player(target_id):
				_float_at(_vital_anchor(target_id), "Gems swapped", Color("b58cff"), 14)

func _sound_at(point: Vector3, name: String, volume: float = 0.6) -> void:
	## A sound from where it happens in the room.
	DeepAudio.play_at(global_position + _to_screen(point), name, {"volume": volume, "gap": 0.03})

func _hit_extras(hit: Dictionary, creature: CrystalCreature, at: Vector3) -> void:
	## What a blow on a reworked creature sets off: a claw opening, heads cut off, a drowned
	## thing getting back up, a mirror breaking.
	if _headless or _fx == null:
		return
	for freed in hit.get("released", []):
		var owner: String = str(freed.get("unit", ""))
		var from: Vector3 = creature.gripped_point() if creature != null and is_instance_valid(creature) else at
		_fx.projectile(from, _before_me(1.6, -0.7) if owner == local_id else Vector3(0, 1.5, 4.0), Color("8fd0e8"), 0.45, 0.14, Callable(), 0.8)
		if owner == local_id:
			_float_world(at + Vector3(0, 1.4, 0), "It lets go of your die", Color("8fd0e8"), 16)
	if int(hit.get("heads_cut", 0)) > 0:
		_fx.shards(at + Vector3(0, 0.5, 0), Color("c070ff"), 6 * int(hit.heads_cut), 4.0, 0.14, 1.0)
		_float_world(at + Vector3(-0.6, 1.4, 0), ("A head off" if int(hit.heads_cut) == 1 else "%d heads off" % int(hit.heads_cut)) + " · %d left" % int(hit.get("heads", 0)), Color("d8a6ef"), 18)
	if bool(hit.get("risen", false)):
		_fx.splash(Vector3(at.x, 0.2, at.z), Color("8fd0e8"), 50, 4.5, 1.1)
		_sound_at(at, "splash", 0.7)
		_float_world(at + Vector3(0, 1.4, 0), "Gets back up!", Color("8fd0e8"), 22)
		if creature != null and is_instance_valid(creature):
			creature.spawn(0.15)

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
	## A gem that did not fire sags on its socket, while its player's page is up.
	var unit_id: String = str(event.get("unit", ""))
	var page: Page = _page_for(unit_id)
	if page == null:
		return
	page.last_fired = -1
	var socket: int = int(event.get("socket", -1))
	if not _is_shown(unit_id) or socket < 0 or socket >= page.socket_cards.size():
		return
	var mine: bool = unit_id == local_id
	var card: Control = page.socket_cards[socket]
	DeepAudio.from(card, "gem_fizzle", {"volume": 0.6 if mine else 0.45, "gap": 0.02})
	card.modulate = Color(0.4, 0.4, 0.5, 1.0)
	var tween := create_tween()
	tween.tween_property(card, "modulate", Color.WHITE, 0.6)
	## It sags rather than leaps, and a dull knock goes through the pad.
	DeepUi.spring(card, -0.14, 9.0, 0.45)
	if mine:
		DeepAudio.rumble(0.0, 0.18, 0.07)
	DeepUi.burst(self, _center_of(card), Color(0.5, 0.5, 0.55), 10, 60.0, 0.6, 6.0)
	_float_at(card, "fizzle", DeepUi.DIM, 14)
	if int(event.get("healed", 0)) > 0:
		_float_at(page.hp_bar, "+" + DeepUi.number(int(event.healed)), DeepUi.GOOD, 18)
	_show_resonance(int(event.get("resonance", 0)), page)
	DeepUi.shake(page.resonance_box, 8.0, 0.25)

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
	## A blow on the reader that block takes part of is counted at the health bar, so the bars
	## hold what they were until it is.
	_soak_pace = clampf(float(event.get("pace", 1.0)), 0.0, 1.0)
	_soaking = _soak_pace > 0.0
	if _soaking:
		var hp: int = 0
		var block: int = 0
		var landings: int = 0
		for effect in event.get("effects", []):
			if str(effect.get("kind", "")) == "damage" and str(effect.get("target", "")) == local_id and int(effect.get("absorbed", 0)) > 0:
				hp += int(effect.get("hp_loss", 0))
				block += int(effect.get("absorbed", 0))
				landings += 2
		var unit: Dictionary = me()
		if landings > 0 and not unit.is_empty():
			if _held.has(local_id):
				_held[local_id].landings = int(_held[local_id].landings) + landings
			else:
				_held[local_id] = {"hp": int(unit.hp) + hp, "block": int(unit.get("block", 0)) + block, "landings": landings, "until": Time.get_ticks_msec() + HELD_MS}
	for effect in event.get("effects", []):
		_enemy_effect(effect, _creature(str(event.get("unit", ""))))
	_soaking = false

func _show_lifeline(who: String, hp: int) -> void:
	var text: String = "Lifeline · %d HP" % hp
	if who == local_id:
		_screen_fx.blink(DeepUi.GOOD, 0.25)
		_float_at(_hp_bar, text, DeepUi.GOOD, 24)
	elif _is_player(who):
		_float_at(_vital_anchor(who), text, DeepUi.GOOD, 18)
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
		elif _is_player(target_id):
			_float_at(_vital_anchor(target_id), label, DeepUi.INFO, 16)
		return
	if effect.has("lifeline"):
		_show_lifeline(target_id, int(effect.lifeline))
	if effect.has("spikes"):
		var retaliation: Dictionary = effect.spikes
		_impact(str(retaliation.target), retaliation, DeepUi.INFO, target_id == local_id, target_id)
	if effect.has("reflected"):
		## A Mirror held up: part of the blow goes straight back at whoever threw it.
		var back: Dictionary = effect.reflected
		var glass: Color = Color("dfe6ff")
		var held_at: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.8 if target_id == local_id else source + Vector3(0, 0, 1.2)
		_fx.shield(held_at, _camera.global_position - held_at, glass, 0.85, 0.45)
		_fx.beam(held_at, source, glass, 0.3, 0.12)
		_impact(str(back.get("target", "")), back, glass, target_id == local_id, target_id)
		if target_id == local_id:
			_float_at(_hp_bar, "Reflected %s" % DeepUi.number(int(effect.get("reflected_amount", 0))), glass, 18)
	_creature_fx(effect, creature, source)
	match kind:
		"damage":
			var loss: int = int(effect.get("hp_loss", 0))
			var absorbed: int = int(effect.get("absorbed", 0))
			if loss > 0:
				_react(target_id, "wince", 0.9)
			if target_id == local_id:
				var unit: Dictionary = me()
				var ratio: float = clampf(float(loss) / float(maxi(1, int(unit.get("max_hp", 60)))), 0.0, 1.0)
				DeepAudio.play("enemy_strike" if loss > 0 else "block", {"volume": clampf(0.6 + ratio * 1.2, 0.6, 1.0), "gap": 0.02})
				_camera.add_trauma(0.3 + ratio * 1.4)
				_camera.nudge(Vector3(randf_range(-0.25, 0.25), -0.12, 0.3 + ratio), 0.45)
				if absorbed > 0 and _soaking:
					## Block took part of it: counted at the bar, and the wound waits for what is left.
					var ahead_soak: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.8
					_fx.shield(ahead_soak, _camera.global_position - ahead_soak, DeepUi.BLOCK, 0.9, 0.5)
					_soak(effect, creature, ratio)
					if bool(effect.get("downed", false)):
						_announce("You are down", DeepUi.BAD, "The party fights on", 1.6)
					return
				if loss > 0:
					DeepAudio.rumble(0.3 + ratio, 0.4 + ratio * 1.5, 0.12 + ratio * 0.2)
					_screen_fx.wound(0.45 + ratio * 2.0)
					_screen_fx.kick(0.4 + ratio * 2.0)
					_screen_fx.blink(Color(1.0, 0.2, 0.15), 0.12 + ratio * 0.3)
					_slash(creature.tint if creature != null and is_instance_valid(creature) else DeepUi.BAD)
				if absorbed > 0:
					var ahead: Vector3 = _camera.global_position + (-_camera.global_transform.basis.z) * 1.8
					_fx.shield(ahead, _camera.global_position - ahead, DeepUi.BLOCK, 0.9, 0.5)
				var text: String = "−%d" % loss if loss > 0 else ("Reflected" if effect.has("reflected") and absorbed <= 0 else "Blocked")
				_float_at(_hp_bar, text, DeepUi.BAD if loss > 0 else DeepUi.BLOCK, 26 + mini(20, loss))
				## Hit while looking at someone else's page: the reader's own tab flinches too.
				if loss > 0 and not _is_shown(local_id):
					_my_tab.hurt()
				if absorbed > 0 and loss > 0:
					_float_at(_hp_bar, "%d blocked" % absorbed, DeepUi.BLOCK, 14)
				if bool(effect.get("downed", false)):
					_announce("You are down", DeepUi.BAD, "The party fights on", 1.6)
				if ratio > 0.2 and _chamber != null:
					_fx.dust_fall(40)
			elif _is_player(target_id):
				## Someone else hit: their tab flinches, and the number lands on whatever of
				## theirs is on screen.
				var where: Control = _vital_anchor(target_id)
				if where != null:
					DeepAudio.from(where, "enemy_strike", {"volume": 0.5, "gap": 0.02})
				var tab: SeatTab = _tab_of(target_id)
				if tab != null:
					tab.hurt()
				_float_at(where, "−%d" % loss, DeepUi.BAD, 18)
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
				var said: String = kind.replace("_", " ").capitalize() + (" " + DeepUi.number(int(effect.get("amount", 0))) if int(effect.get("amount", 0)) > 0 and not kind in ["stun"] else "")
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
					_float_at(_purse_spot(), "−%d pyrite taken" % amount, DeepUi.ORE, 16)
				else:
					_float_at(_purse_spot(), "+%d pyrite" % amount, DeepUi.ORE, 16)
			elif _is_player(target_id) and int(effect.get("stolen", effect.get("amount", 0))) > 0:
				_float_at(_vital_anchor(target_id), ("−%d" if kind == "steal_gold" else "+%d") % int(effect.get("stolen", effect.get("amount", 0))), DeepUi.ORE, 14)
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

class InfinityMark extends Control:
	## The Infinite mark drawn as a line rather than set as a letter: a figure of eight two
	## loops wide, drawn on from its crossing, in every color of the stones running round it.
	const TINTS: Array = ["ff5a4e", "4f8dff", "3fbf74", "a46bff", "ffc33d", "f4f7fa"]
	const STEPS: int = 120
	## How much of the figure is drawn, from the crossing round both loops.
	var progress: float = 1.0:
		set(value):
			progress = clampf(value, 0.0, 1.0)
			queue_redraw()
	## How far the colors have run round it.
	var phase: float = 0.0:
		set(value):
			phase = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func point(t: float, box: Vector2) -> Vector2:
		## A point on the figure of eight in a box this size: two round loops side by side,
		## crossing in the middle (a lemniscate of Gerono, laid on its side).
		var half: Vector2 = box * Vector2(0.5, 0.5)
		var reach: float = box.x * 0.5 * 0.86
		return half + Vector2(cos(t) * reach, sin(2.0 * t) * 0.5 * box.y * 0.86)

	func _tint(at: float) -> Color:
		var count: int = TINTS.size()
		var x: float = fposmod(at, float(count))
		var low: int = int(floor(x))
		return Color(TINTS[low]).lerp(Color(TINTS[(low + 1) % count]), x - float(low)).lightened(0.12)

	func _draw() -> void:
		var shown: int = int(round(float(STEPS) * progress))
		if shown < 2:
			return
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for i in range(shown + 1):
			var t: float = PI * 0.5 + TAU * float(i) / float(STEPS)
			points.append(point(t, size))
			colors.append(_tint(phase + 6.0 * float(i) / float(STEPS)))
		var width: float = size.y * 0.16
		var ink := Color("0a0d18", 0.95)
		draw_polyline(points, ink, width + maxf(8.0, width * 0.3), true)
		draw_circle(points[0], (width + maxf(8.0, width * 0.3)) * 0.5, ink)
		draw_circle(points[points.size() - 1], (width + maxf(8.0, width * 0.3)) * 0.5, ink)
		draw_polyline_colors(points, colors, width, true)
		draw_circle(points[0], width * 0.5, colors[0])
		draw_circle(points[points.size() - 1], width * 0.5, colors[colors.size() - 1])
		## A line of light along the top of the stroke, the way light runs along a facet.
		var shine := PackedVector2Array()
		for p in points:
			shine.append(p + Vector2(0, -width * 0.22))
		draw_polyline(shine, Color(1, 1, 1, 0.35), maxf(2.0, width * 0.22), true)

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
	## Where something on the HUD stands; a control on a page that is not up stands at its
	## player's tab.
	var shown: Control = _shown_anchor(control)
	if shown != null:
		control = shown
	return control.global_position + control.size * 0.5 - global_position

# --- the rail spent, and Infinite ---------------------------------------------------------------

func _rail_spent(event: Dictionary) -> void:
	## A rail played all it may in one turn (DeepBattle.RAIL_CAP): what was still queued for it
	## is dropped, and its sockets say so.
	var unit_id: String = str(event.get("unit", ""))
	var anchor: Control = _tab_anchor(unit_id) if not _is_shown(unit_id) else (_page_for(unit_id).tray_box if _page_for(unit_id) != null else null)
	var plays: int = int(event.get("plays", DeepBattle.RAIL_CAP))
	## Said on the screen's own clock: the rail was racing (DeepBattle.rush) when it was spent.
	_announce("The rail is spent", DeepUi.ACCENT_HI, "%d gems in one turn" % plays, 1.4, true)
	if anchor != null:
		DeepUi.burst(self, _center_of(anchor), DeepUi.ACCENT_HI, 40, 220.0, 0.6)
	DeepAudio.play("tally_fuse", {"volume": 0.7, "pitch": 0.7, "gap": 0.0})
	if _screen_fx != null:
		_screen_fx.blink(DeepUi.ACCENT_HI, 0.18)

## Reaching the ceiling (DeepRules.CEILING) is a moment of its own, the first time in a fight:
## the room is held almost still, an Infinite as tall as the room lands over it in every color
## of the stones, light runs round the figure of eight and the air fills with sparks. After
## that an Infinite number is only big.
const INFINITY_KINDS: Array = ["gem_fire", "birthstone", "rail_end"]
## Fields that only echo a creature's own health: deep in the Rift one is born at the ceiling,
## and that is not the player's doing.
const INFINITY_IGNORED: Array = ["hp_after", "max_hp_after", "hp", "max_hp"]
const INFINITY_TINTS: Array = ["ff5a4e", "4f8dff", "3fbf74", "a46bff", "ffc33d", "f4f7fa"]
## How wide an Infinite blow's mark is drawn where it lands.
const INFINITY_FLOAT: int = 150
var _infinity_seen: bool = false

static func reaches_infinity(value: Variant, depth: int = 0) -> bool:
	## Whether any count in an event reached the ceiling.
	if depth > 8:
		return false
	if value is int:
		return DeepRules.infinite(value)
	if value is Dictionary:
		for key in value:
			if not str(key) in INFINITY_IGNORED and reaches_infinity(value[key], depth + 1):
				return true
	elif value is Array:
		for item in value:
			if reaches_infinity(item, depth + 1):
				return true
	return false

func _watch_infinity(event: Dictionary, delay: float = 0.0) -> void:
	## The first count of the fight from a player's rail to reach the ceiling is celebrated.
	if _infinity_seen or not str(event.get("kind", "")) in INFINITY_KINDS or not reaches_infinity(event):
		return
	_infinity_seen = true
	if delay <= 0.0:
		_infinity_moment(event)
	else:
		_later_do(delay, _infinity_moment.bind(event))

func _infinity_point(event: Dictionary) -> Vector3:
	## Where in the room it happened: the creature its blows landed on, or the middle of it.
	for effect in event.get("effects", []):
		if effect is Dictionary:
			var creature: CrystalCreature = _creature(str(effect.get("target", "")))
			if creature != null and is_instance_valid(creature):
				return creature.centre()
	return Vector3(0, 1.2, 0)

static func infinity_tint(t: float) -> Color:
	## The stones' colors, one into the next, round and round as `t` climbs.
	var count: int = INFINITY_TINTS.size()
	var at: float = fposmod(t, float(count))
	var low: int = int(floor(at))
	return Color(INFINITY_TINTS[low]).lerp(Color(INFINITY_TINTS[(low + 1) % count]), at - float(low)).lightened(0.15)

func _infinity_moment(event: Dictionary) -> void:
	if _headless or not is_inside_tree():
		return
	var at: Vector3 = _infinity_point(event)
	var gold := Color("ffd76a")
	## The room: held almost still while it lands, then every light in it at once.
	ScreenFx.hold(0.75, 0.2)
	if _screen_fx != null:
		_screen_fx.kick(1.6)
		_screen_fx.blink(gold, 0.55)
	if _camera != null:
		_camera.add_trauma(0.95)
		_camera.punch(-7.0, 0.7)
		_camera.focus(at, 0.25, 1.2)
	if _fx != null:
		_fx.flash(at, gold, 16.0, 14.0, 0.9, 3.0)
		_fx.sparks(at, gold, 260, 13.0, 1.4, 0.1)
		_fx.shards(at, Color.WHITE, 48, 9.0, 0.18, 1.6)
		_fx.stars(at + Vector3(0, 0.4, 0), gold, 2.2, 1.6)
		for ring in range(INFINITY_TINTS.size()):
			_fx.ring_wave(Vector3(at.x, 0.0, at.z), Color(INFINITY_TINTS[ring]), 3.0 + float(ring) * 1.6, 0.6 + 0.12 * float(ring), 0.45)
	DeepAudio.play("infinity", {"volume": 1.0, "gap": 0.0})
	DeepAudio.rumble(1.0, 1.0, 0.7)
	## The mark itself, over everything, on the screen's own clock so the held room does not slow it.
	var layer := Control.new()
	layer.name = "Infinite"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 90
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var middle: Vector2 = size * Vector2(0.5, 0.42)
	var tall: int = int(clampf(size.y * 0.46, 180.0, 460.0))
	var halo := TextureRect.new()
	halo.texture = DeepUi.glow_texture()
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_add := CanvasItemMaterial.new()
	glow_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = glow_add
	halo.size = Vector2(tall * 3.2, tall * 2.0)
	halo.position = middle - halo.size * 0.5
	halo.pivot_offset = halo.size * 0.5
	halo.modulate = Color(gold, 0.0)
	layer.add_child(halo)
	var mark := InfinityMark.new()
	var mark_size := Vector2(tall * 2.1, tall * 1.05)
	mark.size = mark_size
	mark.position = middle - mark_size * 0.5
	mark.pivot_offset = mark_size * 0.5
	mark.scale = Vector2.ONE * 0.3
	mark.progress = 0.0
	layer.add_child(mark)
	var word := Label.new()
	word.text = "INFINITE"
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word_size: int = maxi(34, tall / 6)
	word.add_theme_font_override("font", DeepUi.display_font())
	word.add_theme_font_size_override("font_size", word_size)
	word.add_theme_color_override("font_color", Color.WHITE)
	word.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
	word.add_theme_constant_override("outline_size", maxi(6, word_size / 6))
	layer.add_child(word)
	var word_box: Vector2 = word.get_minimum_size()
	word.position = Vector2(middle.x - word_box.x * 0.5, middle.y + mark_size.y * 0.36)
	word.pivot_offset = word_box * 0.5
	word.modulate.a = 0.0
	word.scale = Vector2.ONE * 1.6
	var under := Label.new()
	under.text = "past counting"
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_theme_font_override("font", DeepUi.caps_font())
	under.add_theme_font_size_override("font_size", 18)
	under.add_theme_color_override("font_color", Color(gold, 0.9))
	under.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.9))
	under.add_theme_constant_override("outline_size", 5)
	layer.add_child(under)
	under.position = Vector2(middle.x - under.get_minimum_size().x * 0.5, word.position.y + word_box.y + 2.0)
	under.modulate.a = 0.0
	var show := layer.create_tween()
	show.set_ignore_time_scale(true)
	show.set_parallel(true)
	show.tween_property(dim, "color:a", 0.5, 0.2)
	show.tween_property(halo, "modulate:a", 0.85, 0.3)
	show.tween_property(halo, "scale", Vector2.ONE * 1.25, 1.6).from(Vector2.ONE * 0.4).set_trans(Tween.TRANS_SINE)
	show.tween_property(mark, "progress", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	show.tween_property(mark, "scale", Vector2.ONE * 1.12, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(mark, "scale", Vector2.ONE, 0.3).set_delay(0.42)
	show.tween_property(mark, "rotation", 0.06, 0.5).set_delay(0.5).set_trans(Tween.TRANS_SINE)
	show.tween_property(mark, "rotation", -0.04, 0.6).set_delay(1.0).set_trans(Tween.TRANS_SINE)
	show.tween_method(func(t: float) -> void:
		mark.phase = t
		halo.modulate = Color(infinity_tint(t + 0.5), halo.modulate.a), 0.0, 4.0, 2.2)
	show.tween_property(word, "modulate:a", 1.0, 0.25).set_delay(0.32)
	show.tween_property(word, "scale", Vector2.ONE, 0.32).set_delay(0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(under, "modulate:a", 1.0, 0.3).set_delay(0.6)
	show.chain().tween_interval(0.25)
	show.chain().set_parallel(true)
	show.tween_property(layer, "modulate:a", 0.0, 0.55)
	show.tween_property(mark, "scale", Vector2.ONE * 1.9, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	show.chain().tween_callback(layer.queue_free)
	## Sparks: one blast from the middle in every color, then light running round the figure of
	## eight, then the air full of falling color.
	for tint in INFINITY_TINTS:
		DeepUi.burst(layer, middle, Color(tint), 80, 950.0, 1.5, 9.0, 95)
	var trace := layer.create_tween()
	trace.set_ignore_time_scale(true)
	for k in range(36):
		var point: Vector2 = mark.position + InfinityMark.point(PI * 0.5 + TAU * float(k) / 36.0, mark_size)
		var tint: Color = infinity_tint(float(k) / 6.0)
		trace.tween_interval(0.024)
		trace.tween_callback(func() -> void: DeepUi.burst(layer, point, tint, 26, 280.0, 0.9, 7.0, 96))
	_infinity_confetti(layer)

func _infinity_float(point: Vector3) -> void:
	## An Infinite blow's number: the mark itself, drawn, popping up off what it hit.
	if _headless or _camera == null or _camera.is_position_behind(point):
		return
	var mark := InfinityMark.new()
	mark.size = Vector2(INFINITY_FLOAT, INFINITY_FLOAT * 0.5)
	var at: Vector2 = _unstack(_to_screen(point), 60)
	mark.position = at - mark.size * 0.5
	mark.pivot_offset = mark.size * 0.5
	mark.z_index = 50
	mark.scale = Vector2.ONE * 0.4
	add_child(mark)
	var rise := mark.create_tween()
	rise.set_parallel(true)
	rise.tween_property(mark, "scale", Vector2.ONE * 1.18, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(mark, "scale", Vector2.ONE, 0.2).set_delay(0.14)
	rise.tween_property(mark, "position:y", mark.position.y - 80.0, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(mark, "phase", 6.0, 1.3)
	rise.tween_property(mark, "modulate:a", 0.0, 0.5).set_delay(0.8)
	rise.chain().tween_callback(mark.queue_free)
	DeepUi.burst(self, at, Color("ffd76a"), 40, 260.0, 0.6, 6.0)

func _infinity_confetti(layer: Control) -> void:
	## The air full of color: a fall of sparks across the whole width of the room.
	var fall := CPUParticles2D.new()
	fall.one_shot = true
	fall.explosiveness = 0.25
	fall.amount = 260
	fall.lifetime = 2.4
	fall.texture = DeepUi.dot_texture()
	fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fall.emission_rect_extents = Vector2(size.x * 0.5, 8.0)
	fall.position = Vector2(size.x * 0.5, -12.0)
	fall.direction = Vector2.DOWN
	fall.spread = 25.0
	fall.initial_velocity_min = 120.0
	fall.initial_velocity_max = 340.0
	fall.gravity = Vector2(0, 380)
	fall.angular_velocity_min = -240.0
	fall.angular_velocity_max = 240.0
	fall.scale_amount_min = 0.25
	fall.scale_amount_max = 0.6
	var offsets := PackedFloat32Array()
	var tints := PackedColorArray()
	for i in range(INFINITY_TINTS.size()):
		offsets.append(float(i) / float(INFINITY_TINTS.size() - 1))
		tints.append(Color(INFINITY_TINTS[i]))
	var colors := Gradient.new()
	colors.offsets = offsets
	colors.colors = tints
	fall.color_initial_ramp = colors
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fall.material = add
	fall.z_index = 94
	layer.add_child(fall)
	fall.emitting = true

func _float_at(anchor: Control, text: String, color: Color, size: int = 18) -> void:
	if anchor == null or not is_instance_valid(anchor) or _headless:
		return
	anchor = _shown_anchor(anchor)
	var at: Vector2 = anchor.global_position + Vector2(anchor.size.x * 0.5, 0) - global_position
	DeepUi.float_text(self, _unstack(at, size), text, color, size)

func _float_world(point: Vector3, text: String, color: Color, size: int = 20) -> Label:
	if _headless or _camera == null or _camera.is_position_behind(point):
		return null
	return DeepUi.float_text(self, _unstack(_to_screen(point), size), text, color, size, 70.0, 1.1)

## Words and numbers said in the last moment, and where: a run of them at one spot (five
## blows of a Barrage, a hit and what block took off it) stack up instead of landing on top of
## one another and reading as one smudge.
var _recent_floats: Array = []
const FLOAT_STACK_MS: int = 420

func _unstack(at: Vector2, size: int) -> Vector2:
	var now: int = Time.get_ticks_msec()
	_recent_floats = _recent_floats.filter(func(entry: Array) -> bool: return now - int(entry[1]) < FLOAT_STACK_MS)
	var spot: Vector2 = at
	var step: float = float(size) * 0.95
	for _try in range(4):
		var crowded: bool = false
		for entry in _recent_floats:
			var other: Vector2 = entry[0]
			if absf(other.x - spot.x) < 60.0 and absf(other.y - spot.y) < step * 0.8:
				crowded = true
				break
		if not crowded:
			break
		spot.y -= step
	_recent_floats.append([spot, now])
	return spot

func _announce(text: String, color: Color, sub: String = "", hold: float = 1.1, real_time: bool = false) -> void:
	## A title across the room: it lands large and settles, holds, and fades. `real_time` plays
	## it on the screen's own clock, for a title said while the fight's is racing.
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner_sub.visible = not sub.is_empty()
	_banner_box.modulate.a = 0.0
	_banner_box.pivot_offset = _banner_box.size * 0.5
	_banner_box.scale = Vector2.ONE * 1.35
	## The last title's fade would otherwise carry on and take this one down with it.
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	var tween := create_tween()
	_banner_tween = tween
	tween.set_ignore_time_scale(real_time)
	tween.set_parallel(true)
	tween.tween_property(_banner_box, "modulate:a", 1.0, 0.18)
	tween.tween_property(_banner_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_banner_box, "modulate:a", 0.0, 0.5).set_delay(hold)
