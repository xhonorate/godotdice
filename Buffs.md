# Buffs, debuffs, and suggested additions

Updated September 24, 2026 after implementing the status changes and gem/enemy integrations. **Existing** means supported by the current simulation. Live sources are listed below; future alternatives remain clearly marked. Ability numbers still need playtesting.

The game already has a strong **Balatro-style combo engine**: copying, retriggers, multipliers, hand manipulation, and escalating gem strength. The new statuses add **Slay the Spire-style defensive planning**, softer enemy control, and effects that connect one turn to the next.

**Implemented:** stacking Dread, enemy Clouded, Combo Breaker, Ward, Retain, stack-based Curse, Charged Battery, Marked, Regeneration, Spikes, and Dulled. Current Curse/Dread gems use the new rules, and all Wardens—including the Foreman—start each fight with **1 Ward**. The revised gem sources and eight enemy integrations below are live. The pack contains **66 skill gems**. Lifeline, permanent run upgrades, temporary gem ranks, paid Gold effects and the approved additions are also live; see [Todo.md](Todo.md) for the complete catalogue.

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

**Late enemy applications:** a new player Curse or Dulled applied after the rails survives the immediate turn-end tick. It begins losing one stack at the following turn end; reapplying an existing stack does not postpone normal decay.

### Helpful combat effects and rail modifiers

| Effect | What it currently does | Duration / stacking | Current sources |
| --- | --- | --- | --- |
| **Block** | Absorbs hit damage before HP. Does not stop Poison or direct HP costs. | Adds. At the player turn start / enemy-side action start, Retain preserves up to its amount and all other Block clears. | Blue gems, Flawless lines, inclusions, Birthstones, Vesper, and enemy defensive moves. |
| **Resonance** | Builds as gems fire; powers Birthstones, gem triggers, and character passives. Normal base gain is 1 per firing. | Starts each turn at the consumed Charged amount, otherwise zero. Replays keep building it. **A fizzle does not erase Resonance.** | Every firing gem; Prism and inclusions add more; Charged Battery seeds the next turn. |
| **Harmony** | A gem that fires after another firing gem with a shared color adds 1 extra Resonance. | Evaluated on each firing. A fizzle breaks the chain of consecutive firings. | Rail order, Zoning, Alexandrite, and opals' color behavior. |
| **Amplified** | Multiplies the next evaluated gem's magnitude, affecting scaled amounts and whole-number effect proc counts. | Multipliers multiply. Consumed by the next eligible gem evaluation even if it fizzles; buried/clouded sockets return before consuming it. | Winning Double Down; Stake adds +50%, or +75% Flawless, after paying its Pyrite price. |
| **Sharpened / next Cut bonus** | Judges the next evaluated gem at additional Cut steps. | Steps add; consumed on evaluation, including a fizzle. Does not permanently recut the stone. | Feather inclusion. Facet now grants fight-long Cut instead. |
| **Extra rerolls next turn** | Adds rerolls to the next planning phase. | Grants add; transferred to the allowance and consumed at turn start. | Cascade. The Drill can still set available rerolls to zero. |
| **Carat growth** | Raises affected gems’ effective carats for the rest of the fight. | Adds on each activation; persists across turns, ends with the fight. | Fire Opal; Enrich raises every other gem by 1 (2 Flawless). |
| **Cut growth** | Raises every socketed gem's effective Cut for the rest of the fight. | Adds on each activation; effect ladders stop improving at their highest rung. | Fire Opal’s Flawless line; Facet raises adjacent gems by 1 (all gems Flawless). |
| **Repeat next** | Grants extra firings to the next gem, or the Birthstone when Prelude is last. | Pending amounts add; consumed by the next eligible resolution. A gem still has to fire to use the extra firings. | Prelude. |
| **Repeat previous** | Re-evaluates and fires the previous gem at 50% of its scaled effect amounts; Flawless Echo uses 100%. | Immediate queued repeat. Whole-number effects are not simply halved. | Echo. |
| **Color replay** | Repeats previously fired gems of a selected color in rail order. | Immediate; eligible repeats generate Resonance again. | Red, Blue, Green, Violet, Gold, and White Seam opals. |
| **Fizzle recovery** | Forces earlier fizzled gems to try firing even when their hand trigger was unmet. | Immediate; limited by Matrix's reach. Does not remove burial, fog, or Fracture's veto. | Matrix. |
| **Whole-rail replay** | Replays gems that fired, then eligible Birthstone work, continuing to build Resonance. | Immediate; Encore cannot recursively replay itself. | Cadence's Encore. |
| **Skill copying** | Uses the next reachable non-opal gem's skill with the copying stone's own carats, Cut, Clarity, and inclusions. | While arranged that way; reach depends on Cut. | Doublet. |
| **Face growth** | Raises the current face of each matched real die by 1; Flawless raises every face of those dice. Also updates the current roll. | Lasts this run; physical faces cap at 100. Phantom dice excluded. Stored collection unchanged. | Glimmer, matching dice below 7/6/5/4/3 by Cut. |
| **Match dice** | Changes eligible dice to join the best matching set. | Current hand only. | Mirror (the former Polish matching effect). |
| **Flip low dice** | Replaces a low value with `top + 1 − value`. | Current hand only. Useful depends on the build. | No current gem source; legacy simulation hook. |
| **Phantom dice** | Adds copies of the highest eligible die for later gems to read. | Current hand only; does not add permanent dice to the bowl. | Refract. |
| **Combo Breaker** | After the third consecutive action lost to Stun, an enemy clears every remaining Stun stack and rejects new Stun through its next turn. Rejections do not spend Ward. | Resets the stun streak. Any ordinary action also breaks the streak. Protects against Stun, not Bind or Clouded. **Replaces Resolve.** | Automatic on every enemy, including Wardens. |
| **Ward** | Blocks one harmful effect application per charge: Poison, Stun, Curse, Dread, dice theft/suppression, Clouded, Marked, Dulled, max HP loss, or a creature's burial/fog application. An application can contain several stacks. | Adds up to **99**, persists for the fight, and consumes one charge when it blocks. Existing immunity takes precedence and does not waste Ward. Does not block hits, HP costs, Block stripping, or the Drill's reroll rule. | **All Wardens, including the Foreman, start with 1**. Flawless Aegis grants 1 per ally; Flawless Renewal and Gilded Armor grant 1 to self; Foreman’s Shore Up replenishes 1 on a 12. |
| **Retain** | Preserves up to N unspent Block when that unit's Block would reset. Does not generate Block. | Grants add, retaining the originally proposed **20-point cap**. Consumed at the next reset. Players reset at turn start; enemies at enemy-side action start. | Flawless Bulwark grants half its gained Block; Mortar grants 10/15/20/25/30% of current Block (+10 percentage points Flawless); Flawless Bastion grants 4 per ally; Quartz Golem’s Harden grants 3. |
| **Charged Battery** | At the next player turn start, consumes all Charged stacks and sets starting Resonance to that amount. A count-up animation and pulse show the transfer; allies get a floating notification. Forecasts and rail start preserve the charged starting value. | No cap. Applications add. Charge is spent at turn start even if Stun later prevents that rail from acting. It does not carry forward a second time. | Flawless Prism grants 2; Flawless Bloom grants 1 per odd die to each ally. |
| **Regeneration** | Heals HP equal to stacks at shared turn end, **after Poison**, then loses 1 stack. Cannot exceed max HP or revive a unit killed by Poison. | No cap. Applications add; loses 1 even if already at full HP. Clears after combat. | Flawless Mend grants 2; Silt Slime’s Reknit grants 2 on a maximum face. |
| **Spikes** | Retaliates for N hit damage once per attacking gem firing/Birthstone/ability, including blocked hits. A multi-hit ability triggers it once per defender. Retaliation can be blocked and modified by Curse and enemy Enrage. | No cap. Applications add; expires at the owner's next Block reset. Retaliation cannot trigger Spikes/reflection recursively or consume Marked. A party-wide triggering hit finishes hitting everyone before combat settles. | Flawless Anchor grants 2; Glass Wyrm’s Coil grants 2. Former proposal name: Bristles. |
| **Lifeline** | Before lethal damage downs the bearer, consumes every stack and restores that much HP, up to maximum HP. Works against direct hits, Poison and retaliation. Flawless applications also store revival Block. | No cap or decay; lasts this fight. Reapplications add. Cannot rescue an ally already downed before application. Other statuses remain after rescue. | Lifeline grants matched value to each living ally. |
| **Clarity growth** | Raises affected gems’ effective Clarity, including its Resonance, magnitude and Flawless line. Preserves existing inclusions and stored stone values. | Adds for this fight, capped at Flawless. | Polish grants adjacent gems +1; Flawless affects all gems. |
| **Maximum HP growth** | Raises current and maximum HP by 1. | Each Flawless firing; lasts this run without changing the stored collection. | Thrive, requiring a highest roll of 12/11/10/9/8. |
| **Larger enemy dice** | Increases enemy die size tiers, up to d100; affects unrolled dice and later turns. | Stacks for the fight. Dread temporarily subtracts one tier from the resulting sizes. | Foreman's later-phase Reinforce. |

Gem amounts above are subject to the four C's. Larger magnitude directly scales damage, Block, healing, pyrite, Poison, Block removal, Retain, Regeneration, Spikes, and Lifeline. Exact result percentages and explicitly flat upgrades do not receive another multiplier. Most other gem effects gain whole-number applications, with a chance of an additional application from fractional magnitude. Consequently “one Stun” or “one reroll” in base content can become several on a heavy stone.

### Recovery and removal tools

These are immediate actions, rather than buffs with a duration, but they define the available counterplay.

| Tool | Current behavior | Sources |
| --- | --- | --- |
| **Heal** | Restores HP up to maximum; cannot revive. Regeneration provides delayed healing using the same HP limits. | Mend, Graft, Bloom, Renewal, Thrive, some Flawless lines, Grain, passives, rest, Field Medic. |
| **Cleanse** | Removes individual stacks in this order: **Poison → Stun → Curse → Marked → Dulled → enemy Clouded → Dread**. Never removes beneficial statuses. Does not remove existing player socket restrictions or dice theft. | Renewal; Flawless Shelter; Ardor’s Phalanx. |
| **Revive (legacy hook)** | Restores a downed ally, clearing statuses and delaying its action until next turn. No current gem uses it; Lifeline instead prevents a lethal downing with a stored buff. | Simulation hook only. |
| **Remove Block** | Immediately subtracts Block; does not prevent future Block gain. | Shatter; Vein Wraith's Wail and Mirror Regent's Refraction. |
| **Consume Poison** | Consumes all target Poison before dealing 4 base damage per stack. Flawless applies half the consumed stacks, rounded down, to each adjacent enemy. Spread is separately Ward-blockable. | Detonate. |
| **Poison conversion** | Heals the weakest ally for 20/30/40/50/60% of all living enemy Poison without consuming it; Flawless heals all allies. | Siphon. |
| **Accelerate Poison** | Immediately ticks existing enemy Poison, including its normal one-stack decay and Rue's healing trigger. | Rue's Draught and Dregs. |

## Existing creature traits and encounter modifiers

These are intrinsic rules of a creature, not cleansable statuses. Several produce effects already listed above.

| Trait | Creature | Current behavior |
| --- | --- | --- |
| **Latcher** | Cave Tick | Its Latch move applies Dice taken. Despite the internal name `steal_high_die`, it does not search for the highest die. |
| **Splits** | Silt Slime | A surviving hit that removes at least 40% of its maximum HP splits its remaining HP between it and a new slime, while there are fewer than six enemy entries. The new slime starts without ordinary statuses. |
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

Glimmer’s physical die-face upgrades and Thrive’s maximum HP gains persist for the current run. Appraise reveals raw bag stones and their inclusions during combat; it deals their combined sale value once. Wager and Stake spend available bag Pyrite plus combat earnings; each replay requires fresh payment. Prices/refunds remain exact through elite/warden settlement. On defeat, unbanked earnings and refund profit are lost, while net spending still reduces the bag balance to a minimum of zero.

| Effect | Current behavior | Duration / source |
| --- | --- | --- |
| **Windfall / Hot Streak** | Accumulates reward quality bonus. For ordinary/elite fight drops, every point adds 0.5 percentage points to drop chance; every 10 points adds 1 generation-luck bonus. | That fight's settlement; Windfall and Florin's Hot Streak. Not a guaranteed grade increase. |
| **Sparkle** | **All stored Sparkle is consumed on the next stone find**, adding **+1 generation luck per stack** (even below 5). Applies to the descent’s stone-find sources: battle drops, Birthstone rewards, veins/vugs, and motherlodes. Only the first stone of a multi-stone find spends the stored amount. | **Maximum 100**; applications add up to the cap and carry between fights. Prospect supplies it. Not a guaranteed grade increase; shop/hoard offers and separately generated oddity stones retain their existing generation rules. |
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
| **Bust** | Loses Resonance pyrite when Florin's Birthstone resolves with no crowns. | Immediate combat earnings penalty. Final fight payout is floored at zero. |

Other Grubstakes—Staked, Well Staked, A Raw Stone, Pick of Three, A Precious Stone, Crack a Geode, Roll for It, and Sight Unseen—give immediate currency or items rather than an ongoing buff. Royal Flush similarly queues a bonus stone reward. Oddities and workshops also alter items through recutting, annealing, fusion, inclusions, face changes, and resizing; their lasting combat effects are covered by the item modifiers below. Mining HP costs and purchases are costs, not additional status types.

## Existing character passives

| Character | Passive | Effect |
| --- | --- | --- |
| Ardor | **Second Wind** | Heals 3 per unused reroll when an active rail begins. |
| Vesper | **Riposte** | Gains Block equal to current Resonance for each positive-damage hit landed, including a hit absorbed by enemy Block. |
| Cadence | **Study** | +1 reroll every turn. |
| Rue | **Leech** | Heals current Resonance whenever Poison damages an enemy. |
| Puck | **Sleight** | One free flip of a plain die face per turn. |
| Florin | **Loaded** | A plain die face landing on 1 gets one immediate free retry on its initial roll or a selected reroll; does not chain indefinitely. |

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

### Special die faces and engravings

| Modifier | Effect / tradeoff |
| --- | --- |
| **Wild face** | Substitutes for values in supported patterns; contributes its die's top to totals. |
| **Gem face** | Bypasses hand-trigger requirements throughout the rail. Does not erase independent socket restrictions or Fracture. |
| **Exploding face** | Rolls an additional face and adds its value; chains for up to three additional rolls. |
| **Locked face** | Cannot be selected for reroll while that result remains in the current hand. New turns roll a fresh hand. |
| **Mirror face** | Copies the highest non-mirror value; recalculates when mirror resolution runs. |
| **Blank face** | Contributes no numerical value and is excluded from value/set analysis; the hand still records whether the die was held or rerolled. |
| **Set engraving** | Counts as held for patterns even when rerolled. |
| **Twin engraving** | Counts twice in set patterns. |
| **Keen engraving** | +1 to valued faces, within the value cap. |
| **Steady engraving** | Valued faces cannot show less than 2. Can hurt builds that want 1s. |

Custom face distributions and different die sizes also change a build's odds; they are item configurations rather than separate statuses.

## Implemented integrations

These assignments are implemented in `content/deep_cut.json`. Amounts are base values before gem magnitude/proc scaling. Mist and Etch join the ordinary Violet pool; neither requires a new unlock system.

### Gems and Flawless bonuses

| Gem | Implemented change | Gameplay / ordering |
| --- | --- | --- |
| **Mist — Violet / Uncommon** | Pair valued ≥5/4/3/2/1 by Cut; apply **1 Clouded**. Flawless applies to **all enemies**. | Disables one random ability slot; repeated firings extend that slot's duration. Ward can intercept applications. |
| **Aegis — Flawless** | **1 Ward per ally** replaces the cleanse rider. Base party Block remains. | Proactive party protection; heavy stones can grant multiple charges, up to 99. |
| **Bastion — Flawless** | **4 Retain per ally** replaces the cleanse rider. Base party Block remains. | Preserves a reserve of unspent Block for Thrive or the next enemy phase; Retain caps at 20. |
| **Prism — Flawless** | **2 Charged** replaces the extra immediate Resonance. Base Resonance remains. | Repeated firings build a larger next-turn battery; its transfer is animated at turn start. |
| **Mend — Flawless** | **2 Regeneration** replaces the Block rider. Base healing remains. | Adds delayed recovery; Poison ticks before Regeneration. |
| **Anchor — Flawless** | **2 Spikes** replaces the extra 1 Block per held die. Base **2 Block per held die** remains. | Punishes each attacking ability until the next player Block reset. |
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
2. **Reward text still overpromises.** Windfall/Hot Streak affect drop chance and generation luck. Prospect and the Sparkle tooltip now describe the actual luck bonus, full consumption on the next find, and 100-stack cap; they no longer promise a guaranteed grade increase.
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
- [Dice](sim/dice.gd), [hands](sim/hand.gd), and [patterns](sim/patterns.gd): faces, engravings, and trigger behavior.
- [Descent](sim/descent.gd), [Grubstakes](sim/boons.gd), [oddities](sim/oddities.gd), and [generation](sim/forge.gd): run persistence and reward behavior.
- [Effect chips](view/battle/effect_chips.gd): current displayed names and tooltips; simulation behavior takes precedence where they differ.
- [Gem scenarios](tests/test_gem_updates.gd): attack chains, Lifeline, spending/refunds, appraisal, temporary ranks and run persistence.
- [Status regression suite](tests/test_statuses.gd): stacking, expiry, immunity, damage arithmetic, Charged forecasts, retaliation, and guest patches.
