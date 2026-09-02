extends Control
class_name ScienceObjectiveHUD

@export var navigation_hud_path: NodePath
@export var science_log_hud_path: NodePath
@export var flight_hud_path: NodePath

var navigation_hud: NavigationHUD
var science_log: ScienceLogHUD
var flight_hud: FlightHUD
var objective_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_hud = get_node(navigation_hud_path) as NavigationHUD
	science_log = get_node(science_log_hud_path) as ScienceLogHUD
	flight_hud = get_node(flight_hud_path) as FlightHUD

	objective_label = Label.new()
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 16)
	objective_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.82, 0.92))
	add_child(objective_label)
	_layout_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()


func _process(_delta: float) -> void:
	if navigation_hud == null or science_log == null or flight_hud == null:
		objective_label.visible = false
		return

	# Scanner feedback already owns the pilot's attention while a lock is active.
	# Suppressing this line keeps the cockpit legible instead of stacking prompts.
	if flight_hud.scan_target != null:
		objective_label.visible = false
		return

	var target := navigation_hud.current_target()
	if target == null or not is_instance_valid(target):
		objective_label.visible = false
		return

	objective_label.text = _objective_for(target)
	objective_label.visible = true


func _objective_for(target: Node3D) -> String:
	var body_name := _target_name(target)
	var achieved := int(science_log.discoveries.get(body_name, -1))
	var max_tier := int(target.get_meta("scan_profile_max_tier", 0))

	if max_tier <= 0:
		if achieved >= 0:
			return "SCIENCE %s   •   SURVEY COMPLETE   •   CYCLE NAV FOR NEXT TARGET" % body_name
		return "SCIENCE %s   •   SURVEY READY   •   CENTER TARGET + SCAN" % body_name

	if achieved >= max_tier:
		return "SCIENCE %s   •   FULL SURVEY COMPLETE   •   CYCLE NAV FOR NEXT WORLD" % body_name

	var current_zone := clampi(int(target.get_meta("scan_profile_tier", 0)), 0, max_tier)
	var zone_name := _tier_name(current_zone)

	# A close first encounter can legitimately produce a deeper scan immediately;
	# the catalog records the best completed tier, so no artificial prerequisite
	# forces the pilot to back away and repeat lower-resolution surveys.
	if current_zone > achieved:
		return "SCIENCE %s   •   ZONE %s   •   %s PASS READY — CENTER + SCAN" % [
			body_name,
			zone_name,
			zone_name,
		]

	var next_tier := clampi(achieved + 1, 0, max_tier)
	return "SCIENCE %s   •   ZONE %s   •   APPROACH FOR %s PASS" % [
		body_name,
		zone_name,
		_tier_name(next_tier),
	]


func _tier_name(tier: int) -> String:
	match tier:
		0:
			return "REMOTE"
		1:
			return "SPECTRAL"
		_:
			return "PROXIMITY"


func _target_name(target: Node3D) -> String:
	return str(target.get_meta("scan_name", target.name)).to_upper()


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	objective_label.position = Vector2(size.x * 0.22, 124.0)
	objective_label.size = Vector2(size.x * 0.56, 30.0)
