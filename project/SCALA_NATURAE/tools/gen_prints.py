#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SCALA NATURAE — линогравюры для стен музея (worker-6).
Старые «научные таблицы»: сепия по пожелтевшей бумаге, рамки, подписи.
Выход: ../game/assets/prints/*.png  (1024 px по длинной стороне)
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(1903)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "prints")
os.makedirs(OUT, exist_ok=True)
F_SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
F_SERIF_I = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
F_SERIF_B = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
INK = (62, 46, 30)
INK_L = (110, 88, 60)

def paper(w, h):
    rng = np.random.default_rng(1903)
    base = rng.random((h, w, 1)).astype(np.float32)
    y, x = np.mgrid[0:h, 0:w]
    grad = 1.0 + 0.06 * np.sin(x / w * math.pi * 2 * 3) * np.cos(y / h * math.pi * 3)
    tone = 0.83 + 0.05 * base[..., 0]
    arr = np.stack([tone * grad * 235, tone * grad * 218, tone * grad * 172], -1)
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr).convert("RGB")
    # пятна
    dr = ImageDraw.Draw(img, "RGBA")
    for _ in range(26):
        x0, y0 = random.uniform(0, w), random.uniform(0, h)
        r = random.uniform(8, 90)
        a = random.randint(10, 30)
        dr.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=(140, 120, 80, a))
    for _ in range(300):
        x0, y0 = random.uniform(0, w), random.uniform(0, h)
        dr.point((x0, y0), fill=(90, 75, 50, random.randint(20, 80)))
    return img

def add_frame(dr, w, h, m=46, double=True):
    dr.rectangle([m, m, w - m, h - m], outline=INK, width=3)
    if double:
        dr.rectangle([m + 10, m + 10, w - m - 10, h - m - 10], outline=INK_L, width=1)
    for i in range(8):
        off = m - 18 + i
        pass

def hatch(dr, x0, y0, x1, y1, step=7, ang=math.radians(45), alpha=None):
    """штриховка области (по bbox, аккуратно)"""
    ln = math.hypot(x1 - x0, y1 - y0) + step * 2
    c = math.cos(ang); s = math.sin(ang)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for t in np.arange(-ln / 2, ln / 2, step):
        # точка на центральной линии
        px = cx + t * s
        py = cy - t * c
        # перпендикуляр
        lx = -py + cx if False else px + (-math.sin(ang)) * 0  # unused
        ax = px - 900 * c; ay = py - 900 * s
        bx = px + 900 * c; by = py + 900 * s
        dr.line([ax, ay, bx, by], fill=INK, width=1)

def silhouette(dr, pts, fill=INK):
    dr.polygon(pts, fill=fill)

def fish(dr, cx, cy, s, flip=1):
    """рыба слева-направо"""
    pts = []
    for t in np.linspace(0, math.pi, 40):
        pts.append((cx + s * math.cos(t) * 1.6 * flip, cy + s * 0.85 * math.sin(t)))
    dr.polygon(pts, fill=INK)
    # хвост
    dr.polygon([(cx - s * 1.6 * flip, cy), (cx - s * 2.5 * flip, cy - s * 0.8), (cx - s * 2.5 * flip, cy + s * 0.8)], fill=INK)
    # глаз
    dr.ellipse([cx + s * 0.7 * flip - s * 0.12, cy - s * 0.25, cx + s * 0.7 * flip + s * 0.12, cy + s * 0.25 * -1 + s * 0.25], outline=INK, width=1)

def lizard(dr, cx, cy, s):
    # туловище
    dr.ellipse([cx - s, cy - s * 0.7, cx + s * 1.6, cy + s * 0.7], fill=INK)
    # голова
    dr.polygon([(cx + s * 1.5, cy), (cx + s * 2.6, cy - s * 0.45), (cx + s * 2.8, cy + s * 0.1), (cx + s * 1.6, cy + s * 0.5)], fill=INK)
    # хвост волной
    pts = []
    for t in np.linspace(0, 1, 30):
        pts.append((cx - s * t * 3.4, cy + math.sin(t * 6) * s * 0.3 * (1 - t)))
    dr.line(pts, fill=INK, width=int(s * 0.42))
    # лапы
    for fx, fy, fa in [(-0.4, -0.6, -0.3), (0.6, -0.6, -0.2), (-0.2, 0.6, 0.3), (0.8, 0.6, 0.2)]:
        dr.line([cx + fx * s, cy + fy * s, cx + fx * s + s * 0.8, cy + fy * s + s * 0.35], fill=INK, width=2)

def dove(dr, cx, cy, s, neck=0.0, head_to="up"):
    """голубь; neck — подъём шеи"""
    # тело
    dr.ellipse([cx - s, cy - s * 0.55, cx + s, cy + s * 0.7], fill=INK)
    dr.polygon([(cx + s * 0.85, cy - s * 0.15), (cx + s * 1.7, cy - s * 0.5), (cx + s * 1.1, cy + s * 0.35)], fill=INK)  # хвост-крыло
    # шея и голова
    hy = cy - s * 0.55 - neck * s
    dr.rectangle([cx - s * 0.14, hy, cx + s * 0.22, cy - s * 0.45], fill=INK)
    dr.ellipse([cx - s * 0.35, hy - s * 0.42, cx + s * 0.35, hy + s * 0.3], fill=INK)
    dr.polygon([(cx + s * 0.3, hy - s * 0.05), (cx + s * 0.75, hy + s * 0.05), (cx + s * 0.3, hy + s * 0.2)], fill=INK)
    dr.point((cx - s * 0.05, hy - s * 0.05), fill=paper(1, 1).getpixel((0, 0)) if False else (235, 218, 172))

def ape(dr, cx, cy, s):
    # сидящая обезьяна
    dr.ellipse([cx - s, cy - s * 1.2, cx + s, cy + s], fill=INK)  # тело+голова
    dr.ellipse([cx - s * 0.62, cy - s * 1.5, cx + s * 0.2, cy - s * 0.8], fill=INK)
    dr.point((cx - s * 0.32, cy - s * 1.18), fill=(240, 226, 186))
    dr.point((cx + s * 0.05, cy - s * 1.18), fill=(240, 226, 186))

def man(dr, cx, cy, s):
    # голова и плечи (бюст)
    dr.ellipse([cx - s * 0.55, cy - s * 1.9, cx + s * 0.55, cy - s * 0.8], fill=INK)
    dr.polygon([(cx - s * 1.4, cy), (cx + s * 1.4, cy), (cx + s * 1.1, cy - s * 0.9), (cx - s * 1.1, cy - s * 0.9)], fill=INK)

def cap(dr, w, h, text, y, size=30, font=F_SERIF_I):
    f = ImageFont.truetype(font, size)
    dr.text((w / 2, y), text, font=f, fill=INK, anchor="mm")

def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p, optimize=True)
    print("print:", name, os.path.getsize(p) // 1024, "KB")

# ================= 1. ЛЕСТНИЦА ПРИРОДЫ =================
def p_scala():
    w, h = 1024, 1400
    img = paper(w, h); dr = ImageDraw.Draw(img)
    add_frame(dr, w, h)
    cap(dr, w, h, "TABULA I — SCALA NATURAE", 120, 46, F_SERIF)
    # диагональная лестница (слева-снизу вправо-вверх), облака внизу
    steps = 7
    x0, y0 = 150, 1180
    dx, dy = (w - 260) / steps, -70
    # перила-линии
    dr.line([x0 - 60, y0 + 90, x0 + dx * steps + 30, y0 + dy * steps + 90], fill=INK_L, width=2)
    silhouettes = [("fish", 0), ("lizard", 1), ("dove", 2), ("dove2", 3), ("ape", 4), ("man", 5)]
    order = {"fish": 0, "lizard": 1, "dove": 2, "dove2": 3, "ape": 4, "man": 5, "void": 6}
    labels = ["PISCIS", "REPTILIS", "AVIS", "AVIS? (sine systemate)", "SIMIA", "HOMO", "———"]
    for i in range(steps):
        x = x0 + dx * i
        y = y0 + dy * i
        dr.line([x, y + 26, x + dx * 0.96, y + 26 + dy * 0.96], fill=INK, width=5)
        step_center_x = x + dx * 0.5
        step_center_y = y + 26 + dy * 0.5 + 10
        # подпись ступени справа
        f = ImageFont.truetype(F_SERIF_I, 26)
        dr.text((x + dx * 0.55 + 8, step_center_y - 40), labels[i], font=f, fill=INK_L, anchor="lm")
    # существа на площадках (левее ступеней)
    for name, i in [("fish", 0), ("lizard", 1), ("dove", 2), ("dove2", 3), ("ape", 4), ("man", 5)]:
        cx = x0 + dx * i + 30
        cy = y0 + dy * i + 46
        if name == "fish":
            fish(dr, cx, cy + 16, 34)
        elif name == "lizard":
            lizard(dr, cx - 40, cy + 26, 26)
        elif name == "dove":
            dove(dr, cx - 10, cy + 20, 34)
        elif name == "dove2":
            dove(dr, cx - 10, cy + 20, 30, neck=3.1)
        elif name == "ape":
            ape(dr, cx - 6, cy + 30, 34)
        elif name == "man":
            man(dr, cx - 10, cy + 34, 40)
    # вершина: сияние
    vx, vy = x0 + dx * 7 + 60, y0 + dy * 7 - 40
    for r, al in [(60, 60), (38, 90), (20, 150)]:
        dr.ellipse([vx - r, vy - r, vx + r, vy + r], outline=(120, 96, 60, al) if False else None)
    for t in range(0, 360, 15):
        a = math.radians(t)
        dr.line([vx + math.cos(a) * 14, vy + math.sin(a) * 14, vx + math.cos(a) * 46, vy + math.sin(a) * 46], fill=INK_L, width=1)
    f = ImageFont.truetype(F_SERIF_I, 30)
    dr.text((vx, vy + 70), "VACAT", font=f, fill=INK, anchor="mm")
    cap(dr, w, h, "«аще кто восхощет — ступай; ступени не спрашивают»", h - 90, 30)
    cap(dr, w, h, "MUSEUM HISTORIAE NATURALIS · 1881", h - 48, 26, F_SERIF)
    save(img, "scala_chain.png")

# ================= 2. SYSTEMA NATURAE =================
def p_systema():
    w, h = 1024, 1400
    img = paper(w, h); dr = ImageDraw.Draw(img)
    add_frame(dr, w, h)
    cap(dr, w, h, "TABULA II — SYSTEMA NATURAE", 120, 44, F_SERIF)
    cap(dr, w, h, "per tria regna, per species immutabiles", 168, 26, F_SERIF_I)
    # дерево-таблица
    root = (w / 2, 260)
    dr.ellipse([root[0] - 26, root[1] - 26, root[0] + 26, root[1] + 26], fill=INK)
    f = ImageFont.truetype(F_SERIF_I, 24)
    dr.text((root[0], root[1] + 60), "DEUS ORDINATOR", font=f, fill=INK, anchor="mm")
    branches = [(-200, 0), (-90, -60), (90, -60), (200, 0)]
    for bx, by in branches:
        nx, ny = root[0] + bx, root[1] + 160 + by
        dr.line([root[0], root[1] + 26, nx, ny - 26], fill=INK, width=2)
    regna = [("REGNUм MINERALE", -200, 0), ("REGNUм VEGETABILE", -90, -60), ("REGNUм ANIMALE", 90, -60), ("HOMO? (in regno suo)", 200, 0)]
    for name, bx, by in regna:
        nx, ny = root[0] + bx, root[1] + 160 + by
        dr.ellipse([nx - 20, ny - 20, nx + 20, ny + 20], outline=INK, width=2)
        dr.text((nx, ny + 40), name, font=f, fill=INK, anchor="mm")
    # справа: вертикальный список классов с линиями
    x = w - 210
    classes = ["I. MAMMALIA", "II. AVES", "III. AMPHIBIA", "IV. PISCES", "V. INSECTA", "VI. VERMES"]
    for i, c in enumerate(classes):
        y = 620 + i * 90
        dr.line([x - 30, y, x + 110, y], fill=INK_L, width=1)
        dr.text((x, y - 26), c, font=f, fill=INK, anchor="lm")
    # слева: «виды вечны» + печать
    dr.ellipse([150, 620, 400, 870], outline=INK, width=3)
    dr.ellipse([170, 640, 380, 850], outline=INK_L, width=1)
    f2 = ImageFont.truetype(F_SERIF_B, 26)
    dr.text((275, 700), "SPECIES", font=f2, fill=INK, anchor="mm")
    dr.text((275, 740), "ÆTERNÆ", font=f2, fill=INK, anchor="mm")
    f3 = ImageFont.truetype(F_SERIF_I, 22)
    dr.text((275, 800), "nulla species nova", font=f3, fill=INK, anchor="mm")
    dr.text((275, 830), "(C. Linnaeus, 1758)", font=f3, fill=INK, anchor="mm")
    # низ: дрожащая рукописная приписка
    f4 = ImageFont.truetype(F_SERIF_I, 30)
    dr.text((w / 2, 1200), "— а если вид солжёт? —", font=f4, fill=(120, 60, 40), anchor="mm")
    save(img, "systema.png")

# ================= 3. COLUMBA GIRAFFA =================
def p_columba():
    w, h = 1024, 1400
    img = paper(w, h); dr = ImageDraw.Draw(img)
    add_frame(dr, w, h)
    cap(dr, w, h, "TABULA III — COLUMBA GIRAFFA (inventum)", 120, 42, F_SERIF)
    # голубь с гигантской шеей уходящей вверх
    cx, cy = w / 2 + 40, 980
    dove(dr, cx, cy, 60, neck=1.2)
    # шея уходит за край: дуга
    pts = []
    for t in np.linspace(0, 1, 60):
        yy = cy - 60 - t * 900
        xx = cx + 20 + math.sin(t * 2.2) * 130 * t
        pts.append((xx, yy))
    dr.line(pts, fill=INK, width=26)
    dr.line(pts, fill=INK, width=26)
    # перья-штрихи
    for t in np.linspace(0.05, 0.95, 22):
        xx = cx + 20 + math.sin(t * 2.2) * 130 * t
        yy = cy - 60 - t * 900
        dr.line([xx - 26, yy, xx + 26, yy], fill=INK, width=2)
    # голова наверху листа
    hx = cx + 20 + math.sin(2.2) * 130
    hy = cy - 60 - 900
    dr.ellipse([hx - 45, hy - 60, hx + 45, hy + 40], fill=INK)
    dr.polygon([(hx + 40, hy - 10), (hx + 110, hy + 6), (hx + 40, hy + 24)], fill=INK)
    # пунктир-вопрос сверху
    for t in range(0, 700, 60):
        dr.line([w / 2 - 40 + t * 0.2, 130 + (t % 120) * 0.1, w / 2 - 30 + t * 0.2, 138 + (t % 120) * 0.1], fill=INK_L, width=2)
    f = ImageFont.truetype(F_SERIF_I, 40)
    dr.text((w / 2, 700), "quo usque tandem?", font=f, fill=INK, anchor="mm")
    f2 = ImageFont.truetype(F_SERIF_I, 26)
    dr.text((w / 2, h - 150), "ex herbario custodis · species non in Systemate", font=f2, fill=INK_L, anchor="mm")
    dr.text((w / 2, h - 110), "«рисовано с натуры. натура молчала»", font=f2, fill=(120, 60, 40), anchor="mm")
    save(img, "columba.png")

# ================= 4. ОКО (символ музея) =================
def p_eye():
    w, h = 1024, 1400
    img = paper(w, h); dr = ImageDraw.Draw(img)
    add_frame(dr, w, h)
    cx, cy = w / 2, h / 2 + 40
    # лучи-орнамент
    for t in range(0, 360, 6):
        a = math.radians(t)
        r0, r1 = 330, 370 + (t % 12) * 3
        dr.line([cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1], fill=INK_L, width=1)
    # глаз: веки
    dr.arc([cx - 300, cy - 220, cx + 300, cy + 220], 190, 350, fill=INK, width=8)
    dr.arc([cx - 300, cy - 220, cx + 300, cy + 220], 10, 170, fill=INK, width=8)
    # радужка с лестницей
    dr.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], fill=(150, 130, 100))
    dr.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], outline=INK, width=5)
    for i in range(12):
        a = math.radians(i * 30)
        dr.line([cx + math.cos(a) * 40, cy + math.sin(a) * 40, cx + math.cos(a) * 145, cy + math.sin(a) * 145], fill=(120, 100, 75), width=3)
    # зрачок + лестница-отражение
    dr.ellipse([cx - 60, cy - 60, cx + 60, cy + 60], fill=INK)
    for i in range(5):
        yy = cy - 40 + i * 20
        wdt = 16 + i * 6
        dr.line([cx - wdt, yy, cx + wdt, yy], fill=(215, 190, 140), width=2)
    dr.point((cx, cy - 46), fill=(240, 225, 190))
    f = ImageFont.truetype(F_SERIF_I, 30)
    dr.text((cx, cy + 300), "oculus naturae nunquam dormit", font=f, fill=INK, anchor="mm")
    dr.text((cx, cy + 345), "«он видит тебя и тогда, когда ты не смотришь»", font=f, fill=(120, 60, 40), anchor="mm")
    save(img, "oculus.png")

# ================= 5. LILIUM MUTABILIS =================
def p_lilium():
    w, h = 1024, 1400
    img = paper(w, h); dr = ImageDraw.Draw(img)
    add_frame(dr, w, h)
    cap(dr, w, h, "TABULA IV — LILIUM MUTABILIS", 120, 42, F_SERIF)
    cap(dr, w, h, "eadem planta, tres aetates, tres formae", 166, 26, F_SERIF_I)
    # три лилии разного размера
    f = ImageFont.truetype(F_SERIF_I, 26)
    for i, (x, s) in enumerate([(250, 80), (512, 140), (774, 220)]):
        by = h - 320
        # стебель
        dr.line([x, by, x, by - 300 * s / 140], fill=INK, width=4)
        # лист
        dr.polygon([(x, by - 160 * s / 140), (x - 70 * s / 140, by - 200 * s / 140), (x, by - 220 * s / 140)], fill=INK)
        # цветок: лепестки
        fy = by - 300 * s / 140 - 60
        for k in range(6):
            a = math.radians(k * 60)
            x2 = x + math.cos(a) * s * 0.62
            y2 = fy + math.sin(a) * s * 0.62
            dr.ellipse([x2 - s * 0.24, y2 - s * 0.24, x2 + s * 0.24, y2 + s * 0.24], fill=(150, 130, 100), outline=INK, width=2)
        dr.ellipse([x - s * 0.1, fy - s * 0.1, x + s * 0.1, fy + s * 0.1], fill=INK)
        dr.text((x, by + 60), "a" if i == 0 else ("b" if i == 1 else "c"), font=f, fill=INK, anchor="mm")
    # стрелки превращений
    for x1, x2, lab in [(300, 430, "nutrit"), (560, 690, "nutrit?")]:
        dr.line([x1 + 40, h - 220, x2 - 40, h - 220], fill=INK_L, width=2)
        dr.polygon([(x2 - 30, h - 220), (x2 - 55, h - 230), (x2 - 55, h - 210)], fill=INK_L)
        dr.text(((x1 + x2) / 2, h - 250), lab, font=f, fill=INK_L, anchor="mm")
    dr.text((w / 2, h - 90), "«форма не дана. форма — ответ почвы»", font=f, fill=(120, 60, 40), anchor="mm")
    save(img, "lilium.png")

# ================= 6. ПУСТАЯ РАМА (зал человека) =================
def p_vacua():
    w, h = 1024, 1400
    img = paper(w, h); dr = ImageDraw.Draw(img)
    add_frame(dr, w, h)
    cap(dr, w, h, "TABULA V — HOMO SAPIENS", 120, 42, F_SERIF)
    # большая орнаментальная рама с пустотой
    m = 130
    dr.rectangle([m, m, w - m, h - m], outline=INK, width=6)
    for i in range(4):
        dr.rectangle([m + 14 + i * 5, m + 14 + i * 5, w - m - 14 - i * 5, h - m - 14 - i * 5], outline=(110, 88, 60), width=1)
    # угловые завитки
    for cx0, cy0 in [(m, m), (w - m, m), (m, h - m), (w - m, h - m)]:
        for t in range(0, 360, 10):
            a = math.radians(t)
            r = 30 + t / 360 * 60
            dr.point((cx0 + math.cos(a) * r * (1 if cx0 < w / 2 else -1), cy0 + math.sin(a) * r * (1 if cy0 < h / 2 else -1)), fill=INK)
    f = ImageFont.truetype(F_SERIF_I, 40)
    dr.text((w / 2, h / 2 - 60), "exspectatur", font=f, fill=INK_L, anchor="mm")
    f2 = ImageFont.truetype(F_SERIF_I, 26)
    dr.text((w / 2, h / 2 + 20), "specimen perfectum, immutabile", font=f2, fill=INK_L, anchor="mm")
    dr.text((w / 2, h - 90), "«место готово. уже очень давно готово»", font=f2, fill=(120, 60, 40), anchor="mm")
    save(img, "vacua.png")

# ================= 7. ЗАГОЛОВОК МЕНЮ =================
def p_title():
    w, h = 1600, 620
    img = paper(w, h); dr = ImageDraw.Draw(img)
    f = ImageFont.truetype(F_SERIF_B, 150)
    dr.text((w / 2 - 20, h / 2 - 40), "SCALA", font=f, fill=INK, anchor="mm")
    dr.text((w / 2 + 300, h / 2 + 30), "NATURAE", font=f, fill=INK, anchor="mm")
    # лестница-силуэт слева
    for i in range(8):
        x0 = 150 + i * 30
        y0 = 480 - i * 40
        dr.line([x0, y0, x0 + 60, y0 - 24], fill=INK, width=5)
    dr.line([150, 500, 150 + 7 * 30 + 60, 500 - 7 * 40 - 24], fill=INK_L, width=2)
    f2 = ImageFont.truetype(F_SERIF_I, 40)
    dr.text((w / 2, h - 40), "музей естественной истории · ночная смена", font=f2, fill=INK_L, anchor="mm")
    save(img, "title.png")

if __name__ == "__main__":
    print("Generating prints into", OUT)
    p_scala(); p_systema(); p_columba(); p_eye(); p_lilium(); p_vacua(); p_title()
    print("ALL PRINTS DONE")
