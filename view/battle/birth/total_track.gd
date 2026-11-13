extends Control
## A hand's total on a track: a row of cells, one a stretch of totals, and a marker standing on
## the cell the hand is in with the total over it. The game shows no total of its own; two
## Birthstones read one (a Nocturne's low total, a Blackjack's count), and both lay this over
## the tray so what one more throw risks reads at a glance.
##
## `cells` run left to right, each {"from", "to", "label", "tone", "weight"}: the totals it
## holds (inclusive; the first and last also take everything past their ends), what is
## written in it, its color once the marker stands on it, and how wide it is against the rest.
## Text is drawn at the floor (`DeepUi.min_text`) and the track sizes itself to hold it.

var cells: Array = []
## The total, whether to show it (not while the dice tumble), and the words after the number
## over the marker ("Stand ×4") in their own color.
var value: int = 0
var marked: bool = false
var caption: String = ""
var caption_tone: Color = DeepUi.PAPER
## How wide the row of cells is; the control is as wide, and two lines of text tall.
var span: float = 280.0

var _shown_at: float = -1.0
var _goal: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func lay(with_cells: Array, width: float) -> void:
	cells = with_cells
	span = width
	custom_minimum_size = Vector2(width, _line() * 2.0 + _gap() * 3.0)
	size = custom_minimum_size
	queue_redraw()

func set_total(total: int, show_marker: bool, words: String = "", tone: Color = DeepUi.PAPER) -> void:
	## The hand's total now. The marker slides to it.
	if total == value and show_marker == marked and words == caption and tone == caption_tone:
		return
	value = total
	marked = show_marker
	caption = words
	caption_tone = tone
	_goal = _x_of(total)
	if _shown_at < 0.0 or DeepUi.headless() or not show_marker:
		_shown_at = _goal
	set_process(true)
	queue_redraw()

func cell_of(total: int) -> int:
	for index in range(cells.size()):
		var low: int = int(cells[index].get("from", 0))
		var high: int = int(cells[index].get("to", low))
		if (total >= low or index == 0) and (total <= high or index == cells.size() - 1):
			return index
	return -1

func _process(delta: float) -> void:
	if is_equal_approx(_shown_at, _goal):
		set_process(false)
		return
	_shown_at = move_toward(_shown_at, _goal, maxf(absf(_goal - _shown_at) * 10.0, 60.0) * delta)
	queue_redraw()

func _line() -> float:
	return float(DeepUi.min_text()) + (2.0 if not DeepUi.phone else 0.0)

func _gap() -> float:
	return DeepUi.pt(1.5) if DeepUi.phone else 3.0

func _cell_rect(index: int) -> Rect2:
	var total: float = 0.0
	for cell in cells:
		total += float(cell.get("weight", 1.0))
	var before: float = 0.0
	for at in range(index):
		before += float(cells[at].get("weight", 1.0))
	var wide: float = span * float(cells[index].get("weight", 1.0)) / maxf(total, 0.001)
	return Rect2(span * before / maxf(total, 0.001), _line() + _gap() * 2.0, wide, _line() + _gap())

func _x_of(total: int) -> float:
	## Where the marker stands for a total: along its cell by how far through it the total is
	## (the middle of a cell of one number, the far end of an end cell for a total past it).
	var index: int = cell_of(total)
	if index < 0:
		return 0.0
	var cell: Rect2 = _cell_rect(index)
	var low: int = int(cells[index].get("from", 0))
	var high: int = int(cells[index].get("to", low))
	var share: float = 0.5 if high <= low else clampf((float(total - low) + 0.5) / float(high - low + 1), 0.08, 0.92)
	return cell.position.x + cell.size.x * share

func _draw() -> void:
	if cells.is_empty():
		return
	var font: Font = DeepUi.bold_font()
	var px: int = DeepUi.min_text()
	var here: int = cell_of(value) if marked else -1
	for index in range(cells.size()):
		var cell: Rect2 = _cell_rect(index).grow_individual(-1.0, 0.0, -1.0, 0.0)
		var tone: Color = cells[index].get("tone", DeepUi.MUTED)
		var on: bool = index == here
		draw_rect(cell, Color(tone, 0.92) if on else Color(DeepUi.LEDGER_FILL, 0.92))
		draw_rect(cell, tone if on else Color(tone, 0.5), false, 1.5 if not DeepUi.phone else 2.0)
		var label: String = str(cells[index].get("label", ""))
		if label.is_empty():
			continue
		var wide: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var ink: Color = (Color("15181f") if tone.get_luminance() > 0.45 else Color("f4f7fb")) if on else Color(tone, 0.85)
		draw_string(font, Vector2(cell.get_center().x - wide * 0.5, cell.get_center().y + (font.get_ascent(px) - font.get_descent(px)) * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
	if not marked or here < 0:
		return
	## The marker: a wedge on the cell's top edge, the total over it and its words after.
	var tone_here: Color = cells[here].get("tone", DeepUi.PAPER)
	var top: float = _cell_rect(here).position.y
	var at := Vector2(_shown_at, top)
	var wedge: float = _gap() * 2.0
	draw_colored_polygon(PackedVector2Array([at + Vector2(-wedge, -wedge * 1.3), at + Vector2(wedge, -wedge * 1.3), at + Vector2(0.0, 1.0)]), tone_here.lightened(0.2))
	var number: String = str(value)
	var number_wide: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, px + 2).x
	var words_wide: float = font.get_string_size("  " + caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x if not caption.is_empty() else 0.0
	var left: float = clampf(_shown_at - number_wide * 0.5, 0.0, maxf(0.0, span - number_wide - words_wide))
	var base: float = top - wedge * 1.3 - _gap() * 0.5 - font.get_descent(px + 2)
	var edge := Color(0.02, 0.03, 0.05, 0.9)
	draw_string_outline(font, Vector2(left, base), number, HORIZONTAL_ALIGNMENT_LEFT, -1, px + 2, 4, edge)
	draw_string(font, Vector2(left, base), number, HORIZONTAL_ALIGNMENT_LEFT, -1, px + 2, tone_here.lightened(0.25))
	if not caption.is_empty():
		draw_string_outline(font, Vector2(left + number_wide, base), "  " + caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, edge)
		draw_string(font, Vector2(left + number_wide, base), "  " + caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px, caption_tone)
