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

for suite in ["test_dice.gd", "test_stones.gd", "test_battle.gd", "test_descent.gd", "test_net.gd", "test_view.gd", "test_screens.gd"]:
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

if failed:
    sys.exit("Failed: " + ", ".join(failed))
print("\nAll Godot scenario suites passed.")
