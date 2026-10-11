"""Sinh SVG icon app (2 lá bài xì dách A♠ + K♥) cho 3 biến thể:
full (nền xanh, cho legacy/iOS), foreground (nền trong suốt, adaptive), monochrome."""
import sys, os

HEART = "M50 88 C20 65 0 45 0 28 C0 12 12 0 27 0 C38 0 46 6 50 15 C54 6 62 0 73 0 C88 0 100 12 100 28 C100 45 80 65 50 88 Z"
SPADE = ("M50 0 C50 0 100 35 100 58 C100 74 88 84 74 84 C64 84 56 79 52 72 "
         "C53 84 58 94 66 100 L34 100 C42 94 47 84 48 72 C44 79 36 84 26 84 "
         "C12 84 0 74 0 58 C0 35 50 0 50 0 Z")

def suit(path, x, y, s, color):
    return f'<path d="{path}" fill="{color}" transform="translate({x} {y}) scale({s})"/>'

def letter_a(color, sw=20):
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M-122 -118 L-96 -182 L-70 -118"/><path d="M-112 -140 L-80 -140"/></g>')

def letter_k(color, sw=20):
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M-116 -182 L-116 -118"/><path d="M-80 -182 L-114 -146"/><path d="M-104 -157 L-78 -118"/></g>')

def card(face, ink, symbols, shadow, outline=False):
    out = []
    if shadow:
        out.append('<rect x="-138" y="-196" width="300" height="420" rx="34" fill="#000" fill-opacity="0.22"/>')
    stroke = ' stroke="#000" stroke-width="22"' if outline else ''
    out.append(f'<rect x="-150" y="-210" width="300" height="420" rx="34" fill="{face}"{stroke}/>')
    out += symbols(ink)
    return out

def back_symbols(ink):  # K♥
    return [letter_k(ink), suit(HEART, -121, -104, 0.42, ink), suit(HEART, -40, -30, 0.8, ink)]

def front_symbols(ink):  # A♠
    return [letter_a(ink), suit(SPADE, -117, -104, 0.42, ink),
            suit(SPADE, -78, -82, 1.56, ink),
            f'<g transform="rotate(180)">{letter_a(ink)}{suit(SPADE, -117, -104, 0.42, ink)}</g>']

def svg(variant):
    mono = variant == "monochrome"
    scale = {"full": 1.12, "foreground": 0.80, "monochrome": 0.80}[variant]
    face = "#FFFFFF"
    red = "#000000" if mono else "#E53935"
    black = "#000000" if mono else "#1F2328"
    shadow = not mono
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">']
    if variant == "full":
        parts.append('<rect width="1024" height="1024" fill="#33A13F"/>')
    parts.append(f'<g transform="translate(512 524) scale({scale})">')
    parts.append('<g transform="translate(-92 6) rotate(-14)">' + "".join(card(face, red, back_symbols, shadow)) + '</g>')
    parts.append('<g transform="translate(92 -6) rotate(12)">' + "".join(card(face, black, front_symbols, shadow, outline=mono)) + '</g>')
    parts.append('</g></svg>')
    return "\n".join(parts)

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for v in ("full", "foreground", "monochrome"):
        with open(os.path.join(out, f"icon_{v}.svg"), "w") as f:
            f.write(svg(v))
