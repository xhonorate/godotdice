# Buffs, debuffs, and suggested additions

Updated September 24, 2026 after implementing the status changes and gem/enemy integrations. **Existing** means supported by the current simulation. Live sources are listed below; future alternatives remain clearly marked. Ability numbers still need playtesting.

The game already has a strong **Balatro-style combo engine**: copying, retriggers, multipliers, hand manipulation, and escalating gem strength. The new statuses add **Slay the Spire-style defensive planning**, softer enemy control, and effects that connect one turn to the next.

**Implemented:** stacking Dread, enemy Clouded, Combo Breaker, Ward, Retain, stack-based Curse, Charged Battery, Marked, Regeneration, Spikes, and Dulled. Current Curse/Dread gems use the new rules, and all Wardens—including the Foreman—start each fight with **1 Ward**. The revised gem sources and eight enemy integrations below are live. The pack contains **103 skill gems** (37 added in October 2026, see [Todo.md](Todo.md)). Lifeline, permanent run upgrades, temporary gem ranks, paid Gold effects and the approved additions are also live; see [Todo.md](Todo.md) for the complete catalogue.

## Existing combat buffs and debuffs

Statuses can affect players or enemies where their mechanics apply. Charged Battery powers player rails; Dulled modifies socketed gems; enemy Clouded disables abilities while player Clouded disables sockets. Dice and socket restrictions also have dedicated state, so they are included here.

### Harmful effects and restrictions

| Effect | What it currently does | Duration / stacking | Current sources |
| --- | --- | --- | --- |
| **Poison** | Loses HP equal to its stacks at the shared end-of-turn tick. Bypasses Block and is not amplified by Curse. | Adds stacks; loses 1 stack per tick. Clears after combat. | Venom, Miasma (2 per even die), Flawless Detonate’s poison spread, Ember's Flawless line, Emberline inclusion, Rue's Birthstone; Silt Slime and Vein Wraith. |
| **Stun** | A player skips their whole rail and Birthstone; an enemy skips its action phase. | Adds stacks; consumes 1 per skipped action. After an enemy misses 3 consecutive actions to Stun, Combo Breaker clears all remaining Stun and grants immunity through the following turn. | Flawless Crush, Ardor's Phalanx, Puck's Full Motley. Player Stun is supported; no live enemy currently applies it. |
| **Curse / Cursed** | Each stack reduces outgoing hit damage by **10 percentage points** and increases incoming hit damage by **10%**. At 10 stacks, outgoing damage is zero and incoming damage is doubled. Poison and HP costs are unaffected. | **Maximum 10 stacks** on players and enemies. Applications add up to the cap; loses **1 stack per shared turn-end tick**. Clears after combat. | Curse grants one base stack per rolled 1, also lowers max HP by 0/1/2/3/4 per 1 by Cut. Flawless deals damage equal to target stacks. Mirror Regent’s later-phase Splinter applies 1 to all players. |
| **Dread** | Each stack makes all enemy dice **one tier smaller**, minimum d2. | Applications add with no stack cap. Loses **1 stack after each enemy action phase**, including skipped phases. Dice recover one tier as the remaining penalty permits; excess stacks can hold them at d2. | Dread grants 1/1/2/2/3 base stacks by Cut, scaled by carats. Flawless affects all enemies. |
| **Bound** | Suppresses dice from an enemy's next action. Can suppress every die and prevent that action entirely. | Amounts add; consumed at the next enemy action. | Hex and Bind; Flawless Bind suppresses an additional die. |
| **Dice taken** | A player rolls fewer dice on the next turn. Removes dice from the end of the bowl, preserving at least one. | Amounts add; consumed when that next hand is rolled. | Cave Tick's Latch, Magpie's Snatch, Foreman's Collapse. |
| **Buried** | A filled socket cannot fire. | Clears at the next turn start; living Foremen can bury sockets again. Never takes the last available filled socket. | The Foreman. |
| **Clouded** | A filled socket cannot fire until a Clouder takes direct HP damage. That clears the party's fog. | Also clears at the next turn start; living Clouders can reapply it. Never takes the last available filled socket. | Clouder. Blocked hits do not clear it. |
| **Clouded (enemy)** | Disables **one random ability slot** from the enemy's current moveset. Other abilities and dice still work. The disabled row is visibly marked CLOUDED. | Stacks are action-phase duration. Reapplication adds duration to the same slot rather than choosing additional skills. Loses 1 after each action, including skipped ones. Does not clear when hit. On a phase change, the corresponding slot stays disabled, clamped to the new moveset size. | Mist: 1 base action; Flawless applies to all enemies. Flawless Hex also applies 1 Clouded. Ward can block either. |
| **Marked** | The next direct attack hit takes **+25% damage per stack**. Ten stacks mean **350% normal damage**. Works on players and enemies. | No cap or turn decay. **All stacks are consumed by that hit**, including a fully blocked hit. Only the first hit of a multi-hit attack benefits; Poison, Spikes, and reflection do not consume marks. Ends with combat. | Etch: 2 base stacks, Flawless +1. Vein Wraith’s Omen: 1 on all players. |
| **Dulled** | Each stack reduces effective gem Cut by one step, after other bonuses and the normal Perfect ceiling. Minimum Poor; **5 stacks always guarantee Poor**. Birthstone triggers are unaffected. | No cap. Applications add; loses 1 at shared turn end. In the five-rung ladder, 4 stacks already reduce Perfect to Poor; extra stacks extend recovery. | Clouder’s Abrasive Fog (roll 6+) and Drill’s Grind (maximum face): 1 on all players. |
| **No rerolls** | Reroll allowance is zero on odd-numbered turns. Initial rolls still happen; Puck's separate flip action remains available. | Re-evaluated each turn while the Drill lives. | The Drill's Roller trait. |
| **Came up empty** | Cancels the next ordinary gem resolution after losing Double Down's coin toss. | A pending one-use flag; resets when consumed or at the next rail start. | Double Down. |
| **Reroll drain** | Every living player loses 1 HP per living Lantern Moth whenever any player spends a reroll. Cannot reduce HP below 1. | While the moths live; charged per reroll action, not per die rerolled. | Lantern Moth; paired with its extra-reroll benefit. |
| **Stolen pyrite** | A Magpie steals up to 3 of the player's combat-earned pyrite when its hit causes HP loss. | Held by the enemy; a player who kills it with direct damage receives the stored amount. | Magpie. It does not directly take the run's existing ore balance. |
| **Downed** | Cannot act or receive ordinary healing. | Until revived or the run's recovery rules intervene; a combat revive makes the player eligible to act next turn. | Reaching 0 HP. This is a unit state rather than a stackable debuff. |
| **Festering** | Healing you receive is halved. | Counts down 1 at the tick; a fresh enemy application survives the tick that follows it. | Cap Shambler's Spore Cloud, the Spore Mother's Choke (a 6), the Heartrot's aura (every turn while it lives). |
| **Burn** | At the end of the turn, hurts for its stacks like Poison, but Block soaks it first; then loses one stack. | Adds stacks; loses 1 per tick. Clears after combat. | Salamander's Ember (the roll), Forge Imp's Cackle (the roll), Ember Crawler's Bite (4), Cinder Moth's Embers (3), the Smelter's Pour (the roll), the Kiln Wyrm's Firebreath (the pair) and Lavafall (20). |
| **Scorched** | Block you gain is halved, rounded up. | Counts down 1 a turn, deferred like Festering. | Fire Tick's Ignite, the Kiln Wyrm's Scorch (a crown), each reroll spent under a Cinder Moth. |
| **Dampened** | Gems ring for half the Resonance they would (the half-points carry, so two gems still make one). | While a Null Shade lives. | Null Shade. |
| **Dread (player)** | Your whole bowl is thrown a size smaller a stack next turn; the dice themselves are untouched. | Spent as that hand is rolled. | Drowned Miner's Pull Under. |
| **Locked die** | A creature's lock: the die comes up next turn showing what it shows now and cannot be rerolled. | One turn. | Seep Eel's Shock (highest die), Mycel Weaver's Web (one die), Will-o'-Wisp's Lure (a 6), the Prismarch against a straight. |
| **Dice worn down** | A die shrunk a size, a face burned blank, or a die destroyed, for the rest of the fight; the fight gives it back. Cut and Pruned faces are for good. | The fight; Cut and Prune for the run. | Forge Imp's Heat Treat (one die smaller), the Smelter's Melt (a showing face blank), the Entropy Eye's Unmake (a die destroyed), the Infinite Void's Existential Dread (every die smaller); the Glazier's Cut (its top face, for good) and the Gardener's Prune (every showing face, for good). |
| **Backlash** | While a Riftling Swarm or the Infinite Void lives, every gem that fires costs its owner 1 HP, wherever it sits on the rail (never the last). | While the creature lives. | Riftling Swarm, the Infinite Void. |
| **Gem held** | A gem is off your rail and in a creature's keeping until it dies; the Collector fires every gem it holds as its own on a 6. | Until its death, when it is returned. | Hoard Mimic's Gulp (the gem that hit it hardest), the Collector's Acquire (the finest gem it can use). |
| **Snuffed gem** | A gem is melted for the rest of the fight. | The fight. | Null Shade's Snuff (even roll), the Kiln Wyrm's Melt near death. |

**Late enemy applications:** a new player Curse or Dulled applied after the rails survives the immediate turn-end tick. It begins losing one stack at the following turn end; reapplying an existing stack does not postpone normal decay.

### Helpful combat effects and rail modifiers

| Effect | What it currently does | Duration / stacking | Current sources |
| --- | --- | --- | --- |
| **Block** | Absorbs hit damage before HP. Does not stop Poison or direct HP costs. | Adds. At the player turn start / enemy-side action start, Retain preserves up to its amount and all other Block clears. | Blue gems, Flawless lines, inclusions, Birthstones, Vesper, and enemy defensive moves. |
| **Resonance** | Builds as gems fire; powers Birthstones, gem triggers, and character passives. Normal base gain is 1 per firing. | Starts each turn at the consumed Charged amount, otherwise zero. Replays keep building it. **A fizzle does not erase Resonance.** | Every firing gem; Prism and inclusions add more; Charged Battery seeds the next turn. |
| **Harmony** | A gem that fires after another firing gem with a shared color adds 1 extra Resonance. | Evaluated on each firing. A fizzle breaks the chain of consecutive firings. | Rail order, Zoning, Alexandrite, and opals' color behavior. |
| **Amplified** | Multiplies the next evaluated gem's magnitude, affecting scaled amounts and whole-number effect proc counts. | Multipliers multiply. Consumed by the next eligible gem evaluation even if it fizzles; buried/clouded sockets return before consuming it. | Winning Double Down; Stake adds +50%, or +75% Flawless, × its magnitude, after paying its exact Pyrite price. |
| **Sharpened / next Cut bonus** | Judges the next evaluated gem at additional Cut steps. | Steps add; consumed on evaluation, including a fizzle. Does not permanently recut the stone. | Feather inclusion. Facet now grants fight-long Cut instead. |
| **Extra rerolls next turn** | Adds rerolls to the next planning phase. | Grants add; transferred to the allowance and consumed at turn start. | Cascade. The Drill can still set available rerolls to zero. |
| **Carat growth** | Raises affected gems’ effective carats for the rest of the fight. | Adds on each activation; persists across turns, ends with the fight. | Fire Opal raises every gem but itself; Enrich raises its neighbours by 1 (all gems Flawless). |
| **Cut growth** | Raises affected gems' effective Cut for the rest of the fight. | Adds on each activation; effect ladders stop improving at their highest rung. | Fire Opal’s Flawless line, on every gem but itself; Facet raises adjacent gems by 1 (all gems Flawless). |
| **Repeat next** | Grants extra firings to the next gem, or the Birthstone when Prelude is last. | Pending amounts add; consumed by the next eligible resolution. A gem still has to fire to use the extra firings. | Prelude. |
| **Void copying** | Lays a Void copy of the last gem that fired into the rail, riding the copying gem's socket and firing right after it. | For the rest of the fight, and never a copy of another opal. The copy is the fight's own: nothing carries it home. | Echo (2 copies Flawless); a heavier Echo procs more copies. |
| **Color replay** | Repeats previously fired gems of a selected color in rail order. | Immediate; eligible repeats generate Resonance again. | Red, Blue, Green, Violet, Gold, and White Seam opals. |
| **Fizzle recovery** | Forces earlier fizzled gems to try firing even when their hand trigger was unmet. | Immediate; the first two that stayed dark, or all of them from a Flawless stone. Does not remove burial, fog, or Fracture's veto. | Matrix. |
| **Whole-rail replay** | Replays gems that fired, then eligible Birthstone work, continuing to build Resonance. | Immediate; Encore cannot recursively replay itself. | Cadence's Encore. |
| **Skill copying** | Uses the nearest non-opal gem *behind* it, with the copying stone's own carats, Cut, Clarity, and inclusions. | While arranged that way; it looks as far back along the rail as it must. | Doublet. |
| **Face growth** | Raises the current face of the first matched real die by 1 per proc (heavier stones proc more); Flawless raises every face of that die. An exploding die is judged by the face it landed on, not by what it threw again. Also updates the current roll. | Lasts this run; a face has no ceiling. Phantom dice excluded. Stored collection unchanged. | Glimmer, matching dice below 7/6/5/4/3 by Cut. |
| **Match dice** | Changes eligible dice to join the best matching set. | Current hand only. | Mirror (the former Polish matching effect). |
| **Flip low dice** | Replaces a low value with `top + 1 − value`. | Current hand only. Useful depends on the build. | No current gem source; legacy simulation hook. |
| **Phantom dice** | Adds copies of the highest eligible die for later gems to read. | Current hand only; does not add permanent dice to the bowl. | Refract. |
| **Combo Breaker** | After the third consecutive action lost to Stun, an enemy clears every remaining Stun stack and rejects new Stun through its next turn. Rejections do not spend Ward. | Resets the stun streak. Any ordinary action also breaks the streak. Protects against Stun, not Bind or Clouded. **Replaces Resolve.** | Automatic on every enemy, including Wardens. |
| **Ward** | Blocks one harmful effect application per charge: Poison, Stun, Curse, Dread, dice theft/suppression, Clouded, Marked, Dulled, max HP loss, or a creature's burial/fog application. An application can contain several stacks. | Adds up to **99**, persists for the fight, and consumes one charge when it blocks. Existing immunity takes precedence and does not waste Ward. Does not block hits, HP costs, Block stripping, or the Drill's reroll rule. | **All Wardens, including the Foreman, start with 1**. Flawless Aegis grants 1 per ally; Flawless Renewal and Gilded Armor grant 1 to self; Foreman’s Shore Up replenishes 1 on a 12. |
| **Retain** | Preserves up to N unspent Block when that unit's Block would reset. Does not generate Block. | Grants add, retaining the originally proposed **20-point cap**. Consumed at the next reset. Players reset at turn start; enemies at enemy-side action start. | Flawless Bulwark grants half its gained Block; Mortar grants 10/15/20/25/30% of current Block (+10 percentage points Flawless); Flawless Bastion grants 4 per ally; Quartz Golem’s Harden grants 3. |
| **Charged Battery** | At the next player turn start, consumes all Charged stacks and sets starting Resonance to that amount. A count-up animation and pulse show the transfer; allies get a floating notification. Forecasts and rail start preserve the charged starting value. | No cap. Applications add. Charge is spent at turn start even if Stun later prevents that rail from acting. It does not carry forward a second time. | Flawless Prism grants 2; Flawless Bloom grants 1 per odd die to each ally. |
| **Regeneration** | Heals HP equal to stacks at shared turn end, **after Poison**, then loses 1 stack. Cannot exceed max HP or revive a unit killed by Poison. | No cap. Applications add; loses 1 even if already at full HP. Clears after combat. | Flawless Mend grants 2; Silt Slime’s Reknit grants 2 on a maximum face. |
| **Spikes** | Retaliates for N hit damage once per attacking gem firing/Birthstone/ability, including blocked hits. A multi-hit ability triggers it once per defender. Retaliation can be blocked and modified by Curse and enemy Enrage. | No cap. Applications add; lasts the fight (until October 2026 it expired at the owner's next Block reset). Retaliation cannot trigger Spikes/reflection recursively or consume Marked. A party-wide triggering hit finishes hitting everyone before combat settles. | Caltrop (1 per odd die); Flawless Chainmail (1 per later gem); Flawless Anchor grants 2; Glass Wyrm’s Coil grants 2. Former proposal name: Bristles. |
| **Lifeline** | Before lethal damage downs the bearer, consumes every stack and restores that much HP, up to maximum HP. Works against direct hits, Poison and retaliation. Flawless applications also store revival Block. | No cap or decay; lasts this fight. Reapplications add. Cannot rescue an ally already downed before application. Other statuses remain after rescue. | Lifeline grants matched value to each living ally. |
| **Clarity growth** | Raises affected gems’ effective Clarity, including its Resonance, magnitude and Flawless line. Preserves existing inclusions and stored stone values. | Adds for this fight, capped at Flawless. | Polish grants adjacent gems +1; Flawless affects all gems. |
| **Maximum HP growth** | Raises current and maximum HP by 1 per proc (heavier stones proc more). | Each Flawless firing; lasts this run without changing the stored collection. | Thrive, requiring a highest roll of 12/11/10/9/8. |
| **Larger enemy dice** | Increases enemy die size tiers, up to d100; affects unrolled dice and later turns. | Stacks for the fight. Dread temporarily subtracts one tier from the resulting sizes. | Foreman's later-phase Reinforce. |

Gem amounts above are subject to the four C's. Larger magnitude directly scales damage, Block, healing, pyrite, Poison, Block removal, Retain, Regeneration, Spikes, and Lifeline. Exact result percentages and explicitly flat upgrades do not receive another multiplier. Most other gem effects gain whole-number applications, with a chance of an additional application from fractional magnitude. Consequently “one Stun” or “one reroll” in base content can become several on a heavy stone.

### Recovery and removal tools

These are immediate actions, rather than buffs with a duration, but they define the available counterplay.

| Tool | Current behavior | Sources |
| --- | --- | --- |
| **Heal** | Restores HP up to maximum; cannot revive. Regeneration provides delayed healing using the same HP limits. | Mend, Graft, Bloom, Renewal, Thrive, some Flawless lines, Grain, passives, rest, Field Medic. |
| **Cleanse** | Removes individual stacks in this order: **Poison → Burn → Stun → Curse → Marked → Dulled → enemy Clouded → Festering → Scorched → Dread → bound dice**. Never removes beneficial statuses. Does not remove existing player socket restrictions or dice theft. | Renewal; Flawless Shelter; Ardor’s Phalanx; the Spore Mother's Shed (everything). |
| **Revive (legacy hook)** | Restores a downed ally, clearing statuses and delaying its action until next turn. No current gem uses it; Lifeline instead prevents a lethal downing with a stored buff. | Simulation hook only. |
| **Remove Block** | Immediately subtracts Block; does not prevent future Block gain. | Shatter; Vein Wraith's Wail and Mirror Regent's Refraction. |
| **Consume Poison** | Consumes all target Poison before dealing 4 base damage per stack. Flawless applies half the consumed stacks, rounded down, to each adjacent enemy. Spread is separately Ward-blockable. | Detonate. |
| **Poison conversion** | Heals the weakest ally for 20/30/40/50/60% of all living enemy Poison without consuming it; Flawless heals all allies. | Siphon. |
| **Accelerate Poison** | Immediately ticks existing enemy Poison, including its normal one-stack decay and Rue's healing trigger. | Rue's Draught and Dregs. |

## Statuses and turn effects added with the October 2026 gems

| Effect | What it does | Rules | Sources |
| --- | --- | --- | --- |
| **Envenomed** | Every hit its owner lands that gets past Block also applies that much Poison. | Lasts the fight; stacks add. A hit the Block soaks entirely applies nothing. | Arsenic (1, Flawless 2). |
| **Chainmail / Contagion** | For the rest of the turn every gem that fires after it (the Birthstone and replays included) gives its owner Block or Spikes, or poisons the target. | Cleared as the next turn begins. | Chainmail, Contagion. |
| **Rebound** | For the rest of the turn, each time its owner gains Block the target takes a hit. | Block an ally gives counts. Cleared as the next turn begins. | Rebound. |
| **Phantoms kept** | This turn's phantom dice stay in the hand into the next, showing what they showed. | Only while the opal keeps firing. | Contra Luz. |
| **Drops** | A die soaks drops; at three it is a size bigger (smaller on a Flawless stone) for the rest of the run. | Kept on the die across fights; stops at the d100 or the d2. | Hydrophane. |

## Creature traits from the Bestiary (October 2, revised October 5, 2026)

Traits are what a creature is rather than what it rolls for (`traits` in content, `DeepCreatures.traits_for`); a phase may add or remove them. See [docs/BESTIARY.md](docs/BESTIARY.md).

| Trait | What it does | Who |
| --- | --- | --- |
| **Steadfast** | Stun, Bound, Clouded and Dread applications are halved (rounded up, at least 1); after an action lost to Stun the next Stun is resisted until it acts. | the Undertow, the Prismarch, the Anvil Knight, the Kiln Wyrm, a remembered Rift Warden. |
| **Sturdy N%** | No single hit takes more than N% of its max HP off it. | Geode Golem 25%, the Hollow Crown 15%, the Infinite Void 10%, a remembered Rift Warden 25%. |
| **Burrowed** | Under the floor until its next action: cannot be targeted; gems aimed at it hit another creature, gems that hit every creature miss it. | Pit Mole's Dig In, the Undertow's Dive. |
| **Refracting / Mirror / Drinking a colour** | Refracting: until its next action, half of every blow on it goes back at every player. Mirror: the next blow on it goes back whole at whoever threw it. Drinking a colour: gems of that colour do it no damage, and the block, healing or Ward they would give their owner goes to it. | Prism Golem's Refract, Echo Sprite's Mirror, the Kaleidoscope's Absorb (and Turn, a second colour). |
| **Strength** | A point more on every blow it deals, for the fight. Players can carry it too since October 2026. | The Temper gem (1, Flawless 2), Slag Hound's Howl (every creature), Root Horror's Grow (the pair), the Anvil Knight's Quench (the roll), the Assayer's Weigh (1), the Refractor (1 per new colour it sees fired). |
| **Weighs every gem** | While it stands no gem counts for more than N carats. | the Assayer (5). |
| **Flees after N** | Leaves the fight after its Nth action with everything it stole; a countdown chip on it says how many actions it has left. | Glint Magpie and Gilded Magpie (4). |
| **Escalating** | +N damage per action taken in the phase. | the Drill below 60% (+1). |
| **Aura** | Every player is kept at a status while it lives. | the Heartrot (Festering 1). |
| **Shielded by escorts / Fed by escorts** | Half damage while a Prism floats; heals 10 a turn while a Tendril stands. A Heartrot's 10 grows a Tendril back, room allowing. | the Prismarch, the Heartrot. |
| **Charging** | A blow wound up over an action: it takes half damage meanwhile and throws everything it was dealt back at every player. | the Prismarch below 33%, every other action. |
| **Empowered** | Its next attack deals N% more. | Croupier Crab on a 20, the Hollow Crown on a crown. |
| **Grows its die / throws again / stumbles** | A high roll grows its die a size (to a d20) and throws it again, three times at most; a 1 ends its action. | the Hollow Crown. |
| **Swollen** | Its death burst poisons for its swelling. | Puffball. |
| **Hoard** | Drops a raw stone when it dies. | Hoard Mimic. |

## Existing creature traits and encounter modifiers

These are intrinsic rules of a creature, not cleansable statuses. Several produce effects already listed above.

| Trait | Creature | Current behavior |
| --- | --- | --- |
| **Latcher** | Cave Tick | Its Latch move applies Dice taken. Despite the internal name `steal_high_die`, it does not search for the highest die. |
| **Splits** | A surviving hit that removes at least 40% of its maximum HP splits its remaining HP between it and a new copy, while fewer than four creatures stand. The copy starts without ordinary statuses. | Silt Slime; a remembered Rift Warden. |
| **Hardens** | Quartz Golem | At turn start, raises Block to at least the party's highest initial rolled value. Does not continuously track later rerolls. |
| **Thief** | Magpie | Applies the pyrite theft described above when a hit penetrates Block. |
| **Lantern** | Lantern Moth | Each living moth gives everyone +1 reroll each turn, coupled to the party-wide reroll drain. |
| **Unpoisonable** | Vein Wraith | Rejects Poison applications. |
| **Fogger** | Clouder | Clouds a socket on each player's rail; direct HP damage to a Clouder clears the party's fog. |
| **Mirror-hide** | Glass Wyrm | When a player at Resonance 0 or 1 deals direct HP damage to it, reflects half that HP loss as a hit against every living player. Reflection can be blocked. |
| **Buries** | The Foreman | Buries a socket on each player's rail at turn start. |
| **Mirror** | The Mirror Regent | Gains damage based on half the highest individual player's previous-turn direct HP damage dealt, capped at 6 before dividing across its dice. It is not literally copying a gem. |
| **Roller** | The Drill | Prevents rerolls on odd turns. |
| **Enraged phase** | Foreman / Mirror Regent | Switches movesets at 50% / 40% HP or below, respectively. This is separate from turn-based Enrage. |
| **Enrage** | All enemies | From turn 7, adds 2 damage per hit, then 4 on turn 8, 6 on turn 9, etc. |
| **Depth / party scaling** | All enemies | Depth raises HP and damage bonuses; each additional player adds 15% to the depth-scaled HP. Structural encounter scaling, not a status to dispel. |

## Existing run buffs, rewards, and drawbacks

Glimmer’s physical die-face upgrades and Thrive’s maximum HP gains persist for the current run. Appraise reveals raw bag stones and their inclusions during combat; it deals their combined sale value × its magnitude once. Wager and Stake spend available bag Pyrite plus combat earnings; each replay requires fresh payment. Prices/refunds remain exact through elite/warden settlement. On defeat, unbanked earnings and refund profit are lost, while net spending still reduces the bag balance to a minimum of zero.

| Effect | Current behavior | Duration / source |
| --- | --- | --- |
| **Hot Streak** | Accumulates reward quality bonus. For ordinary/elite fight drops, every point adds 0.5 percentage points to drop chance; every 10 points adds 1 generation-luck bonus. | That fight's settlement; Florin's Hot Streak only, now that Windfall has been removed. Not a guaranteed grade increase. |
| **Sparkle** | **All stored Sparkle is consumed on the next stone find**, adding **+0.1 generation luck per stack** (even below 5), so a full hundred stacks is worth ten points. Applies to the descent’s stone-find sources: battle drops, Birthstone rewards, veins/vugs, and motherlodes. Only the first stone of a multi-stone find spends the stored amount. | **Maximum 100**; applications add up to the cap and carry between fights. Prospect supplies it. Not a guaranteed grade increase; shop/hoard offers and separately generated oddity stones retain their existing generation rules. |
| **Shrine blessing** | +1 effective carat to gems whose base skill trigger type matches the selected pattern. | Rest of the run; Shrine of the Pattern. Choosing another replaces the selection. |
| **Hardy / Iron Constitution** | +12% / +25% maximum HP, with current HP adjusted by the same absolute increase. | Run; Grubstake. |
| **Thinner Blood** | −10% maximum HP, with current HP adjusted too. | Run; Grubstake cost. |
| **Heads or Tails** | Randomly raises or lowers maximum HP by 20%, adjusting current HP too. | Run; Grubstake gamble. |
| **Soft Rock** | Enemies start at half current HP for the benefiting player's first three fights. Maximum HP is unchanged. | Three fights; Grubstake. Benefits the party and does not halve HP repeatedly when several players have it. |
| **Steady Hands** | +1 reroll per turn at depths up to and including 4. | Early run; Grubstake. |
| **Six Carats** | +6 stored carats on one randomly selected rail stone, subject to the stored carat cap. | Run copy of that stone; Grubstake. |
| **Chipped** | −1 stored Cut step on one randomly selected rail stone. | Run copy of that stone; Grubstake cost. Distinct from the Chip inclusion. |
| **Hammered** | Raises one random eligible die by a size tier. | Run die; Grubstake. Larger dice are not universally better for low-value/set builds. |
| **A Wild Face** | Converts one random eligible die's highest plain face to wild. | Run die; Grubstake. |
| **A Pinpoint / A Star** | Adds an inclusion from the named class to a random rail stone. | Run copy of that stone; Grubstake. “A Star” draws from the STAR inclusion class, not necessarily the specific Star inclusion. |
| **Recut / Clarified / Truer Cut** | Rerolls a stone's Cut or Clarity; Truer Cut keeps the better of two Cut rolls with a luck bonus. | Run stone changes; Grubstake. Fresh rolls can still worsen the original stone. |
| **A Bad Fall** | Immediately loses 30% of current HP, leaving at least 1. | Grubstake cost; damage taken, not an ongoing debuff. |
| **Bust** | Florin's Birthstone resolving with no crowns: the pot is lost and half of it is dealt to him as damage (Block soaks it). | Immediate. Staked pyrite never returns; the fight payout is still floored at zero. |

Other Grubstakes—Staked, Well Staked, A Raw Stone, Pick of Three, A Precious Stone, Crack a Geode, Roll for It, and Sight Unseen—give immediate currency or items rather than an ongoing buff. Oddities and workshops also alter items through recutting, annealing, fusion, inclusions, face changes, and resizing; their lasting combat effects are covered by the item modifiers below. Mining HP costs and purchases are costs, not additional status types.

## Existing character passives

| Character | Passive | Effect |
| --- | --- | --- |
| Ardor | **Second Wind** | Heals the rail's Resonance per unused reroll as an active rail closes. |
| Vesper | **Riposte** | Gains Block equal to current Resonance for each positive-damage hit landed, including a hit absorbed by enemy Block. |
| Cadence | **Study** | +1 reroll every turn. |
| Rue | **Leech** | Heals current Resonance whenever Poison damages an enemy. |
| Puck | **Sleight** | One free flip of a plain die face per turn. |
| Florin | **House Money** | Each fight opens with a tenth of his owned pyrite already in the pot, taken out of the bank at once. |

Birthstone benefits reuse the combat effects above: Block, damage, Stun, Cleanse, Poison and extra ticks, rail replay, reward bonuses, and pyrite. They are not separate generic statuses.

## Existing item buffs and drawbacks

### All 31 inclusions

These are attached to stones. Their effects generally last while the stone has the inclusion; they are not removed by Cleanse. The six Zoning variants share one row.

| Inclusion | Effect |
| --- | --- |
| **Pinpoint of Gold** | +2 pyrite each firing. |
| **Silk** | +2 Block each firing. |
| **Needle** | Adds 1 damage per die the gem reads to each of its damage effects. |
| **Grain** | Heals 1 each firing. |
| **Spark** | +1 to the gem's base Resonance gain, before Clarity multiplies it. |
| **Emberline** | Applies 1 Poison to the target each firing. |
| **Glint** | Gains pyrite equal to the matched die count. |
| **Dusting** | Gains Block equal to the matched die count. |
| **Veil** | This gem reads its lowest eligible die as the highest value. Does not alter later gems' hand. |
| **Cat's Eye** | This gem treats plain 1s as wild. |
| **Graining** | This gem counts held dice twice in set patterns. |
| **Red / Blue / Green / Violet / Gold / White Zoning** | Six inclusions: adds the named color for fitting and color interactions. |
| **Feather** | Gives the next evaluated gem +1 Cut step after this gem fires. |
| **Twinning Wisp** | Fires an extra time if the preceding gem fired. |
| **Fingerprint** | Content says “carries one inclusion of the gem before it,” but its modifier currently has no simulation handler. **Defined, apparently inactive.** |
| **Halo** | Adjacent gems sharing a color gain +1 effective carat. |
| **Resonant Vein** | +2 to base Resonance gain, before Clarity multiplies it. |
| **Fracture** | ×2 magnitude, but fizzles when its evaluated hand contains a disallowed 1. |
| **Bruise** | ×1.5 magnitude; loses 2 HP each firing, including repeats, leaving at least 1 HP. |
| **Knot** | +2 effective carats; locks the stone against removal/repositioning during the run. |
| **Cavity** | Doubles effective carats; starts Cut at Poor before other Cut bonuses/penalties apply. |
| **Chip** | +3 effective carats, −1 Cut step. |
| **Star** | Bypasses an unmet hand trigger. Does not clear burial/fog or override Fracture's veto. |
| **Chatoyance** | Fires one extra time. |
| **Fluorescence** | +1 effective carat per depth below 10. |
| **Alexandrite** | Also counts as its socket's color, when the socket has a specific color. |

**Clarity bonuses:** Pristine doubles base Resonance gain. Flawless triples it, multiplies magnitude by 1.5, and enables the skill's authored Flawless line. Harmony's extra point is added afterward. Included, Etched, and Intricate provide one, two, and three inclusion slots respectively; Clear has no additional modifier.

### Etched faces, patterns and materials

| Modifier | Effect / tradeoff |
| --- | --- |
| **Wild face** | Substitutes for values in supported patterns; contributes its die's top to totals. |
| **Exploding face** | Rolls an additional face and adds its value; chains for up to three additional rolls. |
| **Shiny face** | One Resonance more for every gem it helps light. |
| **Golden face** | Pays 2 pyrite every time it is rolled or rerolled. |
| **Tally face** | Climbs by 1 permanently every time it is landed on, which raises the die's own top with it. |
| **Sticky face** | Carries into the next turn instead of being thrown again, and so counts as held. |
| **Twin face** | Counts twice in set patterns. |
| **Doubled face** | Worth twice its number wherever a number is read, so it pairs with the doubled value and not the printed one. |
| **Locked face** | Cannot be selected for reroll while that result remains in the current hand. New turns roll a fresh hand. |
| **Blank face** | Contributes no numerical value and is excluded from value/set analysis; the hand still records whether the die was held or rerolled. |
| **Pattern** | Even, Odd, Split, Gambler's, Paired, Stretched or Shallow: which numbers sit on the faces, nothing else. Shallow keeps the die's own size as its top, so every face of it is low. |
| **Coloured material** | Ruby, Sapphire, Emerald, Amethyst, Citrine, Diamond: ×1.5 magnitude on every gem of that colour the die helps fire, multiplying with each other. Opal answers to every colour; Glass does too, and breaks on one throw in ten. |
| **Other materials** | Crystal rings a Resonance every throw; Iron never shows less than a quarter of its top; Fool's Gold pays 2 pyrite a throw; Granite is immune to every enemy die effect; Blood costs 2 health to throw again and grows by 1 whenever a creature dies. |

Patterns, etchings, materials and die sizes all change a build's odds; they are item configurations rather than separate statuses. The full rules are in [docs/DICE.md](docs/DICE.md).

## Implemented integrations

These assignments are implemented in `content/deep_cut.json`. Amounts are base values before gem magnitude/proc scaling. Mist and Etch join the ordinary Violet pool; neither requires a new unlock system.

### Gems and Flawless bonuses

| Gem | Implemented change | Gameplay / ordering |
| --- | --- | --- |
| **Mist — Violet / Common** | Pair valued ≥5/4/3/2/1 by Cut; apply **1 Clouded**. Flawless applies to **all enemies**. | Disables one random ability slot; repeated firings extend that slot's duration. Ward can intercept applications. |
| **Aegis — Flawless** | **1 Ward per ally** replaces the cleanse rider. Base party Block remains. | Proactive party protection; heavy stones can grant multiple charges, up to 99. |
| **Bastion — Flawless** | **4 Retain per ally** replaces the cleanse rider. Base party Block remains. | Preserves a reserve of unspent Block for Thrive or the next enemy phase; Retain caps at 20. |
| **Prism — Flawless** | **2 Charged** replaces the extra immediate Resonance. Base Resonance remains. | Repeated firings build a larger next-turn battery; its transfer is animated at turn start. |
| **Mend — Flawless** | **2 Regeneration** replaces the Block rider. Base healing remains. | Adds delayed recovery; Poison ticks before Regeneration. |
| **Anchor — Flawless** | **2 Spikes** replaces the extra 1 Block per held die. Base **2 Block per held die** remains. | Punishes each attacking ability for the rest of the fight. |
| **Etch — Violet / Rare** | Pair valued ≥5/4/3/2/1 by Cut; apply **2 Marked**. Flawless adds **1**. | Set up a later heavy hit; the first hit spends every mark, even if Block absorbs it. |
| **Renewal — Flawless** | Gain **1 Ward** instead of extra Cleanse. Base healing and 1/1/2/2/3 Cleanse remain. | Definitions live in keyword hovers; Poison can still consume the entire cleanse. |

### Enemy abilities

| Enemy | Implemented ability | Gameplay purpose |
| --- | --- | --- |
| **Quartz Golem** | Even-roll **Harden**: existing 3 Block plus **3 Retain**. | Teaches Block persistence; Shatter can remove the reserve. |
| **Clouder** | Roll **6+**: **Abrasive Fog**, **1 Dulled** to every player. Existing socket fog remains. | Low-frequency Cut pressure: one face on its starting d6. Dread can prevent that high roll. |
| **Silt Slime** | Maximum face: **Reknit**, **2 Regeneration** to itself. | The proposed pair trigger was adapted because the Slime has only one die. Poison resolves before its heal. |
| **Vein Wraith** | Maximum face: **Omen**, **1 Marked** on all players, after Drain/Wail. | Warns of a stronger next hit from it or another enemy. Each player's Ward protects independently. |
| **Glass Wyrm** | Pair-triggered **Coil**: existing Block plus **2 Spikes**, once per action phase. | General retaliation alongside Mirror-hide's separate low-Resonance reflection. |
| **The Foreman** | **Shore Up**, on a 12: 4 Block and **1 Ward**. Opening Ward remains; later **Reinforce** still upgrades dice. | Conditional protection replaces Shore Up's old upgrade rider. |
| **Mirror Regent** | Later-phase **Splinter**, roll 16+: **1 Curse** instead of Poison. | Penalizes outgoing damage and increases incoming damage through the next player turn. |
| **The Drill** | Maximum-face **Grind**: **1 Dulled** instead of die theft. | Reduces gem Cut without shrinking the hand alongside no-reroll turns. |

Every hostile enemy application reaches **all living players**. A newly inflicted player Curse/Dulled after the rails skips that immediate end-of-turn decay so it affects the next turn. Existing stacks still lose one per turn even when reapplied. Mixed encounters can spend Omen's marks immediately through later enemies' attacks.

### Future integration alternatives — not implemented

| Candidate | Possible change | Reason to defer |
| --- | --- | --- |
| **Cascade — Flawless** | Replace its second reroll with **3 Charged**. | Prism is the first battery source; test it before adding another. |
| **Shatter — Flawless** | Strip Block and deal its normal hit, **then apply 2 Marked**. | Etch is the first Marked gem. Ordering must ensure Shatter does not consume its own marks. |

### Balance implications of the requested rules

- **Curse builds to a 10-stack cap.** Each stack means −10 percentage points outgoing damage and +10% incoming damage. Ten stacks suppress direct outgoing damage and double incoming hits; Poison, debuffs, and defensive moves still work. The gem grants one base stack per rolled 1; whole-number procs can add more, and excess stacks are discarded. Cut now scales max HP loss instead. One stack still decays per turn.
- **Dread is stronger than its old duration-only form.** Several applications can pin large dice at d2 for many actions. Ward creates an opening tax; native low-face abilities should still provide useful enemy actions.
- **Combo Breaker limits Stun specifically.** Bind can still suppress every die, and Clouded can disable a sole ability. Do not present Combo Breaker as immunity to all control.
- **Marked is spent per hit.** It favors big single blows over many small ones and is shared across the party. Different modifiers multiply: 2 incoming Curse stacks and 2 Marked stacks mean 1.2 × 1.5 = 1.8× incoming damage before Block.
- **Uncapped batteries and sustain need source tuning.** Retriggers scale Charged, Regeneration, and Spikes quickly. Each additional source should be tested with Echo, Prelude, Seams, Chatoyance, and Encore, not only a normal single firing.
- **Avoid opaque expiry.** Tooltips distinguish stacks, duration, charges, and one-use Block retention. New ordinary buffs/debuffs clear at combat settlement.

## Possible future additions

These remain suggestions; none is implemented by this change.

| Proposal | Starting rule | Comparison / reason to keep it |
| --- | --- | --- |
| **Buffer** | One charge prevents the next direct hit that would remove HP after Block. Poison and HP costs bypass it. | Spire Buffer; insurance against large Warden hits that small hits can spend first. |
| **Splintered** | Before the target's next N damage-dealing abilities, it loses 2 HP and consumes a stack. | Action-triggered damage with a distinct timing from Poison; Stun delays its payoff. |
| **Frail** | Generates 25% less Block for a stated duration; existing Block is unchanged. | Spire Frail; pressures defense without disabling dice or gems. |
| **Dissonance** | Disables Harmony's extra Resonance for the next rail while preserving ordinary firing gains. | Balatro Boss Blind-style pressure on monochrome builds. |
| **Attuned** | Mixed-color consecutive firings gain bonus Resonance, once per socket. | An alternative to Harmony, inspired by Balatro's composition rewards. |
| **Overdraw** | A planning-time extra reroll now costs a reroll next turn. Debt cannot be cleansed or blocked by Ward. | Present power with a future cost; needs a planning-time source. |
| **Prospector's Streak** | Successful use of a chosen pattern across victorious fights builds a capped pyrite bonus. | Balatro Green Joker/Ride the Bus-style conditional growth, attached to run economy. |

**Weak is no longer proposed separately:** the revised Curse already supplies its damage-reduction role. Copying and retriggering are already supplied by Doublet, Echo, Prelude, Seams, Chatoyance, Twinning Wisp, and Encore; expanding their interactions is more useful than another unconditional replay effect.

## Audit notes and current discrepancies

Remaining findings from the original inventory, plus implementation notes for the new rules:

1. **Fingerprint appears unimplemented.** `copy_previous_inclusion` is declared and used by content, but no application path handles it. It should not be counted as working copying support.
2. **Reward text still overpromises.** Hot Streak affects drop chance and generation luck. Prospect and the Sparkle tooltip now describe the actual luck bonus (a tenth of a point per stack), full consumption on the next find, and the 100-stack cap; they no longer promise a guaranteed grade increase.
3. **Locked faces are turn-local in practice.** The dice header says “rest of the fight,” but each new turn creates a fresh hand.
4. **Old Resonance/Capstone prose is stale.** Current fizzles preserve Resonance, and character Birthstones replaced the old automatic Capstone carat cash-out.
5. **Resolve has been replaced.** Combo Breaker now clears accumulated Stun after three missed actions, on all enemies. Bind still has independent suppression rules.
6. **Cleanse removes stacks, not whole afflictions.** High Poison can consume all of a cleanse before it reaches Stun or Curse. Renewal states its actual cleanse count; Flawless now grants Ward.
7. **Temporary rank gains now have a chip.** It lists per-gem Carat, Cut and Clarity bonuses. Prelude’s pending repeats still lack a dedicated chip.
8. **Some code paths have no live source.** `raise_high`, `flip_high`, the `first_gem_cut_step` and `heal_on_fizzle` passives, and the enemy `regrow` trait are implemented hooks unused by the current content pack. Regrow heals 3 at turn end if a creature is given that trait; it is separate from the newly implemented stack-based Regeneration.

## Sources

- [Current content pack](content/deep_cut.json): 66 skills, 31 inclusions, 6 characters, 24 Grubstakes, 11 creatures, and 19 oddities.
- [Battle simulation](sim/battle.gd): application, stacking, damage, rail order, status ticks, and cleanup.
- [Creature simulation](sim/creatures.gd): dice tiers, Dread, phases, and damage bonuses.
- [Stone evaluation](sim/stone.gd) and [rule vocabulary](sim/rules.gd): inclusion effects, magnitude, Clarity, and proc scaling.
- [Dice](sim/dice.gd), [hands](sim/hand.gd), and [patterns](sim/patterns.gd): patterns, etched faces, materials, and trigger behavior.
- [Descent](sim/descent.gd), [Grubstakes](sim/boons.gd), [oddities](sim/oddities.gd), and [generation](sim/forge.gd): run persistence and reward behavior.
- [Effect chips](view/battle/effect_chips.gd): current displayed names and tooltips; simulation behavior takes precedence where they differ.
- [Gem scenarios](tests/test_gem_updates.gd): attack chains, Lifeline, spending/refunds, appraisal, temporary ranks and run persistence.
- [Status regression suite](tests/test_statuses.gd): stacking, expiry, immunity, damage arithmetic, Charged forecasts, retaliation, and guest patches.
