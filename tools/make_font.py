#!/usr/bin/env python3
"""The game's Chinese font: Noto Sans TC, cut to what the game can show.

    python3 tools/make_font.py [--source NotoSansTC[wght].ttf] [--weight 500]

RogueShot TD in Traditional Chinese (v0.1.24) needs
a font with Chinese in it -- Godot's default, Open Sans SemiBold, has none.
Noto Sans TC (Google Fonts, SIL Open Font License 1.1), as in proj_trts
(2026-10-05); it is set as the default font's FALLBACK (scripts/loc.gd),
so English is drawn exactly as before and only what Open Sans lacks comes
from Noto.

The full font is ~12 MB, a variable font over weight. This makes one weight
of it (500, a little under Open Sans SemiBold, so small Chinese text keeps
its strokes apart) and keeps only:
  - Big5's common characters (its level 1, 0xA440-0xC67E: 5401 -- the
    everyday set of Taiwan's writing) and Big5's symbols (0xA140-0xA3BF:
    full-width punctuation, Bopomofo),
  - Latin, the general punctuation and the full-width forms,
  - every character of every catalogue in locale/*.po, whatever it is,
so a sentence translated later almost never wants the font rebuilt, and
when it does, the localization test (tests/run_tests.gd) says which character is missing.
A player's name in a rarer character still draws through the system font.

Needs fontTools (`pip install --user fonttools`). The source is fetched
from Google Fonts' repository into tools/.cache/ when not given.
"""
import argparse
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SOURCE_URL = "https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf"
LICENSE_URL = "https://github.com/google/fonts/raw/main/ofl/notosanstc/OFL.txt"
OUT_DIR = os.path.join(ROOT, "assets", "fonts")
OUT = os.path.join(OUT_DIR, "NotoSansTC-Game.ttf")


def big5_chars(lo_lead, hi_lead, first, last):
    """Every character Big5 encodes from (lead, trail) `first` to `last`."""
    out = set()
    for lead in range(lo_lead, hi_lead + 1):
        for trail in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            code = (lead << 8) | trail
            if code < first or code > last:
                continue
            try:
                out.add(bytes([lead, trail]).decode("big5"))
            except UnicodeDecodeError:
                pass
    return out


def catalogue_chars():
    out = set()
    locale = os.path.join(ROOT, "locale")
    for name in sorted(os.listdir(locale)) if os.path.isdir(locale) else []:
        if name.endswith(".po"):
            with open(os.path.join(locale, name), encoding="utf-8") as f:
                for line in f:
                    for s in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
                        out.update(s)
    return out


def fetch(url, path):
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        print("fetching", url)
        urllib.request.urlretrieve(url, path)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", help="NotoSansTC[wght].ttf (fetched if not given)")
    ap.add_argument("--weight", type=float, default=500)
    a = ap.parse_args()
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer
    from fontTools import subset

    cache = os.path.join(HERE, ".cache")
    src = a.source or fetch(SOURCE_URL, os.path.join(cache, "NotoSansTC-wght.ttf"))
    fetch(LICENSE_URL, os.path.join(cache, "OFL.txt"))

    chars = set(chr(c) for c in range(0x20, 0x7F))
    chars |= set(chr(c) for c in range(0xA0, 0x180))           # Latin-1, Latin Extended-A
    chars |= set(chr(c) for c in range(0x2000, 0x2070))        # general punctuation
    chars |= set(chr(c) for c in range(0x3000, 0x3040))        # CJK symbols and punctuation
    chars |= set(chr(c) for c in range(0xFF00, 0xFFF0))        # full-width forms
    chars |= big5_chars(0xA1, 0xA3, 0xA140, 0xA3BF)            # Big5 symbols
    common = big5_chars(0xA4, 0xC6, 0xA440, 0xC67E)            # Big5 level 1
    chars |= common
    chars |= catalogue_chars()
    chars.discard("\n")

    font = TTFont(src)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": a.weight})
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.hinting = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in chars])
    sub.subset(font)
    os.makedirs(OUT_DIR, exist_ok=True)
    font.save(OUT)
    with open(os.path.join(cache, "OFL.txt"), encoding="utf-8") as f:
        licence = f.read()
    with open(os.path.join(OUT_DIR, "OFL.txt"), "w", encoding="utf-8") as f:
        f.write(licence)
    have = set(chr(c) for c in TTFont(OUT).getBestCmap())
    print("Big5 level 1: %d characters, %d in the font" % (len(common), len(common & have)))
    print("wrote %s: %d characters, %.2f MB" % (OUT, len(have), os.path.getsize(OUT) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())
