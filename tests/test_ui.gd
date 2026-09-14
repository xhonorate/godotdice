extends SceneTree
## Integration smoke: render actual snapshots, route a reroll through the authority,
## and open every screen without assets, Steam, a display, or writing a run save.
var ui: Control
var checked := 0
var failures: Array[String] = []

class InvitationProbe extends Node:
	var joined_id := ""
	var is_host := false
	var lobby: Dictionary = {}
	var status := "idle"
	func leave() -> void:
		pass
	func join_steam(id: String, _player_name: String) -> Dictionary:
		joined_id = id
		status = "connecting"
		return {"ok":true}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await frames()
	check(not ui.snapshot.size(), "menu opens without an active run")
	ui.offline_hotseat = true
	ui.controlled_id = "ui_test"
	ui.engine.new_run({"heroes":[{"id":"ui_test","hero_id":"MAX","name":"UI Test"}],"profile":"short_9","seed":12345,"autosave":false})
	await frames()
	check(ui.snapshot.phase == "route", "route renders")
	## A lone hero is not a committee: the route is a choice, not a vote, and there is
	## nobody to ping it to.
	var solo: Array = button_texts(ui.page, [])
	check(not has_word(solo, "Vote"), "a lone hero is never asked to vote")
	check(not has_word(solo, "Ping"), "a lone hero is offered no ping")
	check(has_word(solo, "Enter"), "a lone hero simply enters the chosen room")
	check(not ui._party_choice() and not ui._can_ping(), "solo is neither a party choice nor a ping audience")
	## Two heroes at one keyboard really do vote, but still have nobody to ping.
	var shared: Dictionary = ui.engine.state.duplicate(true)
	var second: Dictionary = shared.heroes[0].duplicate(true)
	second.id = "ui_test_2"
	second.seat = 1
	shared.heroes.append(second)
	ui._state_changed(shared)
	await frames()
	var party: Array = button_texts(ui.page, [])
	check(has_word(party, "Vote"), "a party is asked to vote on the route")
	check(not has_word(party, "Ping"), "heroes sharing one screen are offered no ping")
	ui.offline_hotseat = false
	check(ui._can_ping(), "a party on separate machines may ping")
	ui.offline_hotseat = true
	ui._state_changed(ui.engine.state)
	await frames()
	var invited_run_id: String = ui.snapshot.run_id
	ui.session.invite_received.emit("123456789")
	await frames()
	check(is_instance_valid(ui.overlay), "an invitation during a run asks before leaving")
	check(ui.snapshot.run_id == invited_run_id, "invitation preserves the current run until accepted")
	ui._close_overlay()
	check(ui.snapshot.run_id == invited_run_id, "declining an invitation keeps the current run")
	ui._command("VoteRoom", {"offer_id": ui.snapshot.offers[0].id})
	await frames()
	check(ui.snapshot.phase == "planning", "route command enters battle")
	var die: Dictionary = ui._hero().dice[0]
	ui._toggle_die(die.id)
	check(ui.selected_dice.has(die.id), "selected means reroll")
	ui._reroll()
	await frames()
	check(ui._hero().rerolls == 0 and not ui._hero().ready, "reroll spends allowance without locking hand")
	var held: Array = ui._hand_for(ui._hero()).duplicate(true)
	ui._command("SetReady", {"ready":true})
	await frames()
	check(ui.snapshot.get("turn", 0) >= 2 or ui.snapshot.phase != "planning", "lock resolves the turn")
	if ui.snapshot.phase == "planning" and ui.playback_index < ui.playback_events.size():
		check(ui._hand_for(ui._hero()) == held, "the next roll waits while the round is still playing")
		check(ui._hand_for(ui._hero()) != ui._hero().hand, "the authority has already rolled behind the held hand")
		ui._skip_playback()
		await frames()
		check(ui._hand_for(ui._hero()) == ui._hero().hand, "the held hand is released once the round finishes")
	ui._inspect_gem(ui._hero().gems[0])
	await frames()
	check(is_instance_valid(ui.overlay), "a gem sheet opens")
	ui._close_overlay()
	ui._inspect_die(ui._hero().dice[0], ui._hand_for(ui._hero())[0])
	await frames()
	check(is_instance_valid(ui.overlay), "a die sheet opens")
	check(ui.inspect_view.face_count() == ui._hero().dice[0].faces.size(), "the die sheet lists every physical face")
	var resting: Quaternion = ui.inspect_view.orientation()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	ui.inspect_view._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(90, 40)
	ui.inspect_view._gui_input(drag)
	check(ui.inspect_view.orientation() != resting, "dragging turns the inspected die")
	ui._close_overlay()
	ui._inspect_unit(ui.snapshot.enemies[0])
	await frames()
	check(is_instance_valid(ui.overlay), "an enemy sheet opens")
	ui._close_overlay()
	ui._show_inventory()
	await frames()
	check(is_instance_valid(ui.overlay), "inventory opens")
	ui._show_settings()
	await frames()
	for tab in ["guide","rooms","heroes","gems","dice","relics","enemies","history"]:
		ui.journal_tab = tab
		ui._show_journal()
		await frames()
		check(is_instance_valid(ui.overlay), "journal " + tab)
	ui._close_overlay()
	var state: Dictionary = ui.engine.state.duplicate(true)
	var original_order: Array = []
	for gem in ui.engine.state.heroes[0].gems: original_order.append(gem.id)
	state.heroes[0].hp = 0
	state.phase = "planning"
	ui._state_changed(state)
	ui._show_inventory()
	var planned := original_order.duplicate()
	planned.reverse()
	ui._inventory_command("ReorderGems", {"gem_ids":planned})
	await frames()
	check(ui.provisional_commands.get("ui_test", []).size() == 1, "downed hero can prepare a local plan")
	check(ui.engine.state.heroes[0].gems[0].id == original_order[0], "provisional plan does not mutate authority")
	ui._close_overlay()
	state.heroes[0].hp = state.heroes[0].max_hp
	state.phase = "support"
	for kind in ["shop","workshop","lapidary","rest","event","wager","crucible"]:
		state.room.kind = kind
		ui._state_changed(state)
		await frames()
		check(is_instance_valid(ui.page), "support " + kind)
	## The two rooms that are played rather than read: drive them through the real UI.
	state.room.kind = "wager"
	ui._state_changed(state)
	await frames()
	check(ui._room_guide("wager").length() > 0 and ui._room_guide("crucible").length() > 0, "new rooms describe themselves in the journal")
	ui.engine._enter_room("wager")
	ui.engine.state.heroes[0].gold = 40
	ui._state_changed(ui.engine.state)
	await frames()
	check(is_instance_valid(ui.page), "the wager stake screen renders")
	ui._command("PlaceWager", {"stake": 8})
	await frames()
	var seat: Dictionary = ui.snapshot.room.wager[ui.controlled_id]
	check(int(seat.stake) == 8 and seat.hand.size() == 5, "staking rolls the hand through the authority")
	check(is_instance_valid(ui.page), "the staked hand renders")
	ui._toggle_die(str(seat.hand[0].die_id))
	await frames()
	check(ui.selected_dice.has(str(seat.hand[0].die_id)), "a staked die can be marked for the reroll")
	ui._command("WagerReroll", {"die_ids": [str(seat.hand[0].die_id)]})
	await frames()
	check(ui.snapshot.room.wager[ui.controlled_id].rerolled, "the wager reroll reaches the authority")
	var purse: int = int(ui._hero().gold)
	ui._command("SettleWager", {})
	await frames()
	var done: Dictionary = ui.snapshot.room.wager[ui.controlled_id]
	check(done.settled and int(ui._hero().gold) == purse + int(done.payout), "settling pays the displayed hand")
	check(is_instance_valid(ui.page), "the settled table renders")
	ui.engine._enter_room("crucible")
	ui._state_changed(ui.engine.state)
	await frames()
	check(is_instance_valid(ui.page), "the crucible renders")
	var gem: Dictionary = ui._hero().gems[0]
	ui._crucible_preview(gem, "temper", {})
	await frames()
	check(is_instance_valid(ui.overlay), "the crucible previews a temper before it is paid for")
	ui._close_overlay()
	await frames()
	ui._crucible_fuel(gem)
	await frames()
	check(is_instance_valid(ui.overlay), "the crucible offers a choice of fuel")
	ui._close_overlay()
	await frames()
	var carat: int = int(gem.carat)
	var life: int = int(ui._hero().hp)
	ui._command("TemperGem", {"gem_id": gem.id, "method": "temper"})
	await frames()
	check(int(ui._hero().gems[0].carat) > carat and int(ui._hero().hp) < life, "tempering through the UI raises Carat and costs HP")
	check(is_instance_valid(ui.page), "the spent crucible renders")
	state = ui.engine.state.duplicate(true)
	state.phase = "support"
	for phase in ["mine_vote","mine_draft","reward","summary"]:
		state.phase = phase
		ui._state_changed(state)
		await frames()
		check(is_instance_valid(ui.page), "screen " + phase)
	ui._show_recovery(state)
	await frames()
	check(is_instance_valid(ui.overlay), "host loss stops at recovery view")
	var invitation_probe := InvitationProbe.new()
	ui.add_child(invitation_probe)
	ui.session = invitation_probe
	ui.snapshot = {}
	ui._accept_steam_invite("0")
	check(invitation_probe.joined_id.is_empty(), "invalid invitations never call the transport")
	ui._accept_steam_invite("987654321")
	await frames()
	check(invitation_probe.joined_id == "987654321", "accepted menu invitation joins the exact Steam lobby")
	check(ui.menu_page == "lobby", "menu invitation displays connection and lobby state")
	ui.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("UI integration: %d checks, %d failures" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func button_texts(node: Node, found: Array) -> Array:
	if node is Button: found.append(str(node.text))
	for child in node.get_children(): button_texts(child, found)
	return found

func has_word(texts: Array, word: String) -> bool:
	for text in texts:
		if str(text).contains(word): return true
	return false

func frames() -> void:
	await process_frame
	await process_frame

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition: failures.append(description)
