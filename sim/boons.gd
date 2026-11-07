class_name DeepBoons
extends RefCounted
## The Grubstake: what the workshop stakes a lapidary before the lift goes down.
##
## At the shaft head every player is offered three stakes and takes one. The offer is
## built from the `boons` section of the pack:
##
##   a stone stake      something for the stones in the rail or the haul
##   a kit stake        health, ore, one of your dice worked, softer rock
##   terms              one cost and one bigger reward, drawn together; costs and rewards
##                      list what they will not pair with
##
## A player whose last run fell before the first landing, or fell in a mine whose first Warden
## they have never beaten, is shown mercy: their kit stake is drawn from the stakes tagged for
## it, and the card says why. Everything a stake changes is for this run only: the
## rail's stones and the five dice are copies of the vault's and the bowl's, and only the
## haul comes home. No stake hands out a die: dice are only ever worked, never added.
##
## A boon is written as effects with a small vocabulary of their own (they act on the run,
## not on a hand), and says what it `needs`: a socket in the rail, which is drawn at random
## from the stones set there when the stake is taken, or a pick from candidates rolled when
## the offer is made, which the player chooses between once they have taken the stake. A
## pick's candidates are raw stones, one of each of as many colors, so the choice is a
## color and a size; the one taken is read under the loupe on the spot.
##
## A deep start (November 2026, docs/DEEP_START.md): a party that sets out in a mine below
## the first has skipped `k` mines (`DeepDescent.mines_skipped`, read off the content's mine
## order). Its three cards come from a deeper hand (`deep_offer`): two cards of the `deep`
## group and one of the Quarry's own stakes, made better for every mine skipped
## (`upgraded_effect`), its words filled with the numbers they come to (`stake_text`). That
## stake is a stone or kit stake or a reward taken alone, with no cost; never one marked
## `shallow_only` (Steady Hands, Soft Rock). A deep card says what it holds on the offer
## itself: the stones in its pouch, the dice in its bag, the materials, how many carats, how
## much pyrite, how many vouchers.
##
## Hammered and A Wild Face are charges (November 2026): the player chooses the die each one
## lands on, in click order, the same die as often as it will take one (`charges` on the
## offer, `can_charge`, `charge_preview`).

const GROUPS: Array = ["stone", "kit", "cost", "reward", "deep"]
## `picks`: several of the offer's candidates taken at once (a Bag of Gems); `swaps`: any of
## the offer's dice swapped for the player's own (a Bag of Dice); `charges`: dice the player
## chooses, one a charge (Hammered, A Wild Face).
const NEEDS: Array = ["", "socket", "pick", "picks", "swaps", "charges"]
## What a charge does to the die it lands on: `resize` one size bigger, `wild` its lowest face
## that is not wild yet turned wild.
const CHARGE_KINDS: Dictionary = {"resize_die": "resize", "wild_face": "wild"}
const EFFECT_KINDS: Array = ["cut_step", "carat", "reroll_cut", "reroll_clarity", "inclusion", "rail_all", "raw_stone", "pick_stone", "resize_die",
	"wild_face", "max_hp_pct", "hp_pct", "ore", "soft_rock", "extra_rerolls",
	"gem_pouch", "dice_bag", "one_material", "heirloom", "deep_purse", "vouchers"]
## The effects only a deep card carries.
const DEEP_KINDS: Array = ["gem_pouch", "dice_bag", "one_material", "heirloom", "deep_purse", "vouchers"]
## How many times a deep card's stone or material is drawn again when it comes out unfit
## (fragile, or a material already taken).
const DEEP_TRIES: int = 8
const OFFER_KINDS: Array = ["stone", "kit", "terms"]
const PICK_TRIES: int = 12

# --- validation ------------------------------------------------------------------------------

static func validate(def: Variant, p: Dictionary) -> Array:
	if not def is Dictionary:
		return ["must be an object"]
	var errors: Array = []
	if str(def.get("name", "")).is_empty():
		errors.append("needs a name")
	if not str(def.get("group", "")) in GROUPS:
		errors.append("unknown group " + str(def.get("group", "")))
	if not str(def.get("needs", "")) in NEEDS:
		errors.append("unknown needs " + str(def.get("needs", "")))
	if def.has("weight") and (not (def.weight is int or def.weight is float) or float(def.weight) <= 0.0):
		errors.append("weight must be positive")
	if def.has("shallow_only") and not def.shallow_only is bool:
		errors.append("shallow_only is true or false")
	for other in def.get("not_with", []):
		if not p.get("boons", {}).has(str(other)):
			errors.append("not_with names an unknown boon " + str(other))
	var effects: Variant = def.get("effects", null)
	if not effects is Array or effects.is_empty():
		errors.append("needs at least one effect")
		return errors
	for index in range(effects.size()):
		var effect: Variant = effects[index]
		var where: String = "effect %d" % (index + 1)
		if not effect is Dictionary:
			errors.append(where + ": must be an object")
			continue
		var kind: String = str(effect.get("kind", ""))
		if not kind in EFFECT_KINDS:
			errors.append(where + ": unknown kind " + kind)
			continue
		match kind:
			"cut_step", "carat", "max_hp_pct", "hp_pct", "ore":
				if not (effect.get("amount", null) is int or effect.get("amount", null) is float):
					errors.append(where + ": needs an amount")
			"inclusion":
				if not str(effect.get("class", "")) in DeepContent.INCLUSION_CLASSES:
					errors.append(where + ": unknown inclusion class " + str(effect.get("class", "")))
			"pick_stone":
				if int(effect.get("count", 0)) < 1:
					errors.append(where + ": needs a count")
				if str(def.get("needs", "")) != "pick":
					errors.append(where + ": a pick needs the player to pick")
				if effect.has("min_tier") and not str(effect.min_tier) in DeepStone.TIERS:
					errors.append(where + ": unknown tier " + str(effect.min_tier))
			"resize_die":
				if int(effect.get("amount", 0)) != 1:
					errors.append(where + ": a size upgrade is one size bigger")
			"soft_rock":
				if int(effect.get("fights", 0)) < 1:
					errors.append(where + ": needs fights")
			"extra_rerolls":
				if int(effect.get("amount", 0)) < 1 or int(effect.get("until_depth", 0)) < 1:
					errors.append(where + ": needs an amount and until_depth")
			"rail_all":
				if int(effect.get("carat", 0)) == 0 and int(effect.get("cut", 0)) == 0 and int(effect.get("clarity", 0)) == 0:
					errors.append(where + ": needs a carat, cut or clarity step")
			"gem_pouch":
				if int(effect.get("offered", 0)) < 1 or int(effect.get("take", 0)) < 1:
					errors.append(where + ": needs offered and take")
				if str(def.get("needs", "")) != "picks":
					errors.append(where + ": a pouch needs the player to pick")
			"dice_bag":
				if int(effect.get("count", -1)) < 0:
					errors.append(where + ": needs a count")
				if str(def.get("needs", "")) != "swaps":
					errors.append(where + ": a bag of dice needs the player's swaps")
			"one_material":
				if int(effect.get("count", 0)) < 2:
					errors.append(where + ": needs at least two materials to choose from")
				if str(def.get("needs", "")) != "pick":
					errors.append(where + ": a material needs the player to pick")
			"deep_purse":
				if int(effect.get("ore_per_mine", -1)) < 0 or int(effect.get("raw", -1)) < 0:
					errors.append(where + ": needs ore_per_mine and raw")
			"vouchers":
				if int(effect.get("per_mine", 0)) < 1:
					errors.append(where + ": needs per_mine")
		if kind in CHARGE_KINDS and str(def.get("needs", "")) != "charges":
			errors.append(where + ": " + kind + " lands on dice the player chooses, so the boon needs charges")
		if kind in DEEP_KINDS and str(def.get("group", "")) != "deep":
			errors.append(where + ": " + kind + " is a deep start's card")
		if kind in ["cut_step", "carat", "inclusion"] and str(def.get("needs", "")) != "socket":
			errors.append(where + ": acts on a socket, so the boon needs one")
		if kind == "rail_all" and str(def.get("needs", "")) == "socket":
			errors.append(where + ": acts on the whole rail, so it wants no socket")
	return errors

# --- standing ----------------------------------------------------------------------------------

static func standing(unit: Dictionary) -> Dictionary:
	## What a player's last run earns them here. `last_depth`, `last_outcome` and
	## `last_warden_unbeaten` travel in the player's config from their profile (see
	## `warden_unbeaten`). Most new lapidaries fall at the first Warden, well past the first
	## landing, so a fall anywhere short of beating that Warden once is shown mercy too.
	var last_depth: int = int(unit.get("last_depth", 0))
	var last_outcome: String = str(unit.get("last_outcome", ""))
	var early: bool = last_depth < DeepDescent.landing_every() or bool(unit.get("last_warden_unbeaten", false))
	return {"mercy": last_outcome == "fallen" and early}

static func warden_unbeaten(profile: Dictionary, last: Dictionary) -> bool:
	## Whether the mine a run (`last`, an entry of the profile's history) ended in still has
	## its first Warden standing for this profile: no Warden and no boss of it ever beaten, on
	## the run's own Hazard tier or the plain map. Read only; a missing record is unbeaten.
	var mine_key: String = str(last.get("mine", ""))
	if mine_key.is_empty() or DeepContent.mine(mine_key).is_empty():
		return false
	var books: Array = [profile.get("mines", {})]
	var tier: int = int(last.get("hazard", 0))
	if tier > 0:
		books.append(profile.get("hazard", {}).get("tiers", {}).get(str(tier), {}).get("mines", {}))
	for book in books:
		var record: Variant = book.get(mine_key, {}) if book is Dictionary else {}
		if record is Dictionary and (not record.get("wardens", []).is_empty() or bool(record.get("boss", false))):
			return false
	return true

# --- the offer -----------------------------------------------------------------------------------

static func pool(group: String, tag: String = "") -> Array:
	var keys: Array = []
	for key in DeepContent.section("boons"):
		var def: Dictionary = DeepContent.boon(str(key))
		if str(def.get("group", "")) != group:
			continue
		if not tag.is_empty() and not def.get("tags", []).has(tag):
			continue
		keys.append(str(key))
	keys.sort()
	return keys

static func _draw(rng: RandomNumberGenerator, keys: Array) -> String:
	if keys.is_empty():
		return ""
	var table: Dictionary = {}
	for key in keys:
		table[str(key)] = float(DeepContent.boon(str(key)).get("weight", 3))
	return DeepRng.weighted_key(rng, table)

static func _pairs(cost: String, reward: String) -> bool:
	return not DeepContent.boon(cost).get("not_with", []).has(reward) and not DeepContent.boon(reward).get("not_with", []).has(cost)

static func works_bare(key: String) -> bool:
	## Whether a boon does anything for a lapidary with no stone set: not one that lands on a
	## rail stone (needs a socket) nor one on every rail stone (rail_all).
	var def: Dictionary = DeepContent.boon(key)
	if str(def.get("needs", "")) == "socket":
		return false
	for effect in def.get("effects", []):
		if str(effect.get("kind", "")) in ["rail_all", "heirloom"]:
			return false
	return true

static func offer(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator) -> Array:
	## The three stakes one player is shown: stone, kit and terms. A party that sets out below
	## the first mine is shown the deeper hand instead (`deep_offer`).
	var k: int = int(state.get("deep_start", 0))
	if k > 0:
		return deep_offer(state, unit, rng, k)
	var offers: Array = _stakes(state, unit, rng, ["stone", "kit", "terms"], 0)
	_number(offers)
	return offers

static func _usable(unit: Dictionary) -> Callable:
	## A rail with nothing set on it and nothing coming to it (a Sealed Tray, a Big Haul or
	## Bare Hands day, a deep start brought empty) is never offered a stake that only works on
	## set stones. Temporary offers (a Draft day) fill the rail before the stake is taken. Any
	## other rail draws from the whole pools, so its offers are the same as they always were.
	var bare: bool = unit.get("temps", []).is_empty() and not unit.get("rail", []).any(func(s: Variant) -> bool: return s is Dictionary)
	return func(k: String) -> bool: return not bare or works_bare(k)

static func _number(offers: Array) -> void:
	var index: int = 0
	for entry in offers:
		entry.id = "stake%d" % index
		index += 1

static func _stakes(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator, kinds: Array, k: int) -> Array:
	## The Quarry's stakes of these kinds, in the order stone, kit, terms, each drawn as the
	## Quarry draws it. `k` above nought makes every one better for each mine skipped.
	var offers: Array = []
	var stand: Dictionary = standing(unit)
	var usable: Callable = _usable(unit)
	if kinds.has("stone"):
		var stone_key: String = _draw(rng, pool("stone").filter(usable))
		if not stone_key.is_empty():
			offers.append(_make_offer(state, unit, "stone", [stone_key], rng, k))
	if kinds.has("kit"):
		var kit_pool: Array = pool("kit", "mercy") if bool(stand.mercy) else pool("kit")
		if kit_pool.is_empty():
			kit_pool = pool("kit")
		var kit_key: String = _draw(rng, kit_pool)
		if not kit_key.is_empty():
			var kit: Dictionary = _make_offer(state, unit, "kit", [kit_key], rng, k)
			## Marked, so the card can say the workshop is going easy on them and why.
			if bool(stand.mercy) and DeepContent.boon(kit_key).get("tags", []).has("mercy"):
				kit.mercy = true
			offers.append(kit)
	if kinds.has("terms"):
		var cost: String = _draw(rng, pool("cost").filter(usable))
		if not cost.is_empty():
			var rewards: Array = pool("reward").filter(func(key: String) -> bool: return _pairs(cost, key) and usable.call(key))
			var reward: String = _draw(rng, rewards)
			if not reward.is_empty():
				offers.append(_make_offer(state, unit, "terms", [cost, reward], rng, k))
	return offers

## How many cards of the deep group a deep start shows, whatever its depth; the third is
## one of the Quarry's stakes made better.
const DEEP_CARDS: int = 2

static func deep_offer(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator, k: int) -> Array:
	## A deep start's three cards (November 2026): two drawn from the deep cards, never the same
	## one twice, then one of the Quarry's stakes made better for the `k` mines skipped
	## (`stronger_pool`). Every depth shows the same shape.
	var offers: Array = []
	var usable: Callable = _usable(unit)
	var deep_pool: Array = pool("deep").filter(usable)
	for _i in range(DEEP_CARDS):
		var key: String = _draw(rng, deep_pool)
		if key.is_empty():
			break
		deep_pool.erase(key)
		offers.append(_make_deep_offer(state, unit, key, rng, k))
	var stronger: String = _draw(rng, stronger_pool(unit))
	if not stronger.is_empty():
		var group: String = str(DeepContent.boon(stronger).get("group", "kit"))
		var made: Dictionary = _make_offer(state, unit, group, [stronger], rng, k)
		if group == "kit" and bool(standing(unit).mercy) and DeepContent.boon(stronger).get("tags", []).has("mercy"):
			made.mercy = true
		offers.append(made)
	_number(offers)
	return offers

static func stronger_pool(unit: Dictionary) -> Array:
	## What a deep start's better stake is drawn from, by weight in one draw: every stone stake,
	## every kit stake (from those tagged for mercy, for a player shown mercy) and every reward,
	## taken alone, with no cost beside it. Never one `shallow_only` (Steady Hands, Soft Rock:
	## a start below the first landing has no use for them), nor a stake that only works on set
	## stones for a rail with none.
	var usable: Callable = _usable(unit)
	var kit: Array = pool("kit", "mercy") if bool(standing(unit).mercy) else pool("kit")
	var deep_fit: Callable = func(key: String) -> bool: return not bool(DeepContent.boon(key).get("shallow_only", false)) and usable.call(key)
	if kit.filter(deep_fit).is_empty():
		kit = pool("kit")
	var out: Array = pool("stone") + kit + pool("reward")
	return out.filter(deep_fit)

static func _make_offer(state: Dictionary, unit: Dictionary, kind: String, keys: Array, rng: RandomNumberGenerator, k: int = 0) -> Dictionary:
	var out: Dictionary = {"id": "", "kind": kind, "boons": keys.duplicate(), "needs": [], "picks": [], "pick_kind": ""}
	var mine: Dictionary = DeepDescent.mine_of(state)
	for key in keys:
		var def: Dictionary = DeepContent.boon(str(key))
		var needs: String = str(def.get("needs", ""))
		if not needs.is_empty() and not out.needs.has(needs):
			out.needs.append(needs)
		for effect in effects_of(str(key), k):
			## Hammered, A Wild Face: so many charges, each on a die the player chooses.
			if CHARGE_KINDS.has(str(effect.get("kind", ""))):
				out.charges = {"kind": str(CHARGE_KINDS[str(effect.kind)]), "count": maxi(1, int(effect.get("count", 1)))}
			match str(effect.get("kind", "")):
				"pick_stone":
					out.pick_kind = "stone"
					## One raw stone of each color drawn, so the three are a choice of color
					## and size rather than three readings of the same table.
					var colors: Array = _pick_colors(rng, mine, int(effect.get("count", 3)))
					for color in colors:
						out.picks.append(_raw_pick(rng, mine, str(color), int(effect.get("depth", 4)), int(effect.get("bonus", 0)), str(effect.get("min_tier", "")), str(state.get("run_id", "")), "%s_%s_%d" % [str(unit.id), str(key), out.picks.size()]))
	## A Quarry stake made better for a deep start says so, and how much better, in its own
	## words with the numbers filled in.
	if k > 0:
		out.k = k
		out.upgraded = true
		out.names = keys.map(func(key: Variant) -> String: return str(DeepContent.boon(str(key)).get("name", key)))
		out.texts = keys.map(func(key: Variant) -> String: return stake_text(state, str(key), k))
	return out

# --- the deep start --------------------------------------------------------------------------

static func effects_of(key: String, k: int) -> Array:
	## A boon's effects as they act for a start `k` mines down: as written for the Quarry (k 0,
	## and every deep card, which reads its `k` off the offer), else each made better.
	var effects: Array = DeepContent.boon(key).get("effects", [])
	if k <= 0 or str(DeepContent.boon(key).get("group", "")) == "deep":
		return effects
	return effects.map(func(e: Dictionary) -> Dictionary: return upgraded_effect(e, k))

static func upgraded_effect(effect: Dictionary, k: int) -> Dictionary:
	## One Quarry stake's effect made better for `k` mines skipped. A cost (a negative amount:
	## Thinner Blood, A Bad Fall, Chipped) is left as it is: only what a stake gives grows.
	##   ore             x(1 + k)              Staked 40 -> 80 .. 280, Well Staked 90 -> 180 .. 630
	##   max_hp_pct      +6 a mine             Hardy 12% -> 18 .. 48%, Iron Constitution 25% -> 31 .. 61%
	##   raw/pick_stone  depth +2 a mine       A Read Stone, Pick of Three 4 -> 6 .. 16; A Fragile Find 20 -> 22 ..
	##   carat           +half again a mine    Weighed Heavier 2 -> 3 .. 8, Four Carats 4 -> 6 .. 16
	##   cut_step        +1 every three mines  A Truer Set 1 -> 1, 1, 2, 2, 2, 3
	##   resize_die      1 + k charges, 5 at most  Hammered 1 -> 2, 3, 4, 5
	##   wild_face       1 + ceil(k/2) charges, 5 at most  A Wild Face 1 -> 2, 2, 3, 3, 4, 4
	##   extra_rerolls   down to depth x(1 + k) Steady Hands to depth 4 -> 8 .. 28
	##   soft_rock       +1 fight a mine       Soft Rock 3 -> 4 .. 9
	##   rail_all        +1 carat every two mines  The Whole Rail 1 -> 1, 2, 2, 3, 3, 4
	var e: Dictionary = effect.duplicate(true)
	var amount: int = int(e.get("amount", 0))
	match str(e.get("kind", "")):
		"ore":
			if amount > 0:
				e.amount = amount * (1 + k)
		"max_hp_pct":
			if amount > 0:
				e.amount = amount + 6 * k
		"raw_stone", "pick_stone":
			e.depth = int(e.get("depth", 4)) + 2 * k
		"carat":
			if amount > 0:
				e.amount = amount + amount * k / 2
		"cut_step":
			if amount > 0:
				e.amount = amount + k / 3
		"resize_die":
			e.count = mini(1 + k, 5)
		"wild_face":
			e.count = mini(1 + int(ceil(float(k) / 2.0)), 5)
		"extra_rerolls":
			e.until_depth = int(e.get("until_depth", 4)) * (1 + k)
		"soft_rock":
			e.fights = int(e.get("fights", 3)) + k
		"rail_all":
			if int(e.get("carat", 0)) > 0:
				e.carat = int(e.carat) + k / 2
	return e

static func fill(text: String, numbers: Dictionary) -> String:
	## A card's words with its numbers written in: `{name}` is the number, `{name#noun}` the
	## number and its noun ("1 carat", "3 carats"), as a skill's card text reads its numbers.
	var exprs: Dictionary = {}
	for key in numbers:
		exprs[key] = {"const": int(numbers[key])}
	return DeepRules.fill(text, exprs, 0, 1.0)

static func stake_text(state: Dictionary, key: String, k: int) -> String:
	## What a Quarry stake says for a start `k` mines down: its `deep_text` with the numbers
	## it comes to. A stake with no `deep_text` (a cost, which never grows) says what it
	## always says.
	var def: Dictionary = DeepContent.boon(key)
	if k <= 0 or not def.has("deep_text"):
		return str(def.get("text", ""))
	var numbers: Dictionary = {}
	var mine: Dictionary = DeepDescent.mine_of(state)
	for effect in effects_of(key, k):
		var amount: int = int(effect.get("amount", 0))
		match str(effect.get("kind", "")):
			"ore":
				numbers.ore = amount
			"max_hp_pct":
				numbers.pct = amount
			"raw_stone":
				## Never from deeper than the mine goes, as the find itself is (`_effect`).
				var depth: int = int(effect.get("depth", 4))
				if int(mine.get("depth", 0)) > 0:
					depth = mini(depth, int(mine.depth))
				numbers.depth = depth
			"pick_stone":
				numbers.depth = int(effect.get("depth", 4))
			"carat":
				numbers.carats = amount
			"cut_step":
				numbers.steps = amount
			"resize_die", "wild_face":
				numbers.count = int(effect.get("count", 1))
			"extra_rerolls":
				numbers.depth = int(effect.get("until_depth", 4))
			"soft_rock":
				numbers.fights = int(effect.get("fights", 3))
			"rail_all":
				numbers.carats = int(effect.get("carat", 1))
	return fill(str(def.deep_text), numbers)

static func deep_text(offer: Dictionary) -> String:
	## A deep card's words, with what the offer holds written in (its `text` in content).
	var key: String = str(offer.get("boons", [""])[0])
	var numbers: Dictionary = {"k": int(offer.get("k", 0)), "take": int(offer.get("take", 0)), "offered": offer.get("picks", []).size(),
		"count": offer.get("picks", []).size(), "carats": int(offer.get("carats", 0)), "ore": int(offer.get("ore", 0)),
		"raw": offer.get("stones", []).size(), "rooms": int(offer.get("rooms", 0))}
	return fill(str(DeepContent.boon(key).get("text", "")), numbers)

static func _make_deep_offer(state: Dictionary, unit: Dictionary, key: String, rng: RandomNumberGenerator, k: int) -> Dictionary:
	## One deep card, with everything it holds rolled now, so the card shows what it gives:
	##   gem_pouch    picks: 4 + k read stones from the skipped mines; take: 1 + ceil(k/2) of them
	##   dice_bag     picks: 2 + k dice, each one of the player's own reworked as a bench would
	##   one_material picks: three material keys, none the one every die already shares
	##   heirloom     carats: k, cut: 1 (every stone brought from the vault, for the run)
	##   deep_purse   ore: 60 x k, stones: 2 + floor(k/2) raw stones from the skipped mines
	##   vouchers     rooms: k (the next k smithies or carvers visited do better work)
	var def: Dictionary = DeepContent.boon(key)
	var needs: String = str(def.get("needs", ""))
	var out: Dictionary = {"id": "", "kind": "deep", "boons": [key], "needs": [] if needs.is_empty() else [needs], "picks": [], "pick_kind": "",
		"deep": true, "k": k, "names": [str(def.get("name", key))]}
	for effect in def.get("effects", []):
		match str(effect.get("kind", "")):
			"gem_pouch":
				out.pick_kind = "stones"
				out.picks = _deep_stones(state, unit, rng, int(effect.get("offered", 4)) + k, true)
				out.take = mini(out.picks.size(), int(effect.get("take", 1)) + int(ceil(float(k) / 2.0)))
			"dice_bag":
				out.pick_kind = "dice"
				out.picks = _bag_dice(state, unit, rng, int(effect.get("count", 2)) + k)
			"one_material":
				out.pick_kind = "material"
				out.picks = _material_picks(unit, rng, int(effect.get("count", 3)))
			"heirloom":
				out.carats = int(effect.get("carat_per_mine", 1)) * k
				out.cut = int(effect.get("cut", 1))
			"deep_purse":
				out.ore = int(effect.get("ore_per_mine", 60)) * k
				out.stones = _deep_stones(state, unit, rng, int(effect.get("raw", 2)) + k / 2, false)
			"vouchers":
				out.rooms = int(effect.get("per_mine", 1)) * k
	out.texts = [deep_text(out)]
	return out

static func _deep_stones(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator, count: int, read: bool) -> Array:
	## Stones from the mines a deep start skipped, each from one of them drawn at random, out
	## of that mine's own pool at its bottom: distinct skills, none the player holds anywhere,
	## never an opal and never fragile (a Void is drawn again, and stripped if it comes back).
	## The player's loadout luck rides on each, as on every stone the mine gives them; taking
	## them does not change it (CLAUDE.md, docs/DEEP_START.md).
	var skipped: Array = DeepDescent.skipped_mines(str(state.get("mine", "")))
	if skipped.is_empty():
		skipped = [DeepContent.starter_mine()]
	var held: Array = DeepDescent._held_skills(unit)
	var out: Array = []
	for _i in range(count):
		var key: String = str(DeepRng.pick(rng, skipped))
		var mine: Dictionary = DeepContent.mine(key).duplicate()
		mine.key = key
		var open: Array = DeepForge.skill_pool(mine).filter(func(s: String) -> bool: return str(DeepContent.skill(s).get("color", "")) != DeepContent.OPAL)
		var pool: Array = open.filter(func(s: String) -> bool: return not held.has(s) and not out.any(func(o: Dictionary) -> bool: return str(o.get("skill", "")) == s))
		if pool.is_empty():
			pool = open
		var depth: int = int(mine.get("depth", 0)) if int(mine.get("depth", 0)) > 0 else int(DeepContent.constant("temporary_depth", 20))
		var provenance: Dictionary = {"run": str(state.get("run_id", "")), "source": "deep_start", "finder": str(unit.get("id", "")), "mine": key}
		var id: String = DeepDescent._id(state, "deep")
		var stone: Dictionary = {}
		for _try in range(DEEP_TRIES):
			stone = DeepForge.roll_stone(rng, mine, depth, float(unit.get("loadout_luck", 0.0)), provenance, id, pool)
			if not DeepStone.is_fragile(stone):
				break
		stone.inclusions = stone.get("inclusions", []).filter(func(i: Variant) -> bool:
			return not DeepContent.inclusion(str(i)).get("modifiers", []).any(func(m: Dictionary) -> bool: return str(m.get("kind", "")) == "fragile"))
		stone.appraised = read
		stone.inclusions_revealed = read
		out.append(stone)
	return out

static func _bag_dice(state: Dictionary, unit: Dictionary, rng: RandomNumberGenerator, count: int) -> Array:
	## Dice the benches above would have cut: each one of the player's own dice, drawn at
	## random, a size smaller, the same or bigger (drawn too) by the mine's `start_dice_offer`
	## tuning, with its variations, exactly as the old shaft-head swaps rolled them
	## (`DeepDescent._offered_die`); never the die it was drawn from nor one already in the
	## bag. Each has an id of its own until it is swapped in (it then takes the id of the die
	## it replaces).
	var tuning: Dictionary = DeepDescent.mine_of(state).get("start_dice_offer", {})
	var dice: Array = unit.get("dice", [])
	var out: Array = []
	if dice.is_empty():
		return out
	for index in range(count):
		var base: Dictionary = dice[rng.randi_range(0, dice.size() - 1)]
		var side: int = rng.randi_range(-1, 1)
		var offered: Dictionary = {}
		for _try in range(DeepDescent.DICE_OFFER_TRIES):
			offered = DeepDescent._offered_die(base, side * DeepDescent._offer_steps(rng, tuning), tuning, rng)
			if not ([base] + out).any(func(other: Dictionary) -> bool: return DeepDescent.same_die(other, offered)):
				break
		offered.id = "%s_bag%d" % [str(unit.get("id", "")), index]
		out.append(offered)
	return out

static func _material_picks(unit: Dictionary, rng: RandomNumberGenerator, count: int) -> Array:
	## `count` different materials the rock can give, by their rarity, never the one every die
	## the player carries is already made of.
	var shared: String = ""
	var dice: Array = unit.get("dice", [])
	if not dice.is_empty() and dice.all(func(d: Dictionary) -> bool: return str(d.get("material", "")) == str(dice[0].get("material", ""))):
		shared = str(dice[0].get("material", ""))
	var out: Array = []
	for _try in range(count * DEEP_TRIES * 4):
		if out.size() >= count:
			break
		var material: String = DeepForge.roll_material(rng)
		if material.is_empty() or material == shared or out.has(material):
			continue
		out.append(material)
	return out

# --- charges: Hammered, A Wild Face ----------------------------------------------------------

static func can_charge(die: Dictionary, kind: String) -> bool:
	## Whether one more charge of this kind may land on this die as it is now: a size upgrade
	## on any die not yet as big as dice come, a wild face on any die with a face not wild yet.
	match kind:
		"resize":
			return DeepOddities.resize_refusal(die, 1).is_empty()
		"wild":
			return die.get("faces", []).any(func(f: Dictionary) -> bool: return str(f.get("kind", "plain")) != "wild")
	return false

static func _charge(die: Dictionary, kind: String) -> String:
	## One charge on one die, in place: one size bigger, or its lowest face that is not wild yet
	## turned wild (the first of them on a tie). Says what it did.
	var was: String = DeepDice.describe(die)
	match kind:
		"resize":
			DeepOddities.resize(die, 1)
			return "Your %s is a %s now." % [was, DeepDice.describe(die)]
		"wild":
			var faces: Array = die.get("faces", [])
			var low: int = -1
			for index in range(faces.size()):
				if str(faces[index].get("kind", "plain")) == "wild":
					continue
				if low < 0 or int(faces[index].get("value", 0)) < int(faces[low].get("value", 0)):
					low = index
			faces[low] = DeepDice.face(int(faces[low].get("value", 0)), "wild")
			return "The %d on your %s turns wild." % [int(faces[low].value), was]
	return ""

static func charge_refusal(unit: Dictionary, kind: String, dice_ids: Array, most: int) -> String:
	## Why these charges, in this order, cannot land, or "": one to `most` of them, each on one
	## of the player's dice that can take it once the charges before it have landed.
	if dice_ids.is_empty() or dice_ids.size() > most:
		return "choose a die for each of up to %d %s" % [most, "charge" if most == 1 else "charges"]
	var dice: Array = unit.get("dice", []).duplicate(true)
	for id in dice_ids:
		var at: int = -1
		for index in range(dice.size()):
			if str(dice[index].get("id", "")) == str(id):
				at = index
		if at < 0:
			return "that is not one of your dice"
		if not can_charge(dice[at], kind):
			return "that die cannot be made any bigger" if kind == "resize" else "every face of that die is wild already"
		_charge(dice[at], kind)
	return ""

static func charge_preview(unit: Dictionary, kind: String, dice_ids: Array) -> Array:
	## The player's dice as they would be after these charges, in click order (copies; the
	## player's own are untouched), worked by exactly the code `apply` uses. A charge on an id
	## that is not one of theirs, or on a die that can take no more, is skipped.
	var dice: Array = unit.get("dice", []).duplicate(true)
	for id in dice_ids:
		for die in dice:
			if str(die.get("id", "")) == str(id) and can_charge(die, kind):
				_charge(die, kind)
				break
	return dice

static func _pick_colors(rng: RandomNumberGenerator, mine: Dictionary, count: int) -> Array:
	## `count` different colors the mine's rock offers, in a drawn order. Opal is never one:
	## nothing but a Warden's hoard offers an opal.
	var offered: Array = []
	for key in DeepForge.skill_pool(mine):
		var color: String = str(DeepContent.skill(str(key)).get("color", ""))
		if not color.is_empty() and color != DeepContent.OPAL and not offered.has(color):
			offered.append(color)
	offered.sort()
	var out: Array = []
	while not offered.is_empty() and out.size() < count:
		var drawn: String = str(DeepRng.pick(rng, offered))
		offered.erase(drawn)
		out.append(drawn)
	return out

static func _raw_pick(rng: RandomNumberGenerator, mine: Dictionary, color: String, depth: int, bonus: int, min_tier: String, run_id: String, id: String) -> Dictionary:
	## A stone of one color, still in its rock: what it is stays the loupe's to say until
	## it is taken. `min_tier` is a promise about what the loupe will find.
	var pool: Array = DeepForge.skill_pool(mine).filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == color)
	var stone: Dictionary = DeepForge.roll_stone(rng, mine, depth, bonus, {"run": run_id, "source": "grubstake"}, id, pool)
	if not min_tier.is_empty():
		var wanted: int = DeepStone.TIERS.find(min_tier)
		var tries: int = 0
		while tries < PICK_TRIES and DeepStone.TIERS.find(str(DeepStone.grade(stone).tier)) < wanted:
			tries += 1
			var again: Dictionary = DeepForge.roll_stone(rng, mine, depth, bonus + tries * 3, {"run": run_id, "source": "grubstake"}, id, pool)
			if int(DeepStone.grade(again).score) >= int(DeepStone.grade(stone).score):
				stone = again
	stone.appraised = false
	stone.inclusions_revealed = false
	return stone

# --- taking a stake ------------------------------------------------------------------------------

static func apply(state: Dictionary, unit: Dictionary, chosen: Dictionary, payload: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## Resolve one player's stake. A stake on a stone lands on one stone drawn from the rail,
	## every effect of it on the same one; a pick takes the candidate the payload names.
	## Returns {ok, error, message, made: [stones], dice: [dice], changed: [the rail stone], socket}.
	var out: Dictionary = {"ok": true, "error": "", "message": "", "made": [], "dice": [], "changed": [], "socket": -1}
	var pick: int = int(payload.get("pick", -1))
	if chosen.get("needs", []).has("pick"):
		if pick < 0 or pick >= chosen.get("picks", []).size():
			return _refuse("choose one of the %s" % ("three" if chosen.get("picks", []).size() == 3 else str(chosen.get("picks", []).size())))
	## A Bag of Gems: exactly `take` of its stones, each once.
	if chosen.get("needs", []).has("picks"):
		var taken: Variant = payload.get("picks", [])
		var take: int = int(chosen.get("take", 1))
		if not taken is Array or taken.size() != take:
			return _refuse("choose %d of them" % take)
		var seen: Array = []
		for at in taken:
			if not (at is int or at is float) or int(at) < 0 or int(at) >= chosen.get("picks", []).size() or seen.has(int(at)):
				return _refuse("choose %d different stones from the pouch" % take)
			seen.append(int(at))
	## Hammered, A Wild Face: one to `count` charges, each on a die that can take it.
	if chosen.get("needs", []).has("charges"):
		var charged: Variant = payload.get("dice", [])
		var charges: Dictionary = chosen.get("charges", {"kind": "resize", "count": 1})
		if not charged is Array:
			return _refuse("choose a die for each charge")
		var refusal: String = charge_refusal(unit, str(charges.kind), charged, int(charges.count))
		if not refusal.is_empty():
			return _refuse(refusal)
	## A Bag of Dice, its free swap (November 2026): `hand`, the player's dice as they will be,
	## in slot order, each from their own or the bag's, each once, as many as they carry.
	if chosen.get("needs", []).has("swaps") and payload.has("hand"):
		var hand: Variant = payload.get("hand", [])
		var own: Array = unit.get("dice", []).map(func(d: Dictionary) -> String: return str(d.get("id", "")))
		var bag: Array = chosen.get("picks", []).map(func(d: Dictionary) -> String: return str(d.get("id", "")))
		if not hand is Array or hand.size() != own.size():
			return _refuse("choose %d dice to carry" % own.size())
		var used: Array = []
		for id in hand:
			if not (own.has(str(id)) or bag.has(str(id))):
				return _refuse("that die is neither yours nor in the bag")
			if used.has(str(id)):
				return _refuse("each die only once")
			used.append(str(id))
	## A Bag of Dice, the older payload: any of its dice, each for one of the player's own.
	elif chosen.get("needs", []).has("swaps"):
		var swaps: Variant = payload.get("swaps", {})
		if not swaps is Dictionary:
			return _refuse("say which of your dice each one replaces")
		var replaced: Array = []
		for at in swaps:
			var index: int = int(str(at)) if str(at).is_valid_int() else -1
			if index < 0 or index >= chosen.get("picks", []).size():
				return _refuse("there is no such die in the bag")
			var own: String = str(swaps[at])
			if not unit.get("dice", []).any(func(d: Dictionary) -> bool: return str(d.get("id", "")) == own):
				return _refuse("that is not one of your dice")
			if replaced.has(own):
				return _refuse("one die can be swapped only once")
			replaced.append(own)
	var socket: int = -1
	if chosen.get("needs", []).has("socket"):
		var set_sockets: Array = []
		for index in range(unit.get("rail", []).size()):
			if unit.rail[index] is Dictionary:
				set_sockets.append(index)
		if set_sockets.is_empty():
			return _refuse("your rail is empty")
		socket = int(DeepRng.pick(rng, set_sockets))
		out.socket = socket
	var lines: Array = []
	## A Quarry stake on a deep start's card acts as made better (`upgraded`, `k`).
	var k: int = int(chosen.get("k", 0)) if bool(chosen.get("upgraded", false)) else 0
	for key in chosen.get("boons", []):
		for effect in effects_of(str(key), k):
			var said: String = _effect(state, unit, effect, chosen, socket, pick, rng, out, payload)
			if not said.is_empty():
				lines.append(said)
	if socket >= 0:
		out.changed.append(unit.rail[socket].duplicate(true))
	out.message = " ".join(lines)
	return out

static func _effect(state: Dictionary, unit: Dictionary, effect: Dictionary, chosen: Dictionary, socket: int, pick: int, rng: RandomNumberGenerator, out: Dictionary, payload: Dictionary = {}) -> String:
	var kind: String = str(effect.get("kind", ""))
	var mine: Dictionary = DeepDescent.mine_of(state)
	var amount: int = int(effect.get("amount", 0))
	match kind:
		"cut_step":
			## Only ever on a rail stone, which is a copy of the one in the vault, and only for
			## this run: the workshop's own stone is untouched whichever way this goes, so a
			## stake may promise a truer cut without a stone ever becoming farmable.
			var stone: Dictionary = unit.rail[socket]
			var before: int = int(stone.get("cut", 0))
			stone.cut = clampi(before + amount, 0, DeepPatterns.STEPS - 1)
			_note(stone, "cut", before, int(stone.cut) - before)
			var skill_name: String = str(DeepStone.skill_of(stone).get("name", stone.skill))
			## Already at the end of the ladder (the starter Mend is cut Poor): said so plainly,
			## rather than reported as a change it never made.
			if int(stone.cut) == before:
				return "%s is already a %s Cut, so this changes nothing." % [skill_name, DeepContent.cut_name(before)]
			return "%s is now a %s Cut, from %s." % [skill_name, DeepContent.cut_name(int(stone.cut)), DeepContent.cut_name(before)]
		"reroll_cut":
			## A fresh draw of the stone's Cut from this mine's table, better or worse. With
			## `best_of` the wheel is kind and the truer of that many rolls is kept.
			var stone: Dictionary = unit.rail[socket]
			var was: int = int(stone.get("cut", 0))
			var best: int = -1
			for _try in range(maxi(1, int(effect.get("best_of", 1)))):
				best = maxi(best, DeepForge.reroll_cut(rng, stone, mine, int(effect.get("depth", 4)), int(effect.get("bonus", 0))))
			stone.cut = best
			_note(stone, "cut", was, best - was)
			return "%s comes off the wheel %s, from %s." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), DeepContent.cut_name(best), DeepContent.cut_name(was)]
		"reroll_clarity":
			var stone: Dictionary = unit.rail[socket]
			var rolled: Dictionary = DeepForge.reroll_clarity(rng, stone, mine, int(effect.get("depth", 4)), int(effect.get("bonus", 0)))
			## Marked in steps from Clear, the way the ladder counts better, so the mark reads
			## the same as a stake that stepped it; the old inclusions go back with the stone.
			var clear: int = DeepContent.clear_index()
			_note(stone, "clarity", int(rolled.was), absi(int(rolled.clarity) - clear) - absi(int(rolled.was) - clear), rolled.had)
			var named: Array = DeepStone.inclusion_names(stone)
			return "%s is fired again: %s, from %s.%s" % [str(DeepStone.skill_of(stone).get("name", stone.skill)),
				DeepContent.clarity_name(int(rolled.clarity)), DeepContent.clarity_name(int(rolled.was)),
				("" if named.is_empty() else " Inside it now: %s." % ", ".join(named))]
		"carat":
			var stone: Dictionary = unit.rail[socket]
			var before: int = int(stone.get("carat", 1))
			stone.carat = clampi(before + amount, 1, DeepStone.carat_max())
			_note(stone, "carat", before, int(stone.carat) - before)
			## Every carat boon adds weight, so a stone it left unchanged was as heavy as they come.
			if int(stone.carat) == before:
				return "%s already weighs %d carats, as heavy as a stone gets." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), before]
			return "%s weighs %d carats now." % [str(DeepStone.skill_of(stone).get("name", stone.skill)), int(stone.carat)]
		"rail_all":
			## Every stone set on the rail, not one drawn from it. Carat and Cut step straight
			## up; Clarity steps further from Clear along whichever side the stone already
			## leans, which is the only direction "better" means on that ladder.
			var touched: Array = []
			for index in range(unit.get("rail", []).size()):
				if not unit.rail[index] is Dictionary:
					continue
				var stone: Dictionary = unit.rail[index]
				if int(effect.get("carat", 0)) != 0:
					var carat_was: int = int(stone.get("carat", 1))
					stone.carat = clampi(carat_was + int(effect.carat), 1, DeepStone.carat_max())
					_note(stone, "carat", carat_was, int(stone.carat) - carat_was)
				if int(effect.get("cut", 0)) != 0:
					var cut_was: int = int(stone.get("cut", 0))
					stone.cut = clampi(cut_was + int(effect.cut), 0, DeepPatterns.STEPS - 1)
					_note(stone, "cut", cut_was, int(stone.cut) - cut_was)
				if int(effect.get("clarity", 0)) != 0:
					## Where it stood, and what was inside it, before the ladder moved: the
					## mark has to be able to put both back when the run ends.
					var was_clarity: int = int(stone.get("clarity", DeepContent.clear_index()))
					var was_inside: Array = stone.get("inclusions", []).duplicate()
					var stepped: Dictionary = DeepForge.step_clarity(rng, stone, mine, absi(int(effect.clarity)))
					if bool(stepped.moved):
						_note(stone, "clarity", was_clarity, absi(int(stepped.clarity) - was_clarity) * signi(int(effect.clarity)), was_inside)
				out.changed.append(stone.duplicate(true))
				touched.append(str(DeepStone.skill_of(stone).get("name", stone.skill)))
			if touched.is_empty():
				return "Your rail is empty, so nothing happens."
			return "The whole rail comes up: %s." % ", ".join(touched)
		"inclusion":
			var stone: Dictionary = unit.rail[socket]
			var rolled: Array = DeepForge.roll_inclusions(rng, 1, mine, str(effect.get("class", "PINPOINT")), DeepStone.color(stone))
			var fresh: Array = rolled.filter(func(k: String) -> bool: return not stone.get("inclusions", []).has(k))
			if fresh.is_empty():
				return "%s can't take any more inclusions." % str(DeepStone.skill_of(stone).get("name", stone.skill))
			stone.inclusions.append(str(fresh[0]))
			stone.inclusions_revealed = true
			return "A %s forms inside %s." % [str(DeepContent.inclusion(str(fresh[0])).get("name", fresh[0])), str(DeepStone.skill_of(stone).get("name", stone.skill))]
		"raw_stone":
			## `read` hands it over already under the loupe; `fragile` hands it over on the
			## understanding that it is a loan. A fragile stake shatters when the run ends and
			## never reaches the vault, which is what pays for its size.
			## Never from deeper than the mine goes: a find "from depth 20" comes from the bottom of
			## a mine that ends sooner. An endless mine has no bottom to stop at.
			var from_depth: int = int(effect.get("depth", 4))
			if int(mine.get("depth", 0)) > 0:
				from_depth = mini(from_depth, int(mine.depth))
			var stone: Dictionary = DeepForge.roll_stone(rng, mine, from_depth, int(effect.get("bonus", 0)),
				{"run": str(state.get("run_id", "")), "source": "grubstake", "finder": str(unit.id)}, "%s_stake%08x" % [str(unit.id), rng.randi()])
			var read: bool = bool(effect.get("read", false))
			stone.appraised = read
			stone.inclusions_revealed = read
			if bool(effect.get("fragile", false)):
				stone.fragile = true
			unit.haul.append(stone)
			out.made.append(stone)
			if not read:
				return "A %s goes into your haul, unappraised." % DeepStone.raw_name(stone).to_lower()
			if bool(stone.get("fragile", false)):
				return "%s goes into your haul, appraised. It's fragile and won't make it home." % DeepStone.name(stone)
			return "%s goes into your haul, appraised and ready to set." % DeepStone.name(stone)
		"pick_stone":
			## Taken, and read on the spot: the rock comes off under the loupe and the stone
			## goes into the haul known, ready to set.
			var stone: Dictionary = chosen.picks[pick].duplicate(true)
			var was: String = DeepStone.raw_name(stone)
			stone.provenance.finder = str(unit.id)
			stone.appraised = true
			stone.inclusions_revealed = true
			unit.haul.append(stone)
			out.made.append(stone)
			out.pick = true
			return "You take the %s. Under the loupe it is a %s." % [was.to_lower(), DeepStone.name(stone)]
		"resize_die", "wild_face":
			## Charges (November 2026): each lands on the die the payload names, in click order,
			## the same die as often as it will take one (checked in `apply`). Charges left unused
			## are lost.
			var charge: String = str(CHARGE_KINDS[kind])
			var said: Array = []
			var touched: Array = []
			for id in payload.get("dice", []):
				for die in unit.get("dice", []):
					if str(die.get("id", "")) == str(id) and can_charge(die, charge):
						said.append(_charge(die, charge))
						if not touched.has(die):
							touched.append(die)
						break
			for die in touched:
				out.dice.append(die.duplicate(true))
			out.charged = payload.get("dice", []).map(func(id: Variant) -> String: return str(id))
			return " ".join(said)
		"gem_pouch":
			## The stones taken go into the bag, read: finds like any other, so they come home
			## if the run does. The rest stay in the pouch.
			var named: Array = []
			for at in payload.get("picks", []):
				var stone: Dictionary = chosen.picks[int(at)].duplicate(true)
				unit.haul.append(stone)
				out.made.append(stone)
				named.append(DeepStone.name(stone))
			return "Into your bag: %s." % ", ".join(named)
		"dice_bag" when payload.has("hand"):
			## The free swap: the player's dice become the hand named, in its order. A die of the
			## bag taken takes the id of one of theirs left out, in slot order, so the bowl keeps
			## the same ids; a die left out is gone for the run (the bowl at home is untouched, as
			## with every die down the mine), and so is every bag die not taken.
			var own: Dictionary = {}
			for die in unit.get("dice", []):
				own[str(die.get("id", ""))] = die
			var bag: Dictionary = {}
			for index in range(chosen.get("picks", []).size()):
				bag[str(chosen.picks[index].get("id", ""))] = index
			var hand: Array = payload.get("hand", []).map(func(id: Variant) -> String: return str(id))
			var was_order: Array = unit.get("dice", []).map(func(d: Dictionary) -> String: return str(d.get("id", "")))
			var dropped: Array = unit.get("dice", []).map(func(d: Dictionary) -> String: return str(d.get("id", ""))).filter(func(id: String) -> bool: return not hand.has(id))
			var said: Array = []
			var dice: Array = []
			out.swapped = []
			for slot in range(hand.size()):
				var id: String = hand[slot]
				if own.has(id):
					dice.append(own[id])
					continue
				var die: Dictionary = chosen.picks[int(bag[id])].duplicate(true)
				var replaced: Dictionary = own[dropped.pop_front()]
				said.append("your %s for a %s" % [DeepDice.describe(replaced), DeepDice.describe(die)])
				die.id = str(replaced.get("id", ""))
				dice.append(die)
				out.dice.append(die.duplicate(true))
				out.swapped.append({"die_id": str(die.id), "pick": int(bag[id]), "slot": slot})
			unit.dice = dice
			out.hand = dice.map(func(d: Dictionary) -> String: return str(d.get("id", "")))
			if said.is_empty():
				return "You keep your dice." if was_order == out.hand else "You set your dice in a new order."
			return "You swap %s." % ", ".join(said)
		"dice_bag":
			## The older payload, `swaps`: each die swapped in takes the place, and the id, of the
			## one it replaces, which is gone for the run. The dice not swapped in stay in the bag.
			var swaps: Dictionary = payload.get("swaps", {})
			var order: Array = swaps.keys().map(func(at: Variant) -> int: return int(str(at)))
			order.sort()
			var said: Array = []
			out.swapped = []
			for index in order:
				var own: String = str(swaps.get(str(index), swaps.get(index, "")))
				for slot in range(unit.dice.size()):
					if str(unit.dice[slot].get("id", "")) != own:
						continue
					var was: String = DeepDice.describe(unit.dice[slot])
					var die: Dictionary = chosen.picks[index].duplicate(true)
					die.id = own
					unit.dice[slot] = die
					out.dice.append(die.duplicate(true))
					out.swapped.append({"die_id": own, "pick": index})
					said.append("your %s for a %s" % [was, DeepDice.describe(die)])
					break
			if said.is_empty():
				return "You keep your dice as they are."
			return "You swap %s." % ", ".join(said)
		"one_material":
			var material: String = str(chosen.picks[pick])
			for die in unit.get("dice", []):
				die.material = material
				out.dice.append(die.duplicate(true))
			out.material = material
			return "Every die you carry is %s now." % DeepDice.material_name(material).to_lower()
		"heirloom":
			## Every stone brought from the vault (a lent copy), for this run: marked on the stone
			## as a stake is (`_note`), as The Whole Rail does it.
			var carats: int = int(chosen.get("carats", 0))
			var cut: int = int(chosen.get("cut", 1))
			var touched: Array = []
			for stone in DeepStone.rail_stones(unit):
				if not bool(stone.get("lent", false)):
					continue
				var carat_was: int = int(stone.get("carat", 1))
				stone.carat = clampi(carat_was + carats, 1, DeepStone.carat_max())
				_note(stone, "carat", carat_was, int(stone.carat) - carat_was)
				var cut_was: int = int(stone.get("cut", 0))
				stone.cut = clampi(cut_was + cut, 0, DeepPatterns.STEPS - 1)
				_note(stone, "cut", cut_was, int(stone.cut) - cut_was)
				out.changed.append(stone.duplicate(true))
				touched.append(str(DeepStone.skill_of(stone).get("name", stone.skill)))
			if touched.is_empty():
				return "You brought no stones from the vault, so nothing changes."
			return "Polished for this run: %s." % ", ".join(touched)
		"deep_purse":
			unit.ore = int(unit.get("ore", 0)) + int(chosen.get("ore", 0))
			for raw in chosen.get("stones", []):
				var stone: Dictionary = raw.duplicate(true)
				unit.haul.append(stone)
				out.made.append(stone)
			var raw_count: int = chosen.get("stones", []).size()
			return "You take %d pyrite and %d raw %s, unappraised." % [int(chosen.get("ore", 0)), raw_count, "stone" if raw_count == 1 else "stones"]
		"vouchers":
			unit.vouchers = int(unit.get("vouchers", 0)) + int(chosen.get("rooms", 0))
			out.vouchers = int(unit.vouchers)
			return "The next %s you visit will do better work." % ("smithy or carver" if int(chosen.get("rooms", 0)) == 1 else "%d smithies or carvers" % int(chosen.get("rooms", 0)))
		"max_hp_pct":
			return _max_hp(unit, amount)
		"hp_pct":
			var loss: int = int(floor(float(unit.get("hp", 0)) * float(absi(amount)) / 100.0))
			unit.hp = maxi(1, int(unit.get("hp", 0)) - loss)
			return "You start %d health down." % loss
		"ore":
			unit.ore = maxi(0, int(unit.get("ore", 0)) + amount)
			return ("You take %d pyrite." % amount) if amount >= 0 else ("You give up %d pyrite." % -amount)
		"soft_rock":
			if not unit.has("run_mods"):
				unit.run_mods = {}
			unit.run_mods.soft_rock = int(unit.run_mods.get("soft_rock", 0)) + int(effect.get("fights", 3))
			return "Creatures start at half health for your first %d fights." % int(effect.get("fights", 3))
		"extra_rerolls":
			if not unit.has("run_mods"):
				unit.run_mods = {}
			## On top of whatever the day already lends (a daily dig's Steady Hands).
			var had: Dictionary = unit.run_mods.get("extra_rerolls", {})
			unit.run_mods.extra_rerolls = {"amount": int(had.get("amount", 0)) + int(effect.get("amount", 1)),
				"until_depth": maxi(int(had.get("until_depth", 0)), int(effect.get("until_depth", 4)))}
			return "+%d reroll a turn down to depth %d." % [int(effect.get("amount", 1)), int(effect.get("until_depth", 4))]
	return ""

static func _note(stone: Dictionary, field: String, before: int, applied: int, inside: Array = []) -> void:
	## What a stake did to one of the rail's stones, written on the stone itself so every
	## screen that draws it can mark the change the way a buff is marked.
	##
	## The mark carries the stone as it was before the stake touched it, because the rail is
	## only a copy of the vault for as long as the run lasts: a stone taken out of its socket
	## and carried home in the haul has to arrive as the stone that went down. `DeepStone.
	## unstake` is what puts it back, and the vault is where that is done. `before` is the
	## field as it stood and `applied` what the stake really moved it by, after the ladder's
	## ends; a clarity step also hands over what was inside the stone before it moved.
	if not stone.has("staked"):
		stone.staked = {}
	if not stone.staked.has("was"):
		stone.staked.was = {"carat": before if field == "carat" else int(stone.get("carat", 1)),
			"cut": before if field == "cut" else int(stone.get("cut", 0)),
			"clarity": before if field == "clarity" else int(stone.get("clarity", DeepContent.clear_index())),
			"inclusions": (inside if field == "clarity" else stone.get("inclusions", [])).duplicate()}
	stone.staked[field] = int(stone.staked.get(field, 0)) + applied

static func _max_hp(unit: Dictionary, pct: int) -> String:
	var delta: int = int(round(float(unit.get("max_hp", 60)) * float(pct) / 100.0))
	unit.max_hp = maxi(1, int(unit.get("max_hp", 60)) + delta)
	unit.hp = clampi(int(unit.get("hp", unit.max_hp)) + delta, 1, int(unit.max_hp))
	## Says the most health moved too, or beside a cost's "You start N health down" it reads as
	## one number going down and back up, with no word of why the top is now further away.
	return ("Your most health rises by %d, and your health with it." % delta) if delta >= 0 else ("Your most health falls by %d, and your health with it." % -delta)

static func _refuse(error: String) -> Dictionary:
	return {"ok": false, "error": error, "message": "", "made": [], "dice": []}
