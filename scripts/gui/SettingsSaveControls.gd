@tool
extends HBoxContainer

@onready var save_button: Button = $Save
@onready var restore_button: Button = $Restore


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	restore_button.pressed.connect(_on_restore_pressed)

	if not GState.unsaved_settings_changed.is_connected(_on_unsaved_settings_changed):
		GState.unsaved_settings_changed.connect(_on_unsaved_settings_changed)

	_on_unsaved_settings_changed(GState.has_unsaved_settings())


func _exit_tree() -> void:
	if GState.unsaved_settings_changed.is_connected(_on_unsaved_settings_changed):
		GState.unsaved_settings_changed.disconnect(_on_unsaved_settings_changed)


func _on_save_pressed() -> void:
	GState.store_to_file()


func _on_restore_pressed() -> void:
	GState.restore_default_settings()


func _on_unsaved_settings_changed(has_unsaved_changes: bool) -> void:
	save_button.disabled = not has_unsaved_changes
