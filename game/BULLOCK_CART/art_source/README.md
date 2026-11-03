# Original rigged character assets

Created in portable Blender 4.5.9 using `build_characters.py`. No purchased/reference mesh, texture or animation is included.

## Runtime assets

- `../assets/characters/bullock_rigged.glb`: continuous skin mesh, UV-baked coat color and surface normal maps, cloven hooves, curved horns, ears, muzzle, dewlap, tail and bells; 21 bones (17 deformation bones and four foot targets); separate Walk and Run clips.
- `../assets/characters/driver_rigged.glb`: seated blue-kurta driver with red headwrap, cream trousers, bare forearms, sandals and moustache; 11 bones and Ride clip.
- `../assets/characters/driver_rigged_checked.glb`: checked tunic, waist sash and blue-trouser variant for Amber.
- `model_manifest.json` beside the GLBs reports exported mesh, skeleton and animation counts.

The .blend files in this folder retain editable meshes, UVs, armatures, materials and actions. `.gdignore` keeps these authoring files out of Godot imports; the game consumes the GLBs.

## Animation integration

PC detail instantiates the rigged meshes. AnimationPlayers advance manually only during active gameplay, so pause and results freeze characters. Run is used during racing with a short transition from Walk; boost increases animation playback by 1.6 times. Wheels and reins remain separate cart components. Light detail uses the original simpler characters and skips advancing hidden rigged animation.

The revised gait uses two-bone leg IK with a ground-contact stance and lifted return arc, alternating diagonal pairs. Blender bakes these constraints into the exported animation, so Godot does not solve IK at runtime. Run is an 18-frame cycle at 30 fps; Walk uses 34 frames. Coat and clothing also have baked tangent-space normal maps. The gait is stylized and does not guarantee physically exact ground-speed matching.

The model is an original first art pass, not a photoreal scan or a replica of a commercial asset. Smooth voxel-remeshed topology and hand-authored skin weights will benefit from further artist review, especially extreme poses. The driver is designed for seated riding, not a full standing/walking character controller. This rig does not have facial-expression controls. Textures are 1024 × 1024, not 4K. PC performance has not been benchmarked on Raspberry Pi.

## References supplied by user

- [CGTrader bullock cart](https://www.cgtrader.com/3d-models/vehicle/other/bullock-cart-3d-model): white humped bullocks, curved horns, harness and large wooden spoked wheels.
- [Indian Farmer by Hariom Singh](https://sketchfab.com/3d-models/indian-farmer-b9398d519ea7499ca844d81e2877206b): blue short-sleeved kurta, red headwrap, cream cropped trousers and moustache.
- [Indian Farmer Rigged by Mangesh Kondalkar](https://www.turbosquid.com/FullPreview/1069813): checked tunic, waist sash, cropped blue trousers and headwrap.

Only public previews were inspected. No marketplace files were downloaded or purchased.

## Rebuild

From the project root, use Blender 4.5:

```powershell
& '.godot/tools/blender-4.5.9-windows-x64/blender.exe' --background --factory-startup --python game/BULLOCK_CART/art_source/build_characters.py
```

Then let Godot import changed GLBs. `tests/gameplay/bullock_character_preview.gd` checks skeletons, clips, deformation and detail switching; running it without `--headless` saves front/rear previews under `.godot/`.
