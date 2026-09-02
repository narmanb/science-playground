extends Control
class_name ProximityHUD

@export var ship_path: NodePath
@export var caution_clearance_radii := 6.0
@export var danger_clearance_radii := 1.4

var ship: ShipController
var warning_label: Label
var previous_positions: Dictionary = {}
var estimated_velocities: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship = get_node(ship_path) as ShipController
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 18)
	warning_label.visible = false
	add_child(warning_label)
	_layout_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()


func _process(delta: float) -> void:
	if ship == null:
		return
	_update_body_velocities(delta)
	var nearest := _nearest_body()
	if nearest.is_empty():
		warning_label.visible = false
		return

	var body: Node3D = nearest["body"]
	var radius: float = nearest["radius"]
	var clearance: float = nearest["clearance"]
	if clearance > radius * caution_clearance_radii:
		warning_label.visible = false
		return

	var to_body := body.global_position - ship.global_position
	var closing_speed := 0.0
	if to_body.length_squared() > 0.0001:
		var relative_velocity := ship.linear_velocity - _body_velocity(body)
		closing_speed = relative_velocity.dot(to_body.normalized())

	var status := "PROXIMITY"
	var font_color := Color(1.0, 0.78, 0.35, 0.95)
	if clearance <= radius * danger_clearance_radii:
		status = "COLLISION RISK"
		font_color = Color(1.0, 0.32, 0.28, 0.98)
	elif closing_speed > 8.0:
		status = "RAPID APPROACH"

	var eta_text := ""
	if closing_speed > 0.5:
		eta_text = "   •   CONTACT %.1fs" % (maxf(clearance, 0.0) / closing_speed)

	warning_label.text = "%s — %s   •   ALT %.1f u   •   CLOSING %.1f u/s%s" % [
		status,
		_target_name(body),
		maxf(clearance, 0.0),
		closing_speed,
		eta_text,
	]
	warning_label.add_theme_color_override("font_color", font_color)
	warning_label.visible = true


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


func _nearest_body() -> Dictionary:
	var best: Dictionary = {}
	var best_clearance := INF
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is Node3D:
			continue
		var body := candidate as Node3D
		var radius := _body_radius(body)
		if radius <= 0.0:
			continue
		var clearance := ship.global_position.distance_to(body.global_position) - radius
		if clearance < best_clearance:
			best_clearance = clearance
			best = {
				"body": body,
				"radius": radius,
				"clearance": clearance,
			}
	return best


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


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	warning_label.position = Vector2(size.x * 0.20, 92.0)
	warning_label.size = Vector2(size.x * 0.60, 30.0)
