extends SceneTree
## Content authored in the studio, played by the engine.
##
## A pack may carry heroes, gems, dice and enemies the rules build has never heard of, as
## long as each one names the registered behaviour it borrows: a gem names an evaluator, an
## enemy names a routine, a hero names a trait. This suite writes such a pack, loads it the
## way the game does, and then checks the borrowed rules actually fire — that a gem no
## GDScript mentions deals Strike's damage under its own name, colour and rarity, and that
## an enemy no GDScript mentions alternates Shell Up and Claw and reaches a room.
const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const ContentPack = preload("res://scripts/core/content_pack.gd")
const GemRules = preload("res://scripts/core/gem_rules.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")
const PACK_PATH: String = "user://authored_content_test.json"
var checks: int = 0
var failures: Array = []

func _init() -> void:
	var errors: Array = _install(_authored_pack())
	check(errors.is_empty(), "An authored pack that borrows registered rules loads: "+", ".join(errors))
	if errors.is_empty():
		_test_written_rules()
		_test_borrowed_gem()
		_test_borrowed_hero()
		_test_borrowed_enemy()
		_test_reach_the_table()
	_test_rejections()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PACK_PATH))
	print("Authored content: %d assertions, %d failures" % [checks,failures.size()])
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

# --- the pack a studio session would write ------------------------------------

func _authored_pack(mutate: Callable = Callable()) -> Dictionary:
	var pack: Resource = Catalog.default_content_pack()
	var data: Dictionary = pack.as_dictionary()
	## A gem the build has never heard of, running Strike's formula under its own identity.
	data.skills["EMBER_LANCE"] = {"name":"Ember Lance", "rarity":3, "color":"VIOLET",
		"tags":["attack"], "trigger":"Always", "formula":"Damage (highest K dice + F(L)) × M(C).",
		"target":"enemy", "evaluator_id":"STRIKE"}
	## A die is pure data: no borrowed rule at all.
	data.dice["EMBER_D6"] = {"name":"Ember Die", "shape":"D6", "faces":[2,2,4,4,6,6], "price":9, "unlock_depth":1}
	data.heroes["EMBER"] = {"name":"Ember", "max_hp":75, "color":"d08b9f",
		"dice":["EMBER_D6","EMBER_D6","D6","D8","D8"], "trait":"SECOND_THOUGHT",
		"trait_name":"Second Wind", "description":"Once per encounter, reroll one die for free.",
		"starting_gems":[["STRIKE",3,2,2],["EMBER_LANCE",8,3,3]]}
	data.enemies["EMBER_CRAB"] = {"name":"Ember Crab", "max_hp":30, "block":4,
		"dice":["D6","D6"], "threat":1, "description":"Alternates a shell and a claw.", "ai":"STONE_CRAB"}
	## A mine the build has never heard of, spawning the authored crab and dropping the
	## authored gem, reached by an unlock from the Quarry.
	data.mines["EMBER_DEEP"] = {"name":"Ember Deep", "difficulty":2, "boss_id":"SLIME_KING", "links":[],
		"atlas_x":80, "atlas_y":70, "color":"d08b9f", "tremor_rate":100, "lift_rate":100, "quality_bonus":2,
		"rooms":{"battle":5, "elite":1, "mine":2}, "skill_ids":["EMBER_LANCE","STRIKE"], "color_weights":{}, "relic_ids":[],
		"bands":[{"from_depth":1, "normal":{"EMBER_CRAB":1}, "elite":{"EMBER_CRAB":1}},
			{"from_depth":5, "normal":{"EMBER_CRAB":1, "SLIME":1}, "elite":{"RED_SLIME":1}}]}
	data.mines.QUARRY.links = data.mines.QUARRY.links + ["EMBER_DEEP"]
	## Gems whose rule is written as data rather than borrowed from the build. Each one is
	## a shipped skill rewritten in the little language, so the interpreter can be held to
	## the compiled rule's own numbers.
	data.skills["WRIT_STRIKE"] = {"name":"Writ Strike", "rarity":2, "color":"RED", "tags":["attack"],
		"trigger":"Always", "formula":"", "target":"enemy",
		"rule":{"trigger":{"kind":"always"}, "effects":[{"kind":"damage", "target":"enemy",
			"amount":{"op":"+", "args":[{"term":"highest_sum", "count":{"rank":"cut"}}, {"rank":"clarity_bonus"}]}}]}}
	data.skills["WRIT_BLOCK"] = {"name":"Writ Block", "rarity":2, "color":"BLUE", "tags":["pair","block"],
		"trigger":"Any pair", "formula":"", "target":"self",
		"rule":{"trigger":{"kind":"pair"}, "effects":[{"kind":"block", "target":"self",
			"amount":{"op":"+", "args":[{"op":"*", "args":[{"term":"pair_value"}, {"rank":"cut"}]}, {"rank":"clarity_bonus"}]}}]}}
	data.skills["WRIT_ARC"] = {"name":"Writ Arc", "rarity":3, "color":"RED", "tags":["straight","attack","group"],
		"trigger":"Straight of 3", "formula":"", "target":"enemies",
		"rule":{"trigger":{"kind":"straight", "length":{"const":3}}, "effects":[{"kind":"damage", "target":"enemies",
			"amount":{"op":"+", "args":[{"term":"run_high"}, {"rank":"clarity_bonus"}]},
			"target_limit":{"op":"+", "args":[{"rank":"cut"}, {"const":1}]}}]}}
	data.skills["WRIT_VENOM"] = {"name":"Writ Venom", "rarity":3, "color":"VIOLET", "tags":["high","attack","poison"],
		"trigger":"Highest die ≥ 13−L", "formula":"", "target":"enemy",
		"rule":{"trigger":{"kind":"high_at_least", "amount":{"op":"-", "args":[{"const":13}, {"rank":"clarity"}]}},
			"effects":[{"kind":"damage", "target":"enemy",
				"amount":{"op":"+", "args":[{"op":"floor_div", "args":[{"term":"high"}, {"const":2}]}, {"rank":"clarity_bonus"}]}},
				{"kind":"poison", "target":"enemy", "scale":"none",
				"amount":{"op":"+", "args":[{"rank":"cut"},
					{"op":"floor_div", "args":[{"op":"+", "args":[{"rank":"carat"}, {"const":3}]}, {"const":4}]}]}}]}}
	data.skills["WRIT_MULTI"] = {"name":"Writ Multistrike", "rarity":3, "color":"RED", "tags":["straight","attack"],
		"trigger":"Straight by clarity", "formula":"", "target":"enemy",
		"rule":{"trigger":{"kind":"straight", "length":"by_clarity"}, "effects":[{"kind":"damage", "target":"enemy",
			"amount":{"const":4}, "repeat":{"rank":"cut"}}]}}
	data.mines.EMBER_DEEP.skill_ids = data.mines.EMBER_DEEP.skill_ids + ["WRIT_STRIKE","WRIT_BLOCK","WRIT_ARC","WRIT_VENOM","WRIT_MULTI"]
	if mutate.is_valid():
		mutate.call(data)
	return data

func _install(data: Dictionary) -> Array:
	var file: FileAccess = FileAccess.open(PACK_PATH,FileAccess.WRITE)
	if file == null:
		return ["Could not write the test pack"]
	file.store_string(JSON.stringify(data,"\t",true))
	file.close()
	return Catalog.load_content_pack(PACK_PATH)

# --- what a rule written as data does -----------------------------------------

func _same_effects(written: String, shipped: String, numbers: Array, c: int, k: int, l: int, label: String) -> void:
	var actor: Dictionary = Catalog.hero("EMBER","h")
	actor.hand = hand(numbers)
	var authored: Dictionary = Combat.preview(actor,Catalog.gem(written,"g",c,k,l),actor.hand,{})
	var compiled: Dictionary = Combat.preview(actor,Catalog.gem(shipped,"g",c,k,l),actor.hand,{})
	check(authored.active == compiled.active and str(authored.effects) == str(compiled.effects),
		"%s matches %s at C%d K%d L%d on %s: %s vs %s" % [label,shipped,c,k,l,str(numbers),str(authored.effects),str(compiled.effects)])

func _test_written_rules() -> void:
	## The four shipped rules these were written to copy, at ranks that move every term.
	for ranks in [[1,1,1],[8,3,3],[24,5,5],[12,2,4]]:
		_same_effects("WRIT_STRIKE","STRIKE",[1,3,5,6,9],ranks[0],ranks[1],ranks[2],"A written Strike")
		_same_effects("WRIT_BLOCK","BLOCK",[2,2,4,6,8],ranks[0],ranks[1],ranks[2],"A written Block")
		_same_effects("WRIT_ARC","ARC_BURST",[1,2,3,6,9],ranks[0],ranks[1],ranks[2],"A written Arc Burst")
		_same_effects("WRIT_VENOM","VENOM",[2,4,6,8,14],ranks[0],ranks[1],ranks[2],"A written Venom")
		_same_effects("WRIT_MULTI","MULTISTRIKE",[3,4,5,6,7],ranks[0],ranks[1],ranks[2],"A written Multistrike")
	var actor: Dictionary = Catalog.hero("EMBER","h")
	actor.hand = hand([2,2,4,6,8])
	var idle: Dictionary = Combat.preview(actor,Catalog.gem("WRIT_ARC","g",8,3,3),actor.hand,{})
	check(idle.valid and not idle.active and idle.effects.is_empty(), "A written rule whose trigger fails produces nothing")
	var pair: Dictionary = Combat.preview(actor,Catalog.gem("WRIT_BLOCK","g",8,3,3),actor.hand,{})
	check(pair.contributing_dice.size() == 2, "A written trigger highlights the dice it read")
	var strike: Dictionary = Combat.preview(actor,Catalog.gem("WRIT_STRIKE","g",8,3,3),hand([1,3,5,6,9]),{})
	check(strike.contributing_dice.size() == 3, "…and so do the dice a term consumed")
	check(GemRules.describe(Catalog.definitions("skills").WRIT_STRIKE.rule) == "Damage (the highest K dice + F(L)) × M(C) to target.",
		"A written rule says itself in the wording the shipped formulas use")
	check(GemRules.describe(Catalog.definitions("skills").WRIT_MULTI.rule) == "Damage 4 × M(C) to target, K times.",
		"…including how often it repeats")
	check(GemRules.describe(Catalog.definitions("skills").WRIT_BLOCK.rule) == "Block (the pair value × K + F(L)) × M(C).",
		"…and says nothing about a target when the gem only affects its owner")
	check(GemRules.describe_trigger(Catalog.definitions("skills").WRIT_VENOM.rule.trigger) == "Highest die ≥ 13 − L",
		"…including its trigger")
	var drawn: Array = GemText.blocks(Catalog.gem("WRIT_VENOM","g",12,3,3))
	check(drawn.size() == 2 and str(drawn[0].kind) == "damage" and str(drawn[1].kind) == "poison",
		"The gem panel draws a written rule as one block per effect")
	check(not drawn[0].parts.is_empty() and not str(drawn[0].mult).is_empty(),
		"…with its parts and its single Carat multiplier")
	## The requirement strip is drawn before any roll, so it has to come from the trigger.
	var pair_strip: Dictionary = DiceIcons.requirement("WRIT_BLOCK",3,3,8)
	check(pair_strip.faces.size() == 2 and int(pair_strip.faces[0][0]) == int(pair_strip.faces[1][0]),
		"A written pair trigger is drawn as two matching dice")
	var venom_strip: Dictionary = DiceIcons.requirement("WRIT_VENOM",3,3,8)
	check(str(venom_strip.lead) == "≥" and int(venom_strip.faces[0][0]) == 10,
		"A written threshold is worked out from the gem's own ranks")
	var run_strip: Dictionary = DiceIcons.requirement("WRIT_MULTI",5,3,8)
	check(run_strip.faces.size() == 3, "A straight shortened by Clarity is drawn at its real length")
	var always_strip: Dictionary = DiceIcons.requirement("WRIT_STRIKE",3,3,8)
	check(str(always_strip.lead) == "ANY HAND", "A rule with no condition says so")

# --- what the borrowed rules do -----------------------------------------------

func _test_borrowed_gem() -> void:
	var actor: Dictionary = Catalog.hero("EMBER","h")
	actor.hand = hand([1,3,5,6,9])
	var authored: Dictionary = Combat.preview(actor,Catalog.gem("EMBER_LANCE","g",8,3,3),actor.hand,{})
	var shipped: Dictionary = Combat.preview(actor,Catalog.gem("STRIKE","g",8,3,3),actor.hand,{})
	check(authored.valid and authored.active, "An authored gem resolves")
	check(authored.rule == "STRIKE", "It reports the rule it borrowed")
	check(authored.name == "Ember Lance" and authored.key == "EMBER_LANCE", "It keeps its own name and key")
	check(authored.color == "VIOLET", "It keeps its own colour rather than the lender's")
	check(str(authored.effects) == str(shipped.effects), "It produces exactly the lender's effects")
	check(Catalog.gem_value(Catalog.gem("EMBER_LANCE","g",8,3,3)) == 3*(8+2*2+2*2), "It is valued at its own rarity")
	check(Catalog.gem_color("EMBER_LANCE") == "VIOLET", "Its colour drives its cut and its panel")
	## A borrowed rule has to reach the interface too, or the gem panel comes out blank.
	var borrowed_blocks: Array = GemText.blocks(Catalog.gem("EMBER_LANCE","g",8,3,3))
	var lender_blocks: Array = GemText.blocks(Catalog.gem("STRIKE","g",8,3,3))
	check(not borrowed_blocks.is_empty() and str(borrowed_blocks) == str(lender_blocks),
		"The gem panel draws a borrowed rule as the rule it borrowed")
	check(DiceIcons.requirement("EMBER_LANCE",3,3,8).lead == DiceIcons.requirement("STRIKE",3,3,8).lead,
		"…and so does its requirement strip")

func _test_borrowed_hero() -> void:
	var actor: Dictionary = Catalog.hero("EMBER","h")
	check(actor.max_hp == 75 and actor.dice.size() == 5, "An authored hero is built with its own stats")
	check(int(actor.trait_charges) == 1, "A borrowed Second Thought arrives charged, without being named Max")
	check(actor.gems.size() == 2 and actor.gems[1].key == "EMBER_LANCE", "Its starting gems are equipped")
	check(int(actor.gems[1].carat) == 8 and int(actor.gems[1].cut) == 3 and int(actor.gems[1].clarity) == 3,
		"A four-part starting gem carries its whole cut")
	check(str(actor.dice[0].key) == "EMBER_D6" and actor.dice[0].faces.size() == 6, "An authored die rolls its own faces")

func _test_borrowed_enemy() -> void:
	var unit: Dictionary = Catalog.enemy("EMBER_CRAB","e",1,1)
	check(unit.max_hp == 30 and int(unit.block) == 4, "An authored enemy is built with its own stats")
	check(str(unit.ai) == "STONE_CRAB", "It carries the routine it borrowed")
	unit.hand = hand([3,5])
	var hero_unit: Dictionary = Catalog.hero("EMBER","h")
	hero_unit.hand = hand([1,2,3,4,5])
	var state: Dictionary = {"heroes":[hero_unit], "enemies":[unit], "turn":1, "depth":1, "party_size":1, "battle_outcome":""}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var intents: Array = Combat.enemy_intents(unit,state,rng)
	check(intents.size() == 1 and str(intents[0].key) == "SHELL_UP", "It runs the borrowed routine's first turn")
	state.turn = 2
	check(str(Combat.enemy_intents(unit,state,rng)[0].key) == "CLAW", "…and its second")

func _test_reach_the_table() -> void:
	check("EMBER_LANCE" in Catalog.mine_skills("EMBER_DEEP",1), "An authored gem is in the authored mine's pool")
	check("EMBER_D6" in Catalog.merchant_dice(1), "An authored die reaches merchants at the depth it names")
	check(Catalog.merchant_dice(1).slice(0,3) == ["PAIRED_D6","ODD_D6","EVEN_D6"],
		"…without disturbing the order the shipped dice were offered in")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var first: Array = Catalog.mine_encounter("EMBER_DEEP","battle",1,2,rng,"e")
	check(first.size() == 2 and first.all(func(unit: Dictionary) -> bool: return str(unit.key) == "EMBER_CRAB"), "An authored band decides the shallow fights")
	var deeper: Array = Catalog.mine_encounter("EMBER_DEEP","elite",6,1,rng,"e")
	check(str(deeper[0].key) == "RED_SLIME", "…and a deeper band takes over")
	var boss: Array = Catalog.mine_encounter("EMBER_DEEP","boss",3,1,rng,"e")
	check(boss.size() == 1 and str(boss[0].key) == "SLIME_KING", "The mine's boss waits in its lair")
	var found: Dictionary = {}
	for index in range(200):
		found[Catalog.roll_gem(rng, Catalog.mine_skills("EMBER_DEEP",1), 10, "g").key] = true
	check(found.has("EMBER_LANCE") and found.has("WRIT_STRIKE"), "Authored and written gems drop in the authored mine")
	var Seam = load("res://scripts/core/seam.gd")
	var seam: Dictionary = {}
	Seam.ensure_layers(seam, "ember", "EMBER_DEEP", "", 6)
	check(seam.layers["4"].all(func(node: Dictionary) -> bool: return node.kind in ["battle","elite","mine","lift"]), "The authored mine's seam uses only its own room weights")

# --- what a pack still may not do ---------------------------------------------

func _test_rejections() -> void:
	var cases: Array = [
		["a gem that borrows nothing", func(data: Dictionary) -> void: data.skills["EMBER_LANCE"].erase("evaluator_id")],
		["a gem that borrows a rule the build lacks", func(data: Dictionary) -> void: data.skills["EMBER_LANCE"].evaluator_id = "FIREBALL"],
		["an enemy that borrows a routine the build lacks", func(data: Dictionary) -> void: data.enemies["EMBER_CRAB"].ai = "DRAGON"],
		["a hero with an unregistered trait", func(data: Dictionary) -> void: data.heroes["EMBER"].trait = "BRAVERY"],
		["a relic the build never registered", func(data: Dictionary) -> void: data.relics["EMBER_CHARM"] = {"name":"Ember Charm", "description":"Nothing runs this."}],
		["a starting gem cut outside its range", func(data: Dictionary) -> void: data.heroes["EMBER"].starting_gems[1] = ["EMBER_LANCE",8,9,3]],
		["a die whose faces do not fit its shape", func(data: Dictionary) -> void: data.dice["EMBER_D6"].faces = [1,2,3]],
		["a depth band naming an enemy that is not there", func(data: Dictionary) -> void: data.mines["EMBER_DEEP"].bands[0].elite = {"WYVERN":1}],
		["a mine no unlock reaches", func(data: Dictionary) -> void: data.mines.QUARRY.links = ["MIRROR_GROTTO","RIFT_HOLLOW"]],
		["a written rule with an unknown term", func(data: Dictionary) -> void: data.skills["WRIT_STRIKE"].rule.effects[0].amount = {"term":"lunar_phase"}],
		["a written rule with an unknown operator", func(data: Dictionary) -> void: data.skills["WRIT_STRIKE"].rule.effects[0].amount = {"op":"exec", "args":[{"const":1}]}],
		["a written rule with an unknown trigger", func(data: Dictionary) -> void: data.skills["WRIT_STRIKE"].rule.trigger = {"kind":"whenever"}],
		["a written rule with an unknown effect kind", func(data: Dictionary) -> void: data.skills["WRIT_STRIKE"].rule.effects[0].kind = "delete_save"],
		["a written rule with no effects", func(data: Dictionary) -> void: data.skills["WRIT_STRIKE"].rule.effects = []],
		["a written rule nested past its depth limit", func(data: Dictionary) -> void:
			var deep: Dictionary = {"const":1}
			for _level in range(GemRules.MAX_DEPTH+2):
				deep = {"op":"+", "args":[deep, {"const":1}]}
			data.skills["WRIT_STRIKE"].rule.effects[0].amount = deep],
		["a written rule that is not an object", func(data: Dictionary) -> void: data.skills["WRIT_STRIKE"].rule = {"trigger":"always", "effects":"all of them"}],
	]
	for case in cases:
		var errors: Array = _install(_authored_pack(case[1]))
		check(not errors.is_empty(), "The validator rejects "+str(case[0]))
	check(Catalog.load_content_pack(PACK_PATH.replace("authored_content_test","missing")).size() > 0,
		"A pack that is not there is an error, not a crash")
