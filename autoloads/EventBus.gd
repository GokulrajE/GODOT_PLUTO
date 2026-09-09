extends Node

# ── Device ───────────────────────────────────────────────────────────
signal device_connected
signal device_disconnected

# ── Sensor stream ────────────────────────────────────────────────────
signal new_sensor_data
signal button_released

# ── Device state ─────────────────────────────────────────────────────
signal control_mode_changed
signal mechanism_changed

# ── Clinical workflow ────────────────────────────────────────────────
signal mechanism_selected(index: int)
signal calibration_done
signal rom_assessed(arom_min: float, arom_max: float, prom_min: float, prom_max: float)
signal assist_assessed(aprom_min: float, aprom_max: float)
