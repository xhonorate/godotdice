extends RefCounted
## The delve bot: one careful player going down one mine through the real rules, for the balance
## runs (tools/balance/delve.gd plays the jobs, tools/balance/delve.mjs sets them and reads the
## answers; docs/BALANCE.md says how to read them).
##
## It only ever does what a player can: every move is a `DeepDescent.command`, and a fight is
## stepped with `DeepDescent.step`. What it knows it reads off the run the way a screen would.
## It never draws from the run's own random streams: its what-ifs come from dice of its own,
## seeded by the job, so one job always plays the same run.
##
## It has no opinions about gems. Whatever it weighs, it weighs by playing it:
##
##   a hand      `play_rail` plays the party's half of a turn for real, on a copy of the fight:
##               every gem, replay and repeat, the Birthstone, whatever a creature sends back.
##               `turn_worth` reads what that left: the health it took off the creatures, what
##               they are expected to do in answer (their dice read face by face) against the
##               block now standing, the bot's own health, what was set up for later. A hand that
##               leaves the bot dead is worth nothing at all.
##   a reroll    every way of keeping dice that a gem's trigger or a Birthstone tier would chase
##               is thrown a couple of times and played out; the best is taken if it beats
##               standing. The hand is aimed where it does best, never into a mirror.
##   the rail    a stone is worth what the whole rail gains by it (`rail_value`: the rail played
##               out on sample hands, chased the way its own gems would chase, against the
##               creatures of the mine it is in), so a gem that completes what is already set is
##               worth more than a stranger, and a gem that feeds another is seen to.
##   the kit     the rail it goes down with is picked the same way, from a small vault drawn for
##               the job (`choose_kit`): one stone of it is set whatever it is worth (the plant,
##               so every gem is played and not only the ones the bot likes), the rest are the
##               ones the rail gains most by.
##   the mine    fights when healthy, elites when very healthy, rock when it is cheap, the stall
##               to read raw stones and buy what the rail gains by, rest when hurt. Dice are
##               worked only by the spoils, and only when the rail plays better for it.
##
## It looks one turn ahead and no further: it does not plan a fight, hoard for a Warden or
## build toward a combination it has not been dealt. It is a decent player, not a perfect one,
## and it is the same player for every delver, stone and gem, which is what lets one be read
## against another.

const PID: String = "a"
## The steps of a turn that are the bot's own rail firing.
const OWN_STEPS: Array = ["rail_begin", "gem_fire", "gem_fizzle", "birthstone", "rail_end"]
## Who Poison and Burn the Birthstone lays on its own owner are owed to (a Bloodroot's Tap).
const BIRTH_VENOM: String = "*birth"
const ACTION_LIMIT: int = 80000
## A fight nobody is winning is given up: the run is counted as fallen there.
const TURN_LIMIT: int = 60
## How many times a way of rerolling is thrown before it is judged, and how many are tried.
const REROLL_THROWS: int = 2
const REROLL_WAYS: int = 2
## A rail is played on this many hands for each of this many ways of chasing.
const RAIL_HANDS: int = 3
const RAIL_WAYS: int = 2
## How many of a full rail's gems a newcomer is tried in place of (the ones it leans on
## least), and how many of the vault's stones are weighed for each socket of the kit.
const SWAP_TRIES: int = 2
const KIT_TRIES: int = 2
## What a point of each thing is worth beside a point of health taken off a creature.
const POISON_WORTH: float = 1.6
const GOLD_WORTH: float = 0.04
const HEAL_WORTH: float = 0.8
const HURT_WORTH: float = 1.2
## What a hand that kills the bot is worth: nothing a hand does is worth the run.
const GRAVE: float = 1000000.0
## What the bot's own standing statuses are worth a stack, and a creature's afflictions.
const BUFF_WORTH: Dictionary = {"regeneration": 1.5, "spikes": 0.4, "ward": 5.0, "strength": 3.0, "charged": 1.5, "envenom": 2.0, "lifeline": 0.3, "reflect": 4.0}
const HEX_WORTH: Dictionary = {"curse": 2.0, "marked": 2.0, "dulled": 2.0, "clouded": 2.5, "festering": 1.0, "scorched": 1.0}
## A creature made too tough to fall, so a rail weighed against it shows everything it has.
const ARENA_HEALTH: int = 40

var job: Dictionary = {}
var state: Dictionary = {}
var mine_key: String = ""
var rng := RandomNumberGenerator.new()
var row: Dictionary = {}
var fight: Dictionary = {}
var stones: Dictionary = {}
var gem_turns: Dictionary = {}
var gem_fights: Dictionary = {}
## Health each stone cost its own owner (a price it asks), by stone id.
var gem_costs: Dictionary = {}
var birth: Dictionary = {}
var offered: Dictionary = {}
var taken: Dictionary = {}
var refusals: Dictionary = {}
var idle: int = 0
var bench_mark: String = ""
var bench_refused: Dictionary = {}
var stall_mark: String = ""
var stall_bought: int = 0
var value_cache: Dictionary = {}
var lean_cache: Dictionary = {}
var arenas: Dictionary = {}
var hand_cache: Dictionary = {}
var goal_depth: int = 0
var goal_wardens: int = 0
var kit_notes: Dictionary = {}
## Where the time went, in microseconds and calls: {name: [usec, calls]}.
var prof: Dictionary = {}
## Who is asking for a rail to be weighed, for the profile.
var why: String = ""

func clock(name: String, since: int) -> void:
	if not prof.has(name):
		prof[name] = [0, 0]
	prof[name][0] += Time.get_ticks_usec() - since
	prof[name][1] += 1

# --- the job -----------------------------------------------------------------------------------

func config_for(the_job: Dictionary) -> Dictionary:
	## The run a job asks for: the delver, the mine, the stone worn, and the rail they go down with.
	job = the_job
	rng.seed = hash("delve-bot:%d:%s" % [int(job.get("seed", 0)), str(job.get("character", ""))])
	var character: String = str(job.get("character", DeepContent.starter_character()))
	mine_key = str(job.get("mine", DeepContent.starter_mine()))
	var def: Dictionary = DeepContent.character(character)
	var dice: Array = []
	var refs: Array = def.get("dice", [])
	for index in range(refs.size()):
		dice.append(DeepForge.die_from(refs[index], "bowl%d" % index))
	var sockets: Array = def.get("sockets", [])
	var open: int = clampi(int(job.get("sockets", open_sockets(mine_key))), 0, sockets.size())
	var rail: Array = []
	var listed: Variant = job.get("kit", null)
	if listed is Array:
		for index in range(sockets.size()):
			var entry: Variant = listed[index] if index < listed.size() else null
			rail.append(kit_stone(str(entry[0]), index, int(entry[1]), int(entry[2]), int(entry[3])) if entry is Array and entry.size() >= 4 else null)
	else:
		rail = choose_kit(character, dice, sockets, open)
	return {"seed": int(job.get("seed", 1)), "run_id": "delve_%s" % str(job.get("id", "run")), "mine": mine_key, "hazard": int(job.get("hazard", 0)),
		"players": [{"id": PID, "name": "Delve", "character": character, "rail": rail, "dice": dice, "sockets": open, "birthstone": str(job.get("birthstone", ""))}]}

static func open_sockets(mine: String) -> int:
	## How many sockets a player has opened by the time they dig a mine: the three everyone
	## starts with, and one more bought for each mine down, until the rail is whole.
	return int(DeepContent.constant("starting_rail_cap", 3)) + maxi(0, DeepContent.mine_tier(mine) - 1)

static func kit_stone(skill: String, index: int, carat: int, cut: int, clarity: int) -> Dictionary:
	var made: Dictionary = DeepStone.make(skill, carat, cut, clarity, [], {"source": "kit"}, "kit%d" % index)
	made.appraised = true
	made.inclusions_revealed = true
	return made

func choose_kit(character: String, dice: Array, sockets: Array, open: int) -> Array:
	why = "kit"
	## The rail a player of this mine would bring from the vault. The vault is a handful of
	## stones the mines above could have given them (twice as many as they have sockets open,
	## and two more), at the mine's own carats, drawn from the seed and the delver alone, never
	## the Birthstone: a delver's three stones choose from the same vault. One of them is set
	## whatever it is worth (the plant, also drawn before the Birthstone is looked at); the
	## other sockets take, one at a time, the stone the rail gains most by, as the loadout at
	## home allows it (a socket takes only a stone it shows).
	var mine: Dictionary = DeepContent.mine(mine_key)
	var carat: int = int(job.get("carat", int(mine.get("carat", {}).get("soft", 5))))
	var cut: int = int(job.get("cut", 3))
	var clarity: int = int(job.get("clarity", DeepContent.clear_index()))
	var draws := RandomNumberGenerator.new()
	draws.seed = hash("delve-kit:%d:%s:%s" % [int(job.get("seed", 1)), character, mine_key])
	var open_list: Array = sockets.slice(0, open)
	var fits_any: Callable = func(skill: String) -> bool:
		return open_list.any(func(socket: Variant) -> bool: return DeepStone.fits({"skill": skill}, str(socket)))
	var pool: Array = DeepForge.skill_pool(mine).filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) != DeepContent.OPAL and fits_any.call(k))
	var vault: Array = []
	var size: int = int(job.get("vault", 2 * open + 2))
	var left: Array = pool.duplicate()
	while vault.size() < size and not left.is_empty():
		var at: int = draws.randi_range(0, left.size() - 1)
		vault.append(str(left[at]))
		left.remove_at(at)
	## Now and then an opal lies in the vault too, as it does for anyone who has beaten a Warden.
	var opals: Array = DeepForge.opal_pool().filter(fits_any)
	if draws.randf() * 100.0 < float(job.get("opal_pct", 30.0)) and not opals.is_empty():
		vault.append(str(opals[draws.randi_range(0, opals.size() - 1)]))
	var plant: String = str(job.get("plant", ""))
	if plant.is_empty() and not vault.is_empty() and draws.randf() * 100.0 < float(job.get("plant_pct", 100.0)):
		plant = str(vault[draws.randi_range(0, vault.size() - 1)])
	elif not plant.is_empty() and not vault.has(plant):
		vault.append(plant)
	var unit: Dictionary = DeepBattle.make_player(PID, "Delve", character, sockets.map(func(_s: Variant) -> Variant: return null), dice, -1, [], str(job.get("birthstone", "")))
	var place: Callable = func(skill: String) -> int:
		## The open socket this skill would be set in at home, or -1.
		var stone: Dictionary = {"skill": skill}
		var opal: bool = str(DeepContent.skill(skill).get("color", "")) == DeepContent.OPAL
		var order: Array = range(open)
		if opal:
			order.reverse()
		for pass_ in [0, 1]:
			for index in order:
				if unit.rail[index] != null or not DeepStone.fits(stone, str(sockets[index])):
					continue
				## A plain gem takes a socket of its own color before it takes a Rainbow.
				if pass_ == 0 and not opal and DeepContent.is_rainbow(str(sockets[index])):
					continue
				return int(index)
		return -1
	var set_count: int = 0
	if not plant.is_empty():
		var at: int = place.call(plant)
		if at >= 0:
			unit.rail[at] = kit_stone(plant, at, carat, cut, clarity)
			vault.erase(plant)
			set_count += 1
		else:
			plant = ""
	## What each stone of the vault does alone on this rail: the few that do most are the ones
	## weighed for a socket, with every opal (an opal alone does nothing: it wants company).
	var alone: Dictionary = {}
	for skill in vault:
		var at: int = place.call(str(skill))
		if at < 0:
			continue
		var only: Dictionary = unit.duplicate(true)
		only.rail[at] = kit_stone(str(skill), at, carat, cut, clarity)
		alone[str(skill)] = rail_value(only, true)
	while set_count < open and not vault.is_empty():
		var best_skill: String = ""
		var best_at: int = -1
		var best_value: float = -INF
		var tried: Array = vault.filter(func(k: String) -> bool: return alone.has(k) and place.call(k) >= 0)
		tried.sort_custom(func(a: String, b: String) -> bool: return float(alone[a]) > float(alone[b]) if float(alone[a]) != float(alone[b]) else a < b)
		## The few that do most alone, every opal, and one of the rest in turn: a gem that does
		## nothing alone may be the one that completes what is set.
		var rest: Array = tried.slice(KIT_TRIES)
		var shortlist: Array = tried.slice(0, KIT_TRIES) + rest.filter(func(k: String) -> bool: return str(DeepContent.skill(k).get("color", "")) == DeepContent.OPAL)
		if not rest.is_empty():
			var extra: String = str(rest[set_count % rest.size()])
			if not shortlist.has(extra):
				shortlist.append(extra)
		for skill in shortlist:
			var at: int = place.call(str(skill))
			if at < 0:
				continue
			var with: Dictionary = unit.duplicate(true)
			with.rail[at] = kit_stone(str(skill), at, carat, cut, clarity)
			var value: float = rail_value(with)
			if value > best_value:
				best_value = value
				best_skill = str(skill)
				best_at = at
		if best_skill.is_empty():
			break
		unit.rail[best_at] = kit_stone(best_skill, best_at, carat, cut, clarity)
		vault.erase(best_skill)
		set_count += 1
	kit_notes = {"plant": plant, "left": vault.duplicate()}
	return unit.rail

# --- a run -----------------------------------------------------------------------------------

func play(the_job: Dictionary) -> Dictionary:
	## One run, from the shaft head to the mine's boss, the bot's fall, or the action limit.
	var started: int = Time.get_ticks_msec()
	var config: Dictionary = config_for(the_job)
	state = DeepDescent.new_run(config)
	var mine: Dictionary = DeepContent.mine(str(state.mine))
	goal_wardens = int(job.get("rift_wardens", 2))
	goal_depth = int(mine.get("depth", 0)) if not bool(mine.get("endless", false)) else goal_wardens * maxi(1, int(mine.get("warden_every", 8)))
	row = {"id": str(job.get("id", "")), "c": str(job.get("character", "")), "w": str(job.get("birthstone", "")), "mine": str(state.mine), "seed": int(job.get("seed", 0)),
		"hazard": int(job.get("hazard", 0)), "goal": goal_depth, "kit": [], "plant": str(kit_notes.get("plant", "")), "spare": kit_notes.get("left", []), "fights": [], "outcome": ""}
	for stone in DeepStone.rail_stones(state.players[0]):
		row.kit.append([str(stone.skill), int(stone.carat), int(stone.cut), int(stone.clarity)])
		note_stone(stone, "kit")
	birth = {"fires": 0, "turns": 0, "damage": 0, "block": 0, "healed": 0, "hurt": 0, "tiers": {}}
	var actions: int = 0
	while not finished() and actions < ACTION_LIMIT:
		actions += 1
		var before: int = int(state.seq)
		advance()
		if int(state.seq) == before:
			idle += 1
			if idle >= 6:
				row.outcome = "stuck"
				row.stuck = "%s/%s depth %d" % [str(state.phase), str(state.chamber.get("kind", "")), int(state.depth)]
				break
		else:
			idle = 0
	return summary(actions, Time.get_ticks_msec() - started)

func won() -> bool:
	## The mine's boss is down (an endless mine: so many of its Wardens), and the hoard is taken.
	if str(state.phase) == "hoard":
		return false
	var mine: Dictionary = DeepContent.mine(str(state.mine))
	if bool(mine.get("endless", false)):
		return state.records.wardens.size() >= goal_wardens
	return bool(state.records.boss) or not state.get("mines_done", []).is_empty()

func finished() -> bool:
	return str(state.phase) == "over" or won()

func summary(actions: int, ms: int) -> Dictionary:
	var unit: Dictionary = state.players[0]
	## A run given up on (a fight nobody was winning) ends in the salvage room: it fell there.
	if bool(row.get("stalemate", false)) and str(row.outcome).is_empty() and not won():
		row.outcome = "fallen"
	if str(row.outcome).is_empty():
		row.outcome = "conquered" if won() else (str(state.outcome) if str(state.phase) == "over" else "limit")
	var depth: int = int(state.depth)
	row.depth = depth
	## How far down it got, as a share of the way to the boss: the floors it left behind it.
	row.progress = 1.0 if str(row.outcome) == "conquered" else snappedf(clampf(float(maxi(0, depth - 1)) / float(maxi(1, goal_depth)), 0.0, 0.99), 0.001)
	row.wardens = state.records.wardens.duplicate()
	row.hp = int(unit.hp)
	row.max_hp = int(unit.max_hp)
	row.ore = int(unit.ore)
	row.rail = DeepStone.rail_stones(unit).map(func(s: Dictionary) -> Array: return [str(s.skill), int(s.carat), int(s.cut), int(s.clarity)])
	row.dice = unit.dice.map(func(d: Dictionary) -> String: return str(d.get("shape", "")))
	var tally: Dictionary = DeepBattle.stats_of(unit)
	row.stats = {"damage": int(tally.get("damage", 0)), "overkill": int(tally.get("overkill", 0)), "taken": int(tally.get("taken", 0)), "blocked": int(tally.get("blocked", 0)),
		"block": int(tally.get("block", 0)), "healed": int(tally.get("healed", 0)), "turns": int(tally.get("turns", 0)), "rerolls": int(tally.get("rerolls", 0)),
		"resonance": int(tally.get("resonance", 0)), "stones": int(tally.get("stones", 0)), "ore": int(tally.get("ore", 0))}
	## Every gem that sat on the rail, by the skill it fired as: what it did and how long it sat.
	var gems: Dictionary = {}
	for id in gem_turns:
		var known: Dictionary = stones.get(id, {})
		var skill: String = str(known.get("skill", ""))
		if skill.is_empty():
			continue
		var did: Dictionary = tally.get("gems", {}).get(id, {})
		if not gems.has(skill):
			gems[skill] = {"turns": 0, "fights": 0, "fires": 0, "damage": 0, "block": 0, "healed": 0, "debuffs": 0, "ore": 0, "cost": 0, "best": 0, "carat": 0, "src": str(known.get("src", ""))}
		var entry: Dictionary = gems[skill]
		entry.turns += int(gem_turns[id])
		entry.cost += int(gem_costs.get(id, 0))
		entry.fights += int(gem_fights.get(id, 0))
		for key in ["fires", "damage", "block", "healed", "debuffs", "ore"]:
			entry[key] += int(did.get(key, 0))
		entry.best = maxi(int(entry.best), int(did.get("best", 0)))
		entry.carat = maxi(int(entry.carat), int(known.get("carat", 0)))
	row.gems = gems
	birth.fires = int(tally.get("birthstone", 0))
	row.birth = birth
	row.offered = offered
	row.taken = taken
	if not refusals.is_empty():
		row.refusals = refusals
	row.actions = actions
	row.ms = ms
	if bool(job.get("prof", false)):
		row.prof = prof
	return row

func note_stone(stone: Dictionary, src: String) -> void:
	## What the bot knows a stone by, kept by id for the run's end.
	var id: String = str(stone.get("id", ""))
	if id.is_empty() or DeepStone.is_geode(stone):
		return
	var known: Dictionary = stones.get(id, {})
	stones[id] = {"skill": str(stone.get("skill", "")), "carat": int(stone.get("carat", 0)), "src": str(known.get("src", src))}

func bump(book: Dictionary, key: String, by: int = 1) -> void:
	book[key] = int(book.get(key, 0)) + by

func act(kind: String, fields: Dictionary = {}) -> bool:
	var command: Dictionary = fields.duplicate()
	command.kind = kind
	var result: Dictionary = DeepDescent.command(state, PID, command)
	if bool(result.get("ok", false)):
		return true
	bump(refusals, "%s: %s" % [kind, str(result.get("error", ""))])
	return false

func advance() -> void:
	var unit: Dictionary = state.players[0]
	if not unit.get("twin", {}).is_empty():
		settle_twin(unit)
		return
	match str(state.phase):
		"grubstake":
			stake(unit)
		"tunnels":
			if not DeepDescent.spoils_of(state, PID).is_empty():
				take_spoils(unit)
			elif not bench(unit):
				vote(unit)
		"chamber":
			var kind: String = str(state.chamber.get("kind", ""))
			if DeepDescent.in_battle(state):
				fight_step()
			elif kind in DeepDescent.ROCK_ROOMS:
				dig(unit)
			elif kind == "merchant":
				shop(unit)
			elif kind == "altar":
				act("altar_leave")
			else:
				card(unit)
		"landing":
			landing(unit)
		"hoard":
			hoard(unit)
		"salvage":
			act("ready")

# --- the shaft head ----------------------------------------------------------------------------

const STAKE_WORTH: Dictionary = {"BAG_OF_GEMS": 90, "HEIRLOOM_POLISH": 80, "DEEP_PURSE": 55, "BAG_OF_DICE": 15, "ONE_MATERIAL": 12, "SMITHS_VOUCHER": 5,
	"PICK_STONE": 60, "RAW_STONE": 55, "FRAGILE_STONE": 45, "STAKE_CARAT": 50, "STAKE_CUT": 40,
	"HARDY": 50, "SOFT_ROCK": 45, "STEADY_HANDS": 45, "STAKED": 35, "HAMMERED": 20,
	"REWARD_ALL": 85, "REWARD_CARATS": 60, "REWARD_HP": 55, "REWARD_ORE": 30, "REWARD_WILD": 15,
	"COST_HP": - 25, "COST_WOUND": - 20, "COST_CHIPPED": - 20}

func stake(unit: Dictionary) -> void:
	why = "stake"
	for offer in unit.get("temps", []):
		if int(offer.get("chosen", -1)) < 0:
			act("temporary", {"index": offer.index, "pick": 0})
			return
	var offers: Array = state.get("grubstake", {}).get("offers", {}).get(PID, []).duplicate()
	var stake_worth: Callable = func(offer: Dictionary) -> int:
		var total: int = 0
		for key in offer.get("boons", []):
			total += int(STAKE_WORTH.get(str(key), 20))
		return total
	offers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(stake_worth.call(a)) > int(stake_worth.call(b)))
	for offer in offers:
		if act("stake", {"offer": offer.id, "payload": stake_payload(unit, offer)}):
			row.stake = offer.get("boons", []).duplicate()
			for stone in unit.haul:
				note_stone(stone, "stake")
			value_cache.clear()
			return
	for offer in offers:
		if act("stake", {"offer": offer.id, "payload": {}}):
			return

func stake_payload(unit: Dictionary, offer: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	var needs: Array = offer.get("needs", [])
	var picks: Array = offer.get("picks", [])
	if needs.has("pick"):
		## A raw stone is a color and a size: the biggest. Anything else, the first.
		var best: int = 0
		if str(offer.get("pick_kind", "")) == "stone":
			for index in range(picks.size()):
				if DeepStone.shown_carat(picks[index]) > DeepStone.shown_carat(picks[best]):
					best = index
		payload.pick = best
	if needs.has("picks"):
		## A Bag of Gems: the stones the rail gains most by.
		var order: Array = range(picks.size())
		var gains: Dictionary = {}
		for index in order:
			gains[index] = float(best_fit(unit, picks[index]).gain)
		order.sort_custom(func(a: int, b: int) -> bool: return float(gains[a]) > float(gains[b]))
		payload.picks = order.slice(0, int(offer.get("take", 1)))
	if needs.has("charges"):
		var charges: Dictionary = offer.get("charges", {"kind": "resize", "count": 1})
		var chosen: Array = []
		## One charge a die, the smallest first, for as many as will take one.
		var dice: Array = unit.dice.filter(func(d: Dictionary) -> bool: return DeepBoons.can_charge(d, str(charges.kind)))
		dice.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DeepDice.size_of(str(a.shape)) < DeepDice.size_of(str(b.shape)))
		for die in dice:
			if chosen.size() < int(charges.get("count", 1)):
				chosen.append(str(die.id))
		payload.dice = chosen
	if needs.has("swaps"):
		payload.swaps = {}
	return payload

# --- twins -------------------------------------------------------------------------------------

func settle_twin(unit: Dictionary) -> void:
	why = "twin"
	## A second stone of a skill already held: the better one stays; with the fee to spare, the
	## two are fused.
	var pending: Dictionary = unit.twin
	var stone: Dictionary = DeepOddities.find_stone(unit, str(pending.get("stone", "")))
	var other: Dictionary = DeepOddities.find_stone(unit, str(pending.get("other", "")))
	var choices: Array = ["toss"]
	if not stone.is_empty() and not other.is_empty():
		var better: bool = int(DeepStone.grade(stone).score) > int(DeepStone.grade(other).score)
		if int(unit.get("ore", 0)) >= DeepOddities.fuse_cost() + 40 and int(stone.get("cut", 0)) >= int(other.get("cut", 0)) - 1:
			choices = ["fuse", "swap" if better else "toss", "toss"]
		elif better:
			choices = ["swap", "toss"]
	for choice in choices:
		if act("twin", {"choice": choice}):
			bump(row, "twins_" + str(choice))
			for held in DeepStone.rail_stones(unit) + unit.haul:
				note_stone(held, "found")
			bench_mark = ""
			return
	act("abandon")

# --- the bench ---------------------------------------------------------------------------------

func raw_stones(unit: Dictionary) -> Array:
	return unit.haul.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and not DeepStone.is_geode(s))

func loose_stones(unit: Dictionary) -> Array:
	## Read stones in the bag that could be set.
	return unit.haul.filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)) and not DeepStone.is_geode(s))

func bench(unit: Dictionary) -> bool:
	why = "bench"
	## One move toward the rail the bot wants. True when it made one.
	if not DeepDescent.bench_open(state):
		return false
	var mark: String = bench_signature(unit)
	if mark == bench_mark:
		return false
	for stone in loose_stones(unit):
		note_stone(stone, "found")
		var id: String = str(stone.id)
		if bench_refused.has(id):
			continue
		if DeepStone.is_slotless(stone):
			## A Void gem rides a socket: the last one with a gem in it.
			var host: int = -1
			for index in range(unit.rail.size()):
				if unit.rail[index] is Dictionary:
					host = index
			if host >= 0 and act("socket", {"stone_id": id, "index": host}):
				return true
			bench_refused[id] = true
			continue
		var fit: Dictionary = best_fit(unit, stone)
		if int(fit.socket) >= 0 and float(fit.gain) > 0.02:
			if act("socket", {"stone_id": id, "index": int(fit.socket)}):
				return true
		## Weighed once and left in the bag: it is not weighed again this run.
		bench_refused[id] = true
	if tidy(unit):
		return true
	bench_mark = bench_signature(unit)
	return false

func bench_signature(unit: Dictionary) -> String:
	var parts: Array = []
	for stone in unit.rail:
		parts.append(stone_key(stone) if stone is Dictionary else "-")
	for stone in unit.haul:
		if bool(stone.get("appraised", false)) and not DeepStone.is_geode(stone):
			parts.append(stone_key(stone))
	return "|".join(parts)

func stone_key(stone: Dictionary) -> String:
	return "%s:%s:%d:%d:%d:%s" % [str(stone.get("id", "")), str(stone.get("skill", "")), int(stone.get("carat", 0)), int(stone.get("cut", 0)), int(stone.get("clarity", 0)), ",".join(stone.get("inclusions", []))]

func empty_socket(unit: Dictionary, stone: Dictionary) -> int:
	## The empty socket this stone would take: an opal the last one, anything else the first
	## of its own color, else the first that shows it, else the first there is.
	var open: Array = []
	for index in range(unit.rail.size()):
		if unit.rail[index] == null:
			open.append(index)
	if open.is_empty():
		return -1
	if DeepStone.is_opal(stone):
		return int(open.back())
	for index in open:
		if not DeepContent.is_rainbow(str(unit.sockets[index])) and DeepStone.shows(stone, str(unit.sockets[index])):
			return int(index)
	for index in open:
		if DeepStone.shows(stone, str(unit.sockets[index])):
			return int(index)
	return int(open[0])

func best_fit(unit: Dictionary, stone: Dictionary) -> Dictionary:
	## Where this stone would go and what the rail would gain by it, as a share of what the
	## rail does now: {socket, gain}. An empty socket if there is one; else the place of
	## whichever of the gems the rail misses least.
	if stone.is_empty() or not bool(stone.get("appraised", false)) or DeepStone.is_geode(stone):
		return {"socket": - 1, "gain": 0.0}
	## One of each skill: a stone whose skill is already set is a twin, not a newcomer.
	for held in DeepStone.rail_stones(unit):
		if str(held.get("skill", "")) == str(stone.get("skill", "")) and str(held.get("id", "")) != str(stone.get("id", "")):
			return {"socket": - 1, "gain": 0.0}
	var now: float = rail_value(unit)
	var open: int = empty_socket(unit, stone)
	if open >= 0:
		var with: Dictionary = unit.duplicate(true)
		with.rail[open] = stone.duplicate(true)
		return {"socket": open, "gain": gain_over(rail_value(with), now)}
	## A full rail: in place of the gems it leans on least.
	var best: Dictionary = {"socket": - 1, "gain": 0.0}
	var lean: Dictionary = lean_cache.get(value_key(unit), {})
	var order: Array = range(unit.rail.size()).filter(func(i: int) -> bool: return unit.rail[i] is Dictionary and not DeepStone.is_locked(unit.rail[i]))
	order.sort_custom(func(a: int, b: int) -> bool: return float(lean.get(a, 0.0)) < float(lean.get(b, 0.0)) if float(lean.get(a, 0.0)) != float(lean.get(b, 0.0)) else a < b)
	for index in order.slice(0, SWAP_TRIES):
		var swapped: Dictionary = unit.duplicate(true)
		swapped.rail[index] = stone.duplicate(true)
		var gain: float = gain_over(rail_value(swapped), now)
		if gain > float(best.gain):
			best = {"socket": index, "gain": gain}
	return best

func gain_over(with: float, now: float) -> float:
	return (with - now) / maxf(1.0, now)

func tidy(unit: Dictionary) -> bool:
	why = "tidy"
	## The rail's order, one swap at a time: every opal behind the gems that ring it awake, and
	## a gem moved to a socket that shows it when the one it sits in does not.
	var rail: Array = unit.rail
	var last_plain: int = -1
	var first_opal: int = -1
	for index in range(rail.size()):
		if not rail[index] is Dictionary:
			continue
		if DeepStone.is_opal(rail[index]):
			if first_opal < 0:
				first_opal = index
		else:
			last_plain = index
	if first_opal >= 0 and last_plain > first_opal:
		if try_swap(unit, last_plain, first_opal):
			return true
	for index in range(rail.size()):
		var stone: Variant = rail[index]
		if not stone is Dictionary or DeepStone.is_opal(stone) or DeepStone.shows(stone, str(unit.sockets[index])):
			continue
		for other in range(rail.size()):
			if other == index or not DeepStone.shows(stone, str(unit.sockets[other])):
				continue
			var there: Variant = rail[other]
			if there == null or (there is Dictionary and not DeepStone.is_opal(there) and not DeepStone.shows(there, str(unit.sockets[other])) and DeepStone.shows(there, str(unit.sockets[index]))):
				if try_swap(unit, index, other):
					return true
	return false

func try_swap(unit: Dictionary, from: int, to: int) -> bool:
	## Move the gem in `from` to `to` (whatever is there changes places with it), if the rail
	## reads better for it.
	var stone: Variant = unit.rail[from]
	if not stone is Dictionary or DeepStone.is_locked(stone):
		return false
	if unit.rail[to] is Dictionary and DeepStone.is_locked(unit.rail[to]):
		return false
	var swapped: Dictionary = unit.duplicate(true)
	swapped.rail[to] = unit.rail[from]
	swapped.rail[from] = unit.rail[to]
	if rail_value(swapped) < rail_value(unit) * 1.005:
		return false
	if act("socket", {"stone_id": str(stone.id), "index": to}):
		return true
	return false

# --- what a rail is worth ------------------------------------------------------------------------

func rail_value(unit: Dictionary, light: bool = false) -> float:
	## What this rail, these dice and this Birthstone do on a turn: played out for real on sample
	## hands, thrown and chased the way the rail's own gems would chase them (the best of a few
	## ways of chasing), against creatures of the mine the run is in (`arena`). Each hand is
	## read twice: against the room as it is, where overkill is wasted and what the survivors
	## throw back has to be stopped, and against the next Warden, where only what lands counts.
	## The same hands for every rail weighed with the same dice, so one rail is read against
	## another and not against the luck of the throw.
	## `light` is a quick look, on fewer hands: enough to sift a vault, never kept.
	var key: String = value_key(unit)
	if value_cache.has(key):
		return float(value_cache[key])
	var t0: int = Time.get_ticks_usec()
	var ring: Dictionary = arena(unit)
	var me: Dictionary = unit.duplicate(true)
	me.merge({"gold": 0, "quality_bonus": 0, "stone_drops": 0, "pot": 0, "gem_buffs": {}, "rank_buff": {"carat": 0, "cut": 0}, "pyrite_delta": 0, "hand": [],
		"hp": int(float(unit.max_hp) * 0.7), "block": 0, "target": str(ring.aim)}, true)
	DeepStone.flatten_rail(me)
	me.initial_rail = me.rail.duplicate(true)
	var b: Dictionary = ring.hall
	b.players = [me]
	var rerolls: int = int(DeepContent.constant("rerolls", 2)) + (int(me.passive.get("amount", 1)) if str(me.get("passive", {}).get("kind", "")) == "extra_reroll" else 0)
	var best: float = -INF
	var lean: Dictionary = {}
	for way in ways_of(me, 1 if light else RAIL_WAYS):
		var sum: float = 0.0
		var leaned: Dictionary = {}
		var hands: Array = sample_hands(me, str(way), rerolls)
		if light:
			hands = hands.slice(0, 2)
		for hand in hands:
			var after: Dictionary = play_rail(b, hand, str(ring.aim), 0, leaned)
			sum += arena_worth(b, after, ring)
		var mean: float = sum / float(maxi(1, hands.size()))
		if mean > best:
			best = mean
			lean = leaned
	b.players = []
	## What the rail leans on each socket for, a rider's work counted with the gem it rides.
	var by_socket: Dictionary = {}
	for flat in lean:
		var socket: int = int(me.places[flat].get("socket", flat)) if me.has("places") and int(flat) < me.places.size() else int(flat)
		by_socket[socket] = float(by_socket.get(socket, 0.0)) + float(lean[flat])
	if light:
		clock("rail_light", t0)
		return best
	if value_cache.size() > 4000:
		value_cache.clear()
		lean_cache.clear()
	value_cache[key] = best
	lean_cache[key] = by_socket
	clock("rail_value", t0)
	clock("rail:" + why, t0)
	return best

func arena(unit: Dictionary) -> Dictionary:
	## The room a rail is weighed in, laid out once for each stretch of the mine: its ordinary
	## creatures a floor or two below where the run stands (the three its rock breeds most
	## there), as a fight would make them but too tough to fall, so a rail shows everything it
	## has. What comes back is {hall: the room (a fight with nobody in it yet), aim: the
	## creature a rail is aimed at, real: {creature: the health it would really have}, gate:
	## what the next Warden down is expected to throw in a turn}.
	var mine: Dictionary = DeepContent.mine(mine_key)
	var bottom: int = int(mine.get("depth", 0)) if int(mine.get("depth", 0)) > 0 else 2 * maxi(1, int(mine.get("warden_every", 8)))
	var running: bool = not state.is_empty()
	var at: int = clampi(int(state.get("depth", 0)) + 2, 1, bottom) if running else maxi(2, bottom / 3)
	var key: String = str(at / 4)
	if arenas.has(key):
		return arenas[key]
	var band: Dictionary = DeepForge.band_for(mine, at).get("creatures", {})
	var keys: Array = band.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(band[a]) > float(band[b]) if float(band[a]) != float(band[b]) else a < b)
	keys = keys.slice(0, 2 if at < 5 else 3)
	var dice := RandomNumberGenerator.new()
	dice.seed = 1
	var creatures := RandomNumberGenerator.new()
	creatures.seed = 1
	var hall: Dictionary = DeepBattle.begin([], keys, {"depth": at, "threat": at, "scale": DeepDescent.creature_scale(mine, at, true)}, dice, creatures)
	var real: Dictionary = {}
	for foe in hall.enemies:
		real[str(foe.id)] = int(foe.hp)
		foe.hp = int(foe.hp) * ARENA_HEALTH
		foe.max_hp = int(foe.hp)
		foe.hp_at_turn = int(foe.hp)
	## The next Warden down: the run's own schedule says where and who; before a run, the mine's first.
	var warden: String = ""
	var warden_at: int = at
	if running:
		for depth in range(int(state.depth) + 1, int(state.depth) + 41):
			if DeepDescent.run_is_warden(state, depth):
				warden = DeepDescent.warden_key(state, depth)
				warden_at = depth
				break
	if warden.is_empty():
		var listed: Array = mine.get("wardens", [])
		warden = str(listed[0]) if not listed.is_empty() else str(mine.get("boss", ""))
		var depths: Array = mine.get("warden_depths", [])
		warden_at = int(depths[0]) if not depths.is_empty() else maxi(1, int(mine.get("warden_every", 8)))
	var gate: float = 0.0
	if not warden.is_empty():
		var hall_gate: Dictionary = DeepBattle.begin([], [warden], {"depth": warden_at, "threat": warden_at, "scale": DeepDescent.creature_scale(mine, warden_at, false), "warden": true}, dice, creatures)
		for foe in hall_gate.enemies:
			gate += _foe_blow(hall_gate, foe, 0)
	var made: Dictionary = {"hall": hall, "real": real, "aim": str(hall.enemies[0].id) if not hall.enemies.is_empty() else "", "gate": gate}
	if arenas.size() > 40:
		arenas.clear()
	arenas[key] = made
	return made

func arena_worth(b: Dictionary, after: Dictionary, ring: Dictionary) -> float:
	## What a hand played in the arena was worth: half as the room would have it, half as the
	## next Warden would.
	var me0: Dictionary = b.players[0]
	var me1: Dictionary = after.players[0]
	if int(me1.hp) <= 0 or bool(me1.get("downed", false)):
		return -1000.0
	var landed: float = 0.0
	var thrown: float = 0.0
	var coming: float = 0.0
	var later: float = 0.0
	var memo: Dictionary = ring
	for foe0 in b.enemies:
		var foe1: Dictionary = DeepBattle.enemy(after, str(foe0.id))
		var loss: float = float(int(foe0.hp) - maxi(0, int(foe1.get("hp", 0))))
		var stood: float = float(ring.real.get(str(foe0.id), int(foe0.hp)))
		thrown += loss
		landed += minf(loss, stood)
		var venom: float = float(maxi(0, int(foe1.get("statuses", {}).get("poison", 0)) - int(foe0.get("statuses", {}).get("poison", 0)))) * POISON_WORTH
		var hexes: float = 0.0
		for kind in HEX_WORTH:
			hexes += float(maxi(0, int(foe1.get("statuses", {}).get(kind, 0)) - int(foe0.get("statuses", {}).get(kind, 0)))) * float(HEX_WORTH[kind])
		thrown += venom + hexes
		if loss >= stood:
			continue
		landed += minf(venom, stood - loss) + minf(hexes, 20.0)
		coming += foe_blow(after, foe1, memo)
		later += loss * foe_answer(b, foe0, memo)
	var own: float = own_worth(me0, me1)
	var block: float = float(int(me1.get("block", 0)))
	var hp: float = maxf(1.0, float(int(me1.hp)))
	var room: float = landed + own - toll(maxf(0.0, coming + later - block), hp)
	var warden: float = thrown + own - toll(maxf(0.0, float(ring.gate) - block), hp)
	return 0.5 * room + 0.5 * warden

func toll(loss: float, hp: float) -> float:
	## What the health a turn is expected to cost is worth giving up: more the nearer it comes
	## to all of it.
	return loss * (1.0 + 2.0 * clampf(loss / hp, 0.0, 1.5)) + (150.0 if loss >= hp else 0.0)

func own_worth(me0: Dictionary, me1: Dictionary) -> float:
	## What a hand did for the bot itself: health, what it holds, what it set standing.
	var total: float = 0.0
	var healed: float = float(int(me1.hp) - int(me0.hp))
	total += healed * (HEAL_WORTH if healed >= 0.0 else HURT_WORTH)
	total += float(int(me1.max_hp) - int(me0.max_hp)) * 0.6
	total += float(DeepRules.pyrite(me1) - DeepRules.pyrite(me0)) * GOLD_WORTH
	for kind in BUFF_WORTH:
		total += float(int(me1.get("statuses", {}).get(kind, 0)) - int(me0.get("statuses", {}).get(kind, 0))) * float(BUFF_WORTH[kind])
	total += float(int(me1.get("granted_rerolls", 0)) - int(me0.get("granted_rerolls", 0))) * 3.0
	total += float(int(me1.get("stone_drops", 0)) - int(me0.get("stone_drops", 0))) * 10.0
	total += float(int(me1.get("sparkle", 0)) - int(me0.get("sparkle", 0))) * 0.2
	## Anything else that fired did something a count of health does not show: a face raised,
	## a die conjured, a stone read.
	total += float(int(me1.get("fired_count", 0))) * 0.4
	return total

func value_key(unit: Dictionary) -> String:
	return "%s#%s#%d" % [rail_key(unit), dice_key(unit.dice), int(unit.max_hp)]

func rail_key(unit: Dictionary) -> String:
	var parts: Array = []
	for stone in unit.rail:
		parts.append(stone_key(stone) if stone is Dictionary else "-")
	for line in unit.get("riders", []):
		if line is Array:
			for rider in line:
				parts.append("~" + stone_key(rider))
	return "|".join(parts)

func dice_key(dice: Array) -> String:
	var parts: Array = []
	for die in dice:
		parts.append("%s/%s/%s/%s" % [str(die.get("shape", "")), str(die.get("material", "")), str(die.get("pattern", "")), ",".join(die.get("faces", []).map(func(f: Dictionary) -> String: return "%d%s" % [int(f.get("value", 0)), str(f.get("kind", "plain")).left(1)]))])
	return ";".join(parts)

func sample_hands(me: Dictionary, way: String, rerolls: int) -> Array:
	## Hands thrown with these dice and chased this way, the same ones every time they are asked for.
	var key: String = "%s@%s@%d" % [dice_key(me.dice), way, rerolls]
	if hand_cache.has(key):
		return hand_cache[key]
	var throws := RandomNumberGenerator.new()
	throws.seed = hash("delve-hands:%d:%s" % [int(job.get("seed", 0)), way])
	var dice: Array = me.dice.duplicate(true)
	var whole: bool = DeepBattle.all_or_nothing(me)
	var hands: Array = []
	for _i in range(RAIL_HANDS):
		var rolls: Array = DeepDice.roll_hand(dice, throws)
		for _r in range(rerolls):
			var a: Dictionary = DeepHand.analyze(rolls)
			var ids: Array = reroll_ids(way, rolls, a)
			if whole:
				## All or Nothing: the whole bowl goes again while most of it would anyway.
				ids = DeepDice.rerollable(rolls) if ids.size() * 2 > rolls.size() else []
			if ids.is_empty():
				break
			rolls = DeepDice.reroll(rolls, dice, ids, throws)
		hands.append(rolls)
	if hand_cache.size() > 300:
		hand_cache.clear()
	hand_cache[key] = hands
	return hands

# --- playing a hand out ----------------------------------------------------------------------------

func play_rail(b: Dictionary, hand: Array, aim: String, rerolls_left: int, lean: Variant = null) -> Dictionary:
	## The party's half of a turn, played for real on a copy of the fight: what `rail_begin` sets
	## up, then every gem in order, whatever each of them queues (a replay, a repeat, a copy),
	## the Birthstone, and the rail's close. Coins and procs fall as the bot's own dice have
	## them. Nothing a creature does in answer is played: that is read off its dice. `lean`
	## collects, socket by socket, roughly what each gem did.
	var t0: int = Time.get_ticks_usec()
	var copy: Dictionary = b.duplicate(true)
	var unit: Dictionary = copy.players[0]
	unit.hand = hand.duplicate(true)
	unit.rerolls = rerolls_left
	unit.target = aim
	unit.firing_target = aim
	copy.phase = "resolving"
	if int(unit.get("statuses", {}).get("stun", 0)) > 0:
		clock("playout", t0)
		return copy
	unit.resonance = int(unit.get("initial_resonance", 0))
	unit.previous_fired = false
	unit.previous_amount = 0
	unit.previous_colors = []
	unit.previous_socket = -1
	unit.amplify = 1.0
	unit.nullify_next = false
	unit.cut_step_bonus = int(unit.passive.get("amount", 1)) if str(unit.get("passive", {}).get("kind", "")) == "first_gem_cut_step" else 0
	unit.fired_sockets = []
	unit.fizzled_sockets = []
	unit.tailings_paid = {}
	unit.repeat_next = 0
	unit.replaying = false
	unit.fired_count = 0
	unit.rail_plays = 0
	unit.damp_carry = 0
	unit.force_after = {}
	unit.fired_colors = []
	unit.gem_results = {}
	unit.resonance_mult = 1
	unit.second_act = false
	DeepBattle.numb_hand(copy, unit)
	var queue: Array = []
	for socket in range(unit.rail.size()):
		if unit.rail[socket] is Dictionary:
			queue.append({"kind": "gem", "unit": unit.id, "socket": socket})
	if not unit.get("birthstone", {}).is_empty():
		queue.append({"kind": "birthstone", "unit": unit.id})
	queue.append({"kind": "rail_end", "unit": unit.id})
	## A step that does nothing, left standing at the end: the rules never find the queue empty
	## and so never begin the next turn on the copy.
	queue.append({"kind": "skip", "unit": "", "why": "end"})
	copy.queue = queue
	var guard: int = 0
	var mover: int = -1
	var before: Array = _pulse(copy, unit) if lean is Dictionary else []
	while copy.queue.size() > 1 and str(copy.phase) == "resolving" and guard < 600:
		guard += 1
		var event: Dictionary = DeepBattle.step(copy, rng, rng)
		if lean is Dictionary and str(event.get("kind", "")) == "gem_fire":
			## A replay is the doing of the gem that asked for it.
			if not bool(event.get("replay", false)) or mover < 0:
				mover = int(event.get("socket", -1))
			var now: Array = _pulse(copy, unit)
			lean[mover] = float(lean.get(mover, 0.0)) + (float(before[0]) - float(now[0])) + (float(now[1]) - float(before[1])) * 0.6 + (float(now[2]) - float(before[2])) * HEAL_WORTH + (float(now[3]) - float(before[3])) * POISON_WORTH + 1.0
			before = now
	clock("playout", t0)
	return copy

func _pulse(b: Dictionary, me: Dictionary) -> Array:
	## The fight in four numbers: the creatures' health, the bot's block and health, the Poison on the creatures.
	var health: int = 0
	var poison: int = 0
	for foe in b.enemies:
		health += maxi(0, int(foe.hp))
		poison += int(foe.get("statuses", {}).get("poison", 0))
	return [health, int(me.get("block", 0)), int(me.hp), poison]

func turn_worth(b: Dictionary, after: Dictionary) -> float:
	## What a hand played out in a fight was worth, read off what it left: the health it took off
	## the creatures; what those still standing are expected to do in answer (their dice read
	## face by face, and what a Reflection would send back) against the block now up; the bot's
	## own health and what it set standing. A hand that leaves the bot dead is worth nothing.
	var me0: Dictionary = b.players[0]
	var me1: Dictionary = after.players[0]
	var landed: float = 0.0
	for foe0 in b.enemies:
		if int(foe0.hp) > 0:
			landed += float(int(foe0.hp) - maxi(0, int(DeepBattle.enemy(after, str(foe0.id)).get("hp", 0))))
	if int(me1.hp) <= 0 or bool(me1.get("downed", false)):
		return -GRAVE + landed
	var block: float = float(int(me1.get("block", 0)))
	var hp: float = maxf(1.0, float(int(me1.hp)))
	var coming: float = 0.0
	var later: float = 0.0
	var doom: float = 0.0
	var extras: float = 0.0
	var standing: int = 0
	var seen: Dictionary = {}
	for foe0 in b.enemies:
		seen[str(foe0.id)] = true
	for foe1 in after.enemies:
		if int(foe1.hp) <= 0:
			continue
		standing += 1
		coming += foe_blow(after, foe1, fight)
		if not seen.has(str(foe1.id)):
			continue
		var foe0: Dictionary = DeepBattle.enemy(b, str(foe1.id))
		var loss: float = float(int(foe0.hp) - int(foe1.hp))
		extras += minf(float(maxi(0, int(foe1.get("statuses", {}).get("poison", 0)) - int(foe0.get("statuses", {}).get("poison", 0)))) * POISON_WORTH, float(int(foe1.hp)))
		for kind in HEX_WORTH:
			extras += minf(float(maxi(0, int(foe1.get("statuses", {}).get(kind, 0)) - int(foe0.get("statuses", {}).get(kind, 0)))) * float(HEX_WORTH[kind]), 12.0)
		## What it is expected to send back for what it was dealt, if it gets to act: a Regent's
		## Reflection, a Prismarch's gathered light.
		var answer: float = foe_answer(b, foe0, fight)
		var since: float = float(maxi(0, int(foe1.get("hp_at_turn", int(foe0.hp))) - int(foe1.hp)))
		var back: float = since * answer
		var charging: Dictionary = foe1.get("charging", {})
		if bool(charging.get("store", false)):
			back = maxf(back, loss * float(DeepCreatures.damage_pct(foe1)) / 100.0)
		later += back
		doom += foe_doom(after, foe1, since, hp + block, fight)
	var total: float = landed + extras + own_worth(me0, me1)
	if standing == 0:
		## Nothing left to answer: the fight is won.
		return total + 40.0
	total -= toll(maxf(0.0, coming + later - block), hp)
	total -= minf(1.0, doom) * GRAVE * 0.1
	return total

# --- chasing a trigger -----------------------------------------------------------------------------

static func way_for(trigger: Dictionary, cut_step: int = 2) -> String:
	## What a player chasing this trigger keeps: the name of a way of rerolling (`reroll_ids`).
	match str(trigger.get("kind", "always")):
		"pair", "triple", "quad", "quint", "two_pair", "full_house", "set": return "sets"
		"straight": return "straight"
		"odd", "all_odd": return "odd"
		"even", "all_even": return "even"
		"distinct", "distinct_dominant": return "distinct"
		"skip_straight": return "skip"
		"value": return "value:" + ",".join(trigger.get("values", [1]).map(func(v: Variant) -> String: return str(int(v))))
		"at_most", "below", "low_count", "total_pct_at_most", "total_at_most", "crowns_at_most": return "low"
		"at_least", "high_pct_at_least", "total_pct_at_least", "crowns": return "high"
		"high_count": return "floor:%d" % int(trigger.get("value", 6))
		"total_window":
			var least: int = DeepPatterns.rung(trigger, 0)
			var most: int = int(trigger.get("max", -1))
			return "high" if most < 0 else "total:%d:%d" % [least, most]
		"scale": return "scale"
		"all_faces": return "faces"
		"rerolled": return "all"
		"always": return "low" if DeepPatterns.read_side(trigger, cut_step) == "low" else "high"
	return ""

func ways_of(me: Dictionary, most: int) -> Array:
	## The ways of chasing this rail is worth trying, the ones most of its gems share first, and
	## what the Birthstone's tiers want after them.
	var counts: Dictionary = {}
	for stone in DeepStone.rail_stones(me):
		var way: String = way_for(DeepStone.skill_of(stone).get("trigger", {}), int(stone.get("cut", 2)))
		if not way.is_empty():
			counts[way] = float(counts.get(way, 0.0)) + 1.0
	for tier in me.get("birthstone", {}).get("tiers", []):
		if bool(tier.get("penalty", false)):
			continue
		var way: String = way_for(tier.get("trigger", {}), 0)
		if not way.is_empty():
			counts[way] = float(counts.get(way, 0.0)) + 0.6
	var order: Array = counts.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return float(counts[a]) > float(counts[b]) if float(counts[a]) != float(counts[b]) else a < b)
	if order.is_empty():
		order = ["high"]
	return order.slice(0, most)

static func reroll_ids(way: String, hand: Array, a: Dictionary) -> Array:
	## The dice a player chasing `way` throws again: everything they would not keep.
	if way.is_empty() or way == "none":
		return []
	var keep: Dictionary = {}
	if way == "all":
		pass
	elif way == "sets":
		var groups: Array = a.get("groups", [])
		if not groups.is_empty() and int(groups[0].count) >= 2:
			for id in groups[0].dice:
				keep[id] = true
			if groups.size() > 1 and int(groups[1].count) >= 2:
				for id in groups[1].dice:
					keep[id] = true
		else:
			## Nothing paired yet: the highest die is kept and its twin fished for.
			var best: Dictionary = {}
			for roll in hand:
				if str(roll.get("kind", "plain")) != "blank" and (best.is_empty() or int(roll.value) > int(best.value)):
					best = roll
			if not best.is_empty():
				keep[str(best.die_id)] = true
	elif way == "straight":
		for id in a.get("straight", {}).get("dice", []):
			keep[id] = true
	elif way == "odd" or way == "even":
		for roll in hand:
			if str(roll.get("kind", "plain")) != "blank" and (int(roll.value) % 2 == 1) == (way == "odd"):
				keep[str(roll.die_id)] = true
	elif way == "distinct":
		for value in a.get("ids_by_value", {}):
			keep[a.ids_by_value[value][0]] = true
	elif way == "skip":
		var odd: bool = int(a.get("odd_values", 0)) >= int(a.get("even_values", 0))
		for value in a.get("ids_by_value", {}):
			if (int(value) % 2 == 1) == odd:
				keep[a.ids_by_value[value][0]] = true
	elif way.begins_with("value:"):
		var wanted: Array = Array(way.substr(6).split(",")).map(func(v: String) -> int: return int(v))
		for roll in hand:
			if wanted.has(int(roll.get("value", 0))):
				keep[str(roll.die_id)] = true
	elif way.begins_with("floor:"):
		var least: int = int(way.substr(6))
		for roll in hand:
			if str(roll.get("kind", "plain")) != "blank" and int(roll.value) >= least:
				keep[str(roll.die_id)] = true
	elif way.begins_with("total:"):
		## In the window: stand. Under it the low dice go again; over it, the high ones.
		var bounds: PackedStringArray = way.substr(6).split(":")
		var total: int = int(a.get("total", 0))
		var under: bool = total < int(bounds[0])
		var standing: bool = total >= int(bounds[0]) and total <= int(bounds[1])
		for roll in hand:
			if str(roll.get("kind", "plain")) != "blank" and (standing or (int(roll.value) * 2 > _size(roll)) == under):
				keep[str(roll.die_id)] = true
	elif way == "scale":
		for id in a.get("scale", {}).get("dice", []):
			keep[id] = true
	elif way == "faces":
		for id in a.get("crown_ids", []):
			keep[id] = true
		for id in a.get("one_ids", []):
			keep[id] = true
	elif way == "low":
		for roll in hand:
			if str(roll.get("kind", "plain")) != "blank" and int(roll.value) * 2 <= _size(roll):
				keep[str(roll.die_id)] = true
	elif way == "high":
		for roll in hand:
			if str(roll.get("kind", "plain")) != "blank" and int(roll.value) * 2 > _size(roll):
				keep[str(roll.die_id)] = true
	var out: Array = []
	for roll in hand:
		if keep.has(str(roll.get("die_id", ""))) or str(roll.get("kind", "plain")) == "wild":
			continue
		if bool(roll.get("locked", false)) or bool(roll.get("phantom", false)):
			continue
		out.append(str(roll.get("die_id", "")))
	return out

static func _size(roll: Dictionary) -> int:
	return DeepDice.size_of(str(roll.shape)) if roll.has("shape") else maxi(1, int(roll.get("top", roll.get("value", 1))))

# --- a fight ---------------------------------------------------------------------------------------

func fight_step() -> void:
	var b: Dictionary = state.chamber.battle
	if fight.is_empty():
		open_fight(b)
	var me: Dictionary = b.players[0]
	var tally: Dictionary = DeepBattle.stats_of(me)
	if str(b.phase) == "planning":
		var t0: int = Time.get_ticks_usec()
		var owed: int = int(tally.get("taken", 0))
		plan_turn(b)
		clock("plan", t0)
		if not fight.is_empty():
			tolled(b, me, int(DeepBattle.stats_of(me).get("taken", 0)) - owed)
		return
	var before: Dictionary = {"taken": int(tally.get("taken", 0)), "blocked": int(tally.get("blocked", 0)), "damage": int(tally.get("damage", 0)),
		"block": int(tally.get("block", 0)), "healed": int(tally.get("healed", 0)), "hp": int(me.hp), "festers": festers(me)}
	var culprit: String = blame(b, me)
	var t1: int = Time.get_ticks_usec()
	var wrapped: Dictionary = DeepDescent.step(state)
	clock("step", t1)
	if wrapped.is_empty():
		return
	var event: Dictionary = wrapped.get("battle", {})
	tally = DeepBattle.stats_of(me)
	var took: int = int(tally.get("taken", 0)) - int(before.taken)
	var stopped: int = int(tally.get("blocked", 0)) - int(before.blocked)
	var kind: String = str(event.get("kind", ""))
	var who: String = str(event.get("unit", ""))
	## How the rail rang: gem fires lit / unlit / riding, Resonance gained, and the Resonance
	## the Birthstone read each turn.
	if not fight.is_empty() and who == PID:
		if kind == "gem_fire":
			var at: int = int(event.get("socket", -1))
			if at >= 0 and at < me.sockets.size() and str(me.sockets[at]) == DeepContent.SOCKET_NONE:
				fight.ring[2] += 1
			elif bool(event.get("lit", false)):
				fight.ring[0] += 1
			else:
				fight.ring[1] += 1
			fight.ring[3] += int(event.get("gain", 0))
		elif kind == "birthstone":
			fight.ring[4] += int(me.get("resonance", 0))
			fight.ring[5] += 1
	if bool(job.get("trace", false)) and not fight.log.is_empty():
		if kind == "enemy_move":
			fight.log.back().did.append("%s: %s -%d (%d blocked)" % [str(foe_entry(b, who).key), str(event.get("move", "")), took, stopped])
		elif took > 0:
			fight.log.back().did.append("%s -%d" % [kind, took])
		elif kind == "gem_fire":
			fight.log.back().did.append("%s %d" % [str(event.get("skill", "")), int(tally.get("damage", 0)) - int(before.damage)])
		elif kind == "gem_fizzle":
			fight.log.back().did.append("(%s)" % str(event.get("skill", "")).to_lower())
		elif kind == "birthstone" and bool(event.get("fired", false)):
			fight.log.back().did.append("birthstone %d" % (int(tally.get("damage", 0)) - int(before.damage)))
	## Poison and Burn laid on the bot: whoever laid them is owed what they go on to take.
	var laid: int = maxi(0, festers(me) - int(before.festers))
	if kind.begins_with("enemy_") or (kind == "skip" and who != PID):
		var foe: Dictionary = foe_entry(b, who)
		if kind == "enemy_begin":
			foe.acts += 1
		foe.taken += took
		foe.blocked += stopped
		fight.coming += took + stopped
		if laid > 0:
			fight.venom[who] = int(fight.venom.get(who, 0)) + laid
		if took > 0 and int(me.hp) <= 0:
			fight.killer = str(foe.key)
	elif kind == "tick":
		ticked(b, me, took)
	elif kind == "birthstone":
		## A tier that costs its owner (a High Roller's Bust) is the stone's doing, not a creature's.
		var costly: bool = false
		if bool(event.get("fired", false)):
			birth.damage += int(tally.get("damage", 0)) - int(before.damage)
			birth.block += int(tally.get("block", 0)) - int(before.block)
			birth.healed += int(tally.get("healed", 0)) - int(before.healed)
			fight.birth += 1
			var penalties: Array = me.get("birthstone", {}).get("tiers", []).filter(func(t: Dictionary) -> bool: return bool(t.get("penalty", false))).map(func(t: Dictionary) -> String: return str(t.get("name", "")))
			for tier in event.get("tiers", []):
				if bool(tier.get("active", false)):
					bump(birth.tiers, str(tier.get("name", "")))
					if penalties.has(str(tier.get("name", ""))):
						costly = true
		if laid > 0:
			## A stone that poisons its owner (a Bloodroot's Tap) is owed what that goes on to take.
			var owed: String = BIRTH_VENOM if poisons_owner(me) else culprit
			fight.venom[owed] = int(fight.venom.get(owed, 0)) + laid
		if took > 0 and (costly or culprit.is_empty()):
			birth.hurt += took
			own_doing(me, took, "(its own Birthstone)")
		else:
			answered(b, me, took, culprit)
	else:
		## The bot's own rail, or the turn coming round. Nothing the rail does to its owner is a
		## creature's doing unless one stands that answers blows; whatever the turn itself lays
		## on the bot (a rule of the room) is the room's.
		if culprit.is_empty() and not kind in OWN_STEPS:
			var standing: Array = DeepBattle.living(b.enemies)
			if not standing.is_empty():
				culprit = str(standing[0].id)
		if laid > 0:
			fight.venom[culprit] = int(fight.venom.get(culprit, 0)) + laid
		if not culprit.is_empty():
			answered(b, me, took, culprit)
		elif kind == "gem_fire" and took > 0:
			## A price the gem asks of its owner.
			bump(gem_costs, str(event.get("stone_id", "")), took)
			own_doing(me, took, "(its own rail)")
		else:
			tolled(b, me, took)
	if kind == "battle_over":
		close_fight(b, str(event.get("outcome", b.get("outcome", ""))))

static func festers(unit: Dictionary) -> int:
	## What stands on a unit that will take health off it turn by turn.
	return int(unit.get("statuses", {}).get("poison", 0)) + int(unit.get("statuses", {}).get("burn", 0))

static func poisons_owner(unit: Dictionary) -> bool:
	## Whether this delver's Birthstone lays Poison or Burn on the delver wearing it.
	for tier in unit.get("birthstone", {}).get("tiers", []):
		for effect in tier.get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) in ["poison", "burn"] and str(effect.get("target", "")) == "self":
				return true
	return false

static func sends_back(foe: Dictionary) -> bool:
	## Whether this creature makes whoever lands a blow on it pay: a mirror, a Refraction,
	## Spikes, a Jagged hide, an acid skin, a Swarm's Backlash.
	if int(foe.get("mirror", 0)) > 0 or int(foe.get("reflect", 0)) > 0 or int(foe.get("statuses", {}).get("spikes", 0)) > 0:
		return true
	return DeepCreatures.trait_value(foe, "jagged", 0) > 0 or DeepCreatures.trait_value(foe, "acid_armour", 0) > 0 or DeepCreatures.has_trait(foe, "backlash")

func blame(b: Dictionary, me: Dictionary) -> String:
	## Whose doing it is if the bot's own rail costs it health: the creature it is aimed at if
	## that one answers blows, else any standing that does, else nobody's ("": the bot's own).
	## Asked before a step, since a mirror is spent by it.
	var aim: Dictionary = DeepBattle.enemy(b, str(me.get("firing_target", me.get("target", ""))))
	if not aim.is_empty() and int(aim.get("hp", 0)) > 0 and sends_back(aim):
		return str(aim.id)
	for foe in DeepBattle.living(b.enemies):
		if sends_back(foe):
			return str(foe.id)
	return ""

func own_doing(me: Dictionary, took: int, what: String) -> void:
	## Health the bot's own rail or stone cost it: a price a gem asks, a Bust.
	if took <= 0:
		return
	fight.self_hurt += took
	if int(me.hp) <= 0:
		fight.killer = what

func ticked(b: Dictionary, me: Dictionary, took: int) -> void:
	## What Poison and Burn took this turn, shared among whoever laid them on the bot, by how
	## much each laid. Nobody to name (it came in from before the fight): it stays unowned.
	fight.ticks += took
	if took <= 0:
		return
	var total: int = 0
	var order: Array = fight.venom.keys()
	for key in order:
		total += int(fight.venom[key])
	if total <= 0:
		fight.dot += took
		if int(me.hp) <= 0:
			fight.killer = "(poison or burn)"
		return
	order.sort_custom(func(x: String, y: String) -> bool: return int(fight.venom[x]) > int(fight.venom[y]) if int(fight.venom[x]) != int(fight.venom[y]) else x < y)
	for index in range(order.size()):
		var key: String = str(order[index])
		var part: int = took * int(fight.venom[key]) / total
		if index == 0:
			## The odd points go to whoever laid most.
			part = took
			for other in order.slice(1):
				part -= took * int(fight.venom[other]) / total
		if key == BIRTH_VENOM:
			fight.self_hurt += part
			birth.hurt += part
		elif key.is_empty():
			fight.self_hurt += part
		else:
			foe_entry(b, key).taken += part
	if int(me.hp) <= 0:
		var worst: String = str(order[0])
		fight.killer = "(its own Birthstone)" if worst == BIRTH_VENOM else ("(its own rail)" if worst.is_empty() else str(foe_entry(b, worst).key))

func answered(b: Dictionary, me: Dictionary, took: int, culprit: String) -> void:
	## Health the bot lost outside a creature's own action that is a creature's doing all the
	## same: a blow thrown back by a mirror, Spikes or a Jagged hide; a rule of the room.
	if took <= 0:
		return
	var entry: Dictionary = foe_entry(b, culprit)
	entry.taken += took
	fight.answered += took
	if int(me.hp) <= 0:
		fight.killer = str(entry.key)

func tolled(b: Dictionary, me: Dictionary, took: int) -> void:
	## Health a throw cost while the bot was choosing its hand: a Hall of Mirrors' toll, a
	## lantern's price. It is the doing of the creature that asks it; with none standing, the
	## bot's own.
	if took <= 0:
		return
	for foe in DeepBattle.living(b.enemies):
		if DeepCreatures.trait_value(foe, "set_toll", 0) > 0 or DeepCreatures.trait_value(foe, "reroll_drain", 0) > 0 or DeepCreatures.trait_value(foe, "reroll_scorch", 0) > 0:
			foe_entry(b, str(foe.id)).taken += took
			fight.answered += took
			if bool(job.get("trace", false)) and not fight.log.is_empty():
				fight.log.back().did.append("throws -%d" % took)
			return
	own_doing(me, took, "(its own rail)")

func foe_blow(b: Dictionary, foe: Dictionary, memo: Dictionary) -> float:
	## What this creature's action is expected to cost the party in blows: every face of every
	## die it throws, read as the panel shows it, each as likely as the next. Worked out once a
	## turn (its dice change as the fight goes on) and kept in `memo` (the fight's own book).
	if not memo.has("blows"):
		memo.blows = {}
	var id: String = blow_key(b, foe)
	if not memo.blows.has(id):
		memo.blows[id] = _foe_blow(b, foe, 0)
	return float(memo.blows[id])

func foe_answer(b: Dictionary, foe: Dictionary, memo: Dictionary) -> float:
	## How much of every point dealt to this creature this turn is expected to come back in its
	## next action, if it lives to take it (a Regent's Reflection): its blows read again as
	## though it had been dealt a hundred more.
	if not memo.has("answers"):
		memo.answers = {}
	var id: String = blow_key(b, foe)
	if not memo.answers.has(id):
		memo.answers[id] = maxf(0.0, (_foe_blow(b, foe, 100) - _foe_blow(b, foe, 0)) / 100.0)
	return float(memo.answers[id])

func blow_key(b: Dictionary, foe: Dictionary) -> String:
	## Everything a creature's expected blow turns on, short of its dice (they only change in its own action).
	var statuses: Dictionary = foe.get("statuses", {})
	return "%s|%d|%d|%d|%d|%d|%d|%d|%d" % [str(foe.get("id", "")), int(b.get("turn", 0)), int(statuses.get("strength", 0)), int(statuses.get("stun", 0)), int(statuses.get("curse", 0)),
		int(foe.get("dread_turns", 0)), int(foe.get("damage_bonus", 0)), int(foe.get("rally_bonus", 0)), int(foe.get("phase", 0))]

func _foe_blow(b: Dictionary, foe: Dictionary, dealt_more: int) -> float:
	var total: float = 0.0
	for faces in _foe_faces(b, foe, dealt_more):
		var sum: float = 0.0
		for blow in faces:
			sum += float(blow)
		if not faces.is_empty():
			total += sum / float(faces.size())
	return total

func _foe_faces(b: Dictionary, foe: Dictionary, dealt_more: int) -> Array:
	## What each face of each die this creature throws would cost the party in blows, read as
	## the panel shows it: one list a die. `dealt_more`: as though it had been dealt that much
	## since its last action (what a Reflection throws back).
	var out: Array = []
	if int(foe.get("statuses", {}).get("stun", 0)) > 0:
		return out
	var moves: Array = DeepCreatures.moves_for(foe)
	var ctx: Dictionary = DeepCreatures.context(foe, b, 0)
	## Exactly that much, whatever the fight read: the faces are kept for the turn, and the hand
	## being weighed says how much it dealt.
	ctx.taken_since = dealt_more
	var pct: int = DeepCreatures.damage_pct(foe)
	var extra: int = int(foe.get("damage_bonus", 0)) + DeepCreatures.weighted(foe, DeepCreatures.strength(foe) + int(foe.get("rally_bonus", 0)))
	var enraged: int = maxi(0, int(b.get("turn", 1)) - DeepBattle.enrage_turn(b) + 1) * DeepBattle.enrage_step(b)
	for die in DeepCreatures.effective_dice(foe):
		var blows: Array = []
		for face in die.get("faces", []):
			var sum: float = 0.0
			var move: Dictionary = DeepCreatures.move_in(moves, str(face.get("move", "")))
			if not move.is_empty():
				var c: Dictionary = ctx.duplicate()
				c.merge({"a": {}, "trig": {}, "unit": foe, "depth": int(b.get("depth", 1)), "rolled": int(face.get("value", 0))}, true)
				for definition in move.get("effects", []):
					if not definition is Dictionary or not str(definition.get("kind", "")) in ["damage", "lose_hp", "poison", "burn"]:
						continue
					var effect: Dictionary = DeepRules.resolve_effect(definition, c, 1.0, "heroes")
					if str(effect.target) in ["self", "allies", "allies_other", "escort_leader"]:
						continue
					var blow: float = float(int(effect.amount))
					if str(effect.kind) == "damage":
						blow = float(int(effect.amount)) if bool(effect.get("flat", false)) else float(DeepRules.amount({"op": "pct", "args": [int(effect.amount), pct]}, {}) + extra)
						blow += float(enraged)
					sum += blow * float(maxi(1, int(effect.get("repeat", 1))))
			blows.append(sum)
		out.append(blows)
	return out

func foe_doom(b: Dictionary, foe: Dictionary, dealt: float, cover: float, memo: Dictionary) -> float:
	## How likely this creature's next action is the end of the bot: the share of its faces
	## that land for more than the health and block the bot has (`cover`), with what was dealt
	## to it this turn thrown back on the faces that throw it back.
	if not memo.has("faces"):
		memo.faces = {}
	var id: String = blow_key(b, foe)
	if not memo.faces.has(id):
		## Each face as it lands dealt nothing, and what it adds for each point dealt.
		var plain: Array = _foe_faces(b, foe, 0)
		var more: Array = _foe_faces(b, foe, 100)
		var read: Array = []
		for die in range(plain.size()):
			var faces: Array = []
			for face in range(plain[die].size()):
				faces.append([float(plain[die][face]), maxf(0.0, (float(more[die][face]) - float(plain[die][face])) / 100.0)])
			read.append(faces)
		memo.faces[id] = read
	var doom: float = 0.0
	for faces in memo.faces[id]:
		var deadly: int = 0
		for face in faces:
			if float(face[0]) + float(face[1]) * dealt >= cover:
				deadly += 1
		if not faces.is_empty():
			doom += float(deadly) / float(faces.size())
	return minf(1.0, doom)

func foe_entry(b: Dictionary, id: String) -> Dictionary:
	if not fight.by.has(id):
		var foe: Dictionary = DeepBattle.enemy(b, id)
		fight.by[id] = {"key": str(foe.get("key", id)), "acts": 0, "taken": 0, "blocked": 0, "turns": 0, "hp": int(foe.get("max_hp", 0))}
	return fight.by[id]

func open_fight(b: Dictionary) -> void:
	var me: Dictionary = b.players[0]
	var tally: Dictionary = DeepBattle.stats_of(me)
	var kind: String = str(state.chamber.get("kind", "fight"))
	if kind == "warden" and DeepDescent.run_is_boss(state, int(state.depth)):
		kind = "boss"
	fight = {"d": int(state.depth), "k": kind, "foes": b.enemies.map(func(f: Dictionary) -> String: return str(f.key)), "by": {}, "turn": 0, "turns": 0, "ways": 0,
		"hp0": int(me.hp), "max": int(me.max_hp), "taken0": int(tally.get("taken", 0)), "blocked0": int(tally.get("blocked", 0)), "damage0": int(tally.get("damage", 0)),
		"over0": int(tally.get("overkill", 0)), "rerolls0": int(tally.get("rerolls", 0)), "coming": 0, "foe_turns": 0, "dot": 0, "ticks": 0, "venom": {}, "self_hurt": 0, "answered": 0, "birth": 0, "killer": "", "ring": [0, 0, 0, 0, 0, 0],
		"rail": DeepStone.rail_stones(me).map(func(s: Dictionary) -> String: return str(s.skill)), "log": []}
	for foe in b.enemies:
		foe_entry(b, str(foe.id))
	for stone in DeepStone.rail_stones(me):
		note_stone(stone, "found")
		bump(gem_fights, str(stone.id))

func close_fight(b: Dictionary, outcome: String) -> void:
	var me: Dictionary = b.players[0]
	var tally: Dictionary = DeepBattle.stats_of(me)
	## By creature: [how many stood, actions taken, health they took off the bot, what its block
	## stopped, turns they stood, health they came with].
	var by: Dictionary = {}
	for id in fight.by:
		var foe: Dictionary = fight.by[id]
		var key: String = str(foe.key)
		if not by.has(key):
			by[key] = [0, 0, 0, 0, 0, 0]
		by[key][0] += 1
		by[key][1] += int(foe.acts)
		by[key][2] += int(foe.taken)
		by[key][3] += int(foe.blocked)
		by[key][4] += int(foe.turns)
		by[key][5] += int(foe.hp)
	var entry: Dictionary = {"d": int(fight.d), "k": str(fight.k), "foes": fight.foes, "won": outcome == "victory", "turns": int(fight.turns),
		"hp0": int(fight.hp0), "hp1": maxi(0, int(me.hp)), "max": int(fight.max), "taken": int(tally.get("taken", 0)) - int(fight.taken0),
		"blocked": int(tally.get("blocked", 0)) - int(fight.blocked0), "dealt": int(tally.get("damage", 0)) - int(fight.damage0),
		"over": int(tally.get("overkill", 0)) - int(fight.over0), "rr": int(tally.get("rerolls", 0)) - int(fight.rerolls0),
		"dot": int(fight.dot), "ticks": int(fight.ticks), "self": int(fight.self_hurt), "back": int(fight.answered), "birth": int(fight.birth), "ring": fight.ring, "by": by, "rail": fight.rail}
	if bool(job.get("trace", false)):
		entry.log = fight.log
	if outcome != "victory":
		entry.killer = str(fight.killer)
		row.cause = {"d": int(fight.d), "k": str(fight.k), "foes": fight.foes, "killer": str(fight.killer), "turns": int(fight.turns)}
	row.fights.append(entry)
	fight = {}
	bench_mark = ""

func plan_turn(b: Dictionary) -> void:
	var me: Dictionary = b.players[0]
	if int(fight.turns) >= TURN_LIMIT:
		row.stalemate = true
		fight.killer = "(stalemate)"
		close_fight(b, "stalemate")
		act("abandon")
		return
	if int(fight.turn) != int(b.turn):
		fight.turn = int(b.turn)
		fight.ways = 0
		fight.blows = {}
		fight.answers = {}
		fight.faces = {}
	## The hand as it stands, aimed where it does best.
	var aim: String = pick_aim(b, me, float(fight.get("blow", 0.0)))
	var after: Dictionary = play_rail(b, me.hand, aim, int(me.rerolls))
	var stand: float = turn_worth(b, after)
	var thrown: float = float(DeepBattle.stats_of(after.players[0]).get("damage", 0) - DeepBattle.stats_of(me).get("damage", 0)) + float(DeepBattle.stats_of(after.players[0]).get("overkill", 0) - DeepBattle.stats_of(me).get("overkill", 0))
	if absf(thrown - float(fight.get("blow", 0.0))) > 0.5:
		## Now it is known what the hand throws, it may be better aimed.
		fight.blow = thrown
		var better: String = pick_aim(b, me, thrown)
		if better != aim:
			var again: Dictionary = play_rail(b, me.hand, better, int(me.rerolls))
			var value: float = turn_worth(b, again)
			if value > stand:
				stand = value
				aim = better
				after = again
	if stand <= -GRAVE * 0.5:
		## Aimed there, the hand kills the bot (a mirror, a Refraction): anywhere else?
		for foe in DeepBattle.targetable(b.enemies).slice(0, 4):
			if str(foe.id) == aim:
				continue
			var tried: Dictionary = play_rail(b, me.hand, str(foe.id), int(me.rerolls))
			var value: float = turn_worth(b, tried)
			if value > stand:
				stand = value
				aim = str(foe.id)
				after = tried
	var won: bool = DeepBattle.living(after.enemies).is_empty()
	## A hand that ends the fight is not thrown again. One on which every gem fires is only
	## thrown again for higher dice.
	if int(me.get("rerolls", 0)) > 0 and int(fight.ways) < 8 and not won:
		## A hand that would be the end of the bot (thrown back by a mirror now, or by a Reflection
		## as likely as not) is one to get out of: anything else is tried, the whole bowl thrown too.
		var doomed: bool = stand <= -GRAVE * 0.01
		var lit: bool = after.players[0].get("fizzled_sockets", []).is_empty() and not doomed
		var thrown_again: Array = choose_reroll(b, me, aim, stand, lit, doomed)
		if not thrown_again.is_empty():
			fight.ways += 1
			if act("reroll", {"dice": thrown_again}):
				return
	## Sleight: one die turned over, if the hand plays better for it.
	if int(me.get("flips", 0)) > 0 and not won:
		var best_flip: String = ""
		var best_value: float = stand + 0.5
		for index in range(me.hand.size()):
			var roll: Dictionary = me.hand[index]
			if not DeepBattle.shift_refusal(me, roll).is_empty():
				continue
			var turned: Array = me.hand.duplicate(true)
			var die: Dictionary = DeepBattle._die_of(me, str(roll.die_id))
			turned[index].value = DeepDice.face_value(die.faces[DeepBattle.shift_face(me, roll)])
			turned[index].erase("shown")
			turned[index].erase("counted")
			var value: float = turn_worth(b, play_rail(b, turned, aim, int(me.rerolls)))
			if value > best_value:
				best_value = value
				best_flip = str(roll.die_id)
		if not best_flip.is_empty() and act("flip", {"die": best_flip}):
			return
	## The hand is as it will be: aim it, and lock.
	if not aim.is_empty() and aim != str(me.get("target", "")):
		act("target", {"enemy": aim})
	fight.turns += 1
	birth.turns += 1
	if bool(job.get("trace", false)):
		## What the bot saw as it locked in, for reading a fight back turn by turn.
		fight.log.append({"turn": int(b.turn), "hp": int(me.hp), "block": int(me.get("block", 0)), "hand": me.hand.map(func(r: Dictionary) -> int: return int(r.get("value", 0))),
			"foes": DeepBattle.living(b.enemies).map(func(f: Dictionary) -> String: return "%s %d+%d%s" % [str(f.key), int(f.hp), int(f.get("block", 0)), " (%s)" % str(f.id) if str(f.id) == aim else ""]),
			"worth": snappedf(stand, 0.1), "thrown": int(thrown), "rerolls_left": int(me.rerolls), "did": []})
	for foe in DeepBattle.living(b.enemies):
		foe_entry(b, str(foe.id)).turns += 1
		fight.foe_turns += 1
	for stone in DeepStone.rail_stones(me):
		bump(gem_turns, str(stone.id))
		if not stones.has(str(stone.id)):
			note_stone(stone, "fight")
	if not act("lock"):
		act("abandon")

func pick_aim(b: Dictionary, me: Dictionary, blow: float) -> String:
	## Who a hand goes at, before it is played: never a mirror while anything else stands, an
	## escort before the leader it shields, the biggest creature the hand would fell, else the
	## one nearest falling. `blow` is what the rail last threw.
	var foes: Array = DeepBattle.targetable(b.enemies)
	if foes.is_empty():
		return str(me.get("target", ""))
	var best: String = str(foes[0].id)
	var best_score: float = -INF
	for foe in foes:
		var stands: float = float(int(foe.hp) + int(foe.get("block", 0)))
		var score: float = 0.0
		if int(foe.get("mirror", 0)) > 0:
			score -= 1000.0
		score -= 4.0 * float(int(foe.get("reflect", 0)))
		if bool(foe.get("charging", {}).get("store", false)):
			score -= 150.0
		var shielding: int = DeepCreatures.trait_value(foe, "shielded_by_escorts", 0)
		if shielding > 0 and foe.get("escorts", []).any(func(id: Variant) -> bool: return int(DeepBattle.enemy(b, str(id)).get("hp", 0)) > 0):
			score -= 200.0
		var leader: Dictionary = DeepBattle.enemy(b, str(foe.get("escort_of", "")))
		if not leader.is_empty() and int(leader.get("hp", 0)) > 0 and DeepCreatures.trait_value(leader, "shielded_by_escorts", 0) > 0:
			score += 150.0
		var threat: float = foe_blow(b, foe, fight)
		if stands <= blow:
			score += 100.0 + minf(stands, 200.0) * 0.2 + threat * 3.0
		else:
			score += threat * 1.5 - stands * 0.05
		if score > best_score:
			best_score = score
			best = str(foe.id)
	return best

func choose_reroll(b: Dictionary, me: Dictionary, aim: String, stand: float, lit: bool, doomed: bool = false) -> Array:
	## The dice to throw again, or [] to stand: the ways of keeping that the rail would chase,
	## thrown a couple of times and played out. `lit`: every gem already fires on this hand.
	## `doomed`: the hand as it stands is the end of the bot, so the whole bowl is tried as well.
	var allowed: Array = DeepDice.rerollable(me.hand)
	if allowed.is_empty():
		return []
	var ways: Array = []
	var seen: Dictionary = {}
	var whole: bool = DeepBattle.all_or_nothing(me) or DeepBattle.living(b.enemies).any(func(f: Dictionary) -> bool: return DeepCreatures.has_trait(f, "reroll_all"))
	if whole:
		ways.append(allowed)
	else:
		var a: Dictionary = DeepHand.analyze(me.hand)
		for way in (["high"] if lit else ways_of(me, REROLL_WAYS) + ["high", "all"]):
			var ids: Array = reroll_ids(str(way), me.hand, a).filter(func(id: String) -> bool: return allowed.has(id))
			ids.sort()
			var key: String = ",".join(ids)
			if ids.is_empty() or seen.has(key):
				continue
			seen[key] = true
			ways.append(ids)
			if ways.size() >= REROLL_WAYS:
				break
		if doomed:
			var every: Array = allowed.duplicate()
			every.sort()
			if not seen.has(",".join(every)):
				ways.append(every)
	var dice: Array = me.dice.duplicate(true)
	var left: int = int(me.rerolls) - 1
	## A lantern's price comes off what the throw is worth.
	var price: float = 0.0
	for foe in DeepBattle.living(b.enemies):
		if DeepCreatures.has_trait(foe, "gift_rerolls"):
			price += float(DeepCreatures.trait_value(foe, "reroll_drain", 0)) * HURT_WORTH
	## A hand that would kill the bot is thrown again whatever comes of it.
	var best: float = stand + 0.5 if stand > -GRAVE * 0.5 else -INF
	var pick: Array = []
	for ids in ways:
		var sum: float = 0.0
		for _throw in range(REROLL_THROWS):
			sum += turn_worth(b, play_rail(b, DeepDice.reroll(me.hand, dice, ids, rng), aim, left))
		var mean: float = sum / float(REROLL_THROWS) - price
		if mean > best:
			best = mean
			pick = ids
	return pick

# --- the mine --------------------------------------------------------------------------------------

func vote(unit: Dictionary) -> void:
	var health: float = float(unit.hp) / float(maxi(1, int(unit.max_hp)))
	var raw: int = raw_stones(unit).size()
	var worth_of: Dictionary = {"landing": 1000.0, "motherlode": 85.0, "vein": 60.0 if health > 0.5 else 30.0,
		"elite": 70.0 if health >= 0.75 else (25.0 if health >= 0.5 else 2.0),
		"merchant": 58.0 if int(unit.ore) >= 60 or raw > 0 else 30.0, "fight": 45.0 if health >= 0.4 else 15.0,
		"rest_stop": 90.0 if health < 0.6 else 25.0, "oddity": 35.0, "well": 12.0, "smithy": 14.0, "carver": 14.0, "altar": 10.0, "vat": 12.0}
	var best: Dictionary = {}
	var best_worth: float = -1.0
	var nodes: Dictionary = state.get("map", {}).get("nodes", {})
	for offer in state.offers:
		var node: Dictionary = nodes.get(str(offer.id), {})
		var shown: bool = DeepDescent.revealed(state, node) if not node.is_empty() else not bool(offer.get("hidden", false))
		var value: float = float(worth_of.get(str(offer.kind), 30.0)) if shown else 32.0
		if value > best_worth:
			best_worth = value
			best = offer
	if best.is_empty() or not act("vote_tunnel", {"offer": best.id}):
		for offer in state.offers:
			if act("vote_tunnel", {"offer": offer.id}):
				return
		act("abandon")

func take_spoils(unit: Dictionary) -> void:
	why = "spoils"
	## One of the three cards: the stone if the rail gains by it, else a die's work if the rail
	## plays better for it, else the pyrite.
	var cards: Array = DeepDescent.spoils_of(state, PID).get("cards", [])
	var pick: int = -1
	var best: float = 0.012
	for index in range(cards.size()):
		if str(cards[index].get("kind", "")) == "ore" and pick < 0:
			pick = index
	for index in range(cards.size()):
		var card: Dictionary = cards[index]
		if str(card.get("kind", "")) != "stone":
			continue
		bump(offered, str(card.stone.skill))
		var gain: float = stone_gain(unit, card.stone)
		if gain > best:
			best = gain
			pick = index
	if best < 0.03:
		for index in range(cards.size()):
			var card: Dictionary = cards[index]
			if str(card.get("kind", "")) != "die":
				continue
			var worked: Dictionary = unit.duplicate(true)
			for at in range(worked.dice.size()):
				if str(worked.dice[at].get("id", "")) == str(card.get("die_id", "")):
					worked.dice[at] = card.get("after", worked.dice[at]).duplicate(true)
			var gain: float = gain_over(rail_value(worked), rail_value(unit))
			if gain > best:
				best = gain
				pick = index
	if pick >= 0 and str(cards[pick].get("kind", "")) == "stone":
		bump(taken, str(cards[pick].stone.skill))
	if pick >= 0:
		bump(row, "spoils_" + str(cards[pick].get("kind", "")))
	if not act("spoils", {"pick": pick}):
		act("spoils", {"pick": - 1})
	bench_mark = ""

func stone_gain(unit: Dictionary, stone: Dictionary) -> float:
	## What a read stone is worth taking: what the rail gains by it, or for a twin of a gem
	## already held, a carat on that gem if the crucible's fee is to hand.
	for held in DeepStone.rail_stones(unit) + loose_stones(unit):
		if str(held.get("skill", "")) == str(stone.get("skill", "")):
			return 0.03 if int(unit.get("ore", 0)) >= DeepOddities.fuse_cost() + 40 else 0.0
	return float(best_fit(unit, stone).gain)

func dig(unit: Dictionary) -> void:
	## The rock: the first swing is free and each one after costs a point more, so a few
	## swings at the brightest spots while the arm is fresh.
	if not bool(unit.get("mining", false)):
		act("stop_mining")
		return
	var cost: int = DeepDescent.swing_cost(state, unit)
	var health: float = float(int(unit.hp) - cost) / float(maxi(1, int(unit.max_hp)))
	var most: int = 4 if health >= 0.75 else (2 if health >= 0.5 else 0)
	var order: Dictionary = {"rich": 4, "bright": 3, "glint": 2, "dull": 1}
	var best: Dictionary = {}
	for spot in state.chamber.vein.spots:
		if not str(spot.get("taken", "")).is_empty():
			continue
		var value: int = int(order.get(str(spot.get("glint", "dull")), 1)) * 10 + int(spot.get("struck", 0)) * 25
		if best.is_empty() or value > int(best.value):
			best = {"index": int(spot.index), "value": value, "glint": str(spot.get("glint", "dull"))}
	if not best.is_empty() and cost <= most and (cost == 0 or str(best.glint) != "dull") and act("strike", {"spot": int(best.index)}):
		for stone in unit.haul:
			note_stone(stone, "vein")
		return
	act("stop_mining")

func shop(unit: Dictionary) -> void:
	why = "shop"
	## The stall: raw stones read while the pyrite lasts, then whatever stone the rail gains
	## most by, if it can be paid for.
	var here: String = "%s:%d" % [str(state.mine), int(state.depth)]
	if stall_mark != here:
		stall_mark = here
		stall_bought = 0
		for item in DeepDescent.stall_stock(state, PID):
			if str(item.get("kind", "")) == "stone":
				bump(offered, str(item.stone.skill))
	var raw: Array = raw_stones(unit)
	if not raw.is_empty() and int(unit.ore) >= DeepDescent.appraise_cost(state, PID):
		if act("appraise", {"stone_id": best_raw(raw).id}):
			bench_mark = ""
			return
	if bench(unit):
		return
	if stall_bought < 2:
		var best: Dictionary = {}
		var best_gain: float = 0.06
		for item in DeepDescent.stall_stock(state, PID):
			if str(item.get("kind", "")) != "stone" or not str(item.get("sold", "")).is_empty() or int(item.price) > int(unit.ore):
				continue
			var gain: float = stone_gain(unit, item.stone)
			if gain > best_gain:
				best_gain = gain
				best = item
		if not best.is_empty() and act("buy", {"item_id": best.id}):
			stall_bought += 1
			bump(taken, str(best.stone.skill))
			bench_mark = ""
			return
	if not act("leave"):
		act("abandon")

func best_raw(raw: Array) -> Dictionary:
	## The raw stone to read first: an opal out of a hoard, else the biggest.
	var best: Dictionary = raw[0]
	for stone in raw:
		var opal: bool = DeepStone.is_opal(stone)
		if (opal and not DeepStone.is_opal(best)) or (opal == DeepStone.is_opal(best) and int(stone.get("carat", 0)) > int(best.get("carat", 0))):
			best = stone
	return best

func card(unit: Dictionary) -> void:
	## A card room. The bot takes what is plainly good (a rest, a read, loose chips) and leaves
	## the gambles and the dice benches alone, so every delver's dice stay the ones they were made with.
	var key: String = str(state.chamber.get("oddity", ""))
	var choices: Array = DeepDescent.room_choices(state, PID)
	var raw: Array = raw_stones(unit)
	var health: float = float(unit.hp) / float(maxi(1, int(unit.max_hp)))
	var wanted: Array = []
	match key:
		"FIELD_MEDIC":
			var set_gems: Array = unit.rail.filter(func(s: Variant) -> bool: return s is Dictionary and DeepDescent.polish_refusal(unit, s).is_empty())
			if health >= 0.85 and not set_gems.is_empty():
				set_gems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.carat) > int(b.carat))
				wanted.append(["polish", {"stone_id": str(set_gems[0].id)}])
			wanted.append(["heal", {}])
		"LOUPE_CABINET":
			if not raw.is_empty():
				wanted.append(["look", {"stone_id": str(best_raw(raw).id)}])
			wanted.append(["ore", {}])
		"SEAM":
			wanted.append(["chips", {}])
		"ACID_BATH":
			if not raw.is_empty() and health >= 0.6:
				wanted.append(["dissolve", {"stone_ids": raw.slice(0, 3).map(func(s: Dictionary) -> String: return str(s.id))}])
	for want in wanted:
		if act("oddity", {"choice": str(want[0]), "payload": want[1]}):
			bench_mark = ""
			return
	for choice in choices:
		if str(choice.get("action", {}).get("kind", "")) == "none" and act("oddity", {"choice": str(choice.id), "payload": {}}):
			return
	for choice in choices:
		if act("oddity", {"choice": str(choice.id), "payload": {}}):
			return
	act("abandon")

func landing(unit: Dictionary) -> void:
	if bench(unit):
		return
	if DeepDescent.needs_respite(state, unit):
		var raw: Array = raw_stones(unit)
		var health: float = float(unit.hp) / float(maxi(1, int(unit.max_hp)))
		if health < 0.72 and act("respite", {"choice": "rest"}):
			return
		if not raw.is_empty() and act("respite", {"choice": "appraise", "stone_id": str(best_raw(raw).id)}):
			bench_mark = ""
			return
		if act("respite", {"choice": "rest"}):
			return
		if int(unit.ore) >= DeepDescent.WISH_LEAST and act("respite", {"choice": "wish", "ore": DeepDescent.WISH_LEAST}):
			return
	if act("choose", {"choice": "descend"}):
		return
	if act("choose", {"choice": "lift"}):
		return
	act("abandon")

func hoard(unit: Dictionary) -> void:
	why = "hoard"
	## The Warden's pile: the opal if the rail has room for another, else the read stone the
	## rail gains most by. Never the Geode: it is for the workshop.
	var mine_hoard: Dictionary = state.hoard.get(PID, {})
	var offers: Array = mine_hoard.get("offers", [])
	var opals: int = 0
	for held in DeepStone.rail_stones(unit) + unit.haul:
		if not DeepStone.is_geode(held) and DeepStone.is_opal(held):
			opals += 1
	var pick: Dictionary = {}
	var best: float = -1.0
	for stone in offers:
		if DeepStone.is_geode(stone):
			continue
		bump(offered, str(stone.skill))
		var gain: float = 0.0
		if not bool(stone.get("appraised", false)):
			gain = 0.5 if opals < 2 else 0.0
		else:
			gain = stone_gain(unit, stone)
		if gain > best:
			best = gain
			pick = stone
	if pick.is_empty() and not offers.is_empty():
		pick = offers[0]
	if not pick.is_empty() and act("pick_hoard", {"stone_id": str(pick.id)}):
		if not DeepStone.is_geode(pick):
			bump(taken, str(pick.skill))
			note_stone(pick, "hoard")
		bench_mark = ""
		return
	for stone in offers:
		if act("pick_hoard", {"stone_id": str(stone.id)}):
			return
	act("abandon")
