extends Control
class_name NavigationHUD

@export var ship_path: NodePath

const PREFERRED_ORDER := ["NYSA", "VEYR", "ORUN", "KHARIS", "THALE", "ASTERION"]

var ship: ShipController
var nav_button: Button
var nav_label: Label
var targets: Array[Node3D] = []
var target_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship = get_node(ship_path) as ShipController
	_build_ui()
	_layout_ui()
	_refresh_targets.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()


func _process(_delta: float) -> void:
	if targets.is_empty():
		return
	var target := current_target()
	if target == null or not is_instance_valid(target):
		_refresh_targets.call_deferred()
		return
	var distance := ship.global_position.distance_to(target.global_position)
	nav_label.text = "NAV %s   •   %.1f u" % [_target_name(target), distance]
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		cycle_target()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		cycle_target()


func _draw() -> void:
	var target := current_target()
	if target == null or ship == null:
		return
	var camera := ship.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera == null:
		return

	var target_color := Color(0.55, 1.0, 0.62, 0.88)
	var viewport_size := get_viewport_rect().size
	var margin := 42.0

	if not camera.is_position_behind(target.global_position):
		var projected := camera.unproject_position(target.global_position)
		if projected.x >= margin and projected.y >= margin and projected.x <= viewport_size.x - margin and projected.y <= viewport_size.y - margin:
			_draw_nav_diamond(projected, target_color)
			return
		_draw_edge_cue(projected - viewport_size * 0.5, viewport_size, target_color)
		return

	var world_direction := (target.global_position - camera.global_position).normalized()
	var local_direction := camera.global_basis.inverse() * world_direction
	var screen_direction := Vector2(local_direction.x, -local_direction.y)
	if screen_direction.length_squared() < 0.001:
		screen_direction = Vector2(0.0, 1.0)
	_draw_edge_cue(screen_direction, viewport_size, Color(0.38, 0.75, 0.44, 0.72))


func _build_ui() -> void:
	nav_button = Button.new()
	nav_button.text = "NAV"
	nav_button.focus_mode = Control.FOCUS_NONE
	nav_button.add_theme_font_size_override("font_size", 18)
	nav_button.pressed.connect(cycle_target)
	add_child(nav_button)

	nav_label = Label.new()
	nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_label.add_theme_font_size_override("font_size", 18)
	nav_label.text = "NAV — ACQUIRING SYSTEM"
	add_child(nav_label)


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	var button_w := clampf(size.x * 0.075, 96.0, 142.0)
	var button_h := clampf(size.y * 0.075, 54.0, 78.0)
	nav_button.position = Vector2(size.x - button_w * 2.15 - 34.0, 22.0)
	nav_button.size = Vector2(button_w, button_h)
	nav_label.position = Vector2(size.x * 0.34, 58.0)
	nav_label.size = Vector2(size.x * 0.32, 32.0)


func _refresh_targets() -> void:
	# ScanRegistry registers procedural bodies deferred as they appear. Waiting a
	# few frames lets the system generator and registry settle without coupling
	# this HUD directly to either implementation.
	for _frame in 3:
		await get_tree().process_frame

	targets.clear()
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if candidate is Node3D:
			targets.append(candidate as Node3D)

	targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _target_sort_index(a) < _target_sort_index(b)
	)

	if targets.is_empty():
		target_index = -1
		nav_button.text = "NAV\nNONE"
		nav_label.text = "NAV — NO CELESTIAL FIX"
		queue_redraw()
		return

	target_index = 0
	for i in targets.size():
		if _target_name(targets[i]) == "NYSA":
			target_index = i
			break
	_update_button()
	queue_redraw()


func cycle_target() -> void:
	if targets.is_empty():
		_refresh_targets.call_deferred()
		return
	target_index = (target_index + 1) % targets.size()
	_update_button()
	queue_redraw()


func current_target() -> Node3D:
	if target_index < 0 or target_index >= targets.size():
		return null
	var target := targets[target_index]
	return target if is_instance_valid(target) else null


func _update_button() -> void:
	var target := current_target()
	nav_button.text = "NAV\n" + (_target_name(target) if target != null else "NONE")


func _target_name(target: Node3D) -> String:
	return str(target.get_meta("scan_name", target.name)).to_upper()


func _target_sort_index(target: Node3D) -> int:
	var body_name := _target_name(target)
	var index := PREFERRED_ORDER.find(body_name)
	return index if index >= 0 else PREFERRED_ORDER.size() + body_name.unicode_at(0)


func _draw_nav_diamond(center: Vector2, color: Color) -> void:
	var radius := 16.0
	var top := center + Vector2(0.0, -radius)
	var right := center + Vector2(radius, 0.0)
	var bottom := center + Vector2(0.0, radius)
	var left := center + Vector2(-radius, 0.0)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), color, 2.2)
	draw_circle(center, 2.0, color)
	draw_arc(center, 25.0, -0.55, 0.55, 12, color, 1.4)
	draw_arc(center, 25.0, PI - 0.55, PI + 0.55, 12, color, 1.4)


func _draw_edge_cue(direction_value: Vector2, viewport_size: Vector2, color: Color) -> void:
	if direction_value.length_squared() < 0.001:
		return
	var direction := direction_value.normalized()
	var center := viewport_size * 0.5
	var half_extents := viewport_size * 0.5 - Vector2.ONE * 44.0
	var scale_x := INF if absf(direction.x) < 0.0001 else half_extents.x / absf(direction.x)
	var scale_y := INF if absf(direction.y) < 0.0001 else half_extents.y / absf(direction.y)
	var edge := center + direction * minf(scale_x, scale_y)
	var side := Vector2(-direction.y, direction.x)
	var tip := edge + direction * 9.0
	var back := edge - direction * 8.0
	draw_line(tip, back + side * 8.0, color, 2.4)
	draw_line(tip, back - side * 8.0, color, 2.4)
	draw_arc(edge - direction * 15.0, 5.0, 0.0, TAU, 16, color, 1.5)
