# Shared updater and release workflow

Both platforms now use tools/update/install-update.py. Windows bundles it as tools/update/bin/PLUTOUpdater.exe, so patients do not need Python. Linux runs the same source with python3. Build and packaging commands are saved in BUILD_RELEASE.md at the project root. Obsolete platform-specific wrappers have been removed.

After modifying the installer source, run tools/update/build-helper.ps1 on Windows (developer dependency: PyInstaller). Re-export each game build afterward. The export plugin bundles the matching helper automatically.

Use one packaging script for both exports, from the project folder:

```powershell
python tools/update/package-release.py --platform windows --arch x86_64 --build builds/windows --output releases/v1.0.7/windows --version 1.0.7
python tools/update/package-release.py --platform linux --arch arm64 --build builds/raspberry-pi --output releases/v1.0.7/pi --version 1.0.7
```

Use your actual version, matching project.godot and the GitHub tag. Export names must be PLUTO.exe (Windows), PLUTO.arm64 (Pi), or PLUTO.x86_64 (Linux PC). Upload the resulting platform ZIPs to the same GitHub release. Keep exported PCKs and libraries in each build folder.

Updates are optional. Checking, availability, errors and downloads never block login or registration. Update downloads the package; Restart & install explicitly starts replacement from the login screen. A download finishing during a patient session does not restart the app. Only the explicitly requested installation briefly disables login while the app closes.

The installer verifies hashes, backs up changed files, waits for startup acknowledgement, rolls back failed startup, and cleans its own successful download/cache. Linux restart output and Windows restart output are stored in restart-<token>.log and installer.log in Godot's updates cache. Installation folders must be writable and not symlinked. Linux needs Python 3 and an active desktop session.

Manually install the first build containing this shared helper if your old updater cannot restart successfully. Patient Documents files are excluded from release packages.
