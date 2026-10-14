# Windows updates through GitHub Releases

Repository: https://github.com/GokulrajE/GODOT_PLUTO
Current baseline: 1.0.0. Updates run only in the exported Windows app, never in Godot editor/F6 sessions.

## Release package

The generated initial ZIP is releases/v1.0.0-local-documents/PLUTO-windows-x86_64.zip. Extract the entire ZIP and run PLUTO.exe. Keep gdserial.dll alongside the executable. Install into a user-writable folder, not Program Files. Patient data, device.cfg and settings.cfg stay in %USERPROFILE%/Documents/PLUTO (local Documents, explicitly bypassing Windows OneDrive folder redirection). Existing redirected Documents records are copied once without overwriting local files or deleting originals.

For a future update:
1. Increase application/config/version in project.godot (for example 1.0.1), and the two Windows version values in export_presets.cfg.
2. Export Windows Desktop as PLUTO.exe to a clean build folder. The checked-in preset embeds the PCK and excludes patient records, test fixtures, documentation and development caches.
3. Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools/update/package-release.ps1 -BuildDirectory builds/windows -Version 1.0.1 -OutputDirectory releases/v1.0.1
4. Create a public, stable GitHub Release tagged v1.0.1 and upload PLUTO-windows-x86_64.zip as an asset. Do not use GitHub's automatically generated source-code ZIP. GitHub must provide the asset's sha256 digest in its API response.
5. Mark the release as latest. Version in project settings, release tag and app-release.json must agree. Existing copies that already contain this updater will detect the update on the next Main Scene startup.

Nothing was published automatically. At implementation time the public latest-release endpoint returned HTTP 404; this may mean no published release or a private repository. Public unauthenticated releases are required by this implementation. No GitHub token is embedded in the app.

## Behavior

- Login, registration and demo entry are disabled during the initial update check (12-second timeout).
- An available newer stable version blocks entry until installed. The requirement is cached across restarts, so a subsequent network failure does not bypass a known update.
- Offline/API failures with no known update allow the installed version to continue, with a visible notice and Retry.
- The Download & restart button streams the ZIP to the local update cache and verifies its GitHub SHA-256 digest.
- The external Windows PowerShell helper verifies the ZIP again, rejects unsafe paths and protected data, checks every file against the package manifest, and stages the complete package before asking PLUTO to close.
- Files being replaced are backed up. The helper restarts PLUTO and waits up to 45 seconds for the expected version to acknowledge startup. Installation/startup failures restore replaced files and remove files newly introduced by this update. The previous executable is relaunched after rollback.
- The updater does not delete unrelated files from the installation folder. Backups, rollback journals and updater-status.json remain in the user data updates folder for recovery. Abrupt power loss during installation may require manual recovery using rollback.json and backup files; automatic power-loss recovery is not implemented.
- If Windows policies prohibit PowerShell or the folder is not writable, preparation fails while the existing game remains open. No admin elevation is requested.

## Validation

- 19 updater/UI checks: numeric versions, same/older/prerelease handling, login/demo/register gating, offline policy, persisted requirement, asset host and digest validation, progress, interrupted download and corrupt download.
- 25 installer checks using real PowerShell processes and isolated executable fixtures: installation/relaunch acknowledgement, failed-start rollback, corrupt ZIP rejection, path traversal rejection, manifest-version mismatch, and preservation of unrelated records.
- Actual exported PLUTO.exe startup acknowledgement verified as 1.0.0; export log checked to exclude data/tests/docs/builds/graphify-out resources.
- Live download/install from a public GitHub release cannot be verified until a release asset is published. The normal startup smoke test still reports existing ObjectDB/resource cleanup warnings at forced exit.

Primary references: https://docs.github.com/en/rest/releases/releases and https://docs.godotengine.org/en/stable/classes/class_httprequest.html
