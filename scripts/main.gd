extends Node3D

const CAPTURE_ENV := "SCIENCE_PLAYGROUND_CAPTURE"
const CAPTURE_PATH := "res://build/preview/main.png"

@onready var ship: RigidBody3D = $Ship


func _ready() -> void:
	_initialize_view.call_deferred()


func _initialize_view() -> void:
	# The system is procedural, so wait one frame for Nysa to exist before aiming the ship.
	await get_tree().process_frame
	var target := get_node_or_null("AlienSystem/PlanetOrbit/Nysa") as Node3D
	if target != null:
		ship.look_at(target.global_position, Vector3.UP)

	if OS.get_environment(CAPTURE_ENV) == "1":
		await _capture_preview()


func _capture_preview() -> void:
	# Give imported GLB materials and the newly framed camera several rendered frames to settle.
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
