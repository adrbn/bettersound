#!/usr/bin/env python3
"""Writes every SVG the README uses, from the real captures in readme-src/.

    python3 docs/assets/make_svgs.py

readme-src/ holds real captures of the BetterSound panel (panel-*.jpg, 2x, 300 x 311 pt)
and the SF Symbols the app shows, rendered by symbols.swift. Frames (menu bar, cards,
pills) are drawn; the app itself is never redrawn.
"""
import base64
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "readme-src")

ACCENT = "#FAC233"          # the app icon's and sliders' yellow
INK = "#0d1117"             # GitHub dark
CARD = "#161b22"
LINE = "#30363d"
FONT = "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Helvetica, Arial, sans-serif"
U = 8                        # spacing unit
PANEL_W, PANEL_H = 300, 311  # panel capture size in points
T = 12                       # hero loop, seconds


def uri(name):
    mime = "image/jpeg" if name.endswith(".jpg") else "image/png"
    with open(os.path.join(SRC, name), "rb") as f:
        return f"data:{mime};base64,{base64.b64encode(f.read()).decode()}"


def svg(w, h, body, title, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="{title}">'
            f'<title>{title}</title><defs>{defs}</defs>{body}</svg>\n')


def write(name, content):
    with open(os.path.join(HERE, name), "w") as f:
        f.write(content)
    print(f"{name}: {len(content) // 1024} KB")


def fade(values, times, dur=T):
    """Opacity animation; values and times (0..1) must start and end equal for a seamless loop."""
    return (f'<animate attributeName="opacity" dur="{dur}s" repeatCount="indefinite" calcMode="spline" '
            f'values="{";".join(map(str, values))}" keyTimes="{";".join(f"{t:.4f}" for t in times)}" '
            f'keySplines="{";".join(["0.42 0 0.58 1"] * (len(values) - 1))}"/>')


def panel_layers(x, y, w, crop=None, clip_id="p"):
    """The three real panel captures, crossfading A -> B -> C -> A. `crop` = (y0, y1) in points."""
    y0, y1 = crop or (0, PANEL_H)
    s = w / PANEL_W
    h = (y1 - y0) * s
    img = lambda n: (f'<image href="{uri(f"panel-{n}.jpg")}" x="0" y="{-y0 * s:.1f}" '
                     f'width="{w}" height="{PANEL_H * s:.1f}"/>')
    b = fade([0, 0, 1, 1, 0, 0], [0, 3 / T, 4 / T, 8 / T, 8.001 / T, 1])
    c = fade([0, 0, 1, 1, 0, 0], [0, 7 / T, 8 / T, 11 / T, 11.999 / T, 1])
    defs = f'<clipPath id="{clip_id}"><rect width="{w}" height="{h:.1f}" rx="{14 * s if not crop else 10}"/></clipPath>'
    body = (f'<g transform="translate({x} {y})" clip-path="url(#{clip_id})">{img("a")}'
            f'<g opacity="0">{b}{img("b")}</g><g opacity="0">{c}{img("c")}</g></g>')
    return defs, body, h


# ---------------------------------------------------------------- hero

def hero(light):
    w, h = 480, 384
    bar = 30
    desk = "#e6e7ec" if light else "#16181d"
    bar_fill = "#f6f6f8" if light else "#24262c"
    sym = "b" if light else "w"
    text_fill = "#111" if light else "#f2f2f2"

    # Menu bar, right side, in macOS order: ours sits where Apple's Sound item was.
    items = ["airpods.pro", "wifi", "battery.75percent", "magnifyingglass", "switch.2"]
    right = w - 16 - 118         # room for the clock
    xs, x = {}, right
    for name in reversed(items):
        x -= 30
        xs[name] = x
    ours = xs["airpods.pro"]
    icons = "".join(
        f'<image href="{uri(f"sym-{n}-{sym}.png")}" x="{xs[n] + 4}" y="{(bar - 15) / 2:.1f}" width="20" height="15" '
        f'preserveAspectRatio="xMidYMid meet"/>' for n in items)
    highlight = (f'<rect x="{ours - 1}" y="4" width="30" height="{bar - 8}" rx="6" '
                 f'fill="{"#000" if light else "#fff"}" fill-opacity="0.12"/>')
    clock = (f'<text x="{w - 16}" y="{bar / 2 + 5}" text-anchor="end" font-family="{FONT}" font-size="13" '
             f'font-weight="500" fill="{text_fill}">lun. 16 nov. 17:30</text>')

    pw = 300
    px = min(ours - 6, w - pw - 2 * U)
    defs, panel, ph = panel_layers(px, bar + 6, pw, clip_id="hero")
    shadow = (f'<rect x="{px}" y="{bar + 6}" width="{pw}" height="{ph:.0f}" rx="14" fill="#000" '
              f'opacity="{0.18 if light else 0.5}" filter="url(#blur)"/>')
    defs += '<filter id="blur" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="14"/></filter>'
    body = (f'<rect width="{w}" height="{h}" rx="16" fill="{desk}"/>'
            f'<path d="M16 0H{w - 16}A16 16 0 0 1 {w} 16V{bar}H0V16A16 16 0 0 1 16 0Z" fill="{bar_fill}"/>'
            f'{highlight}{icons}{clock}{shadow}{panel}')
    title = ("BetterSound open from the menu bar, captured from the app: a volume slider for each app that "
             "is playing, the outputs with the AirPods battery, the sliders moving between three real states")
    return svg(w, h, body, title, defs)


# ---------------------------------------------------------------- cards

CW, CH = 300, 200


def card(name, title, inner, defs=""):
    body = (f'<rect x="0.5" y="0.5" width="{CW - 1}" height="{CH - 1}" rx="14" fill="{CARD}" stroke="{LINE}"/>'
            f'{inner}')
    write(name, svg(CW, CH, body, title, defs))


def crop_card(name, title, src_a, src_b, y0, y1, width=260):
    """A slice of the panel, crossfading between two real captures."""
    s = width / PANEL_W
    h = (y1 - y0) * s
    x, y = (CW - width) / 2, (CH - h) / 2
    img = lambda n: (f'<image href="{uri(n)}" x="0" y="{-y0 * s:.1f}" width="{width}" height="{PANEL_H * s:.1f}"/>')
    swap = fade([0, 0, 1, 1, 0], [0, 0.4, 0.5, 0.9, 1], dur=8)
    defs = f'<clipPath id="c-{name}"><rect width="{width}" height="{h:.1f}" rx="10"/></clipPath>'
    inner = (f'<g transform="translate({x:.1f} {y:.1f})" clip-path="url(#c-{name})">{img(src_a)}'
             + (f'<g opacity="0">{swap}{img(src_b)}</g>' if src_b else "") + '</g>')
    card(name, title, inner, defs)


def card_icon():
    """The menu bar icon follows the output: the same symbols the app picks."""
    names = ["airpods.pro", "laptopcomputer", "display"]
    labels = ["AirPods", "MacBook speakers", "Display"]
    n, dur = len(names), 9
    inner = (f'<rect x="{CW / 2 - 70}" y="40" width="140" height="64" rx="12" fill="#24262c"/>')
    for i, (sym, label) in enumerate(zip(names, labels)):
        t0, t1 = i / n, (i + 1) / n
        vals = [1 if i == 0 else 0]
        times = [0]
        if i == 0:
            vals += [1, 0, 0, 1]; times += [t1 - 0.04, t1, 1 - 0.04, 1]
        else:
            vals += [0, 1, 1, 0, 0]; times += [t0 - 0.04, t0, t1 - 0.04, t1, 1]
        anim = fade(vals, times, dur=dur)
        inner += (f'<g opacity="{vals[0]}">{anim}'
                  f'<image href="{uri(f"sym-{sym}-w.png")}" x="{CW / 2 - 24}" y="52" width="48" height="40" '
                  f'preserveAspectRatio="xMidYMid meet"/>'
                  f'<text x="{CW / 2}" y="140" text-anchor="middle" font-family="{FONT}" font-size="15" '
                  f'fill="#c9d1d9">{label}</text></g>')
    card("card-icon.svg", "The menu bar icon switching between AirPods, the MacBook speakers and a display", inner)


def card_light():
    """Facts, measured from the repo and the release build."""
    swift = sum(1 for root, _, files in os.walk(os.path.join(HERE, "../../BetterSound"))
                for f in files if f.endswith(".swift")
                for _ in open(os.path.join(root, f)))
    rows = [(f"{swift:,}".replace(",", " "), "lines of Swift"), ("0", "drivers or kernel extensions")]
    inner = ""
    for i, (big, small) in enumerate(rows):
        y = 78 + i * 72
        inner += (f'<text x="{CW / 2}" y="{y}" text-anchor="middle" font-family="{FONT}" font-size="36" '
                  f'font-weight="700" fill="{ACCENT}">{big}</text>'
                  f'<text x="{CW / 2}" y="{y + 24}" text-anchor="middle" font-family="{FONT}" font-size="14" '
                  f'fill="#c9d1d9">{small}</text>')
    card("card-light.svg", f"{rows[0][0]} lines of Swift, no driver or kernel extension", inner)
    return swift


# ---------------------------------------------------------------- pills

def pill(name, label, sub, icon, primary=False, w=None):
    w = w or max(150, 58 + int(len(label) * 8.6) + 18)
    fill = ACCENT if primary else "#21262d"
    fg = "#111" if primary else "#f0f6fc"
    stroke = "" if primary else f'<rect x=".5" y=".5" width="{w - 1}" height="47" rx="23.5" fill="none" stroke="{LINE}"/>'
    ic = icon.replace("CUR", fg if primary else ACCENT)
    text = (f'<text x="46" y="{22 if sub else 30}" font-family="{FONT}" font-size="15" font-weight="600" fill="{fg}">{label}</text>'
            + (f'<text x="46" y="38" font-family="{FONT}" font-size="11.5" fill="{fg}" fill-opacity=".7">{sub}</text>' if sub else ""))
    write(name, svg(w, 48, f'<rect width="{w}" height="48" rx="24" fill="{fill}"/>{stroke}'
                     f'<g transform="translate(24 24)" fill="none" stroke-width="2" stroke-linecap="round" '
                     f'stroke-linejoin="round">{ic}</g>{text}', label))


ICONS = {
    "download": '<path d="M0 -9V5M-5 0L0 5L5 0M-8 9H8" stroke="CUR"/>',
    "features": '<path d="M-8 -5H8M-8 0H8M-8 5H8" stroke="CUR"/><circle cx="3" cy="-5" r="2.4" fill="CUR" stroke="CUR"/><circle cx="-3" cy="0" r="2.4" fill="CUR" stroke="CUR"/><circle cx="5" cy="5" r="2.4" fill="CUR" stroke="CUR"/>',
    "how": '<circle r="8" stroke="CUR"/><path d="M0 -1V5M0 -4.5V-4" stroke="CUR"/>',
    "github": '<path d="M0 -9A9 9 0 0 0 -2.8 8.5C-2.3 8.6 -2.2 8.3 -2.2 8V6.4C-4.7 6.9 -5.2 5.2 -5.2 5.2C-5.6 4.2 -6.2 3.9 -6.2 3.9C-7 3.3 -6.1 3.3 -6.1 3.3C-5.2 3.4 -4.7 4.2 -4.7 4.2C-3.9 5.6 -2.6 5.2 -2.1 5C-2 4.4 -1.8 4 -1.5 3.8C-3.5 3.6 -5.6 2.8 -5.6 -0.6C-5.6 -1.6 -5.2 -2.4 -4.7 -3C-4.8 -3.2 -5.1 -4.2 -4.6 -5.4C-4.6 -5.4 -3.8 -5.6 -2.2 -4.5A8 8 0 0 1 2.2 -4.5C3.8 -5.6 4.6 -5.4 4.6 -5.4C5.1 -4.2 4.8 -3.2 4.7 -3C5.2 -2.4 5.6 -1.6 5.6 -0.6C5.6 2.8 3.5 3.6 1.5 3.8C1.8 4.1 2.1 4.6 2.1 5.4V8C2.1 8.3 2.3 8.6 2.8 8.5A9 9 0 0 0 0 -9Z" fill="CUR" stroke="none"/>',
    "kofi": '<path d="M-9 -4H5V3A6 6 0 0 1 -1 9H-3A6 6 0 0 1 -9 3Z" stroke="CUR"/><path d="M5 -1.5H7A3 3 0 0 1 7 4.5H5" stroke="CUR"/><path d="M-4 -8Q-2.5 -9.5 -4 -11M0 -8Q1.5 -9.5 0 -11" stroke="CUR"/>',
}

PILLS = {
    "en": [("btn-download.svg", "Download", "for macOS 26", "download", True),
           ("btn-features.svg", "Features", "", "features", False),
           ("btn-how.svg", "How it works", "", "how", False),
           ("btn-github.svg", "Star on GitHub", "", "github", False),
           ("btn-kofi.svg", "Buy me a coffee", "Tip the dev on Ko-fi", "kofi", False)],
    "fr": [("btn-download-fr.svg", "Télécharger", "pour macOS 26", "download", True),
           ("btn-features-fr.svg", "Fonctions", "", "features", False),
           ("btn-how-fr.svg", "Comment ça marche", "", "how", False),
           ("btn-github-fr.svg", "Une étoile sur GitHub", "", "github", False),
           ("btn-kofi-fr.svg", "Offrir un café", "Soutenir sur Ko-fi", "kofi", False)],
}


def main():
    write("hero.svg", hero(light=False))
    write("hero-light.svg", hero(light=True))

    # Points in the 300 x 311 pt panel: Apps rows 84-168, output rows 206-270.
    crop_card("card-apps.svg", "The Apps section, captured from the app, its sliders moving between two real states",
              "panel-a.jpg", "panel-c.jpg", 62, 170)
    crop_card("card-mute.svg", "An app muted by a click on its icon, captured from the app",
              "panel-a.jpg", "panel-b.jpg", 140, 170)
    crop_card("card-route.svg", "An app sent to the MacBook speakers, its output icon at the end of the row, captured from the app",
              "panel-light.jpg", None, 140, 170)
    crop_card("card-battery.svg", "The outputs with the AirPods battery, captured from the app",
              "panel-a.jpg", None, 182, 272)
    card_icon()
    lines = card_light()
    for lang in PILLS.values():
        for name, label, sub, icon, primary in lang:
            pill(name, label, sub, ICONS[icon], primary)
    print(f"swift lines: {lines}")


if __name__ == "__main__":
    main()
