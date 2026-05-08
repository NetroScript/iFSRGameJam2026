@tool
class_name GStateFloatSetting
extends Slider

var _signal_paused : bool = false 
var _gstate_signal_binding: GStateSignalBinding = GStateSignalBinding.new()
var _audio_bus_volume_changed_connected: bool = false

enum SLIDER_TYPE {
	SLIDER_TYPE_INT,
	SLIDER_TYPE_FLOAT
}

@export_group("Label Settings")
@export 
var label: Label

@export 
var label_string: String = ""

@export_group("Value Settings")
@export 
var value_multiplier: float = 1.0

@export 
var value_offset: float = 0.0

@export 
var apply_multiplier_and_offset_to_label: bool = false

@export_group("")
@export 
var selected_gstate_property: String:
	set(value):
		selected_gstate_property = value 
		_reinit()

@export 
var audio_bus_name: String:
	set(value):
		audio_bus_name = value
		_reinit()

@export 
var slider_type: SLIDER_TYPE = SLIDER_TYPE.SLIDER_TYPE_FLOAT:
	set(value):
		slider_type = value
		notify_property_list_changed()


func _ready() -> void:
	# Update the GState property on change
	value_changed.connect(
		func(val: float):

			if label and apply_multiplier_and_offset_to_label:
				label.text = label_string % val
			
			val = (val - value_offset) / value_multiplier

			if label and not apply_multiplier_and_offset_to_label:
				label.text = label_string % val

			if _signal_paused:
				return

			if audio_bus_name != "":
				GState.set_audio_bus_volume(audio_bus_name, val)
			elif selected_gstate_property != "":
				if slider_type == SLIDER_TYPE.SLIDER_TYPE_INT:
					val = int(val)
				GState.set(selected_gstate_property, val)
	)

	_reinit()


func _exit_tree() -> void:
	_disconnect_audio_bus_volume_changed()
	_gstate_signal_binding.clear_binding(_on_gstate_changed)


func _reinit():
	_disconnect_audio_bus_volume_changed()

	# Change the value of this button to represent the current GState
	if audio_bus_name != "":
		_gstate_signal_binding.clear_binding(_on_gstate_changed)
		_set_displayed_value(GState.get_audio_bus_volume(audio_bus_name))
		if not GState.audio_bus_volume_changed.is_connected(_on_audio_bus_volume_changed):
			GState.audio_bus_volume_changed.connect(_on_audio_bus_volume_changed)
		_audio_bus_volume_changed_connected = true
	elif selected_gstate_property != "":
		_set_displayed_value(GState.get(selected_gstate_property) as float)

		if not _gstate_signal_binding.reconnect_property_changed(selected_gstate_property, _on_gstate_changed):
			print("GUI Failed to connect to signal of GState ... does %s exist?" % (selected_gstate_property + "_changed"))
	else:
		_gstate_signal_binding.clear_binding(_on_gstate_changed)
		print("Settings Slider %s incorrectly configured" % name)

func _on_gstate_changed(val: float):
	_set_displayed_value(val)

func _on_audio_bus_volume_changed(bus_name: String, val: float) -> void:
	if bus_name != audio_bus_name:
		return

	_set_displayed_value(val)

func _set_displayed_value(val: float) -> void:
	_signal_paused = true
	value = val * value_multiplier + value_offset
	if label:
		if apply_multiplier_and_offset_to_label:
			label.text = label_string % value
		else:
			label.text = label_string % val
	_signal_paused = false

func _disconnect_audio_bus_volume_changed() -> void:
	if not _audio_bus_volume_changed_connected:
		return

	if GState.audio_bus_volume_changed.is_connected(_on_audio_bus_volume_changed):
		GState.audio_bus_volume_changed.disconnect(_on_audio_bus_volume_changed)

	_audio_bus_volume_changed_connected = false

func _validate_property(property: Dictionary):
	# Overwrite the editor properties of the variable to enable a custom dropdown of values
	if property.name == "selected_gstate_property":
		
		# Filter for int or float properties of GState
		var gstate_properties = GState.get_property_list()
		var wanted_properties : PackedStringArray = []
		var wanted_type : int = 3 if slider_type == SLIDER_TYPE.SLIDER_TYPE_FLOAT else 2
		for prop in gstate_properties:
			# Only use floats/ints and custom script properties
			if prop["usage"] & 4096 &&  prop["type"] == wanted_type:
				wanted_properties.append(prop["name"])
		
		# Our property is a string
		property.hint = 2
		# Possible values
		property.hint_string = ",".join(wanted_properties)
		property.usage = 4102
		
