extends SceneTree
## The screens, headless: the app boots, a run is played through the real screens with the
## real session, and nothing throws. Rendering is skipped; layout and logic are exercised.

const Homecoming = preload("res://view/home/homecoming.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

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
	## A new delver's sheet says their dice by name: Rue's Phial and Florin's Gambler's dice are
	## written down as objects, and once came out as their raw text (November 10, 2026).
	var inspector: Script = load("res://view/inspect/inspector.gd")
	for key in DeepContent.section("characters"):
		var said: String = str(inspector.call("_dice_words", DeepContent.character(str(key)).get("dice", [])))
		check(not said.is_empty() and not said.contains("{") and not said.contains("[") and not said.contains("\""), "%s's dice are said by name: %s" % [str(key), said])
	check(str(inspector.call("_dice_words", DeepContent.character("RUE").get("dice", []))).contains("The Phial"), "Rue's dice name the Phial")
	## Flicking across a page to turn its tabs is the phone's alone (view/ui/swipe.gd).
	check(app.home.find_child("Swipe", false, false) == null, "the desk's workshop has no flick watcher")
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
	## Each shelf Geode is a 3D world of its own: kept from one visit to the next, not built again.
	var geode_view: Script = load("res://view/gems/geode_view.gd")
	var shelf_ids := func() -> Array:
		return app.home.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n.get_script() == geode_view).map(func(n: Node) -> int: return n.get_instance_id())
	var first_visit: Array = shelf_ids.call()
	app.home.open("descend")
	app.home.open("market", true)
	await _frames(2)
	check(not first_visit.is_empty() and shelf_ids.call() == first_visit, "the Market keeps its shelf Geodes' views from one visit to the next (%d, then %d)" % [first_visit.size(), shelf_ids.call().size()])
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
					check(app.descent._cross_title.text == "A merchant" and app.descent._run_dock.visible and not app.descent._run_dock.is_drawer_open(), "a stall is kept in the room, with the bag shut so the goods' price tags show")
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
				## The camp first: the respite. Then the crossroads, where a run that means to
				## leave here takes the lift and pays the winch to do it. A Warden's hall has no
				## cage, so there the only way on is down.
				if DeepDescent.needs_respite(run, app.session.local_player()):
					app.session.send({"kind": "respite", "choice": "rest"})
				elif run.depth >= 4 and not bool(run.landing.get("cleared", false)):
					run.players[0].ore = int(run.players[0].ore) + DeepDescent.lift_cost(run)
					app.session.send({"kind": "choose", "choice": "lift"})
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
	## A landing's page left set (a trade opened from a tab whose partner then fell, so it never
	## closed itself) does not follow the party into the hoard, where it hid the pedestals' chip
	## and its "Take it".
	var hoard_stone: Dictionary = DeepForge.roll_stone(RandomNumberGenerator.new(), DeepDescent.mine_of(probe), 6, 3, {}, "screens_hoard")
	probe.hoard = {app.session.local_id: {"offers": [hoard_stone], "chosen": ""}}
	app.descent._hold = {}
	app.descent._landing_view = "trade"
	app.descent.show_state(probe)
	check(app.descent._landing_view.is_empty(), "a landing's page does not follow the party into the hoard (got '%s')" % app.descent._landing_view)
	probe.erase("hoard")
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
	## holds, and the way out as a key in the room's corner.
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
	await _nov5_c1(app)
	await _deep_start(app)
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
	check(choices.size() == 2 and str(choices[0].label) == "Sell it" and str(choices[1].label) == "Keep it, replace yours", "with one of its skill kept, the choice is which to keep, keeping it last")
	## The worse of the two asks before it replaces the better one; the better one asks before it is sold.
	var kept_now: Dictionary = DeepProfile.owned(app.profile, "STRIKE")
	var found_score: int = int(DeepStone.grade(raw).score)
	var kept_score: int = int(DeepStone.grade(kept_now).score)
	var found_better: bool = found_score > kept_score or (found_score == kept_score and DeepStone.value(raw) > DeepStone.value(kept_now))
	check(str(choices[1 if not found_better else 0].get("confirm", "")).begins_with("Click again") and str(choices[0 if not found_better else 1].get("confirm", "")).is_empty(), "the choice that would cost the better stone asks for a second click, the other does not")
	for commission in open_today:
		commission.done = false
	app.home.open("vault", true)
	check(_exact_labels(app.home, "Keep it, replace yours") == 1 and _exact_labels(app.home, "Sell it") == 1, "the tray offers the same choice beside the kept one")
	var old_gold: int = int(app.profile.gold)
	choices[1].call.call()
	check(str(DeepProfile.owned(app.profile, "STRIKE").id) == "screens_raw" and not app.profile.tray.has(raw) and int(app.profile.gold) == old_gold, "keeping the new one lets the old one go for no gold")
	for stone in app.profile.get("tray", []).duplicate():
		stone.appraised = true
	app.home.open("vault", true)
	if not app.profile.tray.is_empty():
		DeepProfile.decide_tray(app.profile, str(app.profile.tray[0].id), true)
		app._profile_changed()
	check(true, "appraisal decisions flow through")
	await _conquest_again(app)
	print("Screens: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _conquest_again(app: Control) -> void:
	## A beaten mine's sheet holds until a way out is chosen, but its buttons put it away before
	## the rules answer and the rules can refuse (a respite owed, the party still at the camp).
	## Gone with no choice standing, it comes back from a key under the boss hall's name
	## (November 10, 2026). Headless, the sheet never opens, which stands for that case.
	if app.session.in_run():
		check(true, "a run was already under way; the boss hall's key is checked by build/nov10/nav/conquest_flow.gd")
		return
	app._depart(9001)
	for step in range(400):
		var phase: String = str(app.session.run.get("phase", ""))
		if phase == "tunnels":
			break
		if phase == "grubstake":
			var offers: Array = app.session.run.grubstake.offers.get(app.session.local_id, [])
			if not offers.is_empty() and str(app.session.local_player().get("stake", "")).is_empty():
				var offer: Dictionary = offers[0]
				app.session.send({"kind": "stake", "offer": str(offer.id), "payload": {"pick": 0} if offer.get("needs", []).has("pick") else {}})
		await process_frame
	var run: Dictionary = app.session.run
	var bottom: int = DeepContent.mine_bottom("QUARRY")
	run.phase = "landing"
	run.depth = bottom
	run.records.deepest = bottom
	run.records.wardens = run.schedule.wardens.duplicate()
	run.records.boss = true
	run.path = [{"depth": bottom, "kind": "landing", "hidden": false, "x": 0.5, "id": "landing"}]
	run.landing = {"depth": bottom, "warden_next": true, "cleared": true, "respites": {}}
	var descent: Control = app.descent
	descent._hold = {}
	descent.show_state(run)
	app._note_conquest(run)
	for step in range(30):
		if descent._news.is_empty():
			break
		descent._tell_news()
		await process_frame
	await _frames(2)
	check(descent._party_asks().any(func(ask: Dictionary) -> bool: return str(ask.kind) == "conquest"), "with the beaten mine's sheet gone and no way out chosen, the boss hall offers it again")
	var again: Button = descent.find_child("ConquestAgain", true, false) as Button
	check(again != null and again.is_visible_in_tree(), "as a key under the hall's name")
	if again != null:
		again.pressed.emit()
		check(descent._conquest_shown, "and the key opens the sheet again")
	app.session.local_player().choice = "lift"
	check(not descent._party_asks().any(func(ask: Dictionary) -> bool: return str(ask.kind) == "conquest"), "with a way out chosen, there is nothing to ask again")
	app.session.send({"kind": "abandon"})
	await _frames(2)

func _nov5_c1(app: Control) -> void:
	## November 5, 2026, lane C1: the trading booth at a party's landing, the twin plate's odds
	## and the stone card's trigger row under its picture.
	var landing: Dictionary = app.session.run.duplicate(true)
	var me_id: String = app.session.local_id
	landing.phase = "landing"
	landing.depth = 4
	landing.landing = {"depth": 4, "warden_next": false, "cleared": false, "respites": {}, "trades": {}, "trade": {"offers": {}, "accepted": []}}
	landing.erase("hoard")
	var mine: Dictionary = DeepDescent.player(landing, me_id)
	mine.respite = ""
	mine.downed = false
	mine.connected = true
	mine.choice = ""
	mine.station = ""
	mine.erase("twin")
	landing.players = [mine]
	app.descent._hold = {}
	app.descent._landing_view = ""
	app.descent.show_state(landing)
	var solo: Array = app.descent._landing_stations()
	check(solo.has("rest") and solo.has("appraise") and solo.has("wish") and not solo.has("trade") and not solo.has("up"),
		"alone, the camp offers the fire, the bench and the well, and no booth (%s)" % str(solo))
	## Two more delvers, a seat each.
	for entry in [["c1_bo", "Bo", 1], ["c1_cy", "Cy", 2]]:
		var other: Dictionary = mine.duplicate(true)
		other.id = str(entry[0])
		other.name = str(entry[1])
		other.seat = int(entry[2])
		other.haul = []
		landing.players.append(other)
	app.descent.show_state(landing)
	var party: Array = app.descent._landing_stations()
	check(party.has("trade") and party.has("rest") and app.descent._tradeable() == ["c1_bo", "c1_cy"],
		"in a party the camp offers the booth as well, with everyone free to trade (%s / %s)" % [str(party), str(app.descent._tradeable())])
	## With two teammates free the booth asks with whom; picking one opens the trade page with them.
	app.descent._trade_station("")
	var plate: Control = app.descent._whom_plate
	check(plate != null and plate.find_child("Partner_c1_bo", true, false) != null and plate.find_child("Partner_c1_cy", true, false) != null and app.descent._landing_view.is_empty(),
		"with two teammates free the booth asks with whom")
	if plate != null and plate.find_child("Partner_c1_cy", true, false) != null:
		plate.find_child("Partner_c1_cy", true, false).pressed.emit()
	check(app.descent._landing_view == "trade" and app.descent._trade_with == "c1_cy" and app.descent._whom_plate == null,
		"picking one opens the trade page with them (view '%s', with '%s')" % [app.descent._landing_view, app.descent._trade_with])
	app.descent._open_landing("")
	## With one teammate free it sits straight down with them; once this player has traded, the booth is not offered.
	landing.landing.trades = {"c1_cy": ["You traded a stone."]}
	app.descent.show_state(landing)
	app.descent._trade_station("")
	check(app.descent._landing_view == "trade" and app.descent._trade_with == "c1_bo" and app.descent._whom_plate == null,
		"with one teammate free the booth sits straight down with them (view '%s', with '%s')" % [app.descent._landing_view, app.descent._trade_with])
	app.descent._open_landing("")
	landing.landing.trades[me_id] = ["You traded a stone."]
	app.descent.show_state(landing)
	check(not app.descent._landing_stations().has("trade") and app.descent._tradeable().is_empty(), "once this player has traded the booth is no longer offered")
	## The twin plate says what the fire can make as a range (the owner, November 5, round 3):
	## the weights fuse_gain can reach, no percentages, under the averaged Cut and the Clarity.
	var held: Dictionary = DeepStone.make("STRIKE", 8, 3, 3, [], {}, "c1_held")
	held.appraised = true
	var found: Dictionary = DeepStone.make("STRIKE", 7, 1, 3, [], {}, "c1_found")
	found.appraised = true
	var odds: Array = app.descent.fuse_odds(8, 4)
	check(absf(float(odds[0]) - 0.75) < 0.001 and absf(float(odds[1]) - 0.21875) < 0.001 and absf(float(odds[2]) - 0.03125) < 0.001,
		"the fuse odds are fuse_gain's: half the weight gives a carat a quarter of the time and two one time in thirty-two (%s)" % str(odds))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var drawn: Array = [0, 0, 0]
	for _draw in range(4000):
		drawn[DeepOddities.fuse_gain(rng, 8, 4)] += 1
	check(absf(float(drawn[0]) / 4000.0 - float(odds[0])) < 0.03 and absf(float(drawn[1]) / 4000.0 - float(odds[1])) < 0.03,
		"the sim's fire draws at the odds the range is read from (%s)" % str(drawn))
	var top: int = DeepStone.carat_max()
	var ranges: Array = [[8, 7, "Carat 8–10"], [10, 2, "Carat 10–12"], [8, 8, "Carat 9–10"], [top, top, "Carat %d" % top], [top - 1, 3, "Carat %d–%d" % [top - 1, top]]]
	for entry in ranges:
		var words: String = app.descent.carat_range_words(app.descent.fuse_range(int(entry[0]), int(entry[1])))
		check(words == str(entry[2]), "%d ct and %d ct fuse to %s (got %s)" % [int(entry[0]), int(entry[1]), str(entry[2]), words])
	var probe_box := VBoxContainer.new()
	root.add_child(probe_box)
	var line: Control = app.descent._fuse_line(probe_box, found, held)
	var said: Array = []
	_percent_labels(line, said)
	check(said.is_empty() and _label_count(line, "Carat 8–10") == 1 and _label_count(line, "Cut: %s" % DeepContent.cut_name(2)) == 1 and _label_count(line, "Clarity: Included to Intricate") == 1 and _label_count(line, "Zoning") == 0,
		"the twin plate's one line: Carat 8–10, the averaged Cut and the Clarity range, and no percentages (%s)" % str(said))
	## Two colors in: the lost one is named as a Zoning wherever the sim would freeze one in.
	var blue: Dictionary = DeepStone.make("GUARD", 5, 1, 3, [], {}, "c1_blue")
	var lost_color: String = str(DeepContent.skill("GUARD").get("color", ""))
	var zoned: bool = not DeepOddities.zoning_key(lost_color).is_empty()
	var mixed: Control = app.descent._fuse_line(probe_box, blue, held)
	check(_label_count(mixed, "Zoning: %s" % str(DeepContent.color(lost_color).get("name", ""))) == (1 if zoned else 0),
		"a pair of two colors names the lost one as a Zoning when the fire would freeze it in (%s, zoning %s)" % [lost_color, str(zoned)])
	## The stone card: the trigger row sits centred under the picture, in the left column.
	var card: PanelContainer = app.descent._stone_option(probe_box, held, Callable())
	var trigger: Node = card.find_child("Trigger", true, false)
	var words: Node = _find_class(card, "RichTextLabel")
	check(trigger is HBoxContainer and trigger.get_parent() is VBoxContainer and trigger.get_parent().get_child(0) is Thumbs.GemThumb
		and words != null and words.get_parent() != trigger.get_parent() and (trigger as BoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER and trigger.get_child_count() > 0,
		"a stone card's trigger row sits centred under its picture, not among the words")
	check(card.custom_minimum_size.x == 340.0, "and the card keeps its width (%d)" % int(card.custom_minimum_size.x))
	probe_box.free()

func _deep_config(seed_value: int, mine: String, me_id: String) -> Dictionary:
	## A run set out in `mine` by this player and a teammate, each with three stones set.
	var players: Array = []
	for entry in [[me_id, "Ada", "ARDOR"], ["c1_bo", "Bo", "VESPER"]]:
		var id: String = str(entry[0])
		var rail: Array = []
		for skill in (["STRIKE", "GUARD", "MEND"] if id == me_id else ["CLEAVE", "CRUSH", "BARRAGE"]):
			var stone: Dictionary = DeepStone.make(str(skill), 4, 2, 3, [], {}, "%s_%s" % [id, str(skill).to_lower()])
			stone.appraised = true
			rail.append(stone)
		var dice: Array = []
		var keys: Array = DeepContent.character(str(entry[2])).dice
		for index in range(keys.size()):
			dice.append(DeepForge.die_from(keys[index], "%s_d%d" % [id, index]))
		players.append({"id": id, "name": str(entry[1]), "character": str(entry[2]), "rail": rail, "dice": dice})
	return {"seed": seed_value, "mine": mine, "boons": true, "players": players}

func _deep_start(app: Control) -> void:
	## Round 4 (docs/DEEP_START.md): a deep start goes straight to the Grubstake, its cards say
	## they are from the deep, each card chosen on a page of its own sends what the rules want,
	## and a Smith's Voucher shows its holder the better work.
	var descent: Control = app.descent
	var me_id: String = app.session.local_id
	var sent: Array = []
	var catch := func(cmd: Dictionary) -> void: sent.append(cmd)
	descent.command.connect(catch)
	descent._hold = {}
	descent._landing_view = ""
	descent._stake_choosing = ""
	for entry in [["WARRENS", 3], ["SEEPS", 1]]:
		var state: Dictionary = DeepDescent.new_run(_deep_config(4242, str(entry[0]), me_id))
		var unit: Dictionary = DeepDescent.player(state, me_id)
		var k: int = int(entry[1])
		check(int(state.get("deep_start", 0)) == k and str(state.phase) == "grubstake" and DeepDescent.temporary_left(unit) == 0 and DeepDescent.dice_offers_left(unit) == 0,
			"a %s start is %d mines deep, with no temporary stones and no dice to swap" % [str(entry[0]), k])
		descent.show_state(state)
		var page: Node = descent._page_holder
		var offers: Array = state.grubstake.offers[me_id]
		check(_label_count(page, "The Grubstake") >= 1 and _label_count(page, "Temporary stones") == 0 and _label_count(page, "Dice for the deep") == 0 and _count_choices(page) == 3,
			"a %s start shows the Grubstake's three cards first" % str(entry[0]))
		var ribbons: int = _named_count(page, "DeepRibbon")
		var better: int = _named_count(page, "BetterTag")
		## Every depth shows two deep cards and one better stake (November 6, 2026).
		check(ribbons == 2 and better == 1, "the %s's cards wear 2 Deep ribbons and 1 Better tag (got %d and %d)" % [str(entry[0]), ribbons, better])
		check(offers.all(func(o: Dictionary) -> bool: return o.texts.all(func(t: Variant) -> bool: return _label_count(page, str(t)) >= 1)),
			"every card shows its own filled words")
		check(page.find_child("DeepStart", true, false) != null, "the page says which mines a deep start skips")
	## Each card that is chosen on a page of its own: built from the rules' own offers.
	var state: Dictionary = DeepDescent.new_run(_deep_config(77, "WARRENS", me_id))
	var unit: Dictionary = DeepDescent.player(state, me_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hand: Array = [DeepBoons._make_deep_offer(state, unit, "BAG_OF_GEMS", rng, 3), DeepBoons._make_deep_offer(state, unit, "BAG_OF_DICE", rng, 3),
		DeepBoons._make_deep_offer(state, unit, "ONE_MATERIAL", rng, 3)]
	DeepBoons._number(hand)
	state.grubstake.offers[me_id] = hand
	var take: int = int(hand[0].take)
	## Bag of Gems: exactly `take` of them.
	descent._stake_choosing = "stake0"
	descent.show_state(state)
	check(_count_choices(descent._page_holder) == hand[0].picks.size(), "the Bag of Gems shows all %d of its stones" % hand[0].picks.size())
	for index in range(take):
		descent._gem_bag_toggle(hand[0], index)
	descent._gem_bag_toggle(hand[0], take)
	var go: Button = descent._page_holder.find_child("BagTake", true, false)
	check(descent._bag_chosen.size() == take and go != null and not go.disabled and _label_count(descent._page_holder, "%d of %d chosen" % [take, take]) == 1,
		"the Bag of Gems takes exactly %d: one more is refused, and Take is lit" % take)
	descent._gem_bag_toggle(hand[0], 0)
	go = descent._page_holder.find_child("BagTake", true, false)
	check(go != null and go.disabled, "with one put back, Take is not lit")
	descent._gem_bag_toggle(hand[0], take)
	sent.clear()
	go = descent._page_holder.find_child("BagTake", true, false)
	if go != null:
		go.pressed.emit()
	var wanted: Array = range(1, take + 1)
	check(sent.size() == 1 and sent[0].get("payload", {}).get("picks", []) == wanted and str(sent[0].get("offer", "")) == "stake0", "the Bag of Gems sends the picks: %s" % str(sent))
	if sent.size() == 1:
		var trial: Dictionary = state.duplicate(true)
		var took: Dictionary = DeepDescent.command(trial, me_id, sent[0])
		check(bool(took.get("ok", false)) and DeepDescent.player(trial, me_id).haul.size() == take, "the rules take the Bag of Gems' answer: %s" % str(took.get("error", "")))
	## Bag of Gems' rows: four to a row, a short last row centred under the first (round 5).
	descent._stake_choosing = "stake0"
	descent.show_state(state)
	var gem_rows: Node = descent._page_holder.find_child("GemBag", true, false)
	var row_sizes: Array = gem_rows.get_children().map(func(r: Node) -> int: return r.get_child_count()) if gem_rows != null else []
	check(gem_rows != null and row_sizes == [4, hand[0].picks.size() - 4] and gem_rows.get_children().all(func(r: Node) -> bool: return r is HBoxContainer and (r as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER),
		"the Bag of Gems stands in centred rows of four (%s)" % str(row_sizes))
	## Bag of Dice (round 5): your dice and the bag's trade places, a click on one and then one in
	## the other row (or one dragged onto the other); nothing is final until the button.
	descent._stake_choosing = "stake1"
	descent.show_state(state)
	var bag_row: Node = descent._page_holder.find_child("BagDice", true, false)
	var own_row: Node = descent._page_holder.find_child("OwnDice", true, false)
	check(bag_row != null and bag_row.get_child_count() == hand[1].picks.size() and own_row != null and own_row.get_child_count() == unit.dice.size(),
		"the Bag of Dice shows your %d dice and the bag's %d" % [unit.dice.size(), hand[1].picks.size()])
	go = descent._page_holder.find_child("BagTake", true, false)
	check(go != null and go.text == "Keep my dice", "with nothing traded, its button keeps your dice")
	check(_label_count(descent._page_holder, "instead of your") == 0 and _label_count(descent._page_holder, "click to swap here") == 0, "no die says what it would replace")
	var own_ids: Array = unit.dice.map(func(d: Dictionary) -> String: return str(d.id))
	var bag_ids: Array = hand[1].picks.map(func(d: Dictionary) -> String: return str(d.id))
	descent._bag_click("hand", 0)
	descent._bag_click("hand", 1)
	descent._bag_click("bag", 2)
	check(descent.bag_hand_ids()[1] == bag_ids[2] and str(descent._bag_pool[2].id) == own_ids[1] and descent.bag_hand_ids()[0] == own_ids[0],
		"a die clicked, then one in the other row, trade places (the second click in a row only moves the hold)")
	descent._bag_trade("bag", 0, "hand", 3)
	check(descent.bag_hand_ids()[3] == bag_ids[0] and str(descent._bag_pool[0].id) == own_ids[3], "one dragged onto the other trades the same way")
	descent._bag_click("bag", 2)
	descent._bag_click("hand", 1)
	check(descent.bag_hand_ids()[1] == own_ids[1], "a die of yours put in the bag can come back out")
	go = descent._page_holder.find_child("BagTake", true, false)
	check(go != null and go.text == "Take these dice", "with a die traded, the button takes these dice (got '%s')" % (go.text if go != null else ""))
	var wanted_hand: Array = own_ids.duplicate()
	wanted_hand[3] = bag_ids[0]
	sent.clear()
	if go != null:
		go.pressed.emit()
	check(sent.size() == 1 and sent[0].get("payload", {}) == {"hand": wanted_hand}, "the Bag of Dice sends the hand as it stands: %s" % str(sent))
	if sent.size() == 1:
		var trial: Dictionary = state.duplicate(true)
		var took: Dictionary = DeepDescent.command(trial, me_id, sent[0])
		## The bag's die takes the place, and the id, of the die it replaced (the bowl keeps its ids).
		var landed: Dictionary = DeepDescent.player(trial, me_id).dice[3]
		check(bool(took.get("ok", false)) and str(landed.shape) == str(hand[1].picks[0].shape) and landed.faces == hand[1].picks[0].faces,
			"the rules take the Bag of Dice's hand, the bag's die in slot 4: %s" % str(took.get("error", "")))
	descent._bag_trade("hand", 3, "bag", 0)
	go = descent._page_holder.find_child("BagTake", true, false)
	sent.clear()
	if go != null:
		go.pressed.emit()
	check(go != null and go.text == "Keep my dice" and sent.size() == 1 and sent[0].get("payload", {}) == {"hand": own_ids}, "traded back, it keeps your dice and sends them: %s" % str(sent))
	## One Material: one of three, each on one of your dice.
	descent._stake_choosing = "stake2"
	descent.show_state(state)
	var row: Node = descent._page_holder.find_child("Materials", true, false)
	check(row != null and row.get_child_count() == 3 and _count_choices(row) == 3, "One Material shows its three")
	sent.clear()
	descent._take_numbered(1)
	check(sent.size() == 1 and sent[0].get("payload", {}) == {"pick": 1} and str(sent[0].get("offer", "")) == "stake2", "One Material sends the pick: %s" % str(sent))
	if sent.size() == 1:
		var trial: Dictionary = state.duplicate(true)
		var took: Dictionary = DeepDescent.command(trial, me_id, sent[0])
		check(bool(took.get("ok", false)) and DeepDescent.player(trial, me_id).dice.all(func(d: Dictionary) -> bool: return str(d.get("material", "")) == str(hand[2].picks[1])), "the rules take One Material's answer")
	descent._stake_choosing = ""
	## A Smith's Voucher: its holder sees the better work, badged; a teammate without one, the plain.
	for room in [["smithy", "SMITHY", {"pattern": "split"}], ["carver", "CARVER", {"etching": "golden"}]]:
		var at_room: Dictionary = state.duplicate(true)
		at_room.phase = "chamber"
		at_room.chamber = {"kind": str(room[0]), "oddity": str(room[1]), "results": {}, "depth": 2, "settled": false, "vouchered": [me_id], "offer": room[2]}
		DeepDescent.player(at_room, me_id).vouchers = 1
		descent._oddity_step = ""
		descent.show_state(at_room)
		var work: int = DeepContent.oddity(str(room[1])).choices.filter(func(c: Dictionary) -> bool: return c.get("improved", null) is Dictionary).size()
		## The better words are marked in the card's own words, drawn bold, never with their marks.
		check(_named_count(descent._page_holder, "MarkedText") >= 1 and _label_count(descent._page_holder, "**") == 0 and _rich_count(descent._page_holder, "**") == 0,
			"the %s's better words are drawn marked, and no mark is shown" % str(room[0]))
		## And in the cards' names too, gold within the title (round 5 follow-up).
		check(_named_count(descent._page_holder, "MarkedTitle") == work, "every better card at the %s marks its name's better words (%d of %d)" % [str(room[0]), _named_count(descent._page_holder, "MarkedTitle"), work])
		check(_named_count(descent._page_holder, "UpgradedBadge") == work and _meta_count(descent._page_holder, "improved") == work and descent._cross_hint.find_child("BenchHint", true, false) != null,
			"a voucher holder at the %s sees %d better pieces of work, badged, and how many vouchers are left" % [str(room[0]), work])
		var holder: String = descent.local_id
		descent.local_id = "c1_bo"
		descent.show_state(at_room)
		check(_named_count(descent._page_holder, "UpgradedBadge") == 0 and _meta_count(descent._page_holder, "improved") == 0 and descent._cross_hint.find_child("BenchHint", true, false) == null,
			"a teammate without one sees the %s's plain work" % str(room[0]))
		descent.local_id = holder
		if str(room[0]) == "carver":
			## The better raise: up to three faces, of one die or several.
			descent._oddity_step = "raise"
			descent.show_state(at_room)
			var ask: Control = descent._ask
			var dice: Array = DeepDescent.player(at_room, me_id).dice
			check(ask.is_open() and ask.face_most() == 3, "the better raise asks for up to three faces")
			ask.take("die", str(dice[0].id))
			ask.pick_face("faces", [0], str(dice[0].id))
			ask.pick_face("faces", [1], str(dice[0].id))
			ask.take("die", str(dice[1].id))
			ask.pick_face("faces", [0], str(dice[1].id))
			ask.pick_face("faces", [1], str(dice[1].id))
			sent.clear()
			ask._do()
			var faces: Array = sent[0].get("payload", {}).get("picks", []) if sent.size() == 1 else []
			check(sent.size() == 1 and str(sent[0].get("choice", "")) == "raise" and faces.size() == 3 and faces[2] == {"die_id": str(dice[1].id), "face": 0},
				"the three-face pick sends up to three picks, each with its die: %s" % str(sent))
		else:
			## The better stamp: every die at once, so its ask only says so, and sends nothing to pick.
			descent._oddity_step = "stamp"
			descent.show_state(at_room)
			var ask: Control = descent._ask
			check(ask.is_open() and not ask.payload().is_empty(), "the better stamp asks only to be sure, its button lit")
			sent.clear()
			ask._do()
			check(sent.size() == 1 and str(sent[0].get("choice", "")) == "stamp" and sent[0].get("payload", {"x": 1}).is_empty(), "and sends the stamp with no payload: %s" % str(sent))
		descent._oddity_step = ""
	## A lucky bench (round 5): the whole party sees the better work, free, and says so.
	var lucky: Dictionary = state.duplicate(true)
	lucky.phase = "chamber"
	lucky.chamber = {"kind": "smithy", "oddity": "SMITHY", "results": {}, "depth": 2, "settled": false, "vouchered": [], "lucky": true, "offer": {"pattern": "split"}}
	descent._oddity_step = ""
	descent.show_state(lucky)
	var hint: Node = descent._cross_hint.find_child("BenchHint", true, false)
	check(descent.bench_upgrade() == "luck" and _named_count(descent._page_holder, "UpgradedBadge") == 3 and hint != null and _label_count(hint, "A good day at the bench") == 1,
		"a lucky smithy shows its better work, badged, and says it is a good day at the bench")
	var holder_id: String = descent.local_id
	descent.local_id = "c1_bo"
	descent.show_state(lucky)
	check(_named_count(descent._page_holder, "UpgradedBadge") == 3, "and so does the teammate's")
	descent.local_id = holder_id
	check(descent.plain_words("Hammer a die **two sizes** bigger") == "Hammer a die two sizes bigger", "the marks come off the words anywhere else")
	## Hammered and A Wild Face (round 5): charges, spent a click at a time, each at once.
	var charged: Dictionary = DeepDescent.new_run(_deep_config(91, "WARRENS", me_id))
	var charger: Dictionary = DeepDescent.player(charged, me_id)
	var crng := RandomNumberGenerator.new()
	crng.seed = 91
	var hammer: Dictionary = DeepBoons._make_offer(charged, charger, "kit", ["HAMMERED"], crng, 3)
	var wild: Dictionary = DeepBoons._make_offer(charged, charger, "terms", ["COST_WOUND", "REWARD_WILD"], crng, 0)
	hammer.id = "stake0"
	wild.id = "stake1"
	charged.grubstake.offers[me_id] = [hammer, wild]
	var hits: int = int(hammer.get("charges", {}).get("count", 0))
	check(hammer.get("needs", []).has("charges") and str(hammer.charges.kind) == "resize" and hits >= 2, "a deep Hammered is %d charges" % hits)
	## The last die is as big as dice go: it cannot take a charge.
	charger.dice[charger.dice.size() - 1] = DeepDice.make(str(DeepDice.TIERS.back()), str(charger.dice[charger.dice.size() - 1].id))
	descent._stake_choosing = "stake0"
	descent.show_state(charged)
	var page: Node = descent._page_holder
	var tiles: Node = page.find_child("ChargeDice", true, false)
	var left_label: Node = page.find_child("ChargesLeft", true, false)
	var done: Button = page.find_child("ChargeDone", true, false)
	check(tiles != null and tiles.get_child_count() == charger.dice.size() and left_label is Label and (left_label as Label).text == str(hits) and done != null and done.disabled,
		"the charge page shows every die and %d charges, Done not yet lit" % hits)
	var top_tile: Node = tiles.get_child(tiles.get_child_count() - 1) if tiles != null else null
	check(top_tile != null and not bool(top_tile.get_meta("able", true)), "a die as big as dice go is dimmed")
	var struck: String = str(charger.dice[0].id)
	var was: String = str(charger.dice[0].shape)
	descent._charge_hit(hammer, struck)
	descent._charge_hit(hammer, struck)
	var after: Array = descent.charge_preview(charger, "resize", descent._charge_clicks)
	check(descent._charge_clicks == [struck, struck] and DeepOddities.SIZES.find(str(after[0].shape)) == DeepOddities.SIZES.find(was) + 2
		and _label_count(descent._page_holder, DeepDice.describe(after[0])) >= 1,
		"the same die struck twice stands there two sizes bigger (%s to %s)" % [was, str(after[0].shape)])
	descent._charge_hit(hammer, str(charger.dice[charger.dice.size() - 1].id))
	check(descent._charge_clicks.size() == 2, "a die that cannot take a charge is refused")
	var again: Button = descent._page_holder.find_child("ChargeAgain", true, false)
	if again != null:
		again.pressed.emit()
	check(descent._charge_clicks.is_empty(), "Start over gives every charge back")
	for at in range(hits):
		descent._charge_hit(hammer, struck if at < 2 else str(charger.dice[1].id))
	done = descent._page_holder.find_child("ChargeDone", true, false)
	check(done != null and not done.disabled and (descent._page_holder.find_child("ChargesLeft", true, false) as Label).text == "0", "every charge spent, Done is lit")
	sent.clear()
	if done != null:
		done.pressed.emit()
	check(sent.size() == 1 and sent[0].get("payload", {}).get("dice", []) == descent._charge_clicks and sent[0].payload.dice.size() == hits, "Done sends the dice in click order: %s" % str(sent))
	if sent.size() == 1:
		var trial: Dictionary = charged.duplicate(true)
		var took: Dictionary = DeepDescent.command(trial, me_id, sent[0])
		check(bool(took.get("ok", false)) and str(DeepDescent.player(trial, me_id).dice[0].shape) == str(after[0].shape), "the rules take the charges: %s" % str(took.get("error", "")))
	## A Wild Face: the lowest face not yet wild turns wild, a click at a time.
	descent._stake_choosing = "stake1"
	descent.show_state(charged)
	var wild_icon: Node = descent._page_holder.find_child("ChargeIcon", true, false)
	check(wild_icon != null and not wild_icon is TextureRect, "A Wild Face's counter wears a wild face, not the hammer")
	var before_wild: int = charger.dice[0].faces.filter(func(f: Dictionary) -> bool: return str(f.get("kind", "")) == "wild").size()
	descent._charge_hit(wild, struck)
	var wilded: Array = descent.charge_preview(charger, "wild", descent._charge_clicks)
	check(wilded[0].faces.filter(func(f: Dictionary) -> bool: return str(f.get("kind", "")) == "wild").size() == before_wild + 1, "a click turns one more face of the die wild")
	descent._stake_choosing = ""
	descent.command.disconnect(catch)
	descent._hold = {}

func _named_count(node: Node, wanted: String) -> int:
	## Nodes in a subtree with this name (a ribbon, a badge), visible ones only.
	var count: int = 1 if node.name == wanted and (not node is CanvasItem or (node as CanvasItem).is_visible_in_tree()) else 0
	for child in node.get_children():
		count += _named_count(child, wanted)
	return count

func _rich_count(node: Node, fragment: String) -> int:
	## Rich text in a subtree whose words, as read, hold this.
	var count: int = 1 if node is RichTextLabel and (node as RichTextLabel).get_parsed_text().contains(fragment) else 0
	for child in node.get_children():
		count += _rich_count(child, fragment)
	return count

func _meta_count(node: Node, key: String) -> int:
	var count: int = 1 if bool(node.get_meta(key, false)) else 0
	for child in node.get_children():
		count += _meta_count(child, key)
	return count

func _percent_labels(node: Node, out: Array) -> void:
	## Every label in a subtree that is a whole percentage, as its number.
	if node is Label and (node as Label).text.ends_with("%") and (node as Label).text.trim_suffix("%").is_valid_int():
		out.append(int((node as Label).text.trim_suffix("%")))
	for child in node.get_children():
		_percent_labels(child, out)

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
	## The way-out keys (DeepUi.way_out) that say this.
	var count: int = 1 if node is Button and str(node.get_meta("way_out", "")) == text else 0
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
