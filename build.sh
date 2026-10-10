#!/usr/bin/env bash
# proj_tdks build/verify driver. Lessons behind each guard are in
# ~/proj_trts/GODOT-BLENDER-WSL-PLAYBOOK.md.
#   ./build.sh import            headless import (reimports assets)
#   ./build.sh check             import + parse-check every script
#   ./build.sh test              check + headless unit tests (tests/run_tests.gd) + tools/loc_check.py
#   ./build.sh sim [ARGS]        headless balance run: the bot plays level 1
#   ./build.sh shot NAME [ARGS]  windowed WSL run (Compatibility, D3D12 GPU) -> renders/NAME.png
#   ./build.sh export            Windows .exe -> /mnt/d/wsl_scratch/proj_tdks/
#   ./build.sh native [ARGS]     run the exported .exe natively on Windows
#   ./build.sh apk               Android debug APK -> /mnt/d/wsl_scratch/proj_tdks/rogueshot_td.apk
#   ./build.sh install           apk + install on the phone with Windows adb.exe
#                                (pair once: phone Developer options > Wireless debugging,
#                                 then  ./build.sh adb pair IP:PORT CODE  and  ./build.sh adb connect IP:PORT)
#   ./build.sh adb ARGS          run Windows adb.exe with ARGS
#   ./build.sh logcat            phone's Godot log (Ctrl-C to stop)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS="$ROOT/.logs"
DIST="/mnt/d/wsl_scratch/proj_tdks"
EXE="$DIST/rogueshot_td.exe"
APK="$DIST/rogueshot_td.apk"
ADB="/mnt/d/wsl_scratch/android-platform-tools/platform-tools/adb.exe"
PKG="com.tfc.rogueshottd"
mkdir -p "$LOGS" "$ROOT/renders" "$DIST"
touch "$LOGS/.gdignore" "$ROOT/renders/.gdignore"

GPU_ENV=(env LD_LIBRARY_PATH=/usr/lib/wsl/lib GALLIUM_DRIVER=d3d12)
GODOT="${GODOT:-godot}"

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
info() { printf '\033[36m==> %s\033[0m\n' "$*"; }

# The user runs other Godot/Blender work on this machine; yield to it.
# Wait until no foreign godot/blender process has been seen for 10 s.
wait_idle() {
  local quiet=0 waited=0
  while (( quiet < 10 )); do
    local busy=0
    for pid in $(pgrep -x godot; pgrep -x blender; pgrep -f '^[^ ]*Godot_v' ); do
      if ! { tr "\0" " " < "/proc/$pid/cmdline"; } 2>/dev/null | grep -qE "proj[_-]tdks"; then busy=1; fi
    done
    if (( busy )); then
      quiet=0
      (( waited % 30 == 0 )) && info "other Godot/Blender job running -- waiting"
    else
      quiet=$((quiet + 1))
    fi
    waited=$((waited + 1))
    read -t 1 -r _ <> <(:) || true
  done
}

t_import() {
  info "importing"
  timeout 600 "$GODOT" --headless --path "$ROOT" --import > "$LOGS/import.log" 2>&1
  if grep -E "^(ERROR|SCRIPT ERROR)" "$LOGS/import.log" | grep -v "Plugin is not attached" | head -20 | grep -q .; then
    red "import reported errors:"; grep -E -A2 "^(ERROR|SCRIPT ERROR)" "$LOGS/import.log" | head -40
    return 1
  fi
  grn "import ok"
}

t_check() {
  t_import || return 1
  info "parse-checking scripts"
  local fail=0
  for f in $(cd "$ROOT" && find scripts tests tools -name '*.gd'); do
    timeout 60 "$GODOT" --headless --path "$ROOT" --check-only --script "res://$f" > "$LOGS/check.log" 2>&1 \
      || { red "FAIL $f"; grep -E "ERROR|error" "$LOGS/check.log" | head -10; fail=1; }
  done
  (( fail )) && return 1
  grn "all scripts parse"
}

t_test() {
  t_check || return 1
  info "unit tests"
  timeout 120 "$GODOT" --headless --path "$ROOT" --script res://tests/run_tests.gd > "$LOGS/test.log" 2>&1
  grep -E "^(PASS|FAIL|ok|RESULT)|SCRIPT ERROR" "$LOGS/test.log" | tail -40
  grep -q "^ALL PASSED" "$LOGS/test.log" || { red "tests FAILED"; return 1; }
  info "localization (tools/loc_check.py)"
  python3 "$ROOT/tools/loc_check.py" > "$LOGS/loc.log" 2>&1 || { red "localization FAILED"; grep -vE "^zh|^\(" "$LOGS/loc.log" | head -20; return 1; }
  grn "tests passed"
}

t_sim() {
  timeout 300 "$GODOT" --headless --path "$ROOT" --script res://tools/balance.gd -- "$@" 2>&1 | grep -vE "^Godot Engine|^$"
}

t_shot() {
  local name="$1"; shift
  # A script that fails to parse still opens a (blank) window that never
  # quits: refuse to launch unless everything parses.
  t_check > "$LOGS/shot_check.log" 2>&1 || { red "scripts don't parse -- not launching"; grep -E "FAIL|ERROR" "$LOGS/shot_check.log" | head; return 1; }
  wait_idle
  info "windowed WSL run -> renders/$name.png"
  rm -f "$ROOT/renders/$name.png"
  timeout 180 "${GPU_ENV[@]}" "$GODOT" --path "$ROOT" \
      --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy \
      -- --shot="$ROOT/renders/$name.png" "$@" > "$LOGS/shot_$name.log" 2>&1
  grep -m1 "OpenGL API" "$LOGS/shot_$name.log"
  grep -E "SCRIPT ERROR|^ERROR|^WARNING|^\[" "$LOGS/shot_$name.log" | head -30
  [[ -f "$ROOT/renders/$name.png" ]] && grn "shot saved" || { red "no shot produced"; tail -20 "$LOGS/shot_$name.log"; return 1; }
}

t_export() {
  t_check || return 1
  info "exporting Windows build -> $EXE"
  timeout 600 "$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$EXE" > "$LOGS/export.log" 2>&1
  [[ -f "$EXE" ]] || { red "export FAILED"; tail -30 "$LOGS/export.log"; return 1; }
  grn "exported: $(du -h "$EXE" | cut -f1)"
}

t_native() {
  [[ -f "$EXE" ]] || { red "no exe; run export first"; return 1; }
  info "running natively on Windows"
  (cd "$DIST" && timeout 120 ./rogueshot_td.exe -- "$@" > "$LOGS/native.log" 2>&1)
  if tasklist.exe 2>/dev/null | grep -qi rogueshot_td.exe; then
    red "game still running after 120 s -- killing it"
    taskkill.exe /IM rogueshot_td.exe /F > /dev/null 2>&1
  fi
  grep -E "^\[|ERROR" "$LOGS/native.log" | head -40
}

# Each APK gets the next build number: Android's version code (an update
# must not go backwards) and the "v0.1.N" shown in the game's corner.
bump_version() {
  local n=$(( $(cat "$ROOT/build_number.txt" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$ROOT/build_number.txt"
  sed -i "s/^version\/code=.*/version\/code=$n/; s/^version\/name=.*/version\/name=\"0.1.$n\"/" "$ROOT/export_presets.cfg"
  sed -i "s/^config\/version=.*/config\/version=\"0.1.$n\"/" "$ROOT/project.godot"
  VERSION="0.1.$n"
}

t_apk() {
  bump_version
  t_check || return 1
  info "exporting Android debug APK -> $APK"
  rm -f "$APK"
  timeout 600 "$GODOT" --headless --path "$ROOT" --export-debug "Android" "$APK" > "$LOGS/apk.log" 2>&1
  [[ -f "$APK" ]] || { red "APK export FAILED"; grep -E "ERROR|error" "$LOGS/apk.log" | head -20; return 1; }
  rm -f "$APK.idsig"   # only used by adb's incremental install; not needed
  grn "APK v$VERSION: $(du -h "$APK" | cut -f1)  (Windows: $(wslpath -w "$APK"))"
}

adbw() { (cd /mnt/c && "$ADB" "$@"); }

t_install() {
  t_apk || return 1
  info "installing on the phone"
  adbw devices
  adbw install -r "$(wslpath -w "$APK")" && adbw shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null \
    && grn "installed and launched"
}

cmd="${1:-check}"; shift || true
case "$cmd" in
  import)  t_import ;;
  check)   t_check ;;
  test)    t_test ;;
  sim)     t_sim "$@" ;;
  shot)    t_shot "$@" ;;
  export)  t_export ;;
  native)  t_native "$@" ;;
  apk)     t_apk ;;
  install) t_install ;;
  adb)     adbw "$@" ;;
  logcat)  adbw logcat -s godot:V ;;
  wait)    wait_idle ;;
  *) red "unknown target $cmd"; exit 2 ;;
esac
