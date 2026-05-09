extends Control

@onready var button: Button = %Button


func _ready() -> void:
	Gamestate.run_ended.connect(_on_game_run_ended)
	Gamestate.run_started.connect(_on_game_run_started)
	button.pressed.connect(_on_restart_button_pressed)


func _on_game_run_ended(_final_score) -> void:
	show()
	GState.paused = true


func _on_game_run_started() -> void:
	hide()


func _on_restart_button_pressed() -> void:
	GState.paused = false
	get_tree().reload_current_scene()
