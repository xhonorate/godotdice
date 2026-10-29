extends SceneTree
## Creatures as action dice (docs/CREATURE_DICE.md): every face of every creature's dice does
## what its move says when it lands, and the new mechanics hold (re-etching, growing dice,
## matches, pinned traits, fog, rubble, clinging, unravelling, echoes, per-reroll prices).
var checks: int = 0
var failures: Array = []

func _init() -> void:
	content_is_action_dice()
	every_face_lands()
	etching()
	magpie_snatch_and_flee()
	lanterns()
	thorns_and_kept_block()
	fog_and_rubble()
	growing_dice()
	matches()
	echoes()
	clinging()
	acid_armour()
	paradox_moth()
	mirrors()
	gathered_light()
	called_moves()
	print("Creature dice: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

# --- fixtures ----------------------------------------------------------------------------

func stone(skill: String, id: String) -> Dictionary:
	return DeepStone.make(skill, 1, 4, 3, [], {}, id)

func setup(keys: Array, players: int = 2) -> Dictionary:
	var party: Array = []
	for i in range(players):
		var bowl: Array = []
		for j in range(5):
			bowl.append(DeepDice.make("D6", "p%d_d%d" % [i, j]))
		var rail: Array = [stone("STRIKE", "p%d_s0" % i), stone("STRIKE", "p%d_s1" % i), stone("STRIKE", "p%d_s2" % i)]
		var unit: Dictionary = DeepBattle.make_player("p%d" % i, "Player %d" % i, "ARDOR", rail, bowl)
		unit.birthstone = {}
		unit.passive = {}
		unit.hp = 1000
		unit.max_hp = 1000
		unit.gold = 300
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(271, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin(party, keys, {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.max_hp = maxi(int(foe.max_hp), 2000)
		foe.hp = int(foe.max_hp)
		foe.hp_at_turn = int(foe.hp)
	var leads: Array = state.enemies.filter(func(e: Dictionary) -> bool: return str(e.get("escort_of", "")).is_empty())
	return {"state": state, "rng": rng, "foe": leads[0] if not leads.is_empty() else state.enemies[0]}

func force(foe: Dictionary, at_die: int, move_name: String) -> void:
	## One die of the creature lands on this move every time: it is given a single face.
	var move: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), move_name)
	var die: Dictionary = DeepDice.make("D6", "%s_d%d" % [str(foe.id), at_die], {"faces": [DeepDice.face(1)]})
	DeepCreatures.dress_face(die.faces[0], move)
	while foe.dice.size() <= at_die:
		foe.dice.append(die.duplicate(true))
	foe.dice[at_die] = die

func force_faces(foe: Dictionary, at_die: int, move_name: String, keep: Array = []) -> void:
	## Every face of one of its real dice carries this move, but for the faces whose moves
	## are in `keep` (the faces a re-etching works on).
	var move: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), move_name)
	for face in foe.dice[at_die].faces:
		if not keep.has(str(face.get("move", ""))):
			DeepCreatures.dress_face(face, move)

func reroll_all(f: Dictionary) -> void:
	for unit in f.state.players:
		DeepBattle.command(f.state, str(unit.id), {"kind": "reroll", "dice": unit.hand.map(func(r: Dictionary) -> String: return str(r.die_id))}, f.rng.dice)

func turn(f: Dictionary) -> Array:
	var out: Array = []
	DeepBattle.force_lock(f.state)
	out.append(DeepBattle.start_resolution(f.state))
	while DeepBattle.has_steps(f.state) and out.size() < 400:
		out.append(DeepBattle.step(f.state, f.rng.dice, f.rng.creatures))
	return out

func moves_named(all: Array, name: String) -> Array:
	return all.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_move" and str(e.get("move", "")) == name)

func die_of(foe: Dictionary, move_name: String) -> int:
	for d in range(foe.dice.size()):
		for face in foe.dice[d].get("faces", []):
			if str(face.get("move", "")) == move_name:
				return d
	return 0

# --- the content -------------------------------------------------------------------------

func content_is_action_dice() -> void:
	for key in DeepContent.section("creatures"):
		var def: Dictionary = DeepContent.creature(str(key))
		check(not def.has("phases"), "%s has no health phases" % key)
		check(not def.get("dice", []).is_empty() and def.dice.size() <= 4, "%s has one to four dice" % key)
		var names: Array = def.moves.map(func(m: Dictionary) -> String: return str(m.name))
		for name in names:
			check(names.count(name) == 1, "%s has one move called %s" % [key, name])
		for die in def.get("dice", []):
			check(die is Dictionary and int(DeepDice.SHAPES[str(die.shape)]) == die.faces.size(), "%s %s lists a move for every face" % [key, str(die.get("shape", ""))])
			check(str(die.shape) in ["D3", "D4", "D6", "D8", "D12"], "%s throws no d10 or d20 (%s)" % [key, str(die.shape)])
			for face in die.faces:
				check(names.has(str(face)), "%s face %s is one of its moves" % [key, str(face)])
		for move in def.moves:
			check(str(move.get("kind", "")) in DeepCreatures.MOVE_KINDS, "%s %s has a move kind" % [key, str(move.name)])
			check(not str(move.get("mark", "")).is_empty(), "%s %s has a mark" % [key, str(move.name)])
			check(not str(move.get("text", "")).is_empty(), "%s %s has its words" % [key, str(move.name)])
			check(not str(move.get("text", "")).contains("every player"), "%s %s does not say every player" % [key, str(move.name)])
		## A made creature's dice carry the moves on their faces.
		var made: Dictionary = DeepCreatures.make(str(key), "x", 1, 1, {}, RandomNumberGenerator.new())
		for die in made.dice:
			check(DeepCreatures.is_face_die(die), "%s's dice are action dice" % key)
			for face in die.faces:
				check(face.has("mark") and face.has("move_kind"), "%s faces carry a mark and a kind" % key)
		check(not DeepCreatures.face_share(made).is_empty(), "%s shares its faces out" % key)
		for move in DeepCreatures.moves_for(made):
			var words: String = DeepCreatures.move_text(made, move)
			check(not words.contains("{"), "%s %s reads with its numbers in: %s" % [key, str(move.name), words])

# --- every face does something ------------------------------------------------------------

const ACTS: Array = ["damage", "block", "heal", "poison", "burn", "curse", "dulled", "festering", "marked", "stun", "strength", "spikes",
	"summon", "steal_gold", "etch", "grow_die", "grow_faces", "pin_trait", "fog", "flee", "morph", "cling", "blank_next", "burrow", "reflect", "mirror",
	"absorb_color", "die_steal", "grip_die", "die_lock", "dice_dread", "downgrade_die", "grind_die", "break_die", "break_gem", "blank_face", "bury_socket",
	"swap_gems", "hold_gem", "remove_block", "swell", "max_hp", "retain", "empower_next", "end_action", "gold", "poison_tick", "charge", "roll_again", "cleanse", "purge"]

func every_face_lands() -> void:
	for key in DeepContent.section("creatures"):
		var def: Dictionary = DeepContent.creature(str(key))
		for move in def.moves:
			if str(move.get("trigger", {}).get("kind", "")) != "face" or str(move.get("kind", "")) == "dud":
				continue
			## A Void Echo's own Echo is never thrown: it throws the dice of what it copies.
			if str(key) == "VOID_ECHO" and str(move.name) == "Echo":
				continue
			_one_face(str(key), def, move)

func _one_face(key: String, def: Dictionary, move: Dictionary) -> void:
	## The leader of an escort is set up for its escorts' faces (a Tendril knits its Heartrot).
	var lead: String = key
	if key == "TENDRIL":
		lead = "THE_HEARTROT"
	elif key == "PRISM":
		lead = "THE_PRISMARCH"
	var f: Dictionary = setup([lead])
	var foe: Dictionary = f.foe
	if lead != key:
		foe = f.state.enemies.filter(func(e: Dictionary) -> bool: return str(e.key) == key)[0]
	var name: String = str(move.name)
	var kinds: Array = move.effects.map(func(e: Dictionary) -> String: return str(e.kind))
	var at: int = die_of(foe, name)
	## Every other die lands on it too, unless its faces are what this move works on (a
	## re-etching keeps the faces it turns, wherever they are).
	var keep: Array = []
	for effect in move.effects:
		if str(effect.kind) == "etch":
			keep.append(str(effect.get("from", "")))
	if keep.is_empty():
		for d in range(foe.dice.size()):
			force(foe, d, name)
	else:
		force(foe, foe.dice.size(), name)
	## Room for what it calls: one of its escorts has fallen.
	if kinds.has("summon"):
		for escort in f.state.enemies:
			if str(escort.get("escort_of", "")) == str(foe.id) and escort != foe:
				escort.hp = 0
				break
	## What the party has for it to work on: rerolls used, poison to bite, gems that hit it.
	reroll_all(f)
	for unit in f.state.players:
		unit.statuses.poison = 3
		unit.block = 20
	if kinds.has("hold_gem") and key == "HOARD_MIMIC":
		foe.hardest_gem = {"unit": "p0", "socket": 0, "stone_id": "p0_s0"}
	var all: Array = turn(f)
	var fired: Array = moves_named(all, name)
	check(not fired.is_empty(), "%s %s fires when its face lands" % [key, name])
	if fired.is_empty():
		return
	var results: Array = fired[0].get("effects", [])
	for kind in kinds:
		if not kind in ACTS:
			continue
		var acted: Array = results.filter(func(r: Dictionary) -> bool: return str(r.get("kind", "")) == kind and not bool(r.get("nothing", false)))
		## A stun the party resisted, or a socket a ward turned away, still landed as a move.
		check(not acted.is_empty() or results.any(func(r: Dictionary) -> bool: return bool(r.get("warded", false)) or bool(r.get("resisted", false))),
			"%s %s does its %s: %s" % [key, name, kind, JSON.stringify(results).left(300)])

# --- the mechanics -------------------------------------------------------------------------

func etching() -> void:
	var f: Dictionary = setup(["THE_FOREMAN"])
	var foe: Dictionary = f.foe
	var picks_before: int = _faces(foe, "Pick")
	force(foe, 0, "Reinforce")
	var all: Array = turn(f)
	var etched: Array = moves_named(all, "Reinforce")[0].effects[0].get("etched", [])
	check(etched.size() == 1 and str(etched[0].to) == "Blast", "Reinforce etches one Pick face into Blast")
	check(_faces(foe, "Pick") == picks_before - 1 and _faces(foe, "Blast") == 1, "the pick die now carries one Blast")
	## The etched face fires as Blast when it lands.
	var g: Dictionary = setup(["THE_FOREMAN"])
	DeepCreatures.etch(g.foe, "Pick", "Blast", 0)
	force(g.foe, 0, "Shore Up")
	force_faces(g.foe, 1, "Blast")
	var blasts: Array = moves_named(turn(g), "Blast")
	check(not blasts.is_empty() and blasts[0].effects.filter(func(r: Dictionary) -> bool: return str(r.kind) == "damage").size() == 3 * g.state.players.size(), "Blast hits three times a player")
	## Raise the Rate turns every Tax face to Heavy Tax.
	var h: Dictionary = setup(["THE_ASSAYER"])
	var taxes: int = _faces(h.foe, "Tax")
	force(h.foe, 0, "Weigh")
	DeepBattle._apply(h.state, h.foe, {"kind": "etch", "target": "self", "amount": 1, "from": "Tax", "to": "Heavy Tax", "count": 0}, h.rng.creatures)
	check(_faces(h.foe, "Tax") == 0 and _faces(h.foe, "Heavy Tax") == taxes, "Raise the Rate turns every Tax face")

func _faces(foe: Dictionary, name: String) -> int:
	var n: int = 0
	for die in foe.dice:
		for face in die.faces:
			if str(face.get("move", "")) == name:
				n += 1
	return n

func magpie_snatch_and_flee() -> void:
	var f: Dictionary = setup(["MAGPIE"])
	var foe: Dictionary = f.foe
	var snatches: int = _faces(foe, "Snatch")
	var at: int = -1
	for face in range(foe.dice[0].faces.size()):
		if str(foe.dice[0].faces[face].move) == "Snatch":
			at = face
			break
	## Throw only that face: every other face of the die becomes it, then put the die back.
	var real: Dictionary = foe.dice[0].duplicate(true)
	foe.dice[0].faces = [foe.dice[0].faces[at]]
	var all: Array = turn(f)
	var snatch: Array = moves_named(all, "Snatch")
	check(not snatch.is_empty() and int(snatch[0].effects[0].get("stolen", 0)) == 10, "Snatch takes 10 pyrite from the richest player")
	check(str(foe.dice[0].faces[0].move) == "Flee", "the Snatch face it landed becomes Flee")
	real.faces[at] = foe.dice[0].faces[0]
	foe.dice[0] = real
	check(_faces(foe, "Snatch") == snatches - 1 and _faces(foe, "Flee") == 1, "one Snatch face fewer, one Flee face more")
	force(foe, 0, "Flee")
	var gone: Array = moves_named(turn(f), "Flee")
	check(not gone.is_empty() and bool(gone[0].effects[0].get("fled", false)) and int(foe.hp) <= 0 and bool(foe.get("fled", false)), "Flee leaves the fight")
	check(int(gone[0].effects[0].get("stolen", 0)) == 10, "and takes what it stole with it")

func lanterns() -> void:
	var f: Dictionary = setup(["LANTERN_MOTH"])
	force(f.foe, 0, "Lantern")
	var base: int = int(f.state.players[0].rerolls_max)
	turn(f)
	check(DeepCreatures.has_trait(f.foe, "gift_rerolls"), "Lantern holds its gift through the party's turn")
	check(int(f.state.players[0].rerolls_max) == base + 1, "the next turn has one more reroll (%d after %d)" % [int(f.state.players[0].rerolls_max), base])
	## A reroll costs nothing under its light.
	var hp: int = int(f.state.players[0].hp)
	DeepBattle.command(f.state, "p0", {"kind": "reroll", "dice": ["p0_d0"]}, f.rng.dice)
	check(int(f.state.players[0].hp) == hp, "its rerolls take no blood")
	force(f.foe, 0, "Flutter")
	var all: Array = turn(f)
	check(not DeepCreatures.has_trait(f.foe, "gift_rerolls"), "the gift wears off as its next action opens")
	## Singe: so much for every reroll used this turn.
	var g: Dictionary = setup(["LANTERN_MOTH"], 1)
	force(g.foe, 0, "Singe")
	DeepBattle.command(g.state, "p0", {"kind": "reroll", "dice": ["p0_d0"]}, g.rng.dice)
	DeepBattle.command(g.state, "p0", {"kind": "reroll", "dice": ["p0_d1"]}, g.rng.dice)
	var singe: Array = moves_named(turn(g), "Singe")
	check(not singe.is_empty() and int(singe[0].effects[0].get("rerolls", 0)) == 2 and int(singe[0].effects[0].raw) >= 6, "Singe burns 3 a reroll: two rerolls, %s" % (str(singe[0].effects[0].get("raw", "?")) if not singe.is_empty() else "none"))
	var h: Dictionary = setup(["LANTERN_MOTH"], 1)
	force(h.foe, 0, "Singe")
	var none: Array = moves_named(turn(h), "Singe")
	check(not none.is_empty() and bool(none[0].effects[0].get("nothing", false)), "Singe does nothing to a player who did not reroll")

func thorns_and_kept_block() -> void:
	var f: Dictionary = setup(["THE_GLAZIER"])
	force(f.foe, 0, "Anneal")
	force(f.foe, 1, "Slice")
	turn(f)
	check(int(f.foe.statuses.get("spikes", 0)) >= 3, "Anneal's thorns stand through the party's turn")
	force(f.foe, 0, "Pincers")
	var all: Array = turn(f)
	check(int(f.foe.statuses.get("spikes", 0)) == 0, "and come down as its next action opens")
	var g: Dictionary = setup(["QUARTZ_GOLEM"])
	force(g.foe, 0, "Fortify")
	turn(g)
	var kept: int = int(g.foe.block)
	check(kept > 0, "Fortify raises block")

func fog_and_rubble() -> void:
	var f: Dictionary = setup(["CLOUDER"], 1)
	force(f.foe, 0, "Fog")
	turn(f)
	var unit: Dictionary = f.state.players[0]
	check(unit.get("fog", []).size() == 1 and unit.clouded.size() == 1, "Fog clouds a socket on the rail, and it is there as the next turn opens")
	DeepBattle._damage(f.state, unit, f.foe, 5, f.rng.dice)
	check(unit.get("fog", []).is_empty(), "hitting the Clouder lifts its fog")
	var g: Dictionary = setup(["THE_FOREMAN"], 1)
	force(g.foe, 0, "Bury")
	turn(g)
	check(g.state.players[0].get("rubble", []).size() == 1, "Bury leaves rubble for the fight")
	force(g.foe, 0, "Shore Up")
	turn(g)
	check(g.state.players[0].buried.size() >= 1, "the rubble is still there the turn after")

func growing_dice() -> void:
	var f: Dictionary = setup(["CRYSTAL_HYDRA"])
	var heads: int = f.foe.dice.size()
	for d in range(heads):
		force(f.foe, d, "Bite")
	force(f.foe, 0, "Sprout")
	turn(f)
	check(f.foe.dice.size() == heads + 1 and DeepCreatures.is_face_die(f.foe.dice.back()), "Sprout grows another head, an action die like the first (%d heads after %d)" % [f.foe.dice.size(), heads])
	for _i in range(6):
		DeepBattle._apply(f.state, f.foe, {"kind": "grow_die", "target": "self", "amount": 1, "cap": 6, "template": 0}, f.rng.creatures)
	check(f.foe.dice.size() == 6, "six heads at most")
	var g: Dictionary = setup(["THE_HOLLOW_CROWN"])
	var was: String = str(g.foe.dice[0].shape)
	force_faces(g.foe, 0, "Rise")
	var faces_before: int = g.foe.dice[0].faces.size()
	turn(g)
	check(g.foe.dice[0].faces.size() == faces_before + 2 and _faces(g.foe, "Topple") == 1 and _faces(g.foe, "Summon") == 1, "Rise grows a Topple face and a Summon face")
	var crown: Dictionary = DeepCreatures.make("THE_HOLLOW_CROWN", "c", 1, 1)
	for _i in range(5):
		DeepCreatures.grow_faces(crown, 0, ["Topple", "Summon"])
	check(str(crown.dice[0].shape) == "D12" and crown.dice[0].faces.size() == 12, "the Crown's die stops at a d12")

func matches() -> void:
	var f: Dictionary = setup(["THE_DROWNED_CHOIR"])
	for d in range(f.foe.dice.size()):
		force(f.foe, d, "Requiem")
	var all: Array = turn(f)
	check(moves_named(all, "Requiem").size() == 3, "three heads sing Requiem")
	check(moves_named(all, "Requiem Chorus").size() == 1, "and the chorus answers once")
	var g: Dictionary = setup(["COLLAPSAR"])
	force(g.foe, 0, "Collapse")
	force(g.foe, 1, "Pull")
	check(moves_named(turn(g), "Singularity").is_empty(), "one Collapse alone is no Singularity")
	var h: Dictionary = setup(["THE_SPORE_MOTHER"])
	force(h.foe, 0, "Spore")
	force(h.foe, 1, "Rot")
	check(moves_named(turn(h), "Bloom").size() == 1, "Spore and Rot together bloom")

func echoes() -> void:
	var f: Dictionary = setup(["VOID_ECHO"])
	var foe: Dictionary = f.foe
	var was: String = str(foe.get("echo_of", ""))
	check(not was.is_empty(), "a Void Echo copies a creature")
	check(_faces(foe, "Echo Anew") >= 1, "and one of its faces is Echo Anew")
	force(foe, 0, "Echo Anew")
	var all: Array = turn(f)
	var anew: Array = moves_named(all, "Echo Anew")
	check(not anew.is_empty() and not str(foe.echo_of).is_empty() and str(foe.echo_of) != was, "Echo Anew turns it into another creature (%s to %s)" % [was, str(foe.get("echo_of", ""))])
	check(int(foe.hp) == int(foe.max_hp), "at that creature's full health")
	check(_faces(foe, "Echo Anew") >= 1, "still able to echo anew")

func clinging() -> void:
	var f: Dictionary = setup(["STAR_LEECH"], 1)
	force(f.foe, 0, "Cling")
	turn(f)
	var unit: Dictionary = f.state.players[0]
	check(unit.get("clung", null) is Dictionary, "Cling takes hold of a gem")
	unit.firing_stone = {"stone_id": str(unit.clung.stone_id), "socket": int(unit.clung.socket)}
	var hp: int = int(unit.hp)
	var hits: Array = DeepBattle._apply(f.state, unit, {"kind": "damage", "target": "enemy", "amount": 9}, f.rng.dice)
	unit.erase("firing_stone")
	check(not hits.is_empty() and str(hits[0].target) == str(unit.id), "the clung gem's blow lands on its owner")
	DeepBattle._damage(f.state, unit, f.foe, 5, f.rng.dice)
	check(not unit.has("clung"), "hitting the leech makes it let go")

func acid_armour() -> void:
	var f: Dictionary = setup(["SPORE_SLIME"], 1)
	var unit: Dictionary = f.state.players[0]
	unit.statuses.erase("poison")
	DeepBattle._damage(f.state, unit, f.foe, 4, f.rng.dice)
	check(int(unit.statuses.get("poison", 0)) == 1, "a hit on a Spore Slime poisons whoever threw it")

func paradox_moth() -> void:
	var f: Dictionary = setup(["PARADOX_MOTH"], 1)
	force(f.foe, 0, "Lantern")
	turn(f)
	var unit: Dictionary = f.state.players[0]
	var out: Dictionary = DeepBattle.command(f.state, "p0", {"kind": "reroll", "dice": ["p0_d0"]}, f.rng.dice)
	check(out.get("event", {}).get("dice", []).size() == unit.hand.size(), "under its lantern a reroll throws every die")
	force(f.foe, 0, "Unravel")
	turn(f)
	check(unit.hand.any(func(r: Dictionary) -> bool: return bool(r.get("blanked", false))), "Unravel blanks a die rerolled the turn before")

func mirrors() -> void:
	var f: Dictionary = setup(["GLASS_WYRM"])
	force(f.foe, 0, "Mirror")
	turn(f)
	var thrower: Dictionary = f.state.players[0]
	var other: Dictionary = f.state.players[1]
	var hp_other: int = int(other.hp)
	var out: Dictionary = DeepBattle._damage(f.state, thrower, f.foe, 10, f.rng.dice)
	check(int(other.hp) == hp_other and out.get("reflections", []).size() == 1, "the wyrm's mirror sends half back at whoever threw it")
	var g: Dictionary = setup(["PRISM_GOLEM"])
	force(g.foe, 0, "Refract")
	turn(g)
	var back: Dictionary = DeepBattle._damage(g.state, g.state.players[0], g.foe, 10, g.rng.dice)
	check(back.get("reflections", []).size() == 2, "a refraction sends it at the whole party")

func gathered_light() -> void:
	var f: Dictionary = setup(["THE_PRISMARCH"])
	force(f.foe, 0, "Gather Light")
	force(f.foe, 1, "Crush")
	turn(f)
	check(not f.foe.get("charging", {}).is_empty(), "Gather Light gathers")
	for escort in f.state.enemies:
		if str(escort.get("escort_of", "")) == str(f.foe.id):
			escort.hp = 0
	DeepBattle._damage(f.state, f.state.players[0], f.foe, 40, f.rng.dice)
	check(int(f.foe.charging.get("stored", 0)) == 40, "it keeps count of what it is dealt")
	force(f.foe, 0, "Brilliance")
	var all: Array = turn(f)
	var released: Array = all.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "enemy_move" and bool(e.get("release", false)))
	check(not released.is_empty(), "and throws it back as its next action opens")

func called_moves() -> void:
	var f: Dictionary = setup(["PIT_MOLE"])
	force(f.foe, 0, "Dig In")
	turn(f)
	check(bool(f.foe.get("burrowed", false)), "Dig In burrows")
	force(f.foe, 0, "Claw")
	var all: Array = turn(f)
	check(not moves_named(all, "Erupt").is_empty(), "it comes up with Erupt")
	var g: Dictionary = setup(["PUFFBALL"])
	force(g.foe, 0, "Swell")
	turn(g)
	turn(g)
	var swell: int = int(g.foe.get("swell", 0))
	check(swell >= 4, "Swell swells it")
	var hit: Dictionary = DeepBattle._damage(g.state, g.state.players[0], g.foe, 99999, g.rng.dice)
	check(bool(hit.get("killed", false)), "a Puffball can be killed")
