// synth.js — Deep Cut sound profiles: the DSP engine, the "today" port and eight proposed
// profiles. Runs as a page script (window.DeepSound) and as a Worker (music is rendered off the
// main thread). Everything is written sample by sample, as the game's own synth is, so each
// profile here is also a statement of what view/audio/synth.gd would need to grow.
(function (root) {
'use strict';
const RATE = (typeof globalThis.DEEP_SOUND_RATE === 'number') ? globalThis.DEEP_SOUND_RATE : 44100;
const TAU = Math.PI * 2;

function rng32(seed) {
  let a = (seed | 0) || 1;
  return function () {
    a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const posmod = (a, n) => ((a % n) + n) % n;

// Partials of struck things (ratios to the fundamental).
const BELL = [1.0, 2.76, 5.4, 8.93];          // a church bell: inharmonic
const CHIME = [1.0, 2.0, 3.01, 4.17];         // a tube or chime: near harmonic
const METAL = [1.0, 1.51, 2.31, 3.37, 4.61];  // struck metal: clangorous
const GLASS = [1.0, 2.32, 4.25, 6.63];        // a tapped wine glass
const TINE = [1.0, 3.95, 9.2];                // a music-box comb tooth
const VIBE = [1.0, 4.0, 10.0];                // a tuned vibraphone bar
const GONG = [1.0, 1.35, 1.72, 2.18, 2.63, 3.3, 4.1];
const PIPE = [1.0, 2.71, 5.15, 8.2];          // a struck steel pipe

const SHAPES = { sine: 0, triangle: 1, saw: 2, square: 3, pulse: 4 };
function polyblep(t, dt) {
  if (t < dt) { t /= dt; return t + t - t * t - 1; }
  if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; }
  return 0;
}
function oscAt(shape, t, dt, pw) {
  switch (shape) {
    case 0: return Math.sin(TAU * t);
    case 1: return 4 * Math.abs(t - 0.5) - 1;
    case 2: return 2 * t - 1 - polyblep(t, dt);
    case 3: { let v = t < 0.5 ? 1 : -1; v += polyblep(t, dt); v -= polyblep((t + 0.5) % 1, dt); return v; }
    default: { const w = pw || 0.25; let v = t < w ? 1 : -1; v += polyblep(t, dt); v -= polyblep((t + 1 - w) % 1, dt); return v; }
  }
}
// The game's struck envelope: linear in, exponential out, landing exactly on silence.
function struck(count, attack, curve) {
  const env = new Float32Array(count);
  const rise = clamp(Math.round(attack * RATE), 1, Math.max(1, count - 1));
  const fall = curve * 2.6, tail = Math.exp(-fall), span = 1 / Math.max(1e-4, 1 - tail);
  const step = Math.exp(-fall / Math.max(1, count - rise));
  let decay = 1 / step;
  for (let i = 0; i < count; i++) {
    if (i < rise) env[i] = i / rise;
    else { decay *= step; env[i] = (decay - tail) * span; }
  }
  return env;
}

class Syn {
  constructor(seconds, seed) {
    this.n = Math.max(8, Math.round(seconds * RATE));
    this.b = new Float32Array(this.n);
    this.rand = rng32(seed || 1);
  }
  range(a, b) { return a + (b - a) * this.rand(); }
  length() { return this.n / RATE; }
  peak() { let p = 0; const b = this.b; for (let i = 0; i < b.length; i++) { const v = Math.abs(b[i]); if (v > p) p = v; } return p; }
  rms() { let s = 0; const b = this.b; for (let i = 0; i < b.length; i++) s += b[i] * b[i]; return Math.sqrt(s / Math.max(1, b.length)); }
  _span(at, dur) {
    const start = Math.max(0, Math.round(at * RATE));
    const count = Math.round(dur * RATE);
    const limit = Math.min(count, this.n - start);
    return { start, count, limit };
  }

  // --- voices (the game's) ----------------------------------------------------------------
  tone(at, dur, f0, f1 = -1, amp = 0.4, shape = 'sine', curve = 3, attack = 0.004, wobble = 0, wobbleHz = 6) {
    const { start, count, limit } = this._span(at, dur);
    if (count <= 0 || limit <= 0) return this;
    const target = f1 > 0 ? f1 : f0;
    const wave = SHAPES[shape] ?? 0;
    const env = struck(count, attack, curve);
    let phase = 0, inc = f0 / RATE;
    const incStep = (target - f0) / RATE / count;
    const wInc = wobbleHz / RATE; let wPhase = 0;
    const b = this.b;
    for (let i = 0; i < limit; i++) {
      let bend = inc;
      if (wobble > 0) { wPhase += wInc; bend += inc * wobble * Math.sin(TAU * wPhase); }
      phase += bend; if (phase >= 1) phase -= 1;
      inc += incStep;
      b[start + i] += oscAt(wave, phase, Math.abs(inc), 0.5) * amp * env[i];
    }
    return this;
  }
  bell(at, dur, hz, amp = 0.4, partials = BELL, curve = 2.6, detune = 0) {
    for (let i = 0; i < partials.length; i++) {
      const ratio = partials[i];
      if (hz * ratio > RATE * 0.45) break;
      const v = amp / (1 + i * 1.35);
      this.tone(at, dur / (1 + i * 0.45), hz * ratio, -1, v, 'sine', curve, 0.002);
      if (detune > 0) this.tone(at, dur / (1 + i * 0.45), hz * ratio * (1 + detune), -1, v * 0.7, 'sine', curve, 0.002);
    }
    return this;
  }
  noise(at, dur, amp = 0.3, cutFrom = 6000, cutTo = 1200, curve = 3, attack = 0.002, highpass = 0) {
    const { start, count, limit } = this._span(at, dur);
    if (count <= 0 || limit <= 0) return this;
    let corner = clamp(TAU * cutFrom / RATE, 0, 1);
    const cornerStep = (clamp(TAU * cutTo / RATE, 0, 1) - corner) / count;
    const hiA = clamp(TAU * highpass / RATE, 0, 1);
    const env = struck(count, attack, curve);
    let low = 0, high = 0;
    const b = this.b, rand = this.rand, cutting = highpass > 0;
    for (let i = 0; i < limit; i++) {
      low += (rand() * 2 - 1 - low) * corner;
      corner += cornerStep;
      let v = low;
      if (cutting) { high += (v - high) * hiA; v -= high; }
      b[start + i] += v * amp * env[i];
    }
    return this;
  }
  voice(at, dur, hz, amp = 0.3, shape = 'saw', attack = 0.05, release = 0.4, unison = 1, detune = 0, cutoff = 0, bloom = 0, vibrato = 0, tremolo = 0) {
    const start = Math.max(0, Math.round(at * RATE));
    const hold = Math.round(dur * RATE);
    const count = hold + Math.round(release * RATE);
    const limit = Math.min(count, this.n - start);
    if (hold <= 0 || limit <= 0) return this;
    const wave = SHAPES[shape] ?? 2;
    const copies = clamp(unison, 1, 5);
    const phases = [], incs = [];
    for (let u = 0; u < copies; u++) {
      const spread = copies === 1 ? 0 : (u / (copies - 1) - 0.5) * 2;
      incs.push(hz * Math.pow(2, spread * detune / 1200) / RATE);
      phases.push(this.rand());
    }
    const rise = clamp(Math.round(attack * RATE), 1, hold);
    const fall = Math.max(1, count - hold);
    const tail = Math.exp(-5), span = 1 / (1 - tail), decayStep = Math.exp(-5 / fall);
    let decay = 1;
    const vibInc = 5.2 / RATE; let vibPhase = 0;
    const tremInc = 6.5 / RATE; let tremPhase = 0;
    const closed = clamp(TAU * cutoff / RATE, 0, 1), filtered = cutoff > 0;
    let lowA = 0, lowB = 0;
    const each = amp / Math.sqrt(copies);
    const b = this.b;
    for (let i = 0; i < limit; i++) {
      let env;
      if (i < rise) env = i / rise; else if (i < hold) env = 1; else { decay *= decayStep; env = (decay - tail) * span; }
      let bend = 1;
      if (vibrato > 0 && i > rise) { vibPhase += vibInc; bend += vibrato * Math.sin(TAU * vibPhase) * Math.min(1, (i - rise) / 6000); }
      let v = 0;
      for (let u = 0; u < copies; u++) {
        let p = phases[u] + incs[u] * bend; p -= Math.floor(p); phases[u] = p;
        v += oscAt(wave, p, incs[u], 0.5);
      }
      if (filtered) { const a = Math.min(1, closed * (1 + bloom * env)); lowA += (v - lowA) * a; lowB += (lowA - lowB) * a; v = lowB; }
      if (tremolo > 0) { tremPhase += tremInc; v *= 1 - tremolo * (0.5 + 0.5 * Math.sin(TAU * tremPhase)); }
      b[start + i] += v * each * env;
    }
    return this;
  }
  pluck(at, dur, hz, amp = 0.4, damping = 0.996, soft = 0) {
    const { start, count, limit } = this._span(at, dur);
    if (count <= 0 || limit <= 0) return this;
    const period = RATE / Math.max(hz, 20);
    let ringSize = Math.max(2, Math.floor(period + 0.5));
    let fraction = period + 0.5 - ringSize;
    if (fraction < 0.1 && ringSize > 2) { ringSize -= 1; fraction += 1; }
    const tune = (1 - fraction) / (1 + fraction);
    const ring = new Float32Array(ringSize);
    for (let i = 0; i < ringSize; i++) ring[i] = this.rand() * 2 - 1;
    if (soft > 0) {
      const keep = clamp(soft, 0, 0.95); let last = 0;
      for (let pass = 0; pass < 2; pass++) for (let i = 0; i < ringSize; i++) { last = last * keep + ring[i] * (1 - keep); ring[i] = last; }
      let loud = 0; for (let i = 0; i < ringSize; i++) loud = Math.max(loud, Math.abs(ring[i]));
      if (loud > 1e-4) for (let i = 0; i < ringSize; i++) ring[i] /= loud;
    }
    let cursor = 0, decay = 1, passIn = 0, passOut = 0;
    const decayStep = Math.exp(-3.6 / limit);
    const b = this.b;
    for (let i = 0; i < limit; i++) {
      const v = ring[cursor];
      const next = (cursor + 1) % ringSize;
      const averaged = (v + ring[next]) * 0.5 * damping;
      passOut = tune * averaged + passIn - tune * passOut;
      passIn = averaged;
      ring[cursor] = passOut;
      cursor = next;
      decay *= decayStep;
      b[start + i] += v * amp * decay;
    }
    return this;
  }
  thump(at, dur, hz = 150, amp = 0.6, body = 0.35) {
    this.tone(at, dur, hz, hz * 0.28, amp, 'sine', 3.2, 0.001);
    if (body > 0) this.noise(at, dur * 0.4, amp * body, 2200, 300, 4);
    return this;
  }
  clack(at, amp = 0.35, hz = 900) {
    this.noise(at, 0.018, amp, 9000, 2400, 5, 0.0006);
    this.tone(at, 0.035, hz, hz * 0.55, amp * 0.5, 'triangle', 5, 0.001);
    return this;
  }
  whoosh(at, dur, amp = 0.25, f0 = 400, f1 = 2600) {
    return this.noise(at, dur, amp, f0 * 2.4, f1 * 2.4, 1.4, dur * 0.35, f0 * 0.7);
  }
  rumble(at, dur, amp = 0.4) {
    this.noise(at, dur, amp, 180, 70, 1.2, dur * 0.3);
    this.tone(at, dur, 44, 31, amp * 0.7, 'sine', 1.3, dur * 0.25);
    return this;
  }
  shatter(at, amp = 0.4, hz = 1400, shards = 9, spread = 0.45, partials = CHIME) {
    this.noise(at, 0.09, amp, 11000, 2000, 4, 0.0008);
    for (let i = 0; i < shards; i++) {
      this.bell(at + this.rand() * spread, this.range(0.1, 0.3), hz * this.range(0.6, 2.4), amp * this.range(0.1, 0.3), partials, 4);
    }
    return this;
  }
  clatter(at, dur, amp = 0.3, hits = 7, hz = 800) {
    for (let i = 0; i < hits; i++) this.clack(at + dur * (i / Math.max(1, hits)) + this.rand() * dur * 0.12, amp * this.range(0.45, 1), hz * this.range(0.6, 1.5));
    return this;
  }
  chord(at, dur, rootHz, steps, amp = 0.3, partials = CHIME, spread = 0) {
    for (let i = 0; i < steps.length; i++) this.bell(at + spread * i, dur, rootHz * Math.pow(2, steps[i] / 12), amp, partials, 2.2);
    return this;
  }
  sparkle(at, dur, amp = 0.2, low = 1800, high = 5200, grains = 14, partials = CHIME) {
    for (let i = 0; i < grains; i++) this.bell(at + this.rand() * dur, this.range(0.08, 0.22), this.range(low, high), amp * this.range(0.2, 0.6), partials, 3.4);
    return this;
  }

  // --- voices the game does not have yet ---------------------------------------------------
  fm(at, dur, hz, o = {}) {
    // Two-operator FM (a third, parallel modulator optional): carrier sin(φ + I·e(t)·sin(φm)).
    // `index` is how far the modulator pushes, `decay` how fast that falls (the tine of a Rhodes
    // dies before the body); `indexAttack` lets it rise instead (brass). `fb` feeds the carrier
    // back on itself for a sawtooth edge. `bend` glides in from that many semitones away.
    const { start, count, limit } = this._span(at, dur);
    if (count <= 0 || limit <= 0) return this;
    const ratio = o.ratio ?? 2, index = o.index ?? 3, idxDecay = o.decay ?? 4, amp = o.amp ?? 0.4;
    const curve = o.curve ?? 3, attack = o.attack ?? 0.004, ratio2 = o.ratio2 ?? 0, index2 = o.index2 ?? 0, idxDecay2 = o.decay2 ?? 6;
    const fb = o.fb ?? 0, idxAttack = o.indexAttack ?? 0, bend = o.bend ?? 0;
    const env = struck(count, attack, curve);
    const ienv = struck(count, Math.max(0.001, idxAttack), idxDecay);
    const ienv2 = index2 ? struck(count, 0.001, idxDecay2) : null;
    let ph = 0, phm = 0, phm2 = 0, last = 0;
    const b = this.b;
    const glideN = Math.min(count, Math.round(0.08 * RATE));
    for (let i = 0; i < limit; i++) {
      let f = hz;
      if (bend && i < glideN) f = hz * Math.pow(2, bend * (1 - i / glideN) / 12);
      const inc = f / RATE;
      phm += inc * ratio; if (phm >= 1) phm -= 1;
      let mod = Math.sin(TAU * phm) * index * ienv[i];
      if (ienv2) { phm2 += inc * ratio2; if (phm2 >= 1) phm2 -= 1; mod += Math.sin(TAU * phm2) * index2 * ienv2[i]; }
      ph += inc; if (ph >= 1) ph -= 1;
      const v = Math.sin(TAU * ph + mod + fb * last);
      last = v;
      b[start + i] += v * amp * env[i];
    }
    return this;
  }
  analog(at, dur, hz, o = {}) {
    // The classic subtractive voice: saw/square/pulse (unison, detuned) into a resonant
    // two-pole filter whose cutoff rides an envelope of its own. `glide` slides in from that ratio.
    const amp = o.amp ?? 0.3, shape = SHAPES[o.shape ?? 'saw'] ?? 2, copies = clamp(o.unison ?? 1, 1, 5), detune = o.detune ?? 0;
    const cutoff = o.cutoff ?? 800, envAmt = o.env ?? 2000, res = clamp(o.res ?? 0.3, 0, 0.95);
    const attack = o.attack ?? 0.005, fDecay = o.decay ?? 0.2, sustain = o.sustain ?? 0.2, release = o.release ?? 0.1;
    const sub = o.sub ?? 0, pw = o.pw ?? 0.5, glide = o.glide ?? 1, drive = o.drive ?? 0, lfo = o.lfo ?? 0, lfoHz = o.lfoHz ?? 0.3;
    const start = Math.max(0, Math.round(at * RATE));
    const hold = Math.round(dur * RATE), count = hold + Math.round(release * RATE);
    const limit = Math.min(count, this.n - start);
    if (hold <= 0 || limit <= 0) return this;
    const phases = [], offs = [];
    for (let u = 0; u < copies; u++) { const spread = copies === 1 ? 0 : (u / (copies - 1) - 0.5) * 2; offs.push(Math.pow(2, spread * detune / 1200)); phases.push(this.rand()); }
    let subPh = 0;
    const rise = clamp(Math.round(attack * RATE), 1, hold), fall = Math.max(1, count - hold);
    const tail = Math.exp(-5), span = 1 / (1 - tail), decayStep = Math.exp(-5 / fall);
    let decay = 1;
    const fDecayN = Math.max(1, Math.round(fDecay * RATE)), fStep = Math.exp(-4 / fDecayN);
    let fEnv = 1;
    const glideN = Math.round(0.07 * RATE);
    let ic1 = 0, ic2 = 0;
    const k = 2 - 2 * res;
    const each = amp / Math.sqrt(copies);
    const b = this.b;
    for (let i = 0; i < limit; i++) {
      let env;
      if (i < rise) env = i / rise; else if (i < hold) env = 1; else { decay *= decayStep; env = (decay - tail) * span; }
      let f = hz;
      if (glide !== 1 && i < glideN) f = hz * Math.pow(glide, 1 - i / glideN);
      const inc = f / RATE;
      let v = 0;
      for (let u = 0; u < copies; u++) { let p = phases[u] + inc * offs[u]; p -= Math.floor(p); phases[u] = p; v += oscAt(shape, p, inc * offs[u], pw); }
      if (sub > 0) { subPh += inc * 0.5; if (subPh >= 1) subPh -= 1; v += Math.sin(TAU * subPh) * sub * Math.sqrt(copies); }
      fEnv *= fStep;
      let fc = cutoff + envAmt * (sustain + (1 - sustain) * fEnv);
      if (lfo > 0) fc *= 1 + lfo * Math.sin(TAU * lfoHz * i / RATE);
      fc = clamp(fc, 20, 18000);
      const g = Math.tan(Math.PI * fc / RATE), a1 = 1 / (1 + g * (g + k)), a2 = g * a1, a3 = g * a2;
      const v3 = v - ic2, v1 = a1 * ic1 + a2 * v3, v2 = ic2 + a2 * ic1 + a3 * v3;
      ic1 = 2 * v1 - ic1; ic2 = 2 * v2 - ic2;
      let out = v2;
      if (drive > 0) out = Math.tanh(out * (1 + drive)) / Math.tanh(1 + drive);
      b[start + i] += out * each * env;
    }
    return this;
  }
  ping(at, hz, q = 40, amp = 0.3, click = 0.08) {
    // A resonant filter struck by an impulse: exactly a damped sine, with the tick of the
    // impulse itself in front. The analog "pew".
    const tau = q / (Math.PI * hz);
    const dur = Math.min(2.5, tau * 7);
    const { start, limit } = this._span(at, dur);
    if (limit <= 0) return this;
    const k = 1 / (tau * RATE), inc = hz / RATE;
    let ph = 0;
    const b = this.b;
    for (let i = 0; i < limit; i++) { ph += inc; b[start + i] += amp * Math.exp(-i * k) * Math.sin(TAU * ph) * Math.min(1, i / 40); }
    if (click > 0) this.noise(at, 0.004, amp * click, 9000, 4000, 5, 0.0003);
    return this;
  }
  gong(at, dur, hz, amp = 0.4, partials = GONG, attack = 0.03) {
    for (let i = 0; i < partials.length; i++) {
      if (hz * partials[i] > RATE * 0.45) break;
      this.tone(at, dur / (1 + i * 0.2), hz * partials[i], hz * partials[i] * 1.004, amp / (1 + i * 0.6), 'sine', 1.6, attack + i * 0.01);
    }
    return this;
  }

  // --- shaping (whole buffer) --------------------------------------------------------------
  _doubled(fn) {
    // For a loop: run a recursive effect over the buffer twice through and keep the second
    // pass, so what rings past the end has already come round into the start.
    const n = this.n, twice = new Float32Array(n * 2);
    twice.set(this.b, 0); twice.set(this.b, n);
    fn(twice);
    this.b.set(twice.subarray(n, 2 * n));
    return this;
  }
  echoes(delay, feedback = 0.35, repeats = 3, damp = 0) {
    const step = Math.round(delay * RATE);
    if (step <= 0) return this;
    const b = this.b;
    let send = feedback;
    const dry = damp > 0 ? Float32Array.from(b) : null;
    for (let r = 0; r < repeats; r++) {
      const off = step * (r + 1);
      if (dry) {
        // Each repeat a little darker than the last.
        const a = clamp(TAU * (6000 * Math.pow(1 - damp, r + 1)) / RATE, 0.02, 1); let low = 0;
        for (let i = 0; i < b.length - off; i++) { low += (dry[i] - low) * a; b[i + off] += low * send; }
      } else for (let i = 0; i < b.length - off; i++) b[i + off] += b[i] * send;
      send *= feedback;
    }
    return this;
  }
  delay(time, feedback = 0.4, mix = 0.5, damp = 3000, loop = false) {
    const run = (buf) => {
      const T = Math.max(1, Math.round(time * RATE)), n = buf.length;
      const line = new Float32Array(T); let w = 0, low = 0;
      const a = clamp(TAU * damp / RATE, 0.01, 1);
      for (let i = 0; i < n; i++) {
        const d = line[w];
        low += (d - low) * a;
        line[w] = buf[i] + low * feedback;
        w = (w + 1) % T;
        buf[i] += d * mix;
      }
    };
    return loop ? this._doubled(run) : (run(this.b), this);
  }
  reverb(o = {}) {
    // Freeverb's bones, mono: eight parallel damped combs, four allpasses in series. `size`
    // stretches the room, `decay` its ring, `damp` how fast the highs die in it. `shimmer`
    // adds an octave-up copy of the input (granular, overlapping grains) into the room: the
    // cathedral trick. For a loop the tail is folded round into the start.
    const size = o.size ?? 0.7, decay = o.decay ?? 0.6, damp = clamp(o.damp ?? 0.4, 0, 0.98), mix = o.mix ?? 0.25;
    const predelay = Math.round((o.predelay ?? 0.015) * RATE), shimmer = o.shimmer ?? 0, lowcut = o.lowcut ?? 120;
    const run = (buf) => {
      const n = buf.length;
      let input = buf;
      if (shimmer > 0) {
        const up = new Float32Array(n), grain = Math.round(0.045 * RATE), hop = grain >> 1;
        for (let g = 0; g + grain < n; g += hop) {
          for (let j = 0; j < grain; j++) { const src = g + 2 * j; if (src >= n) break; const w = 0.5 - 0.5 * Math.cos(TAU * j / grain); up[g + j] += buf[src] * w; }
        }
        input = new Float32Array(n);
        let low = 0; const a = TAU * 5000 / RATE;
        for (let i = 0; i < n; i++) { low += (up[i] - low) * a; input[i] = buf[i] + low * shimmer; }
      }
      const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map(L => Math.round(L * size));
      const allp = [556, 441, 341, 225].map(L => Math.round(L * size));
      const fb = clamp(0.7 + 0.28 * decay, 0.5, 0.985);
      const lines = combs.map(L => ({ buf: new Float32Array(L), i: 0, store: 0 }));
      const aps = allp.map(L => ({ buf: new Float32Array(L), i: 0 }));
      const wet = new Float32Array(n);
      const hp = TAU * lowcut / RATE; let hpState = 0;
      for (let i = 0; i < n; i++) {
        const x = i >= predelay ? input[i - predelay] : 0;
        let acc = 0;
        for (const c of lines) {
          const out = c.buf[c.i];
          c.store = out * (1 - damp) + c.store * damp;
          c.buf[c.i] = x + c.store * fb;
          c.i = (c.i + 1) % c.buf.length;
          acc += out;
        }
        for (const a of aps) {
          const bufout = a.buf[a.i];
          const out = -acc + bufout;
          a.buf[a.i] = acc + bufout * 0.5;
          a.i = (a.i + 1) % a.buf.length;
          acc = out;
        }
        hpState += (acc - hpState) * hp;
        wet[i] = acc - hpState;
      }
      const g = mix * 0.11;
      for (let i = 0; i < n; i++) buf[i] += wet[i] * g;
    };
    return o.loop ? this._doubled(run) : (run(this.b), this);
  }
  chorus(rate = 0.8, depth = 0.003, mix = 0.5, base = 0.018) {
    const n = this.n, b = this.b, src = Float32Array.from(b);
    const baseN = base * RATE, depthN = depth * RATE;
    for (let i = 0; i < n; i++) {
      const d1 = baseN + depthN * Math.sin(TAU * rate * i / RATE), d2 = baseN * 1.3 + depthN * Math.sin(TAU * rate * 1.17 * i / RATE + 2);
      let s = 0;
      for (const d of [d1, d2]) { const p = i - d; const k = Math.floor(p); if (k >= 1) { const f = p - k; s += src[k] * (1 - f) + src[k + 1 < n ? k + 1 : k] * f; } }
      b[i] = src[i] * (1 - mix * 0.5) + s * 0.5 * mix;
    }
    return this;
  }
  tape(o = {}) {
    // Tape: wow and flutter (a slowly and a quickly wandering delay), saturation, a soft top,
    // hiss and, if asked, the crackle of dust.
    const drive = o.drive ?? 1.4, wow = o.wow ?? 0.002, wowHz = o.wowHz ?? 0.45, flutter = o.flutter ?? 0.0004, flutterHz = o.flutterHz ?? 6.3;
    const hiss = o.hiss ?? 0.0012, lowpass = o.lowpass ?? 8000, crackle = o.crackle ?? 0;
    const n = this.n, b = this.b, src = Float32Array.from(b);
    const baseN = 0.012 * RATE;
    const aW = wow / (TAU * wowHz) * RATE, aF = flutter / (TAU * flutterHz) * RATE;
    const lp = clamp(TAU * lowpass / RATE, 0.01, 1);
    let low = 0, hissLow = 0;
    const norm = Math.tanh(drive);
    const rand = this.rand;
    for (let i = 0; i < n; i++) {
      const d = baseN + aW * Math.sin(TAU * wowHz * i / RATE) + aF * Math.sin(TAU * flutterHz * i / RATE);
      const p = i - d, k = Math.floor(p), f = p - k;
      let v = k >= 1 && k + 1 < n ? src[k] * (1 - f) + src[k + 1] * f : (k >= 0 && k < n ? src[k] : 0);
      v = Math.tanh(v * drive) / norm;
      low += (v - low) * lp;
      hissLow += (rand() * 2 - 1 - hissLow) * 0.6;
      b[i] = low + hissLow * hiss;
    }
    if (crackle > 0) {
      const events = Math.round(crackle * n / RATE);
      for (let e = 0; e < events; e++) {
        const at = Math.floor(rand() * (n - 400)), len = 20 + Math.floor(rand() * 180), a = (0.02 + rand() * 0.08) * (rand() < 0.15 ? 2.5 : 1);
        let s = 0; for (let j = 0; j < len && at + j < n; j++) { s += (rand() * 2 - 1 - s) * 0.5; b[at + j] += s * a * (1 - j / len); }
      }
    }
    return this;
  }
  saturate(drive = 1.5) { const b = this.b, norm = Math.tanh(drive); for (let i = 0; i < b.length; i++) b[i] = Math.tanh(b[i] * drive) / norm; return this; }
  lowpass(hz, passes = 1) { const a = clamp(TAU * hz / RATE, 0.001, 1); const b = this.b; for (let p = 0; p < passes; p++) { let low = 0; for (let i = 0; i < b.length; i++) { low += (b[i] - low) * a; b[i] = low; } } return this; }
  highpass(hz) { const a = clamp(TAU * hz / RATE, 0.001, 1); const b = this.b; let low = 0; for (let i = 0; i < b.length; i++) { low += (b[i] - low) * a; b[i] -= low; } return this; }
  bitcrush(bits = 10, hold = 1) {
    const q = Math.pow(2, bits - 1), b = this.b; let held = 0;
    for (let i = 0; i < b.length; i++) { if (i % hold === 0) held = Math.round(b[i] * q) / q; b[i] = held; }
    return this;
  }
  tremolo(hz, depth) { const b = this.b; for (let i = 0; i < b.length; i++) b[i] *= 1 - depth * (0.5 + 0.5 * Math.sin(TAU * hz * i / RATE)); return this; }
  fade(sec = 0.02) { const count = Math.min(this.n, Math.round(sec * RATE)); for (let i = 0; i < count; i++) this.b[this.n - 1 - i] *= i / Math.max(1, count); return this; }
  fadeIn(sec) { const count = Math.min(this.n, Math.round(sec * RATE)); for (let i = 0; i < count; i++) this.b[i] *= i / Math.max(1, count); return this; }
  gain(x) { const b = this.b; for (let i = 0; i < b.length; i++) b[i] *= x; return this; }
  normalise(to = 0.82) { const p = this.peak(); if (p > 1e-4) this.gain(to / p); return this; }
  rmsTo(db) { const r = this.rms(); if (r > 1e-6) this.gain(Math.pow(10, db / 20) / r); return this; }
  softclip(knee = 0.7) { const b = this.b; for (let i = 0; i < b.length; i++) { const v = b[i]; if (v > knee) b[i] = knee + (1 - knee) * Math.tanh((v - knee) / (1 - knee)); else if (v < -knee) b[i] = -knee + (1 - knee) * Math.tanh((v + knee) / (1 - knee)); } return this; }
  add(other, atSample, scale = 1) {
    // Lays a finished sound in, wrapping round the end: in a loop the last bar rings on into the first.
    const size = this.n; if (!other || !other.length || scale === 0) return this;
    const start = posmod(Math.round(atSample), size);
    const first = Math.min(other.length, size - start);
    const b = this.b;
    for (let i = 0; i < first; i++) b[start + i] += other[i] * scale;
    const rest = Math.min(other.length - first, start);
    for (let i = 0; i < rest; i++) b[i] += other[first + i] * scale;
    return this;
  }
  mix(other, scale = 1) { const b = this.b; const m = Math.min(b.length, other.length); for (let i = 0; i < m; i++) b[i] += other[i] * scale; return this; }
  out(peak = 0.82) { this.fade(0.008); this.normalise(peak); this.softclip(); return this.b; }
}

// --- drums and materials shared across profiles -------------------------------------------
const Drums = {
  kick(o = {}) { const s = new Syn(o.dur ?? 0.45, o.seed); s.tone(0, o.dur ?? 0.45, o.hz ?? 150, o.to ?? 45, o.amp ?? 0.9, 'sine', o.curve ?? 3.2, 0.001); if ((o.click ?? 0.12) > 0) s.noise(0, 0.012, o.click ?? 0.12, 6000, 1500, 5, 0.0005); if (o.lp) s.lowpass(o.lp); return s.b; },
  snare(o = {}) { const s = new Syn(o.dur ?? 0.24, o.seed); s.noise(0, o.dur ?? 0.22, o.amp ?? 0.4, o.cut ?? 6000, o.cutTo ?? 1800, o.curve ?? 3.4, 0.001, o.hp ?? 400); s.tone(0, 0.09, o.tone ?? 200, (o.tone ?? 200) * 0.8, (o.amp ?? 0.4) * 0.7, 'triangle', 4.5, 0.001); if (o.lp) s.lowpass(o.lp); return s.b; },
  hat(o = {}) { const s = new Syn(o.dur ?? 0.08, o.seed); s.noise(0, (o.dur ?? 0.08) * 0.9, o.amp ?? 0.4, 11000, o.open ? 8000 : 6000, o.open ? 2.2 : 5, 0.0005, o.hp ?? 4000); return s.b; },
  shaker(o = {}) { const s = new Syn(0.14, o.seed); s.noise(0, 0.12, o.amp ?? 0.3, 9000, 6000, 3.2, 0.025, 3500); return s.b; },
  clap(o = {}) { const s = new Syn(0.3, o.seed); for (let i = 0; i < 3; i++) s.noise(i * 0.011, 0.03, (o.amp ?? 0.4) * 0.6, 5000, 2500, 4, 0.001, 900); s.noise(0.03, 0.22, o.amp ?? 0.4, 4500, 1800, 3.2, 0.002, 800); return s.b; },
  tom(o = {}) { const s = new Syn(0.5, o.seed); const hz = o.hz ?? 150; s.tone(0, o.dur ?? 0.45, hz, hz * 0.7, o.amp ?? 0.6, 'sine', 3, 0.002); s.noise(0, 0.08, (o.amp ?? 0.6) * 0.3, 2400, 600, 4); return s.b; },
  bodhran(o = {}) { const s = new Syn(0.55, o.seed); const hz = o.hz ?? 92; s.tone(0, 0.5, hz * 1.15, hz, o.amp ?? 0.7, 'sine', 2.8, 0.002); s.noise(0, 0.07, (o.amp ?? 0.7) * 0.25, 3000, 700, 4.5, 0.001); if (o.rim) s.clack(0, 0.15, 1800); return s.b; },
  taiko(o = {}) { const s = new Syn(0.8, o.seed); s.thump(0, 0.7, 82, 0.9, 0.35); s.noise(0, 0.25, 0.15, 900, 200, 3); return s.b; },
  ride(o = {}) { const s = new Syn(1.4, o.seed); s.bell(0, 1.3, o.hz ?? 3100, o.amp ?? 0.22, METAL, 1.6); s.noise(0, 0.25, (o.amp ?? 0.22) * 0.5, 9000, 6000, 3, 0.001, 5000); return s.b; },
  swish(o = {}) { const s = new Syn(0.35, o.seed); s.noise(0, 0.3, o.amp ?? 0.3, 4500, 2500, 2.2, o.attack ?? 0.08, 1500); return s.b; },
  tick(o = {}) { const s = new Syn(0.06, o.seed); s.clack(0, o.amp ?? 0.3, o.hz ?? 3400); s.tone(0, 0.012, (o.hz ?? 3400) * 1.5, -1, (o.amp ?? 0.3) * 0.3, 'sine', 6, 0.0005); return s.b; },
  wood(o = {}) { const s = new Syn(0.14, o.seed); const hz = o.hz ?? 880; s.tone(0, 0.1, hz, hz * 0.93, o.amp ?? 0.5, 'sine', 6, 0.001); s.tone(0, 0.05, hz * 2.7, -1, (o.amp ?? 0.5) * 0.24, 'sine', 7, 0.001); return s.b; },
  rim(o = {}) { const s = new Syn(0.1, o.seed); s.clack(0, o.amp ?? 0.42, o.hz ?? 1250); return s.b; },
  anvil(o = {}) { const s = new Syn(0.9, o.seed); s.bell(0, 0.8, o.hz ?? 640, o.amp ?? 0.34, METAL, 3.2); s.noise(0, 0.03, 0.2, 9000, 3000, 5); return s.b; },
  gong(o = {}) { const s = new Syn(o.dur ?? 3, o.seed); s.gong(0, o.dur ?? 3, o.hz ?? 110, o.amp ?? 0.5); s.noise(0, 0.12, 0.1, 3000, 600, 3, 0.01); return s.b; },
  thud(o = {}) { const s = new Syn(0.9, o.seed); s.tone(0, 0.85, 62, 38, 0.8, 'sine', 2.4, 0.003); s.noise(0, 0.3, 0.12, 400, 120, 2.5); return s.b; },
  stomp(o = {}) { const s = new Syn(0.4, o.seed); s.thump(0, 0.35, 70, 0.9, 0.5); s.noise(0, 0.1, 0.25, 1800, 300, 4, 0.001); return s.b; },
  escapement(o = {}) { const s = new Syn(0.08, o.seed); s.clack(0, o.amp ?? 0.3, 3200); s.clack(0.014, (o.amp ?? 0.3) * 0.7, 4600); return s.b; },
  cog(o = {}) { const s = new Syn(0.5, o.seed); s.bell(0, 0.4, o.hz ?? 520, o.amp ?? 0.35, METAL, 3.6); s.clack(0, (o.amp ?? 0.35) * 0.8, 900); return s.b; },
  chip(o = {}) { const s = new Syn(0.12, o.seed); s.clack(0, o.amp ?? 0.35, 2300); s.bell(0, 0.07, 3100, (o.amp ?? 0.35) * 0.35, CHIME, 6); s.thump(0, 0.06, 240, (o.amp ?? 0.35) * 0.5, 0.1); return s.b; },
};

// --- music scaffolding -----------------------------------------------------------------------
const MODES = {
  ionian: [0, 2, 4, 5, 7, 9, 11], dorian: [0, 2, 3, 5, 7, 9, 10], phrygian: [0, 1, 3, 5, 7, 8, 10], lydian: [0, 2, 4, 6, 7, 9, 11],
  mixolydian: [0, 2, 4, 5, 7, 9, 10], aeolian: [0, 2, 3, 5, 7, 8, 10], locrian: [0, 1, 3, 5, 6, 8, 10], harmonic: [0, 2, 3, 5, 7, 8, 11],
  phrygian_dominant: [0, 1, 4, 5, 7, 8, 10],
};
const PITCHES = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };
const midiHz = (m) => 440 * Math.pow(2, (m - 69) / 12);
const fit = (midi, low) => low + posmod(midi - low, 12);
function nearestTone(deg, chord) { for (let d = 0; d < 4; d++) for (const c of [deg - d, deg + d]) if ([0, 2, 4].includes(posmod(c - chord, 7))) return c; return deg; }
function nearestRoot(deg, chord) { for (let d = 0; d < 4; d++) for (const c of [deg - d, deg + d]) if (posmod(c - chord, 7) === 0) return c; return deg; }
function home(deg) { while (deg > 9) deg -= 7; while (deg < -2) deg += 7; return deg; }

class Piece {
  constructor(o) {
    this.bpm = o.bpm; this.meter = o.meter || 4; this.bars = o.bars || 8; this.swing = o.swing || 0; this.swing8 = o.swing8 || 0;
    this.step = Math.round(RATE * 60 / this.bpm / 4);
    this.stepsBar = this.meter * 4; this.totalSteps = this.bars * this.stepsBar; this.total = this.totalSteps * this.step;
    const pc = PITCHES[o.key] ?? 0;
    this.root = 45 + posmod(pc - 9, 12);        // the key note between A2 and G#3, as in the game
    this.scale = MODES[o.mode] || MODES.aeolian;
    this.chords = o.chords;                       // one per two bars
    this.cache = new Map(); this.rand = rng32(o.seed || 7);
  }
  strip() { const s = new Syn(1); s.n = this.total; s.b = new Float32Array(this.total); return s; }
  at(step) { let pos = step * this.step; if (this.swing && (step & 1)) pos += Math.round(this.swing * this.step); if (this.swing8 && step % 4 === 2) pos += Math.round(this.swing8 * 0.667 * this.step); return pos; }
  chordAt(bar) { return this.chords[Math.floor(bar / 2) % this.chords.length]; }
  pitch(deg, base = this.root) { const i = posmod(deg, 7); return base + this.scale[i] + 12 * Math.floor(deg / 7); }
  seconds(steps) { return steps * this.step / RATE; }
  memo(key, make) { let v = this.cache.get(key); if (!v) { v = make(); this.cache.set(key, v); } return v; }
  // A note of a voice: `voice(hz, seconds) -> Float32Array`, written once per pitch and length.
  play(strip, name, voice, midi, step, lenSteps, level = 1) {
    const buf = this.memo(name + ':' + midi + ':' + lenSteps, () => voice(midiHz(midi), this.seconds(Math.max(1, lenSteps))));
    strip.add(buf, this.at(step), level);
  }
  hit(strip, name, drum, step, level = 1, variant = 0) {
    const buf = this.memo('drum:' + name + ':' + variant, () => drum(variant));
    strip.add(buf, this.at(step), level);
  }
  // A one-bar pattern in sixteenths ("X" accent, "x" hit, "o" ghost, "." rest) over every bar.
  pattern(strip, name, drum, line, level = 1, bars = null) {
    const HITS = { X: 1, x: 0.72, o: 0.4 };
    const which = bars || [...Array(this.bars).keys()];
    for (const bar of which) for (let s = 0; s < Math.min(line.length, this.stepsBar); s++) {
      const m = line[s]; if (!HITS[m]) continue;
      this.hit(strip, name, drum, bar * this.stepsBar + s, level * HITS[m] * (0.9 + 0.1 * this.rand()), s % 2);
    }
  }
  // The tune: two-bar motifs ([onset, length, height] in sixteenths and scale steps) placed on
  // each phrase's chord, as the game's composer does: strong beats snap to chord tones, a
  // phrase marked "2" ends on the chord's root, "end" is half a motif and the root held.
  tune(plan, motifs) {
    const out = []; let anchor = 4; const sb = this.stepsBar;
    for (let slot = 0; slot < plan.length; slot++) {
      const kind = plan[slot], chord = this.chordAt(slot * 2), at = slot * 2 * sb;
      if (kind === 'ans') {
        const high = home(nearestTone(anchor + 2, chord));
        out.push([at + 4, sb - 4, high]); out.push([at + sb + 2, sb - 4, home(nearestTone(high - 2, chord))]);
        continue;
      }
      const motif = motifs[kind[0]] || motifs.A;
      const notes = kind === 'end' ? motif.filter(n => n[0] < sb) : motif;
      const lift = kind[0] === 'C' ? 2 : 0;
      const start = nearestTone(anchor + lift, chord);
      let last = start;
      for (let i = 0; i < notes.length; i++) {
        const n = notes[i];
        let deg = start + n[2] - motif[0][2];
        if (n[0] % (this.meter === 3 ? sb : 8) === 0) deg = nearestTone(deg, chord);
        if (i === notes.length - 1 && kind.endsWith('2')) deg = nearestRoot(deg, chord);
        deg = home(deg);
        out.push([at + n[0], n[1], deg]); last = deg;
      }
      if (kind === 'end') { last = home(nearestRoot(last, chord)); out.push([at + sb, sb - 2, last]); }
      anchor = clamp(Math.round((4 + last) * 0.5), 1, 6);
    }
    return out;
  }
  // The chord's tones over the pads' register (root + 7 .. +19), its root an octave under.
  padNotes(chord, sevenths = false, low = this.root + 7) {
    const tones = [chord, chord + 2, chord + 4]; if (sevenths) tones.push(chord + 6);
    return tones.map(d => fit(this.pitch(d), low));
  }
}
// Each layer levelled by its average loudness, then soft-clipped: the game does the same.
function level(strip, db) { strip.rmsTo(db); strip.softclip(0.75); return strip.b; }

root.DeepSoundCore = { RATE, TAU, Syn, Drums, Piece, MODES, PITCHES, midiHz, fit, rng32, clamp, posmod, BELL, CHIME, METAL, GLASS, TINE, VIBE, GONG, PIPE, level };
})(typeof self !== 'undefined' ? self : globalThis);

// =============================================================================================
// Modular Vein, warmed (round 2): one kit for the whole bank and the whole score. Every sound
// here is rendered dry; the room (reverb and echo by place and depth) is added live by the
// page, as the game would add it on its buses.
// =============================================================================================
(function (root) {
'use strict';
const C = root.DeepSoundCore;
const { RATE, Syn, Drums, Piece, midiHz, fit, clamp, posmod, rng32, MODES, PITCHES, METAL, CHIME, level } = C;
const C5 = 523.25, C6 = 1046.5, A4 = 440;
const st = (semis, base = C5) => base * Math.pow(2, semis / 12);
const PENTA = [0, 2, 4, 7, 9];
const STAR = [0, 7, 12, 16, 19];
const sec = (s) => Math.round(s * RATE);

// --- the kit ---------------------------------------------------------------------------------
// A ping with a little sine body under it: the round 1 ping, less click, warmer.
const ping = (s, at, hz, q = 24, amp = 0.4, click = 0.03) => { s.ping(at, hz, q, amp, click); s.tone(at, Math.min(0.5, q / (Math.PI * hz) * 5), hz * 0.5, -1, amp * 0.18, 'sine', 3.5, 0.003); return s; };
// Felt: the soft thump of Lamplight, under anything the hand does.
const felt = (s, at, hz = 210, amp = 0.3) => { s.thump(at, 0.08, hz, amp, 0.1); s.noise(at, 0.016, amp * 0.25, 2000, 600, 5, 0.0008); return s; };
// An analog "tok": the dice.
const tok = (s, at, amp = 0.35, hz = 620) => { s.tone(at, 0.028, hz, hz * 0.66, amp, 'triangle', 5, 0.001); s.noise(at, 0.018, amp * 0.5, 1100, 500, 5, 0.0005); return s; };
const sqk = (s, at, hz, dur, amp, o = {}) => s.analog(at, dur, hz, Object.assign({ amp, shape: 'saw', cutoff: 200, env: 2200, res: 0.5, decay: 0.16, sustain: 0.1, release: 0.08, sub: 0.35, drive: 0.25 }, o));
const stab = (s, at, root, steps, amp = 0.26, dur = 0.3, o = {}) => { for (const k of steps) s.analog(at, dur, root * Math.pow(2, k / 12), Object.assign({ amp, shape: 'saw', unison: 2, detune: 8, cutoff: 400, env: 2800, res: 0.3, attack: 0.008, decay: 0.3, sustain: 0.2, release: 0.2 }, o)); return s; };
const swell = (s, at, root, steps, amp = 0.24, dur = 0.7) => { for (const k of steps) s.analog(at, dur, root * Math.pow(2, k / 12), { amp, shape: 'saw', unison: 3, detune: 9, cutoff: 220, env: 2200, res: 0.25, attack: 0.25, decay: 0.9, sustain: 0.15, release: 0.5 }); return s; };
const ladder = (s, at, root, steps, gap, q = 90, amp = 0.36) => { steps.forEach((k, i) => ping(s, at + i * gap, root * Math.pow(2, k / 12), q, amp, 0.05)); return s; };
const sparkle = (s, at, dur, amp = 0.12, n = 8, low = 1800, high = 5200) => { for (let i = 0; i < n; i++) s.ping(at + s.rand() * dur, s.range(low, high), s.range(18, 50), amp * s.range(0.4, 1), 0.02); return s; };
const metal = (s, at, hz, dur, amp) => s.fm(at, dur, hz, { ratio: 1.41, index: 3.2, decay: 3.5, amp, curve: 3, attack: 0.001 });
const coin = (s, at, amp = 0.16) => { metal(s, at, s.range(1800, 3400), s.range(0.12, 0.26), amp); tok(s, at, amp * 0.3, 1600); return s; };
const riser = (s, at, dur, amp = 0.3, hz = 110) => { s.voice(at, dur, hz, amp, 'saw', dur * 0.4, 0.25, 2, 8, 180, 18); s.noise(at, dur, amp * 0.5, 300, 5000, 0.8, dur * 0.85, 200); return s; };
const kick = (o = {}) => Drums.kick(Object.assign({ hz: 160, to: 46, dur: 0.42, click: 0.12, lp: 3200 }, o));
const hat = (v = 0) => { const s = new Syn(0.08, 301 + v); s.noise(0, 0.07, v ? 0.22 : 0.3, 9000, 5500, 5, 0.0005, 5000); return s.b; };
const shaker = () => Drums.shaker({ amp: 0.24 });
const clap = () => { const s = new Syn(0.3, 302); s.mix(Drums.clap({ amp: 0.4 }), 1); return s.lowpass(5000).b; };
const snare = () => Drums.snare({ dur: 0.18, tone: 195, amp: 0.4, cut: 5000, cutTo: 1800, hp: 500, lp: 6000 });
const tom = (hz = 120) => Drums.tom({ hz, dur: 0.4 });
// A hit that feels like one: the thwack (a pitched knock falling fast), the crack, the weight.
const impact = (s, at, size = 1, hz = 330) => {
  s.tone(at, 0.07 * size, hz, hz * 0.28, 0.5, 'triangle', 4.5, 0.001);
  s.noise(at, 0.05 * size, 0.45, 8000, 700, 4.5, 0.0008, 500);
  s.tone(at, 0.32 * size, 150, 42, 0.6 * Math.min(1.3, size), 'sine', 3.2, 0.001);
  if (size >= 1) s.noise(at + 0.01, 0.18 * size, 0.22, 2600, 300, 3, 0.002);
  return s;
};
const whoosh = (s, at, dur, amp, f0, f1) => s.noise(at, dur, amp, f0 * 2.4, f1 * 2.4, 1.4, dur * 0.35, Math.min(f0, f1) * 0.7);
const crackle = (s, at, dur, n, amp = 0.1) => { for (let i = 0; i < n; i++) s.noise(at + s.rand() * dur, 0.012, amp * s.range(0.4, 1.2), 7000, 3000, 5, 0.0005, 1500); return s; };
const bubbles = (s, at, dur, n, low = 140, high = 320, amp = 0.16) => { for (let i = 0; i < n; i++) { const f = s.range(low, high); s.tone(at + s.rand() * dur, 0.1, f, f * 1.9, amp * s.range(0.6, 1.2), 'sine', 3.5, 0.004); } return s; };
const fin = (s, peak) => { s.lowpass(9500); s.saturate(1.12); return s.out(peak); };
const S = (seconds, seed) => new Syn(seconds, seed);

// --- the bank: every sound the game names, plus the creature blows ------------------------------
const SFX = {
  // interface: pings on the pentatonic (the game would take the key from DeepMusic.tonic)
  ui_tap: (v = 0) => { const s = S(0.45, 1 + v); felt(s, 0, 220, 0.16); ping(s, 0, [880, 1046.5, 1318.5][v % 3], 18, 0.42, 0.025); return fin(s, 0.5); },
  ui_hover: () => { const s = S(0.25, 2); s.ping(0, 1760, 9, 0.2, 0); return fin(s, 0.17); },
  ui_confirm: () => { const s = S(0.9, 3); felt(s, 0, 200, 0.14); ping(s, 0, 659.3, 36, 0.42, 0.03); ping(s, 0.07, 987.8, 36, 0.4, 0.03); [1318.5, 1174.7, 987.8].forEach((hz, i) => sqk(s, 0.18 + i * 0.07, hz, 0.06, 0.1, { shape: 'pulse', pw: 0.3, cutoff: 500, env: 1800, res: 0.5 })); return fin(s, 0.6); },
  ui_back: () => { const s = S(0.6, 4); s.analog(0, 0.11, 440, { amp: 0.4, shape: 'saw', cutoff: 280, env: 2600, res: 0.55, decay: 0.1, sustain: 0.05, release: 0.08, glide: 1.3 }); felt(s, 0.01, 170, 0.22); return fin(s, 0.48); },
  ui_toggle: () => { const s = S(0.3, 5); tok(s, 0, 0.3, 900); ping(s, 0.004, 1480, 10, 0.26, 0.02); return fin(s, 0.5); },
  ui_tab: () => { const s = S(0.3, 6); felt(s, 0, 240, 0.3); ping(s, 0, 740, 9, 0.22, 0.01); return fin(s, 0.36); },
  ui_open: () => { const s = S(0.7, 7); s.analog(0, 0.22, 220, { amp: 0.26, shape: 'saw', unison: 2, detune: 7, cutoff: 250, env: 3200, res: 0.4, attack: 0.02, decay: 0.3, sustain: 0.6, release: 0.15 }); ping(s, 0.12, 1318.5, 30, 0.3, 0.02); return fin(s, 0.52); },
  ui_close: () => { const s = S(0.6, 8); s.analog(0, 0.2, 220, { amp: 0.26, shape: 'saw', unison: 2, detune: 7, cutoff: 1800, env: 0, res: 0.3, attack: 0.005, decay: 0.2, sustain: 0.1, release: 0.12, lfo: 0, drive: 0 }); s.lowpass(2000); felt(s, 0.16, 150, 0.3); return fin(s, 0.5); },
  ui_deny: () => { const s = S(0.5, 9); for (const at of [0, 0.11]) s.analog(at, 0.09, 180, { amp: 0.45, shape: 'square', cutoff: 600, env: 900, res: 0.3, decay: 0.08, release: 0.05 }); felt(s, 0.11, 130, 0.3); return fin(s, 0.5); },
  toast: () => { const s = S(0.8, 10); ping(s, 0, C6, 40, 0.34, 0.02); ping(s, 0.06, C6 * 1.5, 40, 0.26, 0.02); return fin(s, 0.5); },
  toast_bad: () => { const s = S(0.5, 11); s.analog(0, 0.2, 320, { amp: 0.4, shape: 'square', cutoff: 500, env: 700, res: 0.3, decay: 0.18, release: 0.08, glide: 1.6 }); s.noise(0, 0.14, 0.14, 1400, 300, 3); return fin(s, 0.5); },
  unlock: () => { const s = S(1.6, 12); stab(s, 0, C5, [0, 4, 7, 12], 0.24, 0.9, { attack: 0.03 }); ladder(s, 0.1, C6, [0, 4, 7, 12], 0.07, 60, 0.3); whoosh(s, 0, 0.3, 0.1, 400, 2400); sparkle(s, 0.3, 0.8, 0.1, 12); return fin(s, 0.8); },
  // dice: hard little solids on felt
  die_tumble: () => { const s = S(0.5, 13); for (let i = 0; i < 5; i++) { const t = i * 0.06 + s.rand() * 0.02; tok(s, t, 0.26 * s.range(0.6, 1), s.range(520, 760)); felt(s, t, 230, 0.12); } return fin(s, 0.46); },
  die_settle: () => { const s = S(0.25, 14); tok(s, 0, 0.36, 620); felt(s, 0, 230, 0.3); s.ping(0, 480, 8, 0.12, 0); return fin(s, 0.5); },
  die_pick: () => { const s = S(0.2, 15); tok(s, 0, 0.24, 900); s.ping(0, 1100, 10, 0.16, 0); return fin(s, 0.42); },
  die_drop: () => { const s = S(0.2, 16); tok(s, 0, 0.24, 700); felt(s, 0, 240, 0.2); return fin(s, 0.38); },
  dice_lock: () => { const s = S(0.5, 17); s.analog(0, 0.07, 420, { amp: 0.4, shape: 'square', cutoff: 800, env: 2000, res: 0.5, decay: 0.07, release: 0.08 }); metal(s, 0, 1250, 0.3, 0.22); felt(s, 0, 160, 0.26); return fin(s, 0.66); },
  dice_reroll: () => { const s = S(0.8, 18); whoosh(s, 0, 0.18, 0.12, 600, 1800); for (let i = 0; i < 11; i++) { const t = 0.04 + i * 0.038 + s.rand() * 0.02; tok(s, t, 0.3 * s.range(0.5, 1), s.range(500, 800)); } return fin(s, 0.62); },
  die_break: () => { const s = S(0.8, 19); s.noise(0, 0.06, 0.45, 9000, 1500, 4.5, 0.0006); for (let i = 0; i < 9; i++) s.ping(0.01 + s.rand() * 0.25, s.range(2000, 5200), s.range(20, 60), 0.2, 0.02); felt(s, 0, 180, 0.3); s.analog(0, 0.12, 2600, { amp: 0.2, shape: 'square', cutoff: 3000, env: 2000, res: 0.6, decay: 0.08, release: 0.1 }); return fin(s, 0.62); },
  // the fight
  battle_begin: () => { const s = S(1.8, 20); riser(s, 0, 1.2, 0.34, 58); s.rumble(0, 1.3, 0.3); s.add(kick({ hz: 140, to: 40, dur: 0.6 }), sec(1.2), 1); s.analog(1.2, 0.3, 58, { amp: 0.4, shape: 'saw', cutoff: 120, env: 400, res: 0.2, decay: 0.3, release: 0.2, drive: 1.2 }); return fin(s, 0.74); },
  turn_begin: () => { const s = S(1.2, 21); ping(s, 0, 196, 90, 0.42, 0.02); s.tone(0, 0.8, 392, -1, 0.1, 'sine', 2.6, 0.004); return fin(s, 0.6); },
  resolve: () => { const s = S(0.7, 22); whoosh(s, 0, 0.3, 0.2, 220, 1900); ping(s, 0.2, 659.3, 40, 0.3, 0.02); return fin(s, 0.64); },
  gem_red: () => { const s = S(0.9, 23); sqk(s, 0, 73.4, 0.3, 0.55, { res: 0.7, decay: 0.15, drive: 1.0, env: 2600 }); s.noise(0, 0.12, 0.2, 5000, 400, 3.4, 0.001); s.add(kick(), 0, 0.4); return fin(s, 0.68); },
  gem_blue: () => { const s = S(1.4, 24); ping(s, 0, 1174.7, 110, 0.5, 0.05); s.tone(0, 0.6, 2349, -1, 0.06, 'sine', 3, 0.003); return fin(s, 0.62); },
  gem_green: () => { const s = S(1.2, 25); s.analog(0, 0.35, 392, { amp: 0.3, shape: 'saw', unison: 2, detune: 7, cutoff: 200, env: 2400, res: 0.35, attack: 0.04, decay: 0.4, sustain: 0.1, release: 0.25, glide: 0.75 }); ping(s, 0.08, 784, 60, 0.26, 0.02); return fin(s, 0.66); },
  gem_violet: () => { const s = S(1.3, 26); s.ping(0, 740, 90, 0.36, 0.03); s.ping(0, 740 * 1.012, 90, 0.3, 0); s.analog(0, 0.3, 185, { amp: 0.2, shape: 'square', cutoff: 300, env: 600, res: 0.3, decay: 0.3, release: 0.15 }); return fin(s, 0.68); },
  gem_gold: () => { const s = S(1.3, 27); ladder(s, 0, 587.3, [0, 7, 12], 0.02, 70, 0.36); [1174.7, 1480, 1760, 2349].forEach((hz, i) => sqk(s, 0.1 + i * 0.07, hz, 0.07, 0.16, { shape: 'pulse', pw: 0.3, cutoff: 900, env: 3000, res: 0.5 })); return fin(s, 0.66); },
  gem_white: () => { const s = S(1.0, 28); s.ping(0, 1318.5, 120, 0.4, 0); s.tone(0, 0.5, 2637, -1, 0.08, 'sine', 3, 0.003); return fin(s, 0.62); },
  gem_fizzle: () => { const s = S(0.6, 29); s.analog(0, 0.25, 300, { amp: 0.3, shape: 'saw', cutoff: 2400, env: 0, res: 0.4, decay: 0.2, release: 0.1, glide: 1.5 }); s.lowpass(1500); s.noise(0, 0.26, 0.2, 1800, 260, 2.6, 0.01); return fin(s, 0.46); },
  // a gem's count: one instrument in six colours, all on C
  tally_tick: () => { const s = S(0.3, 30); ping(s, 0, C5, 40, 0.42, 0.05); return fin(s, 0.5); },
  tick_red: () => { const s = S(0.3, 31); s.fm(0, 0.12, C5, { ratio: 1, index: 2.2, decay: 4, amp: 0.4, curve: 4.5, attack: 0.001, fb: 0.3 }); s.noise(0, 0.04, 0.18, 6000, 1500, 5, 0.0006); return fin(s, 0.5); },
  tick_blue: () => { const s = S(0.3, 32); s.ping(0, C5, 50, 0.4, 0.04); s.ping(0, C5 * 2, 40, 0.16, 0); return fin(s, 0.5); },
  tick_green: () => { const s = S(0.3, 33); s.analog(0, 0.08, C5, { amp: 0.42, shape: 'triangle', cutoff: 1500, env: 1500, res: 0.3, decay: 0.08, release: 0.1 }); s.tone(0, 0.06, C5, -1, 0.12, 'sine', 5, 0.001); return fin(s, 0.5); },
  tick_violet: () => { const s = S(0.3, 34); s.ping(0, C5, 55, 0.34, 0.03); s.ping(0, C5 * 1.014, 55, 0.3, 0); return fin(s, 0.5); },
  tick_gold: () => { const s = S(0.3, 35); s.ping(0, C5, 45, 0.34, 0.04); metal(s, 0.005, C5 * 3, 0.1, 0.1); return fin(s, 0.5); },
  tick_white: () => { const s = S(0.3, 36); s.ping(0, C5, 50, 0.4, 0); s.ping(0, C5 * 2, 40, 0.1, 0); return fin(s, 0.5); },
  tally_mult: () => { const s = S(0.6, 37); sqk(s, 0, C5 / 4, 0.22, 0.55); s.add(kick(), 0, 0.6); return fin(s, 0.64); },
  tally_fuse: () => { const s = S(0.9, 38); stab(s, 0, C5, [0, 7, 12], 0.26, 0.35); ping(s, 0, C6, 60, 0.3, 0.03); whoosh(s, 0.06, 0.3, 0.14, 500, 3200); sparkle(s, 0.05, 0.3, 0.08, 6, 2400, 6000); return fin(s, 0.72); },
  tally_blaze: () => { const s = S(1.1, 39); whoosh(s, 0, 0.5, 0.3, 180, 2800); s.analog(0, 0.45, 110, { amp: 0.3, shape: 'saw', unison: 2, detune: 9, cutoff: 200, env: 2600, res: 0.3, attack: 0.03, decay: 0.5, sustain: 0.2, release: 0.3, drive: 1.5 }); s.add(kick({ hz: 120, to: 36, dur: 0.5 }), 0, 0.9); crackle(s, 0.08, 0.6, 10, 0.14); sparkle(s, 0.1, 0.6, 0.1, 8, 2600, 7000); return fin(s, 0.74); },
  resonance: () => { const s = S(0.9, 40); ping(s, 0, 880, 90, 0.4, 0.03); s.ping(0.02, 1760, 60, 0.12, 0); return fin(s, 0.58); },
  harmony: () => { const s = S(0.9, 41); ping(s, 0, 880, 80, 0.34, 0.03); ping(s, 0.03, 1318.5, 80, 0.3, 0.02); sparkle(s, 0.05, 0.3, 0.08, 6, 2400, 5200); return fin(s, 0.66); },
  hit_light: () => { const s = S(0.5, 42); impact(s, 0, 0.6, 420); return fin(s, 0.7); },
  hit_heavy: () => { const s = S(0.7, 43); impact(s, 0, 1.0, 330); return fin(s, 0.86); },
  hit_crit: () => { const s = S(1.0, 44); impact(s, 0, 1.3, 280); s.noise(0.01, 0.4, 0.3, 9000, 400, 2.6, 0.001); ping(s, 0.02, 1760, 40, 0.24, 0.02); s.rumble(0.05, 0.5, 0.2); return fin(s, 0.92); },
  block: () => { const s = S(0.6, 45); s.analog(0, 0.08, 420, { amp: 0.45, shape: 'square', cutoff: 800, env: 2000, res: 0.5, decay: 0.08, release: 0.1 }); metal(s, 0, 1250, 0.3, 0.28); tok(s, 0, 0.2, 1600); return fin(s, 0.7); },
  block_break: () => { const s = S(0.8, 46); impact(s, 0, 0.7, 300); for (let i = 0; i < 7; i++) s.ping(0.01 + s.rand() * 0.3, s.range(900, 2600), s.range(15, 40), 0.2, 0.02); return fin(s, 0.76); },
  heal: () => { const s = S(1.5, 47); swell(s, 0, 261.6, [0, 4, 7], 0.24, 0.6); ladder(s, 0.2, 659.3, [0, 4, 7, 12], 0.1, 60, 0.26); return fin(s, 0.62); },
  poison: () => { const s = S(0.9, 48); for (let i = 0; i < 5; i++) s.tone(i * 0.09, 0.14, 240 - i * 22, 130, 0.2, 'sine', 3.4, 0.006, 0.08, 18); s.noise(0, 0.45, 0.12, 900, 220, 2, 0.05); bubbles(s, 0.1, 0.5, 4, 120, 260, 0.12); return fin(s, 0.6); },
  stun: () => { const s = S(1.0, 49); s.tone(0, 0.5, 700, 620, 0.24, 'sine', 2, 0.006, 0.06, 13); for (let i = 0; i < 4; i++) s.ping(0.1 + i * 0.12, 1400 + s.range(-300, 500), 30, 0.14, 0.02); return fin(s, 0.62); },
  curse: () => { const s = S(1.2, 50); s.analog(0, 0.7, 190, { amp: 0.3, shape: 'saw', unison: 2, detune: 14, cutoff: 500, env: -300, res: 0.3, attack: 0.03, decay: 0.6, sustain: 0.4, release: 0.3, glide: 1.4 }); s.noise(0, 0.6, 0.1, 700, 160, 1.6, 0.1); return fin(s, 0.62); },
  enemy_windup: () => { const s = S(0.8, 51); s.analog(0, 0.42, 88, { amp: 0.36, shape: 'saw', unison: 2, detune: 10, cutoff: 150, env: 1200, res: 0.4, attack: 0.1, decay: 0.5, sustain: 1, release: 0.1, glide: 0.6 }); s.noise(0, 0.4, 0.18, 320, 1100, 1.4, 0.2, 180); return fin(s, 0.72); },
  enemy_strike: () => { const s = S(0.9, 52); impact(s, 0, 1.15, 240); s.tone(0, 0.45, 72, 30, 0.6, 'sine', 2.6, 0.001); return fin(s, 0.94); },
  creature_die: () => { const s = S(1.2, 53); impact(s, 0, 0.8, 260); for (let i = 0; i < 12; i++) s.ping(0.02 + s.rand() * 0.45, s.range(700, 3200), s.range(15, 45), 0.2, 0.02); s.noise(0.05, 0.6, 0.14, 3000, 200, 2.2, 0.03); s.analog(0.05, 0.4, 110, { amp: 0.24, shape: 'saw', cutoff: 1600, env: 0, res: 0.3, decay: 0.3, release: 0.2, glide: 1.8 }); s.lowpass(2500); return fin(s, 0.86); },
  warden_die: () => { const s = S(2.6, 54); impact(s, 0, 1.4, 200); s.noise(0.01, 0.5, 0.4, 9000, 300, 2.4, 0.001); s.tone(0, 0.6, 62, 28, 0.8, 'sine', 2.4, 0.001); s.rumble(0.05, 1.6, 0.45); for (let i = 0; i < 16; i++) s.ping(0.05 + s.rand() * 0.9, s.range(500, 3200), s.range(20, 60), 0.2, 0.02); ladder(s, 0.3, 880, [12, 7, 3, 0, -5, -12], 0.11, 80, 0.26); return fin(s, 0.95); },
  victory: () => { const s = S(2.4, 55); swell(s, 0, C5 / 2, [0, 7, 12, 16, 19], 0.22, 1.2); ladder(s, 0.1, 659.3, [0, 7, 12, 16, 19, 24], 0.09, 70, 0.3); s.add(kick(), 0, 0.6); sparkle(s, 0.3, 1.0, 0.08, 10, 2400, 6000); return fin(s, 0.84); },
  defeat: () => { const s = S(2.4, 56); swell(s, 0, 196, [0, 3, 7], 0.24, 1.3); s.analog(0.1, 1.2, 150, { amp: 0.26, shape: 'saw', unison: 2, detune: 12, cutoff: 400, env: 0, res: 0.3, attack: 0.2, decay: 1, sustain: 0.5, release: 0.6, glide: 2.0 }); s.rumble(0, 1.2, 0.3); return fin(s, 0.8); },
  cave_rumble: () => { const s = S(2.6, 57); s.rumble(0, 2.2, 0.4); s.noise(0.3, 1.2, 0.08, 400, 120, 1.4, 0.4); return fin(s, 0.5); },
  ore: () => { const s = S(0.8, 58); for (let i = 0; i < 9; i++) coin(s, s.rand() * 0.34, 0.16); return fin(s, 0.7); },
  // the creature blows: one sound a way of hurting you (content/deep_cut.json `anim`)
  hit_slam: () => { const s = S(1.0, 59); impact(s, 0, 1.3, 220); s.rumble(0.02, 0.5, 0.3); for (let i = 0; i < 4; i++) tok(s, 0.05 + s.rand() * 0.25, 0.12, s.range(400, 700)); return fin(s, 0.9); },
  hit_bite: () => { const s = S(0.6, 60); tok(s, 0, 0.4, 1400); impact(s, 0.03, 0.5, 520); tok(s, 0.075, 0.45, 1100); impact(s, 0.09, 0.6, 380); return fin(s, 0.8); },
  hit_claw: () => { const s = S(0.7, 61); whoosh(s, 0, 0.14, 0.26, 700, 2600); impact(s, 0.07, 0.7, 480); s.noise(0.07, 0.12, 0.3, 9000, 1200, 3.5, 0.0006, 1500); for (let i = 0; i < 3; i++) s.noise(0.09 + i * 0.03, 0.05, 0.2, 7000, 2000, 5, 0.001, 2000); return fin(s, 0.8); },
  hit_breath: () => { const s = S(1.3, 62); whoosh(s, 0, 0.7, 0.34, 220, 2200); s.analog(0.05, 0.6, 55, { amp: 0.3, shape: 'saw', unison: 2, detune: 12, cutoff: 150, env: 1600, res: 0.3, attack: 0.1, decay: 0.6, sustain: 0.3, release: 0.3, drive: 1.6 }); crackle(s, 0.15, 0.8, 14, 0.12); impact(s, 0.3, 0.5, 200); return fin(s, 0.8); },
  hit_spit: () => { const s = S(0.8, 63); s.noise(0, 0.06, 0.3, 3000, 1200, 4, 0.004, 400); whoosh(s, 0.02, 0.2, 0.12, 1400, 500); s.noise(0.2, 0.18, 0.35, 2200, 300, 3.4, 0.002); bubbles(s, 0.22, 0.25, 5, 200, 500, 0.16); felt(s, 0.2, 150, 0.3); return fin(s, 0.74); },
  hit_lash: () => { const s = S(0.6, 64); whoosh(s, 0, 0.12, 0.2, 500, 3200); s.noise(0.1, 0.03, 0.5, 11000, 2500, 5, 0.0005, 1200); impact(s, 0.1, 0.55, 600); return fin(s, 0.8); },
  hit_peck: () => { const s = S(0.35, 65); tok(s, 0, 0.45, 1900); impact(s, 0.005, 0.35, 900); s.ping(0, 2600, 12, 0.12, 0); return fin(s, 0.66); },
  hit_drill: () => { const s = S(0.9, 66); s.analog(0, 0.5, 90, { amp: 0.34, shape: 'square', cutoff: 400, env: 1800, res: 0.4, attack: 0.02, decay: 0.5, sustain: 0.6, release: 0.1, drive: 1.2, lfo: 0.6, lfoHz: 28 }); s.noise(0, 0.5, 0.2, 4000, 1500, 1.2, 0.02, 800); for (let i = 0; i < 10; i++) tok(s, 0.05 + i * 0.045, 0.1, s.range(600, 1000)); impact(s, 0.5, 0.6, 300); return fin(s, 0.7); },
  hit_erupt: () => { const s = S(1.2, 67); s.rumble(0, 0.5, 0.4); s.tone(0.1, 0.5, 90, 30, 0.7, 'sine', 2.8, 0.004); s.noise(0.12, 0.4, 0.45, 2600, 200, 2.4, 0.006); for (let i = 0; i < 12; i++) tok(s, 0.15 + s.rand() * 0.5, 0.14, s.range(300, 700)); impact(s, 0.14, 1.0, 180); return fin(s, 0.9); },
  hit_burst: () => { const s = S(1.0, 68); impact(s, 0, 1.1, 260); s.noise(0, 0.35, 0.45, 9000, 300, 2.6, 0.001); sparkle(s, 0.02, 0.3, 0.12, 10, 1500, 5000); s.rumble(0.02, 0.4, 0.2); return fin(s, 0.88); },
  hit_pull: () => { const s = S(0.9, 69); s.analog(0, 0.4, 220, { amp: 0.3, shape: 'saw', cutoff: 300, env: 2200, res: 0.5, attack: 0.02, decay: 0.4, sustain: 0.2, release: 0.1, glide: 1.8 }); whoosh(s, 0, 0.4, 0.16, 2000, 300); impact(s, 0.4, 0.6, 300); return fin(s, 0.74); },
  hit_drink: () => { const s = S(1.0, 70); for (let i = 0; i < 6; i++) s.tone(i * 0.11, 0.1, 180 + i * 40, 260 + i * 60, 0.22, 'sine', 3.5, 0.01); s.noise(0, 0.7, 0.12, 1200, 400, 1.4, 0.1, 300); bubbles(s, 0.1, 0.6, 6, 150, 400, 0.12); return fin(s, 0.62); },
  // the mine
  pick_strike: () => { const s = S(0.7, 71); impact(s, 0, 0.7, 500); metal(s, 0, 1180, 0.18, 0.26); for (let i = 0; i < 5; i++) tok(s, 0.06 + s.rand() * 0.3, 0.1, s.range(400, 800)); return fin(s, 0.86); },
  rock_break: () => { const s = S(1.0, 72); s.noise(0, 0.5, 0.42, 3000, 180, 2.2, 0.004); impact(s, 0, 0.9, 220); for (let i = 0; i < 9; i++) tok(s, 0.08 + s.rand() * 0.5, 0.18, s.range(300, 600)); return fin(s, 0.86); },
  stone_found: () => { const s = S(1.2, 73); ping(s, 0, 1318.5, 90, 0.36, 0.03); ping(s, 0.07, 1975.5, 80, 0.24, 0.02); sparkle(s, 0.05, 0.6, 0.1, 10, 2600, 6400); return fin(s, 0.72); },
  footstep: () => { const s = S(0.35, 74); felt(s, 0, 118, 0.5); s.noise(0, 0.13, 0.2, 2600, 480, 4, 0.001); for (let i = 0; i < 3; i++) tok(s, 0.015 + s.rand() * 0.12, 0.06, s.range(600, 1200)); return fin(s, 0.42); },
  rockfall: () => { const s = S(2.6, 75); s.rumble(0, 2.0, 0.5); for (const [t, hz] of [[0.1, 70], [0.42, 60], [0.78, 82]]) s.add(kick({ hz: hz * 2, to: hz * 0.5, dur: 0.5, click: 0.2 }), sec(t), 0.9); for (let i = 0; i < 22; i++) tok(s, 0.1 + s.rand() * 1.4, 0.2 * s.range(0.4, 1), s.range(260, 600)); s.noise(0.05, 1.6, 0.35, 2600, 160, 1.8, 0.01); return fin(s, 0.9); },
  crumble: () => { const s = S(1.8, 76); s.noise(0, 1.2, 0.3, 1800, 200, 2, 0.02); for (let i = 0; i < 16; i++) tok(s, s.rand() * 1.0, 0.2 * s.range(0.4, 1), s.range(300, 700)); felt(s, 0.05, 90, 0.4); return fin(s, 0.8); },
  tunnel: () => { const s = S(1.0, 77); whoosh(s, 0, 0.5, 0.26, 1100, 220); felt(s, 0.06, 110, 0.35); felt(s, 0.3, 96, 0.3); s.rumble(0, 0.7, 0.16); return fin(s, 0.72); },
  landing: () => { const s = S(1.8, 78); swell(s, 0, 261.6, [0, 7, 12], 0.24, 1.0); ping(s, 0.1, 1046.5, 90, 0.2, 0.02); return fin(s, 0.68); },
  lift: () => { const s = S(1.6, 79); s.analog(0, 1.0, 124, { amp: 0.3, shape: 'saw', unison: 2, detune: 9, cutoff: 200, env: 500, res: 0.3, attack: 0.2, decay: 0.8, sustain: 0.5, release: 0.3, glide: 1.4 }); s.rumble(0, 1.1, 0.34); s.noise(0, 0.9, 0.12, 1200, 300, 1.4, 0.3, 200); metal(s, 0.9, 420, 0.4, 0.24); return fin(s, 0.78); },
  depart: () => { const s = S(1.8, 80); ping(s, 0, 784, 80, 0.3, 0.02); ping(s, 0.22, 1046.5, 80, 0.28, 0.02); for (let i = 0; i < 9; i++) tok(s, 0.42 + i * 0.075 + 0.012 * i * i / 2, 0.07 * (1 - i / 12), 520); stab(s, 0.5, C5, [0, 4, 7, 12], 0.07, 1.0, { attack: 0.1 }); whoosh(s, 0.4, 1.0, 0.06, 800, 360); return fin(s, 0.36); },
  lantern: () => { const s = S(0.9, 81); whoosh(s, 0, 0.3, 0.26, 500, 2400); crackle(s, 0.05, 0.4, 8, 0.08); ping(s, 0.06, C6, 70, 0.26, 0.02); return fin(s, 0.7); },
  oddity: () => { const s = S(1.5, 82); s.ping(0, 587.3, 120, 0.3, 0.02); s.ping(0, 587.3 * 1.02, 120, 0.24, 0); s.tone(0.1, 0.7, 880, 933, 0.12, 'sine', 1.6, 0.25, 0.03, 3); sparkle(s, 0.1, 0.8, 0.08, 10, 1600, 5200); return fin(s, 0.66); },
  buy: () => { const s = S(0.7, 83); tok(s, 0, 0.3, 700); for (let i = 0; i < 5; i++) coin(s, 0.03 + s.rand() * 0.2, 0.16); return fin(s, 0.7); },
  salvage_save: () => { const s = S(0.8, 84); ping(s, 0, 1568, 80, 0.34, 0.03); sparkle(s, 0.04, 0.3, 0.08, 6, 2600, 5600); return fin(s, 0.66); },
  salvage_lose: () => { const s = S(0.7, 85); felt(s, 0, 140, 0.5); s.analog(0, 0.3, 260, { amp: 0.26, shape: 'saw', cutoff: 600, env: 0, res: 0.3, decay: 0.3, release: 0.1, glide: 2.2 }); s.lowpass(1800); return fin(s, 0.66); },
  depth_card: () => { const s = S(1.3, 86); ping(s, 0, 164.8, 110, 0.4, 0.02); s.noise(0, 0.3, 0.12, 800, 200, 2.4, 0.03); return fin(s, 0.62); },
  // the loupe and the bench
  loupe_spin: () => { const s = S(1.0, 87); s.analog(0, 0.7, 180, { amp: 0.26, shape: 'saw', cutoff: 200, env: 2200, res: 0.45, attack: 0.1, decay: 0.7, sustain: 1, release: 0.15, glide: 0.2, lfo: 0.2, lfoHz: 9 }); s.noise(0, 0.7, 0.12, 600, 3000, 0.9, 0.3, 300); return fin(s, 0.6); },
  reveal: () => { const s = S(1.5, 88); whoosh(s, 0, 0.2, 0.2, 2000, 400); ping(s, 0.05, C6, 90, 0.34, 0.03); ping(s, 0.09, C6 * 1.5, 80, 0.3, 0.02); sparkle(s, 0.05, 1.0, 0.14, 16, 2400, 7000); return fin(s, 0.82); },
  grade_rough: () => { const s = S(0.6, 89); felt(s, 0, 150, 0.5); ping(s, 0, 220, 30, 0.22, 0.01); return fin(s, 0.56); },
  grade_fine: () => { const s = S(0.9, 90); ping(s, 0, A4, 80, 0.32, 0.02); ping(s, 0.05, A4 * 1.5, 80, 0.26, 0.02); return fin(s, 0.62); },
  grade_precious: () => { const s = S(1.3, 91); ladder(s, 0, C5, [0, 4, 7], 0.06, 90, 0.34); sparkle(s, 0.1, 0.6, 0.08, 8, 2200, 5000); return fin(s, 0.72); },
  grade_exquisite: () => { const s = S(1.8, 92); ladder(s, 0, 659.3, [0, 5, 9, 12], 0.07, 100, 0.32); swell(s, 0, 329.6, [0, 5, 9], 0.14, 0.9); sparkle(s, 0.1, 1.1, 0.12, 14, 2600, 6400); return fin(s, 0.84); },
  grade_peerless: () => { const s = S(2.6, 93); ladder(s, 0, 784, [0, 4, 7, 12], 0.08, 110, 0.32); swell(s, 0.06, 196, [0, 7, 12], 0.26, 1.6); s.add(kick(), 0, 0.5); sparkle(s, 0.1, 1.7, 0.14, 18, 2600, 7600); s.rumble(0, 1.0, 0.2); return fin(s, 0.95); },
  star: () => { const s = S(1.8, 94); STAR.forEach((k, i) => ping(s, i * 0.075, C6 * Math.pow(2, k / 12), 140, 0.34, 0.03)); sparkle(s, 0.1, 1.2, 0.12, 12, 3000, 8000); return fin(s, 0.88); },
  keep: () => { const s = S(0.8, 95); felt(s, 0, 120, 0.55); tok(s, 0.02, 0.3, 520); metal(s, 0.02, 330, 0.4, 0.22); return fin(s, 0.76); },
  sell: () => { const s = S(0.9, 96); for (let i = 0; i < 11; i++) coin(s, s.rand() * 0.4, 0.16); tok(s, 0.42, 0.24, 600); return fin(s, 0.74); },
  chisel: () => { const s = S(0.8, 97); tok(s, 0, 0.34, 1500); metal(s, 0, 2350, 0.12, 0.16); s.noise(0.02, 0.22, 0.3, 4200, 700, 3, 0.002); felt(s, 0.02, 120, 0.34); for (let i = 0; i < 6; i++) tok(s, 0.1 + s.rand() * 0.4, 0.1, s.range(600, 1100)); return fin(s, 0.74); },
  gleam: () => { const s = S(2.0, 98); whoosh(s, 0, 0.45, 0.12, 900, 5600); ping(s, 0.1, 2093, 220, 0.28, 0.02); ping(s, 0.2, 3136, 200, 0.2, 0.02); sparkle(s, 0.05, 1.5, 0.16, 20, 3200, 8400); return fin(s, 0.8); },
  tally: () => { const s = S(0.35, 99); tok(s, 0, 0.22, 1700); ping(s, 0, 1760, 25, 0.2, 0.01); return fin(s, 0.5); },
  altar_hum: () => { const s = S(1.8, 100); swell(s, 0, 110, [0, 7, 12], 0.26, 1.5); ping(s, 0.2, 659.3, 110, 0.14, 0.01); ping(s, 0.25, 987.8, 110, 0.12, 0.01); sparkle(s, 0.25, 1.2, 0.08, 10, 2400, 6000); return fin(s, 0.62); },
  altar_fizzle: () => { const s = S(0.8, 101); s.noise(0, 0.18, 0.22, 4200, 900, 2.4, 0.01); s.analog(0.05, 0.3, 420, { amp: 0.2, shape: 'square', cutoff: 1200, env: 0, res: 0.4, decay: 0.3, release: 0.1, glide: 3 }); s.noise(0.22, 0.3, 0.12, 2400, 300, 3.2, 0.01); return fin(s, 0.5); },
  altar_make: () => { const s = S(2.4, 102); riser(s, 0, 0.9, 0.22, 65); ladder(s, 0, C5, [0, 4, 7, 12, 16], 0.12, 120, 0.3); stab(s, 0.65, C5, [0, 4, 7, 12], 0.22, 1.4, { attack: 0.05 }); sparkle(s, 0.6, 1.4, 0.12, 16, 2600, 7200); return fin(s, 0.86); },
  transcendent: () => { const s = S(3.0, 103); s.rumble(0, 1.2, 0.26); riser(s, 0, 1.0, 0.24, 65); ladder(s, 0, 261.6, [0, 7, 12, 16, 19, 24, 28], 0.11, 140, 0.3); swell(s, 0.8, 523.25, [0, 4, 7, 11, 14], 0.22, 2.0); swell(s, 0.8, 130.8, [0, 7, 12], 0.24, 2.0); s.add(kick(), sec(0.8), 0.6); sparkle(s, 0.7, 2.0, 0.18, 30, 2600, 8800); return fin(s, 0.97); },
  hollow_drop: () => { const s = S(2.8, 104); whoosh(s, 0, 1.1, 0.2, 2600, 140); for (let i = 0; i < 7; i++) tok(s, 0.06 * i + 0.016 * i * i, 0.34 * Math.pow(0.78, i), 1500 - 150 * i); s.tone(1.1, 0.7, 46, 20, 0.75, 'sine', 2.6, 0.002); s.rumble(1.1, 1.1, 0.36); s.analog(1.1, 0.7, 61.7, { amp: 0.2, shape: 'saw', unison: 2, detune: 12, cutoff: 150, env: 300, res: 0.3, attack: 0.01, decay: 0.6, sustain: 0.5, release: 0.6, drive: 1 }); return fin(s, 0.88); },
  hollow_rise: () => { const s = S(3.0, 105); whoosh(s, 0, 0.55, 0.22, 140, 3400); s.analog(0, 0.5, 123.5, { amp: 0.18, shape: 'saw', unison: 3, detune: 14, cutoff: 200, env: 2000, res: 0.3, attack: 0.4, decay: 0.5, sustain: 0.5, release: 0.5 }); ladder(s, 0.42, 493.9, [0, 3, 6, 10, 13, 18], 0.06, 140, 0.26); swell(s, 0.82, 246.9, [0, 6, 10, 13], 0.2, 1.6); swell(s, 0.82, 61.7, [0, 7], 0.22, 1.7); sparkle(s, 0.5, 1.7, 0.14, 22, 2400, 7800); return fin(s, 0.9); },
  reel_lever: () => { const s = S(1.2, 106); for (let i = 0; i < 7; i++) tok(s, i * 0.045, 0.2 + 0.03 * i, 700 + 110 * i); s.add(kick(), sec(0.33), 0.6); metal(s, 0.34, 880, 0.3, 0.2); whoosh(s, 0.32, 0.7, 0.22, 300, 2200); return fin(s, 0.66); },
  reel_tick: () => { const s = S(0.1, 107); tok(s, 0, 0.34, 1900); metal(s, 0, 2900, 0.06, 0.08); return fin(s, 0.46); },
  reel_stop: () => { const s = S(0.7, 108); s.add(kick({ hz: 120, to: 40 }), 0, 0.8); tok(s, 0, 0.42, 860); metal(s, 0.01, 523.25, 0.42, 0.24); return fin(s, 0.74); },
  geode_crack: () => { const s = S(1.1, 109); s.noise(0, 0.14, 0.5, 8000, 900, 3.4, 0.0008); impact(s, 0, 0.9, 240); for (let i = 0; i < 8; i++) s.ping(0.02 + s.rand() * 0.3, s.range(1500, 5000), s.range(20, 60), 0.2, 0.02); ping(s, 0.05, 1568, 120, 0.24, 0.02); for (let i = 0; i < 4; i++) tok(s, 0.18 + s.rand() * 0.3, 0.18, s.range(400, 700)); return fin(s, 0.82); },
  jackpot: () => { const s = S(2.6, 110); for (let i = 0; i < 16; i++) coin(s, s.rand() * 0.8, 0.14); ladder(s, 0.1, C5, [0, 4, 7, 12, 16], 0.09, 120, 0.3); swell(s, 0.55, C5, [0, 4, 7, 12], 0.2, 1.5); sparkle(s, 0.4, 1.6, 0.14, 24, 2600, 8000); s.add(kick(), sec(0.55), 0.5); return fin(s, 0.9); },
  contract_seal: () => { const s = S(1.8, 111); whoosh(s, 0, 0.6, 0.2, 200, 2600); felt(s, 0.55, 140, 0.5); tok(s, 0.55, 0.3, 640); ladder(s, 0.6, C5, [0, 7, 12], 0.02, 100, 0.3); sparkle(s, 0.6, 0.9, 0.1, 12, 2400, 6400); return fin(s, 0.78); },
  gem_shatter: () => { const s = S(2.4, 112); s.noise(0, 0.12, 0.45, 9000, 1400, 3.6, 0.0006); for (let i = 0; i < 14; i++) s.ping(0.01 + s.rand() * 0.4, s.range(1800, 6000), s.range(20, 60), 0.2, 0.02); for (let i = 0; i < 9; i++) tok(s, 0.2 + s.rand() * 0.5, 0.16, s.range(900, 1800)); s.analog(0.12, 0.6, 146.8, { amp: 0.2, shape: 'saw', unison: 2, detune: 10, cutoff: 500, env: 0, res: 0.3, attack: 0.06, decay: 0.6, sustain: 0.4, release: 0.6 }); s.analog(0.7, 0.8, 123.5, { amp: 0.18, shape: 'saw', unison: 2, detune: 10, cutoff: 450, env: 0, res: 0.3, attack: 0.08, decay: 0.7, sustain: 0.4, release: 0.7 }); return fin(s, 0.74); },
  infinity: () => { const s = S(3.2, 113); s.rumble(0, 1.3, 0.3); whoosh(s, 0, 0.8, 0.26, 90, 4200); ladder(s, 0, C5, [0, 4, 7, 12, 7, 4, 0, -5, 0, 4, 7, 12, 16, 19, 24], 0.065, 140, 0.24); swell(s, 1.0, C5, [0, 4, 7, 11, 14, 19], 0.22, 1.8); swell(s, 1.0, 65.4, [0, 7, 12, 19], 0.24, 1.85); s.add(kick(), sec(1.0), 0.7); sparkle(s, 0.85, 1.95, 0.2, 40, 2400, 9800); return fin(s, 0.98); },
  flame: () => { const s = S(0.9, 114); whoosh(s, 0, 0.45, 0.3, 260, 2200); s.noise(0.04, 0.6, 0.16, 1600, 500, 2.2, 0.01); crackle(s, 0.06, 0.55, 12, 0.1); s.analog(0.05, 0.4, 65, { amp: 0.16, shape: 'saw', cutoff: 150, env: 900, res: 0.2, attack: 0.1, decay: 0.4, sustain: 0.3, release: 0.2, drive: 1 }); return fin(s, 0.6); },
  splash: () => { const s = S(1.1, 115); felt(s, 0, 110, 0.5); s.noise(0, 0.7, 0.42, 4800, 500, 2.4, 0.004); bubbles(s, 0.18, 0.45, 5, 500, 700, 0.12); return fin(s, 0.62); },
  mirror: () => { const s = S(1.3, 116); ping(s, 0, 1760, 220, 0.28, 0.02); ping(s, 0.04, 2637, 200, 0.18, 0.02); sparkle(s, 0.02, 0.6, 0.08, 8, 3000, 7000); return fin(s, 0.55); },
  claw: () => { const s = S(0.5, 117); tok(s, 0, 0.4, 1400); tok(s, 0.035, 0.45, 1100); felt(s, 0.03, 190, 0.35); s.noise(0.03, 0.08, 0.15, 5000, 1500, 5); return fin(s, 0.6); },
};
const NAMES = Object.keys(SFX);

// --- the score: one engine, twenty-four specs ---------------------------------------------------
// A piece is written in four strips of one arrangement: `bed` (always), `deep` (comes up with
// depth: what grows as the party goes down), `fight` and `warden`. The room (echo) is not baked.
const PLAN = ['A', 'A2', 'B', 'ans', 'A', 'A2', 'B2', 'end'];
function motif(rng, meter, lift) {
  // The game's motif writer (composer.gd _motif): two bars of tune, mostly steps, a leap now and then.
  const beats = meter * 2, notes = []; let height = lift, beat = 0;
  const wander = (h) => { const steps = [-2, -1, -1, -1, 0, 1, 1, 1, 2, 2, 3, -3, 4]; return clamp(h + steps[Math.floor(rng() * steps.length)], lift - 3, lift + 5); };
  while (beat < beats) {
    const onset = beat * 4;
    if (beat >= beats - 2) { const hold = (beats - beat) * 4 - (rng() < 0.5 ? 2 : 0); if (notes.length) height = wander(height); notes.push([onset, hold, height]); break; }
    const roll = rng(); let cell;
    if (beat === 0) cell = roll < 0.4 ? [[0, 4]] : roll < 0.8 ? [[0, 2], [2, 2]] : [[0, 3], [3, 1]];
    else if (roll < 0.3) cell = [[0, 4]];
    else if (roll < 0.58) cell = [[0, 2], [2, 2]];
    else if (roll < 0.7) cell = [[0, 3], [3, 1]];
    else if (roll < 0.8) cell = [];
    else if (roll < 0.9 && beat + 1 < beats - 2) { cell = [[0, 8]]; beat += 1; }
    else cell = [[2, 2]];
    for (const c of cell) { if (notes.length) height = wander(height); notes.push([onset + c[0], c[1], height]); }
    beat += 1;
  }
  return notes;
}
// Voices. Each is (hz, seconds) -> samples; the spec names them.
const V = {
  pad_warm: (hz, s) => { const y = new Syn(s + 1.6, 401); y.analog(0, s, hz, { amp: 0.22, shape: 'saw', unison: 3, detune: 8, cutoff: 300, env: 700, res: 0.15, attack: 0.5, decay: 1.5, sustain: 0.5, release: 1.4, lfo: 0.3, lfoHz: 0.2 }); y.voice(0, s, hz * 0.5, 0.1, 'sine', 0.6, 1.2); return y.b; },
  pad_glass: (hz, s) => { const y = new Syn(s + 1.8, 402); y.analog(0, s, hz, { amp: 0.2, shape: 'pulse', pw: 0.18, unison: 2, detune: 6, cutoff: 500, env: 900, res: 0.3, attack: 0.6, decay: 1.8, sustain: 0.4, release: 1.6, lfo: 0.5, lfoHz: 0.17 }); y.voice(0, s, hz * 2, 0.04, 'sine', 0.8, 1.4, 1, 0, 0, 0, 0.003); return y.b; },
  pad_dark: (hz, s) => { const y = new Syn(s + 2.0, 403); y.analog(0, s, hz, { amp: 0.24, shape: 'saw', unison: 3, detune: 14, cutoff: 180, env: 400, res: 0.2, attack: 0.8, decay: 2, sustain: 0.5, release: 1.8, lfo: 0.4, lfoHz: 0.11 }); y.voice(0, s, hz * 0.5, 0.12, 'sine', 0.8, 1.4); return y.b; },
  pad_choir: (hz, s) => { const y = new Syn(s + 1.7, 404); y.voice(0, s, hz, 0.22, 'triangle', 0.7, 1.5, 3, 12, hz * 4, 0, 0.004); y.analog(0, s, hz, { amp: 0.1, shape: 'saw', unison: 2, detune: 9, cutoff: 700, env: 300, res: 0.2, attack: 0.9, decay: 2, sustain: 0.6, release: 1.5 }); return y.b; },
  lead_ping: (hz, s) => { const y = new Syn(Math.min(2.6, 150 / (Math.PI * hz) * 7) + 0.2, 405); y.ping(0, hz, 150, 0.42, 0.04); y.tone(0, 0.4, hz * 0.5, -1, 0.1, 'sine', 3, 0.003); return y.b; },
  lead_bell: (hz, s) => { const y = new Syn(Math.max(s, 0.8) + 1.2, 406); y.ping(0, hz, 260, 0.36, 0.02); y.ping(0, hz * 2.01, 120, 0.1, 0); y.tone(0, 0.3, hz, -1, 0.1, 'sine', 4, 0.002); return y.b; },
  lead_soft: (hz, s) => { const y = new Syn(s + 0.6, 407); y.analog(0, s, hz, { amp: 0.3, shape: 'triangle', cutoff: 900, env: 1400, res: 0.2, attack: 0.04, decay: 0.4, sustain: 0.3, release: 0.3, glide: 0.97 }); y.voice(0, s, hz, 0.08, 'sine', 0.05, 0.3, 1, 0, 0, 0, 0.004); return y.b; },
  lead_saw: (hz, s) => { const y = new Syn(s + 0.5, 408); y.analog(0, s, hz, { amp: 0.3, shape: 'saw', unison: 2, detune: 5, cutoff: 700, env: 1800, res: 0.3, attack: 0.015, decay: 0.3, sustain: 0.3, release: 0.2, glide: 0.94 }); return y.b; },
  seq_soft: (hz, s) => { const y = new Syn(s + 0.3, 409); y.analog(0, s * 0.8, hz, { amp: 0.26, shape: 'pulse', pw: 0.3, cutoff: 380, env: 1100, res: 0.5, decay: 0.12, sustain: 0.05, release: 0.06 }); return y.b; },
  seq_open: (hz, s) => { const y = new Syn(s + 0.3, 410); y.analog(0, s * 0.8, hz, { amp: 0.26, shape: 'pulse', pw: 0.3, cutoff: 800, env: 2600, res: 0.55, decay: 0.11, sustain: 0.05, release: 0.06 }); return y.b; },
  seq_drip: (hz, s) => { const y = new Syn(s + 0.6, 411); y.ping(0, hz, 60, 0.3, 0.02); y.tone(0, 0.08, hz, hz * 1.5, 0.12, 'sine', 4, 0.001); return y.b; },
  bass_moog: (hz, s) => { const y = new Syn(s + 0.3, 412); y.analog(0, s, hz, { amp: 0.45, shape: 'saw', cutoff: 200, env: 1500, res: 0.4, decay: 0.22, sustain: 0.15, release: 0.08, sub: 0.45, drive: 0.2 }); return y.b; },
  bass_sub: (hz, s) => { const y = new Syn(s + 0.4, 413); y.voice(0, s, hz, 0.5, 'sine', 0.012, 0.2); y.voice(0, s, hz, 0.1, 'triangle', 0.012, 0.15); return y.b; },
  bass_dirt: (hz, s) => { const y = new Syn(s + 0.3, 414); y.analog(0, s, hz, { amp: 0.5, shape: 'saw', cutoff: 160, env: 1600, res: 0.6, decay: 0.2, sustain: 0.2, release: 0.08, sub: 0.3, drive: 2.2 }); return y.b; },
  counter: (hz, s) => { const y = new Syn(s + 0.8, 415); y.analog(0, s, hz, { amp: 0.22, shape: 'triangle', cutoff: 700, env: 600, res: 0.2, attack: 0.08, decay: 0.5, sustain: 0.4, release: 0.5 }); return y.b; },
  brass: (hz, s) => { const y = new Syn(s + 0.4, 416); y.analog(0, s, hz, { amp: 0.26, shape: 'saw', unison: 3, detune: 10, cutoff: 500, env: 2200, res: 0.25, attack: 0.05, decay: 0.4, sustain: 0.5, release: 0.25 }); return y.b; },
  drone: (hz, s) => { const y = new Syn(s + 1.2, 417); y.voice(0, s, hz, 0.4, 'sine', 0.9, 1.0); y.voice(0, s, hz * 1.5, 0.08, 'sine', 1.2, 1.0); return y.b; },
};
const KITS = {
  soft: { kick: () => kick({ lp: 2600, click: 0.05 }), back: () => clap(), hat: shaker, perc: () => tom(140) },
  tok: { kick: () => kick(), back: () => snare(), hat: hat, perc: (v) => { const s = new Syn(0.1, 420 + v); tok(s, 0, 0.4, v ? 760 : 620); return s.b; } },
  drip: { kick: () => kick({ hz: 130, to: 42, lp: 2000, click: 0.03 }), back: () => { const s = new Syn(0.2, 421); tok(s, 0, 0.35, 1250); return s.b; }, hat: shaker, perc: (v) => { const s = new Syn(0.35, 422 + v); s.tone(0, 0.09, v ? 900 : 760, v ? 1800 : 1520, 0.34, 'sine', 4, 0.001); return s.b; } },
  anvil: { kick: () => Drums.taiko(), back: () => Drums.anvil({ hz: 640, amp: 0.3 }), hat: hat, perc: () => tom(120) },
  void: { kick: () => Drums.thud(), back: () => { const s = new Syn(0.2, 423); tok(s, 0, 0.3, 1250); return s.b; }, hat: hat, perc: () => { const s = new Syn(0.4, 424); s.tone(0, 0.14, 380, 760, 0.4, 'sine', 3.6, 0.001); return s.b; } },
  wood: { kick: () => kick({ lp: 3000 }), back: () => Drums.wood({ hz: 520, amp: 0.5 }), hat: shaker, perc: () => Drums.wood({ hz: 880, amp: 0.45 }) },
  glass: { kick: () => kick(), back: () => snare(), hat: hat, perc: (v) => { const s = new Syn(0.3, 425 + v); s.ping(0, v ? 1580 : 3150, 40, 0.3, 0.02); return s.b; } },
};
const GROOVES = {
  4: { pulse: { kick: 'o.......o.......', hat: '..o...o...o...o.', perc: 'x.........o.....' }, drive: { kick: 'X......xX.....x.', back: '....X.......X...', hat: 'x.o.x.o.x.o.x.ox', perc: '......o.......o.' }, fill: { perc: '........x.x.xxxX', back: '....X.......x.x.' } },
  3: { pulse: { kick: 'o...........', hat: '..o...o...o.', perc: 'x.......o...' }, drive: { kick: 'X.......x...', back: '....X...X...', hat: 'x.o.x.o.x.ox', perc: '..........o.' }, fill: { perc: '......x.xxxX', back: '....X...x.x.' } },
};
function groove(p, strip, kit, part, lvl, fills = false) {
  const g = GROOVES[p.meter][part];
  for (const role of Object.keys(g)) {
    const drum = kit[role]; if (!drum) continue;
    for (let bar = 0; bar < p.bars; bar++) {
      let line = g[role];
      if (fills && bar % 8 === 7 && GROOVES[p.meter].fill[role]) line = GROOVES[p.meter].fill[role];
      p.pattern(strip, part + ':' + role, drum, line, lvl, [bar]);
    }
  }
}
function arpBar(p, strip, name, voice, bar, order, rate, lvl, low) {
  const chord = p.chordAt(bar), at = bar * p.stepsBar;
  const first = fit(p.pitch(chord), low), lift = first - p.pitch(chord);
  const notes = [first, p.pitch(chord + 2) + lift, p.pitch(chord + 4) + lift, p.pitch(chord + 7) + lift];
  let i = 0;
  for (let s = 0; s < p.stepsBar; s += rate) { p.play(strip, name, voice, notes[order[i % order.length]], at + s, rate, lvl * (s % 4 === 0 ? 1 : 0.78)); i++; }
}
function piece(spec) {
  const p = new Piece({ bpm: spec.bpm, key: spec.key, mode: spec.mode, chords: spec.chords, bars: 16, meter: spec.meter || 4, swing: spec.swing || 0, seed: spec.seed });
  p.chordAt = (bar) => spec.chords[Math.floor(bar / 2) % spec.chords.length];
  const rng = rng32(spec.seed * 104729 + 7);
  const motifs = { A: motif(rng, p.meter, 0), B: motif(rng, p.meter, 2), C: motif(rng, p.meter, 3) };
  const notes = p.tune(PLAN, motifs);
  const bed = p.strip(), deep = p.strip(), fight = p.strip(), warden = p.strip();
  const sb = p.stepsBar, high = spec.lead_octave === 1;
  const base = fit(p.root, 52 + (high ? 7 : 0));
  const kit = KITS[spec.kit] || KITS.soft, pad = V[spec.pad] || V.pad_warm, lead = V[spec.lead] || V.lead_ping, bass = V[spec.bass] || V.bass_moog;
  const seqV = spec.seq === 'drip' ? V.seq_drip : V.seq_soft;
  for (let bar = 0; bar < p.bars; bar++) {
    const chord = p.chordAt(bar), at = bar * sb, low = fit(p.pitch(chord), p.root - 15);
    if (bar % 2 === 0) {
      for (const m of p.padNotes(chord, !!spec.sevenths, p.root + 7)) p.play(bed, 'pad', pad, m, at, 2 * sb, 0.6);
      p.play(bed, 'padroot', pad, fit(p.pitch(chord), p.root - 5), at, 2 * sb, 0.4);
      if (spec.drone !== false) p.play(bed, 'drone', V.drone, p.root - 12, at, 2 * sb, 0.5);
    }
    // the bed's pulse: bass on the one and the fifth, the sequence in eighths at a low cutoff
    p.play(bed, 'bass', bass, low, at, 7, 0.7); p.play(bed, 'bass', bass, fit(p.pitch(chord + 4), low), at + 8, sb - 9, 0.55);
    if (spec.seq !== 'off') arpBar(p, bed, 'seq', seqV, bar, spec.seq_order || [0, 2, 1, 3], 2, spec.seq === 'drip' ? 0.26 : 0.2, p.root + 12);
    // what grows with depth
    if (spec.deep === 'counter') { if (bar % 2 === 1) for (const m of p.padNotes(chord, false, p.root + 12).slice(0, 2)) p.play(deep, 'counter', V.counter, m, at + 8, 6, 0.4); }
    if (spec.deep === 'seq' || spec.deep === 'both') arpBar(p, deep, 'seqd', V.seq_open, bar, [0, 2, 3, 1, 2, 3, 0, 1], 1, 0.3, p.root + 12);
    if (spec.deep === 'sub' || spec.deep === 'both') { p.play(deep, 'subd', V.bass_sub, low - 12, at, sb - 1, 0.8); for (const s of [0, 6, 10]) p.hit(deep, 'deepkick', () => kick({ hz: 120, to: 38, dur: 0.5, lp: 1800, click: 0 }), at + s, s === 0 ? 0.6 : 0.4); }
    // the fight: bass in eighths, the sequence opened to sixteenths, brass on the one
    for (let e = 0; e < sb / 2; e++) p.play(fight, 'bassf', bass, e % 4 === 3 ? low + 12 : low, at + e * 2, 2, e % 2 === 0 ? 0.85 : 0.6);
    arpBar(p, fight, 'seqf', V.seq_open, bar, [0, 2, 3, 1, 2, 3, 0, 1], 1, 0.36, p.root + 12);
    for (const m of p.padNotes(chord, false, p.root + 7)) p.play(fight, 'brass', V.brass, m, at, 3, 0.4);
    // the Warden: dirt in the bass, a cluster under the pads, a riser into every fourth bar, toms
    for (let e = 0; e < sb / 2; e++) p.play(warden, 'bassw', V.bass_dirt, low - 12, at + e * 2, 2, 0.9);
    if (bar % 2 === 0) { p.play(warden, 'cluster', V.pad_dark, low, at, 2 * sb, 0.5); p.play(warden, 'cluster', V.pad_dark, low + 1, at, 2 * sb, 0.4); }
    if (bar % 4 === 3) p.play(warden, 'riser', (hz, s) => { const y = new Syn(s + 0.2, 430); y.noise(0, s, 0.3, 300, 8000, 0.8, s * 0.9, 200); return y.b; }, 60, at, sb, 0.6);
  }
  layTune(p, bed, 'lead', lead, notes, base, 0.62);
  layTune(p, fight, 'leadf', V.lead_saw, notes, base + (high ? 0 : 12), 0.5);
  groove(p, bed, kit, 'pulse', 0.45);
  groove(p, fight, kit, 'drive', 0.95, true);
  p.pattern(warden, 'kickw', () => kick({ hz: 150, to: 44, dur: 0.5, click: 0.2 }), p.meter === 3 ? 'X...X...X...' : 'X...X...X...X...', 1.0);
  p.pattern(warden, 'tomw', () => tom(120), p.meter === 3 ? '........x.xX' : '..........x.x.xX', 0.7, [3, 7, 11, 15]);
  for (const s of [bed, deep, fight, warden]) { s.lowpass(11000); s.saturate(1.1); }
  return { bed: level(bed, -18), deep: level(deep, -20), fight: level(fight, -18.5), warden: level(warden, -19), seconds: p.total / RATE };
}
function layTune(p, strip, name, voice, notes, base, lvl) {
  for (const n of notes) p.play(strip, name, voice, p.pitch(n[2], base), n[0], n[1], lvl * (n[0] % 4 === 0 ? 1 : 0.82));
}

// Three versions a place. Keys, modes and chords come from the score as it stands (so a place
// keeps its harmonic character); the tunes are new (new seeds), the tempos lower, the voices this kit's.
const SPECS = [
  // the workshop: warm, unhurried, the only place with no fight
  { id: 'home_a', place: 'HOME', name: 'The Bench', key: 'D', mode: 'lydian', bpm: 72, meter: 4, seed: 1101, chords: [0, 3, 0, 6, 0, 3, 4, 4], pad: 'pad_warm', bass: 'bass_sub', lead: 'lead_soft', seq: 'off', kit: 'soft', drone: false, sevenths: true, deep: 'counter', grows: 'a soft counter-line under the tune' },
  { id: 'home_b', place: 'HOME', name: 'Lamplight', key: 'F', mode: 'lydian', bpm: 66, meter: 3, seed: 1102, chords: [0, 1, 0, 4, 0, 1, 5, 4], pad: 'pad_glass', bass: 'bass_sub', lead: 'lead_bell', lead_octave: 1, seq: 'off', kit: 'soft', drone: false, sevenths: true, deep: 'counter', grows: 'a counter-line in the pads' },
  { id: 'home_c', place: 'HOME', name: 'Night Shift', key: 'A', mode: 'ionian', bpm: 78, meter: 4, seed: 1103, chords: [3, 2, 1, 0, 3, 2, 4, 0], pad: 'pad_warm', bass: 'bass_sub', lead: 'lead_ping', seq: 'soft', seq_order: [0, 1, 2, 1], kit: 'soft', drone: false, sevenths: true, deep: 'counter', grows: 'a soft counter-line' },
  // the Quarry: timber, lamp oil and dust
  { id: 'quarry_a', place: 'QUARRY', name: 'Lantern Light', key: 'D', mode: 'dorian', bpm: 84, meter: 4, seed: 2101, chords: [0, 6, 3, 0, 0, 6, 4, 4], pad: 'pad_warm', bass: 'bass_moog', lead: 'lead_ping', seq: 'soft', kit: 'wood', deep: 'seq', grows: 'the sequence opens up' },
  { id: 'quarry_b', place: 'QUARRY', name: 'Pick and Timber', key: 'E', mode: 'aeolian', bpm: 90, meter: 4, seed: 2102, chords: [0, 5, 2, 6, 0, 5, 3, 4], pad: 'pad_warm', bass: 'bass_moog', lead: 'lead_soft', seq: 'soft', seq_order: [0, 3, 2, 1], kit: 'tok', deep: 'both', grows: 'sub bass and the sequence' },
  { id: 'quarry_c', place: 'QUARRY', name: 'Old Galleries', key: 'A', mode: 'dorian', bpm: 76, meter: 3, seed: 2103, chords: [0, 3, 0, 6, 0, 3, 6, 4], pad: 'pad_choir', bass: 'bass_sub', lead: 'lead_bell', seq: 'soft', kit: 'wood', deep: 'counter', grows: 'a counter-line' },
  // the Seeps: water in every crack
  { id: 'seeps_a', place: 'SEEPS', name: 'Drowned Lanterns', key: 'C', mode: 'aeolian', bpm: 68, meter: 3, seed: 3101, chords: [0, 5, 3, 4, 0, 5, 6, 4], pad: 'pad_glass', bass: 'bass_sub', lead: 'lead_bell', lead_octave: 1, seq: 'drip', kit: 'drip', deep: 'sub', grows: 'sub bass and a slow kick' },
  { id: 'seeps_b', place: 'SEEPS', name: 'Lock and Sluice', key: 'F#', mode: 'dorian', bpm: 78, meter: 4, seed: 3102, chords: [0, 3, 0, 6, 5, 3, 6, 4], pad: 'pad_glass', bass: 'bass_moog', lead: 'lead_soft', seq: 'drip', kit: 'drip', deep: 'seq', grows: 'the drips become a sequence' },
  { id: 'seeps_c', place: 'SEEPS', name: 'The Black Sump', key: 'B', mode: 'aeolian', bpm: 62, meter: 4, seed: 3103, chords: [0, 5, 0, 6, 0, 5, 3, 4], pad: 'pad_dark', bass: 'bass_sub', lead: 'lead_bell', seq: 'drip', kit: 'drip', deep: 'both', grows: 'sub bass and the drips' },
  // the Glass Veins: crystal
  { id: 'glass_a', place: 'GLASS_VEINS', name: 'Prism Song', key: 'E', mode: 'lydian', bpm: 94, meter: 4, seed: 4101, chords: [0, 1, 0, 4, 5, 1, 3, 4], pad: 'pad_glass', bass: 'bass_sub', lead: 'lead_bell', lead_octave: 1, seq: 'soft', seq_order: [0, 1, 2, 3], kit: 'glass', deep: 'seq', grows: 'the sequence opens' },
  { id: 'glass_b', place: 'GLASS_VEINS', name: 'Kaleidoscope', key: 'G', mode: 'lydian', bpm: 86, meter: 3, seed: 4102, chords: [0, 1, 5, 4, 0, 1, 2, 4], pad: 'pad_choir', bass: 'bass_sub', lead: 'lead_ping', lead_octave: 1, seq: 'soft', kit: 'glass', deep: 'counter', grows: 'a counter-line' },
  { id: 'glass_c', place: 'GLASS_VEINS', name: 'Black Glass', key: 'C#', mode: 'phrygian', bpm: 80, meter: 4, seed: 4103, chords: [0, 1, 0, 6, 0, 1, 5, 6], pad: 'pad_dark', bass: 'bass_moog', lead: 'lead_bell', lead_octave: 1, seq: 'soft', seq_order: [0, 3, 1, 2], kit: 'glass', deep: 'both', grows: 'sub bass and the sequence' },
  // the Warrens: fungus and roots
  { id: 'warrens_a', place: 'WARRENS', name: 'Rootwork', key: 'E', mode: 'phrygian', bpm: 80, meter: 4, seed: 5101, chords: [0, 1, 0, 6, 0, 1, 3, 6], pad: 'pad_choir', bass: 'bass_moog', lead: 'lead_soft', seq: 'soft', seq_order: [0, 2, 1, 2], kit: 'wood', deep: 'seq', grows: 'the sequence opens' },
  { id: 'warrens_b', place: 'WARRENS', name: 'Spore Drift', key: 'D', mode: 'dorian', bpm: 66, meter: 3, seed: 5102, chords: [0, 3, 2, 0, 0, 3, 6, 4], pad: 'pad_warm', bass: 'bass_sub', lead: 'lead_ping', seq: 'drip', kit: 'wood', deep: 'counter', grows: 'a counter-line' },
  { id: 'warrens_c', place: 'WARRENS', name: 'Heartrot', key: 'G', mode: 'harmonic', bpm: 84, meter: 4, seed: 5103, chords: [0, 5, 3, 4, 0, 5, 1, 4], pad: 'pad_dark', bass: 'bass_moog', lead: 'lead_saw', seq: 'soft', kit: 'wood', deep: 'sub', grows: 'sub bass and a slow kick' },
  // the Furnace: lava and slag
  { id: 'furnace_a', place: 'FURNACE', name: 'Anvil Hymn', key: 'D', mode: 'harmonic', bpm: 98, meter: 4, seed: 6101, chords: [0, 5, 3, 4, 0, 5, 1, 4], pad: 'pad_dark', bass: 'bass_dirt', lead: 'lead_saw', seq: 'soft', kit: 'anvil', deep: 'seq', grows: 'the sequence opens' },
  { id: 'furnace_b', place: 'FURNACE', name: 'Slagfall', key: 'A', mode: 'phrygian_dominant', bpm: 90, meter: 4, seed: 6102, chords: [0, 1, 0, 6, 0, 1, 5, 1], pad: 'pad_dark', bass: 'bass_dirt', lead: 'lead_soft', seq: 'soft', seq_order: [0, 3, 2, 1], kit: 'anvil', deep: 'sub', grows: 'sub bass and a slow kick' },
  { id: 'furnace_c', place: 'FURNACE', name: 'Kiln Heart', key: 'F', mode: 'harmonic', bpm: 104, meter: 4, seed: 6103, chords: [0, 3, 4, 0, 5, 3, 1, 4], pad: 'pad_warm', bass: 'bass_dirt', lead: 'lead_ping', seq: 'soft', kit: 'anvil', deep: 'both', grows: 'sub bass and the sequence' },
  // the Hollow: crystal and gold
  { id: 'hollow_a', place: 'GEODE', name: 'Amethyst Throat', key: 'Bb', mode: 'lydian', bpm: 80, meter: 4, seed: 7101, chords: [0, 1, 5, 4, 0, 1, 2, 4], pad: 'pad_choir', bass: 'bass_sub', lead: 'lead_bell', lead_octave: 1, seq: 'soft', kit: 'glass', deep: 'counter', grows: 'a counter-line' },
  { id: 'hollow_b', place: 'GEODE', name: 'Gilded Hollow', key: 'Eb', mode: 'mixolydian', bpm: 88, meter: 4, seed: 7102, chords: [0, 6, 3, 0, 0, 6, 1, 4], pad: 'pad_warm', bass: 'bass_moog', lead: 'lead_soft', seq: 'soft', seq_order: [0, 1, 2, 3], kit: 'tok', deep: 'seq', grows: 'the sequence opens' },
  { id: 'hollow_c', place: 'GEODE', name: 'The Hollow Crown', key: 'C', mode: 'aeolian', bpm: 72, meter: 3, seed: 7103, chords: [0, 5, 2, 6, 0, 5, 3, 4], pad: 'pad_choir', bass: 'bass_sub', lead: 'lead_ping', lead_octave: 1, seq: 'drip', kit: 'glass', deep: 'both', grows: 'sub bass and the sequence' },
  // the Rift: below everything
  { id: 'rift_a', place: 'RIFT', name: 'The Infinite Void', key: 'B', mode: 'locrian', bpm: 60, meter: 4, seed: 8101, chords: [0, 1, 0, 6, 0, 1, 4, 6], pad: 'pad_dark', bass: 'bass_sub', lead: 'lead_bell', lead_octave: 1, seq: 'drip', kit: 'void', deep: 'sub', grows: 'sub bass and a slow kick' },
  { id: 'rift_b', place: 'RIFT', name: 'Remembered', key: 'F#', mode: 'phrygian', bpm: 70, meter: 3, seed: 8102, chords: [0, 1, 6, 0, 0, 1, 5, 6], pad: 'pad_choir', bass: 'bass_sub', lead: 'lead_ping', seq: 'soft', kit: 'void', deep: 'counter', grows: 'a counter-line' },
  { id: 'rift_c', place: 'RIFT', name: 'Unmaking', key: 'D', mode: 'phrygian_dominant', bpm: 82, meter: 4, seed: 8103, chords: [0, 1, 0, 6, 5, 1, 6, 1], pad: 'pad_dark', bass: 'bass_dirt', lead: 'lead_saw', seq: 'soft', seq_order: [0, 3, 1, 2], kit: 'void', deep: 'both', grows: 'sub bass and the sequence' },
];
const byId = {}; for (const s of SPECS) byId[s.id] = s;

root.DeepSoundMV2 = { SFX, NAMES, SPECS, byId, piece: (id) => piece(byId[id]), _k: { ping, felt, tok, sqk, stab, swell, ladder, sparkle, metal, coin, riser, kick, hat, shaker, clap, snare, tom, impact, whoosh, crackle, bubbles, fin, S, V, KITS, GROOVES, groove, arpBar, motif, layTune, PLAN, C5, C6, PENTA, STAR, sec } };
})(typeof self !== 'undefined' ? self : globalThis);

// =============================================================================================
// Round 3: the sounds the owner flagged, each in two new versions; three Benches for the
// workshop; three fires for the Furnace; and the six picked pieces made to last (one riff a
// place, a longer form with rests, the lead a step back).
// =============================================================================================
(function (root) {
'use strict';
const C = root.DeepSoundCore, M = root.DeepSoundMV2, K = M._k;
const { RATE, Syn, Drums, Piece, midiHz, fit, clamp, posmod, rng32, CHIME, METAL, level } = C;
const { ping, felt, tok, ladder, sparkle, metal, coin, kick, tom, whoosh, crackle, fin, S, V, KITS, GROOVES, groove, arpBar, motif, layTune } = K;
const sec = (s) => Math.round(s * RATE);

// --- more kit: stone, wood, air and weight (nothing with a filter sweep) -----------------------
// A sub-render: a few seconds of its own, shaped as a whole (tremolo), then laid in.
const sub = (dur, seed, fn) => { const y = new Syn(dur, seed); fn(y); return y.b; };
// A stone crack: a short bright burst and two low-Q inharmonic rings.
const crack = (s, at, amp = 0.4, hz = 1800, dur = 0.03) => { s.noise(at, dur, amp, 7000, 1200, 4.5, 0.0005, 600); s.ping(at, hz, 9, amp * 0.5, 0); s.ping(at, hz * 1.37, 7, amp * 0.3, 0); return s; };
// Debris: small grains falling in band and loudness.
const crunch = (s, at, dur, n = 7, amp = 0.2, hi = 3500, lo = 700) => { for (let i = 0; i < n; i++) { const t = i / n; s.noise(at + t * dur + s.rand() * dur * 0.08, 0.02 + s.rand() * 0.02, amp * (1 - t * 0.6) * s.range(0.5, 1), hi * (1 - t * 0.6), lo, 4.5, 0.0008, 300); } return s; };
// A knock: a damped pluck (wood or stone) over felt.
const knock = (s, at, hz = 240, amp = 0.4, damping = 0.93, soft = 0.4) => { s.pluck(at, 0.14, hz, amp, damping, soft); felt(s, at, hz * 0.6, amp * 0.5); return s; };
// A warm chime: a ring, its octave, a sine body.
const chime = (s, at, hz, amp = 0.3, dur = 0.8) => { s.ping(at, hz, 70, amp, 0); s.ping(at, hz * 2.0, 40, amp * 0.18, 0); s.tone(at, Math.min(dur, 0.4), hz * 0.5, -1, amp * 0.15, 'sine', 3, 0.004); return s; };
// Air with a soft front.
const breath = (s, at, dur, amp, f0, f1, attack = 0.3) => s.noise(at, dur, amp, f0, f1, 1.6, dur * attack, Math.min(f0, f1) * 0.5);
// The low weight of a blow.
const boom = (s, at, amp = 0.5, hz = 110, dur = 0.35) => s.tone(at, dur, hz, 38, amp, 'sine', 3.0, 0.001);
// Toks that quicken or slow.
const rattle = (s, at, dur, n, amp, hz0 = 700, accel = 1.0) => { let t = at, gap = dur / n; for (let i = 0; i < n; i++) { tok(s, t, amp * s.range(0.6, 1), hz0 * s.range(0.85, 1.15)); t += gap; gap *= accel; } return s; };
// A growl: low noise and a wobbling sub, chopped by a slow tremolo.
const growl = (s, at, dur, amp, hz = 24, seed = 900) => { s.add(sub(dur, seed, y => { y.noise(0, dur, amp, 900, 250, 1.4, dur * 0.3, 120); y.tone(0, dur, 58, 52, amp * 0.8, 'sine', 1.5, dur * 0.3, 0.02, 5); y.tremolo(hz, 0.85); }), sec(at), 1); return s; };

// --- the flagged sounds, two new versions each ----------------------------------------------------
const SFX3 = {
  // interface: "confirm sounds slightly like an error" (the falling pulse run after the pings)
  ui_confirm: {
    a: () => { const s = S(0.8, 2001); felt(s, 0, 200, 0.16); ping(s, 0, 659.3, 30, 0.4, 0.02); ping(s, 0.09, 987.8, 40, 0.38, 0.02); return fin(s, 0.56); },
    b: () => { const s = S(0.9, 2002); felt(s, 0, 210, 0.18); ping(s, 0, 783.99, 36, 0.4, 0.02); [987.8, 1174.7].forEach((hz, i) => s.ping(0.08 + i * 0.05, hz, 30, 0.14, 0)); return fin(s, 0.56); },
  },
  ui_back: {
    a: () => { const s = S(0.5, 2003); felt(s, 0, 180, 0.3); ping(s, 0, 440, 14, 0.36, 0.015); return fin(s, 0.46); },
    b: () => { const s = S(0.4, 2004); tok(s, 0, 0.34, 520); felt(s, 0.004, 170, 0.28); s.ping(0.03, 392, 10, 0.16, 0); return fin(s, 0.46); },
  },
  ui_open: {
    a: () => { const s = S(0.7, 2005); felt(s, 0, 230, 0.2); s.noise(0, 0.09, 0.1, 500, 2400, 2.2, 0.03, 300); ping(s, 0.05, 1046.5, 22, 0.34, 0.015); return fin(s, 0.5); },
    b: () => { const s = S(0.5, 2006); tok(s, 0, 0.3, 500); tok(s, 0.045, 0.3, 700); felt(s, 0, 220, 0.2); s.ping(0.045, 1318.5, 12, 0.12, 0); return fin(s, 0.5); },
  },
  ui_close: {
    a: () => { const s = S(0.6, 2007); ping(s, 0, 784, 14, 0.3, 0.015); s.noise(0, 0.09, 0.1, 2400, 500, 2.2, 0.02, 300); felt(s, 0.07, 160, 0.34); return fin(s, 0.5); },
    b: () => { const s = S(0.5, 2008); tok(s, 0, 0.3, 700); tok(s, 0.045, 0.32, 500); felt(s, 0.05, 150, 0.3); return fin(s, 0.5); },
  },
  toast_bad: {
    a: () => { const s = S(0.7, 2009); felt(s, 0, 120, 0.5); s.ping(0.01, 330, 12, 0.3, 0); s.lowpass(1600); return fin(s, 0.5); },
    b: () => { const s = S(0.6, 2010); tok(s, 0, 0.3, 420); tok(s, 0.11, 0.3, 330); felt(s, 0.11, 130, 0.4); s.lowpass(2500); return fin(s, 0.5); },
  },
  unlock: {
    a: () => { const s = S(1.2, 2011); felt(s, 0, 200, 0.2); ladder(s, 0, 587.3, [0, 7, 12], 0.09, 50, 0.32); sparkle(s, 0.25, 0.4, 0.06, 6, 2000, 4800); return fin(s, 0.6); },
    b: () => { const s = S(1.4, 2012); felt(s, 0, 190, 0.2); [523.25, 784, 1046.5].forEach((hz, i) => chime(s, i * 0.02, hz, 0.26 - i * 0.04, 0.8)); s.noise(0.02, 0.3, 0.05, 1500, 4000, 1.8, 0.1, 1200); return fin(s, 0.6); },
  },
  // dice: "lock and die breaks are both too grating"
  dice_lock: {
    a: () => { const s = S(0.5, 2013); knock(s, 0, 240, 0.4, 0.93, 0.4); s.ping(0.012, 880, 9, 0.12, 0); return fin(s, 0.6); },
    b: () => { const s = S(0.4, 2014); tok(s, 0, 0.36, 620); tok(s, 0.03, 0.3, 420); felt(s, 0.03, 150, 0.3); return fin(s, 0.6); },
  },
  die_break: {
    a: () => { const s = S(0.8, 2015); crack(s, 0, 0.4, 900, 0.05); crunch(s, 0.02, 0.3, 7, 0.2, 2800, 600); for (let i = 0; i < 4; i++) s.ping(0.02 + s.rand() * 0.2, s.range(900, 1800), 14, 0.1, 0); felt(s, 0, 160, 0.4); s.lowpass(4500, 2); return fin(s, 0.6); },
    b: () => { const s = S(0.8, 2016); knock(s, 0, 180, 0.4, 0.9, 0.3); s.tone(0, 0.02, 1200, 300, 0.3, 'triangle', 5, 0.0005); crack(s, 0.005, 0.3, 1400, 0.03); [700, 560, 430].forEach((hz, i) => tok(s, 0.09 + i * 0.07, 0.18 - i * 0.04, hz)); s.lowpass(5500); return fin(s, 0.6); },
  },
  // gems: red (no note), blue and green "ok but could be better", violet "like an error", gold "too long", fizzle "more subtle"
  gem_red: {
    a: () => { const s = S(0.8, 2017); felt(s, 0, 120, 0.5); crack(s, 0, 0.35, 1200, 0.03); s.ping(0.005, 220, 20, 0.3, 0); s.noise(0.01, 0.16, 0.18, 2200, 300, 2.6, 0.004, 200); return fin(s, 0.66); },
    b: () => { const s = S(0.9, 2018); boom(s, 0, 0.5, 120, 0.3); whoosh(s, 0.0, 0.22, 0.2, 300, 1400); crackle(s, 0.03, 0.3, 5, 0.12); s.ping(0.01, 196, 16, 0.26, 0); return fin(s, 0.66); },
  },
  gem_blue: {
    a: () => { const s = S(1.3, 2019); ping(s, 0, 1174.7, 80, 0.44, 0.02); s.ping(0.03, 1760, 50, 0.12, 0); felt(s, 0, 220, 0.08); return fin(s, 0.6); },
    b: () => { const s = S(1.5, 2020); s.ping(0, 987.8, 110, 0.36, 0.015); s.ping(0, 987.8 * 1.004, 110, 0.3, 0); s.tone(0, 0.5, 493.9, -1, 0.08, 'sine', 3, 0.01); return fin(s, 0.6); },
  },
  gem_green: {
    a: () => { const s = S(1.1, 2021); felt(s, 0, 200, 0.1); s.tone(0, 0.25, 392, 784, 0.16, 'sine', 1.6, 0.03); ping(s, 0.12, 784, 40, 0.3, 0.01); sparkle(s, 0.15, 0.3, 0.04, 4, 1600, 3600); return fin(s, 0.6); },
    b: () => { const s = S(1.1, 2022); ping(s, 0, 784, 36, 0.32, 0.01); ping(s, 0.06, 1174.7, 36, 0.26, 0.01); s.noise(0, 0.3, 0.06, 500, 2500, 1.6, 0.1, 400); return fin(s, 0.6); },
  },
  gem_violet: {
    a: () => { const s = S(1.4, 2023); s.ping(0, 740, 60, 0.3, 0.01); s.ping(0, 740 * 1.006, 60, 0.24, 0); s.ping(0.05, 1108.7, 50, 0.18, 0); s.ping(0.05, 1108.7 * 0.994, 50, 0.14, 0); s.noise(0.0, 0.5, 0.07, 400, 1800, 1.5, 0.15, 300); return fin(s, 0.62); },
    b: () => { const s = S(1.5, 2024); s.bell(0, 1.0, 740, 0.3, CHIME, 2.4, 0.4); s.voice(0.0, 0.5, 370, 0.12, 'triangle', 0.2, 0.3, 2, 9, 1200); felt(s, 0, 180, 0.12); return fin(s, 0.62); },
  },
  gem_gold: {
    a: () => { const s = S(0.7, 2025); coin(s, 0, 0.2); coin(s, 0.05, 0.18); ping(s, 0.02, 1174.7, 40, 0.34, 0.02); return fin(s, 0.62); },
    b: () => { const s = S(0.8, 2026); ladder(s, 0, 587.3, [0, 7, 12], 0.03, 45, 0.34); sparkle(s, 0.05, 0.25, 0.07, 6, 2400, 5600); return fin(s, 0.62); },
  },
  gem_fizzle: {
    a: () => { const s = S(0.4, 2027); s.noise(0, 0.12, 0.2, 1200, 300, 2.8, 0.01, 200); felt(s, 0, 150, 0.2); return fin(s, 0.3); },
    b: () => { const s = S(0.4, 2028); tok(s, 0, 0.3, 330); s.noise(0.01, 0.1, 0.12, 900, 300, 3, 0.005, 150); s.lowpass(1800); return fin(s, 0.3); },
  },
  // the count: multiplier, fuse and blaze flagged without a note (the squelch and the saw stab, I take it)
  tally_mult: {
    a: () => { const s = S(0.8, 2029); felt(s, 0, 110, 0.5); ping(s, 0, 261.6, 40, 0.4, 0.01); s.ping(0.02, 523.25, 30, 0.14, 0); return fin(s, 0.62); },
    b: () => { const s = S(0.7, 2030); s.thump(0, 0.14, 90, 0.5, 0.2); ping(s, 0, 523.25, 30, 0.34, 0.02); s.fm(0, 0.25, 261.6, { ratio: 2, index: 1.8, decay: 3, amp: 0.2, curve: 3, attack: 0.001 }); return fin(s, 0.62); },
  },
  tally_fuse: {
    a: () => { const s = S(0.9, 2031); ping(s, 0, 523.25, 50, 0.3, 0.01); ping(s, 0.04, 784, 50, 0.28, 0.01); ping(s, 0.1, 1046.5, 60, 0.32, 0.01); s.noise(0, 0.2, 0.08, 1500, 400, 2, 0.1, 300); sparkle(s, 0.1, 0.25, 0.05, 4, 2400, 5000); return fin(s, 0.66); },
    b: () => { const s = S(0.9, 2032); felt(s, 0, 200, 0.14); ladder(s, 0, 523.25, [0, 7, 12], 0.03, 50, 0.3); s.voice(0.0, 0.3, 523.25, 0.12, 'triangle', 0.05, 0.2, 2, 8, 1800); return fin(s, 0.66); },
  },
  tally_blaze: {
    a: () => { const s = S(1.1, 2033); whoosh(s, 0, 0.4, 0.28, 200, 2200); crackle(s, 0.05, 0.6, 12, 0.14); s.thump(0, 0.4, 80, 0.5, 0.3); ladder(s, 0.05, 523.25, [0, 4, 7], 0.04, 60, 0.26); return fin(s, 0.7); },
    b: () => { const s = S(1.2, 2034); s.noise(0, 0.25, 0.2, 400, 4000, 1.2, 0.2, 300); [523.25, 659.3, 784, 1046.5].forEach((hz, i) => s.ping(0.22 + i * 0.01, hz, 70, 0.22, 0.01)); crackle(s, 0.25, 0.5, 8, 0.1); s.rumble(0.2, 0.5, 0.2); return fin(s, 0.7); },
  },
  // your blows: "too much like simple drums". A gem strikes stone: a crack, debris, weight.
  hit_light: {
    a: () => { const s = S(0.4, 2035); felt(s, 0, 140, 0.3); crack(s, 0, 0.42, 2400, 0.025); s.tone(0, 0.09, 180, 90, 0.3, 'sine', 4, 0.001); return fin(s, 0.68); },
    b: () => { const s = S(0.4, 2036); s.noise(0, 0.04, 0.14, 1500, 4000, 2, 0.015, 800); knock(s, 0.035, 520, 0.36, 0.9, 0.3); crack(s, 0.035, 0.3, 2000, 0.02); return fin(s, 0.68); },
  },
  hit_heavy: {
    a: () => { const s = S(0.7, 2037); s.thump(0, 0.3, 120, 0.6, 0.3); crack(s, 0, 0.42, 900, 0.045); crunch(s, 0.02, 0.18, 6, 0.2, 3000, 600); s.ping(0.005, 260, 20, 0.2, 0); return fin(s, 0.84); },
    b: () => { const s = S(0.7, 2038); knock(s, 0, 180, 0.5, 0.9, 0.3); crack(s, 0.003, 0.36, 1100, 0.04); s.rumble(0.01, 0.25, 0.2); crunch(s, 0.04, 0.2, 5, 0.16, 2600, 500); return fin(s, 0.84); },
  },
  hit_crit: {
    a: () => { const s = S(1.0, 2039); s.thump(0, 0.35, 120, 0.6, 0.3); crack(s, 0, 0.48, 900, 0.05); crunch(s, 0.02, 0.3, 8, 0.22, 3200, 600); for (let i = 0; i < 6; i++) s.ping(0.01 + s.rand() * 0.12, s.range(1500, 4000), 18, 0.1, 0); s.tone(0.005, 0.4, 55, 40, 0.5, 'sine', 2.6, 0.001); s.ping(0.03, 1318.5, 50, 0.16, 0); return fin(s, 0.9); },
    b: () => { const s = S(1.0, 2040); s.noise(0, 0.012, 0.2, 6000, 2000, 5, 0.0005); crack(s, 0.012, 0.5, 700, 0.06); boom(s, 0.012, 0.6, 100, 0.45); crunch(s, 0.04, 0.35, 8, 0.2, 3000, 500); metal(s, 0.015, 620, 0.5, 0.14); return fin(s, 0.9); },
  },
  block: {
    a: () => { const s = S(0.5, 2041); s.pluck(0, 0.12, 330, 0.4, 0.9, 0.5); felt(s, 0, 170, 0.36); s.noise(0, 0.03, 0.2, 2000, 600, 4.5, 0.0005, 300); return fin(s, 0.66); },
    b: () => { const s = S(0.6, 2042); ping(s, 0, 440, 30, 0.32, 0.02); felt(s, 0, 160, 0.4); s.clack(0, 0.16, 700); return fin(s, 0.66); },
  },
  // creature blows: windup "like a tuba", drill "too electronic", pull "too high, stands out"
  enemy_windup: {
    a: () => { const s = S(0.9, 2043); s.noise(0, 0.5, 0.26, 200, 1500, 1.2, 0.4, 150); s.rumble(0, 0.6, 0.3); rattle(s, 0.1, 0.4, 7, 0.1, 500, 0.86); return fin(s, 0.66); },
    b: () => { const s = S(0.9, 2044); growl(s, 0, 0.55, 0.4, 22, 2044); breath(s, 0, 0.5, 0.12, 300, 1800, 0.5); return fin(s, 0.66); },
  },
  hit_drill: {
    a: () => { const s = S(0.9, 2045); for (let i = 0; i < 14; i++) s.pluck(0.02 + i * 0.028, 0.06, s.range(280, 330), 0.22, 0.85, 0.3); s.add(sub(0.5, 2045, y => { y.noise(0, 0.5, 0.26, 1200, 3000, 1.0, 0.02, 700); y.tremolo(35, 0.8); }), 0, 1); crack(s, 0.44, 0.3, 900, 0.04); felt(s, 0.44, 120, 0.3); return fin(s, 0.7); },
    b: () => { const s = S(0.9, 2046); s.add(sub(0.5, 2046, y => { y.noise(0, 0.5, 0.3, 800, 3000, 1.0, 0.02, 500); y.tremolo(30, 0.9); }), 0, 1); for (let i = 0; i < 10; i++) tok(s, 0.03 + i * 0.047, 0.1, s.range(500, 800)); s.thump(0.48, 0.2, 110, 0.4, 0.25); return fin(s, 0.7); },
  },
  hit_pull: {
    a: () => { const s = S(0.9, 2047); whoosh(s, 0, 0.4, 0.2, 900, 200); felt(s, 0.02, 120, 0.3); s.rumble(0.05, 0.4, 0.2); s.pluck(0.4, 0.2, 110, 0.4, 0.95, 0.5); felt(s, 0.4, 100, 0.4); return fin(s, 0.6); },
    b: () => { const s = S(0.9, 2048); crack(s, 0, 0.3, 700, 0.03); s.noise(0.03, 0.35, 0.18, 1600, 300, 1.3, 0.05, 150); s.thump(0.36, 0.25, 110, 0.5, 0.25); return fin(s, 0.6); },
  },
  // effects: curse "a bit more spooky"
  curse: {
    a: () => { const s = S(1.6, 2049); s.ping(0, 185, 120, 0.3, 0); s.ping(0, 187.2, 120, 0.26, 0); s.noise(0, 0.9, 0.1, 1200, 200, 1.6, 0.2, 150); s.tone(0.05, 1.0, 92.5, 90, 0.2, 'sine', 1.8, 0.2, 0.015, 5); s.ping(0.3, 2637, 60, 0.04, 0); s.ping(0.55, 2217, 60, 0.035, 0); return fin(s, 0.6); },
    b: () => { const s = S(1.6, 2050); s.ping(0, 370, 90, 0.3, 0); s.ping(0.18, 349.2, 110, 0.3, 0); s.add(sub(1.2, 2050, y => { y.noise(0, 1.2, 0.14, 900, 300, 1.4, 0.3, 300); y.tremolo(3, 0.6); }), 0, 1); s.rumble(0.05, 0.9, 0.16); return fin(s, 0.6); },
  },
  // outcomes: creature dies "too watery, a bit of an error message"
  creature_die: {
    a: () => { const s = S(1.3, 2051); crack(s, 0, 0.4, 800, 0.05); crunch(s, 0.03, 0.5, 10, 0.22, 3000, 500); s.add(Drums.thud(), 0, 0.6); for (let i = 0; i < 4; i++) s.ping(0.05 + s.rand() * 0.3, s.range(300, 700), 20, 0.1, 0); s.noise(0.3, 0.5, 0.08, 600, 200, 1.6, 0.1, 100); return fin(s, 0.82); },
    b: () => { const s = S(1.3, 2052); knock(s, 0, 140, 0.5, 0.92, 0.4); for (let i = 0; i < 3; i++) s.ping(0.02 + s.rand() * 0.15, s.range(900, 2000), 20, 0.08, 0); s.rumble(0.02, 0.5, 0.3); s.tone(0.12, 0.3, 220, 110, 0.14, 'sine', 2.2, 0.02); crunch(s, 0.1, 0.35, 6, 0.14, 2200, 400); return fin(s, 0.82); },
  },
  // the mine: landing "too stand-out", lift and salvage lost "too electronic"
  landing: {
    a: () => { const s = S(1.4, 2053); felt(s, 0, 150, 0.3); chime(s, 0.02, 523.25, 0.22, 0.8); s.noise(0.0, 0.3, 0.06, 1200, 300, 2, 0.02, 200); return fin(s, 0.44); },
    b: () => { const s = S(1.0, 2054); s.thump(0, 0.3, 90, 0.5, 0.25); crunch(s, 0.04, 0.3, 5, 0.1, 1800, 400); s.rumble(0, 0.4, 0.14); return fin(s, 0.44); },
  },
  lift: {
    a: () => { const s = S(1.6, 2055); for (let i = 0; i < 7; i++) s.pluck(0.05 + s.rand() * 0.7, 0.1, s.range(900, 1400), 0.12, 0.92, 0.2); s.rumble(0, 1.1, 0.34); whoosh(s, 0.1, 0.9, 0.12, 200, 900); s.clack(1.0, 0.3, 600); felt(s, 1.0, 120, 0.4); return fin(s, 0.72); },
    b: () => { const s = S(1.6, 2056); s.add(sub(1.2, 2056, y => { y.tone(0, 1.2, 60, 58, 0.5, 'sine', 1.2, 0.15); y.tremolo(7, 0.5); }), 0, 1); s.rumble(0, 1.2, 0.3); rattle(s, 0.1, 0.8, 9, 0.08, 800, 1.0); whoosh(s, 0.2, 0.8, 0.1, 150, 700); s.clack(1.05, 0.26, 500); return fin(s, 0.72); },
  },
  salvage_lose: {
    a: () => { const s = S(0.9, 2057); felt(s, 0, 110, 0.5); crunch(s, 0.02, 0.3, 6, 0.18, 2000, 400); s.ping(0.01, 196, 20, 0.22, 0); s.lowpass(3000); return fin(s, 0.6); },
    b: () => { const s = S(0.8, 2058); tok(s, 0, 0.34, 330); tok(s, 0.13, 0.3, 247); felt(s, 0.13, 110, 0.4); s.rumble(0.1, 0.4, 0.14); s.noise(0.15, 0.3, 0.06, 800, 200, 2, 0.05, 100); return fin(s, 0.6); },
  },
  // the bench: loupe spins "like an error beep"
  loupe_spin: {
    a: () => { const s = S(1.0, 2059); let t = 0.02, gap = 0.06; for (let i = 0; i < 20 && t < 0.8; i++) { tok(s, t, 0.12, 1800); t += gap; gap = Math.max(0.028, gap * 0.9); } s.noise(0, 0.8, 0.08, 500, 1200, 1.2, 0.2, 300); return fin(s, 0.5); },
    b: () => { const s = S(1.0, 2060); for (let i = 0; i < 16; i++) s.pluck(0.03 + i * 0.045, 0.05, 2400, 0.14, 0.8, 0.2); s.add(sub(0.8, 2060, y => { y.tone(0, 0.8, 120, 118, 0.3, 'sine', 1.4, 0.05); y.tremolo(11, 0.5); }), 0, 1); felt(s, 0, 180, 0.2); return fin(s, 0.5); },
  },
  // rites: altar fizzles "like a laser beam"
  altar_fizzle: {
    a: () => { const s = S(0.9, 2061); s.noise(0, 0.3, 0.2, 2000, 500, 2.4, 0.01, 300); crackle(s, 0.02, 0.4, 6, 0.1); s.ping(0.0, 330, 30, 0.22, 0); felt(s, 0, 150, 0.2); return fin(s, 0.5); },
    b: () => { const s = S(0.9, 2062); breath(s, 0, 0.25, 0.18, 1800, 400, 0.1); [520, 400, 310].forEach((hz, i) => tok(s, 0.12 + i * 0.09, 0.2 - i * 0.04, hz)); s.noise(0.3, 0.4, 0.06, 700, 200, 1.8, 0.05, 100); return fin(s, 0.5); },
  },
};
const FIXES = Object.keys(SFX3);

// --- the score, round 3 --------------------------------------------------------------------------
// One riff a place: the sequence (the most repeated thing in a piece) has a pattern of its own in
// every place, and so does the bass. The form is 24 bars with rests in the tune, so a tune is heard
// less often; the lead sits a step back. A picked piece keeps its two motifs; its third is new, in
// the place's own dialect.
const SEQS = {
  folk:    { rate: 2, line: 'x.x.x.x.x.x.....', order: [0, 2, 1, 3, 0, 2], voice: 'seq_soft' },
  drip:    { rate: 2, rand: 0.32, order: [3, 1, 2, 0], voice: 'seq_drip' },
  prism:   { rate: 1, line: 'xxxx............', order: [0, 1, 2, 3], voice: 'seq_drip', every: 2 },
  creep:   { rate: 3, order: [0, 1], voice: 'seq_soft', low: -12 },
  hammer:  { rate: 2, line: 'X.x.x.x.X.x.x.x.', order: [0, 0, 0, 2], voice: 'seq_soft', low: -12 },
  glitter: { rate: 2, line: '....x.x.....x.x.', order: [0, 2, 1, 3], voice: 'seq_drip' },
  void:    { rate: 4, line: 'x...............', order: [0], voice: 'seq_drip', every: 2, low: -12 },
  soft:    { rate: 2, order: [0, 2, 1, 3], voice: 'seq_soft' },
};
const BASS = {
  walk:   (p, strip, v, bar, low, chord) => { const at = bar * p.stepsBar, sb = p.stepsBar; p.play(strip, 'bass', v, low, at, 7, 0.7); p.play(strip, 'bass', v, fit(p.pitch(chord + 4), low), at + 8, sb - 9, 0.55); },
  pedal:  (p, strip, v, bar, low) => { p.play(strip, 'bass', v, low, bar * p.stepsBar, p.stepsBar - 1, 0.7); },
  pulse:  (p, strip, v, bar, low) => { const at = bar * p.stepsBar; p.play(strip, 'bass', v, low, at, 5, 0.7); p.play(strip, 'bass', v, low, at + 6, 3, 0.45); p.play(strip, 'bass', v, low, at + 10, 5, 0.55); },
  drip:   (p, strip, v, bar, low) => { p.play(strip, 'bass', v, low, bar * p.stepsBar, 6, 0.7); },
  hammer: (p, strip, v, bar, low) => { const at = bar * p.stepsBar; for (let q = 0; q < p.stepsBar; q += 4) p.play(strip, 'bass', v, low, at + q, 3, q === 0 ? 0.75 : 0.5); },
};
// Dialects: how a place's tune wanders.
const DIALECTS = {
  plain:  { steps: [-2, -1, -1, -1, 0, 1, 1, 1, 2, 2, 3, -3, 4], rest: 0.1, long: 0.1, lo: -3, hi: 5 },
  folk:   { steps: [-2, -1, -1, 0, 1, 1, 2, 2, 3, -3], rest: 0.08, long: 0.14, lo: -3, hi: 6, dotted: true },
  slow:   { steps: [-1, -1, 0, 0, 1, 1, -2, 2], rest: 0.22, long: 0.4, lo: -4, hi: 3 },
  bright: { steps: [-3, -2, 2, 3, 4, -4, 1, -1, 5], rest: 0.08, long: 0.12, lo: -2, hi: 8 },
  creep:  { steps: [-1, -1, 1, 1, 0, 0, -2, 2, -1], rest: 0.18, long: 0.2, lo: -4, hi: 2 },
  hammer: { steps: [0, 0, 0, -1, 1, 0, 0, 2, -2], rest: 0.05, long: 0.05, lo: -2, hi: 3 },
  grand:  { steps: [2, 2, -2, -2, 3, -3, 1, -1, 4], rest: 0.1, long: 0.2, lo: -2, hi: 7 },
  void:   { steps: [-1, -1, -2, 0, 0, 1, -3], rest: 0.35, long: 0.55, lo: -5, hi: 2 },
};
function motif3(rng, meter, lift, d) {
  const beats = meter * 2, notes = []; let height = lift, beat = 0;
  const wander = (h) => clamp(h + d.steps[Math.floor(rng() * d.steps.length)], lift + d.lo, lift + d.hi);
  while (beat < beats) {
    const onset = beat * 4;
    if (beat >= beats - 2) { const hold = (beats - beat) * 4 - (rng() < 0.5 ? 2 : 0); if (notes.length) height = wander(height); notes.push([onset, hold, height]); break; }
    const roll = rng(); let cell;
    if (beat > 0 && roll < d.rest) cell = [];
    else if (roll < d.rest + d.long && beat + 1 < beats - 2) { cell = [[0, 8]]; beat += 1; }
    else { const r2 = rng(); cell = r2 < 0.4 ? [[0, 4]] : r2 < 0.75 ? [[0, 2], [2, 2]] : d.dotted ? [[0, 3], [3, 1]] : [[0, 2], [2, 2]]; }
    for (const c of cell) { if (notes.length) height = wander(height); notes.push([onset + c[0], c[1], height]); }
    beat += 1;
  }
  return notes;
}
// The tune with rests: '-' slots are silent; the engine's tune() is run on the played slots and
// the notes moved back to their real places (the chords follow).
function tuneWithRests(p, plan, motifs, chords) {
  const real = [], compact = [];
  plan.forEach((k, i) => { if (k !== '-') { real.push(i); compact.push(k); } });
  const saved = p.chordAt; p.chordAt = (bar) => chords[real[Math.floor(bar / 2)] % chords.length];
  const notes = p.tune(compact, motifs); p.chordAt = saved;
  const slot = 2 * p.stepsBar;
  return notes.map(n => { const k = Math.floor(n[0] / slot); return [real[k] * slot + (n[0] - k * slot), n[1], n[2]]; });
}
const PLAN24 = ['A', 'A2', 'B', 'ans', '-', '-', 'A', 'C', 'B2', 'end', '-', '-'];
const PLAN_REST = ['A', 'A2', '-', 'B', 'ans', '-', '-', 'C', 'C2', '-', 'A', 'end'];
const PLAN_SPARSE = ['A', '-', 'A2', '-', 'B', 'ans', '-', '-', 'C', '-', 'B2', 'end'];
// Voices for the fires and the Bench.
const V3 = {
  embers: (hz, s) => { const y = new Syn(s + 0.3, 440 + Math.round(hz)); crackle(y, 0, s, Math.round(s * 7), 0.16); y.noise(0, s, 0.04, 400, 250, 1, s * 0.3, 60); y.lowpass(3200); return y.b; },
  bellows: (hz, s) => { const y = new Syn(s + 0.4, 441); y.noise(0, s, 0.3, 250, 1600, 1.3, s * 0.45, 150); y.lowpass(2400); return y.b; },
  heat: (hz, s) => { const y = new Syn(s + 2.0, 442); y.voice(0, s, hz, 0.22, 'saw', 0.8, 1.6, 3, 16, hz * 3); y.voice(0, s, hz * 0.5, 0.12, 'sine', 0.8, 1.4); y.tremolo(5.5, 0.3); return y.b; },
  lead_hum: (hz, s) => { const y = new Syn(s + 0.8, 443); y.voice(0, s, hz, 0.26, 'triangle', 0.08, 0.35, 2, 5, hz * 4, 0, 0.004, 0); y.voice(0, s, hz * 2, 0.03, 'sine', 0.1, 0.3); y.lowpass(1800); return y.b; },
  lead_horn: (hz, s) => { const y = new Syn(s + 0.5, 444); y.analog(0, s, hz, { amp: 0.3, shape: 'saw', unison: 2, detune: 6, cutoff: 500, env: 1400, res: 0.2, attack: 0.04, decay: 0.4, sustain: 0.6, release: 0.3, drive: 1.0, glide: 0.95 }); return y.b; },
};
const voice3 = (name, fallback) => V3[name] || V[name] || fallback;
function seqBar(p, strip, name, voice, bar, sq, lvl, low, rng) {
  if (!sq) return;
  if (sq.every && bar % sq.every !== 0) return;
  const chord = p.chordAt(bar), at = bar * p.stepsBar;
  const first = fit(p.pitch(chord), low + (sq.low || 0)), lift = first - p.pitch(chord);
  const notes = [first, p.pitch(chord + 2) + lift, p.pitch(chord + 4) + lift, p.pitch(chord + 7) + lift];
  let i = 0;
  for (let s = 0; s < p.stepsBar; s += sq.rate) {
    const mark = sq.line ? sq.line[s % sq.line.length] : 'x';
    if (mark === '.') { i++; continue; }
    if (sq.rand && rng() > sq.rand) { i++; continue; }
    const acc = mark === 'X' ? 1.15 : (s % 4 === 0 ? 1 : 0.78);
    p.play(strip, name, voice, notes[sq.order[i % sq.order.length]], at + s, sq.rate, lvl * acc); i++;
  }
}
function piece3(spec) {
  const bars = spec.bars || 24;
  const chords = spec.chords.length >= bars / 2 ? spec.chords : spec.chords.concat(spec.chords.slice(0, 2), spec.chords.slice(6, 8));
  const p = new Piece({ bpm: spec.bpm, key: spec.key, mode: spec.mode, chords, bars, meter: spec.meter || 4, swing: spec.swing || 0, swing8: spec.swing8 || 0, seed: spec.seed });
  p.chordAt = (bar) => chords[Math.floor(bar / 2) % chords.length];
  const rng = rng32(spec.seed * 104729 + 7), drng = rng32(spec.seed * 7919 + 3);
  const d = DIALECTS[spec.dialect] || DIALECTS.plain;
  const motifs = spec.newTune
    ? { A: motif3(rng, p.meter, 0, d), B: motif3(rng, p.meter, 2, d), C: motif3(rng, p.meter, 3, d) }
    : { A: motif(rng, p.meter, 0), B: motif(rng, p.meter, 2), C: motif3(rng, p.meter, 3, d) };
  const notes = tuneWithRests(p, spec.plan || PLAN24, motifs, chords);
  const bed = p.strip(), deep = p.strip(), fight = p.strip(), warden = p.strip();
  const sb = p.stepsBar, high = spec.lead_octave === 1;
  const base = fit(p.root, 52 + (high ? 7 : 0));
  const kit = KITS[spec.kit] || KITS.soft, pad = voice3(spec.pad, V.pad_warm), pad2 = spec.pad2 ? voice3(spec.pad2) : null, lead = voice3(spec.lead, V.lead_ping), bass = voice3(spec.bass, V.bass_moog);
  const sq = SEQS[spec.seq] || null, seqV = sq ? V[sq.voice] : null, bassBar = BASS[spec.bassStyle] || BASS.walk;
  const fightOrder = sq && sq.order.length >= 4 ? sq.order : [0, 2, 3, 1, 2, 3, 0, 1];
  const fire = (spec.texture || '').split('+');
  for (let bar = 0; bar < bars; bar++) {
    const chord = p.chordAt(bar), at = bar * sb, low = fit(p.pitch(chord), p.root - 15);
    if (bar % 2 === 0) {
      for (const m of p.padNotes(chord, !!spec.sevenths, p.root + 7)) p.play(bed, 'pad', pad, m, at, 2 * sb, 0.6);
      p.play(bed, 'padroot', pad, fit(p.pitch(chord), p.root - 5), at, 2 * sb, 0.4);
      if (pad2) for (const m of p.padNotes(chord, false, p.root + 12).slice(0, 2)) p.play(bed, 'pad2', pad2, m, at, 2 * sb, 0.3);
      if (spec.drone !== false) p.play(bed, 'drone', V.drone, p.root - 12, at, 2 * sb, 0.5);
    }
    bassBar(p, bed, bass, bar, low, chord);
    if (sq) seqBar(p, bed, 'seq', seqV, bar, sq, spec.seq_level || (sq.voice === 'seq_drip' ? 0.26 : 0.2), p.root + 12, drng);
    if (fire.includes('embers')) { p.play(bed, 'embers', V3.embers, 60 + bar % 4, at, sb, 0.3); p.play(deep, 'embersd', V3.embers, 64 + bar % 4, at, sb, 0.5); }
    if (fire.includes('bellows') && bar % 2 === 1) p.play(bed, 'bellows', V3.bellows, 60, at, sb, 0.3);
    // what grows with depth
    if (spec.deep === 'counter') { if (bar % 2 === 1) for (const m of p.padNotes(chord, false, p.root + 12).slice(0, 2)) p.play(deep, 'counter', V.counter, m, at + 8, 6, 0.4); }
    if (spec.deep === 'seq' || spec.deep === 'both') arpBar(p, deep, 'seqd', V.seq_open, bar, fightOrder, 1, 0.3, p.root + 12);
    if (spec.deep === 'sub' || spec.deep === 'both') { p.play(deep, 'subd', V.bass_sub, low - 12, at, sb - 1, 0.8); for (const s of [0, 6, 10]) p.hit(deep, 'deepkick', () => kick({ hz: 120, to: 38, dur: 0.5, lp: 1800, click: 0 }), at + s, s === 0 ? 0.6 : 0.4); }
    // the fight: bass in eighths, the sequence opened to sixteenths, brass on the one
    for (let e = 0; e < sb / 2; e++) p.play(fight, 'bassf', bass, e % 4 === 3 ? low + 12 : low, at + e * 2, 2, e % 2 === 0 ? 0.85 : 0.6);
    arpBar(p, fight, 'seqf', V.seq_open, bar, fightOrder, 1, 0.36, p.root + 12);
    for (const m of p.padNotes(chord, false, p.root + 7)) p.play(fight, 'brass', V.brass, m, at, 3, 0.4);
    // the Warden: dirt in the bass, a cluster under the pads, a riser into every fourth bar, toms
    for (let e = 0; e < sb / 2; e++) p.play(warden, 'bassw', V.bass_dirt, low - 12, at + e * 2, 2, 0.9);
    if (bar % 2 === 0) { p.play(warden, 'cluster', V.pad_dark, low, at, 2 * sb, 0.5); p.play(warden, 'cluster', V.pad_dark, low + 1, at, 2 * sb, 0.4); }
    if (bar % 4 === 3) p.play(warden, 'riser', (hz, s) => { const y = new Syn(s + 0.2, 430); y.noise(0, s, 0.3, 300, 8000, 0.8, s * 0.9, 200); return y.b; }, 60, at, sb, 0.6);
  }
  layTune(p, bed, 'lead', lead, notes, base, spec.lead_level || 0.52);
  layTune(p, fight, 'leadf', V.lead_saw, notes, base + (high ? 0 : 12), 0.5);
  const gv = spec.groove || 'pulse';
  if (gv === 'pulse') groove(p, bed, kit, 'pulse', spec.groove_level || 0.45);
  else if (gv === 'brush') for (let bar = 1; bar < bars; bar += 2) p.pattern(bed, 'brush', kit.hat, GROOVES[p.meter].pulse.hat, 0.3, [bar]);
  groove(p, fight, kit, 'drive', 0.95, true);
  p.pattern(warden, 'kickw', () => kick({ hz: 150, to: 44, dur: 0.5, click: 0.2 }), p.meter === 3 ? 'X...X...X...' : 'X...X...X...X...', 1.0);
  p.pattern(warden, 'tomw', () => tom(120), p.meter === 3 ? '........x.xX' : '..........x.x.xX', 0.7, [3, 7, 11, 15, 19, 23].filter(b => b < bars));
  for (const s of [bed, deep, fight, warden]) { s.lowpass(11000); s.saturate(1.1); }
  return { bed: level(bed, -18), deep: level(deep, -20), fight: level(fight, -18.5), warden: level(warden, -19), seconds: p.total / RATE };
}
// The specs: the picked pieces' keys, chords, tempos and seeds, so the tunes are the ones picked.
const B = M.byId;
const from = (id, patch) => Object.assign({}, B[id], patch);
const SPECS3 = [
  // the workshop: the Bench three ways (the tune you picked each time)
  from('home_a', { id: 'home3_a', name: 'The Bench', plan: PLAN_REST, dialect: 'plain', groove: 'pulse', groove_level: 0.38, lead_level: 0.5, bassStyle: 'walk', grows: 'a soft counter-line under the tune', what: 'As picked: the same tune, now 24 bars with four bars of rest in each half, the lead a step back, the kit a touch softer.' }),
  from('home_a', { id: 'home3_b', name: 'The Bench, hummed', bpm: 70, swing8: 0.22, lead: 'lead_hum', pad2: 'pad_glass', plan: PLAN_REST, dialect: 'plain', groove: 'brush', lead_level: 0.5, bassStyle: 'walk', grows: 'a soft counter-line under the tune', what: 'The same tune hummed: a warm, slightly breathy voice in place of the soft lead, a lazy swing, glass pads behind the warm ones, only a brush of shaker every other bar.' }),
  from('home_a', { id: 'home3_c', name: 'The Bench at dusk', bpm: 64, pad: 'pad_glass', lead_octave: 1, plan: PLAN_SPARSE, dialect: 'slow', groove: 'none', lead_level: 0.42, bassStyle: 'pedal', grows: 'a soft counter-line under the tune', what: 'Slower and emptier: glass pads, the tune an octave up and quieter, the bass a long pedal, no drums at all, and the tune away for half the time.' }),
  // the Furnace: three fires (A\'s key and tune under the first)
  from('furnace_a', { id: 'furnace3_a', name: 'Forge Fire', bpm: 96, seq: 'hammer', bassStyle: 'hammer', dialect: 'hammer', texture: 'embers+bellows', deep: 'seq', grows: 'the embers and the sequence', what: 'Anvil Hymn\'s tune over a fire: embers crackling under everything, a bellows breathing every second bar, the bass and the sequence hammering the root.' }),
  { id: 'furnace3_b', place: 'FURNACE', name: 'Magma Choir', key: 'A', mode: 'phrygian_dominant', bpm: 84, meter: 4, seed: 6201, chords: [0, 1, 0, 6, 0, 1, 5, 1], pad: 'heat', bass: 'bass_dirt', lead: 'lead_horn', seq: 'hammer', seq_level: 0.16, kit: 'anvil', bassStyle: 'pedal', dialect: 'hammer', newTune: true, texture: 'embers', deep: 'sub', lead_level: 0.46, grows: 'sub bass, a slow kick and more embers', what: 'Slower and heavier: a shimmering heat pad, a horn-like lead, the bass a long pedal, embers under it all, taiko in the fight.' },
  { id: 'furnace3_c', place: 'FURNACE', name: 'Bellows and Anvil', key: 'D', mode: 'harmonic', bpm: 100, meter: 3, seed: 6301, chords: [0, 5, 3, 4, 0, 5, 1, 4], pad: 'pad_dark', bass: 'bass_dirt', lead: 'lead_saw', seq: 'hammer', kit: 'anvil', bassStyle: 'hammer', dialect: 'hammer', newTune: true, texture: 'embers+bellows', deep: 'both', grows: 'sub bass, the sequence and more embers', what: 'In three: a hammer-and-bellows swing, a new tune in the same key, embers and breath, the sequence and sub bass coming up with depth.' },
  // the six picks, made to last
  from('quarry_a', { id: 'quarry3', seq: 'folk', bassStyle: 'walk', dialect: 'folk', what: 'Sequence: eighths that leave the last beat open. Bass: root and fifth. New third phrase in a folk step.' }),
  from('seeps_a', { id: 'seeps3', seq: 'drip', bassStyle: 'drip', dialect: 'slow', plan: PLAN_REST, what: 'Sequence: drips that fall where they will. Bass: one note a bar. New third phrase slow and low; the tune rests more.' }),
  from('glass_b', { id: 'glass3', seq: 'prism', bassStyle: 'pedal', dialect: 'bright', what: 'Sequence: a four-note flourish on the one of every other bar, then nothing. Bass: a pedal. New third phrase wide and high.' }),
  from('warrens_b', { id: 'warrens3', seq: 'creep', bassStyle: 'pulse', dialect: 'creep', what: 'Sequence: two low notes creeping in dotted eighths. Bass: a limping pulse. New third phrase narrow and sickly.' }),
  from('hollow_a', { id: 'hollow3', seq: 'glitter', bassStyle: 'walk', dialect: 'grand', what: 'Sequence: glints in pairs on the backbeats. Bass: root and fifth. New third phrase in wide, open leaps.' }),
  from('rift_a', { id: 'rift3', seq: 'void', bassStyle: 'drip', dialect: 'void', plan: PLAN_SPARSE, what: 'Sequence: one low drip every two bars. Bass: one note a bar. New third phrase nearly still; the tune away half the time.' }),
];
const byId3 = {}; for (const s of SPECS3) byId3[s.id] = s;
root.DeepSoundMV3 = { SFX3, FIXES, SPECS3, byId3, piece3: (id) => piece3(byId3[id]), _k3: { sub, crack, crunch, knock, chime, breath, boom, rattle, growl, V3, SEQS, BASS, DIALECTS } };
})(typeof self !== 'undefined' ? self : globalThis);
// =============================================================================================
// Round 4: the five sounds sent back from round 3, two more versions each (C and D).
// Red and Violet had no note; the other three did:
//   fizzle  "more like a fizzle sound rather than a dull thud"
//   altar   "more of a musical loss/fail sound effect"
//   landing "can be musical a little bit, just not as fanfare like as the original"
// Every tuned sound sits in the bank's C-major palette (C D E G A B). Violet's old F# (740 Hz)
// was the one note outside it, a tritone against everything else: the alarm in it.
// =============================================================================================
(function (root) {
'use strict';
const C = root.DeepSoundCore, M = root.DeepSoundMV2, M3 = root.DeepSoundMV3, K = M._k;
const { Syn, GLASS, TINE } = C;
const { ping, felt, tok, crackle, fin, S } = K;
// Dust: small lowpassed grains, the altar's smoke or the lift's settling.
const dust = (s, at, dur, n, amp, hi = 1600, lo = 400) => { for (let i = 0; i < n; i++) { const t = i / n; s.noise(at + t * dur + s.rand() * dur * 0.1, 0.02 + s.rand() * 0.02, amp * (1 - t * 0.5) * s.range(0.5, 1), hi * (1 - t * 0.5), lo, 4, 0.001, 200); } return s; };
// Fizz: a cloud of tiny grains whose band falls as it dies, soda in a glass.
const fizz = (s, at, dur, n, amp, hi0 = 5500, lo0 = 3000, fall = 0.5) => { for (let i = 0; i < n; i++) { const t = s.rand(); const k = 1 - t * fall; s.noise(at + t * dur, 0.006 + s.rand() * 0.008, amp * (1 - t * 0.7) * s.range(0.4, 1), hi0 * k, lo0 * k, 5, 0.0004, lo0 * k * 0.4); } return s; };
// Embers lowpassed: the warmth under red.
const embers = (s, at, dur, n, amp) => { const y = new Syn(dur + 0.05, 4100 + n); crackle(y, 0, dur, n, amp); y.lowpass(2000, 3); s.add(y.b, Math.round(at * C.RATE), 1); return s; };

const SFX4 = {
  gem_red: {
    // C: a low D ping with its fifth, heat under it (lowpassed embers and a warm breath), felt in front.
    c: () => { const s = S(0.9, 4001); felt(s, 0, 110, 0.4); ping(s, 0, 293.66, 44, 0.4, 0.02); s.ping(0.01, 440, 36, 0.16, 0); s.noise(0.0, 0.14, 0.09, 900, 300, 2.4, 0.01, 150); embers(s, 0.02, 0.3, 6, 0.12); return fin(s, 0.66); },
    // D: a brass flare, two FM strikes (A3 and E4) with weight under and embers after; lowpassed.
    d: () => { const s = S(0.9, 4002); s.thump(0, 0.16, 95, 0.4, 0.2); s.fm(0, 0.34, 220, { ratio: 1, index: 2.2, decay: 2.6, amp: 0.3, curve: 3, attack: 0.004 }); s.fm(0.02, 0.3, 329.63, { ratio: 1, index: 1.8, decay: 3, amp: 0.16, curve: 3, attack: 0.004 }); embers(s, 0.05, 0.3, 5, 0.1); s.lowpass(4500); return fin(s, 0.66); },
  },
  gem_violet: {
    // C: a tapped wine glass on E5 (inharmonic partials), a low E body swelling under, one faint glint far above.
    c: () => { const s = S(1.3, 4003); s.bell(0, 0.9, 659.26, 0.3, GLASS, 2.6, 0); s.tone(0, 0.45, 164.81, -1, 0.1, 'sine', 2, 0.08); s.ping(0.06, 2637, 30, 0.05, 0); felt(s, 0, 160, 0.08); return fin(s, 0.6); },
    // D: a music-box pair rising a minor third (A5 to C6) with a breath of air rising under them.
    d: () => { const s = S(1.3, 4004); s.bell(0, 0.8, 880, 0.26, TINE, 2.8, 0); s.bell(0.09, 0.8, 1046.5, 0.22, TINE, 2.8, 0); s.noise(0, 0.35, 0.06, 400, 1600, 1.6, 0.15, 300); felt(s, 0, 180, 0.1); return fin(s, 0.6); },
  },
  gem_fizzle: {
    // C: fizz only, a cloud of tiny grains falling in band as it dies, and a soft breath; nothing tuned, nothing struck.
    c: () => { const s = S(0.5, 4005); fizz(s, 0, 0.28, 26, 0.14); s.noise(0, 0.25, 0.07, 2500, 800, 2.2, 0.02, 500); s.lowpass(6500); return fin(s, 0.3); },
    // D: a sputter, a breathy "pff" then five grains slowing and fading, a muted click where it should have rung.
    d: () => { const s = S(0.5, 4006); s.noise(0, 0.14, 0.18, 1800, 500, 3, 0.004, 300); tok(s, 0, 0.12, 260); let t = 0.06, gap = 0.03; for (let i = 0; i < 5; i++) { s.noise(t, 0.012, 0.1 * (1 - i * 0.15), 3000, 1200, 5, 0.0005, 800); t += gap; gap *= 1.35; } s.lowpass(5000); return fin(s, 0.3); },
  },
  altar_fizzle: {
    // C: a falling third (E5 to C5) as two warm pings on felt, smoke hissing out under them.
    c: () => { const s = S(1.1, 4007); ping(s, 0, 659.26, 60, 0.34, 0.01); ping(s, 0.14, 523.25, 70, 0.3, 0.01); felt(s, 0.14, 150, 0.2); s.noise(0.1, 0.4, 0.07, 1500, 400, 2, 0.05, 200); dust(s, 0.2, 0.4, 5, 0.06); return fin(s, 0.5); },
    // D: a sigh, three soft plucks stepping down (D5, C5, A4) over a low body, a breath let out.
    d: () => { const s = S(1.3, 4008); [[0, 587.33, 0.3], [0.13, 523.25, 0.26], [0.28, 440, 0.24]].forEach(([at, hz, amp]) => s.pluck(at, 0.7, hz, amp, 0.985, 0.5)); s.tone(0.05, 0.6, 110, -1, 0.08, 'sine', 1.6, 0.1); s.noise(0.2, 0.5, 0.06, 900, 250, 1.8, 0.2, 150); s.lowpass(5000); return fin(s, 0.5); },
  },
  landing: {
    // C: the lift sets down (a thump, a little dust, rumble), then one warm C4 ping with a quiet octave.
    c: () => { const s = S(1.3, 4009); s.thump(0, 0.25, 80, 0.4, 0.25); dust(s, 0.03, 0.3, 5, 0.08); s.rumble(0, 0.5, 0.12); ping(s, 0.08, 261.63, 70, 0.26, 0.01); s.ping(0.1, 523.25, 50, 0.1, 0); return fin(s, 0.5); },
    // D: a thump, then two soft plucks a fourth apart (G4 up to C5) over a low C body: arrived, not announced.
    d: () => { const s = S(1.3, 4010); s.thump(0, 0.2, 90, 0.35, 0.2); s.pluck(0.06, 0.7, 392, 0.28, 0.99, 0.4); s.pluck(0.22, 0.8, 523.25, 0.28, 0.99, 0.4); s.tone(0.2, 0.5, 130.81, -1, 0.08, 'sine', 1.8, 0.05); s.noise(0, 0.4, 0.05, 1200, 300, 2, 0.1, 200); s.lowpass(5000); return fin(s, 0.5); },
  },
};
for (const name of Object.keys(SFX4)) Object.assign(M3.SFX3[name], SFX4[name]);
const FIXES4 = Object.keys(SFX4);
root.DeepSoundMV4 = { SFX4, FIXES4, _k4: { dust, fizz, embers } };
})(typeof self !== 'undefined' ? self : globalThis);
// =============================================================================================
// Round 5: the three sounds sent back from round 4, two more versions each (E and F).
//   violet  "Think about poison and debuffs. Less chime/bell sounding"
//   fizzle  "A little too high pitched/grating. Keep it subtle."
//   landing "You walk into the landing, not the lift descending to it. It should feel like a
//            rest stop / short break vibe"
// Violet gems are Hex, Venom, Miasma, Curse, Bind, Dread, Mist, Etch, Hemlock, Arsenic, Contagion:
// nothing rings. The landing is the camp between mines: the lamp goes down, the pack comes off.
// =============================================================================================
(function (root) {
'use strict';
const C = root.DeepSoundCore, M = root.DeepSoundMV2, M3 = root.DeepSoundMV3, M4 = root.DeepSoundMV4, K = M._k, K4 = M4._k4;
const { felt, tok, bubbles, crackle, fin, S } = K;
const { fizz, embers } = K4;

const SFX5 = {
  gem_violet: {
    // E: venom. A low G hum with a sickly waver, a hiss, one slow bubble; felt in front, no ring.
    e: () => { const s = S(1.0, 5001); felt(s, 0, 140, 0.2); s.tone(0, 0.5, 196, -1, 0.22, 'sine', 2.2, 0.01, 0.02, 7); s.tone(0.02, 0.4, 294, -1, 0.06, 'triangle', 2.6, 0.02, 0.02, 7); s.noise(0, 0.45, 0.12, 1400, 300, 2, 0.02, 250); bubbles(s, 0.08, 0.3, 2, 130, 260, 0.12); s.lowpass(3000, 2); return fin(s, 0.6); },
    // F: miasma. A gurgle of five bubbles, a sour low pair beating against each other, a cloud of hiss spreading out.
    f: () => { const s = S(1.0, 5002); felt(s, 0, 150, 0.16); bubbles(s, 0.02, 0.4, 5, 150, 330, 0.14); s.tone(0.02, 0.45, 220, -1, 0.12, 'sine', 2, 0.03, 0.01, 5); s.tone(0.02, 0.45, 233.08, -1, 0.1, 'sine', 2, 0.03, 0.01, 5.5); s.noise(0.05, 0.5, 0.08, 500, 1600, 1.6, 0.12, 300); s.lowpass(3000, 2); return fin(s, 0.6); },
  },
  gem_fizzle: {
    // E: the fizz of round 4 brought down two octaves and lowpassed twice; fewer grains, quieter.
    e: () => { const s = S(0.5, 5003); fizz(s, 0, 0.26, 18, 0.1, 2200, 900, 0.5); s.noise(0, 0.22, 0.06, 1200, 400, 2.2, 0.03, 300); s.lowpass(2500, 2); return fin(s, 0.26); },
    // F: a damp puff on felt and four soft grains fading; nothing above 2 kHz.
    f: () => { const s = S(0.5, 5004); s.noise(0, 0.16, 0.14, 900, 300, 3, 0.006, 150); felt(s, 0, 120, 0.12); for (let i = 0; i < 4; i++) s.noise(0.05 + i * 0.045, 0.014, 0.08 * (1 - i * 0.2), 1500, 600, 5, 0.0005, 400); s.lowpass(2200); return fin(s, 0.26); },
  },
  landing: {
    // E: the pack comes off (a soft cloth thump), the lantern clicks, embers under a quiet C and G humming: a breath out.
    e: () => { const s = S(1.4, 5005); felt(s, 0, 100, 0.3); s.noise(0, 0.08, 0.12, 600, 200, 3, 0.004, 80); tok(s, 0.12, 0.1, 900); embers(s, 0.15, 0.6, 8, 0.1); s.tone(0.2, 0.7, 261.63, -1, 0.07, 'sine', 1.6, 0.15); s.tone(0.2, 0.7, 392, -1, 0.05, 'sine', 1.6, 0.18); s.lowpass(4000); return fin(s, 0.46); },
    // F: a match struck, the lamp glass set, one soft low C pluck, a breath let out.
    f: () => { const s = S(1.4, 5006); s.noise(0, 0.05, 0.2, 2500, 800, 4, 0.002, 500); crackle(s, 0.04, 0.2, 3, 0.06); tok(s, 0.22, 0.12, 1200); s.pluck(0.3, 0.8, 261.63, 0.22, 0.99, 0.5); s.noise(0.3, 0.6, 0.05, 800, 250, 1.6, 0.2, 150); s.lowpass(3500); return fin(s, 0.46); },
  },
};
for (const name of Object.keys(SFX5)) Object.assign(M3.SFX3[name], SFX5[name]);
const FIXES5 = Object.keys(SFX5);
root.DeepSoundMV5 = { SFX5, FIXES5 };
})(typeof self !== 'undefined' ? self : globalThis);
// =============================================================================================
// Round 6: the whole bank reviewed with the picks in place. Every proposal is a 'g' version of
// a sound that was never flagged (or, for six of them, a level or note change to a pick).
//   collisions: Close and Lock were the same two toks; Back and Block the same A4 ping; the
//               white and blue ticks identical; Mirror was a find's ping-and-sparkle.
//   off-key:    Tab and Toggle sat on F sharp, Pick on C sharp, Exquisite in A major, the battle
//               drone on B flat, the loupe's motor on B flat.
//   levels:     Deny 15 dB louder than any other interface sound, the green tick 7 dB over its
//               siblings, the altar's hum as loud as a victory, Breath the loudest blow, Blue the
//               quietest gem, Turn begins a little proud.
//   stone:      twelve creature and mine blows still used the drum-like impact the player's
//               blows lost in round 3; here they strike stone too.
//   warm:       the saw-pad swell in the big moments (the voice the landing lost) on a softer
//               triangle pad, same chords.
// =============================================================================================
(function (root) {
'use strict';
const C = root.DeepSoundCore, M = root.DeepSoundMV2, M3 = root.DeepSoundMV3, K = M._k, K3 = M3._k3;
const { Syn, Drums, GLASS } = C;
const { ping, felt, tok, ladder, sparkle, metal, coin, riser, kick, whoosh, crackle, fin, S, C5, C6, sec } = K;
const { sub, crack, crunch } = K3;

// A gem on stone: a crack, debris, weight. The kit the owner picked for the player's blows,
// sized like the old impact() so each recipe keeps its proportions.
const impact2 = (s, at, size = 1, hz = 330) => {
  crack(s, at, 0.42 * Math.min(1.2, size), hz * 2.6, 0.03 * size);
  crunch(s, at + 0.02, 0.18 * size, Math.round(4 + 3 * size), 0.18 * size, 3000, 600);
  s.thump(at, 0.25 * size, 120 / Math.sqrt(size), 0.5 * size, 0.3);
  return s;
};
// The same chord as swell(), on a triangle pad with a sine root under it, lowpassed: warm, not brassy.
const swell2 = (s, at, root, steps, amp = 0.24, dur = 0.7) => {
  for (const k of steps) { const hz = root * Math.pow(2, k / 12); s.voice(at, dur, hz, amp * 0.9, 'triangle', Math.min(0.3, dur * 0.35), dur * 0.7, 2, 6, 2200, 0, 0.004, 0); s.tone(at, dur * 1.2, hz * 0.5, -1, amp * 0.25, 'sine', 1.5, dur * 0.3); }
  return s;
};

const G = {
  // --- collisions ---------------------------------------------------------------------------
  // Close: the same two toks as Lock, a fifth higher and lighter, the lid heavier.
  ui_close: () => { const s = S(0.5, 6001); tok(s, 0, 0.26, 1050); tok(s, 0.045, 0.28, 780); felt(s, 0.05, 140, 0.36); return fin(s, 0.5); },
  // Block: the ping drops from A4 (Back's note) to E4 and the stone clack comes forward.
  block: () => { const s = S(0.6, 6002); ping(s, 0, 329.63, 26, 0.3, 0.02); felt(s, 0, 160, 0.4); s.clack(0, 0.22, 700); s.noise(0, 0.03, 0.15, 2500, 700, 4.5, 0.0005, 300); return fin(s, 0.66); },
  // White tick: the Invert gem's count on glass partials, as pure as its firing sound.
  tick_white: () => { const s = S(0.3, 6003); s.bell(0, 0.25, C5, 0.4, GLASS, 3.5, 0); s.ping(0, C5 * 2, 30, 0.08, 0); return fin(s, 0.5); },
  // Mirror: a breath drawn in and two glass notes, no sparkle; a find rings and glitters, this inhales.
  mirror: () => { const s = S(1.3, 6004); s.noise(0, 0.35, 0.12, 300, 3000, 1.6, 0.3, 300); s.bell(0.3, 0.8, 1760, 0.28, GLASS, 2.4, 0); s.bell(0.34, 0.7, 2637, 0.16, GLASS, 2.4, 0); return fin(s, 0.55); },
  // --- off-key ------------------------------------------------------------------------------
  ui_tab: () => { const s = S(0.3, 6005); felt(s, 0, 240, 0.3); ping(s, 0, 784, 9, 0.22, 0.01); return fin(s, 0.36); },
  ui_toggle: () => { const s = S(0.3, 6006); tok(s, 0, 0.3, 900); ping(s, 0.004, 1568, 10, 0.26, 0.02); return fin(s, 0.5); },
  die_pick: () => { const s = S(0.2, 6007); tok(s, 0, 0.24, 900); s.ping(0, 1046.5, 10, 0.16, 0); return fin(s, 0.42); },
  // Exquisite: F major (the IV) instead of A major, so the grades climb I, IV, V, I; on the warm pad.
  grade_exquisite: () => { const s = S(1.8, 6008); ladder(s, 0, 698.46, [0, 4, 7, 12], 0.07, 100, 0.32); swell2(s, 0, 349.23, [0, 4, 7], 0.14, 0.9); sparkle(s, 0.1, 1.1, 0.12, 14, 2600, 6400); return fin(s, 0.84); },
  // Battle begins: the drone on C2 instead of B flat, 3 dB back.
  battle_begin: () => { const s = S(1.8, 6009); riser(s, 0, 1.2, 0.34, 65.4); s.rumble(0, 1.3, 0.3); s.add(kick({ hz: 140, to: 40, dur: 0.6 }), sec(1.2), 1); s.analog(1.2, 0.3, 65.4, { amp: 0.4, shape: 'saw', cutoff: 120, env: 400, res: 0.2, decay: 0.3, release: 0.2, drive: 1.2 }); return fin(s, 0.55); },
  // Loupe spins: the motor hums on C3.
  loupe_spin: () => { const s = S(1.0, 6010); for (let i = 0; i < 16; i++) s.pluck(0.03 + i * 0.045, 0.05, 2400, 0.14, 0.8, 0.2); s.add(sub(0.8, 6010, y => { y.tone(0, 0.8, 130.81, 128.6, 0.3, 'sine', 1.4, 0.05); y.tremolo(11, 0.5); }), 0, 1); felt(s, 0, 180, 0.2); return fin(s, 0.5); },
  // --- levels -------------------------------------------------------------------------------
  ui_deny: () => { const s = S(0.5, 6011); for (const at of [0, 0.11]) s.analog(at, 0.09, 180, { amp: 0.45, shape: 'square', cutoff: 600, env: 900, res: 0.3, decay: 0.08, release: 0.05 }); felt(s, 0.11, 130, 0.3); s.lowpass(3000); return fin(s, 0.2); },
  tick_green: () => { const s = S(0.3, 6012); s.analog(0, 0.08, C5, { amp: 0.42, shape: 'triangle', cutoff: 1500, env: 1500, res: 0.3, decay: 0.08, release: 0.1 }); s.tone(0, 0.06, C5, -1, 0.12, 'sine', 5, 0.001); return fin(s, 0.25); },
  altar_hum: () => { const s = S(1.8, 6013); swell2(s, 0, 110, [0, 7, 12], 0.26, 1.5); ping(s, 0.2, 659.3, 110, 0.14, 0.01); ping(s, 0.25, 987.8, 110, 0.12, 0.01); sparkle(s, 0.25, 1.2, 0.08, 10, 2400, 6000); return fin(s, 0.3); },
  hit_breath: () => { const s = S(1.3, 6014); whoosh(s, 0, 0.7, 0.34, 220, 2200); s.analog(0.05, 0.6, 55, { amp: 0.3, shape: 'saw', unison: 2, detune: 12, cutoff: 150, env: 1600, res: 0.3, attack: 0.1, decay: 0.6, sustain: 0.3, release: 0.3, drive: 1.6 }); crackle(s, 0.15, 0.8, 14, 0.12); impact2(s, 0.3, 0.5, 200); return fin(s, 0.45); },
  gem_blue: () => { const s = S(1.3, 6015); ping(s, 0, 1174.7, 80, 0.44, 0.02); s.ping(0.03, 1760, 50, 0.12, 0); felt(s, 0, 220, 0.08); return fin(s, 0.82); },
  turn_begin: () => { const s = S(1.2, 6016); ping(s, 0, 196, 90, 0.42, 0.02); s.tone(0, 0.8, 392, -1, 0.1, 'sine', 2.6, 0.004); return fin(s, 0.45); },
  // --- stone impacts for the blows that still had the drum ----------------------------------
  hit_slam: () => { const s = S(1.0, 6017); impact2(s, 0, 1.3, 220); s.rumble(0.02, 0.5, 0.3); for (let i = 0; i < 4; i++) tok(s, 0.05 + s.rand() * 0.25, 0.12, s.range(400, 700)); return fin(s, 0.9); },
  hit_bite: () => { const s = S(0.6, 6018); tok(s, 0, 0.4, 1400); impact2(s, 0.03, 0.5, 520); tok(s, 0.075, 0.45, 1100); impact2(s, 0.09, 0.6, 380); return fin(s, 0.8); },
  hit_claw: () => { const s = S(0.7, 6019); whoosh(s, 0, 0.14, 0.26, 700, 2600); impact2(s, 0.07, 0.7, 480); s.noise(0.07, 0.12, 0.3, 9000, 1200, 3.5, 0.0006, 1500); for (let i = 0; i < 3; i++) s.noise(0.09 + i * 0.03, 0.05, 0.2, 7000, 2000, 5, 0.001, 2000); return fin(s, 0.8); },
  hit_lash: () => { const s = S(0.6, 6020); whoosh(s, 0, 0.12, 0.2, 500, 3200); s.noise(0.1, 0.03, 0.5, 11000, 2500, 5, 0.0005, 1200); impact2(s, 0.1, 0.55, 600); return fin(s, 0.8); },
  hit_peck: () => { const s = S(0.35, 6021); tok(s, 0, 0.45, 1900); impact2(s, 0.005, 0.35, 900); s.ping(0, 2600, 12, 0.12, 0); return fin(s, 0.66); },
  hit_erupt: () => { const s = S(1.2, 6022); s.rumble(0, 0.5, 0.4); s.tone(0.1, 0.5, 90, 30, 0.7, 'sine', 2.8, 0.004); s.noise(0.12, 0.4, 0.45, 2600, 200, 2.4, 0.006); for (let i = 0; i < 12; i++) tok(s, 0.15 + s.rand() * 0.5, 0.14, s.range(300, 700)); impact2(s, 0.14, 1.0, 180); return fin(s, 0.9); },
  hit_burst: () => { const s = S(1.0, 6023); impact2(s, 0, 1.1, 260); s.noise(0, 0.35, 0.45, 9000, 300, 2.6, 0.001); sparkle(s, 0.02, 0.3, 0.12, 10, 1500, 5000); s.rumble(0.02, 0.4, 0.2); return fin(s, 0.88); },
  enemy_strike: () => { const s = S(0.9, 6024); impact2(s, 0, 1.15, 240); s.tone(0, 0.45, 72, 30, 0.6, 'sine', 2.6, 0.001); return fin(s, 0.94); },
  block_break: () => { const s = S(0.8, 6025); impact2(s, 0, 0.7, 300); for (let i = 0; i < 7; i++) s.ping(0.01 + s.rand() * 0.3, s.range(900, 2600), s.range(15, 40), 0.2, 0.02); return fin(s, 0.76); },
  warden_die: () => { const s = S(2.6, 6026); impact2(s, 0, 1.4, 200); s.noise(0.01, 0.5, 0.4, 9000, 300, 2.4, 0.001); s.tone(0, 0.6, 62, 28, 0.8, 'sine', 2.4, 0.001); s.rumble(0.05, 1.6, 0.45); for (let i = 0; i < 16; i++) s.ping(0.05 + s.rand() * 0.9, s.range(500, 3200), s.range(20, 60), 0.2, 0.02); ladder(s, 0.3, 880, [12, 7, 3, 0, -5, -12], 0.11, 80, 0.26); return fin(s, 0.95); },
  pick_strike: () => { const s = S(0.7, 6027); impact2(s, 0, 0.7, 500); metal(s, 0, 1180, 0.18, 0.26); for (let i = 0; i < 5; i++) tok(s, 0.06 + s.rand() * 0.3, 0.1, s.range(400, 800)); return fin(s, 0.86); },
  rock_break: () => { const s = S(1.0, 6028); s.noise(0, 0.5, 0.42, 3000, 180, 2.2, 0.004); impact2(s, 0, 0.9, 220); for (let i = 0; i < 9; i++) tok(s, 0.08 + s.rand() * 0.5, 0.18, s.range(300, 600)); return fin(s, 0.86); },
  geode_crack: () => { const s = S(1.1, 6029); s.noise(0, 0.14, 0.5, 8000, 900, 3.4, 0.0008); impact2(s, 0, 0.9, 240); for (let i = 0; i < 8; i++) s.ping(0.02 + s.rand() * 0.3, s.range(1500, 5000), s.range(20, 60), 0.2, 0.02); ping(s, 0.05, 1568, 120, 0.24, 0.02); for (let i = 0; i < 4; i++) tok(s, 0.18 + s.rand() * 0.3, 0.18, s.range(400, 700)); return fin(s, 0.82); },
  // --- warm swells in the big moments ------------------------------------------------------
  heal: () => { const s = S(1.5, 6030); swell2(s, 0, 261.6, [0, 4, 7], 0.24, 0.6); ladder(s, 0.2, 659.3, [0, 4, 7, 12], 0.1, 60, 0.26); return fin(s, 0.62); },
  victory: () => { const s = S(2.4, 6031); swell2(s, 0, C5 / 2, [0, 7, 12, 16, 19], 0.22, 1.2); ladder(s, 0.1, 659.3, [0, 7, 12, 16, 19, 24], 0.09, 70, 0.3); s.add(kick(), 0, 0.6); sparkle(s, 0.3, 1.0, 0.08, 10, 2400, 6000); return fin(s, 0.72); },
  defeat: () => { const s = S(2.4, 6032); swell2(s, 0, 196, [0, 3, 7], 0.24, 1.3); s.analog(0.1, 1.2, 150, { amp: 0.22, shape: 'saw', unison: 2, detune: 12, cutoff: 400, env: 0, res: 0.3, attack: 0.2, decay: 1, sustain: 0.5, release: 0.6, glide: 2.0 }); s.lowpass(1500); s.rumble(0, 1.2, 0.3); return fin(s, 0.8); },
  grade_peerless: () => { const s = S(2.6, 6033); ladder(s, 0, 784, [0, 4, 7, 12], 0.08, 110, 0.32); swell2(s, 0.06, 196, [0, 7, 12], 0.26, 1.6); s.add(kick(), 0, 0.5); sparkle(s, 0.1, 1.7, 0.14, 18, 2600, 7600); s.rumble(0, 1.0, 0.2); return fin(s, 0.95); },
  altar_make: () => { const s = S(2.4, 6034); riser(s, 0, 0.9, 0.22, 65); ladder(s, 0, C5, [0, 4, 7, 12, 16], 0.12, 120, 0.3); swell2(s, 0.65, C5, [0, 4, 7, 12], 0.22, 1.4); sparkle(s, 0.6, 1.4, 0.12, 16, 2600, 7200); return fin(s, 0.86); },
  transcendent: () => { const s = S(3.0, 6035); s.rumble(0, 1.2, 0.26); riser(s, 0, 1.0, 0.24, 65); ladder(s, 0, 261.6, [0, 7, 12, 16, 19, 24, 28], 0.11, 140, 0.3); swell2(s, 0.8, 523.25, [0, 4, 7, 11, 14], 0.22, 2.0); swell2(s, 0.8, 130.8, [0, 7, 12], 0.24, 2.0); s.add(kick(), sec(0.8), 0.6); sparkle(s, 0.7, 2.0, 0.18, 30, 2600, 8800); return fin(s, 0.97); },
  jackpot: () => { const s = S(2.6, 6036); for (let i = 0; i < 16; i++) coin(s, s.rand() * 0.8, 0.14); ladder(s, 0.1, C5, [0, 4, 7, 12, 16], 0.09, 120, 0.3); swell2(s, 0.55, C5, [0, 4, 7, 12], 0.2, 1.5); sparkle(s, 0.4, 1.6, 0.14, 24, 2600, 8000); s.add(kick(), sec(0.55), 0.5); return fin(s, 0.9); },
  infinity: () => { const s = S(3.2, 6037); s.rumble(0, 1.3, 0.3); whoosh(s, 0, 0.8, 0.26, 90, 4200); ladder(s, 0, C5, [0, 4, 7, 12, 7, 4, 0, -5, 0, 4, 7, 12, 16, 19, 24], 0.065, 140, 0.24); swell2(s, 1.0, C5, [0, 4, 7, 11, 14, 19], 0.22, 1.8); swell2(s, 1.0, 65.4, [0, 7, 12, 19], 0.24, 1.85); s.add(kick(), sec(1.0), 0.7); sparkle(s, 0.85, 1.95, 0.2, 40, 2400, 9800); return fin(s, 0.98); },
};
for (const name of Object.keys(G)) { if (!M3.SFX3[name]) M3.SFX3[name] = {}; M3.SFX3[name].g = G[name]; }
const PROPOSED = Object.keys(G);
root.DeepSoundMV6 = { G, PROPOSED, _k6: { impact2, swell2 } };
})(typeof self !== 'undefined' ? self : globalThis);

// Glue: the same file is a page script and a Worker.
(function (root) {
'use strict';
const M = root.DeepSoundMV2, M3 = root.DeepSoundMV3, M4 = root.DeepSoundMV4, M5 = root.DeepSoundMV5, M6 = root.DeepSoundMV6, C = root.DeepSoundCore;
root.DeepSound3 = {
  RATE: C.RATE, NAMES: M.NAMES, SPECS: M.SPECS, SPECS3: M3.SPECS3, FIXES: M3.FIXES, FIXES4: M4.FIXES4, FIXES5: M5.FIXES5, PROPOSED: M6.PROPOSED,
  // variant 'a' | 'b' = a round 3 version, 'c' | 'd' = round 4, 'e' | 'f' = round 5, 'g' = a round 6 proposal; anything else = the round 2 sound.
  sfx(name, variant = 0) {
    if (typeof variant === 'string' && /^[a-g]$/.test(variant)) { const f = M3.SFX3[name]; return f && f[variant] ? f[variant]() : null; }
    const f = M.SFX[name]; return f ? f(variant) : null;
  },
  music(id) { return M3.byId3[id] ? M3.piece3(id) : M.piece(id); },
  spec(id) { return M3.byId3[id] || M.byId[id]; },
  impulse(o) { const s = new C.Syn(o.seconds || 3.0, 9); s.b[0] = 1; s.reverb({ size: o.size, decay: o.decay, damp: o.damp, mix: 1, predelay: o.predelay || 0.01, shimmer: o.shimmer || 0 }); s.b[0] = 0; return s.b; },
};
const isWorker = typeof root.document === 'undefined' && typeof root.postMessage === 'function';
if (isWorker) {
  root.onmessage = (e) => {
    const { id, kind, name, variant, piece, room } = e.data || {};
    try {
      if (kind === 'music') {
        const m = root.DeepSound3.music(piece);
        root.postMessage({ id, ok: true, kind, piece, seconds: m.seconds, bed: m.bed, deep: m.deep, fight: m.fight, warden: m.warden }, [m.bed.buffer, m.deep.buffer, m.fight.buffer, m.warden.buffer]);
      } else if (kind === 'sfx') {
        const b = root.DeepSound3.sfx(name, variant);
        root.postMessage({ id, ok: true, kind, name, variant, buf: b }, [b.buffer]);
      } else if (kind === 'impulse') {
        const b = root.DeepSound3.impulse(room);
        root.postMessage({ id, ok: true, kind, buf: b }, [b.buffer]);
      }
    } catch (err) { root.postMessage({ id, ok: false, error: String(err && err.stack || err) }); }
  };
}
})(typeof self !== 'undefined' ? self : globalThis);
