@tool
extends EditorExportPlugin
func _get_name() -> String:
    return "PLUTOUpdaterResources"
func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
    if "Windows" in features:
        var recorded := FileAccess.get_file_as_string("res://tools/update/bin/PLUTOUpdater.source.sha256").strip_edges()
        if recorded != FileAccess.get_sha256("res://tools/update/install-update.py"):
            push_error("Rebuild the Windows updater with tools/update/build-helper.ps1 before exporting")
            return
    var path := "res://tools/update/bin/PLUTOUpdater.exe" if "Windows" in features else "res://tools/update/install-update.py"
    var contents := FileAccess.get_file_as_bytes(path)
    if contents.is_empty(): push_error("Missing updater helper: " + path)
    else: add_file(path, contents, false)
