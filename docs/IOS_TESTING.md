# iOS test builds (free, no Apple Developer account)

Every push to `main` that touches game files builds an unsigned `.ipa` on
GitHub Actions (`.github/workflows/ios.yml`) and puts it on the rolling
[`ios-latest`](https://github.com/xhonorate/godotdice/releases/tag/ios-latest)
release. SideStore on the phone signs it with a free Apple ID and installs it.
A build can also be started by hand: Actions → iOS build → Run workflow.

SideStore source URL (add once on the phone):

    https://github.com/xhonorate/godotdice/releases/download/ios-latest/source.json

## How the build works

1. `ios_preset.py` patches the CI copy of `export_presets.cfg`: Xcode project
   only, a placeholder Team ID, `config/version` as the version and the run
   number as the build number.
2. Godot exports the Xcode project; `xcodebuild` compiles it with signing off.
3. `Payload/DeepCut.app` is zipped into `DeepCut.ipa`; `sidestore_source.py`
   writes `source.json`; both go on the release with the app icon.

The iOS preset leaves out `addons/godotsteam` (it has no iOS library); the
game reads Steam through `Engine.has_singleton("Steam")`, so it plays offline.

## One-time phone setup

1. iPhone: Settings → Privacy & Security → Developer Mode → on (restarts).
2. Install SideStore with the official guide at https://docs.sidestore.io
   (it uses a computer once — the Mac or this Windows PC — plus the
   LocalDevVPN app from the App Store).
3. In SideStore: Sources → + → paste the source URL above → install Deep Cut.

## Limits of a free Apple ID

- Apps stop opening after 7 days: SideStore refreshes them (keep LocalDevVPN
  on, or open SideStore and tap Refresh All).
- 3 sideloaded apps at once, and SideStore is one of them.
- 10 new app IDs a week: keep the bundle ID `com.xhonorate.deepcut`.

## If an update does not show

The source marks each build by `buildVersion` (the run number). If SideStore
does not offer it, delete the source and add it again, or open the `.ipa`
link on the release page and share it to SideStore.
