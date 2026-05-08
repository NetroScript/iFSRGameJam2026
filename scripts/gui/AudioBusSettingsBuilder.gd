@tool
extends Label

const GENERATED_META := &"generated_audio_bus_setting"

@export var row_min_height: float = 32.0
@export var label_width: float = 120.0
@export var value_label_width: float = 48.0

var _rebuild_queued := false


func _ready() -> void:
	_queue_rebuild()

	if not GState.audio_bus_layout_changed.is_connected(_on_audio_bus_layout_changed):
		GState.audio_bus_layout_changed.connect(_on_audio_bus_layout_changed)


func _exit_tree() -> void:
	if GState.audio_bus_layout_changed.is_connected(_on_audio_bus_layout_changed):
		GState.audio_bus_layout_changed.disconnect(_on_audio_bus_layout_changed)


func _on_audio_bus_layout_changed() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return

	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false

	var container := get_parent()
	if container == null:
		return

	_clear_generated_nodes(container)

	var insert_index := get_index() + 1
	for bus in GState.get_visible_audio_buses():
		var row := _create_audio_bus_row(bus)
		container.add_child(row)
		container.move_child(row, insert_index)
		insert_index += 1


func _clear_generated_nodes(container: Node) -> void:
	for child in container.get_children():
		if not child.has_meta(GENERATED_META):
			continue

		container.remove_child(child)
		child.queue_free()


func _create_audio_bus_row(bus: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sAudioBusSetting" % String(bus["name"]).validate_node_name()
	row.set_meta(GENERATED_META, true)
	row.custom_minimum_size.y = row_min_height
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = bus["display_name"]
	name_label.custom_minimum_size.x = label_width
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.name = "Value"
	value_label.custom_minimum_size.x = value_label_width
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var slider := HSlider.new()
	slider.name = "Volume"
	slider.set_script(GStateFloatSetting)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.set("label", value_label)
	slider.set("label_string", "%d%%")
	slider.set("value_multiplier", 100.0)
	slider.set("apply_multiplier_and_offset_to_label", true)
	slider.set("audio_bus_name", bus["name"])
	row.add_child(slider)
	row.add_child(value_label)

	return row
