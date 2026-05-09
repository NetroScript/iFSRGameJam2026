class_name ScoreDisplay
extends Control


@export var font_size: int = 40

@onready var score_label: Label = %ScoreLabel
@onready var collected_label: Label = %CollectedLabel
@onready var consumed_label: Label = %ConsumedLabel
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	Gamestate.score_changed.connect(_on_score_changed)
	Gamestate.resources_collected_changed.connect(_on_collected_calories_changed)
	Gamestate.resources_consumed_changed.connect(_on_consumed_calories_changed)


func set_score_label_font_size(new_font_size: int) -> void:
	new_font_size = clamp(new_font_size, 1, 100)
	score_label.add_theme_font_size_override("font_size", new_font_size)


func setup_progressbar(ant_hill: AntHill):
	if not is_instance_valid(ant_hill):
		return
	if not is_instance_valid(progress_bar):
		return
	progress_bar.max_value = ant_hill.max_resources
	progress_bar.min_value = 0.0
	ant_hill.resource_added.connect(_on_ant_hill_resources_changed)
	ant_hill.resource_removed.connect(_on_ant_hill_resources_changed)


func set_calories_label_font_size(new_font_size: int) -> void:
	new_font_size = clamp(new_font_size, 1, 100)
	collected_label.add_theme_font_size_override("font_size", new_font_size)
	consumed_label.add_theme_font_size_override("font_size", new_font_size)


func set_calories_label_visibility(new_visibility: bool) -> void:
	collected_label.visible = new_visibility
	consumed_label.visible = new_visibility


func set_score_label_text(score: int) -> void:
	score_label.text = "Score: %d" % score


func set_calories_collected_label_text(calories_collected: int) -> void:
	var prefix: String = ""
	var cal: float = float(calories_collected)
	if cal > 1000.0:
		prefix = "k"
		cal /= 1000.0
	var cal_string: String = _format_float(cal)
	collected_label.text = "Collected: " + cal_string + " " + prefix + "cal"


func set_calories_consumed_label_text(calories_consumed: int) -> void:
	var prefix: String = ""
	var cal: float = float(calories_consumed)
	if cal > 1000.0:
		prefix = "k"
		cal /= 1000.0
	var cal_string: String = _format_float(cal)
	consumed_label.text = "Consumed: " + cal_string + " " + prefix + "cal"


func _on_score_changed(new_score: int):
	set_score_label_text(new_score)


func _on_collected_calories_changed(new_amount: int):
	set_calories_collected_label_text(new_amount)


func _on_consumed_calories_changed(new_amount: int):
	set_calories_consumed_label_text(new_amount)


func _format_float(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	var text := "%.2f" % rounded

	while text.ends_with("0"):
		text = text.left(text.length() - 1)

	if text.ends_with("."):
		text = text.left(text.length() - 1)

	return text


func _on_ant_hill_resources_changed(new_resources: float):
	progress_bar.value = new_resources
