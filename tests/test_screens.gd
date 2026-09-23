extends SceneTree
## The screens, headless: the app boots, a run is played through the real screens with the
## real session, and nothing throws. Rendering is skipped; layout and logic are exercised.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	## Saves go to a scratch directory so a test never touches a real profile.
	DeepSaveStore.override_directory = "user://test_scratch"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	var app: Control = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	check(app.session != null and app.session.status == "local", "the app boots into a local session")
	check(app.home.visible and not app.descent.visible, "the workshop is shown first")
	for tab in ["map", "roster", "vault", "appraise", "ledger"]:
		app.home.open(tab)
		check(app.home._body.get_child_count() > 0, "the %s tab renders" % tab)
	## The roster shows a locked lapidary's dossier without letting them be chosen.
	app.home._roster_pick = "FLORIN"
	app.home.open("roster")
	check(app.home._body.get_child_count() > 0 and app.profile.current_character == "ARDOR", "a locked lapidary can be looked at, not played")
	app.home._roster_pick = ""
	await _loadout_drags(app)
	app._depart(9001)
	await process_frame
	check(app.descent.visible and not app.home.visible and app.session.in_run(), "departing shows the run")
	var guard: int = 0
	var saw_battle: bool = false
	var saw_landing: bool = false
	var saw_grubstake: bool = false
	var saw_bench: bool = false
	var saw_merchant: bool = false
	var saw_smithy: bool = false
	var crossroads_ok: bool = true
	var places: Dictionary = {}
	while str(app.session.run.get("phase", "")) != "over" and guard < 500:
		guard += 1
		var run: Dictionary = app.session.run
		match str(run.phase):
			"grubstake":
				var staker: Dictionary = app.session.local_player()
				if str(staker.get("stake", "")).is_empty():
					var offers: Array = run.grubstake.offers.get(app.session.local_id, [])
					if not offers.is_empty():
						var offer: Dictionary = offers[0]
						var payload: Dictionary = {}
						if offer.needs.has("pick"):
							payload.pick = 0
						app.descent.show_state(run)
						saw_grubstake = true
						app.session.send({"kind": "stake", "offer": offer.id, "payload": payload})
			"tunnels":
				if not saw_bench and int(run.depth) >= 1:
					## The bench opens over the tunnels, both tabs render, and what it sends reaches the run.
					saw_bench = true
					for which in ["gems", "dice"]:
						app.descent.open_bench(which)
						check(app.descent._bench.is_open() and app.descent._bench._content.get_child_count() > 0, "the bench's %s tab renders" % which)
					var me: Dictionary = app.session.local_player()
					var first: String = str(me.dice[0].id)
					var second: String = str(me.dice[1].id)
					app.descent._bench._send({"kind": "swap_die", "index": 0, "die_id": second}, "die_settle")
					check(str(app.session.local_player().dice[0].id) == second and str(app.session.local_player().dice[1].id) == first, "a swap sent from the bench reaches the run")
					app.descent._bench.close()
					check(not app.descent._bench.is_open(), "and the bench closes")
				## The ways on are the mouths: one per way, and the room the party stands in has as many.
				app.descent.show_state(run)
				if app.descent.crossroads_entries().size() != run.offers.size() or app.descent._place_of(run).exits != run.offers.size():
					crossroads_ok = false
				var offer: Dictionary = run.offers[0]
				for candidate in run.offers:
					if str(candidate.kind) in ["fight", "elite"]:
						offer = candidate
				if not saw_merchant and int(run.depth) >= 1 and str(offer.kind) != "landing":
					offer.kind = "merchant"
				elif saw_merchant and not saw_smithy and str(offer.kind) != "landing":
					offer.kind = "smithy"
				elif not saw_battle and str(offer.kind) != "landing":
					## Whatever the chart rolled, the screens must be walked through a fight.
					offer.kind = "fight"
				app.session.send({"kind": "vote_tunnel", "offer": offer.id})
			"chamber":
				if DeepDescent.in_battle(run):
					saw_battle = true
					var b: Dictionary = DeepDescent.battle(run)
					if str(b.phase) == "planning":
						var unit: Dictionary = DeepBattle.player(b, app.session.local_id)
						if not bool(unit.locked):
							if int(unit.rerolls) > 0 and not unit.hand.is_empty():
								app.session.send({"kind": "reroll", "dice": [str(unit.hand[0].die_id)]})
							app.session.send({"kind": "lock"})
					else:
						app.session.tick(0.5)
				elif str(run.chamber.kind) in ["vein", "vug"]:
					var unit: Dictionary = app.session.local_player()
					if bool(unit.get("mining", false)):
						var open_spot: int = -1
						for spot in run.chamber.vein.spots:
							if str(spot.taken).is_empty():
								open_spot = int(spot.index)
								break
						var can_swing: bool = int(unit.hp) > DeepDescent.strike_cost(int(unit.get("strikes", 0)), bool(run.chamber.vein.get("hazard", false)))
						if open_spot >= 0 and can_swing:
							app.session.send({"kind": "strike", "spot": open_spot})
						else:
							app.session.send({"kind": "stop_mining"})
				elif str(run.chamber.kind) == "smithy" and not saw_smithy:
					## The smithy's card stands along the bottom of its room, and its work reaches the run.
					saw_smithy = true
					app.descent.show_state(run)
					check(app.descent._cross_title.text == "The Smithy" and _count_text(app.descent._page_holder, "Choose") == 2, "a smithy names itself at the top and puts its work along the bottom")
					var smith: Dictionary = app.session.local_player()
					var shape: String = str(smith.dice[0].shape)
					app.session.send({"kind": "oddity", "choice": "hammer" if shape != "D20" else "file", "payload": {"die_id": str(smith.dice[0].id)}})
					check(str(app.session.local_player().dice[0].shape) != shape and app.session.local_player().dice.size() == 5, "the smithy's work reaches the run (%s to %s)" % [shape, str(app.session.local_player().dice[0].shape)])
				elif str(run.chamber.kind) in ["oddity"] + DeepDescent.DICE_ROOMS:
					var oddity: Dictionary = DeepContent.oddity(str(run.chamber.oddity))
					app.session.send({"kind": "oddity", "choice": oddity.choices[oddity.choices.size() - 1].id})
				elif str(run.chamber.kind) == "merchant":
					saw_merchant = true
					app.descent.show_state(run)
					check(app.descent._cross_title.text == "A merchant" and app.descent._run_dock.visible and app.descent._run_dock.is_drawer_open(), "a stall is kept in the room, with the bag open at hand")
					## The lens: what comes off it can go in the bag, an empty socket or the scales.
					var buyer: Dictionary = app.session.local_player()
					buyer.ore = int(buyer.get("ore", 0)) + 100
					buyer.haul.append(DeepStone.make("CLEAVE", 6, 1, 3, [], {}, "screens_lot"))
					app.session.send({"kind": "appraise", "stone_id": "screens_lot"})
					var lot: Dictionary = DeepOddities.find_stone(app.session.local_player(), "screens_lot")
					var labels: Array = app.descent.appraisal_actions(lot).map(func(a: Dictionary) -> String: return str(a.label))
					check(bool(lot.get("appraised", false)) and labels.has("Into the bag") and labels.any(func(l: String) -> bool: return l.begins_with("Set in socket")) and labels.any(func(l: String) -> bool: return l.begins_with("Sell for")),
						"a stone read at a stall can go in the bag, a socket or on the scales: %s" % str(labels))
					## The scales take anything: a stone still in its rock sells for its size
					## class, so the list a click opens holds the raw as well as the read.
					app.session.local_player().haul.append(DeepStone.make("CLEAVE", 9, 1, 3, [], {}, "screens_rough"))
					app.descent.show_state(run)
					app.descent._pin("scales")
					var on_sale: int = _button_count(app.descent._chip, "Sell")
					check(on_sale == app.session.local_player().haul.size() and on_sale >= 2,
						"the scales list every stone in the bag, raw and read alike (%d of %d)" % [on_sale, app.session.local_player().haul.size()])
					check(_button_count(app.descent._chip, "Sell · %d" % DeepStone.rough_value(DeepOddities.find_stone(app.session.local_player(), "screens_rough"))) == 1,
						"a raw stone is priced on the scales at what its size class is worth")
					app.descent._pin("")
					app.session.send({"kind": "leave"})
			"landing":
				saw_landing = true
				app.descent.show_state(run)
				## The cage is walked up to before the respite, never after it: a run that
				## means to leave here takes the lift first.
				if run.depth >= 4:
					app.session.send({"kind": "choose", "choice": "lift"})
				elif str(app.session.local_player().get("respite", "")).is_empty():
					app.session.send({"kind": "respite", "choice": "rest"})
				else:
					app.session.send({"kind": "choose", "choice": "descend"})
			"hoard":
				var mine_hoard: Dictionary = run.hoard[app.session.local_id]
				app.session.send({"kind": "pick_hoard", "stone_id": mine_hoard.offers[0].id})
			"salvage":
				app.session.send({"kind": "ready"})
		var place: Dictionary = app.descent._place_of(app.session.run)
		if not place.is_empty():
			places[str(place.kind)] = true
		if guard % 10 == 0:
			await process_frame
	check(str(app.session.run.get("phase", "")) == "over", "the run ends through the screens (guard %d, phase %s)" % [guard, str(app.session.run.get("phase", ""))])
	check(saw_grubstake, "the grubstake was shown and a stake taken")
	check(saw_battle, "a fight was shown")
	check(saw_bench, "the bench was opened in the tunnels")
	check(saw_merchant or str(app.session.run.get("outcome", "")) == "fallen", "a merchant was visited or the party fell first")
	check(saw_smithy or str(app.session.run.get("outcome", "")) == "fallen", "a smithy was visited or the party fell first")
	check(saw_landing or str(app.session.run.get("outcome", "")) == "fallen", "a landing was shown or the party fell first")
	check(app.profile.records.runs == 1, "the result reached the profile")
	check(crossroads_ok, "every crossroads shows one mouth per way on, in a room built with as many")
	check(places.has("head") and places.has("fight"), "the run stands in rooms: the shaft head and fights (%s)" % str(places.keys()))
	check(not app.descent.walking(), "with no screen nobody walks: the rooms change at once")
	## Where the party stands, read off the state alone.
	var probe: Dictionary = app.session.run.duplicate(true)
	probe.phase = "landing"
	probe.depth = 8
	probe.landing = {"depth": 8, "warden_next": true, "cleared": false}
	check(app.descent._place_of(probe).kind == "landing" and app.descent._place_of(probe).exits == 1 and float(app.descent._place_of(probe).drop) == 0.0, "a Warden's landing has one way on, level, to its hall")
	probe.landing.cleared = true
	check(app.descent._place_of(probe).kind == "warden", "once the Warden is dead the party stands in its hall")
	probe.phase = "hoard"
	check(app.descent._place_of(probe).kind == "warden", "the hoard is taken in the Warden's hall")
	probe.phase = "over"
	check(app.descent._place_of(probe).is_empty(), "at the end the party stays where it fell")
	## Every oddity's page renders, pickers and all, whichever ones the run happened to meet.
	var fake: Dictionary = app.session.run.duplicate(true)
	fake.phase = "chamber"
	app.descent._hold = {}
	for key in DeepContent.section("oddities"):
		fake.chamber = {"kind": "oddity", "oddity": str(key), "results": {}, "depth": 1, "settled": false}
		for unit in fake.players:
			unit.oddity_choice = ""
			unit.downed = false
		app.descent.show_state(fake)
		check(app.descent._page_holder.get_child_count() > 0, "the %s page renders" % str(key))
	## A smithy and a carver show their own card in their own room.
	for kind in DeepDescent.DICE_ROOMS:
		fake.chamber = {"kind": kind, "oddity": DeepDescent.room_card(kind), "results": {}, "depth": 1, "settled": false}
		app.descent.show_state(fake)
		check(app.descent._cross_title.text == str(DeepContent.oddity(DeepDescent.room_card(kind)).name) and _count_text(app.descent._page_holder, "Choose") == 2 and _count_text(app.descent._page_holder, "Leave it") == 1,
			"a %s shows its card: two pieces of work and the way out" % kind)
	## The well is a room of its own as well: a stone down it, or a measure of ore.
	app.session.local_player().ore = 120
	fake.chamber = {"kind": "well", "oddity": DeepDescent.room_card("well"), "results": {}, "depth": 1, "settled": false}
	app.descent.show_state(fake)
	check(app.descent._cross_title.text == str(DeepContent.oddity(DeepDescent.room_card("well")).name) and _count_text(app.descent._page_holder, "Choose") == 2,
		"the wishing well shows its card in its own room")
	var probe_box := VBoxContainer.new()
	root.add_child(probe_box)
	var pair: Dictionary = app.descent._picker(probe_box, "die_face_pair", app.descent.me(), "recut").call()
	check(pair.has("die_id") and pair.has("face") and pair.has("from") and int(pair.face) != int(pair.from), "the carver's picker names a die, a face to recut and a face to copy: %s" % str(pair))
	check(DeepOddities.apply({"kind": "copy_face"}, app.descent.me().duplicate(true), pair, RandomNumberGenerator.new(), {}).ok, "and what it names is work the carver will do")
	probe_box.free()
	## The shaft head: a pick stake hides its three until it is taken, then shows them on a
	## page of their own; a stake left to chance holds its result up once the party moves on.
	var head_state: Dictionary = app.session.run.duplicate(true)
	var mine_id: String = app.session.local_id
	head_state.phase = "grubstake"
	for unit in head_state.players:
		unit.stake = ""
	var dig: Dictionary = DeepDescent.mine_of(head_state)
	var picked_stones: Array = []
	for index in range(3):
		var stone: Dictionary = DeepForge.roll_stone(RandomNumberGenerator.new(), dig, 4, 2, {}, "pick%d" % index)
		stone.appraised = true
		picked_stones.append(stone)
	var pick_offer: Dictionary = {"id": "stake_pick", "kind": "stone", "boons": ["PICK_STONE"], "needs": ["pick"], "pick_kind": "stone", "picks": picked_stones}
	head_state.grubstake = {"offers": {}, "chosen": {}}
	head_state.grubstake.offers[mine_id] = [pick_offer]
	app.descent._stake_choosing = ""
	app.descent.show_state(head_state)
	check(app.descent._page_holder.get_child_count() > 0 and _find_class(app.descent._page_holder, "OptionButton") == null, "the stakes render with nothing to set")
	app.descent._stake_choosing = "stake_pick"
	app.descent.show_state(head_state)
	check(app.descent._stake_choosing == "stake_pick" and _count_text(app.descent._page_holder, "Take this one") == pick_offer.picks.size(), "taking a pick shows its candidates, one button each")
	app.descent._stake_choosing = ""
	head_state.phase = "tunnels"
	app.descent.show_state(head_state)
	check(app.descent._stake_choosing == "", "leaving the shaft head forgets a half-taken pick")
	app.descent.handle({"kind": "staked", "unit": mine_id, "finished": true, "boons": ["COST_CHIPPED", "REWARD_CARATS"], "message": "Strike is now judged Rough. Strike weighs 9 carats now.",
		"made": [], "dice": [], "changed": picked_stones.slice(0, 1)})
	app.descent.show_state(head_state)
	check(str(app.descent._hold.get("kind", "")) == "stake" and _count_text(app.descent._page_holder, "Onward") == 1, "a stake left to chance holds its result up")
	app.descent._hold = {}
	app._back_home()
	await process_frame
	check(app.home.visible and not app.descent.visible, "back in the workshop")
	## Under the loupe at home: the stone is known the moment the loupe goes on, and the
	## choice at the end is which of two to keep when one of its skill is already kept.
	var raw: Dictionary = DeepStone.make("STRIKE", 11, 2, 1, ["STAR"], {}, "screens_raw")
	app.profile.tray.append(raw)
	app.profile.gold = 500
	app.home._appraise_pick = "screens_raw"
	app.home.open("appraise")
	var fee: int = DeepProfile.appraisal_fee(raw)
	check(_count_text(app.home, "Appraise · %d gold" % fee) == 1 and _label_count(app.home, "Medium red stone") >= 1 and _label_count(app.home, "11") == 0, "a raw stone on the tray is named by its size class and color, never its carat")
	## The loupe is paid work, and the other way off the tray is a buyer who never reads it.
	check(_count_text(app.home, "Sell rough · +%d gold" % DeepStone.rough_value(raw)) == 1 and fee > DeepStone.rough_value(raw), "the tray offers the fee or a rough sale, and the fee is the dearer of the two")
	var purse: int = int(app.profile.gold)
	app.home._appraise_stone(raw)
	check(bool(raw.appraised) and bool(raw.inclusions_revealed) and app.profile.tray.has(raw), "the loupe reads the stone and leaves it on the tray")
	check(int(app.profile.gold) == purse - fee and app.profile.seen.has("STRIKE"), "the fee comes out of the purse and the vault notes the skill")
	app.profile.gold = 0
	var poor: Dictionary = DeepStone.make("GUARD", 11, 2, 1, [], {}, "screens_poor")
	check(not DeepProfile.appraise(app.profile, poor) and not bool(poor.get("appraised", false)), "an empty purse cannot pay for a loupe")
	app.profile.gold = 500
	var choices: Array = app.home._tray_actions(raw, true)
	check(choices.size() == 3 and str(choices[0].label) == "Keep the new one" and str(choices[1].label) == "Keep your old one" and bool(choices[2].get("dismiss", false)), "with one of its skill kept, the choice is which to keep, or later")
	app.home.open("appraise")
	check(_count_text(app.home, "Keep the new one") == 1 and _count_text(app.home, "Keep your old one") == 1, "the tray offers the same choice beside the kept one")
	var old_gold: int = int(app.profile.gold)
	var old_value: int = DeepStone.value(DeepProfile.owned(app.profile, "STRIKE"))
	choices[0].call.call()
	check(str(DeepProfile.owned(app.profile, "STRIKE").id) == "screens_raw" and not app.profile.tray.has(raw) and int(app.profile.gold) == old_gold + old_value, "keeping the new one sells the old one")
	for stone in app.profile.get("tray", []).duplicate():
		stone.appraised = true
	app.home.open("appraise")
	if not app.profile.tray.is_empty():
		DeepProfile.decide_tray(app.profile, str(app.profile.tray[0].id), true)
		app._profile_changed()
	check(true, "appraisal decisions flow through")
	print("Screens: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _loadout_drags(app: Control) -> void:
	## The loadout is rearranged with the mouse: a set stone dragged into the vault comes out,
	## a vault stone dragged onto a socket goes in, and nothing goes where it does not fit or
	## into a socket only the mine fills. Clicking a socket, then a stone, still works. A
	## headless window takes no pointer, so the workshop gets a screen of its own.
	var screen := SubViewport.new()
	screen.size = Vector2i(1600, 900)
	root.add_child(screen)
	var home: Control = load("res://view/home/home_screen.gd").new()
	screen.add_child(home)
	var profile: Dictionary = DeepProfile.new_profile("Dragger")
	DeepProfile.keep(profile, DeepStone.make("FURY", 3, 1, 3, [], {"source": "test"}, "screens_fury"))
	var lobby: Dictionary = app.session.lobby.duplicate(true)
	home.profile_changed.connect(func() -> void: home.refresh(profile, lobby, "local", true, app.session.local_id, true, {}))
	home._roster_pick = "ARDOR"
	home._roster_view = "sockets"
	home.tab = "roster"
	home.refresh(profile, lobby, "local", true, app.session.local_id, true, {})
	await _frames(2)
	var rail: Array = profile.characters.ARDOR.rail
	check(rail.slice(0, 3) == ["STRIKE", "GUARD", "MEND"] and home._targets.size() == 4, "the loadout's three sockets and the vault take drops (%d)" % home._targets.size())
	await _drag(screen, _centre(home._targets[0].node), _centre(home._targets[3].node) + Vector2(0, home._targets[3].node.size.y * 0.3))
	check(profile.characters.ARDOR.rail[0] == null and home._bench_socket == -1, "a set stone dragged into the vault comes out: %s" % str(profile.characters.ARDOR.rail))
	await _drag(screen, _centre(_vault_tile(home, "Fury")), _centre(home._targets[0].node))
	check(profile.characters.ARDOR.rail[0] == "FURY", "a vault stone dragged onto a socket goes in: %s" % str(profile.characters.ARDOR.rail))
	await _drag(screen, _centre(_vault_tile(home, "Strike")), _centre(home._targets[1].node))
	check(profile.characters.ARDOR.rail[1] == "GUARD", "a Red stone dropped on the Blue socket is refused: %s" % str(profile.characters.ARDOR.rail))
	await _drag(screen, _centre(_vault_tile(home, "Strike")), _centre(home._targets[2].node.get_parent().get_child(3)))
	check(profile.characters.ARDOR.rail[3] == null, "a socket only the mine fills takes no drop: %s" % str(profile.characters.ARDOR.rail))
	await _click(screen, _centre(home._targets[0].node))
	check(home._bench_socket == 0, "clicking a socket picks it (%d)" % home._bench_socket)
	await _click(screen, _centre(_vault_tile(home, "Strike")))
	check(profile.characters.ARDOR.rail.slice(0, 3) == ["STRIKE", "GUARD", "MEND"], "then clicking a stone sets it: %s" % str(profile.characters.ARDOR.rail))
	screen.queue_free()

func _vault_tile(home: Control, caption: String) -> Control:
	## The loadout's vault tile whose caption is this.
	var tray: Control = home._targets[home._targets.size() - 1].node
	for tile in tray.get_child(0).get_child(1).get_children():
		if tile is PanelContainer and _label_count(tile, caption) > 0:
			return tile
	return null

func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center() if control != null else Vector2.ZERO

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

var _pointer: Vector2 = Vector2.ZERO

func _mouse(viewport: Viewport, at: Vector2, pressed: Variant = null) -> void:
	## A mouse event as the player makes it: a move (with the left button held) when
	## `pressed` is null, or the left button going down or up.
	if pressed == null:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = at - _pointer
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(motion)
	else:
		var button := InputEventMouseButton.new()
		button.position = at
		button.global_position = at
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = bool(pressed)
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if bool(pressed) else 0
		viewport.push_input(button)
	_pointer = at

func _drag(viewport: Viewport, from: Vector2, to: Vector2) -> void:
	_mouse(viewport, from, true)
	await process_frame
	for step in range(1, 9):
		_mouse(viewport, from.lerp(to, float(step) / 8.0))
		await process_frame
	_mouse(viewport, to, false)
	await _frames(3)

func _click(viewport: Viewport, at: Vector2) -> void:
	_mouse(viewport, at, true)
	await process_frame
	_mouse(viewport, at, false)
	await _frames(3)

func _find_class(node: Node, wanted: String) -> Node:
	if node.get_class() == wanted:
		return node
	for child in node.get_children():
		var found: Node = _find_class(child, wanted)
		if found != null:
			return found
	return null

func _count_text(node: Node, text: String) -> int:
	## Buttons in a subtree whose label is exactly this.
	var count: int = 1 if node is Button and (node as Button).text == text else 0
	for child in node.get_children():
		count += _count_text(child, text)
	return count

func _button_count(node: Node, fragment: String) -> int:
	## Buttons in a subtree whose label begins with this: a price is part of the words.
	var count: int = 1 if node is Button and (node as Button).text.begins_with(fragment) else 0
	for child in node.get_children():
		count += _button_count(child, fragment)
	return count

func _label_count(node: Node, fragment: String) -> int:
	## Labels in a subtree whose text holds this.
	var count: int = 1 if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text.contains(fragment) else 0
	for child in node.get_children():
		count += _label_count(child, fragment)
	return count

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
