# Arcade redesign verification — 2026-09-29

Environment: Godot 4.6.2 stable, Windows, OpenGL compatibility renderer on Intel UHD Graphics.

## Results

- **178 gameplay assertions, 0 failures** in the final rendered run.
- **47 UI assertions, 0 failures** covering demo entry, reduced motion, calendar bounds/date selection/year rollover/leap year, reward containment and exactly-once reward completion in both motion modes.
- All **16 application and game scenes** loaded and captured successfully.
- Earlier headless gameplay run: 128 assertions, 0 failures, before the additional layout/button/reduced-motion assertions were added.
- No script errors in the final gameplay, interaction or scene-preview logs.
- Patient-file hashes unchanged after demo gameplay; no raw trial file created.

The gameplay runner uses real keyboard events with manually advanced simulation time, not manual human play or a hardware-in-the-loop run. It exercises each full session with successful and deliberately missed interactions, pause/repeat-key handling, resume, results, replay, speed limits and exits. Window sizes: 1280×720, 1920×1080 and 960×600. Canonical game coordinates remain 1166×656 at all sizes. HUD and modal containment are asserted explicitly.

| Game | Successful interactions | Misses | Resolved targets |
| --- | ---: | ---: | ---: |
| Hat-Trick | 14 | 5 | 19 |
| Fruit Basket | 11 | 4 | 15 |
| Rain & Rise | 22 | 3 | 25 |
| Tuk-Tuk | 6 | 7 | 13 |
| Pong | 5 | 2 | 7 |

Pong interaction counters represent returns/rallies for the existing session metrics. Its visible match scoreboard now uses actual player/CPU goals.

## Fixes verified

Keyboard release preserves player position; pause freezes game motion and time. Hat and basket catches align with the displayed opening. Plant stages share a ground baseline and rain ends at the growing plant. Tuk-Tuk uses rectangular rock artwork matching its collision geometry. Pong sprites remain clearly visible over the court, and wall impacts no longer display false score increments. Calendar days stay inside the popup. Mechanism artwork retains readable contrast.

## Review artifacts

- `gameplay-report.json` and `ui-report.json`: machine-readable results.
- `screenshots/game-picker.png`: actual running game selector.
- `screenshots/pong-playing.png`: actual running Pong gameplay.
- `screenshots/garden-playing.png`: actual running Rain & Rise gameplay.
- Full local captures and logs: `.godot/arcade-test`, `.godot/ui-preview`, `.godot/arcade-final-rendered.log`, `.godot/arcade-ui-final.log`, `.godot/arcade-all-scenes.log`.

Physical device input, calibration/assistance behavior with connected hardware and clinician workflows were not exercised. Existing audio and original non-arcade assets remain as supplied by the project. The editor import scan reports pre-existing duplicate asset UIDs in the Unity-source copies; final runtime test logs are clean.
