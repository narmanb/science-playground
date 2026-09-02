extends Control
class_name FlightHUD

signal scan_completed(target: Node3D, tier: int)

const ACTIVE_SCAN_FONT_SIZE := 21
const REPORT_SCAN_FONT_SIZE := 15

@export var ship_path: NodePath
@export var scan_duration := 3.2
@export var scan_acquire_dot := 0.94
@export var scan_hold_dot := 0.90

var ship: ShipController
var left_touch_id := -1
var right_touch_id := -1
var left_value := Vector2.ZERO
var right_value := Vector2.ZERO
var left_center := Vector2.ZERO
var right_center := Vector2.ZERO
var pad_radius := 150.0

var status_label: Label
var scan_label: Label
var mode_button: Button
var lock_button: Button
var scan_button: Button

var scan_target: Node3D = null
var scan_progress := 0.0
var scan_signal := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship = get_node(ship_path) as ShipController
	_build_cockpit_controls()
	ship.flight_mode_changed.connect(_on_mode_changed)
	ship.inertial_lock_changed.connect(_on_lock_changed)
	ship.scan_requested.connect(_on_scan_requested)
	_on_mode_changed(ShipController.MODE_NAMES[ship.flight_mode])
	_on_lock_changed(ship.inertial_lock)
	_layout_ui()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()
		queue_redraw()


func _process(delta: float) -> void:
	if ship == null:
		return
	var speed := ship.linear_velocity.length()
	status_label.text = "%s   |   %.1f u/s   |   LOCK %s" % [
		ShipController.MODE_NAMES[ship.flight_mode],
		speed,
		"ON" if ship.inertial_lock else "OFF"
	]

	if scan_target != null:
		_update_scan(delta)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if ship == null:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if left_touch_id == -1 and event.position.distance_to(left_center) <= pad_radius * 1.25:
				left_touch_id = event.index
				_update_left_pad(event.position)
				get_viewport().set_input_as_handled()
			elif right_touch_id == -1 and event.position.distance_to(right_center) <= pad_radius * 1.25:
				right_touch_id = event.index
				_update_right_pad(event.position)
				get_viewport().set_input_as_handled()
		else:
			if event.index == left_touch_id:
				left_touch_id = -1
				left_value = Vector2.ZERO
				ship.set_touch_vector(Vector2.ZERO)
				queue_redraw()
			elif event.index == right_touch_id:
				right_touch_id = -1
				right_value = Vector2.ZERO
				ship.set_touch_attitude(Vector2.ZERO)
				queue_redraw()

	elif event is InputEventScreenDrag:
		if event.index == left_touch_id:
			_update_left_pad(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == right_touch_id:
			_update_right_pad(event.position)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var line_color := Color(0.28, 0.84, 0.9, 0.56)
	var active_color := Color(0.65, 0.96, 1.0, 0.86)
	var dim_color := Color(0.18, 0.42, 0.48, 0.30)

	for center in [left_center, right_center]:
		draw_circle(center, pad_radius, dim_color)
		draw_arc(center, pad_radius, 0.0, TAU, 64, line_color, 3.0)
		draw_arc(center, pad_radius * 0.55, 0.0, TAU, 48, line_color, 1.5)
		draw_line(center + Vector2(-pad_radius, 0), center + Vector2(pad_radius, 0), line_color, 1.0)
		draw_line(center + Vector2(0, -pad_radius), center + Vector2(0, pad_radius), line_color, 1.0)

	draw_circle(left_center + Vector2(left_value.x, -left_value.y) * pad_radius, 22.0, active_color)
	draw_circle(right_center + right_value * pad_radius, 22.0, active_color)

	var viewport_size := get_viewport_rect().size
	var reticle_center := viewport_size * 0.5
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


func _draw_target_brackets(center: Vector2, color: Color) -> void:
	var radius := 30.0
	var arm := 11.0
	draw_line(center + Vector2(-radius, -radius), center + Vector2(-radius + arm, -radius), color, 2.0)
	draw_line(center + Vector2(-radius, -radius), center + Vector2(-radius, -radius + arm), color, 2.0)
	draw_line(center + Vector2(radius, -radius), center + Vector2(radius - arm, -radius), color, 2.0)
	draw_line(center + Vector2(radius, -radius), center + Vector2(radius, -radius + arm), color, 2.0)
	draw_line(center + Vector2(-radius, radius), center + Vector2(-radius + arm, radius), color, 2.0)
	draw_line(center + Vector2(-radius, radius), center + Vector2(-radius, radius - arm), color, 2.0)
	draw_line(center + Vector2(radius, radius), center + Vector2(radius - arm, radius), color, 2.0)
	draw_line(center + Vector2(radius, radius), center + Vector2(radius, radius - arm), color, 2.0)


func _build_cockpit_controls() -> void:
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 24)
	add_child(status_label)

	scan_label = Label.new()
	scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scan_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scan_label.add_theme_font_size_override("font_size", ACTIVE_SCAN_FONT_SIZE)
	scan_label.text = "NO TARGET DATA"
	add_child(scan_label)

	mode_button = _make_button("MODE")
	mode_button.pressed.connect(ship.cycle_flight_mode)

	lock_button = _make_button("INERTIAL\nLOCK")
	lock_button.pressed.connect(ship.toggle_inertial_lock)

	scan_button = _make_button("SCAN")
	scan_button.pressed.connect(ship.request_scan)

	var roll_left := _make_button("ROLL ◀")
	roll_left.button_down.connect(func(): ship.set_touch_roll(-1.0))
	roll_left.button_up.connect(func(): ship.set_touch_roll(0.0))

	var roll_right := _make_button("ROLL ▶")
	roll_right.button_down.connect(func(): ship.set_touch_roll(1.0))
	roll_right.button_up.connect(func(): ship.set_touch_roll(0.0))

	var rcs_up := _make_button("RCS ▲")
	rcs_up.button_down.connect(func(): ship.set_touch_vertical(1.0))
	rcs_up.button_up.connect(func(): ship.set_touch_vertical(0.0))

	var rcs_down := _make_button("RCS ▼")
	rcs_down.button_down.connect(func(): ship.set_touch_vertical(-1.0))
	rcs_down.button_up.connect(func(): ship.set_touch_vertical(0.0))

	roll_left.name = "RollLeft"
	roll_right.name = "RollRight"
	rcs_up.name = "RcsUp"
	rcs_down.name = "RcsDown"


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 19)
	add_child(button)
	return button


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	pad_radius = clampf(size.y * 0.155, 92.0, 180.0)
	left_center = Vector2(size.x * 0.16, size.y * 0.72)
	right_center = Vector2(size.x * 0.84, size.y * 0.72)

	status_label.position = Vector2(size.x * 0.25, 18.0)
	status_label.size = Vector2(size.x * 0.5, 44.0)
	scan_label.position = Vector2(size.x * 0.29, size.y * 0.70)
	scan_label.size = Vector2(size.x * 0.42, size.y * 0.24)

	var button_w := clampf(size.x * 0.09, 110.0, 180.0)
	var button_h := clampf(size.y * 0.09, 60.0, 94.0)
	mode_button.position = Vector2(22.0, 22.0)
	mode_button.size = Vector2(button_w, button_h)
	lock_button.position = Vector2(32.0 + button_w, 22.0)
	lock_button.size = Vector2(button_w * 1.12, button_h)
	scan_button.position = Vector2(size.x - button_w - 22.0, 22.0)
	scan_button.size = Vector2(button_w, button_h)

	var roll_left := get_node_or_null("RollLeft") as Button
	var roll_right := get_node_or_null("RollRight") as Button
	var rcs_up := get_node_or_null("RcsUp") as Button
	var rcs_down := get_node_or_null("RcsDown") as Button
	if roll_left:
		roll_left.position = Vector2(size.x * 0.39 - button_w, size.y - button_h - 20.0)
		roll_left.size = Vector2(button_w, button_h)
	if roll_right:
		roll_right.position = Vector2(size.x * 0.61, size.y - button_h - 20.0)
		roll_right.size = Vector2(button_w, button_h)
	if rcs_up:
		rcs_up.position = Vector2(22.0, size.y * 0.39)
		rcs_up.size = Vector2(button_w, button_h)
	if rcs_down:
		rcs_down.position = Vector2(22.0, size.y * 0.39 + button_h + 10.0)
		rcs_down.size = Vector2(button_w, button_h)


func _update_left_pad(position_value: Vector2) -> void:
	var delta := (position_value - left_center) / pad_radius
	delta = delta.limit_length(1.0)
	left_value = Vector2(delta.x, -delta.y)
	ship.set_touch_vector(left_value)
	queue_redraw()


func _update_right_pad(position_value: Vector2) -> void:
	var delta := (position_value - right_center) / pad_radius
	right_value = delta.limit_length(1.0)
	ship.set_touch_attitude(right_value)
	queue_redraw()


func _on_mode_changed(mode_name: String) -> void:
	mode_button.text = "MODE\n" + mode_name


func _on_lock_changed(enabled: bool) -> void:
	lock_button.text = "LOCK\n" + ("ENGAGED" if enabled else "FREE")


func _on_scan_requested() -> void:
	if scan_target != null:
		_cancel_scan("SCAN ABORTED")
		return

	scan_label.add_theme_font_size_override("font_size", ACTIVE_SCAN_FONT_SIZE)
	var camera := _camera()
	if camera == null:
		scan_label.text = "SCAN ERROR — CAMERA OFFLINE"
		return

	var best_target := _find_scan_target(camera, scan_acquire_dot)
	if best_target == null:
		scan_label.text = "SCAN: CENTER A BODY INSIDE THE SENSOR RETICLE"
		return

	scan_target = best_target
	scan_progress = 0.0
	scan_signal = 0.0
	scan_button.text = "ABORT"
	scan_label.text = "%s\nSENSOR LOCK ACQUIRED\nHOLD TARGET IN RETICLE" % _target_name(scan_target)
	queue_redraw()


func _update_scan(delta: float) -> void:
	if scan_target == null or not is_instance_valid(scan_target):
		_cancel_scan("SCAN LOST — TARGET INVALID")
		return

	var camera := _camera()
	if camera == null:
		_cancel_scan("SCAN LOST — CAMERA OFFLINE")
		return

	var to_target := scan_target.global_position - camera.global_position
	if to_target.length_squared() < 0.0001:
		_cancel_scan("SCAN LOST — RANGE ERROR")
		return

	var direction := to_target.normalized()
	var forward := -camera.global_basis.z
	var alignment_dot := forward.dot(direction)
	var alignment := clampf((alignment_dot - scan_hold_dot) / maxf(1.0 - scan_hold_dot, 0.001), 0.0, 1.0)
	var angular_stability := 1.0 - clampf(ship.angular_velocity.length() / 2.0, 0.0, 1.0)
	scan_signal = alignment * lerpf(0.55, 1.0, angular_stability)

	if alignment_dot >= scan_hold_dot:
		scan_progress += delta * scan_signal / maxf(scan_duration, 0.1)
	else:
		scan_progress -= delta * 0.14
	scan_progress = clampf(scan_progress, 0.0, 1.0)

	var distance := camera.global_position.distance_to(scan_target.global_position)
	var guidance := "HOLD STEADY"
	if alignment_dot < scan_hold_dot:
		guidance = "REACQUIRE — CENTER TARGET"
	elif scan_signal < 0.45:
		guidance = "REDUCE ROTATION"

	scan_label.text = "%s   |   RANGE %.1f u\nSIGNAL %d%%   ANALYSIS %d%%\n%s" % [
		_target_name(scan_target),
		distance,
		int(round(scan_signal * 100.0)),
		int(round(scan_progress * 100.0)),
		guidance,
	]

	if scan_progress >= 1.0:
		_complete_scan(camera)


func _complete_scan(camera: Camera3D) -> void:
	if scan_target == null:
		return
	var target := scan_target
	var distance := camera.global_position.distance_to(target.global_position)
	var tier := int(target.get_meta("scan_profile_tier", 0))
	var tier_name := _scan_tier_name(target, tier)
	var report_note := _compact_scan_note(str(target.get_meta("scan_note", "No additional data.")))
	scan_label.add_theme_font_size_override("font_size", REPORT_SCAN_FONT_SIZE)
	scan_label.text = "%s   •   %s\n%s COMPLETE   •   RANGE %.1f u\n%s" % [
		_target_name(target),
		str(target.get_meta("scan_class", "UNCLASSIFIED")),
		tier_name,
		distance,
		report_note,
	]
	scan_completed.emit(target, tier)
	scan_target = null
	scan_progress = 0.0
	scan_signal = 0.0
	scan_button.text = "SCAN"
	queue_redraw()


func _cancel_scan(message: String) -> void:
	scan_target = null
	scan_progress = 0.0
	scan_signal = 0.0
	scan_button.text = "SCAN"
	scan_label.add_theme_font_size_override("font_size", ACTIVE_SCAN_FONT_SIZE)
	scan_label.text = message
	queue_redraw()


func _scan_tier_name(target: Node3D, tier: int) -> String:
	if not target.has_meta("scan_profile_max_tier"):
		return "SURVEY"
	match clampi(tier, 0, 2):
		0:
			return "REMOTE SURVEY"
		1:
			return "SPECTRAL PASS"
		_:
			return "PROXIMITY PASS"


func _compact_scan_note(note: String) -> String:
	return note \
		.trim_prefix("[REMOTE SURVEY] ") \
		.trim_prefix("[SPECTRAL PASS] ") \
		.trim_prefix("[PROXIMITY PASS] ")


func _find_scan_target(camera: Camera3D, minimum_dot: float) -> Node3D:
	var best_target: Node3D = null
	var best_score := minimum_dot
	var forward := -camera.global_basis.z
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is Node3D:
			continue
		var target := candidate as Node3D
		var delta := target.global_position - camera.global_position
		if delta.length_squared() < 0.0001:
			continue
		var score := forward.dot(delta.normalized())
		if score > best_score:
			best_score = score
			best_target = target
	return best_target


func _target_name(target: Node3D) -> String:
	return str(target.get_meta("scan_name", target.name))


func _camera() -> Camera3D:
	return ship.get_node_or_null("CameraRig/Camera3D") as Camera3D
