extends Node3D
class_name ProceduralSystem

const SYSTEM_MANIFEST_PATH := "res://data/asterion_system.json"
const PLAYABLE_UNITS_PER_AU := 310.0 / 0.68
const NYSA_REFERENCE_PERIOD_DAYS := 239.713
const NYSA_REFERENCE_ORBIT_SPEED := 0.006

@export var asteroid_count := 420
@export var ring_particle_count := 700
@export var seed := 731942

var rng := RandomNumberGenerator.new()
var orbiters: Array[Dictionary] = []
var system_manifest: Dictionary = {}


func _ready() -> void:
	_load_system_manifest()
	seed = int(system_manifest.get("seed", seed))
	rng.seed = seed
	_build_system()


func _process(delta: float) -> void:
	for orbiter in orbiters:
		var pivot: Node3D = orbiter["pivot"]
		pivot.rotate_y(float(orbiter["speed"]) * delta)


func _load_system_manifest() -> void:
	if not FileAccess.file_exists(SYSTEM_MANIFEST_PATH):
		push_warning("Science manifest missing; falling back to prototype defaults.")
		return
	var file := FileAccess.open(SYSTEM_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Science manifest could not be opened; falling back to prototype defaults.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Science manifest JSON is invalid; falling back to prototype defaults.")
		return
	system_manifest = parsed


func _body_data(body_name: String) -> Dictionary:
	var bodies: Array = system_manifest.get("bodies", [])
	for body in bodies:
		if typeof(body) == TYPE_DICTIONARY and String(body.get("name", "")) == body_name:
			return body
	return {}


func _build_system() -> void:
	_create_star()
	_create_nysa_and_thale()
	_create_additional_planets()
	_create_asteroid_belt()
	_create_background_stars()


func _create_star() -> void:
	var star_data: Dictionary = system_manifest.get("star", {})
	var radius_solar: float = float(star_data.get("radius_solar", 0.777425))
	var luminosity_solar: float = float(star_data.get("luminosity_solar", 0.283982))
	var mass_solar: float = float(star_data.get("mass_solar", 0.73))
	var temperature_k: float = float(star_data.get("effective_temperature_k", 4778.8))
	var spectral_hint := String(star_data.get("spectral_hint", "K-type orange dwarf"))
	var visual_radius: float = 28.0 * radius_solar / 0.777425

	var star := MeshInstance3D.new()
	star.name = String(star_data.get("name", "Asterion"))
	var mesh := SphereMesh.new()
	mesh.radius = visual_radius
	mesh.height = visual_radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	star.mesh = mesh
	star.material_override = _emissive_material(Color(1.0, 0.54, 0.16), 5.5)
	star.set_meta("scan_name", star.name.to_upper())
	star.set_meta("scan_class", spectral_hint.to_upper())
	star.set_meta(
		"scan_note",
		"Mass %.2f M_sun | Radius %.3f R_sun | Luminosity %.3f L_sun | Teff %.0f K" % [
			mass_solar,
			radius_solar,
			luminosity_solar,
			temperature_k,
		]
	)
	add_child(star)

	var light := OmniLight3D.new()
	light.name = "AsterionLight"
	light.omni_range = 1000.0
	light.light_energy = clampf(4.7 + luminosity_solar * 3.5, 5.0, 7.5)
	light.shadow_enabled = false
	light.light_color = Color(1.0, 0.71, 0.48)
	add_child(light)


func _create_nysa_and_thale() -> void:
	var planet_data: Dictionary = _body_data("Nysa")
	var moon_data: Dictionary = _body_data("Thale")

	var planet_radius_earth: float = float(planet_data.get("radius_earth", 1.34))
	var semimajor_axis_au: float = float(planet_data.get("semimajor_axis_au", 0.68))
	var orbital_period_days: float = float(planet_data.get("orbital_period_days", NYSA_REFERENCE_PERIOD_DAYS))
	var planet_radius: float = 22.0 * planet_radius_earth / 1.34
	var orbital_radius: float = PLAYABLE_UNITS_PER_AU * semimajor_axis_au
	var orbit_speed: float = _playable_orbit_speed(orbital_period_days)

	var planet_pivot := Node3D.new()
	planet_pivot.name = "PlanetOrbit"
	planet_pivot.rotation_degrees.y = float(planet_data.get("initial_phase_degrees", 0.0))
	add_child(planet_pivot)
	orbiters.append({"pivot": planet_pivot, "speed": orbit_speed})

	var planet := _make_sphere_body(
		"Nysa",
		planet_radius,
		Vector3(orbital_radius, 0.0, 0.0),
		Color(0.18, 0.4, 0.49),
		0.72,
		0.12
	)
	var planet_kind := String(planet_data.get("kind", "oceanic_super_earth_candidate")).replace("_", " ").to_upper()
	var atmosphere: Dictionary = planet_data.get("atmosphere", {})
	var pressure_bar: float = float(atmosphere.get("surface_pressure_bar", 2.7))
	planet.set_meta("scan_name", "NYSA")
	planet.set_meta("scan_class", planet_kind)
	planet.set_meta(
		"scan_note",
		"Mass %.2f Earth | Radius %.2f Earth | Gravity %.3f g | Orbit %.1f d | Teq %.1f K | Atmosphere %.1f bar" % [
			float(planet_data.get("mass_earth", 2.6)),
			planet_radius_earth,
			float(planet_data.get("surface_gravity_g", 1.448)),
			orbital_period_days,
			float(planet_data.get("equilibrium_temperature_k", 248.3)),
			pressure_bar,
		]
	)
	planet_pivot.add_child(planet)
	_add_atmosphere(planet, planet_radius * 1.055, Color(0.16, 0.56, 0.9, 0.16))
	if bool((planet_data.get("rings", {}) as Dictionary).get("present", true)):
		_add_ring_system(planet, 1.40, 2.22, Color(0.62, 0.70, 0.73), ring_particle_count)

	var moon_pivot := Node3D.new()
	moon_pivot.name = "MoonOrbit"
	moon_pivot.position = planet.position
	planet_pivot.add_child(moon_pivot)
	orbiters.append({"pivot": moon_pivot, "speed": 0.05})

	var moon_radius_earth: float = float(moon_data.get("radius_earth", 0.48))
	var moon_radius: float = 7.0 * moon_radius_earth / 0.48
	var moon := _make_sphere_body(
		"Thale",
		moon_radius,
		Vector3(48.0, 2.0, 0.0),
		Color(0.4, 0.37, 0.34),
		0.96,
		0.02
	)
	moon.set_meta("scan_name", "THALE")
	moon.set_meta("scan_class", String(moon_data.get("kind", "rocky_moon")).replace("_", " ").to_upper())
	moon.set_meta(
		"scan_note",
		"Mass %.3f Earth | Radius %.2f Earth | Surface gravity %.3f m/s^2" % [
			float(moon_data.get("mass_earth", 0.1)),
			moon_radius_earth,
			float(moon_data.get("surface_gravity_m_s2", 4.256)),
		]
	)
	moon_pivot.add_child(moon)


func _create_additional_planets() -> void:
	var visual_configs := {
		"Veyr": {
			"radius": 13.0,
			"color": Color(0.52, 0.19, 0.07),
			"roughness": 0.92,
			"metallic": 0.05,
			"atmosphere": Color(0.72, 0.22, 0.08, 0.08),
		},
		"Orun": {
			"radius": 25.0,
			"color": Color(0.24, 0.45, 0.58),
			"roughness": 0.74,
			"metallic": 0.0,
			"atmosphere": Color(0.24, 0.60, 0.75, 0.12),
		},
		"Kharis": {
			"radius": 43.0,
			"color": Color(0.17, 0.37, 0.48),
			"roughness": 0.68,
			"metallic": 0.0,
			"atmosphere": Color(0.20, 0.52, 0.68, 0.11),
			"ring_color": Color(0.45, 0.39, 0.34),
			"ring_count": 900,
			"ring_inner": 1.32,
			"ring_outer": 2.45,
		},
	}

	for body_name in ["Veyr", "Orun", "Kharis"]:
		var body_data := _body_data(body_name)
		if body_data.is_empty():
			continue
		var config: Dictionary = visual_configs[body_name]
		_create_manifest_planet(body_data, config)


func _create_manifest_planet(body_data: Dictionary, visual_config: Dictionary) -> void:
	var body_name := String(body_data.get("name", "Unnamed"))
	var semimajor_axis_au: float = float(body_data.get("semimajor_axis_au", 1.0))
	var orbital_period_days: float = float(body_data.get("orbital_period_days", 365.25))
	var orbital_radius: float = PLAYABLE_UNITS_PER_AU * semimajor_axis_au
	var phase_degrees: float = float(body_data.get("initial_phase_degrees", 0.0))

	var pivot := Node3D.new()
	pivot.name = body_name + "Orbit"
	pivot.rotation_degrees.y = phase_degrees
	add_child(pivot)
	orbiters.append({"pivot": pivot, "speed": _playable_orbit_speed(orbital_period_days)})

	var radius: float = float(visual_config.get("radius", 16.0))
	var color: Color = visual_config.get("color", Color(0.35, 0.35, 0.35))
	var roughness: float = float(visual_config.get("roughness", 0.82))
	var metallic: float = float(visual_config.get("metallic", 0.0))
	var planet := _make_sphere_body(
		body_name,
		radius,
		Vector3(orbital_radius, 0.0, 0.0),
		color,
		roughness,
		metallic
	)
	planet.set_meta("scan_name", body_name.to_upper())
	planet.set_meta("scan_class", String(body_data.get("kind", "planet")).replace("_", " ").to_upper())
	planet.set_meta(
		"scan_note",
		"Mass %.2f Earth | Radius %.2f Earth | Gravity %.3f g | Orbit %.1f d | Teq %.1f K" % [
			float(body_data.get("mass_earth", 1.0)),
			float(body_data.get("radius_earth", 1.0)),
			float(body_data.get("surface_gravity_g", 1.0)),
			orbital_period_days,
			float(body_data.get("equilibrium_temperature_k", 0.0)),
		]
	)
	pivot.add_child(planet)

	if visual_config.has("atmosphere"):
		var atmosphere_color: Color = visual_config["atmosphere"]
		_add_atmosphere(planet, radius * 1.045, atmosphere_color)

	var rings: Dictionary = body_data.get("rings", {})
	if bool(rings.get("present", false)) and visual_config.has("ring_color"):
		_add_ring_system(
			planet,
			float(visual_config.get("ring_inner", 1.4)),
			float(visual_config.get("ring_outer", 2.2)),
			visual_config["ring_color"],
			int(visual_config.get("ring_count", ring_particle_count))
		)


func _playable_orbit_speed(orbital_period_days: float) -> float:
	return NYSA_REFERENCE_ORBIT_SPEED * NYSA_REFERENCE_PERIOD_DAYS / maxf(orbital_period_days, 1.0)


func _make_sphere_body(body_name: String, radius: float, position_value: Vector3, color: Color, roughness: float, metallic: float) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = body_name
	body.position = position_value
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	body.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	body.material_override = material
	return body


func _add_atmosphere(parent_body: MeshInstance3D, radius: float, color: Color) -> void:
	var atmosphere := MeshInstance3D.new()
	atmosphere.name = "Atmosphere"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	atmosphere.mesh = sphere
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	atmosphere.material_override = material
	parent_body.add_child(atmosphere)


func _add_ring_system(parent_body: MeshInstance3D, inner_factor: float, outer_factor: float, ring_color: Color, instance_count: int) -> void:
	var source_sphere := parent_body.mesh as SphereMesh
	if source_sphere == null:
		return
	var base_radius: float = source_sphere.radius

	var rings := MultiMeshInstance3D.new()
	rings.name = parent_body.name + "Rings"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var pebble := BoxMesh.new()
	pebble.size = Vector3(base_radius * 0.015, base_radius * 0.0035, base_radius * 0.008)
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = ring_color
	ring_material.roughness = 0.86
	pebble.material = ring_material
	multimesh.mesh = pebble
	multimesh.instance_count = instance_count

	for i in instance_count:
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(base_radius * inner_factor, base_radius * outer_factor)
		var vertical: float = rng.randfn(0.0, base_radius * 0.012)
		var position_value := Vector3(cos(angle) * radius, vertical, sin(angle) * radius)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var scale_value: float = rng.randf_range(0.45, 1.7)
		basis = basis.scaled(Vector3.ONE * scale_value)
		multimesh.set_instance_transform(i, Transform3D(basis, position_value))

	rings.multimesh = multimesh
	parent_body.add_child(rings)


func _create_asteroid_belt() -> void:
	var asteroids := MultiMeshInstance3D.new()
	asteroids.name = "OuterAsteroidBelt"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var asteroid := SphereMesh.new()
	asteroid.radius = 1.0
	asteroid.height = 2.0
	asteroid.radial_segments = 8
	asteroid.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.18, 0.16)
	material.roughness = 1.0
	asteroid.material = material
	multimesh.mesh = asteroid
	multimesh.instance_count = asteroid_count

	for i in asteroid_count:
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(650.0, 760.0)
		var y: float = rng.randfn(0.0, 15.0)
		var position_value := Vector3(cos(angle) * radius, y, sin(angle) * radius)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		basis = basis.scaled(Vector3(
			rng.randf_range(0.7, 3.4),
			rng.randf_range(0.6, 2.3),
			rng.randf_range(0.7, 3.4)
		))
		multimesh.set_instance_transform(i, Transform3D(basis, position_value))

	asteroids.multimesh = multimesh
	add_child(asteroids)


func _create_background_stars() -> void:
	var stars := MultiMeshInstance3D.new()
	stars.name = "BackgroundStars"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.55
	star_mesh.height = 1.1
	star_mesh.radial_segments = 5
	star_mesh.rings = 3
	star_mesh.material = _emissive_material(Color(0.82, 0.88, 1.0), 2.5)
	multimesh.mesh = star_mesh
	multimesh.instance_count = 360

	for i in 360:
		var direction := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		var distance: float = rng.randf_range(1450.0, 1750.0)
		var scale_value: float = rng.randf_range(0.45, 1.9)
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_value), direction * distance))

	stars.multimesh = multimesh
	add_child(stars)


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
