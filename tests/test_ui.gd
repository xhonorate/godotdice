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
	for tab in ["guide","heroes","gems","dice","relics","enemies","history"]:
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
	for kind in ["shop","workshop","lapidary","rest","event"]:
		state.room.kind = kind
		ui._state_changed(state)
		await frames()
		check(is_instance_valid(ui.page), "support " + kind)
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

func frames() -> void:
	await process_frame
	await process_frame

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition: failures.append(description)
