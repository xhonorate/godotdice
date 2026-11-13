# Deep start: the contract for the view

Revised November 6, 2026 (playtest round 5). The first version was round 4 of November 5.

This is what the sim gives the screens when a party sets out in a mine below the first one,
and what the screens send back. It also covers the charges (Hammered, A Wild Face) at every
shaft head, and the smithy and carver's better work.

- Code: `sim/boons.gd` (the cards and charges), `sim/descent.gd` (the run, rooms, benches),
  `sim/oddities.gd` (the better room work), `sim/content.gd` (`DeepContent.plain`).
- Content (`content/deep_cut.json`): `boons`, the `improved` blocks on the SMITHY and CARVER
  oddities, and the constant `bench_upgrade_chance`.
- Tests: `tests/test_descent.gd` (`_test_deep_start`, `_test_deep_start_round5`).

## 1. What a deep start is

A run is a deep start when its mine is not the starter mine and it is not a daily dig.

- **k** is the number of mines it skipped, read from the pack's mine order
  (`DeepContent.mines_in_order`): Seeps 1, Glass Veins 2, Warrens 3, Furnace 4, Geode 5,
  Rift 6.
  - `DeepDescent.mines_skipped(mine_key)` returns k.
  - `DeepDescent.skipped_mines(mine_key)` returns the skipped mines, shallowest first.
- The run carries **`state.deep_start = k`**. It is absent on a Quarry run and on a daily.
- It opens at the shaft head (`state.phase == "grubstake"`), unless the config says
  `boons: false`. Players keep the mine's `start_pyrite`.
- **No temporary stones and no dice swaps.** `unit.temps` is `[]` and `unit.dice_offers` is
  absent, so `temporary_left` and `dice_offers_left` are 0 and those pages never show.
- A Draft daily still has its temporary stones.
- **A Birthstone that grows over a run starts with a head start** (November 13, 2026;
  docs/CHARACTERS.md §7). Renown opens with Trophies and Bloodroot with max health, a share of
  the floors the skipped mines hold (the stone's `head_start`, in percent).
  - `DeepDescent.birthstone_head_start(unit, mine_key)` works it out. `new_run` applies it and
    keeps what it gave in `unit.head_start` (`{"trophies": n}` or `{"max_hp": n}`).
  - The Descend page's stratum card and the shaft head say it ("Renown opens with 24
    Trophies"), through `Plates.birth_opens`.
- A run saved mid-shaft-head before round 4 still answers its old `temps` and `dice_offers`.

## 2. The shaft head: `state.grubstake.offers[unit_id]`

**A deep start always shows three cards, at every k: two deep cards, then one stronger Quarry
stake.** The ids are `"stake0"`, `"stake1"` (the deep cards) and `"stake2"` (the stronger stake).

- The two deep cards are drawn by weight from the `deep` group, without repeats. Heirloom
  Polish is never offered to an empty rail.
- The stronger stake is drawn by weight in one draw from `DeepBoons.stronger_pool(unit)`:
  - every stone stake;
  - every kit stake (only the mercy-tagged ones for a player shown mercy);
  - every reward, taken alone.
- **There are no terms at a deep start**: no cost is ever offered.
- **Never offered at a deep start:** a boon marked `shallow_only` in content (Steady Hands,
  Soft Rock).
- Never offered to an empty rail: a stake that only works on set stones.
- No boon appears twice. The same seed always gives the same hand.

The Quarry's own hand (a run in the first mine) is unchanged: stone, kit, terms. Checked seed
for seed over 30 seeds × 3 players. The only differences are that Hammered and A Wild Face
now carry charges (section 3).

### Fields on every offer

| field | type | meaning |
|---|---|---|
| `id` | String | `"stake0"` .. `"stake2"`. |
| `kind` | String | `"deep"` for a deep card. For a stake, its group: `"stone"`, `"kit"` or, at a deep start, `"reward"`. At the Quarry, `"terms"` for a cost and a reward. |
| `boons` | Array[String] | Boon keys in `content.boons`. Two only for Quarry terms (cost first). |
| `needs` | Array[String] | Any of `"pick"`, `"picks"`, `"swaps"`, `"charges"`, `"socket"`. `"socket"` needs no payload; the sim draws the socket. |
| `picks` | Array | Candidates (see below). |
| `pick_kind` | String | `""`, `"stone"`, `"stones"`, `"dice"` or `"material"`. |
| `charges` | Dictionary | Only on Hammered and A Wild Face, at every shaft head: `{"kind": "resize"\|"wild", "count": N}`. See section 3. |
| `k` | int | Mines skipped. On every deep-start offer; absent on Quarry offers. |
| `deep` | bool | `true` on a deep card. |
| `upgraded` | bool | `true` on the stronger stake (the "Better" tag). |
| `names` | Array[String] | Boon names. |
| `texts` | Array[String] | **Filled with this offer's numbers.** Always show these at a deep start. Quarry offers have none: read content `text`. |
| `mercy` | bool | A kit stake offered as mercy. |

### The deep cards

| key | `needs` | extra fields | text at k = 1 / 3 / 6 |
|---|---|---|---|
| `BAG_OF_GEMS` | `["picks"]` | `picks`: 4 + k read stones (`"stones"`); `take`: 1 + ceil(k/2) | Take 2 of 5 / 3 of 7 / 4 of 10 read stones from the mines above. |
| `BAG_OF_DICE` | `["swaps"]` | `picks`: 2 + k whole dice (`"dice"`), each with its own id `"<unit>_bag<i>"` | Swap any of your dice around with 3 / 5 / 8 random ones drawn from the bag. *(the owner's own words: the one card over 60 characters, allowed up to 80)* |
| `ONE_MATERIAL` | `["pick"]` | `picks`: 3 material keys (`"material"`), never the one every die shares | Every die you carry takes one material: pick of 3. |
| `HEIRLOOM_POLISH` | `[]` | `carats`: k, `cut`: 1 | Stones you brought gain 1 carat / 3 carats / 6 carats and a Cut step this run. |
| `DEEP_PURSE` | `[]` | `ore`: 60k; `stones`: 2 + floor(k/2) raw stones | 60 pyrite and 2 raw stones / 180 and 3 / 360 and 5 … from the mines above. |
| `SMITHS_VOUCHER` | `[]` | `rooms`: k | 1 voucher / 3 vouchers / 6 vouchers for better upgrades at the smithy or carver. |

The stones in a Bag of Gems or a Deep Purse come from the skipped mines' own pools, at each
mine's bottom depth.

- `provenance.source` is `"deep_start"` and `provenance.mine` names the skipped mine.
- A card's stones have different skills, none the player already holds, never an opal and
  never fragile.
- The loadout luck applies to each roll, and taking them never changes `loadout_luck`.
- They are ordinary finds.

### The stronger stake

These are the Quarry's own boons made better (`DeepBoons.upgraded_effect`). Their words are
the content `deep_text`, filled by `DeepBoons.stake_text`.

| boon | Quarry (k 0) | k = 1 | k = 3 | k = 6 |
|---|---|---|---|---|
| Staked | 40 pyrite | 80 | 160 | 280 |
| Well Staked | 90 pyrite | 180 | 360 | 630 |
| Hardy | +12% health | +18% | +30% | +48% |
| Iron Constitution | +25% health | +31% | +43% | +61% |
| A Read Stone, Pick of Three | depth 4 | depth 6 | depth 10 | depth 16 |
| A Fragile Find | depth 20 (“deeper in the mine”) | 20 (Seeps bottom) | 24 | 32 |
| Weighed Heavier | +2 carats | +3 | +5 | +8 |
| Four Carats | +4 carats | +6 | +10 | +16 |
| A Truer Set | +1 Cut step | +1 | +2 | +3 |
| Hammered | 1 size upgrade | 2 | 4 | 5 |
| A Wild Face | 1 wild face | 2 | 3 | 4 |
| The Whole Rail | +1 carat, +1 Cut, +1 Clarity | +1 carat | +2 carats | +4 carats (Cut and Clarity still +1) |

Formulas: ore × (1+k); health +6k; depth +2k (never below the starting mine's bottom);
carats + amount × k / 2; Cut + floor(k/3); Hammered min(1+k, 5); A Wild Face
min(1+ceil(k/2), 5); The Whole Rail's carat + floor(k/2).

**Where a better stake's stone comes from.** "Depth 10" means depth 10 *of the mine the party
starts in*, not of the Quarry. The stone is rolled exactly as that mine rolls a find at that
depth: its skill pool, its luck and its carat band. A Warrens start's better Read Stone is a
depth-10 Warrens stone (soft carat cap 9, cap 13), and `provenance.mine` says `"WARRENS"`.
`_test_deep_start_round5` pins this on Warrens and Rift starts.

## 3. Charges: Hammered and A Wild Face (every shaft head)

These two cards no longer pick a random die: the player chooses.

- **Quarry**: 1 charge.
- **Deep**: Hammered min(1 + k, 5) charges; A Wild Face min(1 + ceil(k/2), 5) charges.
- The offer has `needs` containing `"charges"`, and `charges = {"kind": "resize", "count": N}`
  (Hammered) or `{"kind": "wild", "count": N}` (A Wild Face).
- Quarry terms that pair A Wild Face with a cost carry it too.
- **Payload: `{"dice": [die_id, ...]}`**, in click order.
  - Repeats are allowed: the same die may take several charges.
  - It has 1 to N entries. Charges left unused are lost.
  - Refused: no entries or more than N ("choose a die for each of up to N charges"); an id
    that is not the player's ("that is not one of your dice"); a charge on a die that cannot
    take it once the earlier charges have landed ("that die cannot be made any bigger",
    "every face of that die is wild already").
- **resize**: the die becomes one size bigger. A die already as big as dice come cannot take
  one.
- **wild**: the die's **lowest face that is not wild yet** turns wild (the first such face on
  a tie). For example 1/2/3/4/5/6, then */2/3/4/5/6, then */*/3/4/5/6. A die with every face
  wild cannot take one.
- For the view, so it never repeats the rule:
  - **`DeepBoons.can_charge(die, kind) -> bool`**: whether one more charge may land on this
    die as it is now.
  - **`DeepBoons.charge_preview(unit, kind, dice_ids) -> Array`**: the unit's dice after
    those charges, as copies, worked by exactly the code `apply` uses. The unit's own dice
    are untouched; an invalid charge is skipped.
- Card texts:
  - Quarry Hammered: "One size upgrade: the die you choose is one size bigger for this run."
  - Quarry A Wild Face: "One wild face: the lowest face of the die you choose turns wild."
  - Deep Hammered: `{count#size upgrade}: each makes a die you choose one size bigger.`
  - Deep A Wild Face: `{count#wild face}, each on the lowest face of a die you choose.`
- The `staked` event carries `dice` (the dice changed, as they now are) and `charged` (the ids
  in click order).

## 4. Taking a card

The command is `{"kind": "stake", "offer": "<id>", "payload": {...}}`, only during
`"grubstake"`.

| card | payload |
|---|---|
| Bag of Gems | `{"picks": [i, ...]}`: exactly `take` different indices into `picks`. |
| Bag of Dice | **`{"hand": [die_id, ...]}`**: the player's dice as they will be, in slot order. Each id is from their own dice or the bag's, each used once, exactly as many as they carry. A plain reorder is a hand too. Refused: a hand of the wrong size, an id from neither, an id twice. The older `{"swaps": {"<bag index>": "<own id>"}}` still works. |
| One Material, Pick of Three | `{"pick": i}` |
| Hammered, A Wild Face | `{"dice": [die_id, ...]}` (section 3) |
| everything else | `{}` |

Bag of Dice, as it lands:

- Each bag die taken takes the id of one of the player's dice left out, in slot order, so the
  bowl keeps the same set of ids.
- Dice left out are gone for the run, and so is every bag die not taken. The bowl at home is
  untouched.
- The `staked` event says `swapped: [{"die_id", "pick", "slot"}]`; the result's `hand` is the
  final id list.
- The message is "You swap …", "You set your dice in a new order." or "You keep your dice."

The other cards, as they land:

- Bag of Gems: the stones taken go into the bag.
- One Material: every die takes the material.
- Heirloom Polish: every brought (lent) rail stone gains `carats` carats and `cut` Cut steps,
  marked `staked`.
- Deep Purse: the pyrite, and the raw stones into the bag.
- Smith's Voucher: `unit.vouchers += rooms`.

### The `staked` event

Unchanged fields: `unit`, `offer`, `boons`, `message`, `made`, `dice`, `changed`, `pick`, and
`finished`. Added:

| field | when |
|---|---|
| `deep` / `upgraded` and `k` | a deep card / the stronger stake |
| `swapped` | Bag of Dice |
| `material` | One Material |
| `vouchers` | Smith's Voucher: how many the player now holds |

## 5. The smithy and the carver: vouchers and lucky benches

### When a player is shown the better work

**`DeepDescent.bench_upgrade(state, unit_id) -> String`** answers for the room the party
stands in:

- **`"luck"`**: a lucky bench, for the whole party, free.
- **`"voucher"`**: this player spent a Smith's Voucher on this visit.
- **`""`**: the plain work. Every room that is not a smithy or a carver answers `""`.

Lucky benches:

- Entering a smithy or carver has a `bench_upgrade_chance` chance (content constant, 0.05)
  that the room is lucky (`state.chamber.lucky = true`).
- The roll comes from a stream named for the run's seed, the mine, the floor, the room kind and
  the room id (`DeepDescent.bench_lucky`). The same room is always as lucky; a reload or
  rejoin never rolls again (the answer is also saved on the chamber); and no other stream of
  the run moves.
- **In a lucky room nobody's voucher is spent.**

Vouchers:

- Otherwise, every player still standing who holds a voucher spends one on entering,
  whether or not they then take any work. They are listed in `state.chamber.vouchered`.
- The `enter_chamber` event carries the whole chamber, `lucky` and `vouchered` included.

### `DeepDescent.room_choices(state, unit_id) -> Array`

The room card must list one player's choices through this function. When `bench_upgrade` is
not `""`, each choice that has an improved version is shown in its place. That choice:

- keeps the same `id`;
- has **`improved: true`** (show the shiny badge);
- has its own `label`, `text`, `needs`, `most` (3, on the face services) and `action`.

`"pass"` is never improved. The rules look choices up through the same function.

| room | id | improved label (marks shown) | needs | payload |
|---|---|---|---|---|
| Smithy | hammer | Hammer a die \*\*two sizes\*\* bigger | `"die"` | `{"die_id"}` |
| Smithy | file | File a die \*\*two sizes\*\* smaller | `"die"` | `{"die_id"}` |
| Smithy | stamp | Stamp the pattern on \*\*every\*\* die | `""` | `{}` |
| Carver | raise | Raise \*\*three\*\* faces | `"die_faces"`, `most` 3 | `{"picks": [{"die_id", "face"}, ...]}` (1 to 3 faces, none twice) |
| Carver | lower | Lower \*\*three\*\* faces | `"die_faces"`, `most` 3 | the same; a blank face or a 1 refuses the whole pick |
| Carver | etch | Etch the \*\*top face of every\*\* die | `""` | `{}` |

- The improved `text`s mark their upgrade the same way, for example "Raise one die \*\*two
  tiers\*\*, as far as dice go. …" and "The needles' etching goes on the \*\*top face of
  every\*\* die you carry."
- The `oddity_result` event gains:
  - `improved: true` and **`upgrade`** (`"luck"` or `"voucher"`) on an improved choice;
  - `faces` (`{die_id: face}`);
  - `picks` on a three-face service.

### The upgrade marks

The improved `label` and `text` wrap the words that show the upgrade in **`**double
asterisks**`** (`DeepContent.UPGRADE_MARK`). The view colours what lies between.

- Anywhere that shows the words plain must read them through **`DeepContent.plain(text)`**,
  which strips the marks.
- Only improved words carry marks, and every mark is closed. The content validator checks
  both.
- The sim's own messages (event `message`) never carry them.

## 6. Where the words come from

- **Deep cards**: content `boons.<KEY>.text`, filled by `DeepBoons.deep_text(offer)` into
  `offer.texts`. Tokens: `take`, `offered`, `count`, `carats`, `ore`, `raw`, `rooms`, `k`,
  and `{token#noun}` for plurals.
- **The stronger stake**: content `deep_text`, filled by `DeepBoons.stake_text(state, key, k)`
  into `offer.texts`.
- **Quarry stakes**: content `text`.
- **Improved room work**: content `oddities.SMITHY` / `CARVER` `choices[i].improved`, returned
  by `room_choices`.
