# Deep Cut: the reimagining of RogueDice

Blue-sky redesign, September 18, 2026, with the owner's decisions folded in the same day. This is the design of record for the rebuild. Items that were questions are now marked **[Decided]** with the decision.

## Decisions (September 18, 2026)

| Topic | Decision |
|---|---|
| Name | **Deep Cut** (working title; "Deep Cuts", plural, is an unrelated VR game on Steam, so the singular should be checked again before release) |
| Co-op | Built in from the ground up. Every system assumes one to four players: shared tunnels, enemies budgeted by party size, ally-targeted gems, and giving stones and dice to each other at landings. Steam first; the transport stays abstract for a possible mobile build later |
| Heroes | Gone. Players wear **settings**. Combat is first person: the party looks at the creatures, allies appear as panels, nobody draws a hero sprite |
| Art | Procedural low-poly geometry in one lighting rig is the final look if it looks good enough |
| Run length | About 30 minutes to the third Warden, then **Endless** for players who love their build |
| Collection | One stone per skill in the vault. Bringing home a second copy shows both and the player keeps one |
| Clarity | A normal distribution centred on Clear (no inclusions), so Flawless and the two-inclusion grade are equally rare, with one rarer three-inclusion grade below. Names: Flawless, Pristine, Clear, Included, Veined, Riddled |
| Resonance | Kept. Gems can be retriggered (Balatro style) and same-colour neighbours resonate harder (§3.5) |
| Anything else kept from the old build | Nothing |

## 0. The brief

Keep:

- The gems: their concept, the procedural 3D stones cut from their own properties, the colour-to-cut-shape language.
- The loop: expedition, find raw stones, appraise, return, refit the loadout, go deeper.
- The dice: five dice, select-and-reroll, gems read poker-like patterns off the final hand, requirements drawn as pictographs.

Redo everything else, and maximise three feelings:

1. **Replayability.** Any run could produce a build nobody has seen. Variance, niche synergies, combos.
2. **Progression.** A long ramp of content, records that show how far you have come, a collection to be proud of.
3. **The lever.** Every run has a real chance at a jackpot stone. Make the player want to pull again.

Constraints: user friendly, conceptually cohesive, visually consistent, performant.

## 1. The pitch

You are a **lapidary**: a cutter and setter of stones. Under your workshop runs a mine with no bottom. You go down with a setting full of gems and a bowl of dice, fight what lives in the rock, pull raw stones out of the walls, and decide at every landing whether to ride the lift home with what you carry or dig one landing deeper where the stones are bigger. Back at the bench you put each stone under the loupe. Most are ordinary. Some are perfect. Once in a hundred runs, one of them is the stone you will still be talking about next year.

Everything in the game is one of four kinds of object, all rendered as real geometry in one visual language: **stones** (gems), **dice**, **settings** (the jewellery that holds your gems), and **the creatures of the rock**. The UI around them is quiet, flat and typographic. Only the things that matter sparkle.

## 2. What survives from the current codebase

| Keep | Why | Notes |
|---|---|---|
| `scripts/ui/gem_mesh.gd`, `gem_tuning.gd` (now `view/gems/`) | The stone itself. This is the thing the owner likes. | Extend for inclusions (see §3.4) and new Carat range. |
| `scripts/ui/gem_view.gd` | Lights and frames a stone. | Add a thumbnail cache (§11.3). Live 3D only for the focused stone. |
| `scenes/gem_lab.tscn`, `gem_lab.gd` | The tuning tool. | Keep as the art-direction tool for stones. |
| `scripts/ui/dice_geometry.gd`, `dice_view.gd` | Real polyhedral dice. | Move dice into the one battle World3D instead of a SubViewport per die. |
| `scripts/ui/dice_icons.gd` | The pattern pictographs. | The visual language for triggers stays. Extend for new patterns. |
| `scripts/core/gem_rules.gd` | Skills as data. | Becomes the *only* way a skill is written. Vocabulary grows (§3.6). |
| `scripts/core/content_pack.gd`, `data/full_content.json`, `tools/content_studio/` | Data-driven content and its editor. | Schema changes wholesale; the tooling approach stays. |
| `scripts/services/save_store.gd`, `profile_store.gd` | Atomic, backed-up saves. | Fine as is. |
| `scripts/core/random_source.gd` | Named RNG streams. | Fine as is. |
| `scripts/services/enet_transport.gd`, `packet_codec.gd`, `steam_transport.gd` | Transports. | Parked until co-op returns (§11.2). |

Everything else is deleted, including `main.gd` (3,535 lines that rebuild the whole UI tree on every state change), `run_engine.gd`, `combat.gd`, `seam.gd`, `seam_map.gd`, `hub.gd`, `hub_screens.gd`, `room_screens.gd`, `battle_stage.gd`, `sprite_forge.gd` and every baked sprite, `session.gd`'s snapshot chunking and fallback controller, the tremor meter, the atlas, the appraisal table (the idea returns as the reveal ceremony), and all tests. The gem emblems in `gem_icons.gd` are kept only if the skill list keeps enough of the old names to reuse them.

## 3. Gems, reimagined

### 3.1 The problem with the current gems

Every gem is one formula with three multiplicative dials. Carat multiplies everything, Cut multiplies the dice term, Clarity adds a flat term and loosens the trigger. That is a stat system, not a synergy system: a Carat-12 Strike is a Carat-1 Strike with a bigger number. Two Strikes are always the same Strike. Gems only interact through three White gems and Echo. Colour does nothing mechanically. There is no way for a stone to be *weird*, and weird is where "I could make a crazy build" comes from.

### 3.2 The four C's, each with one job

| C | Question it answers | Range | Visible on a raw, unappraised stone? |
|---|---|---|---|
| **Colour** | *What kind of thing does it do?* | Red, Blue, Green, Violet, Gold, White | Yes: hue and cut outline |
| **Carat** | *How much?* | 1 to 20, heavy-tailed | Yes: size |
| **Cut** | *How often does it fire?* | Poor, Fair, Good, Fine, Perfect | Partly: a Poor stone is visibly lopsided and chipped |
| **Clarity** | *How pure is it, and what is frozen inside?* | Riddled, Veined, Included, Clear, Pristine, Flawless | Partly: fog and visible inclusions, but not what they do |

The important change is to **Cut** and **Clarity**.

**Carat is magnitude, and nothing else.** One multiplier over the gem's amounts, and it is allowed to be enormous at the top. Proposal: `M = 1 + Carat / 4`, so a Carat 1 stone is ×1.25 and a Carat 20 stone is ×6. A jackpot must be unambiguous: bigger is better, always.

**Cut is consistency.** Every skill defines a five-step trigger ladder and Cut picks the step. A Poor Barrage needs a straight of five; a Perfect Barrage fires on a straight of three. A Poor Guard needs a pair of fives or better; a Perfect Guard fires on any pair. A Poor Overkill needs a total at 90% of the maximum your dice can roll; a Perfect one fires at 70%. Skills that fire on every hand (Strike, Mend) use Cut to widen what they read: highest die, then highest two, then highest three. The pictograph shows the requirement the stone actually has, so the player reads Cut directly off the trigger mark and never needs a table.

Thresholds on totals and high dice are always **relative to the dice being rolled** (a percentage of the hand's maximum) so a d20 build cannot trivialise them and a d4 build is not locked out.

**Clarity is purity versus inclusions.** In real gemmology, clarity grades count the inclusions frozen in the stone. Here, inclusions are the affix system: the random modifiers that make one stone different from every other stone with the same skill. **[Decided]** Clarity is a normal distribution centred on Clear. The pure tail and the included tail are equally rare, and one extra grade sits below them as a rare three-inclusion tail.

| Clarity | Inclusion slots | Base weight | Purity bonus |
|---|---|---|---|
| Riddled | 3 | 2 | none |
| Veined | 2 | 6 | none |
| Included | 1 | 20 | none |
| Clear | 0 | 44 | none |
| Pristine | 0 | 20 | +1 Cut step when evaluating triggers |
| Flawless | 0 | 6 | +1 Cut step, ×1.5 magnitude, and the skill's **Flawless line** (an authored bonus effect, one per skill) |

Depth widens both tails a little rather than moving the centre: deeper stones are stranger, not just better. The grade names are content strings and cheap to change.

This gives two different jackpots on the same axis, which is the point:

- A **Flawless** stone is the pure jackpot. Big base, forgiving trigger, its own bonus line. "Perfect stats."
- A **Veined or Riddled** stone whose inclusions happen to agree with each other is the *chaos* jackpot. Lower base, but it does something no clean stone can. "The build-maker."

Both are rare. Both make a player want to pull again. A Riddled stone with three Fractures is the bad roll on this axis, so Clarity is a real gamble, not a rank.

### 3.3 Inclusions

Inclusions are drawn from a pool at stone creation, weighted by mine, depth and colour. Named for real gemmological features, because the names already sound like affixes.

| Class | Frequency | What they do | Examples |
|---|---|---|---|
| **Pinpoints** | Common | Small pure riders | *Pinpoint of Gold*: +2 gold when this fires. *Needle*: +1 damage per die read. *Silk*: when this fires, gain 1 block. |
| **Lenses** | Common | Change what the gem reads | *Veil*: reads the lowest die as if highest. *Cat's Eye*: ones count as wild. *Colour Zoning*: counts as Red and its own colour for sockets and chains. *Graining*: counts dice you did not reroll twice. |
| **Feathers** | Uncommon | Inter-gem chains | *Feather*: the next gem in the rail gains +1 Cut step. *Twinning Wisp*: fires again if the previous gem fired. *Fingerprint*: copies one inclusion from the gem before it. *Halo*: adjacent gems of this colour gain +1 Carat. |
| **Fractures** | Uncommon | Double-edged | *Fracture*: ×2 magnitude, fizzles if any die shows a 1. *Bruise*: ×1.5, you lose 2 HP when it fires. *Knot*: +2 Carat, cannot be removed from its socket during a run. *Cavity*: this gem's Carat counts double, its Cut counts as Poor. |
| **Stars** | Very rare | Jackpot-tier | *Star*: fires on every hand. *Chatoyance*: fires twice. *Fluorescence*: +1 Carat per depth below 10 while underground. *Alexandrite*: changes to the colour of the socket it sits in, and its skill's Flawless line is always on. |

Design rules for the pool:

- Nothing is pure downside. Every Fracture has a large upside.
- Every Lens and Feather should make at least two existing skills read differently.
- A **Star** should appear roughly once in a few hundred stones. Its glint is visible on the raw stone before appraisal (a moving highlight), so the player knows they have *something* before they know what.
- Inclusions can be **revealed** on a raw stone by a loupe without appraising the skill, which is a nice half-step tension for mid-run decisions.

Rendering: `gem_mesh.gd` already freezes inclusions inside the stone from Clarity. Each inclusion class gets its own geometry (needles, feathers, clouds, a star), so a stone's inclusions are literally visible and a practised eye can guess them.

### 3.4 Skills: the catalogue to react to

Six colours, roughly six skills each, about 36 at launch, growing to 60+. Every skill is written as data (§3.6). Each row shows the Poor-to-Perfect trigger ladder in brackets. Names are placeholders; the shape of the space is the point. Rarity (Common, Uncommon, Rare, Legendary) sets pool frequency.

**Red: damage.** Reads sets and high dice.

| Skill | Trigger ladder | Effect | Flawless line |
|---|---|---|---|
| Strike (C) | always [reads highest 1/1/2/2/3 dice] | damage = sum read | also hits the enemy behind |
| Cleave (C) | pair [of 5+/4+/3+/2+/any] | damage = pair value ×2, half to neighbours | full to neighbours |
| Crush (U) | triple [of 5+ … any] | damage = value ×3 | stuns on a 6+ triple |
| Barrage (U) | straight [5/5/4/4/3] | one hit of 4 per die in the run | hits go to distinct enemies |
| Overkill (R) | total ≥ [90/85/80/75/70]% of max | damage = total | excess over the kill carries to the next enemy |
| Spall (R) | distinct dice [5/5/4/4/3] | damage = two lowest ×2 | ×3 |
| Ember (U) | any 1s [1s / 1s or 2s / … ] | 3 damage per qualifying die | burn 1 per die |
| Fury (R) | rerolled dice this turn [≥4/3/3/2/1] | 4 damage per die rerolled | rerolled dice also count for other Red gems as if kept |

**Blue: guard.**

| Skill | Trigger ladder | Effect | Flawless line |
|---|---|---|---|
| Guard (C) | pair | block = pair value | block persists into next fight |
| Bulwark (U) | total ≤ [40/45/50/55/60]% of max | block = (max − total) | party |
| Aegis (U) | straight | block to all allies = top of run | also cleanse |
| Bastion (R) | full house | party block = triple value + pair value | party stun immunity next turn |
| Tempo (C) | even dice [≥5/4/4/3/3] | block = 2 per even die | 3 per even die |
| Anchor (R) | held dice (not rerolled) [≥5/4/4/3/2] | block = 2 per held die | held dice keep their value next turn |
| Riposte (R) | always | deal damage = block lost since your last turn | ×2 |

**Green: sustain.**

| Skill | Trigger ladder | Effect | Flawless line |
|---|---|---|---|
| Mend (C) | always [reads lowest 1 … 3] | heal = sum read | overheal becomes block |
| Graft (U) | two pair | heal = both pair values | party |
| Bloom (C) | odd dice [≥5 … 3] | party heal 1 per odd die | 2 per odd die |
| Renewal (U) | straight | heal top of run, cleanse 1 | cleanse all |
| Lifeline (L) | quad [quad/quad/full house/triple/triple], once per fight | revive a downed ally | revive at half HP |
| Thrive (R) | always | heal = your current block / 2 | = block |
| Sap (R) | always | damage = healing you did this turn | also heals the party for half |

**Violet: control.**

| Skill | Trigger ladder | Effect | Flawless line |
|---|---|---|---|
| Hex (U) | high die ≥ [95/90/85/80/70]% of its die max | stun | stun 2 |
| Venom (C) | pair | poison = pair value | poison does not decay |
| Miasma (U) | even dice ≥ [5 … 3] | poison 2 to every enemy | 3 |
| Curse (R) | always | target takes +25% damage from later gems this turn | +50% |
| Shatter (U) | triple | remove block = value ×3, damage the rest | remove all block |
| Bind (R) | two pair | enemy loses one die next turn | loses two |
| Dread (L) | straight | enemy's next intent is downgraded one step | cancelled |

**Gold: fortune.** Gold is *luck and economy*: gold, loot quality, and gambles.

| Skill | Trigger ladder | Effect | Flawless line |
|---|---|---|---|
| Tithe (C) | pair | +gold = pair value | ×2 |
| Jackpot (R) | triple [triple/triple/triple/triple/pair]; quint pays ×10 | gold = value × dice matched | a quint also drops a stone |
| Lucky Seven (U) | any die shows 7 [7 / 7 or 11 / …] | 7 damage and 7 gold per seven | 14 |
| Wager (R) | total ≤ [40 … 60]% of max | gold 5, damage = (max − total) | gold 10 |
| Windfall (U) | straight | +10% stone quality for the rest of this fight | +25% |
| Double Down (L) | always | coin flip: the next gem is ×2 or ×0 | ×3 or ×0 |
| Prospect (U) | distinct | +1 Sparkle; at 5 Sparkle the next stone found is one grade higher | at 4 |

**White: the hand itself.** White gems mutate the hand for every gem after them in the rail, which makes rail order a build.

| Skill | Trigger ladder | Effect | Flawless line |
|---|---|---|---|
| Glimmer (C) | always | raise lowest die by [1/2/2/3/4] | to match the highest |
| Refract (U) | always | add a phantom die copying the highest | copies the two highest |
| Polish (U) | always | set one die to match another (makes a pair) | makes a triple if a pair exists |
| Mirror (U) | always | flip one die (max + 1 − value) | flip two |
| Cascade (R) | pair | +1 reroll this turn (use before locking, on the next turn if late) | +2 |
| Facet (R) | always | the next gem evaluates at +1 Cut step | +2 |
| Echo (R) | pair | repeat the previous gem at 50% | 100% |
| Prism (L) | always | this gem's inclusions also apply to both adjacent gems | to the whole rail |

### 3.5 Resonance: the combo engine **[Decided]**

One shared mechanic ties the rail together and makes order and consistency matter:

- Each gem that **fires** adds +1 Resonance for the turn. A gem that **fizzles** resets Resonance to 0.
- **Harmony.** If the gem that fired immediately before this one in the rail shares a colour with it, the fire adds +1 more. A run of Red stones climbs twice as fast as a rainbow, which makes colour mechanical, makes a setting's socket colours a real constraint, and makes Colour Zoning (a stone that counts as two colours) worth having.
- **Retriggers.** A gem can fire more than once in a turn: Echo repeats the previous gem, Chatoyance fires its stone twice, Twinning Wisp fires again if the previous gem fired, and a die's gem face fires everything once. Every retrigger adds Resonance again. This is the Balatro lever: stack retriggers on a cheap early stone to feed the Capstone.
- The last socket in every setting is the **Capstone**. A gem in the Capstone gains +Resonance to its Carat when it fires.
- A handful of skills and inclusions read Resonance directly ("×Resonance", "fires only at Resonance 3+", "does not reset Resonance on fizzle").

This gives the moment of watching the counter climb along the rail and land on the final stone, rewards putting reliable Perfect-cut stones early and swingy stones late, and makes Cut (consistency) valuable for a reason other than the stone's own damage.

### 3.6 Skills as data, only

`gem_rules.gd` already interprets a small vocabulary. It becomes the only way a skill exists, and grows:

- Triggers: add `quint`, `held_count`, `rerolled_count`, `value_any_of`, `total_pct_at_least`, `total_pct_at_most`, `high_pct_at_least`, `resonance_at_least`, and a `ladder` field so a trigger's threshold is an array of five values indexed by Cut.
- Terms: add `held_count`, `rerolled_count`, `resonance`, `block_lost`, `healing_this_turn`, `phantom` dice.
- Effects: add `raise_die`, `set_die`, `flip_die`, `add_phantom`, `reroll_grant`, `amplify_next`, `cut_step_next`, `revive`, `cleanse`, `curse`, `intent_downgrade`, `die_steal`, `quality_bonus`, `sparkle`, `coin_flip`.
- Inclusions are the same language with a `hook` (on_fire, on_fizzle, on_read, on_adjacent, on_socket) and a `scope` (self, next, previous, adjacent, rail).

The studio keeps its live preview: pick a skill, spin the C's and inclusions, roll a hand, see what fires.

### 3.7 Grade: the number the slot machine shows

Every stone gets a computed **Grade** from its Carat, Cut, Clarity, inclusion rarity and skill rarity, mapped to five tiers with their own glow and drop beam: **Rough, Fine, Precious, Exquisite, Peerless**. Peerless should be under 1% of stones. Grade drives the drop beam, the reveal fanfare, the sell price, and the vault sort. It is also what commissions ask for ("a Precious or better Blue").

### 3.8 Naming and identity

A stone is named by its skill and its ranks, the way a jeweller would say it: *"a Perfect Flawless 14-carat Barrage"*. Inclusions are listed under it. Every kept stone also carries **provenance**: the mine, the depth, the run number, and the date it was found. Cheap to store, and it turns an instance into a memory.

## 4. Dice

### 4.1 Hands and rerolls

Five active dice, rolled every turn. Proposal: **two selective rerolls** per turn by default (Yahtzee's cadence), up from one, with rerolls as a resource that gems, dice and settings add to and that some gems spend. Select-to-reroll stays.

Patterns the game reads, all with pictographs: pair, two pair, triple, full house, quad, quint, straight 3/4/5, n odd, n even, n distinct, a specific value, high die ≥, low die ≤, total ≥ / ≤ as a share of the hand's maximum, held dice, rerolled dice, phantom dice.

### 4.2 Dice as loot

Dice are the second build axis and deserve the same variance as stones. Every die is an item with faces, a shape, and up to one **engraving**:

- **Shapes**: d4, d6, d8, d10, d12, d20. Shape decides what patterns are easy: d4s make sets, d20s make high totals, a mixed bowl makes straights.
- **Face sets**: weighted, paired, odd, even, split, "sevens", blanks.
- **Special faces**: a **wild** face that counts as any value, a **gem** face that fires every gem regardless of pattern (once per turn), an **exploding** face that rolls again and adds, a **locked** face that cannot be rerolled once shown, a **mirror** face that copies its neighbour.
- **Engravings** (one per die, rare): "always held", "rerolls are free on this die", "counts as two dice for pair triggers", "+1 to every face".

Dice are found in veins, bought at merchants, and crafted at the Grinder (§7). A run's dice changes are kept if the die comes home in the haul, and the home bowl grows the way the vault does.

## 5. Settings instead of heroes **[Decided]**

The heroes are gone. Players wear the thing a lapidary actually makes: **settings**, the jewellery that holds the gems. A setting is the "class".

| Setting | Sockets (colour) | Base HP | Starting dice | Passive |
|---|---|---|---|---|
| Signet | 4: Red, Blue, Any, Capstone | 80 | d6 d6 d6 d8 d8 | +1 reroll per turn |
| Gauntlet | 5: Red, Red, Any, Violet, Capstone | 90 | d8 d8 d10 d10 d12 | first gem each turn gets +1 Cut step |
| Pendant | 5: Green, White, Any, Blue, Capstone | 70 | d4 d4 d6 d6 d20 | heal 2 whenever a gem fizzles |
| Circlet | 6: Any ×5, Capstone | 60 | d4 d6 d8 d10 d12 | none (the flexible one) |
| Chain | 7 small: Gold, Gold, Any ×4, Capstone; only Carat ≤ 8 | 75 | d6 ×5 | Resonance does not reset on the first fizzle |
| Torc, Diadem, Brooch… | unlocked by Wardens and commissions | | | |

A setting's sockets are drawn as the cut shape they take, exactly as today. The Capstone is always last. Settings are unlocked, not found, so they are the progression spine. In co-op each player wears a setting, and two players may wear the same one.

## 6. Combat

### 6.1 Turn flow

1. Enemies roll and publish **intents** with the same pictograph language players read on their own gems (a Quartz Golem's "Slam: pair" shows two matching dice), so the player learns one language.
2. Every player rolls at once, rerolls up to twice, picks a target, locks in. The rail is locked during a fight.
3. When everyone has locked (or a host countdown ends), resolution runs **one step at a time**: player one's rail gem by gem, then player two's, then the creatures. Each step is one atomic event, animated as it happens on every screen (§11.1). Resonance climbs on each rail as gems fire.
4. Statuses tick. Check for victory or wipe. Next turn.

A live **forecast strip** under the dice shows what the current hand would do (damage, block, heal, gold, Resonance) and which gems would fire, updating as the player selects dice to reroll. That preview is the single most important UI element in the game and is what makes the dice decisions feel smart rather than random.

**First person. [Decided]** The camera is the party's eyes. Creatures stand in an arc on the far side of the chamber facing the player. The player's own dice tray and rail sit at the bottom of their screen. Allies are compact panels at the sides showing HP, block, statuses, their final hand and which of their gems fired, with their numbers floating over the creature they hit in their own colour. Nobody is ever drawn as a character.

**Co-op is the baseline. [Decided]** Encounters are budgeted by party size as well as depth. Blue and Green gems target allies as naturally as the self (Aegis, Bastion, Bloom, Graft, Lifeline). At landings players can **give** stones and dice to each other, so a Red-heavy setting can pass its Green find to the healer. Everyone votes on tunnels and on the lift.

### 6.2 Enemies

Creatures of the rock, in the same low-poly geometric language as the stones (§10). Each is a small puzzle for a build:

| Enemy | Puzzle |
|---|---|
| Cave Tick | Steals your highest die for a turn |
| Quartz Golem | Gains block equal to your highest die each turn (punishes high rollers) |
| Glass Wyrm | Reflects damage from gems that fired at Resonance 0 |
| Clouder | Clouds one of your sockets (the gem cannot fire) until you hit it |
| Silt Slime | Splits when hit by a single big hit; dies to many small ones |
| Magpie | Steals gold on hit; drops it all on death |
| Lantern Moth | Extra rerolls for you, but drains 1 HP per reroll |
| Vein Wraith | Immune to poison, weak to straights |

**Wardens** are the bosses. Each mine has three at landings 10, 20 and 30. Wardens have phases with announced patterns and a gimmick that targets the whole rail: the Warden of the Quarry buries a random socket each turn; the Mirror Warden copies your last fired gem against you; the Rift Warden rolls your dice for you on odd turns.

Depth scaling is a smooth curve on enemy HP, damage and count. Enrage after turn 7 stays as an anti-stall rule.

## 7. The Descent (replacing the seam map) **[Decided: option B]**

### 7.1 Options considered

| Option | Shape | For | Against |
|---|---|---|---|
| A. Node map (Spire) | branching graph, several floors visible | proven, planning | this is what is being removed; heavy UI |
| B. Straight shaft with landings | one chamber per depth, 2 or 3 doors each time, safe landings every 5 | simple, push-your-luck, depth is the score | fewer route decisions |
| C. Deck draw | draw three chamber cards, pick one | high variance, cheap UI | shapeless; no sense of place |

**Recommendation: B, with C's card-like chamber choice at each step.**

### 7.2 The shaft

- The mine is a vertical shaft. **Depth** is the score. Each depth has one **chamber**.
- Before each chamber the player sees **two or three tunnel mouths**, each with a glyph: fight, elite, vein, oddity, or unknown (a dark mouth). Pick one. That is the whole map: one step of lookahead, no graph.
- **Revised (September 19, 2026): the lantern map.** One step of lookahead read as two balls floating beside the shaft. Each stretch between landings is now charted when the party reaches its head: rows of two, three, then four chambers, each leading to the two nearest below it, so the ways split and rejoin and never cross. The tunnels offered are the ways on from the chamber the party stands in. The lantern shows what waits two depths ahead; past that a chamber is a glint (hostile, glittering or strange) and a dark mouth shows nothing (at most one a depth). **Lighting the way** costs a loupe, or ore when there are none, and reveals the whole stretch to the landing, dark mouths included: the loupe now competes between appraising and scouting. A landing charts the stretch below it, so the choice to descend is made looking at it.
- Every fourth depth is a **Landing**: a safe room with a **Lift** (extract with everything), a **Lapidary** (appraise for ore or loupes), a **Merchant** (dice, stones, loupes, charms), the **Bench** (rearrange the rail, socket stones), and **Give** (hand a stone or die to an ally). Between landings there is no way up. Four chambers is one bite of commitment.
- **Wardens' gates** at landings 8, 16 and 24. Beating a Warden for the first time unlocks the next mine and a setting. The third Warden at depth 24 is the end of a run, about thirty minutes in. Below 24 the mine is **Endless**: Wardens every eight depths, scaling that never stops, for the player who wants to see how far the build goes.
- The lift screen always shows the haul: how many stones, their grades as beams, and an estimated value. The player chooses to leave *looking at what they would lose*.

### 7.3 Chambers

| Chamber | What happens |
|---|---|
| Fight | An encounter from the mine's pool at this depth. Ore, a chance of one raw stone. |
| Elite | A harder encounter. Guaranteed stone at +1 grade, a charm choice. |
| Vein | Mining: a wall of rock with visible glints. Pick N spots to strike (a light game, not the old automatic dig). Stones and dice come out; the glint colour hints at the grade. |
| Oddity | One of the crafting gambles (§8). |
| Motherlode | Rare. A chamber of stones. Every run has a small hidden chance of one; its existence is the "bonus round" players talk about. |
| Landing | See above. |

### 7.4 Pressure

The tremor meter and the roaming boss are dropped. The pressure is structural: five-chamber commitments, Wardens at known depths, and depth scaling. If more pressure is wanted later, **Dark** is the candidate: below a depth, each chamber adds a Darkness stack that buffs enemies unless a lantern charm burns ore. Not in v1.

### 7.5 Endings

- **Extracted**: the lift. Everything comes home.
- **Fallen**: a wipe. Every raw stone in the haul is rolled on a **salvage die** by grade (d6 for Rough to d20 for Peerless): only the top face survives. Loadout stones are never at risk. The salvage dice are physical, one per stone, and the player rolls them one at a time. Keep this: it is a slot machine inside the loss.
- **Abandoned** (added September 19, 2026): the host can give up the dig from the menu. It counts as a fall: salvage dice for every raw stone, set stones safe.
- **Warden slain**: the Warden's hoard (pick one of three appraised stones at Exquisite or better), unlocks, then the lift.

## 8. Oddities: events as crafting gambles

Events should be variance engines, and every one of them should be about the things the game is about. Odds are shown on every gamble.

| Oddity | The gamble |
|---|---|
| The Cutter's Wheel | Re-cut a stone: Cut moves up one step 60%, down one step 30%, shatters 10%. |
| Acid Bath | Remove one inclusion from a stone, or reveal every hidden inclusion on all your raw stones. |
| The Crucible | Fuse two stones: keep the skill of one, sum the Carats (cap 20), each inclusion of both survives 50%. |
| Geode | Crack it: 3 small stones, or 1 big one, or dust. Shown odds. |
| The Grinder | Shave a die: remove one face and rejoin it as its neighbour (a d6 becomes 1-2-3-4-6-6). Or add an engraving 40%, break the die 10%. |
| The Old Prospector | Trade a raw stone for a raw stone one Carat bigger, sight unseen. |
| Shrine of the Pattern | Pick a pattern. For the rest of the run, every gem that fires on it gains +1 Carat. |
| The Idol | Take a Carat 16+ stone with a guaranteed Fracture and a guaranteed curse. |
| Echo Chamber | Copy one inclusion from one stone onto another. |
| Dice Bowl | Swap one of your dice for a random die of the same shape from the mine's pool. |
| The Collector | Sell any stone for triple, but it is gone from the world (cannot reappear). |
| Loupe Cabinet | +2 loupes, or one Perfect Cut re-cut on any stone. |
| The Vug | Free mining chamber with better odds, but the party takes damage each strike. |

Twelve to twenty of these at launch, drawn with no repeats per run. Each should be one card with two or three choices and a preview of the result.

## 9. Home: the Bench

The shop-with-hotspots becomes a **tabbed home** with a persistent header (gold, runs, deepest depth per mine, active commission). The 3D stones and dice are the rich elements inside a quiet, flat frame. A diorama of the bench can be layered on later as decoration; usability comes first.

| Tab | What it is |
|---|---|
| **Appraise** | The reveal ceremony for stones brought home (§9.1). Also the place to sell. |
| **Vault** | One stone per skill **[Decided]**, laid out as the skill grid: unseen skills are dark silhouettes, seen-but-unowned are grey, owned show the stone you kept. Sort and filter by colour, grade and provenance. Click for the full card. Pin favourites to a **showcase shelf** rendered in 3D. When a second copy of a skill comes home, both stones are shown side by side and the player keeps one; the other is sold. |
| **Bench** | Choose a setting, socket stones from the vault into its rail, arrange dice from the bowl. Drag and drop, with the forecast strip live against a sample hand so a build can be tested before leaving. |
| **Shop** | Daily stock of appraised stones, dice and loupes. Refresh costs gold. |
| **Ledger** | Commissions (bring me X), records (deepest, best find, runs), and the run history. |
| **Map** | Mines as nodes on a cross-section of the earth. Pick one, pick a party if co-op, **Descend**. |

### 9.1 The reveal ceremony

This is the lever. It gets the most polish of anything in the game.

1. The raw stone rises from the haul tray into the light. Its Colour and Carat are already known.
2. **Cut**: the rough surface facets snap into place one band at a time. "PERFECT" holds for a beat with a chime if it lands there.
3. **Clarity**: the fog inside the stone clears. Inclusions light up one by one as sparks, each naming itself.
4. **Skill**: the emblem etches into the table. The name types out.
5. **Grade**: the beam. Peerless gets its own fanfare, camera push and a screen-wide glint.
6. Keep (to vault), Set (straight into the bench), or Sell. If a better copy of the same skill sits in the vault, the two are shown side by side.

Every stone gets this, but the ceremony is skippable to a fast "flip" for Rough and Fine stones after the player has seen a few, and batchable ("appraise all Rough"). The near-miss is honest: a Carat 19 says 19. Odds are shown on the card: "Perfect Cut: 1 in 40. Flawless: 1 in 60. Star inclusion: 1 in 400."

Mid-run, the same ceremony plays at a Landing's Lapidary, paid for with a loupe or ore. Loupes are scarce (two per run plus finds), so appraising underground is a real decision: use the huge red one now, or save the loupe.

### 9.2 Progression, in one place

| System | What it gives | Where it shows |
|---|---|---|
| Depth records | The score. Deepest depth per mine, best Warden. | Header, Ledger, Map nodes |
| Mines | New enemy pools, colour biases, unique inclusions and dice. Unlocked by Wardens. | Map |
| Settings | New socket layouts and passives. Unlocked by Wardens and commissions. | Bench |
| Vault and showcase | The collection. Provenance on every stone. Favourites on a shelf. | Vault |
| Bench upgrades | A short tree bought with gold: +1 loupe per run, vault capacity, shop tier, a sixth die slot in the bowl, starting reroll. Kept small on purpose. | Bench |
| Commissions | Directed goals with exciting rewards (a named die, a setting, a guaranteed Exquisite). | Ledger |
| Hazard tiers | Optional per-mine modifiers after the third Warden (more Fractures in the pool, Dark, elite-only). Later. | Map |

## 10. Art direction **[Decided: low-poly is the final look if it looks good enough]**

The gems are procedural 3D and the owner likes them. Extend that into a single language for everything:

- **Stones, dice, settings, creatures** are all real low-poly geometry with flat shading and one shared lighting rig (the four-light rig already in `gem_view.gd`). Creatures are crystal clusters, stacked-stone golems, refractive slimes, moths with mica wings. No sprites, no painted illustration, nothing that reads as AI-generated.
- **UI** is flat, dark slate with one warm accent, a single line weight for pictographs, one display face and one text face. Panels are quiet. Only stones, dice and beams glow.
- **Motion** is physical: dice tumble, stones rotate in the light, facets snap, fog clears. No UI bounce.
- **Audio** carries the slot machine: escalating chimes on the reveal, a distinct sound per grade, a Star has a sound the player learns to listen for. Built (September 21) the same way as the stones: no files, only waveforms written in code, so the sound is as procedural as the look. See `view/audio/`.

This is the cheapest direction that can look finished, and it is cohesive by construction. If the owner would rather commission illustration, the plan changes: the 3D stones and dice stay, and everything else becomes 2D art from a single artist. Either way, the current sprites go.

## 11. Architecture

### 11.1 A live step machine, not a log and a replay

The current design resolves a whole turn on the host into an event list, publishes a snapshot, and lets the UI replay the list against a reconstructed earlier state (`playback_base`, `_projected_standing`). That is the source of the clunk, and it forces the UI to know how to rebuild intermediate states.

Replace it with a **simulation that advances one atomic step at a time**:

```
battle.step() -> Event      # resolves exactly one thing: one gem, one enemy action,
                            # one status tick, one death. Mutates state. Returns the event.
battle.done() -> bool
```

The presenter calls `step()`, animates the returned event against the *current* state (which is exactly what the event describes), and calls `step()` again when the animation ends or the player skips. No projection, no replay base, no second copy of the rules in the UI. Determinism is unchanged: the same seed and the same commands produce the same steps.

Layers:

```
sim/        pure GDScript, no scene tree: dice, hands, patterns, gems, inclusions,
            resonance, battle step machine, descent state machine, stone generation,
            grade, salvage. Fully testable headless.
content/    the JSON pack and its validator. Skills, inclusions, dice, settings,
            creatures, wardens, mines, oddities, commissions. Studio edits it.
view/       scenes: Home (tabs), Descent, Battle, Landing, Oddity, Reveal, Summary.
            One World3D for the battle. Thumbnail caches for stones and dice.
profile/    the save: vault, bowl, settings, records, bench upgrades. Atomic writes.
net/        (later) host steps the sim and streams each Event; guests render.
```

### 11.2 Co-op from the ground up **[Decided]**

There is one code path for one player and for four. The **host** owns the run and battle state, validates every command, and advances the simulation by calling `step()` on a timer paced by each event's nominal duration. Every step is broadcast as `{event, patch, revision}` where `patch` is a generic diff of the state dictionary, so a guest's mirror is updated by applying the patch and animating the event against it. No guest ever runs the rules. Solo play is the host with a loopback client, so the view code never knows the difference.

Joining and reconnecting send one full snapshot. A disconnected player's hand auto-locks after a countdown so the party is never stuck; on reconnect they take their seat back. Host loss ends the run at the last landing checkpoint, which the host can reopen. Steam is the release transport and ENet the development one, behind the same interface, so a later mobile build can add a third.

Party interactions the rules support: voting on tunnels and the lift, giving stones and dice at landings, ally-targeted gems, encounter budgets by party size, and per-player hauls, ore and loupes.

### 11.3 Performance

- **Thumbnail cache.** Render each distinct stone (hashed by skill, C's and inclusions) once to a texture at appraisal time. Grids of stones are textures. Only the focused stone is live 3D.
- **One 3D world in battle.** Dice are meshes in the battle scene, not one SubViewport each.
- **Scene-based UI.** Screens are `.tscn` instances bound to state, updated by signal, never rebuilt wholesale on every change.
- **Pure sim.** The rules never touch nodes, so they are cheap and can run thousands of times for balance bots.

## 12. Content scale at launch

| Kind | v1 | Later |
|---|---|---|
| Skills | 36 (6 per colour) | 60+ |
| Inclusions | 30 | 60+ |
| Dice | 6 shapes × 5 face sets + 6 special faces + 8 engravings | more engravings |
| Settings | 5 | 10 |
| Mines | 2 (Quarry, Grotto), each with 3 Wardens | 5 |
| Creatures | 8 per mine | more |
| Oddities | 14 | 25 |
| Commissions | templates, 6 kinds | named quests |

## 13. Build plan

Each phase ends with something playable and a passing headless check. Sizes are rough and assume one person working with an AI pair.

| Phase | Deliverable | Rough size |
|---|---|---|
| **0. Design lock** | Answers to the questions below folded into this document. A content spreadsheet: 36 skills with ladders and Flawless lines, 30 inclusions, dice, 5 settings, 2 mines of creatures, 14 oddities. | 2–3 days |
| **1. New sim** | Dice, hands, patterns, stones with the new C's and inclusions, Grade, the skill and inclusion rule language, Resonance with Harmony and retriggers, the battle step machine with party-size budgets, creatures and intents, stone generation by depth, the descent state machine, salvage, the state patch for streaming. Headless tests and a balance bot. Old sim deleted. | 1–2 weeks |
| **2. Host, client and battle screen** | The host/loopback/network client with one interface, then the most-played screen: first-person chamber in one World3D, dice tray, gem rail with live triggers, forecast strip, creature arc with intents, ally panels, target pick, one-step-at-a-time resolution. Procedural crystal creatures. Playable from a debug menu with a fixed setting, solo and over ENet. | 2 weeks |
| **3. The Descent** | Shaft, chamber choice with votes, fights, veins, oddities, landings with lift, lapidary, merchant, bench and give, Wardens, extraction, salvage, the run summary. Endless below 24. | 1–2 weeks |
| **4. Home and lobby** | Tabs: Appraise with the full reveal ceremony, Vault (one per skill) with showcase, Bench with drag and drop and live forecast, Shop, Ledger with commissions and records, Map with the party lobby and Steam invites. Profile save. First full loop. | 1–2 weeks |
| **5. Look and sound** | Low-poly creatures and settings, materials, beams and glints, dice and stone motion, the reveal's audio, UI theme pass, accessibility (text scale, reduced motion, colour-blind safe pictographs). | 2 weeks |
| **6. Content and balance** | Second mine's Wardens, more skills and inclusions, hazard tiers, commission quests, balance passes from bot data and play, reconnect polish. | ongoing |

Phases 1 and 2 overlap: the sim's tests come first, the battle screen grows against them.

## 14. Standing assumptions

Desktop and Steam are the target, with the transport kept abstract for a possible mobile build. Loadout stones are never at risk. Odds are shown to the player everywhere a gamble happens. Godot 4.7 stays. "Deep Cut" should get a trademark search before release: the singular title exists only as itch.io jam games, but "Deep Cuts" is a shipped Steam title and "Deep Cut Studio" is a tabletop publisher.

## 15. Status, September 18, 2026

| Phase | State |
|---|---|
| 0 Design lock | Done. |
| 1 New sim | Done. `sim/` is pure and headless-tested: 1,661 dice/pattern assertions, 383 stone/rule/forge, 109 battle, 443 descent/profile. Whole runs replay from a seed; the forecast equals what happens; a mirror fed patches matches the host after every step. |
| 2 Host, client, battle screen | First pass. One session class hosts or joins (ENet now, Steam transport carried over, not yet wired to the lobby). The battle screen is first person in one World3D with procedural crystal creatures, plates with intents, the rail with live trigger marks, the dice tray and the forecast. |
| 3 The Descent | First pass. Tunnels with votes, fights, elites, veins, all fourteen oddities with their pickers, landings (haul, bench, merchant, lift, give), Wardens with hoards, salvage, Endless. |
| 4 Home | First pass. Map with party and LAN, Bench, Vault (one per skill), Appraise (a plain reveal, not yet the ceremony), Ledger. Profile and checkpoints save atomically. |
| 5 Look and sound | Look: first full pass (September 19). Seven battle biomes by depth with Warden and elite halls, fog, lights, flares, particles and a camera rig; effects for every gem and creature move; a shaft map and a mines map; icon-led screens throughout; the stone and die thumbnail cache. Sound: first full pass (September 21). 69 procedural sounds in `view/audio/`, written sample by sample and baked on a worker thread at boot; a pooled, panned mixer on its own bus; the interface, the dice, every gem colour, blows, afflictions, deaths, the mine and the reveal ceremony all speak, and a Star has a sound of its own. Master and effects volume on the settings page. |
| 6 Content and balance | One mine with eight creatures and three Wardens; 44 skills; 31 inclusions; 17 dice; 5 settings. No balance pass yet. |

Next, in order: the full reveal ceremony (a first version plays on the Appraise tab, and its audio is in); a balance bot over the real content; the second mine; Steam lobby wiring; music and a cave ambience bed under the sound effects.
