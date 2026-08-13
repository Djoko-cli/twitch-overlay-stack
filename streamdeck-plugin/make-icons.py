#!/usr/bin/env python3
"""Génère toutes les icônes requises par le manifest — tailles et zones
transparentes exactes d'après le schéma officiel (@elgato/schemas), pas
devinées. Relance si tu changes le style visuel.
"""
from PIL import Image, ImageDraw
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "com.majid.twitch-server-control.sdPlugin", "imgs")
SS = 4  # supersampling


def circle(size, color, ring_only=False, ring_width_frac=0.12):
    big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    pad = size * SS * 0.08
    box = [pad, pad, size * SS - pad, size * SS - pad]
    if ring_only:
        d.ellipse(box, outline=color, width=int(size * SS * ring_width_frac))
    else:
        d.ellipse(box, fill=color)
    return big.resize((size, size), Image.LANCZOS)


def bolt_monochrome(size):
    """Icône simple, monochrome blanc sur transparent (action list / category)."""
    big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    s = size * SS
    # forme d'éclair stylisée
    pts = [
        (s * 0.56, s * 0.08), (s * 0.22, s * 0.58), (s * 0.46, s * 0.58),
        (s * 0.40, s * 0.92), (s * 0.80, s * 0.40), (s * 0.54, s * 0.40),
    ]
    d.polygon(pts, fill=(255, 255, 255, 255))
    return big.resize((size, size), Image.LANCZOS)


def save2x(img_fn, base_path, size):
    img_fn(size).save(f"{base_path}.png")
    img_fn(size * 2).save(f"{base_path}@2x.png")
    print(f"écrit : {base_path}.png (+@2x)")


# ---- État du bouton : rond plein, couleur pleine (72 / 144) --------------
os.makedirs(f"{ROOT}/actions/toggle", exist_ok=True)
save2x(lambda s: circle(s, (150, 150, 150, 255)), f"{ROOT}/actions/toggle/state-stopped", 72)
save2x(lambda s: circle(s, (60, 200, 110, 255)), f"{ROOT}/actions/toggle/state-running", 72)

# ---- Icône de la liste d'actions : monochrome (20 / 40) -------------------
save2x(bolt_monochrome, f"{ROOT}/actions/toggle/icon", 20)

# ---- Icône de catégorie : monochrome (28 / 56) -----------------------------
os.makedirs(f"{ROOT}/plugin", exist_ok=True)
save2x(bolt_monochrome, f"{ROOT}/plugin/category-icon", 28)

# ---- Icône marketplace (256 / 512) — un peu plus travaillée ---------------
def marketplace(size):
    big = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.18, fill=(20, 16, 28, 255))
    bolt = bolt_monochrome(int(size * 0.55))
    big.paste(bolt, (int(size * 0.225), int(size * 0.225)), bolt)
    return big

marketplace(256).save(f"{ROOT}/plugin/marketplace.png")
marketplace(512).save(f"{ROOT}/plugin/marketplace@2x.png")
print(f"écrit : {ROOT}/plugin/marketplace.png (+@2x)")
