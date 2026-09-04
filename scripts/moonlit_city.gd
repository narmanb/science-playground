extends Node3D
class_name MoonlitCity

@export var city_origin := Vector3(310.0, -40.0, 20.0)
@export var city_seed := 20491
@export var traffic_count := 28

var rng := RandomNumberGenerator.new()
var traffic: Array[Dictionary] = []
var building_materials: Array[StandardMaterial3D] = []
var window_material: StandardMaterial3D
var road_glow_material: StandardMaterial3D
var beacon_material: StandardMaterial3D
var ground_material: StandardMaterial3D


func _ready() -> void:
	rng.seed = city_seed
	_build_materials()
	_tune_night_environment()
	_build_ground_and_roads()
	_build_towers()
	_build_bridges()
	_build_moon()
	_build_traffic()


func _process(delta: float) -> void:
	for entry in traffic:
		var vehicle: MeshInstance3D = entry["node"]
		if not is_instance_valid(vehicle):
			continue
		var direction: Vector3 = entry["direction"]
		var speed: float = float(entry["speed"])
		vehicle.position += direction * speed * delta
		var relative: Vector3 = vehicle.position - city_origin
		if direction.z < -0.5 and relative.z < -790.0:
			vehicle.position.z = city_origin.z + 150.0
		elif direction.z > 0.5 and relative.z > 170.0:
			vehicle.position.z = city_origin.z - 780.0
		elif direction.x > 0.5 and relative.x > 560.0:
			vehicle.position.x = city_origin.x - 560.0
		elif direction.x < -0.5 and relative.x < -560.0:
			vehicle.position.x = city_origin.x + 560.0


func _build_materials() -> void:
	ground_material = _material(Color(0.075, 0.095, 0.115), 0.58, 0.25)
	building_materials = [
		_material(Color(0.10, 0.16, 0.19), 0.52, 0.48),
		_material(Color(0.15, 0.13, 0.18), 0.56, 0.38),
		_material(Color(0.09, 0.14, 0.22), 0.48, 0.54),
		_material(Color(0.18, 0.17, 0.15), 0.62, 0.32),
	]
	window_material = _emissive(Color(0.22, 0.82, 1.0), 3.5)
	road_glow_material = _emissive(Color(0.04, 0.65, 0.90), 4.0)
	beacon_material = _emissive(Color(1.0, 0.22, 0.07), 5.0)


func _tune_night_environment() -> void:
	var world_environment := get_node_or_null("../SpaceEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	var environment := world_environment.environment
	# This is intentionally a readable night rather than a black cyberpunk scene.
	environment.background_color = Color(0.025, 0.045, 0.085)
	environment.ambient_light_color = Color(0.28, 0.38, 0.55)
	environment.ambient_light_energy = 0.82
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18, 0.26, 0.38)
	environment.fog_light_energy = 0.72
	environment.fog_density = 0.00115
	environment.fog_sky_affect = 0.42


func _build_ground_and_roads() -> void:
	var ground := _box(
		Vector3(1300.0, 4.0, 1250.0),
		city_origin + Vector3(0.0, -2.0, -330.0),
		ground_material
	)
	ground.name = "CityGround"
	_add_static_box(ground.position, Vector3(1300.0, 4.0, 1250.0), "GroundCollision")

	# Main north/south flight avenue directly ahead of the starting ship.
	_box(Vector3(66.0, 0.8, 1030.0), city_origin + Vector3(0.0, 0.35, -330.0), _material(Color(0.025, 0.035, 0.045), 0.42, 0.20))
	for side in [-1.0, 1.0]:
		_box(Vector3(1.2, 0.15, 1030.0), city_origin + Vector3(side * 25.0, 0.82, -330.0), road_glow_material)

	# Cross-city corridors make lateral translation and drift equally readable.
	for row in [2, 6, 10]:
		var z := city_origin.z - 74.0 * float(row)
		_box(Vector3(1160.0, 0.75, 54.0), Vector3(city_origin.x, city_origin.y + 0.34, z), _material(Color(0.026, 0.037, 0.05), 0.44, 0.18))
		for edge in [-19.0, 19.0]:
			_box(Vector3(1160.0, 0.14, 1.0), Vector3(city_origin.x, city_origin.y + 0.82, z + edge), road_glow_material)


func _build_towers() -> void:
	var spacing_x := 78.0
	var spacing_z := 74.0
	for row in range(0, 12):
		if row in [2, 6, 10]:
			continue
		for column in range(-6, 7):
			# Leave the central avenue open enough for the player to fly and strafe.
			if column == 0:
				continue
			var x := city_origin.x + float(column) * spacing_x
			var z := city_origin.z - float(row) * spacing_z - 80.0
			var width := rng.randf_range(34.0, 58.0)
			var depth := rng.randf_range(34.0, 58.0)
			var height := rng.randf_range(52.0, 165.0)
			if abs(column) == 1 and row % 3 == 0:
				height *= 1.22
			var center_y := city_origin.y + height * 0.5
			var material := building_materials[rng.randi_range(0, building_materials.size() - 1)]
			var tower := _box(Vector3(width, height, depth), Vector3(x, center_y, z), material)
			tower.name = "Tower_%d_%d" % [row, column]
			_add_static_box(tower.position, Vector3(width, height, depth), tower.name + "Collision")

			# Large luminous horizontal bands read as windows from a distance and
			# produce strong optical flow during strafing without thousands of lights.
			var band_count := rng.randi_range(2, 4)
			for band_index in band_count:
				var fraction := float(band_index + 1) / float(band_count + 1)
				var band_y := city_origin.y + height * fraction
				_box(
					Vector3(width * 0.76, 1.5, 0.45),
					Vector3(x, band_y, z + depth * 0.5 + 0.28),
					window_material
				)
				_box(
					Vector3(width * 0.76, 1.5, 0.45),
					Vector3(x, band_y, z - depth * 0.5 - 0.28),
					window_material
				)

			var beacon := _box(Vector3(1.8, 5.5, 1.8), Vector3(x, city_origin.y + height + 3.0, z), beacon_material)
			beacon.name = "Beacon_%d_%d" % [row, column]

	# Four taller landmarks frame the skyline and make roll immediately obvious.
	for landmark_value in [
		Vector3(-360.0, 0.0, -360.0),
		Vector3(360.0, 0.0, -430.0),
		Vector3(-440.0, 0.0, -690.0),
		Vector3(430.0, 0.0, -720.0),
	]:
		var landmark: Vector3 = landmark_value
		var height := 235.0
		var landmark_position: Vector3 = city_origin + landmark
		landmark_position.y = city_origin.y + height * 0.5
		_box(Vector3(42.0, height, 42.0), landmark_position, building_materials[2])
		_box(Vector3(32.0, 3.0, 43.0), Vector3(landmark_position.x, city_origin.y + height * 0.72, landmark_position.z + 21.6), window_material)
		_box(Vector3(3.0, 16.0, 3.0), Vector3(landmark_position.x, city_origin.y + height + 8.0, landmark_position.z), beacon_material)
		_add_static_box(landmark_position, Vector3(42.0, height, 42.0), "LandmarkCollision")


func _build_bridges() -> void:
	for index in range(3):
		var z := city_origin.z - 205.0 - float(index) * 215.0
		var y := city_origin.y + 72.0 + float(index % 2) * 18.0
		var bridge := _box(Vector3(210.0, 9.0, 20.0), Vector3(city_origin.x, y, z), building_materials[0])
		bridge.name = "SkyBridge_%d" % index
		_add_static_box(bridge.position, Vector3(210.0, 9.0, 20.0), bridge.name + "Collision")
		_box(Vector3(190.0, 1.2, 21.0), Vector3(city_origin.x, y - 5.0, z), road_glow_material)


func _build_moon() -> void:
	var moon_position := city_origin + Vector3(-330.0, 470.0, -720.0)
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 72.0
	moon_mesh.height = 144.0
	moon_mesh.radial_segments = 40
	moon_mesh.rings = 24
	var moon := MeshInstance3D.new()
	moon.name = "FullMoon"
	moon.mesh = moon_mesh
	moon.position = moon_position
	moon.material_override = _emissive(Color(0.68, 0.78, 1.0), 1.45)
	add_child(moon)

	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonKeyLight"
	moon_light.light_color = Color(0.58, 0.70, 1.0)
	moon_light.light_energy = 2.25
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_max_distance = 500.0
	moon_light.position = moon_position
	moon_light.look_at(city_origin + Vector3(0.0, 10.0, -300.0), Vector3.UP)
	add_child(moon_light)

	# A handful of actual lamps supplement emissive architecture without turning
	# the mobile scene into hundreds of dynamic lights.
	for lamp_position in [
		Vector3(-24.0, 18.0, -80.0), Vector3(24.0, 18.0, -170.0),
		Vector3(-24.0, 18.0, -320.0), Vector3(24.0, 18.0, -470.0),
		Vector3(-24.0, 18.0, -620.0), Vector3(24.0, 18.0, -760.0),
	]:
		var light := OmniLight3D.new()
		light.position = city_origin + lamp_position
		light.omni_range = 105.0
		light.light_energy = 3.0
		light.light_color = Color(0.15, 0.70, 1.0)
		light.shadow_enabled = false
		add_child(light)


func _build_traffic() -> void:
	var cyan := _emissive(Color(0.10, 0.92, 1.0), 5.0)
	var amber := _emissive(Color(1.0, 0.42, 0.08), 5.0)
	for index in traffic_count:
		var vehicle := _box(Vector3(5.0, 1.2, 2.2), Vector3.ZERO, cyan if index % 2 == 0 else amber)
		vehicle.name = "Traffic_%02d" % index
		var forward_lane := index % 3 != 0
		var direction := Vector3(0.0, 0.0, -1.0 if forward_lane else 1.0)
		vehicle.position = city_origin + Vector3(
			-13.0 if forward_lane else 13.0,
			rng.randf_range(10.0, 34.0),
			rng.randf_range(-760.0, 130.0)
		)
		traffic.append({
			"node": vehicle,
			"direction": direction,
			"speed": rng.randf_range(18.0, 42.0),
		})

	# A few cross-traffic craft emphasize lateral motion at intersections.
	for index in range(10):
		var vehicle := _box(Vector3(4.2, 1.0, 2.0), Vector3.ZERO, window_material)
		var direction := Vector3(1.0 if index % 2 == 0 else -1.0, 0.0, 0.0)
		vehicle.position = city_origin + Vector3(
			rng.randf_range(-520.0, 520.0),
			rng.randf_range(14.0, 46.0),
			-74.0 * float([2, 6, 10][index % 3])
		)
		traffic.append({
			"node": vehicle,
			"direction": direction,
			"speed": rng.randf_range(20.0, 36.0),
		})


func _box(size: Vector3, position_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	add_child(instance)
	return instance


func _add_static_box(position_value: Vector3, size: Vector3, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color * 0.34, 0.38, 0.22)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
