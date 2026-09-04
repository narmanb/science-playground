extends Node
class_name CityTestMode

const SYSTEM_CAPTURE_ENV := "SCIENCE_PLAYGROUND_CAPTURE"


func _ready() -> void:
	# The legacy science/system gallery still needs the complete orbital scene.
	# Normal gameplay and the dedicated city gallery use this local proving-ground
	# presentation until a proper orbital-to-surface transition system is built.
	if OS.get_environment(SYSTEM_CAPTURE_ENV) == "1":
		return
	_activate_local_city.call_deferred()


func _activate_local_city() -> void:
	for _frame in 3:
		await get_tree().process_frame

	var main := get_parent()
	if main == null:
		return

	var alien_system := main.get_node_or_null("AlienSystem") as Node3D
	if alien_system != null:
		alien_system.visible = false
		alien_system.set_process(false)
		# Prevent the cockpit scanner from acquiring invisible planets while the
		# player is testing low-altitude city flight.
		for candidate in get_tree().get_nodes_in_group("scannable"):
			if candidate is Node and alien_system.is_ancestor_of(candidate):
				candidate.remove_from_group("scannable")

	var stellar_light := main.get_node_or_null("AsterionParallelLight") as Light3D
	if stellar_light != null:
		stellar_light.visible = false

	for controller_name in [
		"StellarLightingController",
		"WorldRotationController",
		"CelestialCollisionController",
		"ScienceScanProfile",
	]:
		var controller := main.get_node_or_null(controller_name)
		if controller != null:
			controller.set_process(false)
			controller.set_physics_process(false)

	var hud_layer := main.get_node_or_null("HUDLayer") as CanvasLayer
	if hud_layer != null:
		for hud_name in ["NavigationHUD", "ProximityHUD", "ScienceLogHUD", "ScienceObjectiveHUD"]:
			var hud := hud_layer.get_node_or_null(hud_name) as CanvasItem
			if hud != null:
				hud.visible = false
				if hud is Node:
					(hud as Node).set_process(false)
					(hud as Node).set_process_input(false)

		var flight_hud := hud_layer.get_node_or_null("FlightHUD") as FlightHUD
		if flight_hud != null:
			flight_hud.navigation_hud = null

	# Moon composition now belongs exclusively to MoonlitCityRuntime. The previous
	# hardcoded reframe here silently overwrote the runtime skyline placement a few
	# frames after startup, which made visual tuning impossible and could put the
	# moon behind cockpit/city geometry.