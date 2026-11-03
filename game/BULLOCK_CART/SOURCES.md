# Asset credits and references

The separate motion preview uses three original generated 16-frame RGBA atlases: `assets/generated/cart-centered-player.png`, `cart-centered-amber.png` and `cart-centered-indigo.png`. They use a centered rear view with individual cart and clothing colours. Earlier angled sheets are retained. No online character/cart artwork or animation was downloaded for these sheets. Exact image_gen prompts and native dimensions are recorded in GENERATED_ASSETS.md; playback details are in MOTION_PREVIEW.md.

Downloaded 26 October 2026. Only the assets below are copied into this game.

| Asset | Creator / source | License | Use |
| --- | --- | --- | --- |
| Nature Kit, selected GLB trees and rock | [Kenney](https://kenney.nl/assets/nature-kit) | CC0; original license in `assets/Kenney-LICENSE.txt` | Roadside scenery |
| Growing Village | [Earl Beat on OpenGameArt](https://opengameart.org/content/growing-village) | CC0, confirmed on asset page and by author comment | Previous soundtrack, retained asset; no longer used by Bullock Trail |
| User-supplied BGM1 / BGM2 | Added to the project by the user | Source/license not specified | `audio/bgm1.mp3` and `audio/bgm2.mp3`: active local soundtrack, original files unchanged |
| Electronic Indian tabla tune | [obscure music / OpenGameArt](https://opengameart.org/content/electronic-indian-tabla-tune) | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `audio/tabla-loop.ogg`: previous soundtrack, retained but no longer played; excerpt from 15–47 seconds, crossfaded into a 31-second loop, normalized and encoded to Ogg; downloaded 27 October 2026 |
| Free Crowd Cheering Sounds | [Gregor Quendel / OpenGameArt](https://opengameart.org/content/free-crowd-cheering-sounds), [creator](https://www.gregorquendel.com/) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | `audio/crowd-bed.ogg` from track 10 (13-second crossfaded loop); `audio/crowd-cheer.ogg` from track 04 (four-second excerpt, faded and normalized). Edited 27 October 2026. Credit also appears in the game's Audio panel. |
| Tamil encouragement | Original phrases synthesized using Microsoft Edge voices ta-IN-ValluvarNeural and ta-IN-PallaviNeural via edge-tts | Generated speech; no recording of a real crowd or impersonation of a particular person | Four local MP3 clips; generation details in `assets/audio/README.md` |
| Dirt, 4K diffuse/GL normal/roughness | [Charlotte Baglioni / Poly Haven](https://polyhaven.com/a/dirt) | [CC0](https://polyhaven.com/license) | PC road surface; downloaded 26 October 2026 |
| Village panorama, neem tree and festival market | Built-in image_gen, 27 October 2026 | Generated project assets; prompts in GENERATED_ASSETS.md | Distant matte plate, tree billboards and fixed transparent roadside market planes |
| Cart, bullocks, driver, houses, road, tokens, collection chime | Original procedural assets in this folder | Project-owned implementation | New game only |

The active soundtrack uses the user-supplied `bgm1.mp3` and `bgm2.mp3`. Their source/license was not provided; the CC0 credit for the previous tabla soundtrack does not apply to these files. BGM1 plays first; replays and natural track endings advance to the other track. Music, crowd recordings and synthesized Tamil encouragement all play locally offline.

The generated Tamil crowd atlas is an original photographic-style image of fictional adults. PC mode uses four cropped upright billboards; these are not rigged 3D humans or animated facial-expression models. Light mode retains the simpler 3D crowd.

## Reference only — not redistributed

[Indian Wooden Bullock Cart — Nashik, Maharashtra](https://www.dsource.in/sites/default/files/resource/indian-wooden-bullock-cart-nashik-maharashtra/downloads/file/indian-wooden-bullock-cart-nashik-maharashtra.pdf), Prof. Bibhudutta Baral and Guna D., NID Campus Bengaluru, D'source. Used to understand paired animals, the wooden yoke, cart platform and driver position. No photographs or diagrams copied into the game.

The supplied concept image sets the theme; its detailed realistic rendering is not represented as a finished asset in this prototype.

`assets/generated/festival-market.png` is an original generated photographic-style composite of fictional spectators, stalls, pennants and bulbs, used on both sides. Its expressions and decorations are static raster details.

`assets/generated/road-flags-lights.png` is an original generated transparent flag-and-bulb string. It shares one texture across overhead and roadside sprites, with subtle whole-string sway. Bulb glow is an image detail, not a dynamic light.

## Added festival variations and pickup

`festival-stalls-v2.png`, `festival-families-v2.png` and `festival-boost-lantern.png` are original built-in image_gen outputs created 27 October 2026. Six vendor stalls and six fictional family groups (including children with adults) are combined with the previous market image and four spectator cutouts. The blue lantern is the active booster pickup. Native PNGs are preserved; atlas cropping/alignment is runtime metadata only. Full prompts and dimensions appear in GENERATED_ASSETS.md.
# Pongal race environment

The distant temple imagery is supplied by the existing generated `assets/generated/village-panorama.png`. Roadside Pongal temple and banana-grove cut-outs are project-authored transparent SVG artwork in `assets/generated/`; no third-party image is used.
