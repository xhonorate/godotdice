class_name DeepOddities
extends RefCounted
## Oddities: the crafting gambles a chamber can hold, and the cards of the rooms where dice
## are worked.
##
## An oddity is a card with two or three choices. Each choice carries an action from the
## fixed list below and shows its odds on the card. A card with a `room` belongs to a chamber
## of that kind (a smithy, a carver) and is never drawn at random. Dice are only ever worked
## here, never bought or swapped: made a size bigger or smaller, their faces raised or recut. `apply()` resolves one player's choice
## against their own stones and dice; it never touches another player. Every roll comes
## from the oddities RNG stream. Besides the stones it made and the ids it took, a result
## names the stones it changed and the dice it made or changed, so a screen can show them.

const ACTIONS: Array = ["none", "reroll_cut", "reroll_clarity", "remove_inclusion", "reveal_inclusions", "fuse", "geode", "grind", "engrave",
	"trade_up", "shrine", "idol", "copy_inclusion", "collector_sell", "heal", "ore", "vug",
	"appraise", "tumble", "upsize", "downsize", "temper", "raise_face", "copy_face", "pry", "chips", "wishing_well"]
const SIZES: Array = ["D4", "D6", "D8", "D10", "D12", "D20"]

static func validate(def: Variant) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if def.has("room") and not str(def.room) in DeepDescent.CARD_ROOMS:
		errors.append("unknown room " + str(def.room))
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

static func resize_refusal(die: Dictionary, steps: int) -> String:
	## Why this die cannot be made `steps` sizes bigger (smaller when negative), or "".
	var at: int = SIZES.find(str(die.get("shape", "")))
	if at < 0:
		return "that die cannot change size"
	if at + steps >= SIZES.size():
		return "that die is as big as dice come"
	if at + steps < 0:
		return "that die is as small as dice come"
	return ""

static func resize(die: Dictionary, steps: int) -> String:
	## The die, in place, `steps` sizes bigger or smaller: it keeps its id and its engraving,
	## and its faces become the plain numbers of its new size. Returns why not, or "".
	var refusal: String = resize_refusal(die, steps)
	if not refusal.is_empty():
		return refusal
	var key: String = str(SIZES[SIZES.find(str(die.shape)) + steps])
	var made: Dictionary = DeepDice.make(key, DeepContent.die(key), str(die.id), str(die.get("engraving", "")))
	die.clear()
	die.merge(made)
	return ""

static func apply(action: Dictionary, player: Dictionary, payload: Dictionary, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	## ctx: mine (Dictionary), depth, run (id), party (int). Returns {ok, error, message, made: [stones], lost: [ids]}.
	var kind: String = str(action.get("kind", "none"))
	var out: Dictionary = {"ok": true, "error": "", "message": "", "made": [], "lost": [], "changed": [], "dice": []}
	var mine: Dictionary = ctx.get("mine", {})
	var depth: int = int(ctx.get("depth", 1))
	match kind:
		"none":
			out.message = "You leave it be."
		"reroll_cut":
			## The wheel never makes a cut truer for the asking: it cuts the stone again, and
			## what comes off is a fresh draw from the table this depth rolls on.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose one of your stones")
			if not bool(stone.get("appraised", false)):
				return _refuse("a raw stone has no cut to speak of yet")
			if DeepRng.chance(rng, float(action.get("shatter", 8))):
				remove_stone(player, str(stone.id))
				out.lost.append(str(stone.id))
				out.message = "The stone shatters on the wheel."
			else:
				var was: int = int(stone.get("cut", 0))
				var now: int = DeepForge.reroll_cut(rng, stone, mine, depth, int(action.get("bonus", 0)))
				out.changed.append(stone.duplicate(true))
				out.message = "%s off the wheel, and it comes off %s." % [DeepContent.cut_name(was), DeepContent.cut_name(now)]
		"reroll_clarity":
			## The same for what a stone is made of, and since clarity is what it carries
			## frozen inside it, whatever is in there is drawn again with it.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose one of your stones")
			if not bool(stone.get("appraised", false)):
				return _refuse("a raw stone has no clarity to speak of yet")
			if DeepRng.chance(rng, float(action.get("shatter", 8))):
				remove_stone(player, str(stone.id))
				out.lost.append(str(stone.id))
				out.message = "The stone cracks across in the heat."
			else:
				var rolled: Dictionary = DeepForge.reroll_clarity(rng, stone, mine, depth, int(action.get("bonus", 0)))
				out.changed.append(stone.duplicate(true))
				var named: Array = DeepStone.inclusion_names(stone)
				out.message = "%s in, %s out." % [DeepContent.clarity_name(int(rolled.was)), DeepContent.clarity_name(int(rolled.clarity))]
				if not named.is_empty():
					out.message += " Inside it now: %s." % ", ".join(named)
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
			var etched: int = DeepContent.clarity_index("ETCHED")
			idol.clarity = etched if etched >= 0 else int(idol.clarity)
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
		"collector_sell":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose a stone to sell")
			var paid: int = DeepStone.value(stone) * int(action.get("mult", 3))
			player.ore = int(player.get("ore", 0)) + paid
			remove_stone(player, str(stone.id))
			out.lost.append(str(stone.id))
			out.message = "The collector pays %d pyrite and the stone is gone." % paid
		"appraise":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty() or bool(stone.get("appraised", false)):
				return _refuse("choose a raw stone")
			stone.appraised = true
			stone.inclusions_revealed = true
			out.changed.append(stone.duplicate(true))
			out.message = "Through the one good lens: a %s." % DeepStone.name(stone)
		"tumble":
			## The drum keeps the stone's size, cut, clarity and whatever is frozen inside it,
			## and turns out another skill of the same color. A socketed stone never comes out
			## as a skill already set beside it.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty() or DeepStone.is_birthstone(stone):
				return _refuse("choose one of your stones")
			var color: String = DeepStone.color(stone)
			var beside: Array = []
			var socketed: bool = false
			for other in player.get("rail", []):
				if other is Dictionary:
					if str(other.id) == str(stone.id):
						socketed = true
					else:
						beside.append(str(other.skill))
			var pool: Array = DeepForge.skill_pool(mine).filter(func(k: String) -> bool:
				return str(DeepContent.skill(k).get("color", "")) == color and k != str(stone.skill) and not (socketed and beside.has(k)))
			if pool.is_empty():
				return _refuse("nothing else of that color could come out of the drum")
			stone.skill = DeepForge.roll_skill(rng, mine, pool)
			out.changed.append(stone.duplicate(true))
			if bool(stone.get("appraised", false)):
				out.message = "The drum stops. The stone is a %s now." % str(DeepStone.skill_of(stone).get("name", stone.skill))
			else:
				out.message = "The drum stops. Something in the stone has changed; only an appraisal will say what."
		"upsize", "downsize":
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			if die.is_empty():
				return _refuse("choose a die to hammer" if kind == "upsize" else "choose a die to file down")
			var refusal: String = resize(die, 1 if kind == "upsize" else -1)
			if not refusal.is_empty():
				return _refuse(refusal)
			out.dice.append(die.duplicate(true))
			out.message = ("The anvil rings. Your die comes away a %s." if kind == "upsize" else "The file bites. Your die comes away a %s.") % DeepDice.describe(die)
		"temper":
			## The lowest face comes up, never past what the die can show; a blank face
			## becomes a number.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			if die.is_empty() or die.get("faces", []).is_empty():
				return _refuse("choose a die to temper")
			var low: int = 0
			for index in range(die.faces.size()):
				if _shown(die.faces[index]) < _shown(die.faces[low]):
					low = index
			var before: int = _shown(die.faces[low])
			var after: int = mini(before + int(action.get("amount", 2)), maxi(DeepDice.top(die), before))
			if after <= before:
				return _refuse("every face of that die is already as high as it goes")
			var kind_was: String = str(die.faces[low].get("kind", "plain"))
			die.faces[low] = DeepDice.face(after, "plain" if kind_was == "blank" else kind_was)
			out.dice.append(die.duplicate(true))
			out.message = "The lowest face comes up from %d to %d." % [before, after]
		"raise_face":
			## One chosen face comes up, never past the die's own highest face (or the top it
			## is judged against); a blank face becomes a number.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var face: int = int(payload.get("face", -1))
			if die.is_empty() or face < 0 or face >= die.get("faces", []).size():
				return _refuse("choose a die and a face to raise")
			var before: int = _shown(die.faces[face])
			var after: int = mini(before + maxi(1, int(action.get("amount", 1))), maxi(_ceiling(die), before))
			if after <= before:
				return _refuse("that face is already as high as the die goes")
			var kind_was: String = str(die.faces[face].get("kind", "plain"))
			die.faces[face] = DeepDice.face(after, "plain" if kind_was == "blank" else kind_was)
			out.dice.append(die.duplicate(true))
			out.message = "The chisel lifts a face: the %s is a %s now." % [_face_words(DeepDice.face(before, kind_was)), _face_words(die.faces[face])]
		"copy_face":
			## One face recut to show another face's number. Only the number is copied: a
			## special face gives its value, never what makes it special.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var face: int = int(payload.get("face", -1))
			var from: int = int(payload.get("from", -1))
			var count: int = die.get("faces", []).size()
			if die.is_empty() or face < 0 or from < 0 or face >= count or from >= count or face == from:
				return _refuse("choose a die, a face to recut and a face to copy")
			if str(die.faces[from].get("kind", "plain")) == "blank":
				return _refuse("a blank face has no number to copy")
			var was: Dictionary = die.faces[face].duplicate()
			var copied: Dictionary = DeepDice.face(int(die.faces[from].get("value", 0)))
			if str(was.get("kind", "plain")) == "plain" and int(was.get("value", 0)) == int(copied.value):
				return _refuse("that face already shows that number")
			die.faces[face] = copied
			out.dice.append(die.duplicate(true))
			out.message = "The carver recuts the %s into a %s." % [_face_words(was), _face_words(copied)]
		"pry":
			var stone: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(action.get("bonus", 4)), {"run": ctx.get("run", ""), "source": "seam"})
			player.haul.append(stone)
			out.made.append(stone)
			var cost: int = int(action.get("hp", 8))
			player.hp = maxi(1, int(player.get("hp", 0)) - cost)
			out.message = "It comes loose, and the edge opens your hand: %d health." % cost
		"chips":
			for _i in range(maxi(1, int(action.get("count", 2)))):
				var chip: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(action.get("bonus", -2)), {"run": ctx.get("run", ""), "source": "seam"})
				player.haul.append(chip)
				out.made.append(chip)
			out.message = "You gather what the seam has already let go of."
		"heal":
			var gained: int = int(ceil(float(player.get("max_hp", 0)) * float(action.get("pct", 25)) / 100.0))
			player.hp = mini(int(player.get("max_hp", 0)), int(player.get("hp", 0)) + gained)
			out.message = "You recover %d." % gained
		"ore":
			player.ore = int(player.get("ore", 0)) + int(action.get("amount", 5))
			out.message = "You take %d pyrite." % int(action.get("amount", 5))
		"vug":
			out.vug = true
			out.message = "You squeeze into the vug. The walls glitter and the air is bad."
		"wishing_well":
			## The well takes and gives. A stone dropped down it comes back as another drawn
			## around what went in, centred a little above it; ore dropped down it comes back
			## as a stone still in its rock, and the more ore the better the odds — though
			## even a hundred of it is only a chance, and a slim one at an opal.
			var most: int = int(action.get("most", 100))
			if str(action.get("mode", "stone")) == "ore":
				var least: int = int(action.get("least", 10))
				var spent: int = clampi(int(payload.get("ore", 0)), least, most)
				if int(player.get("ore", 0)) < spent:
					return _refuse("you have not the pyrite to throw in")
				player.ore = int(player.ore) - spent
				var share: float = float(spent) / float(maxi(1, most))
				var pool: Array = DeepForge.opal_pool() if DeepRng.chance(rng, float(action.get("opal_pct", 4)) * share) else []
				var won: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(round(share * float(action.get("reach", 8)))),
					{"run": str(ctx.get("run", "")), "source": "well"}, "", pool)
				player.haul.append(won)
				out.made.append(won)
				out.message = "%d pyrite goes down into the dark. Something comes back up: %s, still in its rock." % [spent, DeepStone.raw_name(won).to_lower()]
			else:
				var offered: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
				if offered.is_empty():
					return _refuse("choose one of your stones")
				if not bool(offered.get("appraised", false)):
					return _refuse("the well only takes a stone you have read")
				if DeepStone.is_locked(offered):
					return _refuse("a Knot cannot leave its socket")
				var score: float = float(DeepStone.grade(offered).score)
				## What it is trying to hand back: a little better than what it was given,
				## with plenty of room either side of that.
				var target: float = DeepRng.normal(rng, score * 1.06 + 3.0, float(action.get("spread", 9)))
				var bonus: int = clampi(int(round(score / 7.0)), 0, 14)
				var best: Dictionary = {}
				var gap: float = INF
				for _try in range(5):
					var candidate: Dictionary = DeepForge.roll_stone(rng, mine, depth, bonus, {"run": str(ctx.get("run", "")), "source": "well"})
					var off: float = absf(float(DeepStone.grade(candidate).score) - target)
					if off < gap:
						gap = off
						best = candidate
				best.appraised = true
				best.inclusions_revealed = true
				remove_stone(player, str(offered.id))
				out.lost.append(str(offered.id))
				player.haul.append(best)
				out.made.append(best)
				out.message = "%s goes down into the water. The well gives back %s." % [DeepStone.name(offered), DeepStone.name(best)]
		_:
			return _refuse("unknown oddity action")
	return out

static func _shown(f: Dictionary) -> int:
	## What a face counts for when looking for the lowest: a blank shows nothing.
	return 0 if str(f.get("kind", "plain")) == "blank" else int(f.get("value", 0))

static func _ceiling(die: Dictionary) -> int:
	## The most a face may be raised to: the top a die is judged against when it names one,
	## otherwise its own highest face. An engraving never lifts it.
	if int(die.get("top", 0)) > 0:
		return int(die.top)
	var best: int = 0
	for f in die.get("faces", []):
		best = maxi(best, _shown(f))
	return best

static func _face_words(f: Dictionary) -> String:
	## "4", "wild 6", "blank": a face the way a result names it.
	var kind: String = str(f.get("kind", "plain"))
	if kind == "blank":
		return "blank"
	return str(int(f.get("value", 0))) if kind == "plain" else "%s %d" % [kind, int(f.get("value", 0))]

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "message": "", "made": [], "lost": [], "changed": [], "dice": []}
