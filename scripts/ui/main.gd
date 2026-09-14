extends Control
## Snapshot-only desktop presentation. The authority owns all rules and randomness.
const EngineScript = preload("res://scripts/core/run_engine.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const SessionScript = preload("res://scripts/services/session.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Forge = preload("res://scripts/ui/sprite_forge.gd")
const BackdropScript = preload("res://scripts/ui/backdrop.gd")
const SpriteActor = preload("res://scripts/ui/sprite_actor.gd")
const DiceView = preload("res://scripts/ui/dice_view.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")
const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const GemView = preload("res://scripts/ui/gem_view.gd")
const GemPanel = preload("res://scripts/ui/gem_panel.gd")
const BattleStage = preload("res://scripts/ui/battle_stage.gd")
const PlaceholderAudio = preload("res://scripts/ui/placeholder_audio.gd")
const Profile = preload("res://scripts/core/profile.gd")
const ProfileStoreScript = preload("res://scripts/services/profile_store.gd")
const Seam = preload("res://scripts/core/seam.gd")
const SeamMap = preload("res://scripts/ui/seam_map.gd")
const TremorMeter = preload("res://scripts/ui/tremor_meter.gd")
const AppraisalTable = preload("res://scripts/ui/appraisal_table.gd")
const HubScene = preload("res://scripts/ui/hub.gd")
const HubScreens = preload("res://scripts/ui/hub_screens.gd")
const Reveal = preload("res://scripts/ui/reveal.gd")
const Fanfare = preload("res://scripts/ui/fanfare.gd")
const GemBadge = preload("res://scripts/ui/gem_badge.gd")
const ItemBoard = preload("res://scripts/ui/item_board.gd")
const INK := Color("0c111c")
const PANEL := Color("161e2e")
const PANEL_HI := Color("1f2a3d")
const PANEL_LOW := Color("101725")
const LINE := Color("2f3d55")
const GOLD := Color("e8b661")
const GOLD_DIM := Color("8a6d3c")
const PAPER := Color("eef1f7")
const MUTED := Color("8f9fb5")
const GREEN := Color("6fe3b0")
const RED := Color("ff7a6b")
const BLUE := Color("76b6ff")
const VIOLET := Color("b98bff")
const AMBER := Color("ffcf7a")
const HP_LIVE := Color("2f9e75")
const HP_FOE := Color("b8413c")
const HP_LOST := Color("6b3b3b")
const HERO_KEYS := ["ardor", "kait", "max"]
const GEM_SLOTS := 6
const GEM_SLOT_WIDTH := 132
const ACTION_DEFAULTS := {"rd_reroll": KEY_R, "rd_ready": KEY_SPACE, "rd_inspect": KEY_I, "rd_target": KEY_TAB, "rd_back": KEY_ESCAPE, "rd_toggle_die": KEY_T, "rd_skip": KEY_F}

var engine: RefCounted
var session: Node
var snapshot: Dictionary = {}
var root_box: VBoxContainer
var page: Control
var overlay: PanelContainer
var toast: Label
var controlled_id := ""
var selected_dice: Array[String] = []
var menu_hero := "ardor"
var mine_choice := ""
## A special contract taken at the commission board: {id, modifier, mine_id}, or empty.
var special_choice: Dictionary = {}
var atlas_focus := ""
var screens: RefCounted
var hub_view: Control
var profile_store: RefCounted
## The result this client last carried home, so re-rendering the summary never applies it twice.
var applied_result := ""
var last_unlocked: Array = []
var last_completed: Array = []
## Where the end of an expedition is: laying the haul out on the table, then the numbers.
var return_stage := "table"
var return_gold := 0
var appraisal_view: Control
var appraising := ""
var seed_text := ""
var player_name := "Adventurer"
var server_address := "127.0.0.1"
var steam_lobby_text := ""
var settings := {"text_scale": 1.0, "reduced_motion": false, "idle_motion": true, "playback_speed": 1.0, "fullscreen": false, "bindings": {}, "sound_volume": 0.6}
var pending_render := false
var rebind_action := ""
var last_phase := ""
var journal_tab := "guide"
var selected_reserve_gem := ""
var offline_hotseat := false
var command_counter := 0
var observed_revision := -1
var playback_paused := false
var playback_events: Array = []
var playback_index := 0
var playback_timer := 0.0
## The fight as it stood before the log now playing was resolved, and how long the entry
## on screen has asked to keep the floor. Together they let a decided battle be watched
## to its end instead of cutting to the next room the instant the authority settles it.
var playback_base: Dictionary = {}
var playback_dwell := 0.0
var playback_side := 0
var playback_held := false
var loadout_cache: Dictionary = {}
## The socket in your own deck that is resolving, so the stone on the tray lights with the
## one over your hero's head rather than sitting inert while its numbers are counted out.
var gem_slot_cards: Dictionary = {}
var casting_gem := ""
var casting_age := 0.0
var casting_span := 0.0
## The pause the field takes when the initiative changes hands.
const SIDE_CHANGE_BEAT := 0.85
## How long a stone is turned under the loupe before its name is read out.
const APPRAISE_BEAT := 1.2
var history: Array = []
var last_hands: Dictionary = {}
var die_buttons: Dictionary = {}
var sound_player: AudioStreamPlayer
## A few voices, so a card turning over does not cut off the fanfare behind it.
var sound_players: Array = []
var click_sound: AudioStreamWAV
var dice_sound: AudioStreamWAV
var sounds: Dictionary = {}
## Every reveal on screen runs on this clock, so rebuilding the page never replays one.
var reveal: RefCounted
## A find held up to the light over everything else: an appraisal made mid-run.
var spotlight: Control
var spotlight_queue: Array = []
var mine_playback_label: Label
var mine_playback_index := 0
var mine_playback_timer := 0.0
var mine_playback_room := ""
var provisional: Dictionary = {}
var provisional_commands: Dictionary = {}
var backdrop: Control
var dice_views: Dictionary = {}
var actor_views: Dictionary = {}
var tracked_hp: Dictionary = {}
var stage_view: Control
## The hand on screen. A fresh roll waits here until the fight has finished playing.
var shown_hands: Dictionary = {}
var shown_turn := -1
var shown_signature := ""
## The die solid on the open inspect sheet, so hover and drag can be driven and tested.
var inspect_view: DiceView

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()
	_install_input()
	_apply_theme()
	backdrop = BackdropScript.new()
	backdrop.reduced_motion = bool(settings.reduced_motion)
	add_child(backdrop)
	for voice in range(4):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sound_players.append(player)
	sound_player = sound_players[0]
	click_sound = PlaceholderAudio.tone(680, 0.055, 0.12)
	dice_sound = PlaceholderAudio.tone(170, 0.16, 0.24)
	sounds = {"fanfare": PlaceholderAudio.fanfare(), "dirge": PlaceholderAudio.dirge(), "sparkle": PlaceholderAudio.sparkle(),
		"coins": PlaceholderAudio.coins(), "thud": PlaceholderAudio.thud(), "shatter": PlaceholderAudio.shatter(), "flourish": PlaceholderAudio.flourish()}
	reveal = Reveal.new()
	reveal.reduced = bool(settings.reduced_motion)
	reveal.wake.connect(_queue_render)
	engine = EngineScript.new()
	engine.changed.connect(_state_changed)
	profile_store = ProfileStoreScript.new()
	var opened: Dictionary = profile_store.load_or_create()
	if not opened.get("ok", false): _notify(str(opened.get("error", "Your profile could not be opened.")))
	elif opened.has("notice"): _notify(str(opened.notice))
	screens = HubScreens.new(self)
	var selected := str(_profile().get("selected_hero", ""))
	if not selected.is_empty(): menu_hero = selected.to_lower()
	session = SessionScript.new()
	add_child(session)
	session.command_received.connect(_receive_command)
	session.snapshot_received.connect(_receive_snapshot)
	session.lobby_changed.connect(func(_lobby: Dictionary): _queue_render())
	session.connection_changed.connect(func(status: String): _queue_render())
	session.error_received.connect(_notify)
	session.command_result.connect(func(result: Dictionary):
		if not result.get("ok", false): _notify(str(result.get("error", "Command rejected"))))
	session.controller_connection_changed.connect(func(id: String, connected: bool):
		if session.is_host and not snapshot.is_empty(): engine.set_controller_connected(id, connected))
	session.recovery_required.connect(_show_recovery)
	session.invite_received.connect(_accept_steam_invite)
	session.fallback_requested.connect(func(id: String):
		if not _find_hero(id).get("fallback", false): _show_fallback(id))
	if session.has_signal("party_ping"):
		session.connect("party_ping", func(id: String, _subject: String, label: String): _notify(_unit_name(id) + " pings " + label))
	_render()

func _apply_theme() -> void:
	theme = UiKit.build_theme(float(settings.text_scale))

func _style(bg: Color, border: Color, radius: int = 8, padding: int = 16, width: int = 1) -> StyleBoxFlat:
	return UiKit.flat(bg, border, radius, padding, width)

func _queue_render() -> void:
	if pending_render:
		return
	pending_render = true
	_render.call_deferred()

func _render() -> void:
	pending_render = false
	var focus_tag := ""
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focus_tag = str(focused.get_meta("focus_tag", ""))
	_detach_persistent()
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	move_child(page, 1 if is_instance_valid(backdrop) else 0)
	_dress_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	page.add_child(margin)
	root_box = _vbox(margin, 12)
	_header()
	if snapshot.is_empty():
		_hub()
	else:
		_run_screen()
	_footer()
	if not focus_tag.is_empty():
		_restore_focus(page, focus_tag)

func _dress_backdrop() -> void:
	if not is_instance_valid(backdrop):
		return
	backdrop.reduced_motion = bool(settings.reduced_motion)
	var kind := "menu"
	if not snapshot.is_empty():
		var room_kind := str(snapshot.get("room", {}).get("kind", ""))
		match str(snapshot.get("phase", "")):
			"planning", "resolution", "combat":
				kind = room_kind if room_kind in ["elite", "boss"] else "battle"
			"reward", "salvage":
				kind = room_kind if room_kind in ["elite", "boss"] else "battle"
			"route", "lift": kind = "route"
			"support": kind = room_kind
			"mine_vote", "mine_draft": kind = "mine"
			"summary": kind = "summary"
	backdrop.apply_theme(kind)

func _exit_tree() -> void:
	## Detached sprites and dice are owned by this screen, not by the scene tree.
	for voice in sound_players:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	for store in [dice_views, actor_views]:
		for id in store.keys():
			var node = store[id]
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()
		store.clear()
	if is_instance_valid(stage_view) and stage_view.get_parent() == null:
		stage_view.free()
	if is_instance_valid(appraisal_view) and appraisal_view.get_parent() == null:
		appraisal_view.free()
	UiKit.release()
	GemIcons.release()
	GemMesh.release()
	Forge.clear_cache()
	SpriteActor.release()
	BackdropScript.release()

func _detach_persistent() -> void:
	## Sprites and dice outlive a re-render so their animation is continuous.
	if is_instance_valid(stage_view) and stage_view.get_parent() != null:
		stage_view.get_parent().remove_child(stage_view)
	if is_instance_valid(appraisal_view) and appraisal_view.get_parent() != null:
		appraisal_view.get_parent().remove_child(appraisal_view)
	for store in [dice_views, actor_views]:
		for id in store.keys():
			var node = store[id]
			if not is_instance_valid(node):
				store.erase(id)
			elif node.get_parent() != null:
				node.get_parent().remove_child(node)

func _prune_persistent() -> void:
	var live: Dictionary = {}
	for hero in snapshot.get("heroes", []):
		live[str(hero.get("id", ""))] = true
		for die in hero.get("dice", []) + hero.get("reserve_dice", []):
			live[str(die.get("id", ""))] = true
	for enemy in snapshot.get("enemies", []):
		live[str(enemy.get("id", ""))] = true
	for store in [dice_views, actor_views]:
		for id in store.keys():
			if live.has(id) or str(id).begins_with("preview:"):
				continue
			var node = store[id]
			store.erase(id)
			if is_instance_valid(node):
				if node.get_parent() != null:
					node.get_parent().remove_child(node)
				node.queue_free()

func _idle_motion() -> bool:
	## Whether anything turns while nothing is happening. Every die and gem that drifts needs
	## its own live camera, so this is the cheapest frame to buy back on a busy screen — and
	## the first thing someone who cannot watch drifting objects will reach for. Reduced
	## motion overrides it, because that setting means all of this and more.
	return bool(settings.idle_motion) and not bool(settings.reduced_motion)

func _apply_motion() -> void:
	## Pushes the choice onto everything already on screen rather than waiting for the next
	## thing that happens to rebuild it.
	for view in dice_views.values():
		if is_instance_valid(view):
			view.live = _idle_motion()
	if is_instance_valid(backdrop):
		backdrop.reduced_motion = bool(settings.reduced_motion)
	_queue_render()

func _die_view(die_id: String) -> DiceView:
	var view = dice_views.get(die_id, null)
	if not is_instance_valid(view):
		view = DiceView.new()
		dice_views[die_id] = view
	view.live = _idle_motion()
	return view

func _battle_stage() -> Control:
	if not is_instance_valid(stage_view):
		stage_view = BattleStage.new()
		stage_view.inspect_skill = _inspect_stage_skill
	stage_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_view.custom_minimum_size.y = 230
	return stage_view

func _plate_hand(unit: Dictionary, roster: Array) -> Array:
	## The rolled hand as it is drawn under a combatant: each face keeps the shape and
	## colour of the die it came from, so the plate matches the tray and the solid. The
	## die's own id rides along, so an activation can trace its motes back to the faces
	## that fed it.
	var solids: Dictionary = {}
	for die in unit.get("dice", []):
		solids[str(die.get("id", ""))] = die
	var faces: Array = []
	for roll in roster:
		var die: Dictionary = solids.get(str(roll.get("die_id", "")), {})
		faces.append({"value": int(roll.get("value", 0)),
			"shape": str(die.get("shape", "D6")), "key": str(die.get("key", die.get("shape", "D6"))),
			"die_id": str(roll.get("die_id", "")), "die": die, "roll": roll})
	return faces

func _stage_units(state: Dictionary) -> Array:
	## Presentation-only description of the battlefield, read from the given state. While a
	## fight plays out that state is the one the log started from, advanced only as far as
	## the events already shown, so nobody leaves the field before their last blow is drawn.
	var units: Array = []
	var me: Dictionary = _hero()
	var locked: bool = bool(me.get("ready", false)) or _playing_out()
	var standing: Dictionary = _projected_standing()
	var thrown: Dictionary = _projected_rolls()
	for enemy in state.get("enemies", []):
		var id := str(enemy.get("id", ""))
		var hp: int = int(standing.get(id, {}).get("hp", enemy.get("hp", 0)))
		var lines: Array = []
		if int(enemy.get("statuses", {}).get("stun", 0)) > 0:
			lines.append("STUNNED · SLOT SKIPPED")
		units.append({
			"id": id, "key": str(enemy.get("key", "ENEMY")), "side": 1,
			"name": str(enemy.get("name", "Enemy")), "hp": hp, "max_hp": int(enemy.get("max_hp", 1)),
			"block": int(standing.get(id, {}).get("block", enemy.get("block", 0))), "downed": hp <= 0,
			"targeted": str(me.get("preferred_target", "")) == id,
			"hint": "Left-click to target. Right-click to inspect.",
			"boss": bool(enemy.get("boss", false)), "mine": false,
			"tint": _unit_tint(str(enemy.get("key", ""))), "bar": HP_FOE,
			"intents": lines, "badges": _status_badges(enemy),
			"pick_disabled": hp <= 0 or locked,
			"loadout": _enemy_loadout(enemy),
			# The other side's dice are its only tray, so they are drawn as real solids and
			# tumble where they stand when its slot comes up.
			"solid": true,
			"hand": _plate_hand(enemy, thrown.get(id, {}).get("hand", enemy.get("hand", [])))})
	for hero in state.get("heroes", []):
		var id := str(hero.get("id", ""))
		var hp: int = int(standing.get(id, {}).get("hp", hero.get("hp", 0)))
		units.append({
			"id": id, "key": str(hero.get("key", "ARDOR")), "side": - 1,
			"name": str(hero.get("player_name", hero.get("name", "Hero"))), "hp": hp,
			"max_hp": int(hero.get("max_hp", 1)),
			"block": int(standing.get(id, {}).get("block", hero.get("block", 0))), "downed": hp <= 0,
			"targeted": false, "hint": "Right-click to inspect. Friendly effects reach the whole party.",
			"boss": false, "mine": id == controlled_id,
			"tint": _unit_tint(str(hero.get("key", ""))), "bar": HP_LIVE,
			"intents": [],
			"badges": _status_badges(hero), "pick_disabled": true,
			"loadout": _stage_loadout(hero, state),
			"hand": _plate_hand(hero, _hand_for(hero))})
	return units

func _enemy_loadout(enemy: Dictionary) -> Array:
	## The other side's roster, read the same way the party reads its own gems: every action
	## the routine can reach, dimmed until its dice are up and the roll says which it opened.
	var rolled: Dictionary = _projected_rolls().get(str(enemy.get("id", "")), {})
	var opened: Array = rolled.get("opened", [])
	var lit: bool = not rolled.is_empty()
	var carried: Array = []
	for action in Combat.enemy_skills(enemy):
		var key := str(action.key)
		var open: bool = key in opened
		carried.append({
			"id": key, "glyph": GemIcons.emblem(key), "tint": AMBER,
			"dim": not lit or not open,
			"tip": "%s\n%s\nRight-click for when it fires and what it does." % [str(action.name), "Its dice have not come up yet." if not lit else
				("This roll opened it." if open else "This roll did not open it.")]})
	return carried

func _stage_loadout(hero: Dictionary, state: Dictionary) -> Array:
	## The stones an ally is carrying, small enough to ride over the head the way their
	## roll rides under their feet. It is the anchor an activation lights up, so a party
	## member's turn is followed on the party member rather than on a panel of their own.
	var id := str(hero.get("id", ""))
	if loadout_cache.has(id):
		return loadout_cache[id]
	var carried: Array = []
	for gem in hero.get("gems", []):
		if not gem.get("equipped", false):
			continue
		var key := str(gem.get("key", ""))
		var active: bool = Combat.preview(hero, gem, _hand_for(hero), state).get("active", false)
		carried.append({
			"id": str(gem.get("id", "")), "glyph": GemIcons.emblem(key),
			"tint": _gem_color(gem), "dim": not active,
			"tip": "%s\n%s\nRight-click to inspect." % [_gem_name(gem), _gem_stats(gem)]})
	loadout_cache[id] = carried
	return carried

func _status_badges(unit: Dictionary) -> Array:
	var badges: Array = []
	var statuses: Dictionary = unit.get("statuses", {})
	for key in ["stun", "poison", "resolve"]:
		var stacks := int(statuses.get(key, 0))
		if stacks > 0:
			badges.append(["%s %d" % [key.to_upper().substr(0, 3), stacks],
				AMBER if key == "stun" else (Color("9bdc3c") if key == "poison" else VIOLET)])
	if unit.get("ready", false):
		badges.append(["READY", GREEN])
	return badges

func _pick_unit(unit_id: String) -> void:
	## Only hostile targets are chosen. Support skills always reach the whole party.
	if _hero().get("ready", false):
		return
	for enemy in snapshot.get("enemies", []):
		if str(enemy.get("id", "")) == unit_id and int(enemy.get("hp", 0)) > 0:
			_command("SetPreferredTarget", {"unit_id": unit_id})
			return

func _inspect_by_id(unit_id: String) -> void:
	for unit in snapshot.get("enemies", []) + snapshot.get("heroes", []):
		if str(unit.get("id", "")) == unit_id:
			_inspect_unit(unit)
			return

func _die_chip(parent: Node, view_id: String, die: Dictionary, edge: int, rolled: Dictionary = {}) -> Control:
	## A still 3D die for lists: inventory, shops, the workshop and the journal.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(edge, edge)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(holder)
	var view := _die_view(view_id)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(view)
	view.live = false
	view.configure(die, rolled, false, false, BLUE)
	holder.tooltip_text = "%s\nFaces: %s\nRight-click to inspect." % [_die_name(die), _faces_text(die)]
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_die(die))
	return holder

func _actor_for(unit_id: String, art_key: String, facing: float) -> SpriteActor:
	var actor = actor_views.get(unit_id, null)
	if not is_instance_valid(actor):
		actor = SpriteActor.new()
		actor_views[unit_id] = actor
	actor.facing = facing
	actor.setup(Forge.unit(art_key), _unit_tint(art_key), bool(settings.reduced_motion))
	return actor

func _unit_tint(art_key: String) -> Color:
	match art_key.to_upper():
		"ARDOR": return Color("ffb069")
		"KAIT": return GREEN
		"MAX": return BLUE
		"SLIME", "SLIME_KING": return GREEN
		"MIRROR_WISP", "MIRROR_REGENT": return Color("bfe9ff")
		"RIFT_HOUND", "RIFT_SOVEREIGN": return VIOLET
		"IRON_WARDEN", "STONE_CRAB": return Color("b9c6d6")
		"GEM_CULTIST": return Color("ff7ad9")
		"DARTLING": return Color("d8cf6a")
	return RED

func _restore_focus(node: Node, tag: String) -> bool:
	if node is Control and str(node.get_meta("focus_tag", "")) == tag:
		node.grab_focus()
		return true
	for child in node.get_children():
		if _restore_focus(child, tag):
			return true
	return false

func _header() -> void:
	## In a run the top of the screen carries the journey and nothing else. Everything
	## that used to sit up here — inventory, journal, settings, saving — is behind Escape.
	if snapshot.is_empty():
		return
	var bar := _hbox(root_box, 12)
	var fighting: bool = _shown_phase() in BATTLE_SCENE
	if fighting:
		UiKit.icon(bar, Forge.room(str(snapshot.get("room", {}).get("kind", "battle"))), 26).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_label(bar, str(snapshot.get("room", {}).get("name", "Battle")), 17, GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var turn := int(_battle_state().get("turn", 1))
		UiKit.chip(bar, "TURN %02d" % turn, PAPER, 10).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if turn >= 7:
			var enrage := UiKit.chip(bar, "ENRAGE +%d" % (2 * (turn - 6)), RED, 10)
			enrage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			enrage.tooltip_text = "Every enemy hit takes %d extra raw damage this turn." % (2 * (turn - 6))
	else:
		_label(bar, str(snapshot.get("phase", "")).to_upper().replace("_", " "), 15, _phase_color()).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mine: Dictionary = Catalog.mine_definition(str(snapshot.get("mine_id", "")))
	_label(bar, "%s  ·  DEPTH %d" % [str(mine.get("name", "The mine")).to_upper(), int(snapshot.get("depth", 0))], 10, GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var meter := TremorMeter.new()
	meter.reduced_motion = bool(settings.reduced_motion)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(meter)
	meter.set_tremor(int(snapshot.get("tremor", 0)), str(Catalog.definitions("enemies").get(mine.get("boss_id", ""), {}).get("name", "The boss")))
	# Reachable by key or by click: it is the only way in to everything the bar shed.
	var escape := _button(bar, "Menu  [%s]" % _binding_name("rd_back"), _show_menu)
	escape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	escape.tooltip_text = "Equipment, journal, settings and saving all live here."

func _phase_color() -> Color:
	match str(snapshot.get("phase", "")):
		"planning", "resolution", "combat": return RED
		"route", "lift": return BLUE
		"reward": return GOLD
		"summary", "salvage": return VIOLET
		"mine_vote", "mine_draft": return GREEN
	return AMBER

func _footer() -> void:
	UiKit.rule(root_box, Color("22304a"))
	var row := _hbox(root_box)
	_spacer(row)
	if snapshot.is_empty():
		_label(row, "GENERATED SPRITES  ·  REAL POLYHEDRAL DICE", 10, MUTED)
	else:
		_label(row, "SEED  %s   ·   %s   ·   SEAT %d" % [str(snapshot.get("seed", "")), str(snapshot.get("phase", "")).to_upper().replace("_", " "), _seat() + 1], 10, MUTED)

func _hub() -> void:
	var bar := _hbox(root_box, 10)
	_label(bar, "ROGUEDICE  ·  THE JEWELLER'S", 13, GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.chip(bar, "%d GOLD" % int(_profile().get("gold", 0)), GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.chip(bar, "%d / %d GEMS" % [_profile().get("collection", {}).size(), Catalog.SKILLS.size()], VIOLET).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spacer(bar)
	var destination: Dictionary = Catalog.mine_definition(_destination())
	_label(bar, "%s  →  %s" % [str(Catalog.definitions("heroes").get(menu_hero.to_upper(), {}).get("name", menu_hero)), str(destination.get("name", ""))], 14, PAPER).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _in_party():
		var members: Array = session.lobby.get("members", [])
		var ready := members.filter(func(member: Dictionary) -> bool: return member.get("ready", false)).size()
		UiKit.chip(bar, "PARTY %d  ·  %d READY" % [members.size(), ready], GREEN).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hub_view = HubScene.new()
	hub_view.reduced_motion = bool(settings.reduced_motion)
	hub_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(hub_view)
	hub_view.activated.connect(func(id: String): _play_sound(click_sound); screens.open(id))
	var claimable := 0
	for field in ["board", "special"]:
		for note in _profile().get("commissions", {}).get(field, []):
			if note.get("status", "") == "complete": claimable += 1
	var badges: Dictionary = {}
	if claimable > 0: badges["commission_board"] = str(claimable)
	if _in_party(): badges["door"] = str(session.lobby.get("members", []).size())
	hub_view.set_badges(badges)

func _in_party() -> bool:
	return is_instance_valid(session) and str(session.transport_kind) != "offline" and not session.lobby.is_empty() and str(session.status) not in ["idle", "failed", "disconnected"]

func _local_lobby_member() -> Dictionary:
	for member in session.lobby.get("members", []):
		if str(member.get("player_id", "")) == str(session.local_player_id): return member
	return {}

func _choosing_destination() -> bool:
	## Solo players choose their own mine; in a party only the host does.
	return not _in_party() or session.is_host

func _destination() -> String:
	var mines: Array = Profile.unlocked_mines(_profile())
	if _in_party() and not session.is_host and not str(session.lobby.get("mine_id", "")).is_empty():
		return str(session.lobby.mine_id)
	if not mine_choice in mines: mine_choice = mines[0] if not mines.is_empty() else ""
	return mine_choice

func _destination_special() -> Dictionary:
	if _in_party() and not session.is_host:
		return {"id": str(session.lobby.get("special_id", "")), "modifier": str(session.lobby.get("modifier", ""))}
	return special_choice if str(special_choice.get("mine_id", "")) == _destination() else {}

func _choose_mine(mine_id: String) -> void:
	mine_choice = mine_id
	atlas_focus = mine_id
	if str(special_choice.get("mine_id", "")) != mine_id: special_choice = {}
	if _in_party() and session.is_host:
		var special := _destination_special()
		session.choose_mine(mine_id, str(special.get("id", "")), str(special.get("modifier", "")))
	_queue_render()

func _choose_hero(hero_key: String) -> void:
	menu_hero = hero_key.to_lower()
	profile_store.transact(func(profile: Dictionary) -> String: return Profile.select_hero(profile, hero_key.to_upper()))
	_sync_lobby_identity()
	_queue_render()

func _sync_lobby_identity() -> void:
	## Tells the party which hero this player brings and what they socketed.
	if not _in_party(): return
	session.choose_hero(menu_hero)
	session.set_loadout(_loadout(menu_hero))

func _open_party(connect_action: Callable) -> void:
	var result: Variant = connect_action.call()
	if result is Dictionary and not result.get("ok", false):
		_notify(str(result.get("error", "The party could not be reached.")))
	_close_overlay()
	_sync_lobby_identity.call_deferred()
	if session.is_host: _choose_mine.call_deferred(_destination())
	_queue_render()

func _begin_local() -> void:
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		_notify("Enter a whole-number seed, or leave it blank for a new expedition.")
		return
	session.start_offline(player_name, menu_hero)
	offline_hotseat = true
	controlled_id = str(session.local_player_id)
	var party: Array = [ {"id": controlled_id, "hero_id": menu_hero, "name": player_name, "loadout": _loadout(menu_hero)}]
	var result: Dictionary = engine.new_run({"heroes": party, "mine_id": _destination(), "special": _destination_special(), "seed": seed_text if not seed_text.is_empty() else str(Time.get_unix_time_from_system()), "host_id": controlled_id, "session_id": session.session_id})
	if result.has("error") and not result.get("ok", true):
		_notify(str(result.error))
	else:
		_state_changed(engine.state)

func _begin_network() -> void:
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		_notify("Enter a whole-number seed, or leave it blank for a new expedition.")
		return
	var members: Array = session.start_run()
	if members.is_empty():
		_notify("Every hero must be ready before departure.")
		return
	offline_hotseat = false
	var party: Array = []
	for member in members:
		var seat: Dictionary = {"id": member.get("player_id", member.get("id", "")), "name": member.get("name", "Hero"), "hero_id": member.get("hero_id", "ardor")}
		if not member.get("loadout", []).is_empty(): seat["loadout"] = member.loadout
		party.append(seat)
	controlled_id = str(session.local_player_id)
	var started: Dictionary = engine.new_run({"heroes": party, "mine_id": _destination(), "special": _destination_special(), "seed": seed_text if not seed_text.is_empty() else str(Time.get_unix_time_from_system()), "host_id": str(session.host_player_id), "session_id": session.session_id})
	if started.has("error") and not started.get("ok", true):
		_notify(str(started.error))
		session.return_to_lobby()
		return
	_close_overlay()
	_state_changed(engine.state)
	session.broadcast_snapshot(snapshot)

func _profile() -> Dictionary:
	return profile_store.profile if profile_store != null else {}

func _loadout(hero_key: String) -> Array:
	## The profile's loadout for a hero, as the plain records a run is started with.
	var gems: Array = []
	for gem in Profile.loadout_gems(_profile(), hero_key.to_upper(), "menu"):
		gems.append(Profile.gem_record(gem))
	return gems

func _resume() -> void:
	var loaded: Dictionary = engine.save_store.load_checkpoint()
	if not loaded.get("ok", false):
		_notify(str(loaded.get("error", "No saved expedition was found.")))
		return
	var restored: Dictionary = loaded.state.duplicate(true)
	restored.paused = false
	for hero in restored.get("heroes", []):
		hero.connected = true
		hero.fallback = false
		hero.erase("disconnect_time")
	offline_hotseat = true
	var result: Dictionary = engine.restore(restored, loaded.get("command_history", {}))
	if result.has("ok") and not result.ok:
		_notify(str(result.get("error", "No saved expedition was found.")))
		return
	if engine.state.is_empty():
		_notify("No saved expedition was found.")
		return
	offline_hotseat = true
	controlled_id = str(engine.state.get("heroes", [ {}])[0].get("id", ""))
	session.start_offline(player_name)
	_state_changed(engine.state)

func _state_changed(state: Dictionary) -> void:
	var previous: Dictionary = snapshot
	var finds: Array = _appraised_since(previous, state)
	if snapshot.get("run_id", "") != state.get("run_id", ""):
		reveal.reset()
		spotlight_queue.clear()
		return_stage = "table"
		return_gold = 0
		appraising = ""
		last_unlocked = []
		last_completed = []
		if is_instance_valid(appraisal_view):
			appraisal_view.queue_free()
		appraisal_view = null
		shown_hands.clear()
		shown_turn = -1
		shown_signature = ""
		last_hands.clear()
		provisional.clear()
		provisional_commands.clear()
		observed_revision = -1
	for hero in state.get("heroes", []):
		if not hero.get("hand", []).is_empty(): last_hands[hero.id] = hero.hand.duplicate(true)
	snapshot = state.duplicate(true)
	loadout_cache.clear()
	var mine_room := str(snapshot.get("room", {}).get("id", ""))
	if not snapshot.get("mine", {}).get("events", []).is_empty() and mine_playback_room != mine_room:
		mine_playback_room = mine_room
		mine_playback_index = 0
		mine_playback_timer = 0.0
	if controlled_id.is_empty() and not snapshot.get("heroes", []).is_empty():
		controlled_id = str(snapshot.heroes[0].id)
	var phase := str(snapshot.get("phase", ""))
	if phase != last_phase:
		selected_dice.clear()
		_close_overlay()
		last_phase = phase
	var revision := int(snapshot.get("revision", 0))
	if revision != observed_revision:
		playback_events = snapshot.get("last_events", []).duplicate(true)
		playback_index = 0
		playback_timer = 0.0
		playback_dwell = 0.0
		playback_side = 0
		playback_base = previous if str(previous.get("run_id", "")) == str(snapshot.get("run_id", "")) else snapshot
	observed_revision = revision
	_refresh_hands()
	_prune_persistent()
	_react_to_events()
	_queue_render()
	for gem in finds:
		spotlight_queue.append(gem)
	if not finds.is_empty():
		_show_spotlight.call_deferred()
	if is_instance_valid(session) and session.is_host and not offline_hotseat:
		session.broadcast_snapshot(snapshot)

func _appraised_since(previous: Dictionary, state: Dictionary) -> Array:
	## Stones that were sealed in your haul a moment ago and are gems now: the appraisals a
	## loupe or a Lapidary just made, which are worth stopping the screen for.
	if previous.is_empty() or str(previous.get("run_id", "")) != str(state.get("run_id", "")):
		return []
	var sealed: Dictionary = {}
	for stone in _hero_in(previous).get("haul", []):
		sealed[str(stone.get("id", ""))] = true
	var found: Array = []
	for gem in _hero_in(state).get("gems", []):
		if sealed.has(str(gem.get("id", ""))):
			found.append(gem.duplicate(true))
	return found

func _stage_on_screen() -> bool:
	return is_instance_valid(stage_view) and stage_view.is_inside_tree()

const BATTLE_PHASES := ["planning", "resolution", "combat"]
## Phases played out on the battlefield. The spoils and the salvage both belong to the fight
## that produced them, so they are laid over it rather than cutting away to another screen.
const BATTLE_SCENE := ["planning", "resolution", "combat", "reward", "salvage"]

func _playing_out() -> bool:
	## A fight that has already been decided still has to be watched. While the log has
	## entries left, the battlefield keeps the screen and the room that follows waits its
	## turn, so a killing blow is drawn before the spoils are offered.
	if playback_index >= playback_events.size() or playback_base.is_empty():
		return false
	if str(snapshot.get("phase", "")) in BATTLE_PHASES:
		return false
	return str(playback_base.get("phase", "")) in BATTLE_PHASES \
		and str(playback_base.get("room", {}).get("id", "")) == str(snapshot.get("room", {}).get("id", ""))

func _shown_phase() -> String:
	var phase := str(snapshot.get("phase", "route"))
	return "planning" if _playing_out() else phase

func _battle_state() -> Dictionary:
	return playback_base if _playing_out() else snapshot

func _projected_rolls() -> Dictionary:
	## Which enemies have taken their dice up at the point in the log now on screen, and what
	## those dice opened. Before an enemy's own slot arrives it has no hand and no lit action,
	## which is the whole point: the party plans against the board, not against a forecast.
	var rolls: Dictionary = {}
	if playback_events.is_empty():
		return rolls
	for index in mini(playback_index, playback_events.size()):
		var event: Variant = playback_events[index]
		if event is Dictionary and str(event.get("kind", "")) == "roll":
			rolls[str(event.get("actor", ""))] = {
				"hand": event.get("hand", []), "opened": event.get("opened", [])}
	return rolls

func _projected_standing() -> Dictionary:
	## Where each combatant stands at the point in the log currently on screen. Every event
	## carries the standing it produced, so this reads those back rather than re-deriving a
	## rule: without it a fight would empty its field the instant the authority settled it.
	var standing: Dictionary = {}
	if playback_base.is_empty() or playback_index >= playback_events.size():
		return standing
	for unit in playback_base.get("heroes", []) + playback_base.get("enemies", []):
		standing[str(unit.get("id", ""))] = {"hp": int(unit.get("hp", 0)), "block": int(unit.get("block", 0))}
	for index in mini(playback_index, playback_events.size()):
		var event: Variant = playback_events[index]
		if not event is Dictionary or not event.has("target_hp"):
			continue
		var actor_id := str(event.get("actor", ""))
		var target_id := str(event.get("target", ""))
		if standing.has(actor_id):
			standing[actor_id] = {"hp": int(event.get("actor_hp", 0)), "block": int(event.get("actor_block", 0))}
		if standing.has(target_id):
			standing[target_id] = {"hp": int(event.get("target_hp", 0)), "block": int(event.get("target_block", 0))}
	return standing

func _hand_for(unit: Dictionary) -> Array:
	## The hand as it is being shown, which lags the snapshot while a fight plays out.
	return shown_hands.get(str(unit.get("id", "")), unit.get("hand", []))

func _holding_hand() -> bool:
	## Only a hand that is actually on the table can be held. The opening deal of a
	## battle has nothing to wait for, so it lands as soon as it arrives.
	if shown_hands.is_empty() or int(snapshot.get("turn", 0)) == shown_turn:
		return false
	for id in shown_hands:
		if not shown_hands[id].is_empty():
			return true
	return false

func _hand_signature() -> String:
	var parts: Array = []
	for hero in snapshot.get("heroes", []):
		for entry in hero.get("hand", []):
			parts.append("%s#%s#%s" % [str(entry.get("die_id", "")), str(entry.get("roll_count", 0)), str(entry.get("face_index", 0))])
	return "%d|%s" % [int(snapshot.get("turn", 0)), ",".join(parts)]

func _refresh_hands() -> bool:
	## New faces are held back until the round they belong to has finished animating,
	## so the dice on the table never reroll underneath the fight that is still playing.
	var signature := _hand_signature()
	if signature == shown_signature:
		return false
	# A decided fight clears every hand the moment the authority settles it. The dice on
	# the plates are still feeding an activation, so they stay until the log runs out.
	if _playing_out():
		return false
	if _holding_hand() and playback_index < playback_events.size() and _stage_on_screen():
		return false
	shown_hands.clear()
	for hero in snapshot.get("heroes", []):
		shown_hands[str(hero.get("id", ""))] = hero.get("hand", []).duplicate(true)
	shown_turn = int(snapshot.get("turn", 0))
	shown_signature = signature
	return true

func _react_to_events() -> void:
	## Purely cosmetic reactions driven by the authoritative snapshot.
	for unit in snapshot.get("heroes", []) + snapshot.get("enemies", []):
		var id := str(unit.get("id", ""))
		var hp := int(unit.get("hp", 0))
		var actor: SpriteActor = actor_views.get(id, null)
		if tracked_hp.has(id) and is_instance_valid(actor):
			if hp < int(tracked_hp[id]):
				actor.flinch()
			elif hp > int(tracked_hp[id]):
				actor.channel()
		tracked_hp[id] = hp

func _receive_snapshot(state: Dictionary) -> void:
	offline_hotseat = false
	controlled_id = str(session.local_player_id)
	engine.state = state.duplicate(true)
	_state_changed(state)

func _receive_command(player_id: String, envelope: Dictionary) -> void:
	var result: Dictionary = engine.execute(player_id, envelope)
	session.reply_command(player_id, result)
	if not result.get("ok", false):
		_notify(str(result.get("error", "Command rejected")))

func _command(kind: String, payload: Dictionary = {}) -> void:
	if snapshot.is_empty():
		return
	var envelope: Dictionary = engine.make_envelope(controlled_id, kind, payload)
	if offline_hotseat or session.is_host:
		var result: Dictionary = engine.execute(controlled_id, envelope)
		if not result.get("ok", false):
			_notify(str(result.get("error", "That action is not available.")))
	else:
		session.send_command(envelope)

func _hero() -> Dictionary:
	return _hero_in(snapshot)

func _hero_in(state: Dictionary) -> Dictionary:
	for hero in state.get("heroes", []):
		if str(hero.get("id")) == controlled_id:
			return hero
	return state.get("heroes", [ {}])[0] if not state.get("heroes", []).is_empty() else {}

func _seat() -> int:
	return int(_hero().get("seat", 0))

func _run_screen() -> void:
	var phase: String = _shown_phase()
	var body := _hbox(root_box, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# During a fight the battlefield already shows every combatant, so the roster
	# column would only repeat it. Outside combat it is the party's home screen.
	if phase == "summary": _apply_expedition_result()
	var at_table := phase == "summary" and _appraisal_pending()
	if not phase in BATTLE_SCENE and not at_table:
		var side_scroll := _scroll(body)
		side_scroll.custom_minimum_size.x = 240
		side_scroll.size_flags_horizontal = 0
		var side := _vbox(side_scroll, 10)
		_label(side, "PARTY ORDER", 11, GOLD)
		for hero in snapshot.get("heroes", []):
			_party_card(side, hero)
	# A fight is laid out to fit the window exactly, so it is never given a scroll bar.
	var fighting: bool = phase in BATTLE_SCENE or at_table
	var center := _vbox(body if fighting else _scroll(body), 10 if fighting else 14)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fighting:
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match phase:
		"planning", "resolution", "combat", "reward", "salvage": _battle(center)
		"route": _route(center)
		"support": _support(center)
		"mine_vote": _mine_vote(center)
		"mine_draft": _mine_draft(center)
		"lift": _lift(center)
		"summary": _summary(center)
		_: _label(center, phase.capitalize(), 30, GOLD); _ready_button(center)

func _party_card(parent: Node, hero: Dictionary) -> void:
	var mine := str(hero.get("id")) == controlled_id
	var downed := int(hero.get("hp", 0)) <= 0
	var is_ready: bool = hero.get("ready", false)
	var card := _panel(parent, Color("223150") if mine else PANEL, GOLD if mine else LINE, 11)
	var row := _hbox(card, 9)
	var portrait := _actor_for(str(hero.get("id", "")), str(hero.get("key", "")).to_upper(), 1.0)
	portrait.custom_minimum_size = Vector2(54, 64)
	portrait.bob = 0.7
	portrait.downed = downed
	portrait.targeted = false
	portrait.show_ground = false
	row.add_child(portrait)
	var head := _vbox(row, 3)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := _hbox(head, 6)
	_label(name_row, str(hero.get("player_name", hero.get("name", hero.get("key", "Hero")))), 16)
	_spacer(name_row)
	_label(name_row, "●" if is_ready else "○", 15, GREEN if is_ready else MUTED)
	_label(head, "%02d  ·  %s%s" % [int(hero.get("seat", 0)) + 1, str(hero.get("key", "")).capitalize(), "  ·  YOU" if mine else ""], 10, BLUE)
	UiKit.meter(head, float(hero.get("hp", 0)), float(hero.get("max_hp", 1)), HP_LOST if downed else HP_LIVE, 16, "%d / %d" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 1))])
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 4)
	card.add_child(chips)
	if int(hero.get("block", 0)) > 0:
		UiKit.chip(chips, "BLOCK %d" % int(hero.get("block", 0)), BLUE)
	UiKit.chip(chips, "%d ORE" % int(hero.get("ore", 0)), GOLD)
	if not hero.get("haul", []).is_empty():
		UiKit.chip(chips, "%d STONE%s" % [hero.haul.size(), "" if hero.haul.size() == 1 else "S"], VIOLET)
	if int(hero.get("loupes", 0)) > 0:
		UiKit.chip(chips, "%d LOUPE%s" % [int(hero.loupes), "" if int(hero.loupes) == 1 else "S"], BLUE)
	UiKit.chip(chips, "DOWNED" if downed else ("READY" if is_ready else "PLANNING"), RED if downed else (GREEN if is_ready else MUTED))
	var statuses := _status_text(hero)
	if not statuses.is_empty():
		_label(card, statuses, 12, RED, true)
	if snapshot.get("phase") == "planning":
		_label(card, "Enemy → " + _unit_name(str(hero.get("preferred_target", ""))), 11, MUTED, true)
		var mini_hand: Array = []
		for die in _hand_for(hero):
			mini_hand.append(str(die.get("value", "?")))
		_label(card, "  ·  ".join(mini_hand), 18, GREEN)
		if not mine:
			var active_names: Array = []
			for gem in hero.get("gems", []):
				if gem.get("equipped", false):
					var preview: Dictionary = Combat.preview(hero, gem, _hand_for(hero), snapshot)
					if preview.get("active", false): active_names.append(str(preview.get("name", gem.get("key", ""))))
			_label(card, "Ready gems: " + ", ".join(active_names), 11, GREEN, true)
	if offline_hotseat and not mine:
		_button(card, "Control this hero", func(): controlled_id = str(hero.id); selected_dice.clear(); _queue_render())
	elif not offline_hotseat and not bool(hero.get("connected", true)):
		_label(card, "DISCONNECTED · %ds grace remaining" % _grace_remaining(hero), 11, RED, true)
		if session.is_host:
			_button(card, "Recovery options", func(): _show_fallback(str(hero.id)))

func _battle(parent: Node) -> void:
	die_buttons.clear()
	gem_slot_cards.clear()
	var state: Dictionary = _battle_state()
	var hero: Dictionary = _hero_in(state)
	var room_kind := str(snapshot.get("room", {}).get("kind", "battle"))
	var phase := _shown_phase()
	# Gems ride above the battlefield and dice below it, so the fight keeps the middle.
	_gem_deck(parent, hero, state)
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", UiKit.panel_box(Color("1a2233"), Color("0a0e18"), Color("32405e"), 12, 6, 1.4, 0.12))
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	var stage := _battle_stage()
	field.add_child(stage)
	stage.sync(_stage_units(state), bool(settings.reduced_motion), _room_color(room_kind), _pick_unit, _inspect_by_id)
	if phase in ["reward", "salvage"]:
		_aftermath(field, phase, room_kind)
		return
	# While a decided turn is still being drawn the tray is locked and offers a skip. It looks
	# exactly the same whether the fight goes on or has just been lost, so nothing on it
	# gives away the ending before the last blow lands.
	_hand_deck(parent, hero, _resolving())

func _resolving() -> bool:
	return _playing_out() or (_holding_hand() and playback_index < playback_events.size())

func _gem_deck(parent: Node, hero: Dictionary, state: Dictionary) -> void:
	## Six sockets, centred, sprite first. Every word lives on the tooltip and the sheet.
	var row := _hbox(parent, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var equipped: Array = []
	for gem in hero.get("gems", []):
		if gem.get("equipped", false): equipped.append(gem)
	var ordered_previews: Array = [] if _holding_hand() else Combat.preview_loadout(hero, state)
	for slot in range(maxi(GEM_SLOTS, equipped.size())):
		if slot >= equipped.size():
			_empty_gem(row)
			continue
		var gem: Dictionary = equipped[slot]
		_gem_slot(row, gem, ordered_previews[slot] if slot < ordered_previews.size() else Combat.preview(hero, gem, _hand_for(hero), state))

func _gem_slot(row: Node, gem: Dictionary, preview: Dictionary) -> void:
	var active: bool = preview.get("active", false)
	var card := _panel(row, Color("18302c") if active else PANEL, GREEN if active else LINE, 8)
	var frame: Control = card.get_parent()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.custom_minimum_size.x = GEM_SLOT_WIDTH
	gem_slot_cards[str(gem.get("id", ""))] = frame
	reveal.show(frame, "socketed:" + str(gem.get("id", "")), 0.0, "pop", 0.5)
	var badge := _gem_portrait(card, gem, 76)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.modulate = Color.WHITE if active else Color(0.55, 0.60, 0.70, 0.75)
	var title := _label(card, _gem_name(gem), 12, _gem_color(gem) if active else MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	_gem_marks_row(card, gem, 13).modulate = Color(1, 1, 1, 1.0 if active else 0.6)
	var need := _hbox(card, 6)
	need.alignment = BoxContainer.ALIGNMENT_CENTER
	need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_requirement_icons(need, gem, preview, 16)
	card.tooltip_text = _preview_text(gem)
	card.mouse_entered.connect(func(): _highlight_dice(preview.get("contributing_dice", [])))
	card.mouse_exited.connect(func(): _highlight_dice([]))
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_gem(gem))

func _empty_gem(row: Node) -> void:
	## An open socket is shown, not hidden: the party can see the room it still has.
	var card := _panel(row, PANEL_LOW, Color(LINE, 0.5), 8)
	var frame: Control = card.get_parent()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.custom_minimum_size.x = GEM_SLOT_WIDTH
	frame.modulate = Color(1, 1, 1, 0.55)
	frame.tooltip_text = "An empty gem socket. Equip a gem from your reserve between rooms."
	var hollow := Control.new()
	hollow.custom_minimum_size = Vector2(76, 76)
	hollow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(hollow)
	var caption := _label(card, "EMPTY", 12, MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := Control.new()
	pad.custom_minimum_size.y = 16
	card.add_child(pad)

func _hand_deck(parent: Node, hero: Dictionary, resolving := false) -> void:
	## The hand is centred at the foot of the screen with its two actions flanking it,
	## so the dice take the width and the battlefield keeps the height.
	var row := _hbox(parent, 16)
	var locked: bool = resolving or hero.get("ready", false) or int(hero.get("hp", 0)) <= 0
	var rerolls := int(hero.get("rerolls", 0))
	var left := _vbox(row, 6)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var reroll_chip := _hbox(left, 6)
	reroll_chip.alignment = BoxContainer.ALIGNMENT_END
	UiKit.chip(reroll_chip, "%d REROLL" % rerolls, GREEN if rerolls > 0 else MUTED)
	var reroll_row := _hbox(left, 6)
	reroll_row.alignment = BoxContainer.ALIGNMENT_END
	var reroll := _button(reroll_row, "Reroll  [%s]" % _binding_name("rd_reroll"), _reroll, true)
	reroll.disabled = selected_dice.is_empty() or rerolls <= 0 or locked
	if str(hero.get("key", "")).to_lower() == "max":
		var extra := _button(reroll_row, "Second Thought · %d" % int(hero.get("trait_charges", 0)), func():
			if selected_dice.size() == 1:
				_command("UseHeroTrait", {"die_id": selected_dice[0]})
				selected_dice.clear())
		extra.tooltip_text = "Reroll a single selected die without spending the shared reroll."
		extra.disabled = selected_dice.size() != 1 or int(hero.get("trait_charges", 0)) <= 0 or locked
	var dice_row := _hbox(row, 10)
	dice_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(hero.get("dice", []).size()):
		_die_button(dice_row, hero.dice[i], i, locked)
	var right := _vbox(row, 6)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var purse := Combat.ore_allowance(snapshot, hero)
	var ore_row := _hbox(right, 6)
	UiKit.chip(ore_row, "%d ORE" % purse, GOLD).tooltip_text = "Ore your gems may still mint this battle: %d. Room rewards are separate." % purse
	if resolving:
		var skip := _button(_hbox(right, 6), "Skip  [%s]" % _binding_name("rd_skip"), _skip_playback)
		skip.set_meta("focus_tag", "skip")
		skip.tooltip_text = "Show the rest of this turn at once."
		_label(right, "The turn is playing out.", 12, MUTED)
	else:
		_ready_button(_hbox(right, 6))

func _requirement_icons(parent: Node, gem: Dictionary, preview: Dictionary, edge: float) -> Control:
	## The activation condition drawn as the dice that would meet it, worded on hover.
	var key := str(gem.get("key", ""))
	var clarity := int(preview.get("effective_clarity", gem.get("clarity", 1)))
	## A rule written as data can set its cut-off from any rank, so the strip is told them all.
	var spec: Dictionary = DiceIcons.requirement(key, clarity, int(gem.get("cut", 1)), int(gem.get("carat", 1)))
	return DiceIcons.build(parent, spec, edge, DiceIcons.detail(key, clarity))

func _die_button(parent: Node, die: Dictionary, index: int, locked: bool) -> void:
	var rolled: Dictionary = {}
	for entry in _hand_for(_hero()):
		if str(entry.get("die_id")) == str(die.get("id")):
			rolled = entry
	var selected := selected_dice.has(str(die.id)) and not locked
	var slot := _vbox(parent, 3)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.custom_minimum_size.x = 104
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", UiKit.panel_box(
		Color("3d3521") if selected else Color("1a2338"),
		Color("15120b") if selected else Color("0c121e"),
		GOLD if selected else Color("2a3752"), 10, 4, 2.0 if selected else 1.2, 0.28))
	slot.add_child(tray)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(94, 94)
	tray.add_child(stack)
	var view := _die_view(str(die.id))
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(view)
	view.configure(die, rolled, selected, false, GOLD if selected else BLUE)
	var button := Button.new()
	button.flat = true
	button.toggle_mode = true
	button.button_pressed = selected
	button.disabled = locked
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.set_meta("focus_tag", "die_" + str(index))
	button.pressed.connect(func(): _play_sound(click_sound); _toggle_die(str(die.id)))
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_die(die, rolled))
	button.tooltip_text = "%s\nFaces: %s\nEvery physical face has equal probability.\nPress %d to select for reroll. Right-click to inspect." % [_die_name(die), _faces_text(die), index + 1]
	stack.add_child(button)
	die_buttons[str(die.id)] = button
	var caption := _hbox(slot, 5)
	_label(caption, "%d" % (index + 1), 10, MUTED)
	_label(caption, str(die.get("shape", "D6")), 10, BLUE)
	_spacer(caption)
	_label(caption, "REROLL" if selected else "KEEP", 10, GOLD if selected else MUTED)

func _toggle_die(id: String) -> void:
	if _hero().get("ready", false): return
	if selected_dice.has(id): selected_dice.erase(id)
	else: selected_dice.append(id)
	_queue_render()

func _reroll() -> void:
	if selected_dice.is_empty(): return
	_play_sound(dice_sound)
	_command("RerollDice", {"die_ids": selected_dice.duplicate()})
	selected_dice.clear()

func _party_choice() -> bool:
	## Whether a choice is actually put to other heroes. One hero decides alone, so calling
	## that a vote is a lie about how the room works — and a tie-break rule nobody needs.
	return snapshot.get("heroes", []).size() > 1

func _can_ping() -> bool:
	## A ping is addressed to another person at another machine. Solo has nobody to tell,
	## and around one keyboard `_ping` already sends nothing, so the button would be a
	## button that does nothing.
	return _party_choice() and not offline_hotseat

func _route(parent: Node) -> void:
	var head := _hbox(parent, 10)
	_label(head, "Choose a tunnel.", 30, GOLD)
	_spacer(head)
	UiKit.chip(head, "DEPTH %d" % int(snapshot.get("depth", 0)), GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.chip(head, "LANTERN %d LAYER%s" % [int(snapshot.get("sight", Seam.SIGHT)), "" if int(snapshot.get("sight", Seam.SIGHT)) == 1 else "S"], BLUE).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(parent, ("The party votes together; ties follow the host. " if _party_choice() else "") + "Your lantern shows the next %d layers. Beyond that you see only shapes in the dark — and the beacons of lifts, the only way home." % int(snapshot.get("sight", Seam.SIGHT)), 14, MUTED, true)
	var map := SeamMap.new()
	map.reduced_motion = bool(settings.reduced_motion)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(map)
	map.configure(snapshot, controlled_id, _vote_tunnel)
	var offers: Array = snapshot.get("offers", [])
	var voted: Dictionary = snapshot.get("votes", {})
	var mine := str(voted.get(controlled_id, ""))
	var list := HFlowContainer.new()
	list.add_theme_constant_override("h_separation", 10)
	list.add_theme_constant_override("v_separation", 10)
	parent.add_child(list)
	for index in range(offers.size()):
		var offer: Dictionary = offers[index]
		var kind := str(offer.get("kind", ""))
		var accent := RED if offer.get("wakes_boss", false) else _room_color(kind)
		var chosen := mine == str(offer.id)
		var card := _panel(list, PANEL_HI if chosen else PANEL, accent if chosen else Color(accent, 0.55), 10)
		card.custom_minimum_size.x = 250
		reveal.show(card.get_parent(), "route:%s" % str(snapshot.get("phase_id", "")), 0.08 * index, "pop")
		var row := _hbox(card, 10)
		UiKit.icon(row, Forge.room(kind), 40).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var text := _vbox(row, 2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text, str(offer.get("name", "Room")), 17, PAPER)
		if index < 9: _label(text, "KEY %d" % (index + 1), 10, MUTED)
		if offer.get("wakes_boss", false):
			_label(card, "The tremors will wake the boss here.", 12, RED, true)
		var note: Dictionary = _route_note(kind)
		if not str(note.get("text", "")).is_empty(): _label(card, str(note.text), 12, note.get("tone", BLUE), true)
		var caption := ("Voted  ✓" if chosen else "Vote  →") if _party_choice() else "Enter  →"
		var vote := _button(card, caption, func(): _vote_tunnel(str(offer.id)), not chosen)
		vote.disabled = not mine.is_empty()
		vote.tooltip_text = str(offer.get("description", ""))
		if _can_ping(): _button(card, "Ping", func(): _ping("room", str(offer.id), str(offer.get("name", "Room"))))
		if _party_choice():
			var votes: Array = []
			for hero in snapshot.get("heroes", []):
				if str(voted.get(hero.get("id", ""), "")) == str(offer.id): votes.append(str(hero.get("player_name", hero.get("name", "Hero"))))
			if not votes.is_empty(): _label(card, "Votes: " + ", ".join(votes), 12, GREEN)
	var heroes: Array = snapshot.get("heroes", [])
	if heroes.size() > 1:
		var pending: Array = []
		for hero in heroes:
			if not voted.has(str(hero.get("id", ""))): pending.append(str(hero.get("player_name", hero.get("name", "Hero"))))
		_label(parent, "All votes are in." if pending.is_empty() else "Waiting on %d of %d: %s" % [pending.size(), heroes.size(), ", ".join(pending)], 13, GREEN if pending.is_empty() else AMBER, true)
	_button(parent, "Review equipment", _show_inventory)

func _vote_tunnel(offer_id: String) -> void:
	if snapshot.get("votes", {}).has(controlled_id):
		_notify("You have already voted on this tunnel.")
		return
	_command("VoteRoom", {"offer_id": offer_id})

func _lift(parent: Node) -> void:
	_room_banner(parent, "lift", "The Lift")
	_label(parent, "The cage creaks on its rope. Ride up and everything you carry comes home. Keep digging and the next lift may be a long way down.", 16, MUTED, true)
	var hero: Dictionary = _hero()
	var found := 0
	for gem in hero.get("gems", []):
		if gem.get("found", false): found += 1
	_label(parent, "You carry %d unappraised stone%s and %d appraised find%s." % [hero.get("haul", []).size(), "" if hero.get("haul", []).size() == 1 else "s", found, "" if found == 1 else "s"], 15, GOLD, true)
	var voted := str(snapshot.get("votes", {}).get(controlled_id, ""))
	var row := _hbox(parent, 12)
	var ride := _button(row, "Ride up  ·  end the expedition", func(): _command("VoteLift", {"choice": "ride"}), voted.is_empty())
	ride.disabled = not voted.is_empty()
	var dig := _button(row, "Keep digging", func(): _command("VoteLift", {"choice": "dig"}))
	dig.disabled = not voted.is_empty()
	if _party_choice():
		for other in snapshot.get("heroes", []):
			var vote := str(snapshot.get("votes", {}).get(str(other.get("id", "")), ""))
			_label(parent, "%s · %s" % [str(other.get("player_name", other.get("name", "Hero"))), {"ride": "rides up", "dig": "digs on"}.get(vote, "deciding")], 13, GREEN if not vote.is_empty() else AMBER)
	_button(parent, "Review equipment", _show_inventory)

func _aftermath(field: Control, phase: String, room_kind: String) -> void:
	## The end of a fight, played over the field it was fought on: the title lands, then the
	## spoils — or what the fall leaves to chance — are turned over one at a time. The party
	## only leaves this field once every hero has settled their share.
	var key := "%s:%s" % [phase, str(snapshot.get("room", {}).get("id", snapshot.get("run_id", "")))]
	var lost := phase == "salvage"
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	# The light and sparks stay on the battlefield rather than spilling over the gem tray.
	layer.clip_contents = true
	field.add_child(layer)
	layer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			reveal.hurry())
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72) if lost else Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	reveal.show(dim, key, 0.0, "fade", 0.7)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	layer.add_child(margin)
	var column := _vbox(margin, 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := Fanfare.new()
	banner.kind = Fanfare.Kind.DEFEAT if lost else (Fanfare.Kind.BOSS if room_kind == "boss" else Fanfare.Kind.VICTORY)
	banner.title = "DEFEATED" if lost else ("THE BOSS FALLS" if room_kind == "boss" else "VICTORY")
	banner.subtitle = "What the party carried is left to the dice." if lost else ({"elite": "A hard fight, and worth it.", "boss": "The mine is quiet. Its chest is yours."}.get(room_kind, "The spoils are yours."))
	banner.started = reveal.begin(key)
	banner.clock = reveal.now
	banner.reduced = bool(settings.reduced_motion)
	banner.custom_minimum_size.y = 132
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(banner)
	reveal.cue(key, 0.0, _sound("dirge" if lost else "fanfare"))
	var middle := _hbox(column, 0)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spacer(middle)
	# The card hugs what it holds, up to the height of the field; past that its body scrolls
	# and the buttons that move the party on stay pinned along its foot.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_box(Color("1c2233"), Color("0d111c"), RED if lost else GOLD, 14, 18, 1.8, 0.25))
	card.custom_minimum_size.x = 900
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	middle.add_child(card)
	_spacer(middle)
	reveal.show(card, key, 0.85, "pop", 0.5)
	var inside := _vbox(card, 10)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	inside.add_child(scroll)
	var box := _vbox(scroll, 12)
	UiKit.rule(inside)
	var footer := _hbox(inside, 10)
	# Measured against the layer, which the field sizes, not against the column the card sits
	# in: that column grows with whatever it is given, so it cannot say how much room there is.
	var fit := func():
		if not is_instance_valid(scroll) or not is_instance_valid(layer): return
		var room: float = layer.size.y - 36.0 - banner.custom_minimum_size.y - 6.0 - footer.get_combined_minimum_size().y - 36.0 - 24.0
		scroll.custom_minimum_size.y = clampf(box.get_combined_minimum_size().y, 80.0, maxf(80.0, room))
	box.minimum_size_changed.connect(fit)
	layer.resized.connect(fit)
	fit.call_deferred()
	if lost:
		_salvage_card(box, footer, key)
	else:
		_reward_card(box, footer, key, room_kind)

func _salvage_card(box: VBoxContainer, footer: HBoxContainer, key: String) -> void:
	_label(box, "Each stone you carried is rolled on a die by its rarity — a d6 for Common up to a d20 for Legendary. Only the top face drags it back to the surface. Your loadout is never at risk.", 14, MUTED, true)
	var entries: Array = snapshot.get("salvage", {}).get(controlled_id, [])
	var hero: Dictionary = _hero()
	if entries.is_empty():
		_label(box, "You carried nothing to salvage.", 16, MUTED, true)
	var settle := 1.0
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var gem: Dictionary = {}
		for item in hero.get("haul", []) + hero.get("gems", []):
			if str(item.get("id", "")) == str(entry.get("gem_id", "")): gem = item
		var revealed: bool = entry.get("revealed", false)
		var kept: bool = entry.get("kept", false)
		var roll_key := "salvage-roll:" + str(entry.get("gem_id", ""))
		# The die lands, then the verdict: the roll key starts the first time this stone is seen rolled.
		var landed: bool = revealed and reveal.reached(roll_key, 0.9)
		var panel := _panel(box, PANEL, (GREEN if kept else RED) if landed else LINE, 10)
		reveal.show(panel.get_parent(), key, 1.1 + 0.12 * index, "rise")
		var row := _hbox(panel, 14)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(72, 72)
		row.add_child(holder)
		var sides := int(entry.get("sides", 6))
		var die: Dictionary = Catalog.die("D%d" % sides, "salvage-" + str(entry.get("gem_id", "")))
		var view := _die_view("preview:salvage:" + str(entry.get("gem_id", "")))
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(view)
		var shown: Dictionary = {}
		if revealed:
			shown = {"die_id": die.id, "face_index": int(entry.roll) - 1, "face_id": "%s-f%d" % [die.id, int(entry.roll) - 1], "value": int(entry.roll), "roll_count": 1}
		view.configure(die, shown, false, landed and kept, GOLD)
		var info := _vbox(row, 4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not gem.is_empty(): _gem_details(info, gem)
		var verdict := _vbox(row, 2)
		verdict.custom_minimum_size.x = 170
		verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not revealed:
			_button(verdict, "Roll the d%d" % sides, func(): _play_sound(dice_sound); _command("RevealSalvage", {"gem_id": str(entry.gem_id)}), true).disabled = hero.get("ready", false)
		elif not landed:
			_label(verdict, "Rolling…", 18, AMBER)
		else:
			reveal.cue(roll_key, 0.9, _sound("thud" if kept else "shatter"))
			var stamp := _label(verdict, "SAVED" if kept else "SHATTERED", 26, GREEN if kept else RED)
			stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reveal.show(stamp, roll_key, 0.9, "stamp")
			_label(verdict, "Rolled %d of %d" % [int(entry.roll), sides], 12, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if revealed:
			reveal.begin(roll_key)
		settle = maxf(settle, 1.1 + 0.12 * index)
	var pending: bool = entries.any(func(entry: Dictionary) -> bool: return not entry.get("revealed", false))
	var landing: bool = entries.any(func(entry: Dictionary) -> bool: return entry.get("revealed", false) and not reveal.reached("salvage-roll:" + str(entry.get("gem_id", "")), 0.9))
	_party_status(footer)
	_spacer(footer)
	var actions := footer
	if pending:
		_button(actions, "Roll them all", func(): _play_sound(dice_sound); _command("RevealSalvage", {"gem_id": ""}), true).disabled = hero.get("ready", false)
	var leave := _ready_button(actions, false)
	leave.text = ("Stay a moment" if hero.get("ready", false) else "Leave the mine") + "  [%s]" % _binding_name("rd_ready")
	leave.disabled = pending or landing
	if pending: leave.tooltip_text = "Roll every stone first."

func _reward_card(box: VBoxContainer, footer: HBoxContainer, key: String, room_kind: String) -> void:
	var reward: Dictionary = snapshot.get("reward_offers", {}).get(controlled_id, {})
	var hero: Dictionary = _hero()
	var beat := 1.0
	var ore := int(reward.get("ore", 0))
	if ore > 0:
		var purse := _hbox(box, 10)
		UiKit.icon(purse, Forge.prop("gold"), 34).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var amount := _label(purse, "+%d ORE" % ore, 26, GOLD)
		reveal.count(amount, key, beat + 0.1, ore, "+%d ORE")
		_label(purse, "You now carry %d." % int(hero.get("ore", 0)), 13, MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		reveal.show(purse, key, beat, "pop")
		reveal.cue(key, beat + 0.1, _sound("coins"))
		beat += 0.55
	var found: Array = reward.get("found", [])
	if not found.is_empty():
		reveal.show(_label(box, "STONES PRIED LOOSE  ·  UNAPPRAISED, INTO YOUR HAUL", 11, VIOLET), key, beat, "fade")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		box.add_child(flow)
		for index in range(found.size()):
			var stone: Dictionary = found[index]
			var at := beat + 0.3 + 0.6 * index
			var front := _reveal_card(flow, key, at, _gem_color(stone), 390)
			_gem_details(front, stone)
			reveal.cue(key, at + 0.25, _sound("sparkle"))
		beat += 0.3 + 0.6 * found.size()
		reveal.show(_label(box, "Judge them by eye, or appraise them with a loupe or at a Lapidary. They come home with you unless the party falls.", 12, MUTED, true), key, beat, "fade")
	elif room_kind == "battle":
		reveal.show(_label(box, "Nothing glittering this time.", 14, MUTED, true), key, beat, "fade")
	var chest: Array = reward.get("gems", [])
	if not chest.is_empty():
		reveal.show(_label(box, "THE BOSS CHEST  ·  TAKE ONE", 12, GOLD), key, beat, "fade")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		box.add_child(flow)
		var opened := beat + 0.3 + 0.65 * chest.size()
		var ready_to_pick: bool = reveal.reached(key, opened)
		var taken_id := ""
		for offer in chest:
			var gem: Dictionary = offer.get("gem", offer)
			for owned in hero.get("gems", []):
				if str(owned.get("id", "")) == str(offer.get("id", gem.get("id", ""))): taken_id = str(owned.id)
		for index in range(chest.size()):
			var offer: Dictionary = chest[index]
			var gem: Dictionary = offer.get("gem", offer)
			var offer_id := str(offer.get("id", gem.get("id", "")))
			var at := beat + 0.3 + 0.65 * index
			var front := _reveal_card(flow, key, at, _gem_color(gem), 272)
			_gem_card_face(front, gem)
			reveal.cue(key, at + 0.25, _sound("flourish" if int(Catalog.SKILLS.get(str(gem.get("key", "")), {}).get("rarity", 1)) >= 3 else "sparkle"))
			if not reward.get("gem_done", true):
				var take := _button(front, "Take this gem", func(): _command("ChooseReward", {"kind": "gem", "offer_id": offer_id}), true)
				take.disabled = not ready_to_pick or hero.get("ready", false)
			elif offer_id == taken_id:
				_socket_note(front, taken_id)
			else:
				front.modulate = Color(0.6, 0.6, 0.66, 0.7)
				_label(front, "Left in the dark.", 12, MUTED)
		if not reward.get("gem_done", true):
			_button(box, "Leave the chest shut  ·  +3 ore", func(): _command("ChooseReward", {"kind": "gem", "offer_id": ""})).disabled = not ready_to_pick or hero.get("ready", false)
		beat = opened
	var relics: Array = reward.get("relics", [])
	if not relics.is_empty():
		reveal.show(_label(box, "A RELIC FROM THE FALLEN  ·  TAKE ONE", 12, GOLD), key, beat, "fade")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		box.add_child(flow)
		var opened := beat + 0.3 + 0.6 * relics.size()
		var ready_to_pick: bool = reveal.reached(key, opened)
		for index in range(relics.size()):
			var offer: Dictionary = relics[index]
			var relic: Dictionary = offer.get("relic", offer)
			var offer_id := str(offer.get("id", relic.get("id", "")))
			var definition: Dictionary = Catalog.RELICS.get(relic.get("key", ""), {})
			var at := beat + 0.3 + 0.6 * index
			var front := _reveal_card(flow, key, at, GOLD, 390)
			var relic_row := _hbox(front, 12)
			UiKit.icon(relic_row, Forge.relic(str(relic.get("key", ""))), 56).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var relic_text := _vbox(relic_row, 4)
			relic_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(relic_text, str(definition.get("name", relic.get("key", "Relic"))), 19, GOLD)
			_label(relic_text, str(definition.get("description", "")), 13, MUTED, true)
			reveal.cue(key, at + 0.25, _sound("sparkle"))
			var taken: bool = hero.get("relics", []).any(func(owned: Dictionary) -> bool: return str(owned.get("id", "")) == offer_id)
			if not reward.get("relic_done", true):
				_button(front, "Take this relic", func(): _command("ChooseReward", {"kind": "relic", "offer_id": offer_id}), true).disabled = not ready_to_pick or hero.get("ready", false)
			elif taken:
				UiKit.chip(front, "TAKEN  ·  EQUIP IT FROM YOUR EQUIPMENT", GREEN)
			else:
				front.modulate = Color(0.6, 0.6, 0.66, 0.7)
		if not reward.get("relic_done", true):
			_button(box, "Decline the relic", func(): _command("ChooseReward", {"kind": "relic", "offer_id": ""})).disabled = not ready_to_pick or hero.get("ready", false)
		beat = opened
	var settled: bool = reward.get("gem_done", true) and reward.get("relic_done", true)
	var actions := footer
	var gear := _button(actions, "Equipment  [%s]" % _binding_name("rd_inspect"), _show_inventory)
	_party_status(actions)
	gear.tooltip_text = "Sockets, dice and relics can all be changed before the party moves on."
	_spacer(actions)
	if not settled:
		_label(actions, "Choose your reward to continue.", 13, AMBER).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var onward := _ready_button(actions, false)
	var ready: bool = hero.get("ready", false)
	onward.text = ("Wait — not yet" if ready else ("Climb out with the prize" if room_kind == "boss" else "Continue down the seam")) + "  [%s]" % _binding_name("rd_ready")
	onward.disabled = not settled or not reveal.reached(key, beat)

func _reveal_card(parent: Node, key: String, delay: float, accent: Color, width: float) -> VBoxContainer:
	## A card dealt face down that turns over at its moment. The back covers the face until
	## half way through the turn, so nothing on it can be read — or clicked — early.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_box(PANEL.lightened(0.07), PANEL.darkened(0.32), Color(accent, 0.75), 11, 12, 1.6, 0.22))
	card.custom_minimum_size.x = width
	parent.add_child(card)
	var front := _vbox(card, 8)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", UiKit.panel_box(Color("3a2c1c"), Color("1a120b"), Color(accent, 0.6), 11, 0, 1.8, 0.4))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back)
	var mark := CenterContainer.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(mark)
	var sigil := UiKit.icon(mark, Forge.prop("sigil"), 54, Color(accent.lightened(0.2), 0.85))
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal.flip(card, back, key, delay, -1.0, front)
	return front

func _gem_card_face(front: VBoxContainer, gem: Dictionary) -> void:
	var portrait := _gem_portrait(front, gem, 92)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rarity := int(Catalog.SKILLS.get(str(gem.get("key", "")), {}).get("rarity", 1))
	var name := _label(front, _gem_name(gem), 20, _gem_color(gem))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var chip := UiKit.chip(front, ["", "COMMON", "UNCOMMON", "RARE", "LEGENDARY"][clampi(rarity, 1, 4)], [MUTED, MUTED, GREEN, BLUE, AMBER][clampi(rarity, 1, 4)])
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gem_title_row(front, gem, 13, PAPER, false)
	_label(front, str(Catalog.SKILLS.get(str(gem.get("key", "")), {}).get("trigger", "")), 13, GREEN, true)
	_formula_rows(front, gem, -1, 12)
	front.tooltip_text = _preview_text(gem)

func _socket_note(parent: Node, gem_id: String) -> void:
	## Where a gem just taken went: an open socket, or the reserve because the sockets are full.
	var equipped: Array = _hero().get("gems", []).filter(func(gem: Dictionary) -> bool: return gem.get("equipped", false))
	for index in range(equipped.size()):
		if str(equipped[index].get("id", "")) == gem_id:
			reveal.show(UiKit.chip(parent, "TAKEN  ·  SET IN SOCKET %d" % (index + 1), GREEN), "socketed:" + gem_id, 0.0, "stamp")
			return
	reveal.show(UiKit.chip(parent, "TAKEN  ·  IN RESERVE, YOUR SOCKETS ARE FULL", AMBER), "socketed:" + gem_id, 0.0, "stamp")

func _party_status(parent: Node) -> void:
	## Who the party is still waiting on, as faces rather than a list of names.
	var heroes: Array = snapshot.get("heroes", [])
	if heroes.size() < 2: return
	var row := _hbox(parent, 12)
	_label(row, "THE PARTY", 11, MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for hero in heroes:
		var ready: bool = hero.get("ready", false)
		var chip := _hbox(row, 4)
		var face := UiKit.icon(chip, Forge.unit(str(hero.get("key", ""))), 30)
		face.modulate = Color.WHITE if ready else Color(0.7, 0.72, 0.8, 0.8)
		_label(chip, str(hero.get("player_name", hero.get("name", "Hero"))), 13, PAPER).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_label(chip, "✓" if ready else "…", 15, GREEN if ready else AMBER).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _route_note(kind: String) -> Dictionary:
	## What this room is worth to the hero reading it, in the currencies rooms actually
	## charge. Deliberately about you, not the party: the description above covers that.
	## The tone is carried with the text so a plain fact never reads as a warning.
	var hero: Dictionary = _hero()
	var gold := int(hero.get("ore", 0))
	var hp := int(hero.get("hp", 0))
	var top := int(hero.get("max_hp", 1))
	match kind:
		"rest":
			var fallen := 0
			for other in snapshot.get("heroes", []):
				if int(other.get("hp", 0)) <= 0: fallen += 1
			var gain := mini(top / 3, top - hp)
			if fallen > 0: return _note("+%d HP for you, and %d fallen hero%s returns to their feet." % [gain, fallen, "" if fallen == 1 else "es"], GREEN)
			if gain <= 0: return _note("You are already at full HP.", BLUE)
			return _note("+%d HP for you." % gain, GREEN)
		"shop", "lapidary": return _note("You carry %d ore." % gold, BLUE if gold > 0 else AMBER)
		"lift": return _note("A way home.", GREEN)
		"treasure": return _note("Unguarded, as far as anyone can tell.", GREEN)
		"workshop":
			for relic in hero.get("relics", []):
				if relic.get("key") == "TINKERS_BELT" and relic.get("equipped", false):
					return _note("Tinker’s Belt may cover this service.", GREEN)
			return _note("You carry %d ore; a service costs 5." % gold, BLUE if gold >= 5 else AMBER)
		"wager":
			var tiers: Array = []
			for amount in EngineScript.WAGER_STAKES:
				if gold >= int(amount): tiers.append(str(amount))
			if tiers.is_empty(): return _note("You carry %d ore: no stake is within reach." % gold, AMBER)
			return _note("You can cover stakes of %s ore." % ", ".join(tiers), BLUE)
		"crucible":
			var spare := 0
			for gem in hero.get("gems", []):
				if not gem.get("equipped", false) and gem.get("found", false): spare += 1
			return _note("%d HP and %d spare found gem%s to spend." % [hp, spare, "" if spare == 1 else "s"], BLUE)
		"mine": return _note("Free, but noisy: ore and unappraised stones.", GREEN)
	return _note("", MUTED)

func _note(text: String, tone: Color) -> Dictionary:
	return {"text": text, "tone": tone}

func _gem_summary(gem: Dictionary) -> String:
	## Before the first battle there is no hand to read a gem against, and the evaluator's
	## "invalid hand" is an engine word, not an answer to the player's question.
	if _preview_hand().is_empty(): return "Roll a hand in a battle to see this gem’s numbers."
	return str(Combat.preview(_hero(), gem, _preview_hand(), snapshot).get("summary", ""))

func _support(parent: Node) -> void:
	var room: Dictionary = snapshot.get("room", {})
	var kind := str(room.get("kind", ""))
	_room_banner(parent, kind, str(room.get("name", "A quiet moment")))
	match kind:
		"shop": _shop(parent)
		"workshop": _workshop(parent)
		"lapidary": _lapidary(parent)
		"rest":
			_label(parent, "The fire burns low. Your party has recovered one third of maximum HP; fallen heroes return to their feet.", 16, MUTED, true)
			_label(parent, "Prepare your dice and gems before the road continues.", 14, GREEN)
			_button(parent, "Manage equipment", _show_inventory)
		"event": _event(parent)
		"mine": _mine_draft(parent)
		"wager": _wager(parent)
		"crucible": _crucible(parent)
		"treasure": _treasure(parent)
	_ready_button(parent)

func _treasure(parent: Node) -> void:
	var cache: Dictionary = snapshot.get("room", {}).get("treasure", {}).get(controlled_id, {})
	var key := "treasure:" + str(snapshot.get("room", {}).get("id", ""))
	_label(parent, "Nobody has touched this in years, and it is yours: ore, and a stone already known for what it is.", 16, MUTED, true)
	var purse := _hbox(parent, 10)
	UiKit.icon(purse, Forge.prop("gold"), 34).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reveal.count(_label(purse, "+%d ORE" % int(cache.get("ore", 0)), 24, GOLD), key, 0.35, int(cache.get("ore", 0)), "+%d ORE")
	reveal.show(purse, key, 0.2, "pop")
	reveal.cue(key, 0.35, _sound("coins"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	parent.add_child(flow)
	var gems: Array = cache.get("gems", [])
	for index in range(gems.size()):
		var gem: Dictionary = gems[index]
		var at := 0.8 + 0.6 * index
		var front := _reveal_card(flow, key, at, _gem_color(gem), 420)
		_gem_details(front, gem)
		for owned in _hero().get("gems", []):
			if str(owned.get("id", "")) == str(gem.get("id", "")):
				if owned.get("equipped", false): _socket_note(front, str(owned.id))
				else: UiKit.chip(front, "IN RESERVE  ·  YOUR SOCKETS ARE FULL", AMBER)
		reveal.cue(key, at + 0.25, _sound("flourish" if int(Catalog.SKILLS.get(str(gem.get("key", "")), {}).get("rarity", 1)) >= 3 else "sparkle"))
	reveal.show(_label(parent, "An appraised find takes an open socket by itself. It is still at risk if the party falls.", 13, GOLD, true), key, 0.8 + 0.6 * gems.size(), "fade")
	_button(parent, "Equipment  [%s]" % _binding_name("rd_inspect"), _show_inventory)

func _room_banner(parent: Node, kind: String, name: String) -> void:
	## Every service room opens the same way: what this place is, and what you are carrying
	## into it. Gold and HP are what these rooms actually charge, so reading them stops
	## being a detour through the party column.
	var accent := _room_color(kind)
	var row := _hbox(parent, 12)
	UiKit.icon(row, Forge.room(kind), 44).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := _vbox(row, 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(text, name, 30, GOLD)
	var hero: Dictionary = _hero()
	var purse := _hbox(text, 6)
	UiKit.chip(purse, "%d ORE" % int(hero.get("ore", 0)), GOLD)
	UiKit.chip(purse, "%d / %d HP" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 1))], GREEN if int(hero.get("hp", 0)) * 2 > int(hero.get("max_hp", 1)) else RED)
	if kind in ["workshop", "lapidary", "event", "wager", "crucible"]:
		var used: bool = snapshot.get("room", {}).get("services", {}).get(controlled_id, false)
		UiKit.chip(purse, "SERVICE USED" if used else "ONE SERVICE AVAILABLE", MUTED if used else accent)
	_spacer(purse)

## --- The Wager Hall -----------------------------------------------------------

func _wager(parent: Node) -> void:
	var seat: Dictionary = snapshot.get("room", {}).get("wager", {}).get(controlled_id, {})
	var stake := int(seat.get("stake", 0))
	var hand: Array = seat.get("hand", [])
	var settled: bool = seat.get("settled", false)
	_label(parent, "Stake ore on the house’s five dice. One reroll, then the table pays the pattern you show.", 15, MUTED, true)
	if settled:
		var won := int(seat.get("payout", 0))
		var entry: Dictionary = EngineScript.wager_entry(str(seat.get("pattern", "nothing")))
		var box := _panel(parent, PANEL_HI, GOLD if won > stake else LINE)
		_label(box, str(entry.get("name", "No pattern")), 26, GOLD if won > stake else MUTED)
		_label(box, "Staked %d  ·  paid %d  ·  %s %d ore" % [stake, won, "up" if won > stake else "down", absi(won - stake)], 17, GREEN if won > stake else RED)
		_wager_hand(box, seat.get("dice", []), hand, false)
		_label(parent, "The table takes one hand per visit. Mark Done when your equipment is ready.", 14, MUTED, true)
		_wager_table(parent, str(seat.get("pattern", "")))
		return
	if stake <= 0:
		_label(parent, "CHOOSE YOUR STAKE", 12, GOLD)
		var row := _hbox(parent, 10)
		for amount in EngineScript.WAGER_STAKES:
			var value := int(amount)
			var b := _button(row, "Stake %d ore" % value, func(): selected_dice.clear(); _command("PlaceWager", {"stake": value}), true)
			var short := value - int(_hero().get("ore", 0))
			b.disabled = short > 0 or _hero().get("ready", false)
			b.tooltip_text = "You need %d more ore." % short if short > 0 else "A %d ore stake pays up to %d on five of a kind." % [value, value * int(EngineScript.WAGER_TABLE[0].multiplier)]
		_label(parent, "The house deals five matched %s, so the table is the same wager whatever your own dice have become." % EngineScript.WAGER_DIE, 13, BLUE, true)
		_wager_table(parent, "")
		_button(parent, "Walk past the tables", func(): _command("SetReady", {"ready": true}))
		return
	var values: Array = []
	for roll in hand: values.append(int(roll.get("value", 0)))
	var pattern := str(EngineScript.wager_pattern(values))
	var showing: Dictionary = EngineScript.wager_entry(pattern)
	var payout := stake * int(showing.get("multiplier", 0))
	_label(parent, "Staked %d ore.  Showing %s  ·  %d ore." % [stake, str(showing.get("name", "")).to_lower(), payout], 20, GOLD if payout > stake else MUTED)
	_wager_hand(parent, seat.get("dice", []), hand, not seat.get("rerolled", false))
	var actions := _hbox(parent, 10)
	if not seat.get("rerolled", false):
		var reroll := _button(actions, "Reroll %d selected" % selected_dice.size(), func():
			_play_sound(dice_sound)
			_command("WagerReroll", {"die_ids": selected_dice.duplicate()})
			selected_dice.clear())
		reroll.disabled = selected_dice.is_empty() or _hero().get("ready", false)
		reroll.tooltip_text = "Click a die to mark it for the single reroll this stake allows."
	else:
		_label(actions, "Your one reroll is spent.", 14, MUTED)
	_button(actions, "Settle  ·  take %d ore" % payout, func(): selected_dice.clear(); _command("SettleWager", {}), true).disabled = _hero().get("ready", false)
	_wager_table(parent, pattern)

func _wager_hand(parent: Node, dice: Array, hand: Array, selectable: bool) -> void:
	var row := _hbox(parent, 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(hand.size()):
		var roll: Dictionary = hand[index]
		var die: Dictionary = {}
		for dealt in dice:
			if str(dealt.get("id", "")) == str(roll.get("die_id", "")): die = dealt
		if die.is_empty(): continue
		var id := str(die.id)
		var selected := selectable and selected_dice.has(id)
		var slot := _vbox(row, 3)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tray := PanelContainer.new()
		tray.add_theme_stylebox_override("panel", UiKit.panel_box(
			Color("3d3521") if selected else Color("1a2338"),
			Color("15120b") if selected else Color("0c121e"),
			GOLD if selected else Color("2a3752"), 10, 4, 2.0 if selected else 1.2, 0.28))
		slot.add_child(tray)
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(84, 84)
		tray.add_child(stack)
		var view := _die_view("wager:" + id)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(view)
		view.configure(die, roll, selected, false, GOLD if selected else BLUE)
		if selectable:
			var button := Button.new()
			button.flat = true
			button.toggle_mode = true
			button.button_pressed = selected
			button.disabled = _hero().get("ready", false)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.set_meta("focus_tag", "wager_" + str(index))
			button.pressed.connect(func(): _play_sound(click_sound); _toggle_die(id))
			button.tooltip_text = "%s · rolled %d\nClick to mark it for the reroll." % [_die_name(die), int(roll.get("value", 0))]
			stack.add_child(button)
		var caption := _label(slot, "REROLL" if selected else "KEEP", 10, GOLD if selected else MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _wager_table(parent: Node, showing: String) -> void:
	## The paytable is the room's whole teaching job: it names the same patterns the gems
	## read, so an evening at the tables is practice for the next fight.
	var box := _panel(parent, PANEL_LOW, LINE, 12)
	_label(box, "THE TABLE PAYS", 11, GOLD)
	for entry in EngineScript.WAGER_TABLE:
		var here: bool = str(entry.key) == showing
		var row := _hbox(box, 8)
		_label(row, "▸" if here else " ", 13, GOLD)
		_label(row, str(entry.name), 13, PAPER if here else MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(row, "%d×" % int(entry.multiplier), 13, GOLD if int(entry.multiplier) > 1 else MUTED)
	_label(box, "A multiplier includes your stake: 1× returns it, 0× loses it.", 12, MUTED, true)

## --- The Crucible -------------------------------------------------------------

func _crucible(parent: Node) -> void:
	var used: bool = snapshot.get("room", {}).get("services", {}).get(controlled_id, false)
	_label(parent, "Carat multiplies everything a gem does, and this is the only place it moves. Cut and Clarity belong to the Lapidary.", 15, MUTED, true)
	if used:
		_label(parent, "The fire is spent. Mark Done when your equipment is ready.", 16, GREEN, true)
		_button(parent, "Manage equipment", _show_inventory)
		return
	_label(parent, "Temper pays in HP. Fuse pays in an unequipped gem you found down here, and a richer gem feeds more.", 14, GOLD, true)
	var hero: Dictionary = _hero()
	var spare := 0
	for gem in hero.get("gems", []):
		if not gem.get("equipped", false) and gem.get("found", false): spare += 1
	for gem in hero.get("gems", []):
		var carat := int(gem.get("carat", 1))
		var panel := _panel(parent)
		_gem_details(panel, gem)
		if carat >= 24:
			_label(panel, "Already at the highest Carat.", 13, MUTED)
			continue
		var cost := 4 + int(floor(float(carat) / 2.0))
		var row := _hbox(panel, 10)
		_label(row, "Carat %d → %d" % [carat, mini(24, carat + int(EngineScript.CRUCIBLE_CARAT_GAIN))], 15, GREEN)
		var temper := _button(row, "Temper  ·  %d HP" % cost, func(): _crucible_preview(gem, "temper", {}))
		temper.disabled = int(hero.get("hp", 0)) <= cost or hero.get("ready", false)
		temper.tooltip_text = "Costs %d HP and rises with the gem's Carat. You must survive it." % cost
		var usable := spare - (1 if not gem.get("equipped", false) and gem.get("found", false) else 0)
		var fuse := _button(row, "Fuse a found gem…", func(): _crucible_fuel(gem))
		fuse.disabled = usable <= 0 or hero.get("ready", false)
		if usable <= 0: fuse.tooltip_text = "You hold no other unequipped found gem to consume. Loadout gems go home regardless, so they cannot feed the fire."

func _crucible_fuel(target: Dictionary) -> void:
	var box := _modal("Feed the fire for " + _gem_name(target))
	_label(box, "The consumed gem is destroyed. It gives %d Carat, plus one for every %d Carat of its own." % [int(EngineScript.CRUCIBLE_CARAT_GAIN), int(EngineScript.CRUCIBLE_FUSE_DIVISOR)], 14, MUTED, true)
	var any := false
	for gem in _hero().get("gems", []):
		if gem.get("equipped", false) or not gem.get("found", false) or str(gem.id) == str(target.id): continue
		any = true
		var gain: int = int(EngineScript.CRUCIBLE_CARAT_GAIN) + int(floor(float(int(gem.get("carat", 1))) / float(int(EngineScript.CRUCIBLE_FUSE_DIVISOR))))
		var panel := _panel(box)
		_gem_details(panel, gem)
		_button(panel, "Consume this  ·  +%d Carat" % gain, func(): _close_overlay(); _crucible_preview(target, "fuse", gem))
	if not any:
		_label(box, "You hold no unequipped gem found on this expedition.", 15, RED, true)

func _crucible_preview(target: Dictionary, method: String, fuel: Dictionary) -> void:
	var carat := int(target.get("carat", 1))
	var gain: int = int(EngineScript.CRUCIBLE_CARAT_GAIN)
	if method == "fuse": gain += int(floor(float(int(fuel.get("carat", 1))) / float(int(EngineScript.CRUCIBLE_FUSE_DIVISOR))))
	var improved := target.duplicate(true)
	improved.carat = mini(24, carat + gain)
	var box := _modal(("Temper " if method == "temper" else "Fuse ") + _gem_name(target))
	_label(box, "BEFORE", 11, GOLD)
	_gem_title_row(box, target, 14, MUTED)
	_formula_rows(box, target, -1, 13)
	_label(box, _gem_summary(target), 13, MUTED, true)
	UiKit.rule(box)
	_label(box, "AFTER", 11, GREEN)
	_gem_title_row(box, improved, 14, GREEN)
	_formula_rows(box, improved, -1, 13)
	_label(box, _gem_summary(improved), 13, PAPER, true)
	_label(box, _preview_basis() + " This compares gem properties, not a prediction of future rolls.", 12, MUTED, true)
	if method == "temper":
		var cost := 4 + int(floor(float(carat) / 2.0))
		_label(box, "Cost: %d HP, leaving you at %d." % [cost, int(_hero().get("hp", 0)) - cost], 14, RED, true)
		_button(box, "Temper  ·  %d HP" % cost, func(): _close_overlay(); _command("TemperGem", {"gem_id": target.id, "method": "temper"}), true)
	else:
		_label(box, "Cost: %s is destroyed." % _gem_name(fuel), 14, RED, true)
		_button(box, "Fuse  ·  destroy " + _gem_name(fuel), func(): _close_overlay(); _command("TemperGem", {"gem_id": target.id, "method": "fuse", "fuel_id": fuel.id}), true)

func _shop(parent: Node) -> void:
	_label(parent, "Personal stock • Paid in ore • Sell found gems and reserve dice from your equipment", 14, MUTED, true)
	var stock: Dictionary = snapshot.get("shop", {}).get(controlled_id, {})
	var loupe: Dictionary = stock.get("loupe", {})
	if not loupe.is_empty():
		var loupe_panel := _panel(parent)
		var loupe_row := _hbox(loupe_panel, 12)
		UiKit.icon(loupe_row, Forge.prop("loupe"), 48).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var loupe_text := _vbox(loupe_row, 3)
		loupe_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(loupe_text, "A jeweller’s loupe", 18, BLUE)
		_label(loupe_text, "Appraise one stone from your haul, anywhere outside a fight. An appraised find can be equipped.", 13, MUTED, true)
		var loupe_short := int(loupe.get("price", 0)) - int(_hero().get("ore", 0))
		var buy_loupe := _button(loupe_row, "Sold" if loupe.get("claimed", false) else ("Need %d more ore" % loupe_short if loupe_short > 0 else "Buy  ·  %d ore" % int(loupe.get("price", 0))), func(): _command("BuyLoupe", {}), true)
		buy_loupe.disabled = loupe.get("claimed", false) or _hero().get("ready", false) or loupe_short > 0
	for offer in stock.get("gems", []):
		var gem: Dictionary = offer.get("gem", {})
		var panel := _panel(parent)
		var row := _hbox(panel)
		_gem_details(row, gem)
		var short := int(offer.get("price", 0)) - int(_hero().get("ore", 0))
		var buy := _button(row, "Sold" if offer.get("claimed", false) else ("Need %d more ore" % short if short > 0 else "Buy  ·  %d ore" % int(offer.get("price", 0))), func(): _command("BuyGem", {"offer_id": offer.id}), true)
		buy.disabled = offer.get("claimed", false) or _hero().get("ready", false) or short > 0
		if short > 0: buy.tooltip_text = "This gem costs %d ore and you carry %d. Sell a found gem from your equipment to close the gap." % [int(offer.get("price", 0)), int(_hero().get("ore", 0))]
	for offer in stock.get("dice", []):
		var die: Dictionary = offer.get("die", {})
		var panel := _panel(parent)
		var row := _hbox(panel, 12)
		_die_chip(row, "preview:stock:" + str(offer.get("id", die.get("id", ""))), die, 76)
		var info := _vbox(row)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(info, _die_name(die), 18, BLUE)
		_label(info, "Faces: " + _faces_text(die), 13, MUTED, true)
		var die_short := int(offer.get("price", 0)) - int(_hero().get("ore", 0))
		var full: bool = _hero().get("reserve_dice", []).size() >= 5
		var caption := "Sold" if offer.get("claimed", false) else ("Reserve full" if full else ("Need %d more ore" % die_short if die_short > 0 else "Buy die  ·  %d ore" % int(offer.get("price", 0))))
		var die_buy := _button(row, caption, func(): _command("BuyDie", {"offer_id": offer.id}), true)
		die_buy.disabled = offer.get("claimed", false) or _hero().get("ready", false) or die_short > 0 or full
		if full: die_buy.tooltip_text = "Your five reserve die slots are full. Sell one from your inventory first."
		elif die_short > 0: die_buy.tooltip_text = "This die costs %d ore and you carry %d." % [int(offer.get("price", 0)), int(_hero().get("ore", 0))]
	_button(parent, "Inventory / sell items", _show_inventory)

func _workshop(parent: Node) -> void:
	_label(parent, "One service per hero per visit · 5 ore · Tinker’s Belt covers the first service of the expedition", 14, MUTED, true)
	_label(parent, "Changing shape restores standard faces and removes all engravings. Engraving changes one physical face.", 13, GOLD, true)
	if snapshot.get("room", {}).get("services", {}).get(controlled_id, false):
		_label(parent, "Your workshop service is complete.", 16, GREEN)
		return
	var shapes := ["D4", "D6", "D8", "D10", "D12", "D20"]
	for die in _hero().get("dice", []) + _hero().get("reserve_dice", []):
		var panel := _panel(parent)
		var top := _hbox(panel, 12)
		_die_chip(top, "preview:bench:" + str(die.id), die, 76)
		var facts := _vbox(top, 4)
		facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(facts, _die_name(die), 18, BLUE)
		_label(facts, "Faces: " + _faces_text(die), 14, MUTED, true)
		var row := _hbox(panel)
		var shape_i := shapes.find(str(die.get("shape", "D6")))
		for offset in [-1, 1]:
			var next: int = shape_i + int(offset)
			if next >= 0 and next < shapes.size():
				_button(row, "Replace with " + shapes[next], func(): _confirm_shape(die, shapes[next]))
		_button(row, "Engrave a face…", func(): _engrave(die))

func _confirm_shape(die: Dictionary, shape: String) -> void:
	var box := _modal("Replace " + str(die.get("shape", "die")) + " with " + shape)
	_label(box, "Before: " + _faces_text(die), 15, MUTED, true)
	var faces: Array = []
	for n in range(1, int(shape.trim_prefix("D")) + 1): faces.append(str(n))
	_label(box, "After: " + ", ".join(faces), 15, GREEN, true)
	_label(box, "All previous face engravings are removed. Price: 5 ore, or the available Tinker’s Belt service.", 14, GOLD, true)
	_button(box, "Confirm replacement", func(): _close_overlay(); _command("ModifyDie", {"die_id": die.id, "service": "shape", "shape": shape}), true)

func _engrave(die: Dictionary) -> void:
	var box := _modal("Engrave " + _die_name(die))
	_label(box, "Select one face and its new value. Every physical face remains equally likely.", 15, MUTED, true)
	var face_choice := OptionButton.new()
	var faces: Array = die.get("faces", [])
	for i in range(faces.size()):
		var face = faces[i]
		face_choice.add_item("Face %d · currently %s" % [i + 1, str(face.get("value", 0) if face is Dictionary else face)])
	box.add_child(face_choice)
	var value := SpinBox.new()
	value.min_value = 1
	value.max_value = int(str(die.get("shape", "D6")).trim_prefix("D"))
	value.step = 1
	value.value = 1
	box.add_child(value)
	_label(box, "Price: 5 ore, or an available Tinker’s Belt service. One service per visit.", 13, GOLD, true)
	_button(box, "Confirm engraving", func():
		var selected := face_choice.selected
		var new_value := int(value.value)
		_close_overlay()
		_command("ModifyDie", {"die_id": die.id, "service": "face", "face_index": selected, "value": new_value}), true)

func _lapidary(parent: Node) -> void:
	var haul: Array = _hero().get("haul", [])
	if not haul.is_empty():
		_label(parent, "APPRAISE YOUR STONES  ·  %d ORE EACH" % int(EngineScript.APPRAISE_PRICE), 12, GOLD)
		for stone in haul:
			var stone_panel := _panel(parent)
			var stone_row := _hbox(stone_panel)
			_gem_details(stone_row, stone)
			var appraise := _button(stone_row, "Appraise  ·  %d ore" % int(EngineScript.APPRAISE_PRICE), func(): _command("AppraiseGem", {"gem_id": stone.id, "method": "lapidary"}), true)
			appraise.disabled = int(_hero().get("ore", 0)) < int(EngineScript.APPRAISE_PRICE) or _hero().get("ready", false)
		UiKit.rule(parent)
	_label(parent, "Improve one gem per visit. Cut and Clarity cost 5 × the new rank in ore. Upgrades to your loadout last only for this expedition; upgrades to a gem you found stay with it when it comes home.", 14, MUTED, true)
	for gem in _hero().get("gems", []):
		var panel := _panel(parent)
		_gem_details(panel, gem)
		var row := _hbox(panel)
		for property in ["cut", "clarity"]:
			var rank := int(gem.get(property, 1))
			var b := _button(row, "%s %d → %d · %d ore" % [property.capitalize(), rank, mini(5, rank + 1), 5 * (rank + 1)], func(): _upgrade_preview(gem, property))
			b.disabled = rank >= 5 or _hero().get("ready", false) or snapshot.get("room", {}).get("services", {}).get(controlled_id, false)

func _upgrade_preview(gem: Dictionary, property: String) -> void:
	var box := _modal("Improve " + _gem_name(gem))
	var improved := gem.duplicate(true)
	improved[property] = int(gem.get(property, 1)) + 1
	_label(box, "BEFORE", 11, GOLD)
	_gem_title_row(box, gem, 14, MUTED)
	_formula_rows(box, gem, -1, 13)
	_label(box, _gem_summary(gem), 13, MUTED, true)
	UiKit.rule(box)
	_label(box, "AFTER", 11, GREEN)
	_gem_title_row(box, improved, 14, GREEN)
	_formula_rows(box, improved, -1, 13)
	_label(box, _gem_summary(improved), 13, PAPER, true)
	_label(box, _preview_basis() + " This compares gem properties, not a prediction of future rolls. Changes to dice will change future probabilities.", 12, MUTED, true)
	var cost := int(improved[property]) * 5
	_button(box, "Improve %s · %d ore" % [property.capitalize(), cost], func(): _close_overlay(); _command("UpgradeGem", {"gem_id": gem.id, "property": property}), true).disabled = int(_hero().get("ore", 0)) < cost

func _event(parent: Node) -> void:
	if snapshot.get("room", {}).get("services", {}).get(controlled_id, false):
		_label(parent, "Your event choice is settled. Mark Done when your equipment is ready.", 16, GREEN, true)
		return
	var event: Dictionary = snapshot.get("event", {})
	var key := str(event.get("key", "ABANDONED_CACHE"))
	var options: Array = {
		"ABANDONED_CACHE": ["Take 6 ore", "Lose 8 HP for the shown gem (+2 Carat). You must have more than 8 HP."],
		"FIELD_MEDIC": ["Take 4 ore", "Pay 8 ore to heal %d HP" % int(ceil(float(_hero().get("max_hp", 0)) * 0.2))],
		"ECHO_SHRINE": ["Take 5 ore", "Replace an owned D6 with a Paired, Odd, or Even D6. Current engravings are lost."],
		"JEWEL_BROKER": ["Take 4 ore", "Trade one gem you found down here — appraised or not — for one of the offers below."],
		"STILL_POOL": ["Take 4 ore", "Sit by the water a while. The tremors settle by %d%%." % int(EngineScript.STILL_POOL_CALM / 10)]
	}.get(key, ["Take ore", "Choose the offered trade"])
	_label(parent, str(options[0]), 18, GOLD, true)
	_button(parent, "Accept ore", func(): _command("EventChoice", {"option": "a"}))
	_label(parent, str(options[1]), 16, MUTED, true)
	var offers: Array = event.get("offers", {}).get(controlled_id, [])
	for offer in offers:
		var gem: Dictionary = offer.get("gem", offer)
		var panel := _panel(parent)
		_gem_details(panel, gem)
		if key == "JEWEL_BROKER":
			for owned in _hero().get("gems", []) + _hero().get("haul", []):
				if not owned.get("equipped", false) and owned.get("found", false):
					_button(panel, "Trade " + _gem_name(owned) + " for this", func(): _command("EventChoice", {"option": "b", "gem_id": owned.id, "offer_id": offer.get("id", gem.get("id", ""))}))
	if key == "ECHO_SHRINE":
		for die in _hero().get("dice", []) + _hero().get("reserve_dice", []):
			if die.get("shape") != "D6": continue
			var row := _hbox(parent)
			_label(row, _die_name(die) + " (" + _faces_text(die) + ")", 13, BLUE, true)
			for variant in ["PAIRED_D6", "ODD_D6", "EVEN_D6"]:
				var b := _button(row, variant.trim_suffix("_D6").capitalize(), func(): _command("EventChoice", {"option": "b", "die_id": die.id, "variant": variant}))
				b.tooltip_text = "New faces: " + _join_values(Catalog.DICE.get(variant, {}).get("faces", [])) + "\nPrevious engraving is lost."
	elif key != "JEWEL_BROKER":
		_button(parent, "Accept the trade", func(): _command("EventChoice", {"option": "b"}), true)
	_button(parent, "Leave without a transaction", func(): _command("EventChoice", {"option": "leave"}))

func _mine_vote(parent: Node) -> void:
	_label(parent, "Choose a vein.", 30, GOLD)
	_label(parent, "The party chooses together. Mining is automatic: fixed energy, round-robin hits, shared ore, and a draft of unappraised stones." if _party_choice() else "Mining is automatic once you choose: fixed energy, round-robin hits, and a pick of unappraised stones.", 15, MUTED, true)
	var row := _hbox(parent)
	for key in ["coin", "crystal"]:
		var box := _panel(row)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(box, "Coin Vein" if key == "coin" else "Crystal Vein", 24, GOLD if key == "coin" else BLUE)
		_label(box, "More short rocks and more ore." if key == "coin" else "More work per rock, with more stone-bearing rocks.", 14, MUTED, true)
		_label(box, "Small / Medium / Large / Gold / Shiny\n4 / 4 / 2 / 2 / 0" if key == "coin" else "Small / Medium / Large / Gold / Shiny\n1 / 3 / 4 / 0 / 2", 13, PAPER, true)
		_label(box, "These are rock weights, not a guaranteed yield.", 12, MUTED, true)
		_button(box, ("Vote for " if _party_choice() else "Work the ") + key.capitalize(), func(): _command("VoteVein", {"vein": key}), true)
	for hero in snapshot.get("heroes", []):
		var energy := 10
		for relic in hero.get("relics", []):
			if relic.get("key") == "MINERS_LANTERN" and relic.get("equipped", false): energy += 2
		if int(hero.get("hp", 0)) <= 0: energy = 0
		_label(parent, "%s · %d energy" % [str(hero.get("player_name", hero.get("name", "Hero"))), energy], 14, GREEN)

func _mine_draft(parent: Node) -> void:
	var mine: Dictionary = snapshot.get("mine", {})
	_label(parent, "The mine’s yield", 28, GOLD)
	_label(parent, "Ore found: %s · Divided among every hero. The remainder rotates by party seat." % str(mine.get("ore", 0)), 15, GREEN, true)
	var rocks: Array = mine.get("rocks", [])
	if not rocks.is_empty():
		var row := HFlowContainer.new()
		parent.add_child(row)
		for rock in rocks:
			_label(row, "%s  %s   " % [str(rock.get("name", rock.get("kind", rock.get("key", "Rock")))), "✓" if rock.get("broken", false) else "◇"], 12, GREEN if rock.get("broken", false) else MUTED)
	mine_playback_label = _label(parent, "", 14, BLUE, true)
	_button(parent, "Skip playback  [F]", _skip_playback)
	var pool: Array = mine.get("pool", [])
	if pool.is_empty():
		_label(parent, "No stones remain. Even an empty result completes the visit.", 16, MUTED, true)
		_ready_button(parent)
		return
	var picker := str(mine.get("picker_id", ""))
	_label(parent, "Next pick: " + _unit_name(picker), 18, GOLD)
	for index in range(pool.size()):
		var claim: Dictionary = pool[index]
		var panel := _panel(parent)
		reveal.show(panel.get_parent(), "draft:%s:%s" % [str(snapshot.get("room", {}).get("id", "")), str(claim.get("claim_id", ""))], 0.15 * index, "pop")
		_gem_details(panel, claim.get("gem", {}))
		_button(panel, "Take this stone", func(): _command("DraftGem", {"claim_id": claim.claim_id}), true).disabled = picker != controlled_id

func _summary(parent: Node) -> void:
	_apply_expedition_result()
	if _appraisal_pending():
		_appraisal_screen(parent)
	else:
		_statistics_screen(parent)

func _appraisal_pending() -> bool:
	## True while this player's haul is still on the table, unless they have moved on from it.
	var result: Dictionary = snapshot.get("results", {}).get(_local_player(), {})
	var pending: Dictionary = _profile().get("pending_return", {})
	return return_stage == "table" and not result.is_empty() and str(pending.get("result_id", "")) == str(result.get("result_id", "")) and not pending.get("gems", []).is_empty()

func _appraisal_screen(parent: Node) -> void:
	var outcome := str(snapshot.get("outcome", ""))
	var pending: Dictionary = _profile().get("pending_return", {})
	var gems: Array = pending.get("gems", [])
	var undecided: Array = gems.filter(func(entry: Dictionary) -> bool: return str(entry.get("decision", "")).is_empty())
	var head := _hbox(parent, 12)
	var titles := _vbox(head, 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(titles, {"extracted": "Back in daylight.", "fallen": "What survived the fall.", "conquered": "The mine is quiet."}.get(outcome, "The appraisal table."), 30, GOLD)
	_label(titles, "Every stone is appraised on the table. Click one of yours to hold it up to the light, then keep it or sell it. Keeping a gem you already own sells the old one.", 14, MUTED, true)
	var purse := _vbox(head, 4)
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.chip(purse, "%d GOLD" % int(_profile().get("gold", 0)), GOLD)
	UiKit.chip(purse, "%d OF %d TO JUDGE" % [undecided.size(), gems.size()], VIOLET if not undecided.is_empty() else GREEN)
	var body := _hbox(parent, 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table := _appraisal_table()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(Color("1a130c"), Color("0a0705"), Color("5a4026"), 12, 4, 1.4, 0.1))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(frame)
	frame.add_child(table)
	if appraising.is_empty() or not undecided.any(func(entry: Dictionary) -> bool: return str(entry.id) == appraising):
		appraising = str(undecided[0].id) if not undecided.is_empty() else ""
	table.select(appraising, reveal.begin("appraise:" + appraising) if not appraising.is_empty() else 0.0)
	var side_scroll := _scroll(body)
	side_scroll.custom_minimum_size.x = 400
	side_scroll.size_flags_horizontal = 0
	var side := _vbox(side_scroll, 10)
	var entry: Dictionary = {}
	for gem in gems:
		if str(gem.id) == appraising: entry = gem
	if entry.is_empty():
		_label(side, "Every stone has been judged.", 20, GREEN, true)
		_label(side, "You earned %d gold at the table." % return_gold, 15, GOLD, true)
	else:
		_appraisal_sheet(side, entry)
	UiKit.rule(side)
	var actions := _hbox(side, 8)
	if not undecided.is_empty():
		_button(actions, "Sell the rest  ·  %d gold" % undecided.reduce(func(total: int, gem: Dictionary) -> int: return total + Profile.sell_value(gem), 0), _confirm_sell_rest)
	_button(actions, "Done  →" if undecided.is_empty() else "Skip to the numbers", _leave_table, undecided.is_empty())

func _appraisal_table() -> Control:
	if not is_instance_valid(appraisal_view):
		appraisal_view = AppraisalTable.new()
		# Clicking the stone already under the loupe hurries the reading along.
		appraisal_view.gem_selected.connect(func(id: String):
			if id == appraising: reveal.hurry()
			appraising = id
			_queue_render())
		appraisal_view.clock = reveal.now
		appraisal_view.beat = APPRAISE_BEAT
	appraisal_view.reduced_motion = bool(settings.reduced_motion)
	var areas: Array = []
	var decisions: Dictionary = {}
	var pending: Dictionary = _profile().get("pending_return", {})
	for hero in snapshot.get("heroes", []):
		var id := str(hero.get("id", ""))
		var local := id == _local_player()
		var gems: Array = pending.get("gems", []) if local else snapshot.get("results", {}).get(id, {}).get("haul", [])
		if local:
			for gem in gems:
				if not str(gem.get("decision", "")).is_empty(): decisions[str(gem.id)] = str(gem.decision)
		areas.append({"player_id": id, "name": str(hero.get("player_name", hero.get("name", "Hero"))), "local": local,
			"color": Color(str(Catalog.HEROES.get(str(hero.get("key", "")), {}).get("color", "76b6ff"))), "gems": gems})
	appraisal_view.configure(areas, decisions)
	return appraisal_view

func _appraisal_sheet(parent: Node, entry: Dictionary) -> void:
	## Picking a stone up does not tell you what it is. It is turned under the loupe for a
	## moment — only what the eye can see — and then its name lands, its rarity with it, and
	## the rest of the sheet follows line by line. The verdict buttons wait for the reading.
	var key := "appraise:" + str(entry.get("id", ""))
	var definition: Dictionary = Catalog.SKILLS.get(str(entry.get("key", "")), {})
	var rarity := int(definition.get("rarity", 1))
	var named: bool = reveal.reached(key, APPRAISE_BEAT)
	reveal.cue(key, APPRAISE_BEAT, _sound("flourish" if rarity >= 3 else "sparkle"))
	if not named:
		_label(parent, "Under the loupe…", 28, MUTED)
		_label(parent, "Unappraised %s stone" % str(Catalog.color_definition(str(entry.get("key", ""))).get("name", "")).to_lower(), 16, _gem_color(entry))
		_label(parent, _stone_words(_sealed_copy(entry)), 15, PAPER, true)
		_label(parent, "Click anywhere to hurry the jeweller along.", 12, MUTED, true)
		return
	reveal.show(_label(parent, _gem_name(entry), 28, _gem_color(entry)), key, APPRAISE_BEAT, "stamp")
	var chips := _hbox(parent, 6)
	UiKit.chip(chips, ["", "COMMON", "UNCOMMON", "RARE", "LEGENDARY"][clampi(rarity, 1, 4)], [MUTED, MUTED, GREEN, BLUE, AMBER][clampi(rarity, 1, 4)])
	UiKit.chip(chips, str(Catalog.color_definition(str(entry.get("key", ""))).get("name", "")).to_upper(), _gem_color(entry))
	reveal.show(chips, key, APPRAISE_BEAT + 0.2, "pop")
	reveal.show(_gem_title_row(parent, entry, 16, PAPER, false), key, APPRAISE_BEAT + 0.35, "fade")
	reveal.show(_label(parent, str(definition.get("trigger", "")), 14, GREEN, true), key, APPRAISE_BEAT + 0.45, "fade")
	var formula := _vbox(parent, 6)
	_formula_rows(formula, entry, -1, 14)
	reveal.show(formula, key, APPRAISE_BEAT + 0.55, "fade")
	UiKit.rule(parent)
	var value := Profile.sell_value(entry)
	var owned: Dictionary = _profile().get("collection", {}).get(str(entry.get("key", "")), {})
	var verdict_at := APPRAISE_BEAT + 0.75
	if owned.is_empty():
		reveal.show(_label(parent, "New to your collection! Keeping it adds it, and it takes an open socket if your hero has one.", 14, BLUE, true), key, verdict_at, "stamp")
	else:
		_label(parent, "YOU ALREADY OWN ONE", 11, GOLD)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 14)
		parent.add_child(grid)
		for header in ["", "Yours", "This", ""]:
			_label(grid, header, 11, MUTED)
		var properties := ["carat", "cut", "clarity"]
		for index in range(properties.size()):
			var property: String = properties[index]
			var mine := int(owned.get(property, 1))
			var theirs := int(entry.get(property, 1))
			var at := verdict_at + 0.12 * index
			reveal.show(_label(grid, property.capitalize(), 14, PAPER), key, at, "fade")
			reveal.show(_label(grid, str(mine), 14, MUTED), key, at, "fade")
			reveal.show(_label(grid, str(theirs), 14, PAPER), key, at, "fade")
			reveal.show(_label(grid, ("▲ %d" % (theirs - mine)) if theirs > mine else (("▼ %d" % (mine - theirs)) if theirs < mine else "="), 14, GREEN if theirs > mine else (RED if theirs < mine else MUTED)), key, at + 0.06, "stamp")
		var difference := value - Profile.sell_value(owned)
		reveal.show(_label(parent, "Worth %s%d gold against yours." % ["" if difference < 0 else "+", difference], 14, GREEN if difference > 0 else AMBER, true), key, verdict_at + 0.4, "fade")
	var price := _label(parent, "Sells for %d gold." % value, 16, GOLD)
	reveal.count(price, key, verdict_at + 0.3, value, "Sells for %d gold.")
	var row := _hbox(parent, 10)
	var decided_at := verdict_at + 0.6
	var ready: bool = reveal.reached(key, decided_at)
	_button(row, "Keep" if owned.is_empty() else "Keep  ·  sell yours for %d" % Profile.sell_value(owned), func(): _decide_return(str(entry.id), true), true).disabled = not ready
	_button(row, "Sell  ·  %d gold" % value, func(): _decide_return(str(entry.id), false)).disabled = not ready
	reveal.show(row, key, decided_at, "pop")

func _sealed_copy(gem: Dictionary) -> Dictionary:
	var copy := gem.duplicate()
	copy["appraised"] = false
	return copy

func _confirm_sell_rest() -> void:
	var box := _modal("Sell every stone left on the table?")
	var undecided: Array = _profile().get("pending_return", {}).get("gems", []).filter(func(entry: Dictionary) -> bool: return str(entry.get("decision", "")).is_empty())
	for entry in undecided:
		_label(box, "%s  ·  C%d K%d L%d  ·  %d gold" % [_gem_name(entry), int(entry.carat), int(entry.cut), int(entry.clarity), Profile.sell_value(entry)], 14, PAPER, true)
	_button(box, "Sell them all", func(): _close_overlay(); _leave_table(), true)
	_button(box, "Keep looking", _close_overlay)

func _leave_table() -> void:
	var outcome: Dictionary = profile_store.transact(func(profile: Dictionary) -> Dictionary: return Profile.finish_return(profile))
	return_gold += int(outcome.get("gold", 0))
	return_stage = "stats"
	appraising = ""
	_queue_render()

func _statistics_screen(parent: Node) -> void:
	var outcome := str(snapshot.get("outcome", ""))
	var mine: Dictionary = Catalog.mine_definition(str(snapshot.get("mine_id", "")))
	reveal.show(_label(parent, {"extracted": "BACK IN DAYLIGHT", "fallen": "THE EXPEDITION FALLS", "conquered": "THE MINE IS QUIET"}.get(outcome, "THE EXPEDITION ENDS"), 34, GOLD), "stats:" + str(snapshot.get("run_id", "")), 0.0, "stamp")
	_label(parent, "%s  ·  deepest layer %d  ·  tremors %d%%  ·  seed %s" % [str(mine.get("name", "The mine")), int(snapshot.get("deepest", 0)), roundi(float(snapshot.get("tremor", 0)) / 10.0), str(snapshot.get("seed", ""))], 14, BLUE, true)
	for mine_id in last_unlocked:
		reveal.show(_label(parent, "New mine unlocked: %s" % str(Catalog.mine_definition(mine_id).get("name", mine_id)), 20, GREEN, true), "stats:" + str(snapshot.get("run_id", "")), 2.0, "stamp")
		reveal.cue("stats:" + str(snapshot.get("run_id", "")), 2.0, _sound("fanfare"))
	if not last_completed.is_empty():
		_label(parent, "%d commission%s complete — claim %s at the board." % [last_completed.size(), "" if last_completed.size() == 1 else "s", "it" if last_completed.size() == 1 else "them"], 16, GREEN, true)
	if return_gold > 0:
		_label(parent, "The table paid you %d gold. Your purse holds %d." % [return_gold, int(_profile().get("gold", 0))], 16, GOLD, true)
	var heroes: Array = snapshot.get("heroes", [])
	var stats: Dictionary = snapshot.get("statistics", {}).get("heroes", {})
	var results: Dictionary = snapshot.get("results", {})
	var rows: Array = [
		["Damage dealt", func(id: String) -> int: return int(stats.get(id, {}).get("damage_dealt", 0))],
		["Final blows", func(id: String) -> int: return int(stats.get(id, {}).get("final_blows", 0))],
		["Block gained", func(id: String) -> int: return int(stats.get(id, {}).get("block_gained", 0))],
		["Healing", func(id: String) -> int: return int(stats.get(id, {}).get("healing", 0))],
		["HP lost", func(id: String) -> int: return int(stats.get(id, {}).get("hp_lost", 0))],
		["Ore earned", func(id: String) -> int: return int(stats.get(id, {}).get("ore_earned", 0))],
		["Stones found", func(id: String) -> int: return int(stats.get(id, {}).get("gems_found", 0))],
		["Brought home", func(id: String) -> int: return results.get(id, {}).get("haul", []).size()],
		["Haul value (gold)", func(id: String) -> int: return results.get(id, {}).get("haul", []).reduce(func(total: int, gem: Dictionary) -> int: return total + Profile.sell_value(gem), 0)],
		["Best find (gold)", func(id: String) -> int: return results.get(id, {}).get("haul", []).reduce(func(best: int, gem: Dictionary) -> int: return maxi(best, Profile.sell_value(gem)), 0)]]
	var board := _panel(parent, PANEL, LINE, 16)
	var grid := GridContainer.new()
	grid.columns = heroes.size() + 1
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 8)
	board.add_child(grid)
	_label(grid, "", 12, MUTED)
	for hero in heroes:
		var name_cell := _vbox(grid, 2)
		UiKit.icon(name_cell, Forge.unit(str(hero.get("key", ""))), 56).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_label(name_cell, str(hero.get("player_name", hero.get("name", "Hero"))), 15, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_key := "stats:" + str(snapshot.get("run_id", ""))
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		var at := 0.3 + 0.14 * row_index
		reveal.show(_label(grid, str(row[0]), 14, MUTED), stats_key, at, "fade")
		var values: Array = heroes.map(func(hero: Dictionary) -> int: return row[1].call(str(hero.get("id", ""))))
		var best: int = values.max() if not values.is_empty() else 0
		for value in values:
			var leading: bool = heroes.size() > 1 and int(value) == best and best > 0 and str(row[0]) != "HP lost"
			var cell := _label(grid, ("★ %d" if leading else "%d") % int(value), 15, GOLD if leading else PAPER)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if leading:
				reveal.show(cell, stats_key, at + 0.1, "stamp")
			else:
				reveal.count(cell, stats_key, at, int(value))
	var buttons := _hbox(parent, 10)
	_button(buttons, "Read the combat record", _show_log)
	_button(buttons, "Back to the shop", func():
		profile_store.transact(func(profile: Dictionary) -> Dictionary: return Profile.finish_return(profile))
		_return_menu(), true)

func _local_player() -> String:
	## The seat this machine's player sits in. Hot-seat play may be steering another hero,
	## but only this player's profile is on this machine to bring a haul home to.
	var local := str(session.local_player_id) if is_instance_valid(session) else ""
	for hero in snapshot.get("heroes", []):
		if str(hero.get("id", "")) == local: return local
	return controlled_id

func _apply_expedition_result() -> void:
	## Carries this player's result into their own profile, once. The profile refuses a
	## result it has already applied, so a reconnect or a re-render can never pay twice.
	var result: Dictionary = snapshot.get("results", {}).get(_local_player(), {})
	if result.is_empty() or applied_result == str(result.get("result_id", "")):
		return
	applied_result = str(result.get("result_id", ""))
	var outcome: Dictionary = profile_store.transact(func(profile: Dictionary) -> Dictionary: return Profile.apply_result(profile, result))
	if not outcome.get("ok", false):
		_notify(str(outcome.get("error", "The haul could not be brought home.")))
		return
	last_unlocked = outcome.get("unlocked", [])
	last_completed = outcome.get("completed", [])

func _decide_return(gem_id: String, keep: bool) -> void:
	var outcome: Dictionary = profile_store.transact(func(profile: Dictionary) -> Dictionary: return Profile.decide_return_gem(profile, gem_id, keep))
	if not outcome.get("ok", false):
		_notify(str(outcome.get("error", "")))
	else:
		return_gold += int(outcome.get("gold", 0))
		if appraising == gem_id: appraising = ""
		_play_sound(sounds.get("coins") if not keep else sounds.get("thud"))
		var socketed := str(outcome.get("socketed", ""))
		if keep and not socketed.is_empty():
			_notify("Kept, and set in an open socket of %s's loadout." % str(Catalog.definitions("heroes").get(socketed, {}).get("name", socketed.capitalize())))
	_queue_render()

func _ready_button(parent: Node, waiting := true) -> Button:
	var ready: bool = _hero().get("ready", false)
	var combat := str(snapshot.get("phase", "")) == "planning"
	var text := "Unlock hand" if ready else ("Lock in hand" if combat else "Done / ready")
	var b := _button(parent, text + "  [%s]" % _binding_name("rd_ready"), func(): _command("SetReady", {"ready": not ready}), not ready)
	b.set_meta("focus_tag", "ready")
	if combat and int(_hero().get("hp", 0)) <= 0: b.disabled = true
	if waiting: _waiting_line(parent)
	return b

func _waiting_line(parent: Node) -> void:
	## A locked-in player should never have to guess whether the game is stuck or simply
	## waiting for someone. Solo play has nobody to wait for, so it says nothing.
	var heroes: Array = snapshot.get("heroes", [])
	if heroes.size() < 2: return
	var pending: Array = []
	for hero in heroes:
		if not bool(hero.get("connected", true)): continue
		if str(snapshot.get("phase", "")) == "planning" and int(hero.get("hp", 0)) <= 0: continue
		if not hero.get("ready", false): pending.append(str(hero.get("player_name", hero.get("name", "Hero"))))
	if pending.is_empty():
		_label(parent, "Everyone is ready.", 13, GREEN)
	else:
		_label(parent, "Waiting on %d of %d: %s" % [pending.size(), heroes.size(), ", ".join(pending)], 13, AMBER, true)

func _process(delta: float) -> void:
	if reveal != null:
		reveal.reduced = bool(settings.reduced_motion)
		reveal.process()
	_light_casting_socket(delta)
	if _holding_hand() and _refresh_hands():
		_queue_render()
	if is_instance_valid(mine_playback_label):
		var hits: Array = snapshot.get("mine", {}).get("events", [])
		if not hits.is_empty():
			mine_playback_timer += delta * float(settings.playback_speed)
			if settings.reduced_motion or float(settings.playback_speed) >= 100.0: mine_playback_index = hits.size()
			elif mine_playback_timer >= 0.25:
				mine_playback_index = mini(hits.size(), mine_playback_index + 1)
				mine_playback_timer = 0.0
			var step := clampi(mine_playback_index, 1, hits.size())
			var hit: Dictionary = hits[step - 1]
			mine_playback_label.text = "Hit %d/%d · %s · Rock %d/%d%s" % [step, hits.size(), _unit_name(str(hit.get("actor_id", ""))), int(hit.get("progress", 0)), int(hit.get("hits", 1)), " · BROKEN" if hit.get("broken", false) else ""]
	# The battlefield is the only audience for the event log now, so it paces playback.
	if playback_events.is_empty() or not _stage_on_screen():
		return
	if settings.reduced_motion or float(settings.playback_speed) >= 100.0:
		playback_index = playback_events.size()
	stage_view.speed = float(settings.playback_speed)
	if playback_index >= playback_events.size():
		if playback_held:
			# The last blow has been drawn, so the room that was waiting may have the screen.
			playback_held = false
			_queue_render()
		return
	playback_held = _playing_out()
	playback_timer += delta * float(settings.playback_speed)
	if playback_timer < playback_dwell:
		return
	var upcoming: Variant = playback_events[playback_index]
	var side: int = _unit_side(str(upcoming.get("actor", ""))) if upcoming is Dictionary else 0
	if side != 0 and playback_side != 0 and side != playback_side:
		# The initiative has changed hands. The side about to act is named and the field
		# is given a beat to itself, so the two halves of a turn never run together.
		playback_side = side
		playback_timer = 0.0
		playback_dwell = SIDE_CHANGE_BEAT
		stage_view.announce("THE PARTY ACTS" if side < 0 else "THE ENEMY ACTS", GOLD if side < 0 else RED)
		return
	if side != 0:
		playback_side = side
	playback_index += 1
	playback_timer = 0.0
	playback_dwell = float(stage_view.perform(upcoming)) if upcoming is Dictionary else 0.0
	if upcoming is Dictionary and str(upcoming.get("kind", "")) == "skill" \
			and str(upcoming.get("actor", "")) == controlled_id:
		casting_gem = str(upcoming.get("gem_id", ""))
		casting_age = 0.0
		casting_span = playback_dwell + 0.44
	if upcoming is Dictionary and upcoming.has("target_hp"):
		# Somebody's standing moved, or an enemy took its dice up, so the field is redrawn
		# at the point the log has reached rather than at the outcome the authority has
		# already written. A roll lands here too: it is what puts the dice on the plate and
		# lights the roster entries the throw opened.
		stage_view.sync(_stage_units(_battle_state()), bool(settings.reduced_motion),
			_room_color(str(snapshot.get("room", {}).get("kind", "battle"))), _pick_unit, _inspect_by_id)

func _light_casting_socket(delta: float) -> void:
	if casting_gem.is_empty():
		return
	var card: Variant = gem_slot_cards.get(casting_gem, null)
	if card == null or not is_instance_valid(card):
		casting_gem = ""
		return
	casting_age += delta * float(settings.playback_speed)
	var frame: Control = card
	if casting_age >= casting_span or bool(settings.reduced_motion):
		frame.scale = Vector2.ONE
		frame.modulate = Color.WHITE
		casting_gem = ""
		return
	var lift := clampf(minf(casting_age / 0.16, (casting_span - casting_age) / 0.34), 0.0, 1.0)
	frame.pivot_offset = frame.size * 0.5
	frame.scale = Vector2.ONE * (1.0 + 0.13 * lift)
	frame.modulate = Color.WHITE.lerp(Color(1.55, 1.45, 1.2, 1.0), lift)

func _unit_side(unit_id: String) -> int:
	if unit_id.is_empty():
		return 0
	var state: Dictionary = _battle_state()
	for hero in state.get("heroes", []):
		if str(hero.get("id", "")) == unit_id:
			return -1
	for enemy in state.get("enemies", []):
		if str(enemy.get("id", "")) == unit_id:
			return 1
	return 0

func _find_hero(id: String) -> Dictionary:
	for hero in snapshot.get("heroes", []):
		if str(hero.get("id", "")) == id: return hero
	return {}

func _grace_remaining(hero: Dictionary) -> int:
	for member in session.lobby.get("members", []):
		if str(member.get("player_id", "")) == str(hero.get("id", "")):
			return int(member.get("grace_remaining", 0))
	return maxi(0, 60 - int(Time.get_unix_time_from_system() - float(hero.get("disconnect_time", Time.get_unix_time_from_system()))))

func _show_inventory() -> void:
	if snapshot.is_empty(): return
	var planning := str(snapshot.get("phase", "")) == "planning"
	var can_plan := planning and int(_hero().get("hp", 0)) <= 0
	var inventory_hero: Dictionary = _hero()
	if can_plan:
		if not provisional.has(controlled_id):
			provisional[controlled_id] = _hero().duplicate(true)
			provisional_commands[controlled_id] = []
		inventory_hero = provisional[controlled_id]
	var box := _modal("%s’s equipment" % str(inventory_hero.get("player_name", inventory_hero.get("name", "Hero"))))
	var locked := (planning and not can_plan) or bool(inventory_hero.get("ready", false)) or _resolving()
	var equipped: Array = inventory_hero.get("gems", []).filter(func(gem: Dictionary) -> bool: return gem.get("equipped", false))
	var reserve: Array = inventory_hero.get("gems", []).filter(func(gem: Dictionary) -> bool: return not gem.get("equipped", false))
	var at_shop: bool = snapshot.get("room", {}).get("kind") == "shop" and snapshot.get("phase") == "support"
	var chips := _hbox(box, 8)
	UiKit.chip(chips, "%d / %d SOCKETS FILLED" % [equipped.size(), GEM_SLOTS], GOLD if equipped.size() == GEM_SLOTS else AMBER)
	UiKit.chip(chips, "%d ORE" % int(inventory_hero.get("ore", 0)), GOLD)
	UiKit.chip(chips, "%d LOUPE%s" % [int(inventory_hero.get("loupes", 0)), "" if int(inventory_hero.get("loupes", 0)) == 1 else "S"], BLUE)
	UiKit.chip(chips, "%d UNAPPRAISED" % inventory_hero.get("haul", []).size(), VIOLET)
	if can_plan:
		_label(box, "PROVISIONAL PLAN · You are downed. These edits stay local and do not change combat. Apply the plan between rooms after rally.", 14, GREEN, true)
	elif provisional_commands.get(controlled_id, []).size() > 0:
		_label(box, "Your provisional loadout is ready to review. It applies only in this between-room equipment window.", 14, GREEN, true)
		var plan_row := _hbox(box)
		_button(plan_row, "Apply planned changes", _commit_provisional, true).disabled = locked
		_button(plan_row, "Discard plan", func(): provisional.erase(controlled_id); provisional_commands.erase(controlled_id); _show_inventory())
	if locked:
		_label(box, "Equipment is frozen while fighting or ready. Everything can still be inspected.", 14, MUTED, true)
	ItemBoard.build(self, box, {
		"kind": "gem", "title": "GEM SOCKETS", "slots": GEM_SLOTS, "socketed": equipped, "reserve": reserve, "locked": locked, "edge": 62,
		"hint": "Left to right is the order they resolve. Drag to rearrange, drag between sockets and reserve to equip, double-click to set or take off.",
		"reserve_title": "RESERVE GEMS", "empty_reserve": "No spare gems. Appraised finds, treasure and merchants add gems here — and fill an open socket by themselves.",
		"art": func(gem: Dictionary, holder: Control, edge: float): _badge_into(holder, gem, edge),
		"caption": func(gem: Dictionary) -> String: return _gem_name(gem),
		"tint": func(gem: Dictionary) -> Color: return _gem_color(gem),
		"tip": func(gem: Dictionary) -> String: return _preview_text(gem),
		"pinned": func(gem: Dictionary) -> String: return "Strike always stays socketed." if str(gem.get("key", "")) == "STRIKE" else "",
		"place": func(gem: Dictionary, index: int, occupant: Dictionary): _place_gem(equipped, gem, index, occupant),
		"move": func(from: int, to: int): _move_gem(equipped, from, to),
		"remove": func(gem: Dictionary): _inventory_command("EquipGem", {"gem_id": gem.id}),
		"inspect": func(gem: Dictionary): _inspect_gem(gem),
		"extra": func(gem: Dictionary, tile_box: VBoxContainer):
			if at_shop and gem.get("found", false) and not gem.get("loadout", false):
				var sell := _button(tile_box, "Sell · %d" % (Catalog.gem_value(gem) / 2), func(): _inventory_command("SellGem", {"gem_id": gem.id}))
				sell.custom_minimum_size.y = 28
				sell.disabled = locked})
	var haul: Array = inventory_hero.get("haul", [])
	_label(box, "HAUL  ·  UNAPPRAISED STONES", 12, VIOLET)
	if haul.is_empty(): _label(box, "No unappraised stones. Rocks and fallen enemies give them up.", 13, MUTED, true)
	var stones := HFlowContainer.new()
	stones.add_theme_constant_override("h_separation", 10)
	stones.add_theme_constant_override("v_separation", 10)
	box.add_child(stones)
	for stone in haul:
		var stone_card := _panel(stones)
		stone_card.get_parent().custom_minimum_size.x = 380
		stone_card.get_parent().size_flags_horizontal = Control.SIZE_FILL
		_gem_details(stone_card, stone)
		var appraise := _button(stone_card, "Appraise with a loupe" if int(inventory_hero.get("loupes", 0)) > 0 else "Needs a loupe", func(): _inventory_command("AppraiseGem", {"gem_id": stone.id, "method": "loupe"}))
		appraise.disabled = locked or int(inventory_hero.get("loupes", 0)) < 1
		if int(inventory_hero.get("loupes", 0)) < 1: appraise.tooltip_text = "Merchants sell loupes. A Lapidary appraises for ore."
	var active_dice: Array = inventory_hero.get("dice", [])
	var spare_dice: Array = inventory_hero.get("reserve_dice", [])
	ItemBoard.build(self, box, {
		"kind": "die", "title": "ACTIVE DICE", "slots": active_dice.size(), "socketed": active_dice, "reserve": spare_dice, "locked": locked, "edge": 58,
		"hint": "All five roll every turn. Drop a reserve die onto an active one to swap them.",
		"reserve_title": "RESERVE DICE  ·  %d / 5" % spare_dice.size(), "empty_reserve": "No reserve dice. Merchants sell them.",
		"art": func(die: Dictionary, holder: Control, edge: float): _die_into(holder, die, edge),
		"caption": func(die: Dictionary) -> String: return _die_name(die),
		"tint": func(_die: Dictionary) -> Color: return BLUE,
		"tip": func(die: Dictionary) -> String: return "%s\nFaces: %s" % [_die_name(die), _faces_text(die)],
		"pinned": func(_die: Dictionary) -> String: return "Five dice are always active. Drop a reserve die onto this one to swap them.",
		"place": func(die: Dictionary, _index: int, occupant: Dictionary):
			if occupant.is_empty():
				_notify("Drop a reserve die onto the active die it should replace.")
			else:
				_inventory_command("SwapDie", {"active_id": occupant.id, "reserve_id": die.id}),
		"inspect": func(die: Dictionary): _inspect_die(die),
		"extra": func(die: Dictionary, tile_box: VBoxContainer):
			if at_shop:
				var price := int(Catalog.DICE.get(die.get("key", die.get("shape", "D6")), {}).get("price", 6)) / 2
				var sell := _button(tile_box, "Sell · %d" % price, func(): _inventory_command("SellDie", {"die_id": die.id}))
				sell.custom_minimum_size.y = 28
				sell.disabled = locked})
	var worn: Array = inventory_hero.get("relics", []).filter(func(relic: Dictionary) -> bool: return relic.get("equipped", false))
	var carried: Array = inventory_hero.get("relics", []).filter(func(relic: Dictionary) -> bool: return not relic.get("equipped", false))
	ItemBoard.build(self, box, {
		"kind": "relic", "title": "RELICS", "slots": 3, "socketed": worn, "reserve": carried, "locked": locked, "edge": 52,
		"hint": "Three can be worn at once.",
		"reserve_title": "CARRIED RELICS", "empty_reserve": "Elite and boss victories offer relics.",
		"art": func(relic: Dictionary, holder: Control, edge: float):
			UiKit.icon(holder, Forge.relic(str(relic.get("key", ""))), edge).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT),
		"caption": func(relic: Dictionary) -> String: return str(Catalog.RELICS.get(relic.get("key", ""), {}).get("name", relic.get("key", ""))),
		"tint": func(_relic: Dictionary) -> Color: return GOLD,
		"tip": func(relic: Dictionary) -> String: return "%s\n%s" % [str(Catalog.RELICS.get(relic.get("key", ""), {}).get("name", "")), str(Catalog.RELICS.get(relic.get("key", ""), {}).get("description", ""))],
		"place": func(relic: Dictionary, _index: int, occupant: Dictionary):
			if occupant.is_empty() and worn.size() >= 3:
				_notify("All three relic slots are worn. Drop it onto the relic it should replace.")
			else:
				_inventory_command("EquipRelic", {"relic_id": relic.id, "replace_id": str(occupant.get("id", ""))}),
		"remove": func(relic: Dictionary): _inventory_command("EquipRelic", {"relic_id": relic.id})})

func _badge_into(holder: Control, gem: Dictionary, edge: float) -> void:
	var badge := GemBadge.make(gem, edge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(badge)

func _die_into(holder: Control, die: Dictionary, edge: float) -> void:
	## A real solid in the tray; a flat face on the drag preview, which is not in the tree yet.
	if not holder.is_inside_tree():
		var faces: Array = die.get("faces", [])
		var top := 0
		for face in faces: top = maxi(top, int(face.get("value", 0)) if face is Dictionary else int(face))
		var flat: Control = DiceIcons.face(edge, top, DiceIcons.palette(str(die.get("key", "D6"))).body, str(die.get("shape", "D6")), true)
		holder.add_child(flat)
		return
	var view := _die_view("preview:inv:" + str(die.get("id", "")))
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(view)
	view.live = false
	view.configure(die, {}, false, false, BLUE)

func _place_gem(equipped: Array, gem: Dictionary, index: int, occupant: Dictionary) -> void:
	if not occupant.is_empty():
		_inventory_command("EquipGem", {"gem_id": gem.id, "replace_id": occupant.id})
		return
	var twin: bool = equipped.any(func(other: Dictionary) -> bool: return str(other.get("key", "")) == str(gem.get("key", "")))
	if (index < 0 or equipped.size() >= GEM_SLOTS) and not twin:
		_notify("All six sockets are full. Drop it onto the gem it should replace.")
		return
	_inventory_command("EquipGem", {"gem_id": gem.id})

func _move_gem(equipped: Array, from: int, to: int) -> void:
	## Two sockets trade stones. Order is the order they resolve in, so this is the whole of
	## rearranging a loadout.
	if from < 0 or to < 0 or from >= equipped.size() or to >= equipped.size() or from == to: return
	var ids: Array = equipped.map(func(gem: Dictionary) -> String: return str(gem.id))
	var held = ids[from]
	ids[from] = ids[to]
	ids[to] = held
	_inventory_command("ReorderGems", {"gem_ids": ids})

func _inventory_command(kind: String, payload: Dictionary) -> void:
	if str(snapshot.get("phase", "")) == "planning" and int(_hero().get("hp", 0)) <= 0:
		_plan_equipment(kind, payload)
	else:
		_command(kind, payload)
	_show_inventory.call_deferred()

func _sheet(box: Node, art: Control, art_size: Vector2, accent: Color) -> VBoxContainer:
	## Every inspect screen is one shape: a large picture on the left, the sheet beside it.
	var head := _hbox(box, 22)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(Color("18213a"), Color("0a0f1c"), Color(accent, 0.55), 14, 14, 1.6, 0.22))
	head.add_child(frame)
	art.custom_minimum_size = art_size
	frame.add_child(art)
	var body := _vbox(head, 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body

func _target_text(target: String) -> String:
	match target:
		"self": return "Yourself"
		"ally", "allies": return "Every living hero"
		"enemy":
			var chosen := str(_hero().get("preferred_target", ""))
			return ("Your preferred enemy — " + _unit_name(chosen)) if not chosen.is_empty() else "The first living enemy, until you pick one on the battlefield"
		"enemies": return "Several enemies, beginning with your preferred target"
		"revive": return "The first downed hero, otherwise every living hero"
	return target.capitalize()

func _inspect_gem(gem: Dictionary) -> void:
	if _sealed(gem):
		var sealed_box := _modal("An unappraised stone")
		var holder := Control.new()
		var stone := _gem_portrait(holder, gem, 220)
		stone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		(stone as GemView).enable_interaction()
		var facts := _sheet(sealed_box, holder, Vector2(220, 220), _gem_color(gem))
		_label(facts, "Unappraised %s stone" % str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "")).to_lower(), 24, _gem_color(gem))
		_label(facts, _stone_words(gem), 16, PAPER, true)
		_label(facts, "%s stones carry %s." % [str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "")), str(Catalog.color_definition(str(gem.get("key", ""))).get("role", "")).to_lower()], 14, MUTED, true)
		_label(facts, "Turn it in the light and judge it. A loupe or a Lapidary will tell you what it really is.", 14, GOLD, true)
		return
	var preview: Dictionary = Combat.preview(_hero(), gem, _preview_hand(), snapshot)
	var definition: Dictionary = Catalog.SKILLS.get(gem.get("key", ""), {})
	var box := _modal(_gem_name(gem))
	var portrait := Control.new()
	var icon := _gem_portrait(portrait, gem, 200)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(icon as GemView).enable_interaction()
	var body := _sheet(box, portrait, Vector2(200, 200), GOLD)
	_label(body, _gem_name(gem), 26, _gem_color(gem))
	_gem_title_row(body, gem, 16, PAPER, false)
	_label(body, "%s gem — %s." % [str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "Red")), str(Catalog.color_definition(str(gem.get("key", ""))).get("role", "Damage"))], 13, MUTED, true)
	_label(body, "REQUIRES", 11, GOLD)
	var need := _hbox(body, 10)
	_requirement_icons(need, gem, preview, 30)
	_label(body, str(definition.get("trigger", "")), 15, GREEN, true)
	_label(body, "DOES", 11, GOLD)
	_formula_rows(body, gem, int(preview.get("effective_clarity", gem.get("clarity", 1))), 15)
	UiKit.rule(body)
	_label(body, "TARGETS", 11, GOLD)
	_label(body, _target_text(str(definition.get("target", "self"))), 15, BLUE, true)
	UiKit.rule(body)
	var rolled: bool = not _preview_hand().is_empty()
	_label(body, "THIS HAND" if rolled else "NO HAND YET", 11, GOLD)
	var active: bool = preview.get("active", false) and rolled
	var verdict := "Roll a hand in a battle to see what this gem would do."
	if rolled: verdict = str(preview.get("summary", "")) if active else str(preview.get("reason", "Dormant"))
	_label(body, verdict, 17, GREEN if active else MUTED, true)
	if int(preview.get("effective_clarity", gem.get("clarity", 1))) != int(gem.get("clarity", 1)):
		_label(body, "Effective Clarity %d — a Focusing Prism is shortening the run." % int(preview.effective_clarity), 14, VIOLET, true)
	var contributors: Array = preview.get("contributing_dice", [])
	if not contributors.is_empty():
		_label(body, "CONTRIBUTING DICE", 11, GOLD)
		var row := _hbox(body, 10)
		for i in range(_hero().get("dice", []).size()):
			var die: Dictionary = _hero().dice[i]
			if not str(die.id) in contributors: continue
			var held: Dictionary = {}
			for entry in _hand_for(_hero()):
				if str(entry.get("die_id")) == str(die.id): held = entry
			var column := _vbox(row, 3)
			column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_die_chip(column, "preview:contrib:" + str(die.id), die, 64, held)
			_label(column, "SLOT %d%s" % [i + 1, "  ·  %d" % int(held.value) if held.has("value") else ""], 10, GREEN)
	_label(box, "Dice are never consumed. Each equipped gem evaluates independently in the order shown, amounts are floored once, and healing uses the recipient’s own maximum HP.", 13, MUTED, true)
	if _can_ping(): _button(box, "Ping this gem", func(): _ping("gem", str(gem.get("id", "")), _gem_name(gem)))

func _inspect_unit(unit: Dictionary) -> void:
	var id := str(unit.get("id", ""))
	var hostile := false
	for candidate in snapshot.get("enemies", []):
		if str(candidate.get("id", "")) == id: hostile = true
	var key := str(unit.get("key", "ENEMY")).to_upper()
	var downed := int(unit.get("hp", 0)) <= 0
	var box := _modal(str(unit.get("player_name", unit.get("name", "Unit"))))
	var actor := _actor_for("preview:inspect:" + id, key, -1.0 if hostile else 1.0)
	actor.show_ground = true
	actor.downed = downed
	actor.targeted = false
	actor.bob = 1.0
	var body := _sheet(box, actor, Vector2(240, 250), _unit_tint(key))
	_label(body, str(unit.get("name", "Unit")) + ("  ·  BOSS" if unit.get("boss", false) else ""), 26, GOLD)
	UiKit.meter(body, float(unit.get("hp", 0)), float(unit.get("max_hp", 1)),
		HP_LOST if downed else (HP_FOE if hostile else HP_LIVE), 22,
		"%d / %d HP" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))])
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 4)
	body.add_child(chips)
	UiKit.chip(chips, "DOWNED" if downed else ("ENEMY" if hostile else "HERO"), RED if downed else (HP_FOE if hostile else GREEN))
	if int(unit.get("block", 0)) > 0:
		UiKit.chip(chips, "BLOCK %d" % int(unit.get("block", 0)), BLUE)
	for badge in _status_badges(unit):
		UiKit.chip(chips, str(badge[0]), Color(badge[1]))
	var definition: Dictionary = Catalog.ENEMIES.get(unit.get("key", ""), Catalog.HEROES.get(unit.get("key", ""), {}))
	var description := str(definition.get("description", ""))
	if not description.is_empty():
		_label(body, description, 15, PAPER, true)
	var hand: Array = Combat.values(_hand_for(unit)) if not hostile else Combat.values(unit.get("hand", []))
	if not hand.is_empty():
		_label(body, "This turn’s hand: " + _join_values(hand), 15, GREEN, true)
	if hostile:
		# What it can reach, not what it will do: the other side does not take its dice up
		# until the party has finished spending theirs.
		var opened: Array = _projected_rolls().get(id, {}).get("opened", [])
		var roster: Array = Combat.enemy_skills(unit)
		if not roster.is_empty():
			_label(box, "CAN USE", 11, GOLD)
			var row := _hbox(box, 10)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			for action in roster:
				var open: bool = str(action.key) in opened
				var cell := _vbox(row, 3)
				cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				GemIcons.glyph(cell, GemIcons.emblem(str(action.key)), 26,
					AMBER if open else Color(AMBER, 0.4), str(action.name))
				_label(cell, str(action.name), 11, AMBER if open else MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label(box, "It rolls after the party acts; whichever of these its dice open is what lands.", 13, MUTED, true)
	var dice: Array = unit.get("dice", [])
	if not dice.is_empty():
		_label(box, "DICE  ·  RIGHT-CLICK ONE TO TURN IT", 11, GOLD)
		var row := _hbox(box, 12)
		for die in dice:
			var turned: Dictionary = {}
			for entry in unit.get("hand", []):
				if str(entry.get("die_id")) == str(die.get("id", "")): turned = entry
			var column := _vbox(row, 3)
			column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_die_chip(column, "preview:sheet:" + str(die.get("id", "")), die, 68, turned)
			_label(column, str(die.get("shape", "D6")) + ("  ·  %d" % int(turned.value) if turned.has("value") else ""), 10, BLUE)
	if unit.get("boss", false):
		_label(box, "Boss Resolve: external stun queues at most one skipped slot. After that skip, the next two slots reject external stun. Damage still applies. Poison ticks once at each living actor’s slot end.", 14, GOLD, true)
	if _can_ping(): _button(box, "Ping this " + ("enemy" if hostile else "hero"), func(): _ping("enemy" if hostile else "hero", id, str(unit.get("name", "Unit"))))

func _inspect_stage_skill(unit_id: String, entry_id: String) -> void:
	## A right-click on something carried over a combatant's head: a hero's gem opens its
	## sheet, an enemy's move says when it fires and what it does.
	var state: Dictionary = _battle_state()
	for hero in state.get("heroes", []):
		if str(hero.get("id", "")) != unit_id: continue
		for gem in hero.get("gems", []):
			if str(gem.get("id", "")) == entry_id:
				_inspect_gem(gem)
				return
	for enemy in state.get("enemies", []):
		if str(enemy.get("id", "")) == unit_id:
			_inspect_enemy_skill(enemy, entry_id)
			return

func _inspect_enemy_skill(enemy: Dictionary, key: String) -> void:
	var action_name := key.capitalize()
	for action in Combat.enemy_skills(enemy):
		if str(action.key) == key: action_name = str(action.name)
	var box := _modal("%s  ·  %s" % [str(enemy.get("name", "Enemy")), action_name])
	var art := TextureRect.new()
	art.texture = GemIcons.texture(GemIcons.emblem(key), 128)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = AMBER
	var body := _sheet(box, art, Vector2(150, 150), AMBER)
	_label(body, action_name, 26, AMBER)
	_label(body, "One of the moves %s's routine can reach." % str(enemy.get("name", "this enemy")), 14, MUTED, true)
	var when := ""
	var does := ""
	for gem in enemy.get("gems", []):
		if Catalog.canonical_key(str(gem.get("key", ""))) == key:
			when = str(Catalog.SKILLS.get(key, {}).get("trigger", ""))
			does = GemText.sentence(gem)
			_label(body, "REQUIRES", 11, GOLD)
			_requirement_icons(_hbox(body, 10), gem, Combat.preview(enemy, gem, enemy.get("hand", []), snapshot), 28)
	if when.is_empty():
		var text: Dictionary = Combat.enemy_skill_text(enemy, key)
		when = str(text.get("when", ""))
		does = str(text.get("does", ""))
	_label(body, "WHEN", 11, GOLD)
	_label(body, when if not when.is_empty() else "Whenever its routine calls for it.", 16, GREEN, true)
	_label(body, "DOES", 11, GOLD)
	_label(body, does if not does.is_empty() else "Nothing is recorded about this move.", 16, PAPER, true)
	var rolled: Dictionary = _projected_rolls().get(str(enemy.get("id", "")), {})
	UiKit.rule(body)
	if rolled.is_empty():
		_label(body, "It has not taken its dice up this turn. Enemies roll after the party acts.", 14, MUTED, true)
	else:
		var open: bool = key in rolled.get("opened", [])
		_label(body, "This turn's roll opened it." if open else "This turn's roll did not open it.", 15, AMBER if open else MUTED, true)
	var turn := int(_battle_state().get("turn", 1))
	if turn >= 7:
		_label(body, "Enrage: every hit this turn deals %d more." % (2 * (turn - 6)), 14, RED, true)

func _inspect_die(die: Dictionary, rolled: Dictionary = {}) -> void:
	var faces: Array = die.get("faces", [])
	var box := _modal(_die_name(die))
	# A fresh view, not one of the persistent hand dice: this one answers to the reader.
	var view := DiceView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.add_child(view)
	var body := _sheet(box, holder, Vector2(320, 320), BLUE)
	view.enable_interaction()
	view.configure(die, rolled, false, false, GOLD)
	inspect_view = view
	_label(body, _die_name(die), 26, GOLD)
	_label(body, "%s  ·  %d physical faces" % [str(die.get("shape", "D6")).to_upper(), faces.size()], 15, BLUE)
	if rolled.has("value"):
		_label(body, "This roll turned up %d." % int(rolled.get("value", 0)), 16, GREEN, true)
	_label(body, "Drag the solid to turn it. Hover a face to bring that face to the front.", 14, MUTED, true)
	var counts: Dictionary = {}
	for face in faces:
		var value: int = int(face.get("value", 0)) if face is Dictionary else int(face)
		counts[value] = int(counts.get(value, 0)) + 1
	var repeated: Array = []
	var distinct: Array = counts.keys()
	distinct.sort()
	for value in distinct:
		if int(counts[value]) > 1:
			repeated.append("%d on %d faces" % [int(value), int(counts[value])])
	_label(body, ("Weighted: " + ", ".join(repeated) + ". Every physical face is still equally likely.") if not repeated.is_empty() else "Every physical face is equally likely.", 14, AMBER if not repeated.is_empty() else MUTED, true)
	UiKit.rule(body)
	_label(body, "FACES  ·  HOVER TO TURN", 11, GOLD)
	var grid := GridContainer.new()
	grid.columns = 5 if faces.size() > 12 else (4 if faces.size() > 6 else 3)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for index in range(faces.size()):
		var face: Variant = faces[index]
		var value: int = int(face.get("value", index + 1)) if face is Dictionary else int(face)
		var rolled_here: bool = int(rolled.get("face_index", -1)) == index
		var b := _button(grid, str(value), func(): view.focus_face(index))
		b.custom_minimum_size = Vector2(66, 42)
		b.tooltip_text = "Physical face %d shows %d." % [index + 1, value]
		b.mouse_entered.connect(func(): view.focus_face(index))
		if rolled_here:
			b.add_theme_color_override("font_color", GOLD)
			b.tooltip_text += " This is the face the roll turned up."

func _ping(_kind: String, id: String, title: String) -> void:
	if session.has_method("send_ping") and not offline_hotseat:
		session.send_ping(id, title)
	_notify("Ping: " + title)

func _preview_text(gem: Dictionary) -> String:
	var def: Dictionary = Catalog.SKILLS.get(gem.get("key", ""), {})
	var result := _gem_stats(gem) + "\nTrigger: " + str(def.get("trigger", "")) + "\n" + GemText.sentence(gem)
	if not snapshot.is_empty():
		var preview: Dictionary = Combat.preview(_hero(), gem, _preview_hand(), snapshot)
		result += "\n\nThis hand: " + (str(preview.get("summary", "")) if preview.get("active", false) else str(preview.get("reason", "Dormant")))
		if int(preview.get("effective_clarity", gem.get("clarity", 1))) != int(gem.get("clarity", 1)):
			result += "\nEffective Clarity: %d (includes Focusing Prism)" % int(preview.effective_clarity)
	return result

func _sealed(gem: Dictionary) -> bool:
	return gem.has("appraised") and not bool(gem.appraised)

func _stone_words(gem: Dictionary) -> String:
	## What the eye can tell about a stone, in words rather than ranks, so a reader without
	## the 3D view judges it from the same evidence as everyone else.
	var carat := int(gem.get("carat", 1))
	var size_word: String = "a chip of a" if carat <= 3 else ("a small" if carat <= 7 else ("a sizeable" if carat <= 12 else ("a large" if carat <= 18 else "an enormous")))
	var cut_word: String = ["rough", "plainly cut", "neatly cut", "finely cut", "exquisitely cut"][clampi(int(gem.get("cut", 1)), 1, 5) - 1]
	var clarity_word: String = ["cloudy", "hazy", "clear", "bright", "flawless-looking"][clampi(int(gem.get("clarity", 1)), 1, 5) - 1]
	var text := "%s %s, %s stone." % [size_word, cut_word, clarity_word]
	return text.left(1).to_upper() + text.substr(1)

func _gem_details(parent: Node, gem: Dictionary) -> void:
	if _sealed(gem):
		var stone_row := _hbox(parent, 11)
		stone_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_gem_portrait(stone_row, gem, 56).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var stone_box := _vbox(stone_row, 4)
		stone_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(stone_box, "Unappraised %s stone" % str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "")).to_lower(), 16, _gem_color(gem))
		_label(stone_box, _stone_words(gem), 13, MUTED, true)
		stone_row.tooltip_text = GemView.UNAPPRAISED_TEXT
		return
	var row := _hbox(parent, 11)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gem_portrait(row, gem, 56).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := _vbox(row, 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gem_title_row(box, gem, 16, _gem_color(gem))
	var def: Dictionary = Catalog.SKILLS.get(gem.get("key", ""), {})
	_label(box, str(def.get("trigger", "")), 13, GREEN, true)
	_formula_rows(box, gem, -1, 13)
	row.tooltip_text = _preview_text(gem)

func _gem_portrait(parent: Node, gem: Dictionary, edge: int) -> Control:
	## The stone as real geometry, cut from its own four properties, so two gems that
	## differ in one rank are told apart by the solid and not only by the label. A static
	## view renders one frame and stops, so a screen full of gems stays cheap.
	var view := GemView.new()
	view.custom_minimum_size = Vector2(edge, edge)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.set_drift(_idle_motion())
	parent.add_child(view)
	view.configure(gem)
	return view

func _room_guide(kind: String) -> String:
	## The journal describes a room in general, so unlike the route card it names no prices
	## in your purse and no act-specific boss.
	match kind:
		"battle": return "A fight drawn from the mine's depth band. Pays ore, and sometimes an unappraised stone."
		"elite": return "A harder fight. Double ore, one or two better stones, and a choice of relic."
		"boss": return "The mine's own boss, waiting wherever the tremor meter filled. Bosses carry Resolve, so they cannot be stun locked. Killing one opens its chest and unlocks the mines beyond."
		"shop": return "Personal stock paid in ore: three appraised gems, a die and a loupe. You may also sell found gems and reserve dice here."
		"lift": return "The only way home. The party votes to ride up with everything it carries, or to keep digging."
		"treasure": return "An unguarded cache: an appraised gem and a little ore for every hero."
		"rest": return "Recovers one third of maximum HP and returns downed heroes to their feet. Free."
		"workshop": return "One die service per hero: change to an adjacent shape, or engrave one physical face. 5 ore, or free once per expedition with Tinker’s Belt."
		"lapidary": return "Appraises stones for ore, and sells one Cut or Clarity increase per hero at 5 ore times the new rank. Cut scales what the dice gave; Clarity is a flat term that also eases triggers."
		"mine": return "Choose a vein, then mining runs itself: fixed energy per living hero, pooled ore split by seat, and a rotating draft of the unappraised stones the rocks held. Noisy: it stirs the tremors."
		"event": return "One transaction per hero — supplies, a trade, or a free exit."
		"wager": return "Stake ore on the house’s five matched dice — the same wager for every hero, whatever your own dice have become. One reroll, then the table pays the pattern you show. Only a four-die straight or better pays, so the reroll is the whole game: played carelessly the table is a losing bet, played well it is close to a fair one. A stake left on the table is paid out when you leave, never forfeited."
		"crucible": return "The only place Carat moves. Temper a gem to raise its Carat, paid in HP that rises with the gem, or fuse a found gem into it and pay in Carat instead. One offering per hero per visit."
	return ""

func _room_color(kind: String) -> Color:
	match kind:
		"battle", "combat": return RED
		"elite": return Color("ff9d5c")
		"boss": return VIOLET
		"shop": return GOLD
		"rest", "camp": return Color("ffb066")
		"event": return Color("d0b0ff")
		"mine": return GREEN
		"workshop": return Color("b9c6d6")
		"lapidary": return Color("63d8d0")
		"wager": return Color("ffd166")
		"crucible": return Color("ff8fa3")
		"lift": return GREEN
		"treasure": return BLUE
	return BLUE

## The gem widgets live in `gem_panel.gd` so the gem lab draws them the same way. These
## forward to it rather than wrapping it, so there is one implementation to change.

func _flow(parent: Node, separation: int = 6) -> HFlowContainer:
	return GemPanel.flow(parent, separation)

func _word(parent: Node, text: String, size_px: int, color: Color, tooltip: String = "") -> Label:
	return GemPanel.word(parent, text, size_px, color, tooltip)

func _gem_title_row(parent: Node, gem: Dictionary, size_px: int, name_color: Color, show_name := true) -> HFlowContainer:
	return GemPanel.title_row(parent, gem, size_px, name_color, show_name)

func _gem_marks_row(parent: Node, gem: Dictionary, edge: float) -> HBoxContainer:
	return GemPanel.marks_row(parent, gem, edge)

func _formula_rows(parent: Node, gem: Dictionary, effective_clarity: int = -1, size_px: int = 14) -> void:
	GemPanel.formula_rows(parent, gem, effective_clarity, size_px)

func _gem_name(gem: Dictionary) -> String:
	if _sealed(gem): return "an unappraised stone"
	return str(Catalog.SKILLS.get(gem.get("key", ""), {}).get("name", gem.get("key", "Gem")))

func _gem_stats(gem: Dictionary) -> String:
	## The same line the icon row shows, in words, for tooltips and narration.
	return "%s  ·  %s gem" % [GemText.title(gem), str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "Red"))]

func _gem_color(gem: Dictionary) -> Color:
	return Color(str(Catalog.color_definition(str(gem.get("key", ""))).get("hex", "e2564a")))

func _die_name(die: Dictionary) -> String:
	return str(Catalog.DICE.get(die.get("key", die.get("shape", "D6")), {}).get("name", die.get("shape", "Die")))

func _faces_text(die: Dictionary) -> String:
	var values: Array = []
	for face in die.get("faces", []):
		values.append(str(face.get("value", 0) if face is Dictionary else face))
	return ", ".join(values)

func _unit_name(id: String) -> String:
	for unit in snapshot.get("heroes", []) + snapshot.get("enemies", []):
		if str(unit.get("id", "")) == id: return str(unit.get("player_name", unit.get("name", id)))
	return "First valid target" if id.is_empty() else id

func _status_text(unit: Dictionary) -> String:
	var parts: Array = []
	var statuses: Dictionary = unit.get("statuses", {})
	for key in ["stun", "poison", "resolve"]:
		if int(statuses.get(key, 0)) > 0: parts.append("%s %d" % [key.to_upper(), int(statuses[key])])
	return " · ".join(parts)

func _log_text(entry: Variant) -> String:
	if entry is String: return entry
	if not entry is Dictionary: return str(entry)
	var result := str(entry.get("message", entry.get("text", "")))
	if not result.is_empty():
		return result
	result = "%s · %s → %s" % [_unit_name(str(entry.get("actor", entry.get("actor_id", "")))), str(entry.get("skill", entry.get("kind", entry.get("type", "event")))), _unit_name(str(entry.get("target", entry.get("target_id", ""))))]
	var details: Array = []
	for key in ["raw_damage", "block_absorbed", "hp_loss", "amount", "applied", "removed"]:
		if entry.has(key): details.append("%s %s" % [key.replace("_", " "), str(entry[key])])
	if not details.is_empty(): result += "  [" + "; ".join(details) + "]"
	return result

func _show_log() -> void:
	var box := _modal("The combat record")
	_label(box, "Authority events in execution order. Animation controls change only presentation.", 13, MUTED, true)
	for entry in snapshot.get("log", []):
		_label(box, _log_text(entry), 13, PAPER, true)

func _show_journal() -> void:
	var box := _modal("The expedition journal")
	var tabs := _hbox(box)
	for tab in ["guide", "rooms", "heroes", "gems", "dice", "relics", "enemies", "history"]:
		var b := _button(tabs, tab.capitalize(), func(): journal_tab = tab; _show_journal())
		b.toggle_mode = true
		b.button_pressed = journal_tab == tab
	match journal_tab:
		"guide":
			var entries := [
				["ONE HAND, MANY SKILLS", "Roll five active dice. Select dice you want to reroll; the others stay. You normally have one reroll. Lock in when you are satisfied. There is no automatic lock-in timer."],
				["A PAIR CAN DO MORE", "With [2, 2, 4, 6, 8], Strike C1/K1/L1 deals 8 damage and Block C2/K1/L1 grants 2 block. Both use the same hand; dice are neither assigned nor spent."],
				["THE FOUR C'S", "Color is the gem's effect category: Red damage, Blue block, Green healing, Violet control, Gold fortune. Carat 1–24, marked with a balance scale, is the overall strength multiplier, from ×1 at Carat 1 to ×3.875 at Carat 24. Cut 1–5, Poor to Perfect and marked with a throwing star, multiplies whatever the dice contribute, so it matters most on attacks. Clarity 1–5, Fractured to Flawless and marked with a sparkle, adds a flat bonus that does not depend on your roll, eases triggers, and unlocks extra effects at the top ranks."],
				["READING THE STONE", "A gem is drawn from its own four properties, so two gems that differ in one rank look different. Color sets the outline and hue — Red is a triangle cut, Blue a square, Green a heart, Violet a marquise, Gold a round brilliant. Carat sets the size, from a chip at 1 to nearly three times that at 24. Cut sets how intricate the faceting is. Clarity sets the brilliance: a Fractured stone is cloudy and carries visible flaws, a Flawless one is saturated and throws a star. The skill\'s emblem is etched into the face."],
				["READING A GEM", "A gem is named by its ranks: Good, Flawless, 12, Multistrike. Under that, its rule is a short chain — the terms it adds up, then one Carat multiplier, then what it does. Each term wears the mark of the property behind it and its own colour, and hovering any mark or term explains it. A term worth nothing is never shown, so a Carat 1 gem carries no multiplier on its line and a Cut that adds nothing is simply absent."],
				["YOUR BUILD", "Equip six unique skill gems including Strike. Carat, Cut, and Clarity vary independently; Color is fixed by the skill. Equip, replace, and reorder between rooms before ready. Skills resolve in their visible order."],
				["TARGETS AND TURN ORDER", "Choose a preferred enemy by clicking it on the battlefield. Friendly effects need no choice: support skills reach every living hero. A skill fixes its target as it begins; later hostile hits fizzle if that target dies. The next skill can retarget. Heroes act in party seat order, then enemies. Enemy intents are public before planning."],
				["BLOCK, STUN, POISON", "Block persists through turns, then clears after combat. Stun skips an actor’s next slot. Poison bypasses block at the end of a living actor’s slot, then loses one stack; it still ticks when stunned. Boss Resolve prevents repeated stun locking."],
				["FALLING AND RECOVERY", "Downed heroes do not roll or act. Victory rallies them to 10% HP. If the whole party falls, every stone it carried is rolled on a die by rarity — d6 to d20 — and only the top face brings it home. Your loadout is never at risk."],
				["THE SEAM", "A mine is dug one layer at a time and has no bottom. Your lantern shows the rooms two layers ahead; past that you see only shapes, and the beacons of lifts. Deeper layers hold harder fights and better stones."],
				["THE TREMORS", "Every step down and every noisy room fills the tremor meter, faster the deeper you are; fights hold it still. When it fills, the mine's boss breaks through into the next chamber you enter. Ride a lift home before then — or be ready."],
				["STONES AND APPRAISAL", "Stones come out of the rock unappraised: you can see their colour, size, cut and clarity, but not what they do, and they cannot be equipped. A loupe or a Lapidary appraises one. At home every stone is appraised on the table, then kept or sold for gold."],
				["THE LONG FIGHT", "Enrage starts on turn 7: enemies add +2 raw damage per hit, then +2 more each turn. The ore your gems can mint in a battle is capped, rising slowly with depth. Room rewards are separate."],
				["ORE AND GOLD", "Ore is the mine's currency: it pays for merchants, Lapidaries, Workshops and the Wager Hall, and it stays behind when you leave. Gold is what you earn at home by selling stones."],
				["THE THREE UPGRADE PATHS", "A gem’s ranks move in three different places. The Lapidary sells Cut and Clarity for ore. The Crucible raises Carat — the multiplier over the whole gem — for HP, or for a found gem fed to the fire. Upgrades to your loadout last one expedition; upgrades to a find come home with it."],
				["CONTROLS", "Click dice or press 1–5. R rerolls, Space readies, Tab cycles enemy targets, I inspects equipment, Escape closes a panel. On the seam, click a ringed chamber or press 1–9 for the matching tunnel. At the Wager Hall the staked hand uses the same 1–5 and R. Controller focus uses the directional pad, accept, and back. Remap actions in Settings."]
			]
			for entry in entries:
				_label(box, entry[0], 14, GOLD)
				_label(box, entry[1], 15, PAPER, true)
		"rooms":
			_label(box, "Every room a seam can hold. A single expedition rarely meets them all.", 14, MUTED, true)
			for kind in EngineScript.ROOM_NAMES:
				var room_key := str(kind)
				var accent := _room_color(room_key)
				var entry := _panel(box, PANEL, Color(accent, 0.5), 12)
				var room_row := _hbox(entry, 12)
				UiKit.icon(room_row, Forge.room(room_key), 56).size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var room_facts := _vbox(room_row, 3)
				room_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(room_facts, str(EngineScript.ROOM_NAMES[kind]), 20, GOLD)
				_label(room_facts, _room_guide(room_key), 14, PAPER, true)
		"heroes":
			for key in Catalog.HEROES:
				var def: Dictionary = Catalog.HEROES[key]
				var entry := _panel(box, PANEL, LINE, 12)
				var entry_row := _hbox(entry, 12)
				UiKit.icon(entry_row, Forge.unit(key), 96).size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var facts := _vbox(entry_row, 3)
				facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(facts, "%s · %d HP · %s" % [def.name, def.max_hp, _join_values(def.dice)], 20, GOLD)
				_label(facts, str(def.trait_name) + ": " + str(def.description), 15, PAPER, true)
		"gems":
			for key in Catalog.SKILLS:
				var def: Dictionary = Catalog.SKILLS[key]
				var entry := _panel(box, PANEL, LINE, 12)
				var entry_row := _hbox(entry, 12)
				# The journal describes a skill, not an instance, so it shows a mid-rank stone
				# purely to teach the outline and emblem this skill always wears.
				var sample: Dictionary = Catalog.gem(str(key), "journal-" + str(key), 12, 3, 4)
				_gem_portrait(entry_row, sample, 52).size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var gem_facts := _vbox(entry_row, 3)
				gem_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(gem_facts, "%s · Rarity %d" % [def.name, def.rarity], 19, GOLD)
				_label(gem_facts, str(def.trigger) + "\n" + str(def.formula), 15, PAPER, true)
		"dice":
			_label(box, "Every physical face is equally likely. Repeated values simply appear on more faces.", 13, MUTED, true)
			var dice_grid := GridContainer.new()
			dice_grid.columns = 3
			box.add_child(dice_grid)
			for key in Catalog.DICE:
				var def: Dictionary = Catalog.DICE[key]
				var entry := _panel(dice_grid, PANEL, LINE, 12)
				entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var entry_row := _hbox(entry, 10)
				var display := Control.new()
				display.custom_minimum_size = Vector2(86, 86)
				entry_row.add_child(display)
				var preview_die := _die_view("preview:journal:" + key)
				preview_die.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				display.add_child(preview_die)
				preview_die.live = false
				preview_die.configure(Catalog.die(key, "journal-" + key), {}, false, false, BLUE)
				var facts := _vbox(entry_row, 3)
				facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(facts, str(def.name), 18, BLUE)
				_label(facts, "%s · %d ore" % [str(def.shape), int(def.price)], 12, GOLD)
				_label(facts, "Faces: " + _join_values(def.faces), 13, PAPER, true)
		"relics":
			for key in Catalog.RELICS:
				var def: Dictionary = Catalog.RELICS[key]
				var entry := _panel(box, PANEL, LINE, 12)
				var entry_row := _hbox(entry, 12)
				UiKit.icon(entry_row, Forge.relic(key), 52).size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var facts := _vbox(entry_row, 3)
				facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(facts, str(def.name), 19, GOLD)
				_label(facts, str(def.description), 15, PAPER, true)
		"enemies":
			for key in Catalog.ENEMIES:
				var def: Dictionary = Catalog.ENEMIES[key]
				var boss: bool = def.get("boss", false)
				var entry := _panel(box, PANEL, VIOLET if boss else LINE, 12)
				var entry_row := _hbox(entry, 12)
				UiKit.icon(entry_row, Forge.unit(key), 88).size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var facts := _vbox(entry_row, 3)
				facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_label(facts, str(def.name) + ("  ·  BOSS" if boss else ""), 19, AMBER if boss else RED)
				_label(facts, "%d HP  ·  %d starting block" % [int(def.get("max_hp", 0)), int(def.get("block", 0))], 12, GOLD)
				_label(facts, str(def.get("description", "")), 15, PAPER, true)
		"history":
			var records: Array = engine.save_store.load_history()
			if records.is_empty(): _label(box, "Completed expeditions will be recorded here.", 16, MUTED)
			for record in records:
				_label(box, "%s · %s · depth %s · seed %s" % [str(record.get("outcome", "Expedition")).capitalize(), str(Catalog.mine_definition(str(record.get("mine_id", ""))).get("name", "")), str(record.get("depth", 0)), str(record.get("seed", ""))], 17, GOLD)
				_label(box, str(record.get("completed_at", record.get("saved_at", ""))), 13, MUTED)

func _show_menu() -> void:
	## Everything the old top bar held. Escape reaches it from any screen.
	var box := _modal("Menu")
	if not snapshot.is_empty():
		_button(box, "Equipment  [%s]" % _binding_name("rd_inspect"), _show_inventory, true)
	_button(box, "Journal", _show_journal)
	_button(box, "Settings & accessibility", _show_settings)
	if not snapshot.is_empty():
		_button(box, "Save and return to the table", _return_menu)
	_button(box, "Resume  [%s]" % _binding_name("rd_back"), _close_overlay)

func _show_settings() -> void:
	var pending_binding := rebind_action
	var box := _modal("Settings & accessibility")
	rebind_action = pending_binding
	_label(box, "DISPLAY AND PLAYBACK", 12, GOLD)
	var scale_row := _hbox(box)
	_label(scale_row, "Text scale", 15, PAPER)
	var scale := OptionButton.new()
	for text in ["90%", "100%", "110%", "125%", "140%"]: scale.add_item(text)
	var scales := [0.9, 1.0, 1.1, 1.25, 1.4]
	scale.selected = scales.find(float(settings.text_scale))
	scale.item_selected.connect(func(index: int): settings.text_scale = scales[index]; _save_settings(); _apply_theme(); _queue_render(); _show_settings.call_deferred())
	scale_row.add_child(scale)
	var motion := CheckButton.new()
	motion.text = "Reduced motion"
	motion.tooltip_text = "Stops the background, the battle animations and every idle turn."
	motion.button_pressed = settings.reduced_motion
	motion.toggled.connect(func(value: bool): settings.reduced_motion = value; _save_settings(); _apply_motion(); _show_settings.call_deferred())
	box.add_child(motion)
	var drift := CheckButton.new()
	drift.text = "Idle motion on dice and gems"
	drift.tooltip_text = "Dice and gems turn slowly when nothing is happening. Each one that moves needs its own live camera, so switching this off is the cheapest way to buy frames back on a crowded screen. Reduced motion turns it off regardless."
	drift.button_pressed = settings.idle_motion
	drift.disabled = bool(settings.reduced_motion)
	drift.toggled.connect(func(value: bool): settings.idle_motion = value; _save_settings(); _apply_motion())
	box.add_child(drift)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Full screen"
	fullscreen.button_pressed = settings.fullscreen
	fullscreen.toggled.connect(func(value: bool): settings.fullscreen = value; DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED); _save_settings())
	box.add_child(fullscreen)
	var speed_row := _hbox(box)
	_label(speed_row, "Playback speed", 15, PAPER)
	var speed := OptionButton.new()
	for text in ["0.5×", "1×", "2×", "4×", "Instant"]: speed.add_item(text)
	var speeds := [0.5, 1.0, 2.0, 4.0, 100.0]
	speed.selected = speeds.find(float(settings.playback_speed))
	speed.item_selected.connect(func(index: int): settings.playback_speed = speeds[index]; _save_settings())
	speed_row.add_child(speed)
	var volume_row := _hbox(box)
	_label(volume_row, "Sound volume", 15, PAPER)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = float(settings.sound_volume)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value_changed.connect(func(value: float): settings.sound_volume = value; _save_settings())
	volume_row.add_child(volume)
	_label(box, "REMAPPABLE ACTIONS", 12, GOLD)
	_label(box, "Select an action, then press a keyboard key or controller button. Escape cancels a binding.", 13, MUTED, true)
	for action in ACTION_DEFAULTS:
		var row := _hbox(box)
		_label(row, str(action).trim_prefix("rd_").replace("_", " ").capitalize(), 15, PAPER)
		_spacer(row)
		_button(row, "Press a key / button…" if rebind_action == action else _binding_name(action), func(): rebind_action = action; _show_settings())
	_button(box, "Restore default bindings", func(): settings.bindings = {}; _install_input(); _save_settings(); _show_settings())
	_label(box, "Die selection also uses keys 1–5. Status names and keep/reroll labels remain visible independently of color.", 13, MUTED, true)

func _install_input() -> void:
	for action in ACTION_DEFAULTS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var binding: Dictionary = settings.get("bindings", {}).get(action, {})
		if binding.get("type", "key") == "joy":
			var joy := InputEventJoypadButton.new()
			joy.button_index = int(binding.get("button", JOY_BUTTON_A))
			InputMap.action_add_event(action, joy)
		else:
			var key := InputEventKey.new()
			key.physical_keycode = int(binding.get("key", ACTION_DEFAULTS[action]))
			InputMap.action_add_event(action, key)
	var gamepad_defaults := {"rd_reroll": JOY_BUTTON_X, "rd_ready": JOY_BUTTON_Y, "rd_inspect": JOY_BUTTON_BACK, "rd_back": JOY_BUTTON_B, "rd_target": JOY_BUTTON_RIGHT_SHOULDER, "rd_skip": JOY_BUTTON_START}
	for action in gamepad_defaults:
		if settings.get("bindings", {}).has(action): continue
		var joy := InputEventJoypadButton.new()
		joy.button_index = gamepad_defaults[action]
		InputMap.action_add_event(action, joy)

func _binding_name(action: String) -> String:
	var bindings := InputMap.action_get_events(action)
	if bindings.is_empty(): return "Unbound"
	return bindings[0].as_text().replace(" (Physical)", "").replace(" - Physical", "")

func _input(event: InputEvent) -> void:
	if not rebind_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode != KEY_ESCAPE: settings.bindings[rebind_action] = {"type": "key", "key": event.physical_keycode}
			rebind_action = ""
			_install_input()
			_save_settings()
			_show_settings()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			settings.bindings[rebind_action] = {"type": "joy", "button": event.button_index}
			rebind_action = ""
			_install_input()
			_save_settings()
			_show_settings()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("rd_back"):
		if is_instance_valid(spotlight): _close_spotlight()
		elif is_instance_valid(overlay): _close_overlay()
		else: _show_menu()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(overlay) or snapshot.is_empty(): return
	if event.is_action_pressed("rd_skip"):
		_skip_playback()
		reveal.hurry()
	elif _resolving() and not event.is_action_pressed("rd_inspect"):
		# A turn still being drawn cannot be acted on: the hand on the table is not the one
		# the next command would read.
		return
	elif event.is_action_pressed("rd_inspect"):
		_show_inventory()
	elif event.is_action_pressed("rd_ready"):
		_command("SetReady", {"ready": not _hero().get("ready", false)})
	elif snapshot.get("phase") == "planning":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			var i := int(event.physical_keycode - KEY_1)
			if i < _hero().get("dice", []).size(): _toggle_die(str(_hero().dice[i].id))
		elif event.is_action_pressed("rd_reroll"): _reroll()
		elif event.is_action_pressed("rd_target"): _cycle_target()
		elif event.is_action_pressed("rd_toggle_die"):
			var focused := get_viewport().gui_get_focus_owner()
			if is_instance_valid(focused) and str(focused.get_meta("focus_tag", "")).begins_with("die_"):
				var index := int(str(focused.get_meta("focus_tag")).trim_prefix("die_"))
				_toggle_die(str(_hero().dice[index].id))
		else: return
	elif snapshot.get("phase") == "route":
		# The route list is numbered on screen, so the same digits vote for it.
		var offers: Array = snapshot.get("offers", [])
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			var choice := int(event.physical_keycode - KEY_1)
			if choice >= offers.size() or snapshot.get("votes", {}).has(controlled_id): return
			_command("VoteRoom", {"offer_id": offers[choice].id})
		else: return
	elif str(snapshot.get("room", {}).get("kind", "")) == "wager" and snapshot.get("phase") == "support":
		# A staked hand is read and rerolled with the same keys as a combat hand.
		var seat: Dictionary = snapshot.get("room", {}).get("wager", {}).get(controlled_id, {})
		if int(seat.get("stake", 0)) <= 0 or seat.get("settled", false) or seat.get("rerolled", false): return
		var hand: Array = seat.get("hand", [])
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			var slot := int(event.physical_keycode - KEY_1)
			if slot >= hand.size(): return
			_toggle_die(str(hand[slot].get("die_id", "")))
		elif event.is_action_pressed("rd_reroll"):
			if selected_dice.is_empty(): return
			_play_sound(dice_sound)
			_command("WagerReroll", {"die_ids": selected_dice.duplicate()})
			selected_dice.clear()
		else: return
	else: return
	get_viewport().set_input_as_handled()

func _cycle_target() -> void:
	var candidates: Array = []
	for enemy in snapshot.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: candidates.append(str(enemy.id))
	if candidates.is_empty(): return
	var current := candidates.find(str(_hero().get("preferred_target", "")))
	_command("SetPreferredTarget", {"unit_id": candidates[(current + 1) % candidates.size()]})

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://interface.cfg") == OK:
		for key in settings.keys(): settings[key] = cfg.get_value("ui", key, settings[key])
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings: cfg.set_value("ui", key, settings[key])
	cfg.save("user://interface.cfg")

func _skip_playback() -> void:
	playback_index = playback_events.size()
	playback_dwell = 0.0
	casting_gem = ""
	mine_playback_index = snapshot.get("mine", {}).get("events", []).size()

func _return_menu() -> void:
	## Back to the shop. A party stays together: the host reopens the lobby and every guest
	## lands in the shop with it, ready flags cleared for the next descent.
	_close_overlay()
	# A finished expedition has nothing left to resume, so its checkpoint goes with it.
	if str(snapshot.get("phase", "")) == "summary" and (offline_hotseat or session.is_host):
		engine.save_store.clear_checkpoint()
	if _in_party() and not offline_hotseat:
		if session.is_host: session.return_to_lobby()
	else:
		session.leave()
	snapshot = {}
	controlled_id = ""
	selected_dice.clear()
	_queue_render()

func _show_recovery(_state: Dictionary) -> void:
	var box := _modal("The host has departed")
	_label(box, "Progress has stopped. Your party snapshot is preserved for inspection. The original host must reopen the canonical checkpoint and invite the party to resume.", 16, MUTED, true)
	_label(box, "There is no automatic host promotion. Reconnect to the original host when their lobby is available.", 14, GOLD, true)
	_button(box, "Reconnect", func(): session.reconnect())
	_button(box, "Return to table", _return_menu)

func _accept_steam_invite(lobby_id: String) -> void:
	var id := lobby_id.strip_edges()
	if not id.is_valid_int() or int(id) <= 0:
		_notify("The Steam invitation does not contain a valid lobby ID.")
		return
	if snapshot.is_empty():
		_join_invited_lobby(id)
		return
	var box := _modal("Steam party invitation")
	_label(box, "Join Steam lobby %s?" % id, 18, GOLD, true)
	_label(box, "You currently have an active expedition. Joining leaves this party. Your last committed checkpoint remains available to resume.", 16, PAPER, true)
	if session.is_host and not offline_hotseat:
		_label(box, "You are hosting. The current party will pause until you reopen its checkpoint.", 14, MUTED, true)
	var row := _hbox(box)
	_button(row, "Stay in this run", _close_overlay, true)
	_button(row, "Leave saved run & join invitation", func(): _join_invited_lobby(id))

func _join_invited_lobby(lobby_id: String) -> void:
	_close_overlay()
	session.leave()
	snapshot = {}
	controlled_id = ""
	selected_dice.clear()
	offline_hotseat = false
	steam_lobby_text = lobby_id
	var result: Dictionary = session.join_steam(lobby_id, player_name)
	if not result.get("ok", false):
		_notify(str(result.get("error", "The Steam lobby could not be joined.")))
	_queue_render()

func _resume_network() -> void:
	var loaded: Dictionary = engine.save_store.load_checkpoint()
	if not loaded.get("ok", false):
		_notify(str(loaded.get("error", "No saved checkpoint is available.")))
		return
	var result: Dictionary = session.restore_party(loaded.state)
	if not result.get("ok", false):
		_notify(str(result.get("error", "Only the original host can resume this party.")))
		return
	offline_hotseat = false
	controlled_id = str(session.local_player_id)
	result = engine.restore(loaded.state, loaded.get("command_history", {}), str(session.session_id))
	if not result.get("ok", false):
		_notify(str(result.get("error", "Checkpoint could not be restored.")))
		return
	session.host_epoch = int(engine.state.get("host_epoch", 1))
	session.broadcast_snapshot(engine.state)

func _show_fallback(id: String) -> void:
	var box := _modal("A hero is disconnected")
	_label(box, _unit_name(id) + " can reconnect to their existing seat. Planning pauses for a 60-second recovery window.", 16, MUTED, true)
	_label(box, "After that window, the host may enable the declared fallback: keep the existing hand, use deterministic reward choices, and continue without changing encounter difficulty.", 14, GOLD, true)
	_button(box, "Resume with fallback", func():
		var host := str(snapshot.get("host_id", controlled_id))
		var result: Dictionary = engine.execute(host, engine.make_envelope(host, "ResumeDisconnected", {"player_id": id}))
		if not result.get("ok", false): _notify(str(result.get("error", "Recovery window is still active.")))
		else:
			session.resume_disconnected(id)
			_close_overlay(), true)
	_button(box, "Keep waiting", _close_overlay)

func _modal(title: String) -> VBoxContainer:
	# A screen that rebuilds itself after a change — an equip, a purchase — reopens where the
	# reader was rather than at the top.
	var keep := 0
	if is_instance_valid(overlay) and str(overlay.get_meta("title", "")) == title and overlay.has_meta("scroll"):
		var previous: ScrollContainer = overlay.get_meta("scroll")
		if is_instance_valid(previous): keep = previous.scroll_vertical
	_close_overlay()
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", _style(Color(0.016, 0.024, 0.043, 0.965), Color(0, 0, 0, 0), 0, 24))
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 10)
	overlay.add_child(margin)
	var outer := _vbox(margin, 12)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiKit.panel_box(Color("22304d"), Color("141d30"), Color("3a4a6b"), 12, 13, 1.4, 0.35))
	outer.add_child(banner)
	var top := _hbox(banner, 10)
	UiKit.icon(top, Forge.prop("sigil"), 30).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(top, title, 26, GOLD)
	_spacer(top)
	_button(top, "Close  [Esc]", _close_overlay)
	var scroll := _scroll(outer)
	var box := _vbox(scroll, 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.set_meta("title", title)
	overlay.set_meta("scroll", scroll)
	if keep > 0:
		get_tree().process_frame.connect(func():
			if is_instance_valid(scroll): scroll.scroll_vertical = keep, CONNECT_ONE_SHOT)
	return box

## --- The spotlight ---------------------------------------------------------------
## An appraisal made down the mine is held up over everything else, because it is the one
## moment a stone stops being a guess.

func _show_spotlight() -> void:
	if is_instance_valid(spotlight) or spotlight_queue.is_empty() or not is_inside_tree(): return
	var gem: Dictionary = spotlight_queue.pop_front()
	var key := "spotlight:" + str(gem.get("id", ""))
	var definition: Dictionary = Catalog.SKILLS.get(str(gem.get("key", "")), {})
	var rarity := int(definition.get("rarity", 1))
	spotlight = Control.new()
	spotlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spotlight.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(spotlight)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight.add_child(dim)
	reveal.show(dim, key, 0.0, "fade", 0.35)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight.add_child(centre)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 560
	card.add_theme_stylebox_override("panel", UiKit.panel_box(Color("1f2940"), Color("0e131f"), _gem_color(gem), 16, 22, 2.0, 0.3))
	centre.add_child(card)
	reveal.show(card, key, 0.05, "pop")
	var box := _vbox(card, 10)
	var heading := _label(box, "APPRAISED", 13, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(240, 240)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	box.add_child(stage)
	var sealed_view := GemView.new()
	stage.add_child(sealed_view)
	sealed_view.configure(_sealed_copy(gem))
	sealed_view.set_spin(2.2)
	var known_view := GemView.new()
	stage.add_child(known_view)
	known_view.configure(gem)
	known_view.set_spin(0.6)
	reveal.show(sealed_view, key, 1.05, "vanish", 0.18)
	reveal.show(known_view, key, 1.05, "stamp", 0.4)
	reveal.show(stage, key, 1.05, "glow", 0.9)
	reveal.cue(key, 1.05, _sound("flourish" if rarity >= 3 else "sparkle"))
	var title := _label(box, _gem_name(gem), 30, _gem_color(gem))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal.show(title, key, 1.2, "stamp")
	var chips := _hbox(box, 6)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.chip(chips, ["", "COMMON", "UNCOMMON", "RARE", "LEGENDARY"][clampi(rarity, 1, 4)], [MUTED, MUTED, GREEN, BLUE, AMBER][clampi(rarity, 1, 4)])
	UiKit.chip(chips, str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "")).to_upper(), _gem_color(gem))
	reveal.show(chips, key, 1.35, "pop")
	var rows := _vbox(box, 6)
	_gem_title_row(rows, gem, 15, PAPER, false)
	_label(rows, str(definition.get("trigger", "")), 14, GREEN, true)
	_formula_rows(rows, gem, -1, 14)
	reveal.show(rows, key, 1.5, "fade")
	var equipped: Array = _hero().get("gems", []).filter(func(item: Dictionary) -> bool: return item.get("equipped", false))
	var socket := -1
	for index in range(equipped.size()):
		if str(equipped[index].get("id", "")) == str(gem.get("id", "")): socket = index
	var note := UiKit.chip(box, ("SET IN OPEN SOCKET %d" % (socket + 1)) if socket >= 0 else "IN RESERVE  ·  DRAG IT INTO A SOCKET FROM YOUR EQUIPMENT", GREEN if socket >= 0 else AMBER)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reveal.show(note, key, 1.7, "stamp")
	var go := _button(box, "Continue  [%s]" % _binding_name("rd_back"), func():
		if reveal.reached(key, 1.7): _close_spotlight()
		else: reveal.hurry(), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spotlight.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			reveal.hurry())

func _close_spotlight() -> void:
	if is_instance_valid(spotlight):
		spotlight.queue_free()
	spotlight = null
	_show_spotlight.call_deferred()

func _close_overlay() -> void:
	rebind_action = ""
	if is_instance_valid(overlay):
		_rescue_persistent(overlay)
		remove_child(overlay)
		overlay.queue_free()
		overlay = null

func _rescue_persistent(branch: Node) -> void:
	## Pull reusable sprites and dice out of a branch before it is freed.
	for store in [dice_views, actor_views]:
		for id in store.keys():
			var node = store[id]
			if not is_instance_valid(node):
				store.erase(id)
			elif node.get_parent() != null and branch.is_ancestor_of(node):
				node.get_parent().remove_child(node)

func _notify(message: String) -> void:
	if not is_inside_tree(): return
	if is_instance_valid(toast): toast.queue_free()
	toast = Label.new()
	toast.text = message
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", GOLD)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 4)
	toast.add_theme_stylebox_override("normal", UiKit.panel_box(Color("2a3a58"), Color("141d30"), GOLD, 10, 14, 1.6, 0.3))
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 90
	toast.offset_right = -90
	toast.offset_top = -90
	toast.offset_bottom = -40
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	var current := toast
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(current): current.queue_free())

func _panel(parent: Node, color: Color = PANEL, border: Color = LINE, padding: int = 16) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(color.lightened(0.07), color.darkened(0.32), border, 11, padding, 1.4, 0.22))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return _vbox(panel, 9)

func _vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _hbox(parent: Node, separation: int = 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _label(parent: Node, text: String, size_px: int = 16, color: Color = PAPER, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(size_px * float(settings.text_scale)))
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): _play_sound(click_sound); callback.call())
	if primary:
		button.add_theme_stylebox_override("normal", UiKit.panel_box(Color("6d5527"), Color("3c2f14"), GOLD, 8, 13, 1.6, 0.5))
		button.add_theme_stylebox_override("hover", UiKit.panel_box(Color("8e6f32"), Color("52411d"), Color("ffd79a"), 8, 13, 1.8, 0.7))
		button.add_theme_stylebox_override("pressed", UiKit.panel_box(Color("3c2f14"), Color("6d5527"), GOLD, 8, 13, 1.8, 0.0))
		button.add_theme_color_override("font_color", Color("ffe9c2"))
	parent.add_child(button)
	return button

func _scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	return scroll

func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _join_values(values: Array) -> String:
	var strings: Array = []
	for value in values: strings.append(str(value))
	return ", ".join(strings)

func _preview_hand() -> Array:
	var current: Array = _hero().get("hand", [])
	return current if not current.is_empty() else last_hands.get(controlled_id, [])

func _preview_basis() -> String:
	var hand: Array = _preview_hand()
	return "No hand has been rolled yet, so only the gem’s own ranks are compared." if hand.is_empty() else "Using your last combat hand: %s." % _hand_values(hand)

func _hand_values(hand: Array) -> String:
	var values: Array = []
	for face in hand: values.append(str(face.get("value", 0)))
	return "[" + ", ".join(values) + "]" if not values.is_empty() else "No combat hand yet"

func _play_sound(stream: AudioStreamWAV) -> void:
	if stream == null or float(settings.sound_volume) <= 0.0: return
	var voice: AudioStreamPlayer = null
	for candidate in sound_players:
		if is_instance_valid(candidate) and not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = sound_player
	if not is_instance_valid(voice): return
	voice.stream = stream
	voice.volume_db = linear_to_db(float(settings.sound_volume))
	voice.play()

func _sound(name: String) -> Callable:
	## A sound as something a reveal can cue.
	return func(): _play_sound(sounds.get(name, null))

func _highlight_dice(ids: Array) -> void:
	for id in dice_views:
		var view: DiceView = dice_views[id]
		if is_instance_valid(view):
			view.set_highlight(ids.has(id))

func _plan_equipment(kind: String, payload: Dictionary) -> void:
	var hero: Dictionary = provisional.get(controlled_id, {})
	if hero.is_empty(): return
	match kind:
		"EquipGem", "EquipRelic":
			var is_gem := kind == "EquipGem"
			var items: Array = hero.get("gems" if is_gem else "relics", [])
			var id := str(payload.get("gem_id" if is_gem else "relic_id", ""))
			var found: Dictionary = {}
			for item in items:
				if str(item.id) == id: found = item
			if found.is_empty(): return
			for item in items:
				if str(item.id) == str(payload.get("replace_id", "")): item.equipped = false
			found.equipped = not found.get("equipped", false)
		"ReorderGems":
			var ordered: Array = []
			for id in payload.get("gem_ids", []):
				for item in hero.gems:
					if item.id == id: ordered.append(item)
			for item in hero.gems:
				if not item.get("equipped", false): ordered.append(item)
			hero.gems = ordered
		"SwapDie":
			var active_i := -1
			var reserve_i := -1
			for i in hero.dice.size():
				if hero.dice[i].id == payload.get("active_id"): active_i = i
			for i in hero.reserve_dice.size():
				if hero.reserve_dice[i].id == payload.get("reserve_id"): reserve_i = i
			if active_i < 0 or reserve_i < 0: return
			var prior: Dictionary = hero.dice[active_i]
			hero.dice[active_i] = hero.reserve_dice[reserve_i]
			hero.reserve_dice[reserve_i] = prior
		_: return
	provisional_commands[controlled_id].append({"type": kind, "payload": payload.duplicate(true)})

func _commit_provisional() -> void:
	if str(snapshot.get("phase", "")) == "planning" or _hero().get("ready", false): return
	var commands: Array = provisional_commands.get(controlled_id, [])
	for command in commands:
		_command(str(command.type), command.payload)
	provisional.erase(controlled_id)
	provisional_commands.erase(controlled_id)
	_show_inventory.call_deferred()
