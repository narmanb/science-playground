extends Node3D

const CAPTURE_ENV := "SCIENCE_PLAYGROUND_CAPTURE"
const CAPTURE_PATH := "res://build/preview/main.png"


func _ready() -> void:
	if OS.get_environment(CAPTURE_ENV) == "1":
		_capture_preview.call_deferred()


func _capture_preview() -> void:
	# Give imported GLB materials and the first rendered frames time to settle.
	for _frame in 12:
		await get_tree().process_frame

	var absolute_dir := ProjectSettings.globalize_path("res://build/preview")
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(CAPTURE_PATH)
	if error != OK:
		push_error("Failed to save visual preview: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Saved visual preview to %s" % CAPTURE_PATH)
	get_tree().quit()
