extends Node3D

const CAPTURE_ENV := "SCIENCE_PLAYGROUND_CAPTURE"
const CAPTURE_DIR := "res://build/preview"
const CAPTURE_PATH := CAPTURE_DIR + "/main.png"


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
	var nav := get_node_or_null("HUDLayer/NavigationHUD") as NavigationHUD
	if ship == null or hud == null or nav == null:
		push_error("Visual smoke test could not find the ship or cockpit HUD layers.")
		get_tree().quit(1)
		return
	if nav.current_target() == null:
		push_error("Visual smoke test could not acquire the default navigation target.")
		get_tree().quit(1)
		return

	ship.request_scan()
	for _frame in 2:
		await get_tree().process_frame
	if hud.scan_target == null:
		push_error("Visual smoke test failed to acquire a scannable body.")
		get_tree().quit(1)
		return

	# Give only the CI capture ship an obvious diagonal drift. Normal gameplay
	# still starts at rest. This forces the true-velocity marker away from the
	# nose reticle so the screenshot verifies inertial navigation feedback too.
	ship.linear_velocity = Vector3(7.0, 1.5, -7.0)

	# Capture during the scan rather than after it. This validates target
	# projection, scan signal/progress math, the sensor brackets, velocity-vector
	# projection, navigation target acquisition, and the scientific body registry.
	for _frame in 52:
		await get_tree().process_frame

	if not _save_view(CAPTURE_PATH):
		get_tree().quit(1)
		return

	# The remaining views are visual QA only. Freeze and reposition the test ship
	# starward of each world so its illuminated hemisphere faces the camera. None
	# of these teleports exist during normal gameplay.
	if hud.scan_target != null:
		ship.request_scan()
	ship.freeze = true
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	var hud_layer := get_node_or_null("HUDLayer") as CanvasLayer
	if hud_layer != null:
		hud_layer.visible = false

	for body_name in ["VEYR", "ORUN", "KHARIS"]:
		var body := _scannable_named(body_name)
		if body == null:
			push_error("Visual smoke test could not find %s." % body_name)
			get_tree().quit(1)
			return
		_position_ship_for_body(ship, body)
		for _frame in 5:
			await get_tree().process_frame
		if not _save_view(CAPTURE_DIR + "/" + body_name.to_lower() + ".png"):
			get_tree().quit(1)
			return

	get_tree().quit()


func _position_ship_for_body(ship: ShipController, body: Node3D) -> void:
	var visual_radius := 20.0
	if body is MeshInstance3D:
		var sphere := (body as MeshInstance3D).mesh as SphereMesh
		if sphere != null:
			visual_radius = sphere.radius

	var radial := body.global_position
	if radial.length_squared() < 0.001:
		radial = Vector3.RIGHT
	var starward := -radial.normalized()
	var distance := visual_radius * 4.2 + 20.0
	# A modest elevated inspection angle exposes cloud geometry and, on Kharis,
	# the broad ring plane while still keeping the cockpit in frame.
	ship.global_position = body.global_position + starward * distance + Vector3.UP * visual_radius * 0.55
	ship.look_at(body.global_position, Vector3.UP)


func _scannable_named(scan_name: String) -> Node3D:
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if candidate is Node3D and str(candidate.get_meta("scan_name", "")).to_upper() == scan_name:
			return candidate as Node3D
	return null


func _save_view(path: String) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save visual preview %s: %s" % [path, error_string(error)])
		return false
	print("Saved visual preview to %s" % path)
	return true
