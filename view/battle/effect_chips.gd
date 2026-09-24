extends RefCounted
## Every lasting effect on a player or a creature, as a chip: a mark, a number, a color
## that says whether it helps or hurts, and a sentence that says exactly what it does.
##
## The sim keeps these as loose fields (statuses, block, buried sockets, stolen dice, a
## Double Down that came up empty, a Shrine's blessing). This gathers them in one place so
## every screen that shows a unit shows the same effects the same way.

const GemIcons = preload("res://view/gems/gem_icons.gd")

const GOOD := Color("6fe3b0")
const BAD := Color("ff7a6b")

## What each creature's trick does, in rules words, with the mark it is shown by.
const GIMMICKS: Dictionary = {
	"steal_high_die": ["die", "Latcher", "Its Latch takes one of your dice away for the next turn."],
	"split_on_big_hit": ["copy", "Splits", "A single blow of 40% of its health or more splits it in two. Many small blows kill it."],
	"block_from_high": ["shield", "Hardens", "Each turn its block rises to match the party's highest die."],
	"steal_gold": ["coin_fall", "Thief", "Steals up to 3 pyrite with every hit, and drops all of it when it dies."],
	"gift_rerolls": ["reroll", "Lantern", "Its light gives you an extra reroll each turn, and every player loses 1 HP whenever anyone rerolls (cannot down a player)."],
	"poison_immune": ["drop", "Unpoisonable", "Poison cannot touch it."],
	"cloud_socket": ["cloud", "Fogger", "Fogs one of your sockets each turn. Hit it to clear the fog."],
	"reflect_zero_resonance": ["prism", "Mirror-hide", "When hit at Resonance 0 or 1, throws half that damage back at every player."],
	"bury_socket": ["rampart", "Buries", "Buries one of your sockets in rubble each turn: that gem cannot fire."],
	"mirror_last_gem": ["copy", "Mirror", "Adds half the party’s strongest last turn, up to 6 damage, shared across its dice."],
	"roll_for_you": ["die", "Roller", "On odd turns it rolls your dice for you, and you get no rerolls."]}

static func entry(key: String, glyph: String, value: String, good: bool, title: String, text: String, tone: Color = Color(0, 0, 0, 0)) -> Dictionary:
	return {"key": key, "glyph": glyph, "value": value, "good": good, "title": title, "text": text,
		"tone": tone if tone.a > 0.0 else (GOOD if good else BAD)}

static func for_player(unit: Dictionary, battle: Dictionary = {}) -> Array:
	var out: Array = []
	if unit.is_empty():
		return out
	if bool(unit.get("downed", false)):
		out.append(entry("downed", "skull", "", false, "Down", "Out of the fight until someone revives you."))
	var block: int = int(unit.get("block", 0))
	if block > 0:
		out.append(entry("block", "shield", str(block), true, "Block", "Soaks %d hit damage. At turn start, Retain can preserve some; the rest falls away." % block, DeepUi.BLOCK))
	var statuses: Dictionary = unit.get("statuses", {})
	out.append_array(_statuses(statuses, false))
	var buried: int = unit.get("buried", []).size()
	if buried > 0:
		out.append(entry("buried", "rampart", str(buried), false, "Buried", "%s buried in rubble: %s cannot fire this turn." % [DeepUi.plural(buried, "socket"), "that gem" if buried == 1 else "those gems"]))
	var clouded: int = unit.get("clouded", []).size()
	if clouded > 0:
		out.append(entry("clouded", "cloud", str(clouded), false, "Clouded", "%s fogged: %s cannot fire until you hit the creature that clouded it." % [DeepUi.plural(clouded, "socket"), "that gem" if clouded == 1 else "those gems"]))
	var stolen: int = int(unit.get("stolen_dice", 0))
	if stolen > 0:
		out.append(entry("stolen", "die", "−%d" % stolen, false, "Dice taken", "You roll %s next turn." % DeepUi.plural(stolen, "die fewer", "dice fewer")))
	var gifts: int = int(unit.get("granted_rerolls", 0))
	if gifts > 0:
		out.append(entry("gifts", "reroll", "+%d" % gifts, true, "Extra rerolls", "%s more next turn." % DeepUi.plural(gifts, "reroll")))
	var amplify: float = float(unit.get("amplify", 1.0))
	if amplify > 1.001:
		out.append(entry("amplify", "bolt", "×%.1f" % amplify, true, "Amplified", "The next gem to fire hits ×%.1f as hard." % amplify))
	var cut_bonus: int = int(unit.get("cut_step_bonus", 0))
	if cut_bonus > 0 and str(battle.get("phase", "")) == "resolving":
		out.append(entry("cut", "cut", "+%d" % cut_bonus, true, "Sharpened", "The next gem is judged %s better." % DeepUi.plural(cut_bonus, "Cut step")))
	if bool(unit.get("nullify_next", false)):
		out.append(entry("nullify", "cross_out", "", false, "Came up empty", "Double Down lost: the next gem does nothing."))
	var quality: int = int(unit.get("quality_bonus", 0))
	if quality > 0:
		out.append(entry("quality", "star", "+%d%%" % quality, true, "Windfall", "Stones found after this fight are %d%% better." % quality, DeepUi.ACCENT))
	var upgrades: Array = []
	for stone in unit.get("rail", []):
		if not stone is Dictionary:
			continue
		var bonus: Dictionary = unit.get("gem_buffs", {}).get(str(stone.id), {})
		var parts: Array = []
		for rank in ["carat", "cut", "clarity"]:
			var amount: int = int(bonus.get(rank, 0)) + int(unit.get("rank_buff", {}).get(rank, 0))
			if amount > 0:
				parts.append("+%d %s" % [amount, rank.capitalize()])
		if not parts.is_empty():
			upgrades.append("%s: %s" % [DeepStone.name(stone), ", ".join(parts)])
	if not upgrades.is_empty():
		out.append(entry("gem_upgrades", "gem", str(upgrades.size()), true, "Gem upgrades — this fight", "\n".join(upgrades)))
	out.append_array(for_run(unit))
	return out

static func for_run(unit: Dictionary) -> Array:
	## What a player carries through the whole run, not just one fight.
	var out: Array = []
	var sparkle: int = clampi(int(unit.get("sparkle", 0)), 0, DeepRules.SPARKLE_MAX_STACKS)
	if sparkle > 0:
		out.append(entry("sparkle", "spark", "%d/100" % sparkle, true, "Sparkle", "Your next stone find consumes all %d Sparkle for +%d generation luck. Maximum 100; carries between fights." % [sparkle, sparkle], DeepUi.ACCENT))
	var shrine: String = str(unit.get("run_mods", {}).get("shrine", ""))
	if not shrine.is_empty():
		out.append(entry("shrine", "star", "+1 ct", true, "Shrine blessing", "For the rest of the run, every gem that fires on %s gains 1 carat." % shrine.replace("_", " "), DeepUi.ACCENT))
	return out

static func for_enemy(foe: Dictionary, battle: Dictionary = {}) -> Array:
	var out: Array = []
	var block: int = int(foe.get("block", 0))
	if block > 0:
		out.append(entry("block", "shield", str(block), false, "Block", "Soaks %d hit damage. When the enemy side acts, Retain can preserve some; the rest falls away." % block, DeepUi.BLOCK))
	## For a creature the colors flip: what helps it is bad for the party.
	for chip in _statuses(foe.get("statuses", {}), true):
		out.append(chip)
	var downgrade: int = int(foe.get("dread_turns", 0))
	if downgrade > 0:
		out.append(entry("dread", "thorn", str(downgrade), true, "Dread", "All its dice are %d tiers smaller (minimum d2). One stack wears off after each action phase." % downgrade))
	var clouded: int = int(foe.get("statuses", {}).get("clouded", 0))
	if clouded > 0:
		var moves: Array = DeepCreatures.moves_for(foe)
		var index: int = mini(int(foe.get("clouded_move", -1)), moves.size() - 1)
		var skill: String = str(moves[index].get("name", "One ability")) if index >= 0 else "One ability"
		out.append(entry("clouded", "cloud", str(clouded), true, "Clouded", "%s is disabled for %s. Reapplication extends its duration." % [skill, DeepUi.plural(clouded, "action phase")]))
	var bound: int = int(foe.get("stolen_dice", 0))
	if bound > 0:
		out.append(entry("bound", "broken_chain", "−%d" % bound, true, "Bound", "Its next action rolls %s, even if that leaves none." % DeepUi.plural(bound, "die fewer", "dice fewer")))
	var upgrade: int = int(foe.get("dice_upgrade", 0))
	if upgrade > 0:
		out.append(entry("upgrade", "die", "+%d" % upgrade, false, "Larger dice", "Dice raised %d tiers for this fight (maximum d100)." % upgrade))
	var gold: int = int(foe.get("stolen_gold", 0))
	if gold > 0:
		out.append(entry("gold", "coin_fall", str(gold), false, "Stolen pyrite", "It carries %d of your pyrite. Kill it to get it back." % gold, DeepUi.ORE))
	if bool(foe.get("warden", false)) and int(foe.get("phase", 0)) > 0:
		out.append(entry("phase", "crown", "%d" % (int(foe.phase) + 1), false, "Enraged phase", "Hurt below its threshold, it fights with a new set of moves."))
	var gimmick: String = str(foe.get("gimmick", ""))
	if GIMMICKS.has(gimmick):
		var g: Array = GIMMICKS[gimmick]
		out.append(entry("gimmick", str(g[0]), "", false, str(g[1]), str(g[2]), Color("c8a8ff")))
	return out

static func for_battle(battle: Dictionary) -> Array:
	## The fight itself: the creatures grow vicious if it drags on.
	var out: Array = []
	var turn: int = int(battle.get("turn", 1))
	var enrage_turn: int = int(DeepContent.constant("enrage_turn", 7))
	var step: int = int(DeepContent.constant("enrage_damage", 2))
	if turn >= enrage_turn:
		var extra: int = step * (turn - enrage_turn + 1)
		out.append(entry("enrage", "flame", "+%d" % extra, false, "Enraged", "The fight has dragged on: every creature hit deals %d more damage, and more each turn." % extra))
	elif turn >= enrage_turn - 3:
		out.append(entry("enrage_soon", "hourglass", "%d" % (enrage_turn - turn), false, "Enrage coming", "In %s the creatures enrage and hit harder every turn." % DeepUi.plural(enrage_turn - turn, "turn"), Color("ffb05a")))
	return out

static func _statuses(statuses: Dictionary, on_enemy: bool) -> Array:
	var out: Array = []
	var poison: int = int(statuses.get("poison", 0))
	if poison > 0:
		out.append(entry("poison", "drop", str(poison), on_enemy, "Poison", "Loses %d HP at the end of the turn, then one less each turn." % poison, DeepUi.POISON))
	var stun: int = int(statuses.get("stun", 0))
	if stun > 0:
		out.append(entry("stun", "stun", str(stun), on_enemy, "Stunned", ("Skips its next action phase." if on_enemy else "Your rail does not fire next time it would.") + (" (%d)" % stun if stun > 1 else ""), Color("ffe27a")))
	var curse: int = clampi(int(statuses.get("curse", 0)), 0, DeepRules.CURSE_MAX_STACKS)
	if curse > 0:
		out.append(entry("curse", "eye", str(curse), on_enemy, "Cursed", "Deals %d%% less hit damage (minimum zero) and takes %d%% more. Maximum 10 stacks; loses one at turn end." % [curse * DeepRules.CURSE_PERCENT, curse * DeepRules.CURSE_PERCENT] + (" A new enemy application lasts through your next turn." if not on_enemy else ""), Color("c58bff")))
	var breaker: int = int(statuses.get("combo_breaker", 0))
	if breaker > 0:
		out.append(entry("combo_breaker", "shield_burst", "", not on_enemy, "Combo Breaker", "After three consecutive stunned turns, clears all Stun and rejects new Stun through its next turn.", DeepUi.INFO))
	var descriptions: Dictionary = {
		"lifeline": ["pulse", "Lifeline", "The next lethal hit or Poison tick consumes all stacks and restores %d HP, up to maximum HP. Lasts this fight.", true],
		"ward": ["shield_burst", "Ward", "Blocks the next %d debuff applications, consuming one charge each. Maximum 99. Lasts this fight.", true],
		"retain": ["shield", "Retain", "Preserves up to %d unspent Block at the next Block reset, then is consumed. Maximum 20.", true],
		"charged": ["bolt", "Charged Battery", "At next turn start, consumes all stacks to start your rail at %d Resonance.", true],
		"marked": ["eye", "Marked", "The next direct hit takes +%d%% damage, then consumes every mark. Block does not prevent consumption.", false],
		"regeneration": ["heart", "Regeneration", "Heals %d HP at turn end after Poison, then loses one stack. Cannot revive.", true],
		"spikes": ["thorn", "Spikes", "Retaliates for %d hit damage once per attacking gem or ability, including blocked hits. Expires at the next Block reset.", true],
		"dulled": ["cut", "Dulled", "Gems lose %d Cut steps after bonuses (minimum Poor). Loses one stack at turn end; Birthstone is unaffected.", false]}
	for key in descriptions:
		var value: int = int(statuses.get(key, 0))
		if value <= 0:
			continue
		var info: Array = descriptions[key]
		var good: bool = bool(info[3]) != on_enemy
		var timing: String = " A new enemy application lasts through your next turn." if key == "dulled" and not on_enemy else ""
		out.append(entry(str(key), str(info[0]), str(value), good, str(info[1]), str(info[2]) % (value * 25 if key == "marked" else value) + timing))
	return out

# --- showing them ------------------------------------------------------------------------------

class Chip extends PanelContainer:
	## One effect: a mark in a ring of its color and the number beside it. Hover for the
	## sentence. It swells when the number changes, so a new poison stack is seen landing.
	var key: String = ""
	var _value: Label
	var _last: String = ""
	func _init(effect: Dictionary, edge: float = 16.0) -> void:
		key = str(effect.key)
		var tone: Color = effect.tone
		var style := StyleBoxFlat.new()
		style.bg_color = Color(tone.darkened(0.7), 0.85)
		style.border_color = Color(tone, 0.85)
		style.set_border_width_all(1)
		style.border_width_bottom = 2
		style.set_corner_radius_all(int(edge))
		style.content_margin_left = 6
		style.content_margin_right = 8 if not str(effect.value).is_empty() else 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		add_theme_stylebox_override("panel", style)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "%s\n%s" % [str(effect.title), str(effect.text)]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var mark := GemIcons.glyph(row, str(effect.glyph), edge, tone.lightened(0.2), tooltip_text)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_value = Label.new()
		_value.add_theme_font_size_override("font_size", int(edge * 0.82))
		_value.add_theme_color_override("font_color", tone.lightened(0.35))
		_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_value)
		set_value(str(effect.value), false)
	func set_value(value: String, animate: bool = true) -> void:
		_value.text = value
		_value.visible = not value.is_empty()
		if animate and value != _last:
			DeepUi.pulse(self, 1.35, 0.4)
		_last = value

class Row extends HFlowContainer:
	## A row of chips that keeps its chips between updates, adds new ones with a pop,
	## pulses the ones whose number moved, and lets go of the ones that ended.
	var edge: float = 16.0
	var _chips: Dictionary = {}
	func _init(chip_edge: float = 16.0) -> void:
		edge = chip_edge
		add_theme_constant_override("h_separation", 4)
		add_theme_constant_override("v_separation", 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func show_effects(effects: Array) -> void:
		var present: Dictionary = {}
		var index: int = 0
		for effect in effects:
			var key: String = str(effect.key)
			present[key] = true
			var chip: Chip = _chips.get(key, null)
			if chip == null or not is_instance_valid(chip):
				chip = Chip.new(effect, edge)
				add_child(chip)
				_chips[key] = chip
				DeepUi.pop_in(chip, 0.0, 0.5)
			else:
				chip.tooltip_text = "%s\n%s" % [str(effect.title), str(effect.text)]
				chip.set_value(str(effect.value))
			move_child(chip, index)
			index += 1
		for key in _chips.keys():
			if not present.has(key):
				var gone: Chip = _chips[key]
				_chips.erase(key)
				if is_instance_valid(gone):
					var tween := gone.create_tween()
					tween.tween_property(gone, "modulate:a", 0.0, 0.2)
					tween.tween_callback(gone.queue_free)
