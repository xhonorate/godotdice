class_name DeepOddities
extends RefCounted
## Oddities: the crafting gambles a chamber can hold.
##
## An oddity is a card with two or three choices. Each choice carries an action from the
## fixed list below and shows its odds on the card. `apply()` resolves one player's choice
## against their own stones and dice; it never touches another player. Every roll comes
## from the oddities RNG stream.

const ACTIONS: Array = ["none", "recut", "remove_inclusion", "reveal_inclusions", "fuse", "geode", "grind", "engrave",
	"trade_up", "shrine", "idol", "copy_inclusion", "dice_swap", "collector_sell", "loupes", "heal", "ore", "vug"]

static func validate(def: Variant) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	var choices: Variant = def.get("choices", null)
	if not choices is Array or choices.size() < 2 or choices.size() > 3:
		errors.append("needs two or three choices")
		return errors
	for index in range(choices.size()):
		var choice: Variant = choices[index]
		if not choice is Dictionary:
			errors.append("choice %d must be an object" % (index + 1))
			continue
		if str(choice.get("id", "")).is_empty():
			errors.append("choice %d needs an id" % (index + 1))
		var action: Variant = choice.get("action", null)
		if not action is Dictionary or not str(action.get("kind", "")) in ACTIONS:
			errors.append("choice %d has an unknown action" % (index + 1))
	return errors

static func find_stone(player: Dictionary, stone_id: String) -> Dictionary:
	for stone in player.get("haul", []):
		if str(stone.get("id", "")) == stone_id:
			return stone
	for stone in player.get("rail", []):
		if stone is Dictionary and str(stone.get("id", "")) == stone_id:
			return stone
	return {}

static func remove_stone(player: Dictionary, stone_id: String) -> bool:
	var haul: Array = player.get("haul", [])
	for index in range(haul.size()):
		if str(haul[index].get("id", "")) == stone_id:
			haul.remove_at(index)
			return true
	var rail: Array = player.get("rail", [])
	for index in range(rail.size()):
		if rail[index] is Dictionary and str(rail[index].get("id", "")) == stone_id:
			rail[index] = null
			return true
	return false

static func find_die(player: Dictionary, die_id: String) -> Dictionary:
	for die in player.get("dice", []):
		if str(die.get("id", "")) == die_id:
			return die
	for die in player.get("bag_dice", []):
		if str(die.get("id", "")) == die_id:
			return die
	return {}

static func apply(action: Dictionary, player: Dictionary, payload: Dictionary, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	## ctx: mine (Dictionary), depth, run (id), party (int). Returns {ok, error, message, made: [stones], lost: [ids]}.
	var kind: String = str(action.get("kind", "none"))
	var out: Dictionary = {"ok": true, "error": "", "message": "", "made": [], "lost": []}
	var mine: Dictionary = ctx.get("mine", {})
	var depth: int = int(ctx.get("depth", 1))
	match kind:
		"none":
			out.message = "You leave it be."
		"recut":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose one of your stones")
			var roll: float = rng.randf() * 100.0
			var up: float = float(action.get("up", 60))
			var down: float = float(action.get("down", 30))
			if roll < up:
				stone.cut = mini(int(stone.cut) + 1, DeepPatterns.STEPS - 1)
				out.message = "The wheel finds a truer angle: the cut is now %s." % DeepContent.cut_name(int(stone.cut))
			elif roll < up + down:
				stone.cut = maxi(int(stone.cut) - 1, 0)
				out.message = "The wheel bites too deep: the cut is now %s." % DeepContent.cut_name(int(stone.cut))
			else:
				remove_stone(player, str(stone.id))
				out.lost.append(str(stone.id))
				out.message = "The stone shatters on the wheel."
		"remove_inclusion":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			var key: String = str(payload.get("inclusion", ""))
			if stone.is_empty() or not stone.get("inclusions", []).has(key):
				return _refuse("choose a stone and one of its inclusions")
			stone.inclusions.erase(key)
			out.message = "The acid eats the %s away." % str(DeepContent.inclusion(key).get("name", key))
		"reveal_inclusions":
			var count: int = 0
			for stone in player.get("haul", []):
				if not bool(stone.get("inclusions_revealed", false)):
					stone.inclusions_revealed = true
					count += 1
			out.message = "The bath shows what is frozen inside %d stones." % count
		"fuse":
			var keep: Dictionary = find_stone(player, str(payload.get("keep_id", "")))
			var feed: Dictionary = find_stone(player, str(payload.get("feed_id", "")))
			if keep.is_empty() or feed.is_empty() or str(keep.id) == str(feed.id):
				return _refuse("choose two different stones")
			keep.carat = mini(int(keep.carat) + int(feed.carat), DeepStone.carat_max())
			var survivors: Array = []
			for key in keep.get("inclusions", []) + feed.get("inclusions", []):
				if not survivors.has(key) and DeepRng.chance(rng, float(action.get("survive", 50))):
					survivors.append(key)
			keep.inclusions = survivors
			remove_stone(player, str(feed.id))
			out.lost.append(str(feed.id))
			out.message = "The crucible gives back one stone of %d carats." % int(keep.carat)
		"geode":
			var roll: float = rng.randf() * 100.0
			var three: float = float(action.get("three", 45))
			var one: float = float(action.get("one", 35))
			if roll < three:
				for _i in range(3):
					var small: Dictionary = DeepForge.roll_stone(rng, mine, depth, -2, {"run": ctx.get("run", ""), "source": "geode"})
					player.haul.append(small)
					out.made.append(small)
				out.message = "The geode splits into three small stones."
			elif roll < three + one:
				var big: Dictionary = DeepForge.roll_stone(rng, mine, depth, 6, {"run": ctx.get("run", ""), "source": "geode"})
				player.haul.append(big)
				out.made.append(big)
				out.message = "One heavy stone rolls out of the geode."
			else:
				out.message = "Dust. The geode was hollow."
		"grind":
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var face: int = int(payload.get("face", -1))
			if die.is_empty() or face < 0 or face >= die.get("faces", []).size() or die.faces.size() < 2:
				return _refuse("choose a die and a face to grind off")
			var neighbour: int = (face + 1) % die.faces.size()
			die.faces[face] = die.faces[neighbour].duplicate(true)
			out.message = "The grinder takes one face and leaves its neighbour twice."
		"engrave":
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var engraving: String = str(payload.get("engraving", action.get("engraving", "")))
			if die.is_empty() or not engraving in DeepDice.ENGRAVINGS:
				return _refuse("choose a die and an engraving")
			var roll: float = rng.randf() * 100.0
			if roll < float(action.get("success", 40)):
				die.engraving = engraving
				out.message = "The engraving takes: the die is now %s." % engraving.replace("_", " ")
			elif roll < float(action.get("success", 40)) + float(action.get("crack", 10)):
				var top_index: int = 0
				for index in range(die.faces.size()):
					if int(die.faces[index].get("value", 0)) > int(die.faces[top_index].get("value", 0)):
						top_index = index
				die.faces[top_index] = DeepDice.face(1)
				out.message = "The die cracks along its best face."
			else:
				out.message = "The needle slips. Nothing changes."
		"trade_up":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose a stone to trade")
			var bigger: Dictionary = DeepForge.roll_stone(rng, mine, depth, 0, {"run": ctx.get("run", ""), "source": "prospector"})
			bigger.carat = mini(int(stone.carat) + int(action.get("carats", 1)), DeepStone.carat_max())
			remove_stone(player, str(stone.id))
			out.lost.append(str(stone.id))
			player.haul.append(bigger)
			out.made.append(bigger)
			out.message = "The prospector hands you a heavier stone, sight unseen."
		"shrine":
			var pattern: String = str(payload.get("pattern", ""))
			if not pattern in DeepPatterns.KINDS or pattern == "always":
				return _refuse("choose a pattern")
			if not player.has("run_mods"):
				player.run_mods = {}
			player.run_mods.shrine = pattern
			out.message = "The shrine remembers your pattern. Gems that fire on it gain a carat this run."
		"idol":
			var idol: Dictionary = DeepForge.roll_stone(rng, mine, depth, 0, {"run": ctx.get("run", ""), "source": "idol"})
			idol.carat = clampi(maxi(int(idol.carat), int(action.get("carat_min", 16))), 1, DeepStone.carat_max())
			var veined: int = DeepContent.clarity_index("VEINED")
			idol.clarity = veined if veined >= 0 else int(idol.clarity)
			idol.inclusions = DeepForge.roll_inclusions(rng, 2, mine, "FRACTURE")
			idol.appraised = true
			idol.inclusions_revealed = true
			player.haul.append(idol)
			out.made.append(idol)
			out.message = "The idol's eye comes loose in your hand. It is heavy, and it is cracked."
		"copy_inclusion":
			var source: Dictionary = find_stone(player, str(payload.get("from_id", "")))
			var target: Dictionary = find_stone(player, str(payload.get("to_id", "")))
			var key: String = str(payload.get("inclusion", ""))
			if source.is_empty() or target.is_empty() or not source.get("inclusions", []).has(key):
				return _refuse("choose an inclusion and a stone to copy it to")
			if target.get("inclusions", []).has(key):
				return _refuse("that stone already carries it")
			if target.inclusions.size() >= DeepStone.inclusion_slots(int(target.clarity)):
				return _refuse("that stone has no room inside it")
			target.inclusions.append(key)
			out.message = "The echo takes: both stones now carry %s." % str(DeepContent.inclusion(key).get("name", key))
		"dice_swap":
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			if die.is_empty():
				return _refuse("choose a die to swap")
			var fresh: Dictionary = DeepForge.roll_die(rng, mine, depth)
			var guard: int = 0
			while str(fresh.shape) != str(die.shape) and guard < 12:
				fresh = DeepForge.roll_die(rng, mine, depth)
				guard += 1
			fresh.id = str(die.id)
			for field in fresh:
				die[field] = fresh[field]
			out.message = "You draw a %s from the bowl." % DeepDice.describe(die)
		"collector_sell":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose a stone to sell")
			var paid: int = DeepStone.value(stone) * int(action.get("mult", 3))
			player.ore = int(player.get("ore", 0)) + paid
			remove_stone(player, str(stone.id))
			out.lost.append(str(stone.id))
			out.message = "The collector pays %d ore and the stone is gone." % paid
		"loupes":
			player.loupes = int(player.get("loupes", 0)) + int(action.get("amount", 2))
			out.message = "You pocket %d loupes." % int(action.get("amount", 2))
		"heal":
			var gained: int = int(ceil(float(player.get("max_hp", 0)) * float(action.get("pct", 25)) / 100.0))
			player.hp = mini(int(player.get("max_hp", 0)), int(player.get("hp", 0)) + gained)
			out.message = "You recover %d." % gained
		"ore":
			player.ore = int(player.get("ore", 0)) + int(action.get("amount", 5))
			out.message = "You take %d ore." % int(action.get("amount", 5))
		"vug":
			out.vug = true
			out.message = "You squeeze into the vug. The walls glitter and the air is bad."
		_:
			return _refuse("unknown oddity action")
	return out

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "message": "", "made": [], "lost": []}
