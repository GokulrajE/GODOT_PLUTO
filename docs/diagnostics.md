# Device diagnostics

Open **Device diagnostics** on the login screen, or the diagnostics shortcut in the connection panel. The authored editor scene is `scenes/DiagnosticsScene.tscn`; its controller is `scripts/diagnostics_scene.gd`.

The controls and serial packet layout are adapted from `D:/PLUTO-HOMER/Assets/scripts/plutoSceneHandler.cs` and `PlutoComm.cs`.

1. Check the serial port (initially read from external `device.cfg`) and choose Connect. This requests firmware information and diagnostic streaming.
2. Live telemetry shows angle, torque, target, desired output, control error, gain, packet rate and device error flags.
3. For manual calibration, choose the mechanism and Start calibration. Move to zero and press the device button. Move to the opposite limit and press again. The range must be within 10% of the reference range. Press once more to finish.
4. Enable control explicitly and select NONE, POSITION, RESIST, TORQUE or POSITIONAAN. Position targets respect mechanism limits; HOC is entered in centimeters and converted to motor angle. Torque targets range from -1 to 1 Nm; bound is 0 to 1 and gain is 1 to 20. Next random target uses the chosen duration; POSITION uses a minimum-jerk trajectory at up to 20 updates/second.
5. Record diagnostics CSV saves under the active application data root's `diagnostics` directory (normally local Documents/PLUTO/diagnostics). The screen displays the exact path. Recording flushes once per second and closes on stop, disconnect or exit.

Output starts disabled. Stop output cancels trajectories and sends NONE. Stale telemetry, reported device errors and mechanism changes disable control. Leaving the screen stops output and disconnects the serial device.

Protocol note: the reference gain command uses one normalized byte, not a float. Diagnostic packets have eight floats instead of the normal five; their tail fields therefore have different offsets.

## Verification

Run from the project root with your Godot executable:

```powershell
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/gameplay/diagnostics.gd
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/gameplay/arcade_integration.gd
& 'D:/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/gameplay/session_cleanup.gd
```

Diagnostics uses a fake serial transport and isolated test storage. Physical motor response and calibration accuracy require validation with the actual device.
