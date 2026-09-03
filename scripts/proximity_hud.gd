extends Control
class_name ProximityHUD

const TrajectoryMathScript = preload("res://scripts/trajectory_math.gd")

@export var ship_path: NodePath
@export var caution_clearance_radii := 6.0
@export var danger_clearance_radii := 1.4
@export var prediction_horizon_s := 60.0

var ship: ShipController
var warning_label: Label
var previous_positions: Dictionary = {}
var estimated_velocities: Dictionary = {}
var avoidance_delta_v := 0.0
var avoidance_deflection_deg := 0.0
var avoidance_world_delta_v := Vector3.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship = get_node(ship_path) as ShipController
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.add_theme_font_size_override("font_size", 16)
	warning_label.visible = false
	add_child(warning_label)
	_layout_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()
		queue_redraw()


func _process(delta: float) -> void:
	if ship == null:
		return
	avoidance_delta_v = 0.0
	avoidance_deflection_deg = 0.0
	avoidance_world_delta_v = Vector3.ZERO
	queue_redraw()
	_update_body_velocities(delta)
	var hazard := _relevant_body()
	if hazard.is_empty():
		warning_label.visible = false
		return

	var body: Node3D = hazard["body"]
	var radius: float = hazard["radius"]
	var clearance: float = hazard["clearance"]
	var trajectory: Dictionary = hazard["trajectory"]
	var predicted_clearance := float(trajectory["clearance"])
	var time_to_cpa := float(trajectory["time"])
	var future_cpa := bool(trajectory["future"])
	var predicted_in_horizon := future_cpa and time_to_cpa <= prediction_horizon_s

	# A future close pass can deserve attention before the ship enters the local
	# proximity band. Otherwise retain the original range-gated behavior.
	var predicted_hazard := predicted_in_horizon and predicted_clearance <= radius * caution_clearance_radii
	if clearance > radius * caution_clearance_radii and not predicted_hazard:
		warning_label.visible = false
		return

	var to_body := body.global_position - ship.global_position
	var closing_speed := 0.0
	if to_body.length_squared() > 0.0001:
		var relative_velocity := ship.linear_velocity - _body_velocity(body)
		closing_speed = relative_velocity.dot(to_body.normalized())

	var status := "PROXIMITY"
	var font_color := Color(1.0, 0.78, 0.35, 0.95)
	if predicted_in_horizon and predicted_clearance <= 0.0:
		status = "IMPACT CORRIDOR"
		font_color = Color(1.0, 0.24, 0.20, 0.99)
	elif clearance <= radius * danger_clearance_radii:
		status = "COLLISION RISK"
		font_color = Color(1.0, 0.32, 0.28, 0.98)
	elif predicted_in_horizon and predicted_clearance > radius * danger_clearance_radii:
		status = "PROJECTED FLYBY"
		font_color = Color(0.74, 0.94, 0.82, 0.96)
	elif closing_speed > 8.0:
		status = "RAPID APPROACH"

	var cpa_text := "TRAJECTORY HOLD"
	if predicted_in_horizon:
		if predicted_clearance <= 0.0:
			var escape := _collision_cone_escape(body, radius)
			if not escape.is_empty():
				avoidance_delta_v = float(escape["delta_v"])
				avoidance_deflection_deg = float(escape["deflection_deg"])
				avoidance_world_delta_v = escape["delta_v_vector"] as Vector3
				cpa_text = "CPA %.1fs   •   IMPACT DEPTH %.1f u   •   MIN ESC Δv %.1f u/s   •   DEFLECT %.1f°" % [
					time_to_cpa,
					absf(predicted_clearance),
					avoidance_delta_v,
					avoidance_deflection_deg,
				]
			else:
				cpa_text = "CPA %.1fs   •   IMPACT DEPTH %.1f u INSIDE SHELL" % [
					time_to_cpa,
					absf(predicted_clearance),
				]
		else:
			cpa_text = "CPA %.1fs   •   PRED CLR %.1f u" % [time_to_cpa, predicted_clearance]
	elif future_cpa:
		cpa_text = "CPA >%.0fs   •   OUTSIDE PREDICTION WINDOW" % prediction_horizon_s

	warning_label.text = "%s — %s   •   ALT %.1f u   •   CLOSING %.1f u/s\n%s" % [
		status,
		_target_name(body),
		maxf(clearance, 0.0),
		closing_speed,
		cpa_text,
	]
	warning_label.add_theme_color_override("font_color", font_color)
	warning_label.visible = true


func _draw() -> void:
	if avoidance_world_delta_v.length_squared() <= 0.000001:
		return
	var camera := _camera()
	if camera == null:
		return

	var delta_direction := avoidance_world_delta_v.normalized()
	var camera_right := camera.global_basis.x
	var camera_up := camera.global_basis.y
	var camera_forward := -camera.global_basis.z
	var screen_direction := Vector2(
		delta_direction.dot(camera_right),
		-delta_direction.dot(camera_up)
	)

	# A near-pure fore/aft correction has almost no 2D lateral projection. Keep
	# the cue deterministic by placing it above/below the reticle according to the
	# sign of its camera-forward component rather than allowing the arrow to vanish.
	if screen_direction.length_squared() < 0.0025:
		screen_direction = Vector2(0.0, -1.0 if delta_direction.dot(camera_forward) >= 0.0 else 1.0)
	else:
		screen_direction = screen_direction.normalized()

	var center := get_viewport_rect().size * 0.5
	var tip := center + screen_direction * 78.0
	var tail := tip - screen_direction * 24.0
	var perpendicular := Vector2(-screen_direction.y, screen_direction.x)
	var cue_color := Color(0.45, 1.0, 0.70, 0.96)
	draw_line(tail, tip, cue_color, 3.0)
	draw_line(tip, tail + perpendicular * 9.0, cue_color, 3.0)
	draw_line(tip, tail - perpendicular * 9.0, cue_color, 3.0)
	draw_arc(tip, 11.0, 0.0, TAU, 24, cue_color, 1.5)


func _update_body_velocities(delta: float) -> void:
	if delta <= 0.0001:
		return
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is Node3D:
			continue
		var body := candidate as Node3D
		var key := body.get_instance_id()
		var position_value := body.global_position
		if previous_positions.has(key):
			estimated_velocities[key] = (position_value - previous_positions[key]) / delta
		previous_positions[key] = position_value


func _body_velocity(body: Node3D) -> Vector3:
	var key := body.get_instance_id()
	return estimated_velocities.get(key, Vector3.ZERO)


func _trajectory_for(body: Node3D, radius: float) -> Dictionary:
	var relative_position := ship.global_position - body.global_position
	var relative_velocity := ship.linear_velocity - _body_velocity(body)
	return TrajectoryMathScript.closest_approach(relative_position, relative_velocity, radius)


func _collision_cone_escape(body: Node3D, radius: float) -> Dictionary:
	var relative_position := ship.global_position - body.global_position
	var relative_velocity := ship.linear_velocity - _body_velocity(body)
	return TrajectoryMathScript.collision_cone_escape(
		relative_position,
		relative_velocity,
		radius,
		ship.global_basis.x
	)


func _relevant_body() -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_clearance := INF
	var predicted_best: Dictionary = {}
	var predicted_rank := 99
	var predicted_time := INF

	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is Node3D:
			continue
		var body := candidate as Node3D
		var radius := _body_radius(body)
		if radius <= 0.0:
			continue
		var clearance := ship.global_position.distance_to(body.global_position) - radius
		var trajectory := _trajectory_for(body, radius)
		var entry := {
			"body": body,
			"radius": radius,
			"clearance": clearance,
			"trajectory": trajectory,
		}

		if clearance < nearest_clearance:
			nearest_clearance = clearance
			nearest = entry

		var future := bool(trajectory["future"])
		var time_to_cpa := float(trajectory["time"])
		var predicted_clearance := float(trajectory["clearance"])
		if not future or time_to_cpa > prediction_horizon_s:
			continue
		if predicted_clearance > radius * caution_clearance_radii:
			continue

		# Direct shell intersections outrank non-impacting close passes; within the
		# same class, surface the one that reaches closest approach first.
		var rank := 0 if predicted_clearance <= 0.0 else 1
		if rank < predicted_rank or (rank == predicted_rank and time_to_cpa < predicted_time):
			predicted_rank = rank
			predicted_time = time_to_cpa
			predicted_best = entry

	return predicted_best if not predicted_best.is_empty() else nearest


func _body_radius(body: Node3D) -> float:
	if body.has_meta("collision_radius"):
		return float(body.get_meta("collision_radius"))
	if body is MeshInstance3D:
		var sphere := (body as MeshInstance3D).mesh as SphereMesh
		if sphere != null:
			return sphere.radius
	return 0.0


func _target_name(body: Node3D) -> String:
	return str(body.get_meta("scan_name", body.name)).to_upper()


func _camera() -> Camera3D:
	return ship.get_node_or_null("CameraRig/Camera3D") as Camera3D


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	warning_label.position = Vector2(size.x * 0.18, 84.0)
	warning_label.size = Vector2(size.x * 0.64, 54.0)
