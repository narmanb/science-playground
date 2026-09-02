extends Control
class_name VelocityVectorHUD

@export var ship_path: NodePath
@export var minimum_speed := 0.5
@export var projection_distance := 120.0

var ship: ShipController


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship = get_node(ship_path) as ShipController
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ship == null:
		return
	var speed := ship.linear_velocity.length()
	if speed < minimum_speed:
		return

	var camera := ship.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera == null:
		return

	var velocity_direction := ship.linear_velocity.normalized()
	var world_marker := camera.global_position + velocity_direction * projection_distance
	if camera.is_position_behind(world_marker):
		_draw_rear_velocity_cue(camera, velocity_direction)
		return

	var marker := camera.unproject_position(world_marker)
	var viewport_size := get_viewport_rect().size
	var margin := 34.0
	if marker.x < margin or marker.y < margin or marker.x > viewport_size.x - margin or marker.y > viewport_size.y - margin:
		_draw_edge_velocity_cue(marker, viewport_size)
		return

	var center := viewport_size * 0.5
	var drift_color := Color(1.0, 0.63, 0.18, 0.88)
	var guide_color := Color(1.0, 0.63, 0.18, 0.20)
	if marker.distance_to(center) > 45.0:
		draw_dashed_line(center, marker, guide_color, 1.2, 7.0, false)
	_draw_velocity_glyph(marker, drift_color)


func _draw_velocity_glyph(center: Vector2, color: Color) -> void:
	var radius := 11.0
	draw_arc(center, radius, 0.0, TAU, 28, color, 2.2)
	draw_circle(center, 2.4, color)
	draw_line(center + Vector2(-20.0, 0.0), center + Vector2(-13.0, 0.0), color, 2.0)
	draw_line(center + Vector2(13.0, 0.0), center + Vector2(20.0, 0.0), color, 2.0)
	draw_line(center + Vector2(0.0, -20.0), center + Vector2(0.0, -13.0), color, 2.0)
	draw_line(center + Vector2(0.0, 13.0), center + Vector2(0.0, 20.0), color, 2.0)


func _draw_edge_velocity_cue(projected: Vector2, viewport_size: Vector2) -> void:
	var center := viewport_size * 0.5
	var direction := projected - center
	if direction.length_squared() < 0.001:
		return
	var edge := _screen_edge_point(center, direction.normalized(), viewport_size, 42.0)
	_draw_chevron(edge, direction.normalized(), Color(1.0, 0.63, 0.18, 0.82))


func _draw_rear_velocity_cue(camera: Camera3D, world_direction: Vector3) -> void:
	var local_direction := camera.global_basis.inverse() * world_direction
	var screen_direction := Vector2(local_direction.x, -local_direction.y)
	if screen_direction.length_squared() < 0.001:
		screen_direction = Vector2(0.0, 1.0)
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var edge := _screen_edge_point(center, screen_direction.normalized(), viewport_size, 42.0)
	_draw_chevron(edge, screen_direction.normalized(), Color(1.0, 0.39, 0.12, 0.78))


func _screen_edge_point(center: Vector2, direction: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	var half_extents := viewport_size * 0.5 - Vector2.ONE * margin
	var scale_x := INF if absf(direction.x) < 0.0001 else half_extents.x / absf(direction.x)
	var scale_y := INF if absf(direction.y) < 0.0001 else half_extents.y / absf(direction.y)
	var scale := minf(scale_x, scale_y)
	return center + direction * scale


func _draw_chevron(center: Vector2, direction: Vector2, color: Color) -> void:
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var tip := center + forward * 10.0
	var back := center - forward * 8.0
	draw_line(tip, back + side * 8.0, color, 2.6)
	draw_line(tip, back - side * 8.0, color, 2.6)
	draw_circle(center - forward * 14.0, 2.2, color)
