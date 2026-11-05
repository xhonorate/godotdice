extends RefCounted
## One look per meaning for everything a creature's move does (the creature animation pass of
## November 3, 2026, build/rework/ANIM2_BRIEF.md): what it casts as it begins the move, and how
## each effect lands, tinted by the move's kind colour (creature_look.gd FACE: attack red, guard
## blue, meddle violet, mend green, ready gold, dud grey) so a reader learns one look a meaning:
##
##   guard    plates flying in and locking into a crystal shell round it (BattleFx.shell)
##   mend     motes spiralling up round whoever it mends (BattleFx.helix)
##   buff     a ring at its feet and a column of light rising through it (BattleFx.aura)
##   debuff   a hexagon lit at the creature and thrown at the dock, landing as its own mark
##            (stars for a stun, fog for fog, rubble for a burial, a lock for a lock...)
##   steal    what it takes pulled out of the dock and flying back to it
##   summon   a crack in the floor the newcomer climbs out of (BattleFx.crack, at the spawn)
##   dud      a stagger and a grey puff (BattleFx.stagger)
##
## battle_screen.gd calls `windup` as a creature starts acting a move out (`_enemy_windup`) and
## `land_all` as its effects land (`_enemy_move`). Kinds with a look of their own there (Burn's
## flames, Poison's bubbles, Marked's reticle, a curse's sigil, a mirror's barrier) keep it and
## only get the cast. A rig adds its own flourish in its moves' `fx` gestures (the shared names
## `shell`, `aura`, `helix`, `hex`, `crack` in creature_moves.gd `_fire` are this vocabulary).

const Look = preload("res://view/battle/creature_look.gd")

## What each effect kind a creature's move carries means, as it is drawn. "by_move" kinds are
## something a creature takes on itself whose meaning is the move's: a trait pinned on a meddle
## move works against the party, on a guard move it shields the creature.
const MEANING: Dictionary = {
	"damage": "attack",
	"block": "guard", "retain": "guard", "spikes": "guard", "ward": "guard", "reflect": "guard", "mirror": "guard",
	"absorb_color": "guard", "burrow": "hide", "charge": "charge",
	"heal": "mend", "max_hp": "mend", "cleanse": "mend", "purge": "mend", "regeneration": "mend", "lifeline": "mend",
	"strength": "buff", "empower_next": "buff", "rally": "buff", "grow_die": "buff", "grow_faces": "buff", "roll_again": "buff",
	"swell": "buff", "etch": "buff",
	"pin_trait": "by_move", "exhibit": "by_move",
	"summon": "summon", "morph": "morph", "flee": "flee",
	"end_action": "dud", "gold": "dud",
	"curse": "debuff", "dulled": "debuff", "marked": "debuff", "stun": "debuff", "fog": "debuff", "clouded": "debuff",
	"bury_socket": "debuff", "cling": "debuff", "poison": "debuff", "poison_tick": "debuff", "festering": "debuff",
	"burn": "debuff", "scorched": "debuff", "remove_block": "debuff", "dice_dread": "debuff", "die_lock": "debuff",
	"lock_die": "debuff", "grip_die": "debuff", "downgrade_die": "debuff", "grind_die": "debuff", "mar_die": "debuff",
	"break_die": "debuff", "blank_face": "debuff", "blank_next": "debuff", "break_gem": "debuff", "swap_gems": "debuff",
	"die_steal": "steal", "hold_gem": "steal", "steal_gold": "steal",
}
const BY_MOVE: Dictionary = {"meddle": "debuff", "guard": "guard", "mend": "mend", "ready": "buff", "attack": "buff", "dud": "dud"}

## How each debuff lands at the dock: its own mark. "own" kinds have one already in
## battle_screen.gd `_creature_fx` (and are thrown at all the same).
const MARKS: Dictionary = {
	"curse": "own", "marked": "own", "poison": "own", "poison_tick": "own", "festering": "own", "burn": "own",
	"scorched": "own", "remove_block": "own", "grip_die": "own", "swap_gems": "own",
	"stun": "stars", "dulled": "dim", "fog": "fog", "clouded": "fog", "bury_socket": "rubble", "cling": "leech",
	"die_lock": "lock", "lock_die": "lock", "dice_dread": "dread", "downgrade_die": "shrink", "grind_die": "grind",
	"mar_die": "grind", "break_die": "break", "break_gem": "break", "blank_face": "blank", "blank_next": "blank",
	"pin_trait": "dim",
}
## Debuffs that bring their own projectile: no hex is thrown with them.
const OWN_THROW: Array = ["burn"]
## Effects that land on the creature itself, or its side.
const OWN_SIDE: Array = ["self", "allies", "allies_other", "escort_leader"]

static func meaning(kind: String, move_kind: String) -> String:
	var said: String = str(MEANING.get(kind, ""))
	if said == "by_move":
		return str(BY_MOVE.get(move_kind, "buff"))
	if said.is_empty():
		return str(BY_MOVE.get(move_kind, "buff"))
	return said

static func tint(move_kind: String) -> Color:
	return Look.FACE.get(move_kind, Look.FACE.meddle)

static func has_look(kind: String, move_kind: String = "meddle") -> bool:
	## Whether this effect kind has a look of its own in the vocabulary (the test of every kind
	## creature content uses).
	var said: String = meaning(kind, move_kind)
	if said == "debuff":
		return MARKS.has(kind) or str(MEANING.get(kind, "")) == "by_move"
	return said in ["attack", "guard", "mend", "buff", "steal", "summon", "dud", "hide", "charge", "morph", "flee"]

static func _from(creature: Node3D) -> Vector3:
	## Where a creature's cast leaves from: its mouth where its rig names one, its middle else.
	var moves: Node = creature.get("_moves")
	if moves != null and moves.has_method("point"):
		return moves.call("point", "mouth")
	return creature.call("centre")

static func windup(fx: Node, event: Dictionary, creature: Node3D, dock: Vector3, lead: float) -> void:
	## As a creature begins acting a move out: it gathers its move's colour about it, and a
	## debuff aimed at the party is lit as a hexagon at it and thrown, reaching the dock as the
	## move lands (`lead` from now). A plain attack casts nothing: its own gestures say it.
	if fx == null or creature == null:
		return
	var move_kind: String = str(event.get("move_kind", ""))
	var color: Color = tint(move_kind)
	var throws: bool = false
	var gathers: bool = false
	for effect in event.get("effects", []):
		var kind: String = str(effect.get("kind", ""))
		var said: String = meaning(kind, move_kind)
		match said:
			"debuff":
				if not kind in OWN_THROW:
					throws = true
			"steal":
				gathers = true
			"guard", "mend", "buff", "summon", "charge":
				gathers = true
	var held: WeakRef = weakref(creature)
	if gathers:
		var gather: Tween = fx.create_tween()
		gather.tween_interval(maxf(0.0, lead - 0.42))
		gather.tween_callback(func() -> void:
			var who: Node3D = held.get_ref() as Node3D
			if who != null and is_instance_valid(who) and who.is_inside_tree():
				fx.call("spiral_in", who.call("centre"), color.lightened(0.2), 1.0 * who.scale.x, 26, 0.5))
	if throws:
		var flight: float = clampf(lead - 0.08, 0.18, 0.3)
		var throw: Tween = fx.create_tween()
		throw.tween_interval(maxf(0.0, lead - flight - 0.1))
		throw.tween_callback(func() -> void:
			var who: Node3D = held.get_ref() as Node3D
			if who != null and is_instance_valid(who) and who.is_inside_tree():
				fx.call("hex_flare", _from(who), color, 0.55 * who.scale.x, 0.4))
		throw.tween_interval(0.1)
		throw.tween_callback(func() -> void:
			var who: Node3D = held.get_ref() as Node3D
			if who != null and is_instance_valid(who) and who.is_inside_tree():
				fx.call("hex_bolt", _from(who), dock, color, flight, Callable(), 0.24, 0.3))

static func land_all(fx: Node, event: Dictionary, creature: Node3D, find: Callable, local_id: String, dock: Vector3, facing: Vector3) -> void:
	## As a creature's move lands: each meaning's look once where it lands (a shell on the
	## creature that guards, motes round each creature it mends, a mark at the dock for each
	## debuff that reached the reader). `find` turns a unit id into its creature, or null.
	if fx == null:
		return
	var move_kind: String = str(event.get("move_kind", ""))
	var color: Color = tint(move_kind)
	var done: Dictionary = {}
	var alive: bool = creature != null and is_instance_valid(creature) and creature.is_inside_tree()
	if move_kind == "dud" and alive:
		fx.call("stagger", creature.call("centre"), color, creature.scale.x)
		done["dud"] = true
	for effect in event.get("effects", []):
		if bool(effect.get("warded", false)) or bool(effect.get("immune", false)) or bool(effect.get("resisted", false)) or bool(effect.get("nothing", false)):
			continue
		var kind: String = str(effect.get("kind", ""))
		var said: String = meaning(kind, move_kind)
		var target: String = str(effect.get("target", ""))
		var receiver: Node3D = find.call(target) if not target.is_empty() else null
		if receiver == null and alive and (target.is_empty() or target in OWN_SIDE or said in ["guard", "buff", "mend", "dud"]):
			receiver = creature
		var key: String = said + ":" + (str(receiver.get_instance_id()) if receiver != null else target)
		if done.has(key):
			continue
		match said:
			"guard":
				if receiver != null and not kind in ["reflect", "mirror", "absorb_color"]:
					done[key] = true
					fx.call("shell", receiver.call("centre"), color, maxf(0.5, float((receiver.get("anchor") as Vector3).y) * 0.32), 0.75, kind != "block")
					if kind == "spikes":
						fx.call("shards", receiver.call("centre"), color.lightened(0.3), 8, 3.0, 0.07, 0.7)
			"mend":
				if receiver != null:
					done[key] = true
					fx.call("helix", receiver.global_position, color, maxf(0.8, (receiver.get("anchor") as Vector3).y), 1.0, 0.45 * receiver.scale.x)
			"buff":
				if receiver != null:
					done[key] = true
					fx.call("aura", receiver.global_position, color, maxf(0.8, (receiver.get("anchor") as Vector3).y), 0.9)
			"dud":
				if receiver != null and not done.has("dud"):
					done["dud"] = true
					fx.call("stagger", receiver.call("centre"), Look.FACE.dud, receiver.scale.x)
			"steal":
				var victim: String = str(effect.get("held", {}).get("unit", target)) if effect.get("held", {}) is Dictionary else target
				if victim == local_id and alive and kind != "steal_gold":
					done[key] = true
					fx.call("spiral_in", dock, color, 0.5, 16, 0.5)
					fx.call("projectile", dock, _from(creature), color, 0.4, 0.1, Callable(), 0.6, 2.0)
			"debuff":
				## Hexed at the reader, or a trait it took on that works against the party.
				if target == local_id or (alive and receiver == creature and str(MEANING.get(kind, "")) == "by_move"):
					var mark: String = str(MARKS.get(kind, "dim"))
					if mark != "own" and not done.has("mark:" + mark):
						done["mark:" + mark] = true
						land_mark(fx, mark, dock, facing, color)

static func land_mark(fx: Node, mark: String, at: Vector3, facing: Vector3, color: Color) -> void:
	## A debuff's own mark where it lands at the dock (`at`, a way out from the lens).
	match mark:
		"stars":
			fx.call("stars", at + Vector3(0, 0.3, 0), Color("ffe27a"), 1.2, 0.45)
		"fog":
			fx.call("puff", at, Color("b8c8e0"), 10, 0.45, 1.4, 0.12)
		"rubble":
			fx.call("shards", at + Vector3(0, 0.6, 0), Color("8a7a66"), 7, 1.2, 0.06, 0.9)
			fx.call("puff", at + Vector3(0, -0.3, 0), Color(0.45, 0.4, 0.34), 8, 0.4, 1.1, 0.3)
		"leech":
			fx.call("spiral_in", at, Color("ff9ad8"), 0.6, 18, 0.6)
			fx.call("hex_flare", at, Color("ff9ad8"), 0.55, 0.45)
		"lock":
			fx.call("hex_flare", at, Color("9fd8ff"), 0.6, 0.5)
			fx.call("sparks", at, Color("9fd8ff"), 12, 1.5, 0.5, 0.04)
		"dread":
			fx.call("ripple", at, facing, Color("5a3a8a"), 1.0, 0.6)
			fx.call("hex_flare", at, color, 0.6, 0.5)
		"shrink":
			fx.call("hex_flare", at, color, 0.6, 0.45)
			fx.call("shards", at, color.lightened(0.2), 6, 1.5, 0.05, 0.6)
		"grind":
			fx.call("hex_flare", at, color, 0.5, 0.4)
			fx.call("sparks", at, Color("ffd08a"), 18, 2.5, 0.5, 0.04)
		"break":
			fx.call("hex_flare", at, color, 0.6, 0.45)
			fx.call("shards", at, color.lightened(0.25), 10, 2.5, 0.07, 0.8)
		"blank":
			fx.call("hex_flare", at, Color("f4f0ff"), 0.6, 0.5)
			fx.call("puff", at, Color("3a3230"), 6, 0.35, 1.0, 0.3)
		_:
			fx.call("hex_flare", at, color, 0.65, 0.5)
			fx.call("puff", at, color.darkened(0.3), 6, 0.35, 1.0, 0.2)
