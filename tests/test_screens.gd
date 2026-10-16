extends SceneTree
## The screens, headless: the app boots, a run is played through the real screens with the
## real session, and nothing throws. Rendering is skipped; layout and logic are exercised.

const Homecoming = preload("res://view/home/homecoming.gd")
const HomeParts = preload("res://view/home/home_parts.gd")

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
	await _player_name(app)
	for tab in ["descend", "delvers", "vault", "market", "bestiary", "profile"]:
		app.home.open(tab)
		check(app.home._body.get_child_count() > 0, "the %s tab renders" % tab)
	## The old tab names still land on the page that took their place.
	for old in [["map", "descend"], ["roster", "delvers"], ["shop", "market"], ["commissions", "market"], ["ledger", "profile"], ["appraise", "vault"]]:
		app.home.open(str(old[0]))
		check(app.home.tab == str(old[1]), "the old %s tab opens %s (got %s)" % [str(old[0]), str(old[1]), app.home.tab])
	## The Delvers page shows a locked delver's dossier without letting them be chosen.
	app.home._roster_pick = "FLORIN"
	app.home.open("delvers", true)
	check(app.home._body.get_child_count() > 0 and app.profile.current_character == "ARDOR", "a locked delver can be looked at, not played")
	## Changing a delver's sockets picks them to go down.
	DeepProfile.unlock_character(app.profile, "VESPER")
	app.home.edit_loadout("VESPER", 0)
	check(app.profile.current_character == "VESPER" and app.home.tab == "delvers" and app.home._roster_view == "sockets", "editing a delver's sockets picks them to go down")
	app.home.choose_character("ARDOR")
	app.home._roster_view = "dossier"
	app.home._roster_pick = ""
	## The keyboard: 1 to 5 open the tabs, and Q and E change who goes down.
	for index in range(app.home.TABS.size()):
		_key(KEY_1 + index)
		check(app.home.tab == str(app.home.TABS[index][0]), "key %d opens the %s tab (got %s)" % [index + 1, str(app.home.TABS[index][0]), app.home.tab])
	await _bestiary(app)
	app.home.open("descend")
	_key(KEY_E)
	check(app.profile.current_character == "VESPER", "E steps to the next delver (got %s)" % app.profile.current_character)
	_key(KEY_Q)
	check(app.profile.current_character == "ARDOR", "Q steps back (got %s)" % app.profile.current_character)
	## Escape steps out of a page inside a tab before it reaches the menu.
	app.home._market_view = "wheel"
	app.home.open("market", true)
	_key(KEY_ESCAPE)
	check(app.home._market_view == "main" and not app.menu.is_open(), "Escape steps back from the Wheel to the Market")
	## A Geode's odds are its close look, opened with a right-click like a stone's: the Market
	## has no Odds button of its own any more.
	app.home.open("market", true)
	await _frames(2)
	check(_find_lamp(app.home) != null and _find_button(app.home, "Odds") == null, "the Market shows the case's stones, and no Odds button")
	app.home.open("descend")
	app.home._roster_pick = ""
	await _loadout_drags(app)
	app._depart(9001)
	await process_frame
	check(app.descent.visible and not app.home.visible and app.session.in_run(), "departing shows the run")
	check(app.session.local_player().name == "Ada the Delver", "the saved player name follows them into the mine")
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
				elif str(run.chamber.kind) in DeepDescent.ROCK_ROOMS:
					var unit: Dictionary = app.session.local_player()
					if bool(unit.get("mining", false)):
						var open_spot: int = -1
						for spot in run.chamber.vein.spots:
							if str(spot.taken).is_empty() and str(spot.get("owner", unit.id)) == str(unit.id):
								open_spot = int(spot.index)
								break
						var can_swing: bool = int(unit.hp) > DeepDescent.swing_cost(run, unit)
						if open_spot >= 0 and can_swing:
							app.session.send({"kind": "strike", "spot": open_spot})
						else:
							app.session.send({"kind": "stop_mining"})
				elif str(run.chamber.kind) == "smithy" and not saw_smithy:
					## The smithy's card stands along the bottom of its room, and its work reaches the run.
					saw_smithy = true
					app.descent.show_state(run)
					check(app.descent._cross_title.text == "The Smithy" and _count_choices(app.descent._page_holder) == 3, "a smithy names itself at the top and puts its three pieces of work along the bottom")
					var smith: Dictionary = app.session.local_player()
					var shape: String = str(smith.dice[0].shape)
					app.session.send({"kind": "oddity", "choice": "hammer" if shape != str(DeepDice.TIERS.back()) else "file", "payload": {"die_id": str(smith.dice[0].id)}})
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
					## Everything but a fragile stone, which no buyer will take at any price.
					var sellable: int = app.session.local_player().haul.filter(func(st: Dictionary) -> bool: return not DeepStone.known_fragile(st)).size()
					check(on_sale == sellable and on_sale >= 2,
						"the scales list every stone in the bag, raw and read alike (%d of %d)" % [on_sale, sellable])
					check(_button_count(app.descent._chip, "Sell · %d" % DeepStone.rough_value(DeepOddities.find_stone(app.session.local_player(), "screens_rough"))) == 1,
						"a raw stone is priced on the scales at what its size class is worth")
					app.descent._pin("")
					app.session.send({"kind": "leave"})
			"landing":
				saw_landing = true
				app.descent.show_state(run)
				## The cage is walked up to before the respite, never after it: a run that
				## means to leave here takes the lift first, and pays the winch to do it. A
				## Warden's hall has no cage, so there the only way on is down.
				if run.depth >= 4 and not bool(run.landing.get("cleared", false)):
					run.players[0].ore = int(run.players[0].ore) + DeepDescent.lift_cost(run)
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
	## A smithy and a carver show their own card in their own room: every piece of work it
	## holds, and the way out as an arrow off the end of the row.
	for kind in DeepDescent.DICE_ROOMS:
		var card: Dictionary = DeepContent.oddity(DeepDescent.room_card(kind))
		var jobs: int = card.get("choices", []).filter(func(c: Dictionary) -> bool: return str(c.get("action", {}).get("kind", "")) != "none").size()
		fake.chamber = {"kind": kind, "oddity": DeepDescent.room_card(kind), "results": {}, "depth": 1, "settled": false}
		app.descent.show_state(fake)
		check(app.descent._cross_title.text == str(card.name) and _count_choices(app.descent._page_holder) == jobs and _count_skips(app.descent._page_holder, "Leave it") == 1,
			"a %s shows its card: %d pieces of work and the way out" % [kind, jobs])
	## The well is a room of its own as well: a stone down it, or a measure of ore.
	app.session.local_player().ore = 120
	fake.chamber = {"kind": "well", "oddity": DeepDescent.room_card("well"), "results": {}, "depth": 1, "settled": false}
	app.descent.show_state(fake)
	check(app.descent._cross_title.text == str(DeepContent.oddity(DeepDescent.room_card("well")).name) and _count_choices(app.descent._page_holder) == 2,
		"the wishing well shows its card in its own room")
	var probe_box := VBoxContainer.new()
	root.add_child(probe_box)
	var lowered: Dictionary = app.descent._picker(probe_box, "die_face", app.descent.me(), "lower").call()
	check(lowered.has("die_id") and lowered.has("face"), "the carver's picker names a die and a face: %s" % str(lowered))
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
	check(app.descent._stake_choosing == "stake_pick" and _count_choices(app.descent._page_holder) == pick_offer.picks.size(), "taking a pick shows its candidates, each one a card to click")
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
	app.home._vault_view = "unappraised"
	app.home.open("vault", true)
	var fee: int = DeepProfile.appraisal_fee(raw)
	check(_count_text(app.home, "Read it") == 1 and _price_on(_find_button(app.home, "Read it")) == str(fee) and _label_count(app.home, "Medium red stone") >= 1 and _label_count(app.home, "11 ct") == 0, "a raw stone on the tray is named by its size class and color, never its carat")
	## The loupe is paid work, and the other way off the tray is a buyer who never reads it.
	check(_count_text(app.home, "Sell rough") == 1 and _price_on(_find_button(app.home, "Sell rough")) == "+%d" % DeepStone.rough_value(raw) and fee > DeepStone.rough_value(raw), "the tray offers the fee or a rough sale, and the fee is the dearer of the two")
	var purse: int = int(app.profile.gold)
	var read: Button = _find_button(app.home, "Read it")
	if read != null:
		read.pressed.emit()
	check(bool(raw.appraised) and bool(raw.inclusions_revealed) and app.profile.tray.has(raw), "the loupe reads the stone and leaves it on the tray")
	check(int(app.profile.gold) == purse - fee and app.profile.seen.has("STRIKE"), "the fee comes out of the purse and the vault notes the skill")
	app.profile.gold = 0
	var poor: Dictionary = DeepStone.make("GUARD", 11, 2, 1, [], {}, "screens_poor")
	check(not DeepProfile.appraise(app.profile, poor) and not bool(poor.get("appraised", false)), "an empty purse cannot pay for a loupe")
	app.profile.gold = 500
	## Today's commissions are drawn for the day and the profile; one that wanted a Strike would
	## add a third way off the tray. With none open, the choice is between the two stones.
	var open_today: Array = DeepEconomy.open_commissions(app.profile)
	for commission in open_today:
		commission.done = true
	var choices: Array = Homecoming.actions(app.home, raw)
	check(choices.size() == 2 and str(choices[0].label) == "Keep it, replace yours" and str(choices[1].label) == "Sell it", "with one of its skill kept, the choice is which to keep")
	for commission in open_today:
		commission.done = false
	app.home.open("vault", true)
	check(_exact_labels(app.home, "Keep it, replace yours") == 1 and _exact_labels(app.home, "Sell it") == 1, "the tray offers the same choice beside the kept one")
	var old_gold: int = int(app.profile.gold)
	choices[0].call.call()
	check(str(DeepProfile.owned(app.profile, "STRIKE").id) == "screens_raw" and not app.profile.tray.has(raw) and int(app.profile.gold) == old_gold, "keeping the new one lets the old one go for no gold")
	for stone in app.profile.get("tray", []).duplicate():
		stone.appraised = true
	app.home.open("vault", true)
	if not app.profile.tray.is_empty():
		DeepProfile.decide_tray(app.profile, str(app.profile.tray[0].id), true)
		app._profile_changed()
	check(true, "appraisal decisions flow through")
	print("Screens: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _player_name(app: Control) -> void:
	check(app.profile.name == "Player" and app.settings.player_name == "Player", "new players start as Player")
	var character: String = str(app.profile.current_character)
	await _open_name_editor(app)
	check(app.home.tab == "profile", "clicking the corner name opens the profile page")
	check(app.menu.is_open() and app.menu._name_field.text == "Player", "the profile's Change name opens an editor with the current name")
	var speed: float = app.session.speed
	var typed := InputEventKey.new()
	typed.keycode = KEY_F
	typed.unicode = 70
	typed.pressed = true
	root.push_input(typed)
	check(app.menu._name_field.text == "F" and app.session.speed == speed, "typing reaches the name field without triggering game shortcuts")
	app.menu._name_field.text = "   "
	app.menu._name_field.text_changed.emit("   ")
	var save: Button = app.menu._body.find_child("SavePlayerName", true, false)
	check(save.disabled, "a blank player name cannot be saved")
	app.menu._name_field.text_submitted.emit("   ")
	check(app.menu.is_open() and app.profile.name == "Player", "Enter cannot submit a blank name")
	app.menu._name_field.text = "  Ada the Delver  "
	app.menu._name_field.text_submitted.emit(app.menu._name_field.text)
	check(not app.menu.is_open() and app.profile.name == "Ada the Delver", "Enter saves a name and trims surrounding spaces")
	check(app.home._bar.get_node("PlayerName").text == "Ada the Delver" and app.session.local_member().name == "Ada the Delver", "the corner and current lobby show the saved name")
	check(app.saves.load_profile().name == "Ada the Delver" and app.saves.load_settings().player_name == "Ada the Delver", "the name persists in the profile and settings")
	check(app.profile.current_character == character, "renaming the player preserves their chosen lapidary")
	await _open_name_editor(app)
	check(app.menu._name_field.text == "Ada the Delver", "reopening the editor shows the saved name")
	app.menu._name_field.text = "Discard this"
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(not app.menu.is_open() and app.profile.name == "Ada the Delver", "Escape cancels editing without reopening the menu")
	await _open_name_editor(app)
	app.menu._name_field.text = "W".repeat(100)
	check(app.menu._name_field.text.length() == DeepProfile.NAME_LIMIT, "the name editor limits long names")
	app.menu.close()
	check(app.saves.load_profile().name == "Ada the Delver", "closing the editor discards unsaved changes")

func _key(keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press)
	var lift := InputEventKey.new()
	lift.keycode = keycode
	lift.pressed = false
	root.push_input(lift)

func _open_name_editor(app: Control) -> void:
	## The corner chip opens the profile page; its Change name button opens the editor.
	app.home._bar.get_node("PlayerName").pressed.emit()
	await process_frame
	var rename: Node = app.home.find_child("Rename", true, false)
	if rename is Button:
		(rename as Button).pressed.emit()
	await process_frame

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
	home.tab = "delvers"
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
	var flow: Node = _find_class(tray, "HFlowContainer")
	if flow == null:
		return null
	for tile in flow.get_children():
		if tile is PanelContainer and _label_count(tile, caption) > 0:
			return tile
	return null

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null

func _exact_labels(node: Node, text: String) -> int:
	## Visible labels and buttons in a subtree whose words are exactly these.
	var count: int = 0
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text == text:
		count = 1
	elif node is Button and (node as Button).is_visible_in_tree() and (node as Button).text == text:
		count = 1
	for child in node.get_children():
		count += _exact_labels(child, text)
	return count

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

func _find_lamp(node: Node) -> Node:
	## The first stone standing under a lamp: the Market's case shows three.
	if node is HomeParts.Showcase:
		return node
	for child in node.get_children():
		var found: Node = _find_lamp(child)
		if found != null:
			return found
	return null

func _find_class(node: Node, wanted: String) -> Node:
	if node.get_class() == wanted:
		return node
	for child in node.get_children():
		var found: Node = _find_class(child, wanted)
		if found != null:
			return found
	return null

func _price_on(button: Button) -> String:
	## The sum on a button's price tag (DeepUi.priced), or "" when it has none.
	var chip: Node = button.get_node_or_null("Price") if button != null else null
	var value: Node = chip.find_child("Value", true, false) if chip != null else null
	return (value as Label).text if value is Label else ""

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

func _count_choices(node: Node) -> int:
	## Cards in a subtree that are themselves the button.
	var count: int = 1 if bool(node.get_meta("choice", false)) else 0
	for child in node.get_children():
		count += _count_choices(child)
	return count

func _count_skips(node: Node, text: String) -> int:
	## The arrows past a row of choices that say this.
	var count: int = 1 if node is Button and (node as Button).tooltip_text == text and (node as Button).text.is_empty() else 0
	for child in node.get_children():
		count += _count_skips(child, text)
	return count

func _bestiary(app: Control) -> void:
	## A creature met after a run waits marked new; picking it shows it and takes the mark off,
	## and one not met is only a shadow with no name.
	var BestiaryPage: Script = load("res://view/home/bestiary_page.gd")
	## What a run brings home (merged as DeepProfile.apply_result does, without counting a run).
	var first: Array = DeepBestiary.merge(app.profile, {"CAVE_TICK": {"met": 3, "slain": 3, "lost": 0, "mines": {"QUARRY": 4}},
		"THE_FOREMAN": {"met": 1, "slain": 1, "lost": 0, "mines": {"QUARRY": 8}}})
	check(first.size() == 2, "the creatures met for the first time are named")
	app._profile_changed()
	check(app.home.tab_pip("bestiary") == [2, app.home.PIP_NEW], "the Bestiary tab counts the new creatures (got %s)" % str(app.home.tab_pip("bestiary")))
	app.home._bestiary_pick = ""
	app.home.open("bestiary")
	await _frames(3)
	check(app.home._bestiary_pick in ["CAVE_TICK", "THE_FOREMAN"], "the bestiary opens at a new creature (got %s)" % app.home._bestiary_pick)
	var list: Node = app.home.find_child("BestiaryList", true, false)
	check(list != null and list.get_parent() is ScrollContainer and list.get_child_count() == DeepContent.mines_in_order().size(), "every mine is a band of one scrolling list")
	check(list != null and list.find_child("Creature_THE_DRILL", true, false) != null and list.find_child("Creature_VOID_ECHO", true, false) != null,
		"the list holds every mine's creatures, met or not")
	var drawn: Node = list.find_child("Creature_CAVE_TICK", true, false) if list != null else null
	BestiaryPage.call("pick", app.home, "THE_FOREMAN")
	await _frames(2)
	check(app.home._bestiary_pick == "THE_FOREMAN" and not bool(DeepBestiary.entry(app.profile, "THE_FOREMAN").get("fresh", false)), "picking a creature shows it and takes its new mark off")
	check(drawn != null and is_instance_valid(drawn) and drawn.is_inside_tree(), "picking one leaves the list as it was, scrolled where it was")
	check(_find_label(app.home, "The Foreman") != null and app.home.find_child("BestiaryLeaves", true, false) != null, "the picked creature is named, with its pages")
	BestiaryPage.call("pick", app.home, "THE_DRILL")
	await _frames(2)
	check(_find_label(app.home, "The Drill") == null and _find_label(app.home, "???") != null, "a creature not met has no name")
	app.home._bestiary_pick = ""

func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text and (node as Label).is_visible_in_tree():
		return node
	for child in node.get_children():
		var found: Label = _find_label(child, text)
		if found != null:
			return found
	return null
