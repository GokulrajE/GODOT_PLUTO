# PLUTO arcade interface

The saved .tscn scenes contain the approved blue arcade UI, including layouts, textures and control styles. The Godot editor displays the same authored design. Start the project normally and choose **Try the games · Keyboard demo** to play without a device or patient record. Arrow keys move; Space starts, pauses, resumes and replays; Ctrl+G opens speed controls. The opening screen has a Reduced motion toggle for the current application session.

## Script boundaries

- `ui_palette.gd`: shared colors, typography and control styles.
- `ui_manager.gd`: applies the theme and decorates scenes and dynamically created controls.
- `arcade_assets.gd`: cached atlas regions for transparent illustrations and plant stages.
- `ui_motion.gd`: interruptible button feedback and modal entrances.
- `login_ui.gd`, `dashboard_motion.gd`, `game_picker_ui.gd`: screen-specific composition.
- `../gameplay/playfield_layout.gd`: fixed 1166×656 game coordinates with aspect-preserving scaling; menus use 1280×800.
- `../gameplay/game_input.gd`: device/keyboard input selection and position retention when keys are released.
- `../gameplay/game_presentation.gd`: artwork, HUD, dialogs and visual motion, independent of game scoring.
- `../effects/game_effects.gd`: bounded particles, score feedback and ball trails; pause and reduced-motion aware.
- `../CelebrationCard.gd`: reusable star reward sequence and completion signals.
- Each existing game script retains its state machine, collision handling, timers and scoring.

Demo mode suppresses device writes, trial recording and game-settings writes, and restores the prior patient/game selection on exit. Integration tests compare patient-file hashes before and after play. Physical PLUTO operation still requires testing with the device.

## Verification

Using Godot 4.6.2, from the project directory:

```powershell
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script res://tests/gameplay/arcade_integration.gd
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script res://tests/gameplay/ui_interactions.gd
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script res://scripts/ui/preview_ui.gd
```

Add `--headless` for logic-only runs. The gameplay runner injects keyboard events into the real game state machines and advances simulated time; it does not assign scores. It tests successes and misses, pause/resume, timer completion, replay, movement bounds, speed limits, reduced motion, HUD/dialog containment and three window sizes. Screenshots and JSON reports are written under `.godot/arcade-test`; the screen preview covers 16 scenes under `.godot/ui-preview`.

The shared theme is saved in Assets/Arcade/arcade_theme.tres. UIManager preserves authored control styles and attaches behavior; it only supplies runtime styling for newly generated controls. Asset provenance is in `Assets/Arcade/README.md`; final verification is in `docs/design/verification.md`.

## Blue arcade reference refresh

`arcade_backdrop.gd` draws the shared starfield menus. `ui_palette.gd` also owns nine-patch chrome styles from `Assets/Arcade/*blue.svg` and button SVGs. `arcade_assets.gd` selects a different environment for each game and its selection card. `../effects/tuk_booster.gd` owns the vehicle exhaust animation independently from collision/scoring; the driver is embedded in the edited Tuk-Tuk atlas region. See `docs/design/reference-refresh.md` for current verification results and `Assets/Arcade/generation-v2.json` for the exact generation prompts.


## Editor-visible scenes

All 16 primary scenes plus CelebrationCard.tscn are saved with their new composition. Open scenes/MainScene.tscn or scenes/ChooseGameScene.tscn in the 2D editor. If a scene was already open when these files changed, reload its disk version. Backdrops, game textures, driver atlas, HUD plates, play/resume/replay buttons and card contents are editable nodes/resources. The backdrop, Pong court and booster use small @tool drawing scripts to show their geometry in the editor. Animation, input and patient state remain runtime behavior.

The one-time migration utility is tools/bake_arcade_scenes.gd; authored scenes are skipped to protect subsequent manual edits. It is not required to run the application. tests/gameplay/authored_scenes.gd checks all 17 scenes with UIManager decoration and non-tool scripts disabled and captures their saved appearance.
