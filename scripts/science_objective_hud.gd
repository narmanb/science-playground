extends Control
class_name ScienceObjectiveHUD

@export var navigation_hud_path: NodePath
@export var science_log_hud_path: NodePath
@export var flight_hud_path: NodePath

const OBJECTIVE_COLOR := Color(0.72, 0.92, 0.82, 0.92)
const APPROACH_COLOR := Color(0.80, 0.94, 0.84, 0.94)
const OPENING_COLOR := Color(1.0, 0.73, 0.36, 0.96)
const BRAKE_COLOR := Color(1.0, 0.42, 0.30, 0.98)

var navigation_hud: NavigationHUD
var science_log: ScienceLogHUD
var flight_hud: FlightHUD
var objective_label: Label

var tracked_target_id := 0
var previous_target_position := Vector3.ZERO
var estimated_target_velocity := Vector3.ZERO
var has_previous_target_position := false
var braking_required := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_hud = get_node(navigation_hud_path) as NavigationHUD
	science_log = get_node(science_log_hud_path) as ScienceLogHUD
	flight_hud = get_node(flight_hud_path) as FlightHUD

	objective_label = Label.new()
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.add_theme_color_override("font_color", OBJECTIVE_COLOR)
	add_child(objective_label)
	_layout_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()


func _process(delta: float) -> void:
	if navigation_hud == null or science_log == null or flight_hud == null:
		objective_label.visible = false
		return

	# Scanner feedback and the catalog each own the pilot's attention while open.
	# Suppressing this line in either state keeps the cockpit from stacking text.
	if flight_hud.scan_target != null or (science_log.log_panel != null and science_log.log_panel.visible):
		objective_label.visible = false
		return

	var target := navigation_hud.current_target()
	if target == null or not is_instance_valid(target):
		objective_label.visible = false
		_reset_target_tracking()
		return

	_update_target_velocity(target, delta)
	braking_required = false
	var objective := _objective_for(target)
	var approach_lines := _approach_guidance_lines(target)
	var lines: Array[String] = [objective]
	lines.append_array(approach_lines)
	objective_label.text = "\n".join(lines)
	objective_label.add_theme_color_override("font_color", BRAKE_COLOR if braking_required else _guidance_color(target))
	objective_label.visible = true


func _objective_for(target: Node3D) -> String:
	var body_name := _target_name(target)
	var achieved := int(science_log.discoveries.get(body_name, -1))
	var max_tier := int(target.get_meta("scan_profile_max_tier", 0))

	if max_tier <= 0:
		if achieved >= 0:
			return "SCIENCE %s   •   SURVEY COMPLETE   •   TAP NAV FOR NEXT SCIENCE" % body_name
		return "SCIENCE %s   •   SURVEY READY   •   CENTER TARGET + SCAN" % body_name

	if achieved >= max_tier:
		return "SCIENCE %s   •   FULL SURVEY COMPLETE   •   TAP NAV FOR NEXT SCIENCE" % body_name

	var current_zone := clampi(int(target.get_meta("scan_profile_tier", 0)), 0, max_tier)
	var zone_name := _tier_name(current_zone)

	# A close first encounter can legitimately produce a deeper scan immediately;
	# the catalog records the best completed tier, so no artificial prerequisite
	# forces the pilot to back away and repeat lower-resolution surveys.
	if current_zone > achieved:
		return "SCIENCE %s   •   ZONE %s   •   %s PASS READY — CENTER + SCAN" % [
			body_name,
			zone_name,
			zone_name,
		]

	var next_tier := clampi(achieved + 1, 0, max_tier)
	return "SCIENCE %s   •   ZONE %s   •   APPROACH FOR %s PASS" % [
		body_name,
		zone_name,
		_tier_name(next_tier),
	]


func _approach_guidance_lines(target: Node3D) -> Array[String]:
	var lines: Array[String] = []
	var max_tier := int(target.get_meta("scan_profile_max_tier", 0))
	if max_tier <= 0:
		return lines

	var achieved := int(science_log.discoveries.get(_target_name(target), -1))
	if achieved >= max_tier:
		return lines

	var current_zone := clampi(int(target.get_meta("scan_profile_tier", 0)), 0, max_tier)
	if current_zone > achieved:
		return lines

	var next_tier := clampi(achieved + 1, 0, max_tier)
	if next_tier <= 0:
		return lines

	var required_radii := _envelope_radii(target, next_tier)
	var radius := _body_radius(target)
	if required_radii <= 0.0 or radius <= 0.0 or navigation_hud.ship == null:
		return lines

	var ship := navigation_hud.ship
	var center_distance := ship.global_position.distance_to(target.global_position)
	var clearance := maxf(center_distance - radius, 0.0)
	var clearance_radii := clearance / radius
	var to_target := target.global_position - ship.global_position
	var closing_speed := 0.0
	var main_axis_alignment := 0.0
	if to_target.length_squared() > 0.0001:
		var target_direction := to_target.normalized()
		var relative_velocity := ship.linear_velocity - estimated_target_velocity
		closing_speed = relative_velocity.dot(target_direction)
		# Main thrust is bidirectional along local +/-Z, so absolute alignment is
		# the exact fraction of fore/aft thrust currently available radially without
		# first changing attitude.
		main_axis_alignment = absf(ship.global_basis.z.dot(target_direction))

	var motion_text := "RADIAL HOLD"
	if closing_speed > 0.20:
		motion_text = "CLOSING %.1f u/s" % closing_speed
	elif closing_speed < -0.20:
		motion_text = "OPENING %.1f u/s" % absf(closing_speed)

	var envelope_distance := maxf(clearance - required_radii * radius, 0.0)
	var eta_text := ""
	if closing_speed > 0.20 and envelope_distance > 0.0:
		eta_text = "   •   ETA %.0fs" % (envelope_distance / closing_speed)

	lines.append("ENVELOPE ≤%.1f R   •   NOW %.1f R   •   %s%s" % [
		required_radii,
		clearance_radii,
		motion_text,
		eta_text,
	])

	if closing_speed > 0.20 and envelope_distance > 0.0:
		var aligned_acceleration := _main_thrust_acceleration(ship) * main_axis_alignment
		var alignment_percent := int(round(main_axis_alignment * 100.0))
		if aligned_acceleration <= 0.001:
			lines.append("MAIN AXIS %d%%   •   ROTATE FOR RADIAL MAIN-THRUST BRAKING" % alignment_percent)
		else:
			# This is intentionally a thrust-only stopping estimate. Cruise/Vector
			# damping may help in practice, but the science instrument does not count
			# passive damping as guaranteed braking authority.
			var stopping_distance := closing_speed * closing_speed / (2.0 * aligned_acceleration)
			var braking_margin := envelope_distance - stopping_distance
			if braking_margin <= 0.0:
				braking_required = true
				lines.append("BRAKE / ALIGN NOW   •   MAIN AXIS %d%%   •   STOP ≈%.1f u   •   ENVELOPE IN %.1f u" % [
					alignment_percent,
					stopping_distance,
					envelope_distance,
				])
			else:
				lines.append("MAIN AXIS %d%%   •   THRUST STOP ≈%.1f u   •   BRAKE MARGIN %.1f u" % [
					alignment_percent,
					stopping_distance,
					braking_margin,
				])

	return lines


func _main_thrust_acceleration(ship: ShipController) -> float:
	if ship.mass <= 0.0:
		return 0.0
	var mode_multiplier := 1.0
	match ship.flight_mode:
		ShipController.MODE_CRUISE:
			mode_multiplier = 1.35
		ShipController.MODE_DRIFT:
			mode_multiplier = 0.85
		_:
			mode_multiplier = 1.0
	return ship.main_thrust_force * mode_multiplier / ship.mass


func _guidance_color(target: Node3D) -> Color:
	var max_tier := int(target.get_meta("scan_profile_max_tier", 0))
	if max_tier <= 0:
		return OBJECTIVE_COLOR
	var achieved := int(science_log.discoveries.get(_target_name(target), -1))
	if achieved >= max_tier:
		return OBJECTIVE_COLOR
	var current_zone := clampi(int(target.get_meta("scan_profile_tier", 0)), 0, max_tier)
	if current_zone > achieved:
		return OBJECTIVE_COLOR
	var next_tier := clampi(achieved + 1, 0, max_tier)
	if next_tier <= 0 or navigation_hud.ship == null:
		return OBJECTIVE_COLOR
	var to_target := target.global_position - navigation_hud.ship.global_position
	if to_target.length_squared() < 0.0001:
		return APPROACH_COLOR
	var relative_velocity := navigation_hud.ship.linear_velocity - estimated_target_velocity
	var closing_speed := relative_velocity.dot(to_target.normalized())
	return OPENING_COLOR if closing_speed < -0.20 else APPROACH_COLOR


func _envelope_radii(target: Node3D, tier: int) -> float:
	match tier:
		1:
			return float(target.get_meta("scan_profile_spectral_clearance_radii", 0.0))
		2:
			return float(target.get_meta("scan_profile_proximity_clearance_radii", 0.0))
		_:
			return 0.0


func _update_target_velocity(target: Node3D, delta: float) -> void:
	var target_id := target.get_instance_id()
	if tracked_target_id != target_id:
		tracked_target_id = target_id
		previous_target_position = target.global_position
		estimated_target_velocity = Vector3.ZERO
		has_previous_target_position = true
		return
	if not has_previous_target_position or delta <= 0.0001:
		previous_target_position = target.global_position
		has_previous_target_position = true
		return
	var measured_velocity := (target.global_position - previous_target_position) / delta
	estimated_target_velocity = estimated_target_velocity.lerp(measured_velocity, 0.35)
	previous_target_position = target.global_position


func _reset_target_tracking() -> void:
	tracked_target_id = 0
	previous_target_position = Vector3.ZERO
	estimated_target_velocity = Vector3.ZERO
	has_previous_target_position = false


func _body_radius(body: Node3D) -> float:
	if body.has_meta("collision_radius"):
		return float(body.get_meta("collision_radius"))
	if body is MeshInstance3D:
		var sphere := (body as MeshInstance3D).mesh as SphereMesh
		if sphere != null:
			return sphere.radius
	return 0.0


func _tier_name(tier: int) -> String:
	match tier:
		0:
			return "REMOTE"
		1:
			return "SPECTRAL"
		_:
			return "PROXIMITY"


func _target_name(target: Node3D) -> String:
	return str(target.get_meta("scan_name", target.name)).to_upper()


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	objective_label.position = Vector2(size.x * 0.17, 116.0)
	objective_label.size = Vector2(size.x * 0.66, 82.0)
