class_name RogueCombat
extends RefCounted
## Deterministic rules. Presentation never executes or repeats an effect.
const Catalog = preload("res://scripts/core/catalog.gd")

static func roll_die(die: Dictionary, rng: RandomNumberGenerator, roll_count: int = 0) -> Dictionary:
	var faces: Array = die.get("faces",[])
	if faces.is_empty():
		return {}
	var index: int = rng.randi_range(0,faces.size()-1)
	var face: Variant = faces[index]
	return {"die_id":str(die.id), "face_id":str(face.get("id",str(index))) if face is Dictionary else str(index), "face_index":index, "value":int(face.get("value",0)) if face is Dictionary else int(face), "roll_count":roll_count}

static func begin_battle(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	state.turn = 0
	state.battle_outcome = ""
	var events: Array = []
	for actor in state.get("heroes",[]):
		actor.block = 0
		actor.statuses = {"stun":0,"poison":0,"resolve":0}
		actor.combat_gold = 0
		actor.trait_charges = 1 if actor.get("trait","") == "SECOND_THOUGHT" else 0
		actor.action_eligible_from_turn = 1
		for item in actor.get("gems",[]):
			item.revive_charges = 1
		for item in actor.get("relics",[]):
			if item.key == "LASTING_AEGIS" and item.get("equipped",false):
				var amount: int = int(item.get("stored_block",0))
				actor.block += amount
				item.stored_block = 0
				if amount > 0:
					events.append({"kind":"block", "actor":actor.id, "target":actor.id, "skill":"LASTING_AEGIS", "amount":amount, "text":actor.name+" receives "+str(amount)+" stored block."})
	for enemy in state.get("enemies",[]):
		enemy.statuses = {"stun":0,"poison":0,"resolve":0}
		enemy.phase_turn = 0
		enemy.boss_phase = "normal"
	events.append_array(begin_turn(state,rng))
	return events

static func begin_turn(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	state.turn = int(state.get("turn",0))+1
	state.battle_outcome = ""
	for actor in state.get("heroes",[]):
		actor.hand = []
		actor.ready = false
		actor.rerolled = false
		actor.relic_flags = {}
		actor.rerolls = int(actor.get("max_rerolls",1)) if actor.hp > 0 else 0
		if actor.hp > 0:
			for die in actor.get("dice",[]):
				actor.hand.append(roll_die(die,rng))
		actor.initial_hand = actor.hand.duplicate(true)
	for enemy in state.get("enemies",[]):
		enemy.hand = []
		enemy.relic_flags = {}
		if enemy.hp > 0:
			for die in enemy.get("dice",[]):
				enemy.hand.append(roll_die(die,rng))
			enemy.intents = enemy_intents(enemy,state,rng)
		else:
			enemy.intents = []
	return [{"kind":"turn", "turn":state.turn, "text":"Turn "+str(state.turn)+(": Enrage +"+str(enrage(state))+" damage per enemy hit." if enrage(state) > 0 else ". Enemy intents are revealed.")}]

static func enrage(state: Dictionary) -> int:
	return maxi(0,(int(state.get("turn",1))-6)*2)

static func values(hand: Array) -> Array:
	var result: Array = []
	for roll in hand:
		result.append(int(roll.get("value",0)) if roll is Dictionary else int(roll))
	return result

static func _normalized_hand(hand: Array) -> Array:
	var normalized: Array = []
	for index in range(hand.size()):
		var roll: Variant = hand[index]
		var value: Variant = roll.get("value",null) if roll is Dictionary else roll
		if not (value is int or value is float) or float(value) != floor(float(value)) or int(value) < 1 or int(value) > 20:
			return []
		normalized.append({"value":int(value), "die_id":str(roll.get("die_id",index)) if roll is Dictionary else str(index)})
	normalized.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.value < b.value if a.value != b.value else a.die_id < b.die_id)
	return normalized

static func _matching(groups: Dictionary, count: int) -> Array:
	var matches: Array = []
	for value in groups:
		if groups[value].size() >= count:
			matches.append(value)
	matches.sort()
	return matches

static func _straight(groups: Dictionary, length: int) -> Array:
	var distinct: Array = groups.keys()
	distinct.sort()
	var chosen: Array = []
	for value in distinct:
		var candidate: Array = []
		for offset in range(length):
			if groups.has(value+offset):
				candidate.append(value+offset)
		if candidate.size() == length:
			chosen = candidate
	return chosen

static func _scaled(value: int, rank: int) -> int:
	return floori(float(value*(rank+3))/4.0)

static func effect(kind: String, amount: int, target: String = "self") -> Dictionary:
	return {"kind":kind, "amount":maxi(0,amount), "target":target}

static func preview(actor: Dictionary, item: Dictionary, hand: Array, state: Dictionary = {}) -> Dictionary:
	var key: String = Catalog.canonical_key(str(item.get("key","")))
	var output: Dictionary = {"valid":false, "active":false, "key":key, "name":key, "trigger":"", "reason":"Invalid skill or hand", "contributing_dice":[], "effects":[], "summary":"Invalid skill or hand"}
	if not Catalog.definitions("skills").has(key):
		return output
	var definition: Dictionary = Catalog.definitions("skills")[key]
	output.name = definition.name
	output.trigger = definition.trigger
	output.formula = definition.formula
	for property in ["carat","cut","clarity"]:
		var rank: Variant = item.get(property,1)
		if not (rank is int or rank is float) or float(rank) != floor(float(rank)):
			output.reason = "Gem properties must be integers"
			return output
	var c: int = int(item.get("carat",1))
	var k: int = int(item.get("cut",1))
	var stored_l: int = int(item.get("clarity",1))
	if c < 1 or c > 24 or k < 1 or k > 5 or stored_l < 1 or stored_l > 5:
		output.reason = "Gem properties are outside their legal bounds"
		return output
	var normalized: Array = _normalized_hand(hand)
	if normalized.is_empty():
		return output
	var l: int = mini(5,stored_l+1) if Catalog.has_relic(actor,"FOCUSING_PRISM") and "straight" in definition.tags else stored_l
	output.merge({"valid":true,"carat":c,"cut":k,"clarity":stored_l,"effective_clarity":l},true)
	var groups: Dictionary = {}
	var total: int = 0
	var odd: Array = []
	var even: Array = []
	for roll in normalized:
		if not groups.has(roll.value):
			groups[roll.value] = []
		groups[roll.value].append(roll.die_id)
		total += roll.value
		if roll.value % 2 == 0:
			even.append(roll)
		else:
			odd.append(roll)
	var pairs: Array = _matching(groups,2)
	var triples: Array = _matching(groups,3)
	var high: int = normalized.back().value
	var p: int = pairs.back() if not pairs.is_empty() else 0
	var selected: Array = []
	var effects: Array = []
	var active: bool = true
	var straight_length: int = 5-int((l-1)/2)
	match key:
		"STRIKE":
			var high_sum: int = 0
			for roll in normalized.slice(maxi(0,normalized.size()-k)):
				high_sum += roll.value
				selected.append(roll.die_id)
			effects.append(effect("damage",_scaled(high_sum+c,l),"enemy"))
		"BLOCK", "INTERPOSE":
			active = not pairs.is_empty()
			if active:
				selected = groups[p].slice(0,2)
				effects.append(effect("block",_scaled(p*k+c,l) if key == "BLOCK" else _scaled(p+c+k-1,l),"self" if key == "BLOCK" else "ally"))
		"HEAL":
			var low_sum: int = 0
			for roll in normalized.slice(0,mini(k,normalized.size())):
				low_sum += roll.value
				selected.append(roll.die_id)
			effects.append(effect("heal",_scaled(low_sum+c,l)))
		"MULTISTRIKE", "BLESSING", "ARC_BURST", "LIFELINE":
			var run: Array = _straight(groups,straight_length if key in ["MULTISTRIKE","LIFELINE"] else 3)
			active = not run.is_empty()
			if active:
				for value in run:
					selected.append(groups[value][0])
				match key:
					"MULTISTRIKE":
						for _hit in range(k):
							effects.append(effect("damage",c,"enemy"))
					"BLESSING":
						effects = [effect("gold",c),effect("heal",_scaled(k,l))]
					"ARC_BURST":
						var arc: Dictionary = effect("damage",_scaled(run.back()+c,l),"enemies")
						arc.target_limit = k+1
						effects.append(arc)
					"LIFELINE":
						var life: Dictionary = effect("lifeline",c+3*k,"revive")
						life.heal_amount = c+k
						life.charges = int(item.get("revive_charges",1))
						effects.append(life)
		"LUCKYSTRIKE":
			var sevens: Array = groups.get(7,[])
			active = not sevens.is_empty()
			var jackpot: int = (7 if l == 5 else l+1) if sevens.size() >= 3 else 1
			selected = sevens.duplicate()
			for _seven in sevens:
				effects.append(effect("damage",_scaled(7*jackpot,k),"enemy"))
				effects.append(effect("gold",c*jackpot))
		"HEAVYSTRIKE":
			active = not triples.is_empty()
			if active:
				var triple: int = triples.back()
				selected = groups[triple].slice(0,3)
				effects.append(effect("damage",_scaled(triple*k+c,l),"enemy"))
		"SHIELDBASH":
			active = false
			for triple in triples:
				for pair in pairs:
					if triple != pair:
						active = true
						selected = groups[triple].slice(0,3)+groups[pair].slice(0,2)
			if active:
				var bash: Dictionary = effect("damage",floori(float((int(actor.get("block",0))+c)*(k+1))/2.0),"enemy")
				bash.dynamic = "shield_bash"
				bash.numerator = k+1
				bash.denominator = 2
				effects = [effect("block",c),bash]
				if l == 5:
					effects.append(effect("stun",1,"enemy"))
		"STUN":
			active = high >= 21-l
			selected = [normalized.back().die_id]
			effects = [effect("damage",high+c,"enemy"),effect("stun",2 if k == 5 else 1,"enemy")]
		"BULWARK":
			active = total <= 18+2*l
			effects = [effect("block",Catalog.BULWARK_BLOCK[c-1]),effect("stun",Catalog.BULWARK_STUN[k-1])]
		"DRAINSTRIKE":
			active = total >= 45-5*l
			effects = [effect("damage",high*k,"enemy"),effect("heal",c)]
		"MEND":
			active = odd.size() >= 3
			if active:
				effects.append(effect("heal",_scaled(odd[0].value+c+2*(k-1),l),"ally"))
				for roll in odd:
					selected.append(roll.die_id)
		"SUNDER":
			active = pairs.size() >= 2
			if active:
				for pair in pairs.slice(pairs.size()-2):
					selected.append_array(groups[pair].slice(0,2))
				effects = [effect("remove_block",c+2*k,"enemy"),effect("damage",_scaled(p+c,l),"enemy")]
		"VENOM":
			active = high >= 13-l
			selected = [normalized.back().die_id]
			effects = [effect("damage",floori(float(high+c)/2.0),"enemy"),effect("poison",k+ceili(float(c)/4.0),"enemy")]
		"EVEN_TEMPO":
			active = even.size() >= 3
			for roll in even:
				selected.append(roll.die_id)
			effects = [effect("block",_scaled(even.size()*k+c,l)),effect("damage",c+k,"enemy")]
		"PRECISION":
			active = normalized.size() == 5 and groups.size() == 5
			if active:
				effects.append(effect("damage",_scaled(normalized[0].value+normalized[1].value+c+2*k,l),"enemy"))
	if selected.is_empty() and active:
		for roll in normalized:
			selected.append(roll.die_id)
	output.active = active
	output.effects = effects if active else []
	output.contributing_dice = selected if active else []
	output.reason = "Ready" if active else "Needs "+str(definition.trigger).to_lower()
	output.summary = effects_summary(output.effects,actor,state,key) if active else output.reason
	return output

static func preview_loadout(actor: Dictionary, state: Dictionary) -> Array:
	## Preview one actor's ordered batch against the current board. Earlier gems,
	## trait block, healing caps, relic use, deaths and fallback targets are included.
	## Uses copied state and the exact resolver; consumes no RNG or resources.
	var copied: Dictionary = state.duplicate(true)
	var simulated: Dictionary = _find(copied.get("heroes",[])+copied.get("enemies",[]),str(actor.get("id","")))
	if simulated.is_empty():
		simulated = actor.duplicate(true)
		copied.heroes = [simulated]
		copied.enemies = []
	var previews: Array = []
	var skipped: bool = simulated.hp <= 0 or int(simulated.get("statuses",{}).get("stun",0)) > 0 or int(simulated.get("action_eligible_from_turn",1)) > int(state.get("turn",1))
	var encounter_finished: bool = false
	if not skipped:
		_start_trait(simulated,copied,[])
	for item in simulated.get("gems",[]):
		if not item.get("equipped",false):
			continue
		var result: Dictionary = preview(simulated,item,simulated.get("hand",[]),copied)
		result.gem_id = item.id
		result.will_be_skipped = skipped or encounter_finished
		result.resolved_events = []
		if result.active and not result.will_be_skipped:
			resolve_skill(simulated,result,copied,result.resolved_events,item)
			var descriptions: PackedStringArray = []
			for event in result.resolved_events:
				if event.kind != "skill":
					descriptions.append(str(event.text))
			result.summary = " ".join(descriptions)
			encounter_finished = _living(copied.get("heroes",[])).is_empty() or _living(copied.get("enemies",[])).is_empty()
		elif result.will_be_skipped:
			result.summary = "The encounter ends before this skill." if encounter_finished else "This actor's slot will be skipped."
		previews.append(result)
	return previews

static func forecast_turn(state: Dictionary) -> Dictionary:
	## Full-party forecast for the currently displayed hands and published intents.
	## Planning changes cause callers to regenerate it, never to commit this copy.
	var copied: Dictionary = state.duplicate(true)
	var events: Array = resolve_turn(copied,RandomNumberGenerator.new())
	return {"state":copied,"events":events,"outcome":copied.get("battle_outcome","")}

static func effects_summary(effects: Array, actor: Dictionary = {}, state: Dictionary = {}, key: String = "") -> String:
	var parts: PackedStringArray = []
	for action_effect in effects:
		var amount: int = int(action_effect.amount)
		var suffix: String = ""
		if action_effect.get("target","") == "enemies":
			suffix = " to up to "+str(action_effect.get("target_limit","all"))+" enemies"
		elif action_effect.get("target","") == "ally":
			suffix = " to ally"
		elif action_effect.get("target","") == "self":
			suffix = " to self"
		if action_effect.kind == "damage" and key == "STRIKE" and Catalog.has_relic(actor,"STEADY_HAND") and not actor.get("rerolled",false):
			amount += 2
		if action_effect.kind == "block" and key == "BLOCK" and Catalog.has_relic(actor,"MATCHBOX"):
			amount += 2
		if action_effect.kind == "gold" and not state.is_empty():
			suffix += " ("+str(maxi(0,8+4*(int(state.get("act",1))-1)-int(actor.get("combat_gold",0))))+" battle allowance left)"
		if action_effect.kind == "lifeline":
			parts.append("Revive "+str(amount)+" HP ("+str(action_effect.get("charges",1))+" charge), otherwise heal "+str(action_effect.heal_amount))
		else:
			parts.append(str(amount)+" "+str(action_effect.kind).replace("_"," ")+suffix)
		if action_effect.has("condition"):
			parts.append("+"+str(action_effect.get("bonus",0))+" damage if "+str(action_effect.condition).replace("_"," ")+" "+str(action_effect.get("threshold",action_effect.get("marked_value",""))))
	return "; ".join(parts)

static func _living(units: Array) -> Array:
	return units.filter(func(unit: Dictionary) -> bool: return int(unit.get("hp",0)) > 0)

static func _find(units: Array, id: String) -> Dictionary:
	for unit in units:
		if str(unit.get("id","")) == id:
			return unit
	return {}

static func _sides(actor: Dictionary, state: Dictionary) -> Array:
	return [state.get("heroes",[]),state.get("enemies",[])] if actor.get("side","hero") == "hero" else [state.get("enemies",[]),state.get("heroes",[])]

static func _hostile_target(actor: Dictionary, state: Dictionary, preferred: String = "") -> Dictionary:
	var enemies: Array = _living(_sides(actor,state)[1])
	var chosen: Dictionary = _find(enemies,preferred if not preferred.is_empty() else str(actor.get("preferred_target","")))
	return chosen if not chosen.is_empty() else (enemies[0] if not enemies.is_empty() else {})

static func _friendly_target(actor: Dictionary, state: Dictionary, preferred: String = "") -> Dictionary:
	var allies: Array = _living(_sides(actor,state)[0])
	var chosen: Dictionary = _find(allies,preferred if not preferred.is_empty() else str(actor.get("friendly_target",actor.id)))
	return chosen if not chosen.is_empty() else actor

static func enemy_intents(actor: Dictionary, state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var intents: Array = []
	var heroes: Array = _living(state.get("heroes",[]))
	if heroes.is_empty():
		return intents
	var target: Dictionary = heroes[rng.randi_range(0,heroes.size()-1)]
	if actor.key == "RIFT_HOUND":
		for candidate in heroes:
			if candidate.block < target.block:
				target = candidate
		# Stable seat ties must override the random provisional target.
		for candidate in heroes:
			if candidate.block == target.block:
				target = candidate
				break
	var rolled: Array = values(actor.get("hand",[]))
	var high: int = int(rolled.max()) if not rolled.is_empty() else 0
	var low: int = int(rolled.min()) if not rolled.is_empty() else 0
	var first: bool = int(state.get("turn",1)) % 2 == 1
	var p: int = int(actor.get("party_size",state.get("party_size",1)))
	match str(actor.key):
		"SLIME", "RED_SLIME":
			for item in actor.gems:
				intents.append(preview(actor,item,actor.hand,state))
		"STONE_CRAB":
			intents.append(_intent("SHELL_UP" if first else "CLAW","Shell Up" if first else "Claw",[effect("block",low+3)] if first else [effect("damage",high+3,"enemy")]))
		"GEM_CULTIST":
			var wounded: Dictionary = {}
			var missing: int = 4
			for ally in _living(state.get("enemies",[])):
				if int(ally.max_hp)-int(ally.hp) > missing:
					wounded = ally
					missing = int(ally.max_hp)-int(ally.hp)
			if wounded.is_empty():
				intents.append(_intent("SHARD","Shard",[effect("damage",high+1,"enemy")]))
			else:
				var restore: Dictionary = _intent("RESTORE","Restore",[effect("heal",low+2,"ally")])
				restore.friendly_target_id = wounded.id
				intents.append(restore)
		"DARTLING":
			var dart: Dictionary = _intent("BARBED_DART","Barbed Dart",[effect("damage",high+1,"enemy")])
			if preview(actor,Catalog.gem("BLOCK","test"),actor.hand,state).active:
				dart.effects.append(effect("poison",2,"enemy"))
			intents.append(dart)
		"IRON_WARDEN":
			intents.append(_intent("FORTIFY" if first else "HAMMER","Fortify" if first else "Hammer",[effect("block",low+4),effect("block",4,"other_allies")] if first else [effect("damage",high+5,"enemy")]))
		"MIRROR_WISP":
			var reflected: Dictionary = effect("damage",high+1,"enemy")
			reflected.merge({"condition":"contains", "marked_value":rng.randi_range(1,6), "bonus":4})
			intents.append(_intent("REFLECTION","Reflection",[reflected]))
		"RIFT_HOUND":
			intents.append(_intent("TRACK" if first else "POUNCE","Track" if first else "Pounce",[effect("damage",high+(1 if first else 4),"enemy")]))
		"SLIME_KING":
			var cycle: int = int(actor.get("phase_turn",0)) % 3
			intents.append([_intent("SLAM","Slam",[effect("damage",10,"enemies")]),_intent("FORTIFY","Fortify",[effect("block",8*p)]),_intent("ABSORB","Absorb",[effect("heal",6*p)])][cycle])
		"MIRROR_REGENT":
			if actor.hp*2 <= actor.max_hp and actor.boss_phase != "fractured":
				actor.boss_phase = "fractured"
				actor.phase_turn = 0
			var cycle: int = int(actor.get("phase_turn",0)) % (2 if actor.boss_phase == "fractured" else 3)
			if cycle == 0:
				var refraction: Dictionary = effect("damage",8,"enemies")
				refraction.merge({"condition":"contains", "marked_value":rng.randi_range(1,6), "bonus":6})
				intents.append(_intent("REFRACTION","Refraction",[refraction]))
			elif cycle == 1:
				intents.append(_intent("SHATTER","Shatter",[effect("remove_block",5,"enemies"),effect("damage",6,"enemies")]))
			else:
				intents.append(_intent("MENDING_GLASS","Mending Glass",[effect("heal",5*p),effect("block",5*p)]))
		"RIFT_SOVEREIGN":
			if actor.hp*5 <= actor.max_hp*2 and actor.boss_phase != "convergence":
				actor.boss_phase = "convergence"
				actor.phase_turn = 0
			var high_tide: Dictionary = effect("damage",10,"enemies")
			high_tide.merge({"condition":"total_at_least","threshold":24,"bonus":6})
			var low_tide: Dictionary = effect("damage",10,"enemies")
			low_tide.merge({"condition":"total_at_most","threshold":18,"bonus":6})
			if actor.boss_phase == "convergence":
				intents = [_intent("HIGH_TIDE","High Tide",[high_tide]),_intent("LOW_TIDE","Low Tide",[low_tide])]
			else:
				var cycle: int = int(actor.get("phase_turn",0)) % 3
				intents.append([_intent("HIGH_TIDE","High Tide",[high_tide]),_intent("LOW_TIDE","Low Tide",[low_tide]),_intent("ECLIPSE","Eclipse",[effect("remove_block",3,"enemies"),effect("damage",6,"enemies"),effect("block",6*p)])][cycle])
	actor.phase_turn = int(actor.get("phase_turn",0))+1
	for intent in intents:
		intent.target_id = target.id
		intent.will_be_skipped = int(actor.statuses.get("stun",0)) > 0
		for action_effect in intent.effects:
			var amount: int = int(action_effect.amount)
			if not actor.get("boss",false):
				var tier: int = clampi(int(actor.get("act",1)),1,3)-1
				if action_effect.kind == "damage":
					amount += tier*2
				elif action_effect.kind in ["block","heal"]:
					amount = floori(float(amount)*[1.0,1.2,1.4][tier])
			if action_effect.kind == "damage":
				action_effect.enrage_bonus = enrage(state)
				amount += enrage(state)
			action_effect.amount = amount
		intent.summary = effects_summary(intent.effects,actor,state)
	return intents

static func _intent(key: String, name: String, effects: Array) -> Dictionary:
	return {"key":key,"name":name,"active":true,"valid":true,"effects":effects}

static func resolve_turn(state: Dictionary, _rng: RandomNumberGenerator) -> Array:
	var events: Array = []
	if not str(state.get("battle_outcome","")).is_empty():
		return events
	var actors: Array = state.get("heroes",[])+state.get("enemies",[])
	for actor in actors:
		if actor.hp <= 0:
			continue
		var statuses: Dictionary = actor.get("statuses",{})
		var entry_resolve: int = int(statuses.get("resolve",0))
		var eligible: bool = int(actor.get("action_eligible_from_turn",1)) <= int(state.get("turn",1))
		var stunned: bool = int(statuses.get("stun",0)) > 0
		if eligible and stunned:
			statuses.stun = int(statuses.stun)-1
			events.append(_event("skip",actor,actor,"STUN",0,actor.name+" skips their slot (stun)."))
			if actor.get("boss",false):
				statuses.resolve = 2
				events.append(_event("status",actor,actor,"RESOLVE",2,actor.name+" gains Resolve for two future slots."))
		elif eligible:
			_start_trait(actor,state,events)
			if actor.get("side","hero") == "hero":
				for item in actor.get("gems",[]):
					if not item.get("equipped",false):
						continue
					var action: Dictionary = preview(actor,item,actor.get("hand",[]),state)
					if not action.active:
						events.append(_event("inactive",actor,actor,action.key,0,actor.name+": "+action.name+" — "+action.reason+"."))
						continue
					resolve_skill(actor,action,state,events,item)
					if _outcome(state,events):
						return events
			else:
				for action in actor.get("intents",[]):
					if action.get("active",true):
						resolve_skill(actor,action,state,events)
						if _outcome(state,events):
							return events
		else:
			events.append(_event("skip",actor,actor,"REVIVED",0,actor.name+" can act starting next turn."))
		if actor.hp > 0 and int(statuses.get("poison",0)) > 0:
			var poison: int = int(statuses.poison)
			var loss: int = mini(int(actor.hp),poison)
			actor.hp -= loss
			statuses.poison = maxi(0,poison-1) if actor.hp > 0 else 0
			var tick: Dictionary = _event("poison_tick",actor,actor,"POISON",poison,actor.name+" loses "+str(loss)+" HP to Poison; "+str(statuses.poison)+" stacks remain.")
			tick.hp_loss = loss
			tick.remaining = statuses.poison
			events.append(tick)
			if _outcome(state,events):
				return events
		if entry_resolve > 0:
			statuses.resolve = maxi(0,int(statuses.get("resolve",0))-1)
	_outcome(state,events)
	return events

static func _start_trait(actor: Dictionary, state: Dictionary, events: Array) -> void:
	var amount: int = 0
	var trait_id: String = str(actor.get("trait",""))
	if trait_id == "STAND_FIRM" and preview(actor,Catalog.gem("BLOCK","trait"),actor.get("hand",[]),state).active:
		amount = 2
	elif trait_id == "CALCULATED_RISK":
		var initial: Dictionary = {}
		for roll in actor.get("initial_hand",[]):
			initial[roll.die_id] = int(roll.value)
		for roll in actor.get("hand",[]):
			if initial.has(roll.die_id) and int(roll.value)-int(initial[roll.die_id]) >= 4:
				amount = 3
	if amount > 0:
		actor.block += amount
		events.append(_event("block",actor,actor,trait_id,amount,actor.name+" gains "+str(amount)+" block from "+trait_id.replace("_"," ").capitalize()+"."))

static func resolve_skill(actor: Dictionary, action: Dictionary, state: Dictionary, events: Array, item: Dictionary = {}) -> void:
	if actor.hp <= 0:
		return
	var sides: Array = _sides(actor,state)
	var target: Dictionary = _hostile_target(actor,state,str(action.get("target_id","")))
	var friendly: Dictionary = _friendly_target(actor,state,str(action.get("friendly_target_id","")))
	var enemies: Array = _living(sides[1])
	if not target.is_empty():
		enemies.erase(target)
		enemies.push_front(target)
	var allies: Array = _living(sides[0])
	var key: String = str(action.key)
	var preferred: String = str(action.get("target_id",actor.get("preferred_target","")))
	if not preferred.is_empty() and not target.is_empty() and preferred != str(target.id):
		events.append(_event("retarget",actor,target,key,0,actor.name+" retargets "+str(action.name)+" to "+str(target.name)+"."))
	events.append(_event("skill",actor,target if not target.is_empty() else actor,key,0,actor.name+" uses "+str(action.name)+"."))
	for action_effect in action.effects:
		var recipients: Array = []
		match str(action_effect.get("target","self")):
			"enemy":
				recipients = [target] if not target.is_empty() else []
			"enemies":
				recipients = enemies.slice(0,mini(enemies.size(),int(action_effect.get("target_limit",enemies.size()))))
			"ally":
				recipients = [friendly]
			"allies":
				recipients = allies
			"other_allies":
				recipients = allies.filter(func(unit: Dictionary) -> bool: return unit.id != actor.id)
			"revive":
				var downed: Array = sides[0].filter(func(unit: Dictionary) -> bool: return unit.hp <= 0)
				var preferred_downed: Dictionary = _find(downed,str(actor.get("friendly_target","")))
				if not downed.is_empty() and int(item.get("revive_charges",action_effect.get("charges",1))) > 0:
					recipients = [preferred_downed if not preferred_downed.is_empty() else downed[0]]
				else:
					recipients = [friendly]
			_:
				recipients = [actor]
		for recipient in recipients:
			if recipient.hp <= 0 and action_effect.kind != "lifeline":
				events.append(_event("fizzle",actor,recipient,key,0,str(action.name)+" has no effect on downed "+str(recipient.name)+"."))
				continue
			_apply_effect(actor,recipient,action_effect,key,state,events,item)

static func _apply_effect(actor: Dictionary, target: Dictionary, action_effect: Dictionary, key: String, state: Dictionary, events: Array, item: Dictionary) -> void:
	var kind: String = str(action_effect.kind)
	var amount: int = int(action_effect.get("amount",0))
	var sources: Array = []
	var flags: Dictionary = actor.get("relic_flags",{})
	actor.relic_flags = flags
	if action_effect.get("dynamic","") == "shield_bash":
		amount = floori(float(int(actor.block)*int(action_effect.numerator))/float(action_effect.denominator))
	if kind == "damage":
		if action_effect.has("condition"):
			var hand: Array = values(target.get("hand",[]))
			var total: int = 0
			for value in hand:
				total += value
			var triggered: bool = (action_effect.condition == "contains" and int(action_effect.get("marked_value",0)) in hand) or (action_effect.condition == "total_at_least" and total >= int(action_effect.get("threshold",0))) or (action_effect.condition == "total_at_most" and total <= int(action_effect.get("threshold",0)))
			if triggered:
				amount += int(action_effect.get("bonus",0))
				sources.append({"source":"intent_condition","amount":int(action_effect.get("bonus",0))})
		if key == "STRIKE" and Catalog.has_relic(actor,"STEADY_HAND") and not actor.get("rerolled",false) and not flags.get("steady_hand",false):
			amount += 2
			flags.steady_hand = true
			sources.append({"source":"STEADY_HAND","amount":2})
		var absorbed: int = mini(int(target.block),amount)
		var loss: int = mini(int(target.hp),amount-absorbed)
		target.block -= absorbed
		target.hp -= loss
		if target.hp <= 0:
			target.statuses.poison = 0
		var hit: Dictionary = _event("damage",actor,target,key,amount,str(actor.name)+" → "+str(target.name)+": "+str(amount)+" damage, "+str(absorbed)+" blocked, "+str(loss)+" HP lost.")
		hit.merge({"raw_damage":amount,"block_absorbed":absorbed,"hp_loss":loss,"sources":sources,"enrage_bonus":int(action_effect.get("enrage_bonus",0))})
		events.append(hit)
	elif kind == "block":
		if key == "BLOCK" and Catalog.has_relic(actor,"MATCHBOX") and not flags.get("matchbox",false):
			amount += 2
			flags.matchbox = true
			sources.append({"source":"MATCHBOX","amount":2})
		target.block += amount
		var block_event: Dictionary = _event("block",actor,target,key,amount,target.name+" gains "+str(amount)+" block.")
		block_event.sources = sources
		events.append(block_event)
	elif kind == "heal" or (kind == "lifeline" and target.hp > 0):
		if kind == "lifeline":
			amount = int(action_effect.heal_amount)
		if amount > 0 and target.hp < target.max_hp and Catalog.has_relic(actor,"FIELD_DRESSING") and not flags.get("field_dressing",false):
			amount += 2
			flags.field_dressing = true
			sources.append({"source":"FIELD_DRESSING","amount":2})
		var gained: int = mini(int(target.max_hp)-int(target.hp),amount)
		target.hp += gained
		var heal_event: Dictionary = _event("heal",actor,target,key,gained,target.name+" recovers "+str(gained)+" HP ("+str(amount)+" before cap).")
		heal_event.requested = amount
		heal_event.sources = sources
		events.append(heal_event)
	elif kind == "lifeline":
		target.hp = mini(int(target.max_hp),amount)
		target.block = 0
		target.statuses = {"stun":0,"poison":0,"resolve":0}
		target.action_eligible_from_turn = int(state.get("turn",1))+1
		item.revive_charges = maxi(0,int(item.get("revive_charges",1))-1)
		events.append(_event("revive",actor,target,key,int(target.hp),target.name+" returns with "+str(target.hp)+" HP and can act next turn."))
	elif kind == "gold":
		var allowance: int = maxi(0,8+4*(int(state.get("act",1))-1)-int(actor.get("combat_gold",0)))
		var granted: int = mini(allowance,amount)
		actor.gold = int(actor.get("gold",0))+granted
		actor.combat_gold = int(actor.get("combat_gold",0))+granted
		var gold_event: Dictionary = _event("gold",actor,actor,key,granted,actor.name+" gains "+str(granted)+" gold ("+str(amount)+" requested; "+str(allowance-granted)+" combat allowance remains).")
		gold_event.requested = amount
		gold_event.source = "combat_skill"
		events.append(gold_event)
	elif kind == "remove_block":
		var removed: int = mini(int(target.block),amount)
		target.block -= removed
		var removal: Dictionary = _event("remove_block",actor,target,key,removed,target.name+" loses "+str(removed)+" block.")
		removal.requested = amount
		events.append(removal)
	elif kind in ["stun","poison"]:
		var statuses: Dictionary = target.get("statuses",{})
		var before: int = int(statuses.get(kind,0))
		var applied: int = amount
		var rejected: bool = false
		if kind == "poison":
			applied = mini(12-before,amount)
		elif target.get("boss",false) and actor.id != target.id:
			if int(statuses.get("resolve",0)) > 0:
				applied = 0
				rejected = true
			else:
				applied = mini(maxi(0,1-before),amount)
		statuses[kind] = before+applied
		target.statuses = statuses
		var status_event: Dictionary = _event("status",actor,target,key,applied,target.name+(" resists stun with Resolve." if rejected else " gains "+str(applied)+" "+kind+" ("+str(before+applied)+" total)."))
		status_event.merge({"status":kind,"requested":amount,"applied":applied,"remaining":before+applied,"rejected":rejected})
		events.append(status_event)

static func _event(kind: String, actor: Dictionary, target: Dictionary, skill: String, amount: int, message: String) -> Dictionary:
	return {"kind":kind,"actor":str(actor.get("id","")),"target":str(target.get("id","")),"skill":skill,"amount":amount,"text":message}

static func _outcome(state: Dictionary, events: Array) -> bool:
	var result: String = ""
	if _living(state.get("heroes",[])).is_empty():
		result = "defeat"
	elif _living(state.get("enemies",[])).is_empty():
		result = "victory"
	if not result.is_empty():
		if str(state.get("battle_outcome","")) != result:
			state.battle_outcome = result
			events.append({"kind":"outcome","outcome":result,"text":"The party is victorious." if result == "victory" else "The party has fallen."})
		return true
	return false
