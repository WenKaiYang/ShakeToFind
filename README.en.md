English | [简体中文](README.md)

# ShakeToFind — Enlarge the cursor when you move fast (faster = bigger)

A "find my mouse" tool for Windows: once the mouse moves faster than normal, the pointer starts to grow; **the faster you move, the bigger it gets**, and as you slow down it continuously shrinks back to its normal size.

## What it does

- Slow movement / standing still: normal cursor size, no interference.
- Above 2500 px/s: starts to enlarge (about 1.8×).
- At 6000 px/s: maximum zoom of 6×.
- In between, the scale changes continuously with speed — bigger when fast, smaller when slow, smoothly.
- The enlarged cursor follows the mouse in real time; it updates every 5 ms while visible, so it feels more responsive than usual.
- The current cursor shape is synced automatically (arrow / I-beam / hand).
- The overlay is click-through, never steals focus, and does not affect clicking.

## Compared with macOS

| Aspect | macOS | This tool |
| --- | --- | --- |
| Trigger | Shake the mouse | Movement speed (this tool's design) |
| Zoom rule | Fixed multiplier | Continuously varies with speed (this tool's design) |
| Following | Rendered by the system directly, zero latency | Overlay follows the mouse, ~5 ms updates (still a tiny delay) |
| Rendering | System-level smooth scaling, true transparency | GDI bitmap scaling + HALFTONE smoothing + color-key transparency |
| Cursor shape | Always the real current cursor | Synced in real time |
| Hotspot / click-through | Same | Same |

macOS scales the cursor itself at the system level; Windows has no equivalent API, so this tool approximates it with a click-through overlay that follows the mouse in real time. Because the cursor is a scaled bitmap, its edges are not as sharp as system rendering.

## Install / Uninstall

- Install: run `dist\ShakeToFind-Setup-<version>.exe` (see `installer/BUILD.md` for building). It installs to `%LOCALAPPDATA%\Programs\ShakeToFind` without administrator rights; "start with Windows" is checked by default.
- Uninstall: Windows Settings → Apps → ShakeToFind → Uninstall (or "Uninstall ShakeToFind" in the Start menu).
- Migrate: copy the installer to another PC and run it there.

## Usage

- The installer enables auto-start by default: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ShakeToFind.lnk`
- Exit: right-click the AutoHotkey (H) tray icon → Exit.
- After editing the script: right-click the tray icon → Reload.
- Preview the zoom effect (installed version):

```powershell
& "$env:LOCALAPPDATA\Programs\ShakeToFind\AutoHotkey64.exe" "$env:LOCALAPPDATA\Programs\ShakeToFind\ShakeToFind.ahk" --demo
```

## Tuning sensitivity / appearance

Open `ShakeToFind.ahk` in Notepad, change the parameters at the top, save, then Reload:

| Parameter | Default | Description |
| --- | --- | --- |
| `SPEED_WINDOW` | 120 | Speed sampling window (ms) |
| `SPEED_MIN` | 2500 | Speed (px/s) above which zoom starts; lower = more sensitive |
| `SPEED_FULL` | 6000 | Speed at which maximum zoom is reached; lower = easier to reach max |
| `SCALE_MIN` | 1.8 | Zoom factor just above the threshold |
| `SCALE_MAX` | 6.0 | Maximum zoom factor |
| `SCALE_SMOOTH` | 0.35 | Size smoothing factor (0–1, higher = more responsive) |
| `DEBUG` | false | When true, speed/scale are logged to `trigger.log` |

> If it triggers too easily, raise `SPEED_MIN` (e.g. 3500); if a hard flick still does not trigger it, lower it (e.g. 1500).
> For a more dramatic effect set `SCALE_MAX` to 8; if it feels too large, set it to 4.

## Project structure

- `ShakeToFind.ahk` — main script (source)
- `build.cmd` — one-command packaging script
- `installer\` — Inno Setup script and build instructions
- `dist\` — local build output (not committed)

After installation the files live in `%LOCALAPPDATA%\Programs\ShakeToFind\`: the script, a portable AutoHotkey v2, and `license.txt`.

## Build

Run one command from the project root:

```powershell
.\build.cmd            # use the default version from installer\ShakeToFind.iss
.\build.cmd 1.0.1      # set an explicit version
```

The installer is written to `dist\ShakeToFind-Setup-<version>.exe`.

The first build requires [Inno Setup 6](https://jrsoftware.org/isdl.php) and the portable AutoHotkey v2 files in `installer\payload\`; see `installer/BUILD.md`.

> In PowerShell use `.\build.cmd`; in cmd simply type `build.cmd`.

## Third-party components

- AutoHotkey v2 (GPLv2); its license is distributed with the installer (`license.txt`).

## Disable auto-start

Delete `ShakeToFind.lnk` from the Startup folder:

```powershell
Remove-Item "$env:APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ShakeToFind.lnk"
```
