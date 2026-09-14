class_name RunEngine
extends RefCounted
## The one authoritative command boundary, shared by offline and network play.
## All random generation and settlement happen here, before presentation sees a snapshot.

const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const SaveStore = preload("res://scripts/services/save_store.gd")
const RULES_VERSION = "1.0.0"
const CONTENT_VERSION = "1.0.0"
const PROTOCOL_VERSION = 1
const SHAPES = ["D4", "D6", "D8", "D10", "D12", "D20"]
const ROOM_NAMES = {"battle":"Battle", "elite":"Elite Battle", "boss":"Boss", "shop":"Gem Merchant", "rest":"Camp", "workshop":"Workshop", "lapidary":"Lapidary", "mine":"The Mine", "event":"A Chance Encounter", "wager":"The Wager Hall", "crucible":"The Crucible"}
const ROOM_WEIGHTS = {"battle":3, "elite":1, "shop":2, "rest":1, "workshop":1, "lapidary":1, "mine":1, "event":1, "wager":1, "crucible":1}
## The Wager Hall teaches the one skill the whole run rests on — reading five dice — and
## charges gold for the lesson. Stakes are fixed tiers rather than free entry, so the most
## a visit can move is bounded by the table and not by the hero's purse.
const WAGER_STAKES = [4, 8, 12]
## The house deals its own five matched dice rather than the hero's. A pattern is far
## rarer on a d10 than on a d6, so betting a hero's own dice would quietly tax every
## party that had upgraded them, and the Workshop exists to upgrade them. House dice make
## one table that is the same wager for everyone, and let the paytable below be tuned.
const WAGER_DIE = "D6"
const WAGER_DICE_COUNT = 5
## Best pattern first: the hand is tested top to bottom and paid for the first that fits.
## Multipliers are of the stake and include it, so 1 is the stake returned and 0 is a loss.
## Measured over the house dice, a player who never rerolls returns about 0.39 per gold
## staked, one who keeps the largest group about 0.74, and one who also chases a straight
## about 0.99. The room is therefore a losing bet played badly and a fair one played well,
## which is the point: the skill it rewards is the skill the fights ask for.
const WAGER_TABLE = [
	{"key":"five", "name":"Five of a kind", "multiplier":10},
	{"key":"straight5", "name":"Five-die straight", "multiplier":4},
	{"key":"four", "name":"Four of a kind", "multiplier":3},
	{"key":"full_house", "name":"Full house", "multiplier":2},
	{"key":"straight4", "name":"Four-die straight", "multiplier":1},
	{"key":"three", "name":"Three of a kind", "multiplier":0},
	{"key":"two_pair", "name":"Two pair", "multiplier":0},
	{"key":"pair", "name":"One pair", "multiplier":0},
	{"key":"nothing", "name":"No pattern", "multiplier":0}]
## The Crucible is the only place Carat moves. Cut and Clarity have the Lapidary; Carat,
## the overall multiplier, was otherwise fixed at the moment a gem was found.
const CRUCIBLE_CARAT_GAIN = 2
## What a consumed gem gives the gem that survives it, on top of the base gain.
const CRUCIBLE_FUSE_DIVISOR = 4

signal changed(snapshot: Dictionary)
var state: Dictionary = {}
var command_history: Dictionary = {}
var streams: Dictionary = {}
var autosave: bool = true
var save_store = SaveStore.new()
var _sequences: Dictionary = {}
var _events: Array = []

func _init() -> void:
	save_store.content_validator = func(snapshot: Dictionary) -> Dictionary:
		var error: String = validate_state(snapshot)
		return {"ok":error.is_empty(), "error":error}

func new_run(config: Dictionary = {}) -> Dictionary:
	var content_errors: Array = Catalog.validate_content()
	if not content_errors.is_empty():
		return {"ok":false, "error":"Content validation failed: " + str(content_errors)}
	var seats: Array = config.get("heroes", config.get("players", [{"id":"p1", "hero_id":"ARDOR", "name":"Adventurer"}]))
	if seats.is_empty() or seats.size() > 4:
		return {"ok":false, "error":"A party needs one to four heroes."}
	var profile: String = str(config.get("profile", "short_9"))
	if profile not in ["short_9", "expedition_18"]:
		return {"ok":false, "error":"Unknown run profile."}
	var seed_input: String = str(config.get("seed", "")).strip_edges()
	var seed_value: int = int(seed_input) if seed_input.is_valid_int() else int(seed_input.hash())
	if seed_input.is_empty(): seed_value = int(Time.get_unix_time_from_system())
	autosave = bool(config.get("autosave", true))
	command_history.clear()
	_sequences.clear()
	streams.clear()
	for key in ["rooms", "encounters", "dice", "loot"]:
		var generator := RandomNumberGenerator.new()
		generator.seed = seed_value ^ int(key.hash())
		streams[key] = generator
	state = {"schema_version":1, "rules_version":RULES_VERSION, "content_version":CONTENT_VERSION,
		"protocol_version":PROTOCOL_VERSION, "run_id":str(config.get("run_id", "run-%s-%s" % [seed_value, Time.get_ticks_usec()])),
		"session_id":str(config.get("session_id", "offline-%s" % seed_value)), "host_epoch":int(config.get("host_epoch", 1)),
		"host_id":str(config.get("host_id", seats[0].get("id", "p1"))), "profile":profile, "seed":str(seed_value),
		"revision":0, "phase_id":0, "phase":"route", "room_index":1, "act":1, "turn":0, "accepted_sequences":{},
		"party_size":seats.size(), "heroes":[], "enemies":[], "room":{}, "offers":[], "votes":{},
		"reward_offers":{}, "shop":{}, "mine":{}, "event":{}, "log":[], "last_events":[], "history":[],
		"settled_rooms":[], "claimed_rewards":[], "mine_visits":0, "coin_rotation":0, "next_id":0,
		"last_room_kind":"", "shops_seen":[], "outcome":"", "battle_outcome":"", "paused":false,
		"statistics":{"turns":0, "battles":0, "rerolls":0, "gold_earned":0, "gold_spent":0, "rooms":0, "activations":{}, "gem_checks":{}, "hp_lost":0, "healing":0, "damage_dealt":0, "offered_rooms":{}, "chosen_rooms":{}}}
	var ids: Array = []
	for i in seats.size():
		var seat: Dictionary = seats[i]
		var id: String = str(seat.get("id", "p%s" % (i + 1)))
		var hero_key: String = str(seat.get("hero_id", seat.get("key", "ARDOR"))).to_upper()
		if id in ids or id.is_empty() or not Catalog.HEROES.has(hero_key):
			state = {}
			return {"ok":false, "error":"Invalid hero or duplicate player identity."}
		ids.append(id)
		var hero: Dictionary = Catalog.hero(hero_key, id, i)
		hero["player_name"] = str(seat.get("name", hero.get("name", hero_key))).left(32)
		hero["connected"] = true
		hero["fallback"] = false
		hero["reserve_dice"] = []
		hero["tinker_used_acts"] = []
		state.heroes.append(hero)
	if state.host_id not in ids:
		state.host_id = ids[0]
	_events = []
	_route_offers()
	_record("run_started", "The expedition begins. One hand powers every equipped gem.")
	_finish_events()
	var saved: Dictionary = _checkpoint()
	if not saved.get("ok", false):
		return saved
	changed.emit(state)
	return state

func make_envelope(player_id: String, command_type: String, payload: Dictionary = {}) -> Dictionary:
	_sequences[player_id] = maxi(int(_sequences.get(player_id, 0)), int(state.get("accepted_sequences", {}).get(player_id, 0))) + 1
	return {"protocol_version":PROTOCOL_VERSION, "run_id":state.get("run_id", ""),
		"session_id":state.get("session_id", ""), "host_epoch":state.get("host_epoch", 1),
		"command_id":"%s-%s-%s" % [player_id, Time.get_ticks_usec(), _sequences[player_id]],
		"player_sequence":_sequences[player_id], "phase_id":state.get("phase_id", 0),
		"base_revision":state.get("revision", 0), "command_type":command_type, "payload":payload}

func execute(player_id: String, envelope: Dictionary) -> Dictionary:
	if state.is_empty():
		return _rejection("There is no active run.")
	var player: Dictionary = _hero(player_id)
	if player.is_empty():
		return _rejection("Sender does not own a party seat.")
	if not envelope.get("command_id", null) is String:
		return _rejection("Invalid command ID.")
	var command_id: String = envelope.command_id
	if command_id.is_empty() or command_id.length() > 128:
		return _rejection("Invalid command ID.")
	var identity_error: String = _validate_identity(envelope)
	if not identity_error.is_empty(): return _rejection(identity_error)
	var cache_key: String = "%s/%s/%s" % [envelope.get("session_id", ""), player_id, command_id]
	if command_history.has(cache_key):
		var cached: Dictionary = command_history[cache_key].duplicate(true)
		cached.erase("request")
		cached.erase("player_id")
		cached["duplicate"] = true
		cached["state"] = state
		return cached
	var error: String = _validate_envelope(envelope)
	if not error.is_empty():
		return _rejection(error)
	if int(envelope.get("player_sequence", 0)) <= int(state.get("accepted_sequences", {}).get(player_id, 0)):
		return _rejection("This player command sequence has already been committed.")
	var command_type: String = str(envelope.get("command_type", envelope.get("type", "")))
	if state.paused and command_type != "ResumeDisconnected":
		return _rejection("Planning is paused for a disconnected hero. The host can resume after the reconnect grace period.")
	if not player.get("connected", true) or player.get("fallback", false):
		return _rejection("This controller is disconnected.")
	var prior_state: Dictionary = state.duplicate(true)
	var prior_rng: Dictionary = _rng_snapshot()
	var prior_history: Dictionary = command_history.duplicate(true)
	_events = []
	error = _dispatch(player, command_type, envelope.get("payload", {}))
	if not error.is_empty():
		state = prior_state
		_restore_rng(prior_rng)
		_events.clear()
		var rejected: Dictionary = {"ok":false, "error":error, "revision":state.revision, "command_id":command_id, "player_id":player_id, "request":envelope.duplicate(true)}
		command_history[cache_key] = rejected
		_trim_command_history()
		var rejected_save: Dictionary = _checkpoint()
		if not rejected_save.get("ok", false): command_history = prior_history
		return _rejection(error)
	_auto_fallback()
	state.accepted_sequences[player_id] = int(envelope.player_sequence)
	state.revision += 1
	_finish_events()
	var result: Dictionary = {"ok":true, "error":"", "revision":state.revision, "command_id":command_id}
	command_history[cache_key] = result.duplicate(true)
	command_history[cache_key]["request"] = envelope.duplicate(true)
	command_history[cache_key]["player_id"] = player_id
	_trim_command_history()
	var saved: Dictionary = _checkpoint()
	if not saved.get("ok", false):
		state = prior_state
		command_history = prior_history
		_restore_rng(prior_rng)
		return _rejection("The checkpoint could not be saved: " + str(saved.get("error", "disk error")))
	result["state"] = state
	result["events"] = _events.duplicate(true)
	changed.emit(state)
	return result

func _trim_command_history() -> void:
	while command_history.size() > 4096:
		command_history.erase(command_history.keys()[0])

func _validate_identity(envelope: Dictionary) -> String:
	if _integer(envelope, "protocol_version", 0, 1000) != PROTOCOL_VERSION:
		return "Incompatible protocol version."
	if not envelope.get("run_id", null) is String or not envelope.get("session_id", null) is String:
		return "Invalid run or session identity."
	if envelope.run_id != state.run_id or envelope.session_id != state.session_id:
		return "This command belongs to an earlier run or session."
	if _integer(envelope, "host_epoch", 0, 2147483647) != int(state.host_epoch):
		return "The command names an old host authority."
	return ""

func _validate_envelope(envelope: Dictionary) -> String:
	for field in ["protocol_version", "host_epoch", "phase_id", "player_sequence", "base_revision"]:
		if _integer(envelope, field, 0, 2147483647) < 0:
			return "Invalid numeric command field: " + field
	if int(envelope.get("protocol_version", -1)) != PROTOCOL_VERSION:
		return "Incompatible protocol version."
	if str(envelope.get("run_id", "")) != state.run_id or str(envelope.get("session_id", "")) != state.session_id:
		return "This command belongs to an earlier run or session."
	if int(envelope.get("host_epoch", -1)) != int(state.host_epoch):
		return "The command names an old host authority."
	if int(envelope.get("phase_id", -1)) != int(state.phase_id):
		return "The phase has changed; refresh the current state."
	if not envelope.get("payload", {}) is Dictionary or JSON.stringify(envelope).length() > 32768:
		return "Malformed or oversized command."
	if int(envelope.get("base_revision", -1)) > int(state.revision):
		return "The command refers to a future revision."
	return ""

func _dispatch(player: Dictionary, kind: String, payload: Dictionary) -> String:
	var strings: Array = []
	match kind:
		"SetReady":
			if not payload.get("ready", null) is bool: return "Ready must be true or false."
		"RerollDice":
			if not payload.get("die_ids", null) is Array: return "Die IDs must be a list."
		"UseHeroTrait": strings = ["die_id"]
		"SetPreferredTarget": strings = ["unit_id"]
		"VoteRoom", "BuyGem", "BuyDie": strings = ["offer_id"]
		"VoteVein": strings = ["vein"]
		"SellGem", "EquipGem": strings = ["gem_id"]
		"SellDie": strings = ["die_id"]
		"SwapDie": strings = ["active_id", "reserve_id"]
		"EquipRelic": strings = ["relic_id"]
		"ModifyDie": strings = ["die_id", "service"]
		"UpgradeGem": strings = ["gem_id", "property"]
		"ChooseReward": strings = ["kind", "offer_id"]
		"DraftGem": strings = ["claim_id"]
		"EventChoice": strings = ["option"]
		"WagerReroll":
			if not payload.get("die_ids", null) is Array: return "Die IDs must be a list."
		"TemperGem": strings = ["gem_id", "method"]
		"ResumeDisconnected": strings = ["player_id"]
	for key in strings:
		if not payload.get(key, null) is String or payload[key].length() > 256: return "Invalid command field: " + key
	match kind:
		"RerollDice", "UseHeroTrait": return _reroll(player, payload, kind == "UseHeroTrait")
		"SetPreferredTarget": return _target(player, payload)
		"SetReady": return _ready(player, bool(payload.get("ready", true)))
		"VoteRoom": return _vote_room(player, str(payload.get("offer_id", "")))
		"VoteVein": return _vote_vein(player, str(payload.get("vein", "")))
		"BuyGem", "BuyDie": return _buy(player, str(payload.get("offer_id", "")), kind == "BuyDie")
		"SellGem", "SellDie": return _sell(player, payload, kind == "SellDie")
		"EquipGem": return _equip_gem(player, payload)
		"ReorderGems": return _reorder(player, payload.get("gem_ids", []))
		"SwapDie": return _swap_die(player, payload)
		"EquipRelic": return _equip_relic(player, payload)
		"ModifyDie": return _modify_die(player, payload)
		"UpgradeGem": return _upgrade_gem(player, payload)
		"ChooseReward": return _choose_reward(player, payload)
		"DraftGem": return _draft(player, str(payload.get("claim_id", "")))
		"EventChoice": return _event_choice(player, payload)
		"PlaceWager": return _place_wager(player, payload)
		"WagerReroll": return _wager_reroll(player, payload)
		"SettleWager": return _settle_wager(player)
		"TemperGem": return _temper_gem(player, payload)
		"ResumeDisconnected": return _resume_disconnected(player, str(payload.get("player_id", "")))
		_: return "Unknown command: " + kind

func _reroll(player: Dictionary, payload: Dictionary, use_trait: bool) -> String:
	if state.phase != "planning" or player.hp <= 0 or player.ready:
		return "Rerolls require a living, unlocked hero during planning."
	var die_ids = [payload.get("die_id", "")] if use_trait else payload.get("die_ids", [])
	if not die_ids is Array or die_ids.is_empty() or die_ids.size() > 5:
		return "Select at least one of your five dice."
	if use_trait and (str(player.get("trait", "")) != "SECOND_THOUGHT" or int(player.get("trait_charges", 0)) < 1):
		return "Second Thought is unavailable."
	if not use_trait and int(player.rerolls) < 1:
		return "No normal rerolls remain this turn."
	var unique: Array = []
	for id in die_ids:
		if not id is String or id in unique or _find(player.dice, id).is_empty():
			return "Reroll IDs must be a unique subset of your active dice."
		unique.append(id)
	for i in player.dice.size():
		if player.dice[i].id in unique:
			var count: int = int(player.hand[i].get("roll_count", 0)) + 1
			player.hand[i] = Combat.roll_die(player.dice[i], streams.dice, count)
	player["rerolled"] = true
	player["rerolled_this_turn"] = true
	if use_trait:
		player.trait_charges -= 1
	else:
		player.rerolls -= 1
	state.statistics.rerolls += 1
	_record("reroll", "%s rerolled %s %s." % [player.name, unique.size(), "die with Second Thought" if use_trait else "dice"], {"actor_id":player.id, "die_ids":unique})
	return ""

func _target(player: Dictionary, payload: Dictionary) -> String:
	## Only the hostile target is chosen. Friendly effects reach the whole party.
	if state.phase != "planning" or player.hp <= 0 or player.ready:
		return "Targets may be changed while your living hero is unlocked."
	var id: String = str(payload.get("unit_id", ""))
	if id.is_empty():
		player.preferred_target = ""
		return ""
	var target: Dictionary = _find(state.enemies, id)
	if target.is_empty():
		return "That target is not in this encounter."
	if target.hp <= 0:
		return "That target is already defeated."
	player.preferred_target = id
	return ""

func _ready(player: Dictionary, value: bool) -> String:
	if state.phase not in ["planning", "support", "reward"]:
		return "This phase uses a choice instead of Ready."
	if state.phase == "planning" and player.hp <= 0:
		return "Downed heroes do not need to lock in."
	if value and state.phase == "reward":
		var rewards: Dictionary = state.reward_offers.get(player.id, {})
		if not rewards.get("gem_done", true) or not rewards.get("relic_done", true):
			return "Choose or decline your outstanding rewards first."
	# A stake left on the table is paid out rather than forfeited, so leaving the room can
	# never be worse than settling. The house takes no rake on a player who walks away.
	if value and state.room.get("kind", "") == "wager":
		var seat: Dictionary = _wager_seat(player)
		if not seat.is_empty() and int(seat.stake) > 0 and not seat.settled: _settle_wager(player)
	player.ready = value
	_check_ready()
	return ""

func _check_ready() -> void:
	for hero in state.heroes:
		if hero.get("fallback", false) or not hero.get("connected", true):
			continue
		if state.phase == "planning" and hero.hp <= 0:
			continue
		if not hero.ready:
			return
	if state.phase == "planning":
		_resolve_battle()
	elif state.phase in ["support", "reward"]:
		_advance_room()

func _resolve_battle() -> void:
	state.statistics.turns += 1
	var events: Array = Combat.resolve_turn(state, streams.dice)
	_events.append_array(events)
	for event in events:
		event.merge({"run_id":state.run_id, "phase_id":state.phase_id, "turn":state.turn, "room_id":state.room.id})
		var event_kind: String = str(event.get("kind", event.get("type", "")))
		var actor: Dictionary = _hero(str(event.get("actor", event.get("actor_id", ""))))
		var target: Dictionary = _hero(str(event.get("target", event.get("target_id", ""))))
		if event_kind in ["skill", "inactive"] and not actor.is_empty():
			var key: String = str(event.get("skill", event.get("skill_id", "unknown")))
			_stat_bucket("gem_checks", key)
			if event_kind == "skill": _stat_bucket("activations", key)
		elif event_kind in ["damage", "poison_tick"]:
			if not target.is_empty(): _stat("hp_lost", int(event.get("hp_loss", 0)))
			elif not actor.is_empty(): _stat("damage_dealt", int(event.get("hp_loss", 0)))
		elif event_kind == "heal" and not target.is_empty(): _stat("healing", int(event.get("amount", 0)))
		elif event_kind == "gold" and event.get("source", "") == "combat_skill": _stat("gold_earned", int(event.get("amount", 0)))
	match state.get("battle_outcome", ""):
		"defeat": _end_run("defeat")
		"victory": _battle_rewards()
		_:
			_events.append_array(Combat.begin_turn(state, streams.dice))
			_phase("planning")

func _battle_rewards() -> void:
	if state.room.id in state.settled_rooms:
		return
	state.settled_rooms.append(state.room.id)
	state.statistics.battles += 1
	var kind: String = state.room.kind
	var final_boss: bool = kind == "boss" and (state.profile == "short_9" or state.act == 3)
	var gold: int = 10 + (int(state.act) - 1) * 5
	if kind == "elite": gold *= 2
	if kind == "boss": gold = (50 if state.act == 3 else 20 + int(state.act) * 10)
	state.reward_offers = {}
	for hero in state.heroes:
		var bonus: int = 3 if kind in ["battle", "elite"] and _has_relic(hero, "MERCHANT_SEAL") else 0
		_grant_gold(hero, gold + bonus, "room_reward")
		for relic in hero.relics:
			if relic.key == "LASTING_AEGIS" and relic.get("equipped", false):
				relic.stored_block = mini(6, int(hero.block)) if hero.hp > 0 else 0
		if hero.hp <= 0:
			hero.hp = ceili(float(hero.max_hp) / 10.0)
			_record("rally", "%s rallies to %s HP." % [hero.name, hero.hp], {"actor_id":hero.id})
		hero.block = 0
		hero.statuses = {"stun":0, "poison":0, "resolve":0}
		hero.hand = []
		hero.initial_hand = []
		hero.rerolled = false
		hero.ready = false
		var reward: Dictionary = {"gems":[], "relics":[], "gem_done":true, "relic_done":true}
		if kind in ["battle", "elite"]:
			reward.gems = _generate_gems(3, kind == "elite")
			reward.gem_done = reward.gems.is_empty()
		if kind == "elite" or (kind == "boss" and not final_boss):
			var owned: Array = []
			for relic in hero.relics: owned.append(relic.key)
			var eligible: Array = []
			for key in Catalog.eligible_relics(state.profile):
				if key not in owned: eligible.append(key)
			eligible.sort()
			for i in mini(2 if kind == "elite" else 3, eligible.size()):
				var index: int = streams.loot.randi_range(0, eligible.size() - 1)
				var relic_key: String = eligible.pop_at(index)
				reward.relics.append({"id":_id("relic"), "key":relic_key, "equipped":false, "stored_block":0})
			reward.relic_done = reward.relics.is_empty()
			if eligible.is_empty() and reward.relics.is_empty(): _grant_gold(hero, 5, "room_reward")
		state.reward_offers[hero.id] = reward
	_record("battle_victory", "Victory! Each hero receives %s gold and keeps their recovered spoils." % gold)
	if final_boss:
		_end_run("victory")
	else:
		_phase("reward")

func _choose_reward(player: Dictionary, payload: Dictionary) -> String:
	if state.phase != "reward" or player.ready:
		return "Rewards can be selected before marking Done."
	var reward: Dictionary = state.reward_offers.get(player.id, {})
	var kind: String = str(payload.get("kind", "gem"))
	if kind not in ["gem", "relic"] or reward.get(kind + "_done", true):
		return "That reward is already settled."
	var offer_id: String = str(payload.get("offer_id", ""))
	if offer_id.is_empty():
		if kind == "gem": _grant_gold(player, 3, "room_reward")
	else:
		var item: Dictionary = _find(reward.gems if kind == "gem" else reward.relics, offer_id)
		if item.is_empty() or offer_id in state.claimed_rewards:
			return "That reward offer is unavailable."
		state.claimed_rewards.append(offer_id)
		item = item.duplicate(true)
		item["equipped"] = false
		item["owner_id"] = player.id
		if kind == "gem": player.gems.append(item)
		else: player.relics.append(item)
		_record("reward", "%s claims %s." % [player.name, _item_name(item, kind)], {"actor_id":player.id, "item_id":item.id})
	reward[kind + "_done"] = true
	return ""

func _route_offers() -> void:
	var room_number: int = int(state.room_index)
	state.act = 1 if state.profile == "short_9" else floori(float(room_number - 1) / 6.0) + 1
	var local_room: int = (room_number - 1) % 6 + 1
	var required: String = ""
	if state.profile == "short_9":
		if room_number == 1: required = "battle"
		elif room_number == 4: required = "elite"
		elif room_number == 8: required = "rest"
		elif room_number == 9: required = "boss"
	else:
		if local_room == 1: required = "battle"
		elif local_room == 3: required = "elite"
		elif local_room == 5: required = "rest"
		elif local_room == 6: required = "boss"
	var choices: Array = []
	if not required.is_empty():
		choices.append(required)
	else:
		var pool: Array = ["battle", "elite", "shop", "rest", "workshop", "lapidary", "mine", "wager", "crucible"] if state.profile == "short_9" else ["battle", "shop", "rest", "workshop", "lapidary", "mine", "event", "wager", "crucible"]
		if state.last_room_kind not in ["battle", "elite", "boss"]:
			pool.erase(state.last_room_kind)
		choices.append(_weighted(["battle", "elite"], [3, 1], streams.rooms) if state.profile == "short_9" else "battle")
		pool.erase(choices[0])
		if state.profile == "expedition_18" and local_room == 4 and state.act not in state.shops_seen:
			choices.append("shop")
			pool.erase("shop")
		while choices.size() < 3 and not pool.is_empty():
			var weights: Array = []
			for key in pool: weights.append(ROOM_WEIGHTS[key])
			var chosen: String = _weighted(pool, weights, streams.rooms)
			choices.append(chosen)
			pool.erase(chosen)
	state.offers = []
	for kind in choices:
		_stat_bucket("offered_rooms", kind)
		state.offers.append({"id":_id("route"), "kind":kind, "name":ROOM_NAMES[kind], "description":_room_description(kind), "required":not required.is_empty()})
	state.votes = {}
	_phase("route")

func _room_description(kind: String) -> String:
	match kind:
		"battle": return "An authored encounter. Gold and a personal choice of three gems."
		"elite": return "A tougher encounter. Double gold, an improved gem, and a relic choice."
		"boss": return ["Face the Slime King: Slam, Fortify, Absorb.", "Face the Mirror Regent: Refraction and Shatter.", "Face the Rift Sovereign: High Tide and Low Tide."][mini(2, int(state.act)-1)]
		"shop": return "Three personal gems and a featured die. Buy or sell with gold."
		"rest":
			# Only heroes with something to gain are listed: "+0 HP" is not an offer.
			var recovery: PackedStringArray = []
			for hero in state.heroes:
				var amount: int = mini(int(hero.max_hp)-int(hero.hp), floori(float(hero.max_hp)/3.0))
				if amount > 0: recovery.append("%s +%s HP" % [hero.name, amount])
			if recovery.is_empty(): return "Nobody is hurt. The fire is still a quiet place to change your equipment."
			return "Free recovery: " + ", ".join(recovery) + ". Manage your equipment."
		"workshop": return "One service per hero: adjacent die shape or one engraved face. 5 gold."
		"lapidary": return "One Cut or Clarity increase per hero. Cut scales your rolls; Clarity is flat and eases triggers. Cost: 5 × the new rank."
		"mine": return "Choose a vein. 10 energy per living hero; pooled gold and a shared gem draft."
		"event": return "A personal choice of supplies, a trade, or a free exit."
		"wager": return "Stake gold on the house's five dice. One reroll, then the table pays the pattern. Best hand: %s at %d×." % [WAGER_TABLE[0].name.to_lower(), int(WAGER_TABLE[0].multiplier)]
		"crucible": return "Raise one gem's Carat by %d. Pay in HP, or consume a reserve gem to pay in Carat." % CRUCIBLE_CARAT_GAIN
	return ""

func _vote_room(player: Dictionary, offer_id: String) -> String:
	if state.phase != "route" or state.votes.has(player.id):
		return "Each hero may vote once on the current route."
	if _find(state.offers, offer_id).is_empty():
		return "That route is no longer offered."
	state.votes[player.id] = offer_id
	var choice: String = _vote_result()
	if not choice.is_empty(): _enter_room(_find(state.offers, choice).kind)
	return ""

func _vote_result() -> String:
	var counts: Dictionary = {}
	for hero in state.heroes:
		if hero.get("fallback", false) or not hero.get("connected", true): continue
		if not state.votes.has(hero.id): return ""
		var vote: String = state.votes[hero.id]
		counts[vote] = int(counts.get(vote, 0)) + 1
	if counts.is_empty(): return ""
	var highest: int = 0
	for count in counts.values(): highest = maxi(highest, count)
	var host_vote: String = state.votes.get(state.host_id, "")
	if int(counts.get(host_vote, 0)) == highest: return host_vote
	for hero in state.heroes:
		var vote: String = state.votes.get(hero.id, "")
		if int(counts.get(vote, 0)) == highest: return vote
	return ""

func _enter_room(kind: String) -> void:
	_stat_bucket("chosen_rooms", kind)
	state.room = {"id":_id("room"), "kind":kind, "name":ROOM_NAMES[kind], "services":{}, "recovery":{}}
	state.enemies = []
	state.shop = {}
	state.reward_offers = {}
	state.mine = {}
	state.event = {}
	state.votes = {}
	state.offers = []
	for hero in state.heroes:
		hero.ready = false
		state.room.services[hero.id] = false
	_record("room_entered", "Room %s · %s" % [state.room_index, ROOM_NAMES[kind]])
	match kind:
		"battle", "elite", "boss":
			state.enemies = Catalog.encounter(kind, state.act, state.party_size, state.room_index, state.profile)
			state.turn = 0
			state.battle_outcome = ""
			_events.append_array(Combat.begin_battle(state, streams.dice))
			_phase("planning")
		"rest":
			for hero in state.heroes:
				var amount: int = mini(int(hero.max_hp) - int(hero.hp), floori(float(hero.max_hp) / 3.0))
				hero.hp += amount
				state.room.recovery[hero.id] = amount
				_record("rest", "%s recovers %s HP." % [hero.name, amount], {"actor_id":hero.id, "amount":amount})
			_phase("support")
		"shop":
			if state.act not in state.shops_seen: state.shops_seen.append(state.act)
			for hero in state.heroes:
				var stock: Dictionary = {"gems":[], "dice":[]}
				for gem in _generate_gems(3):
					stock.gems.append({"id":_id("offer"), "gem":gem, "price":Catalog.gem_value(gem), "claimed":false})
				var die_keys: Array = ["PAIRED_D6", "ODD_D6", "EVEN_D6"]
				if state.act >= 2: die_keys.append_array(["SEVEN_D8", "SPLIT_D12"])
				elif state.profile == "short_9" and state.room_index > 4: die_keys.append("SEVEN_D8")
				if state.act == 3: die_keys.append("SPLIT_D20")
				var key: String = die_keys[streams.loot.randi_range(0, die_keys.size() - 1)]
				var die: Dictionary = Catalog.die(key, _id("die"))
				stock.dice.append({"id":_id("offer"), "die":die, "price":_die_value(die), "claimed":false})
				state.shop[hero.id] = stock
			_phase("support")
		"mine":
			state.mine = {"vein":"", "rocks":[], "events":[], "pool":[], "gold":0, "picker_id":"", "draft_index":0, "energy":{}}
			for hero in state.heroes: state.mine.energy[hero.id] = 0 if hero.hp <= 0 else 10 + (2 if _has_relic(hero, "MINERS_LANTERN") else 0)
			_phase("mine_vote")
		"event":
			var keys: Array = ["ABANDONED_CACHE", "FIELD_MEDIC", "ECHO_SHRINE", "JEWEL_BROKER"]
			state.event = {"key":keys[streams.rooms.randi_range(0, keys.size()-1)], "offers":{}}
			for hero in state.heroes:
				var gems: Array = _generate_gems(3 if state.event.key == "JEWEL_BROKER" else 1)
				if state.event.key == "ABANDONED_CACHE":
					for gem in gems: gem.carat = mini(24, int(gem.carat) + 2)
				state.event.offers[hero.id] = gems
			_phase("support")
		"wager":
			# Each hero has a private table. Nothing is rolled until a stake is placed, so a
			# hero who walks past the tables spends nothing and reveals nothing.
			state.room.wager = {}
			for hero in state.heroes:
				state.room.wager[hero.id] = {"stake":0, "dice":[], "hand":[], "rerolled":false, "settled":false, "payout":0, "pattern":""}
			_phase("support")
		"crucible":
			_phase("support")
		_:
			_phase("support")

func _buy(player: Dictionary, id: String, is_die: bool) -> String:
	var guard: String = _service_guard(player, "shop")
	if not guard.is_empty(): return guard
	var stock: Dictionary = state.shop.get(player.id, {})
	var offer: Dictionary = _find(stock.get("dice" if is_die else "gems", []), id)
	if offer.is_empty() or offer.get("claimed", true): return "This offer has already been claimed or belongs to another player."
	if player.gold < offer.price: return "Not enough gold."
	if is_die and player.reserve_dice.size() >= 5: return "Your five reserve die slots are full. Sell one first."
	_spend(player, offer.price)
	offer.claimed = true
	var item: Dictionary = offer["die" if is_die else "gem"].duplicate(true)
	item.owner_id = player.id
	if is_die: player.reserve_dice.append(item)
	else:
		item.equipped = false
		player.gems.append(item)
	_record("purchase", "%s buys %s for %s gold." % [player.name, _item_name(item, "die" if is_die else "gem"), offer.price])
	return ""

func _sell(player: Dictionary, payload: Dictionary, is_die: bool) -> String:
	var guard: String = _service_guard(player, "shop")
	if not guard.is_empty(): return guard
	var items: Array = player.reserve_dice if is_die else player.gems
	var item: Dictionary = _find(items, str(payload.get("die_id" if is_die else "gem_id", "")))
	if item.is_empty(): return "You can only sell an owned gem or reserve die."
	if not is_die and item.key == "STRIKE":
		if _count_key(player.gems, "STRIKE") <= 1 or item.get("equipped", false): return "Keep an equipped Strike and your last owned Strike. Equip its replacement first."
	var value: int = floori(float(_die_value(item) if is_die else Catalog.gem_value(item)) / 2.0)
	items.erase(item)
	_grant_gold(player, value, "sale")
	_record("sale", "%s sells %s for %s gold." % [player.name, _item_name(item, "die" if is_die else "gem"), value])
	return ""

func _build_guard(player: Dictionary) -> String:
	if state.phase not in ["route", "support", "reward", "mine_vote", "mine_draft"]: return "Equipment is frozen during combat."
	if player.ready: return "Unready before changing your equipment."
	return ""

func _equip_gem(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _build_guard(player)
	if not guard.is_empty(): return guard
	var gem: Dictionary = _find(player.gems, str(payload.get("gem_id", "")))
	if gem.is_empty(): return "You do not own that gem."
	var replace: Dictionary = _find(player.gems, str(payload.get("replace_id", "")))
	if gem.get("equipped", false):
		if gem.key == "STRIKE": return "Strike must remain equipped. Select a reserve Strike to replace it."
		gem.equipped = false
		return ""
	if not replace.is_empty() and not replace.get("equipped", false): return "The replaced gem must be equipped."
	for other in player.gems:
		if other.get("equipped", false) and other.key == gem.key and replace.is_empty(): replace = other
	if not replace.is_empty():
		if replace.key == "STRIKE" and gem.key != "STRIKE": return "An equipped Strike is required."
		replace.equipped = false
	if _equipped_count(player.gems) >= 6: return "Six gem slots are full. Choose a gem to replace or unequip one."
	if _equipped_skill(player, gem.key): return "Only one copy of each skill may be equipped."
	gem.equipped = true
	if not replace.is_empty():
		var old_index: int = player.gems.find(replace)
		player.gems.erase(gem)
		player.gems.insert(mini(old_index, player.gems.size()), gem)
	return ""

func _reorder(player: Dictionary, ids: Variant) -> String:
	var guard: String = _build_guard(player)
	if not guard.is_empty(): return guard
	if not ids is Array or ids.size() != _equipped_count(player.gems): return "Supply all equipped gem IDs exactly once."
	var ordered: Array = []
	for id in ids:
		var gem: Dictionary = _find(player.gems, str(id))
		if gem.is_empty() or not gem.get("equipped", false) or gem in ordered: return "Invalid or duplicate equipped gem ID."
		ordered.append(gem)
	for gem in player.gems:
		if not gem.get("equipped", false): ordered.append(gem)
	player.gems = ordered
	return ""

func _swap_die(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _build_guard(player)
	if not guard.is_empty(): return guard
	var active: Dictionary = _find(player.dice, str(payload.get("active_id", "")))
	var reserve: Dictionary = _find(player.reserve_dice, str(payload.get("reserve_id", "")))
	if active.is_empty() or reserve.is_empty(): return "Choose one active and one reserve die."
	var index: int = player.dice.find(active)
	var reserve_index: int = player.reserve_dice.find(reserve)
	player.dice[index] = reserve
	player.reserve_dice[reserve_index] = active
	return ""

func _equip_relic(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _build_guard(player)
	if not guard.is_empty(): return guard
	var relic: Dictionary = _find(player.relics, str(payload.get("relic_id", "")))
	if relic.is_empty(): return "You do not own that relic."
	if relic.get("equipped", false):
		relic.equipped = false
		if relic.key == "LASTING_AEGIS": relic.stored_block = 0
		return ""
	var replace: Dictionary = _find(player.relics, str(payload.get("replace_id", "")))
	if not replace.is_empty() and replace.get("equipped", false):
		replace.equipped = false
		if replace.key == "LASTING_AEGIS": replace.stored_block = 0
	if _equipped_count(player.relics) >= 3: return "Three relic slots are full. Unequip or replace one."
	if _has_relic(player, relic.key): return "Only one copy of each relic may be equipped."
	relic.equipped = true
	return ""

func _service_guard(player: Dictionary, kind: String, limited: bool = false) -> String:
	if state.phase != "support" or state.room.get("kind", "") != kind: return "This service is not available in the current room."
	if player.ready: return "Unready before using this room."
	if limited and state.room.services.get(player.id, false): return "Your one service for this visit is already used."
	return ""

func _modify_die(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _service_guard(player, "workshop", true)
	if not guard.is_empty(): return guard
	var die: Dictionary = _find(player.dice + player.reserve_dice, str(payload.get("die_id", "")))
	if die.is_empty(): return "You do not own that die."
	var free: bool = _has_relic(player, "TINKERS_BELT") and state.act not in player.tinker_used_acts
	if not free and player.gold < 5: return "A Workshop service costs 5 gold."
	var service: String = str(payload.get("service", "shape"))
	if service == "shape":
		var shape: String = str(payload.get("shape", ""))
		if shape not in SHAPES or absi(SHAPES.find(shape) - SHAPES.find(str(die.shape))) != 1: return "Choose the adjacent standard shape in either direction."
		var replacement: Dictionary = Catalog.die(shape, die.id)
		replacement.owner_id = player.id
		die.merge(replacement, true)
		die.erase("engraved")
	elif service == "face":
		var face_index: int = _integer(payload, "face_index", 0, die.faces.size()-1)
		var value: int = _integer(payload, "value", 1, int(str(die.shape).trim_prefix("D")))
		if face_index < 0 or value < 0: return "Choose a face and a whole value within this die's side count."
		die.faces[face_index].value = value
		die["engraved"] = true
	else: return "Unknown Workshop service."
	if free: player.tinker_used_acts.append(state.act)
	else: _spend(player, 5)
	state.room.services[player.id] = true
	_record("workshop", "%s modifies a die%s." % [player.name, " with Tinker's Belt" if free else " for 5 gold"])
	return ""

func _upgrade_gem(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _service_guard(player, "lapidary", true)
	if not guard.is_empty(): return guard
	var gem: Dictionary = _find(player.gems, str(payload.get("gem_id", "")))
	var property: String = str(payload.get("property", ""))
	if gem.is_empty() or property not in ["cut", "clarity"]: return "Select an owned gem and Cut or Clarity."
	var rank: int = int(gem.get(property, 1))
	if rank >= 5: return "That property is already rank 5."
	var cost: int = (rank + 1) * 5
	if player.gold < cost: return "This upgrade costs %s gold." % cost
	_spend(player, cost)
	gem[property] = rank + 1
	state.room.services[player.id] = true
	_record("lapidary", "%s improves %s %s to %s." % [player.name, _item_name(gem, "gem"), property, rank+1])
	return ""

func _event_choice(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _service_guard(player, "event", true)
	if not guard.is_empty(): return guard
	var option: String = str(payload.get("option", "leave"))
	if option not in ["a", "b", "leave"]: return "Choose one of the displayed event options."
	var key: String = state.event.key
	if option == "a":
		_grant_gold(player, {"ABANDONED_CACHE":6, "FIELD_MEDIC":4, "ECHO_SHRINE":5, "JEWEL_BROKER":4}[key], "event")
	elif option == "b":
		match key:
			"ABANDONED_CACHE":
				if player.hp <= 8: return "Opening the trapped cache requires more than 8 HP."
				player.hp -= 8
				var gem: Dictionary = state.event.offers[player.id][0].duplicate(true)
				gem.equipped = false
				gem.owner_id = player.id
				player.gems.append(gem)
			"FIELD_MEDIC":
				if player.gold < 8: return "The medic's supplies cost 8 gold."
				_spend(player, 8)
				player.hp = mini(player.max_hp, player.hp + ceili(float(player.max_hp) / 5.0))
			"ECHO_SHRINE":
				var die: Dictionary = _find(player.dice + player.reserve_dice, str(payload.get("die_id", "")))
				var variant: String = str(payload.get("variant", ""))
				if die.is_empty() or str(die.shape) != "D6" or variant not in ["PAIRED_D6", "ODD_D6", "EVEN_D6"]: return "Choose an owned D6 and Paired, Odd, or Even faces."
				die.merge(Catalog.die(variant, die.id), true)
				die.erase("engraved")
			"JEWEL_BROKER":
				var gem: Dictionary = _find(player.gems, str(payload.get("gem_id", "")))
				var offer: Dictionary = _find(state.event.offers[player.id], str(payload.get("offer_id", "")))
				if gem.is_empty() or gem.get("equipped", false) or offer.is_empty(): return "Choose a reserve gem to exchange and a displayed offer."
				if gem.key == "STRIKE" and _count_key(player.gems, "STRIKE") <= 1: return "Your last Strike cannot be traded."
				player.gems.erase(gem)
				var acquired: Dictionary = offer.duplicate(true)
				acquired.equipped = false
				acquired.owner_id = player.id
				player.gems.append(acquired)
	state.room.services[player.id] = true
	_record("event", "%s chooses %s at %s." % [player.name, option, key.to_lower().replace("_", " ")])
	return ""

## --- The Wager Hall -----------------------------------------------------------
## The room reads a hand the way every gem does, so the skill it charges for is the skill
## the rest of the run already asks for: keep what pays, throw what does not.

static func wager_pattern(values: Array) -> String:
	## Names the best pattern in a set of die values. Pure, so the table, the preview and
	## the settlement all read the same hand the same way.
	var groups: Dictionary = {}
	for value in values:
		groups[int(value)] = int(groups.get(int(value), 0)) + 1
	var sizes: Array = groups.values()
	sizes.sort()
	sizes.reverse()
	var largest: int = int(sizes[0]) if not sizes.is_empty() else 0
	var pairs: int = 0
	for size in sizes:
		if int(size) >= 2: pairs += 1
	var distinct: Array = groups.keys()
	distinct.sort()
	var run: int = 1
	var longest: int = 1 if not distinct.is_empty() else 0
	for i in range(1, distinct.size()):
		run = run + 1 if int(distinct[i]) == int(distinct[i - 1]) + 1 else 1
		longest = maxi(longest, run)
	if largest >= 5: return "five"
	if longest >= 5: return "straight5"
	if largest == 4: return "four"
	if largest == 3 and pairs >= 2: return "full_house"
	if longest >= 4: return "straight4"
	if largest == 3: return "three"
	if pairs >= 2: return "two_pair"
	if largest == 2: return "pair"
	return "nothing"

static func wager_entry(pattern: String) -> Dictionary:
	for row in WAGER_TABLE:
		if row.key == pattern: return row
	return WAGER_TABLE[-1]

func _wager_seat(player: Dictionary) -> Dictionary:
	return state.room.get("wager", {}).get(player.id, {})

func _place_wager(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _service_guard(player, "wager", true)
	if not guard.is_empty(): return guard
	var seat: Dictionary = _wager_seat(player)
	if seat.is_empty(): return "You have no seat at this table."
	if int(seat.stake) > 0: return "Your stake for this visit is already on the table."
	var stake: int = _integer(payload, "stake", 1, WAGER_STAKES[-1])
	if stake not in WAGER_STAKES: return "The table takes stakes of %s gold." % ", ".join(PackedStringArray(WAGER_STAKES.map(func(value: int) -> String: return str(value))))
	if int(player.gold) < stake: return "You cannot cover that stake."
	_spend(player, stake)
	seat.stake = stake
	seat.dice = []
	seat.hand = []
	for i in WAGER_DICE_COUNT:
		var die: Dictionary = Catalog.die(WAGER_DIE, _id("house"))
		die.owner_id = player.id
		seat.dice.append(die)
		seat.hand.append(Combat.roll_die(die, streams.dice))
	_record("wager", "%s stakes %s gold and rolls %s." % [player.name, stake, ", ".join(PackedStringArray(Combat.values(seat.hand).map(func(value: int) -> String: return str(value))))], {"actor_id":player.id, "amount":stake})
	return ""

func _wager_reroll(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _service_guard(player, "wager", true)
	if not guard.is_empty(): return guard
	var seat: Dictionary = _wager_seat(player)
	if seat.is_empty() or int(seat.stake) <= 0: return "Place a stake before rolling."
	if seat.rerolled: return "The table allows one reroll per stake."
	var die_ids = payload.get("die_ids", [])
	if not die_ids is Array or die_ids.is_empty() or die_ids.size() > seat.hand.size():
		return "Select at least one of your staked dice."
	var seen: Array = []
	for id in die_ids:
		if not id is String or id in seen: return "Select each die at most once."
		seen.append(id)
	for index in range(seat.hand.size()):
		var roll: Dictionary = seat.hand[index]
		if str(roll.get("die_id", "")) not in seen: continue
		var die: Dictionary = _find(seat.dice, str(roll.get("die_id", "")))
		if die.is_empty(): return "That die is not on the table."
		seat.hand[index] = Combat.roll_die(die, streams.dice)
	seat.rerolled = true
	_record("wager", "%s rerolls %s dice." % [player.name, seen.size()], {"actor_id":player.id})
	return ""

func _settle_wager(player: Dictionary) -> String:
	var guard: String = _service_guard(player, "wager", true)
	if not guard.is_empty(): return guard
	var seat: Dictionary = _wager_seat(player)
	if seat.is_empty() or int(seat.stake) <= 0: return "Place a stake before settling."
	var pattern: String = wager_pattern(Combat.values(seat.hand))
	var entry: Dictionary = wager_entry(pattern)
	var payout: int = int(seat.stake) * int(entry.multiplier)
	seat.pattern = pattern
	seat.payout = payout
	seat.settled = true
	if payout > 0: _grant_gold(player, payout, "wager")
	state.room.services[player.id] = true
	_record("wager", "%s shows %s and takes %s gold." % [player.name, str(entry.name).to_lower(), payout], {"actor_id":player.id, "amount":payout})
	return ""

## --- The Crucible -------------------------------------------------------------
## Cut and Clarity are bought at the Lapidary. Carat, the multiplier over the whole gem,
## had no path at all once a gem was found; this is it, and it is paid for in the two
## things a party cannot simply earn more of on the spot: its health and its other gems.

func _crucible_hp_cost(gem: Dictionary) -> int:
	## Dearer the stronger the gem already is, so the room does not simply favour the best.
	return 4 + floori(float(int(gem.get("carat", 1))) / 2.0)

func _temper_gem(player: Dictionary, payload: Dictionary) -> String:
	var guard: String = _service_guard(player, "crucible", true)
	if not guard.is_empty(): return guard
	var gem: Dictionary = _find(player.gems, str(payload.get("gem_id", "")))
	var method: String = str(payload.get("method", ""))
	if gem.is_empty() or method not in ["temper", "fuse"]: return "Select an owned gem and either Temper or Fuse."
	if int(gem.get("carat", 1)) >= 24: return "That gem is already at the highest Carat."
	var gain: int = CRUCIBLE_CARAT_GAIN
	if method == "temper":
		var cost: int = _crucible_hp_cost(gem)
		if int(player.hp) <= cost: return "Tempering this gem costs %s HP, and you must survive it." % cost
		player.hp -= cost
		_stat("hp_lost", cost)
		_record("crucible", "%s tempers %s for %s HP." % [player.name, _item_name(gem, "gem"), cost], {"actor_id":player.id, "amount":cost})
	else:
		var fuel: Dictionary = _find(player.gems, str(payload.get("fuel_id", "")))
		if fuel.is_empty() or fuel.id == gem.id: return "Choose a second owned gem to consume."
		if fuel.get("equipped", false): return "Only a reserve gem can be consumed. Unequip it first."
		if fuel.key == "STRIKE" and _count_key(player.gems, "STRIKE") <= 1: return "Your last Strike cannot be consumed."
		gain += floori(float(int(fuel.get("carat", 1))) / float(CRUCIBLE_FUSE_DIVISOR))
		player.gems.erase(fuel)
		_record("crucible", "%s consumes %s to feed %s." % [player.name, _item_name(fuel, "gem"), _item_name(gem, "gem")], {"actor_id":player.id})
	var before: int = int(gem.get("carat", 1))
	gem.carat = mini(24, before + gain)
	state.room.services[player.id] = true
	_record("crucible", "%s rises from Carat %s to %s." % [_item_name(gem, "gem"), before, int(gem.carat)], {"actor_id":player.id, "item_id":gem.id})
	return ""

func _vote_vein(player: Dictionary, vein: String) -> String:
	if state.phase != "mine_vote" or vein not in ["coin", "crystal"] or state.votes.has(player.id): return "Choose one mine vein before it is committed."
	state.votes[player.id] = vein
	var chosen: String = _vote_result()
	if not chosen.is_empty(): _mine(chosen)
	return ""

func _mine(vein: String) -> void:
	state.mine.vein = vein
	state.mine_visits += 1
	var rock_keys: Array = ["Small", "Medium", "Large", "Gold", "Shiny"]
	var weights: Array = [4,4,2,2,0] if vein == "coin" else [1,3,4,0,2]
	var hit_ranges: Array = [[1,2], [2,4], [3,5], [1,4], [1,5]]
	var gold_values: Array = [[0,5], [0,5,10], [0,5,10], [10,15,20,25,50], [0,20]]
	var gold_powers: Array = [10,20,15,10,10]
	var gem_values: Array = [[0,1], [0,1], [0,1], [0], [1,2,2,3]]
	var gem_powers: Array = [20,5,3,1,3]
	for i in 6 * int(state.party_size):
		var key: String = _weighted(rock_keys, weights, streams.loot)
		var index: int = rock_keys.find(key)
		var rock: Dictionary = {"id":_id("rock"), "kind":key, "hits":streams.loot.randi_range(hit_ranges[index][0], hit_ranges[index][1]), "progress":0, "broken":false,
			"gold":_power_pick(gold_values[index], gold_powers[index]), "gems":[]}
		var count: int = _power_pick(gem_values[index], gem_powers[index])
		if count > 0:
			rock.gems = _generate_gems(count, state.profile == "expedition_18" and key == "Shiny", mini(15, int(state.room_index)) + (5 if key == "Shiny" and state.profile == "short_9" else 0))
		state.mine.rocks.append(rock)
	var energy: Dictionary = state.mine.energy.duplicate(true)
	var rock_index: int = 0
	var turn_seat: int = 0
	while rock_index < state.mine.rocks.size():
		var any_energy: bool = false
		for amount in energy.values():
			if amount > 0: any_energy = true
		if not any_energy: break
		var hero: Dictionary = state.heroes[turn_seat % state.party_size]
		turn_seat += 1
		if int(energy[hero.id]) <= 0: continue
		energy[hero.id] -= 1
		var rock: Dictionary = state.mine.rocks[rock_index]
		rock.progress += 1
		var event: Dictionary = {"kind":"mine_hit", "actor_id":hero.id, "rock_id":rock.id, "progress":rock.progress, "hits":rock.hits}
		if rock.progress >= rock.hits:
			rock.broken = true
			state.mine.gold += rock.gold
			for gem in rock.gems: state.mine.pool.append({"claim_id":_id("claim"), "gem":gem})
			event["broken"] = true
			rock_index += 1
		state.mine.events.append(event)
	state.mine["remaining_energy"] = energy
	var gold: int = int(state.mine.gold)
	var share: int = floori(float(gold) / float(state.party_size))
	var remainder: int = gold % int(state.party_size)
	for i in state.heroes.size():
		var hero: Dictionary = state.heroes[i]
		var extra: int = 1 if (i - int(state.coin_rotation) + int(state.party_size)) % int(state.party_size) < remainder else 0
		_grant_gold(hero, share + extra, "mine")
	state.coin_rotation = (int(state.coin_rotation) + remainder) % int(state.party_size)
	state.mine.draft_index = (int(state.mine_visits) - 1) % int(state.party_size)
	_record("mine_result", "%s rocks broken. %s gold shared; %s gems found." % [rock_index, gold, state.mine.pool.size()])
	if state.mine.pool.is_empty():
		_phase("support")
	else:
		state.mine.picker_id = state.heroes[state.mine.draft_index].id
		_phase("mine_draft")

func _draft(player: Dictionary, claim_id: String) -> String:
	if state.phase != "mine_draft" or state.mine.picker_id != player.id: return "Wait for your turn in the mine draft."
	var claim: Dictionary = {}
	for candidate in state.mine.pool:
		if candidate.claim_id == claim_id: claim = candidate
	if claim.is_empty() or claim_id in state.claimed_rewards: return "That gem claim is no longer available."
	state.claimed_rewards.append(claim_id)
	var gem: Dictionary = claim.gem.duplicate(true)
	gem.equipped = false
	gem.owner_id = player.id
	player.gems.append(gem)
	state.mine.pool.erase(claim)
	_record("mine_claim", "%s drafts %s." % [player.name, _item_name(gem, "gem")])
	if state.mine.pool.is_empty():
		state.mine.picker_id = ""
		_phase("support")
	else:
		state.mine.draft_index = (int(state.mine.draft_index) + 1) % int(state.party_size)
		state.mine.picker_id = state.heroes[state.mine.draft_index].id
	return ""

func _advance_room() -> void:
	state.statistics.rooms += 1
	state.history.append({"room_index":state.room_index, "act":state.act, "kind":state.room.kind, "room_id":state.room.id})
	state.last_room_kind = state.room.kind
	state.room_index += 1
	state.room = {}
	state.enemies = []
	state.turn = 0
	_route_offers()

func _end_run(outcome: String) -> void:
	state.outcome = outcome
	_phase("summary")
	state["summary"] = {"run_id":state.run_id, "outcome":outcome, "profile":state.profile, "seed":state.seed, "room_index":state.room_index,
		"heroes":state.heroes.duplicate(true), "statistics":state.statistics.duplicate(true), "completed_at":Time.get_datetime_string_from_system(true)}
	_record("run_ended", "The party is victorious!" if outcome == "victory" else "The party has fallen. Your expedition is recorded.")

func set_controller_connected(player_id: String, connected: bool) -> Dictionary:
	var player: Dictionary = _hero(player_id)
	if player.is_empty(): return _rejection("Unknown player.")
	var previous: Dictionary = state.duplicate(true)
	player.connected = connected
	player.fallback = false
	if not connected:
		player["disconnect_time"] = Time.get_unix_time_from_system()
	var paused: bool = false
	for hero in state.heroes:
		if not hero.get("connected", true) and not hero.get("fallback", false): paused = true
	state.paused = paused
	state.revision += 1
	var result: Dictionary = _checkpoint()
	if not result.get("ok", false):
		state = previous
		return result
	changed.emit(state)
	return result

func _resume_disconnected(player: Dictionary, id: String) -> String:
	if player.id != state.host_id: return "Only the host may resume with a fallback controller."
	var absent: Dictionary = _hero(id)
	if absent.is_empty() or absent.get("connected", true): return "That hero is not disconnected."
	if Time.get_unix_time_from_system() - float(absent.get("disconnect_time", 0)) < 60.0: return "The 60-second reconnect grace period has not elapsed."
	absent.fallback = true
	absent.ready = true
	state.paused = false
	for hero in state.heroes:
		if not hero.get("connected", true) and not hero.get("fallback", false): state.paused = true
	_record("fallback", "%s uses deterministic fallback until their player returns." % absent.name)
	return ""

func _auto_fallback() -> void:
	for step in 256:
		var phase_before: int = state.phase_id
		_fallback_step()
		if int(state.phase_id) == phase_before or state.phase == "summary": break

func _fallback_step() -> void:
	if state.paused: return
	# Only declared fallback heroes are automated; no purchases or rerolls are made.
	for hero in state.heroes:
		if not hero.get("fallback", false): continue
		hero.ready = true
		if state.phase == "planning":
			for enemy in state.enemies:
				if enemy.hp > 0:
					hero.preferred_target = enemy.id
					break
		elif state.phase == "reward":
			var reward: Dictionary = state.reward_offers.get(hero.id, {})
			for kind in ["gem", "relic"]:
				if not reward.get(kind + "_done", true):
					hero.ready = false
					var offers: Array = reward.get("gems" if kind == "gem" else "relics", [])
					_choose_reward(hero, {"kind":kind, "offer_id":offers[0].id if not offers.is_empty() else ""})
					hero.ready = true
	while state.phase == "mine_draft":
		var picker: Dictionary = _hero(state.mine.picker_id)
		if not picker.get("fallback", false): break
		_draft(picker, state.mine.pool[0].claim_id)
	if state.phase in ["route", "mine_vote"]:
		var choice: String = _vote_result()
		if not choice.is_empty():
			if state.phase == "route": _enter_room(_find(state.offers, choice).kind)
			else: _mine(choice)
	if state.phase in ["planning", "support", "reward"]:
		_check_ready()

func resume_run(new_session_id: String = "") -> Dictionary:
	var loaded: Dictionary = save_store.load_checkpoint()
	if not loaded.get("ok", false): return loaded
	return restore(loaded.state, loaded.get("command_history", {}), new_session_id)

func restore(snapshot: Dictionary, history: Dictionary = {}, new_session_id: String = "") -> Dictionary:
	var error: String = validate_state(snapshot)
	if not error.is_empty(): return _rejection(error)
	var previous: Dictionary = state.duplicate(true)
	var previous_history: Dictionary = command_history.duplicate(true)
	var previous_rng: Dictionary = _rng_snapshot()
	state = snapshot.duplicate(true)
	state.erase("accepted_commands")
	command_history = history.duplicate(true)
	_restore_rng(state.rng_states)
	if not new_session_id.is_empty():
		state.session_id = new_session_id
		state.host_epoch += 1
		state.paused = state.heroes.size() > 1
		for hero in state.heroes:
			hero.connected = hero.id == state.host_id
			hero.fallback = false
			if not hero.connected: hero.disconnect_time = Time.get_unix_time_from_system()
		state.revision += 1
	var saved: Dictionary = _checkpoint()
	if not saved.get("ok", false):
		state = previous
		command_history = previous_history
		streams.clear()
		_restore_rng(previous_rng)
		return saved
	changed.emit(state)
	return {"ok":true, "state":state}

static func validate_state(snapshot: Dictionary) -> String:
	var whole := func(value: Variant, minimum: int = 0, maximum: int = 2147483647) -> bool:
		return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum
	if snapshot.get("schema_version", 0) != 1 or snapshot.get("rules_version", "") != RULES_VERSION or snapshot.get("content_version", "") != CONTENT_VERSION:
		return "This checkpoint uses incompatible rules or content."
	for field in ["run_id", "session_id", "host_id"]:
		if not snapshot.get(field) is String or snapshot[field].is_empty() or snapshot[field].length() > 256:
			return "The checkpoint has an invalid " + field + "."
	if snapshot.get("profile", "") not in ["short_9", "expedition_18"]: return "Unknown saved run profile."
	if snapshot.get("phase", "") not in ["route", "planning", "support", "reward", "mine_vote", "mine_draft", "summary"]: return "Unknown saved run phase."
	for field in ["revision", "phase_id", "host_epoch", "turn", "room_index", "act", "party_size", "next_id", "mine_visits", "coin_rotation"]:
		if not whole.call(snapshot.get(field)): return "Invalid saved counter: " + field
	if not whole.call(snapshot.act, 1, 3) or not whole.call(snapshot.room_index, 1, 19) or not whole.call(snapshot.host_epoch, 1): return "Invalid saved progression."
	for field in ["heroes", "enemies", "offers", "log", "last_events", "history", "settled_rooms", "claimed_rewards", "shops_seen"]:
		if not snapshot.get(field) is Array: return "Invalid saved list: " + field
	for field in ["room", "votes", "reward_offers", "shop", "mine", "event", "statistics", "rng_states"]:
		if not snapshot.get(field) is Dictionary: return "Invalid saved record: " + field
	if not snapshot.get("accepted_sequences", {}) is Dictionary: return "Invalid command sequence history."
	if not snapshot.get("paused") is bool: return "Invalid saved pause state."
	if snapshot.heroes.is_empty() or snapshot.heroes.size() > 4 or int(snapshot.party_size) != snapshot.heroes.size(): return "The checkpoint has an invalid party."
	var owned_ids: Dictionary = {}
	var hero_ids: Dictionary = {}
	var seats: Dictionary = {}
	for hero in snapshot.heroes:
		if not hero is Dictionary or not Catalog.HEROES.has(hero.get("key", "")): return "Unknown hero content."
		if not hero.get("id") is String or hero.id.is_empty() or hero_ids.has(hero.id): return "Invalid or duplicate saved player ID."
		hero_ids[hero.id] = true
		if not whole.call(hero.get("seat"), 0, snapshot.heroes.size() - 1) or seats.has(int(hero.seat)): return "Invalid or duplicate party seat."
		seats[int(hero.seat)] = true
		if not whole.call(hero.get("max_hp"), 1) or not whole.call(hero.get("hp"), 0, int(hero.max_hp)) or not whole.call(hero.get("gold")) or not whole.call(hero.get("block")): return "Invalid saved hero statistics."
		for field in ["rerolls", "max_rerolls", "trait_charges", "combat_gold", "action_eligible_from_turn"]:
			if not whole.call(hero.get(field)): return "Invalid saved hero counter: " + field
		# A White gem raises the allowance for one battle; `base_rerolls` is what it drops
		# back to at the start of the next one, so the pair is bounded rather than the one.
		if not whole.call(hero.get("base_rerolls", 1), 1, Combat.MAX_REROLLS) or not whole.call(hero.max_rerolls, 1, Combat.MAX_REROLLS): return "Invalid saved reroll allowance."
		if not whole.call(hero.trait_charges, 0, 1) or int(hero.rerolls) > int(hero.max_rerolls): return "Invalid saved encounter allowance."
		if not hero.get("rerolled") is bool or not hero.get("relic_flags") is Dictionary or not hero.get("tinker_used_acts") is Array: return "Invalid saved trait or relic bookkeeping."
		for used_act in hero.tinker_used_acts:
			if not whole.call(used_act, 1, 3): return "Invalid saved relic act charge."
		for field in ["ready", "connected"]:
			if not hero.get(field) is bool: return "Invalid hero controller or readiness state."
		if not hero.get("fallback", false) is bool: return "Invalid fallback controller state."
		for field in ["dice", "reserve_dice", "gems", "relics", "hand", "initial_hand"]:
			if not hero.get(field) is Array: return "Invalid hero inventory: " + field
		if hero.dice.size() != 5 or hero.reserve_dice.size() > 5: return "Invalid saved dice capacity."
		if not hero.get("statuses") is Dictionary: return "Invalid saved status effects."
		for status_key in ["stun", "poison", "resolve"]:
			if not whole.call(hero.statuses.get(status_key, 0)): return "Invalid saved status count."
		if not whole.call(hero.statuses.get("poison", 0), 0, 12): return "Saved Poison exceeds its cap."
		var equipped_gems: Dictionary = {}
		var equipped_relics: Dictionary = {}
		for item in hero.gems:
			if not item is Dictionary or not Catalog.SKILLS.has(item.get("key", "")): return "Unknown saved gem."
			if not whole.call(item.get("carat"), 1, 24) or not whole.call(item.get("cut"), 1, 5) or not whole.call(item.get("clarity"), 1, 5): return "Invalid saved gem properties."
			if not item.get("equipped") is bool: return "Invalid saved gem equipment flag."
			if not whole.call(item.get("revive_charges", 1), 0, 1) or not whole.call(item.get("upgrade_charges", 1), 0, 1): return "Invalid saved gem charge."
			if item.equipped:
				if equipped_gems.has(item.key): return "Duplicate equipped skill."
				equipped_gems[item.key] = true
		if equipped_gems.size() > 6 or not equipped_gems.has("STRIKE"): return "Saved loadout must include Strike within six gem slots."
		for item in hero.relics:
			if not item is Dictionary or not Catalog.RELICS.has(item.get("key", "")): return "Unknown saved relic."
			if not item.get("equipped") is bool: return "Invalid saved relic equipment flag."
			if not whole.call(item.get("stored_block", 0), 0, 6): return "Invalid stored relic block."
			if item.equipped:
				if equipped_relics.has(item.key): return "Duplicate equipped relic."
				equipped_relics[item.key] = true
		if equipped_relics.size() > 3: return "Saved loadout exceeds three relic slots."
		var active_dice: Dictionary = {}
		for die in hero.dice + hero.reserve_dice:
			if not die is Dictionary or not Catalog.DICE.has(die.get("key", "")) or str(die.get("shape", "")) not in SHAPES or not die.get("faces") is Array: return "Unknown saved die."
			var sides: int = int(str(die.shape).trim_prefix("D"))
			if die.faces.size() != sides: return "Invalid saved die face count."
			var face_ids: Dictionary = {}
			for face in die.faces:
				if not face is Dictionary or not whole.call(face.get("value"), 1, sides): return "Invalid saved face value."
				if not face.get("id") is String or face.id.is_empty() or face_ids.has(face.id): return "Invalid or duplicate die face ID."
				face_ids[face.id] = true
			if die in hero.dice: active_dice[str(die.get("id", ""))] = die
		for item in [hero] + hero.gems + hero.relics + hero.dice + hero.reserve_dice:
			if not item.get("id") is String or item.id.is_empty() or owned_ids.has(item.id): return "Duplicate saved inventory instance."
			owned_ids[item.id] = true
			if item.has("owner_id") and item.owner_id != hero.id: return "Saved item belongs to another hero."
		for hand_field in ["hand", "initial_hand"]:
			var rolled_ids: Dictionary = {}
			for roll in hero[hand_field]:
				if not roll is Dictionary or not active_dice.has(roll.get("die_id", "")) or rolled_ids.has(roll.die_id): return "Invalid saved hand ownership."
				var die: Dictionary = active_dice[roll.die_id]
				# A White gem can raise a die above the face it turned up, so a roll carries
				# how far it was lifted and still has to add back to a real physical face.
				if not whole.call(roll.get("face_index"), 0, die.faces.size() - 1) or not whole.call(roll.get("value"), 1, Combat.HAND_VALUE_CAP): return "Invalid saved roll result."
				if not whole.call(roll.get("lift", 0), 0, Combat.HAND_VALUE_CAP): return "Invalid saved die lift."
				var face: Dictionary = die.faces[int(roll.face_index)]
				if roll.get("face_id", "") != face.id or int(roll.value) != int(face.value) + int(roll.get("lift", 0)) or not whole.call(roll.get("roll_count")): return "Saved roll does not match its physical die face."
				rolled_ids[roll.die_id] = true
	if not hero_ids.has(snapshot.host_id): return "The host has no reserved party seat."
	for player_id in snapshot.get("accepted_sequences", {}):
		if not hero_ids.has(player_id) or not whole.call(snapshot.accepted_sequences[player_id]): return "Invalid saved command sequence."
	for enemy in snapshot.enemies:
		if not enemy is Dictionary or not Catalog.ENEMIES.has(enemy.get("key", "")): return "Unknown saved enemy."
		if not enemy.get("id") is String or enemy.id.is_empty() or owned_ids.has(enemy.id): return "Invalid saved enemy ID."
		owned_ids[enemy.id] = true
		if not whole.call(enemy.get("max_hp"), 1) or not whole.call(enemy.get("hp"), 0, int(enemy.max_hp)) or not whole.call(enemy.get("block")): return "Invalid saved enemy statistics."
		for field in ["dice", "gems", "hand"]:
			if not enemy.get(field) is Array: return "Invalid saved enemy inventory."
		if not enemy.get("statuses") is Dictionary: return "Invalid enemy statuses."
		for status_key in ["stun", "poison", "resolve"]:
			if not whole.call(enemy.statuses.get(status_key, 0), 0, 12 if status_key == "poison" else 2147483647): return "Invalid saved enemy status counter."
		if not whole.call(enemy.get("action_eligible_from_turn"), 1) or not whole.call(enemy.get("phase_turn"), 0) or not whole.call(enemy.get("act"), 1, 3): return "Invalid saved enemy turn counter."
		if not enemy.get("intents") is Array: return "Invalid saved enemy intentions."
		for intent in enemy.intents:
			if not intent is Dictionary or not intent.get("key") is String or not intent.get("name") is String or not intent.get("effects") is Array: return "Malformed saved enemy intent."
			for effect in intent.effects:
				if not effect is Dictionary or effect.get("kind", "") not in ["damage", "block", "heal", "gold", "remove_block", "stun", "poison", "lifeline"] or not whole.call(effect.get("amount")): return "Invalid saved enemy effect."
				if effect.get("target", "self") not in ["self", "enemy", "enemies", "ally", "allies", "other_allies", "revive"]: return "Invalid saved effect target."
				for numeric_key in ["marked_value", "bonus", "threshold", "enrage_bonus", "heal_amount", "charges", "target_limit", "numerator"]:
					if effect.has(numeric_key) and not whole.call(effect[numeric_key]): return "Invalid saved conditional intent."
				if effect.has("denominator") and not whole.call(effect.denominator, 1): return "Invalid saved effect multiplier."
	for offer in snapshot.offers:
		if not offer is Dictionary or not offer.get("id") is String or not ROOM_NAMES.has(offer.get("kind", "")): return "Unknown saved route offer."
	if not snapshot.room.is_empty() and (not ROOM_NAMES.has(snapshot.room.get("kind", "")) or not snapshot.room.get("services") is Dictionary): return "Invalid saved room."
	if snapshot.room.get("kind", "") == "wager":
		if not snapshot.room.get("wager") is Dictionary: return "Invalid saved wager table."
		for seat in snapshot.room.wager.values():
			if not seat is Dictionary or not seat.get("hand") is Array or not seat.get("dice") is Array: return "Invalid saved wager seat."
			if not whole.call(seat.get("stake"), 0, WAGER_STAKES[-1]) or not whole.call(seat.get("payout"), 0): return "Invalid saved wager stake."
	if not snapshot.event.is_empty() and (not Catalog.EVENTS.has(snapshot.event.get("key", "")) or not snapshot.event.get("offers") is Dictionary): return "Unknown saved event."
	if snapshot.phase == "mine_draft" and (not snapshot.mine.get("pool") is Array or snapshot.mine.pool.is_empty() or not hero_ids.has(snapshot.mine.get("picker_id", ""))): return "Invalid saved mine draft."
	for key in ["rooms", "encounters", "dice", "loot"]:
		if not snapshot.rng_states.get(key) is String or not snapshot.rng_states[key].is_valid_int(): return "Invalid saved random state."
	# Validate definitions in generated offers and encounter inventories as well.
	# Repeated IDs in historical events/offers are references, not extra ownership.
	var pending: Array = [snapshot]
	var visited: int = 0
	while not pending.is_empty():
		var value: Variant = pending.pop_back()
		visited += 1
		if visited > 200000: return "Saved state exceeds the supported structural size."
		if value is Dictionary:
			if value.has("carat") and value.has("key"):
				if not Catalog.SKILLS.has(value.key) or not whole.call(value.get("carat"), 1, 24) or not whole.call(value.get("cut"), 1, 5) or not whole.call(value.get("clarity"), 1, 5): return "Invalid generated gem content."
			if value.has("shape") and value.has("faces"):
				if not Catalog.DICE.has(value.get("key", "")) or value.shape not in SHAPES or not value.faces is Array: return "Invalid generated die content."
			if value.has("stored_block") and value.has("key") and not Catalog.RELICS.has(value.key): return "Unknown generated relic content."
			for key in value:
				if not (key is String or key is StringName or key is int): return "Invalid saved dictionary key."
				pending.append(value[key])
		elif value is Array:
			pending.append_array(value)
		elif value is float and not is_finite(value): return "Non-finite number in saved state."
		elif not (value == null or value is String or value is StringName or value is bool or value is int or value is float): return "Unsupported saved value."
	return ""
func _checkpoint() -> Dictionary:
	state["rng_states"] = _rng_snapshot()
	if not autosave: return {"ok":true}
	var result = save_store.save_checkpoint(state, command_history)
	if result is Dictionary:
		if result.get("ok", false) and state.phase == "summary": save_store.record_summary(state.summary)
		return result
	return {"ok":bool(result), "error":"Unable to write checkpoint."}

func _rng_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key in streams: result[key] = str(streams[key].state)
	return result

func _restore_rng(saved: Dictionary) -> void:
	for key in saved:
		if not streams.has(key): streams[key] = RandomNumberGenerator.new()
		streams[key].state = int(saved[key])

func _phase(phase: String) -> void:
	state.phase = phase
	state.phase_id += 1
	for hero in state.heroes: hero.ready = false

func _generate_gems(count: int, elite: bool = false, luck: int = -1) -> Array:
	var prefix: String = _id("loot")
	return Catalog.generate_gems(streams.loot, count, state.profile, state.act, mini(15, int(state.room_index) - 1) if luck < 0 else luck, prefix, state.party_size, elite)

func _id(prefix: String) -> String:
	state.next_id += 1
	return "%s-%s-%s" % [state.run_id, prefix, state.next_id]

func _grant_gold(player: Dictionary, amount: int, source: String) -> void:
	player.gold += maxi(0, amount)
	state.statistics.gold_earned += maxi(0, amount)
	_record("gold", "%s gains %s gold." % [player.name, amount], {"actor_id":player.id, "amount":amount, "source":source})

func _spend(player: Dictionary, amount: int) -> void:
	player.gold -= amount
	state.statistics.gold_spent += amount

func _record(kind: String, message: String, detail: Dictionary = {}) -> void:
	var event: Dictionary = {"kind":kind, "type":kind, "message":message, "run_id":state.get("run_id", ""), "phase_id":state.get("phase_id", 0), "turn":state.get("turn", 0), "room_index":state.get("room_index", 0)}
	event.merge(detail, true)
	_events.append(event)

func _stat(key: String, amount: int) -> void:
	state.statistics[key] = int(state.statistics.get(key, 0)) + amount

func _stat_bucket(key: String, entry: String) -> void:
	if not state.statistics.has(key): state.statistics[key] = {}
	state.statistics[key][entry] = int(state.statistics[key].get(entry, 0)) + 1

func _finish_events() -> void:
	for i in _events.size():
		_events[i]["event_id"] = "%s:%s:%s" % [state.run_id, state.revision, i]
	state.last_events = _events.duplicate(true)
	state.log.append_array(_events.duplicate(true))
	if state.log.size() > 500: state.log = state.log.slice(state.log.size()-500)

func _rejection(error: String) -> Dictionary:
	return {"ok":false, "error":error, "state":state}

func _hero(id: String) -> Dictionary:
	return _find(state.get("heroes", []), id)

static func _find(items: Array, id: String) -> Dictionary:
	for item in items:
		if str(item.get("id", "")) == id: return item
	return {}

static func _count_key(items: Array, key: String) -> int:
	var count: int = 0
	for item in items:
		if item.get("key", "") == key: count += 1
	return count

static func _equipped_count(items: Array) -> int:
	var count: int = 0
	for item in items:
		if item.get("equipped", false): count += 1
	return count

static func _has_relic(player: Dictionary, key: String) -> bool:
	for relic in player.get("relics", []):
		if relic.key == key and relic.get("equipped", false): return true
	return false

static func _equipped_skill(player: Dictionary, key: String) -> bool:
	for gem in player.gems:
		if gem.key == key and gem.get("equipped", false): return true
	return false

static func _integer(payload: Dictionary, key: String, low: int, high: int) -> int:
	var value = payload.get(key, null)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
		return -1
	return int(value) if int(value) >= low and int(value) <= high else -1

static func _weighted(values: Array, weights: Array, rng: RandomNumberGenerator) -> Variant:
	var total: float = 0.0
	for weight in weights: total += float(weight)
	var draw: float = rng.randf() * total
	for i in values.size():
		draw -= float(weights[i])
		if draw < 0: return values[i]
	return values[-1]

func _power_pick(values: Array, power: int) -> int:
	return int(values[mini(values.size()-1, floori(pow(streams.loot.randf(), power) * values.size()))])

static func _die_value(die: Dictionary) -> int:
	var key: String = str(die.get("key", die.get("definition_id", die.get("shape", "D6"))))
	var prices: Dictionary = {"D4":4, "D6":6, "D8":8, "D10":10, "D12":12, "D20":16, "PAIRED_D6":8, "ODD_D6":8, "EVEN_D6":8, "SEVEN_D8":14, "SPLIT_D12":16, "SPLIT_D20":22}
	return int(prices.get(key, prices.get(die.get("shape", "D6"), 6)))

static func _item_name(item: Dictionary, kind: String) -> String:
	var definitions: Dictionary = Catalog.SKILLS if kind == "gem" else (Catalog.RELICS if kind == "relic" else Catalog.DICE)
	return str(definitions.get(item.get("key", ""), {}).get("name", item.get("key", item.get("shape", "item"))))
