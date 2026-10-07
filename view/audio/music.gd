class_name DeepMusic
extends Node
## The score player: which piece is playing, how much of it, and the air of the place under it.
##
## The app tells it where the party is every frame (`follow`), as a place (the workshop or a
## mine), a mood and how deep into the mine they are. The place picks the piece — the player's
## pick from the Soundtrack page — and the mood and depth pick how much of it plays: the five
## layers `composer.gd` writes are always running together, and only their levels move. A
## fight brings the drums and the arpeggio in over the tune that was already playing; a
## Warden's hall adds the horns; winning lets them go again. Deeper in a mine the bass and
## the tune come up even between fights, and near the bottom a breath of the horns stays.
##
## A change of place crossfades to the new piece. Every piece is baked ahead of time, one Ogg
## loop a layer in `audio/music/<id>/` (see `score.gd`), and read from there. A piece that has
## not been baked yet (one just added to the score) is written here instead, on a worker
## thread, the one wanted now first and the one most likely next after it; until it is ready
## the old piece plays on.
##
## Under the music, on its own bus under the effects slider, is the air: a loop of wind, drips
## and whatever else lives in that rock, crossfaded the same way.
##
## With no display there is no service and every call is a no-op, so the suites run silent;
## the pure parts (`where_now`, `layer_levels`) are what they check.

const BUS: String = "Music"
const AIR_BUS: String = "Ambience"
## Seconds for a layer to come in, and to go out. Coming in is quicker: a fight starts at once,
## and lets go slowly.
const RISE: float = 1.4
const FALL: float = 4.5
const CROSSFADE: float = 3.0
## The air sits well under the music and the effects.
const AIR_LEVEL: float = 0.3
## Where the baked pieces are: <id>/<layer>.ogg, and air/<family>.ogg.
const BAKED: String = "res://audio/music"

## How loud each layer plays in each mood, [bed, pulse, melody, drive, peril], before depth.
const MOODS: Dictionary = {
	"home": [1.0, 0.7, 0.9, 0.0, 0.0],
	"shaft": [1.0, 0.3, 0.6, 0.0, 0.0],
	"rest": [1.0, 0.2, 0.75, 0.0, 0.0],
	"explore": [1.0, 0.45, 0.55, 0.0, 0.0],
	"hoard": [1.0, 0.5, 1.0, 0.0, 0.0],
	"fight": [1.0, 1.0, 1.0, 0.9, 0.0],
	"elite": [1.0, 1.0, 1.0, 1.0, 0.5],
	"warden": [1.0, 1.0, 1.0, 1.0, 1.0],
	"over": [0.8, 0.0, 0.4, 0.0, 0.0],
}
## The moods the Soundtrack page can audition a piece in.
const PREVIEWS: Array = [["Calm", "rest"], ["Explore", "explore"], ["Fight", "fight"], ["Warden", "warden"]]

static var _service: DeepMusic = null
static var _master: float = 0.8
static var _level: float = 0.6
static var _picks: Dictionary = {}
static var _baked_ids: Dictionary = {}

var _where: Dictionary = {"place": DeepScore.HOME, "mood": "home", "deep": 0.0}
var _preview: Dictionary = {}
var _decks: Array = []
var _airs: Array = []
var _queue: Array = []
var _writer: Thread = null
var _clock: int = 0

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func start(host: Node, settings: Dictionary = {}) -> DeepMusic:
	if headless() or host == null:
		return null
	if _service != null and is_instance_valid(_service):
		levels(settings)
		return _service
	var made := DeepMusic.new()
	made.name = "Music"
	host.add_child(made)
	levels(settings)
	return made

static func service() -> DeepMusic:
	if _service != null and is_instance_valid(_service) and _service.is_inside_tree():
		return _service
	return null

static func levels(settings: Dictionary) -> void:
	## Master and music off the settings page, and which piece plays where.
	if settings.has("master_volume"):
		_master = clampf(float(settings.master_volume), 0.0, 1.0)
	if settings.has("music_volume"):
		_level = clampf(float(settings.music_volume), 0.0, 1.0)
	if settings.get("music_picks", null) is Dictionary:
		_picks = settings.music_picks.duplicate()
	if headless():
		return
	var bus: int = AudioServer.get_bus_index(BUS)
	if bus >= 0:
		var loudness: float = _master * _level
		AudioServer.set_bus_mute(bus, loudness <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(loudness, 0.001)))

static func follow(where: Dictionary) -> void:
	## Where the party is now: {place, mood, deep, next}. Cheap; called every frame.
	var node: DeepMusic = service()
	if node != null:
		node._where = where

static func preview(place: String, track_id: String, mood: String) -> void:
	## Play a piece in a mood instead of what the mine asks for, until `end_preview`.
	var node: DeepMusic = service()
	if node != null:
		node._preview = {"place": place, "track": track_id, "mood": mood, "deep": 0.5}

static func end_preview() -> void:
	var node: DeepMusic = service()
	if node != null:
		node._preview = {}

static func previewing() -> Dictionary:
	var node: DeepMusic = service()
	return node._preview.duplicate() if node != null else {}

static func ready_to_play(track_id: String) -> bool:
	return is_baked(track_id) or not DeepComposer.written(track_id).is_empty()

static func is_baked(track_id: String) -> bool:
	## Cheap enough for every frame: the files do not come and go while the game runs.
	if not _baked_ids.has(track_id):
		_baked_ids[track_id] = _baked_paths(track_id).all(func(path: String) -> bool: return ResourceLoader.exists(path))
	return bool(_baked_ids[track_id])

static func baked(track_id: String) -> Array:
	## The piece's baked layers, looping, or empty if any layer it is written in is missing.
	if not is_baked(track_id):
		return []
	var out: Array = []
	for path in _baked_paths(track_id):
		var stream: AudioStream = _baked_loop(str(path))
		if stream == null:
			return []
		out.append(stream)
	return out

static func _baked_paths(track_id: String) -> Array:
	var spec: Dictionary = DeepScore.track(track_id)
	if spec.is_empty():
		return [""]
	var count: int = clampi(int(spec.get("layers", DeepComposer.LAYERS.size())), 1, DeepComposer.LAYERS.size())
	var out: Array = []
	for i in range(count):
		out.append("%s/%s/%s.ogg" % [BAKED, track_id, DeepComposer.LAYERS[i]])
	return out

static func baked_air(family: String) -> AudioStream:
	return _baked_loop("%s/air/%s.ogg" % [BAKED, family])

static func _baked_loop(path: String) -> AudioStream:
	if not _baked_ids.has(path):
		_baked_ids[path] = ResourceLoader.exists(path)
	if not bool(_baked_ids[path]):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		## Whatever the import says: a layer replaced by hand still has to come round.
		stream.loop = true
		stream.loop_offset = 0.0
	return stream

static func picks() -> Dictionary:
	return _picks.duplicate()

# --- where the party is, as music --------------------------------------------------------------

static func where_now(run: Dictionary, next_mine: String = "") -> Dictionary:
	## The place, mood and depth a run's state asks for. An empty run is the workshop, and the
	## mine on the map is the piece worth writing before anyone asks for it.
	if run.is_empty():
		return {"place": DeepScore.HOME, "mood": "home", "deep": 0.0, "next": next_mine}
	var mine: String = str(run.get("mine", ""))
	if not DeepScore.BOOK.has(mine):
		mine = "QUARRY"
	var mood: String = "explore"
	match str(run.get("phase", "")):
		"grubstake":
			mood = "shaft"
		"landing":
			mood = "rest"
		"hoard":
			mood = "hoard"
		"salvage", "over":
			mood = "over"
		"chamber":
			if DeepDescent.in_battle(run):
				var kind: String = str(run.get("chamber", {}).get("kind", "fight"))
				mood = "warden" if kind == "warden" else ("elite" if kind == "elite" else "fight")
	return {"place": mine, "mood": mood, "deep": depth_into(run), "next": ""}

static func depth_into(run: Dictionary) -> float:
	## How far down the mine the party is, 0 at the top to 1 at its boss. A mine with no bottom
	## climbs from 0 to 1 between one remembered Warden and the next.
	var depth: int = int(run.get("depth", 0))
	if depth <= 0:
		return 0.0
	var bottom: int = DeepDescent.bottom_of(run)
	if bottom > 1:
		return clampf(float(depth - 1) / float(bottom - 1), 0.0, 1.0)
	var every: int = DeepDescent.warden_every(DeepDescent.mine_of(run))
	return float((depth - 1) % every) / float(maxi(1, every - 1))

static func layer_levels(mood: String, deep: float) -> Array:
	## [bed, pulse, melody, drive, peril] for a mood at a depth. Deeper, the walk between
	## fights grows a stronger pulse and a louder tune, and near the bottom a breath of horn.
	var out: Array = MOODS.get(mood, MOODS.explore).duplicate()
	var d: float = clampf(deep, 0.0, 1.0)
	match mood:
		"explore":
			out[1] = float(out[1]) + 0.4 * d
			out[2] = float(out[2]) + 0.35 * d
			out[4] = maxf(0.0, d - 0.6) * 0.5
		"fight":
			out[4] = 0.25 * d
		"rest", "shaft":
			out[1] = float(out[1]) + 0.2 * d
	return out

# --- the service -------------------------------------------------------------------------------

func _ready() -> void:
	_service = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	DeepComposer.abandon = false
	_open_buses()
	_clock = Time.get_ticks_usec()

func _exit_tree() -> void:
	DeepComposer.abandon = true
	if _writer != null and _writer.is_started():
		_writer.wait_to_finish()
	_writer = null
	if _service == self:
		_service = null

func _open_buses() -> void:
	## Music on its own bus with a long, dark room on it; the air under the effects slider.
	if AudioServer.get_bus_index(BUS) < 0:
		var at: int = AudioServer.bus_count
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, BUS)
		AudioServer.set_bus_send(at, "Master")
		var room := AudioEffectReverb.new()
		room.room_size = 0.62
		room.damping = 0.6
		room.spread = 0.85
		room.hipass = 0.15
		room.predelay_msec = 40.0
		room.dry = 1.0
		room.wet = 0.2
		AudioServer.add_bus_effect(at, room)
	if AudioServer.get_bus_index(AIR_BUS) < 0:
		var at: int = AudioServer.bus_count
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, AIR_BUS)
		AudioServer.set_bus_send(at, DeepAudio.BUS if AudioServer.get_bus_index(DeepAudio.BUS) >= 0 else "Master")
		AudioServer.set_bus_volume_db(at, linear_to_db(AIR_LEVEL))
	DeepMusic.levels({})

func _process(_delta: float) -> void:
	## On the wall clock: a fight at four times speed or a held beat is not a reason to fade
	## the music faster or slower.
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf(float(now - _clock) / 1000000.0, 0.0, 0.25)
	_clock = now
	var want: Dictionary = _preview if not _preview.is_empty() else _where
	var place: String = str(want.get("place", DeepScore.HOME))
	var id: String = str(want.get("track", DeepScore.pick(place, _picks)))
	var playing: Dictionary = _decks.back() if not _decks.is_empty() else {}
	if str(playing.get("id", "")) != id:
		var strips: Array = baked(id)
		if strips.is_empty():
			strips = DeepComposer.written(id)
		if strips.is_empty():
			_ask("piece:" + id, true)
		else:
			_play_piece(id, strips, layer_levels(str(want.get("mood", "explore")), float(want.get("deep", 0.0))))
	var next: String = str(_where.get("next", ""))
	if DeepScore.BOOK.has(next) and not is_baked(DeepScore.pick(next, _picks)):
		_ask("piece:" + DeepScore.pick(next, _picks), false)
	var family: String = DeepScore.air(str(_where.get("place", DeepScore.HOME)))
	var breathing: Dictionary = _airs.back() if not _airs.is_empty() else {}
	if str(breathing.get("id", "")) != family:
		var loop: AudioStream = baked_air(family)
		if loop == null:
			loop = DeepComposer.air_written(family)
		if loop == null:
			_ask("air:" + family, true)
		else:
			_play_air(family, loop)
	_steer(layer_levels(str(want.get("mood", "explore")), float(want.get("deep", 0.0))), dt)
	_run_writer()

func _play_piece(id: String, strips: Array, levels_now: Array) -> void:
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = strips.size()
	var presence: Array = []
	for i in range(strips.size()):
		sync.set_sync_stream(i, strips[i])
		var level: float = float(levels_now[i]) if i < levels_now.size() else 0.0
		sync.set_sync_stream_volume(i, _db(level))
		presence.append(sqrt(level))
	var player := AudioStreamPlayer.new()
	player.bus = BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = sync
	player.volume_db = _db(0.0)
	add_child(player)
	player.play()
	for deck in _decks:
		deck.target = 0.0
	_decks.append({"id": id, "player": player, "sync": sync, "fade": 0.0, "target": 1.0, "presence": presence})

func _play_air(family: String, loop: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = AIR_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = loop
	player.volume_db = _db(0.0)
	add_child(player)
	## Somewhere in the loop rather than its start, so two visits never begin the same way.
	player.play(randf() * maxf(0.0, loop.get_length() - 1.0))
	for deck in _airs:
		deck.target = 0.0
	_airs.append({"id": family, "player": player, "fade": 0.0, "target": 1.0})

func _steer(levels_wanted: Array, dt: float) -> void:
	## Layers move on a curve that sounds even (presence, squared on the way out), up quickly
	## and down slowly; whole decks crossfade the same way.
	for deck in _decks:
		var presence: Array = deck.presence
		for i in range(presence.size()):
			var goal: float = sqrt(float(levels_wanted[i]) if i < levels_wanted.size() else 0.0)
			var was: float = float(presence[i])
			var moved: float = move_toward(was, goal, dt / (RISE if goal > was else FALL))
			if not is_equal_approx(moved, was):
				presence[i] = moved
				deck.sync.set_sync_stream_volume(i, _db(moved * moved))
	for list in [_decks, _airs]:
		for deck in list.duplicate():
			var was: float = float(deck.fade)
			deck.fade = move_toward(was, float(deck.target), dt / CROSSFADE)
			if not is_equal_approx(float(deck.fade), was):
				deck.player.volume_db = _db(float(deck.fade) * float(deck.fade))
			if float(deck.target) <= 0.0 and float(deck.fade) <= 0.0:
				deck.player.stop()
				deck.player.queue_free()
				list.erase(deck)

static func _db(level: float) -> float:
	return linear_to_db(maxf(level, 0.00001))

# --- writing on the worker thread --------------------------------------------------------------

func _ask(job: String, urgent: bool) -> void:
	var piece_id: String = job.trim_prefix("piece:")
	if job.begins_with("piece:") and DeepMusic.ready_to_play(piece_id):
		return
	if job.begins_with("air:") and DeepComposer.air_written(job.trim_prefix("air:")) != null:
		return
	if urgent and job.begins_with("piece:"):
		## Only the piece wanted now and the one likely next are worth writing: clicking
		## through the Soundtrack page leaves no queue of pieces nobody is listening to.
		var likely: String = "piece:" + DeepScore.pick(str(_where.get("next", "")), _picks) if DeepScore.BOOK.has(str(_where.get("next", ""))) else ""
		_queue = _queue.filter(func(other: String) -> bool: return not other.begins_with("piece:") or other == job or other == likely)
	if _queue.has(job):
		if urgent and _queue.find(job) > 0:
			_queue.erase(job)
			_queue.push_front(job)
		return
	if urgent:
		_queue.push_front(job)
	else:
		_queue.append(job)

func _run_writer() -> void:
	if _writer != null:
		if _writer.is_alive():
			return
		_writer.wait_to_finish()
		_writer = null
	if _queue.is_empty():
		return
	var job: String = str(_queue.pop_front())
	_writer = Thread.new()
	if _writer.start(_write.bind(job), Thread.PRIORITY_LOW) != OK:
		_writer = null
		## Nowhere to write it but here: a hitch now beats no music at all.
		_write(job)

func _write(job: String) -> void:
	if job.begins_with("piece:"):
		DeepComposer.piece(job.trim_prefix("piece:"))
	elif job.begins_with("air:"):
		DeepComposer.air(job.trim_prefix("air:"))
