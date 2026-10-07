@echo off
rem Release Deep Cut on itch.io, Windows and web: bump the version, export and push with butler. See docs\RELEASES.md.
rem Arguments pass through: -Bump patch, -Platform web, -DryRun, -Godot C:\path\to\Godot.exe, -Butler C:\path\to\butler.exe
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
set "status=%errorlevel%"
rem Opened by a double-click (cmd /c), keep the window up long enough to read how it went.
for %%a in (%cmdcmdline%) do if /i "%%~a"=="/c" (pause & goto done)
:done
exit /b %status%
