English | [简体中文](README.md)

# ShakeToFind — Enlarge the cursor when you move fast (faster = bigger)

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue.svg)](https://github.com/WenKaiYang/ShakeToFind/releases)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0-purple.svg)](https://www.autohotkey.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/WenKaiYang/ShakeToFind?label=Release&color=green)](https://github.com/WenKaiYang/ShakeToFind/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/WenKaiYang/ShakeToFind/total?color=blue)](https://github.com/WenKaiYang/ShakeToFind/releases)

> **find my mouse / find the cursor / enlarge cursor / magnify mouse pointer / lost mouse position / cursor too small / cursor finder / mouse pointer zoom / bigger mouse pointer**
>
> A lightweight Windows fix for "where did my cursor go?" and "I can't see the pointer". The faster you move the mouse, the bigger the cursor gets.

![ShakeToFind icon](assets/icon/preview.png)

A "find my mouse" tool for Windows: once the mouse moves faster than normal, the pointer starts to grow; **the faster you move, the bigger it gets**, and as you slow down it continuously shrinks back to its normal size.

## Why you might want it

- **Multiple monitors / large displays / projectors**: the cursor jumps between screens with different scaling and is easy to lose.
- **Laptop trackpad + external display**: different DPI scales make the cursor tiny on one screen.
- **Presentations, screen recordings, tutorials**: the audience can't see where you're pointing.
- **For elderly users or low vision**: scale the cursor 4–6× so click targets are obvious.

## What it does

- Slow movement / standing still: normal cursor size, no interference.
- Above 2500 px/s: starts to enlarge (about 1.8×).
- At 6000 px/s: maximum zoom of 6×.
- In between, the scale changes continuously with speed — bigger when fast, smaller when slow, smoothly.
- The enlarged cursor follows the mouse in real time; it updates every 5 ms while visible, so it feels more responsive than usual.
- The current cursor shape is synced automatically (arrow / I-beam / hand).
- **The enlarged pointer replaces the real one**: only the magnified cursor is left on screen — you never see a small cursor and a big cursor at the same time.
- The overlay is click-through, never steals focus, and does not affect clicking.

## Features

| | |
| --- | --- |
| 🖱️ | Speed-driven zoom: faster = bigger, shrinks back when you slow down |
| ⛔ | The enlarged pointer replaces the real one — never a small cursor beside a big one |
| 🪟 | Click-through overlay: no focus stealing, no blocked clicks |
| 🔄 | Syncs the live cursor shape (arrow / I-beam / hand) |
| 🪶 | Lightweight: a single AutoHotkey script, clean install and uninstall |
| 🔒 | No administrator rights; installs under `%LOCALAPPDATA%`, never touches system folders |
| 🌐 | Fully local — **no network calls, no data collection** |
| 🎨 | Ships with a custom icon, consistent across installer, shortcuts and tray |
| ⚙️ | Sensitivity and zoom factor are plain parameters at the top of the script |

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

## Download & install

Grab the latest `ShakeToFind-Setup-<version>.exe` from [Releases](https://github.com/WenKaiYang/ShakeToFind/releases):

- Installs to `%LOCALAPPDATA%\Programs\ShakeToFind`, **no administrator rights required**.
- "Start with Windows" is checked by default; untick it in the installer's "Additional tasks" page.
- Uninstall: Windows Settings → Apps → ShakeToFind → Uninstall (or "Uninstall ShakeToFind" in the Start menu).
- Migrate: copy the installer to another PC and run it there.

> The installer is not code-signed, so SmartScreen may warn on first run — click "More info" → "Run anyway".

## Usage

- The installer enables auto-start by default: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ShakeToFind.lnk`
- Exit: right-click the ShakeToFind (magnifier) tray icon → Exit.
- After editing the script: right-click the ShakeToFind tray icon → Reload.
- Preview the zoom effect (installed version):

```powershell
& "$env:LOCALAPPDATA\Programs\ShakeToFind\AutoHotkey64.exe" "$env:LOCALAPPDATA\Programs\ShakeToFind\ShakeToFind.ahk" --demo
```

## FAQ

**Q: How is this different from the macOS "shake to enlarge the cursor" feature?**
A: On macOS it's a system feature triggered by shaking, with a fixed zoom factor. This is the Windows counterpart, but it scales continuously with movement speed — the faster you move, the bigger it gets. It's also more useful across mixed-DPI multi-monitor setups.

**Q: Does it interfere with clicking?**
A: No. The magnified layer is a click-through, focus-free overlay. It only appears when you move fast enough, and it tracks the real pointer exactly.

**Q: Is it safe? Will it upload anything?**
A: No. Everything runs locally in a single `ShakeToFind.ahk` file — no network requests, no data collection. The installer bundles AutoHotkey v2, so nothing needs to be pre-installed on the target PC.

**Q: Will it conflict with other mouse utilities?**
A: Unlikely. It only reads the mouse position and draws an overlay; it doesn't hook, inject or take over input. Running two such tools at once may cause overlapping layers, so pick one.

**Q: Why are the magnified edges less sharp than native rendering?**
A: Windows exposes no system-level cursor scaling API, so this uses GDI bitmap scaling with HALFTONE smoothing to approximate the macOS look — which leaves slight jaggies.

**Q: How do I make it more sensitive or more extreme?**
A: See "Tuning sensitivity / appearance" below.

## Similar tools

| Tool | Platform | How it works | Notes |
| --- | --- | --- | --- |
| **ShakeToFind** (this project) | Windows | Continuous zoom driven by movement speed | Bigger when faster, transparent, clean install |
| macOS shake-to-zoom | macOS | Native shake gesture | System-rendered, sharpest, zero latency |
| Windows Magnifier | Windows | Built-in OS magnifier | Magnifies the whole screen, heavier |
| PointerFocus | Windows | Blinks the pointer periodically | Uses blinking instead of enlarging |
| Crosshair | Cross-platform | Draws a crosshair at screen centre | Better for precise, fixed-position work |

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

## Icon

The installer, the Start-menu / startup shortcuts, the uninstall entry and the tray icon all share one brand icon: `assets\icon\ShakeToFind.ico` (10 sizes, 16–256).

It is a magnifier with an enlarged pointer: the lens means "find the mouse", the pointer inside means "the pointer that grows". The ice-white lens keeps it readable down to 16 px; the cyan→indigo rim and the amber handle end give it its identity.

To change colours or shapes, edit `assets\icon\build_icon.py` (requires Python + Pillow) and regenerate:

```powershell
python assets\icon\build_icon.py
```

This rewrites `assets\icon\ShakeToFind.ico` and the preview `assets\icon\preview.png`; then run `.\build.cmd` again.

## Project structure

- `ShakeToFind.ahk` — main script (source)
- `build.cmd` — one-command packaging script
- `assets\icon\` — brand icon: generator `build_icon.py`, multi-size `ShakeToFind.ico`, preview `preview.png`
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

## Contributing

Issues and pull requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Third-party components

- AutoHotkey v2 (GPLv2); its license is distributed with the installer (`license.txt`).

## License

This project is licensed under the [MIT License](LICENSE). The bundled AutoHotkey v2 runtime is distributed under its own GPLv2 license.

## Disable auto-start

Delete `ShakeToFind.lnk` from the Startup folder:

```powershell
Remove-Item "$env:APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ShakeToFind.lnk"
```
