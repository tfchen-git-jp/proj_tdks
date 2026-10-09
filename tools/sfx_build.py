#!/usr/bin/env python3
"""Build the game's sound effects from the downloaded CC0 / CC-BY packs.

    python3 tools/sfx_build.py            # build everything
    python3 tools/sfx_build.py coin build # only outputs whose name starts with these

Sources: assets_in/sfx_src/<pack>/... (Godot-ignored, see CREDITS.txt for URLs)
Output:  assets/sfx/<name>.ogg  -- mono, 44.1 kHz, Ogg Vorbis q4, leading and
trailing silence removed, short fade-out, peak-normalised to the per-sound
target (frequent sounds quieter).  Needs only python3 + ffmpeg/ffprobe.

Each output is one or more layers mixed together.  A layer is
    L(src, start=0, dur=None, rate=1.0, gain=0, delay=0, af=None)
  src    path under assets_in/sfx_src
  start  seconds cut from the source's head (before anything else)
  dur    keep this many seconds of the source (None = all)
  rate   pitch/speed factor (1.2 = 20 % higher and shorter, like a tape)
  gain   dB applied to this layer before mixing
  delay  seconds this layer starts after t=0 of the mix
  af     extra ffmpeg audio filter string for this layer (e.g. "lowpass=f=2000")
and an output is
    S(name, layers, peak=-3, maxlen=1.5, fade=0.08)
  peak   target sample peak of the finished file in dBFS
  maxlen hard length cap in seconds (after the silence trim)
  fade   fade-out length at the end in seconds
"""
import os, re, subprocess, sys, tempfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "assets_in", "sfx_src")
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 44100
FF = "ffmpeg"
SIL_START_DB = -50   # silenceremove thresholds (absolute dBFS)
SIL_END_DB = -55


def L(src, start=0.0, dur=None, rate=1.0, gain=0.0, delay=0.0, af=None):
    return dict(src=src, start=start, dur=dur, rate=rate, gain=gain, delay=delay, af=af)


def S(name, layers, peak=-3.0, maxlen=1.5, fade=0.08):
    return dict(name=name, layers=layers, peak=peak, maxlen=maxlen, fade=fade)


# --- source shorthands --------------------------------------------------------
K_IMP = "kenney_impact-sounds/Audio/"
K_RPG = "kenney_rpg-audio/Audio/"
K_IF = "kenney_interface-sounds/Audio/"
K_CAS = "kenney_casino-audio/Audio/"
K_SCI = "kenney_sci-fi-sounds/Audio/"
K_JIN = "kenney_music-jingles/Audio/"
BOW = "oga_battle-sound-effects/battle_sound_effects/Bow.wav"   # artisticdude, CC0
TINY = "oga_tinysized-sfx/sfx-cc0/"
CRE = "oga_80-cc0-creature-sfx/"

SOUNDS = [
    # Hero crossbow: the bow twang pitched up (short, tight string) over the
    # trigger click of a metal latch.
    S("hero_shot_1", [L(BOW, start=0.095, rate=1.25, delay=0.015), L(K_RPG + "metalClick.ogg", start=0.09, dur=0.06, gain=-10)],
      peak=-11, maxlen=0.4, fade=0.12),
    S("hero_shot_2", [L(BOW, start=0.095, rate=1.38, delay=0.015), L(K_RPG + "metalClick.ogg", start=0.26, dur=0.06, gain=-10)],
      peak=-11, maxlen=0.4, fade=0.12),
    S("hero_shot_3", [L(BOW, start=0.095, rate=1.15, delay=0.012), L(K_RPG + "metalLatch.ogg", start=0.03, dur=0.05, gain=-14)],
      peak=-11, maxlen=0.4, fade=0.12),
    # Archer towers: the plain bow, a little lower, plus arrow-feather flutter.
    S("arrow_shot_1", [L(BOW, start=0.095, rate=0.95), L(TINY + "arrow-feathers-01.wav", start=0.02, dur=0.2, gain=-16, delay=0.05)],
      peak=-10, maxlen=0.5, fade=0.15),
    S("arrow_shot_2", [L(BOW, start=0.095, rate=0.85), L(TINY + "arrow-feathers-01.wav", start=0.22, dur=0.2, gain=-16, delay=0.05)],
      peak=-10, maxlen=0.5, fade=0.15),
    # Ballista: a big slow twang (bow at 0.55x) + heavy wood knock of the arm.
    S("ballista_shot", [L(BOW, start=0.095, rate=0.55, gain=-2), L(K_IMP + "impactWood_heavy_002.ogg"),
                        L(K_RPG + "creak3.ogg", start=0.03, gain=-14, rate=0.8)],
      peak=-5, maxlen=0.8, fade=0.25),
    # Mortar: a pitched-down dough "pop" over a sub thump; the boom is a real
    # explosion's first second over the sci-fi low-frequency boom.
    S("mortar_shot", [L("oga_dull-explosion/explosion_dull.flac", rate=0.55),
                      L(K_SCI + "lowFrequency_explosion_001.ogg", start=0.03, dur=0.5, gain=-4)],
      peak=-5, maxlen=0.6, fade=0.25),
    S("mortar_boom", [L("oga_chunky-explosion/chunky_explosion.mp3", dur=1.3),
                      L(K_SCI + "lowFrequency_explosion_001.ogg", start=0.03, gain=-3)],
      peak=-3, maxlen=1.2, fade=0.6),
    # Frost tower pulse: ice crackle on the attack, then the loud sustained
    # part of the freeze-spell shimmer and its natural decay.
    S("frost_pulse", [L("oga_freeze-spell/freeze.wav", start=0.95, af="afade=t=in:d=0.04"),
                      L("oga_ice-spells/ice.wav", start=0.12, dur=0.6, gain=-3)],
      peak=-6, maxlen=1.2, fade=0.3),
    # Projectile hits on enemies (very frequent -> quiet, short).
    S("hit_flesh_1", [L(K_IMP + "impactPunch_medium_000.ogg")], peak=-12, maxlen=0.25, fade=0.1),
    S("hit_flesh_2", [L(K_IMP + "impactPunch_medium_001.ogg", rate=1.08)], peak=-12, maxlen=0.25, fade=0.1),
    S("hit_flesh_3", [L(K_IMP + "impactPunch_medium_003.ogg", rate=0.94)], peak=-12, maxlen=0.25, fade=0.1),
    # Grunt deaths: short creature grunts over a soft body pop.
    S("enemy_die_1", [L(CRE + "grunt_02.ogg", rate=1.1), L(K_IMP + "impactSoft_medium_000.ogg", gain=-8)],
      peak=-9, maxlen=0.5, fade=0.15),
    S("enemy_die_2", [L(CRE + "grunt_03.ogg", start=0.12, rate=1.1), L(K_IMP + "impactSoft_medium_001.ogg", gain=-8)],
      peak=-9, maxlen=0.5, fade=0.15),
    S("enemy_die_3", [L(CRE + "troll_03.ogg", rate=1.05), L(K_IMP + "impactSoft_medium_002.ogg", gain=-8)],
      peak=-9, maxlen=0.45, fade=0.15),
    # Ogre brute: deep groan, then the body hits the ground.
    S("brute_die", [L(CRE + "monster_07.ogg", start=0.15, rate=0.85),
                    L(K_IMP + "impactSoft_heavy_001.ogg", delay=0.55, gain=-1),
                    L(K_IMP + "impactWood_heavy_001.ogg", delay=0.57, gain=-8, rate=0.8)],
      peak=-3, maxlen=1.4, fade=0.35),
    # Coins: single coin flip ring + a short glass tick for a bright "clink".
    S("coin_pickup_1", [L(TINY + "coinflip-01.wav", dur=0.2), L(K_IF + "glass_005.ogg", rate=1.5, gain=-8)],
      peak=-12, maxlen=0.2, fade=0.1),
    S("coin_pickup_2", [L(TINY + "coinflip-01.wav", dur=0.2, rate=1.12), L(K_IF + "glass_006.ogg", rate=1.6, gain=-8)],
      peak=-12, maxlen=0.2, fade=0.1),
    S("coin_pickup_3", [L(TINY + "coinflip-01.wav", dur=0.2, rate=0.92), L(K_IF + "glass_002.ogg", rate=1.7, gain=-8)],
      peak=-12, maxlen=0.2, fade=0.1),
    S("coin_pay", [L(K_CAS + "chip-lay-1.ogg")], peak=-14, maxlen=0.15, fade=0.08),
    # Build: three wooden hammer knocks, then a little sparkle.
    S("build", [L(K_IMP + "impactPlank_medium_000.ogg", dur=0.18),
                L(K_IMP + "impactPlank_medium_001.ogg", dur=0.18, delay=0.16, rate=1.05),
                L(K_IMP + "impactPlank_medium_002.ogg", dur=0.3, delay=0.32, rate=0.95, gain=1),
                L(K_IF + "glass_004.ogg", delay=0.45, gain=-9)],
      peak=-3, maxlen=1.2, fade=0.35),
    S("upgrade", [L(K_IF + "confirmation_004.ogg")], peak=-4, maxlen=1.2, fade=0.2),
    # Gate: heavy wood thuds; break = splintering planks + rubble crunch.
    S("gate_hit_1", [L(K_IMP + "impactWood_heavy_000.ogg"), L(K_IMP + "impactPlank_medium_001.ogg", dur=0.3, gain=-6)],
      peak=-5, maxlen=0.4, fade=0.15),
    S("gate_hit_2", [L(K_IMP + "impactWood_heavy_003.ogg", rate=0.92), L(K_IMP + "impactPlank_medium_002.ogg", dur=0.3, gain=-6)],
      peak=-5, maxlen=0.4, fade=0.15),
    S("gate_break", [L(K_IMP + "impactWood_heavy_001.ogg", rate=0.85),
                     L(K_IMP + "impactPlank_medium_000.ogg", delay=0.05),
                     L(TINY + "wood-twigs-break-01.wav", delay=0.04, gain=-4),
                     L(K_IMP + "impactPlank_medium_002.ogg", delay=0.28, rate=0.9, gain=-3),
                     L(K_IMP + "impactWood_heavy_004.ogg", delay=0.45, rate=0.8, gain=-4),
                     L(K_SCI + "explosionCrunch_002.ogg", dur=0.9, gain=-12, af="lowpass=f=1800")],
      peak=-3, maxlen=1.4, fade=0.45),
    # Wave start: horn (didgeridoo through reverb), first ~3 s of the swell.
    S("wave_start", [L("oga_massive-horn/massive_horn.wav", start=0.3, dur=3.2, af="afade=t=in:d=0.25")],
      peak=-3, maxlen=3.2, fade=1.0),
    S("wave_clear", [L(K_JIN + "Steel jingles/jingles_STEEL10.ogg")], peak=-4, maxlen=1.5, fade=0.3),
    S("victory", [L("oga_classic-fanfare-lick/fanfare_3.ogg", start=0.17)], peak=-3, maxlen=3.5, fade=0.5),
    S("defeat", [L("oga_game-over-trumpet/losetrumpet.wav")], peak=-3, maxlen=2.0, fade=0.3),
    # UI
    S("ui_click", [L(K_IF + "click_001.ogg")], peak=-8, maxlen=0.12, fade=0.04),
    S("ui_open", [L(K_IF + "open_002.ogg")], peak=-7, maxlen=0.6, fade=0.12),
    # The lodge takes damage: a dull body-ish thump with a wooden knock.
    S("base_hit", [L(K_IMP + "impactSoft_heavy_002.ogg"), L(K_IMP + "impactWood_heavy_002.ogg", gain=-7, rate=0.85)],
      peak=-4, maxlen=0.6, fade=0.25),
]


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def probe_dur(path):
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).stdout
    return float(out.strip())


def volumedetect(path):
    err = subprocess.run([FF, "-hide_banner", "-nostats", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    mx = float(re.search(r"max_volume: (-?[\d.]+) dB", err).group(1))
    mn = float(re.search(r"mean_volume: (-?[\d.]+) dB", err).group(1))
    return mx, mn


def render_mix(spec, tmp_wav):
    """Mix the layers, strip leading/trailing silence, cap the length -> float wav."""
    cmd = [FF, "-v", "error", "-y"]
    chains, labels = [], []
    for i, ly in enumerate(spec["layers"]):
        src = os.path.join(SRC, ly["src"])
        if not os.path.isfile(src):
            sys.exit(f"missing source: {src}")
        cmd += ["-i", src]
        f = [f"aformat=sample_fmts=fltp:sample_rates={SR}:channel_layouts=mono"]
        if ly["start"] or ly["dur"]:
            f.append(f"atrim=start={ly['start']}" + (f":duration={ly['dur']}" if ly["dur"] else ""))
            f.append("asetpts=PTS-STARTPTS")
        if ly["rate"] != 1.0:
            f.append(f"asetrate={int(SR * ly['rate'])},aresample={SR}")
        if ly["af"]:
            f.append(ly["af"])
        if ly["gain"]:
            f.append(f"volume={ly['gain']}dB")
        if ly["delay"]:
            f.append(f"adelay={int(ly['delay'] * 1000)}:all=1")
        chains.append(f"[{i}:a]{','.join(f)}[l{i}]")
        labels.append(f"[l{i}]")
    n = len(labels)
    mix = f"{''.join(labels)}amix=inputs={n}:duration=longest:normalize=0" if n > 1 else f"{labels[0]}anull"
    trim = (f"silenceremove=start_periods=1:start_threshold={SIL_START_DB}dB:start_silence=0.002,"
            f"areverse,silenceremove=start_periods=1:start_threshold={SIL_END_DB}dB:start_silence=0.01,areverse,"
            f"atrim=duration={spec['maxlen']}")
    fc = ";".join(chains) + f";{mix},{trim}[out]"
    run(cmd + ["-filter_complex", fc, "-map", "[out]", "-ac", "1", "-ar", str(SR), "-c:a", "pcm_f32le", tmp_wav])


def encode(spec, tmp_wav, out_ogg, gain_db):
    d = probe_dur(tmp_wav)
    fade = min(spec["fade"], d / 2)
    af = f"afade=t=in:d=0.003,afade=t=out:st={max(0.0, d - fade):.4f}:d={fade:.4f},volume={gain_db:.2f}dB"
    run([FF, "-v", "error", "-y", "-i", tmp_wav, "-af", af, "-ac", "1", "-ar", str(SR),
         "-c:a", "libvorbis", "-q:a", "4", out_ogg])


def build(spec, tmpdir):
    tmp = os.path.join(tmpdir, spec["name"] + ".wav")
    out = os.path.join(OUT, spec["name"] + ".ogg")
    render_mix(spec, tmp)
    mx, _ = volumedetect(tmp)
    gain = spec["peak"] - mx
    encode(spec, tmp, out, gain)
    # Vorbis can move the peak a little (and the fade can lower it): correct once.
    mx2, _ = volumedetect(out)
    if abs(mx2 - spec["peak"]) > 0.4:
        gain += spec["peak"] - mx2
        encode(spec, tmp, out, gain)
    mx3, mn3 = volumedetect(out)
    print(f"{spec['name']:15s} {probe_dur(out):5.2f} s  peak {mx3:6.1f} dB  mean {mn3:6.1f} dB")


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    with tempfile.TemporaryDirectory() as td:
        for spec in SOUNDS:
            if only and not any(spec["name"].startswith(p) for p in only):
                continue
            build(spec, td)


if __name__ == "__main__":
    main()
