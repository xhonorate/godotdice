extends Control
## Puck's Changing Face, worn by the reader's own dice tray. `level` is what the next face is
## worth (DeepBattle.next_face_pays): 1 when no run is on, 2 the turn after a face, 3 after two
## changes, and so on. From 2 a ribbon of her motley, pink and green squares, runs round the
## tray, faster the longer the run, and diamonds in both colors drift up off it. `change` is
## the moment the face turns at the Birthstone: the tray flashes in the face's color and motley
## bursts off it, more of it the longer the run.
##
## It lies over the whole screen, follows the tray every frame and never takes the mouse.

const CRUEL := Color("ff6fae")
const KIND := Color("6fe08a")
const FADE_SECONDS := 0.8
const SQUARE := 7.0
const PITCH := 10.0

## The tray it follows.
var follow: Control = null
var level: int = 1
## The face shown last turn, "odd" or "even", or "" with no run on.
var face: String = ""

var _drifts: Array = []
var _alpha: float = 0.0
var _tween: Tween
var _phase: float = 0.0
var _flash: float = 0.0
var _flash_tone: Color = CRUEL
static var _diamond: ImageTexture = null

static func diamond_texture() -> ImageTexture:
	## A soft-edged lozenge, the square of her motley turned on its corner.
	if _diamond == null:
		var edge := 24
		var image := Image.create(edge, edge, false, Image.FORMAT_RGBA8)
		var centre := float(edge - 1) * 0.5
		for y in range(edge):
			for x in range(edge):
				var away := absf(float(x) - centre) + absf(float(y) - centre)
				image.set_pixel(x, y, Color(1, 1, 1, clampf((centre - away) / 2.0, 0.0, 1.0)))
		_diamond = ImageTexture.create_from_image(image)
	return _diamond

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DeepUi.headless():
		return
	_drifts = [_drifter(CRUEL), _drifter(KIND)]
	_apply_alpha()

func _drifter(tone: Color) -> CPUParticles2D:
	var drift := CPUParticles2D.new()
	drift.amount = 12
	drift.lifetime = 2.2
	drift.texture = diamond_texture()
	drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift.emission_rect_extents = Vector2(120, 4)
	drift.direction = Vector2.UP
	drift.spread = 25.0
	drift.initial_velocity_min = 18.0
	drift.initial_velocity_max = 40.0
	drift.gravity = Vector2(0, -10)
	drift.angular_velocity_min = -90.0
	drift.angular_velocity_max = 90.0
	drift.scale_amount_min = 0.35
	drift.scale_amount_max = 0.7
	drift.color_ramp = _ramp([Color(tone, 0.0), Color(tone, 0.9), Color(tone.lightened(0.3), 0.0)])
	drift.emitting = false
	add_child(drift)
	return drift

func _ramp(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, colors[0])
	gradient.set_color(1, colors[colors.size() - 1])
	for index in range(1, colors.size() - 1):
		gradient.add_point(float(index) / float(colors.size() - 1), colors[index])
	return gradient

# --- the run ---------------------------------------------------------------------------------

func set_level(next: int, last: String) -> void:
	## What the next face pays (1: no run), and the face shown last turn. Going up lights the
	## motley at once; going down lets it fade.
	next = maxi(1, next)
	face = last
	if next == level:
		return
	var rising: bool = next > level
	level = next
	for drift in _drifts:
		if is_instance_valid(drift):
			(drift as CPUParticles2D).amount = 6 + 6 * mini(level, 5)
	_ease(1.0 if level >= 2 else 0.0, 0.35 if rising else FADE_SECONDS)

func _ease(to: float, seconds: float) -> void:
	if DeepUi.headless() or not is_inside_tree():
		_alpha = to
		_apply_alpha()
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void:
		_alpha = value
		_apply_alpha(), _alpha, to, seconds).set_trans(Tween.TRANS_SINE)

func _apply_alpha() -> void:
	for drift in _drifts:
		if is_instance_valid(drift):
			(drift as CPUParticles2D).modulate.a = _alpha
			(drift as CPUParticles2D).emitting = _alpha > 0.02 and level >= 2
	queue_redraw()

# --- the moment ------------------------------------------------------------------------------

func change(shown: String, pays: int) -> void:
	## The face turns at the Birthstone: the tray flashes in the face's color and motley bursts
	## off it, more the longer the run.
	if DeepUi.headless() or follow == null or not is_instance_valid(follow):
		return
	var area: Rect2 = _local(follow.get_global_rect())
	for tone in [CRUEL, KIND]:
		var burst := CPUParticles2D.new()
		burst.one_shot = true
		burst.explosiveness = 0.9
		burst.amount = 14 + 10 * mini(pays, 5)
		burst.lifetime = 1.3
		burst.texture = diamond_texture()
		burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		burst.emission_rect_extents = Vector2(area.size.x * 0.45, area.size.y * 0.3)
		burst.direction = Vector2.UP
		burst.spread = 70.0
		burst.initial_velocity_min = 90.0
		burst.initial_velocity_max = 220.0
		burst.gravity = Vector2(0, 240)
		burst.angular_velocity_min = -240.0
		burst.angular_velocity_max = 240.0
		burst.scale_amount_min = 0.4
		burst.scale_amount_max = 0.9
		burst.color_ramp = _ramp([Color(tone, 1.0), Color(tone, 1.0), Color(tone, 0.0)])
		burst.position = area.get_center()
		add_child(burst)
		burst.emitting = true
		burst.finished.connect(burst.queue_free)
	_flash = 1.0
	_flash_tone = CRUEL if shown == "odd" else KIND
	queue_redraw()

# --- following the tray ----------------------------------------------------------------------

func _local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - global_position, rect.size)

func _process(delta: float) -> void:
	if _drifts.is_empty():
		return
	var shown: bool = follow != null and is_instance_valid(follow) and follow.is_visible_in_tree()
	visible = shown
	if not shown:
		return
	var area: Rect2 = _local(follow.get_global_rect())
	for drift in _drifts:
		if is_instance_valid(drift):
			(drift as CPUParticles2D).position = Vector2(area.get_center().x, area.end.y - 6.0)
			(drift as CPUParticles2D).emission_rect_extents = Vector2(area.size.x * 0.5 + 8.0, 3.0)
	if _alpha > 0.01:
		_phase += delta * (14.0 + 10.0 * float(mini(level, 6)))
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.8)
		queue_redraw()

func _along(area: Rect2, along: float) -> Vector2:
	## A point `along` the tray's edge, clockwise from its top left corner.
	if along < area.size.x:
		return area.position + Vector2(along, 0)
	if along < area.size.x + area.size.y:
		return area.position + Vector2(area.size.x, along - area.size.x)
	if along < 2.0 * area.size.x + area.size.y:
		return area.position + Vector2(area.size.x - (along - area.size.x - area.size.y), area.size.y)
	return area.position + Vector2(0, area.size.y - (along - 2.0 * area.size.x - area.size.y))

func _draw() -> void:
	if follow == null or not is_instance_valid(follow):
		return
	## Wider than the tray at the sides and below it, but not above, where the tray's title and
	## its hint are written.
	var tray: Rect2 = _local(follow.get_global_rect())
	var area := Rect2(tray.position + Vector2(-10.0, 2.0), tray.size + Vector2(20.0, 8.0))
	if _flash > 0.0:
		draw_rect(area.grow(6.0), Color(_flash_tone, 0.28 * _flash * _flash))
	if _alpha <= 0.01:
		return
	## The ribbon: squares of pink and green, alternating, going round the tray.
	var perimeter: float = 2.0 * (area.size.x + area.size.y)
	var count: int = maxi(4, int(perimeter / PITCH))
	var offset: float = fmod(_phase, PITCH * 2.0)
	for index in range(count):
		var along: float = fmod(PITCH * float(index) + offset, perimeter)
		var spot: Vector2 = _along(area, along)
		var tone: Color = CRUEL if index % 2 == 0 else KIND
		draw_rect(Rect2(spot - Vector2.ONE * SQUARE * 0.5, Vector2.ONE * SQUARE), Color(tone, 0.85 * _alpha))
