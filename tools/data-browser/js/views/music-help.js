// What every control on the Soundtrack page does to the music, in the words a tooltip can
// carry. Each entry is written from what view/audio/composer.gd actually does with the field:
// when the composer changes, change these with it.

import { h, showTip, hideTip, tipTitle } from '../ui.js';

// --- the tooltip ------------------------------------------------------------------------------

// Hovering (or focusing) `el` shows a heading, lines of explanation and, for a choice, every
// option with the current one marked. `lines` may be a function, read when the tip opens.
export function explain(el, heading, lines, options = null) {
	const show = () => {
		const body = typeof lines === 'function' ? lines() : lines;
		showTip(el, h('div', { class: `mu-tip${options ? ' is-wide' : ''}` }, tipTitle(heading),
			[body].flat().filter(Boolean).map((line) => h('div', { class: 'mu-tip-line' }, line)),
			options ? h('div', { class: 'mu-tip-options' }, options.list.map(([key, label, text]) =>
				h('div', { class: `mu-tip-option${String(key) === String(options.current) ? ' is-current' : ''}` }, h('b', {}, label), h('span', {}, text)))) : null));
	};
	el.removeAttribute('title');
	el.addEventListener('mouseenter', show);
	el.addEventListener('focus', show);
	el.addEventListener('mouseleave', hideTip);
	el.addEventListener('blur', hideTip);
	el.addEventListener('mousedown', hideTip);
	return el;
}

// A field whose label carries a small mark saying there is more to read, and the tip on it.
export function helpLabel(text, heading, lines, options = null) {
	return explain(h('span', { class: 'field-label mu-help', tabindex: 0 }, text, h('i', { class: 'mu-q' }, '?')), heading, lines, options);
}

// Each button of a segmented control explained on its own, in the order they were given.
export function explainEach(seg, entries) {
	[...seg.querySelectorAll('.seg-btn')].forEach((btn, i) => { if (entries[i]) explain(btn, entries[i][0], entries[i][1]); });
	return seg;
}

export { hideTip };

// --- the piece --------------------------------------------------------------------------------

export const NAME = ['The piece’s name', 'Shown on the game’s Soundtrack page (Esc, Settings, Soundtrack), where the player picks which piece plays in each place. Changes nothing in the sound.'];

export const KEY = ['Key', [
	'The note the whole piece is built on. Changing it transposes everything (pads, bass, tune, arpeggio) and changes nothing else: same tune, same chords, same rhythm.',
	'Every key is kept about as deep as every other: the key note sits between A2 and G♯3. So A is the lowest-sounding key and G♯ the highest, and going from G♯ round to A drops the piece by most of an octave.',
	'Dots mark the notes of the chosen mode in this key. The tune only ever uses those.']];

export const MODE = ['Mode', [
	'Which seven notes the piece uses, counted up from the key note. It sets the mood more than anything else, and it decides which chords each chord tile gives (a tile is a step of the mode, not a fixed chord).',
	'Under each name, its steps: W a whole tone, H a half tone, W+ a tone and a half.']];

export const MODES = {
	ionian: 'The major scale. Bright, settled, plain. Rare down a mine; sounds like daylight.',
	dorian: 'Minor with a raised sixth. Sad but hopeful, folk-like: the Quarry’s sound.',
	phrygian: 'Minor with a lowered second. Dark, with a Spanish, flamenco edge right next to the key note.',
	lydian: 'Major with a raised fourth. Bright and floating, a little unreal: wonder, crystal, light.',
	mixolydian: 'Major with a lowered seventh. Earthy, folk and rock; homely rather than triumphant.',
	aeolian: 'The natural minor. Plain, melancholy, the default minor sound.',
	locrian: 'Diminished key chord, so it never feels at home. Unstable and uneasy: the Rift.',
	harmonic: 'Minor with a raised seventh: the leap back to the key note is dramatic and old-world. The Furnace.',
	phrygian_dominant: 'Phrygian with a major third. Exotic, fierce, Middle-Eastern.',
};

export const TEMPO = ['Tempo', [
	'Beats a minute. Every piece is 24 bars, so a faster tempo is a shorter loop, and everything (tune, bass, drums, arpeggio) moves with it.',
	'Under about 70 drifts; 80–95 walks; over 105 hurries. A mine’s fights bring the drums in over this same tempo, so a slow piece makes for heavy fights rather than frantic ones.']];

export const METRE = ['Metre', 'How many beats to the bar.'];
export const METRES = [
	['3/4', 'Three beats a bar: a lilt, a waltz, a sway. The drums switch to their three-beat grooves and the tunes to three-beat phrases. A bar is shorter, so the loop is too.'],
	['4/4', 'Four beats a bar: steady, walking, marching. The usual.'],
];

export const SEED = ['Seed', [
	'Where every chance choice comes from: the three short motifs the tune is built from, the small swells in loudness, the drums’ touch.',
	'The same seed always writes the same piece. A new one keeps the key, the chords and the instruments and writes a new tune over them, so it is the way to audition tunes.']];

export const CHORDS = ['Chords', [
	'One chord for every two bars: eight for the verse, four for the bridge, which together make the 24-bar loop. The pads hold it, the bass walks it, the arpeggio climbs it, and the tune leans on its notes at the top of each bar.',
	'A tile is a step of the mode (its Roman numeral), so the same tiles give different chords in another mode. Capitals are major, small letters minor, ° diminished, + augmented.',
	'The last chord of the verse and of the bridge leads back to the start: a V or VII there is what lets the loop come round without a bump.']];

// What each two-bar phrase of the plan does with the tune.
export const PLAN_PARTS = {
	A: 'The first strain: the tune’s opening motif, stated.',
	A2: 'The first strain again, ending on the chord’s root.',
	B: 'The second strain: a new motif, a little higher.',
	B2: 'The second strain again, ending on the chord’s root.',
	ans: 'A breath: two long notes and room for the echo, and a glint of bell.',
	end: 'The landing: half the motif, then the chord’s root held, and a glint of bell.',
	C: 'The bridge: a third motif, lifted higher than the rest.',
	C2: 'The bridge again, ending on the chord’s root.',
};

// What a chord on each step of the scale tends to do, whatever the mode.
export const DEGREES = [
	'Home. Rest and arrival; the piece starts and ends here.',
	'Next door to home: restless, wants to move on (often to V).',
	'A shade of home: soft, a little wistful.',
	'Away from home: opening out, lifting.',
	'Tension that wants to resolve home. The strongest last chord for a phrase.',
	'The relative: home’s darker or brighter twin. Gentle, emotional.',
	'One step below home: leads back up to it. In minor modes a strong, modal way home.',
];

// --- voices and mix ---------------------------------------------------------------------------

export const PAD = ['Pad', 'The held chords in the bed layer, which plays under everything, always. Sets the colour of the whole piece.'];
export const PADS = {
	pad_warm: 'Three detuned sawtooths through a soft filter. Warm, analog, cosy; fills the room.',
	pad_glass: 'Sine with a faint octave shimmer and a slow tremolo. Pure, watery, cold; leaves space.',
	pad_choir: 'Triangles with slow vibrato. Airy, like distant voices.',
	pad_dark: 'Two detuned sawtooths filtered low. Thick, murky, ominous.',
};

export const BASS = ['Bass', 'The bass of the pulse layer (in every mood but the quietest) and of the fight layer’s running eighths.'];
export const BASSES = {
	bass_sub: 'Sine and a little triangle. Smooth, felt more than heard; never in the way.',
	bass_pluck: 'A plucked string. Woody, like an upright bass or a low guitar; every note speaks.',
	bass_saw: 'A filtered sawtooth that opens as it sounds. Growling, heavy, aggressive.',
};

export const BASS_LINE = ['Bass line', 'The rhythm the pulse layer’s bass plays under each chord.'];
export const BASS_LINES = [
	['Walk', 'The root on the downbeat and the fifth halfway through the bar. A steady stride.'],
	['Pedal', 'One long root every two bars. Still, spacious, patient; lets the tune lead.'],
	['Syncopated', 'Root, root again off the beat, then the fifth late. Pushes forward; a groove.'],
];

export const LEAD = ['Lead', 'The instrument that plays the tune, in the melody layer, which is mixed loudest of all. The voice the player will remember the piece by.'];
export const LEADS = {
	lead_flute: 'Breathed sine with a touch of vibrato. Soft, pastoral, wooden.',
	lead_bell: 'Struck bell partials that ring on. Crystalline and sparse; best set High.',
	lead_glass: 'Sine with glassy overtones and a long tail. Ethereal; best set High.',
	lead_pluck: 'A thumbed string. A guitar by the fire: warm, intimate.',
	lead_marimba: 'A struck wooden bar, short. Percussive, earthy, playful.',
	lead_reed: 'Filtered sawtooth with vibrato. Nasal and oboe-like: intense, old, a little sinister.',
};

export const LEAD_OCTAVE = ['Lead octave', 'Where the tune sits. It spans about an octave and a half above its key note.'];
export const LEAD_OCTAVES = [
	['Low', 'Key note between E3 and D♯4; the tune peaks around G5. For flute, pluck, marimba and reed, which turn shrill higher up.'],
	['High', 'A fifth higher: peaks around D6. For bell and glass, which turn muddy low. Can be piercing with any other lead.'],
];

export const KIT = ['Kit', 'Which drums play the grooves. The pulse layer has a light kick, shaker and percussion; the fight layer the full groove with a backbeat and a fill every eighth bar. The threat layer’s taiko and timpani are the same for every kit.'];
export const KITS = {
	frame: 'Kick, tom backbeat, shaker, frame drum. Folk, hand-played.',
	drip: 'Kick, rimshot, shaker, water drips. Wet and sparse.',
	glass: 'Kick, snare, glassy ticks high and low. Bright and brittle.',
	wood: 'Kick, low woodblock, shaker, woodblock. Dry and organic.',
	anvil: 'Taiko, anvil backbeat, hi-hat, tom. Heavy, metallic, hammered.',
	chime: 'Kick, snare, hi-hat, chimes. Bright and a little grand.',
	void: 'A deep thud, rimshot, hi-hat, low drips. Hollow and strange.',
	hearth: 'Kick, rimshot, shaker, woodblock. Gentle; for the workshop.',
};

export const ARP = ['Arpeggio', 'Only heard in fights: the fight layer runs up and down the chord, from just above the key note to an octave over it, in this instrument. Pick something that cuts through the drums.'];
export const ARP_RATE = ['Arp rate', 'How fast the fight layer’s arpeggio runs.'];
export const ARP_RATES = [
	['16th', 'Four notes a beat. Busy, urgent, constant motion.'],
	['8th', 'Two notes a beat. Driving but clear.'],
	['Dotted 8th', 'One note every three sixteenths, against the beat. A rolling cross-rhythm.'],
	['Quarter', 'One note a beat. Sparse and stately; the drums carry the fight.'],
];

export const ECHO = ['Echo on the tune', [
	'The melody layer repeats itself three sixteenths later, three times, each repeat this much quieter than the last.',
	'0 is dry. Around 0.2, a room. 0.4 and over, a cavern, and fast tunes start to blur into themselves.']];

export const LAYERS = ['Layers', 'How many of the six layers the piece is written in.'];
export const LAYER_COUNTS = [
	['3: walk only', 'Bed, pulse and melody. No fight, elite or Warden layers, so a fight would add nothing. Only for the workshop, where no fight is ever had.'],
	['6: with fights', 'All six: the fight layer (full drums, arpeggio, eighth-note bass), the threat layer for elites and Wardens (taiko, timpani, braams) and the Warden layer (string gallop, the tune in horns) come in when the mine asks for them.'],
];

export const DRONE = ['Drone under the bed', 'Two hums held for the whole loop, the key note deep down (A1 to G♯2) and the fifth above it, breathing slowly. Underground weight and pressure. Off, the piece is lighter and more open.'];
export const SEVENTHS = ['Sevenths in the pads', 'Adds each chord’s seventh to the pads. Lusher, jazzier, less resolved; a major chord turns dreamy, a minor one bittersweet.'];
export const WARDEN_LIFT = ['Warden key change', [
	'In a Warden’s hall the whole piece goes up a semitone (and about 6% faster), switching on the next downbeat, and comes back down on the downbeat after the Warden falls. The classic last-chorus lift: the same music, suddenly higher and more urgent.',
	'Nothing is re-rendered for it: the game speeds the baked loop up as it plays, so it needs no render and adopting it is instant. Try it in the Warden mood. It suits some pieces better than others, which is why it is per piece.']];
export const LIFTED = ['Key change on', 'Playing a semitone up, as the game will in a Warden’s hall: the change waits for the next downbeat, as it does in game.'];

// --- hearing it -------------------------------------------------------------------------------

export const MOOD = ['Mood', 'Sets the layers to the levels the game uses in that situation, and runs the Music bus as hot as the game does there (with Game effects on). In a mine the game also brings the bass and tune up the deeper the party goes.'];
export const MOODS = {
	home: 'The workshop: bed, most of the pulse, nearly all of the tune.',
	rest: 'A landing, or the shaft down: bed and tune, barely any pulse.',
	explore: 'Walking the mine between fights: bed, half the pulse, half the tune.',
	fight: 'A fight: the fight layer over everything that was playing.',
	elite: 'An elite fight: the fight, and the threat layer’s big drums and braams.',
	warden: 'A Warden’s hall: all six layers, the pads and the tune pulled back so the string gallop and the horns come through.',
};
// What the bus does at a heat, in words for a mood's tip.
export const HEAT_WORDS = (heat) => (heat <= 0 ? 'Bus: calm (in a mine, a gentle low pass at 6.5 kHz).'
	: heat < 0.6 ? 'Bus: low pass open, compressor squeezing a little harder and louder.'
		: heat < 0.9 ? 'Bus: open, compressed harder, a touch of saturation.'
			: 'Bus: open, compressed hardest and loudest, saturated.');
export const FX = ['Game effects', [
	'The game’s Music bus, as it is in that mood: a long dark reverb; between fights in a mine a gentle low pass, so a fight opening it sounds brighter and closer; a compressor that squeezes harder and adds loudness the bigger the fight; soft saturation in an elite or a Warden’s hall; a limiter last.',
	'The baked files are dry. Off, you hear them as they are.']];
export const MIXER = (i) => [['Bed', 'Pulse', 'Melody', 'Drive', 'Threat', 'Peril'][i] + ' layer', ['Pads and the drone. Always on, in every mood.', 'The bass and a light hand on the drums. Grows the deeper the party goes.', 'The tune, its echo and the bell glints. Mixed loudest.', 'The fight: the full drum groove, the arpeggio, the bass in eighths.', 'Elites and Wardens: taiko on the strong beats, timpani on the chord’s root, a timpani roll and a cymbal swell into every fourth bar, and a low brass braam where they land. Heard far off near the bottom of a mine.', 'A Warden’s hall: strings galloping on the chord in sixteenths, the piece’s own tune in the horns, brass stabs on the downbeat, high tremolo strings.'][i], 'Click to mute it. The bar is its level in this mood.'];

export const LIVE = ['Live', 'What the game plays: the Ogg files in audio/music/<id>, one a layer. Only Adopt (or a bake) changes them.'];
export const DRAFT = ['Draft', 'Your edits, kept in build/music/drafts until you adopt or discard them. Rendered by Godot with the game’s own synth, so it sounds exactly as it would in game.'];
export const RENDER = ['Render draft', 'Has Godot write the draft out, every layer, as it stands. Takes about ten seconds. With “Render as I edit” on, this happens a moment after every change.'];
export const ADOPT = ['Adopt draft → live', 'Bakes the draft over the live Ogg files and writes its spec into content/score.json. The game plays it from then on. Not undoable from here (git is the undo).'];
export const DISCARD = ['Discard draft', 'Deletes the draft and its render. The live version and the score stay as they are.'];
export const MIDI = ['MIDI', ['Every note of this version as a Standard MIDI file: one track for each instrument in each layer, drums on channel 10, with the tempo, metre, key and the phrase names as markers.', 'Edit it in a DAW, bounce a layer to Ogg at the same length, and drop it over that layer in audio/music/<id>: the page marks it as replaced by hand and nothing here overwrites it without asking.']];
export const AUTO = ['Render as I edit', 'Queues a render of the draft a moment after every change, so the draft is always ready to hear. Off, render by hand.'];
export const ROLL = ['Notes', ['Every note of the version playing, coloured by layer; brighter is louder. Pitch runs up the page, the drums sit in rows along the bottom, the phrases and their chords along the top.', 'Click anywhere to jump there.']];
export const PIECE = ['Piece', ['The dot: green is baked and has no draft; gold has a rendered draft; amber has edits not yet rendered; red was never baked.', '“Default” is the piece the game plays in this place unless the player picks another.']];
