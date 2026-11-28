"""Procedural SFX generator for Afterburner Zero.
Pure Python stdlib only. Generates 44.1 kHz stereo 16-bit WAV files.
"""
from __future__ import annotations
import math, os, random, struct, wave

SAMPLE_RATE = 44100
TWO_PI = 2.0 * math.pi

def _clamp(x, lo=-1.0, hi=1.0):
    return lo if x < lo else (hi if x > hi else x)

def write_wav(path: str, buf_l: list, buf_r: list, peak_target=0.82):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max((max(abs(a), abs(b)) for a, b in zip(buf_l, buf_r)), default=1e-6)
    scale = peak_target / peak if peak > 0 else 1.0
    n = len(buf_l)
    fade = min(64, n // 10)
    pcm = bytearray(n * 4)
    for i in range(n):
        lv = math.tanh(buf_l[i] * scale * 1.1) * 0.9
        rv = math.tanh(buf_r[i] * scale * 1.1) * 0.9
        if i < fade:
            w = i / fade; lv *= w; rv *= w
        elif i >= n - fade:
            w = (n - 1 - i) / fade; lv *= w; rv *= w
        struct.pack_into("<hh", pcm, i * 4, int(_clamp(lv) * 32767), int(_clamp(rv) * 32767))
    with wave.open(path, "wb") as wf:
        wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm)
    print(f"Generated {path} ({n/SAMPLE_RATE*1000:.0f}ms)")

def mono(samples: list, pan=0.0):
    pan = _clamp(pan, -1.0, 1.0)
    gl = math.sqrt(0.5 * (1 - pan)); gr = math.sqrt(0.5 * (1 + pan))
    return [s * gl for s in samples], [s * gr for s in samples]

# ─── SHOOT SFX ───────────────────────────────────────────────────────────────

def sfx_shoot_cannon(out_dir):
    """Default cannon: sharp blip + noise burst — crisp arcade feel."""
    n = int(0.07 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(42)
    phase = 0.0
    prev_n = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 900.0 * math.exp(-t * 55.0) + 180.0
        phase += TWO_PI * freq / SAMPLE_RATE
        tone = math.sin(phase) * math.exp(-t * 48.0) * 0.55
        raw = rng.uniform(-1.0, 1.0)
        hp = raw - prev_n * 0.5; prev_n = raw
        noise = hp * math.exp(-t * 85.0) * 0.45
        buf[i] = math.tanh((tone + noise) * 1.3)
    write_wav(os.path.join(out_dir, "sfx_shoot_cannon.wav"), *mono(buf))

def sfx_shoot_spread(out_dir):
    """Spread shot: wider, 3-layered pew with slight flange."""
    n = int(0.09 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(99)
    for layer, (f0, detune, amp) in enumerate([(700,1.0,0.4),(750,1.015,0.35),(650,0.985,0.3)]):
        ph = 0.0
        for i in range(n):
            t = i / SAMPLE_RATE
            freq = f0 * detune * math.exp(-t * 40.0) + 120.0
            ph += TWO_PI * freq / SAMPLE_RATE
            env = math.exp(-t * 38.0)
            raw = rng.uniform(-1.0, 1.0)
            buf[i] += (math.sin(ph) * 0.6 + raw * 0.4) * env * amp
    buf = [math.tanh(v * 1.1) for v in buf]
    write_wav(os.path.join(out_dir, "sfx_shoot_spread.wav"), *mono(buf))

def sfx_shoot_laser(out_dir):
    """Laser: rising-pitch zap."""
    n = int(0.12 * SAMPLE_RATE)
    buf = [0.0] * n
    ph = 0.0; lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 220.0 + 1600.0 * math.exp(-t * 18.0)
        ph += TWO_PI * freq / SAMPLE_RATE
        raw = (2.0 * (ph / TWO_PI % 1.0) - 1.0)  # sawtooth
        lp += 0.35 * (raw - lp)
        env = math.exp(-t * 22.0) * (1.0 - math.exp(-t * 80.0))
        buf[i] = math.tanh(lp * env * 2.0)
    write_wav(os.path.join(out_dir, "sfx_shoot_laser.wav"), *mono(buf))

def sfx_shoot_missile(out_dir):
    """Homing missile: whoosh + low thud."""
    n = int(0.14 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(7)
    prev = 0.0; lp1 = 0.0; lp2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        raw = rng.uniform(-1.0, 1.0)
        hp = raw - prev * 0.7; prev = raw
        lp1 += 0.08 * (hp - lp1); lp2 += 0.08 * (lp1 - lp2)
        env_lo = math.exp(-t * 14.0) * (1.0 - math.exp(-t * 40.0))
        env_hi = math.exp(-t * 32.0)
        buf[i] = math.tanh(lp2 * env_lo * 1.8 + hp * env_hi * 0.35)
    write_wav(os.path.join(out_dir, "sfx_shoot_missile.wav"), *mono(buf))

# ─── ENEMY DEATH SFX ─────────────────────────────────────────────────────────

def sfx_die_small(out_dir):
    """Light unit (soldier/army) death: fast pop + crackle."""
    n = int(0.18 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(11)
    ph = 0.0; prev = 0.0; lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 85.0 * math.exp(-t * 22.0) + 42.0
        ph += TWO_PI * freq / SAMPLE_RATE
        body = math.sin(ph) * math.exp(-t * 18.0) * 0.5
        raw = rng.uniform(-1.0, 1.0)
        hp = raw - prev * 0.65; prev = raw
        lp += 0.5 * (hp - lp)
        noise = lp * math.exp(-t * 24.0) * 0.6
        click = math.exp(-t * 150.0) * rng.uniform(-1, 1) * 0.4
        buf[i] = math.tanh((body + noise + click) * 1.4)
    write_wav(os.path.join(out_dir, "sfx_die_small.wav"), *mono(buf))

def sfx_die_medium(out_dir):
    """Medium unit (heli/humvee) death: bigger explosion crunch."""
    n = int(0.28 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(22)
    ph = 0.0; prev = 0.0; lp = 0.0; hp2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 60.0 * math.exp(-t * 14.0) + 32.0
        ph += TWO_PI * freq / SAMPLE_RATE
        body = math.sin(ph) * math.exp(-t * 10.0) * 0.6
        body += (2.0 * (ph / TWO_PI % 1.0) - 1.0) * math.exp(-t * 20.0) * 0.25
        raw = rng.uniform(-1.0, 1.0)
        hp2 = raw - prev * 0.7; prev = raw
        lp += 0.35 * (hp2 - lp)
        noise = (lp * 0.6 + hp2 * 0.4) * math.exp(-t * 16.0) * 0.65
        buf[i] = math.tanh((body + noise) * 1.5)
    l, r = mono(buf, pan=0.0)
    # Slight stereo widening
    delay = int(0.004 * SAMPLE_RATE)
    for i in range(delay, len(l)):
        l[i] += buf[i - delay] * 0.18
        r[i] -= buf[i - delay] * 0.18
    write_wav(os.path.join(out_dir, "sfx_die_medium.wav"), l, r)

def sfx_die_large(out_dir):
    """Large unit / boss phase: deep rumbling explosion."""
    n = int(0.45 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(33)
    ph = 0.0; lp = 0.0; lp2 = 0.0; prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 48.0 * math.exp(-t * 7.0) + 24.0
        ph += TWO_PI * freq / SAMPLE_RATE
        body = math.sin(ph) * math.exp(-t * 7.0) * 0.65
        sub = math.sin(ph * 0.5) * math.exp(-t * 5.0) * 0.35
        raw = rng.uniform(-1.0, 1.0)
        hp = raw - prev * 0.75; prev = raw
        lp += 0.22 * (hp - lp); lp2 += 0.18 * (lp - lp2)
        noise = lp2 * math.exp(-t * 9.0) * 0.75
        # Secondary crack at 50ms
        crack_t = t - 0.05
        crack = math.exp(-crack_t * 35.0) * rng.uniform(-1, 1) * 0.3 if crack_t > 0 else 0.0
        buf[i] = math.tanh((body + sub + noise + crack) * 1.6)
    l, r = mono(buf)
    delay = int(0.006 * SAMPLE_RATE)
    for i in range(delay, len(l)):
        l[i] += buf[i - delay] * 0.22
        r[i] -= buf[i - delay] * 0.22
    write_wav(os.path.join(out_dir, "sfx_die_large.wav"), l, r)

def sfx_hit(out_dir):
    """Generic hit / damage tick on enemy."""
    n = int(0.06 * SAMPLE_RATE)
    buf = [0.0] * n
    rng = random.Random(55)
    ph = 0.0; prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 400.0 * math.exp(-t * 60.0) + 150.0
        ph += TWO_PI * freq / SAMPLE_RATE
        tone = math.sin(ph) * math.exp(-t * 55.0) * 0.55
        raw = rng.uniform(-1.0, 1.0)
        hp = raw - prev * 0.5; prev = raw
        noise = hp * math.exp(-t * 100.0) * 0.45
        buf[i] = math.tanh((tone + noise) * 1.2)
    write_wav(os.path.join(out_dir, "sfx_hit.wav"), *mono(buf))

# ─── ENTRY POINT ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx"))
    sfx_shoot_cannon(out)
    sfx_shoot_spread(out)
    sfx_shoot_laser(out)
    sfx_shoot_missile(out)
    sfx_die_small(out)
    sfx_die_medium(out)
    sfx_die_large(out)
    sfx_hit(out)
