#!/usr/bin/env python3
"""Synthesizes the alert sounds in sounds/ (16-bit mono WAV). Run again to recreate them."""
import math, os, struct, wave

RATE = 44100
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(os.path.join(here, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in samples))


def tone(partials, length, decay, attack=0.004, start=0.0, total=None):
    """partials: [(frequency, amplitude)]; exponential decay after a short attack."""
    total = total or length + start
    out = []
    for i in range(int(total * RATE)):
        t = i / RATE - start
        if t < 0 or t > length:
            out.append(0.0)
            continue
        env = min(1, t / attack) * math.exp(-t / decay)
        out.append(env * sum(a * math.sin(2 * math.pi * f * t) for f, a in partials))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def sweep(f0, f1, length, decay):
    out, phase = [], 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        f = f0 * (f1 / f0) ** (t / length)
        phase += 2 * math.pi * f / RATE
        out.append(min(1, t / 0.003) * math.exp(-t / decay) * math.sin(phase))
    return out


os.makedirs(here, exist_ok=True)
write("Ping", tone([(1318.5, 1), (2637, 0.25), (3955, 0.08)], 0.9, 0.22))
write("Chime", mix(tone([(1318.5, 1), (2637, 0.2)], 1.0, 0.3), tone([(1975.5, 0.9), (3951, 0.15)], 1.0, 0.3, start=0.12)))
write("Bell", tone([(880, 1), (880 * 2.76, 0.45), (880 * 5.40, 0.2), (880 * 8.93, 0.08)], 1.4, 0.4))
write("Pop", sweep(700, 180, 0.09, 0.03))
write("Tick", tone([(3000, 1), (4500, 0.5)], 0.035, 0.008, attack=0.001))
write("Bubble", sweep(320, 1100, 0.16, 0.07))
