<#
.SYNOPSIS
Release Deep Cut on itch.io: bump the version, export Windows and the web, and push both with butler.

.DESCRIPTION
Asks which part of the version to bump (major, minor or patch), stamps the new version into
project.godot, exports the "Windows Desktop" and "Web" presets to build\release\windows and
build\release\web, and pushes each folder with butler to its own channel of the itch.io project
named in tools\release\release.json. butler uploads only what changed since the last build, and
the itch app patches players' copies the same way. Every export is finished before anything is
pushed. If anything fails or is cancelled before the first push lands, project.godot is put back
as it was. See docs\RELEASES.md.

.PARAMETER Bump
major, minor or patch. Asked for when left out.

.PARAMETER Platform
all (the default), windows or web.

.PARAMETER Godot
The Godot 4.7.2 executable. Otherwise GODOT_BIN, godot on the PATH, or a
Godot_v4.7.2-stable_win64 executable on the Desktop, in Downloads or beside the project.

.PARAMETER Butler
butler.exe. Otherwise BUTLER_BIN, butler on the PATH, or the copy the itch app keeps.

.PARAMETER DryRun
Build everything and list what would be pushed, push nothing, and leave the version where it was.
#>
param(
    [ValidateSet("major", "minor", "patch")] [string] $Bump,
    [ValidateSet("all", "windows", "web")] [string] $Platform = "all",
    [string] $Godot,
    [string] $Butler,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"
$GodotVersion = "4.7.2.stable"
# What each platform is exported from, as what, and the template and files that prove it worked.
$Builds = [ordered]@{
    windows = @{ preset = "Windows Desktop"; file = "DeepCut.exe"; expect = @("DeepCut.exe", "DeepCut.pck"); template = "windows_release_x86_64.exe"; steam = $true }
    web = @{ preset = "Web"; file = "index.html"; expect = @("index.html", "index.wasm", "index.pck"); template = "web*_release.zip"; steam = $false }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$projectFile = Join-Path $root "project.godot"
$out = Join-Path $root "build\release"
$utf8 = New-Object System.Text.UTF8Encoding $false
$selected = if ($Platform -eq "all") { @($Builds.Keys) } else { @($Platform) }

function Write-Step([string] $text) {
    Write-Host ""
    Write-Host "== $text" -ForegroundColor Cyan
}

function Fail([string] $message) {
    Write-Host $message -ForegroundColor Red
    exit 1
}

function Find-Godot {
    $candidates = @($Godot, $env:GODOT_BIN)
    $onPath = Get-Command godot, godot4 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { $candidates += $onPath.Source }
    foreach ($dir in @((Split-Path $root), "$HOME\Desktop", "$HOME\Downloads")) {
        $candidates += @(Get-ChildItem -Path $dir -Filter "Godot_v4.7.2-stable_win64*.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    foreach ($path in $candidates) {
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        # The console build waits for the export and reports its exit code; the windowed one
        # returns at once.
        $console = $path -replace "(?<!_console)\.exe$", "_console.exe"
        if (Test-Path -LiteralPath $console -PathType Leaf) { return $console }
        return $path
    }
    Fail "Godot $GodotVersion was not found. Pass -Godot C:\path\to\Godot_v4.7.2-stable_win64_console.exe or set GODOT_BIN."
}

function Find-Butler {
    $candidates = @($Butler, $env:BUTLER_BIN)
    $onPath = Get-Command butler -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { $candidates += $onPath.Source }
    # The itch app keeps a copy of its own.
    $candidates += @(Get-ChildItem -Path (Join-Path $env:APPDATA "itch\broth\butler\versions\*\butler.exe") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | ForEach-Object { $_.FullName })
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) { return $path }
    }
    return $null
}

function Get-LiveVersion([string] $channel) {
    # The version a channel is serving now, as itch.io's public API reports it. When the API
    # will not say (nothing pushed yet, or a page it does not show), there is nothing to compare.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $uri = "https://api.itch.io/wharf/latest?target=$($config.itch_project)&channel_name=$channel"
        $latest = [string](Invoke-RestMethod -Uri $uri -UseBasicParsing -TimeoutSec 20).latest
        if ($latest -match "^\d+\.\d+\.\d+$") { return $latest }
    } catch { }
    return ""
}

# --- what is needed before anything changes --------------------------------------------------

$config = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "release.json") | ConvertFrom-Json
# The project as butler and the API name it, user/game, whether it was written that way or as
# the page's address.
$page = [regex]::Match([string]$config.itch_project, "^https?://([^./]+)\.itch\.io/([^/?#]+)")
if ($page.Success) { $config.itch_project = "$($page.Groups[1].Value)/$($page.Groups[2].Value)" }
$channels = @{}
foreach ($name in $selected) {
    $channels[$name] = [string]$config.channels.$name
    if (-not $channels[$name]) { Fail "tools\release\release.json names no channel for $name." }
}
$projectOk = [string]$config.itch_project -match "^[^/\s]+/[^/\s]+$" -and [string]$config.itch_project -notmatch "^your-"
if (-not $DryRun -and -not $projectOk) {
    Fail "Fill in itch_project in tools\release\release.json before the first release (docs\RELEASES.md says how)."
}

$godotExe = Find-Godot
$found = (& $godotExe --version | Out-String).Trim()
if (-not $found.StartsWith($GodotVersion)) {
    Fail "$godotExe is Godot $found; releases are built with Godot $GodotVersion."
}
$templates = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion"
foreach ($name in $selected) {
    if (-not (Test-Path -Path (Join-Path $templates $Builds[$name].template))) {
        Fail "The Godot $GodotVersion export templates for $name are not installed. In the Godot editor: Editor > Manage Export Templates > Download and Install. Then run this again."
    }
}

$butlerExe = Find-Butler
$live = @{}
if (-not $DryRun) {
    if (-not $butlerExe) {
        Fail "butler was not found. Install the itch app (it brings butler along), or download butler from https://itchio.itch.io/butler and put it on the PATH, or pass -Butler C:\path\to\butler.exe."
    }
    if (-not $env:BUTLER_API_KEY -and -not (Test-Path -LiteralPath (Join-Path $HOME ".config\itch\butler_creds"))) {
        Write-Step "Connecting butler to your itch.io account"
        & $butlerExe login | Out-Host
        if ($LASTEXITCODE -ne 0) { Fail "butler login did not finish." }
    }
    Write-Step "Checking $($config.itch_project) on itch.io"
    & $butlerExe status $config.itch_project | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Fail "butler could not open $($config.itch_project). Check itch_project in release.json and that the project page exists on itch.io (butler cannot create it). If the saved login has gone stale: butler logout, then butler login."
    }
    foreach ($name in $selected) { $live[$name] = Get-LiveVersion $channels[$name] }
}
$newest = ""
foreach ($v in $live.Values) { if ($v -and (-not $newest -or [version]$v -gt [version]$newest)) { $newest = $v } }

# --- the version -------------------------------------------------------------------------------

$original = [IO.File]::ReadAllText($projectFile)
$match = [regex]::Match($original, '(?m)^config/version="(\d+)\.(\d+)\.(\d+)"')
if (-not $match.Success) {
    Fail "project.godot has no config/version=""major.minor.patch"" under [application]."
}
$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$current = "$major.$minor.$patch"
$next = @{ patch = "$major.$minor.$($patch + 1)"; minor = "$major.$($minor + 1).0"; major = "$($major + 1).0.0" }

if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "Godot*" }) {
    Write-Warning "A Godot editor is open. It keeps the project settings in memory and can write the old version back into project.godot: reload the project (Project > Reload Current Project) after this finishes."
}
$kind = $Bump
if (-not $kind) {
    Write-Host ""
    Write-Host "Deep Cut is at $current$(if ($newest) { " (live: $newest)" })$(if ($DryRun) { ' - dry run, nothing is pushed' }). Releasing: $($selected -join ' and '). Which release is this?"
    Write-Host "  1) major  -> $($next.major)"
    Write-Host "  2) minor  -> $($next.minor)"
    Write-Host "  3) patch  -> $($next.patch)"
    $answer = (Read-Host "Choose 1-3 (anything else cancels)").Trim()
    $kind = @{ "1" = "patch"; "patch" = "patch"; "2" = "minor"; "minor" = "minor"; "3" = "major"; "major" = "major" }[$answer]
    if (-not $kind) {
        Write-Host "Cancelled. Nothing was changed."
        exit 0
    }
}
$version = $next[$kind]
if ($newest -and [version]$version -le [version]$newest) {
    Fail "$version is not newer than the live $newest. Was project.godot reverted (an open Godot editor writes its old settings back)? Set config/version to $newest and run this again."
}

# --- build, then push --------------------------------------------------------------------------

$published = @()
try {
    $stamped = $original.Remove($match.Index, $match.Length).Insert($match.Index, "config/version=""$version""")
    [IO.File]::WriteAllText($projectFile, $stamped, $utf8)
    Write-Host "project.godot: $current -> $version"

    New-Item -ItemType Directory -Force -Path $out | Out-Null
    # Keeps the editor from importing what is built here.
    [IO.File]::WriteAllText((Join-Path $out ".gdignore"), "")
    Write-Step "Importing"
    & $godotExe --headless --path $root --import | Out-Host

    foreach ($name in $selected) {
        $build = $Builds[$name]
        $dir = Join-Path $out $name
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Step "Exporting $($build.preset)"
        & $godotExe --headless --path $root --export-release $build.preset (Join-Path $dir $build.file) | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "The $name export failed (Godot exited with $LASTEXITCODE)." }
        foreach ($file in $build.expect) {
            if (-not (Test-Path -LiteralPath (Join-Path $dir $file))) { throw "The $name export did not write $file." }
        }
        $licenses = New-Item -ItemType Directory -Path (Join-Path $dir "licenses")
        Copy-Item -LiteralPath (Join-Path $root "licenses\GODOT_LICENSE.txt") -Destination $licenses.FullName
        if ($build.steam) {
            Copy-Item -LiteralPath (Join-Path $root "addons\godotsteam\license.md") -Destination (Join-Path $licenses.FullName "GODOTSTEAM_LICENSE.md")
        }
    }

    if ($DryRun) {
        foreach ($name in $selected) {
            if ($butlerExe) {
                Write-Step "What would be pushed to $($config.itch_project):$($channels[$name])"
                & $butlerExe push --dry-run (Join-Path $out $name) "$($config.itch_project):$($channels[$name])" --userversion $version | Out-Host
            }
        }
        Write-Host ""
        Write-Host "Dry run: $version is built in $out and nothing was pushed. project.godot stays at $current." -ForegroundColor Yellow
        exit 0
    }

    foreach ($name in $selected) {
        $target = "$($config.itch_project):$($channels[$name])"
        Write-Step "Pushing $name $version to $target"
        & $butlerExe push (Join-Path $out $name) $target --userversion $version | Out-Host
        if ($LASTEXITCODE -ne 0) {
            if ($published.Count -gt 0) {
                throw "butler push failed for $name (exit code $LASTEXITCODE), after $($published -join ' and ') went out at $version. Push it again by hand: ""$butlerExe"" push ""$(Join-Path $out $name)"" $target --userversion $version"
            }
            throw "butler push failed for $name (exit code $LASTEXITCODE)."
        }
        $published += $name
    }

    $user, $game = ([string]$config.itch_project).Split("/", 2)
    Write-Host ""
    Write-Host "Deep Cut $version is pushed to https://$user.itch.io/$game ($($published -join ' and '))." -ForegroundColor Green
    Write-Host "itch.io takes a minute or two to process it (butler status $($config.itch_project) shows when it is done); the itch app then updates everyone who has it installed."
    if ($published -contains "web" -and -not $live["web"]) {
        Write-Host "If this is the first web build: on the project's edit page, mark the $($channels['web']) upload 'This file will be played in the browser' and tick 'SharedArrayBuffer support' under Embed options (docs\RELEASES.md)." -ForegroundColor Yellow
    }
    Write-Host "Commit project.godot so the repository remembers $version."
} catch {
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    if ($published.Count -eq 0) {
        [IO.File]::WriteAllText($projectFile, $original, $utf8)
        Write-Host "project.godot is back at $current."
    }
}
