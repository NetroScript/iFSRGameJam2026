@tool
extends Node
class_name GameSettings


signal setting_changed(setting_name: StringName, value: Variant)
signal unsaved_settings_changed(has_unsaved_changes: bool)

signal language_changed(value: LANGUAGES)
signal fullscreen_changed(value: bool)
signal vsync_enabled_changed(value: bool)
signal settings_open_changed(value: bool)
signal credits_open_changed(value: bool)
signal paused_changed(value: bool)

signal audio_bus_volume_changed(bus_name: String, value: float)
signal audio_bus_mute_changed(bus_name: String, muted: bool)
signal audio_bus_layout_changed()

signal serialization_event(event: SERIALIZATION_EVENT)


enum SERIALIZATION_EVENT {
	BEFORE_SAVE,
	AFTER_SAVE,
	BEFORE_LOAD,
	AFTER_LOAD,
	NO_SETTINGS_FILE,
	LOAD_FAILED,
	SAVE_FAILED
}

enum LANGUAGES {
	ENGLISH,
	GERMAN
}

const LANGUAGE_LOCALES := {
	LANGUAGES.ENGLISH: "en",
	LANGUAGES.GERMAN: "de",
}

const SETTINGS_PATH := "user://settings.save"

# Audio buses whose names start with this marker are still saved/loaded,
# but are hidden from get_visible_audio_buses().
#
# Example:
#   "_Debug"
const HIDDEN_AUDIO_BUS_PREFIX := "_"


var default_settings: Dictionary = {}
var _saved_settings_snapshot: Dictionary = {}

# Saved as:
# {
#   "Master": 1.0,
#   "Music": 0.8,
#   "SFX": 0.75
# }
var audio_bus_volumes: Dictionary[String, float] = {}

# Saved as:
# {
#   "Master": false,
#   "Music": false,
#   "SFX": true
# }
var audio_bus_mutes: Dictionary[String, bool] = {}

# -------------------------------------------------------------------
# General settings
# -------------------------------------------------------------------

var selected_language: LANGUAGES = LANGUAGES.ENGLISH:
	set(value):
		if selected_language == value:
			return

		selected_language = value
		language_changed.emit(value)
		TranslationServer.set_locale(LANGUAGE_LOCALES[value])
		setting_changed.emit(&"selected_language", value)


var fullscreen: bool = false:
	set(value):
		if fullscreen == value:
			return

		fullscreen = value
		_apply_fullscreen(value)
		fullscreen_changed.emit(value)
		setting_changed.emit(&"fullscreen", value)


var vsync_enabled: bool = true:
	set(value):
		if vsync_enabled == value:
			return

		vsync_enabled = value
		_apply_vsync(value)
		vsync_enabled_changed.emit(value)
		setting_changed.emit(&"vsync_enabled", value)


var settings_open: bool = false:
	set(value):
		if settings_open == value:
			return

		settings_open = value
		if settings_open and credits_open:
			credits_open = false
		settings_open_changed.emit(value)
		setting_changed.emit(&"settings_open", value)


var credits_open: bool = false:
	set(value):
		if credits_open == value:
			return

		credits_open = value
		if credits_open and settings_open:
			settings_open = false
		credits_open_changed.emit(value)
		setting_changed.emit(&"credits_open", value)


var paused: bool = false:
	set(value):
		if paused == value:
			return

		paused = value
		_apply_paused(value)
		paused_changed.emit(value)
		setting_changed.emit(&"paused", value)


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _init() -> void:
	for property_name in get_valid_setting_names():
		default_settings[property_name] = get(property_name)


func _ready() -> void:
	refresh_audio_bus_layout()
	load_from_file()
	setting_changed.connect(_on_setting_changed)
	apply_all_settings()


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		store_to_file()
		get_tree().quit()


# -------------------------------------------------------------------
# Audio bus API
# -------------------------------------------------------------------

func refresh_audio_bus_layout() -> void:
	var changed := false

	for bus_index in AudioServer.get_bus_count():
		var bus_name := AudioServer.get_bus_name(bus_index)

		if not audio_bus_volumes.has(bus_name):
			audio_bus_volumes[bus_name] = db_to_linear(AudioServer.get_bus_volume_db(bus_index))
			changed = true

		if not audio_bus_mutes.has(bus_name):
			audio_bus_mutes[bus_name] = AudioServer.is_bus_mute(bus_index)
			changed = true

	# Remove saved buses that no longer exist in the current AudioServer layout.
	for saved_bus_name in audio_bus_volumes.keys():
		if _get_bus_index(saved_bus_name) == -1:
			audio_bus_volumes.erase(saved_bus_name)
			audio_bus_mutes.erase(saved_bus_name)
			changed = true

	if changed:
		audio_bus_layout_changed.emit()


func get_audio_buses(include_hidden: bool = false) -> Array[Dictionary]:
	refresh_audio_bus_layout()

	var buses: Array[Dictionary] = []

	for bus_index in AudioServer.get_bus_count():
		var bus_name := AudioServer.get_bus_name(bus_index)
		var hidden := is_audio_bus_hidden_from_gui(bus_name)

		if hidden and not include_hidden:
			continue

		buses.append({
			"name": bus_name,
			"display_name": get_audio_bus_display_name(bus_name),
			"volume": get_audio_bus_volume(bus_name),
			"muted": is_audio_bus_muted(bus_name),
			"hidden": hidden,
			"index": bus_index,
		})

	return buses


func get_visible_audio_buses() -> Array[Dictionary]:
	return get_audio_buses(false)


func get_all_audio_buses() -> Array[Dictionary]:
	return get_audio_buses(true)


func get_audio_bus_volume(bus_name: String) -> float:
	refresh_audio_bus_layout()

	if audio_bus_volumes.has(bus_name):
		return float(audio_bus_volumes[bus_name])

	var bus_index := _get_bus_index(bus_name)

	if bus_index == -1:
		return 1.0

	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func set_audio_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := _get_bus_index(bus_name)

	if bus_index == -1:
		push_warning("Audio bus does not exist: %s" % bus_name)
		return

	value = clampf(value, 0.0, 1.0)

	audio_bus_volumes[bus_name] = value
	_apply_bus_volume(bus_name, value)

	audio_bus_volume_changed.emit(bus_name, value)
	setting_changed.emit(&"audio_bus_volumes", audio_bus_volumes)


func is_audio_bus_muted(bus_name: String) -> bool:
	refresh_audio_bus_layout()

	if audio_bus_mutes.has(bus_name):
		return bool(audio_bus_mutes[bus_name])

	var bus_index := _get_bus_index(bus_name)

	if bus_index == -1:
		return false

	return AudioServer.is_bus_mute(bus_index)


func set_audio_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index := _get_bus_index(bus_name)

	if bus_index == -1:
		push_warning("Audio bus does not exist: %s" % bus_name)
		return

	audio_bus_mutes[bus_name] = muted
	AudioServer.set_bus_mute(bus_index, muted)

	audio_bus_mute_changed.emit(bus_name, muted)
	setting_changed.emit(&"audio_bus_mutes", audio_bus_mutes)


func is_audio_bus_hidden_from_gui(bus_name: String) -> bool:
	return bus_name.begins_with(HIDDEN_AUDIO_BUS_PREFIX)


func get_audio_bus_display_name(bus_name: String) -> String:
	if is_audio_bus_hidden_from_gui(bus_name):
		return bus_name.trim_prefix(HIDDEN_AUDIO_BUS_PREFIX)

	return bus_name


func _get_bus_index(bus_name: String) -> int:
	for bus_index in AudioServer.get_bus_count():
		if AudioServer.get_bus_name(bus_index) == bus_name:
			return bus_index

	return -1


func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := _get_bus_index(bus_name)

	if bus_index == -1:
		return

	linear_value = clampf(linear_value, 0.0, 1.0)

	if is_zero_approx(linear_value):
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(0.0001))
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))


func _apply_bus_mute(bus_name: String, muted: bool) -> void:
	var bus_index := _get_bus_index(bus_name)

	if bus_index == -1:
		return

	AudioServer.set_bus_mute(bus_index, muted)


func apply_audio_settings() -> void:
	refresh_audio_bus_layout()

	for bus_name in audio_bus_volumes.keys():
		_apply_bus_volume(bus_name, float(audio_bus_volumes[bus_name]))

	for bus_name in audio_bus_mutes.keys():
		_apply_bus_mute(bus_name, bool(audio_bus_mutes[bus_name]))


# -------------------------------------------------------------------
# Save / Load / Defaults
# -------------------------------------------------------------------

func get_valid_setting_names() -> PackedStringArray:
	var ignored_properties: PackedStringArray = [
		"default_settings",
		"_saved_settings_snapshot",
		"settings_open",
		"credits_open",
		"paused",
	]

	var allowed_types := [
		TYPE_NIL,
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_DICTIONARY,
	]

	var result: PackedStringArray = []

	for property in get_property_list():
		var property_name: String = property["name"]
		var property_type: int = property["type"]
		var property_usage: int = property["usage"]

		var is_script_variable := property_usage & PROPERTY_USAGE_SCRIPT_VARIABLE

		if is_script_variable \
		and not ignored_properties.has(property_name) \
		and property_type in allowed_types:
			result.append(property_name)

	return result


func get_save_data() -> Dictionary:
	refresh_audio_bus_layout()

	var save_data: Dictionary = {}

	for property_name in get_valid_setting_names():
		save_data[property_name] = get(property_name)

	return save_data


func has_unsaved_settings() -> bool:
	return get_save_data() != _saved_settings_snapshot


func store_to_file() -> void:
	if Engine.is_editor_hint():
		return

	serialization_event.emit(SERIALIZATION_EVENT.BEFORE_SAVE)

	var save_data := get_save_data()

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("Could not save settings. Error: %s" % FileAccess.get_open_error())
		serialization_event.emit(SERIALIZATION_EVENT.SAVE_FAILED)
		return

	file.store_var(save_data)
	file.close()

	_set_saved_settings_snapshot(save_data)
	serialization_event.emit(SERIALIZATION_EVENT.AFTER_SAVE)


func load_from_file() -> void:
	if Engine.is_editor_hint():
		return

	serialization_event.emit(SERIALIZATION_EVENT.BEFORE_LOAD)

	if not FileAccess.file_exists(SETTINGS_PATH):
		refresh_audio_bus_layout()
		_set_saved_settings_snapshot(get_save_data())
		serialization_event.emit(SERIALIZATION_EVENT.NO_SETTINGS_FILE)
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)

	if file == null:
		push_warning("Could not open settings file. Error: %s" % FileAccess.get_open_error())
		serialization_event.emit(SERIALIZATION_EVENT.LOAD_FAILED)
		return

	var saved_data: Variant = file.get_var()
	file.close()

	if not saved_data is Dictionary:
		push_warning("Settings file was invalid.")
		serialization_event.emit(SERIALIZATION_EVENT.LOAD_FAILED)
		return

	_apply_save_data(saved_data)

	refresh_audio_bus_layout()
	apply_all_settings()
	_set_saved_settings_snapshot(get_save_data())

	serialization_event.emit(SERIALIZATION_EVENT.AFTER_LOAD)


func restore_default_settings() -> void:
	for property_name in default_settings:
		set(property_name, default_settings[property_name])

	# Reset audio settings from the current AudioServer layout.
	audio_bus_volumes.clear()
	audio_bus_mutes.clear()

	for bus_index in AudioServer.get_bus_count():
		var bus_name := AudioServer.get_bus_name(bus_index)

		set_audio_bus_volume(bus_name, 1.0)
		set_audio_bus_muted(bus_name, false)

	apply_all_settings()
	unsaved_settings_changed.emit(has_unsaved_settings())


func delete_settings_file() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _apply_save_data(save_data: Dictionary) -> void:
	for property_name in get_valid_setting_names():
		if save_data.has(property_name):
			set(property_name, save_data[property_name])


func _set_saved_settings_snapshot(save_data: Dictionary) -> void:
	_saved_settings_snapshot = save_data.duplicate(true)
	unsaved_settings_changed.emit(false)


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	unsaved_settings_changed.emit(has_unsaved_settings())


# -------------------------------------------------------------------
# Apply settings
# -------------------------------------------------------------------

func apply_all_settings() -> void:
	apply_audio_settings()
	_apply_fullscreen(fullscreen)
	_apply_vsync(vsync_enabled)
	_apply_paused(paused)


func _apply_fullscreen(value: bool) -> void:
	if Engine.is_editor_hint():
		return

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_vsync(value: bool) -> void:
	if Engine.is_editor_hint():
		return

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
	)


func _apply_paused(value: bool) -> void:
	if Engine.is_editor_hint() or get_tree() == null:
		return

	get_tree().paused = value


# -------------------------------------------------------------------
# Events
# -------------------------------------------------------------------
func _unhandled_input(_event: InputEvent):
	if Engine.is_editor_hint():
		return
	if Input.is_action_just_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
