"""Synthesises the game's sound effects and music loops as WAV files.

Everything here is generated from code (no samples), so the audio is
original and free of licence questions. Run through build_audio.py, which
also normalises loudness (AUD-05) and encodes to .m4a.

Usage: python synth.py <output dir>
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100


# ---------------------------------------------------------------- basics

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def osc(phase, shape):
    p = phase % 1.0
    if shape == "sine":
        return math.sin(2 * math.pi * p)
    if shape == "triangle":
        return 4 * abs(p - 0.5) - 1
    if shape == "square":
        return 1.0 if p < 0.5 else -1.0
    if shape == "soft":  # rounded square: sine plus a little third harmonic
        return math.sin(2 * math.pi * p) + 0.3 * math.sin(6 * math.pi * p)
    raise ValueError(shape)


def tone(freq, seconds, shape="sine", attack=0.005, release=0.08, vibrato=0.0,
         vib_rate=6.0, volume=1.0):
    """A note. freq may be a number or a function of t (0..1)."""
    n = int(seconds * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        f = freq(t) if callable(freq) else freq
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * vib_rate * i / RATE)
        phase += f / RATE
        env = min(1.0, i / max(1, attack * RATE))
        tail = (n - i) / max(1, release * RATE)
        env = min(env, tail, 1.0)
        out.append(volume * env * osc(phase, shape))
    return out


def noise(seconds, seed, smooth=0.0, volume=1.0, envelope=None):
    """White noise, optionally low-passed (smooth 0..0.99)."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out, last = [], 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        last = smooth * last + (1 - smooth) * x
        t = i / max(1, n - 1)
        env = envelope(t) if envelope else 1.0
        out.append(volume * env * last)
    return out


def decay(samples, rate=6.0):
    n = len(samples)
    return [s * math.exp(-rate * i / n) for i, s in enumerate(samples)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def at(samples, seconds, length):
    """Places samples at a time offset inside a buffer of length seconds."""
    out = [0.0] * int(length * RATE)
    start = int(seconds * RATE)
    for i, s in enumerate(samples):
        if start + i < len(out):
            out[start + i] += s
    return out


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.8 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767))
            for s in samples))


def hz(note):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((note - 69) / 12)


# ---------------------------------------------------------- sound effects
# Friendly and soft; failure sounds are funny, never buzzers (FEEL-03).

def sfx():
    s = {}
    s["tap"] = decay(tone(880, 0.07, "triangle", release=0.05), 5)
    s["snap"] = concat(
        decay(noise(0.02, 1, 0.3), 8),
        decay(tone(1320, 0.09, "triangle"), 5))
    s["bolt"] = concat(
        decay(tone(hz(88), 0.08, "triangle"), 2),
        decay(tone(hz(95), 0.3, "triangle"), 5))
    s["jump"] = tone(lambda t: 300 + 500 * t, 0.18, "soft", volume=0.6)
    s["land"] = mix(
        decay(tone(lambda t: 140 - 70 * t, 0.12, "sine"), 4),
        decay(noise(0.08, 2, 0.8, 0.5), 6))
    s["boing"] = tone(lambda t: 160 + 260 * t, 0.45, "soft", vibrato=0.25,
                      vib_rate=14, release=0.15, volume=0.7)
    s["splash"] = mix(
        noise(0.6, 3, 0.6, envelope=lambda t: math.exp(-5 * t)),
        at(decay(tone(lambda t: 600 + 500 * t, 0.06), 3), 0.18, 0.6),
        at(decay(tone(lambda t: 500 + 700 * t, 0.06), 3), 0.3, 0.6),
        at(decay(tone(lambda t: 700 + 600 * t, 0.05), 3), 0.4, 0.6))
    honk = tone(260, 0.16, "square", vibrato=0.03, vib_rate=20, volume=0.35)
    s["honk"] = concat(honk, silence(0.06), honk)
    s["cheer"] = concat(*[
        decay(tone(hz(n), 0.11, "triangle"), 2) for n in (72, 76, 79)],
        decay(tone(hz(84), 0.35, "triangle"), 4))
    s["star"] = mix(
        decay(tone(hz(91), 0.4, "sine"), 5),
        at(decay(tone(hz(96), 0.35, "sine"), 5), 0.06, 0.45))
    s["reveal"] = concat(
        *[decay(tone(hz(n), 0.09, "triangle"), 2) for n in (67, 71, 74, 79)],
        mix(decay(tone(hz(83), 0.5, "sine"), 4),
            decay(tone(hz(88), 0.5, "sine", volume=0.5), 4)))
    s["unlock"] = concat(
        decay(tone(hz(72), 0.12, "triangle"), 2),
        mix(decay(tone(hz(76), 0.45, "triangle"), 4),
            decay(tone(hz(79), 0.45, "triangle"), 4),
            decay(tone(hz(84), 0.45, "triangle"), 4)))
    s["swing"] = noise(0.35, 4, 0.85,
                       envelope=lambda t: math.sin(math.pi * t))
    s["door"] = mix(
        noise(0.35, 5, 0.9, 0.7, envelope=lambda t: 1 - t),
        tone(lambda t: 220 - 120 * t, 0.35, "triangle", volume=0.4))
    s["whoosh"] = noise(0.4, 6, 0.7, envelope=lambda t: math.sin(math.pi * t))
    s["jetpack"] = noise(0.6, 7, 0.95,
                         envelope=lambda t: min(1, 6 * t) * (1 - t))
    s["shake"] = concat(*[
        concat(decay(noise(0.025, 10 + i, 0.4), 10), silence(0.035))
        for i in range(6)])
    s["yawn"] = tone(lambda t: 420 - 200 * t, 0.9, "soft", attack=0.15,
                     release=0.3, vibrato=0.02, vib_rate=5, volume=0.5)
    return s


# ------------------------------------------------------------------ music
# Short, original, looping tunes (AUD-01). Each pattern is a list of
# (MIDI note or None, beats). The loop length is a whole number of bars so
# it repeats without a gap.

def render_line(pattern, bpm, shape, volume, octave=0, release=0.06):
    out = []
    for note, beats in pattern:
        secs = beats * 60.0 / bpm
        if note is None:
            out.extend(silence(secs))
        else:
            out.extend(tone(hz(note + 12 * octave), secs, shape,
                            release=min(release, secs / 2), volume=volume))
    return out


def drums(bars, bpm, seed):
    beat = 60.0 / bpm
    length = bars * 4 * beat
    parts = []
    for b in range(bars * 4):
        kick = decay(tone(lambda t: 110 - 60 * t, 0.12, "sine"), 5)
        parts.append(at(kick, b * beat, length) if b % 2 == 0 else [])
        hat = decay(noise(0.04, seed + b, 0.2, 0.25), 9)
        parts.append(at(hat, b * beat + beat / 2, length))
    return mix(*[p for p in parts if p])


def song(melody, bass, bpm, bars, shape, seed, repeats=2):
    one = mix(
        render_line(melody, bpm, shape, 0.5),
        render_line(bass, bpm, "sine", 0.55, octave=-1),
        drums(bars, bpm, seed))
    return one * repeats


def music():
    q, h, e = 1, 2, 0.5  # quarter, half and eighth notes in beats
    tracks = {}
    # Menus: calm, C major pentatonic.
    tracks["menus"] = song(
        [(72, q), (74, q), (76, h), (79, q), (76, q), (74, h),
         (72, q), (76, q), (79, q), (81, q), (79, 2 * h),
         (76, q), (79, q), (81, h), (79, q), (76, q), (74, h),
         (72, q), (74, q), (76, q), (74, q), (72, 2 * h)],
        [(48, 2 * h), (53, 2 * h), (55, 2 * h), (48, 2 * h),
         (57, 2 * h), (53, 2 * h), (55, 2 * h), (48, 2 * h)],
        bpm=100, bars=8, shape="triangle", seed=100)
    # Workshop: bouncy, F major.
    tracks["workshop"] = song(
        [(77, e), (81, e), (84, q), (81, e), (77, e), (79, q),
         (77, e), (79, e), (81, q), (79, h),
         (82, e), (81, e), (79, q), (77, e), (76, e), (77, q),
         (72, e), (74, e), (76, q), (77, h)] * 2,
        [(41, q), (48, q), (41, q), (48, q), (46, q), (53, q), (48, q),
         (55, q)] * 4,
        bpm=112, bars=8, shape="soft", seed=200)
    # Run: energetic, G major.
    tracks["run"] = song(
        [(79, e), (79, e), (83, e), (86, e), (84, q), (83, q),
         (81, e), (83, e), (84, e), (81, e), (79, h),
         (76, e), (79, e), (81, e), (83, e), (84, q), (86, q),
         (83, e), (81, e), (79, e), (78, e), (79, h)] * 2,
        [(43, e), (43, e), (50, e), (43, e)] * 16,
        bpm=132, bars=8, shape="square", seed=300)
    # Test Track: playful, D major.
    tracks["testTrack"] = song(
        [(74, q), (78, e), (81, e), (86, q), (81, q),
         (83, q), (81, e), (78, e), (76, h),
         (74, e), (76, e), (78, q), (81, q), (78, q),
         (76, q), (73, q), (74, h)] * 2,
        [(38, h), (45, h), (43, h), (45, h)] * 4,
        bpm=120, bars=8, shape="triangle", seed=400)
    return tracks


def main():
    out = Path(sys.argv[1])
    (out / "sfx").mkdir(parents=True, exist_ok=True)
    (out / "music").mkdir(parents=True, exist_ok=True)
    for name, samples in sfx().items():
        write(out / "sfx" / f"{name}.wav", samples)
    for name, samples in music().items():
        write(out / "music" / f"{name}.wav", samples)


if __name__ == "__main__":
    main()
