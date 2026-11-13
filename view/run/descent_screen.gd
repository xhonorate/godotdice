extends Control
## The run: the shaft's tunnels, its chambers and landings, and the fight when there is one.
## Every screen here shows the run state it is given and turns clicks into commands; the
## battle screen inside it does the same for a fight.
##
## The whole run happens in the mine itself: the mine stage is always on screen, the party
## walks from room to room down real tunnels, chooses a way at the mouths in a room's far
## wall, and is sealed into a fight by a rockfall that crumbles when it is won. What is text
## by nature (a stall's goods, an oddity's choices, the stakes, a landing's respite) is a
## page over the room. Pages are rebuilt whenever the state moves (they are cheap: stones and
## dice are photographs), and only animate in when the page is new, so a vote or a strike
## never makes the whole screen jump. The chart of the stretch folds out on the left.

const BattleScreen = preload("res://view/battle/battle_screen.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const Rework = preload("res://view/gems/rework.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const MineStage = preload("res://view/run/mine_stage.gd")
const ShaftMap = preload("res://view/run/shaft_map.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const BenchPanel = preload("res://view/run/bench_panel.gd")
const RunDock = preload("res://view/run/run_dock.gd")
const DownedVeil = preload("res://view/run/downed_veil.gd")
const HollowRite = preload("res://view/run/hollow_rite.gd")
const AskSheet = preload("res://view/run/ask_sheet.gd")
const Roster = preload("res://view/home/roster.gd")
const Plates = preload("res://view/ui/plates.gd")
const Tips = preload("res://view/ui/tips.gd")
const DieFx = preload("res://view/ui/die_fx.gd")

signal command(cmd: Dictionary)
signal home_requested
signal menu_requested

const KIND_WORDS: Dictionary = {"fight": "A fight", "elite": "Something big", "vein": "A vein", "oddity": "Something odd",
	"motherlode": "A motherlode", "merchant": "A merchant", "smithy": "A smithy", "carver": "A carver's bench", "landing": "The landing",
	"hidden": "A dark mouth", "well": "A wishing well", "vat": "A vat", "altar": "An altar", "rest_stop": "A rest stop", "warden": "The Warden's hall"}
## How many of the bag's stones the scales name at once: the chip is a panel, not a page.
const SCALES_LISTED := 10

const KIND_TEXT: Dictionary = {"fight": "Pays pyrite, with a good chance of a raw stone.",
	"elite": "An elite fight. Guaranteed stone, one grade better.",
	"vein": "A wall of glinting rock. Strike it for stones and pyrite.",
	"oddity": "Usually a gamble with your stones or dice.",
	"motherlode": "A vein with rich seams besides: stones with real luck in them, all but loose, for anyone's pick.",
	"merchant": "A stall on a ledge: stones for pyrite, appraisals, and a buyer for what you found.",
	"smithy": "An anvil and a rack of files: make one of your dice a size bigger or smaller, or stamp it with the anvil's pattern.",
	"carver": "Fine chisels and a case of needles under a lamp: raise or lower a face of a die, or etch a mark into it.",
	"landing": "A landing with a lift. Rest, appraise or use the well, then head up or keep going.",
	"warden": "The hall below the landing. Its Warden stands between the party and the way on down; beat it for a hoard of stones.",
	"well": "Throw in a stone or some pyrite. The more it's worth, the better your odds of a good reward.",
	"hidden": "Too dark to see. Anything could be down there.",
	"vat": "A sunken vat of molten material: dip a die and it comes out made of something else, or melt it back to plain numbers.",
	"altar": "An altar of old stone with a star cut into it and five sockets round the star. Give it five gems and see what it gives back.",
	"rest_stop": "A nook with a bench and a supply box: rest to heal, or take the supplies as pyrite."}
## How many things to work on stand on one line of a room's second page.
const WORK_PAGE: int = 8
## How wide the chart is where it lies over the left of the room.
const MAP_WIDTH := 400.0
## How much larger the phone draws the chart (`_map`), which draws itself in canvas pixels.
const CHART_SCALE := 1.5
## How many salvage rolls, and how many stones coming home, go on one page.
const SALVAGE_PAGE: int = 6
const HOME_PAGE: int = 14
## Said at a landing with a Warden below it, on its pill and on the cage: the hall past the
## Warden has no lift, so this one is the last until the next landing.
const LAST_LIFT: String = "The Warden's hall has no lift. This is the last lift until the next landing."
## How long the well keeps its answer to itself, and how each rung of it looks and sounds.
const WELL_SUSPENSE: float = 2.2
const WELL_TONES: Array = [Color("7d8494"), Color("7fb2ff"), Color("73d98c"), Color("ffc857"), Color("ffe08a")]
const WELL_VOICES: Array = ["gem_fizzle", "stone_found", "grade_precious", "grade_exquisite", "grade_peerless"]
## How many raw stones the acid bath lays out, and how many patterns the shrine offers.
const RACK_SHELF: int = 12
const SHRINE_OFFERS: int = 3
## What the shrine calls each family of trigger, and what it says the family asks for. The
## shrine blesses a whole family, so it never quotes one gem's line on its Cut ladder.
const SHRINE_WORDS: Dictionary = {"pair": ["Pair", "Gems that need two dice alike."], "two_pair": ["Two pair", "Gems that need two pairs."],
	"triple": ["Three of a kind", "Gems that need three dice alike."], "quad": ["Four of a kind", "Gems that need four dice alike."],
	"quint": ["Five of a kind", "Gems that need all five alike."], "full_house": ["Full house", "Gems that need three alike and a pair."],
	"straight": ["Straight", "Gems that need a run of values."], "skip_straight": ["Skip straight", "Gems that need a run of all odd or all even values."],
	"odd": ["Odd dice", "Gems that count the dice showing odd values."], "even": ["Even dice", "Gems that count the dice showing even values."],
	"all_odd": ["All odd", "Gems that need every die odd."], "all_even": ["All even", "Gems that need every die even."],
	"distinct": ["Different values", "Gems that count dice with no two alike."], "distinct_dominant": ["One above the rest", "Gems that need the top die to outroll the rest."],
	"value": ["One number", "Gems that need a die showing one exact number."], "at_most": ["A low die", "Gems that need a die at or under their line."],
	"below": ["A low die", "Gems that need a die under their line."], "at_least": ["A high die", "Gems that need your highest die at or over their line."],
	"total_pct_at_least": ["A high total", "Gems that need your dice to add up high."], "total_pct_at_most": ["A low total", "Gems that need your dice to add up low."],
	"high_pct_at_least": ["A near-top roll", "Gems that need a die near the top of its own die (a 6 on a d6, a 12 on a d12)."], "held": ["Held dice", "Gems that count the dice you kept."],
	"rerolled": ["Rerolled dice", "Gems that count the dice you rerolled."], "low_count": ["Low dice", "Gems that count dice in the low half of their die (1-3 on a d6)."],
	"crowns": ["Crowns", "Gems that count dice on their own top face."], "crowns_at_most": ["Few crowns", "Gems that want few dice on their top face."],
	"pyrite": ["Pyrite", "Gems that need pyrite in hand."], "fizzles": ["Fizzles", "Gems that pay off on gems that stayed dark."]}
const ODDITY_GLYPHS: Dictionary = DeepUi.ODDITY_GLYPHS
## The mark for one piece of work, by the action it takes. See `choice_glyph`.
const CHOICE_GLYPHS: Dictionary = {"none": "next", "reroll_cut": "cut", "reroll_clarity": "clarity", "push_clarity": "flame", "remove_inclusion": "clean_drop",
	"fuse": "flame", "geode_buy": "geode", "etch": "spark", "pattern": "die", "material": "drop", "reset": "flame", "trade_up": "scales", "shrine": "star",
	"idol": "eye", "echo_stone": "copy", "collector_sell": "coins", "collector_buy": "purse", "heal": "heart", "ore": "coins", "appraise": "loupe",
	"acid_appraise": "flask", "tumble": "reroll", "upsize": "rise", "downsize": "fall", "temper": "rise", "raise_face": "rise", "lower_face": "fall",
	"pry": "pick", "chips": "gem", "wishing_well": "gem", "hollow": "widening_spiral"}

var local_id: String = ""
var run: Dictionary = {}
var forecast_provider: Callable = Callable()
## Where this player stands on the day's seam as the run starts: {eligible, best_score,
## best_gold}, from the workshop's own record of the day (DeepEconomy.begin_daily).
var daily_best: Dictionary = {}
var _strip: HBoxContainer
var _body: Control
var _stage: Control
var _scrim: ColorRect
var _battle: BattleScreen
var _area: HBoxContainer
var _map: Control
var _map_margin: MarginContainer
var _page_holder: Control
## The way out of the page on show, in a corner of the room (`_way_out`), or null.
var _way_out_key: Button = null
## The page along the bottom of the room on show (`_bottom_page`), which the way out gives way to.
var _bottom_content: VBoxContainer = null
## The page over the room as last built (see `_page`), so it can fold to fit over an open bag.
var _page_content: VBoxContainer = null
var _crossroads: Control
var _cross_mark: CenterContainer
var _cross_title: Label
var _cross_sub: Label
## The room's line as last put into the phone's words (`_process`).
var _cross_said: String = ""
var _cross_hint: HBoxContainer
## The room's name and line (and the shade behind them), and how far they stand left of the
## middle for an open bag on the phone (`_fit_head`).
var _cross_head: Control = null
var _cross_shade: Control = null
var _head_shift: float = 0.0
## A card stands where the plinth's mark floats, on the phone: the mark is out (`_check_shrine_cover`).
var _shrine_covered: bool = false
## Whether the party was walking last frame: a way out is laid again once it stands still.
var _way_walked: bool = false
var _chip: PanelContainer
var _chip_index: int = -1
## A thing in the room under the cursor (a vein's spot, a stall's goods), shown in the chip.
var _chip_pick: String = ""
## A strike sent and not yet answered: the vein waits for the rock to answer.
var _strike_pending: bool = false
var _strike_token: int = 0
## When the last find thrown out of the rock lands (ticks msec), so the way on waits for all of them.
var _finds_until: int = 0
var _veil: Control
## The two sides of the trading table on the page now showing, for the stones to fly from.
var _trade_slots: Dictionary = {}
var _trade_pulse: bool = false
var _veil_synced: bool = false
## Who was down at the last look, by id.
var _fallen: Dictionary = {}
## A thing in the room clicked on: its chip stays up, with buttons, until something else is.
var _pinned: String = ""
## The rail, the dice and the bag, along the bottom outside a fight.
var _run_dock: Control
## The ask (ask_sheet.gd): one block in the middle of the screen for anything a room wants
## from the party's own things.
var _ask: Control
## The room whose walk-up opened the bag (an altar's), so leaving it shuts the bag again.
var _stall_opened: String = ""
## A mouth clicked at a landing: when the party's ways down are offered, the vote goes to it.
var _descend_via: int = -1
## The end of a run: the ride up (or the dark) first, then the summary.
var _end_started: bool = false
var _end_shown: bool = false
var _salvage_thrown: bool = false
## The pages of the salvage whose dice have been rolled on screen.
var _salvage_rolled: Dictionary = {}
## The page each long list on a page is turned to: the salvage, what comes home.
var _pages: Dictionary = {}
## The chart of the stretch folds out over the room when asked for.
var _chart_open: bool = false
## On the way to the next room: nothing of the room ahead is shown until the party is in it.
var _walking: bool = false
## The key of the place a walk is waiting to start for, while a coin toss is read: "" when
## none is. See `_sync_stage`.
var _walk_pending: String = ""
var _arrive_quietly: bool = false
## The ways on the party was last offered, in the order of the mouths they were shown at.
var _last_offers: Array = []
## Counts the strip keeps showing until what was won has flown up to it: {ore, haul}.
var _strip_hold: Dictionary = {}
## What the last fight paid, held up over the room until it flies to the strip (`_award_plate`).
var _award: Control = null
## A read stone a fight gave up, offered to the rail over the room (`_offer_find`), and its id.
var _find_plate: Control = null
var _find_id: String = ""
## The plate that settles a twin stone (nobody carries two of one gem): see `_sync_twin`.
var _twin_plate: Control = null
## "With whom?": the booth's question when more than one teammate is free to trade.
var _whom_plate: Control = null
var _ore_pill: Control = null
var _bag_pill: Control = null
var _view_key: String = ""
var _bench: Control
var _toasts: VBoxContainer
var _fresh: bool = true
var _headless: bool = false
var _hold: Dictionary = {}
## What Restless Rock did to the rails as the party reached a landing ({changed: {stone id:
## {from, to, unit}}}), said once the walk in is over; {} when there is nothing to say.
var _restless_news: Dictionary = {}
## The Hollow's rite while it plays over the room; no page goes up until it is done.
var _rite: HollowRite = null
## What a final boss's death opened, waiting to be shown a sheet at a time once the hoard is
## chosen: [{run_id, kind: character | tier | conquest, ...}]. See `conquered`.
var _news: Array = []
## The beaten mine's sheet while it is up, put away if the party leaves the hall under it.
var _conquest_sheet: CanvasLayer = null
## What the last beaten mine's sheet said: gone with no way out chosen (the rules refused the
## one taken), it opens again from a key under the hall's name while the party is in the hall.
var _conquest_item: Dictionary = {}
var _conquest_shown: bool = false
var _last_chamber: Dictionary = {}
var _last_battle: Dictionary = {}
var _shown_depth: int = -1
## The pick stake taken at the shaft head whose three are on show, until one is kept.
var _stake_choosing: String = ""
## A deep card's choice being made (docs/DEEP_START.md), kept while its page is redrawn: the
## Bag of Gems' stones picked (indices), the Bag of Dice's rows, a Hammered or Wild Face card's
## charges spent. `_bag_key` says which card they belong to.
var _bag_key: String = ""
var _bag_chosen: Array = []
## The Bag of Dice's two rows as they stand (dice, slot order), and the die held ({row, index}).
var _bag_hand: Array = []
var _bag_pool: Array = []
var _bag_sel: Dictionary = {}
## A Hammered or Wild Face card's charges spent so far, as the die clicked for each.
var _charge_clicks: Array = []
## An upgraded bench's reveal, by visit (`_bench_key`): "pending" while its plain work is
## shown, "done" once the better work has replaced it.
var _bench_revealed: Dictionary = {}
## The dice worked for a deeper start have been read at the shaft head.
var _counts: Dictionary = {}
## What the strip was last built from; see `_sync_strip`.
var _strip_key: String = ""
## Where the ore and bag pills were last seen on the strip, so a spoil thrown at one in the
## same frame the strip was rebuilt still flies to the right place. See `_pill_centre`.
var _pill_spots: Dictionary = {}
## What each slot of a room's card is set to, by room and choice, and which slot the tray
## over the dock is open for. See `_picker`.
var _choice_picks: Dictionary = {}
var _choice_slot: String = ""
## The room the picks above belong to: they are forgotten the moment the party leaves it.
var _choice_room: String = ""
## What the chip was last placed over, so it is placed once and then left alone.
var _chip_over: String = ""
## The piece of work picked out of a room's card, before the thing to do it to is chosen.
var _oddity_step: String = ""
## The landing thing opened up close ("wish" or "appraise"), or "" for the hall itself.
var _landing_view: String = ""
## Whom the trade page is open on, at a landing.
var _trade_with: String = ""
## The last place this player was said to be standing at a landing (see `_send_station`).
var _station_sent: String = ""
## Under the room's name at a landing: what the party is asking of this player.
var _cross_ask: HBoxContainer
var _cross_ask_key: String = ""
## The five gems set on an altar's sockets, by stone id, until the crystal is pressed; and
## whether it has been, so a second click waits on the host's answer.
var _altar_slots: Array = ["", "", "", "", ""]
var _altar_sent: bool = false
## While the circle is taking our five, the sockets are the animation's, not the page's.
var _altar_making: bool = false
## In a party, the others' choices over the room where they point: on the cage, on a mouth,
## at the trading table. Built again when what they say changes, placed every frame.
var _vote_tags: Control
var _vote_key: String = ""
## The line under a room's name while this player is done there and the party is not.
var _cross_wait: HBoxContainer
var _wait_key: String = ""
## A split vote's beat while it is up, and when it comes down (engine milliseconds).
var _toss_panel: Control = null
var _toss_until: int = 0
## Whether a close look or an appraisal stood over the room last frame: the twin plate held
## back under one comes up the frame it goes. See `_sync_twin` and `_process`.
var _was_reading: bool = false
## The "while you were away" line, said once for each time back.
var _back_told: String = ""
## Who sat at the trading table when last shown, so someone sitting down is said once.
var _at_table: Dictionary = {}
## The page's way on, which Enter presses ("Onward", "Put the pick down", "Done here"): set by
## whatever draws it (`_main`), and let go whenever the page is drawn again.
var _main_button: Button = null
## The socket a find held up over the room offers: Enter takes it before the page's way on.
var _find_main: Button = null
## The cards the number keys take on the page, left to right, as they take the mouths at a
## crossroads: {card, take} (see `_numbered_card`).
var _numbered: Array = []
## What this run moved forward for this player, for the over page's "This run" line: set by
## the app when the run comes home (see `note_progress`).
var _progress: Array = []
## The mines this run's conquests opened, as `conquered` heard them.
var _opened: Array = []

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var strip_panel := PanelContainer.new()
	var strip_style := DeepUi.flat(Color(0.035, 0.045, 0.065, 0.97), Color(0, 0, 0, 0), 0, 10)
	strip_style.border_width_bottom = 1
	strip_style.border_color = Color(DeepUi.ACCENT_DIM, 0.6)
	strip_style.content_margin_left = 20
	strip_style.content_margin_right = 20
	strip_style.shadow_color = Color(0, 0, 0, 0.5)
	strip_style.shadow_size = 8
	if DeepUi.phone:
		## The phone's strip: 34 points from edge to edge, its words clear of the corners and
		## the camera island.
		strip_style.content_margin_left = DeepUi.safe_left + DeepUi.pt(4)
		strip_style.content_margin_right = DeepUi.safe_right + DeepUi.pt(4)
		strip_style.content_margin_top = DeepUi.pt(3)
		strip_style.content_margin_bottom = DeepUi.pt(3)
		strip_style.border_width_bottom = int(DeepUi.pt(1))
	strip_panel.add_theme_stylebox_override("panel", strip_style)
	strip_panel.z_index = 5
	column.add_child(strip_panel)
	_strip = DeepUi.hbox(strip_panel, int(DeepUi.pt(10)) if DeepUi.phone else 18)
	if DeepUi.phone:
		_strip.custom_minimum_size.y = DeepUi.pt(28)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.clip_contents = true
	column.add_child(_body)
	## The mine, always on screen: every room, tunnel and fight is drawn on it.
	_stage = MineStage.new()
	_stage.mouth_hovered.connect(_hover_mouth)
	_stage.mouth_pressed.connect(_choose_mouth)
	## The phone's hold on a mouth: where it leads, in place of the desk's hover.
	_stage.mouth_held.connect(_hover_mouth)
	_stage.pick_hovered.connect(_hover_pick)
	_stage.pick_pressed.connect(_press_pick)
	_stage.pick_inspected.connect(_inspect_pick)
	_body.add_child(_stage)
	## A shade over the room behind a page, so the words stand off the rock.
	_scrim = ColorRect.new()
	_scrim.color = Color(0.01, 0.012, 0.02, 0.62)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	_body.add_child(_scrim)
	## Over the room while this player is down in a party, and under everything drawn on it:
	## the fight's dock, the tabs and every page stay in full color, so someone who is down
	## still watches the party's dice and gems as clearly as before.
	_veil = DownedVeil.new()
	_body.add_child(_veil)
	_battle = BattleScreen.new()
	_battle.stage = _stage
	_battle.spoils = true
	_battle.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	## The purse on the strip is where a Gambler's coins leave from and come home to.
	_battle.bank_anchor = func() -> Control: return _ore_pill if _ore_pill != null and is_instance_valid(_ore_pill) else null
	_battle.bank_changed.connect(_bank_changed)
	_battle.visible = false
	_body.add_child(_battle)
	_build_crossroads()
	_area = HBoxContainer.new()
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_theme_constant_override("separation", 0)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_area)
	## The chart lies over the left of the room rather than taking a column out of it: a page
	## that shuffled sideways every time the map was opened was worse than either.
	_map_margin = DeepUi.margin(_body, 18)
	_map_margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_map_margin.offset_right = MAP_WIDTH
	## Its top and foot stand where the bag column's do (`RunDock.COLUMN_TOP`, `side_foot`; the
	## owner, Nov 6, 2026): no margin over or under it, its offsets say where.
	_map_margin.offset_top = RunDock.COLUMN_TOP
	_map_margin.add_theme_constant_override("margin_right", 0)
	_map_margin.add_theme_constant_override("margin_top", 0)
	_map_margin.add_theme_constant_override("margin_bottom", 0)
	_map_margin.visible = false
	_map = ShaftMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.vote.connect(_vote)
	_map.light.connect(func() -> void: command.emit({"kind": "light"}))
	if DeepUi.phone:
		## The phone's chart: 260 points inside the safe edge, the map drawn at CHART_SCALE in a
		## holder (it draws itself in canvas pixels, which a phone's canvas halves).
		_map_margin.offset_right = DeepUi.safe_left + DeepUi.pt(260)
		_map_margin.add_theme_constant_override("margin_left", int(DeepUi.safe_left))
		var holder := Control.new()
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_margin.add_child(holder)
		holder.add_child(_map)
		## Its holder decides its size, a short screen included.
		_map.custom_minimum_size = Vector2.ZERO
		_map.scale = Vector2(CHART_SCALE, CHART_SCALE)
		holder.resized.connect(func() -> void:
			_map.position = Vector2.ZERO
			_map.size = holder.size / CHART_SCALE)
	else:
		_map_margin.add_child(_map)
	_page_holder = Control.new()
	_page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_holder.resized.connect(_place_way_out)
	_area.add_child(_page_holder)
	_run_dock = RunDock.new()
	_run_dock.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	_run_dock.drawer_toggled.connect(func(_open: bool) -> void: _fit_area())
	_run_dock.chose.connect(_on_dock_chose)
	_run_dock.trade_with.connect(_open_trade)
	_run_dock.visible = false
	_run_dock.bag_anchor = func() -> Control: return _bag_pill if _bag_pill != null and is_instance_valid(_bag_pill) else null
	_body.add_child(_run_dock)
	## The ask: its scrim under the dock, so the dock stays lit, and the block itself over it.
	_ask = AskSheet.new()
	_body.add_child(_ask.scrim)
	_body.move_child(_ask.scrim, _run_dock.get_index())
	_body.add_child(_ask)
	_run_dock.ask = _ask
	_run_dock.picked.connect(func(kind: String, id: String) -> void: _ask.take(kind, id))
	_ask.confirmed.connect(_ask_confirmed)
	_ask.cancelled.connect(_ask_cancelled)
	_ask.changed.connect(_light_ask)
	_ask.hp_preview.connect(_aim_hp)
	## The chart is the one thing laid over the veil rather than under it: a lapidary who is
	## down is still carried along the trail, and can read it as clearly as anyone.
	_body.move_child(_map_margin, _body.get_child_count() - 1)
	## The bench lies over everything but the toasts, whatever page is showing.
	_bench = BenchPanel.new()
	_bench.command.connect(func(cmd: Dictionary) -> void: command.emit(cmd))
	add_child(_bench)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 28)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.z_index = 20
	add_child(_toasts)

func bind(player_id: String, forecast: Callable) -> void:
	local_id = player_id
	forecast_provider = forecast
	_map.local_id = player_id
	_map.run = {}
	_battle.bind(player_id)
	_battle.leave()
	_battle.warm_up()
	_bench.local_id = player_id
	_bench.visible = false
	_run_dock.local_id = player_id
	_run_dock.set_drawer(false)
	## Nor does a run start with the last one's chart unfolded.
	_chart_open = false
	_map_margin.visible = false
	_battle.left_inset = 0.0
	_pinned = ""
	_stall_opened = ""
	_descend_via = -1
	_news = []
	_conquest_item = {}
	_end_started = false
	_end_shown = false
	_over_tab = "run"
	_over_seen = {}
	_progress = []
	_opened = []
	_salvage_thrown = false
	_salvage_rolled = {}
	_pages = {}
	## A new run starts with a clean slate: nothing held, nothing counted, nobody walking.
	_hold = {}
	_counts = {}
	_strip_hold = {}
	_award_clear()
	_close_find()
	_shown_depth = -1
	_last_chamber = {}
	_last_battle = {}
	_last_offers = []
	_walking = false
	_veil.set_down(false, false)
	_veil_synced = false
	_fallen = {}
	_back_told = ""
	_at_table = {}
	_vote_key = ""
	_toss_until = 0
	if _toss_panel != null and is_instance_valid(_toss_panel):
		_toss_panel.queue_free()
	_toss_panel = null
	## The last run's room is forgotten too: a new run at the head it ended on (a dig abandoned
	## at the shaft head) is built afresh, out of the dark and grey its fall left on the stage.
	_stage.place = {}

func warm_up() -> void:
	## Pays for the mine's shaders while nobody is looking.
	_stage.warm_up()

func walking() -> bool:
	return _walking

func apply_quality() -> void:
	_battle.apply_quality()

func apply_look() -> void:
	_stage.apply_look()

func _celebrate(which: String, text: String, color: Color, from: int = -1, to: int = -1) -> void:
	## Deferred, and the strip may have been rebuilt since: the pill is looked up now. Its
	## number ticks over from the old count to the new rather than jumping.
	var found: Variant = _ore_pill if which == "ore" else _bag_pill
	if _headless or found == null or not is_instance_valid(found) or not (found as Control).is_inside_tree():
		return
	var pill: Control = found
	var value: Label = pill.find_child("Value", true, false) as Label
	if value != null and from >= 0 and to >= 0 and from != to:
		value.text = str(from)
		value.create_tween().tween_method(func(v: float) -> void: value.text = str(int(round(v))), float(from), float(to), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	DeepUi.pulse(pill, 1.3, 0.45)
	var at: Vector2 = pill.global_position + Vector2(pill.size.x * 0.5, pill.size.y + 4.0) - global_position
	var label := DeepUi.float_text(self, at, text, color, 20, -34.0, 1.3)
	label.z_index = 30
	DeepUi.burst(self, at, color, 14, 140.0, 0.5, 5.0)

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

func _sync_fallen() -> void:
	## Who is down, said as it changes. This player's own fall greys the screen until a landing
	## brings them round; an ally's is a line at the bottom. Getting back up waits for the walk
	## into the landing to finish, so it happens in the landing and not in the tunnel.
	var phase: String = str(run.get("phase", ""))
	var party: bool = run.get("players", []).size() > 1
	var animate: bool = _veil_synced and not _headless
	## Once the dig is over (a wipe's reckoning, the end) nobody is down any more, but nobody
	## got back up either: the veil lifts without a word and without the fanfare a landing gets.
	var ended: bool = phase in ["over", "salvage"] or run.is_empty()
	for other in run.get("players", []):
		var id: String = str(other.get("id", ""))
		var now_down: bool = bool(other.get("downed", false)) and party and not ended
		var was_down: bool = bool(_fallen.get(id, false))
		if now_down == was_down:
			continue
		if not now_down and _walking and animate and not ended:
			continue
		_fallen[id] = now_down
		if id == local_id:
			_veil.set_down(now_down, animate and (now_down or not ended))
		elif animate and not ended:
			if now_down:
				toast("%s is down. Carry them to the next landing." % str(other.get("name", "")), DeepUi.BAD, "skull")
			else:
				toast("%s is back on their feet." % str(other.get("name", "")), DeepUi.GOOD, "heart")
	_veil_synced = true

# --- state -----------------------------------------------------------------------------------

func show_state(state: Dictionary) -> void:
	run = state
	## The page is drawn again below, and says again what Enter and the number keys take.
	_main_button = null
	_numbered = []
	## A landing's page belongs to the landing. One still set once the party has left it (a
	## trade opened from a tab whose partner then fell, so it never closed itself) would hide
	## the hoard's chip and its "Take it", and hold the twin plate down.
	if not _landing_view.is_empty() and str(run.get("phase", "")) != "landing":
		_landing_view = ""
	if _whom_plate != null and str(run.get("phase", "")) != "landing":
		_close_whom()
	_sync_ceremony()
	_sync_find()
	_sync_twin()
	_map.show_run(run)
	var phase: String = str(run.get("phase", ""))
	## Remember the chamber and the fight as they were: when either ends the state moves on
	## at once, and the page that shows what came of them is drawn from these.
	if phase == "chamber" and not run.get("chamber", {}).is_empty():
		## A copy of the room's own keys: a guest's mirror empties the very dictionary it was
		## handed when the room closes, and what the room held is what the next page reads.
		_last_chamber = run.chamber.duplicate()
	if DeepDescent.in_battle(run):
		_last_battle = DeepDescent.battle(run)
	## A held page gives way the moment the party is somewhere new without us.
	if not _hold.is_empty() and _hold_is_stale():
		_hold = {}
		_strip_hold = {}
	_sync_strip()
	## The card's slots belong to the room they were set in, and so does any tray open over
	## the dock: both are let go the moment the party is somewhere else.
	var room_key: String = "%s:%s:%d" % [phase, str(run.get("chamber", {}).get("oddity", "")), int(run.get("depth", 0))]
	if room_key != _choice_room:
		_choice_room = room_key
		_choice_picks.clear()
		_choice_slot = ""
		_oddity_step = ""
		_altar_slots = ["", "", "", "", ""]
		_altar_sent = false
		## A find offered to the rail is left in the bag once the party is somewhere else.
		_close_find()
		if _run_dock != null and _run_dock.choosing():
			_run_dock.cancel_offer()
		if _ask != null and _ask.is_open():
			_ask.close()
			_run_dock.unspotlight()
		## A bag an altar opened is shut again however the party leaves it: walking on, the
		## chart, a fight. Walking up to the next one opens it again.
		if not _stall_opened.is_empty():
			_stall_opened = ""
			if _run_dock != null:
				_run_dock.set_drawer(false)
	if phase == "over":
		_bench.visible = false
	_bench.refresh(run)
	_settle_ask()
	_sync_stage()
	_sync_fallen()
	## Outside a fight the party's kit stays at hand along the bottom.
	_run_dock.visible = (_walking or not DeepDescent.in_battle(run)) and not phase in ["salvage", "over"] and not (not _hold.is_empty() and str(_hold.get("stage", "")) == "battle")
	_run_dock.dock_height = _battle.dock_height()
	_run_dock.show_run(run)
	_sync_waiting()
	_sync_party_asks()
	_at_table = DeepDescent.trade_table(run).get("offers", {}).duplicate() if phase == "landing" else {}
	## Back in the party after dropping out: said once the screen is up.
	if me().has("back"):
		_tell_back.call_deferred()
	_fit_area()
	if phase != "grubstake":
		_stake_choosing = ""
	if _walking:
		## On the way: only the mine and the strip until the party is in the next room.
		_battle.visible = false
		_area.visible = false
		_scrim.visible = false
		_crossroads.visible = false
		return
	_shown_depth = int(run.get("depth", 0))
	var key: String = phase
	if phase == "chamber":
		key += ":" + str(run.chamber.get("kind", "")) + ":" + str(run.depth) + (":battle" if DeepDescent.in_battle(run) else ":" + str(bool(run.chamber.get("settled", false))))
	elif phase == "landing":
		key += ":" + str(run.depth) + ":" + _landing_view
	elif phase == "tunnels":
		key += ":" + str(run.depth)
	elif phase == "grubstake":
		key += ":" + str(me().get("stake", "")) + ":" + _stake_choosing + ":" + str(DeepDescent.temporary_left(me())) + ":" + str(DeepDescent.dice_offers_left(me()))
	if phase != "grubstake":
		_stake_choosing = ""
	if not _hold.is_empty():
		key = "hold:%s:%s:%d" % [str(_hold.kind), str(_hold.get("stage", "")), int(_hold.get("depth", 0))]
	_fresh = key != _view_key
	_view_key = key
	var mine: String = str(run.get("mine", ""))
	if not _hold.is_empty() and str(_hold.get("stage", "")) in ["battle", "spoils", "flight"]:
		## The fight is over but its last moments are still playing: keep the room up, and
		## the fight's own screen while its banner holds.
		_battle.visible = str(_hold.stage) == "battle"
		_area.visible = false
		_scrim.visible = false
		_crossroads.visible = false
		return
	if DeepDescent.in_battle(run):
		if _rite != null and is_instance_valid(_rite):
			_rite.finish()
		_battle.visible = true
		_area.visible = false
		_map_margin.visible = _chart_open
		_fit_area()
		_scrim.visible = false
		_crossroads.visible = false
		_clear_pages()
		## A forecast is a whole dry run of the rail: worked out only when the fight will take it.
		var battle: Dictionary = DeepDescent.battle(run)
		var forecast: Dictionary = forecast_provider.call() if forecast_provider.is_valid() and _battle.wants_forecast(battle) else {}
		_battle.show_state(battle, int(run.depth), forecast, {"mine": mine, "kind": str(run.chamber.get("kind", "fight")),
			"exits": int(_stage.place.get("exits", 2)), "boss": DeepDescent.run_is_boss(run, int(run.depth)),
			"fight": int(run.get("records", {}).get("fights", 0))})
		return
	_battle.visible = false
	## No fight here and none held on screen: the last one's creatures leave the room.
	_battle.leave()
	if _rite != null and is_instance_valid(_rite):
		## The Hollow's rite has the room: nothing goes up over it until the gem is on the rail.
		_clear_pages()
		_area.visible = false
		_scrim.visible = false
		_crossroads.visible = false
		return
	_area.visible = true
	_map_margin.visible = _chart_open
	_clear_pages()
	if phase == "tunnels" and _hold.is_empty():
		## The way on is chosen at the mouths themselves.
		_scrim.visible = false
		_show_crossroads()
		if _descend_via >= 0:
			var via: int = _descend_via
			_descend_via = -1
			_choose_mouth.call_deferred(via)
		return
	if phase == "chamber" and str(run.chamber.get("kind", "")) in DeepDescent.ROCK_ROOMS and _hold.is_empty():
		## A vein is worked in the room itself.
		_scrim.visible = false
		_show_vein()
		return
	if phase == "chamber" and str(run.chamber.get("kind", "")) == "merchant" and _hold.is_empty():
		## So is a stall: its goods are on the counter.
		_scrim.visible = false
		_show_stall()
		return
	if phase == "chamber" and str(run.chamber.get("kind", "")) == "altar" and _hold.is_empty():
		## And an altar: its sockets and its crystal are on its face.
		_scrim.visible = false
		_show_altar()
		return
	if phase == "landing" and _hold.is_empty():
		## A landing: rest, read or polish at the things in the room, then the lift or a mouth.
		_scrim.visible = false
		_show_landing()
		_tell_restless()
		return
	if phase == "hoard" and _hold.is_empty():
		_scrim.visible = false
		_show_hoard()
		return
	if phase == "over" and not _end_shown:
		## The lift goes up, or the lights go out, before the summary.
		_crossroads.visible = false
		_scrim.visible = false
		_area.visible = false
		if not _end_started:
			_end_started = true
			_run_dock.set_drawer(false)
			## The run is over: the chart folds away rather than lying over the summary.
			if _chart_open:
				_chart_open = false
				_map_margin.visible = false
				_battle.left_inset = 0.0
				_sync_strip()
			_stage.clear_salvage()
			if str(run.get("outcome", "")) in ["extracted", "conquered"]:
				## A coin toss that sent the party up is read before the cage goes.
				var wait: float = float(_toss_until - Time.get_ticks_msec()) / 1000.0 - 0.8
				if wait > 0.0:
					_later(wait, func() -> void:
						if _end_started and not _end_shown:
							_stage.ride_lift(_end_ready))
				else:
					_stage.ride_lift(_end_ready)
			else:
				_stage.darken(_end_ready)
		if not _end_shown:
			return
	_crossroads.visible = false
	_chip_index = -1
	_chip_pick = ""
	_stage.close_ways()
	if phase == "chamber" and str(run.chamber.get("kind", "")) in ["oddity"] + DeepDescent.CARD_ROOMS and _hold.is_empty():
		## An oddity stands in the room, as does a smithy's anvil or a carver's bench; the
		## choices are cards along the bottom.
		_scrim.visible = false
		_show_oddity()
		return
	if phase == "salvage":
		## The dice are thrown in the room; the reckoning is read down the side.
		_scrim.visible = false
		if not _salvage_thrown:
			_salvage_thrown = true
			_stage.salvage(run.get("salvage", {}).get(local_id, {}).get("rolls", []), _pill_centre("bag"))
		_page_salvage(_side_page())
		return
	## Everything else outside a fight is a page over the room. A shrine's mark goes out under it.
	_scrim.visible = true
	_stage.hush_shrine(true)
	var content := _page()
	if not _hold.is_empty():
		match str(_hold.kind):
			"victory", "spoils": _page_spoils(content)
			"oddity": _page_oddity_result(content)
			"stake": _page_stake_result(content)
			"well": _page_well(content)
		_fit_page_soon(_fresh)
		return
	match phase:
		"grubstake": _page_grubstake(content)
		"over": _page_over(content)
	_fit_page_soon(_fresh)

# --- holding a moment ------------------------------------------------------------------------
##
## The rules move on the instant a chamber is done: the last strike of a vein, the killing
## blow, the last choice at an oddity. The screen does not. It holds the page that shows
## what came of it (the rock with every find in it, the spoils of a fight) until the player
## says to move on. A held page is local to this screen; the party is never kept waiting on
## it, and it lets go by itself if the party walks on without us.

func _hold_page(kind: String, fields: Dictionary) -> void:
	_hold = {"kind": kind, "depth": int(run.get("depth", 0)), "token": randi()}
	_hold.merge(fields, true)

func _hold_is_stale() -> bool:
	var phase: String = str(run.get("phase", ""))
	if str(_hold.kind) == "defeat":
		return phase == "over"
	if int(run.get("depth", 0)) > int(_hold.get("depth", 0)):
		return true
	if DeepDescent.in_battle(run):
		return true
	return phase in ["salvage", "over"] and str(_hold.kind) != "defeat"

func _release() -> void:
	## "Onward": let go of the held page and show where the party is now.
	_hold = {}
	show_state(run)

func _after_fight(token: int, stage: String) -> void:
	## The last blow has landed and the banner has had its moment: the spoils on the floor
	## resolve into what was won and fly up to the strip, then the way on opens.
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	if stage != "spoils":
		_hold = {}
		show_state(run)
		return
	_hold.stage = "spoils"
	show_state(run)
	## The strip was torn down and built again a line ago and its pills have no place on the
	## screen until the next layout pass. The spoils have to be told where to fly, so they
	## wait that one frame out.
	if not _headless and is_inside_tree():
		await get_tree().process_frame
		if _hold.is_empty() or int(_hold.get("token", -1)) != token:
			return
	var rewards: Dictionary = _hold.get("rewards", {})
	## What was won is held up large over the room (`_award_plate`) and the spoils fly up off
	## the floor into it; it flies on to the strip later (`_award_fly`). With nothing to show,
	## or no display, they go straight to the strip as they always did.
	var award: Control = _award_plate(rewards)
	if award == null:
		_stage.claim(rewards, _pill_centre("ore"), _pill_centre("bag"), _release_count.bind("ore"), _release_count.bind("haul"),
			_spoils_landed.bind(token, rewards, null))
		return
	var into: Vector2 = award.position + award.size * 0.5 + global_position - _stage.global_position
	_stage.claim(rewards, into, into, Callable(), Callable(), _spoils_landed.bind(token, rewards, award))

func _pill_centre(which: String) -> Vector2:
	## A pill on the strip, in the stage's coordinates, so spoils fly up out of the room and
	## into it. The strip is torn down and rebuilt on every state, and the spoils are claimed
	## in the same breath, so the new pills have not been laid out yet and read as the top
	## left corner: where they stood last is remembered and used until they are placed again.
	var pill: Variant = _ore_pill if which == "ore" else _bag_pill
	if pill != null and is_instance_valid(pill):
		var control: Control = pill
		if control.size.x > 1.0 and control.global_position != Vector2.ZERO:
			_pill_spots[which] = control.global_position + control.size * 0.5 - _stage.global_position
	## Failing everything, the right-hand end of the strip, which is where they live.
	return _pill_spots.get(which, Vector2(_stage.size.x * 0.86, -18.0))

func _purse(unit: Dictionary) -> int:
	## What the purse on the strip reads. In a fight it is the bank as it stands this moment
	## (what a Gambler has staked has already left it), as far as the fight has shown it.
	if unit.is_empty() or not DeepDescent.in_battle(run):
		return int(unit.get("ore", 0))
	var fighter: Dictionary = DeepBattle.player(DeepDescent.battle(run), local_id)
	if fighter.is_empty():
		return int(unit.get("ore", 0))
	return _battle.bank_shown(local_id, maxi(0, int(fighter.get("ore", unit.get("ore", 0))) + int(fighter.get("pyrite_delta", 0))), DeepDescent.battle(run))

func _bank_changed(delta: int) -> void:
	## The fight has moved pyrite in or out of the purse: read it again. Once the fight is
	## won the strip holds what it read until the spoils fly up, and the pot coming home is
	## added to that.
	if _strip_hold.has("ore"):
		_strip_hold.ore = int(_strip_hold.ore) + delta
	_sync_strip()

func _release_count(key: String) -> void:
	if _strip_hold.has(key):
		_strip_hold.erase(key)
		_sync_strip()

func _spoils_landed(token: int, rewards: Dictionary, award: Variant) -> void:
	## `award` is untyped: bound when the spoils were thrown, it may have been freed since (a
	## new run), and a freed object handed to a typed argument is an error.
	if award != null and is_instance_valid(award):
		## The plate holds its moment with the way on already open under it, then what it says
		## flies up to the strip and is counted there as it lands.
		var shown: float = float(Time.get_ticks_msec() - int(award.get_meta("shown", 0))) / 1000.0
		_later(maxf(AWARD_SETTLE, AWARD_HOLD - shown), _award_fly.bind(award))
	else:
		_strip_hold = {}
		_sync_strip()
		var words: Array = []
		## The pay that just flew to the purse; what the fight spent left it as it happened.
		var paid: int = int(rewards.get("earned", rewards.get("ore", 0)))
		if paid != 0:
			words.append("%+d pyrite" % paid)
		for stone in rewards.get("stones", []):
			if not words.is_empty():
				words.append("·")
			words.append(stone)
		if not words.is_empty():
			toast_parts(words, DeepUi.ORE, "bag")
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	var elite: bool = str(_hold.get("chamber", "")) == "elite"
	_hold = {}
	show_state(run)
	## A stone the fight gave up already read (an elite's in the first mine, any elite's on a
	## Big Game day) is offered straight to the rail.
	for stone in rewards.get("stones", []):
		if bool(stone.get("appraised", false)) and not DeepStone.is_geode(stone) and _offer_find(stone, elite):
			break

## How long what a fight paid is held up over the room before it flies to the strip, and the
## least it stays once the last spoil has flown into it.
const AWARD_HOLD: float = 2.5
const AWARD_SETTLE: float = 0.9

func _award_plate(rewards: Dictionary) -> PanelContainer:
	## What a fight paid, held up large over the room in the pyrite's gold: the pyrite, then
	## each stone and die. It used to be a dim line at the foot of the screen, gone in a
	## moment, and new players missed it and only saw the purse on the strip had changed.
	## The parts remember what they are ("ore", or "haul" for a stone or a die), so each
	## flies to its own pill on the strip.
	if _headless or not is_inside_tree():
		return null
	var paid: int = int(rewards.get("earned", rewards.get("ore", 0)))
	var stones: Array = rewards.get("stones", [])
	var dice: Array = rewards.get("dice", [])
	if paid <= 0 and stones.is_empty() and dice.is_empty():
		return null
	_award_clear()
	var plate := PanelContainer.new()
	var style := DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ORE, 26, 10, 3, 5)
	style.content_margin_left = 24
	style.content_margin_right = 28
	DeepUi.facet_ends(plate, style)
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = 25
	add_child(plate)
	_award = plate
	var row := DeepUi.hbox(plate, 12)
	var parts: Array = []
	var say := func(glyph: String, tint: Color, words: String, kind: String, thing: Dictionary) -> HBoxContainer:
		if not parts.is_empty():
			DeepUi.label(row, "·", 24, Color(DeepUi.ORE, 0.6)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var part := DeepUi.hbox(row, 8)
		DeepUi.icon(part, glyph, 26, tint).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var said := DeepUi.label(part, words, 24, DeepUi.ORE)
		said.add_theme_font_override("font", DeepUi.bold_font())
		said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parts.append({"node": part, "kind": kind, "glyph": glyph, "tint": tint, "thing": thing})
		return part
	if paid > 0:
		say.call("ore", DeepUi.ORE, "+%d pyrite" % paid, "ore", {})
	## Three things at most by name; past that, how many more, so the plate stays one line.
	var things: Array = stones.map(func(s: Dictionary) -> Array: return ["stone", s]) + dice.map(func(d: Dictionary) -> Array: return ["die", d])
	for entry in things.slice(0, 3):
		if str(entry[0]) == "stone":
			var stone: Dictionary = entry[1]
			var known: bool = bool(stone.get("appraised", false)) and not DeepStone.is_geode(stone)
			var part: HBoxContainer = say.call("gem", DeepUi.color(DeepStone.color(stone)), DeepUi.skill_name(stone) if known else DeepStone.raw_name(stone), "haul", stone)
			if known:
				StoneCard.grade_marks(part, stone, 15, DeepUi.ORE).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			say.call("die", DiceIcons.die_palette(entry[1]).body, DeepDice.describe(entry[1]), "haul", entry[1])
	if things.size() > 3:
		say.call("bag", DeepUi.ORE, "+%d more" % (things.size() - 3), "haul", {})
	plate.set_meta("parts", parts)
	plate.set_meta("shown", Time.get_ticks_msec())
	## Under the room's title and its line of help, over the middle of the room.
	plate.size = plate.get_combined_minimum_size()
	var body_top: float = _body.global_position.y - global_position.y
	plate.position = Vector2((size.x - plate.size.x) * 0.5, body_top + AWARD_Y - plate.size.y * 0.5).round()
	DeepUi.pop_in(plate, 0.0, 0.7, 0.34)
	DeepAudio.play("toast", {"volume": 0.8})
	return plate

## Where the plate's middle stands, down from the top of the room: below the crossroads' name,
## its line and its lantern row, above the signs over the mouths.
const AWARD_Y: float = 200.0

func _award_fly(found: Variant) -> void:
	## Each part of the plate flies to its pill on the strip in a stream of little marks, and
	## the pill's count ticks up as the last of them lands; the plate fades as they go. Untyped
	## for the same reason as `_spoils_landed`'s.
	if found == null or not is_instance_valid(found):
		_strip_hold = {}
		_sync_strip()
		return
	var award: Control = found
	var parts: Array = award.get_meta("parts", [])
	var left: Dictionary = {"ore": 0, "haul": 0}
	for part in parts:
		left[str(part.kind)] = int(left[str(part.kind)]) + 1
	## A pill with nothing coming to it is let go now.
	for key in left:
		if int(left[key]) == 0:
			_release_count(key)
	var delay: float = 0.0
	for part in parts:
		var node: Control = part.node
		if not is_instance_valid(node):
			continue
		var kind: String = str(part.kind)
		var from: Vector2 = node.get_global_rect().get_center() - global_position
		var to: Vector2 = _pill_centre("ore" if kind == "ore" else "bag") + _stage.global_position - global_position
		var marks: int = 6 if kind == "ore" else 1
		for mark in range(marks):
			var last: bool = mark == marks - 1
			var landed := func() -> void:
				DeepAudio.play("ore" if kind == "ore" else "stone_found", {"volume": 0.45 if kind == "ore" else 0.6, "gap": 0.03})
				if last:
					left[kind] = int(left[kind]) - 1
					if int(left[kind]) <= 0:
						_release_count(kind)
			_award_mark(str(part.glyph), part.tint, from + Vector2(randf_range(-10.0, 10.0), 0.0) if marks > 1 else from, to, delay + 0.05 * float(mark), 0.62, landed)
		delay += 0.18
	var fade := award.create_tween()
	fade.tween_interval(0.15)
	fade.tween_property(award, "modulate:a", 0.0, 0.4)
	fade.tween_callback(award.queue_free)
	if _award == award:
		_award = null

func _award_mark(glyph: String, tint: Color, from: Vector2, to: Vector2, delay: float, seconds: float, landed: Callable) -> void:
	## One mark on its way up: out sideways towards the pill, then up into it from below,
	## shrinking as it goes. (An arc over the top crossed the strip's other buttons.)
	var mark := DeepUi.icon(self, glyph, 26, tint)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.z_index = 26
	mark.size = Vector2(26, 26)
	mark.pivot_offset = mark.size * 0.5
	mark.position = from - mark.size * 0.5
	mark.modulate.a = 0.0
	var bend: Vector2 = Vector2(lerpf(from.x, to.x, 0.85), lerpf(from.y, to.y, 0.15))
	var tween := mark.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(mark, "modulate:a", 1.0, 0.06)
	tween.tween_method(func(t: float) -> void:
		mark.position = from.lerp(bend, t).lerp(bend.lerp(to, t), t) - mark.size * 0.5
		mark.scale = Vector2.ONE * lerpf(1.0, 0.55, t), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if landed.is_valid():
			landed.call()
		mark.queue_free())

func _award_clear() -> void:
	## A plate still up from the last fight goes; its flight, when it comes due, finds it gone
	## and lets the strip count what it held at once.
	if _award != null and is_instance_valid(_award):
		_award.queue_free()
	_award = null

func _depth_title(depth: int, kind: String) -> void:
	## A title over the tunnel's last stretch: the depth, what waits, and the biome it is in.
	## No curtain: the party sees where it is going.
	if _headless:
		return
	DeepAudio.play("depth_card", {"volume": 0.8})
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(card)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(centre)
	var column := DeepUi.vbox(centre, 6)
	var tone: Color = DeepUi.CHAMBER_colorS.get(kind, DeepUi.ACCENT)
	var mark := DeepUi.icon(column, str(DeepUi.CHAMBER_GLYPHS.get(kind, "stairs")), 54, tone)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## The head of a mine the party has pushed on into is named, not numbered.
	var heading := DeepUi.title(column, DeepContent.mine_name(str(run.get("mine", ""))) if kind == "head" else "Depth %d" % depth, 54, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	heading.add_theme_constant_override("outline_size", 10)
	var words: String = str(KIND_WORDS.get(kind, kind.capitalize())) if kind != "warden" else ("The final boss" if DeepDescent.run_is_boss(run, depth) else "A Warden")
	if kind == "head":
		words = "The top of the mine"
	var biome: Dictionary = Biomes.for_depth(str(run.get("mine", "")), maxi(1, depth), "fight", Biomes.run_phase(run, maxi(1, depth)))
	var line := DeepUi.label(column, "%s  ·  %s" % [words, str(biome.get("name", ""))], 18, tone.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	line.add_theme_constant_override("outline_size", 6)
	card.modulate.a = 0.0
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.1)
	tween.tween_property(card, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(card.queue_free)

func _page() -> VBoxContainer:
	## A page over the room, centred in it. It never scrolls: a page holds what fits, and a
	## long list on one is turned a page at a time. On the phone it may: a page taller than
	## the room scrolls in it (docs/PHONE_UI.md), and one shorter is centred as on the desk.
	if DeepUi.phone:
		var scroll := ScrollContainer.new()
		scroll.name = "PageScroll"
		scroll.set_meta("may_scroll", true)
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		_page_holder.add_child(scroll)
		var middle := CenterContainer.new()
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
		middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll.add_child(middle)
		var room := MarginContainer.new()
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_theme_constant_override("margin_left", int(DeepUi.safe_left + DeepUi.pt(6)))
		room.add_theme_constant_override("margin_right", int(DeepUi.safe_right + DeepUi.pt(6)))
		room.add_theme_constant_override("margin_top", int(DeepUi.pt(6)))
		room.add_theme_constant_override("margin_bottom", int(DeepUi.pt(6)))
		middle.add_child(room)
		var phone_content := DeepUi.vbox(room, int(DeepUi.pt(6)))
		phone_content.custom_minimum_size.x = minf(DeepUi.pt(700), _page_holder.size.x - DeepUi.safe_left - DeepUi.safe_right - DeepUi.pt(12)) if _page_holder.size.x > 0.0 else DeepUi.pt(700)
		_page_content = phone_content
		return phone_content
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_holder.add_child(centre)
	var margin := DeepUi.margin(centre, 28, 22)
	var content := DeepUi.vbox(margin, 18)
	content.custom_minimum_size.x = 940
	_page_content = content
	return content

## The page's margin above and below it (`_page`), counted when it is measured against the room.
const PAGE_MARGINS: float = 44.0

func _fit_page(fresh: bool = false) -> void:
	## With the bag open, a page over the room (a result's, with its Onward at the foot) could
	## stand taller than the room left above the drawer, and Onward went under it. While the bag
	## is open and the page does not fit, it folds its medallion away. A page new on screen that
	## still does not fit shuts the bag: what it shows is the way on, and the bag opens again
	## from the strip.
	if _page_content == null or not is_instance_valid(_page_content) or not _page_content.is_inside_tree():
		return
	_pin_onward()
	var medals: Array = []
	_medallions(_page_content, medals)
	## Measured whole every time, so a fold never decides that it fits because it is folded.
	for medal in medals:
		(medal as Control).visible = true
	var open: bool = _run_dock.visible and _run_dock.is_drawer_open()
	var room: float = _area.size.y - PAGE_MARGINS
	## A page too tall for the room folds its medallion bag or no bag (November 9, 2026: the
	## haul's two-line names took the end of a run past the foot of the screen).
	if _page_content.get_combined_minimum_size().y <= room:
		return
	for medal in medals:
		(medal as Control).visible = false
	if fresh and open and _page_content.get_combined_minimum_size().y > room:
		_run_dock.set_drawer(false)

func _pin_onward() -> void:
	## On the phone a page taller than the room scrolls, and its way on (Onward, Take it, Back
	## to the workshop) went down out of sight under the dock with the rest: it stands at the
	## room's foot instead, under the scroll (November 9, 2026). A page that fits keeps it.
	if not DeepUi.phone:
		return
	var go: Button = _main_button
	if go == null or not is_instance_valid(go) or not _page_content.is_ancestor_of(go):
		return
	var scroll: Control = _page_holder.get_node_or_null("PageScroll")
	if scroll == null:
		return
	## The button, or the row it stands in (and out of the card it is in: the haul's).
	var piece: Control = go.get_parent() as Control if go.get_parent() is HBoxContainer else go
	if _page_content.get_combined_minimum_size().y + DeepUi.pt(12) <= _page_holder.size.y:
		return
	## Above the dock, or with no dock (the end of a run) above the screen's safe foot.
	var under: float = DeepUi.pt(6) + (0.0 if _run_dock.visible else DeepUi.safe_bottom)
	var lift: float = piece.get_combined_minimum_size().y + DeepUi.pt(6) + under
	var foot := CenterContainer.new()
	foot.name = "PageFoot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = - lift
	foot.offset_bottom = - under
	_page_holder.add_child(foot)
	piece.reparent(foot, false)
	scroll.offset_bottom = - lift

func _fit_page_soon(fresh: bool) -> void:
	## Once the new page has been laid out: a wrapped line knows how tall it is only then.
	if _headless or not is_inside_tree():
		_fit_page(fresh)
		## Headless too, a wrapped line is measured right only once laid out: once more then.
		if not is_inside_tree():
			return
	var later: Callable = _fit_page.bind(fresh)
	if not get_tree().process_frame.is_connected(later):
		get_tree().process_frame.connect(later, CONNECT_ONE_SHOT)

func _medallions(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Medallion:
			out.append(child)
		else:
			_medallions(child, out)

func _enter(node: Control, delay: float = 0.0) -> void:
	## Only a new page eases in; a page rebuilt by a vote or a strike just appears.
	if _fresh:
		DeepUi.pop_in(node, delay)

func _paged(parent: Node, list: String, items: Array, per_page: int) -> Array:
	## The items of a long list that go on its current page, and the pager for the rest.
	var count: int = DeepUi.pages(items.size(), per_page)
	var page: int = clampi(int(_pages.get(list, 0)), 0, count - 1)
	_pages[list] = page
	if count > 1:
		var pager := DeepUi.pager(parent, page, count, func(to: int) -> void:
			_pages[list] = to
			DeepAudio.play("ui_tap", {"volume": 0.6})
			show_state(run))
		## It stands over the room, not on a card: an outline keeps "1 of 2" readable on bright
		## rock.
		for child in pager.get_children():
			if child is Label:
				(child as Label).add_theme_color_override("font_color", DeepUi.PAPER.darkened(0.15))
				(child as Label).add_theme_constant_override("outline_size", 6)
				(child as Label).add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.9))
	return DeepUi.page_of(items, page, per_page)

func handle(event: Dictionary) -> void:
	## One event from the host. Fights are animated; everything else gets a line of text.
	var kind: String = str(event.get("kind", ""))
	## Someone's line dropped or came back. Whatever the party was waiting on them for has
	## already gone ahead in the same event; this only says why.
	## Held longer than most lines: it is the only word the rest of the party gets, and it was
	## missed at the usual length.
	if event.has("absent") and str(event.absent) != local_id:
		var gone: String = str(DeepDescent.player(run, str(event.absent)).get("name", "A delver"))
		toast("%s lost connection. %s" % [gone, "Their seat plays itself until they are back." if DeepDescent.in_battle(run) else "The party goes on without them until they are back."],
			DeepUi.MUTED, "wifi", 5.5)
	elif kind == "presence" and bool(event.get("connected", false)) and str(event.get("unit", "")) != local_id:
		toast("%s is back." % str(DeepDescent.player(run, str(event.get("unit", ""))).get("name", "A delver")), DeepUi.GOOD, "party", 4.0)
	## A split vote settled by a coin toss or a draw: who wanted what, and which way won.
	if event.get("toss", null) is Dictionary:
		_toss_beat(event.toss)
	## The cage was chosen when the party could pay for it and can no longer: whoever chose it
	## chooses again.
	if event.has("lift_short"):
		var short: Dictionary = event.lift_short
		toast("The winch wants %d pyrite and %s %d now. Choose again." % [int(short.get("cost", 0)), "the party has" if run.get("players", []).size() > 1 else "you have", int(short.get("have", 0))], DeepUi.BAD, "lift")
	## The vote that carries takes the party into the next chamber, and the chamber's own
	## event (a motherlode's spoils, the landing, the fight beginning) rides inside it.
	if event.has("entered"):
		handle(event.entered)
	## A Black Opal took a gem from the bag as the fight opened.
	for entry in event.get("absorbed", []):
		if str(entry.get("unit", "")) == local_id:
			toast_parts(["Your Black Opal absorbed", entry.get("taken", {})], DeepUi.OPAL_TONE, "opal_setting")
	match kind:
		"staked":
			if str(event.get("unit", "")) == local_id:
				## Until the party is staked the shaft head shows what this did. Once it moves
				## on, a stake left to chance, or one that made a stone, holds its result up; any
				## other says it in a line.
				var chance: bool = not event.get("changed", []).is_empty() or not event.get("made", []).is_empty()
				if bool(event.get("finished", false)) and not chance and not str(event.get("message", "")).is_empty():
					toast(str(event.message), DeepUi.ACCENT, "bag")
				else:
					DeepAudio.play("dice_lock", {"volume": 0.8})
				if bool(event.get("finished", false)) and chance:
					_hold_page("stake", {"result": {"boons": event.get("boons", []), "message": str(event.get("message", "")),
						"made": event.get("made", []), "dice": event.get("dice", []), "changed": event.get("changed", [])}})
				## A pick's stone goes under the loupe the moment it is taken: the whole reading,
				## and at the end of it an empty socket to set it in, or the bag.
				if str(event.get("unit", "")) == local_id and bool(event.get("pick", false)) and not event.get("made", []).is_empty():
					_appraisal(event.made[0])
			elif bool(event.get("finished", false)) and _hold.is_empty():
				## The party moved on while my own stake's chance result was still on the shaft
				## head: hold it up with Onward, as the last picker gets.
				var mine: Dictionary = run.get("grubstake", {}).get("chosen", {}).get(local_id, {})
				if not mine.get("changed", []).is_empty() or not mine.get("made", []).is_empty():
					_hold_page("stake", {"result": {"boons": mine.get("boons", []), "message": str(mine.get("message", "")),
						"made": mine.get("made", []), "dice": mine.get("dice", []), "changed": mine.get("changed", [])}})
		"battle":
			if event.has("battle"):
				_battle.perform(event.battle)
			if event.has("resolution"):
				_battle.perform(event.resolution)
			if event.has("settle"):
				var settle: Dictionary = event.settle
				var fight: Dictionary = _last_battle
				if str(settle.get("outcome", "")) == "victory":
					_strip_hold = _counts.duplicate()
					_hold_page("victory", {"stage": "battle", "settle": settle, "rewards": settle.get("rewards", {}).get(local_id, {}),
						"chamber": str(settle.get("kind", "fight")), "turns": int(fight.get("turn", 1)),
						"slain": fight.get("enemies", []).map(func(e: Dictionary) -> String: return str(e.get("name", "")))})
					_later(2.3, _after_fight.bind(int(_hold.token), "spoils"))
				else:
					_hold_page("defeat", {"stage": "battle"})
					_later(2.8, _after_fight.bind(int(_hold.token), "release"))
		"vein_strike":
			_vein_struck(event)
		"oddity_result":
			## The Smithy's hammer (plain or upgraded) comes down on the die in the dock.
			if str(event.get("unit", "")) == local_id and _oddity_action(str(event.get("choice", ""))) == "upsize":
				_hammer_dock_die(event.get("dice", []))
			## The cabinet's one good lens reads a stone the way any other appraisal does.
			if str(event.get("unit", "")) == local_id and _oddity_action(str(event.get("choice", ""))) == "appraise" and not event.get("changed", []).is_empty():
				_appraisal(event.changed[0])
			## The Hollow takes its die and gives the gem back Void, over the room, before any page.
			if str(event.get("unit", "")) == local_id and event.get("voided", null) is Dictionary:
				_hollow_rite(event)
			## The well answers in the room itself before any page goes up over it, and the
			## page it puts up waits for the player rather than moving on by itself.
			var wished: bool = str(event.get("unit", "")) == local_id and event.has("well")
			## Whoever threw something in, the bucket goes down for it where everyone can see.
			if event.has("well"):
				_stage.well_draw(_well_loudness(event.get("well", {})))
			if wished:
				_well_hold(str(event.get("message", "")), event.get("well", {}), event.get("made", []), "oddity")
			## The acid takes the rock off several at once, and each is read out in its turn.
			if str(event.get("unit", "")) == local_id and not event.get("revealed", []).is_empty():
				_acid_reveal(event.revealed.duplicate(true), 0)
			if str(event.get("unit", "")) == local_id and bool(event.get("again", false)):
				## The idol did not let go. The card stays up and the next pull costs more.
				DeepAudio.play("dice_lock", {"volume": 0.9})
				if not _headless:
					DeepUi.shake(self, 6.0, 0.25)
				toast(str(event.get("message", "")), DeepUi.BAD, "eye")
			elif str(event.get("unit", "")) == local_id and not wished:
				## What came of this player's choice goes up the moment they make it, whoever
				## else at the card is still choosing: the party waits on them in the room after.
				var room: Dictionary = run.get("chamber", {}) if not run.get("chamber", {}).is_empty() else _last_chamber
				var mine_result: Dictionary = {"choice": str(event.get("choice", "")), "message": str(event.get("message", "")), "made": event.get("made", []),
					"lost": event.get("lost", []), "changed": event.get("changed", []), "dice": event.get("dice", []), "dice_lost": event.get("dice_lost", []),
					"tumbled": event.get("tumbled", {})}
				## What a Wheel or an Oven did, so the page plays it out on the ladder rather than
				## only saying it (it was dropped here, and the result showed at once).
				for extra in ["verdict", "broke", "faces"]:
					if event.has(extra):
						mine_result[extra] = event[extra]
				_hold_page("oddity", {"oddity": str(room.get("oddity", "")), "room": str(room.get("kind", "oddity")), "result": mine_result})
		"altar_made":
			## Everyone sees the circle take the five; whoever gave them gets the gem held up, and
			## a Transcendent is held up for the whole party.
			var maker: String = str(event.get("unit", ""))
			var made: Dictionary = event.get("made", {})
			var transcendent: bool = bool(event.get("transcendent", false))
			var wait: float = 0.0
			var here: Node3D = _stage.business() if _stage.business_key().begins_with("altar|") else null
			if here != null and here.has_method("make"):
				wait = here.make(_stage.fx, transcendent, maker == local_id)
			DeepAudio.play("altar_make")
			if transcendent and not _headless:
				DeepUi.shake(self, 10.0, 0.55)
			if maker == local_id:
				_altar_making = true
				_later(wait, func() -> void:
					_altar_making = false
					_altar_slots = ["", "", "", "", ""]
					_altar_sent = false
					if DeepDescent.at_altar(run):
						_show_altar()
					_altar_reveal(made, transcendent, ""))
			elif transcendent:
				_later(wait, _altar_reveal.bind(made, true, str(DeepDescent.player(run, maker).get("name", "Someone"))))
			else:
				toast_parts(["%s's altar gave" % str(DeepDescent.player(run, maker).get("name", "Someone")), made], DeepUi.CHAMBER_colorS.get("altar", DeepUi.ACCENT), "altar")
		"altar_left":
			if str(event.get("unit", "")) != local_id:
				toast("%s walked on from the altar." % str(DeepDescent.player(run, str(event.get("unit", ""))).get("name", "Someone")), DeepUi.MUTED, "altar")
		"appraised":
			if str(event.get("unit", "")) == local_id:
				_appraisal(event.stone)
		"hoard_pick":
			if str(event.get("unit", "")) == local_id:
				_pinned = ""
				_chip_pick = ""
				var taken: Dictionary = event.get("stone", {})
				_stage.hoard_take(str(taken.get("id", "")), _pill_centre("bag"))
				DeepAudio.reveal_stone(taken)
				var known: bool = bool(taken.get("appraised", false))
				## The mine's last hall is the final boss's, not a Warden's.
				var whose: String = "the final boss's" if DeepDescent.run_is_boss(run, int(run.get("depth", 0))) else "the Warden's"
				Inspector.stone(taken, {"fanfare": {"title": "The hoard is yours",
					"subtitle": ("From %s hoard, appraised and ready to set." % whose) if known else (("From %s hoard, sealed. Carry it up: the workshop cracks it." % whose) if DeepStone.is_geode(taken) else ("From %s hoard, still raw. Appraise it to see what it is." % whose)),
					"button": "Into the bag"}})
		"twin_settled":
			## Fused: the two go into the fire over the room and the heavier comes out of it.
			if str(event.get("unit", "")) == local_id and str(event.get("choice", "")) == "fuse" and event.get("fused", null) is Dictionary:
				_fusion_rite(event.get("other", {}), event.get("stone", {}), event.fused, int(event.get("paid", 0)))
		"traded":
			var units: Array = event.get("units", [])
			var stones: Dictionary = event.get("stones", {})
			if units.has(local_id):
				var other_id: String = str(units[1] if str(units[0]) == local_id else units[0])
				_trade_flourish(stones.get(local_id, {}), stones.get(other_id, {}))
				toast("You traded with %s." % str(DeepDescent.player(run, other_id).get("name", "")), DeepUi.ORE, "scales")
				_landing_view = ""
			else:
				toast("%s and %s traded stones." % [str(DeepDescent.player(run, str(units[0])).get("name", "")), str(DeepDescent.player(run, str(units[1])).get("name", ""))], DeepUi.ORE, "scales")
		"trade_offer":
			var asker: String = str(event.get("unit", ""))
			## A stone offered to this player is said once, wherever they are looking; their
			## tab and the line under the room's name carry it for as long as it stands.
			if asker != local_id and str(event.get("to", "")) == local_id:
				DeepAudio.play("ui_toggle", {"volume": 0.6})
				if _landing_view == "trade" and _trade_with == asker:
					_trade_pulse = true
				elif str(_at_table.get(asker, {}).get("to", "")) != local_id:
					toast("%s offers you a stone. Click their tab to answer." % str(DeepDescent.player(run, asker).get("name", "Someone")), DeepUi.ORE, "scales", 5.0)
		"trade_withdraw":
			## An offer gone without a word read as a bug: say whose, and that it was taken back.
			var taker: String = str(event.get("unit", ""))
			if taker != local_id and str(event.get("to", "")) == local_id:
				toast("%s took their offer back." % str(DeepDescent.player(run, taker).get("name", "Someone")), DeepUi.MUTED, "scales", 4.0)
		"trade_accept":
			if str(event.get("unit", "")) != local_id:
				DeepAudio.play("ui_confirm", {"volume": 0.6})
		"bought":
			## Off the counter and into the bag it goes, or away with whoever bought it.
			var item: Dictionary = event.get("item", {})
			var buyer: bool = str(event.get("unit", "")) == local_id
			_stage.stall_sold(str(item.get("id", "")), _pill_centre("bag"), buyer)
			_stage.remove_pick("item:%s" % str(item.get("id", "")))
			if _pinned == "item:%s" % str(item.get("id", "")):
				_pinned = ""
				_chip_pick = ""
			if buyer:
				DeepAudio.play("buy")
				## A die is traded for, one of yours going back across the counter: it has no stone to name.
				if str(item.get("kind", "stone")) == "die":
					toast("Traded for the %s · %d pyrite" % [DeepDice.describe(item.get("die", {})), int(item.get("price", 0))], DeepUi.ORE, "die")
				else:
					toast_parts(["Bought", item.get("stone", {}), "for %d pyrite" % int(item.get("price", 0))], DeepUi.ORE, "purse")
		"sold":
			var counter: Node3D = _stage.business()
			if counter != null and counter.has_method("weigh"):
				counter.weigh()
			if str(event.get("unit", "")) == local_id:
				DeepAudio.play("sell")
				toast("Sold for %d pyrite" % int(event.get("paid", 0)), DeepUi.ORE, "scales")
		"respite":
			var lift: Node3D = _stage.hall()
			if lift != null and str(event.get("choice", "")) == "wish":
				## The bucket goes down after it and comes back up with the answer; our own
				## wish's page rises over the room just as it breaks.
				lift.wish_drawn(_stage.fx, _well_loudness(event.get("well", {})))
			if str(event.get("unit", "")) == local_id:
				match str(event.get("choice", "")):
					"rest":
						DeepAudio.play("heal", {"volume": 0.8})
						var healed: int = int(event.get("healed", 0))
						toast("+%d health" % healed if healed > 0 else "You were already at full health", DeepUi.GOOD if healed > 0 else DeepUi.MUTED, "heart")
					"appraise":
						_appraisal(event.get("stone", {}))
					"wish":
						_well_hold(str(event.get("message", "")), event.get("well", {}), event.get("made", []), "landing")
		"landing":
			DeepAudio.play("landing")
			toast("The landing. Breathe.", DeepUi.GOOD, "lift")
			_station_sent = ""
			_trade_with = ""
			## Restless Rock turned the rails as the party arrived. It used to happen without a
			## word; now it is said, socket by socket, once the party stands at the landing.
			var landing: Dictionary = event.get("landing", {})
			if landing.has("restless"):
				_restless_news = {"changed": landing.restless.duplicate(true)}
		"landing_choice":
			if not str(event.get("next_mine", "")).is_empty():
				DeepAudio.play("depth_card", {"volume": 0.9})
				toast("On into %s. Nothing is banked until you ride up." % DeepContent.mine_name(str(run.get("mine", ""))), DeepUi.ACCENT, "descend")
		"lit":
			var who: String = str(DeepDescent.player(run, str(event.get("unit", ""))).get("name", ""))
			var paid: String = "%d pyrite" % DeepDescent.lantern_cost()
			var mine: bool = str(event.get("unit", "")) == local_id
			var lighter: String = "You light" if mine else "%s lit" % who
			DeepAudio.play("lantern")
			## Someone else's lantern changes the chart under this player: held a little longer.
			toast("%s the way to depth %d (%s)." % [lighter, int(event.get("to", 0)), paid], DeepUi.ACCENT, "lantern", 2.8 if mine else 4.5)
			if not _headless and is_instance_valid(_map) and _map.is_visible_in_tree():
				DeepUi.burst(self, _map.global_position - global_position + _map.size * Vector2(0.5, 0.35), DeepUi.ACCENT, 26, 220.0, 0.8, 5.0)
		"abandoned":
			_hold = {}
			toast("The dig is abandoned.", DeepUi.BAD, "flag")
		"rail_changed":
			if str(event.get("unit", "")) == local_id and event.get("placed", null) is Dictionary:
				_rail_placed(event.placed)

func _rail_placed(placed: Dictionary) -> void:
	## A stone set on the rail: the socket that took it flashes, and one that put another gem
	## back in the bag says so in a line. A drag onto a filled socket used to swap the two
	## without a word, and the new gem looked like the old one.
	var socket: int = int(placed.get("socket", -1))
	var stone: Dictionary = placed.get("stone", {})
	var out: Dictionary = placed.get("out", {})
	var from: int = int(placed.get("from", -1))
	if socket < 0 or stone.is_empty():
		return
	if not out.is_empty() and from < 0:
		## A stone in a toast is said with its grade marks, its carat among them.
		toast_parts([stone, "in socket %d  ·" % (socket + 1), out, "to the bag"], DeepUi.GOOD, "gem")
	## Two set gems trading places both flash; the one set is named by its weight.
	var sockets: Array = [socket] if from < 0 or out.is_empty() else [socket, from]
	## The dock is drawn again from the new state right after this event: the flash waits for it.
	_run_dock.flash_sockets.call_deferred(sockets, "%d ct" % int(stone.get("carat", 1)))

func _tell_restless() -> void:
	## Restless Rock's turn of the rail, said once the party stands at the landing: each of
	## this player's stones that changed, old skill to new, and the sockets they sit in
	## flashed. A rail it left alone (nothing else of a color to turn into) is said too, since
	## the card only says the stones may change.
	if _restless_news.is_empty():
		return
	var changed: Dictionary = _restless_news.get("changed", {})
	_restless_news = {}
	var unit: Dictionary = me()
	var turns: Array = []
	var sockets: Array = []
	var rail: Array = unit.get("rail", [])
	for stone in DeepStone.rail_stones(unit):
		var id: String = str(stone.get("id", ""))
		if not changed.has(id):
			continue
		## A save from before the change kept only the new skill.
		var entry: Dictionary = changed[id] if changed[id] is Dictionary else {"to": str(changed[id])}
		if str(entry.get("unit", local_id)) != local_id:
			continue
		var now: String = str(DeepContent.skill(str(entry.get("to", stone.get("skill", "")))).get("name", entry.get("to", "")))
		var was: String = str(entry.get("from", ""))
		turns.append(("%s to %s" % [str(DeepContent.skill(was).get("name", was)), now]) if not was.is_empty() else "one to %s" % now)
		var socket: int = int(DeepStone.rider_place(unit, id).get("socket", -1))
		for index in range(rail.size()):
			if rail[index] is Dictionary and str(rail[index].get("id", "")) == id:
				socket = index
		if socket >= 0 and not sockets.has(socket):
			sockets.append(socket)
	var tone: Color = _daily_tone("twist")
	if turns.is_empty():
		toast("Restless Rock leaves your rail as it was.", tone, "swirl")
		return
	var said: String = turns[0] if turns.size() == 1 else "%s and %s" % [", ".join(turns.slice(0, turns.size() - 1)), turns.back()]
	toast("Restless Rock turns %s." % said, tone, "swirl", 5.5)
	DeepAudio.play("ui_toggle", {"volume": 0.8})
	_run_dock.flash_sockets.call_deferred(sockets)

func _acid_reveal(stones: Array, at: int) -> void:
	## Out of the racks one at a time. Each stone gets the whole ceremony, and the last one
	## hands the room back rather than opening another.
	if at < 0 or at >= stones.size():
		return
	var last: bool = at + 1 >= stones.size()
	var raw: Dictionary = stones[at].duplicate(true)
	raw.appraised = false
	raw.inclusions_revealed = false
	var action: Dictionary = {"label": "Onward" if last else "Next stone", "glyph": "check" if last else "next",
		"tone": DeepUi.ACCENT, "primary": true, "dismiss": true,
		"caption": "%d of %d out of the racks" % [at + 1, stones.size()]}
	if not last:
		action["call"] = func() -> void: _acid_reveal(stones, at + 1)
	_belongs_here(Appraisal.open(raw, {"actions": [action], "title": "Out of the acid"}))

func _hollow_rite(event: Dictionary) -> void:
	## The die out of the tray and down the hole, the gem off the rail, over it and back onto
	## it Void (see hollow_rite.gd). This is called before the dock is drawn again from the new
	## state, so the two are taken from where they stood; the gem's new place on the rail stays
	## hidden until it lands there.
	if _headless:
		return
	var voided: Dictionary = event.voided
	var id: String = str(voided.get("stone_id", ""))
	var stone: Dictionary = {}
	for changed in event.get("changed", []):
		if str(changed.get("id", "")) == id:
			stone = changed
	var lost: Array = event.get("dice_lost", [])
	if stone.is_empty() or lost.is_empty():
		return
	if _rite != null and is_instance_valid(_rite):
		_rite.finish()
	var gem_at: Vector2 = _run_dock.centre_of("stone", id)
	if gem_at == Vector2.INF:
		gem_at = _run_dock.centre_of("bag")
	var die_at: Vector2 = _run_dock.centre_of("die", str(lost[0].get("id", "")))
	if die_at == Vector2.INF:
		die_at = _run_dock.centre_of("dice")
	_run_dock.veil(id)
	var rides: Dictionary = voided.get("rides", {})
	var rite := HollowRite.new()
	rite.play(stone, lost[0], gem_at, die_at, func() -> Vector2:
		var spot: Vector2 = _run_dock.centre_of("stone", id)
		if spot == Vector2.INF and not rides.is_empty():
			rite.land_edge = BattleScreen.SOCKET_EDGE - 12.0
			spot = _run_dock.centre_of("socket", str(int(rides.socket)))
		if spot == Vector2.INF:
			rite.land_edge = 40.0
			spot = _run_dock.centre_of("bag")
		return spot)
	rite.gem_from_edge = BattleScreen.SOCKET_EDGE - 12.0
	rite.die_from_edge = BattleScreen.SOCKET_EDGE
	rite.land_edge = RunDock.RIDER - 4.0
	rite.beat.connect(func(moment: String) -> void:
		if moment == "impact":
			DeepUi.shake(self, 7.0, 0.45)
		elif moment == "landed":
			_run_dock.unveil(id))
	rite.done.connect(func() -> void:
		_rite = null
		## The page that waited on it comes up fresh, with its own entrance.
		_view_key = ""
		show_state.call_deferred(run))
	_rite = rite
	_body.add_child(rite)

func _oddity_action(choice_id: String) -> String:
	for choice in DeepContent.oddity(str(_last_chamber.get("oddity", ""))).get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return str(choice.get("action", {}).get("kind", ""))
	return ""

func _appraisal(stone: Dictionary) -> void:
	## A stone of ours has just been read: the whole ceremony, rock and all, then what can be
	## done with it here and now.
	if stone.is_empty():
		return
	_belongs_here(Appraisal.open(stone, {"actions": appraisal_actions(stone)}), stone)

func _belongs_here(layer: CanvasLayer, stone: Dictionary = {}) -> void:
	## An appraisal opened down the mine is the run's: it is told which run, whether a fight
	## was on, and (when its choices follow the room) which stone. See `_sync_ceremony`.
	if layer == null:
		return
	layer.set_meta("run_id", str(run.get("run_id", "")))
	layer.set_meta("in_fight", DeepDescent.in_battle(run))
	if not stone.is_empty():
		layer.set_meta("stone", stone.duplicate(true))

func _sync_ceremony() -> void:
	## An appraisal is a layer over the whole window, and the run goes on under it when the
	## party moves (or the run ends). Where the reading no longer fits (a fight has begun since,
	## the run is over, the screen is gone) it is put away, the stone left in the bag; while it
	## stays up, its choices are the ones that work here now.
	var phase: String = str(run.get("phase", ""))
	## A twin's fusion plays over the room the same way, and goes the same way: a fight begun
	## or the run over puts it away.
	var rite: CanvasLayer = load("res://view/gems/geode.gd").current()
	if rite != null and rite.has_meta("run_id") and (run.is_empty() or not is_visible_in_tree() or str(run.get("run_id", "")) != str(rite.get_meta("run_id")) \
			or phase in ["over", "salvage"] or DeepDescent.in_battle(run)):
		rite.close()
	var layer: CanvasLayer = Appraisal.current()
	if layer == null or not layer.has_meta("run_id"):
		return
	if run.is_empty() or not is_visible_in_tree() or str(run.get("run_id", "")) != str(layer.get_meta("run_id")) or phase in ["over", "salvage"] or (DeepDescent.in_battle(run) and not bool(layer.get_meta("in_fight", false))):
		layer.close()
		return
	if layer.has_meta("stone"):
		var stone: Dictionary = layer.get_meta("stone")
		if DeepOddities.find_stone(me(), str(stone.get("id", ""))).is_empty():
			## Gone from the bag already (sold, traded, set by the bench): nothing left to do.
			layer.set_actions([ {"label": "Continue", "glyph": "check", "tone": DeepUi.ACCENT, "dismiss": true}])
		else:
			layer.set_actions(appraisal_actions(stone))

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_sync_ceremony()

func appraisal_actions(stone: Dictionary) -> Array:
	## Down the mine a stone just read goes in the bag, into an empty socket if there is one
	## it can go in (or in place of the set gem of its own skill), or onto the merchant's
	## scales if there is a merchant.
	var id: String = str(stone.get("id", ""))
	var unit: Dictionary = me()
	var known: Dictionary = stone.duplicate(true)
	known.appraised = true
	if not id.is_empty() and str(unit.get("twin", {}).get("stone", "")) == id:
		## Read, and a second of a gem already held: the rules refuse a sale or a socket until
		## the twin is settled, so the one way out is to put the ceremony down. The twin plate
		## (Keep, Toss, Fuse) stands the moment it is (`_sync_twin`).
		return [{"label": "Two of a kind: decide", "glyph": "gem", "tone": DeepUi.ACCENT, "caption": "Nobody carries two of one gem: keep, toss or fuse it next",
			"dismiss": true, "main": true}]
	var out: Array = []
	## What the bag's line promises: that it can be set later, or why it can't be.
	var bag_caption: String = "Set it from the bench any time"
	if DeepDescent.bench_open(run):
		var rail: Array = unit.get("rail", [])
		if DeepStone.is_slotless(known):
			## A Void gem rides a socket: the first with a gem in it, so it has something to
			## fire after, else the first that will take it.
			var host: int = -1
			for filled in [true, false]:
				for index in range(rail.size()):
					if host < 0 and (rail[index] is Dictionary or not filled) and DeepDescent.socket_refusal(unit, known, index).is_empty():
						host = index
			if host >= 0:
				var socket: int = host
				out.append({"label": "Ride socket %d" % (socket + 1), "glyph": "gem", "tone": DeepUi.INFO, "caption": "No socket used; it fires right after that socket's gem",
					"socket": socket, "call": func() -> void: command.emit({"kind": "socket", "stone_id": id, "index": socket})})
		else:
			for index in range(rail.size()):
				if rail[index] == null and DeepDescent.socket_refusal(unit, known, index).is_empty():
					var socket: int = index
					out.append({"label": "Set in socket %d" % (socket + 1), "glyph": "gem", "tone": DeepUi.GOOD, "caption": "Into the rail for the next fight",
						"socket": socket, "call": func() -> void: command.emit({"kind": "socket", "stone_id": id, "index": socket})})
					break
			if out.is_empty() and not rail.is_empty():
				## No empty socket takes it (most often the rail already holds its skill): it can
				## still take the place of that twin, and the bag's line says why it can't go in.
				var twin: int = -1
				for index in range(rail.size()):
					if twin < 0 and rail[index] is Dictionary and str(rail[index].get("skill", "")) == str(known.get("skill", "")) and DeepDescent.socket_refusal(unit, known, index).is_empty():
						twin = index
				if twin >= 0:
					## Named for the stone it replaces, with the two read side by side under it
					## (Appraisal.swap_lines), so a better copy of a set gem is weighed here.
					var socket: int = twin
					var kept: Dictionary = rail[twin]
					var skill_name: String = str(DeepStone.skill_of(kept).get("name", "stone"))
					out.append({"label": "Swap for your %s (socket %d)" % [skill_name, socket + 1], "glyph": "gem", "tone": DeepUi.GOOD,
						"caption": "Your %d ct %s goes in the bag" % [int(kept.get("carat", 1)), skill_name], "compare": {"found": known, "kept": kept},
						"socket": socket, "call": func() -> void: command.emit({"kind": "socket", "stone_id": id, "index": socket})})
				else:
					var reason: String = DeepDescent.rail_duplicate(unit, known)
					if reason.is_empty() and rail.has(null):
						reason = DeepDescent.socket_refusal(unit, known, rail.find(null))
					if not reason.is_empty():
						bag_caption = reason[0].to_upper() + reason.substr(1)
	out.append({"label": "Into the bag", "glyph": "bag", "tone": DeepUi.ACCENT, "caption": bag_caption, "dismiss": true})
	if DeepDescent.at_stall(run) and not DeepStone.is_fragile(known):
		out.append({"label": "Sell for %d pyrite" % DeepStone.sell_value(known), "glyph": "scales", "tone": DeepUi.ORE, "caption": "Half its worth, on the scales",
			"sound": "sell", "call": func() -> void: command.emit({"kind": "sell", "stone_id": id})})
	## Enter takes the first socket offered, or else the bag: never a swap, nor a sale.
	for action in out:
		if (action.has("socket") and not action.has("compare")) or bool(action.get("dismiss", false)):
			action.main = true
			break
	return out

# --- a find offered to the rail --------------------------------------------------------------------

func _offer_find(stone: Dictionary, elite: bool) -> bool:
	## A stone a fight gave up already read, held up over the room just above the dock with the
	## socket it can go in now beside the bag: one step from the floor to the rail, where empty
	## sockets used to wait while finds sat in the bag. The choices are the appraisal's
	## (`appraisal_actions`), so a gem of a skill already set offers the swap. It asks nothing of
	## the party: the way on stays open beside it, and walking on keeps the stone in the bag.
	## Goes up only when there is a socket to offer, and says whether it did.
	_close_find()
	if _headless or stone.is_empty() or not is_inside_tree() or bool(me().get("downed", false)):
		return false
	var id: String = str(stone.get("id", ""))
	if not me().get("haul", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == id):
		return false
	var actions: Array = appraisal_actions(stone).filter(func(a: Dictionary) -> bool: return a.has("socket"))
	if actions.is_empty():
		return false
	var skill: Dictionary = DeepStone.skill_of(stone)
	var tone: Color = DeepUi.color(DeepStone.color(stone))
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, 16, 3, 5))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.set_meta("stone", stone.duplicate(true))
	plate.set_meta("elite", elite)
	plate.set_meta("labels", actions.map(func(a: Dictionary) -> String: return str(a.label)))
	_body.add_child(plate)
	_find_plate = plate
	_find_id = id
	var box := DeepUi.vbox(plate, 12)
	var top := DeepUi.hbox(box, 16)
	var frame := DeepUi.center(top)
	frame.custom_minimum_size = Vector2(100, 100)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	StoneCard.marked_picture(frame, stone, 92)
	var words := DeepUi.vbox(top, 6)
	words.custom_minimum_size.x = 440
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head := DeepUi.hbox(words, 8)
	DeepUi.title(head, str(skill.get("name", stone.get("skill", ""))), 26, tone.lightened(0.3)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tags := DeepUi.hbox(head, 6)
	tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	StoneCard.rarity_tag(tags, str(skill.get("rarity", "COMMON")), 11, false)
	DeepUi.chip(tags, StoneCard.color_words(stone), tone, 11)
	DeepUi.spacer(head)
	DeepUi.label(head, "dropped by the elite, already read" if elite else "already read", 12, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var facts := DeepUi.hbox(words, 16)
	var cut: int = int(stone.get("cut", 0))
	DeepUi.stat(facts, "carat", "%d ct" % int(stone.get("carat", 1)), DeepUi.PAPER, 14)
	DeepUi.stat(facts, "cut", DeepContent.cut_name(cut), DeepUi.PAPER, 14)
	DeepUi.stat(facts, "clarity", DeepContent.clarity_name(int(stone.get("clarity", DeepContent.clear_index()))), DeepUi.PAPER, 14)
	var grade: Dictionary = DeepStone.grade(stone)
	DeepUi.stat(facts, "star", str(grade.name), DeepUi.tier_color(str(grade.tier)), 14)
	DeepUi.effect_text(words, DeepStone.text(stone), 14, DeepUi.PAPER, false, 440)
	## When it fires, at its own Cut: the pictograph and the words, as a gem's plate says it.
	var described: Dictionary = DeepPatterns.describe(skill.get("trigger", {"kind": "always"}), cut)
	var fires := DeepUi.hbox(words, 8)
	DiceIcons.build(fires, described, 15, DeepUi.MUTED)
	var fires_said := DeepUi.vbox(fires, 0)
	fires_said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.effect_text(fires_said, str(described.get("words", "")), 12, DeepUi.MUTED, false, 400)
	var buttons := DeepUi.hbox(box, 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for action in actions:
		var column := DeepUi.vbox(buttons, 4)
		var run_it: Callable = action.get("call", Callable())
		var socket: int = int(action.socket)
		var go := DeepUi.primary(column, str(action.get("glyph", "gem")), str(action.label), func() -> void:
			_run_dock.light_socket(socket, false)
			_close_find()
			if run_it.is_valid():
				run_it.call(), 16, action.get("tone", DeepUi.GOOD))
		DeepUi.ledger_primary(go, action.get("tone", DeepUi.GOOD))
		go.custom_minimum_size = Vector2(220, 44)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		## Enter sets it in the first socket offered; a swap for a set gem is never one keypress.
		if _find_main == null and action.get("compare", {}).is_empty():
			_find_main = go
		## The socket it would go in lights on the dock while the button is pointed at.
		go.mouse_entered.connect(func() -> void: _run_dock.light_socket(socket, true))
		go.mouse_exited.connect(func() -> void: _run_dock.light_socket(socket, false))
		var compare: Dictionary = action.get("compare", {})
		if not compare.is_empty():
			Appraisal.swap_lines(column, compare.get("found", {}), compare.get("kept", {}))
			DeepUi.label(column, str(action.get("caption", "")), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var keep := DeepUi.primary(DeepUi.vbox(buttons, 4), "bag", "Keep in bag", func() -> void:
		DeepAudio.play("ui_back", {"volume": 0.6})
		_close_find(), 16, DeepUi.ACCENT)
	DeepUi.ledger_primary(keep, DeepUi.ACCENT)
	keep.custom_minimum_size = Vector2(220, 44)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_place_find()
	DeepUi.pop_in(plate, 0.0, 0.92, 0.26)
	DeepAudio.reveal_stone(stone)
	return true

func _place_find() -> void:
	## Centred over the room, just above the dock (and the bag, when it is open).
	_place_over_dock(_twin_plate)
	_place_over_dock(_find_plate)

func _place_over_dock(plate: Control, again: bool = true) -> void:
	if plate == null or not is_instance_valid(plate):
		return
	var want: Vector2 = plate.get_combined_minimum_size()
	plate.size = want
	var floor_height: float = _run_dock.height() if _run_dock.visible else 0.0
	plate.position = Vector2((_body.size.x - want.x) * 0.5, maxf(12.0, _body.size.y - floor_height - want.y - 18.0)).round()
	## Built in the same frame as the screen, the body has no size yet and the plate would
	## stand cut off at the left edge: it is placed once more when the layout has run.
	if again and is_inside_tree():
		_place_over_dock.call_deferred(plate, false)

func _close_twin() -> void:
	if _twin_plate != null and is_instance_valid(_twin_plate):
		_twin_plate.queue_free()
	_twin_plate = null

func _sync_twin() -> void:
	## Nobody carries two of one gem (October 29, 2026): while a read stone of a skill the
	## player already holds waits in the bag, the plate that settles it stands over the room
	## until the twin is swapped for the one held, tossed, or fused into it for the
	## crucible's fee. The rules refuse everything else until it is.
	var pending: Dictionary = me().get("twin", {})
	if pending.is_empty() or _headless or not is_inside_tree():
		_close_twin()
		return
	var key: String = "%s:%s" % [str(pending.get("stone", "")), str(pending.get("other", ""))]
	if _twin_plate != null and is_instance_valid(_twin_plate) and str(_twin_plate.get_meta("key", "")) == key:
		return
	if not _hold.is_empty() or not _landing_view.is_empty() or _reading():
		## Not over something still being read: a held page, a landing's page (the well's
		## answer, whose prize the twin may be), the appraisal that read it or a close look.
		## It comes up when they are down: the pages through `show_state` and `_show_landing`,
		## the readings through `_process`. A plate still up here is for another pair.
		_close_twin()
		return
	_close_twin()
	_close_find()
	var stone: Dictionary = DeepOddities.find_stone(me(), str(pending.get("stone", "")))
	var other: Dictionary = DeepOddities.find_stone(me(), str(pending.get("other", "")))
	if stone.is_empty() or other.is_empty():
		return
	var skill: Dictionary = DeepStone.skill_of(stone)
	var tone: Color = DeepUi.color(DeepStone.color(stone))
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, 16, 3, 5))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.set_meta("key", key)
	_body.add_child(plate)
	_twin_plate = plate
	var box := DeepUi.vbox(plate, 12)
	var head := DeepUi.hbox(box, 8)
	DeepUi.title(head, "Two of a kind: %s" % str(skill.get("name", stone.get("skill", ""))), 24, tone.lightened(0.3)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.spacer(head)
	DeepUi.label(head, "nobody carries two of one gem", 12, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## The two side by side: the one found, and the one already held, where it is.
	var pair := DeepUi.hbox(box, 24)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [[stone, "Found"], [other, "Held" + _twin_where(other)]]:
		var column := DeepUi.vbox(pair, 4)
		DeepUi.label(column, str(entry[1]), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var frame := DeepUi.center(column)
		frame.custom_minimum_size = Vector2(92, 92)
		StoneCard.marked_picture(frame, entry[0], 84)
		var facts := DeepUi.hbox(column, 10)
		facts.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.stat(facts, "carat", "%d ct" % int(entry[0].get("carat", 1)), DeepUi.PAPER, 13)
		DeepUi.stat(facts, "cut", DeepContent.cut_name(int(entry[0].get("cut", 0))), DeepUi.PAPER, 13)
		DeepUi.stat(facts, "clarity", DeepContent.clarity_name(int(entry[0].get("clarity", DeepContent.clear_index()))), DeepUi.PAPER, 13)
		var grade: Dictionary = DeepStone.grade(entry[0])
		DeepUi.stat(facts, "star", str(grade.name), DeepUi.tier_color(str(grade.tier)), 13)
	var compare := DeepUi.vbox(pair, 4)
	compare.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Appraisal.swap_lines(compare, stone, other)
	## What the fire would make of them, as one line under the pair (the owner, November 5,
	## 2026: a range, "Carat 8-10", not the chance of each weight): the weights it can come
	## out at, and the Cut and Clarity it would have.
	_fuse_line(box, stone, other)
	var fee: int = DeepOddities.fuse_cost()
	var buttons := DeepUi.hbox(box, 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var choices: Array = [
		["swap", "reroll", "Keep the new one", "The one you held is gone; the new one takes its place.", DeepUi.GOOD],
		["toss", "cross_out", "Toss the new one", "The one you held stays as it is.", DeepUi.ACCENT],
		["fuse", "flame", "Fuse for %d pyrite" % fee, "The held one takes the new one in, where it stands.", DeepUi.ORE]]
	for choice in choices:
		var column := DeepUi.vbox(buttons, 4)
		var pick: String = str(choice[0])
		var go := DeepUi.primary(column, str(choice[1]), str(choice[2]), func() -> void:
			DeepAudio.play("dice_lock", {"volume": 0.7})
			command.emit({"kind": "twin", "choice": pick}), 15, choice[4])
		DeepUi.ledger_primary(go, choice[4])
		go.custom_minimum_size = Vector2(210, 44)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if pick == "fuse" and int(me().get("ore", 0)) < fee:
			go.disabled = true
			go.tooltip_text = "You have %d pyrite." % int(me().get("ore", 0))
		var caption := DeepUi.label(column, str(choice[3]), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size.x = 210
	_place_over_dock(plate)
	DeepUi.pop_in(plate, 0.0, 0.92, 0.26)

func _twin_where(other: Dictionary) -> String:
	## Where the held twin stands: in a socket, riding one, or in the bag.
	var unit: Dictionary = me()
	for index in range(unit.get("rail", []).size()):
		if unit.rail[index] is Dictionary and str(unit.rail[index].get("id", "")) == str(other.get("id", "")):
			return ", socket %d" % (index + 1)
	var place: Dictionary = DeepStone.rider_place(unit, str(other.get("id", "")))
	if not place.is_empty():
		return ", riding socket %d" % (int(place.get("socket", 0)) + 1)
	return ", in the bag"

static func fuse_odds(heavy: int, light: int) -> Array:
	## The chances the fire adds nothing, one carat or two to the heavier stone, [none, one,
	## two], as `DeepOddities.fuse_gain` draws them: r the lighter over the heavier, two carats
	## with chance r^4 / 2, one with r^2 less that, nothing with the rest.
	if heavy <= 0 or light <= 0:
		return [1.0, 0.0, 0.0]
	var ratio: float = clampf(float(light) / float(heavy), 0.0, 1.0)
	var two: float = 0.5 * pow(ratio, 4.0)
	var one: float = ratio * ratio - two
	return [1.0 - ratio * ratio, one, two]

static func fuse_range(heavy: int, light: int) -> Array:
	## The weights the fire can give the pair, [lightest, heaviest]: the heavier stone plus every
	## gain `fuse_odds` gives a chance above nothing, held to the carat cap. Two equal stones
	## always gain (9-10 from two 8s); any lighter one can still, rarely, give two.
	var odds: Array = fuse_odds(heavy, light)
	var gains: Array = []
	for gain in range(odds.size()):
		if float(odds[gain]) > 0.0:
			gains.append(gain)
	if gains.is_empty():
		gains = [0]
	var top: int = DeepStone.carat_max()
	return [clampi(maxi(1, heavy) + int(gains.min()), 1, top), clampi(maxi(1, heavy) + int(gains.max()), 1, top)]

static func carat_range_words(span: Array) -> String:
	## "Carat 8-10" with an en dash, or "Carat 8" when the fire can only give the one weight.
	if int(span[0]) == int(span[1]):
		return "Carat %d" % int(span[0])
	return "Carat %d–%d" % [int(span[0]), int(span[1])]

func _fuse_line(parent: Node, stone: Dictionary, other: Dictionary) -> HBoxContainer:
	## What fusing the pair would make, in one line under it, marked the way the facts above it
	## are (see `DeepOddities.fuse_stats`): the weights it can come out at, the Cut averaged
	## down, the Clarity drawn between Included and Intricate, and a Zoning of the lost color
	## when the fire would freeze one in.
	var heavy: int = maxi(int(stone.get("carat", 1)), int(other.get("carat", 1)))
	var light: int = mini(int(stone.get("carat", 1)), int(other.get("carat", 1)))
	var cut: int = clampi(int(floor(float(int(stone.get("cut", 0)) + int(other.get("cut", 0))) / 2.0)), 0, DeepPatterns.STEPS - 1)
	var row := DeepUi.hbox(parent, 8)
	row.name = "FuseRange"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.label(row, "If fused", 12, DeepUi.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var parts: Array = [["carat", carat_range_words(fuse_range(heavy, light))], ["cut", "Cut: %s" % DeepContent.cut_name(cut)],
		["clarity", "Clarity: %s to %s" % [DeepContent.clarity_name(DeepContent.clarity_index("INCLUDED")), DeepContent.clarity_name(DeepContent.clarity_index("INTRICATE"))]]]
	## The sim compares the two skills' own colors, and freezes the lost one in only where an
	## inclusion stands for it.
	var kept_color: String = str(DeepContent.skill(str(other.get("skill", ""))).get("color", ""))
	var lost_color: String = str(DeepContent.skill(str(stone.get("skill", ""))).get("color", ""))
	if not lost_color.is_empty() and lost_color != kept_color and lost_color != DeepContent.OPAL and kept_color != DeepContent.OPAL:
		var zoning: String = DeepOddities.zoning_key(lost_color)
		if not zoning.is_empty():
			var kind: String = str(DeepContent.inclusion(zoning).get("class", ""))
			parts.append([str(StoneCard.INCLUSION_GLYPHS.get(kind, "spark")), "Zoning: %s" % str(DeepContent.color(lost_color).get("name", lost_color.capitalize()))])
	for index in range(parts.size()):
		if index > 0:
			DeepUi.label(row, "·", 13, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		DeepUi.stat(row, str(parts[index][0]), str(parts[index][1]), DeepUi.PAPER, 13)
	return row

func _fusion_rite(held: Dictionary, fed: Dictionary, fused: Dictionary, paid: int) -> void:
	## The twin fused (the owner, November 5, 2026): the two stones circle into each other over
	## the room and flash, and the fused stone is revealed with its weight rolling up from the
	## heavier of the two to what the fire made (view/gems/geode.gd `twin`). A layer over the
	## whole window like an appraisal's: the run goes on under it, and `_sync_ceremony` puts
	## it away if a fight begins or the run ends meanwhile.
	if _headless or held.is_empty() or fused.is_empty():
		return
	var Geode: Script = load("res://view/gems/geode.gd")
	var layer: CanvasLayer = Geode.twin([held, fed], fused, {"owned": held, "paid": paid,
		"from_carat": maxi(int(held.get("carat", 1)), int(fed.get("carat", 1))),
		"actions": [{"label": "Carry on", "glyph": "check", "tone": DeepUi.ACCENT, "caption": "The fused stone stays where the held one was.", "dismiss": true}]})
	if layer != null:
		layer.set_meta("run_id", str(run.get("run_id", "")))

func _sync_find() -> void:
	## The offer stands while its stone is still loose in the bag and the rail can be worked on
	## (no fight, nobody down); a socket filled meanwhile some other way redraws its choices.
	if _find_plate == null:
		return
	if not is_instance_valid(_find_plate) or not DeepDescent.bench_open(run) or bool(me().get("downed", false)) \
			or not me().get("haul", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == _find_id):
		_close_find()
		return
	var stone: Dictionary = _find_plate.get_meta("stone", {})
	var labels: Array = appraisal_actions(stone).filter(func(a: Dictionary) -> bool: return a.has("socket")).map(func(a: Dictionary) -> String: return str(a.label))
	if labels != _find_plate.get_meta("labels", []):
		_offer_find(stone, bool(_find_plate.get_meta("elite", false)))

func _close_find() -> void:
	if _find_plate != null and is_instance_valid(_find_plate):
		_find_plate.queue_free()
	_find_plate = null
	_find_main = null
	_find_id = ""

func conquered(mine_key: String, unlocked: Array, purse: int, profile: Dictionary = {}) -> void:
	## This mine's final boss has just fallen and what it opened is already the lapidary's (see
	## app._note_conquest). Whoever comes to the workshop is met first, then any Hazard tier
	## that opened, and last the beaten mine itself, with the hall's choice: home, or deeper.
	## The profile is what the last sheet reads the map, the bestiary and the roster from.
	var run_id: String = str(run.get("run_id", ""))
	var opened: String = ""
	for entry in unlocked:
		if entry.has("character"):
			_news.append({"run_id": run_id, "kind": "character", "key": str(entry.character)})
		if entry.has("mine"):
			opened = str(entry.mine)
	for entry in unlocked:
		if entry.has("tier"):
			_news.append({"run_id": run_id, "kind": "tier", "tier": int(entry.tier)})
	_news.append({"run_id": run_id, "kind": "conquest", "mine": mine_key, "opened": opened, "unlocked": unlocked, "purse": purse, "profile": profile})
	## And said again on the over page's "This run" line.
	if not opened.is_empty() and not _opened.has(opened):
		_opened.append(opened)

func _tell_news() -> void:
	## One sheet at a time, once the room is quiet: no fight, no hoard still to choose from,
	## no page held up and nothing already open over the room.
	if str(_news[0].get("run_id", "")) != str(run.get("run_id", "")):
		_news.clear()
		return
	var phase: String = str(run.get("phase", ""))
	if phase in ["hoard", "salvage"] or DeepDescent.in_battle(run) or not _hold.is_empty() or _walking or _reading() or not is_visible_in_tree():
		return
	var item: Dictionary = _news.pop_front()
	match str(item.get("kind", "")):
		"character":
			DeepAudio.play("unlock")
			Inspector.lapidary(str(item.key))
		"tier":
			var tier: int = int(item.tier)
			var adds: Dictionary = DeepContent.hazard_tier(tier)
			DeepAudio.play("unlock")
			Inspector.announce("Hazard %d beaten" % (tier - 1) if tier > 1 else "Hazard 1 unlocked",
				"Hazard %d is open: every hazard so far, and one more.\n\n%s: %s\n\nEvery tier keeps its own map, starting from the Quarry, and gives up heavier stones." % [tier, str(adds.get("name", "")), str(adds.get("text", ""))],
				"skull", DeepUi.BAD, {"subtitle": "Hazard %d is open" % tier if tier > 1 else "You reached the Rift"})
		"conquest":
			## Gone from the hall already (the cage, or the party went on): nothing to choose.
			if phase == "landing" and DeepDescent.in_boss_hall(run):
				_conquest_item = item
				_conquest_sheet = _show_conquest(item)
				_conquest_shown = true
				_sync_party_asks()

func _show_conquest(item: Dictionary) -> CanvasLayer:
	## The mine is beaten: what that opened, the map of the mines with the mine below laid out
	## beside it (Inspector.conquest), and the two ways out of the boss's hall under the sheet.
	var mine_key: String = str(item.get("mine", ""))
	var opened: String = str(item.get("opened", ""))
	var next_key: String = DeepDescent.next_mine(run)
	var tier: int = DeepDescent.hazard_tier(run)
	var unit: Dictionary = me()
	var downed: bool = bool(unit.get("downed", false))
	var profile: Dictionary = item.get("profile", {})
	if not opened.is_empty():
		DeepAudio.play("unlock")
	var fare: int = DeepDescent.lift_cost(run)
	## Pooled the way the winch counts it: whoever is standing and still on the line.
	var pooled: int = 0
	for other in DeepDescent.living(run):
		pooled += int(other.get("ore", 0))
	var afford: bool = pooled >= fare
	var notes: Array = []
	if not afford:
		notes.append("The winch wants %d pyrite and %s %d." % [fare, "the party has" if run.get("players", []).size() > 1 else "you have", pooled])
	if downed:
		notes.append("You are down: the party decides, and you go with it.")
	elif run.get("players", []).size() > 1:
		notes.append("The party goes where most of it points.")
	## A creature of the mine below counts as met if the lapidary has met it, or the party has
	## on this run (a guest can have been down there in someone else's).
	var met: Array = []
	for key in DeepBestiary.in_mine(next_key) if not next_key.is_empty() else []:
		if DeepBestiary.known(profile, str(key)) or int(run.get("bestiary", {}).get(str(key), {}).get("met", 0)) > 0:
			met.append(str(key))
	var joined: Array = []
	for key in profile.get("characters", {}):
		if bool(profile.characters[key].get("unlocked", false)):
			joined.append(str(key))
	var boss: String = str(DeepContent.creature(DeepDescent.warden_key(run, int(run.get("depth", 0)))).get("name", "The boss"))
	var view: Dictionary = {"mine": mine_key, "next": next_key, "tier": tier, "depth": int(run.get("depth", 0)), "boss": boss, "opened": opened,
		"unlocked": item.get("unlocked", []), "purse": int(item.get("purse", 0)), "fare": fare, "met": met, "joined": joined,
		"records": DeepProfile.mine_records(profile, tier) if not profile.is_empty() else {}}
	## Chosen from a sheet that may have stood a while: only if the party is still in the hall.
	var ride := func() -> void:
		if str(run.get("phase", "")) == "landing" and DeepDescent.in_boss_hall(run):
			DeepAudio.play("lift")
			command.emit({"kind": "choose", "choice": "lift"})
	var deeper := func() -> void:
		if str(run.get("phase", "")) == "landing" and DeepDescent.in_boss_hall(run):
			_choose_mouth(0)
	## No "not yet": Esc or a click outside puts the sheet away, and the hall's cage and mouth
	## still choose the same two things.
	var actions: Array = [ {"label": "Return home", "glyph": "lift", "tone": DeepUi.GOOD, "call": ride, "price": fare, "price_glyph": "ore",
		"disabled": downed or not afford or str(unit.get("choice", "")) == "lift"}]
	if not next_key.is_empty():
		actions.append({"label": "Dig deeper", "glyph": "descend", "tone": DeepUi.ACCENT, "call": deeper,
			"disabled": downed or str(unit.get("choice", "")) == "descend"})
	return Inspector.conquest(view, actions, " ".join(notes))

func _later(seconds: float, callback: Callable) -> void:
	if _headless or not is_inside_tree():
		callback.call()
		return
	get_tree().create_timer(seconds).timeout.connect(callback)

func toast(text: String, color: Color, glyph: String = "", hold: float = 2.8) -> void:
	toast_parts([text], color, glyph, hold)

func toast_parts(parts: Array, color: Color, glyph: String = "", hold: float = 2.8) -> void:
	## A toast told in pieces: a String is said as words, a stone as its skill name with its
	## grade as marks beside it, the way every narrow card says a stone.
	## Three at most; the oldest makes room. `hold` is how long it stays before it fades.
	DeepAudio.play("toast_bad" if color == DeepUi.BAD else "toast", {"volume": 0.7})
	while _toasts.get_child_count() >= 3:
		var oldest: Node = _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var box := PanelContainer.new()
	var style := DeepUi.facet_ends(box, DeepUi.raised(Color(0.04, 0.05, 0.07, 0.94), Color(color, 0.6), 18, 8, 0.5))
	style.content_margin_left = 14
	style.content_margin_right = 16
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(box)
	var row := DeepUi.hbox(box, 8)
	if not glyph.is_empty():
		DeepUi.icon(row, glyph, 18, color)
	for part in parts:
		if part is Dictionary:
			var appraised: bool = bool(part.get("appraised", false))
			DeepUi.label(row, DeepUi.skill_name(part) if appraised else DeepStone.raw_name(part), 15, color)
			StoneCard.grade_marks(row, part, 12, color)
		elif not str(part).is_empty():
			DeepUi.label(row, str(part), 15, color)
	## A long one wraps inside the screen rather than running past its edges.
	DeepUi.cap_row(row, DeepUi.toast_width())
	## Over the room, never over the bar along the bottom (the fight's or the run's).
	var bottom: float = 28.0
	if _battle.visible and _battle._dock != null:
		bottom = maxf(bottom, _battle.size.y - _battle._dock.position.y + 14.0)
	elif _run_dock.visible:
		bottom = maxf(bottom, _run_dock.height() + 14.0)
	_toasts.offset_bottom = - bottom
	_toasts.offset_top = _toasts.offset_bottom - _toasts.get_combined_minimum_size().y
	DeepUi.pop_in(box, 0.0, 0.8)
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 0.0, 0.6).set_delay(hold)
	tween.tween_callback(box.queue_free)

# --- the mine ----------------------------------------------------------------------------------
##
## Where the party stands, as a room on the stage. The state already says it all: the path
## walked, the chamber, the landing and whether its Warden is dead. When the room changes the
## stage walks there through the mouth the party chose (the last ways offered, matched to the
## chamber the path now ends in); when there was no way to walk (a run begun, a party joined
## mid-run) it simply stands the party in the room.

func _place_of(state: Dictionary) -> Dictionary:
	var phase: String = str(state.get("phase", ""))
	var depth: int = int(state.get("depth", 0))
	var mine: String = str(state.get("mine", ""))
	var path: Array = state.get("path", [])
	var last: Dictionary = path.back() if not path.is_empty() else {}
	var landing: Dictionary = state.get("landing", {})
	var cleared: bool = int(landing.get("depth", -1)) == depth and bool(landing.get("cleared", false))
	var kind: String = ""
	match phase:
		"grubstake":
			kind = "head"
		"chamber":
			kind = "warden" if str(state.get("chamber", {}).get("kind", "")) == "warden" else str(last.get("kind", state.get("chamber", {}).get("kind", "fight")))
		"tunnels":
			kind = "head" if path.is_empty() or depth == 0 else ("warden" if cleared else str(last.get("kind", "fight")))
		"landing":
			kind = "warden" if cleared else "landing"
		"hoard":
			kind = "warden"
		_:
			return {}
	if kind == "head":
		depth = 0
	## How many ways on the room has: the chart knows before anyone is offered them. Where
	## nobody has been offered them yet (the shaft head, a landing, a Warden's hall) they are
	## the chart's next floor; and on a day of One Road there is only ever the one.
	var fallback: int = 1 if DeepDescent.has_mod(state, "ONE_ROAD") else 2
	var ahead: Array = DeepDescent.row_of(state.get("map", {}), depth + 1)
	var exits: int = fallback
	if phase == "tunnels":
		exits = state.get("offers", []).size()
	elif kind == "landing":
		exits = 1 if bool(landing.get("warden_next", false)) and not cleared else (ahead.size() if not ahead.is_empty() else fallback)
	elif kind == "warden" and DeepDescent.run_is_boss(state, depth):
		exits = 1
	elif kind in ["warden", "head"]:
		exits = ahead.size() if not ahead.is_empty() else fallback
	else:
		var node: Dictionary = state.get("map", {}).get("nodes", {}).get(str(last.get("id", "")), {})
		exits = node.get("next", []).size() if not node.is_empty() else fallback
	## The shaft falls a little with every depth, except where a stretch runs level, and a
	## landing's way to its Warden's hall never does.
	var key: String = "%s|%d|%s" % [mine, depth, kind]
	var level: bool = absi(("%s|%d" % [mine, depth]).hash()) % 6 == 0
	var drop: float = 0.0 if (kind == "landing" and exits == 1) or level else 2.5
	## The final boss's hall is the one hall with a cage sunk into it: the way home after it.
	var cage: bool = kind == "warden" and DeepDescent.run_is_boss(state, depth)
	return {"key": key, "mine": mine, "depth": depth, "kind": kind, "exits": clampi(exits, 1, 3), "drop": drop, "seal": DeepDescent.in_battle(state), "cage": cage,
		"party": state.get("players", []).size(),
		"phase": Biomes.run_phase(state, maxi(1, depth))}

func _sync_stage() -> void:
	if _headless:
		return
	var place: Dictionary = _place_of(run)
	if place.is_empty():
		return
	var tunnels: bool = str(run.get("phase", "")) == "tunnels"
	if _stage.has_room() and str(_stage.place.get("key", "")) == str(place.key):
		if tunnels and run.get("offers", []).size() != _stage.room.exits.size() and not _stage.walking():
			## The room was built for a different number of ways on than it has: build it again.
			_stage.show_room(place, true)
		if tunnels:
			_last_offers = run.offers.duplicate(true)
		return
	if _walk_pending == str(place.get("key", "")):
		## The walk there is already waiting on the coin toss being read: nothing to start again.
		if tunnels:
			_last_offers = run.offers.duplicate(true)
		return
	if not _walk_pending.is_empty():
		## The party is somewhere else before a held walk began: that walk is dropped.
		_walk_pending = ""
		_walking = false
	if _stage.walking():
		## The party moved on again before this walk was over: get there at once, and on.
		_arrive_quietly = true
		_stage.hurry()
		_arrive_quietly = false
	var index: int = -1
	var path: Array = run.get("path", [])
	var target: String = str(path.back().get("id", "")) if not path.is_empty() else ""
	for i in range(_last_offers.size()):
		if str(_last_offers[i].get("id", "")) == target and not target.is_empty():
			index = i
	if index < 0 and str(_stage.place.get("kind", "")) == "landing" and str(place.kind) == "warden" and int(_stage.place.get("depth", -1)) == int(place.depth):
		index = 0
	## Out of a beaten boss's hall and on into the mine below: down its one mouth, walked, to
	## the new mine's head, where the party chooses its own way on.
	var pushed_on: bool = index < 0 and bool(_stage.place.get("cage", false)) and str(place.kind) == "head" and str(_stage.place.get("mine", "")) != str(place.mine)
	if pushed_on:
		index = 0
	_last_offers = []
	if index >= 0 and _stage.has_room():
		_walking = true
		_descend_via = -1
		_pinned = ""
		## The bag an altar opened closes again as the party walks on from it.
		if not _stall_opened.is_empty() and _stall_opened == str(_stage.place.get("key", "")):
			_run_dock.set_drawer(false)
		_chip_index = -1
		## A fight waits down this tunnel: its creatures are read off the disk on the way.
		if DeepDescent.in_battle(run):
			CrystalCreature.preload_scenes(DeepDescent.battle(run).get("enemies", []))
		var go := func() -> void:
			_stage.walk(place, index, _arrived, _depth_title.bind(int(place.depth), str(place.kind) if str(place.kind) != "head" or pushed_on else "fight"))
		## A coin toss that chose this way is read before the party walks off on it, the way
		## the lift waits for one (`show_state`, "over"). The walk is held, with nothing else
		## moving meanwhile, and dropped if the run is somewhere else by the time it is due.
		var wait: float = float(_toss_until - Time.get_ticks_msec()) / 1000.0 - 0.8
		if wait > 0.0:
			var key: String = str(place.get("key", ""))
			_walk_pending = key
			_later(wait, func() -> void:
				if _walk_pending != key:
					return
				_walk_pending = ""
				if _stage.walking() or not _walking:
					return
				if _stage.has_room() and str(_place_of(run).get("key", "")) == key:
					go.call()
				else:
					## The run is somewhere else now (over, most likely): the held walk is
					## dropped and the screen catches up with where the party is.
					_walking = false
					show_state(run))
		else:
			go.call()
	else:
		_stage.show_room(place)
		if DeepDescent.in_battle(run):
			_stage.seal(false)
	if tunnels:
		_last_offers = run.offers.duplicate(true)

func _arrived() -> void:
	## In the next room. A fight's ways on come down in a rockfall as the creatures rise.
	_walking = false
	if _arrive_quietly:
		return
	if DeepDescent.in_battle(run):
		_stage.seal(true)
	show_state(run)

# --- the vein ------------------------------------------------------------------------------------
##
## The vein is an outcrop in the room, six spots in it. Point at one to see what it gives
## away; click to put the pick in. Every strike, the party's own or an ally's, is played on
## the rock as it arrives, and what came out flies to whoever found it. When the rock is spent
## the finds are let land before the way on opens, and then the rock sinks away.

## Said in luck, not grade: Fine is a grade, and a bright spot near the surface still
## gives a Rough stone more often than not.
const VEIN_WORDS: Dictionary = {"rich": ["A rich seam", "A stone with real luck in it, all but loose."], "bright": ["Something bright", "A stone with some luck in it."],
	"glint": ["A glint", "A stone."], "dull": ["Dull rock", "Pyrite, or nothing but dust."]}
## The color of a motherlode's rich seams, wherever the screen names one.
const RICH_TONE := Color("fff1a6")

static func _swings_band(glint: String) -> String:
	## How many swings a spot of this kind takes to come out ("2-3 swings"), read off the
	## sim's own hardness bands: "a stone" alone read as one swing, and a glint takes two or three.
	var band: Array = DeepDescent.VEIN_HARDNESS.get(glint, [1, 1])
	var low: int = int(band[0])
	var high: int = int(band[1])
	return DeepUi.plural(low, "swing") if low == high else "%d-%d swings" % [low, high]

func _seat_color(unit_id: String) -> Color:
	var unit: Dictionary = DeepDescent.player(run, unit_id)
	return ShaftMap.SEATS[int(unit.get("seat", 0)) % ShaftMap.SEATS.size()]

func _show_vein() -> void:
	## The rock is struck as long as the arm holds out. Every swing costs a little more than
	## the last, and what is worth having is buried deeper than what is not, so the whole
	## business is a running question: one more, or walk on?
	var vein: Dictionary = run.chamber.get("vein", {})
	var hazard: bool = bool(vein.get("hazard", false))
	var motherlode: bool = str(run.chamber.get("kind", "")) == "motherlode"
	var spots: Array = vein.get("spots", [])
	var unit: Dictionary = me()
	var mining: bool = bool(unit.get("mining", false))
	var swings: int = int(unit.get("strikes", 0))
	var cost: int = DeepDescent.swing_cost(run, unit)
	var finders: Dictionary = {}
	for at in range(spots.size()):
		if not str(spots[at].get("taken", "")).is_empty():
			finders[at] = _seat_color(str(spots[at].taken))
	var face: Node3D = _stage.vein(spots, hazard, finders)
	## A rock still pointed at when the room redraws (after a swing) keeps its new price on the ring.
	var aimed: int = 0
	if face != null:
		for at in range(spots.size()):
			var spot: Dictionary = spots[at]
			var place: int = at
			var id: String = "spot:%d" % int(spot.index)
			if not _stage.has_pick(id):
				var holder: Node3D = face.spot_node(place)
				_stage.add_pick(id, holder, Vector3(0.6, 0.55, 0.45), {"hover": func(on: bool) -> void:
					if is_instance_valid(face):
						face.set_hover(place if on else -1)
					## The swing's cost, hatched red on the health ring while the rock is pointed at.
					var mine: Dictionary = me()
					var price: int = DeepDescent.swing_cost(run, mine)
					var live: bool = on and bool(mine.get("mining", false)) and not _strike_pending and int(mine.get("hp", 0)) > price
					_aim_hp(price if live else 0)})
			var open: bool = mining and str(spot.get("taken", "")).is_empty() and not _strike_pending and int(unit.get("hp", 0)) > cost
			_stage.enable_pick(id, open)
			face.set_open(place, open)
			if id == _chip_pick:
				aimed = cost if open else 0
	_aim_hp(aimed)
	_crossroads.visible = true
	_set_cross_mark("gem" if motherlode else "pick", DeepUi.CHAMBER_colorS.get("vein", DeepUi.ACCENT))
	_cross_title.text = "A motherlode" if motherlode else ("The vug" if hazard else "A vein")
	if mining:
		_cross_sub.text = "Swing as often as you like. The next swing costs %s." % ("nothing" if cost <= 0 else "%d health" % cost)
		if int(unit.get("hp", 0)) <= cost:
			_cross_sub.text = "Another swing would finish you. Put the pick down."
	else:
		_cross_sub.text = "You are down, and cannot swing a pick until the next landing." if bool(unit.get("downed", false)) else "You put the pick down."
	DeepUi.clear(_cross_hint)
	var legend := PanelContainer.new()
	legend.add_theme_stylebox_override("panel", DeepUi.facet_ends(legend, DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.LINE, 14, 8, 0.4)))
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_hint.add_child(legend)
	var row := DeepUi.hbox(legend, 18)
	## Walking on is the room's way out, a key in its corner as an oddity's Leave it is (the
	## owner, November 9, 2026): in the middle it stood over the rock it was struck at.
	if mining:
		_main(_way_out("Put the pick down", func() -> void:
			command.emit({"kind": "stop_mining"}), false, "Leave the rest of the rock where it is and take the way on."))
	else:
		_drop_way_out()
	DeepUi.stat(row, "pick", "%s so far" % DeepUi.plural(swings, "swing"), DeepUi.ACCENT, 12, "Every few swings the next one costs another point of health.")
	DeepUi.stat(row, "heart", ("next swing free" if cost <= 0 else "next swing: %d HP" % cost), DeepUi.BAD if cost > 0 else DeepUi.GOOD, 12)
	if motherlode:
		DeepUi.stat(row, "gem", "rich: real luck, all but loose", RICH_TONE, 12, "The motherlode's own seams, for anyone's pick: a stone with real luck in it, a swing or two from out.")
	DeepUi.stat(row, "spark", "bright: some luck, %s" % _swings_band("bright"), Color("ffcf5a"), 12, "A stone with some luck in it: heavier and better cut, on the whole, than a glint's.")
	DeepUi.stat(row, "spark", "glint: a stone, %s" % _swings_band("glint"), DeepUi.INFO, 12)
	DeepUi.stat(row, "ore", "dull: pyrite or dust", DeepUi.MUTED, 12)
	if hazard:
		DeepUi.stat(row, "skull", "bad air: %d HP on top of every swing" % DeepDescent.VUG_HP, DeepUi.BAD, 12)
	_fill_chip()

func _rock_place(global_index: int) -> int:
	## Where a spot stands on the face of the rock, or -1 when it is not on it.
	var vein: Dictionary = run.get("chamber", {}).get("vein", _last_chamber.get("vein", {}))
	var spots: Array = vein.get("spots", [])
	for at in range(spots.size()):
		if int(spots[at].get("index", -1)) == global_index:
			return at
	return -1

func _vein_struck(event: Dictionary) -> void:
	var unit_id: String = str(event.get("unit", ""))
	var mine: bool = unit_id == local_id
	var spot_id: int = int(event.get("spot", -1))
	var index: int = _rock_place(spot_id)
	var result: Dictionary = event.get("result", {})
	var hazard: bool = bool(_last_chamber.get("vein", {}).get("hazard", false))
	if mine:
		_strike_pending = false
		_strike_token += 1
	if index < 0:
		## A spot this screen has no rock for: nothing to play on the face.
		DeepAudio.play("pick_strike", {"gap": 0.0, "volume": 0.5})
		if bool(event.get("finished", false)):
			_hold_page("vein", {"stage": "flight"})
			_later(0.8, _after_vein.bind(int(_hold.token)))
		else:
			show_state(run)
		return
	if not bool(event.get("through", true)):
		## The pick bit and the rock held. Nothing comes out of it; the spot stays open.
		if not _headless:
			_stage.vein_strike(index, _seat_color(unit_id), mine, hazard, false)
			if mine:
				var left: int = int(event.get("hardness", 1)) - int(event.get("struck", 0))
				## As loud as a find and held as long again: a swing that brings nothing out has
				## still bought something, and a faint grey word gone in a second read as a miss.
				var said: String = "The rock holds · 1 more" if left <= 1 else "Deep in the rock"
				var spot_at: Vector2 = _stage.pick_rect("spot:%d" % spot_id).get_center()
				if int(event.get("hp_cost", 0)) > 0:
					DeepUi.float_text(self, spot_at + Vector2(0, -28), "-%d" % int(event.hp_cost), DeepUi.BAD, 18, 55.0, 1.0)
				DeepUi.float_text(self, spot_at, said, DeepUi.CHAMBER_colorS.get("vein", DeepUi.ORE), 20, 36.0, 2.0)
		else:
			DeepAudio.play("pick_strike", {"gap": 0.0})
		show_state(run)
		return
	var landed: float = 0.0
	if _headless:
		DeepAudio.play("pick_strike", {"gap": 0.0})
	else:
		var at: Vector3 = _stage.vein_strike(index, _seat_color(unit_id), mine, hazard)
		var kind: String = str(result.get("kind", ""))
		var arrived: Callable = Callable()
		if mine and kind in ["ore", "stone"]:
			## The count on the strip waits for the find to reach it.
			var key: String = "ore" if kind == "ore" else "haul"
			if not _strip_hold.has(key) and _counts.has(key):
				_strip_hold[key] = _counts[key]
			arrived = _release_count.bind(key)
		var finder: String = ""
		for who in run.get("players", []):
			if str(who.get("id", "")) == unit_id:
				finder = str(who.get("name", ""))
		landed = _stage.throw_find(result, at, _pill_centre("ore"), _pill_centre("bag"), arrived, mine, 0.17 if mine else 0.0, finder)
		_finds_until = maxi(_finds_until, Time.get_ticks_msec() + int(landed * 1000.0))
		if mine:
			var words: String = ""
			match kind:
				"stone": words = DeepStone.raw_name(result.get("stone", {}))
				"ore": words = "+%d pyrite" % int(result.get("ore", 0))
				_: words = "nothing but dust"
			var chip_at: Vector2 = _stage.to_screen(at) + _stage.global_position - global_position
			DeepUi.float_text(self, chip_at, words, DeepUi.ORE if kind == "ore" else DeepUi.PAPER, 20, 60.0, 1.4)
	if bool(event.get("finished", false)):
		## The rock is spent. Let what came out of it land before the way on opens: every find,
		## not just this strike's, since a stone from an earlier swing may still be in the air.
		_hold_page("vein", {"stage": "flight"})
		var still: float = maxf(landed, float(_finds_until - Time.get_ticks_msec()) / 1000.0)
		_later(still + 0.7, _after_vein.bind(int(_hold.token)))

func _after_vein(token: int) -> void:
	if _hold.is_empty() or int(_hold.get("token", -1)) != token:
		return
	_hold = {}
	_strip_hold = {}
	_sync_strip()
	show_state(run)

func _aim_hp(cost: int) -> void:
	## Health a pointed-at click would take, hatched red on the dock's ring (0 clears it).
	if _run_dock != null and is_instance_valid(_run_dock):
		_run_dock.preview_hp(cost)

func _hover_pick(id: String) -> void:
	## A pinned chip stays up while the pointer wanders.
	if not _pinned.is_empty():
		return
	_chip_pick = id
	if not id.is_empty():
		_chip_index = -1
	_fill_chip()

func _pin(id: String) -> void:
	_pinned = "" if _pinned == id else id
	_chip_pick = _pinned
	## The cage's card open is standing at the cage, for the party to see.
	if str(run.get("phase", "")) == "landing" and (_pinned == "hall:up" or _station_sent == "up"):
		_send_station("up" if _pinned == "hall:up" else "")
	_sync_party_asks()
	if not _pinned.is_empty():
		_chip_index = -1
		DeepAudio.play("ui_tap", {"volume": 0.6})
	_fill_chip()
	## A trade tray open for one die closes as soon as anything else is pinned, or nothing is;
	## clicking a stall's die goes straight to the bowl to pick the one traded for it.
	if _run_dock != null and _run_dock.choosing() and _choice_slot.begins_with("trade:"):
		_run_dock.cancel_offer()
		_choice_slot = ""
	var parts: PackedStringArray = _pinned.split(":")
	if parts.size() > 1 and parts[0] == "item":
		_offer_trade(parts[1])

func _inspect_pick(id: String) -> void:
	## The close look at a thing standing in the room: a stone on a stall's counter, one of a
	## Warden's three, a die thrown on the floor after a fall.
	var parts: PackedStringArray = id.split(":")
	if parts.size() < 2:
		return
	match parts[0]:
		"item":
			for item in DeepDescent.stall_stock(run, local_id):
				if str(item.get("id", "")) != parts[1]:
					continue
				if item.has("stone"):
					Inspector.stone(item.stone)
					return
				if item.has("die"):
					Inspector.die(item.die)
					return
		"hoard":
			for stone in run.get("hoard", {}).get(local_id, {}).get("offers", []):
				if str(stone.get("id", "")) == parts[1]:
					Inspector.stone(stone)
					return

func _press_pick(id: String) -> void:
	var parts: PackedStringArray = id.split(":")
	match parts[0]:
		"":
			if not _pinned.is_empty():
				_pin("")
			## The phone has no hover to take a mouth's plate away: a tap off it does.
			if DeepUi.phone and _chip_index >= 0:
				_hover_mouth(-1)
			## A tap on the room puts away what stands over it on the phone (November 10, 2026):
			## the chart, the bag across the right and the "With whom?" plate. Each opens again
			## from where it opened (the chart's button, the bag's pill, the booth).
			if DeepUi.phone:
				if _chart_open:
					toggle_chart()
				if _run_dock.is_drawer_open():
					_run_dock.toggle_drawer()
				if _whom_plate != null and is_instance_valid(_whom_plate):
					_close_whom()
		"item", "scales", "lens", "hoard":
			_pin(id)
		"altar":
			if parts.size() > 1 and parts[1] == "crystal":
				_altar_offer()
			elif parts.size() > 1:
				_altar_take(int(parts[1]))
		"hall":
			match parts[1]:
				"rest":
					_respite("rest", "")
				"wish", "appraise":
					_open_landing(parts[1])
				"trade":
					_trade_station("")
				_:
					_pin(id)
		"spot":
			if not bool(me().get("mining", false)) or _strike_pending or str(run.get("phase", "")) != "chamber":
				return
			_strike_pending = true
			_strike_token += 1
			var token: int = _strike_token
			for spot in run.chamber.get("vein", {}).get("spots", []):
				_stage.enable_pick("spot:%d" % int(spot.index), false)
			command.emit({"kind": "strike", "spot": int(parts[1])})
			## A swing the host turned down (an ally broke through that spot first, or the arm
			## is spent) never comes back as a strike, and a lost packet never comes back at all:
			## neither may leave the rock shut to this player for the rest of the vein.
			_later(2.5, _strike_lapsed.bind(token))

func refused() -> void:
	## The host said no to something this player asked for. A swing waiting on its answer is
	## not waiting any more, and nor is a press of the altar's crystal.
	_altar_sent = false
	if _strike_pending:
		_strike_lapsed(_strike_token)
	## A piece of work turned down after its ask sheet closed on "Do it" leaves the page it
	## was asked from with nothing on it: draw the room again so its cards and the way out
	## come back (an oddity, the landing's well, the trading table).
	if str(run.get("phase", "")) in ["chamber", "landing"] and not DeepDescent.in_battle(run) and _hold.is_empty() and not _walking and (_ask == null or not _ask.is_open()):
		show_state(run)

func _strike_lapsed(token: int) -> void:
	if not _strike_pending or token != _strike_token:
		return
	_strike_pending = false
	if str(run.get("phase", "")) == "chamber" and str(run.get("chamber", {}).get("kind", "")) in DeepDescent.ROCK_ROOMS and _hold.is_empty():
		show_state(run)

func _pick_chip(box: VBoxContainer, id: String) -> bool:
	## What the chip says about a thing in the room. False if there is nothing to say.
	var parts: PackedStringArray = id.split(":")
	match parts[0]:
		"altar":
			return _altar_chip(box, parts[1] if parts.size() > 1 else "")
		"spot":
			var spots: Array = run.get("chamber", {}).get("vein", {}).get("spots", [])
			var index: int = int(parts[1])
			if index < 0 or index >= spots.size():
				return false
			var glint: String = str(spots[index].get("glint", "dull"))
			var words: Array = VEIN_WORDS.get(glint, VEIN_WORDS.dull)
			var tone: Color = {"rich": RICH_TONE, "bright": Color("ffcf5a"), "glint": DeepUi.INFO}.get(glint, DeepUi.MUTED)
			var title_row := DeepUi.hbox(box, 8)
			DeepUi.icon(title_row, "gem" if glint == "rich" else ("spark" if glint != "dull" else "ore"), 20, tone)
			DeepUi.title(title_row, str(words[0]), 18, tone.lightened(0.2))
			DeepUi.label(box, str(words[1]), 13, DeepUi.MUTED)
			var bitten: int = int(spots[index].get("struck", 0))
			if bitten > 0:
				DeepUi.stat(box, "pick", "%s in and the rock still holds" % DeepUi.plural(bitten, "swing"), DeepUi.ACCENT, 12)
			elif glint == "rich":
				DeepUi.stat(box, "pick", "barely held: a swing or two", RICH_TONE, 12)
			elif glint == "bright":
				DeepUi.stat(box, "pick", "buried deep: %s" % _swings_band("bright"), DeepUi.MUTED, 12)
			elif glint == "glint":
				DeepUi.stat(box, "pick", "a little way in: %s" % _swings_band("glint"), DeepUi.MUTED, 12)
			var cost: int = DeepDescent.swing_cost(run, me())
			DeepUi.stat(box, "heart", "this swing costs %s" % ("nothing" if cost <= 0 else "%d health" % cost), DeepUi.BAD if cost > 0 else DeepUi.GOOD, 12)
			DeepUi.label(box, "Click to strike.", 12, DeepUi.DIM)
			return true
		"item", "scales", "lens":
			return _stall_chip(box, id, parts)
		"hall":
			return _hall_chip(box, id, parts[1])
		"hoard":
			return _hoard_chip(box, id, parts[1])
	return false

# --- the stall -----------------------------------------------------------------------------------
##
## A merchant's stones are on a counter in the room (and now and then a die, traded for one
## of yours by clicking it). Drag one onto a socket or the bag to buy it (and set it); click
## one for its lines and a Buy button. A stone from the bag dropped on the lens is appraised,
## on the scales sold; click either for a list instead.

func _show_stall() -> void:
	var chamber: Dictionary = run.chamber
	var unit: Dictionary = me()
	var cost: int = DeepDescent.appraise_cost(run, local_id)
	var stock: Array = DeepDescent.stall_stock(run, local_id)
	var counter: Node3D = _stage.stall(stock, cost)
	if counter != null:
		## Every price on the counter says whether this purse can meet it.
		if counter.has_method("set_purse"):
			counter.set_purse(int(unit.get("ore", 0)))
		for item in stock:
			var id: String = "item:%s" % str(item.id)
			if not str(item.get("sold", "")).is_empty():
				if counter.has_item(str(item.id)):
					_stage.stall_sold(str(item.id), _pill_centre("bag"), false)
				_stage.remove_pick(id)
				continue
			if not _stage.has_pick(id) and counter.has_item(str(item.id)):
				var goods: Dictionary = item
				var key: String = str(item.id)
				_stage.add_pick(id, counter.item_node(key), Vector3(0.3, 0.32, 0.3), {
					"hover": func(on: bool) -> void:
						if is_instance_valid(counter):
							counter.set_hover(key, on),
					"drag": func() -> Variant:
						## A stone is dragged where it is wanted. A die cannot be: it is traded
						## for one of your own, so it is clicked and the trade-in is chosen.
						if str(goods.get("kind", "stone")) == "die":
							return null
						if not DeepDescent.at_stall(run) or int(me().get("ore", 0)) < int(goods.price) or bool(me().get("downed", false)):
							return null
						return {"kind": "shop_item", "item_id": key, "item_kind": "stone", "price": int(goods.price), "stone": goods.stone},
					"preview": func() -> Control:
						return Thumbs.DieThumb.new(goods.die, 64) if str(goods.get("kind", "stone")) == "die" else Thumbs.GemThumb.new(goods.stone, 64)})
		if not _stage.has_pick("scales"):
			_stage.add_pick("scales", counter.scales, Vector3(0.55, 0.55, 0.35), {
				"hover": func(on: bool) -> void:
					if is_instance_valid(counter):
						counter.glow("scales", on)
						## The pans name their price the moment a stone is lifted towards them.
						var held: Dictionary = _dragged_stone() if on else {}
						counter.set_scales_price(DeepStone.sell_value(held) if not held.is_empty() and not DeepStone.known_fragile(held) else -1),
				"accepts": func(data: Dictionary) -> bool:
					## Anything you carry, set or loose, read or still in its rock: the buyer
					## pays what a size class is worth for one nobody has read.
					return str(data.get("kind", "")) == "stone" and not bool(me().get("downed", false)) and not DeepStone.known_fragile(DeepOddities.find_stone(me(), str(data.get("stone_id", "")))),
				"drop": func(data: Dictionary) -> void: _sell(str(data.stone_id))})
		if not _stage.has_pick("lens"):
			_stage.add_pick("lens", counter.lens, Vector3(0.35, 0.55, 0.35), {
				"hover": func(on: bool) -> void:
					if is_instance_valid(counter):
						counter.glow("lens", on),
				"accepts": func(data: Dictionary) -> bool:
					return str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) < 0 and not bool(data.get("appraised", false)) and not bool(me().get("downed", false)) and int(me().get("ore", 0)) >= DeepDescent.appraise_cost(run, local_id),
				"drop": func(data: Dictionary) -> void: _appraise(str(data.stone_id))})
	## The bag stays shut as the party walks up: open, it stood over the goods' price tags. It
	## opens for the length of a drag off the counter (run_dock.gd), and from the strip.
	_crossroads.visible = true
	_cross_title.text = "A merchant"
	_cross_sub.text = "Tap a stone to buy it. Tap the die to trade one of yours for it." if DeepUi.phone else "Drag a stone onto your rail or your bag to buy it. Click the die to trade one of yours for it."
	if bool(unit.get("downed", false)):
		_cross_sub.text = "You are down, and the merchant will not deal with you until you are back on your feet at the next landing."
	DeepUi.clear(_cross_hint)
	## The purse on the same opaque plate as the tools beside it, outlined in ore: a pill's faint
	## tint all but vanished over the stall's lamplight and read as switched off.
	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel", DeepUi.facet_ends(purse, DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.ORE.darkened(0.35), 14, 8, 0.4)))
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_hint.add_child(purse)
	DeepUi.stat(purse, "ore", ("%d to spend" if DeepUi.phone else "%d pyrite to spend") % int(unit.get("ore", 0)), DeepUi.ORE, 12 if DeepUi.phone else 14)
	var tools := PanelContainer.new()
	tools.add_theme_stylebox_override("panel", DeepUi.facet_ends(tools, DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.LINE, 14, 8, 0.4)))
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_hint.add_child(tools)
	var row := DeepUi.hbox(tools, 14)
	## The tool first, then what it does: "sold, read or raw" after a colon read as three choices.
	## The phone's three capsules say it shorter (board run-merchant).
	DeepUi.stat(row, "loupe", ("Lens · %d" if DeepUi.phone else "Lens: appraise a raw stone · %d pyrite") % cost, DeepUi.INFO, 12)
	DeepUi.stat(row, "scales", "Scales: sell any stone" if DeepUi.phone else "Scales: sell any stone, read or raw", DeepUi.ORE, 12)
	## Done here is the stall's way out, in the room's corner (November 9, 2026).
	if not bool(unit.get("ready", false)) and not bool(unit.get("downed", false)):
		_main(_way_out("Done here", func() -> void:
			_pin("")
			command.emit({"kind": "leave"})))
	else:
		_drop_way_out()
	_fill_chip()

func _buy_socket(unit: Dictionary, item: Dictionary) -> int:
	## The first empty socket a stone on the counter would be set in once bought, or -1.
	var stone: Dictionary = item.get("stone", {})
	if stone.is_empty():
		return -1
	var probe: Dictionary = unit.duplicate(true)
	probe.haul.append(stone)
	var rail: Array = unit.get("rail", [])
	for index in range(rail.size()):
		if rail[index] is Dictionary:
			continue
		if DeepDescent.socket_refusal(probe, stone, index).is_empty():
			return index
	return -1

func _buy(item_id: String) -> void:
	DeepAudio.play("ui_confirm", {"volume": 0.6})
	command.emit({"kind": "buy", "item_id": item_id})

func _sell(stone_id: String) -> void:
	command.emit({"kind": "sell", "stone_id": stone_id})

func _dragged_stone() -> Dictionary:
	## The stone in hand right now, if one is being dragged across the room. The scales use it
	## to weigh a thing before it is let go rather than after.
	if _headless or not is_inside_tree():
		return {}
	var port: Viewport = get_viewport()
	if port == null:
		return {}
	var data: Variant = port.gui_get_drag_data()
	if not data is Dictionary or str(data.get("kind", "")) != "stone":
		return {}
	return DeepOddities.find_stone(me(), str(data.get("stone_id", "")))

func _scales_line(box: VBoxContainer, stone: Dictionary, listed: bool) -> void:
	## One stone on the pans: what it is and what the buyer counts out for it. A raw one is
	## sold on its size class alone, which is always the worse end of what it might be worth.
	var appraised: bool = bool(stone.get("appraised", false))
	var paid: int = DeepStone.sell_value(stone)
	var line := DeepUi.hbox(box, 8)
	StoneCard.mini(line, stone, 32)
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
	var said: String = DeepUi.skill_name(stone) if appraised else DeepStone.raw_name(stone)
	DeepUi.label(line, said, 12, tone)
	StoneCard.grade_marks(line, stone, 11).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if DeepStone.known_fragile(stone):
		DeepUi.stat(line, "split_shield", "Fragile · cannot sell", DeepUi.BAD, 12)
		return
	if listed:
		DeepUi.icon_button(line, "ore", "Sell · %d" % paid, _sell.bind(str(stone.id)), 12, DeepUi.ORE).disabled = bool(me().get("downed", false))
	else:
		DeepUi.stat(line, "ore", "%d pyrite" % paid, DeepUi.ORE, 15)
		if not appraised:
			DeepUi.label(box, "Still raw. Appraise it first and it sells for more.", 11, DeepUi.DIM)

func _appraise(stone_id: String) -> void:
	DeepAudio.play("loupe_spin", {"volume": 0.6})
	command.emit({"kind": "appraise", "stone_id": stone_id})

func _die_chip(box: VBoxContainer, item: Dictionary, pinned: bool, ore: int) -> bool:
	## The one die a merchant keeps for you. It is never added to a bowl, only swapped into
	## it, so the only dice offered as trade-ins are the ones with the same number of faces.
	var die: Dictionary = item.get("die", {})
	var tone: Color = DiceIcons.die_palette(die).body
	var head := DeepUi.hbox(box, 8)
	head.add_child(Thumbs.DieThumb.new(die, 44))
	var words := DeepUi.vbox(head, 1)
	DeepUi.title(words, DeepDice.describe(die), 18, tone)
	var told: Array = []
	if not str(die.get("pattern", "")).is_empty():
		told.append(str(DeepContent.pattern(str(die.pattern)).get("text", "")))
	if not str(die.get("material", "")).is_empty():
		told.append(str(DeepContent.material(str(die.material)).get("text", "")))
	for entry in DeepDice.etchings(die):
		told.append("%s: %s" % [DeepDice.etching_name(str(entry.kind)), str(DeepContent.etching(str(entry.kind)).get("text", ""))])
	DeepUi.label(words, "%s · %d faces" % [str(die.get("shape", "D6")).to_lower(), die.get("faces", []).size()], 12, DeepUi.MUTED)
	for line in told:
		DeepUi.wrap(box, line, 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 300)
	var swaps: Array = me().get("dice", []).filter(func(d: Dictionary) -> bool: return str(d.get("shape", "")) == str(die.get("shape", "")))
	if not pinned:
		DeepUi.stat(box, "ore", "%d pyrite  ·  click to trade one of yours for it" % int(item.price), DeepUi.ORE if ore >= int(item.price) else DeepUi.DIM, 12)
		return true
	if swaps.is_empty():
		DeepUi.label(box, "You carry no %s to trade for it." % str(die.get("shape", "D6")).to_lower(), 12, DeepUi.BAD)
		return true
	if ore < int(item.price):
		DeepUi.label(box, "%d pyrite to trade for it. You have %d." % [int(item.price), ore], 12, DeepUi.BAD)
		return true
	## The bowl itself is where the die to give up is picked (see `_offer_trade`): this only
	## brings it back after a Never mind.
	var again := DeepUi.primary(box, "die", "Choose a die to trade · %d pyrite" % int(item.price), _offer_trade.bind(str(item.id)), 14, DeepUi.ORE)
	again.disabled = not DeepDescent.at_stall(run) or bool(me().get("downed", false))
	return true

func _offer_trade(item_id: String) -> void:
	## A die on a stall is bought by trading one of yours for it: the dock gives way to your
	## dice, the ones of its size lit and the rest dimmed, and the one clicked is traded.
	var item: Dictionary = {}
	for candidate in DeepDescent.stall_stock(run, local_id):
		if str(candidate.get("id", "")) == item_id:
			item = candidate
	var unit: Dictionary = me()
	if item.is_empty() or str(item.get("kind", "")) != "die" or not str(item.get("sold", "")).is_empty() or _run_dock == null:
		return
	if int(unit.get("ore", 0)) < int(item.price) or not DeepDescent.at_stall(run) or bool(unit.get("downed", false)):
		return
	var shape: String = str(item.die.get("shape", "D6"))
	if not unit.get("dice", []).any(func(d: Dictionary) -> bool: return str(d.get("shape", "")) == shape):
		return
	var refusals: Dictionary = {}
	for mine in unit.get("dice", []):
		if str(mine.get("shape", "")) != shape:
			refusals[str(mine.id)] = "only a %s can be traded for it" % shape.to_lower()
	_choice_slot = "trade:" + item_id
	_run_dock.offer("die", unit.get("dice", []), "Trade one of your dice for the %s · %d pyrite" % [DeepDice.describe(item.die), int(item.price)], refusals)

func _buy_die(item_id: String, die_id: String) -> void:
	DeepAudio.play("ui_confirm", {"volume": 0.6})
	command.emit({"kind": "buy", "item_id": item_id, "die_id": die_id})

func _stall_chip(box: VBoxContainer, id: String, parts: PackedStringArray) -> bool:
	var unit: Dictionary = me()
	var pinned: bool = _pinned == id
	var ore: int = int(unit.get("ore", 0))
	match parts[0]:
		"item":
			var item: Dictionary = {}
			for candidate in DeepDescent.stall_stock(run, local_id):
				if str(candidate.id) == parts[1]:
					item = candidate
			if item.is_empty() or not str(item.get("sold", "")).is_empty():
				return false
			if str(item.get("kind", "stone")) == "die":
				return _die_chip(box, item, pinned, ore)
			var stone: Dictionary = item.stone
			var grade: Dictionary = DeepStone.grade(stone)
			var tone: Color = DeepUi.tier_color(str(grade.tier))
			var head := DeepUi.hbox(box, 8)
			StoneCard.mini(head, stone, 40)
			var words := DeepUi.vbox(head, 1)
			DeepUi.title(words, str(DeepStone.skill_of(stone).get("name", "")), 18, tone)
			DeepUi.label(words, "%s %s · %d ct · %s" % [DeepContent.cut_name(int(stone.cut)), DeepContent.clarity_name(int(stone.clarity)), int(stone.carat), str(grade.name)], 12, DeepUi.MUTED)
			DeepUi.wrap(box, DeepStone.text(stone), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 300)
			## What is frozen inside it, named before it is paid for; each says what it does.
			if not stone.get("inclusions", []).is_empty() and (bool(stone.get("appraised", false)) or bool(stone.get("inclusions_revealed", false))):
				var inside := HFlowContainer.new()
				inside.add_theme_constant_override("h_separation", 6)
				inside.add_theme_constant_override("v_separation", 4)
				inside.custom_minimum_size.x = 300
				box.add_child(inside)
				for key in stone.inclusions:
					StoneCard._inclusion_chip(inside, str(key))
			if pinned:
				var can: bool = ore >= int(item.price) and DeepDescent.at_stall(run) and not bool(unit.get("downed", false))
				var button := DeepUi.primary(box, "ore", ("Buy for the bag · %d" if DeepUi.phone else "Buy for %d") % int(item.price), _buy.bind(str(item.id)), 14, DeepUi.ORE)
				button.disabled = not can
				## On the phone a stone is not dragged to a socket to be set as it is bought: the
				## card sets it in the first empty socket that takes it.
				var socket: int = _buy_socket(unit, item) if DeepUi.phone else -1
				if socket >= 0:
					var set_it := DeepUi.icon_button(box, "gem", "Set it on the rail · socket %d" % (socket + 1), func() -> void:
						_buy(str(item.id))
						command.emit({"kind": "socket", "stone_id": str(item.stone.get("id", "")), "index": socket}), 13, DeepUi.ACCENT)
					set_it.disabled = not can
				if DeepUi.phone:
					button.custom_minimum_size.y = DeepUi.pt(36)
				if ore < int(item.price):
					DeepUi.label(box, "You have %d pyrite." % ore, 12, DeepUi.BAD)
			else:
				DeepUi.stat(box, "ore", ("%d pyrite  ·  tap to buy" if DeepUi.phone else "%d pyrite  ·  drag it to buy, or click") % int(item.price), DeepUi.ORE if ore >= int(item.price) else DeepUi.DIM, 12)
			return true
		"scales":
			DeepUi.section(box, "scales", "The scales", DeepUi.ORE)
			DeepUi.label(box, "Half what an appraised stone is worth; a raw one fetches what its size class is worth and no more.", 12, DeepUi.MUTED)
			## Something held over the pans is weighed there and then: the buyer's price for
			## that one stone, before it is let go.
			var held: Dictionary = _dragged_stone()
			if not held.is_empty():
				_scales_line(box, held, false)
				if not DeepStone.known_fragile(held):
					DeepUi.label(box, "Let go to sell it.", 12, DeepUi.DIM)
				return true
			var sellable: Array = _loose(unit)
			if not pinned:
				DeepUi.label(box, "Tap for a list of what you can sell." if DeepUi.phone else "Drop one from your bag here, or click for a list.", 12, DeepUi.DIM)
			elif sellable.is_empty():
				DeepUi.label(box, "Nothing in your bag to sell.", 12, DeepUi.DIM)
			## The chip is one panel and never scrolls, so a full bag shows the first of them
			## and says how many are behind; the rest are sold by dropping them on the pans.
			for stone in (sellable.slice(0, SCALES_LISTED) if pinned else []):
				_scales_line(box, stone, true)
			if pinned and sellable.size() > SCALES_LISTED:
				DeepUi.label(box, "%d more in the bag: drop one on the pans to sell it." % (sellable.size() - SCALES_LISTED), 12, DeepUi.DIM)
			return true
		"lens":
			var cost: int = DeepDescent.appraise_cost(run, local_id)
			DeepUi.section(box, "loupe", "The lens", DeepUi.INFO)
			DeepUi.label(box, "%d pyrite for the next stone; dearer each time at this stall." % cost, 12, DeepUi.MUTED)
			var raw: Array = _loose(unit).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			if not pinned:
				DeepUi.label(box, "Tap for a list of your raw stones." if DeepUi.phone else "Drop a raw stone from your bag here, or click for a list.", 12, DeepUi.DIM)
			elif raw.is_empty():
				DeepUi.label(box, "No raw stones in your bag.", 12, DeepUi.DIM)
			for stone in (raw if pinned else []):
				var line := DeepUi.hbox(box, 8)
				StoneCard.mini(line, stone, 32)
				DeepUi.label(line, DeepStone.raw_name(stone), 12, DeepUi.PAPER).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var button := DeepUi.icon_button(line, "loupe", "Appraise · %d" % cost, _appraise.bind(str(stone.id)), 12, DeepUi.INFO)
				button.disabled = ore < cost or bool(unit.get("downed", false))
			return true
	return false

# --- the altar ------------------------------------------------------------------------------------
##
## Five sockets on the star of an old stone face. A gem dragged up from the bag or the rail
## sits in a socket until it is clicked out again: nothing is given up until the crystal is
## pressed, so the five are this screen's to remember, not the run's. When all five sockets
## hold a gem the crystal answers at once: lit for a set the circle knows, cold for anything
## else. It never says which.

func _altar_state() -> String:
	for id in _altar_slots:
		if str(id).is_empty():
			return "dark"
	var stones: Array = _altar_slots.map(func(id: Variant) -> Dictionary: return DeepOddities.find_stone(me(), str(id)))
	return "lit" if DeepAltar.lit(stones) else "cold"

func _altar_forget_missing() -> void:
	## A gem that left our hands since it was set down (a trade, a fall) leaves its socket too.
	for index in range(_altar_slots.size()):
		var id: String = str(_altar_slots[index])
		if not id.is_empty() and DeepAltar.refusal(DeepOddities.find_stone(me(), id)) != "":
			_altar_slots[index] = ""

func _altar_open() -> bool:
	return DeepDescent.at_altar(run) and str(me().get("altar_done", "")).is_empty() and not bool(me().get("downed", false)) and not _altar_sent

func _altar_takes(data: Dictionary) -> bool:
	if str(data.get("kind", "")) != "stone" or not _altar_open():
		return false
	return DeepAltar.refusal(DeepOddities.find_stone(me(), str(data.get("stone_id", "")))).is_empty()

func _altar_place(index: int, stone_id: String) -> void:
	if not _altar_open() or index < 0 or index >= _altar_slots.size():
		return
	var stone: Dictionary = DeepOddities.find_stone(me(), stone_id)
	if not DeepAltar.refusal(stone).is_empty():
		return
	## One gem fills one socket: set down again, it moves.
	for other in range(_altar_slots.size()):
		if str(_altar_slots[other]) == stone_id:
			_altar_slots[other] = ""
	_altar_slots[index] = stone_id
	DeepAudio.play(str(DeepSoundBank.GEM_SOUNDS.get(DeepStone.color(stone), "gleam")), {"volume": 0.7})
	_show_altar()

func _altar_take(index: int) -> void:
	if not _altar_open() or index < 0 or index >= _altar_slots.size() or str(_altar_slots[index]).is_empty():
		return
	_altar_slots[index] = ""
	DeepAudio.play("ui_back", {"volume": 0.6})
	_show_altar()

func _altar_offer() -> void:
	if not _altar_open() or _altar_state() != "lit":
		return
	_altar_sent = true
	command.emit({"kind": "altar", "stone_ids": _altar_slots.duplicate()})

func _altar_lent() -> bool:
	## Whether any of the five is a copy of a stone at home, which the vault then loses too.
	for id in _altar_slots:
		var stone: Dictionary = DeepOddities.find_stone(me(), str(id))
		if not stone.is_empty() and DeepDescent.is_lent(run, stone):
			return true
	return false

func _show_altar() -> void:
	var unit: Dictionary = me()
	var done: String = str(unit.get("altar_done", ""))
	var tone: Color = DeepUi.CHAMBER_colorS.get("altar", DeepUi.ACCENT)
	if not _altar_making:
		_altar_forget_missing()
	var state: String = _altar_state()
	var altar: Node3D = _stage.altar()
	if altar != null and not _altar_making:
		for index in range(DeepAltar.SOCKETS):
			var id: String = "altar:%d" % index
			if not _stage.has_pick(id):
				var at: int = index
				_stage.add_pick(id, altar.sockets[at], Vector3(0.3, 0.3, 0.3), {
					"hover": func(on: bool) -> void:
						if is_instance_valid(altar):
							altar.set_hover(at, on),
					"accepts": func(data: Dictionary) -> bool: return _altar_takes(data),
					"drop": func(data: Dictionary) -> void: _altar_place(at, str(data.get("stone_id", "")))})
		if not _stage.has_pick("altar:crystal"):
			_stage.add_pick("altar:crystal", altar.crystal, Vector3(0.4, 0.55, 0.4), {
				"hover": func(on: bool) -> void:
					if is_instance_valid(altar):
						altar.set_hover(-1, on)})
		for index in range(DeepAltar.SOCKETS):
			var id: String = str(_altar_slots[index])
			altar.set_gem(index, DeepOddities.find_stone(unit, id) if not id.is_empty() else {})
		## The crystal answers the moment the fifth gem goes in, and says it out loud.
		var was: String = altar.state()
		var showing: String = state if done.is_empty() else "dark"
		altar.set_state(showing, _stage.fx)
		if was != showing:
			if showing == "lit":
				DeepAudio.play("altar_hum")
			elif showing == "cold":
				DeepAudio.play("altar_fizzle")
	## The bag opens as the party walks up: that is where the gems come from. (A stall's no
	## longer does: there it stood over the goods' price tags.)
	var room_key: String = str(_stage.place.get("key", run.get("depth", "")))
	if _stall_opened != room_key:
		_stall_opened = room_key
		_run_dock.set_drawer(true)
	_crossroads.visible = true
	_set_cross_mark("altar", tone)
	_cross_title.text = "An altar"
	if bool(unit.get("downed", false)):
		_cross_sub.text = "You are down, and the altar will not answer you until you are back on your feet at the next landing."
	elif done == "made":
		_cross_sub.text = "The circle has given what it had."
	elif done == "left":
		_cross_sub.text = "You walked on from the altar."
	else:
		match state:
			"lit": _cross_sub.text = "The circle is lit. Click the crystal to give the five gems up."
			"cold": _cross_sub.text = "The circle stays cold."
			## What the five are given up for, never which five (docs/ALTAR.md keeps the recipes
			## secret). How to give them is on each socket's own plate.
			_: _cross_sub.text = "Give five gems to the circle and it may make one finer gem from them. Only some sets light it."
	DeepUi.clear(_cross_hint)
	## Walk on is the altar's way out, in the room's corner (November 9, 2026): under the
	## name it stood over the circle's top socket.
	var walk_on: bool = false
	if done == "made" and not _altar_making:
		walk_on = true
	elif done.is_empty() and not bool(unit.get("downed", false)):
		if _altar_lent():
			DeepUi.stat(_cross_hint, "chest", "A gem your rail brought from home is on the altar: your Vault loses it too.", DeepUi.BAD, 13)
		if _altar_slots.any(func(id: Variant) -> bool: return not str(id).is_empty()):
			var clear := DeepUi.icon_button(_cross_hint, "reroll", "Clear the sockets", func() -> void:
				_altar_slots = ["", "", "", "", ""]
				DeepAudio.play("ui_back", {"volume": 0.6})
				_show_altar(), 14, DeepUi.MUTED)
			clear.mouse_filter = Control.MOUSE_FILTER_STOP
		walk_on = true
	if walk_on:
		_main(_way_out("Walk on", func() -> void:
			_pin("")
			command.emit({"kind": "altar_leave"})))
	else:
		_drop_way_out()
	_fill_chip()

func _altar_chip(box: VBoxContainer, which: String) -> bool:
	## What the chip says over a socket or the crystal.
	var tone: Color = DeepUi.CHAMBER_colorS.get("altar", DeepUi.ACCENT)
	if which == "crystal":
		var said: String = {"lit": "Lit. Click to give the five gems up.", "cold": "Cold. The circle does not answer these five.",
			"dark": "Dark until all five sockets hold a gem."}.get(_altar_state(), "")
		if not str(me().get("altar_done", "")).is_empty():
			said = "Dark. The circle has done what it will do for you."
		var row := DeepUi.hbox(box, 8)
		DeepUi.icon(row, "altar", 20, tone)
		DeepUi.label(row, said, 14, DeepUi.PAPER)
		return true
	var index: int = int(which)
	if index < 0 or index >= _altar_slots.size():
		return false
	var stone: Dictionary = DeepOddities.find_stone(me(), str(_altar_slots[index]))
	if stone.is_empty():
		DeepUi.label(box, "An empty socket. Drag a gem here from your bag or your rail.", 13, DeepUi.MUTED)
		return true
	var line := DeepUi.hbox(box, 8)
	StoneCard.mini(line, stone, 32)
	DeepUi.label(line, DeepUi.skill_name(stone), 14, DeepUi.tier_color(str(DeepStone.grade(stone).tier)))
	if _altar_open():
		DeepUi.label(box, "Click to take it back.", 12, DeepUi.DIM)
	return true

func _altar_reveal(made: Dictionary, transcendent: bool, who: String) -> void:
	## The new gem, held up: a plain reveal for anything the circle makes, every color there is
	## for a Transcendent, and a Transcendent anyone in the party makes is everyone's moment.
	if made.is_empty():
		return
	DeepAudio.reveal_stone(made)
	var title: String = "The altar answers"
	var subtitle: String = "%s, already appraised and in your bag." % DeepStone.name(made)
	var button: String = "Into the bag"
	if transcendent:
		title = "Transcendent" if who.is_empty() else "%s made a Transcendent" % who
		subtitle = str(DeepStone.skill_of(made).get("name", "")) + (": made at an altar, and nowhere else." if who.is_empty() else ".")
		button = "Into the bag" if who.is_empty() else "Wonderful"
	Inspector.stone(made, {"fanfare": {"title": title, "subtitle": subtitle, "button": button, "transcendent": transcendent}})

func _fit_area() -> void:
	## Pages stop short of the dock and its drawer, and so does the chart, and so does the ask.
	_area.offset_bottom = - _run_dock.height() if _run_dock.visible else 0.0
	var floor_height: float = _run_dock.height() if _run_dock.visible else 0.0
	if _ask != null:
		_ask.floor_height = floor_height
		## On the phone the open bag is a panel across the right: the ask stands left of it.
		if DeepUi.phone:
			_ask.side_width = _run_dock.column_width() if _run_dock.visible else 0.0
	## In a fight the fight's own dock runs along the bottom: the chart stops above it as
	## well, instead of lying over the health bar and the rail.
	if _battle.visible and _battle._dock != null and _battle.size.y > 0.0:
		floor_height = maxf(floor_height, _battle.size.y - _battle._dock.position.y)
	## Outside a fight its foot stands where the bag column's does, above the dock and the
	## party's tabs; in a fight as far above the fight's dock as it always stood.
	_map_margin.offset_bottom = - _run_dock.side_foot() if _run_dock.visible and not _battle.visible else - floor_height - 26.0
	_fit_page()
	_place_find()
	_place_way_out()
	_fit_head()

func _fit_head() -> void:
	## On the phone an open bag is a panel down the right: the room's name and its line stand
	## centred in what it leaves, not under it (November 9, 2026: the altar's line ran under
	## the bag).
	if _cross_head == null or not is_instance_valid(_cross_head):
		return
	var column: float = _run_dock.column_width() if DeepUi.phone and _run_dock.visible else 0.0
	if DeepUi.phone and _cross_sub != null and _crossroads.size.x > 0.0:
		_cross_sub.custom_minimum_size.x = minf(DeepUi.pt(640), _crossroads.size.x - column - DeepUi.safe_left - DeepUi.safe_right - DeepUi.pt(12))
	## Never so far that its left end goes past the safe edge (a vein's wide legend).
	var wide: float = _cross_head.get_combined_minimum_size().x
	var shift: float = minf(0.0, maxf(- column * 0.5, DeepUi.safe_left + DeepUi.pt(6) - (_crossroads.size.x - wide) * 0.5))
	var moved: float = shift - _head_shift
	if absf(moved) > 0.5:
		for node in [_cross_head, _cross_shade]:
			if node != null and is_instance_valid(node):
				(node as Control).offset_left += moved
				(node as Control).offset_right += moved
		_head_shift = shift

# --- the landing ---------------------------------------------------------------------------------
##
## A landing is the lift hall, and it comes in two beats (see `DeepDescent.at_crossroads`).
## First the camp: a campfire to rest by, a workbench to read a stone at and a wishing well,
## one of the three each, clicked (or a stone dropped on the bench or the well). The cage and
## the mouths in the far wall are shut meanwhile. Once the whole party has taken its respite
## the crossroads opens: the cage and the mouths are chosen from where the party stands, and a
## ride up is asked of the whole party. In a party the trading booth stands at the back on the
## right through both beats (the owner, November 5, 2026): clicked, it asks with whom when more
## than one teammate is free and opens the same trade page a teammate's tab does. A Warden's
## hall is the same screen with none of it: the hoard is behind you and the mouths are all
## there is.

func _show_landing() -> void:
	var unit: Dictionary = me()
	var landing: Dictionary = run.get("landing", {})
	var taken: String = str(unit.get("respite", ""))
	var cleared: bool = bool(landing.get("cleared", false)) and int(landing.get("depth", -1)) == int(run.get("depth", 0))
	var boss_hall: bool = DeepDescent.in_boss_hall(run)
	if _stage.business_key().begins_with("hoard|"):
		## Back to the landing's choices after the hoard: the pedestals are done with.
		_stage.retire_business()
	var lift: Node3D = _stage.hall()
	var can_rest: bool = lift != null and not cleared and lift.parts.has("rest")
	## The respite is still there to take: owed, or (on a No Bench day) on offer.
	var owed: bool = can_rest and taken.is_empty()
	var must_take_respite: bool = DeepDescent.needs_respite(run, unit)
	var crossroads: bool = DeepDescent.at_crossroads(run)
	var party: bool = run.get("players", []).size() > 1
	## The booth stands in a party's hall, put up the first time the party is seen here (the
	## stage builds the hall before it knows the party), and is offered while anyone across
	## the room can still trade with this player (`_landing_stations`).
	if party and lift != null and (not cleared or boss_hall) and DeepDescent.can_trade(run) and lift.has_method("add_trade"):
		lift.call("add_trade")
	var tradeable: Array = _tradeable()
	var trading: bool = party and not tradeable.is_empty()
	## The trade page stays up for as long as the trade can still be made; a station's page only
	## while the respite is still to take.
	if _landing_view == "trade":
		if not DeepDescent.can_trade_with(run, local_id, _trade_with):
			_landing_view = ""
			_send_station("")
	elif lift == null or not lift.parts.has(_landing_view) or not owed:
		_landing_view = ""
	## The booth's question stands only while it still has an answer: the same teammates free,
	## no page up over the hall.
	if _whom_plate != null and (not trading or not _landing_view.is_empty() or str(_whom_plate.get_meta("key", "")) != ",".join(tradeable)):
		_close_whom()
	if _landing_view.is_empty():
		## The page is down (the well answered, the trade was made): a twin plate it held back
		## comes up now rather than on the next state.
		_sync_twin()
	## A page open over the hall says what its station is: the floating names step out meanwhile.
	if lift != null:
		lift.set("names_hushed", not _landing_view.is_empty())
	var offered: Array = []
	if lift != null and (not cleared or boss_hall):
		if not _landing_view.is_empty():
			offered = [_landing_view] if lift.parts.has(_landing_view) else []
		else:
			offered = _landing_stations().filter(func(key: String) -> bool: return lift.parts.has(key))
		lift.set_taken(taken)
		lift.set_offered(offered)
		for key in ["rest", "appraise", "wish", "up", "trade"]:
			if not lift.parts.has(key):
				continue
			var id: String = "hall:" + key
			if not _stage.has_pick(id):
				var part: Node3D = lift.parts[key]
				var which: String = key
				var options: Dictionary = {"hover": func(on: bool) -> void:
					if is_instance_valid(lift):
						lift.set_hover(which if on else "")}
				match key:
					"up":
						options.offset = Vector3(0, 1.5, 0)
						options.half = Vector3(1.3, 1.5, 1.3)
					"rest":
						options.offset = Vector3(0, 0.55, 0)
						options.half = Vector3(0.85, 0.65, 0.85)
					"appraise":
						options.offset = Vector3(0, 1.0, 0)
						options.half = Vector3(1.0, 1.0, 0.6)
						options.accepts = func(data: Dictionary) -> bool:
							return str(me().get("respite", "")).is_empty() and str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) < 0 and not bool(data.get("appraised", false))
						options.drop = func(data: Dictionary) -> void: _respite("appraise", str(data.stone_id))
					"wish":
						options.offset = Vector3(0, 1.1, 0)
						options.half = Vector3(1.0, 1.2, 1.0)
						options.accepts = func(data: Dictionary) -> bool:
							return str(me().get("respite", "")).is_empty() and str(data.get("kind", "")) == "stone" and DeepDescent.can_wish(DeepOddities.find_stone(me(), str(data.get("stone_id", ""))))
						options.drop = func(data: Dictionary) -> void: _respite("wish", str(data.stone_id))
					"trade":
						## The whole booth, awning and all, the way the cage is the whole cage. A loose
						## stone dropped on it goes on the table as the page opens.
						options.offset = Vector3(0, 1.5, 0)
						options.half = Vector3(1.2, 1.5, 0.9)
						options.accepts = func(data: Dictionary) -> bool:
							return str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) < 0 and not _tradeable().is_empty() \
								and not DeepStone.is_geode(DeepOddities.find_stone(me(), str(data.get("stone_id", ""))))
						options.drop = func(data: Dictionary) -> void: _trade_station(str(data.get("stone_id", "")))
				_stage.add_pick(id, part, options.get("half", Vector3.ONE), options)
			_stage.enable_pick(id, key in offered)
	var cage: bool = lift != null and lift.parts.has("up") and (not cleared or boss_hall)
	if not crossroads or _reading() or not _landing_view.is_empty():
		## The camp: the ways on are shut until the whole party has taken its respite. Nothing
		## moves while a sheet is up, either: walking the camera forward behind an appraisal
		## reads as the game having got on without the player.
		_stage.close_ways()
	elif cage:
		## The crossroads, with a cage: the cage and the mouths are both chosen from where the
		## party stands, so both stay in view.
		_stage.open_ways(crossroads_entries())
	else:
		## A Warden's hall: no cage, nothing to stand beside. The party walks up to the mouths.
		_stage.crossroads(crossroads_entries())
	_crossroads.visible = true
	if not _landing_view.is_empty():
		_landing_page(_landing_view)
		_fill_chip()
		return
	_set_cross_mark("crown" if cleared else "lift", DeepUi.CHAMBER_colorS.get("warden" if cleared else "landing", DeepUi.GOOD))
	var next_key: String = DeepDescent.next_mine(run)
	if boss_hall:
		_cross_title.text = "The bottom of %s  ·  depth %d" % [DeepContent.mine_name(str(run.get("mine", ""))), int(run.get("depth", 0))]
	else:
		_cross_title.text = ("The Warden's hall" if cleared else "The landing") + "  ·  depth %d" % int(run.get("depth", 0))
	if boss_hall and not next_key.is_empty():
		_cross_sub.text = "The mine is beaten. Ride the lift home with it all, or push on into %s carrying everything: nothing is banked until you ride up." % DeepContent.mine_name(next_key)
	elif boss_hall:
		_cross_sub.text = "The mine is beaten, and there is nowhere further down. Ride the lift home."
	elif cleared:
		_cross_sub.text = "There's no lift out from this deep. Take a tunnel down and carry your haul to the next one."
	elif not crossroads and must_take_respite:
		_cross_sub.text = ("First, the camp. Each of you takes one action: rest, appraise a stone or use the well. Then the party chooses together: the lift up, or a way down." + (" A trade at the booth is free." if trading else "") if party
			else "First, one action: rest, appraise a stone or use the well. Then ride the lift up, or choose a way down.")
	elif not crossroads:
		_cross_sub.text = "You've taken your action. The lift and the ways down open once everyone has taken theirs." + (" Meanwhile, trade a stone at the booth, or click someone's tab." if trading else "")
	elif owed:
		_cross_sub.text = "You cannot rest today. Appraise a stone or use the well if you like, then ride the lift up or choose a way down."
	elif party:
		_cross_sub.text = "Everyone is ready. Ride the lift up together, or choose a way down: the party goes where most of it points." + (" The booth stays open until you leave." if trading else "")
	else:
		_cross_sub.text = "Ride the lift up with what you're carrying, or choose a way down."
	DeepUi.clear(_cross_hint)
	if bool(landing.get("warden_next", false)) and not cleared:
		## At the bottom of a mine it is not a Warden but the mine's own final boss.
		var boss_below: bool = DeepDescent.run_is_boss(run, int(run.get("depth", 0)))
		if boss_below:
			DeepUi.pill(_cross_hint, "crown", "The final boss guards the way down", DeepUi.BAD, 13)
		else:
			## The hall past a Warden has no cage: said here, where the lift still stands, so the
			## lift is not taken away after the fight without a word.
			DeepUi.pill(_cross_hint, "crown", "A Warden guards the way down · its hall has no lift", DeepUi.BAD, 13, LAST_LIFT)
	if boss_hall:
		DeepUi.pill(_cross_hint, "crown", "%s is dead" % str(DeepContent.creature(DeepDescent.warden_key(run, int(run.get("depth", 0)))).get("name", "The boss")), DeepUi.ACCENT, 13)
	elif cleared:
		DeepUi.pill(_cross_hint, "check", "The Warden is dead", DeepUi.GOOD, 13)
	## A Warden's hall is the landing above it with the Warden dead: what was rested at up
	## there is not said again down here, where nothing can be rested at.
	var rested: Dictionary = landing.get("respites", {}).get(local_id, {})
	if not rested.is_empty() and not cleared:
		DeepUi.pill(_cross_hint, {"rest": "heart", "appraise": "loupe", "wish": "drop"}.get(str(rested.get("choice", "")), "check"), str(rested.get("message", "")), DeepUi.GOOD, 12)
	var traded: Array = landing.get("trades", {}).get(local_id, [])
	if not traded.is_empty():
		DeepUi.pill(_cross_hint, "scales", str(traded.back()), DeepUi.ORE, 12)
	## Where everyone else is with their respite and the way on is on their tab.
	_fill_chip()

func _send_station(at: String) -> void:
	## Where this player stands at a landing, for the rest of the party to see: at the well,
	## the bench, the cage, or trading. Alone there is nobody to tell.
	if run.get("players", []).size() < 2 or str(run.get("phase", "")) != "landing":
		return
	if at == _station_sent and str(me().get("station", "")) == at:
		return
	_station_sent = at
	command.emit({"kind": "station", "at": at})

func _open_landing(view: String) -> void:
	## Go up to the well or the bench, or sit down to trade; "" steps back into the hall.
	if not _pinned.is_empty():
		_pin("")
	_close_whom()
	_landing_view = view
	_oddity_step = ""
	_send_station(view)
	show_state(run)

func _open_trade(partner_id: String) -> void:
	## Trading with one of the party, opened from their tab (or the line that says they asked).
	if not DeepDescent.can_trade_with(run, local_id, partner_id):
		return
	_trade_with = partner_id
	if _landing_view == "trade":
		show_state(run)
		return
	_open_landing("trade")

func _tradeable() -> Array:
	## Who across the room this player could trade with here and now, by id, in seat order
	## (`DeepDescent.can_trade_with`: both standing, both on the line, neither done trading).
	var out: Array = []
	for other in run.get("players", []):
		var id: String = str(other.get("id", ""))
		if id != local_id and DeepDescent.can_trade_with(run, local_id, id):
			out.append(id)
	return out

func _landing_stations() -> Array:
	## What the landing offers this player now, by station, read off the run alone: the camp's
	## three while the respite is still to take (no fire on a No Bench day), the cage once the
	## party stands at the crossroads, and the booth, through both beats, while anyone across
	## the room can still trade with this player. The hall shows the ones it has.
	var unit: Dictionary = me()
	var landing: Dictionary = run.get("landing", {})
	var cleared: bool = bool(landing.get("cleared", false)) and int(landing.get("depth", -1)) == int(run.get("depth", 0))
	if cleared and not DeepDescent.in_boss_hall(run):
		return []
	var out: Array = []
	if not cleared and str(unit.get("respite", "")).is_empty():
		out = ["rest", "appraise", "wish"]
		if DeepDescent.has_mod(run, "NO_BENCH"):
			out.erase("rest")
	if DeepDescent.at_crossroads(run):
		out.append("up")
	if run.get("players", []).size() > 1 and not _tradeable().is_empty():
		out.append("trade")
	return out

func _trade_station(stone_id: String = "") -> void:
	## The booth, clicked (or a loose stone dropped on it): with one teammate free to trade, straight
	## to the table with them; with more, "With whom?" over the dock first. A stone dropped on it
	## goes on the table as the page opens. A twin still to settle comes first, as the rules say.
	if not me().get("twin", {}).is_empty():
		return
	var partners: Array = _tradeable()
	if partners.is_empty():
		return
	if partners.size() == 1:
		_sit_down(str(partners[0]), stone_id)
		return
	_show_whom(partners, stone_id)

func _sit_down(partner_id: String, stone_id: String) -> void:
	## The same page a teammate's tab opens, and the dropped stone offered on it.
	_close_whom()
	_open_trade(partner_id)
	if not stone_id.is_empty() and _landing_view == "trade" and _trade_with == partner_id:
		command.emit({"kind": "trade_offer", "stone_id": stone_id, "to": partner_id})

func _close_whom() -> void:
	if _whom_plate != null and is_instance_valid(_whom_plate):
		_whom_plate.queue_free()
	_whom_plate = null

func _show_whom(partners: Array, stone_id: String) -> void:
	## "With whom?": a face and a name a teammate, each in their seat color, over the dock where
	## the twin plate stands. Picking one sits down with them.
	_close_whom()
	var tone: Color = DeepUi.ORE
	var plate := PanelContainer.new()
	plate.name = "WithWhom"
	plate.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, 16, 3, 5))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.set_meta("key", ",".join(partners))
	_body.add_child(plate)
	_whom_plate = plate
	var box := DeepUi.vbox(plate, 10)
	var head := DeepUi.hbox(box, 8)
	DeepUi.icon(head, "scales", 22, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(head, "With whom?", 22, tone.lightened(0.3)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.spacer(head)
	var shut := DeepUi.icon_button(head, "cross_out", "", _close_whom, 13, DeepUi.MUTED)
	shut.tooltip_text = "Not now"
	shut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := DeepUi.hbox(box, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in partners:
		var partner: Dictionary = DeepDescent.player(run, str(id))
		var seat: Color = _seat_color(str(id))
		var column := DeepUi.vbox(row, 6)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var face := Roster.Portrait.new(str(partner.get("character", "")), Vector2(56, 56), false, false, false, DeepStone.birthstone_for(partner))
		face.ring = seat
		face.mood = Roster.resting_mood(partner)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(face)
		var go := DeepUi.primary(column, "scales", str(partner.get("name", "")), _sit_down.bind(str(id), stone_id), 14, seat)
		DeepUi.ledger_primary(go, seat)
		go.name = "Partner_%s" % str(id)
		go.custom_minimum_size = Vector2(150, 40)
		go.tooltip_text = "Trade a stone with %s." % str(partner.get("name", ""))
		DeepUi.label(column, Roster.unit_named(partner), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_place_over_dock(plate)
	if not _headless:
		DeepAudio.play("ui_tap", {"volume": 0.6})
		DeepUi.pop_in(plate, 0.0, 0.92, 0.26)

func _trade_page() -> void:
	## A trade with one of the party up close: your stone on one side, theirs on the other, and
	## between them the scales and the one word that matters. Below, your loose stones, one
	## click to offer any of them instead. An offer stands when this page is put away: the
	## other player answers it in their own time.
	var unit: Dictionary = me()
	var tone: Color = DeepUi.ORE
	var table: Dictionary = DeepDescent.trade_table(run)
	var accepted: Array = table.get("accepted", [])
	var partner_id: String = _trade_with
	var partner: Dictionary = DeepDescent.player(run, partner_id)
	var who: String = str(partner.get("name", "them"))
	var mine_offer: Dictionary = DeepDescent.trade_offer_of(run, local_id)
	var their_offer: Dictionary = DeepDescent.trade_offer_of(run, partner_id)
	var to_them: bool = str(mine_offer.get("to", "")) == partner_id
	var to_me: bool = str(their_offer.get("to", "")) == local_id
	var paired: bool = DeepDescent.trade_partner(run, local_id) == partner_id
	_set_cross_mark("scales", tone)
	_cross_title.text = "Trading with %s" % who
	_cross_sub.text = "One stone each. When you have both accepted, they swap. One trade each per landing, and it does not use your action here."
	DeepUi.clear(_cross_hint)
	var content := _bottom_page()
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enter(_way_out("Back", func() -> void: _open_landing(""), true, "Back to the landing"))
	var mine_stone: Dictionary = DeepOddities.find_stone(unit, str(mine_offer.get("stone", ""))) if to_them else {}
	var their_stone: Dictionary = DeepOddities.find_stone(partner, str(their_offer.get("stone", ""))) if to_me else {}
	_trade_slots = {}
	var elsewhere: String = str(mine_offer.get("to", "")) if not to_them else ""
	_trade_slots["mine"] = _trade_slot(row, "Your stone", mine_stone, paired and accepted.has(local_id), tone,
		("Offering one here takes back your stone for %s." % str(DeepDescent.player(run, elsewhere).get("name", "them"))) if not elsewhere.is_empty() else "Pick one of your loose stones below.")
	var middle := DeepUi.vbox(DeepUi.card(row, Color(tone, 0.35), 12), 8)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.custom_minimum_size.x = 190
	var scales := DeepUi.icon(middle, "scales", 40, tone)
	scales.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := Roster.Portrait.new(str(partner.get("character", "")), Vector2(28, 28), false, false, false, DeepStone.birthstone_for(partner))
	face.ring = _seat_color(partner_id)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.add_child(face)
	if paired and accepted.has(local_id):
		DeepUi.stat(middle, "check", "You have accepted", DeepUi.GOOD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.label(middle, "Waiting for %s." % who, 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var accept := DeepUi.primary(middle, "check", "Accept the trade", func() -> void:
			DeepAudio.play("ui_confirm", {"volume": 0.8})
			command.emit({"kind": "trade_accept"}), 14, DeepUi.GOOD)
		accept.disabled = not paired
		accept.tooltip_text = "Swap your stone for theirs once they accept too." if paired else "You each need a stone on offer to the other first."
		if paired and accepted.has(partner_id):
			DeepUi.label(middle, "%s has accepted." % who, 12, DeepUi.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	if to_them:
		DeepUi.icon_button(middle, "prev", "Take my stone back", func() -> void: command.emit({"kind": "trade_withdraw"}), 12, DeepUi.MUTED)
	## What they have put up, or why there is nothing: still choosing, or trading with someone else.
	var their_words: String = "%s has not offered you a stone yet." % who
	var their_to: String = str(their_offer.get("to", ""))
	if not their_to.is_empty() and their_to != local_id:
		their_words = "%s is trading with %s." % [who, str(DeepDescent.player(run, their_to).get("name", "someone"))]
	elif to_them:
		their_words = "Your stone is offered. %s answers with one of theirs." % who
	_trade_slots["theirs"] = _trade_slot(row, "%s's stone" % who, their_stone, paired and accepted.has(partner_id), tone, their_words)
	if _trade_pulse and not _headless:
		## What they just put down swells as it lands.
		DeepUi.pulse(_trade_slots.theirs, 1.15, 0.3)
	_trade_pulse = false
	## The bag: any loose stone found down here can be offered, chosen on the ask with the
	## things that would do lit on the dock. A copy of a vault stone stays out of it: it goes
	## home with nobody. So does a sealed Geode, which nobody can trade until the workshop has
	## cracked it.
	var haul: Array = unit.get("haul", []).filter(func(s: Dictionary) -> bool:
		return not DeepStone.is_geode(s) and not (bool(run.get("marks_lent", false)) and DeepDescent.is_lent(run, s)))
	var bag_line := DeepUi.hbox(content, 8)
	bag_line.alignment = BoxContainer.ALIGNMENT_CENTER
	if haul.is_empty():
		DeepUi.stat(bag_line, "cross_out", "You have no stone found down here to trade.", DeepUi.DIM, 13)
		return
	var offered: String = str(mine_offer.get("stone", "")) if to_them else ""
	var choose := DeepUi.icon_button(bag_line, "gem", "Offer a different stone" if to_them else "Offer %s a stone" % who, func() -> void:
		_ask.open({"key": "trade", "title": "Your stone for %s" % who, "text": "One stone each. When you have both accepted, they swap.", "glyph": "scales", "tone": tone,
			"confirm": "Offer it", "slots": [{"key": "stone_id", "kind": "stone", "label": "Which stone?", "items": haul, "pick": offered}]})
		_light_ask(), 14, tone)
	DeepUi.ledger_button(choose, DeepUi.SLATE_HI, DeepUi.ORE, 9)
	_enter(choose, 0.1)

func _trade_slot(parent: Node, heading: String, stone: Dictionary, agreed: bool, tone: Color, empty_words: String) -> Control:
	## One side of the table: the stone put down, its name, and whether its owner has accepted.
	var panel := DeepUi.card(parent, Color(tone, 0.55) if not stone.is_empty() else Color(DeepUi.LINE, 0.7), 14)
	panel.custom_minimum_size = Vector2(220, 0)
	var card := DeepUi.vbox(panel, 6)
	DeepUi.label(card, heading, 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var frame := DeepUi.center(card)
	frame.custom_minimum_size = Vector2(96, 96)
	if stone.is_empty():
		DeepUi.icon(frame, "question", 34, DeepUi.DIM)
		DeepUi.wrap(card, empty_words, 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER, 200)
		return frame
	StoneCard.marked_picture(frame, stone, 90)
	## A raw stone is named by its size and colour, as the bag names it.
	var named := DeepUi.fit_label(card, DeepUi.skill_name(stone) if bool(stone.get("appraised", false)) else DeepStone.raw_name(stone), 13, DeepUi.PAPER, 200)
	named.tooltip_text = DeepUi.stone_name(stone)
	named.mouse_filter = Control.MOUSE_FILTER_PASS
	if agreed:
		DeepUi.stat(card, "check", "Accepted", DeepUi.GOOD, 12).alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		DeepUi.label(card, "Deciding", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return frame

func _trade_flourish(given: Dictionary, got: Dictionary) -> void:
	## The two stones cross the table: each lifts off its own side, they pass in the middle with
	## a flash, and each settles where the other was.
	if _headless:
		return
	var left: Vector2 = size * Vector2(0.38, 0.62)
	var right: Vector2 = size * Vector2(0.62, 0.62)
	for pair in [["mine", true], ["theirs", false]]:
		var slot: Variant = _trade_slots.get(pair[0], null)
		if slot != null and is_instance_valid(slot) and (slot as Control).is_inside_tree():
			var centre: Vector2 = (slot as Control).global_position + (slot as Control).size * 0.5 - global_position
			if bool(pair[1]):
				left = centre
			else:
				right = centre
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 25
	add_child(layer)
	var middle: Vector2 = (left + right) * 0.5 - Vector2(0, 90)
	for flight in [[given, left, right], [got, right, left]]:
		var thumb := Thumbs.GemThumb.new(flight[0], 96)
		thumb.live_on_hover = false
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.size = Vector2(96, 96)
		thumb.pivot_offset = Vector2(48, 48)
		thumb.position = Vector2(flight[1]) - Vector2(48, 48)
		layer.add_child(thumb)
		var start: Vector2 = flight[1]
		var finish: Vector2 = flight[2]
		var arc := func(t: float) -> void:
			var a: Vector2 = start.lerp(middle, t)
			var b: Vector2 = middle.lerp(finish, t)
			thumb.position = a.lerp(b, t) - Vector2(48, 48)
			thumb.scale = Vector2.ONE * (1.0 + 0.45 * sin(t * PI))
			thumb.rotation = sin(t * PI) * 0.35 * (1.0 if start.x < finish.x else -1.0)
		var tween := thumb.create_tween()
		tween.tween_interval(0.15)
		tween.tween_method(arc, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void:
			DeepUi.burst(layer, finish, DeepUi.ORE, 18, 180.0, 0.6, 5.0)
			DeepUi.pulse(thumb, 1.2, 0.3))
	DeepAudio.play("buy", {"volume": 0.8})
	DeepAudio.play("keep", {"volume": 0.7, "delay": 0.9})
	_later(0.6, func() -> void:
		if is_instance_valid(layer):
			DeepUi.burst(layer, middle, Color("fff0c0"), 34, 300.0, 0.7, 6.0))
	var said := DeepUi.float_text(layer, middle - Vector2(0, 20), "Traded!", DeepUi.ORE, 30, 50.0, 1.8)
	said.z_index = 1
	var fade := layer.create_tween()
	fade.tween_interval(1.9)
	fade.tween_property(layer, "modulate:a", 0.0, 0.5)
	fade.tween_callback(layer.queue_free)

func _landing_page(view: String) -> void:
	## The well or the bench up close, along the bottom of the hall. The well is the same card
	## the shaft's well rooms show; the bench lays your raw stones out to be read, one click
	## each. The way back is an arrow at the left end of the row, so another of the landing's
	## things can still be chosen instead.
	if view == "trade":
		_trade_page()
		return
	var unit: Dictionary = me()
	var tone: Color = DeepUi.INFO
	var appraise: bool = view == "appraise"
	var well: Dictionary = DeepContent.oddity(DeepDescent.room_card("well"))
	_set_cross_mark("loupe" if appraise else "drop", tone)
	## Named as the room names it: the word floating over the bench is "Appraise" too.
	_cross_title.text = "Appraise" if appraise else str(well.get("name", "The wishing well"))
	_cross_sub.text = "Read one raw stone under the lamp, free. This is your action at the landing." if appraise else \
		str(well.get("text", "")) + " This is your action at the landing."
	DeepUi.clear(_cross_hint)
	var content := _bottom_page()
	var back := func() -> void: _open_landing("")
	if not appraise:
		## The second step of the well card: what goes down it, chosen in its own socket.
		for choice in well.get("choices", []):
			if str(choice.id) == _oddity_step:
				_page_oddity_work(content, choice, unit, tone, "WISHING_WELL", func(payload: Dictionary) -> void:
					if payload.has("ore"):
						_respite_ore(int(payload.ore))
					else:
						_respite("wish", str(payload.get("stone_id", ""))))
				return
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enter(_way_out("Back", back, true, "Back to the landing"))
	var index: int = 0
	if appraise:
		var raw: Array = _loose(unit).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
		if raw.is_empty():
			var none := DeepUi.card(row, Color(tone, 0.3), 18)
			DeepUi.stat(none, "cross_out", "You have no raw stone to read.", DeepUi.MUTED, 15)
		## A heavy haul is turned like a book, a few stones at a time.
		for stone in _paged(content, "landing_bench", raw, 4):
			var card: PanelContainer = StoneCard.build(row, stone, {"size": 96, "vertical": true, "text_width": 200, "lamp": true})
			var stone_id: String = str(stone.id)
			DeepUi.make_choice(card, tone, func() -> void: _respite("appraise", stone_id))
			card.tooltip_text = "Appraise this one"
			_enter(card, 0.08 + 0.06 * index)
			index += 1
	else:
		for choice in well.get("choices", []):
			if str(choice.get("action", {}).get("kind", "none")) == "none":
				continue
			var needs: String = str(choice.get("needs", ""))
			var id: String = str(choice.id)
			var card := DeepUi.choice_card(row, tone, func() -> void:
				_oddity_step = id
				show_state(run))
			card.custom_minimum_size = Vector2(300, 0)
			var box := DeepUi.vbox(card, 10)
			var title_row := DeepUi.hbox(box, 8)
			DeepUi.icon(title_row, choice_glyph(choice, "WISHING_WELL"), 20, tone)
			DeepUi.title(title_row, str(choice.get("label", choice.id)), 19, DeepUi.PAPER)
			if choice.has("text"):
				DeepUi.wrap(box, DeepOddities.choice_text(choice, int(run.get("depth", 0))), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 260)
			DeepUi.spacer(box, false)
			if needs != "" and _picker_empty(needs, unit, choice.get("action", {})):
				DeepUi.disable_choice(card)
				DeepUi.stat(box, "cross_out", "You have nothing to throw in.", DeepUi.DIM, 12)
			_enter(card, 0.08 + 0.06 * index)
			index += 1

func _respite(choice: String, stone_id: String) -> void:
	if not str(me().get("respite", "")).is_empty():
		return
	var cmd: Dictionary = {"kind": "respite", "choice": choice}
	if not stone_id.is_empty():
		cmd.stone_id = stone_id
	if not _pinned.is_empty():
		_pin("")
	command.emit(cmd)

func _respite_ore(amount: int) -> void:
	## The same respite, paid for out of the purse rather than the haul.
	if not str(me().get("respite", "")).is_empty():
		return
	if not _pinned.is_empty():
		_pin("")
	command.emit({"kind": "respite", "choice": "wish", "ore": amount})

func _well_hold(message: String, well: Dictionary, made: Array, room: String) -> void:
	## Hold the well's answer on a page of its own: it waits for the player to say so before
	## anything moves on, and its first moments are the well's alone (see _page_well).
	_hold_page("well", {"message": message, "well": well, "made": made, "room": room})

func _hall_chip(box: VBoxContainer, id: String, key: String) -> bool:
	var unit: Dictionary = me()
	var pinned: bool = _pinned == id
	var taken: bool = not str(unit.get("respite", "")).is_empty()
	match key:
		"rest":
			DeepUi.section(box, "heart", "Rest by the fire", DeepUi.GOOD)
			if DeepDescent.has_mod(run, "NO_BENCH"):
				DeepUi.label(box, "You cannot rest at a landing today.", 14, DeepUi.DIM)
				return true
			if DeepDescent.has_mod(run, "NIGHT_TERRORS"):
				var to_full: int = maxi(0, int(unit.get("max_hp", 0)) - int(unit.get("hp", 0)))
				DeepUi.label(box, "+%d health, and a little max health lost" % to_full, 14, DeepUi.GOOD)
				if not taken:
					DeepUi.label(box, "Click to sit down.", 12, DeepUi.DIM)
				return true
			var gain: int = DeepDescent.rest_amount(unit, run)
			DeepUi.label(box, "+%d health" % gain if gain > 0 else "You are already whole.", 14, DeepUi.GOOD if gain > 0 else DeepUi.DIM)
			## Whole already, sitting down would spend the landing's one action on nothing.
			if not taken:
				if gain > 0:
					DeepUi.label(box, "Click to sit down.", 12, DeepUi.DIM)
				else:
					DeepUi.wrap(box, "Resting gains nothing now, and it is your one action here.", 12, DeepUi.BAD, HORIZONTAL_ALIGNMENT_LEFT, 300)
			return true
		"appraise", "wish":
			var appraise: bool = key == "appraise"
			DeepUi.section(box, "loupe" if appraise else "drop", "Appraise" if appraise else "The wishing well", DeepUi.INFO)
			DeepUi.label(box, "Read one raw stone under the lamp. Free." if appraise else
				"Throw in something valuable. The more it's worth, the better your odds. A raw stone counts for half its value, an appraised one for 1.5 times.",
				12, DeepUi.MUTED)
			var stones: Array = _loose(unit)
			if not appraise:
				stones.append_array(DeepStone.rail_stones(unit))
			var fit: Array = stones.filter(func(st: Dictionary) -> bool: return (not bool(st.get("appraised", false))) if appraise else DeepDescent.can_wish(st))
			var empty: bool = fit.is_empty() and (appraise or int(unit.get("ore", 0)) < 10)
			## Standing at it already, there is nowhere to go up to.
			var here: bool = _landing_view == key
			DeepUi.label(box, ("No raw stone to read." if appraise else "Nothing you could part with.") if empty else ("Drop a stone here, or pick one below." if here else "Click to go up to it, or drop a stone here."), 12, DeepUi.DIM)
			return true
		"trade":
			DeepUi.section(box, "scales", "The trading booth", DeepUi.ORE)
			DeepUi.wrap(box, "Sit down with one of the party. Each of you puts one loose stone on the table, and when you have both accepted the other's, they swap. One trade each per landing; it is not your action here.", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 300)
			var free: Array = _tradeable().map(func(id: Variant) -> String: return str(DeepDescent.player(run, str(id)).get("name", "")))
			if free.is_empty():
				DeepUi.label(box, "Nobody is free to trade with you here." if not DeepDescent.has_traded(run, local_id) else "You have made your trade at this landing.", 12, DeepUi.DIM)
				return true
			DeepUi.stat(box, "party", "Free to trade: %s" % names_of(free), DeepUi.ORE, 12)
			var seated: Array = DeepDescent.trade_table(run).get("offers", {}).keys().filter(func(id: Variant) -> bool: return str(id) != local_id) \
				.map(func(id: Variant) -> String: return str(DeepDescent.player(run, str(id)).get("name", "")))
			if not seated.is_empty():
				DeepUi.stat(box, "person", "At the table: %s" % names_of(seated), DeepUi.ORE, 12)
			DeepUi.label(box, "Click to sit down, or drop a stone here." if free.size() == 1 else "Click to choose whom to trade with, or drop a stone here.", 12, DeepUi.DIM)
			return true
		"up":
			## Riding up with the mine's last Warden behind you is not extraction but victory,
			## wherever the cage that takes you up happens to stand.
			var conquered: bool = DeepDescent.is_conquered(run)
			DeepUi.section(box, "lift", "Up: return victorious" if conquered else "Up: ride home", DeepUi.GOOD)
			var haul: Array = unit.get("haul", [])
			var worth: int = 0
			for stone in haul:
				worth += DeepEconomy.geode_rough(stone) if DeepStone.is_geode(stone) else DeepStone.value(stone)
			## Only the stones go up: pyrite is lost when a run ends (docs/GOLD.md 4.3), and
			## "it all" read as if the purse rode home too.
			DeepUi.wrap(box, "You're carrying %s, worth roughly %d gold. The lift takes your stones home. Pyrite left after the fare stays in the mine." % [DeepUi.plural(haul.size(), "stone"), worth], 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 300)
			var landing: Dictionary = run.get("landing", {})
			if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)) and not DeepDescent.run_is_boss(run, int(run.get("depth", 0))):
				var last: Label = DeepUi.stat(box, "crown", LAST_LIFT, DeepUi.BAD, 12).get_node("Value")
				last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				last.custom_minimum_size.x = 280
			## The winch wants paying, and it wants more the deeper the cage has to come up from.
			## The party pays it between them, so what matters is the pooled pyrite.
			var fare: int = DeepDescent.lift_cost(run)
			## Pooled the way the winch counts it: whoever is standing and still on the line.
			## Someone away keeps their pocket, and counting it here offered a ride the rules
			## then refused.
			var pooled: int = 0
			for other in DeepDescent.living(run):
				pooled += int(other.get("ore", 0))
			var afford: bool = pooled >= fare
			DeepUi.stat(box, "ore", "The winch wants %d pyrite from depth %d · %s %d" % [fare, int(run.get("depth", 1)), "the party has" if run.get("players", []).size() > 1 else "you have", pooled],
				DeepUi.ORE if afford else DeepUi.BAD, 12)
			var party: bool = run.get("players", []).size() > 1
			var asked_by: String = DeepDescent.lift_asked_by(run)
			if party:
				DeepUi.label(box, "Riding up is asked of the whole party: everyone answers, the cage or a way down. Most of the party wins, and it pays the winch between them." if asked_by.is_empty()
					else "%s asked the party to ride up. Most of the party wins, and it pays the winch between them." % str(DeepDescent.player(run, asked_by).get("name", "Someone")), 11, DeepUi.DIM)
				_vote_lines(box)
			if pinned:
				var words: String = "Ride up · %d" % fare
				if party and asked_by.is_empty():
					words = "Ask the party to ride up · %d" % fare
				elif party and asked_by != local_id:
					words = "Ride up too · %d" % fare
				var ride := DeepUi.primary(box, "lift", words, func() -> void:
					_pin("")
					DeepAudio.play("lift")
					command.emit({"kind": "choose", "choice": "lift"}), 14, DeepUi.GOOD)
				ride.disabled = str(unit.get("choice", "")) == "lift" or not afford or bool(unit.get("downed", false))
				if bool(unit.get("downed", false)):
					DeepUi.label(box, "You are down. The party decides; you ride with it.", 11, DeepUi.BAD)
				elif not afford:
					DeepUi.label(box, ("The party can't afford" if run.get("players", []).size() > 1 else "You can't afford") + " the lift yet. Keep digging.", 11, DeepUi.BAD)
			else:
				DeepUi.label(box, "Click to take the lift.", 12, DeepUi.DIM)
			return true
	return false

func _end_ready() -> void:
	_end_shown = true
	show_state(run)

# --- the hoard -----------------------------------------------------------------------------------

func _show_hoard() -> void:
	var mine_hoard: Dictionary = run.get("hoard", {}).get(local_id, {})
	var offers: Array = mine_hoard.get("offers", [])
	var chosen: String = str(mine_hoard.get("chosen", ""))
	var pile: Node3D = _stage.hoard(offers, chosen)
	if pile != null:
		for stone in offers:
			var id: String = "hoard:%s" % str(stone.id)
			var key: String = str(stone.id)
			if not _stage.has_pick(id) and pile.spot(key) != null:
				_stage.add_pick(id, pile.spot(key), Vector3(0.45, 0.45, 0.45), {"hover": func(on: bool) -> void:
					if is_instance_valid(pile):
						pile.set_hover(key, on)})
			_stage.enable_pick(id, chosen.is_empty())
	_crossroads.visible = true
	_set_cross_mark("crown", DeepUi.CHAMBER_colorS.get("warden", DeepUi.BAD))
	_cross_title.text = "The final boss's hoard" if DeepDescent.run_is_boss(run, int(run.get("depth", 0))) else "The Warden's hoard"
	if not run.get("hoard", {}).has(local_id):
		## Down when it opened: the pedestals are for those still standing.
		_cross_sub.text = "You went down in the fight, so the hoard is for the others. You get back on your feet at the next landing."
	else:
		var has_geode: bool = offers.any(func(s: Dictionary) -> bool: return DeepStone.is_geode(s))
		_cross_sub.text = ("Take one. The stones are raw, so you can only see their color and size." + (" The Geode is sealed: its stone is better, but only the workshop can crack it." if has_geode else "")) if chosen.is_empty() else "Yours is picked."
	DeepUi.clear(_cross_hint)
	## Who has picked and who is still choosing is on their tabs.
	_fill_chip()

func _hoard_chip(box: VBoxContainer, id: String, key: String) -> bool:
	var mine_hoard: Dictionary = run.get("hoard", {}).get(local_id, {})
	for stone in mine_hoard.get("offers", []):
		if str(stone.id) != key:
			continue
		if DeepStone.is_geode(stone):
			_hoard_geode_chip(box, stone, id, key, mine_hoard)
			return true
		var read: bool = bool(stone.get("appraised", false))
		var grade: Dictionary = DeepStone.grade(stone)
		var tone: Color = DeepUi.tier_color(str(grade.tier)) if read else DeepUi.color(DeepStone.color(stone))
		var head := DeepUi.hbox(box, 8)
		StoneCard.mini(head, stone, 40)
		var words := DeepUi.vbox(head, 1)
		if read:
			DeepUi.title(words, str(DeepStone.skill_of(stone).get("name", "")), 18, tone)
			DeepUi.label(words, "%s %s · %d ct · %s" % [DeepContent.cut_name(int(stone.cut)), DeepContent.clarity_name(int(stone.clarity)), int(stone.carat), str(grade.name)], 12, DeepUi.MUTED)
			DeepUi.wrap(box, DeepStone.text(stone), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 300)
			for inclusion in stone.get("inclusions", []):
				DeepUi.stat(box, "spark", str(DeepContent.inclusion(str(inclusion)).get("name", inclusion)), DeepUi.INFO, 12)
		else:
			## Still in its rock: a color and a size class, and not one word about what it is.
			DeepUi.title(words, DeepStone.raw_name(stone), 18, tone)
			StoneCard.size_stat(words, stone, 12)
			DeepUi.label(box, "Not appraised yet. Its skill, cut and inclusions are unknown.", 12, DeepUi.MUTED)
		if _pinned == id:
			var take := DeepUi.primary(box, "check", "Take it", func() -> void:
				command.emit({"kind": "pick_hoard", "stone_id": key}), 14, tone)
			take.disabled = not str(mine_hoard.get("chosen", "")).is_empty()
		else:
			DeepUi.label(box, "Click to choose it.", 12, DeepUi.DIM)
		return true
	return false

func _hoard_geode_chip(box: VBoxContainer, stone: Dictionary, id: String, key: String, mine_hoard: Dictionary) -> void:
	## A Geode on a pedestal: the rock, what kind, and that it cannot be opened down here.
	var geode: Dictionary = stone.geode
	var Geode: Script = load("res://view/gems/geode.gd")
	var tone: Color = Geode.theme_tone(geode)
	var head := DeepUi.hbox(box, 8)
	StoneCard.mini(head, stone, 44)
	var words := DeepUi.vbox(head, 1)
	DeepUi.title(words, DeepStone.raw_name(stone), 18, tone.lightened(0.2))
	DeepUi.label(words, str(Geode.geode_line(geode)), 12, DeepUi.MUTED)
	var odds: Dictionary = DeepEconomy.geode_odds(geode)
	var carats: Array = odds.get("carat", [1, 1])
	DeepUi.stat(box, "carat", "%d to %d ct inside" % [int(carats[0]), int(carats[1])], DeepUi.ACCENT, 12, "Every stone in this kind of Geode weighs this much.")
	DeepUi.wrap(box, DeepUi.touch_words("Sealed. A better stone than the rock gives, but it can only be cracked at the workshop: it cannot be read or set down here. Right-click for its odds."), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 300)
	if _pinned == id:
		var take := DeepUi.primary(box, "check", "Take it", func() -> void:
			command.emit({"kind": "pick_hoard", "stone_id": key}), 14, tone)
		take.disabled = not str(mine_hoard.get("chosen", "")).is_empty()
	else:
		DeepUi.label(box, "Click to choose it.", 12, DeepUi.DIM)

# --- an oddity -----------------------------------------------------------------------------------

func _oddity_tone(kind: String) -> Color:
	## An oddity's violet, or the color of the room whose card it is.
	return DeepUi.CHAMBER_colorS.get(kind, DeepUi.CHAMBER_colorS.oddity)

func _show_oddity() -> void:
	## The room's mark, its name and what it is stand together at the top of the screen; the
	## choices sit along the bottom over the dock, and the room itself is left clear between
	## them so the thing the party has walked up to can be seen.
	var key: String = str(run.chamber.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var tone: Color = _oddity_tone(str(run.chamber.get("kind", "oddity")))
	## Most cards stand on a plinth with their mark burning over it. The well is a well, and
	## the Smithy, the Carver, the Rest Stop and a few more have their own furniture (CardProps).
	if key == "WISHING_WELL":
		_stage.well()
	else:
		_stage.shrine(str(ODDITY_GLYPHS.get(key, "question")), tone, key)
		_stage.hush_shrine((_ask != null and _ask.is_open()) or _shrine_covered)
	_crossroads.visible = true
	_set_cross_mark(str(ODDITY_GLYPHS.get(key, "question")), tone)
	_cross_title.text = str(oddity.get("name", "Something odd"))
	_cross_sub.text = str(oddity.get("text", ""))
	DeepUi.clear(_cross_hint)
	## A Smith's Voucher spent on walking in (docs/DEEP_START.md §4): said under the room's
	## name, with how many are left for the rooms after this one.
	## A lucky room (one in twenty) is upgraded for the whole party, free.
	match bench_upgrade():
		"voucher":
			var left: int = int(me().get("vouchers", 0))
			var said: String = "Smith's Voucher: better work here · %s" % ("%d more after this" % left if left > 0 else "your last one")
			DeepUi.pill(_cross_hint, "spark", said, DEEP_TONE, 13, "One is spent on every smithy or carver you walk into, whether or not you take the work.").name = "BenchHint"
		"luck":
			DeepUi.pill(_cross_hint, "spark", "A good day at the bench: better work here, free", DEEP_TONE, 13, "Now and then a bench is in fine form: everyone gets the better work, no voucher spent.").name = "BenchHint"
	_page_oddity(_bottom_page(), false)

func _set_cross_mark(glyph: String, tone: Color) -> void:
	## The medallion over a room's name, or the air where one would be.
	DeepUi.clear(_cross_mark)
	if glyph.is_empty():
		_cross_mark.custom_minimum_size.y = 0.0 if DeepUi.phone else 14.0
		return
	_cross_mark.custom_minimum_size.y = 0.0
	_cross_mark.add_child(Medallion.new(glyph, tone, DeepUi.pt(34) if DeepUi.phone else 84.0))

func _centre_page() -> VBoxContainer:
	## A page in the middle of whatever room is behind it, clear of the strip and the dock.
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 14.0
	holder.offset_bottom = - (_run_dock.height() if _run_dock.visible else 24.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_holder.add_child(holder)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(centre)
	return DeepUi.vbox(centre, 14)

## How far above the dock's plate a page along the bottom of the room stands, and the way-out
## key in its corner with it, on the desk and the phone alike.
const PAGE_FOOT: float = 20.0

func _page_foot() -> float:
	## The gap left under a bottom page inside the room: PAGE_FOOT, less what the dock keeps
	## clear above its plate already (the desk's 14 pixels; the phone's bar keeps none).
	return maxf(0.0, PAGE_FOOT - (14.0 if _run_dock.visible and not DeepUi.phone else 0.0))

func _bottom_page() -> VBoxContainer:
	## A page along the bottom of the room, above the dock, leaving the room above it clear.
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("separation", 0)
	_page_holder.add_child(holder)
	var content := DeepUi.vbox(holder, 12)
	content.alignment = BoxContainer.ALIGNMENT_END
	## A way-out key in the corner gives way to whatever the page lays out beside it.
	content.sort_children.connect(_place_way_out, CONNECT_DEFERRED)
	DeepUi.gap(holder, _page_foot())
	_bottom_content = content
	return content

func _way_out(text: String, callback: Callable, back: bool = false, tip: String = "") -> Button:
	## The way out of a page (the owner's pick, November 9, 2026, docs/UI_REDO.md): a key with
	## its words on it in a corner of the room, Leave it bottom-right and Back bottom-left, its
	## foot on the bottom page's, instead of an arrow off the end of the page's row.
	_drop_way_out()
	var key := DeepUi.way_out(text, callback, back, tip)
	_page_holder.add_child(key)
	_way_out_key = key
	_place_way_out()
	## Once more when the page's rows have been laid out, a frame on: what it gives way to
	## knows where it stands only then.
	if is_inside_tree() and not get_tree().process_frame.is_connected(_place_way_out):
		get_tree().process_frame.connect(_place_way_out, CONNECT_ONE_SHOT)
	return key

func _check_shrine_cover() -> void:
	## On the phone a card can stand where an oddity's mark floats over its plinth (the Old
	## Prospector's stood on the card's top edge, the Collector's showed through a dimmed one):
	## the mark goes out while one does (November 9, 2026).
	if not DeepUi.phone or _stage == null or not is_instance_valid(_stage):
		return
	var covered: bool = false
	if str(run.get("phase", "")) == "chamber" and _bottom_content != null and is_instance_valid(_bottom_content):
		var mark: Rect2 = _stage.shrine_rect()
		if mark.size != Vector2.ZERO:
			var at := Rect2(_stage.get_global_rect().position + mark.position, mark.size)
			for rect in _page_things():
				if (rect as Rect2).intersects(at):
					covered = true
	if covered != _shrine_covered:
		_shrine_covered = covered
		_hush_room_words()

func _drop_way_out() -> void:
	## The key of a page no longer on show (a stall, a vein or an altar drawn again) goes.
	if _way_out_key != null and is_instance_valid(_way_out_key):
		_way_out_key.queue_free()
	_way_out_key = null

func _clear_pages() -> void:
	## Every page over the room goes, and its way out with it.
	DeepUi.clear(_page_holder)
	_way_out_key = null
	_bottom_content = null

func _place_way_out() -> void:
	## The key's corner: the dock's edge on the desk (the bag's while it is open, for a key on
	## the right), the safe edge on the phone. Where a page's own things come nearer the edge
	## than the key is wide (or stand on it from above), it gives way rather than lie over or
	## against them. A row of cards steps aside first, as far as its other side has room
	## (a phone's Vat, three cards with chips on them); only then does the key go on toward
	## the edge, on the phone into the safe edge's inset, which the owner allowed for it
	## (November 9, 2026).
	_check_shrine_cover()
	var key: Button = _way_out_key
	if key == null or not is_instance_valid(key) or not key.is_inside_tree():
		return
	var back: bool = bool(key.get_meta("back", false))
	var want: Vector2 = key.get_combined_minimum_size()
	var room: Vector2 = _page_holder.size
	var inset: float = (DeepUi.safe_left if back else DeepUi.safe_right) if DeepUi.phone else 16.0
	if not back and _run_dock.visible:
		inset = maxf(inset, _run_dock.column_width())
	## The room's other side, which a row stepping aside may come up to and no further.
	var far: float = (DeepUi.safe_right if back else DeepUi.safe_left) if DeepUi.phone else 16.0
	var top: float = room.y - _page_foot() - want.y
	var rest: float = inset if back else room.x - inset - want.x
	var gap: float = DeepUi.pt(6) if DeepUi.phone else 12.0
	var origin: Vector2 = _page_holder.get_global_rect().position
	## Where the key would stand for the rows (as each would stand centred, before any step
	## aside it took) and for everything else, and how much room each row has on its far side.
	var for_rows: float = rest
	var for_rest: float = rest
	var slack: float = INF
	var rows: Array = []
	for item in _page_items():
		var row: Variant = item.row
		if row != null and (row as HBoxContainer).alignment != BoxContainer.ALIGNMENT_CENTER:
			row = null
		var at: Rect2 = Rect2(item.rect.position - origin + Vector2(_row_aside(row) if row != null else 0.0, 0.0), item.rect.size)
		if at.end.y <= top - gap or at.position.y >= top + want.y:
			continue
		var clear: float = (at.position.x - gap - want.x) if back else (at.end.x + gap)
		if row == null:
			for_rest = minf(for_rest, clear) if back else maxf(for_rest, clear)
			continue
		for_rows = minf(for_rows, clear) if back else maxf(for_rows, clear)
		slack = minf(slack, (room.x - far - at.end.x) if back else (at.position.x - far))
		if not rows.has(row):
			rows.append(row)
	var step: float = 0.0
	var over: float = (rest - for_rows) if back else (for_rows - rest)
	if over > 0.5 and not rows.is_empty():
		step = clampf(over, 0.0, maxf(0.0, slack))
	var went: float = 0.0
	if _bottom_content != null and is_instance_valid(_bottom_content):
		for child in _bottom_content.get_children():
			if child is HBoxContainer and (child as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER:
				var moved: float = _step_aside(child, step if rows.has(child) else 0.0, back)
				if rows.has(child):
					went = moved
	var left: float = (for_rows + went) if back else (for_rows - went)
	left = minf(left, for_rest) if back else maxf(left, for_rest)
	var edge: float = DeepUi.pt(6) if DeepUi.phone else 4.0
	left = clampf(left, edge, maxf(edge, room.x - edge - want.x))
	## Where it would cover something in the room to be clicked or dropped on (the phone's
	## altar, pushed right by the open bag, has a socket in that corner), a way on takes the
	## other bottom corner instead, if that one is clear (November 9, 2026).
	if not back and _covers_pick(Rect2(origin + Vector2(left, top), want)):
		var other: float = DeepUi.safe_left if DeepUi.phone else 16.0
		var clear: bool = not _covers_pick(Rect2(origin + Vector2(other, top), want))
		for item in _page_items():
			if (item.rect as Rect2).intersects(Rect2(origin + Vector2(other, top), want).grow(gap)):
				clear = false
		if clear:
			left = other
	key.size = want
	key.position = Vector2(left, top).round()

func _covers_pick(rect: Rect2) -> bool:
	## Whether a rectangle on the screen lies over something in the room that is clicked or
	## dropped on (an altar's socket, a rock in a vein, a stall's goods).
	if _stage == null or not is_instance_valid(_stage) or not _stage.visible:
		return false
	var origin: Vector2 = _stage.get_global_rect().position
	for id in _stage.pick_ids():
		var at: Rect2 = _stage.pick_rect(str(id))
		if at.size != Vector2.ZERO and Rect2(origin + at.position, at.size).intersects(rect):
			return true
	return false

func _step_aside(row: HBoxContainer, step: float, back: bool) -> float:
	## Moves a centred row `step` away from the way-out key, with an empty column on the key's
	## side, and returns how far it really went (the column carries the row's separation with
	## it, so a step is never less than half of that).
	var room_for: Control = row.get_node_or_null("WayRoom")
	if step < 0.5:
		if room_for != null and room_for.visible:
			room_for.visible = false
			room_for.custom_minimum_size.x = 0.0
		return 0.0
	if room_for == null:
		room_for = Control.new()
		room_for.name = "WayRoom"
		room_for.set_meta("way_room", true)
		room_for.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(room_for)
		if back:
			row.move_child(room_for, 0)
	var separation: float = float(row.get_theme_constant("separation"))
	var width: float = maxf(0.0, roundf(step * 2.0 - separation))
	if not room_for.visible or absf(room_for.custom_minimum_size.x - width) > 0.5:
		room_for.custom_minimum_size.x = width
		room_for.visible = true
	return (width + separation) * 0.5

func _row_aside(row: HBoxContainer) -> float:
	## How far a centred row's own things stand from where they would stand centred, as it is
	## laid out now (to the left is more than nothing): measured, not remembered, so a placing
	## between a step's asking and its laying out reads the row where it really is.
	var first: Control = null
	var total: float = 0.0
	var count: int = 0
	for item in row.get_children():
		if item is Control and (item as Control).visible and not item.has_meta("way_room"):
			if first == null:
				first = item
			total += (item as Control).size.x
			count += 1
	if first == null:
		return 0.0
	total += float(row.get_theme_constant("separation")) * float(maxi(0, count - 1))
	return (row.size.x - total) * 0.5 - first.position.x

func _page_items() -> Array:
	## Where the bottom page's own things stand on screen: each of a row's children (with the
	## row, which can step aside for the way-out key), and anything else that is only as wide
	## as itself (a pill, a centred button), with no row.
	var out: Array = []
	if _bottom_content == null or not is_instance_valid(_bottom_content):
		return out
	for child in _bottom_content.get_children():
		if not child is Control or not (child as Control).visible:
			continue
		if child is HBoxContainer:
			for item in child.get_children():
				if item is Control and (item as Control).visible and (item as Control).size.x > 0.5 and not item.has_meta("way_room"):
					out.append({"rect": (item as Control).get_global_rect(), "row": child})
		elif (child as Control).size_flags_horizontal & Control.SIZE_FILL == 0:
			out.append({"rect": (child as Control).get_global_rect(), "row": null})
	return out

func _page_things() -> Array:
	## Where the bottom page's own things stand on screen, in a list of rectangles.
	var out: Array = []
	for item in _page_items():
		out.append(item.rect)
	return out

func _side_page() -> VBoxContainer:
	## A page down the right side of the room, as tall as the room.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.9), DeepUi.LINE, 16, 16, 0.5))
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -560
	panel.offset_right = -20
	panel.offset_top = 20
	panel.offset_bottom = -20
	if DeepUi.phone:
		## The phone's side page (board run-menu): 310 points down the right side, the room's
		## height, running to the screen's edge with its words inside the safe edge.
		var side := StyleBoxFlat.new()
		side.bg_color = DeepUi.LEDGER_FILL
		side.border_color = DeepUi.ACCENT_DIM
		side.border_width_left = int(DeepUi.pt(1.5))
		side.content_margin_left = DeepUi.pt(10)
		side.content_margin_right = DeepUi.safe_right + DeepUi.pt(8)
		side.content_margin_top = DeepUi.pt(8)
		side.content_margin_bottom = DeepUi.pt(8)
		panel.add_theme_stylebox_override("panel", side)
		panel.offset_left = -(DeepUi.pt(310) + DeepUi.safe_right)
		panel.offset_right = 0.0
		panel.offset_top = 0.0
		panel.offset_bottom = 0.0
	_page_holder.add_child(panel)
	var content := DeepUi.vbox(panel, 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

# --- the crossroads ----------------------------------------------------------------------------

func _build_crossroads() -> void:
	## What the mouths cannot say for themselves: which depth, what the party is choosing, the
	## lantern, and (over the mouth under the cursor) what waits down it and past it.
	_crossroads = Control.new()
	_crossroads.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crossroads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crossroads.visible = false
	_body.add_child(_crossroads)
	## A soft shade behind the room's name and its line of help, so they read the same over a
	## lamp-lit wall as over shadow. The radial light every halo uses, turned dark.
	var shade := TextureRect.new()
	shade.texture = DeepUi.glow_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.modulate = Color(0.0, 0.0, 0.02, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Centred on the name and the line under it, and wide enough that the line's ends are
	## still well inside the shade rather than out at its faint edge.
	shade.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	shade.offset_left = -820.0
	shade.offset_right = 820.0
	shade.offset_top = 30.0
	shade.offset_bottom = 235.0
	_crossroads.add_child(shade)
	var head := DeepUi.vbox(_crossroads, 2)
	_cross_head = head
	_cross_shade = shade
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DeepUi.phone:
		head.offset_top = DeepUi.pt(2)
		head.add_theme_constant_override("separation", 0)
		shade.offset_left = -DeepUi.pt(380)
		shade.offset_right = DeepUi.pt(380)
		shade.offset_top = -DeepUi.pt(10)
		shade.offset_bottom = DeepUi.pt(70)
	## A mark over the name, where a room has one. Where it has none the space it would have
	## taken is kept as air, so the name never sits hard against the top of the screen. On the
	## phone the mark stands beside the name, in one row.
	var name_row: Control = head
	if DeepUi.phone:
		name_row = DeepUi.hbox(head, int(DeepUi.pt(8)))
		(name_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_mark = DeepUi.center(name_row)
	_cross_mark.custom_minimum_size.y = 0.0 if DeepUi.phone else 14.0
	_cross_title = DeepUi.title(name_row, "", 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_cross_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_cross_title.add_theme_constant_override("outline_size", 9)
	_cross_sub = DeepUi.label(head, "", 15, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_cross_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cross_sub.custom_minimum_size.x = DeepUi.pt(640) if DeepUi.phone else 880
	_cross_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_cross_sub.add_theme_constant_override("outline_size", 6)
	DeepUi.gap(head, 6)
	_cross_hint = DeepUi.hbox(head, 10)
	_cross_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_cross_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Under the room's own marks, the one line a party gets while this player waits on it.
	_cross_wait = DeepUi.hbox(head, 8)
	_cross_wait.alignment = BoxContainer.ALIGNMENT_CENTER
	_cross_wait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_wait.visible = false
	## And under that, what the party asks of this player at a landing (see `_sync_party_asks`).
	_cross_ask = DeepUi.hbox(head, 10)
	_cross_ask.alignment = BoxContainer.ALIGNMENT_CENTER
	_cross_ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross_ask.visible = false
	## The others' choices hang over the room, under the plate of whatever is pointed at.
	_vote_tags = Control.new()
	_vote_tags.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vote_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crossroads.add_child(_vote_tags)
	_chip = PanelContainer.new()
	_chip.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.04, 0.05, 0.07, 0.93), DeepUi.LINE_HI, 14, 12, 0.5))
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.visible = false
	_crossroads.add_child(_chip)

func _show_crossroads() -> void:
	_crossroads.visible = true
	_set_cross_mark("", DeepUi.ACCENT)
	var next_depth: int = int(run.get("depth", 0)) + 1
	## The floor the ways lead to, said as the floor ahead: the strip names the one underfoot.
	_cross_title.text = "Down to depth %d" % next_depth
	## Only those standing and on the line vote: someone away or down leaves the choice to the rest.
	var sub: String = "Choose a way. The party goes where most of it points; a split vote is a coin toss." if DeepDescent.living(run).size() > 1 else "Choose a way."
	## This run's own landings, not the written every-fourth: each one wanders a floor either way.
	var landing: bool = DeepDescent.run_is_landing(run, next_depth)
	if landing:
		sub = "The shaft opens onto a landing."
	_cross_sub.text = sub
	DeepUi.clear(_cross_hint)
	if not run.get("map", {}).is_empty() and not landing:
		var lit: bool = DeepDescent.lit_to(run) >= mini(next_depth, int(run.map.get("to", 0)))
		var note := PanelContainer.new()
		note.add_theme_stylebox_override("panel", DeepUi.facet_ends(note, DeepUi.raised(Color(0.04, 0.05, 0.07, 0.88), DeepUi.LINE, 14, 8, 0.4)))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross_hint.add_child(note)
		var row := DeepUi.hbox(note, 8)
		DeepUi.icon(row, "lantern", 18, DeepUi.ACCENT)
		DeepUi.label(row, "The next floor is lit. The chart shows two floors ahead." if lit else ("Your lantern shows two floors ahead. Tap a tunnel to take it, hold it to see where it leads." if DeepUi.phone else "Your lantern shows two floors ahead. Hover a tunnel to see where it leads."), 13, DeepUi.MUTED)
		if DeepDescent.needs_light(run):
			var button := DeepUi.icon_button(_cross_hint, "lantern", "Light the way · %d pyrite" % DeepDescent.lantern_cost(), func() -> void: command.emit({"kind": "light"}), 13, DeepUi.ACCENT)
			button.disabled = int(me().get("ore", 0)) < DeepDescent.lantern_cost() or bool(me().get("downed", false))
			button.mouse_filter = Control.MOUSE_FILTER_STOP
	var entries: Array = crossroads_entries()
	_stage.crossroads(entries)
	if _chip_index >= entries.size():
		_chip_index = -1
	_fill_chip()

func crossroads_entries() -> Array:
	## One per way on, in the order the mouths stand: what each mouth shows.
	return _entries_for(_mouth_offers())

func _mouth_offers() -> Array:
	## The ways on the mouths stand for: the ones offered, or at a landing the ways down, as
	## the chart has them, before anyone has chosen to go down.
	if str(run.get("phase", "")) != "landing":
		return run.get("offers", [])
	var landing: Dictionary = run.get("landing", {})
	if DeepDescent.in_boss_hall(run):
		## One way on from the bottom of a mine: into the top of the next.
		return [] if DeepDescent.next_mine(run).is_empty() else [ {"id": "next_mine", "kind": "next_mine", "hidden": false}]
	if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
		return [ {"id": "warden", "kind": "warden", "hidden": false}]
	var map: Dictionary = run.get("map", {})
	var out: Array = []
	for id in DeepDescent.row_of(map, int(run.get("depth", 0)) + 1):
		var node: Dictionary = map.get("nodes", {}).get(str(id), {})
		out.append({"id": str(id), "kind": str(node.get("kind", "fight")), "hidden": bool(node.get("hidden", false))})
	return out

func _entries_for(offers: Array) -> Array:
	var out: Array = []
	var nodes: Dictionary = run.get("map", {}).get("nodes", {})
	var landing: bool = str(run.get("phase", "")) == "landing"
	var mine_vote: String = str(me().get("vote", ""))
	for offer in offers:
		var node: Dictionary = nodes.get(str(offer.id), {})
		var seen: bool = DeepDescent.revealed(run, node) if not node.is_empty() else not bool(offer.get("hidden", false))
		var kind: String = str(offer.kind) if seen else "hidden"
		var voters: Array = []
		for other in run.get("players", []):
			var chose: bool = _went_by(other, offer, offers.size()) if landing else str(other.get("vote", "")) == str(offer.id)
			if chose:
				voters.append(ShaftMap.SEATS[int(other.get("seat", 0)) % ShaftMap.SEATS.size()])
		var color: Color = DeepUi.CHAMBER_colorS.get(kind, DeepUi.MUTED)
		var glyph: String = str(DeepUi.CHAMBER_GLYPHS.get(kind, "arch")) if kind != "hidden" else "question"
		if kind == "next_mine":
			color = Color(str(DeepContent.mine(DeepDescent.next_mine(run)).get("palette", "b58cff")))
			glyph = "descend"
		out.append({"id": str(offer.id), "kind": kind, "color": color, "light": Color("ffcf8a") if kind == "landing" else color,
			"glyph": glyph, "hidden": kind == "hidden",
			"voters": voters, "mine": _went_by(me(), offer, offers.size()) if landing else mine_vote == str(offer.id)})
	return out

func _went_by(unit: Dictionary, offer: Dictionary, mouths: int) -> bool:
	## At a landing, whether this player chose to go down by this mouth: the one they clicked,
	## or the only one there is. Going down is one choice; it is shown at one mouth, not all.
	if str(unit.get("choice", "")) != "descend":
		return false
	var via: String = str(unit.get("via", ""))
	return via == str(offer.get("id", "")) or (via.is_empty() and mouths == 1)

func _hover_mouth(index: int) -> void:
	_chip_index = index
	if index >= 0:
		_chip_pick = ""
	var offers: Array = _mouth_offers()
	_map.focus = str(offers[index].id) if index >= 0 and index < offers.size() else ""
	_fill_chip()

func _choose_mouth(index: int) -> void:
	var offers: Array = _mouth_offers()
	if index < 0 or index >= offers.size():
		return
	## A tap takes it on the phone as a click does on the desk; a finger held on the mouth
	## shows where it leads instead (MineStage.mouth_held), and that plate has its own Go.
	match str(run.get("phase", "")):
		"tunnels":
			_vote(str(offers[index].id))
		"landing":
			## Down this way: the party chooses to go down, and this mouth gets the vote. The
			## respite is there to be taken, not to be waited on. A boss's hall has only the
			## way into the mine below, and the ways on from that mine's head are chosen there.
			if bool(me().get("downed", false)):
				toast("You are down. The living choose the way.", DeepUi.BAD, "skull")
				return
			_descend_via = index if str(offers[index].get("kind", "")) != "next_mine" else -1
			DeepAudio.play("tunnel", {"volume": 0.6})
			command.emit({"kind": "choose", "choice": "descend", "via": str(offers[index].get("id", ""))})

func _vote(offer_id: String) -> void:
	## The living choose the way on. A fallen lapidary is carried, and gets back on their feet
	## at the next landing.
	if bool(me().get("downed", false)):
		toast("You are down. The living choose the way.", DeepUi.BAD, "skull")
		return
	command.emit({"kind": "vote_tunnel", "offer": offer_id})

func _fill_chip() -> void:
	## Over the mouth under the cursor: what waits down it, what lies past that as far as the
	## lantern shows, and who has chosen it.
	DeepUi.clear(_chip)
	## Under an ask or a landing's page the room's plate would only give the old instruction
	## (the well's "Drop a stone here" behind its own sheet): the page says what to do.
	if (_ask != null and _ask.is_open()) or not _landing_view.is_empty():
		_chip.visible = false
		return
	_chip.mouse_filter = Control.MOUSE_FILTER_STOP if not _pinned.is_empty() else Control.MOUSE_FILTER_IGNORE
	if not _chip_pick.is_empty():
		var said: bool = _pick_chip(DeepUi.vbox(_chip, 6), _chip_pick)
		_chip.visible = said
		if said:
			_chip.reset_size()
			_place_chip()
		return
	var offers: Array = _mouth_offers()
	if _chip_index < 0 or _chip_index >= offers.size():
		_chip.visible = false
		return
	var offer: Dictionary = offers[_chip_index]
	var entry: Dictionary = crossroads_entries()[_chip_index]
	var down: bool = str(run.get("phase", "")) == "landing"
	var kind: String = str(entry.kind)
	var tone: Color = entry.color
	var box := DeepUi.vbox(_chip, 6)
	var title_row := DeepUi.hbox(box, 8)
	DeepUi.icon(title_row, str(entry.glyph), 22, tone)
	var called: String = str(KIND_WORDS.get(kind, kind.capitalize()))
	if kind == "warden" and DeepDescent.run_is_boss(run, int(run.get("depth", 0))):
		called = "The final boss's hall"
	if kind == "next_mine":
		var below: Dictionary = DeepContent.mine(DeepDescent.next_mine(run))
		DeepUi.title(title_row, "On into " + str(below.get("name", "the next mine")), 19, tone.lightened(0.25))
		DeepUi.wrap(box, str(below.get("text", "")), 12 if DeepUi.phone else 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, DeepUi.pt(190) if DeepUi.phone else 300.0)
		var band: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(below, DeepDescent.hazard_tier(run)), 1)
		DeepUi.stat(box, "gem", "Stones up to %d carats, usually %d or less" % [int(band.get("cap", 0)), int(band.get("soft", 0))], DeepUi.ACCENT, 12)
		DeepUi.stat(box, "skull", "Its creatures are far tougher, and bred deeper for a party that pushes on", DeepUi.BAD, 12)
		DeepUi.stat(box, "lift", "Nothing is banked: a fall loses everything from both mines", DeepUi.MUTED, 12)
		if DeepUi.phone:
			_go_button(box, _chip_index, "Push on")
		else:
			DeepUi.label(box, "Click to push on.", 12, DeepUi.DIM)
		_chip.visible = true
		_chip.reset_size()
		_place_chip()
		return
	DeepUi.title(title_row, ("Down: " + called) if down else called, 19, tone.lightened(0.25))
	var kind_text: String = str(KIND_TEXT.get(kind, ""))
	## Alone, the Warden stands between you and the way on, not "the party".
	if kind == "warden" and run.get("players", []).size() <= 1:
		kind_text = kind_text.replace("between the party and", "between you and")
	DeepUi.wrap(box, kind_text, 12 if DeepUi.phone else 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, DeepUi.pt(190) if DeepUi.phone else 300.0)
	var nodes: Dictionary = run.get("map", {}).get("nodes", {})
	var node: Dictionary = nodes.get(str(offer.id), {})
	if str(offer.kind) == "landing" and bool(node.get("warden", false)):
		## The landing comes first; its Warden waits in the hall past it.
		var boss: bool = DeepDescent.run_is_boss(run, int(node.get("depth", 0)))
		DeepUi.stat(box, "crown", "Past it, the %s guards the way on down." % ("final boss" if boss else "Warden"), DeepUi.BAD, 12)
	elif str(offer.kind) != "landing" and not node.is_empty():
		var leads := DeepUi.hbox(box, 6)
		DeepUi.label(leads, "then", 12, DeepUi.DIM)
		for child in node.get("next", []):
			var after: Dictionary = nodes.get(str(child), {})
			if after.is_empty():
				continue
			var shows: bool = DeepDescent.revealed(run, after)
			var after_kind: String = str(after.kind) if shows else "hidden"
			var mark: Color = DeepUi.CHAMBER_colorS.get(after_kind, DeepUi.MUTED)
			var glyph: String = str(DeepUi.CHAMBER_GLYPHS.get(after_kind, "arch"))
			if not shows:
				var glint: String = DeepDescent.glint(after)
				glyph = str(ShaftMap.GLINT_GLYPHS.get(glint, "question"))
				mark = Color(ShaftMap.GLINT_TONES.get(glint, DeepUi.DIM), 0.85)
			DeepUi.pill(leads, glyph, "", mark, 12)
	var voters: Array = []
	for other in run.get("players", []):
		if str(other.get("vote", "")) == str(offer.id):
			voters.append(str(other.name))
	if down:
		if kind == "warden":
			var boss_below: bool = DeepDescent.run_is_boss(run, int(run.get("depth", 0)))
			DeepUi.stat(box, "crown", "Going down means fighting the %s first." % ("final boss" if boss_below else "Warden"), DeepUi.BAD, 12)
		_vote_lines(box)
		if DeepUi.phone and not DeepDescent.needs_respite(run, me()) and DeepDescent.at_crossroads(run):
			_go_button(box, _chip_index, "Go down this way")
		else:
			DeepUi.label(box, "Take a respite first." if DeepDescent.needs_respite(run, me()) else ("The way on opens once everyone has taken their respite." if not DeepDescent.at_crossroads(run) else "Click to go down this way."), 12, DeepUi.DIM)
	elif bool(entry.mine):
		DeepUi.stat(box, "check", "your pick" + ("" if voters.size() <= 1 else "  ·  " + ", ".join(voters)), DeepUi.GOOD, 12)
	elif not voters.is_empty():
		DeepUi.stat(box, "person", "%s %s this way" % [names_of(voters), "want" if voters.size() > 1 else "wants"], DeepUi.ACCENT, 12)
	elif not DeepUi.phone:
		DeepUi.label(box, "Click to go this way.", 12, DeepUi.DIM)
	if DeepUi.phone and not down:
		_go_button(box, _chip_index, "Change my vote" if bool(entry.mine) else "Go this way")
	_chip.visible = true
	_chip.reset_size()
	_place_chip()

func _go_button(box: VBoxContainer, index: int, words: String) -> void:
	## The phone's way down a tunnel whose plate a tap brought up.
	_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var go := DeepUi.primary(box, "descend", words, func() -> void: _choose_mouth(index), 13)
	go.custom_minimum_size.y = DeepUi.pt(36)

func _place_chip() -> void:
	## Put down once and left there. What a chip hangs over is rarely still — a stone on a
	## pedestal turns and bobs, a creature breathes — and a tooltip that rode every one of
	## those movements could not be read, let alone kept under the pointer.
	if not _chip.visible or (_chip_index < 0 and _chip_pick.is_empty()):
		return
	var over: String = "%s|%d|%s" % [_chip_pick, _chip_index, str(_chip.size)]
	if over == _chip_over and _chip.position != Vector2.ZERO:
		return
	var mouth: Rect2 = _stage.pick_rect(_chip_pick) if not _chip_pick.is_empty() else _stage.mouth_rect(_chip_index)
	if mouth.size == Vector2.ZERO:
		return
	if _chip_pick == "altar:crystal":
		## The crystal's plate is about the whole circle: it hangs beside the circle, not over
		## a socket of it.
		for index in range(DeepAltar.SOCKETS):
			var socket: Rect2 = _stage.pick_rect("altar:%d" % index)
			if socket.size != Vector2.ZERO:
				mouth = mouth.merge(socket)
	_chip_over = over
	## Above what it is about if it fits there, else beside it, never over it: a tall chip (the
	## way on into the next mine) pushed down onto its own mouth would sit under the pointer.
	var low: Vector2 = Vector2(12.0, 150.0)
	var high: Vector2 = _crossroads.size - _chip.size - Vector2(12.0, 12.0)
	if DeepUi.phone:
		low = Vector2(DeepUi.safe_left + DeepUi.pt(6), DeepUi.pt(40))
		high = _crossroads.size - _chip.size - Vector2(DeepUi.safe_right + DeepUi.pt(6), (_run_dock.height() if _run_dock.visible else 0.0) + DeepUi.pt(6))
	var middle: float = mouth.get_center().y - _chip.size.y * 0.5
	var spots: Array = [Vector2(mouth.get_center().x - _chip.size.x * 0.5, mouth.position.y - _chip.size.y - 14.0),
		Vector2(mouth.end.x + 18.0, middle), Vector2(mouth.position.x - _chip.size.x - 18.0, middle)]
	## Nor over the room's own buttons under its name: the altar's crystal sits just below
	## "Walk on", and its plate, hung above it, covered the button.
	var buttons: Array = []
	var origin: Vector2 = (_chip.get_parent() as Control).global_position
	for child in _cross_hint.get_children() + _cross_wait.get_children() + _cross_ask.get_children():
		if child is Control and (child as Control).is_visible_in_tree() and (child as Control).size.x > 0.0:
			buttons.append(Rect2((child as Control).global_position - origin, (child as Control).size).grow(6.0))
	## Nor over the room's way out in its corner.
	if _way_out_key != null and is_instance_valid(_way_out_key) and _way_out_key.is_visible_in_tree():
		buttons.append(Rect2(_way_out_key.global_position - origin, _way_out_key.size).grow(6.0))
	var at: Vector2 = spots[0]
	var found: bool = false
	for pass_at in range(2):
		for spot in spots:
			var fitted := Vector2(clampf(spot.x, low.x, maxf(low.x, high.x)), clampf(spot.y, low.y, maxf(low.y, high.y)))
			var placed := Rect2(fitted, _chip.size)
			if placed.intersects(mouth.grow(6.0)) or (pass_at == 0 and buttons.any(func(r: Rect2) -> bool: return placed.intersects(r))):
				if pass_at == 1 and spot == spots[0]:
					at = fitted
				continue
			at = fitted
			found = true
			break
		if found:
			break
	_chip.position = at

# --- the party's choices, where they point ------------------------------------------------------
##
## In a party, what the others have chosen is shown where this player is looking: a tag over
## the cage for someone who wants to ride up, over a mouth for someone who wants to go down it,
## over the trading table for whoever sits at it. A split vote used to be a lift mark on a seat
## tab and then, at once, the end of the run. The tabs keep their marks as well.

static func names_of(names: Array) -> String:
	## "Mira", "Mira and Bo", "Mira, Bo and Cy".
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), str(names.back())]

func _landing_wish(unit: Dictionary) -> Array:
	## What a player's choice at a landing means here, as [glyph, words]: "ride up", or which
	## way down it is. [] for no choice yet.
	match str(unit.get("choice", "")):
		"lift":
			return ["lift", "ride up"]
		"descend":
			if DeepDescent.in_boss_hall(run):
				return ["descend", "push on"]
			var landing: Dictionary = run.get("landing", {})
			if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
				return ["crown", "fight the final boss" if DeepDescent.run_is_boss(run, int(run.get("depth", 0))) else "fight the Warden"]
			return ["descend", "go down"]
	return []

func _vote_targets() -> Array:
	## The tags to hang: [{target ("hall:<station>" or "mouth:N"), units, glyph, words, tone}],
	## one for each thing pointed at, naming everyone pointing at it. At the camp: who is
	## standing at which station, and who is done with one. At the crossroads: who wants the
	## cage and who wants which way down.
	if run.get("players", []).size() < 2 or _walking or not _hold.is_empty() or not _landing_view.is_empty() or _reading() or (_ask != null and _ask.is_open()):
		return []
	var phase: String = str(run.get("phase", ""))
	if not phase in ["landing", "tunnels"] or (phase == "landing" and DeepDescent.in_battle(run)):
		return []
	var offers: Array = _mouth_offers()
	var camp: bool = phase == "landing" and not DeepDescent.at_crossroads(run)
	## A ride up this player has still to answer is asked under the room's name, faces and all
	## (see `_party_asks`): the cage does not say it a second time.
	var asked_here: bool = _party_asks().any(func(ask: Dictionary) -> bool: return str(ask.kind) == "lift")
	var groups: Dictionary = {}
	var order: Array = []
	for other in run.get("players", []):
		var id: String = str(other.get("id", ""))
		if id == local_id or not bool(other.get("connected", true)) or bool(other.get("downed", false)):
			continue
		## Each mark: [target, glyph, words for one, words for several, tone], "%s" the names.
		var marks: Array = []
		var station: String = str(other.get("station", ""))
		if phase == "tunnels":
			for index in range(offers.size()):
				if str(offers[index].get("id", "")) == str(other.get("vote", "")):
					marks.append(["mouth:%d" % index, "check", "%s wants this way", "%s want this way", DeepUi.ACCENT])
		elif camp:
			var done: String = str(other.get("respite", ""))
			if not done.is_empty():
				marks.append(["hall:" + done, "check", STATION_DONE.get(done, "%s is done"), STATION_DONE.get(done, "%s are done"), DeepUi.GOOD])
			elif STATION_AT.has(station):
				marks.append(["hall:" + station, "hourglass", "%s is " + str(STATION_AT[station]), "%s are " + str(STATION_AT[station]), DeepUi.ACCENT])
		else:
			var wish: Array = _landing_wish(other)
			if str(other.get("choice", "")) == "lift":
				if not asked_here:
					marks.append(["hall:up", "lift", "%s wants to ride up", "%s want to ride up", DeepUi.ACCENT])
			elif not wish.is_empty():
				for index in range(offers.size()):
					if _went_by(other, offers[index], offers.size()):
						marks.append(["mouth:%d" % index, str(wish[0]), "%s wants to " + str(wish[1]), "%s want to " + str(wish[1]), DeepUi.ACCENT])
			elif station == "up":
				marks.append(["hall:up", "hourglass", "%s is " + str(STATION_AT.up), "%s are " + str(STATION_AT.up), DeepUi.ACCENT])
			elif station == "trade":
				## The booth is open at the crossroads too: whoever sits at it is shown there.
				marks.append(["hall:trade", "scales", "%s is " + str(STATION_AT.trade), "%s are " + str(STATION_AT.trade), DeepUi.ORE])
		for mark in marks:
			var key: String = "%s|%s" % [mark[0], mark[1]]
			if not groups.has(key):
				groups[key] = {"target": str(mark[0]), "units": [], "glyph": mark[1], "one": mark[2], "many": mark[3], "tone": mark[4]}
				order.append(key)
			groups[key].units.append(other)
	var out: Array = []
	for key in order:
		var group: Dictionary = groups[key]
		var names: Array = group.units.map(func(p: Dictionary) -> String: return str(p.get("name", "")))
		group.words = str(group.many if names.size() > 1 else group.one) % names_of(names)
		out.append(group)
	return out

## What a tag over a landing's station says of someone standing at it, and of someone done
## with it ("%s" is their names).
const STATION_AT: Dictionary = {"rest": "at the fire", "appraise": "at the bench", "wish": "at the well", "up": "looking at the lift", "trade": "at the booth"}
const STATION_DONE: Dictionary = {"rest": "%s rested", "appraise": "%s appraised a stone", "wish": "%s used the well"}

## How far under a floating name's middle a tag about the same thing starts: clear of its words.
const TAG_UNDER_NAME: float = 24.0

func _sync_vote_tags() -> void:
	## Built again only when what the tags say changes; placed over what they point at every
	## frame, since the camera breathes and walks.
	var groups: Array = _vote_targets()
	var key: String = ""
	for group in groups:
		key += "%s|%s|%s;" % [group.target, group.words, ",".join(group.units.map(func(p: Dictionary) -> String: return str(p.get("character", ""))))]
	if key != _vote_key:
		_vote_key = key
		DeepUi.clear(_vote_tags)
		for group in groups:
			var tag: Control = _vote_tag(group)
			_vote_tags.add_child(tag)
			if not _headless:
				DeepUi.pop_in(tag, 0.0, 0.85)
	if _stage == null or not _stage.has_room():
		return
	for tag in _vote_tags.get_children():
		var target: String = str(tag.get_meta("target", ""))
		var over: Rect2 = _stage.pick_rect(target) if target.begins_with("hall:") else _stage.mouth_rect(int(target.trim_prefix("mouth:")))
		var shown: bool = over.size != Vector2.ZERO and over.get_center().x > 0.0 and over.get_center().x < _vote_tags.size.x
		(tag as Control).visible = shown
		if not shown:
			continue
		var need: Vector2 = (tag as Control).get_combined_minimum_size()
		## Over a mouth the tag sits on its plaque, above the arch. Over the cage and the booth
		## it hangs just under their floating name, its point at the thing.
		var at := Vector2(over.get_center().x - need.x * 0.5, over.position.y - need.y - 2.0)
		var hall: Node3D = _stage.hall() if target.begins_with("hall:") else null
		var spot: Node3D = hall.call("name_spot", target.trim_prefix("hall:")) if hall != null and hall.has_method("name_spot") else null
		if spot != null:
			at.y = _stage.to_screen(spot.global_position).y + TAG_UNDER_NAME
		at.x = clampf(at.x, 8.0, maxf(8.0, _vote_tags.size.x - need.x - 8.0))
		at.y = clampf(at.y, 120.0, maxf(120.0, _vote_tags.size.y - need.y - 8.0))
		(tag as Control).size = need
		(tag as Control).position = at.round()

func _vote_tag(group: Dictionary) -> Control:
	## A capsule of faces and a few words, with a point under it at what they chose.
	var tone: Color = group.tone
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("target", str(group.target))
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", DeepUi.capsule(tag, Color(0.055, 0.05, 0.04, 0.96), tone, 2, 8, 4))
	holder.add_child(tag)
	var row := DeepUi.hbox(tag, 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for unit in group.units:
		var face := Roster.Portrait.new(str(unit.get("character", "")), Vector2(26, 26), false, false, false, DeepStone.birthstone_for(unit))
		face.ring = _seat_color(str(unit.get("id", "")))
		face.mood = Roster.resting_mood(unit)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(face)
	var words := DeepUi.label(row, str(group.words), 15, tone.lightened(0.3))
	words.add_theme_font_override("font", DeepUi.bold_font())
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.icon(row, str(group.glyph), 17, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var point := TagPoint.new(tone)
	point.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(point)
	return holder

class Shimmer extends Control:
	## A glint that sweeps across a Smith's Voucher's better work every few seconds, so the
	## card reads as special without a word. Drawn added to what is under it, and kept inside
	## its card.
	const EVERY: float = 2.8
	const SWEEP: float = 0.75
	var tone: Color
	var _clock: float = 0.0
	func _init(color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		set_process(DisplayServer.get_name() != "headless")
	func _process(delta: float) -> void:
		_clock = fmod(_clock + delta, EVERY)
		queue_redraw()
	func _draw() -> void:
		var t: float = _clock / SWEEP
		if t > 1.0 or size.x <= 0.0:
			return
		var lean: float = size.y * 0.45
		var x: float = lerpf(-lean - 40.0, size.x + 40.0, t)
		var band: float = 34.0
		draw_colored_polygon(PackedVector2Array([Vector2(x + lean, 0), Vector2(x + lean + band, 0), Vector2(x + band, size.y), Vector2(x, size.y)]),
			Color(tone, 0.16 * sin(t * PI)))

## How far in from a plate's outer left edge the pill on its border starts: past the corner's cut.
const PLATE_LABEL_IN: float = 16.0
## The Bag of Dice's extra air between the bag's tiles and your dice's plate, over the column's
## own spacing either side of it (round 10): room for the pill on the plate's border.
const BAG_PLATE_GAP: float = 8.0

class SparkleSweep extends Control:
	## The light that turns a bench's plain work to its better work: a bright band sweeping the
	## row of cards left to right, strewn with glints. Halfway (`TURN`) the cards under it change.
	const LIFE: float = 0.9
	const TURN: float = 0.42
	var tone: Color
	var age: float = 0.0
	var stars: Array = []
	func _init(color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 30
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for _i in range(44):
			stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(5.0, 14.0)))
	func _process(delta: float) -> void:
		## At most a frame's step at a time, so a hitch cannot skip the sweep.
		age += minf(delta, 1.0 / 30.0)
		if age > LIFE:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k: float = age / LIFE
		var lean: float = size.y * 0.35
		var x: float = lerpf(-lean - 160.0, size.x + 160.0, k)
		var band: float = 170.0
		var fade: float = sin(k * PI)
		## A wide gold band, a brighter core, and a thin white edge at its heart.
		draw_colored_polygon(PackedVector2Array([Vector2(x + lean, 0), Vector2(x + lean + band, 0), Vector2(x + band, size.y), Vector2(x, size.y)]), Color(tone, 0.34 * fade))
		draw_colored_polygon(PackedVector2Array([Vector2(x + lean + band * 0.3, 0), Vector2(x + lean + band * 0.7, 0), Vector2(x + band * 0.7, size.y), Vector2(x + band * 0.3, size.y)]), Color(tone.lightened(0.35), 0.3 * fade))
		draw_colored_polygon(PackedVector2Array([Vector2(x + lean + band * 0.47, 0), Vector2(x + lean + band * 0.53, 0), Vector2(x + band * 0.53, size.y), Vector2(x + band * 0.47, size.y)]), Color(Color.WHITE, 0.35 * fade))
		for star in stars:
			var at := Vector2(star.x * size.x, star.y * size.y)
			var lead: float = (at.x - x - lean * (1.0 - star.y)) / band
			if lead < -0.3 or lead > 1.3:
				continue
			var glow: float = (1.0 - absf(lead - 0.5) * 1.4) * fade
			if glow <= 0.0:
				continue
			var r: float = star.z * glow
			var shine: Color = Color(tone.lightened(0.55), glow)
			draw_line(at - Vector2(r, 0), at + Vector2(r, 0), shine, 2.0, true)
			draw_line(at - Vector2(0, r), at + Vector2(0, r), shine, 2.0, true)
			draw_circle(at, r * 0.18, Color(Color.WHITE, glow))

class TagPoint extends Control:
	## The small point under a tag, at what it is about.
	var tone: Color
	func _init(color: Color) -> void:
		tone = color
		custom_minimum_size = Vector2(16, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w: float = size.x
		draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(w, -2), Vector2(w * 0.5, size.y)]), Color(0.055, 0.05, 0.04, 0.96))
		draw_polyline(PackedVector2Array([Vector2(0, -1), Vector2(w * 0.5, size.y), Vector2(w, -1)]), tone, 2.0, true)

func _vote_lines(box: VBoxContainer) -> void:
	## On the cage's plate and on a way down's, at a landing: what the rest of the party has
	## chosen, and how a split is settled.
	var others: Array = DeepDescent.living(run).filter(func(p: Dictionary) -> bool: return str(p.get("id", "")) != local_id)
	if others.is_empty():
		return
	for other in others:
		var wish: Array = _landing_wish(other)
		if not wish.is_empty():
			DeepUi.stat(box, str(wish[0]), "%s wants to %s" % [str(other.get("name", "")), str(wish[1])], DeepUi.ACCENT, 12)
	DeepUi.stat(box, "coin", "A split vote is a coin toss." if others.size() == 1 else "A tied vote is a coin toss.", DeepUi.MUTED, 12)

# --- waiting on the party ------------------------------------------------------------------------

func _sync_waiting() -> void:
	## Done here before the rest of the party: who this player waits on, said under the room's
	## name. The tabs carry everyone's mark, but a room that looks the same before and after a
	## choice read as if the choice had not been taken.
	var words: String = _waiting_words()
	_cross_wait.visible = not words.is_empty()
	if words == _wait_key:
		return
	_wait_key = words
	DeepUi.clear(_cross_wait)
	if not words.is_empty():
		DeepUi.pill(_cross_wait, "hourglass", words, DeepUi.PAPER.darkened(0.12), 13)

func _waiting_words() -> String:
	if run.get("players", []).size() < 2 or DeepDescent.in_battle(run) or not _hold.is_empty():
		return ""
	var unit: Dictionary = me()
	if str(run.get("phase", "")) == "landing" and not unit.is_empty() and not bool(unit.get("downed", false)):
		return _landing_waiting(unit)
	if unit.is_empty() or bool(unit.get("downed", false)) or not str(_run_dock.seat_status(unit)[0]) in ["check", "lift", "descend"]:
		return ""
	var waiting: Array = []
	for other in DeepDescent.living(run):
		if str(other.get("id", "")) != local_id and str(_run_dock.seat_status(other)[0]) in ["hourglass", "pick"]:
			waiting.append(str(other.get("name", "")))
	if waiting.is_empty():
		return ""
	var who: String = names_of(waiting)
	match str(run.get("phase", "")):
		"tunnels":
			return "Waiting for %s to choose a way." % who
		"landing":
			var wish: Array = _landing_wish(unit)
			return ("You want to %s. Waiting for %s." % [str(wish[1]), who]) if not wish.is_empty() else "Waiting for %s." % who
		"chamber":
			var kind: String = str(run.get("chamber", {}).get("kind", ""))
			if kind in DeepDescent.ROCK_ROOMS:
				return "Waiting for %s to put the pick down." % who
			if kind == "merchant":
				return "Waiting for %s to finish at the stall." % who
			if kind == "altar":
				return "Waiting for %s at the altar." % who
			return "Waiting for %s to choose." % who
		"hoard":
			return "Waiting for %s to take a stone." % who
	return "Waiting for %s." % who

func _landing_waiting(unit: Dictionary) -> String:
	## At the camp: done with the respite, who the crossroads waits on and where they stand. At
	## the crossroads: who has still to answer up or down.
	if not DeepDescent.at_crossroads(run):
		if not DeepDescent.camp_done(run, unit):
			return ""
		var names: Array = []
		for other in DeepDescent.camp_waiting(run):
			var at: String = str(STATION_AT.get(str(other.get("station", "")), ""))
			names.append(str(other.get("name", "")) + (" (%s)" % at if not at.is_empty() else ""))
		return ("You're done here. Waiting for %s before the way on opens." % names_of(names)) if not names.is_empty() else ""
	var wish: Array = _landing_wish(unit)
	if wish.is_empty():
		return ""
	var waiting: Array = []
	for other in DeepDescent.living(run):
		if str(other.get("id", "")) != local_id and str(other.get("choice", "")).is_empty():
			waiting.append(str(other.get("name", "")))
	return ("You want to %s. Waiting for %s." % [str(wish[1]), names_of(waiting)]) if not waiting.is_empty() else ""

func _sync_party_asks() -> void:
	## Under the room's name at a landing, what the party is asking of this player: a ride up
	## someone has asked for (answered right here), a stone someone has offered (answered on
	## the trade page), and, at the camp, what the cage will cost once the party gets to it.
	if _cross_ask == null:
		return
	var asks: Array = _party_asks()
	_cross_ask.visible = not asks.is_empty()
	var key: String = JSON.stringify(asks)
	if key == _cross_ask_key:
		return
	_cross_ask_key = key
	DeepUi.clear(_cross_ask)
	for ask in asks:
		match str(ask.kind):
			"fare":
				DeepUi.pill(_cross_ask, "lift", str(ask.words), DeepUi.ORE if bool(ask.afford) else DeepUi.BAD, 12)
			"lift":
				var card := PanelContainer.new()
				card.add_theme_stylebox_override("panel", DeepUi.capsule(card, Color(0.055, 0.05, 0.04, 0.96), DeepUi.GOOD, 2, 12, 6))
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_cross_ask.add_child(card)
				var line := DeepUi.hbox(card, 8)
				line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				for id in ask.riders:
					var rider: Dictionary = DeepDescent.player(run, str(id))
					var face := Roster.Portrait.new(str(rider.get("character", "")), Vector2(26, 26), false, false, false, DeepStone.birthstone_for(rider))
					face.ring = _seat_color(str(id))
					face.mouse_filter = Control.MOUSE_FILTER_IGNORE
					face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					line.add_child(face)
				var names: Array = ask.riders.map(func(id: Variant) -> String: return str(DeepDescent.player(run, str(id)).get("name", "")))
				var said := DeepUi.label(line, "%s %s to ride up · fare %d, the party has %d" % [names_of(names), "want" if names.size() > 1 else "wants", int(ask.fare), int(ask.pooled)], 14, DeepUi.PAPER)
				said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var ride := DeepUi.primary(line, "lift", "Ride up", func() -> void:
					DeepAudio.play("lift")
					command.emit({"kind": "choose", "choice": "lift"}), 13, DeepUi.GOOD)
				ride.disabled = not bool(ask.afford)
				ride.mouse_filter = Control.MOUSE_FILTER_STOP
				var stay := DeepUi.icon_button(line, "descend", "Keep going", _keep_going, 13, DeepUi.ACCENT)
				stay.tooltip_text = "Answer no: go down. Click a tunnel mouth instead to say which way."
				stay.mouse_filter = Control.MOUSE_FILTER_STOP
			"conquest":
				var again := DeepUi.icon_button(_cross_ask, "crown", "%s conquered · home or deeper" % DeepContent.mine_name(str(ask.mine)), _reopen_conquest, 13, DeepUi.ACCENT_HI)
				again.name = "ConquestAgain"
				again.tooltip_text = "Open the beaten mine's sheet again: ride the lift home, or dig on into the mine below."
				again.mouse_filter = Control.MOUSE_FILTER_STOP
				if DeepUi.phone:
					again.custom_minimum_size.y = maxf(again.custom_minimum_size.y, DeepUi.pt(34))
			"trade":
				var asker: Dictionary = DeepDescent.player(run, str(ask.id))
				var words: String = ("Your trade with %s is ready to accept" if bool(ask.paired) else "%s offers you a stone") % str(asker.get("name", "Someone"))
				var answer := DeepUi.icon_button(_cross_ask, "scales", words, _open_trade.bind(str(ask.id)), 13, DeepUi.ORE)
				answer.tooltip_text = "Open the trade with them."
				answer.mouse_filter = Control.MOUSE_FILTER_STOP

func _party_asks() -> Array:
	## Nothing while a card is pinned in the room: the card is about the same things.
	if str(run.get("phase", "")) != "landing" or not _landing_view.is_empty() or not _pinned.is_empty() or not _hold.is_empty() or _walking or DeepDescent.in_battle(run):
		return []
	var unit: Dictionary = me()
	var landing: Dictionary = run.get("landing", {})
	var boss_hall: bool = DeepDescent.in_boss_hall(run)
	var out: Array = []
	## The beaten mine's sheet stays up until a way out is chosen (Inspector `_holds_choice`),
	## but its buttons put it away before the rules answer, and the rules can say no (a respite
	## still owed, the party still at the camp). Gone with no choice standing, a key brings it
	## back; with a choice standing there is nothing to ask again.
	if boss_hall and not _conquest_up() and not _conquest_item.is_empty() and str(_conquest_item.get("run_id", "")) == str(run.get("run_id", "")) 			and str(unit.get("choice", "")).is_empty():
		out.append({"kind": "conquest", "mine": str(_conquest_item.get("mine", ""))})
	if unit.is_empty() or bool(unit.get("downed", false)):
		return out
	var party: bool = run.get("players", []).size() > 1
	var cage: bool = (not bool(landing.get("cleared", false)) or boss_hall) and _stage.hall() != null \
		and not (DeepDescent.has_mod(run, "LAST_LIFT") and not boss_hall and not bool(landing.get("warden_next", false)))
	var fare: int = DeepDescent.lift_cost(run)
	var pooled: int = 0
	for other in DeepDescent.living(run):
		pooled += int(other.get("ore", 0))
	var crossroads: bool = DeepDescent.at_crossroads(run)
	if cage and not crossroads:
		## The fare, in sight before anyone gets to the cage.
		out.append({"kind": "fare", "afford": pooled >= fare, "words": "The lift from here: %d pyrite · %s %d" % [fare, "the party has" if party else "you have", pooled]})
	if cage and crossroads and party and str(unit.get("choice", "")) != "lift" and not DeepDescent.lift_asked_by(run).is_empty():
		var riders: Array = DeepDescent.living(run).filter(func(p: Dictionary) -> bool: return str(p.get("choice", "")) == "lift").map(func(p: Dictionary) -> String: return str(p.id))
		out.append({"kind": "lift", "riders": riders, "fare": fare, "pooled": pooled, "afford": pooled >= fare})
	if party:
		var paired: String = DeepDescent.trade_partner(run, local_id)
		for asker in DeepDescent.offers_to(run, local_id).slice(0, 2):
			if DeepDescent.can_trade_with(run, local_id, str(asker)):
				out.append({"kind": "trade", "id": str(asker), "paired": paired == str(asker)})
	return out

func _conquest_up() -> bool:
	return _conquest_sheet != null and is_instance_valid(_conquest_sheet) and not _conquest_sheet.is_queued_for_deletion()

func _reopen_conquest() -> void:
	## The beaten mine's sheet again, as it was first shown.
	if _conquest_item.is_empty() or _conquest_up():
		return
	if not (str(run.get("phase", "")) == "landing" and DeepDescent.in_boss_hall(run)):
		return
	_conquest_sheet = _show_conquest(_conquest_item)
	_conquest_shown = true
	_sync_party_asks()

func _keep_going() -> void:
	## No to the cage: down, by the only mouth if there is one; a mouth clicked later says which.
	var offers: Array = _mouth_offers()
	if offers.size() == 1:
		_choose_mouth(0)
		return
	DeepAudio.play("tunnel", {"volume": 0.6})
	command.emit({"kind": "choose", "choice": "descend", "via": ""})

# --- coming back, and a split vote settled -------------------------------------------------------

func _tell_back() -> void:
	## Back in the party after dropping out: one line on what went on meanwhile, once.
	var back: Dictionary = me().get("back", {})
	if back.is_empty() or not bool(me().get("connected", true)):
		return
	var key: String = "%s|%d|%d" % [str(run.get("run_id", "")), int(back.get("seq", 0)), int(back.get("taken", 0))]
	if key == _back_told:
		return
	_back_told = key
	var words: String = back_words(back)
	if not words.is_empty():
		toast(words, DeepUi.INFO, "wifi", 6.5)

static func back_words(back: Dictionary) -> String:
	## "You were away 1 turn. Your seat played itself and took 22.", or "" when nothing happened.
	var turns: int = int(back.get("turns", 0))
	var floors: int = int(back.get("floors", 0))
	var fought: bool = turns > 0 or int(back.get("fights", 0)) > 0 or bool(back.get("in_fight", false))
	var taken: int = int(back.get("taken", 0))
	var downed: bool = bool(back.get("downed", false))
	if turns <= 0 and floors <= 0 and not fought and taken <= 0 and not downed:
		return ""
	var lead: String = "You were away for a moment."
	if turns > 0:
		lead = "You were away %s." % DeepUi.plural(turns, "turn")
	elif floors > 0:
		lead = "You were away for %s." % DeepUi.plural(floors, "floor")
	elif fought:
		lead = "You were away for a fight."
	if downed:
		return lead + (" Your seat played itself and went down." if fought else " You went down.")
	if taken > 0:
		return lead + ((" Your seat played itself and took %d." % taken) if fought else (" You lost %d health." % taken))
	return lead + (" Your seat played itself and took nothing." if fought else "")

const TOSS_HOLD: float = 3.4
const TOSS_TOP: float = 240.0

func _toss_way(toss: Dictionary, way: String) -> Array:
	## A way voted for, as [glyph, words on a card, words in "... wins"]: "Ride up" and "the
	## lift", "The Warden's hall", "A vein" and "a vein".
	if toss.has("below"):
		if way == "lift":
			return ["lift", "Ride up", "the lift"]
		match str(toss.get("below", "")):
			"warden": return ["crown", "The Warden's hall", "the Warden's hall"]
			"boss": return ["crown", "The final boss's hall", "the final boss's hall"]
			"next_mine": return ["descend", "Push on", "pushing on"]
		return ["descend", "Go on down", "going down"]
	var kind: String = str(toss.get("kinds", {}).get(way, "hidden"))
	var glyph: String = "question" if kind == "hidden" else str(DeepUi.CHAMBER_GLYPHS.get(kind, "arch"))
	var words: String = str(KIND_WORDS.get(kind, kind.capitalize()))
	return [glyph, words, words.left(1).to_lower() + words.substr(1)]

func _toss_beat(toss: Dictionary) -> void:
	## A split vote, settled: who wanted what and which way the coin (or the draw) sent the
	## party, held over the room for a moment while it moves. A split used to walk off, or end
	## the run, without a word on either.
	var votes: Dictionary = toss.get("votes", {})
	if votes.size() < 2:
		return
	if _toss_panel != null and is_instance_valid(_toss_panel):
		_toss_panel.queue_free()
	var won: String = str(toss.get("won", ""))
	var tone: Color = DeepUi.ACCENT
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, 18, 3, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 19
	add_child(panel)
	_toss_panel = panel
	var box := DeepUi.vbox(panel, 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := Medallion.new("coin", tone, 58)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(coin)
	var kicker := DeepUi.label(box, "SPLIT VOTE", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	kicker.add_theme_font_override("font", DeepUi.caps_font())
	var called: String = str(_toss_way(toss, won)[2])
	var headline := DeepUi.title(box, "%s: %s wins" % ["Coin toss" if str(toss.get("how", "toss")) == "toss" else "The draw", called], 30, tone, HORIZONTAL_ALIGNMENT_CENTER)
	var row := DeepUi.hbox(box, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var winners: Array = []
	for id in votes:
		var unit: Dictionary = DeepDescent.player(run, str(id))
		var way: String = str(votes[id])
		var took: bool = way == won
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", DeepUi.ledger(Color(0.075, 0.08, 0.11), tone if took else DeepUi.LINE, 10, 10, 2, 0))
		card.custom_minimum_size.x = 210
		row.add_child(card)
		var line := DeepUi.hbox(card, 10)
		var face := Roster.Portrait.new(str(unit.get("character", "")), Vector2(40, 40), false, false, false, DeepStone.birthstone_for(unit))
		face.ring = _seat_color(str(id))
		face.mood = Roster.resting_mood(unit)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(face)
		var words := DeepUi.vbox(line, 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		var named := DeepUi.hbox(words, 6)
		if str(id) == local_id:
			DeepUi.you_badge(named)
		var who := DeepUi.label(named, str(unit.get("name", "")), 15, DeepUi.PAPER if took else DeepUi.MUTED)
		who.add_theme_font_override("font", DeepUi.bold_font())
		var way_words: Array = _toss_way(toss, way)
		DeepUi.stat(words, str(way_words[0]), str(way_words[1]), tone if took else DeepUi.DIM, 13)
		if took:
			DeepUi.icon(line, "check", 20, DeepUi.GOOD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			winners.append(card)
	if str(toss.get("how", "toss")) != "toss":
		DeepUi.label(box, "Each vote is one chance in the draw.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	## Over the middle of the room, under its name and above the dock.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = TOSS_TOP
	panel.offset_bottom = TOSS_TOP + panel.get_combined_minimum_size().y
	_toss_until = Time.get_ticks_msec() + int(TOSS_HOLD * 1000.0)
	if _headless:
		return
	## The coin turns over a few times, lands, and the way it fell lights up.
	DeepAudio.play("dice_reroll", {"volume": 0.7})
	DeepUi.pop_in(panel, 0.0, 0.9)
	coin.pivot_offset = coin.custom_minimum_size * 0.5
	headline.modulate.a = 0.0
	var flip := coin.create_tween()
	flip.tween_method(func(t: float) -> void: coin.scale.x = maxf(0.08, absf(cos(t * PI * 5.0))), 0.0, 1.0, 0.7)
	flip.tween_callback(func() -> void:
		DeepAudio.play("reel_stop", {"volume": 0.8})
		headline.modulate.a = 1.0
		DeepUi.pulse(headline, 1.12, 0.3)
		for card in winners:
			DeepUi.pulse(card, 1.06, 0.3))
	var fade := panel.create_tween()
	fade.tween_property(panel, "modulate:a", 0.0, 0.5).set_delay(TOSS_HOLD)
	fade.tween_callback(panel.queue_free)

func _process(delta: float) -> void:
	## The room's line, in the phone's words (a tap for a click): it is set in many places.
	if DeepUi.phone and _cross_sub != null and _cross_sub.text != _cross_said:
		_cross_sub.text = DeepUi.phone_words(_cross_sub.text)
		_cross_said = _cross_sub.text
	## A twin plate held back under an appraisal or a close look comes up the frame it goes.
	var reading: bool = _reading()
	if _was_reading and not reading and not run.is_empty() and is_visible_in_tree():
		_sync_twin()
	_was_reading = reading
	## A landing held still for a sheet walks on the moment it is put away.
	if str(run.get("phase", "")) == "landing" and _hold.is_empty() and not _walking and _area.visible and not reading:
		if _stage.has_room() and not _stage.at_crossroads() and not _stage.strolling() and _landing_view.is_empty() and DeepDescent.at_crossroads(run) and not _stage.ways_live():
			_show_landing()
	if not _news.is_empty():
		_tell_news()
	## A way out laid while the party walked in is laid again once it stands still: what it
	## would cover in the room (`_covers_pick`) is only where it stays then.
	var walking_now: bool = _stage != null and _stage.walking()
	if _way_walked and not walking_now and _way_out_key != null and is_instance_valid(_way_out_key):
		_later(0.5, _place_way_out)
	_way_walked = walking_now
	## The beaten mine's choice only stands while the party is still in the boss's hall.
	## (A freed sheet no longer compares equal to anything, null included: ask is_instance_valid.)
	if not _conquest_up():
		if _conquest_sheet != null or _conquest_shown:
			_conquest_sheet = null
			_conquest_shown = false
			_sync_party_asks()
	elif _conquest_sheet != null and not (str(run.get("phase", "")) == "landing" and DeepDescent.in_boss_hall(run)):
		_conquest_sheet.call("_dismiss")
		_conquest_sheet = null
	## The chip rides above its mouth while the camera breathes and leans.
	if _crossroads != null and _crossroads.visible:
		_place_chip()
		_sync_vote_tags()
		## "Down to depth N · Choose a way" waits until the party has walked up to the mouths
		## (the rockfall and the stroll come first), and the room's title steps back while the
		## beaten mine's sheet stands over it. Gated on moving, not on being there, so it can
		## never stay hidden; with no room (headless) it simply shows.
		var away: bool = str(run.get("phase", "")) == "tunnels" and _stage != null and _stage.has_room() and (_stage.strolling() or _stage.walking())
		var goal: float = 0.0 if away or _conquest_up() else 1.0
		_crossroads.modulate.a = move_toward(_crossroads.modulate.a, goal, delta * 4.0)
	elif _crossroads != null:
		## Hidden, it waits clear, so its next showing fades in rather than flashing up mid-walk.
		_crossroads.modulate.a = 1.0 if _headless else 0.0
	## Keep the note of where the ore and bag pills stand fresh, for the frame a spoil is
	## thrown at one of them and the strip has only just been rebuilt.
	if _stage != null and is_instance_valid(_stage):
		_pill_centre("ore")
		_pill_centre("bag")

# --- strip -----------------------------------------------------------------------------------

func _reading() -> bool:
	## A close look or an appraisal is open over the room.
	return Inspector.is_open() or Appraisal.is_open()

func _last_landing_before(depth: int) -> int:
	## The lift the party came down from, or the shaft head.
	var best: int = 0
	for at in run.get("schedule", {}).get("landings", []):
		if int(at) <= depth:
			best = maxi(best, int(at))
	return best

func _sync_strip() -> void:
	var unit: Dictionary = me()
	var mine: Dictionary = DeepContent.mine(str(run.get("mine", "")))
	var depth: int = int(run.get("depth", 0))
	## How far the next lift is, this run: nobody is told until the chart reaches it.
	var next_landing: int = DeepDescent.next_landing(run, depth)
	var charted: bool = int(run.get("map", {}).get("to", 0)) >= next_landing
	var here: bool = DeepDescent.run_is_landing(run, depth)
	var note: String = "On a landing" if here else ("Landing in %d" % (next_landing - depth) if charted else "A landing somewhere below")
	if charted and not here and DeepDescent.run_is_warden(run, next_landing):
		note = "Landing in %d, then %s" % [next_landing - depth, "the boss" if DeepDescent.run_is_boss(run, next_landing) else "a Warden"]
	## A Warden is fought at its landing's own depth, and the run's end keeps the depth it ended
	## on: neither is "On a landing" to the player.
	var phase: String = str(run.get("phase", ""))
	## An abandoned dig also ends as a fall to the sim: its own flag tells the two apart.
	var abandoned: bool = bool(run.get("abandoned", false))
	if phase == "over":
		var outcome_key: String = "abandoned" if abandoned else str(run.get("outcome", ""))
		note = {"extracted": "Extracted", "conquered": "The mine is yours", "fallen": "Fallen", "abandoned": "Abandoned"}.get(outcome_key, "The run is over")
	elif phase == "salvage":
		## The salvage dice are thrown: the way ahead is gone.
		note = "Abandoned" if abandoned else "Fallen"
	elif here and phase == "chamber" and str(run.get("chamber", {}).get("kind", "")) == "warden":
		note = "The boss's hall" if DeepDescent.run_is_boss(run, depth) else "Warden's hall"
	elif here and bool(run.get("landing", {}).get("cleared", false)) and int(run.get("landing", {}).get("depth", -1)) == depth:
		## Back in the hall the Warden held, after its hoard: no lift waits here.
		note = "The boss's hall" if DeepDescent.in_boss_hall(run) else "Warden's hall · no lift"
	var every: int = maxi(1, next_landing - _last_landing_before(depth))
	var into: int = depth - _last_landing_before(depth)
	var guarded: bool = charted and DeepDescent.run_is_warden(run, next_landing)
	## In a fight the health that moves is the fight's own; the run's is only written back
	## when it ends, and allies' bars here would sit still through every blow until then.
	var fighting: Dictionary = {}
	if DeepDescent.in_battle(run):
		for fighter in DeepDescent.battle(run).get("players", []):
			fighting[str(fighter.get("id", ""))] = fighter
	var health := func(p: Dictionary) -> Vector2i:
		var live: Dictionary = fighting.get(str(p.get("id", "")), p)
		return Vector2i(int(live.get("hp", p.get("hp", 0))), int(live.get("max_hp", p.get("max_hp", 0))))
	## Built again only when something on it has changed. A fight sends a fresh state with
	## every step it plays, and the strip used to be torn down and put back for each one.
	var party: Array = run.get("players", []).map(func(p: Dictionary) -> String:
		var hp: Vector2i = health.call(p)
		return "%s|%s|%s|%d|%d|%s|%s|%d" % [str(p.get("id", "")), str(p.get("name", "")), str(p.get("character", "")), hp.x, hp.y,
			str(bool(p.get("downed", false))), str(bool(p.get("connected", true))), int(fighting.get(str(p.get("id", "")), {}).get("streak", 0))])
	var key: String = "%s#%d#%s#%d#%d#%s#%s#%s#%s#%d#%d#%s#%s#%s#%s" % [str(mine.get("name", "")), depth, note, every, into, str(guarded), local_id,
		",".join(party), str(unit.is_empty()), _purse(unit), unit.get("haul", []).size(), str(_strip_hold), str(_chart_open), JSON.stringify(daily_best), str(not fighting.is_empty())]
	if not unit.is_empty():
		key += str(EffectChips.for_run(unit))
	## The run's end takes the Chart away: an abandoned dig says "Abandoned" from its salvage
	## on, so the words alone left the Chart up on the over page.
	key += "#over" if phase == "over" else ""
	if key == _strip_key and _strip.get_child_count() > 0:
		return
	_strip_key = key
	DeepUi.clear(_strip)
	## A party of three or four shares the strip: names are cut short past a few letters (each
	## says itself in full on hover) and the bars and the gaps between things narrow.
	var crowd: bool = run.get("players", []).size() >= 3
	_strip.add_theme_constant_override("separation", 12 if crowd else 18)
	var place := DeepUi.hbox(_strip, 10)
	DeepUi.icon(place, "pick", DeepUi.pt(16) if DeepUi.phone else 22.0, DeepUi.ACCENT)
	var names := DeepUi.vbox(place, 0)
	names.add_theme_constant_override("separation", -4 if DeepUi.phone else 0)
	DeepUi.title(names, str(mine.get("name", "The mine")), 13 if DeepUi.phone else 17, DeepUi.PAPER)
	DeepUi.label(names, ("Depth %d · %s" if DeepUi.phone else "Depth %d  ·  %s") % [depth, note], 11 if DeepUi.phone else 12, DeepUi.MUTED)
	if not run.get("daily", {}).is_empty():
		_daily_marks(place)
	if DeepDescent.hazard_tier(run) > 0:
		DeepUi.stat(place, "skull", "Hazard %d" % DeepDescent.hazard_tier(run), DeepUi.BAD, 12, _hazard_words(DeepDescent.hazard_tier(run))).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Progress to the next landing as a row of little steps.
	var steps := DeepUi.hbox(_strip, 3)
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(every):
		var lit: bool = i < into
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(DeepUi.pt(8), DeepUi.pt(8)) if DeepUi.phone else Vector2(14, 6)
		pip.color = DeepUi.ACCENT if lit else Color(DeepUi.LINE_HI, 0.8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steps.add_child(pip)
	DeepUi.icon(steps, "lift", DeepUi.pt(11) if DeepUi.phone else 16.0, DeepUi.GOOD)
	if guarded:
		DeepUi.icon(steps, "crown", DeepUi.pt(11) if DeepUi.phone else 16.0, DeepUi.BAD)
	DeepUi.spacer(_strip)
	## In a fight each player's health is on their tab and on the dock: the strip leaves it out.
	var alone_on_phone: bool = DeepUi.phone and run.get("players", []).size() <= 1
	for other in ([] if not fighting.is_empty() or alone_on_phone else run.get("players", [])):
		var mine_too: bool = str(other.id) == local_id
		var box := DeepUi.hbox(_strip, 6)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var hp: Vector2i = health.call(other)
		box.tooltip_text = "%s: %d of %d\nClick to see their rail, their bag and their dice." % [str(other.name), hp.x, hp.y]
		var member_id: String = str(other.id)
		box.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_look_at_member(member_id))
		## Their face, in the mood their health puts them in; ringed in their seat's color in a party.
		var face := Roster.Portrait.new(str(other.get("character", "")), Vector2(26, 26), false, false, false, DeepStone.birthstone_for(other))
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.mood = Roster.resting_mood({"hp": hp.x, "max_hp": hp.y, "downed": bool(other.get("downed", false))})
		if run.get("players", []).size() > 1:
			face.ring = Color(_seat_color(member_id), 0.9)
		box.add_child(face)
		var named := DeepUi.label(box, str(other.name), 14, DeepUi.PAPER if mine_too else DeepUi.MUTED)
		var said: float = named.get_theme_font("font").get_string_size(named.text, HORIZONTAL_ALIGNMENT_LEFT, -1, named.get_theme_font_size("font_size")).x
		named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		named.custom_minimum_size.x = minf(52.0 if crowd else 150.0, ceilf(said) + 1.0)
		## Tall enough for its number to be read, which is how allies' health is followed.
		var bar := DeepUi.bar(box, 16.0)
		bar.custom_minimum_size = Vector2(80 if crowd else 110, 16)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.warn = true
		bar.set_values(float(hp.x) / float(maxi(1, hp.y)), "%d" % hp.x)
		## A hot streak, a Hot Streak's die or better, is seen by the whole table.
		var streak: int = int(fighting.get(member_id, {}).get("streak", 0))
		if streak >= 2:
			DeepUi.icon(box, "flame", 16, Color("ff7a2f"), "On Fire" if streak >= 3 else "Hot Streak").size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if bool(other.get("downed", false)):
			DeepUi.icon(box, "skull", 16, DeepUi.BAD, "Down")
		if not bool(other.get("connected", true)):
			DeepUi.label(box, "away", 11, DeepUi.DIM)
	DeepUi.spacer(_strip)
	if not unit.is_empty():
		## Run-long blessings (Sparkle, a Shrine) sit beside what the player carries.
		var blessings := EffectChips.Row.new(15)
		_strip.add_child(blessings)
		if DeepUi.phone:
			## The phone's strip has one line: the blessings keep to it, and in a fight the
			## chips over the dock show them already.
			blessings.custom_minimum_size.x = DeepUi.pt(150)
			blessings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			blessings.visible = fighting.is_empty()
		blessings.show_effects(EffectChips.for_run(unit))
		var counts: Dictionary = {"ore": _purse(unit), "haul": unit.get("haul", []).size()}
		## What was just won is counted when it lands here, not when the fight ends.
		for held in _strip_hold:
			counts[held] = _strip_hold[held]
		## Once the run is over there is no trail ahead to chart.
		if phase != "over":
			var chart := DeepUi.icon_button(_strip, "map", "" if DeepUi.phone else "Chart", toggle_chart, 13, DeepUi.ACCENT if _chart_open else DeepUi.MUTED)
			if DeepUi.phone:
				chart.custom_minimum_size = Vector2(DeepUi.pt(36), DeepUi.pt(28))
			chart.tooltip_text = "The chart of the trail behind and two floors ahead; light dark mouths on the next floor for pyrite (M)"
			chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			## M opens it, and Esc the menu: neither takes the keyboard's focus, so Tab and Enter
			## never open them in place of the page's own way on.
			chart.focus_mode = Control.FOCUS_NONE
		var ore := DeepUi.pill(_strip, "ore", str(counts.ore), DeepUi.ORE, 12 if DeepUi.phone else 14, "Pyrite: spent at merchants and on the lantern")
		var bag := DeepUi.pill(_strip, "bag", str(counts.haul), DeepUi.PAPER, 12 if DeepUi.phone else 14, "Loose stones you carry. Click to look at them.")
		if DeepUi.phone:
			for pill in [ore, bag]:
				(pill as Control).custom_minimum_size = Vector2(DeepUi.pt(44), DeepUi.pt(28))
				(pill as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_ore_pill = ore
		_bag_pill = bag
		bag.mouse_filter = Control.MOUSE_FILTER_STOP
		bag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(bag, 1.06)
		bag.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if _run_dock.visible:
					_run_dock.toggle_drawer()
				else:
					open_bench("gems"))
		## What changed since the last look swells and says by how much; not while the salvage
		## dice are thrown, where the bag's "-2" floated over the page with nothing to say.
		if not _counts.is_empty() and str(run.get("phase", "")) != "salvage":
			for entry in [["ore", DeepUi.ORE], ["haul", DeepUi.ACCENT]]:
				var change: int = int(counts[entry[0]]) - int(_counts.get(entry[0], counts[entry[0]]))
				if change != 0:
					call_deferred("_celebrate", entry[0], ("+%d" % change) if change > 0 else str(change), entry[1] if change > 0 else DeepUi.BAD,
						int(_counts.get(entry[0], counts[entry[0]])), int(counts[entry[0]]))
		_counts = counts
	DeepUi.gear_button(_strip, func() -> void: menu_requested.emit()).focus_mode = Control.FOCUS_NONE

func _look_at_member(id: String) -> void:
	## Anyone in the party, yourself included, opens on the same sheet, read only.
	for other in run.get("players", []):
		if str(other.get("id", "")) == id:
			Inspector.member(other)
			return

func toggle_chart() -> void:
	_chart_open = not _chart_open
	DeepAudio.play("ui_open" if _chart_open else "ui_close", {"volume": 0.7})
	_map_margin.visible = _chart_open and (_area.visible or _battle.visible)
	## The creature's table keeps to the left of a fight: it steps aside for the chart.
	_battle.left_inset = (_map_margin.offset_right if DeepUi.phone else MAP_WIDTH) if _chart_open else 0.0
	_fit_area()
	_sync_strip()

func open_bench(which: String = "") -> void:
	if run.is_empty() or str(run.get("phase", "")) == "over":
		return
	_bench.open(run, which)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_B and not run.is_empty():
		## The bag drawer, when the dock is up; the whole bench otherwise.
		if _bench.is_open():
			_bench.close()
		elif _run_dock.visible:
			_run_dock.toggle_drawer()
		else:
			open_bench("")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M and not run.is_empty():
		toggle_chart()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_1, KEY_2, KEY_3] and _crossroads.visible and _stage.at_crossroads():
		## A way on by number, left to right.
		_choose_mouth(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9 and _take_numbered(event.keycode - KEY_1):
		## A card on the page by number, left to right: a stake, a pick stake's stones.
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _press_main():
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and not run.is_empty() and (not _pinned.is_empty() or _chart_open or not _oddity_step.is_empty()
			or (not _landing_view.is_empty() and str(run.get("phase", "")) == "landing")):
		## Esc puts away what was last opened here (a card pinned in the room, the chart, an
		## oddity's picker, a station at a landing) before it is the way into the menu, the
		## same as the Back and Never mind buttons beside them.
		if not _pinned.is_empty():
			_pin("")
		elif _chart_open:
			toggle_chart()
		elif not _oddity_step.is_empty():
			_oddity_step = ""
			show_state(run)
		else:
			_open_landing("")
		get_viewport().set_input_as_handled()

func _main(button: Button) -> Button:
	## Marks the page's way on: the button Enter presses.
	_main_button = button
	return button

func _numbered_card(card: PanelContainer, take: Callable) -> PanelContainer:
	## Marks a choice card the next number key takes (1 for the first drawn), doing what its
	## click does.
	_numbered.append({"card": card, "take": take})
	return card

func _keys_covered() -> bool:
	## Something stands over the page (the bench, a close look, the ask, a mine's sheet, the
	## Hollow's rite): the page's keys wait until it is gone.
	return _bench.is_open() or Inspector.is_open() or (_ask != null and _ask.is_open()) or Appraisal.is_open() \
		or (_conquest_sheet != null and is_instance_valid(_conquest_sheet)) or (_rite != null and is_instance_valid(_rite))

static func _key_ready(control: Variant) -> bool:
	## On screen, and not still easing in: a page just drawn takes no key until it can be seen.
	## Untyped, as what it is handed may have been freed with the page it was on.
	if not is_instance_valid(control) or not control is Control:
		return false
	if not (control as Control).is_visible_in_tree() or bool((control as Control).get_meta("disabled", false)):
		return false
	var node: Node = control
	while node is CanvasItem:
		if (node as CanvasItem).modulate.a < 0.5:
			return false
		node = node.get_parent()
	return true

func _press_main() -> bool:
	## Enter: the socket a find held up over the room offers, or else the page's way on. Says
	## whether there was one to press.
	if run.is_empty() or _keys_covered():
		return false
	for button in [_find_main, _main_button]:
		if _key_ready(button) and not (button as Button).disabled:
			(button as Button).pressed.emit()
			return true
	return false

func _take_numbered(index: int) -> bool:
	## A number key: the card it names on the page, as a click would take it.
	if run.is_empty() or _keys_covered() or index >= _numbered.size():
		return false
	var entry: Dictionary = _numbered[index]
	if not _key_ready(entry.card):
		return false
	DeepAudio.play("ui_confirm")
	DeepUi.pulse(entry.card, 1.04, 0.2)
	(entry.take as Callable).call()
	return true

# --- spoils ----------------------------------------------------------------------------------

func _page_spoils(content: VBoxContainer) -> void:
	## What a chamber gave up, presented: a title, then each thing won lit up one at a time.
	## A fight's spoils fly up out of the room itself; this page is a motherlode's.
	var hold: Dictionary = _hold
	var title: String = str(hold.get("title", "Victory"))
	var glyph: String = str(hold.get("glyph", "sword"))
	var tone: Color = DeepUi.ACCENT
	var subtitle: String = str(hold.get("subtitle", ""))
	var head := DeepUi.vbox(content, 6)
	var medal := Medallion.new(glyph, tone, 130)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	var heading := DeepUi.title(head, title, 46, tone.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	heading.add_theme_constant_override("outline_size", 8)
	DeepUi.label(head, subtitle, 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	if _fresh and not _headless:
		## A spray of every stone color off the medallion.
		var at := func() -> void:
			if is_instance_valid(medal):
				var centre: Vector2 = medal.size * 0.5
				for color in ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]:
					DeepUi.burst(medal, centre, DeepUi.color(color), 22, 380.0, 1.2, 7.0)
		get_tree().create_timer(0.2).timeout.connect(at)
	var rewards: Dictionary = hold.get("rewards", {})
	var card := DeepUi.card(content, Color(tone, 0.5), 18)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 12)
	DeepUi.section(box, "bag", "Spoils", tone)
	_reward_row(box, rewards, 0.45)
	_enter(card, 0.15)
	var next: String = "To the hoard" if str(run.get("phase", "")) == "hoard" else "Onward"
	var go := _main(DeepUi.primary(content, "crown" if next == "To the hoard" else "descend", next, _release, 19, tone))
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(260, 52)
	_enter(go, 0.6)

func _page_oddity_result(content: VBoxContainer) -> void:
	if _fresh:
		DeepAudio.play("oddity")
	var key: String = str(_hold.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var result: Dictionary = _hold.get("result", {})
	var tone: Color = _oddity_tone(str(_hold.get("room", "oddity")))
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new(str(ODDITY_GLYPHS.get(key, "question")), tone, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, str(oddity.get("name", "Something odd")), 36, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var said := DeepUi.wrap(head, str(result.get("message", "")), 19, tone.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, 760)
	said.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(head)
	## A Cut or a Clarity worked on is read off its ladder, the same as at the Market's Wheel
	## and Oven; a stone that broke flies apart there.
	var reworked: Dictionary = _reworked(result)
	## Lines that would give the ladder's answer away before it lands, held back until it has.
	var held_back: Array = []
	if not reworked.is_empty():
		var ladder: Control = _rework_reveal(content, reworked)
		if _fresh and not _headless:
			var told: String = said.text
			said.text = "The wheel bites into the stone…" if str(reworked.field) == "cut" else "The stone goes into the heat…"
			held_back.append(func() -> void:
				if is_instance_valid(said):
					said.text = told
					DeepUi.pop_in(said, 0.0, 0.97, 0.25))
			ladder.connect("finished", func() -> void:
				for tell in held_back:
					(tell as Callable).call(), CONNECT_ONE_SHOT)
	elif result.has("verdict"):
		_verdict_stamp(content, result.verdict)
	if not result.get("tumbled", {}).is_empty():
		_tumble_stamp(content, result.tumbled)
	if result.has("well"):
		_well_stamp(content, result.well, result.get("made", []))
	## The stone on the ladder is not shown a second time underneath it.
	var made: Array = result.get("made", []) + (result.get("changed", []) if reworked.is_empty() else [])
	var dice: Array = result.get("dice", [])
	var lost: Array = result.get("lost", [])
	if not made.is_empty() or not dice.is_empty():
		var card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 16)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var box := DeepUi.vbox(card, 10)
		DeepUi.section(box, "gem" if not made.is_empty() else "die", "What you have now")
		_reward_row(box, {"stones": made, "dice": dice, "faces": result.get("faces", {})}, 0.3)
		_enter(card, 0.15)
	if not lost.is_empty():
		var gone := DeepUi.stat(content, "split_shield", "%s gone for good." % DeepUi.plural(lost.size(), "stone"), DeepUi.BAD, 15)
		gone.alignment = BoxContainer.ALIGNMENT_CENTER
		if not reworked.is_empty() and _fresh and not _headless:
			gone.modulate.a = 0.0
			held_back.append(func() -> void:
				if is_instance_valid(gone):
					gone.create_tween().tween_property(gone, "modulate:a", 1.0, 0.3).set_delay(0.4))
	for die in result.get("dice_lost", []):
		DeepUi.stat(content, "die", "Gone until the run ends: %s." % DeepDice.describe(die), DeepUi.BAD, 15).alignment = BoxContainer.ALIGNMENT_CENTER
	var go := _main(DeepUi.primary(content, "descend", "Onward", _release, 18, tone))
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 240
	_enter(go, 0.4)

func _reward_row(parent: Node, rewards: Dictionary, start: float) -> HBoxContainer:
	## Each thing won in its own shaft of light, lit one after another.
	var row := DeepUi.hbox(parent, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var delay: float = start if _fresh else -1.0
	var step: float = 0.38
	var ore: int = int(rewards.get("ore", 0))
	var rung: int = 0
	if ore < 0:
		DeepUi.stat(row, "ore", "%d Pyrite after spending" % ore, DeepUi.ORE, 16)
	if ore > 0:
		var slot := RewardSlot.new(DeepUi.ORE, delay)
		slot.voice = "ore"
		slot.rung = rung
		rung += 1
		row.add_child(slot)
		var mark := DeepUi.icon(slot.content, "ore", 60, DeepUi.ORE)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var count := DeepUi.title(slot.content, "+%d" % ore, 26, DeepUi.ORE, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(slot.content, "pyrite", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		slot.count(count, ore, "+%d")
		delay = delay + step if delay >= 0.0 else delay
	for stone in rewards.get("stones", []):
		var appraised: bool = bool(stone.get("appraised", false))
		var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
		var slot := RewardSlot.new(tone, delay)
		slot.voice = "stone_found"
		slot.rung = rung
		rung += 1
		row.add_child(slot)
		var frame := DeepUi.center(slot.content)
		frame.custom_minimum_size = Vector2(96, 96)
		StoneCard.marked_picture(frame, stone, 84)
		DeepUi.name_label(slot.content, DeepUi.skill_name(stone) if appraised else DeepStone.raw_name(stone), 13, tone.lightened(0.3), 130)
		DeepUi.label(slot.content, DeepUi.touch_words("right-click to look"), 10, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		delay = delay + step if delay >= 0.0 else delay
	for die in rewards.get("dice", []):
		var tone: Color = DiceIcons.die_palette(die).body
		var slot := RewardSlot.new(tone, delay)
		slot.voice = "die_settle"
		slot.rung = rung
		rung += 1
		row.add_child(slot)
		## A die worked on one face is shown turned to that face, not to its best one.
		var thumb := Thumbs.DieThumb.new(die, 80, int(rewards.get("faces", {}).get(str(die.get("id", "")), -1)))
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.content.add_child(thumb)
		DeepUi.label(slot.content, DeepDice.describe(die), 13, tone.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER)
		delay = delay + step if delay >= 0.0 else delay
	if row.get_child_count() == 0:
		DeepUi.stat(row, "cloud", "Nothing but dust this time.", DeepUi.MUTED, 15)
	return row

class RewardSlot extends PanelContainer:
	## One thing won: it waits in the dark, then a beam falls on it, it bursts out of the
	## light, and whatever number it carries counts up.
	var content: VBoxContainer
	var tone: Color
	## What this thing sounds like when the light reaches it, and how far up the ladder it is.
	var voice: String = "stone_found"
	var rung: int = 0
	var _delay: float
	var _clock: float = 0.0
	var _lit: float = 0.0
	var _counter: Label = null
	var _amount: int = 0
	var _format: String = "%d"
	func _init(color: Color, delay: float) -> void:
		tone = color
		_delay = delay
		custom_minimum_size = Vector2(150, 170)
		var style := DeepUi.raised(Color(0.05, 0.06, 0.085, 0.95), Color(tone, 0.55), 14, 12, 0.5)
		style.border_width_bottom = 3
		add_theme_stylebox_override("panel", style)
		mouse_filter = Control.MOUSE_FILTER_PASS
		content = DeepUi.vbox(self, 6)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		if delay >= 0.0 and DisplayServer.get_name() != "headless":
			modulate.a = 0.0
		else:
			_lit = 1.0
	func count(label: Label, amount: int, format: String) -> void:
		_counter = label
		_amount = amount
		_format = format
		if _lit < 1.0:
			label.text = format % 0
	func _process(delta: float) -> void:
		_clock += delta
		if _lit < 1.0 and _clock >= _delay:
			_lit = 1.0
			modulate.a = 1.0
			DeepAudio.from(self, voice, {"pitch": 1.0 + 0.07 * float(rung), "gap": 0.0})
			DeepUi.pulse(self, 1.2, 0.45)
			DeepUi.burst(self, size * 0.5, tone.lightened(0.3), 36, 260.0, 0.9, 6.0)
			if _counter != null:
				var shown: Label = _counter
				var tween := create_tween()
				tween.tween_method(func(v: float) -> void: shown.text = _format % int(round(v)), 0.0, float(_amount), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func _draw() -> void:
		if _lit < 1.0:
			return
		var glow: Texture2D = DeepUi.glow_texture()
		var pulse: float = 0.8 + 0.2 * sin(_clock * 2.2)
		var beam := PackedVector2Array([Vector2(size.x * 0.35, 0), Vector2(size.x * 0.65, 0), Vector2(size.x * 0.9, size.y), Vector2(size.x * 0.1, size.y)])
		draw_colored_polygon(beam, Color(tone, 0.09 * pulse))
		var pool := Vector2(size.x * 1.1, size.y * 0.5)
		draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, size.y * 0.45) - pool * 0.5, pool), false, Color(tone, 0.22 * pulse))

# --- vein ------------------------------------------------------------------------------------

# --- the grubstake ---------------------------------------------------------------------------
##
## The stakes are shown as what they are, with nothing to set: a stake on a stone lands on
## one drawn at random from the rail, and a pick keeps its three candidates face down until
## it is taken. Taking one turns the page to the three, large: raw stones of three colors,
## and the one kept is read under the loupe at once.

const STAKE_WORDS: Dictionary = {"stone": "A stone stake", "kit": "A kit stake", "terms": "Terms", "deep": "From the deep", "reward": "A reward"}
const STAKE_GLYPHS: Dictionary = {"stone": "gem", "kit": "bag", "terms": "scales", "deep": "descend", "reward": "star"}
## A deep start's own cards, and the "Deep" and "Better" marks a deep hand's cards wear: the
## Peerless grade's gold (DeepUi.TIER_colorS), the game's word for the best there is.
const DEEP_TONE := Color("ffcf5a")
## What a card that is chosen on a page of its own says before it is taken, by `pick_kind`.
const PICK_HINTS: Dictionary = {"stone": "The three are shown once you take it.", "stones": "You choose them once you take it.",
	"dice": "You choose the swaps once you take it.", "material": "You choose the material once you take it.",
	"charges": "You choose the dice once you take it."}

func _stake_tone(kind: String) -> Color:
	match kind:
		"stone": return DeepUi.ACCENT
		"kit": return DeepUi.INFO
		"terms": return Color("c58bff")
		## A deep start's stronger stake may be a reward alone, with no cost beside it.
		"reward": return DeepUi.GOOD
		"deep": return DEEP_TONE
	return DeepUi.ORE

static func stake_picks(offer: Dictionary) -> bool:
	## A card whose take is chosen on a page of its own: a pick of three, a bag of gems or dice,
	## a material.
	return offer.get("needs", []).any(func(need: Variant) -> bool: return str(need) in ["pick", "picks", "swaps", "charges"])

func _stake_ribbon(row: HBoxContainer, offer: Dictionary) -> void:
	## A deep start's cards say they are special in the card's corner: a deep card "Deep", a
	## Quarry stake made better for the mines skipped "Better +k".
	var deep: bool = bool(offer.get("deep", false))
	if not deep and not bool(offer.get("upgraded", false)):
		return
	var k: int = int(offer.get("k", 0))
	DeepUi.spacer(row)
	var ribbon := DeepUi.pill(row, "descend" if deep else "rise", "Deep" if deep else "Better +%d" % k, DEEP_TONE, 12,
		("Only a start below the first mine offers this." if deep else "The workshop's own stake, made better for each of the %s you skip." % DeepUi.plural(k, "mine")))
	ribbon.name = "DeepRibbon" if deep else "BetterTag"
	ribbon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _page_grubstake(content: VBoxContainer) -> void:
	## The shaft head: the workshop's stakes, one to be taken before the lift goes down.
	var unit: Dictionary = me()
	var stake: String = str(unit.get("stake", ""))
	var offers: Array = run.get("grubstake", {}).get("offers", {}).get(local_id, [])
	var choosing: Dictionary = {}
	for offer in offers:
		if stake.is_empty() and str(offer.get("id", "")) == _stake_choosing:
			choosing = offer
	if choosing.is_empty():
		_stake_choosing = ""
	if _fresh and stake.is_empty() and choosing.is_empty():
		## The host has usually just heard this from the Descend button.
		DeepAudio.play("depart", {"volume": 0.8, "gap": 2.5})
	## Below the Quarry the empty sockets are filled first, one at a time, then each die is
	## offered a swap, one at a time, and then the stakes are offered.
	if DeepDescent.temporary_left(unit) > 0:
		_page_temporary(content, unit)
		return
	if DeepDescent.dice_offers_left(unit) > 0:
		_page_dice_offer(content, unit)
		return
	if not choosing.is_empty():
		_page_stake_pick(content, choosing)
		return
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("bag", DeepUi.ACCENT)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, "The Grubstake", 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(head, "Before you head down, the workshop gives you a head start. Pick one. It only lasts for this run.", 12 if DeepUi.phone else 16, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, DeepUi.pt(660) if DeepUi.phone else 760.0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## A deep start (docs/DEEP_START.md): its cards come from the mines it skips, and say so.
	var deep_k: int = int(run.get("deep_start", 0))
	if deep_k > 0 and run.get("daily", {}).is_empty():
		var skipped: Array = DeepDescent.skipped_mines(str(run.get("mine", ""))).map(func(m: Variant) -> String: return DeepContent.mine_name(str(m)))
		var deep_line := DeepUi.stat(head, "descend", "Starting deep, you skip %s: the workshop's cards are better for it." % names_of(skipped), DEEP_TONE, 14)
		deep_line.alignment = BoxContainer.ALIGNMENT_CENTER
		deep_line.name = "DeepStart"
		## Six mines' names on one line ran past the phone's screen: there it wraps under its mark.
		var deep_said: Label = deep_line.get_node("Value")
		var deep_room: float = DeepUi.pt(640)
		if DeepUi.phone and DeepUi.text_face(DeepUi.readable(14)).get_string_size(deep_said.text, HORIZONTAL_ALIGNMENT_LEFT, -1, DeepUi.readable(14)).x > deep_room:
			deep_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			deep_said.custom_minimum_size.x = deep_room
	## A Birthstone that grows all run opens a deep start with a head start (a Renown its
	## Trophies, a Bloodroot its max health): said here, where the run begins.
	var head_start: Variant = unit.get("head_start", {})
	var opens: String = Plates.birth_opens(str(DeepStone.birthstone_for(unit).get("name", "")), head_start) if head_start is Dictionary else ""
	if not opens.is_empty():
		var opens_line := DeepUi.stat(head, "crown", opens, Roster.stone_tone(DeepStone.birthstone_for(unit)), 11 if DeepUi.phone else 14)
		opens_line.alignment = BoxContainer.ALIGNMENT_CENTER
		opens_line.name = "HeadStart"
	_enter(head)
	if not run.get("daily", {}).is_empty():
		_enter(_daily_banner(content), 0.05)
	if not stake.is_empty():
		var result_card := _stake_result(content, run.get("grubstake", {}).get("chosen", {}).get(local_id, {}))
		_enter(result_card, 0.1)
		return
	var rail_empty: bool = not unit.get("rail", []).any(func(s: Variant) -> bool: return s is Dictionary)
	var row := DeepUi.hbox(content, int(DeepUi.pt(8)) if DeepUi.phone else 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	## On the phone the cards share the page's width, 150 to 210 points each (board run-room).
	var card_width: float = 270.0
	## Four or more to a row on the phone: their words at the floor, 11 points.
	var words_size: int = 11 if DeepUi.phone and offers.size() >= 4 else (12 if DeepUi.phone else 13)
	if DeepUi.phone:
		var room: float = content.custom_minimum_size.x if content.custom_minimum_size.x > 0.0 else DeepUi.pt(700)
		card_width = clampf((room - DeepUi.pt(8) * float(maxi(0, offers.size() - 1))) / float(maxi(1, offers.size())), DeepUi.pt(150), DeepUi.pt(210))
	var index: int = 0
	for offer in offers:
		var kind: String = str(offer.get("kind", "kit"))
		var tone: Color = _stake_tone(kind)
		var offer_id: String = str(offer.get("id", ""))
		var picks: bool = stake_picks(offer)
		var take := func() -> void:
			if picks:
				_stake_choosing = offer_id
				show_state(run)
			else:
				command.emit({"kind": "stake", "offer": offer_id, "payload": {}})
		var card := _numbered_card(DeepUi.choice_card(row, tone, take), take)
		card.custom_minimum_size = Vector2(card_width, 0)
		var box := DeepUi.vbox(card, int(DeepUi.pt(3)) if DeepUi.phone else 8)
		var tag := DeepUi.hbox(box, 6)
		DeepUi.icon(tag, str(STAKE_GLYPHS.get(kind, "bag")), DeepUi.glyph_px(11) if DeepUi.phone else 18.0, tone)
		DeepUi.label(tag, str(STAKE_WORDS.get(kind, "A stake")), 11 if DeepUi.phone else 12, tone)
		_stake_ribbon(tag, offer)
		var on_stones: int = 0
		## Anything that works only on set stones, every-stone rewards too: on an empty rail the
		## card would take its cost and give nothing back.
		var needs_rail: bool = false
		## A deep start's cards carry their own names and words, filled with this card's numbers
		## (the content's words are the Quarry's): those are the ones shown.
		var names: Array = offer.get("names", [])
		var texts: Array = offer.get("texts", [])
		var boons: Array = offer.get("boons", [])
		for at in range(boons.size()):
			var key: String = str(boons[at])
			var def: Dictionary = DeepContent.boon(key)
			var is_cost: bool = str(def.get("group", "")) == "cost"
			if str(def.get("needs", "")) == "socket":
				on_stones += 1
			if not DeepBoons.works_bare(key):
				needs_rail = true
			var title_row := DeepUi.hbox(box, 6)
			if kind == "terms":
				DeepUi.icon(title_row, "cross_out" if is_cost else "check", 16, DeepUi.BAD if is_cost else DeepUi.GOOD)
			DeepUi.title(title_row, str(names[at]) if at < names.size() else str(def.get("name", key)), 15 if DeepUi.phone else 18, DeepUi.BAD.lightened(0.2) if is_cost else DeepUi.PAPER)
			DeepUi.wrap(box, str(texts[at]) if at < texts.size() else str(def.get("text", "")), words_size, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, card_width - DeepUi.pt(22) if DeepUi.phone else 236.0)
		if on_stones > 1:
			_card_note(box, "gem", "Both fall on the same stone.", DeepUi.MUTED, card_width, words_size)
		if picks:
			var hint: String = "charges" if offer.get("needs", []).has("charges") else str(offer.get("pick_kind", "stone"))
			_card_note(box, "eye", str(PICK_HINTS.get(hint, PICK_HINTS.stone)), DeepUi.MUTED, card_width, words_size)
		## A kit drawn from the mercy stakes after a fall says why it is on offer.
		if bool(offer.get("mercy", false)):
			var mercy := DeepUi.hbox(box, 6)
			DeepUi.icon(mercy, "heart", 15, DeepUi.GOOD)
			DeepUi.wrap(mercy, "The workshop goes easy on you after that fall.", 12, DeepUi.GOOD, HORIZONTAL_ALIGNMENT_LEFT, 214)
		## The picture stands in the middle of whatever room the card has under its words.
		DeepUi.spacer(box, false)
		## On the phone the words need the card's room: no picture (docs/PHONE_UI.md).
		if not DeepUi.phone:
			_stake_picture(box, offer, unit)
		DeepUi.spacer(box, false)
		if needs_rail and rail_empty:
			DeepUi.disable_choice(card)
			_card_note(box, "cross_out", "Your rail is empty.", DeepUi.DIM, card_width, words_size)
		_enter(card, 0.1 + 0.08 * index)
		index += 1

func _card_note(box: VBoxContainer, glyph: String, words: String, tone: Color, card_width: float, words_size: int = 12) -> void:
	## A note at the foot of a stake's card. On the phone it wraps to the card: one line of it
	## made the card wider than the four in a row could be.
	if not DeepUi.phone:
		DeepUi.stat(box, glyph, words, tone, 12)
		return
	var row := DeepUi.hbox(box, int(DeepUi.pt(4)))
	DeepUi.icon(row, glyph, DeepUi.glyph_px(words_size), tone).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	DeepUi.wrap(row, words, words_size, tone, HORIZONTAL_ALIGNMENT_LEFT, card_width - DeepUi.pt(40))

## How tall the picture in a stake's card stands.
const STAKE_PICTURE: float = 64.0
## How often the stone in a stone stake's picture turns to the next one on the rail.
const STAKE_TURN: float = 1.6

func _stake_picture(box: VBoxContainer, offer: Dictionary, unit: Dictionary) -> void:
	## What a stake does, drawn small in the room its card has under its words (every card in
	## the row stands as tall as the tallest): the stone it weighs heavier, the die it hammers
	## bigger, the rail it lights. A cost is not drawn; its words are in red above.
	var effect: Dictionary = {}
	for key in offer.get("boons", []):
		var def: Dictionary = DeepContent.boon(str(key))
		## A deep start's stake is drawn with its better numbers (DeepBoons.effects_of).
		var effects: Array = DeepBoons.effects_of(str(key), int(offer.get("k", 0)))
		if str(def.get("group", "")) != "cost" and not effects.is_empty():
			effect = effects[0]
			break
	var row := DeepUi.hbox(box, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size.y = STAKE_PICTURE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind: String = str(effect.get("kind", ""))
	var amount: int = int(effect.get("amount", 0))
	var set_stones: Array = unit.get("rail", []).filter(func(s: Variant) -> bool: return s is Dictionary)
	match kind:
		"carat", "cut_step":
			_stake_stone(row, set_stones)
			var gain := DeepUi.pill(row, "rise" if amount >= 0 else "fall", ("%+d ct" if kind == "carat" else "%+d Cut") % amount, DeepUi.GOOD if amount >= 0 else DeepUi.BAD, 13)
			gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		"rail_all":
			_stake_rail(row, unit)
		"resize_die", "wild_face":
			if not _stake_die(row, unit.get("dice", []), effect):
				row.queue_free()
		"ore":
			_stake_figure(row, "ore", "+%d" % amount, DeepUi.ORE)
		"max_hp_pct":
			_stake_figure(row, "heart", "%+d%%" % amount, DeepUi.GOOD if amount >= 0 else DeepUi.BAD)
		"extra_rerolls":
			_stake_figure(row, "reroll", "+%d" % amount, DeepUi.INFO)
		"soft_rock":
			## A creature at half its health, for as many fights as it lasts.
			DeepUi.icon(row, "skull", 30, DeepUi.BAD).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bar := Control.new()
			bar.custom_minimum_size = Vector2(80, 10)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(bar)
			var back := ColorRect.new()
			back.color = Color(1, 1, 1, 0.12)
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bar.add_child(back)
			var fill := ColorRect.new()
			fill.color = DeepUi.BAD
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fill.anchor_right = 0.5
			fill.anchor_bottom = 1.0
			bar.add_child(fill)
			var times := DeepUi.label(row, "×%d" % int(effect.get("fights", 1)), 20, DeepUi.BAD.lightened(0.2))
			times.add_theme_font_override("font", DeepUi.bold_font())
			times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		"raw_stone":
			## A stone still to be drawn, already read: a socket waiting, and the loupe's word.
			_stake_ring(row, STAKE_PICTURE, "ANY", true).add_child(_centred_glyph("question", 20.0, DeepUi.MUTED))
			DeepUi.pill(row, "loupe", "appraised", DeepUi.INFO, 13).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		"pick_stone":
			## Three, face down until it is taken.
			for _face_down in range(int(effect.get("count", 3))):
				_stake_ring(row, 46.0, "ANY", false).add_child(_centred_glyph("question", 14.0, DeepUi.MUTED))
		## A deep start's own cards (docs/DEEP_START.md), drawn from what the card holds.
		"gem_pouch":
			_stake_figure(row, "gem", "%d of %d" % [int(offer.get("take", 1)), offer.get("picks", []).size()], DEEP_TONE)
		"dice_bag":
			_stake_figure(row, "die", "×%d" % offer.get("picks", []).size(), DEEP_TONE)
		"one_material":
			## One of the player's dice wearing each material on offer.
			var dice: Array = unit.get("dice", [])
			if dice.is_empty():
				row.queue_free()
			for material in offer.get("picks", []):
				if dice.is_empty():
					break
				var worn: Dictionary = dice[0].duplicate(true)
				worn.material = str(material)
				var thumb := Thumbs.DieThumb.new(worn, 50)
				thumb.tooltip_text = ""
				thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(thumb)
		"heirloom":
			_stake_stone(row, set_stones.filter(func(s: Dictionary) -> bool: return bool(s.get("lent", false))))
			var gain := DeepUi.pill(row, "rise", "+%d ct · +%d Cut" % [int(offer.get("carats", 0)), int(offer.get("cut", 1))], DeepUi.GOOD, 13)
			gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		"deep_purse":
			_stake_figure(row, "ore", "+%d" % int(offer.get("ore", 0)), DeepUi.ORE)
			var raws := DeepUi.pill(row, "gem", "+%d raw" % offer.get("stones", []).size(), DeepUi.MUTED, 13)
			raws.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		"vouchers":
			_stake_figure(row, "anvil", "×%d" % int(offer.get("rooms", 0)), DEEP_TONE)
		_:
			row.queue_free()

func _stake_ring(row: Control, edge: float, color_key: String, lit: bool) -> Control:
	## A socket drawn small for a stake's picture: its bezel, lit when the stake reaches it.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(edge, edge)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var ring := BattleScreen.SocketRing.new(color_key, not lit)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if lit:
		ring.set_ready(true)
	slot.set_meta("ring", ring)
	return slot

func _centred_glyph(glyph: String, inset: float, tone: Color) -> Control:
	## A mark in the middle of a stake's socket, `inset` in from its rim all round.
	var mark := TextureRect.new()
	mark.texture = GemIcons.texture(glyph, GemIcons.baked_size(STAKE_PICTURE))
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.modulate = tone
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(inset))
	return mark

func _stake_stone(row: Control, stones: Array) -> void:
	## A stone in its socket, lit. The stake falls on one drawn at random, so the picture turns
	## through every stone on the rail rather than naming one of them.
	if stones.is_empty():
		_stake_ring(row, STAKE_PICTURE, "ANY", false)
		return
	var slot := _stake_ring(row, STAKE_PICTURE, DeepStone.color(stones[0]), true)
	var ring: Control = slot.get_meta("ring")
	var picture := Thumbs.GemThumb.new(stones[0], STAKE_PICTURE - 14)
	picture.live_on_hover = false
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	slot.add_child(picture)
	if stones.size() < 2 or _headless:
		return
	var turn := Timer.new()
	turn.wait_time = STAKE_TURN
	turn.autostart = true
	slot.add_child(turn)
	var at: Array = [0]
	turn.timeout.connect(func() -> void:
		at[0] = (int(at[0]) + 1) % stones.size()
		var next: Dictionary = stones[int(at[0])]
		picture.configure(next)
		ring.set("color", DeepStone.color(next))
		ring.queue_redraw()
		DeepUi.pulse(slot, 1.08, 0.2))

func _stake_rail(row: Control, unit: Dictionary) -> void:
	## The whole rail, every socket with a stone in it lit.
	var sockets: Array = DeepContent.character(str(unit.get("character", ""))).get("sockets", [])
	row.add_theme_constant_override("separation", 5)
	## As big as fits the card's words across: a long rail draws its sockets smaller.
	var edge: float = minf(34.0, floorf((230.0 - 5.0 * float(maxi(0, sockets.size() - 1))) / float(maxi(1, sockets.size()))))
	for index in range(sockets.size()):
		var stone: Variant = unit.rail[index] if index < unit.get("rail", []).size() else null
		var set_here: bool = stone is Dictionary
		var slot := _stake_ring(row, edge, str(sockets[index]), set_here)
		if set_here:
			var picture := Thumbs.GemThumb.new(stone, edge - 8.0)
			picture.live_on_hover = false
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
			slot.add_child(picture)
		else:
			slot.modulate.a = 0.5

func _stake_die(row: Control, dice: Array, effect: Dictionary) -> bool:
	## One of the bowl's dice as it is and as the stake leaves it: a size bigger, or its
	## highest plain face turned wild. False when no die could take it.
	var resize: bool = str(effect.get("kind", "")) == "resize_die"
	var steps: int = int(effect.get("amount", 1)) if int(effect.get("amount", 0)) != 0 else 1
	var before: Dictionary = {}
	for die in dice:
		var able: bool = DeepOddities.resize_refusal(die, steps).is_empty() if resize else \
			die.get("faces", []).any(func(f: Dictionary) -> bool: return str(f.get("kind", "plain")) == "plain")
		if able:
			before = die
			break
	if before.is_empty():
		return false
	var after: Dictionary = before.duplicate(true)
	if resize:
		DeepOddities.resize(after, steps)
	else:
		var best: int = -1
		for index in range(after.faces.size()):
			if str(after.faces[index].get("kind", "plain")) == "plain" and (best < 0 or int(after.faces[index].value) > int(after.faces[best].value)):
				best = index
		after.faces[best] = DeepDice.face(int(after.faces[best].value), "wild")
	for side in range(2):
		if side == 1:
			DeepUi.icon(row, "next", 22, DeepUi.MUTED).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var thumb := Thumbs.DieThumb.new(before if side == 0 else after, STAKE_PICTURE + 6)
		thumb.tooltip_text = ""
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(thumb)
	return true

func _stake_figure(row: Control, glyph: String, figure: String, tone: Color) -> void:
	## A mark and a number, large: pyrite in hand, health, a reroll.
	DeepUi.icon(row, glyph, 34, tone).mouse_filter = Control.MOUSE_FILTER_IGNORE
	DeepUi.title(row, figure, 28, tone.lightened(0.15)).size_flags_vertical = Control.SIZE_SHRINK_CENTER

## How big a socket or a die is drawn in the strip over a shaft-head choice.
const STRIP_EDGE: float = 44.0
## A die offered at the shaft head, by which way its size went: [glyph, word].
const OFFER_SIDES: Array = [["fall", "Smaller"], ["die", "Same size"], ["rise", "Bigger"]]
## Past this many faces an offered die says how many it has instead of drawing each one.
const OFFER_FACES_DRAWN: int = 30
## The medallion over a shaft-head choice: smaller than an ending's, so the choice itself fits
## the room above the dock.
const SHAFT_MEDAL: float = 76.0

func _shaft_head(content: VBoxContainer, glyph: String, tone: Color, title: String, text: String, medal_shown: bool = true) -> void:
	## The top of a shaft-head choice: its mark, its name and one line on what it is. A page
	## that needs every line it can get (a big Bag of Gems, turned a page at a time) goes
	## without the mark.
	var head := DeepUi.vbox(content, 6)
	if medal_shown:
		var medal := Medallion.new(glyph, tone, SHAFT_MEDAL)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		head.add_child(medal)
	DeepUi.title(head, title, 30, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.wrap(head, text, 14, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, 860).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(head)

func _page_temporary(content: VBoxContainer, unit: Dictionary) -> void:
	## A party that starts below the Quarry: every socket with no stone of its own (shut, or
	## bought and left empty) is offered three temporary stones in its color, read already,
	## one socket at a time, the one being filled lit on the rail above. They are gone when
	## the run ends.
	var current: Dictionary = {}
	for offer in unit.get("temps", []):
		if int(offer.get("chosen", -1)) < 0:
			current = offer
			break
	if current.is_empty():
		return
	_shaft_head(content, "gem", DeepUi.INFO, "Temporary stones", "No socket goes down empty. Each one with no stone of yours gets one here, lent for this run only: it can't be kept, sold or thrown down a well, and it shatters when the run ends.")
	var body := DeepUi.vbox(content, 8)
	var socket_index: int = int(current.get("index", 0))
	_socket_strip(body, unit, socket_index)
	var socket: String = str(current.get("socket", DeepContent.SOCKET_RAINBOW))
	var left: int = DeepDescent.temporary_left(unit)
	var line := DeepUi.hbox(body, 8)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.title(line, "Socket %d" % (socket_index + 1), 18, DeepUi.PAPER)
	DeepUi.label(line, DeepContent.socket_name(socket), 14, DeepUi.socket_tone(socket, DeepUi.MUTED))
	DeepUi.label(line, "·  %s to fill" % DeepUi.plural(left, "socket") if left > 1 else "·  the last to fill", 14, DeepUi.MUTED)
	var row := DeepUi.hbox(body, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var picks: Array = current.get("picks", [])
	for pick_index in range(picks.size()):
		var taken: int = pick_index
		var take := func() -> void: command.emit({"kind": "temporary", "index": socket_index, "pick": taken})
		var card := _numbered_card(_stone_option(row, picks[pick_index], take), take)
		_enter(card, 0.1 + 0.08 * pick_index)
	DeepUi.stat(body, "eye", DeepUi.touch_words("Right-click a stone for the close look."), DeepUi.DIM, 12).alignment = BoxContainer.ALIGNMENT_CENTER

func _stone_option(parent: Node, stone: Dictionary, callback: Callable, chosen: bool = false) -> PanelContainer:
	## A stone to choose, drawn compact: its picture with its grade marked on it, its name,
	## what it does, and what is frozen inside it as chips. The close look has the rest.
	## `chosen` (one of several taken together, a Bag of Gems) rims it in gold with a check
	## under its picture; the gold is its look at rest, so the pointer leaving keeps it.
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier))
	var card: PanelContainer
	if chosen:
		card = PanelContainer.new()
		var rim: StyleBoxFlat = DeepUi.raised(Color(DeepUi.GLASS.lerp(DEEP_TONE, 0.12), DeepUi.GLASS.a), DEEP_TONE, 12, 12)
		rim.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", rim)
		parent.add_child(card)
		DeepUi.make_choice(card, DEEP_TONE, callback)
		card.set_meta("chosen", true)
	else:
		card = DeepUi.choice_card(parent, tone, callback, 12)
	card.custom_minimum_size.x = 340
	var row := DeepUi.hbox(card, 12)
	## The left column: a bare picture (its grade is written beside its name, so nothing is laid
	## over the stone), and centred under it what the stone asks of the hand at its own cut, the
	## way the bench writes it under a set stone (the owner, November 5, 2026: under the gem
	## itself, not among the words). The choice is as much the trigger as the effect.
	var left := DeepUi.vbox(row, 4)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.custom_minimum_size.x = 72
	var picture := Thumbs.GemThumb.new(stone, 72)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(picture)
	var trigger_row := DeepUi.hbox(left, 0)
	trigger_row.name = "Trigger"
	trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), 18, DeepUi.MUTED)
	## A chosen stone is marked by its gold rim alone (the owner, November 6, 2026, round 7): no
	## check, so choosing one moves nothing on the card or the page.
	var words := DeepUi.vbox(row, 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.fit_label(words, DeepUi.skill_name(stone), 17, tone.lightened(0.2), 230, HORIZONTAL_ALIGNMENT_LEFT)
	StoneCard.grade_marks(words, stone, 12)
	DeepUi.effect_text(words, DeepStone.text(stone), 13, DeepUi.PAPER, false, 230)
	if not stone.get("inclusions", []).is_empty():
		var inside := HFlowContainer.new()
		inside.add_theme_constant_override("h_separation", 6)
		inside.add_theme_constant_override("v_separation", 4)
		inside.custom_minimum_size.x = 230
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(inside)
		for key in stone.inclusions:
			StoneCard._inclusion_chip(inside, str(key))
	## The plate the rail shows for it, over the whole card: the trigger at its own cut is what
	## says a word like "low" means a die showing 2 or less.
	Tips.attach(card, func() -> Control:
		var plate: Control = Plates.gem(stone, {}, [], {}, [], {})
		Plates.footer(plate)
		return plate, {"tone": DeepUi.color(DeepStone.color(stone)), "keep": true})
	_close_look_on_right(card, func() -> void: Inspector.stone(stone))
	return card

func _close_look_on_right(card: Control, look: Callable) -> void:
	## A right-click anywhere on a stone's or a die's choice card opens its close look, not only
	## on its picture: the words are where the eye is when the question comes up.
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			look.call()
			card.accept_event())
	## A finger held on the card does the same.
	Tips.hold(card, look)

func _socket_strip(content: VBoxContainer, unit: Dictionary, current: int) -> void:
	## The rail over a temporary stone's choice: every socket, the one being filled lit, the
	## ones still to fill dimmed, the rest showing what is set in them.
	var sockets: Array = DeepContent.character(str(unit.get("character", ""))).get("sockets", [])
	var waiting: Array = []
	for offer in unit.get("temps", []):
		if int(offer.get("chosen", -1)) < 0:
			waiting.append(int(offer.get("index", -1)))
	var row := DeepUi.hbox(content, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(sockets.size()):
		var cell := DeepUi.vbox(row, 2)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(STRIP_EDGE, STRIP_EDGE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(slot)
		var stone: Variant = unit.rail[index] if index < unit.get("rail", []).size() else null
		var set_here: bool = stone is Dictionary
		var ring := BattleScreen.SocketRing.new(str(sockets[index]), not set_here)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(ring)
		if set_here:
			var picture := Thumbs.GemThumb.new(stone, STRIP_EDGE - 10)
			picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
			slot.add_child(picture)
		var now: bool = index == current
		if now:
			ring.set_ready(true)
		var word: String = "Now" if now else ("Lent" if set_here and bool(stone.get("temporary", false)) else ("To fill" if waiting.has(index) else ""))
		DeepUi.label(cell, word, 12, DeepUi.ACCENT if now else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if waiting.has(index) and not now:
			cell.modulate.a = 0.55

func _page_dice_offer(content: VBoxContainer, unit: Dictionary) -> void:
	## A party that starts below the Quarry: each die in the bowl is offered three to swap it
	## for, one die at a time, the one being offered lit in the bowl above: one its size or
	## smaller, one its size, one its size or bigger. Or it is kept as it is.
	var current: Dictionary = {}
	for offer in unit.get("dice_offers", []):
		if int(offer.get("chosen", -1)) < 0 and not bool(offer.get("kept", false)):
			current = offer
			break
	if current.is_empty():
		return
	var index: int = int(current.get("index", 0))
	var original: Dictionary = unit.dice[index] if index < unit.get("dice", []).size() else {}
	_shaft_head(content, "anvil", DeepUi.ACCENT, "Dice for the deep", "Starting in %s skips the smithies, carvers and vats above it. For each of your dice, take one of three to swap it for, or keep it. A swap lasts for this run only." % DeepContent.mine_name(str(run.get("mine", ""))))
	var body := DeepUi.vbox(content, 10)
	_bowl_strip(body, unit, index)
	var row := DeepUi.hbox(body, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var sizes: Array = DeepOddities.SIZES
	var base: int = sizes.find(str(original.get("shape", "")))
	var picks: Array = current.get("picks", [])
	for side in range(picks.size()):
		var pick: Dictionary = picks[side]
		var named: Array = OFFER_SIDES[signi(sizes.find(str(pick.get("shape", ""))) - base) + 1]
		var tone: Color = DiceIcons.die_palette(pick).body
		var taken: int = side
		var take := func() -> void: command.emit({"kind": "dice_offer", "index": index, "pick": taken})
		var card := _numbered_card(DeepUi.choice_card(row, DeepUi.ACCENT, take, 12), take)
		card.custom_minimum_size.x = 330
		var line := DeepUi.hbox(card, 12)
		var thumb := Thumbs.DieThumb.new(pick, 64)
		## The card's plate says all of it; the picture's own tooltip would say it twice.
		thumb.tooltip_text = ""
		thumb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(thumb)
		var box := DeepUi.vbox(line, 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tag := DeepUi.hbox(box, 6)
		DeepUi.icon(tag, str(named[0]), 14, DeepUi.ACCENT)
		DeepUi.label(tag, str(named[1]), 12, DeepUi.ACCENT)
		DeepUi.fit_label(box, DeepDice.describe(pick), 16, tone.lightened(0.25), 220, HORIZONTAL_ALIGNMENT_LEFT)
		_offer_faces(box, pick)
		for change in _die_changes(original, pick):
			DeepUi.stat(box, str(change[0]), str(change[1]), DeepUi.BAD.lightened(0.2) if str(change[0]) == "cross_out" else DeepUi.PAPER, 12)
		## The die plate over the whole card, as the dock shows it: its faces, and the words
		## for its pattern, material and etchings, which the lines above only name.
		Tips.attach(card, func() -> Control:
			var plate: Control = Plates.die(pick)
			Plates.footer(plate)
			return plate, {"tone": tone})
		_close_look_on_right(card, func() -> void: Inspector.die(pick))
		_enter(card, 0.1 + 0.08 * side)
	var keep_row := DeepUi.hbox(body, 10)
	keep_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var kept_thumb := Thumbs.DieThumb.new(original, 32)
	keep_row.add_child(kept_thumb)
	var keep := DeepUi.button(keep_row, "Keep your %s" % DeepDice.describe(original), func() -> void:
		command.emit({"kind": "dice_offer", "index": index, "pick": - 1}), 15)
	keep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.stat(body, "eye", DeepUi.touch_words("Right-click a die for the close look."), DeepUi.DIM, 12).alignment = BoxContainer.ALIGNMENT_CENTER

func _bowl_strip(content: VBoxContainer, unit: Dictionary, current: int) -> void:
	## The bowl over a die's choice: every die, the one being offered lit, the ones already
	## answered for marked, the ones still to come dimmed.
	var row := DeepUi.hbox(content, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for offer in unit.get("dice_offers", []):
		var index: int = int(offer.get("index", 0))
		var die: Dictionary = unit.dice[index] if index < unit.get("dice", []).size() else {}
		var now: bool = index == current
		var swapped: bool = int(offer.get("chosen", -1)) >= 0
		var answered: bool = swapped or bool(offer.get("kept", false))
		var frame := DeepUi.panel(row, Color(DeepUi.ACCENT, 0.16) if now else Color(1, 1, 1, 0.03), Color(DeepUi.ACCENT, 0.9) if now else Color(1, 1, 1, 0.08), 10, 5)
		var cell := DeepUi.vbox(frame, 1)
		var thumb := Thumbs.DieThumb.new(die, STRIP_EDGE)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(thumb)
		DeepUi.label(cell, "Now" if now else ("Swapped" if swapped else ("Kept" if answered else "To come")), 12, DeepUi.ACCENT if now else (DeepUi.GOOD if swapped else DeepUi.DIM), HORIZONTAL_ALIGNMENT_CENTER)
		if not now and not answered:
			frame.modulate.a = 0.55

func _offer_faces(parent: Node, die: Dictionary) -> void:
	## An offered die's faces, wrapped to its card; a very big die says how many it has.
	var faces: Array = die.get("faces", [])
	if faces.size() > OFFER_FACES_DRAWN:
		var low: int = 0
		var high: int = 0
		for f in faces:
			low = mini(low, DeepDice.face_value(f)) if low != 0 else DeepDice.face_value(f)
			high = maxi(high, DeepDice.face_value(f))
		DeepUi.label(parent, "%d faces, %d to %d" % [faces.size(), low, high], 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	flow.custom_minimum_size.x = 224
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(flow)
	var tone: Color = DiceIcons.die_palette(die).body
	for f in faces:
		flow.add_child(DiceIcons.face(14, int(f.value), tone if str(f.kind) == "plain" else DiceIcons.face_kind_tint(str(f.kind)), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))

func _die_changes(original: Dictionary, offered: Dictionary) -> Array:
	## What an offered die does differently from the one it would replace, a line a change:
	## [glyph, words, tooltip].
	var out: Array = []
	var was_shape: String = str(original.get("shape", "D6"))
	var now_shape: String = str(offered.get("shape", "D6"))
	if was_shape != now_shape:
		var bigger: bool = DeepOddities.SIZES.find(now_shape) > DeepOddities.SIZES.find(was_shape)
		out.append(["rise" if bigger else "fall", "%s instead of a %s" % [now_shape.to_lower(), was_shape.to_lower()],
			"%d faces instead of %d." % [offered.get("faces", []).size(), original.get("faces", []).size()]])
	var pattern: String = str(offered.get("pattern", ""))
	if pattern != str(original.get("pattern", "")) and not pattern.is_empty():
		out.append(["die", "Pattern: %s" % DeepDice.pattern_name(pattern), str(DeepContent.pattern(pattern).get("text", ""))])
	var material: String = str(offered.get("material", ""))
	if material != str(original.get("material", "")) and not material.is_empty():
		out.append(["drop", "Material: %s" % DeepDice.material_name(material), str(DeepContent.material(material).get("text", ""))])
	var had: Array = DeepDice.etchings(original).map(func(e: Dictionary) -> String: return "%d:%s" % [int(e.face), str(e.kind)])
	var has: Array = DeepDice.etchings(offered).map(func(e: Dictionary) -> String: return "%d:%s" % [int(e.face), str(e.kind)])
	for entry in DeepDice.etchings(offered):
		if had.has("%d:%s" % [int(entry.face), str(entry.kind)]):
			continue
		var kind: String = str(entry.kind)
		out.append(["spark", "%s on the %d" % [DeepDice.etching_name(kind), int(offered.faces[int(entry.face)].get("value", 0))], str(DeepContent.etching(kind).get("text", ""))])
	for entry in DeepDice.etchings(original):
		if not has.has("%d:%s" % [int(entry.face), str(entry.kind)]):
			out.append(["cross_out", "Loses its %s face" % DeepDice.etching_name(str(entry.kind)), "The smaller die has no face for it to sit on."])
	return out

func _page_stake_pick(content: VBoxContainer, offer: Dictionary) -> void:
	## A pick stake, taken: its three candidates at full size, and one of them to keep. A deep
	## start's cards that are chosen on a page of their own go to theirs.
	if offer.get("needs", []).has("charges"):
		_page_charges(content, offer)
		return
	match str(offer.get("pick_kind", "stone")):
		"stones":
			_page_gem_bag(content, offer)
			return
		"dice":
			_page_dice_bag(content, offer)
			return
		"material":
			_page_material_pick(content, offer)
			return
	var tone: Color = _stake_tone(str(offer.get("kind", "stone")))
	var named: Dictionary = {}
	var costs: Array = []
	for key in offer.get("boons", []):
		var def: Dictionary = DeepContent.boon(str(key))
		if str(def.get("needs", "")) == "pick":
			named = def
		elif str(def.get("group", "")) == "cost":
			costs.append(def)
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("gem", tone)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, str(named.get("name", "Your pick")), 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var picks: Array = offer.get("picks", [])
	var all_read: bool = not picks.is_empty() and picks.all(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)))
	DeepUi.wrap(head, "Three stones, appraised. One goes into your haul." if all_read else "Three raw stones in three colors. The one you pick is appraised right away and can go on your rail before you head down.", 16, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for def in costs:
		var price := DeepUi.stat(head, "cross_out", "%s: %s" % [str(def.get("name", "")), str(def.get("text", ""))], DeepUi.BAD.lightened(0.2), 14)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
	_enter(head)
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var offer_id: String = str(offer.get("id", ""))
	for index in range(picks.size()):
		var candidate: Dictionary = picks[index]
		var card: PanelContainer = StoneCard.build(row, candidate, {"size": 156, "vertical": true, "text_width": 268, "lamp": true})
		card.custom_minimum_size.x = 300
		var chosen: int = index
		var take := func() -> void: command.emit({"kind": "stake", "offer": offer_id, "payload": {"pick": chosen}})
		DeepUi.make_choice(card, tone, take)
		_numbered_card(card, take)
		_close_look_on_right(card, func() -> void: Inspector.stone(candidate))
		_enter(card, 0.15 + 0.12 * index)

# --- a deep start's cards, chosen (docs/DEEP_START.md §3) -----------------------------------------

## How many of a Bag of Gems' stones stand on one page before the rest are turned to, and on
## one row of it.
const GEM_BAG_PAGE: int = 8
const GEM_BAG_ROW: int = 4
## A Bag of Dice's dice, and the player's, as they are drawn on its page.
const BAG_DIE: float = 56.0

func _bag_for(offer: Dictionary) -> void:
	## A choice half made belongs to the card it was made on: another card, a new run, starts clean.
	var key: String = "%s|%s" % [str(run.get("run_id", "")), str(offer.get("id", ""))]
	if key == _bag_key:
		return
	_bag_key = key
	_bag_chosen = []
	_bag_hand = []
	_bag_pool = []
	_bag_sel = {}
	_charge_clicks = []

func _offer_words(offer: Dictionary) -> Array:
	## A deep card's [name, words], as the card was offered: filled with its own numbers.
	var key: String = str(offer.get("boons", [""])[0])
	var def: Dictionary = DeepContent.boon(key)
	var names: Array = offer.get("names", [])
	var texts: Array = offer.get("texts", [])
	return [str(names[0]) if not names.is_empty() else str(def.get("name", key)), str(texts[0]) if not texts.is_empty() else str(def.get("text", ""))]

func _stake_back(parent: Node) -> Button:
	## Back to the three cards: nothing is taken until the choice on this page is made.
	var back := DeepUi.icon_button(parent, "prev", "Back to the cards", func() -> void:
		_stake_choosing = ""
		show_state(run), 14, DeepUi.MUTED)
	DeepUi.ledger_button(back, DeepUi.SLATE_LOW, DeepUi.LEDGER_LINE, 9, DeepUi.MUTED)
	back.custom_minimum_size.y = 40
	back.name = "StakeBack"
	return back

static func gem_bag_take(offer: Dictionary) -> int:
	## How many of a Bag of Gems' stones are taken: exactly this many.
	return clampi(int(offer.get("take", 1)), 1, maxi(1, offer.get("picks", []).size()))

func _page_gem_bag(content: VBoxContainer, offer: Dictionary) -> void:
	## Bag of Gems: read stones from the mines skipped, as stone cards. A click picks one or puts
	## it back; exactly `take` of them are taken together.
	_bag_for(offer)
	var picks: Array = offer.get("picks", [])
	var take: int = gem_bag_take(offer)
	var words: Array = _offer_words(offer)
	var paged: bool = picks.size() > GEM_BAG_PAGE
	_shaft_head(content, "gem", DEEP_TONE, str(words[0]), str(words[1]), not paged)
	var body := DeepUi.vbox(content, 10)
	## Four to a row, each row centred: a short last row sits in the middle under the first.
	var rows := DeepUi.vbox(body, 14)
	rows.name = "GemBag"
	var row: HBoxContainer = null
	## A big bag is turned a page at a time, its pager at the head of the row of buttons under
	## the stones; what is chosen stays chosen across its pages.
	var foot := DeepUi.hbox(body, 14)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var shown: Array = _paged(foot, "deep_gems", range(picks.size()), GEM_BAG_PAGE)
	var full: bool = _bag_chosen.size() >= take
	var index: int = 0
	for at in shown:
		var which: int = int(at)
		var chosen: bool = _bag_chosen.has(which)
		var toggle := func() -> void: _gem_bag_toggle(offer, which)
		if index % GEM_BAG_ROW == 0:
			row = DeepUi.hbox(rows, 14)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
		var card := _numbered_card(_stone_option(row, picks[which], toggle, chosen), toggle)
		card.set_meta("pick", which)
		if full and not chosen:
			## Full: the rest step back until one is put back.
			card.modulate.a = 0.6
		_enter(card, 0.08 + 0.05 * index)
		index += 1
	_stake_back(foot)
	var count := DeepUi.stat(foot, "check", "%d of %d chosen" % [_bag_chosen.size(), take], DeepUi.GOOD if full else DeepUi.MUTED, 15)
	count.name = "BagCount"
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var go := _main(DeepUi.primary(foot, "bag", "Take these %d" % take if take > 1 else "Take it", func() -> void: _take_gem_bag(offer), 16, DEEP_TONE))
	DeepUi.ledger_primary(go, DEEP_TONE)
	go.custom_minimum_size = Vector2(220, 40)
	go.disabled = _bag_chosen.size() != take
	go.tooltip_text = "" if not go.disabled else "Choose %d of them first." % take
	go.name = "BagTake"
	DeepUi.stat(body, "eye", DeepUi.touch_words("Right-click a stone for the close look."), DeepUi.DIM, 12).alignment = BoxContainer.ALIGNMENT_CENTER

func _gem_bag_toggle(offer: Dictionary, index: int) -> void:
	## One of the bag's stones picked, or put back. With the bag's share already picked, another
	## is refused until one is put back.
	_bag_for(offer)
	if _bag_chosen.has(index):
		_bag_chosen.erase(index)
	elif _bag_chosen.size() < gem_bag_take(offer):
		_bag_chosen.append(index)
	else:
		DeepAudio.play("ui_back", {"volume": 0.6})
		toast("You have chosen %d. Put one back to choose another." % gem_bag_take(offer), DeepUi.MUTED, "gem", 2.2)
		return
	show_state(run)

func _take_gem_bag(offer: Dictionary) -> void:
	_bag_for(offer)
	if _bag_chosen.size() != gem_bag_take(offer):
		return
	var chosen: Array = _bag_chosen.duplicate()
	chosen.sort()
	command.emit({"kind": "stake", "offer": str(offer.get("id", "")), "payload": {"picks": chosen}})

func _page_dice_bag(content: VBoxContainer, offer: Dictionary) -> void:
	## Bag of Dice (Nov 5 round 5): your dice in one row and the bag's in the other. A die
	## clicked, then one in the other row, trade places, and so does one dragged onto the other;
	## a die put in the bag sits where the bag's die was and can come back out. Nothing is
	## taken until the button, which sends the hand as it stands.
	_bag_for(offer)
	var unit: Dictionary = me()
	if _bag_hand.is_empty():
		_bag_hand = unit.get("dice", []).duplicate(true)
		_bag_pool = offer.get("picks", []).duplicate(true)
	var words: Array = _offer_words(offer)
	## Without the mark over the name: your dice stand as large as the dock's, and the page
	## needs the room to keep clear of the dock.
	_shaft_head(content, "die", DEEP_TONE, str(words[0]), str(words[1]), false)
	var body := DeepUi.vbox(content, 8)
	DeepUi.label(body, "Click a die, then one in the other row, and they trade places. Or drag one onto the other.", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	## The bag on top, as it was; your dice under it, drawn as the dock draws them at the foot of
	## the screen (the owner, November 6, 2026): the same dice, spacing and plate. No headings:
	## the plate says whose dice they are (round 7).
	var bag_row := DeepUi.hbox(body, 10)
	bag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bag_row.name = "BagDice"
	for index in range(_bag_pool.size()):
		_bag_slot(bag_row, "bag", index, _bag_pool[index])
	## The line of words under the dice only when one of them has any: an empty line stood the
	## dice high on their plate.
	var worded: bool = _bag_hand.any(func(d: Dictionary) -> bool: return not _die_word(d).is_empty())
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.LEDGER_LINE, 14, 12, 3, 5))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.name = "HandPlate"
	## Air between the bag's tiles and the plate, so the pill on its border has room over it
	## (round 10): the plate itself keeps its size.
	DeepUi.gap(body, BAG_PLATE_GAP).name = "BagPlateGap"
	body.add_child(plate)
	var tray := DeepUi.hbox(plate, 8)
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.name = "OwnDice"
	for index in range(_bag_hand.size()):
		_hand_die(tray, index, _bag_hand[index], worded)
	## "Your dice" in a pill on the plate's top border (round 10), laid over it rather than set
	## in it: the plate keeps its own size and the dice their places.
	_border_pill(plate, func(holder: Control) -> Control:
		var pill := DeepUi.pill(holder, "die", "Your dice", DeepUi.MUTED, 12)
		pill.name = "HandLabel"
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## The plate's own fill, and its border's colour and width, so the pill reads as part of it.
		var plate_style: StyleBox = plate.get_theme_stylebox("panel")
		var style: StyleBox = pill.get_theme_stylebox("panel")
		if style is StyleBoxFlat and plate_style is StyleBoxFlat:
			(style as StyleBoxFlat).bg_color = (plate_style as StyleBoxFlat).bg_color
			(style as StyleBoxFlat).border_color = (plate_style as StyleBoxFlat).border_color
			(style as StyleBoxFlat).set_border_width_all((plate_style as StyleBoxFlat).border_width_top)
		return pill)
	var foot := DeepUi.hbox(body, 14)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_stake_back(foot)
	var changed: bool = bag_hand_ids() != unit.get("dice", []).map(func(d: Dictionary) -> String: return str(d.get("id", "")))
	var go := _main(DeepUi.primary(foot, "die" if changed else "check", "Take these dice" if changed else "Keep my dice", func() -> void: _take_dice_bag(offer), 16, DEEP_TONE))
	DeepUi.ledger_primary(go, DEEP_TONE)
	go.custom_minimum_size = Vector2(220, 40)
	go.name = "BagTake"

func _bag_slot(row: Node, which_row: String, index: int, die: Dictionary) -> void:
	## One die on the Bag of Dice's page, in your row or the bag's: lit while it is the one held.
	var held: bool = str(_bag_sel.get("row", "")) == which_row and int(_bag_sel.get("index", -1)) == index
	var tile := _bag_tile(row, held)
	tile.name = "%s%d" % ["Hand" if which_row == "hand" else "Bag", index]
	var column := DeepUi.vbox(tile, 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_die_picture(column, die, BAG_DIE)
	DeepUi.fit_label(column, DeepDice.describe(die), 12, DiceIcons.die_palette(die).body.lightened(0.3), 128).mouse_filter = Control.MOUSE_FILTER_IGNORE
	DeepUi.fit_label(column, _die_traits(die), 11, DeepUi.MUTED, 128).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_wire(tile, which_row, index, die)
	_enter(tile, 0.04 * index)

## Your dice on the Bag of Dice's page stand as large as the dock's (run_dock.gd `DIE`).
const HAND_DIE: float = BattleScreen.DIE_EDGE

static func _die_word(die: Dictionary) -> String:
	## What the dock writes under a die: its material, or else its pattern, or nothing.
	var under: String = DeepDice.material_name(str(die.get("material", "")))
	if under.is_empty():
		under = DeepDice.pattern_name(str(die.get("pattern", "")))
	return under

func _hand_die(tray: Node, index: int, die: Dictionary, worded: bool = true) -> void:
	## One of your dice under the bag, drawn as the dock draws it (run_dock.gd `_die_slot`): the
	## die, and what it is made of or cut to under it in small letters (a line kept for every
	## die once any has words, so they stand level; none at all when none has). A ring round
	## it, the same size lit or not, says it is the one held.
	var held: bool = str(_bag_sel.get("row", "")) == "hand" and int(_bag_sel.get("index", -1)) == index
	var frame := PanelContainer.new()
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(DEEP_TONE, 0.14) if held else Color(0, 0, 0, 0)
	ring.border_color = DEEP_TONE if held else Color(0, 0, 0, 0)
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(10)
	ring.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", ring)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.name = "Hand%d" % index
	tray.add_child(frame)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(card)
	var thumb := Thumbs.DieThumb.new(die, HAND_DIE)
	thumb.tooltip_text = ""
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(thumb)
	if worded:
		var words := DeepUi.label(card, _die_word(die).to_lower(), 10, DeepUi.ACCENT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		words.custom_minimum_size = Vector2(HAND_DIE, BattleScreen.DIE_WORDS - 1.0)
		words.clip_text = true
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_wire(frame, "hand", index, die)
	_enter(frame, 0.04 * index)

func _bag_wire(control: Control, which_row: String, index: int, die: Dictionary) -> void:
	## A die on the Bag of Dice's page, either row: a click holds it (or trades it with the one
	## held in the other row), a drag onto one in the other row trades them, a right-click is
	## the close look, and its plate is the die's.
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_bag_click(which_row, index)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				Inspector.die(die)
			control.accept_event())
	control.set_drag_forwarding(func(_at: Vector2) -> Variant:
		var preview := Thumbs.DieThumb.new(die, BAG_DIE)
		preview.modulate.a = 0.85
		control.set_drag_preview(preview)
		return {"kind": "bag_trade", "row": which_row, "index": index},
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and str(data.get("kind", "")) == "bag_trade" and str(data.get("row", "")) != which_row,
		func(_at: Vector2, data: Variant) -> void:
			_bag_trade(str(data.get("row", "")), int(data.get("index", -1)), which_row, index))
	Tips.attach(control, func() -> Control:
		var plate: Control = Plates.die(die)
		Plates.footer(plate)
		return plate, {"tone": DiceIcons.die_palette(die).body})

func _bag_tile(row: Node, lit: bool) -> PanelContainer:
	## One die on the Bag of Dice's page: lit while held, or while a swap stands on it.
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", DeepUi.raised(Color(DEEP_TONE, 0.18) if lit else Color(DeepUi.SLATE, 0.85), Color(DEEP_TONE, 0.95) if lit else Color(DeepUi.LINE, 0.8), 10, 8, 0.3))
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.custom_minimum_size = Vector2(144, 0)
	row.add_child(tile)
	return tile

func _bag_die_picture(parent: Node, die: Dictionary, edge: float) -> Control:
	var thumb := Thumbs.DieThumb.new(die, edge)
	thumb.tooltip_text = ""
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(thumb)
	return thumb

func _die_traits(die: Dictionary) -> String:
	## What a die has beyond its numbers, in a few words: its pattern, material and etchings.
	var said: Array = []
	if not str(die.get("pattern", "")).is_empty():
		said.append(DeepDice.pattern_name(str(die.pattern)))
	if not str(die.get("material", "")).is_empty():
		said.append(DeepDice.material_name(str(die.material)))
	var etched: int = DeepDice.etchings(die).size()
	if etched > 0:
		said.append("%d etched" % etched)
	return " · ".join(said) if not said.is_empty() else "plain"

func _bag_click(which_row: String, index: int) -> void:
	## A die clicked: held; the held one clicked again, let go; one in the other row, the two
	## trade places.
	var held_row: String = str(_bag_sel.get("row", ""))
	var held_at: int = int(_bag_sel.get("index", -1))
	if held_row.is_empty() or held_row == which_row:
		_bag_sel = {} if held_row == which_row and held_at == index else {"row": which_row, "index": index}
		DeepAudio.play("ui_tap", {"volume": 0.6})
		show_state(run)
		return
	_bag_trade(held_row, held_at, which_row, index)

func _bag_trade(row_a: String, at_a: int, row_b: String, at_b: int) -> void:
	## A die of yours and one of the bag's change places.
	if row_a == row_b or at_a < 0 or at_b < 0:
		return
	var hand_at: int = at_a if row_a == "hand" else at_b
	var bag_at: int = at_b if row_a == "hand" else at_a
	if hand_at >= _bag_hand.size() or bag_at >= _bag_pool.size():
		return
	var mine: Dictionary = _bag_hand[hand_at]
	_bag_hand[hand_at] = _bag_pool[bag_at]
	_bag_pool[bag_at] = mine
	_bag_sel = {}
	DeepAudio.play("dice_lock", {"volume": 0.7})
	show_state(run)

func bag_hand_ids() -> Array:
	## The hand as it stands on the Bag of Dice's page, by die id in slot order.
	return _bag_hand.map(func(d: Dictionary) -> String: return str(d.get("id", "")))

func _take_dice_bag(offer: Dictionary) -> void:
	_bag_for(offer)
	if _bag_hand.is_empty():
		_bag_hand = me().get("dice", []).duplicate(true)
	command.emit({"kind": "stake", "offer": str(offer.get("id", "")), "payload": {"hand": bag_hand_ids()}})

# --- charges: Hammered and A Wild Face (Nov 5 round 5) ------------------------------------------

static func can_charge(die: Dictionary, kind: String) -> bool:
	## Whether this die can take one more charge: a size bigger, or a face turned wild.
	return DeepBoons.can_charge(die, kind)

static func charge_preview(unit: Dictionary, kind: String, dice_ids: Array) -> Array:
	## The player's dice after these charges, in click order (the same die may come up again).
	return DeepBoons.charge_preview(unit, kind, dice_ids)

func _page_charges(content: VBoxContainer, offer: Dictionary) -> void:
	## Hammered or A Wild Face, taken: every die the player carries, and a counter of charges.
	## A click on a die that can take one spends it at once: the die is struck (or a face of it
	## glints wild) and stands there as it now is, and can be clicked again. Start over undoes
	## every charge; Done sends the dice clicked once every charge is spent or no die can take
	## another.
	_bag_for(offer)
	var unit: Dictionary = me()
	var charges: Dictionary = offer.get("charges", {})
	var kind: String = str(charges.get("kind", "resize"))
	var count: int = maxi(1, int(charges.get("count", 1)))
	var words: Array = _charge_words(offer)
	var tone: Color = DEEP_TONE if bool(offer.get("deep", false)) or bool(offer.get("upgraded", false)) else _stake_tone(str(offer.get("kind", "kit")))
	_shaft_head(content, "anvil" if kind == "resize" else "star", tone, str(words[0]), str(words[1]))
	var dice: Array = charge_preview(unit, kind, _charge_clicks)
	var left: int = count - _charge_clicks.size()
	var takers: bool = dice.any(func(d: Dictionary) -> bool: return can_charge(d, kind))
	var body := DeepUi.vbox(content, 10)
	var counter := DeepUi.hbox(body, 8)
	counter.alignment = BoxContainer.ALIGNMENT_CENTER
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", DeepUi.capsule(chip, Color(0.055, 0.05, 0.04, 0.96), tone, 2, 14, 4))
	chip.name = "ChargeCount"
	counter.add_child(chip)
	var said := DeepUi.hbox(chip, 8)
	_charge_icon(said, kind, 24, tone)
	var figure := DeepUi.title(said, "%d" % left, 22, tone.lightened(0.2) if left > 0 else DeepUi.DIM)
	figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	figure.name = "ChargesLeft"
	DeepUi.label(said, ("%s left" % ("charge" if left == 1 else "charges")) if left > 0 else "all spent", 13, DeepUi.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.label(body, ("Click a die to hammer it a size bigger. The same die can take another." if kind == "resize"
		else "Click a die and its lowest face not yet wild turns wild. The same die can take another."), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var row := DeepUi.hbox(body, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.name = "ChargeDice"
	for index in range(dice.size()):
		var die: Dictionary = dice[index]
		var die_id: String = str(die.get("id", ""))
		var able: bool = left > 0 and can_charge(die, kind)
		var hits: int = _charge_clicks.count(die_id)
		var tile := _bag_tile(row, hits > 0)
		tile.name = "Charge_%s" % die_id
		tile.set_meta("able", able)
		var column := DeepUi.vbox(tile, 3)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bag_die_picture(column, die, 64.0)
		DeepUi.fit_label(column, DeepDice.describe(die), 12, DiceIcons.die_palette(die).body.lightened(0.3), 128).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var note: String = _die_traits(die)
		if hits > 0:
			note = ("struck once" if hits == 1 else "struck %d times" % hits) if kind == "resize" else ("1 face wild" if hits == 1 else "%d faces wild" % hits)
		elif not can_charge(die, kind):
			note = "as big as dice go" if kind == "resize" else "no face left to turn"
		DeepUi.fit_label(column, note, 11, tone if hits > 0 else DeepUi.MUTED, 128).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not able:
			tile.modulate.a = 0.45
			tile.mouse_default_cursor_shape = Control.CURSOR_ARROW
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_charge_hit(offer, die_id)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					Inspector.die(die)
				tile.accept_event())
		Tips.attach(tile, func() -> Control:
			var plate: Control = Plates.die(die)
			Plates.footer(plate)
			return plate, {"tone": DiceIcons.die_palette(die).body})
		_enter(tile, 0.04 * index)
	var foot := DeepUi.hbox(body, 14)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_stake_back(foot)
	var again := DeepUi.icon_button(foot, "reroll", "Start over", func() -> void:
		_charge_clicks = []
		DeepAudio.play("ui_back", {"volume": 0.6})
		show_state(run), 14, DeepUi.MUTED)
	DeepUi.ledger_button(again, DeepUi.SLATE_LOW, DeepUi.LEDGER_LINE, 9, DeepUi.MUTED)
	again.custom_minimum_size.y = 40
	again.disabled = _charge_clicks.is_empty()
	again.name = "ChargeAgain"
	var done := _main(DeepUi.primary(foot, "check", "Done", func() -> void: _take_charges(offer), 16, tone))
	DeepUi.ledger_primary(done, tone)
	done.custom_minimum_size = Vector2(200, 40)
	done.disabled = not (left <= 0 or not takers)
	done.tooltip_text = "" if not done.disabled else "Spend every charge first: %d left." % left
	done.name = "ChargeDone"

func _charge_words(offer: Dictionary) -> Array:
	## [name, words] of the boon that gives the charges (the reward, on a pair of terms).
	var names: Array = offer.get("names", [])
	var texts: Array = offer.get("texts", [])
	var boons: Array = offer.get("boons", [])
	for at in range(boons.size()):
		var def: Dictionary = DeepContent.boon(str(boons[at]))
		if str(def.get("group", "")) == "cost":
			continue
		return [str(names[at]) if at < names.size() else str(def.get("name", boons[at])), str(texts[at]) if at < texts.size() else str(def.get("text", ""))]
	return _offer_words(offer)

func _charge_icon(parent: Node, kind: String, edge: float, tone: Color) -> Control:
	## The counter's mark: the hammer (the interface's hammer, as the workshop's buttons use it)
	## for Hammered; for A Wild Face, a die's face with the wild star on it.
	if kind == "wild":
		var face: Control = DiceIcons.face(edge, 6, DiceIcons.face_kind_tint("wild"), "D6", true, DiceIcons.face_text(6, "wild"))
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.name = "ChargeIcon"
		parent.add_child(face)
		return face
	var mark := DeepUi.icon(parent, "hammer", edge, tone)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.name = "ChargeIcon"
	return mark

func _charge_hit(offer: Dictionary, die_id: String) -> void:
	## One charge spent on this die, at once: struck (or glinting), and drawn as it now is.
	_bag_for(offer)
	var charges: Dictionary = offer.get("charges", {})
	var kind: String = str(charges.get("kind", "resize"))
	if _charge_clicks.size() >= maxi(1, int(charges.get("count", 1))):
		return
	var now: Array = charge_preview(me(), kind, _charge_clicks)
	var die: Dictionary = {}
	for candidate in now:
		if str(candidate.get("id", "")) == die_id:
			die = candidate
	if die.is_empty() or not can_charge(die, kind):
		DeepAudio.play("ui_back", {"volume": 0.5})
		return
	_charge_clicks.append(die_id)
	show_state(run)
	## Once the page has been laid out again, over the die as it now stands.
	if _headless or not is_inside_tree():
		if kind == "resize":
			DieFx.strike(self, Vector2.ZERO)
		else:
			DieFx.glint(self, Vector2.ZERO)
		return
	get_tree().process_frame.connect(func() -> void: _charge_fx(die_id, kind), CONNECT_ONE_SHOT)

func _charge_fx(die_id: String, kind: String) -> void:
	var tile: Node = _page_holder.find_child("Charge_%s" % die_id, true, false) if is_instance_valid(_page_holder) else null
	if not tile is Control:
		return
	var at: Vector2 = (tile as Control).global_position + (tile as Control).size * Vector2(0.5, 0.36) - global_position
	if kind == "resize":
		DieFx.strike(self, at)
		DeepUi.shake(tile as Control, 5.0, 0.2)
	else:
		DieFx.glint(self, at)
	DeepUi.pulse(tile as Control, 1.1, 0.25)

func _take_charges(offer: Dictionary) -> void:
	_bag_for(offer)
	command.emit({"kind": "stake", "offer": str(offer.get("id", "")), "payload": {"dice": _charge_clicks.duplicate()}})

func _page_material_pick(content: VBoxContainer, offer: Dictionary) -> void:
	## One Material: three, each shown on one of the player's own dice, with its name and what
	## it does. A click takes it for every die carried.
	var unit: Dictionary = me()
	var picks: Array = offer.get("picks", [])
	var words: Array = _offer_words(offer)
	_shaft_head(content, "drop", DEEP_TONE, str(words[0]), str(words[1]))
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.name = "Materials"
	var dice: Array = unit.get("dice", [])
	var offer_id: String = str(offer.get("id", ""))
	for index in range(picks.size()):
		var material: String = str(picks[index])
		var tone: Color = DiceIcons.material_palette(material).get("body", DEEP_TONE)
		var chosen: int = index
		var take := func() -> void: command.emit({"kind": "stake", "offer": offer_id, "payload": {"pick": chosen}})
		var card := _numbered_card(DeepUi.choice_card(row, tone, take), take)
		card.custom_minimum_size = Vector2(300, 0)
		card.set_meta("material", material)
		var box := DeepUi.vbox(card, 8)
		if not dice.is_empty():
			var worn: Dictionary = dice[0].duplicate(true)
			worn.material = material
			var thumb := Thumbs.DieThumb.new(worn, 84)
			thumb.tooltip_text = ""
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(thumb)
		DeepUi.title(box, DeepDice.material_name(material), 20, tone.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.wrap(box, str(DeepContent.material(material).get("text", "")), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 260)
		DeepUi.label(box, "On all %s you carry" % DeepUi.plural(dice.size(), "die", "dice"), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_enter(card, 0.1 + 0.08 * index)
	var foot := DeepUi.hbox(content, 14)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_stake_back(foot)

func _stake_result(content: VBoxContainer, result: Dictionary) -> PanelContainer:
	## What a taken stake did: its words, and every stone or die it made or changed.
	var result_card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.5), 18)
	result_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(result_card, 10)
	var names: Array = result.get("boons", []).map(func(k: Variant) -> String: return str(DeepContent.boon(str(k)).get("name", k)))
	DeepUi.section(box, "check", " and ".join(names) if not names.is_empty() else "Staked", DeepUi.ACCENT)
	DeepUi.wrap(box, str(result.get("message", "You have taken your stake.")), 16, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 700)
	## One stone across the card; two abreast; three or more as a row of small tiles (the
	## close look is a right-click away), so the page stays whole and the button in view.
	var stones: Array = result.get("changed", []) + result.get("made", [])
	var compact: bool = stones.size() > 2
	var grid := GridContainer.new()
	grid.columns = 1 if stones.size() <= 1 else (2 if not compact else 6)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for stone in stones:
		if compact:
			StoneCard.tile(grid, stone, 64)
		else:
			StoneCard.build(grid, stone, {"size": 72 if stones.size() <= 1 else 60, "text_width": 520 if stones.size() <= 1 else 300})
	if not result.get("dice", []).is_empty():
		var dice_row := DeepUi.hbox(box, 8)
		for die in result.dice:
			dice_row.add_child(Thumbs.DieThumb.new(die, 48))
			DeepUi.label(dice_row, DeepDice.describe(die), 14, DeepUi.PAPER)
	## A read stone it made, still in the bag: the socket it can go in now, the button the
	## loupe offers at the end of an appraisal (see appraisal_actions).
	var bag: Array = me().get("haul", [])
	var setters := DeepUi.hbox(box, 10)
	for made in result.get("made", []):
		var id: String = str(made.get("id", ""))
		if not bool(made.get("appraised", false)) or not bag.any(func(s: Variant) -> bool: return s is Dictionary and str(s.get("id", "")) == id):
			continue
		for action in appraisal_actions(made):
			if str(action.get("glyph", "")) == "gem" and action.has("call"):
				var setter := DeepUi.icon_button(setters, "gem", str(action["label"]), action["call"], 15, action["tone"])
				setter.tooltip_text = str(action.get("caption", ""))
	setters.visible = setters.get_child_count() > 0
	return result_card

func _page_stake_result(content: VBoxContainer) -> void:
	## Held once the last stake is in, when this one did something by chance or made a stone:
	## the stone the rail gave up to it, or the one just read. The tunnels wait behind it.
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("bag", DeepUi.ACCENT, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.title(head, "The Grubstake", 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(head)
	_enter(_stake_result(content, _hold.get("result", {})), 0.1)
	var go := _main(DeepUi.primary(content, "descend", "Onward", _release, 18, DeepUi.ACCENT))
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 240
	_enter(go, 0.3)

# --- oddity ----------------------------------------------------------------------------------

func _page_oddity(content: VBoxContainer, headed: bool = true) -> void:
	if _fresh:
		DeepAudio.play("oddity", {"volume": 0.8})
	var unit: Dictionary = me()
	var key: String = str(run.chamber.get("oddity", ""))
	var oddity: Dictionary = DeepContent.oddity(key)
	var tone: Color = _oddity_tone(str(run.chamber.get("kind", "oddity")))
	if headed:
		var head := DeepUi.vbox(content, 8)
		var medal := Medallion.new(str(ODDITY_GLYPHS.get(key, "question")), tone)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		head.add_child(medal)
		DeepUi.title(head, str(oddity.get("name", "Something odd")), 34, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.wrap(head, str(oddity.get("text", "")), 16, DeepUi.PAPER.darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER, 760).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_enter(head)
	var chosen: String = str(unit.get("oddity_choice", ""))
	if not chosen.is_empty():
		## What came of the choice had its own page the moment it was made, and who the room
		## is still waiting on is on their tabs: there is nothing more to say here.
		return
	if bool(unit.get("downed", false)):
		## The fallen are carried past it: nothing here is theirs to choose.
		var down_card := DeepUi.card(content, Color(DeepUi.BAD, 0.5), 16)
		down_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.stat(down_card, "skull", "You are down. The party deals with this without you, and you get back on your feet at the next landing.", DeepUi.BAD.lightened(0.2), 14)
		_enter(down_card, 0.1)
		return
	## This player's choices: the card's own, or a voucher holder's improved ones (the rules
	## look a choice up the same way, DeepDescent.room_choices).
	var choices: Array = DeepDescent.room_choices(run, local_id)
	if choices.is_empty():
		choices = oddity.get("choices", [])
	## An upgraded bench (a voucher spent on it, or a lucky room) opens on its plain work, and
	## after a beat a sparkle sweeps the cards and the better work takes their place: once a
	## visit, for whoever's bench it is. Headless, and once a piece of work is picked, at once.
	var reveal_key: String = _bench_key()
	var waiting_reveal: bool = false
	if choices.any(func(c: Dictionary) -> bool: return is_improved(c)) and not _headless and _oddity_step.is_empty() \
			and str(_bench_revealed.get(reveal_key, "")) != "done":
		waiting_reveal = true
		choices = oddity.get("choices", []).map(func(c: Dictionary) -> Dictionary:
			var plain: Dictionary = c.duplicate(true)
			plain.erase("improved")
			return plain)
		if not _bench_revealed.has(reveal_key):
			_bench_revealed[reveal_key] = "pending"
			_later(BENCH_BEAT, _reveal_bench.bind(reveal_key))
	## Walking on is not a third piece of work: it is a way out, and it is laid out apart
	## from the others rather than standing beside them as an empty column.
	var leaving: Dictionary = {}
	var work: Array = []
	for choice in choices:
		if str(choice.get("needs", "")).is_empty() and str(choice.get("action", {}).get("kind", "none")) == "none" and choices.size() > 1:
			leaving = choice
		else:
			work.append(choice)
	## A choice already picked out: the second page, where the thing to work on is chosen.
	var step: Dictionary = {}
	for choice in work:
		if str(choice.id) == _oddity_step:
			step = choice
	if not step.is_empty():
		_page_oddity_work(content, step, unit, tone, key)
		return
	## Some work is not done in one go. The Idol keeps count of its pulls, and its card is
	## reworded for each ("Pull harder") with what the next one costs, because a price that
	## ramps has to be readable (and on a phone there is no pointing at the card to see it on
	## the ring).
	var pulled: int = int(run.chamber.get("tries", {}).get(local_id, {}).get("done", 0))
	var row := DeepUi.hbox(content, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.name = "BenchRow"
	var index: int = 0
	for choice in work:
		var needs: String = str(choice.get("needs", ""))
		var id: String = str(choice.id)
		## An upgraded bench's better work: gold-rimmed, a glint across it now and then, and an
		## "Upgraded" pill on its corner. Work done to every die asks first, as any work that
		## wants a pick does.
		var improved: bool = is_improved(choice)
		var press := func() -> void:
			if needs.is_empty() and not improved:
				command.emit({"kind": "oddity", "choice": id, "payload": {}})
				return
			_oddity_step = id
			show_state(run)
		var card: PanelContainer
		if improved:
			card = PanelContainer.new()
			var rim: StyleBoxFlat = DeepUi.raised(Color(DeepUi.GLASS.lerp(DEEP_TONE, 0.1), DeepUi.GLASS.a), DEEP_TONE, 12, 16)
			rim.set_border_width_all(2)
			card.add_theme_stylebox_override("panel", rim)
			row.add_child(card)
			DeepUi.make_choice(card, DEEP_TONE, press)
			card.set_meta("improved", true)
		else:
			card = DeepUi.choice_card(row, tone, press)
		## A Geode's card on the phone is a wide one, its rock beside its words: stacked in the
		## narrow card it stood taller than the room (November 9, 2026).
		var wide_geode: bool = DeepUi.phone and str(choice.get("action", {}).get("kind", "")) == "geode_buy"
		card.custom_minimum_size = Vector2(DeepUi.pt(300) if wide_geode else (DeepUi.pt(172) if DeepUi.phone else 300.0), 0)
		if waiting_reveal:
			## The plain work, waiting to be replaced: shown as it is, but not taken meanwhile.
			card.set_meta("disabled", true)
		## A card that costs health (a pry, an idol's pull) shows its price on the ring while pointed at.
		var hp_action: Dictionary = choice.get("action", {})
		if str(hp_action.get("kind", "")) in ["pry", "idol"]:
			var hp_price: int = DeepOddities.idol_price(hp_action, pulled) if str(hp_action.get("kind", "")) == "idol" else int(hp_action.get("hp", 0))
			card.mouse_entered.connect(func() -> void: _aim_hp(hp_price))
			card.mouse_exited.connect(func() -> void: _aim_hp(0))
			card.tree_exiting.connect(func() -> void: _aim_hp(0))
		var box := DeepUi.vbox(card, 10)
		var title_row := DeepUi.hbox(box, 8)
		DeepUi.icon(title_row, choice_glyph(choice, key), 20, DEEP_TONE if improved else tone)
		_marked_title(title_row, str(DeepOddities.at_pull(choice, pulled).get("label", choice.id)), 19, DeepUi.PAPER)
		if choice.has("text"):
			_marked_text(box, DeepOddities.choice_text(choice, int(run.get("depth", 0)), pulled), 12 if DeepUi.phone else 13, DeepUi.MUTED, DeepUi.pt(276) if wide_geode else (DeepUi.pt(150) if DeepUi.phone else 260.0))
		## What the room is set up for tonight, read before the card is picked rather than after.
		_tonight_chip(box, choice.get("action", {}))
		if improved:
			var shine := Shimmer.new(DEEP_TONE)
			shine.name = "VoucherShine"
			card.add_child(shine)
			_upgraded_pill(card)
			var refused: String = _every_die_refused(choice, unit)
			if not refused.is_empty():
				DeepUi.disable_choice(card)
				DeepUi.stat(box, "cross_out", refused, DeepUi.DIM, 12)
		if str(choice.get("action", {}).get("kind", "")) == "geode_buy":
			_geode_offer(box, unit, card)
		if needs == "offer" and not _picker_empty(needs, unit):
			## The case's price on the card itself: opening it was the only way to learn it.
			var price: int = int(run.get("chamber", {}).get("offer", {}).get("price", 0))
			var purse: int = int(unit.get("ore", 0))
			DeepUi.stat(box, "ore", "%d pyrite · you carry %d" % [price, purse], DeepUi.ORE if purse >= price else DeepUi.BAD, 12)
			if purse < price:
				## Too dear, and the card is shut, as a Geode's is (_geode_offer).
				DeepUi.disable_choice(card)
		DeepUi.spacer(box, false)
		if needs != "" and _picker_empty(needs, unit, choice.get("action", {})):
			DeepUi.disable_choice(card)
			var least: int = DeepOddities.hollow_least(choice.get("action", {}))
			var why: String = "You have nothing this could be done to."
			if needs == "gem_and_die" and unit.get("dice", []).size() <= least:
				why = "It will not leave you fewer than %d dice." % least
			elif needs == "ore":
				## Short of pyrite, not of things: say what the well wants, as its ask does.
				why = "You carry %d pyrite: the well wants %d at least." % [int(unit.get("ore", 0)), DeepDescent.WISH_LEAST]
			DeepUi.stat(box, "cross_out", why, DeepUi.DIM, 12)
		_enter(card, 0.12 + 0.08 * index)
		index += 1
	## Walking on is not another piece of work: it is the way out, a key in the room's
	## bottom-right corner, and the work stays centred on its own.
	if not leaving.is_empty():
		var out := _way_out(str(leaving.get("label", "Leave it")), func() -> void:
			command.emit({"kind": "oddity", "choice": str(leaving.id), "payload": {}}))
		_enter(out, 0.12 + 0.08 * index)

static func choice_glyph(choice: Dictionary, room: String = "") -> String:
	## The mark for one piece of work, by what it does: a face raised is an arrow up, a stone
	## sold is coins. The room's own mark is the fallback.
	var kind: String = str(choice.get("action", {}).get("kind", ""))
	if kind == "material" and bool(choice.get("action", {}).get("random", false)):
		return "question"
	if kind == "wishing_well" and str(choice.get("needs", "")) == "ore":
		return "coins"
	return str(CHOICE_GLYPHS.get(kind, ODDITY_GLYPHS.get(room, "question")))

func _geode_offer(box: VBoxContainer, unit: Dictionary, card: Control) -> bool:
	## The Geode on offer, on the card that buys it: the rock turning in 3D, what it is and
	## what it costs against what you carry. Too dear, and the card is shut. False when the
	## room has none to show.
	var held: Dictionary = run.get("chamber", {}).get("offer", {}).get("stone", {})
	if not DeepStone.is_geode(held):
		return false
	var Geode: Script = load("res://view/gems/geode.gd")
	var geode: Dictionary = held.geode
	var tone: Color = Geode.theme_tone(geode)
	var art: Control = load("res://view/gems/geode_view.gd").new(geode, tone)
	## On the phone the rock stands beside what it is, not over it.
	var words: VBoxContainer = box
	if DeepUi.phone:
		var beside := DeepUi.hbox(box, int(DeepUi.pt(8)))
		art.custom_minimum_size = Vector2(DeepUi.pt(48), DeepUi.pt(48))
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		beside.add_child(art)
		words = DeepUi.vbox(beside, int(DeepUi.pt(2)))
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		art.custom_minimum_size = Vector2(0, 96)
		box.add_child(art)
	var align: int = HORIZONTAL_ALIGNMENT_LEFT if DeepUi.phone else HORIZONTAL_ALIGNMENT_CENTER
	DeepUi.title(words, Geode.geode_name(geode), 15 if DeepUi.phone else 17, tone.lightened(0.2), align)
	## The phone leaves out the line under the name ("Blue stones only, from the Quarry's
	## rock"): the name says the color, and a hold on the card shows the rest.
	if not DeepUi.phone:
		DeepUi.wrap(words, str(Geode.geode_line(geode)), 12, DeepUi.MUTED, align, 260.0)
	var odds: Dictionary = DeepEconomy.geode_odds(geode)
	var carats: Array = odds.get("carat", [1, 1])
	DeepUi.stat(words, "carat", "%d to %d ct inside" % [int(carats[0]), int(carats[1])], DeepUi.ACCENT, 11 if DeepUi.phone else 12, "Every stone in this kind of Geode weighs this much.")
	var price: int = int(run.get("chamber", {}).get("offer", {}).get("price", 0))
	var purse: int = int(unit.get("ore", 0))
	DeepUi.stat(words, "ore", "%d pyrite · you carry %d" % [price, purse], DeepUi.ORE if purse >= price else DeepUi.BAD, 11 if DeepUi.phone else 12)
	card.tooltip_text = "Right-click the rock for what it can hold, and how likely each thing is"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			Inspector.stone(held)
			card.accept_event())
	Tips.hold(card, func() -> void: Inspector.stone(held))
	if purse < price:
		DeepUi.disable_choice(card)
	return true

func _tonight_chip(parent: Node, action: Dictionary) -> void:
	## The one pattern, etching or material a room is set up with tonight, as a chip. A blind
	## dip has none of them until the die is already in.
	if bool(action.get("random", false)):
		return
	var tonight: Dictionary = run.get("chamber", {}).get("offer", {})
	match str(action.get("kind", "")):
		"pattern":
			if not str(tonight.get("pattern", "")).is_empty():
				_tool_chip(parent, "die", DeepDice.pattern_name(str(tonight.pattern)), str(DeepContent.pattern(str(tonight.pattern)).get("text", "")), DeepUi.ACCENT)
		"etch":
			if not str(tonight.get("etching", "")).is_empty():
				_tool_chip(parent, "spark", DeepDice.etching_name(str(tonight.etching)), str(DeepContent.etching(str(tonight.etching)).get("text", "")), DiceIcons.face_kind_tint(str(tonight.etching)))
		"material":
			if not str(tonight.get("material", "")).is_empty():
				_tool_chip(parent, "drop", DeepDice.material_name(str(tonight.material)), str(DeepContent.material(str(tonight.material)).get("text", "")), DiceIcons.material_palette(str(tonight.material)).get("body", DeepUi.ACCENT))
		"collector_buy":
			var held: Dictionary = tonight.get("stone", {})
			if not held.is_empty():
				var tone: Color = DeepUi.tier_color(str(DeepStone.grade(held).tier))
				var panel := DeepUi.panel(parent, Color(tone, 0.12), Color(tone, 0.7), 8, 8)
				## Let the press through to the card it sits on.
				panel.mouse_filter = Control.MOUSE_FILTER_PASS
				var line := DeepUi.hbox(panel, 8)
				StoneCard.mini(line, held, 36)
				var words := DeepUi.vbox(line, 1)
				var named := DeepUi.hbox(words, 8)
				DeepUi.label(named, DeepUi.skill_name(held), 13, tone)
				StoneCard.grade_marks(named, held, 10)
				DeepUi.stat(words, "ore", "%d pyrite" % int(tonight.get("price", 0)), DeepUi.ORE, 11)

func _page_oddity_work(content: VBoxContainer, choice: Dictionary, unit: Dictionary, tone: Color, key: String, submit: Callable = Callable()) -> void:
	## The second page of a room's card: one piece of work picked out, the thing it is to be
	## done to set in a socket beside it, and nothing else on the screen to read.
	## `submit` takes the payload instead of it going to the room as an oddity choice (the
	## landing's well is the well card, paid for as the landing's respite).
	## Work that wants one of the party's own things is asked on the ask sheet, in the middle
	## of the screen, with the things that would do lit on the dock (docs/UI_REDO.md). A card
	## that chooses among things the room holds (a pattern, a case) stays a card here.
	var wants: String = str(choice.get("needs", ""))
	## A voucher's work done to every die asks first too, saying what it will do.
	if not wants in ["", "pattern", "offer"] or (wants.is_empty() and is_improved(choice)):
		_ask.open(_ask_spec(choice, unit, tone, key, submit.is_valid()))
		_light_ask()
		return
	var card := DeepUi.card(content, Color(tone, 0.55), 18)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 12)
	var title_row := DeepUi.hbox(box, 10)
	DeepUi.icon(title_row, choice_glyph(choice, key), 24, tone)
	DeepUi.title(title_row, plain_words(str(choice.get("label", choice.id))), 24, DeepUi.PAPER)
	if choice.has("text"):
		DeepUi.wrap(box, plain_words(DeepOddities.choice_text(choice, int(run.get("depth", 0)))), 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 560)
	DeepUi.rule(box, Color(tone, 0.4))
	var needs: String = str(choice.get("needs", ""))
	var payload_of: Callable = _picker(box, needs, unit, str(choice.id), choice.get("action", {}))
	var buttons := DeepUi.hbox(box, 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var id: String = str(choice.id)
	DeepUi.icon_button(buttons, "prev", "Never mind", func() -> void:
		_oddity_step = ""
		show_state(run), 15, DeepUi.MUTED)
	## "Do it" only exists once there is something to do it to.
	if not payload_of.call().is_empty():
		var go := DeepUi.primary(buttons, "check", "Do it", func() -> void:
			var payload: Dictionary = payload_of.call()
			if payload.is_empty():
				return
			_oddity_step = ""
			if submit.is_valid():
				submit.call(payload)
			else:
				command.emit({"kind": "oddity", "choice": id, "payload": payload}), 17, tone)
		go.custom_minimum_size.x = 200
	_enter(card, 0.05)

func _ask_spec(choice: Dictionary, unit: Dictionary, tone: Color, room_key: String, well: bool) -> Dictionary:
	## What a piece of work asks for, as the ask sheet opens it: a slot for each thing, the
	## things that would do and why the rest would not, and a face, an inclusion or a sum of
	## pyrite after the slot when the work wants one.
	var needs: String = str(choice.get("needs", ""))
	var action: Dictionary = choice.get("action", {})
	var id: String = str(choice.id)
	var spec: Dictionary = {"key": ("well:" if well else "oddity:") + id, "title": plain_words(str(choice.get("label", id))),
		"text": plain_words(DeepOddities.choice_text(choice, int(run.get("depth", 0)))) if choice.has("text") else "",
		"glyph": choice_glyph(choice, room_key), "tone": tone, "confirm": "Do it", "slots": []}
	var tonight: String = _tonight_words(action)
	if not tonight.is_empty():
		spec.text = (str(spec.text) + "\n" + tonight).strip_edges()
	var refuse := func(items: Array) -> Dictionary:
		var out: Dictionary = {}
		for item in items:
			var why: String = _work_refusal(action, item)
			if not why.is_empty():
				out[str(item.get("id", ""))] = why
		return out
	var stones: Array = _carried(unit)
	var dice: Array = unit.get("dice", [])
	match needs:
		"stone":
			spec.slots = [{"key": "stone_id", "kind": "stone", "label": "Which stone?", "items": stones, "refusals": refuse.call(stones)}]
		"raw_stone":
			var raw: Array = _loose(unit).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			spec.slots = [{"key": "stone_id", "kind": "stone", "label": "Which raw stone?", "items": raw, "refusals": refuse.call(raw)}]
		"two_stones":
			spec.slots = [{"key": "keep_id", "kind": "stone", "label": "First stone", "items": stones, "refusals": refuse.call(stones)},
				{"key": "feed_id", "kind": "stone", "label": "Second stone", "items": stones, "refusals": refuse.call(stones)}]
		"gem_and_die":
			var gems: Array = DeepStone.rail_stones(unit) + _loose(unit).filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)))
			spec.slots = [{"key": "stone_id", "kind": "stone", "label": "Which gem turns Void?", "items": gems, "refusals": refuse.call(gems)},
				{"key": "die_id", "kind": "die", "label": "Which die goes in?", "items": dice, "refusals": refuse.call(dice)}]
		"raw_stones":
			var raw: Array = _loose(unit).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			var most: int = maxi(1, int(action.get("most", 3)))
			spec.slots = [{"key": "stone_ids", "kind": "stone", "label": "Up to %s" % DeepUi.plural(most, "raw stone"), "items": raw, "refusals": refuse.call(raw), "most": most, "hp": int(action.get("hp", 6))}]
		"inclusion":
			var carriers: Array = stones.filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false))))
			spec.slots = [{"key": "stone_id", "kind": "stone", "label": "Which stone?", "items": carriers, "refusals": refuse.call(carriers)}]
			spec.inclusions = {"key": "inclusion", "of": "stone_id"}
		"die", "die_face":
			var kind: String = str(action.get("kind", ""))
			var refused: Dictionary = refuse.call(dice)
			var set_for: Dictionary = run.get("chamber", {}).get("offer", {})
			if kind == "pattern" and not str(set_for.get("pattern", "")).is_empty():
				## Only the dice the anvil could actually stamp tonight; the rest are refused
				## rather than left out, so a dimmed die says why on its plate.
				for d in dice:
					if not DeepDice.pattern_allows(str(set_for.pattern), str(d.get("shape", "D6"))):
						refused[str(d.get("id", ""))] = "it is the wrong size for this pattern"
			spec.slots = [{"key": "die_id", "kind": "die", "label": "Which die?", "items": dice, "refusals": refused}]
			if needs == "die_face":
				spec.faces = {"key": "face", "of": "die_id", "blanks": true, "lowering": kind == "lower_face", "label": "Which face?"}
		"die_faces":
			## A Smith's Voucher's carver (docs/DEEP_START.md §4): up to `most` faces, of one die
			## or several, picked on the faces of whichever die is in the slot.
			var lowering: bool = str(action.get("kind", "")) == "lower_face"
			var most: int = maxi(1, int(choice.get("most", action.get("faces", 3))))
			spec.slots = [{"key": "die_id", "kind": "die", "label": "Which die?", "items": dice, "refusals": refuse.call(dice)}]
			spec.faces = {"key": "faces", "of": "die_id", "blanks": true, "lowering": lowering, "most": most,
				"label": "Which faces? Up to %d, on one die or several" % most}
			spec.build = func(_picks: Dictionary, extras: Dictionary) -> Dictionary:
				var chosen: Array = extras.get("faces", []) if extras.get("faces", []) is Array else []
				if chosen.is_empty():
					return {}
				return {"picks": chosen.map(func(entry: Dictionary) -> Dictionary: return {"die_id": str(entry.get("die_id", "")), "face": int(entry.get("face", 0))})}
		"":
			## A Smith's Voucher's work done to every die at once: nothing to choose, so the ask
			## only says what will happen, and its button does it.
			if is_improved(choice):
				spec.ready = true
				spec.text = (str(spec.text) + "\n" + _every_die_words(action, unit)).strip_edges()
		"ore":
			## How much goes down the well: anything from the least it takes to the most it
			## takes, or to all you carry.
			var carried: int = int(unit.get("ore", 0))
			var most: int = mini(carried, DeepDescent.WISH_MOST)
			if most < DeepDescent.WISH_LEAST:
				spec.blocked = "You carry %d pyrite: the well wants %d at least." % [carried, DeepDescent.WISH_LEAST]
			else:
				spec.slider = {"key": "ore", "min": DeepDescent.WISH_LEAST, "max": most, "value": DeepDescent.WISH_LEAST, "unit": "pyrite"}
	if str(action.get("kind", "")) in ["wishing_well", "trade_up", "collector_sell"] and bool(run.get("marks_lent", false)):
		## A gem the rail brought from home, given up here, is gone from the Vault too (the
		## altar says the same): said under the slot as soon as one is picked, not after.
		spec.warn = func(picks: Dictionary) -> String:
			var picked: Dictionary = DeepOddities.find_stone(unit, str(picks.get("stone_id", "")))
			return "A gem your rail brought from home: your Vault loses it for good." if not picked.is_empty() and DeepDescent.is_lent(run, picked) else ""
	return spec

func _tonight_words(action: Dictionary) -> String:
	## The one pattern, etching or material a room is set up with tonight, in a line. A blind
	## dip has none of them until the die is already in.
	if bool(action.get("random", false)):
		return ""
	var tonight: Dictionary = run.get("chamber", {}).get("offer", {})
	match str(action.get("kind", "")):
		"pattern":
			if not str(tonight.get("pattern", "")).is_empty():
				return "The anvil is set for %s. %s" % [DeepDice.pattern_name(str(tonight.pattern)), str(DeepContent.pattern(str(tonight.pattern)).get("text", ""))]
		"etch":
			if not str(tonight.get("etching", "")).is_empty():
				return "The needles are set for %s. %s" % [DeepDice.etching_name(str(tonight.etching)), str(DeepContent.etching(str(tonight.etching)).get("text", ""))]
		"material":
			if not str(tonight.get("material", "")).is_empty():
				return "The vat holds %s. %s" % [DeepDice.material_name(str(tonight.material)), str(DeepContent.material(str(tonight.material)).get("text", ""))]
	return ""

## How long an upgraded bench shows its plain work before the better work replaces it.
const BENCH_BEAT: float = 1.1

static func is_improved(choice: Dictionary) -> bool:
	## A piece of work shown in its better version (DeepDescent.room_choices flags it `improved:
	## true`; on the card itself `improved` is the better version's own block).
	var flag: Variant = choice.get("improved", false)
	return flag is bool and bool(flag)

func _bench_key() -> String:
	## This visit to this bench: the run, the depth and the card.
	return "%s|%d|%s" % [str(run.get("run_id", "")), int(run.get("depth", 0)), str(run.get("chamber", {}).get("oddity", ""))]

func bench_upgrade() -> String:
	## Why this player's bench does the better work: "voucher" (one spent on walking in),
	## "luck" (a lucky room, for the whole party) or "" (DeepDescent.bench_upgrade).
	return DeepDescent.bench_upgrade(run, local_id)

static func plain_words(text: String) -> String:
	## Words as read anywhere but an upgraded card: the **marks** round the better words gone.
	return DeepContent.plain(text)

func _marked_text(parent: Node, text: String, size: int, color: Color, width: float) -> Control:
	## A piece of work's words, its **marked** words (what the upgrade makes better) bold in the
	## upgrade's gold, the marks themselves never shown. Words with no marks are a plain line.
	if not text.contains("**"):
		return DeepUi.wrap(parent, text, size, color, HORIZONTAL_ALIGNMENT_LEFT, width)
	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.custom_minimum_size.x = width
	rtl.name = "MarkedText"
	DeepUi.set_text_size(rtl, size)
	rtl.push_color(color)
	var parts: PackedStringArray = text.split("**")
	for at in range(parts.size()):
		if at % 2 == 1:
			rtl.push_font(DeepUi.bold_font())
			rtl.push_color(DEEP_TONE.lightened(0.15))
			rtl.add_text(parts[at])
			rtl.pop()
			rtl.pop()
		else:
			rtl.add_text(parts[at])
	rtl.pop_all()
	parent.add_child(rtl)
	return rtl

func _marked_title(parent: Node, text: String, size: int, color: Color) -> Control:
	## A piece of work's name, its **marked** words (what the upgrade makes better) in the same
	## bold gold as its words below, the marks never shown. Each part is a title of its own,
	## side by side with no gap, so the face, the size and the shadow are the title's own.
	if not text.contains("**"):
		return DeepUi.title(parent, text, size, color)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.name = "MarkedTitle"
	parent.add_child(line)
	var parts: PackedStringArray = text.split("**")
	for at in range(parts.size()):
		if parts[at].is_empty():
			continue
		var part := DeepUi.title(line, parts[at], size, DEEP_TONE.lightened(0.15) if at % 2 == 1 else color)
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _corner_badge(card: PanelContainer, make: Callable) -> Control:
	## A badge on a card's top right corner, over its border, the way a creature's Block pill sits
	## on its tag (creature_tag.gd `_relayout`): it takes no room on the card, so it moves nothing
	## there. Held by a bare Control the card lays over its content; `make` builds the badge
	## into it, and the badge is placed by hand.
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.name = "Corner"
	card.add_child(corner)
	var badge: Control = make.call(corner)
	corner.set_meta("badge", badge)
	## A method, not a lambda: a page drawn again in the same frame frees the card before a
	## deferred call lands, and a lambda's captures error when they are gone.
	corner.resized.connect(_place_corner.bind(corner))
	_place_corner.call_deferred(corner)
	return badge

func _border_pill(plate: PanelContainer, make: Callable) -> Control:
	## A pill on a plate's top border, as a fieldset's legend sits: centred on the border's line,
	## in past the cut corner (`PLATE_LABEL_IN`). Hung from a bare Control the plate lays over its
	## content (as `_corner_badge` hangs a badge), after what is in the plate so it is drawn over
	## it and over the border; it takes no room, so the plate keeps its size.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.name = "HandLegend"
	plate.add_child(holder)
	var pill: Control = make.call(holder)
	holder.set_meta("badge", pill)
	holder.resized.connect(_place_border_pill.bind(holder))
	_place_border_pill.call_deferred(holder)
	return pill

func _place_border_pill(holder: Variant) -> void:
	if not is_instance_valid(holder) or not (holder as Control).is_inside_tree():
		return
	var at: Control = holder
	var pill: Variant = at.get_meta("badge", null)
	var plate: Control = at.get_parent() as Control
	if not is_instance_valid(pill) or plate == null:
		return
	var style: StyleBox = plate.get_theme_stylebox("panel")
	var line: float = float((style as StyleBoxFlat).border_width_top) * 0.5 if style is StyleBoxFlat else 1.5
	(pill as Control).reset_size()
	(pill as Control).position = Vector2(PLATE_LABEL_IN - style.get_margin(SIDE_LEFT), line - (pill as Control).size.y * 0.5 - style.get_margin(SIDE_TOP))

func _place_corner(corner: Variant) -> void:
	## The badge `_corner_badge` hung on a card: on its top right corner, half over its border.
	if not is_instance_valid(corner) or not (corner as Control).is_inside_tree():
		return
	var holder: Control = corner
	var badge: Variant = holder.get_meta("badge", null)
	var card: Control = holder.get_parent() as Control
	if not is_instance_valid(badge) or card == null:
		return
	var style: StyleBox = card.get_theme_stylebox("panel")
	(badge as Control).reset_size()
	(badge as Control).position = Vector2(holder.size.x + style.get_margin(SIDE_RIGHT) - (badge as Control).size.x - 10.0, - style.get_margin(SIDE_TOP) - (badge as Control).size.y * 0.5 - 2.0)

func _upgraded_pill(card: PanelContainer) -> void:
	## "Upgraded" on the card's corner, padded as the round-4 Voucher pill was (DeepUi.pill: the
	## owner, November 6, 2026), its fill made solid so the border it sits on does not show
	## through the words.
	_corner_badge(card, func(holder: Control) -> Control:
		var pill := DeepUi.pill(holder, "spark", "Upgraded", DEEP_TONE, 12,
			"A good day at the bench: everyone gets the better work, free." if bench_upgrade() == "luck" else "Your Smith's Voucher: the better work, for this visit.")
		pill.name = "UpgradedBadge"
		var style: StyleBox = pill.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).bg_color = DeepUi.LEDGER_FILL.lerp(DEEP_TONE, 0.14)
			## Outlined in the card's own gold, as wide as the card's border (round 7): the
			## pill's own outline was mixed down into the dark and read faint beside it.
			(style as StyleBoxFlat).border_color = DEEP_TONE
			(style as StyleBoxFlat).set_border_width_all(2)
		return pill)

func _reveal_bench(key: String) -> void:
	## The beat is up: a sparkle sweeps the plain work, and halfway across it the better work
	## stands in its place.
	if str(_bench_revealed.get(key, "")) != "pending":
		return
	if key != _bench_key() or str(run.get("phase", "")) != "chamber" or not is_inside_tree():
		_bench_revealed[key] = "done"
		return
	var row: Node = _page_holder.find_child("BenchRow", true, false) if is_instance_valid(_page_holder) else null
	DeepAudio.play("gleam", {"volume": 0.9})
	if row is Control and (row as Control).is_visible_in_tree():
		var rect: Rect2 = (row as Control).get_global_rect().grow(16.0)
		var sweep := SparkleSweep.new(DEEP_TONE)
		sweep.name = "BenchSweep"
		sweep.position = rect.position - global_position
		sweep.size = rect.size
		add_child(sweep)
	_later(SparkleSweep.TURN, func() -> void:
		_bench_revealed[key] = "done"
		if key != _bench_key():
			return
		show_state(run)
		var fresh: Node = _page_holder.find_child("BenchRow", true, false) if is_instance_valid(_page_holder) else null
		if fresh != null and not _headless:
			for card in fresh.get_children():
				if card is Control and bool(card.get_meta("improved", false)):
					DeepUi.pop_in(card as Control, 0.0, 0.9, 0.3))

func _hammer_dock_die(dice: Array) -> void:
	## The Smithy's hammer landing: struck on the die it hit, where the dock shows it.
	if dice.is_empty():
		DieFx.strike(self, size * Vector2(0.5, 0.8))
		return
	var at: Vector2 = _run_dock.centre_of("die", str(dice[0].get("id", ""))) if _run_dock != null else Vector2.INF
	DieFx.strike(self, (at - global_position) if at != Vector2.INF else size * Vector2(0.5, 0.8), 1.2)

func _every_die_words(action: Dictionary, unit: Dictionary) -> String:
	## What a voucher's work done to every die will do to this player's dice, in a line.
	var dice: Array = unit.get("dice", [])
	var tonight: Dictionary = run.get("chamber", {}).get("offer", {})
	match str(action.get("kind", "")):
		"pattern":
			var pattern: String = str(tonight.get("pattern", ""))
			var able: int = dice.filter(func(d: Dictionary) -> bool: return DeepDice.pattern_allows(pattern, str(d.get("shape", "D6")))).size()
			if able == 0:
				return "None of your dice is a size this pattern fits."
			if able == dice.size():
				return "It goes on all %s you carry." % DeepUi.plural(dice.size(), "die", "dice")
			return "It goes on %d of your %s; the rest are the wrong size for it." % [able, DeepUi.plural(dice.size(), "die", "dice")]
		"etch":
			return "It goes on the highest face of each of your %s." % DeepUi.plural(dice.size(), "die", "dice")
	return ""

func _every_die_refused(choice: Dictionary, unit: Dictionary) -> String:
	## Why a voucher's every-die stamp could not be done at all ("" when it could).
	var action: Dictionary = choice.get("action", {})
	if not is_improved(choice) or not str(choice.get("needs", "")).is_empty() or str(action.get("kind", "")) != "pattern":
		return ""
	var pattern: String = str(run.get("chamber", {}).get("offer", {}).get("pattern", ""))
	if pattern.is_empty():
		return ""
	var able: bool = unit.get("dice", []).any(func(d: Dictionary) -> bool: return DeepDice.pattern_allows(pattern, str(d.get("shape", "D6"))))
	return "" if able else "None of your dice is a size this pattern fits."

func _light_ask() -> void:
	## The things the ask would take stay lit on the dock; the rest step back.
	if _ask == null or _run_dock == null:
		return
	if _ask.is_open():
		_run_dock.spotlight({"stone": _ask.eligible("stone"), "die": _ask.eligible("die")})
	else:
		_run_dock.unspotlight()
	_ask.floor_height = _run_dock.height() if _run_dock.visible else 0.0
	_hush_room_words()

func _hush_room_words() -> void:
	## The room's words under an open ask would show only as ends either side of the sheet,
	## and the sheet says what the work is: they step out while it is up.
	if _cross_sub != null:
		_cross_sub.modulate.a = 0.0 if _ask != null and _ask.is_open() else 1.0
	## And a shrine's mark, which would show round the sheet's edge as a grey shape; it stays
	## out while a page is over the room as well.
	if _stage != null:
		_stage.hush_shrine((_ask != null and _ask.is_open()) or (_scrim != null and _scrim.visible) or _shrine_covered)
	## The pointer's plate too: hidden while the ask is up, back (if still wanted) once it closes.
	if _chip != null:
		_fill_chip()

func _settle_ask() -> void:
	## An ask outlives the page it was opened from only while the room still wants it.
	if _ask == null or not _ask.is_open():
		_hush_room_words()
		return
	var key: String = str(_ask.key())
	var phase: String = str(run.get("phase", ""))
	var wanted: bool = false
	if key.begins_with("oddity:"):
		wanted = phase == "chamber" and _oddity_step == key.trim_prefix("oddity:") and str(me().get("oddity_choice", "")).is_empty()
	elif key.begins_with("well:"):
		wanted = phase == "landing" and _landing_view == "wish" and _oddity_step == key.trim_prefix("well:") and str(me().get("respite", "")).is_empty()
	elif key == "trade":
		wanted = phase == "landing" and _landing_view == "trade"
	elif key == "dock_offer":
		wanted = _run_dock.choosing()
	if not wanted:
		_ask.close()
		_run_dock.unspotlight()
		_hush_room_words()

func _ask_confirmed(key: String, payload: Dictionary) -> void:
	_run_dock.unspotlight()
	_hush_room_words()
	if key.begins_with("oddity:"):
		_oddity_step = ""
		## An ask with nothing to choose answers "ready"; the room is sent no payload for it.
		var sent: Dictionary = payload.duplicate()
		sent.erase("ready")
		command.emit({"kind": "oddity", "choice": key.trim_prefix("oddity:"), "payload": sent})
	elif key.begins_with("well:"):
		_oddity_step = ""
		if payload.has("ore"):
			_respite_ore(int(payload.ore))
		else:
			_respite("wish", str(payload.get("stone_id", "")))
	elif key == "trade":
		command.emit({"kind": "trade_offer", "stone_id": str(payload.get("stone_id", "")), "to": _trade_with})

func _ask_cancelled() -> void:
	_oddity_step = ""
	_run_dock.unspotlight()
	show_state(run)

func _reworked(result: Dictionary) -> Dictionary:
	## A room's result as a stone on the ladder: the stone as it was, which ladder, the rung it
	## lands on and whether it broke. Empty when nothing's Cut or Clarity was worked on.
	if result.get("broke", null) is Dictionary and result.broke.get("stone", null) is Dictionary:
		var lost: Dictionary = result.broke.stone
		var broken_field: String = str(result.broke.get("field", "cut"))
		return {"stone": lost, "field": broken_field, "now": int(lost.get(broken_field, 0)), "broke": true}
	var verdict: Dictionary = result.get("verdict", {}) if result.get("verdict", null) is Dictionary else {}
	var changed: Array = result.get("changed", [])
	if verdict.is_empty() or changed.is_empty() or not str(verdict.get("field", "")) in ["cut", "clarity"]:
		return {}
	var field: String = str(verdict.field)
	var before: Dictionary = (changed[0] as Dictionary).duplicate(true)
	before[field] = int(verdict.get("was", before.get(field, 0)))
	return {"stone": before, "field": field, "now": int(verdict.get("now", 0)), "broke": false}

func _rework_reveal(parent: Node, reworked: Dictionary) -> Control:
	## The stone worked on its ladder (Rework): heat or sparks, a beat, then the rung it lands
	## on. A tap or a click on it lands it at once.
	var card := DeepUi.card(parent, Color(DeepUi.BAD if bool(reworked.broke) else DeepUi.ACCENT, 0.45), 14)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## On the phone the stone stands beside its ladder: the page has width to spare, not height.
	var ladder := Rework.new(reworked.stone, str(reworked.field), DeepUi.pt(56) if DeepUi.phone else 96.0, DeepUi.phone)
	card.add_child(ladder)
	_enter(card, 0.08)
	if _fresh and not _headless:
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if is_instance_valid(ladder):
				ladder.play(int(reworked.now), bool(reworked.broke)))
	else:
		ladder.settle(int(reworked.now), bool(reworked.broke))
	return ladder

func _verdict_stamp(parent: Node, verdict: Dictionary) -> void:
	## Better or worse, said out loud. A wheel or an oven never gives back what it took, so
	## there is always a verdict to read, and the room should make something of it.
	var better: int = int(verdict.get("better", 0))
	var field: String = str(verdict.get("field", "cut"))
	var was: String = DeepContent.cut_name(int(verdict.get("was", 0))) if field == "cut" else DeepContent.clarity_name(int(verdict.get("was", 0)))
	var now: String = DeepContent.cut_name(int(verdict.get("now", 0))) if field == "cut" else DeepContent.clarity_name(int(verdict.get("now", 0)))
	var tone: Color = DeepUi.GOOD if better > 0 else (DeepUi.BAD if better < 0 else DeepUi.MUTED)
	var word: String = "Better" if better > 0 else ("Worse" if better < 0 else "Changed")
	var card := DeepUi.card(parent, Color(tone, 0.6), 14)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := DeepUi.hbox(card, 14)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.stat(line, "cut" if field == "cut" else "clarity", was, DeepUi.DIM, 20)
	DeepUi.icon(line, "next", 22, tone)
	DeepUi.stat(line, "cut" if field == "cut" else "clarity", now, tone, 26)
	DeepUi.title(line, word, 24, tone)
	_enter(card, 0.08)
	if _fresh and not _headless:
		DeepUi.pulse(card, 1.14, 0.5)
		DeepAudio.play("stone_found" if better > 0 else ("salvage_lose" if better < 0 else "ui_toggle"), {"volume": 0.8})
		var at := func() -> void:
			if is_instance_valid(card):
				DeepUi.burst(card, card.size * 0.5, tone, 16 + 26 * absi(better), 200.0 + 140.0 * float(absi(better)), 0.8, 5.0)
		get_tree().create_timer(0.25).timeout.connect(at)

func _tumble_stamp(parent: Node, tumbled: Dictionary) -> void:
	## The Tumbler's skill that went in, greyed, beside the one that came out, so the change
	## reads at a glance: the page used to show only the new card.
	var was: String = str(tumbled.get("from", ""))
	var now: String = str(tumbled.get("to", ""))
	var tone: Color = DeepUi.color(str(DeepContent.skill(now).get("color", "WHITE")))
	var card := DeepUi.card(parent, Color(tone, 0.6), 14)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := DeepUi.hbox(card, 12)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(line, GemIcons.emblem(was), 30, DeepUi.DIM)
	DeepUi.label(line, str(DeepContent.skill(was).get("name", was)), 20, DeepUi.DIM)
	DeepUi.icon(line, "next", 22, tone)
	DeepUi.icon(line, GemIcons.emblem(now), 36, tone)
	DeepUi.title(line, str(DeepContent.skill(now).get("name", now)), 26, tone.lightened(0.2))
	_enter(card, 0.08)
	if _fresh and not _headless:
		DeepUi.pulse(card, 1.12, 0.5)

func _page_well(content: VBoxContainer) -> void:
	## What the well sent back. First the room is left alone for a breath: the water takes
	## what went in, the light under it gathers, and only then does it answer and the page
	## rise over it, as loud as the rung deserves. Nothing moves on until the player says so.
	var well: Dictionary = _hold.get("well", {})
	var made: Array = _hold.get("made", [])
	var tier: int = _well_loudness(well)
	var tone: Color = WELL_TONES[tier]
	var kind: String = str(well.get("kind", ""))
	var head := DeepUi.vbox(content, 8)
	var medal := Medallion.new("heart" if kind == "heal" else ("ore" if kind == "ore" else "drop"), tone, 110 + 10 * tier)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(medal)
	DeepUi.label(head, "The well answers", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	## Judged against what went down it, never the rung's own name: "A good stone" sat over a
	## tiny one, and "A hundred pyrite" after a throw of 157 read as a win.
	## The phone's headline and answer are held to its screen: a stone's full name at the loudest
	## rung ran wide, and the answer under it tall (November 10, 2026). Both wrap.
	var named := DeepUi.title(head, DeepOddities.well_headline(well, made), (22 + 2 * tier) if DeepUi.phone else 34 + 6 * tier, tone.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	named.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	named.add_theme_constant_override("outline_size", 8 + 2 * tier)
	var headline_most: float = DeepUi.pt(520) if DeepUi.phone else 1000.0
	if named.get_combined_minimum_size().x > headline_most:
		named.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		named.custom_minimum_size.x = headline_most
		named.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.wrap(head, str(_hold.get("message", "")), 13 if DeepUi.phone else 17, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER, DeepUi.pt(480) if DeepUi.phone else 720.0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var counted: String = _well_counted(well)
	if not counted.is_empty():
		DeepUi.label(head, counted, 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var suspense: float = WELL_SUSPENSE if _fresh and not _headless else 0.0
	var rewards: Dictionary = {"stones": made, "ore": int(well.get("ore", 0))}
	if not made.is_empty() or int(well.get("ore", 0)) > 0:
		var card := DeepUi.card(content, Color(tone, 0.5), 16)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reward_row(DeepUi.vbox(card, 10), rewards, suspense + 0.45)
	elif kind == "heal":
		DeepUi.stat(content, "heart", "+%d health" % int(well.get("healed", 0)), DeepUi.GOOD, 22).alignment = BoxContainer.ALIGNMENT_CENTER
	var go := _main(DeepUi.primary(content, "check" if not made.is_empty() else "descend", "Take it" if not made.is_empty() else "Onward", _release, 18, tone))
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 240
	if suspense <= 0.0:
		if _fresh:
			_well_answer(tier)
		return
	## The breath before: the page and the scrim wait, and a line over the room says only
	## that something is coming.
	_scrim.visible = false
	content.modulate.a = 0.0
	go.disabled = true
	var stir := DeepUi.label(_page_holder, "Something stirs in the water...", 22, tone.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER)
	stir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 140)
	stir.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stir.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	stir.add_theme_constant_override("outline_size", 8)
	stir.modulate.a = 0.0
	DeepAudio.play("oddity", {"volume": 0.7})
	var build := stir.create_tween()
	build.tween_property(stir, "modulate:a", 1.0, 0.4)
	for beat in range(3):
		build.tween_callback(func() -> void: DeepAudio.play("tally", {"volume": 0.5 + 0.12 * float(beat)}))
		build.tween_interval((WELL_SUSPENSE - 0.6) / 3.0)
	build.tween_property(stir, "modulate:a", 0.0, 0.2)
	var reveal := content.create_tween()
	reveal.tween_interval(suspense)
	reveal.tween_callback(func() -> void:
		_scrim.visible = true
		_scrim.modulate.a = 0.0
		_scrim.create_tween().tween_property(_scrim, "modulate:a", 1.0, 0.35)
		_well_answer(tier)
		DeepUi.pulse(named, 1.2 + 0.08 * float(tier), 0.6)
		for wave in range(tier + 1):
			get_tree().create_timer(0.1 + 0.2 * float(wave)).timeout.connect(func() -> void:
				if is_instance_valid(medal):
					DeepUi.burst(medal, medal.size * 0.5, tone.lightened(0.1 * float(wave)), 16 + 22 * tier, 200.0 + 110.0 * float(tier), 0.8 + 0.15 * float(tier), 4.0 + float(tier)))
		if tier >= 3:
			DeepUi.shake(self, 4.0 + 3.0 * float(tier - 3), 0.35)
		if tier >= 4:
			for color in ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]:
				DeepUi.burst(medal, medal.size * 0.5, DeepUi.color(color), 20, 420.0, 1.3, 7.0))
	reveal.tween_property(content, "modulate:a", 1.0, 0.35)
	reveal.tween_interval(0.5)
	reveal.tween_callback(func() -> void: go.disabled = false)

static func _well_loudness(well: Dictionary) -> int:
	## How loud the well's answer is, 0 to 4: its rung's, except that a loss is not cheered.
	## Pyrite back short of what went down is said quietly, whatever rung it landed on.
	var tier: int = clampi(int(well.get("tier", 0)), 0, 4)
	return mini(tier, 1) if DeepOddities.well_short(well) else tier

static func _well_counted(well: Dictionary) -> String:
	## What the well counted the throw at, when that is news: a stone's worth in pyrite, or
	## pyrite a Bright Well made more of. Pyrite counted at its face is already said in the
	## line above ("157 pyrite goes down into the dark"), so it is not said twice.
	var worth: int = int(well.get("worth", 0))
	var spent: int = int(well.get("spent", 0))
	if spent > 0 and worth == spent:
		return ""
	return "The well counted it as %d pyrite" % worth

func _well_answer(tier: int) -> void:
	## The well has said it in light already, its bucket breaking over the rim (see
	## WishingWell.draw_up, started when the wish was made); the screen says it in sound.
	if str(_hold.get("well", {}).get("kind", "")) == "heal":
		DeepAudio.play("heal", {"volume": 0.9})
	DeepAudio.play(WELL_VOICES[tier], {"volume": 0.65 + 0.08 * float(tier)})
	if tier >= 3:
		DeepAudio.play("victory", {"volume": 0.5 + 0.1 * float(tier)})

func _well_stamp(parent: Node, well: Dictionary, made: Array = []) -> void:
	## The rung the well landed on, with as much noise as it is worth. The top of its ladder
	## should feel like a jackpot and the bottom like a wet plop, and this is where that is
	## said: the sparks, the sound and the size of the words all read off the same number.
	var tier: int = _well_loudness(well)
	var tone: Color = [DeepUi.DIM, DeepUi.INFO, DeepUi.GOOD, DeepUi.ACCENT, DeepUi.ORE][tier]
	var card := DeepUi.card(parent, Color(tone, 0.55), 14)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 4)
	DeepUi.title(box, DeepOddities.well_headline(well, made), 22 + 6 * tier, tone.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	var counted: String = _well_counted(well)
	if not counted.is_empty():
		DeepUi.label(box, counted, 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_enter(card, 0.1)
	if not _fresh or _headless:
		return
	DeepUi.pulse(card, 1.1 + 0.05 * float(tier), 0.5)
	DeepAudio.play(["ui_toggle", "stone_found", "stone_found", "victory", "victory"][tier], {"volume": 0.6 + 0.09 * float(tier)})
	for wave in range(tier + 1):
		var at := func() -> void:
			if is_instance_valid(card):
				DeepUi.burst(card, card.size * Vector2(0.5, 0.6), tone, 12 + 24 * tier, 180.0 + 110.0 * float(tier), 0.7 + 0.15 * float(tier), 4.0 + float(tier))
		get_tree().create_timer(0.2 + 0.16 * float(wave)).timeout.connect(at)

func _racks(parent: Node, choice_id: String, raw: Array, most: int, hp: int) -> Array:
	## The acid bath's racks: three sockets, and every raw stone you carry laid out under
	## them. Clicking a stone drops it in the first empty rack; clicking a full rack takes
	## it back out. Nothing is spent until the whole set is sent down.
	var key: String = _slot_key(choice_id, "racks")
	var set_ids: Array = []
	for id in _choice_picks.get(key, []):
		if set_ids.size() < most and raw.any(func(st: Dictionary) -> bool: return str(st.get("id", "")) == str(id)):
			set_ids.append(str(id))
	_choice_picks[key] = set_ids
	var sockets := DeepUi.hbox(parent, 10)
	sockets.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in range(most):
		var filled: bool = slot < set_ids.size()
		var socket := PanelContainer.new()
		socket.custom_minimum_size = Vector2(86, 86)
		sockets.add_child(socket)
		socket.add_theme_stylebox_override("panel", DeepUi.raised(Color(DeepUi.ACCENT, 0.2) if filled else Color(DeepUi.SLATE, 0.8),
			Color(DeepUi.ACCENT, 0.9) if filled else Color(DeepUi.LINE, 0.8), 12, 8, 0.3))
		if not filled:
			var empty := DeepUi.center(socket)
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			DeepUi.icon(empty, "drop", 26, DeepUi.DIM)
			continue
		var held: Dictionary = raw.filter(func(st: Dictionary) -> bool: return str(st.get("id", "")) == str(set_ids[slot]))[0]
		var holder := DeepUi.center(socket)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture: Control = Thumbs.GemThumb.new(held, 62)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
		socket.tooltip_text = "%s — click to take it back out" % DeepStone.raw_name(held)
		socket.mouse_filter = Control.MOUSE_FILTER_STOP
		socket.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var taken: String = str(set_ids[slot])
		socket.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_toggle", {"volume": 0.7})
				var kept: Array = _choice_picks.get(key, []).duplicate()
				kept.erase(taken)
				_choice_picks[key] = kept
				show_state(run)
				socket.accept_event())
	DeepUi.label(parent, "%d in the racks · %d health" % [set_ids.size(), set_ids.size() * hp],
		13, DeepUi.BAD if set_ids.size() > 0 else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if raw.is_empty():
		DeepUi.stat(parent, "cross_out", "You carry nothing still in its rock.", DeepUi.DIM, 12)
		return set_ids
	DeepUi.label(parent, "Your raw stones", 12, DeepUi.MUTED)
	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", 6)
	shelf.add_theme_constant_override("v_separation", 6)
	shelf.alignment = FlowContainer.ALIGNMENT_CENTER
	parent.add_child(shelf)
	for stone in raw.slice(0, RACK_SHELF):
		var id: String = str(stone.get("id", ""))
		var chosen: bool = set_ids.has(id)
		var card := PanelContainer.new()
		shelf.add_child(card)
		_mark(card, chosen, DeepUi.ACCENT)
		card.tooltip_text = DeepStone.raw_name(stone)
		if chosen or set_ids.size() >= most:
			card.modulate = Color(0.55, 0.55, 0.6, 0.55)
		var frame := DeepUi.center(card)
		frame.custom_minimum_size = Vector2(52, 52)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var thumb: Control = Thumbs.GemThumb.new(stone, 46)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(thumb)
		if chosen or set_ids.size() >= most:
			continue
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_toggle", {"volume": 0.7})
				var kept: Array = _choice_picks.get(key, []).duplicate()
				kept.append(id)
				_choice_picks[key] = kept
				show_state(run)
				card.accept_event())
	if raw.size() > RACK_SHELF:
		DeepUi.label(parent, "and %d more in your haul." % (raw.size() - RACK_SHELF), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return set_ids

func _fire_on(unit: Dictionary, kind: String) -> Array:
	## Every gem this player has to hand that fires on this pattern. A stone nobody has read
	## is not counted: its skill is not known yet, and the shrine should not leak it.
	if kind.is_empty():
		return []
	return _carried(unit).filter(func(st: Dictionary) -> bool:
		return bool(st.get("appraised", false)) and str(DeepStone.skill_of(st).get("trigger", {}).get("kind", "")) == kind)

func _shrine_patterns(unit: Dictionary) -> Array:
	## The three the shrine offers: the patterns your own gems fire on, the commonest first.
	## A pattern nothing of yours reads would be a carat thrown into a hole, so it is only
	## padded out with the plain ones when you carry fewer than three kinds.
	var counted: Dictionary = {}
	for stone in _carried(unit):
		if not bool(stone.get("appraised", false)):
			continue
		var kind: String = str(DeepStone.skill_of(stone).get("trigger", {}).get("kind", ""))
		if kind.is_empty() or kind == "always" or kind == "resonance":
			continue
		counted[kind] = int(counted.get(kind, 0)) + 1
	var kinds: Array = counted.keys()
	kinds.sort()
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(counted[a]) > int(counted[b]))
	for fallback in ["pair", "two_pair", "triple", "straight", "odd", "even"]:
		if kinds.size() >= SHRINE_OFFERS:
			break
		if not kinds.has(fallback):
			kinds.append(fallback)
	return kinds.slice(0, SHRINE_OFFERS)

func _picker_empty(needs: String, unit: Dictionary, action: Dictionary = {}) -> bool:
	## Whether there is nothing this piece of work could be done to at all. The rules' own
	## test (DeepOddities.nothing_to_work), so the draw that puts back a card nobody could use
	## and the card greyed out here never disagree.
	if needs == "gem_and_die":
		## The Hollow's least dice are on its card, whichever action was handed in.
		for choice in DeepContent.oddity(str(run.get("chamber", {}).get("oddity", ""))).get("choices", []):
			if str(choice.get("needs", "")) == needs:
				action = choice.get("action", {})
	return DeepOddities.nothing_to_work(needs, action, unit, run.get("chamber", {}).get("offer", {}))

func _loose(unit: Dictionary) -> Array:
	## The bag without its Geodes. Nothing down here can be done to a sealed Geode (read, sold,
	## worked on, thrown in a well), so no list of what can be is given one.
	return DeepOddities.carried(unit, true)

func _carried(unit: Dictionary) -> Array:
	## Every stone the player has to hand: the bag and the rail alike, riders included.
	return DeepOddities.carried(unit)

class Medallion extends Control:
	## A big mark in a ring of light that turns slowly: the face of an oddity or an ending.
	var glyph: String
	var tone: Color
	var _clock: float = 0.0
	func _init(mark: String, color: Color, edge: float = 120.0) -> void:
		glyph = mark
		tone = color
		## On the phone it stands beside the page's name, 30 points across (board run-room).
		if DeepUi.phone:
			edge = minf(edge, DeepUi.pt(30))
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _ready() -> void:
		if DeepUi.phone:
			_beside_title.call_deferred()
	func _beside_title() -> void:
		## On the phone a page's head is one row (docs/PHONE_UI.md): a medallion that heads a
		## column, with the page's title under it, stands beside the title instead.
		var column := get_parent() as VBoxContainer
		if column == null or get_index() != 0 or column.get_child_count() < 2:
			return
		var title := column.get_child(1) as Label
		if title == null:
			return
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(DeepUi.pt(8)))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		column.move_child(row, 0)
		column.remove_child(self)
		column.remove_child(title)
		row.add_child(self)
		row.add_child(title)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.42
		var glow: Texture2D = DeepUi.glow_texture()
		var pulse: float = 1.0 + 0.06 * sin(_clock * 2.0)
		var halo := Vector2(radius, radius) * 4.2 * pulse
		draw_texture_rect(glow, Rect2(centre - halo * 0.5, halo), false, Color(tone, 0.35))
		draw_circle(centre, radius, Color(tone.darkened(0.75), 0.95))
		draw_arc(centre, radius, 0, TAU, 64, Color(tone, 0.9), 2.5, true)
		for i in range(12):
			var angle: float = _clock * 0.25 + TAU * float(i) / 12.0
			var inner: Vector2 = centre + Vector2.from_angle(angle) * radius * 1.12
			var outer: Vector2 = centre + Vector2.from_angle(angle) * radius * (1.2 + 0.06 * float(i % 2))
			draw_line(inner, outer, Color(tone, 0.6), 2.0, true)
		var edge: float = radius * 1.15
		var bob: float = sin(_clock * 1.6) * 3.0
		draw_texture_rect(GemIcons.texture(glyph, 128), Rect2(centre - Vector2(edge, edge) * 0.5 + Vector2(0, bob), Vector2(edge, edge)), false, tone.lightened(0.35))

class StatChart extends Control:
	## The party compared: one row a stat, one thin bar a player, each row its own scale, the
	## leader's bar crowned and every bar's number beside it. A hovered delver's bars stay lit
	## while the others fade. `reveal` grows the bars in when the tab first opens.
	var rows: Array = []
	var seats: Array = []
	var highlight: String = "":
		set(value):
			highlight = value
			queue_redraw()
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()
	func _init(stat_rows: Array, party: Array) -> void:
		rows = stat_rows
		seats = party
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if rows.is_empty() or seats.is_empty():
			return
		var font: Font = DeepUi.text_face(12)
		var text_size: int = DeepUi.readable(12)
		var label_width: float = 118.0
		var value_width: float = 76.0
		var row_height: float = size.y / float(rows.size())
		var bar_height: float = clampf((row_height - 22.0) / float(seats.size()) - 3.0, 5.0, 11.0)
		var span: float = maxf(10.0, size.x - label_width - value_width)
		var crown: Texture2D = GemIcons.texture("crown", 64)
		for index in range(rows.size()):
			var row: Dictionary = rows[index]
			var top: float = row_height * float(index)
			draw_string(font, Vector2(0, top + 14.0), str(row.words), HORIZONTAL_ALIGNMENT_LEFT, label_width - 6.0, text_size, DeepUi.PAPER)
			var most: int = 0
			for seat in seats:
				most = maxi(most, int(row.values.get(str(seat.id), 0)))
			for j in range(seats.size()):
				var seat: Dictionary = seats[j]
				var value: int = int(row.values.get(str(seat.id), 0))
				var y: float = top + 20.0 + float(j) * (bar_height + 3.0)
				var width: float = (span * float(value) / float(maxi(1, most))) * reveal
				var lit: bool = highlight.is_empty() or highlight == str(seat.id)
				var tone: Color = seat.color
				if not lit:
					tone.a = 0.3
				draw_rect(Rect2(label_width, y, maxf(2.0, width), bar_height), tone)
				var words: String = DeepUi.number(value)
				var ink: Color = DeepUi.PAPER if lit else Color(DeepUi.MUTED, 0.5)
				draw_string(font, Vector2(label_width + width + 6.0, y + bar_height - 1.0), words, HORIZONTAL_ALIGNMENT_LEFT, value_width, text_size, ink)
				if str(row.get("leader", "")) == str(seat.id) and value > 0:
					var after: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
					draw_texture_rect(crown, Rect2(Vector2(label_width + width + 10.0 + after, y + bar_height * 0.5 - 6.0), Vector2(12, 12)), false, DeepUi.ACCENT_HI if lit else Color(DeepUi.ACCENT_HI, 0.4))
			if index < rows.size() - 1:
				draw_line(Vector2(0, top + row_height - 3.0), Vector2(size.x, top + row_height - 3.0), Color(DeepUi.LINE, 0.6), 1.0)

## Nothing in the mine is worked on through a list of names. A choice that wants one of your
## stones or one of your dice gives the dock over to those things themselves, drawn large
## where it stood, and the one to work on is clicked. A face, an inclusion, an engraving, a
## pattern or a measure of ore is a row of marks, clicked the same way. What each slot is set
## to is remembered by room and choice, so a page rebuilt under the pointer keeps it.

func _slot_key(choice_id: String, slot: String) -> String:
	return "%s|%s|%s" % [str(run.get("chamber", {}).get("oddity", "")), choice_id, slot]

func _remembered(key: String, options: Array, prefer_last: bool = false) -> String:
	## What this slot holds: what was chosen if it is still on offer, else one end of the row.
	var ids: Array = options.map(func(o: Variant) -> String: return str(o.id) if o is Dictionary else str(o))
	var held: String = str(_choice_picks.get(key, ""))
	if ids.has(held):
		return held
	if ids.is_empty():
		return ""
	return str(ids[ids.size() - 1]) if prefer_last else str(ids[0])

func _offer_pick(key: String, kind: String, items: Array, prompt: String) -> void:
	if items.is_empty() or _run_dock == null:
		return
	_choice_slot = key
	_run_dock.offer(kind, items, prompt)

func _on_dock_chose(id: String) -> void:
	if _choice_slot.is_empty():
		return
	if _choice_slot.begins_with("trade:"):
		var item_id: String = _choice_slot.trim_prefix("trade:")
		_choice_slot = ""
		_buy_die(item_id, id)
		return
	_choice_picks[_choice_slot] = id
	_choice_slot = ""
	show_state(run)

func _mark(control: Control, chosen: bool, tone: Color) -> void:
	## A thing in a row of things to click: lit when it is the one.
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if control is PanelContainer:
		(control as PanelContainer).add_theme_stylebox_override("panel", DeepUi.raised(Color(tone, 0.22) if chosen else Color(DeepUi.SLATE, 0.85),
			Color(tone, 0.95) if chosen else Color(DeepUi.LINE, 0.8), 10, 6, 0.3))
	DeepUi.juice(control, 1.06)

func _tool_chip(row: Node, icon: String, name: String, text: String, tone: Color) -> void:
	## What the room is set for tonight, said once above the dice: there is nothing to choose
	## here, so it is told rather than offered.
	var panel := DeepUi.panel(row, Color(tone, 0.12), Color(tone, 0.7), 8, 8)
	## It sits in the middle of the card it belongs to: a press on it is a press on the card.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = text
	var line := DeepUi.vbox(panel, 1)
	DeepUi.stat(line, icon, name, tone, 13)
	DeepUi.wrap(line, text, 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 210)

func _chip_row(parent: Node, key: String, entries: Array, tone: Color, builder: Callable, prefer_last: bool = false) -> String:
	## One row of things to click, one of them lit. `entries` are [id, payload] pairs; the
	## builder fills a panel for each. Returns the id that is chosen.
	var picked: String = _remembered(key, entries.map(func(e: Array) -> String: return str(e[0])), prefer_last)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	for entry in entries:
		var id: String = str(entry[0])
		var panel := PanelContainer.new()
		row.add_child(panel)
		_mark(panel, id == picked, tone)
		builder.call(panel, entry)
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_toggle", {"volume": 0.7})
				_choice_picks[key] = id
				show_state(run)
				panel.accept_event())
	return picked

func _work_refusal(action: Dictionary, item: Dictionary) -> String:
	## Why this die or this stone cannot take this piece of work, or "": the rules' own answer
	## (DeepOddities.work_refusal), against this player and what the room laid out tonight.
	return DeepOddities.work_refusal(action, item, me(), run.get("chamber", {}).get("offer", {}))

func _thing_row(parent: Node, choice_id: String, slot: String, kind: String, items: Array, label: String, action: Dictionary) -> String:
	## Everything the work could be done to, laid out at once and left there: the one picked
	## is lit, the ones it cannot be done to are greyed and will not answer. Nothing pops
	## open and nothing closes, so the choice can be changed as often as it likes.
	var key: String = _slot_key(choice_id, slot)
	var open: Array = items.filter(func(item: Dictionary) -> bool: return _work_refusal(action, item).is_empty())
	## Work that takes the stone away (sold, traded, thrown in, fed to the fire) is never
	## pointed at a set gem on its own: with nothing loose to sell, "Do it" sold the first gem
	## on the rail. A socketed stone goes only once it is clicked.
	if kind == "stone" and str(action.get("kind", "")) in ["collector_sell", "trade_up", "wishing_well", "fuse"] and not _choice_picks.has(key):
		var set_ids: Array = DeepStone.rail_stones(me()).map(func(s: Dictionary) -> String: return str(s.get("id", "")))
		open = open.filter(func(item: Dictionary) -> bool: return not set_ids.has(str(item.get("id", ""))))
	var picked: String = _remembered(key, open)
	if not label.is_empty():
		DeepUi.label(parent, label, 12, DeepUi.MUTED)
	if items.is_empty():
		DeepUi.stat(parent, "cross_out", "You carry nothing this could be done to.", DeepUi.DIM, 12)
		return ""
	## One line of them at a time. A heavy haul would otherwise run off the bottom of the
	## screen, and nothing in this game scrolls.
	var page_key: String = key + "#page"
	var pages: int = maxi(1, int(ceil(float(items.size()) / float(WORK_PAGE))))
	## The row opens on the page holding what is picked; after that the arrows own it, or
	## turning the page would only snap straight back to the pick.
	var page: int = clampi(int(_choice_picks.get(page_key, 0)), 0, pages - 1)
	if not _choice_picks.has(page_key):
		for at in range(items.size()):
			if str(items[at].get("id", "")) == picked:
				page = at / WORK_PAGE
	_choice_picks[page_key] = page
	var line := DeepUi.hbox(parent, 6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	if pages > 1:
		var back := DeepUi.icon_button(line, "prev", "", func() -> void:
			_choice_picks[page_key] = posmod(page - 1, pages)
			show_state(run), 14, DeepUi.MUTED)
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := DeepUi.hbox(line, 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for item in items.slice(page * WORK_PAGE, mini((page + 1) * WORK_PAGE, items.size())):
		var id: String = str(item.get("id", ""))
		var refusal: String = _work_refusal(action, item)
		var chosen: bool = id == picked and refusal.is_empty()
		var card := PanelContainer.new()
		row.add_child(card)
		_mark(card, chosen, DeepUi.ACCENT)
		var named: String = DeepDice.describe(item) if kind == "die" else DeepUi.stone_name(item)
		card.tooltip_text = named if refusal.is_empty() else "%s — %s" % [named, refusal]
		if not refusal.is_empty():
			card.modulate = Color(0.55, 0.55, 0.6, 0.55)
			card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		var box := DeepUi.vbox(card, 3)
		var frame := DeepUi.center(box)
		frame.custom_minimum_size = Vector2(62, 62)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "die":
			var picture := Thumbs.DieThumb.new(item, 56)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(picture)
		else:
			StoneCard.marked_picture(frame, item, 56, "", false)
		DeepUi.fit_label(box, named if kind == "die" else DeepUi.skill_name(item), 11, DeepUi.PAPER if refusal.is_empty() else DeepUi.DIM, 104)
		if refusal.is_empty():
			var look_close := func() -> void:
				if kind == "die":
					Inspector.die(item)
				else:
					Inspector.stone(item)
			card.gui_input.connect(func(event: InputEvent) -> void:
				if not (event is InputEventMouseButton and event.pressed):
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					look_close.call()
					card.accept_event()
				elif event.button_index == MOUSE_BUTTON_LEFT:
					DeepAudio.play("ui_toggle", {"volume": 0.7})
					_choice_picks[key] = id
					show_state(run)
					card.accept_event())
			Tips.hold(card, look_close)
			## A die or a stone dragged off the dock lands here as well.
			var wanted: String = "die_id" if kind == "die" else "stone_id"
			card.set_drag_forwarding(Callable(), func(_at: Vector2, data: Variant) -> bool:
				return data is Dictionary and str(data.get("kind", "")) == kind and str(data.get(wanted, "")) == id,
				func(_at: Vector2, _data: Variant) -> void:
					DeepAudio.play("ui_confirm", {"volume": 0.7})
					_choice_picks[key] = id
					show_state(run))
	if pages > 1:
		var on := DeepUi.icon_button(line, "next", "", func() -> void:
			_choice_picks[page_key] = posmod(page + 1, pages)
			show_state(run), 14, DeepUi.MUTED)
		on.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		DeepUi.label(parent, "%d of %d" % [page + 1, pages], 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	return picked

func _face_slot(parent: Node, choice_id: String, slot: String, die: Dictionary, label: String, blanks: bool, lowering: bool = false) -> int:
	## One of a die's faces, chosen by clicking the face itself rather than reading its number
	## off a list — the same row of faces the close look draws. Lowering, a 1 (or a blank) is
	## left out: it cannot come down, and offering it (first, as the pick) only got it refused.
	var faces: Array = die.get("faces", [])
	var entries: Array = []
	for index in range(faces.size()):
		var kind: String = str(faces[index].get("kind", "plain"))
		if lowering and (kind == "blank" or int(faces[index].get("value", 0)) <= 1):
			continue
		if blanks or kind != "blank":
			entries.append([str(index), faces[index]])
	if entries.is_empty():
		return -1
	if not label.is_empty():
		DeepUi.label(parent, label, 12, DeepUi.MUTED)
	var tone: Color = DiceIcons.die_palette(die).body
	var picked: String = _chip_row(parent, _slot_key(choice_id, slot), entries, tone, func(panel: PanelContainer, entry: Array) -> void:
		var face: Dictionary = entry[1]
		var holder := DeepUi.center(panel)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var drawn: Control = DiceIcons.face(34.0, int(face.get("value", 0)), tone, str(die.get("shape", "D6")), false,
			DiceIcons.face_text(int(face.get("value", 0)), str(face.get("kind", "plain"))))
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(drawn))
	return int(picked)

func _picker(box: VBoxContainer, needs: String, unit: Dictionary, choice_id: String, action: Dictionary = {}) -> Callable:
	## The controls a choice needs, and a callable that reads them into a payload.
	if needs.is_empty():
		return func() -> Dictionary: return {}
	var stones: Array = _loose(unit)
	stones.append_array(DeepStone.rail_stones(unit))
	var dice: Array = unit.get("dice", [])
	var row := DeepUi.vbox(box, 6)
	match needs:
		"stone":
			var id: String = _thing_row(row, choice_id, "stone", "stone", stones, "Which stone?", action)
			return func() -> Dictionary: return {} if id.is_empty() else {"stone_id": id}
		"raw_stone":
			## Only what the work is for: a lens is shown rough stones and nothing else.
			var raw: Array = _loose(unit).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			var id: String = _thing_row(row, choice_id, "stone", "stone", raw, "Which raw stone?", action)
			return func() -> Dictionary: return {} if id.is_empty() else {"stone_id": id}
		"two_stones":
			## Two stones and no say in which comes out: the fire decides that.
			var keep_id: String = _thing_row(row, choice_id, "keep", "stone", stones, "First stone", action)
			var feed_id: String = _thing_row(row, choice_id, "feed", "stone", stones.filter(func(s: Dictionary) -> bool: return str(s.get("id", "")) != keep_id), "Second stone", action)
			return func() -> Dictionary: return {} if keep_id.is_empty() or feed_id.is_empty() or keep_id == feed_id else {"keep_id": keep_id, "feed_id": feed_id}
		"gem_and_die":
			## The Hollow: a read gem to come away Void, the rail's first since freeing a socket
			## is the point, and one of the five dice to pay for it.
			var gems: Array = DeepStone.rail_stones(unit) + _loose(unit).filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)))
			var gem_id: String = _thing_row(row, choice_id, "gem", "stone", gems, "Which gem turns Void?", action)
			var die_id: String = _thing_row(row, choice_id, "die", "die", dice, "Which die goes in?", action)
			return func() -> Dictionary: return {} if gem_id.is_empty() or die_id.is_empty() else {"stone_id": gem_id, "die_id": die_id}
		"raw_stones":
			## The acid bath: up to three raw stones set in the racks, each clicked on and off.
			var raw: Array = _loose(unit).filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
			var most: int = maxi(1, int(action.get("most", 3)))
			var set_ids: Array = _racks(row, choice_id, raw, most, int(action.get("hp", 6)))
			return func() -> Dictionary: return {} if set_ids.is_empty() else {"stone_ids": set_ids}
		"offer":
			## Nothing to choose: the case holds one stone and the card shows it and its price.
			var offer: Dictionary = run.get("chamber", {}).get("offer", {})
			var held: Dictionary = offer.get("stone", {})
			if held.is_empty():
				DeepUi.stat(row, "cross_out", "her case is empty", DeepUi.DIM, 12)
				return func() -> Dictionary: return {}
			var case_row := DeepUi.hbox(row, 14)
			case_row.alignment = BoxContainer.ALIGNMENT_CENTER
			StoneCard.marked_picture(case_row, held, 72)
			var words := DeepUi.vbox(case_row, 4)
			words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			DeepUi.title(words, DeepUi.skill_name(held), 18, DeepUi.tier_color(str(DeepStone.grade(held).tier)))
			DeepUi.wrap(words, DeepStone.text(held), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 320)
			var purse: int = int(unit.get("ore", 0))
			var price: int = int(offer.get("price", 0))
			DeepUi.stat(words, "ore", "%d pyrite · you carry %d" % [price, purse], DeepUi.ORE if purse >= price else DeepUi.BAD, 13)
			case_row.mouse_filter = Control.MOUSE_FILTER_PASS
			case_row.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					Inspector.stone(held)
					case_row.accept_event())
			Tips.hold(case_row, func() -> void: Inspector.stone(held))
			return func() -> Dictionary: return {} if purse < price else {"buy": true}
		"inclusion":
			var carriers: Array = stones.filter(func(s: Dictionary) -> bool: return not s.get("inclusions", []).is_empty() and (bool(s.get("appraised", false)) or bool(s.get("inclusions_revealed", false))))
			var from_id: String = _thing_row(row, choice_id, "from", "stone", carriers, "Which stone?", action)
			var carrier: Dictionary = DeepOddities.find_stone(unit, from_id)
			var keys: Array = carrier.get("inclusions", []).map(func(k: Variant) -> Array: return [str(k), str(k)])
			var which: String = ""
			if not keys.is_empty():
				which = _chip_row(row, _slot_key(choice_id, "inclusion"), keys, DeepUi.INFO, func(panel: PanelContainer, entry: Array) -> void:
					var inclusion: Dictionary = DeepContent.inclusion(str(entry[0]))
					panel.tooltip_text = str(inclusion.get("text", ""))
					DeepUi.stat(panel, "spark", str(inclusion.get("name", entry[0])), DeepUi.INFO, 12))
			return func() -> Dictionary: return {} if from_id.is_empty() or which.is_empty() else {"stone_id": from_id, "inclusion": which}
		"die", "die_face":
			## What the room is set for tonight is shown before the die is chosen: the anvil
			## has one pattern in it, the needles one etching, the vat one material, and a
			## blind dip has none of them until the die is already in.
			var tonight: Dictionary = run.get("chamber", {}).get("offer", {})
			var kind: String = str(action.get("kind", ""))
			_tonight_chip(row, action)
			var offered: Array = dice
			if kind == "pattern" and not str(tonight.get("pattern", "")).is_empty():
				## Only the dice the anvil could actually stamp tonight.
				offered = dice.filter(func(d: Dictionary) -> bool: return DeepDice.pattern_allows(str(tonight.pattern), str(d.get("shape", "D6"))))
			var die_id: String = _thing_row(row, choice_id, "die", "die", offered, "Which die?", action)
			var die: Dictionary = DeepOddities.find_die(unit, die_id)
			if needs == "die":
				return func() -> Dictionary: return {} if die_id.is_empty() else {"die_id": die_id}
			var face: int = _face_slot(row, choice_id, "face", die, "Which face?", true, kind == "lower_face")
			return func() -> Dictionary: return {} if die_id.is_empty() or face < 0 else {"die_id": die_id, "face": face}
		"pattern":
			## Three patterns, and they are your own: the shrine only offers what your gems
			## already fire on, so praying at it is a choice between things you hold rather
			## than a list of every pattern in the game. Each is a card saying what it asks
			## for; under the three, the gems the lit one would pay for. Pointing at another
			## card shows its gems there instead, and only that shelf is redrawn: rebuilding
			## the page under the pointer took the card away before a click could land on it.
			var kinds: Array = _shrine_patterns(unit)
			var key: String = _slot_key(choice_id, "pattern")
			var pattern: String = _remembered(key, kinds)
			DeepUi.label(row, "Which pattern?", 12, DeepUi.MUTED)
			var cards := DeepUi.hbox(row, 10)
			cards.alignment = BoxContainer.ALIGNMENT_CENTER
			var shelf := DeepUi.hbox(row, 8)
			shelf.alignment = BoxContainer.ALIGNMENT_CENTER
			shelf.custom_minimum_size.y = 48
			var fill_shelf := func(kind: String) -> void:
				if not is_instance_valid(shelf) or shelf.is_queued_for_deletion():
					return
				DeepUi.clear(shelf)
				var gems: Array = _fire_on(unit, kind)
				var named: String = str(SHRINE_WORDS.get(kind, [kind.replace("_", " ").capitalize()])[0])
				if gems.is_empty():
					DeepUi.stat(shelf, "cross_out", "Nothing you carry fires on %s." % named, DeepUi.DIM, 12)
					return
				DeepUi.label(shelf, "%s: these gain a carat" % named, 12, DeepUi.MUTED)
				for gem in gems.slice(0, 6):
					var tile := StoneCard.mini(shelf, gem, 44)
					if tile is Control:
						(tile as Control).tooltip_text = DeepUi.stone_name(gem)
				if gems.size() > 6:
					DeepUi.label(shelf, "+%d" % (gems.size() - 6), 12, DeepUi.MUTED)
			for kind in kinds:
				var option: String = str(kind)
				var said: Array = SHRINE_WORDS.get(option, [option.replace("_", " ").capitalize(), str(DeepPatterns.describe({"kind": option}, 0).get("words", ""))])
				var panel := PanelContainer.new()
				panel.custom_minimum_size = Vector2(200, 0)
				cards.add_child(panel)
				_mark(panel, option == pattern, DeepUi.INFO)
				var box_in := DeepUi.vbox(panel, 4)
				box_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var head := DeepUi.hbox(box_in, 8)
				head.mouse_filter = Control.MOUSE_FILTER_IGNORE
				DeepUi.icon(head, DiceIcons.glyph_for({"kind": option}), 26, DeepUi.INFO).mouse_filter = Control.MOUSE_FILTER_IGNORE
				var words := DeepUi.vbox(head, 0)
				words.mouse_filter = Control.MOUSE_FILTER_IGNORE
				DeepUi.label(words, str(said[0]), 15, DeepUi.PAPER)
				var count: int = _fire_on(unit, option).size()
				DeepUi.label(words, "%s of yours" % DeepUi.plural(count, "gem"), 11, DeepUi.GOOD if count > 0 else DeepUi.DIM)
				DeepUi.wrap(box_in, str(said[1]), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 180)
				if option == pattern:
					DeepUi.stat(box_in, "check", "Chosen", DeepUi.INFO, 11)
				panel.mouse_entered.connect(func() -> void: fill_shelf.call(option))
				panel.mouse_exited.connect(func() -> void: fill_shelf.call(pattern))
				panel.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						panel.accept_event()
						if option == pattern:
							return
						DeepAudio.play("ui_toggle", {"volume": 0.7})
						_choice_picks[key] = option
						show_state(run))
			fill_shelf.call(pattern)
			return func() -> Dictionary: return {} if pattern.is_empty() else {"pattern": pattern}
		"ore":
			## How much goes down the well: anything from the least it takes to the most it takes,
			## or to all you carry. The amount set is remembered by room and choice, so a page
			## rebuilt under the pointer keeps it; dragging never rebuilds the page.
			var carried: int = int(unit.get("ore", 0))
			var most: int = mini(carried, DeepDescent.WISH_MOST)
			if most < DeepDescent.WISH_LEAST:
				DeepUi.stat(row, "ore", "you carry %d pyrite: the well wants %d at least" % [carried, DeepDescent.WISH_LEAST], DeepUi.DIM, 12)
				return func() -> Dictionary: return {}
			var key: String = _slot_key(choice_id, "ore")
			var held: int = clampi(int(str(_choice_picks.get(key, str(DeepDescent.WISH_LEAST)))), DeepDescent.WISH_LEAST, most)
			## The least and the most at either end, so it reads as a range to drag along.
			DeepUi.label(row, str(DeepDescent.WISH_LEAST), 12, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var slider := HSlider.new()
			slider.min_value = DeepDescent.WISH_LEAST
			slider.max_value = most
			slider.step = 1
			slider.value = held
			slider.custom_minimum_size = Vector2(220, 26)
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slider.tooltip_text = "Drag to choose how much goes down: anything from %d to %d pyrite." % [DeepDescent.WISH_LEAST, most]
			row.add_child(slider)
			DeepUi.label(row, str(most), 12, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var readout := DeepUi.label(row, "%d pyrite" % held, 14, DeepUi.ORE)
			readout.custom_minimum_size.x = 84
			slider.value_changed.connect(func(value: float) -> void:
				_choice_picks[key] = str(int(value))
				readout.text = "%d pyrite" % int(value))
			var top := DeepUi.icon_button(row, "rise", "Max", func() -> void: slider.value = most, 12, DeepUi.ORE)
			top.tooltip_text = "All the well takes: %d pyrite." % most if most == DeepDescent.WISH_MOST else "All you carry: %d pyrite." % most
			return func() -> Dictionary: return {"ore": int(slider.value)} if is_instance_valid(slider) else {}
	return func() -> Dictionary: return {}

# --- landing ---------------------------------------------------------------------------------
##
## A landing is a lift and a moment's rest. Each player first takes one respite (rest,
## appraise or polish); then the lift asks the only question it has: up, or down.

# --- hoard, salvage, over ---------------------------------------------------------------------

func _page_salvage(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var head := DeepUi.vbox(content, 4)
	var title_row := DeepUi.hbox(head, 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(title_row, "skull", 32, DeepUi.BAD)
	var abandoned: bool = bool(run.get("abandoned", false))
	## Alone down there it is you who falls or flees; only a party is spoken of as one.
	var party: bool = run.get("players", []).size() > 1
	var headline: String = ("The dig is abandoned" if party else "You abandon the dig") if abandoned else ("The party falls" if party else "You fall")
	DeepUi.title(title_row, headline, 34, DeepUi.BAD)
	var fled: String = ("The party flees to the lift and drops some stones on the way. " if party else "You flee to the lift and drop some stones on the way. ") if abandoned else ""
	DeepUi.wrap(head, fled + "Every raw stone rolls a die by its grade. Only the top face brings it home. Set stones are safe.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 480)
	_enter(head)
	var rolls: Array = run.get("salvage", {}).get(local_id, {}).get("rolls", [])
	var turn := DeepUi.hbox(content, 8)
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	var list := DeepUi.vbox(content, 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var index: int = 0
	var shown: Array = _paged(turn, "salvage", rolls, SALVAGE_PAGE)
	## Each page's dice are rolled the first time it is turned to, and shown landed after.
	var page: int = int(_pages.get("salvage", 0))
	var rolling: bool = not _salvage_rolled.has(page) and not _headless
	_salvage_rolled[page] = true
	for roll in shown:
		var kept: bool = bool(roll.kept)
		var card := DeepUi.card(list, Color(DeepUi.GOOD if kept else DeepUi.BAD, 0.55), 12)
		card.custom_minimum_size = Vector2(480, 0)
		var row := DeepUi.hbox(card, 14)
		StoneCard.marked_picture(row, roll.stone, 56)
		var box := DeepUi.vbox(row, 2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		## A long name is cut short rather than widening the page past the room's edge. Every
		## stone here is raw, and "Tiny raw" three times over would not say which one was the
		## hoard's opal: the size and the color are named, as everywhere else a raw stone is.
		var named := DeepUi.title(box, DeepUi.stone_name(roll.stone), 17, DeepUi.tier_color(str(roll.tier)))
		named.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		named.tooltip_text = DeepUi.stone_name(roll.stone)
		named.mouse_filter = Control.MOUSE_FILTER_PASS
		if bool(roll.get("insured", false)):
			var insured_line := DeepUi.label(box, "A d%d, insured: %d and %d" % [int(roll.sides), int(roll.first), int(roll.get("second", roll.roll))], 12, DeepUi.GOOD.darkened(0.1))
			insured_line.tooltip_text = "Insured: the d%d was thrown twice, needing a %d, and the better throw kept." % [int(roll.sides), int(roll.sides)]
			insured_line.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			DeepUi.label(box, "A d%d, needing a %d" % [int(roll.sides), int(roll.sides)], 12, DeepUi.MUTED)
		var die := SalvageDie.new(int(roll.sides), int(roll.roll), kept, 0.35 + 0.45 * float(index) if rolling else -1.0)
		row.add_child(die)
		var verdict := DeepUi.stat(row, "check" if kept else "split_shield", "kept" if kept else "shattered", DeepUi.GOOD if kept else DeepUi.BAD, 15)
		verdict.custom_minimum_size.x = 110
		die.verdict = verdict
		if rolling:
			DeepUi.pop_in(card, 0.1 + 0.45 * index)
		index += 1
	if index == 0:
		DeepUi.label(content, "You carried no raw stones. Nothing to lose.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	elif rolls.size() > SALVAGE_PAGE:
		var saved: int = rolls.filter(func(r: Dictionary) -> bool: return bool(r.kept)).size()
		DeepUi.stat(turn, "check", "%d of %d kept" % [saved, rolls.size()], DeepUi.GOOD if saved > 0 else DeepUi.MUTED, 13)
	var button := _main(DeepUi.primary(content, "ladder", "Climb out", func() -> void: command.emit({"kind": "ready"}), 17, DeepUi.ACCENT))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.disabled = bool(unit.get("ready", false))

class SalvageDie extends Control:
	## One salvage roll: the die tumbles through faces, then lands and says what it says.
	var sides: int
	var result: int
	var kept: bool
	var _t: float = 0.0
	var _delay: float = 0.0
	var _shown: int = 1
	var _tick: float = 0.0
	## Shown only once the die has landed, so the answer is never read before it is rolled.
	var verdict: Control = null:
		set(node):
			verdict = node
			if verdict != null and _t < _delay + 0.9:
				verdict.modulate.a = 0.0
	func _init(die_sides: int, rolled: int, survives: bool, delay: float) -> void:
		sides = die_sides
		result = rolled
		kept = survives
		_delay = delay
		custom_minimum_size = Vector2(58, 58)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if delay < 0.0:
			_t = 99.0
		_shown = result if delay < 0.0 else 1
	func _process(delta: float) -> void:
		_t += delta
		if _t < _delay + 0.9:
			_tick += delta
			if _t > _delay and _tick > 0.07:
				_tick = 0.0
				_shown = randi_range(1, sides)
			queue_redraw()
		elif _shown != result or (verdict != null and verdict.modulate.a < 1.0):
			_shown = result
			DeepAudio.from(self, "salvage_save" if kept else "salvage_lose", {"gap": 0.0})
			DeepUi.pulse(self, 1.3, 0.35)
			DeepUi.burst(self, size * 0.5, DeepUi.GOOD if kept else DeepUi.BAD, 18 if not kept else 40, 120.0 if not kept else 200.0, 0.5)
			if verdict != null:
				verdict.modulate.a = 1.0
				DeepUi.pulse(verdict, 1.25, 0.4)
			queue_redraw()
		else:
			set_process(false)
	func _draw() -> void:
		var landed: bool = _t >= _delay + 0.9
		var tone: Color = (DeepUi.GOOD if kept else DeepUi.BAD) if landed else DeepUi.PAPER
		var spin: float = 0.0 if landed else sin(_t * 30.0) * 0.3
		draw_set_transform(size * 0.5, spin, Vector2.ONE)
		var r: float = size.x * 0.44
		var poly := PackedVector2Array()
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + PI / 6.0
			poly.append(Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(poly, Color(tone, 0.2))
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, tone, 2.0, true)
		var text: String = str(_shown)
		var font: Font = DeepUi.display_font()
		var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, Vector2(-measured.x * 0.5, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tone)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _hazard_words(tier: int) -> String:
	## Every hazard the run carries, one to a line, for a hover.
	var lines: Array = ["Hazard %d" % tier]
	for index in range(1, tier + 1):
		var entry: Dictionary = DeepContent.hazard_tier(index)
		lines.append("%s: %s" % [str(entry.get("name", "")), str(entry.get("text", ""))])
	return "\n".join(lines)

# --- the day's seam --------------------------------------------------------------------------

const DAILY_KIND_WORDS: Dictionary = {"rail": "Rail rule", "hazard": "Hazard", "blessing": "Blessing", "twist": "Twist"}

func _daily_tone(kind: String) -> Color:
	match kind:
		"hazard": return DeepUi.BAD
		"blessing": return DeepUi.GOOD
		"twist": return _stake_tone("terms")
	return DeepUi.INFO

func _daily_cards() -> Array:
	## The day's cards in the order they are dealt: the rail rule, then the hazard, blessing
	## and twist, each as {key, name, text, glyph, kind, tone}.
	var daily: Dictionary = run.get("daily", {})
	var keys: Array = []
	if not str(daily.get("rail", "")).is_empty():
		keys.append(str(daily.rail))
	keys.append_array(daily.get("mods", []))
	var out: Array = []
	for key in keys:
		var mod: Dictionary = DeepContent.entry("daily_modifiers", str(key))
		var kind: String = str(mod.get("kind", "hazard"))
		var name: String = str(mod.get("name", key))
		if str(key) == "DROUGHT" and daily.has("drought"):
			name = "%s: no %s" % [name, str(DeepContent.color(str(daily.drought)).get("name", daily.drought))]
		if str(key) == "BORROWED_BIRTHSTONE" and daily.has("birthstone"):
			## Whose stone, and which of their three: "Borrowed Birthstone: Florin's Blackjack".
			name = "%s: %s's %s" % [name, DeepContent.character_title(str(daily.birthstone)).get_slice(",", 0),
				str(DeepStone.birthstone(str(daily.birthstone), str(daily.get("birthstone_key", ""))).get("name", "Birthstone"))]
		out.append({"key": str(key), "name": name, "text": str(mod.get("text", "")), "glyph": str(mod.get("glyph", "spark")), "kind": kind,
			"tone": _daily_tone(kind), "kind_word": str(DAILY_KIND_WORDS.get(kind, ""))})
	return out

func _daily_standing() -> String:
	## Where this player stands today, in a line.
	if not bool(daily_best.get("eligible", true)):
		return "Beat the Quarry to be paid for the daily dig."
	if int(daily_best.get("best_score", 0)) > 0:
		return "Your best today is %d. This run pays only what it adds to that." % int(daily_best.best_score)
	return "Your first dig today."

func _daily_marks(parent: Node) -> void:
	## On the strip: the day's mark, and its cards as their own marks, each saying itself on hover.
	var marks := DeepUi.hbox(parent, 4)
	marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.icon(marks, "calendar", 18, DeepUi.ACCENT, "Today's seam\nYour score is the worth of the stones you bring up plus the pyrite you carry.\n" + _daily_standing())
	for card in _daily_cards():
		DeepUi.icon(marks, str(card.glyph), 15, card.tone, "%s · %s\n%s" % [str(card.name), str(card.kind_word), str(card.text)])

func _daily_banner(parent: Node) -> Control:
	## At the shaft head: the day's seam, its four cards, and the score to beat.
	var card := DeepUi.card(parent, Color(DeepUi.ACCENT, 0.4), 12, Color(0.06, 0.055, 0.04, 0.9))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := DeepUi.vbox(card, 8)
	var head := DeepUi.hbox(box, 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(head, "calendar", 22, DeepUi.ACCENT)
	DeepUi.title(head, "Today's seam", 18, DeepUi.PAPER)
	var best: int = int(daily_best.get("best_score", 0))
	var standing: String = ("Best today: %d" % best) if best > 0 else "First dig today"
	if not bool(daily_best.get("eligible", true)):
		standing = "Not paid yet"
	DeepUi.pill(head, "star", standing, DeepUi.ACCENT if bool(daily_best.get("eligible", true)) else DeepUi.MUTED, 12, _daily_standing())
	var cards := DeepUi.hbox(box, 8)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in _daily_cards():
		DeepUi.pill(cards, str(entry.glyph), str(entry.name), entry.tone, 13, "%s\n%s" % [str(entry.kind_word), str(entry.text)])
	DeepUi.label(box, "Your score is the worth of the stones you bring up plus the pyrite you carry. Nothing is kept.", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	return card

func _daily_result() -> Dictionary:
	## This player's score for the run as it ended, and what it pays.
	var unit: Dictionary = me()
	var result: Dictionary = {"outcome": str(run.get("outcome", "")), "players": {local_id: {"home": DeepDescent.coming_home(run, unit), "ore": int(unit.get("ore", 0))}}}
	var scored: Dictionary = DeepEconomy.daily_score(result, local_id)
	var gold: int = DeepEconomy.daily_gold(int(scored.score), DeepDescent.hazard_tier(run))
	var eligible: bool = bool(daily_best.get("eligible", true))
	scored.gold = gold
	scored.paid = maxi(0, gold - int(daily_best.get("best_gold", 0))) if eligible else 0
	return scored

func _daily_strip(parent: Node) -> void:
	## At the lift: what came up, as a score, and the gold it pays, counted out.
	var scored: Dictionary = _daily_result()
	var strip := DeepUi.card(parent, Color(DeepUi.ACCENT, 0.4), 10, Color(0.06, 0.055, 0.04, 0.9))
	var lines := DeepUi.vbox(strip, 4)
	var row := DeepUi.hbox(lines, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(row, "calendar", 26, DeepUi.ACCENT)
	DeepUi.title(row, "Today's seam", 18, DeepUi.PAPER)
	DeepUi.gap(row, 6)
	DeepUi.stat(row, "gem", "%d" % int(scored.worth), DeepUi.PAPER, 16, "The worth of the %s you brought up" % DeepUi.plural(scored.stones.size(), "stone"))
	DeepUi.label(row, "+", 16, DeepUi.MUTED)
	## Said for who it was: alone, "you"; and an abandoned dig is not a fall.
	var party: bool = run.get("players", []).size() > 1
	var abandoned: bool = bool(run.get("abandoned", false))
	DeepUi.stat(row, "ore", "%d" % int(scored.pyrite), DeepUi.ORE, 16, "The pyrite you carried up" if not bool(scored.fell) else "%s carries no pyrite up" % ("An abandoned dig" if abandoned else "A fall"))
	DeepUi.label(row, "=", 16, DeepUi.MUTED)
	## The figures in bold Barlow, as the run's end has them: the title face draws a 0 as a bar.
	var score_label := DeepUi.title(row, "%d" % int(scored.score), 22, DeepUi.PAPER)
	score_label.tooltip_text = "Your score"
	score_label.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.icon(row, "next", 18, DeepUi.MUTED)
	var coin := DeepUi.icon(row, "coin", 24, DeepUi.ACCENT)
	var paid: int = int(scored.paid)
	var gold_label := DeepUi.title(row, "%d gold" % paid, 22, DeepUi.ACCENT_HI if paid > 0 else DeepUi.DIM)
	gold_label.add_theme_font_override("font", DeepUi.bold_font())
	gold_label.custom_minimum_size.x = 96
	var note: String = "A score of %d is worth %d gold." % [int(scored.score), int(scored.gold)]
	if bool(scored.fell):
		var who: String = ("The dig was abandoned" if party else "You abandoned the dig") if abandoned else ("The party fell" if party else "You fell")
		note = who + ": only the stones the salvage dice saved count. " + note
	if not bool(daily_best.get("eligible", true)):
		note += " Beat the Quarry to be paid for the daily dig."
	elif int(daily_best.get("best_gold", 0)) > 0:
		note += (" Your best today paid %d, so this run pays the difference." if paid > 0 else " Your best today paid %d, so this run adds nothing.") % int(daily_best.best_gold)
	var said := DeepUi.label(lines, note, 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	## The phone's card is narrower than the note: it wraps.
	if DeepUi.phone:
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size.x = DeepUi.pt(400)
	if _fresh and not _headless and paid > 0:
		gold_label.text = "0 gold"
		var tween := gold_label.create_tween()
		tween.tween_interval(0.7)
		tween.tween_callback(func() -> void: DeepAudio.play("ore", {"volume": 0.8}))
		tween.tween_method(func(v: float) -> void: gold_label.text = "%d gold" % int(round(v)), 0.0, float(paid), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void:
			DeepAudio.play("buy", {"volume": 0.7})
			DeepUi.pulse(gold_label, 1.3, 0.4)
			if is_instance_valid(coin) and coin.is_inside_tree():
				DeepUi.burst(self, coin.global_position + coin.size * 0.5 - global_position, DeepUi.ACCENT_HI, 30, 220.0, 0.8, 6.0))

# --- the end of the run --------------------------------------------------------------------------
##
## The run ends on tabs over the room. Your run is the tally: six totals with what each one
## cost (overkill, damage blocked, overhealing, pyrite spent), the run's highlights, the Crown
## Jewel (the stone on the rail that did the most) and the way down. Party, in a party of two
## or more, is everyone side by side, the stat each one led crowned, the MVP crowned on their
## portrait, and the party compared on one chart. Haul is the lift card as it was: the stones
## coming home and the way to the workshop. A tab's numbers count up the first time it is
## seen; the music plays once, on the first tab.

const OVER_TABS: Array = [["run", "person", "Your run"], ["party", "party", "Party"], ["haul", "bag", "Haul"]]
const HAND_WORDS: Dictionary = {"quint": "Five of a kind", "quad": "Four of a kind", "straight": "A straight", "full_house": "A full house",
	"triple": "Three of a kind", "two_pair": "Two pair", "pair": "A pair", "distinct": "All different", "nothing": "Nothing"}
## The order hands rank in, best first, for the one a run is remembered by.
const HAND_RANK: Array = ["quint", "quad", "straight", "full_house", "triple", "two_pair", "pair", "distinct", "nothing"]
## A color a seat, for the party's chart (checked apart under every kind of color vision).
const PARTY_TONES: Array = [Color("3a7fd9"), Color("b9871a"), Color("1f9e78"), Color("d4574c")]
## Points: what a gem or a player did, weighed together. Damage, block and healing as they
## are, a debuff stack worth three, a pyrite worth two; a player's revive fifty, a kill ten.
const POINT_WEIGHTS: Dictionary = {"damage": 1, "block": 1, "healed": 1, "debuffs": 3, "ore": 2, "revives": 50, "slain": 10}

var _over_tab: String = "run"
var _over_seen: Dictionary = {}

func _over_tone() -> Color:
	var outcome: String = str(run.get("outcome", ""))
	return DeepUi.BAD if outcome == "fallen" else (DeepUi.ACCENT if outcome == "conquered" else DeepUi.GOOD)

func _show_over_tab(tab: String) -> void:
	_over_tab = tab
	show_state(run)

func _page_over(content: VBoxContainer) -> void:
	var party: bool = run.get("players", []).size() > 1
	if _over_tab == "party" and not party:
		_over_tab = "run"
	if _over_seen.is_empty():
		DeepAudio.play("defeat" if str(run.get("outcome", "")) == "fallen" else "victory")
	var animate: bool = not _over_seen.has(_over_tab) and not _headless
	_over_seen[_over_tab] = true
	var tabs := DeepUi.hbox(content, 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in OVER_TABS:
		if str(entry[0]) == "party" and not party:
			continue
		DeepUi.tab_button(tabs, str(entry[1]), str(entry[2]), _over_tab == str(entry[0]), _show_over_tab.bind(str(entry[0])), 15)
	match _over_tab:
		"party":
			_page_over_party(content, animate)
		"haul":
			_page_over_haul(content)
		_:
			_page_over_run(content, animate)

static func tally_of(unit: Dictionary) -> Dictionary:
	## A player's tally, whole, without writing to the run: a run begun before the tally was
	## kept has only part of it.
	var out: Dictionary = DeepBattle.fresh_stats()
	out.merge(unit.get("stats", {}), true)
	return out

static func stat_value(stats: Dictionary, key: String) -> int:
	## One compared number out of a tally: a total, the sum of a dictionary, or a best's amount.
	var value: Variant = stats.get(key, 0)
	if value is Dictionary:
		if value.has("amount"):
			return int(value.amount)
		var sum: int = 0
		for kind in value:
			sum = DeepRules.sat_add(sum, int(value[kind]))
		return sum
	return int(value)

static func points_of(stats: Dictionary, player: bool) -> int:
	## What a gem's tally (or a player's) is worth as one number (see POINT_WEIGHTS).
	var total: int = 0
	for key in POINT_WEIGHTS:
		if not player and key in ["revives", "slain"]:
			continue
		total = DeepRules.sat_add(total, DeepRules.sat_mul(stat_value(stats, str(key)), int(POINT_WEIGHTS[key])))
	return total

static func top_kind(counts: Dictionary) -> Array:
	## The biggest entry of a dictionary of counts: [kind, count], or [] for none.
	var best: Array = []
	for kind in counts:
		if best.is_empty() or int(counts[kind]) > int(best[1]):
			best = [str(kind), int(counts[kind])]
	return best

static func status_words(kind: String) -> String:
	return kind.replace("_", " ").capitalize()

func _best_hand(stats: Dictionary) -> Array:
	## The best hand the run rolled and how often: [words, times], or [] for none.
	var hands: Dictionary = stats.get("hands", {})
	for kind in HAND_RANK:
		if int(hands.get(kind, 0)) > 0:
			return [str(HAND_WORDS.get(kind, kind)), int(hands[kind])]
	return []

func _crown_jewel(unit: Dictionary, stats: Dictionary) -> Dictionary:
	## The stone on the rail at the end that did the most, by points: {stone, tally, points},
	## or nothing when no gem on it fired. The run's end takes fragile stones off the rail
	## (shattered, or a temporary one handed back), so those are looked at too.
	var gems: Dictionary = stats.get("gems", {})
	var best: Dictionary = {}
	for stone in DeepStone.rail_stones(unit) + unit.get("riders", []) + unit.get("shattered", []) + unit.get("handed_back", []):
		if not stone is Dictionary or DeepStone.is_birthstone(stone):
			continue
		var tally: Dictionary = gems.get(str(stone.get("id", "")), {})
		if tally.is_empty() or int(tally.get("fires", 0)) <= 0:
			continue
		var points: int = points_of(tally, false)
		if best.is_empty() or points > int(best.points) or (points == int(best.points) and int(tally.get("fires", 0)) > int(best.tally.get("fires", 0))):
			best = {"stone": stone, "tally": tally, "points": points}
	## A stone whose skill changed after it did its work (a Restless Rock, a Changing Face) is
	## credited as the skill it fired as most, not the one it ends the run as. A tally kept
	## before the skill was noted has none, and names the stone as it stands.
	if not best.is_empty():
		var fired_as: Dictionary = best.tally.get("as", {})
		var most: String = ""
		for key in fired_as:
			if most.is_empty() or int(fired_as[key]) > int(fired_as[most]):
				most = str(key)
		if not most.is_empty() and most != str(best.stone.get("skill", "")):
			var shown: Dictionary = best.stone.duplicate()
			shown.skill = most
			best.was = best.stone
			best.stone = shown
	return best

func _party_units() -> Array:
	var out: Array = run.get("players", []).duplicate()
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("seat", 0)) < int(y.get("seat", 0)))
	return out

func _party_stats() -> Array:
	## What the party is compared on: [key, words, glyph, tint].
	return [["damage", "Damage dealt", "sword", DeepUi.ACCENT], ["block", "Block gained", "shield", DeepUi.BLOCK], ["healed", "Healed", "heart", DeepUi.HP],
		["slain", "Enemies slain", "skull", DeepUi.BAD], ["ore", "Pyrite dug", "ore", DeepUi.ORE], ["debuffs", "Debuffs applied", "drop", DeepUi.POISON],
		["best_hit", "Biggest hit", "hit", DeepUi.ACCENT_HI], ["best_turn", "Best turn", "flurry_burst", DeepUi.ACCENT_HI]]

func _leads(players: Array) -> Dictionary:
	## Who led each compared stat (by seat on a tie), where anyone did anything at all.
	var out: Dictionary = {}
	for entry in _party_stats():
		var key: String = str(entry[0])
		var best: int = 0
		for unit in players:
			var value: int = stat_value(tally_of(unit), key)
			if value > best:
				best = value
				out[key] = str(unit.id)
	return out

func _mvp(players: Array) -> Dictionary:
	## The party's MVP: the most points (see points_of), damage breaking a tie. {id, points}.
	var best: Dictionary = {}
	for unit in players:
		var stats: Dictionary = tally_of(unit)
		var points: int = points_of(stats, true)
		if best.is_empty() or points > int(best.points) or (points == int(best.points) and int(stats.damage) > int(best.damage)):
			best = {"id": str(unit.id), "points": points, "damage": int(stats.damage)}
	return best

func _count_up(label: Label, value: int, delay: float) -> void:
	## A number that ticks up from nothing to what it is, the way the seam's gold is paid out.
	## The label keeps the width of its full number while it counts, so nothing shifts.
	if value <= 0:
		return
	label.custom_minimum_size.x = label.get_minimum_size().x
	label.text = "0"
	var tween := label.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: DeepAudio.play("tally", {"volume": 0.4}))
	tween.tween_method(func(v: float) -> void: label.text = DeepUi.number(int(round(v))), 0.0, float(value), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _over_card(content: VBoxContainer) -> VBoxContainer:
	if DeepUi.phone:
		## The phone's card is the page's width (board run-over).
		var wide := DeepUi.card(content, Color(_over_tone(), 0.6), int(DeepUi.pt(8)))
		wide.size_flags_horizontal = Control.SIZE_FILL
		return DeepUi.vbox(wide, int(DeepUi.pt(4)))
	var card := DeepUi.card(content, Color(_over_tone(), 0.6), 20)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = 1180
	return DeepUi.vbox(card, 10)

func _over_head(box: VBoxContainer, glyph: String, title: String, words: String) -> HBoxContainer:
	var head := DeepUi.hbox(box, 16)
	var medal := Medallion.new(glyph, _over_tone(), 68)
	head.add_child(medal)
	var lines := DeepUi.vbox(head, 0)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.title(lines, title, 32, _over_tone())
	DeepUi.label(lines, words, 13, DeepUi.MUTED)
	return head

func _who_chip(parent: Node, unit: Dictionary) -> PanelContainer:
	## A delver's face, name and calling, as a small plate.
	var chip := DeepUi.card(parent, DeepUi.LINE, 6, Color(0.05, 0.06, 0.085, 0.8))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := DeepUi.hbox(chip, 10)
	var face := Roster.Portrait.new(str(unit.get("character", "")), Vector2(44, 44), false, false, false, DeepStone.birthstone_for(unit))
	face.mood = Roster.resting_mood(unit)
	row.add_child(face)
	var words := DeepUi.vbox(row, 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.label(words, str(unit.get("name", "")), 15, DeepUi.PAPER)
	## With the Birthstone they wore when it was not their first: "Ardor · Rampart".
	DeepUi.label(words, Roster.unit_named(unit), 12, DeepUi.MUTED).name = "DugAs"
	DeepUi.gap(row, 4)
	return chip

func _stat_tile(parent: Node, glyph: String, tint: Color, value: int, words: String, note: String, animate: bool, delay: float) -> PanelContainer:
	## One of the six totals: a mark, the number, what it is, and under it what it cost.
	var tile := DeepUi.card(parent, DeepUi.LINE, int(DeepUi.pt(4)) if DeepUi.phone else 8, Color(0.05, 0.06, 0.085, 0.9))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := DeepUi.vbox(tile, 0)
	var mark := DeepUi.icon(inner, glyph, DeepUi.glyph_px(14) if DeepUi.phone else 22.0, tint)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var number := DeepUi.title(inner, DeepUi.number(value), 20 if DeepUi.phone else 26, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	## Numbers are read, so they are Barlow: the display face fills its 0 in to a solid bar.
	number.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.label(inner, words, 11 if DeepUi.phone else 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	## The phone's tile keeps to its number and name; what it cost is in the card a hold opens.
	if DeepUi.phone:
		if not note.is_empty():
			tile.tooltip_text = "%s: %s" % [words, note]
	else:
		DeepUi.label(inner, note if not note.is_empty() else " ", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if animate:
		_count_up(number, value, delay)
	return tile

func _over_panel(parent: Node, glyph: String, words: String) -> VBoxContainer:
	var panel := DeepUi.card(parent, DeepUi.LINE, 12, Color(0.05, 0.06, 0.085, 0.8))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(panel, 5)
	DeepUi.section(box, glyph, words)
	return box

## Which of the run's three panels the phone shows (`_phone_parts`).
var _over_part: int = 0

func _phone_parts(holder: Container, boxes: Array, tabs: Array) -> void:
	## The phone's three panels behind tabs (board run-over): one shown at a time, its heading
	## the tab's.
	var row := DeepUi.hbox(holder, int(DeepUi.pt(3)))
	holder.move_child(row, 0)
	_over_part = clampi(_over_part, 0, boxes.size() - 1)
	for index in range(boxes.size()):
		var box: Control = boxes[index]
		(box.get_parent() as Control).visible = index == _over_part
		if box.get_child_count() > 0:
			(box.get_child(0) as Control).visible = false
		var at: int = index
		var tab := DeepUi.tab_button(row, str(tabs[index][0]), str(tabs[index][1]), index == _over_part, func() -> void:
			_over_part = at
			show_state(run), 12)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = DeepUi.pt(30)

func _over_row(box: VBoxContainer, words: String, value: String, note: String) -> void:
	## A highlight: what it is down the left, the number large, and where it happened under it.
	var row := DeepUi.hbox(box, 8)
	var key := DeepUi.label(row, words, 12, DeepUi.MUTED)
	key.custom_minimum_size.x = 104
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var lines := DeepUi.vbox(row, 0)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.title(lines, value, 17, DeepUi.PAPER).add_theme_font_override("font", DeepUi.bold_font())
	if not note.is_empty():
		DeepUi.wrap(lines, note, 11, DeepUi.MUTED)

func _journey_row(box: VBoxContainer, words: String, value: String, note: String = "") -> void:
	## One line of the way down: what it is, its note beside it ("Stones found · 1 shattered"),
	## and the number against the right edge, so the note never reads as part of the number.
	var row := DeepUi.hbox(box, 8)
	DeepUi.label(row, words, 12, DeepUi.MUTED)
	var said := DeepUi.label(row, ("· " + note) if not note.is_empty() else "", 11, DeepUi.DIM)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.clip_text = true
	DeepUi.title(row, value, 15, DeepUi.PAPER).add_theme_font_override("font", DeepUi.bold_font())

# --- what the run moved forward ----------------------------------------------------------------

func note_progress(before: Dictionary, applied: Dictionary, results: Dictionary, profile: Dictionary) -> void:
	## The run has come home into the profile: what it moved forward, for the over page.
	var opened: Array = _opened.duplicate()
	for entry in applied.get("unlocked", []):
		if entry is Dictionary and entry.has("mine") and not opened.has(str(entry.mine)):
			opened.append(str(entry.mine))
	_progress = progress_parts(before, applied, results, profile, opened)

static func records_before(profile: Dictionary, results: Dictionary) -> Dictionary:
	## The records a run is weighed against when it comes home, read before it is written into
	## them: the deepest this lapidary had reached in each mine, on the run's Hazard tier.
	var tier: int = clampi(int(results.get("hazard", 0)), 0, DeepContent.hazard_max())
	var deepest: Dictionary = {}
	var records: Dictionary = _mine_records(profile, tier)
	for key in records:
		if records[key] is Dictionary:
			deepest[str(key)] = int(records[key].get("deepest", 0))
	return {"tier": tier, "deepest": deepest}

static func _mine_records(profile: Dictionary, tier: int) -> Dictionary:
	## One tier's mine records, as DeepProfile.mine_records keeps them, only read: a tier never
	## gone down on has none yet.
	var found: Variant = profile.get("mines", {})
	if tier > 0:
		var hazard: Variant = profile.get("hazard", {})
		var tiers: Variant = hazard.get("tiers", {}) if hazard is Dictionary else {}
		var entry: Variant = tiers.get(str(tier), {}) if tiers is Dictionary else {}
		found = entry.get("mines", {}) if entry is Dictionary else {}
	return found if found is Dictionary else {}

static func next_goal(profile: Dictionary, mine_key: String, tier: int) -> String:
	## The next thing to go down a mine for, as "Next:" says it: its first Warden not beaten yet,
	## then its boss and the mine that opens, then the mine below. Empty for nothing more.
	var record: Variant = _mine_records(profile, tier).get(mine_key, {})
	if not record is Dictionary:
		record = {}
	var mine: Dictionary = DeepContent.mine(mine_key)
	if DeepContent.is_endless(mine_key):
		return "deeper than %d" % int(record.get("deepest", 0))
	var beaten: Array = record.get("wardens", [])
	var depths: Array = mine.get("warden_depths", [])
	for index in range(depths.size()):
		if not beaten.any(func(d: Variant) -> bool: return DeepEconomy.warden_index(mine_key, int(d)) == index):
			return "%s at depth %d" % [DeepEconomy.warden_name(mine_key, index), int(depths[index])]
	var below: String = str(mine.get("next", ""))
	if not bool(record.get("boss", false)):
		var boss: String = str(DeepContent.creature(str(mine.get("boss", ""))).get("name", "the boss"))
		return "%s at depth %d%s" % [boss, int(mine.get("depth", 0)), (" opens " + DeepContent.mine_name(below)) if not below.is_empty() else ""]
	return ("%s, the mine below" % DeepContent.mine_name(below)) if not below.is_empty() else ""

static func _guards_a_mine(creature: String) -> bool:
	## A Warden or a mine's boss: worth naming when it is met for the first time.
	for key in DeepContent.mines_in_order():
		var mine: Dictionary = DeepContent.mine(str(key))
		if str(mine.get("boss", "")) == creature or mine.get("wardens", []).has(creature):
			return true
	return false

static func progress_parts(before: Dictionary, applied: Dictionary, results: Dictionary, profile: Dictionary, opened: Array = []) -> Array:
	## What a run just come home moved forward for one lapidary, as the over page's "This run"
	## line says it, a part each: [glyph, tone, lead, words, aside]. The depth reached against
	## the best before it, every purse a Warden or a conquest paid, the mines opened, the
	## creatures met for the first time, and the next thing to go down for. The day's seam
	## writes no mine's records: it says only what the bestiary gained.
	var parts: Array = []
	var daily: bool = not results.get("daily", {}).is_empty()
	var mine_key: String = str(results.get("mine", ""))
	if not daily and not mine_key.is_empty():
		var reached: int = int(results.get("deepest", results.get("depth", 0)))
		for entry in results.get("mines", []):
			if entry is Dictionary and str(entry.get("mine", "")) == mine_key:
				reached = int(entry.get("deepest", reached))
		var was: int = int(before.get("deepest", {}).get(mine_key, 0))
		var where: String = DeepContent.mine_name(mine_key)
		if reached > was:
			parts.append(["star", DeepUi.ACCENT_HI, "New deepest", " in %s: %d" % [where, reached], (" (was %d)" % was) if was > 0 else ""])
		elif was > 0:
			parts.append(["stairs", DeepUi.MUTED, "Best", " in %s: %d" % [where, was], " (this run %d)" % reached])
	## A Warden named for its purse is not named again as met.
	var named: Array = []
	for purse in applied.get("purses", []):
		if not purse is Dictionary:
			continue
		if purse.has("warden"):
			named.append(DeepEconomy.warden_name(str(purse.mine), int(purse.warden)))
			parts.append(["crown", DeepUi.ACCENT, named.back(), " beaten: +%d gold" % int(purse.gold), ""])
		else:
			parts.append(["crown", DeepUi.ACCENT, DeepContent.mine_name(str(purse.mine)), " conquered: +%d gold" % int(purse.gold), ""])
	for key in opened:
		parts.append(["pick", DeepUi.GOOD, "Opened", " " + DeepContent.mine_name(str(key)), ""])
	var met: Array = applied.get("first_met", [])
	for key in met:
		var who: String = str(DeepContent.creature(str(key)).get("name", key))
		if _guards_a_mine(str(key)) and not named.has(who):
			parts.append(["eye", StoneCard.PIP_NEW, "Met", " " + who, ""])
			break
	if not met.is_empty():
		parts.append(["book", StoneCard.PIP_NEW, "+%d" % met.size(), " in the Bestiary", ""])
	if not daily and not mine_key.is_empty():
		var goal: String = next_goal(profile, mine_key, int(before.get("tier", 0)))
		if not goal.is_empty():
			parts.append(["next", DeepUi.INFO, "Next:", " " + goal, ""])
	return parts

func _progress_line(box: VBoxContainer) -> void:
	## "This run": what the run moved forward, compared with the best before it, and what to go
	## down for next (see `progress_parts`). Two lines at most, so the page never grows past one.
	if _progress.is_empty():
		return
	var band := DeepUi.card(box, Color(DeepUi.ACCENT, 0.75), 8, Color(DeepUi.ACCENT, 0.07))
	var row := DeepUi.hbox(band, 12)
	var head := DeepUi.hbox(row, 6)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	DeepUi.icon(head, "descend", 15, DeepUi.ACCENT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.heading(head, "This run", 13, DeepUi.ACCENT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rule := ColorRect.new()
	rule.color = Color(DeepUi.ACCENT, 0.4)
	rule.custom_minimum_size = Vector2(1, 18)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	## Each part's mark sets it off from the one before: a dot between them was left hanging
	## at the end of the first line whenever the line wrapped.
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 20)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flow)
	for part in _progress:
		var piece := DeepUi.hbox(flow, 5)
		DeepUi.icon(piece, str(part[0]), 14, part[1]).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var words := DeepUi.hbox(piece, 0)
		DeepUi.label(words, str(part[2]), 13, part[1]).add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(words, str(part[3]), 13, DeepUi.PAPER)
		if not str(part[4]).is_empty():
			DeepUi.label(words, str(part[4]), 12, DeepUi.MUTED)

func _page_over_run(content: VBoxContainer, animate: bool) -> void:
	var unit: Dictionary = me()
	var stats: Dictionary = tally_of(unit)
	var outcome: String = str(run.get("outcome", ""))
	## An abandoned dig ends as a fall to the sim, but nobody died: it is titled for what it was.
	var named: String = "abandoned" if bool(run.get("abandoned", false)) else outcome
	var titles: Dictionary = {"extracted": "Extracted", "conquered": "The mine is yours", "fallen": "Fallen", "abandoned": "Abandoned"}
	var glyphs: Dictionary = {"extracted": "lift", "conquered": "crown", "fallen": "skull", "abandoned": "door"}
	var party: bool = run.get("players", []).size() > 1
	var box := _over_card(content)
	var head := _over_head(box, str(glyphs.get(named, "lift")), str(titles.get(named, named.capitalize())),
		"%s · depth %d · %s · %s" % [DeepContent.mine_name(str(run.get("mine", ""))), int(run.get("depth", 0)), DeepUi.plural(int(stats.fights), "fight"), DeepUi.plural(int(stats.turns), "turn")])
	_who_chip(head, unit)
	_progress_line(box)
	## The six totals, each with what it cost. On the phone three to a row down the left, the
	## panels beside them (board run-over).
	var body: HBoxContainer = null
	var tiles: Container = null
	if DeepUi.phone:
		body = DeepUi.hbox(box, int(DeepUi.pt(10)))
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", int(DeepUi.pt(4)))
		grid.add_theme_constant_override("v_separation", int(DeepUi.pt(4)))
		grid.custom_minimum_size.x = DeepUi.pt(310)
		grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		body.add_child(grid)
		tiles = grid
	else:
		tiles = DeepUi.hbox(box, 10)
	var top_debuff: Array = top_kind(stats.get("debuffs", {}))
	var wardens: int = int(stats.slain_wardens)
	var sums: Array = [["sword", DeepUi.ACCENT, int(stats.damage), "Damage dealt", "%s overkill" % DeepUi.number(int(stats.overkill)) if int(stats.overkill) > 0 else ""],
		["shield", DeepUi.BLOCK, int(stats.block), "Block gained", "%s damage blocked" % DeepUi.number(int(stats.blocked)) if int(stats.blocked) > 0 else ""],
		["heart", DeepUi.HP, int(stats.healed), "Healed in fights", "%s overhealed" % DeepUi.number(int(stats.overheal)) if int(stats.overheal) > 0 else ""],
		["ore", DeepUi.ORE, int(stats.ore), "Pyrite dug", "%s spent" % DeepUi.number(int(stats.spent)) if int(stats.spent) > 0 else ""],
		["skull", DeepUi.BAD, int(stats.slain), "Enemies slain", DeepUi.plural(wardens, "Warden") if wardens > 0 else ""],
		["drop", DeepUi.POISON, stat_value(stats, "debuffs"), "Debuffs applied", "%s %s" % [DeepUi.number(int(top_debuff[1])), status_words(str(top_debuff[0]))] if not top_debuff.is_empty() else ""]]
	for index in range(sums.size()):
		var entry: Array = sums[index]
		_stat_tile(tiles, str(entry[0]), entry[1], int(entry[2]), str(entry[3]), str(entry[4]), animate, 0.15 + 0.12 * float(index))
	var panels: Container = null
	if DeepUi.phone:
		panels = DeepUi.vbox(body, int(DeepUi.pt(4)))
		panels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		panels = DeepUi.hbox(box, 10)
		panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## Highlights: the run's bests, with where they happened.
	var highlights := _over_panel(panels, "spark", "Highlights")
	var hit: Dictionary = stats.get("best_hit", {})
	if int(hit.get("amount", 0)) > 0:
		var skill: String = str(DeepContent.skill(str(hit.get("skill", ""))).get("name", hit.get("skill", "")))
		_over_row(highlights, "Biggest hit", DeepUi.number(int(hit.amount)), "%s%s · depth %d" % [skill, (" on " + str(hit.creature)) if not str(hit.get("creature", "")).is_empty() else "", int(hit.get("depth", 0))])
	else:
		_over_row(highlights, "Biggest hit", "–", "No gem landed a blow.")
	var turn: Dictionary = stats.get("best_turn", {})
	if int(turn.get("amount", 0)) > 0:
		_over_row(highlights, "Best turn", DeepUi.number(int(turn.amount)), "damage%s, turn %d · depth %d" % [(" · " + str(turn.creature)) if not str(turn.get("creature", "")).is_empty() else "", int(turn.get("turn", 0)), int(turn.get("depth", 0))])
	var hand: Array = _best_hand(stats)
	if not hand.is_empty():
		_over_row(highlights, "Best hand", str(hand[0]), "%s, in %s" % [DeepUi.plural(int(hand[1]), "time"), DeepUi.plural(int(stats.turns), "turn")])
	var downs: String = "never downed" if int(stats.downs) == 0 else "downed %s" % DeepUi.plural(int(stats.downs), "time")
	if party and int(stats.revives) > 0:
		downs += " · picked up %s" % DeepUi.plural(int(stats.revives), "ally", "allies")
	_over_row(highlights, "Taken", DeepUi.number(int(stats.taken)), "damage · " + downs)
	var top_buff: Array = top_kind(stats.get("buffs", {}))
	if not top_buff.is_empty():
		_over_row(highlights, "Buffs given", DeepUi.number(stat_value(stats, "buffs")), "%s %s, most of all" % [DeepUi.number(int(top_buff[1])), status_words(str(top_buff[0]))])
	## The Crown Jewel: the stone on the rail that did the most.
	var jewel := _over_panel(panels, "crown", "Crown Jewel")
	var pick: Dictionary = _crown_jewel(unit, stats)
	if pick.is_empty():
		DeepUi.wrap(jewel, "No gem on the rail fired this run.", 13, DeepUi.MUTED)
	else:
		var stone: Dictionary = pick.stone
		var tally: Dictionary = pick.tally
		var row := DeepUi.hbox(jewel, 10)
		StoneCard.tile(row, stone, 60, false)
		var words := DeepUi.vbox(row, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.title(words, str(DeepStone.skill_of(stone).get("name", stone.get("skill", ""))), 19, DeepUi.ACCENT_HI)
		DeepUi.wrap(words, DeepUi.stone_name(stone), 11, DeepUi.MUTED)
		DeepUi.label(words, "%s points · fired %s" % [DeepUi.number(int(pick.points)), DeepUi.plural(int(tally.get("fires", 0)), "time")], 11, DeepUi.DIM)
		for entry in [["Damage", int(tally.get("damage", 0)), int(stats.damage), DeepUi.ACCENT], ["Block", int(tally.get("block", 0)), int(stats.block), DeepUi.BLOCK],
				["Healed", int(tally.get("healed", 0)), int(stats.healed), DeepUi.HP], ["Debuffs", int(tally.get("debuffs", 0)), stat_value(stats, "debuffs"), DeepUi.POISON],
				["Biggest hit", int(tally.get("best", 0)), int(hit.get("amount", 0)), DeepUi.ACCENT_HI]]:
			if int(entry[1]) <= 0:
				continue
			var line := DeepUi.hbox(jewel, 8)
			DeepUi.label(line, str(entry[0]), 11, DeepUi.MUTED).custom_minimum_size.x = 72
			var share: float = clampf(float(entry[1]) / float(maxi(1, int(entry[2]))), 0.0, 1.0)
			var gauge := DeepUi.bar(line, 8.0, entry[3], Color(DeepUi.INK, 0.9))
			gauge.ratio = share
			gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var pct: String = " · %d%%" % int(round(share * 100.0)) if str(entry[0]) != "Biggest hit" and int(entry[2]) > 0 else ""
			DeepUi.label(line, DeepUi.number(int(entry[1])) + pct, 11, DeepUi.PAPER).custom_minimum_size.x = 84
	## The way down.
	var journey := _over_panel(panels, "map", "The way down")
	var deepest: int = int(run.get("records", {}).get("deepest", 0))
	_journey_row(journey, "Depth reached", str(int(run.get("depth", 0))), ("deepest %d" % deepest) if deepest > int(run.get("depth", 0)) else "")
	var kinds: Array = []
	if int(stats.elites) > 0:
		kinds.append("%d elite" % int(stats.elites))
	if int(stats.wardens) > 0:
		kinds.append(DeepUi.plural(int(stats.wardens), "Warden"))
	_journey_row(journey, "Fights", str(int(stats.fights)), " · ".join(kinds))
	var shattered: int = unit.get("shattered", []).size()
	_journey_row(journey, "Stones found", str(int(stats.stones)), "%d shattered" % shattered if shattered > 0 else "")
	_journey_row(journey, "Turns played", str(int(stats.turns)))
	_journey_row(journey, "Rerolls used", ("%d of %d" % [int(stats.rerolls), int(stats.rerolls_given)]) if int(stats.rerolls_given) > 0 else str(int(stats.rerolls)))
	_journey_row(journey, "Birthstone fired", "%s" % DeepUi.plural(int(stats.birthstone), "time"), str(unit.get("birthstone", {}).get("name", "")))
	_journey_row(journey, "Peak Resonance", str(int(stats.resonance)))
	if DeepUi.phone:
		_phone_parts(panels, [highlights, jewel, journey], [["spark", "Highlights"], ["crown", "Crown Jewel"], ["map", "The way down"]])
	var foot := DeepUi.hbox(box, 12)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_main(DeepUi.primary(foot, "next", "Next: the party" if party else "Next: the haul", _show_over_tab.bind("party" if party else "haul"), 16))

func _page_over_party(content: VBoxContainer, animate: bool) -> void:
	var players: Array = _party_units()
	var leads: Dictionary = _leads(players)
	var mvp: Dictionary = _mvp(players)
	var box := _over_card(content)
	var fights: int = 0
	var left: int = 0
	for unit in players:
		fights = maxi(fights, int(tally_of(unit).fights))
		if not bool(unit.get("connected", true)):
			left += 1
	var head := _over_head(box, "party", "The party", "%s · %s · %s" % [DeepUi.plural(players.size(), "delver"), DeepUi.plural(fights, "fight"),
		"nobody left behind" if left == 0 else DeepUi.plural(left, "delver") + " left on the way"])
	## The MVP: the most points, said with what they led.
	var crowned: Dictionary = DeepDescent.player(run, str(mvp.get("id", "")))
	if not crowned.is_empty():
		var band := DeepUi.card(head, DeepUi.ACCENT, 8, Color(DeepUi.ACCENT, 0.1))
		band.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var row := DeepUi.hbox(band, 10)
		DeepUi.icon(row, "crown", 28, DeepUi.ACCENT_HI)
		var words := DeepUi.vbox(row, 0)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.title(words, "MVP · %s" % str(crowned.get("name", "")), 20, DeepUi.ACCENT_HI)
		var led: Array = []
		for entry in _party_stats():
			if str(leads.get(str(entry[0]), "")) == str(crowned.id):
				led.append(str(entry[1]).to_lower())
		DeepUi.label(words, "%s points%s" % [DeepUi.number(int(mvp.points)), (" · led " + ", ".join(led)) if not led.is_empty() else ""], 12, DeepUi.MUTED)
		DeepUi.gap(row, 4)
	var body := DeepUi.hbox(box, 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side := DeepUi.vbox(body, 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## The chart: one row a stat, one bar a player, the leader crowned. A column hovered
	## lights that player's bars.
	var rows: Array = []
	for entry in _party_stats().slice(0, 6):
		var values: Dictionary = {}
		for unit in players:
			values[str(unit.id)] = stat_value(tally_of(unit), str(entry[0]))
		rows.append({"words": str(entry[1]), "values": values, "leader": str(leads.get(str(entry[0]), ""))})
	var seats: Array = []
	for index in range(players.size()):
		seats.append({"id": str(players[index].id), "name": str(players[index].get("name", "")), "color": PARTY_TONES[index % PARTY_TONES.size()]})
	var chart := StatChart.new(rows, seats)
	var cols := DeepUi.hbox(side, 8)
	for index in range(players.size()):
		_party_column(cols, players[index], PARTY_TONES[index % PARTY_TONES.size()], leads, str(mvp.get("id", "")), animate, 0.15 + 0.1 * float(index), chart)
	## The party's totals under the columns.
	var totals := DeepUi.hbox(side, 8)
	for entry in _party_stats().slice(0, 6):
		var sum: int = 0
		for unit in players:
			sum = DeepRules.sat_add(sum, stat_value(tally_of(unit), str(entry[0])))
		var tile := DeepUi.card(totals, DeepUi.LINE, 6, Color(0.05, 0.06, 0.085, 0.7))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := DeepUi.vbox(tile, 0)
		var number := DeepUi.title(inner, DeepUi.number(sum), 17, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		number.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(inner, "Party " + str(entry[1]).to_lower(), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if animate:
			_count_up(number, sum, 0.9)
	var panel := DeepUi.card(body, DeepUi.LINE, 12, Color(0.05, 0.06, 0.085, 0.8))
	panel.custom_minimum_size.x = 470
	var inner := DeepUi.vbox(panel, 6)
	DeepUi.section(inner, "count", "Compared")
	var legend := DeepUi.hbox(inner, 14)
	for seat in seats:
		var mark := DeepUi.hbox(legend, 5)
		var swatch := ColorRect.new()
		swatch.color = seat.color
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.add_child(swatch)
		DeepUi.label(mark, str(seat.name), 12, DeepUi.MUTED)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.custom_minimum_size = Vector2(440, 280)
	inner.add_child(chart)
	DeepUi.label(inner, "Each row is its own scale. Hover a delver to pick out their bars.", 11, DeepUi.DIM)
	if animate:
		chart.reveal = 0.0
		var tween := chart.create_tween()
		tween.tween_interval(0.3)
		tween.tween_property(chart, "reveal", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var foot := DeepUi.hbox(box, 12)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon_button(foot, "prev", "Your run", _show_over_tab.bind("run"), 15, DeepUi.MUTED)
	_main(DeepUi.primary(foot, "next", "Next: the haul", _show_over_tab.bind("haul"), 16))

func _party_column(parent: Node, unit: Dictionary, tone: Color, leads: Dictionary, mvp_id: String, animate: bool, delay: float, chart: Control) -> PanelContainer:
	## One delver of the party: their face, the compared stats with a crown on each one they
	## led, and their Crown Jewel. The MVP's column is lit, and the crown drops onto them.
	var stats: Dictionary = tally_of(unit)
	var is_mvp: bool = str(unit.id) == mvp_id
	var col := DeepUi.card(parent, DeepUi.ACCENT if is_mvp else DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.8))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_entered.connect(func() -> void: chart.highlight = str(unit.id))
	col.mouse_exited.connect(func() -> void: chart.highlight = "")
	var inner := DeepUi.vbox(col, 3)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(72, 72)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(holder)
	var face := Roster.Portrait.new(str(unit.get("character", "")), Vector2(72, 72), false, false, false, DeepStone.birthstone_for(unit))
	face.mood = Roster.resting_mood(unit)
	face.ring = tone
	holder.add_child(face)
	DeepUi.title(inner, str(unit.get("name", "")), 19, DeepUi.ACCENT_HI if is_mvp else DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.label(inner, Roster.unit_named(unit), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if not bool(unit.get("connected", true)):
		var gone := DeepUi.pill(inner, "hourglass", "left at depth %d" % int(unit.get("left_depth", run.get("depth", 0))), DeepUi.BAD, 11)
		gone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var numbers: Array = []
	for entry in _party_stats():
		var row := DeepUi.hbox(inner, 6)
		DeepUi.label(row, str(entry[1]), 11, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: int = stat_value(stats, str(entry[0]))
		var figure := DeepUi.title(row, DeepUi.number(value), 15, DeepUi.PAPER)
		figure.add_theme_font_override("font", DeepUi.bold_font())
		numbers.append([figure, value])
		if str(leads.get(str(entry[0]), "")) == str(unit.id):
			DeepUi.icon(row, "crown", 13, DeepUi.ACCENT_HI, "Led the party")
		else:
			DeepUi.gap(row, 13)
	var pick: Dictionary = _crown_jewel(unit, stats)
	var jewel := DeepUi.pill(inner, "crown", str(DeepStone.skill_of(pick.stone).get("name", "")) if not pick.is_empty() else "no gem fired", DeepUi.ACCENT if not pick.is_empty() else DeepUi.DIM, 11,
		("Crown Jewel: " + DeepUi.stone_name(pick.stone)) if not pick.is_empty() else "")
	jewel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not bool(unit.get("connected", true)):
		col.modulate = Color(1, 1, 1, 0.6)
	if animate:
		for index in range(numbers.size()):
			_count_up(numbers[index][0], int(numbers[index][1]), delay + 0.05 * float(index))
	if is_mvp:
		var crown := DeepUi.icon(holder, "crown", 30, DeepUi.ACCENT_HI, "MVP")
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rest := Vector2(21, -16)
		crown.position = rest
		if animate:
			crown.modulate.a = 0.0
			crown.position = rest - Vector2(0, 40)
			var tween := crown.create_tween()
			tween.tween_interval(delay + 1.1)
			tween.tween_callback(func() -> void: crown.modulate.a = 1.0)
			tween.tween_property(crown, "position", rest, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func() -> void:
				DeepAudio.play("gleam")
				DeepUi.pulse(crown, 1.3, 0.4)
				if is_instance_valid(crown) and crown.is_inside_tree():
					DeepUi.burst(self, crown.global_position + crown.size * 0.5 - global_position, DeepUi.ACCENT_HI, 30, 220.0, 0.8, 6.0))
	return col

func _page_over_haul(content: VBoxContainer) -> void:
	var unit: Dictionary = me()
	var outcome: String = str(run.get("outcome", ""))
	## An abandoned dig ends as a fall to the sim, but nobody died: it is titled for what it was.
	var named: String = "abandoned" if bool(run.get("abandoned", false)) else outcome
	var titles: Dictionary = {"extracted": "Extracted", "conquered": "The mine is yours", "fallen": "Fallen", "abandoned": "Abandoned"}
	var glyphs: Dictionary = {"extracted": "lift", "conquered": "crown", "fallen": "skull", "abandoned": "door"}
	var tone: Color = _over_tone()
	var card := DeepUi.card(content, Color(tone, 0.6), int(DeepUi.pt(10)) if DeepUi.phone else 26)
	card.size_flags_horizontal = Control.SIZE_FILL if DeepUi.phone else Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = 0.0 if DeepUi.phone else 720.0
	## The day's seam has one more line to say at the lift: the card closes up a little for it.
	var box := DeepUi.vbox(card, int(DeepUi.pt(5)) if DeepUi.phone else (14 if run.get("daily", {}).is_empty() else 10))
	var medal := Medallion.new(str(glyphs.get(named, "lift")), tone, 110)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(medal)
	DeepUi.title(box, str(titles.get(named, named.capitalize())), 38, tone, HORIZONTAL_ALIGNMENT_CENTER)
	var stats := DeepUi.hbox(box, 12)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	## Exactly what the workshop's tray will be handed: the bag, and the stones found down here
	## and set on the rail. The vault's own stones were never in question.
	var haul: Array = DeepDescent.coming_home(run, unit)
	## The day's seam keeps nothing: what came up is scored.
	var daily: bool = not run.get("daily", {}).is_empty()
	if daily:
		haul = haul.filter(func(s: Dictionary) -> bool: return not DeepStone.is_fragile(s) and not bool(s.get("lent", false)))
	var tally: Dictionary = unit.get("stats", {})
	for entry in [["stairs", "Depth", str(int(run.depth))], ["bag", "Stones up" if daily else "Stones home", str(haul.size())], ["sword", "Fights", str(int(tally.get("fights", 0)))],
			["ore", "Pyrite dug", str(int(tally.get("ore", 0)))], ["shield_burst", "Damage", str(int(tally.get("damage", 0)))]]:
		var tile := DeepUi.card(stats, DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9))
		tile.custom_minimum_size = Vector2(118, 0)
		var inner := DeepUi.vbox(tile, 2)
		var mark := DeepUi.icon(inner, str(entry[0]), 22, DeepUi.ACCENT)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.title(inner, str(entry[2]), 24, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(inner, str(entry[1]), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if daily:
		_daily_strip(box)
	## On the phone what comes home and what shattered stand side by side.
	var home_box: VBoxContainer = box
	var loss_box: Container = box
	if DeepUi.phone:
		var split := DeepUi.hbox(box, int(DeepUi.pt(14)))
		home_box = DeepUi.vbox(split, int(DeepUi.pt(4)))
		home_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loss_box = split
	if not haul.is_empty():
		var home_head := DeepUi.hbox(home_box, 8)
		DeepUi.section(home_head, "bag", "Brought up, scored and not kept" if daily else "Coming home").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tiles := HFlowContainer.new()
		tiles.add_theme_constant_override("h_separation", 10)
		tiles.add_theme_constant_override("v_separation", 10)
		home_box.add_child(tiles)
		var index: int = 0
		for stone in _paged(home_head, "home", haul, HOME_PAGE):
			var tile := StoneCard.tile(tiles, stone, 84 if DeepUi.phone else 64, true, true)
			_enter(tile, 0.4 + 0.06 * index)
			index += 1
	var shattered: Array = unit.get("shattered", [])
	if not shattered.is_empty():
		## Centred under the tiles like everything else on the card, and wide enough that its
		## one line of explanation is not folded into a narrow column beside the shards.
		var losses := DeepUi.hbox(loss_box, 12)
		losses.alignment = BoxContainer.ALIGNMENT_CENTER
		var shards: Control = load("res://view/gems/shatter.gd").new(shattered[0], 64.0, 0.45, _fresh)
		losses.add_child(shards)
		var note := DeepUi.vbox(losses, 4)
		note.custom_minimum_size.x = DeepUi.pt(260) if DeepUi.phone else 440.0
		note.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.section(note, "split_shield", "%s shattered" % DeepUi.plural(shattered.size(), "fragile gem"), DeepUi.BAD)
		DeepUi.wrap(note, "Fragile gems never leave the mine: Void gems and fragile finds shatter when a run ends. Nothing was kept or sold.", 13, DeepUi.MUTED)
		losses.tooltip_text = "\n".join(shattered.map(func(s: Dictionary) -> String: return DeepUi.stone_name(s)))
	var go := _main(DeepUi.primary(box, "anvil", "Back to the workshop", func() -> void: home_requested.emit(), 18))
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter(card)
