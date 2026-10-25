extends PanelContainer
## The plate an instant tooltip is drawn on (see tips.gd): a Ledger panel that keeps itself
## next to the control it explains, inside the screen, and lets go of itself when that
## control is gone, hidden, or no longer under the pointer.

signal closed

var anchor: Control = null
var keep: bool = false
var gap: float = 10.0
var below: bool = false
## Stood beside the anchor (to its right, or its left when there is no room), level with
## the pointer: the working opened from inside another plate.
var beside: bool = false
## The pointer has left the anchor: unless it is on the plate by the next frame, the plate goes.
var leaving: bool = false
var _tone: Color = DeepUi.LEDGER_LINE
var _fading: Tween = null
var _gone: bool = false
var _arrow: Control = null

func _init() -> void:
	set_meta("tip_plate", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	modulate.a = 0.0
	top_level = true
	mouse_exited.connect(func() -> void:
		if keep and (anchor == null or not is_instance_valid(anchor) or not anchor.get_global_rect().has_point(anchor.get_global_mouse_position())):
			dismiss(0.06))

func fill(content: Control, tone: Color, width: float) -> void:
	_tone = tone
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var style: StyleBoxFlat = DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 10, 12, 3, 4)
	add_theme_stylebox_override("panel", style)
	add_child(content)
	if width > 0.0:
		custom_minimum_size.x = width
	mouse_filter = Control.MOUSE_FILTER_STOP if keep else Control.MOUSE_FILTER_IGNORE
	## A plate the pointer may rest on passes nothing through to what is under it.
	reset_size()
	place()

func appear(seconds: float) -> void:
	visible = true
	if _fading != null and _fading.is_valid():
		_fading.kill()
	if DeepUi.headless():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_fading = create_tween()
	_fading.tween_property(self, "modulate:a", 1.0, seconds)
	set_process(true)

func dismiss(seconds: float) -> void:
	if _gone:
		return
	_gone = true
	set_process(false)
	closed.emit()
	if _fading != null and _fading.is_valid():
		_fading.kill()
	if seconds <= 0.0 or DeepUi.headless() or not is_inside_tree():
		queue_free()
		return
	_fading = create_tween()
	_fading.tween_property(self, "modulate:a", 0.0, seconds)
	_fading.tween_callback(queue_free)

func place() -> void:
	## Centred over the anchor (or under it), kept inside the screen. The size it needs is
	## what its content asks for; a plate wider than the screen is as wide as the screen.
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var screen: Rect2 = get_viewport().get_visible_rect() if get_viewport() != null else Rect2(Vector2.ZERO, Vector2(1600, 900))
	var want: Vector2 = get_combined_minimum_size()
	want.x = minf(want.x, screen.size.x - 16.0)
	size = want
	var at: Rect2 = anchor.get_global_rect()
	if beside:
		var bx: float = at.end.x + gap
		if bx + size.x > screen.end.x - 8.0:
			bx = at.position.x - size.x - gap
		var by: float = clampf(get_global_mouse_position().y - 24.0, screen.position.y + 8.0, maxf(screen.position.y + 8.0, screen.end.y - size.y - 8.0))
		global_position = Vector2(clampf(bx, screen.position.x + 8.0, screen.end.x - size.x - 8.0), by).round()
		return
	var x: float = at.position.x + (at.size.x - size.x) * 0.5
	var y: float = at.position.y - size.y - gap
	var hang: bool = below or y < screen.position.y + 8.0
	if hang:
		y = at.end.y + gap
		if y + size.y > screen.end.y - 8.0:
			## No room under it either: over it, as high as it goes.
			y = maxf(screen.position.y + 8.0, at.position.y - size.y - gap)
	x = clampf(x, screen.position.x + 8.0, maxf(screen.position.x + 8.0, screen.end.x - size.x - 8.0))
	global_position = Vector2(x, y).round()

func _process(_delta: float) -> void:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
		dismiss(0.0)
		return
	if beside:
		return
	if leaving:
		leaving = false
		var pointer: Vector2 = get_global_mouse_position()
		if not get_global_rect().grow(2.0).has_point(pointer) and not anchor.get_global_rect().has_point(pointer):
			dismiss(0.06)
			return
	## The anchor may move (a die lifting, a dock sliding): the plate follows it.
	place()
