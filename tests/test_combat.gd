extends SceneTree
const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const RandomSource = preload("res://scripts/core/random_source.gd")
const ContentPack = preload("res://scripts/core/content_pack.gd")
var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_catalog()
	_test_skill_formulas()
	_test_resolution()
	_test_status_timing()
	_test_traits_relics()
	_test_intents()
	_test_determinism()
	_test_authoring_and_forecasts()
	print("Combat/content: %d assertions, %d failures" % [checks,failures.size()])
	for failure in failures:
		printerr("FAIL: "+str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func hand(numbers: Array) -> Array:
	var result: Array = []
	for index in range(numbers.size()):
		result.append({"die_id":"d"+str(index),"value":numbers[index],"face_id":"f"+str(index),"roll_count":0})
	return result

func hero(key: String = "ARDOR", id: String = "h") -> Dictionary:
	var unit: Dictionary = Catalog.hero(key,id)
	unit.hand = hand([2,2,4,6,8])
	unit.initial_hand = unit.hand.duplicate(true)
	unit.gems = []
	unit.trait = ""
	return unit

func state_for(unit: Dictionary, enemy: Dictionary = {}) -> Dictionary:
	if enemy.is_empty():
		enemy = Catalog.enemy("SLIME","e")
		enemy.hp = 1000
		enemy.max_hp = 1000
		enemy.intents = []
	return {"heroes":[unit],"enemies":[enemy],"turn":1,"act":1,"party_size":1,"battle_outcome":""}

func skill(key: String, numbers: Array, c: int = 1, k: int = 1, l: int = 1) -> Dictionary:
	return Combat.preview(hero(),Catalog.gem(key,"gem",c,k,l),hand(numbers),{})

func cast(unit: Dictionary, item: Dictionary, state: Dictionary) -> Array:
	var events: Array = []
	var action: Dictionary = Combat.preview(unit,item,unit.hand,state)
	if action.active:
		Combat.resolve_skill(unit,action,state,events,item)
	return events

func equip(unit: Dictionary, key: String, c: int = 1, k: int = 1, l: int = 1) -> Dictionary:
	var item: Dictionary = Catalog.gem(key,unit.id+"-"+key,c,k,l)
	item.equipped = true
	unit.gems.append(item)
	return item

func relic(unit: Dictionary, key: String) -> Dictionary:
	var item: Dictionary = Catalog.relic(key,unit.id+"-"+key)
	item.equipped = true
	unit.relics.append(item)
	return item

func _test_catalog() -> void:
	check(Catalog.validate_content().is_empty(),"All content IDs, face definitions and references validate")
	check(Catalog.SKILLS.size() == 19,"Nineteen skills")
	check(Catalog.ENEMIES.size() == 11,"Eight ordinary/elite enemy types and three bosses")
	check(Catalog.gem("BULLWARK","b").key == "BULWARK","Legacy Bullwark import alias")
	check(Catalog.gem_value(Catalog.gem("HEAL","g",5,2,3)) == 22,"Gem buy value")
	check(Catalog.die_value(Catalog.die("SPLIT_D20","d")) == 22,"Alternative die value")
	for key in Catalog.DICE:
		var definition: Dictionary = Catalog.DICE[key]
		var total: int = 0
		for face in definition.faces:
			total += face
		check(total*2 == definition.faces.size()*(definition.faces.size()+1),"Die preserves mean: "+key)
	var a: Dictionary = Catalog.hero("ARDOR","a")
	var b: Dictionary = Catalog.hero("ARDOR","b")
	a.dice[0].faces[0].value = 6
	a.gems[0].carat = 24
	check(b.dice[0].faces[0].value == 1 and b.gems[0].carat == 1,"Instances do not mutate shared templates")
	check(not "LIFELINE" in Catalog.eligible_skills("expedition_18",1),"Lifeline excluded from solo loot")
	check("LIFELINE" in Catalog.eligible_skills("expedition_18",2),"Lifeline available in full co-op")
	for party_size in range(1,5):
		for act in range(1,4):
			for kind in ["battle","elite","boss"]:
				var encounter: Array = Catalog.encounter(kind,act,party_size,2,"expedition_18")
				check(encounter.size() <= 4 and encounter.size() > 0,"Bounded authored encounter "+str([party_size,act,kind]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 735
	for profile in ["short_9","expedition_18"]:
		for act in range(1,4):
			for luck in [0,9,15,20]:
				var gems: Array = Catalog.generate_gems(rng,50,profile,act,luck,"test",2,true)
				var found: Dictionary = {}
				for item in gems:
					check(not found.has(item.key),"Unique skill keys per offer set")
					found[item.key] = true
					check(item.carat >= 1 and item.carat <= 24 and item.cut >= 1 and item.cut <= 5 and item.clarity >= 1 and item.clarity <= 5,"Generated properties valid")
	check(RandomSource.weighted_index(rng,[0,0,0]) == -1,"Empty eligible weighted pool safe")
	check(RandomSource.weighted_index(rng,[0,0,1]) == 2,"Weighted bucket index preserved")

func _test_skill_formulas() -> void:
	check(skill("STRIKE",[2,2,4,6,8]).effects[0].amount == 9,"Shared hand Strike is 9")
	check(skill("BLOCK",[2,2,4,6,8],2).effects[0].amount == 4,"Shared hand Block is 4")
	check(skill("HEAL",[2,2,4,6,8],2,2,3).effects[0].amount == 9,"Corrected Heal scales whole sum")
	check(skill("MULTISTRIKE",[1,2,2,3,4],3,2,3).effects.size() == 2,"Straight ignores duplicate and creates K hits")
	check(skill("HEAVYSTRIKE",[2,2,2,6,6,6],1).effects[0].amount == 7,"Highest triple selected in larger hand")
	check(skill("BLOCK",[2,2,2,6,6],1).effects[0].amount == 7,"Highest pair selected; triple is usable pair")
	check(skill("BLOCK",[4,4,4,4,5],1).effects[0].amount == 5,"Quad contains pair")
	check(skill("SHIELDBASH",[2,2,3,3,3],2,2).active,"Full house triggers Shield Bash")
	check(not skill("SHIELDBASH",[2,2,2,2,3]).active,"Quad and singleton not full house")
	check(skill("ARC_BURST",[1,2,2,3,4]).effects[0].amount == 5,"Highest qualifying three-value straight selected")
	check(skill("ARC_BURST",[1,2,2,3,4]).contributing_dice == ["d1","d3","d4"],"Straight highlights stable representative IDs")
	check(skill("MEND",[1,3,3,5,12],2,2).effects[0].amount == 5,"Mend odd formula")
	check(skill("VENOM",[1,3,3,5,12],2,2).effects[0].amount == 7,"Venom damage formula")
	check(skill("VENOM",[1,3,3,5,12],2,2).effects[1].amount == 3,"Venom Poison formula")
	check(skill("EVEN_TEMPO",[2,4,6,7,9],2,2,3).effects[0].amount == 12,"Even Tempo parity block")
	check(skill("PRECISION",[1,3,5,7,9],2,2,3).effects[0].amount == 15,"Precision distinct formula")
	check(not skill("PRECISION",[1,1,5,7,9]).active,"Precision rejects a duplicate")
	check(skill("SUNDER",[2,2,3,3,3]).active,"Full house contains two pairs")
	check(not skill("SUNDER",[2,2,2,2,3]).active,"Quad is not two distinct pairs")
	check(not skill("STUN",[1,2,3,4,19],1,1,1).active,"Stun 19 fails at L1")
	check(skill("STUN",[1,2,3,4,19],1,1,2).active,"Stun 19 succeeds at L2")
	check(not skill("BULWARK",[1,2,3,5,10],1,1,1).active,"Bulwark 21 fails at L1")
	check(skill("BULWARK",[1,2,3,5,10],1,1,2).active,"Bulwark 21 succeeds at L2")
	for l in range(1,6):
		var threshold: int = 45-5*l
		check(skill("DRAINSTRIKE",[threshold-20,5,5,5,5],1,1,l).active if threshold > 20 else skill("DRAINSTRIKE",[4,4,4,4,4],1,1,l).active,"Drain inclusive threshold L"+str(l))
		var below: Array = [threshold-20,5,5,5,4] if threshold > 20 else [3,4,4,4,4]
		check(not skill("DRAINSTRIKE",below,1,1,l).active,"Drain below threshold L"+str(l))
		for k in range(1,6):
			for c in [1,24]:
				check(skill("STUN",[20,1,2,3,4],c,k,l).effects[1].amount == (2 if k == 5 else 1),"Stun cut duration boundary")
				check(skill("BULWARK",[1,1,1,1,1],c,k,l).effects[0].amount == (10 if c == 1 else 300),"Bulwark carat boundary")
	for sevens in range(5):
		var numbers: Array = [1,2,3,4,5]
		for index in range(sevens):
			numbers[index] = 7
		var action: Dictionary = skill("LUCKYSTRIKE",numbers,2,1,2)
		check(action.active == (sevens > 0),"Lucky activation for "+str(sevens)+" sevens")
		check(action.effects.size() == sevens*2,"Lucky hit and gold effect count")
		if sevens > 0:
			check(action.effects[0].amount == (21 if sevens >= 3 else 7),"Lucky jackpot scaling")
	check(skill("LUCKYSTRIKE",[7,7,7,7,7],1,1,5).effects[0].amount == 49,"L5 jackpot multiplier is seven")
	check(not Combat.preview(hero(),Catalog.gem("STRIKE","x"),[]).valid,"Empty hand rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","carat":0},hand([1,2,3,4,5])).valid,"Zero Carat rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","carat":1.5},hand([1,2,3,4,5])).valid,"Fractional property rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","cut":6},hand([1,2,3,4,5])).valid,"Out of bounds rank rejected")
	check(not skill("STRIKE",[0,1,2,3,4]).valid,"Invalid die value rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","carat":[]},hand([1,2,3,4,5])).valid,"Malformed property container rejected without conversion crash")

func _test_resolution() -> void:
	var unit: Dictionary = hero()
	var state: Dictionary = state_for(unit)
	unit.hand = hand([2,2,3,3,3])
	unit.block = 5
	var events: Array = cast(unit,Catalog.gem("SHIELDBASH","g",2,2,1),state)
	check(unit.block == 7 and state.enemies[0].hp == 990,"Shield Bash gains own block before dynamic damage (7 × 1.5 = 10)")
	unit.hand = hand([1,2,3,4,5])
	state.enemies[0].block = 7
	var second: Dictionary = Catalog.enemy("SLIME","e2")
	second.hp = 100
	state.enemies.append(second)
	cast(unit,Catalog.gem("ARC_BURST","arc",5,3,1),state)
	check(state.enemies[0].hp == 987 and second.hp == 90,"Group damage mitigates independently (10 vs 7 and 0 block)")
	state.enemies = [second]
	var arc_events: Array = cast(unit,Catalog.gem("ARC_BURST","arc",5,3,1),state)
	check(arc_events.filter(func(event: Dictionary) -> bool: return event.kind == "damage").size() == 1,"Arc Burst one target means one hit despite K3")
	unit.hp = 99
	var ally: Dictionary = hero("KAIT","ally")
	ally.hp = 69
	state.heroes.append(ally)
	unit.friendly_target = ally.id
	unit.hand = hand([1,3,5,7,9])
	cast(unit,Catalog.gem("MEND","mend",24,5,5),state)
	check(ally.hp == 70,"Recipient's own maximum HP caps support heal")
	unit.hand = hand([2,2,3,3,3])
	second.block = 3
	second.hp = 100
	cast(unit,Catalog.gem("SUNDER","sun",3,2,1),state)
	check(second.hp == 94 and second.block == 0,"Sunder removes only existing block; no overflow damage")
	unit.hand = hand([1,2,3,4,5])
	second.hp = 2
	state.enemies.append(Catalog.enemy("SLIME","e3"))
	var hp_before: int = state.enemies[1].hp
	cast(unit,Catalog.gem("MULTISTRIKE","multi",3,3),state)
	check(state.enemies[1].hp == hp_before,"Multistrike remaining hits fizzle on dead fixed target")
	cast(unit,Catalog.gem("STRIKE","strike"),state)
	check(state.enemies[1].hp == hp_before-6,"Next skill retargets first living enemy")
	var lucky: Dictionary = hero()
	lucky.hand = hand([7,7,7,1,2])
	equip(lucky,"LUCKYSTRIKE",2,1,2)
	lucky.combat_gold = 7
	var lucky_state: Dictionary = state_for(lucky,Catalog.enemy("SLIME","last"))
	lucky_state.enemies[0].hp = 1
	Combat.resolve_turn(lucky_state,RandomNumberGenerator.new())
	check(lucky_state.battle_outcome == "victory" and lucky.gold == 1 and lucky.combat_gold == 8,"Killing Lucky Strike finishes self gold effects, respects allowance, settles once")
	check(Combat.resolve_turn(lucky_state,RandomNumberGenerator.new()).is_empty(),"Completed combat cannot resolve again")
	var rescue: Dictionary = hero("MAX","rescue")
	rescue.hand = hand([1,2,3,4,5])
	var life: Dictionary = equip(rescue,"LIFELINE",2,2,1)
	var downed: Dictionary = hero("ARDOR","downed")
	downed.hp = 0
	downed.block = 20
	downed.statuses = {"stun":3,"poison":5,"resolve":0}
	equip(downed,"STRIKE",24,5,5)
	rescue.friendly_target = downed.id
	var rescue_state: Dictionary = state_for(rescue)
	rescue_state.heroes.append(downed)
	Combat.resolve_turn(rescue_state,RandomNumberGenerator.new())
	check(downed.hp == 8 and downed.block == 0 and downed.statuses.stun == 0 and downed.statuses.poison == 0,"Lifeline revival clears block/statuses and restores exact HP")
	check(downed.action_eligible_from_turn == 2 and rescue_state.enemies[0].hp == 1000,"Later-seat revived hero cannot act this turn")
	check(life.revive_charges == 0,"Lifeline charge consumed by revival")
	var fresh: Dictionary = Catalog.gem("LIFELINE","fresh",2,2,1)
	cast(rescue,fresh,rescue_state)
	check(fresh.revive_charges == 1 and downed.hp == 12,"Lifeline ordinary heal keeps revival charge")

func _test_status_timing() -> void:
	var unit: Dictionary = hero()
	unit.hand = hand([20,1,2,3,4])
	equip(unit,"STUN",1,1,1)
	var state: Dictionary = state_for(unit)
	state.enemies[0].intents = [{"key":"ATTACK","name":"Attack","effects":[Combat.effect("damage",30,"enemy")]}]
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(unit.hp == 100 and state.enemies[0].statuses.stun == 0,"Stun applied before enemy slot skips it immediately and decrements")
	unit = hero()
	unit.hand = hand([1,1,1,1,1])
	equip(unit,"BULWARK",1,1,1)
	equip(unit,"STRIKE",1,1,1)
	state = state_for(unit)
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(state.enemies[0].hp == 998 and unit.statuses.stun == 3,"Self-stun does not cancel remaining current skills")
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(state.enemies[0].hp == 998 and unit.statuses.stun == 2,"Self-stun skips future actor slot")
	unit = hero()
	state = state_for(unit)
	unit.block = 50
	unit.statuses = {"stun":1,"poison":3,"resolve":0}
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(unit.hp == 97 and unit.block == 50 and unit.statuses.poison == 2,"Poison ticks once through block after stunned slot")
	unit.hand = hand([12,1,2,3,4])
	state.enemies[0].statuses.poison = 11
	cast(unit,Catalog.gem("VENOM","v",24,5,5),state)
	check(state.enemies[0].statuses.poison == 12,"Poison additions cap at twelve")
	var boss: Dictionary = Catalog.enemy("SLIME_KING","boss")
	state = state_for(unit,boss)
	unit.hand = hand([20,1,2,3,4])
	cast(unit,Catalog.gem("STUN","stun",1,5),state)
	check(boss.statuses.stun == 1,"External boss stun caps at one")
	boss.intents = [{"key":"SLAM","name":"Slam","effects":[Combat.effect("damage",1,"enemies")]}]
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(boss.statuses.resolve == 2 and boss.statuses.stun == 0,"Boss stun skip grants two full future Resolve slots")
	for remaining in [1,0]:
		var hp_before: int = boss.hp
		cast(unit,Catalog.gem("STUN","stun",1,5),state)
		check(boss.statuses.stun == 0 and boss.hp == hp_before-21,"Resolve rejects stun but permits damage")
		# Keep boss alive across both checks.
		boss.hp = 60
		Combat.resolve_turn(state,RandomNumberGenerator.new())
		check(boss.statuses.resolve == remaining,"Resolve expires after each protected slot")
	unit = hero()
	unit.hp = 1
	unit.statuses.poison = 1
	state = state_for(unit)
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(state.battle_outcome == "defeat" and unit.hp == 0 and unit.statuses.poison == 0,"Poison party wipe loses immediately and clears downed Poison")

func _test_traits_relics() -> void:
	var unit: Dictionary = hero()
	unit.trait = "STAND_FIRM"
	unit.hand = hand([2,2,3,3,3])
	equip(unit,"BLOCK")
	equip(unit,"INTERPOSE")
	equip(unit,"HEAVYSTRIKE")
	var state: Dictionary = state_for(unit)
	var events: Array = Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(events.filter(func(event: Dictionary) -> bool: return event.skill == "STAND_FIRM" if event.has("skill") else false).size() == 1,"Ardor trait once for two pairs and several matching gems")
	check(unit.block == 10,"Ardor adds exactly two trait block")
	unit = hero("KAIT")
	unit.trait = "CALCULATED_RISK"
	unit.initial_hand = hand([2,1,2,3,4])
	unit.hand = hand([5,1,2,3,4])
	state = state_for(unit)
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(unit.block == 0,"Kait compares final vs initial only, 2→8→5 gives no block")
	unit.hand[0].value = 6
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(unit.block == 3,"Kait improvement of four gives three block")
	unit = hero()
	relic(unit,"MATCHBOX")
	state = state_for(unit)
	cast(unit,Catalog.gem("BLOCK","block"),state)
	cast(unit,Catalog.gem("INTERPOSE","interpose"),state)
	check(unit.block == 8,"Matchbox +2 applies only to Block")
	cast(unit,Catalog.gem("BLOCK","block-again"),state)
	check(unit.block == 11,"Matchbox trigger bounded once per turn")
	relic(unit,"STEADY_HAND")
	var before: int = state.enemies[0].hp
	cast(unit,Catalog.gem("STRIKE","strike"),state)
	check(state.enemies[0].hp == before-11,"Steady Hand adds two raw damage")
	unit.relic_flags = {}
	unit.rerolled = true
	before = state.enemies[0].hp
	cast(unit,Catalog.gem("STRIKE","strike"),state)
	check(state.enemies[0].hp == before-9,"Any reroll, including Second Thought, disables Steady Hand")
	relic(unit,"FIELD_DRESSING")
	unit.hp = unit.max_hp
	cast(unit,Catalog.gem("HEAL","heal"),state)
	check(not unit.relic_flags.get("field_dressing",false),"Full HP heal does not spend Field Dressing")
	unit.hp = 99
	cast(unit,Catalog.gem("HEAL","heal"),state)
	check(unit.hp == 100 and unit.relic_flags.field_dressing,"Missing one HP consumes Field Dressing despite cap")
	relic(unit,"FOCUSING_PRISM")
	var item: Dictionary = Catalog.gem("MULTISTRIKE","m",1,1,2)
	var action: Dictionary = Combat.preview(unit,item,hand([1,2,2,3,4]),state)
	check(action.active and action.effective_clarity == 3 and item.clarity == 2,"Prism affects straight trigger without changing stored property")
	var aegis: Dictionary = relic(unit,"LASTING_AEGIS")
	aegis.stored_block = 6
	Combat.begin_battle(state,RandomNumberGenerator.new())
	check(unit.block == 6 and aegis.stored_block == 0,"Aegis consumes stored block at entry")
	Combat.begin_battle(state,RandomNumberGenerator.new())
	check(unit.block == 0,"Aegis block cannot be granted twice")

func _test_intents() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 221
	var unit: Dictionary = hero()
	var crab: Dictionary = Catalog.enemy("STONE_CRAB","crab",2)
	crab.hand = hand([2,5])
	var state: Dictionary = state_for(unit,crab)
	var intents: Array = Combat.enemy_intents(crab,state,rng)
	check(intents[0].key == "SHELL_UP" and intents[0].effects[0].amount == 6,"Act 2 Crab scaled block floor(5×1.2)")
	state.turn = 8
	intents = Combat.enemy_intents(crab,state,rng)
	check(intents[0].key == "CLAW" and intents[0].effects[0].amount == 14,"Act 2 Claw +2 act damage and +4 Enrage")
	var cultist: Dictionary = Catalog.enemy("GEM_CULTIST","cultist")
	cultist.hand = hand([2,8])
	state = state_for(unit,cultist)
	state.enemies.append(Catalog.enemy("SLIME","hurt"))
	state.enemies[1].hp -= 5
	intents = Combat.enemy_intents(cultist,state,rng)
	check(intents[0].key == "RESTORE" and intents[0].friendly_target_id == "hurt","Cultist chooses wounded ally before planning")
	state.enemies[1].hp = 20
	cultist.intents = intents
	Combat.resolve_turn(state,rng)
	check(unit.hp == 100,"Cultist announced heal stays heal even after wound disappears")
	var mirror: Dictionary = Catalog.enemy("MIRROR_REGENT","mirror",2)
	state = state_for(unit,mirror)
	intents = Combat.enemy_intents(mirror,state,rng)
	mirror.hp = 30
	check(mirror.boss_phase == "normal" and intents[0].key == "REFRACTION","Mirror crossing HP does not replace current announced intent")
	Combat.enemy_intents(mirror,state,rng)
	check(mirror.boss_phase == "fractured" and mirror.phase_turn == 1,"Mirror enters phase at next intent publication and restarts cycle")
	var sovereign: Dictionary = Catalog.enemy("RIFT_SOVEREIGN","rift",3)
	sovereign.hp = 40
	sovereign.statuses.poison = 3
	state = state_for(unit,sovereign)
	unit.hand = hand([4,4,4,4,4])
	sovereign.intents = Combat.enemy_intents(sovereign,state,rng)
	var events: Array = Combat.resolve_turn(state,rng)
	check(sovereign.intents.size() == 2 and unit.hp == 80,"Convergence publishes both tide actions and safe band takes 20 damage")
	check(sovereign.hp == 37 and sovereign.statuses.poison == 2,"Convergence Poison ticks only once")
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "skill").size() == 2,"Convergence two distinct named actions")
	for key in Catalog.ENEMIES:
		var enemy: Dictionary = Catalog.enemy(key,"test",3,4)
		state = state_for(hero(),enemy)
		Combat.begin_battle(state,rng)
		check(not enemy.intents.is_empty(),"Every enemy publishes an executable intent: "+key)

func _test_determinism() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 672120
	rng_b.seed = 672120
	var a: Dictionary = {"heroes":[Catalog.hero("MAX","h")],"enemies":Catalog.encounter("battle",1,1,1,"short_9"),"turn":0,"act":1,"party_size":1}
	var b: Dictionary = a.duplicate(true)
	Combat.begin_battle(a,rng_a)
	Combat.begin_battle(b,rng_b)
	check(a == b and rng_a.state == rng_b.state,"Same seed produces identical battle entry and hands")
	var events_a: Array = Combat.resolve_turn(a,rng_a)
	var events_b: Array = Combat.resolve_turn(b,rng_b)
	check(a == b and events_a == events_b,"Same state/commands produce identical effects and state")
	var restored: RandomNumberGenerator = RandomNumberGenerator.new()
	restored.state = rng_a.state
	var die: Dictionary = Catalog.die("SEVEN_D8","test-die")
	check(Combat.roll_die(die,rng_a) == Combat.roll_die(die,restored),"Saved RNG resumes future physical face exactly")

func _test_authoring_and_forecasts() -> void:
	var pack: Resource = Catalog.default_content_pack()
	var registry: Dictionary = {"heroes":Catalog.HEROES,"skills":Catalog.SKILLS,"dice":Catalog.DICE,"relics":Catalog.RELICS,"enemies":Catalog.ENEMIES}
	check(pack.validate(registry).is_empty(),"Typed default content Resource validates")
	var imported: Dictionary = ContentPack.from_json(pack.to_json())
	check(imported.errors.is_empty() and imported.pack.validate(registry).is_empty(),"Editable JSON pack round-trips and validates: "+str(imported.errors if not imported.errors.is_empty() else imported.pack.validate(registry)))
	pack.skills.STRIKE.evaluator_id = "arbitrary_expression"
	check(not pack.validate(registry).is_empty(),"Unregistered formula evaluator is rejected before a run")
	check(not ContentPack.from_json('{"schema_version":2}').errors.is_empty(),"Future content schema rejected explicitly")
	check(not ContentPack.from_json('{"schema_version":1,"heroes":[]}').errors.is_empty(),"Malformed content container rejected")
	var unit: Dictionary = hero()
	unit.hand = hand([2,2,3,3,3])
	unit.block = 5
	equip(unit,"BLOCK",2,1,1)
	equip(unit,"SHIELDBASH",2,2,1)
	var state: Dictionary = state_for(unit)
	var before: Dictionary = state.duplicate(true)
	var previews: Array = Combat.preview_loadout(unit,state)
	var hits: Array = previews[1].resolved_events.filter(func(event: Dictionary) -> bool: return event.kind == "damage")
	check(hits.size() == 1 and hits[0].raw_damage == 18,"Ordered preview includes previous Block before Shield Bash: (5+5+2)×1.5")
	check(state == before,"Ordered previews cannot mutate real combat state")
	var forecast: Dictionary = Combat.forecast_turn(state)
	var actual: Dictionary = state.duplicate(true)
	var actual_events: Array = Combat.resolve_turn(actual,RandomNumberGenerator.new())
	check(forecast.state == actual and forecast.events == actual_events,"Full forecast equals actual deterministic resolution")
	check(state == before,"Full forecast is read-only")
	var mirror: Dictionary = Catalog.enemy("MIRROR_WISP","wisp")
	mirror.intents = [{"key":"REFLECTION","name":"Reflection","effects":[{"kind":"damage","amount":5,"target":"enemy","condition":"contains","marked_value":3,"bonus":4}],"target_id":unit.id}]
	state.enemies = [mirror]
	unit.gems = []
	unit.block = 0
	forecast = Combat.forecast_turn(state)
	check(forecast.state.heroes[0].hp == 91,"Forecast includes marked-value conditional intent against current final hand")
	unit.hand = hand([1,2,4,5,6])
	forecast = Combat.forecast_turn(state)
	check(forecast.state.heroes[0].hp == 95,"Changing hand updates conditional enemy damage without changing published intent")
