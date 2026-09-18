extends Control
## The run: the shaft's tunnels, its chambers and landings, and the fight when there is one.
## Every screen here shows the run state it is given and turns clicks into commands; the
## battle screen inside it does the same for a fight.

const BattleScreen = preload("res://view/battle/battle_screen.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

signal command(cmd: Dictionary)
signal home_requested

const KIND_WORDS: Dictionary = {"fight": "A fight", "elite": "Something big", "vein": "A vein", "oddity": "Something odd",
	"motherlode": "A glittering hollow", "landing": "The landing"}
const KIND_GLYPHS: Dictionary = {"fight": "sword", "elite": "hammer", "vein": "coins", "oddity": "eye", "motherlode": "sun", "landing": "rampart"}

var local_id: String = ""
var run: Dictionary = {}
var forecast_provider: Callable = Callable()
var _strip: HBoxContainer
var _body: Control
var _battle: BattleScreen
var _view_key: String = ""
var _landing_tab: String = "haul"
var _toasts: VBoxContainer
var _picker_payload: Callable = Callable()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var strip_panel := DeepUi.panel(column, DeepUi.SLATE_LOW, DeepUi.LINE, 0, 10)
	_strip = DeepUi.hbox(strip_panel, 18)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body)
	_battle = BattleScreen.new()
	_battle.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	_battle.visible = false
	_body.add_child(_battle)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_toasts)

func bind(player_id: String, forecast: Callable) -> void:
	local_id = player_id
	forecast_provider = forecast
	_battle.bind(player_id)

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

# --- state -----------------------------------------------------------------------------------

func show_state(state: Dictionary) -> void:
	run = state
	_sync_strip()
	var phase: String = str(run.get("phase", ""))
	var key: String = phase
	if phase == "chamber":
		key += ":" + str(run.chamber.get("kind", "")) + ":" + str(run.depth) + (":battle" if DeepDescent.in_battle(run) else ":" + str(bool(run.chamber.get("settled", false))))
	elif phase == "landing":
		key += ":" + str(run.depth) + ":" + _landing_tab
	elif phase == "tunnels":
		key += ":" + str(run.depth)
	if DeepDescent.in_battle(run):
		_battle.visible = true
		for child in _body.get_children():
			if child != _battle:
				child.queue_free()
		var forecast: Dictionary = forecast_provider.call() if forecast_provider.is_valid() else {}
		_battle.show_state(DeepDescent.battle(run), int(run.depth), forecast)
		_view_key = key
		return
	_battle.visible = false
	## Everything outside a fight is a page: cheap to rebuild whenever the state moves.
	_view_key = key
	for child in _body.get_children():
		if child != _battle:
			child.queue_free()
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(page)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	page.add_child(margin)
	var content := DeepUi.vbox(margin, 14)
	match phase:
		"tunnels": _page_tunnels(content)
		"chamber":
			match str(run.chamber.get("kind", "")):
				"vein", "vug": _page_vein(content)
				"oddity": _page_oddity(content)
				_: _page_tunnels(content)
		"landing": _page_landing(content)
		"hoard": _page_hoard(content)
		"salvage": _page_salvage(content)
		"over": _page_over(content)

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
				if str(settle.get("outcome", "")) == "victory":
					var mine_reward: Dictionary = settle.get("rewards", {}).get(local_id, {})
					var parts: Array = ["+%d ore" % int(mine_reward.get("ore", 0))]
					for stone in mine_reward.get("stones", []):
						parts.append("a " + DeepStone.raw_name(stone))
					for die in mine_reward.get("dice", []):
						parts.append("a " + DeepDice.describe(die))
					toast("Victory: " + ", ".join(parts), DeepUi.GOOD)
		"vein_strike":
			if str(event.get("unit", "")) == local_id:
				var result: Dictionary = event.get("result", {})
				match str(result.get("kind", "")):
					"stone": toast("You pull a %s from the rock." % DeepStone.raw_name(result.stone), DeepUi.ACCENT)
					"ore": toast("+%d ore" % int(result.get("ore", 0)), DeepUi.ACCENT)
					"die": toast("A %s falls out of the wall." % DeepDice.describe(result.die), DeepUi.INFO)
					_: toast("Nothing but dust.", DeepUi.MUTED)
		"oddity_result":
			if str(event.get("unit", "")) == local_id:
				toast(str(event.get("message", "")), DeepUi.PAPER)
		"appraised":
			if str(event.get("unit", "")) == local_id:
				toast("Appraised: " + DeepStone.name(event.stone), DeepUi.tier_colour(str(DeepStone.grade(event.stone).tier)))
		"given":
			toast("%s gave %s something." % [str(DeepDescent.player(run, str(event.get("from", ""))).get("name", "")), str(DeepDescent.player(run, str(event.get("to", ""))).get("name", ""))], DeepUi.INFO)
		"motherlode":
			toast("A motherlode. Stones everywhere.", DeepUi.ACCENT)
		"landing":
			toast("The landing. Breathe.", DeepUi.MUTED)

func toast(text: String, color: Color) -> void:
	var label := DeepUi.label(_toasts, text, 15, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_outline_color", DeepUi.INK)
	label.add_theme_constant_override("outline_size", 4)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(2.4)
	tween.tween_callback(label.queue_free)

# --- strip -----------------------------------------------------------------------------------

func _sync_strip() -> void:
	DeepUi.clear(_strip)
	var unit: Dictionary = me()
	DeepUi.label(_strip, str(DeepContent.mine(str(run.get("mine", ""))).get("name", "The mine")), 14, DeepUi.ACCENT)
	DeepUi.label(_strip, "Depth %d" % int(run.get("depth", 0)), 14, DeepUi.PAPER)
	DeepUi.spacer(_strip)
	for other in run.get("players", []):
		var tone: Color = DeepUi.PAPER if str(other.id) == local_id else DeepUi.MUTED
		var box := DeepUi.hbox(_strip, 6)
		DeepUi.label(box, str(other.name), 13, tone)
		var bar := DeepUi.bar(box, 10.0)
		bar.custom_minimum_size = Vector2(90, 10)
		bar.set_values(float(other.hp) / float(maxi(1, int(other.max_hp))), "%d" % int(other.hp))
		if not bool(other.get("connected", true)):
			DeepUi.label(box, "away", 11, DeepUi.DIM)
	DeepUi.spacer(_strip)
	if not unit.is_empty():
		DeepUi.chip(_strip, "%d ore" % int(unit.get("ore", 0)), DeepUi.ACCENT, 12)
		DeepUi.chip(_strip, "%d loupe%s" % [int(unit.get("loupes", 0)), "" if int(unit.get("loupes", 0)) == 1 else "s"], DeepUi.INFO, 12)
		DeepUi.chip(_strip, "%d stone%s carried" % [unit.get("haul", []).size(), "" if unit.get("haul", []).size() == 1 else "s"], DeepUi.MUTED, 12)

# --- pages -----------------------------------------------------------------------------------

func _page_tunnels(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	if not run.get("aftermath", {}).is_empty():
		var mine_reward: Dictionary = run.aftermath.get(local_id, {})
		if not mine_reward.is_empty():
			var panel := DeepUi.panel(content)
			var box := DeepUi.vbox(panel, 8)
			DeepUi.heading(box, "Taken from the rock")
			var row := DeepUi.hbox(box, 12)
			if int(mine_reward.get("ore", 0)) > 0:
				DeepUi.chip(row, "+%d ore" % int(mine_reward.ore), DeepUi.ACCENT)
			for stone in mine_reward.get("stones", []):
				StoneCard.build(row, stone, {"size": 64})
			for die in mine_reward.get("dice", []):
				DeepUi.chip(row, DeepDice.describe(die), DeepUi.INFO)
	var next_depth: int = int(run.get("depth", 0)) + 1
	DeepUi.heading(content, "Depth %d" % next_depth, 15)
	DeepUi.label(content, "Choose a tunnel. The party goes where most of it points." if run.players.size() > 1 else "Choose a tunnel.", 14, DeepUi.MUTED)
	var row := DeepUi.hbox(content, 16)
	for offer in run.get("offers", []):
		var hidden: bool = bool(offer.get("hidden", false))
		var kind: String = str(offer.kind)
		var card := DeepUi.panel(row, DeepUi.SLATE, DeepUi.ACCENT if str(unit.get("vote", "")) == str(offer.id) else DeepUi.LINE, 12, 18)
		card.custom_minimum_size = Vector2(220, 170)
		var box := DeepUi.vbox(card, 10)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var glyph_row := DeepUi.hbox(box, 0)
		glyph_row.alignment = BoxContainer.ALIGNMENT_CENTER
		GemIcons.glyph(glyph_row, "eye" if hidden else str(KIND_GLYPHS.get(kind, "sword")), 44, DeepUi.DIM if hidden else DeepUi.PAPER)
		DeepUi.label(box, "A dark mouth" if hidden else str(KIND_WORDS.get(kind, kind)), 16, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var voters: Array = []
		for other in run.players:
			if str(other.get("vote", "")) == str(offer.id):
				voters.append(str(other.name))
		DeepUi.label(box, ", ".join(voters) if not voters.is_empty() else " ", 12, DeepUi.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		var button := DeepUi.button(box, "Go this way", func() -> void: command.emit({"kind": "vote_tunnel", "offer": offer.id}))
		button.disabled = bool(unit.get("downed", false)) and false

func _page_vein(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var vein: Dictionary = run.chamber.get("vein", {})
	DeepUi.heading(content, "A vein" if not bool(vein.get("hazard", false)) else "The vug", 15)
	DeepUi.label(content, "Glints in the rock. You have %d strike%s left%s." % [int(unit.get("strikes", 0)), "" if int(unit.get("strikes", 0)) == 1 else "s", "; each one costs 3 HP here" if bool(vein.get("hazard", false)) else ""], 14, DeepUi.MUTED)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	for spot in vein.get("spots", []):
		var taken: String = str(spot.get("taken", ""))
		var glint: String = str(spot.get("glint", "dull"))
		var tone: Color = DeepUi.tier_colour("PEERLESS") if glint == "bright" else (DeepUi.INFO if glint == "glint" else DeepUi.DIM)
		var card := DeepUi.panel(grid, DeepUi.SLATE, Color(tone, 0.6), 10, 14)
		card.custom_minimum_size = Vector2(200, 110)
		var box := DeepUi.vbox(card, 6)
		DeepUi.label(box, ["Dull rock", "A glint", "Something bright"][["dull", "glint", "bright"].find(glint)], 14, tone)
		if taken.is_empty():
			var button := DeepUi.button(box, "Strike", func() -> void: command.emit({"kind": "strike", "spot": int(spot.index)}))
			button.disabled = int(unit.get("strikes", 0)) <= 0
		else:
			var result: Dictionary = spot.get("result", {})
			var who: String = str(DeepDescent.player(run, taken).get("name", taken))
			var words: String = "%s: " % who
			match str(result.get("kind", "")):
				"stone": words += DeepStone.raw_name(result.get("stone", {}))
				"ore": words += "%d ore" % int(result.get("ore", 0))
				"die": words += DeepDice.describe(result.get("die", {}))
				_: words += "nothing"
			DeepUi.label(box, words, 12, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _page_oddity(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var oddity: Dictionary = DeepContent.oddity(str(run.chamber.get("oddity", "")))
	DeepUi.heading(content, str(oddity.get("name", "Something odd")), 15)
	DeepUi.label(content, str(oddity.get("text", "")), 15, DeepUi.PAPER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chosen: String = str(unit.get("oddity_choice", ""))
	if not chosen.is_empty():
		var mine_result: Dictionary = run.chamber.get("results", {}).get(local_id, {})
		DeepUi.label(content, str(mine_result.get("message", "You have chosen.")), 14, DeepUi.ACCENT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for stone in mine_result.get("made", []):
			StoneCard.build(content, stone, {"size": 64})
		var waiting: Array = run.players.filter(func(p: Dictionary) -> bool: return str(p.get("oddity_choice", "")).is_empty() and not bool(p.get("downed", false)))
		if not waiting.is_empty():
			DeepUi.label(content, "Waiting for " + ", ".join(waiting.map(func(p: Dictionary) -> String: return str(p.name))), 13, DeepUi.MUTED)
		return
	for choice in oddity.get("choices", []):
		var card := DeepUi.panel(content)
		var box := DeepUi.vbox(card, 8)
		DeepUi.label(box, str(choice.get("label", choice.id)), 16, DeepUi.PAPER)
		if choice.has("text"):
			DeepUi.label(box, str(choice.text), 13, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var needs: String = str(choice.get("needs", ""))
		var payload_of: Callable = _picker(box, needs, unit)
		var button := DeepUi.button(box, "Choose", func() -> void:
			command.emit({"kind": "oddity", "choice": str(choice.id), "payload": payload_of.call()}))
		if needs != "" and payload_of.call().is_empty():
			button.disabled = true
			DeepUi.label(box, "You have nothing this could be done to.", 12, DeepUi.DIM)

func _picker(box: VBoxContainer, needs: String, unit: Dictionary) -> Callable:
	## The controls a choice needs, and a callable that reads them into a payload.
	if needs.is_empty():
		return func() -> Dictionary: return {}
	var stones: Array = unit.get("haul", []).duplicate()
	for stone in unit.get("rail", []):
		if stone is Dictionary:
			stones.append(stone)
	var dice: Array = unit.get("dice", []) + unit.get("bag_dice", [])
	var row := DeepUi.hbox(box, 8)
	match needs:
		"stone":
			var pick := _options(row, stones.map(func(s: Dictionary) -> Array: return [str(s.id), DeepUi.stone_name(s)]))
			return func() -> Dictionary: return {} if pick.item_count == 0 else {"stone_id": str(pick.get_item_metadata(pick.selected))}
		"two_stones":
			DeepUi.label(row, "Keep", 12, DeepUi.MUTED)
			var keep := _options(row, stones.map(func(s: Dictionary) -> Array: return [str(s.id), DeepUi.stone_name(s)]))
			DeepUi.label(row, "Feed", 12, DeepUi.MUTED)
			var feed := _options(row, stones.map(func(s: Dictionary) -> Array: return [str(s.id), DeepUi.stone_name(s)]))
			if feed.item_count > 1:
				feed.selected = 1
			return func() -> Dictionary: return {} if stones.size() < 2 else {"keep_id": str(keep.get_item_metadata(keep.selected)), "feed_id": str(feed.get_item_metadata(feed.selected))}
		"inclusion", "copy_inclusion":
			var carriers: Array = stones.filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false))))
			var from := _options(row, carriers.map(func(s: Dictionary) -> Array: return [str(s.id), DeepUi.stone_name(s)]))
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
			var to := _options(row, stones.map(func(s: Dictionary) -> Array: return [str(s.id), DeepUi.stone_name(s)]))
			return func() -> Dictionary: return {} if from.item_count == 0 or which.item_count == 0 or to.item_count == 0 else {"from_id": str(from.get_item_metadata(from.selected)), "inclusion": str(which.get_item_metadata(which.selected)), "to_id": str(to.get_item_metadata(to.selected))}
		"die", "die_face", "die_engraving":
			var pick := _options(row, dice.map(func(d: Dictionary) -> Array: return [str(d.id), DeepDice.describe(d)]))
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

func _options(parent: Node, entries: Array) -> OptionButton:
	var pick := OptionButton.new()
	for entry in entries:
		pick.add_item(str(entry[1]))
		pick.set_item_metadata(pick.item_count - 1, entry[0])
	if pick.item_count > 0:
		pick.selected = 0
	parent.add_child(pick)
	return pick

func _page_landing(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var landing: Dictionary = run.get("landing", {})
	var head := DeepUi.hbox(content, 12)
	DeepUi.heading(head, "Landing at depth %d" % int(run.depth), 15)
	DeepUi.spacer(head)
	if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
		DeepUi.chip(head, "A Warden guards the way down", DeepUi.BAD, 12)
	if bool(landing.get("cleared", false)):
		DeepUi.chip(head, "The Warden is dead", DeepUi.GOOD, 12)
	var tabs := DeepUi.hbox(content, 6)
	for entry in [["haul", "Haul"], ["bench", "Bench"], ["merchant", "Merchant"], ["lift", "Lift"]]:
		var button := DeepUi.button(tabs, str(entry[1]), func() -> void:
			_landing_tab = str(entry[0])
			show_state(run))
		if _landing_tab == str(entry[0]):
			button.add_theme_stylebox_override("normal", DeepUi.flat(DeepUi.ACCENT_DIM, DeepUi.ACCENT, 8, 10))
	DeepUi.rule(content)
	match _landing_tab:
		"haul": _landing_haul(content, unit)
		"bench": _landing_bench(content, unit)
		"merchant": _landing_merchant(content, unit, landing)
		"lift": _landing_lift(content, unit, landing)

func _landing_haul(content: VBoxContainer, unit: Dictionary) -> void:
	var haul: Array = unit.get("haul", [])
	if haul.is_empty():
		DeepUi.label(content, "You carry no loose stones.", 14, DeepUi.MUTED)
		return
	var cost: int = int(DeepContent.constant("appraise_ore_cost", 12))
	for stone in haul:
		var card := StoneCard.build(content, stone, {"size": 76, "value": true})
		var actions := DeepUi.hbox(card.get_child(0), 6)
		actions.alignment = BoxContainer.ALIGNMENT_END
		var id: String = str(stone.id)
		if not bool(stone.get("appraised", false)):
			var loupe := DeepUi.button(actions, "Appraise (loupe)", func() -> void: command.emit({"kind": "appraise", "stone_id": id, "with": "loupe"}), 13)
			loupe.disabled = int(unit.get("loupes", 0)) <= 0
			var ore := DeepUi.button(actions, "Appraise (%d ore)" % cost, func() -> void: command.emit({"kind": "appraise", "stone_id": id, "with": "ore"}), 13)
			ore.disabled = int(unit.get("ore", 0)) < cost
		else:
			DeepUi.button(actions, "Sell for %d ore" % (DeepStone.value(stone) / 2), func() -> void: command.emit({"kind": "sell", "stone_id": id}), 13)
		for other in run.players:
			if str(other.id) != local_id and bool(other.get("connected", true)):
				var to: String = str(other.id)
				DeepUi.button(actions, "Give to %s" % str(other.name), func() -> void: command.emit({"kind": "give", "to": to, "item_id": id}), 13)

func _landing_bench(content: VBoxContainer, unit: Dictionary) -> void:
	DeepUi.heading(content, "Sockets", 13)
	DeepUi.label(content, "Set appraised stones from your haul. One stone of each skill.", 13, DeepUi.MUTED)
	var rail_row := DeepUi.hbox(content, 12)
	var sockets: Array = unit.get("sockets", [])
	for index in range(unit.get("rail", []).size()):
		var socket_colour: String = str(sockets[index]) if index < sockets.size() else "ANY"
		var card := DeepUi.panel(rail_row, DeepUi.SLATE, DeepUi.ACCENT if socket_colour == "CAPSTONE" else (DeepUi.colour(socket_colour) if socket_colour != "ANY" else DeepUi.LINE), 10, 10)
		card.custom_minimum_size = Vector2(150, 0)
		var box := DeepUi.vbox(card, 6)
		DeepUi.label(box, socket_colour.capitalize(), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var stone: Variant = unit.rail[index]
		if stone is Dictionary:
			var pic_row := DeepUi.hbox(box, 0)
			pic_row.alignment = BoxContainer.ALIGNMENT_CENTER
			StoneCard.mini(pic_row, stone, 64)
			DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", stone.skill)), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
			var socket_index: int = index
			var out := DeepUi.button(box, "Remove", func() -> void: command.emit({"kind": "unsocket", "index": socket_index}), 12)
			out.disabled = DeepStone.is_locked(stone)
		else:
			DeepUi.label(box, "empty", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var fitting: Array = unit.get("haul", []).filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)) and DeepStone.fits(s, socket_colour))
		if not fitting.is_empty():
			var pick := _options(box, fitting.map(func(s: Dictionary) -> Array: return [str(s.id), str(DeepStone.skill_of(s).get("name", s.skill))]))
			var socket_index: int = index
			DeepUi.button(box, "Set", func() -> void: command.emit({"kind": "socket", "stone_id": str(pick.get_item_metadata(pick.selected)), "index": socket_index}), 12)
	DeepUi.heading(content, "Dice", 13)
	var dice_row := DeepUi.hbox(content, 12)
	for index in range(unit.get("dice", []).size()):
		var die: Dictionary = unit.dice[index]
		var card := DeepUi.panel(dice_row, DeepUi.SLATE, DeepUi.LINE, 10, 10)
		var box := DeepUi.vbox(card, 6)
		DeepUi.label(box, DeepDice.describe(die), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var faces: Array = die.get("faces", []).map(func(f: Dictionary) -> String: return DiceIcons.face_text(int(f.value), str(f.kind)))
		DeepUi.label(box, " ".join(faces), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if not unit.get("bag_dice", []).is_empty():
			var pick := _options(box, unit.bag_dice.map(func(d: Dictionary) -> Array: return [str(d.id), DeepDice.describe(d)]))
			var slot: int = index
			DeepUi.button(box, "Swap in", func() -> void: command.emit({"kind": "swap_die", "index": slot, "die_id": str(pick.get_item_metadata(pick.selected))}), 12)
	if not unit.get("bag_dice", []).is_empty():
		DeepUi.label(content, "In your bag: " + ", ".join(unit.bag_dice.map(func(d: Dictionary) -> String: return DeepDice.describe(d))), 12, DeepUi.MUTED)

func _landing_merchant(content: VBoxContainer, unit: Dictionary, landing: Dictionary) -> void:
	DeepUi.label(content, "You have %d ore." % int(unit.get("ore", 0)), 14, DeepUi.ACCENT)
	for item in landing.get("stock", []):
		var sold: String = str(item.get("sold", ""))
		var card := DeepUi.panel(content, DeepUi.SLATE, DeepUi.LINE if sold.is_empty() else Color(DeepUi.LINE, 0.4), 10, 10)
		var row := DeepUi.hbox(card, 12)
		match str(item.kind):
			"stone":
				var inner := StoneCard.build(row, item.stone, {"size": 64})
				inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			"die":
				var die: Dictionary = item.die
				var box := DeepUi.vbox(row, 4)
				box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				DeepUi.label(box, DeepDice.describe(die), 15, DeepUi.PAPER)
				DeepUi.label(box, " ".join(die.get("faces", []).map(func(f: Dictionary) -> String: return DiceIcons.face_text(int(f.value), str(f.kind)))), 12, DeepUi.MUTED)
			"loupe":
				var box := DeepUi.vbox(row, 4)
				box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				DeepUi.label(box, "A loupe", 15, DeepUi.PAPER)
				DeepUi.label(box, "Appraise one stone underground without spending ore.", 12, DeepUi.MUTED)
		if sold.is_empty():
			var id: String = str(item.id)
			var button := DeepUi.button(row, "Buy for %d ore" % int(item.price), func() -> void: command.emit({"kind": "buy", "item_id": id}), 13)
			button.disabled = int(unit.get("ore", 0)) < int(item.price)
		else:
			DeepUi.label(row, "Sold to %s" % str(DeepDescent.player(run, sold).get("name", sold)), 12, DeepUi.DIM)

func _landing_lift(content: VBoxContainer, unit: Dictionary, landing: Dictionary) -> void:
	var haul: Array = unit.get("haul", [])
	var worth: int = 0
	for stone in haul:
		worth += DeepStone.value(stone)
	DeepUi.label(content, "You carry %d stone%s, worth about %d gold if they are what they look like." % [haul.size(), "" if haul.size() == 1 else "s", worth], 14, DeepUi.PAPER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tiers := DeepUi.hbox(content, 6)
	for stone in haul:
		var tier: String = str(DeepStone.grade(stone).tier)
		DeepUi.chip(tiers, DeepStone.raw_name(stone) if not bool(stone.get("appraised", false)) else str(DeepStone.skill_of(stone).get("name", "")), DeepUi.tier_colour(tier), 11)
	if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
		DeepUi.label(content, "Going down means fighting the Warden first.", 14, DeepUi.BAD)
	var conquered: bool = int(run.depth) >= int(DeepContent.constant("run_depth", 24)) and bool(landing.get("cleared", false))
	var row := DeepUi.hbox(content, 12)
	var lift := DeepUi.button(row, "Ride the lift home" if not conquered else "Return victorious", func() -> void: command.emit({"kind": "choose", "choice": "lift"}))
	var down := DeepUi.button(row, "Go deeper" if not conquered else "Go deeper (Endless)", func() -> void: command.emit({"kind": "choose", "choice": "descend"}))
	if str(unit.get("choice", "")) == "lift":
		lift.add_theme_stylebox_override("normal", DeepUi.flat(DeepUi.ACCENT_DIM, DeepUi.ACCENT, 8, 10))
	elif str(unit.get("choice", "")) == "descend":
		down.add_theme_stylebox_override("normal", DeepUi.flat(DeepUi.ACCENT_DIM, DeepUi.ACCENT, 8, 10))
	var votes: Array = []
	for other in run.players:
		if not str(other.get("choice", "")).is_empty():
			votes.append("%s: %s" % [str(other.name), str(other.choice)])
	if not votes.is_empty():
		DeepUi.label(content, ", ".join(votes) + ". The party goes where most of it points; a tie goes to the first seat.", 12, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _page_hoard(content: VBoxContainer) -> void:
	var mine_hoard: Dictionary = run.get("hoard", {}).get(local_id, {})
	DeepUi.heading(content, "The Warden's hoard", 15)
	DeepUi.label(content, "Take one. They are appraised.", 14, DeepUi.MUTED)
	var row := DeepUi.hbox(content, 14)
	for stone in mine_hoard.get("offers", []):
		var box := DeepUi.vbox(row, 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		StoneCard.build(box, stone, {"size": 84})
		var id: String = str(stone.id)
		var button := DeepUi.button(box, "Take it", func() -> void: command.emit({"kind": "pick_hoard", "stone_id": id}))
		button.disabled = not str(mine_hoard.get("chosen", "")).is_empty()
	if not str(mine_hoard.get("chosen", "")).is_empty():
		DeepUi.label(content, "Waiting for the others to choose.", 13, DeepUi.MUTED)

func _page_salvage(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	DeepUi.heading(content, "The party falls", 15)
	DeepUi.label(content, "Every raw stone rolls a die by its grade. Only the top face brings it home.", 14, DeepUi.MUTED)
	for roll in run.get("salvage", {}).get(local_id, {}).get("rolls", []):
		var kept: bool = bool(roll.kept)
		var card := DeepUi.panel(content, DeepUi.SLATE, DeepUi.GOOD if kept else Color(DeepUi.BAD, 0.6), 10, 10)
		var row := DeepUi.hbox(card, 12)
		StoneCard.mini(row, roll.stone, 48)
		var box := DeepUi.vbox(row, 2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(box, DeepUi.stone_name(roll.stone), 14, DeepUi.tier_colour(str(roll.tier)))
		DeepUi.label(box, "d%d rolled %d: %s" % [int(roll.sides), int(roll.roll), "kept" if kept else "shattered"], 13, DeepUi.GOOD if kept else DeepUi.BAD)
	var button := DeepUi.button(content, "Climb out", func() -> void: command.emit({"kind": "ready"}))
	button.disabled = bool(unit.get("ready", false))

func _page_over(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var outcome: String = str(run.get("outcome", ""))
	var titles: Dictionary = {"extracted": "Extracted", "conquered": "The mine is yours", "fallen": "Fallen"}
	DeepUi.heading(content, str(titles.get(outcome, outcome)), 18, DeepUi.GOOD if outcome != "fallen" else DeepUi.BAD)
	DeepUi.label(content, "Depth %d. %d stone%s come home." % [int(run.depth), unit.get("haul", []).size(), "" if unit.get("haul", []).size() == 1 else "s"], 14, DeepUi.MUTED)
	for stone in unit.get("haul", []):
		StoneCard.build(content, stone, {"size": 64})
	DeepUi.button(content, "Back to the workshop", func() -> void: home_requested.emit())
