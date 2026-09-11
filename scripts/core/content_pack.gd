class_name RogueContentPack
extends Resource
## Editable content asset; behavior is selected only through registered rule IDs.
## JSON import is data-only and never evaluates source or arbitrary expressions.
@export var schema_version: int = 1
@export var content_version: String = "1.0.0"
@export var pack_id: String = "full"
@export var heroes: Dictionary = {}
@export var skills: Dictionary = {}
@export var dice: Dictionary = {}
@export var relics: Dictionary = {}
@export var enemies: Dictionary = {}
@export var events: Dictionary = {}
@export var profiles: Dictionary = {}
@export var statuses: Dictionary = {}
const SECTIONS: Array = ["heroes","skills","dice","relics","enemies","events","profiles","statuses"]
## Color is the fourth C: the category a skill's effects belong to. It is authored, not rolled.
const COLORS: Array = ["RED","BLUE","GREEN","VIOLET","GOLD","WHITE"]
const TARGETS: Array = ["self","enemy","enemies","ally","revive"]
const TAGS: Array = ["attack","pair","block","heal","straight","seven","gold","triple","full_house","high","stun","low","support","odd","two_pairs","group","poison","even","distinct","revive"]

func as_dictionary() -> Dictionary:
	var result: Dictionary = {"schema_version":schema_version,"content_version":content_version,"pack_id":pack_id}
	for section in SECTIONS:
		result[section] = get(section).duplicate(true)
	return result

func to_json() -> String:
	return JSON.stringify(as_dictionary(),"\t",true)

static func from_json(text: String) -> Dictionary:
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(text)
	if error != OK or not parser.data is Dictionary:
		return {"pack":null,"errors":["Invalid content JSON: "+parser.get_error_message()]}
	var data: Dictionary = parser.data
	if not data.get("schema_version",null) in [1,1.0]:
		return {"pack":null,"errors":["Unsupported content schema"]}
	var pack: Resource = (load("res://scripts/core/content_pack.gd") as GDScript).new()
	pack.content_version = str(data.get("content_version",""))
	pack.pack_id = str(data.get("pack_id",""))
	for section in SECTIONS:
		if not data.get(section,{}) is Dictionary:
			return {"pack":null,"errors":["Content section "+section+" must be an object"]}
		pack.set(section,data.get(section,{}).duplicate(true))
	return {"pack":pack,"errors":[]}

func validate(registry: Dictionary) -> Array:
	var errors: Array = []
	if schema_version != 1 or content_version.is_empty() or pack_id.is_empty():
		errors.append("Invalid content version/pack identity")
	for section in ["heroes","skills","dice","relics","enemies"]:
		var entries: Dictionary = get(section)
		if entries.is_empty():
			errors.append("Content section "+section+" is empty")
		if pack_id == "full":
			for registered_id in registry.get(section,{}):
				if not entries.has(registered_id):
					errors.append("Missing required "+section+" ID: "+registered_id)
		for key in entries:
			if not entries[key] is Dictionary:
				errors.append(section+"/"+str(key)+": definition must be an object")
			elif not _has_rule(section,str(key),entries[key],registry):
				errors.append(section+"/"+str(key)+": "+_rule_hint(section))
			elif not entries[key].get("name",null) is String or str(entries[key].get("name","")).is_empty():
				errors.append(section+"/"+str(key)+": definition needs a display name")
	if not errors.is_empty():
		return errors
	for key in skills:
		var entry: Dictionary = skills[key]
		if not _positive_integer(entry.get("rarity",0)) or int(entry.get("rarity",0)) > 4 or not entry.get("target","") in TARGETS:
			errors.append("Invalid rarity or target policy: "+key)
		if _rules().has_rule(entry):
			## A skill may write its own rule as data instead of naming a compiled one. The
			## interpreter owns what that language allows, so it reports on it too.
			for problem in _rules().validate(entry.rule):
				errors.append(key+" rule: "+str(problem))
			if _rules().node_count(entry.rule) > _rules().MAX_NODES:
				errors.append(key+" rule: too many parts; keep it to "+str(_rules().MAX_NODES))
		elif not registry.get("skills",{}).has(str(entry.get("evaluator_id",key))):
			errors.append("Unknown formula evaluator: "+str(entry.get("evaluator_id",key))+" on "+key)
		if not str(entry.get("color","")) in COLORS:
			errors.append("Unknown gem color "+str(entry.get("color",""))+" on "+key)
		if not entry.get("tags",[]) is Array:
			errors.append("Tags must be an array: "+key)
		else:
			for tag in entry.get("tags",[]):
				if not tag in TAGS:
					errors.append("Unknown trigger tag "+str(tag)+" on "+key)
	for key in dice:
		var entry: Dictionary = dice[key]
		if not _positive_integer(entry.get("price",0)):
			errors.append("Invalid die price: "+key)
		var shape: String = str(entry.get("shape",""))
		if not shape in ["D4","D6","D8","D10","D12","D20"]:
			errors.append("Invalid die shape: "+key)
			continue
		var sides: int = int(shape.trim_prefix("D"))
		var faces: Variant = entry.get("faces",[])
		if not faces is Array or faces.size() != sides:
			errors.append("Invalid face count: "+key)
			continue
		for face in faces:
			if not (face is int or face is float) or float(face) != floor(float(face)) or int(face) < 1 or int(face) > sides:
				errors.append("Invalid face value: "+key)
		var unlock_act: Variant = entry.get("unlock_act",0)
		if not (unlock_act is int or unlock_act is float) or int(unlock_act) < 0 or int(unlock_act) > 3:
			errors.append("Invalid shop unlock act (0 is never sold, 1-3 an act): "+key)
		var unlock_room: Variant = entry.get("unlock_room",0)
		if not (unlock_room is int or unlock_room is float) or int(unlock_room) < 0:
			errors.append("Invalid shop unlock room: "+key)
	for key in heroes:
		var entry: Dictionary = heroes[key]
		if not _positive_integer(entry.get("max_hp",0)) or not entry.get("dice",[]) is Array or entry.get("dice",[]).size() != 5:
			errors.append("Invalid hero health/dice: "+key)
			continue
		for die_id in entry.dice:
			if not dice.has(die_id):
				errors.append("Missing starting die: "+str(die_id))
		var starters: Variant = entry.get("starting_gems",[])
		if not starters is Array or starters.is_empty() or starters.size() > 6:
			errors.append("Missing starting gems: "+key)
			continue
		var starting_keys: Array = []
		for starter in starters:
			## [skill, carat] or [skill, carat, cut, clarity] — the same shape `Catalog.hero()`
			## reads, so a starting gem can be authored at any rank the drop table can roll.
			if not starter is Array or starter.size() < 2 or starter.size() > 4 or not skills.has(starter[0]) or not _positive_integer(starter[1]) or int(starter[1]) > 24:
				errors.append("Invalid starting gem on "+key)
			elif (starter.size() > 2 and (not _positive_integer(starter[2]) or int(starter[2]) > 5)) or (starter.size() > 3 and (not _positive_integer(starter[3]) or int(starter[3]) > 5)):
				errors.append("Starting gem cut and clarity must be 1-5 on "+key)
			elif starter[0] in starting_keys:
				errors.append("Duplicate equipped starting skill on "+key)
			else:
				starting_keys.append(starter[0])
		if not "STRIKE" in starting_keys:
			errors.append("Hero must begin with an equipped Strike: "+key)
		if not entry.get("trait","") in ["STAND_FIRM","CALCULATED_RISK","SECOND_THOUGHT"]:
			errors.append("Unknown hero trait: "+key)
	for key in enemies:
		var entry: Dictionary = enemies[key]
		if not _positive_integer(entry.get("max_hp",0)) or not entry.get("dice",[]) is Array:
			errors.append("Invalid enemy stats: "+key)
			continue
		var block: Variant = entry.get("block",null)
		if not (block is int or block is float) or float(block) != floor(float(block)) or int(block) < 0:
			errors.append("Invalid enemy initial block: "+key)
		for die_id in entry.get("dice",[]):
			if not dice.has(die_id):
				errors.append("Missing enemy die: "+str(die_id))
		if not registry.get("enemies",{}).has(str(entry.get("ai",key))):
			errors.append("Unknown enemy routine: "+str(entry.get("ai",key))+" on "+key)
	for key in profiles:
		var entry: Variant = profiles[key]
		if not entry is Dictionary or not entry.get("skill_ids",[]) is Array:
			errors.append("Invalid profile: "+key)
			continue
		for skill_id in entry.get("skill_ids",[]):
			if not skills.has(skill_id):
				errors.append("Unknown profile skill: "+str(skill_id))
		for relic_id in entry.get("relic_ids",[]):
			if not relics.has(relic_id):
				errors.append("Unknown profile relic: "+str(relic_id))
		for boss_id in entry.get("boss_ids",[]):
			if not enemies.has(boss_id):
				errors.append("Unknown profile boss: "+str(boss_id))
		if not entry.get("loot_generator","") in ["depth_luck_v1","act_tier_v1"]:
			errors.append("Unregistered loot generator: "+key)
		errors.append_array(_encounter_errors(key,entry.get("encounters",{})))
	for key in statuses:
		if not key in ["stun","poison","resolve"]:
			errors.append("Unregistered status rule: "+key)
	if pack_id == "full":
		for profile_id in ["short_9","expedition_18"]:
			if not profiles.has(profile_id):
				errors.append("Missing run profile: "+profile_id)
	return errors

static func _rules() -> GDScript:
	## Loaded rather than preloaded: the pack is a Resource the editor may open on its own,
	## and a cycle through the interpreter would make that a chore.
	return load("res://scripts/core/gem_rules.gd") as GDScript

static func _has_rule(section: String, key: String, entry: Dictionary, registry: Dictionary) -> bool:
	## Dice are pure data, so any ID is legal. Skills, enemies and heroes may be new as long
	## as they name a registered behaviour to run. Relics and events are nothing but a code
	## hook, so those still have to exist in the build before the pack can mention them.
	if section == "dice":
		return true
	if registry.get(section,{}).has(key):
		return true
	match section:
		"skills": return _rules().has_rule(entry) or registry.get("skills",{}).has(str(entry.get("evaluator_id","")))
		"enemies": return registry.get("enemies",{}).has(str(entry.get("ai","")))
		"heroes": return str(entry.get("trait","")) in ["STAND_FIRM","CALCULATED_RISK","SECOND_THOUGHT"]
	return false

static func _rule_hint(section: String) -> String:
	match section:
		"skills": return "new skills need either a `rule` of their own or `evaluator_id` set to a registered skill whose rule they run"
		"enemies": return "new enemies need `ai` set to a registered enemy whose routine they run"
		"heroes": return "new heroes need `trait` set to a registered trait"
	return "ID has no registered rule; this section is behaviour, so the build has to ship it first"

func _encounter_errors(profile_key: String, table: Variant) -> Array:
	## Optional. {"first_room": [id], "normal": {"1": [[ids] per party size]},
	## "elite": [[ids] per party size], "boss": [id per act]}. Every ID named has to be an
	## enemy this pack carries, or the room it fills would come out empty at the table.
	if table == null or (table is Dictionary and table.is_empty()):
		return []
	if not table is Dictionary:
		return [profile_key+": encounters must be an object"]
	var found: Array = []
	for field in table:
		if not str(field) in ["first_room","normal","elite","boss"]:
			found.append(profile_key+": unknown encounter group "+str(field))
	for key in _encounter_ids(table):
		if not enemies.has(key):
			found.append(profile_key+": encounter names an enemy this pack does not carry: "+str(key))
	for field in ["first_room","boss"]:
		if table.has(field) and not table[field] is Array:
			found.append(profile_key+"/"+field+": must be a list of enemy IDs")
	if table.has("elite") and not table.elite is Array:
		found.append(profile_key+"/elite: must be a list of enemy groups, one per party size")
	if table.has("normal"):
		if not table.normal is Dictionary:
			found.append(profile_key+"/normal: must be an object keyed by act")
		else:
			for act in table.normal:
				if not str(act) in ["1","2","3"]:
					found.append(profile_key+"/normal: act "+str(act)+" is outside 1-3")
				elif not table.normal[act] is Array:
					found.append(profile_key+"/normal/"+str(act)+": must be a list of enemy groups, one per party size")
	return found

static func _encounter_ids(table: Dictionary) -> Array:
	## Every enemy ID an encounter table names, whichever group it sits in.
	var found: Array = []
	for field in ["first_room","boss"]:
		for key in table.get(field,[]) if table.get(field,[]) is Array else []:
			if key is String:
				found.append(key)
	var buckets: Array = table.get("elite",[]) if table.get("elite",[]) is Array else []
	var normal: Variant = table.get("normal",{})
	if normal is Dictionary:
		for act in normal:
			if normal[act] is Array:
				buckets = buckets + normal[act]
	for group in buckets:
		if group is Array:
			for key in group:
				if key is String:
					found.append(key)
	return found

static func _positive_integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value)) and int(value) > 0
