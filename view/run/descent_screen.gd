extends Control
## The run: the shaft's tunnels, its chambers and landings, and the fight when there is one.
## Every screen here shows the run state it is given and turns clicks into commands; the
## battle screen inside it does the same for a fight.
##
## Between fights the page stands in front of a 2D cave in the colours of the biome the
## party is in, with the shaft map down the left. Pages are rebuilt whenever the state moves
## (they are cheap: stones and dice are photographs), and only animate in when the page is
## new, so a vote or a strike never makes the whole screen jump.

const BattleScreen = preload("res://view/battle/battle_screen.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Backdrop = preload("res://view/run/backdrop.gd")
const ShaftMap = preload("res://view/run/shaft_map.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")

signal command(cmd: Dictionary)
signal home_requested
signal menu_requested

const KIND_WORDS: Dictionary = {"fight": "A fight", "elite": "Something big", "vein": "A vein", "oddity": "Something odd",
	"motherlode": "A glittering hollow", "landing": "The landing", "hidden": "A dark mouth"}
const KIND_TEXT: Dictionary = {"fight": "Creatures of the rock. Ore, and a fair chance of a raw stone.",
	"elite": "Something big and angry. A stone a grade better, guaranteed.",
	"vein": "A wall of glinting rock. Strike it for stones, ore and dice.",
	"oddity": "Something strange in the dark: a gamble with your stones or dice.",
	"motherlode": "A hollow glittering with stones. Take them.",
	"landing": "Solid ground: a lift home, a lapidary, a merchant and a bench.",
	"hidden": "Too dark to see. Anything could be down there."}
const ODDITY_GLYPHS: Dictionary = {"CUTTERS_WHEEL": "cut", "ACID_BATH": "drop", "CRUCIBLE": "flame", "GEODE": "ore", "GRINDER": "die",
	"OLD_PROSPECTOR": "person", "SHRINE": "star", "IDOL": "eye", "ECHO_CHAMBER": "copy", "DICE_BOWL": "die", "COLLECTOR": "coins",
	"LOUPE_CABINET": "loupe", "FIELD_MEDIC": "cross", "VUG": "pick"}
const LANDING_TABS: Array = [["haul", "Haul", "bag"], ["bench", "Bench", "anvil"], ["merchant", "Merchant", "coins"], ["lift", "Lift", "lift"]]

var local_id: String = ""
var run: Dictionary = {}
var forecast_provider: Callable = Callable()
var _strip: HBoxContainer
var _body: Control
var _backdrop: Control
var _battle: BattleScreen
var _area: HBoxContainer
var _map: Control
var _page_holder: Control
var _view_key: String = ""
var _landing_tab: String = "haul"
var _toasts: VBoxContainer
var _fresh: bool = true
var _struck: int = -1
var _headless: bool = false
var _curtain: ColorRect
var _hold: Dictionary = {}
var _last_chamber: Dictionary = {}
var _last_battle: Dictionary = {}
var _shown_depth: int = -1
var _counts: Dictionary = {}

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
	_backdrop = Backdrop.new()
	_body.add_child(_backdrop)
	_battle = BattleScreen.new()
	_battle.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	_battle.visible = false
	_body.add_child(_battle)
	_area = HBoxContainer.new()
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_theme_constant_override("separation", 0)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_area)
	var map_margin := DeepUi.margin(_area, 18)
	map_margin.add_theme_constant_override("margin_right", 0)
	_map = ShaftMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.vote.connect(func(offer_id: String) -> void: command.emit({"kind": "vote_tunnel", "offer": offer_id}))
	_map.light.connect(func() -> void: command.emit({"kind": "light"}))
	map_margin.add_child(_map)
	_page_holder = Control.new()
	_page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_page_holder)
	## A curtain of dark that lifts whenever the party walks into or out of a fight: the room
	## is built while it is down, and the descent reads as a descent.
	_curtain = ColorRect.new()
	_curtain.color = Color(0.01, 0.01, 0.015, 1.0)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.modulate.a = 0.0
	_body.add_child(_curtain)
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
	## A new run starts with a clean slate: nothing held, nothing counted.
	_hold = {}
	_counts = {}
	_shown_depth = -1
	_last_chamber = {}
	_last_battle = {}

func apply_quality() -> void:
	_battle.apply_quality()

func _celebrate(pill: Control, text: String, colour: Color) -> void:
	if _headless or not is_instance_valid(pill) or not pill.is_inside_tree():
		return
	DeepUi.pulse(pill, 1.3, 0.45)
	var at: Vector2 = pill.global_position + Vector2(pill.size.x * 0.5, pill.size.y + 4.0) - global_position
	var label := DeepUi.float_text(self, at, text, colour, 20, -34.0, 1.3)
	label.z_index = 30
	DeepUi.burst(self, at, colour, 14, 140.0, 0.5, 5.0)

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
	_sync_strip()
	## A held page gives way the moment the party is somewhere new without us.
	if not _hold.is_empty() and _hold_is_stale():
		_hold = {}
	var depth: int = int(run.get("depth", 0))
	if depth != _shown_depth:
		if _shown_depth >= 0 and depth > _shown_depth and phase in ["chamber", "landing"]:
			_depth_card(depth, "landing" if phase == "landing" else str(run.chamber.get("kind", "fight")))
		_shown_depth = depth
	var key: String = phase
	if phase == "chamber":
		key += ":" + str(run.chamber.get("kind", "")) + ":" + str(run.depth) + (":battle" if DeepDescent.in_battle(run) else ":" + str(bool(run.chamber.get("settled", false))))
	elif phase == "landing":
		key += ":" + str(run.depth) + ":" + _landing_tab
	elif phase == "tunnels":
		key += ":" + str(run.depth)
	if not _hold.is_empty():
		key = "hold:%s:%s:%d" % [str(_hold.kind), str(_hold.get("stage", "")), int(_hold.get("depth", 0))]
	_fresh = key != _view_key
	_view_key = key
	var mine: String = str(run.get("mine", ""))
	if not _hold.is_empty() and str(_hold.get("stage", "")) == "battle":
		## The fight is over but its last moments are still playing: keep the room up.
		_battle.visible = true
		_area.visible = false
		_backdrop.visible = false
		return
	if DeepDescent.in_battle(run) != _battle.visible and _hold.is_empty():
		_lift_curtain(0.75 if DeepDescent.in_battle(run) else 0.45)
	if DeepDescent.in_battle(run):
		_battle.visible = true
		_area.visible = false
		_backdrop.visible = false
		DeepUi.clear(_page_holder)
		var forecast: Dictionary = forecast_provider.call() if forecast_provider.is_valid() else {}
		_battle.show_state(DeepDescent.battle(run), int(run.depth), forecast, {"mine": mine, "kind": str(run.chamber.get("kind", "fight"))})
		return
	_battle.visible = false
	_area.visible = true
	_backdrop.visible = true
	_backdrop.show_biome(mine, maxi(1, int(run.get("depth", 0)) + (1 if phase == "tunnels" else 0)))
	_map.show_run(run)
	## Everything outside a fight is a page: cheap to rebuild whenever the state moves.
	DeepUi.clear(_page_holder)
	var content := _page()
	if not _hold.is_empty():
		match str(_hold.kind):
			"victory", "spoils": _page_spoils(content)
			"vein": _page_vein(content, _hold.chamber, true)
			"oddity": _page_oddity_result(content)
		_struck = -1
		return
	match phase:
		"tunnels": _page_tunnels(content)
		"chamber":
			match str(run.chamber.get("kind", "")):
				"vein", "vug": _page_vein(content, run.chamber, false)
				"oddity": _page_oddity(content)
				_: _page_tunnels(content)
		"landing": _page_landing(content)
		"hoard": _page_hoard(content)
		"salvage": _page_salvage(content)
		"over": _page_over(content)
	_struck = -1

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
	_lift_curtain(0.35)
	show_state(run)

func _after_fight(token: int, stage: String) -> void:
	## The last blow has landed and the banner has had its moment: on to the spoils.
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	if stage == "spoils":
		_hold.stage = "spoils"
	else:
		_hold = {}
	_lift_curtain(0.55)
	show_state(run)

func _lift_curtain(seconds: float) -> void:
	if _headless:
		return
	_body.move_child(_curtain, _body.get_child_count() - 1)
	_curtain.modulate.a = 1.0
	var tween := _curtain.create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(_curtain, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _depth_card(depth: int, kind: String) -> void:
	## A title across the dark as the party arrives somewhere new: the depth, what the
	## chamber is, and the biome it is in. It lifts on its own and never blocks a click.
	if _headless:
		return
	DeepAudio.play("tunnel", {"volume": 0.8})
	DeepAudio.play("depth_card", {"delay": 0.3})
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(card)
	var dark := ColorRect.new()
	dark.color = Color(0.01, 0.01, 0.015, 1.0)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dark)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(centre)
	var column := DeepUi.vbox(centre, 6)
	var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.ACCENT)
	var mark := DeepUi.icon(column, str(DeepUi.CHAMBER_GLYPHS.get(kind, "stairs")), 54, tone)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.title(column, "Depth %d" % depth, 54, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var words: String = str(KIND_WORDS.get(kind, kind.capitalize())) if kind != "warden" else "A Warden"
	var biome: Dictionary = Biomes.for_depth(str(run.get("mine", "")), depth)
	DeepUi.label(column, "%s  ·  %s" % [words, str(biome.get("name", ""))], 17, tone.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.pop_in(column, 0.0, 1.15, 0.45)
	var tween := card.create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(card, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(card.queue_free)

func _page() -> VBoxContainer:
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_holder.add_child(page)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(centre)
	var margin := DeepUi.margin(centre, 28, 22)
	var content := DeepUi.vbox(margin, 18)
	content.custom_minimum_size.x = 940
	return content

func _enter(node: Control, delay: float = 0.0) -> void:
	## Only a new page eases in; a page rebuilt by a vote or a strike just appears.
	if _fresh:
		DeepUi.pop_in(node, delay)

func handle(event: Dictionary) -> void:
	## One event from the host. Fights are animated; everything else gets a line of text.
	var kind: String = str(event.get("kind", ""))
	match kind:
		"battle":
			if event.has("battle"):
				_battle.perform(event.battle)
			if event.has("resolution"):
				_battle.perform(event.resolution)
			if event.has("settle"):
				var settle: Dictionary = event.settle
				var fight: Dictionary = _last_battle
				if str(settle.get("outcome", "")) == "victory":
					_hold_page("victory", {"stage": "battle", "settle": settle, "rewards": settle.get("rewards", {}).get(local_id, {}),
						"chamber": str(settle.get("kind", "fight")), "turns": int(fight.get("turn", 1)),
						"slain": fight.get("enemies", []).map(func(e: Dictionary) -> String: return str(e.get("name", "")))})
					_later(2.3, _after_fight.bind(int(_hold.token), "spoils"))
				else:
					_hold_page("defeat", {"stage": "battle"})
					_later(2.8, _after_fight.bind(int(_hold.token), "release"))
		"vein_strike":
			var unit_id: String = str(event.get("unit", ""))
			DeepAudio.play("pick_strike", {"gap": 0.0})
			var found: Dictionary = event.get("result", {})
			match str(found.get("kind", "")):
				"stone": DeepAudio.play("stone_found", {"delay": 0.22})
				"ore": DeepAudio.play("ore", {"delay": 0.22, "volume": 0.8})
				"die": DeepAudio.play("die_settle", {"delay": 0.22})
			if unit_id == local_id:
				_struck = int(event.get("spot", -1))
			if bool(event.get("finished", false)):
				DeepAudio.play("rock_break", {"delay": 0.12, "volume": 0.8})
				if _last_chamber.has("vein"):
					## The rock is done. Keep it on screen, with this last blow in it, until
					## the player has seen what came out.
					var spots: Array = _last_chamber.vein.get("spots", [])
					var index: int = int(event.get("spot", -1))
					if index >= 0 and index < spots.size():
						spots[index].taken = unit_id
						spots[index].result = event.get("result", {})
					_hold_page("vein", {"chamber": _last_chamber})
		"oddity_result":
			if str(event.get("unit", "")) == local_id and bool(event.get("vug", false)):
				toast(str(event.get("message", "")), DeepUi.PAPER, "question")
			elif bool(event.get("finished", false)):
				var mine_result: Dictionary = _last_chamber.get("results", {}).get(local_id, {})
				if str(event.get("unit", "")) == local_id:
					mine_result = {"message": str(event.get("message", "")), "made": event.get("made", []), "lost": event.get("lost", [])}
				if not mine_result.is_empty():
					_hold_page("oddity", {"oddity": str(_last_chamber.get("oddity", "")), "result": mine_result})
		"appraised":
			if str(event.get("unit", "")) == local_id:
				var stone: Dictionary = event.stone
				var grade: Dictionary = DeepStone.grade(stone)
				DeepAudio.reveal_stone(stone)
				Inspector.stone(stone, {"fanfare": {"title": "Appraised", "subtitle": "A %s %s: %s" % [str(grade.name).to_lower(), str(DeepStone.skill_of(stone).get("name", "stone")), str(DeepStone.skill_of(stone).get("text", ""))], "button": "Into the bag"}})
		"hoard_pick":
			if str(event.get("unit", "")) == local_id:
				DeepAudio.reveal_stone(event.get("stone", {}))
				Inspector.stone(event.get("stone", {}), {"fanfare": {"title": "The hoard is yours", "subtitle": "Taken from the Warden's pile, appraised and ready to set.", "button": "Take it home"}})
		"given":
			toast("%s gave %s something." % [str(DeepDescent.player(run, str(event.get("from", ""))).get("name", "")), str(DeepDescent.player(run, str(event.get("to", ""))).get("name", ""))], DeepUi.INFO, "party")
		"bought":
			if str(event.get("unit", "")) == local_id:
				var item: Dictionary = event.get("item", {})
				DeepAudio.play("buy")
				match str(item.get("kind", "")):
					"stone": Inspector.stone(item.get("stone", {}), {"fanfare": {"title": "Bought", "subtitle": "It is in your bag.", "button": "Good"}})
					"die": Inspector.die(item.get("die", {}), {"fanfare": {"title": "Bought", "subtitle": "It waits in your bag; swap it in at the bench.", "button": "Good"}})
					_: toast("A new loupe.", DeepUi.INFO, "loupe")
		"motherlode":
			DeepAudio.play("stone_found")
			_hold_page("spoils", {"title": "A motherlode", "subtitle": "A hollow full of stones. Take them.", "glyph": "gem",
				"rewards": event.get("rewards", {}).get(local_id, {})})
		"landing":
			DeepAudio.play("landing")
			toast("The landing. Breathe.", DeepUi.GOOD, "lift")
		"lit":
			var who: String = str(DeepDescent.player(run, str(event.get("unit", ""))).get("name", ""))
			var paid: String = "a loupe" if str(event.get("method", "")) == "loupe" else "%d ore" % DeepDescent.lantern_cost()
			var lighter: String = "You light" if str(event.get("unit", "")) == local_id else "%s lights" % who
			DeepAudio.play("lantern")
			toast("%s the way to depth %d (%s)." % [lighter, int(event.get("to", 0)), paid], DeepUi.ACCENT, "lantern")
			if not _headless and is_instance_valid(_map) and _map.is_inside_tree():
				DeepUi.burst(self, _map.global_position - global_position + _map.size * Vector2(0.5, 0.35), DeepUi.ACCENT, 26, 220.0, 0.8, 5.0)
		"abandoned":
			_hold = {}
			toast("The dig is abandoned.", DeepUi.BAD, "flag")

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

# --- strip -----------------------------------------------------------------------------------

func _sync_strip() -> void:
	DeepUi.clear(_strip)
	var unit: Dictionary = me()
	var mine: Dictionary = DeepContent.mine(str(run.get("mine", "")))
	var place := DeepUi.hbox(_strip, 10)
	DeepUi.icon(place, "pick", 22, DeepUi.ACCENT)
	var names := DeepUi.vbox(place, 0)
	DeepUi.title(names, str(mine.get("name", "The mine")), 17, DeepUi.PAPER)
	var depth: int = int(run.get("depth", 0))
	var next_landing: int = (depth / DeepDescent.landing_every() + 1) * DeepDescent.landing_every()
	var note: String = "Landing in %d" % (next_landing - depth) if not DeepDescent.is_landing(depth) else "On a landing"
	if DeepDescent.is_warden_depth(next_landing) and not DeepDescent.is_landing(depth):
		note = "Warden in %d" % (next_landing - depth)
	DeepUi.label(names, "Depth %d  ·  %s" % [depth, note], 12, DeepUi.MUTED)
	## Progress to the next landing as a row of little steps.
	var steps := DeepUi.hbox(_strip, 3)
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var every: int = DeepDescent.landing_every()
	var into: int = depth % every
	for i in range(every):
		var lit: bool = i < into or (into == 0 and depth > 0)
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 6)
		pip.color = DeepUi.ACCENT if lit else Color(DeepUi.LINE_HI, 0.8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steps.add_child(pip)
	DeepUi.icon(steps, "crown" if DeepDescent.is_warden_depth(next_landing) else "lift", 16, DeepUi.BAD if DeepDescent.is_warden_depth(next_landing) else DeepUi.GOOD)
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
		var counts: Dictionary = {"ore": int(unit.get("ore", 0)), "loupes": int(unit.get("loupes", 0)), "haul": unit.get("haul", []).size()}
		var ore := DeepUi.pill(_strip, "ore", str(counts.ore), DeepUi.ORE, 14, "Ore: spent at merchants and lapidaries underground")
		var loupes := DeepUi.pill(_strip, "loupe", str(counts.loupes), DeepUi.INFO, 14, "Loupes: appraise a stone underground for free, or light the way ahead")
		var bag := DeepUi.pill(_strip, "bag", str(counts.haul), DeepUi.PAPER, 14, "Loose stones you carry. Open the Haul at a landing to see them.")
		## What changed since the last look swells and says by how much.
		if not _counts.is_empty():
			for entry in [["ore", ore, DeepUi.ORE], ["loupes", loupes, DeepUi.INFO], ["haul", bag, DeepUi.ACCENT]]:
				var change: int = int(counts[entry[0]]) - int(_counts.get(entry[0], counts[entry[0]]))
				if change != 0:
					call_deferred("_celebrate", entry[1], ("+%d" % change) if change > 0 else str(change), entry[2] if change > 0 else DeepUi.BAD)
		_counts = counts
	DeepUi.gear_button(_strip, func() -> void: menu_requested.emit())

# --- tunnels ---------------------------------------------------------------------------------

# --- spoils ----------------------------------------------------------------------------------

func _page_spoils(content: VBoxContainer) -> void:
	## What a chamber gave up, presented: a title, then each thing won lit up one at a time.
	var hold: Dictionary = _hold
	var title: String = str(hold.get("title", "Victory"))
	var glyph: String = str(hold.get("glyph", "sword"))
	var tone: Color = DeepUi.ACCENT
	var subtitle: String = str(hold.get("subtitle", ""))
	if str(hold.kind) == "victory":
		match str(hold.get("chamber", "fight")):
			"warden":
				title = "The Warden falls"
				glyph = "crown"
				tone = DeepUi.ACCENT_HI
			"elite":
				title = "Something big, beaten"
				glyph = "skull"
				tone = Color("ff8a70")
			_:
				title = "Victory"
				glyph = "sword"
				tone = DeepUi.GOOD
		var slain: Array = hold.get("slain", [])
		subtitle = "Depth %d  ·  %s  ·  %s" % [int(hold.depth), ", ".join(slain) if not slain.is_empty() else "the rock is quiet", DeepUi.plural(int(hold.get("turns", 1)), "turn")]
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
		## A spray of every stone colour off the medallion.
		var at := func() -> void:
			if is_instance_valid(medal):
				var centre: Vector2 = medal.size * 0.5
				for colour in ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]:
					DeepUi.burst(medal, centre, DeepUi.colour(colour), 22, 380.0, 1.2, 7.0)
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
	var tone: Color = DeepUi.CHAMBER_COLOURS.oddity
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new(str(ODDITY_GLYPHS.get(key, "question")), tone, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, str(oddity.get("name", "Something odd")), 36, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(head, str(result.get("message", "")), 19, tone.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(head)
	var made: Array = result.get("made", [])
	var lost: Array = result.get("lost", [])
	if not made.is_empty():
		var card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 16)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var box := DeepUi.vbox(card, 10)
		DeepUi.section(box, "gem", "What you have now")
		_reward_row(box, {"stones": made}, 0.3)
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
		var tone: Color = DeepUi.tier_colour(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.colour(DeepStone.colour(stone))
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
	func _init(colour: Color, delay: float) -> void:
		tone = colour
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

func _page_tunnels(content: VBoxContainer) -> void:
	## What the last chamber gave was shown on its own page; this one is only the way on.
	var unit: Dictionary = me()
	var next_depth: int = int(run.get("depth", 0)) + 1
	var head := DeepUi.vbox(content, 2)
	DeepUi.title(head, "Depth %d" % next_depth, 36, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var sub: String = "Choose a tunnel. The party goes where most of it points." if run.players.size() > 1 else "Choose a tunnel."
	if DeepDescent.is_landing(next_depth):
		sub = "The shaft opens onto a landing."
	DeepUi.label(head, sub, 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	var row := DeepUi.hbox(content, 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var nodes: Dictionary = run.get("map", {}).get("nodes", {})
	var index: int = 0
	for offer in run.get("offers", []):
		var node: Dictionary = nodes.get(str(offer.id), {})
		var seen: bool = DeepDescent.revealed(run, node) if not node.is_empty() else not bool(offer.get("hidden", false))
		var kind: String = str(offer.kind) if seen else "hidden"
		var voters: Array = []
		for other in run.players:
			if str(other.get("vote", "")) == str(offer.id):
				voters.append(str(other.name))
		## What lies past it, as far as the lantern shows.
		var beyond: Array = []
		if str(offer.kind) != "landing":
			for child in node.get("next", []):
				var after: Dictionary = nodes.get(str(child), {})
				if not after.is_empty():
					beyond.append({"kind": str(after.kind), "seen": DeepDescent.revealed(run, after), "glint": DeepDescent.glint(after), "depth": int(after.depth)})
		var card := TunnelCard.new(kind, str(offer.id), voters, str(unit.get("vote", "")) == str(offer.id), next_depth, beyond)
		var offer_id: String = str(offer.id)
		card.chosen.connect(func() -> void: command.emit({"kind": "vote_tunnel", "offer": offer_id}))
		card.mouse_entered.connect(func() -> void: _map.focus = offer_id)
		card.mouse_exited.connect(func() -> void:
			if _map.focus == offer_id:
				_map.focus = "")
		row.add_child(card)
		_enter(card, 0.12 + 0.1 * index)
		index += 1
	_map.focus = ""
	if not run.get("map", {}).is_empty() and not DeepDescent.is_landing(next_depth):
		var hint := DeepUi.hbox(content, 8)
		hint.alignment = BoxContainer.ALIGNMENT_CENTER
		var lit: bool = bool(run.map.get("lit", false))
		DeepUi.icon(hint, "lantern", 18, DeepUi.ACCENT)
		DeepUi.label(hint, "The way is lit to the landing." if lit else "Your lantern shows two depths ahead; past it, only glints. Hover a tunnel to trace where it leads.", 13, DeepUi.MUTED)
		_enter(hint, 0.3)

static func faceted(seed_value: int, cols: int = 7, rows: int = 5) -> Array:
	## A low-poly rock face in unit space: a jittered grid split into triangles, each lit by a
	## made-up height field so the facets catch an upper-left light the way cut stone does.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: Array = []
	var heights: Array = []
	for j in range(rows + 1):
		var row: Array = []
		var hrow: Array = []
		for i in range(cols + 1):
			var jitter := Vector2(rng.randf_range(-0.35, 0.35) / float(cols), rng.randf_range(-0.35, 0.35) / float(rows))
			if i == 0 or i == cols:
				jitter.x = 0.0
			if j == 0 or j == rows:
				jitter.y = 0.0
			row.append(Vector2(float(i) / float(cols), float(j) / float(rows)) + jitter)
			hrow.append(rng.randf_range(0.0, 1.0))
		points.append(row)
		heights.append(hrow)
	var light := Vector3(-0.5, -0.6, 0.62).normalized()
	var out: Array = []
	for j in range(rows):
		for i in range(cols):
			var corners: Array = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			var split: bool = rng.randf() > 0.5
			var tris: Array = [[0, 1, 2], [0, 2, 3]] if split else [[0, 1, 3], [1, 2, 3]]
			for tri in tris:
				var p: Array = []
				var h: Array = []
				for k in tri:
					var c: Array = corners[k]
					p.append(points[c[1]][c[0]])
					h.append(heights[c[1]][c[0]])
				var a := Vector3(p[0].x * cols, p[0].y * rows, h[0])
				var b := Vector3(p[1].x * cols, p[1].y * rows, h[1])
				var c3 := Vector3(p[2].x * cols, p[2].y * rows, h[2])
				var normal: Vector3 = (b - a).cross(c3 - a).normalized()
				if normal.z < 0.0:
					normal = -normal
				out.append({"poly": PackedVector2Array([p[0], p[1], p[2]]), "shade": clampf(normal.dot(light), -1.0, 1.0)})
	return out

static func draw_faceted(canvas: CanvasItem, facets: Array, rect: Rect2, base: Color, contrast: float = 0.22) -> void:
	for facet in facets:
		var poly := PackedVector2Array()
		for point in facet.poly:
			poly.append(rect.position + Vector2(point) * rect.size)
		var shade: float = float(facet.shade) * contrast
		canvas.draw_colored_polygon(poly, base.lightened(shade) if shade > 0.0 else base.darkened(-shade))

class TunnelCard extends PanelContainer:
	## A tunnel mouth in the rock: its dark, lit from inside by what waits there, the mark of
	## that thing hanging in it, and a line of what the party would get.
	signal chosen
	var kind: String
	var mouth: TunnelMouth
	func _init(tunnel_kind: String, offer_id: String, voters: Array, mine: bool, depth: int, beyond: Array = []) -> void:
		kind = tunnel_kind
		var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.MUTED)
		var style := DeepUi.raised(Color(0.05, 0.06, 0.085, 0.92), DeepUi.ACCENT if mine else Color(tone, 0.35), 16, 14, 0.55)
		if mine:
			style.set_border_width_all(2)
			style.shadow_color = Color(DeepUi.ACCENT, 0.3)
			style.shadow_size = 18
		add_theme_stylebox_override("panel", style)
		custom_minimum_size = Vector2(270, 0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var box := DeepUi.vbox(self, 10)
		mouth = TunnelMouth.new(kind, (offer_id + str(depth)).hash())
		box.add_child(mouth)
		DeepUi.title(box, str(KIND_WORDS.get(kind, kind.capitalize())), 21, tone.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.wrap(box, str(KIND_TEXT.get(kind, "")), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 240)
		if not beyond.is_empty():
			var leads := DeepUi.hbox(box, 6)
			leads.alignment = BoxContainer.ALIGNMENT_CENTER
			DeepUi.label(leads, "then", 12, DeepUi.DIM)
			for after in beyond:
				var shows: bool = bool(after.seen)
				var glint: String = str(after.glint)
				var after_kind: String = str(after.kind) if shows else "hidden"
				var mark: Color = DeepUi.CHAMBER_COLOURS.get(after_kind, DeepUi.MUTED)
				var glyph: String = str(DeepUi.CHAMBER_GLYPHS.get(after_kind, "arch"))
				var words: String = "Depth %d: %s" % [int(after.depth), str(KIND_WORDS.get(after_kind, after_kind.capitalize()))]
				if not shows:
					var glints: Dictionary = {"hostile": ["eye", Color("ff5a4a"), "something hostile"], "glittering": ["star", Color("ffd257"), "something glittering"],
						"strange": ["question", Color("b58cff"), "something strange"], "dark": ["question", DeepUi.DIM, "a dark mouth"]}
					var look: Array = glints.get(glint, glints.dark)
					glyph = str(look[0])
					mark = Color(look[1], 0.75)
					words = "Depth %d: past the lantern, %s" % [int(after.depth), str(look[2])]
				DeepUi.pill(leads, glyph, "", mark, 12, words)
		var votes := DeepUi.hbox(box, 6)
		votes.alignment = BoxContainer.ALIGNMENT_CENTER
		votes.custom_minimum_size.y = 22
		for voter in voters:
			DeepUi.stat(votes, "person", str(voter), DeepUi.ACCENT, 12)
		if mine:
			DeepUi.stat(votes, "check", "your pick", DeepUi.GOOD, 12)
		DeepUi.juice(self, 1.04)
		mouse_entered.connect(func() -> void: mouth.hover = true)
		mouse_exited.connect(func() -> void: mouth.hover = false)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DeepAudio.from(self, "ui_confirm", {"volume": 0.7})
			chosen.emit()
			DeepUi.pulse(self, 1.08, 0.3)

class TunnelMouth extends Control:
	var kind: String
	var hover: bool = false
	var _clock: float = 0.0
	var _heat: float = 0.0
	var _rock: Array = []
	var _kit = null
	var _mouth := PackedVector2Array()
	var _motes: Array = []
	func _init(tunnel_kind: String, seed_value: int) -> void:
		kind = tunnel_kind
		custom_minimum_size = Vector2(240, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_clock = rng.randf() * 10.0
		_kit = load("res://view/run/descent_screen.gd")
		_rock = _kit.faceted(seed_value, 8, 6)
		for i in range(14):
			_motes.append({"phase": rng.randf(), "angle": rng.randf_range(-1.2, 1.2), "speed": rng.randf_range(0.15, 0.35)})
		## The rock never moves: it is painted once, behind the light and the motes that do.
		var still := Control.new()
		still.show_behind_parent = true
		still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		still.draw.connect(_paint_rock.bind(still))
		add_child(still)
	func _process(delta: float) -> void:
		_clock += delta
		_heat = move_toward(_heat, 1.0 if hover else 0.0, delta * 4.0)
		queue_redraw()
	func _opening() -> PackedVector2Array:
		## The opening: a round-headed arch.
		var mouth := PackedVector2Array()
		var base_y: float = size.y * 0.98
		var half: float = size.x * 0.28
		var crown_y: float = size.y * 0.2
		var cx: float = size.x * 0.5
		mouth.append(Vector2(cx - half, base_y))
		for i in range(17):
			var angle: float = PI + PI * float(i) / 16.0
			mouth.append(Vector2(cx + cos(angle) * half, crown_y + half + sin(angle) * half + (half * 0.2 if i in [0, 16] else 0.0)))
		mouth.append(Vector2(cx + half, base_y))
		return mouth
	func _paint_rock(canvas: Control) -> void:
		var rock := Color("2a2622")
		var back := StyleBoxFlat.new()
		back.bg_color = rock.darkened(0.3)
		back.set_corner_radius_all(10)
		canvas.draw_style_box(back, Rect2(Vector2.ZERO, size))
		## Faceted rock around the opening.
		_kit.draw_faceted(canvas, _rock, Rect2(Vector2.ZERO, size), rock, 0.3)
		canvas.draw_colored_polygon(_opening(), Color(0.02, 0.02, 0.03))
	func _draw() -> void:
		var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.MUTED)
		var mouth: PackedVector2Array = _opening()
		var half: float = size.x * 0.28
		var crown_y: float = size.y * 0.2
		var cx: float = size.x * 0.5
		var flicker: float = 0.85 + 0.15 * sin(_clock * 7.0) * sin(_clock * 3.1 + 1.0)
		var glow: Texture2D = DeepUi.glow_texture()
		var inner := Vector2(half * 2.6, half * 2.4) * (1.0 + 0.2 * _heat)
		var inner_at := Vector2(cx, crown_y + half * 1.35)
		var strength: float = (0.55 if kind != "hidden" else 0.12) * flicker + 0.3 * _heat
		draw_texture_rect(glow, Rect2(inner_at - inner * 0.5, inner), false, Color(tone, strength))
		## Motes drifting out of the dark.
		for mote in _motes:
			var t: float = fmod(float(mote.phase) + _clock * float(mote.speed), 1.0)
			var at: Vector2 = inner_at + Vector2(sin(float(mote.angle)) * half * 1.6 * t, -half * 0.3 * t + half * 0.8 * t * t)
			draw_circle(at, 1.6 + 1.5 * (1.0 - t), Color(tone.lightened(0.4), (1.0 - t) * 0.8))
		## The mark of what waits, hanging in the dark.
		var bob: float = sin(_clock * 1.8) * 4.0
		var edge: float = 58.0 * (1.0 + 0.08 * _heat)
		var glyph: String = str(DeepUi.CHAMBER_GLYPHS.get(kind, "arch"))
		if kind == "hidden":
			## Two glints in the black that blink out of step.
			for side in [-1.0, 1.0]:
				var blink: float = clampf(sin(_clock * 0.9 + side) * 4.0, 0.0, 1.0)
				draw_circle(inner_at + Vector2(side * 12.0, bob), 3.0, Color(1.0, 0.9, 0.6, 0.7 * blink))
			glyph = "question"
			draw_texture_rect(GemIcons.texture(glyph, 96), Rect2(inner_at + Vector2(-edge * 0.5, -edge * 0.5 + 30.0 + bob), Vector2(edge, edge) * 0.7), false, Color(tone, 0.35))
		else:
			draw_texture_rect(glow, Rect2(inner_at - Vector2(edge, edge) + Vector2(0, bob), Vector2(edge, edge) * 2.0), false, Color(tone, 0.35))
			draw_texture_rect(GemIcons.texture(glyph, 96), Rect2(inner_at - Vector2(edge, edge) * 0.5 + Vector2(0, bob), Vector2(edge, edge)), false, tone.lightened(0.35))
		var loop := mouth.duplicate()
		draw_polyline(loop, Color(tone, 0.35 + 0.4 * _heat), 2.0, true)

# --- vein ------------------------------------------------------------------------------------

func _page_vein(content: VBoxContainer, chamber: Dictionary, finished: bool) -> void:
	var unit: Dictionary = me()
	var vein: Dictionary = chamber.get("vein", {})
	var hazard: bool = bool(vein.get("hazard", false))
	var head := DeepUi.vbox(content, 6)
	var title_row := DeepUi.hbox(head, 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, "pick", 32, DeepUi.CHAMBER_COLOURS.vein)
	DeepUi.title(title_row, "The vug" if hazard else "A vein", 34, DeepUi.PAPER)
	var strikes: int = 0 if finished else int(unit.get("strikes", 0))
	var total: int = DeepDescent.VEIN_STRIKES
	var status := DeepUi.hbox(head, 8)
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	if finished:
		DeepUi.stat(status, "check", "The rock is spent. Here is what came out of it.", DeepUi.GOOD, 16)
	elif strikes > 0:
		DeepUi.label(status, "Pick a spot to strike." if strikes == total else "One more strike.", 16, DeepUi.PAPER)
		for i in range(total):
			var pick := DeepUi.icon(status, "pick", 26, DeepUi.ACCENT if i < strikes else Color(DeepUi.DIM, 0.4), "Strikes left: %d of %d" % [strikes, total])
			if i < strikes:
				DeepUi.breathe(pick, 0.6, 1.4)
		DeepUi.label(status, "%d of %d left" % [strikes, total], 14, DeepUi.MUTED)
	else:
		var waiting: Array = run.players.filter(func(p: Dictionary) -> bool: return int(p.get("strikes", 0)) > 0 and not bool(p.get("downed", false)))
		DeepUi.stat(status, "hourglass", "Your arm is spent. Waiting for " + ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))) + ".", DeepUi.MUTED, 15)
	if hazard and not finished:
		DeepUi.stat(head, "heart", "Every strike here costs 3 HP.", DeepUi.BAD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
	_enter(head)
	if not finished:
		var legend := DeepUi.hbox(content, 22)
		legend.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.stat(legend, "spark", "bright: likely a fine stone", Color("ffcf5a"), 12)
		DeepUi.stat(legend, "spark", "glint: a stone or a die", DeepUi.INFO, 12)
		DeepUi.stat(legend, "ore", "dull: ore or dust", DeepUi.MUTED, 12)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(grid)
	var index: int = 0
	var cards: Array = []
	for spot in vein.get("spots", []):
		var taken: String = str(spot.get("taken", ""))
		var card := VeinSpot.new(spot, str(DeepDescent.player(run, taken).get("name", taken)) if not taken.is_empty() else "", strikes > 0, taken == local_id)
		var spot_index: int = int(spot.index)
		card.struck.connect(func() -> void:
			## One blow per click: every other spot goes still until the rock answers.
			for other in cards:
				if is_instance_valid(other):
					other.call("close")
			command.emit({"kind": "strike", "spot": spot_index}))
		grid.add_child(card)
		cards.append(card)
		_enter(card, 0.08 + 0.06 * index)
		if spot_index == _struck and not _headless:
			card.reveal()
		index += 1
	if finished:
		var mine: Array = vein.get("spots", []).filter(func(s: Dictionary) -> bool: return str(s.get("taken", "")) == local_id)
		var rewards: Dictionary = {"ore": 0, "stones": [], "dice": []}
		for spot in mine:
			var result: Dictionary = spot.get("result", {})
			match str(result.get("kind", "")):
				"stone": rewards.stones.append(result.get("stone", {}))
				"ore": rewards.ore = int(rewards.ore) + int(result.get("ore", 0))
				"die": rewards.dice.append(result.get("die", {}))
		var take := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 16)
		take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var take_box := DeepUi.vbox(take, 10)
		DeepUi.section(take_box, "bag", "Into your bag")
		_reward_row(take_box, rewards, 0.35)
		_enter(take, 0.2)
		var go := DeepUi.primary(content, "descend", "Onward", _release, 18)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.custom_minimum_size.x = 240
		_enter(go, 0.5)

class VeinSpot extends PanelContainer:
	## A patch of the wall: cracked rock with a glint in it, or the hole where someone struck.
	signal struck
	var spot: Dictionary
	var face: VeinFace
	var _open: bool
	func _init(vein_spot: Dictionary, finder: String, can_strike: bool, mine: bool = false) -> void:
		spot = vein_spot
		var taken: bool = not str(spot.get("taken", "")).is_empty()
		_open = not taken and can_strike
		var glint: String = str(spot.get("glint", "dull"))
		var tone: Color = Color("ffcf5a") if glint == "bright" else (DeepUi.INFO if glint == "glint" else DeepUi.MUTED)
		var style := DeepUi.raised(Color(0.05, 0.05, 0.06, 0.92), DeepUi.ACCENT if mine else Color(tone, 0.5 if not taken else 0.2), 14, 8, 0.5)
		if mine:
			style.set_border_width_all(2)
		add_theme_stylebox_override("panel", style)
		if not taken and not can_strike:
			modulate = Color(1, 1, 1, 0.55)
		custom_minimum_size = Vector2(250, 0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _open else Control.CURSOR_ARROW
		var box := DeepUi.vbox(self, 6)
		face = VeinFace.new(glint, int(spot.index) * 7919 + 13, taken)
		box.add_child(face)
		if taken:
			var result: Dictionary = spot.get("result", {})
			var line := DeepUi.hbox(face, 8)
			line.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			match str(result.get("kind", "")):
				"stone":
					StoneCard.mini(line, result.get("stone", {}), 72)
				"ore":
					DeepUi.stat(line, "ore", "%d" % int(result.get("ore", 0)), DeepUi.ORE, 26)
				"die":
					line.add_child(Thumbs.DieThumb.new(result.get("die", {}), 64))
				_:
					DeepUi.stat(line, "cloud", "dust", DeepUi.DIM, 18)
			var words: String = ""
			match str(result.get("kind", "")):
				"stone": words = DeepStone.raw_name(result.get("stone", {}))
				"ore": words = "%d ore" % int(result.get("ore", 0))
				"die": words = DeepDice.describe(result.get("die", {}))
				_: words = "nothing but dust"
			DeepUi.label(box, words, 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			DeepUi.stat(box, "person", finder, DeepUi.MUTED, 11).alignment = BoxContainer.ALIGNMENT_CENTER
		else:
			DeepUi.label(box, {"bright": "Something bright", "glint": "A glint", "dull": "Dull rock"}.get(glint, "Rock"), 15, tone, HORIZONTAL_ALIGNMENT_CENTER)
			DeepUi.label(box, "Click to strike" if _open else " ", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if _open:
			DeepUi.juice(self, 1.04)
			mouse_entered.connect(func() -> void: face.hover = true)
			mouse_exited.connect(func() -> void: face.hover = false)
	func _gui_input(event: InputEvent) -> void:
		if _open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			face.strike()
			struck.emit()
	func close() -> void:
		_open = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	func reveal() -> void:
		## The blow that opened this spot: the rock bursts and what was in it pops out.
		face.strike()
		var result: Dictionary = spot.get("result", {})
		var tone: Color = {"stone": Color("ffcf5a"), "ore": DeepUi.ORE, "die": DeepUi.INFO}.get(str(result.get("kind", "")), DeepUi.MUTED)
		var tween := create_tween()
		tween.tween_interval(0.05)
		tween.tween_callback(func() -> void:
			DeepUi.pulse(self, 1.12, 0.45)
			DeepUi.burst(self, size * 0.5, tone, 36, 260.0, 0.8, 6.0))

class VeinFace extends Control:
	var glint: String
	var taken: bool
	var hover: bool = false
	var _clock: float = 0.0
	var _hit: float = 0.0
	var _cracks: Array = []
	var _chunks: Array = []
	var _kit = null
	var _sparks: Array = []
	func _init(kind: String, seed_value: int, is_taken: bool) -> void:
		glint = kind
		taken = is_taken
		custom_minimum_size = Vector2(230, 130)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_kit = load("res://view/run/descent_screen.gd")
		_chunks = _kit.faceted(seed_value, 7, 4)
		for i in range(4):
			var start := Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7))
			var path := [start]
			for j in range(4):
				path.append(Vector2(path.back()) + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15)))
			_cracks.append(path)
		var count: int = {"bright": 9, "glint": 5, "dull": 2}.get(kind, 2)
		for i in range(count):
			_sparks.append({"at": Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7)), "phase": rng.randf() * TAU, "rate": rng.randf_range(1.5, 3.5)})
	func strike() -> void:
		_hit = 1.0
	func _process(delta: float) -> void:
		_clock += delta
		_hit = maxf(0.0, _hit - delta * 2.5)
		queue_redraw()
	func _draw() -> void:
		var rock := Color("3a332c") if glint != "bright" else Color("40362a")
		var shake := Vector2(sin(_clock * 60.0), cos(_clock * 53.0)) * 4.0 * _hit
		var back := StyleBoxFlat.new()
		back.bg_color = rock.darkened(0.35)
		back.set_corner_radius_all(8)
		draw_style_box(back, Rect2(shake, size))
		_kit.draw_faceted(self, _chunks, Rect2(shake, size), rock.lightened(0.06 * float(hover)), 0.28)
		var glow: Texture2D = DeepUi.glow_texture()
		if taken:
			## The hole the pick left.
			var hole := Vector2(size.x * 0.46, size.y * 0.78)
			draw_texture_rect(glow, Rect2(size * 0.5 - hole * 0.5 + shake, hole), false, Color(0, 0, 0, 0.85))
		for crack in _cracks:
			var pts := PackedVector2Array()
			for p in crack:
				pts.append(Vector2(p) * size + shake)
			draw_polyline(pts, Color(0, 0, 0, 0.55), 2.0, true)
		if not taken:
			var tone: Color = Color("ffcf5a") if glint == "bright" else (Color("bfe0ff") if glint == "glint" else Color("a09080"))
			var pulse: float = 0.6 + 0.4 * sin(_clock * 2.0)
			if glint != "dull":
				var halo := Vector2(size.y, size.y) * (0.9 if glint == "bright" else 0.6) * (1.0 + 0.1 * pulse + 0.2 * float(hover))
				draw_texture_rect(glow, Rect2(size * 0.5 - halo * 0.5 + shake, halo), false, Color(tone, 0.25 * pulse + 0.15 * float(hover)))
			for s in _sparks:
				var twinkle: float = maxf(0.0, sin(_clock * float(s.rate) + float(s.phase)))
				var at: Vector2 = Vector2(s.at) * size + shake
				var arm: float = (5.0 if glint == "dull" else 9.0) * twinkle
				draw_line(at - Vector2(arm, 0), at + Vector2(arm, 0), Color(tone, twinkle), 1.5, true)
				draw_line(at - Vector2(0, arm), at + Vector2(0, arm), Color(tone, twinkle), 1.5, true)
				draw_circle(at, 1.5 + twinkle, Color(1, 1, 1, twinkle * (0.9 if glint != "dull" else 0.4)))
		if _hit > 0.0:
			draw_texture_rect(glow, Rect2(size * 0.5 - size * 0.6, size * 1.2), false, Color(1, 0.9, 0.7, 0.5 * _hit))

# --- oddity ----------------------------------------------------------------------------------

func _page_oddity(content: VBoxContainer) -> void:
	if _fresh:
		DeepAudio.play("oddity", {"volume": 0.8})
	var unit: Dictionary = me()
	var key: String = str(run.chamber.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var tone: Color = DeepUi.CHAMBER_COLOURS.oddity
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
		for stone in mine_result.get("made", []):
			StoneCard.build(box, stone, {"size": 72, "text_width": 520})
		_enter(result_card, 0.1)
		var waiting: Array = run.players.filter(func(p: Dictionary) -> bool: return str(p.get("oddity_choice", "")).is_empty() and not bool(p.get("downed", false)))
		if not waiting.is_empty():
			DeepUi.stat(content, "hourglass", "Waiting for " + ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))), DeepUi.MUTED, 14).alignment = BoxContainer.ALIGNMENT_CENTER
		return
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var index: int = 0
	var choices: Array = oddity.get("choices", [])
	for choice in choices:
		var leave: bool = index == choices.size() - 1 and str(choice.get("needs", "")).is_empty() and choices.size() > 1 and str(choice.get("action", {}).get("kind", "none")) == "none"
		var card := DeepUi.card(row, Color(tone, 0.4) if not leave else DeepUi.LINE, 16)
		card.custom_minimum_size = Vector2(300 if not leave else 220, 0)
		var box := DeepUi.vbox(card, 10)
		var title_row := DeepUi.hbox(box, 8)
		DeepUi.icon(title_row, "cross_out" if leave else str(ODDITY_GLYPHS.get(key, "question")), 20, DeepUi.MUTED if leave else tone)
		DeepUi.title(title_row, str(choice.get("label", choice.id)), 19, DeepUi.PAPER)
		if choice.has("text"):
			DeepUi.wrap(box, str(choice.text), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 260)
		var needs: String = str(choice.get("needs", ""))
		var payload_of: Callable = _picker(box, needs, unit)
		DeepUi.spacer(box, false)
		var button: Button
		if leave:
			button = DeepUi.icon_button(box, "cross_out", "Walk on", func() -> void: command.emit({"kind": "oddity", "choice": str(choice.id), "payload": {}}), 15, DeepUi.MUTED)
		else:
			button = DeepUi.primary(box, "check", "Choose", func() -> void:
				command.emit({"kind": "oddity", "choice": str(choice.id), "payload": payload_of.call()}), 16, tone)
		if needs != "" and payload_of.call().is_empty():
			button.disabled = true
			DeepUi.stat(box, "cross_out", "You have nothing this could be done to.", DeepUi.DIM, 12)
		_enter(card, 0.12 + 0.08 * index)
		index += 1

class Medallion extends Control:
	## A big mark in a ring of light that turns slowly: the face of an oddity or an ending.
	var glyph: String
	var tone: Color
	var _clock: float = 0.0
	func _init(mark: String, colour: Color, edge: float = 120.0) -> void:
		glyph = mark
		tone = colour
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

func _picker(box: VBoxContainer, needs: String, unit: Dictionary) -> Callable:
	## The controls a choice needs, and a callable that reads them into a payload.
	if needs.is_empty():
		return func() -> Dictionary: return {}
	var stones: Array = unit.get("haul", []).duplicate()
	for stone in unit.get("rail", []):
		if stone is Dictionary:
			stones.append(stone)
	var dice: Array = unit.get("dice", []) + unit.get("bag_dice", [])
	var row := DeepUi.vbox(box, 6)
	match needs:
		"stone":
			var pick := _stone_options(row, stones)
			return func() -> Dictionary: return {} if pick.item_count == 0 else {"stone_id": str(pick.get_item_metadata(pick.selected))}
		"two_stones":
			DeepUi.label(row, "Keep", 12, DeepUi.MUTED)
			var keep := _stone_options(row, stones)
			DeepUi.label(row, "Feed", 12, DeepUi.MUTED)
			var feed := _stone_options(row, stones)
			if feed.item_count > 1:
				feed.select(1)
				feed.item_selected.emit(1)
			return func() -> Dictionary: return {} if stones.size() < 2 else {"keep_id": str(keep.get_item_metadata(keep.selected)), "feed_id": str(feed.get_item_metadata(feed.selected))}
		"inclusion", "copy_inclusion":
			var carriers: Array = stones.filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false))))
			var from := _stone_options(row, carriers)
			var which := _options(row, [])
			var refill: Callable = func() -> void:
				which.clear()
				if from.item_count == 0:
					return
				var stone: Dictionary = DeepOddities.find_stone(unit, str(from.get_item_metadata(from.selected)))
				for key in stone.get("inclusions", []):
					which.add_item(str(DeepContent.inclusion(str(key)).get("name", key)))
					which.set_item_metadata(which.item_count - 1, str(key))
			refill.call()
			from.item_selected.connect(func(_i: int) -> void: refill.call())
			if needs == "inclusion":
				return func() -> Dictionary: return {} if from.item_count == 0 or which.item_count == 0 else {"stone_id": str(from.get_item_metadata(from.selected)), "inclusion": str(which.get_item_metadata(which.selected))}
			DeepUi.label(row, "onto", 12, DeepUi.MUTED)
			var to := _stone_options(row, stones)
			return func() -> Dictionary: return {} if from.item_count == 0 or which.item_count == 0 or to.item_count == 0 else {"from_id": str(from.get_item_metadata(from.selected)), "inclusion": str(which.get_item_metadata(which.selected)), "to_id": str(to.get_item_metadata(to.selected))}
		"die", "die_face", "die_engraving":
			var pick := _options(row, dice.map(func(d: Dictionary) -> Array: return [str(d.id), DeepDice.describe(d)]))
			var preview := DeepUi.hbox(row, 6)
			var show_die: Callable = func() -> void:
				DeepUi.clear(preview)
				if pick.item_count > 0:
					var die: Dictionary = DeepOddities.find_die(unit, str(pick.get_item_metadata(pick.selected)))
					preview.add_child(Thumbs.DieThumb.new(die, 44))
					for f in die.get("faces", []):
						preview.add_child(DiceIcons.face(20, int(f.value), DiceIcons.palette(str(die.get("key", "D6"))).body, str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))
			show_die.call()
			pick.item_selected.connect(func(_i: int) -> void: show_die.call())
			if needs == "die":
				return func() -> Dictionary: return {} if pick.item_count == 0 else {"die_id": str(pick.get_item_metadata(pick.selected))}
			if needs == "die_face":
				var face := _options(row, [])
				var refill_faces: Callable = func() -> void:
					face.clear()
					if pick.item_count == 0:
						return
					var die: Dictionary = DeepOddities.find_die(unit, str(pick.get_item_metadata(pick.selected)))
					for index in range(die.get("faces", []).size()):
						face.add_item("face %d: %s" % [index + 1, DiceIcons.face_text(int(die.faces[index].value), str(die.faces[index].kind))])
						face.set_item_metadata(face.item_count - 1, index)
				refill_faces.call()
				pick.item_selected.connect(func(_i: int) -> void: refill_faces.call())
				return func() -> Dictionary: return {} if pick.item_count == 0 or face.item_count == 0 else {"die_id": str(pick.get_item_metadata(pick.selected)), "face": int(face.get_item_metadata(face.selected))}
			var engraving := _options(row, DeepDice.ENGRAVINGS.map(func(e: String) -> Array: return [e, e.replace("_", " ")]))
			return func() -> Dictionary: return {} if pick.item_count == 0 else {"die_id": str(pick.get_item_metadata(pick.selected)), "engraving": str(engraving.get_item_metadata(engraving.selected))}
		"pattern":
			var kinds: Array = DeepPatterns.KINDS.filter(func(k: String) -> bool: return k != "always" and k != "resonance")
			var pick := _options(row, kinds.map(func(k: String) -> Array: return [k, k.replace("_", " ")]))
			return func() -> Dictionary: return {"pattern": str(pick.get_item_metadata(pick.selected))}
	return func() -> Dictionary: return {}

func _stone_options(parent: Node, stones: Array) -> OptionButton:
	## A stone picker with a picture of the stone it has chosen beside it.
	var row := DeepUi.hbox(parent, 8)
	var holder := DeepUi.center(row)
	holder.custom_minimum_size = Vector2(46, 46)
	var pick := _options(row, stones.map(func(s: Dictionary) -> Array: return [str(s.id), DeepUi.stone_name(s)]))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.clip_text = true
	pick.custom_minimum_size.x = 180
	var show: Callable = func() -> void:
		DeepUi.clear(holder)
		if pick.item_count > 0:
			var id: String = str(pick.get_item_metadata(pick.selected))
			for stone in stones:
				if str(stone.id) == id:
					StoneCard.mini(holder, stone, 42)
	show.call()
	pick.item_selected.connect(func(_i: int) -> void: show.call())
	return pick

func _options(parent: Node, entries: Array) -> OptionButton:
	var pick := OptionButton.new()
	for entry in entries:
		pick.add_item(str(entry[1]))
		pick.set_item_metadata(pick.item_count - 1, entry[0])
	if pick.item_count > 0:
		pick.selected = 0
	pick.pressed.connect(func() -> void: DeepAudio.play("ui_tap"))
	pick.item_selected.connect(func(_i: int) -> void: DeepAudio.play("ui_toggle", {"volume": 0.7}))
	parent.add_child(pick)
	return pick

# --- landing ---------------------------------------------------------------------------------

func _page_landing(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var landing: Dictionary = run.get("landing", {})
	var head := DeepUi.vbox(content, 4)
	var title_row := DeepUi.hbox(head, 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, "lift", 30, DeepUi.CHAMBER_COLOURS.landing)
	DeepUi.title(title_row, "The landing at depth %d" % int(run.depth), 32, DeepUi.PAPER)
	var notes := DeepUi.hbox(head, 10)
	notes.alignment = BoxContainer.ALIGNMENT_CENTER
	if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
		DeepUi.pill(notes, "crown", "A Warden guards the way down", DeepUi.BAD, 13)
	if bool(landing.get("cleared", false)):
		DeepUi.pill(notes, "check", "The Warden is dead", DeepUi.GOOD, 13)
	if notes.get_child_count() == 0:
		DeepUi.label(notes, "Solid ground. Sort what you carry, then choose: up or down.", 14, DeepUi.MUTED)
	_enter(head)
	var tabs := DeepUi.hbox(content, 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in LANDING_TABS:
		var key: String = str(entry[0])
		var badge: int = 0
		if key == "haul":
			badge = unit.get("haul", []).size()
		DeepUi.tab_button(tabs, str(entry[2]), str(entry[1]), _landing_tab == key, func() -> void:
			_landing_tab = key
			show_state(run), 16, badge)
	var body := DeepUi.vbox(content, 14)
	match _landing_tab:
		"haul": _landing_haul(body, unit)
		"bench": _landing_bench(body, unit)
		"merchant": _landing_merchant(body, unit, landing)
		"lift": _landing_lift(body, unit, landing)

func _empty(content: VBoxContainer, glyph: String, title: String, text: String) -> void:
	var card := DeepUi.card(content, DeepUi.LINE, 26)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 8)
	var mark := DeepUi.icon(box, glyph, 54, DeepUi.DIM)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.title(box, title, 20, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(box, text, 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 420)
	_enter(card, 0.05)

func _landing_haul(content: VBoxContainer, unit: Dictionary) -> void:
	var haul: Array = unit.get("haul", [])
	if haul.is_empty():
		_empty(content, "bag", "You carry no loose stones", "Stones you find wait in your bag until the lift takes them home, or you set them here.")
		return
	var cost: int = int(DeepContent.constant("appraise_ore_cost", 12))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(grid)
	var index: int = 0
	for stone in haul:
		var holder := DeepUi.vbox(grid, 6)
		holder.custom_minimum_size.x = 540
		var card := StoneCard.build(holder, stone, {"size": 80, "value": true})
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var actions := DeepUi.hbox(holder, 6)
		actions.alignment = BoxContainer.ALIGNMENT_END
		var id: String = str(stone.id)
		if not bool(stone.get("appraised", false)):
			var loupe := DeepUi.icon_button(actions, "loupe", "Appraise with a loupe", func() -> void: command.emit({"kind": "appraise", "stone_id": id, "with": "loupe"}), 13, DeepUi.INFO)
			loupe.disabled = int(unit.get("loupes", 0)) <= 0
			var ore := DeepUi.icon_button(actions, "ore", "Appraise for %d" % cost, func() -> void: command.emit({"kind": "appraise", "stone_id": id, "with": "ore"}), 13, DeepUi.ORE)
			ore.disabled = int(unit.get("ore", 0)) < cost
		else:
			DeepUi.icon_button(actions, "ore", "Sell for %d" % (DeepStone.value(stone) / 2), func() -> void: command.emit({"kind": "sell", "stone_id": id}), 13, DeepUi.ORE)
		for other in run.players:
			if str(other.id) != local_id and bool(other.get("connected", true)):
				var to: String = str(other.id)
				DeepUi.icon_button(actions, "party", "Give to %s" % str(other.name), func() -> void: command.emit({"kind": "give", "to": to, "item_id": id}), 13, DeepUi.INFO)
		_enter(holder, 0.06 * index)
		index += 1

func _landing_bench(content: VBoxContainer, unit: Dictionary) -> void:
	var rail_card := DeepUi.card(content, DeepUi.LINE, 16)
	var rail_box := DeepUi.vbox(rail_card, 10)
	DeepUi.section(rail_box, "gem", "Your rail")
	DeepUi.label(rail_box, "Set appraised stones from your haul. One stone of each skill; the last socket is the Capstone.", 13, DeepUi.MUTED)
	var rail_row := DeepUi.hbox(rail_box, 12)
	rail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var sockets: Array = unit.get("sockets", [])
	for index in range(unit.get("rail", []).size()):
		var socket_colour: String = str(sockets[index]) if index < sockets.size() else "ANY"
		var card := DeepUi.card(rail_row, Color(DeepUi.ACCENT if socket_colour == "CAPSTONE" else (DeepUi.colour(socket_colour) if socket_colour != "ANY" else DeepUi.LINE_HI), 0.5), 10, Color(0.05, 0.06, 0.085, 0.9))
		card.custom_minimum_size = Vector2(150, 0)
		var box := DeepUi.vbox(card, 6)
		var stone: Variant = unit.rail[index]
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(76, 76)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(slot)
		var ring := BattleScreen.SocketRing.new(socket_colour, not stone is Dictionary)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(ring)
		if stone is Dictionary:
			var thumb := StoneCard.mini(slot, stone, 62)
			thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
			DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", stone.skill)), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			var socket_index: int = index
			var out := DeepUi.icon_button(box, "cross_out", "Remove", func() -> void: command.emit({"kind": "unsocket", "index": socket_index}), 12, DeepUi.MUTED)
			out.disabled = DeepStone.is_locked(stone)
		else:
			DeepUi.label(box, "Capstone" if socket_colour == "CAPSTONE" else ("Any colour" if socket_colour == "ANY" else socket_colour.capitalize()), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var fitting: Array = unit.get("haul", []).filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)) and DeepStone.fits(s, socket_colour))
		if not fitting.is_empty():
			var pick := _options(box, fitting.map(func(s: Dictionary) -> Array: return [str(s.id), str(DeepStone.skill_of(s).get("name", s.skill))]))
			pick.clip_text = true
			var socket_index: int = index
			DeepUi.icon_button(box, "check", "Set", func() -> void: command.emit({"kind": "socket", "stone_id": str(pick.get_item_metadata(pick.selected)), "index": socket_index}), 12, DeepUi.GOOD)
		_enter(card, 0.05 * index)
	var dice_card := DeepUi.card(content, DeepUi.LINE, 16)
	var dice_box := DeepUi.vbox(dice_card, 10)
	DeepUi.section(dice_box, "die", "Your dice")
	var dice_row := DeepUi.hbox(dice_box, 12)
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(unit.get("dice", []).size()):
		var die: Dictionary = unit.dice[index]
		var card := DeepUi.card(dice_row, DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9))
		card.custom_minimum_size = Vector2(150, 0)
		var box := DeepUi.vbox(card, 6)
		var thumb := Thumbs.DieThumb.new(die, 64)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(thumb)
		DeepUi.label(box, DeepDice.describe(die), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		_faces_row(box, die, 18)
		if not unit.get("bag_dice", []).is_empty():
			var pick := _options(box, unit.bag_dice.map(func(d: Dictionary) -> Array: return [str(d.id), DeepDice.describe(d)]))
			var slot: int = index
			DeepUi.icon_button(box, "reroll", "Swap in", func() -> void: command.emit({"kind": "swap_die", "index": slot, "die_id": str(pick.get_item_metadata(pick.selected))}), 12, DeepUi.INFO)
		_enter(card, 0.05 * index)
	if not unit.get("bag_dice", []).is_empty():
		var bag := DeepUi.hbox(dice_box, 8)
		bag.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.stat(bag, "bag", "In your bag:", DeepUi.MUTED, 13)
		for die in unit.bag_dice:
			bag.add_child(Thumbs.DieThumb.new(die, 44))

func _faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	var row := DeepUi.hbox(parent, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tone: Color = DiceIcons.palette(str(die.get("key", "D6"))).body
	for f in die.get("faces", []):
		row.add_child(DiceIcons.face(edge, int(f.value), tone if str(f.kind) == "plain" else DiceIcons.face_kind_tint(str(f.kind)), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))
	return row

func _landing_merchant(content: VBoxContainer, unit: Dictionary, landing: Dictionary) -> void:
	var purse := DeepUi.hbox(content, 10)
	purse.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.pill(purse, "ore", "%d ore to spend" % int(unit.get("ore", 0)), DeepUi.ORE, 16)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(grid)
	var index: int = 0
	for item in landing.get("stock", []):
		var sold: String = str(item.get("sold", ""))
		var card := DeepUi.card(grid, DeepUi.LINE if sold.is_empty() else Color(DeepUi.LINE, 0.4), 14)
		card.custom_minimum_size = Vector2(300, 0)
		var box := DeepUi.vbox(card, 8)
		match str(item.kind):
			"stone":
				var stone: Dictionary = item.stone
				var grade: Dictionary = DeepStone.grade(stone)
				var row := DeepUi.hbox(box, 10)
				StoneCard.mini(row, stone, 76)
				var words := DeepUi.vbox(row, 3)
				words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				DeepUi.title(words, str(DeepStone.skill_of(stone).get("name", "")), 18, DeepUi.tier_colour(str(grade.tier)))
				DeepUi.label(words, "%s %s · %d ct" % [DeepContent.cut_name(int(stone.cut)), DeepContent.clarity_name(int(stone.clarity)), int(stone.carat)], 12, DeepUi.MUTED)
				DeepUi.pill(words, "star", str(grade.name), DeepUi.tier_colour(str(grade.tier)), 11).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				DeepUi.wrap(box, str(DeepStone.skill_of(stone).get("text", "")), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 270)
				card.tooltip_text = DeepStone.name(stone)
			"die":
				var die: Dictionary = item.die
				var row := DeepUi.hbox(box, 10)
				row.add_child(Thumbs.DieThumb.new(die, 72))
				var words := DeepUi.vbox(row, 4)
				DeepUi.title(words, DeepDice.describe(die), 18, DeepUi.PAPER)
				_faces_row(words, die, 18)
			"loupe":
				var row := DeepUi.hbox(box, 10)
				var frame := DeepUi.center(row)
				frame.custom_minimum_size = Vector2(72, 72)
				DeepUi.icon(frame, "loupe", 56, DeepUi.INFO)
				var words := DeepUi.vbox(row, 4)
				DeepUi.title(words, "A loupe", 18, DeepUi.PAPER)
				DeepUi.wrap(words, "Appraise one stone underground without spending ore.", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 180)
		DeepUi.spacer(box, false)
		if sold.is_empty():
			var id: String = str(item.id)
			var button := DeepUi.icon_button(box, "ore", "Buy for %d" % int(item.price), func() -> void: command.emit({"kind": "buy", "item_id": id}), 14, DeepUi.ORE)
			button.disabled = int(unit.get("ore", 0)) < int(item.price)
		else:
			card.modulate = Color(1, 1, 1, 0.55)
			DeepUi.stat(box, "check", "Sold to %s" % str(DeepDescent.player(run, sold).get("name", sold)), DeepUi.GOOD, 13)
		_enter(card, 0.05 * index)
		index += 1

func _landing_lift(content: VBoxContainer, unit: Dictionary, landing: Dictionary) -> void:
	var haul: Array = unit.get("haul", [])
	var worth: int = 0
	for stone in haul:
		worth += DeepStone.value(stone)
	var warden_ahead: bool = bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false))
	var conquered: bool = int(run.depth) >= int(DeepContent.constant("run_depth", 24)) and bool(landing.get("cleared", false))
	var row := DeepUi.hbox(content, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var scene := LiftScene.new(haul, warden_ahead)
	row.add_child(scene)
	_enter(scene)
	var side := DeepUi.vbox(row, 12)
	side.custom_minimum_size.x = 480
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(side, "Up, or down?", 30, DeepUi.PAPER)
	DeepUi.wrap(side, "You carry %s, worth about %d gold if they are what they look like. The lift takes everything home. Going down means bigger stones, and no way up until the next landing." % [DeepUi.plural(haul.size(), "stone"), worth], 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 460)
	if not haul.is_empty():
		var tiles := HFlowContainer.new()
		tiles.add_theme_constant_override("h_separation", 6)
		tiles.add_theme_constant_override("v_separation", 6)
		side.add_child(tiles)
		for stone in haul:
			StoneCard.mini(tiles, stone, 46)
	if warden_ahead:
		var warn := DeepUi.card(side, Color(DeepUi.BAD, 0.6), 12)
		DeepUi.stat(warn, "crown", "Going down means fighting the Warden first.", DeepUi.BAD, 14)
	var buttons := DeepUi.hbox(side, 12)
	var choice: String = str(unit.get("choice", ""))
	var lift := DeepUi.primary(buttons, "lift", "Ride the lift home" if not conquered else "Return victorious", func() -> void:
		DeepAudio.play("lift")
		command.emit({"kind": "choose", "choice": "lift"}), 17, DeepUi.GOOD)
	var down := DeepUi.primary(buttons, "descend", "Go deeper" if not conquered else "Go deeper (Endless)", func() -> void:
		DeepAudio.play("tunnel")
		command.emit({"kind": "choose", "choice": "descend"}), 17, DeepUi.BAD if warden_ahead else DeepUi.ACCENT)
	if choice == "lift":
		DeepUi.pulse(lift, 1.06)
		down.modulate.a = 0.6
	elif choice == "descend":
		DeepUi.pulse(down, 1.06)
		lift.modulate.a = 0.6
	var votes := DeepUi.hbox(side, 10)
	for other in run.players:
		if not str(other.get("choice", "")).is_empty():
			DeepUi.stat(votes, "lift" if str(other.choice) == "lift" else "descend", str(other.name), DeepUi.GOOD if str(other.choice) == "lift" else DeepUi.ACCENT, 13)
	if run.players.size() > 1:
		DeepUi.label(side, "The party goes where most of it points; a tie goes to the first seat.", 12, DeepUi.DIM)
	_enter(side, 0.1)

class LiftScene extends Control:
	## The cage in its shaft, the cable running up into the dark, and the haul's grades
	## shining up it as beams: what the party would lose by going down.
	var tiers: Array = []
	var danger: bool = false
	var _clock: float = 0.0
	func _init(haul: Array, warden_ahead: bool) -> void:
		custom_minimum_size = Vector2(300, 380)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		danger = warden_ahead
		for stone in haul:
			tiers.append(DeepUi.tier_colour(str(DeepStone.grade(stone).tier)) if bool(stone.get("appraised", false)) else DeepUi.colour(DeepStone.colour(stone)))
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var shaft := Rect2(Vector2(size.x * 0.2, 0), Vector2(size.x * 0.6, size.y))
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.03, 0.035, 0.05, 0.9)
		back.set_corner_radius_all(12)
		back.border_color = Color(DeepUi.LINE_HI, 0.5)
		back.set_border_width_all(1)
		draw_style_box(back, Rect2(Vector2.ZERO, size))
		## Light from the top of the shaft: the way home.
		var sky := Vector2(size.x * 0.9, size.y * 0.9)
		draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, 0) - sky * 0.5, sky), false, Color(Color("fff0c8"), 0.22 + 0.04 * sin(_clock * 1.2)))
		## Guide rails.
		for x in [shaft.position.x, shaft.end.x]:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(DeepUi.LINE_HI, 0.8), 3.0)
		var bob: float = sin(_clock * 1.4) * 3.0
		var cage := Rect2(Vector2(size.x * 0.27, size.y * 0.5 + bob), Vector2(size.x * 0.46, size.y * 0.36))
		## The cable.
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, cage.position.y), Color("8a8f98"), 2.0)
		## The haul's grades shining up the shaft.
		for i in range(tiers.size()):
			var tone: Color = tiers[i]
			var x: float = cage.position.x + cage.size.x * (float(i) + 0.5) / float(maxi(1, tiers.size()))
			var flicker: float = 0.7 + 0.3 * sin(_clock * 3.0 + float(i) * 1.7)
			var beam := Rect2(Vector2(x - 6, 0), Vector2(12, cage.position.y + cage.size.y * 0.5))
			draw_texture_rect(glow, Rect2(beam.position - Vector2(10, 0), beam.size + Vector2(20, 0)), false, Color(tone, 0.25 * flicker))
			draw_rect(Rect2(Vector2(x - 1.5, 0), Vector2(3, beam.size.y)), Color(tone, 0.5 * flicker))
			draw_circle(Vector2(x, cage.position.y + cage.size.y * 0.72), 7.0, tone)
			draw_texture_rect(glow, Rect2(Vector2(x, cage.position.y + cage.size.y * 0.72) - Vector2(20, 20), Vector2(40, 40)), false, Color(tone, 0.6))
		## The cage itself.
		draw_rect(cage, Color(0.12, 0.13, 0.16, 0.55))
		draw_rect(cage, Color("9aa0aa"), false, 3.0)
		for i in range(1, 5):
			var x: float = cage.position.x + cage.size.x * float(i) / 5.0
			draw_line(Vector2(x, cage.position.y), Vector2(x, cage.end.y), Color("6a707a"), 1.5)
		draw_rect(Rect2(cage.position - Vector2(6, 8), Vector2(cage.size.x + 12, 8)), Color("7a808a"))
		## Below: the dark going down, red if a Warden waits.
		var below := Vector2(size.x * 0.9, size.y * 0.5)
		draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, size.y) - below * 0.5, below), false, Color(DeepUi.BAD if danger else Color("5a3aff"), 0.25 + 0.1 * sin(_clock * 2.0)))

# --- hoard, salvage, over ---------------------------------------------------------------------

func _page_hoard(content: VBoxContainer) -> void:
	if _fresh:
		DeepAudio.play("stone_found", {"volume": 0.8})
	var mine_hoard: Dictionary = run.get("hoard", {}).get(local_id, {})
	var head := DeepUi.vbox(content, 4)
	var title_row := DeepUi.hbox(head, 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, "crown", 32, DeepUi.ACCENT)
	DeepUi.title(title_row, "The Warden's hoard", 34, DeepUi.ACCENT_HI)
	DeepUi.label(head, "Take one. They are appraised.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	var row := DeepUi.hbox(content, 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chosen: String = str(mine_hoard.get("chosen", ""))
	var index: int = 0
	for stone in mine_hoard.get("offers", []):
		var grade: Dictionary = DeepStone.grade(stone)
		var tone: Color = DeepUi.tier_colour(str(grade.tier))
		var card := DeepUi.card(row, Color(tone, 0.6), 14)
		card.custom_minimum_size = Vector2(300, 0)
		var box := DeepUi.vbox(card, 8)
		var pedestal := Pedestal.new(tone)
		box.add_child(pedestal)
		var view := GemView.new()
		view.anchor_left = 0.5
		view.anchor_right = 0.5
		view.offset_left = -65
		view.offset_right = 65
		view.offset_top = 22
		view.offset_bottom = 152
		view.set_drift(true)
		view.set_spin(0.6)
		view.inspectable = true
		view.configure(stone)
		pedestal.add_child(view)
		DeepUi.title(box, str(DeepStone.skill_of(stone).get("name", "")), 22, tone, HORIZONTAL_ALIGNMENT_CENTER)
		var tag_row := DeepUi.hbox(box, 8)
		tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.pill(tag_row, "star", str(grade.name), tone, 12)
		DeepUi.label(tag_row, "%s %s · %d ct" % [DeepContent.cut_name(int(stone.cut)), DeepContent.clarity_name(int(stone.clarity)), int(stone.carat)], 12, DeepUi.MUTED)
		DeepUi.wrap(box, str(DeepStone.skill_of(stone).get("text", "")), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 270)
		for key in stone.get("inclusions", []):
			DeepUi.stat(box, "spark", str(DeepContent.inclusion(str(key)).get("name", key)), DeepUi.INFO, 12).alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.spacer(box, false)
		var id: String = str(stone.id)
		var button := DeepUi.primary(box, "check", "Take it" if chosen != id else "Taken", func() -> void: command.emit({"kind": "pick_hoard", "stone_id": id}), 16, tone)
		button.disabled = not chosen.is_empty()
		if not chosen.is_empty() and chosen != id:
			card.modulate = Color(1, 1, 1, 0.5)
		_enter(card, 0.15 + 0.12 * index)
		index += 1
	if not chosen.is_empty():
		DeepUi.stat(content, "hourglass", "Waiting for the others to choose.", DeepUi.MUTED, 14).alignment = BoxContainer.ALIGNMENT_CENTER

class Pedestal extends Control:
	## A beam of light falling on a stone set on a plinth.
	var tone: Color
	var _clock: float = 0.0
	func _init(colour: Color) -> void:
		tone = colour
		custom_minimum_size = Vector2(300, 190)
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var cx: float = size.x * 0.5
		var beam := PackedVector2Array([Vector2(cx - 26, 0), Vector2(cx + 26, 0), Vector2(cx + 70, size.y - 30), Vector2(cx - 70, size.y - 30)])
		draw_colored_polygon(beam, Color(tone, 0.10 + 0.03 * sin(_clock * 2.0)))
		var pool := Vector2(220, 60)
		draw_texture_rect(glow, Rect2(Vector2(cx, size.y - 28) - pool * 0.5, pool), false, Color(tone, 0.45))
		var plinth := PackedVector2Array([Vector2(cx - 60, size.y - 30), Vector2(cx + 60, size.y - 30), Vector2(cx + 48, size.y - 8), Vector2(cx - 48, size.y - 8)])
		draw_colored_polygon(plinth, Color("2a2f3a"))
		draw_line(Vector2(cx - 60, size.y - 30), Vector2(cx + 60, size.y - 30), Color(tone, 0.7), 2.0)
		for i in range(6):
			var t: float = fmod(_clock * 0.3 + float(i) / 6.0, 1.0)
			var x: float = cx + sin(float(i) * 2.3) * 40.0 * t
			draw_circle(Vector2(x, lerpf(0.0, size.y - 40.0, t)), 1.5, Color(tone.lightened(0.5), 1.0 - t))

func _page_salvage(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var head := DeepUi.vbox(content, 4)
	var title_row := DeepUi.hbox(head, 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, "skull", 32, DeepUi.BAD)
	var abandoned: bool = bool(run.get("abandoned", false))
	DeepUi.title(title_row, "You abandon the dig" if abandoned else "The party falls", 34, DeepUi.BAD)
	DeepUi.label(head, ("The party runs for the lift and the rock takes its share. " if abandoned else "") + "Every raw stone rolls a die by its grade. Only the top face brings it home. Set stones are safe.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	var list := DeepUi.vbox(content, 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var index: int = 0
	for roll in run.get("salvage", {}).get(local_id, {}).get("rolls", []):
		var kept: bool = bool(roll.kept)
		var card := DeepUi.card(list, Color(DeepUi.GOOD if kept else DeepUi.BAD, 0.55), 12)
		card.custom_minimum_size = Vector2(620, 0)
		var row := DeepUi.hbox(card, 14)
		StoneCard.mini(row, roll.stone, 56)
		var box := DeepUi.vbox(row, 2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.title(box, DeepUi.stone_name(roll.stone), 17, DeepUi.tier_colour(str(roll.tier)))
		DeepUi.label(box, "A d%d, needing a %d" % [int(roll.sides), int(roll.sides)], 12, DeepUi.MUTED)
		var die := SalvageDie.new(int(roll.sides), int(roll.roll), kept, 0.35 + 0.45 * float(index) if _fresh and not _headless else -1.0)
		row.add_child(die)
		var verdict := DeepUi.stat(row, "check" if kept else "split_shield", "kept" if kept else "shattered", DeepUi.GOOD if kept else DeepUi.BAD, 15)
		verdict.custom_minimum_size.x = 110
		die.verdict = verdict
		_enter(card, 0.1 + 0.45 * index)
		index += 1
	if index == 0:
		DeepUi.label(content, "You carried no raw stones. Nothing to lose.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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
			["ore", "Ore dug", str(int(tally.get("ore", 0)))], ["shield_burst", "Damage", str(int(tally.get("damage", 0)))]]:
		var tile := DeepUi.card(stats, DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9))
		tile.custom_minimum_size = Vector2(118, 0)
		var inner := DeepUi.vbox(tile, 2)
		var mark := DeepUi.icon(inner, str(entry[0]), 22, DeepUi.ACCENT)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.title(inner, str(entry[2]), 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(inner, str(entry[1]), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if not haul.is_empty():
		DeepUi.section(box, "bag", "Coming home")
		var tiles := HFlowContainer.new()
		tiles.add_theme_constant_override("h_separation", 10)
		tiles.add_theme_constant_override("v_separation", 10)
		box.add_child(tiles)
		var index: int = 0
		for stone in haul:
			var tile := StoneCard.tile(tiles, stone, 64)
			_enter(tile, 0.4 + 0.06 * index)
			index += 1
	var go := DeepUi.primary(box, "anvil", "Back to the workshop", func() -> void: home_requested.emit(), 18)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(card)
