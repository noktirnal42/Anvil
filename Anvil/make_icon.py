#!/usr/bin/env python3
"""Generate Anvil app icon (fallback: no image-gen credits)."""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageOps

def draw_anvil(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2

    # Radial gradient background: graphite -> warm clay at bottom
    for y in range(size):
        t = y / size  # 0 top -> 1 bottom
        r = int(26 * (1 - t) + 78 * t)
        g = int(27 * (1 - t) + 52 * t)
        b = int(30 * (1 - t) + 46 * t)
        d.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Soft vignette / glow behind anvil
    glow = Image.new("L", (size, size), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - size * 0.55, cy - size * 0.55, cx + size * 0.55, cy + size * 0.55], fill=200)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    # tint glow warm clay
    glow_rgba = Image.merge("RGBA", (
        Image.eval(glow.split()[0], lambda v: min(255, int(v * 0.6))),
        Image.eval(glow.split()[0], lambda v: min(255, int(v * 0.35))),
        Image.eval(glow.split()[0], lambda v: min(255, int(v * 0.18))),
        glow.split()[0]
    ))
    img = Image.alpha_composite(img, glow_rgba)
    d = ImageDraw.Draw(img)

    # --- Draw anvil ---
    # anvil base (pedestal)
    base_w = size * 0.42
    base_h = size * 0.16
    base_top = cy + size * 0.10
    d.rounded_rectangle(
        [cx - base_w/2, base_top, cx + base_w/2, base_top + base_h],
        radius=size * 0.03, fill=(60, 58, 62, 255)
    )
    # base highlight
    d.rounded_rectangle(
        [cx - base_w/2 + 4, base_top + 4, cx + base_w/2 - 4, base_top + base_h - 4],
        radius=size * 0.025, fill=(90, 86, 92, 255))

    # anvil body (main block)
    body_w = size * 0.62
    body_h = size * 0.34
    body_top = base_top - body_h
    d.rounded_rectangle(
        [cx - body_w/2, body_top, cx + body_w/2, base_top],
        radius=size * 0.02, fill=(45, 44, 48, 255)
    )
    # body bevel highlight (top rim)
    d.line([cx - body_w/2 + 8, body_top + 6, cx + body_w/2 - 8, body_top + 6],
           fill=(110, 108, 112, 255), width=6)
    # body dark side
    d.rectangle([cx + body_w/2 - size*0.04, body_top + size*0.03, cx + body_w/2, base_top - size*0.03],
                fill=(28, 27, 30, 255))

    # anvil top face (the working face), slightly lighter worn iron
    face_w = size * 0.52
    face_h = size * 0.07
    face_top = body_top - face_h
    d.rounded_rectangle(
        [cx - face_w/2, face_top, cx + face_w/2, face_top + face_h],
        radius=size * 0.02, fill=(78, 76, 80, 255)
    )
    # top face highlight rim
    d.line([cx - face_w/2 + 6, face_top + 4, cx + face_w/2 - 6, face_top + 4],
           fill=(150, 148, 152, 255), width=5)

    # horn (left side, pointing up-left)
    horn_w = size * 0.14
    horn_h = size * 0.10
    d.pieslice([cx - face_w/2 - horn_w, face_top - horn_h, cx - face_w/2 + horn_w, face_top + horn_h],
               180, 270, fill=(52, 50, 54, 255))
    d.arc([cx - face_w/2 - horn_w + 4, face_top - horn_h + 4, cx - face_w/2 + horn_w - 4, face_top + horn_h - 4],
          180, 270, fill=(130, 128, 132, 255), width=5)

    # --- Code glyph "</>" centered on the anvil face ---
    glyph_cx, glyph_cy = cx, face_top + face_h/2
    glyph_size = size * 0.17
    stroke = max(6, int(size * 0.007))
    # "<"
    d.line([(glyph_cx - glyph_size/2, glyph_cy - glyph_size/2),
            (glyph_cx, glyph_cy),
            (glyph_cx - glyph_size/2, glyph_cy + glyph_size/2)],
           fill=(255, 255, 255, 230), width=stroke)
    # "/"
    d.line([(glyph_cx + glyph_size/2, glyph_cy - glyph_size/2),
            (glyph_cx + glyph_size/2 - glyph_size/2, glyph_cy + glyph_size/2)],
           fill=(255, 255, 255, 230), width=stroke)
    # ">"
    d.line([(glyph_cx + glyph_size/2, glyph_cy - glyph_size/2),
            (glyph_cx + glyph_size, glyph_cy),
            (glyph_cx + glyph_size/2, glyph_cy + glyph_size/2)],
           fill=(255, 255, 255, 230), width=stroke)

    # soft drop shadow under anvil
    shadow = Image.new("L", (size, size), 0)
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([cx - body_w/2 - 10, base_top + base_h - 8, cx + body_w/2 + 10, base_top + base_h + 18], fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
    shadow_rgba = Image.merge("RGBA", (shadow, shadow, shadow, Image.eval(shadow, lambda v: v // 3)))
    # composite shadow beneath: re-render order—simply blend at bottom
    img = Image.alpha_composite(Image.new("RGBA", (size, size), (0,0,0,0)), img)
    return img

def main():
    src = draw_anvil(1024)
    outdir = "/Volumes/Artificial_Intelligence_Machine_Learning/dev/OpenCodeNext/Anvil/Sources/AnvilApp/Assets.xcassets/AppIcon.appiconset"
    # save master
    src.save(outdir + "/icon-1024.png")

    # derive all required macOS app icon sizes from master
    sizes = [16, 32, 128, 256, 512, 1024]
    scales = {"1x": 1, "2x": 2}
    entries = []
    for s in sizes:
        for scale_name, scale in scales.items():
            out_size = s * scale
            # filename unique per entry
            fname = f"icon-{s}{scale_name}.png"
            img = src.resize((out_size, out_size), Image.LANCZOS)
            img.save(outdir + "/" + fname)
            entries.append({
                "filename": fname,
                "idiom": "mac",
                "scale": scale_name,
                "size": f"{s}x{s}"
            })

    import json
    contents = {
        "images": entries,
        "info": {"author": "xcode", "version": 1},
        "properties": {"provides-app-icon": True}
    }
    with open(outdir + "/Contents.json", "w") as f:
        json.dump(contents, f, indent=2)
    print("generated", len(entries), "icon entries + Contents.json")

if __name__ == "__main__":
    main()
