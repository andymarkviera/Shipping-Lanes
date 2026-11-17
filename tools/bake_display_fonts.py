"""Bake Andy's sheets into BMFont atlases; Python + Pillow + numpy, no runtime work.
Sources already have alpha. Opaque white backgrounds are keyed by flood fill only,
so white letter interiors survive. Missing coloured glyphs tint the white sheet.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'features/ui/fonts'
OUT.mkdir(exist_ok=True)

def sheet(name):
    im = Image.open(ROOT / f'docs/reference/patch_2_9_1/font_sheet_{name}.png').convert('RGBA')
    if im.getpixel((0, 0))[3] == 255:
        ImageDraw.floodfill(im, (0, 0), (0, 0, 0, 0), thresh=40)
    return im

def slice_rows(im, ys, rows):
    result = {}
    a = np.array(im)
    for lo, hi, letters in zip(ys, ys[1:], rows):
        used = (a[lo:hi, :, 3] > 128).sum(axis=0) > 3
        runs, start = [], None
        for x, v in enumerate(list(used) + [False]):
            if v and start is None: start = x
            if not v and start is not None:
                if x - start > 10: runs.append((start, x))
                start = None
        if letters == 'ABCDEFGH':
            # G/H share the middle stroke: retain it in both independent cells.
            runs[-1:] = [(943, 1035), (1009, 1100)]
        assert len(runs) == len(letters), (letters, runs)
        for ch, (left, right) in zip(letters, runs):
            glyph = im.crop((max(0, left-2), lo, min(im.width, right+2), hi))
            mask = glyph.getchannel('A').point(lambda p: 255 if p > 128 else 0)
            result[ch] = glyph.crop(mask.getbbox())
    return result

white = slice_rows(sheet('white_navy'), [0,170,333,473,615,742,875,1024],
                   ['ABCDEFGHIJ','KLMNOPQRST','UVWXYZabcd','efghijklmn','opqrstuvwx','yz01234567','89!?.,:;+-'])
colour = sheet('red_gold')
red = slice_rows(colour, [0,166,318,482,630,778], ['ABCDEFGH','IJKLMNO','QRSTUWX','YZ01235','6789!?:'])
gold = slice_rows(colour, [778,900,1016,1142,1270,1402], ['ABCDEFH','IJKLMNP','QRSTUWX','YZ01235','6789!?:'])
# Additional ASCII punctuation from the same rounded strokes; readable fallbacks
# cover unusual Unicode through Godot's existing body font.
for ch in "\"#$%&'()*/<=>@[\\]^_`{|}~":
    tile = Image.new('RGBA', (100,140))
    d = ImageDraw.Draw(tile)
    # Use a serif raster for rare punctuation only, then match sheet ink/shadow.
    from PIL import ImageFont
    f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-BoldItalic.ttf', 90)
    d.text((8,5), ch, font=f, fill='white', stroke_width=7, stroke_fill='#071c39')
    white[ch] = tile.crop(tile.getbbox())

def tinted(im, kind):
    a = np.array(im).copy()
    light = a[:,:,:3].mean(axis=2) / 255.0
    base = np.array([255,201,40] if kind == 'gold' else [245,35,55])
    for i in range(3): a[:,:,i] = (base[i] * light).astype('uint8')
    return Image.fromarray(a)

def bake(kind, glyphs):
    atlas = Image.new('RGBA', (1536, 512))
    chars = []
    for n, code in enumerate(range(32,127)):
        ch = chr(code)
        if ch == ' ':
            chars.append(f'char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=18 page=0 chnl=15')
            continue
        source = ch.upper() if kind != 'white' and ch.islower() else ch
        im = glyphs.get(source)
        if im is None: im = tinted(white[source], kind)
        # Fit to the same cap height. Lowercase retains the white sheet's proportions.
        scale = 52 / (140 if kind != 'gold' else 110)
        if kind != 'white' and source not in glyphs: scale = 52/140
        w, h = max(1,round(im.width*scale)), max(1,round(im.height*scale))
        im = im.resize((w,h), Image.Resampling.LANCZOS)
        x, y = (n%16)*96+2, (n//16)*80+2
        assert w <= 94 and h <= 70, (ch,w,h)
        atlas.alpha_composite(im,(x,y))
        baseline = 62 if ch in 'gjpqy' and kind == 'white' else 56
        chars.append(f'char id={code} x={x} y={y} width={w} height={h} xoffset=0 yoffset={baseline-h} xadvance={w+2} page=0 chnl=15')
    atlas.save(OUT / f'{kind}.png')
    (OUT/f'{kind}.fnt').write_text(f'info face="Andy {kind}" size=64 bold=0 italic=0 unicode=1\ncommon lineHeight=64 base=56 scaleW=1536 scaleH=512 pages=1 packed=0\npage id=0 file="{kind}.png"\nchars count={len(chars)}\n'+'\n'.join(chars)+'\nkernings count=0\n')
for kind,glyphs in [('white',white),('red',red),('gold',gold)]: bake(kind,glyphs)
print('Baked three atlases, 95 ASCII glyphs each; coloured lowercase aliases caps.')
