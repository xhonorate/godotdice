extends SceneTree
## The creatures in a fight as the owner settled them over the plates rethink (artifact
## NMAGkwooypHHUKxsB4tR71, docs/CREATURE_DICE.md): an inset tag at each creature's feet (its
## action dice standing in it, its name, health, block and a row of grey pills), the ledger
## at the side of the room (a row a face with its pips, keywords that explain themselves), the
## roll played on the tag, the right-click die window, and what the creatures' new moves show
## as they land: a face re-etched, a die grown, an echo becoming something else, a creature
## running off, a trait pinned for a turn, fog, rubble, a leech clinging, a die left blank, a
## lantern's price per reroll. And the Creature Tells marks on the dock.

const Look = preload("res://view/battle/creature_look.gd")
const Tag = preload("res://view/battle/creature_tag.gd")
const Ledger = preload("res://view/battle/enemy_panel.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")

var failures: Array = []
var checks: int = 0
var viewport: SubViewport

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	Engine.time_scale = 8.0
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	root.add_child(viewport)
	_chips()
	await _ledger()
	await _tags()
	await _screen()
	await _events()
	viewport.free()
	Engine.time_scale = 1.0
	print("Enemy UI: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

# --- fixtures ------------------------------------------------------------------------------------

func fight(keys: Array, players: int = 1, seed_value: int = 17) -> Dictionary:
	var party: Array = []
	for i in range(players):
		var bowl: Array = []
		for j in range(5):
			bowl.append(DeepDice.make("D6", "p%d_d%d" % [i, j]))
		var rail: Array = [DeepStone.make("STRIKE", 1, 4, 3, [], {}, "p%d_s0" % i), DeepStone.make("STRIKE", 1, 4, 3, [], {}, "p%d_s1" % i), DeepStone.make("STRIKE", 1, 4, 3, [], {}, "p%d_s2" % i)]
		var unit: Dictionary = DeepBattle.make_player("p" if i == 0 else "p%d" % i, "Player %d" % i, "ARDOR", rail, bowl)
		unit.birthstone = {}
		unit.passive = {}
		unit.hp = 1000
		unit.max_hp = 1000
		party.append(unit)
	var rng: Dictionary = DeepRng.streams(seed_value, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin(party, keys, {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.max_hp = maxi(int(foe.max_hp), 2000)
		foe.hp = int(foe.max_hp)
		foe.hp_at_turn = int(foe.hp)
	return {"state": state, "rng": rng}

func force(foe: Dictionary, at_die: int, move_name: String) -> void:
	## One die of the creature lands on this move every time: it is given a single face.
	var move: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), move_name)
	var die: Dictionary = DeepDice.make("D6", "%s_d%d" % [str(foe.id), at_die], {"faces": [DeepDice.face(1)]})
	DeepCreatures.dress_face(die.faces[0], move)
	while foe.dice.size() <= at_die:
		foe.dice.append(die.duplicate(true))
	foe.dice[at_die] = die

func play(battle: Control, f: Dictionary, watch: Callable = Callable()) -> Array:
	## A whole turn as the run plays it: each step performed on the screen, then the state.
	var events: Array = []
	DeepBattle.force_lock(f.state)
	var opened: Dictionary = DeepBattle.start_resolution(f.state)
	battle.perform(opened)
	battle.show_state(f.state, 1)
	while DeepBattle.has_steps(f.state) and events.size() < 400:
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		if event.is_empty():
			continue
		events.append(event)
		battle.perform(event)
		if watch.is_valid():
			watch.call(event)
		battle.show_state(f.state, 1)
	return events

func screen_for(f: Dictionary) -> Control:
	var battle: Control = load("res://view/battle/battle_screen.gd").new()
	viewport.add_child(battle)
	battle.local_id = "p"
	battle.show_state(f.state, 1)
	return battle

static func faces_of(foe: Dictionary, move_name: String) -> int:
	var count: int = 0
	for die in DeepCreatures.effective_dice(foe):
		for face in die.get("faces", []):
			if face is Dictionary and str(face.get("move", "")) == move_name:
				count += 1
	return count

static func pips_in(row: Control) -> int:
	for node in row.find_children("*", "Control", true, false):
		if node is Look.Pips:
			return int((node as Look.Pips).count)
	return 0

static func badge_key(host: Control) -> String:
	var badge: Node = host.get_node_or_null("Mark")
	return str(badge.get_meta("key", "")) if badge != null else ""

# --- chips ---------------------------------------------------------------------------------------

func _chips() -> void:
	for on_enemy in [true, false]:
		var chips: Array = EffectChips._statuses({"curse": 3}, on_enemy)
		check(chips.size() == 1 and str(chips[0].text).contains("30% less") and str(chips[0].text).contains("30% more") and str(chips[0].text).contains("Maximum 10 stacks"), "Curse tooltips show ten percent per stack and the cap on either side")
	var sparkle_chips: Array = EffectChips.for_run({"sparkle": 100})
	check(sparkle_chips.size() == 1 and str(sparkle_chips[0].value) == "100/100" and str(sparkle_chips[0].text).contains("spends all 100") and str(sparkle_chips[0].text).contains("+%s luck" % str(snappedf(100.0 * DeepRules.SPARKLE_LUCK, 0.01))), "Sparkle chip explains its cap and complete next-find consumption")
	var acid: Dictionary = EffectChips.trait_entry("acid_armour", 1)
	check(str(acid.title) == "Acid Armour" and str(acid.text).contains("1 Poison"), "Acid Armour is a trait the ledger can say")

# --- the ledger ----------------------------------------------------------------------------------

func _ledger() -> void:
	var panel: Control = Ledger.new()
	viewport.add_child(panel)
	var f: Dictionary = fight(["CAVE_TICK", "THE_HOLLOW_CROWN"])
	var tick: Dictionary = f.state.enemies[0]
	panel.show_foe(tick, f.state, "target", "")
	await process_frame
	await process_frame
	var named: Array = Look.distinct(tick).map(func(e: Dictionary) -> String: return str(e.move))
	check(panel.visible and panel.rows().keys() == named, "the ledger has a row for every move on the creature's faces, in die order: %s" % str(panel.rows().keys()))
	for name in named:
		check(pips_in(panel.row_for(name)) == faces_of(tick, name), "%s's pips are one dot a face (%d)" % [name, faces_of(tick, name)])
	check(str(panel._who.text) == "YOUR TARGET" and str(panel._name.text) == "CAVE TICK" and str(panel._dice_words.text).begins_with("D6"), "the ledger says whose it is, its name and its dice")
	panel.set_lit("Latch")
	var lit_style: StyleBoxFlat = panel.row_for("Latch").get_theme_stylebox("panel")
	var dark_style: StyleBoxFlat = panel.row_for("Bite").get_theme_stylebox("panel")
	check(lit_style.bg_color.a > 0.05 and dark_style.bg_color.a < 0.01, "the face that landed is lit in the ledger, the others are not")
	check(lit_style.border_color == Look.ink("meddle") and dark_style.border_color == Look.ink("attack"), "a row's rule is its kind's ink")
	panel.show_foe(tick, f.state, "acting", "Bite")
	check(str(panel._who.text) == "ACTING" and panel.lit == "Bite", "an acting creature's ledger says so and keeps the landed face lit")
	panel.show_foe(tick, f.state, "looking", "")
	check(str(panel._who.text) == "LOOKING AT" and panel.lit.is_empty(), "the creature under the pointer is read as looked at")
	## A Warden: its traits and the moves on no face yet.
	var crown: Dictionary = f.state.enemies[1]
	panel.show_foe(crown, f.state, "target", "")
	await process_frame
	await process_frame
	check(panel.rows().has("Topple") and panel.rows().has("Summon"), "moves no face carries yet are listed, with when they come")
	check(Look.traits(crown).any(func(c: Dictionary) -> bool: return str(c.title) == "Sturdy"), "the Crown's Sturdy is one of its traits")
	check(Look.meaning("Sturdy", crown).contains("15%") and Look.meaning("Acid Armour", {"key": "SPORE_SLIME", "traits": {}}).contains("Poison"), "a keyword's meaning reads the creature's own number")
	for word in ["Marked", "Poison", "Burn", "Curse", "Dulled", "Festering", "Strength", "Stunned", "Drink", "Acid Armour", "Sturdy", "Steadfast", "Waterlogged"]:
		check(not Look.meaning(word).is_empty(), "the keyword %s is explained on hover" % word)
	var rtl := RichTextLabel.new()
	viewport.add_child(rtl)
	Look.write(rtl, "2 Marked and 3 damage, then Poison")
	check(rtl.get_parsed_text() == "2 Marked and 3 damage, then Poison", "keyword text keeps its words as written")
	rtl.free()
	## Every creature reads on one page: the ledger never stands taller than the room keeps for it.
	for key in DeepContent.section("creatures"):
		var foe: Dictionary = DeepCreatures.make(str(key), "ledger_" + str(key), 20, 4)
		DeepCreatures.prepare(foe)
		panel.max_height = 450.0
		panel.show_foe(foe, {}, "target", "")
		await process_frame
		await process_frame
		## Read a die at a time, its rows are that die's.
		var on_faces: int = Look.groups(foe)[panel.page].moves.size() if panel.paged else Look.distinct(foe).size()
		var expected: int = on_faces + Look.matches(foe).size() + Look.extras(foe).size()
		check(panel.rows().size() == expected, "%s's ledger has a row for each face move, match and called move (%d, got %d)" % [str(key), expected, panel.rows().size()])
		check(panel.size.y < 460.0 and panel.size.x < 550.0, "%s's ledger leaves room for the fight: %s" % [str(key), str(panel.size)])
	var wyrm: Dictionary = DeepCreatures.make("THE_KILN_WYRM", "wyrm", 20, 4)
	panel.max_height = 600.0
	panel.show_foe(wyrm, {}, "target", "")
	check(Look.groups(wyrm).size() == 3 and panel.dense and not panel.paged and panel.rows().size() == 10, "a Warden with three dice and ten moves reads one line a move where the room holds them")
	panel.max_height = 380.0
	panel.show_foe(wyrm, {}, "target", "")
	check(panel.paged and panel.rows().size() == Look.groups(wyrm)[0].moves.size(), "where it does not, it is read a die at a time")
	var breath: String = str(Look.groups(wyrm)[1].moves[0].move)
	panel.set_lit(breath)
	check(panel.page == 1 and panel.rows().has(breath) and panel.lit == breath, "the face that lands turns the ledger to its die")
	panel.max_height = 450.0
	var choir: Dictionary = DeepCreatures.make("THE_DROWNED_CHOIR", "choir", 1, 1)
	check(Look.groups(choir).size() == 1 and int(Look.groups(choir)[0].count) == 3 and Look.dice_words(choir) == "d6 ×3 · 18 faces", "dice written alike are listed once, with how many: %s" % Look.dice_words(choir))
	panel.free()

# --- the tags ------------------------------------------------------------------------------------

func _tags() -> void:
	var f: Dictionary = fight(["CAVE_TICK", "THE_HOLLOW_CROWN", "THE_DROWNED_CHOIR"])
	var tick: Dictionary = f.state.enemies[0]
	var tag: Control = Tag.new()
	viewport.add_child(tag)
	tick.statuses["poison"] = 3
	tick.block = 5
	tag.update(tick, f.state, true, 0)
	await process_frame
	var faces: Array = Look.distinct(tick)
	check(tag.pill_count() == faces.size() and tag.dice_count() == DeepCreatures.effective_dice(tick).size(), "the tag has a pill a face move and its dice standing in it")
	var bite: Control = tag.pill_of("Bite")
	var said: Array = bite.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(said == [Look.number(tick, Look.move_of(tick, "Bite"))], "a pill is the move's mark and its number, nothing more: %s" % str(said))
	check(tag._block.visible and str(tag._block_label.text) == "5", "its block is a chip on the tag's corner")
	var chip_keys: Array = tag.chips()._chips.keys()
	check(chip_keys.has("poison") and not chip_keys.has("block"), "its statuses hang under it as chips; its block is not one of them: %s" % str(chip_keys))
	check(tag.is_targeted(), "the target's tag is lit")
	check(tag.size.x >= Tag.MIN_WIDTH and tag.size.y > 30.0, "the tag is at least its narrowest")
	## A Warden's tag: wider, its pills named, in one row.
	var crown: Dictionary = f.state.enemies[1]
	var big: Control = Tag.new()
	viewport.add_child(big)
	big.update(crown, f.state, false, 0)
	await process_frame
	var crush: Control = big.pill_of("Crush")
	var crush_words: String = " ".join(crush.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	check(big.size.x >= Tag.WARDEN_WIDTH and crush_words.contains("Crush"), "a Warden's tag is wide and its pills say their names: '%s'" % crush_words)
	var rows: Dictionary = {}
	for pill in big._pills.get_children():
		rows[roundi((pill as Control).position.y)] = true
	check(rows.size() == 1, "a Warden's pills stand in one row")
	## A pinned trait is a chip while it lasts; what the creature always is is not.
	crown.traits["gift_rerolls"] = true
	crown.pinned = {"gift_rerolls": true}
	big.update(crown, f.state, false, 0)
	var crown_chips: Array = big.chips()._chips.keys()
	check(crown_chips.has("pinned_gift_rerolls") and not crown_chips.has("trait_sturdy"), "a pinned Lantern is a chip; Sturdy stays in the ledger: %s" % str(crown_chips))
	crown.traits.erase("gift_rerolls")
	crown.pinned = {}
	big.update(crown, f.state, false, 0)
	check(not big.chips()._chips.has("pinned_gift_rerolls"), "the pinned chip goes as it wears off")
	## The Choir: three dice, and the match its faces make together.
	var choir: Dictionary = f.state.enemies[2]
	var three: Control = Tag.new()
	viewport.add_child(three)
	three.update(choir, f.state, false, 0)
	await process_frame
	check(three.dice_count() == 3 and three.pill_of("Requiem Chorus") != null, "three dice stand in the Choir's tag, and its Requiem Chorus is a pill")
	var spots: Array = Tag.dice_spots(3, 70.0)
	check(Tag.dice_inset(spots) >= Tag.INSET and spots.size() == 3, "three dice fit the tag's inset")
	## Several dice stand nearly as big as one, overlapped, none further out than the screen keeps clear.
	var one: float = float(Tag.dice_spots(1, 70.0)[0][1])
	for count in range(2, 7):
		var stack: Array = Tag.dice_spots(count, 70.0)
		check(float(stack[0][1]) >= one * 0.75 and (stack[stack.size() - 1][0] as Vector2).x >= -float(load("res://view/battle/battle_screen.gd").TAG_REACH), "%d dice stand at least three quarters as big as one (%d px against %d), within the tag's reach" % [count, int(stack[0][1]), int(one)])
	## A die thrown from behind the stack swaps round to the front.
	check(three.place_of(0) == 0 and three.place_of(2) == 2, "the first die stands at the front of the stack")
	var choir_roll: Dictionary = DeepDice.roll_one(choir.dice[2], f.rng.creatures)
	choir_roll.turn_tag = 1
	three.roll({"unit": str(choir.id), "die": choir.dice[2], "roll": choir_roll, "roll_index": 2, "duration": 0.75})
	check(three.place_of(2) == 0 and three.place_of(0) == 2 and three.place_of(1) == 1, "the thrown third die swaps to the front, the first goes back to its place")
	check(three._dice.get_child(three._dice.get_child_count() - 1) == three.die_mark(2), "the thrown die is drawn over the others")
	three.settle()
	three.update(choir, f.state, false, 0)
	check(three.place_of(2) == 0, "the stack keeps its order as the tag is shown again")
	## The throw: the die grows, lands, and its face is a pill over it.
	var roll: Dictionary = DeepDice.roll_one(tick.dice[0], f.rng.creatures)
	var landed: Dictionary = tick.dice[0].faces[int(roll.face)]
	roll.move = str(landed.move)
	roll.mark = str(landed.mark)
	roll.move_kind = str(landed.move_kind)
	roll.turn_tag = 1
	tag.roll({"unit": str(tick.id), "die": tick.dice[0], "roll": roll, "roll_index": 0, "duration": 0.75})
	check(tag.grown(0) and tag.rolling() == 0, "the thrown die grows on the tag")
	check(tag.result_words().begins_with(str(landed.move)), "what it landed on is a pill over the die: '%s'" % tag.result_words())
	check(tag._result.position.y < 0.0, "the result pill stands over the die, above the tag, not over the creature's head")
	tag.settle()
	check(not tag.grown(0) and tag.result_words().is_empty(), "the die goes back into the tag as the action ends")
	tag.free()
	big.free()
	three.free()

# --- the screen ----------------------------------------------------------------------------------

func _screen() -> void:
	var f: Dictionary = fight(["CAVE_TICK", "QUARTZ_GOLEM"], 2)
	var party_state: Dictionary = f.state
	var battle: Control = screen_for(f)
	await process_frame
	var aim: String = str(party_state.players[0].target)
	var other: String = "e1" if aim != "e1" else "e0"
	check(battle._plates.size() == 2 and battle._plates.values().all(func(p: Variant) -> bool: return p is Tag), "every creature has its tag")
	check(battle._enemy_panel != null and battle._enemy_panel.visible and battle._enemy_panel.enemy_id == aim and battle._enemy_panel.who == "target", "the ledger reads the target")
	battle._hover_creature(other)
	check(battle._enemy_panel.enemy_id == other and battle._enemy_panel.who == "looking", "pointing at another creature hands the ledger to it")
	check(battle._plates[other]._hover and not battle._plates[aim]._hover, "the creature under the pointer has its tag edged")
	check(str(party_state.players[0].target) == aim, "pointing leaves the attack target alone")
	battle._hover_creature("")
	check(battle._enemy_panel.enemy_id == aim and battle._enemy_panel.who == "target", "the ledger goes back to the target when the pointer leaves")
	## The ledger stands on the side of the room away from the creature it reads.
	check(battle._ledger_right("e0") and not battle._ledger_right("e1"), "the ledger stands opposite the creature it reads")
	## Acting.
	party_state.enemies[0].acting = true
	party_state.phase = "resolving"
	battle.show_state(party_state, 1)
	await process_frame
	check(battle._plates["e0"].is_acting() and not battle._plates["e1"].is_acting() and battle._plates["e1"].modulate.a < 1.0, "the acting creature's tag is lit and the others step back")
	check(battle._enemy_panel.enemy_id == "e0" and battle._enemy_panel.who == "acting", "the ledger reads the creature acting")
	check(not battle._plates["e0"].get_global_rect().intersects(battle._my_tab.face.get_global_rect()), "the acting tag leaves the party's tabs visible")
	party_state.enemies[0].acting = false
	party_state.phase = "planning"
	battle.show_state(party_state, 1)
	## A real throw, played as the run plays it.
	var lit: Array = []
	var shut: Array = []
	var events: Array = play(battle, f, func(event: Dictionary) -> void:
		if str(event.kind) == "enemy_roll" and str(event.unit) == "e0":
			lit.append([str(event.roll.get("move", "")), battle._lit_move, battle._plates["e0"].grown(int(event.roll_index)), battle._plates["e0"].result_words(), battle._enemy_panel.lit])
		if str(event.kind) == "enemy_end" and str(event.unit) == "e0":
			shut.append([battle._enemy_roll_id, battle._plates["e0"].grown(0), battle._plates["e0"].result_words()]))
	check(not lit.is_empty() and lit.all(func(l: Array) -> bool: return str(l[0]) == str(l[1]) and bool(l[2]) and str(l[3]).begins_with(str(l[0]))), "each throw grows the die on the tag, says its face over it and lights it in the ledger: %s" % str(lit))
	check(not shut.is_empty() and shut.all(func(s: Array) -> bool: return str(s[0]).is_empty() and not bool(s[1]) and str(s[2]).is_empty()), "the die goes back as the action ends: %s" % str(shut))
	check(events.any(func(e: Dictionary) -> bool: return str(e.kind) == "enemy_move"), "the creatures acted")
	## Right-click: the die window.
	battle._inspect_creature("e0", "")
	await process_frame
	var window: Control = battle._die_window
	var first: Array = Look.face_dice(party_state.enemies[0])[0].moves
	check(window != null and is_instance_valid(window) and window.rows() >= first.size(), "right-click opens the creature's die beside a row for each of its faces")
	check(window != null and window.die_view().interactive, "the die in the window turns by hand")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	window._input(esc)
	await process_frame
	check(battle._die_window == null, "Esc closes the die window")
	## The Creature Tells marks on the dock (October 27, 2026), and who did it named on them.
	party_state = fight(["CAVE_TICK", "CLOUDER"], 2).state
	battle.show_state(party_state, 1)
	await process_frame
	var hero: Dictionary = party_state.players[0]
	hero.clouded = [0]
	hero.fog = [{"socket": 0, "by": "e1"}]
	hero.buried = [2]
	hero.rubble = [2]
	party_state.enemies[0].statuses.poison = 3
	party_state.enemies[0].statuses.curse = 1
	var locked_roll: Dictionary = hero.hand[0]
	locked_roll.lock_next = true
	var sitting_out: Dictionary = hero.hand[hero.hand.size() - 1]
	hero.hand.remove_at(hero.hand.size() - 1)
	hero.gripped = {str(sitting_out.die_id): "e1"}
	var inspection_stone: Dictionary = hero.rail[1]
	hero.rail[1] = null
	party_state.enemies[1].held_gems = [{"unit": "p", "socket": 1, "stone": inspection_stone}]
	battle.show_state(party_state, 1)
	await process_frame
	await process_frame
	var fogged: Control = battle._socket_cards[0].get_node("Slot")
	check(fogged.get_node_or_null("Fog") != null and badge_key(fogged).contains("Clouded by Clouder"), "a clouded socket wears fog and a badge naming the creature that fogged it: %s" % badge_key(fogged))
	var buried_slot: Control = battle._socket_cards[2].get_node("Slot")
	check(buried_slot.get_node_or_null("Rubble") != null and badge_key(buried_slot).contains("rest of the fight"), "rubble for the fight says so: %s" % badge_key(buried_slot))
	var held_ring: Control = battle._socket_cards[1].get_node("Slot/Ring")
	check(bool(held_ring.get("ghost")) and battle._socket_cards[1].get_node("Slot").get_node_or_null("Mark") != null, "a socket whose gem a creature holds shows the ghost of the gem and a badge")
	var locked_holder: Control = (battle._dice_views[str(locked_roll.die_id)] as Control).get_parent()
	check(locked_holder.get_node_or_null("Crackle") != null and locked_holder.get_node_or_null("Mark") != null and locked_holder.get_node("DimPane").visible, "a die a creature locked is dimmed, crackling and badged")
	check(battle._tray_box.get_node_or_null("Ghost_" + str(sitting_out.die_id)) != null, "a die in a crayfish's claw keeps a ghost seat in the tray")
	var model: CrystalCreature = battle._creature("e0")
	if model == null:
		model = CrystalCreature.make("CAVE_TICK")
		viewport.add_child(model)
		model.wear_statuses(party_state.enemies[0].statuses, 0.0)
		await process_frame
	var worn: Node = model.get_node_or_null("Wear")
	check(worn != null and int(worn._want.get("poison", 0)) == 3 and int(worn._want.get("curse", 0)) == 1, "a poisoned, cursed creature wears both on its model")
	hero.clouded = []
	hero.fog = []
	battle.show_state(party_state, 1)
	await process_frame
	check(fogged.get_node_or_null("Fog") == null, "the fog goes when the socket clears")
	## A Star Leech on the finest gem; a die a Paradox Moth left blank.
	party_state = fight(["STAR_LEECH", "PARADOX_MOTH"], 1).state
	battle.show_state(party_state, 1)
	await process_frame
	hero = party_state.players[0]
	hero.clung = {"stone_id": str(hero.rail[0].id), "socket": 0, "by": "e0"}
	var blank: Dictionary = hero.hand[1]
	blank.value = 0
	blank.kind = "blank"
	blank.locked = true
	blank.locked_by_foe = true
	blank.blanked = true
	battle.show_state(party_state, 1)
	await process_frame
	await process_frame
	var clung_slot: Control = battle._socket_cards[0].get_node("Slot")
	check(badge_key(clung_slot).contains("Star Leech clings"), "a gem a leech clings to wears its mark and name: %s" % badge_key(clung_slot))
	var blank_holder: Control = (battle._dice_views[str(blank.die_id)] as Control).get_parent()
	check(badge_key(blank_holder).contains("Blanked by Paradox Moth") and blank_holder.get_node("DimPane").visible and blank_holder.get_node_or_null("Crackle") == null, "a blanked die is dimmed and badged as blanked, not as locked: %s" % badge_key(blank_holder))
	## The party's statuses still fit along the dock.
	for member in party_state.players:
		member.sparkle = 100
		member.statuses = {"poison": 5, "stun": 2, "curse": 3, "ward": 99, "retain": 20, "charged": 125, "marked": 10, "regeneration": 6, "spikes": 4, "dulled": 5}
	battle.show_state(party_state, 1)
	await process_frame
	await process_frame
	for chip in battle._effects.get_children():
		check(chip.get_global_rect().end.x <= 1600 and chip.get_global_rect().position.x >= 0, "the expanded status collection fits without horizontal scrolling")
	battle.free()

# --- what the new moves show -----------------------------------------------------------------------

func _events() -> void:
	## A Magpie's Snatch turns its face to Flee: the tag and the ledger have the new face at once.
	var f: Dictionary = fight(["MAGPIE"], 1)
	var magpie: Dictionary = f.state.enemies[0]
	var battle: Control = screen_for(f)
	await process_frame
	check(battle._plates["e0"].pill_of("Flee") == null and battle._enemy_panel.rows().has("Flee"), "before Snatch, Flee is on no face: the ledger lists it as waiting, the tag has no pill for it")
	for face in magpie.dice[0].faces:
		DeepCreatures.dress_face(face, DeepCreatures.move_in(DeepCreatures.moves_for(magpie), "Snatch"))
	battle.show_state(f.state, 1)
	var etched: Array = []
	play(battle, f, func(event: Dictionary) -> void:
		for effect in event.get("effects", []):
			if effect is Dictionary and not effect.get("etched", []).is_empty():
				etched.append(effect.etched))
	check(not etched.is_empty(), "Snatch re-etched its own face")
	check(battle._plates["e0"].pill_of("Flee") != null and pips_in(battle._enemy_panel.row_for("Flee")) == faces_of(magpie, "Flee"), "the re-etched face is a pill on the tag and pips in the ledger as soon as it lands")
	## Its Flee: it runs off with what it took, and its tag goes.
	force(magpie, 0, "Flee")
	play(battle, f)
	check(bool(magpie.get("fled", false)) and (not battle._plates.has("e0") or battle._plates["e0"].fading), "a creature that flees takes its tag with it")
	battle.free()
	## The Hollow Crown's Rise: its die grows a size, with new faces.
	f = fight(["THE_HOLLOW_CROWN"], 1)
	var crown: Dictionary = f.state.enemies[0]
	battle = screen_for(f)
	await process_frame
	for face in crown.dice[0].faces:
		DeepCreatures.dress_face(face, DeepCreatures.move_in(DeepCreatures.moves_for(crown), "Rise"))
	battle.show_state(f.state, 1)
	play(battle, f)
	check(str(crown.dice[0].shape) == "D8" and battle._plates["e0"]._dice_key.contains("D8"), "a die grown a size is drawn the size it is now: %s" % battle._plates["e0"]._dice_key)
	check(battle._plates["e0"].pill_of("Topple") != null and battle._plates["e0"].pill_of("Summon") != null, "its new faces are pills on the tag")
	battle.free()
	## A Crystal Hydra's Sprout: another head, another die on the tag.
	f = fight(["CRYSTAL_HYDRA"], 1)
	var hydra: Dictionary = f.state.enemies[0]
	battle = screen_for(f)
	await process_frame
	var heads: int = battle._plates["e0"].dice_count()
	force(hydra, 0, "Sprout")
	battle.show_state(f.state, 1)
	play(battle, f)
	check(battle._plates["e0"].dice_count() == heads + 1 and hydra.dice.size() == heads + 1, "a grown head stands in the tag as another die (%d → %d)" % [heads, battle._plates["e0"].dice_count()])
	battle.free()
	## A Void Echo's Echo Anew: it becomes another creature, and its tag says which.
	f = fight(["VOID_ECHO"], 1, 31)
	var echo: Dictionary = f.state.enemies[0]
	battle = screen_for(f)
	await process_frame
	var was: String = str(battle._plates["e0"]._name.text)
	force(echo, 0, "Echo Anew")
	battle.show_state(f.state, 1)
	play(battle, f)
	check(int(echo.get("morphs", 0)) > 0 and str(battle._plates["e0"]._name.text) == str(echo.name).to_upper() and str(battle._plates["e0"]._name.text) != was, "an echo that becomes something else wears its new name: %s → %s" % [was, str(battle._plates["e0"]._name.text)])
	battle.free()
	## A Lantern Moth's Lantern: pinned until its next action, a chip while it lasts.
	f = fight(["LANTERN_MOTH"], 1)
	var moth: Dictionary = f.state.enemies[0]
	battle = screen_for(f)
	await process_frame
	force(moth, 0, "Lantern")
	battle.show_state(f.state, 1)
	var pinned_seen: Array = []
	play(battle, f, func(event: Dictionary) -> void:
		if str(event.kind) == "enemy_move":
			pinned_seen.append(battle._plates["e0"].chips()._chips.has("pinned_gift_rerolls")))
	check(battle._plates["e0"].chips()._chips.has("pinned_gift_rerolls"), "a pinned Lantern is a chip on its tag through the party's turn")
	## Its Singe the next turn: a price per reroll the party spent, said over the die.
	force(moth, 0, "Singe")
	DeepBattle.command(f.state, "p", {"kind": "reroll", "dice": f.state.players[0].hand.map(func(r: Dictionary) -> String: return str(r.die_id))}, f.rng.dice)
	battle.show_state(f.state, 1)
	var priced: Array = []
	var unpinned: Array = []
	play(battle, f, func(event: Dictionary) -> void:
		if str(event.kind) == "enemy_begin" and str(event.unit) == "e0":
			unpinned.append(event.get("unpinned", []))
		if str(event.kind) == "enemy_move" and str(event.get("move", "")) == "Singe":
			priced.append(battle._plates["e0"].result_words()))
	check(not unpinned.is_empty() and unpinned[0].has("gift_rerolls") and not battle._plates["e0"].chips()._chips.has("pinned_gift_rerolls"), "the pinned chip goes as the creature's next action opens")
	check(not priced.is_empty() and str(priced[0]).contains("reroll"), "a per-reroll price says the rerolls and what it came to: %s" % str(priced))
	battle.free()
