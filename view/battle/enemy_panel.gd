extends PanelContainer
## One readable moveset, shared by hover, pinning and the acting enemy: its ordered dice,
## every move with what it needs and what it does, and its trick (the passive it fights
## with) at the foot. The die it is rolling is not here: that turns over the creature's own
## head, in the room, so this table stays the one size whether it is acting or not.
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const GLYPHS: Dictionary = {"damage": "sword", "block": "shield", "heal": "heart", "poison": "drop", "die_steal": "die", "remove_block": "split_shield", "dice_upgrade": "die", "stun": "stun",
	"curse": "eye", "clouded": "cloud", "ward": "shield_burst", "retain": "shield", "charged": "bolt", "marked": "eye", "regeneration": "heart", "spikes": "thorn", "dulled": "cut"}
const STATES: Dictionary = {"unrevealed": "", "pending": "WAITING", "activated": "READY", "resolving": "ACTING", "resolved": "DONE", "used": "USED", "missed": "MISSED", "clouded": "CLOUDED"}
signal pinned(id: String)
var enemy_id: String = ""
var foe: Dictionary = {}
var _key: String = ""
var _title: Label
var _hint: Label
var _dice: HBoxContainer
var _table: VBoxContainer
var _rows: Array = []
var _shown_states: Array = []
var _slots: Dictionary = {}
var _animations: Array = []
var _tween: Tween
var _revealed: int = 0
var _turn: int = -1
var _pin: Button
var _effects_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", DeepUi.raised(Color("10141f"), Color("755449"), 12, 12, 0.8))
	var box := DeepUi.vbox(self, 6)
	var head := DeepUi.hbox(box, 8)
	_title = DeepUi.heading(head, "", 17, DeepUi.PAPER)
	DeepUi.spacer(head)
	_pin = DeepUi.button(head, "Pin", func() -> void: pinned.emit(enemy_id), 12)
	_hint = DeepUi.label(box, "Damage and debuffs affect all players", 11, DeepUi.MUTED)
	_dice = DeepUi.hbox(box, 6)
	_table = DeepUi.vbox(box, 5)
	_table.custom_minimum_size.x = 265
	_effects_layer = Control.new()
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_effects_layer)
	visible = false

func _cancel_animations() -> void:
	for animation in _animations:
		if animation.is_valid():
			animation.kill()
	_animations.clear()
	DeepUi.clear(_effects_layer)

func reset() -> void:
	_cancel_animations()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	DeepUi.clear(_effects_layer)
	enemy_id = ""
	_key = ""
	_revealed = 0
	_shown_states = []
	visible = false

func show_enemy(unit: Dictionary, turn: int, is_pinned: bool = false) -> void:
	var changed: bool = enemy_id != str(unit.id) or _turn != turn
	if changed:
		reset()
		_turn = turn
		enemy_id = str(unit.id)
		_revealed = unit.get("hand", []).size()
	foe = unit.duplicate(true)
	visible = true
	_pin.text = "Unpin" if is_pinned else "Pin"
	_title.text = str(foe.name)
	_hint.text = "Damage and debuffs affect all players"
	var moves: Array = DeepCreatures.display_moves(foe, foe.get("moves", DeepCreatures.moves_for(foe)))
	var key: String = str(moves) + "|" + str(foe.get("gimmick", ""))
	if key != _key:
		_cancel_animations()
		_key = key
		_build_rows(moves)
	if changed or not bool(foe.get("acting", false)) or str(foe.get("beat", "")) != "roll":
		_revealed = foe.get("hand", []).size()
		_states(foe.get("move_states", []))
	_show_dice()
	# Containers otherwise retain the width of the previous panel on hover.
	reset_size()

func _build_rows(moves: Array) -> void:
	DeepUi.clear(_table)
	_rows.clear()
	for move in moves:
		var panel := DeepUi.panel(_table, Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08), 6, 6)
		var box := DeepUi.vbox(panel, 1)
		var head := DeepUi.hbox(box, 5)
		DeepUi.icon(head, GemIcons.emblem(str(move.name).to_upper()), 15, DeepUi.BAD)
		DeepUi.label(head, str(move.name), 14, DeepUi.PAPER)
		DeepUi.spacer(head)
		var badge := DeepUi.label(head, "", 9, DeepUi.DIM)
		var requirement := DeepUi.hbox(box, 5)
		var described: Dictionary = DeepPatterns.describe(move.get("trigger", {"kind": "always"}), 0)
		described.label = ""
		if str(described.kind) in ["all_odd", "all_even"]:
			described.mark = "odd" if str(described.kind) == "all_odd" else "even"
		DiceIcons.build(requirement, described, 13, DeepUi.MUTED, DeepCreatures.trigger_words(move))
		var condition := DeepUi.label(requirement, DeepCreatures.trigger_words(move), 11, DeepUi.MUTED)
		condition.tooltip_text = condition.text
		var numbers: Array = []
		var formulas: Array = []
		for effect in move.get("effects", []):
			var line := DeepUi.hbox(box, 5)
			DeepUi.icon(line, str(GLYPHS.get(str(effect.kind), "spark")), 13, DeepUi.BAD if str(effect.kind) == "damage" else DeepUi.INFO)
			var formula: String = DeepCreatures.amount_words(effect.get("amount", 0))
			var number := DeepUi.label(line, formula, 12, DeepUi.PAPER)
			var noun: String = str({"damage": "damage", "block": "block", "heal": "healing", "poison": "poison", "die_steal": "die suppressed", "remove_block": "block removed", "dice_upgrade": "tier up · this fight", "stun": "turn stunned"}.get(str(effect.kind), str(effect.kind)))
			DeepUi.label(line, noun, 11, DeepUi.MUTED)
			line.tooltip_text = DeepCreatures.effect_words(effect)
			numbers.append(number)
			formulas.append(formula)
		_rows.append({"panel": panel, "badge": badge, "numbers": numbers, "formulas": formulas})
	_build_passive()

func _build_passive() -> void:
	## The creature's trick, the thing it does without rolling for it, read out with the
	## moves rather than left to the chip over its head: a Latcher's latch or a Fogger's fog
	## is as much its moveset as anything it rolls for.
	var gimmick: String = str(foe.get("gimmick", ""))
	if not EffectChips.GIMMICKS.has(gimmick):
		return
	var words: Array = EffectChips.GIMMICKS[gimmick]
	var panel := DeepUi.panel(_table, Color(0.78, 0.66, 1.0, 0.05), Color(0.78, 0.66, 1.0, 0.16), 6, 6)
	var box := DeepUi.vbox(panel, 1)
	var head := DeepUi.hbox(box, 5)
	DeepUi.icon(head, str(words[0]), 15, Color("c8a8ff"))
	DeepUi.label(head, str(words[1]), 14, DeepUi.PAPER)
	DeepUi.spacer(head)
	DeepUi.label(head, "PASSIVE", 9, DeepUi.DIM)
	DeepUi.wrap(box, str(words[2]), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 250)

func _show_dice() -> void:
	DeepUi.clear(_dice)
	_slots.clear()
	var dice: Array = DeepCreatures.effective_dice(foe)
	var suppressed: int = int(foe.get("suppressed", 0)) if bool(foe.get("acting", false)) or str(foe.get("beat", "")) == "done" else int(foe.get("stolen_dice", 0))
	for index in range(dice.size()):
		if index > 0:
			DeepUi.label(_dice, "›", 13, DeepUi.DIM)
		var die: Dictionary = dice[index]
		var shape: String = str(foe.hand[index].get("shape", die.shape)) if index < foe.get("hand", []).size() else str(die.shape)
		var shown: String = shape.to_lower()
		if index < _revealed and index < foe.get("hand", []).size():
			shown += " · %d" % int(foe.hand[index].value)
		elif index >= dice.size() - suppressed:
			shown += " ×"
		else:
			shown += " · ?"
		var slot := DeepUi.label(_dice, shown, 13, DeepUi.BAD if index == int(foe.get("next_die", 0)) - 1 and bool(foe.get("acting", false)) else DeepUi.MUTED)
		slot.tooltip_text = "Suppressed" if index >= dice.size() - suppressed else "Roll %d" % (index + 1)
		_slots[str(die.id)] = slot

func _states(states: Array) -> void:
	_shown_states = states.duplicate()
	for index in range(_rows.size()):
		var status: String = str(states[index]) if index < states.size() else "unrevealed"
		if DeepCreatures.move_clouded(foe, index):
			status = "clouded"
		var row: Dictionary = _rows[index]
		row.badge.text = str(STATES.get(status, ""))
		row.badge.modulate = DeepUi.ACCENT if status in ["activated", "resolving"] else DeepUi.MUTED
		row.panel.modulate.a = 0.4 if status in ["missed", "clouded"] else (0.65 if status in ["used", "resolved"] else 1.0)
		row.panel.add_theme_stylebox_override("panel", DeepUi.raised(Color("30221f") if status == "resolving" else Color("171c29"), DeepUi.ACCENT if status == "resolving" else Color("343443"), 6, 6, 0.0))

func roll_die(event: Dictionary) -> void:
	_cancel_animations()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for row in _rows:
		for i in range(row.numbers.size()):
			row.numbers[i].text = row.formulas[i]
	var before: Array = []
	for i in range(_rows.size()):
		var prior: String = str(_shown_states[i]) if i < _shown_states.size() else "unrevealed"
		before.append("used" if prior == "used" else ("pending" if DeepCreatures.is_combination(foe.moves[i]) else "unrevealed"))
	_states(before)
	_hint.text = "One die away…" if bool(event.get("suspense", false)) else "Rolling…"
	_revealed = int(event.roll_index)
	_show_dice()
	## The die itself tumbles over the creature's head (the battle screen's business); the
	## table only waits for it to land before it reads the roll into its rows.
	_tween = create_tween()
	_tween.tween_interval(maxf(0.1, float(event.duration) - 0.28))
	_tween.tween_callback(func() -> void:
		_revealed = int(event.roll_index) + 1
		_show_dice()
		_hint.text = "Damage and debuffs affect all players"
		_states(event.get("states", []))
		var slot: Control = _slots.get(str(event.roll.get("die_id", "")), null)
		if slot != null and is_instance_valid(slot):
			DeepUi.pulse(slot, 1.25, 0.23))

func power(event: Dictionary) -> void:
	var index: int = int(event.index)
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	_states(foe.get("move_states", []))
	var assemble: float = 0.3 if bool(event.get("combo", false)) else 0.0
	var contributors: Array = []
	for roll in foe.get("hand", []):
		if event.get("dice", []).has(str(roll.die_id)):
			contributors.append(roll)
	if bool(event.get("combo", false)):
		contributors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.value) < int(b.value))
	for i in range(contributors.size()):
		var roll: Dictionary = contributors[i]
		var source: Control = _slots.get(str(roll.die_id), _dice)
		var token := DeepUi.label(_effects_layer, str(int(roll.value)), 21, DeepUi.ACCENT)
		token.position = source.global_position + source.size * 0.5 - _effects_layer.global_position - Vector2(8, 8)
		var flight := token.create_tween()
		_animations.append(flight)
		if assemble > 0:
			flight.tween_property(token, "position", _dice.global_position - _effects_layer.global_position + Vector2(18 + i * 35, 34), assemble).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flight.tween_property(token, "position", row.numbers[0].global_position - _effects_layer.global_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flight.parallel().tween_property(token, "modulate:a", 0.0, 0.2)
		flight.tween_callback(token.queue_free)
	var effects: Array = event.get("effects", [])
	for i in range(mini(effects.size(), row.numbers.size())):
		var number: Label = row.numbers[i]
		var amount: int = int(effects[i].amount)
		number.text = str(mini(1, amount))
		var count := number.create_tween()
		_animations.append(count)
		count.tween_interval(assemble + 0.14)
		count.tween_method(func(value: float) -> void: number.text = str(int(round(value))), float(mini(1, amount)), float(amount), 0.22)
		count.tween_callback(func() -> void:
			DeepUi.pulse(number, 1.18, 0.18)
			DeepAudio.from(number, "resonance", {"volume": 0.4, "pitch": 0.85}))

func impact(event: Dictionary) -> void:
	var index: int = int(event.get("index", -1))
	if index >= 0 and index < _rows.size():
		DeepUi.pulse(_rows[index].panel, 1.025, 0.24)
		_states(foe.get("move_states", []))
