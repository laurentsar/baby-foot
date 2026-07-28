#!/usr/bin/env python3
# Genere les 6 icones de game pass, meme identite visuelle que l'icone du jeu.
import os

OUT = os.path.dirname(os.path.abspath(__file__))

HEAD = '''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{c1}"/>
      <stop offset="1" stop-color="#070B1C"/>
    </linearGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFE886"/>
      <stop offset="1" stop-color="#EFA315"/>
    </linearGradient>
    <linearGradient id="silver" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F6F9FF"/>
      <stop offset="1" stop-color="#9AA6BF"/>
    </linearGradient>
    <radialGradient id="halo" cx="0.5" cy="0.42" r="0.55">
      <stop offset="0" stop-color="{glow}" stop-opacity="0.55"/>
      <stop offset="1" stop-color="{glow}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="vig" cx="0.5" cy="0.42" r="0.78">
      <stop offset="0.55" stop-color="#000000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0.5"/>
    </radialGradient>
  </defs>
  <rect width="512" height="512" fill="url(#bg)"/>
  <circle cx="256" cy="215" r="200" fill="url(#halo)"/>
'''

FOOT = '''  <rect width="512" height="512" fill="url(#vig)"/>
  <g font-family="DejaVu Sans" font-weight="bold" text-anchor="middle">
    <text x="256" y="{ly}" font-size="{ls}" fill="{lc}" stroke="#08122E" stroke-width="11"
          paint-order="stroke" letter-spacing="1">{label}</text>
  </g>
</svg>
'''

def star(cx, cy, r, fill):
    import math
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = r if i % 2 == 0 else r * 0.44
        pts.append(f"{cx + rad * math.cos(ang):.1f},{cy + rad * math.sin(ang):.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="#3A1F00" stroke-width="10" stroke-linejoin="round"/>'

def pips(x, y, size, layout):
    """Points d'un de, positions relatives au carre (x,y,size)."""
    g = ""
    third = size / 4
    coords = {
        "tl": (x + third, y + third), "tr": (x + 3 * third, y + third),
        "ml": (x + third, y + 2 * third), "mr": (x + 3 * third, y + 2 * third),
        "c":  (x + 2 * third, y + 2 * third),
        "bl": (x + third, y + 3 * third), "br": (x + 3 * third, y + 3 * third),
    }
    for k in layout:
        px, py = coords[k]
        g += f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{size*0.09:.0f}" fill="#16203E"/>'
    return g

PASSES = {}

# ---- VIP : etoile doree
PASSES["vip"] = dict(c1="#3B2C6E", glow="#FFD86B", label="VIP", ls=104, ly=452, lc="url(#gold)",
    body=star(256, 210, 150, "url(#gold)") + '''
    <text x="256" y="238" font-family="DejaVu Sans" font-weight="bold" font-size="86"
          text-anchor="middle" fill="#3A1F00">x2</text>''')

# ---- Argent x2 : piece
PASSES["moneyx2"] = dict(c1="#1F4C2E", glow="#8CF0A8", label="ARGENT", ls=76, ly=452, lc="#FFFFFF",
    body='''<circle cx="256" cy="206" r="132" fill="url(#gold)" stroke="#3A1F00" stroke-width="12"/>
    <circle cx="256" cy="206" r="104" fill="none" stroke="#3A1F00" stroke-width="7" stroke-opacity="0.45"/>
    <text x="256" y="252" font-family="DejaVu Sans" font-weight="bold" font-size="150"
          text-anchor="middle" fill="#3A1F00">$</text>
    <text x="392" y="330" font-family="DejaVu Sans" font-weight="bold" font-size="96"
          text-anchor="middle" fill="#FFFFFF" stroke="#08122E" stroke-width="12"
          paint-order="stroke">x2</text>''')

# ---- Renaissance x2 : fleche circulaire
PASSES["rebirthx2"] = dict(c1="#5A1F55", glow="#FF9BE0", label="RENAISSANCE", ls=52, ly=452, lc="#FFFFFF",
    body='''<path d="M256 84 a122 122 0 1 1 -110 69" fill="none" stroke="#FF78CE"
          stroke-width="34" stroke-linecap="round"/>
    <polygon points="256,40 256,128 322,84" fill="#FF78CE"/>
    <text x="256" y="248" font-family="DejaVu Sans" font-weight="bold" font-size="112"
          text-anchor="middle" fill="#FFFFFF" stroke="#4A0F3E" stroke-width="12"
          paint-order="stroke">x2</text>''')

# ---- Des Chanceux : deux des
PASSES["luckydice"] = dict(c1="#26356F", glow="#9FD8FF", label="DES CHANCEUX", ls=48, ly=452, lc="#FFFFFF",
    body='<g transform="rotate(-14 190 220)"><rect x="118" y="148" width="150" height="150" rx="30"'
         ' fill="url(#silver)" stroke="#16203E" stroke-width="10"/>'
         + pips(118, 148, 150, ["tl", "c", "br"]) + '</g>'
         '<g transform="rotate(12 330 250)"><rect x="256" y="180" width="150" height="150" rx="30"'
         ' fill="url(#gold)" stroke="#3A1F00" stroke-width="10"/>'
         + pips(256, 180, 150, ["tl", "tr", "ml", "mr", "bl", "br"]) + '</g>')

# ---- Vitesse Balle x2 : ballon + trainee
PASSES["ballspeedx2"] = dict(c1="#123E63", glow="#8FE9FF", label="VITESSE BALLE", ls=48, ly=452, lc="#FFFFFF",
    body='''<path d="M40 172 L210 172 L232 208 L18 208 Z" fill="#8FE9FF" opacity="0.45"/>
    <path d="M70 232 L200 232 L218 262 L52 262 Z" fill="#8FE9FF" opacity="0.28"/>
    <circle cx="312" cy="212" r="118" fill="#FFFFFF" stroke="#16203E" stroke-width="10"/>
    <path d="M312 122 l58 42 -22 68 -72 0 -22 -68 z" fill="#16203E"/>
    <path d="M312 102 l0 20 M234 184 l-38 -14 M390 184 l38 -14 M268 272 l-22 42 M356 272 l22 42"
          stroke="#16203E" stroke-width="15" stroke-linecap="round" fill="none"/>
    <text x="418" y="340" font-family="DejaVu Sans" font-weight="bold" font-size="92"
          text-anchor="middle" fill="#FFFFFF" stroke="#08122E" stroke-width="12"
          paint-order="stroke">x2</text>''')

# ---- Grand Terrain : cage elargie
PASSES["bigfield"] = dict(c1="#1B5E3A", glow="#8CF0A8", label="GRAND TERRAIN", ls=48, ly=452, lc="#FFFFFF",
    body='''<g stroke="#F2F5FA" stroke-width="24" fill="none" stroke-linecap="round">
      <path d="M96 300 L96 132 L416 132 L416 300"/>
    </g>
    <g stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="5">
      <path d="M136 132 L136 300 M176 132 L176 300 M216 132 L216 300 M256 132 L256 300
               M296 132 L296 300 M336 132 L336 300 M376 132 L376 300"/>
      <path d="M96 172 L416 172 M96 212 L416 212 M96 252 L416 252"/>
    </g>
    <g stroke="url(#gold)" stroke-width="20" fill="none" stroke-linecap="round">
      <path d="M74 342 L36 342"/><path d="M438 342 L476 342"/>
    </g>
    <polygon points="30,342 66,322 66,362" fill="url(#gold)"/>
    <polygon points="482,342 446,322 446,362" fill="url(#gold)"/>''')

for key, p in PASSES.items():
    svg = HEAD.format(c1=p["c1"], glow=p["glow"]) + p["body"] + "\n" + FOOT.format(
        label=p["label"], ls=p["ls"], ly=p["ly"], lc=p["lc"])
    path = os.path.join(OUT, f"pass-{key}.svg")
    open(path, "w", encoding="utf-8").write(svg)
    print("ecrit", os.path.basename(path))
