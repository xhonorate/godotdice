# Characters: the roster that replaced settings

Second draft, September 21, 2026, with the owner's first-round notes folded in. **Implemented the
same day**: Puck was chosen as the sixth character, Vesper's requirement is the recommended one, and
Florin keeps his Bust tier. The content lives in the `characters` section of `content/deep_cut.json`,
the Birthstone resolves in `DeepBattle.resolve_birthstone`, and `tests/test_battle.gd` covers every
tier and passive. The headshots are drawn and wired in (§4, October 20, 2026); the six Birthstone cuts are still to draw: each borrows
the nearest of the six outlines and is told apart by its tint and emblem for now. The jewellery "settings" of §5 in `REIMAGINING.md` become **characters**: a lapidary
you play, each with five colored gem sockets, a set of starting dice, a passive, and a
**Birthstone**: a fixed personal gemstone that sits last in the rail and cannot be removed or
swapped. Combat stays first person; a character is a headshot and a handful of reaction faces,
never a body on screen.

Fire rates come from `tools/capstone_odds.py`: 200,000 hands per line, two rerolls spent by a greedy
policy that chases the character's own Birthstone. "Res" is Resonance when the Birthstone resolves.
"Block" is the game's word for shield, and block now falls off at the end of every turn.

## 1. Shared rules

- **Five sockets**, each Red, Blue, Green, Violet, Gold, White or Any. **Every character has at least
  one Red socket.** One character has six sockets and pays for it elsewhere.
- The **Birthstone** is last in the rail, always. Its cut and material sit outside the six-color
  language so it can never be mistaken for a socketable stone. Every gem that fires before it feeds
  its Resonance, as the Capstone socket does today.
- A Birthstone has **tiers**. Every tier the final hand satisfies fires: a triple also fires the pair
  tier, a large straight also fires the small one.
- Thresholds on totals and "low" dice are **relative to each die's maximum**, as everywhere else.
- Two players may pick the **same character**. Name plates are tinted to tell them apart.
- **Unlock order.** Ardor is the starter. Every other lapidary joins when the final boss of the mine
  above theirs falls: Vesper with the Quarry's boss, Cadence with the Seeps', Rue with the Glass
  Veins', Puck with the Warrens' and Florin with the Furnace's.

## 2. The roster

| Character                         | HP  | Dice (mean)                 | Sockets                        | Passive                    | Birthstone reads                  |
| --------------------------------- | --- | --------------------------- | ------------------------------ | -------------------------- | --------------------------------- |
| **Ardor**, the Knight             | 80  | d6 d6 d6 d8 d8 (19.5)       | Red, Blue, Green, Any, Any     | Heal Resonance per unused reroll | Sets                        |
| **Vesper**, the Rogue             | 65  | d4 d4 d4 d4 d12 (16.5)      | Red, Red, Any ×4               | Block per hit dealt        | Five different values             |
| **Cadence**, the Wizard           | 70  | d4 d6 d8 d10 d12 (22.5)     | Red, White, Violet, Any, Any   | +1 reroll                  | Straights                         |
| **Rue**, the Apothecary           | 70  | d4 d4 d6 d6 Phial (13.7)    | Red, Violet, Green, Any, Any   | Heal Res when poison ticks | Low dice and ones                 |
| **Florin**, the Gambler           | 60  | five d6 with 7 for 6 (18.3) | Red, Gold, Gold, Any ×4        | All or Nothing             | Crowns                            |
| **Sixth**: Harrow, Blaise or Puck |     |                             |                                |                            | High total, explosions, or parity |

### Ardor, the Knight

_The wall. Locks in early, heals for patience, and turns a lucky triple into a hammer._

- **HP** 80. **Dice** d6 d6 d6 d8 d8. **Sockets** Red, Blue, Green, Any, Any.
- **Passive: Second Wind.** Heal, for each unused reroll, the Resonance your rail built — paid as the rail closes, because at the start of it there is no Resonance yet to heal on. Patience is worth what the chain was worth.
- **Birthstone: Rally.**
  - Pair (_Rank_): gain Res block.
  - Triple (_File_): deal 3×Res damage.
  - Four of a kind (_Phalanx_): cleanse your afflictions and stun the target for a turn.
  - Five of a kind (_Legion_): deal 5×Res damage, five times.
- **Fire rates.** Natural hand, banking both heals: pair 83%, triple 16%, quad 1%. Chasing with two
  rerolls: pair 99%, triple 65%, quad 22%, quint 3%. Heal or chase is the Knight's decision every turn.
- **Stone.** Almandine garnet in a shield (kite) cut: opaque, blood-red, an iron sheen, the only
  flat-topped Birthstone. **Birthstone face:** jaw set, eyes narrowed, a slow nod.

### Vesper, the Rogue

_The assassin's gamble. Four tiny knives and one enormous die._

- **HP** 65. **Dice** d4 d4 d4 d4 d12. **Sockets** Red, Red, Any, Any, Any, Any.
- **Passive: Riposte.** Gain Res block for every hit one of your gems lands. Block falls off at the end
  of the turn, so a big Birthstone turn is a wall for that turn only.
- **Birthstone: Thousand Cuts.** Five different values: deal Res damage once for every point on your
  highest die (a d12 showing 7 is seven cuts). _Clean Kill_: a crown on that die as well lands
  every cut twice.
- **Combo.** Curse in an Any socket, then the Birthstone. Etch before it marks every cut, since
  Marked is spent per gem (October 23, 2026).
- **Stone.** Black opal in a needle-thin marquise: dark body, a thousand pinprick flashes.
  **Birthstone face:** a thin smile, eyes on the target.

**Reworked October 23, 2026.** The first rule, five different values with the top die outrolling the
other four combined, asked for arithmetic at the tray, and on the fight sim's hunted rails, where
the rerolls chase the gems, it fired 0.0 times in four turns. The owner chose the plain rule for its
plainness, knowing it balloons as the small dice grow (dice-only model, two rerolls, chasing it):

| Bowl                  | Fires | Cuts | Res multiplier a turn |
| --------------------- | ----- | ---- | --------------------- |
| Start d4 d4 d4 d4 d20 | 44%   | 12.5 | 5.6×                  |
| Mid d4 d4 d6 d8 d20   | 72%   | 12.6 | 9.1×                  |
| Late d6 d8 d8 d10 d20 | 88%   | 12.7 | 11.1×                 |

Clean Kill comes on 5% of natural hands and 12% chased. The owner's lever against the balloon, a d12 in place of the d20 to start, was taken: the model gives it 3.× on the starting bowl, 6.× mid-run and 7.× late (4.×, 6.× and 8.× with Clean Kill, which comes 5 to 10% of chased turns on a d12), beside the old rule's 3.×, 5.× and 5.×; the d20 would have been 5.×, 9.× and 11.×. It also takes a fifth off her Hemlock pace in the gem sweep (the single gem reading her highest die) and puts Apex (16+) and Temper (12+) where Cadence has them. Her first bowl mean falls from 20.5 to 16.5; a d20 remains one upgrade away. The rules the owner turned down
are on the review page: the long knife (the top die at 85% of its top, 9× on every bowl), the lead
(top die minus second, every turn), Ambush, Execute and Bleed riders.

### Cadence, the Wizard

_The combo player. Runs of numbers, and the turn that plays twice._

- **HP** 70. **Dice** d4 d6 d8 d10 d12. **Sockets** Red, White, Violet, Any, Any, Any.
- **Passive: Study.** +1 reroll every turn.
- **Birthstone: Encore.**
  - Three in a row (_Motif_): the last gem that fired plays again, at full strength. It is queued
    after the Birthstone, Echo's way, so the Resonance it rings comes too late for Encore itself.
    Added October 23, 2026: a run of three is 75% of chased turns with two rerolls and 85% with
    Study's third (31% of natural hands), and until then most of her turns ended with one and
    nothing to show for it.
  - Small straight, four in a row (_Overture_): deal 4×Res damage to every creature. (The owner
    kept 4× on October 23, 2026, over the 5× picked on the balance page the day before.)
  - Large straight, five in a row (_Encore_): replay every gem that fired this turn from the first
    socket onward, Overture included. Resonance keeps climbing through the replay. **Replayed gems do
    exactly what they did the first time, hand mutations included**: a Glimmer raises the lowest die
    again, a Refract adds a second phantom, so the hand the later gems read is bigger the second time.
    Motif fires on the replay pass too, so the last gem plays once more after it.
- **Fire rates.** With the passive's three rerolls: small 50%, large 15%. With two: 37% and 9%.
- **Stone.** Ametrine, violet fading to gold, in a step cut: a staircase of facets.
  **Birthstone face:** eyes closed, one hand raised like a conductor.

### Rue, the Apothecary

_The low roller. Wants ones. Everything the other five dread, Rue drinks._

- **HP** 70. **Dice** d4 d4 d6 d6 and **the Phial**, a d6-shaped die with faces 1 1 1 2 2 3
  (bowl mean 13.7). Judged against its d6 shape, every Phial face is low. **Sockets** Red, Violet,
  Green, Any, Any.
- **Passive: Leech.** Heal Res whenever poison damages a creature, Res being the final Resonance of
  your last rail. Three poisoned creatures means three heals a turn, which is what Miasma is for.
- **Birthstone: Bitter Draught.** A die is _low_ when it shows half its maximum or less.
  - Four or more low dice (_Tincture_): poison the target for Res.
  - All five low (_Draught_): every poison on every creature ticks immediately, once.
  - All five showing 1 (_Dregs_): every poison on every creature ticks Res times.
- **Fire rates.** Chasing low: 92%, 58%, and Dregs 0.8%. Chasing ones instead: 63%, 22%, and Dregs
  5.2%. Two lanes, picked each turn from the forecast.
- **Why it works.** Bulwark, Wager, Ember, Miasma and Venom read low or even dice, and Mend reads the
  lowest. This is the only bowl that makes those Rare stones look good.
- **Stone.** Dark tourmaline briolette, a faceted teardrop, murky green-black with a trapped bubble.
  **Birthstone face:** a wry grimace, as if tasting it.

### Florin, the Gambler

_The seven-socket high roller. Every roll is all or nothing._

- **HP** 60. **Dice** five **Gambler's Dice**: d6s whose 6 is a 7 (faces 1 2 3 4 5 7, bowl mean
  18.3). The 7 is the crown, and it is the face Lucky Seven pays on. **Sockets** Red, Gold, Gold,
  Any, Any, Any, Any (seven).
- **Passive: All or Nothing.** Florin throws all his dice together or none of them: a reroll throws
  the whole bowl, so no gem's pattern can be chased. Every crown that comes up, on any throw,
  phantom dice and a die a gem turns onto its top face included, adds 1 Resonance; the throws of
  the planning phase bank it before the rail starts.
- **Birthstone: High Roller.** A _crown_ is a die showing its top face. Every tier the hand reaches pays.
  - One crown or more (_Lucky_): deal Resonance for each crown showing.
  - Two or more (_Heating Up_): +1 reroll next turn.
  - Three or more (_Hot Streak_): a phantom Gambler's die joins next turn's throw. It is thrown and
    rerolled with the hand and leaves after that turn, unless a Contra Luz keeps the turn's phantoms.
  - Four or more (_On Fire_): next turn High Roller reads double the whole Resonance total.
  - Five or more (_Jackpot_): deal 7× Resonance seven times, and gain 7× Resonance in pyrite.
  - None (_Bust_): lose Resonance in pyrite, as much as the bank holds, then take Resonance as
    damage. Block soaks it.
- **The streak.** What one turn earns the next one rides on, and the battle screen wears it:
  embers off the tray for Heating Up, flames along it for a Hot Streak (the bonus die gold-rimmed),
  burning dice, heat at the screen's edges and his victory face On Fire, a slot machine's lights for
  a Jackpot, smoke for a Bust. His seat tab and the run strip carry a flame for the whole table.
- **Odds** (dice-only model, two rerolls, a rail ringing 5 on its own): about 2.2× Resonance a turn
  when he rerolls one-crown hands, busting 1 turn in 4; 1.8× when he stops on any crown, busting 1 in
  18. The Jackpot comes about 1 turn in 2,700 on bare dice; face changes and extra rerolls bring it closer.
- **What the seventh socket costs.** Lowest HP, a flat bowl, and rerolls that cannot chase a pattern.
  Wild and Twin faces are the Gambler's shopping list.
- **Reworked October 22, 2026.** House Money and the pot (Ante, Raise, All In) are gone: the pot was
  never spent, so every fire dealt it again, it doubled for free on a win, and it grew with the bank,
  which made Florin's Birthstone cut his boss kill time by a third to four fifths against 0 to 15%
  for everyone else. Refract and Mirror changed at the same time, because their copies of a 7 kept
  the new ladder lit (Refract now rolls a phantom copy of the largest die; Mirror reflects half of
  the next enemy attack).
- **Stone.** A pyrite cube, fool's gold, which forms as a perfect cube in nature: the Birthstone is a
  metal die. **Birthstone face:** wide eyes, a whoop.

## 3. The sixth character: three candidates

Wren the Lamplighter is withdrawn: a party-scaling passive punishes solo players, and the class was
dull. Each candidate below reads a pattern family nobody else uses, has a Red socket, and works
identically alone or in a party. **Puck was chosen.** Harrow and Blaise stay here as candidates for
a later roster.

### Harrow, the Berserker

_Big dice, big totals, and the less HP you have the harder you hit._ (alt names: Brann, Gorse)

- **HP** 90. **Dice** d8 d8 d10 d10 d12 (mean 26.5, the biggest bowl in the game; d6 d8 d10 d10 d12
  at 25.5 is the tamer alternative). **Sockets** Red, Red, Blue, Any, Any. Riposte in the Blue socket
  turns the hits he takes into damage.
- **Passive: Bloodrush.** Your rail starts at +1 Resonance for every 20 HP you are missing, up to +4.
- **Birthstone: Rampage.**
  - Total at or above 60% of the hand's maximum (_Charge_): deal 2×Res damage.
  - At or above 75% (_Frenzy_): also deal Res damage to every other creature.
  - At or above 90% (_Rampage_): deal 5×Res damage and stun the target.
- **Fire rates** chasing high dice: 92%, 53%, 2.7%. Natural: 38%, 8%, 0.2%.
- **Stone.** Bloodstone, dark green shot with red, in a heavy cushion cut with one corner chipped.
  **Birthstone face:** a roar.

### Blaise, the Sapper

_Blasting powder in a mine. Dice that explode, damage that splashes._ (alt names: Cinder, Pyke)

- **HP** 65. **Dice** five **Powder Kegs**: exploding d6s, a 6 rolls again and adds (natural mean
  about 21). **Sockets** Red, Violet, Gold, Any, Any. A 6 that rolls a 1 is a 7, which Lucky Seven
  pays.
- **Passive: Splash.** Whenever one of your gems damages a creature, the creatures beside it take Res
  damage. Once per gem that fires, not per hit.
- **Birthstone: Chain Reaction.**
  - Each die that exploded this turn (_Spark_): Res damage to every creature.
  - Three or more dice exploded (_Blast_): strip the target's block and stun it.
  - Any die that exploded three times (_Chain Reaction_): deal 10×Res damage to every creature.
- **Fire rates** chasing explosions: 94%, 36%, 5.7%. A double explosion shows up 31% of turns and
  could carry a fourth tier if wanted.
- **Cost.** Five Rare dice is a rich bowl, paid for with 65 HP and a Birthstone that does nothing on a
  hand with no sixes. Needs the sim to count explosions per die, which it does not yet.
- **Stone.** Fire opal cut as a faceted sphere, a bomb, with a single needle inclusion for a fuse.
  **Birthstone face:** fingers in ears, grinning.

### Puck, the Harlequin

_Two faces. You choose which one the enemy sees, every turn._ (alt names: Quip, Jinx)

- **HP** 70. **Dice** d6 d6 d8 d8 d10 (21.5). **Sockets** Red, Blue, White, Any, Any, Any.
- **Passive: Sleight.** Once a turn, turn one die over. The face underneath is the other parity: the
  face mirrored across the die's range (a 2 on a d6 to its 5) when the die has that face, else the
  nearest face of the other parity it does have, so a patterned die is only ever turned to a number
  it can show. A die whose faces are all even or all odd (an Even, Odd or Stretched die) cannot turn,
  and the button says so. The Harlequin can almost always finish a hand in one parity.
- **On the tray (October 23, 2026).** Her odd dice wear a pink rim light and her even dice a green
  one, the two halves of her tourmaline, and the tray's title line counts them ("3 cruel · 2 kind ·
  one turn from the Cruel Face"). Hovering a die shows the face it would turn to as a ghost; a
  right-click, a long press, or F with the die picked turns it over on the spot, and the button
  reads "Turn over". Shift+right-click still opens the die.
- **Birthstone: Motley.**
  - All five dice odd (_the Cruel Face_): deal 3×Res damage to the target.
  - All five dice even (_the Kind Face_): gain 3×Res block.
  - All five one parity and all distinct, a skip straight like 2-4-6-8-10 or 1-3-5-7-9
    (_Full Motley_): both, doubled, and the target is stunned.
  - **The Changing Face** (October 23, 2026): a face different from last turn's pays double, and
    every turn running the faces keep changing pays one more: ×2, ×3, ×4… Full Motley is
    multiplied too. The same face twice running, a mixed hand or a stunned turn starts it over.
- **The run, on screen.** The ×N beside the Resonance count says what the other face is worth this
  turn (and a chip over her tab says which face that is). From ×2 a ribbon of pink and green squares
  runs round the tray, faster the longer the run, with motley drifting up off it; when the face
  turns at the Birthstone the tray flashes in that face's color, motley bursts off it and the room
  is told "CHANGING FACE ×N". The count under the tier's name says "Changing Face ×N" too.
- **Fire rates.** A single face is reachable 96% of chased turns, so the choice each turn is attack or
  defend, not whether. Full Motley is 6.4% when chased, and chasing it drops the safe tier to 77%.
- **Why it is different.** Every other Birthstone is a gamble. This one is a decision, which is a
  playstyle the roster otherwise lacks, and the shift is a small, satisfying action.
- **Reviewed October 23, 2026.** Nine directions were offered (majority Motley, a whole-hand turn,
  masks, a patchwork of colors, crowns and ones, called rerolls, rail shuffling, the Changing Face,
  wild cards); the owner kept Sleight and Motley as they were, took the Changing Face with its run
  stacking, and asked for the tray to show the faces.
- **Stone.** Watermelon tourmaline, pink one half and green the other, in a checkerboard cut.
  **Birthstone face:** one eye winking, mouth half grin, half frown.

## 4. Headshots

Eight states per character, the same eight for everyone so panels and tests stay uniform:

1. Idle. 2. Rolling (eyes down on the dice). 3. Wince (took damage). 4. Bloodied (under half HP).
2. Critical (under a quarter, the Duke Nukem face). 6. Birthstone (unique per character, listed
   above). 7. Downed. 8. Victory.

**Built October 20, 2026, as 2D art** (the owner turned down the 3D busts recommended here; stones
and dice stay 3D, the faces are the one hand-drawn element). Each face is a 512 square PNG with a
transparent background at `view/home/delvers/<delver>/<mood>.png`, imported with mipmaps, made in
ComfyUI from the owner's own mockups. `Roster.Portrait` (`view/home/roster.gd`) draws one on the
plate lit in the Birthstone's tint, cut to the kit's chamfered corners: the whole bust at 120 px and
over, closing in on the face as the plate shrinks to the size of a word. Key and mood can change on
a built plate, and a new face fades in over the old in 0.12 s.

Where the moods come from:

- **Resting**, from health as the bars read it (`Roster.resting_mood`): idle, bloodied under half,
  critical under a quarter, downed once the blow that downs them has landed.
- **Passing**, for a moment, then back to resting (`_react` in `battle_screen.gd`): rolling while
  their dice tumble (each roll and reroll), wince for 0.9 s on any hit that takes health (0.7 s for
  a poison or burn tick), their Birthstone face for 1.8 s when it fires (a wince for a Bust).
- **Victory** for everyone still standing once a fight is won.

Where the faces are: the left of each player's page in the battle dock (it rocks with a flinch and
jumps with the Birthstone), each seat tab in a party (ringed in the seat color), each player in the
run's top strip (resting mood only), a party member's inspector sheet, and every roster and home
plate that showed the Birthstone before. A delver with no faces drawn still shows their Birthstone.

## 5. Decided and still open

Decided in the first round: the player-facing word is **Birthstone**; Ardor heals 3; Riposte is per
hit; Encore replays mutations; duplicates are allowed; Ardor, Vesper, Cadence unlock in that order;
every character has a Red socket.

Settled at implementation: Vesper fires on five distinct values with the top die outrolling the
other four combined (no tray-order tier); the sixth character is Puck; Florin keeps Bust, which is
one tier in the content and trivial to remove. Harrow's bowl is moot until he is added.

## 6. Implementation sketch (after approval)

- **Content.** `settings` becomes `characters`: name, title, hp, dice, sockets (five or six colors,
  no CAPSTONE entry), passive, birthstone (name, stone style, tiers in the rules language). New dice:
  the Phial, the Gambler's Die, and if Blaise is chosen the Powder Keg is the existing exploding d6.
  New triggers: `distinct_dominant`, `tray_ascending`, `all_value`, `low_count`, `crowns`,
  `same_parity`, `skip_straight`, `exploded_count`, `max_explosions`. New effects: `replay_rail`,
  `stone_drop`, `tick_poison(times)`, `ore_loss`. New passive kinds: `heal_per_unused_reroll`,
  `block_per_hit`, `heal_on_poison_tick`, `free_reroll_value`, `start_resonance_missing_hp`,
  `splash`, `free_flip`.
- **Sim.** The Birthstone becomes a fixed final rail entry built from the character, not a socket the
  bench fills. Tier evaluation fires every satisfied tier in order. Block clears at end of turn (done).
  If the tray-order tier is taken, dice keep their bench order through a fight. If Blaise is taken,
  the hand records explosions per die. If Puck is taken, `flip` is a new player command like `reroll`.
- **View.** Character select card with face, HP, dice, sockets and Birthstone; Birthstone mesh
  variants (shield, marquise, step, briolette, cube, cushion, sphere, checkerboard) in `view/gems/`;
  face moods wired to HP and events on the player's own panel and the ally panels (done, §4); a flip button if
  Puck is taken.
- **Profile.** `current_setting` becomes `current_character`; per-character rail and bowl as today.
- **Docs.** Rewrite §5 of `REIMAGINING.md` and the Heroes row of the decisions table; fold this in.
