#!/usr/bin/env python3
"""Balance meta-analysis: play many games with randomised bot builds
(tools/meta.gd) in parallel headless Godot processes and summarise what
wins and what loses.

  tools/meta_report.py [--runs=120] [--jobs=4] [--fixed] [--from=0] [--json=out.jsonl]
      [--specs=archer:repeater,...]   (the fixed bot's specs, for A/B runs)
      [--force=ID]                    (this card / relic first in the bot's picks)

Report: win rate; where runs die (wave) and lose keep HP; damage share by
source (hero vs each tower kind) in wins and losses; win rate by how much
of the build went into each tower kind; farm vs bank; relics and cards.
"""
import json
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor

ROOT = __file__.rsplit('/tools/', 1)[0]
TOWERS = ["archer", "ballista", "mortar", "frost", "banner"]


def arg(name, default):
    for a in sys.argv[1:]:
        if a.startswith("--" + name + "="):
            return type(default)(a.split("=", 1)[1])
        if a == "--" + name and isinstance(default, bool):
            return True
    return default


def play(chunk):
    start, count, fixed, specs, force = chunk
    cmd = ["godot", "--headless", "--path", ROOT, "--script", "res://tools/meta.gd", "--",
           "--from=%d" % start, "--count=%d" % count] + (["--fixed"] if fixed else []) + \
        (["--specs=" + specs] if specs else []) + (["--force=" + force] if force else [])
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=3600).stdout
    return [json.loads(line[6:]) for line in out.splitlines() if line.startswith("[run] ")]


def pct(a, b):
    return "%3.0f%%" % (100.0 * a / b) if b else "  - "


def main():
    runs, jobs, fixed = arg("runs", 120), arg("jobs", 4), arg("fixed", False)
    start = arg("from", 0)
    per = max(1, (runs + jobs - 1) // jobs)
    specs = arg("specs", "")
    force = arg("force", "")
    chunks = [(k, min(per, start + runs - k), fixed, specs, force) for k in range(start, start + runs, per)]
    games = []
    with ThreadPoolExecutor(jobs) as ex:
        for got in ex.map(play, chunks):
            games += got
    out = arg("json", "")
    if out:
        with open(out, "w") as f:
            for g in games:
                f.write(json.dumps(g) + "\n")
    n = len(games)
    wins = [g for g in games if g["win"]]
    losses = [g for g in games if not g["win"]]
    print("=== %d games (%s builds): %d wins (%s) ===" % (n, "fixed" if fixed else "random", len(wins), pct(len(wins), n)))
    if wins:
        print("wins: keep left avg %.0f%%, level %.1f" % (100 * sum(g["keep"] for g in wins) / len(wins),
                                                           sum(g["level"] for g in wins) / len(wins)))
    died = defaultdict(int)
    for g in losses:
        died[g["waves"] + 1] += 1
    print("losses by wave:", " ".join("w%d:%d" % (w, died[w]) for w in sorted(died)))
    lost = defaultdict(list)
    for g in games:
        for w, v in enumerate(g["keep_lost"]):
            lost[w + 1].append(v)
    print("keep HP lost per wave (avg over games reaching it):",
          " ".join("w%d:%.0f" % (w, sum(v) / len(v)) for w, v in sorted(lost.items())))

    print("\n-- damage share (avg) --")
    srcs = sorted({k for g in games for k in g["share"]})
    print("%-10s %8s %8s %8s" % ("source", "all", "wins", "losses"))
    for k in srcs:
        def avg(gs):
            return 100.0 * sum(g["share"].get(k, 0) for g in gs) / len(gs) if gs else 0.0
        print("%-10s %7.1f%% %7.1f%% %7.1f%%" % (k, avg(games), avg(wins), avg(losses)))

    if not fixed:
        print("\n-- win rate by share of tower levels in each kind --")
        print("%-10s %14s %14s %14s" % ("tower", "none", "some (<25%)", "heavy (>=25%)"))
        for t in TOWERS:
            buckets = {"none": [0, 0], "some": [0, 0], "heavy": [0, 0]}
            for g in games:
                tot = sum(g["levels"].get(k, 0) for k in TOWERS) or 1
                s = g["levels"].get(t, 0) / tot
                b = "none" if s == 0 else ("some" if s < 0.25 else "heavy")
                buckets[b][0] += g["win"]
                buckets[b][1] += 1
            print("%-10s %14s %14s %14s" % (t, *("%s of %3d" % (pct(*buckets[b]), buckets[b][1]) for b in ["none", "some", "heavy"])))
        print("\n-- economy plots --")
        for eco in ["farm", "bank"]:
            gs = [g for g in games if g["levels"].get(eco, 0) > 0]
            only = [g for g in gs if g["levels"].get("bank" if eco == "farm" else "farm", 0) == 0]
            print("%-5s any: win %s of %3d   only %s: win %s of %3d" % (
                eco, pct(sum(g["win"] for g in gs), len(gs)), len(gs), eco, pct(sum(g["win"] for g in only), len(only)), len(only)))

    print("\n-- relics (win rate when owned) --")
    rel = defaultdict(lambda: [0, 0])
    for g in games:
        for r in g["relics"]:
            rel[r][0] += g["win"]
            rel[r][1] += 1
    print("  ".join("%s %s/%d" % (r, pct(*v), v[1]) for r, v in sorted(rel.items())))
    print("\n-- tower specs (win rate when built, towers) --")
    spc = defaultdict(lambda: [0, 0, 0])
    for g in games:
        for sp, k in g.get("specs", {}).items():
            spc[sp][0] += g["win"]
            spc[sp][1] += 1
            spc[sp][2] += k
    print("  ".join("%s %s/%d (%d)" % (sp, pct(v[0], v[1]), v[1], v[2]) for sp, v in sorted(spc.items())))
    print("\n-- cards (win rate when owned, avg tier) --")
    card = defaultdict(lambda: [0, 0, 0])
    for g in games:
        for c, t in g["perks"].items():
            card[c][0] += g["win"]
            card[c][1] += 1
            card[c][2] += t
    for c, v in sorted(card.items(), key=lambda kv: -kv[1][0] / max(kv[1][1], 1)):
        print("  %-10s win %s of %3d  tier %.1f" % (c, pct(v[0], v[1]), v[1], v[2] / v[1]))


if __name__ == "__main__":
    main()
