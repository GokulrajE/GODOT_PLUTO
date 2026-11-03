# Five-lane Bullock Trail

Choose **Bullock Trail** from PLUTO's game selection screen, or open `scenes/BullockMotionPreview.tscn` in Godot and press F6. The menu now opens this generated-PNG race. `BullockCartScene.tscn` retains the older 3D prototype for comparison.

## Race and controls

- Tap Left/Right or A/D once per lane change. Hold does not repeat. Running is automatic; Space does nothing.
- The wide sandy road has five lanes. Practice and Easy activate the middle three. A shared three-second countdown starts the race.
- Player starts at 0 m, Amber at 10 m and Indigo at 5 m, in different lanes. Practice removes rivals.
- **No gold coins.** Only the generated cyan festival lanterns are pickups. Touch one for a three-second boost and the rein-flick animation. Another refreshes duration to three seconds, without stacking speed. All racers share the same pickups.
- Each race generates a fresh seeded random route. Consecutive primary boosters move at most one lane, with 26–44 m spacing depending on difficulty. Alternate neighbouring branches offer overtaking choices. A fixed seed is available in the simulation for tests; normal gameplay randomizes every race.
- Practice: three lanes, no rivals, 40–44 m between rows and a generous pickup radius. Easy: three lanes, 36–40 m spacing, slower rivals (0.6 m/s below player speed), less frequent decisions and more missed opportunities. Standard: five lanes, 30–34 m spacing, equal speeds, balanced AI. Challenge: five lanes, 26–30 m spacing, quicker AI decisions and more route choices. Difficulty increases decision demand before player speed.
- Normal player speed remains 8 m/s, boosted speed 13 m/s. Rival maximum speeds are equal in Standard/Challenge. These are arcade presets for keyboard testing, not clinical exercise recommendations.
- Live standings reorder immediately on overtaking and show racer names, gaps, active boosts and actual finish times. HUD shows position, race time, remaining distance and active boost duration.
- First crossing wins. If the player finishes before the rivals, they continue running while the player watches the live standings. The final board appears once all active racers finish or the 90-second limit is reached. It shows the winner, actual finishing order, times, time gaps and boosters collected. Unfinished racers are explicitly marked; their times are never estimated. Practice has a solo completion board.
- Pause freezes movement, countdown and animation. Replay clears results, creates a new route and applies the selected difficulty. Both BGM tracks remain active and alternate as before.
- The centered rear camera moves gently sideways. Reduced motion disables decorative movement. Light mode retains the mixed crowd/family artwork at lower density and disables dust/shadows.

This is still an **unrecorded keyboard prototype**. No PLUTO device mapping or patient data changes have been made. Device integration is a later step.

## Festival scenery and boosters

The original market and four adult spectator cutouts are retained and mixed with six new stalls and six family groups, including children with adults. New stall types are fruit, flowers, pottery, refreshments, toys and crafts. Different variants appear on opposite sides and in neighbouring sections. Families stand outside the roadside fence on both sides. A second continuous row of the previous crowd-and-stall composite fills the gaps behind the varied foreground stalls. It uses 48 shared-texture planes recycled every 5 m; 48 foreground spectator groups mix the old adults and new families. Light mode keeps continuous coverage and reduces foreground density. These are photographic cutouts with subtle whole-group cheering motion, not newly rigged or facially animated humans.

New built-in image-generation assets, original files preserved:
- `assets/generated/festival-stalls-v2.png`: 1536 × 1024, six stalls.
- `assets/generated/festival-families-v2.png`: 1536 × 1024, six family groups.
- `assets/generated/festival-boost-lantern.png`: generated cyan lantern pickup; see GENERATED_ASSETS.md for native dimensions and full prompt.

Matching JSON atlas bounds use transparent gaps and foot baselines. Runtime regions do not modify or resize the source images. Full prompts and generation details are in GENERATED_ASSETS.md.

## Original generated artwork

The active original transparent PNG sheets are:

- `assets/generated/cart-centered-player.png`: teal cart, ivory shirt, saffron headwrap.
- `assets/generated/cart-centered-amber.png`: amber-orange cart, burgundy shirt, cream headwrap.
- `assets/generated/cart-centered-indigo.png`: indigo-blue cart, violet shirt, cream headwrap.

Created with the built-in image_gen tool, using the previous original sheet as an edit reference. No online character/cart model or downloaded animation was used. Every sheet contains eight running poses and eight rein-flick poses. Actual output is **1254 × 1254** per sheet, below native 4K. Earlier angled sheets remain available for comparison.

Each matching `.json` file records integer frame regions and wheel alignment offsets. Generated row spacing is slightly uneven, so the row boundaries follow the transparent gaps rather than assuming four equal rows. Anchors use the center and baseline of the rigid cart wheels; moving hooves and raised hands do not reposition the whole sprite. AtlasTexture consumes the original image without resizing. The generated sequences retain raster-animation consistency limits and support this centered rear view, not an orbiting camera.

Gait advances from **actual distance travelled after collision resolution**, using 4.8 game metres per complete stride. A blocked cart therefore stops stepping even if its requested speed remains nonzero. Boost queues the rein gesture at the next stride boundary, then plays one shared gait cycle before returning to running at the matching phase. This can delay the visible hand action by up to one stride (about 0.6 seconds at normal speed); acceleration starts immediately. Pause freezes the cycle and replay clears both the phase and queued gesture.

## Implementation and checks

- `scripts/lane_race.gd`: difficulty presets, reachable random booster routes, staggered starts, rival decisions and actual finish times.
- `scripts/motion_race.gd`: shared acceleration/contact foundation, with a configurable road limit. The earlier continuous-steering rules remain available for comparison.
- `scripts/race_rules.gd`: crossing arbitration, finish order and an overridable pickup award method. Its original mode retains its prior rules.
- `scripts/png_cart_actor.gd`: generated running/rein animation and effects; unchanged artwork.
- `scripts/bullock_game.gd`: countdown, keyboard input, feedback and scene integration.
- `scripts/track.gd` and festival scripts: configurable road width and roadside clearance.

Normal speed is 8 m/s and boosted speed is 13 m/s, with gradual acceleration. Lateral speed is capped at 3.8 m/s. Contacts use 2.25 m lateral / 4.8 m longitudinal clearance and a 0.45-second recovery. These are arcade settings, not physical animal simulation or an exercise prescription.

`tests/gameplay/bullock_lanes.gd` checks lane taps/holds/limits, 30/120 FPS consistency, boost activation/refresh/expiry, absence of coin rewards, shared pickup ownership, rival boosts, contact recovery, full races, countdown/pause/replay, HUD instructions and camera coverage. It also checks 120 seeded layouts across all four difficulties, immediate standings changes, mixed old/new scenery, generated booster artwork, real results and solo practice completion. A tested booster-seeking route wins from the staggered grid, while a no-steering run finishes behind both rivals. This is gameplay validation, not a hardware performance benchmark.

`tests/gameplay/bullock_motion.gd` checks the original contact foundation and current PNG scene: gait phase, automatic-boost rein flick, pause/replay, camera follow and distinct racer colours. Optional `-- --capture --video` saves a screenshot and four-second image sequence in `.godot/`.

Run from the project root with an isolated test profile:

```powershell
$env:APPDATA = Join-Path (Get-Location).Path '.godot/test-profile'
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/gameplay/bullock_lanes.gd
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/gameplay/bullock_motion.gd -- --capture --video
```

## Gameplay refinement (keyboard)

The course now has three labelled phases: Find your rhythm (0–140 m), Chase & overtake (140–330 m), and Final sprint (330–480 m). Opening gaps gain 2 m; every third middle-section gap gains 12 m to break continuous boost chains. The final stretch uses the original difficulty spacing. Random routes turn inward at road edges instead of repeatedly clamping to the same outer lane. Rivals look up to 60 m ahead when choosing a route.

Follow an active rival in the same lane, 5.3–15 m behind, for 1.2 seconds to charge slipstream. Change lanes to leave the slipstream and earn a two-second slingshot at 10 m/s. Lantern boost remains 13 m/s and does not stack with slingshot. Contact cancels the charge/advantage; all racers share these rules. The HUD shows building, ready, and passing feedback.

The result screen offers **Retry same course** (same seed and original difficulty) and **New course** (fresh seed and selected difficulty). Course bests are keyed by rules version, difficulty and seed and stored locally in `user://bullock-course-records.cfg`. Unfinished runs do not set records. These are game records, not patient session files.

The lane regression suite also checks slipstream charging, passing, expiry/reset, section names, same-course regeneration and new-course randomization.
