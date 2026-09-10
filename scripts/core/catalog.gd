class_name RogueCatalog
extends RefCounted
## Immutable, versioned content and instance factories. Runtime objects are deep copies.
const RandomSource = preload("res://scripts/core/random_source.gd")
const ContentPack = preload("res://scripts/core/content_pack.gd")
const CONTENT_VERSION: String = "1.0.0"
static var _content_pack: Resource = null
const STANDARD_DICE: Array = ["D4", "D6", "D8", "D10", "D12", "D20"]
const BULWARK_BLOCK: Array = [10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180,190,200,210,230,250,300]
const BULWARK_STUN: Array = [3,2,2,1,0]
## The four C's. Color is a fixed property of the skill definition; Carat, Cut and Clarity
## are rolled per gem instance. Color names the category of a gem's effects and is never
## generated, upgraded or sold; it exists so a build can be read at a glance.
const GEM_COLORS: Dictionary = {
	"RED": {"name":"Red", "hex":"e2564a", "role":"Damage"},
	"BLUE": {"name":"Blue", "hex":"5a8fd8", "role":"Block"},
	"GREEN": {"name":"Green", "hex":"6fbf73", "role":"Healing and revival"},
	"VIOLET": {"name":"Violet", "hex":"a97fe0", "role":"Control: stun and poison"},
	"GOLD": {"name":"Gold", "hex":"e0b64a", "role":"Gold and fortune"}
}
const CUT_NAMES: Array = ["Poor","Fair","Good","Great","Perfect"]
const CLARITY_NAMES: Array = ["Fractured","Flawed","Clean","Pristine","Flawless"]
const HEROES: Dictionary = {
	"ARDOR": {"name":"Ardor", "max_hp":100, "dice":["D6","D6","D6","D8","D8"], "trait":"STAND_FIRM", "trait_name":"Stand Firm", "description":"Gain 2 block at the start of your turn when your final hand contains a pair.", "starting_gems":[["STRIKE",1],["BLOCK",2],["INTERPOSE",1]], "color":"ec9d62"},
	"KAIT": {"name":"Kait", "max_hp":70, "dice":["D4","D4","D4","D4","D20"], "trait":"CALCULATED_RISK", "trait_name":"Calculated Risk", "description":"Gain 3 block when a die finishes at least 4 higher than its initial value this turn.", "starting_gems":[["STRIKE",2],["BLOCK",1],["SUNDER",1]], "color":"9fd08b"},
	"MAX": {"name":"Max", "max_hp":80, "dice":["D4","D6","D6","D8","D12"], "trait":"SECOND_THOUGHT", "trait_name":"Second Thought", "description":"Once per encounter, reroll one die without spending your normal reroll.", "starting_gems":[["STRIKE",1],["BLOCK",1],["ARC_BURST",1]], "color":"9dabed"}
}
## Formula text uses M(C) = (C+7)/8 as the Carat multiplier and F(L) = 2L as the flat
## Clarity bonus. Cut multiplies whatever the dice contribute. Every amount floors once.
const SKILLS: Dictionary = {
	"STRIKE": {"name":"Strike", "rarity":1, "color":"RED", "tags":["attack"], "trigger":"Always", "formula":"Damage (highest K dice + F(L)) × M(C).", "target":"enemy"},
	"BLOCK": {"name":"Block", "rarity":1, "color":"BLUE", "tags":["pair","block"], "trigger":"Any pair", "formula":"Self block (highest pair value × K + F(L)) × M(C).", "target":"self"},
	"HEAL": {"name":"Heal", "rarity":2, "color":"GREEN", "tags":["heal"], "trigger":"Always", "formula":"Self heal (lowest K dice + F(L)) × M(C).", "target":"self"},
	"MULTISTRIKE": {"name":"Multistrike", "rarity":2, "color":"RED", "tags":["straight","attack"], "trigger":"Straight: 5 at L1–2; 4 at L3–4; 3 at L5", "formula":"K hits of 4 × M(C) damage. Clarity shortens the straight instead of adding F(L). Target stays fixed for this skill.", "target":"enemy"},
	"LUCKYSTRIKE": {"name":"Lucky Strike", "rarity":3, "color":"GOLD", "tags":["seven","attack","gold"], "trigger":"At least one 7", "formula":"Each 7: 7 × M(K) × M(C) damage, then C × J gold. Three or more sevens: J=L+1 (7 at L5); otherwise J=1. The jackpot multiplies gold only.", "target":"enemy"},
	"HEAVYSTRIKE": {"name":"Heavy Strike", "rarity":1, "color":"RED", "tags":["triple","attack"], "trigger":"At least three matching values", "formula":"Damage (highest triple value × K + F(L)) × M(C).", "target":"enemy"},
	"BLESSING": {"name":"Blessing", "rarity":3, "color":"GOLD", "tags":["straight","heal","gold"], "trigger":"Straight of 3", "formula":"Gain 3 × M(C) gold, then self heal (K + F(L)) × M(C).", "target":"self"},
	"SHIELDBASH": {"name":"Shield Bash", "rarity":2, "color":"BLUE", "tags":["full_house","attack","block"], "trigger":"Three of one value and two of another", "formula":"Gain F(L) × M(C) block, then damage floor(current block × (K+1)/2). At L5, apply 1 stun.", "target":"enemy"},
	"STUN": {"name":"Stun", "rarity":4, "color":"VIOLET", "tags":["high","attack","stun"], "trigger":"Highest die ≥ 21−L", "formula":"Damage (H + F(L)) × M(C), then 1 stun (2 at K5). K2–4 do not improve duration.", "target":"enemy"},
	"BULWARK": {"name":"Bulwark", "rarity":3, "color":"BLUE", "tags":["low","block"], "trigger":"Total ≤ 18+2L (20/22/24/26/28)", "formula":"Carat reads a fixed 10–300 block table instead of M(C); self-stun at Cut 1–5: 3/2/2/1/0. Clarity only eases the trigger.", "target":"self"},
	"DRAINSTRIKE": {"name":"Drain Strike", "rarity":4, "color":"RED", "tags":["high","attack","heal"], "trigger":"Total ≥ 45−5L", "formula":"Damage (floor(H × (K+1)/2) + F(L)) × M(C), then self heal F(L) × M(C).", "target":"enemy"},
	"INTERPOSE": {"name":"Interpose", "rarity":1, "color":"BLUE", "tags":["pair","support","block"], "trigger":"Any pair", "formula":"Party block (highest pair value + K−1 + F(L)) × M(C) to every living hero.", "target":"ally"},
	"MEND": {"name":"Mend", "rarity":1, "color":"GREEN", "tags":["odd","support","heal"], "trigger":"At least three odd results", "formula":"Party heal (lowest odd + 2(K−1) + F(L)) × M(C) to every living hero.", "target":"ally"},
	"SUNDER": {"name":"Sunder", "rarity":2, "color":"RED", "tags":["two_pairs","attack"], "trigger":"Two distinct pairs", "formula":"Remove up to (2K + F(L)) × M(C) block; damage (highest pair value + F(L)) × M(C).", "target":"enemy"},
	"ARC_BURST": {"name":"Arc Burst", "rarity":2, "color":"RED", "tags":["straight","attack","group"], "trigger":"Straight of 3", "formula":"Damage (highest value of chosen straight + F(L)) × M(C) to up to K+1 distinct enemies. Extra targets do not add hits on a single boss.", "target":"enemies"},
	"VENOM": {"name":"Venom", "rarity":2, "color":"VIOLET", "tags":["high","attack","poison"], "trigger":"Highest die ≥ 13−L", "formula":"Damage (floor(H/2) + F(L)) × M(C); apply K+ceil(C/4) Poison (12 stack cap).", "target":"enemy"},
	"EVEN_TEMPO": {"name":"Even Tempo", "rarity":2, "color":"BLUE", "tags":["even","attack","block"], "trigger":"At least three even results", "formula":"Self block (even result count × K + F(L)) × M(C); damage (K + F(L)) × M(C).", "target":"enemy"},
	"PRECISION": {"name":"Precision", "rarity":3, "color":"RED", "tags":["distinct","attack"], "trigger":"Five distinct results", "formula":"Damage (lowest two dice + 2K + F(L)) × M(C).", "target":"enemy"},
	"LIFELINE": {"name":"Lifeline", "rarity":4, "color":"GREEN", "tags":["straight","support","heal","revive"], "trigger":"Straight: 5 at L1–2; 4 at L3–4; 3 at L5", "formula":"Once per encounter revive a downed ally for (3K + F(L)) × M(C) HP; otherwise heal every living hero (K + F(L)) × M(C). Revived allies act next turn.", "target":"revive"}
}
const DICE: Dictionary = {
	"D4":{"name":"D4", "shape":"D4", "faces":[1,2,3,4], "price":4},
	"D6":{"name":"D6", "shape":"D6", "faces":[1,2,3,4,5,6], "price":6},
	"D8":{"name":"D8", "shape":"D8", "faces":[1,2,3,4,5,6,7,8], "price":8},
	"D10":{"name":"D10", "shape":"D10", "faces":[1,2,3,4,5,6,7,8,9,10], "price":10},
	"D12":{"name":"D12", "shape":"D12", "faces":[1,2,3,4,5,6,7,8,9,10,11,12], "price":12},
	"D20":{"name":"D20", "shape":"D20", "faces":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20], "price":16},
	"PAIRED_D6":{"name":"Paired Die", "shape":"D6", "faces":[1,1,2,5,6,6], "price":8},
	"ODD_D6":{"name":"Odd Die", "shape":"D6", "faces":[1,1,3,5,5,6], "price":8},
	"EVEN_D6":{"name":"Even Die", "shape":"D6", "faces":[1,2,4,4,4,6], "price":8},
	"SEVEN_D8":{"name":"Seven Die", "shape":"D8", "faces":[1,2,3,4,5,7,7,7], "price":14},
	"SPLIT_D12":{"name":"Split Die", "shape":"D12", "faces":[1,1,2,3,4,5,8,9,10,11,12,12], "price":16},
	"SPLIT_D20":{"name":"Rift Die", "shape":"D20", "faces":[1,2,3,4,5,5,6,6,7,7,14,14,15,15,16,16,17,18,19,20], "price":22}
}
const RELICS: Dictionary = {
	"MATCHBOX":{"name":"Matchbox", "description":"Your Block gem grants +2 block once per actor turn."},
	"STEADY_HAND":{"name":"Steady Hand", "description":"Strike deals +2 raw damage when no die was rerolled this turn."},
	"FIELD_DRESSING":{"name":"Field Dressing", "description":"Your first positive ordinary heal to an injured recipient each turn gains +2 healing."},
	"MINERS_LANTERN":{"name":"Miner's Lantern", "description":"Gain 2 extra mining energy while alive."},
	"FOCUSING_PRISM":{"name":"Focusing Prism", "description":"Straight skills use +1 effective Clarity, up to 5."},
	"MERCHANT_SEAL":{"name":"Merchant's Seal", "description":"Gain +3 gold from each normal or elite battle reward."},
	"TINKERS_BELT":{"name":"Tinker's Belt", "description":"Your first Workshop service each act is free. One service per visit."},
	"LASTING_AEGIS":{"name":"Lasting Aegis", "description":"Carry up to 6 remaining block from a won battle into the next. Unequipping discards stored block."}
}
const ENEMIES: Dictionary = {
	"SLIME":{"name":"Slime", "max_hp":20, "block":0, "dice":["D10","D10"], "threat":1, "description":"Strike, then Heal every turn."},
	"RED_SLIME":{"name":"Red Slime", "max_hp":30, "block":10, "dice":["D10","D10","D10"], "threat":2, "description":"Stronger Strike, then Heal every turn."},
	"STONE_CRAB":{"name":"Stone Crab", "max_hp":26, "block":6, "dice":["D6","D6"], "threat":1, "description":"Alternates Shell Up (block) and Claw (attack)."},
	"GEM_CULTIST":{"name":"Gem Cultist", "max_hp":22, "block":0, "dice":["D8","D8"], "threat":1, "description":"Restores the ally missing most HP when at least 5 HP is missing; otherwise attacks."},
	"DARTLING":{"name":"Dartling", "max_hp":16, "block":0, "dice":["D4","D4","D4"], "threat":1, "description":"Barbed Dart adds 2 Poison if its hand has a pair."},
	"IRON_WARDEN":{"name":"Iron Warden", "max_hp":48, "block":12, "dice":["D6","D8","D10"], "threat":2, "description":"Alternates Fortify (self and group block) and Hammer."},
	"MIRROR_WISP":{"name":"Mirror Wisp", "max_hp":18, "block":0, "dice":["D6","D6"], "threat":1, "description":"Reflection deals +4 if the target keeps its marked value."},
	"RIFT_HOUND":{"name":"Rift Hound", "max_hp":28, "block":0, "dice":["D4","D8","D12"], "threat":1, "description":"Alternates Track and Pounce, targeting the hero with least block."},
	"SLIME_KING":{"name":"Slime King", "max_hp":60, "block":0, "dice":[], "boss":true, "description":"Slam → Fortify → Absorb. Resolve: after a stun skip, immune to external stun for two slots."},
	"MIRROR_REGENT":{"name":"Mirror Regent", "max_hp":75, "block":8, "dice":[], "boss":true, "description":"Refraction → Shatter → Mending Glass. Below half HP: Refraction → Shatter. Resolve protects two slots after a stun skip."},
	"RIFT_SOVEREIGN":{"name":"Rift Sovereign", "max_hp":100, "block":0, "dice":[], "boss":true, "description":"High Tide → Low Tide → Eclipse. At 40% HP: High Tide and Low Tide each turn; safe total 19–23. Has Resolve."}
}
const EVENTS: Dictionary = {
	"ABANDONED_CACHE":{"name":"Abandoned Cache", "description":"Take 6 gold, or lose 8 HP for the displayed gem with +2 Carat. Requires more than 8 HP."},
	"FIELD_MEDIC":{"name":"Field Medic", "description":"Take 4 gold, or pay 8 gold to recover 20% maximum HP (rounded up)."},
	"ECHO_SHRINE":{"name":"Echo Shrine", "description":"Take 5 gold, or replace one D6's faces with Paired, Odd, or Even faces."},
	"JEWEL_BROKER":{"name":"Jewel Broker", "description":"Take 4 gold, or exchange one reserve gem for one of three displayed gems."}
}

static func canonical_key(key: String) -> String:
	return "BULWARK" if key == "BULLWARK" else key

static func gem(key: String, id: String, carat: int = 1, cut: int = 1, clarity: int = 1) -> Dictionary:
	key = canonical_key(key)
	if not definitions("skills").has(key):
		return {}
	return {"id":id, "key":key, "carat":clampi(carat,1,24), "cut":clampi(cut,1,5), "clarity":clampi(clarity,1,5), "equipped":false, "revive_charges":1}

static func die(key: String, id: String) -> Dictionary:
	if not definitions("dice").has(key):
		return {}
	var definition: Dictionary = definitions("dice")[key]
	var faces: Array = []
	for index in range(definition.faces.size()):
		faces.append({"id":id+"-f"+str(index), "value":definition.faces[index]})
	return {"id":id, "key":key, "name":definition.name, "shape":definition.shape, "sides":definition.faces.size(), "faces":faces, "price":definition.price}

static func relic(key: String, id: String) -> Dictionary:
	if not RELICS.has(key):
		return {}
	return {"id":id, "key":key, "equipped":false, "stored_block":0, "used_act":0}

static func hero(key: String, id: String, seat: int = 0) -> Dictionary:
	key = key.to_upper()
	if not definitions("heroes").has(key):
		return {}
	var definition: Dictionary = definitions("heroes")[key]
	var unit: Dictionary = _unit(key,id,"hero",definition.max_hp,0)
	unit.merge({"seat":seat, "trait":definition.trait, "trait_charges":1 if key == "MAX" else 0, "gold":0, "rerolls":1, "max_rerolls":1, "reserve_dice":[], "relics":[], "combat_gold":0, "preferred_target":"", "connected":true})
	for index in range(definition.dice.size()):
		unit.dice.append(die(definition.dice[index],id+"-d"+str(index)))
	for index in range(definition.starting_gems.size()):
		var starting: Array = definition.starting_gems[index]
		var item: Dictionary = gem(starting[0],id+"-g"+str(index),starting[1])
		item.equipped = true
		unit.gems.append(item)
	return unit

static func _unit(key: String, id: String, side: String, hp: int, block: int) -> Dictionary:
	var definition: Dictionary = definitions("heroes")[key] if side == "hero" else definitions("enemies")[key]
	return {"id":id, "key":key, "name":definition.name, "side":side, "hp":hp, "max_hp":hp, "block":block, "statuses":{"stun":0,"poison":0,"resolve":0}, "dice":[], "hand":[], "initial_hand":[], "gems":[], "ready":false, "action_eligible_from_turn":1, "rerolled":false, "relic_flags":{}}

static func enemy(key: String, id: String, act: int = 1, party_size: int = 1) -> Dictionary:
	if not definitions("enemies").has(key):
		return {}
	var definition: Dictionary = definitions("enemies")[key]
	var boss: bool = definition.get("boss",false)
	var tier: int = clampi(act,1,3)-1
	var hp: int = int(definition.max_hp)*party_size if boss else int(ceil(float(definition.max_hp)*[1.0,1.35,1.75][tier]))
	var block: int = int(definition.block)*party_size if boss else int(float(definition.block)*[1.0,1.2,1.4][tier])
	var unit: Dictionary = _unit(key,id,"enemy",hp,block)
	unit.merge({"boss":boss, "act":clampi(act,1,3), "party_size":party_size, "intents":[], "boss_phase":"normal", "phase_turn":0, "description":definition.description})
	for index in range(definition.dice.size()):
		unit.dice.append(die(definition.dice[index],id+"-d"+str(index)))
	if key in ["SLIME","RED_SLIME"]:
		var c: int = 2 if key == "RED_SLIME" else 1
		unit.gems = [gem("STRIKE",id+"-strike",c),gem("HEAL",id+"-heal",c)]
		for item in unit.gems:
			item.equipped = true
	return unit

static func encounter(kind: String, act: int, party_size: int, room: int, profile: String) -> Array:
	var count: int = clampi(party_size,1,4)
	var keys: Array = []
	var normalized: String = kind.to_lower()
	if normalized in ["boss","boss_battle"]:
		keys = [["SLIME_KING"],["MIRROR_REGENT"],["RIFT_SOVEREIGN"]][clampi(act,1,3)-1]
	elif normalized in ["elite","elite_battle"]:
		keys = [["IRON_WARDEN"],["IRON_WARDEN","RED_SLIME"],["IRON_WARDEN","IRON_WARDEN","RED_SLIME"],["IRON_WARDEN","IRON_WARDEN","RED_SLIME","RED_SLIME"]][count-1]
	elif room == 1:
		for _index in range(count):
			keys.append("SLIME")
	elif act == 1:
		keys = [["STONE_CRAB"],["STONE_CRAB","DARTLING"],["STONE_CRAB","DARTLING","GEM_CULTIST"],["STONE_CRAB","STONE_CRAB","DARTLING","GEM_CULTIST"]][count-1].duplicate()
		if profile == "short_9":
			for index in range(keys.size()):
				if keys[index] == "DARTLING":
					keys[index] = "SLIME"
	elif act == 2:
		keys = [["MIRROR_WISP"],["MIRROR_WISP","DARTLING"],["MIRROR_WISP","DARTLING","GEM_CULTIST"],["MIRROR_WISP","MIRROR_WISP","DARTLING","GEM_CULTIST"]][count-1]
	else:
		keys = [["RIFT_HOUND"],["MIRROR_WISP","RIFT_HOUND"],["MIRROR_WISP","RIFT_HOUND","RIFT_HOUND"],["MIRROR_WISP","RIFT_HOUND","RIFT_HOUND","GEM_CULTIST"]][count-1]
	var units: Array = []
	for index in range(keys.size()):
		units.append(enemy(keys[index],"room"+str(room)+"-enemy"+str(index),act,count))
	return units

static func gem_value(item: Dictionary) -> int:
	var key: String = canonical_key(str(item.get("key","")))
	if not SKILLS.has(key):
		return 0
	return int(definitions("skills")[key].rarity) * (int(item.get("carat",1))+2*(int(item.get("cut",1))-1)+2*(int(item.get("clarity",1))-1))

static func gem_color(key: String) -> String:
	## Color is read from the skill definition, never from the gem instance.
	key = canonical_key(key)
	return str(definitions("skills").get(key,{}).get("color","RED"))

static func color_definition(key: String) -> Dictionary:
	return GEM_COLORS.get(gem_color(key),GEM_COLORS.RED)

static func cut_name(rank: int) -> String:
	return CUT_NAMES[clampi(rank,1,5)-1]

static func clarity_name(rank: int) -> String:
	return CLARITY_NAMES[clampi(rank,1,5)-1]

static func die_value(item: Dictionary) -> int:
	return int(item.get("price",DICE.get(item.get("key","D6"),DICE.D6).price))

static func has_relic(unit: Dictionary, key: String) -> bool:
	for item in unit.get("relics",[]):
		if item.get("key","") == key and item.get("equipped",false):
			return true
	return false

static func eligible_skills(profile: String, party_size: int = 1) -> Array:
	var keys: Array = definitions("skills").keys()
	if profile in ["short_9","starter"]:
		for key in ["VENOM","EVEN_TEMPO","PRECISION","LIFELINE"]:
			keys.erase(key)
	if party_size <= 1:
		keys.erase("LIFELINE")
	keys.sort()
	return keys

static func eligible_relics(profile: String) -> Array:
	return ["MATCHBOX","STEADY_HAND","FIELD_DRESSING","MINERS_LANTERN"] if profile in ["short_9","starter"] else RELICS.keys()

static func eligible_dice(profile: String, act: int = 1, room: int = 1) -> Array:
	var keys: Array = ["PAIRED_D6","ODD_D6","EVEN_D6"]
	if act >= 2 or (profile == "short_9" and room > 4):
		keys.append("SEVEN_D8")
	if act >= 2:
		keys.append("SPLIT_D12")
	if act >= 3:
		keys.append("SPLIT_D20")
	return keys

static func generate_gems(rng: RandomNumberGenerator, count: int, profile: String, act: int, luck: int, prefix: String, party_size: int = 1, elite: bool = false) -> Array:
	var available: Array = eligible_skills(profile,party_size)
	var result: Array = []
	var tier: int = clampi(act,1,3)-1
	var rarity_weights: Array = [[55,35,10,0],[35,40,20,5],[20,40,30,10]][tier] if profile == "expedition_18" else RandomSource.luck_weights(luck)
	while result.size() < count and not available.is_empty():
		var buckets: Array = [[],[],[],[],[]]
		for key in available:
			buckets[int(definitions("skills")[key].rarity)-1].append(key)
		var weights: Array = []
		for index in range(rarity_weights.size()):
			weights.append(0 if buckets[index].is_empty() else rarity_weights[index])
		var bucket_index: int = RandomSource.weighted_index(rng,weights)
		if bucket_index < 0:
			break
		var bucket: Array = buckets[bucket_index]
		var key: String = bucket[rng.randi_range(0,bucket.size()-1)]
		available.erase(key)
		var c: int
		var k: int
		var l: int
		if profile == "expedition_18":
			c = rng.randi_range([1,4,7][tier],[4,8,12][tier])
			var ranks: Array = [[75,25,0,0,0],[35,45,20,0,0],[10,25,45,20,0]][tier]
			k = RandomSource.weighted_index(rng,ranks)+1
			l = RandomSource.weighted_index(rng,ranks)+1
		else:
			c = mini((RandomSource.rarity(rng,luck)-1)*5+rng.randi_range(1,5),24)
			k = RandomSource.rarity(rng,luck)
			l = RandomSource.rarity(rng,luck)
		if elite:
			if rng.randi_range(0,1) == 0:
				k = mini(k+1,5)
			else:
				l = mini(l+1,5)
		result.append(gem(key,prefix+"-"+str(result.size()),c,k,l))
	return result

static func validate_content() -> Array:
	var errors: Array = []
	if _content_pack == null:
		errors.append_array(load_content_pack())
	if SKILLS.size() != 19 or RELICS.size() != 8 or HEROES.size() != 3:
		errors.append("Incomplete content catalog")
	for key in DICE:
		var definition: Dictionary = DICE[key]
		var sides: int = int(str(definition.shape).trim_prefix("D"))
		if definition.faces.size() != sides:
			errors.append(key+": invalid face count")
		for face in definition.faces:
			if int(face) < 1 or int(face) > sides:
				errors.append(key+": invalid face value")
	for key in HEROES:
		if HEROES[key].dice.size() != 5:
			errors.append(key+": must have five dice")
		for die_id in HEROES[key].dice:
			if not DICE.has(die_id):
				errors.append(key+": missing die "+die_id)
		for entry in HEROES[key].starting_gems:
			if not SKILLS.has(entry[0]):
				errors.append(key+": missing gem "+entry[0])
	return errors

static func definitions(section: String) -> Dictionary:
	if _content_pack != null:
		var data: Variant = _content_pack.get(section)
		if data is Dictionary:
			return data
	match section:
		"heroes": return HEROES
		"skills": return SKILLS
		"dice": return DICE
		"relics": return RELICS
		"enemies": return ENEMIES
		"events": return EVENTS
	return {}

static func default_content_pack() -> Resource:
	var pack: Resource = ContentPack.new()
	pack.content_version = CONTENT_VERSION
	pack.heroes = HEROES.duplicate(true)
	pack.skills = SKILLS.duplicate(true)
	pack.dice = DICE.duplicate(true)
	pack.relics = RELICS.duplicate(true)
	pack.enemies = ENEMIES.duplicate(true)
	pack.events = EVENTS.duplicate(true)
	for key in pack.skills:
		pack.skills[key]["evaluator_id"] = key
	pack.profiles = {
		"short_9":{"rooms":9,"acts":1,"skill_ids":eligible_skills("short_9",4),"relic_ids":eligible_relics("short_9"),"boss_ids":["SLIME_KING"],"loot_generator":"depth_luck_v1","combat_gold_cap":[8]},
		"expedition_18":{"rooms":18,"acts":3,"skill_ids":eligible_skills("expedition_18",4),"relic_ids":eligible_relics("expedition_18"),"boss_ids":["SLIME_KING","MIRROR_REGENT","RIFT_SOVEREIGN"],"loot_generator":"act_tier_v1","combat_gold_cap":[8,12,16]}
	}
	pack.statuses = {
		"stun":{"name":"Stun","description":"Skip the next actor slot; ticks before the skill batch. Self-stun affects future slots.","hook":"start_slot","cap":-1},
		"poison":{"name":"Poison","description":"End-slot damage bypasses block, including a stunned slot. Lose one stack after ticking.","hook":"end_slot","cap":12},
		"resolve":{"name":"Resolve","description":"Bosses reject external stun for two slots after a stun skip.","hook":"end_slot","cap":2}
	}
	return pack

static func load_content_pack(path: String = "res://content/full_content.tres") -> Array:
	var pack: Resource
	if path.ends_with(".json"):
		var file: FileAccess = FileAccess.open(path,FileAccess.READ)
		if file == null:
			return ["Cannot read content pack: "+path]
		var imported: Dictionary = ContentPack.from_json(file.get_as_text())
		if not imported.errors.is_empty():
			return imported.errors
		pack = imported.pack
	else:
		if not ResourceLoader.exists(path):
			return ["Missing content pack: "+path]
		pack = load(path)
	if not pack is ContentPack:
		return ["Content asset has the wrong Resource type"]
	var errors: Array = pack.validate({"heroes":HEROES,"skills":SKILLS,"dice":DICE,"relics":RELICS,"enemies":ENEMIES})
	if pack.content_version != CONTENT_VERSION:
		errors.append("Content version does not match this rules build")
	if errors.is_empty():
		_content_pack = pack
	return errors

static func export_content_pack(path: String, use_defaults: bool = false) -> Error:
	var pack: Resource = default_content_pack() if use_defaults or _content_pack == null else _content_pack
	if path.ends_with(".json"):
		var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(pack.to_json()+"\n")
		return OK
	return ResourceSaver.save(pack,path)
