extends RefCounted
## Reveals that survive a re-render.
##
## The interface rebuilds its page from the snapshot whenever anything changes, so an
## animation that lived on a node would restart every time another player readied up. A
## reveal lives here instead, keyed by what it reveals: the first time a key is asked for,
## its clock starts, and every node registered under it afterwards — the same card rebuilt
## ten times — is posed from that one clock. A rebuilt screen picks the moment up where it
## was rather than playing it again.
##
## Styles only touch `scale`, `modulate` and, for a count, a label's text, because a
## container owns its children's positions and would fight anything else.

signal wake

## How long each style takes when the caller does not say.
const SPANS := {"fade": 0.4, "vanish": 0.25, "pop": 0.42, "flip": 0.5, "stamp": 0.34, "count": 0.8, "glow": 0.9, "rise": 0.45}

var reduced := false
var _starts: Dictionary = {}
var _items: Array = []
var _wakes: Array = []
var _cues: Dictionary = {}

func now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func begin(key: String) -> float:
	if not _starts.has(key):
		_starts[key] = now()
	return float(_starts[key])

func started(key: String) -> bool:
	return _starts.has(key)

func age(key: String) -> float:
	return now() - begin(key)

func reset() -> void:
	## A new expedition: nothing it shows has been seen before.
	_starts.clear()
	_items.clear()
	_wakes.clear()
	_cues.clear()

func hurry() -> void:
	## Everything under way lands now. The reader asked to skip, not to miss anything.
	for key in _starts:
		_starts[key] = float(_starts[key]) - 60.0
	for item in _items:
		item.at = float(item.at) - 60.0
	for tag in _cues:
		_cues[tag].at = float(_cues[tag].at) - 60.0
	for index in _wakes.size():
		_wakes[index] = float(_wakes[index]) - 60.0
	process()
	wake.emit()

func reached(key: String, delay: float) -> bool:
	## Whether a moment in a reveal has passed. If not, the page is woken when it does, so a
	## button that waits for its card to turn over is enabled without anything else changing.
	if reduced:
		return true
	var at := begin(key) + delay
	if now() >= at:
		return true
	if not at in _wakes:
		_wakes.append(at)
	return false

func cue(key: String, delay: float, action: Callable) -> void:
	## Runs `action` once when the moment arrives — a sound on a card turning, say. Asking
	## again after a rebuild does not run it twice.
	var tag := "%s@%.3f" % [key, delay]
	if _cues.has(tag):
		return
	_cues[tag] = {"at": begin(key) + (0.0 if reduced else delay), "action": action, "done": false}
	process()

func show(node: Control, key: String, delay: float = 0.0, style := "pop", span := -1.0) -> Control:
	if node == null:
		return node
	var entry := {"node": weakref(node), "at": begin(key) + delay, "span": span if span > 0.0 else float(SPANS.get(style, 0.4)), "style": style}
	_apply(entry, now())
	if not reduced:
		_items.append(entry)
	return node

func flip(card: Control, back: Control, key: String, delay: float = 0.0, span := -1.0, front: Control = null) -> Control:
	## A card that starts face down: `back` covers it and turns away half way through, and
	## `front`, if given, stays invisible until then so nothing shows through the back.
	card.set_meta("reveal_back", back)
	if front != null:
		card.set_meta("reveal_front", front)
	return show(card, key, delay, "flip", span)

func count(label: Label, key: String, delay: float, target: int, format := "%d") -> Label:
	label.set_meta("count_to", target)
	label.set_meta("count_format", format)
	show(label, key, delay, "count")
	return label

func process() -> void:
	var moment := now()
	var live: Array = []
	for entry in _items:
		var node: Object = entry.node.get_ref()
		if node == null or not is_instance_valid(node):
			continue
		if _apply(entry, moment) < 1.0:
			live.append(entry)
	_items = live
	for tag in _cues:
		var pending: Dictionary = _cues[tag]
		if not pending.done and moment >= float(pending.at):
			pending.done = true
			# A moment long gone — skipped past, or reached before anyone was watching — passes
			# in silence rather than every sound of a reveal arriving at once.
			if pending.action.is_valid() and moment - float(pending.at) < 1.0:
				pending.action.call()
	var due := false
	var waiting: Array = []
	for at in _wakes:
		if moment >= float(at):
			due = true
		else:
			waiting.append(at)
	_wakes = waiting
	if due:
		wake.emit()

func _apply(entry: Dictionary, moment: float) -> float:
	var node: Control = entry.node.get_ref()
	if node == null:
		return 1.0
	var t := 1.0 if reduced else clampf((moment - float(entry.at)) / float(entry.span), 0.0, 1.0)
	node.pivot_offset = node.size * 0.5
	match str(entry.style):
		"fade":
			node.modulate.a = t
		"vanish":
			node.modulate.a = 1.0 - t
		"rise":
			node.modulate.a = t
			node.scale = Vector2.ONE * lerpf(0.94, 1.0, ease(t, 0.3))
		"pop":
			node.modulate.a = clampf(t * 3.0, 0.0, 1.0)
			node.scale = Vector2.ONE * _overshoot(t)
		"stamp":
			node.modulate.a = clampf(t * 2.5, 0.0, 1.0)
			node.scale = Vector2.ONE * lerpf(2.2, 1.0, ease(t, 0.35))
		"glow":
			var lift := 1.0 - ease(t, 0.5)
			node.modulate = Color(1.0 + 1.2 * lift, 1.0 + 1.0 * lift, 1.0 + 0.6 * lift, 1.0)
		"count":
			var label := node as Label
			if label != null:
				label.text = str(label.get_meta("count_format", "%d")) % roundi(lerpf(0.0, float(label.get_meta("count_to", 0)), ease(t, 0.4)))
		"flip":
			var back: Control = node.get_meta("reveal_back", null)
			var turned := t >= 0.5
			if back != null and is_instance_valid(back):
				back.modulate.a = 0.0 if turned else 1.0
				back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var front: Control = node.get_meta("reveal_front", null)
			if front != null and is_instance_valid(front):
				front.modulate.a = 1.0 if turned else 0.0
			var half := absf(t - 0.5) * 2.0
			node.scale = Vector2(maxf(0.02, ease(half, 0.6)), 1.0 + 0.04 * (1.0 - half))
			node.modulate = Color(1.0, 1.0, 1.0, 1.0) if not turned else Color(1.0 + 0.9 * (1.0 - t), 1.0 + 0.8 * (1.0 - t), 1.0 + 0.5 * (1.0 - t), 1.0)
	return t

func _overshoot(t: float) -> float:
	if t >= 1.0:
		return 1.0
	var c := 1.9
	var u := t - 1.0
	return lerpf(0.55, 1.0, 1.0 + (c + 1.0) * u * u * u + c * u * u)
