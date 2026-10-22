#!/usr/bin/env python3
"""Run the Godot scenario suites and fail on engine script errors, even on exit 0."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
parser.add_argument("--balance-strict", action="store_true", help="fail, not warn, when the balance gate finds a band over its limit")
parser.add_argument("--no-balance", action="store_true", help="skip the balance gate")
args = parser.parse_args()
candidates = [args.godot, shutil.which("godot"), shutil.which("godot4"),
              "/Users/benthomas/Downloads/Godot.app/Contents/MacOS/Godot",
              "/Applications/Godot.app/Contents/MacOS/Godot"]
godot = next((str(path) for path in candidates if path and Path(path).is_file()), None)
if not godot:
    sys.exit("Godot 4.7.2 was not found. Use --godot /path/to/Godot or set GODOT_BIN.")

version = subprocess.check_output([godot, "--version"], text=True).strip()
print(f"Engine: {version}", flush=True)
if not version.startswith("4.7.2.stable"):
    sys.exit("This project's deterministic replay contract is pinned to Godot 4.7.2 stable.")

failed = []
# The class cache is what lets one script name another by class_name; a fresh checkout has
# none, so the project is scanned once before the suites run.
subprocess.run([godot, "--headless", "--path", str(ROOT), "--import"], cwd=ROOT, text=True,
               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)

for suite in ["test_dice.gd", "test_dice_shapes.gd", "test_stones.gd", "test_gem_updates.gd", "test_new_gems.gd", "test_void.gd", "test_battle.gd", "test_statuses.gd", "test_limits.gd", "test_enemy_turns.gd", "test_bestiary.gd", "test_enemy_ui.gd", "test_descent.gd", "test_altar.gd", "test_economy.gd", "test_net.gd", "test_view.gd", "test_creatures.gd", "test_audio.gd", "test_screens.gd", "test_menu_navigation.gd", "test_fit.gd"]:
    path = ROOT / "tests" / suite
    if not path.exists():
        failed.append(suite + " (missing)")
        continue
    print(f"\nRunning {suite}", flush=True)
    result = subprocess.run([godot, "--headless", "--path", str(ROOT), "--script", str(path)],
                            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=120)
    print(result.stdout.strip(), flush=True)
    if result.returncode or re.search(r"SCRIPT ERROR:|^ERROR:|^FAIL:|[1-9]\d* failures", result.stdout, re.MULTILINE):
        failed.append(suite)

# The balance browser's fight is a port of the rail in sim/battle.gd; hold it to the real one.
node = shutil.which("node")
if node:
    print("\nRunning the balance parity check", flush=True)
    result = subprocess.run([node, str(ROOT / "tools" / "data-browser" / "parity.mjs"), "--count", "300"],
                            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=600, env=dict(os.environ, GODOT_BIN=godot))
    print(result.stdout.strip()[-3000:], flush=True)
    if result.returncode:
        failed.append("balance parity (tools/data-browser/parity.mjs)")
else:
    print("\nSkipping the balance parity check: node was not found.", flush=True)

# The balance gate: the strongest rails the combo hunt can find against each bowl's best gems
# alone. It reads the last hunt while the content pack is unchanged and plays a quick one when
# it has moved on. A band over the limit is a warning unless --balance-strict.
if node and not args.no_balance:
    print("\nRunning the balance gate", flush=True)
    result = subprocess.run([node, str(ROOT / "tools" / "data-browser" / "balance.mjs"), "check", "--quick"],
                            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=3600)
    report = "\n".join(line.split("\r")[-1] for line in result.stdout.split("\n"))
    print(report.strip()[-4000:], flush=True)
    if result.returncode == 1 and not args.balance_strict:
        print("Balance gate: a band is over its limit (a warning; --balance-strict makes it a failure).", flush=True)
    elif result.returncode:
        failed.append("balance gate (tools/data-browser/balance.mjs check)")

if failed:
    sys.exit("Failed: " + ", ".join(failed))
print("\nAll Godot scenario suites passed.")
