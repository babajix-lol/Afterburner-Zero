"""Procedural Arcade Synthwave / Darksynth BGM generator for Afterburner Zero.

Generates seamless bar-aligned 44.1 kHz stereo 16-bit WAV loops using only the
Python standard library (math, random, struct, wave, os).
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave
from typing import Callable

SAMPLE_RATE = 44100
TWO_PI = 2.0 * math.pi


def midi_to_hz(midi: int) -> float:
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def _clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if x < lo else (hi if x > hi else x)


def make_drum_kick(punch: float = 1.0) -> list[float]:
    dur = int(0.22 * SAMPLE_RATE)
    out = [0.0] * dur
    phase = 0.0
    for i in range(dur):
        t = i / SAMPLE_RATE
        freq = 46.0 + 115.0 * math.exp(-t * 34.0)
        phase += TWO_PI * freq / SAMPLE_RATE
        amp = math.exp(-t * 14.0)
        click = math.exp(-t * 180.0) * 0.45 * punch
        val = math.tanh((math.sin(phase) * (1.2 + 0.4 * punch) + click) * amp)
        out[i] = val * 0.92
    return out


def make_drum_snare(tight: float = 1.0, seed: int = 101) -> list[float]:
    rng = random.Random(seed)
    dur = int(0.19 * SAMPLE_RATE)
    out = [0.0] * dur
    phase = 0.0
    prev_n = 0.0
    lp = 0.0
    for i in range(dur):
        t = i / SAMPLE_RATE
        freq = 125.0 + 95.0 * math.exp(-t * 38.0)
        phase += TWO_PI * freq / SAMPLE_RATE
        body = math.sin(phase) * math.exp(-t * 22.0 * tight) * 0.55
        n = rng.uniform(-1.0, 1.0)
        hp = n - prev_n * 0.65
        prev_n = n
        lp += 0.55 * (hp - lp)
        noise = lp * math.exp(-t * 15.0 * tight) * 0.65
        out[i] = math.tanh((body + noise) * 1.15) * 0.72
    return out


def make_drum_hat(open_hat: bool = False, seed: int = 202) -> list[float]:
    rng = random.Random(seed)
    dur = int((0.16 if open_hat else 0.055) * SAMPLE_RATE)
    decay = 16.0 if open_hat else 58.0
    out = [0.0] * dur
    prev = 0.0
    prev2 = 0.0
    for i in range(dur):
        t = i / SAMPLE_RATE
        n = rng.uniform(-1.0, 1.0)
        hp = n - 1.2 * prev + 0.35 * prev2
        prev2 = prev
        prev = n
        out[i] = hp * math.exp(-t * decay) * (0.28 if open_hat else 0.24)
    return out


def synth_note(
    freq: float,
    dur_sec: float,
    wave_type: str = "saw",
    cutoff_start: float = 0.38,
    cutoff_end: float = 0.08,
    attack_sec: float = 0.008,
    release_sec: float = 0.04,
    detune: float = 0.004,
    gain: float = 0.5,
) -> list[float]:
    n = max(1, int(dur_sec * SAMPLE_RATE))
    out = [0.0] * n
    atk_n = max(1, int(attack_sec * SAMPLE_RATE))
    rel_n = max(1, int(release_sec * SAMPLE_RATE))

    p1 = 0.0
    p2 = 0.0
    inc1 = freq / SAMPLE_RATE
    inc2 = (freq * (1.0 + detune)) / SAMPLE_RATE
    lp1 = 0.0
    lp2 = 0.0

    for i in range(n):
        p1 = (p1 + inc1) % 1.0
        p2 = (p2 + inc2) % 1.0

        if wave_type == "saw":
            raw = (2.0 * p1 - 1.0) * 0.55 + (2.0 * p2 - 1.0) * 0.45
        elif wave_type == "square":
            s1 = 1.0 if p1 < 0.5 else -1.0
            s2 = 1.0 if p2 < 0.46 else -1.0
            raw = s1 * 0.6 + s2 * 0.4
        elif wave_type == "pulse25":
            s1 = 1.0 if p1 < 0.25 else -1.0
            s2 = 1.0 if p2 < 0.25 else -1.0
            raw = s1 * 0.6 + s2 * 0.4
        elif wave_type == "sub":
            sine = math.sin(TWO_PI * p1)
            tri = 4.0 * abs(p1 - 0.5) - 1.0
            saw = 2.0 * p2 - 1.0
            raw = sine * 0.5 + tri * 0.25 + saw * 0.35
        elif wave_type == "pad":
            s1 = 2.0 * p1 - 1.0
            s2 = 2.0 * p2 - 1.0
            s3 = math.sin(TWO_PI * ((p1 * 0.5) % 1.0))
            raw = s1 * 0.35 + s2 * 0.35 + s3 * 0.30
        else:  # triangle
            raw = 4.0 * abs(p1 - 0.5) - 1.0

        frac = i / n
        alpha = cutoff_start + (cutoff_end - cutoff_start) * (frac ** 0.7)
        alpha = _clamp(alpha, 0.015, 0.92)
        lp1 += alpha * (raw - lp1)
        lp2 += alpha * (lp1 - lp2)

        env = 1.0
        if i < atk_n:
            env = i / atk_n
        elif i > n - rel_n:
            env = max(0.0, (n - i) / rel_n)

        out[i] = lp2 * env * gain
    return out


def mix_into(
    buf_l: list[float],
    buf_r: list[float],
    sample: list[float],
    start_idx: int,
    gain: float = 1.0,
    pan: float = 0.0,
    wrap: bool = True,
) -> None:
    total = len(buf_l)
    pan = _clamp(pan, -1.0, 1.0)
    gl = gain * math.sqrt(0.5 * (1.0 - pan))
    gr = gain * math.sqrt(0.5 * (1.0 + pan))
    if wrap:
        for i, v in enumerate(sample):
            idx = (start_idx + i) % total
            buf_l[idx] += v * gl
            buf_r[idx] += v * gr
    else:
        for i, v in enumerate(sample):
            idx = start_idx + i
            if 0 <= idx < total:
                buf_l[idx] += v * gl
                buf_r[idx] += v * gr


def apply_stereo_delay(
    src_l: list[float],
    src_r: list[float],
    delay_samples: int,
    wet: float = 0.28,
    feedback: float = 0.32,
) -> tuple[list[float], list[float]]:
    total = len(src_l)
    out_l = list(src_l)
    out_r = list(src_r)
    tap_l = [0.0] * total
    tap_r = [0.0] * total
    # Wrap two delay passes so the loop seam stays seamless
    d1 = delay_samples % total
    d2 = (delay_samples * 2) % total
    fb2 = feedback * feedback
    for i in range(total):
        i1 = (i - d1) % total
        i2 = (i - d2) % total
        tap_l[i] = src_r[i1] * feedback + src_l[i2] * fb2
        tap_r[i] = src_l[i1] * feedback + src_r[i2] * fb2
    for i in range(total):
        out_l[i] += tap_l[i] * wet
        out_r[i] += tap_r[i] * wet
    return out_l, out_r


def write_wav_stereo(path: str, buf_l: list[float], buf_r: list[float], peak_target: float = 0.86) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = 1e-6
    for a, b in zip(buf_l, buf_r):
        va = abs(a)
        vb = abs(b)
        if va > peak:
            peak = va
        if vb > peak:
            peak = vb

    scale = peak_target / peak if peak > 0.0 else 1.0
    total = len(buf_l)

    # Tiny 2ms seam smoothing at very start/end to guarantee zero click
    fade_n = min(96, total // 20)
    pcm = bytearray(total * 4)
    for i in range(total):
        l_val = math.tanh(buf_l[i] * scale * 1.15) * 0.92
        r_val = math.tanh(buf_r[i] * scale * 1.15) * 0.92
        if i < fade_n:
            w = i / fade_n
            l_val *= w
            r_val *= w
        elif i >= total - fade_n:
            w = (total - 1 - i) / fade_n
            l_val *= w
            r_val *= w
        il = int(_clamp(l_val) * 32767.0)
        ir = int(_clamp(r_val) * 32767.0)
        struct.pack_into("<hh", pcm, i * 4, il, ir)

    with wave.open(path, "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm)


class NoteCache:
    def __init__(self) -> None:
        self._cache: dict[tuple, list[float]] = {}

    def get(self, key: tuple, builder: Callable[[], list[float]]) -> list[float]:
        if key not in self._cache:
            self._cache[key] = builder()
        return self._cache[key]


def render_track(
    out_path: str,
    bpm: float,
    bars: int,
    chords: list[list[int]],
    bass_pattern: list[int | None],
    arp_pattern: list[int | None],
    lead_phrases: list[list[tuple[int, int, int] | None]],
    drum_style: str = "driving",
    bass_wave: str = "sub",
    lead_wave: str = "saw",
    arp_wave: str = "pulse25",
    pad_gain: float = 0.16,
    lead_cutoff: tuple[float, float] = (0.55, 0.18),
    delay_wet: float = 0.26,
) -> None:
    """Render a `bars`-long 4/4 loop where each bar has 16 sixteenth-note steps."""
    steps_per_bar = 16
    total_steps = bars * steps_per_bar
    step_sec = 60.0 / bpm / 4.0
    total_samples = int(round(total_steps * step_sec * SAMPLE_RATE))

    dry_l = [0.0] * total_samples
    dry_r = [0.0] * total_samples
    fx_l = [0.0] * total_samples
    fx_r = [0.0] * total_samples

    cache = NoteCache()
    kick = make_drum_kick(punch=1.2 if drum_style in ("heavy", "boss") else 1.0)
    snare = make_drum_snare(tight=1.15 if drum_style == "boss" else 1.0)
    hat_c = make_drum_hat(open_hat=False)
    hat_o = make_drum_hat(open_hat=True)

    for bar in range(bars):
        chord = chords[bar % len(chords)]
        bar_step = bar * steps_per_bar

        # Warm stereo pad on beat 1 of each bar
        if pad_gain > 0.0:
            bar_start = int(round(bar_step * step_sec * SAMPLE_RATE))
            for idx_c, note_midi in enumerate(chord):
                pan = -0.35 + 0.35 * idx_c
                pad_note = cache.get(
                    ("pad", note_midi, round(step_sec * 16, 4)),
                    lambda m=note_midi: synth_note(
                        midi_to_hz(m + 12),
                        step_sec * 15.8,
                        wave_type="pad",
                        cutoff_start=0.16,
                        cutoff_end=0.10,
                        attack_sec=0.18,
                        release_sec=0.25,
                        detune=0.005,
                        gain=pad_gain,
                    ),
                )
                mix_into(dry_l, dry_r, pad_note, bar_start, gain=1.0, pan=pan)

        for s in range(steps_per_bar):
            step_idx = bar_step + s
            pos = int(round(step_idx * step_sec * SAMPLE_RATE))

            # Drums
            if drum_style == "menu":
                if s in (0, 6, 10):
                    mix_into(dry_l, dry_r, kick, pos, gain=0.78, pan=0.0)
                if s in (4, 12):
                    mix_into(dry_l, dry_r, snare, pos, gain=0.58, pan=0.0)
                if s % 2 == 0:
                    mix_into(dry_l, dry_r, hat_c, pos, gain=0.45, pan=0.18)
            elif drum_style == "driving":
                if s in (0, 4, 8, 12) or (bar % 2 == 1 and s == 14):
                    mix_into(dry_l, dry_r, kick, pos, gain=0.92, pan=0.0)
                if s in (4, 12):
                    mix_into(dry_l, dry_r, snare, pos, gain=0.78, pan=0.0)
                if s % 2 == 1:
                    mix_into(dry_l, dry_r, hat_o if s in (7, 15) else hat_c, pos, gain=0.65, pan=-0.18)
                else:
                    mix_into(dry_l, dry_r, hat_c, pos, gain=0.35, pan=0.22)
            elif drum_style == "heavy":
                if s in (0, 3, 6, 8, 10, 12) or (bar % 2 == 1 and s == 15):
                    mix_into(dry_l, dry_r, kick, pos, gain=0.98, pan=0.0)
                if s in (4, 12) or (bar == bars - 1 and s in (14, 15)):
                    mix_into(dry_l, dry_r, snare, pos, gain=0.84, pan=0.0)
                mix_into(dry_l, dry_r, hat_o if s in (2, 10) else hat_c, pos, gain=0.55, pan=(0.2 if s % 2 else -0.2))
            elif drum_style == "boss":
                if s in (0, 2, 4, 6, 8, 10, 12, 14):
                    mix_into(dry_l, dry_r, kick, pos, gain=0.95 if s % 4 == 0 else 0.72, pan=0.0)
                if s in (4, 12) or (bar % 2 == 1 and s in (13, 15)):
                    mix_into(dry_l, dry_r, snare, pos, gain=0.86, pan=0.0)
                mix_into(dry_l, dry_r, hat_o if s % 4 == 2 else hat_c, pos, gain=0.62, pan=(-0.25 if s % 2 else 0.25))
            elif drum_style == "ambient":
                if s in (0, 8):
                    mix_into(dry_l, dry_r, kick, pos, gain=0.45, pan=0.0)
                if s == 12:
                    mix_into(dry_l, dry_r, hat_o, pos, gain=0.30, pan=0.15)
            elif drum_style == "victory":
                if s in (0, 6, 8, 14):
                    mix_into(dry_l, dry_r, kick, pos, gain=0.76, pan=0.0)
                if s in (4, 12):
                    mix_into(dry_l, dry_r, snare, pos, gain=0.65, pan=0.0)
                if s % 2 == 0:
                    mix_into(dry_l, dry_r, hat_c, pos, gain=0.45, pan=0.15)

            # Bass (root + octave/fifth pattern)
            b_deg = bass_pattern[s % len(bass_pattern)]
            if b_deg is not None:
                bass_midi = chord[0] - 12 + b_deg
                b_dur = step_sec * 0.88
                b_note = cache.get(
                    ("bass", bass_wave, bass_midi, round(b_dur, 4)),
                    lambda m=bass_midi, d=b_dur: synth_note(
                        midi_to_hz(m),
                        d,
                        wave_type=bass_wave,
                        cutoff_start=0.34,
                        cutoff_end=0.07,
                        attack_sec=0.004,
                        release_sec=0.025,
                        detune=0.003,
                        gain=0.48,
                    ),
                )
                mix_into(dry_l, dry_r, b_note, pos, gain=1.0, pan=0.0)

            # Arpeggiator (sent to FX bus for stereo width)
            a_idx = arp_pattern[s % len(arp_pattern)]
            if a_idx is not None:
                octave_shift = 12 if a_idx >= len(chord) else 0
                arp_midi = chord[a_idx % len(chord)] + 12 + octave_shift
                a_dur = step_sec * 0.78
                a_note = cache.get(
                    ("arp", arp_wave, arp_midi, round(a_dur, 4)),
                    lambda m=arp_midi, d=a_dur: synth_note(
                        midi_to_hz(m),
                        d,
                        wave_type=arp_wave,
                        cutoff_start=0.45,
                        cutoff_end=0.10,
                        attack_sec=0.004,
                        release_sec=0.03,
                        detune=0.005,
                        gain=0.22,
                    ),
                )
                pan_a = -0.35 if (s % 2 == 0) else 0.35
                mix_into(fx_l, fx_r, a_note, pos, gain=1.0, pan=pan_a)

        # Lead melody phrase for this bar: list of (step_in_bar, midi_note, length_in_steps)
        phrase = lead_phrases[bar % len(lead_phrases)]
        for item in phrase:
            if item is None:
                continue
            s_off, l_midi, l_steps = item
            pos = int(round((bar_step + s_off) * step_sec * SAMPLE_RATE))
            l_dur = step_sec * l_steps * 0.94
            l_note = cache.get(
                ("lead", lead_wave, l_midi, round(l_dur, 4), lead_cutoff),
                lambda m=l_midi, d=l_dur: synth_note(
                    midi_to_hz(m),
                    d,
                    wave_type=lead_wave,
                    cutoff_start=lead_cutoff[0],
                    cutoff_end=lead_cutoff[1],
                    attack_sec=0.012,
                    release_sec=0.06,
                    detune=0.006,
                    gain=0.34,
                ),
            )
            mix_into(fx_l, fx_r, l_note, pos, gain=1.0, pan=0.08)

    delay_samples = int(round(3.0 * step_sec * SAMPLE_RATE))
    wet_l, wet_r = apply_stereo_delay(fx_l, fx_r, delay_samples=delay_samples, wet=delay_wet, feedback=0.34)
    final_l = [dry_l[i] + wet_l[i] for i in range(total_samples)]
    final_r = [dry_r[i] + wet_r[i] for i in range(total_samples)]
    write_wav_stereo(out_path, final_l, final_r)
    dur_s = total_samples / SAMPLE_RATE
    print(f"Generated {out_path} ({dur_s:.2f}s @ {bpm} BPM, {bars} bars)")


def build_all(out_dir: str) -> None:
    # 1. Main Menu / Splash / Level Select: Tactical Synth (A minor, 110 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_menu.wav"),
        bpm=110.0,
        bars=8,
        chords=[
            [57, 60, 64],  # Am
            [53, 57, 60],  # F
            [48, 52, 55],  # C
            [55, 59, 62],  # G
            [57, 60, 64],  # Am
            [53, 57, 60],  # F
            [50, 53, 57],  # Dm
            [52, 56, 59],  # E
        ],
        bass_pattern=[0, None, 0, None, 12, None, 0, None, 0, None, 0, None, 7, None, 12, None],
        arp_pattern=[0, 1, 2, 1, 0, 1, 2, 3, 0, 1, 2, 1, 2, 3, 2, 1],
        lead_phrases=[
            [(0, 69, 4), (4, 72, 4), (8, 76, 6), (14, 74, 2)],
            [(0, 72, 6), (6, 71, 2), (8, 69, 8)],
            [(0, 72, 4), (4, 74, 4), (8, 76, 4), (12, 79, 4)],
            [(0, 79, 6), (6, 76, 2), (8, 74, 8)],
            [(0, 69, 4), (4, 72, 4), (8, 76, 4), (12, 81, 4)],
            [(0, 79, 4), (4, 77, 4), (8, 76, 4), (12, 72, 4)],
            [(0, 74, 6), (6, 72, 2), (8, 69, 8)],
            [(0, 71, 4), (4, 76, 4), (8, 75, 4), (12, 71, 4)],
        ],
        drum_style="menu",
        bass_wave="sub",
        lead_wave="saw",
        arp_wave="triangle",
        pad_gain=0.18,
        lead_cutoff=(0.36, 0.14),
        delay_wet=0.32,
    )

    # 2. Level 1 — Highway Breach: Upbeat Arcade Synthwave (E minor, 128 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_level_01.wav"),
        bpm=128.0,
        bars=8,
        chords=[
            [52, 55, 59],  # Em
            [48, 52, 55],  # C
            [50, 54, 57],  # D
            [52, 55, 59],  # Em
            [52, 55, 59],  # Em
            [48, 52, 55],  # C
            [55, 59, 62],  # G
            [54, 57, 61],  # F#m / B7 feel -> [47, 51, 54] B
        ],
        bass_pattern=[0, 0, 12, 0, 0, 12, 0, 7, 0, 0, 12, 0, 0, 12, 7, 12],
        arp_pattern=[0, 1, 2, 3, 2, 1, 0, 2, 0, 1, 2, 3, 2, 1, 2, 3],
        lead_phrases=[
            [(0, 76, 3), (3, 79, 3), (6, 78, 2), (8, 76, 4), (12, 74, 4)],
            [(0, 72, 4), (4, 76, 4), (8, 79, 6), (14, 76, 2)],
            [(0, 74, 3), (3, 78, 3), (6, 81, 2), (8, 79, 4), (12, 78, 4)],
            [(0, 76, 8), (8, 74, 4), (12, 71, 4)],
            [(0, 76, 3), (3, 79, 3), (6, 83, 2), (8, 81, 4), (12, 79, 4)],
            [(0, 84, 4), (4, 83, 4), (8, 79, 4), (12, 76, 4)],
            [(0, 79, 4), (4, 78, 4), (8, 74, 4), (12, 79, 4)],
            [(0, 78, 6), (6, 76, 2), (8, 75, 4), (12, 71, 4)],
        ],
        drum_style="driving",
        bass_wave="sub",
        lead_wave="saw",
        arp_wave="pulse25",
        pad_gain=0.14,
        lead_cutoff=(0.56, 0.20),
        delay_wet=0.25,
    )

    # 3. Level 2 — Downtown Corridor: Driving Synth-Rock (D minor, 136 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_level_02.wav"),
        bpm=136.0,
        bars=8,
        chords=[
            [50, 53, 57],  # Dm
            [46, 50, 53],  # Bb
            [48, 52, 55],  # C
            [50, 53, 57],  # Dm
            [50, 53, 57],  # Dm
            [46, 50, 53],  # Bb
            [43, 46, 50],  # Gm
            [45, 49, 52],  # A
        ],
        bass_pattern=[0, 0, 0, 12, 0, 0, 7, 12, 0, 0, 0, 12, 0, 10, 7, 12],
        arp_pattern=[0, 2, 1, 2, 3, 2, 1, 2, 0, 2, 1, 2, 3, 1, 2, 0],
        lead_phrases=[
            [(0, 74, 2), (2, 77, 2), (4, 81, 4), (8, 79, 2), (10, 77, 2), (12, 76, 4)],
            [(0, 74, 4), (4, 70, 4), (8, 77, 4), (12, 74, 4)],
            [(0, 72, 2), (2, 76, 2), (4, 79, 4), (8, 77, 4), (12, 76, 4)],
            [(0, 74, 6), (6, 72, 2), (8, 74, 4), (12, 69, 4)],
            [(0, 74, 2), (2, 77, 2), (4, 81, 4), (8, 82, 4), (12, 81, 4)],
            [(0, 77, 4), (4, 79, 4), (8, 82, 4), (12, 81, 4)],
            [(0, 79, 3), (3, 77, 3), (6, 74, 2), (8, 70, 4), (12, 74, 4)],
            [(0, 73, 4), (4, 76, 4), (8, 81, 4), (12, 79, 4)],
        ],
        drum_style="driving",
        bass_wave="saw",
        lead_wave="square",
        arp_wave="pulse25",
        pad_gain=0.14,
        lead_cutoff=(0.58, 0.22),
        delay_wet=0.24,
    )

    # 4. Level 3 — Industrial District: Industrial Electro (F# minor, 140 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_level_03.wav"),
        bpm=140.0,
        bars=8,
        chords=[
            [54, 57, 61],  # F#m
            [54, 57, 61],  # F#m
            [50, 54, 57],  # D
            [52, 56, 59],  # E
            [54, 57, 61],  # F#m
            [49, 53, 56],  # C#
            [50, 54, 57],  # D
            [49, 53, 56],  # C#
        ],
        bass_pattern=[0, 12, 0, 0, 12, 0, 7, 12, 0, 12, 0, 0, 12, 7, 10, 12],
        arp_pattern=[0, 0, 2, 1, 3, 2, 0, 1, 0, 0, 2, 1, 3, 2, 1, 2],
        lead_phrases=[
            [(0, 78, 2), (2, 78, 2), (4, 81, 2), (6, 78, 2), (8, 85, 4), (12, 83, 4)],
            [(0, 81, 4), (4, 80, 4), (8, 78, 4), (12, 73, 4)],
            [(0, 74, 2), (2, 78, 2), (4, 81, 4), (8, 80, 4), (12, 76, 4)],
            [(0, 78, 6), (6, 76, 2), (8, 74, 4), (12, 73, 4)],
            [(0, 78, 2), (2, 81, 2), (4, 85, 4), (8, 86, 4), (12, 85, 4)],
            [(0, 80, 4), (4, 83, 4), (8, 85, 4), (12, 80, 4)],
            [(0, 81, 3), (3, 78, 3), (6, 74, 2), (8, 78, 4), (12, 81, 4)],
            [(0, 80, 4), (4, 77, 4), (8, 73, 4), (12, 77, 4)],
        ],
        drum_style="heavy",
        bass_wave="square",
        lead_wave="saw",
        arp_wave="saw",
        pad_gain=0.12,
        lead_cutoff=(0.62, 0.24),
        delay_wet=0.22,
    )

    # 5. Level 4 — Harbor Siege: Urgent Darksynth (C minor, 146 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_level_04.wav"),
        bpm=146.0,
        bars=8,
        chords=[
            [48, 51, 55],  # Cm
            [44, 48, 51],  # Ab
            [46, 50, 53],  # Bb
            [43, 47, 50],  # G
            [48, 51, 55],  # Cm
            [41, 44, 48],  # Fm
            [44, 48, 51],  # Ab
            [43, 47, 50],  # G
        ],
        bass_pattern=[0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 7, 10, 12, 7],
        arp_pattern=[0, 1, 2, 3, 2, 1, 0, 3, 0, 1, 2, 3, 2, 3, 1, 2],
        lead_phrases=[
            [(0, 72, 2), (2, 75, 2), (4, 79, 4), (8, 77, 2), (10, 75, 2), (12, 74, 4)],
            [(0, 75, 4), (4, 72, 4), (8, 80, 4), (12, 79, 4)],
            [(0, 77, 2), (2, 74, 2), (4, 70, 4), (8, 74, 4), (12, 77, 4)],
            [(0, 79, 4), (4, 77, 4), (8, 74, 4), (12, 71, 4)],
            [(0, 72, 2), (2, 75, 2), (4, 79, 2), (6, 84, 2), (8, 82, 4), (12, 79, 4)],
            [(0, 80, 4), (4, 77, 4), (8, 75, 4), (12, 72, 4)],
            [(0, 75, 3), (3, 79, 3), (6, 80, 2), (8, 84, 4), (12, 80, 4)],
            [(0, 79, 4), (4, 74, 4), (8, 71, 4), (12, 74, 4)],
        ],
        drum_style="heavy",
        bass_wave="sub",
        lead_wave="saw",
        arp_wave="pulse25",
        pad_gain=0.14,
        lead_cutoff=(0.66, 0.24),
        delay_wet=0.28,
    )

    # 6. Level 5 — Zero Hour: Black Site: Climax Darksynth (C# Phrygian/Minor, 154 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_level_05.wav"),
        bpm=154.0,
        bars=8,
        chords=[
            [49, 52, 56],  # C#m
            [50, 54, 57],  # D (Phrygian bII!)
            [49, 52, 56],  # C#m
            [47, 51, 54],  # B
            [45, 49, 52],  # A
            [47, 51, 54],  # B
            [44, 48, 51],  # G#
            [49, 52, 56],  # C#m
        ],
        bass_pattern=[0, 0, 12, 0, 0, 12, 0, 12, 0, 0, 12, 0, 7, 12, 13, 12],
        arp_pattern=[0, 2, 3, 2, 1, 3, 2, 0, 0, 2, 3, 2, 1, 2, 3, 1],
        lead_phrases=[
            [(0, 73, 2), (2, 74, 2), (4, 76, 4), (8, 80, 2), (10, 78, 2), (12, 76, 4)],
            [(0, 74, 3), (3, 76, 3), (6, 78, 2), (8, 81, 4), (12, 80, 4)],
            [(0, 76, 2), (2, 73, 2), (4, 80, 4), (8, 85, 4), (12, 83, 4)],
            [(0, 83, 4), (4, 81, 4), (8, 78, 4), (12, 75, 4)],
            [(0, 76, 2), (2, 81, 2), (4, 85, 4), (8, 83, 4), (12, 81, 4)],
            [(0, 78, 4), (4, 83, 4), (8, 81, 4), (12, 78, 4)],
            [(0, 80, 2), (2, 79, 2), (4, 75, 4), (8, 80, 4), (12, 84, 4)],
            [(0, 85, 4), (4, 80, 4), (8, 76, 4), (12, 73, 4)],
        ],
        drum_style="boss",
        bass_wave="saw",
        lead_wave="saw",
        arp_wave="saw",
        pad_gain=0.14,
        lead_cutoff=(0.72, 0.28),
        delay_wet=0.25,
    )

    # 7. Boss Arena Theme: Fast Heavy Synth-Metal (G Phrygian, 156 BPM, 8 bars)
    render_track(
        os.path.join(out_dir, "bgm_boss.wav"),
        bpm=156.0,
        bars=8,
        chords=[
            [43, 46, 50],  # Gm
            [44, 48, 51],  # Ab
            [43, 46, 50],  # Gm
            [41, 45, 48],  # F
            [39, 43, 46],  # Eb
            [41, 45, 48],  # F
            [44, 48, 51],  # Ab
            [42, 46, 50],  # D/F# tension -> [38, 42, 45] D
        ],
        bass_pattern=[0, 0, 12, 0, 12, 0, 7, 12, 0, 0, 12, 0, 13, 12, 10, 7],
        arp_pattern=[0, 3, 2, 1, 0, 3, 2, 1, 0, 2, 3, 1, 2, 3, 2, 0],
        lead_phrases=[
            [(0, 79, 2), (2, 80, 2), (4, 82, 4), (8, 79, 2), (10, 74, 2), (12, 79, 4)],
            [(0, 80, 2), (2, 79, 2), (4, 75, 4), (8, 80, 4), (12, 84, 4)],
            [(0, 82, 2), (2, 79, 2), (4, 74, 4), (8, 79, 4), (12, 82, 4)],
            [(0, 81, 4), (4, 77, 4), (8, 74, 4), (12, 72, 4)],
            [(0, 75, 2), (2, 79, 2), (4, 82, 4), (8, 84, 4), (12, 82, 4)],
            [(0, 81, 4), (4, 84, 4), (8, 86, 4), (12, 81, 4)],
            [(0, 80, 2), (2, 84, 2), (4, 87, 4), (8, 84, 4), (12, 80, 4)],
            [(0, 86, 4), (4, 82, 4), (8, 78, 4), (12, 74, 4)],
        ],
        drum_style="boss",
        bass_wave="square",
        lead_wave="saw",
        arp_wave="pulse25",
        pad_gain=0.11,
        lead_cutoff=(0.76, 0.30),
        delay_wet=0.22,
    )

    # 8. Victory Theme: Heroic Synth Epilog (C Major / F / G, 105 BPM, 4 bars)
    render_track(
        os.path.join(out_dir, "bgm_victory.wav"),
        bpm=105.0,
        bars=4,
        chords=[
            [48, 52, 55],  # C
            [53, 57, 60],  # F
            [55, 59, 62],  # G
            [48, 52, 55],  # C
        ],
        bass_pattern=[0, None, 12, None, 0, None, 7, 12, 0, None, 12, None, 0, 7, 12, None],
        arp_pattern=[0, 1, 2, 3, 2, 1, 0, 2, 0, 1, 2, 3, 2, 1, 2, 3],
        lead_phrases=[
            [(0, 72, 4), (4, 76, 4), (8, 79, 6), (14, 76, 2)],
            [(0, 77, 4), (4, 81, 4), (8, 84, 8)],
            [(0, 83, 4), (4, 79, 4), (8, 74, 4), (12, 79, 4)],
            [(0, 84, 8), (8, 79, 4), (12, 76, 4)],
        ],
        drum_style="victory",
        bass_wave="sub",
        lead_wave="saw",
        arp_wave="triangle",
        pad_gain=0.22,
        lead_cutoff=(0.48, 0.18),
        delay_wet=0.34,
    )

    # 9. Game Over Theme: Somber Low-Pass Pad (D minor, 84 BPM, 4 bars)
    render_track(
        os.path.join(out_dir, "bgm_gameover.wav"),
        bpm=84.0,
        bars=4,
        chords=[
            [50, 53, 57],  # Dm
            [46, 50, 53],  # Bb
            [43, 46, 50],  # Gm
            [45, 48, 52],  # Am
        ],
        bass_pattern=[0, None, None, None, None, None, None, None, 0, None, None, None, None, None, None, None],
        arp_pattern=[0, None, 1, None, 2, None, 1, None, 0, None, 1, None, 2, None, 1, None],
        lead_phrases=[
            [(0, 69, 8), (8, 65, 8)],
            [(0, 62, 8), (8, 65, 8)],
            [(0, 67, 8), (8, 62, 8)],
            [(0, 64, 12), (12, 62, 4)],
        ],
        drum_style="ambient",
        bass_wave="sub",
        lead_wave="triangle",
        arp_wave="triangle",
        pad_gain=0.22,
        lead_cutoff=(0.24, 0.08),
        delay_wet=0.36,
    )


if __name__ == "__main__":
    out_directory = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "bgm")
    build_all(os.path.abspath(out_directory))
