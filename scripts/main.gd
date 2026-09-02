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
	var science_log := get_node_or_null("HUDLayer/ScienceLogHUD") as ScienceLogHUD
	var science_objective := get_node_or_null("HUDLayer/ScienceObjectiveHUD") as ScienceObjectiveHUD
	if ship == null or hud == null or nav == null or science_log == null or science_objective == null:
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

	# Finish the same scan in a deliberately stable test configuration, then open
	# the persistent science catalog. This exercises scan completion -> science
	# tier -> discovery signal -> saved catalog -> rendered UI in one CI run.
	if hud.scan_target != null:
		var locked_target := hud.scan_target
		ship.freeze = true
		ship.linear_velocity = Vector3.ZERO
		ship.angular_velocity = Vector3.ZERO
		ship.look_at(locked_target.global_position, Vector3.UP)

	var completion_frames := 0
	while hud.scan_target != null and completion_frames < 360:
		await get_tree().process_frame
		completion_frames += 1
	if hud.scan_target != null:
		push_error("Visual smoke test could not complete the held science scan.")
		get_tree().quit(1)
		return
	if not science_log.discoveries.has("NYSA"):
		push_error("Visual smoke test completed a scan but the science catalog did not record Nysa.")
		get_tree().quit(1)
		return

	science_log.toggle_log()
	for _frame in 3:
		await get_tree().process_frame
	if not _save_view(CAPTURE_DIR + "/catalog.png"):
		get_tree().quit(1)
		return
	science_log.toggle_log()

	# Once the catalog closes, the contextual objective should immediately use
	# the saved discovery depth and tell the pilot that Nysa is fully surveyed.
	for _frame in 3:
		await get_tree().process_frame
	if science_objective.objective_label == null or not science_objective.objective_label.visible:
		push_error("Visual smoke test completed Nysa but the science objective did not return.")
		get_tree().quit(1)
		return
	if not science_objective.objective_label.text.contains("FULL SURVEY COMPLETE"):
		push_error("Visual smoke test science objective did not advance after the Nysa scan.")
		get_tree().quit(1)
		return
	if not _save_view(CAPTURE_DIR + "/objective.png"):
		get_tree().quit(1)
		return

	# Science-priority NAV must skip the now-complete Nysa survey and choose the
	# next unfinished body in deterministic order. This makes the objective's
	# "next science" instruction an end-to-end tested action rather than prose.
	nav.cycle_science_target()
	for _frame in 3:
		await get_tree().process_frame
	var science_target := nav.current_target()
	if science_target == null or str(science_target.get_meta("scan_name", science_target.name)).to_upper() != "VEYR":
		push_error("Science-priority NAV did not advance from completed Nysa to Veyr.")
		get_tree().quit(1)
		return
	if not science_objective.objective_label.text.contains("SCIENCE VEYR"):
		push_error("Science objective did not follow the science-priority NAV target.")
		get_tree().quit(1)
		return
	if hud.completed_report_visible or hud.scan_label.text.contains("NYSA"):
		push_error("Sensor HUD retained stale Nysa report data after NAV advanced to Veyr.")
		get_tree().quit(1)
		return
	if not _save_view(CAPTURE_DIR + "/science_nav.png"):
		get_tree().quit(1)
		return

	# Simulate a previously completed Remote survey on Veyr without writing it to
	# disk. Face the target so the safe-margin test exercises 100% fore/aft radial
	# braking authority deterministically, then give the frozen CI ship a modest
	# stored closing velocity.
	science_log.discoveries["VEYR"] = 0
	ship.look_at(science_target.global_position, Vector3.UP)
	for _frame in 2:
		await get_tree().process_frame
	var toward_veyr := science_target.global_position - ship.global_position
	if toward_veyr.length_squared() > 0.0001:
		ship.linear_velocity = toward_veyr.normalized() * 6.0
	for _frame in 6:
		await get_tree().process_frame
	var approach_text := science_objective.objective_label.text
	if not approach_text.contains("APPROACH FOR SPECTRAL PASS"):
		push_error("Science approach objective did not request Veyr's Spectral pass.")
		get_tree().quit(1)
		return
	if not approach_text.contains("ENVELOPE ≤12.0 R") or not approach_text.contains("NOW"):
		push_error("Science approach objective did not expose the Spectral envelope geometry.")
		get_tree().quit(1)
		return
	if not approach_text.contains("CLOSING"):
		push_error("Science approach objective did not report deterministic relative closing motion.")
		get_tree().quit(1)
		return
	if not approach_text.contains("MAIN AXIS 100%") or not approach_text.contains("THRUST STOP") or not approach_text.contains("BRAKE MARGIN"):
		push_error("Science approach objective did not expose aligned thrust stopping distance and positive braking margin.")
		get_tree().quit(1)
		return
	if not _save_view(CAPTURE_DIR + "/approach.png"):
		get_tree().quit(1)
		return

	# Move the frozen CI ship just outside Veyr's Spectral boundary and give it a
	# closing speed whose aligned thrust-only stopping distance is longer than the
	# remaining gap. This must flip the same instrument from margin to emergency.
	var veyr_radius := float(science_target.get_meta("collision_radius", 0.0))
	var spectral_radii := float(science_target.get_meta("scan_profile_spectral_clearance_radii", 0.0))
	if veyr_radius <= 0.0 or spectral_radii <= 0.0:
		push_error("Science braking test could not read Veyr radius/envelope metadata.")
		get_tree().quit(1)
		return
	var outward := ship.global_position - science_target.global_position
	if outward.length_squared() < 0.001:
		outward = Vector3.RIGHT
	outward = outward.normalized()
	var braking_gap := 8.0
	ship.global_position = science_target.global_position + outward * (veyr_radius * (1.0 + spectral_radii) + braking_gap)
	ship.linear_velocity = -outward * 32.0
	ship.angular_velocity = Vector3.ZERO
	ship.look_at(science_target.global_position, Vector3.UP)
	for _frame in 8:
		await get_tree().process_frame
	var braking_text := science_objective.objective_label.text
	if not braking_text.contains("BRAKE / ALIGN NOW") or not science_objective.braking_required:
		push_error("Science braking guidance did not transition to emergency when stopping distance exceeded the envelope gap.")
		get_tree().quit(1)
		return
	if not braking_text.contains("MAIN AXIS 100%") or not braking_text.contains("STOP") or not braking_text.contains("ENVELOPE IN"):
		push_error("Emergency braking state did not expose aligned stopping distance and remaining envelope distance.")
		get_tree().quit(1)
		return
	if not _save_view(CAPTURE_DIR + "/braking.png"):
		get_tree().quit(1)
		return

	# Prove both sides of NAV-aware acquisition. First, explicit NAV intent must
	# outrank a better-centered competing body while Veyr is still inside the
	# legitimate cone. Then, once Veyr is rotated outside that cone, the centered
	# competitor must win so NAV never behaves like an invisible hard lock.
	var camera := ship.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera == null:
		push_error("NAV-aware scan test could not find the cockpit camera.")
		get_tree().quit(1)
		return
	var target_direction := (science_target.global_position - camera.global_position).normalized()
	var side_direction := target_direction.cross(Vector3.UP)
	if side_direction.length_squared() < 0.001:
		side_direction = target_direction.cross(Vector3.RIGHT)
	side_direction = side_direction.normalized()

	var inside_angle := deg_to_rad(10.0)
	var inside_forward := (target_direction * cos(inside_angle) + side_direction * sin(inside_angle)).normalized()
	ship.look_at(ship.global_position + inside_forward * 100.0, Vector3.UP)
	for _frame in 2:
		await get_tree().process_frame

	camera = ship.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var decoy := Node3D.new()
	decoy.name = "CIScanDecoy"
	decoy.set_meta("scan_name", "CI DECOY")
	decoy.set_meta("scan_class", "QA TARGET")
	decoy.set_meta("scan_note", "Temporary CI scan-acquisition competitor.")
	add_child(decoy)
	decoy.add_to_group("scannable")
	decoy.global_position = camera.global_position + (-camera.global_basis.z) * 100.0
	await get_tree().process_frame

	var preferred_acquisition := hud._find_scan_target(camera, hud.scan_acquire_dot)
	if preferred_acquisition != science_target:
		push_error("Scanner allowed a centered competitor to steal acquisition from the valid selected NAV target.")
		get_tree().quit(1)
		return

	var outside_angle := deg_to_rad(30.0)
	target_direction = (science_target.global_position - camera.global_position).normalized()
	side_direction = target_direction.cross(Vector3.UP)
	if side_direction.length_squared() < 0.001:
		side_direction = target_direction.cross(Vector3.RIGHT)
	side_direction = side_direction.normalized()
	var outside_forward := (target_direction * cos(outside_angle) + side_direction * sin(outside_angle)).normalized()
	ship.look_at(ship.global_position + outside_forward * 100.0, Vector3.UP)
	for _frame in 2:
		await get_tree().process_frame
	camera = ship.get_node_or_null("CameraRig/Camera3D") as Camera3D
	decoy.global_position = camera.global_position + (-camera.global_basis.z) * 100.0
	await get_tree().process_frame

	var free_acquisition := hud._find_scan_target(camera, hud.scan_acquire_dot)
	if free_acquisition != decoy:
		push_error("Scanner kept the NAV target after it left the acquisition cone instead of returning to free scanning.")
		get_tree().quit(1)
		return
	decoy.queue_free()
	await get_tree().process_frame

	# The remaining views are visual QA only. Freeze and reposition the test ship
	# starward of each world so its illuminated hemisphere faces the camera. None
	# of these teleports exist during normal gameplay.
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
