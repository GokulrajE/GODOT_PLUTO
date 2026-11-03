# Bullock Trail — keyboard preview

A new, separate 3D game in PLUTO. Existing Tuk Tuk gameplay is unchanged.

## Play

Choose **Bullock Trail** from PLUTO's game-selection screen, or open `scenes/BullockMotionPreview.tscn` and press F6. This is now the active five-lane PNG race. See [MOTION_PREVIEW.md](MOTION_PREVIEW.md) for controls, rules and checks.

Tap Left/Right or A/D to change one lane. Forward running is automatic. Collect generated blue lantern boosters for immediate acceleration; no Space key is needed. Choose Practice, Easy, Standard or Challenge. Catch rivals from a staggered start, watch live standings, and compare actual times and booster counts on the final board. Coins have been removed from this mode. Esc pauses. The centred rear camera moves gently sideways, and cart/dress colours distinguish all three racers.

`scenes/BullockCartScene.tscn` remains an older 3D comparison scene with its previous continuous-steering, Space-boost and camera-toggle controls. It is no longer the menu destination. The older implementation details below refer to that comparison scene where they differ from the five-lane rules.

Both modes are **unrecorded keyboard prototypes**. They do not read PLUTO device input, issue motor commands, create patient trials or upload session files.

PC / Light detail and reduced-motion options remain available. Audio opens music, crowd/Tamil and effect volume controls; recordings and music are bundled locally with credits in the panel.

## Files

- `scripts/bullock_game.gd`: keyboard input, token rules, timer, UI and audio.
- `scripts/race_rules.gd`: deterministic rival steering, shared pickup arbitration, boosts and finish order.
- `scripts/cart_actor.gd`: cart, reins, wheel rotation, rigged character playback and simple character fallback.
- `art_source/`: original Blender models and reproducible authoring script; see its README for reference credits and limitations.
- `scripts/track.gd`: village road and reusable scenery.
- `scripts/festival.gd`: foreground cheering spectators and the market layers.
- `scripts/festival_market.gd`: 24 fixed roadside image planes with detailed stalls, flags, lights and crowds; Light mode uses 12 planes.
- `scripts/festival_festoons.gd`: 18 separate PNG flag/light strings above and alongside the road, with gentle paused-clock sway; Light mode uses nine. Bulb glow is baked into the PNG, without extra dynamic lights.
- `scripts/ground_detail.gd`: instanced pebbles/footprints, low sand banks, flower circles and stall mats.
- `scripts/race_hud.gd`: racing position badge, timer, score, remaining distance, racer progress markers and boost diamonds.
- `scripts/race_audio.gd`: local BGM/crowd/voice playback, music ducking, speech cooldown and volume persistence.
- `scripts/collection_fx.gd`: six reusable collection bursts with reduced-motion fallback.
- `scripts/chase_camera.gd`: damped steering follow, view transitions and fixed reduced-motion camera.
- `scripts/surface_materials.gd`: procedural wood, soil and grass materials.
- `assets/`: downloaded CC0 scenery and music; see SOURCES.md.

The scene constructs its cart and UI at runtime; use F6 to preview it. PC detail now uses original UV-textured, skinned GLB bullocks and seated drivers with Walk, Run and Ride clips. The characters remain a first art pass rather than photorealistic production models. Scenery combines generated photographic raster assets with 3D objects and native 4K scanned road textures. Generated background, market, crowd and tree assets are below 4K, with exact sizes and prompts in GENERATED_ASSETS.md.

## Performance and checks

Fixed pools of 24 scenery groups, 46 pickups and three carts; no per-frame object spawning or fullscreen blur. Directional sunlight shadows are limited to 45 world units in PC mode. Light road textures are generated once at 256 × 256 and tiled; PC road materials use 4K color, normal and roughness maps. Reduced motion removes cart bob/tilt and pickup spin and uses a fixed camera while retaining gameplay movement. No Raspberry Pi performance claim is made until measured on that hardware.

Festival scenery includes 24 detailed market planes and 48 foreground spectators. Light mode reduces these to 12 market planes and 12 simple animated spectators and disables hoof dust. Individual crowd movement uses the simulation clock and freezes on pause/results or reduced motion; dust follows the same settings. Market decorations and faces are static image details. Character leg movement continues for gameplay readability.

PC spectators use a generated photographic cutout atlas with visible smiling/cheering expressions, fixed-Y billboards and subtle celebration movement. These do not provide changing facial expressions or full skeletal human animation. The atlas is 1774 × 887. Floor dressing is instanced and recycled; Light mode shows one in four dressing groups. Road and surroundings use warm sand colors.

Pickups produce gold/cyan expanding rings and flying gems, a short ascending chime, and a brief HUD pulse. A five-second speech cooldown prevents repeated Tamil phrases from overlapping. Streaks, overtakes and completion trigger crowd cheers; music ducks during speech. Reduced motion uses a static collection indicator and fixed camera. Audio is packaged locally; no Python or online service is used when playing.

Run the isolated regression checks from the project root:

```powershell
$env:APPDATA = Join-Path (Get-Location).Path '.godot/test-profile'
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/gameplay/bullock_cart.gd
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/gameplay/bullock_race_rules.gd
```

For rendered screenshots, remove `--headless` and append `-- --capture`. Test profiles do not save clinical sessions. Production-quality character art, course variety and device/session integration remain future work.

The market planes replace the primitive tents, flags and string lights. Their surfaces stay fixed in world space as the camera passes, with close individual spectators adding depth. Stall people, flags and bulbs are baked into the image and do not animate independently. This is layered 2.5D scenery, not fully modeled stalls or facial animation. Both camera views are checked; Light density is reduced, but Raspberry Pi frame rates still require a hardware test.
