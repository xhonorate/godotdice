# Releases

Deep Cut is released on one itch.io page: a Windows download, which the **itch app** installs, launches and keeps up to date, and a web version played right on the page. One command bumps the version, exports both and pushes each with **butler**, itch's upload tool, to a channel of its own.

| Where | What |
|---|---|
| `project.godot`, `application/config/version` | The version, `major.minor.patch`. The workshop shows it faintly in its bottom-right corner, the export stamps it into `DeepCut.exe`'s file properties, and itch.io shows it beside each upload. |
| `export_presets.cfg` | **Windows Desktop** and **Web**. Both leave out `build/`, `tools/` and `tests/`, none of which the game loads. |
| `tools/release/deploy.cmd` | Runs `deploy.ps1` past PowerShell's execution policy. Double-click it or run it from a terminal. |
| `tools/release/deploy.ps1` | The release itself (below). |
| `tools/release/release.json` | The itch.io project (`user/game`, or the page's address) and the channel each platform goes to. |

## One-time setup

1. **Export templates.** In the Godot 4.7.2 editor: Editor > Manage Export Templates > Download and Install. That brings the Windows and Web templates both.
2. **The itch.io page.** Dashboard > Create new project (or edit the one there).
   - **Kind of project: HTML.** That is what lets the page run the web build; the Windows download sits on the same page below it. itch.io takes payments on an HTML page only as donations, so if Deep Cut is ever sold there, the page becomes Downloadable and the web build moves to a page of its own.
   - **Visibility & access:** Draft while setting up (only you, and anyone with its secret link). For a private test, Restricted: testers get a download key (Distribute > Download keys) to attach to their itch account, which is also what lets the itch app see the game; a password can open the page in a browser as well, and can go in the link itself. Public when it is ready for everyone.
   - Save. butler cannot create a project, only push to one that exists.
3. **butler.** The [itch app](https://itch.io/app) brings butler with it, and `deploy.ps1` finds that copy on its own. The first real release runs `butler login`: a browser window asks you to allow it, and the key is kept in `%USERPROFILE%\.config\itch\butler_creds`.
4. **`tools/release/release.json`.** `itch_project` is the page (`xhonorate/deep-cut` or `https://xhonorate.itch.io/deep-cut`); `channels` names where each platform goes. `windows` tags its upload as Windows by its name alone.
5. **After the first release,** on the project's edit page:
   - **Uploads:** on the `html5` upload, tick **This file will be played in the browser**.
   - **Embed options:** a viewport of **1280 × 720** (the game scales itself to whatever it is given); **Fullscreen button** on; and under Frame options, **SharedArrayBuffer support** on. The web build runs on threads, which browsers allow only with that switched on; without it the page shows an error instead of the game. Leave Mobile friendly off: the game wants a mouse and a wide screen.

## Releasing

```
tools\release\deploy.cmd                      # asks: patch, minor or major; releases Windows and the web
tools\release\deploy.cmd -Bump patch          # no question
tools\release\deploy.cmd -Platform web        # just one of them: windows or web
tools\release\deploy.cmd -DryRun              # build it all and list what would be pushed; push nothing, version unchanged
tools\release\deploy.cmd -Godot C:\path\to\Godot_v4.7.2-stable_win64_console.exe -Butler C:\path\to\butler.exe
```

In order, `deploy.ps1`:

1. Checks everything it will need before it changes anything: `release.json`; Godot 4.7.2 (from `-Godot`, `GODOT_BIN`, the PATH, or the Desktop, Downloads or the folder above the project); the export templates; butler (from `-Butler`, `BUTLER_BIN`, the PATH, or the itch app's copy); butler's login; and the project on itch.io (`butler status`, which also prints what is up now).
2. Asks which part of the version to bump and writes the new one into `project.godot`. When itch.io's API reports what is live, it refuses a version that is not newer.
3. Imports, then exports each platform to `build\release\windows` and `build\release\web`, with the licenses beside them. Every export is finished before anything is pushed.
4. Pushes each folder: `butler push build\release\<platform> <itch_project>:<channel> --userversion <version>`. butler sends only what changed since the last build, so a small release is a small upload.

If anything fails or is cancelled (Ctrl+C included) before the first push lands, `project.godot` is put back as it was, and the next run offers the same version again. If Windows goes out and the web push then fails, the version stays, and the script prints the one `butler push` line that finishes the job. itch.io takes a minute or two to process a build (`butler status <itch_project>` shows when); then the page serves it and the itch app updates everyone who has the game installed. Commit `project.godot` after a release so the repository remembers the version.

An open Godot editor holds the project settings in memory and can write the old version back into `project.godot` the next time it saves them. The script warns when an editor is running; reload the project (Project > Reload Current Project) after a release.

## For players

- **The itch app** (Windows; the way to recommend): install it from [itch.io/app](https://itch.io/app), open Deep Cut's page in it, press Install, then Launch. Every release after that arrives as a patch in the background.
- **The browser:** press Run game on the page. Chrome, Edge and Firefox on a desktop or laptop play it in the page; Safari opens it in a window of its own. The first load fetches about 87 MB, which the browser keeps afterwards.
- **A plain download:** the Windows zip from the page, unzipped anywhere, run `DeepCut.exe`. Windows may warn on the first run because the game is not code-signed (More info, then Run anyway), and it does not update itself.

Saves of the Windows game live in `%APPDATA%\DeepCut`, outside the game's folder, so updates never touch them. Saves of the web version live in that browser's storage for itch.io's game domain: they last from one release to the next in the same browser, but are separate from the Windows game's and are lost if the player clears their site data.

## How the web version differs

- **The renderer.** Browsers get Godot's Compatibility renderer (WebGL 2), not Forward+. The rooms, creatures, stones and lights are all there, but there is no ink outline pass (the Outlines setting does nothing) and no volumetric fog or ground mist, so the mine reads darker and flatter. `looks.gd` and `chamber.gd` skip those two under Compatibility rather than build what cannot draw.
- **The fonts.** The interface asks the system for its faces (Palatino or Georgia for titles, Segoe UI for text), and a browser has no system fonts to give, so the web version is set entirely in the engine's own sans. Shipping the font files in the project would fix that here and on any machine without them.
- **Co-op.** Steam and LAN play are not available in a browser; the web version is solo. Co-op needs the Windows download.
- **Threads.** The Web preset is built with thread support, as the Windows game is: sounds are synthesized in the background while the workshop is up. That is what needs SharedArrayBuffer support on the page. Turning Thread Support off in the Web preset makes that switch unnecessary (and lets Safari play in the page), at a price: each of the 77 sounds is then made the first time it plays, which takes 20 to 150 ms each on a desktop and longer in a browser, enough to hitch.

## What must not change

- **The channel names.** A different channel is a different upload on itch.io: anyone who installed the old one stays on it and stops getting updates.
- **The project.** If its address on itch.io changes, change `itch_project` with it.

When Deep Cut goes on Steam, Steam does the Windows half of this itself, and that push in `deploy.ps1` becomes a `steamcmd` upload.
