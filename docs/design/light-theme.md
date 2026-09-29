# Light theme refresh
All 17 authored scenes use light surfaces, navy text and teal accents. Scene files retain their original layouts and scene identities. Nunito semibold is bundled with its OFL license. HUD label plates have been removed to reduce clutter.

Tuk-Tuk uses scripts/gameplay/scrolling_background.gd: mirrored horizontal panorama, stopped while waiting, paused, completed or reduced motion is enabled. Player, driver, booster and collision coordinates remain independent of the scenery.

Kenney CC0 click, success, celebration jingle and star particles are bundled in Assets/Arcade/Online with original licenses and SOURCES.md. Colored bursts are bounded to 100 particles; reduced motion suppresses particles and background motion. No asset network requests occur during play.

Validation: 198 gameplay checks across five games, 47 UI interaction checks, and 17 saved-scene checks with runtime styling disabled passed. Gameplay covers real keyboard movement, hit/miss interactions, scoring, pause/resume, replay, speed bounds and three window sizes. UI checks cover demo, calendar and normal/reduced celebrations. These are automated rendered Godot runs; physical PLUTO hardware was not tested.

Open project.godot in this project folder, reload externally changed scenes, and run with F6 for MainScene or F5 for the project.

## Editor, results and feedback follow-up
The running editor was verified to use this same project path. Menu backgrounds are now native TextureRect nodes referencing daylight-background.svg, with no editor script dependency. Scenes reference distinct daylight theme/panel/field/button resources to avoid reusing the old resource identities. Reload externally changed scenes (or reopen the project after preserving unsaved work) to replace the editor's in-memory scene state.

Hat-Trick GameOverPanel/ExitButton was explicitly hidden in the saved scene. It is now visible, labeled SELECT GAME, and aligned beside PLAY AGAIN. Integration tests check visibility, containment, and button-driven return to ChooseGameScene.

Particles increased from 10-18px to 24-40px diameter, with brighter colors, glow, longer lifetimes, larger outlined score feedback, and larger ball trails. Tuk booster flame length increased from about 45px to 68px; reduced-motion behavior remains steady.

MenuMusic is a separate autoload with a locally bundled CC0 loop by polosik (see Assets/Arcade/Online/SOURCES.md). It continues between menus, stops in games, resumes on return, and can be muted using the MainScene Music toggle. No music plays in the editor.

Validation: 200 gameplay checks, 47 UI checks, 9 music/effect checks, 17 saved-scene checks and normal startup passed. Tests found and fixed a one-frame null scene transition that initially restarted the menu loop. Hardware input and subjective speaker listening are not covered by these automated runs.

## Yellow stars, auto tilt and filled baskets
Hat-Trick success effects now use a dedicated bright-yellow five-point SVG star. Other games keep their colorful particles. Tuk-Tuk has traveling cyan exhaust rings and a smoothed movement-driven visual pitch limited to about 7 degrees. Pause freezes tilt and exhaust; reduced motion levels the vehicle. Wheel centers follow the rotated player transform; driver and booster remain attached children. Collision coordinates are unchanged.

Fruit Basket now uses five transparent, outlined SVG fruits in red, yellow, orange, pink and blue. Each basket displays a five-fruit pile matching its assigned falling-fruit texture; catches add up to three decorative top fruits while numeric counters retain the full score. Removed the separate single-fruit marker and unbounded caught-icon stack. FilledFruit nodes are authored in the scene and render in the editor through their tool script.
