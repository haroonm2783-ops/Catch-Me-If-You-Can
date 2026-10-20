"""Perspective preview renders from dist/map-geometry.json (exact baked geometry, no Studio lighting).
Usage: python3 tools/render-views.py OUT.png camx camy camz tx ty tz [fov] [hide-roof]
Requires Pillow and NumPy. These are geometry previews, not Roblox renders."""
import json, math, sys
import numpy as np
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
scene = json.loads((ROOT / 'dist/map-geometry.json').read_text())
out = sys.argv[1]
cam = np.array(sys.argv[2:5], float); tgt = np.array(sys.argv[5:8], float)
fov = float(sys.argv[8]) if len(sys.argv) > 8 else 65
hide = (sys.argv[9] == '1') if len(sys.argv) > 9 else False
W, H = 1400, 800
ROOFS = {'VaultGlass','VaultRib','VaultGable','VaultLight','VaultCornice','WingSkylight','SkylightRib','StoreRowRoof','EastWingRoofSolid','WestWingRoofSolid','RoofNeon'}
fw = tgt - cam; fw /= np.linalg.norm(fw)
rt = np.cross(fw, [0, 1, 0]); rt /= np.linalg.norm(rt)
up = np.cross(rt, fw)
f = (H / 2) / math.tan(math.radians(fov) / 2)
light = np.array([-0.4, 1, 0.5]); light /= np.linalg.norm(light)

def mesh(p):
    x, y, z = (s / 2 for s in p['size'])
    sh = p['shape']
    if sh == 'Cylinder':
        n = 14
        v = [(s * x, math.cos(i * 2 * math.pi / n) * y, math.sin(i * 2 * math.pi / n) * z) for s in (-1, 1) for i in range(n)]
        fc = [list(range(n - 1, -1, -1)), list(range(n, 2 * n))] + [[i, (i + 1) % n, (i + 1) % n + n, i + n] for i in range(n)]
    elif sh == 'Ball':
        n, m = 10, 6; v = []
        for j in range(m + 1):
            lat = -math.pi / 2 + j * math.pi / m
            for i in range(n):
                a = i * 2 * math.pi / n
                v.append((math.cos(lat) * math.cos(a) * x, math.sin(lat) * y, math.cos(lat) * math.sin(a) * z))
        fc = [[j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i] for j in range(m) for i in range(n)]
    else:
        v = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        fc = [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]
    c = p['cf']; R = np.array([[c[3],c[4],c[5]],[c[6],c[7],c[8]],[c[9],c[10],c[11]]]); t = np.array(c[:3])
    return (np.array(v) @ R.T) + t, fc

polys = []
for p in scene['parts']:
    if hide and p['name'] in ROOFS: continue
    if p['name'] in ('CityBelow',): continue
    V, fc = mesh(p)
    for idx in fc:
        vs = V[idx]
        n = np.cross(vs[1] - vs[0], vs[-1] - vs[0]); ln = np.linalg.norm(n)
        if ln < 1e-9: continue
        n /= ln
        if np.dot(n, cam - vs[0]) <= 0 and p['alpha'] < 0.3: continue
        s = 0.62 + 0.38 * max(0, np.dot(n, light))
        if p['neon']: s = 1.15
        col = np.minimum(255, np.array(p['color']) * 255 * s)
        polys.append((vs, col, p['alpha']))

def to_cam(v): d = v - cam; return np.array([d @ rt, d @ up, d @ fw])
img = np.zeros((H, W, 3), np.float32)
for y in range(H):
    t = y / H; img[y, :] = (150 - 40 * t, 175 - 40 * t, 225 - 30 * t)
depth = np.full((H, W), np.inf, np.float32)
near = 0.5
polys.sort(key=lambda q: -np.linalg.norm(q[0].mean(axis=0) - cam))
for vs, col, alpha in polys:
    pc = [to_cam(v) for v in vs]
    # clip against near plane
    clipped = []
    for i in range(len(pc)):
        a, b = pc[i], pc[(i + 1) % len(pc)]
        ain, bin_ = a[2] >= near, b[2] >= near
        if ain: clipped.append(a)
        if ain != bin_:
            t = (near - a[2]) / (b[2] - a[2]); clipped.append(a + (b - a) * t)
    if len(clipped) < 3: continue
    sp = [(W / 2 + f * c[0] / c[2], H / 2 - f * c[1] / c[2], c[2]) for c in clipped]
    for i in range(1, len(sp) - 1):
        a, b, c = sp[0], sp[i], sp[i + 1]
        minx = max(0, int(min(a[0], b[0], c[0]))); maxx = min(W - 1, int(max(a[0], b[0], c[0])) + 1)
        miny = max(0, int(min(a[1], b[1], c[1]))); maxy = min(H - 1, int(max(a[1], b[1], c[1])) + 1)
        if minx >= maxx or miny >= maxy: continue
        dv = (b[1]-c[1])*(a[0]-c[0]) + (c[0]-b[0])*(a[1]-c[1])
        if abs(dv) < 1e-6: continue
        yy, xx = np.mgrid[miny:maxy+1, minx:maxx+1]
        u = ((b[1]-c[1])*(xx-c[0]) + (c[0]-b[0])*(yy-c[1])) / dv
        v = ((c[1]-a[1])*(xx-c[0]) + (a[0]-c[0])*(yy-c[1])) / dv
        w = 1 - u - v
        zz = u*a[2] + v*b[2] + w*c[2]
        cur = depth[miny:maxy+1, minx:maxx+1]
        mask = (u >= 0) & (v >= 0) & (w >= 0) & (zz < cur)
        tile = img[miny:maxy+1, minx:maxx+1]
        fog = np.clip((zz - 120) / 500, 0, 0.5)[..., None]
        shaded = col * (1 - fog) + np.array([170, 175, 215]) * fog
        if alpha > 0:
            tile[mask] = shaded[mask] * (1 - alpha) + tile[mask] * alpha
        else:
            tile[mask] = shaded[mask]; cur[mask] = zz[mask]
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out)
print(out)
