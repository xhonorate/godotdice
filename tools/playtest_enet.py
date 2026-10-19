#!/usr/bin/env python3
"""Run separate Godot host/guest processes and compare every mirrored revision."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def unexpected_refusals(report):
    # A guest can put their pick down just after another player empties the last spot.
    # The host has already advanced the room, so refusing that stale action is correct.
    return [entry for seat in report["refusals"] for entry in seat
            if not (entry["message"] == "there is no rock to walk away from"
                    and '"kind":"stop_mining"' in entry["command"])]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
    parser.add_argument("--players", default="2,3,4")
    parser.add_argument("--seeds", default="4242,4243,4244,4245,4246,4247,4248,4249")
    parser.add_argument("--mine", default="QUARRY")
    parser.add_argument("--mode", default="new", choices=["new", "rejoin", "traversal"])
    parser.add_argument("--output", default="build/playtest-enet")
    args = parser.parse_args()
    candidates = [args.godot, shutil.which("godot"), shutil.which("godot4"),
                  "/Applications/Godot.app/Contents/MacOS/Godot"]
    godot = next((str(path) for path in candidates if path and Path(path).is_file()), None)
    if not godot:
        sys.exit("Godot 4.7.2 was not found. Use --godot /path/to/Godot or set GODOT_BIN.")
    version = subprocess.check_output([godot, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable"):
        sys.exit("This project's deterministic replay contract requires Godot 4.7.2 stable.")
    counts = [int(count) for count in args.players.split(",")]
    if any(count not in (2, 3, 4) for count in counts):
        parser.error("--players must contain party sizes from 2 to 4")
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for count in counts:
        for seed in map(int, args.seeds.split(",")):
            folder = output / f"{args.mine.lower()}-{args.mode}-{count}p-{seed}-{time.time_ns()}"
            folder.mkdir()
            workers, logs = [], []
            port = 25000 + (os.getpid() % 20000)
            for seat in range(count):
                log = open(folder / f"seat{seat}.log", "w")
                logs.append(log)
                workers.append(subprocess.Popen([godot, "--headless", "--path", str(ROOT), "--script", "tools/playtest_enet.gd", "--", str(seat), str(count), str(port), str(seed), str(folder), args.mine, args.mode], stdout=log, stderr=subprocess.STDOUT))
                if seat == 0:
                    time.sleep(0.3)
            deadline = time.monotonic() + 190
            while any(worker.poll() is None for worker in workers) and time.monotonic() < deadline:
                time.sleep(0.1)
            for worker in workers:
                if worker.poll() is None:
                    worker.kill()
                worker.wait()
            for log in logs:
                log.close()
            results = [json.loads((folder / f"seat{seat}-run.json").read_text()) if (folder / f"seat{seat}-run.json").exists() else {} for seat in range(count)]
            returned = [bool(json.loads((folder / f"seat{seat}-done.json").read_text()).get("returned", False))
                        if (folder / f"seat{seat}-done.json").exists() else False for seat in range(count)]
            mismatches = []
            host_hashes = results[0].get("hashes", {})
            compared = 0
            for seat, guest in enumerate(results[1:], 1):
                for revision, digest in guest.get("hashes", {}).items():
                    compared += 1
                    if host_hashes.get(revision) != digest:
                        mismatches.append([seat, revision])
            console_errors = []
            for seat in range(count):
                for line in (folder / f"seat{seat}.log").read_text().splitlines():
                    if "SCRIPT ERROR" in line or line.startswith("ERROR:") or line.startswith("WARNING:"):
                        console_errors.append([seat, line])
            report = {"players": count, "seed": seed, "mine": args.mine, "mode": args.mode,
                      "depth": results[0].get("depth"), "outcome": results[0].get("outcome"),
                      "compared": compared, "mismatches": mismatches, "console_errors": console_errors,
                      "commands": sum(r.get("commands", 0) for r in results),
                      "refusals": [r.get("refusals", []) for r in results], "errors": [r.get("errors", []) for r in results],
                      "exits": [w.returncode for w in workers], "returned": returned,
                      "missing_results": [seat for seat, r in enumerate(results) if not r.get("hashes")],
                      "coverage": results[0].get("coverage", {}), "folder": str(folder)}
            reports.append(report)
            print(json.dumps({k: v for k, v in report.items() if k not in ("coverage", "folder")}), flush=True)
            (output / "summary.json").write_text(json.dumps(reports, indent=2))
    return 1 if any(r["mismatches"] or r["console_errors"] or r["missing_results"] or not all(r["returned"])
                   or any(r["exits"]) or any(r["errors"]) or unexpected_refusals(r) for r in reports) else 0


if __name__ == "__main__":
    raise SystemExit(main())
