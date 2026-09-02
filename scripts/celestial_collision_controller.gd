extends Node
class_name CelestialCollisionController

@export_range(0.5, 1.0, 0.01) var collision_radius_scale := 0.97


func _ready() -> void:
	_build_collision_shells.call_deferred()


func _build_collision_shells() -> void:
	# Procedural bodies and ScanRegistry are created at runtime. Wait for both so
	# collision geometry can be derived from the exact rendered sphere radius.
	for _frame in 3:
		await get_tree().process_frame

	var built := 0
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if not candidate is MeshInstance3D:
			continue
		var body := candidate as MeshInstance3D
		if body.get_node_or_null("CelestialCollision") != null:
			continue
		var sphere_mesh := body.mesh as SphereMesh
		if sphere_mesh == null:
			continue

		var collision_radius := sphere_mesh.radius * collision_radius_scale
		var static_body := StaticBody3D.new()
		static_body.name = "CelestialCollision"
		static_body.collision_layer = 1
		static_body.collision_mask = 1

		var shape_node := CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = collision_radius
		shape_node.shape = sphere_shape

		static_body.add_child(shape_node)
		body.add_child(static_body)
		body.set_meta("collision_radius", collision_radius)
		built += 1

	if built == 0:
		push_warning("Celestial collision controller did not find any spherical scan targets.")
