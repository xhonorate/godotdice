// The sound profile as the owner settled it over six rounds of review (November 2026): which
// version of each sound in `synth.js` is the game's. Everything not named here is the round 2
// recipe; a letter is a later round's version (a, b round 3; c, d round 4; e, f round 5;
// g a round 6 proposal). `view/audio/sound_bank.gd` is the same bank in GDScript, recipe for
// recipe, and `parity.mjs` checks the two still agree.
export const PICKS = {
	ui_confirm: 'b', ui_back: 'a', ui_open: 'a', ui_close: 'g', ui_toggle: 'g', ui_tab: 'g', ui_deny: 'g', toast_bad: 'a', unlock: 'a',
	dice_lock: 'b', die_break: 'a', die_pick: 'g',
	battle_begin: 'g', turn_begin: 'g',
	gem_red: 'c', gem_blue: 'g', gem_green: 'a', gem_violet: 'f', gem_gold: 'b', gem_fizzle: 'f',
	tick_green: 'g', tick_white: 'g', tally_mult: 'a', tally_fuse: 'a', tally_blaze: 'a',
	hit_light: 'a', hit_heavy: 'a', hit_crit: 'a', block: 'g', block_break: 'g',
	heal: 'g', curse: 'a',
	enemy_windup: 'b', hit_bite: 'g', hit_claw: 'g', hit_breath: 'g', hit_lash: 'g', hit_peck: 'g', hit_drill: 'b', hit_erupt: 'g', hit_burst: 'g', hit_pull: 'a',
	creature_die: 'a', warden_die: 'g', victory: 'g', defeat: 'g',
	pick_strike: 'g', rock_break: 'g', landing: 'e', lift: 'b', salvage_lose: 'a',
	loupe_spin: 'g', grade_exquisite: 'g', grade_peerless: 'g',
	altar_hum: 'g', altar_fizzle: 'c', altar_make: 'g', transcendent: 'g',
	geode_crack: 'g', jackpot: 'g', infinity: 'g', mirror: 'g',
};
// The game's sample rate: the synth in `view/audio/synth.gd` writes at 24 kHz and the mixer
// resamples. Set before `synth.js` is loaded, so the two banks are compared like for like.
export const GAME_RATE = 24000;
// The eight pieces of the score, by place, as `content/score.json` names them.
export const PIECES = { HOME: 'home_bench', QUARRY: 'quarry_lantern', SEEPS: 'seeps_lanterns', GLASS_VEINS: 'glass_kaleidoscope', WARRENS: 'warrens_spores', FURNACE: 'furnace_choir', GEODE: 'geode_amethyst', RIFT: 'rift_void' };
// Which spec in `synth.js` each piece is written from.
export const SPEC_OF = { home_bench: 'home3_a', quarry_lantern: 'quarry3', seeps_lanterns: 'seeps3', glass_kaleidoscope: 'glass3', warrens_spores: 'warrens3', furnace_choir: 'furnace3_b', geode_amethyst: 'hollow3', rift_void: 'rift3' };
