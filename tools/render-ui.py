"""Layout preview of an exported UI tree (Pillow). NOT a Roblox render: no real fonts, emoji, gradients or
UIListLayout edge cases. It exists to check composition, overlap and sizing at different screen sizes.
  .tooling/bin/lune run tools/export-ui.luau 1280 720 runner .tooling/ui.json
  python3 tools/render-ui.py .tooling/ui.json .tooling/ui.png
The translucent blue box marks where Roblox's chat window sits on keyboard devices after UIController moves it.
"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

data = json.loads(Path(sys.argv[1]).read_text())
W, H = data["width"], data["height"]
out = sys.argv[2]
img = Image.new("RGBA", (W, H), (96, 150, 120, 255))
d = ImageDraw.Draw(img, "RGBA")
for y in range(H):  # simple sky-to-floor backdrop standing in for the 3D world
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(140 - 60 * t), int(190 - 40 * t), int(235 - 120 * t), 255))

def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "DejaVuSans-Bold.ttf"):
        try: return ImageFont.truetype(path, max(6, int(size)))
        except OSError: pass
    return ImageFont.load_default()

def resolve(udim, parent_len):  # (scale, offset)
    return udim[0] * parent_len + udim[1]

def abs_size(node, parent):
    pw, ph = parent[2], parent[3]
    s = node.get("size") or [0, 0, 0, 0]
    w, h = resolve(s[0:2], pw), resolve(s[2:4], ph)
    c = node.get("constraint")
    if c:
        if c.get("min"): w, h = max(w, c["min"][0]), max(h, c["min"][1])
        if c.get("max"): w, h = min(w, c["max"][0]), min(h, c["max"][1])
    return w, h

rects = []  # (z_path, rect, node)
def layout(node, parent, zpath):
    if not node["visible"] or node["name"] == "Sheen": return  # sheen is a transparency gradient this tool cannot draw
    x, y, pw, ph = parent
    w, h = (pw, ph) if node["class"] == "ScreenGui" else abs_size(node, parent)
    p = node.get("pos") or [0, 0, 0, 0]
    a = node.get("anchor") or [0, 0]
    nx = x + resolve(p[0:2], pw) - a[0] * w
    ny = y + resolve(p[2:4], ph) - a[1] * h
    if node["class"] != "ScreenGui":
        rects.append((zpath, (nx, ny, w, h), node))
    kids = [c for c in node["children"] if c["visible"]]
    lst, grid = node.get("list"), node.get("grid")
    if lst:
        kids.sort(key=lambda c: c["order"])
        cursor = 0
        sizes = [abs_size(c, (nx, ny, w, h)) for c in kids]
        total = sum((s[0] if lst["horizontal"] else s[1]) for s in sizes) + lst["padding"] * max(0, len(kids) - 1)
        start = 0
        if lst["horizontal"] and lst["halign"] == "Center": start = (w - total) / 2
        for c, s in zip(kids, sizes):
            if lst["horizontal"]:
                cx, cy = nx + start + cursor, ny
                cursor += s[0] + lst["padding"]
            else:
                cx = nx + ((w - s[0]) / 2 if lst["halign"] == "Center" else 0)
                cy = ny + cursor
                cursor += s[1] + lst["padding"]
            sub = dict(c); sub["pos"] = [0, 0, 0, 0]; sub["anchor"] = [0, 0]
            layout(sub, (cx, cy, s[0], s[1]) if False else (cx, cy, w, h), zpath + [(c["z"], c["order"])])
            # list layout positions the child by its own size; reuse its size with zero position
    elif grid:
        kids.sort(key=lambda c: c["order"])
        cw, ch = resolve(grid["cell"][0:2], w), resolve(grid["cell"][2:4], h)
        px, py = grid["padding"]
        cols = max(1, int((w + px) // (cw + px)))
        for i, c in enumerate(kids):
            cx, cy = nx + (i % cols) * (cw + px), ny + (i // cols) * (ch + py)
            sub = dict(c); sub["pos"] = [0, 0, 0, 0]; sub["anchor"] = [0, 0]; sub["size"] = [0, cw, 0, ch]
            layout(sub, (cx, cy, cw, ch), zpath + [(c["z"], c["order"])])
    else:
        for i, c in enumerate(kids):
            layout(c, (nx, ny, w, h), zpath + [(c["z"], i)])

layout(data["tree"], (0, 0, W, H), [])
rects.sort(key=lambda r: r[0])
overlaps = []
for zpath, (x, y, w, h), n in rects:
    bg = n.get("gradient") if n.get("gradient") and n.get("bg") == [1, 1, 1] else n.get("bg")
    if bg is not None and n["alpha"] < 1 and w > 0 and h > 0:
        fill = tuple(int(c * 255) for c in bg) + (int(255 * (1 - n["alpha"])),)
        r = min(n.get("corner") or 0, w / 2, h / 2)
        d.rounded_rectangle((x, y, x + w, y + h), radius=r, fill=fill)
        if n.get("stroke"):
            sc = tuple(int(c * 255) for c in n["stroke"]["color"])
            d.rounded_rectangle((x, y, x + w, y + h), radius=r, outline=sc + (255,), width=max(1, int(n["stroke"]["thickness"])))
    if n.get("text"):
        text = "".join(ch if ord(ch) < 0x2000 else "o" for ch in n["text"]).replace("\n", " ")
        f = font(n["textSize"] or 12)
        tc = tuple(int(c * 255) for c in (n.get("textColor") or [1, 1, 1]))
        bbox = d.textbbox((0, 0), text, font=f)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        al = n.get("textAlign", "Left")
        tx = x + (w - tw) / 2 if al == "Center" else (x + w - tw if al == "Right" else x)
        ty = y + (h - th) / 2 - bbox[1]
        d.text((tx, ty), text, font=f, fill=tc + (255,))
# Approximate Roblox chat on keyboard devices after UIController positions it (bottom-left, 22% x 20%).
if not data.get("touch"):
    d.rectangle((0, H - 0.2 * H, 0.22 * W, H), outline=(255, 255, 0, 255), width=2, fill=(0, 120, 255, 70))
    d.text((8, H - 0.2 * H + 4), "CHAT (approx.)", font=font(11), fill=(255, 255, 255, 255))
d.rectangle((0, 0, W - 1, H - 1), outline=(0, 0, 0, 255))
img.convert("RGB").save(out)
print(out, len(rects), "visible rects")
