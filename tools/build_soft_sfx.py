#!/usr/bin/env python3
"""Synthesise the soft water-weapon sounds.

The water pistol and bubble blaster used duck squeaks as their fire sound —
funny once, maddening at four shots a second for a whole run. These are the
replacements: short, quiet, watery. A plip (a little sine that falls in pitch
and dies fast) and a soft bubble (two rounded blips). Deliberately low
amplitude — rapid-fire sounds earn their place by staying out of the way.

    python3 tools/build_soft_sfx.py
"""

import math
import os
import struct
import wave

RATE = 44100


def _write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
                               for s in samples))
    print(path, f"{len(samples) / RATE:.3f}s")


def _tone(dur, f0, f1, amp, attack=0.004):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += math.tau * f / RATE
        env = min(1.0, (i / RATE) / attack) * (1.0 - t) ** 2.2
        out.append(math.sin(phase) * amp * env)
    return out


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "audio", "sfx")

    # water plip: one droplet, pitch falling away
    _write(os.path.join(out, "water_plip.wav"), _tone(0.09, 950.0, 320.0, 0.22))

    # soft bubble: two rounded blips, the second lower — a pop underwater
    blip = _tone(0.05, 620.0, 540.0, 0.20, attack=0.008)
    blip += _tone(0.06, 460.0, 380.0, 0.16, attack=0.008)
    _write(os.path.join(out, "bubble_soft.wav"), blip)


if __name__ == "__main__":
    main()
