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
	app._depart(9001)
	await process_frame
	check(app.descent.visible and not app.home.visible and app.session.in_run(), "departing shows the run")
	var guard: int = 0
	var saw_battle: bool = false
	var saw_landing: bool = false
	var saw_grubstake: bool = false
	var saw_bench: bool = false
	var saw_merchant: bool = false
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
				var offer: Dictionary = run.offers[0]
				for candidate in run.offers:
					if str(candidate.kind) in ["fight", "elite"]:
						offer = candidate
				if not saw_merchant and int(run.depth) >= 1 and str(offer.kind) != "landing":
					offer.kind = "merchant"
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
					if int(unit.strikes) > 0:
						for spot in run.chamber.vein.spots:
							if str(spot.taken).is_empty():
								app.session.send({"kind": "strike", "spot": spot.index})
								break
				elif str(run.chamber.kind) == "oddity":
					var oddity: Dictionary = DeepContent.oddity(str(run.chamber.oddity))
					app.session.send({"kind": "oddity", "choice": oddity.choices[oddity.choices.size() - 1].id})
				elif str(run.chamber.kind) == "merchant":
					saw_merchant = true
					app.descent.show_state(run)
					check(app.descent._page_holder.get_child_count() > 0, "the merchant's stall renders")
					app.session.send({"kind": "leave"})
			"landing":
				saw_landing = true
				app.descent.show_state(run)
				if str(app.session.local_player().get("respite", "")).is_empty():
					app.session.send({"kind": "respite", "choice": "rest"})
				else:
					app.session.send({"kind": "choose", "choice": "lift" if run.depth >= 4 else "descend"})
			"hoard":
				var mine_hoard: Dictionary = run.hoard[app.session.local_id]
				app.session.send({"kind": "pick_hoard", "stone_id": mine_hoard.offers[0].id})
			"salvage":
				app.session.send({"kind": "ready"})
		if guard % 10 == 0:
			await process_frame
	check(str(app.session.run.get("phase", "")) == "over", "the run ends through the screens (guard %d, phase %s)" % [guard, str(app.session.run.get("phase", ""))])
	check(saw_grubstake, "the grubstake was shown and a stake taken")
	check(saw_battle, "a fight was shown")
	check(saw_bench, "the bench was opened in the tunnels")
	check(saw_merchant or str(app.session.run.get("outcome", "")) == "fallen", "a merchant was visited or the party fell first")
	check(saw_landing or str(app.session.run.get("outcome", "")) == "fallen", "a landing was shown or the party fell first")
	check(app.profile.records.runs == 1, "the result reached the profile")
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
	var die_offer: Dictionary = {"id": "stake_die", "kind": "terms", "boons": ["COST_WOUND", "REWARD_STONE"], "needs": ["pick"], "pick_kind": "die",
		"picks": [DeepForge.roll_die(RandomNumberGenerator.new(), dig, 4, "d0"), DeepForge.roll_die(RandomNumberGenerator.new(), dig, 4, "d1")]}
	head_state.grubstake = {"offers": {}, "chosen": {}}
	head_state.grubstake.offers[mine_id] = [pick_offer, die_offer]
	app.descent._stake_choosing = ""
	app.descent.show_state(head_state)
	check(app.descent._page_holder.get_child_count() > 0 and _find_class(app.descent._page_holder, "OptionButton") == null, "the stakes render with nothing to set")
	for chosen_offer in ["stake_pick", "stake_die"]:
		app.descent._stake_choosing = chosen_offer
		app.descent.show_state(head_state)
		check(app.descent._stake_choosing == chosen_offer and _count_text(app.descent._page_holder, "Take this one") == head_state.grubstake.offers[mine_id][0 if chosen_offer == "stake_pick" else 1].picks.size(),
			"taking %s shows its candidates, one button each" % chosen_offer)
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

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
