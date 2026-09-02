extends Node

const NYSA_SURFACE := preload("res://shaders/nysa_surface.gdshader")
const NYSA_CLOUDS := preload("res://shaders/nysa_clouds.gdshader")
const VEYR_SURFACE := preload("res://shaders/veyr_surface.gdshader")
const ORUN_SURFACE := preload("res://shaders/orun_surface.gdshader")
const KHARIS_SURFACE := preload("res://shaders/kharis_surface.gdshader")
const PLANET_RINGS := preload("res://shaders/planet_rings.gdshader")


func _ready() -> void:
	_apply_visuals.call_deferred()


func _apply_visuals() -> void:
	await get_tree().process_frame
	_apply_surface(NodePath("../AlienSystem/VeyrOrbit/Veyr"), VEYR_SURFACE)
	_apply_surface(NodePath("../AlienSystem/OrunOrbit/Orun"), ORUN_SURFACE)
	_apply_surface(NodePath("../AlienSystem/KharisOrbit/Kharis"), KHARIS_SURFACE)
	_add_kharis_ring_sheet()

	var nysa := get_node_or_null("../AlienSystem/PlanetOrbit/Nysa") as MeshInstance3D
	if nysa == null:
		push_warning("Visual enhancer could not find Nysa.")
		return

	var surface_material := ShaderMaterial.new()
	surface_material.shader = NYSA_SURFACE
	nysa.material_override = surface_material

	if nysa.get_node_or_null("CloudShell") != null:
		return

	var source_sphere := nysa.mesh as SphereMesh
	if source_sphere == null:
		return

	var clouds := MeshInstance3D.new()
	clouds.name = "CloudShell"
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = source_sphere.radius * 1.028
	cloud_mesh.height = source_sphere.height * 1.028
	cloud_mesh.radial_segments = 48
	cloud_mesh.rings = 24
	clouds.mesh = cloud_mesh

	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = NYSA_CLOUDS
	clouds.material_override = cloud_material
	nysa.add_child(clouds)


func _apply_surface(node_path: NodePath, shader: Shader) -> void:
	var body := get_node_or_null(node_path) as MeshInstance3D
	if body == null:
		push_warning("Visual enhancer could not find %s." % node_path)
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	body.material_override = material


func _add_kharis_ring_sheet() -> void:
	var kharis := get_node_or_null("../AlienSystem/KharisOrbit/Kharis") as MeshInstance3D
	if kharis == null or kharis.get_node_or_null("BroadRingSheet") != null:
		return
	var sphere := kharis.mesh as SphereMesh
	if sphere == null:
		return

	var outer_radius := sphere.radius * 2.45
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * outer_radius * 2.0
	plane.subdivide_width = 1
	plane.subdivide_depth = 1

	var material := ShaderMaterial.new()
	material.shader = PLANET_RINGS
	material.set_shader_parameter("inner_radius", 1.32 / 2.45)
	material.set_shader_parameter("inner_color", Vector3(0.18, 0.15, 0.14))
	material.set_shader_parameter("outer_color", Vector3(0.55, 0.47, 0.38))
	material.set_shader_parameter("opacity", 0.58)

	var ring_sheet := MeshInstance3D.new()
	ring_sheet.name = "BroadRingSheet"
	ring_sheet.mesh = plane
	ring_sheet.material_override = material
	kharis.add_child(ring_sheet)
