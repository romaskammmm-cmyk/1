#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
НЕДОСТАЮЩЕЕ ЗВЕНО — генератор текстур [art-04]
Процедурные текстуры главы 1. Запуск: python3 texture_gen.py
Выход: ../assets/textures/*.png
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "textures"))
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(OUT, "labels"), exist_ok=True)

FONT_DIR = "/usr/share/fonts/truetype/dejavu"
F_REG = os.path.join(FONT_DIR, "DejaVuSans.ttf")
F_BOLD = os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf")
F_MONO = os.path.join(FONT_DIR, "DejaVuSansMono.ttf")

random.seed(1971)
np.random.seed(1971)

def fbm(w, h, octaves=5, seed=None, aniso=(1.0, 1.0)):
    """Фрактальный шум через PIL-resize октав."""
    rng = np.random.RandomState(seed if seed is not None else random.randint(0, 1 << 30))
    acc = np.zeros((h, w), dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        ow = max(2, int((w / (2 ** o)) * aniso[0]))
        oh = max(2, int((h / (2 ** o)) * aniso[1]))
        n = rng.rand(oh, ow).astype(np.float32)
        img = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        acc += np.asarray(img, dtype=np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.55
    return acc / tot

def to_img(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))

def save(img, name):
    img.save(os.path.join(OUT, name))
    print("  +", name)

# ---------------------------------------------------------------- паркет
def gen_parquet():
    W = H = 1024
    n = fbm(W, H, 6, seed=11, aniso=(0.06, 1.0))          # волокна (вытянуты по X)
    base = np.zeros((H, W, 3), dtype=np.float32)
    c_light = np.array([0.36, 0.24, 0.13]); c_dark = np.array([0.16, 0.09, 0.045])
    for y in range(H):
        v = (np.sin((n[y]) * 26.0) * 0.5 + 0.5) ** 1.4
        base[y] = c_dark[None, :] + (c_light - c_dark)[None, :] * ((1.0 - v * 0.8)[:, None])
    grime = fbm(W, H, 4, seed=12) * 0.25
    base *= (1.0 - grime)[:, :, None]
    img = to_img(base)
    d = ImageDraw.Draw(img)
    plank = H // 4
    for i in range(4):                                       # швы досок
        y = i * plank
        d.line([(0, y), (W, y)], fill=(12, 7, 3), width=3)
        d.line([(0, y + 1), (W, y + 1)], fill=(60, 40, 20), width=1)
    for i in range(4):                                       # торцевые стыки вразбежку
        x = (i * 397 + 211) % W
        d.line([(x, i * plank), (x, (i + 1) * plank)], fill=(12, 7, 3), width=2)
    save(img, "parquet.png")

# ------------------------------------------------- двухтонная стена (СССР)
def gen_wall_twotone():
    W, H = 1024, 1024
    plaster = fbm(W, H, 6, seed=21)
    img_arr = np.zeros((H, W, 3), dtype=np.float32)
    top = np.array([0.55, 0.51, 0.43]); green = np.array([0.13, 0.20, 0.15])
    for y in range(H):
        t = y / H
        col = top if t < 0.58 else green
        img_arr[y] = col
    img_arr *= (0.82 + plaster * 0.36)[:, :, None]
    img = to_img(img_arr)
    d = ImageDraw.Draw(img)
    yl = int(H * 0.58)
    d.line([(0, yl), (W, yl)], fill=(18, 22, 16), width=6)          # отбитая линия
    d.line([(0, yl + 7), (W, yl + 7)], fill=(120, 128, 110), width=2)
    d.line([(0, H - 12), (W, H - 12)], fill=(8, 8, 6), width=12)    # плинтус
    d.rectangle([0, H - 12, W, H - 10], fill=(70, 66, 52))
    for _ in range(26):                                             # потёки/сколы
        x, y = random.randint(0, W), random.randint(yl + 20, H - 30)
        r = random.randint(6, 30)
        d.ellipse([x, y, x + r, y + int(r * 1.8)], fill=(10, 12, 9))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    save(img, "wall_twotone.png")

# ---------------------------------------------------------------- мрамор
def gen_marble():
    W = H = 1024
    warp = fbm(W, H, 5, seed=31) - 0.5
    x = np.arange(W)[None, :].repeat(H, 0) / W * 24.0 + warp * 14.0
    v = np.abs(np.sin(x * math.pi))
    veins = (v ** 6.0)
    grain = fbm(W, H, 6, seed=32) * 0.12
    base = np.array([0.62, 0.60, 0.56])
    dark = np.array([0.10, 0.11, 0.12])
    arr = base[None, None, :] * (1 - veins[:, :, None]) + dark[None, None, :] * veins[:, :, None]
    arr *= (1 - grain)[:, :, None]
    save(to_img(arr), "marble.png")

# ---------------------------------------------------------------- велюр
def gen_velvet():
    W = H = 512
    n = fbm(W, H, 5, seed=41, aniso=(0.4, 1.0))
    arr = np.array([0.22, 0.03, 0.04])[None, None, :] * (0.5 + n[:, :, None] * 1.3)
    save(to_img(arr), "velvet.png")

# ------------------------------------------------------------- жирафа
def gen_giraffe_skin():
    W = H = 512
    n = fbm(W, H, 5, seed=51)
    patch = n > 0.62
    edge = (np.abs(n - 0.62) < 0.02)
    pale = np.array([0.66, 0.60, 0.44]); brown = np.array([0.23, 0.15, 0.07])
    arr = np.where(patch[:, :, None], brown[None, None, :], pale[None, None, :])
    arr = np.where(edge[:, :, None], np.array([0.08, 0.05, 0.02])[None, None, :], arr)
    sick = fbm(W, H, 4, seed=52) * 0.15
    arr *= (1 - sick)[:, :, None]
    save(to_img(arr), "giraffe_skin.png")

# ------------------------------------------------------------- чучело/мех
def gen_fur():
    W = H = 512
    n = fbm(W, H, 6, seed=61, aniso=(0.05, 1.0))
    arr = np.array([0.13, 0.09, 0.05])[None, None, :] * (0.4 + n[:, :, None] * 1.5)
    save(to_img(arr), "fur_dark.png")

def gen_bone():
    W = H = 256
    n = fbm(W, H, 5, seed=71)
    arr = np.array([0.82, 0.78, 0.66])[None, None, :] * (0.75 + n[:, :, None] * 0.4)
    save(to_img(arr), "bone.png")

# ------------------------------------------------------------- бумага
def gen_paper():
    W, H = 512, 640
    n = fbm(W, H, 6, seed=81)
    arr = np.array([0.80, 0.74, 0.60])[None, None, :] * (0.78 + n[:, :, None] * 0.35)
    img = to_img(arr)
    d = ImageDraw.Draw(img)
    for _ in range(14):  # пятна возраста
        x, y = random.randint(0, W), random.randint(0, H)
        r = random.randint(8, 46)
        d.ellipse([x, y, x + r, y + r], fill=(150, 128, 88))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    save(img, "paper.png")

# ------------------------------------------------------------- виньетка
def gen_vignette():
    S = 512
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    r = np.sqrt(((xx - S / 2) / (S / 2)) ** 2 + ((yy - S / 2) / (S / 2)) ** 2)
    a = np.clip((r - 0.55) / 0.65, 0, 1) ** 1.6 * 255
    img = Image.fromarray(np.dstack([np.zeros((S, S), np.uint8)] * 3 + [a.astype(np.uint8)]), "RGBA")
    save(img, "vignette.png")

# ------------------------------------------------------------- прочее
def gen_linoleum():
    W = H = 512
    n = fbm(W, H, 6, seed=91)
    cell = 64
    arr = np.zeros((H, W, 3), dtype=np.float32)
    c1 = np.array([0.16, 0.22, 0.17]); c2 = np.array([0.13, 0.17, 0.13])
    for y in range(H):
        for_step = ((y // cell) % 2)
        row = np.where((((np.arange(W) // cell) % 2) == for_step), 1, 0)
        arr[y] = c1 * row[:, None] + c2 * (1 - row)[:, None]
    arr *= (0.8 + n[:, :, None] * 0.4)
    save(to_img(arr), "linoleum.png")

def gen_ceiling():
    W = H = 512
    n = fbm(W, H, 5, seed=101)
    arr = np.array([0.16, 0.15, 0.13])[None, None, :] * (0.6 + n[:, :, None] * 0.6)
    img = to_img(arr)
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (W, 0)], fill=(4, 4, 4), width=4)
    d.line([(0, 0), (0, H)], fill=(4, 4, 4), width=4)
    d.rectangle([W // 2 - 40, H // 2 - 20, W // 2 + 40, H // 2 + 20], outline=(6, 6, 6), width=3)  # вентрешётка
    save(img, "ceiling.png")

def gen_concrete():
    W = H = 512
    n = fbm(W, H, 6, seed=111)
    arr = np.array([0.24, 0.23, 0.21])[None, None, :] * (0.55 + n[:, :, None] * 0.8)
    img = to_img(arr)
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x, y = random.randint(0, W), random.randint(0, H)
        d.point((x, y), fill=(10, 10, 10))
    save(img, "concrete.png")

def gen_door_wood():
    W, H = 512, 512
    n = fbm(W, H, 6, seed=121, aniso=(1.0, 0.05))
    base = np.zeros((H, W, 3), dtype=np.float32)
    c1 = np.array([0.24, 0.15, 0.07]); c2 = np.array([0.10, 0.055, 0.03])
    v = (np.sin(n * 30.0) * 0.5 + 0.5) ** 1.2
    base = c2[None, None, :] + (c1 - c2)[None, None, :] * (1 - v[:, :, None])
    img = to_img(base)
    d = ImageDraw.Draw(img)
    for (x0, y0, x1, y1) in [(64, 48, 448, 236), (64, 300, 448, 464)]:  # филёнки
        d.rectangle([x0, y0, x1, y1], outline=(20, 12, 6), width=5)
        d.rectangle([x0 + 12, y0 + 12, x1 - 12, y1 - 12], outline=(46, 28, 14), width=2)
    save(img, "door_wood.png")

# ------------------------------------------------------------- этикетки
LABELS = [
    ("label_giraffe", "Giraffa camelopardalis streletskii", "Жирафа стрелецкая", "007"),
    ("label_wolf", "Canis lupus fidelis", "Волк преданный", "034"),
    ("label_owl", "Bubo stirps", "Филин родовой", "061"),
    ("label_fish", "Lucifuga desirans", "Слепорыл желающий", "088"),
    ("label_mole", "Talpa archivaria", "Крот архивный", "112"),
    ("label_diver", "Homo batialis", "Человек глубинный", "141"),
    ("label_zero", "Homo custos", "Человек хранитель", "000"),
    ("label_missing", "Anthropoides indefinitus", "Антропоид неопределённый", "???"),
]

def gen_labels():
    W, H = 512, 320
    for key, latin, ru, num in LABELS:
        img = Image.new("RGB", (W, H), (196, 188, 160))
        d = ImageDraw.Draw(img)
        d.rectangle([6, 6, W - 7, H - 7], outline=(40, 36, 26), width=3)
        d.rectangle([14, 14, W - 15, H - 15], outline=(90, 82, 60), width=1)
        f_small = ImageFont.truetype(F_REG, 17)
        f_latin = ImageFont.truetype(F_BOLD, 26)
        f_ru = ImageFont.truetype(F_REG, 22)
        f_num = ImageFont.truetype(F_MONO, 30)
        d.text((W // 2, 42), "ИЭТ · ЭКСП. ТАКСОНОМИЯ · СТРЕЛЕЦК-14", font=f_small, fill=(60, 55, 40), anchor="mm")
        d.text((W // 2, 108), latin, font=f_latin, fill=(24, 22, 16), anchor="mm")
        d.text((W // 2, 152), ru, font=f_ru, fill=(70, 64, 48), anchor="mm")
        d.line([(60, 190), (W - 60, 190)], fill=(120, 110, 84), width=2)
        d.text((W // 2, 232), "ОБРАЗЕЦ № " + num, font=f_num, fill=(30, 28, 20), anchor="mm")
        if num == "000":
            d.text((W // 2, 276), "ПОЛЕВОЙ МАТЕРИАЛ НЕ ПОСТУПАЛ", font=f_small, fill=(120, 30, 24), anchor="mm")
        elif num == "???":
            d.text((W // 2, 276), "ВИД НЕ ОПРЕДЕЛЁН. ЖДЁТ.", font=f_small, fill=(120, 30, 24), anchor="mm")
        else:
            d.text((W // 2, 276), "ЭКСПОНАЦИЯ ПОСТОЯННАЯ", font=f_small, fill=(100, 94, 76), anchor="mm")
        # старение
        age = fbm(W, H, 4, seed=hash(key) % 9999)
        img = Image.fromarray((np.asarray(img, np.float32) * (0.86 + age[:, :, None] * 0.2)).astype(np.uint8))
        img = img.filter(ImageFilter.GaussianBlur(0.4))
        save(img, os.path.join("labels", key + ".png"))

if __name__ == "__main__":
    print("[art-04] Генерация текстур →", OUT)
    gen_parquet(); gen_wall_twotone(); gen_marble(); gen_velvet(); gen_giraffe_skin()
    gen_fur(); gen_bone(); gen_paper(); gen_vignette(); gen_linoleum()
    gen_ceiling(); gen_concrete(); gen_door_wood(); gen_labels()
    print("[art-04] Готово.")
