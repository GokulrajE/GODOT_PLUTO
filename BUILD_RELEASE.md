# Build and package PLUTO

Run from the project folder on Windows. Requires Python 3, PyInstaller (`python -m pip install pyinstaller`), Godot 4.6.2 and its export templates.

1. Set `config/version` in `project.godot` to the new release version, for example `1.0.7`.
2. Close running project instances before exporting.
3. Build and package both Windows and Raspberry Pi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/update/build-release.ps1 -GodotPath "D:\Godot_v4.6.2-stable_win64_console.exe"
```

Add `-Platform windows` or `-Platform pi` to build only one platform. Change the Godot path if installed elsewhere. The command works from Command Prompt or PowerShell.

The script reads the project version, builds the Windows updater helper when needed, exports the game, and creates the ZIP, `app-release.json` and checksum. Existing version folders are never overwritten.

For version 1.0.7, outputs are:

```text
builds/releases/v1.0.7/windows/PLUTO.exe
builds/releases/v1.0.7/pi/PLUTO.arm64
releases/v1.0.7/windows/PLUTO-windows-x86_64.zip
releases/v1.0.7/pi/PLUTO-linux-arm64.zip
```

Upload both ZIPs to one GitHub release tagged `v1.0.7`. The script does not publish automatically. To update existing users, the version must be higher than their installed version.

## Package an already exported build

```powershell
python tools/update/package-release.py --platform windows --arch x86_64 --build builds/windows --output releases/v1.0.7/windows --version 1.0.7
python tools/update/package-release.py --platform linux --arch arm64 --build builds/raspberry-pi --output releases/v1.0.7/pi --version 1.0.7
```

Use the same version as the exported project. Keep the executable, PCK and libraries together. See `docs/linux-releases.md` for updater behavior.
