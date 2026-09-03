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

	var escape := TrajectoryMathScript.collision_cone_escape(direct_position, direct_velocity, radius)
	_require(not escape.is_empty(), "Direct intercept must produce a collision-cone escape solution.")
	var expected_cone_angle := rad_to_deg(asin(radius / 220.0))
	var expected_delta_v := 12.0 * sin(asin(radius / 220.0))
	_require_close(float(escape["delta_v"]), expected_delta_v, EPS, "Minimum tangent escape delta-v")
	_require_close(float(escape["deflection_deg"]), expected_cone_angle, EPS, "Required centerline deflection angle")

	var flyby_position := Vector3(-220.0, -60.0, 0.0)
	var flyby_cpa := TrajectoryMathScript.closest_approach(flyby_position, direct_velocity, radius)
	_require(bool(flyby_cpa["future"]), "Offset flyby must have a future CPA.")
	_require_close(float(flyby_cpa["time"]), 220.0 / 12.0, EPS, "Flyby CPA time")
	_require_close(float(flyby_cpa["clearance"]), 40.0, EPS, "Flyby predicted clearance")
	_require(
		TrajectoryMathScript.collision_cone_escape(flyby_position, direct_velocity, radius).is_empty(),
		"A trajectory with 40u predicted shell clearance must not request collision-cone escape delta-v."
	)

	print(
		"Trajectory math verified: CPA %.2fs, impact clearance %.2fu, min escape Δv %.3fu/s, deflection %.3fdeg, flyby clearance %.2fu" % [
			float(direct_cpa["time"]),
			float(direct_cpa["clearance"]),
			float(escape["delta_v"]),
			float(escape["deflection_deg"]),
			float(flyby_cpa["clearance"]),
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
