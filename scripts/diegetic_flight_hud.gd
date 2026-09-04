extends FlightHUD
class_name DiegeticFlightHUD


func _ready() -> void:
	super._ready()
	# FlightHUD still owns scanner/status logic, but the old virtual sticks and
	# rectangular action buttons are no longer the phone controls. The 3D cockpit
	# hardware drives the same ShipController underneath.
	for node_name in ["RollLeft", "RollRight", "RcsUp", "RcsDown"]:
		var button := get_node_or_null(node_name) as Button
		if button != null:
			button.visible = false
	if mode_button != null:
		mode_button.visible = false
	if lock_button != null:
		lock_button.visible = false
	if scan_button != null:
		scan_button.visible = false
	queue_redraw()


func _input(_event: InputEvent) -> void:
	# Touchscreen flight input belongs to DiegeticCockpitControls. Physical
	# controller and keyboard input continue to be read directly by ShipController.
	pass


func _draw() -> void:
	var line_color := Color(0.28, 0.84, 0.9, 0.56)
	var active_color := Color(0.65, 0.96, 1.0, 0.86)
	var viewport_size := get_viewport_rect().size
	var reticle_center := viewport_size * 0.5

	# Keep only information that belongs on the canopy/HUD. There are deliberately
	# no virtual joystick circles here; the pilot manipulates visible cockpit parts.
	draw_arc(reticle_center, 30.0, 0.0, TAU, 40, Color(0.30, 0.74, 0.8, 0.34), 1.5)
	draw_line(reticle_center + Vector2(-48.0, 0.0), reticle_center + Vector2(-20.0, 0.0), line_color, 1.5)
	draw_line(reticle_center + Vector2(20.0, 0.0), reticle_center + Vector2(48.0, 0.0), line_color, 1.5)
	draw_line(reticle_center + Vector2(0.0, -48.0), reticle_center + Vector2(0.0, -20.0), line_color, 1.5)
	draw_line(reticle_center + Vector2(0.0, 20.0), reticle_center + Vector2(0.0, 48.0), line_color, 1.5)

	if scan_target != null and is_instance_valid(scan_target):
		var camera := _camera()
		if camera != null and not camera.is_position_behind(scan_target.global_position):
			var marker := camera.unproject_position(scan_target.global_position)
			var target_color := line_color.lerp(active_color, scan_signal)
			_draw_target_brackets(marker, target_color)
			draw_arc(
				reticle_center,
				38.0,
				-PI * 0.5,
				-PI * 0.5 + TAU * scan_progress,
				48,
				target_color,
				3.0
			)
