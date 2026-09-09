#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SCALA NATURAE — procedural SFX/ambient generator (worker-7).
Pure-python WAV synth (22.05 kHz, mono, 16-bit). Output: ../game/assets/audio/
"""
import math, os, random, struct, wave
import numpy as np

random.seed(1912)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 22050

def env_ar(n, a=0.01, r=0.3):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    if na < n: e[:na] = np.linspace(0, 1, na)
    if nr < n: e[-nr:] = np.linspace(1, 0, nr) ** 1.2
    return e

def save(name, x, amp=0.85):
    x = np.clip(x, -1, 1) * amp
    data = (x * 32767).astype(np.int16)
    p = os.path.join(OUT, name)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("audio:", name, os.path.getsize(p) // 1024, "KB")

def noise(n, lp=0.0):
    x = np.random.default_rng().normal(0, 1, n)
    if lp > 0:
        b = math.exp(-2 * math.pi * lp / SR)
        y = np.empty_like(x); acc = 0.0
        for i in range(n):
            acc = acc * b + x[i] * (1 - b)
            y[i] = acc
        x = y
    return x

def tone(freqs, n, amp=1.0, slide=0.0):
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f0, a in freqs:
        f = f0 * (1 + slide * t)
        ph = np.cumsum(2 * math.pi * f / SR)
        x += a * np.sin(ph)
    return x * amp

# ---------- ШАГИ ----------
def steps():
    # wood
    for name, spec in [("step_wood", dict(f0=210, thud=90, click=0.4)),
                       ("step_stone", dict(f0=140, thud=40, click=0.2)),
                       ("step_mud", dict(f0=95, thud=0, click=0.0))]:
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        x = np.zeros(n)
        x += np.exp(-t * 22) * np.sin(2 * math.pi * spec["f0"] * t) * 1.0
        x += np.exp(-t * 60) * noise(n, lp=900) * spec["click"]
        if spec["thud"] > 0:
            x += np.exp(-t * 9) * np.sin(2 * math.pi * spec["thud"] * t) * 0.5
        save(name, x, 0.7)

# ---------- КЛИКИ / ДВЕРИ / СКРИПЫ ----------
def ticks():
    for name, f0, d, amp in [("tick", 1400, 0.045, 0.3), ("click", 900, 0.03, 0.5)]:
        n = int(d * SR)
        x = noise(n, lp=2500) * env_ar(n, 0.001, 0.5) * amp
        x += tone([(f0, 1.0)], n, slide=0.4) * env_ar(n, 0.001, 0.6) * amp
        save(name, x, 0.5)

def door_creak():
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    f = 120 + 380 * (t / n) ** 1.5 + 60 * np.sin(t * 7)
    ph = np.cumsum(2 * math.pi * f / SR)
    x = np.sin(ph) * (0.5 + 0.5 * np.sin(t * 11)) ** 2
    x *= env_ar(n, 0.25, 0.3)
    x += noise(n, lp=600) * 0.12 * env_ar(n, 0.2, 0.5)
    save("door", x, 0.6)
    # отдельный «скрип-стона» (длиннее, тоньше)
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    f = 220 + 700 * np.sin(t * 0.9) ** 2 + 40 * np.sin(t * 3.1)
    ph = np.cumsum(2 * math.pi * f / SR)
    x = np.sin(ph) * (0.35 + 0.65 * np.sin(t * 1.3) ** 4)
    x *= np.clip(np.sin(np.pi * np.linspace(0, 1, n)) ** 0.6 + 0.15, 0, 1)
    x += noise(n, lp=900) * 0.08
    save("creak", x, 0.4)

def page():
    n = int(0.28 * SR)
    x = noise(n, lp=4000) * np.clip(np.linspace(1, 0, n) * 1.4 + 0.05, 0, 1) ** 1.4
    save("page", x, 0.5)

# ---------- АМБИЕНТ ----------
def drone():
    dur = 30
    n = dur * SR
    t = np.arange(n) / SR
    x = tone([(55, 0.5), (55.7, 0.4), (82.4, 0.3), (110.1, 0.22), (164.8, 0.1), (220.3, 0.06)], n)
    x *= 0.7 + 0.3 * np.sin(t * 0.11 + 1.0)
    x += tone([(55, 0.2)], n, slide=0.0009) * (0.6 + 0.4 * np.sin(t * 0.043))
    wn = noise(n, lp=300) * 0.35
    x = x + wn
    # медленные «вздохи» — приподнятие шума
    breath = 0.5 + 0.5 * np.sin(t * 0.07 + 2.0) ** 3
    x += noise(n, lp=700) * 0.12 * breath
    save("drone", x, 0.5)

def whisper():
    for i in range(3):
        dur = random.uniform(2.0, 4.2)
        n = int(dur * SR)
        x = noise(n, lp=1400)
        # «слоговая» огибающая
        env = np.zeros(n)
        pos = 0
        while pos < n:
            ln = int(SR * random.uniform(0.08, 0.3))
            peak = random.uniform(0.5, 1.0)
            seg = np.linspace(0, 1, ln) ** 1.5
            seg = np.sin(np.pi * seg) ** 0.8 * peak
            end = min(pos + ln, n)
            env[pos:end] = seg[:end - pos]
            pos = end + int(SR * random.uniform(0.03, 0.25))
        x *= env
        x += tone([(900, 0.06), (1400, 0.05)], n) * env
        x *= np.clip(np.sin(np.pi * np.linspace(0, 1, n)) * 1.3, 0, 1) ** 0.7
        save(f"whisper{i}.wav", x, 0.4)

def sting():
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    f0 = 82.0
    x = tone([(f0, 0.5), (f0 * 2, 0.35), (f0 * 1.5, 0.3), (f0 * 2.98, 0.2)], n, amp=0.6)
    x += noise(n, lp=400) * np.linspace(0, 1, n) ** 2 * 0.5
    x *= np.clip(np.linspace(0, 1, n), 0, 1) ** 1.6 * env_ar(n, 0.01, 0.35)
    x *= np.clip(np.sin(np.pi * np.linspace(0, 1, n)) * 1.8, 0, 1) ** 0.9
    save("sting", x, 0.55)

def heart():
    n = int(1.0 * SR)
    x = np.zeros(n)
    for (t0, f, d) in [(0.0, 60, 0.12), (0.22, 48, 0.14)]:
        m = int(t0 * SR)
        ln = int(d * SR)
        tt = np.arange(ln) / SR
        seg = np.exp(-tt * 26) * np.sin(2 * math.pi * f * tt)
        seg += np.exp(-tt * 40) * noise(ln, lp=300) * 0.2
        x[m:m + ln] += seg
    save("heart", x, 0.7)

def bell():
    dur = 5.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = tone([(196, 0.8), (392, 0.35), (587, 0.2), (784, 0.16), (980, 0.12), (196*2.9, 0.09), (196*3.6, 0.06)], n)
    for i, p in enumerate([196, 392, 587, 784, 980]):
        x[:] = x  # noop
    dec = np.exp(-t * 1.1) ** 1.2
    x *= dec
    save("bell", x, 0.6)

def water():
    dur = 4.0
    n = int(dur * SR)
    x = np.zeros(n)
    rng = random.Random(7)
    pos = 0
    while pos < n:
        ln = int(SR * rng.uniform(0.04, 0.2))
        f0 = rng.uniform(240, 500)
        tt = np.arange(ln) / SR
        f = f0 * (1 - tt * 6)
        ph = np.cumsum(2 * math.pi * f / SR)
        seg = np.sin(ph) * np.exp(-tt * 9) * rng.uniform(0.3, 1)
        seg += noise(ln, lp=800) * np.exp(-tt * 14) * 0.4
        end = min(pos + ln, n)
        x[pos:end] += seg[:end - pos]
        pos = end + int(SR * rng.uniform(0.03, 0.6))
    x += noise(n, lp=200) * 0.06
    save("water", x, 0.5)

def whoosh():
    n = int(1.1 * SR)
    x = noise(n, lp=900)
    e = np.sin(np.pi * np.linspace(0, 1, n)) ** 2.2
    x *= e
    save("whoosh", x, 0.4)

if __name__ == "__main__":
    print("Generating audio into", OUT)
    steps(); ticks(); door_creak(); page(); drone(); whisper(); sting(); heart(); bell(); water(); whoosh()
    print("ALL AUDIO DONE")
