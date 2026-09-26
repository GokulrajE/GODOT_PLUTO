# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

A Godot 4.6 application for interfacing with the **PLUTO** (Portable Lower Limb Universal Testing Orthosis) rehabilitation device over serial. It drives a linear clinical workflow: connect → select mechanism → calibrate → ROM assessment → assist profile configuration.

## Running the Project

Open in **Godot 4.6** (Forward Plus renderer). Press **F5** to run or use the Godot editor's Play button. There are no build scripts — the project runs directly in the editor.

The main scene is `scenes/ConnectScene.tscn`. For raw serial debugging without the full workflow, run `serial_test.tscn` directly.

**Serial port:** Currently hardcoded to `"COM45"` in `scripts/connect_scene.gd` and `SerialTest.gd`. Change this to match the connected device's port.

## Architecture

### Global Singletons (autoloads/)

Two autoloads are registered in `project.godot` and available everywhere:

- **`GameData`** (`autoloads/GameData.gd`) — Shared clinical state: selected mechanism index/name, calibration angles/offsets, AROM/PROM results, and assist profile settings. Also holds the `MECHANISMS`, `CALIB_ANGLE`, and `MECH_OFFSET` constant arrays indexed together.

- **`PlutoComm`** (`autoloads/PlutoComm.gd`) — All serial I/O with the PLUTO device. Manages the GdSerial connection, encodes outbound JEDI protocol commands, parses inbound sensor packets, and exposes live data properties (`angle`, `torque`, `control`, `button`, etc.). Scene scripts read from this singleton and connect to its signals.

### Scene Flow (linear, one-way)

```
ConnectScene → ChooseMechanism → CalibrationScene → AssessmentScene → AssistProfileScene
```

Each scene script (`scripts/*.gd`) attaches to its matching `.tscn` in `scenes/`. Scene transitions happen by calling `get_tree().change_scene_to_file(...)`.

### Signal-Driven Updates

Scene scripts connect to `PlutoComm` signals rather than polling:
- `PlutoComm.new_pluto_data` — emitted every sensor packet (~20 Hz); drives UI updates
- `PlutoComm.button_released` — physical button on device
- `PlutoComm.control_mode_changed`, `PlutoComm.mechanism_changed`

### JEDI Serial Protocol

**Inbound** (device → host): `0xFF 0xFF [len] [status] [err_lo] [err_hi] [mechanism] [pkt_lo] [pkt_hi] [runtime×4] [angle f32] [torque f32] [control f32] [target f32] [desired f32] [bound] [dir] [button] [checksum]`

**Outbound** (host → device): `0xAA 0xAA [len+1] [payload…] [checksum]`

Checksum is an 8-bit sum of all preceding bytes. Parsing logic is in `PlutoComm._parse_packet()`.

### Mechanism Constants

`GameData` holds parallel arrays indexed by mechanism number (0–6):

| Index | Name | Calib Angle | Offset |
|-------|------|-------------|--------|
| 0 | NOMECH | 0° | 0.0 |
| 1 | WFE | 136° | 68.0 |
| 2 | WURD | 136° | 68.0 |
| 3 | FPS | 180° | 90.0 |
| 4 | HOC | 93° | 0.0 |
| 5 | FME1 | 180° | 90.0 |
| 6 | FME2 | 180° | 90.0 |

HOC is a special case: it uses linear distance (cm) rather than degrees. Use `GameData.hoc_to_cm()` / `GameData.cm_to_hoc()` for conversions.

### GdSerial Plugin

Located in `addons/gdserial/`. A Rust-based GDExtension with pre-compiled binaries for Windows x86_64, macOS arm64/x86_64, and Linux x86_64/arm64. The plugin is enabled in `project.godot`. Do not modify the `bin/` directory. API is accessed via `GdSerialManager` — see `PlutoComm._setup_serial()` for usage pattern.

### State Machines

`CalibrationScene` and `AssessmentScene` use GDScript `enum` + a single state variable. State transitions are driven by `PlutoComm.new_pluto_data` signal and timer callbacks. Follow the existing pattern when adding new scenes with multi-step workflows.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
