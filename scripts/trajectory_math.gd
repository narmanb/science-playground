extends RefCounted
class_name TrajectoryMath


static func closest_approach(relative_position: Vector3, relative_velocity: Vector3, radius: float) -> Dictionary:
	var speed_squared := relative_velocity.length_squared()
	if speed_squared < 0.0001:
		return {
			"time": 0.0,
			"clearance": relative_position.length() - radius,
			"future": false,
		}

	var raw_time := -relative_position.dot(relative_velocity) / speed_squared
	var future := raw_time > 0.0
	var time_to_cpa := maxf(raw_time, 0.0)
	var predicted_position := relative_position + relative_velocity * time_to_cpa
	return {
		"time": time_to_cpa,
		"clearance": predicted_position.length() - radius,
		"future": future,
	}


static func sphere_entry(relative_position: Vector3, relative_velocity: Vector3, radius: float) -> Dictionary:
	# Solve |r + vt|^2 = R^2 for the earliest non-negative time. This is an exact
	# line/sphere intersection under the same constant-relative-velocity model as
	# closest_approach(), so it is suitable for both collision and science-zone
	# entry prediction without assuming a purely radial trajectory.
	if radius <= 0.0:
		return {"intersects": false, "time": 0.0, "inside": false}

	var c := relative_position.length_squared() - radius * radius
	if c <= 0.0:
		return {"intersects": true, "time": 0.0, "inside": true}

	var a := relative_velocity.length_squared()
	if a < 0.0001:
		return {"intersects": false, "time": 0.0, "inside": false}

	var b := 2.0 * relative_position.dot(relative_velocity)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return {"intersects": false, "time": 0.0, "inside": false}

	var root := sqrt(maxf(discriminant, 0.0))
	var denominator := 2.0 * a
	var entry_time := (-b - root) / denominator
	var exit_time := (-b + root) / denominator
	if exit_time < 0.0:
		return {"intersects": false, "time": 0.0, "inside": false}

	return {
		"intersects": entry_time >= 0.0,
		"time": maxf(entry_time, 0.0),
		"exit_time": maxf(exit_time, 0.0),
		"inside": false,
	}


static func collision_cone_escape(
	relative_position: Vector3,
	relative_velocity: Vector3,
	radius: float,
	preferred_side: Vector3 = Vector3.ZERO
) -> Dictionary:
	# Under constant relative velocity, the body subtends a collision cone whose
	# half-angle is asin(radius / range). If the current velocity vector lies
	# inside that cone, the minimum instantaneous delta-v that reaches a tangent
	# trajectory is the perpendicular distance from the velocity vector to the
	# nearest cone-boundary ray.
	var range_to_center := relative_position.length()
	if radius <= 0.0 or range_to_center <= radius or range_to_center <= 0.0001:
		return {}

	var speed := relative_velocity.length()
	if speed <= 0.0001:
		return {}

	var toward_body := -relative_position / range_to_center
	var velocity_direction := relative_velocity / speed
	var axial_dot := clampf(toward_body.dot(velocity_direction), -1.0, 1.0)
	var approach_angle := acos(axial_dot)
	var cone_half_angle := asin(clampf(radius / range_to_center, 0.0, 1.0))
	if approach_angle >= cone_half_angle:
		return {}

	# For an off-axis intercept, the current velocity already identifies the
	# nearest side of the tangent cone. A mathematically exact centerline hit has
	# infinitely many equally short escape directions, so callers may supply a
	# preferred side (the cockpit uses ship-right) to keep the guidance stable.
	var lateral := velocity_direction - toward_body * axial_dot
	var side := Vector3.ZERO
	if lateral.length_squared() > 0.000001:
		side = lateral.normalized()
	else:
		var preferred_lateral := preferred_side - toward_body * preferred_side.dot(toward_body)
		if preferred_lateral.length_squared() > 0.000001:
			side = preferred_lateral.normalized()
		else:
			var fallback := Vector3.UP if absf(toward_body.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			side = (fallback - toward_body * fallback.dot(toward_body)).normalized()

	var deflection := cone_half_angle - approach_angle
	var tangent_direction := (toward_body * cos(cone_half_angle) + side * sin(cone_half_angle)).normalized()
	var tangent_speed := maxf(relative_velocity.dot(tangent_direction), 0.0)
	var tangent_velocity := tangent_direction * tangent_speed
	var delta_v_vector := tangent_velocity - relative_velocity

	return {
		"delta_v": delta_v_vector.length(),
		"delta_v_vector": delta_v_vector,
		"deflection_deg": rad_to_deg(deflection),
		"cone_half_angle_deg": rad_to_deg(cone_half_angle),
		"approach_angle_deg": rad_to_deg(approach_angle),
	}
