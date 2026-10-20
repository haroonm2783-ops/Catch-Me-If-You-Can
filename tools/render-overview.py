"""Optional geometric overview from the exact baked map; not a Studio screenshot.
Requires Pillow and NumPy. Run tools/build.sh first to refresh dist/map-geometry.json.
"""
import json
import math
import numpy as np
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
scene = json.loads((ROOT / 'dist/map-geometry.json').read_text())
W, H = 1800, 1400

def add(a, b): return tuple(x+y for x,y in zip(a,b))
def sub(a, b): return tuple(x-y for x,y in zip(a,b))
def mul(a, n): return tuple(x*n for x in a)
def dot(a, b): return sum(x*y for x,y in zip(a,b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a,1/math.sqrt(dot(a,a)))

camera=(310,270,400)
forward=unit(sub((0,14,25),camera))
right=unit(cross(forward,(0,1,0)))
up=cross(right,forward)
light=unit((-0.5,1,0.6))
def project(v): return (dot(v,right),-dot(v,up),dot(v,forward))
def transform(v,cf):
    return (cf[0]+dot(cf[3:6],v),cf[1]+dot(cf[6:9],v),cf[2]+dot(cf[9:12],v))

def mesh(part):
    x,y,z=(s/2 for s in part['size'])
    if part['shape']=='Cylinder':
        n=12
        vertices=[(side*x,math.cos(i*2*math.pi/n)*y,math.sin(i*2*math.pi/n)*z) for side in (-1,1) for i in range(n)]
        faces=[list(range(n-1,-1,-1)),list(range(n,2*n))]
        faces += [[i,(i+1)%n,(i+1)%n+n,i+n] for i in range(n)]
    elif part['shape']=='Ball':
        n,m=10,6
        vertices=[]
        for j in range(m+1):
            lat=-math.pi/2+j*math.pi/m
            for i in range(n):
                a=i*2*math.pi/n
                vertices.append((math.cos(lat)*math.cos(a)*x,math.sin(lat)*y,math.cos(lat)*math.sin(a)*z))
        faces=[[j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i] for j in range(m) for i in range(n)]
    elif part['shape']=='Wedge':
        vertices=[(-x,-y,-z),(x,-y,-z),(-x,-y,z),(x,-y,z),(-x,y,z),(x,y,z)]
        faces=[[0,2,3,1],[2,4,5,3],[0,1,5,4],[0,4,2],[1,3,5]]
    else:
        vertices=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        faces=[[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]
    return [transform(v,part['cf']) for v in vertices],faces

faces=[]; all_points=[]
for part in scene['parts']:
    if part['name']=='CityBelow': continue
    vertices,indices=mesh(part)
    all_points.extend(project(v) for v in vertices)
    for indices_ in indices:
        vs=[vertices[i] for i in indices_]
        normal=cross(sub(vs[1],vs[0]),sub(vs[-1],vs[0]))
        if dot(normal,normal)<1e-12: continue
        normal=unit(normal)
        if dot(normal,forward)>=0 and part['alpha']<0.3: continue
        strength=0.76+0.24*max(0,dot(normal,light))
        if part['neon']: strength=1.13
        color=tuple(min(255,int(v*255*strength)) for v in part['color'])
        coords=[project(v) for v in vs]
        faces.append((sum(p[2] for p in coords)/len(coords),coords,color,part['alpha']))
xs=[p[0] for p in all_points];ys=[p[1] for p in all_points]
scale=min((W-110)/(max(xs)-min(xs)),(H-240)/(max(ys)-min(ys)))
ox=(W-(max(xs)+min(xs))*scale)/2
oy=155-min(ys)*scale

def screen(p): return (int(ox+p[0]*scale),int(oy+p[1]*scale))
image=Image.new('RGB',(W,H))
d=ImageDraw.Draw(image)
for y in range(H):
    t=y/H
    d.line((0,y,W,y),fill=(int(13+12*t),int(22+17*t),int(40+20*t)))
# A depth buffer keeps a large street polygon from painting over distant roofs.
pixels=np.array(image)
depth=np.full((H,W),np.inf,dtype=np.float32)
for _,points,color,alpha in sorted(faces,reverse=True,key=lambda a:a[0]):
    projected=[(ox+p[0]*scale,oy+p[1]*scale,p[2]) for p in points]
    for i in range(1,len(projected)-1):
        a,b,c=projected[0],projected[i],projected[i+1]
        minx=max(0,int(min(a[0],b[0],c[0])));maxx=min(W-1,int(max(a[0],b[0],c[0]))+1)
        miny=max(0,int(min(a[1],b[1],c[1])));maxy=min(H-1,int(max(a[1],b[1],c[1]))+1)
        if minx>=maxx or miny>=maxy: continue
        divisor=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(divisor)<0.00001: continue
        yy,xx=np.mgrid[miny:maxy+1,minx:maxx+1]
        u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/divisor
        v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/divisor
        w=1-u-v
        zz=u*a[2]+v*b[2]+w*c[2]
        current=depth[miny:maxy+1,minx:maxx+1]
        mask=(u>=0)&(v>=0)&(w>=0)&(zz<current)
        current[mask]=zz[mask]
        tile=pixels[miny:maxy+1,minx:maxx+1]
        if alpha>0: tile[mask]=(np.array(color)*(1-alpha)+tile[mask]*alpha).astype(np.uint8)
        else: tile[mask]=color
image=Image.fromarray(pixels)
d=ImageDraw.Draw(image)
fontbase=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
boldbase=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
def font(size,bold=False): return ImageFont.truetype(str(boldbase if bold else fontbase),size)
d.rounded_rectangle((58,49,70,105),radius=5,fill=(77,239,229))
d.text((91,43),'NEON HEIGHTS',font=font(43,True),fill=(239,244,248))
d.text((93,98),'CATCH ME IF YOU CAN  /  THE CITY CHASE CIRCUIT',font=font(16),fill=(147,183,198))
# Landmark callouts are an architectural guide; they are not game UI overlays.
labels=[((-88,30,-80),'01  CITRUS ARCADE'),((-85,33,51),'02  MOON NOODLE'),((79,43,-84),'03  CLOUD GARDEN'),((88,28,60),'04  POLAR LAUNDRY'),((0,28,81),'05  EMBER MARKET'),((0,68,-91),'06  MERIDIAN'),((0,25,258),'SOCIAL DECK + PODIUMS')]
for point,text in labels:
    x,y=screen(project(point));f=font(13,True)
    box=d.textbbox((0,0),text,font=f);width=box[2]+20
    d.rounded_rectangle((x-width/2,y-27,x+width/2,y-3),radius=6,fill=(14,27,44),outline=(66,131,145))
    d.text((x-width/2+10,y-24),text,font=f,fill=(224,246,242))
part_count=scene.get('partCount',len(scene['parts']))
route_count=scene.get('routes',12)
d.text((62,H-62),f'{part_count:,} AUTHORED PARTS     /     {route_count} BRIDGE + RAMP ROUTES     /     6 ROOFTOP DISTRICTS',font=font(17,True),fill=(91,223,215))
d.text((62,H-32),'Geometric overview generated from the baked place. Lighting and rendering must be reviewed in Roblox Studio.',font=font(13),fill=(145,166,187))
output=ROOT/'docs/city-backup-overview.png'
image.save(output)
print(output)
