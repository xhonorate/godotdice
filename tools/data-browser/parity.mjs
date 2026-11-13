// Holds the balance browser's fight (js/sim/fight.js) to the game's own rail. Writes seeded
// fixtures, has Godot play them with the real DeepBattle (tools/balance_parity.gd), plays the
// same fixtures here, and compares the state after every rail field by field.
//
//   node tools/data-browser/parity.mjs [--count 400] [--seed 1] [--keep] [--etched] [--first]
//
// --etched etches Exploding and Doubled faces onto some fixtures' dice and writes each
// exploding face's throws after it (`chain`, face indices), so shown faces, `base` and the
// value/below triggers that read them are held to the game too. tools/balance_parity.gd
// reads the same `etch` and `chain` (see buildRoll below).
//
// After those come the "full" fixtures: every skill with a Flawless line, played Flawless over
// real turns (see flawlessFixtures). They draw from a copy of Godot's own generator (makePcg), so
// procs, coins and thrown dice agree, and they have a stream of their own, so the plain fixtures
// stay as they were.
//
// Every fixture names the Birthstone its player wears (`worn`: a variant's key, or "" for the
// delver's first), drawn from a stream of its own so each of a delver's three stones gets a third
// of that delver's fixtures and the gems and hands stay as they were. Last come the fixtures
// aimed at the twelve variants (see variantFixtures): hands chosen to light each tier, played
// dry, live and over real turns. A variant may pick a creature at random or throw the dice again,
// so every fixture is played here on the copy of Godot's generator.
//
// Exits 1 on any difference. Files go to build/parity/ (kept with --keep).

import { spawn, execFileSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as C from './js/sim/content.js';
import * as Dice from './js/sim/dice.js';
import * as Stone from './js/sim/stone.js';
import * as Fight from './js/sim/fight.js';
import * as Rules from './js/sim/rules.js';
import { makeRng } from './js/sim/rng.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const args = process.argv.slice(2);
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };
const COUNT = Number(option('count', 400));
const SEED = Number(option('seed', 1));
const ETCHED = args.includes('--etched');
// --first: every fixture in its delver's first Birthstone and none aimed at the variants, which
// is the fixtures as they were before there were variants.
const FIRST_ONLY = args.includes('--first');
const ETCH_KINDS = ['exploding', 'doubled'];
const OUT = path.join(ROOT, 'build', 'parity');

C.setPack(JSON.parse(await readFile(path.join(ROOT, 'content', 'deep_cut.json'), 'utf8')));

// --- fixtures --------------------------------------------------------------------------------

// Live fixtures queue replays for real, so they keep to stones that never roll for a proc:
// one carat, no Flawless, nothing that changes a stone's weight mid-rail, no coin.
const LIVE_SKIP_SKILLS = ['ENRICH', 'FIRE_OPAL', 'STAKE', 'DOUBLE_DOWN', 'POLISH',
	// Bloodletting changes the next gem's weight, as Stake does; the rest throw dice of their
	// own (the two RNGs are not the same) or wait for a kill. A Hex draws its debuff from the
	// fight's random numbers (dry fixtures keep it: a forecast draws none, in both).
	'BLOODLETTING', 'TUMBLE', 'CONTRA_LUZ', 'RATTLE', 'PLACER', 'REFRACT', 'HEX'];
const LIVE_SKIP_INCLUSIONS = ['FRACTURE', 'BRUISE', 'KNOT', 'CAVITY', 'CHIP', 'HALO', 'VOID'];

// Which of a delver's Birthstones a fixture wears, from a stream apart from the one that picks
// its gems and hands: the first stone or either variant, each a third of the time.
function dresser(seed) {
	const rng = makeRng(seed);
	return (character) => { const keys = C.birthstoneKeys(character); const at = rng.randiRange(0, keys.length - 1); return FIRST_ONLY ? '' : keys[at]; };
}

function fixtures(count, seed) {
	const rng = makeRng(seed * 7919 + 11);
	const dress = dresser(seed * 1299709 + 23);
	const pick = (list) => list[rng.randiRange(0, list.length - 1)];
	const characters = C.keys('characters');
	const skills = C.keys('skills');
	const inclusions = C.keys('inclusions').filter((k) => k !== 'VOID');
	const out = [];
	for (let n = 0; n < count; n++) {
		const live = n % 2 === 1;
		const character = pick(characters);
		const def = C.character(character);
		const sockets = def.sockets.length;
		const filled = rng.randiRange(1, sockets);
		const rail = Array.from({ length: sockets }, () => null);
		for (let i = 0; i < filled; i++) {
			const socket = rng.randf() < 0.85 ? i : rng.randiRange(0, sockets - 1);
			const pool = live ? skills.filter((k) => !LIVE_SKIP_SKILLS.includes(k)) : skills;
			const skill = pick(pool);
			const clarity = live ? pick([3, 4]) : rng.randiRange(0, 5);
			let slots = live ? (rng.randf() < 0.4 ? 1 : 0) : Stone.inclusionSlots(clarity);
			const allowed = live ? inclusions.filter((k) => !LIVE_SKIP_INCLUSIONS.includes(k)) : inclusions;
			const chosen = [];
			while (slots-- > 0) { const k = pick(allowed); if (!chosen.includes(k)) chosen.push(k); }
			rail[socket] = { skill, carat: live ? 1 : rng.randiRange(1, 24), cut: rng.randiRange(0, 4), clarity, inclusions: chosen, id: `g${socket}` };
		}
		const dice = def.dice.map((ref, i) => Dice.dieFrom(ref, `p${i}`));
		// Only with --etched, and from a stream of its own, so the plain fixtures stay as they were.
		const etch = [];
		const extra = ETCHED ? makeRng(seed * 104729 + n) : null;
		if (extra && extra.randf() < 0.6) {
			for (let i = 0; i < dice.length; i++) {
				if (extra.randf() < 0.5) continue;
				const at = { die: i, face: extra.randiRange(0, dice[i].faces.length - 1), kind: ETCH_KINDS[extra.randiRange(0, ETCH_KINDS.length - 1)] };
				if (Dice.etch(dice[i], at.face, at.kind)) etch.push(at);
			}
		}
		const runs = Array.from({ length: rng.randiRange(1, 3) }, () => ({ hand: dice.map((die) => {
			const rerolls = rng.randf() < 0.4 ? 1 : 0;
			const spec = { face: rng.randiRange(0, die.faces.length - 1), rerolls, held: rerolls === 0 ? rng.randf() < 0.5 : true };
			if (extra && (die.faces[spec.face].kind || 'plain') === 'exploding') {
				spec.chain = [];
				while (spec.chain.length < Dice.MAX_EXPLOSIONS) {
					const again = extra.randiRange(0, die.faces.length - 1);
					spec.chain.push(again);
					if ((die.faces[again].kind || 'plain') !== 'exploding') break;
				}
			}
			return spec;
		}) }));
		const enemy = () => ({ block: rng.randf() < 0.5 ? 0 : rng.randiRange(1, 10), statuses: { poison: rng.randiRange(0, 6), curse: rng.randiRange(0, 2), marked: rng.randiRange(0, 1) } });
		out.push({ id: n, mode: live ? 'live' : 'dry', seed: seed * 1000 + n, character, worn: dress(character), pyrite: rng.randiRange(0, 80), depth: 3, rail, runs, ...(etch.length ? { etch } : {}),
			enemies: [enemy(), enemy()], unit: { hp: rng.randiRange(20, Number(def.hp)), block: rng.randiRange(0, 10), block_lost: rng.randiRange(0, 8), statuses: {},
				initial_resonance: rng.randiRange(0, 5), rerolls: rng.randiRange(0, 2) } });
	}
	return out;
}

// How many fixtures each Flawless line gets, half of them on hands that turn its `when` on.
const FLAWLESS_VARIANTS = 8;
const FLAWLESS_TURNS = 4;

// What a Flawless line needs around it to have anything to do, by variant: gems before and after
// it on the rail, each a list to pick from; `dark` gems stay dark as the hand is chosen, and a
// `quiet` stone does too; `absorbed` is what a Black Opal took in; `frail`, a creature near death
// for the lines that read a kill; `foes`, what its first creature carries; `breaker`, a blow that
// takes all the Block there is; `clarity` for a stone that is not Flawless itself; `light`, few
// carats; `character` and `cut` where only those dice and that Cut can answer its trigger;
// `resonance` to start the rail from.
const darkGems = () => anyGem().filter((k) => ['triple', 'quad', 'full_house', 'straight', 'two_pair'].includes(String((C.skill(k).trigger || {}).kind)));
const ofColor = (color) => C.keys('skills').filter((k) => C.skill(k).color === color && !C.skill(k).altar);
const anyGem = () => C.keys('skills').filter((k) => C.skill(k).color !== C.OPAL && !C.skill(k).altar);
const guards = () => anyGem().filter((k) => (C.skill(k).effects || []).some((e) => e.kind === 'block'));
const hitters = () => anyGem().filter((k) => (C.skill(k).effects || []).some((e) => e.kind === 'damage'));
const FLAWLESS_SCENES = {
	SEAM_RED: () => ({ before: [ofColor('RED'), ofColor('RED')] }), SEAM_BLUE: () => ({ before: [ofColor('BLUE'), ofColor('BLUE')] }),
	SEAM_GREEN: () => ({ before: [ofColor('GREEN'), ofColor('GREEN')] }), SEAM_VIOLET: () => ({ before: [ofColor('VIOLET'), ofColor('VIOLET')] }),
	SEAM_GOLD: () => ({ before: [ofColor('GOLD'), ofColor('GOLD')] }), SEAM_WHITE: () => ({ before: [ofColor('WHITE'), ofColor('WHITE')] }),
	RAINBOW_SEAM: () => ({ before: [anyGem(), anyGem()] }),
	TAILINGS: () => ({ before: [darkGems(), darkGems(), darkGems(), darkGems(), darkGems()], dark: true }),
	MATRIX: () => ({ before: [darkGems(), darkGems(), darkGems(), darkGems()], dark: true, resonance: 12 }),
	QUINTESSENCE: () => ({ character: 'FLORIN' }), JACKPOT: () => ({ character: 'FLORIN' }), LUCKY_SEVEN: () => ({ character: 'CADENCE' }),
	ECHO: (variant) => ({ before: [hitters()], after: [anyGem()], clarity: variant % 2 ? 4 : 5 }),
	DOUBLET: () => ({ before: [anyGem()], after: [anyGem()] }),
	GEMINI: (variant) => { const color = ['RED', 'BLUE', 'GREEN', 'VIOLET'][variant]; return { before: [ofColor(color)], after: [variant === 3 ? ofColor('GOLD') : ofColor(color)] }; },
	CERTAINTY: () => ({ after: [anyGem(), anyGem(), anyGem()] }),
	POLISH: () => ({ before: [anyGem()], after: [anyGem()], neighbours: { clarity: 5 } }),
	FACET: () => ({ before: [anyGem()], after: [anyGem()], neighbours: { cut: 4 } }),
	ENRICH: (variant) => ({ before: variant % 2 ? [hitters(), ['ECHO']] : [anyGem()], after: [anyGem()] }),
	FIRE_OPAL: () => ({ before: [anyGem()], after: [anyGem(), anyGem()] }),
	// Odd variants: not Flawless until the Polish beside it has fired.
	LODESTONE: (variant) => (variant % 2 ? { before: [['POLISH']], after: [anyGem(), anyGem()], charged: true, clarity: 4, quiet: true, statuses: { charged: 2 } } : { after: [anyGem(), anyGem()], charged: true }),
	SPALL: () => ({ light: true }), SPECTRUM: () => ({ before: [ofColor('RED'), ofColor('RED')] }),
	FERMENT: () => ({ foes: { statuses: { curse: 9, burn: 2, dulled: 1, festering: 1, scorched: 1 }, dread_turns: 2 } }),
	STAKE: () => ({ after: [hitters()] }), DOUBLE_DOWN: () => ({ after: [hitters()] }), BLOODLETTING: () => ({ after: [hitters()] }),
	ARSENIC: () => ({ after: [hitters()], statuses: { spikes: 3 } }),
	CONFLUENCE: () => ({ frail: true }), HONE: () => ({ frail: true }), OVERKILL: () => ({ frail: true }),
	// Odd variants: its first firing is amplified, so the next is the smaller.
	CONTAGION: (variant) => ({ before: variant % 2 ? [['BLOODLETTING']] : [], after: [anyGem(), anyGem()] }), REBOUND: () => ({ after: [guards()] }), TEMPER: () => ({ after: [['GUARD', 'HARDENING'], ['ANCHOR', 'TEMPO', 'BULWARK']], statuses: { strength: 2 }, character: 'CADENCE', cut: 4 }),
	MORTAR: () => ({ guarded: true }), GILDED_ARMOR: () => ({ guarded: true }),
	// Block broken by a blow, a creature stripping it, and a burn with the gem itself left dark.
	HARDENING: (variant) => (variant === 1 ? { quiet: true, dark: true, statuses: { burn: 15 }, lowBlock: true } : { guarded: true, breaker: variant === 2 ? 'strip' : 'blow' }),
	LICHEN: () => ({ statuses: { regeneration: 3 } }), HEMLOCK: () => ({ statuses: { poison: 2 } }), SHELTER: () => ({ statuses: { burn: 2 } }),
	BLACK_OPAL: () => ({ absorbed: [hitters(), guards()] }),
	RENEWAL: () => ({ full: true }), THIRST: () => ({ full: true }), SIPHON: () => ({ full: true }), SAP: () => ({ before: [ofColor('GREEN')], full: true }),
};

function flawlessFixtures(seed, firstId) {
	const rng = makeRng(seed * 15485863 + 5);
	const dress = dresser(seed * 2750159 + 29);
	const pick = (list) => list[rng.randiRange(0, list.length - 1)];
	const characters = C.keys('characters');
	const lines = C.keys('skills').filter((k) => Object.keys(C.skill(k).flawless || {}).length);
	const out = [];
	for (const skill of lines) {
		for (let variant = 0; variant < FLAWLESS_VARIANTS; variant++) {
			const scene = (FLAWLESS_SCENES[skill] || (() => ({})))(variant % 4);
			const character = scene.character || pick(characters);
			const def = C.character(character);
			const sockets = def.sockets.length;
			const before = scene.before || [];
			const after = scene.after || [];
			const at = Math.min(sockets - 1 - after.length, before.length + rng.randiRange(0, Math.max(0, sockets - 1 - after.length - before.length)));
			const rail = Array.from({ length: sockets }, () => null);
			const used = [skill];
			const lay = (socket, pool, extra = {}) => {
				const open = pool.filter((k) => !used.includes(k));
				if (!open.length) return;
				const key = pick(open);
				used.push(key);
				rail[socket] = { skill: key, carat: rng.randiRange(1, 24), cut: rng.randiRange(0, 4), clarity: pick([3, 4, 5]), inclusions: [], id: `g${socket}`, ...extra };
			};
			rail[at] = { skill, carat: rng.randiRange(1, scene.light ? 4 : 24), cut: scene.cut ?? rng.randiRange(0, 4), clarity: scene.clarity ?? 5, inclusions: [], id: `g${at}` };
			if (scene.absorbed) rail[at].absorbed = scene.absorbed.map((pool) => pick(pool));
			before.forEach((pool, index) => lay(at - before.length + index, pool, index === before.length - 1 ? scene.neighbours : {}));
			after.forEach((pool, index) => lay(at + 1 + index, pool, index === 0 ? scene.neighbours : {}));
			// A few gems more, here and there.
			for (let socket = 0; socket < sockets; socket++) if (!rail[socket] && !scene.dark && rng.randf() < 0.3) lay(socket, anyGem());
			const dice = def.dice.map((ref, i) => Dice.dieFrom(ref, `p${i}`));
			const pyrite = rng.randiRange(0, 300);
			const unit = { hp: scene.full || rng.randf() < 0.3 ? Number(def.hp) : rng.randiRange(20, Number(def.hp)), block: scene.guarded ? rng.randiRange(4, 30) : scene.lowBlock ? rng.randiRange(1, 5) : rng.randiRange(0, 10), block_lost: rng.randiRange(0, 8),
				statuses: { ...(scene.statuses || {}) }, initial_resonance: scene.resonance ?? (scene.charged ? rng.randiRange(1, 5) : rng.randiRange(0, 5)), rerolls: rng.randiRange(0, 2) };
			const enemy = () => ({ block: rng.randf() < 0.5 ? 0 : rng.randiRange(1, 10), statuses: { poison: rng.randiRange(0, 6), curse: rng.randiRange(0, 2), marked: rng.randiRange(0, 1) } });
			const enemies = [enemy(), enemy()];
			if (scene.frail || rng.randf() < 0.25) enemies[0].hp = rng.randiRange(1, 30);
			if (scene.foes) Object.assign(enemies[0], { dread_turns: scene.foes.dread_turns, statuses: { ...enemies[0].statuses, ...scene.foes.statuses } });
			// The first hand is chosen to give the line something to do.
			const hand = chooseHand(dice, rail[at], rail, unit, pyrite, { dark: Boolean(scene.dark), quiet: Boolean(scene.quiet), wantLine: variant % 2 === 0 }, rng);
			const blow = () => ({ foe: 1, amount: rng.randiRange(1, 8) });
			const breaker = { blow: { foe: 1, through_block: true }, strip: { foe: 1, kind: 'remove_block', amount: 0 } }[scene.breaker];
			const runs = Array.from({ length: FLAWLESS_TURNS }, (_, turn) => ({ ...(turn === 0 ? { hand } : {}), blows: scene.quiet ? [] : breaker ? [breaker] : [blow(), blow()] }));
			out.push({ id: firstId + out.length, mode: 'full', seed: seed * 1000 + firstId + out.length, character, worn: dress(character), pyrite, depth: 3, rail, runs, enemies, unit });
		}
	}
	return out;
}

// The fixtures aimed at the variant Birthstones: for each of the twelve, hands chosen to light
// every tier (the ones tests/test_birthstones.gd plays), written as the numbers each die shows.
// `rail` is the gems a stone needs around it (a Nocturne's dark gems, a Patchwork's colors), cut
// to fire or stay dark on those hands; `foes`, each creature's health (0: more than any blow
// takes), so a kill, a Trophy or a knife thrown again is there to be had; `unit`, what the player
// stands in. Each scene is played three ways: dry, live (a rail a hand), and over real turns (a
// turn a hand, the creatures hitting back, then a turn on whatever the dice throw).
const gem = (skill, cut = 4, carat = 1) => ({ skill, cut, carat });
const VARIANT_SCENES = [
	// Ardor (d6 d6 d6 d8 d8). Rampart: even dice; Ram wants Block to swing, Keep a Tempo's Block to hold.
	{ character: 'ARDOR', worn: 'RAMPART', hands: [[2, 4, 1, 3, 5], [2, 4, 6, 3, 5], [2, 4, 6, 2, 5], [2, 4, 6, 2, 8], [1, 3, 5, 1, 3]], unit: { block: 30 } },
	{ character: 'ARDOR', worn: 'RAMPART', hands: [[2, 4, 6, 2, 8], [1, 3, 5, 1, 3], [2, 4, 6, 3, 5]], rail: [gem('TEMPO')], unit: { block: 9, statuses: { spikes: 4 } } },
	// Renown: dice showing 6 or more; a creature a Lance can kill is a Trophy, and the Tourney finds the weakest.
	{ character: 'ARDOR', worn: 'RENOWN', hands: [[6, 1, 2, 3, 4], [6, 6, 6, 7, 1], [6, 6, 6, 7, 8], [1, 2, 3, 4, 5]], foes: [0, 50] },
	{ character: 'ARDOR', worn: 'RENOWN', hands: [[6, 1, 2, 3, 4], [6, 6, 6, 7, 1], [6, 6, 6, 7, 8]], foes: [5, 8, 0] },
	// Vesper (d4 d4 d4 d4 d12). Ill Omen: 1s.
	{ character: 'VESPER', worn: 'ILL_OMEN', hands: [[1, 2, 3, 4, 7], [1, 1, 1, 2, 7], [1, 1, 1, 1, 7], [1, 1, 1, 1, 1], [2, 2, 3, 4, 7]] },
	{ character: 'VESPER', worn: 'ILL_OMEN', hands: [[1, 1, 1, 1, 1], [1, 1, 1, 1, 7]], foes: [40, 0, 0] },
	// Fan of Knives: sets; three creatures, two of them a knife's worth of health, so knives are thrown again.
	{ character: 'VESPER', worn: 'FAN_OF_KNIVES', hands: [[3, 3, 1, 2, 9], [3, 3, 2, 2, 9], [3, 3, 3, 3, 9], [1, 2, 3, 4, 9]] },
	{ character: 'VESPER', worn: 'FAN_OF_KNIVES', hands: [[3, 3, 3, 2, 9], [3, 3, 2, 2, 9], [3, 3, 3, 3, 9]], foes: [5, 5, 0] },
	{ character: 'VESPER', worn: 'FAN_OF_KNIVES', hands: [[2, 2, 2, 2, 2], [4, 4, 1, 1, 12]], foes: [12, 0, 30, 0] },
	// Cadence (d4 d6 d8 d10 d12). Nocturne: low totals wake the gems that stayed dark.
	{ character: 'CADENCE', worn: 'NOCTURNE', hands: [[1, 2, 3, 4, 5], [1, 2, 3, 1, 4], [1, 1, 2, 2, 3], [2, 3, 4, 5, 6]], rail: [gem('HEARTWOOD'), gem('PETRIFY')] },
	{ character: 'CADENCE', worn: 'NOCTURNE', hands: [[1, 2, 3, 4, 5], [1, 1, 2, 2, 3], [1, 2, 3, 1, 4]], rail: [gem('STRIKE'), gem('PETRIFY'), gem('GUARD'), gem('HEARTWOOD')] },
	// Arpeggio: a scale.
	{ character: 'CADENCE', worn: 'ARPEGGIO', hands: [[2, 3, 5, 4, 11], [1, 2, 3, 4, 5], [4, 3, 2, 1, 2], [1, 5, 2, 9, 3], [4, 1, 2, 3, 12]] },
	{ character: 'CADENCE', worn: 'ARPEGGIO', hands: [[1, 2, 3, 4, 5], [2, 3, 5, 4, 11]], rail: [gem('PRISM'), gem('STRIKE')], foes: [20, 0] },
	// Rue (d4 d4 d6 d6 and the Phial, 1 1 2 2 3 3). Mithridate: straights.
	{ character: 'RUE', worn: 'MITHRIDATE', hands: [[1, 2, 3, 1, 1], [1, 2, 3, 4, 1], [2, 3, 4, 5, 1], [1, 1, 3, 3, 1], [2, 3, 4, 5, 1]] },
	{ character: 'RUE', worn: 'MITHRIDATE', hands: [[2, 3, 4, 5, 1], [2, 3, 4, 5, 1]], rail: [gem('STRIKE')], unit: { block: 0, initial_resonance: 23 } },
	// Bloodroot: 1s and sets; one of them with a single point of health, which a Tap takes.
	{ character: 'RUE', worn: 'BLOODROOT', hands: [[1, 1, 4, 3, 2], [1, 2, 4, 3, 2], [2, 2, 4, 3, 2], [2, 2, 2, 2, 3], [2, 2, 2, 2, 2]], unit: { hp: 64 } },
	{ character: 'RUE', worn: 'BLOODROOT', hands: [[3, 3, 3, 3, 2], [1, 1, 1, 3, 1], [2, 2, 2, 2, 2]], unit: { hp: 60 }, foes: [0, 0, 0] },
	{ character: 'RUE', worn: 'BLOODROOT', hands: [[1, 2, 3, 4, 2], [1, 1, 4, 3, 2]], unit: { hp: 1 } },
	// Puck (d6 d6 d8 d8 d10). Highs and Lows: crowns and 1s; `grown` are hands on the dice the Ovation grew.
	{ character: 'PUCK', worn: 'HIGHS_AND_LOWS', hands: [[6, 2, 3, 4, 5], [6, 1, 8, 3, 10], [2, 3, 1, 5, 1], [6, 1, 8, 1, 10]], grown: [[8, 1, 10, 1, 12], [7, 2, 9, 3, 11]] },
	{ character: 'PUCK', worn: 'HIGHS_AND_LOWS', hands: [[6, 1, 8, 1, 10]], grown: [[8, 8, 10, 10, 12], [1, 1, 1, 1, 1]], rail: [gem('STRIKE'), gem('GUARD')] },
	// A Glimmer raises a face for good every turn: the faces it raises after the Ovation stay raised when the fight files the dice back down.
	{ character: 'PUCK', worn: 'HIGHS_AND_LOWS', hands: [[6, 1, 8, 1, 10]], grown: [[2, 3, 4, 5, 6], [8, 1, 10, 1, 12]], rail: [gem('GLIMMER')] },
	// Patchwork: colors fired. Six gems that fire on a pair, one a color; three, four and all six of them.
	{ character: 'PUCK', worn: 'PATCHWORK', hands: [[2, 2, 3, 5, 7], [1, 2, 3, 5, 7]], rail: [gem('STRIKE'), gem('RIPOSTE'), gem('THIRST')] },
	{ character: 'PUCK', worn: 'PATCHWORK', hands: [[2, 2, 3, 5, 7], [4, 4, 3, 5, 7]], rail: [gem('STRIKE'), gem('RIPOSTE'), gem('THIRST'), gem('TITHE')], unit: { hp: 40 } },
	{ character: 'PUCK', worn: 'PATCHWORK', hands: [[2, 2, 3, 5, 7], [3, 3, 3, 5, 7]], rail: [gem('STRIKE'), gem('RIPOSTE'), gem('THIRST'), gem('MIASMA'), gem('TITHE'), gem('PRISM')], unit: { hp: 40 } },
	// Florin (five Gambler's d6: 1 2 3 4 5 7). One-Armed Bandit: sets by size, a prize a number.
	{ character: 'FLORIN', worn: 'ONE_ARMED_BANDIT', hands: [[5, 5, 5, 2, 2], [1, 1, 3, 4, 7], [3, 3, 4, 4, 7], [4, 4, 4, 4, 7], [7, 7, 7, 7, 7], [1, 2, 3, 4, 5]], unit: { hp: 30 } },
	{ character: 'FLORIN', worn: 'ONE_ARMED_BANDIT', hands: [[7, 7, 1, 2, 3], [2, 2, 2, 2, 2], [7, 7, 7, 5, 5]], foes: [25, 0] },
	// Blackjack: the total in a window, on a number, or over it.
	{ character: 'FLORIN', worn: 'BLACKJACK', hands: [[5, 4, 3, 7, 1], [5, 4, 3, 4, 1], [5, 5, 3, 7, 1], [7, 7, 5, 2, 1], [1, 2, 3, 4, 5]] },
	{ character: 'FLORIN', worn: 'BLACKJACK', hands: [[7, 7, 5, 2, 1], [7, 7, 7, 7, 7], [5, 5, 3, 7, 1]], unit: { hp: 12, initial_resonance: 9 } },
];

function variantFixtures(seed, firstId) {
	const rng = makeRng(seed * 32452843 + 7);
	const out = [];
	for (const scene of VARIANT_SCENES) {
		const def = C.character(scene.character);
		const dice = def.dice.map((ref, i) => Dice.dieFrom(ref, `p${i}`));
		const sockets = def.sockets.length;
		const rail = Array.from({ length: sockets }, () => null);
		(scene.rail || []).forEach((stone, socket) => { rail[socket] = { skill: stone.skill, carat: stone.carat, cut: stone.cut, clarity: 3, inclusions: [], id: `g${socket}` }; });
		// The face of each die that shows the number asked for. A `grown` hand is laid on the bowl
		// a size bigger, as a Standing Ovation leaves it; a forecast grows nothing, so the dry
		// fixture leaves those hands out.
		const bigger = dice.map((die) => { const copy = { ...die, faces: die.faces.map((f) => ({ ...f })) }; Dice.resize(copy, 1); return copy; });
		const hand = (values, bowl) => bowl.map((die, index) => {
			const face = die.faces.findIndex((f) => Dice.faceValue(f) === values[index]);
			if (face < 0) throw new Error(`${scene.worn}: die ${index} (${die.shape}) has no face showing ${values[index]}`);
			return { face, rerolls: 0, held: false };
		});
		const foes = scene.foes || [0, 0];
		const last = foes.length - 1;
		for (const mode of ['dry', 'live', 'full']) {
			const enemies = foes.map((hp) => ({ block: 0, statuses: {}, ...(hp > 0 ? { hp } : {}) }));
			const unit = { hp: Number(def.hp), block: 10, block_lost: 0, statuses: {}, initial_resonance: 10, rerolls: rng.randiRange(0, 2), ...(scene.unit || {}) };
			unit.statuses = { ...unit.statuses };
			const hands = scene.hands.map((values) => hand(values, dice)).concat(mode === 'dry' ? [] : (scene.grown || []).map((values) => hand(values, bigger)));
			const runs = hands.map((laid) => (mode === 'full' ? { hand: laid, blows: [{ foe: last, amount: rng.randiRange(2, 6) }] } : { hand: laid }));
			// A last turn on whatever the dice throw: the bowl a Standing Ovation grew, the Spikes that came down.
			if (mode === 'full') runs.push({ blows: [{ foe: last, amount: rng.randiRange(2, 6) }] });
			out.push({ id: firstId + out.length, mode, seed: seed * 1000 + firstId + out.length, character: scene.character, worn: scene.worn, pyrite: 40, depth: 3, rail, runs, enemies, unit, aimed: true });
		}
	}
	return out;
}

// A hand the stone fires on, with its `when` on if `wantLine`; for a rail that wants its gems
// dark, one that leaves as many of them dark as it can.
function chooseHand(dice, spec, rail, unit, pyrite, { dark, quiet, wantLine }, rng) {
	const context = { unit: { ore: pyrite, gold: 0, pyrite_delta: 0, hp: unit.hp, max_hp: unit.hp, block: unit.block, statuses: unit.statuses, rerolls: unit.rerolls }, resonance: 4, fizzles: 6 };
	const stones = rail.map((s) => (s ? Stone.make(s.skill, s.carat, s.cut, s.clarity, s.inclusions, s.id) : null));
	const stone = Stone.make(spec.skill, spec.carat, spec.cut, spec.clarity, spec.inclusions, spec.id);
	const line = Stone.skillOf(stone).flawless || {};
	let best = null, bestScore = -Infinity;
	// A rare hand (a Lucky Seven's three 7s, five of a kind) is worth a long look for.
	const wanted = wantLine && 'when' in line ? 150 : 100;
	for (let attempt = 0; attempt < 6000 && (attempt < 80 || bestScore < wanted); attempt++) {
		const hand = dice.map((die) => {
			const rerolls = rng.randf() < 0.4 ? 1 : 0;
			return { face: rng.randiRange(0, die.faces.length - 1), rerolls, held: rerolls === 0 ? rng.randf() < 0.5 : true };
		});
		const rolls = dice.map((die, index) => buildRoll(die, hand[index]));
		const ev = Stone.evaluate(stone, rolls, context);
		let score = ev.active === !quiet ? 100 : 0;
		if (ev.active && wantLine && 'when' in line) {
			const tc = { a: ev.analysis, trig: ev.trigger, unit: context.unit, resonance: 4, cut: ev.cut_step, carat: ev.carat, fizzles: 6 };
			if (Rules.amount(line.when, tc) !== 0) score += 50;
		}
		for (const other of stones) if (other && other.id !== stone.id && Stone.evaluate(other, rolls, context).active) score += dark ? -5 : 1;
		if (score > bestScore) { best = hand; bestScore = score; }
	}
	return best;
}

// Godot's RandomNumberGenerator (a PCG32, core/math/random_pcg): the "full" fixtures draw from
// this on both sides. `seed` as RandomPCG.seed sets it, with Godot's default stream.
function makePcg(seed) {
	const MASK = (1n << 64n) - 1n;
	const MULT = 6364136223846793005n;
	const INC = ((1442695040888963407n << 1n) | 1n) & MASK;
	let state = 0n;
	const next = () => {
		const old = state;
		state = (old * MULT + INC) & MASK;
		const shifted = Number((((old >> 18n) ^ old) >> 27n) & 0xffffffffn);
		const rot = Number(old >> 59n);
		return ((shifted >>> rot) | (shifted << (-rot & 31))) >>> 0;
	};
	next();
	state = (state + BigInt(seed)) & MASK;
	next();
	const randf = () => {
		const proto = next();
		if (proto === 0) return 0;
		return Math.fround((next() | 0x80000001) >>> 0) * 2 ** (-32 - Math.clz32(proto));
	};
	const bounded = (bound) => {
		const threshold = ((2 ** 32 - bound) >>> 0) % bound;
		for (;;) { const r = next(); if (r >= threshold) return r % bound; }
	};
	return { randf, randiRange(low, high) { return low === high ? low : low + bounded(high - low + 1); }, chance(percent) { return randf() * 100 < percent; } };
}

// --- the JavaScript side ---------------------------------------------------------------------

const ints = (source) => Object.fromEntries(Object.entries(source || {}).filter(([, v]) => typeof v === 'number' && Math.trunc(v) !== 0).map(([k, v]) => [k, Math.trunc(v)]));

// A "full" fixture: real turns. A turn that names a hand is played on it (the Flawless fixtures
// fix only the first); the rest come out of the turn's own throw. tools/balance_parity.gd
// _run_full plays the same.
function playFull(f, state, unit) {
	const rng = makePcg(7);
	const snaps = [];
	state.turn = 1;
	f.runs.forEach((run, index) => {
		if (unit.downed && index > 0) return;
		if (run.hand) unit.hand = unit.dice.map((die, at) => buildRoll(die, run.hand[at]));
		Fight.startRail(state, unit);
		snaps.push(snapshot(state, unit, Fight.runQueue(state, rng, true)));
		if (unit.downed) return;
		for (const blow of run.blows) {
			const foe = state.enemies[blow.foe];
			if (foe.hp <= 0 || unit.downed) continue;
			if (blow.kind === 'remove_block') Fight.applyOne(state, foe, unit, 'remove_block', 0, { remove_all: true }, rng);
			else Fight.applyOne(state, foe, unit, 'damage', blow.through_block ? Math.ceil(unit.block * 1.25) : blow.amount, {}, rng);
		}
		Fight.tick(state, rng);
		state.queue = [{ kind: 'mortar' }];
		snaps.push(snapshot(state, unit, Fight.runQueue(state, rng, true)));
		if (unit.downed) return;
		state.turn += 1;
		state.turn_kills = 0;
		Fight.beginTurn(state, unit, (die, _index, rerolled = 0) => Dice.rollOne(die, rng, rerolled));
		snaps.push(snapshot(state, unit, []));
	});
	return { id: f.id, snaps };
}

function play(f) {
	const def = C.character(f.character);
	const dice = def.dice.map((ref, i) => Dice.dieFrom(ref, `p${i}`));
	for (const at of f.etch || []) Dice.etch(dice[at.die], at.face, at.kind);
	const rail = f.rail.map((s) => (s ? { ...Stone.make(s.skill, s.carat, s.cut, s.clarity, s.inclusions, s.id), ...(s.absorbed ? { absorbed: s.absorbed } : {}) } : null));
	const unit = Fight.makePlayer('p0', f.character, rail, dice, { pyrite: f.pyrite, worn: f.worn || '' });
	const enemies = f.enemies.map((spec, i) => { const foe = Fight.makeDummy(`e${i}`, { dice: f.mode === 'full' ? ['D4', 'D4', 'D4'] : ['D4', 'D4'], hp: spec.hp ?? 0 }); foe.block = spec.block; foe.statuses = ints(spec.statuses); foe.dread_turns = spec.dread_turns | 0; return foe; });
	const state = Fight.makeFight({ players: [unit], enemies, depth: f.depth });
	unit.hp = f.unit.hp;
	unit.block = f.unit.block;
	unit.block_lost = f.unit.block_lost;
	unit.statuses = ints(f.unit.statuses);
	unit.initial_resonance = f.unit.initial_resonance;
	unit.rerolls = f.unit.rerolls;
	unit.target = 'e0';
	if (f.mode === 'full') return playFull(f, state, unit);
	// Godot's own generator here too: a variant Birthstone may pick a creature at random (a Fan
	// of Knives, a Heartsblood) or throw the dice again (a Whole Cloth), forecast or not. Nothing
	// else on these rails asks it for a number that matters.
	const rng = makePcg(7);
	const snaps = [];
	for (const run of f.runs) {
		unit.hand = unit.dice.map((die, index) => buildRoll(die, run.hand[index]));
		Fight.startRail(state, unit);
		const events = f.mode === 'dry' ? playDry(state, unit, rng) : Fight.runQueue(state, rng, true);
		snaps.push(snapshot(state, unit, events));
	}
	return { id: f.id, snaps };
}

// A fixed roll, written the way DeepDice.roll_one writes a thrown one: an exploding face adds
// each face of its `chain` and keeps `base` and `chain`; a face whose number is not what it
// counts for keeps `shown` and `counted`. tools/balance_parity.gd _hand builds the same.
function buildRoll(die, spec) {
	const face = die.faces[spec.face];
	const kind = face.kind || 'plain';
	let value = Dice.faceValue(face);
	const chain = (kind === 'exploding' ? spec.chain || [] : []).map((at) => ({ face: at, value: Dice.faceValue(die.faces[at]) }));
	for (const link of chain) value += link.value;
	const roll = { die_id: die.id, shape: die.shape, material: die.material || '', value, face: spec.face, kind, top: Dice.top(die),
		held: spec.held, rerolls: spec.rerolls, locked: false, explosions: chain.length, phantom: false };
	if (kind !== 'blank' && (face.value | 0) !== value) { roll.shown = face.value | 0; roll.counted = value; }
	if (kind === 'exploding') { roll.base = Dice.faceValue(face); roll.chain = chain; }
	return roll;
}

// The forecast's way through a rail: every gem and the Birthstone resolved dry.
function playDry(state, unit, rng) {
	const events = [];
	// No rail begins for a player who is down (a Bloodroot's Tap can take the last of her health):
	// every step of theirs is dropped, as sim/battle.gd _drop_steps drops them.
	if (unit.downed) state.queue = state.queue.filter((s) => s.unit !== unit.id);
	while (state.queue.length) {
		const s = state.queue.shift();
		if (s.kind === 'gem') events.push(Fight.resolveGem(state, unit, s.socket, { dry: true, retrigger: Boolean(s.retrigger), scale: s.scale ?? 100 }, rng));
		else if (s.kind === 'birthstone') events.push(Fight.resolveBirthstone(state, unit, { dry: true, replay: Boolean(s.replay), share: s.share ?? 100 }, rng));
		else events.push(Fight.perform(state, s, rng));
	}
	return events;
}

function snapshot(state, a, events) {
	const log = [];
	for (const e of events) {
		if (!e) continue;
		if (e.kind === 'gem_fire' || e.kind === 'gem_fizzle') log.push([e.kind, e.socket, e.resonance | 0]);
		// The tiers that fired, the ones another took the place of, how many things each did (a
		// knife thrown again is one more), the Resonance it opened on, what an Arpeggio added, and
		// what each tier's trigger counted (the dice showing 1, the colors fired).
		else if (e.kind === 'birthstone') log.push(['birthstone', Boolean(e.fired), e.tiers.map((t) => Boolean(t.active)), e.tiers.map((t) => Boolean(t.eclipsed)), e.tiers.map((t) => t.effects.length),
			Math.trunc(e.resonance), Math.trunc(e.climbed), e.tiers.map((t) => Math.trunc(t.counted))]);
	}
	const buffs = {};
	for (const [id, entry] of Object.entries(a.gem_buffs || {})) { const clean = ints(entry); if (Object.keys(clean).length) buffs[id] = clean; }
	return { unit: { hp: a.hp, max_hp: a.max_hp, block: a.block, resonance: a.resonance, gold: a.gold | 0, pyrite_delta: a.pyrite_delta | 0, pot: a.pot | 0, statuses: ints(a.statuses),
		granted_rerolls: a.granted_rerolls | 0, sparkle: a.sparkle | 0, quality_bonus: a.quality_bonus | 0, rank_buff: ints(a.rank_buff), gem_buffs: buffs,
		fired: a.fired_sockets.slice(), fizzled: a.fizzled_sockets.slice(), rail: a.rail.map((s) => (s ? String(s.id) : '')), hand: a.hand.map((r) => [r.die_id, r.value, Boolean(r.phantom), Math.trunc(r.shown ?? -1), Math.trunc(r.counted ?? -1)]),
		faces: a.dice.map((d) => d.faces.map((f) => f.value | 0)), amplify: Math.round(Number(a.amplify) * 10000) / 10000, cut_step_bonus: a.cut_step_bonus | 0,
		nullify_next: Boolean(a.nullify_next), repeat_next: a.repeat_next | 0, healed: a.healed | 0, dealt: a.dealt | 0, once: Object.keys(a.once).sort(),
		carats: a.rail.map((s) => (s ? s.carat | 0 : 0)), run_counts: ints(a.run_counts), rerolls: a.rerolls | 0, granted: a.granted_rerolls | 0,
		// What the Flawless lines have set up, or hold for later, that nothing above reads yet.
		setups: { strength_guard: Boolean(a.strength_guard), poison_safe: Boolean(a.poison_safe), thorns: Boolean(a.envenom_thorns), gilded_pay: a.gilded_pay | 0, carry_next: Boolean(a.carry_rerolls_next),
			carrying: Boolean(a.carrying_rerolls), mortar: 'mortar' in a, grow_next: a.grow_next | 0, bound_next: (a.bound_next || []).slice(), fight_max_hp: a.fight_max_hp | 0, enriched: ints(a.enriched),
			shattered: (a.shattered || []).slice(), refracted: (a.refracted || []).length, overhealed: a.overhealed | 0, gifts: Object.values(a.after_fire_fight || {}).reduce((sum, gift) => sum + (gift.amount | 0), 0) },
		// The Birthstone worn and what the variants keep: the 1s a Bloodroot has counted, what a
		// Thornwork holds up until next turn, a Whole Cloth spent, the bowl a Standing Ovation grew
		// (a Renown's Trophies are among the run's counts above).
		worn: String(a.birthstone_key || ''), stone: String((a.birthstone || {}).name || ''), fight_ones: Math.trunc(a.fight_ones || 0), timed: ints(a.timed), second_act: Boolean(a.second_act),
		shapes: a.dice.map((d) => String(d.shape)), tops: a.dice.map((d) => Dice.top(d)), fight_grown: ints(a.fight_grown),
		// The bowl the fight would hand back were it to end here: the Ovation's sizes off, what was done for good kept.
		after: Fight.diceAfterFight(a).map((d) => [String(d.shape), d.faces.map((f) => f.value | 0)]) },
	enemies: state.enemies.map((foe) => ({ hp: foe.hp, max_hp: foe.max_hp, block: foe.block, statuses: ints(foe.statuses), stolen_dice: foe.stolen_dice | 0, dread_turns: foe.dread_turns | 0, marks_kept: foe.marks_kept | 0, plague: Boolean(foe.plague) })),
	events: log };
}

// --- comparing -------------------------------------------------------------------------------

function differences(want, got, where = '', out = []) {
	if (out.length > 6) return out;
	if (typeof want !== typeof got || Array.isArray(want) !== Array.isArray(got)) { out.push(`${where}: godot ${JSON.stringify(want)} · js ${JSON.stringify(got)}`); return out; }
	if (want && typeof want === 'object') {
		const keys = new Set([...Object.keys(want), ...Object.keys(got)]);
		for (const key of keys) {
			if (!(key in want) || !(key in got)) { out.push(`${where}.${key}: godot ${JSON.stringify(want[key])} · js ${JSON.stringify(got[key])}`); continue; }
			differences(want[key], got[key], `${where}.${key}`, out);
		}
		return out;
	}
	if (want !== got) out.push(`${where}: godot ${JSON.stringify(want)} · js ${JSON.stringify(got)}`);
	return out;
}

function describe(f) {
	return `${f.mode} ${f.character}${f.worn ? ` in ${f.worn}` : ''}${f.aimed ? ' (aimed)' : ''} [${f.rail.map((s) => (s ? `${s.skill} ${s.carat}ct c${s.cut} k${s.clarity}${s.inclusions.length ? ' +' + s.inclusions.join('+') : ''}` : '·')).join(', ')}]`;
}

// Godot 4.7.2: GODOT_BIN, the path, or a build (console or not) beside the project, on the desktop or in
// downloads (the way music.mjs looks, without needing its encoder installed).
function findGodot() {
	const candidates = [process.env.GODOT_BIN];
	for (const name of ['godot', 'godot4']) {
		try { candidates.push(execFileSync(process.platform === 'win32' ? 'where' : 'which', [name], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split(/\r?\n/)[0].trim()); } catch { /* not on the path */ }
	}
	const home = process.env.USERPROFILE || process.env.HOME || '';
	for (const dir of [path.dirname(ROOT), path.join(home, 'Desktop'), path.join(home, 'Downloads')]) {
		// The console build first (its output reaches the pipe as it is written), then the plain one.
		try { for (const file of readdirSync(dir).sort((a, b) => Number(/_console/i.test(b)) - Number(/_console/i.test(a)))) if (/^Godot_v4\.7\.2-stable_win64(_console)?\.exe$/i.test(file)) candidates.push(path.join(dir, file)); } catch { /* no such folder */ }
	}
	candidates.push('/Applications/Godot.app/Contents/MacOS/Godot');
	return candidates.find((c) => c && existsSync(c)) || null;
}

function runGodot(fixtureFile, outFile) {
	const godot = findGodot();
	if (!godot) throw new Error('Godot 4.7.2 was not found. Set GODOT_BIN to the Godot executable.');
	return new Promise((resolve, reject) => {
		const child = spawn(godot, ['--headless', '--path', ROOT, '--script', 'res://tools/balance_parity.gd', '--', fixtureFile, outFile], { cwd: ROOT, windowsHide: true });
		let log = '';
		child.stdout.on('data', (d) => { log += d; });
		child.stderr.on('data', (d) => { log += d; });
		child.on('error', reject);
		child.on('close', (code) => {
			const errors = log.split(/\r?\n/).filter((l) => /SCRIPT ERROR|^ERROR:/.test(l));
			if (code !== 0 || errors.length) reject(new Error(errors.join('\n') || `Godot exited with ${code}\n${log.slice(-1200)}`));
			else resolve(log);
		});
	});
}

await mkdir(OUT, { recursive: true });
const list = fixtures(COUNT, SEED);
list.push(...flawlessFixtures(SEED, COUNT));
if (!FIRST_ONLY) list.push(...variantFixtures(SEED, list.length));
const fixtureFile = path.join(OUT, 'fixtures.json');
const godotFile = path.join(OUT, 'godot.json');
await writeFile(fixtureFile, JSON.stringify(list));
const started = Date.now();
await runGodot(fixtureFile, godotFile);
const godot = JSON.parse(await readFile(godotFile, 'utf8'));
console.log(`Godot played ${godot.length} fixtures in ${((Date.now() - started) / 1000).toFixed(1)}s`);
let failed = 0;
// What each Birthstone was given to do: the fixtures that wore it, the ones it fired in, and
// which of its tiers lit at least once (as Godot played them).
const worn = new Map();
for (const f of list) {
	const want = godot.find((g) => g.id === f.id);
	const key = `${f.character}/${f.worn || ''}`;
	const seen = worn.get(key) || { fixtures: 0, fired: 0, tiers: new Set() };
	worn.set(key, seen);
	seen.fixtures += 1;
	let lit = false;
	for (const snap of want.snaps) for (const e of snap.events) if (e[0] === 'birthstone' && e[1]) { lit = true; e[2].forEach((on, tier) => { if (on) seen.tiers.add(tier); }); }
	if (lit) seen.fired += 1;
	let got;
	try { got = play(f); } catch (error) { failed += 1; console.log(`\n#${f.id} ${describe(f)}\n  JS threw: ${error.stack || error}`); continue; }
	const diff = differences(want.snaps, got.snaps, 'rail');
	if (diff.length) {
		failed += 1;
		if (failed <= 25) console.log(`\n#${f.id} ${describe(f)}\n  ${diff.join('\n  ')}`);
	}
}
console.log(`\n${list.length - failed} of ${list.length} fixtures agree (${list.filter((f) => f.mode === 'live').length} live, ${list.filter((f) => f.mode === 'dry').length} dry, ${list.filter((f) => f.mode === 'full').length} full; ${list.filter((f) => f.aimed).length} of them aimed at the variant Birthstones).`);
console.log('Birthstones worn: fixtures / fired in / tiers lit of its tiers');
for (const [character, key] of C.allBirthstones()) {
	const def = C.birthstoneDef(character, key);
	const seen = worn.get(`${character}/${key}`) || { fixtures: 0, fired: 0, tiers: new Set() };
	const dark = (def.tiers || []).filter((_, tier) => !seen.tiers.has(tier)).map((tier) => tier.name);
	console.log(`  ${String(def.name).padEnd(18)} ${String(seen.fixtures).padStart(4)} / ${String(seen.fired).padStart(4)} / ${seen.tiers.size} of ${(def.tiers || []).length}${dark.length ? ` (never lit: ${dark.join(', ')})` : ''}`);
}
if (!args.includes('--keep')) await rm(OUT, { recursive: true, force: true });
process.exit(failed ? 1 : 0);
