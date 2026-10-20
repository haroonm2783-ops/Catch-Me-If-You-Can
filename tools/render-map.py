"""Software renderer for exported map geometry (Pillow + NumPy). Not a Studio render.
Examples:
  python3 tools/render-map.py --view iso --out docs/Mall-overview.png
  python3 tools/render-map.py --view plan --ymin -1 --ymax 22 --out docs/Mall-floor1.png
"""
import argparse, json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent

def unit(v):
    v = np.array(v, float)
    return v / np.linalg.norm(v)

def mesh(part):
    x, y, z = (s / 2 for s in part["size"])
    shape = part["shape"]
    if shape == "Cylinder":
        n = 10
        vertices = [(s*x, math.cos(i*2*math.pi/n)*y, math.sin(i*2*math.pi/n)*z) for s in (-1, 1) for i in range(n)]
        faces = [list(range(n-1, -1, -1)), list(range(n, 2*n))] + [[i, (i+1)%n, (i+1)%n+n, i+n] for i in range(n)]
    elif shape == "Ball":
        n, m = 8, 5
        vertices = []
        for j in range(m+1):
            lat = -math.pi/2 + j*math.pi/m
            for i in range(n):
                lon = i*2*math.pi/n
                vertices.append((math.cos(lat)*math.cos(lon)*x, math.sin(lat)*y, math.cos(lat)*math.sin(lon)*z))
        faces = [[j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i] for j in range(m) for i in range(n)]
    elif shape == "Wedge":
        vertices = [(-x,-y,-z), (x,-y,-z), (-x,-y,z), (x,-y,z), (-x,y,z), (x,y,z)]
        faces = [[0,2,3,1], [2,4,5,3], [0,1,5,4], [0,4,2], [1,3,5]]
    else:
        vertices = [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z), (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)]
        faces = [[0,3,2,1], [4,5,6,7], [0,4,7,3], [1,2,6,5], [3,7,6,2], [0,1,5,4]]
    cf = part["cf"]
    matrix = np.array(cf[3:]).reshape((3, 3))
    return np.array(vertices) @ matrix.T + np.array(cf[:3]), faces

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default=str(ROOT / ".tooling/map-geometry.json"))
    ap.add_argument("--out", default=str(ROOT / "docs/map.png"))
    ap.add_argument("--view", choices=["iso", "plan", "iso2"], default="iso")
    ap.add_argument("--ymin", type=float, default=-1e9)
    ap.add_argument("--ymax", type=float, default=1e9)
    ap.add_argument("--width", type=int, default=1800)
    ap.add_argument("--height", type=int, default=1400)
    ap.add_argument("--xmin", type=float, default=-1e9)
    ap.add_argument("--xmax", type=float, default=1e9)
    ap.add_argument("--zmin", type=float, default=-1e9)
    ap.add_argument("--zmax", type=float, default=1e9)
    ap.add_argument("--title", default="")
    ap.add_argument("--skip", default="", help="comma separated name fragments to hide")
    ap.add_argument("--only-collide", action="store_true")
    ap.add_argument("--cam", default="")
    args = ap.parse_args()
    scene = json.loads(Path(args.input).read_text())
    W, H = args.width, args.height
    skips = [s for s in args.skip.split(",") if s]
    parts = []
    for p in scene["parts"]:
        cy = p["cf"][1]; cx = p["cf"][0]; cz = p["cf"][2]
        if cy < args.ymin or cy > args.ymax: continue
        if not (args.xmin <= cx <= args.xmax and args.zmin <= cz <= args.zmax): continue
        if any(s in p["name"] for s in skips): continue
        if args.only_collide and not p["collide"]: continue
        parts.append(p)
    xs = [p["cf"][0] for p in parts]; zs = [p["cf"][2] for p in parts]
    cx, cz = (min(xs)+max(xs))/2, (min(zs)+max(zs))/2
    if args.view == "plan":
        camera = np.array([cx, 900, cz+0.01]); target = np.array([cx, 0, cz])
    elif args.view == "iso2":
        camera = np.array([cx+300, 330, cz-420]); target = np.array([cx, 14, cz])
    else:
        camera = np.array([cx-300, 360, cz-480]); target = np.array([cx, 14, cz])
    if args.cam:
        a = [float(v) for v in args.cam.split(",")]
        camera = np.array(a[:3]); target = np.array(a[3:6])
    forward = unit(target - camera)
    right = unit(np.cross(forward, (0, 1, 0))) if args.view != "plan" else np.array([1.0, 0, 0])
    up = np.cross(right, forward)
    if args.view == "plan":
        forward = np.array([0, -1.0, 0]); right = np.array([1.0, 0, 0]); up = np.array([0, 0, 1.0])
    projection = np.array([right, -up, forward]).T
    light = unit((-0.4, 1, -0.6))
    faces = []
    allpts = []
    for p in parts:
        verts, idx = mesh(p)
        allpts.append(verts @ projection)
        center = np.array(p["cf"][:3])
        for f in idx:
            pts = verts[f]
            normal = np.cross(pts[1]-pts[0], pts[-1]-pts[0])
            mag = np.linalg.norm(normal)
            if mag < 1e-10: continue
            normal /= mag
            if np.dot(normal, pts.mean(axis=0)-center) < 0: normal = -normal
            if np.dot(normal, forward) >= 0 and p["alpha"] < 0.3: continue
            strength = 0.72 + 0.28*max(0, np.dot(normal, light))
            if p["neon"]: strength = 1.12
            color = np.minimum(255, np.array(p["color"])*255*strength)
            proj = pts @ projection
            faces.append((proj[:, 2].mean(), proj, color, p["alpha"]))
    allp = np.concatenate(allpts)
    lo, hi = allp.min(axis=0), allp.max(axis=0)
    scale = min((W-80)/(hi[0]-lo[0]), (H-200)/(hi[1]-lo[1]))
    ox = (W - (hi[0]+lo[0])*scale)/2
    oy = 140 + (H-200 - (hi[1]-lo[1])*scale)/2 - lo[1]*scale
    pixels = np.zeros((H, W, 3), dtype=np.uint8)
    pixels[:] = (232, 238, 246)
    depth = np.full((H, W), np.inf, dtype=np.float32)
    for _, proj, color, alpha in sorted(faces, key=lambda f: -f[0]):
        sp = [(ox+p[0]*scale, oy+p[1]*scale, p[2]) for p in proj]
        for i in range(1, len(sp)-1):
            a, b, c = sp[0], sp[i], sp[i+1]
            x0 = max(0, int(min(a[0], b[0], c[0]))); x1 = min(W-1, int(max(a[0], b[0], c[0]))+1)
            y0 = max(0, int(min(a[1], b[1], c[1]))); y1 = min(H-1, int(max(a[1], b[1], c[1]))+1)
            if x0 >= x1 or y0 >= y1: continue
            den = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den) < 1e-9: continue
            yy, xx = np.mgrid[y0:y1+1, x0:x1+1]
            u = ((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
            v = ((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
            w = 1-u-v
            zz = u*a[2]+v*b[2]+w*c[2]
            cur = depth[y0:y1+1, x0:x1+1]
            m = (u >= -0.001) & (v >= -0.001) & (w >= -0.001) & (zz < cur + (0.0 if alpha < 0.3 else 0))
            if alpha < 0.3: cur[m] = zz[m]
            tile = pixels[y0:y1+1, x0:x1+1]
            tile[m] = (color*(1-alpha)+tile[m]*alpha).astype(np.uint8) if alpha > 0 else color
    image = Image.fromarray(pixels)
    d = ImageDraw.Draw(image)
    def font(size, bold=False):
        base = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
        try: return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{base}", size)
        except OSError: return ImageFont.load_default(size=size)
    d.rectangle((0, 0, W, 110), fill=(30, 34, 60))
    d.text((40, 24), args.title or "CATCH MALL", font=font(40, True), fill=(255, 255, 255))
    d.text((42, 74), f"Geometry preview, {len(parts):,} parts shown. Not a Roblox Studio render.", font=font(16), fill=(170, 180, 210))
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out)
    print(args.out)

main()
