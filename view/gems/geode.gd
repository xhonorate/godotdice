extends CanvasLayer
## A Geode cracked on the bench, and the drum inside it (docs/GOLD.md §3.3).
##
## The stone a Geode holds was rolled when the shelf was stocked and is on the tray, already
## read, by the time this opens: everything here is the showing, and skipping it loses nothing.
##
## It plays like the slot machine the appraisal has always been. The Geode sits in front of a
## brass-bound drum with a lever at its side. The lever comes down, the shell splits along its
## seam, and the drum inside spins: a strip of stones, every one a stone this Geode could have
## held, drawn at the odds its card printed, slowing tooth by tooth past the loupe's hairline
## until it stops on the one it did hold. The lamps round the drum chase while it spins and
## flash the stone's rarity when it stops, and a rare one gets the whole machine. Then the
## stone itself is set on the lamp and read out line by line, the way every stone is.
##
## A contract plays the same ending from another start (`fuse`): five stones go into the
## middle of the bench and come out as one.
##
## A click or Space pulls the lever, skips the spin to its last tooth, and skips the reading;
## Escape at the end takes the gentlest way out (the stone waits on the tray).

const GemView = preload("res://view/gems/gem_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")
const Inspector = preload("res://view/inspect/inspector.gd")

## The drum: how big a stone on it is, how far apart, how many go by, and which one wins.
const TILE := Vector2(144, 176)
const GAP: float = 12.0
const STRIDE: float = TILE.x + GAP
const TILES: int = 64
const START_AT: int = 3
const WIN_AT: int = 56
## How long the drum turns, and how hard it leans on the brake at the end (the higher, the
## longer the last few teeth take to come round).
const SPIN: float = 6.4
const BRAKE: float = 3.6
## The machine on the bench: the whole of it, and the window the drum shows through.
const STAGE := Vector2(1360, 420)
const BODY := Rect2(40, 34, 1180, 352)
const WINDOW := Rect2(78, 104, 1104, 216)
## How long each line of the stone's sheet holds once the drum has stopped: brisker than the
## appraisal at the workshop, because the drum has already had its moment.
const PAUSES: Dictionary = {"name": 0.7, "carat": 0.55, "cut": 0.45, "clarity": 0.6, "inclusions": 0.6,
	"inclusion": 0.75, "grade": 1.0, "worth": 0.6, "compare": 0.6}
const RARITIES: Array = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY", "MYTHIC"]

static var _open: CanvasLayer = null

## What is being opened: the Geode (or for a contract, the stones that went in) and the
## stone that came out, read.
var geode: Dictionary = {}
var given: Array = []
var stone: Dictionary = {}
var owned: Dictionary = {}
## The choices at the end: {label, glyph, tone, caption, call, primary, dismiss}.
var actions: Array = []
var mode: String = "geode"
var new_skill: bool = false
var wanted: String = ""

var _root: Control
var _dim: ColorRect
var _rays: Control
var _title: Label
var _subtitle: Label
var _slot: Control
var _stage: Control
var _housing: Housing
var _reel: Reel
var _glass: Glass
var _art: Art
var _lever: Lever
var _swirl: Swirl
var _legend: Control
var _reveal: PanelContainer
var _reveal_style: StyleBoxFlat
var _halo: Control
var _lamp: TextureRect
var _view: Control
var _sheet: Appraisal.Sheet
var _skip: Label
var _choices: Control
var _gleam: Appraisal.Gleam
var _flash: ColorRect
var _tone: Color = DeepUi.ACCENT
var _tweens: Array = []
## Where the showing has got to: waiting on the lever, the drum turning, stopped on the stone,
## the stone being read, and over.
var _phase: String = "ready"
var _clock: float = 0.0
var _spin_from: float = 0.0
var _spin_to: float = 0.0
var _last_tooth: int = -1
var _top_speed: float = 1.0
var _closing: bool = false

static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)

static func open(shelf_geode: Dictionary, made: Dictionary, opts: Dictionary = {}) -> CanvasLayer:
	## Cracks a Geode on screen: `made` is the stone it held, already on the tray. `opts` may
	## carry `owned` (the stone of its skill already kept), `actions`, `new_skill` and
	## `wanted` (words for the commission that wants it). Nothing happens without a display.
	return _show("geode", shelf_geode, [], made, opts)

static func fuse(inputs: Array, made: Dictionary, opts: Dictionary = {}) -> CanvasLayer:
	## Signs a contract on screen: the five `inputs` go in, `made` comes out.
	return _show("contract", {}, inputs, made, opts)

static func _show(kind: String, shelf_geode: Dictionary, inputs: Array, made: Dictionary, opts: Dictionary) -> CanvasLayer:
	if DisplayServer.get_name() == "headless":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if is_open():
		_open.queue_free()
	Inspector.close()
	var built: CanvasLayer = load("res://view/gems/geode.gd").new()
	tree.root.add_child(built)
	built.call("build", kind, shelf_geode, inputs, made, opts)
	built.call("play")
	_open = built
	return built

# --- building -------------------------------------------------------------------------------------

func build(kind: String, shelf_geode: Dictionary, inputs: Array, made: Dictionary, opts: Dictionary = {}) -> void:
	## Everything laid out from the start, hidden where it waits its turn, so nothing moves as
	## it is shown. `finish()` jumps to the end; `play()` plays it out.
	layer = 61
	mode = kind
	geode = shelf_geode
	given = inputs
	stone = made.duplicate(true)
	stone.appraised = true
	stone.inclusions_revealed = true
	owned = opts.get("owned", {})
	actions = opts.get("actions", [])
	new_skill = bool(opts.get("new_skill", false))
	wanted = str(opts.get("wanted", ""))
	_tone = theme_tone(geode) if mode == "geode" else DeepUi.tier_color(str(DeepStone.grade(stone).tier))
	_root = Control.new()
	_root.theme = DeepUi.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	## Opaque: the shelf behind already shows the Geode open, and the stone it held, and must
	## not give it away through the dark.
	_dim.color = Color("05070b")
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	_rays = Inspector.Rays.new(_tone)
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.modulate.a = 0.35
	_rays.set("offset", Vector2(0, -30))
	_root.add_child(_rays)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var column := DeepUi.vbox(centre, 8)
	_title = DeepUi.title(column, geode_name(geode) if mode == "geode" else "A contract", 40, _tone.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("outline_size", 10)
	var said: String = "Pull the lever to crack it open" if mode == "geode" else "Five %s stones, sealed into one" % DeepStone.TIER_NAMES.get(str(DeepStone.grade(given[0]).tier) if not given.is_empty() else "ROUGH", "")
	_subtitle = DeepUi.label(column, said, 17, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	## One slot the machine and the stone's own reading take turns in, so the page does not
	## jump when one gives way to the other.
	_slot = Control.new()
	_slot.custom_minimum_size = Vector2(STAGE.x, 470)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_slot)
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.position = Vector2(0, 18)
	_slot.add_child(_stage)
	if mode == "geode":
		_build_machine()
	else:
		_build_fusion()
	_build_reveal()
	var foot := DeepUi.vbox(column, 6)
	foot.custom_minimum_size.y = 84
	_legend = _odds_legend(foot) if mode == "geode" else DeepUi.gap(foot, 1)
	_skip = DeepUi.label(foot, "Click the lever, or press Space" if mode == "geode" else "Click or press Space to skip ahead", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_choices = Appraisal.choices(foot, actions, close)
	_choices.visible = false
	_gleam = Appraisal.Gleam.new()
	_gleam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_gleam)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

func _build_machine() -> void:
	var kinds: Dictionary = {"mine": "A mine's Geode", "color": "A color's Geode", "featured": "The week's Geode"}
	_housing = Housing.new(_tone, str(kinds.get(str(geode.get("kind", "mine")), "A Geode")))
	_housing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_housing)
	var window := Control.new()
	window.position = WINDOW.position
	window.size = WINDOW.size
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(window)
	_reel = Reel.new(_strip())
	_reel.size = WINDOW.size
	_reel.offset = float(START_AT) * STRIDE + TILE.x * 0.5
	window.add_child(_reel)
	_glass = Glass.new(_tone)
	_glass.position = WINDOW.position
	_glass.size = WINDOW.size
	_stage.add_child(_glass)
	## The Geode sits over the middle of the window, inside the bezel, clear of the plaque.
	_art = Art.new(geode, _tone)
	_art.size = Vector2(WINDOW.size.x * 0.42, WINDOW.size.y + 20)
	_art.position = WINDOW.position + Vector2(WINDOW.size.x * 0.29, -10)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_art)
	_lever = Lever.new(_tone)
	_lever.position = Vector2(BODY.end.x - 10, BODY.position.y)
	_lever.size = Vector2(150, BODY.size.y)
	_lever.pulled.connect(_pull)
	_stage.add_child(_lever)

func _build_fusion() -> void:
	_swirl = Swirl.new(given, stone, _tone)
	_swirl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_swirl)

func _build_reveal() -> void:
	## The stone on the lamp beside its sheet, waiting behind the machine until the drum stops.
	_reveal = PanelContainer.new()
	_reveal_style = DeepUi.raised(Color(0.045, 0.055, 0.08, 0.97), Color(_tone, 0.6), 18, 18, 0.7)
	_reveal_style.set_border_width_all(2)
	_reveal_style.shadow_color = Color(_tone, 0.2)
	_reveal_style.shadow_size = 30
	_reveal.add_theme_stylebox_override("panel", _reveal_style)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal.visible = false
	## Centred in the slot by a container, so it is laid out at the size its sheet comes to.
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(holder)
	holder.add_child(_reveal)
	var row := DeepUi.hbox(_reveal, 26)
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(380, 380)
	stand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stand)
	_halo = Inspector.Halo.new(_tone)
	_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stand.add_child(_halo)
	_lamp = DeepUi.glow(stand, _tone, 0.35, 1.1)
	_view = GemView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_slot(230.0)
	_view.set_drift(true)
	_view.set_spin(0.6)
	_view.configure(stone)
	stand.add_child(_view)
	_sheet = Appraisal.Sheet.new(stone, owned, {"skill_text": true})
	_sheet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sheet)

func _odds_legend(parent: Node) -> Control:
	## The drum's odds, printed under it the way the shelf printed them: what share of the
	## stones on it are of each rarity.
	var row := DeepUi.hbox(parent, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var shares: Dictionary = rarity_shares(geode)
	for rarity in RARITIES:
		var share: float = float(shares.get(rarity, 0.0))
		if share <= 0.0:
			continue
		var words: String = "%s %s" % [("Opal" if rarity == "MYTHIC" else rarity.capitalize()), percent(share)]
		DeepUi.chip(row, words, rarity_tone(rarity), 12, rarity == "MYTHIC")
	return row

# --- the strip on the drum --------------------------------------------------------------------------

func _strip() -> Array:
	## Every stone on the drum. The one it stops on is the stone the Geode held; every other is
	## drawn at the Geode's own odds, so the strip is as honest as the card: what goes by is
	## what could have come out, and nothing rare is crowded round the stopping place.
	var odds: Dictionary = DeepEconomy.geode_odds(geode)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [str(geode.get("id", "")), Time.get_ticks_usec()])
	var table: Dictionary = {}
	for entry in odds.get("skills", []):
		table[str(entry[0])] = float(entry[1])
	var opals: Array = odds.get("opals", [])
	var tiles: Array = []
	for index in range(TILES):
		if index == WIN_AT:
			tiles.append(tile_of(str(stone.get("skill", ""))))
			continue
		var skill: String = ""
		if not opals.is_empty() and rng.randf() < float(odds.get("opal", 0.0)):
			skill = str(opals[rng.randi_range(0, opals.size() - 1)])
		else:
			skill = DeepRng.weighted_key(rng, table)
		tiles.append(tile_of(skill))
	return tiles

static func tile_of(skill: String) -> Dictionary:
	var def: Dictionary = DeepContent.skill(skill)
	return {"skill": skill, "name": str(def.get("name", skill)), "rarity": str(def.get("rarity", "COMMON")), "color": str(def.get("color", "WHITE")),
		"glyph": GemIcons.emblem(skill)}

# --- what the shelf and this page say about a Geode ---------------------------------------------------

static func geode_name(shelf_geode: Dictionary) -> String:
	var theme: String = str(shelf_geode.get("theme", ""))
	match str(shelf_geode.get("kind", "mine")):
		"color":
			return "%s Geode" % str(DeepContent.color(theme).get("name", theme.capitalize()))
		"featured":
			var found: Dictionary = {}
			for entry in DeepEconomy.featured_sets():
				if str(entry.get("key", "")) == theme:
					found = entry
			return str(found.get("name", "The week's Geode"))
	return "%s Geode" % DeepContent.mine_name(theme).trim_prefix("The ")

static func geode_line(shelf_geode: Dictionary) -> String:
	## One line under a Geode's name: where its stone comes from.
	var mine: String = DeepContent.mine_name(str(shelf_geode.get("mine", ""))).trim_prefix("The ")
	match str(shelf_geode.get("kind", "mine")):
		"color":
			var color: String = str(DeepContent.color(str(shelf_geode.get("theme", ""))).get("name", ""))
			return "%s stones only, from the %s's rock" % [color, mine]
		"featured":
			for entry in DeepEconomy.featured_sets():
				if str(entry.get("key", "")) == str(shelf_geode.get("theme", "")):
					return str(entry.get("text", ""))
	return "Anything the %s's rock can hold" % mine

static func theme_tone(shelf_geode: Dictionary) -> Color:
	## The color a Geode glows: its gem color, its mine's own color, or the accent for the
	## week's set.
	match str(shelf_geode.get("kind", "mine")):
		"color":
			return DeepUi.color(str(shelf_geode.get("theme", "")))
		"featured":
			return DeepUi.ACCENT_HI
	var palette: String = str(DeepContent.mine(str(shelf_geode.get("mine", ""))).get("palette", ""))
	return Color(palette).lightened(0.15) if not palette.is_empty() else DeepUi.ACCENT

static func rarity_tone(rarity: String) -> Color:
	return StoneCard._rarity_color(rarity)

static func rarity_shares(shelf_geode: Dictionary) -> Dictionary:
	## The share of a Geode's stones of each skill rarity, opals as Mythic.
	var odds: Dictionary = DeepEconomy.geode_odds(shelf_geode)
	var out: Dictionary = {}
	for entry in odds.get("skills", []):
		var rarity: String = str(DeepContent.skill(str(entry[0])).get("rarity", "COMMON"))
		out[rarity] = float(out.get(rarity, 0.0)) + float(entry[1])
	if float(odds.get("opal", 0.0)) > 0.0:
		out["MYTHIC"] = float(out.get("MYTHIC", 0.0)) + float(odds.opal)
	return out

static func percent(share: float) -> String:
	## A share as a whole percentage, and a sliver as "under 1%" rather than a misleading 0%.
	if share <= 0.0:
		return "0%"
	if share < 0.01:
		return "<1%"
	return "%d%%" % int(round(share * 100.0))

# --- playing it out ---------------------------------------------------------------------------------

func play() -> void:
	DeepAudio.play("ui_open", {"volume": 0.6})
	_dim.modulate.a = 0.0
	_track(create_tween()).tween_property(_dim, "modulate:a", 1.0, 0.22)
	DeepUi.pop_in(_stage, 0.0, 0.9, 0.38)
	if mode == "contract":
		_phase = "fusing"
		_swirl.begin()
		DeepAudio.play("altar_hum", {"volume": 0.7})
		var beat := _track(create_tween())
		beat.tween_interval(Swirl.LIFE)
		beat.tween_callback(_fused)
		return
	_phase = "ready"
	_lever.invite(true)

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween

func _pull() -> void:
	## The lever comes down: the shell splits and the drum is off.
	if _phase != "ready":
		return
	_phase = "spinning"
	_lever.invite(false)
	_lever.haul()
	_skip.text = "Click or press Space to skip ahead"
	_subtitle.text = "The drum is turning…"
	DeepAudio.play("reel_lever", {"volume": 0.9})
	_spin_from = float(START_AT) * STRIDE + TILE.x * 0.5
	## Stopping somewhere across the stone, not always dead on its middle: the hairline can
	## come to rest near either edge, which is where the last tooth is worth watching.
	var jitter: float = randf_range(-0.36, 0.36) * TILE.x
	_spin_to = float(WIN_AT) * STRIDE + TILE.x * 0.5 + jitter
	_top_speed = (_spin_to - _spin_from) * BRAKE / SPIN
	_clock = 0.0
	_last_tooth = int(floor(_spin_from / STRIDE))
	var crack := _track(create_tween())
	crack.tween_interval(0.16)
	crack.tween_callback(_crack)

func _crack() -> void:
	## The Geode splits along its seam and the halves fall away from the window.
	if not is_instance_valid(_art):
		return
	DeepAudio.play("geode_crack", {"volume": 0.9})
	var heart: Vector2 = _art.global_position + _art.size * 0.5
	DeepUi.burst(_root, heart, _tone.lightened(0.3), 70, 480.0, 1.0, 7.0)
	DeepUi.burst(_root, heart, Color.WHITE, 26, 300.0, 0.7, 5.0)
	DeepUi.shake(_stage, 4.0, 0.3)
	_flash.color = Color(_tone.lightened(0.6), 0.3)
	var tween := _track(create_tween())
	tween.set_parallel(true)
	tween.tween_property(_flash, "color:a", 0.0, 0.32)
	tween.tween_method(func(t: float) -> void: _art.split = t, 0.0, 1.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_art, "modulate:a", 0.0, 0.55).set_delay(0.3)

func _process(delta: float) -> void:
	if _phase != "spinning" or _reel == null:
		return
	_clock += delta
	var u: float = clampf(_clock / SPIN, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - u, BRAKE)
	_reel.offset = lerpf(_spin_from, _spin_to, eased)
	var speed: float = _top_speed * pow(1.0 - u, BRAKE - 1.0)
	var share: float = clampf(speed / maxf(1.0, _top_speed), 0.0, 1.0)
	_housing.speed = share
	_glass.speed = share
	_reel.speed = share
	## A tick for every tooth past the pawl: dry and quick at speed, each one a little lower
	## and louder as the drum runs out of turn.
	var tooth: int = int(floor(_reel.offset / STRIDE))
	if tooth != _last_tooth:
		_last_tooth = tooth
		DeepAudio.play("reel_tick", {"gap": 0.0, "vary": 0.0, "pitch": 0.86 + 0.34 * share, "volume": 0.55 + 0.35 * (1.0 - share)})
	if u >= 1.0:
		_land()

func _land() -> void:
	## The pawl drops into its last tooth on the stone the Geode held.
	_phase = "landed"
	_reel.offset = _spin_to
	_housing.speed = 0.0
	_glass.speed = 0.0
	_reel.speed = 0.0
	var rarity: String = str(_reel.tiles[WIN_AT].get("rarity", "COMMON"))
	var tone: Color = rarity_tone(rarity)
	_reel.win(WIN_AT, tone)
	_housing.win(tone, rarity == "MYTHIC")
	_glass.win(tone)
	DeepAudio.play("reel_stop", {"volume": 0.9})
	var heart: Vector2 = _reel.global_position + Vector2(_reel.size.x * 0.5 - (_spin_to - (float(WIN_AT) * STRIDE + TILE.x * 0.5)), _reel.size.y * 0.5)
	var grand: bool = rarity in ["LEGENDARY", "MYTHIC"]
	var fine: bool = grand or rarity == "RARE"
	DeepUi.burst(_root, heart, tone.lightened(0.3), 90 if fine else 40, 520.0 if fine else 320.0, 1.1, 7.0)
	_rays.set("tone", tone)
	_track(create_tween()).tween_property(_rays, "modulate:a", 1.0 if fine else 0.6, 0.5)
	_subtitle.text = "%s!" % DeepUi.skill_name(stone) if fine else DeepUi.skill_name(stone)
	_subtitle.add_theme_color_override("font_color", tone.lightened(0.25))
	DeepUi.pulse(_subtitle, 1.25, 0.45)
	if fine:
		_gleam.fire(heart, tone.lightened(0.45), 120.0 if grand else 70.0)
		DeepUi.shake(_stage, 7.0 if grand else 4.0, 0.4)
		DeepAudio.play("jackpot" if grand else "stone_found", {"delay": 0.12, "volume": 0.9})
	var beat := _track(create_tween())
	beat.tween_interval(1.6 if fine else 1.05)
	beat.tween_callback(_to_reading)

func _fused() -> void:
	## The five have gone into the middle: the one they made comes out of the light.
	if _phase != "fusing":
		return
	_phase = "landed"
	var heart: Vector2 = _swirl.global_position + _swirl.size * 0.5
	DeepAudio.play("contract_seal", {"volume": 0.95})
	DeepUi.burst(_root, heart, _tone.lightened(0.3), 110, 560.0, 1.2, 8.0)
	DeepUi.burst(_root, heart, Color.WHITE, 40, 320.0, 0.9, 6.0)
	_gleam.fire(heart, _tone.lightened(0.45), 110.0)
	_flash.color = Color(1, 1, 1, 0.7)
	_track(create_tween()).tween_property(_flash, "color:a", 0.0, 0.6)
	_track(create_tween()).tween_property(_rays, "modulate:a", 1.0, 0.6)
	var beat := _track(create_tween())
	beat.tween_interval(0.55)
	beat.tween_callback(_to_reading)

func _to_reading() -> void:
	## The machine steps back and the stone is set on the lamp and read out.
	if _phase not in ["landed"]:
		return
	_phase = "reading"
	_title.text = "Out of the Geode" if mode == "geode" else "Out of the contract"
	_subtitle.text = "Here's what it is."
	_subtitle.add_theme_color_override("font_color", DeepUi.MUTED)
	if _legend != null:
		_legend.visible = false
	var out := _track(create_tween())
	out.set_parallel(true)
	out.tween_property(_stage, "modulate:a", 0.0, 0.3)
	out.tween_property(_stage, "scale", Vector2.ONE * 0.92, 0.3)
	out.chain().tween_callback(func() -> void:
		_stage.visible = false
		_reveal.visible = true
		DeepUi.pop_in(_reveal, 0.0, 0.88, 0.4)
		DeepAudio.play("gleam", {"volume": 0.7}))
	var beat := _track(create_tween())
	beat.tween_interval(0.75)
	for part in _sheet.parts():
		beat.tween_callback(_read.bind(part))
		beat.tween_interval(float(PAUSES.get(str(part).get_slice(":", 0), 0.6)))
	beat.tween_callback(_show_choices)

func _read(part: String) -> void:
	_sheet.reveal(part)
	if part == "grade":
		var tier: String = str(DeepStone.grade(stone).tier)
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if is_instance_valid(self) and _phase == "reading":
				_tint(DeepUi.tier_color(tier)))

func _tint(tone: Color) -> void:
	## The grade's color takes over the frame and the light.
	_halo.set("tone", tone)
	_rays.set("tone", tone)
	_lamp.modulate = Color(tone, _lamp.modulate.a)
	_reveal_style.border_color = Color(tone, 0.8)
	_reveal_style.shadow_color = Color(tone, 0.3)
	if _reveal.is_inside_tree() and not DeepUi.headless():
		## Placed once the container has set the panel where it goes (it may only just have
		## been shown).
		(func() -> void:
			if is_instance_valid(_reveal) and not _closing:
				DeepUi.burst(_root, _reveal.global_position + Vector2(190, _reveal.size.y * 0.5), tone, 50, 380.0, 1.0, 6.0)).call_deferred()

func _show_choices() -> void:
	_phase = "done"
	_skip.visible = false
	_choices.visible = true
	if new_skill:
		## Never found before: announced as what it is, a new place lit in the vault.
		_title.text = "A new skill!"
		_title.add_theme_color_override("font_color", DeepUi.ACCENT_HI)
		_subtitle.text = "The first %s you have found. A first stone is never sold." % DeepUi.skill_name(stone)
		DeepUi.pulse(_title, 1.3, 0.6)
		DeepAudio.play("unlock", {"volume": 0.9})
		if _root.is_inside_tree() and not DeepUi.headless():
			DeepUi.burst(_root, _title.global_position + _title.size * 0.5, DeepUi.ACCENT, 50, 300.0, 1.0, 6.0)
	elif not wanted.is_empty():
		_subtitle.text = wanted
		_subtitle.add_theme_color_override("font_color", DeepUi.GOOD)
	else:
		_subtitle.text = "It waits on the tray."
	DeepUi.stagger(_choices.get_children(), 0.0, 0.08, 0.85)

func finish() -> void:
	## Straight to the end: the drum stopped, the stone read, the choices up.
	if _phase == "done":
		return
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_dim.modulate.a = 1.0
	_flash.color.a = 0.0
	if _art != null:
		_art.split = 1.0
		_art.modulate.a = 0.0
	if _reel != null:
		_reel.speed = 0.0
		_reel.offset = float(WIN_AT) * STRIDE + TILE.x * 0.5
		_reel.win(WIN_AT, rarity_tone(str(_reel.tiles[WIN_AT].get("rarity", "COMMON"))))
	if _swirl != null:
		_swirl.settle()
	if _phase in ["ready", "spinning", "fusing"] and not DeepUi.headless() and is_inside_tree():
		## Skipped before the stop: the moment still gets its sound.
		DeepAudio.play("reel_stop" if mode == "geode" else "contract_seal", {"volume": 0.8})
		DeepAudio.reveal_stone(stone)
	_stage.visible = false
	_stage.modulate.a = 1.0
	_stage.scale = Vector2.ONE
	if _legend != null:
		_legend.visible = false
	_reveal.visible = true
	_reveal.modulate.a = 1.0
	_reveal.scale = Vector2.ONE
	_title.text = "Out of the Geode" if mode == "geode" else "Out of the contract"
	_subtitle.add_theme_color_override("font_color", DeepUi.MUTED)
	_rays.modulate.a = 1.0
	_sheet.show_all()
	_tint(DeepUi.tier_color(str(DeepStone.grade(stone).tier)))
	_show_choices()

func close() -> void:
	if not is_instance_valid(self) or is_queued_for_deletion() or _closing:
		return
	_closing = true
	_phase = "done"
	var tween := create_tween()
	tween.set_parallel(true)
	for child in _root.get_children():
		if child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)
	if _open == self:
		_open = null

func _input(event: InputEvent) -> void:
	## Space or a click pulls the lever, then skips the spin and the reading; once it is all
	## read, only Escape means anything, and it takes the gentlest way out.
	if not is_instance_valid(_root) or is_queued_for_deletion() or _closing:
		return
	var press: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if _phase == "done":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		finish()
		get_viewport().set_input_as_handled()
		return
	if not press:
		return
	if _phase == "ready":
		_pull()
	elif _phase == "spinning":
		## Skipping the spin: the drum is let go on its last turn rather than cut, so the stop
		## still plays, just sooner.
		_clock = maxf(_clock, SPIN - 0.45)
	else:
		finish()
	get_viewport().set_input_as_handled()

func _dismiss() -> void:
	for action in actions:
		if bool(action.get("dismiss", false)):
			close()
			var run: Callable = action.get("call", Callable())
			if run.is_valid():
				run.call()
			return
	close()

# --- the machine --------------------------------------------------------------------------------

class Housing extends Control:
	## The drum's brass-bound case: an iron body with rivets, a plaque with the Geode's name,
	## the window the drum shows through, and a ring of lamps that chase while it turns and
	## flash the rarity of the stone it stops on.
	var tone: Color
	var label: String
	var speed: float = 0.0
	var _clock: float = 0.0
	var _chase: float = 0.0
	var _win: float = 0.0
	var _win_tone: Color = Color.WHITE
	var _rainbow: bool = false
	var _bulbs: Array = []

	func _init(color: Color, name: String) -> void:
		tone = color
		label = name.to_upper()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inset: Rect2 = BODY.grow(-18)
		var step: float = 38.0
		var count: int = int(inset.size.x / step)
		for i in range(count + 1):
			_bulbs.append(Vector2(inset.position.x + inset.size.x * float(i) / float(count), inset.position.y))
		var rows: int = int(inset.size.y / step)
		for i in range(1, rows + 1):
			_bulbs.append(Vector2(inset.end.x, inset.position.y + inset.size.y * float(i) / float(rows)))
		for i in range(count - 1, -1, -1):
			_bulbs.append(Vector2(inset.position.x + inset.size.x * float(i) / float(count), inset.end.y))
		for i in range(rows - 1, 0, -1):
			_bulbs.append(Vector2(inset.position.x, inset.position.y + inset.size.y * float(i) / float(rows)))

	func win(color: Color, rainbow: bool) -> void:
		_win = 1.0
		_win_tone = color
		_rainbow = rainbow

	func _process(delta: float) -> void:
		_clock += delta
		_chase += delta * (1.2 + speed * 26.0)
		if _win > 0.0:
			_win = maxf(0.0, _win - delta * 0.12)
		queue_redraw()

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		## Light from the machine pooled on the bench under it.
		var pool := Vector2(BODY.size.x * 1.1, 140)
		draw_texture_rect(glow, Rect2(Vector2(BODY.get_center().x, BODY.end.y) - pool * 0.5, pool), false, Color(tone, 0.16))
		## The body: dark iron, lit along its top edge, heavier along the bottom.
		var body := StyleBoxFlat.new()
		body.bg_color = Color("161b26")
		body.border_color = Color("5a4a30")
		body.set_border_width_all(3)
		body.border_width_bottom = 6
		body.set_corner_radius_all(26)
		body.shadow_color = Color(0, 0, 0, 0.6)
		body.shadow_size = 24
		body.shadow_offset = Vector2(0, 10)
		body.anti_aliasing = true
		draw_style_box(body, BODY)
		var rim := StyleBoxFlat.new()
		rim.bg_color = Color(0, 0, 0, 0)
		rim.border_color = Color("b8a47a", 0.55)
		rim.set_border_width_all(1)
		rim.set_corner_radius_all(22)
		rim.anti_aliasing = true
		draw_style_box(rim, BODY.grow(-5))
		## The window's recess, a shade darker, with a brass bezel.
		var recess := StyleBoxFlat.new()
		recess.bg_color = Color("06080c")
		recess.border_color = Color("8a7448")
		recess.set_border_width_all(4)
		recess.set_corner_radius_all(14)
		recess.anti_aliasing = true
		draw_style_box(recess, WINDOW.grow(8))
		## Rivets in the corners and along the plaque.
		for corner in [BODY.position + Vector2(20, 20), Vector2(BODY.end.x - 20, BODY.position.y + 20), Vector2(BODY.position.x + 20, BODY.end.y - 20), BODY.end - Vector2(20, 20)]:
			draw_circle(corner, 5.0, Color("8a7448"))
			draw_circle(corner + Vector2(-1.2, -1.2), 2.0, Color("e6d4a8", 0.7))
		## The plaque: the Geode's name, engraved.
		var plaque := Rect2(Vector2(BODY.get_center().x - 190, BODY.position.y + 14), Vector2(380, 40))
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("2a2216")
		plate.border_color = Color("b8a47a", 0.8)
		plate.set_border_width_all(2)
		plate.set_corner_radius_all(8)
		plate.anti_aliasing = true
		draw_style_box(plate, plaque)
		var font: Font = DeepUi.display_font()
		var size_px: int = 18
		var measured: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var at := Vector2(plaque.get_center().x - measured * 0.5, plaque.get_center().y + font.get_ascent(size_px) * 0.36)
		draw_string(font, at + Vector2(0, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.6))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("e6d4a8"))
		## The lamps: a slow glimmer at rest, a run of light chasing round while the drum turns,
		## and every lamp blinking the stone's rarity when it stops.
		var count: int = _bulbs.size()
		for i in range(count):
			var place: Vector2 = _bulbs[i]
			if plaque.grow(10).has_point(place):
				continue
			var lit: float = 0.0
			if _win > 0.0:
				lit = (0.55 + 0.45 * sin(_clock * 14.0 + float(i % 2) * PI)) * clampf(_win * 3.0, 0.0, 1.0)
			else:
				var run: float = fposmod(_chase - float(i) * 0.5, float(count) * 0.25)
				lit = clampf(1.0 - run / 3.0, 0.0, 1.0) * clampf(speed * 4.0, 0.0, 1.0)
				lit = maxf(lit, 0.22 + 0.18 * sin(_clock * 1.6 + float(i) * 0.7))
			var color: Color = tone
			if _win > 0.0:
				color = DeepUi.rainbow_at(fposmod(float(i) / float(count) + _clock * 0.2, 1.0), 0.6) if _rainbow else _win_tone
			var halo: float = 26.0 * (0.5 + lit)
			draw_texture_rect(glow, Rect2(place - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(color, 0.45 * lit))
			draw_circle(place, 4.6, Color("3a3020"))
			draw_circle(place, 3.4, color.lerp(Color(0.25, 0.22, 0.18), 1.0 - lit))
			draw_circle(place + Vector2(-1.0, -1.0), 1.2, Color(1, 1, 1, 0.5 * lit))

class Reel extends Control:
	## The strip on the drum: stones in a row, each shown by its skill's mark on a tile washed
	## in its rarity's color, sliding past the window. Drawn by hand, a tile at a time, only
	## where the window can see.
	var tiles: Array = []
	## How far along the strip the window's middle is, and how fast it is going (0 to 1).
	var offset: float = 0.0
	var speed: float = 0.0
	var _winner: int = -1
	var _win_tone: Color = Color.WHITE
	var _win_age: float = 99.0
	var _clock: float = 0.0
	static var _wash: GradientTexture2D = null
	static var _shade: GradientTexture2D = null

	func _init(strip: Array) -> void:
		tiles = strip
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func win(index: int, color: Color) -> void:
		_winner = index
		_win_tone = color
		_win_age = 0.0

	func _process(delta: float) -> void:
		_clock += delta
		_win_age += delta
		queue_redraw()

	static func wash() -> GradientTexture2D:
		## A tile's color rising from its foot: clear at the top, the rarity at the bottom.
		if _wash == null:
			var gradient := Gradient.new()
			gradient.set_color(0, Color(1, 1, 1, 0.0))
			gradient.set_color(1, Color(1, 1, 1, 1.0))
			gradient.add_point(0.55, Color(1, 1, 1, 0.18))
			_wash = GradientTexture2D.new()
			_wash.gradient = gradient
			_wash.fill_from = Vector2(0.5, 0.0)
			_wash.fill_to = Vector2(0.5, 1.0)
			_wash.width = 8
			_wash.height = 64
		return _wash

	static func shade() -> GradientTexture2D:
		## The dark the strip comes out of and goes back into, at either end of the window.
		if _shade == null:
			var gradient := Gradient.new()
			gradient.set_color(0, Color(0.024, 0.031, 0.047, 1.0))
			gradient.set_color(1, Color(0.024, 0.031, 0.047, 0.0))
			_shade = GradientTexture2D.new()
			_shade.gradient = gradient
			_shade.fill_from = Vector2(0.0, 0.5)
			_shade.fill_to = Vector2(1.0, 0.5)
			_shade.width = 64
			_shade.height = 8
		return _shade

	func _draw() -> void:
		var middle: float = size.x * 0.5
		var first: int = maxi(0, int(floor((offset - middle) / STRIDE)) - 1)
		var last: int = mini(tiles.size() - 1, int(ceil((offset + middle) / STRIDE)) + 1)
		for index in range(first, last + 1):
			var centre_x: float = float(index) * STRIDE + TILE.x * 0.5 - offset + middle
			## The stone under the hairline swells a touch, as if under the loupe.
			var near: float = clampf(1.0 - absf(centre_x - middle) / STRIDE, 0.0, 1.0)
			var grow: float = 1.0 + 0.06 * near
			var won: bool = index == _winner
			if won:
				grow += 0.1 * (1.0 - clampf(_win_age / 0.35, 0.0, 1.0)) + 0.05
			var box := Rect2(Vector2(centre_x, size.y * 0.5) - TILE * grow * 0.5, TILE * grow)
			_tile(tiles[index], box, won, near)
		var dark: Texture2D = shade()
		draw_texture_rect(dark, Rect2(Vector2.ZERO, Vector2(size.x * 0.2, size.y)), false)
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(dark, Rect2(Vector2.ZERO, Vector2(size.x * 0.2, size.y)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _tile(tile: Dictionary, box: Rect2, won: bool, near: float) -> void:
		var rarity: String = str(tile.get("rarity", "COMMON"))
		var mythic: bool = rarity == "MYTHIC"
		var tone: Color = DeepUi.rainbow_at(fposmod(_clock * 0.25, 1.0), 0.55) if mythic else StoneCard._rarity_color(rarity)
		var gem: Color = DeepUi.color(str(tile.get("color", "WHITE")))
		var glow: Texture2D = DeepUi.glow_texture()
		if won:
			var pulse: float = 0.75 + 0.25 * sin(_win_age * 6.0)
			var halo: Vector2 = box.size * 1.9
			draw_texture_rect(glow, Rect2(box.get_center() - halo * 0.5, halo), false, Color(_win_tone, 0.55 * pulse))
		var face := StyleBoxFlat.new()
		face.bg_color = Color("141924").lerp(Color("1c2331"), near)
		face.border_color = tone.lerp(Color.WHITE, 0.35) if won else Color(tone, 0.55 + 0.3 * near)
		face.set_border_width_all(3 if won else 2)
		face.set_corner_radius_all(12)
		face.anti_aliasing = true
		draw_style_box(face, box)
		draw_texture_rect(wash(), box.grow(-3), false, Color(tone, 0.5))
		## The skill's mark, in its gem color, over a soft light of the same.
		var mark: float = box.size.x * 0.56
		var heart := Vector2(box.get_center().x, box.position.y + box.size.y * 0.4)
		var light: float = mark * 1.7
		draw_texture_rect(glow, Rect2(heart - Vector2(light, light) * 0.5, Vector2(light, light)), false, Color(gem, 0.28 + 0.2 * near))
		var glyph: Texture2D = GemIcons.texture(str(tile.get("glyph", "gem")), GemIcons.baked_size(mark), mythic)
		var ink: Color = Color.WHITE if mythic else gem.lightened(0.15)
		## At speed the mark smears along the way the drum is turning.
		if speed > 0.08:
			for step in [1.0, 2.0, 3.0]:
				var back := Vector2(step * 9.0 * speed, 0)
				draw_texture_rect(glyph, Rect2(heart - Vector2(mark, mark) * 0.5 + back, Vector2(mark, mark)), false, Color(ink, 0.22 * speed * (1.0 - step / 4.0)))
		draw_texture_rect(glyph, Rect2(heart - Vector2(mark, mark) * 0.5, Vector2(mark, mark)), false, ink)
		## The name, and the rarity along the foot.
		var font: Font = DeepUi.bold_font()
		var size_px: int = 13
		draw_string(font, Vector2(box.position.x + 6, box.end.y - 22), str(tile.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 12, size_px, DeepUi.PAPER if near > 0.5 or won else DeepUi.PAPER.darkened(0.15))
		var foot := Rect2(Vector2(box.position.x + 3, box.end.y - 9), Vector2(box.size.x - 6, 6))
		var band := StyleBoxFlat.new()
		band.bg_color = tone
		band.set_corner_radius_all(3)
		band.anti_aliasing = true
		draw_style_box(band, foot)

class Glass extends Control:
	## The loupe's hairline over the middle of the window, its brass pointers above and below,
	## and the sheen of the glass the drum turns behind.
	var tone: Color
	var speed: float = 0.0
	var _clock: float = 0.0
	var _win: float = 0.0
	var _win_tone: Color = Color.WHITE

	func _init(color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func win(color: Color) -> void:
		_win = 1.0
		_win_tone = color

	func _process(delta: float) -> void:
		_clock += delta
		if _win > 0.0:
			_win = maxf(0.0, _win - delta * 0.5)
		queue_redraw()

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var middle: float = size.x * 0.5
		var hue: Color = tone.lerp(_win_tone, clampf(_win * 2.0, 0.0, 1.0))
		## The hairline, brighter while the drum turns and flaring when it stops.
		var strength: float = 0.55 + 0.35 * speed + 0.6 * _win
		var beam := Vector2(26, size.y + 40)
		draw_texture_rect(glow, Rect2(Vector2(middle, size.y * 0.5) - beam * 0.5, beam), false, Color(hue, 0.35 * strength))
		draw_line(Vector2(middle, 6), Vector2(middle, size.y - 6), Color(hue.lightened(0.5), 0.75 * strength), 2.0, true)
		## The pointers, brass, above and below.
		for down in [true, false]:
			var y: float = -4.0 if down else size.y + 4.0
			var tip: float = 18.0 if down else size.y - 18.0
			var points := PackedVector2Array([Vector2(middle - 15, y), Vector2(middle + 15, y), Vector2(middle, tip)])
			draw_colored_polygon(points, Color("c9b07a"))
			draw_polyline(PackedVector2Array([points[0], points[2], points[1]]), Color("5a4a30"), 2.0, true)
		## Glass: a soft band of reflected light sweeping slowly across.
		var sweep: float = fposmod(_clock * 0.07, 1.4) - 0.2
		var sheen := PackedVector2Array([Vector2(size.x * sweep, 0), Vector2(size.x * sweep + 60, 0), Vector2(size.x * sweep - 20, size.y), Vector2(size.x * sweep - 80, size.y)])
		draw_colored_polygon(sheen, Color(1, 1, 1, 0.035))
		draw_line(Vector2(0, 2), Vector2(size.x, 2), Color(1, 1, 1, 0.08), 2.0)

class Lever extends Control:
	## The handle at the machine's side: a brass arm with a knob in the Geode's color. It
	## breathes while it waits to be pulled, answers the pointer, and comes down when pulled.
	signal pulled
	var tone: Color
	var _angle: float = -1.2
	var _target: float = -1.2
	var _invite: bool = false
	var _hover: bool = false
	var _clock: float = 0.0
	const UP: float = -1.2
	const DOWN: float = 0.95
	const KNOB: float = 25.0

	func _init(color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Pull the lever"
		mouse_entered.connect(func() -> void:
			_hover = true
			if _invite:
				DeepAudio.play("ui_hover", {"volume": 0.5}))
		mouse_exited.connect(func() -> void: _hover = false)

	func invite(on: bool) -> void:
		_invite = on

	func haul() -> void:
		## Down, and back up on its spring.
		_target = DOWN
		var spring := create_tween()
		spring.tween_interval(0.45)
		spring.tween_callback(func() -> void: _target = UP)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _invite:
			accept_event()
			pulled.emit()

	func _process(delta: float) -> void:
		_clock += delta
		var rate: float = 22.0 if _target == DOWN else 5.0
		_angle = lerpf(_angle, _target, clampf(delta * rate, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var pivot := Vector2(34, size.y * 0.5)
		## The mount: a brass block bolted to the case.
		var mount := Rect2(Vector2(0, pivot.y - 46), Vector2(58, 92))
		var block := StyleBoxFlat.new()
		block.bg_color = Color("2e2618")
		block.border_color = Color("b8a47a", 0.85)
		block.set_border_width_all(2)
		block.set_corner_radius_all(12)
		block.shadow_color = Color(0, 0, 0, 0.5)
		block.shadow_size = 10
		block.anti_aliasing = true
		draw_style_box(block, mount)
		for bolt in [mount.position + Vector2(14, 14), Vector2(mount.position.x + 14, mount.end.y - 14)]:
			draw_circle(bolt, 4.0, Color("8a7448"))
			draw_circle(bolt + Vector2(-1, -1), 1.6, Color("e6d4a8", 0.7))
		## The arm, swinging about its pivot from up to down: a brass rod, thick at the hub.
		var length: float = size.y * 0.42
		var along: Vector2 = Vector2.from_angle(_angle)
		var tip: Vector2 = pivot + along * length
		var across: Vector2 = along.orthogonal()
		draw_colored_polygon(PackedVector2Array([pivot + across * 9.0, tip + across * 6.5, tip - across * 6.5, pivot - across * 9.0]), Color("4a3c24"))
		draw_colored_polygon(PackedVector2Array([pivot + across * 7.0, tip + across * 4.5, tip - across * 4.5, pivot - across * 7.0]), Color("a88f5c"))
		draw_line(pivot + across * 4.0, tip + across * 2.5, Color("f0e2bc", 0.7), 2.0, true)
		draw_circle(pivot, 17.0, Color("4a3c24"))
		draw_circle(pivot, 14.0, Color("8a7448"))
		draw_circle(pivot, 6.5, Color("d9c28e"))
		draw_circle(pivot + Vector2(-2, -2), 2.4, Color(1, 1, 1, 0.6))
		## The knob, breathing while it waits and brighter under the pointer.
		var breath: float = 0.5 + 0.5 * sin(_clock * 3.2) if _invite else 0.0
		var lit: float = 0.35 + 0.45 * breath + (0.35 if _hover and _invite else 0.0)
		var halo: float = 92.0 + 34.0 * breath
		draw_texture_rect(glow, Rect2(tip - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(tone, 0.5 * lit))
		draw_circle(tip + Vector2(0, 4), KNOB, Color(0, 0, 0, 0.35))
		draw_circle(tip, KNOB, tone.darkened(0.55))
		draw_circle(tip + Vector2(-1.5, -1.5), KNOB - 3.0, tone.lerp(Color.WHITE, 0.08 * lit))
		draw_circle(tip + Vector2(-4, -4), KNOB * 0.6, tone.lightened(0.18 + 0.12 * lit))
		draw_circle(tip + Vector2(-8, -9), KNOB * 0.26, Color(1, 1, 1, 0.65))
		if not _invite:
			return
		## Which way it goes: the word over the knob, and an arrow down the arc it will travel.
		var hue := Color(tone.lightened(0.4), 0.55 + 0.45 * breath)
		var font: Font = DeepUi.display_font()
		var word: String = "PULL"
		var size_px: int = 16
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, Vector2(tip.x - width * 0.5, tip.y - KNOB - 12), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, hue)
		var reach: float = length + KNOB + 14.0
		var from: float = _angle + 0.32
		var to: float = _angle + 0.95 + 0.06 * sin(_clock * 3.2)
		draw_arc(pivot, reach, from, to, 18, Color(hue, hue.a * 0.8), 3.0, true)
		var end: Vector2 = pivot + Vector2.from_angle(to) * reach
		var ahead: Vector2 = Vector2.from_angle(to).orthogonal() * -1.0
		var side: Vector2 = ahead.orthogonal()
		draw_colored_polygon(PackedVector2Array([end + ahead * 11.0, end + side * 7.0, end - side * 7.0]), hue)

class Art extends Control:
	## A Geode on the bench, cut low-poly like the stones themselves: a rough egg of rock in lit
	## and shadowed facets, with a seam of light down its middle and crystal tips catching in
	## it. `split` from 0 to 1 cracks it, the halves falling away to either side with light
	## pouring from between them. `open` lays the two halves face up, the way the shelf shows
	## one that has been bought: a rind of rock round a faceted bowl of crystal, empty.
	## `hover` brightens the seam.
	var tone: Color
	var split: float = 0.0:
		set(value):
			split = value
			queue_redraw()
	var open: bool = false
	var hover: float = 0.0
	var _clock: float = 0.0
	var _rock: PackedVector2Array = PackedVector2Array()
	var _seam: PackedVector2Array = PackedVector2Array()
	var _shades: PackedFloat32Array = PackedFloat32Array()
	var _tips: Array = []
	var _glints: Array = []
	## The rock's facets, each [triangle, shade]; the same cut in two along the seam, by side;
	## and the triangles of the crystal bowl inside, in the rock's own units.
	var _facets: Array = []
	var _pieces: Dictionary = {}
	var _bowl: Array = []
	## The rock's outline has this many points. Every other one has a partner on a ring inside
	## it, and the facets run from the outline to the ring and from the ring in to the hub.
	const POINTS: int = 26
	const HUB := Vector2(-0.04, -0.06)
	## How much of a half's face the hollow takes, inside the rind.
	const HOLLOW: float = 0.7
	## The largest the rock is drawn, however much room it is given.
	const MOST: float = 320.0
	## The light, from the upper left and in front, and the rock's darkest and lightest faces.
	const LIGHT := Vector3(-0.42, -0.62, 0.66)
	const DARK := Color("1d1a17")
	const LIT := Color("9a8b75")

	func _init(shelf_geode: Dictionary, color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(shelf_geode.get("id", "")) + str(shelf_geode.get("theme", "")))
		for i in range(POINTS):
			var angle: float = TAU * float(i) / float(POINTS) - PI * 0.5
			var wobble: float = 1.0 + rng.randf_range(-0.08, 0.06)
			_rock.append(Vector2(cos(angle) * 0.47 * wobble, sin(angle) * 0.41 * wobble))
		for i in range(64):
			_shades.append(rng.randf_range(0.86, 1.1))
		var ring := PackedVector2Array()
		for i in range(0, POINTS, 2):
			ring.append(HUB + (_rock[i] - HUB) * rng.randf_range(0.56, 0.66))
		for j in range(ring.size()):
			for corners in _band(HUB, ring, j, 1.0):
				_facets.append([corners, _facet(corners, _facets.size(), 1.0)])
		## The bowl: the same pattern again inside the rind, round a heart a little off true.
		var heart := Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
		var inner := PackedVector2Array()
		for i in range(0, POINTS, 2):
			inner.append(heart + (_rock[i] * HOLLOW - heart) * rng.randf_range(0.42, 0.6))
		for j in range(inner.size()):
			_bowl.append_array(_band(heart, inner, j, HOLLOW))
		## The seam runs top to bottom a little off true, and stops short of the rind.
		var steps: int = 9
		for i in range(steps):
			var y: float = lerpf(-0.36, 0.36, float(i) / float(steps - 1))
			_seam.append(Vector2((0.028 if i % 2 == 0 else -0.028) + rng.randf_range(-0.01, 0.01) + y * 0.05, y))
		for i in range(1, steps - 1):
			_tips.append([i, rng.randf_range(0.025, 0.05), 1.0 if i % 2 == 0 else -1.0])
		for i in range(7):
			_glints.append([Vector2(rng.randf_range(-0.75, 0.75), rng.randf_range(-0.65, 0.65)), rng.randf_range(0.0, TAU)])

	func _band(hub: Vector2, ring: PackedVector2Array, j: int, shrink: float) -> Array:
		## The four triangles one step round the ring makes: one in to the hub, three out to
		## the outline (scaled, for the bowl inside the rind).
		var a: Vector2 = ring[j]
		var b: Vector2 = ring[(j + 1) % ring.size()]
		var o0: Vector2 = _rock[j * 2] * shrink
		var o1: Vector2 = _rock[j * 2 + 1] * shrink
		var o2: Vector2 = _rock[(j * 2 + 2) % POINTS] * shrink
		return [PackedVector2Array([hub, a, b]), PackedVector2Array([a, o0, o1]), PackedVector2Array([a, o1, b]), PackedVector2Array([b, o1, o2])]

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _height(p: Vector2) -> float:
		## How far the rock stands out of the page at a point: a low dome over its outline.
		var nx: float = p.x / 0.47
		var ny: float = p.y / 0.41
		return sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny)) * 0.36

	func _facet(corners: PackedVector2Array, index: int, rise: float) -> float:
		## How much light a facet catches: each triangle is flat on the dome (or, with `rise`
		## below zero, in the bowl), so the rock reads as cut stone rather than a smooth blob.
		## The bowl's far wall is the one facing the light.
		var lifted: Array[Vector3] = []
		for p in corners:
			lifted.append(Vector3(p.x, p.y, _height(p if rise > 0.0 else p / HOLLOW) * rise))
		var normal: Vector3 = (lifted[1] - lifted[0]).cross(lifted[2] - lifted[0]).normalized()
		if normal.z < 0.0:
			normal = -normal
		return clampf(normal.dot(LIGHT.normalized()) * _shades[index % _shades.size()], 0.0, 1.0)

	func _shape(at: Vector2, span: float, turn: float, corners: PackedVector2Array, color: Color) -> void:
		var points := PackedVector2Array()
		for p in corners:
			points.append(at + p.rotated(turn) * span)
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, Color(color.darkened(0.3), 0.55), 1.0, true)

	func _draw() -> void:
		var span: float = minf(MOST, minf(size.x, size.y * 1.15))
		var bob: float = 0.0 if open else sin(_clock * 1.3) * 3.0 * (1.0 - split)
		var centre: Vector2 = size * 0.5 + Vector2(0, bob)
		if open:
			_faces(centre, span)
			return
		var glow: Texture2D = DeepUi.glow_texture()
		## The light the seam throws round the rock, stronger under the pointer.
		var halo: float = span * (1.3 + 0.2 * hover + 0.05 * sin(_clock * 2.0))
		draw_texture_rect(glow, Rect2(centre - Vector2(halo, halo * 0.8) * 0.5, Vector2(halo, halo * 0.8)), false, Color(tone, (0.2 + 0.2 * hover) * (1.0 - split * 0.4)))
		var floor_glow := Vector2(span * 0.95, span * 0.17)
		draw_texture_rect(glow, Rect2(centre + Vector2(0, span * 0.39) - floor_glow * 0.5, floor_glow), false, Color(0, 0, 0, 0.6 * (1.0 - split)))
		if split <= 0.001:
			_whole(centre, span)
			return
		## Cracking: light pours out of the middle and the halves fall away to either side.
		var core: float = span * (0.5 + 0.9 * split)
		draw_texture_rect(glow, Rect2(centre - Vector2(core, core) * 0.5, Vector2(core, core)), false, Color(tone.lightened(0.4), 0.55 * (1.0 - split * 0.6)))
		for side in [-1.0, 1.0]:
			var turn: float = side * 0.45 * split
			var shift := Vector2(side * span * 0.95 * split, span * 0.22 * split * split)
			_falling(side, centre + shift, span, turn)

	func _whole(centre: Vector2, span: float) -> void:
		for facet in _facets:
			_shape(centre, span, 0.0, facet[0], DARK.lerp(LIT, float(facet[1])))
		var outline := PackedVector2Array()
		for p in _rock:
			outline.append(centre + p * span)
		outline.append(outline[0])
		draw_polyline(outline, Color(0, 0, 0, 0.55), 2.0, true)
		## The lit rim along the upper left.
		var rim := PackedVector2Array()
		for p in _rock:
			if p.y < -0.05 and p.x < 0.25:
				rim.append(centre + p * span * 0.985)
		if rim.size() > 1:
			draw_polyline(rim, Color(1, 1, 1, 0.16), 2.0, true)
		## The seam: light leaking out of the crack, crystal tips catching in it.
		var seam := PackedVector2Array()
		for p in _seam:
			seam.append(centre + p * span)
		var flicker: float = minf(1.0, 0.78 + 0.22 * sin(_clock * 5.3) * sin(_clock * 2.1 + 1.0) + 0.35 * hover)
		var glow: Texture2D = DeepUi.glow_texture()
		for p in seam:
			var spot: float = span * (0.15 + 0.05 * hover)
			draw_texture_rect(glow, Rect2(p - Vector2(spot, spot) * 0.5, Vector2(spot, spot)), false, Color(tone, 0.2 * flicker))
		draw_polyline(seam, Color(tone.darkened(0.25), 0.9), 5.0, true)
		draw_polyline(seam, Color(tone.lightened(0.35), 0.9 * flicker), 2.6, true)
		draw_polyline(seam, Color(1, 1, 1, 0.75 * flicker), 1.0, true)
		for tip in _tips:
			var at: Vector2 = seam[int(tip[0])]
			var reach: float = float(tip[1]) * span
			var point := at + Vector2(float(tip[2]) * reach, -reach * 0.35)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -reach * 0.3), point, at + Vector2(0, reach * 0.3)]), tone.lightened(0.15))
			draw_line(at, point, Color(1, 1, 1, 0.5), 1.0, true)
		## Now and then a glint runs up the seam.
		var run: float = fposmod(_clock * 0.45, 1.6)
		if run < 1.0:
			var at: Vector2 = seam[seam.size() - 1].lerp(seam[0], run)
			var star: float = span * 0.09
			draw_texture_rect(glow, Rect2(at - Vector2(star, star) * 0.5, Vector2(star, star)), false, Color(1, 1, 1, 0.85 * sin(run * PI)))

	func _cut(side: float) -> PackedVector2Array:
		## Everything on one side of the seam (carried on straight up and down through the
		## rind, where the seam itself stops short).
		var cut := PackedVector2Array()
		cut.append(Vector2(_seam[0].x, -1.0))
		cut.append_array(_seam)
		cut.append(Vector2(_seam[_seam.size() - 1].x, 1.0))
		cut.append(Vector2(2.0 * side, 1.0))
		cut.append(Vector2(2.0 * side, -1.0))
		return cut

	func _half(side: float) -> Dictionary:
		## One half of the rock: its facets cut along the seam, each keeping its shade, and its
		## outline. Worked out the first time the rock cracks.
		if not _pieces.has(side):
			var cut: PackedVector2Array = _cut(side)
			var pieces: Array = []
			for facet in _facets:
				for piece in Geometry2D.intersect_polygons(facet[0], cut):
					pieces.append([piece, facet[1]])
			var outline := PackedVector2Array()
			for shape in Geometry2D.intersect_polygons(_rock, cut):
				if shape.size() > outline.size():
					outline = shape
			_pieces[side] = {"pieces": pieces, "outline": outline}
		return _pieces[side]

	func _falling(side: float, at: Vector2, span: float, turn: float) -> void:
		## A half on its way down: its own facets, and its broken face, edge on, crusted with
		## crystal and lit by the hollow it opened.
		var half: Dictionary = _half(side)
		for piece in half.pieces:
			_shape(at, span, turn, piece[0], DARK.lerp(LIT, float(piece[1])))
		var outline := PackedVector2Array()
		for p in half.outline:
			outline.append(at + p.rotated(turn) * span)
		if outline.size() > 2:
			outline.append(outline[0])
			draw_polyline(outline, Color(0, 0, 0, 0.55), 2.0, true)
		var cut := PackedVector2Array()
		for p in _seam:
			cut.append(at + p.rotated(turn) * span)
		var glow: Texture2D = DeepUi.glow_texture()
		for p in cut:
			var spot: float = span * 0.14
			draw_texture_rect(glow, Rect2(p - Vector2(spot, spot) * 0.5, Vector2(spot, spot)), false, Color(tone, 0.3))
		var facing := Vector2(-side, 0).rotated(turn)
		for i in range(cut.size() - 1):
			var base: Vector2 = (cut[i] + cut[i + 1]) * 0.5
			var tip: Vector2 = base + facing * span * (0.03 + 0.015 * float(i % 3))
			draw_colored_polygon(PackedVector2Array([cut[i], tip, base]), tone.lerp(Color.WHITE, 0.3))
			draw_colored_polygon(PackedVector2Array([base, tip, cut[i + 1]]), tone.darkened(0.2))
		draw_polyline(cut, Color(tone.lightened(0.5), 0.9), 2.0, true)

	func _faces(centre: Vector2, span: float) -> void:
		## Bought and cracked: the two halves lie face up side by side, mirror images, each a
		## rind of rock round a bowl of crystal facets, the stone it held gone from the middle.
		var glow: Texture2D = DeepUi.glow_texture()
		var floor_glow := Vector2(span * 1.05, span * 0.16)
		draw_texture_rect(glow, Rect2(centre + Vector2(0, span * 0.27) - floor_glow * 0.5, floor_glow), false, Color(0, 0, 0, 0.55))
		var reach: float = span * 0.5
		for side in [-1.0, 1.0]:
			var at: Vector2 = centre + Vector2(side * span * 0.27, 0)
			var turn: float = side * 0.08
			var rind := PackedVector2Array()
			var hollow := PackedVector2Array()
			for p in _rock:
				var q: Vector2 = Vector2(p.x * side, p.y).rotated(turn) * reach
				rind.append(at + q)
				hollow.append(at + q * HOLLOW)
			var count: int = rind.size()
			## The rind: the shell's broken face, flat, a little lighter toward the light.
			for i in range(count):
				var j: int = (i + 1) % count
				var facing: Vector2 = ((rind[i] + rind[j]) * 0.5 - at).normalized()
				var lit: float = clampf((0.5 - facing.dot(Vector2(0.5, 0.75)) * 0.3) * _shades[i % _shades.size()], 0.0, 1.0)
				draw_colored_polygon(PackedVector2Array([rind[i], rind[j], hollow[j], hollow[i]]), DARK.lerp(LIT, lit))
			## The bowl, each facet lit for where it faces once the half is turned this way up.
			var index: int = 0
			for corners in _bowl:
				var turned := PackedVector2Array()
				for p in corners:
					turned.append(Vector2(p.x * side, p.y))
				var lit: float = _facet(turned, index * 7, -1.0)
				_shape(at, reach, turn, turned, tone.darkened(0.62).lerp(tone.lightened(0.42), lit))
				index += 1
			var heart: float = reach * 0.75
			draw_texture_rect(glow, Rect2(at - Vector2(heart, heart) * 0.5, Vector2(heart, heart)), false, Color(tone, 0.16 + 0.06 * sin(_clock * 1.6 + side)))
			## The pale band of agate where the rock gives way to crystal.
			var band := hollow.duplicate()
			band.append(band[0])
			draw_polyline(band, Color(tone.lerp(Color.WHITE, 0.6), 0.8), maxf(2.0, span * 0.012), true)
			## Glints on the crystal, coming and going.
			for glint in _glints:
				var shine: float = clampf(sin(_clock * 1.4 + float(glint[1]) + side * 2.0), 0.0, 1.0)
				if shine <= 0.0:
					continue
				var spot: Vector2 = at + Vector2(glint[0].x * side, glint[0].y) * reach * 0.42
				var star: float = span * 0.06 * shine
				draw_texture_rect(glow, Rect2(spot - Vector2(star, star) * 0.5, Vector2(star, star)), false, Color(1, 1, 1, 0.85 * shine))
			rind.append(rind[0])
			draw_polyline(rind, Color(0, 0, 0, 0.6), 2.0, true)

class Swirl extends Control:
	## A contract sealed: the five stones set round the middle of the bench turn in toward it,
	## faster and closer, leaving light behind them, until they meet and are gone in a flash.
	const LIFE: float = 2.2
	var stones: Array = []
	var made: Dictionary = {}
	var tone: Color
	var _age: float = -1.0
	var _thumbs: Array = []

	func _init(inputs: Array, out: Dictionary, color: Color) -> void:
		stones = inputs
		made = out
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for stone in stones:
			var thumb := Thumbs.GemThumb.new(stone, 96.0)
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(thumb)
			_thumbs.append(thumb)
		_place(0.0)

	func begin() -> void:
		_age = 0.0

	func settle() -> void:
		_age = LIFE
		_place(1.0)

	func _process(delta: float) -> void:
		if _age >= 0.0 and _age < LIFE:
			_age = minf(LIFE, _age + delta)
			_place(_age / LIFE)
		queue_redraw()

	func _place(t: float) -> void:
		var centre: Vector2 = STAGE * 0.5
		var ease_in: float = t * t * t
		for index in range(_thumbs.size()):
			var thumb: Control = _thumbs[index]
			var angle: float = -PI * 0.5 + TAU * float(index) / float(maxi(1, _thumbs.size())) + ease_in * TAU * 1.6
			var reach: float = lerpf(180.0, 0.0, ease_in)
			thumb.position = centre + Vector2.from_angle(angle) * reach - Vector2(48, 48)
			thumb.scale = Vector2.ONE * lerpf(1.0, 0.35, ease_in)
			thumb.pivot_offset = Vector2(48, 48)
			thumb.modulate.a = 1.0 - smoothstep(0.85, 1.0, t)

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre: Vector2 = STAGE * 0.5
		var t: float = clampf(_age / LIFE, 0.0, 1.0) if _age >= 0.0 else 0.0
		var ease_in: float = t * t * t
		## The circle on the bench, its lines lighting up as the stones go round it.
		draw_arc(centre, 200.0, 0.0, TAU, 96, Color(tone, 0.18 + 0.4 * t), 2.0, true)
		draw_arc(centre, 160.0, 0.0, TAU, 96, Color(tone, 0.1 + 0.3 * t), 1.5, true)
		## Round the circle from stone to stone, and a spoke from each in to the middle, the way
		## the bench's lines ran down to the one place.
		var count: int = maxi(1, stones.size())
		for index in range(count):
			var a: float = -PI * 0.5 + TAU * float(index) / float(count)
			var b: float = -PI * 0.5 + TAU * float((index + 1) % count) / float(count)
			draw_line(centre + Vector2.from_angle(a) * 180.0, centre + Vector2.from_angle(b) * 180.0, Color(tone, 0.08 + 0.3 * t), 1.5, true)
			draw_line(centre + Vector2.from_angle(a) * 150.0, centre + Vector2.from_angle(a) * 40.0, Color(tone, 0.06 + 0.4 * t), 2.0, true)
		## Trails behind the stones.
		for index in range(count):
			for step in range(8):
				var back: float = maxf(0.0, ease_in - float(step) * 0.035)
				var angle: float = -PI * 0.5 + TAU * float(index) / float(count) + back * TAU * 1.6
				var reach: float = lerpf(180.0, 0.0, back)
				var spot: float = 26.0 * (1.0 - float(step) / 8.0)
				draw_texture_rect(glow, Rect2(centre + Vector2.from_angle(angle) * reach - Vector2(spot, spot) * 0.5, Vector2(spot, spot)), false, Color(tone, 0.25 * t * (1.0 - float(step) / 8.0)))
		var core: float = 120.0 + 420.0 * ease_in
		draw_texture_rect(glow, Rect2(centre - Vector2(core, core) * 0.5, Vector2(core, core)), false, Color(tone.lightened(0.3), 0.15 + 0.6 * ease_in))
