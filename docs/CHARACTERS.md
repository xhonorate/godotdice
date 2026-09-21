# Characters: the roster that replaced settings

Second draft, September 21, 2026, with the owner's first-round notes folded in. **Implemented the
same day**: Puck was chosen as the sixth character, Vesper's requirement is the recommended one, and
Florin keeps his Bust tier. The content lives in the `characters` section of `content/deep_cut.json`,
the Birthstone resolves in `DeepBattle.resolve_birthstone`, and `tests/test_battle.gd` covers every
tier and passive. Headshots and the six Birthstone cuts are still to draw; each Birthstone borrows
the nearest of the six outlines and is told apart by its tint and emblem for now. The jewellery "settings" of §5 in `REIMAGINING.md` become **characters**: a lapidary
you play, each with five coloured gem sockets, a set of starting dice, a passive, and a
**Birthstone**: a fixed personal gemstone that sits last in the rail and cannot be removed or
swapped. Combat stays first person; a character is a headshot and a handful of reaction faces,
never a body on screen.

Fire rates come from `tools/capstone_odds.py`: 200,000 hands per line, two rerolls spent by a greedy
policy that chases the character's own Birthstone. "Res" is Resonance when the Birthstone resolves.
"Block" is the game's word for shield, and block now falls off at the end of every turn.

## 1. Shared rules

- **Five sockets**, each Red, Blue, Green, Violet, Gold, White or Any. **Every character has at least
  one Red socket.** One character has six sockets and pays for it elsewhere.
- The **Birthstone** is last in the rail, always. Its cut and material sit outside the six-colour
  language so it can never be mistaken for a socketable stone. Every gem that fires before it feeds
  its Resonance, as the Capstone socket does today.
- A Birthstone has **tiers**. Every tier the final hand satisfies fires: a triple also fires the pair
  tier, a large straight also fires the small one.
- Thresholds on totals and "low" dice are **relative to each die's maximum**, as everywhere else.
- Two players may pick the **same character**. Name plates are tinted to tell them apart.
- **Unlock order.** Ardor is the starter. Vesper after the first Warden, Cadence after the second,
  Rue after the third (the first full run), the sixth character and Florin from commissions.

## 2. The roster

| Character | HP | Dice (mean) | Sockets | Passive | Birthstone reads |
|---|---|---|---|---|---|
| **Ardor**, the Knight | 80 | d6 d6 d6 d8 d8 (19.5) | Red, Blue, Green, Any, Any | Heal 3 per unused reroll | Sets |
| **Vesper**, the Rogue | 65 | d4 d4 d4 d4 d20 (20.5) | Red, Red, Violet, Any, Any | Block per hit dealt | Five distinct, see options |
| **Cadence**, the Wizard | 70 | d4 d6 d8 d10 d12 (22.5) | Red, White, Violet, Any, Any | +1 reroll | Straights |
| **Rue**, the Apothecary | 70 | d4 d4 d6 d6 Phial (13.7) | Red, Violet, Green, Any, Any | Heal Res when poison ticks | Low dice and ones |
| **Florin**, the Gambler | 60 | five d6 with 7 for 6 (18.3) | Red, Gold, Gold, Any, Any, Any | Free reroll of ones | Crowns |
| **Sixth**: Harrow, Blaise or Puck | | | | | High total, explosions, or parity |

### Ardor, the Knight

*The wall. Locks in early, heals for patience, and turns a lucky triple into a hammer.*

- **HP** 80. **Dice** d6 d6 d6 d8 d8. **Sockets** Red, Blue, Green, Any, Any.
- **Passive: Second Wind.** Heal 3 HP for each unused reroll when you lock in.
- **Birthstone: Rally.**
  - Pair (*Rank*): gain Res block.
  - Triple (*File*): deal 3×Res damage.
  - Four of a kind (*Phalanx*): cleanse your afflictions and stun the target for a turn.
  - Five of a kind (*Legion*): deal 5×Res damage, five times.
- **Fire rates.** Natural hand, banking both heals: pair 83%, triple 16%, quad 1%. Chasing with two
  rerolls: pair 99%, triple 65%, quad 22%, quint 3%. Heal or chase is the Knight's decision every turn.
- **Stone.** Almandine garnet in a shield (kite) cut: opaque, blood-red, an iron sheen, the only
  flat-topped Birthstone. **Birthstone face:** jaw set, eyes narrowed, a slow nod.

### Vesper, the Rogue

*The assassin's gamble. Four tiny knives and one enormous die.*

- **HP** 65. **Dice** d4 d4 d4 d4 d20. **Sockets** Red, Red, Violet, Any, Any.
- **Passive: Riposte.** Gain Res block for every hit one of your gems lands. Block falls off at the end
  of the turn, so a big Birthstone turn is a wall for that turn only.
- **Birthstone: Thousand Cuts.** Deal Res damage a number of times equal to your **highest rolled
  value**: a d20 showing 7 means seven hits, not twenty.
- **Combo.** Curse in the Violet socket, then the Birthstone.
- **Stone.** Black opal in a needle-thin marquise: dark body, a thousand pinprick flashes.
  **Birthstone face:** a thin smile, eyes on the target.

**The requirement is the open question.** Five distinct values fires 44% of chased turns with the
starting bowl, but 72% once a single d4 becomes a d6 or d8, because four d4s can only be distinct as
1-2-3-4. The owner suggested ascending order across the tray instead. Odds for each candidate, chasing
with two rerolls; "expected" is fires × average hits, so it is the Res multiplier a turn is worth:

| Requirement | Start bowl | Mid-run bowl (d4 d4 d6 d8 d20) | Late bowl (d6 d8 d8 d10 d20) | Notes |
|---|---|---|---|---|
| Five distinct (draft one) | 44%, avg 12.5 hits, expected 5.5 | 72%, expected 9.0 | higher still | balloons as the bowl improves |
| Ascending across the tray: 1, 2, 3, 4, then 5+ | 11%, expected 1.4 | 4.6%, expected 0.6 | lower | too rare to carry a character; needs a fixed tray order |
| Five distinct and the top die at 10 or more | 40%, avg 15 hits, expected 6.1 | 67%, expected 10.1 | | still balloons |
| **Five distinct and the top die outrolls the other four combined** | **37%, avg 15.7 hits, expected 5.9** | **48%, expected 8.3** | **23%, expected 4.1** | self-limiting: bigger small dice raise the bar |

For scale, Ardor's Birthstone is worth about 2.7×Res a chased turn, so any of the 35-to-50% rows
makes Vesper the damage dealer she should be at 65 HP.

**Recommendation.** The last row, named for what it is: *one long knife and four short ones*. The
d20 has to beat 1+2+3+4 at the start, so a d20 showing 7 does not fire; the average hit count goes up
and the rate stays in a band across the whole run instead of climbing to three turns in four. If the
owner still wants the tray-order idea, it works best as a **rare top tier** on top of that base:
*Perfect Fan*, the five dice ascending left to right, every hit deals 2×Res (11% at the start). That
needs the tray order fixed for the fight and arrangeable at the bench, which is a small addition.

### Cadence, the Wizard

*The combo player. Runs of numbers, and the turn that plays twice.*

- **HP** 70. **Dice** d4 d6 d8 d10 d12. **Sockets** Red, White, Violet, Any, Any.
- **Passive: Study.** +1 reroll every turn.
- **Birthstone: Encore.**
  - Small straight, four in a row (*Overture*): deal 4×Res damage to every creature.
  - Large straight, five in a row (*Encore*): replay every gem that fired this turn from the first
    socket onward, Overture included. Resonance keeps climbing through the replay. **Replayed gems do
    exactly what they did the first time, hand mutations included**: a Glimmer raises the lowest die
    again, a Refract adds a second phantom, so the hand the later gems read is bigger the second time.
- **Fire rates.** With the passive's three rerolls: small 50%, large 15%. With two: 37% and 9%.
- **Stone.** Ametrine, violet fading to gold, in a step cut: a staircase of facets.
  **Birthstone face:** eyes closed, one hand raised like a conductor.

### Rue, the Apothecary

*The low roller. Wants ones. Everything the other five dread, Rue drinks.*

- **HP** 70. **Dice** d4 d4 d6 d6 and **the Phial**, a d6-shaped die with faces 1 1 1 2 2 3
  (bowl mean 13.7). Judged against its d6 shape, every Phial face is low. **Sockets** Red, Violet,
  Green, Any, Any.
- **Passive: Leech.** Heal Res whenever poison damages a creature, Res being the final Resonance of
  your last rail. Three poisoned creatures means three heals a turn, which is what Miasma is for.
- **Birthstone: Bitter Draught.** A die is *low* when it shows half its maximum or less.
  - Four or more low dice (*Tincture*): poison the target for Res.
  - All five low (*Draught*): every poison on every creature ticks immediately, once.
  - All five showing 1 (*Dregs*): every poison on every creature ticks Res times.
- **Fire rates.** Chasing low: 92%, 58%, and Dregs 0.8%. Chasing ones instead: 63%, 22%, and Dregs
  5.2%. Two lanes, picked each turn from the forecast.
- **Why it works.** Bulwark, Wager, Ember, Miasma and Venom read low or even dice, and Mend reads the
  lowest. This is the only bowl that makes those Rare stones look good.
- **Stone.** Dark tourmaline briolette, a faceted teardrop, murky green-black with a trapped bubble.
  **Birthstone face:** a wry grimace, as if tasting it.

### Florin, the Gambler

*The six-socket high roller. Loaded dice, fool's gold, and a stone once in a hundred turns.*

- **HP** 60. **Dice** five **Gambler's Dice**: d6s whose 6 is a 7 (faces 1 2 3 4 5 7, bowl mean
  18.3). The 7 is the crown, and it is the face Lucky Seven pays on. **Sockets** Red, Gold, Gold,
  Any, Any, Any (six).
- **Passive: Loaded.** Any die that lands on a 1 is rerolled once, free, before you see the hand.
- **Birthstone: High Roller.** A *crown* is a die showing its top face.
  - Each crown (*Ante*): Res damage and Res ore.
  - Three or more crowns (*Hot Streak*): stones found in this fight are a grade better.
  - Five crowns (*Royal Flush*): a raw stone drops on the spot, Exquisite or better.
  - Optional fourth tier, *Bust*: no crown showing, lose Res ore. Gamblers lose sometimes; the odds are
    shown, and Loaded keeps it at one turn in twenty-five.
- **Fire rates** chasing crowns with Loaded: at least one 96%, three or more 46%, five 2.5% (one
  chased turn in forty), Bust 3.9%. Without the passive: 94%, 35%, 1.3%, 6.5%.
- **What the sixth socket costs.** Lowest HP, a flat bowl, and a sixth chance to fizzle and reset
  Resonance before the Birthstone. Wild faces and Twin engravings are the Gambler's shopping list.
- **Stone.** A pyrite cube, fool's gold, which forms as a perfect cube in nature: the Birthstone is a
  metal die. **Birthstone face:** wide eyes, a whoop.

## 3. The sixth character: three candidates

Wren the Lamplighter is withdrawn: a party-scaling passive punishes solo players, and the class was
dull. Each candidate below reads a pattern family nobody else uses, has a Red socket, and works
identically alone or in a party. **Puck was chosen.** Harrow and Blaise stay here as candidates for
a later roster.

### Harrow, the Berserker

*Big dice, big totals, and the less HP you have the harder you hit.* (alt names: Brann, Gorse)

- **HP** 90. **Dice** d8 d8 d10 d10 d12 (mean 26.5, the biggest bowl in the game; d6 d8 d10 d10 d12
  at 25.5 is the tamer alternative). **Sockets** Red, Red, Blue, Any, Any. Riposte in the Blue socket
  turns the hits he takes into damage.
- **Passive: Bloodrush.** Your rail starts at +1 Resonance for every 20 HP you are missing, up to +4.
- **Birthstone: Rampage.**
  - Total at or above 60% of the hand's maximum (*Charge*): deal 2×Res damage.
  - At or above 75% (*Frenzy*): also deal Res damage to every other creature.
  - At or above 90% (*Rampage*): deal 5×Res damage and stun the target.
- **Fire rates** chasing high dice: 92%, 53%, 2.7%. Natural: 38%, 8%, 0.2%.
- **Stone.** Bloodstone, dark green shot with red, in a heavy cushion cut with one corner chipped.
  **Birthstone face:** a roar.

### Blaise, the Sapper

*Blasting powder in a mine. Dice that explode, damage that splashes.* (alt names: Cinder, Pyke)

- **HP** 65. **Dice** five **Powder Kegs**: exploding d6s, a 6 rolls again and adds (natural mean
  about 21). **Sockets** Red, Violet, Gold, Any, Any. A 6 that rolls a 1 is a 7, which Lucky Seven
  pays.
- **Passive: Splash.** Whenever one of your gems damages a creature, the creatures beside it take Res
  damage. Once per gem that fires, not per hit.
- **Birthstone: Chain Reaction.**
  - Each die that exploded this turn (*Spark*): Res damage to every creature.
  - Three or more dice exploded (*Blast*): strip the target's block and stun it.
  - Any die that exploded three times (*Chain Reaction*): deal 10×Res damage to every creature.
- **Fire rates** chasing explosions: 94%, 36%, 5.7%. A double explosion shows up 31% of turns and
  could carry a fourth tier if wanted.
- **Cost.** Five Rare dice is a rich bowl, paid for with 65 HP and a Birthstone that does nothing on a
  hand with no sixes. Needs the sim to count explosions per die, which it does not yet.
- **Stone.** Fire opal cut as a faceted sphere, a bomb, with a single needle inclusion for a fuse.
  **Birthstone face:** fingers in ears, grinning.

### Puck, the Harlequin

*Two faces. You choose which one the enemy sees, every turn.* (alt names: Quip, Jinx)

- **HP** 70. **Dice** d6 d6 d8 d8 d10 (21.5). **Sockets** Red, Blue, White, Any, Any.
- **Passive: Sleight.** Once per turn, before locking in, flip one die to the other side of its range
  (1 and 6, 2 and 5, 3 and 4) for free. On even-sided dice a flip always changes parity, so the
  Harlequin can almost always finish a hand in one parity.
- **Birthstone: Motley.**
  - All five dice odd (*the Cruel Face*): deal 3×Res damage to the target.
  - All five dice even (*the Kind Face*): gain 3×Res block.
  - All five one parity and all distinct, a skip straight like 2-4-6-8-10 or 1-3-5-7-9
    (*Full Motley*): both, doubled, and the target is stunned.
- **Fire rates.** A single face is reachable 96% of chased turns, so the choice each turn is attack or
  defend, not whether. Full Motley is 6.4% when chased, and chasing it drops the safe tier to 77%.
- **Why it is different.** Every other Birthstone is a gamble. This one is a decision, which is a
  playstyle the roster otherwise lacks, and the flip is a small, satisfying action.
- **Stone.** Watermelon tourmaline, pink one half and green the other, in a checkerboard cut.
  **Birthstone face:** one eye winking, mouth half grin, half frown.

## 4. Headshots

Eight states per character, the same eight for everyone so panels and tests stay uniform:

1. Idle. 2. Rolling (eyes down on the dice). 3. Wince (took damage). 4. Bloodied (under half HP).
5. Critical (under a quarter, the Duke Nukem face). 6. Birthstone (unique per character, listed
above). 7. Downed. 8. Victory.

Recommendation: keep §10's rule and build the heads as **low-poly busts in the shared four-light
rig**, expressions done by swapping eye and mouth meshes and a small head tilt, rendered once each
into the existing thumbnail cache. Ally panels get a face for free, and the busts can be posed for
the character select. If the owner would rather commission 2D portraits, the doc's existing clause
applies: stones and dice stay 3D, the portraits are the one hand-drawn element.

## 5. Decided and still open

Decided in the first round: the player-facing word is **Birthstone**; Ardor heals 3; Riposte is per
hit; Encore replays mutations; duplicates are allowed; Ardor, Vesper, Cadence unlock in that order;
every character has a Red socket.

Settled at implementation: Vesper fires on five distinct values with the top die outrolling the
other four combined (no tray-order tier); the sixth character is Puck; Florin keeps Bust, which is
one tier in the content and trivial to remove. Harrow's bowl is moot until he is added.

## 6. Implementation sketch (after approval)

- **Content.** `settings` becomes `characters`: name, title, hp, dice, sockets (five or six colours,
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
- **View.** Character select card with bust, HP, dice, sockets and Birthstone; Birthstone mesh
  variants (shield, marquise, step, briolette, cube, cushion, sphere, checkerboard) in `view/gems/`;
  bust states wired to HP and events on the player's own panel and the ally panels; a flip button if
  Puck is taken.
- **Profile.** `current_setting` becomes `current_character`; per-character rail and bowl as today.
- **Docs.** Rewrite §5 of `REIMAGINING.md` and the Heroes row of the decisions table; fold this in.
