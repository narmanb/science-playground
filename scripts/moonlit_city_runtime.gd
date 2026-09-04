extends MoonlitCity
class_name MoonlitCityRuntime

const MOON_TEXTURE_SIZE := 192
const MOON_WORLD_DIAMETER := 88.0


func _build_moon() -> void:
	# A distant astronomical body is effectively a camera-facing disc at this
	# scale. Sprite3D keeps the limb circular even far off-axis while still living
	# in world space and participating in ordinary depth occlusion by the skyline.
	var moon := Sprite3D.new()
	moon.name = "FullMoon"
	moon.texture = _build_moon_texture()
	moon.pixel_size = MOON_WORLD_DIAMETER / float(MOON_TEXTURE_SIZE)
	moon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon.shaded = false
	moon.position = city_origin + Vector3(-90.0, 170.0, -1050.0)
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


func _build_moon_texture() -> ImageTexture:
	var image := Image.create(MOON_TEXTURE_SIZE, MOON_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var craters := [
		Vector3(-0.38, -0.16, 0.15),
		Vector3(0.33, -0.31, 0.11),
		Vector3(0.20, 0.22, 0.17),
		Vector3(-0.12, 0.42, 0.095),
		Vector3(0.54, 0.10, 0.075),
		Vector3(-0.52, 0.30, 0.065),
		Vector3(0.02, -0.55, 0.085),
	]
	var maria := [
		Vector3(-0.18, -0.08, 0.34),
		Vector3(0.38, 0.18, 0.24),
		Vector3(-0.34, 0.40, 0.19),
	]
	var base := Color(0.79, 0.86, 1.0, 1.0)
	var half_size := float(MOON_TEXTURE_SIZE) * 0.5

	for y in range(MOON_TEXTURE_SIZE):
		for x in range(MOON_TEXTURE_SIZE):
			var nx := (float(x) + 0.5 - half_size) / half_size
			var ny := (float(y) + 0.5 - half_size) / half_size
			var radial_sq := nx * nx + ny * ny
			if radial_sq > 1.0:
				continue

			var limb := sqrt(maxf(0.0, 1.0 - radial_sq))
			var shade := 0.80 + limb * 0.18
			# Low-frequency deterministic surface variation keeps the disc from
			# reading like a flat HUD circle without requiring a texture asset.
			shade += sin(nx * 11.0 + ny * 6.0) * 0.018
			shade += sin(nx * 5.0 - ny * 14.0) * 0.012

			for patch in maria:
				var patch_distance := Vector2(nx - patch.x, ny - patch.y).length()
				if patch_distance < patch.z:
					shade -= (1.0 - patch_distance / patch.z) * 0.105

			for crater in craters:
				var crater_distance := Vector2(nx - crater.x, ny - crater.y).length()
				if crater_distance < crater.z:
					var normalized_distance := crater_distance / crater.z
					shade -= (1.0 - normalized_distance) * 0.16
					if normalized_distance > 0.72:
						shade += (normalized_distance - 0.72) / 0.28 * 0.045

			# Slight edge falloff softens the alpha fringe against the night sky.
			var alpha := 1.0
			if radial_sq > 0.94:
				alpha = clampf((1.0 - radial_sq) / 0.06, 0.0, 1.0)
			image.set_pixel(x, y, Color(
				clampf(base.r * shade, 0.0, 1.0),
				clampf(base.g * shade, 0.0, 1.0),
				clampf(base.b * shade, 0.0, 1.0),
				alpha
			))

	return ImageTexture.create_from_image(image)


func _compose_moon_after_cockpit_settles(moon: Node3D, moon_light: DirectionalLight3D) -> void:
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