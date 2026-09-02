extends RigidBody3D
class_name ShipController

signal flight_mode_changed(mode_name: String)
signal inertial_lock_changed(enabled: bool)
signal scan_requested

const MODE_CRUISE := 0
const MODE_VECTOR := 1
const MODE_DRIFT := 2
const MODE_NAMES := ["CRUISE", "VECTOR", "DRIFT"]

@export var main_thrust_force := 52.0
@export var strafe_thrust_force := 34.0
@export var vertical_thrust_force := 34.0
@export var attitude_torque := 7.5
@export var roll_torque := 6.0
@export var rcs_impulse := 2.8
@export var rcs_repeat_delay := 0.16
@export var inertial_lock_strength := 4.0

var flight_mode := MODE_VECTOR
var inertial_lock := false
var locked_velocity := Vector3.ZERO

var touch_vector := Vector2.ZERO
var touch_attitude := Vector2.ZERO
var touch_roll := 0.0
var touch_vertical := 0.0

var _rcs_cooldown := 0.0


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_apply_mode_damping()
	continuous_cd = true


func _physics_process(delta: float) -> void:
	_rcs_cooldown = maxf(0.0, _rcs_cooldown - delta)
	var vector_input := _read_vector_input()
	var attitude_input := _read_attitude_input()
	var roll_input := _read_roll_input()
	var vertical_input := _read_vertical_input()

	var local_force := Vector3(
		vector_input.x * strafe_thrust_force,
		vertical_input * vertical_thrust_force,
		-vector_input.y * main_thrust_force
	)

	if flight_mode == MODE_CRUISE:
		local_force.z *= 1.35
	elif flight_mode == MODE_DRIFT:
		local_force *= 0.85

	var world_force := global_basis * local_force
	apply_central_force(world_force)

	if inertial_lock:
		# The lock preserves a world-space velocity vector while attitude remains free.
		# Pilot translation commands intentionally move the held vector rather than
		# fighting the lock.
		if mass > 0.0:
			locked_velocity += (world_force / mass) * delta
		var correction := (locked_velocity - linear_velocity) * mass * inertial_lock_strength
		apply_central_force(correction)

	var local_torque := Vector3(
		-attitude_input.y * attitude_torque,
		-attitude_input.x * attitude_torque,
		-roll_input * roll_torque
	)
	apply_torque(global_basis * local_torque)

	_handle_rcs_bursts()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_RIGHT_SHOULDER:
				toggle_inertial_lock()
			JOY_BUTTON_Y:
				cycle_flight_mode()
			JOY_BUTTON_X:
				request_scan()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L:
				toggle_inertial_lock()
			KEY_M:
				cycle_flight_mode()
			KEY_X:
				request_scan()


func _read_vector_input() -> Vector2:
	var result := touch_vector
	if Input.get_connected_joypads().size() > 0:
		result.x += _deadzone(Input.get_joy_axis(0, JOY_AXIS_LEFT_X))
		result.y += -_deadzone(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))

	if Input.is_key_pressed(KEY_A):
		result.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		result.x += 1.0
	if Input.is_key_pressed(KEY_W):
		result.y += 1.0
	if Input.is_key_pressed(KEY_S):
		result.y -= 1.0
	return result.limit_length(1.0)


func _read_attitude_input() -> Vector2:
	var result := touch_attitude
	if Input.get_connected_joypads().size() > 0:
		result.x += _deadzone(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X))
		result.y += _deadzone(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))

	if Input.is_key_pressed(KEY_LEFT):
		result.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		result.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		result.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		result.y += 1.0
	return result.limit_length(1.0)


func _read_roll_input() -> float:
	var value := touch_roll
	if Input.get_connected_joypads().size() > 0:
		var left_trigger := _trigger_value(Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT))
		var right_trigger := _trigger_value(Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT))
		value += right_trigger - left_trigger
	if Input.is_key_pressed(KEY_Q):
		value -= 1.0
	if Input.is_key_pressed(KEY_E):
		value += 1.0
	return clampf(value, -1.0, 1.0)


func _read_vertical_input() -> float:
	var value := touch_vertical
	if Input.is_key_pressed(KEY_R):
		value += 1.0
	if Input.is_key_pressed(KEY_F):
		value -= 1.0
	return clampf(value, -1.0, 1.0)


func _handle_rcs_bursts() -> void:
	if _rcs_cooldown > 0.0 or Input.get_connected_joypads().is_empty():
		return

	var local_impulse := Vector3.ZERO
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		local_impulse.x -= rcs_impulse
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		local_impulse.x += rcs_impulse
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		local_impulse.y += rcs_impulse
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		local_impulse.y -= rcs_impulse

	if local_impulse != Vector3.ZERO:
		var world_impulse := global_basis * local_impulse
		apply_central_impulse(world_impulse)
		if inertial_lock and mass > 0.0:
			locked_velocity += world_impulse / mass
		_rcs_cooldown = rcs_repeat_delay


func cycle_flight_mode() -> void:
	flight_mode = (flight_mode + 1) % MODE_NAMES.size()
	_apply_mode_damping()
	flight_mode_changed.emit(MODE_NAMES[flight_mode])


func toggle_inertial_lock() -> void:
	inertial_lock = not inertial_lock
	if inertial_lock:
		locked_velocity = linear_velocity
	_apply_mode_damping()
	inertial_lock_changed.emit(inertial_lock)


func request_scan() -> void:
	scan_requested.emit()


func set_touch_vector(value: Vector2) -> void:
	touch_vector = value.limit_length(1.0)


func set_touch_attitude(value: Vector2) -> void:
	touch_attitude = value.limit_length(1.0)


func set_touch_roll(value: float) -> void:
	touch_roll = clampf(value, -1.0, 1.0)


func set_touch_vertical(value: float) -> void:
	touch_vertical = clampf(value, -1.0, 1.0)


func _apply_mode_damping() -> void:
	if inertial_lock:
		linear_damp = 0.0
	else:
		match flight_mode:
			MODE_CRUISE:
				linear_damp = 0.72
			MODE_VECTOR:
				linear_damp = 0.08
			MODE_DRIFT:
				linear_damp = 0.0

	match flight_mode:
		MODE_CRUISE:
			angular_damp = 1.8
		MODE_VECTOR:
			angular_damp = 0.95
		MODE_DRIFT:
			angular_damp = 0.28


func _deadzone(value: float, zone := 0.16) -> float:
	if absf(value) < zone:
		return 0.0
	return signf(value) * inverse_lerp(zone, 1.0, absf(value))


func _trigger_value(value: float) -> float:
	# Godot controller mappings commonly expose triggers as -1..1.
	# This also behaves acceptably on devices that report a narrower range.
	if value <= -0.95:
		return 0.0
	return clampf((value + 1.0) * 0.5, 0.0, 1.0)
