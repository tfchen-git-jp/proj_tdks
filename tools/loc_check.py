#!/usr/bin/env python3
"""Every text the game shows, against the catalogues (locale/*.po).

    tools/loc_check.py [--missing]       report; exit 1 on a problem
    tools/loc_check.py --pot             print every msgid (for a new language)

Texts are found as:
  - literals in tr("…"), Loc.t("…"), Loc.tc("…", "ctx") in scripts/ (with
    "a" + "b" joined; comments skipped);
  - the data tables shown through Loc.t / tr: Level (building and enemy
    name / plural / desc / weak / strong, LANE_NAMES), Perks (card names and
    tier texts, relic names and texts), UiText's keyword lists, the
    menu's CREDITS block.
Checks per catalogue: every text translated (non-empty), %-slots kept in
order (or {n} for each), every character in the Chinese font, no mainland
word (MAINLAND), full-width punctuation after Chinese.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
LOCALE = os.path.join(ROOT, "locale")
FONT = os.path.join(ROOT, "assets", "fonts", "NotoSansTC-Game.ttf")

# Mainland forms an AI translation slips in, never used (Taiwan usage).
MAINLAND = ["游戏", "设置", "保存", "加载", "暴击", "屏幕", "信息", "默认", "支持", "质量", "级别", "点击",
            "退出", "首领", "视频", "文件", "程序", "界面", "网络", "鼠标", "窗口", "全屏", "分辨率", "米）",
            "制作人员", "设定", "单击"]

LIT = r'"((?:[^"\\]|\\.)*)"'


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def strip_comments(src):
    out = []
    for line in src.splitlines():
        # drop a # comment outside strings
        q = False
        for i, c in enumerate(line):
            if c == '"' and (i == 0 or line[i - 1] != "\\"):
                q = not q
            if c == "#" and not q:
                line = line[:i]
                break
        out.append(line)
    return "\n".join(out)


def joined(expr):
    """'"a" + "b"' -> 'ab' (only literal pieces), else None."""
    parts = re.findall(LIT, expr)
    if not parts:
        return None
    rest = re.sub(LIT, "", expr).replace("+", "").replace("\\\n", "").strip()
    if rest.strip("\t\n "):
        return None
    return "".join(unescape(p) for p in parts)


def code_texts():
    found = {}  # (ctx, msgid) -> where
    for name in sorted(os.listdir(SCRIPTS)):
        if not name.endswith(".gd"):
            continue
        src = strip_comments(open(os.path.join(SCRIPTS, name), encoding="utf-8").read())
        for m in re.finditer(r'\b(tr|Loc\.t|Loc\.tc)\(', src):
            i = m.end()
            depth = 1
            j = i
            while j < len(src) and depth:
                if src[j] == "(":
                    depth += 1
                elif src[j] == ")":
                    depth -= 1
                elif src[j] == '"':
                    j += 1
                    while src[j] != '"':
                        j += 2 if src[j] == "\\" else 1
                j += 1
            args = src[i:j - 1]
            ctx = ""
            if m.group(1) == "Loc.tc":
                cm = re.search(r',\s*' + LIT + r'\s*$', args)
                if not cm:
                    continue
                ctx = unescape(cm.group(1))
                args = args[:cm.start()]
            text = joined(args)
            if text is not None:
                found.setdefault((ctx, text), name)
    return found


def table_texts():
    out = set()
    lv = open(os.path.join(SCRIPTS, "level.gd"), encoding="utf-8").read()
    for key in ["name", "plural", "desc", "weak", "strong"]:
        for m in re.finditer(r'\b' + key + r' = ' + LIT, lv):
            out.add(unescape(m.group(1)))
    m = re.search(r'const LANE_NAMES := \[(.*?)\]', lv)
    out.update(unescape(x) for x in re.findall(LIT, m.group(1)))
    pk = open(os.path.join(SCRIPTS, "perks.gd"), encoding="utf-8").read()
    for m in re.finditer(r'name = ' + LIT, pk):
        out.add(unescape(m.group(1)))
    for m in re.finditer(r'desc = \[(.*?)\]\}', pk, re.S):
        out.update(unescape(x) for x in re.findall(LIT, m.group(1)))
    for m in re.finditer(r'desc = ' + LIT + r'\}', pk):
        out.add(unescape(m.group(1)))
    ui = open(os.path.join(SCRIPTS, "ui_text.gd"), encoding="utf-8").read()
    for block in re.findall(r'const (?:ICON|COLOR)_WORDS := \[(.*?)\n\]', ui, re.S):
        for m in re.finditer(r'\[' + LIT + r',', block):
            out.add(unescape(m.group(1)))
    mn = open(os.path.join(SCRIPTS, "menu.gd"), encoding="utf-8").read()
    m = re.search(r'const CREDITS := """(.*?)"""', mn, re.S)
    out.add(m.group(1))
    # Not shown: building-kind keys and the like are never names here.
    return out


def read_po(path):
    entries = {}
    ctx = ""
    cur = None
    field = None
    buf = {"msgctxt": "", "msgid": "", "msgstr": ""}

    def flush():
        if buf["msgid"] or buf["msgstr"]:
            entries[(buf["msgctxt"], buf["msgid"])] = buf["msgstr"]

    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith("#") or not line.strip():
            if field == "msgstr":
                flush()
                buf = {"msgctxt": "", "msgid": "", "msgstr": ""}
                field = None
            continue
        m = re.match(r'(msgctxt|msgid|msgstr) "(.*)"$', line)
        if m:
            if m.group(1) in ("msgctxt", "msgid") and field == "msgstr":
                flush()
                buf = {"msgctxt": "", "msgid": "", "msgstr": ""}
            field = m.group(1)
            buf[field] = unescape(m.group(2))
        elif line.startswith('"') and field:
            buf[field] += unescape(line[1:-1])
    if field == "msgstr":
        flush()
    entries.pop(("", ""), None)
    return entries


def slots(s):
    return re.findall(r'%[-+0-9.]*[sdfi%]', s)


def main():
    wanted = {k: v for k, v in code_texts().items()}
    for t in table_texts():
        wanted.setdefault(("", t), "table")
    if "--pot" in sys.argv:
        for (ctx, t) in sorted(wanted, key=lambda k: (k[1].lower(), k[0])):
            print(("[%s] " % ctx if ctx else "") + repr(t))
        return 0
    bad = 0
    font_chars = None
    try:
        from fontTools.ttLib import TTFont
        font_chars = set(chr(c) for c in TTFont(FONT).getBestCmap())
    except Exception as e:
        print("(font not checked: %s)" % e)
    for name in sorted(os.listdir(LOCALE)):
        if not name.endswith(".po"):
            continue
        po = read_po(os.path.join(LOCALE, name))
        missing = [k for k in wanted if not po.get(k)]
        extra = [k for k in po if k not in wanted]
        print("%s: %d texts, %d translated, %d missing, %d unused" % (name, len(wanted), len(wanted) - len(missing), len(missing), len(extra)))
        for k in sorted(missing):
            print("  MISSING %s%r  (%s)" % ("[%s] " % k[0] if k[0] else "", k[1], wanted[k]))
            bad += 1
        if "--unused" in sys.argv:
            for k in sorted(extra):
                print("  unused %r" % (k,))
        for k, v in po.items():
            if not v:
                continue
            a, b = slots(k[1]), slots(v)
            braces = re.findall(r'\{(\d)\}', v)
            if braces:  # {n} per real slot ("%%" is a literal percent sign)
                ok = sorted(int(x) for x in braces) == list(range(len([x for x in a if x != "%%"])))
            else:
                ok = a == b
            if not ok:
                print("  SLOTS %r -> %r" % (k[1], v))
                bad += 1
            for w in MAINLAND:
                if w in v:
                    print("  MAINLAND %r in %r" % (w, v))
                    bad += 1
            if re.search(r'[一-鿿][,:;!?()]', v):
                print("  HALF-WIDTH punctuation after Chinese: %r" % v)
                bad += 1
            if font_chars is not None:
                lack = sorted(set(c for c in v if c not in font_chars and c not in "\n\t"))
                if lack:
                    print("  FONT lacks %r in %r (run tools/make_font.py)" % ("".join(lack), v))
                    bad += 1
    print("localization: %s" % ("OK" if not bad else "%d problems" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
