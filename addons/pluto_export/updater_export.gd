@tool
extends EditorExportPlugin

const HELPER_PATH := "res://tools/update/install-update.ps1"

func _get_name() -> String:
	return "PLUTOUpdaterResources"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	# PowerShell files are not Godot resources. Add explicitly even when the
	# preset's non-resource inclusion filter has been cleared in the editor.
	var contents := FileAccess.get_file_as_bytes(HELPER_PATH)
	if contents.is_empty():
		push_error("PLUTO export is missing tools/update/install-update.ps1")
		return
	add_file(HELPER_PATH, contents, false)
