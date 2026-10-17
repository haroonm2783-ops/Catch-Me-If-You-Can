"""Optional software contact sheet of exported Appearance.BuildPreview geometry.

Run .tooling/bin/lune run tools/export-characters.luau first, then this script.
Pillow and NumPy are optional inspection dependencies, never game dependencies.
Head SpecialMeshes are rounded box approximations, labelled in the result.
No generated artwork or substitute models are used in this geometry inspection.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent


def unit(v):
    v = np.array(v, dtype=float)
    return v / np.linalg.norm(v)


def mesh(part):
    x, y, z = (s / 2 for s in part["size"])
    shape = part["shape"]
    if shape == "Cylinder":
        n = 20
        vertices = [(s*x, math.cos(i*2*math.pi/n)*y, math.sin(i*2*math.pi/n)*z)
                    for s in (-1, 1) for i in range(n)]
        faces = [list(range(n-1, -1, -1)), list(range(n, 2*n))]
        faces += [[i, (i+1)%n, (i+1)%n+n, i+n] for i in range(n)]
    elif shape in ("Ball", "HeadApproximation"):
        n, m = 24, 16
        exponent = 0.36 if shape == "HeadApproximation" else 1

        def rounded(v):
            return math.copysign(abs(v)**exponent, v)

        vertices = []
        for j in range(m+1):
            latitude = -math.pi/2+j*math.pi/m
            for i in range(n):
                longitude = i*2*math.pi/n
                vertices.append((rounded(math.cos(latitude))*rounded(math.cos(longitude))*x,
                                 rounded(math.sin(latitude))*y,
                                 rounded(math.cos(latitude))*rounded(math.sin(longitude))*z))
        faces = [[j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i]
                 for j in range(m) for i in range(n)]
    elif shape == "Wedge":
        # Roblox WedgePart rises from the local -Z edge to the local +Z edge.
        vertices = [(-x,-y,-z), (x,-y,-z), (-x,-y,z), (x,-y,z), (-x,y,z), (x,y,z)]
        faces = [[0,2,3,1], [2,4,5,3], [0,1,5,4], [0,4,2], [1,3,5]]
    else:
        vertices = [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z),
                    (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)]
        faces = [[0,3,2,1], [4,5,6,7], [0,4,7,3], [1,2,6,5], [3,7,6,2], [0,1,5,4]]
    cf = part["cf"]
    matrix = np.array(cf[3:]).reshape((3,3))
    vertices = np.array(vertices) @ matrix.T + np.array(cf[:3])
    return vertices, faces


def font(size, bold=False):
    filename = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    candidates = [Path("/usr/share/fonts/truetype/dejavu") / filename, Path(filename)]
    for candidate in candidates:
        try:
            return ImageFont.truetype(str(candidate), size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def draw_model(image, parts, box, camera):
    width, height = box[2]-box[0], box[3]-box[1]
    tile = np.array(image.crop(box))
    depth = np.full((height,width), np.inf, dtype=np.float32)
    forward = unit(-np.array(camera))
    right = unit(np.cross(forward,(0,1,0)))
    up = np.cross(right,forward)
    projection = np.array([right,-up,forward]).T
    light = unit((-0.5,0.9,-0.7))
    faces = []
    for part in parts:
        vertices, indices = mesh(part)
        for index in indices:
            points = vertices[index]
            normal = np.cross(points[1]-points[0],points[-1]-points[0])
            magnitude = np.linalg.norm(normal)
            if magnitude < 1e-10:
                continue
            normal /= magnitude
            # Keep lighting independent of any accidental triangle winding differences.
            if np.dot(normal,points.mean(axis=0)-np.array(part["cf"][:3])) < 0:
                normal = -normal
            brightness = 0.67+0.33*max(0,np.dot(normal,light))
            if part["neon"]:
                brightness = 1.12
            color = np.minimum(255,np.array(part["color"])*255*brightness)
            faces.append((points @ projection,color,part["alpha"]))
    coordinates = np.concatenate([face[0] for face in faces])
    lower, upper = coordinates.min(axis=0), coordinates.max(axis=0)
    # Fixed scale across outfits preserves silhouette comparisons.
    scale = min((width-26)/4.5,(height-25)/7.3)
    ox = width/2 - (lower[0]+upper[0])*scale/2
    oy = height-10-upper[1]*scale
    for points, color, alpha in sorted(faces,key=lambda f:f[0][:,2].mean(),reverse=True):
        projected = [(ox+p[0]*scale,oy+p[1]*scale,p[2]) for p in points]
        for i in range(1,len(projected)-1):
            a,b,c = projected[0],projected[i],projected[i+1]
            x0 = max(0,math.floor(min(a[0],b[0],c[0])))
            x1 = min(width-1,math.ceil(max(a[0],b[0],c[0])))
            y0 = max(0,math.floor(min(a[1],b[1],c[1])))
            y1 = min(height-1,math.ceil(max(a[1],b[1],c[1])))
            if x0>x1 or y0>y1:
                continue
            denominator = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(denominator)<1e-9:
                continue
            yy,xx = np.mgrid[y0:y1+1,x0:x1+1]
            u = ((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/denominator
            v = ((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/denominator
            w = 1-u-v
            zz = u*a[2]+v*b[2]+w*c[2]
            current = depth[y0:y1+1,x0:x1+1]
            mask = (u>=0)&(v>=0)&(w>=0)&(zz<current)
            current[mask] = zz[mask]
            pixels = tile[y0:y1+1,x0:x1+1]
            pixels[mask] = (color*(1-alpha)+pixels[mask]*alpha).astype(np.uint8)
    image.paste(Image.fromarray(tile),box[:2])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",type=Path,default=ROOT/".tooling/character-geometry.json")
    parser.add_argument("--output",type=Path,default=ROOT/"docs/Character-lineup.png")
    args = parser.parse_args()
    scene = json.loads(args.input.read_text())
    specimens = scene["specimens"]
    assert len(specimens)==8,"The comparison sheet expects seven outfits and a Hunter comparison"
    width,height = 2382,1370
    image = Image.new("RGB",(width,height),(12,20,35))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((43,34,53,106),radius=4,fill=(74,224,216))
    draw.text((72,32),"CATCH ME IF YOU CAN",font=font(39,True),fill=(240,244,250))
    draw.text((74,84),"CHARACTER SILHOUETTE + FIT REVIEW",font=font(18),fill=(139,178,195))
    accents = [(75,221,211),(250,118,111),(165,215,242),(152,219,151),(182,143,232),(239,198,94),(90,222,231),(231,113,130)]
    for i,specimen in enumerate(specimens):
        x,y = 36+(i%4)*582,133+(i//4)*566
        draw.rounded_rectangle((x,y,x+564,y+548),radius=19,fill=(21,33,51),outline=(43,61,81),width=2)
        draw.rounded_rectangle((x+23,y+25,x+29,y+72),radius=3,fill=accents[i])
        draw.text((x+43,y+23),specimen["title"],font=font(23,True),fill=(237,242,247))
        draw.text((x+43,y+57),specimen["subtitle"],font=font(15),fill=(152,176,193))
        draw.line((x+21,y+501,x+543,y+501),fill=(57,78,95),width=2)
        draw_model(image,specimen["parts"],(x+8,y+80,x+282,y+499),(0,0.4,-10))
        draw_model(image,specimen["parts"],(x+282,y+80,x+556,y+499),(-5,1.0,-10))
        draw = ImageDraw.Draw(image)
        draw.text((x+92,y+515),"FRONT",font=font(13,True),fill=(124,157,178))
        draw.text((x+360,y+515),"3/4 VIEW",font=font(13,True),fill=(124,157,178))
    draw.text((41,1283),"GEOMETRY PREVIEW — NOT ROBLOX STUDIO RENDERING",font=font(20,True),fill=(90,220,213))
    draw.text((41,1319),"Actual Appearance.BuildPreview geometry. Head meshes approximated. Materials, role outlines, VFX and lighting require Studio review.",font=font(16),fill=(149,171,190))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    image.save(args.output)
    print(args.output)


if __name__=="__main__":
    main()
