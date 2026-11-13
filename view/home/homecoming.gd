extends RefCounted
## Coming home: back from a run with stones on the tray, the workshop waits until the haul is
## settled. The haul is laid out on one table (haul_table.gd, the redo approved November 13,
## 2026): one press cracks it, one more settles it, and a report closes it.
##
## The same table, without the hold on the workshop, is the vault's Unappraised view. A stone
## shown on its own (a Geode cracked at the Market, a contract's stone) is read in the spotlight
## with its fates as buttons (`single_actions`).

## HomeParts first: it brings in the battle screen, whose constants the run's screen reads
## while it compiles; a script that loads this one before the run's screen needs that order.
const HomeParts = preload("res://view/home/home_parts.gd")
const HaulTable = preload("res://view/home/haul_table.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")

static func bar(home: Control, bar: HBoxContainer) -> void:
	## The top bar while coming home: where from, how the run ended, and the vault's count (where
	## the kept stones fly), in place of the tabs.
	var history: Array = home.profile.get("history", [])
	var last: Dictionary = history.back() if not history.is_empty() else {}
	var row := DeepUi.hbox(bar, 12)
	var outcome: String = str(last.get("outcome", "extracted"))
	DeepUi.title(row, ("Salvaged from %s" if outcome == "fallen" else "Back from %s") % DeepContent.mine_name(str(last.get("mine", DeepContent.starter_mine()))), 20, DeepUi.PAPER)
	var words: String = {"fallen": "fell at depth %d", "conquered": "conquered it, depth %d"}.get(outcome, "rode the lift at depth %d") % int(last.get("depth", 0))
	DeepUi.pill(row, {"fallen": "skull", "conquered": "crown"}.get(outcome, "lift"), words, DeepUi.BAD if outcome == "fallen" else DeepUi.GOOD, 12)
	vault_mark(home, row, 12)
	if not home.profile.get("tray", []).is_empty():
		DeepUi.icon(row, "lock", 16, DeepUi.DIM, "The workshop opens once the haul is settled")

static func vault_mark(home: Control, parent: Node, size: int) -> Control:
	## How full the vault is: what a kept stone flies into on the table, counting up as it lands.
	var owned: int = home.profile.get("vault", {}).size()
	var total: int = DeepProfile.known_skills(home.profile).size()
	var mark: Control
	if DeepUi.phone:
		mark = DeepUi.stat(parent, "chest", "%d" % owned, StoneCard.PIP_NEW, size, "Vault: %d of %d gems" % [owned, total])
	else:
		mark = DeepUi.pill(parent, "chest", "Vault %d of %d" % [owned, total], StoneCard.PIP_NEW, size, "Gems in your vault, of every one there is to find")
	mark.name = "VaultMark"
	var seen: int = int(home.get_meta("vault_seen", -1))
	if seen >= 0 and seen != owned and not DeepUi.headless():
		var value: Label = null
		for node in mark.find_children("*", "Label", true, false):
			value = node
		if value != null:
			var from: int = seen
			var tween := mark.create_tween()
			tween.tween_interval(0.2)
			tween.tween_method(func(v: float) -> void:
				value.text = ("%d" % int(round(v))) if DeepUi.phone else ("Vault %d of %d" % [int(round(v)), total]), float(from), float(owned), 0.8)
			tween.tween_callback(func() -> void: DeepUi.pulse(mark, 1.25, 0.35))
	home.set_meta("vault_seen", owned)
	return mark

static func build(home: Control, content: VBoxContainer) -> void:
	bench(home, content, true)

static func bench(home: Control, content: VBoxContainer, holding: bool) -> void:
	## The haul's table, kept between draws of the page so nothing it is playing is cut short.
	var key: String = "haul_home" if holding else "haul_vault"
	var table: Control = home.kept(key, func() -> Control: return HaulTable.new(home, holding))
	content.add_child(table)
	table.call("sync")

static func single_actions(home: Control, stone: Dictionary) -> Array:
	## The fates of one stone shown on its own, as the spotlight's buttons: into the vault (or in
	## place of the one kept), sold, turned in for a commission. The suggested one is filled; the
	## one that would give up the finer stone is red. Each carries itself out at once.
	var profile: Dictionary = home.profile
	var id: String = str(stone.get("id", ""))
	var offered: Array = DeepProfile.fates_for(profile, stone, [stone])
	var suggested: String = str(DeepProfile.suggest_fates(profile, [stone]).get(id, ""))
	var out: Array = []
	for fate in offered:
		var look: Array = HaulTable.fate_look(str(fate))
		var fates: Dictionary = {id: str(fate)}
		var price: int = 0
		var caption: String = ""
		match str(fate):
			"vault":
				caption = "The first of its skill is never sold"
			"replace":
				caption = "Yours is let go for no gold"
			"sell":
				price = DeepStone.value(stone)
				caption = "Yours stays"
			"turnin":
				var wanted: Dictionary = DeepEconomy.commission_for(profile, stone)
				price = DeepEconomy.payout(wanted, stone) if not wanted.is_empty() else 0
				caption = "For a commission"
		out.append({"label": str(look[1]), "glyph": str(look[0]), "tone": look[3], "price": ("+%d" % price) if price > 0 else "", "caption": caption,
			"main": str(fate) == suggested, "risky": bool(DeepProfile.costly_fates(profile, [stone], fates).get(id, false)),
			"sound": "keep" if str(fate) in ["vault", "replace"] else "sell", "fate": str(fate),
			"call": func() -> void:
				var done: Dictionary = DeepProfile.settle_tray(profile, fates)
				if not done.get("kept", []).is_empty():
					home.cheer("Kept in the vault", DeepUi.GOOD)})
	return out
