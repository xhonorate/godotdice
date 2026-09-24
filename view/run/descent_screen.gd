extends Control
## The run: the shaft's tunnels, its chambers and landings, and the fight when there is one.
## Every screen here shows the run state it is given and turns clicks into commands; the
## battle screen inside it does the same for a fight.
##
## The whole run happens in the mine itself: the mine stage is always on screen, the party
## walks from room to room down real tunnels, chooses a way at the mouths in a room's far
## wall, and is sealed into a fight by a rockfall that crumbles when it is won. What is text
## by nature (a stall's goods, an oddity's choices, the stakes, a landing's respite) is a
## page over the room. Pages are rebuilt whenever the state moves (they are cheap: stones and
## dice are photographs), and only animate in when the page is new, so a vote or a strike
## never makes the whole screen jump. The chart of the stretch folds out on the left.

const BattleScreen = preload("res://view/battle/battle_screen.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeScreen = preload("res://view/home/home_screen.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const MineStage = preload("res://view/run/mine_stage.gd")
const ShaftMap = preload("res://view/run/shaft_map.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const BenchPanel = preload("res://view/run/bench_panel.gd")
const RunDock = preload("res://view/run/run_dock.gd")

signal command(cmd: Dictionary)
signal home_requested
signal menu_requested

const KIND_WORDS: Dictionary = {"fight": "A fight", "elite": "Something big", "vein": "A vein", "oddity": "Something odd",
	"motherlode": "A glittering hollow", "merchant": "A merchant", "smithy": "A smithy", "carver": "A carver's bench", "landing": "The landing",
	"hidden": "A dark mouth", "well": "A wishing well"}
## How many of the bag's stones the scales name at once: the chip is a panel, not a page.
const SCALES_LISTED := 10

const KIND_TEXT: Dictionary = {"fight": "Creatures of the rock. Pyrite, and a fair chance of a raw stone.",
	"elite": "Something big and angry. A stone a grade better, guaranteed.",
	"vein": "A wall of glinting rock. Strike it for stones and pyrite.",
	"oddity": "Something strange in the dark: a gamble with your stones or dice.",
	"motherlode": "A hollow glittering with stones. Take them.",
	"merchant": "A stall on a ledge: stones for pyrite, appraisals, and a buyer for what you found.",
	"smithy": "An anvil and a rack of files: make one of your dice a size bigger, or a size smaller.",
	"carver": "Fine chisels under a lamp: raise one face of a die, or recut it to show another's number.",
	"landing": "Solid ground and a lift: rest, appraise or back to the wheel, then up or down.",
	"well": "A wet brick shaft going down past the lantern. Drop a stone in and it gives one back; throw pyrite in and it gives back something still in its rock.",
	"hidden": "Too dark to see. Anything could be down there."}
## How many things to work on stand on one line of a room's second page.
const WORK_PAGE: int = 8
## How wide the chart is where it lies over the left of the room.
const MAP_WIDTH := 400.0
## How many salvage rolls, and how many stones coming home, go on one page.
const SALVAGE_PAGE: int = 6
const HOME_PAGE: int = 14
const ODDITY_GLYPHS: Dictionary = {"CUTTERS_WHEEL": "cut", "ACID_BATH": "drop", "CRUCIBLE": "flame", "GEODE": "ore", "GRINDER": "die",
	"OLD_PROSPECTOR": "person", "SHRINE": "star", "IDOL": "eye", "ECHO_CHAMBER": "copy", "COLLECTOR": "coins",
	"LOUPE_CABINET": "loupe", "FIELD_MEDIC": "cross", "VUG": "pick", "TUMBLER": "reroll", "SEAM": "gem", "SMITHY": "anvil", "CARVER": "face",
	"ANNEALING_OVEN": "flame", "WISHING_WELL": "drop"}

var local_id: String = ""
var run: Dictionary = {}
var forecast_provider: Callable = Callable()
var _strip: HBoxContainer
var _body: Control
var _stage: Control
var _scrim: ColorRect
var _battle: BattleScreen
var _area: HBoxContainer
var _map: Control
var _map_margin: MarginContainer
var _page_holder: Control
var _crossroads: Control
var _cross_mark: CenterContainer
var _cross_title: Label
var _cross_sub: Label
var _cross_hint: HBoxContainer
var _chip: PanelContainer
var _chip_index: int = -1
## A thing in the room under the cursor (a vein's spot, a stall's goods), shown in the chip.
var _chip_pick: String = ""
## A strike sent and not yet answered: the vein waits for the rock to answer.
var _strike_pending: bool = false
## A thing in the room clicked on: its chip stays up, with buttons, until something else is.
var _pinned: String = ""
## The rail, the dice and the bag, along the bottom outside a fight.
var _run_dock: Control
var _stall_opened: String = ""
## A mouth clicked at a landing: when the party's ways down are offered, the vote goes to it.
var _descend_via: int = -1
## The end of a run: the ride up (or the dark) first, then the summary.
var _end_started: bool = false
var _end_shown: bool = false
var _salvage_thrown: bool = false
## The pages of the salvage whose dice have been rolled on screen.
var _salvage_rolled: Dictionary = {}
## The page each long list on a page is turned to: the salvage, what comes home.
var _pages: Dictionary = {}
## The chart of the stretch folds out over the room when asked for.
var _chart_open: bool = false
## On the way to the next room: nothing of the room ahead is shown until the party is in it.
var _walking: bool = false
var _arrive_quietly: bool = false
## The ways on the party was last offered, in the order of the mouths they were shown at.
var _last_offers: Array = []
## Counts the strip keeps showing until what was won has flown up to it: {ore, haul}.
var _strip_hold: Dictionary = {}
var _ore_pill: Control = null
var _bag_pill: Control = null
var _view_key: String = ""
var _bench: Control
var _toasts: VBoxContainer
var _fresh: bool = true
var _headless: bool = false
var _hold: Dictionary = {}
var _last_chamber: Dictionary = {}
var _last_battle: Dictionary = {}
var _shown_depth: int = -1
## The pick stake taken at the shaft head whose three are on show, until one is kept.
var _stake_choosing: String = ""
var _counts: Dictionary = {}
## Where the ore and bag pills were last seen on the strip, so a spoil thrown at one in the
## same frame the strip was rebuilt still flies to the right place. See `_pill_centre`.
var _pill_spots: Dictionary = {}
## What each slot of a room's card is set to, by room and choice, and which slot the tray
## over the dock is open for. See `_picker`.
var _choice_picks: Dictionary = {}
var _choice_slot: String = ""
## The room the picks above belong to: they are forgotten the moment the party leaves it.
var _choice_room: String = ""
## What the chip was last placed over, so it is placed once and then left alone.
var _chip_over: String = ""
## The piece of work picked out of a room's card, before the thing to do it to is chosen.
var _oddity_step: String = ""

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var strip_panel := PanelContainer.new()
	var strip_style := DeepUi.flat(Color(0.035, 0.045, 0.065, 0.97), Color(0, 0, 0, 0), 0, 10)
	strip_style.border_width_bottom = 1
	strip_style.border_color = Color(DeepUi.ACCENT_DIM, 0.6)
	strip_style.content_margin_left = 20
	strip_style.content_margin_right = 20
	strip_style.shadow_color = Color(0, 0, 0, 0.5)
	strip_style.shadow_size = 8
	strip_panel.add_theme_stylebox_override("panel", strip_style)
	strip_panel.z_index = 5
	column.add_child(strip_panel)
	_strip = DeepUi.hbox(strip_panel, 18)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.clip_contents = true
	column.add_child(_body)
	## The mine, always on screen: every room, tunnel and fight is drawn on it.
	_stage = MineStage.new()
	_stage.mouth_hovered.connect(_hover_mouth)
	_stage.mouth_pressed.connect(_choose_mouth)
	_stage.pick_hovered.connect(_hover_pick)
	_stage.pick_pressed.connect(_press_pick)
	_stage.pick_inspected.connect(_inspect_pick)
	_body.add_child(_stage)
	## A shade over the room behind a page, so the words stand off the rock.
	_scrim = ColorRect.new()
	_scrim.color = Color(0.01, 0.012, 0.02, 0.62)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	_body.add_child(_scrim)
	_battle = BattleScreen.new()
	_battle.stage = _stage
	_battle.spoils = true
	_battle.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	_battle.visible = false
	_body.add_child(_battle)
	_build_crossroads()
	_area = HBoxContainer.new()
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_theme_constant_override("separation", 0)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_area)
	## The chart lies over the left of the room rather than taking a column out of it: a page
	## that shuffled sideways every time the map was opened was worse than either.
	_map_margin = DeepUi.margin(_body, 18)
	_map_margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_map_margin.offset_right = MAP_WIDTH
	_map_margin.offset_top = 8.0
	_map_margin.add_theme_constant_override("margin_right", 0)
	_map_margin.visible = false
	_map = ShaftMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.vote.connect(func(offer_id: String) -> void: command.emit({"kind": "vote_tunnel", "offer": offer_id}))
	_map.light.connect(func() -> void: command.emit({"kind": "light"}))
	_map_margin.add_child(_map)
	_page_holder = Control.new()
	_page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_page_holder)
	_run_dock = RunDock.new()
	_run_dock.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	_run_dock.drawer_toggled.connect(func(_open: bool) -> void: _fit_area())
	_run_dock.chose.connect(_on_dock_chose)
	_run_dock.visible = false
	_body.add_child(_run_dock)
	## The bench lies over everything but the toasts, whatever page is showing.
	_bench = BenchPanel.new()
	_bench.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	add_child(_bench)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 28)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.z_index = 20
	add_child(_toasts)

func bind(player_id: String, forecast: Callable) -> void:
	local_id = player_id
	forecast_provider = forecast
	_map.local_id = player_id
	_map.run = {}
	_battle.bind(player_id)
	_battle.warm_up()
	_bench.local_id = player_id
	_bench.visible = false
	_run_dock.local_id = player_id
	_run_dock.set_drawer(false)
	_pinned = ""
	_stall_opened = ""
	_descend_via = -1
	_end_started = false
	_end_shown = false
	_salvage_thrown = false
	_salvage_rolled = {}
	_pages = {}
	## A new run starts with a clean slate: nothing held, nothing counted, nobody walking.
	_hold = {}
	_counts = {}
	_strip_hold = {}
	_shown_depth = -1
	_last_chamber = {}
	_last_battle = {}
	_last_offers = []
	_walking = false

func warm_up() -> void:
	## Pays for the mine's shaders while nobody is looking.
	_stage.warm_up()

func walking() -> bool:
	return _walking

func apply_quality() -> void:
	_battle.apply_quality()

func apply_look() -> void:
	_stage.apply_look()

func _celebrate(which: String, text: String, color: Color) -> void:
	## Deferred, and the strip may have been rebuilt since: the pill is looked up now.
	var found: Variant = _ore_pill if which == "ore" else _bag_pill
	if _headless or found == null or not is_instance_valid(found) or not (found as Control).is_inside_tree():
		return
	var pill: Control = found
	DeepUi.pulse(pill, 1.3, 0.45)
	var at: Vector2 = pill.global_position + Vector2(pill.size.x * 0.5, pill.size.y + 4.0) - global_position
	var label := DeepUi.float_text(self, at, text, color, 20, -34.0, 1.3)
	label.z_index = 30
	DeepUi.burst(self, at, color, 14, 140.0, 0.5, 5.0)

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

# --- state -----------------------------------------------------------------------------------

func show_state(state: Dictionary) -> void:
	run = state
	var phase: String = str(run.get("phase", ""))
	## Remember the chamber and the fight as they were: when either ends the state moves on
	## at once, and the page that shows what came of them is drawn from these.
	if phase == "chamber" and not run.get("chamber", {}).is_empty():
		_last_chamber = run.chamber
	if DeepDescent.in_battle(run):
		_last_battle = DeepDescent.battle(run)
	## A held page gives way the moment the party is somewhere new without us.
	if not _hold.is_empty() and _hold_is_stale():
		_hold = {}
		_strip_hold = {}
	_sync_strip()
	## The card's slots belong to the room they were set in, and so does any tray open over
	## the dock: both are let go the moment the party is somewhere else.
	var room_key: String = "%s:%s:%d" % [phase, str(run.get("chamber", {}).get("oddity", "")), int(run.get("depth", 0))]
	if room_key != _choice_room:
		_choice_room = room_key
		_choice_picks.clear()
		_choice_slot = ""
		_oddity_step = ""
		if _run_dock != null and _run_dock.choosing():
			_run_dock.cancel_offer()
	if phase == "over":
		_bench.visible = false
	_bench.refresh(run)
	_sync_stage()
	## Outside a fight the party's kit stays at hand along the bottom.
	_run_dock.visible = (_walking or not DeepDescent.in_battle(run)) and not phase in ["salvage", "over"] and not (not _hold.is_empty() and str(_hold.get("stage", "")) == "battle")
	_run_dock.show_run(run)
	_fit_area()
	if phase != "grubstake":
		_stake_choosing = ""
	if _walking:
		## On the way: only the mine and the strip until the party is in the next room.
		_battle.visible = false
		_area.visible = false
		_scrim.visible = false
		_crossroads.visible = false
		return
	_shown_depth = int(run.get("depth", 0))
	var key: String = phase
	if phase == "chamber":
		key += ":" + str(run.chamber.get("kind", "")) + ":" + str(run.depth) + (":battle" if DeepDescent.in_battle(run) else ":" + str(bool(run.chamber.get("settled", false))))
	elif phase == "landing":
		key += ":" + str(run.depth)
	elif phase == "tunnels":
		key += ":" + str(run.depth)
	elif phase == "grubstake":
		key += ":" + str(me().get("stake", "")) + ":" + _stake_choosing
	if phase != "grubstake":
		_stake_choosing = ""
	if not _hold.is_empty():
		key = "hold:%s:%s:%d" % [str(_hold.kind), str(_hold.get("stage", "")), int(_hold.get("depth", 0))]
	_fresh = key != _view_key
	_view_key = key
	var mine: String = str(run.get("mine", ""))
	if not _hold.is_empty() and str(_hold.get("stage", "")) in ["battle", "spoils", "flight"]:
		## The fight is over but its last moments are still playing: keep the room up, and
		## the fight's own screen while its banner holds.
		_battle.visible = str(_hold.stage) == "battle"
		_area.visible = false
		_scrim.visible = false
		_crossroads.visible = false
		return
	if DeepDescent.in_battle(run):
		## The chart puts itself away as the rock comes down: there is nothing on it to read
		## during a fight, and it sits over the room the fight is in.
		if _chart_open:
			_chart_open = false
			_map_margin.visible = false
		_battle.visible = true
		_area.visible = false
		_scrim.visible = false
		_crossroads.visible = false
		DeepUi.clear(_page_holder)
		var forecast: Dictionary = forecast_provider.call() if forecast_provider.is_valid() else {}
		_battle.show_state(DeepDescent.battle(run), int(run.depth), forecast, {"mine": mine, "kind": str(run.chamber.get("kind", "fight")),
			"exits": int(_stage.place.get("exits", 2))})
		return
	_battle.visible = false
	_area.visible = true
	_map_margin.visible = _chart_open
	_map.show_run(run)
	DeepUi.clear(_page_holder)
	if phase == "tunnels" and _hold.is_empty():
		## The way on is chosen at the mouths themselves.
		_scrim.visible = false
		_show_crossroads()
		if _descend_via >= 0:
			var via: int = _descend_via
			_descend_via = -1
			_choose_mouth.call_deferred(via)
		return
	if phase == "chamber" and str(run.chamber.get("kind", "")) in ["vein", "vug"] and _hold.is_empty():
		## A vein is worked in the room itself.
		_scrim.visible = false
		_show_vein()
		return
	if phase == "chamber" and str(run.chamber.get("kind", "")) == "merchant" and _hold.is_empty():
		## So is a stall: its goods are on the counter.
		_scrim.visible = false
		_show_stall()
		return
	if phase == "landing" and _hold.is_empty():
		## A landing: rest, read or polish at the things in the room, then the lift or a mouth.
		_scrim.visible = false
		_show_landing()
		return
	if phase == "hoard" and _hold.is_empty():
		_scrim.visible = false
		_show_hoard()
		return
	if phase == "over" and not _end_shown:
		## The lift goes up, or the lights go out, before the summary.
		_crossroads.visible = false
		_scrim.visible = false
		_area.visible = false
		if not _end_started:
			_end_started = true
			_run_dock.set_drawer(false)
			if str(run.get("outcome", "")) in ["extracted", "conquered"]:
				_stage.ride_lift(_end_ready)
			else:
				_stage.darken(_end_ready)
		if not _end_shown:
			return
	_crossroads.visible = false
	_chip_index = -1
	_chip_pick = ""
	_stage.close_ways()
	if phase == "chamber" and str(run.chamber.get("kind", "")) in ["oddity"] + DeepDescent.CARD_ROOMS and _hold.is_empty():
		## An oddity stands in the room, as does a smithy's anvil or a carver's bench; the
		## choices are cards along the bottom.
		_scrim.visible = false
		_show_oddity()
		return
	if phase == "salvage":
		## The dice are thrown in the room; the reckoning is read down the side.
		_scrim.visible = false
		if not _salvage_thrown:
			_salvage_thrown = true
			_stage.salvage(run.get("salvage", {}).get(local_id, {}).get("rolls", []), _pill_centre("bag"))
		_page_salvage(_side_page())
		return
	## Everything else outside a fight is a page over the room.
	_scrim.visible = true
	var content := _page()
	if not _hold.is_empty():
		match str(_hold.kind):
			"victory", "spoils": _page_spoils(content)
			"oddity": _page_oddity_result(content)
			"stake": _page_stake_result(content)
		return
	match phase:
		"grubstake": _page_grubstake(content)
		"over": _page_over(content)

# --- holding a moment ------------------------------------------------------------------------
##
## The rules move on the instant a chamber is done: the last strike of a vein, the killing
## blow, the last choice at an oddity. The screen does not. It holds the page that shows
## what came of it (the rock with every find in it, the spoils of a fight) until the player
## says to move on. A held page is local to this screen; the party is never kept waiting on
## it, and it lets go by itself if the party walks on without us.

func _hold_page(kind: String, fields: Dictionary) -> void:
	_hold = {"kind": kind, "depth": int(run.get("depth", 0)), "token": randi()}
	_hold.merge(fields, true)

func _hold_is_stale() -> bool:
	var phase: String = str(run.get("phase", ""))
	if str(_hold.kind) == "defeat":
		return phase == "over"
	if int(run.get("depth", 0)) > int(_hold.get("depth", 0)):
		return true
	if DeepDescent.in_battle(run):
		return true
	return phase in ["salvage", "over"] and str(_hold.kind) != "defeat"

func _release() -> void:
	## "Onward": let go of the held page and show where the party is now.
	_hold = {}
	show_state(run)

func _after_fight(token: int, stage: String) -> void:
	## The last blow has landed and the banner has had its moment: the spoils on the floor
	## resolve into what was won and fly up to the strip, then the way on opens.
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	if stage != "spoils":
		_hold = {}
		show_state(run)
		return
	_hold.stage = "spoils"
	show_state(run)
	## The strip was torn down and built again a line ago and its pills have no place on the
	## screen until the next layout pass. The spoils have to be told where to fly, so they
	## wait that one frame out.
	if not _headless and is_inside_tree():
		await get_tree().process_frame
		if _hold.is_empty() or int(_hold.get("token", -1)) != token:
			return
	var rewards: Dictionary = _hold.get("rewards", {})
	_stage.claim(rewards, _pill_centre("ore"), _pill_centre("bag"), _release_count.bind("ore"), _release_count.bind("haul"),
		_spoils_landed.bind(token, rewards))

func _pill_centre(which: String) -> Vector2:
	## A pill on the strip, in the stage's coordinates, so spoils fly up out of the room and
	## into it. The strip is torn down and rebuilt on every state, and the spoils are claimed
	## in the same breath, so the new pills have not been laid out yet and read as the top
	## left corner: where they stood last is remembered and used until they are placed again.
	var pill: Variant = _ore_pill if which == "ore" else _bag_pill
	if pill != null and is_instance_valid(pill):
		var control: Control = pill
		if control.size.x > 1.0 and control.global_position != Vector2.ZERO:
			_pill_spots[which] = control.global_position + control.size * 0.5 - _stage.global_position
	## Failing everything, the right-hand end of the strip, which is where they live.
	return _pill_spots.get(which, Vector2(_stage.size.x * 0.86, -18.0))

func _release_count(key: String) -> void:
	if _strip_hold.has(key):
		_strip_hold.erase(key)
		_sync_strip()

func _spoils_landed(token: int, rewards: Dictionary) -> void:
	_strip_hold = {}
	_sync_strip()
	var words: Array = []
	if int(rewards.get("ore", 0)) != 0:
		words.append("%+d pyrite" % int(rewards.ore))
	for stone in rewards.get("stones", []):
		words.append(DeepStone.raw_name(stone) if not bool(stone.get("appraised", false)) else DeepUi.stone_name(stone))
	if not words.is_empty():
		toast("  ·  ".join(words), DeepUi.ORE, "bag")
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	_hold = {}
	show_state(run)

func _depth_title(depth: int, kind: String) -> void:
	## A title over the tunnel's last stretch: the depth, what waits, and the biome it is in.
	## No curtain: the party sees where it is going.
	if _headless:
		return
	DeepAudio.play("depth_card", {"volume": 0.8})
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(card)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(centre)
	var column := DeepUi.vbox(centre, 6)
	var tone: Color = DeepUi.CHAMBER_colorS.get(kind, DeepUi.ACCENT)
	var mark := DeepUi.icon(column, str(DeepUi.CHAMBER_GLYPHS.get(kind, "stairs")), 54, tone)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var heading := DeepUi.title(column, "Depth %d" % depth, 54, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	heading.add_theme_constant_override("outline_size", 10)
	var words: String = str(KIND_WORDS.get(kind, kind.capitalize())) if kind != "warden" else "A Warden"
	var biome: Dictionary = Biomes.for_depth(str(run.get("mine", "")), maxi(1, depth))
	var line := DeepUi.label(column, "%s  ·  %s" % [words, str(biome.get("name", ""))], 18, tone.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	line.add_theme_constant_override("outline_size", 6)
	card.modulate.a = 0.0
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.1)
	tween.tween_property(card, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(card.queue_free)

func _page() -> VBoxContainer:
	## A page over the room, centred in it. It never scrolls: a page holds what fits, and a
	## long list on one is turned a page at a time.
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_holder.add_child(centre)
	var margin := DeepUi.margin(centre, 28, 22)
	var content := DeepUi.vbox(margin, 18)
	content.custom_minimum_size.x = 940
	return content

func _enter(node: Control, delay: float = 0.0) -> void:
	## Only a new page eases in; a page rebuilt by a vote or a strike just appears.
	if _fresh:
		DeepUi.pop_in(node, delay)

func _paged(parent: Node, list: String, items: Array, per_page: int) -> Array:
	## The items of a long list that go on its current page, and the pager for the rest.
	var count: int = DeepUi.pages(items.size(), per_page)
	var page: int = clampi(int(_pages.get(list, 0)), 0, count - 1)
	_pages[list] = page
	if count > 1:
		DeepUi.pager(parent, page, count, func(to: int) -> void:
			_pages[list] = to
			DeepAudio.play("ui_tap", {"volume": 0.6})
			show_state(run))
	return DeepUi.page_of(items, page, per_page)

func handle(event: Dictionary) -> void:
	## One event from the host. Fights are animated; everything else gets a line of text.
	var kind: String = str(event.get("kind", ""))
	match kind:
		"staked":
			if str(event.get("unit", "")) == local_id:
				## Until the party is staked the shaft head shows what this did. Once it moves
				## on, a stake left to chance holds its result up; any other says it in a line.
				var chance: bool = not event.get("changed", []).is_empty() or event.get("boons", []).any(func(k: Variant) -> bool: return str(DeepContent.boon(str(k)).get("group", "")) == "long_shot")
				if bool(event.get("finished", false)) and not chance and not str(event.get("message", "")).is_empty():
					toast(str(event.message), DeepUi.ACCENT, "bag")
				else:
					DeepAudio.play("dice_lock", {"volume": 0.8})
				if bool(event.get("finished", false)) and chance:
					_hold_page("stake", {"result": {"boons": event.get("boons", []), "message": str(event.get("message", "")),
						"made": event.get("made", []), "dice": event.get("dice", []), "changed": event.get("changed", [])}})
		"battle":
			if event.has("battle"):
				_battle.perform(event.battle)
			if event.has("resolution"):
				_battle.perform(event.resolution)
			if event.has("settle"):
				var settle: Dictionary = event.settle
				var fight: Dictionary = _last_battle
				if str(settle.get("outcome", "")) == "victory":
					_strip_hold = _counts.duplicate()
					_hold_page("victory", {"stage": "battle", "settle": settle, "rewards": settle.get("rewards", {}).get(local_id, {}),
						"chamber": str(settle.get("kind", "fight")), "turns": int(fight.get("turn", 1)),
						"slain": fight.get("enemies", []).map(func(e: Dictionary) -> String: return str(e.get("name", "")))})
					_later(2.3, _after_fight.bind(int(_hold.token), "spoils"))
				else:
					_hold_page("defeat", {"stage": "battle"})
					_later(2.8, _after_fight.bind(int(_hold.token), "release"))
		"vein_strike":
			_vein_struck(event)
		"oddity_result":
			## The cabinet's one good lens reads a stone the way any other appraisal does.
			if str(event.get("unit", "")) == local_id and _oddity_action(str(event.get("choice", ""))) == "appraise" and not event.get("changed", []).is_empty():
				_appraisal(event.changed[0])
			if str(event.get("unit", "")) == local_id and bool(event.get("vug", false)):
				toast(str(event.get("message", "")), DeepUi.PAPER, "question")
			elif bool(event.get("finished", false)):
				var mine_result: Dictionary = _last_chamber.get("results", {}).get(local_id, {})
				if str(event.get("unit", "")) == local_id:
					mine_result = {"choice": str(event.get("choice", "")), "message": str(event.get("message", "")), "made": event.get("made", []),
						"lost": event.get("lost", []), "changed": event.get("changed", []), "dice": event.get("dice", [])}
				if not mine_result.is_empty():
					_hold_page("oddity", {"oddity": str(_last_chamber.get("oddity", "")), "room": str(_last_chamber.get("kind", "oddity")), "result": mine_result})
		"appraised":
			if str(event.get("unit", "")) == local_id:
				_appraisal(event.stone)
		"hoard_pick":
			if str(event.get("unit", "")) == local_id:
				_pinned = ""
				_chip_pick = ""
				var taken: Dictionary = event.get("stone", {})
				_stage.hoard_take(str(taken.get("id", "")), _pill_centre("bag"))
				DeepAudio.reveal_stone(taken)
				var known: bool = bool(taken.get("appraised", false))
				Inspector.stone(taken, {"fanfare": {"title": "The hoard is yours",
					"subtitle": "Taken from the Warden's pile, appraised and ready to set." if known else "Taken from the Warden's pile, still in its rock. Nobody knows what it is yet.",
					"button": "Take it home"}})
		"given":
			toast("%s gave %s something." % [str(DeepDescent.player(run, str(event.get("from", ""))).get("name", "")), str(DeepDescent.player(run, str(event.get("to", ""))).get("name", ""))], DeepUi.INFO, "party")
		"bought":
			## Off the counter and into the bag it goes, or away with whoever bought it.
			var item: Dictionary = event.get("item", {})
			var buyer: bool = str(event.get("unit", "")) == local_id
			_stage.stall_sold(str(item.get("id", "")), _pill_centre("bag"), buyer)
			_stage.remove_pick("item:%s" % str(item.get("id", "")))
			if _pinned == "item:%s" % str(item.get("id", "")):
				_pinned = ""
				_chip_pick = ""
			if buyer:
				DeepAudio.play("buy")
				toast("Bought %s for %d pyrite" % [DeepUi.stone_name(item.get("stone", {})), int(item.get("price", 0))], DeepUi.ORE, "purse")
		"sold":
			var counter: Node3D = _stage.business()
			if counter != null and counter.has_method("weigh"):
				counter.weigh()
			if str(event.get("unit", "")) == local_id:
				DeepAudio.play("sell")
				toast("Sold for %d pyrite" % int(event.get("paid", 0)), DeepUi.ORE, "scales")
		"respite":
			var lift: Node3D = _stage.hall()
			if lift != null and str(event.get("choice", "")) == "polish":
				lift.spark_wheel(_stage.fx)
			if str(event.get("unit", "")) == local_id:
				match str(event.get("choice", "")):
					"rest":
						DeepAudio.play("heal", {"volume": 0.8})
						toast("+%d health" % int(event.get("healed", 0)), DeepUi.GOOD, "heart")
					"appraise":
						_appraisal(event.get("stone", {}))
					"polish":
						DeepAudio.play("dice_lock", {"volume": 0.8})
						Inspector.stone(event.get("stone", {}), {"fanfare": {"title": "Polished", "subtitle": str(event.get("message", "")), "button": "Good"}})
		"motherlode":
			DeepAudio.play("stone_found")
			_hold_page("spoils", {"title": "A motherlode", "subtitle": "A hollow full of stones. Take them.", "glyph": "gem",
				"rewards": event.get("rewards", {}).get(local_id, {})})
		"landing":
			DeepAudio.play("landing")
			toast("The landing. Breathe.", DeepUi.GOOD, "lift")
		"lit":
			var who: String = str(DeepDescent.player(run, str(event.get("unit", ""))).get("name", ""))
			var paid: String = "%d pyrite" % DeepDescent.lantern_cost()
			var lighter: String = "You light" if str(event.get("unit", "")) == local_id else "%s lights" % who
			DeepAudio.play("lantern")
			toast("%s the way to depth %d (%s)." % [lighter, int(event.get("to", 0)), paid], DeepUi.ACCENT, "lantern")
			if not _headless and is_instance_valid(_map) and _map.is_visible_in_tree():
				DeepUi.burst(self, _map.global_position - global_position + _map.size * Vector2(0.5, 0.35), DeepUi.ACCENT, 26, 220.0, 0.8, 5.0)
		"abandoned":
			_hold = {}
			toast("The dig is abandoned.", DeepUi.BAD, "flag")

func _page_bath(content: VBoxContainer, stones: Array, tone: Color, key: String, oddity: Dictionary) -> void:
	## Out of the bath one at a time. Each raw stone is held up large and what the acid found
	## in it is read off: the names of what is frozen inside, or that there is nothing.
	var step: int = clampi(int(_hold.get("step", 0)), 0, stones.size() - 1)
	var stone: Dictionary = stones[step]
	var hue: Color = GemMesh.tint(stone)
	var head := DeepUi.vbox(content, 4)
	var title_row := DeepUi.hbox(head, 10)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, str(ODDITY_GLYPHS.get(key, "drop")), 24, tone)
	DeepUi.title(title_row, str(oddity.get("name", "Acid Bath")), 30, DeepUi.PAPER)
	DeepUi.label(head, "%d of %s out of the bath" % [step + 1, DeepUi.plural(stones.size(), "stone")], 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	var card := DeepUi.card(content, Color(hue, 0.6), 18)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := DeepUi.hbox(card, 22)
	var lens := Control.new()
	lens.custom_minimum_size = Vector2(230, 230)
	lens.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(lens)
	var view := GemView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_drift(true)
	view.set_spin(0.4)
	view.configure(stone)
	lens.add_child(view)
	var words := DeepUi.vbox(row, 8)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(words, DeepStone.raw_name(stone), 24, hue.lightened(0.3))
	StoneCard.size_stat(words, stone, 13)
	var inside: Array = stone.get("inclusions", [])
	if inside.is_empty():
		DeepUi.stat(words, "clean_drop", "Nothing frozen inside it.", DeepUi.MUTED, 15)
	else:
		DeepUi.section(words, "spark", "Frozen inside it", DeepUi.INFO)
		for name in inside:
			var line := DeepUi.vbox(words, 0)
			var inclusion: Dictionary = DeepContent.inclusion(str(name))
			DeepUi.stat(line, "spark", str(inclusion.get("name", name)), DeepUi.INFO, 15)
			DeepUi.wrap(line, str(inclusion.get("text", "")), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 320)
	_enter(card, 0.05)
	var foot := DeepUi.hbox(content, 12)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if step + 1 < stones.size():
		var next := DeepUi.primary(foot, "next", "Next stone", func() -> void:
			if _hold.is_empty():
				return
			_hold.step = step + 1
			_view_key = ""
			show_state(run), 16, tone)
		next.custom_minimum_size.x = 220
	else:
		var done := DeepUi.primary(foot, "check", "Onward", _release, 16, tone)
		done.custom_minimum_size.x = 220
	_enter(foot, 0.12)

func _oddity_action(choice_id: String) -> String:
	for choice in DeepContent.oddity(str(_last_chamber.get("oddity", ""))).get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return str(choice.get("action", {}).get("kind", ""))
	return ""

func _appraisal(stone: Dictionary) -> void:
	## A stone of ours has just been read: the whole ceremony, rock and all, then what can be
	## done with it here and now.
	if stone.is_empty():
		return
	Appraisal.open(stone, {"actions": appraisal_actions(stone)})

func appraisal_actions(stone: Dictionary) -> Array:
	## Down the mine a stone just read goes in the bag, into an empty socket if there is one
	## it can go in, or onto the merchant's scales if there is a merchant.
	var id: String = str(stone.get("id", ""))
	var unit: Dictionary = me()
	var known: Dictionary = stone.duplicate(true)
	known.appraised = true
	var out: Array = []
	if DeepDescent.bench_open(run):
		var rail: Array = unit.get("rail", [])
		for index in range(rail.size()):
			if rail[index] == null and DeepDescent.socket_refusal(unit, known, index).is_empty():
				var socket: int = index
				out.append({"label": "Set in socket %d" % (socket + 1), "glyph": "gem", "tone": DeepUi.GOOD, "caption": "Into the rail for the next fight",
					"call": func() -> void: command.emit({"kind": "socket", "stone_id": id, "index": socket})})
				break
	out.append({"label": "Into the bag", "glyph": "bag", "tone": DeepUi.ACCENT, "caption": "Set it from the bench any time", "dismiss": true})
	if DeepDescent.at_stall(run):
		out.append({"label": "Sell for %d pyrite" % DeepStone.sell_value(known), "glyph": "scales", "tone": DeepUi.ORE, "caption": "Half its worth, on the scales",
			"sound": "sell", "call": func() -> void: command.emit({"kind": "sell", "stone_id": id})})
	return out

func _later(seconds: float, callback: Callable) -> void:
	if _headless or not is_inside_tree():
		callback.call()
		return
	get_tree().create_timer(seconds).timeout.connect(callback)

func toast(text: String, color: Color, glyph: String = "") -> void:
	## Three at most; the oldest makes room.
	DeepAudio.play("toast_bad" if color == DeepUi.BAD else "toast", {"volume": 0.7})
	while _toasts.get_child_count() >= 3:
		var oldest: Node = _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var box := PanelContainer.new()
	var style := DeepUi.raised(Color(0.04, 0.05, 0.07, 0.94), Color(color, 0.6), 18, 8, 0.5)
	style.content_margin_left = 14
	style.content_margin_right = 16
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(box)
	var row := DeepUi.hbox(box, 8)
	if not glyph.is_empty():
		DeepUi.icon(row, glyph, 18, color)
	DeepUi.label(row, text, 15, color)
	DeepUi.pop_in(box, 0.0, 0.8)
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 0.0, 0.6).set_delay(2.8)
	tween.tween_callback(box.queue_free)

# --- the mine ----------------------------------------------------------------------------------
##
## Where the party stands, as a room on the stage. The state already says it all: the path
## walked, the chamber, the landing and whether its Warden is dead. When the room changes the
## stage walks there through the mouth the party chose (the last ways offered, matched to the
## chamber the path now ends in); when there was no way to walk (a run begun, a party joined
## mid-run) it simply stands the party in the room.

func _place_of(state: Dictionary) -> Dictionary:
	var phase: String = str(state.get("phase", ""))
	var depth: int = int(state.get("depth", 0))
	var mine: String = str(state.get("mine", ""))
	var path: Array = state.get("path", [])
	var last: Dictionary = path.back() if not path.is_empty() else {}
	var landing: Dictionary = state.get("landing", {})
	var cleared: bool = int(landing.get("depth", -1)) == depth and bool(landing.get("cleared", false))
	var kind: String = ""
	match phase:
		"grubstake":
			kind = "head"
		"chamber":
			kind = "warden" if str(state.get("chamber", {}).get("kind", "")) == "warden" else str(last.get("kind", state.get("chamber", {}).get("kind", "fight")))
		"tunnels":
			kind = "head" if path.is_empty() or depth == 0 else ("warden" if cleared else str(last.get("kind", "fight")))
		"landing":
			kind = "warden" if cleared else "landing"
		"hoard":
			kind = "warden"
		_:
			return {}
	if kind == "head":
		depth = 0
	## How many ways on the room has: the chart knows before anyone is offered them.
	var exits: int = 2
	if phase == "tunnels":
		exits = state.get("offers", []).size()
	elif kind == "landing":
		exits = 1 if bool(landing.get("warden_next", false)) and not cleared else 2
	elif not kind in ["warden", "head"]:
		var node: Dictionary = state.get("map", {}).get("nodes", {}).get(str(last.get("id", "")), {})
		exits = node.get("next", []).size() if not node.is_empty() else 2
	## The shaft falls a little with every depth, except where a stretch runs level, and a
	## landing's way to its Warden's hall never does.
	var key: String = "%s|%d|%s" % [mine, depth, kind]
	var level: bool = absi(("%s|%d" % [mine, depth]).hash()) % 6 == 0
	var drop: float = 0.0 if (kind == "landing" and exits == 1) or level else 2.5
	return {"key": key, "mine": mine, "depth": depth, "kind": kind, "exits": clampi(exits, 1, 3), "drop": drop, "seal": DeepDescent.in_battle(state)}

func _sync_stage() -> void:
	if _headless:
		return
	var place: Dictionary = _place_of(run)
	if place.is_empty():
		return
	var tunnels: bool = str(run.get("phase", "")) == "tunnels"
	if _stage.has_room() and str(_stage.place.get("key", "")) == str(place.key):
		if tunnels and run.get("offers", []).size() != _stage.room.exits.size() and not _stage.walking():
			## The room was built for a different number of ways on than it has: build it again.
			_stage.show_room(place, true)
		if tunnels:
			_last_offers = run.offers.duplicate(true)
		return
	if _stage.walking():
		## The party moved on again before this walk was over: get there at once, and on.
		_arrive_quietly = true
		_stage.hurry()
		_arrive_quietly = false
	var index: int = -1
	var path: Array = run.get("path", [])
	var target: String = str(path.back().get("id", "")) if not path.is_empty() else ""
	for i in range(_last_offers.size()):
		if str(_last_offers[i].get("id", "")) == target and not target.is_empty():
			index = i
	if index < 0 and str(_stage.place.get("kind", "")) == "landing" and str(place.kind) == "warden" and int(_stage.place.get("depth", -1)) == int(place.depth):
		index = 0
	_last_offers = []
	if index >= 0 and _stage.has_room():
		_walking = true
		_descend_via = -1
		_pinned = ""
		## The bag a stall opened closes again as the party walks on from it.
		if not _stall_opened.is_empty() and _stall_opened == str(_stage.place.get("key", "")):
			_run_dock.set_drawer(false)
		_chip_index = -1
		_stage.walk(place, index, _arrived, _depth_title.bind(int(place.depth), str(place.kind) if str(place.kind) != "head" else "fight"))
	else:
		_stage.show_room(place)
		if DeepDescent.in_battle(run):
			_stage.seal(false)
	if tunnels:
		_last_offers = run.offers.duplicate(true)

func _arrived() -> void:
	## In the next room. A fight's ways on come down in a rockfall as the creatures rise.
	_walking = false
	if _arrive_quietly:
		return
	if DeepDescent.in_battle(run):
		_stage.seal(true)
	show_state(run)

# --- the vein ------------------------------------------------------------------------------------
##
## The vein is an outcrop in the room, six spots in it. Point at one to see what it gives
## away; click to put the pick in. Every strike, the party's own or an ally's, is played on
## the rock as it arrives, and what came out flies to whoever found it. When the rock is spent
## the finds are let land before the way on opens, and then the rock sinks away.

const VEIN_WORDS: Dictionary = {"bright": ["Something bright", "Likely a fine stone."], "glint": ["A glint", "A stone."],
	"dull": ["Dull rock", "Pyrite, or nothing but dust."]}

func _seat_color(unit_id: String) -> Color:
	var unit: Dictionary = DeepDescent.player(run, unit_id)
	return ShaftMap.SEATS[int(unit.get("seat", 0)) % ShaftMap.SEATS.size()]

func _show_vein() -> void:
	## The rock is struck as long as the arm holds out. Every swing costs a little more than
	## the last, and what is worth having is buried deeper than what is not, so the whole
	## business is a running question: one more, or walk on?
	var vein: Dictionary = run.chamber.get("vein", {})
	var hazard: bool = bool(vein.get("hazard", false))
	var spots: Array = vein.get("spots", [])
	var unit: Dictionary = me()
	var mining: bool = bool(unit.get("mining", false))
	var swings: int = int(unit.get("strikes", 0))
	var cost: int = DeepDescent.strike_cost(swings, hazard)
	var finders: Dictionary = {}
	for spot in spots:
		if not str(spot.get("taken", "")).is_empty():
			finders[int(spot.index)] = _seat_color(str(spot.taken))
	var face: Node3D = _stage.vein(spots, hazard, finders)
	if face != null:
		for spot in spots:
			var index: int = int(spot.index)
			var id: String = "spot:%d" % index
			if not _stage.has_pick(id):
				var holder: Node3D = face.spot_node(index)
				_stage.add_pick(id, holder, Vector3(0.6, 0.55, 0.45), {"hover": func(on: bool) -> void:
					if is_instance_valid(face):
						face.set_hover(index if on else -1)})
			var open: bool = mining and str(spot.get("taken", "")).is_empty() and not _strike_pending and int(unit.get("hp", 0)) > cost
			_stage.enable_pick(id, open)
			face.set_open(index, open)
	_crossroads.visible = true
	_set_cross_mark("pick", DeepUi.CHAMBER_colorS.get("vein", DeepUi.ACCENT))
	_cross_title.text = "The vug" if hazard else "A vein"
	if mining:
		_cross_sub.text = "Swing as often as you like. The next swing costs %s." % ("nothing" if cost <= 0 else "%d health" % cost)
		if int(unit.get("hp", 0)) <= cost:
			_cross_sub.text = "Another swing would finish you. Put the pick down."
	else:
		var waiting: Array = run.get("players", []).filter(func(p: Dictionary) -> bool: return bool(p.get("mining", false)) and not bool(p.get("downed", false)))
		_cross_sub.text = "You put the pick down." + (" Waiting for %s." % ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))) if not waiting.is_empty() else "")
	DeepUi.clear(_cross_hint)
	var legend := PanelContainer.new()
	legend.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.LINE, 14, 8, 0.4))
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_hint.add_child(legend)
	var row := DeepUi.hbox(legend, 18)
	DeepUi.stat(row, "pick", "%s so far" % DeepUi.plural(swings, "swing"), DeepUi.ACCENT, 12, "Every few swings the next one costs another point of health.")
	DeepUi.stat(row, "heart", ("next swing free" if cost <= 0 else "next swing: %d HP" % cost), DeepUi.BAD if cost > 0 else DeepUi.GOOD, 12)
	DeepUi.stat(row, "spark", "bright: a fine stone, deep in", Color("ffcf5a"), 12)
	DeepUi.stat(row, "spark", "glint: a stone", DeepUi.INFO, 12)
	DeepUi.stat(row, "ore", "dull: pyrite or dust", DeepUi.MUTED, 12)
	if hazard:
		DeepUi.stat(row, "skull", "bad air: %d HP on top of every swing" % DeepDescent.VUG_HP, DeepUi.BAD, 12)
	if mining:
		## Down at the bottom of the screen where every other room's choices are, not tucked
		## under the title at the top.
		var done := DeepUi.primary(_bottom_page(), "check", "Put the pick down", func() -> void:
			command.emit({"kind": "stop_mining"}), 15, DeepUi.GOOD)
		done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		done.custom_minimum_size.x = 260
		done.tooltip_text = "Leave the rest of the rock where it is and take the way on."
	_fill_chip()

func _vein_struck(event: Dictionary) -> void:
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	var index: int = int(event.get("spot", -1))
	var result: Dictionary = event.get("result", {})
	var hazard: bool = bool(_last_chamber.get("vein", {}).get("hazard", false))
	if mine:
		_strike_pending = false
	if not bool(event.get("through", true)):
		## The pick bit and the rock held. Nothing comes out of it; the spot stays open.
		if not _headless:
			_stage.vein_strike(index, _seat_color(unit_id), mine, hazard, false)
			if mine:
				var left: int = int(event.get("hardness", 1)) - int(event.get("struck", 0))
				var said: String = "the rock holds" if left <= 1 else "deep in the rock"
				var spot_at: Vector2 = _stage.pick_rect("spot:%d" % index).get_center()
				if int(event.get("hp_cost", 0)) > 0:
					DeepUi.float_text(self, spot_at + Vector2(0, -28), "-%d" % int(event.hp_cost), DeepUi.BAD, 18, 55.0, 1.0)
				DeepUi.float_text(self, spot_at, said, DeepUi.MUTED, 17, 50.0, 1.1)
		else:
			DeepAudio.play("pick_strike", {"gap": 0.0})
		show_state(run)
		return
	var landed: float = 0.0
	if _headless:
		DeepAudio.play("pick_strike", {"gap": 0.0})
	else:
		var at: Vector3 = _stage.vein_strike(index, _seat_color(unit_id), mine, hazard)
		var kind: String = str(result.get("kind", ""))
		var arrived: Callable = Callable()
		if mine and kind in ["ore", "stone"]:
			## The count on the strip waits for the find to reach it.
			var key: String = "ore" if kind == "ore" else "haul"
			if not _strip_hold.has(key) and _counts.has(key):
				_strip_hold[key] = _counts[key]
			arrived = _release_count.bind(key)
		landed = _stage.throw_find(result, at, _pill_centre("ore"), _pill_centre("bag"), arrived, mine, 0.17 if mine else 0.0)
		if mine:
			var words: String = ""
			match kind:
				"stone": words = DeepStone.raw_name(result.get("stone", {}))
				"ore": words = "+%d pyrite" % int(result.get("ore", 0))
				_: words = "nothing but dust"
			var chip_at: Vector2 = _stage.to_screen(at) + _stage.global_position - global_position
			DeepUi.float_text(self, chip_at, words, DeepUi.ORE if kind == "ore" else DeepUi.PAPER, 20, 60.0, 1.4)
	if bool(event.get("finished", false)):
		## The rock is spent. Let what came out of it land before the way on opens.
		_hold_page("vein", {"stage": "flight"})
		_later(landed + 0.7, _after_vein.bind(int(_hold.token)))

func _after_vein(token: int) -> void:
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	_hold = {}
	_strip_hold = {}
	_sync_strip()
	show_state(run)

func _hover_pick(id: String) -> void:
	## A pinned chip stays up while the pointer wanders.
	if not _pinned.is_empty():
		return
	_chip_pick = id
	if not id.is_empty():
		_chip_index = -1
	_fill_chip()

func _pin(id: String) -> void:
	_pinned = "" if _pinned == id else id
	_chip_pick = _pinned
	if not _pinned.is_empty():
		_chip_index = -1
		DeepAudio.play("ui_tap", {"volume": 0.6})
	_fill_chip()

func _inspect_pick(id: String) -> void:
	## The close look at a thing standing in the room: a stone on a stall's counter, one of a
	## Warden's three, a die thrown on the floor after a fall.
	var parts: PackedStringArray = id.split(":")
	if parts.size() < 2:
		return
	match parts[0]:
		"item":
			for item in run.get("chamber", {}).get("stock", []):
				if str(item.get("id", "")) == parts[1] and item.has("stone"):
					Inspector.stone(item.stone)
					return
		"hoard":
			for stone in run.get("hoard", {}).get(local_id, {}).get("offers", []):
				if str(stone.get("id", "")) == parts[1]:
					Inspector.stone(stone)
					return

func _press_pick(id: String) -> void:
	var parts: PackedStringArray = id.split(":")
	match parts[0]:
		"":
			if not _pinned.is_empty():
				_pin("")
		"item", "scales", "lens", "hoard":
			_pin(id)
		"hall":
			match parts[1]:
				"rest":
					_respite("rest", "")
				_:
					_pin(id)
		"spot":
			if not bool(me().get("mining", false)) or _strike_pending or str(run.get("phase", "")) != "chamber":
				return
			_strike_pending = true
			for spot in run.chamber.get("vein", {}).get("spots", []):
				_stage.enable_pick("spot:%d" % int(spot.index), false)
			command.emit({"kind": "strike", "spot": int(parts[1])})

func _pick_chip(box: VBoxContainer, id: String) -> bool:
	## What the chip says about a thing in the room. False if there is nothing to say.
	var parts: PackedStringArray = id.split(":")
	match parts[0]:
		"spot":
			var spots: Array = run.get("chamber", {}).get("vein", {}).get("spots", [])
			var index: int = int(parts[1])
			if index < 0 or index >= spots.size():
				return false
			var glint: String = str(spots[index].get("glint", "dull"))
			var words: Array = VEIN_WORDS.get(glint, VEIN_WORDS.dull)
			var tone: Color = {"bright": Color("ffcf5a"), "glint": DeepUi.INFO}.get(glint, DeepUi.MUTED)
			var title_row := DeepUi.hbox(box, 8)
			DeepUi.icon(title_row, "spark" if glint != "dull" else "ore", 20, tone)
			DeepUi.title(title_row, str(words[0]), 18, tone.lightened(0.2))
			DeepUi.label(box, str(words[1]), 13, DeepUi.MUTED)
			var bitten: int = int(spots[index].get("struck", 0))
			if bitten > 0:
				DeepUi.stat(box, "pick", "%s in and the rock still holds" % DeepUi.plural(bitten, "swing"), DeepUi.ACCENT, 12)
			elif glint == "bright":
				DeepUi.stat(box, "pick", "buried deep: three or four swings", DeepUi.MUTED, 12)
			var cost: int = DeepDescent.strike_cost(int(me().get("strikes", 0)), bool(run.get("chamber", {}).get("vein", {}).get("hazard", false)))
			DeepUi.stat(box, "heart", "this swing costs %s" % ("nothing" if cost <= 0 else "%d health" % cost), DeepUi.BAD if cost > 0 else DeepUi.GOOD, 12)
			DeepUi.label(box, "Click to strike.", 12, DeepUi.DIM)
			return true
		"item", "scales", "lens":
			return _stall_chip(box, id, parts)
		"hall":
			return _hall_chip(box, id, parts[1])
		"hoard":
			return _hoard_chip(box, id, parts[1])
	return false

# --- the stall -----------------------------------------------------------------------------------
##
## A merchant's stones are on a counter in the room (never dice: those are only worked, at a
## smithy or a carver). Drag one onto a socket or the bag to buy it (and set it); click one for
## its lines and a Buy button. A stone from the bag dropped on the lens is appraised, on the
## scales sold; click either for a list instead.

func _show_stall() -> void:
	var chamber: Dictionary = run.chamber
	var unit: Dictionary = me()
	var cost: int = DeepDescent.appraise_cost(run, local_id)
	var stock: Array = chamber.get("stock", [])
	var counter: Node3D = _stage.stall(stock, cost)
	if counter != null:
		for item in stock:
			var id: String = "item:%s" % str(item.id)
			if not str(item.get("sold", "")).is_empty():
				if counter.has_item(str(item.id)):
					_stage.stall_sold(str(item.id), _pill_centre("bag"), false)
				_stage.remove_pick(id)
				continue
			if not _stage.has_pick(id) and counter.has_item(str(item.id)):
				var goods: Dictionary = item
				var key: String = str(item.id)
				_stage.add_pick(id, counter.item_node(key), Vector3(0.3, 0.32, 0.3), {
					"hover": func(on: bool) -> void:
						if is_instance_valid(counter):
							counter.set_hover(key, on),
					"drag": func() -> Variant:
						if not DeepDescent.at_stall(run) or int(me().get("ore", 0)) < int(goods.price):
							return null
						return {"kind": "shop_item", "item_id": key, "item_kind": "stone", "price": int(goods.price), "stone": goods.stone},
					"preview": func() -> Control:
						return Thumbs.GemThumb.new(goods.stone, 64)})
		if not _stage.has_pick("scales"):
			_stage.add_pick("scales", counter.scales, Vector3(0.55, 0.55, 0.35), {
				"hover": func(on: bool) -> void:
					if is_instance_valid(counter):
						counter.glow("scales", on)
						## The pans name their price the moment a stone is lifted towards them.
						var held: Dictionary = _dragged_stone() if on else {}
						counter.set_scales_price(DeepStone.sell_value(held) if not held.is_empty() else -1),
				"accepts": func(data: Dictionary) -> bool:
					## Anything you carry, set or loose, read or still in its rock: the buyer
					## pays what a size class is worth for one nobody has read.
					return str(data.get("kind", "")) == "stone",
				"drop": func(data: Dictionary) -> void: _sell(str(data.stone_id))})
		if not _stage.has_pick("lens"):
			_stage.add_pick("lens", counter.lens, Vector3(0.35, 0.55, 0.35), {
				"hover": func(on: bool) -> void:
					if is_instance_valid(counter):
						counter.glow("lens", on),
				"accepts": func(data: Dictionary) -> bool:
					return str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) < 0 and not bool(data.get("appraised", false)) and int(me().get("ore", 0)) >= DeepDescent.appraise_cost(run, local_id),
				"drop": func(data: Dictionary) -> void: _appraise(str(data.stone_id))})
	## The drawer opens as the party walks up to the stall: that is where things are bought to.
	var room_key: String = str(_stage.place.get("key", run.get("depth", "")))
	if _stall_opened != room_key:
		_stall_opened = room_key
		_run_dock.set_drawer(true)
	_crossroads.visible = true
	_cross_title.text = "A merchant"
	_cross_sub.text = "Drag a stone onto your rail or your bag to buy it. Click one for a closer look."
	DeepUi.clear(_cross_hint)
	DeepUi.pill(_cross_hint, "ore", "%d pyrite to spend" % int(unit.get("ore", 0)), DeepUi.ORE, 14)
	var tools := PanelContainer.new()
	tools.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.LINE, 14, 8, 0.4))
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_hint.add_child(tools)
	var row := DeepUi.hbox(tools, 14)
	DeepUi.stat(row, "loupe", "a raw stone on the lens: appraised for %d pyrite" % cost, DeepUi.INFO, 12)
	DeepUi.stat(row, "scales", "any stone on the scales: sold, read or raw", DeepUi.ORE, 12)
	if bool(unit.get("ready", false)):
		var waiting: Array = run.get("players", []).filter(func(p: Dictionary) -> bool: return not bool(p.get("ready", false)) and not bool(p.get("downed", false)) and bool(p.get("connected", true)))
		DeepUi.stat(_cross_hint, "hourglass", "Waiting for " + ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))), DeepUi.MUTED, 13)
	else:
		var done := DeepUi.primary(_cross_hint, "descend", "Done here", func() -> void:
			_pin("")
			command.emit({"kind": "leave"}), 14, DeepUi.CHAMBER_colorS.merchant)
		done.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_chip()

func _buy(item_id: String) -> void:
	DeepAudio.play("ui_confirm", {"volume": 0.6})
	command.emit({"kind": "buy", "item_id": item_id})

func _sell(stone_id: String) -> void:
	command.emit({"kind": "sell", "stone_id": stone_id})

func _dragged_stone() -> Dictionary:
	## The stone in hand right now, if one is being dragged across the room. The scales use it
	## to weigh a thing before it is let go rather than after.
	if _headless or not is_inside_tree():
		return {}
	var port: Viewport = get_viewport()
	if port == null:
		return {}
	var data: Variant = port.gui_get_drag_data()
	if not data is Dictionary or str(data.get("kind", "")) != "stone":
		return {}
	return DeepOddities.find_stone(me(), str(data.get("stone_id", "")))

func _scales_line(box: VBoxContainer, stone: Dictionary, listed: bool) -> void:
	## One stone on the pans: what it is and what the buyer counts out for it. A raw one is
	## sold on its size class alone, which is always the worse end of what it might be worth.
	var appraised: bool = bool(stone.get("appraised", false))
	var paid: int = DeepStone.sell_value(stone)
	var line := DeepUi.hbox(box, 8)
	StoneCard.mini(line, stone, 32)
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
	var said: String = DeepUi.stone_name(stone) if appraised else DeepStone.raw_name(stone)
	DeepUi.label(line, said, 12, tone).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if listed:
		DeepUi.icon_button(line, "ore", "Sell · %d" % paid, _sell.bind(str(stone.id)), 12, DeepUi.ORE)
	else:
		DeepUi.stat(line, "ore", "%d pyrite" % paid, DeepUi.ORE, 15)
		if not appraised:
			DeepUi.label(box, "Still in its rock: the lens first, and it is worth more.", 11, DeepUi.DIM)

func _appraise(stone_id: String) -> void:
	DeepAudio.play("loupe_spin", {"volume": 0.6})
	command.emit({"kind": "appraise", "stone_id": stone_id})

func _stall_chip(box: VBoxContainer, id: String, parts: PackedStringArray) -> bool:
	var unit: Dictionary = me()
	var pinned: bool = _pinned == id
	var ore: int = int(unit.get("ore", 0))
	match parts[0]:
		"item":
			var item: Dictionary = {}
			for candidate in run.get("chamber", {}).get("stock", []):
				if str(candidate.id) == parts[1]:
					item = candidate
			if item.is_empty() or not str(item.get("sold", "")).is_empty():
				return false
			var stone: Dictionary = item.stone
			var grade: Dictionary = DeepStone.grade(stone)
			var tone: Color = DeepUi.tier_color(str(grade.tier))
			var head := DeepUi.hbox(box, 8)
			StoneCard.mini(head, stone, 40)
			var words := DeepUi.vbox(head, 1)
			DeepUi.title(words, str(DeepStone.skill_of(stone).get("name", "")), 18, tone)
			DeepUi.label(words, "%s %s · %d ct · %s" % [DeepContent.cut_name(int(stone.cut)), DeepContent.clarity_name(int(stone.clarity)), int(stone.carat), str(grade.name)], 12, DeepUi.MUTED)
			DeepUi.wrap(box, DeepStone.text(stone), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 300)
			if pinned:
				var button := DeepUi.primary(box, "ore", "Buy for %d" % int(item.price), _buy.bind(str(item.id)), 14, DeepUi.ORE)
				button.disabled = ore < int(item.price) or not DeepDescent.at_stall(run)
				if ore < int(item.price):
					DeepUi.label(box, "You have %d pyrite." % ore, 12, DeepUi.BAD)
			else:
				DeepUi.stat(box, "ore", "%d pyrite  ·  drag it to buy, or click" % int(item.price), DeepUi.ORE if ore >= int(item.price) else DeepUi.DIM, 12)
			return true
		"scales":
			DeepUi.section(box, "scales", "The scales", DeepUi.ORE)
			DeepUi.label(box, "Half what an appraised stone is worth; a raw one fetches what its size class is worth and no more.", 12, DeepUi.MUTED)
			## Something held over the pans is weighed there and then: the buyer's price for
			## that one stone, before it is let go.
			var held: Dictionary = _dragged_stone()
			if not held.is_empty():
				_scales_line(box, held, false)
				DeepUi.label(box, "Let go to sell it.", 12, DeepUi.DIM)
				return true
			var sellable: Array = unit.get("haul", [])
			if not pinned:
				DeepUi.label(box, "Drop one from your bag here, or click for a list.", 12, DeepUi.DIM)
			elif sellable.is_empty():
				DeepUi.label(box, "Nothing in your bag to sell.", 12, DeepUi.DIM)
			## The chip is one panel and never scrolls, so a full bag shows the first of them
			## and says how many are behind; the rest are sold by dropping them on the pans.
			for stone in (sellable.slice(0, SCALES_LISTED) if pinned else []):
				_scales_line(box, stone, true)
			if pinned and sellable.size() > SCALES_LISTED:
				DeepUi.label(box, "%d more in the bag: drop one on the pans to sell it." % (sellable.size() - SCALES_LISTED), 12, DeepUi.DIM)
			return true
		"lens":
			var cost: int = DeepDescent.appraise_cost(run, local_id)
			DeepUi.section(box, "loupe", "The lens", DeepUi.INFO)
			DeepUi.label(box, "%d pyrite for the next stone; dearer each time at this stall." % cost, 12, DeepUi.MUTED)
			var raw: Array = unit.get("haul", []).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			if not pinned:
				DeepUi.label(box, "Drop a raw stone from your bag here, or click for a list.", 12, DeepUi.DIM)
			elif raw.is_empty():
				DeepUi.label(box, "No raw stones in your bag.", 12, DeepUi.DIM)
			for stone in (raw if pinned else []):
				var line := DeepUi.hbox(box, 8)
				StoneCard.mini(line, stone, 32)
				DeepUi.label(line, DeepStone.raw_name(stone), 12, DeepUi.PAPER).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var button := DeepUi.icon_button(line, "loupe", "Appraise · %d" % cost, _appraise.bind(str(stone.id)), 12, DeepUi.INFO)
				button.disabled = ore < cost
			return true
	return false

func _fit_area() -> void:
	## Pages stop short of the dock and its drawer, and so does the chart.
	_area.offset_bottom = - _run_dock.height() if _run_dock.visible else 0.0
	_map_margin.offset_bottom = (- _run_dock.height() - 8.0) if _run_dock.visible else -8.0

# --- the landing ---------------------------------------------------------------------------------
##
## A landing is the lift hall, and it offers four things at once: a campfire to rest by, a
## workbench to read a stone at, a wheel to cut one again on, and the cage. Point at one and
## click it (or drop a stone on the bench or the wheel). The respite is one of the three and
## can only be taken once; the cage and the mouths in the far wall wait on nothing.

func _show_landing() -> void:
	var unit: Dictionary = me()
	var landing: Dictionary = run.get("landing", {})
	var taken: String = str(unit.get("respite", ""))
	var cleared: bool = bool(landing.get("cleared", false)) and int(landing.get("depth", -1)) == int(run.get("depth", 0))
	if _stage.business_key().begins_with("hoard|"):
		## Back to the landing's choices after the hoard: the pedestals are done with.
		_stage.retire_business()
	var lift: Node3D = _stage.hall()
	## Four things to walk up to and one question at a time: while the respite is still to be
	## taken the fire, the bench, the wheel and the cage are all live and the ways down are
	## shut; once it is taken the party walks up to the mouths and chooses one. A Warden's
	## hall keeps its cage, because riding up with a hoard is what the hall is for.
	var can_rest: bool = lift != null and lift.parts.has("rest")
	var waiting: bool = can_rest and taken.is_empty()
	var offered: Array = []
	if lift != null:
		if waiting:
			offered = ["rest", "appraise", "polish", "up"]
		elif cleared or not can_rest:
			offered = ["up"]
		lift.set_taken(taken)
		lift.set_offered(offered)
		for key in ["rest", "appraise", "polish", "up"]:
			if not lift.parts.has(key):
				continue
			var id: String = "hall:" + key
			if not _stage.has_pick(id):
				var part: Node3D = lift.parts[key]
				var which: String = key
				var options: Dictionary = {"hover": func(on: bool) -> void:
					if is_instance_valid(lift):
						lift.set_hover(which if on else "")}
				match key:
					"up":
						options.offset = Vector3(0, 1.5, 0)
						options.half = Vector3(1.3, 1.5, 1.3)
					"rest":
						options.offset = Vector3(0, 0.55, 0)
						options.half = Vector3(0.85, 0.65, 0.85)
					"appraise":
						options.offset = Vector3(0, 1.0, 0)
						options.half = Vector3(1.0, 1.0, 0.6)
						options.accepts = func(data: Dictionary) -> bool:
							return str(me().get("respite", "")).is_empty() and str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) < 0 and not bool(data.get("appraised", false))
						options.drop = func(data: Dictionary) -> void: _respite("appraise", str(data.stone_id))
					"polish":
						options.offset = Vector3(0, 0.9, 0)
						options.half = Vector3(0.7, 0.9, 0.7)
						options.accepts = func(data: Dictionary) -> bool:
							return str(me().get("respite", "")).is_empty() and str(data.get("kind", "")) == "stone" and DeepDescent.can_polish(DeepOddities.find_stone(me(), str(data.get("stone_id", ""))))
						options.drop = func(data: Dictionary) -> void: _respite("polish", str(data.stone_id))
				_stage.add_pick(id, part, options.get("half", Vector3.ONE), options)
			_stage.enable_pick(id, key in offered)
	if waiting or _reading():
		## Nothing moves while a sheet is up. Walking the camera forward behind an appraisal
		## or a close look means the room has changed under the player by the time they put
		## it away, which reads as the game having got on without them.
		_stage.close_ways()
	else:
		## The respite is taken and read: the party walks up to the crossroads.
		_stage.crossroads(crossroads_entries())
	_crossroads.visible = true
	_set_cross_mark("lift", DeepUi.CHAMBER_colorS.get("landing", DeepUi.GOOD))
	_cross_title.text = ("The Warden's hall" if cleared else "The landing") + "  ·  depth %d" % int(run.get("depth", 0))
	if waiting:
		_cross_sub.text = "One respite each: rest by the fire, read a stone at the bench, cut one again at the wheel — or ride the cage up now with what you carry."
	elif cleared:
		_cross_sub.text = "Up the lift with everything you carry, or down one of the mouths for bigger stones."
	else:
		_cross_sub.text = "Your respite is taken. The way on is down: choose a mouth."
	DeepUi.clear(_cross_hint)
	if bool(landing.get("warden_next", false)) and not cleared:
		DeepUi.pill(_cross_hint, "crown", "A Warden guards the way down", DeepUi.BAD, 13)
	if cleared:
		DeepUi.pill(_cross_hint, "check", "The Warden is dead", DeepUi.GOOD, 13)
	var rested: Dictionary = landing.get("respites", {}).get(local_id, {})
	if not rested.is_empty():
		DeepUi.pill(_cross_hint, {"rest": "heart", "appraise": "loupe", "polish": "cut"}.get(str(rested.get("choice", "")), "check"), str(rested.get("message", "")), DeepUi.GOOD, 12)
	for other in run.get("players", []):
		if str(other.id) == local_id:
			continue
		if not str(other.get("choice", "")).is_empty():
			DeepUi.stat(_cross_hint, "lift" if str(other.choice) == "lift" else "descend", str(other.name), DeepUi.GOOD if str(other.choice) == "lift" else DeepUi.ACCENT, 12)
		elif str(other.get("respite", "")).is_empty():
			DeepUi.stat(_cross_hint, "hourglass", "%s is resting" % str(other.name), DeepUi.DIM, 12)
	_fill_chip()

func _respite(choice: String, stone_id: String) -> void:
	if not str(me().get("respite", "")).is_empty():
		return
	var cmd: Dictionary = {"kind": "respite", "choice": choice}
	if not stone_id.is_empty():
		cmd.stone_id = stone_id
	if not _pinned.is_empty():
		_pin("")
	command.emit(cmd)

func _hall_chip(box: VBoxContainer, id: String, key: String) -> bool:
	var unit: Dictionary = me()
	var pinned: bool = _pinned == id
	var taken: bool = not str(unit.get("respite", "")).is_empty()
	match key:
		"rest":
			DeepUi.section(box, "heart", "Rest by the fire", DeepUi.GOOD)
			var gain: int = DeepDescent.rest_amount(unit)
			DeepUi.label(box, "+%d health" % gain if gain > 0 else "You are already whole.", 14, DeepUi.GOOD if gain > 0 else DeepUi.DIM)
			DeepUi.label(box, "Click to sit down." if not taken else "", 12, DeepUi.DIM)
			return true
		"appraise", "polish":
			var appraise: bool = key == "appraise"
			DeepUi.section(box, "loupe" if appraise else "cut", "The workbench" if appraise else "The wheel", DeepUi.INFO if appraise else DeepUi.ACCENT)
			DeepUi.label(box, "Read one raw stone under the lamp. Free." if appraise else "One stone you have read goes back on the wheel: its Cut is drawn again, better or worse.", 12, DeepUi.MUTED)
			var stones: Array = unit.get("haul", []).duplicate()
			if not appraise:
				for stone in unit.get("rail", []):
					if stone is Dictionary:
						stones.append(stone)
			var fit: Array = stones.filter(func(st: Dictionary) -> bool: return (not bool(st.get("appraised", false))) if appraise else DeepDescent.can_polish(st))
			if not pinned:
				DeepUi.label(box, ("No raw stone to read." if appraise else "No stone you have read yet.") if fit.is_empty() else "Drop a stone here, or click for a list.", 12, DeepUi.DIM)
				return true
			for stone in fit:
				var line := DeepUi.hbox(box, 8)
				StoneCard.mini(line, stone, 32)
				DeepUi.label(line, DeepStone.raw_name(stone) if appraise else DeepUi.stone_name(stone), 12, DeepUi.PAPER).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				DeepUi.icon_button(line, "loupe" if appraise else "cut", "Appraise" if appraise else "Cut again", _respite.bind(key, str(stone.id)), 12, DeepUi.INFO if appraise else DeepUi.ACCENT)
			if fit.is_empty():
				DeepUi.label(box, "Nothing here to work on.", 12, DeepUi.DIM)
			return true
		"up":
			var landing: Dictionary = run.get("landing", {})
			var conquered: bool = int(run.get("depth", 0)) >= int(DeepContent.constant("run_depth", 24)) and bool(landing.get("cleared", false))
			DeepUi.section(box, "lift", "Up: return victorious" if conquered else "Up: ride home", DeepUi.GOOD)
			var haul: Array = unit.get("haul", [])
			var worth: int = 0
			for stone in haul:
				worth += DeepStone.value(stone)
			DeepUi.wrap(box, "You carry %s, worth about %d gold if they are what they look like. The lift takes everything home." % [DeepUi.plural(haul.size(), "stone"), worth], 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 300)
			if run.get("players", []).size() > 1:
				DeepUi.label(box, "The party goes where most of it points.", 11, DeepUi.DIM)
			if pinned:
				var ride := DeepUi.primary(box, "lift", "Ride up", func() -> void:
					_pin("")
					DeepAudio.play("lift")
					command.emit({"kind": "choose", "choice": "lift"}), 14, DeepUi.GOOD)
				ride.disabled = str(unit.get("choice", "")) == "lift"
				if not taken:
					DeepUi.label(box, "You have not taken your respite: the fire, the bench and the wheel are all free.", 11, DeepUi.ACCENT)
			else:
				DeepUi.label(box, "Click to take the lift.", 12, DeepUi.DIM)
			return true
	return false

func _end_ready() -> void:
	_end_shown = true
	show_state(run)

# --- the hoard -----------------------------------------------------------------------------------

func _show_hoard() -> void:
	var mine_hoard: Dictionary = run.get("hoard", {}).get(local_id, {})
	var offers: Array = mine_hoard.get("offers", [])
	var chosen: String = str(mine_hoard.get("chosen", ""))
	var pile: Node3D = _stage.hoard(offers, chosen)
	if pile != null:
		for stone in offers:
			var id: String = "hoard:%s" % str(stone.id)
			var key: String = str(stone.id)
			if not _stage.has_pick(id) and pile.spot(key) != null:
				_stage.add_pick(id, pile.spot(key), Vector3(0.45, 0.45, 0.45), {"hover": func(on: bool) -> void:
					if is_instance_valid(pile):
						pile.set_hover(key, on)})
			_stage.enable_pick(id, chosen.is_empty())
	_crossroads.visible = true
	_set_cross_mark("crown", DeepUi.CHAMBER_colorS.get("warden", DeepUi.BAD))
	_cross_title.text = "The Warden's hoard"
	_cross_sub.text = "Take one. They are appraised." if chosen.is_empty() else "Waiting for the others to choose."
	DeepUi.clear(_cross_hint)
	_fill_chip()

func _hoard_chip(box: VBoxContainer, id: String, key: String) -> bool:
	var mine_hoard: Dictionary = run.get("hoard", {}).get(local_id, {})
	for stone in mine_hoard.get("offers", []):
		if str(stone.id) != key:
			continue
		var read: bool = bool(stone.get("appraised", false))
		var grade: Dictionary = DeepStone.grade(stone)
		var tone: Color = DeepUi.tier_color(str(grade.tier)) if read else DeepUi.color(DeepStone.color(stone))
		var head := DeepUi.hbox(box, 8)
		StoneCard.mini(head, stone, 40)
		var words := DeepUi.vbox(head, 1)
		if read:
			DeepUi.title(words, str(DeepStone.skill_of(stone).get("name", "")), 18, tone)
			DeepUi.label(words, "%s %s · %d ct · %s" % [DeepContent.cut_name(int(stone.cut)), DeepContent.clarity_name(int(stone.clarity)), int(stone.carat), str(grade.name)], 12, DeepUi.MUTED)
			DeepUi.wrap(box, DeepStone.text(stone), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 300)
			for inclusion in stone.get("inclusions", []):
				DeepUi.stat(box, "spark", str(DeepContent.inclusion(str(inclusion)).get("name", inclusion)), DeepUi.INFO, 12)
		else:
			## Still in its rock: a colour and a size class, and not one word about what it is.
			DeepUi.title(words, DeepStone.raw_name(stone), 18, tone)
			StoneCard.size_stat(words, stone, 12)
			DeepUi.label(box, "Nobody has read it yet. Its skill, its cut and what is frozen inside it are the loupe's to say.", 12, DeepUi.MUTED)
		if _pinned == id:
			var take := DeepUi.primary(box, "check", "Take it", func() -> void:
				command.emit({"kind": "pick_hoard", "stone_id": key}), 14, tone)
			take.disabled = not str(mine_hoard.get("chosen", "")).is_empty()
		else:
			DeepUi.label(box, "Click to choose it.", 12, DeepUi.DIM)
		return true
	return false

# --- an oddity -----------------------------------------------------------------------------------

func _oddity_tone(kind: String) -> Color:
	## An oddity's violet, or the color of the room whose card it is.
	return DeepUi.CHAMBER_colorS.get(kind, DeepUi.CHAMBER_colorS.oddity)

func _show_oddity() -> void:
	## The room's mark, its name and what it is stand together at the top of the screen; the
	## choices sit along the bottom over the dock, and the room itself is left clear between
	## them so the thing the party has walked up to can be seen.
	var key: String = str(run.chamber.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var tone: Color = _oddity_tone(str(run.chamber.get("kind", "oddity")))
	_stage.shrine(str(ODDITY_GLYPHS.get(key, "question")), tone)
	_crossroads.visible = true
	_set_cross_mark(str(ODDITY_GLYPHS.get(key, "question")), tone)
	_cross_title.text = str(oddity.get("name", "Something odd"))
	_cross_sub.text = str(oddity.get("text", ""))
	DeepUi.clear(_cross_hint)
	_page_oddity(_bottom_page(), false)

func _set_cross_mark(glyph: String, tone: Color) -> void:
	## The medallion over a room's name, or the air where one would be.
	DeepUi.clear(_cross_mark)
	if glyph.is_empty():
		_cross_mark.custom_minimum_size.y = 14.0
		return
	_cross_mark.custom_minimum_size.y = 0.0
	_cross_mark.add_child(Medallion.new(glyph, tone, 84))

func _centre_page() -> VBoxContainer:
	## A page in the middle of whatever room is behind it, clear of the strip and the dock.
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 14.0
	holder.offset_bottom = - (_run_dock.height() if _run_dock.visible else 24.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_holder.add_child(holder)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(centre)
	return DeepUi.vbox(centre, 14)

func _bottom_page() -> VBoxContainer:
	## A page along the bottom of the room, above the dock, leaving the room above it clear.
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("separation", 10)
	_page_holder.add_child(holder)
	var content := DeepUi.vbox(holder, 12)
	content.alignment = BoxContainer.ALIGNMENT_END
	var pad := DeepUi.gap(holder, 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return content

func _side_page() -> VBoxContainer:
	## A page down the right side of the room, as tall as the room.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.9), DeepUi.LINE, 16, 16, 0.5))
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -560
	panel.offset_right = -20
	panel.offset_top = 20
	panel.offset_bottom = -20
	_page_holder.add_child(panel)
	var content := DeepUi.vbox(panel, 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

# --- the crossroads ----------------------------------------------------------------------------

func _build_crossroads() -> void:
	## What the mouths cannot say for themselves: which depth, what the party is choosing, the
	## lantern, and (over the mouth under the cursor) what waits down it and past it.
	_crossroads = Control.new()
	_crossroads.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crossroads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crossroads.visible = false
	_body.add_child(_crossroads)
	var head := DeepUi.vbox(_crossroads, 2)
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## A mark over the name, where a room has one. Where it has none the space it would have
	## taken is kept as air, so the name never sits hard against the top of the screen.
	_cross_mark = DeepUi.center(head)
	_cross_mark.custom_minimum_size.y = 14.0
	_cross_title = DeepUi.title(head, "", 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_cross_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_cross_title.add_theme_constant_override("outline_size", 9)
	_cross_sub = DeepUi.label(head, "", 15, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_cross_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cross_sub.custom_minimum_size.x = 880
	_cross_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_cross_sub.add_theme_constant_override("outline_size", 6)
	DeepUi.gap(head, 6)
	_cross_hint = DeepUi.hbox(head, 10)
	_cross_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_cross_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = PanelContainer.new()
	_chip.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.93), DeepUi.LINE_HI, 14, 12, 0.5))
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.visible = false
	_crossroads.add_child(_chip)

func _show_crossroads() -> void:
	_crossroads.visible = true
	_set_cross_mark("", DeepUi.ACCENT)
	var next_depth: int = int(run.get("depth", 0)) + 1
	_cross_title.text = "Depth %d" % next_depth
	var sub: String = "Choose a way. The party goes where most of it points." if run.get("players", []).size() > 1 else "Choose a way."
	if DeepDescent.is_landing(next_depth):
		sub = "The shaft opens onto a landing."
	_cross_sub.text = sub
	DeepUi.clear(_cross_hint)
	if not run.get("map", {}).is_empty() and not DeepDescent.is_landing(next_depth):
		var lit: bool = bool(run.map.get("lit", false))
		var note := PanelContainer.new()
		note.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.LINE, 14, 8, 0.4))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross_hint.add_child(note)
		var row := DeepUi.hbox(note, 8)
		DeepUi.icon(row, "lantern", 18, DeepUi.ACCENT)
		DeepUi.label(row, "The way is lit to the landing." if lit else "Your lantern shows two depths ahead; past it, only glints. Point at a mouth to see where it leads.", 13, DeepUi.MUTED)
		if not lit:
			var button := DeepUi.icon_button(_cross_hint, "lantern", "Light the way · %d pyrite" % DeepDescent.lantern_cost(), func() -> void: command.emit({"kind": "light"}), 13, DeepUi.ACCENT)
			button.disabled = int(me().get("ore", 0)) < DeepDescent.lantern_cost()
			button.mouse_filter = Control.MOUSE_FILTER_STOP
	var entries: Array = crossroads_entries()
	_stage.crossroads(entries)
	if _chip_index >= entries.size():
		_chip_index = -1
	_fill_chip()

func crossroads_entries() -> Array:
	## One per way on, in the order the mouths stand: what each mouth shows.
	return _entries_for(_mouth_offers())

func _mouth_offers() -> Array:
	## The ways on the mouths stand for: the ones offered, or at a landing the ways down, as
	## the chart has them, before anyone has chosen to go down.
	if str(run.get("phase", "")) != "landing":
		return run.get("offers", [])
	var landing: Dictionary = run.get("landing", {})
	if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
		return [ {"id": "warden", "kind": "warden", "hidden": false}]
	var map: Dictionary = run.get("map", {})
	var out: Array = []
	for id in DeepDescent.row_of(map, int(run.get("depth", 0)) + 1):
		var node: Dictionary = map.get("nodes", {}).get(str(id), {})
		out.append({"id": str(id), "kind": str(node.get("kind", "fight")), "hidden": bool(node.get("hidden", false))})
	return out

func _entries_for(offers: Array) -> Array:
	var out: Array = []
	var nodes: Dictionary = run.get("map", {}).get("nodes", {})
	var landing: bool = str(run.get("phase", "")) == "landing"
	var mine_vote: String = str(me().get("vote", ""))
	for offer in offers:
		var node: Dictionary = nodes.get(str(offer.id), {})
		var seen: bool = DeepDescent.revealed(run, node) if not node.is_empty() else not bool(offer.get("hidden", false))
		var kind: String = str(offer.kind) if seen else "hidden"
		var look: String = "warden" if kind == "landing" and bool(node.get("warden", false)) else kind
		var voters: Array = []
		for other in run.get("players", []):
			var chose: bool = str(other.get("choice", "")) == "descend" if landing else str(other.get("vote", "")) == str(offer.id)
			if chose:
				voters.append(ShaftMap.SEATS[int(other.get("seat", 0)) % ShaftMap.SEATS.size()])
		var color: Color = DeepUi.CHAMBER_colorS.get(look, DeepUi.MUTED)
		out.append({"id": str(offer.id), "kind": kind, "color": color, "light": Color("ffcf8a") if kind == "landing" else color,
			"glyph": str(DeepUi.CHAMBER_GLYPHS.get(look, "arch")) if kind != "hidden" else "question", "hidden": kind == "hidden",
			"voters": voters, "mine": (str(me().get("choice", "")) == "descend") if landing else mine_vote == str(offer.id)})
	return out

func _hover_mouth(index: int) -> void:
	_chip_index = index
	if index >= 0:
		_chip_pick = ""
	var offers: Array = _mouth_offers()
	_map.focus = str(offers[index].id) if index >= 0 and index < offers.size() else ""
	_fill_chip()

func _choose_mouth(index: int) -> void:
	var offers: Array = _mouth_offers()
	if index < 0 or index >= offers.size():
		return
	match str(run.get("phase", "")):
		"tunnels":
			command.emit({"kind": "vote_tunnel", "offer": str(offers[index].id)})
		"landing":
			## Down this way: the party chooses to go down, and this mouth gets the vote. The
			## respite is there to be taken, not to be waited on.
			_descend_via = index
			DeepAudio.play("tunnel", {"volume": 0.6})
			command.emit({"kind": "choose", "choice": "descend"})

func _fill_chip() -> void:
	## Over the mouth under the cursor: what waits down it, what lies past that as far as the
	## lantern shows, and who has chosen it.
	DeepUi.clear(_chip)
	_chip.mouse_filter = Control.MOUSE_FILTER_STOP if not _pinned.is_empty() else Control.MOUSE_FILTER_IGNORE
	if not _chip_pick.is_empty():
		var said: bool = _pick_chip(DeepUi.vbox(_chip, 6), _chip_pick)
		_chip.visible = said
		if said:
			_chip.reset_size()
			_place_chip()
		return
	var offers: Array = _mouth_offers()
	if _chip_index < 0 or _chip_index >= offers.size():
		_chip.visible = false
		return
	var offer: Dictionary = offers[_chip_index]
	var entry: Dictionary = crossroads_entries()[_chip_index]
	var down: bool = str(run.get("phase", "")) == "landing"
	var kind: String = str(entry.kind)
	var tone: Color = entry.color
	var box := DeepUi.vbox(_chip, 6)
	var title_row := DeepUi.hbox(box, 8)
	DeepUi.icon(title_row, str(entry.glyph), 22, tone)
	var called: String = str(KIND_WORDS.get(kind, kind.capitalize())) if str(entry.glyph) != "crown" else ("The Warden's hall" if kind == "warden" else "The landing, and its Warden")
	DeepUi.title(title_row, ("Down: " + called) if down else called, 19, tone.lightened(0.25))
	DeepUi.wrap(box, str(KIND_TEXT.get(kind, "")), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 300)
	var nodes: Dictionary = run.get("map", {}).get("nodes", {})
	var node: Dictionary = nodes.get(str(offer.id), {})
	if str(offer.kind) != "landing" and not node.is_empty():
		var leads := DeepUi.hbox(box, 6)
		DeepUi.label(leads, "then", 12, DeepUi.DIM)
		for child in node.get("next", []):
			var after: Dictionary = nodes.get(str(child), {})
			if after.is_empty():
				continue
			var shows: bool = DeepDescent.revealed(run, after)
			var after_kind: String = str(after.kind) if shows else "hidden"
			var mark: Color = DeepUi.CHAMBER_colorS.get(after_kind, DeepUi.MUTED)
			var glyph: String = str(DeepUi.CHAMBER_GLYPHS.get(after_kind, "arch"))
			if not shows:
				var glint: String = DeepDescent.glint(after)
				glyph = str(ShaftMap.GLINT_GLYPHS.get(glint, "question"))
				mark = Color(ShaftMap.GLINT_TONES.get(glint, DeepUi.DIM), 0.85)
			DeepUi.pill(leads, glyph, "", mark, 12)
	var voters: Array = []
	for other in run.get("players", []):
		if str(other.get("vote", "")) == str(offer.id):
			voters.append(str(other.name))
	if down:
		if kind == "warden":
			DeepUi.stat(box, "crown", "Going down means fighting the Warden first.", DeepUi.BAD, 12)
		DeepUi.label(box, "Click to go down this way." if not str(me().get("respite", "")).is_empty() else "Take a respite first.", 12, DeepUi.DIM)
	elif bool(entry.mine):
		DeepUi.stat(box, "check", "your pick" + ("" if voters.size() <= 1 else "  ·  " + ", ".join(voters)), DeepUi.GOOD, 12)
	elif not voters.is_empty():
		DeepUi.stat(box, "person", ", ".join(voters), DeepUi.ACCENT, 12)
	else:
		DeepUi.label(box, "Click to go this way.", 12, DeepUi.DIM)
	_chip.visible = true
	_chip.reset_size()
	_place_chip()

func _place_chip() -> void:
	## Put down once and left there. What a chip hangs over is rarely still — a stone on a
	## pedestal turns and bobs, a creature breathes — and a tooltip that rode every one of
	## those movements could not be read, let alone kept under the pointer.
	if not _chip.visible or (_chip_index < 0 and _chip_pick.is_empty()):
		return
	var over: String = "%s|%d|%s" % [_chip_pick, _chip_index, str(_chip.size)]
	if over == _chip_over and _chip.position != Vector2.ZERO:
		return
	var mouth: Rect2 = _stage.pick_rect(_chip_pick) if not _chip_pick.is_empty() else _stage.mouth_rect(_chip_index)
	if mouth.size == Vector2.ZERO:
		return
	_chip_over = over
	var at := Vector2(mouth.get_center().x - _chip.size.x * 0.5, mouth.position.y - _chip.size.y - 14.0)
	at.x = clampf(at.x, 12.0, _crossroads.size.x - _chip.size.x - 12.0)
	at.y = clampf(at.y, 150.0, _crossroads.size.y - _chip.size.y - 12.0)
	_chip.position = at

func _process(_delta: float) -> void:
	## A landing held still for a sheet walks on the moment it is put away.
	if str(run.get("phase", "")) == "landing" and _hold.is_empty() and not _walking and _area.visible and not _reading():
		if _stage.has_room() and not _stage.at_crossroads() and not _stage.strolling() and not str(me().get("respite", "")).is_empty():
			_show_landing()
	## The chip rides above its mouth while the camera breathes and leans.
	if _crossroads != null and _crossroads.visible:
		_place_chip()
	## Keep the note of where the ore and bag pills stand fresh, for the frame a spoil is
	## thrown at one of them and the strip has only just been rebuilt.
	if _stage != null and is_instance_valid(_stage):
		_pill_centre("ore")
		_pill_centre("bag")

# --- strip -----------------------------------------------------------------------------------

func _reading() -> bool:
	## A close look or an appraisal is open over the room.
	return Inspector.is_open() or Appraisal.is_open()

func _last_landing_before(depth: int) -> int:
	## The lift the party came down from, or the shaft head.
	var best: int = 0
	for at in run.get("schedule", {}).get("landings", []):
		if int(at) <= depth:
			best = maxi(best, int(at))
	return best

func _sync_strip() -> void:
	DeepUi.clear(_strip)
	var unit: Dictionary = me()
	var mine: Dictionary = DeepContent.mine(str(run.get("mine", "")))
	var place := DeepUi.hbox(_strip, 10)
	DeepUi.icon(place, "pick", 22, DeepUi.ACCENT)
	var names := DeepUi.vbox(place, 0)
	DeepUi.title(names, str(mine.get("name", "The mine")), 17, DeepUi.PAPER)
	var depth: int = int(run.get("depth", 0))
	## How far the next lift is, this run: nobody is told until the chart reaches it.
	var next_landing: int = DeepDescent.next_landing(run, depth)
	var charted: bool = int(run.get("map", {}).get("to", 0)) >= next_landing
	var here: bool = DeepDescent.run_is_landing(run, depth)
	var note: String = "On a landing" if here else ("Landing in %d" % (next_landing - depth) if charted else "A landing somewhere below")
	if charted and not here and DeepDescent.run_is_warden(run, next_landing):
		note = "Warden in %d" % (next_landing - depth)
	DeepUi.label(names, "Depth %d  ·  %s" % [depth, note], 12, DeepUi.MUTED)
	## Progress to the next landing as a row of little steps.
	var steps := DeepUi.hbox(_strip, 3)
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var every: int = maxi(1, next_landing - _last_landing_before(depth))
	var into: int = depth - _last_landing_before(depth)
	for i in range(every):
		var lit: bool = i < into
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 6)
		pip.color = DeepUi.ACCENT if lit else Color(DeepUi.LINE_HI, 0.8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steps.add_child(pip)
	var guarded: bool = charted and DeepDescent.run_is_warden(run, next_landing)
	DeepUi.icon(steps, "crown" if guarded else "lift", 16, DeepUi.BAD if guarded else DeepUi.GOOD)
	DeepUi.spacer(_strip)
	for other in run.get("players", []):
		var mine_too: bool = str(other.id) == local_id
		var box := DeepUi.hbox(_strip, 6)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.tooltip_text = "%s: %d of %d" % [str(other.name), int(other.hp), int(other.max_hp)]
		DeepUi.icon(box, "person", 18, DeepUi.PAPER if mine_too else DeepUi.INFO)
		DeepUi.label(box, str(other.name), 14, DeepUi.PAPER if mine_too else DeepUi.MUTED)
		var bar := DeepUi.bar(box, 12.0)
		bar.custom_minimum_size = Vector2(110, 12)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.set_values(float(other.hp) / float(maxi(1, int(other.max_hp))), "%d" % int(other.hp))
		if bool(other.get("downed", false)):
			DeepUi.icon(box, "skull", 16, DeepUi.BAD, "Down")
		if not bool(other.get("connected", true)):
			DeepUi.label(box, "away", 11, DeepUi.DIM)
	DeepUi.spacer(_strip)
	if not unit.is_empty():
		## Run-long blessings (Sparkle, a Shrine) sit beside what the player carries.
		var blessings := EffectChips.Row.new(15)
		_strip.add_child(blessings)
		blessings.show_effects(EffectChips.for_run(unit))
		var counts: Dictionary = {"ore": int(unit.get("ore", 0)), "haul": unit.get("haul", []).size()}
		## What was just won is counted when it lands here, not when the fight ends.
		for held in _strip_hold:
			counts[held] = _strip_hold[held]
		var chart := DeepUi.icon_button(_strip, "map", "Chart", toggle_chart, 13, DeepUi.ACCENT if _chart_open else DeepUi.MUTED)
		chart.tooltip_text = "The chart of the way down: the trail behind, the stretch to the next landing, and the lantern (M)"
		chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ore := DeepUi.pill(_strip, "ore", str(counts.ore), DeepUi.ORE, 14, "Pyrite: spent at merchants and on the lantern")
		var bag := DeepUi.pill(_strip, "bag", str(counts.haul), DeepUi.PAPER, 14, "Loose stones you carry. Click to look at them.")
		_ore_pill = ore
		_bag_pill = bag
		bag.mouse_filter = Control.MOUSE_FILTER_STOP
		bag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(bag, 1.06)
		bag.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if _run_dock.visible:
					_run_dock.toggle_drawer()
				else:
					open_bench("gems"))
		## What changed since the last look swells and says by how much.
		if not _counts.is_empty():
			for entry in [["ore", DeepUi.ORE], ["haul", DeepUi.ACCENT]]:
				var change: int = int(counts[entry[0]]) - int(_counts.get(entry[0], counts[entry[0]]))
				if change != 0:
					call_deferred("_celebrate", entry[0], ("+%d" % change) if change > 0 else str(change), entry[1] if change > 0 else DeepUi.BAD)
		_counts = counts
	DeepUi.gear_button(_strip, func() -> void: menu_requested.emit())

func toggle_chart() -> void:
	_chart_open = not _chart_open
	DeepAudio.play("ui_open" if _chart_open else "ui_close", {"volume": 0.7})
	_map_margin.visible = _chart_open and _area.visible
	_sync_strip()

func open_bench(which: String = "") -> void:
	if run.is_empty() or str(run.get("phase", "")) == "over":
		return
	_bench.open(run, which)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_B and not run.is_empty():
		## The bag drawer, when the dock is up; the whole bench otherwise.
		if _bench.is_open():
			_bench.close()
		elif _run_dock.visible:
			_run_dock.toggle_drawer()
		else:
			open_bench("")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M and not run.is_empty():
		toggle_chart()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_1, KEY_2, KEY_3] and _crossroads.visible and _stage.at_crossroads():
		## A way on by number, left to right.
		_choose_mouth(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

# --- spoils ----------------------------------------------------------------------------------

func _page_spoils(content: VBoxContainer) -> void:
	## What a chamber gave up, presented: a title, then each thing won lit up one at a time.
	## A fight's spoils fly up out of the room itself; this page is a motherlode's.
	var hold: Dictionary = _hold
	var title: String = str(hold.get("title", "Victory"))
	var glyph: String = str(hold.get("glyph", "sword"))
	var tone: Color = DeepUi.ACCENT
	var subtitle: String = str(hold.get("subtitle", ""))
	var head := DeepUi.vbox(content, 6)
	var medal := Medallion.new(glyph, tone, 130)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	var heading := DeepUi.title(head, title, 46, tone.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	heading.add_theme_constant_override("outline_size", 8)
	DeepUi.label(head, subtitle, 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	if _fresh and not _headless:
		## A spray of every stone color off the medallion.
		var at := func() -> void:
			if is_instance_valid(medal):
				var centre: Vector2 = medal.size * 0.5
				for color in ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]:
					DeepUi.burst(medal, centre, DeepUi.color(color), 22, 380.0, 1.2, 7.0)
		get_tree().create_timer(0.2).timeout.connect(at)
	var rewards: Dictionary = hold.get("rewards", {})
	var card := DeepUi.card(content, Color(tone, 0.5), 18)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 12)
	DeepUi.section(box, "bag", "Spoils", tone)
	_reward_row(box, rewards, 0.45)
	_enter(card, 0.15)
	var next: String = "To the hoard" if str(run.get("phase", "")) == "hoard" else "Onward"
	var go := DeepUi.primary(content, "crown" if next == "To the hoard" else "descend", next, _release, 19, tone)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(260, 52)
	_enter(go, 0.6)

func _page_oddity_result(content: VBoxContainer) -> void:
	if _fresh:
		DeepAudio.play("oddity")
	var key: String = str(_hold.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var result: Dictionary = _hold.get("result", {})
	var tone: Color = _oddity_tone(str(_hold.get("room", "oddity")))
	if _oddity_action(str(result.get("choice", ""))) == "reveal_inclusions":
		var read: Array = me().get("haul", []).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and bool(s.get("inclusions_revealed", false)))
		if not read.is_empty():
			_page_bath(content, read, tone, key, oddity)
			return
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new(str(ODDITY_GLYPHS.get(key, "question")), tone, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, str(oddity.get("name", "Something odd")), 36, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(head, str(result.get("message", "")), 19, tone.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(head)
	var made: Array = result.get("made", []) + result.get("changed", [])
	var dice: Array = result.get("dice", [])
	var lost: Array = result.get("lost", [])
	if not made.is_empty() or not dice.is_empty():
		var card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 16)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var box := DeepUi.vbox(card, 10)
		DeepUi.section(box, "gem" if not made.is_empty() else "die", "What you have now")
		_reward_row(box, {"stones": made, "dice": dice}, 0.3)
		_enter(card, 0.15)
	if not lost.is_empty():
		DeepUi.stat(content, "split_shield", "%s gone for good." % DeepUi.plural(lost.size(), "stone"), DeepUi.BAD, 15).alignment = BoxContainer.ALIGNMENT_CENTER
	var go := DeepUi.primary(content, "descend", "Onward", _release, 18, tone)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 240
	_enter(go, 0.4)

func _reward_row(parent: Node, rewards: Dictionary, start: float) -> HBoxContainer:
	## Each thing won in its own shaft of light, lit one after another.
	var row := DeepUi.hbox(parent, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var delay: float = start if _fresh else -1.0
	var step: float = 0.38
	var ore: int = int(rewards.get("ore", 0))
	var rung: int = 0
	if ore < 0:
		DeepUi.stat(row, "ore", "%d Pyrite after spending" % ore, DeepUi.ORE, 16)
	if ore > 0:
		var slot := RewardSlot.new(DeepUi.ORE, delay)
		slot.voice = "ore"
		slot.rung = rung
		rung += 1
		row.add_child(slot)
		var mark := DeepUi.icon(slot.content, "ore", 60, DeepUi.ORE)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var count := DeepUi.title(slot.content, "+%d" % ore, 26, DeepUi.ORE, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(slot.content, "ore", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		slot.count(count, ore, "+%d")
		delay = delay + step if delay >= 0.0 else delay
	for stone in rewards.get("stones", []):
		var appraised: bool = bool(stone.get("appraised", false))
		var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
		var slot := RewardSlot.new(tone, delay)
		slot.voice = "stone_found"
		slot.rung = rung
		rung += 1
		row.add_child(slot)
		var frame := DeepUi.center(slot.content)
		frame.custom_minimum_size = Vector2(96, 96)
		StoneCard.mini(frame, stone, 84)
		DeepUi.label(slot.content, DeepUi.stone_name(stone) if not appraised else str(DeepStone.skill_of(stone).get("name", "")), 13, tone.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(slot.content, "right-click to look", 10, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		delay = delay + step if delay >= 0.0 else delay
	for die in rewards.get("dice", []):
		var tone: Color = DiceIcons.palette(str(die.get("key", "D6"))).body
		var slot := RewardSlot.new(tone, delay)
		slot.voice = "die_settle"
		slot.rung = rung
		rung += 1
		row.add_child(slot)
		var thumb := Thumbs.DieThumb.new(die, 80)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.content.add_child(thumb)
		DeepUi.label(slot.content, DeepDice.describe(die), 13, tone.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER)
		delay = delay + step if delay >= 0.0 else delay
	if row.get_child_count() == 0:
		DeepUi.stat(row, "cloud", "Nothing but dust this time.", DeepUi.MUTED, 15)
	return row

class RewardSlot extends PanelContainer:
	## One thing won: it waits in the dark, then a beam falls on it, it bursts out of the
	## light, and whatever number it carries counts up.
	var content: VBoxContainer
	var tone: Color
	## What this thing sounds like when the light reaches it, and how far up the ladder it is.
	var voice: String = "stone_found"
	var rung: int = 0
	var _delay: float
	var _clock: float = 0.0
	var _lit: float = 0.0
	var _counter: Label = null
	var _amount: int = 0
	var _format: String = "%d"
	func _init(color: Color, delay: float) -> void:
		tone = color
		_delay = delay
		custom_minimum_size = Vector2(150, 170)
		var style := DeepUi.raised(Color(0.05, 0.06, 0.085, 0.95), Color(tone, 0.55), 14, 12, 0.5)
		style.border_width_bottom = 3
		add_theme_stylebox_override("panel", style)
		mouse_filter = Control.MOUSE_FILTER_PASS
		content = DeepUi.vbox(self, 6)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		if delay >= 0.0 and DisplayServer.get_name() != "headless":
			modulate.a = 0.0
		else:
			_lit = 1.0
	func count(label: Label, amount: int, format: String) -> void:
		_counter = label
		_amount = amount
		_format = format
		if _lit < 1.0:
			label.text = format % 0
	func _process(delta: float) -> void:
		_clock += delta
		if _lit < 1.0 and _clock >= _delay:
			_lit = 1.0
			modulate.a = 1.0
			DeepAudio.from(self, voice, {"pitch": 1.0 + 0.07 * float(rung), "gap": 0.0})
			DeepUi.pulse(self, 1.2, 0.45)
			DeepUi.burst(self, size * 0.5, tone.lightened(0.3), 36, 260.0, 0.9, 6.0)
			if _counter != null:
				var shown: Label = _counter
				var tween := create_tween()
				tween.tween_method(func(v: float) -> void: shown.text = _format % int(round(v)), 0.0, float(_amount), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func _draw() -> void:
		if _lit < 1.0:
			return
		var glow: Texture2D = DeepUi.glow_texture()
		var pulse: float = 0.8 + 0.2 * sin(_clock * 2.2)
		var beam := PackedVector2Array([Vector2(size.x * 0.35, 0), Vector2(size.x * 0.65, 0), Vector2(size.x * 0.9, size.y), Vector2(size.x * 0.1, size.y)])
		draw_colored_polygon(beam, Color(tone, 0.09 * pulse))
		var pool := Vector2(size.x * 1.1, size.y * 0.5)
		draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, size.y * 0.45) - pool * 0.5, pool), false, Color(tone, 0.22 * pulse))

# --- vein ------------------------------------------------------------------------------------

# --- the grubstake ---------------------------------------------------------------------------
##
## The stakes are shown as what they are, with nothing to set: a stake on a stone lands on
## one drawn at random from the rail, and a pick keeps its three candidates face down until
## it is taken. Taking one turns the page to the three, large, and one of them is kept.

const STAKE_WORDS: Dictionary = {"stone": "A stone stake", "kit": "A kit stake", "terms": "Terms", "long_shot": "A long shot"}
const STAKE_GLYPHS: Dictionary = {"stone": "gem", "kit": "bag", "terms": "scales", "long_shot": "die"}

func _stake_tone(kind: String) -> Color:
	match kind:
		"stone": return DeepUi.ACCENT
		"kit": return DeepUi.INFO
		"terms": return Color("c58bff")
	return DeepUi.ORE

func _page_grubstake(content: VBoxContainer) -> void:
	## The shaft head: the workshop's stakes, one to be taken before the lift goes down.
	var unit: Dictionary = me()
	var stake: String = str(unit.get("stake", ""))
	var offers: Array = run.get("grubstake", {}).get("offers", {}).get(local_id, [])
	var choosing: Dictionary = {}
	for offer in offers:
		if stake.is_empty() and str(offer.get("id", "")) == _stake_choosing:
			choosing = offer
	if choosing.is_empty():
		_stake_choosing = ""
	if _fresh and stake.is_empty() and choosing.is_empty():
		## The host has usually just heard this from the Descend button.
		DeepAudio.play("depart", {"volume": 0.8, "gap": 2.5})
	if not choosing.is_empty():
		_page_stake_pick(content, choosing)
		return
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("bag", DeepUi.ACCENT)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, "The Grubstake", 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(head, "Before the lift goes down, the workshop stakes you. Take one. Whatever it changes is for this dig only.", 16, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(head)
	if not stake.is_empty():
		var result_card := _stake_result(content, run.get("grubstake", {}).get("chosen", {}).get(local_id, {}))
		_enter(result_card, 0.1)
		var waiting: Array = run.players.filter(func(p: Dictionary) -> bool: return str(p.get("stake", "")).is_empty() and bool(p.get("connected", true)))
		if not waiting.is_empty():
			DeepUi.stat(content, "hourglass", "Waiting for " + ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))), DeepUi.MUTED, 14).alignment = BoxContainer.ALIGNMENT_CENTER
		return
	var rail_empty: bool = not unit.get("rail", []).any(func(s: Variant) -> bool: return s is Dictionary)
	var row := DeepUi.hbox(content, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var index: int = 0
	for offer in offers:
		var kind: String = str(offer.get("kind", "kit"))
		var tone: Color = _stake_tone(kind)
		var card := DeepUi.card(row, Color(tone, 0.45), 16)
		card.custom_minimum_size = Vector2(270, 0)
		var box := DeepUi.vbox(card, 8)
		var tag := DeepUi.hbox(box, 6)
		DeepUi.icon(tag, str(STAKE_GLYPHS.get(kind, "bag")), 18, tone)
		DeepUi.label(tag, str(STAKE_WORDS.get(kind, "A stake")), 12, tone)
		var on_stones: int = 0
		for key in offer.get("boons", []):
			var def: Dictionary = DeepContent.boon(str(key))
			var is_cost: bool = str(def.get("group", "")) == "cost"
			if str(def.get("needs", "")) == "socket":
				on_stones += 1
			var title_row := DeepUi.hbox(box, 6)
			if kind == "terms":
				DeepUi.icon(title_row, "cross_out" if is_cost else "check", 16, DeepUi.BAD if is_cost else DeepUi.GOOD)
			DeepUi.title(title_row, str(def.get("name", key)), 18, DeepUi.BAD.lightened(0.2) if is_cost else DeepUi.PAPER)
			DeepUi.wrap(box, str(def.get("text", "")), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 236)
		if on_stones > 1:
			DeepUi.stat(box, "gem", "Both fall on the same stone.", DeepUi.MUTED, 12)
		var picks: bool = offer.get("needs", []).has("pick")
		if picks:
			DeepUi.stat(box, "eye", "The three are shown once you take it.", DeepUi.MUTED, 12)
		DeepUi.spacer(box, false)
		var offer_id: String = str(offer.get("id", ""))
		var button := DeepUi.primary(box, "check", "Take it", func() -> void:
			if picks:
				_stake_choosing = offer_id
				show_state(run)
			else:
				command.emit({"kind": "stake", "offer": offer_id, "payload": {}}), 16, tone)
		if on_stones > 0 and rail_empty:
			button.disabled = true
			DeepUi.stat(box, "cross_out", "Your rail is empty.", DeepUi.DIM, 12)
		_enter(card, 0.1 + 0.08 * index)
		index += 1

func _page_stake_pick(content: VBoxContainer, offer: Dictionary) -> void:
	## A pick stake, taken: its three candidates at full size, and one of them to keep.
	var tone: Color = _stake_tone(str(offer.get("kind", "stone")))
	var named: Dictionary = {}
	var costs: Array = []
	for key in offer.get("boons", []):
		var def: Dictionary = DeepContent.boon(str(key))
		if str(def.get("needs", "")) == "pick":
			named = def
		elif str(def.get("group", "")) == "cost":
			costs.append(def)
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("gem", tone)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, str(named.get("name", "Your pick")), 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(head, "Three stones, appraised. One goes into your haul.", 16, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for def in costs:
		var price := DeepUi.stat(head, "cross_out", "%s: %s" % [str(def.get("name", "")), str(def.get("text", ""))], DeepUi.BAD.lightened(0.2), 14)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
	_enter(head)
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var offer_id: String = str(offer.get("id", ""))
	var picks: Array = offer.get("picks", [])
	for index in range(picks.size()):
		var candidate: Dictionary = picks[index]
		var column := DeepUi.vbox(row, 12)
		column.custom_minimum_size.x = 300
		var card: Control = StoneCard.build(column, candidate, {"size": 156, "vertical": true, "text_width": 268})
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var chosen: int = index
		DeepUi.primary(column, "check", "Take this one", func() -> void:
			command.emit({"kind": "stake", "offer": offer_id, "payload": {"pick": chosen}}), 16, tone)
		_enter(column, 0.15 + 0.12 * index)

func _stake_result(content: VBoxContainer, result: Dictionary) -> PanelContainer:
	## What a taken stake did: its words, and every stone or die it made or changed.
	var result_card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 18)
	result_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(result_card, 10)
	var names: Array = result.get("boons", []).map(func(k: Variant) -> String: return str(DeepContent.boon(str(k)).get("name", k)))
	DeepUi.section(box, "check", " and ".join(names) if not names.is_empty() else "Staked", DeepUi.ACCENT)
	DeepUi.wrap(box, str(result.get("message", "You have taken your stake.")), 16, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 700)
	## One stone across the card; more (a geode's three) two abreast, so the page stays whole.
	var stones: Array = result.get("changed", []) + result.get("made", [])
	var grid := GridContainer.new()
	grid.columns = 1 if stones.size() <= 1 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for stone in stones:
		StoneCard.build(grid, stone, {"size": 72 if stones.size() <= 1 else 60, "text_width": 520 if stones.size() <= 1 else 300})
	if not result.get("dice", []).is_empty():
		var dice_row := DeepUi.hbox(box, 8)
		for die in result.dice:
			dice_row.add_child(Thumbs.DieThumb.new(die, 48))
			DeepUi.label(dice_row, DeepDice.describe(die), 14, DeepUi.PAPER)
	return result_card

func _page_stake_result(content: VBoxContainer) -> void:
	## Held once the last stake is in, when this one did something by chance: the stone the
	## rail gave up to it, or how a long shot fell. The tunnels wait behind it.
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("bag", DeepUi.ACCENT, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, "The Grubstake", 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	_enter(_stake_result(content, _hold.get("result", {})), 0.1)
	var go := DeepUi.primary(content, "descend", "Onward", _release, 18, DeepUi.ACCENT)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 240
	_enter(go, 0.3)

# --- oddity ----------------------------------------------------------------------------------

func _page_oddity(content: VBoxContainer, headed: bool = true) -> void:
	if _fresh:
		DeepAudio.play("oddity", {"volume": 0.8})
	var unit: Dictionary = me()
	var key: String = str(run.chamber.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var tone: Color = _oddity_tone(str(run.chamber.get("kind", "oddity")))
	if headed:
		var head := DeepUi.vbox(content, 8)
		var medal := Medallion.new(str(ODDITY_GLYPHS.get(key, "question")), tone)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		head.add_child(medal)
		DeepUi.title(head, str(oddity.get("name", "Something odd")), 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.wrap(head, str(oddity.get("text", "")), 16, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_enter(head)
	var chosen: String = str(unit.get("oddity_choice", ""))
	if not chosen.is_empty():
		var mine_result: Dictionary = run.chamber.get("results", {}).get(local_id, {})
		var result_card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 18)
		result_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var box := DeepUi.vbox(result_card, 10)
		DeepUi.section(box, "check", "What came of it", DeepUi.ACCENT)
		DeepUi.wrap(box, str(mine_result.get("message", "You have chosen.")), 16, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 700)
		for stone in mine_result.get("made", []) + mine_result.get("changed", []):
			StoneCard.build(box, stone, {"size": 72, "text_width": 520})
		for die in mine_result.get("dice", []):
			var die_row := DeepUi.hbox(box, 10)
			die_row.add_child(Thumbs.DieThumb.new(die, 56))
			DeepUi.label(die_row, DeepDice.describe(die), 15, DeepUi.PAPER)
			_faces_row(die_row, die, 16)
		_enter(result_card, 0.1)
		var waiting: Array = run.players.filter(func(p: Dictionary) -> bool: return str(p.get("oddity_choice", "")).is_empty() and not bool(p.get("downed", false)))
		if not waiting.is_empty():
			DeepUi.stat(content, "hourglass", "Waiting for " + ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))), DeepUi.MUTED, 14).alignment = BoxContainer.ALIGNMENT_CENTER
		return
	var choices: Array = oddity.get("choices", [])
	## Walking on is not a third piece of work: it is a way out, and it goes under the others
	## on a line of its own rather than standing beside them as an empty column.
	var leaving: Dictionary = {}
	var work: Array = []
	for choice in choices:
		if str(choice.get("needs", "")).is_empty() and str(choice.get("action", {}).get("kind", "none")) == "none" and choices.size() > 1:
			leaving = choice
		else:
			work.append(choice)
	## A choice already picked out: the second page, where the thing to work on is chosen.
	var step: Dictionary = {}
	for choice in work:
		if str(choice.id) == _oddity_step:
			step = choice
	if not step.is_empty():
		_page_oddity_work(content, step, unit, tone, key)
		return
	if not leaving.is_empty():
		var out := DeepUi.icon_button(content, "cross_out", str(leaving.get("label", "Leave it")), func() -> void:
			command.emit({"kind": "oddity", "choice": str(leaving.id), "payload": {}}), 15, DeepUi.MUTED)
		out.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_enter(out)
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var index: int = 0
	for choice in work:
		var card := DeepUi.card(row, Color(tone, 0.4), 16)
		card.custom_minimum_size = Vector2(300, 0)
		var box := DeepUi.vbox(card, 10)
		var title_row := DeepUi.hbox(box, 8)
		DeepUi.icon(title_row, str(ODDITY_GLYPHS.get(key, "question")), 20, tone)
		DeepUi.title(title_row, str(choice.get("label", choice.id)), 19, DeepUi.PAPER)
		if choice.has("text"):
			DeepUi.wrap(box, str(choice.text), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 260)
		DeepUi.spacer(box, false)
		var needs: String = str(choice.get("needs", ""))
		var id: String = str(choice.id)
		var nothing: bool = needs != "" and _picker_empty(needs, unit)
		var button: Button = DeepUi.primary(box, "check", "Choose", func() -> void:
			if needs.is_empty():
				command.emit({"kind": "oddity", "choice": id, "payload": {}})
				return
			_oddity_step = id
			show_state(run), 16, tone)
		if nothing:
			button.disabled = true
			DeepUi.stat(box, "cross_out", "You have nothing this could be done to.", DeepUi.DIM, 12)
		_enter(card, 0.12 + 0.08 * index)
		index += 1

func _page_oddity_work(content: VBoxContainer, choice: Dictionary, unit: Dictionary, tone: Color, key: String) -> void:
	## The second page of a room's card: one piece of work picked out, the thing it is to be
	## done to set in a socket beside it, and nothing else on the screen to read.
	var card := DeepUi.card(content, Color(tone, 0.55), 18)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 12)
	var title_row := DeepUi.hbox(box, 10)
	DeepUi.icon(title_row, str(ODDITY_GLYPHS.get(key, "question")), 24, tone)
	DeepUi.title(title_row, str(choice.get("label", choice.id)), 24, DeepUi.PAPER)
	if choice.has("text"):
		DeepUi.wrap(box, str(choice.text), 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 560)
	DeepUi.rule(box, Color(tone, 0.4))
	var needs: String = str(choice.get("needs", ""))
	var payload_of: Callable = _picker(box, needs, unit, str(choice.id), choice.get("action", {}))
	var buttons := DeepUi.hbox(box, 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var id: String = str(choice.id)
	DeepUi.icon_button(buttons, "prev", "Never mind", func() -> void:
		_oddity_step = ""
		show_state(run), 15, DeepUi.MUTED)
	## "Do it" only exists once there is something to do it to.
	if not payload_of.call().is_empty():
		var go := DeepUi.primary(buttons, "check", "Do it", func() -> void:
			var payload: Dictionary = payload_of.call()
			if payload.is_empty():
				return
			_oddity_step = ""
			command.emit({"kind": "oddity", "choice": id, "payload": payload}), 17, tone)
		go.custom_minimum_size.x = 200
	_enter(card, 0.05)

func _picker_empty(needs: String, unit: Dictionary) -> bool:
	## Whether there is nothing this piece of work could be done to at all.
	match needs:
		"die", "die_face", "die_face_pair", "die_engraving":
			return unit.get("dice", []).is_empty()
		"raw_stone":
			return unit.get("haul", []).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false))).is_empty()
		"ore":
			return int(unit.get("ore", 0)) < 10
		"inclusion", "copy_inclusion":
			return _carried(unit).filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false)))).is_empty()
		"two_stones":
			return _carried(unit).size() < 2
		"stone":
			return _carried(unit).is_empty()
	return false

func _carried(unit: Dictionary) -> Array:
	## Every stone the player has to hand: the bag and the rail alike.
	var out: Array = unit.get("haul", []).duplicate()
	for stone in unit.get("rail", []):
		if stone is Dictionary:
			out.append(stone)
	return out

class Medallion extends Control:
	## A big mark in a ring of light that turns slowly: the face of an oddity or an ending.
	var glyph: String
	var tone: Color
	var _clock: float = 0.0
	func _init(mark: String, color: Color, edge: float = 120.0) -> void:
		glyph = mark
		tone = color
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.42
		var glow: Texture2D = DeepUi.glow_texture()
		var pulse: float = 1.0 + 0.06 * sin(_clock * 2.0)
		var halo := Vector2(radius, radius) * 4.2 * pulse
		draw_texture_rect(glow, Rect2(centre - halo * 0.5, halo), false, Color(tone, 0.35))
		draw_circle(centre, radius, Color(tone.darkened(0.75), 0.95))
		draw_arc(centre, radius, 0, TAU, 64, Color(tone, 0.9), 2.5, true)
		for i in range(12):
			var angle: float = _clock * 0.25 + TAU * float(i) / 12.0
			var inner: Vector2 = centre + Vector2.from_angle(angle) * radius * 1.12
			var outer: Vector2 = centre + Vector2.from_angle(angle) * radius * (1.2 + 0.06 * float(i % 2))
			draw_line(inner, outer, Color(tone, 0.6), 2.0, true)
		var edge: float = radius * 1.15
		var bob: float = sin(_clock * 1.6) * 3.0
		draw_texture_rect(GemIcons.texture(glyph, 128), Rect2(centre - Vector2(edge, edge) * 0.5 + Vector2(0, bob), Vector2(edge, edge)), false, tone.lightened(0.35))

## Nothing in the mine is worked on through a list of names. A choice that wants one of your
## stones or one of your dice gives the dock over to those things themselves, drawn large
## where it stood, and the one to work on is clicked. A face, an inclusion, an engraving, a
## pattern or a measure of ore is a row of marks, clicked the same way. What each slot is set
## to is remembered by room and choice, so a page rebuilt under the pointer keeps it.

func _slot_key(choice_id: String, slot: String) -> String:
	return "%s|%s|%s" % [str(run.get("chamber", {}).get("oddity", "")), choice_id, slot]

func _remembered(key: String, options: Array, prefer_last: bool = false) -> String:
	## What this slot holds: what was chosen if it is still on offer, else one end of the row.
	var ids: Array = options.map(func(o: Variant) -> String: return str(o.id) if o is Dictionary else str(o))
	var held: String = str(_choice_picks.get(key, ""))
	if ids.has(held):
		return held
	if ids.is_empty():
		return ""
	return str(ids[ids.size() - 1]) if prefer_last else str(ids[0])

func _offer_pick(key: String, kind: String, items: Array, prompt: String) -> void:
	if items.is_empty() or _run_dock == null:
		return
	_choice_slot = key
	_run_dock.offer(kind, items, prompt)

func _on_dock_chose(id: String) -> void:
	if _choice_slot.is_empty():
		return
	_choice_picks[_choice_slot] = id
	_choice_slot = ""
	show_state(run)

func _mark(control: Control, chosen: bool, tone: Color) -> void:
	## A thing in a row of things to click: lit when it is the one.
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if control is PanelContainer:
		(control as PanelContainer).add_theme_stylebox_override("panel", DeepUi.raised(Color(tone, 0.22) if chosen else Color(DeepUi.SLATE, 0.85),
			Color(tone, 0.95) if chosen else Color(DeepUi.LINE, 0.8), 10, 6, 0.3))
	DeepUi.juice(control, 1.06)

func _chip_row(parent: Node, key: String, entries: Array, tone: Color, builder: Callable, prefer_last: bool = false) -> String:
	## One row of things to click, one of them lit. `entries` are [id, payload] pairs; the
	## builder fills a panel for each. Returns the id that is chosen.
	var picked: String = _remembered(key, entries.map(func(e: Array) -> String: return str(e[0])), prefer_last)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	for entry in entries:
		var id: String = str(entry[0])
		var panel := PanelContainer.new()
		row.add_child(panel)
		_mark(panel, id == picked, tone)
		builder.call(panel, entry)
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_toggle", {"volume": 0.7})
				_choice_picks[key] = id
				show_state(run)
				panel.accept_event())
	return picked

func _work_refusal(action: Dictionary, item: Dictionary) -> String:
	## Why this die or this stone cannot take this piece of work, or "". A d4 cannot be filed
	## any smaller and a stone nobody has read has no cut to draw again: neither should be
	## offered and then refused.
	match str(action.get("kind", "")):
		"upsize":
			return DeepOddities.resize_refusal(item, 1)
		"downsize":
			return DeepOddities.resize_refusal(item, -1)
		"raise_face":
			var head: int = 0
			for f in item.get("faces", []):
				head = maxi(head, int(f.get("value", 0)))
			var ceiling: int = int(item.get("top", 0)) if int(item.get("top", 0)) > 0 else head
			for f in item.get("faces", []):
				if int(f.get("value", 0)) < ceiling:
					return ""
			return "every face is already as high as it goes"
		"copy_face":
			var seen: Dictionary = {}
			for f in item.get("faces", []):
				seen[int(f.get("value", 0))] = true
			return "" if seen.size() > 1 else "every face already shows the same number"
		"reroll_cut", "reroll_clarity", "wishing_well", "collector_sell", "trade_up", "tumble", "fuse":
			if not bool(item.get("appraised", false)):
				return "nobody has read it yet"
			return "a Knot cannot leave its socket" if DeepStone.is_locked(item) else ""
		"remove_inclusion", "copy_inclusion":
			return "" if not item.get("inclusions", []).is_empty() else "nothing is frozen inside it"
		"appraise":
			return "" if not bool(item.get("appraised", false)) else "it has already been read"
	return ""

func _thing_row(parent: Node, choice_id: String, slot: String, kind: String, items: Array, label: String, action: Dictionary) -> String:
	## Everything the work could be done to, laid out at once and left there: the one picked
	## is lit, the ones it cannot be done to are greyed and will not answer. Nothing pops
	## open and nothing closes, so the choice can be changed as often as it likes.
	var key: String = _slot_key(choice_id, slot)
	var open: Array = items.filter(func(item: Dictionary) -> bool: return _work_refusal(action, item).is_empty())
	var picked: String = _remembered(key, open)
	if not label.is_empty():
		DeepUi.label(parent, label, 12, DeepUi.MUTED)
	if items.is_empty():
		DeepUi.stat(parent, "cross_out", "You carry nothing this could be done to.", DeepUi.DIM, 12)
		return ""
	## One line of them at a time. A heavy haul would otherwise run off the bottom of the
	## screen, and nothing in this game scrolls.
	var page_key: String = key + "#page"
	var pages: int = maxi(1, int(ceil(float(items.size()) / float(WORK_PAGE))))
	var page: int = clampi(int(_choice_picks.get(page_key, 0)), 0, pages - 1)
	for at in range(items.size()):
		if str(items[at].get("id", "")) == picked:
			page = at / WORK_PAGE
	_choice_picks[page_key] = page
	var line := DeepUi.hbox(parent, 6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	if pages > 1:
		var back := DeepUi.icon_button(line, "prev", "", func() -> void:
			_choice_picks[page_key] = posmod(page - 1, pages)
			show_state(run), 14, DeepUi.MUTED)
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := DeepUi.hbox(line, 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for item in items.slice(page * WORK_PAGE, mini((page + 1) * WORK_PAGE, items.size())):
		var id: String = str(item.get("id", ""))
		var refusal: String = _work_refusal(action, item)
		var chosen: bool = id == picked and refusal.is_empty()
		var card := PanelContainer.new()
		row.add_child(card)
		_mark(card, chosen, DeepUi.ACCENT)
		var named: String = DeepDice.describe(item) if kind == "die" else DeepUi.stone_name(item)
		card.tooltip_text = named if refusal.is_empty() else "%s — %s" % [named, refusal]
		if not refusal.is_empty():
			card.modulate = Color(0.55, 0.55, 0.6, 0.55)
			card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		var box := DeepUi.vbox(card, 3)
		var frame := DeepUi.center(box)
		frame.custom_minimum_size = Vector2(62, 62)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture: Control = Thumbs.DieThumb.new(item, 56) if kind == "die" else Thumbs.GemThumb.new(item, 56)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(picture)
		var caption := DeepUi.label(box, named, 11, DeepUi.PAPER if refusal.is_empty() else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		caption.custom_minimum_size.x = 104
		caption.clip_text = true
		if refusal.is_empty():
			card.gui_input.connect(func(event: InputEvent) -> void:
				if not (event is InputEventMouseButton and event.pressed):
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					if kind == "die":
						Inspector.die(item)
					else:
						Inspector.stone(item)
					card.accept_event()
				elif event.button_index == MOUSE_BUTTON_LEFT:
					DeepAudio.play("ui_toggle", {"volume": 0.7})
					_choice_picks[key] = id
					show_state(run)
					card.accept_event())
			## A die or a stone dragged off the dock lands here as well.
			var wanted: String = "die_id" if kind == "die" else "stone_id"
			card.set_drag_forwarding(Callable(), func(_at: Vector2, data: Variant) -> bool:
				return data is Dictionary and str(data.get("kind", "")) == kind and str(data.get(wanted, "")) == id,
				func(_at: Vector2, _data: Variant) -> void:
					DeepAudio.play("ui_confirm", {"volume": 0.7})
					_choice_picks[key] = id
					show_state(run))
	if pages > 1:
		var on := DeepUi.icon_button(line, "next", "", func() -> void:
			_choice_picks[page_key] = posmod(page + 1, pages)
			show_state(run), 14, DeepUi.MUTED)
		on.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		DeepUi.label(parent, "%d of %d" % [page + 1, pages], 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return picked

func _face_slot(parent: Node, choice_id: String, slot: String, die: Dictionary, label: String, blanks: bool, prefer_last: bool = false) -> int:
	## One of a die's faces, chosen by clicking the face itself rather than reading its number
	## off a list — the same row of faces the close look draws.
	var faces: Array = die.get("faces", [])
	var entries: Array = []
	for index in range(faces.size()):
		if blanks or str(faces[index].get("kind", "plain")) != "blank":
			entries.append([str(index), faces[index]])
	if entries.is_empty():
		return -1
	if not label.is_empty():
		DeepUi.label(parent, label, 12, DeepUi.MUTED)
	var tone: Color = DiceIcons.palette(str(die.get("key", "D6"))).body
	var picked: String = _chip_row(parent, _slot_key(choice_id, slot), entries, tone, func(panel: PanelContainer, entry: Array) -> void:
		var face: Dictionary = entry[1]
		var holder := DeepUi.center(panel)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var drawn: Control = DiceIcons.face(34.0, int(face.get("value", 0)), tone, str(die.get("shape", "D6")), false,
			DiceIcons.face_text(int(face.get("value", 0)), str(face.get("kind", "plain"))))
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(drawn), prefer_last)
	return int(picked)

func _picker(box: VBoxContainer, needs: String, unit: Dictionary, choice_id: String, action: Dictionary = {}) -> Callable:
	## The controls a choice needs, and a callable that reads them into a payload.
	if needs.is_empty():
		return func() -> Dictionary: return {}
	var stones: Array = unit.get("haul", []).duplicate()
	for stone in unit.get("rail", []):
		if stone is Dictionary:
			stones.append(stone)
	var dice: Array = unit.get("dice", [])
	var row := DeepUi.vbox(box, 6)
	match needs:
		"stone":
			var id: String = _thing_row(row, choice_id, "stone", "stone", stones, "Which stone?", action)
			return func() -> Dictionary: return {} if id.is_empty() else {"stone_id": id}
		"raw_stone":
			## Only what the work is for: a lens is shown rough stones and nothing else.
			var raw: Array = unit.get("haul", []).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			var id: String = _thing_row(row, choice_id, "stone", "stone", raw, "Which raw stone?", action)
			return func() -> Dictionary: return {} if id.is_empty() else {"stone_id": id}
		"two_stones":
			var keep_id: String = _thing_row(row, choice_id, "keep", "stone", stones, "Which stone survives?", action)
			var feed_id: String = _thing_row(row, choice_id, "feed", "stone", stones.filter(func(s: Dictionary) -> bool: return str(s.get("id", "")) != keep_id), "Which stone goes in?", action)
			return func() -> Dictionary: return {} if keep_id.is_empty() or feed_id.is_empty() or keep_id == feed_id else {"keep_id": keep_id, "feed_id": feed_id}
		"inclusion", "copy_inclusion":
			var carriers: Array = stones.filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false))))
			var from_id: String = _thing_row(row, choice_id, "from", "stone", carriers, "Which stone?", action)
			var carrier: Dictionary = DeepOddities.find_stone(unit, from_id)
			var keys: Array = carrier.get("inclusions", []).map(func(k: Variant) -> Array: return [str(k), str(k)])
			var which: String = ""
			if not keys.is_empty():
				which = _chip_row(row, _slot_key(choice_id, "inclusion"), keys, DeepUi.INFO, func(panel: PanelContainer, entry: Array) -> void:
					var inclusion: Dictionary = DeepContent.inclusion(str(entry[0]))
					panel.tooltip_text = str(inclusion.get("text", ""))
					DeepUi.stat(panel, "spark", str(inclusion.get("name", entry[0])), DeepUi.INFO, 12))
			if needs == "inclusion":
				return func() -> Dictionary: return {} if from_id.is_empty() or which.is_empty() else {"stone_id": from_id, "inclusion": which}
			var to_id: String = _thing_row(row, choice_id, "to", "stone", stones, "Onto which stone?", {})
			return func() -> Dictionary: return {} if from_id.is_empty() or which.is_empty() or to_id.is_empty() else {"from_id": from_id, "inclusion": which, "to_id": to_id}
		"die", "die_face", "die_face_pair", "die_engraving":
			var die_id: String = _thing_row(row, choice_id, "die", "die", dice, "Which die?", action)
			var die: Dictionary = DeepOddities.find_die(unit, die_id)
			if needs == "die":
				return func() -> Dictionary: return {} if die_id.is_empty() else {"die_id": die_id}
			if needs in ["die_face", "die_face_pair"]:
				var pair: bool = needs == "die_face_pair"
				var face: int = _face_slot(row, choice_id, "face", die, "Recut" if pair else "Which face?", true)
				if not pair:
					return func() -> Dictionary: return {} if die_id.is_empty() or face < 0 else {"die_id": die_id, "face": face}
				var from: int = _face_slot(row, choice_id, "from", die, "to show the number on", false, true)
				return func() -> Dictionary: return {} if die_id.is_empty() or face < 0 or from < 0 else {"die_id": die_id, "face": face, "from": from}
			var marks: Array = DeepDice.ENGRAVINGS.map(func(e: String) -> Array: return [e, e])
			var engraving: String = _chip_row(row, _slot_key(choice_id, "engraving"), marks, DeepUi.ACCENT, func(panel: PanelContainer, entry: Array) -> void:
				## Named and explained on the chip itself: nobody should have to guess what
				## Keen or Steady does to a die, and the mark beside it is not a Cut.
				var def: Dictionary = DeepContent.engraving(str(entry[0]))
				panel.tooltip_text = str(def.get("text", ""))
				var line := DeepUi.vbox(panel, 1)
				DeepUi.stat(line, "spark", str(def.get("name", entry[0])), DeepUi.ACCENT, 12, str(def.get("text", "")))
				DeepUi.wrap(line, str(def.get("text", "")), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 210))
			return func() -> Dictionary: return {} if die_id.is_empty() or engraving.is_empty() else {"die_id": die_id, "engraving": engraving}
		"pattern":
			var kinds: Array = DeepPatterns.KINDS.filter(func(k: String) -> bool: return k != "always" and k != "resonance").map(func(k: String) -> Array: return [k, k])
			var pattern: String = _chip_row(row, _slot_key(choice_id, "pattern"), kinds, DeepUi.INFO, func(panel: PanelContainer, entry: Array) -> void:
				DeepUi.stat(panel, "pair", str(entry[0]).replace("_", " "), DeepUi.INFO, 12))
			return func() -> Dictionary: return {"pattern": pattern}
		"ore":
			## How much goes down the well, in the measures a miner counts in.
			var carried: int = int(unit.get("ore", 0))
			var steps: Array = []
			for amount in [10, 25, 50, 75, 100]:
				if amount <= carried:
					steps.append([str(amount), amount])
			if steps.is_empty():
				DeepUi.stat(row, "ore", "you carry %d pyrite: the well wants ten at least" % carried, DeepUi.DIM, 12)
				return func() -> Dictionary: return {}
			var spend: String = _chip_row(row, _slot_key(choice_id, "ore"), steps, DeepUi.ORE, func(panel: PanelContainer, entry: Array) -> void:
				DeepUi.stat(panel, "ore", str(entry[0]), DeepUi.ORE, 14))
			DeepUi.label(row, "You carry %d." % carried, 11, DeepUi.DIM)
			return func() -> Dictionary: return {} if spend.is_empty() else {"ore": int(spend)}
	return func() -> Dictionary: return {}

# --- landing ---------------------------------------------------------------------------------
##
## A landing is a lift and a moment's rest. Each player first takes one respite (rest,
## appraise or polish); then the lift asks the only question it has: up, or down.

func _faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	return BenchPanel.faces_row(parent, die, edge)

# --- hoard, salvage, over ---------------------------------------------------------------------

func _page_salvage(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var head := DeepUi.vbox(content, 4)
	var title_row := DeepUi.hbox(head, 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, "skull", 32, DeepUi.BAD)
	var abandoned: bool = bool(run.get("abandoned", false))
	DeepUi.title(title_row, "You abandon the dig" if abandoned else "The party falls", 34, DeepUi.BAD)
	DeepUi.wrap(head, ("The party runs for the lift and the rock takes its share. " if abandoned else "") + "Every raw stone rolls a die by its grade. Only the top face brings it home. Set stones are safe.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 480)
	_enter(head)
	var rolls: Array = run.get("salvage", {}).get(local_id, {}).get("rolls", [])
	var turn := DeepUi.hbox(content, 8)
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	var list := DeepUi.vbox(content, 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var index: int = 0
	var shown: Array = _paged(turn, "salvage", rolls, SALVAGE_PAGE)
	## Each page's dice are rolled the first time it is turned to, and shown landed after.
	var page: int = int(_pages.get("salvage", 0))
	var rolling: bool = not _salvage_rolled.has(page) and not _headless
	_salvage_rolled[page] = true
	for roll in shown:
		var kept: bool = bool(roll.kept)
		var card := DeepUi.card(list, Color(DeepUi.GOOD if kept else DeepUi.BAD, 0.55), 12)
		card.custom_minimum_size = Vector2(480, 0)
		var row := DeepUi.hbox(card, 14)
		StoneCard.mini(row, roll.stone, 56)
		var box := DeepUi.vbox(row, 2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		## A long name is cut short rather than widening the page past the room's edge.
		var named := DeepUi.title(box, DeepUi.stone_name(roll.stone), 17, DeepUi.tier_color(str(roll.tier)))
		named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		named.tooltip_text = named.text
		named.mouse_filter = Control.MOUSE_FILTER_PASS
		DeepUi.label(box, "A d%d, needing a %d" % [int(roll.sides), int(roll.sides)], 12, DeepUi.MUTED)
		var die := SalvageDie.new(int(roll.sides), int(roll.roll), kept, 0.35 + 0.45 * float(index) if rolling else -1.0)
		row.add_child(die)
		var verdict := DeepUi.stat(row, "check" if kept else "split_shield", "kept" if kept else "shattered", DeepUi.GOOD if kept else DeepUi.BAD, 15)
		verdict.custom_minimum_size.x = 110
		die.verdict = verdict
		if rolling:
			DeepUi.pop_in(card, 0.1 + 0.45 * index)
		index += 1
	if index == 0:
		DeepUi.label(content, "You carried no raw stones. Nothing to lose.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	elif rolls.size() > SALVAGE_PAGE:
		var saved: int = rolls.filter(func(r: Dictionary) -> bool: return bool(r.kept)).size()
		DeepUi.stat(turn, "check", "%d of %d kept" % [saved, rolls.size()], DeepUi.GOOD if saved > 0 else DeepUi.MUTED, 13)
	var button := DeepUi.primary(content, "ladder", "Climb out", func() -> void: command.emit({"kind": "ready"}), 17, DeepUi.ACCENT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.disabled = bool(unit.get("ready", false))

class SalvageDie extends Control:
	## One salvage roll: the die tumbles through faces, then lands and says what it says.
	var sides: int
	var result: int
	var kept: bool
	var _t: float = 0.0
	var _delay: float = 0.0
	var _shown: int = 1
	var _tick: float = 0.0
	## Shown only once the die has landed, so the answer is never read before it is rolled.
	var verdict: Control = null:
		set(node):
			verdict = node
			if verdict != null and _t < _delay + 0.9:
				verdict.modulate.a = 0.0
	func _init(die_sides: int, rolled: int, survives: bool, delay: float) -> void:
		sides = die_sides
		result = rolled
		kept = survives
		_delay = delay
		custom_minimum_size = Vector2(58, 58)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if delay < 0.0:
			_t = 99.0
		_shown = result if delay < 0.0 else 1
	func _process(delta: float) -> void:
		_t += delta
		if _t < _delay + 0.9:
			_tick += delta
			if _t > _delay and _tick > 0.07:
				_tick = 0.0
				_shown = randi_range(1, sides)
			queue_redraw()
		elif _shown != result or (verdict != null and verdict.modulate.a < 1.0):
			_shown = result
			DeepAudio.from(self, "salvage_save" if kept else "salvage_lose", {"gap": 0.0})
			DeepUi.pulse(self, 1.3, 0.35)
			DeepUi.burst(self, size * 0.5, DeepUi.GOOD if kept else DeepUi.BAD, 18 if not kept else 40, 120.0 if not kept else 200.0, 0.5)
			if verdict != null:
				verdict.modulate.a = 1.0
				DeepUi.pulse(verdict, 1.25, 0.4)
			queue_redraw()
		else:
			set_process(false)
	func _draw() -> void:
		var landed: bool = _t >= _delay + 0.9
		var tone: Color = (DeepUi.GOOD if kept else DeepUi.BAD) if landed else DeepUi.PAPER
		var spin: float = 0.0 if landed else sin(_t * 30.0) * 0.3
		draw_set_transform(size * 0.5, spin, Vector2.ONE)
		var r: float = size.x * 0.44
		var poly := PackedVector2Array()
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + PI / 6.0
			poly.append(Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(poly, Color(tone, 0.2))
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, tone, 2.0, true)
		var text: String = str(_shown)
		var font: Font = DeepUi.display_font()
		var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, Vector2(-measured.x * 0.5, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tone)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _page_over(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var outcome: String = str(run.get("outcome", ""))
	var titles: Dictionary = {"extracted": "Extracted", "conquered": "The mine is yours", "fallen": "Fallen"}
	var glyphs: Dictionary = {"extracted": "lift", "conquered": "crown", "fallen": "skull"}
	var tone: Color = DeepUi.BAD if outcome == "fallen" else (DeepUi.ACCENT if outcome == "conquered" else DeepUi.GOOD)
	if _fresh:
		DeepAudio.play("defeat" if outcome == "fallen" else "victory")
	var card := DeepUi.card(content, Color(tone, 0.6), 26)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = 720
	var box := DeepUi.vbox(card, 14)
	var medal := Medallion.new(str(glyphs.get(outcome, "lift")), tone, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(medal)
	DeepUi.title(box, str(titles.get(outcome, outcome.capitalize())), 38, tone, HORIZONTAL_ALIGNMENT_CENTER)
	var stats := DeepUi.hbox(box, 12)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var haul: Array = unit.get("haul", [])
	var tally: Dictionary = unit.get("stats", {})
	for entry in [["stairs", "Depth", str(int(run.depth))], ["bag", "Stones home", str(haul.size())], ["sword", "Fights", str(int(tally.get("fights", 0)))],
			["ore", "Pyrite dug", str(int(tally.get("ore", 0)))], ["shield_burst", "Damage", str(int(tally.get("damage", 0)))]]:
		var tile := DeepUi.card(stats, DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9))
		tile.custom_minimum_size = Vector2(118, 0)
		var inner := DeepUi.vbox(tile, 2)
		var mark := DeepUi.icon(inner, str(entry[0]), 22, DeepUi.ACCENT)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.title(inner, str(entry[2]), 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(inner, str(entry[1]), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if not haul.is_empty():
		var home_head := DeepUi.hbox(box, 8)
		DeepUi.section(home_head, "bag", "Coming home").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tiles := HFlowContainer.new()
		tiles.add_theme_constant_override("h_separation", 10)
		tiles.add_theme_constant_override("v_separation", 10)
		box.add_child(tiles)
		var index: int = 0
		for stone in _paged(home_head, "home", haul, HOME_PAGE):
			var tile := StoneCard.tile(tiles, stone, 64)
			_enter(tile, 0.4 + 0.06 * index)
			index += 1
	var go := DeepUi.primary(box, "anvil", "Back to the workshop", func() -> void: home_requested.emit(), 18)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(card)
