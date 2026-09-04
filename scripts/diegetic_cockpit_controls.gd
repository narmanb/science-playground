extends Node3D
class_name DiegeticCockpitControls

@export var ship_path: NodePath
@export var camera_path: NodePath
@export var drag_radius_pixels := 125.0
@export var button_radius_pixels := 72.0

var ship: ShipController
var camera: Camera3D

var vector_root: Node3D
var vector_knob: MeshInstance3D
var attitude_root: Node3D
var attitude_knob: MeshInstance3D
var vertical_root: Node3D
var vertical_knob: MeshInstance3D
var roll_left: MeshInstance3D
var roll_right: MeshInstance3D
var mode_switch: MeshInstance3D
var lock_switch: MeshInstance3D
var scan_button: MeshInstance3D

var vector_touch := -1
var attitude_touch := -1
var vertical_touch := -1
var roll_touch := -1
var roll_touch_value := 0.0

var cyan_material: StandardMaterial3D
var cyan_dim_material: StandardMaterial3D
var amber_material: StandardMaterial3D
var red_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var metal_material: StandardMaterial3D


func _ready() -> void:
	ship = get_node(ship_path) as ShipController
	camera = get_node(camera_path) as Camera3D
	_build_materials()
	_build_hardware()
	if ship != null:
		ship.flight_mode_changed.connect(_on_mode_changed)
		ship.inertial_lock_changed.connect(_on_lock_changed)
		_on_mode_changed(ShipController.MODE_NAMES[ship.flight_mode])
		_on_lock_changed(ship.inertial_lock)


func _input(event: InputEvent) -> void:
	if ship == null or camera == null:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		_update_touch(event.index, event.position)


func _begin_touch(touch_id: int, screen_position: Vector2) -> void:
	if vector_touch < 0 and _hit(vector_root, screen_position, drag_radius_pixels):
		vector_touch = touch_id
		_update_vector(screen_position)
		_haptic(18)
		get_viewport().set_input_as_handled()
		return

	if attitude_touch < 0 and _hit(attitude_root, screen_position, drag_radius_pixels):
		attitude_touch = touch_id
		_update_attitude(screen_position)
		_haptic(18)
		get_viewport().set_input_as_handled()
		return

	if vertical_touch < 0 and _hit(vertical_root, screen_position, button_radius_pixels * 0.9):
		vertical_touch = touch_id
		_update_vertical(screen_position)
		_haptic(16)
		get_viewport().set_input_as_handled()
		return

	if _hit(roll_left, screen_position, button_radius_pixels):
		roll_touch = touch_id
		roll_touch_value = -1.0
		ship.set_touch_roll(-1.0)
		_set_pressed(roll_left, true)
		_haptic(20)
		get_viewport().set_input_as_handled()
		return

	if _hit(roll_right, screen_position, button_radius_pixels):
		roll_touch = touch_id
		roll_touch_value = 1.0
		ship.set_touch_roll(1.0)
		_set_pressed(roll_right, true)
		_haptic(20)
		get_viewport().set_input_as_handled()
		return

	if _hit(mode_switch, screen_position, button_radius_pixels):
		ship.cycle_flight_mode()
		_pulse_control(mode_switch)
		_haptic(28)
		get_viewport().set_input_as_handled()
		return

	if _hit(lock_switch, screen_position, button_radius_pixels):
		ship.toggle_inertial_lock()
		_pulse_control(lock_switch)
		_haptic(34)
		get_viewport().set_input_as_handled()
		return

	if _hit(scan_button, screen_position, button_radius_pixels * 1.05):
		ship.request_scan()
		_pulse_control(scan_button)
		_haptic(24)
		get_viewport().set_input_as_handled()


func _update_touch(touch_id: int, screen_position: Vector2) -> void:
	if touch_id == vector_touch:
		_update_vector(screen_position)
		get_viewport().set_input_as_handled()
	elif touch_id == attitude_touch:
		_update_attitude(screen_position)
		get_viewport().set_input_as_handled()
	elif touch_id == vertical_touch:
		_update_vertical(screen_position)
		get_viewport().set_input_as_handled()


func _end_touch(touch_id: int) -> void:
	if touch_id == vector_touch:
		vector_touch = -1
		ship.set_touch_vector(Vector2.ZERO)
		_animate_knob_home(vector_knob)
		get_viewport().set_input_as_handled()
	elif touch_id == attitude_touch:
		attitude_touch = -1
		ship.set_touch_attitude(Vector2.ZERO)
		_animate_knob_home(attitude_knob)
		get_viewport().set_input_as_handled()
	elif touch_id == vertical_touch:
		vertical_touch = -1
		ship.set_touch_vertical(0.0)
		_animate_slider_home()
		get_viewport().set_input_as_handled()
	elif touch_id == roll_touch:
		roll_touch = -1
		ship.set_touch_roll(0.0)
		_set_pressed(roll_left, false)
		_set_pressed(roll_right, false)
		roll_touch_value = 0.0
		get_viewport().set_input_as_handled()


func _update_vector(screen_position: Vector2) -> void:
	var center := _screen_position(vector_root)
	var delta := (screen_position - center) / drag_radius_pixels
	delta = delta.limit_length(1.0)
	var value := Vector2(delta.x, -delta.y)
	ship.set_touch_vector(value)
	vector_knob.position = Vector3(value.x * 0.28, value.y * 0.28, -0.055)


func _update_attitude(screen_position: Vector2) -> void:
	var center := _screen_position(attitude_root)
	var delta := ((screen_position - center) / drag_radius_pixels).limit_length(1.0)
	ship.set_touch_attitude(delta)
	attitude_knob.position = Vector3(delta.x * 0.27, -delta.y * 0.27, -0.06)
	attitude_root.rotation_degrees.z = delta.x * 8.0


func _update_vertical(screen_position: Vector2) -> void:
	var center := _screen_position(vertical_root)
	var value := clampf(-(screen_position.y - center.y) / (drag_radius_pixels * 0.75), -1.0, 1.0)
	ship.set_touch_vertical(value)
	vertical_knob.position.y = value * 0.26


func _hit(control: Node3D, screen_position: Vector2, radius: float) -> bool:
	if control == null or camera == null or camera.is_position_behind(control.global_position):
		return false
	return screen_position.distance_to(_screen_position(control)) <= radius


func _screen_position(control: Node3D) -> Vector2:
	return camera.unproject_position(control.global_position)


func _build_materials() -> void:
	dark_material = _material(Color(0.025, 0.045, 0.055), 0.78, 0.35)
	metal_material = _material(Color(0.14, 0.19, 0.21), 0.52, 0.72)
	cyan_dim_material = _emissive_material(Color(0.05, 0.35, 0.42), 1.2)
	cyan_material = _emissive_material(Color(0.18, 0.88, 1.0), 3.0)
	amber_material = _emissive_material(Color(1.0, 0.48, 0.08), 2.7)
	red_material = _emissive_material(Color(1.0, 0.12, 0.06), 3.2)


func _build_hardware() -> void:
	vector_root = Node3D.new()
	vector_root.name = "VectorControl"
	vector_root.position = Vector3(-1.26, -0.52, -2.32)
	add_child(vector_root)
	_add_plate(vector_root, Vector3(0.82, 0.82, 0.08), dark_material)
	_add_ring(vector_root, 0.31, cyan_dim_material)
	_add_cross(vector_root, 0.29)
	vector_knob = _sphere(vector_root, 0.105, cyan_material)
	vector_knob.position.z = -0.055
	_add_label(vector_root, "VECTOR", Vector3(0.0, 0.50, 0.0), 36, Color(0.45, 0.92, 1.0))

	attitude_root = Node3D.new()
	attitude_root.name = "AttitudeControl"
	attitude_root.position = Vector3(1.26, -0.52, -2.32)
	add_child(attitude_root)
	_add_plate(attitude_root, Vector3(0.82, 0.82, 0.08), dark_material)
	_add_ring(attitude_root, 0.34, cyan_dim_material)
	_add_ring(attitude_root, 0.23, metal_material)
	attitude_knob = _sphere(attitude_root, 0.10, cyan_material)
	attitude_knob.position.z = -0.06
	_add_label(attitude_root, "ATTITUDE", Vector3(0.0, 0.50, 0.0), 34, Color(0.45, 0.92, 1.0))

	vertical_root = Node3D.new()
	vertical_root.name = "RCSVertical"
	vertical_root.position = Vector3(-1.78, 0.02, -2.42)
	add_child(vertical_root)
	_add_plate(vertical_root, Vector3(0.22, 0.72, 0.07), dark_material)
	vertical_knob = _box(vertical_root, Vector3(0.18, 0.14, 0.09), amber_material)
	vertical_knob.position.z = -0.055
	_add_label(vertical_root, "RCS", Vector3(0.0, 0.47, 0.0), 28, Color(1.0, 0.64, 0.28))

	roll_left = _hardware_button(Vector3(-0.48, -0.88, -2.18), "ROLL ◀", amber_material)
	roll_right = _hardware_button(Vector3(0.48, -0.88, -2.18), "ROLL ▶", amber_material)

	mode_switch = _hardware_button(Vector3(-0.50, -0.20, -2.42), "MODE", cyan_dim_material)
	lock_switch = _hardware_button(Vector3(0.0, -0.20, -2.42), "LOCK", amber_material)
	scan_button = _hardware_button(Vector3(0.50, -0.20, -2.42), "SCAN", cyan_material)


func _hardware_button(local_position: Vector3, label_text: String, material: Material) -> MeshInstance3D:
	var root := Node3D.new()
	root.position = local_position
	add_child(root)
	_add_plate(root, Vector3(0.38, 0.24, 0.07), dark_material)
	var button := _box(root, Vector3(0.24, 0.13, 0.09), material)
	button.position.z = -0.055
	button.set_meta("rest_z", button.position.z)
	_add_label(root, label_text, Vector3(0.0, 0.20, 0.0), 25, Color(0.72, 0.92, 0.96))
	return button


func _add_plate(parent: Node3D, size: Vector3, material: Material) -> MeshInstance3D:
	return _box(parent, size, material)


func _add_ring(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.018
	mesh.outer_radius = radius + 0.018
	mesh.rings = 32
	mesh.ring_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation_degrees.x = 90.0
	instance.position.z = -0.055
	parent.add_child(instance)
	return instance


func _add_cross(parent: Node3D, radius: float) -> void:
	var horizontal := _box(parent, Vector3(radius * 1.7, 0.012, 0.018), cyan_dim_material)
	horizontal.position.z = -0.06
	var vertical := _box(parent, Vector3(0.012, radius * 1.7, 0.018), cyan_dim_material)
	vertical.position.z = -0.06


func _box(parent: Node3D, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_label(parent: Node3D, text_value: String, local_position: Vector3, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = local_position
	label.position.z = -0.065
	label.font_size = font_size
	label.pixel_size = 0.0017
	label.modulate = color
	label.outline_size = 4
	label.no_depth_test = true
	parent.add_child(label)
	return label


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color * 0.45, 0.38, 0.18)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _set_pressed(button: MeshInstance3D, pressed: bool) -> void:
	if button == null:
		return
	var rest_z := float(button.get_meta("rest_z", button.position.z))
	button.position.z = rest_z + (0.045 if pressed else 0.0)


func _pulse_control(button: MeshInstance3D) -> void:
	if button == null:
		return
	var rest_z := float(button.get_meta("rest_z", button.position.z))
	var tween := create_tween()
	tween.tween_property(button, "position:z", rest_z + 0.055, 0.055)
	tween.tween_property(button, "position:z", rest_z, 0.10)


func _animate_knob_home(knob: MeshInstance3D) -> void:
	if knob == null:
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(knob, "position:x", 0.0, 0.12)
	tween.parallel().tween_property(knob, "position:y", 0.0, 0.12)
	if knob == attitude_knob:
		tween.parallel().tween_property(attitude_root, "rotation_degrees:z", 0.0, 0.12)


func _animate_slider_home() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vertical_knob, "position:y", 0.0, 0.10)


func _on_mode_changed(_mode_name: String) -> void:
	if mode_switch == null or ship == null:
		return
	mode_switch.rotation_degrees.z = [-18.0, 0.0, 18.0][ship.flight_mode]


func _on_lock_changed(enabled: bool) -> void:
	if lock_switch == null:
		return
	lock_switch.rotation_degrees.z = 16.0 if enabled else -16.0
	lock_switch.material_override = cyan_material if enabled else amber_material


func _haptic(duration_ms: int) -> void:
	if OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(duration_ms)
