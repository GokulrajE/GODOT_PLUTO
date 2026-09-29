# Reference-style refresh — 2026-09-29

The blue arcade concept is now applied across all 16 application/game scenes through shared nine-patch frame assets, glossy lime/purple buttons, indigo surfaces and a procedural starfield menu backdrop. Game-selection cards preview their individual worlds. Game HUDs include the game name and separate timer/score plates.

## Game settings

| Game | Background |
| --- | --- |
| Hat-Trick | Moonlit fantasy landscape |
| Fruit Basket | Sunny apple orchard |
| Rain & Rise | Bright flower garden and planting bed |
| Tuk-Tuk | Tropical canyon, waterfalls and river |
| Pong | Neon blue/violet sports arena |

Tuk-Tuk has a visible seated driver in the front cabin and a rear-mounted blue booster. The booster is a separate visual-effects script (`scripts/effects/tuk_booster.gd`), inherits the vehicle transform/visibility, freezes on pause, uses a steady flame with reduced motion, and stops at session end. It does not enlarge or change the existing collision box. Original wheel/sprite coordinates are retained.

## Verification

- Rendered Godot 4.6.2 integration run: **195 assertions, zero failures**.
- UI interaction run: **47 assertions, zero failures**.
- All **16 scenes** loaded and captured without script errors.
- Added assertions verify each background resource, driver atlas, rear mount, booster animation/pause/reduced motion/end-of-session behavior, and the added HUD name plate.
- Existing checks cover actual keyboard-driven catches/misses, complete sessions, pause/resume, replay, limits, three viewport sizes, calendar interaction and reward completion.
- Demo patient-file hashes remained unchanged.
- Physical PLUTO hardware remains untested; this revision changes presentation.

Final machine-readable reports: `gameplay-v2-report.json`, `ui-v2-report.json`. Runtime screenshots are in `screenshots/v2/`. Full local logs: `.godot/v2-gameplay.log`, `.godot/v2-ui.log`, `.godot/v2-scenes.log`.

New raster artwork was produced with the built-in image_gen tool. Saved file paths and provenance are listed in `Assets/Arcade/README.md`; exact prompts are in `Assets/Arcade/generation-v2.json`. The shared UI frames, starfield and booster are code-native assets. No new third-party downloads were needed.

## Normal startup regression fix

A normal MainScene launch reproduced the old UI even though `change_scene_to_file` preview tests passed. The startup scene's identity was not available to the original `node_added` root-scene check. UIManager now reconciles the current scene once it is available, decorates it idempotently, and styles its existing controls. Normal application startup and explicit MainScene/TukTukScene launches are covered by `tests/gameplay/normal_startup.gd`.

Run the actual startup regression without a `--script` override:

```powershell
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility -- --ui-startup-test
```

The diagnostic exits after checking the startup UI and saves `.godot/normal-startup.png` in graphical mode. The flag is inactive during ordinary application use.

## Authored scene conversion

The 16 primary scenes and shared CelebrationCard scene now store the new UI directly in their .tscn files. This supersedes the earlier runtime-only/editor-preview limitation. MainScene and ChooseGameScene contain the new panels, buttons, textures and layouts; all five game scenes contain their background, HUD, artwork and dialogs. A shared arcade_theme.tres supplies typography/default styles. Scene UIDs are retained.

UIManager preserves authored controls and wires runtime behavior without duplicating them. Generated gameplay objects still follow their existing state machines. Small @tool scripts expose the starfield, Pong court and booster drawing in the editor. No gameplay or patient scripts were made editor tools.

Verification: 17 saved-scene checks passed with runtime styling and non-tool scripts disabled; 195 rendered gameplay checks and 47 UI interaction checks passed. Normal MainScene startup and direct Tuk-Tuk launch passed without duplicate presentation nodes. Final logs contain no runtime errors. Saved-design captures are in screenshots/authored/; machine-readable preview results are in authored-scenes-report.json.

If an old scene is still open in Godot, reload its changed file from disk or reopen the project to replace the editor's cached copy.
