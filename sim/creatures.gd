class_name DeepCreatures
extends RefCounted
## The creatures of the rock: how one is made for a depth and a party, and how it decides
## what it can do. Results are produced one die at a time during its action phase.

static func make(key: String, id: String, depth: int, party: int, scale: Dictionary = {}, rng: RandomNumberGenerator = null, extra: Dictionary = {}) -> Dictionary:
	## `scale` is what the mine adds on top of depth and party: {hp, damage} multipliers. A
	## mine further down breeds the same creatures far tougher. `rng` is only drawn on by a
	## creature that is a copy of another (a Void Echo). `extra` is what a fight adds to the
	## creature as written: the trait a Rift Warden is remembered with.
	var def: Dictionary = DeepContent.creature(key)
	## A Void Echo is some earlier creature over again, in the Rift's own light: its health,
	## dice, moves, phases and traits are the original's and only its name says what it is.
	var echo_of: String = ""
	if def.has("echo") and rng != null:
		echo_of = _echo_source(def.echo, rng)
		if not echo_of.is_empty():
			var source: Dictionary = DeepContent.creature(echo_of).duplicate(true)
			source.name = "%s (%s)" % [str(def.get("name", key)), str(source.get("name", echo_of))]
			source.warden = bool(def.get("warden", false))
			source.erase("echo")
			## An echo will not stay one thing: one face of its first die is Echo Anew, which
			## turns it into another creature from those mines at that one's full health.
			_echo_anew(source, DeepContent.creature(key))
			def = source
	## Pressure Cooker writes a steeper climb into the fight's scale.
	var hp_scale: float = 1.0 + float(scale.get("depth_hp", DeepContent.constant("depth_hp_scale", 0.05))) * float(maxi(0, depth - 1))
	## A party meets as many creatures as a lone delver would, each with a lone delver's
	## health for every player on the run.
	hp_scale *= float(maxi(1, party))
	hp_scale *= maxf(0.01, float(scale.get("hp", 1.0)))
	## Deep in the Rift the scale runs past what a whole number holds: it stops at the ceiling.
	var hp: int = maxi(1, DeepRules.sat_floor(roundf(float(def.get("hp", 10)) * hp_scale)))
	var dice: Array = []
	var index: int = 0
	for die_ref in def.get("dice", []):
		dice.append(face_die(die_ref, "%s_d%d" % [id, index], def.get("moves", [])))
		index += 1
	var traits: Dictionary = {}
	for trait_key in extra.get("traits", {}):
		traits[str(trait_key)] = extra.traits[trait_key]
	var name: String = str(def.get("name", key))
	if not str(extra.get("name_prefix", "")).is_empty():
		name = str(extra.name_prefix) + name
	## The gems a creature walks in holding (the Collector's own Strike and Bulwark): kept like
	## the ones it takes, but nobody's to have back.
	var held: Array = []
	for skill_key in def.get("gems", []):
		held.append({"unit": "", "socket": - 1, "stone": DeepStone.make(str(skill_key), 1, 2, 1, [], {}, "%s_gem%d" % [id, held.size()])})
	## Its defences grow with it: the block it walks in behind, and every block, heal and
	## Regeneration it gives itself, carry the same factor its health was given (`health_pct`).
	return {"id": id, "key": key, "name": name, "side": "enemy", "hp": hp, "max_hp": hp, "hp_scale": hp_scale,
		"block": DeepRules.sat_floor(roundf(float(def.get("block", 0)) * hp_scale)), "statuses": {"ward": clampi(int(def.get("ward", 1 if bool(def.get("warden", false)) else 0)), 0, 99)}, "dice": dice, "hand": [], "moves": [], "move_states": [], "used_combos": [],
		"acting": false, "beat": "", "rolled_die": {}, "damage_bonus": 0, "enrage_bonus": 0, "next_die": 0, "suppressed": 0, "active_move": - 1,
		"gimmick": str(def.get("gimmick", "")), "warden": bool(def.get("warden", false)), "phase": 0,
		"stolen_dice": 0, "dread_turns": 0, "dice_upgrade": 0, "stolen_gold": 0, "stun_streak": 0, "clouded_move": - 1, "threat": int(def.get("threat", 1)),
		"text": str(def.get("text", "")), "damage_mult": maxf(0.01, float(scale.get("damage", 1.0))),
		## The deeper mines' creatures (docs/BESTIARY.md): what the fight pinned on them, and
		## what the fight so far has done to them. Written traits are read from the definition.
		"traits": traits, "echo_of": echo_of, "echo_def": def if not echo_of.is_empty() else {}, "scale": scale.duplicate(true), "depth": depth,
		"turns_acted": 0, "phase_entered_turn": 0, "hp_at_turn": hp, "used_once": [], "burrowed": false, "emerging": false,
		"held_gems": held, "swell": 0, "rally_bonus": 0, "empowered": 0, "charging": {},
		"reflect": 0, "mirror": 0, "absorb": [], "extra_dice": [], "stopped": false, "seen_colors": [],
		"hurt_by": {}, "hurt_by_color": {}, "biggest_hit": 0, "hardest_gem": {},
		"escorts": [], "escort_of": "", "summoned": false, "fled": false, "stun_guard": false, "death_turn": 0}

# --- action dice ------------------------------------------------------------------------
##
## A creature throws action dice (docs/CREATURE_DICE.md): every face of every die is one of its
## moves, named in the content (`"dice": [{"shape": "D8", "faces": ["Claw", "Claw", "Rake",
## ...]}]`), and a face does what its move says when it lands. The face carries the move's
## name, mark and kind (`move`, `mark`, `move_kind`; a face's own `kind` is its etching, as on
## any die) so the die can be drawn, and so a face re-etched mid-fight (`etch`) is the die
## itself changing. A move with no face on any die (a Flee a Snatch turns into, a Blast a
## Reinforce etches) waits in the moves list until a face is etched to it.
const MOVE_KINDS: Array = ["attack", "guard", "meddle", "mend", "ready", "dud"]

static func move_in(moves: Array, name: String) -> Dictionary:
	for move in moves:
		if move is Dictionary and str(move.get("name", "")) == name:
			return move
	return {}

static func dress_face(face: Dictionary, move: Dictionary) -> void:
	face.move = str(move.get("name", ""))
	face.mark = str(move.get("mark", "f_sword"))
	face.move_kind = str(move.get("kind", "attack"))

static func face_die(ref: Variant, id: String, moves: Array) -> Dictionary:
	## One of a creature's dice as written: a shape, and for an action die the move on each
	## face, in order (repeating if the list is short).
	var die: Dictionary = DeepForge.die_from(ref, id)
	if not ref is Dictionary or ref.get("faces", []).is_empty():
		return die
	var names: Array = ref.faces
	for at in range(die.faces.size()):
		dress_face(die.faces[at], move_in(moves, str(names[at % names.size()])))
	if ref.has("label"):
		die.label = str(ref.label)
	return die

static func is_face_die(die: Dictionary) -> bool:
	return not die.get("faces", []).is_empty() and die.faces[0] is Dictionary and die.faces[0].has("move")

static func face_share(enemy: Dictionary) -> Array:
	## Each die's moves and how many of its faces carry each, in the order they first appear:
	## [{shape, label, faces, moves: [{move, count, mark, kind}]}]. What the panel's pips show.
	var out: Array = []
	for die in enemy.get("dice", []):
		var counts: Dictionary = {}
		var order: Array = []
		for face in die.get("faces", []):
			var name: String = str(face.get("move", ""))
			if name.is_empty():
				continue
			if not counts.has(name):
				order.append({"move": name, "mark": str(face.get("mark", "")), "kind": str(face.get("move_kind", "attack"))})
				counts[name] = 0
			counts[name] = int(counts[name]) + 1
		for entry in order:
			entry.count = int(counts[str(entry.move)])
		out.append({"shape": str(die.get("shape", "D6")), "label": str(die.get("label", "")), "faces": die.get("faces", []).size(), "moves": order})
	return out

static func etch(enemy: Dictionary, from: String, to: String, count: int, at_die: int = -1, at_face: int = -1) -> Array:
	## Faces showing one move re-etched to another for the rest of the fight: `count` of them
	## (0 = every one), on one die or any, or one face in particular. Returns what changed.
	var move: Dictionary = move_in(moves_for(enemy), to)
	var changed: Array = []
	if move.is_empty():
		return changed
	var dice: Array = enemy.get("dice", [])
	for d in range(dice.size()):
		if at_die >= 0 and d != at_die:
			continue
		var faces: Array = dice[d].get("faces", [])
		for f in range(faces.size()):
			if at_face >= 0 and f != at_face:
				continue
			if str(faces[f].get("move", "")) != from or (count > 0 and changed.size() >= count):
				continue
			dress_face(faces[f], move)
			changed.append({"die": d, "face": f, "from": from, "to": to, "mark": str(faces[f].mark), "kind": str(faces[f].move_kind)})
	return changed

static func grow_faces(enemy: Dictionary, at_die: int, names: Array, cap: String = "D12") -> Dictionary:
	## The Hollow Crown's Rise: a die grows a size, and its new faces carry these moves.
	var dice: Array = enemy.get("dice", [])
	if at_die < 0 or at_die >= dice.size():
		return {"nothing": true}
	var die: Dictionary = dice[at_die]
	var tier: int = TIERS.find(str(die.get("shape", "D6")))
	var most: int = TIERS.find(cap)
	if tier < 0 or tier >= most:
		return {"nothing": true, "reason": "Its die is as big as it grows."}
	var next: String = str(TIERS[tier + 1])
	var want: int = int(DeepDice.SHAPES[next])
	var moves: Array = moves_for(enemy)
	var added: Array = []
	var index: int = 0
	while die.faces.size() < want:
		var face: Dictionary = DeepDice.face(die.faces.size() + 1)
		dress_face(face, move_in(moves, str(names[index % maxi(1, names.size())])))
		die.faces.append(face)
		added.append(str(face.move))
		index += 1
	die.shape = next
	die.erase("top")
	return {"die": at_die, "shape": next, "added": added}

static func _echo_anew(source: Dictionary, echo_def: Dictionary) -> void:
	## A Void Echo's copy of another creature, with one face of its first die turned to the
	## echo's own Echo Anew.
	var anew: Dictionary = move_in(echo_def.get("moves", []), "Echo Anew")
	if anew.is_empty() or source.get("dice", []).is_empty():
		return
	var moves: Array = source.get("moves", []).duplicate(true)
	if move_in(moves, "Echo Anew").is_empty():
		moves.append(anew.duplicate(true))
	source.moves = moves
	var first: Variant = source.dice[0]
	if first is Dictionary and not first.get("faces", []).is_empty():
		var copy: Dictionary = first.duplicate(true)
		copy.faces[0] = "Echo Anew"
		source.dice[0] = copy

static func become_echo(enemy: Dictionary, source_key: String) -> void:
	## A Void Echo turning into another creature it remembers (its Echo Anew): that one's
	## dice, moves and traits, at that one's full health as this fight breeds it.
	var own: Dictionary = DeepContent.creature(str(enemy.get("key", "")))
	var source: Dictionary = DeepContent.creature(source_key).duplicate(true)
	source.name = "%s (%s)" % [str(own.get("name", enemy.get("key", ""))), str(source.get("name", source_key))]
	source.warden = bool(own.get("warden", false))
	source.erase("echo")
	_echo_anew(source, own)
	var scale: float = float(enemy.get("hp_scale", 1.0))
	var hp: int = maxi(1, DeepRules.sat_floor(roundf(float(source.get("hp", 10)) * scale)))
	enemy.echo_of = source_key
	enemy.echo_def = source
	enemy.name = str(source.name)
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.block = DeepRules.sat_floor(roundf(float(source.get("block", 0)) * scale))
	enemy.morphs = int(enemy.get("morphs", 0)) + 1
	var dice: Array = []
	for at in range(source.get("dice", []).size()):
		dice.append(face_die(source.dice[at], "%s_m%d_%d" % [str(enemy.id), int(enemy.morphs), at], source.get("moves", [])))
	enemy.dice = dice
	enemy.statuses = {"ward": int(enemy.get("statuses", {}).get("ward", 0))}
	enemy.swell = 0
	enemy.hp_at_turn = hp
	for name in enemy.get("pinned", {}):
		enemy.get("traits", {}).erase(name)
	enemy.pinned = {}
	enemy.timed = {}

static func _echo_source(echo: Dictionary, rng: RandomNumberGenerator) -> String:
	## Some ordinary creature out of the mines an echo remembers, each as likely as its weight
	## across every band of those mines.
	var table: Dictionary = {}
	for mine_key in echo.get("mines", []):
		for band in DeepContent.mine(str(mine_key)).get("bands", []):
			for key in band.get("creatures", {}):
				var def: Dictionary = DeepContent.creature(str(key))
				if bool(def.get("warden", false)) or def.has("echo") or bool(def.get("summon_only", false)):
					continue
				table[str(key)] = float(table.get(str(key), 0.0)) + float(band.creatures[key])
	if table.is_empty():
		return ""
	return DeepRng.weighted_key(rng, table)

static func definition(enemy: Dictionary) -> Dictionary:
	## What this creature is written as: its own entry, or for an echo the entry it copies.
	if not enemy.get("echo_def", {}).is_empty():
		return enemy.echo_def
	return DeepContent.creature(str(enemy.get("key", "")))

static func phase_for(enemy: Dictionary) -> int:
	var hp_pct: int = int(float(enemy.get("hp", 0)) * 100.0 / float(maxi(1, int(enemy.get("max_hp", 1)))))
	var selected: int = 0
	var phases: Array = definition(enemy).get("phases", [])
	for index in range(phases.size()):
		if hp_pct <= int(phases[index].get("below_hp_pct", 0)):
			selected = index + 1
	return selected

static func moves_for(enemy: Dictionary) -> Array:
	var def: Dictionary = definition(enemy)
	var phase: int = phase_for(enemy)
	return def.get("phases", [])[phase - 1].get("moves", []) if phase > 0 else def.get("moves", [])

static func traits_for(enemy: Dictionary) -> Dictionary:
	## Everything the creature is at this moment: its written traits, its old-style gimmick
	## read as one, whatever its current phase adds or takes away (a phase trait of 0 or
	## false removes it), and anything the fight pinned on it.
	var def: Dictionary = definition(enemy)
	var out: Dictionary = def.get("traits", {}).duplicate()
	var gimmick: String = str(enemy.get("gimmick", def.get("gimmick", "")))
	if not gimmick.is_empty() and not out.has(gimmick):
		out[gimmick] = true
	var phase: int = phase_for(enemy)
	if phase > 0:
		for key in def.phases[phase - 1].get("traits", {}):
			out[str(key)] = def.phases[phase - 1].traits[key]
	for key in enemy.get("traits", {}):
		out[str(key)] = enemy.traits[key]
	for key in out.keys():
		var value: Variant = out[key]
		if (value is bool and not value) or ((value is int or value is float) and float(value) <= 0.0):
			out.erase(key)
	return out

static func _trait(enemy: Dictionary, name: String) -> Variant:
	## One trait as `traits_for` would read it, or null, without building the whole set: a
	## blow asks after several of them, and every copy of the set was one more dictionary.
	var def: Dictionary = definition(enemy)
	var value: Variant = null
	var pinned: Dictionary = enemy.get("traits", {})
	var phased: Dictionary = {}
	if not pinned.has(name):
		var phase: int = phase_for(enemy)
		if phase > 0:
			phased = def.phases[phase - 1].get("traits", {})
	if pinned.has(name):
		value = pinned[name]
	elif phased.has(name):
		value = phased[name]
	elif def.get("traits", {}).has(name):
		value = def.traits[name]
	elif str(enemy.get("gimmick", def.get("gimmick", ""))) == name and not name.is_empty():
		value = true
	if (value is bool and not value) or ((value is int or value is float) and float(value) <= 0.0):
		return null
	return value

static func has_trait(enemy: Dictionary, name: String) -> bool:
	return _trait(enemy, name) != null

static func trait_value(enemy: Dictionary, name: String, fallback: int = 0) -> int:
	var value: Variant = _trait(enemy, name)
	if value == null:
		return fallback
	if value is bool:
		return 1 if value else 0
	return int(value)

const TIERS: Array = DeepDice.TIERS
const COMBINATIONS: Array = ["pair", "triple", "quad", "quint", "two_pair", "full_house", "straight", "all_odd", "all_even", "match"]
## The move states a creature's table draws. `latent` is a move that waits for its death,
## `spent` one it has used up for the fight.
const MOVE_STATES: Array = ["unrevealed", "clouded", "used", "pending", "missed", "activated", "resolving", "resolved", "latent", "spent"]

static func effective_dice(enemy: Dictionary) -> Array:
	var out: Array = []
	var upgrade: int = int(enemy.get("dice_upgrade", 0))
	var dread: int = maxi(0, int(enemy.get("dread_turns", 0)))
	for base in enemy.get("dice", []) + enemy.get("extra_dice", []):
		var index: int = TIERS.find(str(base.get("shape", "D6")))
		var tier: int = maxi(0, clampi(index + upgrade, 0, TIERS.size() - 1) - dread)
		var key: String = str(TIERS[tier])
		if tier == index:
			out.append(base.duplicate(true))
		elif is_face_die(base):
			out.append(_resized_face_die(base, key))
		else:
			out.append(DeepDice.make(key, str(base.id), {"pattern": str(base.get("pattern", "")), "material": str(base.get("material", ""))}))
	return out

static func _resized_face_die(base: Dictionary, shape: String) -> Dictionary:
	## An action die thrown a size smaller (Dread) or larger keeps its moves: its faces in
	## order, cut short or carried round again.
	var die: Dictionary = base.duplicate(true)
	var want: int = int(DeepDice.SHAPES.get(shape, 6))
	var faces: Array = []
	for at in range(want):
		var face: Dictionary = base.faces[at % base.faces.size()].duplicate(true)
		face.value = at + 1
		faces.append(face)
	die.shape = shape
	die.faces = faces
	die.erase("top")
	return die

static func prepare(enemy: Dictionary) -> void:
	## Public planning information only; this never consumes random numbers.
	var was: int = int(enemy.get("phase", 0))
	enemy.phase = phase_for(enemy)
	if int(enemy.phase) != was:
		enemy.phase_entered_turn = int(enemy.get("turns_acted", 0))
	enemy.moves = moves_for(enemy).duplicate(true)
	enemy.hand = []
	enemy.rolled_die = {}
	enemy.used_combos = []
	enemy.move_states = []
	enemy.next_die = 0
	enemy.active_move = -1
	enemy.acting = false
	enemy.beat = ""
	enemy.suppressed = 0
	for index in range(enemy.moves.size()):
		enemy.move_states.append(_resting_state(enemy, index))

static func _resting_state(enemy: Dictionary, index: int) -> String:
	var move: Dictionary = enemy.moves[index]
	var called: String = _called_state(enemy, move, index)
	if not called.is_empty():
		return called
	if bool(move.get("once", false)) and enemy.get("used_once", []).has(str(move.get("name", ""))):
		return "spent"
	return "clouded" if move_clouded(enemy, index) else "unrevealed"

static func _called_state(enemy: Dictionary, move: Dictionary, index: int) -> String:
	## A move the fight calls rather than a die: one waiting for its death or for its health to
	## fall, spent once that has happened, and one that opens its action, used once it has.
	match str(move.get("trigger", {}).get("kind", "")):
		"on_death":
			return "latent"
		"hp_below":
			return "spent" if enemy.get("used_once", []).has(str(move.get("name", ""))) else "latent"
		"action_begin":
			return "used" if DeepPatch.holds(enemy.get("used_combos", []), index) else "unrevealed"
	return ""

static func move_clouded(enemy: Dictionary, index: int) -> bool:
	return int(enemy.get("statuses", {}).get("clouded", 0)) > 0 and index == mini(int(enemy.get("clouded_move", -1)), enemy.get("moves", []).size() - 1)

static func finish(enemy: Dictionary) -> void:
	enemy.acting = false
	enemy.beat = "done"
	enemy.turns_acted = int(enemy.get("turns_acted", 0)) + 1
	enemy.emerging = false
	## What it was told to throw again, or to stop throwing, was for this action only.
	enemy.extra_dice = []
	enemy.stopped = false
	## What the party did to it this turn has been answered; the next rail writes it afresh.
	enemy.hurt_by = {}
	enemy.hurt_by_color = {}
	enemy.biggest_hit = 0
	enemy.hardest_gem = {}
	## Its health as this action closes, against which a hard turn on it is measured.
	enemy.hp_at_turn = int(enemy.get("hp", 0))
	enemy.dread_turns = maxi(0, int(enemy.get("dread_turns", 0)) - 1)
	if int(enemy.statuses.get("clouded", 0)) > 0:
		enemy.statuses.clouded = int(enemy.statuses.clouded) - 1
		if int(enemy.statuses.clouded) == 0:
			enemy.clouded_move = -1

static func is_combination(move: Dictionary) -> bool:
	return str(move.get("trigger", {}).get("kind", "always")) in COMBINATIONS

static func is_turn_move(move: Dictionary) -> bool:
	## A move the action fires on its own, once, rather than a die.
	return str(move.get("trigger", {}).get("kind", "always")) in DeepPatterns.TURN_KINDS

static func once_an_action(move: Dictionary) -> bool:
	return is_combination(move) or is_turn_move(move)

static func activation(move: Dictionary, history: Array, last: bool, context: Dictionary = {}) -> Dictionary:
	var face_kind: String = str(move.get("trigger", {}).get("kind", ""))
	if face_kind == "face":
		## Its own face landed on the die just thrown.
		var thrown: Dictionary = history.back() if not history.is_empty() else {}
		var landed: bool = str(thrown.get("move", "")) == str(move.get("name", ""))
		return {"active": landed, "dice": [str(thrown.get("die_id", ""))] if landed else [], "kind": "face", "need": 0,
			"value": 0, "count": 1 if landed else 0, "reason": "" if landed else "Its face did not land."}
	if face_kind == "match":
		return _matched(move.trigger, history)
	var combo: bool = is_combination(move)
	var read: Array = history if combo else history.slice(-1)
	var a: Dictionary = DeepHand.analyze(read)
	var trigger: Dictionary = move.get("trigger", {"kind": "always"})
	var result: Dictionary = DeepPatterns.evaluate(trigger, 0, a, context)
	if str(trigger.get("kind", "")) in ["all_odd", "all_even"] and not last:
		result.active = false
	## A move that reads one die in particular ignores the others.
	if trigger.has("die") and not combo and not is_turn_move(move) and int(context.get("roll_index", -1)) != int(trigger.die):
		result.active = false
		result.reason = "Reads die %d." % (int(trigger.die) + 1)
	return result

static func _matched(trigger: Dictionary, history: Array) -> Dictionary:
	## Faces landing together in one action: `count` of the first named face, or (no count)
	## every named face at least once. The Choir's three heads on Requiem, Spore with Rot.
	var faces: Array = trigger.get("faces", [])
	var landed: Array = history.filter(func(r: Dictionary) -> bool: return faces.has(str(r.get("move", ""))))
	var need: int = int(trigger.get("count", 0))
	var met: bool = false
	if faces.is_empty():
		met = false
	elif need > 0:
		met = landed.filter(func(r: Dictionary) -> bool: return str(r.get("move", "")) == str(faces[0])).size() >= need
	else:
		met = faces.all(func(f: Variant) -> bool: return landed.any(func(r: Dictionary) -> bool: return str(r.get("move", "")) == str(f)))
	return {"active": met, "dice": landed.map(func(r: Dictionary) -> String: return str(r.get("die_id", ""))) if met else [], "kind": "match",
		"need": need, "value": 0, "count": landed.size(), "reason": "" if met else "Its faces have not landed together."}

static func can_complete(move: Dictionary, history: Array, remaining: Array) -> bool:
	## Look only at possible faces, never at future RNG. Current content has at most 5 dice.
	if is_turn_move(move):
		return false
	if bool(activation(move, history, remaining.is_empty()).active):
		return true
	if remaining.is_empty():
		return false
	var die: Dictionary = remaining[0]
	for face in die.get("faces", []):
		var sample: Dictionary = {"die_id": str(die.id), "value": int(face.value), "kind": str(face.get("kind", "plain")), "top": DeepDice.top(die), "move": str(face.get("move", ""))}
		if can_complete(move, history + [sample], remaining.slice(1)):
			return true
	return false

static func suspense(enemy: Dictionary, remaining: Array) -> bool:
	if remaining.size() != 1 or enemy.get("hand", []).is_empty():
		return false
	for index in range(enemy.moves.size()):
		if move_clouded(enemy, index):
			continue
		var move: Dictionary = enemy.moves[index]
		if bool(move.get("dramatic", false)) and is_combination(move) and not enemy.used_combos.has(index):
			if can_complete(move, enemy.hand, remaining):
				return true
	return false

static func context(enemy: Dictionary, state: Dictionary, roll_index: int = -1) -> Dictionary:
	## What a creature's triggers and amounts may read of the fight: which action this is,
	## whether it is the first die, whether it has just come up out of the floor, and the
	## party's numbers that a few of the deeper creatures weigh (the heaviest gem on any
	## rail, the party's best turn so far, how many stand).
	var players: Array = state.get("players", [])
	var living: int = 0
	var heaviest: int = 0
	var richest: int = 0
	for player in players:
		if int(player.get("hp", 0)) > 0 and not bool(player.get("downed", false)):
			living += 1
			richest = maxi(richest, DeepRules.pyrite(player))
		for stone in player.get("rail", []):
			if stone is Dictionary:
				heaviest = maxi(heaviest, int(stone.get("carat", 1)))
	## The best die any player shows (the Mirror Regent's Mirror Image throws it back), and what
	## it has taken since its last action (its Reflection).
	var high_die: int = 0
	for player in players:
		if int(player.get("hp", 0)) > 0 and not bool(player.get("downed", false)):
			for roll in player.get("hand", []):
				high_die = maxi(high_die, int(roll.get("value", 0)))
	var taken: int = maxi(0, int(enemy.get("hp_at_turn", enemy.get("hp", 0))) - int(enemy.get("hp", 0)))
	return {"first_roll": roll_index == 0, "roll_index": roll_index, "turns_acted": int(enemy.get("turns_acted", 0)) + 1,
		"party_high_die": high_die, "taken_since": taken,
		"emerging": bool(enemy.get("emerging", false)), "turn": int(state.get("turn", 1)), "party": players.size(),
		"living_players": maxi(1, living), "party_heaviest_carat": heaviest, "party_best_turn": int(state.get("party_best_turn", 0)),
		"party_richest": richest}

static func _move_context(enemy: Dictionary, move: Dictionary, ctx: Dictionary) -> Dictionary:
	## A countdown move learns whether this is the action it has been counting to.
	if str(move.get("trigger", {}).get("kind", "")) != "countdown":
		return ctx
	var own: Dictionary = ctx.duplicate()
	own.countdown_due = enemy.get("countdown_due", []).has(str(move.get("name", "")))
	return own

static func countdown_in(enemy: Dictionary, move: Dictionary) -> int:
	## How many actions until a countdown move fires, the coming one counted as 1.
	var whole: int = maxi(1, int(move.get("trigger", {}).get("amount", 1)))
	var counts: Variant = enemy.get("countdowns", {})
	if not counts is Dictionary:
		return whole
	return int(counts.get(str(move.get("name", "")), whole))

static func resolve_roll(enemy: Dictionary, state: Dictionary) -> Array:
	var dice: Array = effective_dice(enemy)
	var available: int = maxi(0, dice.size() - int(enemy.get("suppressed", 0)))
	var remaining: Array = dice.slice(int(enemy.next_die), available)
	var roll_index: int = int(enemy.next_die) - 1
	var ctx: Dictionary = context(enemy, state, roll_index)
	var out: Array = []
	for index in range(enemy.moves.size()):
		var move: Dictionary = enemy.moves[index]
		var called: String = _called_state(enemy, move, index)
		if not called.is_empty():
			enemy.move_states[index] = called
			continue
		if bool(move.get("once", false)) and enemy.get("used_once", []).has(str(move.get("name", ""))):
			enemy.move_states[index] = "spent"
			continue
		if move_clouded(enemy, index):
			enemy.move_states[index] = "clouded"
			continue
		var combo: bool = is_combination(move)
		var once: bool = once_an_action(move)
		if once and enemy.used_combos.has(index):
			enemy.move_states[index] = "used"
			continue
		var trig: Dictionary = activation(move, enemy.hand, remaining.is_empty(), _move_context(enemy, move, ctx))
		if not trig.active:
			enemy.move_states[index] = "pending" if combo and can_complete(move, enemy.hand, remaining) else "missed"
			continue
		enemy.move_states[index] = "activated"
		if once:
			enemy.used_combos.append(index)
		if bool(move.get("once", false)):
			enemy.used_once.append(str(move.get("name", "")))
		out.append(resolved_move(enemy, state, move, index, trig, combo, roll_index))
	return out

static func resolved_move(enemy: Dictionary, state: Dictionary, move: Dictionary, index: int, trig: Dictionary, combo: bool, roll_index: int) -> Dictionary:
	## One move with its numbers filled in against the dice shown so far. Damage carries the
	## mine's multiplier, the depth bonus, a Howl's rallying, its Strength and an Empowered
	## creature's doubled blow, which is spent on the first attack it makes.
	var a: Dictionary = DeepHand.analyze(enemy.hand if combo else enemy.hand.slice(-1))
	var c: Dictionary = context(enemy, state, roll_index)
	c.merge({"a": a, "trig": trig, "unit": enemy, "depth": int(state.get("depth", 1)),
		"rolled": int(enemy.hand.back().value) if not enemy.hand.is_empty() else 0}, true)
	var effects: Array = []
	for definition in move.get("effects", []):
		if str(definition.get("kind", "")) == "exhibit":
			## Every gem it holds goes off as though it were its own move.
			for held in enemy.get("held_gems", []):
				effects.append_array(gem_effects(enemy, held.stone, c))
			continue
		var effect: Dictionary = DeepRules.resolve_effect(definition, c, 1.0, "heroes")
		if str(effect.kind) == "roll_again":
			effect.die = roll_index
		scale_effect(enemy, effect, definition)
		effects.append(effect)
	for effect in effects:
		if str(effect.target) == "hero":
			effect.target = "heroes"
		## Each blow keeps the pieces of its number (what it was before anything was added on,
		## the weight it was given, what went on top), so the screen can count it out.
		if str(effect.kind) == "damage" and bool(effect.get("flat", false)):
			effect.scaled = int(effect.amount)
			effect.adds = [["strength", strength(enemy)]]
			effect.amount = int(effect.amount) + strength(enemy)
		elif str(effect.kind) == "damage":
			var pct: int = damage_pct(enemy)
			effect.depth_pct = pct
			if int(enemy.get("empowered", 0)) > 0:
				pct = pct * (100 + int(enemy.empowered)) / 100
				effect.empowered = int(enemy.empowered)
			effect.scaled = DeepRules.amount({"op": "pct", "args": [int(effect.amount), pct]}, {})
			## Strength, a Howl's rally and an Escalating creature's anger are points on the roll,
			## so they carry the mine's weight as the roll does; only the depth bonus sits on top.
			var adds: Array = [["bonus", int(enemy.get("damage_bonus", 0))], ["rally", weighted(enemy, int(enemy.get("rally_bonus", 0)))],
				["strength", weighted(enemy, strength(enemy) + int(enemy.get("escalate_bonus", 0)))]]
			effect.adds = adds
			effect.amount = int(effect.scaled) + int(adds[0][1]) + int(adds[1][1]) + int(adds[2][1])
		if str(effect.kind) == "charge":
			## What the charge lets go is written down now, in this action's words, so a
			## different phase or a smaller party later cannot change what was promised. A
			## charge that stores what it is dealt fills its blow in when it lets go.
			var release: Array = []
			for sub in effect.get("release", []):
				var ready: Dictionary = DeepRules.resolve_effect(sub, c, 1.0, "heroes")
				if str(ready.target) == "hero":
					ready.target = "heroes"
				if str(ready.kind) == "damage" and not bool(effect.get("store", false)):
					ready.amount = DeepRules.amount({"op": "pct", "args": [int(ready.amount), damage_pct(enemy)]}, {}) + int(enemy.get("damage_bonus", 0)) + weighted(enemy, strength(enemy))
				release.append(ready)
			effect.release = release
	if int(enemy.get("empowered", 0)) > 0 and effects.any(func(e: Dictionary) -> bool: return str(e.kind) == "damage"):
		enemy.empowered = 0
	return {"move": str(move.get("name", "?")), "index": index, "effects": effects,
		"dice": trig.get("dice", []), "combo": combo, "trigger": move.get("trigger", {}), "roll_index": roll_index,
		"mark": str(move.get("mark", "")), "move_kind": str(move.get("kind", "")), "anim": str(move.get("anim", ""))}

## What a creature does for itself, which grows with its health (see `health_pct`).
const HEALTH_SCALED: Array = ["block", "heal", "regeneration", "retain", "max_hp"]

static func health_pct(enemy: Dictionary) -> int:
	## The factor its health was bred with (mine, depth, party, the day's cards), as a whole
	## percentage: a number written as the Quarry would show it weighs the same anywhere.
	return maxi(1, int(round(float(enemy.get("hp_scale", 1.0)) * 100.0)))

static func weighted(enemy: Dictionary, points: int) -> int:
	## Points that sit on a creature's roll (Strength, a rally, its anger) carry the mine's
	## weight on that roll, rounded to the nearest.
	if points == 0:
		return 0
	return int(round(float(points) * float(damage_pct(enemy)) / 100.0))

static func _reads_health(expr: Variant) -> bool:
	## An amount already written as a share of its own health (a quarter more, a tenth back).
	if expr is Dictionary:
		if str(expr.get("term", "")) in ["max_hp", "hp", "hp_missing"]:
			return true
		for arg in expr.get("args", []):
			if _reads_health(arg):
				return true
	return false

static func scale_effect(enemy: Dictionary, effect: Dictionary, definition: Dictionary) -> void:
	## A creature's own numbers, weighed for where it is met: what it does for itself grows
	## with its health, and what it strips from the party's block grows with its blows.
	var kind: String = str(effect.get("kind", ""))
	if kind in HEALTH_SCALED and not _reads_health(definition.get("amount", 0)) and not bool(effect.get("keep_all", false)):
		var pct: int = health_pct(enemy)
		if pct != 100:
			effect.amount = DeepRules.sat_muldiv(int(effect.amount), pct, 100)
			effect.health_pct = pct
	elif kind == "remove_block" and not bool(effect.get("remove_all", false)):
		var pct: int = damage_pct(enemy)
		if pct != 100:
			effect.amount = DeepRules.sat_muldiv(int(effect.amount), pct, 100)
			effect.damage_pct = pct

## What a creature can do with a gem it holds: the effects that land on the party or help the
## creature itself. A gem that only works the hand, the rail or the purse is a trophy to it.
const GEM_USABLE: Array = ["damage", "block", "heal", "poison", "curse", "marked", "dulled", "stun", "remove_block",
	"regeneration", "retain", "spikes", "ward", "dice_dread", "die_steal", "clouded"]

static func gem_usable(stone: Dictionary) -> bool:
	return DeepStone.skill_of(stone).get("effects", []).any(func(e: Variant) -> bool: return e is Dictionary and str(e.get("kind", "")) in GEM_USABLE)

static func gem_effects(enemy: Dictionary, stone: Dictionary, c: Dictionary) -> Array:
	## A held gem fired by the creature: its skill read against the creature's own dice at
	## the gem's Cut, as one carat, whatever the hand shows. What it would do to "the enemy"
	## lands on the party; what it would do for its owner, the creature has.
	var skill: Dictionary = DeepStone.skill_of(stone)
	var cut: int = int(stone.get("cut", 0))
	var a: Dictionary = DeepHand.analyze(enemy.get("hand", []))
	var trig: Dictionary = DeepPatterns.evaluate(skill.get("trigger", {"kind": "always"}), cut, a)
	if not bool(trig.get("active", false)):
		trig.active = true
		trig.value = int(a.get("best_set", {}).get("value", a.get("high", 0)))
		trig.count = maxi(1, int(a.get("best_set", {}).get("count", 1)))
		trig.dice = []
	var gc: Dictionary = c.duplicate()
	gc.merge({"a": a, "trig": trig, "cut": cut, "carat": 1, "clarity": int(stone.get("clarity", 0)), "resonance": 0, "previous_amount": 0}, true)
	var out: Array = []
	for definition in skill.get("effects", []):
		if not definition is Dictionary or not str(definition.get("kind", "")) in GEM_USABLE:
			continue
		var effect: Dictionary = DeepRules.resolve_effect(definition, gc, 1.0, "heroes")
		scale_effect(enemy, effect, definition)
		effect.gem = str(skill.get("name", stone.get("skill", "")))
		effect.repeat = maxi(1, int(effect.get("repeat", 1)))
		out.append(effect)
	return out

static func strength(enemy: Dictionary) -> int:
	## A flat point more on every blow for every stack it has gathered this fight.
	return maxi(0, int(enemy.get("statuses", {}).get("strength", 0)))

static func death_moves(enemy: Dictionary) -> Array:
	## The moves that wait for this creature to die, in its current phase.
	return moves_for(enemy).filter(func(m: Dictionary) -> bool: return str(m.get("trigger", {}).get("kind", "")) == "on_death")

static func moves_called(enemy: Dictionary, kind: String) -> Array:
	## The moves of its current phase that the fight calls by this kind, with their places.
	var out: Array = []
	var moves: Array = moves_for(enemy)
	for index in range(moves.size()):
		if str(moves[index].get("trigger", {}).get("kind", "")) == kind:
			out.append({"index": index, "move": moves[index]})
	return out

static func refresh_bonuses(enemy: Dictionary, state: Dictionary) -> void:
	var count: int = maxi(1, enemy.get("dice", []).size())
	var threat: int = int(state.get("threat", state.get("depth", 1)))
	enemy.damage_bonus = int(threat / maxi(1, int(enemy.get("scale", {}).get("damage_every", DeepContent.constant("depth_damage_every", 4))))) / count
	if has_trait(enemy, "mirror_last_gem"):
		var reflected: int = 0
		for player in state.get("players", []):
			reflected = maxi(reflected, int(player.get("dealt_last_turn", 0)) / 2)
		enemy.damage_bonus += mini(6, reflected) / count
	## Escalating: a point more on every blow for each action it has spent in this phase, on
	## the roll, so the mine's weight carries it (`resolved_move`).
	var escalate: int = trait_value(enemy, "escalate", 0)
	enemy.escalate_bonus = escalate * maxi(0, int(enemy.get("turns_acted", 0)) - int(enemy.get("phase_entered_turn", 0))) if escalate > 0 else 0
	enemy.enrage_bonus = maxi(0, int(state.get("turn", 1)) - DeepBattle.enrage_turn(state) + 1) * DeepBattle.enrage_step(state)

static func damage_pct(enemy: Dictionary) -> int:
	## The mine's damage multiplier as a whole percentage, so what a move says it will deal
	## and what it deals are worked out the same way. A Rising creature's grows by its share
	## for every action it has taken.
	var pct: float = float(enemy.get("damage_mult", 1.0)) * 100.0
	var rising: int = trait_value(enemy, "rising", 0)
	if rising > 0:
		pct *= pow(1.0 + float(rising) / 100.0, float(int(enemy.get("turns_acted", 0))))
	return int(round(pct))

static func charge_turns(enemy: Dictionary) -> int:
	## How many of its actions a charging creature still has to wait, or 0.
	return int(enemy.get("charging", {}).get("turns", 0))

static func next_nth_in(enemy: Dictionary, move: Dictionary) -> int:
	## For a move that fires every nth action: how many actions away the next one is, counting
	## the action about to come as 1.
	var every: int = int(move.get("trigger", {}).get("amount", 0))
	if every <= 0:
		return 0
	var upcoming: int = int(enemy.get("turns_acted", 0)) + 1
	var wait: int = (every - upcoming % every) % every
	return wait + 1

static func display_moves(enemy: Dictionary, moves: Array = []) -> Array:
	var shown: Array = (enemy.get("moves", []) if moves.is_empty() else moves).duplicate(true)
	var bonus: int = int(enemy.get("damage_bonus", 0)) + int(enemy.get("enrage_bonus", 0)) + weighted(enemy, int(enemy.get("rally_bonus", 0)))
	bonus += weighted(enemy, strength(enemy) + int(enemy.get("escalate_bonus", 0)))
	for move in shown:
		for effect in move.get("effects", []):
			var kind: String = str(effect.get("kind", ""))
			if kind in HEALTH_SCALED and not _reads_health(effect.get("amount", 0)) and not bool(effect.get("keep_all", false)) and health_pct(enemy) != 100:
				effect.amount = {"op": "pct", "args": [effect.get("amount", 0), health_pct(enemy)]}
			elif kind == "remove_block" and not bool(effect.get("remove_all", false)) and damage_pct(enemy) != 100:
				effect.amount = {"op": "pct", "args": [effect.get("amount", 0), damage_pct(enemy)]}
			## Its Poison and Burn keep their stacks, and every round of them hurts with the
			## weight on its blows (`DeepBattle.tick_amount`): said beside the number.
			if kind in ["poison", "burn"] and not str(effect.get("target", "heroes")) in ["self", "allies", "allies_other", "ally_low"]:
				var weight: int = int(round(float(enemy.get("damage_mult", 1.0)) * 100.0))
				if weight != 100:
					effect.weight = weight
			if str(effect.kind) == "damage" and bool(effect.get("flat", false)):
				## Its own number and its Strength, nothing more.
				if strength(enemy) > 0:
					effect.amount = {"op": "+", "args": [effect.get("amount", 0), strength(enemy)]}
				continue
			if str(effect.kind) == "damage":
				if damage_pct(enemy) != 100:
					effect.amount = {"op": "pct", "args": [effect.get("amount", 0), damage_pct(enemy)]}
				if bonus > 0:
					effect.amount = {"op": "+", "args": [effect.get("amount", 0), bonus]}
				var pct: int = DeepRules.outgoing_damage(100, enemy.get("statuses", {}))
				if pct != 100:
					effect.amount = {"op": "pct", "args": [effect.get("amount", 0), pct]}
	return shown

static func move_text(enemy: Dictionary, move: Dictionary) -> String:
	## What a move does, in the words written for it, with its numbers as this creature
	## deals them here: `{0}`, `{1}` stand for its first, second effect's amount (a Strength,
	## the mine's weight and the like already on), `{n}` for its first.
	var text: String = str(move.get("text", ""))
	if text.is_empty():
		return " · ".join(move.get("effects", []).map(func(e: Dictionary) -> String: return effect_words(e)))
	var shown: Array = display_moves(enemy, [move])
	var effects: Array = shown[0].get("effects", []) if not shown.is_empty() else []
	for at in range(effects.size()):
		var key: String = "{%d}" % at
		if text.contains(key) or (at == 0 and text.contains("{n}")):
			var n: String = str(DeepRules.amount(effects[at].get("amount", 0), {"unit": enemy}))
			text = text.replace(key, n)
			if at == 0:
				text = text.replace("{n}", n)
	return text

static func trigger_words(move: Dictionary, enemy: Dictionary = {}) -> String:
	var t: Dictionary = move.get("trigger", {"kind": "always"})
	if str(t.get("kind", "")) == "face":
		## How many faces of its dice carry it: what the pips show.
		var count: int = 0
		var total: int = 0
		for die in enemy.get("dice", []):
			total += die.get("faces", []).size()
			for face in die.get("faces", []):
				if str(face.get("move", "")) == str(move.get("name", "")):
					count += 1
		return ("%d of %d faces" % [count, total]) if total > 0 else "Its face"
	if str(t.get("kind", "")) == "match":
		var faces: Array = t.get("faces", [])
		if int(t.get("count", 0)) > 0 and not faces.is_empty():
			return "%d dice on %s · once/turn" % [int(t.count), str(faces[0])]
		return " and ".join(faces.map(func(f: Variant) -> String: return str(f))) + " together · once/turn"
	var n: int = DeepPatterns.rung(t, 0)
	var which: String = " · die %d" % (int(t.die) + 1) if t.has("die") else ""
	var once_only: String = " · once a fight" if bool(move.get("once", false)) else ""
	match str(t.get("kind", "always")):
		"always": return "Every roll" + which
		"odd": return "Odd roll" + which
		"even": return "Even roll" + which
		"at_least": return "Roll %d+" % n + which
		"at_most": return "Roll ≤%d" % n + which
		"value": return "Roll " + "/".join(t.get("values", []).map(func(v: Variant) -> String: return str(int(v)))) + which
		"crowns": return "Maximum face" + which
		"high_pct_at_least": return ("High roll · over half its die" if n == 51 else "Roll %d%%+ of its die" % n) + which
		"each_turn": return "Each action" + once_only
		"every_nth_turn": return "Every %s action" % DeepPatterns._ordinal(n) + once_only
		"countdown": return "Every %d, counting down" % n
		"emerge": return "When it comes up" + once_only
		"on_death": return "When it dies"
		"hp_below": return "Once, at %d%% health" % n
		"action_begin": return "As each action opens"
		"pair", "triple", "quad", "quint":
			var name: String = str({"pair": "Pair", "triple": "Three of a kind", "quad": "Four of a kind", "quint": "Five of a kind"}[str(t.kind)])
			return name + (" (%d+)" % n if n > 1 else "") + " · once/turn"
		"straight": return "%d-value sequence · once/turn" % n
		"all_odd": return "All odd · %d+ dice" % n
		"all_even": return "All even · %d+ dice" % n
	return DeepPatterns.words(t, 0).trim_suffix(".") + " · once/turn"

static func amount_words(expr: Variant) -> String:
	if expr is int or expr is float:
		return str(int(expr))
	if not expr is Dictionary:
		return "0"
	if expr.has("term"):
		return str({"rolled": "Rolled value", "value": "Matched value", "total": "Dice total", "high": "Highest value", "low": "Lowest value",
			"swell": "Its swelling", "held_gems": "Gems it holds", "biggest_hit": "Hardest hit on it this turn", "party_heaviest_carat": "Heaviest gem's carats",
			"party_best_turn": "The party's best turn", "party_richest": "Richest purse", "turns_acted": "Actions taken",
			"living_players": "Players standing", "max_hp": "Its most health", "hp": "Its health", "strength": "Its Strength"}.get(str(expr.term), str(expr.term)))
	if expr.has("const"):
		return str(int(expr.const ))
	var args: Array = expr.get("args", [])
	## A share of its own health for every so much of the richest purse (the Assayer's Eat the Rich).
	if _share_of_purse(expr):
		return "1%%/%s pyrite" % amount_words(args[1].args[1])
	if str(expr.get("op", "")) == "floor_div" and args.size() == 2 and (args[1] is int or args[1] is float):
		return "%s ÷ %d" % [_grouped_words(args[0]), int(args[1])]
	var parts: Array = args.map(func(a: Variant) -> String: return amount_words(a))
	if str(expr.get("op", "")) == "pct" and parts.size() == 2 and (expr.args[1] is int or expr.args[1] is float):
		return "%s × %s" % [_grouped_words(args[0]), ("%.2f" % (float(expr.args[1]) / 100.0)).rstrip("0").rstrip(".")]
	if str(expr.get("op", "")) == "*":
		parts = args.map(func(a: Variant) -> String: return _grouped_words(a))
	return (" %s " % str(expr.get("op", "+"))).join(parts)

static func _grouped_words(expr: Variant) -> String:
	## A sum read inside a product, a share or a division is bracketed: (Rolled value + 1) ÷ 2.
	var words: String = amount_words(expr)
	if expr is Dictionary and not expr.has("term") and str(expr.get("op", "")) in ["+", "-"]:
		return "(%s)" % words
	return words

static func _share_of_purse(expr: Dictionary) -> bool:
	## pct(max_hp, floor_div(party_richest, N)): a hundredth of its health for every N pyrite.
	var args: Array = expr.get("args", [])
	if str(expr.get("op", "")) != "pct" or args.size() != 2 or not args[0] is Dictionary or str(args[0].get("term", "")) != "max_hp":
		return false
	if not args[1] is Dictionary or str(args[1].get("op", "")) != "floor_div" or args[1].get("args", []).size() != 2:
		return false
	return args[1].args[0] is Dictionary and str(args[1].args[0].get("term", "")) == "party_richest"

static func amount_parts(expr: Variant) -> Dictionary:
	## An amount the creature's bonuses were stacked on, taken apart for the screen: the plain
	## number it started as, then each bonus in the order it applies, {op: "pct" | "+", value}.
	## A formula that is not that shape (a die's value, a sum of two terms) is {}, and is read
	## out in words instead.
	if not expr is Dictionary or not expr.has("op"):
		return {}
	var args: Array = expr.get("args", [])
	var op: String = str(expr.op)
	if args.size() != 2 or not op in ["pct", "+"]:
		return {}
	if not (args[1] is int or args[1] is float):
		return {}
	var inner: Variant = args[0]
	var parts: Dictionary = amount_parts(inner)
	if parts.is_empty():
		parts = {"base": amount_words(inner), "mods": []}
		if inner is Dictionary and not inner.has("term") and not inner.has("const"):
			return {}
	parts.mods.append({"op": op, "value": int(args[1])})
	return parts

const TARGET_WORDS: Dictionary = {"heroes": "all players", "hero": "all players", "self": "itself", "allies": "every creature", "allies_other": "every other creature",
	"hero_least_block": "the player with the least block", "hero_most_hp": "the player with the most health", "hero_most_gold": "the richest player",
	"hero_top_damage": "whoever hurt it most this turn", "hero_top_dealt": "whoever dealt the most last turn", "hero_marked": "every Marked player",
	"hero_rerolled": "every player who rerolled this turn",
	"spread": "spread round the party"}

static func target_words(effect: Dictionary, fallback: String = "all players") -> String:
	return str(TARGET_WORDS.get(str(effect.get("target", "heroes")), fallback))

static func _weight_words(effect: Dictionary) -> String:
	## A creature's Poison or Burn in a deeper mine: every round of it hurts with its blows' weight.
	if int(effect.get("weight", 100)) == 100:
		return ""
	return " · every round hurts ×%s here" % ("%.2f" % (float(effect.weight) / 100.0)).rstrip("0").rstrip(".")

static func _dice_words(n: int) -> String:
	return "%d %s" % [n, "die" if n == 1 else "dice"]

static func effect_words(effect: Dictionary) -> String:
	var n: String = amount_words(effect.get("amount", 0))
	var who: String = target_words(effect)
	var summoned: String = str(DeepContent.creature(str(effect.get("creature", ""))).get("name", "creature"))
	match str(effect.get("kind", "")):
		"damage":
			var words: String = "%s damage · %s" % [n, who]
			if effect.has("repeat") and not (effect.repeat is int and int(effect.repeat) == 1):
				words = "%s damage, %s times · %s" % [n, amount_words(effect.repeat).to_lower() if effect.repeat is Dictionary else str(effect.repeat), who]
			if bool(effect.get("flat", false)):
				words += " · plus its Strength, nothing more"
			if bool(effect.get("split_party", false)):
				words = "%s damage, split across the party (rounded up)" % n
			if bool(effect.get("piercing", false)):
				words += " · ignores block"
			return words
		"heal":
			if effect.get("amount", 0) is Dictionary and _share_of_purse(effect.amount):
				return "Heals 1%% of its most health for every %s pyrite the richest player holds" % amount_words(effect.amount.args[1].args[1])
			return "Heal %s · %s" % [n, who] if str(effect.get("target", "self")) != "self" else "Heal %s" % n
		"summon": return "%s joins the fight" % summoned if str(n) == "1" else "%s %ss join the fight" % [n, summoned]
		"purge": return "Sheds %s%% of its poison" % n
		"burrow": return "Burrows · cannot be targeted until its next action"
		"absorb_color":
			var chosen: String = "the color the party uses most" if str(effect.get("color", "random")) == "most_used" else "a color"
			return ("Drinks %s as well" if bool(effect.get("add", false)) else "Drinks %s") % chosen + " · those gems do it no damage, and what they would give their owner goes to it"
		"reflect": return "Until its next action, %s%% of every blow on it goes back to every player" % n
		"mirror": return "The next blow on it hits whoever threw it instead" if str(n) == "1" else "The next %s blows on it hit whoever threw them instead" % n
		"festering": return "%s Festering · healing halved · all players" % n
		"scorched": return "%s Scorched · block gained halved · all players" % n
		"burn": return "%s Burn · hurts at the end of each turn, block soaks it, one less each turn · all players" % n + _weight_words(effect)
		"strength": return ("%s Strength · %s more on every blow, for the fight" % [n, n]) + ("" if str(effect.get("target", "self")) == "self" else " · " + who.replace("all players", "every creature"))
		"blank_face": return "The face one of your dice shows is blank for the rest of the fight · all players"
		"roll_again": return "Throws this die once more"
		"end_action": return "Its action ends here"
		"exhibit": return "Fires every gem it holds, as its own"
		"die_lock":
			var pick: String = str(effect.get("pick", "random"))
			var what: String = "highest die" if pick == "high" else ("lowest die" if pick == "low" else _dice_words(int(effect.get("amount", 1))))
			return "Locks your %s · it comes up the same and cannot be rerolled next turn · all players" % what
		"steal_gold":
			## One player picked (the Magpie robs the richest), or every player (the Assayer's Tax).
			var picked: bool = str(effect.get("target", "heroes")) in DeepRules.HERO_PICKS
			var taken: String = ("Takes %s%% of each player's pyrite" % n) if bool(effect.get("pct", false)) else ("Takes %s pyrite from each player" % n)
			if picked:
				taken = ("Takes %s%% of the pyrite of %s" % [n, who]) if bool(effect.get("pct", false)) else ("Takes %s pyrite from %s" % [n, who])
			return taken + ((" · and hits them for what it took" if picked else " · and hits each for what it took") if bool(effect.get("hurt", false)) else "")
		"gold": return "Drops %s pyrite · %s" % [n, who] if str(effect.get("target", "heroes")) != "self" else "Gains %s pyrite" % n
		"empower_next": return "Its next attack deals %s%% more" % n
		"rally": return "Every creature deals %s more this turn" % n
		"grow_die": return "Grows another head: +1 %s (%s at most)" % [str(effect.get("shape", "D6")).to_lower(), str(effect.get("cap", 5))]
		"swell": return "Swells by %s · its burst grows" % n
		"hold_gem": return "Takes %s off a rail until it dies" % {"hardest": "the gem that hit it hardest this turn", "usable": "the finest gem it can fire itself"}.get(str(effect.get("pick", "hardest")), "the party's highest-grade gem")
		"bury_socket": return "Buries the socket holding your heaviest gem · all players"
		"charge":
			var turns: int = int(effect.get("turns", 2))
			var words: String = "Charges for %d %s, then: " % [turns, "action" if turns == 1 else "actions"]
			if bool(effect.get("store", false)):
				words += "all the damage it was dealt meanwhile, back at every player"
			else:
				words += " and ".join(effect.get("release", []).map(func(e: Dictionary) -> String: return effect_words(e)))
			if int(effect.get("guard_pct", 0)) > 0:
				words += " · takes %d%% less meanwhile" % int(effect.guard_pct)
			if int(effect.get("cancel_pct", 0)) > 0:
				words += " · losing %d%% of its health meanwhile cancels it" % int(effect.cancel_pct)
			return words
		"stun": return "Stun %s · %s turn" % [who, n] if str(effect.get("target", "heroes")) != "self" else "Stuns itself · %s turn" % n
		"downgrade_die": return "%s a size for the fight · all players" % {"high": "Your highest die shrinks", "all": "Every one of your dice shrinks"}.get(str(effect.get("pick", "random")), "One of your dice shrinks")
		"grind_die":
			if str(effect.get("pick", "random")) == "showing":
				return "Every face your dice show loses 1%s · all players" % (", for good" if bool(effect.get("permanent", false)) else " for the fight")
			return "Your %s loses 1 from its top face%s · all players" % ["highest die" if str(effect.get("pick", "random")) == "high" else "die", " for good" if bool(effect.get("permanent", false)) else " for the fight"]
		"break_gem": return "Melts one of your gems%s · all players" % (" for the rest of the fight" if bool(effect.get("permanent", false)) else " until next turn")
		"break_die": return "Destroys one of your dice%s · all players" % (" for the rest of the fight" if bool(effect.get("permanent", false)) else " until next turn")
		"lock_die": return "Locks one of your dice this turn · all players"
		"block": return "Gain %s block" % n
		"heal": return "Heal %s" % n
		"die_steal": return "Suppress %s die · all players · next turn" % n
		"poison": return "%s poison · all players" % n + _weight_words(effect)
		"stun": return "Stun all players · %s turn" % n
		"remove_block": return "Removes all your block · all players" if bool(effect.get("remove_all", false)) else "Remove %s block · all players" % n
		"curse": return "%s Curse · −10%% dealt / +10%% taken per stack (max 10) · all players" % n
		"clouded": return "Cloud a socket · all players" if str(effect.get("target", "heroes")) in ["hero", "heroes"] else "Clouded for %s actions · one random ability disabled" % n
		"marked": return "%s Marked · next hit +25%% per stack" % n + ("" if str(effect.get("target", "heroes")) in ["hero", "heroes"] else " · " + who)
		"dulled": return "%s Dulled · gems lose one Cut step per stack" % n
		"ward": return "%s Ward · blocks debuff applications (max 99)" % n
		"retain": return "Keeps all its block into its next turn" if bool(effect.get("keep_all", false)) else "Retain up to %s block at the next reset" % n
		"copy_hand": return "Throws copies of the %s highest dice of whoever rolled the most, showing the same faces" % n
		"grip_die": return "Holds your best die in its claw · it sits out every throw until this creature loses health · all players"
		"lose_die": return "Loses a head · one die fewer"
		"hasten": return "Its countdown comes %s %s sooner" % [n, "action" if str(n) == "1" else "actions"]
		"swap_gems": return "Two neighbouring gems on your rail change places for the fight · all players"
		"charged": return "%s Charged · starting Resonance next turn" % n
		"regeneration": return "%s Regeneration · heal at turn end, then lose one stack" % n
		"spikes": return "%s Spikes · retaliate once per attacking ability" % n
		"dice_dread": return "%s Dread · dice lose one tier per stack" % n if str(effect.get("target", "")) in ["", "enemy", "enemies", "self"] else "%s Dread · your dice roll a size smaller next turn · all players" % n
		"dice_upgrade": return "Dice +%s tier · this fight" % n + (" (%s at most)" % str(effect.cap).to_lower() if effect.has("cap") else "")
		"max_hp":
			if effect.get("amount", 0) is Dictionary and _share_of_purse(effect.amount):
				return "Grows by 1%% of its most health for every %s pyrite the richest player holds" % amount_words(effect.amount.args[1].args[1])
			return "Gains %s most health, and that much health" % n
		"cleanse": return "Sheds every affliction on it" if int(effect.get("amount", 0)) >= 99 else "Sheds %s afflictions" % n
		"etch":
			var how_many: String = "Every %s face" % str(effect.get("from", "")) if int(effect.get("count", 1)) == 0 else "One of its %s faces" % str(effect.get("from", ""))
			if str(effect.get("from", "")) == "self_face":
				how_many = "This face"
			return "%s becomes %s" % [how_many, str(effect.get("to", ""))]
		"grow_faces": return "Its die grows a size, its new faces %s" % " and ".join(effect.get("faces", []).map(func(f: Variant) -> String: return str(f)))
		"pin_trait": return "Until its next action: %s" % str(effect.get("trait", "")).replace("_", " ")
		"fog": return "Clouds a socket on your rail until you hit it"
		"flee": return "Leaves the fight with everything it took"
		"morph": return "Becomes another creature, at full health"
		"cling": return "Clings to your finest gem: it fires at you until you hit this creature"
		"blank_next": return "A die you rerolled this turn is blank on your next turn"
	return str(effect.get("kind", "")).capitalize() + " " + n
