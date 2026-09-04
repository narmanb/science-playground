extends MoonlitCity
class_name MoonlitCityRuntime


func _build_moon() -> void:
	# Compose the moon in the open central flight avenue so it is immediately
	# visible through the cockpit instead of being lost behind towers/canopy.
	# Its large distance keeps it reading as a sky object while the diameter is
	# deliberately exaggerated enough to remain obvious on a phone display.
	var moon_position := city_origin + Vector3(-90.0, 170.0, -1050.0)
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 110.0
	moon_mesh.height = 220.0
	moon_mesh.radial_segments = 48
	moon_mesh.rings = 28
	var moon := MeshInstance3D.new()
	moon.name = "FullMoon"
	moon.mesh = moon_mesh
	moon.position = moon_position
	moon.material_override = _emissive(Color(0.78, 0.86, 1.0), 1.9)
	add_child(moon)

	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonKeyLight"
	moon_light.light_color = Color(0.58, 0.70, 1.0)
	moon_light.light_energy = 2.35
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_max_distance = 500.0
	moon_light.position = moon_position
	add_child(moon_light)
	moon_light.look_at(city_origin + Vector3(0.0, 10.0, -300.0), Vector3.UP)

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