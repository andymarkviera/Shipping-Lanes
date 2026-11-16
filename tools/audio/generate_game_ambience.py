"""Original CC0 synthesis for in-game ambience. No samples; standard library only.
Run: python tools/audio/generate_game_ambience.py
"""
import math
import random
from generate_menu_beach import RATE, COUNT, OUT, write

KINDS = ('wash', 'wind', 'harbour', 'ice', 'rain', 'desert')


def channel(kind, seed):
    rng = random.Random(seed)
    low = slow = phase = 0.0
    samples = []
    for i in range(COUNT + RATE):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.08 * (noise - low)
        slow += 0.005 * (noise - slow)
        gust = 0.6 + 0.4 * math.sin(math.tau * t / 16) ** 2
        if kind == 'wash':
            value = low * (0.16 + 0.3 * math.sin(math.tau * t / 4) ** 4)
        elif kind == 'wind':
            value = (low - slow) * 0.32 * gust
        elif kind == 'desert':
            value = (noise - low) * 0.035 * gust + slow * 0.18
        elif kind == 'rain':
            # Broadband rain with a distant, slowly pulsing city rumble.
            value = noise * 0.045 + slow * 0.25 + 0.012 * math.sin(math.tau * 75 * t) * gust
        elif kind == 'harbour':
            # Crane motor/metal squeak and a soft, distant two-tone horn.
            cycle = t % 16
            motor = math.sin(math.pi * min(cycle / 6, 1)) ** 2 if cycle < 6 else 0
            horn = math.sin(math.pi * (cycle - 10) / 2) ** 2 if 10 < cycle < 12 else 0
            phase += math.tau * (420 + 35 * math.sin(t * 2)) / RATE
            value = motor * (low * 0.12 + 0.018 * math.sin(phase))
            value += horn * 0.045 * (math.sin(math.tau * 110 * t) + 0.4 * math.sin(math.tau * 165 * t))
        else:
            # Low wind and slow bowed-ice groans, with soft crackle.
            cycle = t % 16
            creak = math.sin(math.pi * (cycle - 4) / 5) ** 2 if 4 < cycle < 9 else 0
            phase += math.tau * (180 + 70 * math.sin(t * 0.8)) / RATE
            value = low * 0.15 * gust + creak * (0.04 * math.sin(phase) + 0.012 * noise)
        samples.append(value)
    # One-second overlap: outgoing continuation is the incoming start.
    for i in range(RATE):
        blend = 0.5 - 0.5 * math.cos(math.pi * i / RATE)
        samples[i] = samples[COUNT + i] * (1 - blend) + samples[i] * blend
    return samples[:COUNT]


if __name__ == '__main__':
    for k, kind in enumerate(KINDS):
        write('game_' + kind + '.wav', [channel(kind, 29180 + k * 2), channel(kind, 29181 + k * 2)])
