# The phone layout

November 7, 2026. The phone build had text and marks too small to read, buttons too small to hit and hover-only actions a finger cannot reach. The owner chose one codebase with two designed layouts (not a separate project, and not a fluid layout that squeezes the desktop's). Every screen was mocked up for a phone on a review page (artifact AaEEptCVyEMsUNVBm2jQja, owner marks in its db collection `phone1`, mocks under `build/phone/mock/`), every board was approved, and the layouts were built from it. This file records the system, what was built and how to work on it.

## Turning it on

`DeepUi.phone` is the switch, set once by `DeepUi.detect_phone()` at the top of `App._ready` and never changed after. It is on for an iOS or Android device whose screen is under 7.5 inches across, and for any window started with `--phone` or with the environment variable `DEEPCUT_FORM=phone` (how it is tested on a desk). `--desktop` or `DEEPCUT_FORM=desktop` forces it off. A tablet keeps the desktop layout, with touch.

Everything phone-only is gated on `DeepUi.phone`. The desktop's code paths are unchanged by it.

## The sizes

- **Points.** The phone is laid out in points: 852 × 393, an iPhone 15/16 held sideways. The canvas is twice that, `DeepUi.PHONE_CANVAS` (1704 × 786) with `CONTENT_SCALE_ASPECT_EXPAND`, so `DeepUi.pt(n)` is `n * 2` canvas pixels. A longer or taller screen only adds room.
- **Safe edges.** `DeepUi.safe_left`, `safe_right`, `safe_top`, `safe_bottom`, in canvas pixels, from the display's safe area on a device (`fit_safe_area`, again on every resize) and an iPhone's insets on a desk window (`PHONE_SAFE_SIDE` 118 each side, `PHONE_SAFE_FOOT` 42). Bars (the strip, the dock, the rail of places) run to the screen's edges and keep their content inside; no button stands under a safe edge.
- **Text.** A size asked of the kit (`label`, `wrap`, `title`, `set_text_size`, `readable`) is read in points on the phone. Up to 13 it is taken as asked; past that it grows at half the pace (`DeepUi.phone_points`: a desk title of 34 reads at 24 points). The floor is `PHONE_LEAST`, 11 points. One size only: the Text size setting is hidden.
- **Fingers.** No button is under `DeepUi.FINGER_LEAST` (28 points) either way: `DeepUi.button` (and so every icon, primary and tab button) starts there, and a caller's own size stands over it. Main actions are 36 to 44 points tall. `DeepUi.reach` areas count toward it.
- **Marks.** `DeepUi.glyph_px(size, extra)` sizes a mark beside text of `size`; `DeepUi.gap_px` a gap.

## What a finger does

- **Tap** does what a click does. Where the desktop shows something on hover, the first tap shows it and a second tap (or the button that appears) acts: a tunnel's way shows with Go this way; a stone in the bag reads on the card at the bag's foot.
- **Hold** (`Tips.hold`, 0.42 s) opens a thing's card: a panel down the right side, the screen's height, its words scrolling, with **Details** (the close look, what a right-click opens on the desk) and **Close** (`Tips.open_sheet`). It stays after the finger lifts; a tap anywhere else closes it. No hover plates on the phone.
- **Drag** still works everywhere the desktop drags, but nothing needs it: a stone is set by a tap on it and then on a lit socket (the run's bench), bought into the bag or onto the rail from its card (the merchant), and so on.
- **Words.** `DeepUi.phone_words` swaps the mouse's words for a finger's (Click → Tap, Right-click → Hold, Double-click → Double-tap) in every label the kit makes and on the room's line; keyboard hints are dropped or reworded where they are set ("Tap to skip ahead").

## What was built

**The workshop.** The places run down the left edge (`HomeScreen._ready_phone`, `_draw_rail`): the purse, Descend, Delvers, Vault, Market, Bestiary with their pips, then Party and You at the foot. Pages are in `view/phone/`, each called from the top of its desktop page's `build()`:
- `descend_phone.gd`: the mines as rows, the hazard row and its side panel, the stratum card, the going-down card (the delver, a Seed side panel, Insure and Descend), the daily dig.
- `delvers_phone.gd`: the six delvers in a strip, the dossier in three columns (Birthstone tiers in a two-column grid), the sockets view with the vault's stones nine a row, scrolling.
- `vault_phone.gd`: the collection five a row, scrolling, beside the stone's card (favorite star over the picture's corner, the numbers as bars, wearers, Socket it, Wheel, Oven); the tray's bench without its Yours column, the tray five rows a page.
- `market_phone.gd`: Cut and read, Geodes, Commissions and The bench as four tabs.
- `bestiary_phone.gd`: the list down every mine three to a row in 262 points (it scrolls, as the desk's does), the creature's model in a 120 × 104 window beside its name and words, its facts, then its pages under tabs.
- `profile_phone.gd`: You. The face, the name and Settings; seven numbers in a row; Showcase, Mines and Recent runs as tabs.
- The party (`PartyDock.popover`): a panel down the right side. Steam is the desktop game's; the phone plays on its Wi-Fi.

**The menu** (`view/menu/game_menu.gd`). A card 260 points wide: Resume, Settings, How to play, Leave the run (Close the game on Android; iOS has no quit). Settings take the whole screen in two columns (no Fullscreen, Vertical sync or Text size; Rumble is Vibration; the version at the foot) and also open straight from You (`HomeScreen.settings_requested`, `GameMenu.open_settings`). How to play lists the gestures.

**Down the mine.** The strip and the dock are bars from edge to edge (`DeepUi.phone_bar`). The fight's dock (`BattleScreen.use_phone_sizes`): sockets and dice at 44 points, no names over the rings, the Resonance mark and number without the word, Reroll and Lock in under the dice. The run's dock is exactly as tall (no words under its dice). The target's ledger stands over the creatures' tags. The rooms' heads are one row (`Medallion` beside the title, 30 points). Room names (the landing's stations, the hoard's pedestals) are capsules to tap (`MineStage._phone_name`).
- The bag (`RunDock`): a 290 point panel down the right side from under the strip to the foot, stones four a row, the stone tapped read on a card at its foot with Set, Sell and Look.
- The chart: a 260 point panel on the left, inside the safe edge, drawn half again as large (`CHART_SCALE`; `ShaftMap._text` keeps its words at reading size under the scale).
- The ask: 318 points wide over the room, a 52 point slot, left of the bag when the bag is open (`AskSheet.side_width`), placed again once its words are laid out.
- The bench (`BenchPanel`): the whole screen, no reading pane, 88 pixel sockets; tap a stone and a lit socket to set it, a set stone and the haul to take it out.
- Rooms with offers (the grubstake, oddities, the smithy, the carver, the well): cards share the page's width, 150 to 210 points each, four to a row at the 11 point floor.
- The merchant: "Tap a stone to buy it"; a stone's card offers Buy for the bag and Set it on the rail.
- The end of a run: one card the page's width; the six numbers on the left, Highlights, the Crown Jewel and the way down behind tabs; the haul beside what shattered.
- The conquest sheet: its two halves inside the safe edges, the mines in 240 points, the next mine's new skills as name capsules, no creature silhouettes.

**Close looks and ceremonies.** The close look (`Inspector._phone_frame`) fills the screen inside its safe edges: the picture in 250 points on the left, the words on the right scrolling, a 44 point way out at the top right. A won thing's sheet (`Inspector._frame` with a fanfare) takes the screen's height between its title and its buttons. The appraisal and the Geode's crack are laid out at phone sizes (`Appraisal.phone_sheet`).

## Working on it

- **Both layouts in one change.** Every UI change is made on the desktop and the phone together (CLAUDE.md). A new screen gets its phone layout drawn first on the review page, or says it still needs one.
- **Where the code lives.** Whole pages that differ go in `view/phone/` and are called from the top of the desktop page's builder. Smaller differences are `if DeepUi.phone:` branches beside the desktop's code, with sizes in `DeepUi.pt(...)`.
- **Run it.** `godot --path . -- --phone` (or `DEEPCUT_FORM=phone`). `build/phone/pshot.sh <target> ...` shoots phone screens to `build/phone/p/` through `build/phone/shot.gd` (the desk's targets plus `bag`, `bag_read`, `ask`, `twin`, `geode_crack`, `over_haul`, `party`, `daily`, `market_*`); `build/phone/sheet.py` lays several side by side; `PHONE_PROBE=<script name>` prints the boxes of every control drawn by that script.
- **Test it.** `tests/test_fit_phone.gd` draws every page on the phone's canvas, filled as full as a player can make it, and holds each to the screen (only `may_scroll` lists scroll), the 11 point floor, and the finger's least and the safe edges for every button. It is in `tools/run_checks.py`.

## Still to do

- The end of a run's Party tab (four cards, four numbers each), and the Hollow's rite, are still the desktop's layout at phone sizes.
- The creature die window and the Tally plate keep the desktop's layout.
- Toasts stand where the desktop's do; the board moves them under the strip, one at a time.
