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
			elif not registry.get(section,{}).has(key):
				errors.append(section+"/"+str(key)+": ID has no registered rule")
			elif not entries[key].get("name",null) is String or str(entries[key].get("name","")).is_empty():
				errors.append(section+"/"+str(key)+": definition needs a display name")
	if not errors.is_empty():
		return errors
	for key in skills:
		var entry: Dictionary = skills[key]
		if not _positive_integer(entry.get("rarity",0)) or int(entry.get("rarity",0)) > 4 or not entry.get("target","") in TARGETS:
			errors.append("Invalid rarity or target policy: "+key)
		if entry.get("evaluator_id",key) != key or not registry.skills.has(key):
			errors.append("Unknown formula evaluator: "+key)
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
			if not starter is Array or starter.size() != 2 or not skills.has(starter[0]) or not _positive_integer(starter[1]) or int(starter[1]) > 24:
				errors.append("Invalid starting gem on "+key)
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
	for key in statuses:
		if not key in ["stun","poison","resolve"]:
			errors.append("Unregistered status rule: "+key)
	if pack_id == "full":
		for profile_id in ["short_9","expedition_18"]:
			if not profiles.has(profile_id):
				errors.append("Missing run profile: "+profile_id)
	return errors

static func _positive_integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value)) and int(value) > 0
