class_name DeepPatch
extends RefCounted
## A generic diff over the dictionary state, so a guest's mirror can follow the host one
## step at a time without ever running the rules.
##
## A patch is {"set": {key: value}, "sub": {key: patch}, "del": [key]} for two dictionaries,
## or {"=": value} when either side is not a dictionary. Arrays are replaced whole, except a
## list of dictionaries that keeps its length (the players, the creatures): that is patched
## item by item, {"at": {index: patch}}, since a creature's action dice made every creature a
## few kilobytes and one of them changing should not send them all.

static func holds(list: Array, number: int) -> bool:
	## Whether a list of whole numbers has this one in it. Anything that has been through JSON
	## (a checkpoint, the profile, a packet to a guest) comes back with every number a float,
	## and `[5.0].has(5)` is false.
	for item in list:
		if (item is int or item is float) and int(item) == number:
			return true
	return false

static func diff(before: Variant, after: Variant) -> Variant:
	if before is Dictionary and after is Dictionary:
		var out: Dictionary = {}
		for key in after:
			if not before.has(key):
				_put(out, "set", key, after[key])
			elif _untouched(before[key], after[key]):
				## Most of the run does not move from one step of a fight to the next.
				continue
			elif before[key] is Dictionary and after[key] is Dictionary:
				var sub: Variant = diff(before[key], after[key])
				if sub != null:
					_put(out, "sub", key, sub)
			elif _items(before[key], after[key]):
				var each: Dictionary = {}
				for index in range(after[key].size()):
					if not _untouched(before[key][index], after[key][index]):
						var item: Variant = diff(before[key][index], after[key][index])
						if item != null:
							each[str(index)] = item
				if not each.is_empty():
					_put(out, "sub", key, {"at": each})
			elif not _same(before[key], after[key]):
				_put(out, "set", key, after[key])
		for key in before:
			if not after.has(key):
				if not out.has("del"):
					out.del = []
				out.del.append(key)
		return out if not out.is_empty() else null
	if _same(before, after):
		return null
	return {"=": after}

static func apply(base: Variant, patch: Variant) -> Variant:
	if patch == null:
		return base
	if not patch is Dictionary:
		return patch
	if patch.has("="):
		return _copy(patch["="])
	if patch.has("at") and base is Array:
		for index in patch.at:
			base[int(index)] = apply(base[int(index)], patch.at[index])
		return base
	if not base is Dictionary:
		base = {}
	for key in patch.get("del", []):
		base.erase(key)
	var sets: Dictionary = patch.get("set", {})
	for key in sets:
		base[key] = _copy(sets[key])
	var subs: Dictionary = patch.get("sub", {})
	for key in subs:
		base[key] = apply(base.get(key, {}), subs[key])
	return base

static func _items(a: Variant, b: Variant) -> bool:
	## A list of dictionaries the same length on both sides: patched item by item.
	if not (a is Array and b is Array) or a.size() != b.size() or a.is_empty():
		return false
	for index in range(a.size()):
		if not (a[index] is Dictionary and b[index] is Dictionary):
			return false
	return true

static func _put(out: Dictionary, bucket: String, key: Variant, value: Variant) -> void:
	if not out.has(bucket):
		out[bucket] = {}
	out[bucket][key] = value

static func _untouched(a: Variant, b: Variant) -> bool:
	## The engine's own comparison, which walks a whole branch natively and far faster than the
	## loops below. It is strict about types, so "equal" here always means `_same` too; when it
	## says no, `_same` still gets its say on 3 against 3.0.
	return typeof(a) == typeof(b) and (a is Dictionary or a is Array) and a == b

static func _same(a: Variant, b: Variant) -> bool:
	if _untouched(a, b):
		return true
	if typeof(a) != typeof(b):
		## JSON turns every number into a float; a patch must not thrash on 3 versus 3.0.
		if (a is int or a is float) and (b is int or b is float):
			return float(a) == float(b)
		return false
	if a is Array:
		if a.size() != b.size():
			return false
		for index in range(a.size()):
			if not _same(a[index], b[index]):
				return false
		return true
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	return a == b

static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
