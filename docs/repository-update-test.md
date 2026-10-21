# Repository update validation — 2026-10-16

Built current project version 1.0.6 for Windows x86_64 and Linux ARM64 into builds/shared-updater. Clean exports completed after retrying outside sandbox file restrictions.

Verified packages are under releases/shared-updater-verified-v1.0.6/windows and releases/shared-updater-verified-v1.0.6/pi. Earlier releases/shared-updater-v1.0.6 packages are superseded; use only verified packages.

Live Pi test: the exported game pack was loaded by the official matching Godot 4.6.2 ARM64 runner because release templates ignore external --script tests. The test reported installed version 1.0.5 in memory, queried the real GitHub latest endpoint, detected v1.0.6, downloaded PLUTO-linux-arm64.zip and verified the GitHub SHA-256. Login remained enabled. It explicitly requested installation, then the embedded shared helper replaced the disposable test installation with the actual repository release executable. Startup acknowledged version 1.0.6 and cache cleanup completed. The test instance was closed afterward. Normal installed files and patient data were untouched.

Evidence: .godot/repository-update-evidence/pi-run.log and pi-updater-status.json. Pi test profile: /home/nd/pluto-repository-profile-1792129581.

Windows: native executable startup smoke test exited 0. The exported Windows PCK passed 25 updater UI checks using the test-capable Godot runner. Native shared-helper installer tests previously passed all 44 checks. The current GitHub v1.0.6 release has no Windows asset, so a live Windows GitHub download/install test is not possible yet.

No release/tag/assets were published or changed. These packages retain source version 1.0.6; to deliver the latest code to existing 1.0.6 users, bump project version and re-export/package under a higher tag before publishing.

Windows real-app follow-up: 2026-10-16
The actual Windows exported executable was installed from the verified local Windows ZIP into .godot/windows-real-update-1792129805/installed. The shared bundled helper restarted the actual app, received its 1.0.6 startup acknowledgement, and removed this job's package, backup and markers. All installed manifest hashes matched; unrelated-record.txt was preserved. The isolated test instance was closed. This tests replacement/restart using a same-version package; the public GitHub release still contains only the Linux ZIP, so the Windows network-download/newer-version path remains unverified end to end.
