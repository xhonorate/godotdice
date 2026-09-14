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
	_test_white_gems()
	_test_colour_gems()
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
	check(Catalog.SKILLS.size() == 34,"Thirty-four skills")
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
	check(skill("STRIKE",[2,2,4,6,8]).effects[0].amount == 10,"Shared hand Strike is 10")
	check(skill("BLOCK",[2,2,4,6,8],2).effects[0].amount == 4,"Shared hand Block is 4")
	check(skill("HEAL",[2,2,4,6,8],2,2,3).effects[0].amount == 11,"Heal multiplies the whole sum by Carat")
	check(skill("MULTISTRIKE",[1,2,2,3,4],3,2,3).effects.size() == 2,"Straight ignores duplicate and creates K hits")
	check(skill("HEAVYSTRIKE",[2,2,2,6,6,6],1).effects[0].amount == 8,"Highest triple selected in larger hand")
	check(skill("BLOCK",[2,2,2,6,6],1).effects[0].amount == 8,"Highest pair selected; triple is usable pair")
	check(skill("BLOCK",[4,4,4,4,5],1).effects[0].amount == 6,"Quad contains pair")
	check(skill("SHIELDBASH",[2,2,3,3,3],2,2).active,"Full house triggers Shield Bash")
	check(not skill("SHIELDBASH",[2,2,2,2,3]).active,"Quad and singleton not full house")
	check(skill("ARC_BURST",[1,2,2,3,4]).effects[0].amount == 6,"Highest qualifying three-value straight selected")
	check(skill("ARC_BURST",[1,2,2,3,4]).contributing_dice == ["d1","d3","d4"],"Straight highlights stable representative IDs")
	check(skill("MEND",[1,3,3,5,12],2,2).effects[0].amount == 5,"Mend odd formula")
	check(skill("VENOM",[1,3,3,5,12],2,2).effects[0].amount == 9,"Venom damage formula")
	check(skill("VENOM",[1,3,3,5,12],2,2).effects[1].amount == 3,"Venom Poison formula")
	check(skill("EVEN_TEMPO",[2,4,6,7,9],2,2,3).effects[0].amount == 13,"Even Tempo parity block")
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
			check(action.effects[0].amount == 7,"Lucky damage ignores the jackpot")
			check(action.effects[1].amount == (6 if sevens >= 3 else 2),"Lucky jackpot scales gold only")
	check(skill("LUCKYSTRIKE",[7,7,7,7,7],1,1,5).effects[0].amount == 7,"L5 jackpot leaves damage on Cut and Carat")
	check(skill("LUCKYSTRIKE",[7,7,7,7,7],1,1,5).effects[1].amount == 7,"L5 jackpot multiplier is seven for gold")
	check(not Combat.preview(hero(),Catalog.gem("STRIKE","x"),[]).valid,"Empty hand rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","carat":0},hand([1,2,3,4,5])).valid,"Zero Carat rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","carat":1.5},hand([1,2,3,4,5])).valid,"Fractional property rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","cut":6},hand([1,2,3,4,5])).valid,"Out of bounds rank rejected")
	check(not skill("STRIKE",[0,1,2,3,4]).valid,"Invalid die value rejected")
	check(not Combat.preview(hero(),{"key":"STRIKE","carat":[]},hand([1,2,3,4,5])).valid,"Malformed property container rejected without conversion crash")
	_test_four_cs()

func _test_four_cs() -> void:
	## Carat is the only property that multiplies a finished effect, and it is strictly
	## increasing across its whole 1-24 range.
	check(is_equal_approx(Combat.carat_multiplier(1),1.0),"M(1) leaves a base untouched")
	check(is_equal_approx(Combat.carat_multiplier(24),3.875),"M(24) is the strongest multiplier")
	check(Combat.carat_multiplier(0) == Combat.carat_multiplier(1) and Combat.carat_multiplier(99) == Combat.carat_multiplier(24),"Carat multiplier clamps to legal ranks")
	var previous: int = 0
	for c in range(1,25):
		var amount: int = skill("STRIKE",[2,2,4,6,8],c).effects[0].amount
		check(amount > previous,"Carat "+str(c)+" strictly increases Strike damage")
		previous = amount
	check(skill("STRIKE",[2,2,4,6,8],24).effects[0].amount == 38,"Carat 24 Strike is base 10 times 3.875")
	## Clarity is flat: it adds F(L) = 2L to the base before the Carat multiplier, so the
	## gap between two Clarity ranks scales with Carat but never with the roll.
	for l in range(1,6):
		check(Combat.clarity_bonus(l) == 2*l,"F("+str(l)+") is flat 2L")
	check(skill("STRIKE",[2,2,4,6,8],1,1,5).effects[0].amount-skill("STRIKE",[2,2,4,6,8],1,1,1).effects[0].amount == 8,"Clarity 1 to 5 adds a flat 8 at Carat 1")
	check(skill("STRIKE",[2,2,4,6,8],1,1,3).effects[0].amount == skill("STRIKE",[20,20,20,20,20],1,1,3).effects[0].amount-12,"Clarity contributes the same flat amount on a much larger roll")
	## Cut multiplies only what the dice contributed, so it is worth more to an attack that
	## reads many dice than to a defensive gem that reads a fixed pair.
	var cut_gain: int = skill("STRIKE",[8,8,8,8,8],1,5).effects[0].amount-skill("STRIKE",[8,8,8,8,8],1,1).effects[0].amount
	var block_gain: int = skill("INTERPOSE",[8,8,8,8,8],1,5).effects[0].amount-skill("INTERPOSE",[8,8,8,8,8],1,1).effects[0].amount
	check(cut_gain > block_gain,"Cut is worth more on a dice-reading attack than on flat support block")
	## Color is a fixed property of the skill, never of the instance.
	for key in Catalog.SKILLS:
		check(Catalog.GEM_COLORS.has(Catalog.gem_color(key)),"Skill "+key+" declares a known color")
	check(Catalog.gem_color("STRIKE") == "RED" and Catalog.gem_color("BLOCK") == "BLUE" and Catalog.gem_color("HEAL") == "GREEN","Damage, block and healing gems carry their category color")
	check(Catalog.gem_color("STUN") == "VIOLET" and Catalog.gem_color("LUCKYSTRIKE") == "GOLD","Control and fortune gems carry their category color")
	check(Catalog.gem_color("BULLWARK") == Catalog.gem_color("BULWARK"),"Legacy aliases resolve to the same color")
	check(str(skill("STRIKE",[2,2,4,6,8]).get("color","")) == "RED","Preview reports the gem color for presentation")
	check(Catalog.cut_name(1) == "Poor" and Catalog.cut_name(5) == "Perfect","Cut ranks are named Poor to Perfect")
	check(Catalog.clarity_name(1) == "Fractured" and Catalog.clarity_name(5) == "Flawless","Clarity ranks are named Fractured to Flawless")

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
	check(state.enemies[1].hp == hp_before-7,"Next skill retargets first living enemy")
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
	check(downed.hp == 9 and downed.block == 0 and downed.statuses.stun == 0 and downed.statuses.poison == 0,"Lifeline revival clears block/statuses and restores exact HP")
	check(downed.action_eligible_from_turn == 2 and rescue_state.enemies[0].hp == 1000,"Later-seat revived hero cannot act this turn")
	check(life.revive_charges == 0,"Lifeline charge consumed by revival")
	var fresh: Dictionary = Catalog.gem("LIFELINE","fresh",2,2,1)
	cast(rescue,fresh,rescue_state)
	check(fresh.revive_charges == 1 and downed.hp == 13,"Lifeline ordinary heal keeps revival charge")

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
	check(state.enemies[0].hp == 997 and unit.statuses.stun == 3,"Self-stun does not cancel remaining current skills")
	Combat.resolve_turn(state,RandomNumberGenerator.new())
	check(state.enemies[0].hp == 997 and unit.statuses.stun == 2,"Self-stun skips future actor slot")
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
		check(boss.statuses.stun == 0 and boss.hp == hp_before-22,"Resolve rejects stun but permits damage")
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
	check(unit.block == 12,"Ardor adds exactly two trait block")
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
	check(unit.block == 10,"Matchbox +2 applies only to Block")
	cast(unit,Catalog.gem("BLOCK","block-again"),state)
	check(unit.block == 14,"Matchbox trigger bounded once per turn")
	relic(unit,"STEADY_HAND")
	var before: int = state.enemies[0].hp
	cast(unit,Catalog.gem("STRIKE","strike"),state)
	check(state.enemies[0].hp == before-12,"Steady Hand adds two raw damage")
	unit.relic_flags = {}
	unit.rerolled = true
	before = state.enemies[0].hp
	cast(unit,Catalog.gem("STRIKE","strike"),state)
	check(state.enemies[0].hp == before-10,"Any reroll, including Second Thought, disables Steady Hand")
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
	## The other side takes its dice up at its own slot, so nothing is revealed while the
	## party is still planning. What the party is shown instead is the roster: every action
	## the routine can reach. Whatever the roll then opens must come from that roster, or
	## the loadout drawn over the enemy's head would be describing a different creature.
	for key in Catalog.ENEMIES:
		var enemy: Dictionary = Catalog.enemy(key,"test",3,4)
		state = state_for(hero(),enemy)
		Combat.begin_battle(state,rng)
		check(enemy.intents.is_empty(),"Nothing is revealed before the party has acted: "+key)
		var roster: Array = Combat.enemy_skills(enemy)
		check(not roster.is_empty(),"Every enemy carries a readable roster: "+key)
		var offered: PackedStringArray = []
		for action in roster:
			offered.append(str(action.key))
		Combat.resolve_turn(state,rng)
		check(not enemy.intents.is_empty(),"Taking its slot publishes an executable intent: "+key)
		for intent in enemy.intents:
			check(str(intent.key) in offered,"…named by the roster the party was shown: "+key+" → "+str(intent.key))

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

func _test_white_gems() -> void:
	## White reaches past the effect it resolves — into the reroll allowance, the hand, the
	## gem before it in the loadout, and the gems themselves. Each of those is a place the
	## other five colours never touch, so each one is checked where it lands.
	## The lifts change the hand rather than a combatant.
	var glimmer: Dictionary = skill("GLIMMER",[2,3,4,6,8],1,1,1)
	check(glimmer.active and glimmer.effects.size() == 1,"Glimmer always fires and lifts once")
	check(glimmer.effects[0].kind == "amplify" and glimmer.effects[0].get("which","") == "low","Glimmer raises the lowest die")
	check(glimmer.effects[0].amount == 3,"Glimmer at C1 K1 L1 adds K + F(L) = 3 pips")
	check(glimmer.contributing_dice.size() == 1,"A lift marks the one die it raises")
	var refract: Dictionary = skill("REFRACT",[2,3,4,6,8],1,1,1)
	check(refract.effects[0].get("which","") == "high" and refract.effects[0].amount == 10,
		"Refract adds H + 2(K-1) + F(L) = 10 to a highest die of 8, which more than doubles it")
	check(skill("REFRACT",[2,3,4,6,8],8,1,1).effects[0].amount > refract.effects[0].amount,"Carat multiplies the lift")
	var lifted: Dictionary = hero()
	lifted.hand = hand([2,3,4,6,8])
	var lift_events: Array = []
	Combat.resolve_skill(lifted,Combat.preview(lifted,Catalog.gem("REFRACT","g",1,1,1),lifted.hand,state_for(lifted)),state_for(lifted),lift_events,Catalog.gem("REFRACT","g"))
	check(Combat.values(lifted.hand).max() == 18,"A resolved lift raises the die in the hand itself")
	var raised: Dictionary = {}
	for roll in lifted.hand:
		if int(roll.value) == 18:
			raised = roll
	check(int(raised.get("lift",0)) == 10,"A raised roll records how far it left its physical face")
	var capped: Dictionary = hero()
	capped.hand = hand([2,3,4,6,19])
	Combat.resolve_skill(capped,Combat.preview(capped,Catalog.gem("REFRACT","g",24,5,5),capped.hand,state_for(capped)),state_for(capped),[],Catalog.gem("REFRACT","g"))
	check(Combat.values(capped.hand).max() == Combat.HAND_VALUE_CAP,"A lift stops at the 20 every other rule reads")
	## A lift is only worth anything to the gems resolved after it, which is what makes
	## loadout order matter. Resolving the whole batch is the only way to see that.
	var ordered: Dictionary = hero()
	ordered.hand = hand([2,3,4,6,8])
	var before_strike: Dictionary = Combat.preview(ordered,Catalog.gem("STRIKE","s",1,1,1),ordered.hand,state_for(ordered))
	ordered.gems = []
	equip(ordered,"REFRACT")
	equip(ordered,"STRIKE")
	var batch: Array = Combat.preview_loadout(ordered,state_for(ordered))
	check(batch.size() == 2 and batch[1].effects[0].amount > before_strike.effects[0].amount,
		"A Strike equipped after a Refract reads the raised hand")
	check(Combat.values(ordered.hand).max() == 8,"A forecast leaves the real hand where it found it")
	## Rerolls: an allowance for the battle, set rather than added, and dropped at the next.
	check(Combat.reroll_allowance(1,1) == 2 and Combat.reroll_allowance(24,1) == 4
		and Combat.reroll_allowance(1,5) == 3,"Carat sets the allowance and a Perfect Cut adds one")
	check(Combat.reroll_allowance(24,5) == Combat.MAX_REROLLS-1,"The allowance stops below the engine ceiling")
	var seer: Dictionary = hero()
	var seer_state: Dictionary = state_for(seer)
	equip(seer,"SECOND_SIGHT",16,1,1)
	Combat.resolve_turn(seer_state,RandomNumberGenerator.new())
	check(int(seer.max_rerolls) == 4,"Second Sight raises the allowance where it resolves")
	Combat.begin_turn(seer_state,RandomNumberGenerator.new())
	check(int(seer.rerolls) == 4,"The raised allowance is in hand for the next roll")
	Combat.resolve_turn(seer_state,RandomNumberGenerator.new())
	check(int(seer.max_rerolls) == 4,"Casting it twice in a battle is worth no more than once")
	Combat.begin_battle(seer_state,RandomNumberGenerator.new())
	check(int(seer.max_rerolls) == 1 and int(seer.rerolls) == 1,"The next battle starts from the hero's own allowance")
	## Echo repeats the gem before it, at a share, and never itself.
	var mimic: Dictionary = hero()
	mimic.hand = hand([5,5,4,6,8])
	var mimic_state: Dictionary = state_for(mimic)
	equip(mimic,"STRIKE",1,1,1)
	equip(mimic,"ECHO",1,1,1)
	var struck: int = int(Combat.preview(mimic,mimic.gems[0],mimic.hand,mimic_state).effects[0].amount)
	var enemy_hp: int = int(mimic_state.enemies[0].hp)
	Combat.resolve_turn(mimic_state,RandomNumberGenerator.new())
	check(enemy_hp-int(mimic_state.enemies[0].hp) == struck+floori(float(struck)*0.27),
		"Echo repeats the Strike before it at 27% and the pair is what lets it")
	var silent: Dictionary = hero()
	silent.hand = hand([5,5,4,6,8])
	var silent_state: Dictionary = state_for(silent)
	equip(silent,"ECHO",1,1,1)
	var silent_events: Array = Combat.resolve_turn(silent_state,RandomNumberGenerator.new())
	var fizzled: bool = false
	for event in silent_events:
		if event.kind == "fizzle":
			fizzled = true
	check(fizzled,"An Echo with nothing before it says so rather than repeating itself")
	check(not skill("ECHO",[1,2,3,4,5],1,1,1).active,"Echo needs a pair")
	## Facet is the one effect that outlives the encounter, so it is charged and ceilinged.
	check(not skill("FACET",[1,1,3,4,5],1,1,1).active,"Facet needs five distinct results at low Clarity")
	check(skill("FACET",[1,1,3,4,5],1,1,5).active,"Flawless Clarity eases it to three")
	var cutter: Dictionary = hero()
	cutter.hand = hand([1,2,3,4,5])
	var cutter_state: Dictionary = state_for(cutter)
	var small: Dictionary = equip(cutter,"STRIKE",1,1,1)
	var facet: Dictionary = equip(cutter,"FACET",6,5,1)
	Combat.resolve_turn(cutter_state,RandomNumberGenerator.new())
	check(int(small.carat) == 4,"Facet cuts the lowest-Carat other gem up by ceil(K/2) = 3")
	check(int(facet.upgrade_charges) == 0,"It spends its one charge for the battle")
	Combat.begin_turn(cutter_state,RandomNumberGenerator.new())
	cutter.hand = hand([1,2,3,4,5])
	Combat.resolve_turn(cutter_state,RandomNumberGenerator.new())
	check(int(small.carat) == 4,"A spent charge does not recut the same stone next turn")
	Combat.begin_battle(cutter_state,RandomNumberGenerator.new())
	cutter.hand = hand([1,2,3,4,5])
	Combat.resolve_turn(cutter_state,RandomNumberGenerator.new())
	check(int(small.carat) == 6 and int(facet.carat) == 6,
		"A new battle restores the charge, and a gem is never lifted past the cutter's own Carat")
	Combat.begin_battle(cutter_state,RandomNumberGenerator.new())
	cutter.hand = hand([1,2,3,4,5])
	var stuck: Array = Combat.resolve_turn(cutter_state,RandomNumberGenerator.new())
	var refused: bool = false
	for event in stuck:
		if event.kind == "fizzle":
			refused = true
	check(refused and int(small.carat) == 6,"With nothing left below its own Carat it cuts nothing")
	## Colour, shape and words, which is how a player tells White from the rest.
	for key in ["GLIMMER","REFRACT","SECOND_SIGHT","ECHO","FACET"]:
		check(Catalog.gem_color(key) == "WHITE","%s is a White gem" % key)
		check(not Combat.effects_summary(skill(key,[2,2,4,6,8],4,3,3).effects).is_empty(),
			"%s says what it does in words" % key)

func _test_colour_gems() -> void:
	## The ten that round the other five colours out. Each is checked on the shape of its
	## trigger, the arithmetic of its amounts, and the one thing it does that its colour
	## could not do before it existed.
	## Red: the only skill that reads four alike, and the only trigger Clarity buys outright.
	check(not skill("QUARTET",[4,4,4,2,3],1,1,1).active,"Quartet needs four matching values")
	check(skill("QUARTET",[4,4,4,4,3],1,1,1).active,"Four alike switches it on")
	check(skill("QUARTET",[4,4,4,2,3],1,1,5).active,"Flawless Clarity buys it down to a triple")
	check(skill("QUARTET",[4,4,4,4,3],1,1,1).effects[0].amount == 10,"Quartet is v × 2K + F(L) at C1 K1 L1")
	check(skill("QUARTET",[4,4,4,4,3],1,3,1).effects[0].amount == 26,"Cut doubles into the matched value")
	check(skill("QUARTET",[4,4,4,4,3],1,1,1).contributing_dice.size() == 4,"It marks the four dice it read")
	check(skill("QUARTET",[2,2,2,2,6],1,1,1).effects[0].amount < skill("QUARTET",[6,6,6,6,2],1,1,1).effects[0].amount,
		"A higher matched value hits harder")
	## Blue and Green: stacks coming off, which nothing could do before.
	var stunned: Dictionary = hero()
	stunned.statuses = {"stun":2,"poison":7,"resolve":0}
	var stunned_state: Dictionary = state_for(stunned)
	stunned.hand = hand([1,2,3,4,5])
	var bastion: Dictionary = Combat.preview(stunned,Catalog.gem("BASTION","g",1,2,1),stunned.hand,stunned_state)
	check(bastion.active and bastion.effects.size() == 2,"Bastion fires on a low total and does two things")
	check(bastion.effects[0].kind == "block" and bastion.effects[0].target == "ally","It walls the whole party")
	check(bastion.effects[1].kind == "cleanse" and bastion.effects[1].get("status","") == "stun"
		and bastion.effects[1].amount == 1,"and clears one slot of stun")
	check(Combat.preview(stunned,Catalog.gem("BASTION","g",1,2,5),stunned.hand,stunned_state).effects[1].amount == 2,
		"Flawless Clarity clears two")
	Combat.resolve_skill(stunned,bastion,stunned_state,[],Catalog.gem("BASTION","g",1,2,1))
	check(int(stunned.statuses.stun) == 1,"A resolved cleanse actually takes the stack off")
	var healer: Dictionary = hero()
	healer.hand = hand([2,4,6,1,3])
	healer.statuses = {"stun":0,"poison":7,"resolve":0}
	var healer_state: Dictionary = state_for(healer)
	var purge: Dictionary = Combat.preview(healer,Catalog.gem("PURGE","g",8,2,1),healer.hand,healer_state)
	check(purge.active and purge.effects[0].get("status","") == "poison" and purge.effects[0].amount == 3,
		"Purge clears K + ceil(C/8) Poison")
	Combat.resolve_skill(healer,purge,healer_state,[],Catalog.gem("PURGE","g",8,2,1))
	check(int(healer.statuses.poison) == 4,"and the stacks are gone from the hero")
	var clean: Dictionary = hero()
	clean.hand = hand([2,4,6,1,3])
	var clean_state: Dictionary = state_for(clean)
	var quiet: Array = []
	Combat.resolve_skill(clean,Combat.preview(clean,Catalog.gem("PURGE","g",8,2,1),clean.hand,clean_state),clean_state,quiet,{})
	check(int(clean.statuses.poison) == 0,"Clearing a status nobody has takes it no lower than zero")
	check(skill("GRAFT",[3,3,6,6,2],1,1,1).effects[0].amount == 11,"Graft heals both pair values plus F(L)")
	check(skill("GRAFT",[3,3,6,6,2],1,3,1).effects[0].amount == 15,"Cut adds a flat bonus to it")
	check(not skill("GRAFT",[3,3,3,3,2],1,1,1).active,"A quad is not two distinct pairs")
	## Violet: a counting attack, a group poison and a strip.
	check(skill("HEXBOLT",[1,3,5,2,4],1,2,1).effects[0].amount == 8,"Hex Bolt is odd count × K + F(L)")
	check(skill("HEXBOLT",[1,3,5,2,4],1,2,4).effects.size() == 1,"It has no stun below Flawless")
	check(skill("HEXBOLT",[1,3,5,2,4],1,2,5).effects[1].kind == "stun","and gains one at Flawless")
	check(not skill("HEXBOLT",[1,3,2,2,4],1,1,1).active,"It needs three odd results")
	var miasma: Dictionary = skill("MIASMA",[2,4,6,1,3],12,2,1)
	check(miasma.active and miasma.effects.size() == 2,"Miasma poisons and then burns")
	check(miasma.effects[0].kind == "poison" and miasma.effects[0].amount == 4,"Poison is K + ceil(C/6)")
	check(miasma.effects[0].target == "enemies" and int(miasma.effects[0].target_limit) == 3,
		"and it reaches K+1 enemies, which no other Poison skill does")
	check(int(miasma.effects[1].target_limit) == int(miasma.effects[0].target_limit),
		"The damage follows the same enemies the poison went to")
	var enervate: Dictionary = skill("ENERVATE",[6,6,6,1,2],1,2,1)
	check(enervate.effects[0].kind == "remove_block" and enervate.effects[0].amount == 6,"Enervate strips 2K + F(L)")
	check(enervate.effects[1].kind == "poison" and enervate.effects[1].amount == 5,
		"then applies half the matched value plus K")
	## Gold: three ways to be paid, all of them still inside the battle allowance.
	check(skill("TITHE",[4,4,1,2,3],1,3,2).effects[0].kind == "gold","Tithe pays gold on any pair")
	check(skill("TITHE",[4,4,1,2,3],1,3,2).effects[0].amount == 7,"at K + F(L)")
	check(not skill("TITHE",[1,2,3,4,5],1,1,1).active,"and needs the pair")
	var mint: Dictionary = skill("MINT",[1,2,3,4,5],1,2,1)
	check(mint.active and mint.effects[0].kind == "gold" and mint.effects[1].kind == "block","Mint pays and then walls")
	check(mint.effects[0].amount == 6 and mint.effects[1].amount == 4,"at 2K + F(L) and K + F(L)")
	check(not skill("MINT",[1,1,3,4,5],1,1,1).active and skill("MINT",[1,1,3,4,5],1,1,3).active,
		"Clarity eases it to four distinct at L3")
	var low: Dictionary = skill("WAGER",[1,1,2,3,4],1,1,1)
	var higher: Dictionary = skill("WAGER",[4,4,4,4,4],1,1,1)
	check(low.active and higher.active,"Wager fires anywhere under its ceiling")
	check(low.effects[1].amount > higher.effects[1].amount,
		"and the quieter the hand, the harder it lands — the only skill paid by what you did not roll")
	check(low.effects[1].amount == Combat.WAGER_CEILING-11+2+2,"Wager is (24 − total + 2K + F(L)) × M(C)")
	check(low.effects[0].kind == "gold" and low.effects[0].amount == Combat.BLESSING_GOLD,"It pays before it hits")
	check(not skill("WAGER",[6,6,6,6,6],1,1,1).active,"A loud hand pays nothing")
	## Every colour now has a build in it, and every gem says what it does.
	var tally: Dictionary = {}
	for key in Catalog.SKILLS:
		var colour: String = Catalog.gem_color(str(key))
		tally[colour] = int(tally.get(colour,0))+1
	for colour in Catalog.GEM_COLORS:
		check(int(tally.get(colour,0)) >= 5,"Colour %s carries at least five skills" % colour)
	for key in ["QUARTET","BASTION","PURGE","GRAFT","HEXBOLT","MIASMA","ENERVATE","TITHE","MINT","WAGER"]:
		var hands: Array = [[4,4,4,4,3],[1,2,3,4,5],[2,4,6,1,3],[3,3,6,6,2]]
		var said: bool = false
		for numbers in hands:
			var action: Dictionary = skill(key,numbers,4,3,3)
			if action.active:
				said = said or not Combat.effects_summary(action.effects).is_empty()
		check(said,"%s fires on one of its own hands and says what it did" % key)
