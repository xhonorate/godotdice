"""Point the iOS export preset at an unsigned CI build.

Godot only writes the Xcode project (export_project_only); the workflow
compiles it unsigned and SideStore signs it on the phone with the owner's
free Apple ID. Godot still wants a Team ID to fill in the project, so a
placeholder goes in. Run on the CI copy of export_presets.cfg only.

usage: ios_preset.py export_presets.cfg <short_version> <build_number>
"""
import re
import sys

path, short_version, build = sys.argv[1:4]
text = open(path, encoding="utf-8").read()

# The iOS preset's options section: find "[preset.N]" whose name is iOS.
match = re.search(r'^\[preset\.(\d+)\]\s*\n\s*name="iOS"', text, re.M)
if not match:
    sys.exit("no iOS preset in " + path)
header = "[preset.%s.options]" % match.group(1)
start = text.index(header)
end = text.find("\n[preset.", start + len(header))
end = len(text) if end < 0 else end
section = text[start:end]

overrides = {
    "application/export_project_only": "true",
    "application/app_store_team_id": '"ABCDE12345"',
    "application/short_version": '"%s"' % short_version,
    "application/version": '"%s"' % build,
}
for key, value in overrides.items():
    pattern = re.compile(r"^%s=.*$" % re.escape(key), re.M)
    if pattern.search(section):
        section = pattern.sub(lambda _m: "%s=%s" % (key, value), section)
    else:
        section = section.rstrip("\n") + "\n%s=%s\n" % (key, value)

open(path, "w", encoding="utf-8", newline="").write(text[:start] + section + text[end:])
print("iOS preset:", ", ".join("%s=%s" % kv for kv in overrides.items()))
