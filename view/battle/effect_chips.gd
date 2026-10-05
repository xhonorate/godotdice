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
	"roll_for_you": ["die", "Roller", "On odd turns it rolls your dice for you, and you get no rerolls."],
	"regrow": ["heart", "Regrows", "Heals 3 at the end of every turn."]}

## The traits the deeper mines' creatures carry (docs/BESTIARY.md), in the same words. A
## trait with a number says it with %d; `aura` is spelled out from its statuses.
const TRAITS: Dictionary = {
	"steadfast": ["shield_burst", "Steadfast", "Stun, Bound and Clouded last half as long on it, and it cannot be stunned two actions in a row."],
	"sturdy": ["rampart", "Sturdy", "No single hit takes more than %d%% of its health off it."],
	"backlash": ["bolt", "Backlash", "While it lives, every gem that fires costs its owner 1 health."],
	"flee": ["hourglass", "Flees", "After its %d%s action it leaves the fight with everything it stole."],
	"rising": ["flame", "Rising", "Deals %d%% more than the action before, every action."],
	"escalate": ["sword", "Escalating", "Its damage goes up by %d for every action it takes in this phase."],
	"spikes": ["thorn", "Bristling", "Has %d Spikes up every time it acts: anything that hits it is hit back."],
	"regen_with_escorts": ["heart", "Fed", "While any of its escorts stands, it heals %d at the end of every turn."],
	"shielded_by_escorts": ["shield", "Shielded", "While any of its escorts stands, it takes %d%% less from every hit."],
	"regrow_escorts": ["copy", "Regrows its escorts", "A dead escort grows back %d actions later, unless all of them die within %d turns of each other."],
	"reroll_drain": ["drop", "Costly light", "Each reroll anyone spends costs every player %d health."],
	"reroll_scorch": ["flame", "Burning light", "Each reroll anyone spends Scorches every player %d."],
	"punish_straight": ["die", "Shatters straights", "Anyone whose hand holds a straight has their highest die locked for the next turn."],
	"drops_stone": ["star", "Hoard", "Drops a raw stone when it dies."],
	"carat_cap": ["gem", "Weighs every gem", "While it stands no gem counts for more than %d carats."],
	"resonance_damp": ["cross_out", "Dampening", "While it lives your gems ring for %d%% less Resonance."],
	"colour_strength": ["prism", "Feeds on colour", "The first time it sees each colour of gem fire, it gains 1 Strength."],
	"aura": ["cloud", "Aura", "While it lives, every player is %s."]}

static func trait_entry(key: String, value: Variant) -> Dictionary:
	## One trait as a chip. Traits the older gimmick table already names use its words.
	if GIMMICKS.has(key):
		var g: Array = GIMMICKS[key]
		return entry("trait_" + key, str(g[0]), "", false, str(g[1]), str(g[2]), Color("c8a8ff"))
	if not TRAITS.has(key):
		return entry("trait_" + key, "spark", "", false, key.capitalize(), "", Color("c8a8ff"))
	var t: Array = TRAITS[key]
	var text: String = str(t[2])
	var shown: String = ""
	var number: int = int(value) if (value is int or value is float) else 0
	match key:
		"aura":
			var parts: Array = []
			if value is Dictionary:
				for status in value:
					parts.append("%s %d" % [str(status).capitalize(), int(value[status])])
			text = text % (", ".join(parts) if not parts.is_empty() else "afflicted")
		"flee":
			text = text % [number, _ordinal_suffix(number)]
			shown = str(number)
		"regrow_escorts":
			text = text % [number, number]
		_:
			if text.contains("%d"):
				text = text % number
				shown = ("%d%%" % number) if text.contains("%") and key in ["sturdy", "rising", "shielded_by_escorts", "resonance_damp"] else str(number)
	return entry("trait_" + key, str(t[0]), shown, false, str(t[1]), text, Color("c8a8ff"))

static func _ordinal_suffix(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	return {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")

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
	var locked: Array = unit.get("hand", []).filter(func(r: Dictionary) -> bool: return bool(r.get("lock_next", false)) or bool(r.get("locked_by_foe", false)))
	if not locked.is_empty():
		var now: bool = locked.any(func(r: Dictionary) -> bool: return bool(r.get("locked_by_foe", false)))
		out.append(entry("locked", "die", str(locked.size()), false, "Locked dice", ("%s came up as last turn and cannot be rerolled." if now else "%s will come up next turn exactly as it shows now, and cannot be rerolled.") % DeepUi.plural(locked.size(), "die", "dice")))
	var dread: int = int(statuses.get("dread", 0))
	if dread > 0:
		out.append(entry("dread", "thorn", str(dread), false, "Dread", "Next turn your whole bowl rolls %s smaller." % DeepUi.plural(dread, "size")))
	var fired: int = int(unit.get("fired_count", 0))
	if not battle.is_empty() and DeepBattle.living(battle.get("enemies", [])).any(func(f: Dictionary) -> bool: return DeepCreatures.has_trait(f, "backlash")):
		out.append(entry("backlash", "bolt", "−%d" % fired if str(battle.get("phase", "")) == "resolving" and fired > 0 else "", false, "Backlash",
			"Every gem that fires costs you 1 health while it lives (never your last).", Color("ff8ad8")))
	var gifts: int = int(unit.get("granted_rerolls", 0))
	if gifts > 0:
		out.append(entry("gifts", "reroll", "+%d" % gifts, true, "Extra rerolls", "%s more next turn." % DeepUi.plural(gifts, "reroll")))
	## What the Gambler has riding. It has already left his bank, so the chip says both what
	## winning gives back and what a Bust would cost him.
	var pot: int = int(unit.get("pot", 0))
	if pot > 0:
		out.append(entry("pot", "coins", str(pot), true, "The pot",
			"%d Pyrite on the table. Win the fight and it all comes back; Bust and it is gone, and half of it comes out of you (%d damage)." % [pot, pot / 2],
			DeepUi.ACCENT))
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
		out.append(entry("quality", "star", "+%d" % quality, true, "Hot Streak", "Stones found when this fight is won roll at +%.1f generation luck, and are %d%% likelier to turn up at all." % [float(quality) / 10.0, quality / 2], DeepUi.ACCENT))
	## A gem raised mid-fight is not a chip here: the rail draws the raised ranks on the gem
	## itself, where the player is already looking, and it grows to the carat it now counts as.
	out.append_array(for_run(unit))
	return out

static func for_run(unit: Dictionary) -> Array:
	## What a player carries through the whole run, not just one fight.
	var out: Array = []
	var sparkle: int = clampi(int(unit.get("sparkle", 0)), 0, DeepRules.SPARKLE_MAX_STACKS)
	if sparkle > 0:
		out.append(entry("sparkle", "spark", "%d/100" % sparkle, true, "Sparkle", "Your next stone find consumes all %d Sparkle for +%.1f generation luck, %s of a point each. Maximum 100; carries between fights." % [sparkle, float(sparkle) * DeepRules.SPARKLE_LUCK, str(DeepRules.SPARKLE_LUCK)], DeepUi.ACCENT))
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
	if bool(foe.get("burrowed", false)):
		out.append(entry("burrowed", "rampart", "", true, "Burrowed", "Under the floor: it cannot be targeted until its next action. Your gems hit another creature instead, or wait."))
	var drinking: Array = foe.get("absorb", [])
	if not drinking.is_empty():
		var names: Array = drinking.map(func(c: Variant) -> String: return str(DeepContent.color(str(c)).get("name", str(c).capitalize())))
		var tone: Color = Color("#" + str(DeepContent.color(str(drinking[0])).get("hue", "c8a8ff")))
		out.append(entry("absorb", "prism", " · ".join(names), true, "Drinking " + " and ".join(names),
			"%s gems do it no damage, and what they would give their owner (block, healing, Ward) goes to it instead. It drinks afresh when it next acts." % " and ".join(names), tone))
	var reflect: int = int(foe.get("reflect", 0))
	if reflect > 0:
		out.append(entry("reflect", "prism", "%d%%" % reflect, true, "Refracting", "Until its next action, %d%% of every blow it takes goes back at every player." % reflect, Color("c8b8ff")))
	var mirror: int = int(foe.get("mirror", 0))
	if mirror > 0:
		out.append(entry("mirror", "copy", str(mirror) if mirror > 1 else "", true, "Mirror", "The next blow on it goes back whole at whoever threw it." if mirror == 1 else "The next %d blows on it go back at whoever threw them." % mirror, Color("c8b8ff")))
	var charge: int = DeepCreatures.charge_turns(foe)
	if charge > 0:
		var gathering: Dictionary = foe.get("charging", {})
		var words: String = "Winding up %s: it lets go in %s." % [str(gathering.get("name", "a blow")), DeepUi.plural(charge, "action")]
		if bool(gathering.get("store", false)):
			words += " It throws back everything dealt to it meanwhile (%d so far)." % int(gathering.get("stored", 0))
		if int(gathering.get("guard_pct", 0)) > 0:
			words += " It takes %d%% less while it gathers." % int(gathering.guard_pct)
		if int(gathering.get("cancel_pct", 0)) > 0:
			words += " Taking %d%% of its health off it meanwhile breaks the charge." % int(gathering.cancel_pct)
		out.append(entry("charging", "bolt", str(charge), true, "Charging", words, Color("ffe27a")))
	var empowered: int = int(foe.get("empowered", 0))
	if empowered > 0:
		out.append(entry("empowered", "sword", "+%d%%" % empowered, false, "Empowered", "Its next attack deals %d%% more." % empowered))
	var rally: int = int(foe.get("rally_bonus", 0))
	if rally > 0:
		out.append(entry("rally", "sword", "+%d" % rally, false, "Rallied", "Deals %d more with every blow this turn." % rally))
	var swell: int = int(foe.get("swell", 0))
	if swell > 0:
		out.append(entry("swell", "drop", str(swell), false, "Swollen", "Its burst will poison every player for %d when it dies." % swell, DeepUi.POISON))
	var held: int = foe.get("held_gems", []).size()
	var taken: int = foe.get("held_gems", []).filter(func(h: Dictionary) -> bool: return not str(h.get("unit", "")).is_empty()).size()
	if held > 0:
		var said: String = "%s taken off the party's rails. Kill it to get %s back." % [DeepUi.plural(taken, "gem"), "it" if taken == 1 else "them"] if taken > 0 else ""
		if held > taken:
			said = ("%s of its own. " % DeepUi.plural(held - taken, "gem") + said).strip_edges()
		if DeepCreatures.moves_for(foe).any(func(m: Dictionary) -> bool: return m.get("effects", []).any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "exhibit")):
			said += " It can fire every one of them as its own."
		out.append(entry("held_gems", "gem", str(held), false, "Holding gems", said, DeepUi.ACCENT))
	var flee: int = DeepCreatures.trait_value(foe, "flee", 0)
	if flee > 0:
		var left: int = maxi(0, flee - int(foe.get("turns_acted", 0)))
		out.append(entry("fleeing", "hourglass", str(left), false, "Leaving", "It flies off with everything it stole after %s." % DeepUi.plural(left, "more action"), Color("ffb05a")))
	for move in DeepCreatures.moves_for(foe):
		if str(move.get("trigger", {}).get("kind", "")) == "every_nth_turn":
			var wait: int = DeepCreatures.next_nth_in(foe, move)
			out.append(entry("nth_" + str(move.get("name", "")), "hourglass", str(wait), false, str(move.get("name", "")) + " coming", "%s fires in %s." % [str(move.get("name", "")), DeepUi.plural(wait, "action")], Color("ffb05a")))
	if not str(foe.get("echo_of", "")).is_empty():
		out.append(entry("echo", "copy", "", false, "Echo", "A Rift echo of %s: its health, dice and moves over again." % str(DeepContent.creature(str(foe.echo_of)).get("name", foe.echo_of)), Color("c8b8ff")))
	if not str(foe.get("escort_of", "")).is_empty():
		out.append(entry("escort", "copy", "", false, "Escort", "It came with the creature it stands beside.", Color("c8b8ff")))
	if not str(foe.get("remembered", "")).is_empty():
		out.append(entry("remembered", "crown", "", false, "Remembered", "A boss the Rift remembers, with one trait more: %s." % str(DeepContent.REMEMBERED_NAMES.get(str(foe.remembered), str(foe.remembered).capitalize())), Color("c8b8ff")))
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
	## Everything it is, as traits: its old-style trick and the newer kinds alike.
	var traits: Dictionary = DeepCreatures.traits_for(foe) if foe.has("key") else ({str(foe.gimmick): true} if not str(foe.get("gimmick", "")).is_empty() else {})
	var keys: Array = traits.keys()
	keys.sort()
	for key in keys:
		## A Flee is already its own countdown chip above (Leaving, with the actions left).
		if str(key) == "flee":
			continue
		if str(key) == "poison_immune" and GIMMICKS.has("poison_immune"):
			out.append(trait_entry("poison_immune", true))
		elif not str(key) in ["gift_rerolls"] or not (traits.has("reroll_drain") or traits.has("reroll_scorch")):
			out.append(trait_entry(str(key), traits[key]))
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
		"dulled": ["cut", "Dulled", "Gems lose %d Cut steps after bonuses (minimum Poor). Loses one stack at turn end; Birthstone is unaffected.", false],
		"festering": ["drop", "Festering", "Healing you receive is halved. Counts down 1 each turn (%d left).", false],
		"scorched": ["flame", "Scorched", "Block you gain is halved. Counts down 1 each turn (%d left).", false],
		"burn": ["flame", "Burn", "Hurts %d at the end of the turn, block soaking it first, then one less each turn.", false],
		"strength": ["sword", "Strength", "Deals %d more with every blow. Lasts the fight.", true]}
	for key in descriptions:
		var value: int = int(statuses.get(key, 0))
		if value <= 0:
			continue
		var info: Array = descriptions[key]
		var good: bool = bool(info[3]) != on_enemy
		var timing: String = " A new enemy application lasts through your next turn." if key in ["dulled", "festering", "scorched"] and not on_enemy else ""
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
