#!/usr/bin/env python3
"""Synthesizes the game's sound effects into audio/*.wav.

Everything is generated from sine waves and filtered noise, so the sounds need
no external assets or licenses. Uses only the Python standard library:

    python3 tools/generate_sounds.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio"


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(dst, src, at=0.0, gain=1.0):
    """Adds `src` into `dst` starting at `at` seconds, growing `dst` as needed."""
    start = int(at * RATE)
    if len(dst) < start + len(src):
        dst.extend([0.0] * (start + len(src) - len(dst)))
    for i, s in enumerate(src):
        dst[start + i] += s * gain
    return dst


def tone(freq, seconds, decay, partials=((1.0, 1.0),), attack=0.004, sweep=0.0):
    """Sum of decaying sine partials. `sweep` bends the pitch by that fraction per second."""
    out = []
    phases = [0.0] * len(partials)
    for i in range(int(seconds * RATE)):
        t = i / RATE
        env = math.exp(-t / decay) * min(1.0, t / attack)
        f = freq * (1.0 + sweep * t)
        s = 0.0
        for p, (ratio, weight) in enumerate(partials):
            phases[p] += 2.0 * math.pi * f * ratio / RATE
            s += math.sin(phases[p]) * weight
        out.append(s * env)
    return out


def noise(seconds, decay, cutoff, rng):
    """Low-passed white noise with an exponential decay."""
    out = []
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    y = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        y += alpha * (rng.uniform(-1.0, 1.0) - y)
        out.append(y * math.exp(-t / decay))
    return out


def bubble(freq, seconds=0.07):
    """A bubble pop: a sine whose pitch rises quickly while it fades out."""
    return tone(freq, seconds, decay=0.022, attack=0.002, sweep=6.0)


BELL = ((1.0, 1.0), (2.0, 0.35), (3.01, 0.15), (4.2, 0.06))


def pick():
    # Light glass "tink" when a bottle is picked up.
    return tone(1760.0, 0.25, decay=0.05, partials=((1.0, 1.0), (1.51, 0.5), (2.33, 0.25)))


def invalid():
    # Soft low "bonk" for a move that is not allowed.
    s = tone(170.0, 0.22, decay=0.06, sweep=-1.5, partials=((1.0, 1.0), (2.0, 0.2)))
    return mix(s, noise(0.03, 0.008, 1500.0, random.Random(3)), gain=0.4)


def pour():
    # A stream of bubbles that rise in pitch as the bottle fills.
    rng = random.Random(7)
    s = noise(0.7, 0.5, 900.0, rng)
    s = [x * 0.25 for x in s]
    t = 0.0
    while t < 0.62:
        mix(s, bubble(rng.uniform(380.0, 520.0) * (1.0 + 0.9 * t)), at=t, gain=rng.uniform(0.6, 1.0))
        t += rng.uniform(0.045, 0.085)
    return s


def cork():
    # Cork "pop" followed by a two-note chime when a bottle is finished.
    s = tone(520.0, 0.06, decay=0.012, attack=0.001, sweep=-8.0)
    mix(s, noise(0.04, 0.006, 3000.0, random.Random(11)), gain=0.6)
    mix(s, tone(1318.5, 0.7, decay=0.18, partials=BELL), at=0.06, gain=0.45)
    mix(s, tone(1975.5, 0.8, decay=0.22, partials=BELL), at=0.16, gain=0.4)
    return s


def victory():
    # Rising arpeggio that lands on a ringing major chord.
    notes = [523.25, 659.25, 783.99, 1046.5]
    s = []
    for i, f in enumerate(notes):
        mix(s, tone(f, 0.5, decay=0.14, partials=BELL), at=i * 0.11, gain=0.5)
    for f in notes + [1318.5]:
        mix(s, tone(f, 1.6, decay=0.5, partials=BELL), at=0.5, gain=0.22)
    return s


def write(name, samples, peak, fade=0.01):
    # Normalize, fade out the tail to avoid clicks, and save as 16-bit mono PCM.
    top = max(abs(x) for x in samples) or 1.0
    n = len(samples)
    fade_n = int(fade * RATE)
    frames = bytearray()
    for i, x in enumerate(samples):
        g = peak / top
        if i >= n - fade_n:
            g *= (n - i) / fade_n
        frames += struct.pack("<h", int(max(-1.0, min(1.0, x * g)) * 32767))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print(f"audio/{name}.wav  {n / RATE:.2f}s")


def main():
    OUT.mkdir(exist_ok=True)
    # Peaks leave headroom so overlapping sounds (cork over a pour, victory over a cork) don't clip.
    write("pick", pick(), peak=0.3)
    write("invalid", invalid(), peak=0.35)
    write("pour", pour(), peak=0.4)
    write("cork", cork(), peak=0.45)
    write("victory", victory(), peak=0.5)


if __name__ == "__main__":
    main()
