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
	dice_denial()
	hall_of_mirrors()
	deeper_dice_rules()
	jagged()
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
	## Raise the Rate is a ladder: every Tax face to Heavy Tax, and only once no Tax is left
	## (its second etching is a `fallback`), every Heavy Tax to Ruinous Tax.
	var h: Dictionary = setup(["THE_ASSAYER"])
	var taxes: int = _faces(h.foe, "Tax")
	force(h.foe, 0, "Weigh")
	var ladder: Array = DeepCreatures.move_in(DeepCreatures.moves_for(h.foe), "Raise the Rate").effects
	check(ladder.size() == 2 and bool(ladder[1].get("fallback", false)) and str(ladder[1].from) == "Heavy Tax" and str(ladder[1].to) == "Ruinous Tax", "its second rung is a fallback from Heavy Tax to Ruinous Tax")
	var reactions: Dictionary = {}
	for effect in ladder:
		DeepBattle._apply(h.state, h.foe, effect, h.rng.creatures, "", reactions)
	check(_faces(h.foe, "Tax") == 0 and _faces(h.foe, "Heavy Tax") == taxes and _faces(h.foe, "Ruinous Tax") == 0, "Raise the Rate turns every Tax face, and no Heavy Tax while a Tax stood")
	reactions = {}
	for effect in ladder:
		DeepBattle._apply(h.state, h.foe, effect, h.rng.creatures, "", reactions)
	check(_faces(h.foe, "Heavy Tax") == 0 and _faces(h.foe, "Ruinous Tax") == taxes, "and with no Tax left, every Heavy Tax face")
	reactions = {}
	var spent: Array = []
	for effect in ladder:
		spent.append_array(DeepBattle._apply(h.state, h.foe, effect, h.rng.creatures, "", reactions))
	check(spent.all(func(r: Dictionary) -> bool: return bool(r.get("nothing", false))) and _faces(h.foe, "Ruinous Tax") == taxes, "and then nothing: the rate is as high as it goes")

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
	check(not snatch.is_empty() and int(snatch[0].effects[0].get("stolen", 0)) == 30, "Snatch takes a tenth of the richest player's 300 pyrite")
	check(str(foe.dice[0].faces[0].move) == "Flee", "the Snatch face it landed becomes Flee")
	real.faces[at] = foe.dice[0].faces[0]
	foe.dice[0] = real
	check(_faces(foe, "Snatch") == snatches - 1 and _faces(foe, "Flee") == 1, "one Snatch face fewer, one Flee face more")
	force(foe, 0, "Flee")
	var gone: Array = moves_named(turn(f), "Flee")
	check(not gone.is_empty() and bool(gone[0].effects[0].get("fled", false)) and int(foe.hp) <= 0 and bool(foe.get("fled", false)), "Flee leaves the fight")
	check(int(gone[0].effects[0].get("stolen", 0)) == 30, "and takes what it stole with it")

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
	## Fog also lifts on its own after 3 turns (November 13, 2026). Guards never hit the Clouder.
	f = setup(["CLOUDER"], 1)
	unit = f.state.players[0]
	for at in range(unit.rail.size()):
		unit.rail[at] = stone("GUARD", "p0_g%d" % at)
	for d in range(f.foe.dice.size()):
		force(f.foe, d, "Gather")
	force(f.foe, 0, "Fog")
	turn(f)
	var lefts: Array = [DeepBattle.hold_left(DeepBattle.hold_at(unit, "fog", int(unit.clouded[0]) if not unit.clouded.is_empty() else -1), int(f.state.turn))]
	force(f.foe, 0, "Gather")
	for _turn in range(2):
		turn(f)
		lefts.append(DeepBattle.hold_left(DeepBattle.hold_at(unit, "fog", int(unit.clouded[0]) if not unit.clouded.is_empty() else -1), int(f.state.turn)))
	check(lefts == [3, 2, 1] and unit.clouded.size() == 1, "fog counts down 3, 2, 1 over the turns it holds: %s" % str(lefts))
	turn(f)
	check(unit.get("fog", []).is_empty() and unit.clouded.is_empty(), "and lifts on its own after 3 turns")
	## The Foreman's rubble holds the heaviest gem's socket for 3 turns, then digs itself out.
	var g: Dictionary = setup(["THE_FOREMAN"], 1)
	for d in range(g.foe.dice.size()):
		force(g.foe, d, "Shore Up")
	force(g.foe, 0, "Bury")
	turn(g)
	var hero: Dictionary = g.state.players[0]
	check(hero.get("rubble", []).size() == 1 and hero.buried.size() == 1, "Bury leaves rubble, and it is there as the next turn opens")
	var left: Array = [DeepBattle.hold_left(DeepBattle.hold_at(hero, "rubble", int(hero.buried[0])), int(g.state.turn))]
	force(g.foe, 0, "Shore Up")
	for _turn in range(2):
		turn(g)
		left.append(DeepBattle.hold_left(DeepBattle.hold_at(hero, "rubble", int(hero.buried[0]) if not hero.buried.is_empty() else -1), int(g.state.turn)))
	check(left == [3, 2, 1] and hero.buried.size() == 1, "the rubble counts down 3, 2, 1: %s" % str(left))
	turn(g)
	check(hero.get("rubble", []).is_empty() and hero.buried.is_empty(), "and the socket digs itself out after 3 turns")

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

# --- W3 and W4 (November 13, 2026): dice a Warden denies, and blows that cost the thrower ----

func _hand(unit: Dictionary, shapes: Array, values: Array) -> void:
	## Sets a player's hand by hand: these shapes, showing these faces.
	var hand: Array = []
	for i in range(values.size()):
		hand.append({"die_id": "%s_h%d" % [str(unit.id), i], "shape": str(shapes[i]), "value": int(values[i]), "top": int(DeepDice.SHAPES[str(shapes[i])]), "kind": "plain"})
	unit.hand = hand

func _numbed(unit: Dictionary) -> Array:
	return unit.hand.filter(func(r: Dictionary) -> bool: return r.has("numb")).map(func(r: Dictionary) -> int: return int(r.value))

func dice_denial() -> void:
	## The Drill's Jam: each player's smallest dice count for nothing on their next turn.
	var f: Dictionary = setup(["THE_DRILL"], 1)
	for d in range(f.foe.dice.size()):
		force(f.foe, d, "Bore")
	force(f.foe, 0, "Jam")
	turn(f)
	var unit: Dictionary = f.state.players[0]
	check(DeepCreatures.trait_value(f.foe, "numb_small", 0) == 1, "Jam holds its rule through the party's turn")
	## A bowl all of one size (setup's five d6s): every die but one is numbed, never all of them.
	check(unit.hand.filter(func(r: Dictionary) -> bool: return r.has("numb")).size() == unit.hand.size() - 1 and not unit.hand.back().has("numb"),
		"a bowl of one size keeps its last die counting: %s" % str(unit.hand.map(func(r: Dictionary) -> String: return str(r.get("numb", "-")))))
	check(int(DeepHand.analyze(unit.hand).dice_count) == 1, "and the hand reads as that one die")
	_hand(unit, ["D4", "D4", "D6", "D8", "D12"], [4, 4, 4, 4, 4])
	DeepBattle.numb_hand(f.state, unit)
	check(_numbed(unit) == [4, 4] and unit.hand[0].numb == "small" and str(unit.hand[0].numb_by) == str(f.foe.id), "a mixed bowl loses only its d4s")
	var crush: Dictionary = DeepStone.make("CRUSH", 1, 4, 3, [], {}, "c")
	check(DeepStone.evaluate(crush, unit.hand).active, "the d6, d8 and d12 still make a triple of 4s")
	_hand(unit, ["D4", "D4", "D4", "D6", "D12"], [4, 4, 4, 2, 9])
	DeepBattle.numb_hand(f.state, unit)
	check(not DeepStone.evaluate(crush, unit.hand).active, "but three 4s on numbed d4s are no triple")
	force(f.foe, 0, "Bore")
	turn(f)
	check(not DeepCreatures.has_trait(f.foe, "numb_small") and _numbed(unit).is_empty(), "the rule lifts as its next action opens")
	## The Lock-Keeper's High Water: dice showing 2 or less count for nothing; a reroll is read again.
	var g: Dictionary = setup(["THE_LOCKKEEPER"], 1)
	for d in range(g.foe.dice.size()):
		force(g.foe, d, "Wrench")
	force(g.foe, 0, "High Water")
	turn(g)
	var hero: Dictionary = g.state.players[0]
	_hand(hero, ["D6", "D6", "D6", "D6", "D6"], [1, 2, 2, 3, 6])
	DeepBattle.numb_hand(g.state, hero)
	check(_numbed(hero) == [1, 2, 2] and hero.hand[1].numb == "low", "High Water numbs every die showing 2 or less")
	check(DeepHand.analyze(hero.hand).pairs.is_empty(), "so the 2s make no pair")
	hero.hand[1].value = 5
	DeepBattle.numb_hand(g.state, hero)
	check(_numbed(hero) == [1, 2], "a face changed to 5 counts again")
	## A wild is no number: no line numbs it.
	hero.hand[0].kind = "wild"
	DeepBattle.numb_hand(g.state, hero)
	check(not hero.hand[0].has("numb"), "a wild is never under the water")
	## Killing it lifts the rule at once, mid-rail.
	g.foe.hp = 0
	DeepBattle.numb_hand(g.state, hero)
	check(_numbed(hero).is_empty(), "the rule lifts the moment the Lock-Keeper falls")
	## The Foreman's Low Ceiling: dice showing 6 or more count for nothing.
	var h: Dictionary = setup(["THE_FOREMAN"], 1)
	for d in range(h.foe.dice.size()):
		force(h.foe, d, "Pick")
	force(h.foe, 0, "Low Ceiling")
	turn(h)
	var p: Dictionary = h.state.players[0]
	_hand(p, ["D6", "D8", "D8", "D12", "D4"], [6, 5, 8, 11, 4])
	DeepBattle.numb_hand(h.state, p)
	check(_numbed(p) == [6, 8, 11] and p.hand[0].numb == "high", "Low Ceiling numbs every die showing 6 or more")
	check(int(DeepHand.analyze(p.hand).high) == 5, "so the hand's high die is the 5")
	## A reroll is read against the rule again.
	var out: Dictionary = DeepBattle.command(h.state, "p0", {"kind": "reroll", "dice": [str(p.hand[4].die_id)]}, h.rng.dice)
	check(bool(out.get("ok", false)) and p.hand.filter(func(r: Dictionary) -> bool: return r.has("numb")).all(func(r: Dictionary) -> bool: return int(r.value) >= 6), "a reroll is read against the rule again")
	## The rail reads it: a Strike fired under it reads only the dice that count.
	_hand(p, ["D6", "D6", "D6", "D6", "D6"], [6, 6, 6, 6, 2])
	DeepBattle.numb_hand(h.state, p)
	var strike: Dictionary = DeepStone.make("STRIKE", 1, 4, 3, [], {}, "s")
	var read: Dictionary = DeepStone.evaluate(strike, p.hand)
	check(read.active and read.get("dice", []).size() == 1, "a Strike under a Low Ceiling reads the one die that counts: %s" % str(read.get("dice", [])))

func hall_of_mirrors() -> void:
	## The Mirror Regent's Hall of Mirrors: every throw costs 1 health a die that matches another.
	var f: Dictionary = setup(["THE_REGENT"], 1)
	for d in range(f.foe.dice.size()):
		force(f.foe, d, "Mirror")
	force(f.foe, 0, "Hall of Mirrors")
	var all: Array = turn(f)
	var unit: Dictionary = f.state.players[0]
	check(DeepCreatures.trait_value(f.foe, "set_toll", 0) == 1, "Hall of Mirrors holds through the party's turn")
	## The throw that opened the turn paid for its matches.
	var opened: Array = all.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "turn_begin")
	var matched: int = int(DeepRules.amount({"term": "matched"}, {"a": DeepHand.analyze(unit.hand)}))
	var tolled: Array = opened.back().get("tolled", []) if not opened.is_empty() else []
	check((matched == 0 and tolled.is_empty()) or (tolled.size() == 1 and int(tolled[0].amount) == matched), "the opening throw paid 1 a matching die (%d matched, %s)" % [matched, str(tolled)])
	_hand(unit, ["D6", "D6", "D6", "D6", "D6"], [3, 3, 3, 5, 5])
	var hp: int = int(unit.hp)
	var toll: Dictionary = DeepBattle.set_toll(f.state, unit)
	check(int(toll.get("amount", 0)) == 5 and int(unit.hp) == hp - 5 and toll.dice.size() == 5, "a full house costs 5")
	_hand(unit, ["D6", "D6", "D6", "D6", "D6"], [1, 2, 3, 4, 6])
	check(DeepBattle.set_toll(f.state, unit).is_empty(), "five different values cost nothing")
	unit.hp = 2
	_hand(unit, ["D6", "D6", "D6", "D6", "D6"], [4, 4, 4, 4, 4])
	check(int(DeepBattle.set_toll(f.state, unit).get("amount", 0)) == 1 and int(unit.hp) == 1, "it never takes the last point")
	unit.hp = 500
	var out: Dictionary = DeepBattle.command(f.state, "p0", {"kind": "reroll", "dice": unit.hand.map(func(r: Dictionary) -> String: return str(r.die_id))}, f.rng.dice)
	var now: int = int(DeepRules.amount({"term": "matched"}, {"a": DeepHand.analyze(unit.hand)}))
	check(bool(out.get("ok", false)) and int(out.event.get("toll", {}).get("amount", 0)) == now, "a reroll pays for the matches it lands (%d)" % now)

func deeper_dice_rules() -> void:
	## W3 round 3 (November 16, 2026): three of the four dice rules on a Warden or boss of the
	## deeper mines, one each, each on one face where the creature's own face of about that
	## weight was. (Jam's rule stays on the Drill alone: on the Gardener, as Thin Out, it cost
	## Vesper's d4s about 16 points whichever face it took, so it was held back.)
	## [creature, move, rule, value, die label, faces of it on each die, the face it replaced,
	##  a plain move to fill its other dice, a bowl, its values, the values that count for nothing]
	var specs: Array = [
		["THE_UNDERTOW", "High Water", "numb_low", 2, "tail", [0, 1], "Drag Down", "Bite", ["D6", "D8", "D8", "D12", "D4"], [2, 1, 5, 9, 3], [2, 1]],
		["THE_KALEIDOSCOPE", "Hall of Mirrors", "set_toll", 1, "", [1, 1], "Blind", "Glare", ["D6", "D6", "D6", "D6", "D6"], [4, 4, 2, 5, 5], []],
		["THE_ANVIL_KNIGHT", "Flatten", "numb_high", 6, "hammer", [0, 1], "Forge-fire", "Hammer", ["D6", "D8", "D8", "D12", "D4"], [6, 5, 8, 11, 4], [6, 8, 11]]]
	var rules: Array = ["numb_low", "numb_high", "numb_small", "set_toll"]
	for spec in specs:
		var key: String = str(spec[0])
		var def: Dictionary = DeepContent.creature(key)
		## Its one rule, and only one of the four.
		var pinned: Array = []
		for move in def.get("moves", []):
			for effect in move.get("effects", []):
				if str(effect.get("kind", "")) == "pin_trait" and rules.has(str(effect.get("trait", ""))):
					pinned.append([str(move.name), str(effect.trait), effect.get("value", true)])
		check(pinned.size() == 1 and str(pinned[0][0]) == str(spec[1]) and str(pinned[0][1]) == str(spec[2]) and pinned[0][2] == spec[3],
			"%s holds one dice rule, %s (%s %s): %s" % [key, spec[1], spec[2], str(spec[3]), str(pinned)])
		var counts: Array = def.dice.map(func(die: Dictionary) -> int: return die.faces.count(str(spec[1])))
		check(counts == spec[5], "%s: %s on its dice %s (want %s)" % [key, spec[1], str(counts), str(spec[5])])
		if not str(spec[4]).is_empty():
			var at: int = counts.find(1)
			check(at >= 0 and str(def.dice[at].get("label", "")) == str(spec[4]), "%s: on its %s die" % [key, spec[4]])
		check(def.dice.all(func(die: Dictionary) -> bool: return not die.faces.has(str(spec[6]))) and DeepCreatures.move_in(def.moves, str(spec[6])).is_empty(),
			"%s: %s is gone, the face it took" % [key, spec[6]])
		## It lands, holds through the party's turn and reads the dice.
		var f: Dictionary = setup([key], 1)
		for d in range(f.foe.dice.size()):
			force(f.foe, d, str(spec[7]))
		force(f.foe, 0, str(spec[1]))
		var all: Array = turn(f)
		check(moves_named(all, str(spec[1])).size() == 1 and DeepCreatures.has_trait(f.foe, str(spec[2])), "%s's %s lands and holds its rule through the turn" % [key, spec[1]])
		var unit: Dictionary = f.state.players[0]
		_hand(unit, spec[8], spec[9])
		DeepBattle.numb_hand(f.state, unit)
		if str(spec[2]) == "set_toll":
			unit.hp = 500
			var toll: Dictionary = DeepBattle.set_toll(f.state, unit)
			check(int(toll.get("amount", 0)) == 4 and int(unit.hp) == 496, "%s: two pairs cost 4 under its Hall of Mirrors: %s" % [key, str(toll)])
		else:
			check(_numbed(unit) == spec[10], "%s's %s numbs %s: %s" % [key, spec[1], str(spec[10]), str(_numbed(unit))])
		## Its next action lifts it.
		force(f.foe, 0, str(spec[7]))
		turn(f)
		DeepBattle.numb_hand(f.state, unit)
		check(not DeepCreatures.has_trait(f.foe, str(spec[2])) and _numbed(unit).is_empty(), "%s: the rule lifts as its next action opens" % key)
	## Never two of the four on one creature, anywhere in the pack.
	for key in DeepContent.section("creatures"):
		var traits: Dictionary = {}
		for move in DeepContent.creature(str(key)).get("moves", []):
			for effect in move.get("effects", []):
				if str(effect.get("kind", "")) == "pin_trait" and rules.has(str(effect.get("trait", ""))):
					traits[str(effect.trait)] = true
		check(traits.size() <= 1, "%s carries one dice rule at most: %s" % [str(key), str(traits.keys())])

func jagged() -> void:
	## Jagged: every blow on it costs whoever threw it 1 health, through block, never the last.
	var f: Dictionary = setup(["GLASS_WYRM"], 1)
	var unit: Dictionary = f.state.players[0]
	unit.block = 50
	var hp: int = int(unit.hp)
	var hit: Dictionary = DeepBattle._damage(f.state, unit, f.foe, 4, f.rng.dice)
	check(int(unit.hp) == hp - 1 and int(hit.get("jagged", {}).get("amount", 0)) == 1 and int(unit.block) == 50, "a blow on a Glass Wyrm costs its thrower 1 health, and no block stops it")
	for _i in range(5):
		DeepBattle._damage(f.state, unit, f.foe, 2, f.rng.dice)
	check(int(unit.hp) == hp - 6, "every blow pays: six blows, six health")
	DeepBattle._damage(f.state, unit, f.foe, 3, f.rng.dice, true, {}, false, true, true)
	check(int(unit.hp) == hp - 6, "health lost (`pure`) is no blow")
	unit.hp = 1
	DeepBattle._damage(f.state, unit, f.foe, 3, f.rng.dice)
	check(int(unit.hp) == 1, "and it never takes the last point")
	for key in ["SHARD_WYRM", "CAVE_CRAYFISH"]:
		## Strong ordinary creatures, never a Warden: a long fight against it walls a many-hit rail.
		check(DeepCreatures.trait_value(setup([key], 1).foe, "jagged", 0) == 1, "%s is Jagged" % key)
	check(DeepCreatures.trait_value(setup(["THE_GLAZIER"], 1).foe, "jagged", 0) == 0, "the Glazier is not Jagged")
	check(DeepContent.REMEMBERED_TRAITS.has("jagged") and DeepDescent.CHAMPION_TRAITS.has("jagged"), "a Remembered boss or a Champion may be Jagged")
