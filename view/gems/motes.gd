extends Control
## The slow ring of motes a Transcendent carries wherever it is drawn: a handful of points of
## light going round the stone on a tilted ellipse, each flickering on its own beat, in gold
## and the colors of the wheel. Nothing else in the game wears it, so a Transcendent on the
## rail, in the vault or on a card reads as one before its name does.
##
## It lays itself over whatever control it is added to and ignores the pointer.

const COUNT := 9
## Seconds for one mote to go round once.
const LAP := 9.0

var _clock: float = 0.0
var _seed: float = 0.0

static func wanted(stone: Dictionary) -> bool:
	## Only a read Transcendent: a raw stone keeps every secret, this one included.
	return not stone.is_empty() and bool(stone.get("appraised", true)) and DeepStone.is_transcendent(stone)

static func refresh(host: Control, stone: Dictionary) -> void:
	## Puts the ring on `host` if the stone wants one, and takes it off if it does not.
	var existing: Node = host.get_node_or_null("Motes")
	if wanted(stone):
		if existing == null:
			var ring: Control = load("res://view/gems/motes.gd").new()
			ring.name = "Motes"
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.set("_seed", float(str(stone.get("id", "")).hash() % 997) / 997.0)
			host.add_child(ring)
	elif existing != null:
		existing.queue_free()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var centre: Vector2 = size * 0.5
	var reach: Vector2 = Vector2(size.x * 0.5, size.y * 0.24)
	for i in range(COUNT):
		var phase: float = float(i) / float(COUNT) + _seed
		var angle: float = TAU * (phase + _clock / LAP)
		var at: Vector2 = centre + Vector2(cos(angle) * reach.x, sin(angle) * reach.y + size.y * 0.06)
		## Behind the stone on the far side of the ellipse: dimmer and smaller.
		var near: float = 0.55 + 0.45 * (sin(angle) * 0.5 + 0.5)
		var flicker: float = 0.55 + 0.45 * sin(_clock * (2.1 + float(i) * 0.37) + float(i) * 1.7)
		var tone: Color = DeepUi.TRANSCENDENT_TONE if i % 3 == 0 else DeepUi.rainbow_at(fposmod(phase + _clock * 0.05, 1.0), 0.6)
		var radius: float = maxf(1.0, size.x * 0.022) * near
		draw_circle(at, radius * 2.6, Color(tone, 0.12 * flicker * near))
		draw_circle(at, radius, Color(tone, 0.85 * flicker * near))
