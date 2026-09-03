extends SceneTree

const TrajectoryMathScript = preload("res://scripts/trajectory_math.gd")
const EPS := 0.02


func _init() -> void:
	var direct_position := Vector3(-220.0, 0.0, 0.0)
	var direct_velocity := Vector3(12.0, 0.0, 0.0)
	var radius := 20.0

	var direct_cpa := TrajectoryMathScript.closest_approach(direct_position, direct_velocity, radius)
	_require(bool(direct_cpa["future"]), "Direct intercept must have a future CPA.")
	_require_close(float(direct_cpa["time"]), 220.0 / 12.0, EPS, "Direct-intercept CPA time")
	_require_close(float(direct_cpa["clearance"]), -20.0, EPS, "Direct-intercept predicted clearance")

	var direct_entry := TrajectoryMathScript.sphere_entry(direct_position, direct_velocity, radius)
	_require(bool(direct_entry["intersects"]), "Direct intercept must enter the collision sphere.")
	_require_close(float(direct_entry["time"]), 200.0 / 12.0, EPS, "Direct sphere-entry time")
	_require_close(float(direct_entry["exit_time"]), 240.0 / 12.0, EPS, "Direct sphere-exit time")

	# Centerline impact has infinitely many equally short tangent directions. Give
	# the pure helper a deterministic +Y preference so the returned full delta-v
	# vector can be verified as well as its magnitude.
	var escape := TrajectoryMathScript.collision_cone_escape(
		direct_position,
		direct_velocity,
		radius,
		Vector3.UP
	)
	_require(not escape.is_empty(), "Direct intercept must produce a collision-cone escape solution.")
	var expected_cone_angle := rad_to_deg(asin(radius / 220.0))
	var expected_delta_v := 12.0 * sin(asin(radius / 220.0))
	var escape_vector: Vector3 = escape["delta_v_vector"]
	_require_close(float(escape["delta_v"]), expected_delta_v, EPS, "Minimum tangent escape delta-v")
	_require_close(escape_vector.length(), expected_delta_v, EPS, "Escape-vector magnitude")
	_require_close(float(escape["deflection_deg"]), expected_cone_angle, EPS, "Required centerline deflection angle")
	_require(escape_vector.y > 0.0, "Preferred +Y centerline escape must produce positive lateral Y delta-v.")
	_require(escape_vector.x < 0.0, "Minimum tangent solution must include the small axial deceleration component.")
	_require_close(escape_vector.z, 0.0, EPS, "Preferred +Y escape Z component")

	var flyby_position := Vector3(-220.0, -60.0, 0.0)
	var flyby_cpa := TrajectoryMathScript.closest_approach(flyby_position, direct_velocity, radius)
	_require(bool(flyby_cpa["future"]), "Offset flyby must have a future CPA.")
	_require_close(float(flyby_cpa["time"]), 220.0 / 12.0, EPS, "Flyby CPA time")
	_require_close(float(flyby_cpa["clearance"]), 40.0, EPS, "Flyby predicted clearance")
	_require(
		not bool(TrajectoryMathScript.sphere_entry(flyby_position, direct_velocity, radius)["intersects"]),
		"A trajectory with 40u predicted shell clearance must not enter the 20u collision sphere."
	)
	_require(
		TrajectoryMathScript.collision_cone_escape(flyby_position, direct_velocity, radius).is_empty(),
		"A trajectory with 40u predicted shell clearance must not request collision-cone escape delta-v."
	)

	# The same offset trajectory misses the 20u collision sphere but intersects a
	# wider 80u science envelope. This proves sphere-entry timing is not merely a
	# collision-specific special case.
	var science_radius := 80.0
	var science_entry := TrajectoryMathScript.sphere_entry(flyby_position, direct_velocity, science_radius)
	_require(bool(science_entry["intersects"]), "Offset trajectory must enter the wider science envelope.")
	var science_half_chord := sqrt(science_radius * science_radius - 60.0 * 60.0)
	var expected_science_entry := (220.0 - science_half_chord) / 12.0
	_require_close(float(science_entry["time"]), expected_science_entry, EPS, "Science-envelope entry time")

	print(
		"Trajectory math verified: CPA %.2fs, sphere entry %.2fs, impact clearance %.2fu, min escape Δv %.3fu/s, deflection %.3fdeg, flyby clearance %.2fu, science entry %.2fs" % [
			float(direct_cpa["time"]),
			float(direct_entry["time"]),
			float(direct_cpa["clearance"]),
			float(escape["delta_v"]),
			float(escape["deflection_deg"]),
			float(flyby_cpa["clearance"]),
			float(science_entry["time"]),
		]
	)
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _require_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) <= tolerance:
		return
	push_error("%s expected %.5f, got %.5f" % [label, expected, actual])
	quit(1)
