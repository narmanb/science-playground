extends Node
class_name StellarLightingController

@export var star_light_path := NodePath("../AlienSystem/AsterionLight")
@export var fill_light_path := NodePath("../AsterionParallelLight")
@export var playable_star_range := 2400.0
@export var playable_attenuation := 0.45
@export var star_energy_multiplier := 1.75
@export var fill_energy := 0.22


func _ready() -> void:
	_apply_lighting.call_deferred()


func _apply_lighting() -> void:
	# ProceduralSystem creates the stellar OmniLight3D at runtime. The world uses
	# a compressed spatial scale, so Godot's finite-range falloff is tuned here
	# for readable gameplay while preserving the physically meaningful direction:
	# illumination always originates at Asterion rather than from a fixed sky sun.
	for _frame in 2:
		await get_tree().process_frame

	var star_light := get_node_or_null(star_light_path) as OmniLight3D
	if star_light == null:
		push_warning("Stellar lighting controller could not find Asterion's point light.")
	else:
		star_light.omni_range = playable_star_range
		star_light.omni_attenuation = playable_attenuation
		star_light.light_energy *= star_energy_multiplier

	# Retain only a low-energy directional fill so the unlit hemisphere is not
	# crushed to featureless black on mobile displays. It is not the source used
	# to determine the planet's day side.
	var fill_light := get_node_or_null(fill_light_path) as DirectionalLight3D
	if fill_light != null:
		fill_light.light_energy = fill_energy
