extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_register_existing")


func _register_existing() -> void:
	_register_branch(get_tree().current_scene)


func _register_branch(node: Node) -> void:
	if node == null:
		return
	_register_node(node)
	for child in node.get_children():
		_register_branch(child)


func _on_node_added(node: Node) -> void:
	call_deferred("_register_node", node)


func _register_node(node: Node) -> void:
	if node is Node3D and node.has_meta("scan_name") and not node.is_in_group("scannable"):
		node.add_to_group("scannable")
