#!/usr/bin/env python3
"""Content Studio: a local web panel for authoring every entry in the content pack.

Run with:  python tools/content_studio/server.py        (then open the printed URL)

The studio edits `data/full_content.json`, which is the authored source of truth, and
writes `content/full_content.tres` alongside it because that is the file the game loads
at startup. Every save keeps a timestamped copy of the previous JSON under
`tools/content_studio/backups/`, so an edit is always one file copy away from undone.

Nothing here evaluates game rules. The registry of behaviours a new entry may borrow is
read straight out of `scripts/core/catalog.gd` and `scripts/core/combat.gd`, so the panel
can never offer a rule the engine does not actually implement.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import webbrowser
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
APP = Path(__file__).resolve().parent / "app"
BACKUPS = Path(__file__).resolve().parent / "backups"
JSON_PATH = ROOT / "data" / "full_content.json"
TRES_PATH = ROOT / "content" / "full_content.tres"
CATALOG = ROOT / "scripts" / "core" / "catalog.gd"
COMBAT = ROOT / "scripts" / "core" / "combat.gd"
PACK = ROOT / "scripts" / "core" / "content_pack.gd"
KEEP_BACKUPS = 30

MIME = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
        ".js": "text/javascript; charset=utf-8", ".json": "application/json",
        ".svg": "image/svg+xml", ".png": "image/png", ".ico": "image/x-icon"}


# --- reading the engine's own registries --------------------------------------

def _const_dict_keys(text: str, name: str) -> list[str]:
    """Top-level keys of a `const NAME: Dictionary = { ... }` block, by brace depth."""
    match = re.search(r"^const\s+%s\s*(?::\s*Dictionary\s*)?=\s*\{" % name, text, re.MULTILINE)
    if not match:
        return []
    index = match.end()
    depth = 1
    keys: list[str] = []
    in_string = False
    start = index
    while index < len(text) and depth > 0:
        char = text[index]
        if in_string:
            if char == "\\":
                index += 2
                continue
            if char == '"':
                in_string = False
                token = text[start:index]
                if depth == 1 and re.match(r"\s*:", text[index + 1:index + 8]):
                    keys.append(token)
        elif char == '"':
            in_string = True
            start = index + 1
        elif char in "{[(":
            depth += 1
        elif char in "}])":
            depth -= 1
        index += 1
    return keys


def _match_cases(text: str, anchor: str) -> list[str]:
    """Case labels of the `match` block that starts at `anchor`, e.g. `match str(actor.key):`."""
    start = text.find(anchor)
    if start < 0:
        return []
    body = text[start + len(anchor):]
    labels: list[str] = []
    base_indent = None
    for line in body.splitlines()[1:]:
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip("\t"))
        if base_indent is None:
            base_indent = indent
        if indent < base_indent:
            break
        if indent == base_indent and line.rstrip().endswith(":"):
            for token in re.findall(r'"([A-Z_0-9]+)"', line):
                labels.append(token)
    return labels


def _const_array(text: str, name: str) -> list[str]:
    match = re.search(r"^const\s+%s\s*(?::\s*Array\s*)?=\s*\[(.*?)\]" % name, text, re.MULTILINE | re.DOTALL)
    if not match:
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def read_registry() -> dict:
    """What the compiled rules actually implement, so the panel offers nothing else."""
    catalog = CATALOG.read_text(encoding="utf-8")
    combat = COMBAT.read_text(encoding="utf-8")
    pack = PACK.read_text(encoding="utf-8")
    traits = re.findall(r'"([A-Z_]+)"', re.search(
        r'entry\.get\("trait",""\) in \[(.*?)\]', pack, re.DOTALL).group(1)) if 'entry.get("trait"' in pack else []
    return {
        "heroes": _const_dict_keys(catalog, "HEROES"),
        "skills": _const_dict_keys(catalog, "SKILLS"),
        "dice": _const_dict_keys(catalog, "DICE"),
        "relics": _const_dict_keys(catalog, "RELICS"),
        "enemies": _const_dict_keys(catalog, "ENEMIES"),
        "events": _const_dict_keys(catalog, "EVENTS"),
        # Behaviours a brand-new entry can borrow.
        "evaluators": sorted(set(_match_cases(combat, "\tmatch rule:"))),
        "enemy_ai": sorted(set(_match_cases(combat, '\tmatch str(actor.get("ai",actor.key)):'))),
        "traits": traits or ["STAND_FIRM", "CALCULATED_RISK", "SECOND_THOUGHT"],
        "colors": _const_array(pack, "COLORS"),
        "targets": _const_array(pack, "TARGETS"),
        "tags": _const_array(pack, "TAGS"),
        "shapes": ["D4", "D6", "D8", "D10", "D12", "D20"],
        "statuses": ["stun", "poison", "resolve"],
        "loot_generators": ["depth_luck_v1", "act_tier_v1"],
        "mine_rooms": _const_array(pack, "MINE_ROOMS"),
        "gem_colors": _gem_colors(catalog),
        "die_unlock": _die_unlock(catalog),
        # The numbers the gem panel spells out, read from the rules build rather than copied.
        "bulwark_block": _const_numbers(catalog, "BULWARK_BLOCK"),
        "bulwark_stun": _const_numbers(catalog, "BULWARK_STUN"),
        "cut_names": _const_array(catalog, "CUT_NAMES"),
        "clarity_names": _const_array(catalog, "CLARITY_NAMES"),
        "multistrike_hit": (_const_numbers(combat, "MULTISTRIKE_HIT") or [4])[0],
        "blessing_gold": (_const_numbers(combat, "BLESSING_GOLD") or [3])[0],
        "wager_ceiling": (_const_numbers(combat, "WAGER_CEILING") or [24])[0],
    }


def _const_numbers(text: str, name: str) -> list[int]:
    match = re.search(r"^const\s+%s(?::\s*\w+\s*)?=\s*(\[[^\]]*\]|-?\d+)" % name, text, re.MULTILINE)
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))] if match else []


def _die_unlock(catalog: str) -> dict:
    """When a die does not say when it reaches the shop, the act the build falls back to."""
    match = re.search(r"const DIE_UNLOCK: Dictionary = \{(.*?)\}\}", catalog, re.DOTALL)
    if not match:
        return {}
    found: dict = {}
    for key, body in re.findall(r'"([A-Z_0-9]+)":\s*\{([^}]*)\}', match.group(1) + "}"):
        entry = {name: int(value) for name, value in re.findall(r'"(act|room)":\s*(\d+)', body)}
        if entry:
            found[key] = entry
    return found


def _gem_colors(catalog: str) -> dict:
    colors: dict = {}
    match = re.search(r"const GEM_COLORS: Dictionary = \{(.*?)\n\}", catalog, re.DOTALL)
    if match:
        for key, name, hexcode, role in re.findall(
                r'"([A-Z]+)": \{"name": "([^"]+)", "hex": "([^"]+)", "role": "([^"]+)"\}', match.group(1)):
            colors[key] = {"name": name, "hex": hexcode, "role": role}
    return colors


# --- writing the pack ---------------------------------------------------------

def _write_lf(path: Path, text: str) -> None:
    """The repo normalises every text file to LF; Python would write CRLF on Windows."""
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def gd_literal(value) -> str:
    """A Variant as Godot's own text-resource syntax, matching `ResourceSaver` output."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return str(int(value)) if value == int(value) else repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "[" + ", ".join(gd_literal(item) for item in value) + "]"
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = ['"%s": %s' % (key, gd_literal(value[key])) for key in sorted(value, key=str)]
        return "{\n" + ",\n".join(lines) + "\n}"
    raise TypeError("Unsupported value in content pack: %r" % (value,))


def write_tres(content: dict) -> None:
    """The .tres the game loads at startup, written from the same data as the JSON."""
    sections = ["heroes", "skills", "dice", "relics", "enemies", "events", "profiles", "statuses", "mines"]
    existing = TRES_PATH.read_text(encoding="utf-8") if TRES_PATH.exists() else ""
    script_id = re.search(r'id="([^"]+)"', existing).group(1) if 'ext_resource' in existing else "1_k7jmp"
    out = ['[gd_resource type="Resource" script_class="RogueContentPack" format=3]', "",
           '[ext_resource type="Script" path="res://scripts/core/content_pack.gd" id="%s"]' % script_id,
           "", "[resource]", 'script = ExtResource("%s")' % script_id]
    for key in ["schema_version", "content_version", "pack_id"]:
        if key in content:
            out.append("%s = %s" % (key, gd_literal(content[key])))
    for section in sections:
        out.append("%s = %s" % (section, gd_literal(content.get(section, {}))))
    TRES_PATH.parent.mkdir(parents=True, exist_ok=True)
    _write_lf(TRES_PATH, "\n".join(out) + "\n")


def save_content(content: dict) -> dict:
    BACKUPS.mkdir(parents=True, exist_ok=True)
    if JSON_PATH.exists():
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(JSON_PATH, BACKUPS / ("full_content-%s.json" % stamp))
        old = sorted(BACKUPS.glob("full_content-*.json"))
        for path in old[:-KEEP_BACKUPS]:
            path.unlink()
    text = json.dumps(content, indent="\t", ensure_ascii=False, sort_keys=True) + "\n"
    temporary = JSON_PATH.with_suffix(".json.tmp")
    _write_lf(temporary, text)
    temporary.replace(JSON_PATH)
    write_tres(content)
    return {"saved": True, "json": str(JSON_PATH.relative_to(ROOT)),
            "tres": str(TRES_PATH.relative_to(ROOT)), "mtime": JSON_PATH.stat().st_mtime,
            "backups": len(list(BACKUPS.glob("full_content-*.json")))}


# --- optional engine-side validation ------------------------------------------

def find_godot(explicit: str | None = None) -> str | None:
    candidates = [explicit, os.environ.get("GODOT_BIN"), shutil.which("godot"), shutil.which("godot4")]
    settings = ROOT / ".vscode" / "settings.json"
    if settings.exists():
        try:
            candidates.append(json.loads(settings.read_text(encoding="utf-8")).get("godotTools.editorPath.godot4"))
        except (ValueError, OSError):
            pass
    candidates += [str(Path.home() / "Desktop" / "Godot_v4.7.1-stable_win64.exe"),
                   "/Applications/Godot.app/Contents/MacOS/Godot"]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    return None


def run_engine_validation(godot: str) -> dict:
    script = Path(__file__).resolve().parent / "validate_pack.gd"
    try:
        result = subprocess.run([godot, "--headless", "--path", str(ROOT), "--script", str(script)],
                                cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=120)
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"ok": False, "errors": ["Could not run Godot: %s" % error], "output": ""}
    errors = [line[len("CONTENT-ERROR: "):] for line in result.stdout.splitlines()
              if line.startswith("CONTENT-ERROR: ")]
    ok = "CONTENT-OK" in result.stdout and not errors
    return {"ok": ok, "errors": errors, "output": result.stdout.strip()[-4000:]}


# --- http ---------------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    server_version = "ContentStudio/1.0"
    godot_path: str | None = None

    def log_message(self, fmt, *args):  # quieter console
        if "/api/" in (args[0] if args else ""):
            sys.stderr.write("  %s\n" % (fmt % args))

    def _send(self, code: int, body: bytes, mime: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, payload: dict, code: int = 200) -> None:
        self._send(code, json.dumps(payload).encode("utf-8"), "application/json")

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        try:
            if path == "/api/bootstrap":
                content = json.loads(JSON_PATH.read_text(encoding="utf-8"))
                self._json({"content": content, "registry": read_registry(),
                            "meta": {"json": str(JSON_PATH.relative_to(ROOT)),
                                     "tres": str(TRES_PATH.relative_to(ROOT)),
                                     "mtime": JSON_PATH.stat().st_mtime,
                                     "godot": self.godot_path or ""}})
                return
            if path == "/api/backups":
                names = sorted((p.name for p in BACKUPS.glob("full_content-*.json")), reverse=True)
                self._json({"backups": names})
                return
            self._static(path)
        except Exception as error:  # a studio that 500s silently is worse than one that says why
            self._json({"error": "%s: %s" % (type(error).__name__, error)}, 500)

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        try:
            if path == "/api/save":
                payload = self._body()
                content = payload.get("content")
                if not isinstance(content, dict) or "skills" not in content:
                    self._json({"error": "Refusing to save a pack with no sections"}, 400)
                    return
                self._json(save_content(content))
                return
            if path == "/api/validate":
                if not self.godot_path:
                    self._json({"ok": False, "skipped": True,
                                "errors": ["Godot was not found. Start the studio with --godot <path> "
                                           "or set GODOT_BIN to run engine-side validation."]})
                    return
                self._json(run_engine_validation(self.godot_path))
                return
            if path == "/api/restore":
                name = str(self._body().get("name", ""))
                source = BACKUPS / name
                if not name.startswith("full_content-") or not source.is_file():
                    self._json({"error": "Unknown backup"}, 400)
                    return
                content = json.loads(source.read_text(encoding="utf-8"))
                result = save_content(content)
                result["content"] = content
                self._json(result)
                return
            self._json({"error": "Unknown endpoint"}, 404)
        except Exception as error:
            self._json({"error": "%s: %s" % (type(error).__name__, error)}, 500)

    def _static(self, path: str) -> None:
        relative = "index.html" if path in ("/", "") else path.lstrip("/")
        target = (APP / relative).resolve()
        if not str(target).startswith(str(APP.resolve())) or not target.is_file():
            self._send(404, b"Not found", "text/plain; charset=utf-8")
            return
        self._send(200, target.read_bytes(), MIME.get(target.suffix, "application/octet-stream"))


def free_port(preferred: int) -> int:
    for port in range(preferred, preferred + 20):
        with socket.socket() as probe:
            if probe.connect_ex(("127.0.0.1", port)) != 0:
                return port
    return preferred


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8777)
    parser.add_argument("--godot", default=None, help="Godot 4 binary, for engine-side validation")
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()

    if not JSON_PATH.exists():
        return "Missing %s. Run the content export first." % JSON_PATH
    Handler.godot_path = find_godot(args.godot)
    port = free_port(args.port)
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = "http://127.0.0.1:%d/" % port
    print("Content Studio  ->  %s" % url)
    print("  editing   %s" % JSON_PATH.relative_to(ROOT))
    print("  writing   %s on save" % TRES_PATH.relative_to(ROOT))
    print("  Godot     %s" % (Handler.godot_path or "not found (engine validation disabled)"))
    print("  Ctrl+C to stop.")
    if not args.no_browser:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
