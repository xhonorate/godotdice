class_name DeepAudio
extends Node
## The mixer: one small service that every screen shouts a name at.
##
## `DeepAudio.play("pick_strike")` is the whole interface. The service keeps a pool of players
## on its own bus, steals the oldest voice when they are all busy, refuses to start the same
## sound twice inside a few milliseconds (a rail of five gems firing at once would otherwise
## be one loud smear), and wobbles the pitch of anything physical so two dice never land on
## exactly the same note. Sounds given a screen position are played through a 2D voice, which
## pans them: a creature on the left of the arc is hit on the left.
##
## Nothing in the bank exists on disk, so the first ask for a sound has to write it. A worker
## thread bakes the whole bank at boot, in the order the game is likely to need it, while the
## player is still looking at the workshop; anything asked for before its turn comes is baked
## on the spot instead.
##
## With no display there is no service and every call is a no-op, so the headless suites and
## the screenshot tools run in silence.

const BUS: String = "Sfx"
const FLAT_VOICES: int = 16
const PLACED_VOICES: int = 10
## Two plays of one sound closer together than this are one play.
const GAP: float = 0.035
## Sounds that carry a tune are never detuned; everything else gets a little life.
const TUNED: PackedStringArray = ["unlock", "victory", "defeat", "landing", "reveal", "star", "gleam",
	"grade_rough", "grade_fine", "grade_precious", "grade_exquisite", "grade_peerless",
	"heal", "harmony", "turn_begin", "resonance"]
const VARIATION: float = 0.035
## The sounds of a control being pressed. A click that rebuilds a bar of buttons puts a new
## one under the pointer, and its hover is not news: it is not played this soon after a press.
const PRESSES: PackedStringArray = ["ui_tap", "ui_confirm", "ui_back", "ui_toggle", "ui_tab", "ui_open", "ui_close", "depart"]
const HOVER_AFTER_PRESS: float = 0.35

static var _service: DeepAudio = null
static var _master: float = 0.8
static var _level: float = 0.85

var _flat: Array = []
var _placed: Array = []
var _stage: CanvasLayer
var _recent: Dictionary = {}
var _pressed: float = -99.0
var _unknown: Dictionary = {}
var _bakery: Thread = null
var _closing: bool = false

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func start(host: Node, settings: Dictionary = {}) -> DeepAudio:
	## Called once by the app shell, so the first click already has a voice to speak with.
	if headless() or host == null:
		return null
	if _service != null and is_instance_valid(_service):
		levels(settings)
		return _service
	var made := DeepAudio.new()
	made.name = "Audio"
	host.add_child(made)
	levels(settings)
	return made

static func service() -> DeepAudio:
	if _service != null and is_instance_valid(_service) and _service.is_inside_tree():
		return _service
	return null

static func levels(settings: Dictionary) -> void:
	## Master and effects, straight off the settings page.
	if settings.has("master_volume"):
		_master = clampf(float(settings.master_volume), 0.0, 1.0)
	if settings.has("sfx_volume"):
		_level = clampf(float(settings.sfx_volume), 0.0, 1.0)
	if headless():
		return
	var bus: int = AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	var loudness: float = _master * _level
	AudioServer.set_bus_mute(bus, loudness <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(loudness, 0.001)))

static func play(sound: String, opts: Dictionary = {}) -> void:
	## `volume` scales it, `pitch` shifts it, `delay` holds it back, `at` places it on screen,
	## `gap` overrides how soon it may be heard again, `vary` how far its pitch may wander.
	var node: DeepAudio = service()
	if node != null:
		node.emit(sound, opts)

static func play_at(at: Vector2, sound: String, opts: Dictionary = {}) -> void:
	var placed: Dictionary = opts.duplicate()
	placed["at"] = at
	play(sound, placed)

static func from(control: Control, sound: String, opts: Dictionary = {}) -> void:
	## The same, for something the player can see: the sound comes from where it is.
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		play(sound, opts)
		return
	play_at(control.global_position + control.size * 0.5, sound, opts)

static func reveal_stone(stone: Dictionary) -> void:
	## The ceremony, in sound, wherever a stone is first known: the light falling on it, its
	## grade a breath later, and — once in a long while — the Star, which is the one sound in
	## the game worth learning by ear.
	play("reveal")
	play(DeepSoundBank.grade_sound(str(DeepStone.grade(stone).get("tier", "ROUGH"))), {"delay": 0.42})
	if stone.get("inclusions", []).has("STAR"):
		play("star", {"delay": 0.95})

# --- the service ---------------------------------------------------------------------------

func _ready() -> void:
	_service = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open_bus()
	for i in range(FLAT_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_flat.append(voice)
	_stage = CanvasLayer.new()
	_stage.layer = -100
	add_child(_stage)
	for i in range(PLACED_VOICES):
		var voice := AudioStreamPlayer2D.new()
		voice.bus = BUS
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		## Panning is the point; the falloff over one screen should be slight.
		voice.max_distance = 4000.0
		voice.attenuation = 0.5
		voice.panning_strength = 1.4
		_stage.add_child(voice)
		_placed.append(voice)
	_bake_in_the_background()

func _exit_tree() -> void:
	_closing = true
	if _bakery != null and _bakery.is_started():
		_bakery.wait_to_finish()
	_bakery = null
	if _service == self:
		_service = null

func _open_bus() -> void:
	## The game's own bus, so one slider moves every sound and nothing else.
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	var at: int = AudioServer.bus_count
	AudioServer.add_bus(at)
	AudioServer.set_bus_name(at, BUS)
	AudioServer.set_bus_send(at, "Master")
	DeepAudio.levels({})

func _bake_in_the_background() -> void:
	if OS.get_processor_count() < 2:
		return
	_bakery = Thread.new()
	if _bakery.start(_bake_the_bank, Thread.PRIORITY_LOW) != OK:
		_bakery = null

func _bake_the_bank() -> void:
	for sound in DeepSoundBank.NAMES:
		if _closing:
			return
		DeepSoundBank.stream(str(sound))

# --- playing -------------------------------------------------------------------------------

func emit(sound: String, opts: Dictionary = {}) -> void:
	if _master * _level <= 0.001:
		return
	var delay: float = float(opts.get("delay", 0.0))
	if delay > 0.0 and is_inside_tree():
		var held: Dictionary = opts.duplicate()
		held.erase("delay")
		## On scaled time, so a sound held for a blow still lands with it in a fast fight.
		get_tree().create_timer(delay, true, false, false).timeout.connect(emit.bind(sound, held))
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var gap: float = float(opts.get("gap", GAP))
	if gap > 0.0 and now - float(_recent.get(sound, -99.0)) < gap:
		return
	if sound == "ui_hover" and now - _pressed < HOVER_AFTER_PRESS:
		return
	if PRESSES.has(sound):
		_pressed = now
	## While the bakery is still working, a sound that has not been written yet is skipped
	## rather than baked here: dropping one click in the first second of the game is better
	## than spending a frame writing a chord nobody asked to wait for.
	if _bakery != null and _bakery.is_alive() and not DeepSoundBank.baked(sound):
		return
	var stream: AudioStreamWAV = DeepSoundBank.stream(sound)
	if stream == null:
		if not _unknown.has(sound):
			_unknown[sound] = true
			push_warning("DeepAudio: no sound named '%s'" % sound)
		return
	_recent[sound] = now
	var wander: float = float(opts.get("vary", 0.0 if TUNED.has(sound) else VARIATION))
	var pitch: float = clampf(float(opts.get("pitch", 1.0)) * (1.0 + randf_range(-wander, wander)), 0.05, 6.0)
	var volume: float = clampf(float(opts.get("volume", 1.0)), 0.0, 4.0)
	if volume <= 0.001:
		return
	var voice: Node = _free_voice(opts.has("at"))
	if voice == null:
		return
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = linear_to_db(volume)
	if opts.has("at"):
		(voice as AudioStreamPlayer2D).global_position = opts.at
	voice.set_meta("began", now)
	voice.play()

func _free_voice(placed: bool) -> Node:
	## A silent voice if there is one, otherwise whichever has been sounding longest.
	var pool: Array = _placed if placed else _flat
	var oldest: Node = null
	var since: float = INF
	for voice in pool:
		if not voice.playing:
			return voice
		var began: float = float(voice.get_meta("began", 0.0))
		if began < since:
			since = began
			oldest = voice
	return oldest
