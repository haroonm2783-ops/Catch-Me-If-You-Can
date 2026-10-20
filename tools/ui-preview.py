"""Approximate Roblox GUI layout + render from tests' UI_DUMP json (geometry preview, NOT Studio).
Usage: python3 tools/ui-preview.py DUMP_DIR OUT_DIR [name ...]
Implements anchors, UDim2, UIListLayout, UIGridLayout, size constraints, automatic size, corners, strokes, gradients.
Fonts are DejaVu/Noto stand-ins for Gotham, so text widths are approximate."""
import json, sys, os
from PIL import Image, ImageDraw, ImageFont
GUI = {'Frame','TextLabel','TextButton','ScrollingFrame','ViewportFrame','ScreenGui','ImageLabel'}
src, out = sys.argv[1], sys.argv[2]
names = sys.argv[3:]
os.makedirs(out, exist_ok=True)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
EMOJI = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'
_f = {}
def font(size, bold):
    k = (int(size), bold)
    if k not in _f: _f[k] = ImageFont.truetype(BOLD if bold else FONT, max(6, int(size)))
    return _f[k]
_emoji = ImageFont.truetype(EMOJI, 109)
warnings = []

def kids(n): return [c for c in n['children'] if c['cls'] in GUI]
def helper(n, cls):
    for c in n['children']:
        if c['cls'] == cls: return c
    return None

def measure(n, pw, ph):
    s = n.get('size') or [0, 0, 0, 0]
    w, h = s[0] * pw + s[1], s[2] * ph + s[3]
    mc = helper(n, 'UISizeConstraint')
    if mc:
        if mc.get('minSize'): w, h = max(w, mc['minSize'][0]), max(h, mc['minSize'][1])
        if mc.get('maxSize'): w, h = min(w, mc['maxSize'][0]), min(h, mc['maxSize'][1])
    if n.get('auto') and n['auto'] != 'None':
        solve(n, 0, 0, pw, ph, (0, 0))
        w, h = n['rect'][2], n['rect'][3]
    return w, h

def solve(n, px, py, pw, ph, forced=None):
    w, h = measure_noauto(n, pw, ph)
    anc = n.get('anchor') or [0, 0]
    pos = n.get('pos') or [0, 0, 0, 0]
    if forced: x, y = forced
    else: x, y = px + pos[0] * pw + pos[1] - anc[0] * w, py + pos[2] * ph + pos[3] - anc[1] * h
    n['rect'] = [x, y, w, h]
    arrange(n)
    auto = n.get('auto')
    if auto and auto != 'None':
        ex = max([c['rect'][0] + c['rect'][2] - x for c in kids(n) if c['vis']] + [0])
        ey = max([c['rect'][1] + c['rect'][3] - y for c in kids(n) if c['vis']] + [0])
        if auto in ('X', 'XY'): w = ex
        if auto in ('Y', 'XY'): h = ey
        if not forced: x, y = px + pos[0] * pw + pos[1] - anc[0] * w, py + pos[2] * ph + pos[3] - anc[1] * h
        n['rect'] = [x, y, w, h]
        arrange(n)

def measure_noauto(n, pw, ph):
    s = n.get('size') or [0, 0, 0, 0]
    w, h = s[0] * pw + s[1], s[2] * ph + s[3]
    mc = helper(n, 'UISizeConstraint')
    if mc:
        if mc.get('minSize'): w, h = max(w, mc['minSize'][0]), max(h, mc['minSize'][1])
        if mc.get('maxSize'): w, h = min(w, mc['maxSize'][0]), min(h, mc['maxSize'][1])
    return w, h

def arrange(n):
    x, y, w, h = n['rect']
    lst, grid = helper(n, 'UIListLayout'), helper(n, 'UIGridLayout')
    ks = [c for c in kids(n)]
    if lst or grid:
        ks = sorted(enumerate(ks), key=lambda t: (t[1].get('order', 0), t[0]))
        ks = [t[1] for t in ks if t[1]['vis']]
    if lst:
        pad = lst.get('padding') or 0
        sizes = [measure(c, w, h) for c in ks]
        horizontal = lst.get('fill') == 'Horizontal'
        ha = lst.get('ha') or 'Left'
        if horizontal:
            total = sum(s[0] for s in sizes) + pad * max(0, len(ks) - 1)
            cx = {'Left': 0, 'Center': (w - total) / 2, 'Right': w - total}[ha]
            for c, s in zip(ks, sizes):
                solve(c, x, y, w, h, (x + cx, y)); cx += s[0] + pad
        else:
            cy = 0
            for c, s in zip(ks, sizes):
                off = {'Left': 0, 'Center': (w - s[0]) / 2, 'Right': w - s[0]}[ha]
                solve(c, x, y, w, h, (x + off, y + cy)); cy += s[1] + pad
    elif grid:
        cs, cp = grid['cell'], grid.get('cellPad') or [0, 0, 0, 0]
        cw, ch = cs[0] * w + cs[1], cs[2] * h + cs[3]
        px_, py_ = cp[1], cp[3]
        cols = max(1, int((w + px_) // (cw + px_)))
        for i, c in enumerate(ks):
            r, k = divmod(i, cols)
            solve(c, x, y, w, h, (x + k * (cw + px_), y + r * (ch + py_)))
            c['rect'][2], c['rect'][3] = cw, ch
            arrange(c)
    else:
        for c in kids(n): solve(c, x, y, w, h)

def gradient_img(size, c1, c2, rotation):
    w, h = max(1, int(size[0])), max(1, int(size[1]))
    img = Image.new('RGB', (w, h))
    px = img.load()
    for yy in range(h):
        for xx in range(w):
            t = (yy / max(h - 1, 1)) if rotation == 90 else (xx / max(w - 1, 1))
            px[xx, yy] = tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))
    return img

def radius_of(n):
    c = helper(n, 'UICorner')
    if not c or not c.get('radius'): return 0
    r = c['radius']
    return min(n['rect'][2], n['rect'][3]) / 2 if r[0] >= 1 else (r[0] * min(n['rect'][2], n['rect'][3]) + r[1])

def draw(n, img, clip):
    if not n['vis']: return
    x, y, w, h = n['rect']
    if w <= 0 or h <= 0: return
    d = ImageDraw.Draw(img, 'RGBA')
    r = radius_of(n)
    box = (x, y, x + w, y + h)
    if n['cls'] != 'ScreenGui' and n.get('bg') and n['bgt'] < 1 and not (n['cls'] == 'TextLabel' and n['bgt'] >= 1):
        alpha = int(255 * (1 - n['bgt']))
        g = helper(n, 'UIGradient')
        layer = Image.new('RGBA', (int(w) + 1, int(h) + 1), (0, 0, 0, 0))
        mask = Image.new('L', layer.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=r, fill=alpha)
        if g and g.get('gradient') and n['cls'] in ('Frame', 'TextButton', 'TextLabel') and n['cls'] != 'TextButton' or (g and g.get('gradient') and n['cls'] == 'TextButton' and not n.get('text')):
            fill = gradient_img(layer.size, g['gradient'][0], g['gradient'][1], g.get('rotation') or 90)
        else:
            fill = Image.new('RGB', layer.size, tuple(n['bg']))
        img.paste(fill, (int(x), int(y)), mask)
    st = helper(n, 'UIStroke')
    if st and st.get('thickness') and st.get('color') and n['cls'] != 'TextLabel' or (st and st.get('color') and n['cls'] == 'TextLabel' and n['bgt'] < 1):
        a = int(255 * (1 - (st.get('alpha') or 0)))
        d.rounded_rectangle(box, radius=r, outline=tuple(st['color']) + (a,), width=max(1, int(st['thickness'])))
    if n['cls'] == 'ViewportFrame':
        d.rounded_rectangle(box, radius=8, outline=(255, 255, 255, 60), width=1)
        d.ellipse((x + w * .4, y + h * .12, x + w * .6, y + h * .3), fill=(200, 190, 230, 140))
        d.rounded_rectangle((x + w * .35, y + h * .32, x + w * .65, y + h * .75), radius=8, fill=(200, 190, 230, 120))
        d.text((x + 6, y + 4), '3D', fill=(255, 255, 255, 120), font=font(10, True))
    t = n.get('text')
    if t and n['cls'] in ('TextLabel', 'TextButton'):
        size = n.get('textSize') or 14
        if n.get('textScaled'): size = min(h * .8, 40)
        bold = (n.get('font') or '') in ('GothamBold', 'GothamBlack')
        col = tuple(n.get('textColor') or [255, 255, 255])
        if any(ord(ch) > 0x2000 for ch in t) and len(t) <= 4:
            e = _emoji.getmask(t[0], mode='RGBA') if False else None
            tmp = Image.new('RGBA', (136, 128), (0, 0, 0, 0))
            ImageDraw.Draw(tmp).text((0, 0), t[0], font=_emoji, embedded_color=True)
            bb = tmp.getbbox()
            if bb:
                tmp = tmp.crop(bb)
                sc = size / 109 * 1.15
                tmp = tmp.resize((max(1, int(tmp.width * sc)), max(1, int(tmp.height * sc))))
                ax = {'Left': x, 'Center': x + (w - tmp.width) / 2, 'Right': x + w - tmp.width}[n.get('tx') or 'Center']
                ay = y + (h - tmp.height) / 2
                img.paste(tmp, (int(ax), int(ay)), tmp)
        else:
            f = font(size, bold)
            lines = []
            if n.get('textWrapped'):
                cur = ''
                for word in t.replace('\n', ' \n ').split(' '):
                    if word == '\n': lines.append(cur); cur = ''; continue
                    test = (cur + ' ' + word).strip()
                    if d.textlength(test, font=f) <= w - 2 or not cur: cur = test
                    else: lines.append(cur); cur = word
                lines.append(cur)
            else:
                lines = t.split('\n')
            lh = size * 1.15
            total = lh * len(lines)
            ty = {'Top': y, 'Center': y + (h - total) / 2, 'Bottom': y + h - total}[n.get('ty') or 'Center']
            for i, line in enumerate(lines):
                tw = d.textlength(line, font=f)
                if tw > w + 4 and not n.get('textScaled'): warnings.append(f"TEXT OVERFLOW '{line[:30]}' {tw:.0f}>{w:.0f} in {n['name']}")
                tx = {'Left': x, 'Center': x + (w - tw) / 2, 'Right': x + w - tw}[n.get('tx') or ('Center' if n['cls']=='TextButton' else 'Left')]
                d.text((tx, ty + i * lh), line, font=f, fill=col)
    ks = sorted(enumerate(kids(n)), key=lambda t: (t[1].get('z', 1), t[0]))
    if n['cls'] == 'ScrollingFrame':
        scratch = img.copy()
        for _, c in ks: draw(c, scratch, clip)
        region = (max(0, int(x)), max(0, int(y)), min(img.width, int(x + w)), min(img.height, int(y + h)))
        if region[2] > region[0] and region[3] > region[1]: img.paste(scratch.crop(region), region[:2])
    else:
        for _, c in ks: draw(c, img, clip)

def overflow(n, parent=None):
    if not n['vis']: return
    if parent and parent['cls'] not in ('ScrollingFrame',) and n['cls'] in GUI and n['name'] not in ('Gloss', 'Shadow') and not helper(parent, 'UIListLayout') and parent['cls'] != 'ScreenGui':
        px, py, pw, ph = parent['rect']; x, y, w, h = n['rect']
        if x < px - 3 or y < py - 3 or x + w > px + pw + 3 or y + h > py + ph + 3:
            if w > 0 and h > 0 and not (n['bgt'] >= 1 and n['cls'] == 'Frame'):
                warnings.append(f"OUTSIDE PARENT {n['name']} ({n['cls']}) {[round(v) for v in n['rect']]} in {parent['name']} {[round(v) for v in parent['rect']]}")
    for c in kids(n): overflow(c, n)

for fn in sorted(os.listdir(src)):
    base = fn[:-5]
    if names and base not in names: continue
    data = json.load(open(os.path.join(src, fn)))
    W, H = data['viewport']
    tree = data['tree']
    warnings.clear()
    # ScreenGui root is the viewport minus the 36px top bar (IgnoreGuiInset=false).
    solve(tree, 0, 0, W, H, (0, 0)); tree['rect'] = [0, 0, W, H]
    arrange(tree)
    img = Image.new('RGB', (int(W), int(H)), (70, 96, 150))
    d = ImageDraw.Draw(img)
    for yy in range(int(H)): d.line((0, yy, W, yy), fill=(90 + yy * 40 // int(H), 120 + yy * 30 // int(H), 190 - yy * 40 // int(H)))
    # chat zone marker (Roblox default chat window) so overlaps are obvious
    d.rectangle((0, 0, min(W, 440), min(H, 230)), outline=(255, 255, 0), width=1)
    d.text((6, 4), 'Roblox chat zone', fill=(255, 255, 0), font=font(10, False))
    draw(tree, img, None)
    overflow(tree)
    img.save(os.path.join(out, base + '.png'))
    print(base, len(warnings), 'warnings')
    for w_ in warnings[:12]: print('   ', w_)
