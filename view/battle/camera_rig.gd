extends Camera3D
## The party's eyes. It breathes while nothing happens, flinches when the party is hit,
## leans toward what the party is striking, punches in on a heavy blow, sweeps in when a
## fight begins and sags when it is lost.
##
## Shake is trauma-based: every hit adds trauma, trauma decays, and the shake is its square
## run through smooth noise, so small knocks barely move the view and big ones rattle it.

var home_position := Vector3(0.0, 2.1, 5.2)
var home_look := Vector3(0.0, 1.2, -3.5)
var home_fov: float = 58.0
## Motion sickness guard: a player who turns this down gets a steadier room.
var shake_scale: float = 1.0
## The same guard from the settings menu, for every room at once (0 to 1).
static var comfort: float = 1.0

var trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _clock: float = 0.0
var _punch: float = 0.0
var _focus := Vector3.ZERO
var _focus_weight: float = 0.0
var _offset := Vector3.ZERO
var _roll: float = 0.0
var _sway: float = 1.0

func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 1.0
	fov = home_fov
	look_at_from_position(home_position, home_look, Vector3.UP)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func punch(degrees: float, seconds: float = 0.35) -> void:
	## A quick zoom: negative is in, toward the blow.
	degrees *= lerpf(0.25, 1.0, comfort)
	var tween := create_tween()
	tween.tween_property(self, "_punch", degrees, seconds * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_punch", 0.0, seconds * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func focus(point: Vector3, weight: float = 0.18, seconds: float = 0.5) -> void:
	## Leans the view toward something without leaving the party's place.
	_focus = point
	var tween := create_tween()
	tween.tween_property(self, "_focus_weight", weight, seconds * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_focus_weight", 0.0, seconds * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func nudge(offset: Vector3, seconds: float = 0.3) -> void:
	## A physical knock: the view is shoved and springs back.
	var tween := create_tween()
	tween.tween_property(self, "_offset", offset, seconds * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_offset", Vector3.ZERO, seconds * 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func intro(seconds: float = 1.4, warden: bool = false) -> void:
	## Coming into the room: from further back and higher, the view settles into place.
	_offset = Vector3(0.0, 1.6 if not warden else 2.6, 4.5 if not warden else 6.5)
	_punch = 14.0 if not warden else 20.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_offset", Vector3.ZERO, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_punch", 0.0, seconds * 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func victory() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_offset", Vector3(0, 0.3, -1.4), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_punch", -6.0, 2.2).set_trans(Tween.TRANS_SINE)

func defeat() -> void:
	## The party goes down: the view drops and rolls.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_offset", Vector3(0.4, -1.4, 0.6), 1.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_roll", deg_to_rad(18.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	add_trauma(0.8)

func reset() -> void:
	_offset = Vector3.ZERO
	_roll = 0.0
	_punch = 0.0
	trauma = 0.0

func settled() -> bool:
	## Not mid-intro, mid-punch or mid-shove: the view is where it means to be.
	return absf(_punch) < 0.6 and _offset.length() < 0.15 and trauma < 0.2

func calm(amount: float) -> void:
	## How much the view breathes at rest: a Warden's hall heaves more than a gallery.
	_sway = amount

func _process(delta: float) -> void:
	_clock += delta
	trauma = maxf(0.0, trauma - delta * 1.1)
	var shake: float = trauma * trauma * shake_scale * comfort
	var t: float = _clock * 24.0
	var jolt := Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(0.0, t), _noise.get_noise_2d(t, t)) * shake
	## Breathing: two slow swings that never line up.
	var breath := Vector3(sin(_clock * 0.37) * 0.08, sin(_clock * 0.53 + 1.0) * 0.05, 0.0) * _sway
	var eye := home_position + _offset + breath + jolt * 0.28
	var look := home_look.lerp(_focus, _focus_weight) + Vector3(sin(_clock * 0.29) * 0.1, 0, 0) * _sway + jolt * 0.35
	look_at_from_position(eye, look, Vector3.UP)
	rotate_object_local(Vector3(0, 0, 1), _roll + _noise.get_noise_2d(t * 0.7, 99.0) * shake * 0.06)
	fov = clampf(home_fov + _punch, 30.0, 95.0)
