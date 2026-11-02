"""Write the SideStore (AltStore-format) source that lists the latest build.

SideStore reads this file from the rolling `ios-latest` release; a new
build number shows up on the phone as an update.

usage: sidestore_source.py <out.json> <ipa> <short_version> <build> <release_base_url>
"""
import datetime
import json
import os
import sys

out, ipa, short_version, build, base = sys.argv[1:6]
date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
size = os.path.getsize(ipa)
download = base + "/" + os.path.basename(ipa)
description = "Test build %s (%s) of Deep Cut." % (build, os.environ.get("GITHUB_SHA", "")[:7])

version = {
    "version": short_version,
    "buildVersion": build,
    "date": date,
    "localizedDescription": description,
    "downloadURL": download,
    "size": size,
    "minOSVersion": "15.0",
}
source = {
    "name": "Deep Cut test builds",
    "identifier": "com.xhonorate.deepcut.source",
    "apps": [{
        "name": "Deep Cut",
        "bundleIdentifier": "com.xhonorate.deepcut",
        "developerName": "xhonorate",
        "subtitle": "Test builds",
        "localizedDescription": "Test builds of Deep Cut, built by GitHub Actions on every push to main.",
        "iconURL": base + "/icon.png",
        "versions": [version],
        # Older SideStore releases read the flat fields instead of versions[].
        "version": short_version,
        "versionDate": date,
        "versionDescription": description,
        "downloadURL": download,
        "size": size,
    }],
    "news": [],
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(source, f, indent=2)
print("source:", download, size, "bytes, build", build)
