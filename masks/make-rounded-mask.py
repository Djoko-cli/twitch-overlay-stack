#!/usr/bin/env python3
"""Génère un masque PNG (rectangle arrondi, blanc opaque dedans / transparent
dehors) pour le filtre natif "Image Mask/Blend" d'OBS — la façon la plus
simple de donner un radius à une source vidéo sans plugin ni shader.

Usage :
    python3 make-rounded-mask.py [largeur] [hauteur] [rayon] [sortie.png]

Défauts : 1920 1080 32 rounded-1920x1080-r32.png
(32px = --radius-xl, le même rayon que le reste de la stack CSS, pour rester
visuellement cohérent si tu appliques ça à côté des autres overlays)

Suréchantillonne à 4x puis redimensionne, pour un bord anti-crénelé propre au
lieu d'un contour en escalier.
"""
import sys
from PIL import Image, ImageDraw

W = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
R = int(sys.argv[3]) if len(sys.argv) > 3 else 32
OUT = sys.argv[4] if len(sys.argv) > 4 else f"rounded-{W}x{H}-r{R}.png"

SS = 4  # supersampling pour l'anti-aliasing des coins
big = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
draw = ImageDraw.Draw(big)
draw.rounded_rectangle(
    [0, 0, W * SS - 1, H * SS - 1],
    radius=R * SS,
    fill=(255, 255, 255, 255),
)
mask = big.resize((W, H), Image.LANCZOS)
mask.save(OUT)
print(f"écrit : {OUT} ({W}x{H}, rayon {R}px)")
