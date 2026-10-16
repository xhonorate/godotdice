class_name DeepBestiary
extends RefCounted
## The bestiary: every creature the player has met, and where the rest are waiting.
##
## What is written down happens in the run, for the whole party, at the two places a fight
## starts and ends (`met` and `settled`): every creature standing when it opens is met, every
## one called in during it is met when it is over, every one that fell is slain, and every
## kind still standing over a party that lost is one the party lost to. The run carries this
## as `state.bestiary`, so a guest's mirror and a share held for an absent player have it
## too, and the profile adds it to its own when the run comes home (`merge`).
##
## Where a creature lives is read from the pack, not written anywhere: the mine bands it is
## drawn from, the landings it guards, whoever brings it in. Its home is the shallowest mine
## it turns up in, which is where the bestiary files it.

## The order a mine's creatures are listed in, by what they are.
const ROLES: Array = ["creature", "escort", "warden", "boss", "unmade"]

## Where everything lives, worked out once for the pack it was read from (see `_index`).
static var _indexed_pack: Dictionary = {}
static var _index_cache: Dictionary = {}

# --- in the run -----------------------------------------------------------------------------

static func met(state: Dictionary, enemies: Array) -> void:
	## A fight has opened on these creatures: each one is met, in the mine and at the depth
	## the party stands at.
	for foe in enemies:
		_note(state, foe).met += 1

static func settled(state: Dictionary, enemies: Array, outcome: String) -> void:
	## A fight is over. What was called into it is met now; what fell is slain; and a fight
	## lost is lost once to every kind still standing, however many of it there were.
	var standing: Dictionary = {}
	for foe in enemies:
		var entry: Dictionary = _note(state, foe)
		if bool(foe.get("summoned", false)):
			entry.met += 1
		if int(foe.get("hp", 0)) <= 0 and not bool(foe.get("fled", false)):
			entry.slain += 1
		elif outcome == "defeat" and int(foe.get("hp", 0)) > 0 and not bool(foe.get("fled", false)):
			standing[str(foe.get("key", ""))] = entry
	for entry in standing.values():
		entry.lost += 1

static func _note(state: Dictionary, foe: Dictionary) -> Dictionary:
	if not state.has("bestiary"):
		state.bestiary = {}
	var key: String = str(foe.get("key", ""))
	if not state.bestiary.has(key):
		state.bestiary[key] = {"met": 0, "slain": 0, "lost": 0, "mines": {}}
	var entry: Dictionary = state.bestiary[key]
	var mine: String = str(state.get("mine", ""))
	if not mine.is_empty():
		entry.mines[mine] = maxi(int(entry.mines.get(mine, 0)), int(state.get("depth", 0)))
	return entry

# --- in the profile -------------------------------------------------------------------------

static func merge(profile: Dictionary, run: Dictionary) -> Array:
	## Adds a run's record to the profile's. Returns the keys met for the first time, which
	## are marked new until the player has looked at them.
	if not profile.has("bestiary"):
		profile.bestiary = {}
	var first: Array = []
	for key in run:
		if DeepContent.creature(str(key)).is_empty():
			continue
		var seen: Dictionary = run[key]
		if not profile.bestiary.has(key):
			profile.bestiary[key] = {"met": 0, "slain": 0, "lost": 0, "mines": {}, "first": Time.get_date_string_from_system(), "fresh": true}
			first.append(str(key))
		var entry: Dictionary = profile.bestiary[key]
		for field in ["met", "slain", "lost"]:
			entry[field] = int(entry.get(field, 0)) + int(seen.get(field, 0))
		if not entry.has("mines"):
			entry.mines = {}
		for mine in seen.get("mines", {}):
			entry.mines[mine] = maxi(int(entry.mines.get(mine, 0)), int(seen.mines[mine]))
	return first

static func entry(profile: Dictionary, key: String) -> Dictionary:
	return profile.get("bestiary", {}).get(key, {})

static func known(profile: Dictionary, key: String) -> bool:
	return int(entry(profile, key).get("met", 0)) > 0

static func known_count(profile: Dictionary, keys: Array = []) -> int:
	var count: int = 0
	for key in (keys if not keys.is_empty() else order()):
		if known(profile, str(key)):
			count += 1
	return count

static func fresh_count(profile: Dictionary) -> int:
	var count: int = 0
	for key in profile.get("bestiary", {}):
		if bool(profile.bestiary[key].get("fresh", false)):
			count += 1
	return count

static func unfresh(profile: Dictionary, key: String) -> bool:
	## The player has looked at it: it is no longer new. True if it was.
	var record: Dictionary = entry(profile, key)
	if not bool(record.get("fresh", false)):
		return false
	record.erase("fresh")
	return true

# --- where they live ------------------------------------------------------------------------

static func order() -> Array:
	## Every creature in the pack, mine by mine from the top down (see `in_mine`).
	return _index().order.duplicate()

static func in_mine(mine_key: String) -> Array:
	## The creatures filed under a mine: those it is the first to have.
	return _index().pages.get(mine_key, []).duplicate()

static func home(key: String) -> String:
	## The mine a creature is filed under (see `homes`).
	return str(_index().homes.get(key, ""))

static func _index() -> Dictionary:
	## The pages and their order, read from the pack once: a page of the bestiary asks for
	## them many times over, and the pack does not change under a running game.
	var pack: Dictionary = DeepContent.pack()
	if is_same(pack, _indexed_pack) and not _index_cache.is_empty():
		return _index_cache
	var pages: Dictionary = {}
	var everything: Array = []
	for mine in DeepContent.mines_in_order():
		pages[str(mine)] = _page(str(mine))
		everything.append_array(pages[str(mine)])
	_indexed_pack = pack
	_index_cache = {"pages": pages, "order": everything, "homes": homes()}
	return _index_cache

static func _page(mine_key: String) -> Array:
	## A mine's page: the ordinary creatures as they come, by the depth they first turn up at
	## and then how dangerous they are; then its Wardens in the order they stand, its boss and
	## whatever stands in for a Warden, each followed by the creatures that only ever walk in
	## beside it.
	var homes: Dictionary = homes()
	var mine: Dictionary = DeepContent.mine(mine_key)
	var ordinary: Array = []
	var leaders: Array = []
	for key in homes:
		if str(homes[key]) != mine_key:
			continue
		match role(str(key)):
			"creature": ordinary.append(str(key))
			"warden", "boss", "unmade": leaders.append(str(key))
	var first: Dictionary = {}
	for key in ordinary:
		first[key] = _first_depth(mine, key)
	ordinary.sort_custom(func(a: String, b: String) -> bool:
		if int(first[a]) != int(first[b]):
			return int(first[a]) < int(first[b])
		var ta: int = int(DeepContent.creature(a).get("threat", 0))
		var tb: int = int(DeepContent.creature(b).get("threat", 0))
		return ta < tb if ta != tb else a < b)
	leaders.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = ROLES.find(role(a))
		var rb: int = ROLES.find(role(b))
		if ra != rb:
			return ra < rb
		return mine.get("wardens", []).find(a) < mine.get("wardens", []).find(b))
	var out: Array = ordinary.duplicate()
	for leader in leaders:
		out.append(leader)
		for key in homes:
			if str(homes[key]) == mine_key and role(str(key)) == "escort" and _brought_by(str(key)) == leader and not out.has(str(key)):
				out.append(str(key))
	## An escort whose leader lives elsewhere still belongs on this mine's page.
	for key in homes:
		if str(homes[key]) == mine_key and not out.has(str(key)):
			out.append(str(key))
	return out

static func homes() -> Dictionary:
	## Every creature's home mine: the shallowest it turns up in, as one of a band, a Warden,
	## a boss or the Rift's own. A creature only ever brought in by another lives where that
	## one does.
	var out: Dictionary = {}
	for mine_key in DeepContent.mines_in_order():
		var mine: Dictionary = DeepContent.mine(str(mine_key))
		var here: Array = []
		for band in mine.get("bands", []):
			here.append_array(band.get("creatures", {}).keys())
		here.append_array(mine.get("wardens", []))
		for field in ["boss", "unmade"]:
			if not str(mine.get(field, "")).is_empty():
				here.append(str(mine[field]))
		for key in here:
			if not out.has(str(key)):
				out[str(key)] = str(mine_key)
	for key in DeepContent.section("creatures"):
		if out.has(str(key)):
			continue
		var by: String = _brought_by(str(key))
		if out.has(by):
			out[str(key)] = out[by]
	return out

static func role(key: String) -> String:
	## What the creature is: an ordinary creature, one that only walks in beside another, a
	## Warden, a mine's final boss, or the Rift's own Warden.
	var def: Dictionary = DeepContent.creature(key)
	if bool(def.get("summon_only", false)):
		return "escort"
	for mine_key in DeepContent.mines_in_order():
		var mine: Dictionary = DeepContent.mine(str(mine_key))
		if str(mine.get("unmade", "")) == key:
			return "unmade"
		if str(mine.get("boss", "")) == key:
			return "boss"
	if bool(def.get("warden", false)):
		return "warden"
	return "creature"

static func haunts(key: String) -> Array:
	## Where the creature is met, as written in the pack: one entry per place, each one of
	##   {kind: "band", mine, from, to}  drawn for fights between these depths (`to` 0: on down)
	##   {kind: "warden", mine, depth}   a Warden, around this depth
	##   {kind: "boss", mine, depth}     the final boss, on the bottom floor
	##   {kind: "remembered", mine}      an endless mine's Warden, remembered from above
	##   {kind: "unmade", mine, every}   an endless mine's own, every so many floors
	##   {kind: "escort", of}            walks in beside another
	##   {kind: "summoned", by}          called into a fight by another
	##   {kind: "echo", mines}           a copy of an ordinary creature from these mines
	var out: Array = []
	for mine_key in DeepContent.mines_in_order():
		var mine: Dictionary = DeepContent.mine(str(mine_key))
		for span in _spans(mine, key):
			out.append({"kind": "band", "mine": str(mine_key), "from": int(span[0]), "to": int(span[1])})
		var wardens: Array = mine.get("wardens", [])
		if wardens.has(key):
			if bool(mine.get("endless", false)):
				out.append({"kind": "remembered", "mine": str(mine_key)})
			else:
				var depths: Array = mine.get("warden_depths", [])
				var at: int = wardens.find(key)
				out.append({"kind": "warden", "mine": str(mine_key), "depth": int(depths[at]) if at < depths.size() else 0})
		if str(mine.get("boss", "")) == key:
			out.append({"kind": "boss", "mine": str(mine_key), "depth": DeepContent.mine_bottom(str(mine_key))})
		if str(mine.get("unmade", "")) == key:
			out.append({"kind": "unmade", "mine": str(mine_key), "every": int(mine.get("unmade_every", 0)) * maxi(1, int(mine.get("warden_every", 8)))})
	for other in DeepContent.section("creatures"):
		if str(other) == key:
			continue
		var def: Dictionary = DeepContent.creature(str(other))
		if def.get("escorts", []).has(key):
			out.append({"kind": "escort", "of": str(other)})
		elif _summons(def).has(key):
			out.append({"kind": "summoned", "by": str(other)})
	var echo: Dictionary = DeepContent.creature(key).get("echo", {})
	if not echo.is_empty():
		out.append({"kind": "echo", "mines": echo.get("mines", []).duplicate()})
	return out

static func _spans(mine: Dictionary, key: String) -> Array:
	## The depths a mine's bands draw this creature at, as [from, to] pairs with neighbouring
	## bands run together; `to` is 0 in a mine with no bottom.
	var bands: Array = mine.get("bands", []).duplicate()
	bands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("from_depth", 1)) < int(b.get("from_depth", 1)))
	var bottom: int = 0 if bool(mine.get("endless", false)) else int(mine.get("depth", 24))
	var out: Array = []
	for index in range(bands.size()):
		if not bands[index].get("creatures", {}).has(key):
			continue
		var from: int = int(bands[index].get("from_depth", 1))
		var to: int = int(bands[index + 1].get("from_depth", 1)) - 1 if index + 1 < bands.size() else bottom
		if not out.is_empty() and int(out.back()[1]) == from - 1:
			out.back()[1] = to
		else:
			out.append([from, to])
	return out

static func _first_depth(mine: Dictionary, key: String) -> int:
	var spans: Array = _spans(mine, key)
	return int(spans[0][0]) if not spans.is_empty() else 999

static func _brought_by(key: String) -> String:
	## The creature that brings this one in, when it has no band of its own: whoever it walks
	## beside, or else whoever calls it.
	var caller: String = ""
	for other in DeepContent.section("creatures"):
		if str(other) == key:
			continue
		var def: Dictionary = DeepContent.creature(str(other))
		if def.get("escorts", []).has(key):
			return str(other)
		if caller.is_empty() and _summons(def).has(key):
			caller = str(other)
	return caller

static func _summons(def: Dictionary) -> Array:
	## The creatures a creature's moves call into a fight, in any phase.
	var out: Array = []
	for moveset in [def] + def.get("phases", []):
		for move in moveset.get("moves", []):
			for effect in move.get("effects", []):
				if str(effect.get("kind", "")) == "summon" and not out.has(str(effect.get("creature", ""))):
					out.append(str(effect.get("creature", "")))
	return out
