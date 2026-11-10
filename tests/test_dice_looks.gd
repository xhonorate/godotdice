extends SceneTree
## The dice's looks and blood's effects (November 10, 2026): every material resolves to a
## shipped look with no review switch left in the code, only blood bleeds, and a blood effect's
## layer is made when it plays and freed when it is done, for a reroll and for a kill alike.
## Headless: the dice draw nothing, but their effects keep their clocks.

const DiceView = preload("res://view/dice/dice_view.gd")
const GemCut = preload("res://view/dice/gem_cut.gd")
const BloodFx = preload("res://view/dice/blood_fx.gd")

var checks: int = 0
var failures: Array = []

func _init() -> void:
	DeepSaveStore.override_directory = "user://test_dice_looks"
	_looks()
	await _blood_layers()
	print("Dice looks: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _looks() -> void:
	for material in DeepDice.MATERIALS:
		var look: Dictionary = DiceView.look_of(str(material))
		check(not look.is_empty(), "%s has a shipped look" % material)
		check(bool(look.get("bleeds", false)) == (material == "blood"), "only blood bleeds (%s)" % material)
		if look.has("cut"):
			## A cut look names the passes it is drawn with and nothing else.
			check(look.has("solid") or (look.has("near") and look.has("far")), "%s's cut look has its passes" % material)
	check(DiceView.look_of("").is_empty(), "a die made of nothing in particular keeps the plain look")
	var names: Array = []
	for property in (DiceView as Script).get_script_property_list():
		names.append(str(property.name))
	check(not names.has("look_variant"), "no look under review is left to switch on")
	check(not (GemCut as Script).get_script_constant_map().has("OPTIONS") and not names.has("OPTIONS"), "no review options are left in gem_cut.gd")
	check(BloodFx.active("stream", 0.0) and BloodFx.active("thread", 0.0), "a reroll and a kill each have an effect")
	check(not BloodFx.active("stream", 10.0) and not BloodFx.active("thread", 10.0), "and both end")
	check(is_zero_approx(BloodFx.pulse("thread", float(BloodFx.SECONDS.thread))), "the vein pulse is back to nothing when the thread ends")

func _die(material: String) -> Control:
	var view := DiceView.new()
	view.live = false
	view.size = Vector2(88, 88)
	root.add_child(view)
	var faces: Array = []
	for i in range(20):
		faces.append({"value": i + 1, "kind": "plain"})
	view.configure({"id": "b", "shape": "D20", "material": material, "faces": faces}, {"die_id": "b", "face": 19, "value": 20}, false, false, Color.WHITE)
	view.settle_immediately()
	return view

func _blood_layers() -> void:
	var blood: Control = _die("blood")
	var ruby: Control = _die("ruby")
	await process_frame
	var before: int = blood.get_child_count()
	blood.blood_reroll(Vector2(10, 10))
	check(blood.bleeding() and blood.get_child_count() == before + 1, "a rerolled blood die puts up its effect's layer")
	blood.blood_fed(Vector2(400, 20))
	check(blood.get_child_count() == before + 1, "a kill during a reroll's effect takes its place on the same layer")
	await create_timer(float(BloodFx.SECONDS.thread) + 0.4).timeout
	await process_frame
	check(not blood.bleeding() and blood.get_child_count() == before, "the layer is freed once the effect is done (%d children, %d before)" % [blood.get_child_count(), before])
	var ruby_before: int = ruby.get_child_count()
	ruby.blood_reroll(Vector2(10, 10))
	ruby.blood_fed(Vector2(10, 10))
	check(not ruby.bleeding() and ruby.get_child_count() == ruby_before, "a die that does not bleed plays nothing")
	blood.visible = false
	blood.blood_fed(Vector2(10, 10))
	check(not blood.bleeding(), "a blood die nobody can see (another seat's page) plays nothing")
	blood.visible = true
	blood.blood_fed(Vector2(10, 10))
	blood.queue_free()
	await process_frame
	check(not is_instance_valid(blood), "a die freed mid-effect takes its layer with it")
	ruby.queue_free()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
