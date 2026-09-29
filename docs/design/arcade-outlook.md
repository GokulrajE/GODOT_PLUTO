# PLUTO arcade redesign — proposed outlook

Status: design proposal for review, before implementation. The concept board illustrates the direction; it is not a running game screenshot or a promise of identical generated artwork.

## Visual system

Use the supplied reference as the visual direction: deep indigo backdrops, layered slate panels with lavender rim highlights, lime primary controls, purple progress fills, coral feedback, and gold stars. Keep body text clear, with rounded bold display typography only for headings and rewards. Use one consistent illustration treatment, outline weight, light direction, and shadow softness across all five games.

Menu cards: equal artwork boxes, shared baselines, consistent gutters, short game descriptions, obvious selection and keyboard-focus states. Game HUD: timer on the left, score centered, earned stars and pause/exit on the right. Keep playfield clear below the HUD. Controls remain large and readable. Do not introduce health, lives, locked stages, or rewards unsupported by existing rules.

Patient login, registration, device connection, plan setup, calibration, assessment, assistance, duration, and summary share the palette and panel language. Clinical forms use quieter decoration. Preserve meaningful range, warning, prescribed-time, and connection states. Use real labels and live values, not text baked into artwork.

## Game-by-game motion and alignment

| Game | Proposed presentation and animation | Alignment and gameplay checks |
| --- | --- | --- |
| Hat-Trick | Cohesive stage background; subtle hat lean; falling ball rotation; brief brim impact squash; localized catch sparkle and score pop. | Hat visual center matches movement center; catch bounds match the visible brim; ball and bomb sizes remain consistent with their hitboxes; floor spans the playfield. |
| Fruit Basket | Unified orchard art and baskets; restrained fruit rotation; basket catch bounce; compact fruit-colored burst. | Equal basket spacing and floor baseline; correct fruit lands in the correct basket; transparent image padding cannot shift catch targets. |
| R-N-R | Soft cloud bob; rain from cloud to active slot; smooth growth between plant stages; gentle leaf motion. | Plant roots stay on one ground baseline through scaling; rain, target highlight, and progress indicator agree with active seed center. |
| Tuk-Tuk | Layered scrolling background; wheel/body motion; clear gap targets; short impact feedback. | Rock gaps stay traversable and within bounds; hitbox tracks the vehicle body; scrolling art tiles without seams or exposed margins. |
| Ping-Pong | Clean framed court; symmetric paddles; short ball trail; contact ripple; goal feedback. | Court centered in the actual playfield; walls, paddles, ball, trail and prediction guide use one coordinate space; rebounds and scoring agree with displayed edges. |

UI motion: approximately 100–140 ms button feedback, 180–250 ms panel entrances, and 250–350 ms scene transitions. Rewards should be brief and localized. Avoid looping effects that compete with rehabilitation targets. Provide reduced-motion support. Decorative animation must not change collision geometry or sensor mapping.

## Technical approach

Current inspection found a 1280 × 800 viewport alongside fixed game coordinates around 1152–1166 pixels wide and fixed vertical catch/floor bounds. This needs a deliberate shared playfield layout. Establish a canonical game coordinate space, scale it uniformly within an aspect-preserving viewport, and anchor HUD/overlays separately. Map device range and keyboard input into that same playfield. Do not independently stretch sprites or merely replace the old constants with the current window width.

Audit source image dimensions and visible alpha bounds. Use explicit visual anchors: center for balls, center/brim for hat, bottom-center for baskets/plants, center-body for vehicle. Keep physics/logical bounds on stable parents and animate visual children. Verify artwork baselines and bounds with a debug overlay.

Proposed modules:

- `scripts/ui/`: theme tokens, shared framed controls, navigation transitions, HUD, dialogs, rewards.
- `scripts/gameplay/playfield_layout.gd`: playfield rectangle, scaling, anchors and coordinate conversion.
- `scripts/gameplay/game_input.gd`: device and keyboard test input adapters.
- `scripts/effects/`: reusable impacts, particles, score pops, trails and game-specific visual motion.
- Existing per-game scripts: rules, scoring, spawn logic and state transitions.
- `tests/gameplay/`: repeatable input scenarios and visual capture tools.

These names describe the proposed structure, not files already implemented.

## Asset sourcing

Use original project art when it fits; replace inconsistent pieces with a coherent family of properly licensed assets. Candidate sources verified on their own pages:

- Kenney UI Pack — Sci-Fi: https://kenney.nl/assets/ui-pack-sci-fi — CC0, panels/buttons/sliders.
- Kenney Particle Pack: https://kenney.nl/assets/particle-pack — CC0, impact and reward textures.

These are candidates, not downloaded or integrated assets. Retain each downloaded license and source URL in an asset manifest. Custom-drawn Godot panels can match the reference more closely than combining unrelated packs. Import textures with consistent filtering and intentional visible padding.

## Play-test and acceptance plan

The previous pass loaded screens and inspected screenshots; it did not establish that full gameplay works. All five games already include Space and arrow-key paths, making device-free play testing feasible.

1. Add an explicit isolated demo/test mode that uses no real patient records or device actuation. Trial start/end currently calls AppData and DataManager, so test logging needs isolation before full sessions run.
2. Play each game from waiting through start, movement, success, failure, pause/resume, timer expiry, results, replay, and exit. Check speed adjustments and input limits.
3. Exercise repeated catches/collisions, boundary positions, rapid pause/resume, repeated replays, and changing scenes during effects. Ensure no duplicate scoring, lingering tweens, orphaned particles, or stale input connections.
4. Capture real running scenes at 1280 × 800, 1280 × 720, 1920 × 1080 and a smaller window. Verify uniform scaling, safe HUD margins, centered dialogs, no stretched sprites, and matching collision/visual bounds.
5. Measure frame time while effects run and inspect Godot errors/warnings. Check frame-rate-independent movement and that pausing freezes game time and gameplay effects correctly.
6. Compare normal and reduced-motion modes. Test keyboard focus and disabled/selected controls.
7. Deliver real gameplay screenshots or clips and a pass/fail record for each game. Report hardware checks separately: sensor direction, calibration, assistance response and PLUTO button behavior require the connected device.

## Implementation order after design review

First fix playfield/sprite alignment and establish isolated keyboard testing. Then implement shared arcade components and one complete Hat-Trick slice. Apply the validated visual and motion conventions to the other four games and all supporting screens. Finish with full gameplay regression and captured evidence. Do not claim that screenshot previews prove gameplay correctness.

## Implementation status — 2026-09-29

The approved visual direction is now implemented. Runtime screenshots and verified behavior are documented in `verification.md`. The shipped implementation uses a shared illustrated landscape, atlas artwork, event-driven effects, subtle sprite motion, new reward transitions and aspect-preserving playfields. The table above records the original proposal; it is not a checklist of promises for each individual animation.
