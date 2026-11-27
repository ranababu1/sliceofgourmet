"""Builds launch screen assets from assets/branding/sog-logo-1024.png.

Run from the repo root: python3 tool/gen_splash.py
Needs Pillow, numpy and Playfair Display (static or variable TTF).
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(ROOT, 'assets/branding/sog-logo-1024.png')
FONT = os.path.join(ROOT, 'assets/fonts/PlayfairDisplay-Variable.ttf')
PREVIEW = sys.argv[1] if len(sys.argv) > 1 else None

LIGHT_BG = (0xFF, 0xFD, 0xF9)   # Brand.paper
DARK_BG = (0x17, 0x16, 0x14)    # Brand.darkPaper
LIGHT_TEXT = (0x2A, 0x73, 0x48)  # Brand.herb
DARK_TEXT = (0x6F, 0xCF, 0x97)   # Brand.herbLight

LOGO_PT = 160      # logo width in pt/dp inside the composite
TEXT_PT = 23       # title size in pt/dp
GAP_PT = 18        # space between logo and title


def keyed_logo():
    """Logo with its flat off-white background turned transparent."""
    a = np.asarray(Image.open(LOGO).convert('RGB')).astype(float)
    bg = np.median(np.concatenate([a[:8, :8], a[-8:, -8:]]).reshape(-1, 3), 0)
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    alpha = np.clip((d - 6) / 30, 0, 1)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha[..., None]) * bg) / safe, 0, 255)
    img = Image.fromarray(np.dstack([rgb, alpha * 255]).astype('uint8'), 'RGBA')
    x0, y0, x1, y1 = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
    return img.crop(box)


def font(px):
    f = ImageFont.truetype(FONT, px)
    try:
        f.set_variation_by_axes([600])
    except Exception:
        pass
    return f


def composite(logo, scale, text_rgb):
    """Logo with title below, padded so the logo sits at the vertical centre."""
    lw = LOGO_PT * scale
    f = font(TEXT_PT * scale)
    title = 'Slice of Gourmet'
    tb = f.getbbox(title)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    w = max(lw, tw) + 4 * scale
    below = GAP_PT * scale + th + 2 * scale
    h = lw + 2 * below
    img = Image.new('RGBA', (int(w), int(h)), (0, 0, 0, 0))
    lg = logo.resize((int(lw), int(lw)), Image.LANCZOS)
    img.alpha_composite(lg, (int((w - lw) / 2), int(below)))
    d = ImageDraw.Draw(img)
    d.text(((w - tw) / 2 - tb[0], below + lw + GAP_PT * scale - tb[1]), title, font=f, fill=text_rgb + (255,))
    return img


def android12_icon(logo, px):
    """288dp canvas, artwork kept inside the 192dp circle."""
    a = np.asarray(logo.getchannel('A')).astype(float)
    ys, xs = np.where(a > 8)
    c = logo.width / 2
    r = np.sqrt((xs - c) ** 2 + (ys - c) ** 2).max()   # art radius in logo px
    target_r = px * (192 / 288) / 2 * 0.96
    size = int(logo.width * target_r / r)
    img = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    img.alpha_composite(logo.resize((size, size), Image.LANCZOS), ((px - size) // 2, (px - size) // 2))
    return img


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def main():
    logo = keyed_logo()
    ios = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/LaunchImage.imageset')
    for f in os.listdir(ios):
        if f.endswith('.png'):
            os.remove(os.path.join(ios, f))
    images = []
    for s in (1, 2, 3):
        sfx = '' if s == 1 else f'@{s}x'
        for mode, col in (('', LIGHT_TEXT), ('Dark', DARK_TEXT)):
            name = f'LaunchImage{mode}{sfx}.png'
            save(composite(logo, s, col), os.path.join(ios, name))
            e = {'idiom': 'universal', 'filename': name, 'scale': f'{s}x'}
            if mode:
                e['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
            images.append(e)
    json.dump({'images': images, 'info': {'version': 1, 'author': 'xcode'}},
              open(os.path.join(ios, 'Contents.json'), 'w'), indent=2)

    res = os.path.join(ROOT, 'android/app/src/main/res')
    for q, s in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
        save(composite(logo, s, LIGHT_TEXT), f'{res}/drawable-{q}/launch_image.png')
        save(composite(logo, s, DARK_TEXT), f'{res}/drawable-night-{q}/launch_image.png')
        save(android12_icon(logo, int(288 * s)), f'{res}/drawable-{q}/android12_splash.png')

    c1 = composite(logo, 1, LIGHT_TEXT)
    ratio = c1.width / LOGO_PT
    print(f'composite {c1.width}x{c1.height}pt, width/logo={ratio:.4f}')

    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        W, H, S = 1290, 2796, 3   # iPhone 6.7in at 3x, 430x932pt
        for name, bg, col in (('launch-ios-light.png', LIGHT_BG, LIGHT_TEXT),
                              ('launch-ios-dark.png', DARK_BG, DARK_TEXT)):
            scr = Image.new('RGBA', (W, H), bg + (255,))
            comp = composite(logo, S, col)
            tw = int(W * 0.40 * ratio)
            comp = comp.resize((tw, int(comp.height * tw / comp.width)), Image.LANCZOS)
            scr.alpha_composite(comp, ((W - comp.width) // 2, (H - comp.height) // 2))
            scr.convert('RGB').save(os.path.join(PREVIEW, name))
        # Android 12: 1080x2400 at 2.625x would be typical; use 3x on the same canvas.
        scr = Image.new('RGBA', (W, H), LIGHT_BG + (255,))
        icon = android12_icon(logo, 288 * S)
        mask = Image.new('L', icon.size, 0)
        r = icon.width * (192 / 288) / 2
        c = icon.width / 2
        ImageDraw.Draw(mask).ellipse((c - r, c - r, c + r, c + r), fill=255)
        icon.putalpha(Image.fromarray(np.minimum(np.asarray(icon.getchannel('A')), np.asarray(mask))))
        scr.alpha_composite(icon, ((W - icon.width) // 2, (H - icon.height) // 2))
        scr.convert('RGB').save(os.path.join(PREVIEW, 'launch-android12.png'))


if __name__ == '__main__':
    main()
