extends Control
## The player's vitals on the dock (docs/UI_REDO.md): their face in a round plate, their
## health as a ring round it (easing to its new share, with a pale ghost of what was lost
## trailing it and a hatched red share of what a counted blow will take), and one capsule
## under the ring with the health numbers. Block is its own number, on a badge at the top of
## the ring, and an arc outside the ring that grows both ways round from the top: a full
## circle when block matches their health, and past that the arc thickens and brightens and
## a lattice of pale blue hexagons comes up over the face, stronger up to three times their
## health. It answers the same calls the kit's Bar does (`set_values`, `preview`, `warn`,
## `fill`), so the fight's counts land on it unchanged.

const Roster = preload("res://view/home/roster.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")

## Block past the health it matches, as a share of that health, at which the armour is at
## its fullest.
const OVERFLOW: float = 2.0

var ratio: float = 1.0
var fill: Color = DeepUi.HP
var warn: bool = true
var text: String = ""
## Block as a share of full health: one is a whole ring, up to three.
var overlay: float = 0.0
var overlay_color: Color = DeepUi.BLOCK
## A share of the ring shown pulsing at the end of the fill: what is about to be lost.
var preview: float = 0.0:
	set(value):
		if not is_equal_approx(value, preview):
			preview = value
			set_process(true)
var portrait: Roster.Portrait
## The capsule under the ring: the health numbers.
var plate: PanelContainer
## The badge at the top of the ring: the block number, while there is any.
var shield_badge: PanelContainer
var _hp_label: Label
var _shield_label: Label
var _hexes: Control
var _edge: float = 156.0
var _face: float = 109.0
var _shown: float = -1.0
var _ghost: float = 1.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _clock: float = 0.0
var _shown_overlay: float = 0.0

func _init(edge: float = 156.0, character: String = "") -> void:
	_edge = edge
	custom_minimum_size = Vector2(edge, edge + 10.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_face = edge * 0.7
	portrait = Roster.Portrait.new(character, Vector2(_face, _face))
	portrait.round = true
	portrait.position = Vector2((edge - _face) * 0.5, (edge - _face) * 0.5)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	## The lattice over the face, drawn only once block runs past the health it matches.
	_hexes = Control.new()
	_hexes.position = portrait.position
	_hexes.size = Vector2(_face, _face)
	_hexes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hexes.draw.connect(_draw_hexes)
	add_child(_hexes)
	plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", DeepUi.capsule(plate, DeepUi.LEDGER_SHADOW, DeepUi.LEDGER_LINE, 2, 14, 2))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	_hp_label = DeepUi.label(plate, "", 14, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.add_theme_font_override("font", DeepUi.bold_font())
	shield_badge = PanelContainer.new()
	shield_badge.add_theme_stylebox_override("panel", DeepUi.capsule(shield_badge, Color("0b1a33"), DeepUi.BLOCK, 2, 12, 1))
	shield_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_badge.z_index = 2
	shield_badge.visible = false
	add_child(shield_badge)
	var row := DeepUi.hbox(shield_badge, 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var shield := DeepUi.icon(row, "shield", 13, DeepUi.BLOCK)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_label = DeepUi.label(row, "", 14, Color("dbe8ff"))
	_shield_label.add_theme_font_override("font", DeepUi.bold_font())
	plate.resized.connect(_place_plates)
	shield_badge.resized.connect(_place_plates)
	resized.connect(_place_plates)

func _place_plates() -> void:
	plate.position = Vector2((_edge - plate.size.x) * 0.5, _edge - plate.size.y * 0.5 - 1.0).round()
	shield_badge.position = Vector2((_edge - shield_badge.size.x) * 0.5, -shield_badge.size.y * 0.5 + 1.0).round()

func set_values(new_ratio: float, new_text: String = "", new_overlay: float = 0.0, block_words: String = "") -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	if _shown < 0.0 or not is_inside_tree() or DeepUi.headless():
		_shown = new_ratio
		_ghost = new_ratio
	elif not is_equal_approx(new_ratio, ratio):
		_flash = 1.0
		_flash_color = Color(1, 0.35, 0.3) if new_ratio < ratio else Color(0.6, 1, 0.7)
		if new_ratio > _ghost:
			_ghost = new_ratio
	ratio = new_ratio
	text = new_text
	overlay = clampf(new_overlay, 0.0, 1.0 + OVERFLOW)
	if DeepUi.headless() or not is_inside_tree():
		_shown_overlay = overlay
	_hp_label.text = new_text
	shield_badge.visible = not block_words.is_empty()
	_shield_label.text = block_words
	plate.reset_size()
	shield_badge.reset_size()
	_place_plates()
	set_process(true)
	queue_redraw()
	_hexes.queue_redraw()

func _armour() -> float:
	## How far block has run past the health it matches, nought to one.
	return clampf((_shown_overlay - 1.0) / OVERFLOW, 0.0, 1.0)

func _process(delta: float) -> void:
	_clock += delta
	var settled := true
	if not is_equal_approx(_shown, ratio):
		_shown = move_toward(_shown, ratio, maxf(0.4, absf(ratio - _shown) * 6.0) * delta)
		settled = false
	if _ghost > _shown:
		if _clock > 0.35:
			_ghost = move_toward(_ghost, _shown, 0.55 * delta)
		settled = false
	else:
		_ghost = _shown
		_clock = 0.0
	if not is_equal_approx(_shown_overlay, overlay):
		_shown_overlay = move_toward(_shown_overlay, overlay, 2.5 * delta)
		settled = false
		_hexes.queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		settled = false
	if preview > 0.0:
		settled = false
	## The lattice breathes while there is armour to show.
	if _armour() > 0.0 and not ScreenFx.calm:
		settled = false
		_hexes.queue_redraw()
	queue_redraw()
	if settled:
		_clock = 0.0
		set_process(false)

func _draw() -> void:
	var centre := Vector2(_edge, _edge) * 0.5
	var r_hp: float = _edge * 0.405
	var w_hp: float = maxf(6.0, _edge * 0.062)
	var r_block: float = _edge * 0.468
	var armour: float = _armour()
	## Past a whole ring the arc thickens, up to twice its width.
	var w_block: float = maxf(3.0, _edge * 0.028) * (1.0 + armour)
	var start: float = -PI * 0.5
	## The plate behind the face, then the health track in the dock's own dark.
	draw_circle(centre, r_hp - w_hp * 0.5, DeepUi.LEDGER_FILL)
	draw_arc(centre, r_hp, 0.0, TAU, 96, DeepUi.LEDGER_SHADOW, w_hp + 4.0, true)
	draw_arc(centre, r_hp, 0.0, TAU, 96, Color("16211a"), w_hp, true)
	if _ghost > _shown + 0.001:
		draw_arc(centre, r_hp, start, start + TAU * _ghost, 96, Color(1, 0.92, 0.8, 0.5), w_hp, true)
	if _shown > 0.001:
		var tone: Color = DeepUi.health_tone(_shown, fill) if warn else fill
		draw_arc(centre, r_hp, start, start + TAU * _shown, 96, tone, w_hp, true)
		draw_arc(centre, r_hp + w_hp * 0.22, start, start + TAU * _shown, 96, Color(1, 1, 1, 0.14), w_hp * 0.3, true)
	if preview > 0.0 and _shown > 0.001:
		var cut: float = minf(preview, _shown)
		var pulse: float = 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
		_hatch(centre, r_hp, start + TAU * (_shown - cut), start + TAU * _shown, w_hp, Color(1.0, 0.35, 0.3, pulse))
	## Block, outside: an arc that grows both ways round from the top, over a dark track of
	## its own; a whole ring when block matches full health.
	draw_arc(centre, r_block, 0.0, TAU, 96, DeepUi.LEDGER_SHADOW, w_block + 3.0, true)
	var share: float = minf(1.0, _shown_overlay)
	if share > 0.001:
		var half: float = PI * share
		if armour > 0.0:
			var glow: float = armour * (0.35 + (0.0 if ScreenFx.calm else 0.15 * sin(_clock * 3.0)))
			draw_arc(centre, r_block, start - half, start + half, 96, Color(overlay_color.lightened(0.4), glow), w_block + 6.0, true)
		draw_arc(centre, r_block, start - half, start + half, 96, overlay_color.lerp(Color("bfe0ff"), armour * 0.6), w_block, true)
	if _flash > 0.0:
		draw_arc(centre, r_hp, 0.0, TAU, 96, Color(_flash_color, 0.35 * _flash), w_hp, true)

func _draw_hexes() -> void:
	## A lattice of pale blue hexagons over the face: the armour block past full health is,
	## denser and brighter the more there is, each cell breathing in its own time.
	var armour: float = _armour()
	if armour <= 0.0:
		return
	var centre: Vector2 = Vector2(_face, _face) * 0.5
	var radius: float = _face * 0.5 - 3.0
	var side: float = _face * 0.085
	var dx: float = side * sqrt(3.0)
	var dy: float = side * 1.5
	var rows: int = int(ceil(_face / dy)) + 2
	var cols: int = int(ceil(_face / dx)) + 2
	var tone: Color = Color("8fc3ff")
	var still: bool = ScreenFx.calm
	for row in range(-rows, rows):
		for col in range(-cols, cols):
			var at: Vector2 = centre + Vector2(float(col) * dx + (dx * 0.5 if row % 2 != 0 else 0.0), float(row) * dy)
			var away: float = at.distance_to(centre)
			if away > radius - side * 0.9:
				continue
			## The cells nearest the rim come up first; the middle fills as the armour grows.
			var order: float = 1.0 - away / radius
			var shown: float = clampf((armour * 1.4 - order) / 0.4, 0.0, 1.0)
			if shown <= 0.0:
				continue
			var phase: float = float(row * 7 + col * 13) * 0.61
			var breath: float = 0.5 if still else 0.5 + 0.5 * sin(_clock * 1.6 + phase)
			var alpha: float = shown * (0.12 + 0.3 * armour) * (0.6 + 0.4 * breath)
			var points := PackedVector2Array()
			for corner in range(6):
				var angle: float = PI / 6.0 + TAU * float(corner) / 6.0
				points.append(at + Vector2.from_angle(angle) * side * 0.92)
			_hexes.draw_colored_polygon(points, Color(tone, alpha * 0.35))
			points.append(points[0])
			_hexes.draw_polyline(points, Color(tone.lightened(0.2), alpha), 1.2, true)

func _hatch(centre: Vector2, radius: float, from: float, to: float, width: float, color: Color) -> void:
	## Diagonal ticks across the arc between two angles: what a blow would take, hatched.
	if to <= from:
		return
	draw_arc(centre, radius, from, to, 48, Color(color, color.a * 0.35), width, true)
	var step: float = 4.0 / radius
	var angle: float = from
	while angle < to:
		var a: Vector2 = centre + Vector2.from_angle(angle) * (radius - width * 0.5)
		var b: Vector2 = centre + Vector2.from_angle(angle + step * 0.6) * (radius + width * 0.5)
		draw_line(a, b, color, 1.5, true)
		angle += step
