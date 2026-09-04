extends ScienceObjectiveHUD
class_name ScienceObjectiveHUDRuntime


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
