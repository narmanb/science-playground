extends Node
class_name WorldRotationController

const SYSTEM_MANIFEST_PATH := "res://data/asterion_system.json"

# A 24-hour physical rotation is compressed to this many real seconds. The
# simulation preserves relative spin rates from the manifest while keeping
# planetary rotation visible during an ordinary play session.
@export var reference_day_seconds := 48.0

var rotators: Array[Dictionary] = []


func _ready() -> void:
	_bind_rotators.call_deferred()


func _process(delta: float) -> void:
	for entry in rotators:
		var body: Node3D = entry["body"]
		if is_instance_valid(body):
			body.rotate_y(float(entry["speed_rad_s"]) * delta)


func _bind_rotators() -> void:
	# ProceduralSystem and ScanRegistry both populate dynamically, so allow them
	# to settle before resolving manifest bodies by their scan names.
	for _frame in 3:
		await get_tree().process_frame

	var manifest := _load_manifest()
	if manifest.is_empty():
		push_warning("World rotation controller could not load the system manifest.")
		return

	var periods: Dictionary = {}
	for body_value in manifest.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		if not body.has("rotation_period_hours"):
			continue
		var period_hours := float(body.get("rotation_period_hours", 0.0))
		if period_hours <= 0.0:
			continue
		periods[String(body.get("name", "")).to_upper()] = period_hours

	rotators.clear()
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is Node3D:
			continue
		var node := candidate as Node3D
		var scan_name := str(node.get_meta("scan_name", node.name)).to_upper()
		if not periods.has(scan_name):
			continue
		var period_hours: float = periods[scan_name]
		var visual_period_seconds := maxf(reference_day_seconds * period_hours / 24.0, 0.1)
		var speed_rad_s := TAU / visual_period_seconds
		rotators.append({
			"body": node,
			"period_hours": period_hours,
			"speed_rad_s": speed_rad_s,
		})
		node.set_meta("rotation_period_hours", period_hours)
		_append_rotation_scan_data(node, period_hours)

	if rotators.is_empty():
		push_warning("World rotation controller found no manifest-driven rotating bodies.")


func bound_body_count() -> int:
	return rotators.size()


func _append_rotation_scan_data(body: Node3D, period_hours: float) -> void:
	var note := str(body.get_meta("scan_note", ""))
	if note.contains("Rotation"):
		return
	var suffix := "Rotation %.1f h" % period_hours
	body.set_meta("scan_note", suffix if note.is_empty() else note + " | " + suffix)


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(SYSTEM_MANIFEST_PATH):
		return {}
	var file := FileAccess.open(SYSTEM_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
