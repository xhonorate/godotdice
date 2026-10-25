extends Control
## Copies fanned out behind a thing (docs/UI_REDO.md): the Void gems riding a socket behind
## its gem, a Refract's phantoms behind the die they copy. It lies over the slot it belongs
## to; the rings handed to `lay` are stepped up and to the right behind it, three at most, and
## a capsule at the top-left counts them all. Each ring stays a Control of its own, so a count
## can land on it or an event light it.

const SHOWN: int = 3
const STEP := Vector2(7.0, -7.0)

var badge: PanelContainer
var _count: Label

func _init(tone: Color = DeepUi.INFO) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", DeepUi.capsule(badge, tone.darkened(0.6), tone, 2, 9, 0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 3
	badge.visible = false
	add_child(badge)
	_count = DeepUi.label(badge, "", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_count.add_theme_font_override("font", DeepUi.bold_font())
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.resized.connect(_place_badge)
	resized.connect(_place_badge)

func _place_badge() -> void:
	## At the top-left corner, clear of the rings fanned out to the right.
	badge.position = Vector2(-8.0, STEP.y * float(SHOWN) - 2.0).round()

func set_count(count: int) -> void:
	badge.visible = count >= 1
	_count.text = "×%d" % count
	badge.reset_size()
	_place_badge()

func lay(ring: Control, index: int) -> void:
	## Puts one ring behind the slot, `index` steps back (0 is nearest).
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shift: Vector2 = STEP * float(index + 1)
	ring.offset_left = shift.x
	ring.offset_top = shift.y
	ring.offset_right = shift.x
	ring.offset_bottom = shift.y
	add_child(ring)
	move_child(ring, 0)
	ring.visible = index < SHOWN
