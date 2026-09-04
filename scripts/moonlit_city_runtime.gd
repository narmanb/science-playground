extends MoonlitCity
class_name MoonlitCityRuntime


func _build_moon() -> void:
	# Compose the moon for the actual cockpit view: low enough to clear the canopy
	# crossbar, left of the flight avenue, and large enough to read immediately on
	# a phone without becoming a nearby-looking object.
	var moon_position := city_origin + Vector3(-250.0, 250.0, -900.0)
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 95.0
	moon_mesh.height = 190.0
	moon_mesh.radial_segments = 48
	moon_mesh.rings = 28
	var moon := MeshInstance3D.new()
	moon.name = "FullMoon"
	moon.mesh = moon_mesh
	moon.position = moon_position
	moon.material_override = _emissive(Color(0.76, 0.84, 1.0), 1.75)
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