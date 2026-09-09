#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SCALA NATURAE — procedural texture generator (worker-4 / env programmer)
Generates ALL game textures with numpy+PIL: albedo + normal maps (+alpha).
Deterministic (fixed seeds). Output: ../game/assets/textures/
Normals are written with sRGB gamma encoding so Godot's default sRGB import
decodes them back to linear automatically. Albedo: sRGB as-is.
"""
import numpy as np, os, math
from PIL import Image, ImageDraw

SEED = 1903
rng = np.random.default_rng(SEED)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "textures")
os.makedirs(OUT, exist_ok=True)

# ---------------- helpers ----------------
def save(name, arr, mode="RGB"):
    """arr float32 0..1 or uint8; mode RGB/RGBA/L"""
    a = arr if arr.dtype == np.uint8 else np.clip(arr, 0, 1)
    if arr.dtype != np.uint8:
        a = (a * 255).astype(np.uint8)
    if mode == "L" and a.ndim == 3:
        a = a[..., 0]
    Image.fromarray(a, mode).save(os.path.join(OUT, name), optimize=True)
    print("  tex:", name, a.shape, os.path.getsize(os.path.join(OUT, name)) // 1024, "KB")

def sfield(w, h, octaves=5, scale=3.0, seed=None):
    """tileable pseudo-noise field: sum of integer-freq sinusoids (fast)."""
    g = np.random.default_rng(seed if seed is not None else int(rng.integers(1e9)))
    yy, xx = np.mgrid[0:h, 0:w]
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(octaves):
        f = scale * (o + 1) * 2 * np.pi
        for _ in range(3):
            a, b = g.uniform(-1, 1, 2)
            ph = g.uniform(0, 2 * np.pi)
            ph2 = g.uniform(0, 2 * np.pi)
            # integer cycles on BOTH axes for seamless tiling
            fx, fy = int(g.integers(1, max(2, f // (2*np.pi) * w / (2*np.pi)) + 1)) or 1, int(g.integers(1, max(2, f / (2*np.pi) * h / (2*np.pi)) + 1)) or 1
            out += amp * np.sin(fx * xx * 2 * np.pi / w * scale + ph) * np.cos(fy * yy * 2 * np.pi / h * scale + ph2) * 0.333
        amp *= 0.5
    out -= out.min(); out /= (out.max() + 1e-9)
    return out

def tileable_noise(w, h, cells, seed=None):
    """value noise, tileable via wrapped lattice."""
    g = np.random.default_rng(seed if seed is not None else int(rng.integers(1e9)))
    lat = g.random((cells + 1, cells + 1), np.float32)
    lat[cells] = lat[0]  # wrap rows/cols
    lat[:, cells] = lat[:, 0]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fx = xx / w * cells; fy = yy / h * cells
    x0 = fx.astype(np.int64); y0 = fy.astype(np.int64)
    tx = fx - x0; ty = fy - y0
    tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)  # smoothstep
    def L(i, j):
        i = i % cells; j = j % cells
        return lat[i, j]
    v = (L(x0, y0) * (1 - tx) + L(x0 + 1, y0) * tx) * (1 - ty) + \
        (L(x0, y0 + 1) * (1 - tx) + L(x0 + 1, y0 + 1) * tx) * ty
    return v.astype(np.float32)

def fbm(w, h, cells=8, oct=5, seed=None):
    g = np.random.default_rng(seed if seed is not None else int(rng.integers(1e9)))
    out = np.zeros((h, w), np.float32)
    a, f = 1.0, 1
    for _ in range(oct):
        out += a * tileable_noise(w, h, int(cells * f), seed=int(g.integers(1e9)))
        a *= 0.5; f *= 2
    out -= out.min(); out /= (out.max() + 1e-9)
    return out

def normal_from_height(h, strength=3.0):
    """h float 0..1 -> normal map (linear), returns [0..1] float."""
    gy, gx = np.gradient(h.astype(np.float32))
    nx = -gx * strength; ny = -gy * strength
    n = np.stack([nx, ny, np.ones_like(h, np.float32)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
    n = n * 0.5 + 0.5
    n = np.power(np.clip(n, 0, 1), 1 / 2.2)  # sRGB-encode for Godot import
    return n

def write_tex(base, albedo, normal=None, mode="RGB"):
    save(base + ".png", albedo, mode)
    if normal is not None:
        save(base + "_n.png", normal, "RGB")

def draw_lines_pil(arr_rgb, n_lines, seed, color=(0, 0, 0), alpha=90, wmin=1, wmax=2, lmin=8, lmax=60, cover=0.02):
    """fine random scratches/stains via PIL"""
    img = Image.fromarray((np.clip(arr_rgb, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    dr = ImageDraw.Draw(img)
    g = np.random.default_rng(seed)
    h, w = arr_rgb.shape[:2]
    for _ in range(n_lines):
        x, y = g.uniform(0, w), g.uniform(0, h)
        ang = g.uniform(0, math.pi)
        ln = g.uniform(lmin, lmax)
        c = tuple(int(v) for v in color)
        dr.line([x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln], fill=c + (int(g.uniform(alpha * 0.3, alpha)),), width=int(g.uniform(wmin, wmax)))
    out = np.asarray(img).astype(np.float32) / 255.0
    return out[..., :3]

# ---------------- 1. PARQUET (herringbone, dark oak) ----------------
def gen_parquet():
    w = h = 1024
    n = 8  # 8x8 planks
    base = fbm(w, h, cells=3, oct=3, seed=11)
    plank_w = w // n
    rows = cols = n
    alb = np.zeros((h, w, 3), np.float32)
    g = np.random.default_rng(42)
    tone = g.uniform(0.75, 1.0, (rows, cols)).astype(np.float32)
    for r in range(rows):
        for c in range(cols):
            off = (plank_w // 2) if (r % 2 == 1) else 0
            for rr in range(plank_w):
                for cc in range(plank_w):
                    px = (c * plank_w + cc + off) % w
                    py = r * plank_w + rr
                    # grain bands along plank
                    t = ((cc + rr) * 0.13 + base[py, px] * 1.5) % 1.0
                    wood = 0.22 + 0.16 * np.sin(t * math.pi) ** 1.5 + base[py, px] * 0.05
                    shade = tone[r, c]
                    alb[py, px] = (wood * shade * 1.15, wood * shade * 0.62, wood * shade * 0.34)
    alb = np.clip(alb * (0.82 + 0.25 * base[..., None]), 0, 1)
    # joints (dark lines)
    for i in range(1, cols):
        alb[:, (i * plank_w - 2):(i * plank_w + 2)] *= 0.25
    for i in range(1, rows):
        alb[(i * plank_w - 2):(i * plank_w + 2), :] *= 0.25
    # fine grain scratches
    lum = alb.mean(-1)
    alb2 = draw_lines_pil(alb, 260, 7, color=(10, 5, 2), alpha=60, wmin=1, wmax=1, lmin=14, lmax=70)
    write_tex("parquet_dark", alb2, normal_from_height(lum * 0.25 + base * 0.4, 2.2))

# ---------------- 2. MARBLE (white/grey veined) ----------------
def gen_marble():
    w = h = 1024
    n1 = sfield(w, h, octaves=6, scale=2.4, seed=3)
    veins = np.abs(np.sin(n1 * 10 + sfield(w, h, 4, 5, seed=4) * 6)) ** 1.6
    base = fbm(w, h, 6, 4, seed=5)
    alb = np.zeros((h, w, 3), np.float32)
    alb[..., 0] = 0.86 - veins * 0.55 + base * 0.06
    alb[..., 1] = 0.85 - veins * 0.55 + base * 0.06
    alb[..., 2] = 0.82 - veins * 0.58 + base * 0.05
    alb = draw_lines_pil(alb, 30, 9, color=(60, 55, 50), alpha=50, wmin=1, wmax=2, lmin=30, lmax=140)
    lum = (0.3 * veins + 0.1 * base)
    write_tex("marble_white", alb, normal_from_height(lum * 0.5 + veins * 1.2, 1.6))

# ---------------- 3. BRASS ----------------
def gen_brass():
    w = h = 512
    base = fbm(w, h, 5, 4, seed=21)
    alb = np.zeros((h, w, 3), np.float32)
    alb[..., 0] = 0.72 + base * 0.05
    alb[..., 1] = 0.60 + base * 0.05
    alb[..., 2] = 0.28 + base * 0.05
    # patina stains
    stains = fbm(w, h, 6, 4, seed=22)
    mask = (stains > 0.75).astype(np.float32) * ((stains - 0.75) / 0.25)
    alb[..., 0] = alb[..., 0] * (1 - mask * 0.8) + mask * 0.16
    alb[..., 1] = alb[..., 1] * (1 - mask * 0.7) + mask * 0.30
    alb[..., 2] = alb[..., 2] * (1 - mask * 0.6) + mask * 0.22
    alb = draw_lines_pil(alb, 120, 23, color=(0, 0, 0), alpha=40, wmin=1, wmax=1)
    hgt = base * 0.35
    write_tex("brass", alb, normal_from_height(hgt, 2.0))

# ---------------- 4. VELVET (deep red, folds) ----------------
def gen_velvet():
    w = h = 512
    folds = np.zeros((h, w), np.float32)
    for f in (1.0, 2.0, 3.7):
        ph = rng.uniform(0, math.pi * 2)
        folds += np.sin(np.arange(w)[None, :] / w * math.pi * 2 * f + ph)[..., None].repeat(h, 0)[..., 0] if False else np.sin(
            np.broadcast_to(np.arange(w)[None, :], (h, w)) / w * math.pi * 2 * f + ph) / f
    folds = folds / 3 + 0.5
    no = fbm(w, h, 8, 4, seed=31)
    lum = 0.30 + 0.16 * folds + 0.05 * no
    alb = np.stack([lum * 1.5, lum * 0.16, lum * 0.14], -1)
    alb = np.clip(alb, 0, 1)
    write_tex("velvet_red", alb, normal_from_height(folds * 0.8 + no * 0.2, 3.0))

# ---------------- 5. PLASTER (aged walls) ----------------
def gen_plaster():
    w = h = 1024
    base = fbm(w, h, 10, 5, seed=41)
    alb = np.ones((h, w, 3), np.float32) * 0.72
    alb *= (0.94 + 0.06 * base)[..., None]
    # damp patches
    damp = fbm(w, h, 4, 4, seed=42)
    m = np.clip((damp - 0.62) / 0.38, 0, 1) ** 1.4
    alb[..., 0] *= (1 - m * 0.45); alb[..., 1] *= (1 - m * 0.30); alb[..., 2] *= (1 - m * 0.22)
    # cracks
    alb2 = draw_lines_pil(alb, 90, 43, color=(38, 36, 32), alpha=160, wmin=1, wmax=3, lmin=40, lmax=220)
    alb2 = draw_lines_pil(alb2, 400, 44, color=(45, 42, 38), alpha=50, wmin=1, wmax=1, lmin=10, lmax=50)
    write_tex("plaster", alb2, normal_from_height(base * 0.5 + damp * 0.6 + m * 0.5, 1.2))

# ---------------- 6. WALLPAPER (dark green, rosettes) ----------------
def gen_wallpaper():
    w = h = 1024
    base = fbm(w, h, 6, 4, seed=51)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cy, cx = h / 2, w / 2
    pat = np.zeros((h, w), np.float32)
    for oy in np.arange(0, h, 128):
        for ox in np.arange(0, w, 128):
            d = np.sqrt((yy - (oy % h + 64)) ** 2 + (xx - (ox % w + 64)) ** 2)
            pat += np.clip(np.sin(d / 128 * math.pi * 4) * (d < 56), 0, 1) * np.clip(np.sin(d / 9), 0, 1)
    # petal rosettes via petals
    pat = np.clip(pat / 8, 0, 1)
    no = fbm(w, h, 8, 3, seed=52)
    g = 0.16 + 0.05 * no + 0.10 * pat
    alb = np.stack([g * 1.2, g, g * 0.9], -1)
    alb = np.clip(alb * 1.1, 0, 1)
    alb[..., 2] += pat * 0.10
    write_tex("wallpaper_green", alb, normal_from_height(pat * 0.9 + no * 0.2, 2.0))

# ---------------- 7. GLASS grime (RGBA streaks) ----------------
def gen_glass():
    w = h = 512
    a = np.zeros((h, w, 4), np.float32)
    a[..., 3] = 1.0
    grime = fbm(w, h, 5, 3, seed=61)
    streaks = np.zeros((h, w), np.float32)
    g = np.random.default_rng(62)
    for _ in range(140):
        x0 = g.uniform(0, w); y0 = g.uniform(0, h * 0.3); ln = g.uniform(80, 420); wd = g.uniform(1, 7)
        ang = math.pi / 2 + g.uniform(-0.18, 0.18)
        for t in range(0, int(ln), 2):
            x = int(x0 + math.cos(ang) * t) % w; y = int(y0 + math.sin(ang) * t) % h
            if y >= h: break
            r = int(wd)
            for dx in range(-r, r + 1):
                if 0 <= y < h and 0 <= (x + dx) % w < w:
                    streaks[y, (x + dx) % w] = max(streaks[y, (x + dx) % w], (1 - abs(dx) / (r + 1)) * g.uniform(0.5, 1))
    alpha = 1 - np.clip(grime * 0.25 + streaks * 0.5, 0, 0.8)
    a[..., 3] = alpha
    a[..., 0] = 0.75; a[..., 1] = 0.85; a[..., 2] = 0.8
    save("glass_grime.png", a, "RGBA")

# ---------------- 8. PAPER (aged) ----------------
def gen_paper():
    w, h = 768, 1024
    base = fbm(w, h, 6, 5, seed=71)
    stains = fbm(w, h, 3, 3, seed=72)
    m = np.clip((stains - 0.6) / 0.4, 0, 1) ** 1.6
    m2 = np.clip((stains - 0.8) / 0.2, 0, 1) ** 1.2
    p = 0.86 + 0.05 * base
    alb = np.stack([p * 0.96, p * 0.92, p * 0.72], -1)
    alb[..., 0] -= m * 0.25; alb[..., 1] -= m * 0.22; alb[..., 2] -= m * 0.15
    alb[..., 0] -= m2 * 0.4; alb[..., 1] -= m2 * 0.35; alb[..., 2] -= m2 * 0.25
    # edge darkening vignette
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(yy, h - yy), np.minimum(xx, w - xx)) / 60.0
    vig = np.clip(d, 0, 1) ** 1.5
    alb *= (1 - 0.35 * (1 - vig))[..., None]
    alb = draw_lines_pil(alb, 25, 73, color=(60, 50, 30), alpha=50, wmin=1, wmax=2)
    save("paper.png", alb, "RGB")

# ---------------- 9. SWAMP MUD ----------------
def gen_mud():
    w = h = 1024
    base = fbm(w, h, 7, 5, seed=81)
    pools = fbm(w, h, 3, 3, seed=82)
    pm = np.clip((pools - 0.55) / 0.45, 0, 1)
    g = 0.10 + 0.10 * base
    alb = np.stack([g * 1.0, g * 1.15, g * 0.9], -1)
    alb[..., 1] += pm * 0.06
    alb[..., 0] = np.where(pm > 0.05, 0.02 + 0.01 * base, alb[..., 0])
    alb[..., 1] = np.where(pm > 0.05, 0.035 + 0.02 * base, alb[..., 1])
    alb[..., 2] = np.where(pm > 0.05, 0.025 + 0.01 * base, alb[..., 2])
    alb = draw_lines_pil(alb, 160, 83, color=(5, 8, 4), alpha=120, wmin=1, wmax=3, lmin=12, lmax=70)
    write_tex("mud_swamp", alb, normal_from_height(base * 0.7 + pm * 0.5, 1.8))

# ---------------- 10. MOSSY STONE ----------------
def gen_stone():
    w = h = 1024
    cells = 6
    yy, xx = np.mgrid[0:h, 0:w]
    cw, ch = w // cells, h // cells
    alb = np.zeros((h, w, 3), np.float32)
    g = np.random.default_rng(91)
    heights = g.uniform(0.35, 0.6, (cells, cells))
    hgt = np.zeros((h, w), np.float32)
    for r in range(cells):
        for c in range(cells):
            hgt[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = heights[r, c] + fbm(cw, ch, 3, 3, seed=92)[:, :] * 0.1
    base = fbm(w, h, 6, 4, seed=93)
    grey = 0.30 + hgt * 0.3 + base * 0.08
    alb[..., 0] = grey * 1.0; alb[..., 1] = grey * 0.98; alb[..., 2] = grey * 0.92
    # moss
    moss = fbm(w, h, 4, 4, seed=94)
    mm = np.clip((moss - 0.66) / 0.34, 0, 1) ** 1.3
    alb[..., 0] = alb[..., 0] * (1 - mm) + mm * 0.06
    alb[..., 1] = alb[..., 1] * (1 - mm) + mm * 0.14
    alb[..., 2] = alb[..., 2] * (1 - mm) + mm * 0.05
    write_tex("stone_moss", alb, normal_from_height((hgt - hgt.min()) * 1.2 + moss * 0.4, 2.0))

# ---------------- 11. PEAT / ROOT wood ----------------
def gen_peat():
    w = h = 1024
    yy, xx = np.mgrid[0:h, 0:w]
    warp = sfield(w, h, 5, 3, seed=101) * 8 + sfield(w, h, 3, 6, seed=102) * 4
    bands = np.sin((yy + warp) / h * np.pi * 26) ** 0.7  # growth rings vertical
    base = fbm(w, h, 5, 4, seed=103)
    lum = 0.13 + bands * 0.10 + base * 0.08
    alb = np.stack([lum * 1.1, lum * 0.8, lum * 0.45], -1)
    knots = fbm(w, h, 2, 2, seed=104)
    kn = np.clip((knots - 0.8) / 0.2, 0, 1)
    alb *= (1 - kn * 0.35)[..., None]
    write_tex("peat_root", alb, normal_from_height(bands * 0.8 + base * 0.4 + kn * 0.6, 2.4))

# ---------------- 12. WATER normal map ----------------
def gen_water():
    w = h = 512
    n1 = sfield(w, h, 6, 4, seed=111)
    n2 = sfield(w, h, 4, 9, seed=112)
    hgt = n1 * 0.4 + n2 * 0.6
    save("water_normal.png", np.power(np.clip(normal_from_height(hgt, 6.0), 0, 1), 1.0), "RGB")
    alb = np.zeros((h, w, 3), np.float32)
    alb[..., 0] = 0.015; alb[..., 1] = 0.03; alb[..., 2] = 0.02
    save("water_albedo.png", alb, "RGB")

# ---------------- 13. FOLIAGE (RGBA) ----------------
def gen_foliage():
    g = np.random.default_rng(121)
    # reeds: tall blade cluster, RGBA
    w, h = 256, 512
    a = np.zeros((h, w, 4), np.float32); a[..., 3] = 0
    col = np.array([0.10, 0.19, 0.07])
    for i in range(11):
        bx = g.uniform(30, w - 30); bh = g.uniform(h * 0.42, h * 0.98)
        bw = g.uniform(5, 10); bend = g.uniform(-0.8, 0.8)
        for y in range(0, int(bh)):
            t = y / bh                      # 0 at base -> 1 at tip
            xc = bx + bend * t * t * w * 0.30   # quadratic bend toward tip
            half = bw * (1.0 - 0.72 * t) + 0.6  # tapering width
            x0, x1 = int(xc - half), int(xc + half)
            for x in range(max(0, x0), min(w, x1 + 1)):
                f = 1 - abs(x - xc) / max(half, 0.01)
                if f > 0.15:
                    a[y, x, 3] = max(a[y, x, 3], min(1.0, f * (0.9 - 0.5 * t)))
                    a[y, x, :3] = np.maximum(a[y, x, :3], col * (0.75 + 0.45 * (1 - t)))
    # seed-heads (dark cattail tips on a few blades)
    for i in range(3):
        bx = g.uniform(30, w - 30); bh = g.uniform(h * 0.6, h * 0.9)
        bend = g.uniform(-0.3, 0.3)
        for y in range(int(bh), min(h, int(bh + 26))):
            xc = bx + bend * (y / bh) ** 2 * w * 0.2
            for x in range(int(xc - 4), int(xc + 5)):
                if 0 <= x < w:
                    a[y, x, 3] = 0.95
                    a[y, x, :3] = np.array([0.03, 0.05, 0.02])
    save("reed.png", a, "RGBA")
    # lily leaf pad
    w2 = h2 = 256
    yy, xx = np.mgrid[0:h2, 0:w2]
    d = np.sqrt((yy - h2 / 2) ** 2 + (xx - w2 / 2) ** 2)
    a2 = np.zeros((h2, w2, 4), np.float32)
    m = (d < 100) & (np.abs(yy - h2 / 2) < 30)
    a2[m, 3] = 1.0
    a2[m, :3] = (0.05, 0.16, 0.06)
    notch = (xx > w2 / 2 - 14) & (yy > h2 / 2 - 14) & (yy < h2 / 2 + 14)
    a2[notch, 3] = 0
    a2[..., :3] += (fbm(w2, h2, 4, 3, seed=122) * 0.03)[..., None]
    save("lily_pad.png", a2, "RGBA")
    # glow dot sprite
    w3 = 128
    yy3, xx3 = np.mgrid[0:w3, 0:w3]
    d3 = np.sqrt((yy3 - w3 / 2) ** 2 + (xx3 - w3 / 2) ** 2) / (w3 / 2)
    g3 = np.clip(1 - d3, 0, 1) ** 2.2
    a3 = np.zeros((w3, w3, 4), np.float32)
    a3[..., 3] = g3
    a3[..., 0] = 0.65 * g3; a3[..., 1] = 0.95 * g3; a3[..., 2] = 0.6 * g3
    save("glow_dot.png", a3, "RGBA")
    # swamp bloom flower (RGBA) — bioluminescent lily
    w4 = 256; h4 = 256
    a4 = np.zeros((h4, w4, 4), np.float32)
    cy, cx = 170, 128
    petal_col = np.array([0.5, 0.9, 0.65])
    for k in range(6):
        ang = k * math.pi / 3
        for t in np.linspace(0, 1, 60):
            rad = t * 60
            px = int(cx + math.cos(ang) * rad * 1.4); py = int(cy + math.sin(ang) * rad * 0.4 + (1 - t) * 0)
            for rr in range(3):
                for aa in range(24):
                    ang2 = math.atan2(aa / 24 * 2 - 1, 0.5)  # noop
                pass
        # petal as rotated ellipse
        for t in range(0, 60):
            for side in (-1, 1):
                wid = 10 * (1 - t / 60) + 2
                for dw in range(int(-wid), int(wid) + 1):
                    px = int(cx + math.cos(ang) * t * 1.35 - math.sin(ang) * dw * 0.35)
                    py = int(cy + math.sin(ang) * t * 1.35 + math.cos(ang) * dw * 0.35)
                    if 0 <= px < w4 and 0 <= py < h4:
                        fade = (1 - t / 60) * (1 - abs(dw) / wid)
                        a4[py, px, 3] = max(a4[py, px, 3], fade)
                        a4[py, px, :3] = np.maximum(a4[py, px, :3], petal_col * fade)
    gcore = np.clip(1 - d3 * 1.2, 0, 1) ** 1.5
    a4[..., 3] = np.maximum(a4[..., 3], 0)
    save("lily_bloom.png", a4, "RGBA")

# ---------------- 14. RUG (RGBA, ornate border) ----------------
def gen_rug():
    w, h = 1024, 512
    a = np.zeros((h, w, 4), np.float32)
    a[..., 3] = 1
    bg = np.array([0.16, 0.05, 0.07])
    a[..., :3] = bg
    bd = 42
    a[bd:h - bd, bd:w - bd, :3] = np.array([0.30, 0.10, 0.12])
    # inner border
    a[bd + 12:h - bd - 12, bd + 12:w - bd - 12, :3] = np.array([0.10, 0.04, 0.06])
    # center medallion-ish pattern (simplified diamonds)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.abs(yy - h / 2) + np.abs(xx - w / 2)
    med = (d < 160) & (d > 90)
    a[med, :3] = np.array([0.35, 0.13, 0.14])
    med2 = (d < 200) & (d > 170)
    a[med2, :3] = np.array([0.45, 0.18, 0.16])
    f = fbm(w, h, 6, 3, seed=131)
    a[..., :3] *= (0.85 + 0.25 * f[..., None])
    save("rug_red.png", a, "RGBA")

# ---------------- 15. HERRINGBONE floor dirt for museum lower floor? reuse parquet. SKIP

# run all
if __name__ == "__main__":
    print("Generating textures into", os.path.abspath(OUT))
    gen_parquet(); gen_marble(); gen_brass(); gen_velvet(); gen_plaster()
    gen_wallpaper(); gen_glass(); gen_paper(); gen_mud(); gen_stone()
    gen_peat(); gen_water(); gen_foliage(); gen_rug()
    print("ALL TEXTURES DONE")
