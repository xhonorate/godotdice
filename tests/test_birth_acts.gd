extends SceneTree
## Every Birthstone's own pieces over the fight's dock (view/battle/birth_act.gd and the
## scripts in view/battle/birth/): each of the eighteen stones is stood up in a fight on the
## desktop and on the phone, shown a few hands, thrown, and played through a turn. Its pieces
## must come up without changing the dock's height, keep inside the screen (and the phone's
## safe edges), keep their words at the text floor, and take the fight's events without a slip.
##   godot --headless --path . --script tests/test_birth_acts.gd [-- ARDOR FLORIN_BLACKJACK ...]
## (names after `--` keep the run to those stones: a delver's key for their first stone, or
## DELVER_KEY for a variant.)

const BirthAct = preload("res://view/battle/birth_act.gd")
const UNLIT: String = "UNLIT"

## The hands each stone is shown, on its delver's own dice ("top" is the die's own top face),
## and the rail it fires behind (a Patchwork wants colors).
const CASES: Dictionary = {
	"ARDOR": [[4, 4, 4, 2, 5], [3, 3, 3, 3, 3], [1, 2, 3, 5, 8]],
	"ARDOR_RAMPART": [[2, 4, 6, 2, 1], [2, 4, 6, 6, 8], [1, 3, 5, 7, 5]],
	"ARDOR_RENOWN": [[6, 6, 1, 7, 3], [6, 6, 6, 8, 7], [1, 2, 3, 4, 5]],
	"VESPER": [[1, 2, 3, 4, 9], [1, 2, 3, 4, "top"], [2, 2, 3, 3, 7]],
	"VESPER_ILL_OMEN": [[1, 1, 1, 3, 7], [1, 1, 1, 1, 1], [1, 1, 1, 1, 6], [2, 3, 4, 4, 9]],
	"VESPER_FAN_OF_KNIVES": [[3, 3, 2, 2, 9], [4, 4, 4, 4, 11], [1, 2, 3, 4, 5]],
	"CADENCE": [[1, 2, 3, 7, 9], [1, 2, 3, 4, 5], [4, 4, 8, 8, 12]],
	"CADENCE_NOCTURNE": [[1, 2, 3, 4, 5], [1, 1, 2, 2, 3], [4, 6, 8, 10, 12], [2, 2, 2, 3, 3]],
	"CADENCE_ARPEGGIO": [[1, 2, 3, 4, 5], [3, 2, 5, 1, 7], [4, 3, 2, 1, 1]],
	"RUE": [[1, 1, 2, 2, 3], [1, 1, 1, 1, 1], [4, 4, 6, 6, 6]],
	"RUE_MITHRIDATE": [[2, 3, 4, 5, 6], [1, 2, 3, 6, 6], [1, 1, 4, 4, 6]],
	"RUE_BLOODROOT": [[1, 1, 4, 4, 4], [3, 3, 3, 3, 3], [1, 2, 3, 5, 6], [2, 2, 2, 2, 5]],
	"PUCK": [[1, 3, 5, 7, 9], [2, 4, 6, 8, 10], [1, 2, 3, 4, 5]],
	"PUCK_HIGHS_AND_LOWS": [["top", 1, "top", 1, 3], ["top", "top", "top", "top", "top"], [1, 1, 1, 1, 1], [2, 3, 4, 5, 6]],
	"PUCK_PATCHWORK": [[1, 2, 3, 4, 5], [2, 2, 6, 6, 9]],
	"FLORIN": [[7, 7, 1, 2, 3], [7, 7, 7, 7, 7], [1, 2, 3, 4, 5]],
	"FLORIN_ONE_ARMED_BANDIT": [[3, 3, 5, 5, 5], [7, 7, 7, 7, 7], [1, 2, 3, 4, 5], [2, 2, 2, 2, 4]],
	"FLORIN_BLACKJACK": [[3, 4, 5, 5, 2], [7, 7, 3, 2, 2], [7, 7, 5, 4, 3], [1, 2, 3, 4, 5]]}
const RAILS: Dictionary = {"PUCK_PATCHWORK": ["STRIKE", "GUARD", "MEND", "HEX", "TITHE", "GLIMMER"]}

var failures: Array = []
var checks: int = 0
var viewport: SubViewport
var only: Array = []
var dock_height: Dictionary = {}

func _init() -> void:
	only = Array(OS.get_cmdline_user_args())
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	root.add_child(viewport)
	_files()
	await _layout("desk")
	DeepUi.phone = true
	DeepUi.safe_left = DeepUi.PHONE_SAFE_SIDE
	DeepUi.safe_right = DeepUi.PHONE_SAFE_SIDE
	DeepUi.safe_bottom = DeepUi.PHONE_SAFE_FOOT
	load("res://view/battle/battle_screen.gd").use_phone_sizes()
	viewport.size = DeepUi.PHONE_CANVAS
	dock_height.clear()
	await _layout("phone")
	viewport.free()
	print("Birthstone acts: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _files() -> void:
	## Every script in the folder is some stone's, and loads.
	var names: Dictionary = {}
	for key in CASES:
		names[str(key).to_lower() + ".gd"] = true
	var folder := DirAccess.open(BirthAct.FOLDER)
	if folder == null:
		return
	for file in folder.get_files():
		if not str(file).ends_with(".gd") or str(file) == "total_track.gd":
			continue
		check(names.has(str(file)), "%s is named after a Birthstone" % file)
		var script: Variant = load(BirthAct.FOLDER + str(file))
		check(script is GDScript and (script as GDScript).can_instantiate(), "%s loads" % file)

# --- fixtures ------------------------------------------------------------------------------------

func gem(key: String, id: String) -> Dictionary:
	var stone: Dictionary = DeepStone.make(key, 6, 4, 3, [], {}, id)
	stone.appraised = true
	stone.inclusions_revealed = true
	return stone

func fight(character: String, worn: String, rail_keys: Array) -> Dictionary:
	var bowl: Array = []
	var wanted: Array = DeepContent.character(character).dice
	for index in range(wanted.size()):
		bowl.append(DeepForge.die_from(wanted[index], "p%d" % index))
	var rail: Array = []
	for index in range(rail_keys.size()):
		rail.append(gem(str(rail_keys[index]), "p_s%d" % index))
	var unit: Dictionary = DeepBattle.make_player("p", "Player", character, rail, bowl, -1, [], worn)
	unit.sockets = unit.sockets.map(func(_socket: Variant) -> String: return UNLIT)
	unit.hp = 500
	unit.max_hp = 500
	var rng: Dictionary = DeepRng.streams(23, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin([unit], ["CAVE_TICK", "CAVE_TICK"], {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.max_hp = 3000
		foe.hp = 3000
		foe.statuses.stun = 9
	return {"state": state, "rng": rng}

func set_hand(unit: Dictionary, numbers: Array) -> void:
	var out: Array = []
	for index in range(numbers.size()):
		var die: Dictionary = unit.dice[index % unit.dice.size()]
		var value: int = DeepDice.top(die) if str(numbers[index]) == "top" else int(numbers[index])
		out.append({"die_id": str(die.id), "shape": str(die.shape), "material": str(die.get("material", "")), "value": value, "face": 0, "kind": "plain",
			"top": DeepDice.top(die), "held": false, "rerolls": 0, "locked": false, "explosions": 0, "phantom": false})
	unit.hand = out

func controls_in(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			out.append(child)
			controls_in(child, out)

# --- one layout ----------------------------------------------------------------------------------

func _layout(layout: String) -> void:
	for name in CASES:
		if not only.is_empty() and not only.has(str(name)):
			continue
		var character: String = str(name).get_slice("_", 0)
		var worn: String = str(name).substr(character.length() + 1) if str(name).contains("_") else ""
		await _stone(layout, str(name), character, worn)

func _stone(layout: String, name: String, character: String, worn: String) -> void:
	var said: String = "%s %s" % [layout, name]
	var f: Dictionary = fight(character, worn, RAILS.get(name, ["STRIKE", "GUARD"]))
	var unit: Dictionary = DeepBattle.player(f.state, "p")
	check(str(unit.get("birthstone_key", "")) == worn, "%s goes into the fight wearing its stone" % said)
	var battle: Control = load("res://view/battle/battle_screen.gd").new()
	viewport.add_child(battle)
	battle.local_id = "p"
	var hands: Array = CASES[name]
	set_hand(unit, hands[0])
	battle.show_state(f.state, 1, DeepBattle.forecast(f.state, "p"))
	await process_frame
	await process_frame
	var page: RefCounted = battle._local_page
	var has_script: bool = ResourceLoader.exists(BirthAct.path_for(DeepStone.birthstone_for(unit)))
	check((page.act != null) == has_script, "%s: its pieces are made when it has a script (%s)" % [said, str(has_script)])
	## The dock stands the same height whichever of a delver's stones is worn.
	var tall: float = battle._dock.size.y
	if not dock_height.has(character):
		dock_height[character] = tall
	check(is_equal_approx(tall, float(dock_height[character])), "%s leaves the dock its height (%.1f, %.1f for their first)" % [said, tall, float(dock_height[character])])
	var act: Control = page.act
	if act == null:
		battle.queue_free()
		await process_frame
		return
	for numbers in hands:
		set_hand(unit, numbers)
		battle.show_state(f.state, 1, DeepBattle.forecast(f.state, "p"))
		## The dice have landed.
		page.dice_settle_at = 0
		battle._sync()
		act.thrown()
		await process_frame
		await process_frame
		_fits(act, "%s %s" % [said, str(numbers)])
	## The turn played: every event goes by the act, and the stone's own tiers through it.
	for mate in f.state.players:
		mate.locked = true
	var events: Array = [DeepBattle.start_resolution(f.state)]
	var guard: int = 0
	while DeepBattle.has_steps(f.state) and guard < 400:
		guard += 1
		var event: Dictionary = DeepBattle.step(f.state, f.rng.dice, f.rng.creatures)
		if not event.is_empty():
			events.append(event)
	var lit: int = 0
	for event in events:
		battle.show_state(f.state, 1)
		act.event(event)
		if str(event.get("kind", "")) == "birthstone" and str(event.get("unit", "")) == "p":
			page.birth_outcome = event
			act.fired(event)
			for entry in event.get("tiers", []):
				if bool(entry.get("active", false)):
					lit += 1
					act.tier(entry, entry.get("effects", []), Vector3.ZERO, Color.WHITE)
	battle._sync()
	await process_frame
	_fits(act, said + " after the turn")
	check(is_instance_valid(act) and is_equal_approx(battle._dock.size.y, tall), "%s: the dock is as tall after the turn (%d tiers played)" % [said, lit])
	battle.queue_free()
	await process_frame

func _fits(act: Control, said: String) -> void:
	## Everything the act shows keeps inside the screen (the phone's safe edges too), its words
	## at the text floor, and on the phone anything pressed is a finger wide.
	var shown: Array = []
	controls_in(act, shown)
	var screen := Rect2(Vector2.ZERO, Vector2(viewport.size))
	if DeepUi.phone:
		screen = Rect2(DeepUi.safe_left, 0.0, float(viewport.size.x) - DeepUi.safe_left - DeepUi.safe_right, float(viewport.size.y) - DeepUi.safe_bottom)
	for control in shown:
		var rect: Rect2 = (control as Control).get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or (control as Control).modulate.a <= 0.01:
			continue
		check(screen.grow(1.0).encloses(rect), "%s: %s keeps inside the screen (%s)" % [said, str(control.name), str(rect)])
		if control is Label and not (control as Label).text.is_empty():
			check((control as Label).get_theme_font_size("font_size") >= DeepUi.min_text(), "%s: \"%s\" is at the text floor (%d of %d)" % [said, (control as Label).text, (control as Label).get_theme_font_size("font_size"), DeepUi.min_text()])
		if DeepUi.phone and control is BaseButton and not (control as BaseButton).disabled:
			check(rect.size.x >= DeepUi.pt(DeepUi.FINGER_LEAST) - 0.5 and rect.size.y >= DeepUi.pt(DeepUi.FINGER_LEAST) - 0.5, "%s: %s is finger-sized (%s)" % [said, str(control.name), str(rect.size)])
