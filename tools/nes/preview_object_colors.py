#!/usr/bin/env python3
"""Compare actual native cached pixels before/after with original NES CHR."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
from assets import ROM,RGB
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT.parents[1]/'outputs'
def main():
 before=json.loads((ROOT/'build/stable-items/before.json').read_text())['images'];after=json.loads((ROOT/'build/stable-items/after.json').read_text())['images'];chars=json.loads((ROOT/'build/nes_full/graphics.json').read_text())['chars'];rom=ROM((ROOT/'orig/nes/monty.nes').read_bytes())
 font='/System/Library/Fonts/Supplemental/Arial.ttf'
 f=ImageFont.truetype(font,17);small=ImageFont.truetype(font,14);title=ImageFont.truetype(font,22)
 names={'White key':'Белый ключ','Blue key':'Синий ключ','Red key':'Красный ключ','Sword':'Меч','Amulet':'Амулет','Torch 0':'Факел','Jewel':'Драгоценность','White door':'Белая','Blue door':'Синяя','Red door':'Красная','White arch':'Белая открыта','Blue arch':'Синяя открыта','Red arch':'Красная открыта'}
 groups=[[q for q in after if q['name'] in ['White key','Blue key','Red key','Sword','Amulet','Torch 0','Jewel']], [q for q in after if 'door' in q['name'] or 'arch' in q['name']]]
 width=940;im=Image.new('RGB',(width,1100),'#171b22');d=ImageDraw.Draw(im);d.text((24,16),'Постоянные цвета предметов и дверей',font=title,fill='white')
 d.text((24,49),'NES: исходные CHR; Вектор: реальные изображения из кэша ROM. Чёрный фон не показан в списке цветов.',font=small,fill='#aeb7c7')
 y=86
 for gi,group in enumerate(groups):
  d.text((24,y),'Предметы' if gi==0 else 'Двери',font=f,fill='#b7cdf6');y+=30
  x0=170;cw=(width-x0-15)//len(group);rh=112 if gi==0 else 146
  for i,q in enumerate(group):
   label=names[q['name']];box=d.textbbox((0,0),label,font=small);d.text((x0+i*cw+(cw-(box[2]-box[0]))//2,y),label,font=small,fill='#ccd3df')
  y+=27
  for version,label in [('nes','Оригинал NES'),('before','Было'),('after','Стало')]:
   d.text((24,y+rh//2-10),label,font=f,fill='white' if version=='after' else '#9ba7ba')
   for i,q in enumerate(group):
    obj=q if version=='after' else next(a for a in before if a['name']==q['name'])
    if version=='nes':
     pal=[0x0f,0x16,0x27,0x1c] if q['context']=='accent' else [0x0f,0x20,0x16,0x1c]
     w=q['cols']*8;h=len(q['tiles'])//q['cols']*8;pic=Image.new('RGB',(w,h))
     for j,t in enumerate(q['tiles']):
      nt=int(chars[str(t)])
      if t in (0xa8,0xae):nt=0x123+2*q['phase']+(t==0xae)
      pic.paste(rom.tile(nt,[RGB[c] for c in pal]),(j%q['cols']*8,j//q['cols']*8))
    else:
     p=obj['pixels'];pic=Image.new('RGB',(len(p[0]),len(p)));palette=obj['palette']
     pic.putdata([((palette[v]&7)*32,((palette[v]>>3)&7)*32,((palette[v]>>6)&3)*64) for row in p for v in row])
    scale=4 if gi==0 else 3;pic=pic.resize((pic.width*scale,pic.height*scale),Image.Resampling.NEAREST)
    px=x0+i*cw+(cw-pic.width)//2;py=y+(rh-pic.height)//2
    d.rounded_rectangle((x0+i*cw+3,y+3,x0+(i+1)*cw-3,y+rh-3),radius=6,fill='#080a0e')
    im.paste(pic,(px,py))
   y+=rh
  y+=23
 d.text((24,y),'Белый, телесный, красный и бирюзовый предметов теперь постоянны; акцент комнаты остаётся в кирпичах и HUD.',font=small,fill='#aeb7c7')
 OUT.mkdir(exist_ok=True);im.crop((0,0,width,min(y+40,im.height))).save(OUT/'stable-item-colors.png')
 print(OUT/'stable-item-colors.png')
if __name__=='__main__':main()
