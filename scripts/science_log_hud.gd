extends Control
class_name ScienceLogHUD

const SAVE_PATH := "user://science_discoveries.json"
const PREFERRED_ORDER := ["ASTERION", "VEYR", "NYSA", "THALE", "ORUN", "KHARIS"]
const TIER_NAMES := ["REMOTE", "SPECTRAL", "PROXIMITY"]

@export var flight_hud_path: NodePath

var flight_hud: FlightHUD
var log_button: Button
var log_panel: PanelContainer
var log_label: Label
var targets_by_name: Dictionary = {}
var discoveries: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight_hud = get_node(flight_hud_path) as FlightHUD
	_build_ui()
	_layout_ui()
	_load_discoveries()
	if flight_hud != null:
		flight_hud.scan_completed.connect(_on_scan_completed)
	_refresh_targets.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		toggle_log()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		toggle_log()


func _build_ui() -> void:
	log_button = Button.new()
	log_button.text = "LOG"
	log_button.focus_mode = Control.FOCUS_NONE
	log_button.add_theme_font_size_override("font_size", 17)
	log_button.pressed.connect(toggle_log)
	add_child(log_button)

	log_panel = PanelContainer.new()
	log_panel.visible = false
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(log_panel)

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_label.add_theme_font_size_override("font_size", 18)
	log_panel.add_child(log_label)


func _layout_ui() -> void:
	var size := get_viewport_rect().size
	var button_w := clampf(size.x * 0.068, 88.0, 126.0)
	var button_h := clampf(size.y * 0.072, 52.0, 76.0)
	log_button.position = Vector2(size.x - button_w * 3.45 - 46.0, 22.0)
	log_button.size = Vector2(button_w, button_h)
	log_panel.position = Vector2(size.x * 0.60, size.y * 0.16)
	log_panel.size = Vector2(size.x * 0.36, size.y * 0.55)


func toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	_update_display()


func _refresh_targets() -> void:
	for _frame in 6:
		await get_tree().process_frame
	targets_by_name.clear()
	for candidate in get_tree().get_nodes_in_group("scannable"):
		if candidate is Node3D:
			var target := candidate as Node3D
			targets_by_name[_target_name(target)] = target
	_update_display()


func _on_scan_completed(target: Node3D, tier: int) -> void:
	if target == null:
		return
	var body_name := _target_name(target)
	var max_tier := int(target.get_meta("scan_profile_max_tier", 0))
	var achieved_tier := clampi(tier, 0, max_tier)
	var previous_tier := int(discoveries.get(body_name, -1))
	if achieved_tier > previous_tier:
		discoveries[body_name] = achieved_tier
		_save_discoveries()
	_update_display()


func _update_display() -> void:
	var ordered_names := _ordered_target_names()
	var completed_bodies := 0
	var completed_levels := 0
	var total_levels := 0
	var lines: Array[String] = [
		"SCIENCE CATALOG",
		"Best completed survey depth is saved automatically.",
		"",
	]

	for body_name in ordered_names:
		var target: Node3D = targets_by_name.get(body_name)
		var max_tier := int(target.get_meta("scan_profile_max_tier", 0)) if target != null else _saved_max_tier_hint(body_name)
		var achieved := int(discoveries.get(body_name, -1))
		total_levels += max_tier + 1
		if achieved >= 0:
			completed_bodies += 1
			completed_levels += min(achieved, max_tier) + 1

		if achieved < 0:
			lines.append("%s   —   UNSCANNED" % body_name)
		elif max_tier <= 0:
			lines.append("%s   —   SURVEY COMPLETE" % body_name)
		else:
			var tier_name := TIER_NAMES[clampi(achieved, 0, TIER_NAMES.size() - 1)]
			lines.append("%s   —   %s   (%d/%d)" % [body_name, tier_name, achieved + 1, max_tier + 1])

	lines.append("")
	lines.append("BODIES %d/%d   •   DATA DEPTH %d/%d" % [completed_bodies, ordered_names.size(), completed_levels, total_levels])
	lines.append("Remote → Spectral → Proximity")
	log_label.text = "\n".join(lines)
	log_button.text = "LOG\n%d/%d" % [completed_bodies, ordered_names.size()]


func _ordered_target_names() -> Array[String]:
	var names: Array[String] = []
	for name_value in targets_by_name.keys():
		names.append(String(name_value))
	# Keep already-saved discoveries visible even if a target is temporarily not
	# registered yet during startup.
	for name_value in discoveries.keys():
		var body_name := String(name_value)
		if not names.has(body_name):
			names.append(body_name)
	names.sort_custom(func(a: String, b: String) -> bool:
		return _sort_index(a) < _sort_index(b)
	)
	return names


func _sort_index(body_name: String) -> int:
	var index := PREFERRED_ORDER.find(body_name)
	return index if index >= 0 else PREFERRED_ORDER.size() + body_name.unicode_at(0)


func _saved_max_tier_hint(body_name: String) -> int:
	return 2 if body_name in ["VEYR", "NYSA", "ORUN", "KHARIS"] else 0


func _target_name(target: Node3D) -> String:
	return str(target.get_meta("scan_name", target.name)).to_upper()


func _load_discoveries() -> void:
	discoveries.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in (parsed as Dictionary).keys():
		discoveries[String(key).to_upper()] = int((parsed as Dictionary)[key])


func _save_discoveries() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Science catalog could not save discoveries.")
		return
	file.store_string(JSON.stringify(discoveries, "  "))
