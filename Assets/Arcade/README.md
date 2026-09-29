# Arcade artwork provenance

Created for this project with the built-in OpenAI image generation tool on 2026-09-29. These are new generated images, not downloaded third-party asset packs. The supplied UI reference informed the palette and arcade treatment. Existing project audio, fruit/ball sprites, mechanism illustrations and the Luckiest Guy font remain in use.

| File | Use | Generation brief (summary) |
| --- | --- | --- |
| twilight-garden.png | Shared game landscape and dimmed menu background | Wide polished 2D fantasy landscape in purple/indigo twilight; soft distant hills, castle and moon; foliage at the edges; uncluttered playable middle; ground near the bottom; no text or interface. |
| sprites-source.png | Transparent atlas: hat, basket, cloud, tuk-tuk, paddles, reward star | Six separated polished arcade illustrations in a 3×2 arrangement, consistent dark outlines and highlights, generous transparent gaps, no text. Purple magician hat, woven basket, friendly cloud, yellow auto rickshaw, red/blue paddles and gold star. |
| plant-stages.png | Five bottom-anchored growth stages | Five separated matching plant growth stages on a transparent background, from seed through sprout, leaves, bud and flower; coherent illustration style and ground baseline. |
| ball.svg | High-contrast Pong ball | Authored vector source; white/cyan shaded sphere. |
| rock-column.svg | Tuk-Tuk obstacles | Authored vector source; rectangular purple rock column and cyan gap-facing cap. Visible width agrees with rectangular collision geometry. |

All PNGs are 1536×1024. Transparent PNG sources remain unmodified. `scripts/ui/arcade_assets.gd` defines atlas regions, avoiding destructive cropping and preserving an editable source of truth. The SVGs are code-native assets. The earlier generated concept board is a design reference, not a runtime screenshot.

## Reference refresh (v2)

Generated with the built-in image_gen tool, 2026-09-29. Exact prompts are saved in `generation-v2.json`.

- `orchard-v2.png`: sunny fruit orchard for Fruit Basket.
- `garden-v2.png`: daytime planting garden for Rain & Rise.
- `canyon-v2.png`: tropical canyon and river for Tuk-Tuk.
- `arena-v2.png`: neon sports arena for Pong.
- `sprites-driver-v2.png`: edited atlas with a seated driver; the original vehicle silhouette and wheel coordinates are preserved. Only its Tuk-Tuk region replaces the original atlas region. Transparent alpha verified.

Hat-Trick retains the matching `twilight-garden.png` moonlit magic setting. The images above are each 1536×1024 and are stored in this directory. `frame-blue.svg`, `field-blue.svg`, `button-lime.svg`, and `button-purple.svg` are authored vector frames, rendered as Godot nine-patch styles. The starfield and booster are native Godot drawing code, so they remain crisp and do not need extra raster animation sheets.
