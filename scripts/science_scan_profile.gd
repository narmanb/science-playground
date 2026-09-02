extends Node
class_name ScienceScanProfile

const SYSTEM_MANIFEST_PATH := "res://data/asterion_system.json"

@export var ship_path: NodePath
@export var spectral_clearance_radii := 12.0
@export var proximity_clearance_radii := 5.0

var ship: ShipController
var profiled_targets: Array[Dictionary] = []


func _ready() -> void:
	ship = get_node(ship_path) as ShipController
	_bind_profiles.call_deferred()


func _process(_delta: float) -> void:
	if ship == null:
		return
	for entry in profiled_targets:
		var target: Node3D = entry["target"]
		if not is_instance_valid(target):
			continue
		var radius := _body_radius(target)
		if radius <= 0.0:
			continue
		var clearance := maxf(ship.global_position.distance_to(target.global_position) - radius, 0.0)
		var clearance_radii := clearance / radius
		var tier := 0
		if clearance_radii <= proximity_clearance_radii:
			tier = 2
		elif clearance_radii <= spectral_clearance_radii:
			tier = 1
		if int(target.get_meta("scan_profile_tier", -1)) != tier:
			target.set_meta("scan_profile_tier", tier)
			target.set_meta("scan_note", _note_for_tier(entry["data"], String(entry["fallback_note"]), tier))


func _bind_profiles() -> void:
	# Wait until procedural generation, scan registration, collision radii, and
	# manifest-driven rotation metadata have all had time to bind.
	for _frame in 5:
		await get_tree().process_frame

	var manifest := _load_manifest()
	if manifest.is_empty():
		push_warning("Science scan profile could not load the system manifest.")
		return

	var body_data_by_name: Dictionary = {}
	for body_value in manifest.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY:
			var body_data: Dictionary = body_value
			body_data_by_name[String(body_data.get("name", "")).to_upper()] = body_data

	profiled_targets.clear()
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is Node3D:
			continue
		var target := candidate as Node3D
		var scan_name := str(target.get_meta("scan_name", target.name)).to_upper()
		if not body_data_by_name.has(scan_name):
			continue
		var body_data: Dictionary = body_data_by_name[scan_name]
		# Bodies without orbital-range metadata, such as the prototype moon Thale,
		# currently have only one meaningful scan result. Do not pretend they have
		# three science tiers until the manifest contains data to support them.
		if not body_data.has("semimajor_axis_au"):
			continue
		profiled_targets.append({
			"target": target,
			"data": body_data,
			"fallback_note": str(target.get_meta("scan_note", "No additional data.")),
		})
		target.set_meta("scan_profile_tier", -1)
		target.set_meta("scan_profile_max_tier", 2)

	if profiled_targets.is_empty():
		push_warning("Science scan profile did not find any manifest-backed scan targets.")


func _note_for_tier(data: Dictionary, fallback_note: String, tier: int) -> String:
	if not data.has("semimajor_axis_au"):
		return fallback_note

	var remote := "[REMOTE SURVEY] Mass %.2f Earth | Radius %.2f Earth | Gravity %.3f g | Orbit %.1f d | Teq %.1f K" % [
		float(data.get("mass_earth", 0.0)),
		float(data.get("radius_earth", 0.0)),
		float(data.get("surface_gravity_g", 0.0)),
		float(data.get("orbital_period_days", 0.0)),
		float(data.get("equilibrium_temperature_k", 0.0)),
	]
	if tier == 0:
		return remote + " | Approach for spectral detail"

	var details: Array[String] = []
	if data.has("rotation_period_hours"):
		details.append("Rotation %.1f h" % float(data.get("rotation_period_hours", 0.0)))
	var atmosphere: Dictionary = data.get("atmosphere", {})
	var atmosphere_text := _atmosphere_text(atmosphere)
	if not atmosphere_text.is_empty():
		details.append(atmosphere_text)

	var spectral := "[SPECTRAL PASS] " + remote.trim_prefix("[REMOTE SURVEY] ")
	if not details.is_empty():
		spectral += " | " + " | ".join(details)
	if tier == 1:
		return spectral + " | Close approach for local detail"

	var close_details: Array[String] = []
	if atmosphere.has("surface_pressure_bar"):
		close_details.append("Pressure %.2f bar" % float(atmosphere.get("surface_pressure_bar", 0.0)))
	var rings: Dictionary = data.get("rings", {})
	if bool(rings.get("present", false)):
		close_details.append("Ring system resolved")
	var science_status := String(data.get("science_status", ""))
	if not science_status.is_empty():
		close_details.append("Model status: " + science_status.replace("_", " "))

	var proximity := "[PROXIMITY PASS] " + spectral.trim_prefix("[SPECTRAL PASS] ")
	if not close_details.is_empty():
		proximity += " | " + " | ".join(close_details)
	return proximity


func _atmosphere_text(atmosphere: Dictionary) -> String:
	if atmosphere.is_empty():
		return ""
	if atmosphere.has("composition_hint"):
		return "ATM model: " + String(atmosphere.get("composition_hint", ""))
	var composition: Dictionary = atmosphere.get("composition", {})
	if composition.is_empty():
		return ""
	var pieces: Array[String] = []
	for key in composition.keys():
		pieces.append("%s %.0f%%" % [String(key), float(composition[key]) * 100.0])
	return "ATM model: " + ", ".join(pieces)


func _body_radius(body: Node3D) -> float:
	if body.has_meta("collision_radius"):
		return float(body.get_meta("collision_radius"))
	if body is MeshInstance3D:
		var sphere := (body as MeshInstance3D).mesh as SphereMesh
		if sphere != null:
			return sphere.radius
	return 0.0


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(SYSTEM_MANIFEST_PATH):
		return {}
	var file := FileAccess.open(SYSTEM_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
