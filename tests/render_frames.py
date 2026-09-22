"""Render the integration harness's real terminal cells, including CC mosaics.
Run texlua tests/workspace.lua first. Requires Pillow; for local visual review.
"""
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont

NAMES = ['white','orange','magenta','lightBlue','yellow','lime','pink','gray',
         'lightGray','cyan','purple','blue','brown','green','red','black']
palette = [0] * 16
for name, value in re.findall(r'\[colors\.(\w+)\] = (0x[0-9a-f]+)', Path('src/ui/fluent.lua').read_text()):
    palette[NAMES.index(name)] = int(value, 16)
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 17)

def render(name):
    rows = Path('/tmp/linkos-' + name + '.frame').read_bytes().split(b'\n')
    width, height = len(rows[0]), (len(rows)-1)//3
    image = Image.new('RGB', (width*12, height*24))
    draw = ImageDraw.Draw(image)
    for y in range(height):
        text, fg, bg = rows[y*3:y*3+3]
        for x, ch in enumerate(text):
            back = '#%06x' % palette[int(chr(bg[x]), 16)]
            front = '#%06x' % palette[int(chr(fg[x]), 16)]
            draw.rectangle((x*12,y*24,x*12+11,y*24+23), fill=back)
            if 128 <= ch <= 159:
                for bit in range(5):
                    if (ch-128) & (1 << bit):
                        xx, yy = x*12 + bit%2*6, y*24 + bit//2*8
                        draw.rectangle((xx,yy,xx+5,yy+7),fill=front)
            elif ch != 32:
                draw.text((x*12+1,y*24+1), chr(ch),font=font,fill=front)
    return image

if __name__ == '__main__':
    render('desktop-clean').save('docs/desktop-0.24-preview.png')
    names = ['desktop-clean','launcher','settings','files']
    sheet = Image.new('RGB',(1224,912))
    for i, name in enumerate(names):
        sheet.paste(render(name),((i%2)*612,(i//2)*456))
    sheet.save('docs/interface-0.24-preview.png')
