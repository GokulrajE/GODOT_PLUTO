# Local server integration

PLUTO uses the existing background agent API for start, stop, trial-ended and status. It does not launch another agent or modify external Python files.

Refresh IDs runs `python -X utf8 C:/sender.py --login`, using the sender's own settings. The native Godot session uploader is restored. It reads literal SERVER_IP and SERVER_PORT assignments from the same sender file at startup and every three seconds, so old server_host/server_port values do not override that address. A valid reachable server address is still required. Restart the background agent after changing sender settings so its imported configuration also updates.

Completed server-patient trials queue immutable sessions.csv snapshots from the active patient's local data folder. Native TCP uploads retry every 30 seconds and remove queued copies only after server acknowledgement. Original files remain intact. Local-only patient sessions stay local.

Default external script: C:/sender.py. Default cache: C:/NeuroDash/patients.json. The app's Documents/PLUTO/server.json supports sender_path, patients_file, agent_port and python overrides. No developer-settings UI has been implemented.

Tests: session_upload.gd exercises native upload retries and acknowledgement with a synthetic loopback server. local_server.gd checks local/server training IDs and login behavior. Live refresh on 2026-10-23 resolved 192.168.0.104:5000 from sender.py, but the connection timed out.

Configuration saves and completed trials also queue configdata.csv from the active patient folder. The export preserves configdata and adds HomerID for server routing. Local-only sessions are excluded.
