extends SceneTree
## The engine half of the rule-interpreter cross-check. Reads the cases `rule_probe.mjs`
## wrote and prints the same lines, so the two can be diffed:
##   node tools/content_studio/rule_probe.mjs > js.txt
##   godot --headless --path . --script tools/content_studio/rule_probe.gd > gd.txt
##   diff js.txt gd.txt
const GemRules = preload("res://scripts/core/gem_rules.gd")
const CASES: String = "res://tools/content_studio/rule_probe_cases.json"

func _init() -> void:
	var file: FileAccess = FileAccess.open(CASES,FileAccess.READ)
	if file == null:
		printerr("Run rule_probe.mjs first; it writes the cases this reads.")
		quit(1)
		return
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		printerr("Unreadable probe cases.")
		quit(1)
		return
	var data: Dictionary = parser.data
	var lines: PackedStringArray = []
	for key in data.recipes:
		var rule: Dictionary = data.recipes[key]
		lines.append("%s trigger: %s" % [key,GemRules.describe_trigger(rule.trigger)])
		lines.append("%s formula: %s" % [key,GemRules.describe(rule)])
		var errors: Array = GemRules.validate(rule)
		lines.append("%s errors: %s" % [key,"none" if errors.is_empty() else " | ".join(errors)])
		for ranks in data.ranks:
			for numbers in data.hands:
				var context: Dictionary = _context(numbers,int(ranks[0]),int(ranks[1]),int(ranks[2]),int(data.block))
				var result: Dictionary = GemRules.evaluate(rule,context)
				var drawn: PackedStringArray = []
				for effect in result.effects:
					drawn.append("%s:%d>%s%s" % [effect.kind,int(effect.amount),effect.target,
						"x"+str(int(effect.target_limit)) if effect.has("target_limit") else ""])
				var dice: Array = result.selected.duplicate()
				dice.sort()
				var shown: PackedStringArray = []
				for value in numbers:
					shown.append(str(int(value)))
				lines.append("%s C%dK%dL%d %s active=%d dice=%s %s" % [key,int(ranks[0]),int(ranks[1]),int(ranks[2]),
					"-".join(shown),1 if result.active else 0,"+".join(PackedStringArray(dice)),",".join(drawn)])
	print("\n".join(lines))
	quit(0)

func _context(numbers: Array, carat: int, cut: int, clarity: int, block: int) -> Dictionary:
	## The same shape `combat.gd` hands the interpreter.
	var rolls: Array = []
	for index in range(numbers.size()):
		rolls.append({"value":int(numbers[index]), "die_id":"d"+str(index)})
	rolls.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.value < b.value if a.value != b.value else a.die_id < b.die_id)
	var groups: Dictionary = {}
	var total: int = 0
	for roll in rolls:
		if not groups.has(roll.value):
			groups[roll.value] = []
		groups[roll.value].append(roll.die_id)
		total += int(roll.value)
	return {"hand":rolls, "groups":groups, "total":total, "high":int(rolls.back().value) if not rolls.is_empty() else 0,
		"carat":carat, "cut":cut, "clarity":clarity, "block":block,
		"straight_length":5-int((clarity-1)/2), "selected":[], "run":[]}
