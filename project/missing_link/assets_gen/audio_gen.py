#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
НЕДОСТАЮЩЕЕ ЗВЕНО — генератор звука [audio-06]
100% синтез: numpy → WAV 44100/16бит. Запуск: python3 audio_gen.py
Выход: ../assets/audio/*.wav
Лупы бесшовные: все LFO — целое число периодов на длину выборки.
"""
import os, math, wave, random
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "audio"))
os.makedirs(OUT, exist_ok=True)
random.seed(1971); np.random.seed(1971)

def save(name, data, gain=0.9):
    """data: float32 [-1..1]"""
    data = np.asarray(data, dtype=np.float32)
    peak = np.max(np.abs(data)) + 1e-9
    data = data / peak * gain
    pcm = (data * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("  +", name, f"({len(data)/SR:.2f}s)")

def t(dur): return np.arange(int(SR * dur)) / SR

def lowpass(x, alpha):
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc); y[i] = acc
    return y

def env_ad(n, a, d):
    """атака-спад (сек)"""
    e = np.ones(n)
    na, nd = int(a * SR), int(d * SR)
    na = min(na, n); nd = min(nd, n)
    e[:na] = np.linspace(0, 1, na)
    if nd > 0: e[-nd:] *= np.linspace(1, 0, nd)
    return e

# ------------------------------------------------------------- дрон зала
def drone(freqs, dur, noise_amt=0.3, seed=1, sub=None, thump_every=None):
    n = int(SR * dur); tt = np.arange(n) / SR
    rng = np.random.RandomState(seed)
    out = np.zeros(n, dtype=np.float32)
    for f in freqs:
        k = max(1, round(f * dur))            # целое число периодов → бесшовный луп
        fl = k / dur
        lfo_k = max(1, round((0.05 + rng.rand() * 0.1) * dur))
        lfo = 0.5 + 0.5 * np.sin(2 * math.pi * (lfo_k / dur) * tt + rng.rand() * 6.28)
        out += np.sin(2 * math.pi * fl * tt + rng.rand() * 6.28) * lfo
    out /= len(freqs)
    # бурый шум
    w = rng.randn(n).astype(np.float32)
    b = np.cumsum(w); b -= np.linspace(b[0], b[-1], n)
    b /= (np.max(np.abs(b)) + 1e-9)
    out += b * noise_amt
    if sub is not None:
        out += np.sin(2 * math.pi * sub * tt) * 0.2
    if thump_every:
        for t0 in np.arange(dur * 0.3, dur, thump_every):
            i0 = int(t0 * SR); L = int(0.5 * SR)
            if i0 + L > n: L = n - i0
            if L <= 0: break
            out[i0:i0 + L] += np.sin(2 * math.pi * 38 * np.arange(L) / SR) * np.exp(-np.arange(L) / (SR * 0.08)) * 0.5
    return out

def gen_drones():
    save("drone_hall.wav", drone([46, 52.3, 61.7], 24, noise_amt=0.35, seed=1, thump_every=7.3), 0.55)
    save("drone_wing.wav", drone([98, 147, 155.6], 18, noise_amt=0.18, seed=2), 0.4)
    save("drone_menu.wav", drone([38, 44.5, 57.3], 20, noise_amt=0.4, seed=3, sub=19), 0.6)

# ------------------------------------------------------------- сердцебиение
def gen_heartbeat():
    dur = 1.5; n = int(SR * dur)
    out = np.zeros(n, dtype=np.float32)
    def thump(t0, f, amp, decay):
        i0 = int(t0 * SR); L = int(0.25 * SR)
        i0 = min(i0, n - 1); L = min(L, n - i0)
        idx = np.arange(L)
        out[i0:i0 + L] += (np.sin(2 * math.pi * f * idx / SR) + 0.3 * np.sin(2 * math.pi * f * 2 * idx / SR)) * np.exp(-idx / (SR * decay)) * amp
    thump(0.05, 58, 1.0, 0.045); thump(0.32, 47, 0.7, 0.04)
    save("heartbeat.wav", out, 0.8)

# ------------------------------------------------------------- скрипы сухожилий
def gen_creaks():
    for i in range(4):
        dur = random.uniform(0.5, 1.1)
        n = int(SR * dur)
        f0 = random.uniform(160, 260)
        burst = np.zeros(n, dtype=np.float32)
        pos = 0
        while pos < n:
            L = int(random.uniform(0.04, 0.12) * SR); L = min(L, n - pos)
            idx = np.arange(L)
            f = f0 * random.uniform(0.9, 1.35)
            ph = np.cumsum(np.full(L, f)) / SR * 2 * math.pi + np.random.randn(L) * 0.15
            s = np.sin(ph) * env_ad(L, 0.01, L / SR * 0.8)
            burst[pos:pos + L] += s * random.uniform(0.4, 1.0)
            pos += L + int(random.uniform(0.01, 0.05) * SR)
        w = np.random.randn(n).astype(np.float32) * 0.15
        save(f"creak_{i+1}.wav", burst + w, 0.6)

# ------------------------------------------------------------- шаги
def gen_steps():
    for i in range(4):
        n = int(0.34 * SR)
        w = np.random.randn(n).astype(np.float32)
        thump = np.sin(2 * math.pi * 165 * np.arange(n) / SR) * np.exp(-np.arange(n) / (SR * 0.035))
        knock = np.sin(2 * math.pi * 95 * np.arange(n) / SR) * np.exp(-np.arange(n) / (SR * 0.06)) * 0.6
        step = lowpass(w, 0.22) * env_ad(n, 0.002, 0.16) * 0.8 + thump * 0.9 + knock
        save(f"step_{i+1}.wav", step, 0.5 + i * 0.05)

# ------------------------------------------------------------- двери
def gen_doors():
    # открывание: длинный скрип
    dur = 2.2; n = int(SR * dur)
    tt = np.arange(n) / SR
    f = 140 + 70 * np.sin(2 * math.pi * 0.7 * tt) + 60 * tt / dur
    ph = np.cumsum(f) / SR * 2 * math.pi
    body = np.sin(ph) * (0.4 + 0.6 * np.sin(2 * math.pi * 1.3 * tt) ** 2)
    body *= env_ad(n, 0.15, 0.5)
    clack = np.zeros(n); L = int(0.05 * SR)
    clack[:L] = np.random.randn(L) * np.exp(-np.arange(L) / (SR * 0.006))
    save("door_open.wav", body * 0.7 + clack * 0.5, 0.7)
    # заперто: стук + дребезг
    n = int(1.1 * SR); out = np.zeros(n)
    for t0, amp in [(0.0, 1.0), (0.28, 0.8), (0.52, 0.9), (0.6, 0.4), (0.68, 0.3)]:
        i0 = int(t0 * SR); L = int(0.09 * SR)
        out[i0:i0 + L] += np.sin(2 * math.pi * 120 * np.arange(L) / SR) * np.exp(-np.arange(L) / (SR * 0.02)) * amp
        out[i0:i0 + L] += np.random.randn(L) * 0.2 * amp * np.exp(-np.arange(L) / (SR * 0.01))
    save("door_locked.wav", out, 0.75)

# ------------------------------------------------------------- чеканка печати
def gen_seal():
    n = int(1.6 * SR)
    out = np.zeros(n)
    for f, amp, dec in [(523, 0.5, 0.5), (1310, 0.35, 0.35), (2180, 0.2, 0.22), (392, 0.4, 0.8)]:
        out += np.sin(2 * math.pi * f * np.arange(n) / SR) * np.exp(-np.arange(n) / (SR * dec)) * amp
    i0 = int(1.05 * SR); L = n - i0   # «отклик» второй чеканки
    out[i0:] += np.sin(2 * math.pi * 523 * np.arange(L) / SR) * np.exp(-np.arange(L) / (SR * 0.4)) * 0.25
    save("seal_pickup.wav", out, 0.65)

# ------------------------------------------------------------- PA: гонг + голос
def gen_pa():
    # гонг
    n = int(2.2 * SR); tt = np.arange(n) / SR
    wow = 1.0 + 0.008 * np.sin(2 * math.pi * 1.7 * tt)
    ph = np.cumsum(220 * wow) / SR * 2 * math.pi
    gong = np.sin(ph) * np.exp(-tt / 0.7) * 0.8
    gong += np.sin(np.cumsum(220 * 2.76 * wow) / SR * 2 * math.pi) * np.exp(-tt / 0.3) * 0.4
    gong += np.sin(np.cumsum(220 * 5.4 * wow) / SR * 2 * math.pi) * np.exp(-tt / 0.2) * 0.2
    hiss = np.random.randn(n) * 0.02
    save("pa_gong.wav", gong + hiss, 0.6)
    # «голос»: слоговое бормотание сквозь плёнку
    dur = 4.5; n = int(SR * dur); out = np.zeros(n)
    pos = int(0.3 * SR)
    rng = np.random.RandomState(7)
    while pos < n - int(0.3 * SR):
        L = int(rng.uniform(0.07, 0.16) * SR); L = min(L, n - pos)
        f0 = rng.uniform(95, 130)
        f1 = rng.uniform(350, 900); f2 = rng.uniform(1300, 2600)
        idx = np.arange(L); tt2 = idx / SR
        buzz = np.sign(np.sin(2 * math.pi * f0 * tt2)) * 0.5
        noise = rng.randn(L).astype(np.float32)
        b1 = np.sin(2 * math.pi * f1 * tt2) * 0.6
        b2 = np.sin(2 * math.pi * f2 * tt2) * 0.3
        syl = (buzz * 0.5 + (noise * 0.4 + b1 + b2) * 0.5) * env_ad(L, 0.01, 0.05)
        out[pos:pos + L] += syl
        pos += L + int(rng.uniform(0.02, 0.09) * SR)
    out = lowpass(out, 0.35); out = lowpass(out, 0.35)
    out += np.random.randn(n) * 0.012
    save("pa_voice.wav", out, 0.5)

# ------------------------------------------------------------- скример
def gen_sting():
    dur = 1.3; n = int(SR * dur); tt = np.arange(n) / SR
    burst = np.random.randn(int(0.05 * SR)) * np.exp(-np.arange(int(0.05 * SR)) / (SR * 0.012))
    noise = np.zeros(n); noise[:len(burst)] += burst * 2.0
    f_top = 1800 * np.exp(-tt * 2.2) + 120
    fall = np.sin(np.cumsum(f_top) / SR * 2 * math.pi) * np.exp(-tt * 1.8) * 0.8
    sub = np.sin(2 * math.pi * 44 * tt) * np.exp(-tt / 0.5)
    save("scare_sting.wav", noise + fall + sub, 0.98)

# ------------------------------------------------------------- шёпот/бумага/статика
def gen_misc():
    # шёпот
    dur = 3.5; n = int(SR * dur); tt = np.arange(n) / SR
    w = np.random.randn(n).astype(np.float32)
    fc = 1200 + 900 * np.sin(2 * math.pi * 0.7 * tt)
    ph = np.cumsum(fc) / SR * 2 * math.pi
    wh = np.sin(ph) * 0.5 + w * 0.5
    syl = 0.5 + 0.5 * np.sin(2 * math.pi * 3.3 * tt + np.sin(2 * math.pi * 0.9 * tt) * 2)
    save("whisper.wav", wh * syl, 0.28)
    # бумага
    n = int(0.7 * SR)
    paper = np.random.randn(n) * 0.5
    for _ in range(26):
        i0 = random.randint(0, n - 400); L = random.randint(60, 400)
        paper[i0:i0 + L] += np.random.randn(L) * np.exp(-np.arange(L) / 60.0)
    paper = lowpass(paper, 0.5)
    save("paper.wav", paper * env_ad(n, 0.02, 0.3), 0.4)
    # статика
    dur = 6; n = int(SR * dur)
    st = np.random.randn(n).astype(np.float32) * 0.5
    for _ in range(90):
        i0 = random.randint(0, n - 200); L = random.randint(20, 160)
        st[i0:i0 + L] += np.random.randn(L) * 3.0 * np.exp(-np.arange(L) / 40.0)
    save("static_loop.wav", lowpass(st, 0.6), 0.5)
    # клик фонаря
    n = int(0.12 * SR)
    click = np.sin(2 * math.pi * 900 * np.arange(n) / SR) * np.exp(-np.arange(n) / (SR * 0.004))
    click += np.random.randn(n) * 0.4 * np.exp(-np.arange(n) / (SR * 0.003))
    save("flashlight_click.wav", click, 0.4)

if __name__ == "__main__":
    print("[audio-06] Синтез звука →", OUT)
    gen_drones(); gen_heartbeat(); gen_creaks(); gen_steps(); gen_doors()
    gen_seal(); gen_pa(); gen_sting(); gen_misc()
    print("[audio-06] Готово.")
