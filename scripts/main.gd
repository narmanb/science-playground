extends Node3D

const CAPTURE_ENV := "SCIENCE_PLAYGROUND_CAPTURE"
const CAPTURE_PATH := "res://build/preview/main.png"


func _ready() -> void:
	if OS.get_environment(CAPTURE_ENV) == "1":
		_capture_preview.call_deferred()


func _capture_preview() -> void:
	# Let procedural bodies, the scan registry, imported GLB materials, and the
	# visual enhancer settle before exercising the gameplay HUD.
	for _frame in 8:
		await get_tree().process_frame

	var ship := get_node_or_null("Ship") as ShipController
	var hud := get_node_or_null("HUDLayer/FlightHUD") as FlightHUD
	if ship == null or hud == null:
		push_error("Visual smoke test could not find the ship or flight HUD.")
		get_tree().quit(1)
		return

	ship.request_scan()
	for _frame in 2:
		await get_tree().process_frame
	if hud.scan_target == null:
		push_error("Visual smoke test failed to acquire a scannable body.")
		get_tree().quit(1)
		return

	# Capture during the scan rather than after it. This validates target
	# projection, scan signal/progress math, the sensor brackets, and the
	# underlying scientific body registry in one rendered frame.
	for _frame in 52:
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
