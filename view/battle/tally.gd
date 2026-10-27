extends Control
## A gem's arithmetic, counted out over its socket before what it does leaves it.
##
## A number is only felt if it is seen being made. The dice a gem read hop in the tray one
## after another and send what they showed up to the gem, where they add up in the left-hand
## box; then each multiplier the stone carries (a die of its own color, its weight in carats,
## a Flawless clarity, an inclusion, a Double Down, an Echo's share) flies in from where it
## comes from and stacks in the right-hand box; then the two are fused into the figure that
## lands, anything added on top lands on that, and only then does the bolt leave. Every tick
## climbs a step of the music's own scale in the gem's own voice, a rail that keeps firing
## climbs with it, and a gamepad feels each one. A figure big enough to finish what it hits
## catches fire.
##
## The rules have decided every number already (`DeepBattle.tally_of`, `creature_tally`);
## this only plays them, on the beat `DeepBattle.tally_span` reserved in the step and at the
## pace the host chose (Full, Quick, or Off, which shows only the figure), so the bolt leaves
## exactly when the step expects it to. An ally's gem is counted beside their card, smaller
## and quieter; a creature's blow beside its nameplate, an octave down. A gem with no figure
## to land (one that rerolls, or calls a phantom) has no boxes: its dice hop and send a glint
## to the socket, which is all it has to say.
##
## `show_sum` draws the same plate standing still, already worked out, for a gem the player
## is pointing at while the hand is still being chosen.

const DiceIcons = preload("res://view/dice/dice_icons.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")

## How far up the scale one rail may climb, in steps of it: two octaves less a little. Past
## that a tick is a whistle.
const TOP_STEP: int = 9
## Where in the scale a gem's count starts, at most: a long rail's later gems still have
## room to climb inside their own count.
const TOP_START: int = 5
## How each step a count lays on is said: its note under the number, its mark and its color.
const STEP_LOOKS: Dictionary = {
	"carat": ["carat", "e2b23a", ""], "clarity": ["clarity", "dff3ff", "Flawless"], "inclusions": ["prism", "76b6ff", "inclusion"],
	"amplify": ["double_up", "ffd76a", "amplified"], "echo": ["echo", "76b6ff", "Echo"],
	"depth": ["depth", "ff9a7a", "depth"], "empowered": ["rise", "ffb04a", "Empowered"],
	"bonus": ["spark", "76b6ff", "bonus"], "strength": ["flame", "ff9a5a", "Strength"], "rally": ["party", "ffb0a0", "Rallied"],
	"enrage": ["skull", "ff6a5a", "Enraged"], "curse": ["eye", "c58bff", "Cursed"]}

class Chain extends RefCounted:
	## A rail's run of counts, as pitch: each gem that fires starts its count a step higher up
	## the music's scale than the one before, so a rail that keeps firing is heard to climb.
	## Begun again with every rail, in whatever key is playing then.
	var fired: int = 0
	var _key: Dictionary = {"pc": 0, "steps": [0, 2, 4, 7, 9]}

	func reset() -> void:
		fired = 0
		_key = DeepMusic.tonic()

	func pitch(step: int, octaves: int = 2) -> float:
		## The pitch scale that puts a sound tuned to C on this step of the scale, in a key
		## never more than half an octave from C, so nothing starts out shrill or muddy. A
		## heavier sound climbs fewer `octaves` before it folds back down: a chord pitched as
		## high as a tick would squeal.
		var steps: Array = _key.get("steps", [0, 2, 4, 7, 9])
		var at: int = clampi(step, 0, TOP_STEP)
		var pc: int = int(_key.get("pc", 0))
		var shift: int = pc if pc <= 6 else pc - 12
		var semis: int = shift + 12 * mini(at / steps.size(), maxi(0, octaves)) + int(steps[at % steps.size()])
		return pow(2.0, float(semis) / 12.0)

## What the screen hands the count, asked for as it needs them rather than held: a tray or a
## rail rebuilt mid-count must not leave it pointing at controls that are gone.
## () -> Control: the socket card the gem sits in, an ally's card, a creature's nameplate.
var gem_anchor: Callable = Callable()
## (die_id) -> Control: the die in the tray (or among the phantoms, or on a nameplate), or null.
var die_anchor: Callable = Callable()
## () -> Vector2: where the fused figure flies (global), or Vector2.INF for nowhere.
var destination: Callable = Callable()
## () -> float: the lowest the plate's bottom edge may sit (global y), so it stands clear of
## the dock; INF for no limit.
var ceiling: Callable = Callable()
## (total: int, blazing: bool) -> void: told as the figure is fused, for the room to answer it.
var on_fuse: Callable = Callable()
var chain: Chain = null
var start_step: int = 0
## The gem's own color, the name it is counted under, and the voice its ticks are in.
var color: Color = Color.WHITE
var caption: String = ""
var tick: String = "tally_tick"
## The skill alone, for the step its own formula adds (a Crush's five times its set).
var skill: String = ""
## Where the plate stands against its anchor: "above" a socket, "left" of an ally's card,
## "right" of a creature's nameplate (or left of it, if the screen ends first).
var placement: String = "above"
## Smaller type, for a count that is not the reader's own.
var compact: bool = false
var volume: float = 1.0
## Pitch over the chain's: a creature counts an octave down.
var register: float = 1.0
## Whether the reader's pad feels it: only their own counts.
var rumbles: bool = true
## The figure finishes what it hits.
var blaze: bool = false
## The mark on the multiplier box: a stone's weight is in carats, a creature's in its depth.
var mult_glyph: String = "carat"
## A soak (see `soak`): () -> Control where the block flies from, and what to do as the block
## lands (block: int) and as the rest bleeds into the health bar (hp: int).
var shield: Callable = Callable()
var on_soaked: Callable = Callable()
var on_bled: Callable = Callable()

var _tally: Dictionary = {}
var _numbered: bool = false
var _pace: float = 1.0
var _step: int = 0
var _column: VBoxContainer
var _row: HBoxContainer
var _base_box: PanelContainer
var _base_label: Label
var _mult_box: PanelContainer
var _mult_label: Label
var _total_box: PanelContainer
var _total_label: Label
var _base: int = 0
var _mult: float = 1.0
var _total: int = 0
var _kind_tone: Color = DeepUi.PAPER

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45

func play(tally: Dictionary) -> void:
	## Counts this tally out from now. The plate frees itself once the figure has flown.
	_tally = tally
	_numbered = tally.has("amount")
	_pace = clampf(float(tally.get("pace", 1.0)), 0.0, 1.0)
	_step = start_step
	var dice: Array = _in_tray_order(tally.get("dice", []))
	var link: String = str(tally.get("link", {}).get("op", ""))
	## Whether the dice add up to the skill's number, each sending its own figure; otherwise
	## they only glint, and the number they woke is shown once they have.
	var dice_add: bool = link.is_empty()
	var timeline := create_tween().set_parallel(true)
	if _pace <= 0.0:
		## Counts are off: only the figure, for a moment, then it flies.
		if not _numbered:
			queue_free()
			return
		_build()
		_place()
		_appear()
		timeline.tween_callback(_fuse.bind(true)).set_delay(0.0)
		timeline.tween_callback(_launch).set_delay(DeepBattle.TALLY_GLANCE)
		return
	var at: float = 0.0
	if _numbered:
		_build()
		_place()
		_appear()
		if dice.is_empty():
			## Nothing on the dice to count: the skill's own number is there from the start,
			## set as soon as the plate has been laid out.
			timeline.tween_callback(_reveal_base).set_delay(0.0)
			dice_add = true
		elif not dice_add:
			## Not a sum the dice will build: the skill's own number waits in the box, dimmed,
			## and lights when the dice wake it. A dash there read as nothing, or as broken.
			_base_label.text = DeepUi.number(int(tally.get("link", {}).get("from", tally.get("base", 0))))
			_base_box.modulate = Color(1, 1, 1, 0.45)
	if not dice.is_empty():
		var gap: float = DeepBattle.tally_die_gap(dice.size()) * _pace
		for i in range(dice.size()):
			timeline.tween_callback(_count_die.bind(dice[i], dice_add)).set_delay(gap * float(i))
		at = gap * float(dice.size() - 1) + DeepBattle.TALLY_FLIGHT * _pace
		if _numbered and not dice_add:
			## The dice only woke it: the number (or the face their set shows) is the skill's
			## own, and shows once they have.
			timeline.tween_callback(_reveal_base).set_delay(at)
	if not _numbered:
		timeline.tween_callback(queue_free).set_delay(at + 0.35)
		return
	var laid: Array = []
	if link == "x":
		laid.append({"what": "link", "op": link, "by": int(tally.link.get("by", 0))})
	laid.append_array(tally.get("mults", []))
	var adds: Array = tally.get("adds", [])
	var step_gap: float = DeepBattle.tally_step_gap(DeepBattle.tally_weights(tally)) * _pace
	for entry in laid:
		var beat: float = step_gap * DeepBattle.tally_weight(entry)
		timeline.tween_callback(_lay.bind(entry, beat)).set_delay(at)
		at += beat
	timeline.tween_callback(_fuse.bind(false)).set_delay(at)
	at += DeepBattle.TALLY_FUSE * _pace
	for entry in adds:
		timeline.tween_callback(_add.bind(entry, step_gap)).set_delay(at)
		at += step_gap
	timeline.tween_callback(_launch).set_delay(at)

func show_sum(tally: Dictionary) -> void:
	## The same plate standing still, already worked out: what the gem would come to on the
	## hand as it lies. Nothing moves and nothing sounds; the screen takes it away.
	_tally = tally
	_numbered = true
	_build()
	var link: Dictionary = tally.get("link", {})
	if str(link.get("op", "")) == "x":
		_base_label.text = "%d×%d" % [int(link.get("from", 0)), int(link.get("by", 0))]
	else:
		_base_label.text = DeepUi.number(int(tally.get("base", 0)))
	var product: float = 1.0
	for entry in tally.get("mults", []):
		product *= float(entry.get("x", 1.0))
	_mult_label.text = times(product).substr(1)
	for entry in tally.get("adds", []):
		var by: int = int(entry.get("by", 0))
		var look: Array = STEP_LOOKS.get(str(entry.get("what", "")), ["spark", "76b6ff", ""])
		var added := DeepUi.label(_row, ("+" + DeepUi.number(by)) if by >= 0 else ("−" + DeepUi.number(-by)), 18, Color(str(look[1])))
		added.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
		added.add_theme_constant_override("outline_size", 5)
		added.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var equals := DeepUi.label(_row, "=", 24, DeepUi.PAPER)
	equals.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
	equals.add_theme_constant_override("outline_size", 5)
	equals.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var total := _box(_row, _kind_tone)
	var line := DeepUi.hbox(total, 4)
	_number(line, DeepUi.number(int(tally.get("amount", 0))), 28, _kind_tone.lightened(0.3))
	if int(tally.get("repeat", 1)) > 1:
		_number(line, "×%d" % int(tally.repeat), 18, DeepUi.PAPER)
	_place()
	_column.modulate.a = 0.0
	_column.create_tween().tween_property(_column, "modulate:a", 1.0, 0.1)

func soak(incoming: int, absorbed: int, loss: int, pace: float) -> void:
	## A blow on the reader that block took part of, counted at the health bar: what came in,
	## the block flying off the shield to meet it and taking its share, then what is left
	## dropping into the bar, on the beat `DeepBattle.SOAK_SPAN` reserved for it.
	_tally = {"kind": "damage"}
	_kind_tone = DeepUi.BAD
	_pace = clampf(pace, 0.05, 1.0)
	_column = DeepUi.vbox(self, 2)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_total_box = _box(_column, DeepUi.BAD)
	var line := DeepUi.hbox(_total_box, 6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(line, "sword", 24.0, DeepUi.BAD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_total_label = _number(line, str(incoming), 30, DeepUi.BAD.lightened(0.3))
	_total = incoming
	_place()
	_appear()
	var span: float = DeepBattle.SOAK_SPAN * _pace
	var timeline := create_tween().set_parallel(true)
	timeline.tween_callback(_soak_block.bind(absorbed, loss, span * 0.35)).set_delay(span * 0.2)
	timeline.tween_callback(_soak_bleed.bind(loss)).set_delay(span * 0.72)

func _soak_block(absorbed: int, loss: int, seconds: float) -> void:
	var found: Variant = shield.call() if shield.is_valid() else null
	var source: Control = found as Control if found is Control and is_instance_valid(found) else null
	var from: Vector2 = _centre(source) if source != null else _centre(_total_box) + Vector2(0, 60)
	_fly(from, _centre(_total_box), "−" + DeepUi.number(absorbed), "block", DeepUi.BLOCK, maxf(0.06, seconds), _soaked.bind(absorbed, loss), "shield")

func _soaked(absorbed: int, loss: int) -> void:
	_total = loss
	_total_label.text = DeepUi.number(loss) if loss > 0 else "0"
	_total_label.add_theme_color_override("font_color", DeepUi.BAD.lightened(0.3) if loss > 0 else DeepUi.BLOCK)
	DeepUi.spring(_total_box, -0.18, 6.0, 0.36)
	_sparks(_centre(_total_box), DeepUi.BLOCK, 14, 130.0)
	_rumble(0.2, 0.0, 0.04)
	if on_soaked.is_valid():
		on_soaked.call(absorbed)

func _soak_bleed(loss: int) -> void:
	## What is left goes into the health bar; with nothing left, the plate only says so and goes.
	set_process(false)
	var tween := create_tween().set_parallel(true)
	if loss <= 0:
		tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.1)
		tween.chain().tween_callback(queue_free)
		if on_bled.is_valid():
			on_bled.call(0)
		return
	var anchor: Control = _anchor()
	var to: Vector2 = _centre(anchor) if anchor != null else global_position
	tween.tween_property(self, "global_position", to - size * 0.5, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * 0.5, 0.14)
	tween.tween_property(self, "modulate:a", 0.0, 0.06).set_delay(0.1)
	tween.chain().tween_callback(func() -> void:
		if on_bled.is_valid():
			on_bled.call(loss)
		queue_free())

func _appear() -> void:
	## In from small, overshooting and settling, like everything else the count does.
	_column.modulate.a = 0.0
	_column.create_tween().tween_property(_column, "modulate:a", 1.0, 0.06)
	DeepUi.spring(_column, -0.45, 4.0, 0.45)

func _process(_delta: float) -> void:
	if _column != null:
		_place()

# --- the plate ---------------------------------------------------------------------------------

static func kind_look(kind: String) -> Array:
	## A figure's mark and color: the ones the forecast and the floating numbers use.
	match kind:
		"damage": return ["sword", DeepUi.BAD]
		"block", "retain": return ["shield", DeepUi.BLOCK]
		"heal", "regeneration": return ["heart", DeepUi.GOOD]
		"poison": return ["drop", DeepUi.POISON]
		"gold": return ["coin", DeepUi.ORE]
		"spikes": return ["caltrop", Color("ffa36b")]
	return ["spark", DeepUi.PAPER]

static func times(x: float) -> String:
	## A multiplier as it is written on the plate: ×2.5, ×3.75, ×2, never ×2.50; a vast one is
	## shortened the way a count is (×1.2M), and one past counting is Infinite.
	if x >= 1000000.0:
		return "×" + DeepUi.number(DeepRules.sat_floor(x))
	var text: String = ("%.2f" % x).rstrip("0").rstrip(".")
	return "×" + text

func _build() -> void:
	var look: Array = kind_look(str(_tally.get("kind", "")))
	_kind_tone = look[1]
	var big: int = 18 if compact else 28
	_column = DeepUi.vbox(self, 2)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	if not caption.is_empty():
		var name_label := DeepUi.heading(_column, caption, 12, color.lightened(0.35))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.9))
		name_label.add_theme_constant_override("outline_size", 4)
	_row = DeepUi.hbox(_column, 5)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_base_box = _box(_row, _kind_tone)
	var base_row := DeepUi.hbox(_base_box, 4)
	DeepUi.icon(base_row, str(look[0]), 16.0 if compact else 24.0, _kind_tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_base_label = _number(base_row, "0", big, _kind_tone.lightened(0.25))
	_base_label.custom_minimum_size.x = 22.0 if compact else 34.0
	## The sign between the two boxes, in the body face: the display face has no times sign.
	var sign := DeepUi.label(_row, "×", 18 if compact else 24, DeepUi.PAPER)
	sign.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
	sign.add_theme_constant_override("outline_size", 5)
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mult_box = _box(_row, DeepUi.ACCENT)
	var mult_row := DeepUi.hbox(_mult_box, 4)
	DeepUi.icon(mult_row, mult_glyph, 14.0 if compact else 22.0, DeepUi.ACCENT_HI).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mult_label = _number(mult_row, "1", big - 2, DeepUi.ACCENT_HI)
	_mult_label.custom_minimum_size.x = 18.0 if compact else 28.0
	## Struck no stronger than it was: the box stays, dim, so the place a multiplier would
	## land is learned before the first heavy stone ever fills it.
	if _tally.get("mults", []).is_empty():
		_mult_box.modulate = Color(1, 1, 1, 0.45)

func _box(parent: Control, edge: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", DeepUi.flat(Color(0.03, 0.04, 0.07, 0.92), Color(edge, 0.85), 6, 5 if compact else 8, 2))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func _number(parent: Control, text: String, size: int, tone: Color) -> Label:
	var number := DeepUi.title(parent, text, size, tone, HORIZONTAL_ALIGNMENT_CENTER)
	number.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
	number.add_theme_constant_override("outline_size", 6)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return number

func _anchor() -> Control:
	var found: Variant = gem_anchor.call() if gem_anchor.is_valid() else null
	return found as Control if found is Control and is_instance_valid(found) and (found as Control).is_inside_tree() else null

func _place() -> void:
	## Over its socket and clear of the dock, beside an ally's card or a creature's plate;
	## never off the screen. Asked again every frame: the socket springs, the plate drifts
	## after its creature, the window can change.
	var anchor: Control = _anchor()
	if anchor == null or _column == null:
		return
	var wanted: Vector2 = _column.get_combined_minimum_size()
	_column.size = wanted
	size = wanted
	pivot_offset = wanted * 0.5
	var rect: Rect2 = anchor.get_global_rect()
	var screen: Rect2 = get_viewport_rect()
	var at: Vector2
	match placement:
		"left":
			at = Vector2(rect.position.x - wanted.x - 14.0, rect.get_center().y - wanted.y * 0.5)
		"right":
			at = Vector2(rect.end.x + 12.0, rect.get_center().y - wanted.y * 0.5)
			if at.x + wanted.x > screen.size.x - 8.0:
				at.x = rect.position.x - wanted.x - 12.0
		_:
			at = Vector2(rect.get_center().x - wanted.x * 0.5, rect.position.y - wanted.y - 10.0)
			var lowest: float = float(ceiling.call()) if ceiling.is_valid() else INF
			at.y = minf(at.y, lowest - wanted.y)
	at.x = clampf(at.x, 8.0, maxf(8.0, screen.size.x - wanted.x - 8.0))
	at.y = clampf(at.y, 8.0, maxf(8.0, screen.size.y - wanted.y - 8.0))
	global_position = at

func _in_tray_order(dice: Array) -> Array:
	## Counted left to right as they lie, the way the eye reads them; phantoms and anything
	## not on screen after.
	if not die_anchor.is_valid():
		return dice
	var placed: Array = dice.duplicate()
	placed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _die_x(str(a.get("id", ""))) < _die_x(str(b.get("id", ""))))
	return placed

func _die_x(id: String) -> float:
	var found: Variant = die_anchor.call(id)
	return (found as Control).get_global_rect().get_center().x if found is Control and is_instance_valid(found) else INF

func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center() if control != null and is_instance_valid(control) else Vector2.INF

# --- the beats -----------------------------------------------------------------------------------

func _count_die(entry: Dictionary, adds: bool) -> void:
	## One die counted: it hops where it lies and its number (or a glint, where the dice only
	## woke the gem) flies to the plate.
	var found: Variant = die_anchor.call(str(entry.get("id", ""))) if die_anchor.is_valid() else null
	var die: Control = found as Control if found is Control and is_instance_valid(found) else null
	var material: String = str(entry.get("material", ""))
	var tint: Color = DiceIcons.material_palette(material).get("body", DeepUi.PAPER) if not material.is_empty() else DeepUi.PAPER
	var from: Vector2 = _centre(die) if die != null else _centre(_anchor())
	if die != null:
		if die.has_method("pop"):
			die.call("pop", 1.0, tint if not material.is_empty() else color.lightened(0.3))
		else:
			DeepUi.spring(die, 0.3, 10.0, 0.4)
		from.y -= die.size.y * 0.4
	_voice(tick, from, 0.5 + 0.04 * float(_step - start_step))
	_rumble(0.16, 0.0, 0.03)
	var value: int = int(entry.get("value", 0))
	var to: Vector2 = _centre(_base_box) if _numbered else _centre(_anchor())
	_step += 1
	_fly(from, to, ("+%d" % value) if adds and _numbered else "", "", tint, DeepBattle.TALLY_FLIGHT * _pace, _die_landed.bind(value, adds))

func _die_landed(value: int, adds: bool) -> void:
	if _numbered and adds:
		_set_base(_base + value)
	elif not _numbered:
		var anchor: Control = _anchor()
		if anchor != null:
			DeepUi.spring(anchor, 0.08, 3.0, 0.3)

func _reveal_base() -> void:
	## The dice have woken the gem; the number is its own (or the face of their set, which
	## the skill is about to take so many times over), lit now.
	if _base_box != null:
		_base_box.modulate = Color.WHITE
	_set_base(int(_tally.get("link", {}).get("from", _tally.get("base", 0))))
	_voice(tick, _centre(_base_box), 0.55)
	_step += 1

func _lay(entry: Dictionary, seconds: float) -> void:
	## One step between the dice and the fuse: the skill's own ×5 onto the face of its set,
	## or a multiplier into the right-hand box, flown in from where it comes from.
	var what: String = str(entry.get("what", ""))
	var source: Control = _anchor()
	var look: Array = STEP_LOOKS.get(what, ["spark", "ffd76a", ""])
	var tint: Color = Color(str(look[1]))
	var note: String = str(look[2])
	var glyph: String = str(look[0])
	var text: String = times(float(entry.get("x", 1.0)))
	match what:
		"link":
			text = "×%d" % int(entry.get("by", 0))
			tint = DeepUi.PAPER
			note = skill
			glyph = ""
		"material":
			var material: String = str(entry.get("material", ""))
			tint = DiceIcons.material_palette(material).get("body", DeepUi.ACCENT_HI)
			note = DeepDice.material_name(material)
			glyph = "die"
			var found: Variant = die_anchor.call(str(entry.get("die", ""))) if die_anchor.is_valid() else null
			if found is Control and is_instance_valid(found):
				source = found
				if (found as Control).has_method("pop"):
					(found as Control).call("pop", 1.3, tint)
		"carat":
			var weight: float = float(entry.get("weight", 1.0))
			note = ("%d carats" % int(weight)) if is_equal_approx(weight, round(weight)) else ("%.1f carats" % weight)
	var from: Vector2 = _centre(source)
	if source != null:
		from.y -= source.size.y * 0.35
	var to: Vector2 = _centre(_base_box if what == "link" else _mult_box)
	var step: int = _step
	_step += 1
	_fly(from, to, text, note, tint, clampf(seconds * 0.6, 0.05, 0.24), _laid.bind(what, float(entry.get("x", 1.0)), tint, step), glyph)

func _laid(what: String, x: float, tint: Color, step: int) -> void:
	if what == "link":
		_set_base(int(_tally.get("base", 0)))
		_voice(tick, _centre(_base_box), 0.6, step)
		return
	_mult *= x
	_mult_box.modulate = Color.WHITE
	_mult_label.text = times(_mult).substr(1)
	DeepUi.spring(_mult_box, 0.28, 8.0, 0.42)
	_sparks(_centre(_mult_box), tint, 12, 120.0)
	_voice("tally_mult", _centre(_mult_box), 0.75, step)
	_rumble(0.22, 0.32, 0.06)

func _fuse(whole: bool) -> void:
	## The sum and the multiplier become one figure: what will land, before anything is added
	## to every blow (or, with the counts off, all of it at once).
	var added: int = 0
	if not whole:
		for entry in _tally.get("adds", []):
			added += int(entry.get("by", 0))
	_total = int(_tally.get("amount", 0)) - added
	var centre: Vector2 = _centre(_row)
	## The two boxes are drawn together into the middle as light, and go.
	for box in [_base_box, _mult_box]:
		_streak(_centre(box), centre, _kind_tone if box == _base_box else DeepUi.ACCENT_HI)
	_row.visible = false
	var tone: Color = Color("ffcf5a") if blaze else _kind_tone
	if blaze:
		var lethal := DeepUi.heading(_column, "Lethal", 12, Color("ffb04a"))
		lethal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lethal.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.9))
		lethal.add_theme_constant_override("outline_size", 4)
	_total_box = _box(_column, tone)
	var line := DeepUi.hbox(_total_box, 6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	var look: Array = kind_look(str(_tally.get("kind", "")))
	var size_now: int = (22 if compact else 34) + mini(12, _total / 8)
	DeepUi.icon(line, str(look[0]), float(size_now) * 0.8, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_total_label = _number(line, DeepUi.number(_total), size_now, tone.lightened(0.3))
	if int(_tally.get("repeat", 1)) > 1:
		var over := _number(line, "×%d" % int(_tally.repeat), maxi(14, size_now - 10), DeepUi.PAPER)
		over.tooltip_text = "Lands this many times"
	if blaze:
		_ignite(_total_box)
	DeepUi.spring(_total_box, 0.42 if blaze else 0.36, 9.0 if blaze else 7.0, 0.55 if blaze else 0.5)
	_sparks(centre, tone, 34 if blaze else 22, 220.0 if blaze else 170.0)
	_voice("tally_fuse", centre, 0.8, _step)
	if blaze:
		DeepAudio.play_at(centre, "tally_blaze", {"volume": 0.8 * volume, "gap": 0.0})
	_rumble(0.45 if blaze else 0.35, 0.8 if blaze else 0.55, 0.16 if blaze else 0.09)
	_step += 1
	if on_fuse.is_valid():
		on_fuse.call(_total, blaze)

func _ignite(box: Control) -> void:
	## A figure that finishes what it hits catches fire: flames licking up off the box until
	## it leaves.
	var flames := CPUParticles2D.new()
	flames.amount = 24 if ScreenFx.calm else 64
	flames.lifetime = 0.45
	flames.texture = DeepUi.glow_texture()
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flames.direction = Vector2.UP
	flames.spread = 18.0
	flames.initial_velocity_min = 60.0
	flames.initial_velocity_max = 150.0
	flames.gravity = Vector2(0, -80)
	flames.scale_amount_min = 0.14
	flames.scale_amount_max = 0.34
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	flames.scale_amount_curve = curve
	var heat := Gradient.new()
	heat.set_color(0, Color(1.0, 0.97, 0.7, 1.0))
	heat.add_point(0.35, Color(1.0, 0.6, 0.15, 0.95))
	heat.set_color(1, Color(0.8, 0.15, 0.05, 0.0))
	flames.color_ramp = heat
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flames.material = additive
	flames.show_behind_parent = true
	box.add_child(flames)
	var fit := func() -> void:
		## Off the top edge, from behind the box, so the figure itself is never covered.
		flames.position = Vector2(box.size.x * 0.5, 4.0)
		flames.emission_rect_extents = Vector2(box.size.x * 0.45, 3.0)
	box.resized.connect(fit)
	fit.call()
	flames.emitting = true

func _add(entry: Dictionary, seconds: float) -> void:
	## Something every blow carries on top of the fused figure: Strength, an inclusion's bonus,
	## a creature's rallying or its enrage; or a Curse taking a share back off.
	var what: String = str(entry.get("what", ""))
	var by: int = int(entry.get("by", 0))
	var look: Array = STEP_LOOKS.get(what, ["spark", "76b6ff", "bonus"])
	var source: Control = _anchor()
	var from: Vector2 = _centre(source)
	if source != null:
		from.y -= source.size.y * 0.35
	var step: int = _step
	_step += 1
	_fly(from, _centre(_total_box), ("+" + DeepUi.number(by)) if by >= 0 else ("−" + DeepUi.number(-by)), str(look[2]), Color(str(look[1])),
		clampf(seconds * 0.6, 0.05, 0.24), _added.bind(by, step), str(look[0]))

func _added(by: int, step: int) -> void:
	_total = DeepRules.sat_add(_total, by)
	if _total_label != null:
		_total_label.text = DeepUi.number(_total)
	DeepUi.spring(_total_box, 0.2 if by >= 0 else -0.12, 5.0, 0.36)
	_voice(tick, _centre(_total_box), 0.6, step if by >= 0 else maxi(0, step - 3))

func _launch() -> void:
	## Gone: the figure flies toward what it lands on, as the bolt (or the blow) leaves.
	set_process(false)
	if _total_box == null:
		queue_free()
		return
	var found: Variant = destination.call() if destination.is_valid() else Vector2.INF
	var to: Vector2 = found if found is Vector2 else Vector2.INF
	var tween := create_tween()
	if not to.is_finite():
		tween.set_parallel(true)
		tween.tween_property(self, "position:y", position.y - 30.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(queue_free)
		return
	## Out of the plate's own frame and toward what it lands on, shrinking as it goes.
	var target: Vector2 = to - size * 0.5
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * 0.45, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.08).set_delay(0.14)
	tween.chain().tween_callback(queue_free)

# --- the pieces of it ------------------------------------------------------------------------------

func _set_base(value: int) -> void:
	_base = value
	if _base_label == null:
		return
	_base_label.text = DeepUi.number(value)
	DeepUi.spring(_base_box, 0.26, 7.0, 0.4)
	_sparks(_centre(_base_box), _kind_tone, 8, 90.0)

func _sparks(at: Vector2, tint: Color, amount: int, speed: float) -> void:
	## A spray where something landed, in the screen's own frame; thinner with fewer flashes.
	var parent: Control = get_parent() as Control
	if parent == null or not at.is_finite():
		return
	DeepUi.burst(parent, at - parent.get_global_rect().position, tint, maxi(4, amount / 3) if ScreenFx.calm else amount, speed, 0.4, 4.0)

func _fly(from: Vector2, to: Vector2, text: String, note: String, tint: Color, seconds: float, landed: Callable, glyph: String = "") -> void:
	## A chip carrying a number (or a glint, with no number) from where it comes from to where
	## it lands, along a bow, trailing sparks of its own color.
	if not from.is_finite() or not to.is_finite():
		landed.call()
		return
	var chip := Control.new()
	chip.top_level = true
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.z_index = 5
	add_child(chip)
	## The trail first, so it is drawn under the number it follows.
	var trail := CPUParticles2D.new()
	chip.add_child(trail)
	var body: Control
	if text.is_empty():
		body = DeepUi.icon(chip, "spark", 20.0, tint.lightened(0.3))
	else:
		var column := DeepUi.vbox(chip, -2)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var line := DeepUi.hbox(column, 3)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		if not glyph.is_empty():
			DeepUi.icon(line, glyph, 16.0, tint).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_number(line, text, 18 if compact else 22, tint.lightened(0.2))
		if not note.is_empty():
			var said := DeepUi.label(column, note, 12 if compact else 14, tint.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER)
			said.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
			said.add_theme_constant_override("outline_size", 4)
		body = column
	var half: Vector2 = body.get_combined_minimum_size() * 0.5
	body.size = half * 2.0
	chip.pivot_offset = half
	trail.local_coords = false
	trail.amount = 16
	trail.lifetime = 0.24
	trail.texture = DeepUi.dot_texture()
	trail.spread = 180.0
	trail.initial_velocity_min = 6.0
	trail.initial_velocity_max = 26.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 0.14
	trail.scale_amount_max = 0.34
	var fade := Gradient.new()
	fade.set_color(0, Color(tint.lightened(0.45), 0.95))
	fade.set_color(1, Color(tint, 0.0))
	trail.color_ramp = fade
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = add
	trail.position = half
	trail.emitting = true
	## A bow up and across: higher the further it has to go, a little to one side.
	var bend: Vector2 = (from + to) * 0.5 + Vector2(randf_range(-24.0, 24.0), -30.0 - absf(to.x - from.x) * 0.12)
	chip.global_position = from - half
	var tween := chip.create_tween()
	tween.tween_method(func(t: float) -> void:
		var eased: float = 1.0 - pow(1.0 - t, 2.2)
		chip.global_position = from.lerp(bend, eased).lerp(bend.lerp(to, eased), eased) - half
		chip.scale = Vector2.ONE * (lerpf(1.35, 0.85, t) if not text.is_empty() else lerpf(1.0, 0.6, t))
		, 0.0, 1.0, maxf(0.05, seconds))
	tween.tween_callback(func() -> void:
		body.visible = false
		trail.emitting = false
		landed.call())
	tween.tween_interval(trail.lifetime + 0.05)
	tween.tween_callback(chip.queue_free)

func _streak(from: Vector2, to: Vector2, tint: Color) -> void:
	## A box drawn into the middle as light.
	if not from.is_finite() or not to.is_finite():
		return
	var glow := TextureRect.new()
	glow.texture = DeepUi.glow_texture()
	glow.top_level = true
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(70, 70)
	glow.pivot_offset = glow.size * 0.5
	glow.modulate = Color(tint.lightened(0.3), 0.9)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.z_index = 6
	add_child(glow)
	glow.global_position = from - glow.size * 0.5
	var tween := glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "global_position", to - glow.size * 0.5, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "scale", Vector2.ONE * 1.6, 0.16)
	tween.tween_property(glow, "modulate:a", 0.0, 0.16).set_delay(0.06)
	tween.chain().tween_callback(glow.queue_free)

func _voice(sound: String, at: Vector2, loudness: float, step: int = -1) -> void:
	## A tick of the count, a step up the scale: placed where it happens, never wandering off
	## its note, and never swallowed for following the last one too closely.
	var octaves: int = {"tally_mult": 1, "tally_fuse": 0}.get(sound, 2)
	var pitch: float = (chain.pitch(step if step >= 0 else _step, octaves) if chain != null else 1.0) * register
	var opts: Dictionary = {"pitch": pitch, "vary": 0.0, "gap": 0.0, "volume": loudness * volume}
	if at.is_finite():
		DeepAudio.play_at(at, sound, opts)
	else:
		DeepAudio.play(sound, opts)

func _rumble(weak: float, strong: float, seconds: float) -> void:
	if rumbles:
		DeepAudio.rumble(weak, strong, seconds)
