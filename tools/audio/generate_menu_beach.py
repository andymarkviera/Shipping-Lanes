"""Bake original CC0 beach ambience; Python standard library, no recordings.
Run from any directory. Runtime only plays these baked PCM loops.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
SECONDS = 32
COUNT = RATE * SECONDS
OUT = Path(__file__).resolve().parents[2] / 'features/audio'


def write(name, channels):
    with wave.open(str(OUT / name), 'wb') as wav:
        wav.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(b''.join(struct.pack('<hh', *(round(max(-1, min(1, c[i])) * 32767) for c in channels)) for i in range(COUNT)))


def surf(seed):
    rng = random.Random(seed)
    # Warm the filter, then crossfade one second of overlap into the start.
    low = 0.0
    samples = []
    for i in range(COUNT + RATE):
        low += 0.13 * (rng.uniform(-1, 1) - low)
        t = i / RATE
        swell = (0.5 + 0.5 * math.sin(math.tau * t / 8)) ** 2
        samples.append(low * (0.16 + 0.48 * swell))
    for i in range(RATE):
        blend = 0.5 - 0.5 * math.cos(math.pi * i / RATE)
        samples[i] = samples[COUNT + i] * (1 - blend) + samples[i] * blend
    return samples[:COUNT]


def gulls():
    channels = [[0.0] * COUNT for _ in range(2)]
    # Distant two/three-syllable calls with smooth envelopes and falling pitch.
    for start, pan in [(5.2, -0.5), (18.4, 0.6), (26.0, -0.2)]:
        for syllable, duration in enumerate([0.34, 0.6, 0.42]):
            phase = 0.0
            for i in range(int(duration * RATE)):
                t = i / RATE
                u = t / duration
                frequency = 1150 + 480 * math.sin(math.pi * u) - 300 * u + 35 * math.sin(43 * t)
                phase += math.tau * frequency / RATE
                value = (math.sin(phase) + 0.22 * math.sin(2 * phase)) * math.sin(math.pi * u) ** 2 * 0.065
                index = int((start + syllable * 0.75) * RATE) + i
                channels[0][index] += value * (1 - pan) / 2
                channels[1][index] += value * (1 + pan) / 2
    return channels


if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    write('menu_surf.wav', [surf(2917), surf(2918)])
    write('menu_gulls.wav', gulls())
