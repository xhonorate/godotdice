class_name DeepOddities
extends RefCounted
## Oddities: the crafting gambles a chamber can hold, and the cards of the rooms where dice
## are worked.
##
## An oddity is a card with two to four choices. Each choice carries an action from the
## fixed list below and shows its odds on the card. A card with a `room` belongs to a chamber
## of that kind (a smithy, a carver) and is never drawn at random. Dice are only ever worked
## here, never bought or swapped: made a size bigger or smaller, their faces raised or lowered. `apply()` resolves one player's choice
## against their own stones and dice; it never touches another player. Every roll comes
## from the oddities RNG stream. Besides the stones it made and the ids it took, a result
## names the stones it changed and the dice it made or changed, so a screen can show them.

const ACTIONS: Array = ["none", "reroll_cut", "reroll_clarity", "push_clarity", "remove_inclusion", "fuse", "geode_buy", "etch", "pattern", "material", "reset",
	"trade_up", "shrine", "idol", "echo_stone", "collector_sell", "collector_buy", "heal", "ore",
	"appraise", "acid_appraise", "tumble", "upsize", "downsize", "temper", "raise_face", "lower_face", "pry", "chips", "wishing_well", "hollow"]
const SIZES: Array = DeepDice.TIERS
## The fewest dice the Hollow leaves anybody with, unless its card says otherwise.
const HOLLOW_LEAST_DICE: int = 3
## Actions the room has to lay something out before anybody chooses: the Collector's case is
## rolled when the chamber opens, and the Idol's grip is rolled the first time it is pulled.
const OFFERS: Array = ["collector_buy", "geode_buy", "pattern", "etch", "material"]

static func validate(def: Variant) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if def.has("room") and not str(def.room) in DeepDescent.CARD_ROOMS:
		errors.append("unknown room " + str(def.room))
	var choices: Variant = def.get("choices", null)
	if not choices is Array or choices.size() < 2 or choices.size() > 4:
		errors.append("needs between two and four choices")
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
	## A stone anywhere the player has it: the bag, a socket, or riding one.
	for stone in player.get("haul", []):
		if str(stone.get("id", "")) == stone_id:
			## A Geode is only carried: nothing down here can be done to one, so none is found.
			return stone if not DeepStone.is_geode(stone) else {}
	for stone in DeepStone.rail_stones(player):
		if str(stone.get("id", "")) == stone_id:
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
	var riders: Array = player.get("riders", [])
	for socket in range(riders.size()):
		if not riders[socket] is Array:
			continue
		for at in range(riders[socket].size()):
			if riders[socket][at] is Dictionary and str(riders[socket][at].get("id", "")) == stone_id:
				riders[socket].remove_at(at)
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

static func hollow_refusal(stone: Dictionary, player: Dictionary = {}) -> String:
	## Why the Hollow cannot make this stone Void, or "". A gem from the bag goes onto the
	## rail, so it must be one the rail can take: one of each skill (`rail_duplicate`).
	if stone.is_empty() or DeepStone.is_birthstone(stone) or DeepStone.is_geode(stone):
		return "choose one of your gems"
	if not bool(stone.get("appraised", false)):
		return "nobody has read it yet"
	if DeepStone.is_slotless(stone):
		return "it takes no socket already"
	if not player.is_empty():
		return DeepDescent.rail_duplicate(player, stone)
	return ""

static func hollow_least(action: Dictionary) -> int:
	return maxi(1, int(action.get("least_dice", HOLLOW_LEAST_DICE)))

static func hollow_host(player: Dictionary, stone: Dictionary) -> int:
	## The socket a gem made Void out of the bag rides: the first with a gem set in it, so it
	## has something to fire after, else the first that will take it; -1 when none will.
	var rail: Array = player.get("rail", [])
	for filled in [true, false]:
		for index in range(rail.size()):
			if (rail[index] is Dictionary) == filled and DeepDescent.socket_refusal(player, stone, index).is_empty():
				return index
	return -1

# --- what a card's work can be done to -------------------------------------------------------
##
## The card's screen greys out a piece of work with nothing to take (descent_screen.gd asks
## these), and the draw at an oddity asks the same of the whole party: a card nobody could do
## a thing at is drawn again, so a room behind "Something odd" is never only a "Leave it".

static func carried(player: Dictionary, loose_only: bool = false) -> Array:
	## Every stone the player has to hand: the bag, then the rail with its riders unless only
	## the loose ones are asked for. Never a sealed Geode: nothing down here can be done to
	## one (read, sold, worked on, thrown in a well).
	var out: Array = player.get("haul", []).filter(func(s: Dictionary) -> bool: return not DeepStone.is_geode(s))
	if not loose_only:
		out.append_array(DeepStone.rail_stones(player))
	return out

static func work_refusal(action: Dictionary, item: Dictionary, player: Dictionary = {}, offer: Dictionary = {}) -> String:
	## Why this die or this stone cannot take this piece of work, or "". A d4 cannot be filed
	## any smaller and a stone nobody has read has no cut to draw again: neither should be
	## offered and then refused. `offer` is what the room laid out (the anvil's pattern).
	match str(action.get("kind", "")):
		"upsize":
			return resize_refusal(item, 1)
		"downsize":
			return resize_refusal(item, -1)
		"raise_face":
			## The chisel has no ceiling, and neither does a face: any die with a face takes it.
			return "" if not item.get("faces", []).is_empty() else "it has no faces to raise"
		"lower_face":
			for f in item.get("faces", []):
				if str(f.get("kind", "plain")) != "blank" and int(f.get("value", 0)) > 1:
					return ""
			return "every face is already as low as it goes"
		"reroll_cut", "reroll_clarity", "push_clarity", "collector_sell", "tumble", "fuse":
			if str(action.get("kind", "")) == "collector_sell" and DeepStone.known_fragile(item):
				return "fragile stones cannot be sold"
			if not bool(item.get("appraised", false)):
				return "nobody has read it yet"
			if DeepStone.is_locked(item):
				return "a Knot cannot leave its socket"
			## The oven's own rule (push_clarity): a stone at the end of the ladder has nowhere to go.
			if str(action.get("kind", "")) == "push_clarity":
				var was: int = int(item.get("clarity", DeepContent.clear_index()))
				if DeepForge.stepped_clarity(was, maxi(1, int(action.get("steps", 1)))) == was:
					return "it is as far from Clear as the ladder goes"
			return ""
		"wishing_well", "trade_up", "echo_stone":
			## These take a stone as it is: rough or read, it makes no difference to them.
			if DeepStone.is_locked(item):
				return "a Knot cannot leave its socket"
			## The well's own rule (wishing_well): offered here, it was only refused on "Do it".
			if str(action.get("kind", "")) == "wishing_well" and DeepStone.is_fragile(item):
				return "the well will not take a fragile stone"
			return ""
		"remove_inclusion":
			return "" if not item.get("inclusions", []).is_empty() else "nothing is frozen inside it"
		"appraise":
			return "" if not bool(item.get("appraised", false)) else "it has already been read"
		"hollow":
			## Any of the five dice will go down the hole; only a read gem with a socket to give up comes away Void.
			return "" if item.has("faces") else hollow_refusal(item, player)
		"reset":
			## The vat keeps a die's size and its material: one with no pattern and nothing
			## etched on it would come out exactly as it went in.
			if str(item.get("pattern", "")).is_empty() and DeepDice.etchings(item).is_empty():
				return "it is as plain as they come already"
		"pattern":
			## The anvil is set for one pattern, and not every size of die can take it.
			if not bool(action.get("random", false)):
				var pattern: String = str(offer.get("pattern", action.get("pattern", "")))
				if not pattern.is_empty() and not DeepDice.pattern_allows(pattern, str(item.get("shape", "D6"))):
					return "it is the wrong size for this pattern"
	return ""

static func nothing_to_work(needs: String, action: Dictionary, player: Dictionary, offer: Dictionary = {}) -> bool:
	## Whether a piece of work that `needs` something has nothing of the player's it could be
	## done to at all.
	match needs:
		"die", "die_face":
			var dice: Array = player.get("dice", [])
			## A die the work would refuse (a plain one in the vat, a d4 at the file) is not one it could be done to.
			return dice.is_empty() or (not action.is_empty() and not dice.any(func(d: Dictionary) -> bool: return work_refusal(action, d, player, offer).is_empty()))
		"raw_stone", "raw_stones":
			return carried(player, true).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false))).is_empty()
		"ore":
			return int(player.get("ore", 0)) < DeepDescent.WISH_LEAST
		"offer":
			return offer.get("stone", null) == null
		"inclusion":
			return carried(player).filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false)))).is_empty()
		"two_stones":
			return carried(player).filter(func(s: Dictionary) -> bool: return work_refusal(action, s, player, offer).is_empty()).size() < 2
		"stone":
			## A stone the work would refuse (a fragile one down a well, a Knot) is not one it could be done to.
			return not carried(player).any(func(s: Dictionary) -> bool: return work_refusal(action, s, player, offer).is_empty())
		"gem_and_die":
			return player.get("dice", []).size() <= hollow_least(action) or carried(player).all(func(s: Dictionary) -> bool: return not hollow_refusal(s, player).is_empty())
	return false

static func can_work(card: Dictionary, player: Dictionary, offer: Dictionary) -> bool:
	## Whether the player could do any of the card's work: a choice other than walking away,
	## with something of theirs to do it to and, where it is bought, the pyrite to pay.
	for choice in card.get("choices", []):
		var action: Dictionary = choice.get("action", {})
		var kind: String = str(action.get("kind", "none"))
		if kind == "none":
			continue
		if kind in ["geode_buy", "collector_buy"]:
			if offer.has("stone") and int(player.get("ore", 0)) >= int(offer.get("price", 0)):
				return true
			continue
		var needs: String = str(choice.get("needs", ""))
		if needs.is_empty() or not nothing_to_work(needs, action, player, offer):
			return true
	return false

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
	## The die, in place, `steps` sizes bigger or smaller: it keeps its id, its material and
	## every etching that still has a face to sit on. Its pattern is cut again across the new
	## size, and a face somebody had already worked higher than the pattern asks stays where
	## it was put: an hour at a carver's bench is not thrown away by an hour at an anvil.
	## Returns why not, or "".
	var refusal: String = resize_refusal(die, steps)
	if not refusal.is_empty():
		return refusal
	var key: String = str(SIZES[SIZES.find(str(die.shape)) + steps])
	var had: Array = die.get("faces", []).duplicate(true)
	var made: Dictionary = DeepDice.make(key, str(die.id), {"pattern": str(die.get("pattern", "")),
		"material": str(die.get("material", "")), "name": DeepDice.given_name(die)})
	for index in range(mini(had.size(), made.get("faces", []).size())):
		made.faces[index].kind = str(had[index].get("kind", "plain"))
		made.faces[index].value = maxi(int(made.faces[index].get("value", 0)), int(had[index].get("value", 0)))
	die.clear()
	die.merge(made)
	return ""

static func apply(action: Dictionary, player: Dictionary, payload: Dictionary, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	## ctx: mine (Dictionary), depth, run (id), party (int), and for the rooms that lay
	## something out first, `offer` (what the Collector has in her case) and `tries` (how far
	## this player has got with the Idol). Returns {ok, error, message, made: [stones],
	## lost: [ids], changed, dice}, and when a pull did not finish the job, `again` and the
	## `tries` to hand back the next time.
	var kind: String = str(action.get("kind", "none"))
	var out: Dictionary = {"ok": true, "error": "", "message": "", "made": [], "lost": [], "changed": [], "dice": []}
	var mine: Dictionary = ctx.get("mine", {})
	## The player's loadout luck rides on every stone a room gives them: it is folded into
	## the mine's own luck, which every roll below reads (DeepForge.luck).
	if float(ctx.get("luck", 0.0)) != 0.0:
		mine = mine.duplicate()
		mine.luck = int(round(float(DeepForge.mine_luck(mine)) + float(ctx.get("luck", 0.0))))
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
			if DeepRng.chance(rng, float(action.get("shatter", 4))):
				remove_stone(player, str(stone.id))
				out.lost.append(str(stone.id))
				out.broke = {"field": "cut", "stone": stone.duplicate(true)}
				out.message = "The stone shatters on the wheel."
			else:
				var was: int = int(stone.get("cut", 0))
				var now: int = DeepForge.reroll_cut(rng, stone, mine, depth, int(action.get("bonus", 0)))
				out.changed.append(stone.duplicate(true))
				out.verdict = {"field": "cut", "was": was, "now": now, "better": signi(now - was)}
				out.message = "The Cut goes from %s to %s." % [DeepContent.cut_name(was), DeepContent.cut_name(now)]
		"reroll_clarity":
			## The same for what a stone is made of, and since clarity is what it carries
			## frozen inside it, whatever is in there is drawn again with it.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose one of your stones")
			if not bool(stone.get("appraised", false)):
				return _refuse("a raw stone has no clarity to speak of yet")
			if DeepRng.chance(rng, float(action.get("shatter", 4))):
				remove_stone(player, str(stone.id))
				out.lost.append(str(stone.id))
				out.broke = {"field": "clarity", "stone": stone.duplicate(true)}
				out.message = "The stone cracks in the heat."
			else:
				var rolled: Dictionary = DeepForge.reroll_clarity(rng, stone, mine, depth, int(action.get("bonus", 0)))
				out.changed.append(stone.duplicate(true))
				var named: Array = DeepStone.inclusion_names(stone)
				out.verdict = _clarity_verdict(int(rolled.was), int(rolled.clarity))
				out.message = "The Clarity goes from %s to %s." % [DeepContent.clarity_name(int(rolled.was)), DeepContent.clarity_name(int(rolled.clarity))]
				if not named.is_empty():
					out.message += " Inside it now: %s." % ", ".join(named)
		"push_clarity":
			## The oven held hot and long. Clarity is driven one rung further from Clear along
			## the side it already leans, which is as much a gamble as it sounds: an Etched
			## stone comes out Intricate and carrying more, a Pristine one comes out Flawless.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose one of your stones")
			if not bool(stone.get("appraised", false)):
				return _refuse("a raw stone has no clarity to speak of yet")
			var was: int = int(stone.get("clarity", DeepContent.clear_index()))
			if DeepForge.stepped_clarity(was, maxi(1, int(action.get("steps", 1)))) == was:
				return _refuse("that stone is already as far from Clear as the ladder goes")
			if DeepRng.chance(rng, float(action.get("shatter", 4))):
				remove_stone(player, str(stone.id))
				out.lost.append(str(stone.id))
				out.broke = {"field": "clarity", "stone": stone.duplicate(true)}
				out.message = "The stone cracks in the heat."
			else:
				var pushed: Dictionary = DeepForge.step_clarity(rng, stone, mine, maxi(1, int(action.get("steps", 1))))
				out.changed.append(stone.duplicate(true))
				out.verdict = _clarity_verdict(int(pushed.was), int(pushed.clarity))
				var inside: Array = DeepStone.inclusion_names(stone)
				out.message = "It survives the heat. %s becomes %s." % [DeepContent.clarity_name(int(pushed.was)), DeepContent.clarity_name(int(pushed.clarity))]
				if not inside.is_empty():
					out.message += " Inside it now: %s." % ", ".join(inside)
		"remove_inclusion":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			var key: String = str(payload.get("inclusion", ""))
			if stone.is_empty() or not stone.get("inclusions", []).has(key):
				return _refuse("choose a stone and one of its inclusions")
			stone.inclusions.erase(key)
			out.message = "The acid eats the %s away." % str(DeepContent.inclusion(key).get("name", key))
		"acid_appraise":
			## The racks hold three. The acid eats the matrix off each in turn and takes its
			## price out of you for every one, whatever it finds underneath.
			var ids: Array = payload.get("stone_ids", [])
			if ids.is_empty():
				return _refuse("set at least one raw stone in the racks")
			if ids.size() > maxi(1, int(action.get("most", 3))):
				return _refuse("the racks hold only %d" % maxi(1, int(action.get("most", 3))))
			var each: int = maxi(0, int(action.get("hp", 6)))
			## Every stone is checked before the acid touches any, so a refused rack reads nothing.
			var racked: Array = []
			var seen: Array = []
			for raw_id in ids:
				var stone: Dictionary = find_stone(player, str(raw_id))
				if stone.is_empty() or bool(stone.get("appraised", false)) or seen.has(str(raw_id)):
					return _refuse("the racks take raw stones only")
				seen.append(str(raw_id))
				racked.append(stone)
			var read: Array = []
			for stone in racked:
				stone.appraised = true
				stone.inclusions_revealed = true
				read.append(stone.duplicate(true))
			out.changed.append_array(read)
			out.revealed = read.duplicate(true)
			player.hp = maxi(1, int(player.get("hp", 0)) - each * read.size())
			out.message = "The acid strips %d %s clean. You lose %d health." % [
				read.size(), "stone" if read.size() == 1 else "stones", each * read.size()]
		"fuse":
			## The crucible does not add two stones together: one survives it and takes some
			## of the other into itself. Which one is the fire's to decide, not the miner's,
			## and if the colors differed the loser's color is frozen in as a Zoning, so a
			## fused stone always shows where it came from.
			var keep: Dictionary = find_stone(player, str(payload.get("keep_id", "")))
			var feed: Dictionary = find_stone(player, str(payload.get("feed_id", "")))
			if keep.is_empty() or feed.is_empty() or str(keep.id) == str(feed.id):
				return _refuse("choose two different stones")
			## The room's fire is free: its price is the coin flip on which stone survives.
			## Only fusing a twin into the stone it matches is paid for (`fuse_cost`).
			if DeepRng.chance(rng, 50.0):
				var swap: Dictionary = keep
				keep = feed
				feed = swap
			var fused: Dictionary = fuse_stats(rng, keep, feed, mine, float(action.get("carry", 30)))
			## Whatever a fragile stone gave the fire is fragile too: nothing that cannot leave
			## the mine may be fused into something that can.
			var fragile: bool = DeepStone.is_fragile(keep) or DeepStone.is_fragile(feed)
			var temporary: bool = bool(keep.get("temporary", false)) or bool(feed.get("temporary", false))
			## The same for a copy of a vault stone, which goes home with nobody: the vault keeps
			## the stone itself, so nothing it fed the fire may ride the lift in another stone.
			var lent: bool = bool(keep.get("lent", false)) or bool(feed.get("lent", false))
			keep.merge(fused, true)
			if fragile:
				keep.fragile = true
			if temporary:
				keep.temporary = true
			if lent:
				keep.lent = true
			remove_stone(player, str(feed.id))
			out.lost.append(str(feed.id))
			out.changed.append(keep.duplicate(true))
			out.message = "The stones fuse into one: a %s, %d carats." % [
				str(DeepStone.skill_of(keep).get("name", keep.skill)), int(keep.carat)]
		"echo_stone":
			## The room rings and the rock answers with another of the same. Only the skill
			## carries across: the stone that forms is rolled fresh in every other way, which
			## is what makes it a second draw at a skill rather than a copy of a gem.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose one of your stones")
			var like: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(action.get("bonus", 2)),
				{"run": ctx.get("run", ""), "source": "echo"}, "", [str(stone.get("skill", ""))])
			like.appraised = false
			like.inclusions_revealed = false
			player.haul.append(like)
			out.made.append(like)
			out.message = "A raw stone with the same skill forms in the wall. It goes into your haul."
		"geode_buy":
			## One Geode, rolled when the room opened so the price on the card is the price paid.
			## It goes into the haul sealed: only the workshop can crack it.
			var offer: Dictionary = ctx.get("offer", {})
			if offer.is_empty() or not offer.has("stone"):
				return _refuse("there is no Geode here")
			var price: int = int(offer.get("price", 0))
			if int(player.get("ore", 0)) < price:
				return _refuse("you have not the pyrite for it")
			player.ore = int(player.ore) - price
			DeepBattle.tally_add(player, "spent", price)
			var bought: Dictionary = (offer.stone as Dictionary).duplicate(true)
			bought.provenance.finder = str(player.get("id", ""))
			player.haul.append(bought)
			out.made.append(bought)
			out.bought = true
			out.message = "You pay %d pyrite for the %s. It goes into your haul, sealed: only the workshop can crack it." % [price, DeepStone.raw_name(bought)]
		"etch":
			## The needles are set for one etching a night, and a chosen face always takes it.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var at: int = int(payload.get("face", -1))
			var etching: String = str(ctx.get("offer", {}).get("etching", payload.get("etching", action.get("etching", ""))))
			if bool(action.get("random", false)):
				etching = DeepForge.roll_etching(rng)
			if die.is_empty() or at < 0 or at >= die.get("faces", []).size() or not etching in DeepDice.FACE_KINDS:
				return _refuse("choose a die and a face to etch")
			DeepDice.etch(die, at, etching)
			out.dice.append(die.duplicate(true))
			## Which face it was, so the die can be shown turned to it.
			out.faces = {str(die.id): at}
			out.message = "The etching takes. That face is %s now." % DeepDice.etching_name(etching).to_lower()
		"pattern":
			## The anvil is set for one pattern a night, and it is cut across every face.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var pattern: String = str(ctx.get("offer", {}).get("pattern", payload.get("pattern", action.get("pattern", ""))))
			if bool(action.get("random", false)):
				pattern = DeepForge.roll_pattern(rng, str(die.get("shape", "D6")))
			if die.is_empty() or not pattern in DeepDice.PATTERNS:
				return _refuse("choose a die to stamp")
			if not DeepDice.pattern_allows(pattern, str(die.get("shape", "D6"))):
				return _refuse("that die is the wrong size for this pattern")
			var stamped: Dictionary = DeepDice.make(str(die.shape), str(die.id), {"pattern": pattern, "rng": rng,
				"material": str(die.get("material", "")), "etches": DeepDice.etchings(die), "name": DeepDice.given_name(die)})
			die.clear()
			die.merge(stamped)
			out.dice.append(die.duplicate(true))
			out.message = "Your die is now a %s." % DeepDice.describe(die)
		"material":
			## What is in the vat tonight, or whatever goes in after the die does.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var material: String = str(ctx.get("offer", {}).get("material", payload.get("material", action.get("material", ""))))
			if bool(action.get("random", false)):
				material = DeepForge.roll_material(rng)
			if die.is_empty() or not material in DeepDice.MATERIALS:
				return _refuse("choose a die to dip")
			die.material = material
			out.dice.append(die.duplicate(true))
			out.message = "Your die comes out %s." % DeepDice.material_name(material).to_lower()
		"reset":
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			if die.is_empty():
				return _refuse("choose a die to melt down")
			if str(die.get("pattern", "")).is_empty() and DeepDice.etchings(die).is_empty():
				return _refuse("that die is as plain as they come already")
			DeepDice.reset(die)
			out.dice.append(die.duplicate(true))
			out.message = "Your die comes out plain: %s." % DeepDice.describe(die)
		"trade_up":
			## He takes anything and hands back rock. What he gives is heavier than what he
			## took, by as little as nothing and as much as the card promises.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose a stone to trade")
			if DeepStone.is_locked(stone):
				return _refuse("a Knot cannot leave its socket")
			var bigger: Dictionary = DeepForge.roll_stone(rng, mine, depth, 0, {"run": ctx.get("run", ""), "source": "prospector"})
			var gained: int = rng.randi_range(int(action.get("carats", 0)), maxi(int(action.get("carats", 0)), int(action.get("carats_max", 2))))
			bigger.carat = mini(int(stone.carat) + gained, DeepStone.carat_max())
			bigger.appraised = false
			bigger.inclusions_revealed = false
			## What he hands back is no more free to leave the mine than what he took, as at the
			## crucible. A vault copy is the vault's loss instead (see DeepDescent `vault_spent`).
			if DeepStone.is_fragile(stone):
				bigger.fragile = true
			if bool(stone.get("temporary", false)):
				bigger.temporary = true
			remove_stone(player, str(stone.id))
			out.lost.append(str(stone.id))
			player.haul.append(bigger)
			out.made.append(bigger)
			out.message = "He takes your stone and hands you a raw one: %d carats." % int(bigger.carat)
		"shrine":
			var pattern: String = str(payload.get("pattern", ""))
			if not pattern in DeepPatterns.KINDS or pattern == "always":
				return _refuse("choose a pattern")
			if not player.has("run_mods"):
				player.run_mods = {}
			player.run_mods.shrine = pattern
			out.message = "Gems that fire on that pattern gain a carat for the rest of the run."
		"idol":
			## The eye is set deep. Between one and five pulls get it out, each costing more
			## blood than the last, and the room remembers how many are left. Its size is the
			## depth's, not a flat promise: an idol near the surface is a small, cracked thing.
			var tries: Dictionary = ctx.get("tries", {})
			var needed: int = int(tries.get("needed", 0))
			if needed <= 0:
				needed = rng.randi_range(1, maxi(1, int(action.get("tries_max", 5))))
			var pulled: int = int(tries.get("done", 0)) + 1
			var cost: int = maxi(0, int(action.get("hp", 3)) + int(action.get("hp_step", 2)) * (pulled - 1))
			player.hp = maxi(1, int(player.get("hp", 0)) - cost)
			out.tries = {"needed": needed, "done": pulled}
			out.hp_lost = cost
			if pulled < needed:
				out.again = true
				out.message = "It won't budge. You lose %d health." % cost
			else:
				var idol: Dictionary = DeepForge.roll_stone(rng, mine, depth, 0, {"run": ctx.get("run", ""), "source": "idol"})
				idol.carat = clampi(int(round(3.0 + DeepForge.luck(mine, depth))) + rng.randi_range(0, 3), 1, DeepForge.carat_cap(mine, depth))
				var etched: int = DeepContent.clarity_index("ETCHED")
				idol.clarity = etched if etched >= 0 else int(idol.clarity)
				idol.inclusions = DeepForge.roll_inclusions(rng, 2, mine, "FRACTURE")
				idol.appraised = true
				idol.inclusions_revealed = true
				player.haul.append(idol)
				out.made.append(idol)
				out.message = "The eye comes loose. You lose %d health. The gem is badly cracked." % cost
		"collector_sell":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty():
				return _refuse("choose a stone to sell")
			if DeepStone.is_fragile(stone):
				return _refuse("fragile stones cannot be sold")
			var paid: int = DeepStone.value(stone) * int(action.get("mult", 3))
			player.ore = int(player.get("ore", 0)) + paid
			remove_stone(player, str(stone.id))
			out.lost.append(str(stone.id))
			out.message = "She pays you %d pyrite for it." % paid
		"collector_buy":
			## One stone out of her case, rolled when the room opened so the price on the card
			## is the price that is paid.
			var offer: Dictionary = ctx.get("offer", {})
			if offer.is_empty() or not offer.has("stone"):
				return _refuse("her case is empty")
			var price: int = int(offer.get("price", 0))
			if int(player.get("ore", 0)) < price:
				return _refuse("you have not the pyrite for it")
			player.ore = int(player.ore) - price
			DeepBattle.tally_add(player, "spent", price)
			var bought: Dictionary = (offer.stone as Dictionary).duplicate(true)
			bought.appraised = true
			bought.inclusions_revealed = true
			player.haul.append(bought)
			out.made.append(bought)
			out.bought = true
			out.message = "You buy it for %d pyrite: %s." % [price, DeepStone.name(bought)]
		"appraise":
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			if stone.is_empty() or bool(stone.get("appraised", false)):
				return _refuse("choose a raw stone")
			stone.appraised = true
			stone.inclusions_revealed = true
			out.changed.append(stone.duplicate(true))
			out.message = "Through the loupe, it's a %s." % DeepStone.name(stone)
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
			for other in DeepStone.rail_stones(player):
				if str(other.id) == str(stone.id):
					socketed = true
				else:
					beside.append(str(other.skill))
			var pool: Array = DeepForge.skill_pool(mine).filter(func(k: String) -> bool:
				return str(DeepContent.skill(k).get("color", "")) == color and k != str(stone.skill) and not (socketed and beside.has(k)))
			if pool.is_empty():
				return _refuse("nothing else of that color could come out of the drum")
			var was: String = str(stone.skill)
			stone.skill = DeepForge.roll_skill(rng, mine, pool)
			out.changed.append(stone.duplicate(true))
			if bool(stone.get("appraised", false)):
				## Named going in as well as coming out: "The stone comes out as a Spall" alone
				## never said it had been an Ember, and the change was easy to miss.
				var now: String = str(DeepStone.skill_of(stone).get("name", stone.skill))
				out.message = "%s comes out as %s." % [str(DeepContent.skill(was).get("name", was)), a_or_an(now)]
				out.tumbled = {"from": was, "to": str(stone.skill)}
			else:
				out.message = "The stone's skill has changed. Appraise it to find out what it is now."
		"upsize", "downsize":
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			if die.is_empty():
				return _refuse("choose a die to hammer" if kind == "upsize" else "choose a die to file down")
			var refusal: String = resize(die, 1 if kind == "upsize" else -1)
			if not refusal.is_empty():
				return _refuse(refusal)
			out.dice.append(die.duplicate(true))
			out.message = "Your die is now a %s." % DeepDice.describe(die)
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
			## One chosen face comes up, as far as the chisel is asked to take it: nothing
			## holds it to the die's own highest face, and a face has no ceiling at all.
			## A blank face becomes a number.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var face: int = int(payload.get("face", -1))
			if die.is_empty() or face < 0 or face >= die.get("faces", []).size():
				return _refuse("choose a die and a face to raise")
			var before: int = _shown(die.faces[face])
			var after: int = before + maxi(1, int(action.get("amount", 1)))
			if after <= before:
				return _refuse("that face is already as high as a face is cut")
			var kind_was: String = str(die.faces[face].get("kind", "plain"))
			die.faces[face] = DeepDice.face(after, "plain" if kind_was == "blank" else kind_was)
			out.dice.append(die.duplicate(true))
			out.faces = {str(die.id): face}
			out.message = "The %s is now a %s." % [_face_words(DeepDice.face(before, kind_was)), _face_words(die.faces[face])]
		"lower_face":
			## One chosen face comes down by one, never below a 1. Whatever is etched on it
			## stays on it. A blank face has no number to take down.
			var die: Dictionary = find_die(player, str(payload.get("die_id", "")))
			var face: int = int(payload.get("face", -1))
			if die.is_empty() or face < 0 or face >= die.get("faces", []).size():
				return _refuse("choose a die and a face to lower")
			var kind_was: String = str(die.faces[face].get("kind", "plain"))
			if kind_was == "blank":
				return _refuse("a blank face has no number to lower")
			var before: int = _shown(die.faces[face])
			var after: int = maxi(1, before - maxi(1, int(action.get("amount", 1))))
			if after >= before:
				return _refuse("that face is already a 1")
			die.faces[face] = DeepDice.face(after, kind_was)
			out.dice.append(die.duplicate(true))
			out.faces = {str(die.id): face}
			out.message = "The %s is now a %s." % [_face_words(DeepDice.face(before, kind_was)), _face_words(die.faces[face])]
		"pry":
			var stone: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(action.get("bonus", 4)), {"run": ctx.get("run", ""), "source": "seam"})
			## The big one is never smaller than its `min_size` class, however poor the rock's luck.
			var least: int = DeepStone.size_low(str(action.get("min_size", "")))
			if int(stone.carat) < least:
				stone.carat = least
			player.haul.append(stone)
			out.made.append(stone)
			var cost: int = int(action.get("hp", 8))
			player.hp = maxi(1, int(player.get("hp", 0)) - cost)
			out.message = "It comes loose, but the edge cuts you. You lose %d health." % cost
		"chips":
			for _i in range(maxi(1, int(action.get("count", 2)))):
				var chip: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(action.get("bonus", -2)), {"run": ctx.get("run", ""), "source": "seam"})
				player.haul.append(chip)
				out.made.append(chip)
			out.message = "You pick up the loose stones."
		"heal":
			var gained: int = int(ceil(float(player.get("max_hp", 0)) * float(action.get("pct", 25)) / 100.0))
			player.hp = mini(int(player.get("max_hp", 0)), int(player.get("hp", 0)) + gained)
			out.message = "You recover %d HP." % gained
		"ore":
			## A flat amount, or one that grows with the depth: what is left lying about down
			## here is worth more the further it is from anywhere that would sell it.
			var taken: int = ore_amount(action, depth)
			player.ore = int(player.get("ore", 0)) + taken
			out.message = "You take %d pyrite." % taken
		"wishing_well":
			## The well takes and gives, and all it counts is what went down it. A stone is
			## weighed at its worth — halved while it is still in its rock, half again once it
			## has been read — and pyrite at its face. That one number picks a rung on the
			## ladder of what can come back up, from nothing at all to a stone cut perfect.
			var thrown: float = 0.0
			var said: String = ""
			var spent: int = 0
			if str(action.get("mode", "stone")) == "ore":
				var least: int = int(action.get("least", 10))
				spent = clampi(int(payload.get("ore", 0)), least, int(action.get("most", 1000)))
				if int(player.get("ore", 0)) < spent:
					return _refuse("you have not the pyrite to throw in")
				player.ore = int(player.ore) - spent
				DeepBattle.tally_add(player, "spent", spent)
				thrown = float(spent) * float(ctx.get("well_mult", 1.0))
				said = "%d pyrite goes down into the dark." % spent
			else:
				var offered: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
				if offered.is_empty():
					return _refuse("choose one of your stones")
				if DeepStone.is_locked(offered):
					return _refuse("a Knot cannot leave its socket")
				if DeepStone.is_fragile(offered):
					return _refuse("the well will not take a fragile stone")
				thrown = well_worth(offered, float(action.get("raw_mult", 0.5)), float(action.get("read_mult", 1.5))) * float(ctx.get("well_mult", 1.0))
				said = "%s goes down into the water." % (DeepStone.name(offered) if bool(offered.get("appraised", false)) else DeepStone.raw_name(offered))
				remove_stone(player, str(offered.id))
				out.lost.append(str(offered.id))
			var rung: int = well_rung(rng, thrown)
			var prize: Dictionary = well_prize(rng, rung, player, mine, depth, str(ctx.get("run", "")))
			out.made.append_array(prize.get("made", []))
			out.well = well_summary(rung, thrown, prize, spent)
			out.message = "%s %s" % [said, str(prize.get("message", ""))]
		"hollow":
			## A die goes down the hole and a gem comes away Void, both until the run ends.
			## The die is one of the five thrown, never one carried in the bag. A gem set in
			## a socket steps off it and rides it instead, first in line, so it fires where
			## it always did and the socket is free for another. A gem from the bag goes
			## straight onto the rail: it rides the first socket with a gem set in it.
			var stone: Dictionary = find_stone(player, str(payload.get("stone_id", "")))
			var refusal: String = hollow_refusal(stone, player)
			if not refusal.is_empty():
				return _refuse(refusal)
			var dice: Array = player.get("dice", [])
			var at: int = -1
			for index in range(dice.size()):
				if str(dice[index].get("id", "")) == str(payload.get("die_id", "")):
					at = index
			if at < 0:
				return _refuse("choose one of your dice")
			var least: int = hollow_least(action)
			if dice.size() <= least:
				return _refuse("the Hollow will not leave you fewer than %d dice" % least)
			var fed: Dictionary = dice[at]
			dice.remove_at(at)
			var from_socket: int = -1
			var rail: Array = player.get("rail", [])
			for index in range(rail.size()):
				if rail[index] is Dictionary and str(rail[index].get("id", "")) == str(stone.id):
					from_socket = index
			var bagged: bool = DeepStone.rider_place(player, str(stone.id)).is_empty() and from_socket < 0
			stone.voided = true
			DeepStone.normalize_rail(player)
			if bagged:
				var host: int = hollow_host(player, stone)
				if host >= 0:
					remove_stone(player, str(stone.id))
					DeepStone.normalize_rail(player)
					player.riders[host].append(stone)
			out.changed.append(stone.duplicate(true))
			out.dice_lost = [fed.duplicate(true)]
			## Where everything went, so a screen can show the die going in and the gem coming
			## out onto the rail.
			out.voided = {"stone_id": str(stone.id), "die_index": at, "from_socket": from_socket, "rides": DeepStone.rider_place(player, str(stone.id))}
			out.message = "The Hollow takes a die (%s). %s comes away Void: it takes no socket until the run ends." % [
				DeepDice.describe(fed), str(DeepStone.skill_of(stone).get("name", stone.get("skill", "")))]
		_:
			return _refuse("unknown oddity action")
	return out

# --- what a room lays out before anyone chooses ---------------------------------------------
##
## Most oddities resolve entirely inside `apply()`. Two do not: the Collector has to have
## rolled the stone in her case before the card can name its price, and the Idol has to
## remember, per player, how many pulls are left in it. Both live on the chamber.

static func offer_for(def: Dictionary, rng: RandomNumberGenerator, mine: Dictionary, depth: int, run: String) -> Dictionary:
	## What this card has to have to hand before anybody chooses, or {} for a card that needs
	## nothing. Rolled once, when the room opens, so every player sees the same case.
	for choice in def.get("choices", []):
		var action: Dictionary = choice.get("action", {})
		var kind: String = str(action.get("kind", ""))
		if kind in ["pattern", "etch", "material"] and not bool(action.get("random", false)):
			## What the anvil, the needles and the vat are set for tonight. Rolled once, when
			## the room opens, so every player is offered the same thing.
			match kind:
				"pattern":
					return {"pattern": DeepForge.roll_pattern(rng, "D12")}
				"etch":
					return {"etching": DeepForge.roll_etching(rng)}
				"material":
					return {"material": DeepForge.roll_material(rng)}
		if kind == "geode_buy":
			var found: Dictionary = DeepEconomy.roll_run_geode(rng, str(mine.get("key", "")), {"run": run}, "ge%08x" % rng.randi())
			return {"stone": found, "price": DeepEconomy.run_geode_price(found.geode)}
		if kind != "collector_buy":
			continue
		var stone: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(action.get("bonus", 4)),
			{"run": run, "source": "collector"})
		stone.appraised = true
		stone.inclusions_revealed = true
		return {"stone": stone, "price": maxi(1, int(round(float(DeepStone.value(stone)) * float(action.get("price_mult", 2)))))}
	return {}

static func ore_amount(action: Dictionary, depth: int) -> int:
	## A flat `amount`, or a `base` that grows by `per_depth` for every depth reached.
	if action.has("base") or action.has("per_depth"):
		return maxi(0, int(action.get("base", 0)) + int(action.get("per_depth", 1)) * maxi(0, depth))
	return int(action.get("amount", 5))

static func choice_text(choice: Dictionary, depth: int) -> String:
	## A card's words as they stand at this depth: an amount that grows the deeper the party
	## is ("{ore}") is written as the number it comes to here, never as its sum.
	var text: String = str(choice.get("text", ""))
	if text.contains("{ore}"):
		text = text.replace("{ore}", str(ore_amount(choice.get("action", {}), depth)))
	return text

# --- the crucible -------------------------------------------------------------------------------

static func fuse_cost() -> int:
	## What fusing a twin into the stone it matches costs (DeepDescent._twin). The Crucible
	## room itself is free: its price is the coin flip on which stone survives.
	return int(DeepContent.constant("fuse_ore_cost", 100))

static func fuse_gain(rng: RandomNumberGenerator, heavy: int, light: int) -> int:
	## What the fire adds to the heavier stone's weight: nothing, one carat or two, by how
	## close the lighter stone comes to it. With r the lighter over the heavier, two carats
	## with chance r^4 / 2 and one with chance r^2 in all, so a stone half the weight of the
	## other gives one carat a quarter of the time and two one time in thirty-two, and two
	## equals give one or two every time, half and half. Nothing else grows carat here
	## (October 29, 2026; it used to carry a random share of the lighter stone).
	if heavy <= 0 or light <= 0:
		return 0
	var ratio: float = clampf(float(light) / float(heavy), 0.0, 1.0)
	var draw: float = rng.randf()
	if draw < 0.5 * pow(ratio, 4.0):
		return 2
	if draw < ratio * ratio:
		return 1
	return 0

static func fuse_stats(rng: RandomNumberGenerator, keep: Dictionary, feed: Dictionary, mine: Dictionary, _carry_pct: float = 0.0) -> Dictionary:
	## What comes out of the fire, as fields to write over `keep`, the stone the fire already
	## chose to survive: its skill comes through. The heavier of the two sets the weight and
	## grows by `fuse_gain`: a carat or two, likelier the nearer the lighter stone comes to it;
	## the Cut is the average of the pair, rounded down, so a Perfect is only ever found;
	## the Clarity is drawn fresh between Included and Intricate, which is the only range the
	## crucible ever gives back. Two colors in and the one whose skill lost is frozen in as a
	## Zoning, so a fused stone always says what it was made of. Opal counts as no color at all.
	var heavy: int = maxi(int(keep.get("carat", 1)), int(feed.get("carat", 1)))
	var light: int = mini(int(keep.get("carat", 1)), int(feed.get("carat", 1)))
	var carried: int = fuse_gain(rng, heavy, light)
	var skill: String = str(keep.get("skill", ""))
	var lost: Dictionary = feed
	var cut: int = int(floor(float(int(keep.get("cut", 0)) + int(feed.get("cut", 0))) / 2.0))
	var top: int = DeepContent.clarity_index("INCLUDED")
	var bottom: int = DeepContent.clarity_index("INTRICATE")
	var clarity: int = rng.randi_range(mini(bottom, top), maxi(bottom, top))
	var out: Dictionary = {
		"skill": skill,
		"carat": clampi(heavy + carried, 1, DeepStone.carat_max()),
		"cut": clampi(cut, 0, DeepPatterns.STEPS - 1),
		"clarity": clarity,
		"appraised": true,
		"inclusions_revealed": true,
	}
	var color: String = str(DeepContent.skill(skill).get("color", ""))
	var other: String = str(DeepContent.skill(str(lost.get("skill", ""))).get("color", ""))
	var zoning: String = ""
	if not other.is_empty() and other != color and other != DeepContent.OPAL and color != DeepContent.OPAL:
		zoning = zoning_key(other)
	var slots: int = DeepStone.inclusion_slots(clarity)
	var inside: Array = []
	if not zoning.is_empty():
		inside.append(zoning)
	for key in DeepForge.roll_inclusions(rng, maxi(0, slots - inside.size()), mine, "", color):
		if not inside.has(str(key)) and inside.size() < slots:
			inside.append(str(key))
	out.inclusions = inside
	return out

static func zoning_key(color: String) -> String:
	## The inclusion that makes a stone count as `color` as well as its own, or "".
	var keys: Array = DeepContent.section("inclusions").keys()
	keys.sort()
	for key in keys:
		if DeepForge.zoning_color(DeepContent.inclusion(str(key))) == color:
			return str(key)
	return ""

# --- the wishing well ----------------------------------------------------------------------------
##
## Everything that goes down the well is weighed into one number of pyrite, and that number
## picks a rung on this ladder. The ladder runs worst to best and never changes; what changes
## is where on it the draw lands. Even a pittance thrown in nearly always brings something
## back, a little more than it cost; a thousand pyrite's worth puts the top of it within easy
## reach. `tier` is how loud the result is, 0 to 4, for the sparks and the noise the screen
## makes of it. A rung's `name` is the ladder's own label, never the result's headline: "A good
## stone" over a tiny one, or "A hundred pyrite" after a throw of 157, said what the rung was
## meant to be rather than what came back (the screen judges it, see well_headline).

const WELL_MOST: float = 1000.0
## Where the smallest offering's bell is centred (rung 1.6, past a single pyrite), and how
## quickly it climbs from there: an offering's share of the most is raised to this power.
const WELL_FLOOR: float = 1.6
const WELL_CLIMB: float = 0.6
const WELL_PRIZES: Array = [
	{"kind": "none", "tier": 0, "name": "Nothing"},
	{"kind": "ore", "amount": 1, "tier": 0, "name": "A single pyrite"},
	{"kind": "raw", "bonus": -4, "tier": 1, "name": "A lesser stone"},
	{"kind": "ore", "amount": 50, "tier": 1, "name": "Fifty pyrite"},
	{"kind": "gem", "bonus": -3, "tier": 1, "name": "A lesser gem"},
	{"kind": "raw", "bonus": 0, "tier": 2, "name": "A fair stone"},
	{"kind": "ore", "amount": 100, "tier": 2, "name": "A hundred pyrite"},
	{"kind": "heal", "tier": 2, "name": "A full heal"},
	{"kind": "gem", "bonus": 1, "tier": 2, "name": "A fair gem"},
	{"kind": "raw", "bonus": 3, "tier": 2, "name": "A good stone"},
	{"kind": "gem", "bonus": 4, "tier": 3, "name": "A good gem"},
	{"kind": "ore", "amount": 250, "tier": 3, "name": "Two hundred and fifty pyrite"},
	{"kind": "raw", "bonus": 7, "tier": 3, "name": "A great stone"},
	{"kind": "raw", "bonus": 0, "opal": true, "tier": 3, "name": "An opal in its rock"},
	{"kind": "gem", "bonus": 8, "tier": 4, "name": "A great gem"},
	{"kind": "raw", "bonus": 4, "opal": true, "tier": 4, "name": "A good opal in its rock"},
	{"kind": "raw", "bonus": 10, "tier": 4, "name": "An exceptional stone"},
	{"kind": "perfect", "bonus": 0, "tier": 4, "name": "A perfect gem"},
	{"kind": "raw", "bonus": 8, "opal": true, "tier": 4, "name": "A great opal in its rock"},
]

static func well_worth(stone: Dictionary, raw_mult: float, read_mult: float) -> float:
	## What the well reckons a stone at: its worth, halved while it is still in its rock and
	## half again once somebody has read it. Reading a stone before you drop it in is worth
	## three times as much to the well as dropping it rough.
	return float(DeepStone.value(stone)) * (read_mult if bool(stone.get("appraised", false)) else raw_mult)

static func well_rung(rng: RandomNumberGenerator, worth: float) -> int:
	## Which rung of the ladder a draw of this size lands on. The draw is a bell centred where
	## the offering puts it and as wide as the offering is generous. The bell never sits on
	## "Nothing" (a pittance centres between a poor stone and fifty pyrite, and lands on
	## Nothing about once in a hundred), and it climbs fastest for the first coins thrown in,
	## so a modest offering is a real chance; a thousand is a broad reach across the top.
	var share: float = pow(clampf(worth / WELL_MOST, 0.0, 1.0), WELL_CLIMB)
	var top: float = float(WELL_PRIZES.size() - 1)
	var centre: float = WELL_FLOOR + (top - WELL_FLOOR) * share
	var spread: float = 0.8 + 3.2 * share
	var weights: Array = []
	for index in range(WELL_PRIZES.size()):
		var off: float = float(index) - centre
		weights.append(exp(-(off * off) / (2.0 * spread * spread)))
	return maxi(0, DeepRng.weighted_index(rng, weights))

static func well_prize(rng: RandomNumberGenerator, rung: int, player: Dictionary, mine: Dictionary, depth: int, run: String) -> Dictionary:
	## The rung made real: pyrite into the purse, a stone into the haul, or every wound
	## closed. Returns {made: [stones], tier, name, message}.
	var entry: Dictionary = WELL_PRIZES[clampi(rung, 0, WELL_PRIZES.size() - 1)]
	var out: Dictionary = {"made": [], "tier": int(entry.get("tier", 0)), "name": str(entry.get("name", "")), "message": "",
		"kind": str(entry.get("kind", "none")), "ore": 0, "healed": 0}
	var where: Dictionary = {"run": run, "source": "well"}
	match str(entry.get("kind", "none")):
		"none":
			out.message = "Nothing comes back up."
		"ore":
			var amount: int = int(entry.get("amount", 1))
			player.ore = int(player.get("ore", 0)) + amount
			out.ore = amount
			out.message = "%d pyrite comes back up." % amount if amount > 1 else "One pyrite comes back up."
		"heal":
			## The water that comes back up is warm, and every wound it touches closes.
			var healed: int = maxi(0, int(player.get("max_hp", 0)) - int(player.get("hp", 0)))
			player.hp = maxi(int(player.get("hp", 0)), int(player.get("max_hp", 0)))
			out.healed = healed
			out.message = "Warm water wells up and every wound closes: %d HP back." % healed if healed > 0 else "Warm water wells up, but you have no wounds for it to close."
		"raw":
			var pool: Array = DeepForge.opal_pool() if bool(entry.get("opal", false)) else []
			var stone: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(entry.get("bonus", 0)), where, "", pool)
			stone.appraised = false
			stone.inclusions_revealed = false
			player.haul.append(stone)
			out.made.append(stone)
			out.message = "Something comes back up: %s, still in its rock." % DeepStone.raw_name(stone).to_lower()
		"gem":
			var read: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(entry.get("bonus", 0)), where)
			read.appraised = true
			read.inclusions_revealed = true
			player.haul.append(read)
			out.made.append(read)
			out.message = "Something comes back up, already appraised: %s." % DeepStone.name(read)
		"perfect":
			## Everything about it is drawn the way the rock draws it, and then it is cut
			## perfect and left flawless. There is nothing better the well can do.
			var made: Dictionary = DeepForge.roll_stone(rng, mine, depth, int(entry.get("bonus", 0)), where)
			made.cut = DeepPatterns.STEPS - 1
			var flawless: int = DeepContent.clarity_index("FLAWLESS")
			made.clarity = flawless if flawless >= 0 else int(made.clarity)
			made.inclusions = []
			made.appraised = true
			made.inclusions_revealed = true
			player.haul.append(made)
			out.made.append(made)
			out.message = "A flawless gem comes back up: %s." % DeepStone.name(made)
	return out

static func well_summary(rung: int, worth: float, prize: Dictionary, spent: int = 0) -> Dictionary:
	## What the screen needs to make a noise about a draw: the rung, what went down, and
	## what came back up in pyrite or health as well as in words. `spent` is the pyrite thrown
	## in, 0 when a stone went down instead.
	return {"rung": rung, "worth": int(round(worth)), "tier": int(prize.get("tier", 0)), "name": str(prize.get("name", "")),
		"kind": str(prize.get("kind", "none")), "ore": int(prize.get("ore", 0)), "healed": int(prize.get("healed", 0)), "spent": maxi(0, spent)}

static func well_headline(well: Dictionary, made: Array = []) -> String:
	## The well's answer in a few words, judged against what went down it rather than read off
	## the rung: pyrite back is less or more than the pyrite thrown (or than the well counted a
	## stone at), a stone is named by its real size and grade, and warm water over no wounds
	## says so.
	var spent: int = int(well.get("spent", 0))
	match str(well.get("kind", "none")):
		"none":
			return "Nothing"
		"ore":
			var back: int = int(well.get("ore", 0))
			var thrown: String = "you threw" if spent > 0 else "it was worth"
			if well_short(well):
				return "Less than %s" % thrown
			if back > _well_stake(well):
				return "More than %s" % thrown
			return "Your pyrite back" if spent > 0 else "Its worth in pyrite"
		"heal":
			return "Every wound closed" if int(well.get("healed", 0)) > 0 else "Warm water, and no wounds"
		"raw", "gem", "perfect":
			for stone in made:
				if stone is Dictionary:
					return found_words(stone)
	return str(well.get("name", "The well answers"))

static func well_short(well: Dictionary) -> bool:
	## Whether the pyrite that came back up is less than what went down: a loss, said quietly
	## whatever rung it landed on.
	return str(well.get("kind", "")) == "ore" and int(well.get("ore", 0)) < _well_stake(well)

static func _well_stake(well: Dictionary) -> int:
	## The pyrite thrown in, or what the well counted a stone at.
	var spent: int = int(well.get("spent", 0))
	return spent if spent > 0 else int(well.get("worth", 0))

static func found_words(stone: Dictionary) -> String:
	## A stone named by what it really is: "A tiny blue stone" still in its rock, "A small
	## Spall" once read, its grade said only from Precious up ("A large Exquisite Barrage"):
	## Rough reads as still in its rock and Fine as plain praise, so neither is said here.
	var words: String = DeepStone.raw_name(stone).to_lower()
	if bool(stone.get("appraised", false)):
		var size: String = str(DeepStone.SIZE_CLASSES[int(DeepStone.size_class(int(stone.get("carat", 1))).index)].name).to_lower()
		var grade: Dictionary = DeepStone.grade(stone)
		var graded: String = (str(grade.name) + " ") if int(grade.get("index", 0)) >= DeepStone.TIERS.find("PRECIOUS") else ""
		words = "%s %s%s" % [size, graded, str(DeepStone.skill_of(stone).get("name", stone.get("skill", "stone")))]
	words = a_or_an(words)
	return words.left(1).to_upper() + words.substr(1)

static func a_or_an(words: String) -> String:
	## "a Spall", "an Ember".
	return ("an " if not words.is_empty() and "aeiou".contains(words.left(1).to_lower()) else "a ") + words

static func _clarity_verdict(was: int, now: int) -> Dictionary:
	## Which way a clarity moved, judged by how far off Clear it ended: both ends of the
	## ladder are good, so a stone that went from Clear to Etched has improved.
	var clear: int = DeepContent.clear_index()
	return {"field": "clarity", "was": was, "now": now, "better": signi(absi(now - clear) - absi(was - clear))}

static func _shown(f: Dictionary) -> int:
	## What a face counts for when looking for the lowest: a blank shows nothing.
	return 0 if str(f.get("kind", "plain")) == "blank" else int(f.get("value", 0))

static func _face_words(f: Dictionary) -> String:
	## "4", "wild 6", "blank": a face the way a result names it.
	var kind: String = str(f.get("kind", "plain"))
	if kind == "blank":
		return "blank"
	return str(int(f.get("value", 0))) if kind == "plain" else "%s %d" % [kind, int(f.get("value", 0))]

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "message": "", "made": [], "lost": [], "changed": [], "dice": []}
