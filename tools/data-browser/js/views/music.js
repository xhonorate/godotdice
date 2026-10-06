// Soundtrack: every piece in content/score.json, its spec edited with the controls that suit it,
// a draft rendered by Godot beside the live version, both heard through the same five-layer
// mixer the game uses, and either one taken out as MIDI.
//
// Edits go into a draft (build/music/drafts/<id>), never straight into the score. Render plays
// the draft back; Adopt bakes it over the live Ogg files and writes its spec to the score;
// Discard throws it away and the live version stands.

import * as C from '../sim/content.js';
import { h, clear, append, card, chip, segmented, select, field } from '../ui.js';

// --- what the composer knows (view/audio/composer.gd, score.gd, music.gd) ----------------------

const LAYERS = ['bed', 'pulse', 'melody', 'drive', 'peril'];
const LAYER_COLORS = ['#5b8bd9', '#3fb56b', '#e2b23a', '#e0473c', '#a77be0'];
const LAYER_WORDS = ['pads and drone, always on', 'bass and a light hand on the drums', 'the tune, its echo, a glint of bell', 'the fight: full kit, arpeggio, eighths', 'a Warden: horns, strings, cymbal swells'];
const PLAN = ['A', 'A2', 'B', 'ans', 'A', 'A2', 'B2', 'end', 'C', 'C2', 'B', 'end'];
const MODES = {
	ionian: [0, 2, 4, 5, 7, 9, 11], dorian: [0, 2, 3, 5, 7, 9, 10], phrygian: [0, 1, 3, 5, 7, 8, 10],
	lydian: [0, 2, 4, 6, 7, 9, 11], mixolydian: [0, 2, 4, 5, 7, 9, 10], aeolian: [0, 2, 3, 5, 7, 8, 10],
	locrian: [0, 1, 3, 5, 6, 8, 10], harmonic: [0, 2, 3, 5, 7, 8, 11], phrygian_dominant: [0, 1, 4, 5, 7, 8, 10],
};
const MODE_NAMES = { ionian: 'Ionian', dorian: 'Dorian', phrygian: 'Phrygian', lydian: 'Lydian', mixolydian: 'Mixolydian', aeolian: 'Aeolian',
	locrian: 'Locrian', harmonic: 'Harmonic minor', phrygian_dominant: 'Phrygian dom.' };
const MODE_MOOD = { ionian: 'bright, settled', dorian: 'minor, folk, hopeful', phrygian: 'dark, Spanish edge', lydian: 'bright, floating, wonder',
	mixolydian: 'major, earthy', aeolian: 'plain minor, sad', locrian: 'unstable, no home', harmonic: 'minor, dramatic', phrygian_dominant: 'exotic, fierce' };
const KEYS = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
const PITCH = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };
const VOICES = {
	pad: [['pad_warm', 'Warm'], ['pad_glass', 'Glass'], ['pad_choir', 'Choir'], ['pad_dark', 'Dark']],
	bass: [['bass_sub', 'Sub'], ['bass_pluck', 'Pluck'], ['bass_saw', 'Saw']],
	lead: [['lead_flute', 'Flute'], ['lead_bell', 'Bell'], ['lead_glass', 'Glass'], ['lead_pluck', 'Pluck'], ['lead_marimba', 'Marimba'], ['lead_reed', 'Reed']],
	kit: [['frame', 'Frame'], ['drip', 'Drip'], ['glass', 'Glass'], ['wood', 'Wood'], ['anvil', 'Anvil'], ['chime', 'Chime'], ['void', 'Void'], ['hearth', 'Hearth']],
};
// The composer's fallbacks for a field a spec leaves out.
const DEFAULTS = { key: 'C', mode: 'aeolian', bpm: 90, meter: 4, seed: 1, chords: [0, 5, 3, 4, 0, 5, 3, 4], bridge: [3, 5, 3, 4], pad: 'pad_warm',
	bass: 'bass_sub', bass_style: 'walk', lead: 'lead_pluck', lead_octave: 0, arp: 'lead_pluck', arp_rate: 2, kit: 'frame', layers: 5,
	drone: true, sevenths: false, echo: 0.22 };
const FIELD_NAMES = { name: 'name', key: 'key', mode: 'mode', bpm: 'tempo', meter: 'metre', seed: 'seed', chords: 'verse chords', bridge: 'bridge chords',
	pad: 'pad', bass: 'bass', bass_style: 'bass line', lead: 'lead', lead_octave: 'lead octave', arp: 'arpeggio', arp_rate: 'arp rate', kit: 'kit',
	layers: 'layers', drone: 'drone', sevenths: 'sevenths', echo: 'echo' };
// How loud each layer plays in each mood (DeepMusic.MOODS), as the game mixes them.
const MOODS = [['home', 'Workshop', [1, 0.7, 0.9, 0, 0]], ['rest', 'Calm', [1, 0.2, 0.75, 0, 0]], ['explore', 'Explore', [1, 0.45, 0.55, 0, 0]],
	['fight', 'Fight', [1, 1, 1, 0.9, 0]], ['elite', 'Elite', [1, 1, 1, 1, 0.5]], ['warden', 'Warden', [1, 1, 1, 1, 1]]];
const DRUM_ROWS = ['kick', 'back', 'hat', 'perc', 'swell'];

// --- state kept across renders ----------------------------------------------------------------

const store = (key, fallback) => { try { const v = JSON.parse(localStorage.getItem(`deepcut.music.${key}`)); return v ?? fallback; } catch { return fallback; } };
const keep = (key, value) => { try { localStorage.setItem(`deepcut.music.${key}`, JSON.stringify(value)); } catch { /* private window */ } };

const state = {
	data: null, loading: null, id: store('id', ''), tab: store('tab', 'harmony'), auto: store('auto', true),
	edit: null, editId: null, saveTimer: 0, renderTimer: 0, saving: Promise.resolve(), poll: 0, lastChanges: -1, error: '',
};
let ui = {};
let liveCtx = null;

async function api(method, url, body) {
	const response = await fetch(url, { method, headers: body ? { 'content-type': 'application/json' } : {}, body: body ? JSON.stringify(body) : undefined });
	const out = await response.json().catch(() => ({}));
	if (!response.ok) throw new Error(out.error || `${method} ${url} failed (${response.status})`);
	return out;
}

async function load() {
	state.data = await api('GET', '/api/music');
	state.lastChanges = state.data.queue.changes;
	return state.data;
}

function absorb(result) {
	// A piece's fresh state, as the API sends it back after any change.
	const piece = state.data.pieces[result.id];
	piece.live = result.live;
	piece.draft = result.draft;
	state.data.score.tracks[result.id] = result.spec;
	state.data.queue = result.queue;
	state.lastChanges = result.queue.changes;
}

// --- music arithmetic -------------------------------------------------------------------------

const effective = (spec) => ({ ...DEFAULTS, ...spec });

function chordOf(spec, degree) {
	const s = effective(spec);
	const scale = MODES[s.mode] || MODES.aeolian;
	const at = (d) => scale[((d % 7) + 7) % 7] + 12 * Math.floor(d / 7);
	const root = at(degree), third = at(degree + 2) - root, fifth = at(degree + 4) - root;
	const quality = third === 4 && fifth === 7 ? 'maj' : third === 3 && fifth === 7 ? 'min' : third === 3 && fifth === 6 ? 'dim' : third === 4 && fifth === 8 ? 'aug' : 'sus';
	const numeral = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'][((degree % 7) + 7) % 7];
	const roman = (quality === 'min' || quality === 'dim' ? numeral.toLowerCase() : numeral) + (quality === 'dim' ? '°' : quality === 'aug' ? '+' : '') + (s.sevenths ? '7' : '');
	const name = KEYS[(PITCH[s.key] + root) % 12] + ({ maj: '', min: 'm', dim: '°', aug: '+', sus: 'sus' }[quality]) + (s.sevenths ? '7' : '');
	const tones = [0, 2, 4].map((k) => (PITCH[s.key] + at(degree + k)) % 12);
	return { roman, name, quality, tones };
}
const QUALITY_COLORS = { maj: '#e2b23a', min: '#5b8bd9', dim: '#c0463c', aug: '#a77be0', sus: '#7f8896' };

function differences(a, b) {
	const x = effective(a), y = effective(b);
	return Object.keys(FIELD_NAMES).filter((k) => JSON.stringify(x[k]) !== JSON.stringify(y[k]));
}

const seconds = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const lengthOf = (spec) => { const s = effective(spec); return 24 * s.meter * 60 / s.bpm; };
const ago = (iso) => {
	if (!iso) return '';
	const s = (Date.now() - Date.parse(iso)) / 1000;
	if (s < 60) return 'just now';
	if (s < 3600) return `${Math.round(s / 60)} min ago`;
	if (s < 86400) return `${Math.round(s / 3600)} h ago`;
	return new Date(iso).toLocaleDateString();
};

// --- the player: five buffers started on one sample, gains moved like the game moves them ------

const player = {
	ctx: null, master: null, dry: null, wet: null, room: true, gains: [], sources: [], buffers: [], key: '',
	id: '', version: 'live', playing: false, startAt: 0, offset: 0, duration: 0, mood: store('mood', 'explore'), muted: new Set(), cache: new Map(), loadToken: 0,

	ensure() {
		if (this.ctx) return;
		this.ctx = new AudioContext();
		this.master = this.ctx.createGain();
		this.master.gain.value = 0.9;
		this.dry = this.ctx.createGain();
		this.wet = this.ctx.createGain();
		// The game's Music bus: a long, dark room, wet at a fifth.
		const verb = this.ctx.createConvolver();
		const rate = this.ctx.sampleRate, length = Math.round(rate * 2.4);
		const ir = this.ctx.createBuffer(2, length, rate);
		for (let ch = 0; ch < 2; ch++) {
			const data = ir.getChannelData(ch);
			let lp = 0;
			for (let i = 0; i < length; i++) { lp += 0.35 * ((Math.random() * 2 - 1) - lp); data[i] = lp * Math.pow(1 - i / length, 3.2); }
		}
		verb.buffer = ir;
		this.master.connect(this.dry).connect(this.ctx.destination);
		this.master.connect(verb).connect(this.wet).connect(this.ctx.destination);
		this.setRoom(this.room);
		for (let i = 0; i < LAYERS.length; i++) { const g = this.ctx.createGain(); g.connect(this.master); this.gains.push(g); }
		this.applyLevels(true);
	},
	setRoom(on) {
		this.room = on;
		if (this.ctx) { this.wet.gain.value = on ? 0.22 : 0; this.dry.gain.value = 1; }
	},
	levels() {
		const preset = (MOODS.find((m) => m[0] === this.mood) || MOODS[2])[2];
		return preset.map((v, i) => (this.muted.has(i) ? 0 : v));
	},
	applyLevels(now = false) {
		if (!this.ctx) return;
		const levels = this.levels();
		this.gains.forEach((g, i) => {
			// Up quickly, down slowly, as DeepMusic does (here a quarter of its time, to hear it).
			const target = levels[i] ?? 0;
			g.gain.cancelScheduledValues(this.ctx.currentTime);
			if (now) g.gain.value = target;
			else g.gain.setTargetAtTime(target, this.ctx.currentTime, target > g.gain.value ? 0.12 : 0.35);
		});
	},
	position() {
		if (!this.duration) return 0;
		const raw = this.playing ? this.ctx.currentTime - this.startAt + this.offset : this.offset;
		return ((raw % this.duration) + this.duration) % this.duration;
	},
	async decode(url) {
		if (!this.cache.has(url)) {
			this.cache.set(url, fetch(url).then((r) => { if (!r.ok) throw new Error(`${url}: ${r.status}`); return r.arrayBuffer(); }).then((b) => this.ctx.decodeAudioData(b)));
			if (this.cache.size > 40) this.cache.delete(this.cache.keys().next().value);
		}
		return this.cache.get(url);
	},
	// Point the player at a version of a piece. Keeps the place in the loop, as a fraction, so
	// switching live and draft (or a draft re-rendering) carries on from the same bar.
	async load(id, version, layers) {
		this.ensure();
		const key = `${id}|${version}|${layers.map((l) => l.url).join()}`;
		if (key === this.key) return;
		const token = ++this.loadToken;
		const fraction = this.id === id && this.duration ? this.position() / this.duration : 0;
		const wasPlaying = this.playing;
		const buffers = await Promise.all(layers.map((l) => this.decode(l.url)));
		if (token !== this.loadToken) return;
		this.stopSources();
		this.key = key;
		this.id = id;
		this.version = version;
		this.buffers = buffers;
		this.duration = buffers.length ? Math.max(...buffers.map((b) => b.duration)) : 0;
		this.offset = fraction * this.duration;
		if (wasPlaying) this.start();
	},
	unload() { this.stopSources(); this.playing = false; this.buffers = []; this.key = ''; this.duration = 0; this.offset = 0; },
	start() {
		if (!this.buffers.length) return;
		this.ctx.resume();
		const when = this.ctx.currentTime + 0.05;
		this.sources = this.buffers.map((buffer, i) => {
			const src = this.ctx.createBufferSource();
			src.buffer = buffer;
			src.loop = true;
			src.connect(this.gains[i]);
			src.start(when, this.offset % buffer.duration);
			return src;
		});
		this.startAt = when;
		this.playing = true;
	},
	stopSources() {
		if (this.playing) this.offset = this.position();
		for (const s of this.sources) { try { s.stop(); } catch { /* never started */ } }
		this.sources = [];
	},
	toggle() {
		this.ensure();
		if (this.playing) { this.stopSources(); this.playing = false; } else this.start();
	},
	seek(fraction) {
		const was = this.playing;
		this.stopSources();
		this.playing = false;
		this.offset = fraction * this.duration;
		if (was) this.start();
	},
};

// --- the page ---------------------------------------------------------------------------------

export default {
	id: 'music', label: 'Soundtrack', blurb: 'Edit, render, compare and adopt the pieces; MIDI out',
	count: () => (state.data ? Object.keys(state.data.score.tracks).length : ''),
	icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/></svg>',
	render(root, route, ctx) {
		liveCtx = ctx;
		root.classList.add('mu-view');
		if (!state.data) {
			root.append(h('div', { class: 'loading' }, h('span', { class: 'spinner' }), 'Reading the score…'));
			(state.loading ||= load()).then(() => ctx.alive() && ctx.rerender()).catch((error) => {
				state.loading = null;
				if (!ctx.alive()) return;
				clear(root).append(h('div', { class: 'error' }, h('b', {}, 'The soundtrack API did not answer. '), String(error.message || error),
					h('p', {}, 'Restart the server after ', h('code', {}, 'npm install'), ' in ', h('code', {}, 'tools/data-browser'), '.')));
			});
			return;
		}
		const tracks = state.data.score.tracks;
		let id = route.key && tracks[route.key] ? route.key : (tracks[state.id] ? state.id : Object.keys(tracks)[0]);
		if (id !== state.editId) selectPiece(id);
		keep('id', id);
		state.id = id;
		ui = { root };
		root.append(topBar(ctx));
		const left = h('div', { class: 'mu-left' });
		const right = h('div', { class: 'mu-right' });
		root.append(h('div', { class: 'mu-grid' }, left, right));
		ui.spec = h('div', { class: 'mu-spec' });
		left.append(ui.spec);
		ui.player = h('div');
		ui.versions = h('div');
		ui.roll = h('div', { class: 'mu-roll-wrap' });
		right.append(ui.player, ui.versions, ui.roll);
		paintSpec();
		paintVersions();
		paintPlayer();
		paintRoll();
		pointPlayer(state.resume);
		state.resume = false;
		startPolling();
	},
};

function selectPiece(id) {
	flushSave();
	state.editId = id;
	const piece = state.data.pieces[id];
	state.edit = structuredClone(piece.draft ? piece.draft.spec : state.data.score.tracks[id]);
	state.error = '';
	if (player.id !== id) { state.resume = player.playing; player.unload(); player.id = id; }
}

function piece() { return state.data.pieces[state.id]; }
function liveSpec() { return state.data.score.tracks[state.id]; }

// --- top: where, which piece, the queue -------------------------------------------------------

function placeName(key) { return key === 'HOME' ? 'Workshop' : (C.mine(key).name || C.title(key)); }

function topBar(ctx) {
	const places = state.data.score.places;
	const here = Object.keys(places).find((p) => places[p].tracks.includes(state.id)) || Object.keys(places)[0];
	const pieces = places[here].tracks.map((id) => {
		const p = state.data.pieces[id];
		const dot = p.draft ? (p.draft.stale ? 'var(--warn)' : 'var(--accent)') : (p.live.complete ? 'var(--good)' : 'var(--bad)');
		return h('button', { type: 'button', class: `mu-piece${id === state.id ? ' is-active' : ''}`, title: p.draft ? 'Has a draft' : (p.live.complete ? 'Baked' : 'Not baked yet'), onClick: () => ctx.navigate('music', id) },
			h('i', { class: 'dot', style: { background: dot, width: '7px', height: '7px' } }), state.data.score.tracks[id].name || id, places[here].tracks[0] === id ? h('span', { class: 'mu-default' }, 'default') : null);
	});
	ui.queue = h('div', { class: 'mu-queue' });
	paintQueue();
	return h('div', { class: 'mu-top' },
		segmented(Object.keys(places).map((p) => [p, placeName(p), places[p].about]), here, (p) => ctx.navigate('music', places[p].tracks[0]), { class: 'seg small' }),
		h('div', { class: 'row tight' }, pieces),
		ui.queue);
}

function paintQueue() {
	if (!ui.queue) return;
	const q = state.data.queue;
	const name = (id) => state.data.score.tracks[id]?.name || id;
	append(clear(ui.queue), [
		!state.data.godot ? chip('Godot not found: set GODOT_BIN', { class: 'bad', title: 'Rendering needs Godot 4.7.2 (the console build on Windows)' }) : null,
		q.running ? h('span', { class: 'mu-busy' }, h('span', { class: 'spinner' }), `Rendering ${name(q.running)}`, q.waiting.length ? h('span', { class: 'muted' }, ` · ${q.waiting.length} queued`) : null) : null,
		!q.running && q.last && !q.last.ok ? chip(`Render of ${name(q.last.id)} failed`, { class: 'bad', title: q.last.error }) : null,
		h('label', { class: 'checkbox', title: 'Queue a render a moment after every change' }, h('input', { type: 'checkbox', checked: state.auto ? true : null, onChange: (e) => { state.auto = e.target.checked; keep('auto', state.auto); if (state.auto) scheduleRender(); } }), 'Render as I edit')]);
}

// --- the spec editor --------------------------------------------------------------------------

function change(key, value) {
	state.edit[key] = value;
	paintSpec();
	scheduleSave();
}

function scheduleSave() {
	clearTimeout(state.saveTimer);
	state.saveTimer = setTimeout(flushSave, 250);
	markDraftEdited();
}

function flushSave() {
	if (!state.saveTimer) return state.saving;
	clearTimeout(state.saveTimer);
	state.saveTimer = 0;
	const id = state.editId, spec = structuredClone(state.edit);
	state.saving = state.saving.then(() => api('PUT', `/api/music/${id}/draft`, spec)).then((result) => {
		absorb(result);
		if (id === state.id) { paintVersions(); if (state.auto) scheduleRender(); }
	}).catch((error) => { state.error = String(error.message || error); paintVersions(); });
	return state.saving;
}

function scheduleRender() {
	clearTimeout(state.renderTimer);
	const id = state.id;
	state.renderTimer = setTimeout(() => {
		const draft = state.data.pieces[id].draft;
		if (draft && draft.stale) queueRender(id);
	}, 900);
}

async function queueRender(id = state.id) {
	try {
		await flushSave();
		absorb(await api('POST', `/api/music/${id}/render`));
		startPolling();
	} catch (error) { state.error = String(error.message || error); }
	paintVersions();
	paintQueue();
}

function markDraftEdited() {
	// Show "edited" at once rather than after the save comes back.
	const p = piece();
	if (p.draft) p.draft.stale = true;
	else p.draft = { spec: state.edit, layers: [], rendered: false, stale: true };
	p.draft.spec = state.edit;
	paintVersions();
}

function paintSpec() {
	if (!ui.spec) return;
	const s = effective(state.edit);
	const tabs = h('div', { class: 'tabs' }, [['harmony', 'Harmony'], ['voices', 'Voices & mix']].map(([k, label]) =>
		h('button', { type: 'button', class: `tab${state.tab === k ? ' is-active' : ''}`, onClick: () => { state.tab = k; keep('tab', k); paintSpec(); } }, label)));
	const nameInput = h('input', { class: 'input mu-name', value: s.name || '', onChange: (e) => change('name', e.target.value.trim() || state.editId) });
	const body = state.tab === 'harmony' ? harmonyPanel(s) : voicesPanel(s);
	clear(ui.spec).append(card(null, h('div', { class: 'col', style: { gap: '12px' } },
		h('div', { class: 'row between' }, nameInput, h('span', { class: 'tiny muted mono' }, state.editId)), tabs, body), { class: 'mu-spec-card' }));
}

function harmonyPanel(s) {
	const scale = (MODES[s.mode] || MODES.aeolian).map((i) => (PITCH[s.key] + i) % 12);
	return h('div', { class: 'col', style: { gap: '14px' } },
		h('div', { class: 'mu-field' }, h('span', { class: 'field-label' }, 'Key'), keyboard(s.key, scale, (k) => change('key', k))),
		h('div', { class: 'mu-field' }, h('span', { class: 'field-label' }, 'Mode ', h('span', { class: 'mu-hint' }, MODE_MOOD[s.mode] || '')),
			h('div', { class: 'mu-modes' }, Object.keys(MODES).map((m) => h('button', { type: 'button', class: `mu-mode${m === s.mode ? ' is-active' : ''}`, title: MODE_MOOD[m], onClick: () => change('mode', m) },
				h('b', {}, MODE_NAMES[m]), h('span', {}, steps(MODES[m])))))),
		h('div', { class: 'row', style: { alignItems: 'flex-end', gap: '16px' } },
			field('Tempo', h('div', { class: 'row tight' },
				h('input', { type: 'range', min: 50, max: 150, step: 1, value: s.bpm, class: 'mu-range', onInput: (e) => { e.target.nextSibling.value = e.target.value; }, onChange: (e) => change('bpm', Number(e.target.value)) }),
				h('input', { class: 'input', type: 'number', min: 40, max: 200, value: s.bpm, style: { width: '62px' }, onChange: (e) => change('bpm', Math.max(40, Math.min(200, Math.round(Number(e.target.value) || 90)))) }),
				h('span', { class: 'tiny muted' }, `bpm · ${seconds(lengthOf(s))} loop`))),
			field('Metre', segmented([[3, '3/4'], [4, '4/4']], s.meter, (v) => change('meter', Number(v)))),
			field('Seed', h('div', { class: 'row tight' },
				h('input', { class: 'input', type: 'number', min: 1, value: s.seed, style: { width: '70px' }, onChange: (e) => change('seed', Math.max(1, Math.round(Number(e.target.value) || 1))) }),
				h('button', { type: 'button', class: 'btn', title: 'A new tune over the same chords', onClick: () => change('seed', 1 + Math.floor(Math.random() * 9999)) }, '⚄ New tune')), 'The tune, the drum feel and every small variation are drawn from the seed')),
		h('div', { class: 'mu-field' }, h('span', { class: 'field-label' }, 'Chords ', h('span', { class: 'mu-hint' }, 'two bars each · click to change')),
			chordRow('Verse', s, 'chords', 0), chordRow('Bridge', s, 'bridge', 8)));
}

function steps(intervals) {
	return [...intervals, 12].slice(1).map((v, i) => ({ 1: 'H', 2: 'W', 3: 'W+' }[v - intervals[i]] || '?')).join(' ');
}

function keyboard(value, scale, onPick) {
	// One octave: click a key to make it the piece's key; dots mark the notes of the mode.
	const whites = [0, 2, 4, 5, 7, 9, 11], blacks = { 1: 0, 3: 1, 6: 3, 8: 4, 10: 5 };
	const wrap = h('div', { class: 'mu-keys' });
	for (const pc of whites) wrap.append(keyEl(pc, 'white', null));
	for (const [pc, after] of Object.entries(blacks)) wrap.append(keyEl(Number(pc), 'black', after));
	function keyEl(pc, kind, after) {
		const isKey = PITCH[value] === pc, inScale = scale.includes(pc);
		return h('button', { type: 'button', class: `mu-key ${kind}${isKey ? ' is-key' : ''}`, title: `${KEYS[pc]}${inScale ? ' · in the scale' : ''}`,
			style: kind === 'black' ? { left: `calc(${(after + 1) * (100 / 7)}% - 11px)` } : null, onClick: () => onPick(KEYS[pc]) },
		inScale ? h('i', { class: 'mu-key-dot' }) : null, h('span', {}, KEYS[pc]));
	}
	return wrap;
}

let openChord = null;
function chordRow(label, s, part, firstSlot) {
	const list = s[part].slice();
	const want = part === 'chords' ? 8 : 4;
	while (list.length < want) list.push(list[list.length % Math.max(1, list.length)] ?? 0);
	const row = h('div', { class: 'mu-chords' }, h('span', { class: 'mu-chords-label' }, label));
	list.slice(0, want).forEach((degree, i) => {
		const c = chordOf(s, degree);
		const slot = `${part}:${i}`;
		const tile = h('button', { type: 'button', class: `mu-chord${openChord === slot ? ' is-open' : ''}`, style: { '--q': QUALITY_COLORS[c.quality] }, title: `Bars ${(firstSlot + i) * 2 + 1}–${(firstSlot + i) * 2 + 2}`,
			onClick: () => { openChord = openChord === slot ? null : slot; paintSpec(); } },
		h('span', { class: 'mu-plan' }, PLAN[firstSlot + i]), h('b', {}, c.roman), h('span', { class: 'mu-chord-name' }, c.name));
		row.append(tile);
	});
	if (openChord && openChord.startsWith(part + ':')) {
		const i = Number(openChord.split(':')[1]);
		row.append(h('div', { class: 'mu-chord-pick' }, [0, 1, 2, 3, 4, 5, 6].map((d) => {
			const c = chordOf(s, d);
			return h('button', { type: 'button', class: `mu-chord small${d === list[i] ? ' is-active' : ''}`, style: { '--q': QUALITY_COLORS[c.quality] },
				onClick: () => { const next = list.slice(0, want); next[i] = d; openChord = null; change(part, next); } }, h('b', {}, c.roman), h('span', { class: 'mu-chord-name' }, c.name));
		})));
	}
	return row;
}

function voicesPanel(s) {
	const pick = (key, options) => select(options, s[key], (v) => change(key, v), { class: 'select', style: { width: '100%' } });
	return h('div', { class: 'col', style: { gap: '14px' } },
		h('div', { class: 'mu-voices' },
			field('Pad', pick('pad', VOICES.pad), 'The held chords of the bed'),
			field('Bass', pick('bass', VOICES.bass)),
			field('Bass line', segmented([['walk', 'Walk'], ['pedal', 'Pedal'], ['syncop', 'Syncop.']], s.bass_style, (v) => change('bass_style', v), { class: 'seg small' })),
			field('Lead', pick('lead', VOICES.lead), 'The tune'),
			field('Lead octave', segmented([[0, 'Low'], [1, 'High']], Number(s.lead_octave), (v) => change('lead_octave', Number(v)), { class: 'seg small' })),
			field('Kit', pick('kit', VOICES.kit), 'Which drums play each part'),
			field('Arpeggio', pick('arp', VOICES.lead), 'The fight layer’s running arpeggio'),
			field('Arp rate', segmented([[1, '16th'], [2, '8th'], [3, 'Dot. 8th'], [4, 'Qtr']], Number(s.arp_rate), (v) => change('arp_rate', Number(v)), { class: 'seg small' }))),
		h('div', { class: 'row', style: { alignItems: 'flex-end', gap: '16px' } },
			field('Echo on the tune', h('div', { class: 'row tight' },
				h('input', { type: 'range', min: 0, max: 0.6, step: 0.01, value: s.echo, class: 'mu-range', onInput: (e) => { e.target.nextSibling.textContent = Number(e.target.value).toFixed(2); }, onChange: (e) => change('echo', Number(e.target.value)) }),
				h('span', { class: 'mono small', style: { width: '34px' } }, Number(s.echo).toFixed(2)))),
			field('Layers', segmented([[3, '3: walk only'], [5, '5: with fights']], Number(s.layers) >= 5 ? 5 : 3, (v) => change('layers', Number(v)), { class: 'seg small' }), 'The workshop never fights, so it is written in three')),
		h('div', { class: 'row' },
			h('label', { class: 'checkbox' }, h('input', { type: 'checkbox', checked: s.drone ? true : null, onChange: (e) => change('drone', e.target.checked) }), 'Drone under the bed'),
			h('label', { class: 'checkbox' }, h('input', { type: 'checkbox', checked: s.sevenths ? true : null, onChange: (e) => change('sevenths', e.target.checked) }), 'Sevenths in the pads')),
		h('div', { class: 'mu-layer-key' }, LAYERS.map((name, i) => h('div', { class: 'row tight' }, h('i', { class: 'dot', style: { background: LAYER_COLORS[i] } }), h('b', { class: 'small' }, name), h('span', { class: 'tiny muted' }, LAYER_WORDS[i])))));
}

// --- versions: live, draft, and what to do with them ------------------------------------------

function paintVersions() {
	if (!ui.versions) return;
	const p = piece();
	const q = state.data.queue;
	const live = p.live, draft = p.draft;
	const rendering = q.running === state.id, queued = q.waiting.includes(state.id);
	const changed = draft ? differences(draft.spec, liveSpec()) : [];
	const hand = live.layers.filter((l) => l.hand);

	const liveTile = h('div', { class: `mu-version${player.version === 'live' ? ' is-playing' : ''}` },
		h('div', { class: 'row between' }, h('b', {}, 'Live'), live.complete ? chip('baked', { color: 'var(--good)' }) : chip('not baked', { class: 'bad' })),
		h('div', { class: 'tiny muted' }, live.bakedAt ? `Baked ${ago(live.bakedAt)}` : 'Not baked yet: render a draft and adopt it'),
		hand.length ? h('div', { class: 'tiny', style: { color: 'var(--warn)' } }, `Replaced by hand: ${hand.map((l) => l.name).join(', ')}`) : null,
		live.baked && !live.matchesScore && !hand.length ? h('div', { class: 'tiny', style: { color: 'var(--warn)' } }, 'The score has changed since this was baked') : null,
		h('div', { class: 'row tight' },
			h('button', { type: 'button', class: `btn${player.version === 'live' ? ' is-active' : ''}`, disabled: live.complete ? null : true, onClick: () => listen('live') }, '▶ Listen'),
			live.hasNotes ? h('a', { class: 'btn mu-link', href: `/api/music/${state.id}/midi?v=live`, download: `${state.id}.mid` }, 'MIDI') : null));

	let status, statusColor = 'var(--muted)';
	if (!draft) status = 'No changes. Edit the spec to start a draft.';
	else if (rendering) { status = 'Rendering…'; statusColor = 'var(--accent)'; }
	else if (queued) { status = 'Queued to render'; statusColor = 'var(--accent)'; }
	else if (draft.error && draft.stale) { status = 'Render failed'; statusColor = 'var(--bad)'; }
	else if (draft.stale) { status = draft.rendered ? 'Edited since it was rendered' : 'Edited, not rendered'; statusColor = 'var(--warn)'; }
	else { status = `Rendered ${ago(draft.renderedAt)}${draft.renderMs ? ` in ${(draft.renderMs / 1000).toFixed(1)} s` : ''}`; statusColor = 'var(--good)'; }

	const draftTile = h('div', { class: `mu-version${player.version === 'draft' ? ' is-playing' : ''}${draft ? '' : ' is-empty'}` },
		h('div', { class: 'row between' }, h('b', {}, 'Draft'), rendering || queued ? h('span', { class: 'spinner' }) : null),
		h('div', { class: 'tiny', style: { color: statusColor } }, status),
		draft && draft.error && draft.stale ? h('div', { class: 'tiny mu-error', title: draft.error }, draft.error.split('\n')[0]) : null,
		draft ? h('div', { class: 'row tight', style: { flexWrap: 'wrap' } }, changed.length ? changed.map((k) => h('span', { class: 'mu-diff' }, FIELD_NAMES[k])) : h('span', { class: 'tiny muted' }, 'Same as live')) : null,
		h('div', { class: 'row tight' },
			h('button', { type: 'button', class: `btn${player.version === 'draft' ? ' is-active' : ''}`, disabled: draft && draft.layers.length ? null : true, onClick: () => listen('draft') }, '▶ Listen'),
			draft && draft.layers.length ? h('a', { class: 'btn mu-link', href: `/api/music/${state.id}/midi?v=draft`, download: `${state.id}_draft.mid` }, 'MIDI') : null));

	const canAdopt = draft && draft.rendered && !draft.stale && !rendering && !queued;
	const actions = h('div', { class: 'mu-actions' },
		h('button', { type: 'button', class: 'btn', disabled: rendering || queued || !state.data.godot ? true : null, onClick: () => queueRender() }, draft ? 'Render draft' : 'Render a draft of live'),
		h('button', { type: 'button', class: 'btn mu-primary', disabled: canAdopt ? null : true, title: hand.length ? `Adopting replaces the hand-made ${hand.map((l) => l.name).join(', ')}` : 'Bake the draft over the live files and write its spec to the score', onClick: adopt }, 'Adopt draft → live'),
		h('button', { type: 'button', class: 'btn', disabled: draft ? null : true, title: 'Throw the draft away; the live version stays', onClick: discard }, 'Discard draft'));

	const confirm = state.confirm ? h('div', { class: 'note warn small' }, state.confirm.text, ' ',
		h('button', { type: 'button', class: 'btn', onClick: () => { const go = state.confirm.go; state.confirm = null; go(); } }, state.confirm.yes),
		' ', h('button', { type: 'button', class: 'btn', onClick: () => { state.confirm = null; paintVersions(); } }, 'Cancel')) : null;

	append(clear(ui.versions), [card(null, h('div', { class: 'col' },
		h('div', { class: 'mu-versions' }, liveTile, draftTile, actions), confirm,
		state.error ? h('div', { class: 'error small' }, state.error) : null))]);
}

function adopt() {
	const hand = piece().live.layers.filter((l) => l.hand);
	const go = async () => {
		try {
			state.error = '';
			absorb(await api('POST', `/api/music/${state.id}/adopt`));
			state.edit = structuredClone(state.data.score.tracks[state.id]);
			player.version = 'live';
		} catch (error) { state.error = String(error.message || error); }
		liveCtx.rerender();
	};
	if (hand.length) {
		state.confirm = { text: `The live ${hand.map((l) => l.name).join(', ')} ${hand.length > 1 ? 'were' : 'was'} replaced by hand. Adopting overwrites ${hand.length > 1 ? 'them' : 'it'}.`, yes: 'Adopt anyway', go };
		paintVersions();
	} else go();
}

function discard() {
	state.confirm = { text: 'Discard this draft? The spec edits and its render are deleted; the live version stays.', yes: 'Discard', go: async () => {
		try {
			clearTimeout(state.saveTimer);
			state.saveTimer = 0;
			await state.saving;
			absorb(await api('DELETE', `/api/music/${state.id}/draft`));
			state.edit = structuredClone(state.data.score.tracks[state.id]);
			if (player.version === 'draft') player.version = 'live';
		} catch (error) { state.error = String(error.message || error); }
		liveCtx.rerender();
	} };
	paintVersions();
}

function listen(version) {
	player.version = version;
	pointPlayer(true);
	paintVersions();
}

// Load whichever version the player is on (falling back to the other if it has no audio).
async function pointPlayer(andPlay = false) {
	const p = piece();
	let version = player.version;
	if (version === 'draft' && !(p.draft && p.draft.layers.length)) version = 'live';
	if (version === 'live' && !p.live.complete && p.draft && p.draft.layers.length) version = 'draft';
	const layers = version === 'draft' ? p.draft?.layers || [] : p.live.layers;
	if (!layers.length) { player.unload(); paintPlayer(); return; }
	if (!player.ctx && !andPlay) { player.version = version; paintPlayer(); return; } // no AudioContext before a click
	try {
		await player.load(state.id, version, layers);
		if (andPlay && !player.playing) player.toggle();
	} catch (error) { state.error = String(error.message || error); paintVersions(); }
	paintPlayer();
	paintRoll();
}

// --- the player and the roll ------------------------------------------------------------------

function paintPlayer() {
	if (!ui.player) return;
	const p = piece();
	const version = player.version;
	const spec = version === 'draft' && p.draft ? p.draft.spec : liveSpec();
	const count = Math.min(LAYERS.length, Number(effective(spec).layers) >= 5 ? 5 : 3);
	const levels = player.levels();
	ui.time = h('span', { class: 'mono small mu-time' }, '0:00');
	const transport = h('div', { class: 'row', style: { gap: '12px' } },
		h('button', { type: 'button', class: 'mu-play', 'aria-label': player.playing ? 'Pause' : 'Play', onClick: async () => { if (!player.buffers.length || player.id !== state.id) await pointPlayer(true); else player.toggle(); paintPlayer(); } },
			player.playing ? '❚❚' : '▶'),
		h('div', { class: 'col', style: { gap: '0' } }, h('b', {}, `${effective(spec).name || state.id}`), h('span', { class: 'tiny muted' }, `${version === 'draft' ? 'Draft' : 'Live'} · `, ui.time)),
		h('div', { class: 'fill' }),
		field('Mood', segmented(MOODS.map(([k, label]) => [k, label]), player.mood, (m) => { player.mood = m; keep('mood', m); player.applyLevels(); paintPlayer(); }, { class: 'seg small' }), 'Each mood sets the layers to the levels the game uses there'),
		h('label', { class: 'checkbox', title: 'The game plays music through a long, dark room' }, h('input', { type: 'checkbox', checked: player.room ? true : null, onChange: (e) => player.setRoom(e.target.checked) }), 'Room'));
	const mixer = h('div', { class: 'mu-mixer' }, LAYERS.map((name, i) => {
		const off = i >= count;
		const muted = player.muted.has(i);
		return h('button', { type: 'button', class: `mu-strip${muted ? ' is-muted' : ''}${off ? ' is-off' : ''}`, disabled: off ? true : null, title: off ? 'This piece is written without it' : `${LAYER_WORDS[i]} · click to mute`,
			onClick: () => { if (muted) player.muted.delete(i); else player.muted.add(i); player.applyLevels(); paintPlayer(); paintRoll(); } },
		h('i', { class: 'dot', style: { background: LAYER_COLORS[i] } }), h('span', {}, name),
		h('span', { class: 'mu-level' }, h('span', { style: { width: `${Math.round((off ? 0 : levels[i]) * 100)}%`, background: LAYER_COLORS[i] } })));
	}));
	clear(ui.player).append(card(null, h('div', { class: 'col' }, transport, mixer)));
}

const rollCache = new Map();
async function notesFor(id, version) {
	const p = state.data.pieces[id];
	const stamp = version === 'draft' ? p.draft?.renderedAt : p.live.bakedAt;
	if (!stamp) return null;
	const key = `${id}|${version}|${stamp}`;
	if (!rollCache.has(key)) rollCache.set(key, api('GET', `/api/music/${id}/notes?v=${version}`).catch(() => null));
	return rollCache.get(key);
}

let rollToken = 0;
let rollObserver = null;
async function paintRoll() {
	if (!ui.roll) return;
	const token = ++rollToken;
	const p = piece();
	let version = player.version;
	if (version === 'draft' && !(p.draft && p.draft.layers.length)) version = 'live';
	const notes = await notesFor(state.id, version) || (version === 'live' ? await notesFor(state.id, 'draft') : null);
	if (token !== rollToken || !ui.roll) return;
	const canvas = h('canvas', { class: 'mu-roll' });
	const head = h('canvas', { class: 'mu-roll-head' });
	const box = h('div', { class: 'mu-roll-box', onClick: (e) => {
		if (!player.duration) return;
		const r = box.getBoundingClientRect();
		player.seek(Math.max(0, Math.min(1, (e.clientX - r.left - ROLL_PAD) / (r.width - ROLL_PAD))));
	} }, canvas, head);
	const draftSpec = p.draft ? p.draft.spec : null;
	const shownSpec = version === 'draft' && draftSpec ? draftSpec : liveSpec();
	clear(ui.roll).append(card(`Notes · ${version}`, notes ? box : h('div', { class: 'empty' }, 'Nothing rendered to show yet.'), {
		meta: notes ? `${notes.notes.length} notes · ${notes.bars} bars of ${notes.meter}/4 · ${effective(shownSpec).bpm} bpm` : '',
		tools: h('span', { class: 'tools tiny muted' }, 'click to jump'), class: 'mu-roll-card' }));
	if (!notes) return;
	const draw = () => drawRoll(canvas, notes, shownSpec);
	rollObserver?.disconnect();
	rollObserver = new ResizeObserver(draw);
	rollObserver.observe(box);
	animateHead(head, notes);
}

const ROLL_PAD = 34;
function drawRoll(canvas, notes, spec) {
	const box = canvas.parentElement;
	if (!box || !box.isConnected) return;
	const w = box.clientWidth, hgt = box.clientHeight;
	const dpr = window.devicePixelRatio || 1;
	canvas.width = w * dpr; canvas.height = hgt * dpr;
	canvas.style.width = `${w}px`; canvas.style.height = `${hgt}px`;
	const g = canvas.getContext('2d');
	g.scale(dpr, dpr);
	const css = getComputedStyle(document.documentElement);
	const stepsBar = notes.steps_bar, totalSteps = notes.bars * stepsBar;
	const top = 30, drumH = 64, bottom = hgt - 4;
	const pitched = notes.notes.filter((n) => !n[1].startsWith('drum:'));
	let lo = Math.min(...pitched.map((n) => n[2])), hi = Math.max(...pitched.map((n) => n[2]));
	lo -= 1; hi += 1;
	const pitchBottom = bottom - drumH - 6;
	const rowH = (pitchBottom - top) / (hi - lo + 1);
	const x = (step) => ROLL_PAD + (step / totalSteps) * (w - ROLL_PAD);
	const y = (midi) => top + (hi - midi) * rowH;
	// Phrases: shaded alternately, named by the plan and their chord.
	for (let slot = 0; slot < PLAN.length; slot++) {
		const x0 = x(slot * 2 * stepsBar), x1 = x((slot + 1) * 2 * stepsBar);
		g.fillStyle = slot % 2 ? 'rgba(255,255,255,0.025)' : 'rgba(255,255,255,0.0)';
		g.fillRect(x0, 0, x1 - x0, bottom);
		const c = chordOf(spec, notes.chords[slot]);
		g.fillStyle = css.getPropertyValue('--muted');
		g.font = '10px system-ui';
		g.fillText(PLAN[slot], x0 + 4, 11);
		g.fillStyle = QUALITY_COLORS[c.quality];
		g.font = '600 11px system-ui';
		g.fillText(c.name, x0 + 4, 24);
	}
	// Octaves of C as a guide, then bar lines.
	g.font = '9px system-ui';
	for (let m = Math.ceil(lo / 12) * 12; m <= hi; m += 12) {
		g.fillStyle = 'rgba(255,255,255,0.06)'; g.fillRect(ROLL_PAD, y(m) + rowH - 1, w - ROLL_PAD, 1);
		g.fillStyle = css.getPropertyValue('--muted'); g.fillText(`C${m / 12 - 1}`, 4, y(m) + rowH - 2);
	}
	for (let bar = 0; bar <= notes.bars; bar++) {
		g.fillStyle = bar % 2 === 0 ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.05)';
		g.fillRect(Math.round(x(bar * stepsBar)), top - 2, 1, bottom - top + 2);
	}
	g.fillStyle = css.getPropertyValue('--muted');
	DRUM_ROWS.forEach((role, i) => g.fillText(role, 4, pitchBottom + 10 + i * (drumH / DRUM_ROWS.length) + 6));
	// The notes: drones as a thread, the rest as bars, brighter the louder.
	for (const [layer, voice, midi, at, len, level] of notes.notes) {
		const muted = player.muted.has(layer);
		g.globalAlpha = (muted ? 0.12 : 1) * Math.min(1, 0.35 + level * 1.1);
		g.fillStyle = LAYER_COLORS[layer];
		if (voice.startsWith('drum:')) {
			const row = Math.max(0, DRUM_ROWS.indexOf(voice.split(':')[1]));
			const yy = pitchBottom + 8 + row * (drumH / DRUM_ROWS.length);
			g.fillRect(x(at), yy, Math.max(2, x(at + 1) - x(at) - 1), drumH / DRUM_ROWS.length - 3);
		} else if (voice === 'drone') {
			g.fillRect(x(at), y(midi) + rowH / 2 - 1, x(at + len) - x(at), 2);
		} else {
			g.fillRect(x(at), y(midi) + 0.5, Math.max(2, x(at + len) - x(at) - 1), Math.max(2, rowH - 1));
		}
	}
	g.globalAlpha = 1;
}

let headFrame = 0;
function animateHead(head, notes) {
	cancelAnimationFrame(headFrame);
	const tick = () => {
		if (!head.isConnected) return;
		const box = head.parentElement;
		const w = box.clientWidth, hgt = box.clientHeight, dpr = window.devicePixelRatio || 1;
		if (head.width !== w * dpr || head.height !== hgt * dpr) { head.width = w * dpr; head.height = hgt * dpr; head.style.width = `${w}px`; head.style.height = `${hgt}px`; }
		const g = head.getContext('2d');
		g.setTransform(dpr, 0, 0, dpr, 0, 0);
		g.clearRect(0, 0, w, hgt);
		if (player.duration && player.id === state.id) {
			const pos = player.position();
			const xx = ROLL_PAD + (pos / player.duration) * (w - ROLL_PAD);
			g.fillStyle = '#f0c95a';
			g.fillRect(xx, 0, 2, hgt);
			if (ui.time) ui.time.textContent = `${seconds(pos)} / ${seconds(player.duration)}`;
		}
		headFrame = requestAnimationFrame(tick);
	};
	headFrame = requestAnimationFrame(tick);
}

// --- keeping up with the render queue ---------------------------------------------------------

function startPolling() {
	if (state.poll) return;
	state.poll = setInterval(async () => {
		if (!liveCtx || !liveCtx.alive() || !document.querySelector('.mu-view')) { clearInterval(state.poll); state.poll = 0; return; }
		let q;
		try { q = await api('GET', '/api/music/status'); } catch { return; }
		const busy = q.running || q.waiting.length;
		if (q.changes !== state.lastChanges) {
			const playingDraftOf = player.version === 'draft' ? state.id : null;
			const fresh = await api('GET', '/api/music');
			// Keep the edit in hand: the server's copy of a draft spec may be a save behind.
			state.data = fresh;
			state.lastChanges = fresh.queue.changes;
			if (state.edit && state.saveTimer) markDraftEdited();
			paintQueue();
			paintVersions();
			if (playingDraftOf === state.id || !player.buffers.length) await pointPlayer();
			paintRoll();
			refreshPieceDots();
		} else {
			state.data.queue = q;
			paintQueue();
		}
		if (!busy) { clearInterval(state.poll); state.poll = 0; }
	}, 1000);
}

function refreshPieceDots() {
	// The dots on the piece buttons say baked / draft / edited; repaint only the top bar.
	const top = ui.root?.querySelector('.mu-top');
	if (top && liveCtx) top.replaceWith(topBar(liveCtx));
}

