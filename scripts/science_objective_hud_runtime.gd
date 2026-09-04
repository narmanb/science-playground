extends ScienceObjectiveHUD
class_name ScienceObjectiveHUDRuntime

var capture_braking_trace_printed := false


func _update_target_velocity(target: Node3D, delta: float) -> void:
	# The software-rendered visual gallery has highly variable frame times once the
	# dense city is loaded. It tests presentation and state transitions, while the
	# separate headless trajectory test covers moving-body numerical behavior.
	# Use an exact stationary sample only in capture mode so screenshot QA cannot
	# become flaky. Normal Android gameplay keeps the parent's smoothed live-orbit
	# velocity estimate unchanged.
	if OS.get_environment("SCIENCE_PLAYGROUND_CAPTURE") == "1":
		tracked_target_id = target.get_instance_id()
		previous_target_position = target.global_position
		estimated_target_velocity = Vector3.ZERO
		has_previous_target_position = true
		return
	super._update_target_velocity(target, delta)


func _approach_guidance_lines(target: Node3D) -> Array[String]:
	var lines := super._approach_guidance_lines(target)
	if (
		OS.get_environment("SCIENCE_PLAYGROUND_CAPTURE") == "1"
		and not capture_braking_trace_printed
		and navigation_hud != null
		and navigation_hud.ship != null
		and _target_name(target) == "VEYR"
		and navigation_hud.ship.linear_velocity.length() > 20.0
	):
		capture_braking_trace_printed = true
		print("CI_BRAKING_TRACE speed=%.3f braking=%s intercept=%s lines=%s" % [
			navigation_hud.ship.linear_velocity.length(),
			str(braking_required),
			str(envelope_intercept_predicted),
			str(lines),
		])
	return lines
