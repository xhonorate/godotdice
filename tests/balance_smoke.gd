extends SceneTree
## Deterministic integration smoke with ordinary starting heroes, no stat changes.
## Bot estimates hands from the real resolver and uses only public commands. It digs until
## it is hurt or has a good haul, then rides the first lift it can reach; a boss that wakes
## first is fought. This is a smoke sample, not a balance or win-rate claim.
const EngineCore = preload("res://scripts/core/run_engine.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
var errors: Array = []
var summaries: Array = []
var decisions: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_autosave_regression()
	for mine_id in ["QUARRY","MIRROR_GROTTO","RIFT_HOLLOW"]:
		for hero_id in ["ARDOR","KAIT","MAX"]:
			for seed_value in ([101,202,303] if mine_id == "QUARRY" else [101]):
				var engine: RefCounted = _fresh(hero_id,seed_value,false,mine_id)
				for _step in range(3000):
					if engine.state.phase == "summary": break
					if not _step_bot(engine): break
				var state: Dictionary = engine.state
				if state.phase != "summary": errors.append("Bot did not reach summary: "+mine_id+" "+hero_id+" seed "+str(seed_value)+" phase "+str(state.phase))
				var result: Dictionary = {"hero":hero_id,"seed":seed_value,"mine":mine_id,"outcome":state.get("outcome",""),"depth":state.deepest,"tremor":state.tremor,"turns":state.statistics.turns,"ore_earned":state.statistics.ore_earned,"haul":state.results.get("bot",{}).get("haul",[]).size(),"remaining_hp":state.heroes[0].hp}
				summaries.append(result)
				print(JSON.stringify(result))
	print("Starting-loadout smoke: %d completed samples, %d commands, %d errors" % [summaries.size(),decisions,errors.size()])
	for error in errors: printerr("FAIL: "+str(error))
	quit(0 if errors.is_empty() else 1)

func _fresh(hero_id: String, seed_value: int, save: bool = false, mine_id: String = "QUARRY") -> RefCounted:
	var engine: RefCounted = EngineCore.new()
	if save:
		engine.save_store.directory = "user://tests/balance-autosave-"+str(OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(engine.save_store.directory))
	var result: Dictionary = engine.new_run({"heroes":[{"id":"bot","hero_id":hero_id}],"mine_id":mine_id,"seed":seed_value,"run_id":"smoke-"+mine_id+"-"+hero_id+"-"+str(seed_value),"autosave":save})
	if result.get("ok",true) == false: errors.append("new_run: "+str(result.get("error","")))
	return engine

func _command(engine: RefCounted, kind: String, payload: Dictionary = {}) -> bool:
	decisions += 1
	var result: Dictionary = engine.execute("bot",engine.make_envelope("bot",kind,payload))
	if not result.get("ok",false):
		errors.append(kind+": "+str(result.get("error","unknown")))
		return false
	return true

func _step_bot(engine: RefCounted) -> bool:
	var state: Dictionary = engine.state
	var unit: Dictionary = state.heroes[0]
	match str(state.phase):
		"route":
			var best: Dictionary = state.offers[0]
			var best_score: float = -INF
			var leaving: bool = _wants_home(state)
			for offer in state.offers:
				var score: float = {"battle":25.0,"elite":8.0,"shop":12.0+float(unit.ore),"rest":float(unit.max_hp-unit.hp)*2.0,"workshop":15.0 if unit.ore >= 5 else 0.0,"lapidary":32.0 if unit.ore >= 10 else 0.0,"mine":35.0,"event":30.0,"treasure":40.0,"wager":18.0 if unit.ore >= 4 else 0.0,"crucible":34.0 if unit.hp > unit.max_hp / 2 else 4.0,"lift":200.0 if leaving else 1.0}.get(offer.kind,10.0)
				if offer.get("wakes_boss",false): score -= 50.0
				if score > best_score:
					best_score = score
					best = offer
			return _command(engine,"VoteRoom",{"offer_id":best.id})
		"lift":
			return _command(engine,"VoteLift",{"choice":"ride" if _wants_home(state) else "dig"})
		"salvage":
			return _command(engine,"SetReady",{"ready":true})
		"planning":
			return _plan(engine)
		"reward":
			var reward: Dictionary = state.reward_offers.bot
			if not reward.gem_done:
				var chosen: Dictionary = _best_gem(unit,reward.gems)
				if chosen.is_empty() and not reward.gems.is_empty(): chosen = reward.gems[0]
				if not _command(engine,"ChooseReward",{"kind":"gem","offer_id":chosen.get("id","")}): return false
			if not reward.relic_done:
				var best: Dictionary = {}
				var best_score: float = -INF
				for item in reward.relics:
					var score: float = {"MATCHBOX":8,"STEADY_HAND":6,"FIELD_DRESSING":9,"MINERS_LANTERN":3}.get(item.key,5)
					if score > best_score:
						best = item
						best_score = score
				if not _command(engine,"ChooseReward",{"kind":"relic","offer_id":best.get("id","")}): return false
			if not _manage_build(engine): return false
			return _command(engine,"SetReady",{"ready":true})
		"support":
			match str(state.room.kind):
				"shop":
					var offers: Array = state.shop.bot.gems.duplicate()
					offers.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return _gem_score(unit,a.gem)/maxf(1.0,a.price) > _gem_score(unit,b.gem)/maxf(1.0,b.price))
					for offer in offers:
						if not offer.claimed and unit.ore >= offer.price and _upgrade_value(unit,offer.gem) > 0.5:
							if not _command(engine,"BuyGem",{"offer_id":offer.id}): return false
					if not unit.haul.is_empty() and not state.shop.bot.loupe.claimed and unit.ore >= int(state.shop.bot.loupe.price):
						if not _command(engine,"BuyLoupe",{}): return false
				"lapidary":
					var upgrade: Dictionary = {}
					var improvement: float = 0.0
					for item in unit.gems:
						if not item.equipped: continue
						for property in ["cut","clarity"]:
							if item[property] >= 5 or unit.ore < (item[property]+1)*5: continue
							var improved: Dictionary = item.duplicate(true)
							improved[property] += 1
							var gain: float = _gem_score(unit,improved)-_gem_score(unit,item)
							if gain > improvement:
								improvement = gain
								upgrade = {"gem_id":item.id,"property":property}
					if not upgrade.is_empty() and not _command(engine,"UpgradeGem",upgrade): return false
					for stone in unit.haul.duplicate():
						if unit.ore < engine.APPRAISE_PRICE: break
						if not _command(engine,"AppraiseGem",{"gem_id":stone.id,"method":"lapidary"}): return false
				"workshop":
					if unit.ore >= 5:
						for die in unit.dice:
							var index: int = Catalog.STANDARD_DICE.find(die.shape)
							if index < Catalog.STANDARD_DICE.size()-1:
								if not _command(engine,"ModifyDie",{"die_id":die.id,"service":"shape","shape":Catalog.STANDARD_DICE[index+1]}): return false
								break
				"event":
					if not _command(engine,"EventChoice",{"option":"a"}): return false
				"wager":
					# Stake what it can cover, throw everything outside the largest group, settle.
					var seat: Dictionary = state.room.wager.get("bot",{})
					var stake: int = 0
					for tier in engine.WAGER_STAKES:
						if unit.ore >= int(tier): stake = int(tier)
					if int(seat.get("stake",0)) <= 0 and stake > 0:
						if not _command(engine,"PlaceWager",{"stake":stake}): return false
					seat = state.room.wager.get("bot",{})
					if int(seat.get("stake",0)) > 0 and not seat.get("rerolled",false):
						var counts: Dictionary = {}
						for roll in seat.hand: counts[int(roll.value)] = int(counts.get(int(roll.value),0))+1
						var keep: int = 0
						for value in counts:
							if int(counts[value]) > int(counts.get(keep,0)): keep = int(value)
						var throw: Array = []
						for roll in seat.hand:
							if int(roll.value) != keep: throw.append(str(roll.die_id))
						if not throw.is_empty() and not _command(engine,"WagerReroll",{"die_ids":throw}): return false
					if int(state.room.wager.get("bot",{}).get("stake",0)) > 0 and not state.room.wager.bot.settled:
						if not _command(engine,"SettleWager",{}): return false
				"crucible":
					# Prefer feeding a spare gem to the best equipped one; temper only when healthy.
					var target: Dictionary = {}
					var best: float = -INF
					for item in unit.gems:
						if not item.equipped or int(item.carat) >= 24: continue
						var rating: float = _gem_score(unit,item)
						if rating > best:
							best = rating
							target = item
					if not target.is_empty():
						var fuel: Dictionary = {}
						for item in unit.gems:
							if item.equipped or not item.get("found",false) or str(item.id) == str(target.id): continue
							if fuel.is_empty() or int(item.carat) > int(fuel.carat): fuel = item
						if not fuel.is_empty():
							if not _command(engine,"TemperGem",{"gem_id":target.id,"method":"fuse","fuel_id":fuel.id}): return false
						elif unit.hp > unit.max_hp / 2 + 4 + int(target.carat) / 2:
							if not _command(engine,"TemperGem",{"gem_id":target.id,"method":"temper"}): return false
			if not _manage_build(engine): return false
			return _command(engine,"SetReady",{"ready":true})
		"mine_vote":
			return _command(engine,"VoteVein",{"vein":"crystal"})
		"mine_draft":
			var best: Dictionary = state.mine.pool[0]
			for claim in state.mine.pool:
				if _gem_score(unit,claim.gem) > _gem_score(unit,best.gem): best = claim
			return _command(engine,"DraftGem",{"claim_id":best.claim_id})
	return false

func _wants_home(state: Dictionary) -> bool:
	## A cautious miner: head home when hurt, when the meter is past two thirds, or with a
	## decent haul past the first few layers.
	var unit: Dictionary = state.heroes[0]
	var carried: int = unit.haul.size() + unit.gems.filter(func(item: Dictionary) -> bool: return item.get("found",false)).size()
	return unit.hp * 2 < unit.max_hp or int(state.tremor) > 650 or (carried >= 4 and int(state.depth) >= 6)

func _plan(engine: RefCounted) -> bool:
	var unit: Dictionary = engine.state.heroes[0]
	var base: float = _hand_score(engine.state)
	if unit.key == "MAX" and int(unit.trait_charges) > 0:
		var best_index: int = -1
		var best_gain: float = 0.1
		for index in range(5):
			var gain: float = _reroll_expectation(engine.state,index)-base
			if gain > best_gain:
				best_gain = gain
				best_index = index
		if best_index >= 0:
			if not _command(engine,"UseHeroTrait",{"die_id":unit.dice[best_index].id}): return false
			base = _hand_score(engine.state)
	if int(unit.rerolls) > 0:
		var selected: Array = []
		for index in range(5):
			if _reroll_expectation(engine.state,index) > base+0.25: selected.append(unit.dice[index].id)
		if not selected.is_empty() and not _command(engine,"RerollDice",{"die_ids":selected}): return false
	return _command(engine,"SetReady",{"ready":true})

func _small_state(state: Dictionary) -> Dictionary:
	return {"heroes":state.heroes.duplicate(true),"enemies":state.enemies.duplicate(true),"turn":state.turn,"depth":state.depth,"party_size":state.party_size,"battle_outcome":""}

func _hand_score(state: Dictionary) -> float:
	var forecast: Dictionary = Combat.forecast_turn(_small_state(state))
	var before: Dictionary = state.heroes[0]
	var after: Dictionary = forecast.state.heroes[0]
	if forecast.outcome == "defeat": return -10000.0
	var score: float = 200.0 if forecast.outcome == "victory" else 0.0
	score += float(after.hp-before.hp)*1.5+float(after.block-before.block)*0.65
	for index in range(state.enemies.size()):
		score += float(state.enemies[index].hp-forecast.state.enemies[index].hp)
		score += float(state.enemies[index].block-forecast.state.enemies[index].block)*0.5
	return score

func _reroll_expectation(state: Dictionary, index: int) -> float:
	var copied: Dictionary = _small_state(state)
	var die: Dictionary = copied.heroes[0].dice[index]
	var score: float = 0.0
	copied.heroes[0].rerolled = true
	for face in die.faces:
		copied.heroes[0].hand[index].value = face.value
		score += _hand_score(copied)
	return score / die.faces.size()

func _gem_score(unit: Dictionary, item: Dictionary) -> float:
	# Fixed local sample stream cannot consume authoritative RNG or predict its future.
	var sample_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	sample_rng.seed = 817
	var score: float = 0.0
	for _sample in range(20):
		var hand: Array = []
		for die in unit.dice: hand.append(Combat.roll_die(die,sample_rng))
		var action: Dictionary = Combat.preview(unit,item,hand)
		for effect in action.effects:
			var factor: float = {"damage":1.0,"block":0.65,"heal":1.1,"gold":0.15,"stun":5.0,"poison":2.0,"remove_block":0.3,"lifeline":0.5}.get(effect.kind,0.0)
			if effect.kind == "stun" and effect.target == "self": factor = -4.0
			score += float(effect.amount)*factor
	return score/20.0

func _upgrade_value(unit: Dictionary, item: Dictionary) -> float:
	var score: float = _gem_score(unit,item)
	var count: int = 0
	var lowest: float = INF
	for owned in unit.gems:
		if not owned.equipped: continue
		count += 1
		if owned.key == item.key: return score-_gem_score(unit,owned)
		if owned.key != "STRIKE": lowest = minf(lowest,_gem_score(unit,owned))
	return score if count < 6 else score-lowest

func _best_gem(unit: Dictionary, items: Array) -> Dictionary:
	var best: Dictionary = {}
	var gain: float = 0.25
	for item in items:
		var value: float = _upgrade_value(unit,item)
		if value > gain:
			best = item
			gain = value
	return best

func _manage_build(engine: RefCounted) -> bool:
	var unit: Dictionary = engine.state.heroes[0]
	if int(unit.loupes) > 0 and not unit.haul.is_empty():
		if not _command(engine,"AppraiseGem",{"gem_id":unit.haul[0].id,"method":"loupe"}): return false
	for item in unit.gems.duplicate():
		if item.equipped or _upgrade_value(unit,item) <= 0.1: continue
		## A gem can only go where its Color fits: its twin's socket, an open socket of its
		## Color, or the weakest stone already sitting in a socket that would take it.
		var same: Dictionary = {}
		var worst: Dictionary = {}
		for owned in unit.gems:
			if not owned.equipped: continue
			if owned.key == item.key: same = owned
			if owned.key != "STRIKE" and Catalog.socket_fits(str(unit.sockets[int(owned.socket)]),str(item.key)) and (worst.is_empty() or _gem_score(unit,owned) < _gem_score(unit,worst)): worst = owned
		var payload: Dictionary = {"gem_id":item.id}
		if not same.is_empty(): payload.replace_id = same.id
		elif Catalog.open_socket(unit.sockets,unit.gems,str(item.key)) < 0:
			if worst.is_empty() or _gem_score(unit,item) <= _gem_score(unit,worst): continue
			payload.replace_id = worst.id
		if not _command(engine,"EquipGem",payload): return false
	var relic_count: int = 0
	for item in unit.relics:
		if item.equipped: relic_count += 1
	for item in unit.relics:
		if not item.equipped and relic_count < 3:
			if not _command(engine,"EquipRelic",{"relic_id":item.id}): return false
			relic_count += 1
	## Sockets fix the order gems resolve in, so there is nothing left to rearrange.
	return true

func _autosave_regression() -> void:
	var engine: RefCounted = _fresh("MAX",101,true)
	var battle: String = ""
	for offer in engine.state.offers:
		if offer.kind == "battle" and battle.is_empty(): battle = offer.id
	if battle.is_empty():
		errors.append("Autosave fixture found no battle on the first layer")
		return
	if not _command(engine,"VoteRoom",{"offer_id":battle}): return
	for _turn in range(30):
		if engine.state.phase != "planning": break
		if not _plan(engine): return
	if engine.state.phase != "reward":
		errors.append("Autosave fixture did not survive first ordinary battle")
		return
	if not engine.state.heroes[0].initial_hand.is_empty(): errors.append("Combat settlement left a stale initial hand")
	if not _command(engine,"SetReady",{"ready":true}): return
	# Isolate the service transitions without changing hero statistics or inventory.
	engine._enter_room("shop")
	engine.state.heroes[0].ore += 20
	if not _command(engine,"BuyDie",{"offer_id":engine.state.shop.bot.dice[0].id}): return
	if not _command(engine,"SwapDie",{"active_id":engine.state.heroes[0].dice[0].id,"reserve_id":engine.state.heroes[0].reserve_dice[0].id}): return
	var swapped_id: String = engine.state.heroes[0].dice[0].id
	engine._enter_room("workshop")
	if not _command(engine,"ModifyDie",{"die_id":engine.state.heroes[0].dice[4].id,"service":"shape","shape":"D10"}): return
	var loaded: Dictionary = engine.save_store.load_checkpoint()
	if not loaded.get("ok",false): errors.append("Autosave after swap/shape failed to load: "+str(loaded.get("error","")))
	elif loaded.state.heroes[0].dice[0].id != swapped_id or loaded.state.heroes[0].dice[4].shape != "D10": errors.append("Saved swap/shape did not persist")
	var resumed: Dictionary = engine.restore(loaded.get("state",{}),loaded.get("command_history",{}))
	if not resumed.get("ok",false): errors.append("Service checkpoint failed authority restore: "+str(resumed.get("error","")))
	engine.save_store.clear_checkpoint()
	print("Real autosave regression: postcombat die purchase, swap, shape reduction, reload and restore checked.")
