@tool
class_name GStateBooleanSetting
extends CheckButton

var _gstate_signal_binding: GStateSignalBinding = GStateSignalBinding.new()

@export 
var selected_gstate_property: String:
	set(value):
		selected_gstate_property = value 
		_reinit()

func _ready() -> void:
	
	
	
	# Update the GState property on change
	toggled.connect(
		func(state: bool):
			if selected_gstate_property != "":
				GState.set(selected_gstate_property, state)
	)

	_reinit()


func _reinit():
	
	# Change the value of this button to represent the current GState
	if selected_gstate_property != "":
		if typeof(GState.get(selected_gstate_property)) != TYPE_BOOL:
			print_verbose("GState Value " + str(selected_gstate_property) + " is not a bool.")
		button_pressed = GState.get(selected_gstate_property) as bool
		
		if not _gstate_signal_binding.reconnect_property_changed(selected_gstate_property, _on_gstate_changed):
			print_verbose("GUI Failed to connect to signal of GState ... does %s exist?" % (selected_gstate_property + "_changed"))
	else:
		_gstate_signal_binding.clear_binding(_on_gstate_changed)
		print_verbose("Settings Button %s incorrectly configured" % name)

func _on_gstate_changed(state: bool):
	set_pressed_no_signal(state) 

func _validate_property(property: Dictionary):
	# Overwrite the editor properties of the variable to enable a custom dropdown of values
	if property.name == "selected_gstate_property":
		
		# Filter for boolean properties of GState
		var gstate_properties = GState.get_property_list()
		var boolean_properties : PackedStringArray = []
		for prop in gstate_properties:
			# Only use booleans and custom script properties
			if prop["usage"] & 4096 &&  prop["type"] == 1:
				boolean_properties.append(prop["name"])
		
		# Our property is a string
		property.hint = 2
		# Possible values
		property.hint_string = ",".join(boolean_properties)
		property.usage = 4102
		
