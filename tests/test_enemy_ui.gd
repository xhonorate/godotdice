extends SceneTree
## The real panel at accelerated time: hidden results, reveal, count-up and cancellation.
var failures: Array = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	Engine.time_scale = 8.0
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	root.add_child(viewport)
	var panel: Control = load("res://view/battle/enemy_panel.gd").new()
	viewport.add_child(panel)
	var dice: Array = []
	for i in range(5):
		dice.append(DeepDice.make("D6", DeepContent.die("D6"), "p%d" % i))
	var player: Dictionary = DeepBattle.make_player("p", "Player", "ARDOR", [], dice)
	player.birthstone = {}
	var rng: Dictionary = DeepRng.streams(17, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin([player], ["CAVE_TICK"], {"depth": 1}, rng.dice, rng.creatures)
	var foe: Dictionary = state.enemies[0]
	for face in foe.dice[0].faces:
		face.value = 6
	panel.show_enemy(foe, 1, true)
	await process_frame
	check(panel.visible and panel._rows.size() == 2, "pinned planning panel shows the entire moveset")
	check(not panel._stage.visible and panel._revealed == 0, "planning shows no roll or result")
	check(panel._rows[0].numbers[0].text == "Rolled value", "planning shows the formula")
	DeepBattle.start_resolution(state)
	var roll_event: Dictionary = {}
	while roll_event.is_empty():
		var event: Dictionary = DeepBattle.step(state, rng.dice, rng.creatures)
		if str(event.kind) == "enemy_roll":
			roll_event = event
	panel.show_enemy(foe, 1, true)
	panel.roll_die(roll_event)
	check(panel._stage.visible and panel._die.visible, "the acting enemy opens its die stage")
	check(panel._revealed == 0 and panel._value.text == "Rolling…", "new result stays hidden during the roll")
	check(panel._rows.all(func(row: Dictionary) -> bool: return str(row.badge.text).is_empty()), "activation is not leaked before the die lands")
	await panel._tween.finished
	check(panel._revealed == 1 and panel._value.text == "6", "landing reveals the rolled value")
	check(panel._rows.all(func(row: Dictionary) -> bool: return str(row.badge.text) == "READY"), "six activates Bite and Latch")
	var hp: int = int(state.players[0].hp)
	var ability: Dictionary = DeepBattle.step(state, rng.dice, rng.creatures)
	panel.show_enemy(foe, 1, true)
	panel.power(ability)
	check(panel._rows[0].badge.text == "ACTING" and panel._rows[0].numbers[0].text == "1", "power-up highlights the active row and starts its count at one")
	await create_timer(float(ability.duration)).timeout
	check(panel._rows[0].numbers[0].text == "6" and int(state.players[0].hp) == hp, "count reaches six before damage happens")
	var hit: Dictionary = DeepBattle.step(state, rng.dice, rng.creatures)
	panel.show_enemy(foe, 1, true)
	panel.impact(hit)
	check(int(state.players[0].hp) == hp - 6 and panel._rows[0].badge.text == "DONE", "impact applies damage and completes the row")
	var latch: Dictionary = DeepBattle.step(state, rng.dice, rng.creatures)
	panel.show_enemy(foe, 1, true)
	panel.power(latch)
	panel.reset()
	await create_timer(0.9).timeout
	check(not panel.visible and panel._animations.is_empty(), "closing during an animation cancels all callbacks")
	panel.show_enemy(foe, 1, true)
	check(panel._die.visible and panel._value.text == "6", "reconnecting in an ability restores the revealed die")
	check(panel._die._spin_time > panel._die.spin_seconds, "restored results do not reroll")
	while DeepBattle.has_steps(state):
		DeepBattle.step(state, rng.dice, rng.creatures)
	panel.show_enemy(foe, int(state.turn), true)
	check(panel._revealed == 0 and panel._rows[0].numbers[0].text == "Rolled value", "next turn resets results and amount formulas")
	panel.free()
	var battle: Control = load("res://view/battle/battle_screen.gd").new()
	viewport.add_child(battle)
	battle.local_id = "p"
	var ally: Dictionary = player.duplicate(true)
	ally.id = "ally"
	var party_state: Dictionary = DeepBattle.begin([player, ally], ["CAVE_TICK", "QUARTZ_GOLEM"], {"depth": 1}, rng.dice, rng.creatures)
	battle.show_state(party_state, 1)
	var aim: String = str(party_state.players[0].target)
	battle._pin_enemy("e1")
	await process_frame
	check(battle._enemy_panel.visible and battle._pinned_enemy == "e1", "Moves pins the selected enemy's full table")
	check(str(party_state.players[0].target) == aim, "pinning leaves the player's attack target unchanged")
	battle._pin_enemy("e1")
	check(not battle._enemy_panel.visible, "unpinning closes an unhovered inactive table")
	battle._pin_enemy("e1")
	party_state.enemies[0].acting = true
	party_state.phase = "resolving"
	battle.show_state(party_state, 1)
	await process_frame
	await process_frame
	battle._position_enemy_panel()
	check(battle._enemy_panel.enemy_id == "e0", "the acting enemy takes precedence over the pinned enemy")
	check(not battle._enemy_panel.get_global_rect().intersects(battle._ally_box.get_global_rect()), "the acting panel leaves ally cards visible")
	party_state.enemies[0].acting = false
	battle.show_state(party_state, 1)
	check(battle._enemy_panel.enemy_id == "e1", "the pinned enemy returns when the action finishes")
	battle.free()
	viewport.free()
	Engine.time_scale = 1.0
	print("Enemy UI: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)
