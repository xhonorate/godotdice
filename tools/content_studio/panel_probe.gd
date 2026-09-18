extends SceneTree
## The engine half of the gem-panel cross-check. Prints the same lines `panel_probe.mjs`
## does, from the code the game actually draws with.
const Catalog = preload("res://scripts/core/catalog.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")
const RANKS: Array = [[1, 1, 1], [8, 3, 3], [24, 5, 5], [12, 2, 4], [4, 4, 2]]

func _init() -> void:
	var errors: Array = Catalog.load_content_pack("res://data/full_content.json")
	if not errors.is_empty():
		printerr("The pack did not load: ", errors)
		quit(1)
		return
	var keys: Array = Catalog.definitions("skills").keys()
	keys.sort()
	var lines: PackedStringArray = []
	for key in keys:
		var definition: Dictionary = Catalog.definitions("skills")[key]
		for ranks in RANKS:
			var c: int = int(ranks[0])
			var k: int = int(ranks[1])
			var l: int = int(ranks[2])
			var label: String = "%s C%dK%dL%d" % [key, c, k, l]
			var gem: Dictionary = Catalog.gem(str(key), "probe", c, k, l)
			var strip: Dictionary = DiceIcons.strip(str(key), l, k, c)
			var faces: PackedStringArray = []
			for entry in strip.faces:
				faces.append(str(int(entry[0])))
			lines.append("%s requires lead=%s faces=%s note=%s" % [label,
				str(strip.lead) if not str(strip.lead).is_empty() else "_",
				"+".join(faces) if not faces.is_empty() else "_", str(strip.note)])
			for row in GemText.blocks(gem):
				var parts: PackedStringArray = []
				for found in row.parts:
					parts.append(_item(found))
				lines.append("%s does %s [%s] mult=%s %s %s repeat=%s note=%s" % [label, str(row.verb),
					" + ".join(parts), _item(row.mult), str(row.label),
					str(row.suffix) if not str(row.suffix).is_empty() else "_",
					_item(row.repeat), str(row.note) if not str(row.note).is_empty() else "_"])
			for found in GemText.title_parts(gem):
				lines.append("%s title %s" % [label, _item(found)])
	print("\n".join(lines))
	quit(0)

func _item(found: Dictionary) -> String:
	if found == null or found.is_empty():
		return "-"
	var factor: Dictionary = found.get("factor", {})
	var suffix: String = "" if factor.is_empty() else "{%s:%s}" % [str(factor.get("glyph", "")), str(factor.get("text", ""))]
	var glyph: String = str(found.get("glyph", ""))
	return "%s:%s%s" % ["_" if glyph.is_empty() else glyph, str(found.get("text", "")), suffix]
