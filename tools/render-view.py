"""Perspective software preview of exported map geometry (Pillow + NumPy). NOT a Roblox Studio render:
no real materials, shadows, bloom, or atmosphere. It exists so composition, palette balance and sight lines
can be reviewed without Studio. Example:
  python3 tools/render-view.py --cam 0,6,-60,0,10,0 --out .tooling/view.png
"""
import argparse, json, math
from pathlib import Path
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent

def mesh(p):
    x, y, z = (s / 2 for s in p["size"])
    shape = p["shape"]
    if shape == "Cylinder":
        n = 12
        v = [(s*x, math.cos(i*2*math.pi/n)*y, math.sin(i*2*math.pi/n)*z) for s in (-1, 1) for i in range(n)]
        f = [list(range(n-1, -1, -1)), list(range(n, 2*n))] + [[i, (i+1)%n, (i+1)%n+n, i+n] for i in range(n)]
    elif shape == "Ball":
        n, m = 10, 6
        v = []
        for j in range(m+1):
            lat = -math.pi/2 + j*math.pi/m
            for i in range(n):
                lon = i*2*math.pi/n
                v.append((math.cos(lat)*math.cos(lon)*x, math.sin(lat)*y, math.cos(lat)*math.sin(lon)*z))
        f = [[j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i] for j in range(m) for i in range(n)]
    elif shape == "Wedge":
        v = [(-x,-y,-z), (x,-y,-z), (-x,-y,z), (x,-y,z), (-x,y,z), (x,y,z)]
        f = [[0,2,3,1], [2,4,5,3], [0,1,5,4], [0,4,2], [1,3,5]]
    else:
        v = [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z), (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)]
        f = [[0,3,2,1], [4,5,6,7], [0,4,7,3], [1,2,6,5], [3,7,6,2], [0,1,5,4]]
    cf = p["cf"]
    m = np.array(cf[3:]).reshape((3, 3))
    return np.array(v) @ m.T + np.array(cf[:3]), f

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default=str(ROOT / ".tooling/map-geometry.json"))
    ap.add_argument("--cam", required=True, help="x,y,z,tx,ty,tz")
    ap.add_argument("--fov", type=float, default=70)
    ap.add_argument("--width", type=int, default=1100)
    ap.add_argument("--height", type=int, default=650)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ymax", type=float, default=1e9, help="hide parts above this centre height (cut-away roofs)")
    ap.add_argument("--fog", type=float, default=0.0035)
    ap.add_argument("--exposure", type=float, default=1.0)
    ap.add_argument("--sky", default="150,196,236")
    a = ap.parse_args()
    W, H = a.width, a.height
    c = [float(v) for v in a.cam.split(",")]
    eye, target = np.array(c[:3]), np.array(c[3:])
    fwd = target - eye; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, (0, 1, 0)); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = 1 / math.tan(math.radians(a.fov) / 2)
    aspect = W / H
    sky = np.array([float(v) for v in a.sky.split(",")])
    scene = json.loads(Path(a.input).read_text())
    sun = np.array([-0.35, 0.8, -0.45]); sun /= np.linalg.norm(sun)
    opaque, glass = [], []
    for p in scene["parts"]:
        if p["cf"][1] > a.ymax: continue
        d = np.array(p["cf"][:3]) - eye
        reach = max(p["size"])
        if np.dot(d, fwd) < -reach: continue
        if np.linalg.norm(d) > 700: continue
        verts, idx = mesh(p)
        center = np.array(p["cf"][:3])
        rel = verts - eye
        cam = np.stack([rel @ right, rel @ up, rel @ fwd], axis=1)
        mat = p.get("material", "")
        alpha = p["alpha"]
        if mat == "Glass": alpha = max(alpha, 0.35)
        base = np.array(p["color"]) * 255
        for face in idx:
            pts = verts[face]
            n = np.cross(pts[1]-pts[0], pts[-1]-pts[0]); mg = np.linalg.norm(n)
            if mg < 1e-9: continue
            n /= mg
            if np.dot(n, pts.mean(axis=0)-center) < 0: n = -n
            if np.dot(n, pts.mean(axis=0)-eye) > 0 and alpha < 0.3: continue
            light = 0.55 + 0.25 * (n[1] * 0.5 + 0.5) + 0.35 * max(0, np.dot(n, sun))
            col = base * light
            if p["neon"]: col = np.minimum(255, base * 1.25 + 40)
            tri = (cam[face], np.minimum(255, col), alpha, float(np.linalg.norm(pts.mean(axis=0)-eye)))
            (glass if alpha >= 0.3 else opaque).append(tri)
    img = np.empty((H, W, 3), np.float32); 
    ys = np.linspace(0, 1, H)[:, None]
    img[:] = (sky * (0.75 + 0.25 * (1 - ys)))[:, None, :] if False else sky
    depth = np.full((H, W), np.inf, np.float32)
    near = 0.3
    def raster(poly, color, alpha, dist, write_depth):
        # clip against the near plane
        out = []
        for i in range(len(poly)):
            p0, p1 = poly[i], poly[(i+1) % len(poly)]
            in0, in1 = p0[2] > near, p1[2] > near
            if in0: out.append(p0)
            if in0 != in1:
                t = (near - p0[2]) / (p1[2] - p0[2])
                out.append(p0 + (p1 - p0) * t)
        if len(out) < 3: return
        sp = [((o[0]/o[2]*f/aspect*0.5+0.5)*W, (0.5-o[1]/o[2]*f*0.5)*H, o[2]) for o in out]
        fogk = 1 - math.exp(-a.fog * dist)
        col = (np.array(color) * (1 - fogk) + sky * fogk) * a.exposure
        for i in range(1, len(sp)-1):
            A, B, C = sp[0], sp[i], sp[i+1]
            x0 = max(0, int(min(A[0], B[0], C[0]))); x1 = min(W-1, int(max(A[0], B[0], C[0]))+1)
            y0 = max(0, int(min(A[1], B[1], C[1]))); y1 = min(H-1, int(max(A[1], B[1], C[1]))+1)
            if x0 >= x1 or y0 >= y1 or (x1-x0)*(y1-y0) > W*H*2: continue
            den = (B[1]-C[1])*(A[0]-C[0])+(C[0]-B[0])*(A[1]-C[1])
            if abs(den) < 1e-9: continue
            yy, xx = np.mgrid[y0:y1+1, x0:x1+1]
            u = ((B[1]-C[1])*(xx-C[0])+(C[0]-B[0])*(yy-C[1]))/den
            v = ((C[1]-A[1])*(xx-C[0])+(A[0]-C[0])*(yy-C[1]))/den
            w = 1-u-v
            zz = u*A[2]+v*B[2]+w*C[2]
            cur = depth[y0:y1+1, x0:x1+1]
            m = (u >= -0.001) & (v >= -0.001) & (w >= -0.001) & (zz < cur)
            if not m.any(): continue
            tile = img[y0:y1+1, x0:x1+1]
            tile[m] = col * (1-alpha) * 0 + col if alpha < 0.3 else tile[m] * alpha + col * (1-alpha)
            if write_depth: cur[m] = zz[m]
    for poly, col, al, dist in opaque: raster(list(poly), col, al, dist, True)
    for poly, col, al, dist in sorted(glass, key=lambda t: -t[3]): raster(list(poly), col, al, dist, False)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(a.out)
    print(a.out, len(opaque), "opaque tris,", len(glass), "glass tris")
main()
