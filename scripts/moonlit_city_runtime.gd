extends MoonlitCity
class_name MoonlitCityRuntime


func _build_moon() -> void:
	# Create a distant physical moon first, then compose its final world-space
	# direction from the settled cockpit camera. Once positioned it remains fixed
	# in the world; it is not a camera-attached HUD decoration.
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 44.0
	moon_mesh.height = 88.0
	moon_mesh.radial_segments = 48
	moon_mesh.rings = 28
	var moon := MeshInstance3D.new()
	moon.name = "FullMoon"
	moon.mesh = moon_mesh
	moon.position = city_origin + Vector3(-90.0, 170.0, -1050.0)
	moon.material_override = _emissive(Color(0.78, 0.86, 1.0), 1.9)
	add_child(moon)

	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonKeyLight"
	moon_light.light_color = Color(0.58, 0.70, 1.0)
	moon_light.light_energy = 2.35
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_max_distance = 500.0
	moon_light.position = moon.position
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

	_compose_moon_after_cockpit_settles.call_deferred(moon, moon_light)


func _compose_moon_after_cockpit_settles(moon: MeshInstance3D, moon_light: DirectionalLight3D) -> void:
	# CityTestMode finishes its local-scene setup after three frames. The dedicated
	# city capture turns the ship toward the avenue after ten. Waiting eleven makes
	# this one composition path valid for both Android startup and visual QA.
	for _frame in 11:
		await get_tree().process_frame

	var camera := get_node_or_null("../Ship/CameraRig/Camera3D") as Camera3D
	if camera == null or moon == null:
		push_warning("Moon composition could not find the cockpit camera or moon.")
		return

	var viewport_size := camera.get_viewport().get_visible_rect().size
	# Upper-left sky is intentionally open above the nearest skyline. On phones
	# this also keeps the moon away from the center reticle and cockpit controls.
	var desired_screen := Vector2(viewport_size.x * 0.10, viewport_size.y * 0.075)
	var ray_origin := camera.project_ray_origin(desired_screen)
	var ray_direction := camera.project_ray_normal(desired_screen).normalized()
	var sky_distance := 1600.0
	moon.global_position = ray_origin + ray_direction * sky_distance

	if moon_light != null:
		moon_light.global_position = moon.global_position
		moon_light.look_at(city_origin + Vector3(0.0, 10.0, -300.0), Vector3.UP)

	if OS.get_environment(CITY_CAPTURE_ENV) == "1":
		var behind := camera.is_position_behind(moon.global_position)
		var projected := camera.unproject_position(moon.global_position) if not behind else Vector2(-1.0, -1.0)
		print("CITY_MOON_TRACE desired=%s projected=%s behind=%s distance=%.2f visible=%s" % [desired_screen, projected, behind, camera.global_position.distance_to(moon.global_position), moon.visible])