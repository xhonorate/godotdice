extends Control
## A Birthstone's own pieces over its player's dock: what one stone needs on screen beyond its
## card and its count. A One-Armed Bandit's reel windows and pay table, a Blackjack's count, an
## Arpeggio's staff across the tray, the eyes on an Ill Omen's 1s.
##
## Every Birthstone may have one script in view/battle/birth/, named after the stone's id
## (`birthstone_FLORIN_ONE_ARMED_BANDIT` is florin_one_armed_bandit.gd, a delver's first stone
## is the delver alone: florin.gd). The battle screen makes one for each player's page whose
## stone has a script (`make`), keeps it told (`sync`, `thrown`, `event`, `fired`), and lets it
## play a tier its own way (`tier`). A stone with no script is drawn and played as before.
##
## An act lies over the whole screen, never takes the mouse itself (a child may), and shows
## only while its player's page is the one up in the dock. It draws in its own `_draw` from the
## rects below, or lays Controls and keeps them placed (`place`). Everything it knows comes
## from the fight as it stands (`unit`), the hand's forecast (`tiers`) and the events it is
## handed: it decides nothing.
##
## Both layouts: the same act serves the desktop's dock and the phone's. Sizes come from `u`
## (a desktop measure, or points on the phone); text is kept to the floor by `DeepUi.label` and
## `DeepUi.set_text_size`; anything pressed is at least `DeepUi.FINGER_LEAST` on the phone.

const GemIcons = preload("res://view/gems/gem_icons.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")

const DiceView = preload("res://view/dice/dice_view.gd")

const FOLDER: String = "res://view/battle/birth/"
## How long the dice tumble after a throw, for an act that spins with them.
const SPIN: float = DiceView.SPIN_SECONDS

## The battle screen, and the page of its dock this act stands on (BattleScreen.Page).
var screen: Control = null
var page: RefCounted = null
## The stone worn (`DeepStone.birthstone_for`), and its two hues.
var stone: Dictionary = {}
var tint: Color = Color.WHITE
var tint2: Color = Color.WHITE
## Whether this is the reader's own page.
var mine: bool = false

## The player as the fight has them now, the stone's tiers as content wrote them, and the same
## tiers as this hand would fire them (or did, once the stone has resolved this turn): by
## index, each {name, active, dice, counted, reason, effects, count, eclipsed}.
var unit: Dictionary = {}
var defs: Array = []
var tiers: Array = []
## The hand is still being chosen; the dice have stopped tumbling.
var planning: bool = false
var settled: bool = true

var _busy_until: int = 0
var _was_busy: bool = false
var _look: String = ""
var _placed: Array = []
var _opened: bool = false

# --- made by the battle screen -------------------------------------------------------------

static func path_for(worn: Dictionary) -> String:
	var id: String = str(worn.get("id", ""))
	if not id.begins_with("birthstone_"):
		return ""
	return FOLDER + id.trim_prefix("birthstone_").to_lower() + ".gd"

static func make(worn: Dictionary) -> Control:
	## The act for a stone, or null when it has none of its own.
	var path: String = path_for(worn)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var script: Variant = load(path)
	if not script is GDScript or not (script as GDScript).can_instantiate():
		return null
	var act: Variant = (script as GDScript).new()
	if not act is Control:
		return null
	return act

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var second: Color = GemMesh.tint2(stone) if not stone.is_empty() else Color(0, 0, 0, 0)
	tint2 = second if second.a > 0.0 else tint.lightened(0.3)
	mine = page != null and bool(page.mine)
	visible = false
	_open()
	_opened = true

func sync(now: Dictionary, previewed: Array, is_planning: bool, is_settled: bool) -> void:
	## The fight as it stands, told again whenever the screen is.
	unit = now
	defs = now.get("birthstone", {}).get("tiers", [])
	tiers = previewed
	planning = is_planning
	settled = is_settled
	if _opened:
		_sync_act()
		queue_redraw()

func thrown() -> void:
	## The dice have just been thrown (a turn opening, a reroll): they tumble for `SPIN`.
	if _opened and not DeepUi.headless():
		busy(SPIN + 0.2)
		_thrown()

func event(played: Dictionary) -> void:
	## Any event of the fight as it is played, this player's or not.
	if _opened:
		_event(played)

func fired(played: Dictionary) -> void:
	## This player's Birthstone has lit; its tiers follow one by one (`tier`).
	if _opened:
		_fired(played)

func tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## One lit tier is landing. True when the act played its effects itself; false leaves them
	## to the screen's own bolts and numbers.
	return _tier(entry, effects, origin, tone) if _opened else false

func button_words() -> Dictionary:
	## Other words for the reader's buttons while this stone is worn: {"reroll", "lock"}, and
	## "reroll_icon", a mark of gem_icons.gd for the throw button.
	return _button_words()

func spin_extra() -> float:
	## How much longer than the dice's own tumble the hand keeps its secret: the rail lights
	## and the tiers are read only once this has passed too (a Bandit's reels stop one by one).
	return _spin_extra()

# --- what a stone's script fills in -----------------------------------------------------------

func _open() -> void:
	pass

func _sync_act() -> void:
	pass

func _thrown() -> void:
	pass

func _event(_played: Dictionary) -> void:
	pass

func _fired(_played: Dictionary) -> void:
	pass

func _tier(_entry: Dictionary, _effects: Array, _origin: Vector3, _tone: Color) -> bool:
	return false

func _button_words() -> Dictionary:
	return {}

func _spin_extra() -> float:
	return 0.0

func _look_key() -> String:
	## Anything the act draws from that `_process` should redraw for when it changes; the
	## rects of the dock are watched already.
	return ""

func _tick(_delta: float) -> void:
	## Every frame the act's page is up, before it is drawn. (A stone's script never writes
	## `_process` or `_ready` of its own: these hooks are how it joins them.)
	pass

# --- every frame -----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var up: bool = on_screen()
	if visible != up:
		visible = up
	if not up:
		return
	for entry in _placed:
		_put(entry)
	_tick(_delta)
	var look: String = "%s|%s|%s|%s" % [str(tray_rect()), str(stone_rect()), str(ring_rect()), _look_key()]
	## Drawn again while something moves, and once more after it has stopped: the last frame
	## of a flash is the one without it.
	var moving: bool = Time.get_ticks_msec() < _busy_until
	if look != _look or moving or _was_busy:
		_look = look
		queue_redraw()
	_was_busy = moving

func busy(seconds: float) -> void:
	## Redraw every frame for this long: something of the act's is moving.
	_busy_until = maxi(_busy_until, Time.get_ticks_msec() + int(seconds * 1000.0))

func on_screen() -> bool:
	## Whether this act's page is the one up in the dock.
	return page != null and page.root != null and is_instance_valid(page.root) and (page.root as Control).is_visible_in_tree()

# --- measures -----------------------------------------------------------------------------------

static func u(desk: float, phone_points: float = -1.0) -> float:
	## A measure in canvas pixels: `desk` on the desktop, `phone_points` points on the phone
	## (left out, `desk` halved and read as points, which keeps a mark's share of a 44 pt die).
	if not DeepUi.phone:
		return desk
	return DeepUi.pt(phone_points if phone_points >= 0.0 else desk * 0.5)

static func text_px(desk: int, phone_points: int = 11) -> int:
	## A text size for `DeepUi.label`: the desktop's, or the phone's in points (11 at the least).
	return desk if not DeepUi.phone else maxi(11, phone_points)

func local(rect: Rect2) -> Rect2:
	## A rect on the screen, in this act's own space.
	return Rect2(rect.position - global_position, rect.size)

func _rect_of(control: Variant) -> Rect2:
	if control == null or not control is Control or not is_instance_valid(control) or not (control as Control).is_inside_tree():
		return Rect2()
	return local((control as Control).get_global_rect())

func tray_rect() -> Rect2:
	## The row of dice.
	return _rect_of(page.tray_box) if page != null else Rect2()

func dice() -> Array:
	## The hand's own dice, left to right as the tray shows them (no phantoms).
	return unit.get("hand", []).filter(func(roll: Dictionary) -> bool: return not bool(roll.get("phantom", false)))

func die_view(die_id: String) -> Control:
	var view: Variant = page.dice_views.get(die_id, null) if page != null else null
	return view if view is Control and is_instance_valid(view) else null

func die_rect(die_id: String) -> Rect2:
	## A die's seat in the tray: a square the dock's die edge wide. The solid is drawn in the
	## middle of it (`die_face`).
	return _rect_of(die_view(die_id))

func die_face(die_id: String) -> Rect2:
	## About where a die's solid shows in its seat: the square a mark is hung on.
	var seat: Rect2 = die_rect(die_id)
	if seat.size.x <= 0.0:
		return seat
	var edge: float = seat.size.x * (0.66 if DeepUi.phone else 0.6)
	return Rect2(seat.get_center() - Vector2(edge, edge) * 0.5, Vector2(edge, edge))

func stone_rect() -> Rect2:
	## The Birthstone's ring on the rail.
	var card: Variant = page.birthstone_card if page != null else null
	if card == null or not is_instance_valid(card):
		return Rect2()
	return _rect_of((card as Control).get_node_or_null("Slot"))

func stone_card() -> Control:
	var card: Variant = page.birthstone_card if page != null else null
	return card if card is Control and is_instance_valid(card) else null

func ring_rect() -> Rect2:
	## The player's face in the ring of their health.
	return _rect_of(page.hp_bar) if page != null else Rect2()

func resonance_rect() -> Rect2:
	return _rect_of(page.resonance_box) if page != null else Rect2()

func block_rect() -> Rect2:
	## The Block badge at the top of the health ring (empty while it is hidden).
	var badge: Variant = page.status_row if page != null else null
	return _rect_of(badge) if badge is Control and is_instance_valid(badge) and (badge as Control).is_visible_in_tree() else Rect2()

func die_corner(die_id: String, corner: int = CORNER_TOP_RIGHT, edge: float = -1.0) -> Rect2:
	## A square for a small mark hung on a die's corner (CORNER_TOP_LEFT, ...), `edge` wide
	## (left out, a third of the die's face). Two marks on one die take two corners.
	var face: Rect2 = die_face(die_id)
	if face.size.x <= 0.0:
		return face
	var wide: float = edge if edge > 0.0 else face.size.x * 0.36
	var at: Vector2 = face.position - Vector2(wide, wide) * 0.4
	if corner == CORNER_TOP_RIGHT or corner == CORNER_BOTTOM_RIGHT:
		at.x = face.end.x - wide * 0.6
	if corner == CORNER_BOTTOM_LEFT or corner == CORNER_BOTTOM_RIGHT:
		at.y = face.end.y - wide * 0.6
	return Rect2(at, Vector2(wide, wide))

func socket_rect(socket: int) -> Rect2:
	## A socket's ring on the rail (its card's Main), or an empty rect.
	if page == null or page.rail_box == null or not is_instance_valid(page.rail_box) or socket < 0 or socket >= page.rail_box.get_child_count():
		return Rect2()
	var host: Node = page.rail_box.get_child(socket)
	var main: Node = host.get_node_or_null("Main")
	var slot: Node = main.get_node_or_null("Slot") if main != null else null
	return _rect_of(slot if slot != null else (main if main != null else host))

func dock_rect() -> Rect2:
	return _rect_of(screen._dock) if screen != null else Rect2()

func over_tray() -> float:
	## The y a piece set over the tray stands its foot on: clear of the dock's top edge on the
	## desktop, and of the line of words that floats over the dice on the phone.
	var tray: Rect2 = tray_rect()
	if DeepUi.phone:
		var said: Variant = page.hint if page != null else null
		var wordy: bool = said is Label and is_instance_valid(said) and not (said as Label).text.is_empty()
		return tray.position.y - DeepUi.pt(26.0 if wordy else 10.0)
	return dock_rect().position.y - 8.0

# --- pieces kept in place ---------------------------------------------------------------------

func place(control: Control, where: String, align: float = 0.5, nudge: Vector2 = Vector2.ZERO) -> Control:
	## Keeps a child standing somewhere on the dock as the dock moves: "over_tray" (its foot on
	## `over_tray`, `align` along the tray's width: 0 its left end, 1 its right), "over_stone"
	## (centred over the Birthstone's ring), "under_stone", "over_ring" (over the health ring),
	## "left_of_tray" (its right edge at the tray's left, feet level with the dice). Returns it.
	if control.get_parent() == null:
		add_child(control)
	_placed.append({"control": control, "where": where, "align": align, "nudge": nudge})
	return control

func _put(entry: Dictionary) -> void:
	var control: Control = entry.control
	if not is_instance_valid(control):
		return
	var size_now: Vector2 = control.get_combined_minimum_size().max(control.size if not control is Container else Vector2.ZERO)
	if control is Container:
		control.size = size_now
	var at := Vector2.ZERO
	match str(entry.where):
		"over_tray":
			var tray: Rect2 = tray_rect()
			at = Vector2(tray.position.x + (tray.size.x - size_now.x) * float(entry.align), over_tray() - size_now.y)
		"over_stone":
			var ring: Rect2 = stone_rect()
			at = Vector2(ring.get_center().x - size_now.x * 0.5, minf(ring.position.y, dock_rect().position.y) - size_now.y - u(6.0, 3.0))
		"under_stone":
			var ring: Rect2 = stone_rect()
			at = Vector2(ring.get_center().x - size_now.x * 0.5, ring.end.y + u(2.0, 1.0))
		"over_ring":
			var ring: Rect2 = ring_rect()
			at = Vector2(ring.get_center().x - size_now.x * 0.5, minf(ring.position.y, dock_rect().position.y) - size_now.y - u(6.0, 3.0))
		"left_of_tray":
			var tray: Rect2 = tray_rect()
			at = Vector2(tray.position.x - size_now.x - u(10.0, 5.0), tray.position.y + (tray.size.y - size_now.y) * float(entry.align))
	at += entry.nudge
	## Never off the screen, nor under the phone's camera island.
	var left: float = DeepUi.safe_left if DeepUi.phone else 4.0
	var right: float = size.x - (DeepUi.safe_right if DeepUi.phone else 4.0)
	at.x = clampf(at.x, left, maxf(left, right - size_now.x))
	at.y = maxf(at.y, DeepUi.safe_top if DeepUi.phone else 4.0)
	if not control.position.is_equal_approx(at):
		control.position = at

func plate(pad_x: float = 10.0, pad_y: float = 5.0, line: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	## A small Ledger-dark panel for a readout over the dock, edged in the stone's color.
	var panel := PanelContainer.new()
	var box: StyleBoxFlat = DeepUi.flat(Color(DeepUi.LEDGER_FILL, 0.94), line if line.a > 0.0 else tint.lerp(DeepUi.LEDGER_LINE, 0.35), int(u(6.0, 3.0)), 0, 2)
	box.content_margin_left = u(pad_x)
	box.content_margin_right = u(pad_x)
	box.content_margin_top = u(pad_y)
	box.content_margin_bottom = u(pad_y)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func tip(control: Control, build: Callable, opts: Dictionary = {}) -> void:
	## A plate for one of the act's own pieces, on hover or under a held finger (`build` returns
	## the plate, see view/ui/plates.gd). The piece lies over the room, so a press on it is still
	## a press on the room behind it: a creature picked, a turn hurried.
	Tips.attach(control, build, opts)
	control.gui_input.connect(func(input: InputEvent) -> void:
		if input is InputEventMouseButton and screen != null and is_instance_valid(screen._picker):
			var through: InputEventMouseButton = input.duplicate()
			through.position = control.global_position + input.position - (screen._picker as Control).global_position
			screen._pick_input(through))

func words(parent: Node, text: String, desk: int, tone: Color, bold: bool = true) -> Label:
	## A line of an act's own text: the kit's label at the desktop's size or the phone's floor,
	## edged dark so it reads over the room.
	var said: Label = DeepUi.label(parent, text, text_px(desk), tone)
	if bold:
		said.add_theme_font_override("font", DeepUi.bold_font())
	said.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	said.add_theme_constant_override("outline_size", int(u(4.0, 2.0)))
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return said

# --- reading the hand --------------------------------------------------------------------------

func tier_index(tier_name: String) -> int:
	for index in range(defs.size()):
		if str(defs[index].get("name", "")) == tier_name:
			return index
	return -1

func tier_now(tier_name: String) -> Dictionary:
	## A tier as this hand reads it ({} when it is not known yet).
	var index: int = tier_index(tier_name)
	return tiers[index] if index >= 0 and index < tiers.size() and tiers[index] is Dictionary else {}

func lit(tier_name: String) -> bool:
	## Whether the hand in the tray would fire this tier (or did). False while the dice tumble.
	return settled and bool(tier_now(tier_name).get("active", false))

func resonance_now() -> int:
	## The Resonance the rail would bring the stone this turn: the forecast's while the hand is
	## planned, the count the fight holds once it resolves.
	if page != null and planning:
		var seen: Dictionary = page.forecast.get("birthstone", {})
		if seen.has("resonance"):
			return int(seen.resonance)
		return int(page.forecast.get("resonance", unit.get("resonance", 0)))
	return int(unit.get("resonance", 0))

func reading() -> Dictionary:
	## The hand as the rules read it (`DeepHand.analyze`): counts, sets, runs, crowns, the scale.
	return DeepHand.analyze(unit.get("hand", []))

func forecast() -> Dictionary:
	## What the rail would do with the hand as it stands, while it is planned: {"sockets":
	## [{socket, skill, active, reason, dice, effects, ...}], "totals": {damage, block, heal,
	## gold, poison, fires, fizzles, resonance}, "birthstone": {fired, tiers, resonance,
	## climbed, colors}}. Held as it was at the lock while the turn resolves.
	return page.forecast if page != null else {}

func picked() -> Array:
	## The dice the reader has picked to throw again or turn over (their own page only).
	return screen.selected if screen != null and mine else []

func hand_total() -> int:
	var total: int = 0
	for roll in dice():
		total += int(roll.get("value", 0))
	return total

func showing_one(roll: Dictionary) -> bool:
	return str(roll.get("kind", "plain")) != "wild" and int(roll.get("value", 0)) == 1

func crowned(roll: Dictionary) -> bool:
	return DeepBattle.is_crown(roll)

# --- saying and throwing ------------------------------------------------------------------------

func say(anchor: Variant, text: String, tone: Color, px: int = 18) -> void:
	## Words that rise and fade: over a Control, or at a point of this act's own space.
	if screen == null or DeepUi.headless():
		return
	if anchor is Control:
		screen._float_at(anchor, text, tone, px)
	elif anchor is Vector2:
		DeepUi.float_text(screen, (anchor as Vector2) + global_position - screen.global_position, text, tone, px)

func call_out(text: String, tone: Color, sub: String = "", hold: float = 1.0) -> void:
	## A title across the room (the screen's own banner).
	if screen != null and mine and not DeepUi.headless():
		screen._announce(text, tone, sub, hold)

func later(seconds: float, work: Callable) -> void:
	## One beat of a moment, on the fight's own clock; nothing here outlives the screen.
	if screen != null:
		var act: Control = self
		screen._later_do(seconds, func() -> void:
			if is_instance_valid(act):
				work.call())

func land(effects: Array, origin: Vector3, tone: Color, magnitude: float = 1.0) -> void:
	## What a tier did, played the screen's own way from `origin`: a bolt a blow, numbers, and
	## the bars moving as each lands. An act that plays a tier itself still lands its numbers
	## through this (all of them, or a few at a time between its own beats).
	if screen != null and not DeepUi.headless():
		screen._animate_effects(effects, origin, tone, mine, stone_card(), magnitude, str(unit.get("id", "")))

func sound(sound_name: String, opts: Dictionary = {}) -> void:
	## One of the bank's sounds (view/audio/sound_bank.gd), quieter for someone else's stone.
	if DeepUi.headless():
		return
	var said: Dictionary = opts.duplicate()
	if not mine:
		said.volume = float(said.get("volume", 1.0)) * 0.6
	DeepAudio.play(sound_name, said)

func burst(at: Vector2, tone: Color, amount: int = 16, speed: float = 160.0, seconds: float = 0.6, dot: float = 5.0) -> void:
	## A puff of sparks at a point of this act's own space.
	if screen != null and not DeepUi.headless():
		DeepUi.burst(screen, at + global_position - screen.global_position, tone, amount, speed, seconds, dot)

func room_point(at: Vector2, distance: float = 1.6) -> Vector3:
	## The point in the room behind a point of this act's own space, for a bolt to leave from.
	if screen == null or DeepUi.headless() or screen._camera == null:
		return Vector3.ZERO
	return screen._from_screen(at + global_position - screen.global_position, distance)

func screen_point(at: Vector3) -> Vector2:
	## Where a point in the room shows, in this act's own space.
	if screen == null or DeepUi.headless() or screen._camera == null:
		return size * 0.5
	return screen._to_screen(at) + screen.global_position - global_position

func creature_at(id: String) -> Vector2:
	## Where a creature stands, in this act's own space (the middle of the room when it is gone).
	var creature: Variant = screen._creature(id) if screen != null else null
	if creature == null or not is_instance_valid(creature) or screen._camera == null:
		return Vector2(size.x * 0.5, size.y * 0.3)
	return screen_point(creature.centre())

func creature_point(id: String) -> Vector3:
	## A creature's middle in the room, or a point before the camera when it is gone.
	var creature: Variant = screen._creature(id) if screen != null else null
	if screen == null or screen._camera == null:
		return Vector3.ZERO
	if creature == null or not is_instance_valid(creature):
		return screen._camera.global_position + (-screen._camera.global_transform.basis.z) * 6.0
	return creature.centre()

func target_id() -> String:
	## The creature the player is aimed at.
	return str(unit.get("target", ""))

func living() -> Array:
	## The ids of the creatures still standing, left to right.
	var out: Array = []
	for foe in screen.state.get("enemies", []) if screen != null else []:
		if int(foe.get("hp", 0)) > 0 and not bool(foe.get("downed", false)):
			out.append(str(foe.get("id", "")))
	return out

func fx() -> Node3D:
	## The room's own effects (view/battle/battle_fx.gd): projectile, sparks, shards, ring_wave, ...
	## Null with no display to draw them on: ask before every use.
	return screen._fx if screen != null and not DeepUi.headless() else null

# --- drawing ----------------------------------------------------------------------------------

func draw_glyph(glyph: String, box: Rect2, tone: Color) -> void:
	## One of gem_icons.gd's marks, drawn into a square of this act's own space.
	if box.size.x <= 0.0 or not GemIcons.known(glyph):
		return
	draw_texture_rect(GemIcons.texture(glyph, GemIcons.baked_size(box.size.x * 1.5)), box, false, tone)

func draw_words(text: String, at: Vector2, px: int, tone: Color, centred: bool = true, bold: bool = true, edged: bool = true) -> void:
	## A few words drawn straight onto the act (a count on a mark), edged dark unless `edged`
	## is off (dark words on a bright chip), never under the text floor. `at` is the middle of
	## the line when `centred`, else its left end, half way up either way.
	var size_px: int = maxi(px, DeepUi.min_text())
	var font: Font = DeepUi.bold_font() if bold else DeepUi.body_font()
	var wide: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var from := Vector2(at.x - (wide.x * 0.5 if centred else 0.0), at.y + (font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5)
	if edged:
		draw_string_outline(font, from, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, maxi(2, int(u(4.0, 2.0))), Color(0.02, 0.03, 0.05, 0.9))
	draw_string(font, from, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, tone)
