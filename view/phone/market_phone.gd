extends RefCounted
## The market on the phone (docs/PHONE_UI.md, board home-market, approved November 7, 2026).
## The desk's four parts side by side become four tabs of one page: Cut and read, Geodes,
## Commissions, The bench. Each fills the page; one taller than the screen scrolls. The Wheel's,
## the Oven's and the contract's own pages are the desk's, fitted to the phone where they are
## built (market_page.gd, November 9, 2026): two columns, each scrolling.

const MarketPage = preload("res://view/home/market_page.gd")
const HomeParts = preload("res://view/home/home_parts.gd")

const TABS: Array = [["case", "gem", "Cut and read"], ["geodes", "geode", "Geodes"], ["commissions", "flag", "Commissions"], ["bench", "hammer", "The bench"]]

static func build(home: Control, content: VBoxContainer) -> void:
	if not bool(home.profile.get("daily", {}).get("market_seen", false)) and home.profile.get("daily", null) is Dictionary:
		home.profile.daily.market_seen = true
		home.call_deferred("touch")
	match home._market_view:
		"wheel", "oven":
			MarketPage._rework_page(home, content, "cut" if home._market_view == "wheel" else "clarity")
			return
		"contract":
			MarketPage._contract_page(home, content)
			return
	home._rework_done = {}
	home._rework_hold = {}
	var head := DeepUi.hbox(content, int(DeepUi.pt(8)))
	DeepUi.icon(head, "geode", DeepUi.pt(18), DeepUi.ACCENT)
	DeepUi.title(head, "The market", 26, DeepUi.PAPER)
	DeepUi.spacer(head)
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(head, "hourglass", "New stock in %dh %02dm" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 11)
	var price: int = DeepEconomy.restock_price()
	var done: bool = DeepEconomy.restocked_today(home.profile)
	var restock := DeepUi.icon_button(head, "reroll", "Restocked" if done else "Restock", func() -> void:
		if bool(DeepEconomy.restock(home.profile).get("ok", false)):
			DeepAudio.play("buy")
			home.profile_changed.emit(), 12, DeepUi.PAPER)
	DeepUi.ledger_button(restock, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 6)
	restock.custom_minimum_size.y = DeepUi.pt(32)
	if not done:
		DeepUi.priced(restock, str(price))
		home.gold_gate(restock, price)
	restock.disabled = done or int(home.profile.get("gold", 0)) < price
	var tab: String = str(home.get_meta("market_tab", "case"))
	var tabs := DeepUi.hbox(content, int(DeepUi.pt(3)))
	## A sideways flick over the page turns them too (view/ui/swipe.gd).
	tabs.set_meta("swipe_tabs", true)
	for entry in TABS:
		var key: String = str(entry[0])
		var count: int = 0
		match key:
			"case": count = DeepEconomy.case_stones(home.profile).filter(func(e: Dictionary) -> bool: return not bool(e.get("bought", false))).size()
			"geodes": count = DeepEconomy.shelf(home.profile).filter(func(g: Dictionary) -> bool: return not bool(g.get("bought", false))).size()
		var words: String = str(entry[2]) + (" · %d" % count if count > 0 else "")
		var b := DeepUi.tab_button(tabs, str(entry[1]), words, key == tab, func() -> void:
			home.set_meta("market_tab", key)
			home._render(), 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = DeepUi.pt(34)
		if key == "commissions" and DeepEconomy.ready_count(home.profile) > 0:
			HomeParts.pin(b, DeepEconomy.ready_count(home.profile), home.PIP_READY, true)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_meta("may_scroll", true)
	content.add_child(scroll)
	var body := DeepUi.vbox(scroll, int(DeepUi.pt(6)))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match tab:
		"geodes":
			var row := DeepUi.hbox(body, int(DeepUi.pt(8)))
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var shelf: Array = DeepEconomy.shelf(home.profile)
			if shelf.is_empty():
				DeepUi.wrap(row, "Geodes come from the mines you have opened.", 13, DeepUi.DIM)
			for geode in shelf:
				var cell := DeepUi.vbox(row, 0)
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
				MarketPage._geode_card(home, cell, geode)
			home.let_go_kept("shelf|", shelf.map(func(g: Dictionary) -> String: return MarketPage._shelf_key(g)))
		"commissions":
			var holder := DeepUi.vbox(body, 0)
			holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			home.region(holder, "market_commissions", func(h: Control) -> void: MarketPage._commissions(home, h))
		"bench":
			MarketPage._bench(home, body)
		_:
			var holder := DeepUi.vbox(body, 0)
			holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			home.region(holder, "market_case", func(h: Control) -> void: MarketPage._case(home, h))
